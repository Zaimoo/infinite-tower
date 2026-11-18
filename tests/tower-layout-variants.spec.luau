-- Per-floor layout variation specs (TowerLayout.Get(index, floorId)). Bundled by run.ps1 after the module
-- list; `nodes`, `register` and `require` come from the shim.
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local Graph = require(nodes["ServerScriptService.Core.TowerNavigationGraph"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function same(a: any, b: any): boolean
	for id, p in a.Platforms do
		local q = b.Platforms[id]
		if not q or q.X ~= p.X or q.Y ~= p.Y or q.Z ~= p.Z or q.Width ~= p.Width or q.Depth ~= p.Depth then return false end
	end
	for id in b.Platforms do
		if not a.Platforms[id] then return false end
	end
	return true
end

test("Floor 1 is the hand-authored Overgrown Threshold: fixed, and shaped differently from the canonical layout", function()
	local room = Layout.ForFloor(1)
	assert(room.Authored == "verdant:1" and room.Name == "Overgrown Threshold")
	assert(same(room, Layout.Get(1, 1)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(1)), "floor 1 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- The east glade rejoins the avenue instead of climbing to the Apex; the avenue ends in grand steps.
	assert(paths.EastGallery_Crossing == "RAMP" and paths.EastGallery_Apex == nil)
	assert(paths.Crossing_Apex == "STAIRS" and paths.WestGallery_Apex == "RAMP")
	local avenue = room.Platforms.Crossing
	assert(avenue.Name == "Processional Avenue" and avenue.Depth > avenue.Width, "the avenue runs north-south")
	assert(room.Platforms.Apex.X == 0, "the Dawn Gate is in line with the Sanctuary")
	assert(room.EliteCount == 1)
end)

test("Floor 2 is the hand-authored Broken Aqueduct: broken span, mill detour, off-centre Wellhead Shrine", function()
	local room = Layout.ForFloor(2)
	assert(room.Authored == "verdant:2" and room.Name == "Broken Aqueduct")
	assert(same(room, Layout.Get(2, 2)), "the authored floor 2 is not fixed")
	assert(not same(room, Layout.Get(2)), "floor 2 should not be the canonical layout")
	assert(room.Platforms.AqueductNorth ~= nil, "missing AqueductNorth platform")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- The aqueduct is broken mid-span: no link between AqueductSouth (Crossing) and AqueductNorth.
	assert(paths.Crossing_AqueductNorth == nil and paths.AqueductNorth_Crossing == nil)
	assert(paths.Crossing_Apex == nil)
	assert(paths.EastGallery_AqueductNorth == "RAMP" and paths.AqueductNorth_Apex == "RAMP")
	assert(paths.WestGallery_Apex == "STAIRS")
	assert(room.Platforms.Apex.X < 0, "the Wellhead Shrine sits off-centre to the west")
	assert(room.EliteCount == 2)
end)

test("Floor 3 is the hand-authored Rootway Crossing: gorge root bridges, Hollow Stump, and Root-Throne", function()
	local room = Layout.ForFloor(3)
	assert(room.Authored == "verdant:3" and room.Name == "Rootway Crossing")
	assert(same(room, Layout.Get(3, 3)), "the authored floor 3 is not fixed")
	assert(not same(room, Layout.Get(3)), "floor 3 should not be the canonical layout")
	assert(room.Bottom == -4 and #room.ReturnLinks == 2, "floor 3 has a gorge chasm with two return ramps")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_Crossing == "RAMP" and paths.Crossing_Apex == "STAIRS")
	assert(paths.WestGallery_Apex == "RAMP" and paths.EastGallery_Apex == "RAMP")
	assert(room.Platforms.Crossing.Name == "The Knot" and room.Platforms.WestGallery.Name == "Root Perch")
	assert(room.Platforms.EastGallery.Name == "Hollow Stump" and room.Platforms.Apex.Name == "Root-Throne")
	assert(room.EliteCount == 3)
end)

test("Floor 4 is the hand-authored Vinebound Bastion: walled compound, moat, wall-walks, and Inner Keep", function()
	local room = Layout.ForFloor(4)
	assert(room.Authored == "verdant:4" and room.Name == "Vinebound Bastion")
	assert(same(room, Layout.Get(4, 4)), "the authored floor 4 is not fixed")
	assert(not same(room, Layout.Get(4)), "floor 4 should not be the canonical layout")
	assert(room.Bottom == -4 and #room.ReturnLinks == 2, "floor 4 has a marsh moat with two return ramps")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Crossing_WestGallery == "RAMP" and paths.Crossing_EastGallery == "RAMP", "gatehouse wall-walks")
	assert(paths.Crossing_Apex == "STAIRS" and paths.WestBastion_Apex == "RAMP" and paths.EastBastion_Apex == "RAMP")
	assert(room.Platforms.Basin.Name == "Outer Ward" and room.Platforms.Crossing.Name == "Gatehouse")
	assert(room.Platforms.WestBastion.Name == "West Tower" and room.Platforms.EastBastion.Name == "East Tower")
	assert(room.Platforms.Apex.Name == "Inner Keep" and room.EliteCount == 4)
	assert(Layout.PatrolRoutes(4, 4).WALL_WALK ~= nil, "floor 4 includes the WALL_WALK patrol route")
end)

test("Every floor but the authored ones reshapes its own layout, the same way every time", function()
	local varied, bends = 0, 0
	for id = 2, 50 do
		local index = (id - 1) % 5 + 1
		local room = Layout.Get(index, id)
		assert(same(room, Layout.Get(index, id)), "floor " .. id .. " is not deterministic")
		assert(same(room, Layout.ForFloor(id)))
		if not same(room, Layout.Get(index)) then varied += 1 end
		for _, p in room.Platforms do
			if p.Bend then bends += 1 end
		end
	end
	assert(varied >= 45, "only " .. varied .. " of 49 floors are reshaped")
	assert(bends >= 15, "only " .. bends .. " winding paths")
end)

test("Every floor's layout is sound: no new problems, terraces in the room, ramps at most 15 degrees", function()
	for id = 1, 50 do
		local index = (id - 1) % 5 + 1
		local allowed = {}
		for _, problem in Layout.Validate(Layout.Get(index)) do allowed[problem] = true end
		local room = Layout.Get(index, id)
		for _, problem in Layout.Validate(room) do
			assert(allowed[problem], "floor " .. id .. ": " .. problem)
		end
		local p = room.Platforms
		assert(p.Sanctuary.X == 0 and p.Basin.X == 0, "floor " .. id .. " moved the Sanctuary or the Basin")
		for _, link in room.Links do
			local run = math.sqrt((link.BX - link.AX) ^ 2 + (link.BZ - link.AZ) ^ 2)
			assert(math.abs(link.BY - link.AY) / run <= math.tan(math.rad(15)) + 1e-6, "floor " .. id .. " " .. link.Id .. " is too steep")
			assert(p[link.From] and p[link.To], "floor " .. id .. " " .. link.Id .. " joins a missing terrace")
		end
	end
end)

test("Camps stand inside their terraces, never on a bend, and patrols walk on terraces and connectors", function()
	for id = 1, 50 do
		local index = (id - 1) % 5 + 1
		local room = Layout.Get(index, id)
		for _, camp in room.Camps do
			local terrace = room.Platforms[camp.Platform]
			assert(not terrace.Bend)
			assert(camp.Y == terrace.Y)
			assert(math.abs(camp.X - terrace.X) + camp.Radius <= terrace.Width / 2 and math.abs(camp.Z - terrace.Z) + camp.Radius <= terrace.Depth / 2,
				"floor " .. id .. " camp " .. camp.Id .. " spills off its terrace")
		end
		for routeId, route in Layout.PatrolRoutes(index, id) do
			for _, point in route do
				local onWalk = false
				for _, t in room.Platforms do
					if math.abs(point.X - t.X) <= t.Width / 2 + 0.01 and math.abs(point.Z - t.Z) <= t.Depth / 2 + 0.01 and math.abs(point.Y - t.Y) < 0.01 then onWalk = true end
				end
				for _, link in room.Links do
					for _, end_ in { { link.AX, link.AY, link.AZ }, { link.BX, link.BY, link.BZ } } do
						if math.abs(point.X - end_[1]) < 0.01 and math.abs(point.Y - end_[2]) < 0.01 and math.abs(point.Z - end_[3]) < 0.01 then onWalk = true end
					end
				end
				assert(onWalk, "floor " .. id .. " patrol " .. routeId .. " leaves the walkways")
			end
		end
		local apex = room.Platforms.Apex
		for _, spot in Layout.PortalSpots(index, id) do
			assert(spot.Y == apex.Y and math.abs(spot.X - apex.X) + 8 <= apex.Width / 2, "floor " .. id .. " boss portal off the Apex")
		end
	end
end)

test("On every floor heroes can route from the Sanctuary to every camp and to the Apex", function()
	for id = 1, 50 do
		local index = (id - 1) % 5 + 1
		local room = Layout.Get(index, id)
		local g = Graph.new(room)
		local s = room.Sanctuary
		local from = { X = s.X, Y = s.Y, Z = s.Z }
		local goals = {}
		for _, camp in room.Camps do table.insert(goals, { X = camp.X, Y = camp.Y, Z = camp.Z }) end
		for _, t in room.Platforms do table.insert(goals, { X = t.X, Y = t.Y, Z = t.Z }) end
		for _, goal in goals do
			local route = Graph.Route(g, from, goal)
			assert(#route > 0, string.format("floor %d: no route to (%.0f, %.0f, %.0f)", id, goal.X, goal.Y, goal.Z))
		end
	end
end)

print(string.format("tower-layout-variants: %d passed", passed))
