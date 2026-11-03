--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroCostumes.luau
-- Every hero's appearance as data (hero-rig-rebuild-plan.md, Phase 3): body type, body
-- colours, face decal and costume pieces. Pure data plus a lint, so the offline test runner
-- can check every costume. HeroCostumeBuilder turns an entry into Parts on a HeroRig.
--
-- Authoring rules (checked by HeroCostumes.Lint):
--   * Positions and sizes are in the bone's space on the Standard body; other body types
--     scale them horizontally with the bone. Head pieces are authored for a 1.2-stud head
--     (HeroRigSpec.HEAD_AUTHORED_SIZE) and scale uniformly with the real head.
--   * One bone per piece: a piece may not overlap any other bone in the rest pose, unless
--     it is marked Loose (hair, skirts, capes and mantles that are meant to clip like cloth).
--   * No weapons, shields or other gear: those come from HeroSockets.
--   * No asset IDs other than the face decal and the hair meshes listed in MESHES.

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

-- FileMeshes a piece may use (piece.Mesh), with the texture each ships with. Only meshes
-- inspected in Studio (no scripts, plain accessory) go here, with their source.
HeroCostumes.MESHES = table.freeze({
	-- Creator Store 15045824818 "Black Messy Anime Hair Solo leveling" (treepside), an avatar
	-- hair accessory: HairAttachment at (0.026, 0.257, 0.034) in its Handle.
	["rbxassetid://15045614397"] = "rbxassetid://15045613896",
	-- Velkist's hair, our own: assets/hair/velkist_hair.blend, imported through Studio's 3D
	-- importer. Untextured (takes the piece colour); the importer stored it at 100x scale,
	-- centred on its bounding box and turned 180 degrees about Y.
	["rbxassetid://109684055929778"] = "",
	-- Aaron's hair, our own: AaronHair in assets/hair/hero_hair.blend, imported the same way.
	["rbxassetid://76088495641706"] = "",
	-- Jenna's hair, our own: tools/make_jenna_hair_ugc.py (assets/hair/jenna_hair_ugc.blend).
	["rbxassetid://107250648665529"] = "",
	["rbxassetid://84157414920224"] = "",
	-- Catio's hair, our own: CatioHair in assets/hair/hero_hair.blend, imported the same way.
	["rbxassetid://139185116264855"] = "",
	-- Eolka's hair, our own: tools/make_eolka_hair_ugc.py (assets/hair/eolka_hair_ugc.blend).
	["rbxassetid://123421721359927"] = "",
	-- Valeria's hair, our own: tools/make_valeria_hair_ugc.py (assets/hair/valeria_hair_ugc.blend).
	["rbxassetid://119546665528137"] = "",
	-- Morrigan's hair, our own: tools/make_morrigan_hair_ugc.py (assets/hair/morrigan_hair_ugc.blend).
	["rbxassetid://132434150044694"] = "",
	-- Archon's hair, our own: tools/make_archon_hair_ugc.py (assets/hair/archon_hair_ugc.blend).
	["rbxassetid://139133902834118"] = "",
	-- Ignis's hair, our own: tools/make_ignis_hair_ugc.py (assets/hair/ignis_hair_ugc.blend).
	["rbxassetid://101701313703578"] = "",
} :: { [string]: string })

-- Avatar hair accessory placement: a piece centred so the accessory's HairAttachment meets
-- the head's (top centre), as Humanoid accessory welding would do. Authored for the
-- HEAD_AUTHORED_SIZE head like every head piece; HeroCostumeMath scales it with the head.
local function hairAccessoryOffset(attachment: RGB): RGB
	local headTop = HeroRigSpec.HEAD_AUTHORED_SIZE / 2
	return { -attachment[1], headTop - attachment[2], -attachment[3] }
end

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
-- Wandering brawler look: messy black anime hair (mesh), cream shirt and cape,
-- leather-and-steel gauntlets, steel pauldron on the left shoulder, knee plates, greaves and
-- gold-soled boots. Face: our own decal, generated by assets/faces/make_han_face.py and
-- uploaded as an image asset.
do
	local skin, hair, shirt, collar, cape = { 236, 196, 158 }, { 22, 22, 28 }, { 225, 216, 200 }, { 238, 232, 220 }, { 214, 205, 190 }
	local leather, darkLeather, glove = { 105, 68, 45 }, { 78, 50, 34 }, { 80, 52, 36 }
	local steel, gold, shorts, boot = { 160, 168, 178 }, { 214, 170, 70 }, { 48, 45, 44 }, { 38, 44, 66 }
	table.insert(COSTUMES, costume("hero_han", "Standard", {
		Skin = skin, UpperTorso = shirt, LowerTorso = shorts, UpperArm = shirt, LowerArm = skin, Hand = glove,
		UpperLeg = shorts, LowerLeg = steel, Foot = boot,
	}, {
		-- Messy anime hair: the accessory mesh with its own texture, sized as shipped.
		piece("HairMesh", "Head", { 0.97, 0.98, 0.97 }, hairAccessoryOffset({ 0.026, 0.257, 0.034 }), hair, with(LOOSE, {
			Mesh = { MeshId = "rbxassetid://15045614397", TextureId = "rbxassetid://15045613896", Scale = { 0.9689, 0.9826, 0.9689 } },
		})),
		-- Shirt: open collar flaps and a skin V at the neckline (a diamond whose top half hides
		-- inside the head), cape hanging from the shoulders.
		piece("CollarL", "UpperTorso", { 0.5, 0.22, 0.45 }, { -0.35, 0.62, -0.25 }, collar, { Rotation = { -15, 0, 15 } }),
		piece("CollarR", "UpperTorso", { 0.5, 0.22, 0.45 }, { 0.35, 0.62, -0.25 }, collar, { Rotation = { -15, 0, -15 } }),
		piece("VNeck", "UpperTorso", { 0.42, 0.42, 0.04 }, { 0, 0.6, -0.51 }, skin, { Rotation = { 0, 0, 45 } }),
		piece("CapeUpper", "UpperTorso", { 2.0, 1.6, 0.12 }, { 0, -0.02, 0.58 }, cape, with(LOOSE, { Material = "Fabric" })),
		-- Steel pauldron with a gold rim on the left shoulder
		piece("PauldronL", "LeftUpperArm", { 1.3, 0.45, 1.25 }, { -0.15, 0.42, 0 }, steel, with(METAL, { Rotation = { 0, 0, 15 } })),
		piece("PauldronTrimL", "LeftUpperArm", { 1.34, 0.08, 1.29 }, { 0, -0.2, 0 }, gold, with(METAL, { RelativeTo = "PauldronL" })),
		-- Gauntlets: leather cuff over the forearm, gold-bordered steel plate on the outer face,
		-- steel guard on the back of the hand. Nothing covers the front of the fist, where the
		-- dagger blade leaves the grip.
		piece("GauntletCuffL", "LeftLowerArm", { 1.1, 0.75, 1.1 }, { 0, -0.12, 0 }, leather),
		piece("GauntletGoldL", "LeftLowerArm", { 0.1, 0.68, 0.9 }, { -0.55, -0.12, 0 }, gold, METAL),
		piece("GauntletPlateL", "LeftLowerArm", { 0.1, 0.56, 0.76 }, { -0.6, -0.12, 0 }, steel, METAL),
		piece("HandGuardL", "LeftHand", { 0.08, 0.3, 0.8 }, { -0.54, 0, 0 }, steel, METAL),
		piece("GauntletCuffR", "RightLowerArm", { 1.1, 0.75, 1.1 }, { 0, -0.12, 0 }, leather),
		piece("GauntletGoldR", "RightLowerArm", { 0.1, 0.68, 0.9 }, { 0.55, -0.12, 0 }, gold, METAL),
		piece("GauntletPlateR", "RightLowerArm", { 0.1, 0.56, 0.76 }, { 0.6, -0.12, 0 }, steel, METAL),
		piece("HandGuardR", "RightHand", { 0.08, 0.3, 0.8 }, { 0.54, 0, 0 }, steel, METAL),
		-- Belt with a steel buckle and two flapped pouches, cape (lower half) flaring back
		piece("Belt", "LowerTorso", { 2.06, 0.26, 1.06 }, { 0, 0.04, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.34, 0.2, 0.06 }, { 0.15, 0.04, -0.55 }, steel, METAL),
		piece("PouchL", "LowerTorso", { 0.45, 0.45, 0.28 }, { -0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapL", "LowerTorso", { 0.47, 0.16, 0.3 }, { 0, 0.17, -0.01 }, darkLeather, { RelativeTo = "PouchL" }),
		piece("PouchR", "LowerTorso", { 0.45, 0.45, 0.28 }, { 0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapR", "LowerTorso", { 0.47, 0.16, 0.3 }, { 0, 0.17, -0.01 }, darkLeather, { RelativeTo = "PouchR" }),
		piece("CapeLower", "LowerTorso", { 2.1, 2.0, 0.12 }, { 0.1, -1.1, 0.68 }, cape, with(LOOSE, { Material = "Fabric", Rotation = { -10, 0, 0 } })),
		-- Legs: skin above the knee, gold-rimmed steel knee plates, gold band on the greaves,
		-- navy boots on gold soles.
		piece("SkinGapL", "LeftUpperLeg", { 1.02, 0.25, 1.02 }, { 0, -0.47, 0 }, skin),
		piece("SkinGapR", "RightUpperLeg", { 1.02, 0.25, 1.02 }, { 0, -0.47, 0 }, skin),
		piece("KneeRimL", "LeftLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadL", "LeftLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, steel, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimL" })),
		piece("GreaveTrimL", "LeftLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.05, 0 }, gold, METAL),
		piece("KneeRimR", "RightLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadR", "RightLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, steel, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimR" })),
		piece("GreaveTrimR", "RightLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.05, 0 }, gold, METAL),
		piece("BootL", "LeftFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold),
		piece("BootR", "RightFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold),
	}, "rbxassetid://121433999720755"))
end

-- 2. AARON (2★ Vanguard - Heavy Anime Paladin) ----------------------------------------
-- Reluctant squire look: blond hair, white laced shirt under an open brown vest, buckled leather
-- forearm bands over steel bracers, black fingerless gloves, belt with pouches and a torn sash,
-- maroon trousers, dark knee plates and greaves. Face: our own stern decal, generated by
-- assets/faces/make_aaron_face.py. Hair: our Blender mesh (AaronHair in assets/hair/hero_hair.blend).
do
	local skin, hair, shirt, vest, lace = { 244, 208, 172 }, { 222, 192, 133 }, { 236, 234, 230 }, { 92, 52, 42 }, { 60, 38, 28 }
	local leather, darkLeather, strap, steel, gold = { 100, 62, 42 }, { 70, 44, 32 }, { 30, 28, 30 }, { 150, 150, 158 }, { 200, 160, 70 }
	local cloth, pants, bronze, greave, boot = { 170, 140, 120 }, { 110, 40, 42 }, { 72, 56, 46 }, { 62, 46, 38 }, { 58, 40, 34 }
	table.insert(COSTUMES, costume("hero_aaron", "Heavy", {
		Skin = skin, UpperTorso = shirt, LowerTorso = pants, UpperArm = shirt, LowerArm = shirt, Hand = strap,
		UpperLeg = pants, LowerLeg = greave, Foot = boot,
	}, {
		-- Hair mesh: modelled around a 1.2-stud head; centred on the export's bounding box, and
		-- turned 180 degrees to undo the importer's rotation.
		piece("HairMesh", "Head", { 1.91, 1.66, 1.58 }, { 0, 0.248, 0.061 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://76088495641706", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Open vest over the laced shirt
		piece("VestL", "UpperTorso", { 0.7, 1.62, 1.08 }, { -0.68, 0, 0 }, vest, { Material = "Fabric" }),
		piece("VestR", "UpperTorso", { 0.7, 1.62, 1.08 }, { 0.68, 0, 0 }, vest, { Material = "Fabric" }),
		piece("VestBack", "UpperTorso", { 2.08, 1.62, 0.2 }, { 0, 0, 0.48 }, vest, { Material = "Fabric" }),
		piece("ShirtNeck", "UpperTorso", { 0.36, 0.36, 0.04 }, { 0, 0.62, -0.51 }, skin, { Rotation = { 0, 0, 45 } }),
		piece("LaceA", "UpperTorso", { 0.3, 0.04, 0.05 }, { 0, 0.42, -0.525 }, lace, { Rotation = { 0, 0, 35 } }),
		piece("LaceB", "UpperTorso", { 0.3, 0.04, 0.05 }, { 0, 0.42, -0.525 }, lace, { Rotation = { 0, 0, -35 } }),
		-- Forearms: buckled leather band, steel bracer with a gold rim; black fingerless gloves
		piece("ArmStrapL", "LeftLowerArm", { 1.1, 0.22, 1.1 }, { 0, 0.18, 0 }, leather),
		piece("ArmStrapR", "RightLowerArm", { 1.1, 0.22, 1.1 }, { 0, 0.18, 0 }, leather),
		piece("StrapBuckleR", "RightLowerArm", { 0.25, 0.14, 0.06 }, { 0, 0.18, -0.57 }, steel, METAL),
		piece("BracerL", "LeftLowerArm", { 1.1, 0.42, 1.1 }, { 0, -0.3, 0 }, steel, METAL),
		piece("BracerR", "RightLowerArm", { 1.1, 0.42, 1.1 }, { 0, -0.3, 0 }, steel, METAL),
		piece("BracerRimL", "LeftLowerArm", { 1.12, 0.07, 1.12 }, { 0, -0.08, 0 }, gold, METAL),
		piece("BracerRimR", "RightLowerArm", { 1.12, 0.07, 1.12 }, { 0, -0.08, 0 }, gold, METAL),
		-- Belt, pouches, torn sash and leather flaps at the hips
		piece("Belt", "LowerTorso", { 2.08, 0.26, 1.08 }, { 0, 0.04, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.34, 0.2, 0.06 }, { 0.15, 0.04, -0.56 }, steel, METAL),
		piece("PouchL", "LowerTorso", { 0.45, 0.45, 0.28 }, { -0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapL", "LowerTorso", { 0.47, 0.16, 0.3 }, { 0, 0.17, -0.01 }, darkLeather, { RelativeTo = "PouchL" }),
		piece("PouchR", "LowerTorso", { 0.45, 0.45, 0.28 }, { 0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapR", "LowerTorso", { 0.47, 0.16, 0.3 }, { 0, 0.17, -0.01 }, darkLeather, { RelativeTo = "PouchR" }),
		piece("SashTatterL", "LowerTorso", { 0.06, 0.7, 0.45 }, { -0.3, -0.45, -0.58 }, cloth, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("SashTatterR", "LowerTorso", { 0.06, 0.6, 0.4 }, { 0.22, -0.42, -0.6 }, cloth, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, -90, 180 } })),
		piece("HipFlapL", "LowerTorso", { 0.1, 0.8, 0.8 }, { -1.02, -0.45, 0.05 }, darkLeather, with(WEDGE, LOOSE, { Rotation = { 180, 0, 0 } })),
		piece("HipFlapR", "LowerTorso", { 0.1, 0.8, 0.8 }, { 1.02, -0.45, 0.05 }, darkLeather, with(WEDGE, LOOSE, { Rotation = { 180, 0, 0 } })),
		-- Legs: strap above the knee, gold-rimmed dark knee plates, greaves, boots on gold soles
		piece("KneeStrapL", "LeftUpperLeg", { 1.05, 0.12, 1.05 }, { 0, -0.45, 0 }, strap),
		piece("KneeStrapR", "RightUpperLeg", { 1.05, 0.12, 1.05 }, { 0, -0.45, 0 }, strap),
		piece("KneeRimL", "LeftLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadL", "LeftLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, bronze, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimL" })),
		piece("KneeRimR", "RightLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadR", "RightLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, bronze, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimR" })),
		piece("GreaveTrimL", "LeftLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.05, 0 }, gold, METAL),
		piece("GreaveTrimR", "RightLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.05, 0 }, gold, METAL),
		piece("BootL", "LeftFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold),
		piece("BootR", "RightFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold),
	}, "rbxassetid://135079238224097"))
end

-- 3. CATIO (3★ Royal Scholar - High Inquisitor / Archbishop) -----------------------------
-- Remodelled from reference image: white ceremonial mantle with gold borders, dark navy sash
-- with hanging ribbon and silk tassel, gold sunburst brooch with sapphire center gem and
-- shoulder sapphire medallions with silver swag chains, boxy kimono sleeve pauldrons,
-- pleated dark charcoal hakama trousers with gold cuffs, and gold-capped heavy boots.
-- Hair: long layered dark navy anime wolf-cut bob (CatioHair in assets/hair/hero_hair.blend).
do
	local skin = { 252, 230, 212 }
	local hair = { 45, 51, 74 } -- #2D334A Dark Slate Navy
	local white = { 246, 248, 250 }
	local gold = { 228, 185, 95 }
	local darkGold = { 165, 125, 55 }
	local navy = { 28, 36, 66 }
	local darkNavy = { 18, 24, 45 }
	local sapphire = { 25, 100, 240 }
	local silver = { 210, 215, 225 }
	local charcoal = { 32, 36, 48 }
	local bootBlack = { 25, 26, 32 }
	local tasselWhite = { 240, 242, 245 }

	table.insert(COSTUMES, costume("hero_catio", "Standard", {
		Skin = skin, UpperTorso = white, LowerTorso = navy, UpperArm = white, LowerArm = navy,
		Hand = skin, UpperLeg = charcoal, LowerLeg = charcoal, Foot = bootBlack,
	}, {
		-- 1. Hair mesh: authored around 1.2-stud head; centred on export's bounding box
		piece("HairMesh", "Head", { 1.79, 1.70, 1.62 }, { 0, 0.108, 0.043 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://139185116264855", Scale = { 0.01, 0.01, 0.01 } },
		})),

		-- 2. Hood / Cowl (folded back on the neck)
		piece("HoodCowlBack", "UpperTorso", { 2.08, 0.65, 0.45 }, { 0, 0.72, 0.48 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("HoodCowlInner", "UpperTorso", { 1.88, 0.55, 0.35 }, { 0, 0.76, 0.44 }, darkNavy, with(LOOSE, { Material = "Fabric" })),
		piece("HoodTrimGold", "UpperTorso", { 2.12, 0.08, 0.47 }, { 0, 1.04, 0.48 }, gold, with(LOOSE, METAL)),
		piece("CollarWhite", "UpperTorso", { 1.25, 0.35, 1.05 }, { 0, 0.85, -0.05 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("CollarTrim", "UpperTorso", { 0.06, 0.36, 1.06 }, { 0, 0.85, -0.06 }, gold, with(LOOSE, METAL)),

		-- 3. Royal Sapphire Medallions & Silver Swag Chains
		piece("BroochCenterRim", "UpperTorso", { 0.55, 0.55, 0.12 }, { 0, 0.48, -0.56 }, gold, METAL),
		piece("BroochCenterGem", "UpperTorso", { 0.38, 0.38, 0.16 }, { 0, 0.48, -0.58 }, sapphire, with(NEON, { Shape = "Ball" })),
		piece("BroochShoulderL", "UpperTorso", { 0.34, 0.34, 0.08 }, { -0.72, 0.58, -0.54 }, gold, METAL),
		piece("BroochGemL", "UpperTorso", { 0.22, 0.22, 0.12 }, { -0.72, 0.58, -0.56 }, sapphire, with(NEON, { Shape = "Ball" })),
		piece("BroochShoulderR", "UpperTorso", { 0.34, 0.34, 0.08 }, { 0.72, 0.58, -0.54 }, gold, METAL),
		piece("BroochGemR", "UpperTorso", { 0.22, 0.22, 0.12 }, { 0.72, 0.58, -0.56 }, sapphire, with(NEON, { Shape = "Ball" })),
		piece("ChestChainA", "UpperTorso", { 1.00, 0.04, 0.06 }, { 0, 0.30, -0.54 }, silver, METAL),
		piece("ChestChainB", "UpperTorso", { 0.80, 0.04, 0.06 }, { 0, 0.20, -0.53 }, silver, METAL),
		piece("BroochCharm", "UpperTorso", { 0.15, 0.25, 0.05 }, { 0, 0.18, -0.55 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),

		-- 4. White Mantle & Front Lapels
		piece("MantleFrontL", "UpperTorso", { 0.75, 1.58, 1.08 }, { -0.66, 0.02, 0.02 }, white, { Material = "Fabric" }),
		piece("MantleFrontR", "UpperTorso", { 0.75, 1.58, 1.08 }, { 0.66, 0.02, 0.02 }, white, { Material = "Fabric" }),
		piece("MantleBack", "UpperTorso", { 2.08, 1.58, 0.18 }, { 0, 0.02, 0.50 }, white, { Material = "Fabric" }),
		piece("MantleTrimL", "UpperTorso", { 0.06, 1.60, 0.08 }, { -0.28, 0.02, -0.53 }, gold, METAL),
		piece("MantleTrimR", "UpperTorso", { 0.06, 1.60, 0.08 }, { 0.28, 0.02, -0.53 }, gold, METAL),

		-- 5. Waist Sash, Long Decorative Ribbon & Silk Tassel
		piece("WaistSash", "LowerTorso", { 2.06, 0.38, 1.06 }, { 0, 0.01, 0.0 }, navy, { Material = "Fabric" }),
		piece("SashGoldTrim", "LowerTorso", { 2.08, 0.06, 1.08 }, { 0, -0.16, 0.0 }, gold, METAL),
		piece("SashRibbon", "LowerTorso", { 0.42, 1.35, 0.08 }, { 0.15, -0.58, -0.56 }, navy, with(LOOSE, { Material = "Fabric" })),
		piece("SashTasselRing", "LowerTorso", { 0.18, 0.18, 0.06 }, { -0.16, -0.22, -0.56 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, 45 } })),
		piece("SashTassel", "LowerTorso", { 0.16, 0.50, 0.12 }, { -0.16, -0.52, -0.55 }, tasselWhite, with(LOOSE, { Material = "Fabric" })),

		-- 6. Lower Robe Coat Tails
		piece("CoatTailL", "LowerTorso", { 0.85, 1.35, 1.15 }, { -0.74, -0.65, 0.04 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("CoatTailR", "LowerTorso", { 0.85, 1.35, 1.15 }, { 0.74, -0.65, 0.04 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("CoatTailBack", "LowerTorso", { 2.12, 1.35, 0.20 }, { 0, -0.65, 0.52 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("CoatTrimL", "LowerTorso", { 0.88, 0.08, 1.18 }, { -0.74, -1.30, 0.04 }, gold, with(LOOSE, METAL)),
		piece("CoatTrimR", "LowerTorso", { 0.88, 0.08, 1.18 }, { 0.74, -1.30, 0.04 }, gold, with(LOOSE, METAL)),

		-- 7. Boxy Sleeve Pauldrons & Flared Cuffs
		piece("SleevePauldronL", "LeftUpperArm", { 1.25, 0.95, 1.25 }, { -0.12, 0.16, 0.0 }, white, { Material = "Fabric" }),
		piece("SleeveGoldRimL", "LeftUpperArm", { 1.28, 0.08, 1.28 }, { -0.12, -0.28, 0.0 }, gold, METAL),
		piece("SleevePauldronR", "RightUpperArm", { 1.25, 0.95, 1.25 }, { 0.12, 0.16, 0.0 }, white, { Material = "Fabric" }),
		piece("SleeveGoldRimR", "RightUpperArm", { 1.28, 0.08, 1.28 }, { 0.12, -0.28, 0.0 }, gold, METAL),
		piece("SleeveCuffL", "LeftLowerArm", { 1.24, 0.45, 1.24 }, { -0.10, -0.25, 0.0 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("SleeveCuffRimL", "LeftLowerArm", { 1.26, 0.06, 1.26 }, { -0.10, -0.46, 0.0 }, gold, with(LOOSE, METAL)),
		piece("SleeveCuffR", "RightLowerArm", { 1.24, 0.45, 1.24 }, { 0.10, -0.25, 0.0 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("SleeveCuffRimR", "RightLowerArm", { 1.26, 0.06, 1.26 }, { 0.10, -0.46, 0.0 }, gold, with(LOOSE, METAL)),

		-- 8. Trousers & Heavy Gold-Capped Boots
		piece("TrouserHemL", "LeftLowerLeg", { 1.08, 0.10, 1.08 }, { 0, -0.50, 0 }, gold, METAL),
		piece("TrouserHemR", "RightLowerLeg", { 1.08, 0.10, 1.08 }, { 0, -0.50, 0 }, gold, METAL),
		piece("BootToeL", "LeftFoot", { 1.06, 0.16, 0.35 }, { 0, -0.07, -0.45 }, gold, METAL),
		piece("BootToeR", "RightFoot", { 1.06, 0.16, 0.35 }, { 0, -0.07, -0.45 }, gold, METAL),
		piece("BootSoleL", "LeftFoot", { 1.08, 0.08, 1.25 }, { 0, -0.12, -0.08 }, darkGold, METAL),
		piece("BootSoleR", "RightFoot", { 1.08, 0.08, 1.25 }, { 0, -0.12, -0.08 }, darkGold, METAL),
	}, "rbxassetid://135079238224097"))
end

-- 4. VALERIA (4★ Healer - Emerald Guardian) --------------------------------------------
-- Sleepy field-medic priest from her reference art: fluffy shoulder-length brown hair, white and
-- green robe with gold trim, high collar with goggles resting at the neck, white pauldrons with
-- gold stars, a green tabard with a gold cross and stars, belt with potion vials and a herb
-- pouch, an open white coat skirt, dark trousers, gold-rimmed knee plates and gilded boots.
-- Face: our own decal from assets/faces/make_valeria_face.py. Hair: our Blender mesh
-- (tools/make_valeria_hair_ugc.py).
do
	local skin, hair, white, green, gold = { 240, 205, 172 }, { 110, 62, 32 }, { 236, 236, 232 }, { 62, 140, 118 }, { 214, 172, 92 }
	local leather, pants, plate, boot, steel = { 78, 52, 36 }, { 60, 42, 34 }, { 58, 40, 34 }, { 52, 38, 30 }, { 150, 150, 158 }
	local lens, potionGreen, potionPurple, pouch = { 190, 210, 215 }, { 90, 220, 120 }, { 170, 70, 220 }, { 72, 80, 50 }
	table.insert(COSTUMES, costume("hero_valeria", "Standard", {
		Skin = skin, UpperTorso = white, LowerTorso = white, UpperArm = white, LowerArm = white, Hand = skin,
		UpperLeg = pants, LowerLeg = pants, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 1.93, 2.04, 1.8 }, { 0.0039, -0.021, 0.0966 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://119546665528137", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- High collar with gold rim; goggles resting at the neck
		piece("HighCollar", "UpperTorso", { 1.3, 0.36, 0.98 }, { 0, 0.82, 0.04 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("CollarRim", "UpperTorso", { 1.34, 0.06, 1.02 }, { 0, 0.99, 0.04 }, gold, with(LOOSE, METAL)),
		piece("GoggleStrap", "UpperTorso", { 1.24, 0.12, 1.02 }, { 0, 0.72, 0 }, leather),
		piece("GoggleLensL", "UpperTorso", { 0.08, 0.26, 0.26 }, { -0.17, 0.66, -0.56 }, lens, { Shape = "Cylinder", Material = "Glass", Rotation = { 0, 90, 0 } }),
		piece("GoggleLensR", "UpperTorso", { 0.08, 0.26, 0.26 }, { 0.17, 0.66, -0.56 }, lens, { Shape = "Cylinder", Material = "Glass", Rotation = { 0, 90, 0 } }),
		-- Green yoke with gold trim, green tabard with gold edges and a gold star
		piece("Yoke", "UpperTorso", { 2.04, 0.3, 1.04 }, { 0, 0.62, 0 }, green, { Material = "Fabric" }),
		piece("YokeTrim", "UpperTorso", { 2.06, 0.06, 1.06 }, { 0, 0.46, 0 }, gold, METAL),
		piece("TabardChest", "UpperTorso", { 0.75, 1.1, 0.06 }, { 0, -0.12, -0.51 }, green, { Material = "Fabric" }),
		piece("TabardEdgeL", "UpperTorso", { 0.06, 1.1, 0.07 }, { -0.39, -0.12, -0.52 }, gold, METAL),
		piece("TabardEdgeR", "UpperTorso", { 0.06, 1.1, 0.07 }, { 0.39, -0.12, -0.52 }, gold, METAL),
		piece("ChestStar", "UpperTorso", { 0.22, 0.22, 0.04 }, { 0, 0.02, -0.55 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("ChestCrossV", "UpperTorso", { 0.06, 0.26, 0.04 }, { 0, 0.32, -0.55 }, gold, METAL),
		piece("ChestCrossH", "UpperTorso", { 0.18, 0.06, 0.04 }, { 0, 0.35, -0.55 }, gold, METAL),
		-- White pauldrons with a gold rim and a gold star on the outer face
		piece("PauldronL", "LeftUpperArm", { 1.2, 0.5, 1.16 }, { -0.1, 0.38, 0 }, white, { Material = "Fabric" }),
		piece("PauldronTrimL", "LeftUpperArm", { 1.24, 0.07, 1.2 }, { 0, -0.25, 0 }, gold, with(METAL, { RelativeTo = "PauldronL" })),
		piece("PauldronStarL", "LeftUpperArm", { 0.04, 0.2, 0.2 }, { -0.61, 0, 0 }, gold, with(METAL, { RelativeTo = "PauldronL", Rotation = { 45, 0, 0 } })),
		piece("PauldronR", "RightUpperArm", { 1.2, 0.5, 1.16 }, { 0.1, 0.38, 0 }, white, { Material = "Fabric" }),
		piece("PauldronTrimR", "RightUpperArm", { 1.24, 0.07, 1.2 }, { 0, -0.25, 0 }, gold, with(METAL, { RelativeTo = "PauldronR" })),
		piece("PauldronStarR", "RightUpperArm", { 0.04, 0.2, 0.2 }, { 0.61, 0, 0 }, gold, with(METAL, { RelativeTo = "PauldronR", Rotation = { 45, 0, 0 } })),
		-- Sleeves: a green band, then a broad gold cuff above the wrist
		piece("SleeveBandL", "LeftLowerArm", { 1.08, 0.16, 1.08 }, { 0, 0.2, 0 }, green, { Material = "Fabric" }),
		piece("SleeveBandR", "RightLowerArm", { 1.08, 0.16, 1.08 }, { 0, 0.2, 0 }, green, { Material = "Fabric" }),
		piece("GoldCuffL", "LeftLowerArm", { 1.12, 0.22, 1.12 }, { 0, -0.3, 0 }, gold, METAL),
		piece("GoldCuffR", "RightLowerArm", { 1.12, 0.22, 1.12 }, { 0, -0.3, 0 }, gold, METAL),
		-- Belt with potion vials and a herb pouch
		piece("Belt", "LowerTorso", { 2.06, 0.24, 1.06 }, { 0, 0.04, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.3, 0.2, 0.06 }, { 0, 0.04, -0.56 }, steel, METAL),
		piece("PotionGreen", "LowerTorso", { 0.14, 0.3, 0.14 }, { -0.42, -0.1, -0.6 }, potionGreen, with(NEON, { Material = "Glass" })),
		piece("PotionPurple", "LowerTorso", { 0.14, 0.3, 0.14 }, { -0.62, -0.1, -0.6 }, potionPurple, with(NEON, { Material = "Glass" })),
		piece("HerbPouch", "LowerTorso", { 0.4, 0.4, 0.3 }, { 0.62, -0.08, -0.64 }, pouch, { Material = "Fabric" }),
		-- Open white coat skirt with a long green tabard down the front
		piece("CoatBack", "LowerTorso", { 2.12, 1.5, 0.12 }, { 0, -0.85, 0.56 }, white, with(LOOSE, { Material = "Fabric", Rotation = { -6, 0, 0 } })),
		piece("CoatFrontL", "LowerTorso", { 0.6, 1.3, 0.08 }, { -0.72, -0.75, -0.56 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("CoatFrontR", "LowerTorso", { 0.6, 1.3, 0.08 }, { 0.72, -0.75, -0.56 }, white, with(LOOSE, { Material = "Fabric" })),
		piece("TabardSkirt", "LowerTorso", { 0.75, 1.4, 0.06 }, { 0, -0.85, -0.56 }, green, with(LOOSE, { Material = "Fabric" })),
		piece("TabardStar", "LowerTorso", { 0.2, 0.2, 0.04 }, { 0, -1.1, -0.6 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, 45 } })),
		-- Legs: gold-rimmed dark knee plates, a gold greave band, boots on gold soles
		piece("KneeRimL", "LeftLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadL", "LeftLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, plate, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimL" })),
		piece("KneeRimR", "RightLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadR", "RightLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, plate, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimR" })),
		piece("GreaveBandL", "LeftLowerLeg", { 1.08, 0.1, 1.08 }, { 0, -0.15, 0 }, gold, METAL),
		piece("GreaveBandR", "RightLowerLeg", { 1.08, 0.1, 1.08 }, { 0, -0.15, 0 }, gold, METAL),
		piece("BootL", "LeftFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold, METAL),
		piece("BootR", "RightFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold, METAL),
	}, "rbxassetid://75911538426683"))
end

-- 5. IGNIS (5★ Vanguard - Blazing Berserker) -------------------------------------------
-- Brawler from his reference art: short spiky golden hair swept over, a tattered dark cowl, a
-- riveted dark armour core between red tabard panels with gold edges and flame emblems, bare
-- arms with dark steel pauldrons and studded leather bracers, a heavy belt with a pouch and
-- hanging chains, a tattered red loincloth, gold-rimmed knee plates, greaves and sabatons.
-- (The reference's flaming fist is an effect, not costume.) Face: our own decal from
-- assets/faces/make_ignis_face.py. Hair: our Blender mesh (tools/make_ignis_hair_ugc.py).
do
	local skin, hair, dark, darkSteel, red = { 236, 198, 160 }, { 220, 150, 60 }, { 40, 36, 36 }, { 64, 66, 74 }, { 150, 36, 32 }
	local gold, leather, chain, pants, cowl, flame = { 196, 156, 70 }, { 92, 62, 44 }, { 130, 132, 140 }, { 58, 48, 44 }, { 52, 46, 44 }, { 250, 120, 40 }
	table.insert(COSTUMES, costume("hero_ignis", "Heavy", {
		Skin = skin, UpperTorso = dark, LowerTorso = pants, UpperArm = skin, LowerArm = skin, Hand = skin,
		UpperLeg = pants, LowerLeg = pants, Foot = darkSteel,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 1.59, 1.83, 1.63 }, { -0.0074, 0.6105, 0.0364 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://101701313703578", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Tattered cowl at the neck
		piece("CowlWrap", "UpperTorso", { 1.6, 0.42, 1.2 }, { 0, 0.78, 0 }, cowl, with(LOOSE, { Material = "Fabric" })),
		piece("CowlDrape", "UpperTorso", { 1.3, 0.4, 0.12 }, { 0, 0.5, -0.56 }, cowl, with(LOOSE, { Material = "Fabric" })),
		-- Riveted dark armour core between red tabard panels with gold edges and flame emblems
		piece("ArmourCore", "UpperTorso", { 1.0, 1.3, 0.12 }, { 0, -0.1, -0.5 }, darkSteel, METAL),
		piece("TabardL", "UpperTorso", { 0.45, 1.45, 0.08 }, { -0.62, -0.05, -0.53 }, red, { Material = "Fabric" }),
		piece("TabardR", "UpperTorso", { 0.45, 1.45, 0.08 }, { 0.62, -0.05, -0.53 }, red, { Material = "Fabric" }),
		piece("TabardEdgeL", "UpperTorso", { 0.05, 1.45, 0.09 }, { -0.38, -0.05, -0.54 }, gold, METAL),
		piece("TabardEdgeR", "UpperTorso", { 0.05, 1.45, 0.09 }, { 0.38, -0.05, -0.54 }, gold, METAL),
		piece("FlameEmblemL", "UpperTorso", { 0.18, 0.3, 0.04 }, { -0.62, 0.25, -0.58 }, flame, NEON),
		piece("FlameEmblemR", "UpperTorso", { 0.18, 0.3, 0.04 }, { 0.62, 0.25, -0.58 }, flame, NEON),
		-- Dark steel pauldrons with gold trim and a gold flame emblem; studded leather bracers
		piece("PauldronL", "LeftUpperArm", { 1.4, 0.6, 1.35 }, { -0.22, 0.42, 0 }, darkSteel, with(METAL, { Rotation = { 0, 0, 10 } })),
		piece("PauldronTrimL", "LeftUpperArm", { 1.44, 0.07, 1.39 }, { 0, -0.3, 0 }, gold, with(METAL, { RelativeTo = "PauldronL" })),
		piece("PauldronFlameL", "LeftUpperArm", { 0.04, 0.34, 0.3 }, { -0.72, 0.02, 0 }, gold, with(METAL, { RelativeTo = "PauldronL" })),
		piece("PauldronR", "RightUpperArm", { 1.4, 0.6, 1.35 }, { 0.22, 0.42, 0 }, darkSteel, with(METAL, { Rotation = { 0, 0, -10 } })),
		piece("PauldronTrimR", "RightUpperArm", { 1.44, 0.07, 1.39 }, { 0, -0.3, 0 }, gold, with(METAL, { RelativeTo = "PauldronR" })),
		piece("PauldronFlameR", "RightUpperArm", { 0.04, 0.34, 0.3 }, { 0.72, 0.02, 0 }, gold, with(METAL, { RelativeTo = "PauldronR" })),
		piece("BracerL", "LeftLowerArm", { 1.12, 0.7, 1.12 }, { 0, -0.1, 0 }, leather),
		piece("BracerRimL", "LeftLowerArm", { 1.14, 0.06, 1.14 }, { 0, 0.24, 0 }, chain, METAL),
		piece("BracerR", "RightLowerArm", { 1.12, 0.7, 1.12 }, { 0, -0.1, 0 }, leather),
		piece("BracerRimR", "RightLowerArm", { 1.14, 0.06, 1.14 }, { 0, 0.24, 0 }, chain, METAL),
		-- Heavy belt with a pouch and hanging chains; tattered red loincloth with gold edges
		piece("Belt", "LowerTorso", { 2.08, 0.3, 1.08 }, { 0, 0.04, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.36, 0.24, 0.06 }, { 0, 0.04, -0.57 }, chain, METAL),
		piece("Pouch", "LowerTorso", { 0.42, 0.4, 0.3 }, { -0.62, -0.06, -0.66 }, leather),
		piece("ChainL", "LowerTorso", { 0.6, 0.06, 0.06 }, { -0.7, -0.25, -0.56 }, chain, with(LOOSE, METAL, { Rotation = { 0, 0, -25 } })),
		piece("ChainR", "LowerTorso", { 0.6, 0.06, 0.06 }, { 0.7, -0.25, -0.56 }, chain, with(LOOSE, METAL, { Rotation = { 0, 0, 25 } })),
		piece("Loincloth", "LowerTorso", { 0.9, 0.95, 0.06 }, { 0, -0.62, -0.56 }, red, with(LOOSE, { Material = "Fabric" })),
		piece("LoinEdgeL", "LowerTorso", { 0.05, 0.95, 0.07 }, { -0.45, -0.62, -0.57 }, gold, with(LOOSE, METAL)),
		piece("LoinEdgeR", "LowerTorso", { 0.05, 0.95, 0.07 }, { 0.45, -0.62, -0.57 }, gold, with(LOOSE, METAL)),
		piece("LoinTatterL", "LowerTorso", { 0.06, 0.3, 0.4 }, { -0.2, -1.2, -0.56 }, red, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("LoinTatterR", "LowerTorso", { 0.06, 0.3, 0.4 }, { 0.2, -1.2, -0.56 }, red, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, -90, 180 } })),
		piece("LoinBack", "LowerTorso", { 2.0, 0.9, 0.08 }, { 0, -0.55, 0.56 }, red, with(LOOSE, { Material = "Fabric", Rotation = { -6, 0, 0 } })),
		-- Legs: gold-rimmed knee plates, dark greaves, leg wraps, steel sabatons with gold soles
		piece("KneeRimL", "LeftLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadL", "LeftLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, darkSteel, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimL" })),
		piece("KneeRimR", "RightLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadR", "RightLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, darkSteel, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimR" })),
		piece("GreaveL", "LeftLowerLeg", { 1.1, 0.7, 1.1 }, { 0, -0.15, 0 }, darkSteel, METAL),
		piece("GreaveR", "RightLowerLeg", { 1.1, 0.7, 1.1 }, { 0, -0.15, 0 }, darkSteel, METAL),
		piece("LegWrapL", "LeftLowerLeg", { 1.06, 0.1, 1.06 }, { 0, 0.22, 0 }, leather),
		piece("LegWrapR", "RightLowerLeg", { 1.06, 0.1, 1.06 }, { 0, 0.22, 0 }, leather),
		piece("SabatonL", "LeftFoot", { 1.1, 0.36, 1.3 }, { 0, 0.02, -0.12 }, darkSteel, METAL),
		piece("SabatonSoleL", "LeftFoot", { 1.12, 0.06, 1.32 }, { 0, -0.14, -0.12 }, gold, METAL),
		piece("SabatonR", "RightFoot", { 1.1, 0.36, 1.3 }, { 0, 0.02, -0.12 }, darkSteel, METAL),
		piece("SabatonSoleR", "RightFoot", { 1.12, 0.06, 1.32 }, { 0, -0.14, -0.12 }, gold, METAL),
	}, "rbxassetid://137040425989997"))
end

-- 6. JENNA (1★ Marksman - Wind-Scout Archer) ---------------------------------------------
-- Confident red-haired archer look: spiky layered crimson hair with two front framing tails
-- and a woven 3-strand braid cascading down the back, oatmeal coarse linen tunic with V-neck,
-- dark brown leather belt with 5-point gold star buckle, hip utility pouches, dual-tone bracers,
-- burgundy trousers with gold-rimmed octagonal knee armor plates, and heavy combat boots.
-- Face: our custom decal with golden-amber anime eyes, smirk with teeth, and cute freckles.
-- Hair: our Blender mesh (JennaHair in assets/hair/hero_hair.blend).
do
	local skin, hair, linen = { 246, 218, 196 }, { 226, 66, 34 }, { 222, 215, 198 }
	local leather, darkLeather, steel, gold = { 65, 42, 28 }, { 45, 28, 20 }, { 160, 165, 175 }, { 225, 185, 75 }
	local bronze, slate, trousers, charcoal = { 72, 56, 46 }, { 46, 51, 61 }, { 56, 32, 34 }, { 36, 36, 40 }

	table.insert(COSTUMES, costume("hero_jenna", "Slim", {
		Skin = skin, UpperTorso = linen, LowerTorso = leather, UpperArm = linen, LowerArm = skin,
		Hand = skin, UpperLeg = trousers, LowerLeg = slate, Foot = leather,
	}, {
		-- 1. Hair mesh: UGC-style ribbon locks, spiky crown, side-swept fringe, face-framing locks
		-- and a ponytail at the centre of the back. Centred on the export's bounding box and
		-- turned 180 degrees to undo the importer's rotation; a dark band covers the hair tie.
		-- Shrunk 8% about the head centre (mesh, offset and tie together) to hug the head.
		piece("HairMesh", "Head", { 1.6, 2.8, 1.89 }, { 0.0018, -0.4851, 0.1636 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://107250648665529", Scale = { 0.0092, 0.0092, 0.0092 } },
		})),
		piece("HairTie", "Head", { 0.11, 0.23, 0.23 }, { 0, -0.221, 0.754 }, charcoal, with(LOOSE, { Shape = "Cylinder", Rotation = { 0, 0, 90 } })),

		-- 2. Linen Tunic & Collar
		piece("TunicVNeck", "UpperTorso", { 0.36, 0.36, 0.04 }, { 0, 0.65, -0.51 }, skin, { Rotation = { 0, 0, 45 } }),
		piece("TunicCollarL", "UpperTorso", { 0.38, 0.16, 0.32 }, { -0.26, 0.68, -0.25 }, linen, { Rotation = { -15, 0, 15 } }),
		piece("TunicCollarR", "UpperTorso", { 0.38, 0.16, 0.32 }, { 0.26, 0.68, -0.25 }, linen, { Rotation = { -15, 0, -15 } }),
		piece("TunicDrapeUpper", "UpperTorso", { 1.86, 0.48, 0.15 }, { 0, -0.45, -0.48 }, linen, { Material = "Fabric" }),

		-- 3. Tunic Lower Skirt & Waist
		piece("TunicLowerSkirt", "LowerTorso", { 2.06, 0.62, 1.06 }, { 0, -0.16, 0 }, linen, with(LOOSE, { Material = "Fabric" })),
		piece("TunicBottomHem", "LowerTorso", { 2.08, 0.08, 1.08 }, { 0, -0.46, 0 }, linen, with(LOOSE, { Material = "Fabric" })),

		-- 4. Utility Belt, Gold Star Buckle & Side Pouches
		piece("UtilityBelt", "LowerTorso", { 2.12, 0.30, 1.12 }, { 0, 0.12, 0 }, leather),
		piece("BuckleFrame", "LowerTorso", { 0.55, 0.42, 0.12 }, { 0, 0.12, -0.58 }, steel, METAL),
		piece("StarBuckle", "LowerTorso", { 0.42, 0.42, 0.14 }, { 0, 0.12, -0.62 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("BeltPouchL", "LowerTorso", { 0.35, 0.42, 0.28 }, { -0.75, 0.08, -0.52 }, leather),
		piece("BeltPouchR", "LowerTorso", { 0.35, 0.42, 0.28 }, { 0.75, 0.08, -0.52 }, leather),

		-- 5. Short Sleeves
		piece("SleeveL", "LeftUpperArm", { 1.08, 0.45, 1.08 }, { 0, 0.25, 0 }, linen, { Material = "Fabric" }),
		piece("SleeveR", "RightUpperArm", { 1.08, 0.45, 1.08 }, { 0, 0.25, 0 }, linen, { Material = "Fabric" }),

		-- 6. Dual-Tone Forearm Bracers
		piece("BracerBaseL", "LeftLowerArm", { 1.08, 0.62, 1.08 }, { 0, -0.12, 0 }, slate),
		piece("BracerStrapL", "LeftLowerArm", { 1.12, 0.16, 1.12 }, { 0, -0.06, 0 }, leather),
		piece("BracerGoldRimL", "LeftLowerArm", { 1.10, 0.08, 1.10 }, { 0, 0.16, 0 }, gold, METAL),
		piece("BracerBaseR", "RightLowerArm", { 1.08, 0.62, 1.08 }, { 0, -0.12, 0 }, slate),
		piece("BracerStrapR", "RightLowerArm", { 1.12, 0.16, 1.12 }, { 0, -0.06, 0 }, leather),
		piece("BracerGoldRimR", "RightLowerArm", { 1.10, 0.08, 1.10 }, { 0, 0.16, 0 }, gold, METAL),

		-- 7. Knee Armor Plates & Greaves
		piece("KneeCopRimL", "LeftLowerLeg", { 0.12, 0.58, 0.58 }, { 0, 0.42, -0.52 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneeCopPlateL", "LeftLowerLeg", { 0.14, 0.46, 0.46 }, { 0.03, 0, 0 }, bronze, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeCopRimL" })),
		piece("GreaveStrapL", "LeftLowerLeg", { 1.06, 0.12, 1.06 }, { 0, 0.15, 0 }, leather),
		piece("KneeCopRimR", "RightLowerLeg", { 0.12, 0.58, 0.58 }, { 0, 0.42, -0.52 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneeCopPlateR", "RightLowerLeg", { 0.14, 0.46, 0.46 }, { 0.03, 0, 0 }, bronze, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeCopRimR" })),
		piece("GreaveStrapR", "RightLowerLeg", { 1.06, 0.12, 1.06 }, { 0, 0.15, 0 }, leather),

		-- 8. Combat Boots & Cleats
		piece("BootCuffL", "LeftFoot", { 1.08, 0.22, 1.18 }, { 0, 0.10, -0.05 }, leather),
		piece("BootToeGuardL", "LeftFoot", { 1.06, 0.18, 0.40 }, { 0, -0.05, -0.46 }, gold, METAL),
		piece("BootSoleL", "LeftFoot", { 1.08, 0.08, 1.25 }, { 0, -0.12, -0.08 }, charcoal, METAL),
		piece("BootCuffR", "RightFoot", { 1.08, 0.22, 1.18 }, { 0, 0.10, -0.05 }, leather),
		piece("BootToeGuardR", "RightFoot", { 1.06, 0.18, 0.40 }, { 0, -0.05, -0.46 }, gold, METAL),
		piece("BootSoleR", "RightFoot", { 1.08, 0.08, 1.25 }, { 0, -0.12, -0.08 }, charcoal, METAL),
	}, "rbxassetid://100881487266962"))
end

-- 7. VELKIST (2★ Striker - Crimson Rogue Assassin) ---------------------------------------
-- Cocky rogue look: purple hair with a low ponytail, sleeveless maroon hooded coat with
-- tattered shoulders over a black shirt and chest strap, bare arms with bands, leather
-- bracers and black fingerless gloves, belt with pouches and a torn sash, long coat tails,
-- maroon trousers, dark knee plates and greaves. Face: our own decal, generated by
-- assets/faces/make_velkist_face.py. Hair: our Blender mesh (assets/hair/velkist_hair.blend).
do
	local skin, hair, coat, coatDark, shirt = { 236, 196, 158 }, { 95, 80, 175 }, { 110, 40, 42 }, { 82, 30, 34 }, { 32, 30, 34 }
	local leather, darkLeather, strap, gold, steel = { 100, 62, 42 }, { 70, 44, 32 }, { 28, 26, 28 }, { 200, 160, 70 }, { 150, 150, 158 }
	local cloth, pants, bronze, greave, boot = { 170, 140, 120 }, { 120, 40, 40 }, { 72, 56, 46 }, { 62, 46, 38 }, { 50, 38, 32 }
	table.insert(COSTUMES, costume("hero_velkist", "Standard", {
		Skin = skin, UpperTorso = shirt, LowerTorso = pants, UpperArm = skin, LowerArm = skin, Hand = strap,
		UpperLeg = pants, LowerLeg = greave, Foot = boot,
	}, {
		-- Hair mesh: modelled around a 1.2-stud head; centred on the export's bounding box, and
		-- turned 180 degrees to undo the importer's rotation.
		piece("HairMesh", "Head", { 2.03, 2.16, 1.8 }, { -0.1855, -0.0039, 0.1509 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://109684055929778", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Sleeveless hooded coat, open over the black shirt with a buckled chest strap
		piece("VestL", "UpperTorso", { 0.75, 1.62, 1.08 }, { -0.66, 0, 0 }, coat, { Material = "Fabric" }),
		piece("VestR", "UpperTorso", { 0.75, 1.62, 1.08 }, { 0.66, 0, 0 }, coat, { Material = "Fabric" }),
		piece("VestBack", "UpperTorso", { 2.08, 1.62, 0.2 }, { 0, 0, 0.48 }, coat, { Material = "Fabric" }),
		piece("HoodCollar", "UpperTorso", { 1.6, 0.4, 1.15 }, { 0, 0.72, 0.08 }, coatDark, with(LOOSE, { Material = "Fabric" })),
		piece("HoodBack", "UpperTorso", { 1.3, 0.55, 0.35 }, { 0, 0.75, 0.6 }, coatDark, with(LOOSE, { Material = "Fabric" })),
		piece("ShoulderTatterL", "UpperTorso", { 0.25, 0.4, 1.0 }, { -1.0, 0.62, 0 }, coatDark, with(WEDGE, LOOSE, { Rotation = { 180, 0, 0 } })),
		piece("ShoulderTatterR", "UpperTorso", { 0.25, 0.4, 1.0 }, { 1.0, 0.62, 0 }, coatDark, with(WEDGE, LOOSE, { Rotation = { 180, 0, 0 } })),
		piece("ChestStrap", "UpperTorso", { 0.4, 1.3, 0.06 }, { 0, 0, -0.52 }, strap),
		piece("StrapBuckle", "UpperTorso", { 0.5, 0.22, 0.08 }, { 0, 0.35, -0.56 }, steel, METAL),
		-- Arms: bands, leather bracers with a gold rim, black fingerless gloves (hand colour)
		piece("ArmBandL", "LeftUpperArm", { 1.06, 0.14, 1.06 }, { 0, 0.05, 0 }, strap),
		piece("ArmBandR", "RightUpperArm", { 1.06, 0.14, 1.06 }, { 0, 0.05, 0 }, strap),
		piece("ElbowCuffL", "LeftLowerArm", { 1.08, 0.22, 1.08 }, { 0, 0.38, 0 }, leather),
		piece("ElbowCuffR", "RightLowerArm", { 1.08, 0.22, 1.08 }, { 0, 0.38, 0 }, leather),
		piece("BracerL", "LeftLowerArm", { 1.1, 0.45, 1.1 }, { 0, -0.3, 0 }, darkLeather),
		piece("BracerR", "RightLowerArm", { 1.1, 0.45, 1.1 }, { 0, -0.3, 0 }, darkLeather),
		piece("BracerRimL", "LeftLowerArm", { 1.12, 0.07, 1.12 }, { 0, -0.06, 0 }, gold, METAL),
		piece("BracerRimR", "RightLowerArm", { 1.12, 0.07, 1.12 }, { 0, -0.06, 0 }, gold, METAL),
		-- Belt, pouches, torn sash and long coat tails
		piece("Belt", "LowerTorso", { 2.08, 0.26, 1.08 }, { 0, 0.04, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.34, 0.2, 0.06 }, { 0.15, 0.04, -0.56 }, steel, METAL),
		piece("PouchL", "LowerTorso", { 0.45, 0.45, 0.28 }, { -0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapL", "LowerTorso", { 0.47, 0.16, 0.3 }, { 0, 0.17, -0.01 }, darkLeather, { RelativeTo = "PouchL" }),
		piece("PouchR", "LowerTorso", { 0.45, 0.45, 0.28 }, { 0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapR", "LowerTorso", { 0.47, 0.16, 0.3 }, { 0, 0.17, -0.01 }, darkLeather, { RelativeTo = "PouchR" }),
		piece("SashTatterL", "LowerTorso", { 0.06, 0.7, 0.45 }, { -0.3, -0.45, -0.58 }, cloth, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("SashTatterR", "LowerTorso", { 0.06, 0.6, 0.4 }, { 0.22, -0.42, -0.6 }, cloth, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, -90, 180 } })),
		piece("CoatTail", "LowerTorso", { 2.1, 2.1, 0.12 }, { 0, -1.15, 0.62 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { -8, 0, 0 } })),
		piece("CoatSideL", "LowerTorso", { 0.12, 1.9, 0.9 }, { -1.05, -1.05, 0.15 }, coat, with(LOOSE, { Material = "Fabric" })),
		piece("CoatSideR", "LowerTorso", { 0.12, 1.9, 0.9 }, { 1.05, -1.05, 0.15 }, coat, with(LOOSE, { Material = "Fabric" })),
		-- Legs: strap above the knee, gold-rimmed dark knee plates, greaves, boots on gold soles
		piece("KneeStrapL", "LeftUpperLeg", { 1.05, 0.12, 1.05 }, { 0, -0.45, 0 }, strap),
		piece("KneeStrapR", "RightUpperLeg", { 1.05, 0.12, 1.05 }, { 0, -0.45, 0 }, strap),
		piece("KneeRimL", "LeftLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadL", "LeftLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, bronze, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimL" })),
		piece("KneeRimR", "RightLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadR", "RightLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, bronze, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimR" })),
		piece("GreaveTrimL", "LeftLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.05, 0 }, gold, METAL),
		piece("GreaveTrimR", "RightLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.05, 0 }, gold, METAL),
		piece("BootL", "LeftFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold),
		piece("BootR", "RightFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold),
	}, "rbxassetid://104592422151826"))
end

-- 8. EOLKA (3★ Scholar - Crimson Pyromancer Sorceress) ------------------------------------
-- Battle-sorceress look from her reference art: copper hair swept into a high ponytail with a
-- gold band, high black collar with a ruby brooch, black yoke and broad pauldrons edged in gold,
-- crimson chest panels with gold piping, gold-trimmed belt and crimson tabard, black cape with
-- crimson lining, gold bracers, black trousers and gilded boots. Face: our own decal from
-- assets/faces/make_eolka_face.py. Hair: our Blender mesh (tools/make_eolka_hair_ugc.py).
do
	local skin, hair, black, crimson = { 247, 223, 198 }, { 216, 98, 40 }, { 26, 22, 28 }, { 140, 29, 34 }
	local gold, ruby, sleeve, boot = { 214, 172, 92 }, { 255, 50, 40 }, { 78, 64, 80 }, { 48, 36, 30 }
	table.insert(COSTUMES, costume("hero_eolka", "Standard", {
		Skin = skin, UpperTorso = black, LowerTorso = black, UpperArm = black, LowerArm = sleeve, Hand = skin,
		UpperLeg = black, LowerLeg = boot, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation; gold band on the high ponytail.
		piece("HairMesh", "Head", { 1.66, 1.87, 1.79 }, { 0.0006, 0.2293, 0.1851 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://123421721359927", Scale = { 0.01, 0.01, 0.01 } },
		})),
		piece("HairBand", "Head", { 0.12, 0.27, 0.27 }, { 0, 0.836, 0.5376 }, gold, with(LOOSE, METAL, { Shape = "Cylinder", Rotation = { 15, 0, 90 } })),
		-- High collar with gold rim and a ruby brooch
		piece("HighCollar", "UpperTorso", { 1.2, 0.35, 0.95 }, { 0, 0.82, 0.05 }, black, with(LOOSE, { Material = "Fabric" })),
		piece("CollarRim", "UpperTorso", { 1.24, 0.06, 0.99 }, { 0, 0.99, 0.05 }, gold, with(LOOSE, METAL)),
		piece("BroochBezel", "UpperTorso", { 0.3, 0.34, 0.08 }, { 0, 0.6, -0.53 }, gold, METAL),
		piece("RubyBrooch", "UpperTorso", { 0.2, 0.24, 0.12 }, { 0, 0.6, -0.57 }, ruby, with(NEON, { Shape = "Ball" })),
		-- Black yoke across the shoulders, crimson chest panels with gold piping
		piece("Yoke", "UpperTorso", { 2.06, 0.45, 1.06 }, { 0, 0.6, 0 }, black, { Material = "Fabric" }),
		piece("YokeTrim", "UpperTorso", { 2.08, 0.06, 1.08 }, { 0, 0.37, 0 }, gold, METAL),
		piece("ChestPanelL", "UpperTorso", { 0.55, 1.0, 0.06 }, { -0.38, -0.2, -0.51 }, crimson, { Material = "Fabric" }),
		piece("ChestPanelR", "UpperTorso", { 0.55, 1.0, 0.06 }, { 0.38, -0.2, -0.51 }, crimson, { Material = "Fabric" }),
		piece("PipingL", "UpperTorso", { 0.06, 1.0, 0.07 }, { -0.12, -0.2, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, -6 } })),
		piece("PipingR", "UpperTorso", { 0.06, 1.0, 0.07 }, { 0.12, -0.2, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, 6 } })),
		piece("CapeUpper", "UpperTorso", { 2.1, 1.62, 0.1 }, { 0, 0, 0.58 }, black, with(LOOSE, { Material = "Fabric" })),
		-- Broad pauldrons edged in gold, with a gold emblem on the outer face
		piece("PauldronL", "LeftUpperArm", { 1.4, 0.75, 1.3 }, { -0.2, 0.35, 0 }, black, { Rotation = { 0, 0, 8 } }),
		piece("PauldronTrimL", "LeftUpperArm", { 1.44, 0.08, 1.34 }, { 0, -0.36, 0 }, gold, with(METAL, { RelativeTo = "PauldronL" })),
		piece("PauldronEmblemL", "LeftUpperArm", { 0.04, 0.34, 0.5 }, { -0.71, 0.02, 0 }, gold, with(METAL, { RelativeTo = "PauldronL" })),
		piece("PauldronR", "RightUpperArm", { 1.4, 0.75, 1.3 }, { 0.2, 0.35, 0 }, black, { Rotation = { 0, 0, -8 } }),
		piece("PauldronTrimR", "RightUpperArm", { 1.44, 0.08, 1.34 }, { 0, -0.36, 0 }, gold, with(METAL, { RelativeTo = "PauldronR" })),
		piece("PauldronEmblemR", "RightUpperArm", { 0.04, 0.34, 0.5 }, { 0.71, 0.02, 0 }, gold, with(METAL, { RelativeTo = "PauldronR" })),
		-- Forearms: dusky sleeves, a gold ring at the elbow and double gold bracers
		piece("ElbowRingL", "LeftLowerArm", { 1.08, 0.08, 1.08 }, { 0, 0.42, 0 }, gold, METAL),
		piece("ElbowRingR", "RightLowerArm", { 1.08, 0.08, 1.08 }, { 0, 0.42, 0 }, gold, METAL),
		piece("BracerUpperL", "LeftLowerArm", { 1.1, 0.12, 1.1 }, { 0, -0.18, 0 }, gold, METAL),
		piece("BracerUpperR", "RightLowerArm", { 1.1, 0.12, 1.1 }, { 0, -0.18, 0 }, gold, METAL),
		piece("BracerLowerL", "LeftLowerArm", { 1.1, 0.12, 1.1 }, { 0, -0.4, 0 }, gold, METAL),
		piece("BracerLowerR", "RightLowerArm", { 1.1, 0.12, 1.1 }, { 0, -0.4, 0 }, gold, METAL),
		-- Gold-trimmed belt, crimson tabard and the lower cape with its crimson lining
		piece("Belt", "LowerTorso", { 2.06, 0.24, 1.06 }, { 0, 0.06, 0 }, black),
		piece("BeltTrimTop", "LowerTorso", { 2.08, 0.05, 1.08 }, { 0, 0.19, 0 }, gold, METAL),
		piece("BeltTrimBottom", "LowerTorso", { 2.08, 0.05, 1.08 }, { 0, -0.07, 0 }, gold, METAL),
		piece("Tabard", "LowerTorso", { 1.0, 0.9, 0.06 }, { 0, -0.6, -0.53 }, crimson, with(LOOSE, { Material = "Fabric" })),
		piece("TabardHem", "LowerTorso", { 1.02, 0.06, 0.07 }, { 0, -1.03, -0.54 }, gold, with(LOOSE, METAL)),
		piece("CapeLower", "LowerTorso", { 2.1, 2.1, 0.1 }, { 0, -1.15, 0.66 }, black, with(LOOSE, { Material = "Fabric", Rotation = { -10, 0, 0 } })),
		piece("CapeLining", "LowerTorso", { 2.0, 2.0, 0.05 }, { 0, -1.12, 0.6 }, crimson, with(LOOSE, { Material = "Fabric", Rotation = { -10, 0, 0 } })),
		-- Gilded boots: gold cuff, a gold chevron on the shin, gold soles
		piece("BootCuffL", "LeftLowerLeg", { 1.08, 0.1, 1.08 }, { 0, 0.55, 0 }, gold, METAL),
		piece("BootCuffR", "RightLowerLeg", { 1.08, 0.1, 1.08 }, { 0, 0.55, 0 }, gold, METAL),
		piece("ChevronAL", "LeftLowerLeg", { 0.4, 0.06, 0.04 }, { -0.14, 0.1, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, -30 } })),
		piece("ChevronBL", "LeftLowerLeg", { 0.4, 0.06, 0.04 }, { 0.14, 0.1, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, 30 } })),
		piece("ChevronAR", "RightLowerLeg", { 0.4, 0.06, 0.04 }, { -0.14, 0.1, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, -30 } })),
		piece("ChevronBR", "RightLowerLeg", { 0.4, 0.06, 0.04 }, { 0.14, 0.1, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, 30 } })),
		piece("BootL", "LeftFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold, METAL),
		piece("BootR", "RightFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, gold, METAL),
	}, "rbxassetid://131976429681674"))
end

-- 9. MORRIGAN (4★ Vanguard - Void Nightblade) ---------------------------------------------
-- Grim veteran knight from his reference art: black hair swept up and back into spikes with
-- long locks flaring behind the shoulders, a black scarf, a riveted steel breastplate with
-- leather straps, layered pauldrons, steel vambraces, a belt with pouches, steel tassets,
-- greaves and sabatons over a dark undersuit. Face: our own decal from
-- assets/faces/make_morrigan_face.py. Hair: our Blender mesh (tools/make_morrigan_hair_ugc.py).
do
	local skin, hair, steel, darkSteel = { 226, 186, 150 }, { 20, 20, 24 }, { 150, 152, 160 }, { 92, 94, 102 }
	local under, leather, scarf = { 42, 42, 46 }, { 88, 56, 38 }, { 24, 24, 28 }
	table.insert(COSTUMES, costume("hero_morrigan", "Heavy", {
		Skin = skin, UpperTorso = under, LowerTorso = under, UpperArm = under, LowerArm = under, Hand = leather,
		UpperLeg = under, LowerLeg = steel, Foot = darkSteel,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 2.29, 2.36, 1.68 }, { -0.0145, 0.0653, 0.0604 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://132434150044694", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Black scarf wrapped at the neck, draping onto the chest
		piece("ScarfWrap", "UpperTorso", { 1.5, 0.42, 1.18 }, { 0, 0.78, 0 }, scarf, with(LOOSE, { Material = "Fabric" })),
		piece("ScarfDrape", "UpperTorso", { 1.1, 0.32, 0.2 }, { 0, 0.55, -0.52 }, scarf, with(LOOSE, { Material = "Fabric" })),
		-- Steel breastplate with a centre ridge, abdomen plate, back plate and leather straps
		piece("Breastplate", "UpperTorso", { 1.9, 1.1, 0.18 }, { 0, 0, -0.5 }, steel, METAL),
		piece("ChestRidge", "UpperTorso", { 0.08, 0.9, 0.06 }, { 0, 0, -0.6 }, darkSteel, METAL),
		piece("Backplate", "UpperTorso", { 1.9, 1.3, 0.14 }, { 0, 0.05, 0.5 }, steel, METAL),
		piece("AbdomenPlate", "UpperTorso", { 1.7, 0.42, 0.16 }, { 0, -0.62, -0.5 }, steel, METAL),
		piece("AbdomenEdge", "UpperTorso", { 1.72, 0.05, 0.17 }, { 0, -0.4, -0.5 }, darkSteel, METAL),
		piece("StrapL", "UpperTorso", { 0.16, 0.9, 0.08 }, { -0.62, 0.35, -0.6 }, leather, { Rotation = { 0, 0, 10 } }),
		piece("StrapR", "UpperTorso", { 0.16, 0.9, 0.08 }, { 0.62, 0.35, -0.6 }, leather, { Rotation = { 0, 0, -10 } }),
		-- Layered pauldrons with a leather band below, steel vambraces with a dark rim
		piece("PauldronL", "LeftUpperArm", { 1.35, 0.55, 1.3 }, { -0.15, 0.42, 0 }, steel, with(METAL, { Rotation = { 0, 0, 10 } })),
		piece("PauldronLowerL", "LeftUpperArm", { 1.32, 0.28, 1.27 }, { 0, -0.34, 0 }, steel, with(METAL, { RelativeTo = "PauldronL" })),
		piece("ArmBandL", "LeftUpperArm", { 1.08, 0.12, 1.08 }, { 0, -0.3, 0 }, leather),
		piece("PauldronR", "RightUpperArm", { 1.35, 0.55, 1.3 }, { 0.15, 0.42, 0 }, steel, with(METAL, { Rotation = { 0, 0, -10 } })),
		piece("PauldronLowerR", "RightUpperArm", { 1.32, 0.28, 1.27 }, { 0, -0.34, 0 }, steel, with(METAL, { RelativeTo = "PauldronR" })),
		piece("ArmBandR", "RightUpperArm", { 1.08, 0.12, 1.08 }, { 0, -0.3, 0 }, leather),
		piece("VambraceL", "LeftLowerArm", { 1.12, 0.62, 1.12 }, { 0, -0.12, 0 }, steel, METAL),
		piece("VambraceRimL", "LeftLowerArm", { 1.14, 0.06, 1.14 }, { 0, 0.2, 0 }, darkSteel, METAL),
		piece("VambraceR", "RightLowerArm", { 1.12, 0.62, 1.12 }, { 0, -0.12, 0 }, steel, METAL),
		piece("VambraceRimR", "RightLowerArm", { 1.14, 0.06, 1.14 }, { 0, 0.2, 0 }, darkSteel, METAL),
		-- Belt with a steel buckle and two flapped pouches, steel tassets over the hips
		piece("Belt", "LowerTorso", { 2.06, 0.26, 1.08 }, { 0, 0.04, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.32, 0.2, 0.06 }, { 0, 0.04, -0.57 }, steel, METAL),
		piece("PouchL", "LowerTorso", { 0.42, 0.4, 0.28 }, { -0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapL", "LowerTorso", { 0.44, 0.15, 0.3 }, { 0, 0.16, -0.01 }, leather, { RelativeTo = "PouchL" }),
		piece("PouchR", "LowerTorso", { 0.42, 0.4, 0.28 }, { 0.62, -0.06, -0.66 }, leather),
		piece("PouchFlapR", "LowerTorso", { 0.44, 0.15, 0.3 }, { 0, 0.16, -0.01 }, leather, { RelativeTo = "PouchR" }),
		piece("TassetL", "LowerTorso", { 0.75, 0.6, 0.08 }, { -0.55, -0.42, -0.56 }, steel, with(LOOSE, METAL, { Rotation = { -8, 0, 0 } })),
		piece("TassetR", "LowerTorso", { 0.75, 0.6, 0.08 }, { 0.55, -0.42, -0.56 }, steel, with(LOOSE, METAL, { Rotation = { -8, 0, 0 } })),
		-- Legs: thigh straps, knee guards, greaves with a dark rim, steel sabatons
		piece("ThighStrapL", "LeftUpperLeg", { 1.05, 0.1, 1.05 }, { 0, -0.15, 0 }, leather),
		piece("ThighStrapR", "RightUpperLeg", { 1.05, 0.1, 1.05 }, { 0, -0.15, 0 }, leather),
		piece("KneeGuardL", "LeftLowerLeg", { 0.9, 0.42, 0.16 }, { 0, 0.48, -0.55 }, steel, METAL),
		piece("KneeGuardR", "RightLowerLeg", { 0.9, 0.42, 0.16 }, { 0, 0.48, -0.55 }, steel, METAL),
		piece("GreaveL", "LeftLowerLeg", { 1.08, 0.7, 1.08 }, { 0, -0.15, 0 }, steel, METAL),
		piece("GreaveRimL", "LeftLowerLeg", { 1.1, 0.06, 1.1 }, { 0, 0.2, 0 }, darkSteel, METAL),
		piece("GreaveR", "RightLowerLeg", { 1.08, 0.7, 1.08 }, { 0, -0.15, 0 }, steel, METAL),
		piece("GreaveRimR", "RightLowerLeg", { 1.1, 0.06, 1.1 }, { 0, 0.2, 0 }, darkSteel, METAL),
		piece("SabatonL", "LeftFoot", { 1.1, 0.36, 1.3 }, { 0, 0.02, -0.12 }, steel, METAL),
		piece("SabatonSoleL", "LeftFoot", { 1.12, 0.06, 1.32 }, { 0, -0.14, -0.12 }, darkSteel, METAL),
		piece("SabatonR", "RightFoot", { 1.1, 0.36, 1.3 }, { 0, 0.02, -0.12 }, steel, METAL),
		piece("SabatonSoleR", "RightFoot", { 1.12, 0.06, 1.32 }, { 0, -0.14, -0.12 }, darkSteel, METAL),
	}, "rbxassetid://134987323511884"))
end

-- 10. SOVEREIGN ARCHON (5★ Striker - World Boss Hybrid) -----------------------------------
-- Scarred assassin from his reference art: short spiky ash-blond hair, a navy hood down behind
-- a cream collar, a navy jerkin with gold chevrons, a bandolier of throwing knives, navy
-- pauldrons and dark steel vambraces with gold trim, a belt with pouches, a grey sash and a
-- scroll, a navy coat skirt with a tattered back, knee plates, greaves and boots. Face: our own
-- decal from assets/faces/make_archon_face.py. Hair: our Blender mesh
-- (tools/make_archon_hair_ugc.py).
do
	local skin, hair, navy, black, cream = { 232, 194, 160 }, { 122, 114, 76 }, { 34, 40, 62 }, { 26, 26, 30 }, { 205, 190, 160 }
	local leather, gold, steel, darkSteel, sash = { 82, 56, 40 }, { 190, 156, 80 }, { 150, 154, 166 }, { 70, 78, 96 }, { 110, 112, 120 }
	local sleeve, boot = { 180, 165, 140 }, { 66, 46, 36 }
	table.insert(COSTUMES, costume("hero_archon", "Heavy", {
		Skin = skin, UpperTorso = navy, LowerTorso = black, UpperArm = sleeve, LowerArm = navy, Hand = black,
		UpperLeg = black, LowerLeg = black, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 1.6, 1.8, 1.64 }, { 0.0137, 0.5965, 0.0281 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://139133902834118", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Hood down behind the neck, cream collar, navy cape
		piece("Hood", "UpperTorso", { 1.6, 0.7, 0.55 }, { 0, 0.85, 0.5 }, navy, with(LOOSE, { Material = "Fabric" })),
		piece("Collar", "UpperTorso", { 1.3, 0.32, 1.0 }, { 0, 0.82, 0 }, cream, with(LOOSE, { Material = "Fabric" })),
		piece("CapeUpper", "UpperTorso", { 2.1, 1.6, 0.1 }, { 0, 0, 0.58 }, navy, with(LOOSE, { Material = "Fabric" })),
		-- Gold chevrons on the jerkin, bandolier with throwing knives
		piece("ChevronUpperL", "UpperTorso", { 0.7, 0.06, 0.05 }, { -0.27, 0.05, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, -35 } })),
		piece("ChevronUpperR", "UpperTorso", { 0.7, 0.06, 0.05 }, { 0.27, 0.05, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, 35 } })),
		piece("ChevronLowerL", "UpperTorso", { 0.7, 0.06, 0.05 }, { -0.27, -0.35, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, -35 } })),
		piece("ChevronLowerR", "UpperTorso", { 0.7, 0.06, 0.05 }, { 0.27, -0.35, -0.52 }, gold, with(METAL, { Rotation = { 0, 0, 35 } })),
		piece("Bandolier", "UpperTorso", { 2.1, 0.16, 0.08 }, { 0, 0.15, -0.56 }, leather, { Rotation = { 0, 0, 35 } }),
		piece("ThrowingKnifeA", "UpperTorso", { 0.08, 0.36, 0.04 }, { 0.32, 0.12, -0.05 }, steel, with(METAL, { RelativeTo = "Bandolier", Rotation = { 0, 0, -35 } })),
		piece("ThrowingKnifeB", "UpperTorso", { 0.08, 0.36, 0.04 }, { 0.5, 0.12, -0.05 }, steel, with(METAL, { RelativeTo = "Bandolier", Rotation = { 0, 0, -35 } })),
		-- Navy pauldrons with gold trim; dark steel vambraces with a gold emblem and a strap
		piece("PauldronL", "LeftUpperArm", { 1.35, 0.5, 1.3 }, { -0.15, 0.42, 0 }, navy, with(METAL, { Rotation = { 0, 0, 10 } })),
		piece("PauldronTrimL", "LeftUpperArm", { 1.39, 0.07, 1.34 }, { 0, -0.25, 0 }, gold, with(METAL, { RelativeTo = "PauldronL" })),
		piece("PauldronR", "RightUpperArm", { 1.35, 0.5, 1.3 }, { 0.15, 0.42, 0 }, navy, with(METAL, { Rotation = { 0, 0, -10 } })),
		piece("PauldronTrimR", "RightUpperArm", { 1.39, 0.07, 1.34 }, { 0, -0.25, 0 }, gold, with(METAL, { RelativeTo = "PauldronR" })),
		piece("VambraceL", "LeftLowerArm", { 1.12, 0.7, 1.12 }, { 0, -0.08, 0 }, darkSteel, METAL),
		piece("VambraceEmblemL", "LeftLowerArm", { 0.04, 0.35, 0.4 }, { -0.58, -0.05, 0 }, gold, METAL),
		piece("VambraceStrapL", "LeftLowerArm", { 1.14, 0.1, 1.14 }, { 0, 0.35, 0 }, leather),
		piece("VambraceR", "RightLowerArm", { 1.12, 0.7, 1.12 }, { 0, -0.08, 0 }, darkSteel, METAL),
		piece("VambraceEmblemR", "RightLowerArm", { 0.04, 0.35, 0.4 }, { 0.58, -0.05, 0 }, gold, METAL),
		piece("VambraceStrapR", "RightLowerArm", { 1.14, 0.1, 1.14 }, { 0, 0.35, 0 }, leather),
		-- Belt with pouches, grey sash tails, a scroll at the left hip
		piece("Belt", "LowerTorso", { 2.08, 0.26, 1.08 }, { 0, 0.04, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.32, 0.2, 0.06 }, { 0.2, 0.04, -0.57 }, steel, METAL),
		piece("PouchL", "LowerTorso", { 0.42, 0.4, 0.28 }, { -0.62, -0.06, -0.66 }, leather),
		piece("PouchR", "LowerTorso", { 0.42, 0.4, 0.28 }, { 0.62, -0.06, -0.66 }, leather),
		piece("SashTailL", "LowerTorso", { 0.18, 0.7, 0.06 }, { -0.08, -0.5, -0.58 }, sash, with(LOOSE, { Material = "Fabric" })),
		piece("SashTailR", "LowerTorso", { 0.18, 0.6, 0.06 }, { 0.12, -0.45, -0.58 }, sash, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -6 } })),
		piece("Scroll", "LowerTorso", { 0.5, 0.18, 0.18 }, { -0.95, -0.15, -0.38 }, cream, with(LOOSE, { Shape = "Cylinder" })),
		-- Coat skirt: open front panels, tattered back
		piece("CoatFrontL", "LowerTorso", { 0.6, 1.2, 0.08 }, { -0.72, -0.72, -0.56 }, navy, with(LOOSE, { Material = "Fabric" })),
		piece("CoatFrontR", "LowerTorso", { 0.6, 1.2, 0.08 }, { 0.72, -0.72, -0.56 }, navy, with(LOOSE, { Material = "Fabric" })),
		piece("CoatBack", "LowerTorso", { 2.1, 2.0, 0.1 }, { 0, -1.12, 0.66 }, navy, with(LOOSE, { Material = "Fabric", Rotation = { -10, 0, 0 } })),
		-- Legs: gold-rimmed knee plates, steel greave plates, leg straps, boots
		piece("KneeRimL", "LeftLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadL", "LeftLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, darkSteel, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimL" })),
		piece("KneeRimR", "RightLowerLeg", { 0.1, 0.6, 0.6 }, { 0, 0.42, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePadR", "RightLowerLeg", { 0.12, 0.48, 0.48 }, { 0.04, 0, 0 }, darkSteel, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimR" })),
		piece("GreavePlateL", "LeftLowerLeg", { 0.8, 0.6, 0.12 }, { 0, -0.12, -0.52 }, darkSteel, METAL),
		piece("GreavePlateR", "RightLowerLeg", { 0.8, 0.6, 0.12 }, { 0, -0.12, -0.52 }, darkSteel, METAL),
		piece("LegStrapL", "LeftLowerLeg", { 1.06, 0.1, 1.06 }, { 0, 0.18, 0 }, leather),
		piece("LegStrapR", "RightLowerLeg", { 1.06, 0.1, 1.06 }, { 0, 0.18, 0 }, leather),
		piece("BootL", "LeftFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, black),
		piece("BootR", "RightFoot", { 1.08, 0.34, 1.25 }, { 0, 0.02, -0.1 }, boot),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.1 }, black),
	}, "rbxassetid://104359124032831"))
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
		local mesh = p.Mesh
		if mesh then
			local texture = HeroCostumes.MESHES[mesh.MeshId]
			if not texture then
				problem(`{p.Name} uses mesh {mesh.MeshId}, which is not listed in MESHES`)
			elseif mesh.TextureId and mesh.TextureId ~= texture then
				problem(`{p.Name} pairs mesh {mesh.MeshId} with texture {mesh.TextureId}, expected {texture}`)
			end
			if #mesh.Scale ~= 3 then
				problem(`{p.Name} mesh Scale needs three numbers`)
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
