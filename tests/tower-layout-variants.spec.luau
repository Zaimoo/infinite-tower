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

test("Floor 6 is the hand-authored Sporelit Entry: a horseshoe round the glowpool, nothing across it", function()
	local room = Layout.ForFloor(6)
	assert(room.Authored == "fungal:6" and room.Name == "Sporelit Entry")
	assert(same(room, Layout.Get(1, 6)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(1)), "floor 6 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_Crossing == nil and paths.Basin_Apex == nil, "a path crosses the glowpool")
	assert(paths.EastGallery_Crossing == "STAIRS", "the Mason's Stair is not stairs")
	-- The bridge steps down onto the dais (every Crossing -> Apex path is a grand stair); the rest are ramps.
	assert(paths.Crossing_Apex == "STAIRS" and paths.WestGallery_Apex == "RAMP" and paths.Basin_WestGallery == "RAMP" and paths.Basin_EastGallery == "RAMP")
	assert(room.EliteCount == 1 and #room.Camps == 5)
	assert(room.Platforms.Crossing.Name == "Veinspan" and room.Platforms.Apex.Name == "Skylight Dais")
	local td = room.Terrain
	assert(td and td.Direct and td.Decks.Crossing and td.Decks.Sanctuary and room.Skylight)
	-- Terrain terraces sit on the voxel grid: smooth terrain renders exactly on a plane only at multiples of 4.
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
	end
	-- Every path keeps off the central glowpool and the Elder Cap island.
	local island, pool = td.Islands[1], td.Pools[1]
	for _, link in room.Links do
		for step = 0, 20 do
			local x = link.AX + (link.BX - link.AX) * step / 20
			local z = link.AZ + (link.BZ - link.AZ) * step / 20
			assert(math.sqrt((x - island.X) ^ 2 + (z - island.Z) ^ 2) > island.R + link.Width / 2 + 8, link.Id .. " runs over the Elder Cap island")
			assert(((x - pool.X) / pool.RX) ^ 2 + ((z - pool.Z) / pool.RZ) ^ 2 > 1, link.Id .. " runs through the glowpool")
		end
	end
	-- No camp in the glowpool, and the arrival area stays clear.
	for _, camp in room.Camps do
		assert(((camp.X - pool.X) / pool.RX) ^ 2 + ((camp.Z - pool.Z) / pool.RZ) ^ 2 > 1.4, camp.Id .. " is in the glowpool")
		assert(math.abs(camp.X) > 60 or camp.Z < room.Platforms.Basin.Z - 30, camp.Id .. " is in the arrival area")
	end
	-- The oculus opens over the dais.
	local apex = room.Platforms.Apex
	assert(math.abs(room.Skylight.X - apex.X) < apex.Width / 2 and math.abs(room.Skylight.Z - apex.Z) < apex.Depth / 2)
end)

test("Floor 6's terrain is the walking surface: flush under natural ground, recessed under decks, pools off the paths", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(6)
	local field = Terrain.Field(room, "fungal_hollow", 6)
	assert(field.Surface == Terrain.Surfaces.FUNGAL, "floor 6 uses the Fungal surface palette")
	assert(math.abs(field.LiquidLevel - (field.Bottom + room.Terrain.LiquidRise)) < 1e-6)
	for id, t in room.Platforms do
		local y, kind = field.Sample(t.X + 3, t.Z - 3)
		if room.Terrain.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, string.format("%s: ground %.2f is not flush with the walking plane %.2f", id, y, t.Y))
			assert(kind == "WALK" or kind == "TRAIL", id .. " is not walkway ground (" .. kind .. ")")
		end
	end
	-- Under the Veinspan bridge the east pool runs on; the Elder Cap stands on its island in the glowpool.
	local cross = room.Platforms.Crossing
	local _, under = field.Sample(cross.X + 4, cross.Z + 6)
	assert(under == "POOL", "no pool under the Veinspan (" .. under .. ")")
	local isle = room.Terrain.Islands[1]
	local iy, ik = field.Sample(isle.X, isle.Z)
	assert(ik == "ISLAND" and iy > field.LiquidLevel + 2, "the Elder Cap island does not rise out of the pool")
	local _, open = field.Sample(isle.X + 44, isle.Z)
	assert(open == "POOL", "the glowpool is missing round the island")
	-- Every ramp's centreline is walkable ground at its own height (SOFT under its surface).
	for _, link in room.Links do
		if link.Kind ~= "STAIRS" then
			for step = 1, 9 do
				local t = step / 10
				local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
				local want = link.AY + (link.BY - link.AY) * t
				local y = field.Sample(x, z)
				assert(math.abs(y - (want - 2)) < 0.05 or y < want - 2, link.Id .. " ground rises over the ramp")
				assert(y > want - 2.6, string.format("%s ground sags under the ramp (%.2f vs %.2f)", link.Id, y, want))
			end
		end
	end
end)

test("Floor 7 is the hand-authored Mycelium Galleries: a switchback up the lamp-gallery wall", function()
	local room = Layout.ForFloor(7)
	assert(room.Authored == "fungal:7" and room.Name == "Mycelium Galleries")
	assert(same(room, Layout.Get(2, 7)), "the authored floor is not fixed")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- East, back west over the span and up the gallery steps, east again to the vault; a shortcut onto the span.
	assert(paths.Basin_EastGallery == "RAMP" and paths.Basin_Crossing == "RAMP" and paths.EastGallery_Apex == "RAMP")
	assert(paths.Crossing_WestGallery == "STAIRS" and paths.WestGallery_Apex == "RAMP")
	assert(paths.Basin_WestGallery == nil and paths.Crossing_Apex == nil and paths.Basin_Apex == nil)
	assert(room.EliteCount == 2)
	local mobs = 0
	for _, camp in room.Camps do if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end end
	assert(mobs == 22, "floor 7 has " .. mobs .. " live mobs")
	local p = room.Platforms
	assert(p.EastGallery.Y < p.Crossing.Y and p.Crossing.Y < p.WestGallery.Y and p.WestGallery.Y < p.Apex.Y, "the switchback does not climb")
	assert(p.EastGallery.X > 0 and p.WestGallery.X < 0 and p.Apex.X > 0, "the switchback does not zig-zag")
	local td = room.Terrain
	-- The Netted Isle is a rounded terrain island, not a deck.
	assert(td and td.Direct and not td.Decks.Crossing and td.Shapes.Crossing and room.Skylight)
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
	end
	for _, pool in td.Pools do
		for _, link in room.Links do
			for step = 0, 20 do
				local x = link.AX + (link.BX - link.AX) * step / 20
				local z = link.AZ + (link.BZ - link.AZ) * step / 20
				-- Only the span pool may run under a path (the shortcut and the steps cross it to reach the bridge).
				local e = ((x - pool.X) / pool.RX) ^ 2 + ((z - pool.Z) / pool.RZ) ^ 2
				assert(e > 1 or (pool.X == p.Crossing.X and pool.Z == p.Crossing.Z), link.Id .. " runs through a pool")
			end
		end
	end
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local field = Terrain.Field(room, "fungal_hollow", 7)
	for id, t in room.Platforms do
		local y = field.Sample(t.X + 3, t.Z - 3)
		if td.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, id .. ": ground is not flush with the walking plane")
		end
	end
	-- The isle rises out of the span pool, and its rounded corners fall away (no square slab).
	local cross = p.Crossing
	local _, shore = field.Sample(cross.X + cross.Width / 2 + 14, cross.Z)
	assert(shore == "POOL", "no pool round the Netted Isle (" .. shore .. ")")
	local cornerY = field.Sample(cross.X + cross.Width / 2 - 1, cross.Z + cross.Depth / 2 - 1)
	assert(cornerY < cross.Y - 3, "the Netted Isle's corner is still square")
	local edgeY = field.Sample(cross.X + cross.Width / 2 - 1, cross.Z)
	assert(math.abs(edgeY - (cross.Y - 2)) < 1e-6, "the Netted Isle's edge is not flat where paths land")
end)

test("Floor 8 is the hand-authored Blooming Chasm: rope walkways over the chasm to a cap, an islet and the aqueduct", function()
	local room = Layout.ForFloor(8)
	assert(room.Authored == "fungal:8" and room.Name == "Blooming Chasm")
	assert(same(room, Layout.Get(3, 8)), "the authored floor is not fixed")
	assert(room.Platforms.Sanctuary.Name == "Lampkeepers' Rest", "the Sanctuary is the Lampkeepers' camp")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_WestGallery and paths.Basin_EastGallery and paths.WestGallery_Crossing and paths.EastGallery_Crossing)
	assert(paths.Crossing_Apex == "STAIRS" and paths.EastGallery_Apex == "RAMP")
	assert(paths.WestGallery_Apex == nil and paths.Basin_Crossing == nil, "the aqueduct is reached only from the islands")
	assert(room.EliteCount == 3)
	local mobs = 0
	for _, camp in room.Camps do if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end end
	assert(mobs == 25, "floor 8 has " .. mobs .. " live mobs")
	local td = room.Terrain
	assert(td.Decks.WestGallery and td.RoundDecks.WestGallery and td.Decks.Crossing, "the cap top and the aqueduct are decks")
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
	end
	-- The Violet Cap's patrol walks its rope walkway to the aqueduct (it has no path up).
	local routes = Layout.PatrolRoutes(3, 8)
	assert(routes.GALLERY_WEST and routes.GALLERY_EAST, "floor 8 lost a gallery patrol")
	local last = routes.GALLERY_WEST[#routes.GALLERY_WEST]
	assert(math.abs(last.Y - room.Platforms.Crossing.Y) < 1e-6, "the Violet Cap patrol does not reach the aqueduct")
	-- The walkways hang over open chasm: no ground rises under their middles; the terrain terraces are flush.
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local field = Terrain.Field(room, "fungal_hollow", 8)
	for _, link in room.Links do
		if td.Bridges[link.Id] then
			local x, z = (link.AX + link.BX) / 2, (link.AZ + link.BZ) / 2
			local y = field.Sample(x, z)
			assert(y < math.min(link.AY, link.BY) - 4.4, link.Id .. ": ground rises under the rope walkway")
		end
	end
	for id, t in room.Platforms do
		if not td.Decks[id] then
			local y = field.Sample(t.X + 3, t.Z - 3)
			assert(math.abs(y - (t.Y - 2)) < 1e-6, id .. ": ground is not flush with the walking plane")
		end
	end
end)

test("Floor 9 is the hand-authored Rotcap Keep: an H with a high keystone over the rot pit", function()
	local room = Layout.ForFloor(9)
	assert(room.Authored == "fungal:9" and room.Name == "Rotcap Keep")
	assert(same(room, Layout.Get(4, 9)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(4)), "floor 9 should not be the canonical layout")
	assert(room.Platforms.Sanctuary.Name == "The Broken Gate")
	assert(room.Platforms.Crossing.Name == "The Keystone" and room.Platforms.Apex.Name == "Keep of the Rotcap")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- The H shape: wings climb to rot-spires, high spans meet at The Keystone, stairs climb to the Keep.
	assert(paths.Basin_WestGallery == "RAMP" and paths.Basin_EastGallery == "RAMP")
	assert(paths.WestGallery_WestBastion == "RAMP" and paths.EastGallery_EastBastion == "RAMP")
	assert(paths.WestBastion_Crossing == "RAMP" and paths.EastBastion_Crossing == "RAMP")
	assert(paths.Crossing_Apex == "STAIRS")
	assert(paths.Basin_Crossing == nil and paths.Basin_Apex == nil and paths.WestBastion_Apex == nil and paths.EastBastion_Apex == nil,
		"floor 9 breaks the H shape")
	assert(room.EliteCount == 4)
	local mobs = 0
	for _, camp in room.Camps do if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end end
	assert(mobs == 35, "floor 9 has " .. mobs .. " live mobs")
	-- Both wings clear the chasm return ramps.
	for _, side in { "West", "East" } do
		local g = room.Platforms[side .. "Gallery"]
		assert(g.Z + g.Depth / 2 < 41, side .. "Gallery overlaps the chasm return ramp landing")
	end
	-- The bastion ring crosses The Keystone.
	local routes = Layout.PatrolRoutes(4, 9)
	assert(routes.BASTION_RING and routes.GALLERY_WEST and routes.GALLERY_EAST, "floor 9 lost patrol routes")
	local hitsKeystone = false
	for _, pt in routes.BASTION_RING do
		if math.abs(pt.X - room.Platforms.Crossing.X) <= room.Platforms.Crossing.Width / 2
			and math.abs(pt.Z - room.Platforms.Crossing.Z) <= room.Platforms.Crossing.Depth / 2 then
			hitsKeystone = true
		end
	end
	assert(hitsKeystone, "floor 9 bastion ring does not cross The Keystone")
end)

test("Floor 9's terrain is the walking surface: flush on terrain terraces, open under the high spans and Keystone", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(9)
	local td = room.Terrain
	assert(td and td.Direct and td.Decks.Crossing and td.Decks.Sanctuary and room.Skylight)
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
	end
	local field = Terrain.Field(room, "fungal_hollow", 9)
	for id, t in room.Platforms do
		local y = field.Sample(t.X + 3, t.Z - 3)
		if td.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, id .. ": ground is not flush with the walking plane")
		end
	end
	-- The rot pit runs under The Keystone; the high spans cross open ground/pools.
	local cross = room.Platforms.Crossing
	local _, underCross = field.Sample(cross.X, cross.Z + 12)
	assert(underCross == "POOL", "no rot pit under The Keystone (" .. underCross .. ")")
	for _, link in room.Links do
		if td.Bridges[link.Id] then
			local x, z = (link.AX + link.BX) / 2, (link.AZ + link.BZ) / 2
			local y = field.Sample(x, z)
			assert(y < math.min(link.AY, link.BY) - 4.4, link.Id .. ": ground rises under the high span")
		end
	end
end)

test("Floor 10 is the hand-authored Matriarch's Hollow: a ring round a central dais, reached only from the back", function()
	local room = Layout.ForFloor(10)
	assert(room.Authored == "fungal:10" and room.Name == "Matriarch's Hollow")
	assert(same(room, Layout.Get(5, 10)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(5)), "floor 10 should not be the canonical layout")
	assert(room.Platforms.Sanctuary.Name == "The Last Lamp")
	assert(room.Platforms.Crossing.Name == "Brood Pillar" and room.Platforms.Apex.Name == "Matriarch's Dais")
	local paths, intoApex = {}, 0
	for _, link in room.Links do
		paths[link.Id] = link.Kind
		if link.To == "Apex" or link.From == "Apex" then intoApex += 1 end
	end
	assert(#room.Links == 8, "floor 10 should have 8 paths round the ring, got " .. #room.Links)
	assert(paths.WestGallery_WestBastion == "STAIRS" and paths.EastGallery_EastBastion == "STAIRS")
	assert(paths.WestBastion_Crossing and paths.EastBastion_Crossing and paths.Crossing_Apex)
	assert(intoApex == 1, "the dais should have one way in (the Silk Stair from the Brood Pillar)")
	-- The dais sits in the middle of the floor, the Brood Pillar behind it at the back of the nest.
	local apex, cross, basin = room.Platforms.Apex, room.Platforms.Crossing, room.Platforms.Basin
	assert(apex.X == 0 and apex.Z > cross.Z + cross.Depth / 2 + apex.Depth / 2 and apex.Z < basin.Z - basin.Depth / 2 - apex.Depth / 2)
	for _, side in { "West", "East" } do
		local g, b = room.Platforms[side .. "Gallery"], room.Platforms[side .. "Bastion"]
		assert(math.abs(g.X) - g.Width / 2 > apex.Width / 2 + 40, side .. "Gallery crowds the dais")
		assert(math.abs(b.X) - b.Width / 2 > apex.Width / 2, side .. "Bastion crowds the dais")
	end
	-- Boss portals on the dais's south rim, facing the way the Masters walked round.
	assert(room.Portals and room.Portals.Side == "SOUTH")
	local routes = Layout.PatrolRoutes(5, 10)
	assert(routes.BASIN_LOOP and routes.GALLERY_WEST and routes.GALLERY_EAST and routes.BASTION_RING, "floor 10 lost patrol routes")
end)

test("Floor 10's terrain is the walking surface: a round mesa in a moat, open under the silk spans and Brood Pillar", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(10)
	local td = room.Terrain
	assert(td and td.Direct and td.Decks.Crossing and td.Decks.Sanctuary and room.Skylight)
	assert(td.NoApexShelf and td.Shapes.Apex and td.Shapes.Apex.Round)
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
	end
	local field = Terrain.Field(room, "fungal_hollow", 10)
	for id, t in room.Platforms do
		local y = field.Sample(t.X + 3, t.Z - 3)
		if td.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, id .. ": ground is not flush with the walking plane")
		end
	end
	local apex, cross = room.Platforms.Apex, room.Platforms.Crossing
	local _, underCross = field.Sample(cross.X, cross.Z + 12)
	assert(underCross == "POOL", "no brood pool under Brood Pillar (" .. underCross .. ")")
	-- The moat rings the dais on both flanks and in front of it, past the mesa's rock apron.
	for _, at in { { apex.X - apex.Width / 2 - 40, apex.Z }, { apex.X + apex.Width / 2 + 40, apex.Z }, { apex.X, apex.Z + apex.Depth / 2 + 40 } } do
		local y, kind = field.Sample(at[1], at[2])
		assert(kind == "POOL" and y < apex.Y - 20, "no moat round the dais at " .. at[1] .. ", " .. at[2])
	end
	-- No apex shelf: the ground behind the dais drops to the moat instead of a wall-high massif.
	local behind = field.Sample(apex.X, apex.Z - apex.Depth / 2 - 30)
	assert(behind < apex.Y - 10, "a shelf rises behind the dais")
	for _, link in room.Links do
		if td.Bridges[link.Id] then
			local x, z = (link.AX + link.BX) / 2, (link.AZ + link.BZ) / 2
			local y = field.Sample(x, z)
			assert(y < math.min(link.AY, link.BY) - 4.4, link.Id .. ": ground rises under the silk span")
		end
	end
end)

test("Fungal-owned terrain materials are used by no biome palette", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local owned = {}
	for _, m in Terrain.FungalMaterials do
		owned[m] = true
		assert(Terrain.MaterialColors[m] ~= nil, tostring(m) .. " has no Fungal colour")
	end
	for biome, palette in Terrain.Palettes do
		for key, m in palette :: any do
			assert(not owned[m], biome .. " palette " .. key .. " uses a Fungal-owned material")
		end
	end
	for key, m in Terrain.Surfaces.FUNGAL :: any do
		-- Basalt is the shared dark rock (one colour for every biome), so the Fungal peaks may use it.
		assert(owned[m] or m == Enum.Material.Basalt or Terrain.MaterialColors[m] == nil, "Fungal surface " .. key .. " uses another look's recoloured material")
	end
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

test("Floor 18 is the hand-authored Shattered Iceway: glacier spine, twin crevasse bridges, East Moraine via Upper Iceway", function()
	local room = Layout.ForFloor(18)
	assert(room.Authored == "frozen:3" and room.Name == "Shattered Iceway" and room.PathStyle == "WHITEGUARD")
	assert(room.DirectTerrain == true and room.Masonry == "GLACIER_SLAB")
	assert(room.Decks and room.Decks.Crossing and room.Decks.UpperIceway)
	assert(room.Suspended and room.Suspended.Links.Crossing_WestGallery and room.Suspended.Links.Crossing_EastGallery and room.Suspended.Links.EastGallery_UpperIceway)
	assert(room.Bottom == -4 and #room.ReturnLinks == 2, "Floor 18 has twin crevasses and two Basin return ramps")
	assert(same(room, Layout.Get(3, 18)), "the authored floor 18 is not fixed")
	assert(not same(room, Layout.Get(3)), "floor 18 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_Crossing == "RAMP" and paths.Crossing_UpperIceway == "RAMP")
	assert(paths.Crossing_WestGallery == "RAMP" and paths.Crossing_EastGallery == "RAMP")
	assert(paths.EastGallery_UpperIceway == "RAMP" and paths.UpperIceway_Apex == "STAIRS" and paths.WestGallery_Apex == "RAMP")
	assert(paths.EastGallery_Apex == nil, "Floor 18 East Moraine reaches Apex only via Upper Iceway")
	assert(room.Platforms.Basin.Name == "Moraine Foot" and room.Platforms.Crossing.Name == "Lower Iceway")
	assert(room.Platforms.UpperIceway.Name == "Upper Iceway" and room.Platforms.WestGallery.Name == "West Moraine")
	assert(room.Platforms.EastGallery.Name == "East Moraine" and room.Platforms.Apex.Name == "Icefall Gate" and room.EliteCount == 3)
	local routes = Layout.PatrolRoutes(3, 18)
	assert(routes.BASIN_LOOP and routes.WEST_MORAINE and routes.ICEWAY_CROSS and routes.EAST_CLIMB)
	assert(routes.GALLERY_WEST == nil and routes.GALLERY_EAST == nil, "authored patrols replace generic gallery routes on Floor 18")
	local totalMobs, upperElites = 0, 0
	for _, camp in room.Camps do
		assert(camp.Platform ~= "UpperIceway", "UpperIceway holds no camp")
		if camp.Platform ~= "Apex" then
			totalMobs += camp.Size
			if camp.Elite and camp.Y > 0 then upperElites += 1 end
		end
	end
	assert(upperElites >= 1, "Floor 18 places at least one Elite camp above entry level")
	assert(totalMobs == 25, "Floor 18 keeps 25 live camp mobs (got " .. totalMobs .. ")")
end)

test("Floor 19 is the hand-authored Whiteguard Keep: separated cave and battlement viaduct routes meeting at Keep Hall", function()
	local room = Layout.ForFloor(19)
	assert(room.Authored == "frozen:4" and room.Name == "Whiteguard Keep" and room.PathStyle == "WHITEGUARD")
	assert(room.DirectTerrain == true and room.Masonry == "WHITEGUARD_FORTRESS")
	assert(room.Decks and room.Decks.Crossing and room.Decks.EastGallery and room.Decks.EastBastion and room.Decks.Apex)
	assert(room.Suspended and room.Suspended.Links.Basin_Crossing)
	assert(room.Bottom == -4 and #room.ReturnLinks == 2, "Floor 19 has chasm floor and two Basin return ramps")
	assert(same(room, Layout.Get(4, 19)), "the authored floor 19 is not fixed")
	assert(not same(room, Layout.Get(4)), "floor 19 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_Crossing == "RAMP" and paths.Crossing_EastGallery == "RAMP" and paths.EastGallery_EastBastion == "RAMP" and paths.EastBastion_Apex == "RAMP")
	assert(paths.Basin_WestGallery == "RAMP" and paths.WestGallery_WestBastion == "RAMP" and paths.WestBastion_Apex == "RAMP")
	assert(paths.Crossing_WestGallery == "RAMP", "Floor 19 middle Crossing connects to left WestGallery via viaduct ramp")
	assert(paths.Basin_EastGallery == nil and paths.Crossing_Apex == nil and paths.WestGallery_EastGallery == nil,
		"Floor 19 west cave route and east battlement route only connect via Crossing")
	assert(room.Platforms.Basin.Name == "Siege Camp" and room.Platforms.Crossing.Name == "Viaduct Gate")
	assert(room.Platforms.EastGallery.Name == "East Bailey" and room.Platforms.EastBastion.Name == "Whiteguard Tower")
	assert(room.Platforms.WestGallery.Name == "Ice Cave Mouth" and room.Platforms.WestBastion.Name == "Crystal Grotto")
	assert(room.Platforms.Apex.Name == "Keep Hall" and room.EliteCount == 4)
	local routes = Layout.PatrolRoutes(4, 19)
	assert(routes.BASIN_LOOP and routes.GALLERY_WEST and routes.GALLERY_EAST and routes.BASTION_RING and routes.VIADUCT,
		"Floor 19 includes all generic routes plus VIADUCT")
	local totalMobs = 0
	for _, camp in room.Camps do
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 35, "Floor 19 keeps 35 live camp mobs (got " .. totalMobs .. ")")
end)

test("Floor 20 is the hand-authored Frostbound Throne: symmetric cathedral nave, transepts, chapels, and royal stair", function()
	local room = Layout.ForFloor(20)
	assert(room.Authored == "frozen:5" and room.Name == "Frostbound Throne" and room.PathStyle == "WHITEGUARD")
	assert(room.DirectTerrain == true and room.Masonry == "THRONE_HALL")
	assert(room.Decks and room.Decks.Crossing and room.Decks.WestGallery and room.Decks.EastGallery and room.Decks.WestBastion and room.Decks.EastBastion and room.Decks.Apex)
	assert(room.Suspended and room.Suspended.Links.Crossing_Apex and room.Suspended.Links.Crossing_WestGallery and room.Suspended.Links.Crossing_EastGallery)
	assert(room.Bottom == -6 and #room.ReturnLinks == 2, "Floor 20 has chasm floor and two Basin return ramps")
	assert(same(room, Layout.Get(5, 20)), "the authored floor 20 is not fixed")
	assert(not same(room, Layout.Get(5)), "floor 20 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Crossing_Apex == "STAIRS", "Floor 20 Crossing -> Apex is the Royal Stair")
	assert(paths.Crossing_WestGallery == "RAMP" and paths.Crossing_EastGallery == "RAMP", "Floor 20 has nave-to-aisle transepts")
	assert(paths.Basin_Crossing == "RAMP" and paths.Basin_WestGallery == nil and paths.Basin_EastGallery == nil,
		"Floor 20 Basin connects solely through the Antechamber Gate to Crossing")
	assert(paths.WestGallery_WestBastion == "RAMP" and paths.EastGallery_EastBastion == "RAMP")
	assert(paths.WestBastion_Apex == "RAMP" and paths.EastBastion_Apex == "RAMP")
	assert(room.Platforms.Basin.Name == "Frozen Antechamber" and room.Platforms.Crossing.Name == "Nave of Kneeling Knights")
	assert(room.Platforms.WestGallery.Name == "West Aisle" and room.Platforms.EastGallery.Name == "East Aisle")
	assert(room.Platforms.WestBastion.Name == "West Chapel" and room.Platforms.EastBastion.Name == "East Chapel")
	assert(room.Platforms.Apex.Name == "Frostbound Throne" and room.EliteCount == 4)
	local routes = Layout.PatrolRoutes(5, 20)
	assert(routes.BASIN_LOOP and routes.GALLERY_WEST and routes.GALLERY_EAST and routes.BASTION_RING and routes.TRANSEPT,
		"Floor 20 includes generic routes plus TRANSEPT")
	local totalMobs = 0
	for _, camp in room.Camps do
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 35, "Floor 20 keeps 35 live camp mobs (got " .. totalMobs .. ")")
end)

-- Terraces (including the Sanctuary), links and distinct walk heights (other than the Sanctuary's).
local function ladderCounts(room: any): (number, number, number)
	local terraces, levels, seen = 0, 0, {}
	for id, p in room.Platforms do
		terraces += 1
		if id ~= "Sanctuary" and not seen[p.Y] then
			seen[p.Y] = true
			levels += 1
		end
	end
	return terraces, #room.Links, levels
end

local function routeLength(room: any): number
	local g = Graph.new(room)
	local s, a = room.Sanctuary, room.Platforms.Apex
	local from = { X = s.X, Y = s.Y, Z = s.Z }
	local route = Graph.Route(g, from, { X = a.X, Y = a.Y, Z = a.Z })
	assert(#route > 0, "no route to the Apex")
	local length = 0
	for _, point in route do
		length += Graph.Distance(from, point)
		from = point
	end
	return length
end

test("Floor 21 is the hand-authored Slagworks Entry: a bigger room round a hub every route passes", function()
	local room = Layout.ForFloor(21)
	assert(room.Authored == "infernal:1" and room.Name == "Slagworks Entry" and room.PathStyle == "SOOTWRIGHT")
	assert(room.DirectTerrain == true and room.Surface == "SOOTWRIGHT" and room.Masonry == "FOUNDRY_IRON")
	assert(room.Width == 480 and room.Depth == 525 and room.Height == 160, "Floor 21 overrides its room size")
	assert(room.Bottom == 0 and #room.ReturnLinks == 0, "Floor 21 has no chasm")
	assert(same(room, Layout.Get(1, 21)), "the authored floor 21 is not fixed")
	assert(not same(room, Layout.Get(1)), "floor 21 should not be the canonical layout")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(paths.Basin_Weighbridge == "RAMP" and paths.Weighbridge_Crossing == "RAMP")
	assert(paths.Crossing_WestGallery and paths.Crossing_EastGallery and paths.Crossing_OreCrusher and paths.Crossing_CoalBunker)
	assert(paths.Crossing_Apex == "STAIRS", "the Furnace Steps climb from the Great Turntable")
	assert(paths.WestGallery_OreCrusher == "RAMP", "the rim track links the Sorting Shed to the Ore Crusher")
	assert(room.Suspended.Platforms.OreCrusher and room.Suspended.Links.Crossing_OreCrusher and room.Suspended.Links.WestGallery_OreCrusher)
	-- The hub: without the Great Turntable, the Ore Yard reaches nothing past the Weighbridge.
	local adjacent: { [string]: { string } } = {}
	for _, link in room.Links do
		if link.From ~= "Crossing" and link.To ~= "Crossing" then
			adjacent[link.From] = adjacent[link.From] or {}
			adjacent[link.To] = adjacent[link.To] or {}
			table.insert(adjacent[link.From], link.To)
			table.insert(adjacent[link.To], link.From)
		end
	end
	local reached, queue = { Basin = true }, { "Basin" }
	while #queue > 0 do
		local id = table.remove(queue) :: string
		for _, other in adjacent[id] or {} do
			if not reached[other] then
				reached[other] = true
				table.insert(queue, other)
			end
		end
	end
	for id in reached do
		assert(id == "Basin" or id == "Sanctuary" or id == "Weighbridge", "the Ore Yard reaches " .. id .. " without the turntable")
	end
	local p = room.Platforms
	assert(p.Crossing.Name == "Great Turntable" and p.Weighbridge.Name == "Weighbridge" and p.WestGallery.Name == "Sorting Shed")
	assert(p.EastGallery.Name == "Slag Tip" and p.OreCrusher.Name == "Ore Crusher" and p.CoalBunker.Name == "Coal Bunker" and p.Apex.Name == "Furnace Gate")
	-- Terrain terraces sit on 4-stud planes (smooth terrain only renders flush there); the rest are built decks.
	for id, t in p do
		if not room.Decks[id] then
			assert(t.Y % 4 == 0, id .. " is a terrain terrace off the 4-stud grid")
		end
	end
	local totalMobs = 0
	for _, camp in room.Camps do
		assert(camp.Platform ~= "Weighbridge" and camp.Platform ~= "OreCrusher" and camp.Platform ~= "CoalBunker", "ExtraPlatforms hold no camps")
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 16 and room.EliteCount == 1, "Floor 21 keeps 16 live camp mobs and 1 Elite")
	assert(Layout.PatrolRoutes(1, 21).BASIN_LOOP ~= nil)
end)

test("Floor 21 climbs the escalation ladder: bigger and more elaborate than every earlier first floor", function()
	local room = Layout.ForFloor(21)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 9 and links == 9 and levels == 8, string.format("Floor 21 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 1, 6, 11, 16 } do
		local t, l, v = ladderCounts(Layout.ForFloor(earlier))
		assert(terraces > t and links > l and levels > v, "Floor 21 does not beat floor " .. earlier)
	end
	local canonical = Layout.Get(1)
	assert(room.Width * room.Depth >= 1.25 * canonical.Width * canonical.Depth, "Floor 21's room is not grander")
	-- Bigger rooms, but the walk to the summit stays within half again the canonical floor's.
	local walk, base = routeLength(room), routeLength(canonical)
	assert(walk <= 1.5 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
	-- Every floor without its own Size keeps its per-index room size.
	local sized = { [21] = true, [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [31] = true, [32] = true, [33] = true, [34] = true, [35] = true, [36] = true }
	for id = 1, 50 do
		if not sized[id] then
			local r, c = Layout.ForFloor(id), Layout.Get((id - 1) % 5 + 1)
			assert(r.Width == c.Width and r.Depth == c.Depth and r.Height == c.Height and r.Bottom == c.Bottom, "floor " .. id .. " changed size")
		end
	end
end)

test("Floor 21's terrain: Sootwright ground, a slag tip heaped by the east spur, walkways untouched", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(21)
	local field = Terrain.Field(room, "infernal_foundry", 21)
	assert(field.Surface == Terrain.Surfaces.SOOTWRIGHT, "floor 21 uses the Sootwright surface")
	assert(field.Accent ~= nil, "the slag tips colour their own ground")
	-- The heap rises well over the yard somewhere along the fan, and shows clinker and glowing seams.
	local top, seams = -math.huge, 0
	for along = 4, 60, 4 do
		for across = -16, 16, 4 do
			local yaw = math.rad(-24)
			local x = 212 + math.sin(yaw) * along + math.cos(yaw) * across
			local z = -8 + math.cos(yaw) * along - math.sin(yaw) * across
			top = math.max(top, field.Height(x, z))
			local m = field.Accent(x, z)
			if m == Enum.Material.CrackedLava then seams += 1 end
		end
	end
	assert(top > field.Bottom + 14, "the slag tip does not heap up")
	assert(seams > 0, "the slag tip has no glowing seams")
	-- Terraces stay flush: the ground at every terrace centre is at or under its top.
	for id, t in room.Platforms do
		assert(field.Height(t.X, t.Z) <= t.Y + 0.01, id .. " is buried")
	end
end)

test("No terrain is made of a blocky material: every slope stays walkable", function()
	-- Brick and WoodPlanks terrain collides as 4-stud blocks however smoothly it is written, so a ramp or trail
	-- in them is a staircase heroes cannot climb (Floors 21-23's Sanctuary ramps, 2026-11-20).
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local blocky = {}
	for _, m in Terrain.BlockyMaterials do
		blocky[m] = true
	end
	assert(blocky[Enum.Material.Brick] and blocky[Enum.Material.WoodPlanks])
	for biome, palette in Terrain.Palettes do
		for key, m in palette :: any do
			assert(not blocky[m], biome .. " palette " .. key .. " is a blocky terrain material")
		end
	end
	for name, surface in Terrain.Surfaces do
		for key, m in surface :: any do
			assert(not blocky[m], name .. " surface " .. key .. " is a blocky terrain material")
		end
	end
	-- The Sootwright ground keeps to shared or uncoloured materials (it recolours nothing).
	for key, m in Terrain.Surfaces.SOOTWRIGHT :: any do
		for _, fungal in Terrain.FungalMaterials do
			assert(m ~= fungal, "Sootwright surface " .. key .. " uses a Fungal-owned material")
		end
	end
	local field = Terrain.Field(Layout.ForFloor(21), "infernal_foundry", 21)
	for _, link in Layout.ForFloor(21).Links do
		for t = 0, 1, 0.1 do
			local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
			local m = field.Accent and field.Accent(x, z)
			assert(not (m and blocky[m]), link.Id .. " crosses blocky slag")
		end
	end
end)

test("Floors 21-25's landmarks stand clear of every walkway and camp", function()
	local Infernal = require(nodes["ServerScriptService.Core.TowerSetPieces.InfernalFoundry"])
	local Infernal24 = require(nodes["ServerScriptService.Core.TowerSetPieces.InfernalFloor24"])
	local Infernal25 = require(nodes["ServerScriptService.Core.TowerSetPieces.InfernalFloor25"])
	assert(#Infernal.Floor21Landmarks >= 10, "Floor 21 needs at least 10 landmarks")
	assert(#Infernal.Floor22Landmarks >= 12, "Floor 22 needs at least 12 landmarks")
	assert(#Infernal.Floor23Landmarks >= 14, "Floor 23 needs at least 14 landmarks")
	assert(#Infernal24.Landmarks >= 16, "Floor 24 needs at least 16 landmarks")
	assert(#Infernal25.Landmarks >= 19, "Floor 25 needs at least 18 landmarks plus the Great Crucible")
	for floorId, list in { [21] = Infernal.Floor21Landmarks, [22] = Infernal.Floor22Landmarks, [23] = Infernal.Floor23Landmarks, [24] = Infernal24.Landmarks, [25] = Infernal25.Landmarks } do
	local room = Layout.ForFloor(floorId)
	local lanes = Layout.Lanes((floorId - 1) % 5 + 1, floorId)
	-- Separating-axis test between an axis-aligned rectangle and a lane's oriented strip (top-down).
	local function overlaps(lm: any, lane: any): boolean
		local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		local ux, uz = dx / len, dz / len
		local cx, cz = (lane.AX + lane.BX) / 2, (lane.AZ + lane.BZ) / 2
		local laneCorners = {}
		for _, s in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(laneCorners, { cx + ux * len / 2 * s[1] - uz * lane.HalfWidth * s[2], cz + uz * len / 2 * s[1] + ux * lane.HalfWidth * s[2] })
		end
		local rectCorners = {}
		for _, s in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(rectCorners, { lm.X + lm.HalfX * s[1], lm.Z + lm.HalfZ * s[2] })
		end
		for _, axis in { { 1, 0 }, { 0, 1 }, { ux, uz }, { -uz, ux } } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in rectCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				aMin, aMax = math.min(aMin, v), math.max(aMax, v)
			end
			for _, c in laneCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				bMin, bMax = math.min(bMin, v), math.max(bMax, v)
			end
			if aMax < bMin or bMax < aMin then
				return false
			end
		end
		return true
	end
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(not overlaps(lm, lane), lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				local nx = math.clamp(camp.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
				local nz = math.clamp(camp.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
				assert((nx - camp.X) ^ 2 + (nz - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " reaches into camp " .. camp.Id)
			end
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	end
end)

test("Floor 22 is the hand-authored Molten Assembly: a walkable crane girder between two piers, with a stem to the hall", function()
	local room = Layout.ForFloor(22)
	assert(room.Authored == "infernal:2" and room.Name == "Molten Assembly" and room.PathStyle == "SOOTWRIGHT")
	assert(room.DirectTerrain == true and room.Surface == "SOOTWRIGHT" and room.Masonry == "FOUNDRY_IRON")
	assert(room.Width == 550 and room.Depth == 615 and room.Height == 180 and room.Bottom == 0, "Floor 22 overrides its room size")
	assert(room.Skylight ~= nil, "the assembly hall is vaulted, lit by one oculus")
	assert(same(room, Layout.Get(2, 22)) and not same(room, Layout.Get(2)))
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- The girder: pier -> West Hoist -> Crane Trolley -> East Hoist -> pier, rising Y 8 to 12 (the failed jack).
	local girder = { "WestGallery_WestHoist", "WestHoist_Crossing", "Crossing_EastHoist", "EastHoist_EastGallery" }
	for _, id in girder do
		assert(paths[id] == "RAMP" and room.Suspended.Links[id] and room.GirderSpans[id], id .. " is not a free girder span")
	end
	local p = room.Platforms
	assert(p.WestGallery.Y < p.WestHoist.Y and p.WestHoist.Y < p.Crossing.Y and p.Crossing.Y < p.EastHoist.Y and p.EastHoist.Y < p.EastGallery.Y,
		"the girder tilts up from west to east")
	-- The piers join only through the girder nodes (no pier-to-pier or pier-to-trolley link).
	assert(paths.WestGallery_EastGallery == nil and paths.WestGallery_Crossing == nil and paths.Crossing_EastGallery == nil)
	-- Only the trolley's stem reaches the hall: trolley -> Inspection Gallery -> stair -> Assembly Hall; a loading
	-- ramp climbs from the yard to the trolley.
	assert(paths.Crossing_Inspection == "RAMP" and paths.Inspection_Apex == "STAIRS" and paths.Basin_Crossing == "RAMP")
	local toApex = 0
	for _, link in room.Links do
		if link.To == "Apex" or link.From == "Apex" then toApex += 1 end
	end
	assert(toApex == 1, "the Assembly Hall has one way in")
	assert(paths.WestGallery_PatternLoft and paths.EastGallery_ControlCab, "each pier carries its loft")
	for _, id in { "PatternLoft", "ControlCab" } do
		local degree = 0
		for _, link in room.Links do
			if link.From == id or link.To == id then degree += 1 end
		end
		assert(degree == 1, id .. " is a dead-end loft")
	end
	assert(p.Crossing.Name == "Crane Trolley" and p.Inspection.Name == "Inspection Gallery" and p.Apex.Name == "Assembly Hall")
	for id, t in p do
		if not room.Decks[id] then
			assert(t.Y % 4 == 0, id .. " is a terrain terrace off the 4-stud grid")
		end
	end
	local totalMobs = 0
	for _, camp in room.Camps do
		local extra = { WestHoist = true, EastHoist = true, Inspection = true, PatternLoft = true, ControlCab = true }
		assert(not extra[camp.Platform], "ExtraPlatforms hold no camps")
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 22 and room.EliteCount == 2, "Floor 22 keeps 22 live camp mobs and 2 Elites")
	-- The ladder: grander than Floor 21 and than every earlier second floor.
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 11 and links == 12 and levels == 10, string.format("Floor 22 has %d/%d/%d", terraces, links, levels))
	local t21, l21, v21 = ladderCounts(Layout.ForFloor(21))
	assert(terraces > t21 and links > l21 and levels > v21, "Floor 22 does not beat Floor 21")
	local r21 = Layout.ForFloor(21)
	assert(room.Width * room.Depth > r21.Width * r21.Depth, "Floor 22's hall is not bigger than Floor 21's yard")
	for _, earlier in { 2, 7, 12, 17 } do
		local t, l, v = ladderCounts(Layout.ForFloor(earlier))
		assert(terraces > t and links > l and levels > v, "Floor 22 does not beat floor " .. earlier)
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(2))
	assert(walk <= 1.5 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 23 is the hand-authored Furnace Causeway: a three-span causeway over lava with six bays off it like ribs", function()
	local room = Layout.ForFloor(23)
	assert(room.Authored == "infernal:3" and room.Name == "Furnace Causeway" and room.PathStyle == "SOOTWRIGHT")
	assert(room.Width == 625 and room.Depth == 700 and room.Height == 205 and room.Bottom == -4, "Floor 23 is a bigger hall over a lava chasm")
	assert(#room.ReturnLinks == 2, "return ramps climb from the lava shore")
	assert(same(room, Layout.Get(3, 23)) and not same(room, Layout.Get(3)))
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- The spine: South -> Mid -> North Causeway on stone piers, then the stair to the Furnace Mouth.
	for _, id in { "Basin_Crossing", "Crossing_MidCauseway", "MidCauseway_NorthCauseway" } do
		assert(paths[id] == "RAMP" and room.Suspended.Links[id] and room.StonePiers[id], id .. " is not a stone causeway span")
	end
	assert(paths.NorthCauseway_Apex == "STAIRS")
	local p = room.Platforms
	assert(p.Crossing.Y < p.MidCauseway.Y and p.MidCauseway.Y < p.NorthCauseway.Y and p.NorthCauseway.Y < p.Apex.Y, "the spine climbs north")
	-- Six ribs, two per span on alternate sides, each bay joined only to its span (and the catwalk).
	local spine = { Crossing = true, MidCauseway = true, NorthCauseway = true }
	local ribs = { WestGallery = "Crossing", SlagBay = "Crossing", EastGallery = "MidCauseway", CoolingBay = "MidCauseway",
		CastingBay = "NorthCauseway", BladeGallery = "NorthCauseway" }
	for bay, span in ribs do
		assert(paths[span .. "_" .. bay] == "RAMP", bay .. " is not a rib off " .. span)
		assert(math.abs(p[bay].Z - p[span].Z) < 1 and math.abs(p[bay].X) > 100, bay .. " does not open off its span")
		for _, link in room.Links do
			local other = if link.From == bay then link.To elseif link.To == bay then link.From else nil
			if other then
				assert(other == span or (bay == "EastGallery" and other == "BladeGallery") or (bay == "BladeGallery" and other == "EastGallery"),
					bay .. " joins " .. other)
			end
		end
	end
	assert(paths.EastGallery_BladeGallery == "RAMP", "the east catwalk joins the Quench Bay up to the Blade Gallery")
	for bay, span in ribs do
		assert(not spine[bay] and spine[span])
	end
	assert((p.WestGallery.X < 0) ~= (p.SlagBay.X < 0) and (p.EastGallery.X < 0) ~= (p.CoolingBay.X < 0) and (p.CastingBay.X < 0) ~= (p.BladeGallery.X < 0),
		"each span's two ribs go to opposite sides")
	for id, t in p do
		if not room.Decks[id] then
			assert(t.Y % 4 == 0, id .. " is a terrain terrace off the 4-stud grid")
		end
	end
	-- 25 mobs, 3 Elites, one Elite camp above the entry level; extra platforms hold none.
	local totalMobs, raisedElite = 0, false
	for _, camp in room.Camps do
		assert(ribs[camp.Platform] == nil or camp.Platform == "WestGallery" or camp.Platform == "EastGallery", "ExtraPlatforms hold no camps")
		assert(camp.Platform ~= "MidCauseway" and camp.Platform ~= "NorthCauseway")
		if camp.Platform ~= "Apex" then
			totalMobs += camp.Size
			if camp.Elite and camp.Y > p.Basin.Y then raisedElite = true end
		end
	end
	assert(totalMobs == 25 and room.EliteCount == 3 and raisedElite, "Floor 23 keeps 25 mobs, 3 Elites, one above the entry level")
	local routes = Layout.PatrolRoutes(3, 23)
	assert(routes.BASIN_LOOP and routes.SPINE and routes.CATWALK, "Floor 23 patrols the Basin, the spine and the catwalk")
	assert(routes.GALLERY_WEST == nil and routes.GALLERY_EAST == nil, "the authored patrols replace the generic ones")
	-- The ladder: grander than Floor 22 and every earlier third floor.
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 12 and links == 12 and levels == 11, string.format("Floor 23 has %d/%d/%d", terraces, links, levels))
	local t22, l22, v22 = ladderCounts(Layout.ForFloor(22))
	assert(terraces > t22 and links >= l22 and levels > v22, "Floor 23 does not beat Floor 22")
	local r22 = Layout.ForFloor(22)
	assert(room.Width * room.Depth > r22.Width * r22.Depth)
	for _, earlier in { 3, 8, 13, 18 } do
		local t, l, v = ladderCounts(Layout.ForFloor(earlier))
		assert(terraces > t and links > l and levels > v, "Floor 23 does not beat floor " .. earlier)
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(3))
	assert(walk <= 1.5 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 24 is the hand-authored Ironflame Bulwark: three strips split by lava channels, Sluice Towers, and The Pour", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(24)
	assert(room.Authored == "infernal:4" and room.Name == "Ironflame Bulwark" and room.PathStyle == "SOOTWRIGHT")
	assert(room.DirectTerrain == true and room.Surface == "SOOTWRIGHT" and room.Masonry == "FOUNDRY_IRON")
	assert(room.Width == 715 and room.Depth == 810 and room.Height == 230 and room.Bottom == -4, "Floor 24 is a 715x810x230 fortress over a lava chasm")
	assert(#room.ReturnLinks == 2, "return ramps climb from the lava shore")
	assert(same(room, Layout.Get(4, 24)) and not same(room, Layout.Get(4)))
	-- Signature shape: Basin links ONLY to Sanctuary and the West Gun Deck (The Pour blocks the centre).
	local basinOut = {}
	local paths = {}
	for _, link in room.Links do
		paths[link.Id] = link.Kind
		if link.From == "Basin" then table.insert(basinOut, link.To)
		elseif link.To == "Basin" and link.From ~= "Sanctuary" then table.insert(basinOut, link.From) end
	end
	assert(#basinOut == 1 and basinOut[1] == "WestGallery", "Floor 24's Basin must link only to the West Gun Deck")
	-- Strip-to-strip weave and elevated deck-to-deck spans are solid suspended iron bridges.
	for _, id in { "Basin_WestGallery", "PowderStore_WestBastion", "WestBastion_SignalBastion", "WestBastion_Apex",
		"WestGallery_WestSluice", "WestSluice_Crossing", "Crossing_IronflameForge", "Crossing_EastSluice",
		"EastSluice_EastGallery", "HammerHall_EastBastion", "EastBastion_Apex" } do
		assert(paths[id] == "RAMP" and room.Suspended.Links[id], id .. " is not a suspended iron bridge")
	end
	assert(room.Suspended.Platforms.WestSluice and room.Suspended.Platforms.EastSluice)
	assert(room.StonePiers.WestSluice and room.StonePiers.EastSluice)
	assert(paths.WestGallery_PowderStore == "STAIRS" and paths.EastGallery_HammerHall == "STAIRS")
	-- Terrain terraces sit on 4-stud planes; the rest are built iron decks.
	local p = room.Platforms
	for id, t in p do
		if not room.Decks[id] then
			assert(t.Y % 4 == 0, id .. " is a terrain terrace off the 4-stud grid")
		end
	end
	-- Terrain features: The Pour carves a molten pool south of Crossing, and Lava Falls paint glowing cliff ribbons.
	local field = Terrain.Field(room, "infernal_foundry", 24)
	assert(field.Kind(0, 86) == "POOL", "The Pour must carve a molten lava pit south of Ironflame Gate")
	assert(field.Kind(-115, 0) == "POOL" and field.Kind(115, -60) == "POOL", "both north-south lava channels must be molten pools")
	assert(field.Accent ~= nil and field.Accent(-340, -120) == Enum.Material.CrackedLava, "Lava Falls paint glowing lava ribbons on the cavern walls")
	for id, t in p do
		assert(field.Height(t.X, t.Z) <= t.Y + 0.01, id .. " is buried")
	end
	-- 35 live camp mobs, 4 Elites (all above entry level); ExtraPlatforms hold no camps.
	local extras = { PowderStore = true, SignalBastion = true, WestSluice = true, IronflameForge = true, EastSluice = true, HammerHall = true }
	local totalMobs, raisedElites = 0, 0
	for _, camp in room.Camps do
		assert(not extras[camp.Platform], "ExtraPlatform " .. camp.Platform .. " must hold no camp")
		if camp.Platform ~= "Apex" then
			totalMobs += camp.Size
			if camp.Elite and camp.Y > p.Basin.Y then raisedElites += 1 end
		end
	end
	assert(totalMobs == 35 and room.EliteCount == 4 and raisedElites == 4, "Floor 24 keeps 35 mobs and 4 raised Elites")
	local routes = Layout.PatrolRoutes(4, 24)
	assert(routes.BASIN_LOOP and routes.BASTION_RING and routes.WEST_STRIP and routes.WEAVE)
	-- The escalation ladder: strictly grander than Floor 23 and every earlier 4th floor (4, 9, 14, 19).
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 14 and links == 14 and levels == 12, string.format("Floor 24 has %d/%d/%d", terraces, links, levels))
	local t23, l23, v23 = ladderCounts(Layout.ForFloor(23))
	assert(terraces > t23 and links > l23 and levels > v23, "Floor 24 does not beat Floor 23")
	local r23 = Layout.ForFloor(23)
	assert(room.Width * room.Depth > r23.Width * r23.Depth)
	for _, earlier in { 4, 9, 14, 19 } do
		local t, l, v = ladderCounts(Layout.ForFloor(earlier))
		assert(terraces > t and links > l and levels > v, "Floor 24 does not beat floor " .. earlier)
	end
	-- Note on walking distance: in a 715x810 room with Sanctuary at Z+371, Apex at Z-320 (straight-line 691.6 >
	-- 1.5x canonical F4 = 683.0) and Basin linking only to West Gun Deck (X-230), the shortest walk stays under 2.0x.
	local walk, base = routeLength(room), routeLength(Layout.Get(4))
	assert(walk <= 2.0 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 25 is the hand-authored Titan's Crucible: an hourglass pinch with side chambers and the 170x124 Boss Dais", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(25)
	assert(room.Authored == "infernal:5" and room.Name == "Titan's Crucible" and room.PathStyle == "SOOTWRIGHT")
	assert(room.DirectTerrain == true and room.Surface == "SOOTWRIGHT" and room.Masonry == "FOUNDRY_IRON")
	assert(room.Width == 740 and room.Depth == 795 and room.Height == 250 and room.Bottom == -6, "Floor 25 is a 740x795x250 boss hall over a deep lava lake")
	assert(#room.ReturnLinks == 2, "return ramps climb from the lava shore")
	assert(same(room, Layout.Get(5, 25)) and not same(room, Layout.Get(5)))
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- Hourglass pinch: no Basin->Crossing and no Crossing->Apex, and every Basin->Apex route passes Pour Gate (Crossing).
	assert(paths.Basin_Crossing == nil and paths.Crossing_Apex == nil, "Floor 25 has no Basin->Crossing or Crossing->Apex")
	assert(paths.Basin_WestGallery == "STAIRS" and paths.Basin_EastGallery == "STAIRS")
	local adjacent: { [string]: { string } } = {}
	for _, link in room.Links do
		if link.From ~= "Crossing" and link.To ~= "Crossing" then
			adjacent[link.From] = adjacent[link.From] or {}
			adjacent[link.To] = adjacent[link.To] or {}
			table.insert(adjacent[link.From], link.To)
			table.insert(adjacent[link.To], link.From)
		end
	end
	local reached, queue = { Basin = true }, { "Basin" }
	while #queue > 0 do
		local id = table.remove(queue) :: string
		for _, other in adjacent[id] or {} do
			if not reached[other] then
				reached[other] = true
				table.insert(queue, other)
			end
		end
	end
	assert(not reached.Apex, "every Basin->Apex route on Floor 25 must pass through Pour Gate (Crossing)")
	local p = room.Platforms
	assert(p.Apex.Width == 170 and p.Apex.Depth == 124 and p.Apex.Y == 44, "Boss dais is 170x124 at Y44")
	for id, t in p do
		if not room.Decks[id] then
			assert(t.Y % 4 == 0, id .. " is a terrain terrace off the 4-stud grid")
		end
	end
	-- Terrain features: boiling lava lake beneath Pour Gate and six glowing wall lava falls.
	local field = Terrain.Field(room, "infernal_foundry", 25)
	assert(field.Kind(0, -46) == "POOL", "Floor 25 has a boiling lava lake beneath Pour Gate")
	assert(field.Accent ~= nil and field.Accent(-356, -100) == Enum.Material.CrackedLava, "Lava Falls paint glowing ribbons on the cavern walls")
	for id, t in p do
		assert(field.Height(t.X, t.Z) <= t.Y + 0.01, id .. " is buried")
	end
	-- 35 live camp mobs + Boss, 4 Elites; ExtraPlatforms hold no camps.
	local extras = { PatternShop = true, IngotStore = true, PourSpout = true, WestDuct = true, EastDuct = true, WestChainGallery = true, EastChainGallery = true }
	local totalMobs, hasBoss = 0, false
	for _, camp in room.Camps do
		assert(not extras[camp.Platform], "ExtraPlatform " .. camp.Platform .. " must hold no camp")
		if camp.Platform == "Apex" then
			hasBoss = camp.Boss == true
		else
			totalMobs += camp.Size
		end
	end
	assert(totalMobs == 35 and room.EliteCount == 4 and hasBoss, "Floor 25 keeps 35 live camp mobs, 4 Elites, and the Ember Titan boss")
	local routes = Layout.PatrolRoutes(5, 25)
	assert(routes.BASIN_LOOP and routes.LOWER_PINCH and routes.UPPER_PINCH and routes.CRUCIBLE_RING)
	assert(routes.GALLERY_WEST == nil and routes.GALLERY_EAST == nil and routes.BASTION_RING == nil)
	-- The escalation ladder: strictly grander than Floor 24 and every earlier 5th floor (5, 10, 15, 20).
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 15 and links == 16 and levels == 13, string.format("Floor 25 has %d/%d/%d", terraces, links, levels))
	local t24, l24, v24 = ladderCounts(Layout.ForFloor(24))
	assert(terraces > t24 and links > l24 and levels > v24, "Floor 25 does not beat Floor 24")
	local r24 = Layout.ForFloor(24)
	assert(room.Width * room.Depth > r24.Width * r24.Depth)
	for _, earlier in { 5, 10, 15, 20 } do
		local t, l, v = ladderCounts(Layout.ForFloor(earlier))
		assert(terraces > t and links > l and levels > v, "Floor 25 does not beat floor " .. earlier)
	end
end)

-- Which platforms a walker reaches from the Sanctuary without the given links.
local function reachable(room: any, without: { [string]: boolean }?): { [string]: boolean }
	local seen, queue = { Sanctuary = true }, { "Sanctuary" }
	while #queue > 0 do
		local at = table.remove(queue, 1)
		for _, link in room.Links do
			if not (without and without[link.Id]) then
				local other = if link.From == at then link.To elseif link.To == at then link.From else nil
				if other and not seen[other] then
					seen[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
	return seen
end

test("Floor 31 is the hand-authored Blighted Verge: a blight-brook forded four times, the Apex in the far corner", function()
	local room = Layout.ForFloor(31)
	assert(room.Authored == "corrupted:1" and room.Name == "Blighted Verge" and room.PathStyle == "HOLLIN")
	assert(same(room, Layout.Get(1, 31)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(1)), "floor 31 should not be the canonical layout")
	assert(room.Width == 540 and room.Depth == 580 and room.Height == 195 and room.Bottom == 0)
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(#room.Links == 13)
	assert(paths.Rothollow_Apex == "STAIRS", "the Rootstep Stairs are not stairs")
	for id, kind in paths do
		if id ~= "Rothollow_Apex" then assert(kind == "RAMP", id .. " should be a ramp") end
	end
	-- The brook rule: four fords cross it, and without them the Apex is out of reach.
	local fords = {}
	local count = 0
	for id in room.Fords do
		assert(paths[id] ~= nil, "ford " .. id .. " is not a path")
		fords[id] = true
		count += 1
	end
	assert(count == 4, "Floor 31 has four fords")
	assert(reachable(room).Apex, "the Apex is out of reach")
	local dry = reachable(room, fords)
	assert(not dry.Apex and not dry.Crossing and not dry.Rothollow, "a route reaches the rotten bank without fording the brook")
	assert(dry.LastGreen and dry.EastGallery and dry.WestGallery and dry.Woodcutters, "the south bank is cut off")
	-- The mill-race plank and the fallen log hang over the water; the stepping stones and the weir are causeways.
	local td = room.Terrain
	assert(td.Bridges.LastGreen_Crossing and td.Bridges.Crossing_EastGallery and td.BridgeStyles.Crossing_EastGallery == "LOG")
	assert(not td.Bridges.WestGallery_Crossing and not td.Bridges.EastGallery_Rothollow)
	-- The Apex sits in the far north-east corner.
	local apex = room.Platforms.Apex
	assert(apex.X > 0 and apex.Z < -150 and apex.Y == 28, "the Heartrot Spring is not in the north-east corner")
	-- Camps: 16 mobs, 1 Elite, none on an extra platform.
	local mobs = 0
	for _, camp in room.Camps do
		if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end
		assert(({ Basin = true, WestGallery = true, EastGallery = true, Crossing = true, Apex = true })[camp.Platform], camp.Id .. " stands on an extra platform")
	end
	assert(mobs == 16 and room.EliteCount == 1)
	-- Terrain terraces on the voxel grid; every height its own.
	local heights = {}
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
		if id ~= "Sanctuary" then
			assert(not heights[t.Y], id .. " shares a walk height")
			heights[t.Y] = true
		end
	end
end)

test("Floor 31 climbs the escalation ladder: bigger and more elaborate than every earlier first floor", function()
	local room = Layout.ForFloor(31)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 11 and links == 13 and levels == 10, string.format("Floor 31 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 1, 6, 11, 16, 21 } do
		local r = Layout.ForFloor(earlier)
		local t, l, v = ladderCounts(r)
		assert(terraces > t and links > l and levels > v, "Floor 31 does not beat floor " .. earlier)
		assert(room.Width * room.Depth > r.Width * r.Depth and room.Height > r.Height, "Floor 31's room is not grander than floor " .. earlier)
		assert(room.Platforms.Apex.Y > r.Platforms.Apex.Y, "Floor 31's Apex is not higher than floor " .. earlier .. "'s")
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(1))
	assert(walk <= 2 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 31's terrain is the walking surface: Hollin ground, the brook in its channel, open under the hung fords", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(31)
	local field = Terrain.Field(room, "corrupted_grove", 31)
	assert(field.Surface == Terrain.Surfaces.HOLLIN, "floor 31 uses the Hollin surface palette")
	for key, m in Terrain.Surfaces.HOLLIN :: any do
		for _, fungal in Terrain.FungalMaterials do
			assert(m ~= fungal, "Hollin surface " .. key .. " uses a Fungal-owned material")
		end
		-- Mud's rippled texture reads as water: only the brook bed is mud.
		assert(m ~= Enum.Material.Mud or key == "PoolBed", "Hollin surface " .. key .. " is mud")
	end
	assert(math.abs(field.LiquidLevel - (field.Bottom + room.Terrain.LiquidRise)) < 1e-6)
	assert(field.LiquidLevel < field.Bottom, "the brook does not sit in a channel below its banks")
	for id, t in room.Platforms do
		local y, kind = field.Sample(t.X + 3, t.Z - 3)
		if room.Terrain.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, string.format("%s: ground %.2f is not flush with the walking plane %.2f", id, y, t.Y))
			assert(kind == "WALK" or kind == "TRAIL", id .. " is not walkway ground (" .. kind .. ")")
		end
	end
	-- The brook runs on under the fallen log and past the mill.
	local log
	for _, link in room.Links do
		if link.Id == "Crossing_EastGallery" then log = link end
	end
	local wet = 0
	for step = 2, 8 do
		local t = step / 10
		local _, kind = field.Sample(log.AX + (log.BX - log.AX) * t, log.AZ + (log.BZ - log.AZ) * t)
		if kind == "POOL" then wet += 1 end
	end
	assert(wet > 0, "no water under the Fallen-Log Ford")
	local _, mill = field.Sample(95, -62)
	assert(mill == "POOL", "the mill race is dry (" .. mill .. ")")
	-- Every earthen ramp's centreline is walkable ground at its own height.
	for _, link in room.Links do
		if link.Kind ~= "STAIRS" and not room.Terrain.Bridges[link.Id] then
			for step = 1, 9 do
				local t = step / 10
				local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
				local want = link.AY + (link.BY - link.AY) * t
				local y = field.Sample(x, z)
				assert(math.abs(y - (want - 2)) < 0.05 or y < want - 2, link.Id .. " ground rises over the ramp")
				assert(y > want - 2.6, string.format("%s ground sags under the ramp (%.2f vs %.2f)", link.Id, y, want))
			end
		end
	end
end)

test("Floor 31's landmarks stand clear of every walkway and camp", function()
	local Grove = require(nodes["ServerScriptService.Core.TowerSetPieces.CorruptedGrove"])
	local list = Grove.Floor31Landmarks
	assert(#list >= 11, "Floor 31 needs at least 11 landmark footprints")
	local room = Layout.ForFloor(31)
	local lanes = Layout.Lanes(1, 31)
	local function overlaps(lm: any, lane: any): boolean
		local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		local ux, uz = dx / len, dz / len
		local cx, cz = (lane.AX + lane.BX) / 2, (lane.AZ + lane.BZ) / 2
		local laneCorners, rectCorners = {}, {}
		for _, sgn in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(laneCorners, { cx + ux * len / 2 * sgn[1] - uz * lane.HalfWidth * sgn[2], cz + uz * len / 2 * sgn[1] + ux * lane.HalfWidth * sgn[2] })
			table.insert(rectCorners, { lm.X + lm.HalfX * sgn[1], lm.Z + lm.HalfZ * sgn[2] })
		end
		for _, axis in { { 1, 0 }, { 0, 1 }, { ux, uz }, { -uz, ux } } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in rectCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				aMin, aMax = math.min(aMin, v), math.max(aMax, v)
			end
			for _, c in laneCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				bMin, bMax = math.min(bMin, v), math.max(bMax, v)
			end
			if aMax < bMin or bMax < aMin then return false end
		end
		return true
	end
	local tallest = 0
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		tallest = math.max(tallest, lm.Top)
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(not overlaps(lm, lane), lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				local nx = math.clamp(camp.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
				local nz = math.clamp(camp.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
				assert((nx - camp.X) ^ 2 + (nz - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " reaches into camp " .. camp.Id)
			end
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	assert(tallest >= 105, "Floor 31's tallest landmark is under the ladder's 105 studs")
	-- The two banks: the arrival is on the healthy one, the Heartrot Spring on the rotten one.
	assert(Grove.HealthyBank(0, 150) and not Grove.HealthyBank(130, -205))
end)

test("Floor 32 is the hand-authored Twisted Orchard: up and over the Graft Ridge into the hidden Pressing Hollow", function()
	local room = Layout.ForFloor(32)
	assert(room.Authored == "corrupted:2" and room.Name == "Twisted Orchard" and room.PathStyle == "HOLLIN")
	assert(same(room, Layout.Get(2, 32)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(2)), "floor 32 should not be the canonical layout")
	assert(room.Width == 620 and room.Depth == 640 and room.Height == 220 and room.Bottom == 0)
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(#room.Links == 15)
	assert(paths.Crossing_GraftedCrown == "STAIRS", "the Grafters' Stair is not stairs")
	assert(paths.GraftedCrown_Apex == "STAIRS", "the Press Stair is not stairs")
	for id, kind in paths do
		if id ~= "Crossing_GraftedCrown" and id ~= "GraftedCrown_Apex" then
			assert(kind == "RAMP", id .. " should be a ramp")
		end
	end
	-- The up-and-over rule: the Grafted Crown sits higher than the Apex, every link entering the Apex descends,
	-- and no link runs straight from the Basin, Galleries or Crossing to the Apex.
	local crown, apex = room.Platforms.GraftedCrown, room.Platforms.Apex
	assert(crown.Y > apex.Y, "the Grafted Crown must sit higher than the Pressing Hollow")
	local directBlocked = { Basin = true, WestGallery = true, EastGallery = true, Crossing = true }
	local intoApex = 0
	for _, link in room.Links do
		if link.To == "Apex" then
			intoApex += 1
			assert(not directBlocked[link.From], link.Id .. " bypasses the Graft Ridge")
			assert(room.Platforms[link.From].Y > apex.Y, link.Id .. " does not descend into the Pressing Hollow")
		elseif link.From == "Apex" then
			intoApex += 1
			assert(not directBlocked[link.To], link.Id .. " bypasses the Graft Ridge")
			assert(room.Platforms[link.To].Y > apex.Y, link.Id .. " does not descend into the Pressing Hollow")
		end
	end
	assert(intoApex == 3, "exactly three ridge crossings descend into the Pressing Hollow")
	-- Camps: 22 mobs, 2 Elites, none on an extra platform.
	local mobs = 0
	for _, camp in room.Camps do
		if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end
		assert(({ Basin = true, WestGallery = true, EastGallery = true, Crossing = true, Apex = true })[camp.Platform], camp.Id .. " stands on an extra platform")
	end
	assert(mobs == 22 and room.EliteCount == 2)
	-- Terrain terraces on the 4-stud grid; every terrace except Sanctuary has its own walk height.
	local td = room.Terrain
	local heights = {}
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
		if id ~= "Sanctuary" then
			assert(not heights[t.Y], id .. " shares a walk height")
			heights[t.Y] = true
		end
	end
end)

test("Floor 32 climbs the escalation ladder: bigger and more elaborate than Floor 31 and every earlier second floor", function()
	local room = Layout.ForFloor(32)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 13 and links == 15 and levels == 12, string.format("Floor 32 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 2, 7, 12, 17, 22, 31 } do
		local r = Layout.ForFloor(earlier)
		local t, l, v = ladderCounts(r)
		assert(terraces > t and links > l and levels > v, "Floor 32 does not beat floor " .. earlier)
		assert(room.Width * room.Depth > r.Width * r.Depth and room.Height > r.Height, "Floor 32's room is not grander than floor " .. earlier)
		assert(room.Platforms.Apex.Y > r.Platforms.Apex.Y, "Floor 32's Apex is not higher than floor " .. earlier .. "'s")
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(2))
	assert(walk <= 2 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 32's terrain is the walking surface: Hollin ground, orchard slope and solid Graft Ridge", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(32)
	local field = Terrain.Field(room, "corrupted_grove", 32)
	assert(field.Surface == Terrain.Surfaces.HOLLIN, "floor 32 uses the Hollin surface palette")
	for id, t in room.Platforms do
		local y, kind = field.Sample(t.X + 3, t.Z - 3)
		if room.Terrain.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, string.format("%s: ground %.2f is not flush with the walking plane %.2f", id, y, t.Y))
			assert(kind == "WALK" or kind == "TRAIL", id .. " is not walkway ground (" .. kind .. ")")
		end
	end
	-- The solid East Graft Ridge between GraftedCrown and Thorn Saddle rises above Y 52 to hide the hollow.
	local ridgeY = field.Height(76, -168)
	assert(ridgeY >= 52, string.format("the East Graft Ridge dips to %.1f (below Y 52)", ridgeY))
	-- Every earthen ramp's centreline is walkable ground at its own height.
	for _, link in room.Links do
		if link.Kind ~= "STAIRS" and not (room.Terrain.Bridges and room.Terrain.Bridges[link.Id]) then
			for step = 1, 9 do
				local t = step / 10
				local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
				local want = link.AY + (link.BY - link.AY) * t
				local y = field.Sample(x, z)
				assert(math.abs(y - (want - 2)) < 0.05 or y < want - 2, link.Id .. " ground rises over the ramp")
				assert(y > want - 2.6, string.format("%s ground sags under the ramp (%.2f vs %.2f)", link.Id, y, want))
			end
		end
	end
end)

test("Floor 32's landmarks stand clear of every walkway, camp and boss portal", function()
	local F32 = require(nodes["ServerScriptService.Core.TowerSetPieces.CorruptedFloor32"])
	local list = F32.Landmarks
	assert(#list >= 15, "Floor 32 needs at least 15 landmark footprints")
	local room = Layout.ForFloor(32)
	local lanes = Layout.Lanes(2, 32)
	local portals = Layout.PortalSpots(2, 32)
	local function overlaps(lm: any, lane: any): boolean
		local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		local ux, uz = dx / len, dz / len
		local cx, cz = (lane.AX + lane.BX) / 2, (lane.AZ + lane.BZ) / 2
		local laneCorners, rectCorners = {}, {}
		for _, sgn in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(laneCorners, { cx + ux * len / 2 * sgn[1] - uz * lane.HalfWidth * sgn[2], cz + uz * len / 2 * sgn[1] + ux * lane.HalfWidth * sgn[2] })
			table.insert(rectCorners, { lm.X + lm.HalfX * sgn[1], lm.Z + lm.HalfZ * sgn[2] })
		end
		for _, axis in { { 1, 0 }, { 0, 1 }, { ux, uz }, { -uz, ux } } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in rectCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				aMin, aMax = math.min(aMin, v), math.max(aMax, v)
			end
			for _, c in laneCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				bMin, bMax = math.min(bMin, v), math.max(bMax, v)
			end
			if aMax < bMin or bMax < aMin then return false end
		end
		return true
	end
	local tallest = 0
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		tallest = math.max(tallest, lm.Top)
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(not overlaps(lm, lane), lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				local nx = math.clamp(camp.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
				local nz = math.clamp(camp.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
				assert((nx - camp.X) ^ 2 + (nz - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " reaches into camp " .. camp.Id)
			end
		end
		for pName, p in portals do
			local nx = math.clamp(p.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
			local nz = math.clamp(p.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
			assert((nx - p.X) ^ 2 + (nz - p.Z) ^ 2 >= 12 * 12, lm.Id .. " covers portal " .. pName)
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	assert(tallest >= 125, "Floor 32's tallest landmark is under the ladder's 125 studs")
end)

test("Floor 33 is the hand-authored Briar Labyrinth: centred Thornheart Court, false east dead-end and west maze", function()
	local room = Layout.ForFloor(33)
	assert(room.Authored == "corrupted:3" and room.Name == "Briar Labyrinth" and room.PathStyle == "HOLLIN")
	assert(same(room, Layout.Get(3, 33)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(3)), "floor 33 should not be the canonical layout")
	assert(room.Width == 680 and room.Depth == 720 and room.Height == 250 and room.Bottom == -6)
	assert(#room.ReturnLinks == 2, "Floor 33 has a thorn pit chasm with two Basin return ramps")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(#room.Links == 17)
	assert(paths.ThornheartSteps_Apex == "STAIRS", "the Thornheart Steps are not stairs")
	assert(paths.Crossing_Apex == nil and paths.Apex_Crossing == nil, "Briar Gate must not link directly across the pit to the Court")
	for id, kind in paths do
		if id ~= "ThornheartSteps_Apex" then
			assert(kind == "RAMP", id .. " should be a ramp")
		end
	end
	-- Centred Apex: Thornheart Court sits in the exact middle of the room.
	local apex = room.Platforms.Apex
	assert(math.abs(apex.X) <= 10 and math.abs(apex.Z) <= room.Depth / 6, "Thornheart Court is not centred in the room")
	-- The maze rule: removing HangingGarden_Apex and ThornheartSteps_Apex leaves the Apex unreachable;
	-- and Thornwrack is a dead end (degree 1).
	local degree: { [string]: number } = {}
	local adj: { [string]: { string } } = {}
	for _, link in room.Links do
		degree[link.From] = (degree[link.From] or 0) + 1
		degree[link.To] = (degree[link.To] or 0) + 1
		if link.Id ~= "HangingGarden_Apex" and link.Id ~= "ThornheartSteps_Apex" then
			adj[link.From] = adj[link.From] or {}
			adj[link.To] = adj[link.To] or {}
			table.insert(adj[link.From], link.To)
			table.insert(adj[link.To], link.From)
		end
	end
	assert(degree.Thornwrack == 1, "Thornwrack must be a dead end (degree " .. tostring(degree.Thornwrack) .. ")")
	local seen, queue = { Basin = true }, { "Basin" }
	while #queue > 0 do
		local id = table.remove(queue) :: string
		for _, other in adj[id] or {} do
			if not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	assert(not seen.Apex, "Thornheart Court is reachable without HangingGarden_Apex or ThornheartSteps_Apex")
	-- Camps: 25 live mobs, 3 Elites, none on extra platforms.
	local mobs = 0
	for _, camp in room.Camps do
		if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end
		assert(({ Basin = true, WestGallery = true, EastGallery = true, Crossing = true, Apex = true })[camp.Platform], camp.Id .. " stands on an extra platform")
	end
	assert(mobs == 25 and room.EliteCount == 3)
	-- Terrain terraces on 4-stud planes; every terrace except Sanctuary has its own walk height.
	local td = room.Terrain
	local heights = {}
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
		if id ~= "Sanctuary" then
			assert(not heights[t.Y], id .. " shares a walk height")
			heights[t.Y] = true
		end
	end
end)

test("Floor 33 climbs the escalation ladder: bigger and more elaborate than Floor 32 and every earlier third floor", function()
	local room = Layout.ForFloor(33)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 15 and links == 17 and levels == 14, string.format("Floor 33 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 3, 8, 13, 18, 23, 32 } do
		local r = Layout.ForFloor(earlier)
		local t, l, v = ladderCounts(r)
		assert(terraces > t and links > l and levels > v, "Floor 33 does not beat floor " .. earlier)
		assert(room.Width * room.Depth > r.Width * r.Depth and room.Height > r.Height, "Floor 33's room is not grander than floor " .. earlier)
		assert(room.Platforms.Apex.Y > r.Platforms.Apex.Y, "Floor 33's Apex is not higher than floor " .. earlier .. "'s")
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(3))
	assert(walk <= 2.2 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 33's terrain is the walking surface: corrupted BLIGHT pit fissures, crags and Thornheart mound", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(33)
	local field = Terrain.Field(room, "corrupted_grove", 33)
	assert(field.Surface == Terrain.Surfaces.BLIGHT, "floor 33 uses the corrupted BLIGHT surface palette")
	assert(room.Terrain.Blight ~= nil, "floor 33 enables corrupted pit fissures and crags")
	assert(room.Terrain.NoApexShelf == true and #room.Terrain.Pools == 0, "floor 33 has no water pools and no apex shelf")
	for id, t in room.Platforms do
		local y, kind = field.Sample(t.X + 3, t.Z - 3)
		if room.Terrain.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, string.format("%s: ground %.2f is not flush with the walking plane %.2f", id, y, t.Y))
			assert(kind == "WALK" or kind == "TRAIL", id .. " is not walkway ground (" .. kind .. ")")
		end
	end
	-- The rocky briar mound under the Thornheart rises cleanly above the pit floor.
	local moundY = field.Height(0, -166)
	assert(moundY >= 20, string.format("the Thornheart mound dips to %.1f (below Y 20)", moundY))
	-- Every earthen ramp's centreline is walkable ground at its own height.
	for _, link in room.Links do
		if link.Kind ~= "STAIRS" and not (room.Terrain.Bridges and room.Terrain.Bridges[link.Id]) then
			for step = 1, 9 do
				local t = step / 10
				local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
				local want = link.AY + (link.BY - link.AY) * t
				local y = field.Sample(x, z)
				assert(math.abs(y - (want - 2)) < 0.05 or y < want - 2, link.Id .. " ground rises over the ramp")
				assert(y > want - 2.6, string.format("%s ground sags under the ramp (%.2f vs %.2f)", link.Id, y, want))
			end
		end
	end
end)

test("Floor 33's landmarks stand clear of every walkway, camp and boss portal", function()
	local F33 = require(nodes["ServerScriptService.Core.TowerSetPieces.CorruptedFloor33"])
	local list = F33.Landmarks
	assert(#list >= 17, "Floor 33 needs at least 17 landmark footprints")
	local room = Layout.ForFloor(33)
	local lanes = Layout.Lanes(3, 33)
	local portals = Layout.PortalSpots(3, 33)
	local function overlaps(lm: any, lane: any): boolean
		local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		local ux, uz = dx / len, dz / len
		local cx, cz = (lane.AX + lane.BX) / 2, (lane.AZ + lane.BZ) / 2
		local laneCorners, rectCorners = {}, {}
		for _, sgn in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(laneCorners, { cx + ux * len / 2 * sgn[1] - uz * lane.HalfWidth * sgn[2], cz + uz * len / 2 * sgn[1] + ux * lane.HalfWidth * sgn[2] })
			table.insert(rectCorners, { lm.X + lm.HalfX * sgn[1], lm.Z + lm.HalfZ * sgn[2] })
		end
		for _, axis in { { 1, 0 }, { 0, 1 }, { ux, uz }, { -uz, ux } } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in rectCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				aMin, aMax = math.min(aMin, v), math.max(aMax, v)
			end
			for _, c in laneCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				bMin, bMax = math.min(bMin, v), math.max(bMax, v)
			end
			if aMax < bMin or bMax < aMin then return false end
		end
		return true
	end
	local tallest = 0
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		tallest = math.max(tallest, lm.Top)
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(not overlaps(lm, lane), lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				local nx = math.clamp(camp.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
				local nz = math.clamp(camp.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
				assert((nx - camp.X) ^ 2 + (nz - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " reaches into camp " .. camp.Id)
			end
		end
		for pName, p in portals do
			local nx = math.clamp(p.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
			local nz = math.clamp(p.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
			assert((nx - p.X) ^ 2 + (nz - p.Z) ^ 2 >= 12 * 12, lm.Id .. " covers portal " .. pName)
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	assert(tallest >= 150, "Floor 33's tallest landmark is under the ladder's 150 studs")
end)

test("Floor 34 is the hand-authored Heartrot Stronghold: five elder trunks, Bole Stair and back-west Heartrot Crown", function()
	local room = Layout.ForFloor(34)
	assert(room.Authored == "corrupted:4" and room.Name == "Heartrot Stronghold" and room.PathStyle == "HOLLIN")
	assert(same(room, Layout.Get(4, 34)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(4)), "floor 34 should not be the canonical layout")
	assert(room.Width == 750 and room.Depth == 795 and room.Height == 275 and room.Bottom == -6)
	assert(#room.ReturnLinks == 2, "Floor 34 has a rot bog chasm with two Basin return ramps")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(#room.Links == 19)
	assert(paths.LowerBole_MiddleFork == "STAIRS", "the Bole Stair is not stairs")
	for id, kind in paths do
		if id ~= "LowerBole_MiddleFork" then
			assert(kind == "RAMP", id .. " should be a ramp")
		end
	end
	-- Back-west high Apex: Heartrot Crown sits in the Great Rotwood's fork, highest terrace on the floor,
	-- entered from exactly three links (WestBastion, MiddleFork, CanopyWalk).
	local apex = room.Platforms.Apex
	assert(apex.X < -100 and apex.Z < -250, "Heartrot Crown is not back-west")
	for id, p in room.Platforms do
		if id ~= "Apex" then
			assert(apex.Y > p.Y, id .. " sits as high as Heartrot Crown")
		end
	end
	local apexEntries = {}
	for _, link in room.Links do
		if link.To == "Apex" then apexEntries[link.From] = true
		elseif link.From == "Apex" then apexEntries[link.To] = true end
	end
	assert(apexEntries.WestBastion and apexEntries.MiddleFork and apexEntries.CanopyWalk, "Heartrot Crown needs WestBastion, MiddleFork and CanopyWalk entries")
	local entryCount = 0
	for _ in apexEntries do entryCount += 1 end
	assert(entryCount == 3, "exactly three links enter Heartrot Crown")
	-- Camps: 35 live mobs, 4 Elites, UPPER_WEST & UPPER_EAST above Y 30, none on extra platforms.
	local mobs, upperWestY, upperEastY = 0, 0, 0
	for _, camp in room.Camps do
		if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end
		if camp.Id == "UPPER_WEST" then upperWestY = camp.Y end
		if camp.Id == "UPPER_EAST" then upperEastY = camp.Y end
		assert(({ Basin = true, WestGallery = true, EastGallery = true, Crossing = true, WestBastion = true, EastBastion = true, Apex = true })[camp.Platform], camp.Id .. " stands on an extra platform")
	end
	assert(mobs == 35 and room.EliteCount == 4)
	assert(upperWestY > 30 and upperEastY > 30, "UPPER_WEST and UPPER_EAST must sit above Y 30")
	-- Terrain terraces on 4-stud planes; every terrace except Sanctuary has its own walk height.
	local td = room.Terrain
	local heights = {}
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
		if id ~= "Sanctuary" then
			assert(not heights[t.Y], id .. " shares a walk height")
			heights[t.Y] = true
		end
	end
end)

test("Floor 34 climbs the escalation ladder: bigger and more elaborate than Floor 33 and every earlier fourth floor", function()
	local room = Layout.ForFloor(34)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 16 and links == 19 and levels == 15, string.format("Floor 34 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 4, 9, 14, 19, 24, 33 } do
		local r = Layout.ForFloor(earlier)
		local t, l, v = ladderCounts(r)
		assert(terraces > t and links > l and levels > v, "Floor 34 does not beat floor " .. earlier)
		assert(room.Width * room.Depth > r.Width * r.Depth and room.Height > r.Height, "Floor 34's room is not grander than floor " .. earlier)
		assert(room.Platforms.Apex.Y > r.Platforms.Apex.Y, "Floor 34's Apex is not higher than floor " .. earlier .. "'s")
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(4))
	assert(walk <= 2.2 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 34's terrain is the walking surface: corrupted BLIGHT rot bog, built bracket decks and branch bridges", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(34)
	local field = Terrain.Field(room, "corrupted_grove", 34)
	assert(field.Surface == Terrain.Surfaces.BLIGHT, "floor 34 uses the corrupted BLIGHT surface palette")
	assert(room.Terrain.Blight ~= nil and #room.Terrain.Pools >= 3, "floor 34 has corrupted bog relief and rot-bog pools")
	for id, t in room.Platforms do
		local y, kind = field.Sample(t.X + 3, t.Z - 3)
		if room.Terrain.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, string.format("%s: ground %.2f is not flush with the walking plane %.2f", id, y, t.Y))
			assert(kind == "WALK" or kind == "TRAIL", id .. " is not walkway ground (" .. kind .. ")")
		end
	end
	-- Every earthen ramp's centreline is walkable ground at its own height.
	for _, link in room.Links do
		if link.Kind ~= "STAIRS" and not (room.Terrain.Bridges and room.Terrain.Bridges[link.Id]) then
			for step = 1, 9 do
				local t = step / 10
				local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
				local want = link.AY + (link.BY - link.AY) * t
				local y = field.Sample(x, z)
				assert(math.abs(y - (want - 2)) < 0.05 or y < want - 2, link.Id .. " ground rises over the ramp")
				assert(y > want - 2.6, string.format("%s ground sags under the ramp (%.2f vs %.2f)", link.Id, y, want))
			end
		end
	end
end)

test("Floor 34's landmarks stand clear of every walkway, camp and boss portal", function()
	local F34 = require(nodes["ServerScriptService.Core.TowerSetPieces.CorruptedFloor34"])
	local list = F34.Landmarks
	assert(#list >= 19, "Floor 34 needs at least 19 landmark footprints")
	local room = Layout.ForFloor(34)
	local lanes = Layout.Lanes(4, 34)
	local portals = Layout.PortalSpots(4, 34)
	local function overlaps(lm: any, lane: any): boolean
		local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		local ux, uz = dx / len, dz / len
		local cx, cz = (lane.AX + lane.BX) / 2, (lane.AZ + lane.BZ) / 2
		local laneCorners, rectCorners = {}, {}
		for _, sgn in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(laneCorners, { cx + ux * len / 2 * sgn[1] - uz * lane.HalfWidth * sgn[2], cz + uz * len / 2 * sgn[1] + ux * lane.HalfWidth * sgn[2] })
			table.insert(rectCorners, { lm.X + lm.HalfX * sgn[1], lm.Z + lm.HalfZ * sgn[2] })
		end
		for _, axis in { { 1, 0 }, { 0, 1 }, { ux, uz }, { -uz, ux } } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in rectCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				aMin, aMax = math.min(aMin, v), math.max(aMax, v)
			end
			for _, c in laneCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				bMin, bMax = math.min(bMin, v), math.max(bMax, v)
			end
			if aMax < bMin or bMax < aMin then return false end
		end
		return true
	end
	local tallest = 0
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		tallest = math.max(tallest, lm.Top)
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(not overlaps(lm, lane), lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				local nx = math.clamp(camp.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
				local nz = math.clamp(camp.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
				assert((nx - camp.X) ^ 2 + (nz - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " reaches into camp " .. camp.Id)
			end
		end
		for pName, p in portals do
			local nx = math.clamp(p.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
			local nz = math.clamp(p.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
			assert((nx - p.X) ^ 2 + (nz - p.Z) ^ 2 >= 12 * 12, lm.Id .. " covers portal " .. pName)
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	assert(tallest >= 175, "Floor 34's tallest landmark is under the ladder's 175 studs")
end)

test("Floor 35 is the hand-authored Sovereign's Grove: three colossal roots to the 184x136 Sovereign's Dais", function()
	local room = Layout.ForFloor(35)
	assert(room.Authored == "corrupted:5" and room.Name == "Sovereign's Grove" and room.PathStyle == "HOLLIN")
	assert(same(room, Layout.Get(5, 35)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(5)), "floor 35 should not be the canonical layout")
	assert(room.Width == 810 and room.Depth == 795 and room.Height == 305 and room.Bottom == -8)
	assert(#room.ReturnLinks == 2, "Floor 35 has a deep sap mire with two Basin return ramps")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	assert(#room.Links == 21)
	assert(paths.TaprootSpine_Apex == "STAIRS", "the Heart Stair is not stairs")
	for id, kind in paths do
		if id ~= "TaprootSpine_Apex" then
			assert(kind == "RAMP", id .. " should be a ramp")
		end
	end
	-- The Sovereign's Dais: 184 x 136 at Y 60, highest terrace on the floor, entered by exactly three links.
	local apex = room.Platforms.Apex
	assert(apex.Width == 184 and apex.Depth == 136 and apex.Y == 60, "Sovereign's Dais size or height changed")
	for id, p in room.Platforms do
		if id ~= "Apex" then
			assert(apex.Y > p.Y, id .. " sits as high as Sovereign's Dais")
		end
	end
	local apexEntries = {}
	for _, link in room.Links do
		if link.To == "Apex" then apexEntries[link.From] = true
		elseif link.From == "Apex" then apexEntries[link.To] = true end
	end
	assert(apexEntries.WestRootCrown and apexEntries.TaprootSpine and apexEntries.EastRootCrown, "Sovereign's Dais needs WestRootCrown, TaprootSpine and EastRootCrown entries")
	local entryCount = 0
	for _ in apexEntries do entryCount += 1 end
	assert(entryCount == 3, "exactly three links enter Sovereign's Dais")
	-- Camps: 35 live mobs, 4 Elites, Boss camp on Apex, none on extra platforms.
	local mobs, hasBoss = 0, false
	for _, camp in room.Camps do
		if camp.Id == "APEX_SANCTUM" then
			hasBoss = camp.Boss == true
		else
			mobs += camp.Size
		end
		assert(({ Basin = true, WestGallery = true, EastGallery = true, Crossing = true, WestBastion = true, EastBastion = true, Apex = true })[camp.Platform], camp.Id .. " stands on an extra platform")
	end
	assert(mobs == 35 and room.EliteCount == 4 and hasBoss, "Floor 35 needs 35 live mobs, 4 Elites and the Boss camp")
	-- Terrain terraces on 4-stud planes; every terrace except Sanctuary has its own walk height.
	local td = room.Terrain
	local heights = {}
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
		if id ~= "Sanctuary" then
			assert(not heights[t.Y], id .. " shares a walk height")
			heights[t.Y] = true
		end
	end
end)

test("Floor 35 tops the Corrupted Grove escalation ladder: grander than Floor 34 and every earlier fifth floor", function()
	local room = Layout.ForFloor(35)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 18 and links == 21 and levels == 17, string.format("Floor 35 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 5, 10, 15, 20, 25, 34 } do
		local r = Layout.ForFloor(earlier)
		local t, l, v = ladderCounts(r)
		assert(terraces > t and links > l and levels > v, "Floor 35 does not beat floor " .. earlier)
		assert(room.Width * room.Depth > r.Width * r.Depth and room.Height > r.Height, "Floor 35's room is not grander than floor " .. earlier)
		assert(room.Platforms.Apex.Y > r.Platforms.Apex.Y, "Floor 35's Apex is not higher than floor " .. earlier .. "'s")
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(5))
	assert(walk <= 2.2 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 35's terrain is the walking surface: deeply corrupted BLIGHT sap mire, root walks and Sovereign's Dais", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(35)
	local field = Terrain.Field(room, "corrupted_grove", 35)
	assert(field.Surface == Terrain.Surfaces.BLIGHT, "floor 35 uses the corrupted BLIGHT surface palette")
	assert(room.Terrain.Blight ~= nil and #room.Terrain.Pools >= 3, "floor 35 has corrupted sap mire relief and pools")
	for id, t in room.Platforms do
		local y, kind = field.Sample(t.X + 3, t.Z - 3)
		if room.Terrain.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, string.format("%s: ground %.2f is not flush with the walking plane %.2f", id, y, t.Y))
			assert(kind == "WALK" or kind == "TRAIL", id .. " is not walkway ground (" .. kind .. ")")
		end
	end
	for _, link in room.Links do
		if link.Kind ~= "STAIRS" and not (room.Terrain.Bridges and room.Terrain.Bridges[link.Id]) then
			for step = 1, 9 do
				local t = step / 10
				local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
				local want = link.AY + (link.BY - link.AY) * t
				local y = field.Sample(x, z)
				assert(math.abs(y - (want - 2)) < 0.05 or y < want - 2, link.Id .. " ground rises over the ramp")
				assert(y > want - 2.6, string.format("%s ground sags under the ramp (%.2f vs %.2f)", link.Id, y, want))
			end
		end
	end
end)

test("Floor 35's landmarks stand clear of every walkway, camp, Boss Arena and boss portal", function()
	local F35 = require(nodes["ServerScriptService.Core.TowerSetPieces.CorruptedFloor35"])
	local list = F35.Landmarks
	assert(#list >= 21, "Floor 35 needs at least 21 landmark footprints")
	local room = Layout.ForFloor(35)
	local lanes = Layout.Lanes(5, 35)
	local portals = Layout.PortalSpots(5, 35)
	local apex = room.Platforms.Apex
	local function overlaps(lm: any, lane: any): boolean
		local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		local ux, uz = dx / len, dz / len
		local cx, cz = (lane.AX + lane.BX) / 2, (lane.AZ + lane.BZ) / 2
		local laneCorners, rectCorners = {}, {}
		for _, sgn in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(laneCorners, { cx + ux * len / 2 * sgn[1] - uz * lane.HalfWidth * sgn[2], cz + uz * len / 2 * sgn[1] + ux * lane.HalfWidth * sgn[2] })
			table.insert(rectCorners, { lm.X + lm.HalfX * sgn[1], lm.Z + lm.HalfZ * sgn[2] })
		end
		for _, axis in { { 1, 0 }, { 0, 1 }, { ux, uz }, { -uz, ux } } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in rectCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				aMin, aMax = math.min(aMin, v), math.max(aMax, v)
			end
			for _, c in laneCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				bMin, bMax = math.min(bMin, v), math.max(bMax, v)
			end
			if aMax < bMin or bMax < aMin then return false end
		end
		return true
	end
	local tallest = 0
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		tallest = math.max(tallest, lm.Top)
		-- Keep every landmark footprint off the 184 x 136 Sovereign's Dais combat floor.
		local hitsApexX = math.abs(lm.X - apex.X) < apex.Width / 2 + lm.HalfX
		local hitsApexZ = math.abs(lm.Z - apex.Z) < apex.Depth / 2 + lm.HalfZ
		assert(not (hitsApexX and hitsApexZ), lm.Id .. " intrudes onto Sovereign's Dais arena")
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(not overlaps(lm, lane), lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				local nx = math.clamp(camp.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
				local nz = math.clamp(camp.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
				assert((nx - camp.X) ^ 2 + (nz - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " reaches into camp " .. camp.Id)
			end
		end
		for pName, p in portals do
			local nx = math.clamp(p.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
			local nz = math.clamp(p.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
			assert((nx - p.X) ^ 2 + (nz - p.Z) ^ 2 >= 12 * 12, lm.Id .. " covers portal " .. pName)
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	assert(tallest >= 230, "Floor 35's tallest landmark is under the ladder's 230 studs")
end)

test("Floor 26 is the hand-authored Stormgrass Rise: wind-tacking contours round a sheer central headwall", function()
	local room = Layout.ForFloor(26)
	assert(room.Authored == "thunder:1" and room.Name == "Stormgrass Rise" and room.PathStyle == "KAIRN")
	assert(room.DirectTerrain == true and room.Surface == "KAIRN" and room.Masonry == "KAIRN_STONE")
	assert(room.Width == 510 and room.Depth == 550 and room.Height == 180, "Floor 26 overrides its room size")
	assert(room.Bottom == 0 and #room.ReturnLinks == 0, "Floor 26 has no chasm")
	assert(same(room, Layout.Get(1, 26)) and not same(room, Layout.Get(1)))
	assert(#Layout.Validate(room) == 0, "Floor 26's layout has problems")
	local paths = {}
	for _, link in room.Links do paths[link.Id] = link.Kind end
	-- No way up the headwall's face: every ascent tacks out to a wind-crag first.
	assert(paths.Crossing_Apex == nil, "the Cairn Fold must not climb straight to the Crown")
	assert(paths.Crossing_WestCrag and paths.WestGallery_WestCrag and paths.EastGallery_EastCrag)
	assert(paths.WestCrag_Apex == "STAIRS" and paths.EastCrag_Apex == "RAMP", "the west ascent ends on the slate stair")
	local apexLinks = 0
	for _, link in room.Links do
		if link.To == "Apex" or link.From == "Apex" then
			apexLinks += 1
			assert(link.From == "WestCrag" or link.From == "EastCrag", link.Id .. " reaches the Crown past the crags")
		end
	end
	assert(apexLinks == 2)
	-- Every link touching an off-grid dry-stone deck is a built causeway; terrain terraces sit on 4-stud planes.
	local p = room.Platforms
	for id, t in p do
		if room.Decks[id] then
			assert(t.Y % 4 ~= 0, id .. " is a deck on the terrain grid: make it terrain")
		else
			assert(t.Y % 4 == 0, id .. " is a terrain terrace off the 4-stud grid")
		end
	end
	for _, link in room.Links do
		if room.Decks[link.From] or room.Decks[link.To] then
			assert(room.Suspended.Links[link.Id], link.Id .. " touches a deck but is not a built causeway")
		end
	end
	assert(p.Crossing.Name == "Cairn Fold" and p.WestGallery.Name == "Windmill Knoll" and p.EastGallery.Name == "Standing Stones")
	assert(p.ShepherdWatch.Name == "Shepherd's Watch" and p.FulguriteSpur.Name == "Fulgurite Outcrop" and p.Apex.Name == "Stormgrass Crown")
	-- The headwall stands between the wind-crags, north of the Fold.
	local headwall
	for _, feat in room.TerrainFeatures do
		if feat.Kind == "HEADWALL" then headwall = feat end
	end
	assert(headwall, "Floor 26 has no headwall")
	assert(headwall.X - headwall.HalfX > p.WestCrag.X + p.WestCrag.Width / 2 and headwall.X + headwall.HalfX < p.EastCrag.X - p.EastCrag.Width / 2,
		"the headwall stands between the wind-crags")
	assert(headwall.Z + headwall.HalfZ < p.Crossing.Z - p.Crossing.Depth / 2 and headwall.Z - headwall.HalfZ > p.Apex.Z + p.Apex.Depth / 2,
		"the headwall stands between the Cairn Fold and the Crown")
	local totalMobs = 0
	for _, camp in room.Camps do
		assert(camp.Platform ~= "ShepherdWatch" and camp.Platform ~= "FulguriteSpur" and camp.Platform ~= "WestCrag" and camp.Platform ~= "EastCrag",
			"ExtraPlatforms hold no camps")
		if camp.Platform ~= "Apex" then totalMobs += camp.Size end
	end
	assert(totalMobs == 16 and room.EliteCount == 1, "Floor 26 keeps 16 live camp mobs and 1 Elite")
	assert(Layout.PatrolRoutes(1, 26).BASIN_LOOP ~= nil)
end)

test("Floor 26 climbs the escalation ladder: grander than every earlier first floor, the walk still brisk", function()
	local room = Layout.ForFloor(26)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 10 and links == 11 and levels == 9, string.format("Floor 26 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 1, 6, 11, 16, 21 } do
		local r = Layout.ForFloor(earlier)
		local t, l, v = ladderCounts(r)
		assert(terraces > t and links > l and levels > v, "Floor 26 does not beat floor " .. earlier)
		assert(room.Platforms.Apex.Y > r.Platforms.Apex.Y, "Floor 26's Crown is not higher than floor " .. earlier .. "'s Apex")
	end
	local f21 = Layout.ForFloor(21)
	assert(room.Width * room.Depth > f21.Width * f21.Depth and room.Height > f21.Height, "Floor 26's room is not grander than Floor 21's")
	local walk, base = routeLength(room), routeLength(Layout.Get(1))
	assert(walk <= 1.5 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 26's terrain: Kairn ground, a sheer headwall over the Fold, a strike crater, walkways untouched", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(26)
	local field = Terrain.Field(room, "thunder_highlands", 26)
	assert(field.Surface == Terrain.Surfaces.KAIRN, "floor 26 uses the Kairn surface")
	for key, m in Terrain.Surfaces.KAIRN :: any do
		for _, fungal in Terrain.FungalMaterials do
			assert(m ~= fungal, "Kairn surface " .. key .. " uses a Fungal-owned material")
		end
	end
	-- The headwall towers over the Crown, and its face is sheer: it rises 40 studs within 12 of its foot.
	local apex = room.Platforms.Apex
	assert(field.Height(4, -96) > apex.Y + 25, "the headwall does not tower over the Crown")
	local foot, face = math.huge, -math.huge
	for z = -50, -40, 2 do foot = math.min(foot, field.Height(4, z)) end
	for z = -66, -62, 2 do face = math.max(face, field.Height(4, z)) end
	assert(face - foot > 40, "the headwall's face is not sheer")
	assert(field.Kind(4, -96) == "MOUNTAIN", "the headwall is not rock")
	-- The strike crater: a scorched ring wall on the slope, fused glass in its bowl.
	assert(field.Accent ~= nil and field.Accent(150, -204) ~= nil, "the strike crater has no scorched ground")
	local rim = -math.huge
	for a = 0, 330, 30 do
		rim = math.max(rim, field.Height(150 + math.cos(math.rad(a)) * 27, -204 + math.sin(math.rad(a)) * 27))
	end
	assert(rim > field.Bottom + 2, "the strike crater has no rim")
	-- Terraces stay flush; no link is buried by the headwall or the crater.
	for id, t in room.Platforms do
		assert(field.Height(t.X, t.Z) <= t.Y + 0.01, id .. " is buried")
	end
	for _, link in room.Links do
		for t = 0, 1, 0.05 do
			local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
			assert(field.Height(x, z) <= link.AY + (link.BY - link.AY) * t + 0.01, link.Id .. " is buried")
		end
	end
end)

test("Floor 26's twin falls hang in front of the headwall from pool to lip, rock never showing through", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local Thunder = require(nodes["ServerScriptService.Core.TowerSetPieces.ThunderHighlands"])
	local field = Terrain.Field(Layout.ForFloor(26), "thunder_highlands", 26)
	local hw = Thunder.FallHalfWidth
	assert(#Thunder.FallXs == 2)
	assert(math.abs(Thunder.FallXs[1] - Thunder.FallXs[2]) > 2 * hw, "the falls overlap each other")
	for _, fx in Thunder.FallXs do
		local fy = field.LiquidLevel - 0.6
		local fit = Thunder.FitFall(field, fx, fy, hw)
		local sinT, cosT, cosY, sinY = math.sin(fit.Tilt), math.cos(fit.Tilt), math.cos(fit.Yaw), math.sin(fit.Yaw)
		local function at(u: number, v: number): (number, number, number)
			return fx + u * cosY + v * sinT * sinY, fy + v * cosT, fit.Z0 - u * sinY + v * sinT * cosY
		end
		for k = -4, 4 do
			local u = hw * k / 4
			-- Never behind the rock (smooth terrain renders up to 2.5 studs over the field's height).
			for f = 0.03, 1, 0.03 do
				local x, y, z = at(u, f * fit.Length)
				assert(field.Height(x, z) + 2.5 <= y + 1e-6, string.format("rock shows through the fall at x %.0f at height %.0f", x, y))
			end
			-- Its top edge meets the lip: rock within 4 studs behind it, and the turf no lower than it.
			local x, y, z = at(u, fit.Length - 1)
			local touches = false
			for d = 0, 4, 0.5 do
				if field.Height(x, z - d) + 1 >= y then touches = true end
			end
			assert(touches, string.format("the fall at x %.0f stands away from the lip", x))
		end
	end
end)

test("Floor 26's landmarks stand clear of every walkway, camp and mob slot", function()
	local Thunder = require(nodes["ServerScriptService.Core.TowerSetPieces.ThunderHighlands"])
	local list = Thunder.Floor26Landmarks
	assert(#list >= 12, "Floor 26 needs at least 12 landmarks")
	local room = Layout.ForFloor(26)
	local lanes = Layout.Lanes(1, 26)
	local function nearestDistSq(px: number, pz: number, lm: any): number
		local nx = math.clamp(px, lm.X - lm.HalfX, lm.X + lm.HalfX)
		local nz = math.clamp(pz, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
		return (nx - px) ^ 2 + (nz - pz) ^ 2
	end
	-- Distance from a footprint to a lane's centre segment (sampled along the segment).
	local function laneGap(lm: any, lane: any): number
		local best = math.huge
		for k = 0, 40 do
			local t = k / 40
			local x, z = lane.AX + (lane.BX - lane.AX) * t, lane.AZ + (lane.BZ - lane.AZ) * t
			best = math.min(best, math.sqrt(nearestDistSq(x, z, lm)))
		end
		return best - lane.HalfWidth
	end
	local tallest = 0
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		tallest = math.max(tallest, y1)
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(laneGap(lm, lane) > 0, lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		-- Mirrors TowerBiomeAssets.CampHitTest: nothing centred within 34 studs of a camp, no box within 7 of a
		-- mob's slot, inside the camp's height band.
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				assert((lm.X - camp.X) ^ 2 + (lm.Z - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " is centred in camp " .. camp.Id)
				for _, slot in { { 0, 0 }, { 18, 12 }, { -18, 12 }, { 12, -16 }, { -12, -16 } } do
					assert(nearestDistSq(camp.X + slot[1], camp.Z + slot[2], lm) >= 7 * 7, lm.Id .. " crowds a mob slot of " .. camp.Id)
				end
			end
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	-- The tor and its crown totem: the tallest landmark on any first floor, far above the moor.
	assert(tallest >= 95 + room.Platforms.Apex.Y, string.format("Floor 26's skyline tops out at %.0f", tallest))
end)

test("Floor 36 is the hand-authored Drowned Steps: a broken pilgrim stair over a tide-flat, the Bell Stack in the back-west", function()
	local room = Layout.ForFloor(36)
	assert(room.Authored == "sunken:1" and room.Name == "Drowned Steps" and room.PathStyle == "NERETH")
	assert(same(room, Layout.Get(1, 36)), "the authored floor is not fixed")
	assert(not same(room, Layout.Get(1)), "floor 36 should not be the canonical layout")
	assert(room.Width == 570 and room.Depth == 600 and room.Height == 210 and room.Bottom == 0)
	assert(#Layout.Validate(room) == 0, "Floor 36's layout has problems")
	local kinds = {}
	for _, link in room.Links do kinds[link.Id] = link.Kind end
	assert(#room.Links == 16)
	assert(kinds.Crossing_PilgrimLanding == "STAIRS", "the First Flight is not a stair")
	assert(kinds.BellLanding_Apex == "STAIRS", "the Bell Stair is not a stair")
	for id, kind in kinds do
		if id ~= "Crossing_PilgrimLanding" and id ~= "BellLanding_Apex" then assert(kind == "RAMP", id .. " should be a ramp") end
	end
	-- The broken-stair rule: no link spans the fallen middle flight, and the Apex is still reachable round it.
	local broken = room.BrokenFlight
	assert(broken and broken.From == "PilgrimLanding" and broken.To == "BellLanding")
	for _, link in room.Links do
		local pair = (link.From == broken.From and link.To == broken.To) or (link.From == broken.To and link.To == broken.From)
		assert(not pair, "a link bridges the fallen flight")
	end
	assert(reachable(room).Apex, "the Bell Stack is out of reach")
	-- Both detours reach the Apex on their own: east over the Votive Pool, west by the barge and Cantors' Rock.
	assert(reachable(room, { CantorRock_Apex = true }).Apex, "the east detour does not reach the Bell Stack")
	assert(reachable(room, { BellLanding_Apex = true }).Apex, "the west route does not reach the Bell Stack")
	-- The Apex sits back-west on its sea-stack, entered from the south and the west, never the north.
	local apex = room.Platforms.Apex
	assert(apex.X < 0 and apex.Z < -200 and apex.Y == 32, "the Bell Stack is not in the back-west")
	for _, link in room.Links do
		if link.To == "Apex" then
			local from = room.Platforms[link.From]
			assert(from.Z > apex.Z - apex.Depth / 2, link.Id .. " enters the Apex from the north")
		end
	end
	-- Camps: 16 mobs, 1 Elite, none on an extra platform.
	local mobs = 0
	for _, camp in room.Camps do
		if camp.Id ~= "APEX_SANCTUM" then mobs += camp.Size end
		assert(({ Basin = true, WestGallery = true, EastGallery = true, Crossing = true, Apex = true })[camp.Platform], camp.Id .. " stands on an extra platform")
	end
	assert(mobs == 16 and room.EliteCount == 1)
	-- Terrain terraces on the voxel grid; every height its own.
	local td = room.Terrain
	local heights = {}
	for id, t in room.Platforms do
		if not td.Decks[id] then assert(t.Y % 4 == 0, id .. " (terrain) is not on a 4-stud plane") end
		if id ~= "Sanctuary" then
			assert(not heights[t.Y], id .. " shares a walk height")
			heights[t.Y] = true
		end
	end
	-- The four causeways cross open water on piers; the Bell Stack's apron is sheer.
	for _, id in { "WestGallery_Wreck", "PilgrimLanding_Wreck", "Crossing_Votive", "Votive_BellLanding" } do
		assert(kinds[id] and td.Bridges[id] and td.BridgeStyles[id] == "CAUSEWAY", id .. " is not a causeway")
	end
	assert(td.Shapes.Apex.Sheer == true, "the Bell Stack is not a sheer sea-stack")
end)

test("Floor 36 climbs the escalation ladder: bigger and more elaborate than every earlier first floor", function()
	local room = Layout.ForFloor(36)
	local terraces, links, levels = ladderCounts(room)
	assert(terraces == 12 and links == 16 and levels == 11, string.format("Floor 36 has %d/%d/%d", terraces, links, levels))
	for _, earlier in { 1, 6, 11, 16, 21, 26, 31 } do
		local r = Layout.ForFloor(earlier)
		local t, l, v = ladderCounts(r)
		assert(terraces > t and links > l and levels > v, "Floor 36 does not beat floor " .. earlier)
		assert(room.Width * room.Depth > r.Width * r.Depth and room.Height > r.Height, "Floor 36's room is not grander than floor " .. earlier)
		assert(room.Platforms.Apex.Y > r.Platforms.Apex.Y, "Floor 36's Apex is not higher than floor " .. earlier .. "'s")
	end
	local walk, base = routeLength(room), routeLength(Layout.Get(1))
	assert(walk <= 2 * base, string.format("the Sanctuary-Apex walk is %.0f (canonical %.0f)", walk, base))
end)

test("Floor 36's terrain is the walking surface: Nereth ground, turquoise shallows, the surf open under the causeways", function()
	local Terrain = require(nodes["ServerScriptService.Core.TowerTerrain"])
	local room = Layout.ForFloor(36)
	local field = Terrain.Field(room, "sunken_sanctuary", 36)
	assert(field.Surface == Terrain.Surfaces.NERETH, "floor 36 uses the Nereth surface palette")
	for key, m in Terrain.Surfaces.NERETH :: any do
		for _, fungal in Terrain.FungalMaterials do
			assert(m ~= fungal, "Nereth surface " .. key .. " uses a Fungal-owned material")
		end
		for _, blocky in Terrain.BlockyMaterials do
			assert(m ~= blocky, "Nereth surface " .. key .. " uses a blocky material")
		end
	end
	assert(math.abs(field.LiquidLevel - (field.Bottom + room.Terrain.LiquidRise)) < 1e-6)
	for id, t in room.Platforms do
		local y, kind = field.Sample(t.X + 3, t.Z - 3)
		if room.Terrain.Decks[id] then
			assert(y <= t.Y - 4.5 + 1e-6, id .. ": the terrain rises into a deck")
		else
			assert(math.abs(y - (t.Y - 2)) < 1e-6, string.format("%s: ground %.2f is not flush with the walking plane %.2f", id, y, t.Y))
			assert(kind == "WALK" or kind == "TRAIL", id .. " is not walkway ground (" .. kind .. ")")
		end
	end
	-- The surf runs on under the three long causeways (the short Bell Causeway crosses wet sand between two
	-- aprons), and the fallen flight lies in the water.
	local long = { WestGallery_Wreck = true, PilgrimLanding_Wreck = true, Crossing_Votive = true }
	for _, link in room.Links do
		if long[link.Id] then
			local wet = 0
			for step = 2, 8 do
				local t = step / 10
				local _, kind = field.Sample(link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t)
				if kind == "POOL" then wet += 1 end
			end
			assert(wet > 0, "no water under " .. link.Id)
		end
	end
	local _, gapKind = field.Sample(-36, -90)
	assert(gapKind == "POOL", "the fallen flight's gap is dry (" .. gapKind .. ")")
	-- The Bell Stack is a sea-stack: eight studs past its crown's open east edge the ground has already
	-- fallen far (a bank would still be within about 12 studs of the top).
	local apex = room.Platforms.Apex
	local below = field.Sample(apex.X + apex.Width / 2 + 6 + 8, apex.Z - 12)
	assert(below < apex.Y - 20, string.format("the Bell Stack's east face is a slope, not a cliff (%.1f)", below))
	-- Every earthen ramp's centreline is walkable ground at its own height.
	for _, link in room.Links do
		if link.Kind ~= "STAIRS" and not room.Terrain.Bridges[link.Id] then
			for step = 1, 9 do
				local t = step / 10
				local x, z = link.AX + (link.BX - link.AX) * t, link.AZ + (link.BZ - link.AZ) * t
				local want = link.AY + (link.BY - link.AY) * t
				local y = field.Sample(x, z)
				assert(math.abs(y - (want - 2)) < 0.05 or y < want - 2, link.Id .. " ground rises over the ramp")
				assert(y > want - 2.6, string.format("%s ground sags under the ramp (%.2f vs %.2f)", link.Id, y, want))
			end
		end
	end
end)

test("Floor 36's landmarks stand clear of every walkway, camp and boss portal", function()
	local Sunken = require(nodes["ServerScriptService.Core.TowerSetPieces.SunkenSanctuary"])
	local list = Sunken.Floor36Landmarks
	assert(#list >= 14, "Floor 36 needs at least 14 landmark footprints")
	local room = Layout.ForFloor(36)
	local lanes = Layout.Lanes(1, 36)
	local function overlaps(lm: any, lane: any): boolean
		local dx, dz = lane.BX - lane.AX, lane.BZ - lane.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		local ux, uz = dx / len, dz / len
		local cx, cz = (lane.AX + lane.BX) / 2, (lane.AZ + lane.BZ) / 2
		local laneCorners, rectCorners = {}, {}
		for _, sgn in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			table.insert(laneCorners, { cx + ux * len / 2 * sgn[1] - uz * lane.HalfWidth * sgn[2], cz + uz * len / 2 * sgn[1] + ux * lane.HalfWidth * sgn[2] })
			table.insert(rectCorners, { lm.X + lm.HalfX * sgn[1], lm.Z + lm.HalfZ * sgn[2] })
		end
		for _, axis in { { 1, 0 }, { 0, 1 }, { ux, uz }, { -uz, ux } } do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in rectCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				aMin, aMax = math.min(aMin, v), math.max(aMax, v)
			end
			for _, c in laneCorners do
				local v = c[1] * axis[1] + c[2] * axis[2]
				bMin, bMax = math.min(bMin, v), math.max(bMax, v)
			end
			if aMax < bMin or bMax < aMin then return false end
		end
		return true
	end
	local skyline = 0
	for _, lm in list do
		local y0 = lm.Y or (room.Bottom - 4)
		local y1 = y0 + lm.Top
		skyline = math.max(skyline, y1 - (room.Bottom - 4))
		for _, lane in lanes do
			local ly0 = math.min(lane.AY, lane.BY) - lane.Below
			local ly1 = math.max(lane.AY, lane.BY) + lane.Above
			if y1 > ly0 and y0 < ly1 then
				assert(not overlaps(lm, lane), lm.Id .. " stands on walkway " .. lane.Id)
			end
		end
		for _, camp in room.Camps do
			if y1 > camp.Y - 2 and y0 < camp.Y + 22 then
				local nx = math.clamp(camp.X, lm.X - lm.HalfX, lm.X + lm.HalfX)
				local nz = math.clamp(camp.Z, lm.Z - lm.HalfZ, lm.Z + lm.HalfZ)
				assert((nx - camp.X) ^ 2 + (nz - camp.Z) ^ 2 >= 34 * 34, lm.Id .. " reaches into camp " .. camp.Id)
			end
		end
		assert(math.abs(lm.X) + lm.HalfX <= room.Width / 2 and math.abs(lm.Z) + lm.HalfZ <= room.Depth / 2, lm.Id .. " leaves the room")
	end
	-- The Bell Stack's canopy rises 120+ studs over the surf: the ladder's tallest landmark for a first Sunken floor.
	assert(skyline >= 120, string.format("Floor 36's skyline tops out at %.0f", skyline))
	-- The fallen flight lies between the two landings it once joined.
	local gap, p = Sunken.Floor36Gap, room.Platforms
	assert(gap.Z < p.PilgrimLanding.Z - p.PilgrimLanding.Depth / 2 and gap.Z > p.BellLanding.Z + p.BellLanding.Depth / 2)
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
	-- Hand-authored floors (1-26, 31-36) have no seeded bends, so the count falls as more floors are authored.
	assert(bends >= 10, "only " .. bends .. " winding paths")
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
