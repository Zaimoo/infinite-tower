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
			WestGallery = true,
			EastGallery = true,
			WestBastion = true,
			EastBastion = true,
			Apex = true,
		},
		Suspended = {
			Platforms = { Crossing = true, WestGallery = true, EastGallery = true, WestBastion = true, EastBastion = true, Apex = true },
			Links = {
				Basin_Crossing = true,
				Crossing_WestGallery = true,
				Crossing_EastGallery = true,
				WestGallery_EastGallery = true,
				WestGallery_WestBastion = true,
				EastGallery_EastBastion = true,
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
}

local function build(index: number, v: any?): any
	assert(index >= 1 and index <= 5 and index % 1 == 0)
	local w, d = widths[index], depths[index]
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
	local bottom = if index==5 then -6 elseif index>=3 then -4 else 0
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
	return {Width=w, Depth=d, Height=heights[index], Bottom=bottom, ReturnLinks=returns,
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
		ReplacePatrols=v ~= nil and v.ReplacePatrols == true}
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
			for _, link in assert(pathBetween(side.."Gallery", if index >= 4 then side.."Bastion" else "Apex")) do
				table.insert(route, point(link.AX, link.AY, link.AZ))
				table.insert(route, point(link.BX, link.BY, link.BZ))
			end
			routes["GALLERY_"..string.upper(side)] = route
		end
	end
	if index >= 4 and not replaceGeneric then
		local west, east = assert(pathBetween("WestBastion", "Apex")), assert(pathBetween("EastBastion", "Apex"))
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
	local apex = Layout.Get(index, floorId).Platforms.Apex
	local z = apex.Z - apex.Depth/2 + 12
	return {
		Ascend = {X=apex.X+16, Y=apex.Y, Z=z},
		Rerun = {X=apex.X-16, Y=apex.Y, Z=z},
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
