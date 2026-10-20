-- Regression tests execute real Pit modules through roblox-module-shim.luau.
local Config = require(nodes["ReplicatedStorage.Shared.Config.PitBalanceConfig"])
local Catalog = require(nodes["ReplicatedStorage.Shared.Config.HeroCatalog"])
local Stats = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local Math = require(nodes["ReplicatedStorage.Shared.Util.PitMath"])
local PitService = require(nodes["ServerScriptService.Core.PitService"])

local passed, failed = 0, 0
local function check(condition, message)
	assert(condition, message or "Expected condition to be true")
end
local function equal(actual, expected, message)
	assert(actual == expected, (message or "Value differs") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function close(actual, expected, tolerance)
	check(math.abs(actual - expected) <= (tolerance or 0.00001), "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function deepEqual(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do if not deepEqual(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end
local function test(name, callback)
	local ok, result = pcall(callback)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name .. "\n" .. tostring(result)) end
end
local function hero(id, seedId, fields)
	local seed = Catalog.Seeds[seedId or "hero_han"]
	local value = {
		UUID = id, TemplateId = seed.HeroId, DisplayName = seed.DisplayName, Archetype = seed.Archetype,
		Stars = seed.BaseStar, Level = 1, XP = 0, OverflowXP = 0, QualityScalar = 1,
		BaseHP = seed.NativeHP, BaseATK = seed.NativeATK, BaseLabor = seed.NativeLabor,
		AttackInterval = seed.AttackInterval, AttackRange = seed.AttackRange,
		PassiveTrait = seed.PassiveTraitName, CurrentStamina = 100, MaxStamina = 100,
		ComaUntilTimestamp = 0, IsHardAuditComa = false, Assignment = "BENCHED",
		Locked = false, Favorite = false, InheritedImprints = {},
	}
	for key, valueOverride in pairs(fields or {}) do value[key] = valueOverride end
	return value
end

test("Existing level curve and all five caps remain intact", function()
	equal(Stats.GetXPRequiredForNextLevel(1), 50)
	equal(Stats.GetXPRequiredForNextLevel(2), 137)
	equal(Stats.GetXPRequiredForNextLevel(9), 1210)
	for stars = 1, 5 do equal(Stats.GetMaxLevel(stars), stars * 10) end
end)

test("Fresh donor value, affinity, research and efficiency have exact results", function()
	local recipient = hero("r")
	local donor = hero("d", "hero_jenna")
	local result = Math.GetSynthesisXP(donor, recipient, {})
	equal(result.Base, 125); equal(result.Efficiency, 1); equal(result.Final, 125)
	equal(Math.GetSynthesisXP(hero("a"), recipient, {}).Final, 131)
	equal(Math.GetSynthesisXP(donor, recipient, { EssenceAttunement = true }).Final, 138)
	recipient.Level = 30
	local diminished = Math.GetSynthesisXP(donor, recipient, {})
	equal(diminished.Efficiency, 0.55); equal(diminished.Final, 69)
end)

test("Invested donors improve value at every rarity", function()
	for stars = 1, 5 do
		local recipient = hero("r", "hero_han", { Stars = stars, Level = stars * 10 })
		local fresh = hero("a", "hero_jenna", { Stars = stars })
		local invested = hero("b", "hero_jenna", { Stars = stars, Level = stars * 10 })
		check(Math.GetSynthesisXP(invested, recipient, {}).Final > Math.GetSynthesisXP(fresh, recipient, {}).Final)
	end
end)

test("Full balance sweep keeps donor XP monotonic and efficiency between 55 and 100 percent", function()
	for stars = 1, 5 do
		for recipientLevel = 1, 50 do
			for _, affinity in ipairs({ false, true }) do
				for _, researched in ipairs({ false, true }) do
					local previous = -1
					for donorLevel = 1, stars * 10 do
						local donor = hero("d", affinity and "hero_han" or "hero_jenna", { Stars = stars, Level = donorLevel })
						local recipient = hero("r", "hero_han", { Stars = 5, Level = recipientLevel })
						local result = Math.GetSynthesisXP(donor, recipient, { EssenceAttunement = researched })
						check(result.Efficiency >= 0.55 and result.Efficiency <= 1)
						check(result.Final >= 0 and result.Final >= previous, "Investing levels reduced donor value")
						local base = 100 * 3 ^ (stars - 1) + 25 * donorLevel
						-- Evaluate rational config constants without intermediate
						-- floating-point .5 boundary drift in the expected result.
						local efficiencyUnits = math.max(22, 40 - math.max(0, recipientLevel - donorLevel - 5))
						local bonusPercent = 100 + (researched and 10 or 0) + (affinity and 5 or 0)
						local expected = math.floor(base * efficiencyUnits * bonusPercent / 4000 + 0.5)
						equal(result.Final, expected, string.format("Rounding stars=%d donor=%d recipient=%d affinity=%s research=%s", stars, donorLevel, recipientLevel, tostring(affinity), tostring(researched)))
						previous = result.Final
					end
				end
			end
		end
	end
end)

test("Every native seed retains original combat and facility formulas without imprints", function()
	for seedId, seed in pairs(Catalog.Seeds) do
		for level = 1, seed.BaseStar * 10 do
			for _, quality in ipairs({ 0.9, 1, 1.15 }) do
				local original = hero("native", seedId, { Level = level, QualityScalar = quality })
				local atk, hp, dps = Stats.GetEffectiveCombatStats(original, false, false)
				local expectedATK = math.round(seed.NativeATK * quality * (1 + 0.08 * (level - 1)) * (1 + seed.TraitATKBonus))
				local expectedHP = math.round(seed.NativeHP * quality * (1 + 0.08 * (level - 1)) * (1 + seed.TraitHPBonus))
				local expectedDPS = math.round((expectedATK / seed.AttackInterval) * 10) / 10
				equal(atk, expectedATK); equal(hp, expectedHP); equal(dps, expectedDPS)
				for _, facility in ipairs({ "BENCHED", "FACILITY_CONDUIT", "FACILITY_INFIRMARY", "FACILITY_LAB" }) do
					local synergy = (seed.PreferredFacility == "ALL" or seed.PreferredFacility == facility) and 0.25 or 0
					local expectedLabor = math.round(seed.NativeLabor * quality * (1 + 0.05 * (level - 1)) * (1 + synergy) * (1 + seed.TraitLaborBonus) * 100) / 100
					equal(Stats.GetEffectiveLabor(original, facility), expectedLabor)
				end
			end
		end
	end
end)

test("One and multiple donors apply the existing level curve", function()
	local original = hero("r")
	local after = Math.AdvanceXP(original, 125)
	equal(after.Level, 2); equal(after.XP, 75)
	local batch = Math.AdvanceXP(original, 250)
	equal(batch.Level, 3); equal(batch.XP, 63)
	equal(original.Level, 1); equal(original.XP, 0)
	local atk, hp, dps = Stats.GetEffectiveCombatStats(after, false, false)
	equal(atk, 48); equal(hp, 324); equal(dps, 56.5)
	equal(Stats.GetEffectiveLabor(after), 14.7)
end)

test("Cap overflow is stored exactly and excess is reported", function()
	local recipient = hero("r", "hero_han", { Level = 9, XP = 1190 })
	local after, overflow = Math.AdvanceXP(recipient, 125)
	equal(after.Level, 10); equal(after.XP, 0); equal(after.OverflowXP, 105)
	equal(overflow.Rejected, 0); equal(overflow.Capacity, 3027)
	local bounded, excess = Math.AdvanceXP(hero("r", "hero_han", { Level = 10 }), 4000)
	equal(bounded.OverflowXP, 3027); equal(excess.Rejected, 973)
end)

test("Five stars never exceed level 50 or create a future-tier reserve", function()
	local result, overflow = Math.AdvanceXP(hero("r", "hero_han", { Stars = 5, Level = 50 }), 10000)
	equal(result.Level, 50); equal(result.XP, 0); equal(result.OverflowXP, 0); equal(overflow.Rejected, 10000)
end)

test("Promotion applies one multiplier and releases reserve through real levels", function()
	local before = hero("r", "hero_han", { Level = 10, OverflowXP = 3027, InheritedImprints = { melee_memory = 1 } })
	local after = Math.Promote(before)
	equal(after.Stars, 2); equal(after.BaseATK, 66); equal(after.BaseHP, 495); equal(after.BaseLabor, 18.9)
	equal(after.Level, 12); equal(after.XP, 0); equal(after.OverflowXP, 0)
	equal(after.PassiveTrait, before.PassiveTrait); equal(after.InheritedImprints.melee_memory, 1)
	equal(before.Stars, 1); equal(before.BaseATK, 40)
	local atk, hp = Stats.GetEffectiveCombatStats(after, false, false)
	equal(atk, math.round(66 * 1.88 * 1.12)); equal(hp, math.round(495 * 1.88))
	local repeatATK, repeatHP = Stats.GetEffectiveCombatStats(after, false, false)
	equal(repeatATK, atk); equal(repeatHP, hp); equal(after.BaseATK, 66)
	close(Stats.GetEffectiveLabor(after, "FACILITY_CONDUIT"), 36.62, 0.00001)
end)

test("Conversion rewards are deterministic and account for bounded investment", function()
	equal(Math.GetConversionYield(hero("a")), 4)
	equal(Math.GetConversionYield(hero("a", "hero_han", { Level = 6 })), 5)
	equal(Math.GetConversionYield(hero("b", "hero_aaron")), 12)
	equal(Math.GetConversionYield(hero("c", "hero_eolka")), 36)
	equal(Math.GetConversionYield(hero("a", "hero_han", { InheritedImprints = { melee_memory = 999, fake = 999 } })), 10)
end)

test("Imprint compatibility, research and capacity reject unsupported transfers", function()
	local options = Math.GetImprintOptions(hero("d", "hero_jenna"), hero("r"), {})
	equal(#options, 1); equal(options[1].Id, "ranged_memory"); equal(options[1].Compatible, false)
	options = Math.GetImprintOptions(hero("d"), hero("r", "hero_aaron"), {})
	equal(options[1].Compatible, true); equal(options[1].SuccessChance, 1)
	local full = hero("r", "hero_han", { InheritedImprints = { conduit_memory = 1 } })
	equal(Math.GetImprintOptions(hero("d"), full, {})[1].Compatible, false)
	local scholar = hero("r", "hero_eolka")
	equal(Math.GetImprintOptions(hero("d", "hero_eolka"), scholar, {})[1].Compatible, false)
	equal(Math.GetImprintOptions(hero("d", "hero_eolka"), scholar, { MemoryStudies = true })[1].Compatible, true)
end)

test("Proficiency upgrades use the existing slot and stop at rank three", function()
	local recipient = hero("r", "hero_han", { InheritedImprints = { melee_memory = 1 } })
	equal(Math.GetImprintOptions(hero("d"), recipient, {})[1].Compatible, true)
	recipient.InheritedImprints.melee_memory = 3
	equal(Math.GetImprintOptions(hero("d"), recipient, {})[1].Compatible, false)
end)

test("Malformed and incompatible imprint bonuses cannot stack beyond caps", function()
	local recipient = hero("r", "hero_han", { InheritedImprints = {
		melee_memory = 1000, conduit_memory = 1000, ranged_memory = 1000,
		scholarly_memory = 1000, bulwark_memory = 1000, fake = 1000,
	} })
	local atk, hp, labor = Stats.GetImprintBonuses(recipient)
	close(atk, 0.06); equal(hp, 0); close(labor, 0.09)
	check(atk <= Config.Imprints.BonusCaps.ATK); check(labor <= Config.Imprints.BonusCaps.Labor)
	recipient.InheritedImprints = { melee_memory = -1, conduit_memory = 0 / 0 }
	atk, hp, labor = Stats.GetImprintBonuses(recipient)
	equal(atk, 0); equal(hp, 0); equal(labor, 0)
end)

-- Service tests follow below; all tests share the same assertions and real modules.
local function profile()
	return {
		SchemaVersion = 1, PlotIndex = 1,
		Currencies = { Gold = 1000000, Gems = 10000, ResearchPoints = 1000 },
		Heroes = { r = hero("r"), d = hero("d", "hero_jenna"), e = hero("e", "hero_catio") },
		DeployedSquadOrder = {},
		Facilities = {
			ManaConduit = { Level = 1, AssignedHeroUUIDs = {}, UncollectedOutput = 0 },
			Infirmary = { Level = 1, AssignedHeroUUIDs = {}, UncollectedOutput = 0 },
			DimensionalLab = { Level = 5, AssignedHeroUUIDs = {}, UncollectedOutput = 0 },
		},
		UnlockedResearch = {},
		PitMaterials = { SoulEssence = 1000, PromotionStone = 100, ImprintCatalyst = 100 },
		Social = {},
	}
end

local function context()
	local c = { now = 100, nextToken = 0, syncs = 0, player = "master-one", other = "master-two" }
	c.profile, c.otherProfile = profile(), profile()
	c.profiles = { [c.player] = c.profile, [c.other] = c.otherProfile }
	for _, value in pairs(c.profiles) do PitService.EnsureDefaults(value) end
	c.service = PitService.new({
		GetProfile = function(player) return c.profiles[player] end,
		GenerateToken = function() c.nextToken += 1; return "opaque-test-token-" .. c.nextToken end,
		Clock = function() return c.now end,
		SyncProfile = function(player) c.syncs += 1; if c.onSync then c.onSync(player) end end,
	})
	function c:request(command, payload, player)
		self.now += 0.25
		return self.service:Request(player or self.player, command, payload)
	end
	function c:preview(request, player)
		local result = self:request("PREVIEW", request, player)
		check(result.Success, result.Message)
		return result.Preview
	end
	function c:commit(preview, extra, player)
		local payload = { Token = preview.Token, ConfirmRare = true }
		for key, value in pairs(extra or {}) do payload[key] = value end
		return self:request("COMMIT", payload, player)
	end
	return c
end

local function synthesis(donors)
	return { Action = "SYNTHESIS", Recipient = "r", Donors = donors or { "d" } }
end

local function rejectedWithoutMutation(c, command, payload)
	-- Newly inserted legacy fixtures may need schema defaults. Migration is
	-- deliberately allowed before measuring the irreversible operation's effects.
	PitService.EnsureDefaults(c.profile)
	local before = Math.Copy(c.profile)
	local response = c:request(command, payload)
	check(response.Success == false or (response.Preview and response.Preview.CanCommit == false), "Expected rejected operation")
	check(deepEqual(c.profile, before), "Rejected operation mutated the profile")
	return response
end

test("Schema migration preserves existing heroes, assignments, levels and inventory", function()
	local p = profile()
	p.PitMaterials = nil; p.Heroes.r.Level = 8; p.Heroes.r.Assignment = "FACILITY_LAB"
	p.Heroes.r.Locked = nil; p.Heroes.r.Favorite = nil; p.Heroes.r.OverflowXP = nil
	p.Heroes.r.InheritedImprints = nil; p.Facilities.DimensionalLab.AssignedHeroUUIDs = { "r" }
	p.UnlockedResearch.SquadSlot4 = true
	PitService.EnsureDefaults(p)
	equal(p.SchemaVersion, 2); equal(p.Heroes.r.Level, 8); equal(p.Heroes.r.XP, 0)
	equal(p.Heroes.r.Assignment, "FACILITY_LAB"); equal(p.Facilities.DimensionalLab.AssignedHeroUUIDs[1], "r")
	equal(p.Currencies.Gems, 10000); equal(p.UnlockedResearch.SquadSlot4, true)
	equal(p.Heroes.r.Locked, false); equal(p.Heroes.r.Favorite, false); equal(p.Heroes.r.OverflowXP, 0)
	equal(p.PitMaterials.SoulEssence, 0); equal(p.PitMaterials.PromotionStone, 0); equal(p.PitMaterials.ImprintCatalyst, 0)
	local stable = Math.Copy(p); PitService.EnsureDefaults(p); check(deepEqual(stable, p), "Migration must be idempotent")
end)

test("State snapshots do not expose mutable references", function()
	local c = context()
	local result = c:request("STATE")
	check(result.Success); equal(result.State.SessionOnly, true)
	result.State.Heroes.r.Level = 50; result.State.Materials.SoulEssence = 10000000
	equal(c.profile.Heroes.r.Level, 1); equal(c.profile.PitMaterials.SoulEssence, 1000)
end)

test("Preview does not spend resources and committed single donor matches exact preview", function()
	local c = context()
	local before = Math.Copy(c.profile)
	local preview = c:preview(synthesis())
	check(preview.CanCommit); check(preview.Token); check(deepEqual(before, c.profile))
	equal(preview.XP.Final, 125); equal(preview.After.Level, 2); equal(preview.After.XP, 75)
	local result = c:commit(preview)
	check(result.Success, result.Message); equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e)
	check(deepEqual(Math.Snapshot(c.profile.Heroes.r), preview.After))
	equal(c.profile.Heroes.r.SynthesisHistory.DonorsConsumed, 1); equal(c.profile.Heroes.r.SynthesisHistory.XPGained, 125)
	equal(c.profile.Currencies.Gold, before.Currencies.Gold); equal(c.syncs, 1)
end)

test("Batch synthesis is deterministic and independent of donor order", function()
	local c = context()
	local preview = c:preview(synthesis({ "d", "e" }))
	local reverse = c:preview(synthesis({ "e", "d" }))
	equal(preview.XP.Final, 250); equal(reverse.XP.Final, 250)
	check(deepEqual(preview.After, reverse.After)); check(c:commit(reverse).Success)
	equal(c.profile.Heroes.r.Level, 3); equal(c.profile.Heroes.r.XP, 63)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.e, nil)
end)

test("Six-donor limit and exact identities are enforced", function()
	local c = context()
	local ids = {}
	for i = 1, 7 do local id = "batch" .. i; c.profile.Heroes[id] = hero(id, "hero_jenna"); table.insert(ids, id) end
	rejectedWithoutMutation(c, "PREVIEW", synthesis(ids))
	table.remove(ids); local p = c:preview(synthesis(ids)); check(p.CanCommit); equal(#p.Donors, 6)
	check(c:commit(p).Success); check(c.profile.Heroes.batch7)
	for _, id in ipairs(ids) do equal(c.profile.Heroes[id], nil) end
end)

test("Duplicate hero names remain separate UUID instances", function()
	local c = context()
	c.profile.Heroes.d = hero("d"); c.profile.Heroes.e = hero("e")
	equal(c.profile.Heroes.d.DisplayName, c.profile.Heroes.e.DisplayName)
	local preview = c:preview({ Action = "CONVERSION", Donors = { "d" } })
	check(c:commit(preview).Success); equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e); check(c.profile.Heroes.r)
end)

test("Self-donors, duplicate UUIDs, missing heroes and foreign UUIDs reject atomically", function()
	for _, ids in ipairs({ { "r" }, { "d", "d" }, { "missing" }, { "foreign-only" } }) do
		local c = context(); c.otherProfile.Heroes["foreign-only"] = hero("foreign-only")
		rejectedWithoutMutation(c, "PREVIEW", synthesis(ids))
	end
end)

test("Every donor protection applies equally to synthesis and conversion", function()
	local protections = {
		{ Locked = true }, { Favorite = true }, { Favorited = true },
		{ Assignment = "SQUAD_SLOT_1" }, { Assignment = "FACILITY_CONDUIT" },
		{ ComaUntilTimestamp = os.time() + 1000 }, { IsHardAuditComa = true },
		{ ReservedBy = "ritual" }, { Reserved = true }, { OperationReserved = true },
		{ ReservedOperationId = "operation" }, { InCombat = true }, { IsInCombat = true },
		{ ActiveCombat = true }, { Unique = true }, { IsUnique = true }, { Protected = true },
		{ TemplateId = "hero_archon" }, { TemplateId = "unknown-unique" },
	}
	for _, fields in ipairs(protections) do
		for _, action in ipairs({ "SYNTHESIS", "CONVERSION" }) do
			local c = context()
			for key, value in pairs(fields) do c.profile.Heroes.d[key] = value end
			rejectedWithoutMutation(c, "PREVIEW", { Action = action, Recipient = action == "SYNTHESIS" and "r" or nil, Donors = { "d" } })
		end
	end
end)

test("Redundant squad, facility and reservation indexes protect apparently benched donors", function()
	for _, index in ipairs({ "squad", "facility", "reservation" }) do
		local c = context()
		if index == "squad" then c.profile.DeployedSquadOrder = { "d" }
		elseif index == "facility" then c.profile.Facilities.ManaConduit.AssignedHeroUUIDs = { "d" }
		else c.profile.ReservedHeroUUIDs = { d = true } end
		rejectedWithoutMutation(c, "PREVIEW", synthesis())
	end
end)

test("Malformed and oversized client request shapes cannot mutate profiles", function()
	local bad = {
		false, 7, "SYNTHESIS", {}, { Action = 3 }, { Action = "FAKE" },
		{ Action = "SYNTHESIS", Recipient = {} }, { Action = "SYNTHESIS", Recipient = 3 },
		{ Action = "SYNTHESIS", Recipient = string.rep("x", 81) },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = "d" },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { [2] = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { [-1] = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { donor = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { [math.huge] = "d" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { "d", extra = "e" } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { 0 / 0 } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { math.huge } },
		{ Action = "SYNTHESIS", Recipient = "r", Donors = { string.rep("x", 81) } },
		{ Action = "IMPRINT", Recipient = "r", Donors = { "d" }, Imprint = {} },
		{ Action = "CRAFT", Recipe = false },
	}
	for _, payload in ipairs(bad) do rejectedWithoutMutation(context(), "PREVIEW", payload) end
	rejectedWithoutMutation(context(), "PREVIEW", nil)
	local acceptsNaNKey = pcall(function() return { [0 / 0] = "d" } end)
	equal(acceptsNaNKey, false) -- Luau rejects NaN keys before any request exists.
end)

test("Client EXP, cost, outcome and star fields never become authoritative", function()
	local c = context()
	local request = synthesis(); request.XP = 1e15; request.Gold = -999; request.FinalStars = 5; request.Success = true
	local preview = c:preview(request)
	equal(preview.XP.Final, 125)
	request.Donors[1] = "e"
	check(c:commit(preview, { XP = 1e15, Recipient = "e", FinalStars = 5 }).Success)
	equal(c.profile.Heroes.r.Stars, 1); equal(c.profile.Heroes.r.Level, 2)
	equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e)
end)

test("Stale economy, roster, assignment, research and material changes reject without partial consumption", function()
	local mutations = {
		function(p) p.Currencies.Gold -= 1 end,
		function(p) p.Heroes.d.Level = 2 end,
		function(p) p.Heroes.d = nil end,
		function(p) p.Heroes.d.Locked = true end,
		function(p) p.Facilities.ManaConduit.AssignedHeroUUIDs = { "d" } end,
		function(p) p.DeployedSquadOrder = { "d" } end,
		function(p) p.UnlockedResearch.EssenceAttunement = true end,
		function(p) p.PitMaterials.SoulEssence -= 1 end,
		function(p) p.ReservedHeroUUIDs = { d = true } end,
	}
	for _, mutate in ipairs(mutations) do
		local c = context(); local preview = c:preview(synthesis()); mutate(c.profile)
		rejectedWithoutMutation(c, "COMMIT", { Token = preview.Token, ConfirmRare = true })
	end
end)

test("Ordinary stamina regeneration preserves a valid preview", function()
	local c = context(); c.profile.Heroes.r.CurrentStamina = 80
	local p = c:preview(synthesis()); c.profile.Heroes.r.CurrentStamina = 82
	check(c:commit(p).Success)
end)

test("Tokens are expiring, single-use and isolated to their player", function()
	local c = context(); local p = c:preview(synthesis())
	local foreign = c:request("COMMIT", { Token = p.Token }, c.other)
	equal(foreign.Success, false); check(c.profile.Heroes.d)
	check(c:commit(p).Success)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	local expired = context(); local old = expired:preview(synthesis())
	expired.now += Config.PreviewLifetime + 1
	rejectedWithoutMutation(expired, "COMMIT", { Token = old.Token })
end)

test("A new preview invalidates a previous operation token", function()
	local c = context(); local old = c:preview(synthesis())
	c:preview({ Action = "CONVERSION", Donors = { "e" } })
	rejectedWithoutMutation(c, "COMMIT", { Token = old.Token })
end)

test("Rare donors require explicit confirmation, with no cost on rejection", function()
	local c = context(); c.profile.Heroes.d = hero("d", "hero_eolka"); PitService.EnsureDefaults(c.profile)
	local p = c:preview({ Action = "CONVERSION", Donors = { "d" } })
	equal(p.RequiresRareConfirmation, true)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token, ConfirmRare = false })
	p = c:preview({ Action = "CONVERSION", Donors = { "d" } }); check(c:commit(p).Success)
	equal(c.profile.Heroes.d, nil)
end)

test("Reentrant requests observe the per-player lock and cannot double consume", function()
	local c = context(); local p = c:preview({ Action = "CONVERSION", Donors = { "d" } })
	local nested
	c.onSync = function() nested = c.service:Request(c.player, "COMMIT", { Token = p.Token, ConfirmRare = true }) end
	local result = c:commit(p)
	check(result.Success); equal(nested.Success, false); equal(c.profile.PitMaterials.SoulEssence, 1004)
	equal(c.profile.Heroes.d, nil); equal(c.service.Locks[c.player], nil)
end)

test("Replication exceptions preserve a committed success and release the lock", function()
	local c = context(); local p = c:preview(synthesis())
	c.onSync = function() error("simulated network sync error") end
	check(c:commit(p).Success); equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.r.Level, 2)
	equal(c.service.Locks[c.player], nil); check(c:request("STATE").Success)
end)

test("Committed deltas contain only affected heroes and exact removals", function()
	local c = context(); local p = c:preview(synthesis())
	local result = c:commit(p); check(result.Success); check(result.Delta)
	equal(result.State, nil); check(result.Delta.Heroes.r); equal(result.Delta.Heroes.e, nil)
	equal(#result.Delta.Removed, 1); equal(result.Delta.Removed[1], "d")
	equal(result.Delta.Revision, c.profile.PitRevision)
end)

test("Delta construction failure cannot misreport an already committed transaction", function()
	local c = context(); local p = c:preview(synthesis())
	c.service.Delta = function() error("simulated post-commit delta failure") end
	local result = c:commit(p); check(result.Success); equal(result.Delta, nil)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.r.Level, 2)
	equal(c.service.Locks[c.player], nil)
end)

test("Recipient recovery/reservation and overflow reject before donors are lost", function()
	for _, fields in ipairs({ { ComaUntilTimestamp = os.time() + 1000 }, { ReservedBy = "operation" }, { Level = 10, OverflowXP = 3027 }, { Stars = 5, Level = 50 } }) do
		local c = context(); for key, value in pairs(fields) do c.profile.Heroes.r[key] = value end
		rejectedWithoutMutation(c, "PREVIEW", synthesis())
	end
	local c = context(); c.profile.Heroes.r.Level = 9; c.profile.Heroes.r.XP = 1190
	local p = c:preview(synthesis()); check(p.CanCommit); check(c:commit(p).Success)
	equal(c.profile.Heroes.r.Level, 10); equal(c.profile.Heroes.r.OverflowXP, 96)
end)

test("Valid promotion charges exact resources, preserves traits and cannot repeat", function()
	local c = context(); c.profile.Heroes.r.Level = 10; c.profile.Heroes.r.InheritedImprints = { melee_memory = 1 }
	local p = c:preview({ Action = "PROMOTION", Recipient = "r" }); check(p.CanCommit)
	equal(p.Costs.Gold, 1500); equal(p.Costs.PromotionStone, 1)
	check(c:commit(p).Success); equal(c.profile.Currencies.Gold, 998500); equal(c.profile.PitMaterials.PromotionStone, 99)
	equal(c.profile.Heroes.r.Stars, 2); equal(c.profile.Heroes.r.BaseATK, 66)
	equal(c.profile.Heroes.r.BaseLabor, 18.9); equal(c.profile.Heroes.r.InheritedImprints.melee_memory, 1)
	equal(c.profile.Heroes.r.PassiveTrait, Catalog.Seeds.hero_han.PassiveTraitName)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	rejectedWithoutMutation(c, "PREVIEW", { Action = "PROMOTION", Recipient = "r" })
end)

test("Promotion validates cap, Gold, stones, advanced research and five-star ceiling", function()
	local scenarios = {
		function(p) p.Heroes.r.Level = 9 end,
		function(p) p.Currencies.Gold = 1499 end,
		function(p) p.PitMaterials.PromotionStone = 0 end,
		function(p) p.Heroes.r.Stars = 3; p.Heroes.r.Level = 30 end,
		function(p) p.Heroes.r.Stars = 4; p.Heroes.r.Level = 40 end,
		function(p) p.Heroes.r.Stars = 5; p.Heroes.r.Level = 50 end,
	}
	for _, mutate in ipairs(scenarios) do
		local c = context(); c.profile.Heroes.r.Level = 10; mutate(c.profile)
		rejectedWithoutMutation(c, "PREVIEW", { Action = "PROMOTION", Recipient = "r" })
	end
	local c = context(); c.profile.Heroes.r.Stars = 4; c.profile.Heroes.r.Level = 40; c.profile.UnlockedResearch.MasterStonecraft = true
	local p = c:preview({ Action = "PROMOTION", Recipient = "r" }); check(p.CanCommit); check(c:commit(p).Success)
	equal(c.profile.Heroes.r.Stars, 5); equal(Math.GetImprintCapacity(c.profile.Heroes.r), 3)
end)

test("Promotion updates actual assigned facility labor without double scaling", function()
	local c = context(); local r = c.profile.Heroes.r
	r.Level = 10; r.Assignment = "FACILITY_CONDUIT"; c.profile.Facilities.ManaConduit.AssignedHeroUUIDs = { "r" }
	local beforeLabor = Stats.GetEffectiveLabor(r)
	local p = c:preview({ Action = "PROMOTION", Recipient = "r" }); check(c:commit(p).Success)
	local promoted = c.profile.Heroes.r; local actualLabor = Stats.GetEffectiveLabor(promoted)
	equal(promoted.Assignment, "FACILITY_CONDUIT"); equal(c.profile.Facilities.ManaConduit.AssignedHeroUUIDs[1], "r")
	check(actualLabor > beforeLabor); equal(actualLabor, p.After.Labor)
	check(Stats.GetManaConduitGemsPerMin(1, actualLabor, 1) > Stats.GetManaConduitGemsPerMin(1, beforeLabor, 1))
	c:request("STATE"); equal(Stats.GetEffectiveLabor(c.profile.Heroes.r), actualLabor)
end)

test("Focused imprint has guaranteed server-derived rank, half EXP and exact consumption", function()
	local c = context(); c.profile.Heroes.d = hero("d"); PitService.EnsureDefaults(c.profile)
	local p = c:preview({ Action = "IMPRINT", Recipient = "r", Donors = { "d" }, Imprint = "melee_memory", SuccessChance = 0, Rank = 100 })
	check(p.CanCommit); equal(p.SuccessChance, 1); equal(p.XP.Final, 65)
	equal(p.After.InheritedImprints.melee_memory, 1); check(c:commit(p).Success)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.r.InheritedImprints.melee_memory, 1)
	equal(c.profile.PitMaterials.ImprintCatalyst, 99); equal(c.profile.Currencies.Gold, 999800)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
end)

test("Five-star level-50 heroes receive explicitly disclosed memory-only imprints", function()
	local c = context(); c.profile.Heroes.r.Stars = 5; c.profile.Heroes.r.Level = 50
	c.profile.Heroes.d = hero("d"); PitService.EnsureDefaults(c.profile)
	local beforeATK = Stats.GetEffectiveCombatStats(c.profile.Heroes.r, false, false)
	local p = c:preview({ Action = "IMPRINT", Recipient = "r", Donors = { "d" }, Imprint = "melee_memory" })
	check(p.CanCommit); equal(p.XP.MemoryOnly, true); equal(p.XP.Final, 0); check(#p.Warnings > 0)
	equal(p.After.Level, 50); equal(p.After.XP, 0); equal(p.After.OverflowXP, 0)
	check(c:commit(p).Success); equal(c.profile.Heroes.d, nil)
	equal(c.profile.Heroes.r.InheritedImprints.melee_memory, 1); equal(c.profile.Heroes.r.Level, 50)
	check((Stats.GetEffectiveCombatStats(c.profile.Heroes.r, false, false)) > beforeATK)
	equal(c.profile.Currencies.Gold, 999800); equal(c.profile.PitMaterials.ImprintCatalyst, 99)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
end)

test("Imprint incompatibility, maximum rank, full slots and missing costs reject atomically", function()
	local scenarios = {
		function(c) end,
		function(c) c.profile.Heroes.d = hero("d"); c.profile.Heroes.r.InheritedImprints = { melee_memory = 3 } end,
		function(c) c.profile.Heroes.d = hero("d"); c.profile.Heroes.r.InheritedImprints = { conduit_memory = 1 } end,
		function(c) c.profile.Heroes.d = hero("d"); c.profile.PitMaterials.ImprintCatalyst = 0 end,
		function(c) c.profile.Heroes.d = hero("d"); c.profile.Currencies.Gold = 199 end,
	}
	for _, mutate in ipairs(scenarios) do
		local c = context(); mutate(c); PitService.EnsureDefaults(c.profile)
		rejectedWithoutMutation(c, "PREVIEW", { Action = "IMPRINT", Recipient = "r", Donors = { "d" }, Imprint = "melee_memory" })
	end
end)

test("Duplicate imprint attempts upgrade one slot to its bounded rank", function()
	local c = context()
	for rank = 1, 3 do
		local id = "imprint-donor-" .. rank; c.profile.Heroes[id] = hero(id); PitService.EnsureDefaults(c.profile)
		local p = c:preview({ Action = "IMPRINT", Recipient = "r", Donors = { id }, Imprint = "melee_memory" })
		check(p.CanCommit); check(c:commit(p).Success); equal(c.profile.Heroes.r.InheritedImprints.melee_memory, rank)
	end
	local count = 0; for _ in pairs(c.profile.Heroes.r.InheritedImprints) do count += 1 end
	equal(count, 1); close((Stats.GetImprintBonuses(c.profile.Heroes.r)), 0.06)
end)

test("Conversion grants exact essence once and no Gem/Gold or hero output", function()
	local c = context(); local startingGold, startingGems = c.profile.Currencies.Gold, c.profile.Currencies.Gems
	local p = c:preview({ Action = "CONVERSION", Donors = { "d", "e" } })
	equal(p.Rewards.SoulEssence, 8); equal(p.Rewards.Gems, nil); equal(p.Rewards.Gold, nil)
	check(c:commit(p).Success); equal(c.profile.PitMaterials.SoulEssence, 1008)
	equal(c.profile.Currencies.Gold, startingGold); equal(c.profile.Currencies.Gems, startingGems)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.e, nil)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
end)

test("Conversion-to-crafting loop is a finite resource sink", function()
	local c = context(); c.profile.PitMaterials.SoulEssence = 0; c.profile.PitMaterials.PromotionStone = 0
	local p = c:preview({ Action = "CONVERSION", Donors = { "d", "e" } }); check(c:commit(p).Success)
	p = c:preview({ Action = "CRAFT", Recipe = "PromotionStone" }); check(p.CanCommit)
	equal(p.Costs.SoulEssence, 8); equal(p.Costs.Gems, 20); equal(p.Costs.Gold, 100)
	check(c:commit(p).Success); equal(c.profile.PitMaterials.SoulEssence, 0); equal(c.profile.PitMaterials.PromotionStone, 1)
	equal(c.profile.Currencies.Gems, 9980); equal(c.profile.Currencies.Gold, 999900)
	equal(c.profile.Heroes.d, nil); equal(c.profile.Heroes.e, nil)
	rejectedWithoutMutation(c, "PREVIEW", { Action = "CRAFT", Recipe = "PromotionStone" })
	for _, recipe in pairs(Config.Recipes) do check(recipe.Gems > 0); check(recipe.Gold > 0); check(recipe.SoulEssence > 0) end
end)

test("Crafting rejects invalid recipes, invalid funds and accidental donor selections", function()
	for _, mutation in ipairs({
		function(p) p.Currencies.Gems = 19 end,
		function(p) p.Currencies.Gold = 99 end,
		function(p) p.PitMaterials.SoulEssence = 7 end,
		function(p) p.Currencies.Gold = -10 end,
		function(p) p.Currencies.Gems = 0 / 0 end,
		function(p) p.Currencies.Gems = math.huge end,
	}) do
		local c = context(); mutation(c.profile)
		local beforeGold, beforeGems = c.profile.Currencies.Gold, c.profile.Currencies.Gems
		local p = c:preview({ Action = "CRAFT", Recipe = "PromotionStone" }); equal(p.CanCommit, false)
		check(c.profile.Heroes.d); equal(c.profile.PitMaterials.PromotionStone, 100)
		check(c.profile.Currencies.Gold == beforeGold or (beforeGold ~= beforeGold and c.profile.Currencies.Gold ~= c.profile.Currencies.Gold))
		check(c.profile.Currencies.Gems == beforeGems or (beforeGems ~= beforeGems and c.profile.Currencies.Gems ~= c.profile.Currencies.Gems))
	end
	rejectedWithoutMutation(context(), "PREVIEW", { Action = "CRAFT", Recipe = "FreeSummon" })
	rejectedWithoutMutation(context(), "PREVIEW", { Action = "CRAFT", Recipe = "PromotionStone", Donors = { "d" } })
end)

test("Lock control invalidates previews and cannot unlock a unique or foreign hero", function()
	local c = context(); local p = c:preview(synthesis())
	check(c:request("LOCK", { Hero = "d", Locked = true }).Success); equal(c.profile.Heroes.d.Locked, true)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	check(c:request("LOCK", { Hero = "d", Locked = false }).Success); equal(c.profile.Heroes.d.Locked, false)
	c.profile.Heroes.d = hero("d", "hero_archon"); PitService.EnsureDefaults(c.profile)
	rejectedWithoutMutation(c, "LOCK", { Hero = "d", Locked = false })
	rejectedWithoutMutation(c, "LOCK", { Hero = "foreign-only", Locked = false })
	rejectedWithoutMutation(c, "LOCK", { Hero = "r", Locked = 0 })
end)

test("Deliberate unified unlock clears current and legacy favorite protection", function()
	local c = context(); local donor = c.profile.Heroes.d
	donor.Locked = true; donor.Favorite = true; donor.Favorited = true
	rejectedWithoutMutation(c, "PREVIEW", synthesis())
	local result = c:request("LOCK", { Hero = "d", Locked = false })
	check(result.Success); equal(donor.Locked, false); equal(donor.Favorite, false); equal(donor.Favorited, false)
	equal(result.Delta.Heroes.d.PitStatus.EligibleDonor, true)
	local p = c:preview(synthesis()); check(p.CanCommit); check(c:commit(p).Success)
	equal(c.profile.Heroes.d, nil)
end)

test("Two Masters' simultaneous valid operations affect only their own profiles", function()
	local c = context()
	local first = c:preview({ Action = "CONVERSION", Donors = { "d" } })
	local second = c:preview({ Action = "CONVERSION", Donors = { "e" } }, c.other)
	check(c:commit(first).Success); check(c:commit(second, nil, c.other).Success)
	equal(c.profile.Heroes.d, nil); check(c.profile.Heroes.e)
	equal(c.otherProfile.Heroes.e, nil); check(c.otherProfile.Heroes.d)
	equal(c.profile.PitMaterials.SoulEssence, 1004); equal(c.otherProfile.PitMaterials.SoulEssence, 1004)
end)

test("Combat EXP requires active participation, bounds awards and applies cooldown", function()
	local c = context(); local before = Math.Copy(c.profile)
	equal(c.service:GrantCombatXP(c.player, "r", 25), false); check(deepEqual(c.profile, before))
	c.profile.Heroes.r.Assignment = "SQUAD_SLOT_1"; c.profile.DeployedSquadOrder = { "r" }
	check(c.service:GrantCombatXP(c.player, "r", 1e9)); equal(c.profile.Heroes.r.Level, 2); equal(c.profile.Heroes.r.XP, 100)
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
	c.now += Config.CombatXP.Cooldown; check(c.service:GrantCombatXP(c.player, "r", 25))
	equal(c.profile.Heroes.r.XP, 125)
	for _, invalid in ipairs({ -1, 0, 0 / 0, math.huge }) do equal(c.service:GrantCombatXP(c.player, "r", invalid), false) end
	c.now += Config.CombatXP.Cooldown; c.profile.Heroes.r.CurrentStamina = 0
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
	c.profile.Heroes.r.CurrentStamina = 100; c.profile.Heroes.r.ComaUntilTimestamp = os.time() + 1000
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
end)

test("Combat EXP holds the player lock through replication and rejects reentrant grants", function()
	local c = context(); local p = c:preview(synthesis())
	c.profile.Heroes.r.Assignment = "SQUAD_SLOT_1"; c.profile.DeployedSquadOrder = { "r" }
	local nestedCommit, nestedGrant, callbackCount
	callbackCount = 0
	c.service.Dependencies.SyncCombatXP = function(player, uuid, after)
		callbackCount += 1
		equal(c.service.Locks[player], true)
		equal(after.XP, 25); equal(c.profile.Heroes[uuid].XP, 25)
		nestedCommit = c.service:Request(player, "COMMIT", { Token = p.Token, ConfirmRare = true })
		nestedGrant = c.service:GrantCombatXP(player, uuid, 25)
	end
	local ok, result = c.service:GrantCombatXP(c.player, "r", 25)
	check(ok); equal(result.Before.XP, 0); equal(result.After.XP, 25)
	equal(nestedCommit.Success, false); equal(nestedGrant, false); equal(callbackCount, 1)
	equal(c.profile.Heroes.r.XP, 25); check(c.profile.Heroes.d); equal(c.profile.PitRevision, 1)
	equal(c.service.Locks[c.player], nil)
	check(c:request("STATE").Success)
end)

test("Combat EXP replication exceptions preserve one committed award and release the lock", function()
	local c = context(); c.profile.Heroes.r.Assignment = "SQUAD_SLOT_1"; c.profile.DeployedSquadOrder = { "r" }
	c.service.Dependencies.SyncCombatXP = function() error("simulated combat replication error") end
	local ok, result = c.service:GrantCombatXP(c.player, "r", 25)
	check(ok); equal(result.Before.XP, 0); equal(result.After.XP, 25)
	equal(c.profile.Heroes.r.XP, 25); equal(c.profile.PitRevision, 1); equal(c.service.Locks[c.player], nil)
	equal(c.service:GrantCombatXP(c.player, "r", 25), false)
	equal(c.profile.Heroes.r.XP, 25); equal(c.profile.PitRevision, 1)
	check(c:request("STATE").Success)
end)

test("Missing profiles, unknown commands and forgotten sessions fail safely", function()
	local c = context()
	equal(c:request("STATE", nil, "disconnected-player").Success, false)
	rejectedWithoutMutation(c, "BAD_COMMAND", {})
	local p = c:preview(synthesis()); c.service:Forget(c.player)
	rejectedWithoutMutation(c, "COMMIT", { Token = p.Token })
	equal(c.service.LastPreview[c.player], nil); equal(c.service.Locks[c.player], nil)
end)

print(string.format("Pit regression tests: %d passed, %d failed", passed, failed))
if failed > 0 then error(tostring(failed) .. " Pit regression test(s) failed") end
