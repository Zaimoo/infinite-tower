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

print("Portal tests: " .. passed .. " passed, 0 failed")
