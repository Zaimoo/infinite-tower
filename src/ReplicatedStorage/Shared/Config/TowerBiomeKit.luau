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
	| "CRYSTAL" | "CAP" | "STEM" | "ALT" | "CORAL"

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
TowerBiomeKit.ExtraTemplates = table.freeze({
	AqueductBrokenSpan = table.freeze({ Size = Vector3.new(23.055, 19.059, 16.419), Min = Vector3.new(-11.167, -0.284, -7.26), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM", "WOOD" }) }),
	CurtainWallRuins = table.freeze({ Size = Vector3.new(32.1, 18.875, 7.673), Min = Vector3.new(-16.1, -0.475, -3.178), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM", "WOOD" }) }),
	FernCluster = table.freeze({ Size = Vector3.new(9.888, 3.741, 10.323), Min = Vector3.new(-4.642, 0.0, -5.13), Roles = table.freeze({ "FOLIAGE", "MOSS", "WOOD" }) }),
	GatehouseArch = table.freeze({ Size = Vector3.new(77.0, 30.357, 14.304), Min = Vector3.new(-38.5, -0.657, -6.205), Roles = table.freeze({ "ACCENT", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	HollowStumpRim = table.freeze({ Size = Vector3.new(86.521, 29.645, 60.122), Min = Vector3.new(-43.706, -1.036, -42.875), Roles = table.freeze({ "FOLIAGE", "MOSS", "WOOD" }) }),
	ReedPondCluster = table.freeze({ Size = Vector3.new(7.493, 6.128, 7.881), Min = Vector3.new(-3.494, -0.091, -4.298), Roles = table.freeze({ "FOLIAGE", "GLOW", "WOOD" }) }),
	RootBridgeArch = table.freeze({ Size = Vector3.new(54.835, 23.185, 7.634), Min = Vector3.new(-27.434, -0.208, -3.727), Roles = table.freeze({ "GLOW", "MOSS", "TRIM", "WOOD" }) }),
	RootKnotLantern = table.freeze({ Size = Vector3.new(3.727, 9.471, 3.2), Min = Vector3.new(-1.6, -0.161, -1.6), Roles = table.freeze({ "GLOW", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	RootThrone = table.freeze({ Size = Vector3.new(31.462, 34.652, 31.541), Min = Vector3.new(-15.731, -0.652, -20.0), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	SolmereBalustrade = table.freeze({ Size = Vector3.new(16.6, 5.55, 3.0), Min = Vector3.new(-8.3, 0.0, -1.5), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM" }) }),
	SunDiscShrine = table.freeze({ Size = Vector3.new(17.127, 22.698, 9.405), Min = Vector3.new(-8.435, 0.0, -4.205), Roles = table.freeze({ "ACCENT", "GLOW", "GOLD", "MOSS", "TRIM" }) }),
	VineboundGuardian = table.freeze({ Size = Vector3.new(10.405, 14.987, 9.137), Min = Vector3.new(-5.203, -0.007, -4.63), Roles = table.freeze({ "ACCENT", "GLOW", "MOSS", "TRIM", "WOOD" }) }),
	VineboundKeep = table.freeze({ Size = Vector3.new(46.67, 47.701, 22.501), Min = Vector3.new(-23.441, -0.201, -13.767), Roles = table.freeze({ "ACCENT", "GOLD", "MOSS", "TRIM", "WOOD" }) }),
	VineboundTower = table.freeze({ Size = Vector3.new(25.625, 51.665, 24.861), Min = Vector3.new(-12.37, -1.165, -12.661), Roles = table.freeze({ "ACCENT", "MOSS", "TRIM", "WOOD" }) }),
	Waterwheel = table.freeze({ Size = Vector3.new(26.255, 27.045, 12.575), Min = Vector3.new(-12.5, -0.417, -5.827), Roles = table.freeze({ "FOLIAGE", "METAL", "MOSS", "TRIM", "WOOD" }) }),
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
}) :: { [string]: boolean }

return TowerBiomeKit
