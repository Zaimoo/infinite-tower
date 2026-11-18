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

test("Floor 5 is the hand-authored Mossbound Court: sunken cenote spiral, Sunbridge stair, and 140x110 Boss Dais", function()
	local room = Layout.ForFloor(5)
	assert(room.Authored == "verdant:5" and room.Name == "Mossbound Court")
	assert(same(room, Layout.Get(5, 5)), "the authored floor 5 is not fixed")
	assert(not same(room, Layout.Get(5)), "floor 5 should not be the canonical layout")
	assert(room.Bottom == -6 and #room.ReturnLinks == 2, "floor 5 has a deep cenote chasm with two return ramps")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Crossing_Apex == "STAIRS" and paths.WestBastion_Apex == "RAMP" and paths.EastBastion_Apex == "RAMP")
	assert(room.Platforms.Basin.Name == "Cenote Rim" and room.Platforms.Crossing.Name == "Sunbridge")
	assert(room.Platforms.WestBastion.Name == "Northwest Tier" and room.Platforms.EastBastion.Name == "Northeast Tier")
	local apex = room.Platforms.Apex
	assert(apex.Name == "Mossbound Dais" and apex.Width == 140 and apex.Depth == 110 and apex.Y == 28)
	assert(room.EliteCount == 4)
	local routes = Layout.PatrolRoutes(5, 5)
	assert(routes.BASIN_LOOP and routes.GALLERY_WEST and routes.GALLERY_EAST and routes.BASTION_RING)
end)

test("Floor 11 is the hand-authored Cinder Gate: Varrash dune crest lookout, Toll House, Watch Kiln", function()
	local room = Layout.ForFloor(11)
	assert(room.Authored == "ashen:1" and room.Name == "Cinder Gate" and room.PathStyle == "VARRASH")
	assert(room.DirectTerrain == true and room.Liquid and room.Liquid.Dry == true)
	assert(same(room, Layout.Get(1, 11)), "the authored floor 11 is not fixed")
	assert(not same(room, Layout.Get(1)), "floor 11 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_Crossing == "RAMP" and paths.Crossing_Apex == nil, "Dune Crest is a dead-end ridge lookout")
	assert(paths.WestGallery_Apex == "RAMP" and paths.EastGallery_Apex == "RAMP")
	assert(room.Platforms.Basin.Name == "Ash Flats" and room.Platforms.Crossing.Name == "Dune Crest")
	assert(room.Platforms.WestGallery.Name == "Toll House" and room.Platforms.EastGallery.Name == "Watch Kiln")
	assert(room.Platforms.Apex.Name == "Cinder Gate" and room.EliteCount == 1)
	local totalMobs = 0
	for _, camp in room.Camps do
		assert(camp.Platform ~= "Crossing", "Dune Crest carries no camp")
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 16, "Floor 11 keeps 16 live camp mobs (got " .. totalMobs .. ")")
end)

test("Floor 12 is the hand-authored Buried Caravan: switchback trail, Caravanserai Roof deck, Spice Vault", function()
	local room = Layout.ForFloor(12)
	assert(room.Authored == "ashen:2" and room.Name == "Buried Caravan" and room.PathStyle == "VARRASH")
	assert(room.DirectTerrain == true and room.Decks.Crossing == true and room.Masonry == "VARRASH_DECK")
	assert(same(room, Layout.Get(2, 12)), "the authored floor 12 is not fixed")
	assert(not same(room, Layout.Get(2)), "floor 12 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_EastGallery == "RAMP" and paths.EastGallery_Crossing == "RAMP")
	assert(paths.Crossing_WestGallery == "RAMP" and paths.WestGallery_Apex == "RAMP")
	assert(paths.Basin_WestGallery == nil and paths.Crossing_Apex == nil, "Floor 12 is a single switchback trail")
	assert(room.Platforms.Basin.Name == "Wagon Circle" and room.Platforms.EastGallery.Name == "Strider's Ribs")
	assert(room.Platforms.Crossing.Name == "Caravanserai Roof" and room.Platforms.WestGallery.Name == "Spice Vault")
	assert(room.Platforms.Apex.Name == "Caravan Master's Tomb" and room.Platforms.Apex.X == 40)
	assert(room.EliteCount == 2)
	local totalMobs = 0
	for _, camp in room.Camps do
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 22, "Floor 12 keeps 22 live camp mobs (got " .. totalMobs .. ")")
end)

test("Floor 13 is the hand-authored Glasswind Ravine: chasm ledges, suspended Glass Arch, glass stairs, authored patrols", function()
	local room = Layout.ForFloor(13)
	assert(room.Authored == "ashen:3" and room.Name == "Glasswind Ravine" and room.PathStyle == "VARRASH")
	assert(room.DirectTerrain == true and room.Decks.Crossing == true and room.Masonry == "VARRASH_GLASS")
	assert(room.Suspended and room.Suspended.Platforms.Crossing and room.Suspended.Links.WestGallery_Crossing and room.Suspended.Links.EastGallery_Crossing and room.Suspended.Links.Crossing_Apex)
	assert(room.Bottom == -4 and #room.ReturnLinks == 2, "Floor 13 has ravine chasm and two Basin return ramps")
	assert(same(room, Layout.Get(3, 13)), "the authored floor 13 is not fixed")
	assert(not same(room, Layout.Get(3)), "floor 13 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_WestGallery == "RAMP" and paths.Basin_EastGallery == "RAMP")
	assert(paths.WestGallery_Crossing == "RAMP" and paths.EastGallery_Crossing == "RAMP")
	assert(paths.Crossing_Apex == "STAIRS" and paths.WestGallery_Apex == "RAMP")
	assert(paths.EastGallery_Apex == nil and paths.Basin_Crossing == nil, "Floor 13 east ledge reaches Apex only via the Glass Arch")
	assert(room.Platforms.Basin.Name == "Ravine Mouth" and room.Platforms.WestGallery.Name == "West Ledge")
	assert(room.Platforms.EastGallery.Name == "East Ledge" and room.Platforms.Crossing.Name == "Glass Arch")
	assert(room.Platforms.Apex.Name == "Lightning Scar" and room.EliteCount == 3)
	local routes = Layout.PatrolRoutes(3, 13)
	assert(routes.BASIN_LOOP and routes.WEST_LEDGE and routes.ARCH_CROSSING)
	assert(routes.GALLERY_WEST == nil and routes.GALLERY_EAST == nil, "authored patrols replace generic gallery routes on Floor 13")
	local totalMobs = 0
	for _, camp in room.Camps do
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 25, "Floor 13 keeps 25 live camp mobs (got " .. totalMobs .. ")")
end)

test("Floor 14 is the hand-authored Sunscar Fortress: Kiln Gate chokepoint, Scar Bridge, split bastions, Sunscar Throne", function()
	local room = Layout.ForFloor(14)
	assert(room.Authored == "ashen:4" and room.Name == "Sunscar Fortress" and room.PathStyle == "VARRASH")
	assert(room.DirectTerrain == true and room.Masonry == "VARRASH_FORTRESS")
	assert(room.Suspended and room.Suspended.Platforms.Crossing and room.Suspended.Links.WestGallery_EastGallery)
	assert(room.Bottom == -4 and #room.ReturnLinks == 2, "Floor 14 keeps chasm floor with two return ramps")
	assert(same(room, Layout.Get(4, 14)), "the authored floor 14 is not fixed")
	assert(not same(room, Layout.Get(4)), "floor 14 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_Crossing == "RAMP" and paths.Basin_WestGallery == nil and paths.Basin_EastGallery == nil,
		"Floor 14 Basin links solely to Kiln Gate")
	assert(paths.Crossing_WestGallery == "RAMP" and paths.Crossing_EastGallery == "RAMP")
	assert(paths.WestGallery_EastGallery == "RAMP" and paths.Crossing_Apex == nil)
	assert(paths.WestGallery_WestBastion == "RAMP" and paths.EastGallery_EastBastion == "RAMP")
	assert(paths.WestBastion_Apex == "RAMP" and paths.EastBastion_Apex == "RAMP")
	assert(room.Platforms.Basin.Name == "Ashmarket" and room.Platforms.Crossing.Name == "Kiln Gate")
	assert(room.Platforms.WestGallery.Name == "Glassblowers' Row" and room.Platforms.EastGallery.Name == "Cistern Barracks")
	assert(room.Platforms.WestBastion.Name == "West Kiln" and room.Platforms.EastBastion.Name == "Signal Tower")
	assert(room.Platforms.Apex.Name == "Sunscar Throne" and room.EliteCount == 4)
	local routes = Layout.PatrolRoutes(4, 14)
	assert(routes.BASIN_LOOP and routes.GALLERY_WEST and routes.GALLERY_EAST and routes.BASTION_RING and routes.SCAR_BRIDGE,
		"Floor 14 includes all generic routes plus SCAR_BRIDGE")
	local totalMobs = 0
	for _, camp in room.Camps do
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 35, "Floor 14 keeps 35 live camp mobs (got " .. totalMobs .. ")")
end)

test("Floor 15 is the hand-authored Colossus Dais: Elder Colossus body route, Shield & Crown flanks, Cinderhold Vent Dais", function()
	local room = Layout.ForFloor(15)
	assert(room.Authored == "ashen:5" and room.Name == "Colossus Dais" and room.PathStyle == "VARRASH")
	assert(room.DirectTerrain == true and room.Masonry == "VARRASH_DAIS")
	assert(room.Decks.Crossing and room.Decks.Apex and not room.Decks.WestGallery and not room.Decks.EastBastion)
	assert(room.Suspended and room.Suspended.Platforms.Crossing and room.Suspended.Platforms.Apex and room.Suspended.Links.WestGallery_Crossing and room.Suspended.Links.Crossing_WestBastion and room.Suspended.Links.Crossing_Apex)
	assert(room.Bottom == -6 and #room.ReturnLinks == 2, "Floor 15 keeps caldera chasm with two return ramps")
	assert(same(room, Layout.Get(5, 15)), "the authored floor 15 is not fixed")
	assert(not same(room, Layout.Get(5)), "floor 15 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_WestGallery == "RAMP" and paths.WestGallery_Crossing == "RAMP" and paths.Crossing_WestBastion == "RAMP")
	assert(paths.Basin_EastGallery == "RAMP" and paths.EastGallery_EastBastion == "RAMP")
	assert(paths.Crossing_Apex == "STAIRS" and paths.WestBastion_Apex == "RAMP" and paths.EastBastion_Apex == "RAMP")
	assert(paths.WestGallery_WestBastion == nil, "Floor 15 climbs through Crossing instead of direct WestGallery->WestBastion")
	assert(room.Platforms.Basin.Name == "Caldera Floor" and room.Platforms.WestGallery.Name == "Fallen Hand")
	assert(room.Platforms.Crossing.Name == "Elder's Chest" and room.Platforms.EastGallery.Name == "Broken Shield")
	assert(room.Platforms.WestBastion.Name == "Shoulder" and room.Platforms.EastBastion.Name == "Fallen Crown")
	assert(room.Platforms.Apex.Name == "Colossus Dais" and room.EliteCount == 4)
	local routes = Layout.PatrolRoutes(5, 15)
	assert(routes.BASIN_LOOP and routes.FOREARM and routes.SHIELD_CLIMB and routes.CROWN_RING)
	assert(routes.GALLERY_WEST == nil and routes.GALLERY_EAST == nil, "authored patrols replace generic gallery routes on Floor 15")
	local totalMobs = 0
	for _, camp in room.Camps do
		if camp.Platform == "Apex" then
			assert(camp.Boss == true, "Floor 15 Apex holds the Biome Boss")
		else
			totalMobs += camp.Size
		end
	end
	assert(totalMobs == 35, "Floor 15 keeps 35 live camp mobs plus the Boss (got " .. totalMobs .. ")")
end)

test("Floor 16 is the hand-authored Rimefall Approach: shoreline route and ice-floe chain across frozen lake", function()
	local room = Layout.ForFloor(16)
	assert(room.Authored == "frozen:1" and room.Name == "Rimefall Approach" and room.PathStyle == "WHITEGUARD")
	assert(room.DirectTerrain == true and room.Masonry == "GLACIER_SLAB")
	assert(room.Decks and room.Decks.FloeSouth and room.Decks.Crossing and room.Decks.FloeNorth)
	assert(room.Suspended and room.Suspended.Links.Basin_FloeSouth and room.Suspended.Links.FloeSouth_Crossing and room.Suspended.Links.Crossing_EastGallery and room.Suspended.Links.Crossing_FloeNorth and room.Suspended.Links.FloeNorth_Apex)
	assert(room.Bottom == 0 and #room.ReturnLinks == 0, "Floor 16 has no chasm")
	assert(same(room, Layout.Get(1, 16)), "the authored floor 16 is not fixed")
	assert(not same(room, Layout.Get(1)), "floor 16 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_WestGallery == "RAMP" and paths.WestGallery_Apex == "RAMP")
	assert(paths.Basin_FloeSouth == "RAMP" and paths.FloeSouth_Crossing == "RAMP" and paths.Crossing_EastGallery == "RAMP" and paths.Crossing_FloeNorth == "RAMP" and paths.FloeNorth_Apex == "RAMP")
	assert(room.Platforms.Basin.Name == "Snowfield" and room.Platforms.WestGallery.Name == "Hunters' Lodge")
	assert(room.Platforms.FloeSouth.Name == "South Floe" and room.Platforms.Crossing.Name == "Heart Floe" and room.Platforms.EastGallery.Name == "Fisher's Hut" and room.Platforms.FloeNorth.Name == "North Floe")
	assert(room.Platforms.Apex.Name == "Rimefall Shrine" and room.EliteCount == 1)
	local routes = Layout.PatrolRoutes(1, 16)
	assert(routes.BASIN_LOOP ~= nil and routes.GALLERY_WEST == nil and routes.GALLERY_EAST == nil)
	local totalMobs = 0
	for _, camp in room.Camps do
		assert(camp.Platform ~= "FloeSouth" and camp.Platform ~= "FloeNorth", "ExtraPlatforms hold no camps")
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 16, "Floor 16 keeps 16 live camp mobs (got " .. totalMobs .. ")")
end)

test("Floor 17 is the hand-authored Frozen Barracks: street lattice converging on Armory and stairs to Commander's Hall", function()
	local room = Layout.ForFloor(17)
	assert(room.Authored == "frozen:2" and room.Name == "Frozen Barracks" and room.PathStyle == "WHITEGUARD")
	assert(room.DirectTerrain == true and room.Masonry == "WHITEGUARD")
	assert(room.Liquid and room.Liquid.Dry == true)
	assert(room.Bottom == 0 and #room.ReturnLinks == 0, "Floor 17 has no chasm")
	assert(same(room, Layout.Get(2, 17)), "the authored floor 17 is not fixed")
	assert(not same(room, Layout.Get(2)), "floor 17 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_WestGallery == "RAMP" and paths.Basin_Crossing == "RAMP" and paths.Basin_EastGallery == "RAMP")
	assert(paths.WestGallery_Crossing == "RAMP" and paths.EastGallery_Crossing == "RAMP")
	assert(paths.WestGallery_Armory == "RAMP" and paths.Crossing_Armory == "RAMP" and paths.EastGallery_Armory == "RAMP")
	assert(paths.Armory_Apex == "STAIRS" and paths.Crossing_Apex == nil, "Floor 17 climbs to Commander's Hall only via Armory stairs")
	assert(room.Platforms.Basin.Name == "Parade Ground" and room.Platforms.WestGallery.Name == "West Barracks")
	assert(room.Platforms.Crossing.Name == "Mess Hall" and room.Platforms.EastGallery.Name == "East Barracks & Kennels")
	assert(room.Platforms.Armory.Name == "Armory" and room.Platforms.Apex.Name == "Commander's Hall" and room.EliteCount == 2)
	local routes = Layout.PatrolRoutes(2, 17)
	assert(routes.BASIN_LOOP ~= nil and routes.GALLERY_WEST == nil and routes.GALLERY_EAST == nil)
	local totalMobs = 0
	for _, camp in room.Camps do
		assert(camp.Platform ~= "Armory", "Armory holds no camp")
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 22, "Floor 17 keeps 22 live camp mobs (got " .. totalMobs .. ")")
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
	assert(varied >= 40, "only " .. varied .. " of 49 floors are reshaped")
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
