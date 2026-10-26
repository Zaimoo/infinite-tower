--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroCostumes.luau
-- Every hero's appearance as data (hero-rig-rebuild-plan.md, Phase 3): body type, body
-- colours, face decal and costume pieces. Pure data plus a lint, so the offline test runner
-- can check every costume. HeroCostumeBuilder turns an entry into Parts on a HeroRig.
--
-- Authoring rules (checked by HeroCostumes.Lint):
--   * Positions and sizes are in the bone's space on the Standard body; other body types
--     scale them horizontally with the bone.
--   * One bone per piece: a piece may not overlap any other bone in the rest pose, unless
--     it is marked Loose (hair, skirts, capes and mantles that are meant to clip like cloth).
--   * No weapons, shields or other gear: those come from HeroSockets.
--   * No asset IDs other than the face decal.

local HeroRigSpec = require(script.Parent:WaitForChild("HeroRigSpec"))
local HeroCostumeMath = require(script.Parent:WaitForChild("HeroCostumeMath"))

export type RGB = { number }

export type Colors = {
	Skin: RGB,
	UpperTorso: RGB,
	LowerTorso: RGB,
	UpperArm: RGB,
	LowerArm: RGB,
	Hand: RGB?, -- defaults to Skin
	UpperLeg: RGB,
	LowerLeg: RGB,
	Foot: RGB,
}

export type Costume = {
	HeroId: string,
	BodyType: HeroRigSpec.BodyTypeName,
	Face: string?,
	Colors: Colors,
	Pieces: { HeroCostumeMath.Piece },
}

local HeroCostumes = {}

HeroCostumes.PART_BUDGET = 60
HeroCostumes.DEFAULT_FACE = "rbxassetid://144080495"
HeroCostumes.SHAPES = table.freeze({ Block = true, Wedge = true, Ball = true, Cylinder = true })
HeroCostumes.MATERIALS = table.freeze({ SmoothPlastic = true, Neon = true, Metal = true, Fabric = true, Wood = true, Glass = true })

-- Overlap tolerance: bones are shrunk by this much before testing, so pieces that sit
-- flush against a neighbouring bone (belts, plates) do not count as overlapping it.
HeroCostumes.LINT_MARGIN = 0.1

local function piece(name: string, bone: string, size: RGB, position: RGB, color: RGB, extra: { [string]: any }?): HeroCostumeMath.Piece
	local p: any = { Name = name, Bone = bone, Size = size, Position = position, Color = color }
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	return p
end

local function costume(heroId: string, bodyType: HeroRigSpec.BodyTypeName, colors: Colors, pieces: { HeroCostumeMath.Piece }, face: string?): Costume
	return table.freeze({ HeroId = heroId, BodyType = bodyType, Colors = colors, Pieces = pieces, Face = face or HeroCostumes.DEFAULT_FACE })
end

local NEON = { Material = "Neon" }
local METAL = { Material = "Metal" }
local WEDGE = { Shape = "Wedge" }
local LOOSE = { Loose = true }

local function with(...: { [string]: any }): { [string]: any }
	local merged = {}
	for _, t in { ... } do
		for k, v in t do
			merged[k] = v
		end
	end
	return merged
end

local COSTUMES: { Costume } = {}

-- 1. HAN (1★ Striker - Shonen Swordsman) ---------------------------------------------
do
	local skin, hair, blue, white, navy = { 255, 224, 196 }, { 24, 38, 75 }, { 70, 155, 255 }, { 245, 245, 250 }, { 25, 30, 48 }
	table.insert(COSTUMES, costume("hero_han", "Standard", {
		Skin = skin, UpperTorso = blue, LowerTorso = navy, UpperArm = blue, LowerArm = skin,
		UpperLeg = navy, LowerLeg = navy, Foot = navy,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, hair),
		piece("SpikeTop1", "Head", { 0.35, 0.75, 0.4 }, { 0, 0.85, 0.15 }, hair, with(WEDGE, { Rotation = { 25, 0, 0 } })),
		piece("SpikeTop2", "Head", { 0.35, 0.65, 0.4 }, { -0.35, 0.75, 0.05 }, hair, with(WEDGE, { Rotation = { 15, 0, -20 } })),
		piece("SpikeTop3", "Head", { 0.35, 0.65, 0.4 }, { 0.35, 0.75, 0.05 }, hair, with(WEDGE, { Rotation = { 15, 0, 20 } })),
		piece("SpikeBack", "Head", { 0.8, 0.55, 0.35 }, { 0, 0.35, 0.65 }, hair, with(WEDGE, { Rotation = { 45, 0, 0 } })),
		piece("Bangs", "Head", { 1.15, 0.3, 0.3 }, { 0, 0.38, -0.58 }, hair, { Rotation = { -15, 0, 0 } }),
		piece("CollarTrim", "UpperTorso", { 0.9, 0.15, 0.5 }, { 0, 0.72, -0.32 }, white),
		piece("BeltSash", "LowerTorso", { 2.05, 0.35, 1.05 }, { 0, 0, 0 }, blue),
		piece("BeltKnot", "LowerTorso", { 0.4, 0.6, 0.25 }, { -0.5, -0.25, -0.62 }, blue, LOOSE),
		piece("BracerL", "LeftLowerArm", { 1.05, 0.65, 1.05 }, { 0, -0.18, 0 }, navy),
		piece("BracerR", "RightLowerArm", { 1.05, 0.65, 1.05 }, { 0, -0.18, 0 }, navy),
	}))
end

-- 2. AARON (2★ Vanguard - Heavy Anime Paladin) ----------------------------------------
do
	local skin, hair, steel, gold = { 255, 224, 196 }, { 235, 215, 150 }, { 210, 215, 225 }, { 255, 185, 60 }
	table.insert(COSTUMES, costume("hero_aaron", "Heavy", {
		Skin = skin, UpperTorso = steel, LowerTorso = steel, UpperArm = steel, LowerArm = steel,
		UpperLeg = steel, LowerLeg = steel, Foot = steel,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, hair),
		piece("HairBangs", "Head", { 1.15, 0.4, 0.35 }, { 0, 0.35, -0.58 }, hair, { Rotation = { -15, 0, 0 } }),
		piece("ChestPlate", "UpperTorso", { 2.05, 1.4, 1.15 }, { 0, 0.05, 0 }, steel, METAL),
		piece("GoldCross", "UpperTorso", { 0.6, 0.9, 0.1 }, { 0, 0.1, -0.62 }, gold, METAL),
		piece("PauldronL", "LeftUpperArm", { 1.3, 0.7, 1.3 }, { -0.25, 0.45, 0 }, steel, METAL),
		piece("PauldronL_Trim", "LeftUpperArm", { 1.35, 0.15, 1.35 }, { -0.25, 0.45, 0 }, gold, METAL),
		piece("PauldronR", "RightUpperArm", { 1.3, 0.7, 1.3 }, { 0.25, 0.45, 0 }, steel, METAL),
		piece("PauldronR_Trim", "RightUpperArm", { 1.35, 0.15, 1.35 }, { 0.25, 0.45, 0 }, gold, METAL),
	}))
end

-- 3. CATIO (3★ Miner - Steampunk Cat-Engineer) -----------------------------------------
do
	local skin, amber, vest, leather, cyan, pink = { 255, 220, 190 }, { 215, 155, 40 }, { 255, 205, 75 }, { 120, 80, 45 }, { 80, 225, 255 }, { 255, 180, 190 }
	local slate = { 45, 50, 65 }
	table.insert(COSTUMES, costume("hero_catio", "Standard", {
		Skin = skin, UpperTorso = vest, LowerTorso = leather, UpperArm = vest, LowerArm = skin,
		UpperLeg = slate, LowerLeg = slate, Foot = leather,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, amber),
		piece("CatEarL", "Head", { 0.35, 0.65, 0.35 }, { -0.45, 0.85, 0.05 }, amber, with(WEDGE, { Rotation = { 0, -15, 10 } })),
		piece("CatEarInnerL", "Head", { 0.18, 0.35, 0.05 }, { -0.45, 0.82, -0.12 }, pink),
		piece("CatEarR", "Head", { 0.35, 0.65, 0.35 }, { 0.45, 0.85, 0.05 }, amber, with(WEDGE, { Rotation = { 0, 15, -10 } })),
		piece("CatEarInnerR", "Head", { 0.18, 0.35, 0.05 }, { 0.45, 0.82, -0.12 }, pink),
		piece("GoggleStrap", "Head", { 1.26, 0.2, 1.26 }, { 0, 0.3, 0 }, leather),
		piece("LensL", "Head", { 0.2, 0.38, 0.38 }, { -0.28, 0, -0.6 }, cyan, with(NEON, { Shape = "Cylinder", RelativeTo = "GoggleStrap", Rotation = { 0, 90, 0 } })),
		piece("LensR", "Head", { 0.2, 0.38, 0.38 }, { 0.28, 0, -0.6 }, cyan, with(NEON, { Shape = "Cylinder", RelativeTo = "GoggleStrap", Rotation = { 0, 90, 0 } })),
		piece("ToolBelt", "LowerTorso", { 2.05, 0.3, 1.05 }, { 0, 0, 0 }, leather),
		piece("PouchL", "LowerTorso", { 0.45, 0.4, 0.35 }, { -0.62, 0, -0.66 }, leather),
		piece("PouchR", "LowerTorso", { 0.45, 0.4, 0.35 }, { 0.62, 0, -0.66 }, leather),
	}))
end

-- 4. VALERIA (4★ Healer - Emerald Guardian) --------------------------------------------
do
	local skin, hair, emerald, gold, mint, white = { 255, 226, 210 }, { 240, 225, 170 }, { 60, 160, 120 }, { 255, 205, 75 }, { 100, 232, 175 }, { 240, 245, 240 }
	table.insert(COSTUMES, costume("hero_valeria", "Slim", {
		Skin = skin, UpperTorso = emerald, LowerTorso = emerald, UpperArm = emerald, LowerArm = skin,
		UpperLeg = white, LowerLeg = white, Foot = gold,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, hair),
		piece("HairCirclet", "Head", { 1.26, 0.15, 1.26 }, { 0, 0.35, 0 }, gold, METAL),
		piece("CircletGem", "Head", { 0.3, 0.3, 0.15 }, { 0, 0.35, -0.63 }, mint, with(NEON, { Shape = "Ball" })),
		piece("HealerSkirt", "LowerTorso", { 2.3, 1.3, 1.5 }, { 0, -0.45, 0 }, emerald, LOOSE),
		piece("HealerTrim", "LowerTorso", { 2.35, 0.2, 1.55 }, { 0, -1.05, 0 }, gold, LOOSE),
	}))
end

-- 5. IGNIS (5★ Vanguard - Blazing Berserker) -------------------------------------------
do
	local skin, flame, crimson, magma = { 255, 218, 190 }, { 255, 80, 20 }, { 150, 25, 25 }, { 255, 160, 40 }
	table.insert(COSTUMES, costume("hero_ignis", "Heavy", {
		Skin = skin, UpperTorso = crimson, LowerTorso = crimson, UpperArm = crimson, LowerArm = crimson,
		UpperLeg = crimson, LowerLeg = crimson, Foot = magma,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, flame),
		piece("FlameHorn1", "Head", { 0.35, 0.9, 0.35 }, { -0.35, 0.85, 0.1 }, magma, with(WEDGE, NEON, { Rotation = { 25, 0, -15 } })),
		piece("FlameHorn2", "Head", { 0.35, 0.9, 0.35 }, { 0.35, 0.85, 0.1 }, magma, with(WEDGE, NEON, { Rotation = { 25, 0, 15 } })),
		piece("ChestPlate", "UpperTorso", { 2.1, 1.4, 1.2 }, { 0, 0.05, 0 }, crimson, METAL),
		piece("MagmaCore", "UpperTorso", { 0.6, 0.6, 0.2 }, { 0, 0.1, -0.62 }, magma, with(NEON, { Shape = "Ball" })),
		piece("PauldronL", "LeftUpperArm", { 1.35, 0.8, 1.35 }, { -0.25, 0.45, 0 }, magma, NEON),
		piece("PauldronR", "RightUpperArm", { 1.35, 0.8, 1.35 }, { 0.25, 0.45, 0 }, magma, NEON),
	}))
end

-- 6. JENNA (1★ Marksman - Wind-Scout Archer) ---------------------------------------------
-- Rebuilt from the Studio-only JennaPreview inventory (Phase 0). The hood, goggles, cape and
-- crystal pauldron were catalogue meshes there; here they are Part constructions.
do
	local skin, hair, navy, capeDark = { 255, 226, 204 }, { 180, 100, 48 }, { 24, 38, 70 }, { 16, 24, 48 }
	local leather, glove, gold, brass = { 75, 45, 25 }, { 60, 42, 30 }, { 225, 175, 50 }, { 205, 160, 50 }
	local cyan, magenta, violet, green, steel, quiver = { 60, 240, 255 }, { 255, 75, 220 }, { 180, 100, 255 }, { 120, 255, 140 }, { 195, 205, 215 }, { 50, 32, 22 }
	local hairLoose = { Loose = true }
	table.insert(COSTUMES, costume("hero_jenna", "Slim", {
		Skin = skin, UpperTorso = navy, LowerTorso = navy, UpperArm = navy, LowerArm = navy, Hand = glove,
		UpperLeg = navy, LowerLeg = glove, Foot = glove,
	}, {
		-- Hair (offsets from the original attachJennaHair)
		piece("HairBase", "Head", { 1.20, 0.40, 1.15 }, { 0, 0.42, -0.05 }, hair),
		piece("HairBangs_Mid", "Head", { 0.44, 0.28, 0.16 }, { 0, 0.32, -0.56 }, hair, { Rotation = { -14, 0, 0 } }),
		piece("HairBangs_OutL", "Head", { 0.32, 0.34, 0.18 }, { -0.35, 0.28, -0.55 }, hair, { Rotation = { -12, 8, -14 } }),
		piece("HairBangs_OutR", "Head", { 0.32, 0.34, 0.18 }, { 0.35, 0.28, -0.55 }, hair, { Rotation = { -12, -8, 14 } }),
		piece("HairSide_L", "Head", { 0.16, 0.82, 0.22 }, { -0.55, -0.06, -0.47 }, hair, { Rotation = { 6, 4, -5 } }),
		piece("HairSide_R", "Head", { 0.16, 0.82, 0.22 }, { 0.55, -0.06, -0.47 }, hair, { Rotation = { 6, -4, 5 } }),
		piece("HairTress_L", "Head", { 0.20, 0.95, 0.20 }, { -0.62, -0.62, -0.32 }, hair, with(hairLoose, { Rotation = { 10, 0, -8 } })),
		piece("HairTress_R", "Head", { 0.20, 0.95, 0.20 }, { 0.62, -0.62, -0.32 }, hair, with(hairLoose, { Rotation = { 10, 0, 8 } })),
		piece("HairTressTip_L", "Head", { 0.20, 0.32, 0.20 }, { -0.70, -1.18, -0.24 }, hair, with(WEDGE, hairLoose, { Rotation = { 190, 0, -8 } })),
		piece("HairTressTip_R", "Head", { 0.20, 0.32, 0.20 }, { 0.70, -1.18, -0.24 }, hair, with(WEDGE, hairLoose, { Rotation = { 190, 0, 8 } })),
		-- Open hood (was a catalogue mesh): top, back and two side panels, face left clear
		piece("HoodTop", "Head", { 1.42, 0.22, 1.32 }, { 0, 0.7, 0.04 }, navy, { Material = "Fabric" }),
		piece("HoodBack", "Head", { 1.42, 1.25, 0.22 }, { 0, 0.02, 0.68 }, navy, { Material = "Fabric" }),
		piece("HoodSideL", "Head", { 0.2, 1.15, 1.2 }, { -0.7, 0.02, 0.08 }, navy, { Material = "Fabric" }),
		piece("HoodSideR", "Head", { 0.2, 1.15, 1.2 }, { 0.7, 0.02, 0.08 }, navy, { Material = "Fabric" }),
		-- Steampunk goggles on the hood brow (was a catalogue mesh)
		piece("GoggleBand", "Head", { 1.46, 0.16, 1.36 }, { 0, 0.46, 0.04 }, brass, METAL),
		piece("GoggleLensL", "Head", { 0.12, 0.3, 0.3 }, { -0.25, 0.46, -0.68 }, cyan, with(NEON, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("GoggleLensR", "Head", { 0.12, 0.3, 0.3 }, { 0.25, 0.46, -0.68 }, cyan, with(NEON, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		-- Upper body: harness, quiver, starry cape (upper half)
		piece("CrossHarness", "UpperTorso", { 1.7, 0.16, 0.08 }, { 0, 0.05, -0.54 }, leather, { Rotation = { 0, 0, 35 } }),
		piece("BackQuiver", "UpperTorso", { 0.48, 2.0, 0.48 }, { 0.35, 0.25, 0.85 }, quiver, { Rotation = { 0, 0, -25 } }),
		piece("QuiverGoldRim", "UpperTorso", { 0.56, 0.14, 0.56 }, { 0, 0.98, 0 }, gold, with(METAL, { RelativeTo = "BackQuiver" })),
		piece("CapeUpper", "UpperTorso", { 1.8, 1.55, 0.12 }, { 0, -0.02, 0.58 }, capeDark, { Material = "Fabric" }),
		piece("CapeStar_1", "UpperTorso", { 0.16, 0.16, 0.04 }, { -0.45, 0.2, 0.08 }, gold, with(NEON, { RelativeTo = "CapeUpper", Rotation = { 0, 0, 45 } })),
		piece("CapeStar_2", "UpperTorso", { 0.16, 0.16, 0.04 }, { 0.4, -0.35, 0.08 }, gold, with(NEON, { RelativeTo = "CapeUpper", Rotation = { 0, 0, 45 } })),
		-- Belt, pouch, potions, coat tails, cape (lower half)
		piece("UtilityBelt", "LowerTorso", { 2.05, 0.32, 1.05 }, { 0, 0, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.42, 0.36, 0.1 }, { 0, 0, -0.56 }, gold, METAL),
		piece("LeatherPouch", "LowerTorso", { 0.24, 0.38, 0.42 }, { 0.75, -0.04, -0.5 }, leather),
		piece("PotionVial_1", "LowerTorso", { 0.16, 0.36, 0.16 }, { -0.4, 0, -0.6 }, magenta, NEON),
		piece("PotionVial_2", "LowerTorso", { 0.16, 0.36, 0.16 }, { -0.62, 0, -0.6 }, green, NEON),
		piece("CoatTailL", "LowerTorso", { 0.95, 0.65, 0.08 }, { -0.48, -0.5, 0.55 }, navy, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, 0 } })),
		piece("CoatTailR", "LowerTorso", { 0.95, 0.65, 0.08 }, { 0.48, -0.5, 0.55 }, navy, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, 0 } })),
		piece("CapeLower", "LowerTorso", { 1.8, 1.4, 0.12 }, { 0, -0.8, 0.66 }, capeDark, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, 0 } })),
		-- Crystal pauldron on the right shoulder (was a catalogue mesh)
		piece("PauldronPlate", "RightUpperArm", { 1.1, 0.32, 1.1 }, { 0.1, 0.45, 0 }, steel, with(METAL, { Rotation = { 0, 0, -12 } })),
		piece("PauldronCrystal_1", "RightUpperArm", { 0.18, 0.65, 0.18 }, { 0.15, 0.4, -0.28 }, magenta, with(NEON, { RelativeTo = "PauldronPlate", Rotation = { 0, 0, -20 } })),
		piece("PauldronCrystal_2", "RightUpperArm", { 0.18, 0.75, 0.18 }, { 0.3, 0.45, 0 }, cyan, with(NEON, { RelativeTo = "PauldronPlate", Rotation = { 0, 0, -20 } })),
		piece("PauldronCrystal_3", "RightUpperArm", { 0.18, 0.85, 0.18 }, { 0.15, 0.5, 0.28 }, violet, with(NEON, { RelativeTo = "PauldronPlate", Rotation = { 0, 0, -20 } })),
		-- Forearm cuffs sit fully on the forearm, clear of the hand
		piece("LeatherCuffL", "LeftLowerArm", { 1.05, 0.38, 1.05 }, { 0, -0.32, 0 }, leather),
		piece("CuffGoldBandL", "LeftLowerArm", { 1.06, 0.08, 1.06 }, { 0, -0.1, 0 }, gold, METAL),
		piece("LeatherCuffR", "RightLowerArm", { 1.05, 0.38, 1.05 }, { 0, -0.32, 0 }, leather),
		piece("CuffGoldBandR", "RightLowerArm", { 1.06, 0.08, 1.06 }, { 0, -0.1, 0 }, gold, METAL),
		-- Thigh-high boots: skin gap above the knee, gold cuff at the boot top
		piece("SkinGapL", "LeftUpperLeg", { 1.02, 0.22, 1.02 }, { 0, -0.48, 0 }, skin),
		piece("SkinGapR", "RightUpperLeg", { 1.02, 0.22, 1.02 }, { 0, -0.48, 0 }, skin),
		piece("BootGoldCuffL", "LeftLowerLeg", { 1.06, 0.12, 1.06 }, { 0, 0.52, 0 }, gold, METAL),
		piece("BootGoldCuffR", "RightLowerLeg", { 1.06, 0.12, 1.06 }, { 0, 0.52, 0 }, gold, METAL),
	}, "rbxassetid://800114796"))
end

-- 7. VELKIST (2★ Striker - Crimson Rogue Assassin) ---------------------------------------
do
	local skin, black, dark, crimson = { 245, 225, 215 }, { 20, 20, 25 }, { 28, 28, 35 }, { 235, 55, 85 }
	table.insert(COSTUMES, costume("hero_velkist", "Slim", {
		Skin = skin, UpperTorso = dark, LowerTorso = dark, UpperArm = dark, LowerArm = dark,
		UpperLeg = dark, LowerLeg = dark, Foot = dark,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, black),
		piece("AsymBangs", "Head", { 0.65, 0.75, 0.35 }, { -0.35, 0.2, -0.6 }, black, { Rotation = { 0, 0, 20 } }),
		piece("ScarfWrap", "UpperTorso", { 1.7, 0.4, 1.2 }, { 0, 0.8, 0 }, crimson, with(LOOSE, { Material = "Fabric" })),
		piece("ScarfTail1", "UpperTorso", { 0.35, 2.2, 0.15 }, { -0.35, -0.85, 0.65 }, crimson, with(LOOSE, { Material = "Fabric", RelativeTo = "ScarfWrap", Rotation = { 25, 0, -15 } })),
		piece("ScarfTail2", "UpperTorso", { 0.35, 2.0, 0.15 }, { 0.35, -0.75, 0.65 }, crimson, with(LOOSE, { Material = "Fabric", RelativeTo = "ScarfWrap", Rotation = { 30, 0, 15 } })),
		piece("ThighSheath", "RightUpperLeg", { 0.3, 1.0, 0.3 }, { 0.22, 0, -0.62 }, dark, { Rotation = { 0, 0, 10 } }),
	}))
end

-- 8. EOLKA (3★ Scholar - Pyromancer Sorceress) --------------------------------------------
do
	local skin, magenta, violet, pink = { 255, 230, 220 }, { 235, 60, 175 }, { 75, 25, 85 }, { 255, 80, 195 }
	table.insert(COSTUMES, costume("hero_eolka", "Slim", {
		Skin = skin, UpperTorso = violet, LowerTorso = violet, UpperArm = violet, LowerArm = violet,
		UpperLeg = violet, LowerLeg = violet, Foot = pink,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, magenta),
		piece("BraidL", "Head", { 0.32, 1.8, 0.32 }, { -0.7, -0.2, -0.15 }, magenta, LOOSE),
		piece("BraidR", "Head", { 0.32, 1.8, 0.32 }, { 0.7, -0.2, -0.15 }, magenta, LOOSE),
		piece("RobeSkirt", "LowerTorso", { 2.3, 1.3, 1.5 }, { 0, -0.45, 0 }, violet, with(LOOSE, { Material = "Fabric" })),
		piece("RobeTrim", "LowerTorso", { 2.35, 0.2, 1.55 }, { 0, -1.05, 0 }, pink, LOOSE),
	}))
end

-- 9. MORRIGAN (4★ Vanguard - Void Nightblade) ---------------------------------------------
do
	local skin, raven, purple, amethyst = { 240, 235, 245 }, { 25, 20, 35 }, { 60, 35, 80 }, { 160, 100, 240 }
	table.insert(COSTUMES, costume("hero_morrigan", "Standard", {
		Skin = skin, UpperTorso = purple, LowerTorso = purple, UpperArm = purple, LowerArm = purple,
		UpperLeg = purple, LowerLeg = purple, Foot = raven,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, raven),
		piece("NightCape", "UpperTorso", { 2.2, 2.8, 0.3 }, { 0, -0.2, 0.68 }, purple, with(LOOSE, { Material = "Fabric" })),
		piece("AmethystBrooch", "UpperTorso", { 0.4, 0.4, 0.2 }, { 0, 0.6, -0.58 }, amethyst, with(NEON, { Shape = "Ball" })),
	}))
end

-- 10. SOVEREIGN ARCHON (5★ Striker - World Boss Hybrid) -----------------------------------
do
	local skin, silver, obsidian, purple, gold = { 240, 242, 255 }, { 235, 240, 255 }, { 30, 20, 45 }, { 190, 85, 255 }, { 240, 210, 120 }
	table.insert(COSTUMES, costume("hero_archon", "Standard", {
		Skin = skin, UpperTorso = obsidian, LowerTorso = obsidian, UpperArm = obsidian, LowerArm = obsidian,
		UpperLeg = obsidian, LowerLeg = obsidian, Foot = obsidian,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, silver),
		piece("HairSwept", "Head", { 1.15, 0.4, 0.4 }, { 0, 0.38, -0.58 }, silver, { Rotation = { -15, 0, 0 } }),
		piece("AstralHalo", "Head", { 1.6, 0.15, 1.6 }, { 0, 1.1, 0 }, obsidian),
		piece("HaloCore", "Head", { 0.6, 0.25, 0.6 }, { 0, 0, 0 }, purple, with(NEON, { Shape = "Ball", RelativeTo = "AstralHalo" })),
		piece("HaloSpire1", "Head", { 0.15, 0.5, 0.15 }, { 0.7, 0.25, 0 }, gold, { RelativeTo = "AstralHalo" }),
		piece("HaloSpire2", "Head", { 0.15, 0.5, 0.15 }, { -0.7, 0.25, 0 }, gold, { RelativeTo = "AstralHalo" }),
		piece("VoidMantle", "UpperTorso", { 2.4, 0.45, 1.4 }, { 0, 0.75, 0 }, obsidian, with(LOOSE, { Material = "Fabric" })),
		piece("RunicPlateChest", "UpperTorso", { 1.2, 0.8, 0.1 }, { 0, 0.2, -0.56 }, purple, NEON),
		piece("VoidWingL", "UpperTorso", { 0.15, 2.6, 0.8 }, { -1.2, 0.9, 1.25 }, purple, with(NEON, { Rotation = { 0, -25, -35 } })),
		piece("VoidWingR", "UpperTorso", { 0.15, 2.6, 0.8 }, { 1.2, 0.9, 1.25 }, purple, with(NEON, { Rotation = { 0, 25, 35 } })),
		piece("GauntletL", "LeftLowerArm", { 1.05, 0.65, 1.05 }, { 0, -0.18, 0 }, gold, METAL),
		piece("GauntletR", "RightLowerArm", { 1.05, 0.65, 1.05 }, { 0, -0.18, 0 }, gold, METAL),
	}))
end

-- 11. SOLARIS (6★ Scholar - Sun Priest) ----------------------------------------------------
do
	local skin, hair, white, gold, glow, sand = { 255, 235, 215 }, { 255, 215, 60 }, { 250, 248, 240 }, { 255, 195, 0 }, { 255, 255, 180 }, { 235, 225, 200 }
	table.insert(COSTUMES, costume("hero_solaris", "Standard", {
		Skin = skin, UpperTorso = white, LowerTorso = white, UpperArm = white, LowerArm = skin,
		UpperLeg = white, LowerLeg = sand, Foot = gold,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, hair),
		piece("SunCrown", "Head", { 1.6, 0.15, 1.6 }, { 0, 1.1, 0 }, gold, NEON),
		piece("SunCrownCore", "Head", { 0.6, 0.25, 0.6 }, { 0, 0, 0 }, glow, with(NEON, { Shape = "Ball", RelativeTo = "SunCrown" })),
		piece("SolarMantle", "UpperTorso", { 2.3, 0.4, 1.3 }, { 0, 0.75, 0 }, gold, with(LOOSE, { Material = "Fabric" })),
	}))
end

-- 12. ASTREA (7★ Marksman - Featured Astral Star-Gazer) -----------------------------------
do
	local skin, silver, dark, star, cyan = { 245, 240, 255 }, { 230, 235, 255 }, { 35, 25, 55 }, { 235, 220, 255 }, { 120, 230, 255 }
	table.insert(COSTUMES, costume("hero_astrea", "Slim", {
		Skin = skin, UpperTorso = dark, LowerTorso = dark, UpperArm = dark, LowerArm = dark,
		UpperLeg = dark, LowerLeg = dark, Foot = dark,
	}, {
		piece("HairBase", "Head", { 1.24, 0.45, 1.24 }, { 0, 0.48, -0.05 }, silver),
		piece("StarlightTiara", "Head", { 1.26, 0.2, 1.26 }, { 0, 0.4, 0 }, star, NEON),
		piece("AstralCloak", "UpperTorso", { 2.3, 2.9, 0.35 }, { 0, -0.2, 0.7 }, dark, with(LOOSE, { Material = "Fabric" })),
		piece("StarWingL", "UpperTorso", { 0.15, 2.8, 0.9 }, { -1.3, 0.95, 1.3 }, cyan, with(NEON, { Rotation = { 0, -20, -30 } })),
		piece("StarWingR", "UpperTorso", { 0.15, 2.8, 0.9 }, { 1.3, 0.95, 1.3 }, cyan, with(NEON, { Rotation = { 0, 20, 30 } })),
	}))
end

HeroCostumes.List = table.freeze(COSTUMES)
local byId: { [string]: Costume } = {}
for _, c in COSTUMES do
	byId[c.HeroId] = c
end
HeroCostumes.ById = table.freeze(byId)

-- Body part name -> colour for a costume.
function HeroCostumes.BodyColors(c: Costume): { [string]: RGB }
	local col = c.Colors
	local colors: { [string]: RGB } = {
		Head = col.Skin,
		UpperTorso = col.UpperTorso,
		LowerTorso = col.LowerTorso,
	}
	for _, side in { "Left", "Right" } do
		colors[side .. "UpperArm"] = col.UpperArm
		colors[side .. "LowerArm"] = col.LowerArm
		colors[side .. "Hand"] = col.Hand or col.Skin
		colors[side .. "UpperLeg"] = col.UpperLeg
		colors[side .. "LowerLeg"] = col.LowerLeg
		colors[side .. "Foot"] = col.Foot
	end
	return colors
end

-- Returns a list of problems (empty when the costume follows the authoring rules).
function HeroCostumes.Lint(c: Costume): { string }
	local problems: { string } = {}
	local function problem(message: string)
		table.insert(problems, `{c.HeroId}: {message}`)
	end

	if not HeroRigSpec.BODY_TYPES[c.BodyType] then
		problem(`unknown body type {c.BodyType}`)
		return problems
	end
	local layout = HeroRigSpec.Layout(c.BodyType)

	if c.Face and not string.match(c.Face, "^rbxassetid://%d+$") then
		problem(`face must be an rbxassetid, got {c.Face}`)
	end
	local partCount = #HeroRigSpec.PART_NAMES + #c.Pieces
	if partCount > HeroCostumes.PART_BUDGET then
		problem(`{partCount} parts exceeds the budget of {HeroCostumes.PART_BUDGET}`)
	end

	local names: { [string]: boolean } = {}
	for _, p in c.Pieces do
		if names[p.Name] then
			problem(`duplicate piece name {p.Name}`)
		end
		names[p.Name] = true
		if not layout.Parts[p.Bone] or p.Bone == "HumanoidRootPart" then
			problem(`{p.Name} is on unknown bone {p.Bone}`)
		end
		if p.Shape and not HeroCostumes.SHAPES[p.Shape] then
			problem(`{p.Name} has unknown shape {p.Shape}`)
		end
		if p.Material and not HeroCostumes.MATERIALS[p.Material] then
			problem(`{p.Name} has unsupported material {p.Material}`)
		end
		for _, channel in p.Color do
			if channel < 0 or channel > 255 then
				problem(`{p.Name} colour channel out of range`)
			end
		end
	end
	if #problems > 0 then
		return problems
	end

	local ok, resolved = pcall(HeroCostumeMath.Resolve, c.Pieces, layout)
	if not ok then
		problem(tostring(resolved))
		return problems
	end

	-- One bone per piece: a non-Loose piece may not overlap any other bone. Bones are shrunk
	-- by LINT_MARGIN (at most half of each dimension) so flush contact is allowed.
	local margin = HeroCostumes.LINT_MARGIN
	for _, entry in resolved do
		if entry.Piece.Loose then
			continue
		end
		local pieceBoneCenter = layout.Parts[entry.Piece.Bone].Center
		for boneName, bone in layout.Parts do
			if boneName == entry.Piece.Bone or boneName == "HumanoidRootPart" then
				continue
			end
			local half = {}
			for i = 1, 3 do
				half[i] = math.max(bone.Size[i] / 2 - margin, bone.Size[i] / 4)
			end
			if HeroCostumeMath.OverlapsAabb(entry, pieceBoneCenter, bone.Center, half) then
				problem(`{entry.Piece.Name} on {entry.Piece.Bone} overlaps {boneName}; split it per bone or mark it Loose`)
			end
		end
	end
	return problems
end

return table.freeze(HeroCostumes)
