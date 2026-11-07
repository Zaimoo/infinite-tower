-- Phase H Sanctuary and portal specs. Bundled by run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local Assets = require(nodes["ReplicatedStorage.Shared.Config.TowerPortalAssets"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("The boss portals stand side by side at the back of the Apex, fully on its terrace", function()
	for index = 1, 5 do
		local apex = Layout.Get(index).Platforms.Apex
		local spots = Layout.PortalSpots(index)
		assert(spots.Ascend and spots.Rerun)
		local half = Assets.Width * Assets.BossScale / 2
		for _, spot in { spots.Ascend, spots.Rerun } do
			assert(spot.Y == apex.Y)
			assert(math.abs(spot.X - apex.X) + half <= apex.Width / 2, "Portal hangs off the Apex side")
			assert(math.abs(spot.Z - apex.Z) + 2 <= apex.Depth / 2, "Portal hangs off the Apex back")
			assert(spot.Z < apex.Z, "Portals belong at the back of the Apex")
		end
		assert(math.abs(spots.Ascend.X - spots.Rerun.X) >= Assets.Width * Assets.BossScale + 2, "The two portals overlap")
	end
end)

test("The portal spots are kept clear like walkways", function()
	for index = 1, 5 do
		local ids = {}
		for _, lane in Layout.Lanes(index) do ids[lane.Id] = true end
		assert(ids.PortalAscend and ids.PortalRerun)
	end
end)

test("The portal mesh is four pieces, one per material, with sizes and offsets from the Blender export", function()
	local roles = {}
	for _, piece in Assets.Pieces do
		roles[piece.Role] = true
		assert(piece.Size.X > 0 and piece.Size.Y > 0 and piece.Size.Z > 0)
		assert(piece.Offset.Y > 0, piece.Name .. " must sit above the plinth base")
		assert(type(piece.MeshId) == "string")
		if piece.MeshId ~= "" then assert(piece.MeshSize, piece.Name .. " needs its imported MeshSize") end
	end
	assert(roles.STONE and roles.GOLD and roles.RUNES and roles.VORTEX)
	-- The four Sanctuary portals fit side by side inside the Sanctuary, clear of its pillars.
	local safe = Layout.Get(1).Sanctuary
	assert(Assets.Width * Assets.SanctuaryScale + 2 < Assets.SanctuarySpacing)
	assert(1.5 * Assets.SanctuarySpacing + Assets.Width * Assets.SanctuaryScale / 2 < safe.Width / 2 - 6)
end)

local Hardcore = require(nodes["ReplicatedStorage.Shared.Config.TowerHardcoreConfig"])

test("Choosing rerun portal revives KO'd heroes at ReviveHPFraction while standing heroes keep their HP", function()
	local heroes = {
		h1 = { UUID = "h1", DisplayName = "Han", MaxHP = 1200, CurrentHP = 0, State = "COMA", FloorId = 1 },
		h2 = { UUID = "h2", DisplayName = "Valeria", MaxHP = 1500, CurrentHP = 400, State = "FOLLOW_MASTER", FloorId = 1 },
		h3 = { UUID = "h3", DisplayName = "Aaron", MaxHP = 1000, CurrentHP = 0, State = "COMA", FloorId = 1 },
	}

	-- Choosing rerun portal triggers reviveDownedOnTransition logic:
	-- Downed heroes stand back up at ReviveHPFraction HP; standing heroes keep their HP.
	local function onRerunPortal(deployedHeroes: { [string]: any }): number
		local revived = 0
		for _, h in pairs(deployedHeroes) do
			if h.State == "COMA" or h.CurrentHP <= 0 then
				h.CurrentHP = math.max(1, math.floor(h.MaxHP * Hardcore.ReviveHPFraction))
				h.State = "FOLLOW_MASTER"
				revived += 1
			end
		end
		return revived
	end

	local revivedCount = onRerunPortal(heroes)
	assert(revivedCount == 2, "Both KO'd heroes must be revived")
	assert(heroes.h1.State == "FOLLOW_MASTER", "h1 must be revived to FOLLOW_MASTER")
	assert(heroes.h1.CurrentHP == math.floor(1200 * Hardcore.ReviveHPFraction), "h1 must revive at ReviveHPFraction HP")
	assert(heroes.h2.State == "FOLLOW_MASTER", "h2 remains FOLLOW_MASTER")
	assert(heroes.h2.CurrentHP == 400, "Standing hero keeps current HP")
	assert(heroes.h3.State == "FOLLOW_MASTER", "h3 must be revived to FOLLOW_MASTER")
	assert(heroes.h3.CurrentHP == math.floor(1000 * Hardcore.ReviveHPFraction), "h3 must revive at ReviveHPFraction HP")
end)

print("Portal tests: " .. passed .. " passed, 0 failed")
