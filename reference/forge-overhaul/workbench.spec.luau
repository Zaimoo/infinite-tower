--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Package = ReplicatedStorage.ForgeReview
local Model = require(Package.ForgeWorkbench.Model)
local fixture = require(Package.Fixture)
local newTransport = require(Package.DemoTransport)

local count = 0
local function test(name: string, run: () -> ())
	run(); count += 1; print("PASS forge-workbench: " .. name)
end
local function allFilter()
	return { Query = "", Ownership = "ALL", Rarity = 0, WeaponType = "ALL", Sort = "BEST" }
end
local function contains(items: { any }, id: string): boolean
	for _, item in items do if item.UUID == id then return true end end
	return false
end

test("all-owned inventory includes equipped, locked, and unequipped targets", function()
	local s = fixture()
	local items = Model.inventory(s, allFilter(), "hero-jenna-0001")
	assert(#items == 9 and contains(items, "bow-protected") and contains(items, "bow-locked"))
	assert(Model.materialReason(s, "bow-target", "bow-protected") ~= nil)
	assert(Model.materialReason(s, "bow-target", "bow-locked") ~= nil)
end)
test("reciprocal-only, missing-owner, and conflicting equipment all stay protected", function()
	local s = fixture()
	s.Artifacts["bow-protected"].EquippedHeroUUID = nil
	assert(Model.materialReason(s, "bow-target", "bow-protected") ~= nil)
	s.Artifacts["bow-material"].EquippedHeroUUID = "deleted-hero"
	assert(Model.materialReason(s, "bow-target", "bow-material") ~= nil)
	s.Heroes["hero-jenna-0003"].EquippedArtifactUUID = "bow-protected"
	assert(string.find(Model.ownerText(s, "bow-protected"), "sync", 1, true))
end)
test("auto-fill uses safe low-star materials and preserves an explicit valid choice", function()
	local s = fixture()
	local ids = Model.autoFill(s, "sword-target", {})
	assert(#ids == 1 and ids[1] == "sword-material")
	local explicit = Model.autoFill(s, "sword-target", { "sword-invested" })
	assert(explicit[1] == "sword-invested")
	local bows = Model.autoFill(s, "bow-target", {})
	assert(#bows == 1 and bows[1] == "bow-material")
end)
test("materials revalidate after equipping, locking, deletion, and target changes", function()
	local s = fixture()
	assert(#Model.materials(s, "bow-target", { "bow-material", "bow-material" }) == 1)
	s.Artifacts["bow-material"].Locked = true
	assert(#Model.materials(s, "bow-target", { "bow-material" }) == 0)
	s.Artifacts["bow-material"].Locked = false
	s.Artifacts["bow-material"].EquippedHeroUUID = "hero-jenna-0003"
	assert(#Model.materials(s, "bow-target", { "bow-material" }) == 0)
	s.Artifacts["bow-material"] = nil
	assert(#Model.materials(s, "bow-target", { "bow-material" }) == 0)
	assert(#Model.materials(s, "sword-target", { "bow-locked" }) == 0)
end)
test("hero identity survives duplicate display names and literal search punctuation", function()
	local s = fixture()
	local filter = allFilter(); filter.Query = "#0002"
	assert(contains(Model.inventory(s, filter, nil), "bow-protected"))
	filter.Query = "[" -- literal search, never Lua pattern syntax
	assert(#Model.inventory(s, filter, nil) == 0)
	assert(Model.heroLabel(s.Heroes["hero-jenna-0001"]) ~= Model.heroLabel(s.Heroes["hero-jenna-0002"]))
end)
test("best suggestions skip other heroes' weapons and never equip automatically", function()
	local s = fixture()
	s.Artifacts["bow-max"].EquippedHeroUUID = "hero-jenna-0002"
	local best = Model.best(s, "hero-jenna-0001")
	assert(best ~= "bow-max" and best ~= "bow-protected")
	assert(s.Heroes["hero-jenna-0001"].EquippedArtifactUUID == "bow-current")
end)
test("max rank, compatibility, currency, and duplicate materials block commitment", function()
	local s = fixture()
	assert(Model.upgradeReason(s, "bow-max", {}) ~= nil)
	assert(Model.equipReason(s, "hero-valeria-0004", "bow-target") ~= nil)
	s.Gold = 499
	assert(Model.upgradeReason(s, "bow-target", { "bow-material" }) == "Not enough Gold")
	s.Gold = 115940
	assert(Model.upgradeReason(s, "bow-target", { "bow-material", "bow-material" }) ~= nil)
	s.Artifacts["bow-target"].Star = 4; s.Gems = 49
	for i = 1, 4 do local donor = table.clone(s.Artifacts["bow-material"]); donor.UUID = "d" .. i; s.Artifacts[donor.UUID] = donor end
	assert(Model.upgradeReason(s, "bow-target", { "d1", "d2", "d3", "d4" }) == "Not enough Gems")
end)
test("filters compose without deleting inventory entries; sorting is stable", function()
	local s = fixture()
	local filter = allFilter(); filter.Ownership = "EQUIPPED"; filter.WeaponType = "BOW"
	assert(#Model.inventory(s, filter, nil) == 2)
	filter.Ownership = "HERO"
	assert(#Model.inventory(s, filter, "hero-jenna-0002") == 1)
	filter = allFilter(); filter.Sort = "NAME"
	local a, b = Model.inventory(s, filter, nil), Model.inventory(s, filter, nil)
	for i, item in a do assert(item.UUID == b[i].UUID) end
	assert(s.Artifacts["bow-material"] ~= nil)
end)
test("equip and undo restore both heroes and both artifacts atomically in the demo", function()
	local s = fixture()
	local api = newTransport(s)
	local result = api.Execute({ RequestId = "move", ExpectedRevision = 1, Kind = "EQUIP", HeroId = "hero-jenna-0001", ArtifactId = "bow-protected" })
	assert(result.Ok and result.UndoToken)
	assert(result.Snapshot.Heroes["hero-jenna-0002"].EquippedArtifactUUID == nil)
	assert(result.Snapshot.Artifacts["bow-current"].EquippedHeroUUID == nil)
	local undo = api.Execute({ RequestId = "undo", ExpectedRevision = 2, Kind = "UNDO", UndoToken = result.UndoToken })
	assert(undo.Ok and undo.Snapshot.Revision == 3)
	assert(undo.Snapshot.Heroes["hero-jenna-0002"].EquippedArtifactUUID == "bow-protected")
	assert(undo.Snapshot.Heroes["hero-jenna-0001"].EquippedArtifactUUID == "bow-current")
	assert(undo.Snapshot.Artifacts["bow-protected"].EquippedHeroUUID == "hero-jenna-0002")
	local again = api.Execute({ RequestId = "undo-again", ExpectedRevision = 3, Kind = "UNDO", UndoToken = result.UndoToken })
	assert(not again.Ok)
end)
test("promotion is idempotent, preserves equipped target, and returns immutable receipts", function()
	local s = fixture(); s.Artifacts["bow-target"].EquippedHeroUUID = "hero-jenna-0003"; s.Heroes["hero-jenna-0003"].EquippedArtifactUUID = "bow-target"
	local api = newTransport(s)
	local command = { RequestId = "upgrade", ExpectedRevision = 1, Kind = "UPGRADE", ArtifactId = "bow-target", MaterialIds = { "bow-material" } }
	local result = api.Execute(command)
	assert(result.Ok and result.Snapshot.Gold == s.Gold - 500)
	assert(result.Snapshot.Artifacts["bow-target"].Star == 2)
	assert(result.Snapshot.Artifacts["bow-target"].EquippedHeroUUID == "hero-jenna-0003")
	assert(result.Snapshot.Artifacts["bow-material"] == nil and result.UndoToken == nil)
	local repeated = api.Execute(command)
	assert(repeated.Snapshot.Revision == 2 and repeated.Snapshot.Gold == s.Gold - 500)
	api.Execute({ RequestId = "lock", ExpectedRevision = 2, Kind = "LOCK", ArtifactId = "bow-target", Locked = true })
	assert(result.Snapshot.Artifacts["bow-target"].Locked ~= true)
	assert(api.Reconcile("upgrade").RequestId == "upgrade")
end)
test("failed and stale actions never spend currency or consume protected materials", function()
	local s = fixture(); local api = newTransport(s)
	local denied = api.Execute({ RequestId = "protected", ExpectedRevision = 1, Kind = "UPGRADE", ArtifactId = "bow-target", MaterialIds = { "bow-protected" } })
	assert(not denied.Ok and denied.Snapshot.Gold == s.Gold and denied.Snapshot.Revision == 1)
	assert(denied.Snapshot.Artifacts["bow-protected"] ~= nil)
	local stale = api.Execute({ RequestId = "stale", ExpectedRevision = 0, Kind = "LOCK", ArtifactId = "bow-target", Locked = true })
	assert(not stale.Ok and stale.Snapshot.Artifacts["bow-target"].Locked ~= true)
end)
test("large synthetic inventory remains complete and deterministic across pages", function()
	local s = fixture()
	for i = 1, 1000 do local artifact = table.clone(s.Artifacts["bow-material"]); artifact.UUID = string.format("large-%04d", i); s.Artifacts[artifact.UUID] = artifact end
	local items = Model.inventory(s, allFilter(), "hero-jenna-0001")
	assert(#items == 1009)
	local seen = {}
	for _, item in items do assert(not seen[item.UUID]); seen[item.UUID] = true end
end)
print(string.format("Forge workbench: %d tests passed", count))
