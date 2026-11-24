--!strict
-- Shared geometry and camp contract. Heights describe walkable top surfaces.
local Layout = {}
local widths = {380, 420, 460, 510, 560}
local depths = {420, 470, 520, 580, 640}
local heights = {130, 140, 155, 170, 190}
local apexHeights = {12, 14, 18, 22, 28}

-- Landings extend into the terrace, away from the inclined section. Their full
-- footprints are shared by the builder and scenery clearance.
local function landings(link: any, ux: number, uz: number, lengthA: number, lengthB: number)
	link.Id = link.From.."_"..link.To
	link.Kind = if link.From == "Crossing" and link.To == "Apex" then "STAIRS" else "RAMP"
	link.UsableWidth = link.Width - 6.8 -- curbs plus body clearance on both sides
	link.UX, link.UZ = ux, uz
	link.LandingA = {AX=link.AX-ux*lengthA, AY=link.AY, AZ=link.AZ-uz*lengthA,
		BX=link.AX+ux*.05, BY=link.AY, BZ=link.AZ+uz*.05, Width=link.Width+8}
	link.LandingB = {AX=link.BX-ux*.05, AY=link.BY, AZ=link.BZ-uz*.05,
		BX=link.BX+ux*lengthB, BY=link.BY, BZ=link.BZ+uz*lengthB, Width=link.Width+8}
end

-- Per-floor variation (GDD §3.3). The five layouts above are the canonical shapes, one per floor of a
-- biome; each floor reshapes its own copy, seeded by its floor id: galleries, bastions, the Crossing and
-- the Apex shift, resize and change height (each side on its own, so floors are no longer mirror images),
-- and a few paths wind through a small "bend" terrace instead of running straight. The Sanctuary and the
-- Basin never move (arrival, banking and the travel portals depend on them), and hand-authored floors
-- (AUTHORED below, starting with floor 1) take their own fixed shape instead. A variation is kept only if
-- it passes Layout.Validate; otherwise the next seed is tried, and the canonical layout is the fallback.
local VARIANT_ATTEMPTS = 16

-- Deterministic generator (not Roblox Random, so specs and the server see the same layouts).
local function generator(seed: number): (number, number) -> number
	local s = (seed * 2654435761 + 97) % 4294967296
	return function(lo: number, hi: number): number
		s = (s * 1664525 + 1013904223) % 4294967296
		return lo + (hi - lo) * (s / 4294967296)
	end
end

local function variation(index: number, floorId: number, attempt: number): any
	local r = generator(floorId * 131 + attempt * 7919)
	local w, d = widths[index], depths[index]
	local v: any = {}
	-- Galleries and bastions: the outer edge never moves past the canonical one (the perimeter and the
	-- chasm return ramps stay clear); they move inward, away from the Basin, and up or down.
	for _, side in {"West", "East"} do
		local sign = if side == "West" then -1 else 1
		local width = math.round(r(72, 88))
		local outer = w*.28 + 42 - r(0, w*.03)
		v[side.."Gallery"] = {X = sign*(outer - width/2), Z = -d*.06 + r(-d*.05, 0),
			Y = 8 + math.round(r(-2, 4)), Width = width, Depth = math.round(r(66, 82))}
		local bWidth = math.round(r(72, 88))
		local bOuter = w*.28 + 42 - r(0, w*.035)
		v[side.."Bastion"] = {X = sign*(bOuter - bWidth/2), Z = -d*.31 + r(-d*.02, d*.02),
			Y = 14 + math.round(r(-2, 3)), Width = bWidth, Depth = math.round(r(66, 80))}
	end
	v.Crossing = {X = r(-w*.035, w*.035), Z = -d*.04 + r(-d*.025, d*.015),
		Y = if index >= 3 then 5 + math.round(r(-2, 3)) else math.round(r(0, 2)), Width = math.round(r(64, 78)), Depth = math.round(r(52, 62))}
	v.Apex = {X = r(-w*.05, w*.05), Y = apexHeights[index] + math.round(r(-2, 2)), Width = math.round(r(92, 110)), Depth = math.round(r(74, 84))}
	-- Paths that wind: the long climbs to the Apex bend through a small terrace, pulled out toward the
	-- room's side (from a gallery) or toward its back wall (from a bastion), where there is room.
	v.Bends = {}
	local climbs = if index >= 4 then {"WestBastion", "EastBastion"} else {"WestGallery", "EastGallery"}
	for _, from in climbs do
		if r(0, 1) < 0.8 then
			v.Bends[from.."_Apex"] = {Offset = r(24, 44), Pull = if index >= 4 then "BACK" else "OUT", Along = r(0.42, 0.58),
				Width = math.round(r(34, 40)), Depth = math.round(r(34, 40))}
		end
	end
	return v
end

-- Hand-authored floors (docs/prompts/verdant-ruins-floor-layouts-prompt.md). An authored floor is not a
-- seeded variation: it moves terraces to its own fixed spots and replaces the path list, so its shape
-- (not just its proportions) differs from the canonical layout. Terrace ids keep their roles (Basin is the
-- entry level, the Galleries the wings, the Crossing the central spine, Apex the summit), so every
-- consumer keeps working; Names gives each terrace its in-world name. Validated like any variation.
local AUTHORED: {[number]: any} = {
	-- Floor 1, Overgrown Threshold (Verdant Ruins): the Solmere's front door. A narrow processional avenue
	-- runs from the fern hollow straight up grand steps to the cracked Dawn Gate, so the summit is in view
	-- from the Sanctuary; two low glades flank it at different heights, and the east glade's path rejoins
	-- the avenue instead of climbing to the Apex on its own.
	[1] = {
		Key = "verdant:1",
		Name = "Overgrown Threshold",
		-- Ramps and stairs are Solmere flagstone causeways with mossy kerbs (TowerRoomBuilder), and the
		-- canopy of giant trees replaces the ramp arches (TowerBiomeAssets).
		PathStyle = "SOLMERE",
		DirectTerrain = true,
		Crossing = {X = 0, Y = 3, Z = -34, Width = 52, Depth = 96},
		WestGallery = {X = -116, Y = 4, Z = -30, Width = 84, Depth = 76},
		EastGallery = {X = 118, Y = 6, Z = -40, Width = 84, Depth = 76},
		Apex = {X = 0, Y = 12, Z = -140, Width = 104, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"}, {"Basin", "EastGallery"}, {"Basin", "Crossing"},
			{"Crossing", "Apex"}, {"WestGallery", "Apex"}, {"EastGallery", "Crossing"},
		},
		Names = {
			Sanctuary = "Fallen Gate", Basin = "Pilgrim Hollow", Crossing = "Processional Avenue",
			WestGallery = "Shrine Glade", EastGallery = "Banyan Well", Apex = "Dawn Gate",
		},
	},
	-- Floor 2, Broken Aqueduct (Verdant Ruins): an asymmetric diagonal layout. The aqueduct snapped
	-- mid-span between AqueductSouth (Crossing) and AqueductNorth, forcing a detour through the
	-- Mill Ruin (EastGallery) to reach the off-centre Wellhead Shrine (Apex) in the north-west.
	[2] = {
		Key = "verdant:2",
		Name = "Broken Aqueduct",
		PathStyle = "SOLMERE",
		DirectTerrain = true,
		Decks = {
			Crossing = true,
			AqueductNorth = true,
		},
		Liquid = { LevelOffset = 2.6, FloorDip = 1.8 },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 70, Feather = 28 },
			{
				Kind = "POOL_ELLIPSES_SQ",
				Strength = 0.28,
				Gain = 0.28,
				Ellipses = {
					{ X = -34, Z = 16, RX = 36, RZ = 32 },
					{ X = 16, Z = -48, RX = 62, RZ = 34 },
					{ X = -94, Z = -82, RX = 24, RZ = 62 },
					{ X = 134, Z = 16, RX = 36, RZ = 32 },
				},
			},
		},
		Basin = {X = 0, Y = 0, Z = 112, Width = 360, Depth = 96},
		WestGallery = {X = -134, Y = 6, Z = -6, Width = 88, Depth = 76},
		Crossing = {X = 16, Y = 10, Z = 2, Width = 56, Depth = 64},
		EastGallery = {X = 138, Y = 4, Z = -36, Width = 84, Depth = 76},
		ExtraPlatforms = {
			AqueductNorth = {X = 16, Y = 12, Z = -96, Width = 56, Depth = 56},
		},
		Apex = {X = -68, Y = 14, Z = -174, Width = 104, Depth = 76},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"}, {"Basin", "Crossing"}, {"Basin", "EastGallery"},
			{"EastGallery", "AqueductNorth"}, {"AqueductNorth", "Apex"}, {"WestGallery", "Apex"},
		},
		Stairs = {
			WestGallery_Apex = true,
		},
		Names = {
			Sanctuary = "Springhead Gate", Basin = "Mill Pond", WestGallery = "Cistern Plaza",
			Crossing = "Aqueduct South", AqueductNorth = "Aqueduct North", EastGallery = "Mill Ruin",
			Apex = "Wellhead Shrine",
		},
	},
	-- Floor 3, Rootway Crossing (Verdant Ruins): an east-west river gorge splits the south bank (Fern Bank)
	-- from the north cliff (Root-Throne), bridged by three Heartroot spans at different elevations: The Knot
	-- (central root tangle island), Root Perch (west arched root bridge), and Hollow Stump (east felled giant).
	[3] = {
		Key = "verdant:3",
		Name = "Rootway Crossing",
		PathStyle = "SOLMERE",
		DirectTerrain = true,
		Masonry = "ORGANIC",
		Decks = {
			Crossing = true,
			WestGallery = true,
			EastGallery = true,
		},
		Suspended = {
			Platforms = { Crossing = true, WestGallery = true, EastGallery = true },
			Links = {
				Basin_Crossing = true, Basin_WestGallery = true, Basin_EastGallery = true,
				Crossing_Apex = true, WestGallery_Apex = true, EastGallery_Apex = true,
			},
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{
				Kind = "RIVER_GORGE",
				BaseZ = -42, Amp = 14, Freq = 95, NoiseScale = 65, NoiseAmp = 10, NoiseSeed = 61, HalfWidth = 44, Gain = 0.34,
				WestPool = { X = -190, Z = -32, RX = 40, RZ = 40 },
			},
		},
		Basin = {X = 0, Y = 0, Z = 124, Width = 400, Depth = 108},
		Crossing = {X = 0, Y = 5, Z = 0, Width = 74, Depth = 60},
		WestGallery = {X = -150, Y = 10, Z = -26, Width = 84, Depth = 76},
		EastGallery = {X = 152, Y = 6, Z = -34, Width = 84, Depth = 76},
		Apex = {X = 0, Y = 18, Z = -182, Width = 104, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "Crossing"}, {"Basin", "WestGallery"}, {"Basin", "EastGallery"},
			{"Crossing", "Apex"}, {"WestGallery", "Apex"}, {"EastGallery", "Apex"},
		},
		Names = {
			Sanctuary = "Fallen Gate", Basin = "Fern Bank", Crossing = "The Knot",
			WestGallery = "Root Perch", EastGallery = "Hollow Stump", Apex = "Root-Throne",
		},
	},
	-- Floor 4, Vinebound Bastion (Verdant Ruins): a strangler-fig-breached Solmere fortress. An Outer Ward
	-- marsh meadow looks across a green moat to the Gatehouse & flanking Barracks/Sun Shrine wall-walks,
	-- with West & East Bastion towers and the roofless Inner Keep behind.
	[4] = {
		Key = "verdant:4",
		Name = "Vinebound Bastion",
		PathStyle = "SOLMERE",
		DirectTerrain = true,
		Masonry = "FORTRESS",
		Decks = {
			Crossing = true,
			WestGallery = true,
			EastGallery = true,
			WestBastion = true,
			EastBastion = true,
			Apex = true,
		},
		Suspended = {
			Platforms = { Crossing = true, WestGallery = true, EastGallery = true, WestBastion = true, EastBastion = true, Apex = true },
			Links = {
				Basin_Crossing = true, Basin_WestGallery = true, Basin_EastGallery = true,
				Crossing_WestGallery = true, Crossing_EastGallery = true,
				WestGallery_WestBastion = true, EastGallery_EastBastion = true,
				WestBastion_Apex = true, EastBastion_Apex = true,
				Crossing_Apex = true,
			},
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{
				Kind = "MOAT_CHANNELS",
				BaseZ = 78, Amp = 8, Freq = 85, NoiseScale = 55, NoiseAmp = 8, NoiseSeed = 71, HalfWidth = 30, Gain = 0.30,
				Channels = {
					{ X = -92, Z = -55, RX = 42, RZ = 85 },
					{ X = 92, Z = -55, RX = 42, RZ = 85 },
				},
			},
		},
		Patrols = {
			WALL_WALK = { "WestGallery", "Crossing", "EastGallery" },
		},
		Basin = {X = 0, Y = 0, Z = 160, Width = 440, Depth = 114},
		Crossing = {X = 0, Y = 5, Z = 48, Width = 74, Depth = 60},
		WestGallery = {X = -158, Y = 8, Z = 12, Width = 86, Depth = 78},
		EastGallery = {X = 158, Y = 8, Z = 4, Width = 86, Depth = 78},
		WestBastion = {X = -152, Y = 14, Z = -140, Width = 84, Depth = 76},
		EastBastion = {X = 152, Y = 16, Z = -150, Width = 84, Depth = 76},
		Apex = {X = 0, Y = 22, Z = -198, Width = 104, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "Crossing"}, {"Basin", "WestGallery"}, {"Basin", "EastGallery"},
			{"Crossing", "WestGallery"}, {"Crossing", "EastGallery"},
			{"WestGallery", "WestBastion"}, {"EastGallery", "EastBastion"},
			{"WestBastion", "Apex"}, {"EastBastion", "Apex"},
			{"Crossing", "Apex"},
		},
		Names = {
			Sanctuary = "Fallen Gate", Basin = "Outer Ward", Crossing = "Gatehouse",
			WestGallery = "Barracks", EastGallery = "Sun Shrine",
			WestBastion = "West Tower", EastBastion = "East Tower", Apex = "Inner Keep",
		},
	},
	-- Floor 5, Mossbound Court (Verdant Ruins Boss Arena): sunken amphitheatre cenote ringed by tiered Solmere
	-- colonnade galleries, cascading falls, and a central sunbridge causeway rising to the 140x110 Mossbound Dais.
	[5] = {
		Key = "verdant:5",
		Name = "Mossbound Court",
		PathStyle = "SOLMERE",
		DirectTerrain = true,
		Masonry = "FORTRESS",
		SunMedallions = true,
		Decks = {
			Crossing = true,
			WestGallery = true,
			EastGallery = true,
			WestBastion = true,
			EastBastion = true,
			Apex = true,
		},
		Suspended = {
			Platforms = { Crossing = true, WestGallery = true, EastGallery = true, WestBastion = true, EastBastion = true, Apex = true },
			Links = {
				Basin_Crossing = true, Basin_WestGallery = true, Basin_EastGallery = true,
				WestGallery_WestBastion = true, EastGallery_EastBastion = true,
				WestBastion_Apex = true, EastBastion_Apex = true,
				Crossing_Apex = true,
			},
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{
				Kind = "CENOTE_LAGOON",
				Z = -28, RX = 172, RZ = 146, NoiseScale = 60, NoiseAmp = 0.08, NoiseSeed = 83, Base = 0.30, Gain = 0.34,
			},
		},
		Basin = {X = 0, Y = 0, Z = 176, Width = 480, Depth = 108},
		Crossing = {X = 0, Y = 5, Z = 40, Width = 74, Depth = 60},
		WestGallery = {X = -176, Y = 6, Z = 12, Width = 86, Depth = 80},
		EastGallery = {X = 176, Y = 8, Z = 6, Width = 86, Depth = 80},
		WestBastion = {X = -160, Y = 14, Z = -126, Width = 86, Depth = 80},
		EastBastion = {X = 162, Y = 16, Z = -134, Width = 86, Depth = 80},
		Apex = {X = 0, Y = 28, Z = -222, Width = 140, Depth = 110},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "Crossing"}, {"Basin", "WestGallery"}, {"Basin", "EastGallery"},
			{"WestGallery", "WestBastion"}, {"EastGallery", "EastBastion"},
			{"WestBastion", "Apex"}, {"EastBastion", "Apex"},
			{"Crossing", "Apex"},
		},
		Names = {
			Sanctuary = "Fallen Gate", Basin = "Cenote Rim", Crossing = "Sunbridge",
			WestGallery = "West Terrace", EastGallery = "East Terrace",
			WestBastion = "Northwest Tier", EastBastion = "Northeast Tier", Apex = "Mossbound Dais",
		},
	},
	-- Floor 6, Sporelit Entry (Fungal Hollow, docs/prompts/fungal-hollow-floor-layouts-prompt.md): the edge of
	-- the Veinweb, the Velmari lamp-masons' outer quarry. A still teal glowpool fills the middle of the floor
	-- with the Elder Cap, one colossal mushroom, on an island in it; the cap hides the Apex from the Sanctuary,
	-- and the cavern skylight's cyan shaft glowing over it is the beacon. Two routes wrap round the pool: west
	-- up the long Mycelium Ramp from the Chanters' Terrace, east through the Skitter Warren, up the Mason's Stair
	-- and over the Veinspan bridge. Nothing crosses the pool, so there is no Basin -> Crossing or Basin -> Apex.
	[6] = {
		Key = "fungal:6",
		Name = "Sporelit Entry",
		PathStyle = "VELMARI",
		Basin = {X = 0, Y = 0, Z = 96, Width = 320, Depth = 80},
		-- Natural (terrain) terraces stand on multiples of 4 studs, the voxel size: only there does smooth terrain
		-- render exactly on the walking plane (TowerTerrain). Decks and ramps can be at any height.
		WestGallery = {X = -112, Y = 8, Z = -6, Width = 84, Depth = 76},
		EastGallery = {X = 118, Y = 4, Z = 6, Width = 80, Depth = 72},
		Crossing = {X = 104, Y = 9, Z = -96, Width = 52, Depth = 64},
		Apex = {X = 0, Y = 12, Z = -150, Width = 104, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"}, {"Basin", "EastGallery"},
			{"EastGallery", "Crossing"}, {"Crossing", "Apex"}, {"WestGallery", "Apex"},
		},
		-- The Mason's Stair: cut slate steps climbing from the warren onto the bridge deck.
		Stairs = {EastGallery_Crossing = true},
		Names = {
			Sanctuary = "Lampwright's Landing", Basin = "Glowpool Shore", WestGallery = "Chanters' Terrace",
			EastGallery = "Skitter Warren", Crossing = "Veinspan", Apex = "Skylight Dais",
		},
		-- Natural ground you walk on (TowerTerrain direct mode). Decks are built Velmari masonry: solid,
		-- visible slabs with the terrain kept under them; every other terrace and ramp is sculpted terrain.
		Terrain = {
			Direct = true,
			Surface = "FUNGAL",
			Decks = {Sanctuary = true, Crossing = true},
			-- Thin deck slabs (studs): the Veinspan is a bridge over the east pool, not a solid block.
			DeckThickness = {Crossing = 3},
			LiquidRise = 2.6,
			FloorDip = 2.2,
			WallBand = {Base = 36, Noise = 14},
			-- Ellipses (local X/Z centre and radii) of the cosmetic glowpools, recessed off every walkway.
			Pools = {
				{X = 0, Z = -32, RX = 62, RZ = 66},  -- the central glowpool round the Elder Cap island
				{X = 104, Z = -92, RX = 30, RZ = 46}, -- the east pool under the Veinspan
				{X = -168, Z = -92, RX = 24, RZ = 34}, -- the north-west fall pool
				{X = 172, Z = -64, RX = 22, RZ = 24},  -- the north-east fall pool
			},
			-- Rock islands rising out of the pools (Top: local Y of the crown).
			Islands = {
				{X = 0, Z = -34, R = 26, Top = 4},
			},
			-- Ecosystem (TowerBiomeAssets section 7): far fewer giant-mushroom groves (one giant, the Elder Cap,
			-- not a forest), glowcap turf and spore-moss as the cavern floor's "grass", veins on the cliffs.
			GroveScale = 0.35,
			GroundCover = {"GlowcapTuftA", "GlowcapTuftB", "SporeMoss", "GlowcapTuftA"},
			GroundCoverCount = 150,
			CliffVeins = 26,
		},
		-- A round oculus in a closed cavern vault, over the Apex (TowerRoomBuilder).
		Skylight = {X = 0, Z = -132, Radius = 46},
	},
	-- Floor 7, Mycelium Galleries (Fungal Hollow): the Velmari's lamp-galleries, cut in tiers into the cavern
	-- wall and now strung with the Veinweb's nets. The main route is a switchback up the wall: east to the
	-- Lower Lamp Gallery, back west over the Netted Isle (a rounded rock island rising out of the span pool,
	-- under a small oculus), up the gallery steps to the Upper Lamp Gallery, and east again to the Lantern
	-- Vault. A shortcut ramp climbs from the Drip Hall straight onto the isle; the long east climb skips the
	-- upper gallery.
	[7] = {
		Key = "fungal:7",
		Name = "Mycelium Galleries",
		PathStyle = "VELMARI",
		Basin = {X = 0, Y = 0, Z = 118, Width = 340, Depth = 88},
		EastGallery = {X = 126, Y = 4, Z = 20, Width = 88, Depth = 72},
		Crossing = {X = -20, Y = 8, Z = -40, Width = 60, Depth = 60},
		WestGallery = {X = -134, Y = 12, Z = -110, Width = 88, Depth = 72},
		Apex = {X = 40, Y = 16, Z = -180, Width = 104, Depth = 76},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "EastGallery"}, {"Basin", "Crossing"},
			{"EastGallery", "Apex"}, {"Crossing", "WestGallery"}, {"WestGallery", "Apex"},
		},
		-- The gallery steps: broad slate steps from the isle up to the upper gallery.
		Stairs = {Crossing_WestGallery = true},
		Names = {
			Sanctuary = "Lampwright's Stair", Basin = "Drip Hall", EastGallery = "Lower Lamp Gallery",
			Crossing = "Netted Isle", WestGallery = "Upper Lamp Gallery", Apex = "Lantern Vault",
		},
		Terrain = {
			Direct = true,
			Surface = "FUNGAL",
			Decks = {Sanctuary = true},
			-- The Netted Isle is terrain, not a slab: a squircle 3 studs past its edges, its corners falling away
			-- into the pool, so it reads as a rock island.
			Shapes = {Crossing = {Round = 3.2, Grow = 3}},
			LiquidRise = 2.6,
			FloorDip = 2.2,
			WallBand = {Base = 38, Noise = 14},
			Pools = {
				{X = -20, Z = -40, RX = 60, RZ = 56},  -- the span pool round the Netted Isle
				{X = -120, Z = 40, RX = 26, RZ = 20},  -- drip puddle below the hall's west end
				{X = 10, Z = -110, RX = 26, RZ = 20},  -- drip puddle below the vault
			},
			GroveScale = 0.5,
			GroundCover = {"GlowcapTuftA", "GlowcapTuftB", "SporeMoss", "GlowcapTuftA"},
			GroundCoverCount = 170,
			-- The veins thicken on this floor.
			CliffVeins = 40,
		},
		-- A small oculus over the isle: daylight filtered through the nets.
		Skylight = {X = -20, Z = -40, Radius = 28},
	},
	-- Floor 8, Blooming Chasm (Fungal Hollow): the cavern floor fell away and the Veinweb bloomed in the chasm.
	-- The Lampkeepers (the last Velmari who refused the Veinweb) made their refuge here: their last lit camp is
	-- the Sanctuary, and from the Rim of Blooms their rope walkways, lashed to the Veinweb's cables, hang out
	-- over the chasm to the Violet Cap (the walkable top of a colossal mushroom) and the Crystal Islet. Both
	-- reach the Old Aqueduct, a surviving Velmari span running east-west between them, whose stairs climb to
	-- the Bloomcrown Ledge; the islet also climbs the Spine, a rock ridge, straight to the ledge.
	[8] = {
		Key = "fungal:8",
		Name = "Blooming Chasm",
		PathStyle = "VELMARI",
		Basin = {X = 0, Y = 0, Z = 136, Width = 400, Depth = 96},
		-- Square, so the round cap top (a disc through its corners) stays close to it.
		WestGallery = {X = -140, Y = 8, Z = -20, Width = 62, Depth = 62},
		EastGallery = {X = 150, Y = 4, Z = -30, Width = 84, Depth = 76},
		-- 48 deep, so the deck's camp stays clear of the stairs' first treads (they start 4 studs inside it).
		Crossing = {X = 10, Y = 12, Z = -60, Width = 96, Depth = 48},
		Apex = {X = 0, Y = 20, Z = -196, Width = 104, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"}, {"Basin", "EastGallery"},
			{"WestGallery", "Crossing"}, {"EastGallery", "Crossing"},
			{"Crossing", "Apex"}, {"EastGallery", "Apex"},
		},
		Names = {
			Sanctuary = "Lampkeepers' Rest", Basin = "Rim of Blooms", WestGallery = "Violet Cap",
			EastGallery = "Crystal Islet", Crossing = "Old Aqueduct", Apex = "Bloomcrown Ledge",
		},
		Terrain = {
			Direct = true,
			Surface = "FUNGAL",
			-- Built or grown decks: the Sanctuary's landing, the aqueduct (a span: no ground raised under it)
			-- and the Violet Cap's top (a round cap on its stem: no ground under it either).
			Decks = {Sanctuary = true, Crossing = true, WestGallery = true},
			DeckThickness = {Crossing = 4, WestGallery = 3},
			RoundDecks = {WestGallery = true},
			-- The Lampkeepers' rope walkways: plank decks hung over the chasm (solid, visible parts; the chasm
			-- stays open beneath them). The Spine (EastGallery_Apex) is a rock ridge: terrain.
			Bridges = {Basin_WestGallery = true, Basin_EastGallery = true, WestGallery_Crossing = true, EastGallery_Crossing = true},
			LiquidRise = 2.6,
			FloorDip = 2.2,
			WallBand = {Base = 40, Noise = 14},
			Pools = {
				{X = 10, Z = -62, RX = 58, RZ = 34},   -- under the aqueduct
				{X = -136, Z = -22, RX = 40, RZ = 36}, -- round the Violet Cap's stem
				{X = 64, Z = 30, RX = 40, RZ = 28},    -- the bloom pool in the middle of the chasm
			},
			-- A sea of mid-size caps on the chasm floor, below eye level.
			GroveScale = 1.3,
			GroundCover = {"GlowcapTuftA", "GlowcapTuftB", "SporeMoss", "GlowcapTuftA"},
			GroundCoverCount = 200,
			CliffVeins = 30,
		},
		-- The widest oculus yet, over the middle of the chasm: the brightest Fungal floor.
		Skylight = {X = 0, Z = -50, Radius = 56},
	},
	-- Floor 9, Rotcap Keep (Fungal Hollow): the Velmari citadel devoured from the inside by rotcaps, and the
	-- scene of the Lampkeepers' last stand. An "H" layout with a high keystone: both wings climb north along
	-- the cavern walls (Brewing Cellars -> West Rot-Spire; Ossuary of Caps -> East Rot-Spire), then high
	-- spans cross from both spires to The Keystone suspended over the central rot pit, whose stairs climb
	-- to the roofless Keep of the Rotcap under a colossal rotcap.
	[9] = {
		Key = "fungal:9",
		Name = "Rotcap Keep",
		PathStyle = "VELMARI",
		Basin = {X = 0, Y = 0, Z = 160, Width = 440, Depth = 110},
		WestGallery = {X = -156, Y = 8, Z = -12, Width = 92, Depth = 80},
		EastGallery = {X = 160, Y = 12, Z = -20, Width = 92, Depth = 80},
		WestBastion = {X = -150, Y = 16, Z = -144, Width = 88, Depth = 78},
		EastBastion = {X = 150, Y = 20, Z = -136, Width = 88, Depth = 78},
		Crossing = {X = 0, Y = 20, Z = -124, Width = 76, Depth = 62},
		Apex = {X = 0, Y = 24, Z = -228, Width = 108, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"}, {"Basin", "EastGallery"},
			{"WestGallery", "WestBastion"}, {"EastGallery", "EastBastion"},
			{"WestBastion", "Crossing"}, {"EastBastion", "Crossing"},
			{"Crossing", "Apex"},
		},
		Names = {
			Sanctuary = "The Broken Gate", Basin = "Fallen Quarry", WestGallery = "Brewing Cellars",
			EastGallery = "Ossuary of Caps", WestBastion = "West Rot-Spire", EastBastion = "East Rot-Spire",
			Crossing = "The Keystone", Apex = "Keep of the Rotcap",
		},
		Terrain = {
			Direct = true,
			Surface = "FUNGAL",
			Decks = {Sanctuary = true, Crossing = true},
			DeckThickness = {Crossing = 4},
			-- High stone-and-plank spans crossing from both rot-spires to The Keystone above the rot pit.
			Bridges = {WestBastion_Crossing = true, EastBastion_Crossing = true},
			LiquidRise = 2.6,
			FloorDip = 2.2,
			WallBand = {Base = 40, Noise = 14},
			Pools = {
				{X = 0, Z = -76, RX = 68, RZ = 74},    -- the central rot pit under The Keystone
				{X = -96, Z = -78, RX = 36, RZ = 32},  -- west rot pool under the high span
				{X = 96, Z = -78, RX = 36, RZ = 32},   -- east rot pool under the high span
			},
			GroveScale = 0.65,
			GroundCover = {"GlowcapTuftA", "GlowcapTuftB", "SporeMoss", "GlowcapTuftA"},
			GroundCoverCount = 190,
			CliffVeins = 44,
		},
		Skylight = {X = 0, Z = -124, Radius = 36},
	},
	-- Floor 10, Matriarch's Hollow (Fungal Hollow, BOSS_ARENA): the Spore Matriarch's nest, and the floor
	-- that plays least like Floor 9. Floor 9 climbs wings to spires against the north wall; here the boss dais
	-- is a rock mesa in the MIDDLE of the nest, under the great oculus, and the terraces ring it: from the
	-- Silk Shore the route laps the dais (west by the Egg Gallery and the West Cocoon Arcade, or east by the
	-- Spinneret and the East Cocoon Arcade) to the Brood Pillar at the very back, the gate of the nest, and
	-- the only way in is the Silk Stair from the pillar, inward and up across the brood pool to the dais. The
	-- Matriarch is in view from every side of the lap.
	[10] = {
		Key = "fungal:10",
		Name = "Matriarch's Hollow",
		PathStyle = "VELMARI",
		Basin = {X = 0, Y = 0, Z = 196, Width = 480, Depth = 100},
		WestGallery = {X = -205, Y = 8, Z = -30, Width = 86, Depth = 80},
		EastGallery = {X = 205, Y = 12, Z = -30, Width = 86, Depth = 80},
		WestBastion = {X = -160, Y = 16, Z = -215, Width = 86, Depth = 80},
		EastBastion = {X = 160, Y = 20, Z = -215, Width = 86, Depth = 80},
		-- The Brood Pillar: a deck on a silk-and-mushroom column at the back of the nest, the ring's low point.
		Crossing = {X = 0, Y = 12, Z = -262, Width = 76, Depth = 68},
		-- The dais: a rounded rock mesa in the middle of the nest (terrain), the boss arena.
		Apex = {X = 0, Y = 28, Z = -60, Width = 140, Depth = 110},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"}, {"Basin", "EastGallery"},
			{"WestGallery", "WestBastion"}, {"EastGallery", "EastBastion"},
			{"WestBastion", "Crossing"}, {"EastBastion", "Crossing"},
			{"Crossing", "Apex"},
		},
		-- The wall stairs up to the cocoon arcades (the Silk Stair is stairs anyway: every Crossing -> Apex is).
		Stairs = {WestGallery_WestBastion = true, EastGallery_EastBastion = true},
		Names = {
			Sanctuary = "The Last Lamp", Basin = "Silk Shore", WestGallery = "West Egg Gallery",
			EastGallery = "Spinneret Ledge", WestBastion = "West Cocoon Arcade", EastBastion = "East Cocoon Arcade",
			Crossing = "Brood Pillar", Apex = "Matriarch's Dais",
		},
		-- The Silk Stair lands on the dais' north side, so the boss portals stand at its south side, facing the
		-- way the Masters came in, spread wide of the Veinweb heart between them.
		Portals = {Side = "SOUTH", Spread = 44},
		Terrain = {
			Direct = true,
			Surface = "FUNGAL",
			Decks = {Sanctuary = true, Crossing = true},
			DeckThickness = {Crossing = 4},
			Shapes = {Apex = {Round = 3.0, Grow = 4}},
			-- The dais is in the middle: no shelf behind it (the ring's north terraces stand there).
			NoApexShelf = true,
			-- Silk spans hung over the brood pool: the back ring to the pillar, and the Silk Stair to the dais.
			Bridges = {WestBastion_Crossing = true, EastBastion_Crossing = true, Crossing_Apex = true},
			LiquidRise = 2.6,
			FloorDip = 6,
			WallBand = {Base = 34, Noise = 12},
			Pools = {
				{X = 0, Z = -46, RX = 124, RZ = 128},   -- the brood pool round the dais mesa
				{X = 0, Z = -262, RX = 54, RZ = 42},    -- under the Brood Pillar
				{X = -84, Z = -246, RX = 40, RZ = 28},  -- under the west span
				{X = 84, Z = -246, RX = 40, RZ = 28},   -- under the east span
			},
			-- A made nest: few caps outside the heart, silk and stone instead.
			GroveScale = 0.35,
			GroundCover = {"SporeMoss", "GlowcapTuftB", "SporeMoss"},
			GroundCoverCount = 140,
			CliffVeins = 54,
		},
		-- The great oculus, over the dais in the middle of the nest.
		Skylight = {X = 0, Z = -60, Radius = 70},
	},
	-- Floor 11, Cinder Gate (Ashen Dunes Introduction): wind-rippled black-ash plains swept by the central
	-- Sleeping Dune (dead-end Dune Crest lookout) with a half-buried Varrash caravan wreck, banded Toll House
	-- ruins, a cylindrical Watch Kiln tower, waystone-lined tracks, and the towering Cinder Gate in the basalt wall.
	[11] = {
		Key = "ashen:1",
		Name = "Cinder Gate",
		PathStyle = "VARRASH",
		DirectTerrain = true,
		Liquid = { Dry = true },
		TerrainFeatures = {
			{ Kind = "DUNE", X = -8, Z = -64, Width = 148, Length = 132, Height = 19, Yaw = -16, CrestSway = 0.22, SlipSteep = 0.92, RippleAmp = 0.22 },
			{ Kind = "DUNE", X = -84, Z = 26, Width = 54, Length = 60, Height = 5.5, Yaw = 25, CrestSway = 0.14, SlipSteep = 0.92 },
			{ Kind = "DUNE", X = 86, Z = 18, Width = 56, Length = 62, Height = 6.0, Yaw = -22, CrestSway = 0.14, SlipSteep = 0.92 },
		},
		Basin = {X = 0, Y = 0, Z = 82, Width = 330, Depth = 88},
		Crossing = {X = 0, Y = 10, Z = -20, Width = 48, Depth = 44},
		WestGallery = {X = -116, Y = 4, Z = -20, Width = 84, Depth = 76},
		EastGallery = {X = 118, Y = 7, Z = -44, Width = 80, Depth = 72},
		Apex = {X = 0, Y = 12, Z = -150, Width = 110, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"}, {"Basin", "EastGallery"}, {"Basin", "Crossing"},
			{"WestGallery", "Apex"}, {"EastGallery", "Apex"},
		},
		Names = {
			Sanctuary = "Sun-Bleached Steps", Basin = "Ash Flats", Crossing = "Dune Crest",
			WestGallery = "Toll House", EastGallery = "Watch Kiln", Apex = "Cinder Gate",
		},
	},
	-- Floor 12, Buried Caravan (Ashen Dunes Expanded): a single switchback caravan road climbing from the
	-- Wagon Circle entry through the colossal Sand-Strider Ribcage, across the buried Caravanserai Roof deck
	-- with flush skylights, past the collapsed Spice Vault with burst saffron & crimson urns, up to the
	-- tented Caravan Master's Tomb Pavilion off-centre east.
	[12] = {
		Key = "ashen:2",
		Name = "Buried Caravan",
		PathStyle = "VARRASH",
		DirectTerrain = true,
		Masonry = "VARRASH_DECK",
		Decks = {
			Crossing = true,
		},
		Liquid = { Dry = true },
		TerrainFeatures = {
			{ Kind = "DUNE", X = -85, Z = 42, Width = 80, Length = 90, Height = 9.0, Yaw = 24, CrestSway = 0.16, SlipSteep = 0.95 },
			{ Kind = "DUNE", X = 148, Z = -82, Width = 110, Length = 100, Height = 13.0, Yaw = -28, CrestSway = 0.18, SlipSteep = 0.95 },
			{ Kind = "DUNE", X = -125, Z = -148, Width = 115, Length = 95, Height = 14.0, Yaw = 18, CrestSway = 0.18, SlipSteep = 0.95 },
		},
		Basin = {X = 0, Y = 0, Z = 110, Width = 360, Depth = 96},
		EastGallery = {X = 130, Y = 5, Z = 10, Width = 88, Depth = 76},
		Crossing = {X = -10, Y = 9, Z = -30, Width = 70, Depth = 56},
		WestGallery = {X = -130, Y = 12, Z = -80, Width = 88, Depth = 76},
		Apex = {X = 40, Y = 14, Z = -170, Width = 104, Depth = 80},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "EastGallery"},
			{"EastGallery", "Crossing"},
			{"Crossing", "WestGallery"},
			{"WestGallery", "Apex"},
		},
		Names = {
			Sanctuary = "Caravan Brink", Basin = "Wagon Circle", EastGallery = "Strider's Ribs",
			Crossing = "Caravanserai Roof", WestGallery = "Spice Vault", Apex = "Caravan Master's Tomb",
		},
	},
	-- Floor 13, Glasswind Ravine (Ashen Dunes Expanded): a deep north-south obsidian canyon splits
	-- two wall ledges (West Ledge high on the west rim, East Ledge lower on the east rim), joined
	-- only across a suspended fused-glass Glass Arch (Crossing); east ledge reaches Apex only via the arch.
	[13] = {
		Key = "ashen:3",
		Name = "Glasswind Ravine",
		PathStyle = "VARRASH",
		DirectTerrain = true,
		Masonry = "VARRASH_GLASS",
		Decks = {
			Crossing = true,
		},
		Suspended = {
			Platforms = { Crossing = true },
			Links = {
				WestGallery_Crossing = true,
				EastGallery_Crossing = true,
				Crossing_Apex = true,
			},
		},
		Liquid = { Dry = true },
		TerrainFeatures = {
			{ Kind = "RAVINE", X = 0, ZStart = -142, ZEnd = 74, HalfWidth = 48, NoiseAmp = 8 },
			{ Kind = "DUNE", X = -108, Z = 44, Width = 76, Length = 80, Height = 8.0, Yaw = 16, CrestSway = 0.14, SlipSteep = 0.95 },
		},
		Basin = {X = 0, Y = 0, Z = 124, Width = 400, Depth = 104},
		WestGallery = {X = -140, Y = 10, Z = -34, Width = 80, Depth = 110},
		EastGallery = {X = 140, Y = 6, Z = -56, Width = 80, Depth = 110},
		Crossing = {X = 0, Y = 5, Z = -78, Width = 64, Depth = 44},
		Apex = {X = 0, Y = 18, Z = -185, Width = 110, Depth = 84},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "WestGallery"},
			{"Basin", "EastGallery"},
			{"WestGallery", "Crossing"},
			{"EastGallery", "Crossing"},
			{"Crossing", "Apex"},
			{"WestGallery", "Apex"},
		},
		Patrols = {
			WEST_LEDGE = { "WestGallery", "Apex" },
			ARCH_CROSSING = { "WestGallery", "Crossing", "EastGallery" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Ravine Threshold", Basin = "Ravine Mouth", WestGallery = "West Ledge",
			EastGallery = "East Ledge", Crossing = "Glass Arch", Apex = "Lightning Scar",
		},
	},
	-- Floor 14, Sunscar Fortress (Ashen Dunes Elite Stronghold): Varrash kiln fortress split down the
	-- middle by the Sunscar lava fissure. Basin (Ashmarket) enters solely through the Kiln Gate chokepoint
	-- (Crossing), splits to Glassblowers' Row & Cistern Barracks joined across the chasm by the suspended
	-- Scar Bridge, and climbs West Kiln & Signal Tower to the glass-floored Sunscar Throne.
	[14] = {
		Key = "ashen:4",
		Name = "Sunscar Fortress",
		PathStyle = "VARRASH",
		DirectTerrain = true,
		Masonry = "VARRASH_FORTRESS",
		Decks = {
			Crossing = true,
			Apex = true,
		},
		Suspended = {
			Platforms = { Crossing = true, Apex = true },
			Links = {
				Basin_Crossing = true,
				Crossing_WestGallery = true,
				Crossing_EastGallery = true,
				WestGallery_EastGallery = true,
				WestBastion_Apex = true,
				EastBastion_Apex = true,
			},
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{
				Kind = "LAVA_CHANNEL",
				X = 0, ZStart = -220, ZEnd = 64, HalfWidth = 22, NoiseAmp = 6, Gain = 0.36,
				GateMoat = { Z = 54, RX = 78, RZ = 28 },
			},
		},
		Patrols = {
			SCAR_BRIDGE = { "WestGallery", "EastGallery" },
		},
		Basin = {X = 0, Y = 0, Z = 150, Width = 440, Depth = 110},
		Crossing = {X = 0, Y = 5, Z = 52, Width = 74, Depth = 60},
		WestGallery = {X = -160, Y = 8, Z = 0, Width = 86, Depth = 78},
		EastGallery = {X = 160, Y = 8, Z = -10, Width = 86, Depth = 78},
		WestBastion = {X = -160, Y = 14, Z = -150, Width = 84, Depth = 76},
		EastBastion = {X = 160, Y = 16, Z = -160, Width = 84, Depth = 76},
		Apex = {X = 0, Y = 22, Z = -205, Width = 110, Depth = 84},
		Paths = {
			{"Sanctuary", "Basin"},
			{"Basin", "Crossing"},
			{"Crossing", "WestGallery"},
			{"Crossing", "EastGallery"},
			{"WestGallery", "EastGallery"},
			{"WestGallery", "WestBastion"},
			{"EastGallery", "EastBastion"},
			{"WestBastion", "Apex"},
			{"EastBastion", "Apex"},
		},
		Names = {
			Sanctuary = "Kiln Threshold", Basin = "Ashmarket", Crossing = "Kiln Gate",
			WestGallery = "Glassblowers' Row", EastGallery = "Cistern Barracks",
			WestBastion = "West Kiln", EastBastion = "Signal Tower", Apex = "Sunscar Throne",
		},
	},
	-- Floor 15, Colossus Dais (Ashen Dunes Boss Arena): Cinderhold's caldera around a cracked-lava lake.
	-- Players cross the fallen Elder Colossus's body (Fallen Hand -> forearm -> Elder's Chest -> upper arm -> Shoulder)
	-- or climb its Broken Shield & Fallen Crown, or take the exposed trade-road stairs to the 140x110 Colossus Dais.
	[15] = {
		Key = "ashen:5",
		Name = "Colossus Dais",
		PathStyle = "VARRASH",
		DirectTerrain = true,
		Masonry = "VARRASH_DAIS",
		Decks = {
			Crossing = true,
			Apex = true,
		},
		Suspended = {
			Platforms = { Crossing = true, Apex = true },
			Links = {
				WestGallery_Crossing = true,
				Crossing_WestBastion = true,
				Crossing_Apex = true,
				WestBastion_Apex = true,
				EastBastion_Apex = true,
			},
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{
				Kind = "CENOTE_LAGOON",
				Z = -28, RX = 220, RZ = 165, NoiseScale = 58, NoiseAmp = 0.09, NoiseSeed = 91, Base = 0.30, Gain = 0.36,
			},
		},
		Basin = { X = 0, Y = 0, Z = 176, Width = 480, Depth = 108 },
		WestGallery = { X = -180, Y = 6, Z = 30, Width = 88, Depth = 80 },
		Crossing = { X = -30, Y = 10, Z = -40, Width = 80, Depth = 64 },
		EastGallery = { X = 180, Y = 8, Z = 20, Width = 88, Depth = 80 },
		WestBastion = { X = -150, Y = 16, Z = -150, Width = 86, Depth = 80 },
		EastBastion = { X = 170, Y = 14, Z = -140, Width = 86, Depth = 80 },
		Apex = { X = 0, Y = 28, Z = -232, Width = 140, Depth = 110 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "WestGallery", "Crossing" },
			{ "Basin", "EastGallery" },
			{ "Crossing", "WestBastion" },
			{ "EastGallery", "EastBastion" },
			{ "WestBastion", "Apex" },
			{ "EastBastion", "Apex" },
			{ "Crossing", "Apex" },
		},
		Stairs = { Crossing_Apex = true },
		Patrols = {
			FOREARM = { "WestGallery", "Crossing", "WestBastion" },
			SHIELD_CLIMB = { "EastGallery", "EastBastion" },
			CROWN_RING = { "WestBastion", "Apex", "EastBastion" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Caldera Brink", Basin = "Caldera Floor", WestGallery = "Fallen Hand",
			Crossing = "Elder's Chest", EastGallery = "Broken Shield",
			WestBastion = "Shoulder", EastBastion = "Fallen Crown", Apex = "Colossus Dais",
		},
	},
	-- Floor 16, Rimefall Approach (Frozen Citadel): natural deep winter below the frozen Rimefall.
	-- Two routes cross the frozen lake: the long shoreline road round Hunters' Lodge on the west bank,
	-- or the narrow chain of jagged ice floes across the lake (with Fisher's Hut on a side floe).
	[16] = {
		Key = "frozen:1",
		Name = "Rimefall Approach",
		PathStyle = "WHITEGUARD",
		DirectTerrain = true,
		Masonry = "GLACIER_SLAB",
		Decks = {
			FloeSouth = true,
			Crossing = true,
			FloeNorth = true,
		},
		Suspended = {
			Platforms = { FloeSouth = true, Crossing = true, FloeNorth = true },
			Links = {
				Basin_FloeSouth = true,
				FloeSouth_Crossing = true,
				Crossing_EastGallery = true,
				Crossing_FloeNorth = true,
				FloeNorth_Apex = true,
			},
		},
		Liquid = { LevelOffset = 2.8, FloorDip = 1.6 },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 84, Feather = 28 },
			{
				Kind = "POOL_ELLIPSES_SQ",
				Strength = 0.28,
				Gain = 0.28,
				Ellipses = {
					{ X = 54, Z = -46, RX = 108, RZ = 82 },
					{ X = 18, Z = -94, RX = 60, RZ = 46 },
				},
			},
			{
				Kind = "PRESSURE_RIDGE",
				Ridges = {
					{ AX = -12, AZ = -18, BX = 26, BZ = -62, HalfWidth = 4.5, Height = 2.2, WarpAmp = 4.5 },
					{ AX = 84, AZ = 6, BX = 104, BZ = -84, HalfWidth = 4.2, Height = 2.0, WarpAmp = 5.0 },
				},
			},
			{ Kind = "ICEFALL", X = -8, Z = -196, Width = 108, Depth = 34, Height = 42 },
			{ Kind = "DUNE", X = -84, Z = 132, Width = 34, Length = 52, Height = 3.8, Yaw = 12, CrestSway = 0.14, SlipSteep = 1.25 },
			{ Kind = "DUNE", X = 96, Z = 134, Width = 36, Length = 50, Height = 3.6, Yaw = -10, CrestSway = 0.14, SlipSteep = 1.25 },
		},
		Basin = { X = 0, Y = 0, Z = 90, Width = 330, Depth = 80 },
		WestGallery = { X = -116, Y = 4, Z = -10, Width = 84, Depth = 76 },
		Crossing = { X = 60, Y = 4, Z = -50, Width = 56, Depth = 48 },
		EastGallery = { X = 130, Y = 5, Z = -30, Width = 60, Depth = 56 },
		ExtraPlatforms = {
			FloeSouth = { X = 40, Y = 2, Z = 10, Width = 40, Depth = 36 },
			FloeNorth = { X = 60, Y = 8, Z = -108, Width = 40, Depth = 36 },
		},
		Apex = { X = -30, Y = 12, Z = -158, Width = 104, Depth = 76 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "WestGallery", "Apex" },
			{ "Basin", "FloeSouth" },
			{ "FloeSouth", "Crossing" },
			{ "Crossing", "EastGallery" },
			{ "Crossing", "FloeNorth" },
			{ "FloeNorth", "Apex" },
		},
		Names = {
			Sanctuary = "Snowdrift Gate",
			Basin = "Snowfield",
			WestGallery = "Hunters' Lodge",
			FloeSouth = "South Floe",
			Crossing = "Heart Floe",
			EastGallery = "Fisher's Hut",
			FloeNorth = "North Floe",
			Apex = "Rimefall Shrine",
		},
	},
	-- Floor 17, Frozen Barracks (Frozen Citadel Expanded): garrison streets forming a walkable mesh converging on the
	-- Armory and climbing a grand straight granite stair to the Commander's Hall, with the drill company frozen mid-march.
	[17] = {
		Key = "frozen:2",
		Name = "Frozen Barracks",
		PathStyle = "WHITEGUARD",
		DirectTerrain = true,
		Masonry = "WHITEGUARD",
		Liquid = { Dry = true },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 98, Feather = 24 },
			{ Kind = "DUNE", X = -152, Z = 136, Width = 38, Length = 68, Height = 5.2, Yaw = 8, CrestSway = 0.14, SlipSteep = 1.2 },
			{ Kind = "DUNE", X = 152, Z = 136, Width = 38, Length = 68, Height = 5.2, Yaw = -8, CrestSway = 0.14, SlipSteep = 1.2 },
			{ Kind = "DUNE", X = -148, Z = -128, Width = 44, Length = 72, Height = 6.0, Yaw = 12, CrestSway = 0.14, SlipSteep = 1.2 },
		},
		Basin = { X = 0, Y = 0, Z = 112, Width = 360, Depth = 92 },
		WestGallery = { X = -130, Y = 6, Z = 0, Width = 84, Depth = 76 },
		Crossing = { X = 0, Y = 4, Z = -10, Width = 72, Depth = 58 },
		EastGallery = { X = 130, Y = 6, Z = 0, Width = 84, Depth = 76 },
		ExtraPlatforms = {
			Armory = { X = 0, Y = 10, Z = -96, Width = 64, Depth = 44 },
		},
		Apex = { X = 0, Y = 14, Z = -180, Width = 104, Depth = 80 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "EastGallery" },
			{ "Basin", "Crossing" },
			{ "WestGallery", "Crossing" },
			{ "EastGallery", "Crossing" },
			{ "Crossing", "Armory" },
			{ "WestGallery", "Armory" },
			{ "EastGallery", "Armory" },
			{ "Armory", "Apex" },
		},
		Stairs = { Armory_Apex = true },
		Names = {
			Sanctuary = "Barracks Gate",
			Basin = "Parade Ground",
			WestGallery = "West Barracks",
			Crossing = "Mess Hall",
			EastGallery = "East Barracks & Kennels",
			Armory = "Armory",
			Apex = "Commander's Hall",
		},
	},
	-- Floor 18, Shattered Iceway (Frozen Citadel Terrain Variation): an inverted ravine with a central glacier spine
	-- rising in two heaved road slabs (Lower Iceway -> Upper Iceway), flanked by twin crevasses spanned by suspended
	-- ice-slab bridges to West and East Moraines; East Moraine rejoins the spine while West Moraine climbs to the Icefall Gate.
	[18] = {
		Key = "frozen:3",
		Name = "Shattered Iceway",
		PathStyle = "WHITEGUARD",
		DirectTerrain = true,
		Masonry = "GLACIER_SLAB",
		Decks = {
			Crossing = true,
			UpperIceway = true,
		},
		Suspended = {
			Links = {
				Crossing_WestGallery = true,
				Crossing_EastGallery = true,
				EastGallery_UpperIceway = true,
			},
		},
		Liquid = { Dry = true },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 112, Feather = 28 },
			{ Kind = "GLACIER_SPINE", X = 0, ZStart = -152, ZEnd = 68, HalfWidth = 42, BaseHeight = 12, RiseHeight = 8, StrataAmp = 1.4, NoiseAmp = 5 },
			{ Kind = "RAVINE", X = -86, ZStart = -126, ZEnd = 62, HalfWidth = 34, NoiseAmp = 7, IceFloor = true },
			{ Kind = "RAVINE", X = 86, ZStart = -146, ZEnd = 62, HalfWidth = 34, NoiseAmp = 7, IceFloor = true },
			{ Kind = "ICEFALL", X = 0, Z = -242, Width = 136, Depth = 42, Height = 56 },
			{ Kind = "DUNE", X = -148, Z = 138, Width = 44, Length = 72, Height = 5.6, Yaw = 12, CrestSway = 0.14, SlipSteep = 1.2 },
			{ Kind = "DUNE", X = 148, Z = 138, Width = 44, Length = 72, Height = 5.6, Yaw = -12, CrestSway = 0.14, SlipSteep = 1.2 },
		},
		Basin = { X = 0, Y = 0, Z = 124, Width = 400, Depth = 104 },
		Crossing = { X = 0, Y = 6, Z = 10, Width = 70, Depth = 60 },
		WestGallery = { X = -150, Y = 8, Z = -40, Width = 80, Depth = 80 },
		EastGallery = { X = 150, Y = 4, Z = -70, Width = 80, Depth = 80 },
		ExtraPlatforms = {
			UpperIceway = { X = 0, Y = 12, Z = -96, Width = 64, Depth = 56 },
		},
		Apex = { X = 0, Y = 18, Z = -190, Width = 110, Depth = 84 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Crossing" },
			{ "Crossing", "WestGallery" },
			{ "Crossing", "EastGallery" },
			{ "Crossing", "UpperIceway" },
			{ "UpperIceway", "Apex" },
			{ "WestGallery", "Apex" },
			{ "EastGallery", "UpperIceway" },
		},
		Stairs = { UpperIceway_Apex = true },
		Patrols = {
			WEST_MORAINE = { "WestGallery", "Apex" },
			ICEWAY_CROSS = { "WestGallery", "Crossing", "EastGallery" },
			EAST_CLIMB = { "EastGallery", "UpperIceway" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Moraine Gate",
			Basin = "Moraine Foot",
			Crossing = "Lower Iceway",
			UpperIceway = "Upper Iceway",
			WestGallery = "West Moraine",
			EastGallery = "East Moraine",
			Apex = "Icefall Gate",
		},
	},
	-- Floor 19, Whiteguard Keep (Frozen Citadel Elite Stronghold): two separated routes under twilight aurora —
	-- west glacier caves glowing with rimelight crystals, east elevated battlement viaduct, East Bailey trebuchet,
	-- and Whiteguard Tower converging solely at the Keep Hall.
	[19] = {
		Key = "frozen:4",
		Name = "Whiteguard Keep",
		PathStyle = "WHITEGUARD",
		DirectTerrain = true,
		Masonry = "WHITEGUARD_FORTRESS",
		Decks = {
			Crossing = true,
			EastGallery = true,
			EastBastion = true,
			Apex = true,
		},
		Suspended = {
			Links = {
				Basin_Crossing = true,
				Crossing_WestGallery = true,
				Crossing_EastGallery = true,
				EastGallery_EastBastion = true,
				EastBastion_Apex = true,
			},
		},
		Liquid = { Dry = true },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 124, Feather = 32 },
			{ Kind = "RAVINE", X = 48, ZStart = -165, ZEnd = 92, HalfWidth = 48, NoiseAmp = 8, IceFloor = true },
			{ Kind = "ICEFALL", X = -22, Z = -255, Width = 160, Depth = 44, Height = 58 },
			{ Kind = "DUNE", X = -176, Z = 176, Width = 52, Length = 80, Height = 5.5, Yaw = 14, CrestSway = 0.14, SlipSteep = 1.2 },
			{ Kind = "DUNE", X = 176, Z = 176, Width = 52, Length = 80, Height = 5.5, Yaw = -14, CrestSway = 0.14, SlipSteep = 1.2 },
		},
		Patrols = {
			VIADUCT = { "Crossing", "EastGallery" },
		},
		Basin = { X = 0, Y = 0, Z = 160, Width = 440, Depth = 110 },
		Crossing = { X = 40, Y = 8, Z = 10, Width = 74, Depth = 60 },
		EastGallery = { X = 165, Y = 10, Z = -30, Width = 86, Depth = 78 },
		EastBastion = { X = 160, Y = 16, Z = -160, Width = 84, Depth = 76 },
		WestGallery = { X = -165, Y = 4, Z = -10, Width = 86, Depth = 78 },
		WestBastion = { X = -160, Y = 12, Z = -150, Width = 84, Depth = 76 },
		Apex = { X = 0, Y = 22, Z = -210, Width = 110, Depth = 84 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Crossing" },
			{ "Crossing", "WestGallery" },
			{ "Crossing", "EastGallery" },
			{ "EastGallery", "EastBastion" },
			{ "EastBastion", "Apex" },
			{ "Basin", "WestGallery" },
			{ "WestGallery", "WestBastion" },
			{ "WestBastion", "Apex" },
		},
		Names = {
			Sanctuary = "Siege Threshold",
			Basin = "Siege Camp",
			Crossing = "Viaduct Gate",
			EastGallery = "East Bailey",
			EastBastion = "Whiteguard Tower",
			WestGallery = "Ice Cave Mouth",
			WestBastion = "Crystal Grotto",
			Apex = "Keep Hall",
		},
	},
	-- Floor 20, Frostbound Throne (Frozen Citadel Boss Cathedral): long symmetric ruined gothic throne hall —
	-- Frozen Antechamber into the Nave of Kneeling Knights flanked by West/East Aisles via transepts,
	-- ascending to West/East Chapels and up the Royal Stair to the Frostbound Throne Dais under night aurora.
	[20] = {
		Key = "frozen:5",
		Name = "Frostbound Throne",
		PathStyle = "WHITEGUARD",
		DirectTerrain = true,
		Masonry = "THRONE_HALL",
		Decks = {
			Crossing = true,
			WestGallery = true,
			EastGallery = true,
			WestBastion = true,
			EastBastion = true,
			Apex = true,
		},
		Suspended = {
			Platforms = { Crossing = true, Apex = true },
			Links = {
				Basin_Crossing = true,
				Crossing_WestGallery = true,
				Crossing_EastGallery = true,
				WestGallery_WestBastion = true,
				EastGallery_EastBastion = true,
				WestBastion_Apex = true,
				EastBastion_Apex = true,
				Crossing_Apex = true,
			},
		},
		Liquid = { Dry = true },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 152, Feather = 34 },
			{ Kind = "ICEFALL", X = 0, Z = -322, Width = 140, Depth = 34, Height = 68 },
		},
		Patrols = {
			TRANSEPT = { "WestGallery", "Crossing", "EastGallery" },
		},
		Basin = { X = 0, Y = 0, Z = 180, Width = 480, Depth = 100 },
		Crossing = { X = 0, Y = 8, Z = 10, Width = 72, Depth = 120 },
		WestGallery = { X = -170, Y = 6, Z = 20, Width = 86, Depth = 80 },
		EastGallery = { X = 170, Y = 6, Z = 20, Width = 86, Depth = 80 },
		WestBastion = { X = -165, Y = 16, Z = -130, Width = 86, Depth = 80 },
		EastBastion = { X = 165, Y = 16, Z = -130, Width = 86, Depth = 80 },
		Apex = { X = 0, Y = 28, Z = -232, Width = 140, Depth = 110 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Crossing" },
			{ "Crossing", "WestGallery" },
			{ "Crossing", "EastGallery" },
			{ "WestGallery", "WestBastion" },
			{ "EastGallery", "EastBastion" },
			{ "WestBastion", "Apex" },
			{ "EastBastion", "Apex" },
			{ "Crossing", "Apex" },
		},
		Stairs = { Crossing_Apex = true },
		Names = {
			Sanctuary = "Cathedral Porch",
			Basin = "Frozen Antechamber",
			Crossing = "Nave of Kneeling Knights",
			WestGallery = "West Aisle",
			EastGallery = "East Aisle",
			WestBastion = "West Chapel",
			EastBastion = "East Chapel",
			Apex = "Frostbound Throne",
		},
	},
	-- Floor 21, Slagworks Entry (Infernal Foundry): the Sootwrights' outer works, where ore came in and
	-- slag went out. A hub with spokes: the Ore Yard crosses the Weighbridge onto the Great Turntable, and
	-- every route passes it. Four spurs leave the turntable (Sorting Shed, Slag Tip, Ore Crusher on its
	-- gantry, Coal Bunker), the Furnace Steps climb from it to the Furnace Gate, and one rim track links
	-- the Sorting Shed to the Ore Crusher. A bigger room than Floor 1 (Size, docs/prompts/
	-- infernal-foundry-floor-layouts-prompt.md Part 2): 9 terraces, 9 links, 8 walk heights.
	[21] = {
		Key = "infernal:1",
		Name = "Slagworks Entry",
		Size = { Width = 480, Depth = 525, Height = 160 },
		PathStyle = "SOOTWRIGHT",
		DirectTerrain = true,
		Surface = "SOOTWRIGHT",
		Masonry = "FOUNDRY_IRON",
		Decks = {
			Weighbridge = true,
			Crossing = true,
			OreCrusher = true,
			CoalBunker = true,
		},
		Suspended = {
			-- The Ore Crusher stands on an iron gantry; girder bridges carry the rail spurs up to it.
			Platforms = { OreCrusher = true },
			Links = {
				Crossing_OreCrusher = true,
				WestGallery_OreCrusher = true,
			},
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 96, Feather = 30 },
			-- The Slag Tip: cooled slag tipped off the east spur, a fan of clinker spilling south-west toward the yard.
			{ Kind = "SLAG_TIP", X = 212, Z = -8, Top = 30, Length = 78, Yaw = -24, HalfWidth = 20, Spread = 26 },
			-- Ore and coal heaps banked against the back corners behind the Crusher and the Bunker.
			{ Kind = "SLAG_TIP", X = -210, Z = -214, Top = 34, Length = 56, Yaw = 45, HalfWidth = 18, Spread = 22 },
			{ Kind = "SLAG_TIP", X = 210, Z = -218, Top = 32, Length = 52, Yaw = -45, HalfWidth = 18, Spread = 20 },
			-- Molten runoff pooled at the foot of the slag fan, and a sump under the crusher's girder spur.
			{
				Kind = "POOL_ELLIPSES_SQ",
				Strength = 0.28,
				Gain = 0.3,
				Ellipses = {
					{ X = 172, Z = 48, RX = 24, RZ = 10 },
					{ X = -84, Z = -88, RX = 18, RZ = 13 },
				},
			},
		},
		Basin = { X = 0, Y = 0, Z = 120, Width = 400, Depth = 90 },
		Crossing = { X = 0, Y = 4, Z = -10, Width = 96, Depth = 84 },
		WestGallery = { X = -150, Y = 8, Z = 0, Width = 84, Depth = 76 },
		EastGallery = { X = 150, Y = 12, Z = -20, Width = 84, Depth = 76 },
		ExtraPlatforms = {
			Weighbridge = { X = 0, Y = 2, Z = 54, Width = 60, Depth = 20 },
			OreCrusher = { X = -140, Y = 16, Z = -130, Width = 70, Depth = 60 },
			CoalBunker = { X = 140, Y = 6, Z = -140, Width = 70, Depth = 60 },
		},
		Apex = { X = 0, Y = 20, Z = -190, Width = 120, Depth = 84 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Weighbridge" },
			{ "Weighbridge", "Crossing" },
			{ "Crossing", "WestGallery" },
			{ "Crossing", "EastGallery" },
			{ "Crossing", "OreCrusher" },
			{ "Crossing", "CoalBunker" },
			{ "Crossing", "Apex" },
			{ "WestGallery", "OreCrusher" },
		},
		Stairs = { Crossing_Apex = true },
		Names = {
			Sanctuary = "Slagworks Gate",
			Basin = "Ore Yard",
			Weighbridge = "Weighbridge",
			Crossing = "Great Turntable",
			WestGallery = "Sorting Shed",
			EastGallery = "Slag Tip",
			OreCrusher = "Ore Crusher",
			CoalBunker = "Coal Bunker",
			Apex = "Furnace Gate",
		},
	},
	-- Floor 22, Molten Assembly (Infernal Foundry): the assembly hall, under a closed brick vault. A gantry
	-- crane spans the hall on two lattice piers, and its girder is the route: pier -> West Hoist -> Crane
	-- Trolley -> East Hoist -> pier, tilted by a failed jack (Y 8 up to 12). From the trolley a stem climbs over
	-- the Inspection Gallery and up an iron stair to the Assembly Hall; each pier also carries a dead-end loft
	-- (the Pattern Loft, the Control Cab). A loading ramp climbs from the yard straight to the trolley, so the
	-- walk to the hall stays within 1.5x the canonical floor's. 11 terraces, 12 links, 10 walk heights.
	[22] = {
		Key = "infernal:2",
		Name = "Molten Assembly",
		Size = { Width = 550, Depth = 615, Height = 180 },
		PathStyle = "SOOTWRIGHT",
		DirectTerrain = true,
		Surface = "SOOTWRIGHT",
		Masonry = "FOUNDRY_IRON",
		Decks = {
			WestGallery = true,
			WestHoist = true,
			Crossing = true,
			EastHoist = true,
			EastGallery = true,
			Inspection = true,
			PatternLoft = true,
			ControlCab = true,
		},
		Suspended = {
			-- Every deck stands on iron (gantry columns), and every link but the arrival and the hall stair is a
			-- girder bridge over the yard floor.
			Platforms = {
				WestGallery = true, WestHoist = true, Crossing = true, EastHoist = true, EastGallery = true,
				Inspection = true, PatternLoft = true, ControlCab = true,
			},
			Links = {
				Basin_WestGallery = true, Basin_EastGallery = true, Basin_Crossing = true,
				WestGallery_WestHoist = true, WestHoist_Crossing = true, Crossing_EastHoist = true, EastHoist_EastGallery = true,
				Crossing_Inspection = true, WestGallery_PatternLoft = true, EastGallery_ControlCab = true,
			},
		},
		-- The crane girder's spans hang free between their nodes (no trestles), as a deep lattice box girder.
		GirderSpans = {
			WestGallery_WestHoist = true, WestHoist_Crossing = true, Crossing_EastHoist = true, EastHoist_EastGallery = true,
		},
		-- A closed brick vault over the hall; the only daylight is a smoky oculus over the Inspection Gallery.
		Skylight = { X = 0, Z = -110, Radius = 44 },
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 100, Feather = 30 },
			-- Molten runnels down both side aisles of the hall, under the piers and lofts.
			{ Kind = "LAVA_CHANNEL", X = -212, ZStart = -270, ZEnd = 86, HalfWidth = 11, NoiseAmp = 3, Gain = 0.36 },
			{ Kind = "LAVA_CHANNEL", X = 212, ZStart = -270, ZEnd = 86, HalfWidth = 11, NoiseAmp = 3, Gain = 0.36 },
			-- Slag and scrap banked in the back corners.
			{ Kind = "SLAG_TIP", X = -240, Z = -272, Top = 30, Length = 50, Yaw = 50, HalfWidth = 18, Spread = 18 },
			{ Kind = "SLAG_TIP", X = 240, Z = -272, Top = 30, Length = 50, Yaw = -50, HalfWidth = 18, Spread = 18 },
		},
		Basin = { X = 0, Y = 0, Z = 150, Width = 470, Depth = 100 },
		WestGallery = { X = -175, Y = 8, Z = -20, Width = 80, Depth = 68 },
		Crossing = { X = 0, Y = 10, Z = -20, Width = 72, Depth = 56 },
		EastGallery = { X = 175, Y = 12, Z = -20, Width = 80, Depth = 68 },
		ExtraPlatforms = {
			WestHoist = { X = -88, Y = 9, Z = -20, Width = 40, Depth = 40 },
			EastHoist = { X = 88, Y = 11, Z = -20, Width = 40, Depth = 40 },
			Inspection = { X = 0, Y = 18, Z = -120, Width = 64, Depth = 48 },
			PatternLoft = { X = -180, Y = 16, Z = -150, Width = 70, Depth = 60 },
			ControlCab = { X = 180, Y = 20, Z = -160, Width = 66, Depth = 56 },
		},
		Apex = { X = 0, Y = 24, Z = -230, Width = 120, Depth = 88 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "EastGallery" },
			{ "Basin", "Crossing" },
			{ "WestGallery", "WestHoist" },
			{ "WestHoist", "Crossing" },
			{ "Crossing", "EastHoist" },
			{ "EastHoist", "EastGallery" },
			{ "Crossing", "Inspection" },
			{ "Inspection", "Apex" },
			{ "WestGallery", "PatternLoft" },
			{ "EastGallery", "ControlCab" },
		},
		Stairs = { Inspection_Apex = true },
		Names = {
			Sanctuary = "Hall Doors",
			Basin = "Assembly Yard",
			WestGallery = "West Gantry Pier",
			WestHoist = "West Hoist",
			Crossing = "Crane Trolley",
			EastHoist = "East Hoist",
			EastGallery = "East Gantry Pier",
			Inspection = "Inspection Gallery",
			PatternLoft = "Pattern Loft",
			ControlCab = "Control Cab",
			Apex = "Assembly Hall",
		},
	},
	-- Floor 23, Furnace Causeway (Infernal Foundry): the furnace line over a lava lake. A causeway in three spans
	-- on stone piers (South -> Mid -> North) runs north to a stair up to the Furnace Mouth, and six bays open off
	-- it like ribs, two per span on alternate sides; an iron catwalk joins the East Quench Bay up to the Blade
	-- Gallery. 12 terraces, 12 links, 11 walk heights in a 625 x 700 hall.
	[23] = {
		Key = "infernal:3",
		Name = "Furnace Causeway",
		Size = { Width = 625, Depth = 700, Height = 205 },
		PathStyle = "SOOTWRIGHT",
		DirectTerrain = true,
		Surface = "SOOTWRIGHT",
		Masonry = "FOUNDRY_IRON",
		Decks = {
			Crossing = true,
			MidCauseway = true,
			NorthCauseway = true,
			CoolingBay = true,
			BladeGallery = true,
		},
		Suspended = {
			Platforms = { Crossing = true, MidCauseway = true, NorthCauseway = true, CoolingBay = true, BladeGallery = true },
			Links = {
				Basin_Crossing = true, Crossing_MidCauseway = true, MidCauseway_NorthCauseway = true,
				Crossing_WestGallery = true, Crossing_SlagBay = true, MidCauseway_EastGallery = true,
				MidCauseway_CoolingBay = true, NorthCauseway_CastingBay = true, NorthCauseway_BladeGallery = true,
				EastGallery_BladeGallery = true,
			},
		},
		-- The causeway's decks and spans stand on soot-brick piers rising out of the lava (not iron trestles).
		StonePiers = {
			Crossing = true, MidCauseway = true, NorthCauseway = true,
			Basin_Crossing = true, Crossing_MidCauseway = true, MidCauseway_NorthCauseway = true,
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 104, Feather = 30 },
			-- The lava lake under the causeway, filling the hall between the Charging Floor and the Furnace Mouth.
			{ Kind = "CENOTE_LAGOON", Z = -95, RX = 250, RZ = 215, NoiseScale = 60, NoiseAmp = 0.08, NoiseSeed = 23, Base = 0.3, Gain = 0.36 },
			-- Crust floes and cooled ridges drifting on the lake.
			{
				Kind = "PRESSURE_RIDGE",
				Ridges = {
					{ AX = -70, AZ = -10, BX = -40, BZ = -60, HalfWidth = 6, Height = 2.4, WarpAmp = 5 },
					{ AX = 50, AZ = -140, BX = 80, BZ = -175, HalfWidth = 6, Height = 2.6, WarpAmp = 6 },
					{ AX = -90, AZ = -150, BX = -60, BZ = -120, HalfWidth = 5, Height = 2.2, WarpAmp = 4 },
					{ AX = 60, AZ = 80, BX = 90, BZ = 30, HalfWidth = 5, Height = 2.0, WarpAmp = 4 },
				},
			},
		},
		Basin = { X = 0, Y = 0, Z = 180, Width = 540, Depth = 110 },
		Crossing = { X = 0, Y = 6, Z = 40, Width = 64, Depth = 100 },
		WestGallery = { X = -140, Y = 8, Z = 40, Width = 84, Depth = 76 },
		EastGallery = { X = 140, Y = 16, Z = -90, Width = 84, Depth = 76 },
		ExtraPlatforms = {
			SlagBay = { X = 140, Y = 4, Z = 40, Width = 80, Depth = 72 },
			MidCauseway = { X = 0, Y = 12, Z = -90, Width = 60, Depth = 80 },
			CoolingBay = { X = -140, Y = 14, Z = -90, Width = 80, Depth = 72 },
			NorthCauseway = { X = 0, Y = 20, Z = -195, Width = 60, Depth = 70 },
			CastingBay = { X = -140, Y = 24, Z = -195, Width = 76, Depth = 68 },
			BladeGallery = { X = 140, Y = 22, Z = -195, Width = 76, Depth = 68 },
		},
		Apex = { X = 0, Y = 28, Z = -285, Width = 124, Depth = 84 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Crossing" },
			{ "Crossing", "WestGallery" },
			{ "Crossing", "SlagBay" },
			{ "Crossing", "MidCauseway" },
			{ "MidCauseway", "EastGallery" },
			{ "MidCauseway", "CoolingBay" },
			{ "MidCauseway", "NorthCauseway" },
			{ "NorthCauseway", "CastingBay" },
			{ "NorthCauseway", "BladeGallery" },
			{ "NorthCauseway", "Apex" },
			{ "EastGallery", "BladeGallery" },
		},
		Stairs = { NorthCauseway_Apex = true },
		Patrols = {
			SPINE = { "Crossing", "MidCauseway", "NorthCauseway", "Apex" },
			CATWALK = { "EastGallery", "BladeGallery", "NorthCauseway" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Charging Gate",
			Basin = "Charging Floor",
			Crossing = "South Causeway",
			WestGallery = "West Smelting Bay",
			SlagBay = "Slag Bay",
			MidCauseway = "Mid Causeway",
			EastGallery = "East Quench Bay",
			CoolingBay = "Cooling Bay",
			NorthCauseway = "North Causeway",
			CastingBay = "Casting Bay",
			BladeGallery = "Blade Gallery",
			Apex = "Furnace Mouth",
		},
	},
	-- Floor 24, Ironflame Bulwark (Infernal Foundry): the Foundry's defences. Two north-south lava channels cut the
	-- floor into three fortified strips, with The Pour (a molten cauldron pit) blocking the south centre. The yard
	-- leads only to the West Gun Deck; from there, squads either climb the west strip (Gun Deck -> Powder Store ->
	-- West Bulwark Tower -> Citadel, with the dead-end Signal Bastion beyond) or weave east across both Sluice
	-- Towers and the Ironflame Gate onto the East Foundry Deck, Hammer Hall and East Bulwark Tower. 14 terraces,
	-- 14 links, 12 walk heights in a 715 x 810 cavern fortress.
	[24] = {
		Key = "infernal:4",
		Name = "Ironflame Bulwark",
		Size = { Width = 715, Depth = 810, Height = 230, Bottom = -4 },
		PathStyle = "SOOTWRIGHT",
		DirectTerrain = true,
		Surface = "SOOTWRIGHT",
		Masonry = "FOUNDRY_IRON",
		Decks = {
			WestGallery = true,
			PowderStore = true,
			WestBastion = true,
			SignalBastion = true,
			WestSluice = true,
			Crossing = true,
			IronflameForge = true,
			EastSluice = true,
			EastGallery = true,
			HammerHall = true,
			EastBastion = true,
		},
		Suspended = {
			Platforms = { WestSluice = true, EastSluice = true },
			Links = {
				Basin_WestGallery = true,
				PowderStore_WestBastion = true,
				WestBastion_SignalBastion = true,
				WestBastion_Apex = true,
				WestGallery_WestSluice = true,
				WestSluice_Crossing = true,
				Crossing_IronflameForge = true,
				Crossing_EastSluice = true,
				EastSluice_EastGallery = true,
				HammerHall_EastBastion = true,
				EastBastion_Apex = true,
			},
		},
		-- The two sluice decks stand directly in the lava channels on battered soot-brick piers.
		StonePiers = { WestSluice = true, EastSluice = true },
		Liquid = { LevelOffset = 3.2, FloorDip = 1.6 },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 110, Feather = 32 },
			-- Two north-south lava channels cutting the fortress into three fortified strips.
			{ Kind = "LAVA_CHANNEL", X = -115, ZStart = -360, ZEnd = 165, HalfWidth = 38, NoiseAmp = 6, Gain = 0.4 },
			{ Kind = "LAVA_CHANNEL", X = 115, ZStart = -360, ZEnd = 165, HalfWidth = 38, NoiseAmp = 6, Gain = 0.4 },
			-- The Pour: boiling molten pit blocking the south centre in front of the Ironflame Gate.
			{ Kind = "POUR_PIT", X = 0, Z = 86, RX = 84, RZ = 66, RimWidth = 14, RimHeight = 3.6, NoiseAmp = 0.14, NoiseSeed = 24, Gain = 0.44 },
			-- Volcanic lava falls cascading down the outer cavern walls.
			{ Kind = "LAVA_FALL", X = -340, Z = -120, Width = 32, Depth = 54, Height = 128, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = -340, Z = -280, Width = 32, Depth = 54, Height = 140, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = 340, Z = -60, Width = 32, Depth = 54, Height = 128, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = 340, Z = -260, Width = 32, Depth = 54, Height = 140, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = -135, Z = -388, Width = 54, Depth = 34, Height = 148, Axis = "X", RibbonWidth = 12 },
			{ Kind = "LAVA_FALL", X = 135, Z = -388, Width = 54, Depth = 34, Height = 148, Axis = "X", RibbonWidth = 12 },
		},
		Basin = { X = 0, Y = 0, Z = 230, Width = 620, Depth = 120 },
		WestGallery = { X = -230, Y = 8, Z = 60, Width = 92, Depth = 80 },
		WestBastion = { X = -230, Y = 24, Z = -190, Width = 90, Depth = 80 },
		Crossing = { X = 0, Y = 14, Z = -40, Width = 84, Depth = 64 },
		EastGallery = { X = 230, Y = 10, Z = -80, Width = 92, Depth = 80 },
		EastBastion = { X = 230, Y = 30, Z = -300, Width = 90, Depth = 80 },
		ExtraPlatforms = {
			PowderStore = { X = -230, Y = 16, Z = -65, Width = 70, Depth = 56 },
			SignalBastion = { X = -230, Y = 32, Z = -310, Width = 80, Depth = 56 },
			WestSluice = { X = -115, Y = 12, Z = -10, Width = 48, Depth = 44 },
			IronflameForge = { X = 0, Y = 20, Z = -160, Width = 76, Depth = 60 },
			EastSluice = { X = 115, Y = 12, Z = -70, Width = 48, Depth = 44 },
			HammerHall = { X = 230, Y = 18, Z = -190, Width = 80, Depth = 64 },
		},
		Apex = { X = 0, Y = 36, Z = -320, Width = 124, Depth = 96 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "WestGallery", "PowderStore" },
			{ "PowderStore", "WestBastion" },
			{ "WestBastion", "Apex" },
			{ "WestBastion", "SignalBastion" },
			{ "WestGallery", "WestSluice" },
			{ "WestSluice", "Crossing" },
			{ "Crossing", "IronflameForge" },
			{ "Crossing", "EastSluice" },
			{ "EastSluice", "EastGallery" },
			{ "EastGallery", "HammerHall" },
			{ "HammerHall", "EastBastion" },
			{ "EastBastion", "Apex" },
		},
		Stairs = {
			WestGallery_PowderStore = true,
			EastGallery_HammerHall = true,
		},
		Patrols = {
			WEST_STRIP = { "WestGallery", "PowderStore", "WestBastion" },
			WEAVE = { "WestGallery", "WestSluice", "Crossing", "EastSluice", "EastGallery" },
		},
		Names = {
			Sanctuary = "Siege Gate",
			Basin = "Mustering Yard",
			WestGallery = "West Gun Deck",
			PowderStore = "Powder Store",
			WestBastion = "West Bulwark Tower",
			SignalBastion = "Signal Bastion",
			WestSluice = "West Sluice Tower",
			Crossing = "Ironflame Gate",
			IronflameForge = "Ironflame Forge",
			EastSluice = "East Sluice Tower",
			EastGallery = "East Foundry Deck",
			HammerHall = "Hammer Hall",
			EastBastion = "East Bulwark Tower",
			Apex = "Ironflame Citadel",
		},
	},
	-- Floor 25, Titan's Crucible (Infernal Foundry Boss Arena): the heart of the Foundry. An hourglass with side
	-- chambers at every level over a deep lava lake (Bottom = -6). Both Mould Stations climb from the Casting Floor
	-- by twin iron stairs (each with a dead-end side chamber: Pattern Shop and Ingot Store) and converge on the Pour
	-- Gate pinch — every Basin->Apex route passes through it. Beyond the Pour Gate stand the dead-end Pour Spout
	-- overlook and the twin Duct bridgeheads climbing to the Great Bellows Towers, each with a high Chain Gallery
	-- beside the 170 x 124 dark-iron Titan's Crucible Dais. 15 terraces, 16 links, 13 walk heights in 800 x 920 x 270.
	[25] = {
		Key = "infernal:5",
		Name = "Titan's Crucible",
		Size = { Width = 740, Depth = 795, Height = 250, Bottom = -6 },
		PathStyle = "SOOTWRIGHT",
		DirectTerrain = true,
		Surface = "SOOTWRIGHT",
		Masonry = "FOUNDRY_IRON",
		Decks = {
			IngotStore = true,
			Crossing = true,
			PourSpout = true,
			WestDuct = true,
			EastDuct = true,
			WestBastion = true,
			EastBastion = true,
			WestChainGallery = true,
			EastChainGallery = true,
			Apex = true,
		},
		Suspended = {
			Platforms = {
				Crossing = true,
				PourSpout = true,
				WestDuct = true,
				EastDuct = true,
				WestChainGallery = true,
				EastChainGallery = true,
			},
			Links = {
				WestGallery_PatternShop = true,
				EastGallery_IngotStore = true,
				WestGallery_Crossing = true,
				EastGallery_Crossing = true,
				Crossing_PourSpout = true,
				Crossing_WestDuct = true,
				Crossing_EastDuct = true,
				WestDuct_WestBastion = true,
				EastDuct_EastBastion = true,
				WestBastion_WestChainGallery = true,
				EastBastion_EastChainGallery = true,
				WestBastion_Apex = true,
				EastBastion_Apex = true,
			},
		},
		-- The Pour Gate stands over the boiling lava lake on battered soot-brick bridge piers.
		StonePiers = { Crossing = true },
		Liquid = { LevelOffset = 3.2, FloorDip = 1.8 },
		TerrainFeatures = {
			{ Kind = "APEX_ALCOVE", Width = 132, Feather = 32 },
			-- Colossal molten lake filling the Foundry core beneath the Pour Gate, ducts and dais.
			{ Kind = "CENOTE_LAGOON", Z = -100, RX = 290, RZ = 248, NoiseScale = 60, NoiseAmp = 0.08, NoiseSeed = 25, Base = 0.3, Gain = 0.42 },
			{
				Kind = "PRESSURE_RIDGE",
				Ridges = {
					{ AX = -95, AZ = 30, BX = -45, BZ = -10, HalfWidth = 6.5, Height = 2.5, WarpAmp = 5 },
					{ AX = 55, AZ = 15, BX = 105, BZ = -30, HalfWidth = 6.5, Height = 2.4, WarpAmp = 5 },
					{ AX = -80, AZ = -95, BX = -35, BZ = -130, HalfWidth = 6, Height = 2.3, WarpAmp = 5 },
					{ AX = 40, AZ = -110, BX = 85, BZ = -155, HalfWidth = 6, Height = 2.3, WarpAmp = 5 },
				},
			},
			-- Six towering molten lava falls pouring down the cavern walls.
			{ Kind = "LAVA_FALL", X = -356, Z = -100, Width = 32, Depth = 54, Height = 155, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = -356, Z = -265, Width = 32, Depth = 54, Height = 168, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = 356, Z = -100, Width = 32, Depth = 54, Height = 155, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = 356, Z = -265, Width = 32, Depth = 54, Height = 168, Axis = "Z", RibbonWidth = 10 },
			{ Kind = "LAVA_FALL", X = -156, Z = -384, Width = 54, Depth = 30, Height = 180, Axis = "X", RibbonWidth = 12 },
			{ Kind = "LAVA_FALL", X = 156, Z = -384, Width = 54, Depth = 30, Height = 180, Axis = "X", RibbonWidth = 12 },
		},
		Basin = { X = 0, Y = 0, Z = 228, Width = 640, Depth = 112 },
		WestGallery = { X = -210, Y = 8, Z = 68, Width = 92, Depth = 80 },
		EastGallery = { X = 210, Y = 8, Z = 68, Width = 92, Depth = 80 },
		Crossing = { X = 0, Y = 20, Z = -46, Width = 88, Depth = 68 },
		WestBastion = { X = -222, Y = 30, Z = -215, Width = 92, Depth = 82 },
		EastBastion = { X = 222, Y = 32, Z = -215, Width = 92, Depth = 82 },
		ExtraPlatforms = {
			PatternShop = { X = -255, Y = 12, Z = -48, Width = 68, Depth = 60 },
			IngotStore = { X = 255, Y = 14, Z = -48, Width = 68, Depth = 60 },
			PourSpout = { X = 0, Y = 28, Z = -146, Width = 60, Depth = 44 },
			WestDuct = { X = -114, Y = 24, Z = -146, Width = 56, Depth = 52 },
			EastDuct = { X = 114, Y = 26, Z = -146, Width = 56, Depth = 52 },
			WestChainGallery = { X = -200, Y = 36, Z = -325, Width = 74, Depth = 56 },
			EastChainGallery = { X = 200, Y = 40, Z = -325, Width = 74, Depth = 56 },
		},
		Apex = { X = 0, Y = 44, Z = -302, Width = 170, Depth = 124 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "EastGallery" },
			{ "WestGallery", "PatternShop" },
			{ "EastGallery", "IngotStore" },
			{ "WestGallery", "Crossing" },
			{ "EastGallery", "Crossing" },
			{ "Crossing", "PourSpout" },
			{ "Crossing", "WestDuct" },
			{ "Crossing", "EastDuct" },
			{ "WestDuct", "WestBastion" },
			{ "EastDuct", "EastBastion" },
			{ "WestBastion", "WestChainGallery" },
			{ "EastBastion", "EastChainGallery" },
			{ "WestBastion", "Apex" },
			{ "EastBastion", "Apex" },
		},
		Stairs = {
			Basin_WestGallery = true,
			Basin_EastGallery = true,
		},
		Patrols = {
			LOWER_PINCH = { "WestGallery", "Crossing", "EastGallery" },
			UPPER_PINCH = { "WestBastion", "WestDuct", "Crossing", "EastDuct", "EastBastion" },
			CRUCIBLE_RING = { "WestBastion", "Apex", "EastBastion" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Foundry Core Gate",
			Basin = "Casting Floor",
			WestGallery = "West Mould Station",
			EastGallery = "East Mould Station",
			PatternShop = "Pattern Shop",
			IngotStore = "Ingot Store",
			Crossing = "Pour Gate",
			PourSpout = "Pour Spout",
			WestDuct = "West Duct",
			EastDuct = "East Duct",
			WestBastion = "West Bellows",
			EastBastion = "East Bellows",
			WestChainGallery = "West Chain Gallery",
			EastChainGallery = "East Chain Gallery",
			Apex = "Titan's Crucible",
		},
	},
	-- Floor 26, Stormgrass Rise (Thunder Highlands): the Kairnfolk's lower grazing slopes. The moor climbs
	-- into three staggered contours (the Windmill Knoll, the Cairn Fold, the Standing Stones), and north of the
	-- Fold a sheer turf-and-slate headwall rises, twin falls spilling down it, with no way up its face: every
	-- ascent tacks across the wind, west through the West Wind-Crag and up the slate stair, or east over the
	-- dry-stone causeways through the East Wind-Crag. Two cairn spurs (the Shepherd's Watch croft, the
	-- Fulgurite Outcrop) overlook the moor, and a split granite tor crowned by a copper forked-bolt totem
	-- stands behind the Stormgrass Crown. 10 terraces, 11 links, 9 walk heights.
	[26] = {
		Key = "thunder:1",
		Name = "Stormgrass Rise",
		Size = { Width = 510, Depth = 550, Height = 180 },
		PathStyle = "KAIRN",
		DirectTerrain = true,
		Surface = "KAIRN",
		Masonry = "KAIRN_STONE",
		-- Off-grid dry-stone platforms (Y 6, 10, 18); every link touching one is a built causeway.
		Decks = {
			EastGallery = true,
			ShepherdWatch = true,
			EastCrag = true,
		},
		Suspended = {
			Links = {
				Basin_EastGallery = true,
				WestGallery_ShepherdWatch = true,
				EastGallery_FulguriteSpur = true,
				EastGallery_EastCrag = true,
				EastCrag_Apex = true,
			},
		},
		-- Moorland tarns: water sits just under the moor.
		Liquid = { LevelOffset = 3.2, FloorDip = 2.2 },
		TerrainFeatures = {
			-- The headwall: a sheer turf-capped slate wall north of the Cairn Fold, between the two wind-crags.
			{ Kind = "HEADWALL", X = 4, Z = -96, HalfX = 26, HalfZ = 40, Top = 74 },
			-- The fulgurite strike crater: a scorched bowl in the slope north of the Fulgurite Outcrop.
			{ Kind = "LIGHTNING_SCAR", X = 150, Z = -204, Radius = 28, Rim = 7 },
			-- The plunge tarn under the twin falls, and a moorland pool off the west trail.
			{
				Kind = "POOL_ELLIPSES_SQ",
				Strength = 0.28,
				Gain = 0.34,
				Ellipses = {
					{ X = 6, Z = -46, RX = 26, RZ = 10 },
					{ X = -214, Z = 72, RX = 18, RZ = 12 },
				},
			},
		},
		Basin = { X = 0, Y = 0, Z = 132, Width = 420, Depth = 92 },
		Crossing = { X = -6, Y = 8, Z = 16, Width = 78, Depth = 62 },
		-- The knoll is broad enough for the windmill to stand on it, outside the Elite's camp.
		WestGallery = { X = -150, Y = 4, Z = 10, Width = 112, Depth = 88 },
		EastGallery = { X = 152, Y = 6, Z = 2, Width = 86, Depth = 76 },
		ExtraPlatforms = {
			-- Broad enough for the croft to stand on its north edge, clear of the landing.
			ShepherdWatch = { X = -178, Y = 10, Z = -124, Width = 86, Depth = 70 },
			FulguriteSpur = { X = 180, Y = 12, Z = -124, Width = 64, Depth = 52 },
			WestCrag = { X = -76, Y = 16, Z = -96, Width = 72, Depth = 60 },
			EastCrag = { X = 80, Y = 18, Z = -102, Width = 72, Depth = 60 },
		},
		Apex = { X = 0, Y = 24, Z = -206, Width = 120, Depth = 84 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "Crossing" },
			{ "Basin", "EastGallery" },
			{ "WestGallery", "ShepherdWatch" },
			{ "EastGallery", "FulguriteSpur" },
			{ "WestGallery", "WestCrag" },
			{ "Crossing", "WestCrag" },
			{ "EastGallery", "EastCrag" },
			{ "WestCrag", "Apex" },
			{ "EastCrag", "Apex" },
		},
		Stairs = { WestCrag_Apex = true },
		Names = {
			Sanctuary = "Bell-Gate Fold",
			Basin = "Shepherd's Moor",
			WestGallery = "Windmill Knoll",
			Crossing = "Cairn Fold",
			EastGallery = "Standing Stones",
			ShepherdWatch = "Shepherd's Watch",
			FulguriteSpur = "Fulgurite Outcrop",
			WestCrag = "West Wind-Crag",
			EastCrag = "East Wind-Crag",
			Apex = "Stormgrass Crown",
		},
	},
	-- Floor 27, Thunderhead Outpost (Thunder Highlands): the Kairnfolk's hilltop ringfort and signal station, a
	-- concentric dry-stone broch where the shepherds took refuge and relayed storm warnings down the mountain by
	-- wind-harp and beacon. The Stockade Apron has no way straight in: it enters only through the twin palisade
	-- gate-bastions into the flanking yards (the Ram Yard, the Forge Yard). From the yards, routes cut in to the
	-- Signal Broch and its hearth, push out to the two Wind-Harp towers on the ridge, or sweep round the inner
	-- rampart arcs; three approaches (both inner ramparts and the Broch Ascent stair) converge on Thunderhead
	-- Lodge under the stepped broch keep. 12 terraces, 14 links, 11 walk heights.
	[27] = {
		Key = "thunder:2",
		Name = "Thunderhead Outpost",
		Size = { Width = 600, Depth = 605, Height = 205 },
		PathStyle = "KAIRN",
		DirectTerrain = true,
		Surface = "KAIRN",
		Masonry = "KAIRN_STONE",
		-- Off-grid dry-stone platforms (Y 6, 14, 18, 22); every link touching one is a built causeway.
		Decks = {
			WestOuter = true,
			EastGallery = true,
			WestHarp = true,
			EastInner = true,
		},
		Suspended = {
			Links = {
				Basin_WestOuter = true,
				WestOuter_WestGallery = true,
				EastOuter_EastGallery = true,
				EastGallery_Crossing = true,
				WestGallery_WestHarp = true,
				EastGallery_EastHarp = true,
				EastGallery_EastInner = true,
				EastInner_Apex = true,
			},
		},
		Liquid = { LevelOffset = 3.2, FloorDip = 2.2 },
		-- The boss portals stand wide on the Lodge, either side of the broch keep that rises behind it.
		Portals = { Spread = 44 },
		Basin = { X = 0, Y = 0, Z = 166, Width = 490, Depth = 94 },
		Crossing = { X = 0, Y = 16, Z = -30, Width = 84, Depth = 72 },
		WestGallery = { X = -142, Y = 12, Z = -24, Width = 86, Depth = 78 },
		EastGallery = { X = 142, Y = 14, Z = -24, Width = 86, Depth = 78 },
		ExtraPlatforms = {
			WestOuter = { X = -96, Y = 6, Z = 68, Width = 70, Depth = 52 },
			EastOuter = { X = 96, Y = 8, Z = 68, Width = 70, Depth = 52 },
			WestHarp = { X = -224, Y = 18, Z = -124, Width = 58, Depth = 52 },
			EastHarp = { X = 224, Y = 24, Z = -124, Width = 58, Depth = 52 },
			WestInner = { X = -104, Y = 20, Z = -132, Width = 68, Depth = 54 },
			EastInner = { X = 104, Y = 22, Z = -132, Width = 68, Depth = 54 },
		},
		Apex = { X = 0, Y = 32, Z = -232, Width = 126, Depth = 88 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestOuter" },
			{ "Basin", "EastOuter" },
			{ "WestOuter", "WestGallery" },
			{ "EastOuter", "EastGallery" },
			{ "WestGallery", "Crossing" },
			{ "EastGallery", "Crossing" },
			{ "WestGallery", "WestHarp" },
			{ "EastGallery", "EastHarp" },
			{ "WestGallery", "WestInner" },
			{ "EastGallery", "EastInner" },
			{ "WestInner", "Apex" },
			{ "Crossing", "Apex" },
			{ "EastInner", "Apex" },
		},
		Stairs = { Crossing_Apex = true },
		Names = {
			Sanctuary = "Stockade Gate",
			Basin = "Stockade Apron",
			WestOuter = "West Palisade",
			EastOuter = "East Palisade",
			WestGallery = "West Ram Yard",
			Crossing = "Signal Broch",
			EastGallery = "East Forge Yard",
			WestHarp = "West Wind-Harp",
			EastHarp = "East Wind-Harp",
			WestInner = "West Inner Rampart",
			EastInner = "East Inner Rampart",
			Apex = "Thunderhead Lodge",
		},
	},
	-- Floor 28, Skybridge Cliffs (Thunder Highlands): the mountain breaks into freestanding slate sea-stacks
	-- over a sea of storm cloud (Bottom = -6), spanned only by the Kairnfolk's rope-and-copper suspension
	-- skybridges. From the Cloudbreak Ledge three chains climb the archipelago at staggered heights: a sweeping
	-- western chain (West Sea-Stack, West Pinion Crag, West Cable Pylon), a central chord (the Central Sky-Spire,
	-- the Thunderstep Crag, then cliff-cut steps to the summit) and a steeper eastern chain (East Sea-Stack, East
	-- Pinion Crag, East Cable Pylon), cross-linked mid-gorge, with two dead-end roosts (the Gale Roost, the
	-- Fulgurite Needle) jutting over the clouds. Every span past the ledge but the summit steps hangs over the
	-- abyss. 13 terraces, 16 links, 12 walk heights.
	[28] = {
		Key = "thunder:3",
		Name = "Skybridge Cliffs",
		Size = { Width = 655, Depth = 700, Height = 235, Bottom = -6 },
		PathStyle = "KAIRN",
		DirectTerrain = true,
		Surface = "KAIRN",
		Masonry = "SKYBRIDGE",
		-- Off-grid dry-stone caps (Y 14, 30, 34) on top of their rock needles.
		Decks = {
			GaleRoost = true,
			SkyAnchorE = true,
			FulminiteNeedle = true,
		},
		-- Every chasm span is a hung skybridge; only the Sanctuary causeway and the summit steps are rock.
		Suspended = {
			Links = {
				Basin_WestGallery = true,
				Basin_Crossing = true,
				Basin_EastGallery = true,
				WestGallery_GaleRoost = true,
				WestGallery_NeedleWest = true,
				WestGallery_Crossing = true,
				EastGallery_Crossing = true,
				EastGallery_NeedleEast = true,
				NeedleWest_SkyAnchorW = true,
				Crossing_CloudSpire = true,
				NeedleEast_FulminiteNeedle = true,
				NeedleEast_SkyAnchorE = true,
				SkyAnchorW_Apex = true,
				SkyAnchorE_Apex = true,
			},
		},
		-- The abyss floor is dry slate under the cloud banks (no water in the chasm).
		Liquid = { Dry = true },
		TerrainFeatures = {
			-- The mountain wall falls back behind the Crown, leaving a shelf for the twin crown towers.
			{ Kind = "APEX_ALCOVE", Width = 118, Feather = 30 },
			-- Every terrace a sheer needle out of the abyss (its sides fall 3.4 times as steeply), the abyss
			-- floor bare slate under the cloud sea.
			{ Kind = "SEA_STACK_APRON", Steep = 3.4 },
		},
		Basin = { X = 0, Y = 0, Z = 200, Width = 545, Depth = 104 },
		WestGallery = { X = -178, Y = 8, Z = 40, Width = 88, Depth = 78 },
		EastGallery = { X = 186, Y = 12, Z = 32, Width = 88, Depth = 78 },
		Crossing = { X = -6, Y = 20, Z = -28, Width = 86, Depth = 72 },
		ExtraPlatforms = {
			GaleRoost = { X = -256, Y = 14, Z = -60, Width = 60, Depth = 54 },
			NeedleWest = { X = -148, Y = 16, Z = -76, Width = 70, Depth = 60 },
			NeedleEast = { X = 164, Y = 24, Z = -84, Width = 70, Depth = 60 },
			SkyAnchorW = { X = -176, Y = 28, Z = -194, Width = 72, Depth = 62 },
			SkyAnchorE = { X = 172, Y = 30, Z = -198, Width = 72, Depth = 62 },
			FulminiteNeedle = { X = 258, Y = 34, Z = -102, Width = 56, Depth = 50 },
			CloudSpire = { X = 22, Y = 36, Z = -164, Width = 68, Depth = 56 },
		},
		Apex = { X = -12, Y = 40, Z = -270, Width = 132, Depth = 90 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "Crossing" },
			{ "Basin", "EastGallery" },
			{ "WestGallery", "GaleRoost" },
			{ "WestGallery", "NeedleWest" },
			{ "WestGallery", "Crossing" },
			{ "EastGallery", "Crossing" },
			{ "EastGallery", "NeedleEast" },
			{ "NeedleWest", "SkyAnchorW" },
			{ "Crossing", "CloudSpire" },
			{ "NeedleEast", "FulminiteNeedle" },
			{ "NeedleEast", "SkyAnchorE" },
			{ "SkyAnchorW", "Apex" },
			{ "CloudSpire", "Apex" },
			{ "SkyAnchorE", "Apex" },
		},
		-- The Thunderstep: slate steps cut into the rock saddle up to the summit.
		Stairs = { CloudSpire_Apex = true },
		Patrols = {
			WEST_SKYLINE = { "WestGallery", "NeedleWest", "SkyAnchorW" },
			EAST_SKYLINE = { "EastGallery", "NeedleEast", "SkyAnchorE" },
			CLOUD_SPAN = { "WestGallery", "Crossing", "CloudSpire" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Cloudbreak Stair",
			Basin = "Cloudbreak Ledge",
			WestGallery = "West Sea-Stack",
			EastGallery = "East Sea-Stack",
			GaleRoost = "Gale Roost",
			NeedleWest = "West Pinion Crag",
			Crossing = "Central Sky-Spire",
			NeedleEast = "East Pinion Crag",
			SkyAnchorW = "West Cable Pylon",
			SkyAnchorE = "East Cable Pylon",
			FulminiteNeedle = "Fulgurite Needle",
			CloudSpire = "Thunderstep Crag",
			Apex = "Skybridge Crown",
		},
	},
	-- Floor 29, Tempest Redoubt (Thunder Highlands): the Kairnfolk's two-tier mountain acropolis, split by an
	-- east-west cliff fault. South of it the lower ward stands on rock over a misty chasm (Bottom = -6): the walled
	-- causeway into the Lower Barbican, the two Ram Yards and the Horn Posts on the outer cliff edges. North of
	-- it the upper citadel stands on a plateau: both Stormkeeps, the Storm-Bell Gate, the Capacitor Spire and the
	-- Tempest Redoubt. Three ways climb the fault: the west and east switchbacks (causeways out to buttressed
	-- ledges on the cliff's lip, then on up to the Stormkeeps) and, in the middle, the arched Thunder-Viaduct
	-- from the Barbican to its pier and up the grand steps under the Storm-Bell Gate. 15 terraces, 17 links,
	-- 13 walk heights.
	[29] = {
		Key = "thunder:4",
		Name = "Tempest Redoubt",
		Size = { Width = 735, Depth = 790, Height = 260, Bottom = -6 },
		PathStyle = "KAIRN",
		DirectTerrain = true,
		Surface = "KAIRN",
		Masonry = "KAIRN_STONE",
		-- Off-grid dry-stone platforms (Y 14, 22, 30, 38) and the viaduct's masonry pier (Y 20).
		Decks = {
			EastGallery = true,
			ViaductPier = true,
			WestSwitchback = true,
			WestBastion = true,
			WestCoilSpire = true,
		},
		-- Every causeway over the chasm, every link touching a deck, and the walled causeway into the Barbican.
		Suspended = {
			Links = {
				Basin_Crossing = true,
				Basin_EastGallery = true,
				Crossing_ViaductPier = true,
				ViaductPier_UpperGate = true,
				EastGallery_EastHornPost = true,
				WestGallery_WestSwitchback = true,
				EastGallery_EastSwitchback = true,
				WestSwitchback_WestBastion = true,
				WestBastion_UpperGate = true,
				WestBastion_WestCoilSpire = true,
				WestBastion_Apex = true,
				EastBastion_Apex = true,
			},
		},
		-- The Thunder-Viaduct: open masonry arches on tall piers out of the chasm, copper conduits along both
		-- parapets (TowerRoomBuilder, KAIRN_STONE).
		Viaducts = { Crossing_ViaductPier = true, ViaductPier_UpperGate = true },
		-- The chasm floor is dry slate under the mist.
		Liquid = { Dry = true },
		-- The boss portals stand wide on the Redoubt, either side of the citadel keep behind it.
		Portals = { Spread = 46 },
		TerrainFeatures = {
			-- The mountain wall falls back behind the Redoubt, leaving a shelf for the citadel keep.
			{ Kind = "APEX_ALCOVE", Width = 120, Feather = 30 },
			-- The fault: north of Z -88 (wavering with the strata) the ground is a plateau 28 studs over the chasm
			-- floor, its south face a sheer stepped scarp.
			{ Kind = "CLIFF_FAULT", Z = -88, Top = 28, Amp = 7 },
			-- Every terrace stands on sheer rock (sides 2.2 times as steep), the chasm floor bare slate.
			{ Kind = "SEA_STACK_APRON", Steep = 2.2 },
		},
		Basin = { X = 0, Y = 0, Z = 230, Width = 630, Depth = 112 },
		Crossing = { X = 0, Y = 8, Z = 102, Width = 88, Depth = 68 },
		WestGallery = { X = -208, Y = 12, Z = 84, Width = 92, Depth = 80 },
		EastGallery = { X = 208, Y = 14, Z = 84, Width = 92, Depth = 80 },
		WestBastion = { X = -212, Y = 30, Z = -176, Width = 92, Depth = 82 },
		EastBastion = { X = 212, Y = 32, Z = -176, Width = 92, Depth = 82 },
		ExtraPlatforms = {
			WestHornPost = { X = -302, Y = 16, Z = -28, Width = 62, Depth = 56 },
			EastHornPost = { X = 302, Y = 16, Z = -28, Width = 62, Depth = 56 },
			ViaductPier = { X = 0, Y = 20, Z = -24, Width = 68, Depth = 58 },
			WestSwitchback = { X = -194, Y = 22, Z = -48, Width = 72, Depth = 60 },
			EastSwitchback = { X = 194, Y = 24, Z = -48, Width = 72, Depth = 60 },
			UpperGate = { X = 0, Y = 36, Z = -160, Width = 84, Depth = 64 },
			WestCoilSpire = { X = -282, Y = 38, Z = -304, Width = 68, Depth = 56 },
		},
		Apex = { X = 0, Y = 48, Z = -306, Width = 136, Depth = 98 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Crossing" },
			{ "Basin", "WestGallery" },
			{ "Basin", "EastGallery" },
			{ "Crossing", "ViaductPier" },
			{ "WestGallery", "WestHornPost" },
			{ "EastGallery", "EastHornPost" },
			{ "WestGallery", "WestSwitchback" },
			{ "EastGallery", "EastSwitchback" },
			{ "WestSwitchback", "WestBastion" },
			{ "EastSwitchback", "EastBastion" },
			{ "ViaductPier", "UpperGate" },
			{ "WestBastion", "UpperGate" },
			{ "WestBastion", "WestCoilSpire" },
			{ "WestBastion", "Apex" },
			{ "EastBastion", "Apex" },
			{ "UpperGate", "Apex" },
		},
		-- The viaduct's grand steps up under the Storm-Bell Gate, and the Redoubt's keep steps.
		Stairs = { ViaductPier_UpperGate = true, UpperGate_Apex = true },
		Patrols = {
			LOWER_WALL = { "WestGallery", "Basin", "EastGallery" },
			FAULT_VIADUCT = { "Crossing", "ViaductPier", "UpperGate" },
			UPPER_REDOUBT = { "WestBastion", "Apex", "EastBastion" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Storm Road",
			Basin = "Outer Causeway",
			Crossing = "Lower Barbican",
			WestGallery = "West Ram Yard",
			EastGallery = "East Ram Yard",
			WestHornPost = "West Horn Post",
			EastHornPost = "East Horn Post",
			ViaductPier = "Thunder-Viaduct Pier",
			WestSwitchback = "West Fault Switchback",
			EastSwitchback = "East Fault Switchback",
			WestBastion = "West Stormkeep",
			EastBastion = "East Stormkeep",
			UpperGate = "Storm-Bell Gate",
			WestCoilSpire = "Capacitor Spire",
			Apex = "Tempest Redoubt",
		},
	},
	-- Floor 31, Blighted Verge (Corrupted Grove Introduction; docs/prompts/corrupted-grove-floor-layouts-prompt.md):
	-- the edge of the grove, where the Hollin grove-wardens still held the line. A blight-brook rises at the
	-- Heartrot Spring in the north-east corner and meanders west-south-west to a sinkhole in the west wall,
	-- splitting the floor into an autumn-gold south bank and a rotten north bank. Four fords cross it (stepping
	-- stones and a fieldstone weir as causeways, a mill-race plank and a fallen log hung over the water), and
	-- every route to the Apex fords at least once: the quick way once (the Last Green, the Lantern Copse, the
	-- Weir Ford), the zigzag three times (the Pale Glade, the Weir Mill, the Lantern Copse, Rothollow), and a
	-- back path along the rotten bank (the Warding Shrine, the Blight Line) reaches the Apex from the west.
	[31] = {
		Key = "corrupted:1",
		Name = "Blighted Verge",
		Size = { Width = 540, Depth = 580, Height = 195 },
		PathStyle = "HOLLIN",
		Basin = { X = 0, Y = 0, Z = 150, Width = 508, Depth = 96 },
		WestGallery = { X = -160, Y = 4, Z = 40, Width = 86, Depth = 72 },
		Crossing = { X = -20, Y = 8, Z = -40, Width = 76, Depth = 60 },
		EastGallery = { X = 175, Y = 12, Z = -10, Width = 86, Depth = 72 },
		ExtraPlatforms = {
			LastGreen = { X = 60, Y = 6, Z = 45, Width = 64, Depth = 52 },
			Woodcutters = { X = -205, Y = 10, Z = -40, Width = 64, Depth = 52 },
			WardingShrine = { X = -170, Y = 16, Z = -120, Width = 68, Depth = 56 },
			Rothollow = { X = 175, Y = 20, Z = -112, Width = 70, Depth = 56 },
			BlightLine = { X = -40, Y = 24, Z = -150, Width = 68, Depth = 56 },
		},
		Apex = { X = 130, Y = 28, Z = -205, Width = 116, Depth = 84 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "LastGreen" },
			{ "WestGallery", "Woodcutters" },
			{ "WestGallery", "Crossing" }, -- the Stepping-Stone Ford
			{ "LastGreen", "Crossing" }, -- the Mill-Race Ford
			{ "LastGreen", "EastGallery" },
			{ "Crossing", "EastGallery" }, -- the Fallen-Log Ford
			{ "Crossing", "WardingShrine" },
			{ "EastGallery", "Rothollow" }, -- the Weir Ford
			{ "Rothollow", "Apex" },
			{ "WardingShrine", "BlightLine" },
			{ "BlightLine", "Apex" },
		},
		-- The Rootstep Stairs: fieldstone treads up through the Heartrot Spring's roots.
		Stairs = { Rothollow_Apex = true },
		-- The four links that cross the blight-brook (specs: without them the Apex is out of reach).
		Fords = {
			WestGallery_Crossing = "STEPPING_STONES",
			LastGreen_Crossing = "MILL_RACE",
			Crossing_EastGallery = "FALLEN_LOG",
			EastGallery_Rothollow = "WEIR",
		},
		Names = {
			Sanctuary = "Warden's Stile",
			Basin = "Verge Meadow",
			WestGallery = "Pale Glade",
			LastGreen = "The Last Green",
			Woodcutters = "Woodcutters' Ring",
			Crossing = "Weir Mill",
			EastGallery = "Lantern Copse",
			WardingShrine = "Warding Shrine",
			Rothollow = "Rothollow",
			BlightLine = "The Blight Line",
			Apex = "Heartrot Spring",
		},
		Terrain = {
			Direct = true,
			Surface = "HOLLIN",
			-- Built: the stile's landing, the Last Green's fieldstone knoll top and the Woodcutters' log floor.
			Decks = { Sanctuary = true, LastGreen = true, Woodcutters = true },
			DeckLooks = {
				LastGreen = { Color = Color3.fromRGB(104, 96, 82), Material = Enum.Material.Slate },
				Woodcutters = { Color = Color3.fromRGB(96, 70, 48), Material = Enum.Material.Wood },
			},
			-- Every terrain terrace is a rounded rise, never a square plinth.
			Shapes = {
				WestGallery = { Round = 3.0, Grow = 4 },
				Crossing = { Round = 2.6, Grow = 4 },
				EastGallery = { Round = 3.0, Grow = 4 },
				WardingShrine = { Round = 2.8, Grow = 4 },
				Rothollow = { Round = 2.6, Grow = 4 },
				BlightLine = { Round = 3.2, Grow = 4 },
				Apex = { Round = 3.0, Grow = 4 },
			},
			-- The hung fords: the mill-race plank and the fallen log (the brook runs on under them). The
			-- stepping stones and the weir are earthen causeways across it.
			Bridges = { LastGreen_Crossing = true, Crossing_EastGallery = true },
			BridgeStyles = { Crossing_EastGallery = "LOG" },
			-- The Apex is in the north-east corner: no full-width shelf behind it, the wall's own slopes instead.
			NoApexShelf = true,
			-- The brook runs in a channel about 1.5 studs below its banks (the floor's slab carries walkers over it).
			LiquidRise = -1.6,
			FloorDip = 6,
			WallBand = { Base = 40, Noise = 14 },
			-- The blight-brook: from the spring (north-east) down a meander to the sinkhole (west wall).
			Pools = {
				{ X = 214, Z = -236, RX = 14, RZ = 13 }, { X = 220, Z = -212, RX = 15, RZ = 13 },
				{ X = 222, Z = -188, RX = 15, RZ = 13 }, { X = 223, Z = -164, RX = 15, RZ = 13 },
				{ X = 225, Z = -140, RX = 15, RZ = 13 }, { X = 227, Z = -116, RX = 15, RZ = 13 },
				{ X = 229, Z = -92, RX = 15, RZ = 13 }, { X = 230, Z = -70, RX = 15, RZ = 13 },
				{ X = 210, Z = -69, RX = 15, RZ = 13 }, { X = 187, Z = -68, RX = 19, RZ = 17 },
				{ X = 165, Z = -66, RX = 19, RZ = 17 }, { X = 142, Z = -65, RX = 19, RZ = 17 },
				{ X = 120, Z = -64, RX = 19, RZ = 17 }, { X = 100, Z = -50, RX = 19, RZ = 17 },
				{ X = 80, Z = -36, RX = 19, RZ = 17 }, { X = 60, Z = -22, RX = 19, RZ = 17 },
				{ X = 40, Z = -8, RX = 19, RZ = 17 }, { X = 20, Z = -5, RX = 19, RZ = 17 },
				{ X = 0, Z = -1, RX = 19, RZ = 17 }, { X = -20, Z = 2, RX = 19, RZ = 17 },
				{ X = -47, Z = -3, RX = 19, RZ = 17 }, { X = -73, Z = -9, RX = 19, RZ = 17 },
				{ X = -100, Z = -14, RX = 19, RZ = 17 }, { X = -120, Z = -30, RX = 19, RZ = 17 },
				{ X = -140, Z = -46, RX = 19, RZ = 17 }, { X = -160, Z = -62, RX = 16, RZ = 14 },
				{ X = -180, Z = -78, RX = 16, RZ = 14 }, { X = -207, Z = -80, RX = 16, RZ = 14 },
				{ X = -235, Z = -82, RX = 16, RZ = 14 }, { X = -262, Z = -84, RX = 16, RZ = 14 },
			},
			-- Low hillocks rolling the open ground of both banks (walkways cap them where they pass).
			Islands = {
				{ X = -70, Z = 58, R = 30, Top = -1 },
				{ X = 140, Z = 80, R = 30, Top = 0 },
				{ X = -235, Z = 120, R = 26, Top = 2 },
				{ X = -100, Z = -105, R = 30, Top = 4 },
				{ X = 45, Z = -110, R = 34, Top = 8 },
				{ X = -205, Z = -200, R = 32, Top = 12 },
				{ X = 55, Z = -245, R = 30, Top = 16 },
			},
			-- The floor's trees are placed by hand (TowerSetPieces/CorruptedGrove): golden on the south bank,
			-- twisted on the north. The biome's random groves and meadow pods would mix them up.
			GroveScale = 0,
			MeadowScale = 0.15,
		},
	},
	-- Floor 32, Twisted Orchard (Corrupted Grove Expanded Encounter; docs/prompts/corrupted-grove-floor-layouts-prompt.md):
	-- the Hollin's grafting orchard climbing a south-facing terraced slope to the E-W Graft Ridge (Crookback Ridge
	-- Y 40, The Grafted Crown Y 48, Thorn Saddle Y 44) and then descending behind the crest into the hidden
	-- Pressing Hollow (Apex Y 36, lower than the crest!) where the Great Cider Press draws the orchard's rot.
	-- Three routes cross the ridge: centre up the Grafters' Stair (+32) to the Grafted Crown and down the Press
	-- Stair (-12); west via West Rows -> West Espalier -> Crookback Ridge (-4 to Apex, plus ridge-walk to Crown);
	-- east via East Rows -> Skep Terrace -> Thorn Saddle (-8 to Apex, with Cider Vats as a dead-end spur).
	[32] = {
		Key = "corrupted:2",
		Name = "Twisted Orchard",
		Size = { Width = 620, Depth = 640, Height = 220 },
		PathStyle = "HOLLIN",
		Basin = { X = 0, Y = 0, Z = 180, Width = 588, Depth = 100 },
		WestGallery = { X = -200, Y = 8, Z = 60, Width = 88, Depth = 76 },
		EastGallery = { X = 200, Y = 12, Z = 55, Width = 88, Depth = 76 },
		Crossing = { X = 0, Y = 16, Z = 40, Width = 80, Depth = 64 },
		ExtraPlatforms = {
			Windfall = { X = -100, Y = 6, Z = 20, Width = 56, Depth = 48 },
			CiderVats = { X = 250, Y = 20, Z = -110, Width = 60, Depth = 52 },
			WestEspalier = { X = -170, Y = 24, Z = -70, Width = 76, Depth = 62 },
			EastEspalier = { X = 150, Y = 28, Z = -80, Width = 76, Depth = 62 },
			RidgeWest = { X = -130, Y = 40, Z = -175, Width = 72, Depth = 56 },
			RidgeEast = { X = 145, Y = 44, Z = -185, Width = 72, Depth = 56 },
			GraftedCrown = { X = 0, Y = 48, Z = -140, Width = 84, Depth = 60 },
		},
		Apex = { X = 0, Y = 36, Z = -250, Width = 120, Depth = 88 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "Crossing" },
			{ "Basin", "EastGallery" },
			{ "Basin", "Windfall" },
			{ "WestGallery", "WestEspalier" },
			{ "EastGallery", "EastEspalier" },
			{ "Crossing", "GraftedCrown" }, -- Grafters' Stair (+32)
			{ "GraftedCrown", "Apex" }, -- Press Stair (-12)
			{ "WestEspalier", "RidgeWest" },
			{ "EastEspalier", "RidgeEast" },
			{ "RidgeWest", "Apex" },
			{ "RidgeEast", "Apex" },
			{ "EastEspalier", "CiderVats" },
			{ "RidgeWest", "GraftedCrown" }, -- Ridge-walk
		},
		Stairs = {
			Crossing_GraftedCrown = true,
			GraftedCrown_Apex = true,
		},
		Names = {
			Sanctuary = "Orchard Gate",
			Basin = "Orchard Lawn",
			Windfall = "Windfall Hollow",
			WestGallery = "West Rows",
			EastGallery = "East Rows",
			Crossing = "Grafters' Yard",
			CiderVats = "Cider Vats",
			WestEspalier = "West Espalier",
			EastEspalier = "Skep Terrace",
			RidgeWest = "Crookback Ridge",
			RidgeEast = "Thorn Saddle",
			GraftedCrown = "The Grafted Crown",
			Apex = "Pressing Hollow",
		},
		Terrain = {
			Direct = true,
			Surface = "HOLLIN",
			-- Built: the Orchard Gate landing and Windfall Hollow's slatted timber fruit-drying deck.
			Decks = { Sanctuary = true, Windfall = true },
			DeckLooks = {
				Windfall = { Color = Color3.fromRGB(108, 76, 52), Material = Enum.Material.Wood },
			},
			-- Organic rounded terrain terraces and the round Pressing Hollow bowl.
			Shapes = {
				WestGallery = { Round = 3.2, Grow = 4 },
				EastGallery = { Round = 3.2, Grow = 4 },
				Crossing = { Round = 3.0, Grow = 4 },
				CiderVats = { Round = 2.8, Grow = 4 },
				WestEspalier = { Round = 3.0, Grow = 4 },
				EastEspalier = { Round = 3.0, Grow = 4 },
				RidgeWest = { Round = 2.8, Grow = 4 },
				RidgeEast = { Round = 2.8, Grow = 4 },
				GraftedCrown = { Round = 2.4, Grow = 5 },
				Apex = { Round = 2.4, Grow = 5 },
			},
			LiquidRise = 0.8,
			FloorDip = 3.4,
			WallBand = { Base = 42, Noise = 14 },
			-- Shallow rot-fruit puddles along the lower orchard edge (Orchard Lawn & south orchard rows).
			Pools = {
				{ X = -238, Z = 132, RX = 14, RZ = 10 },
				{ X = -142, Z = 112, RX = 12, RZ = 9 },
				{ X = 112, Z = 114, RX = 13, RZ = 9 },
				{ X = 236, Z = 130, RX = 14, RZ = 10 },
				{ X = -58, Z = 98, RX = 11, RZ = 8 },
				{ X = 70, Z = 102, RX = 11, RZ = 8 },
			},
			-- Solid earthen knoll under the Great Cider Press & Press-House Roof on the back-west hollow rim
			-- (expressed in Ridges below so walkway caps never crater it).
			-- Continuous south-facing orchard slope with shallow E-W terrain benches climbing to the Graft Ridge.
			Slope = {
				ZStart = 126,
				ZEnd = -132,
				YStart = -4,
				YEnd = 36,
				BenchSpan = 34,
				BenchStep = 2.6,
				FadeNorth = 46,
			},
			-- The E-W Graft Ridge: solid earthen ridge crests joining Crookback Ridge, The Grafted Crown and
			-- Thorn Saddle into the room's east/west walls, hiding the Pressing Hollow (Y 36) from arrival.
			Ridges = {
				{
					HalfWidth = 34,
					NoiseAmp = 3.8,
					Points = {
						{ -310, -190, 68 },
						{ -188, -182, 62 },
					},
				},
				{
					HalfWidth = 26,
					NoiseAmp = 3.0,
					Points = {
						{ -90, -184, 60 },
						{ -56, -182, 60 },
					},
				},
				{
					HalfWidth = 42,
					NoiseAmp = 3.8,
					Points = {
						{ 48, -162, 62 },
						{ 104, -174, 62 },
					},
				},
				{
					HalfWidth = 34,
					NoiseAmp = 3.8,
					Points = {
						{ 194, -186, 62 },
						{ 310, -196, 68 },
					},
				},
				-- Raised press-house knoll on the Pressing Hollow's back-west rim under the Great Cider Press.
				{
					HalfWidth = 58,
					NoiseAmp = 2.0,
					Points = {
						{ -126, -290, 48 },
						{ -96, -274, 48 },
					},
				},
			},
			-- Floor 32 places all of its orchard rows, grafted trees and ground cover by hand.
			GroveScale = 0,
			MeadowScale = 0.1,
		},
	},
	-- Floor 33, Briar Labyrinth (Corrupted Grove Terrain Variation; docs/prompts/corrupted-grove-floor-layouts-prompt.md):
	-- the hedge-maze the Hollin wardens planted over a sunken thorn pit (Bottom = -6) to wall in the Thornheart.
	-- Thornheart Court (Apex, Y 44) stands in the exact centre of the room, visible over the low hedges from the
	-- arrival, with the Briar Gate (Crossing, Y 8) directly in front and NO path across the pit. East leads to
	-- the false dead-end Thornwrack (Y 22, unbanded); west (marked with Pale Bands) climbs via Nettle Turn ->
	-- Hanging Garden -> Garden Stair into the Court, or around the long outer ring (Briar Cloister -> North
	-- Hedge Gate -> Gibbet Thicket -> East Rosary -> Thornheart Steps STAIRS into the Court from the south-east).
	[33] = {
		Key = "corrupted:3",
		Name = "Briar Labyrinth",
		Size = { Width = 680, Depth = 720, Height = 250, Bottom = -6 },
		PathStyle = "HOLLIN",
		Basin = { X = 0, Y = 0, Z = 200, Width = 648, Depth = 96 },
		Crossing = { X = 0, Y = 8, Z = 80, Width = 84, Depth = 64 },
		WestGallery = { X = -200, Y = 12, Z = 60, Width = 88, Depth = 76 },
		EastGallery = { X = 200, Y = 16, Z = 60, Width = 88, Depth = 76 },
		ExtraPlatforms = {
			MenderCroft = { X = -100, Y = 4, Z = 118, Width = 56, Depth = 44 },
			NettleThicket = { X = -235, Y = 20, Z = -130, Width = 72, Depth = 60 },
			Thornwrack = { X = 255, Y = 22, Z = -60, Width = 60, Depth = 56 },
			BriarCloister = { X = -150, Y = 24, Z = -255, Width = 64, Depth = 52 },
			HangingGarden = { X = -150, Y = 26, Z = -30, Width = 64, Depth = 56 },
			NorthGate = { X = 0, Y = 28, Z = -255, Width = 80, Depth = 60 },
			HangingThicket = { X = 150, Y = 32, Z = -250, Width = 64, Depth = 56 },
			EastRosary = { X = 170, Y = 36, Z = -120, Width = 64, Depth = 56 },
			ThornheartSteps = { X = 110, Y = 40, Z = -10, Width = 64, Depth = 56 },
		},
		Apex = { X = 0, Y = 44, Z = -60, Width = 124, Depth = 92 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Crossing" },
			{ "Basin", "MenderCroft" },
			{ "MenderCroft", "WestGallery" },
			{ "Crossing", "WestGallery" },
			{ "Crossing", "EastGallery" },
			{ "EastGallery", "Thornwrack" }, -- false path (dead end, unbanded)
			{ "WestGallery", "NettleThicket" },
			{ "NettleThicket", "HangingGarden" },
			{ "NettleThicket", "BriarCloister" },
			{ "HangingGarden", "BriarCloister" },
			{ "HangingGarden", "Apex" }, -- Garden Stair (+18)
			{ "BriarCloister", "NorthGate" },
			{ "NorthGate", "HangingThicket" },
			{ "HangingThicket", "EastRosary" },
			{ "EastRosary", "ThornheartSteps" },
			{ "ThornheartSteps", "Apex" }, -- Thornheart Steps (STAIRS, +4)
		},
		Stairs = {
			ThornheartSteps_Apex = true,
		},
		Patrols = {
			GATE_WALK = { "WestGallery", "Crossing", "EastGallery" },
			WEST_MAZE = { "WestGallery", "NettleThicket", "HangingGarden" },
			OUTER_RING = { "BriarCloister", "NorthGate", "HangingThicket", "EastRosary" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Hedge Stile",
			Basin = "Briar Lawn",
			MenderCroft = "Mender's Croft",
			Crossing = "Briar Gate",
			WestGallery = "West Walk",
			EastGallery = "East Walk",
			NettleThicket = "Nettle Turn",
			Thornwrack = "Thornwrack",
			BriarCloister = "Briar Cloister",
			HangingGarden = "Hanging Garden",
			NorthGate = "North Hedge Gate",
			HangingThicket = "Gibbet Thicket",
			EastRosary = "East Rosary",
			ThornheartSteps = "Thornheart Steps",
			Apex = "Thornheart Court",
		},
		Terrain = {
			Direct = true,
			Surface = "BLIGHT",
			Blight = { FissureDepth = 4.5, CragHeight = 14 },
			Decks = { Sanctuary = true, Thornwrack = true, HangingGarden = true },
			DeckLooks = {
				Thornwrack = { Color = Color3.fromRGB(68, 44, 58), Material = Enum.Material.Wood },
				HangingGarden = { Color = Color3.fromRGB(108, 82, 62), Material = Enum.Material.Wood },
			},
			Shapes = {
				MenderCroft = { Round = 3.2, Grow = 4 },
				Crossing = { Round = 3.2, Grow = 4 },
				WestGallery = { Round = 3.0, Grow = 4 },
				EastGallery = { Round = 3.0, Grow = 4 },
				NettleThicket = { Round = 3.0, Grow = 4 },
				BriarCloister = { Round = 3.0, Grow = 4 },
				NorthGate = { Round = 3.0, Grow = 4 },
				HangingThicket = { Round = 3.0, Grow = 4 },
				EastRosary = { Round = 3.0, Grow = 4 },
				ThornheartSteps = { Round = 2.8, Grow = 4 },
				Apex = { Round = 2.2, Grow = 5 },
			},
			-- Every link spanning the sunken thorn pit is a hedge-walled bridge over the pit floor.
			Bridges = {
				EastGallery_Thornwrack = true,
				WestGallery_NettleThicket = true,
				NettleThicket_HangingGarden = true,
				NettleThicket_BriarCloister = true,
				HangingGarden_BriarCloister = true,
				HangingGarden_Apex = true,
				BriarCloister_NorthGate = true,
				NorthGate_HangingThicket = true,
				HangingThicket_EastRosary = true,
				EastRosary_ThornheartSteps = true,
			},
			BridgeStyles = {
				EastGallery_Thornwrack = "HEDGE",
				WestGallery_NettleThicket = "HEDGE",
				NettleThicket_HangingGarden = "HEDGE",
				NettleThicket_BriarCloister = "HEDGE",
				HangingGarden_BriarCloister = "HEDGE",
				HangingGarden_Apex = "HEDGE",
				BriarCloister_NorthGate = "HEDGE",
				NorthGate_HangingThicket = "HEDGE",
				HangingThicket_EastRosary = "HEDGE",
				EastRosary_ThornheartSteps = "HEDGE",
			},
			-- The Apex sits in the middle of the room: no shelf behind it (NorthGate stands behind it across the pit).
			NoApexShelf = true,
			-- Dry thorn pit: no water pools. A raised rocky briar mound in the northern pit seats the Thornheart
			-- high enough that its glowing magenta cavity looms directly over the north rim of Thornheart Court,
			-- while jagged corrupted basalt crags jut from open pit pockets around the central mesa.
			LiquidRise = -10,
			Pools = {},
			Ridges = {
				{
					HalfWidth = 38,
					NoiseAmp = 2.6,
					Points = {
						{ -16, -166, 28 },
						{ 16, -166, 28 },
					},
				},
				{
					HalfWidth = 22,
					NoiseAmp = 3.2,
					Points = {
						{ -104, -142, 18 },
						{ -86, -130, 18 },
					},
				},
				{
					HalfWidth = 22,
					NoiseAmp = 3.2,
					Points = {
						{ 86, -160, 18 },
						{ 104, -148, 18 },
					},
				},
				{
					HalfWidth = 20,
					NoiseAmp = 3.0,
					Points = {
						{ -100, 14, 14 },
						{ -84, 24, 14 },
					},
				},
				{
					HalfWidth = 20,
					NoiseAmp = 3.0,
					Points = {
						{ 94, 56, 14 },
						{ 112, 66, 14 },
					},
				},
			},
			WallBand = { Base = 48, Noise = 18 },
			GroveScale = 0,
			MeadowScale = 0.05,
		},
	},
	-- Floor 34, Heartrot Stronghold (Corrupted Grove Elite Stronghold; docs/prompts/corrupted-grove-floor-layouts-prompt.md):
	-- the Hollin wardens' last refuge built up five colossal elder trunks over a deeply corrupted violet-black rot bog
	-- (Bottom = -6, Surface = "BLIGHT"), climbing tree to tree on bracket decks and branch bridges to the Heartrot Crown
	-- (Apex, Y 52) cradled in the fork of the Great Rotwood at the back-west.
	[34] = {
		Key = "corrupted:4",
		Name = "Heartrot Stronghold",
		Size = { Width = 750, Depth = 795, Height = 275, Bottom = -6 },
		PathStyle = "HOLLIN",
		Basin = { X = 0, Y = 0, Z = 232, Width = 718, Depth = 104 },
		Crossing = { X = 0, Y = 8, Z = 110, Width = 88, Depth = 68 },
		WestGallery = { X = -205, Y = 12, Z = 95, Width = 92, Depth = 80 },
		EastGallery = { X = 205, Y = 14, Z = 85, Width = 92, Depth = 80 },
		WestBastion = { X = -240, Y = 32, Z = -170, Width = 92, Depth = 82 },
		EastBastion = { X = 235, Y = 36, Z = -160, Width = 92, Depth = 82 },
		ExtraPlatforms = {
			MenderWard = { X = -295, Y = 6, Z = -20, Width = 56, Depth = 52 },
			ShelfLedge = { X = 160, Y = 18, Z = -40, Width = 72, Depth = 60 },
			LowerBole = { X = 0, Y = 20, Z = 0, Width = 80, Depth = 64 },
			SapCistern = { X = -150, Y = 26, Z = -60, Width = 72, Depth = 60 },
			SeedVault = { X = 110, Y = 30, Z = -150, Width = 60, Depth = 52 },
			MiddleFork = { X = 0, Y = 40, Z = -150, Width = 80, Depth = 64 },
			CanopyWalk = { X = 130, Y = 44, Z = -275, Width = 76, Depth = 60 },
			WeepingGallows = { X = -300, Y = 48, Z = -300, Width = 56, Depth = 52 },
		},
		Apex = { X = -150, Y = 52, Z = -290, Width = 136, Depth = 100 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "Crossing" },
			{ "Basin", "WestGallery" },
			{ "Basin", "EastGallery" },
			{ "WestGallery", "MenderWard" },
			{ "Crossing", "LowerBole" },
			{ "WestGallery", "SapCistern" },
			{ "EastGallery", "ShelfLedge" },
			{ "LowerBole", "SapCistern" },
			{ "LowerBole", "ShelfLedge" },
			{ "SapCistern", "WestBastion" },
			{ "ShelfLedge", "EastBastion" },
			{ "LowerBole", "MiddleFork" }, -- Bole Stair (STAIRS, +20)
			{ "MiddleFork", "SeedVault" },
			{ "EastBastion", "CanopyWalk" },
			{ "MiddleFork", "Apex" },
			{ "CanopyWalk", "Apex" },
			{ "WestBastion", "Apex" },
			{ "WestBastion", "WeepingGallows" },
		},
		Stairs = {
			LowerBole_MiddleFork = true,
		},
		Patrols = {
			BOLE_RING = { "SapCistern", "LowerBole", "ShelfLedge" },
			WEST_CLIMB = { "WestGallery", "SapCistern", "WestBastion" },
			EAST_CLIMB = { "EastGallery", "ShelfLedge", "EastBastion" },
			CROWN_WALK = { "WestBastion", "Apex", "MiddleFork" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "Bog Stair",
			Basin = "Sedge Landing",
			MenderWard = "Mender's Ward",
			Crossing = "Rootgate",
			WestGallery = "West Stockade",
			EastGallery = "East Stockade",
			ShelfLedge = "Bracket Ledge",
			LowerBole = "The Lower Bole",
			SapCistern = "Sap Cistern",
			SeedVault = "Seed Vault",
			WestBastion = "West Bole Keep",
			EastBastion = "East Bole Keep",
			MiddleFork = "Middle Fork",
			CanopyWalk = "Canopy Walk",
			WeepingGallows = "Weeping Gallows",
			Apex = "Heartrot Crown",
		},
		Terrain = {
			Direct = true,
			Surface = "BLIGHT",
			Blight = { FissureDepth = 5.0, CragHeight = 15 },
			Decks = {
				Sanctuary = true,
				MenderWard = true,
				EastGallery = true,
				ShelfLedge = true,
				LowerBole = true,
				SapCistern = true,
				SeedVault = true,
			},
			DeckLooks = {
				MenderWard = { Color = Color3.fromRGB(68, 46, 56), Material = Enum.Material.Wood },
				EastGallery = { Color = Color3.fromRGB(78, 56, 58), Material = Enum.Material.Wood },
				ShelfLedge = { Color = Color3.fromRGB(118, 42, 118), Material = Enum.Material.SmoothPlastic },
				LowerBole = { Color = Color3.fromRGB(74, 52, 58), Material = Enum.Material.Wood },
				SapCistern = { Color = Color3.fromRGB(72, 48, 60), Material = Enum.Material.Wood },
				SeedVault = { Color = Color3.fromRGB(64, 42, 54), Material = Enum.Material.Wood },
			},
			Shapes = {
				Crossing = { Round = 3.0, Grow = 4 },
				WestGallery = { Round = 3.0, Grow = 4 },
				WestBastion = { Round = 2.8, Grow = 5 },
				EastBastion = { Round = 2.8, Grow = 5 },
				MiddleFork = { Round = 2.6, Grow = 5 },
				CanopyWalk = { Round = 2.8, Grow = 4 },
				WeepingGallows = { Round = 2.8, Grow = 4 },
				Apex = { Round = 2.2, Grow = 6 },
			},
			Bridges = {
				WestGallery_MenderWard = true,
				Crossing_LowerBole = true,
				WestGallery_SapCistern = true,
				EastGallery_ShelfLedge = true,
				LowerBole_SapCistern = true,
				LowerBole_ShelfLedge = true,
				SapCistern_WestBastion = true,
				ShelfLedge_EastBastion = true,
				MiddleFork_SeedVault = true,
				EastBastion_CanopyWalk = true,
				MiddleFork_Apex = true,
				CanopyWalk_Apex = true,
				WestBastion_Apex = true,
				WestBastion_WeepingGallows = true,
			},
			BridgeStyles = {
				WestGallery_MenderWard = "BRANCH",
				Crossing_LowerBole = "BRANCH",
				WestGallery_SapCistern = "BRANCH",
				EastGallery_ShelfLedge = "BRANCH",
				LowerBole_SapCistern = "BRANCH",
				LowerBole_ShelfLedge = "BRANCH",
				SapCistern_WestBastion = "BRANCH",
				ShelfLedge_EastBastion = "BRANCH",
				MiddleFork_SeedVault = "BRANCH",
				EastBastion_CanopyWalk = "BRANCH",
				MiddleFork_Apex = "BRANCH",
				CanopyWalk_Apex = "BRANCH",
				WestBastion_Apex = "BRANCH",
				WestBastion_WeepingGallows = "BRANCH",
			},
			NoApexShelf = true,
			LiquidRise = 1.8,
			Pools = {
				{ X = -115, Z = -15, RX = 160, RZ = 145 },
				{ X = 120, Z = -20, RX = 160, RZ = 150 },
				{ X = 0, Z = -210, RX = 215, RZ = 105 },
			},
			WallBand = { Base = 54, Noise = 20 },
			GroveScale = 0,
			MeadowScale = 0.05,
		},
	},
	-- Floor 35, Sovereign's Grove (Corrupted Grove Biome Boss: Blight Sovereign; docs/prompts/corrupted-grove-floor-layouts-prompt.md):
	-- the Mother Graft's colossal root crown over an abyssal sap mire (Bottom = -8, Surface = "BLIGHT").
	-- Three colossal roots fan out from the 184 x 136 Sovereign's Dais (Apex, Y 60) toward the Mire Shore (Basin, Y 0):
	-- West Root, Taproot (ending in the Heart Stair STAIRS +20), and East Root, joined at the knees with four spurs.
	[35] = {
		Key = "corrupted:5",
		Name = "Sovereign's Grove",
		Size = { Width = 810, Depth = 795, Height = 305, Bottom = -8 },
		PathStyle = "HOLLIN",
		Basin = { X = 0, Y = 0, Z = 236, Width = 778, Depth = 104 },
		WestGallery = { X = -230, Y = 8, Z = 100, Width = 92, Depth = 80 },
		EastGallery = { X = 230, Y = 10, Z = 100, Width = 92, Depth = 80 },
		Crossing = { X = 0, Y = 12, Z = 105, Width = 88, Depth = 68 },
		WestBastion = { X = -200, Y = 36, Z = -160, Width = 92, Depth = 82 },
		EastBastion = { X = 200, Y = 38, Z = -160, Width = 92, Depth = 82 },
		ExtraPlatforms = {
			WeepingPulpit = { X = -120, Y = 14, Z = 40, Width = 60, Depth = 50 },
			RotbloomNursery = { X = 120, Y = 18, Z = 40, Width = 60, Depth = 50 },
			WestRootKnee = { X = -250, Y = 20, Z = -30, Width = 76, Depth = 64 },
			EastRootKnee = { X = 250, Y = 22, Z = -30, Width = 76, Depth = 64 },
			TaprootKnuckle = { X = 0, Y = 24, Z = -20, Width = 80, Depth = 64 },
			FallenCrownRing = { X = -330, Y = 28, Z = -120, Width = 60, Depth = 56 },
			SapfallLedge = { X = 330, Y = 30, Z = -120, Width = 60, Depth = 56 },
			TaprootSpine = { X = 0, Y = 40, Z = -140, Width = 76, Depth = 56 },
			WestRootCrown = { X = -165, Y = 48, Z = -290, Width = 64, Depth = 56 },
			EastRootCrown = { X = 165, Y = 50, Z = -290, Width = 64, Depth = 56 },
		},
		Apex = { X = 0, Y = 60, Z = -300, Width = 184, Depth = 136 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "Crossing" },
			{ "Basin", "EastGallery" },
			{ "WestGallery", "WestRootKnee" },
			{ "EastGallery", "EastRootKnee" },
			{ "Crossing", "TaprootKnuckle" },
			{ "WestRootKnee", "WestBastion" },
			{ "EastRootKnee", "EastBastion" },
			{ "WestBastion", "WestRootCrown" },
			{ "EastBastion", "EastRootCrown" },
			{ "WestRootCrown", "Apex" },
			{ "EastRootCrown", "Apex" },
			{ "TaprootKnuckle", "TaprootSpine" },
			{ "TaprootSpine", "Apex" }, -- Heart Stair (STAIRS, +20)
			{ "WestGallery", "WeepingPulpit" },
			{ "EastGallery", "RotbloomNursery" },
			{ "WestRootKnee", "FallenCrownRing" },
			{ "EastRootKnee", "SapfallLedge" },
			{ "TaprootKnuckle", "WestRootKnee" },
			{ "TaprootKnuckle", "EastRootKnee" },
		},
		Stairs = {
			TaprootSpine_Apex = true,
		},
		Patrols = {
			WEST_ROOT = { "WestGallery", "WestRootKnee", "WestBastion", "WestRootCrown" },
			EAST_ROOT = { "EastGallery", "EastRootKnee", "EastBastion", "EastRootCrown" },
			TAPROOT = { "Crossing", "TaprootKnuckle", "TaprootSpine" },
			KNEE_CHORD = { "WestRootKnee", "TaprootKnuckle", "EastRootKnee" },
			CROWN_RING = { "WestRootCrown", "Apex", "EastRootCrown" },
		},
		ReplacePatrols = true,
		Names = {
			Sanctuary = "The Last Band",
			Basin = "Mire Shore",
			WestGallery = "West Root Foot",
			EastGallery = "East Root Foot",
			Crossing = "Taproot Foot",
			WeepingPulpit = "Weeping Pulpit",
			RotbloomNursery = "Rotbloom Nursery",
			WestRootKnee = "West Root Knee",
			EastRootKnee = "East Root Knee",
			TaprootKnuckle = "Taproot Knuckle",
			FallenCrownRing = "Fallen Crown Ring",
			SapfallLedge = "Sapfall Ledge",
			WestBastion = "West Root Crest",
			EastBastion = "East Root Crest",
			TaprootSpine = "Taproot Spine",
			WestRootCrown = "West Root Crown",
			EastRootCrown = "East Root Crown",
			Apex = "Sovereign's Dais",
		},
		Terrain = {
			Direct = true,
			Surface = "BLIGHT",
			Blight = { FissureDepth = 6.0, CragHeight = 16 },
			Decks = {
				Sanctuary = true,
				EastGallery = true,
				WeepingPulpit = true,
				RotbloomNursery = true,
				EastRootKnee = true,
				SapfallLedge = true,
				EastBastion = true,
				EastRootCrown = true,
			},
			DeckLooks = {
				EastGallery = { Color = Color3.fromRGB(54, 34, 62), Material = Enum.Material.Wood },
				WeepingPulpit = { Color = Color3.fromRGB(58, 36, 66), Material = Enum.Material.Wood },
				RotbloomNursery = { Color = Color3.fromRGB(62, 34, 68), Material = Enum.Material.Wood },
				EastRootKnee = { Color = Color3.fromRGB(52, 32, 60), Material = Enum.Material.Wood },
				SapfallLedge = { Color = Color3.fromRGB(64, 32, 68), Material = Enum.Material.Wood },
				EastBastion = { Color = Color3.fromRGB(50, 30, 58), Material = Enum.Material.Wood },
				EastRootCrown = { Color = Color3.fromRGB(48, 28, 56), Material = Enum.Material.Wood },
			},
			Shapes = {
				WestGallery = { Round = 2.8, Grow = 5 },
				Crossing = { Round = 2.8, Grow = 5 },
				WestRootKnee = { Round = 2.6, Grow = 5 },
				TaprootKnuckle = { Round = 2.6, Grow = 5 },
				FallenCrownRing = { Round = 2.6, Grow = 4 },
				WestBastion = { Round = 2.6, Grow = 5 },
				TaprootSpine = { Round = 2.6, Grow = 5 },
				WestRootCrown = { Round = 2.6, Grow = 5 },
				Apex = { Round = 2.0, Grow = 6 },
			},
			Bridges = {
				Basin_WestGallery = true,
				Basin_Crossing = true,
				Basin_EastGallery = true,
				WestGallery_WeepingPulpit = true,
				EastGallery_RotbloomNursery = true,
				WestRootKnee_FallenCrownRing = true,
				EastRootKnee_SapfallLedge = true,
				TaprootKnuckle_WestRootKnee = true,
				TaprootKnuckle_EastRootKnee = true,
				EastGallery_EastRootKnee = true,
				EastRootKnee_EastBastion = true,
				EastBastion_EastRootCrown = true,
				EastRootCrown_Apex = true,
			},
			BridgeStyles = {
				Basin_WestGallery = "ROOT",
				Basin_Crossing = "ROOT",
				Basin_EastGallery = "ROOT",
				WestGallery_WeepingPulpit = "ROOT",
				EastGallery_RotbloomNursery = "ROOT",
				WestRootKnee_FallenCrownRing = "ROOT",
				EastRootKnee_SapfallLedge = "ROOT",
				TaprootKnuckle_WestRootKnee = "ROOT",
				TaprootKnuckle_EastRootKnee = "ROOT",
				EastGallery_EastRootKnee = "ROOT",
				EastRootKnee_EastBastion = "ROOT",
				EastBastion_EastRootCrown = "ROOT",
				EastRootCrown_Apex = "ROOT",
			},
			NoApexShelf = true,
			LiquidRise = 2.0,
			Pools = {
				{ X = -140, Z = -20, RX = 185, RZ = 175 },
				{ X = 140, Z = -20, RX = 185, RZ = 175 },
				{ X = 0, Z = -175, RX = 220, RZ = 120 },
			},
			WallBand = { Base = 28, Noise = 10 },
			GroveScale = 0,
			MeadowScale = 0.04,
		},
	},
	-- Floor 36, Drowned Steps (Sunken Sanctuary Introduction; docs/prompts/sunken-sanctuary-floor-layouts-prompt.md,
	-- guide image reference/Sunken Sanctuary 36.webp): the Nereth city's sea-front at low tide. A tide-flat of
	-- turquoise shallows and sandbars; the Pilgrim Stair climbs from the Stair Foot up the First Flight to the
	-- Pilgrims' Landing, and then stops: its middle flight lies broken in the surf with its bell drowned under it,
	-- and there is NO link from the Landing to the Bell Landing beyond the gap. Detours run round it east (the Votive
	-- Pool) and west (the wrecked Hollin barge on its sandbar, then Cantors' Rock), and a scenic one climbs the
	-- Tidepool Steps to the Upper Pools. The Apex, the Bell Stack, is a sheer limestone sea-stack in the back-west,
	-- crowned by the shrine of the first Tidebell and reached up the Bell Stair (south) or from Cantors' Rock (west).
	[36] = {
		Key = "sunken:1",
		Name = "Drowned Steps",
		Size = { Width = 570, Depth = 600, Height = 210 },
		PathStyle = "NERETH",
		Basin = { X = 0, Y = 0, Z = 155, Width = 538, Depth = 96 },
		Crossing = { X = 30, Y = 8, Z = 30, Width = 76, Depth = 60 },
		WestGallery = { X = -170, Y = 4, Z = 40, Width = 84, Depth = 72 },
		EastGallery = { X = 195, Y = 12, Z = 45, Width = 84, Depth = 72 },
		ExtraPlatforms = {
			Wreck = { X = -185, Y = 6, Z = -62, Width = 64, Depth = 48 },
			Votive = { X = 85, Y = 10, Z = -55, Width = 56, Depth = 48 },
			PilgrimLanding = { X = -30, Y = 16, Z = -52, Width = 64, Depth = 52 },
			CantorRock = { X = -222, Y = 20, Z = -196, Width = 56, Depth = 48 },
			BellLanding = { X = 10, Y = 24, Z = -140, Width = 64, Depth = 52 },
			UpperPools = { X = 150, Y = 28, Z = -150, Width = 72, Depth = 60 },
		},
		Apex = { X = -85, Y = 32, Z = -228, Width = 116, Depth = 84 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "Crossing" },
			{ "Basin", "EastGallery" },
			{ "Crossing", "PilgrimLanding" }, -- the First Flight
			{ "WestGallery", "Wreck" }, -- the Barge Causeway
			{ "PilgrimLanding", "Wreck" }, -- the Landing Causeway, down to the barge
			{ "Wreck", "CantorRock" },
			{ "CantorRock", "Apex" },
			{ "Crossing", "Votive" }, -- the Votive Causeway
			{ "PilgrimLanding", "Votive" },
			{ "Votive", "EastGallery" },
			{ "EastGallery", "UpperPools" },
			{ "UpperPools", "BellLanding" },
			{ "Votive", "BellLanding" }, -- the Bell Causeway, over the fallen flight's surf
			{ "BellLanding", "Apex" }, -- the Bell Stair
		},
		-- The two flights of the Pilgrim Stair that still stand: limestone treads under bell arches.
		Stairs = { Crossing_PilgrimLanding = true, BellLanding_Apex = true },
		-- The fallen middle flight (specs: no PilgrimLanding-BellLanding link, and the Apex stays reachable without one).
		BrokenFlight = { From = "PilgrimLanding", To = "BellLanding" },
		Names = {
			Sanctuary = "Pilgrims' Gate",
			Basin = "The Tide-Flat",
			WestGallery = "Shell Midden",
			Crossing = "Stair Foot",
			EastGallery = "Tidepool Steps",
			Wreck = "The Hollin Barge",
			Votive = "Votive Pool",
			PilgrimLanding = "Pilgrims' Landing",
			CantorRock = "Cantors' Rock",
			BellLanding = "Bell Landing",
			UpperPools = "Upper Pools",
			Apex = "The Bell Stack",
		},
		Terrain = {
			Direct = true,
			Surface = "NERETH",
			-- Built: the gate's flagged landing, the barge's deck on its sandbar, the Votive Pool's flagged rim and
			-- the Pilgrims' Landing (a marble slab on piers over the surf, its north edge sheared off).
			Decks = { Sanctuary = true, Wreck = true, Votive = true, PilgrimLanding = true },
			DeckThickness = { PilgrimLanding = 3 },
			DeckLooks = {
				Wreck = { Color = Color3.fromRGB(112, 92, 72), Material = Enum.Material.Wood },
				Votive = { Color = Color3.fromRGB(212, 204, 184), Material = Enum.Material.Limestone },
				PilgrimLanding = { Color = Color3.fromRGB(222, 218, 204), Material = Enum.Material.Marble },
			},
			-- Every terrain terrace is a rounded rock in the surf; the Bell Stack's apron is sheer (a sea-stack).
			Shapes = {
				WestGallery = { Round = 2.8, Grow = 4 },
				Crossing = { Round = 2.4, Grow = 4 },
				EastGallery = { Round = 2.8, Grow = 4 },
				CantorRock = { Round = 2.2, Grow = 4 },
				BellLanding = { Round = 2.6, Grow = 4 },
				UpperPools = { Round = 2.4, Grow = 4 },
				Apex = { Round = 2.2, Grow = 6, Sheer = true },
			},
			-- The causeways: flagged limestone on arched piers, the surf running on under them.
			Bridges = { WestGallery_Wreck = true, PilgrimLanding_Wreck = true, Crossing_Votive = true, Votive_BellLanding = true },
			BridgeStyles = {
				WestGallery_Wreck = "CAUSEWAY",
				PilgrimLanding_Wreck = "CAUSEWAY",
				Crossing_Votive = "CAUSEWAY",
				Votive_BellLanding = "CAUSEWAY",
			},
			-- The Bell Stack is in the back-west: no full-width shelf behind it.
			NoApexShelf = true,
			-- The surf: just under the floor's slab (it carries walkers as wading ground), deep enough to read turquoise.
			LiquidRise = -0.6,
			FloorDip = 7,
			-- The north wall is the far shore: a low sea-cliff, so the Tidewall stands over it (TowerSetPieces).
			WallBand = { Base = 34, Noise = 12, NorthScale = 0.3 },
			-- The sea: one sheet of shallows over all the open ground. The terraces and their banks, the sandbars and
			-- the Tide-Flat's beach stand out of it; only the room's far corners stay dry.
			Pools = {
				{ X = 0, Z = -60, RX = 330, RZ = 300 },
			},
			-- Sandbars: the barge's bar (the largest), the fallen flight's rubble bar and low bars in the shallows.
			Islands = {
				{ X = -185, Z = -62, R = 46, Top = -2 },
				{ X = -62, Z = -118, R = 16, Top = -3 },
				{ X = 120, Z = -222, R = 22, Top = -3 },
				{ X = -95, Z = 40, R = 18, Top = -3 },
				{ X = 230, Z = -120, R = 18, Top = -2 },
				{ X = 110, Z = 96, R = 20, Top = -3 },
			},
			-- The floor places its own coral, kelp and shells (TowerSetPieces/SunkenSanctuary).
			GroveScale = 0,
			MeadowScale = 0.1,
		},
	},
	-- Floor 37, Coral Cloister (Sunken Sanctuary Expanded Encounter; docs/prompts/sunken-sanctuary-floor-layouts-prompt.md,
	-- guide image reference/Sunken Sanctuary 37.jpg): the Nereth cantors' double cloister, a figure-eight of two
	-- arcaded walks around two flooded squircle garths. From Lay Court you can cross the south garth directly on
	-- the flagged Garth Causeway to the Lavabo (the domed fountain house at the waist) or walk either arcaded
	-- gallery (West Walk, East Walk, each with an Elite). Across the north garth stands Chapter Isle (Apex, sheer
	-- coral rock) with NO link from the Lavabo or the Bell Tower behind it: walk round by Cantors' Walk (west) or
	-- Coral Walk (east) and climb one of the twin coral-arched Isle Stairs (`STAIRS`, BridgeStyles = "ARCADE").
	-- Side spurs house the Dorter, Frater, Choir Loft, Sacristy and Scriptorium.
	[37] = {
		Key = "sunken:2",
		Name = "Coral Cloister",
		Size = { Width = 640, Depth = 690, Height = 235 },
		PathStyle = "NERETH",
		Basin = { X = 0, Y = 0, Z = 200, Width = 608, Depth = 100 },
		WestGallery = { X = -135, Y = 8, Z = 60, Width = 88, Depth = 76 },
		EastGallery = { X = 135, Y = 12, Z = 60, Width = 88, Depth = 76 },
		Crossing = { X = 0, Y = 16, Z = -50, Width = 84, Depth = 64 },
		ExtraPlatforms = {
			Dorter = { X = -250, Y = 4, Z = -40, Width = 56, Depth = 48 },
			Frater = { X = 250, Y = 10, Z = -40, Width = 56, Depth = 48 },
			CantorsWalk = { X = -164, Y = 20, Z = -185, Width = 80, Depth = 64 },
			CoralWalk = { X = 150, Y = 24, Z = -185, Width = 80, Depth = 64 },
			ChoirLoft = { X = -252, Y = 26, Z = -150, Width = 56, Depth = 48 },
			Sacristy = { X = -255, Y = 28, Z = -300, Width = 56, Depth = 44 },
			Scriptorium = { X = 252, Y = 30, Z = -150, Width = 56, Depth = 48 },
			BellTower = { X = 0, Y = 36, Z = -300, Width = 64, Depth = 48 },
		},
		Apex = { X = 0, Y = 40, Z = -185, Width = 120, Depth = 88 },
		Paths = {
			{ "Sanctuary", "Basin" },
			{ "Basin", "WestGallery" },
			{ "Basin", "EastGallery" },
			{ "Basin", "Crossing" }, -- the Garth Causeway
			{ "WestGallery", "Crossing" },
			{ "EastGallery", "Crossing" },
			{ "WestGallery", "Dorter" },
			{ "EastGallery", "Frater" },
			{ "Crossing", "CantorsWalk" },
			{ "Crossing", "CoralWalk" },
			{ "CantorsWalk", "BellTower" },
			{ "CoralWalk", "BellTower" },
			{ "CantorsWalk", "Apex" }, -- the West Isle Stair
			{ "CoralWalk", "Apex" }, -- the East Isle Stair
			{ "CantorsWalk", "ChoirLoft" },
			{ "CoralWalk", "Scriptorium" },
			{ "CantorsWalk", "Sacristy" },
		},
		-- Twin coral-arched stair-bridges climbing onto Chapter Isle from the west and east walks.
		Stairs = { CantorsWalk_Apex = true, CoralWalk_Apex = true },
		Names = {
			Sanctuary = "Lay Gate",
			Basin = "Lay Court",
			Dorter = "The Dorter",
			WestGallery = "West Walk",
			Frater = "The Frater",
			EastGallery = "East Walk",
			Crossing = "The Lavabo",
			CantorsWalk = "Cantors' Walk",
			CoralWalk = "Coral Walk",
			ChoirLoft = "Choir Loft",
			Sacristy = "Sacristy",
			Scriptorium = "Scriptorium",
			BellTower = "Bell Tower",
			Apex = "Chapter Isle",
		},
		Terrain = {
			Direct = true,
			Surface = "NERETH",
			-- Built cloister floors on undercrofts/corbels: Lay Gate, Frater, Choir Loft and Scriptorium.
			Decks = { Sanctuary = true, Frater = true, ChoirLoft = true, Scriptorium = true },
			DeckThickness = { Frater = 3, ChoirLoft = 3, Scriptorium = 3 },
			DeckLooks = {
				Frater = { Color = Color3.fromRGB(214, 206, 186), Material = Enum.Material.Limestone },
				ChoirLoft = { Color = Color3.fromRGB(224, 218, 204), Material = Enum.Material.Marble },
				Scriptorium = { Color = Color3.fromRGB(214, 206, 186), Material = Enum.Material.Limestone },
			},
			-- Sheer coral-rock & cloister retaining walls keep >= 44 studs of open turquoise water between the
			-- Lavabo and Chapter Isle and full deep water under both Isle Stairs.
			Shapes = {
				WestGallery = { Round = 3.2, Grow = 3 },
				EastGallery = { Round = 3.2, Grow = 3 },
				Dorter = { Round = 3.0, Grow = 3 },
				Crossing = { Round = 2.2, Grow = 2, Sheer = true },
				CantorsWalk = { Round = 3.2, Grow = 2, Sheer = true },
				CoralWalk = { Round = 3.2, Grow = 2, Sheer = true },
				Sacristy = { Round = 3.0, Grow = 3 },
				BellTower = { Round = 3.2, Grow = 3 },
				Apex = { Round = 2.2, Grow = 3, Sheer = true },
			},
			Bridges = { Basin_Crossing = true, CantorsWalk_Apex = true, CoralWalk_Apex = true },
			BridgeStyles = {
				Basin_Crossing = "CAUSEWAY",
				CantorsWalk_Apex = "ARCADE",
				CoralWalk_Apex = "ARCADE",
			},
			NoApexShelf = true,
			LiquidRise = 2.0,
			FloorDip = 9,
			-- Lower coastal cliffs around the cloister so coral arcades, the Bell Tower and the Tidewall lead the view.
			WallBand = { Base = 24, Noise = 8, NorthScale = 0.22 },
			-- Two flooded squircle cloister garths (Round = 5): the south garth crossed by the Garth Causeway,
			-- and the wide north garth encircling Chapter Isle (impassable from the Lavabo).
			Pools = {
				{ X = 0, Z = 65, RX = 122, RZ = 94, Round = 5 },
				{ X = -6, Z = -182, RX = 178, RZ = 122, Round = 5 },
			},
			GroveScale = 0,
			MeadowScale = 0.06,
		},
	},
}

local function build(index: number, v: any?): any
	assert(index >= 1 and index <= 5 and index % 1 == 0)
	-- An authored floor may override its room size (Size = {Width, Depth, Height, Bottom?}); every consumer
	-- reads the built layout's Width/Depth/Height/Bottom, never the per-index tables.
	local roomSize = v and v.Size
	local w, d = (roomSize and roomSize.Width) or widths[index], (roomSize and roomSize.Depth) or depths[index]
	local platforms, links = {}, {}
	local function platform(id, x, y, z, width, depth)
		local o = v and v[id]
		if o then
			x, y, z = o.X or x, o.Y or y, o.Z or z
			width, depth = o.Width or width, o.Depth or depth
		end
		local p: any = {Id=id, X=x, Y=y, Z=z, Width=width, Depth=depth}
		platforms[id] = p
		return p
	end
	local safe = platform("Sanctuary", 0, 8, d/2-34, 128, 56)
	platform("Basin", 0, 0, d*.18, w-32, d*.22)
	platform("WestGallery", -w*.28, 8, -d*.06, 84, 76)
	platform("EastGallery", w*.28, 8, -d*.06, 84, 76)
	platform("Crossing", 0, if index >= 3 then 5 else 0, -d*.04, 72, 58)
	platform("Apex", 0, apexHeights[index], -d*.34, 100, 80)
	if index >= 4 then
		platform("WestBastion", -w*.28, 14, -d*.31, 84, 76)
		platform("EastBastion", w*.28, 14, -d*.31, 84, 76)
	end
	if v and v.ExtraPlatforms then
		for id, o in v.ExtraPlatforms do
			platform(id, o.X, o.Y, o.Z, o.Width, o.Depth)
		end
	end
	local function link(a, b)
		local p, q = platforms[a], platforms[b]
		local dx, dz = q.X-p.X, q.Z-p.Z
		local length = math.sqrt(dx*dx+dz*dz)
		local ux, uz = dx/length, dz/length
		local function edge(terrace, halfWidth)
			return math.min((terrace.Width/2+math.abs(uz)*halfWidth)/math.max(math.abs(ux),.001),
				(terrace.Depth/2+math.abs(ux)*halfWidth)/math.max(math.abs(uz),.001))
		end
		local edgeA, edgeB = edge(p,0), edge(q,0)
		local insetA, insetB = edgeA-4, edgeB-4
		-- Keep the inclined deck wholly outside the UPPER slab, including its
		-- diagonal shoulders. A flat landing bridges back into that slab.
		if p.Y > q.Y then insetA = edge(p,14)+1 end
		if q.Y > p.Y then insetB = edge(q,14)+1 end
		local run = length-insetA-insetB
		local extra = math.max(0,math.abs(q.Y-p.Y)/math.tan(math.rad(15))+1-run)
		-- The lower end can overlap its slab without creating a raised lip:
		-- the deck approaches that slab from above. Extend there on short links.
		if p.Y>q.Y then insetB-=extra else insetA-=extra end
		run=length-insetA-insetB
		assert(math.abs(q.Y-p.Y)/run <= math.tan(math.rad(15)), a.." ramp too steep")
		local connector = {From=a, To=b, AX=p.X+ux*insetA, AZ=p.Z+uz*insetA, AY=p.Y,
			BX=q.X-ux*insetB, BZ=q.Z-uz*insetB, BY=q.Y, Width=28}
		landings(connector,ux,uz,math.max(20,2*math.abs(insetA-edgeA)+12),math.max(20,2*math.abs(insetB-edgeB)+12))
		-- An authored floor can make any of its paths a staircase (Stairs = {[linkId] = true}).
		if v and v.Stairs and v.Stairs[connector.Id] then
			connector.Kind = "STAIRS"
		end
		table.insert(links, connector)
	end
	-- A path from a to b; on a varied floor it may wind through a bend terrace beside the straight line
	-- (two connectors, a -> Bend_a_b -> b). Bend terraces carry Bend = true and hold no camp.
	local function route(a, b)
		local bend = v and v.Bends and v.Bends[a.."_"..b]
		if not bend then
			link(a, b)
			return
		end
		local p, q = platforms[a], platforms[b]
		local dx, dz = q.X-p.X, q.Z-p.Z
		local length = math.sqrt(dx*dx+dz*dz)
		local nx, nz = -dz/length, dx/length
		local mx, mz = p.X+dx*bend.Along, p.Z+dz*bend.Along
		-- Pull OUT: away from the room's centre line; BACK: toward the back wall (-Z).
		local flip = if bend.Pull == "BACK" then nz > 0 else nx*mx < 0
		if flip then nx, nz = -nx, -nz end
		local id = "Bend_"..a.."_"..b
		platforms[id] = {Id=id, X=mx+nx*bend.Offset, Y=math.round((p.Y+q.Y)/2),
			Z=mz+nz*bend.Offset, Width=bend.Width, Depth=bend.Depth, Bend=true}
		link(a, id); link(id, b)
	end
	if v and v.Paths then
		for _, path in v.Paths do route(path[1], path[2]) end
	else
		link("Sanctuary", "Basin")
		route("Basin", "WestGallery"); route("Basin", "EastGallery"); link("Basin", "Crossing")
		link("Crossing", "Apex")
		if index >= 4 then
			link("WestGallery", "WestBastion"); link("EastGallery", "EastBastion")
			route("WestBastion", "Apex"); route("EastBastion", "Apex")
		else
			route("WestGallery", "Apex"); route("EastGallery", "Apex")
		end
	end
	if v and v.Names then
		for id, name in v.Names do
			if platforms[id] then platforms[id].Name = name end
		end
	end
	local camps = {}
	local function camp(id, terrace, dx, elite, boss, size)
		local p = platforms[terrace]
		-- Radius: members scatter this far from the centre (CampRoster), staying 6 studs inside the terrace.
		table.insert(camps, {Id=id, Platform=terrace, X=p.X+(dx or 0), Y=p.Y, Z=p.Z,
			Elite=elite or false, Boss=boss or false, Size=size or 4,
			Radius=math.min(20, p.Width/2-math.abs(dx or 0)-6, p.Depth/2-6)})
	end
	-- Live camps per floor: 16 / 22 / 25 / 35 / 35 mobs, led by 1 / 2 / 3 / 4 / 4 Elites. The Basin
	-- centre stays clear so arrivals land out of aggro. The Apex camp is never pre-placed: it marks
	-- where the floor champion (or Biome Boss) is summoned.
	local size = if index == 1 then 4 else 5
	camp("BASIN_WEST", "Basin", -110, false, false, if index == 2 then 4 else size)
	camp("BASIN_EAST", "Basin", 110, false, false, if index == 2 then 4 else size)
	if index >= 2 then camp("CENTRAL_CROSSING", "Crossing", 0, index == 3, false, if index == 2 then 4 else 5) end
	camp("WEST_GALLERY", "WestGallery", 0, true, false, size)
	camp("EAST_GALLERY", "EastGallery", 0, index >= 2, false, size)
	if index >= 4 then
		camp("UPPER_WEST", "WestBastion", 0, true, false, 5)
		camp("UPPER_EAST", "EastBastion", 0, true, false, 5)
	end
	if index == 5 then camp("APEX_SANCTUM", "Apex", 0, false, true, 5) else camp("APEX_SANCTUM", "Apex", 0, true) end
	-- Live Elites per floor (1 / 2 / 3 / 4 / 4). The runtime decides which areas they lead (CampRoster).
	local eliteCount = 0
	for _, c in camps do
		if c.Elite and c.Id ~= "APEX_SANCTUM" then eliteCount += 1 end
	end
	local bottom = if roomSize and roomSize.Bottom then roomSize.Bottom elseif index==5 then -6 elseif index>=3 then -4 else 0
	local returns = {}
	if bottom < 0 then
		local basin = platforms.Basin
		for _, side in {-1,1} do
			local x, z = side*w*.37, basin.Z-basin.Depth/2
			local connector = {From=if side<0 then "ChasmWest" else "ChasmEast",To="Basin",
				AX=x,AY=bottom-4,AZ=z-44,BX=x,BY=0,BZ=z-1,Width=32}
			landings(connector,0,1,20,20)
			table.insert(returns,connector)
		end
	end
	return {Width=w, Depth=d, Height=(roomSize and roomSize.Height) or heights[index], Bottom=bottom, ReturnLinks=returns,
		Platforms=platforms, Links=links, Camps=camps, Sanctuary=safe, EliteCount=eliteCount, Index=index,
		Varied=v ~= nil, Authored=v and v.Key or nil, Name=v and v.Name or nil, PathStyle=v and v.PathStyle or nil,
		DirectTerrain=v ~= nil and v.DirectTerrain == true,
		Decks=v and v.Decks or nil,
		Suspended=v and v.Suspended or nil,
		Masonry=v and v.Masonry or nil,
		SunMedallions=v ~= nil and v.SunMedallions == true,
		Liquid=v and v.Liquid or nil,
		TerrainFeatures=v and v.TerrainFeatures or nil,
		Patrols=v and v.Patrols or nil,
		ReplacePatrols=v ~= nil and v.ReplacePatrols == true, Surface=v and v.Surface or nil,
		Terrain=v and v.Terrain or nil, Skylight=v and v.Skylight or nil, Portals=v and v.Portals or nil,
		GirderSpans=v and v.GirderSpans or nil, StonePiers=v and v.StonePiers or nil, Viaducts=v and v.Viaducts or nil,
		Fords=v and v.Fords or nil, BrokenFlight=v and v.BrokenFlight or nil}
end

-- Problems with a layout (empty when it is sound): terraces overlapping or leaving the room's inner area,
-- connectors running over a terrace they do not join, connectors crossing, cramped camps.
function Layout.Validate(room: any): {string}
	local problems = {}
	local margin = 30
	local list = {}
	for id, p in room.Platforms do table.insert(list, p) end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	for i, p in list do
		local fixed = p.Id == "Sanctuary" or p.Id == "Basin" -- full-width, never varied
		if not fixed and (math.abs(p.X)+p.Width/2 > room.Width/2-margin or math.abs(p.Z)+p.Depth/2 > room.Depth/2-12) then
			table.insert(problems, p.Id.." leaves the room")
		end
		for j = i+1, #list do
			local q = list[j]
			if math.abs(p.X-q.X) < (p.Width+q.Width)/2+10 and math.abs(p.Z-q.Z) < (p.Depth+q.Depth)/2+10 then
				table.insert(problems, p.Id.." crowds "..q.Id)
			end
		end
	end
	local connectors = table.clone(room.Links)
	for _, link in room.ReturnLinks do table.insert(connectors, link) end
	local function inside(p: any, x: number, z: number, pad: number): boolean
		return math.abs(x-p.X) < p.Width/2+pad and math.abs(z-p.Z) < p.Depth/2+pad
	end
	for _, link in connectors do
		local dx, dz = link.BX-link.AX, link.BZ-link.AZ
		local length = math.sqrt(dx*dx+dz*dz)
		local nx, nz = -dz/length, dx/length
		for _, p in list do
			local hit = false
			if p.Id ~= link.From and p.Id ~= link.To then
				for step = 0, 20 do
					for _, side in {-1, 0, 1} do
						local x = link.AX+dx*step/20+nx*side*link.Width/2
						local z = link.AZ+dz*step/20+nz*side*link.Width/2
						if inside(p, x, z, 1) then hit = true end
					end
				end
			end
			if hit then table.insert(problems, link.Id.." runs over "..p.Id) end
		end
	end
	-- Connectors must not cross: away from a shared terrace, centrelines stay a deck width apart.
	local function sample(link: any, t: number): (number, number)
		return link.AX+(link.BX-link.AX)*t, link.AZ+(link.BZ-link.AZ)*t
	end
	for i, a in connectors do
		for j = i+1, #connectors do
			local b = connectors[j]
			local shared = a.From == b.From or a.From == b.To or a.To == b.From or a.To == b.To
			local clear = (a.Width+b.Width)/2+6
			local closest = math.huge
			for s = 0, 16 do
				for u = 0, 16 do
					local ta, tb = s/16, u/16
					local ax, az = sample(a, ta)
					local bx, bz = sample(b, tb)
					closest = math.min(closest, math.sqrt((ax-bx)^2+(az-bz)^2))
				end
			end
			if not shared and closest < clear then
				table.insert(problems, a.Id.." crosses "..b.Id)
			end
		end
	end
	for _, camp in room.Camps do
		if camp.Radius < 10 then table.insert(problems, camp.Id.." is cramped") end
	end
	return problems
end

local variantAttempt: {[number]: number} = {}

-- The layout for a floor. With a floor id it is that floor's own variation of the canonical layout for
-- `index` (= (floorId - 1) % 5 + 1); without one it is the canonical layout (specs, tools).
function Layout.Get(index: number, floorId: number?): any
	if not floorId then
		return build(index)
	end
	-- Hand-authored floors are fixed, not seeded. Floor 1 is also the onboarding floor: the guide only
	-- points at the floor boss wherever it stands, so it needs no particular shape, only a fixed one.
	local authored = AUTHORED[floorId]
	if authored then
		return build(index, authored)
	end
	local allowed = {}
	local known = variantAttempt[floorId]
	if known == 0 then
		return build(index)
	end
	-- A variation may keep the canonical layout's own quirks (the chasm return ramps' feet tuck beside the
	-- galleries on floors 3-4 of a biome), but must add no new problem.
	for _, problem in Layout.Validate(build(index)) do allowed[problem] = true end
	local function attemptAt(attempt: number): any?
		local v = variation(index, floorId, attempt)
		-- A bend that does not fit is dropped on its own; the rest of the variation can still stand.
		for _ = 1, 3 do
			local ok, room = pcall(build, index, v)
			local fresh = {}
			if ok then
				for _, problem in Layout.Validate(room) do
					if not allowed[problem] then table.insert(fresh, problem) end
				end
				if #fresh == 0 then return room end
			end
			local dropped = false
			for key in v.Bends do
				local id = "Bend_"..key
				local blamed = not ok
				for _, problem in fresh do
					if string.find(problem, id, 1, true) then blamed = true end
				end
				if blamed then v.Bends[key] = nil; dropped = true end
			end
			if not dropped then return nil end
		end
		return nil
	end
	if known then
		return attemptAt(known) or build(index)
	end
	for attempt = 1, VARIANT_ATTEMPTS do
		local room = attemptAt(attempt)
		if room then
			variantAttempt[floorId] = attempt
			return room
		end
	end
	variantAttempt[floorId] = 0
	return build(index)
end

-- The floor's own layout (Layout.Get with the floor's index in its biome).
function Layout.ForFloor(floorId: number): any
	return Layout.Get((floorId-1)%5+1, floorId)
end

-- Walkways that must stay clear of scenery: every ramp and stair (with a 3-stud shoulder), a 20 x 20
-- landing pad at each end of every link, the Basin causeway and the Sanctuary exit. Each lane is a box
-- from A to B (local floor coordinates, Y = walking surface) that is HalfWidth to each side and spans
-- Below studs under the surface to Above studs over it. Plain numbers, so specs can read it directly.
-- Patrol routes (Phase E): walkable waypoint paths (local coordinates, Y = walking surface) that a
-- patrol walks back and forth. They follow terraces and link centrelines, never use the Sanctuary link
-- and keep to the back half of the Basin, away from the arrival ramp.
--   BASIN_LOOP     every floor: Basin west -> foot of the Crossing ramp -> Basin east
--   GALLERY_WEST/EAST  floor 3 on: Gallery centre -> along its link -> Apex (floor 3) or Bastion (4-5)
--   BASTION_RING   floors 4-5: West Bastion -> Apex edge -> East Bastion
-- On a floor whose path winds through a bend terrace, routes follow both connectors of the path.
function Layout.PatrolRoutes(index: number, floorId: number?): {[string]: {{X: number, Y: number, Z: number}}}
	local room = Layout.Get(index, floorId)
	local p = room.Platforms
	local function point(x, y, z) return {X=x, Y=y, Z=z} end
	local function find(from, to)
		for _, link in room.Links do
			if link.From == from and link.To == to then return link end
		end
		return nil
	end
	-- The connectors of the path from -> to, in order (one, or two through Bend_from_to).
	local function pathBetween(from, to): {any}?
		local direct = find(from, to)
		if direct then return {direct} end
		local bend = "Bend_"..from.."_"..to
		local a, b = find(from, bend), find(bend, to)
		return if a and b then {a, b} else nil
	end
	local basin = p.Basin
	local backZ = basin.Z - basin.Depth*0.3
	local routes = {
		BASIN_LOOP = {
			point(-room.Width*0.22, basin.Y, backZ),
			point(0, basin.Y, basin.Z - basin.Depth*0.4),
			point(room.Width*0.22, basin.Y, backZ),
		},
	}
	local replaceGeneric = room.ReplacePatrols == true
	if index >= 3 and not replaceGeneric then
		for _, side in {"West", "East"} do
			local gallery = p[side.."Gallery"]
			local route = {point(gallery.X, gallery.Y, gallery.Z)}
			-- A hand-authored floor's gallery may have no path up (floor 8's Violet Cap only reaches the
			-- aqueduct): its patrol walks the path it has to the Crossing instead.
			local path = pathBetween(side.."Gallery", if index >= 4 then side.."Bastion" else "Apex")
				or (if room.Authored then pathBetween(side.."Gallery", "Crossing") else nil)
			if path then
				for _, link in path do
					table.insert(route, point(link.AX, link.AY, link.AZ))
					table.insert(route, point(link.BX, link.BY, link.BZ))
				end
				routes["GALLERY_"..string.upper(side)] = route
			else
				assert(room.Authored, side.." gallery has no path up")
			end
		end
	end
	if index >= 4 and not replaceGeneric then
		-- An authored floor's bastions may meet at the Crossing instead of climbing straight to the Apex
		-- (Floor 9's "H" with The Keystone): its bastion ring crosses the Crossing between them.
		local west = pathBetween("WestBastion", "Apex")
			or (if room.Authored then pathBetween("WestBastion", "Crossing") else nil)
		local east = pathBetween("EastBastion", "Apex")
			or (if room.Authored then pathBetween("EastBastion", "Crossing") else nil)
		assert(west and east, "bastion ring has no path across")
		local ring = {point(p.WestBastion.X, p.WestBastion.Y, p.WestBastion.Z)}
		for _, link in west do
			table.insert(ring, point(link.AX, link.AY, link.AZ))
			table.insert(ring, point(link.BX, link.BY, link.BZ))
		end
		for i = #east, 1, -1 do
			local link = east[i]
			table.insert(ring, point(link.BX, link.BY, link.BZ))
			table.insert(ring, point(link.AX, link.AY, link.AZ))
		end
		table.insert(ring, point(p.EastBastion.X, p.EastBastion.Y, p.EastBastion.Z))
		routes.BASTION_RING = ring
	end
	if room.Patrols then
		for routeName, stops in room.Patrols do
			if #stops >= 2 and p[stops[1]] then
				local first = p[stops[1]]
				local route = { point(first.X, first.Y, first.Z) }
				local ok = true
				for i = 1, #stops - 1 do
					local fromId, toId = stops[i], stops[i + 1]
					local toPlat = p[toId]
					if not toPlat then
						ok = false
						break
					end
					local seg = pathBetween(fromId, toId)
					if seg then
						for _, link in seg do
							table.insert(route, point(link.AX, link.AY, link.AZ))
							table.insert(route, point(link.BX, link.BY, link.BZ))
						end
					else
						local rev = pathBetween(toId, fromId)
						if not rev then
							ok = false
							break
						end
						for j = #rev, 1, -1 do
							local link = rev[j]
							table.insert(route, point(link.BX, link.BY, link.BZ))
							table.insert(route, point(link.AX, link.AY, link.AZ))
						end
					end
					table.insert(route, point(toPlat.X, toPlat.Y, toPlat.Z))
				end
				if ok then
					routes[routeName] = route
				end
			end
		end
	end
	return routes
end

function Layout.Lanes(index: number, floorId: number?): {any}
	local room = Layout.Get(index, floorId)
	local lanes = {}
	local function lane(id, ax, ay, az, bx, by, bz, halfWidth)
		table.insert(lanes, {Id=id, AX=ax, AY=ay, AZ=az, BX=bx, BY=by, BZ=bz, HalfWidth=halfWidth, Below=2, Above=14})
	end
	local connectors = table.clone(room.Links)
	for _, link in room.ReturnLinks do table.insert(connectors,link) end
	for _, link in connectors do
		local dx, dz = link.BX-link.AX, link.BZ-link.AZ
		local length = math.sqrt(dx*dx+dz*dz)
		local ux, uz = dx/length, dz/length
		lane(link.From.."_"..link.To, link.AX, link.AY, link.AZ, link.BX, link.BY, link.BZ, link.Width/2+3)
		for _, name in {"LandingA","LandingB"} do
			local pad = link[name]
			lane(link.Id.."_"..name,pad.AX,pad.AY,pad.AZ,pad.BX,pad.BY,pad.BZ,pad.Width/2+3)
		end
	end
	local basin, safe = room.Platforms.Basin, room.Sanctuary
	lane("BasinCauseway", 0, basin.Y, basin.Z+basin.Depth/2, 0, basin.Y, basin.Z-basin.Depth/2, 20)
	lane("SanctuaryExit", 0, safe.Y, safe.Z-12, 0, safe.Y, safe.Z-safe.Depth/2, 18)
	-- The boss portals' spots (Phase H) are kept clear the same way.
	for id, spot in Layout.PortalSpots(index, floorId) do
		lane("Portal"..id, spot.X, spot.Y, spot.Z-5, spot.X, spot.Y, spot.Z+5, 10)
	end
	return lanes
end

-- Where the boss portals rise when a floor's boss falls (Phase H): side by side at the back of the
-- Apex terrace, facing the arena. Ascend leads up (or home from floor 50); Rerun replays the floor.
function Layout.PortalSpots(index: number, floorId: number?): {[string]: {X: number, Y: number, Z: number}}
	local room = Layout.Get(index, floorId)
	local apex = room.Platforms.Apex
	-- An authored floor can put them on the Apex's south side (its paths arrive from the north) and spread them.
	local south = room.Portals and room.Portals.Side == "SOUTH"
	local spread = (room.Portals and room.Portals.Spread) or 16
	local z = if south then apex.Z + apex.Depth/2 - 12 else apex.Z - apex.Depth/2 + 12
	return {
		Ascend = {X=apex.X+spread, Y=apex.Y, Z=z},
		Rerun = {X=apex.X-spread, Y=apex.Y, Z=z},
	}
end

function Layout.Placements(biome: any, index: number, floorId: number?): {any}
	local result = {}
	for _, camp in Layout.Get(index, floorId).Camps do
		for slot=1,camp.Size do
			local enemy = biome.RegularEnemyIds[if slot%2==0 then 2 else 1]
			if camp.Boss and slot==1 then enemy=biome.BossEnemyId
			elseif camp.Boss and slot<=3 then enemy=biome.EliteEnemyId
			elseif camp.Elite and slot==1 then enemy=if camp.Id=="APEX_SANCTUM" then biome.AlphaEnemyId else biome.EliteEnemyId end
			local offsets = {{0,0},{-18,12},{18,12},{-12,-16},{12,-16}}
			table.insert(result, {EnemyId=enemy, X=camp.X+offsets[slot][1], Y=camp.Y, Z=camp.Z+offsets[slot][2],
				CampId="CAMP_"..camp.Id, LeashRadius=if camp.Boss then 95 else 60})
		end
	end
	return result
end
return table.freeze(Layout)
