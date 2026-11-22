--!strict
-- TowerBiomeKit.luau
-- The sculpted environment kit for the tower floors (GDD §3.3), modelled in Blender by
-- tools/blender/generate_tower_biome_kit.py (assets-source/tower/biome_kit/TowerBiomeKit.fbx).
--
-- Each template is a Model of MeshParts in ServerStorage.TowerBiomeKit, one MeshPart per colour role
-- (the part's Role attribute), so one mesh serves every biome: TowerKitProps tints and textures each role
-- from the floor's theme and the biome palette below. tests/studio-tower-biome-kit-import.luau files an
-- imported FBX into that folder. Until the folder exists, TowerBiomeAssets builds the old part-made props.
--
-- Size and Min are the template's bounds in studs at scale 1, in Roblox axes (Y up), measured from the
-- template's origin: the centre of its footprint on the ground. The front of a template faces +Z.

local TowerBiomeKit = {}

export type Role =
	"STONE" | "TRIM" | "ACCENT" | "MOSS" | "GLOW" | "WOOD" | "FOLIAGE" | "METAL" | "GOLD"
	| "CRYSTAL" | "CAP" | "STEM" | "ALT" | "CORAL" | "BULB" | "CANDLE" | "SILK"

export type Template = {
	Size: Vector3,
	Min: Vector3,
	Roles: { string },
}

export type Swatch = {
	Color: Color3,
	Material: Enum.Material,
	Transparency: number?,
}

export type BiomeKit = {
	-- Template for tree(): the ruin tree, the blighted tree or the dead tree.
	Tree: string,
	-- Template for non-crystal spire() (obelisk, furnace stack, obsidian shard).
	Spire: string,
	-- Extra conifer beside landmarks (nil: none).
	Pine: string?,
	-- Clutter beds, picked in order by the bed's variant seed.
	Clutter: { string },
	-- Per-role colours and materials; roles left out fall back to the floor theme (TowerKitProps).
	Palette: { [string]: Swatch },
}

-- Where the imported templates live (not managed by Rojo).
TowerBiomeKit.FolderName = "TowerBiomeKit"

TowerBiomeKit.Templates = table.freeze({
	ArchCrown = table.freeze({ Size = Vector3.new(32.0, 18.185, 8.45), Min = Vector3.new(-16.0, 0.0, -4.225), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM" }) }),
	ArchPierBase = table.freeze({ Size = Vector3.new(8.6, 3.5, 8.6), Min = Vector3.new(-4.3, 0.0, -4.3), Roles = table.freeze({ "TRIM" }) }),
	ArchPierSegment = table.freeze({ Size = Vector3.new(6.523, 4.421, 6.851), Min = Vector3.new(-3.287, -0.011, -3.335), Roles = table.freeze({ "MOSS", "TRIM" }) }),
	BanyanTree = table.freeze({ Size = Vector3.new(80.859, 68.753, 71.91), Min = Vector3.new(-42.614, -1.4, -38.335), Roles = table.freeze({ "FOLIAGE", "WOOD" }) }),
	BlightPod = table.freeze({ Size = Vector3.new(9.075, 5.173, 10.611), Min = Vector3.new(-3.02, -0.3, -5.136), Roles = table.freeze({ "CAP", "GLOW", "STONE", "WOOD" }) }),
	BlightTree = table.freeze({ Size = Vector3.new(56.146, 45.125, 47.08), Min = Vector3.new(-29.309, -2.414, -21.373), Roles = table.freeze({ "FOLIAGE", "GLOW", "WOOD" }) }),
	BoulderCluster = table.freeze({ Size = Vector3.new(10.059, 3.494, 7.165), Min = Vector3.new(-4.226, 0.0, -3.676), Roles = table.freeze({ "STONE" }) }),
	Cairn = table.freeze({ Size = Vector3.new(8.479, 4.503, 7.927), Min = Vector3.new(-4.349, -0.45, -3.259), Roles = table.freeze({ "FOLIAGE", "TRIM" }) }),
	ChasmIsland = table.freeze({ Size = Vector3.new(40.821, 40.129, 40.914), Min = Vector3.new(-20.152, -0.856, -20.002), Roles = table.freeze({ "MOSS", "STONE" }) }),
	CliffRockA = table.freeze({ Size = Vector3.new(47.003, 73.149, 38.623), Min = Vector3.new(-23.442, -0.919, -19.32), Roles = table.freeze({ "MOSS", "STONE" }) }),
	CliffRockB = table.freeze({ Size = Vector3.new(45.858, 75.719, 36.945), Min = Vector3.new(-24.268, -0.87, -19.091), Roles = table.freeze({ "MOSS", "STONE" }) }),
	CoralCluster = table.freeze({ Size = Vector3.new(10.394, 6.905, 7.994), Min = Vector3.new(-4.846, -0.5, -3.886), Roles = table.freeze({ "CORAL", "GLOW", "STONE" }) }),
	CrystalSpire = table.freeze({ Size = Vector3.new(22.31, 44.5, 17.66), Min = Vector3.new(-12.114, 0.0, -8.802), Roles = table.freeze({ "CRYSTAL", "STONE" }) }),
	DeadTree = table.freeze({ Size = Vector3.new(18.096, 36.91, 24.261), Min = Vector3.new(-9.578, -1.06, -13.055), Roles = table.freeze({ "WOOD" }) }),
	FoliageBush = table.freeze({ Size = Vector3.new(9.111, 5.269, 8.202), Min = Vector3.new(-4.072, -0.209, -4.072), Roles = table.freeze({ "ALT", "FOLIAGE", "STONE" }) }),
	ForgeScrap = table.freeze({ Size = Vector3.new(12.028, 6.187, 7.409), Min = Vector3.new(-6.598, -1.694, -3.408), Roles = table.freeze({ "GOLD", "METAL", "STONE" }) }),
	FurnaceStack = table.freeze({ Size = Vector3.new(20.0, 54.7, 20.0), Min = Vector3.new(-10.0, 0.0, -10.0), Roles = table.freeze({ "GLOW", "METAL", "STONE" }) }),
	GiantMushroom = table.freeze({ Size = Vector3.new(48.356, 46.068, 48.212), Min = Vector3.new(-20.018, -1.287, -24.05), Roles = table.freeze({ "CAP", "GLOW", "STEM" }) }),
	IceCluster = table.freeze({ Size = Vector3.new(7.04, 8.193, 5.891), Min = Vector3.new(-3.129, -0.5, -2.953), Roles = table.freeze({ "CRYSTAL", "MOSS" }) }),
	LionGuardian = table.freeze({ Size = Vector3.new(22.0, 32.735, 27.527), Min = Vector3.new(-11.0, 0.0, -15.458), Roles = table.freeze({ "ACCENT", "GLOW", "TRIM" }) }),
	MushroomCluster = table.freeze({ Size = Vector3.new(9.552, 8.019, 8.544), Min = Vector3.new(-3.756, -0.4, -4.383), Roles = table.freeze({ "CAP", "GLOW", "MOSS", "STEM" }) }),
	Obelisk = table.freeze({ Size = Vector3.new(16.0, 57.0, 16.0), Min = Vector3.new(-8.0, 0.0, -8.0), Roles = table.freeze({ "GLOW", "GOLD", "TRIM" }) }),
	ObsidianSpire = table.freeze({ Size = Vector3.new(23.344, 60.0, 18.942), Min = Vector3.new(-11.819, 0.0, -9.079), Roles = table.freeze({ "GLOW", "STONE" }) }),
	PineTree = table.freeze({ Size = Vector3.new(28.865, 45.179, 28.145), Min = Vector3.new(-14.442, -0.8, -13.5), Roles = table.freeze({ "FOLIAGE", "MOSS", "WOOD" }) }),
	RobedStatueStaff = table.freeze({ Size = Vector3.new(25.281, 62.988, 20.0), Min = Vector3.new(-10.236, 0.0, -10.0), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "TRIM" }) }),
	RobedStatueTrident = table.freeze({ Size = Vector3.new(24.912, 64.18, 20.0), Min = Vector3.new(-10.236, 0.0, -10.0), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "TRIM" }) }),
	RuinRubble = table.freeze({ Size = Vector3.new(9.571, 4.812, 9.462), Min = Vector3.new(-4.531, -0.412, -3.848), Roles = table.freeze({ "MOSS", "TRIM" }) }),
	StoneUrn = table.freeze({ Size = Vector3.new(5.4, 7.015, 5.4), Min = Vector3.new(-2.7, 0.0, -2.7), Roles = table.freeze({ "ACCENT", "FOLIAGE", "TRIM" }) }),
	TomeStack = table.freeze({ Size = Vector3.new(6.986, 3.8, 3.545), Min = Vector3.new(-1.919, 0.0, -1.752), Roles = table.freeze({ "ACCENT", "ALT", "GOLD", "TRIM" }) }),
	VoidShards = table.freeze({ Size = Vector3.new(5.725, 8.16, 4.6), Min = Vector3.new(-2.3, 0.0, -2.3), Roles = table.freeze({ "GLOW", "STONE", "TRIM" }) }),
}) :: { [string]: Template }

-- Floor-specific sculpted templates (optional until imported into ServerStorage.TowerBiomeKit; callers
-- check TowerKitProps.Has(name) and fall back to native parts until the FBX is imported).
-- Kits and the floors they dress:
--   fungal_f6_kit (tools/blender/generate_fungal_f6_kit.py): Floor 6, Sporelit Entry.
--   fungal_f7_kit (tools/blender/generate_fungal_f7_kit.py): Floor 7, Mycelium Galleries (LampNiche, MyceliumNet).
--   fungal_f8_kit (tools/blender/generate_fungal_f8_kit.py): Floor 8, Blooming Chasm, the Lampkeepers' camp kit
--     (CapShelter, CampSupplies, CrystalBrazier, Barricade, ChalkSign).
--   fungal_f9_kit (tools/blender/generate_fungal_f9_kit.py): Floor 9, Rotcap Keep (BrokenBarricade, RotVat,
--     OssuaryBones, RotcapTower, VelmariBanner, RotcapCluster, RotMyceliumWeb).
--   fungal_f10_kit (tools/blender/generate_fungal_f10_kit.py): Floor 10, Matriarch's Hollow (WebbedArchway,
--     SilkSpire, BroodEggClutch, StolenLampCocoon, SilkWindlass, LastLampShrine, SilkWebCurtain).
--   fungal_f10_nest_kit (tools/blender/generate_fungal_f10_nest_kit.py): Floor 10's dais and brood pieces
--     (ShroudSpire, EggRack, SilkSpool, SilkDrape, CocoonLamp), adding the SILK role.
--   infernal_f21_kit (tools/blender/generate_infernal_f21_kit.py): Floor 21, Slagworks Entry (OreCrusherJaw,
--     CoalHopper, OreCart, TankLocomotive, SignalCabin, FurnaceGateDoors, WaterTower, RailBuffer, FlueStack,
--     ScrapHeap, CoalHeap, SignalLamp).
--   infernal_f22_kit (tools/blender/generate_infernal_f22_kit.py): Floor 22, Molten Assembly (ConstructShell,
--     AssemblyScaffold, ChainHoist, CraneTrolley, QuenchTank, PatternRack, ControlCabin, FurnaceBox, WallGear,
--     ConveyorRollers, PartsRack, HydraulicJack).
--   infernal_f23_kit (tools/blender/generate_infernal_f23_kit.py): Floor 23, Furnace Causeway (FurnaceTower,
--     TiltingCrucible, MouldBed, CoolingRack, BladeDisplay, FurnaceDoorGiant, SlagLadleCart, JibCrane,
--     BellowsDuctRun, CrustIsland, SteamVent).
--   infernal_f24_kit (tools/blender/generate_infernal_f24_kit.py): Floor 24, Ironflame Bulwark (BulwarkWall,
--     SluiceTower, SluiceGateChain, SlagCannon, SignalBrazier, DropHammer, PowderKegStack, FlameJetPortcullis,
--     ChainWinch, SiegeBallista, ArmourRack, CitadelDoors).
--   infernal_f25_kit (tools/blender/generate_infernal_f25_kit.py): Floor 25, Titan's Crucible (GreatCrucible,
--     TitanHeartGrate, GreatBellows, TitanMouldFist, TitanMouldHelm, HangingChainRun, PourSpoutChute,
--     DuctManifold, IngotPallet, PatternLathe, VaultRibArch, ChainGalleryRail).
--   thunder_f26_kit (tools/blender/generate_thunder_f26_kit.py): Floor 26, Stormgrass Rise (ForkedBoltTotem,
--     SplitGraniteTor, HighlandWindmill, RuneStandingStone, ShepherdCroft, DryStoneWall, RamHurdleFence,
--     TrailCairnTall, WindBentPine, StormgrassTuft, DolmenBellGate, HighlandSheep, WaterfallRibbon,
--     PrayerFlagLine, StormCrystalSpikes).
TowerBiomeKit.ExtraTemplates = table.freeze({
	AqueductBrokenSpan = table.freeze({ Size = Vector3.new(23.055, 19.059, 16.419), Min = Vector3.new(-11.167, -0.284, -7.26), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM", "WOOD" }) }),
	ArmourRack = table.freeze({ Size = Vector3.new(7.9, 8.8, 3.2), Min = Vector3.new(-3.95, 0.0, -1.6), Roles = table.freeze({ "GOLD", "METAL", "TRIM", "WOOD" }) }),
	AshmarketStall = table.freeze({ Size = Vector3.new(14.8, 11.676, 9.0), Min = Vector3.new(-7.4, -0.05, -4.5), Roles = table.freeze({ "ALT", "FOLIAGE", "STONE", "TRIM", "WOOD" }) }),
	AssemblyScaffold = table.freeze({ Size = Vector3.new(19.3, 30.963, 15.2), Min = Vector3.new(-9.6, 0.0, -7.6), Roles = table.freeze({ "METAL", "TRIM", "WOOD" }) }),
	BarracksBlock = table.freeze({ Size = Vector3.new(35.847, 29.25, 24.85), Min = Vector3.new(-17.923, -1.2, -12.2), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE", "TRIM", "WOOD" }) }),
	Barricade = table.freeze({ Size = Vector3.new(14.898, 6.059, 3.619), Min = Vector3.new(-7.21, -0.328, -2.012), Roles = table.freeze({ "MOSS", "STEM", "TRIM", "WOOD" }) }),
	BellowsDuctRun = table.freeze({ Size = Vector3.new(8.0, 27.767, 27.56), Min = Vector3.new(-4.0, 0.0, -8.0), Roles = table.freeze({ "ACCENT", "METAL", "TRIM" }) }),
	BladeDisplay = table.freeze({ Size = Vector3.new(8.5, 8.9, 2.6), Min = Vector3.new(-4.1, 0.0, -1.3), Roles = table.freeze({ "GOLD", "METAL", "TRIM", "WOOD" }) }),
	BrokenBarricade = table.freeze({ Size = Vector3.new(16.205, 5.624, 5.312), Min = Vector3.new(-7.655, -0.294, -2.311), Roles = table.freeze({ "BULB", "CAP", "GLOW", "MOSS", "STEM", "TRIM", "WOOD" }) }),
	BroodEggClutch = table.freeze({ Size = Vector3.new(9.326, 4.552, 8.179), Min = Vector3.new(-4.788, 0.188, -4.065), Roles = table.freeze({ "BULB", "CAP", "GLOW", "MOSS", "STEM" }) }),
	BulwarkWall = table.freeze({ Size = Vector3.new(24.4, 12.875, 6.3), Min = Vector3.new(-12.2, 0.0, -3.15), Roles = table.freeze({ "GOLD", "METAL", "STONE", "TRIM" }) }),
	BuriedWagon = table.freeze({ Size = Vector3.new(16.375, 12.662, 18.778), Min = Vector3.new(-6.98, -0.387, -10.084), Roles = table.freeze({ "FOLIAGE", "METAL", "MOSS", "WOOD" }) }),
	CalderaDragonCorpse = table.freeze({ Size = Vector3.new(67.43, 23.026, 67.985), Min = Vector3.new(-35.215, -0.84, -28.518), Roles = table.freeze({ "GLOW", "STONE", "TRIM" }) }),
	CampSupplies = table.freeze({ Size = Vector3.new(8.399, 2.45, 5.42), Min = Vector3.new(-4.014, -0.25, -2.899), Roles = table.freeze({ "FOLIAGE", "MOSS", "TRIM", "WOOD" }) }),
	CandleAltar = table.freeze({ Size = Vector3.new(18.582, 12.9, 12.109), Min = Vector3.new(-9.212, 0.0, -5.867), Roles = table.freeze({ "ACCENT", "BULB", "CANDLE", "GLOW", "MOSS", "STEM", "TRIM" }) }),
	CapShelter = table.freeze({ Size = Vector3.new(13.762, 7.351, 8.796), Min = Vector3.new(-7.167, -0.2, -4.976), Roles = table.freeze({ "CAP", "FOLIAGE", "GLOW", "MOSS", "STEM", "WOOD" }) }),
	CaravanseraiSkylight = table.freeze({ Size = Vector3.new(11.6, 1.665, 11.6), Min = Vector3.new(-5.8, 0.005, -5.8), Roles = table.freeze({ "GLOW", "METAL", "STONE", "TRIM" }) }),
	CenoteCascadeSpillway = table.freeze({ Size = Vector3.new(23.0, 30.2, 27.1), Min = Vector3.new(-11.5, 0.0, -13.8), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM", "WOOD" }) }),
	CenoteColonnadeDome = table.freeze({ Size = Vector3.new(125.819, 67.285, 45.009), Min = Vector3.new(-62.791, -0.258, -34.0), Roles = table.freeze({ "ACCENT", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	ChainGalleryRail = table.freeze({ Size = Vector3.new(22.4, 6.13, 1.55), Min = Vector3.new(-11.2, 0.0, -0.6), Roles = table.freeze({ "GOLD", "METAL", "TRIM" }) }),
	ChainHoist = table.freeze({ Size = Vector3.new(3.2, 22.258, 3.15), Min = Vector3.new(-1.6, 0.042, -1.3), Roles = table.freeze({ "GOLD", "METAL", "TRIM" }) }),
	ChainWinch = table.freeze({ Size = Vector3.new(9.295, 16.491, 9.2), Min = Vector3.new(-4.525, 0.0, -4.6), Roles = table.freeze({ "GOLD", "METAL", "TRIM", "WOOD" }) }),
	ChalkSign = table.freeze({ Size = Vector3.new(3.058, 2.63, 1.803), Min = Vector3.new(-1.502, -0.1, -1.138), Roles = table.freeze({ "ALT", "STONE" }) }),
	CinderGateArch = table.freeze({ Size = Vector3.new(58.32, 51.614, 18.924), Min = Vector3.new(-29.16, -0.114, -7.253), Roles = table.freeze({ "ACCENT", "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	CinderholdVent = table.freeze({ Size = Vector3.new(88.96, 101.524, 84.0), Min = Vector3.new(-44.2, -1.524, -50.0), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	CitadelDoors = table.freeze({ Size = Vector3.new(64.8, 91.5, 24.8), Min = Vector3.new(-32.4, 0.0, -10.0), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	CoalHeap = table.freeze({ Size = Vector3.new(12.909, 3.153, 8.959), Min = Vector3.new(-6.204, -0.1, -4.536), Roles = table.freeze({ "ALT", "STONE" }) }),
	CoalHopper = table.freeze({ Size = Vector3.new(36.6, 24.145, 14.583), Min = Vector3.new(-18.3, 0.0, -8.0), Roles = table.freeze({ "ACCENT", "ALT", "METAL", "TRIM", "WOOD" }) }),
	CocoonLamp = table.freeze({ Size = Vector3.new(2.743, 10.725, 4.575), Min = Vector3.new(-1.1, 0.0, -1.1), Roles = table.freeze({ "CANDLE", "SILK", "TRIM", "WOOD" }) }),
	ConstructShell = table.freeze({ Size = Vector3.new(14.061, 25.25, 7.8), Min = Vector3.new(-6.361, 0.0, -3.9), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "METAL", "TRIM" }) }),
	ControlCabin = table.freeze({ Size = Vector3.new(15.443, 12.8, 15.443), Min = Vector3.new(-7.722, 0.0, -7.722), Roles = table.freeze({ "CRYSTAL", "GLOW", "GOLD", "METAL", "TRIM", "WOOD" }) }),
	ConveyorRollers = table.freeze({ Size = Vector3.new(7.95, 5.92, 22.9), Min = Vector3.new(-2.85, 0.0, -11.9), Roles = table.freeze({ "ACCENT", "METAL", "TRIM" }) }),
	CoolingRack = table.freeze({ Size = Vector3.new(12.5, 9.2, 3.7), Min = Vector3.new(-6.25, -0.2, -1.85), Roles = table.freeze({ "GLOW", "METAL", "STONE", "TRIM" }) }),
	CraneTrolley = table.freeze({ Size = Vector3.new(16.26, 11.84, 12.1), Min = Vector3.new(-8.13, 0.0, -5.7), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "METAL", "TRIM" }) }),
	CrevasseCartPillar = table.freeze({ Size = Vector3.new(10.374, 24.703, 14.64), Min = Vector3.new(-5.143, -0.545, -6.004), Roles = table.freeze({ "CRYSTAL", "METAL", "MOSS", "STONE", "WOOD" }) }),
	CrustIsland = table.freeze({ Size = Vector3.new(16.872, 2.178, 12.714), Min = Vector3.new(-9.16, -0.2, -6.736), Roles = table.freeze({ "ALT", "GLOW", "STONE" }) }),
	CrystalBrazier = table.freeze({ Size = Vector3.new(5.95, 2.52, 5.546), Min = Vector3.new(-2.679, -0.22, -2.55), Roles = table.freeze({ "CANDLE", "CRYSTAL", "MOSS", "TRIM" }) }),
	CurtainWallRuins = table.freeze({ Size = Vector3.new(32.1, 18.875, 7.673), Min = Vector3.new(-16.1, -0.475, -3.178), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM", "WOOD" }) }),
	DesertCaravanWagon = table.freeze({ Size = Vector3.new(16.12, 8.767, 20.249), Min = Vector3.new(-6.0, -0.031, -7.386), Roles = table.freeze({ "FOLIAGE", "METAL", "MOSS", "WOOD" }) }),
	DolmenBellGate = table.freeze({ Size = Vector3.new(45.891, 24.654, 7.996), Min = Vector3.new(-22.875, -0.649, -3.969), Roles = table.freeze({ "GOLD", "MOSS", "STONE", "TRIM" }) }),
	DropHammer = table.freeze({ Size = Vector3.new(16.25, 44.18, 12.0), Min = Vector3.new(-8.125, 0.0, -6.0), Roles = table.freeze({ "ACCENT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	DryStoneWall = table.freeze({ Size = Vector3.new(26.082, 3.961, 3.252), Min = Vector3.new(-12.0, -0.126, -1.563), Roles = table.freeze({ "MOSS", "STONE" }) }),
	DuctManifold = table.freeze({ Size = Vector3.new(12.0, 24.985, 25.1), Min = Vector3.new(-6.0, -1.64, -16.1), Roles = table.freeze({ "ACCENT", "GOLD", "METAL", "TRIM" }) }),
	EggRack = table.freeze({ Size = Vector3.new(13.6, 20.132, 2.801), Min = Vector3.new(-6.8, 0.0, -1.401), Roles = table.freeze({ "BULB", "CRYSTAL", "SILK", "TRIM", "WOOD" }) }),
	EggSacCluster = table.freeze({ Size = Vector3.new(8.207, 5.376, 6.356), Min = Vector3.new(-4.356, -0.3, -3.186), Roles = table.freeze({ "BULB", "CRYSTAL", "MOSS", "STEM" }) }),
	ElderCap = table.freeze({ Size = Vector3.new(87.606, 110.267, 88.212), Min = Vector3.new(-44.673, -2.73, -43.234), Roles = table.freeze({ "BULB", "CAP", "GLOW", "MOSS", "STEM" }) }),
	ElderColossusHead = table.freeze({ Size = Vector3.new(31.201, 33.998, 26.571), Min = Vector3.new(-13.597, 0.0, -13.42), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	ElderCrownRing = table.freeze({ Size = Vector3.new(61.558, 25.692, 24.398), Min = Vector3.new(-32.991, -0.045, -7.673), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	ElderHandFingers = table.freeze({ Size = Vector3.new(56.327, 29.658, 27.232), Min = Vector3.new(-23.551, -1.8, -15.167), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	ElderShieldRim = table.freeze({ Size = Vector3.new(49.389, 40.108, 28.791), Min = Vector3.new(-24.689, -0.456, -15.781), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	ElderShoulderPauldron = table.freeze({ Size = Vector3.new(43.139, 53.423, 25.68), Min = Vector3.new(-20.944, -1.523, -14.6), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	FernCluster = table.freeze({ Size = Vector3.new(9.888, 3.741, 10.323), Min = Vector3.new(-4.642, 0.0, -5.13), Roles = table.freeze({ "FOLIAGE", "MOSS", "WOOD" }) }),
	FisherHut = table.freeze({ Size = Vector3.new(31.487, 19.875, 17.448), Min = Vector3.new(-13.459, -1.8, -8.448), Roles = table.freeze({ "ALT", "GLOW", "MOSS", "STONE", "WOOD" }) }),
	FlameJetPortcullis = table.freeze({ Size = Vector3.new(39.8, 31.85, 12.0), Min = Vector3.new(-19.9, 0.0, -6.0), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	FlueStack = table.freeze({ Size = Vector3.new(14.6, 100.4, 19.3), Min = Vector3.new(-7.3, 0.0, -7.3), Roles = table.freeze({ "GLOW", "METAL", "STONE", "TRIM" }) }),
	ForkedBoltTotem = table.freeze({ Size = Vector3.new(18.993, 42.882, 11.852), Min = Vector3.new(-9.496, -0.282, -5.642), Roles = table.freeze({ "ACCENT", "GLOW", "METAL", "MOSS", "STONE" }) }),
	FrozenAvalancheWave = table.freeze({ Size = Vector3.new(68.344, 51.544, 29.545), Min = Vector3.new(-33.501, -1.2, -15.352), Roles = table.freeze({ "CRYSTAL", "MOSS", "STONE" }) }),
	FrozenBareTree = table.freeze({ Size = Vector3.new(14.817, 27.053, 9.674), Min = Vector3.new(-6.862, -1.41, -4.426), Roles = table.freeze({ "CRYSTAL", "MOSS", "WOOD" }) }),
	FrozenSiegeLadder = table.freeze({ Size = Vector3.new(5.948, 25.91, 13.083), Min = Vector3.new(-3.176, -0.591, -10.815), Roles = table.freeze({ "CRYSTAL", "METAL", "MOSS", "WOOD" }) }),
	FrozenSoldier = table.freeze({ Size = Vector3.new(3.815, 9.55, 3.258), Min = Vector3.new(-2.049, 0.1, -1.632), Roles = table.freeze({ "CRYSTAL", "METAL", "STONE" }) }),
	FrozenTrebuchet = table.freeze({ Size = Vector3.new(12.15, 21.454, 19.835), Min = Vector3.new(-6.09, -0.2, -11.635), Roles = table.freeze({ "CRYSTAL", "METAL", "MOSS", "STONE", "WOOD" }) }),
	FulguriteCluster = table.freeze({ Size = Vector3.new(15.046, 14.825, 14.087), Min = Vector3.new(-6.93, 0.1, -7.211), Roles = table.freeze({ "CRYSTAL", "GLOW", "STONE" }) }),
	FurnaceBox = table.freeze({ Size = Vector3.new(23.4, 34.238, 21.04), Min = Vector3.new(-11.7, 0.0, -12.14), Roles = table.freeze({ "GLOW", "METAL", "STONE", "TRIM" }) }),
	FurnaceDoorGiant = table.freeze({ Size = Vector3.new(56.0, 54.0, 16.1), Min = Vector3.new(-28.0, 0.0, -7.5), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	FurnaceGateDoors = table.freeze({ Size = Vector3.new(48.0, 46.4, 12.0), Min = Vector3.new(-24.0, 0.0, -6.6), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	FurnaceTower = table.freeze({ Size = Vector3.new(20.0, 59.3, 18.0), Min = Vector3.new(-10.0, 0.0, -9.0), Roles = table.freeze({ "ACCENT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	GatehouseArch = table.freeze({ Size = Vector3.new(77.0, 30.357, 14.304), Min = Vector3.new(-38.5, -0.657, -6.205), Roles = table.freeze({ "ACCENT", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	GlacialUrnShrine = table.freeze({ Size = Vector3.new(8.4, 14.7, 8.4), Min = Vector3.new(-4.2, -0.5, -4.2), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE" }) }),
	GlacierShrine = table.freeze({ Size = Vector3.new(9.309, 12.131, 7.6), Min = Vector3.new(-3.8, -0.948, -3.8), Roles = table.freeze({ "CRYSTAL", "GLOW", "MOSS", "STONE", "TRIM" }) }),
	GlassArchSpan = table.freeze({ Size = Vector3.new(98.271, 61.76, 25.947), Min = Vector3.new(-49.908, 0.265, -13.299), Roles = table.freeze({ "CRYSTAL", "GLOW", "STONE" }) }),
	GlassCactusCluster = table.freeze({ Size = Vector3.new(9.492, 8.609, 9.825), Min = Vector3.new(-5.031, 0.05, -5.118), Roles = table.freeze({ "ALT", "FOLIAGE", "MOSS", "STONE" }) }),
	GlowLilyCluster = table.freeze({ Size = Vector3.new(10.516, 3.532, 9.0), Min = Vector3.new(-5.453, 0.063, -4.2), Roles = table.freeze({ "FOLIAGE", "GLOW", "GOLD", "MOSS", "WOOD" }) }),
	GlowcapTuftA = table.freeze({ Size = Vector3.new(7.011, 2.71, 5.929), Min = Vector3.new(-3.409, -0.35, -2.672), Roles = table.freeze({ "CAP", "GLOW", "MOSS", "STEM" }) }),
	GlowcapTuftB = table.freeze({ Size = Vector3.new(7.753, 3.179, 5.318), Min = Vector3.new(-3.624, -0.35, -2.897), Roles = table.freeze({ "CAP", "GLOW", "MOSS", "STEM" }) }),
	GothicPillarColonnade = table.freeze({ Size = Vector3.new(12.0, 48.951, 12.072), Min = Vector3.new(-6.0, -1.0, -5.822), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE" }) }),
	GreatBellows = table.freeze({ Size = Vector3.new(25.0, 63.809, 28.176), Min = Vector3.new(-12.5, 0.0, -11.5), Roles = table.freeze({ "ACCENT", "METAL", "STONE", "TRIM", "WOOD" }) }),
	GreatCrucible = table.freeze({ Size = Vector3.new(75.2, 97.039, 37.409), Min = Vector3.new(-37.6, 0.0, -17.174), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	HangingChainRun = table.freeze({ Size = Vector3.new(7.4, 35.259, 5.2), Min = Vector3.new(-3.7, -0.284, -2.6), Roles = table.freeze({ "GOLD", "METAL", "TRIM" }) }),
	HangingRootFringe = table.freeze({ Size = Vector3.new(38.713, 30.308, 7.623), Min = Vector3.new(-19.404, 1.408, -2.005), Roles = table.freeze({ "GLOW", "MOSS", "WOOD" }) }),
	HeartrootMotherHeart = table.freeze({ Size = Vector3.new(73.643, 90.59, 48.352), Min = Vector3.new(-37.988, -2.197, -28.69), Roles = table.freeze({ "FOLIAGE", "GLOW", "MOSS", "WOOD" }) }),
	HighlandSheep = table.freeze({ Size = Vector3.new(2.555, 3.119, 5.537), Min = Vector3.new(-1.363, 0.0, -2.236), Roles = table.freeze({ "ALT", "TRIM" }) }),
	HighlandWindmill = table.freeze({ Size = Vector3.new(32.431, 46.753, 33.08), Min = Vector3.new(-13.678, 0.0, -23.396), Roles = table.freeze({ "ALT", "METAL", "STONE", "TRIM", "WOOD" }) }),
	HollowStumpRim = table.freeze({ Size = Vector3.new(86.521, 29.645, 60.122), Min = Vector3.new(-43.706, -1.036, -42.875), Roles = table.freeze({ "FOLIAGE", "MOSS", "WOOD" }) }),
	HuntersLodge = table.freeze({ Size = Vector3.new(27.88, 22.516, 22.1), Min = Vector3.new(-11.708, -1.6, -9.8), Roles = table.freeze({ "GLOW", "MOSS", "STONE", "TRIM", "WOOD" }) }),
	HydraulicJack = table.freeze({ Size = Vector3.new(8.964, 15.254, 8.0), Min = Vector3.new(-4.964, 0.0, -4.0), Roles = table.freeze({ "ACCENT", "GOLD", "METAL", "TRIM" }) }),
	IceBrazier = table.freeze({ Size = Vector3.new(4.157, 6.7, 4.1), Min = Vector3.new(-2.078, 0.0, -2.05), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "WOOD" }) }),
	IceCaveOverhang = table.freeze({ Size = Vector3.new(17.529, 29.691, 30.654), Min = Vector3.new(-8.952, -0.43, -14.878), Roles = table.freeze({ "CRYSTAL", "GLOW", "MOSS", "STONE" }) }),
	IceCrystalBrazier = table.freeze({ Size = Vector3.new(7.6, 8.5, 8.285), Min = Vector3.new(-3.8, -0.4, -4.485), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE" }) }),
	IceFloeSlab = table.freeze({ Size = Vector3.new(26.867, 6.619, 21.682), Min = Vector3.new(-12.675, 0.2, -10.709), Roles = table.freeze({ "CRYSTAL", "MOSS", "STONE" }) }),
	IngotPallet = table.freeze({ Size = Vector3.new(14.0, 4.825, 8.8), Min = Vector3.new(-7.0, 0.0, -4.4), Roles = table.freeze({ "GLOW", "METAL", "TRIM", "WOOD" }) }),
	JibCrane = table.freeze({ Size = Vector3.new(6.0, 32.412, 22.3), Min = Vector3.new(-3.0, 0.0, -3.4), Roles = table.freeze({ "ACCENT", "GOLD", "METAL", "TRIM" }) }),
	KennelRow = table.freeze({ Size = Vector3.new(27.35, 12.7, 11.536), Min = Vector3.new(-15.95, -0.8, -5.668), Roles = table.freeze({ "CRYSTAL", "METAL", "MOSS", "STONE", "WOOD" }) }),
	KilnTower = table.freeze({ Size = Vector3.new(27.6, 58.85, 27.6), Min = Vector3.new(-13.8, -0.1, -13.8), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	KneelingKnight = table.freeze({ Size = Vector3.new(6.212, 8.393, 7.168), Min = Vector3.new(-3.073, -0.153, -4.277), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE" }) }),
	LampNiche = table.freeze({ Size = Vector3.new(12.8, 15.039, 5.469), Min = Vector3.new(-6.4, 0.0, -3.729), Roles = table.freeze({ "ACCENT", "BULB", "GLOW", "MOSS", "STEM", "TRIM" }) }),
	LastLampShrine = table.freeze({ Size = Vector3.new(12.8, 10.428, 9.6), Min = Vector3.new(-6.4, 0.0, -4.8), Roles = table.freeze({ "BULB", "CANDLE", "GLOW", "STEM", "STONE", "TRIM", "WOOD" }) }),
	MasterTombPavilion = table.freeze({ Size = Vector3.new(36.139, 23.802, 24.226), Min = Vector3.new(-18.057, -0.002, -12.026), Roles = table.freeze({ "FOLIAGE", "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	MessCauldron = table.freeze({ Size = Vector3.new(8.325, 7.128, 7.626), Min = Vector3.new(-4.031, 0.1, -3.756), Roles = table.freeze({ "CRYSTAL", "METAL", "MOSS", "STONE" }) }),
	MouldBed = table.freeze({ Size = Vector3.new(16.9, 1.8, 10.9), Min = Vector3.new(-8.45, 0.0, -5.45), Roles = table.freeze({ "GLOW", "METAL", "STONE", "TRIM" }) }),
	MyceliumNet = table.freeze({ Size = Vector3.new(27.348, 14.849, 3.613), Min = Vector3.new(-13.649, -0.49, -1.839), Roles = table.freeze({ "BULB", "GLOW", "MOSS", "STEM" }) }),
	MyceliumVein = table.freeze({ Size = Vector3.new(27.623, 20.987, 1.646), Min = Vector3.new(-5.718, -0.584, -0.548), Roles = table.freeze({ "GLOW", "STEM" }) }),
	OreCart = table.freeze({ Size = Vector3.new(7.84, 6.662, 10.0), Min = Vector3.new(-3.92, 0.0, -5.0), Roles = table.freeze({ "ACCENT", "ALT", "METAL", "TRIM" }) }),
	OreCrusherJaw = table.freeze({ Size = Vector3.new(26.0, 25.59, 25.817), Min = Vector3.new(-13.0, -0.4, -10.96), Roles = table.freeze({ "ACCENT", "ALT", "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	OssuaryBones = table.freeze({ Size = Vector3.new(12.019, 8.172, 11.958), Min = Vector3.new(-6.307, -0.35, -6.435), Roles = table.freeze({ "ALT", "BULB", "CAP", "GLOW", "MOSS", "STEM" }) }),
	PadCap = table.freeze({ Size = Vector3.new(4.979, 0.644, 4.98), Min = Vector3.new(-2.468, 0.002, -2.506), Roles = table.freeze({ "CAP", "GLOW" }) }),
	PartsRack = table.freeze({ Size = Vector3.new(12.4, 9.0, 3.8), Min = Vector3.new(-6.2, 0.0, -1.9), Roles = table.freeze({ "GOLD", "METAL", "TRIM" }) }),
	PatternLathe = table.freeze({ Size = Vector3.new(24.81, 13.95, 8.3), Min = Vector3.new(-13.1, 0.0, -3.8), Roles = table.freeze({ "ACCENT", "GOLD", "METAL", "TRIM", "WOOD" }) }),
	PatternRack = table.freeze({ Size = Vector3.new(12.75, 11.098, 7.25), Min = Vector3.new(-6.45, -0.098, -1.95), Roles = table.freeze({ "ACCENT", "TRIM", "WOOD" }) }),
	PermafrostCage = table.freeze({ Size = Vector3.new(10.8, 23.4, 10.8), Min = Vector3.new(-5.4, -0.6, -5.4), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE" }) }),
	PortcullisGate = table.freeze({ Size = Vector3.new(68.0, 42.3, 19.15), Min = Vector3.new(-34.0, -0.1, -9.0), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	PourSpoutChute = table.freeze({ Size = Vector3.new(23.292, 22.15, 26.431), Min = Vector3.new(-11.65, 0.0, -11.531), Roles = table.freeze({ "ACCENT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	PowderKegStack = table.freeze({ Size = Vector3.new(8.6, 7.1, 6.4), Min = Vector3.new(-4.3, 0.0, -3.2), Roles = table.freeze({ "ACCENT", "TRIM", "WOOD" }) }),
	PrayerFlagLine = table.freeze({ Size = Vector3.new(36.117, 11.071, 0.45), Min = Vector3.new(-18.058, -0.014, -0.225), Roles = table.freeze({ "ACCENT", "ALT", "GOLD", "TRIM", "WOOD" }) }),
	QuenchTank = table.freeze({ Size = Vector3.new(28.166, 7.4, 19.0), Min = Vector3.new(-13.5, -0.2, -9.5), Roles = table.freeze({ "CRYSTAL", "METAL", "STONE", "TRIM" }) }),
	RailBuffer = table.freeze({ Size = Vector3.new(7.0, 5.35, 5.93), Min = Vector3.new(-3.5, 0.05, -2.705), Roles = table.freeze({ "ACCENT", "METAL", "TRIM", "WOOD" }) }),
	RamHurdleFence = table.freeze({ Size = Vector3.new(12.707, 4.62, 0.6), Min = Vector3.new(-6.39, -0.01, -0.3), Roles = table.freeze({ "WOOD" }) }),
	RavineHorizonSpire = table.freeze({ Size = Vector3.new(17.6, 60.3, 17.6), Min = Vector3.new(-8.8, -0.1, -8.8), Roles = table.freeze({ "ALT", "GLOW", "STONE", "TRIM" }) }),
	ReedPondCluster = table.freeze({ Size = Vector3.new(7.493, 6.128, 7.881), Min = Vector3.new(-3.494, -0.091, -4.298), Roles = table.freeze({ "FOLIAGE", "GLOW", "WOOD" }) }),
	RimefallIcefall = table.freeze({ Size = Vector3.new(97.474, 73.995, 31.911), Min = Vector3.new(-47.381, -0.2, -19.825), Roles = table.freeze({ "CRYSTAL", "GLOW", "MOSS", "STONE" }) }),
	RimelightCrystalCluster = table.freeze({ Size = Vector3.new(10.747, 14.706, 10.21), Min = Vector3.new(-5.472, 0.104, -5.148), Roles = table.freeze({ "CRYSTAL", "GLOW", "MOSS", "STONE" }) }),
	RootBridgeArch = table.freeze({ Size = Vector3.new(54.835, 23.185, 7.634), Min = Vector3.new(-27.434, -0.208, -3.727), Roles = table.freeze({ "GLOW", "MOSS", "TRIM", "WOOD" }) }),
	RootKnotLantern = table.freeze({ Size = Vector3.new(3.727, 9.471, 3.2), Min = Vector3.new(-1.6, -0.161, -1.6), Roles = table.freeze({ "GLOW", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	RootThrone = table.freeze({ Size = Vector3.new(31.462, 34.652, 31.541), Min = Vector3.new(-15.731, -0.652, -20.0), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	RotMyceliumWeb = table.freeze({ Size = Vector3.new(14.126, 5.099, 13.281), Min = Vector3.new(-7.693, -0.3, -6.858), Roles = table.freeze({ "BULB", "CAP", "GLOW", "MOSS", "STEM" }) }),
	RotVat = table.freeze({ Size = Vector3.new(7.655, 5.561, 7.276), Min = Vector3.new(-3.902, -0.25, -3.451), Roles = table.freeze({ "BULB", "CAP", "GLOW", "MOSS", "TRIM", "WOOD" }) }),
	RotcapCluster = table.freeze({ Size = Vector3.new(12.268, 9.205, 9.643), Min = Vector3.new(-5.974, -0.3, -5.094), Roles = table.freeze({ "BULB", "CAP", "GLOW", "MOSS", "STEM" }) }),
	RotcapTower = table.freeze({ Size = Vector3.new(17.051, 23.54, 15.977), Min = Vector3.new(-9.226, -0.35, -7.776), Roles = table.freeze({ "ACCENT", "BULB", "CAP", "GLOW", "MOSS", "STEM", "TRIM" }) }),
	RuneStandingStone = table.freeze({ Size = Vector3.new(6.529, 13.261, 5.387), Min = Vector3.new(-2.792, -0.5, -2.571), Roles = table.freeze({ "GLOW", "MOSS", "STONE" }) }),
	SandStriderRibs = table.freeze({ Size = Vector3.new(39.705, 30.619, 52.166), Min = Vector3.new(-19.871, -0.478, -26.322), Roles = table.freeze({ "MOSS", "STONE", "TRIM" }) }),
	SandStriderSkull = table.freeze({ Size = Vector3.new(22.758, 16.174, 33.021), Min = Vector3.new(-11.577, -0.419, -15.061), Roles = table.freeze({ "MOSS", "STONE", "TRIM" }) }),
	ScrapHeap = table.freeze({ Size = Vector3.new(17.396, 6.0, 12.261), Min = Vector3.new(-8.741, -0.6, -6.022), Roles = table.freeze({ "ACCENT", "METAL", "STONE", "TRIM" }) }),
	SeracCluster = table.freeze({ Size = Vector3.new(16.944, 30.762, 11.995), Min = Vector3.new(-9.751, -1.158, -6.584), Roles = table.freeze({ "CRYSTAL", "GLOW", "MOSS", "STONE" }) }),
	ShatteredRoseWindow = table.freeze({ Size = Vector3.new(25.776, 41.567, 8.132), Min = Vector3.new(-12.084, -0.8, -3.749), Roles = table.freeze({ "CRYSTAL", "GLOW", "MOSS", "STONE" }) }),
	ShepherdCroft = table.freeze({ Size = Vector3.new(22.569, 14.084, 15.354), Min = Vector3.new(-10.8, -0.134, -7.705), Roles = table.freeze({ "GLOW", "MOSS", "STONE", "TRIM", "WOOD" }) }),
	ShroudSpire = table.freeze({ Size = Vector3.new(35.775, 62.343, 33.028), Min = Vector3.new(-17.945, -0.343, -17.609), Roles = table.freeze({ "GLOW", "SILK", "TRIM" }) }),
	SiegeBallista = table.freeze({ Size = Vector3.new(19.3, 8.214, 18.999), Min = Vector3.new(-9.65, 0.0, -7.822), Roles = table.freeze({ "GOLD", "METAL", "TRIM", "WOOD" }) }),
	SignalBrazier = table.freeze({ Size = Vector3.new(16.693, 29.7, 16.7), Min = Vector3.new(-8.35, 0.0, -8.35), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "STONE", "TRIM" }) }),
	SignalCabin = table.freeze({ Size = Vector3.new(11.604, 12.5, 9.915), Min = Vector3.new(-6.504, -0.3, -4.365), Roles = table.freeze({ "ACCENT", "GLOW", "METAL", "STONE", "TRIM", "WOOD" }) }),
	SignalLamp = table.freeze({ Size = Vector3.new(4.305, 9.8, 2.05), Min = Vector3.new(-0.9, 0.0, -0.9), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "TRIM" }) }),
	SignalLensTower = table.freeze({ Size = Vector3.new(25.97, 61.15, 25.97), Min = Vector3.new(-12.97, -0.1, -12.97), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "STONE", "TRIM" }) }),
	SilkDrape = table.freeze({ Size = Vector3.new(24.098, 9.601, 4.02), Min = Vector3.new(-12.049, -0.364, -1.829), Roles = table.freeze({ "MOSS", "SILK", "STEM" }) }),
	SilkSpire = table.freeze({ Size = Vector3.new(10.402, 25.4, 10.024), Min = Vector3.new(-5.277, 0.0, -4.8), Roles = table.freeze({ "BULB", "CAP", "GLOW", "STEM", "STONE", "TRIM" }) }),
	SilkSpool = table.freeze({ Size = Vector3.new(11.8, 7.652, 9.546), Min = Vector3.new(-5.4, -0.118, -3.0), Roles = table.freeze({ "SILK", "TRIM", "WOOD" }) }),
	SilkWebCurtain = table.freeze({ Size = Vector3.new(17.319, 6.332, 2.776), Min = Vector3.new(-8.662, 0.0, -1.386), Roles = table.freeze({ "BULB", "CAP", "GLOW", "STEM" }) }),
	SilkWindlass = table.freeze({ Size = Vector3.new(9.784, 6.44, 5.98), Min = Vector3.new(-4.6, 0.0, -2.7), Roles = table.freeze({ "BULB", "GLOW", "METAL", "STEM", "TRIM", "WOOD" }) }),
	SlagCannon = table.freeze({ Size = Vector3.new(7.89, 9.304, 15.651), Min = Vector3.new(-4.45, 0.0, -6.168), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "TRIM", "WOOD" }) }),
	SlagLadleCart = table.freeze({ Size = Vector3.new(10.29, 15.373, 17.013), Min = Vector3.new(-4.85, -2.251, -7.4), Roles = table.freeze({ "ACCENT", "GLOW", "METAL", "TRIM" }) }),
	SluiceGateChain = table.freeze({ Size = Vector3.new(33.2, 23.036, 3.4), Min = Vector3.new(-16.6, 0.0, -1.7), Roles = table.freeze({ "ACCENT", "METAL", "TRIM" }) }),
	SluiceTower = table.freeze({ Size = Vector3.new(18.8, 50.8, 18.8), Min = Vector3.new(-9.4, 0.0, -9.4), Roles = table.freeze({ "ACCENT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	SolmereBalustrade = table.freeze({ Size = Vector3.new(16.6, 5.55, 3.0), Min = Vector3.new(-8.3, 0.0, -1.5), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM" }) }),
	SolmereColonnadeWing = table.freeze({ Size = Vector3.new(55.2, 36.962, 17.079), Min = Vector3.new(-27.6, -0.525, -8.579), Roles = table.freeze({ "ACCENT", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	SpiceVaultRuins = table.freeze({ Size = Vector3.new(32.443, 14.864, 22.991), Min = Vector3.new(-16.0, -0.064, -5.9), Roles = table.freeze({ "ALT", "CORAL", "GOLD", "METAL", "STONE", "TRIM" }) }),
	SplitGraniteTor = table.freeze({ Size = Vector3.new(65.568, 93.935, 52.922), Min = Vector3.new(-33.315, -0.591, -24.2), Roles = table.freeze({ "ALT", "MOSS", "STONE" }) }),
	SporeMoss = table.freeze({ Size = Vector3.new(8.469, 1.02, 6.524), Min = Vector3.new(-4.337, -0.25, -3.05), Roles = table.freeze({ "BULB", "GLOW", "MOSS" }) }),
	SteamVent = table.freeze({ Size = Vector3.new(4.68, 10.8, 4.8), Min = Vector3.new(-2.34, 0.0, -2.4), Roles = table.freeze({ "ACCENT", "METAL", "TRIM" }) }),
	StolenLampCocoon = table.freeze({ Size = Vector3.new(4.253, 12.41, 6.218), Min = Vector3.new(-2.353, 0.0, -2.5), Roles = table.freeze({ "BULB", "CAP", "GLOW", "METAL", "STEM", "TRIM" }) }),
	StormCrystalSpikes = table.freeze({ Size = Vector3.new(12.197, 14.471, 9.431), Min = Vector3.new(-6.739, -0.3, -4.408), Roles = table.freeze({ "CRYSTAL", "GLOW", "STONE" }) }),
	StormgrassTuft = table.freeze({ Size = Vector3.new(3.902, 2.851, 2.583), Min = Vector3.new(-1.567, -0.1, -1.32), Roles = table.freeze({ "FOLIAGE", "MOSS" }) }),
	SunDiscShrine = table.freeze({ Size = Vector3.new(17.127, 22.698, 9.405), Min = Vector3.new(-8.435, 0.0, -4.205), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "MOSS", "TRIM" }) }),
	TankLocomotive = table.freeze({ Size = Vector3.new(7.0, 12.208, 20.628), Min = Vector3.new(-3.5, -0.208, -9.9), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "METAL", "TRIM", "WOOD" }) }),
	ThroneOfIcicles = table.freeze({ Size = Vector3.new(25.054, 44.005, 19.3), Min = Vector3.new(-12.21, -1.0, -9.3), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE" }) }),
	TiltingCrucible = table.freeze({ Size = Vector3.new(16.0, 16.747, 20.872), Min = Vector3.new(-7.7, -0.309, -8.972), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "METAL", "TRIM" }) }),
	TitanHeartGrate = table.freeze({ Size = Vector3.new(30.4, 30.4, 4.5), Min = Vector3.new(-15.2, -1.2, -2.5), Roles = table.freeze({ "GLOW", "GOLD", "METAL", "TRIM" }) }),
	TitanMouldFist = table.freeze({ Size = Vector3.new(23.0, 9.369, 16.0), Min = Vector3.new(-11.5, 0.0, -8.0), Roles = table.freeze({ "GLOW", "METAL", "STONE", "TRIM" }) }),
	TitanMouldHelm = table.freeze({ Size = Vector3.new(23.046, 18.696, 18.0), Min = Vector3.new(-11.523, 0.0, -9.0), Roles = table.freeze({ "GLOW", "METAL", "STONE", "TRIM" }) }),
	TollHouseRuins = table.freeze({ Size = Vector3.new(39.997, 13.554, 31.326), Min = Vector3.new(-18.523, -0.154, -14.0), Roles = table.freeze({ "ALT", "GLOW", "METAL", "MOSS", "STONE", "TRIM" }) }),
	TollShelterRuins = table.freeze({ Size = Vector3.new(20.526, 14.699, 15.653), Min = Vector3.new(-10.326, -1.094, -8.653), Roles = table.freeze({ "CRYSTAL", "METAL", "MOSS", "STONE", "WOOD" }) }),
	TrailCairnTall = table.freeze({ Size = Vector3.new(4.673, 13.322, 4.032), Min = Vector3.new(-2.214, -0.156, -1.921), Roles = table.freeze({ "GLOW", "METAL", "MOSS", "STONE" }) }),
	VarrashLightningRod = table.freeze({ Size = Vector3.new(11.781, 29.7, 12.079), Min = Vector3.new(-6.027, 0.0, -6.356), Roles = table.freeze({ "CRYSTAL", "GLOW", "METAL", "STONE" }) }),
	VarrashWaystone = table.freeze({ Size = Vector3.new(3.8, 10.3, 3.8), Min = Vector3.new(-1.9, 0.0, -1.9), Roles = table.freeze({ "ALT", "GLOW", "METAL", "STONE", "TRIM" }) }),
	VaultRibArch = table.freeze({ Size = Vector3.new(51.741, 119.042, 14.4), Min = Vector3.new(-7.2, 0.0, -7.2), Roles = table.freeze({ "METAL", "STONE", "TRIM" }) }),
	VelmariBanner = table.freeze({ Size = Vector3.new(5.532, 15.0, 3.01), Min = Vector3.new(-2.7, 0.0, -1.3), Roles = table.freeze({ "ALT", "CAP", "FOLIAGE", "GLOW", "TRIM", "WOOD" }) }),
	VelmariLampPost = table.freeze({ Size = Vector3.new(4.2, 11.9, 5.947), Min = Vector3.new(-2.1, 0.0, -1.3), Roles = table.freeze({ "ACCENT", "BULB", "GLOW", "TRIM" }) }),
	VineboundGuardian = table.freeze({ Size = Vector3.new(10.405, 14.987, 9.137), Min = Vector3.new(-5.203, -0.007, -4.63), Roles = table.freeze({ "ACCENT", "GLOW", "MOSS", "TRIM", "WOOD" }) }),
	VineboundKeep = table.freeze({ Size = Vector3.new(46.67, 47.701, 22.501), Min = Vector3.new(-23.441, -0.201, -13.767), Roles = table.freeze({ "ACCENT", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	VineboundTower = table.freeze({ Size = Vector3.new(25.625, 51.665, 24.861), Min = Vector3.new(-12.37, -1.165, -12.661), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM", "WOOD" }) }),
	WallGear = table.freeze({ Size = Vector3.new(34.904, 28.807, 5.0), Min = Vector3.new(-14.404, -0.904, -2.5), Roles = table.freeze({ "ACCENT", "METAL", "TRIM" }) }),
	WardStarShieldMarker = table.freeze({ Size = Vector3.new(8.789, 8.242, 5.988), Min = Vector3.new(-4.79, 0.0, -3.192), Roles = table.freeze({ "CRYSTAL", "METAL", "MOSS", "STONE" }) }),
	WatchKilnTower = table.freeze({ Size = Vector3.new(26.415, 27.947, 22.967), Min = Vector3.new(-15.235, 0.0, -9.57), Roles = table.freeze({ "ALT", "GLOW", "METAL", "MOSS", "STONE", "TRIM" }) }),
	WaterTower = table.freeze({ Size = Vector3.new(14.1, 34.032, 19.55), Min = Vector3.new(-7.05, -0.032, -7.05), Roles = table.freeze({ "ACCENT", "METAL", "TRIM", "WOOD" }) }),
	WaterfallRibbon = table.freeze({ Size = Vector3.new(18.0, 60.84, 6.825), Min = Vector3.new(-9.0, -0.84, -1.803), Roles = table.freeze({ "ALT", "CRYSTAL" }) }),
	Waterwheel = table.freeze({ Size = Vector3.new(26.255, 27.045, 12.575), Min = Vector3.new(-12.5, -0.417, -5.827), Roles = table.freeze({ "FOLIAGE", "METAL", "MOSS", "TRIM", "WOOD" }) }),
	WebbedArchway = table.freeze({ Size = Vector3.new(18.2, 15.9, 4.79), Min = Vector3.new(-9.1, 0.0, -2.0), Roles = table.freeze({ "BULB", "CAP", "GLOW", "STEM", "STONE", "TRIM" }) }),
	WhiteguardTower = table.freeze({ Size = Vector3.new(20.668, 62.7, 26.662), Min = Vector3.new(-10.334, -1.2, -10.6), Roles = table.freeze({ "ALT", "CRYSTAL", "GLOW", "METAL", "MOSS", "STONE", "TRIM" }) }),
	WindBentPine = table.freeze({ Size = Vector3.new(24.141, 28.797, 8.176), Min = Vector3.new(-3.188, -0.565, -3.938), Roles = table.freeze({ "FOLIAGE", "WOOD" }) }),
}) :: { [string]: Template }

local rgb = Color3.fromRGB
local M = Enum.Material

local function swatch(r: number, g: number, b: number, material: Enum.Material, transparency: number?): Swatch
	return table.freeze({ Color = rgb(r, g, b), Material = material, Transparency = transparency })
end

TowerBiomeKit.Biomes = table.freeze({
	verdant_ruins = table.freeze({
		Tree = "BanyanTree",
		Spire = "Obelisk",
		Clutter = table.freeze({ "FoliageBush", "RuinRubble", "StoneUrn" }),
		Palette = table.freeze({
			MOSS = swatch(86, 132, 58, M.Grass),
			WOOD = swatch(82, 64, 46, M.Wood),
			FOLIAGE = swatch(54, 122, 60, M.Grass),
			CRYSTAL = swatch(165, 230, 200, M.Glass, 0.2),
			ALT = swatch(245, 210, 120, M.SmoothPlastic),
		}),
	}),
	fungal_hollow = table.freeze({
		Tree = "BanyanTree",
		Spire = "Obelisk",
		Clutter = table.freeze({ "MushroomCluster" }),
		Palette = table.freeze({
			MOSS = swatch(58, 72, 112, M.Grass),
			WOOD = swatch(52, 40, 48, M.Wood),
			FOLIAGE = swatch(60, 118, 130, M.Grass),
			CAP = swatch(68, 48, 168, M.SmoothPlastic),
			STEM = swatch(165, 162, 195, M.SmoothPlastic),
			CRYSTAL = swatch(120, 240, 230, M.Glass, 0.2),
			ALT = swatch(115, 225, 255, M.SmoothPlastic),
			-- Violet spore-bulbs and the Sporecap Chanters' candle flames (fungal_f6_kit).
			BULB = swatch(196, 112, 255, M.Neon),
			CANDLE = swatch(255, 198, 122, M.Neon),
			-- The Matriarch's silk (fungal_f10_nest_kit).
			SILK = swatch(232, 226, 246, M.Fabric),
		}),
	}),
	ashen_dunes = table.freeze({
		Tree = "DeadTree",
		Spire = "Obelisk",
		Clutter = table.freeze({ "BoulderCluster", "StoneUrn" }),
		Palette = table.freeze({
			MOSS = swatch(128, 102, 80, M.Sand),
			WOOD = swatch(92, 74, 62, M.Wood),
			FOLIAGE = swatch(118, 94, 62, M.Grass),
			CRYSTAL = swatch(255, 150, 70, M.Glass, 0.2),
			ALT = swatch(175, 95, 65, M.Slate),
		}),
	}),
	frozen_citadel = table.freeze({
		Tree = "BanyanTree",
		Spire = "Obelisk",
		Pine = "PineTree",
		Clutter = table.freeze({ "IceCluster" }),
		Palette = table.freeze({
			MOSS = swatch(232, 242, 252, M.Snow),
			WOOD = swatch(70, 58, 52, M.Wood),
			FOLIAGE = swatch(40, 82, 76, M.Grass),
			CRYSTAL = swatch(165, 225, 255, M.Ice, 0.1),
			ALT = swatch(150, 210, 255, M.SmoothPlastic),
		}),
	}),
	infernal_foundry = table.freeze({
		Tree = "DeadTree",
		Spire = "FurnaceStack",
		Clutter = table.freeze({ "ForgeScrap" }),
		Palette = table.freeze({
			MOSS = swatch(96, 46, 30, M.CrackedLava),
			WOOD = swatch(40, 30, 30, M.Wood),
			FOLIAGE = swatch(90, 40, 30, M.Grass),
			METAL = swatch(58, 50, 52, M.DiamondPlate),
			CRYSTAL = swatch(255, 120, 40, M.Glass, 0.2),
			ALT = swatch(255, 140, 60, M.SmoothPlastic),
		}),
	}),
	thunder_highlands = table.freeze({
		Tree = "BanyanTree",
		Spire = "Obelisk",
		Pine = "PineTree",
		Clutter = table.freeze({ "Cairn" }),
		Palette = table.freeze({
			MOSS = swatch(84, 112, 74, M.Grass),
			WOOD = swatch(70, 56, 46, M.Wood),
			FOLIAGE = swatch(52, 88, 68, M.Grass),
			CRYSTAL = swatch(165, 195, 255, M.Glass, 0.2),
			ALT = swatch(180, 200, 255, M.SmoothPlastic),
		}),
	}),
	corrupted_grove = table.freeze({
		Tree = "BlightTree",
		Spire = "Obelisk",
		Clutter = table.freeze({ "BlightPod" }),
		Palette = table.freeze({
			MOSS = swatch(82, 36, 80, M.Grass),
			WOOD = swatch(30, 22, 36, M.Wood),
			FOLIAGE = swatch(95, 28, 88, M.Grass),
			CAP = swatch(138, 36, 118, M.SmoothPlastic),
			STEM = swatch(120, 100, 130, M.SmoothPlastic),
			CRYSTAL = swatch(245, 95, 205, M.Glass, 0.2),
			ALT = swatch(255, 95, 195, M.SmoothPlastic),
		}),
	}),
	sunken_sanctuary = table.freeze({
		Tree = "BanyanTree",
		Spire = "Obelisk",
		Clutter = table.freeze({ "CoralCluster" }),
		Palette = table.freeze({
			MOSS = swatch(70, 160, 150, M.Grass),
			WOOD = swatch(110, 96, 80, M.Wood),
			FOLIAGE = swatch(60, 150, 120, M.Grass),
			CORAL = swatch(238, 142, 112, M.SmoothPlastic),
			CRYSTAL = swatch(125, 238, 255, M.Glass, 0.2),
			ALT = swatch(52, 188, 204, M.SmoothPlastic),
		}),
	}),
	astral_archives = table.freeze({
		Tree = "BanyanTree",
		Spire = "Obelisk",
		Clutter = table.freeze({ "TomeStack" }),
		Palette = table.freeze({
			MOSS = swatch(120, 130, 210, M.SmoothPlastic),
			WOOD = swatch(36, 26, 48, M.Wood),
			FOLIAGE = swatch(80, 90, 170, M.Grass),
			CRYSTAL = swatch(170, 200, 255, M.Glass, 0.15),
			ALT = swatch(38, 48, 88, M.SmoothPlastic),
		}),
	}),
	abyssal_throne = table.freeze({
		Tree = "BlightTree",
		Spire = "ObsidianSpire",
		Clutter = table.freeze({ "VoidShards" }),
		Palette = table.freeze({
			MOSS = swatch(44, 32, 60, M.Basalt),
			WOOD = swatch(24, 18, 30, M.Wood),
			FOLIAGE = swatch(60, 30, 90, M.Grass),
			CRYSTAL = swatch(152, 88, 235, M.Glass, 0.15),
			ALT = swatch(52, 215, 228, M.SmoothPlastic),
		}),
	}),
}) :: { [string]: BiomeKit }

-- Natural floors (GDD §3.3): how each biome's ecosystem is scattered over its terrain (TowerBiomeAssets).
--   Groves       clusters on open ground: a centrepiece (Trees, scaled TreeScale), up to Companions smaller
--                ones around it and UnderPerGrove understory pieces (Understory) in a ring
--   SlopeForest  trees climbing the mountain slopes (SlopeForestCount of them)
--   Rocks        boulder clusters anywhere not too steep; Outcrops: small cliff rocks half sunk in the slopes
--   Monoliths    a few standing landmarks on open ground (MonolithScale)
export type Ecology = {
	Groves: number,
	Trees: { string },
	TreeScale: { number },
	Companions: number,
	Understory: { string },
	UnderPerGrove: number,
	SlopeForest: { string },
	SlopeForestCount: number,
	Rocks: number,
	Outcrops: number,
	Monoliths: { string },
	MonolithCount: number,
	MonolithScale: { number },
}

local function ecology(e: Ecology): Ecology
	return table.freeze(e)
end

TowerBiomeKit.Ecology = table.freeze({
	verdant_ruins = ecology({ Groves = 7, Trees = { "BanyanTree" }, TreeScale = { 0.55, 0.9 }, Companions = 2,
		Understory = { "FoliageBush", "FoliageBush", "RuinRubble", "StoneUrn" }, UnderPerGrove = 5,
		SlopeForest = { "BanyanTree", "FoliageBush" }, SlopeForestCount = 6, Rocks = 10, Outcrops = 10,
		Monoliths = { "Obelisk" }, MonolithCount = 2, MonolithScale = { 0.42, 0.6 } }),
	fungal_hollow = ecology({ Groves = 8, Trees = { "GiantMushroom" }, TreeScale = { 0.5, 0.95 }, Companions = 3,
		Understory = { "MushroomCluster" }, UnderPerGrove = 6, SlopeForest = { "GiantMushroom" }, SlopeForestCount = 6,
		Rocks = 8, Outcrops = 8, Monoliths = { "CrystalSpire" }, MonolithCount = 3, MonolithScale = { 0.45, 0.7 } }),
	ashen_dunes = ecology({ Groves = 5, Trees = { "DeadTree" }, TreeScale = { 0.6, 1.0 }, Companions = 1,
		Understory = { "BoulderCluster", "StoneUrn" }, UnderPerGrove = 3, SlopeForest = { "DeadTree" }, SlopeForestCount = 4,
		Rocks = 16, Outcrops = 14, Monoliths = { "Obelisk" }, MonolithCount = 3, MonolithScale = { 0.42, 0.6 } }),
	frozen_citadel = ecology({ Groves = 8, Trees = { "PineTree" }, TreeScale = { 0.55, 1.0 }, Companions = 3,
		Understory = { "IceCluster", "BoulderCluster" }, UnderPerGrove = 3, SlopeForest = { "PineTree" }, SlopeForestCount = 14,
		Rocks = 8, Outcrops = 8, Monoliths = { "CrystalSpire" }, MonolithCount = 4, MonolithScale = { 0.45, 0.75 } }),
	infernal_foundry = ecology({ Groves = 5, Trees = { "DeadTree" }, TreeScale = { 0.5, 0.85 }, Companions = 1,
		Understory = { "ForgeScrap", "BoulderCluster" }, UnderPerGrove = 3, SlopeForest = {}, SlopeForestCount = 0,
		Rocks = 14, Outcrops = 12, Monoliths = { "FurnaceStack" }, MonolithCount = 4, MonolithScale = { 0.45, 0.65 } }),
	thunder_highlands = ecology({ Groves = 7, Trees = { "PineTree" }, TreeScale = { 0.6, 1.1 }, Companions = 3,
		Understory = { "Cairn", "BoulderCluster" }, UnderPerGrove = 3, SlopeForest = { "PineTree" }, SlopeForestCount = 12,
		Rocks = 12, Outcrops = 12, Monoliths = { "Obelisk" }, MonolithCount = 2, MonolithScale = { 0.42, 0.6 } }),
	corrupted_grove = ecology({ Groves = 7, Trees = { "BlightTree", "GiantMushroom" }, TreeScale = { 0.55, 0.95 }, Companions = 2,
		Understory = { "BlightPod" }, UnderPerGrove = 5, SlopeForest = { "BlightTree" }, SlopeForestCount = 6,
		Rocks = 8, Outcrops = 8, Monoliths = { "Obelisk" }, MonolithCount = 2, MonolithScale = { 0.42, 0.6 } }),
	sunken_sanctuary = ecology({ Groves = 8, Trees = { "CoralCluster" }, TreeScale = { 2.2, 3.4 }, Companions = 3,
		Understory = { "CoralCluster", "BoulderCluster" }, UnderPerGrove = 4, SlopeForest = { "CoralCluster" }, SlopeForestCount = 6,
		Rocks = 8, Outcrops = 8, Monoliths = { "Obelisk" }, MonolithCount = 4, MonolithScale = { 0.4, 0.6 } }),
	astral_archives = ecology({ Groves = 6, Trees = { "CrystalSpire" }, TreeScale = { 0.35, 0.6 }, Companions = 2,
		Understory = { "TomeStack", "BoulderCluster" }, UnderPerGrove = 4, SlopeForest = { "CrystalSpire" }, SlopeForestCount = 6,
		Rocks = 6, Outcrops = 8, Monoliths = { "Obelisk" }, MonolithCount = 4, MonolithScale = { 0.42, 0.62 } }),
	abyssal_throne = ecology({ Groves = 6, Trees = { "ObsidianSpire" }, TreeScale = { 0.35, 0.6 }, Companions = 2,
		Understory = { "VoidShards" }, UnderPerGrove = 4, SlopeForest = { "BlightTree" }, SlopeForestCount = 4,
		Rocks = 10, Outcrops = 10, Monoliths = { "ObsidianSpire" }, MonolithCount = 3, MonolithScale = { 0.45, 0.7 } }),
}) :: { [string]: Ecology }

-- Roles every biome shares unless its palette says otherwise.
TowerBiomeKit.SharedPalette = table.freeze({
	GOLD = swatch(218, 178, 88, M.Metal),
	METAL = swatch(58, 52, 56, M.Metal),
	CAP = swatch(68, 48, 168, M.SmoothPlastic),
	STEM = swatch(165, 162, 195, M.SmoothPlastic),
	CORAL = swatch(238, 142, 112, M.SmoothPlastic),
}) :: { [string]: Swatch }

-- Templates drawn smaller than their sculpt relative to the part-built prop they replace.
TowerBiomeKit.RefScale = table.freeze({
	DeadTree = 1.2,
	BlightTree = 1.1,
	PineTree = 1.0,
}) :: { [string]: number }

-- Templates large enough to cast shadows (clutter, glow and crystals never do).
TowerBiomeKit.CastsShadow = table.freeze({
	BanyanTree = true, BlightTree = true, DeadTree = true, PineTree = true, GiantMushroom = true,
	LionGuardian = true, RobedStatueStaff = true, RobedStatueTrident = true, Obelisk = true,
	FurnaceStack = true, ObsidianSpire = true, ArchCrown = true, ArchPierSegment = true,
	Waterwheel = true, AqueductBrokenSpan = true, SunDiscShrine = true, SolmereBalustrade = true,
	RootThrone = true, HollowStumpRim = true, RootBridgeArch = true, RootKnotLantern = true,
	GatehouseArch = true, VineboundTower = true, VineboundKeep = true, CurtainWallRuins = true, VineboundGuardian = true,
	CenoteColonnadeDome = true, SolmereColonnadeWing = true, HeartrootMotherHeart = true, CenoteCascadeSpillway = true,
	CinderGateArch = true, VarrashWaystone = true, BuriedWagon = true, TollHouseRuins = true, WatchKilnTower = true,
	SandStriderRibs = true, SandStriderSkull = true, DesertCaravanWagon = true, SpiceVaultRuins = true, MasterTombPavilion = true,
	GlassArchSpan = true, RavineHorizonSpire = true, VarrashLightningRod = true,
	KilnTower = true, SignalLensTower = true, PortcullisGate = true, AshmarketStall = true,
	ElderHandFingers = true, ElderShieldRim = true, ElderColossusHead = true, ElderCrownRing = true, ElderShoulderPauldron = true, CinderholdVent = true, CalderaDragonCorpse = true,
	ElderCap = true, CandleAltar = true, VelmariLampPost = true, LampNiche = true, CapShelter = true, Barricade = true,
	RotcapTower = true, OssuaryBones = true, RotcapCluster = true,
	WebbedArchway = true, SilkSpire = true, BroodEggClutch = true, StolenLampCocoon = true, SilkWindlass = true, LastLampShrine = true,
	ShroudSpire = true, EggRack = true,
	RimefallIcefall = true, HuntersLodge = true, FisherHut = true, IceFloeSlab = true, WardStarShieldMarker = true,
	BarracksBlock = true, KennelRow = true, FrozenSoldier = true, MessCauldron = true,
	CrevasseCartPillar = true, GlacierShrine = true, TollShelterRuins = true, FrozenBareTree = true,
	IceCaveOverhang = true, WhiteguardTower = true, FrozenSiegeLadder = true, FrozenTrebuchet = true,
	GothicPillarColonnade = true, ThroneOfIcicles = true, FrozenAvalancheWave = true, ShatteredRoseWindow = true, PermafrostCage = true,
	OreCrusherJaw = true, CoalHopper = true, TankLocomotive = true, SignalCabin = true, FurnaceGateDoors = true, WaterTower = true, FlueStack = true,
	ConstructShell = true, AssemblyScaffold = true, CraneTrolley = true, ControlCabin = true, FurnaceBox = true, WallGear = true, HydraulicJack = true,
	FurnaceTower = true, TiltingCrucible = true, FurnaceDoorGiant = true, SlagLadleCart = true, JibCrane = true, BellowsDuctRun = true,
	ForkedBoltTotem = true, SplitGraniteTor = true, HighlandWindmill = true, ShepherdCroft = true, DolmenBellGate = true, WindBentPine = true,
}) :: { [string]: boolean }

return TowerBiomeKit
