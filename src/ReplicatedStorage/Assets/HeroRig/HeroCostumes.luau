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
	-- Velkist's hair, our own: assets/hair/velkist_hair.blend, imported through Studio's 3D
	-- importer. Untextured (takes the piece colour); the importer stored it at 100x scale,
	-- centred on its bounding box and turned 180 degrees about Y.
	["rbxassetid://109684055929778"] = "",
	-- Aaron's hair, our own: AaronHair in assets/hair/hero_hair.blend, imported the same way.
	["rbxassetid://76088495641706"] = "",
	-- Jenna's hair, our own: tools/make_jenna_hair_ugc.py (assets/hair/jenna_hair_ugc.blend).
	["rbxassetid://107250648665529"] = "",
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
	-- Solaris's hair, our own: tools/make_solaris_hair_ugc.py (assets/hair/solaris_hair_ugc.blend).
	["rbxassetid://116753377442189"] = "",
	-- Astrea's hair, our own: tools/make_astrea_hair_ugc.py (assets/hair/astrea_hair_ugc.blend).
	["rbxassetid://108726871571153"] = "",
	-- Edis's hair (head part), our own: EdisHair in tools/make_edis_hair_ugc.py (assets/hair/edis_hair_ugc.blend).
	["rbxassetid://95018278281793"] = "",
	-- Edis's hair (back fall), our own: EdisBackHair in tools/make_edis_hair_ugc.py (assets/hair/edis_hair_ugc.blend).
	["rbxassetid://75343037988699"] = "",
	-- Han's hair, our own: tools/make_han_hair_ugc.py (assets/hair/han_hair_ugc.blend).
	["rbxassetid://127638976753205"] = "",
	-- Gide's hair, our own: tools/make_gide_hair_ugc.py (assets/hair/gide_hair_ugc.blend).
	["rbxassetid://115502888193432"] = "",
	-- Shurn's hair, our own: tools/make_shurn_hair_ugc.py (assets/hair/shurn_hair_ugc.blend).
	["rbxassetid://115542883011217"] = "",
	-- Diran's hair, our own: tools/make_diran_hair_ugc.py (assets/hair/diran_hair_ugc.blend).
	["rbxassetid://95241080213006"] = "",
	-- Vane's hair, our own: tools/make_vane_hair_ugc.py (assets/hair/vane_hair_ugc.blend).
	["rbxassetid://121356449188059"] = "",
	-- Aeli's hair and braid, our own: tools/make_aeli_hair_ugc.py (assets/hair/aeli_hair_ugc.blend).
	["rbxassetid://70386605530551"] = "",
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

-- 1. HAN (7★ Striker - Mythical Black-Coat Swordsman) ----------------------------------
-- From his card art. Hair from the two-star card: messy layered black hair with heavy bangs
-- (our Blender mesh, tools/make_han_hair_ugc.py). Outfit from the four-star card: an all-black
-- long coat with a high collar and a hood folded on the back, a dark chest plate with a round
-- steel emblem over a black turtleneck, a chest strap, dark gloves, black trousers and
-- tall boots. Steel trim on every bone keeps him readable on dark floors. Face: our own decal,
-- generated by assets/faces/make_han_face.py.
do
	local skin, hair, coat, under, pants = { 236, 196, 158 }, { 22, 22, 28 }, { 40, 40, 48 }, { 24, 24, 28 }, { 30, 30, 36 }
	local armor, steel, strap, boot = { 80, 84, 96 }, { 168, 172, 184 }, { 52, 50, 58 }, { 26, 26, 30 }
	table.insert(COSTUMES, costume("hero_han", "Standard", {
		Skin = skin, UpperTorso = under, LowerTorso = pants, UpperArm = coat, LowerArm = coat, Hand = strap,
		UpperLeg = pants, LowerLeg = boot, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 2.02, 1.717, 1.873 }, { 0.0253, 0.1285, 0.1268 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://127638976753205", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Dark chest plate with a round steel emblem, over the black turtleneck
		piece("ChestPlate", "UpperTorso", { 1.3, 0.95, 0.08 }, { 0, 0.18, -0.52 }, armor, METAL),
		piece("EmblemRing", "UpperTorso", { 0.06, 0.44, 0.44 }, { 0, 0.22, -0.57 }, steel, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("EmblemCore", "UpperTorso", { 0.06, 0.26, 0.26 }, { 0.03, 0, 0 }, under, with(METAL, { Shape = "Cylinder", RelativeTo = "EmblemRing" })),
		-- Open long coat: front panels with steel piping, back, high collar, hood folded down
		piece("CoatL", "UpperTorso", { 0.6, 1.62, 1.1 }, { -0.73, 0, 0 }, coat, { Material = "Fabric" }),
		piece("CoatR", "UpperTorso", { 0.6, 1.62, 1.1 }, { 0.73, 0, 0 }, coat, { Material = "Fabric" }),
		piece("CoatBack", "UpperTorso", { 2.08, 1.62, 0.2 }, { 0, 0, 0.48 }, coat, { Material = "Fabric" }),
		piece("PipingL", "UpperTorso", { 0.04, 1.62, 0.04 }, { -0.44, 0, -0.56 }, steel, METAL),
		piece("PipingR", "UpperTorso", { 0.04, 1.62, 0.04 }, { 0.44, 0, -0.56 }, steel, METAL),
		piece("CollarBack", "UpperTorso", { 1.4, 0.42, 0.14 }, { 0, 0.98, 0.44 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { -10, 0, 0 } })),
		piece("CollarL", "UpperTorso", { 0.12, 0.4, 0.55 }, { -0.66, 0.94, 0.1 }, coat, with(LOOSE, { Material = "Fabric" })),
		piece("CollarR", "UpperTorso", { 0.12, 0.4, 0.55 }, { 0.66, 0.94, 0.1 }, coat, with(LOOSE, { Material = "Fabric" })),
		piece("Hood", "UpperTorso", { 1.5, 0.5, 0.4 }, { 0, 0.62, 0.74 }, coat, with(LOOSE, { Material = "Fabric" })),
		-- Chest strap from his left shoulder to his right hip, with a steel buckle
		piece("ChestStrap", "UpperTorso", { 0.2, 1.7, 0.05 }, { 0, 0, -0.6 }, strap, { Rotation = { 0, 0, -32 } }),
		piece("StrapBuckle", "UpperTorso", { 0.3, 0.2, 0.06 }, { 0.2, -0.3, -0.63 }, steel, with(METAL, { Rotation = { 0, 0, -32 } })),
		-- Sleeves: steel-grey arm bands and cuffs over dark gloves (the hand colour)
		piece("ArmBandL", "LeftUpperArm", { 1.06, 0.16, 1.06 }, { 0, -0.1, 0 }, armor, METAL),
		piece("ArmBandR", "RightUpperArm", { 1.06, 0.16, 1.06 }, { 0, -0.1, 0 }, armor, METAL),
		piece("CuffL", "LeftLowerArm", { 1.06, 0.12, 1.06 }, { 0, -0.34, 0 }, steel, METAL),
		piece("CuffR", "RightLowerArm", { 1.06, 0.12, 1.06 }, { 0, -0.34, 0 }, steel, METAL),
		-- Belt, and the coat's long tails: open at the front, flaring behind
		piece("Belt", "LowerTorso", { 2.08, 0.2, 1.08 }, { 0, 0.06, 0 }, strap),
		piece("BeltBuckle", "LowerTorso", { 0.32, 0.22, 0.06 }, { 0, 0.06, -0.56 }, steel, METAL),
		piece("CoatTailBack", "LowerTorso", { 2.1, 2.1, 0.12 }, { 0, -1.15, 0.62 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { -9, 0, 0 } })),
		piece("CoatTailL", "LowerTorso", { 0.55, 1.9, 0.1 }, { -0.78, -1.05, -0.58 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 5, 0, 0 } })),
		piece("CoatTailR", "LowerTorso", { 0.55, 1.9, 0.1 }, { 0.78, -1.05, -0.58 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 5, 0, 0 } })),
		piece("CoatSideL", "LowerTorso", { 0.1, 1.9, 1.0 }, { -1.08, -1.05, 0.05 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -5 } })),
		piece("CoatSideR", "LowerTorso", { 0.1, 1.9, 1.0 }, { 1.08, -1.05, 0.05 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, 5 } })),
		piece("TailHem", "LowerTorso", { 2.12, 0.06, 0.14 }, { 0, -1.05, 0 }, steel, with(LOOSE, METAL, { RelativeTo = "CoatTailBack" })),
		-- Legs: thigh straps, tall boots with steel cuffs and dark shin plates
		piece("ThighStrapL", "LeftUpperLeg", { 1.06, 0.1, 1.06 }, { 0, 0.1, 0 }, armor, METAL),
		piece("ThighStrapR", "RightUpperLeg", { 1.06, 0.1, 1.06 }, { 0, 0.1, 0 }, armor, METAL),
		piece("BootCuffL", "LeftLowerLeg", { 1.08, 0.08, 1.08 }, { 0, 0.34, 0 }, steel, METAL),
		piece("BootCuffR", "RightLowerLeg", { 1.08, 0.08, 1.08 }, { 0, 0.34, 0 }, steel, METAL),
		piece("ShinPlateL", "LeftLowerLeg", { 0.66, 0.6, 0.06 }, { 0, -0.08, -0.54 }, armor, METAL),
		piece("ShinPlateR", "RightLowerLeg", { 0.66, 0.6, 0.06 }, { 0, -0.08, -0.54 }, armor, METAL),
		piece("BootSoleL", "LeftFoot", { 1.08, 0.07, 1.26 }, { 0, -0.13, -0.08 }, armor),
		piece("BootSoleR", "RightFoot", { 1.08, 0.07, 1.26 }, { 0, -0.13, -0.08 }, armor),
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
	}, "rbxassetid://121586827857415"))
end

-- 4. VALERIA (Exalted Healer - Emerald Guardian) ---------------------------------------
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
	}, "rbxassetid://79233691033516"))
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
-- Sun priestess from her reference art: long wavy copper hair, a dark fur collar over a gold
-- torc, a black and crimson bodice with gold trim, black sleeves with gold cuffs and an armband,
-- an ember belt with a gold sigil, crimson and flame-orange tabards over black skirts, dark knee
-- plates and flame-orange boots. Behind her, a gold sun frame with ember gems and two crimson
-- banners. Face: our own decal from assets/faces/make_solaris_face.py. Hair: our Blender mesh
-- (tools/make_solaris_hair_ugc.py).
do
	local skin, hair, black, crimson, flame = { 214, 170, 132 }, { 205, 96, 42 }, { 32, 24, 26 }, { 128, 30, 28 }, { 230, 112, 34 }
	local gold, fur, ember, plate, boot = { 214, 166, 70 }, { 62, 42, 34 }, { 255, 110, 30 }, { 58, 46, 42 }, { 200, 80, 34 }
	table.insert(COSTUMES, costume("hero_solaris", "Standard", {
		Skin = skin, UpperTorso = black, LowerTorso = black, UpperArm = skin, LowerArm = black, Hand = flame,
		UpperLeg = black, LowerLeg = boot, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 1.9, 2.59, 1.78 }, { 0.0063, -0.2546, 0.108 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://116753377442189", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Fur collar over a gold torc
		piece("FurCollar", "UpperTorso", { 2.2, 0.4, 1.3 }, { 0, 0.74, 0.04 }, fur, with(LOOSE, { Material = "Fabric" })),
		piece("Torc", "UpperTorso", { 0.9, 0.14, 0.8 }, { 0, 0.92, 0 }, gold, with(LOOSE, METAL)),
		-- Bodice: crimson panel with gold trim and a gold V
		piece("BodicePanel", "UpperTorso", { 1.0, 1.0, 0.06 }, { 0, -0.05, -0.51 }, crimson, { Material = "Fabric" }),
		piece("BodiceTrimL", "UpperTorso", { 0.05, 1.0, 0.07 }, { -0.5, -0.05, -0.52 }, gold, METAL),
		piece("BodiceTrimR", "UpperTorso", { 0.05, 1.0, 0.07 }, { 0.5, -0.05, -0.52 }, gold, METAL),
		piece("BodiceVL", "UpperTorso", { 0.5, 0.06, 0.07 }, { -0.2, 0.32, -0.53 }, gold, with(METAL, { Rotation = { 0, 0, -35 } })),
		piece("BodiceVR", "UpperTorso", { 0.5, 0.06, 0.07 }, { 0.2, 0.32, -0.53 }, gold, with(METAL, { Rotation = { 0, 0, 35 } })),
		piece("EmberGlow", "UpperTorso", { 0.16, 0.16, 0.04 }, { 0, -0.2, -0.55 }, ember, with(NEON, { Rotation = { 0, 0, 45 } })),
		-- Arms: a gold-trimmed armband on the left, black sleeves with gold cuffs
		piece("ArmbandL", "LeftUpperArm", { 1.08, 0.18, 1.08 }, { 0, -0.1, 0 }, black),
		piece("ArmbandTrimL", "LeftUpperArm", { 1.1, 0.05, 1.1 }, { 0, 0.01, 0 }, gold, METAL),
		piece("SleeveCuffL", "LeftLowerArm", { 1.1, 0.12, 1.1 }, { 0, 0.42, 0 }, gold, METAL),
		piece("SleeveCuffR", "RightLowerArm", { 1.1, 0.12, 1.1 }, { 0, 0.42, 0 }, gold, METAL),
		piece("WristCuffL", "LeftLowerArm", { 1.1, 0.1, 1.1 }, { 0, -0.42, 0 }, gold, METAL),
		piece("WristCuffR", "RightLowerArm", { 1.1, 0.1, 1.1 }, { 0, -0.42, 0 }, gold, METAL),
		-- Ember belt with a gold sigil; crimson and flame tabards over black skirts
		piece("Belt", "LowerTorso", { 2.08, 0.26, 1.08 }, { 0, 0.04, 0 }, flame),
		piece("BeltTrim", "LowerTorso", { 2.1, 0.05, 1.1 }, { 0, 0.18, 0 }, gold, METAL),
		piece("BeltSigil", "LowerTorso", { 0.24, 0.24, 0.06 }, { 0, 0.04, -0.56 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("TabardFront", "LowerTorso", { 0.6, 1.5, 0.06 }, { 0, -0.85, -0.56 }, crimson, with(LOOSE, { Material = "Fabric" })),
		piece("TabardFlame", "LowerTorso", { 0.24, 0.5, 0.04 }, { 0, -0.95, -0.6 }, ember, with(LOOSE, NEON)),
		piece("TabardTip", "LowerTorso", { 0.06, 0.3, 0.6 }, { 0, -1.75, -0.56 }, crimson, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("SkirtL", "LowerTorso", { 0.7, 1.4, 0.08 }, { -0.66, -0.8, -0.54 }, black, with(LOOSE, { Material = "Fabric" })),
		piece("SkirtR", "LowerTorso", { 0.7, 1.4, 0.08 }, { 0.66, -0.8, -0.54 }, black, with(LOOSE, { Material = "Fabric" })),
		piece("SkirtTrimL", "LowerTorso", { 0.06, 1.4, 0.09 }, { -0.32, -0.8, -0.55 }, flame, with(LOOSE, METAL)),
		piece("SkirtTrimR", "LowerTorso", { 0.06, 1.4, 0.09 }, { 0.32, -0.8, -0.55 }, flame, with(LOOSE, METAL)),
		piece("SkirtBack", "LowerTorso", { 2.1, 1.6, 0.1 }, { 0, -0.9, 0.58 }, black, with(LOOSE, { Material = "Fabric", Rotation = { -6, 0, 0 } })),
		-- Legs: dark knee plates, gold-rimmed flame boots
		piece("KneePlateL", "LeftLowerLeg", { 0.85, 0.5, 0.14 }, { 0, 0.44, -0.55 }, plate, METAL),
		piece("KneePlateR", "RightLowerLeg", { 0.85, 0.5, 0.14 }, { 0, 0.44, -0.55 }, plate, METAL),
		piece("BootCuffL", "LeftLowerLeg", { 1.08, 0.1, 1.08 }, { 0, 0.08, 0 }, gold, METAL),
		piece("BootCuffR", "RightLowerLeg", { 1.08, 0.1, 1.08 }, { 0, 0.08, 0 }, gold, METAL),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.08 }, crimson),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.08 }, crimson),
		-- Sun frame behind her: a gold arch over the head with flame spires and ember gems,
		-- and two crimson banners hanging from gold posts.
		piece("FrameArchL", "UpperTorso", { 0.26, 2.2, 0.18 }, { -1.35, 1.75, 1.35 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, -16 } })),
		piece("FrameArchR", "UpperTorso", { 0.26, 2.2, 0.18 }, { 1.35, 1.75, 1.35 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, 16 } })),
		piece("FrameTop", "UpperTorso", { 2.1, 0.26, 0.18 }, { 0, 2.85, 1.35 }, gold, with(LOOSE, METAL)),
		piece("FrameCrest", "UpperTorso", { 0.18, 0.7, 0.5 }, { 0, 3.3, 1.35 }, gold, with(LOOSE, METAL, WEDGE, { Rotation = { 0, 90, 0 } })),
		piece("FrameGemTop", "UpperTorso", { 0.3, 0.3, 0.12 }, { 0, 2.85, 1.24 }, ember, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("FrameGemL", "UpperTorso", { 0.26, 0.26, 0.12 }, { -1.42, 1.9, 1.24 }, ember, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("FrameGemR", "UpperTorso", { 0.26, 0.26, 0.12 }, { 1.42, 1.9, 1.24 }, ember, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("BannerPostL", "UpperTorso", { 0.2, 1.3, 0.2 }, { -3.25, 1.1, 1.1 }, gold, with(LOOSE, METAL)),
		piece("BannerPostR", "UpperTorso", { 0.2, 1.3, 0.2 }, { 3.25, 1.1, 1.1 }, gold, with(LOOSE, METAL)),
		piece("BannerL", "UpperTorso", { 0.8, 2.6, 0.05 }, { -3.25, -0.8, 1.1 }, crimson, with(LOOSE, { Material = "Fabric" })),
		piece("BannerR", "UpperTorso", { 0.8, 2.6, 0.05 }, { 3.25, -0.8, 1.1 }, crimson, with(LOOSE, { Material = "Fabric" })),
	}, "rbxassetid://89614314986771"))
end

-- 12. ASTREA (7★ Marksman - Featured Astral Star-Gazer) -----------------------------------
-- Astral archer from her reference art: very long wavy silver-blue hair with star ornaments, a
-- halo of stars behind her head, an off-shoulder lavender gown with silver trim and a star
-- brooch, bell sleeves, a silver belt with a star clasp, a sheer layered overskirt, a quiver at
-- her left hip, lavender trousers and pale blue boots with gold trim. Face: our own decal from
-- assets/faces/make_astrea_face.py. Hair: our Blender mesh (tools/make_astrea_hair_ugc.py).
do
	local skin, hair, lavender, lilac, silver = { 238, 200, 168 }, { 200, 212, 236 }, { 170, 170, 220 }, { 196, 196, 236 }, { 214, 218, 232 }
	local star, gold, leather, boot, glow = { 120, 190, 255 }, { 214, 176, 90 }, { 42, 38, 46 }, { 176, 196, 228 }, { 170, 220, 255 }
	table.insert(COSTUMES, costume("hero_astrea", "Standard", {
		Skin = skin, UpperTorso = lavender, LowerTorso = lavender, UpperArm = lavender, LowerArm = lavender, Hand = skin,
		UpperLeg = lilac, LowerLeg = boot, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 2.31, 5.02, 2.11 }, { -0.0118, -1.4656, 0.1972 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://108726871571153", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Star ornaments in the hair and crystal earrings
		piece("HairStarL", "Head", { 0.08, 0.3, 0.3 }, { -0.62, 0.32, -0.15 }, star, with(NEON, { Rotation = { 45, 0, 0 } })),
		piece("HairStarR", "Head", { 0.08, 0.3, 0.3 }, { 0.62, 0.32, -0.15 }, star, with(NEON, { Rotation = { 45, 0, 0 } })),
		piece("EarringL", "Head", { 0.06, 0.2, 0.06 }, { -0.6, -0.3, -0.1 }, glow, with(LOOSE, NEON)),
		piece("EarringR", "Head", { 0.06, 0.2, 0.06 }, { 0.6, -0.3, -0.1 }, glow, with(LOOSE, NEON)),
		-- Halo of stars behind her head
		piece("HaloStar1", "UpperTorso", { 0.14, 0.14, 0.14 }, { -0.95, 1.95, 0.75 }, glow, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("HaloStar2", "UpperTorso", { 0.14, 0.14, 0.14 }, { -0.7, 2.45, 0.75 }, glow, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("HaloStar3", "UpperTorso", { 0.14, 0.14, 0.14 }, { -0.25, 2.72, 0.75 }, glow, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("HaloStar4", "UpperTorso", { 0.14, 0.14, 0.14 }, { 0.25, 2.72, 0.75 }, glow, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("HaloStar5", "UpperTorso", { 0.14, 0.14, 0.14 }, { 0.7, 2.45, 0.75 }, glow, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("HaloStar6", "UpperTorso", { 0.14, 0.14, 0.14 }, { 0.95, 1.95, 0.75 }, glow, with(LOOSE, NEON, { Shape = "Ball" })),
		piece("HaloCrown", "UpperTorso", { 0.06, 0.5, 0.5 }, { 0, 3.05, 0.75 }, star, with(LOOSE, NEON, { Rotation = { 45, 0, 0 } })),
		-- Off-shoulder bodice: bare shoulders, silver neckline, star brooch, silver seams
		piece("BareShoulders", "UpperTorso", { 2.02, 0.26, 1.02 }, { 0, 0.68, 0 }, skin),
		piece("NecklineTrim", "UpperTorso", { 2.06, 0.08, 1.06 }, { 0, 0.52, 0 }, silver, METAL),
		piece("StarBrooch", "UpperTorso", { 0.04, 0.3, 0.3 }, { 0, 0.32, -0.53 }, star, with(NEON, { Rotation = { 0, 90, 45 } })),
		piece("SeamL", "UpperTorso", { 0.05, 0.8, 0.05 }, { -0.3, -0.2, -0.52 }, silver, METAL),
		piece("SeamR", "UpperTorso", { 0.05, 0.8, 0.05 }, { 0.3, -0.2, -0.52 }, silver, METAL),
		-- Arms: bare shoulder caps, silver bands, flared bell sleeves with silver hems
		piece("ShoulderCapL", "LeftUpperArm", { 1.02, 0.3, 1.02 }, { 0, 0.42, 0 }, skin),
		piece("ShoulderCapR", "RightUpperArm", { 1.02, 0.3, 1.02 }, { 0, 0.42, 0 }, skin),
		piece("ArmBandL", "LeftUpperArm", { 1.06, 0.1, 1.06 }, { 0, 0.24, 0 }, silver, METAL),
		piece("ArmBandR", "RightUpperArm", { 1.06, 0.1, 1.06 }, { 0, 0.24, 0 }, silver, METAL),
		piece("BellSleeveL", "LeftLowerArm", { 1.35, 0.85, 1.35 }, { 0, 0.05, 0 }, lilac, with(LOOSE, { Material = "Fabric" })),
		piece("BellSleeveR", "RightLowerArm", { 1.35, 0.85, 1.35 }, { 0, 0.05, 0 }, lilac, with(LOOSE, { Material = "Fabric" })),
		piece("SleeveHemL", "LeftLowerArm", { 1.38, 0.06, 1.38 }, { 0, -0.36, 0 }, silver, with(LOOSE, METAL)),
		piece("SleeveHemR", "RightLowerArm", { 1.38, 0.06, 1.38 }, { 0, -0.36, 0 }, silver, with(LOOSE, METAL)),
		-- Silver belt with a star clasp
		piece("Belt", "LowerTorso", { 2.06, 0.18, 1.06 }, { 0, 0.1, 0 }, silver, METAL),
		piece("StarClasp", "LowerTorso", { 0.04, 0.26, 0.26 }, { 0.4, 0.1, -0.55 }, star, with(NEON, { Rotation = { 0, 90, 45 } })),
		-- Sheer layered overskirt: open front panels, a wrap drape, a long back
		piece("OverskirtL", "LowerTorso", { 0.75, 1.9, 0.06 }, { -0.65, -1.05, -0.56 }, lilac, with(LOOSE, { Material = "Glass" })),
		piece("OverskirtR", "LowerTorso", { 0.75, 1.9, 0.06 }, { 0.65, -1.05, -0.56 }, lilac, with(LOOSE, { Material = "Glass" })),
		piece("WrapDrape", "LowerTorso", { 1.2, 1.0, 0.07 }, { 0.15, -0.55, -0.58 }, lavender, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -12 } })),
		piece("SkirtBack", "LowerTorso", { 2.2, 2.2, 0.1 }, { 0, -1.2, 0.6 }, lavender, with(LOOSE, { Material = "Fabric", Rotation = { -8, 0, 0 } })),
		piece("HemL", "LowerTorso", { 0.75, 0.06, 0.07 }, { -0.65, -2.0, -0.57 }, silver, with(LOOSE, METAL)),
		piece("HemR", "LowerTorso", { 0.75, 0.06, 0.07 }, { 0.65, -2.0, -0.57 }, silver, with(LOOSE, METAL)),
		-- Quiver at her left hip with a gold rim and glowing crystal fletching
		piece("Quiver", "LowerTorso", { 0.4, 1.4, 0.4 }, { -1.2, -0.45, 0.2 }, leather, with(LOOSE, { Shape = "Cylinder", Rotation = { 0, 0, 80 } })),
		piece("QuiverRim", "LowerTorso", { 0.44, 0.1, 0.44 }, { -1.24, 0.25, 0.2 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, -10 } })),
		piece("FletchA", "LowerTorso", { 0.06, 0.32, 0.18 }, { -1.22, 0.45, 0.14 }, glow, with(LOOSE, NEON)),
		piece("FletchB", "LowerTorso", { 0.06, 0.32, 0.18 }, { -1.28, 0.42, 0.28 }, glow, with(LOOSE, NEON)),
		-- Boots: gold V trim and cuff, gold soles
		piece("BootCuffL", "LeftLowerLeg", { 1.08, 0.1, 1.08 }, { 0, 0.32, 0 }, gold, METAL),
		piece("BootCuffR", "RightLowerLeg", { 1.08, 0.1, 1.08 }, { 0, 0.32, 0 }, gold, METAL),
		piece("BootStarL", "LeftLowerLeg", { 0.22, 0.22, 0.04 }, { 0, 0.05, -0.54 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("BootStarR", "RightLowerLeg", { 0.22, 0.22, 0.04 }, { 0, 0.05, -0.54 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.08 }, gold, METAL),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.08 }, gold, METAL),
	}, "rbxassetid://139763198478294"))
end

-- 13. EDIS CALLEN (6★ Striker - Legendary Black-Leather Rogue) ---------------------------
-- Rogue from her card art and render: long, wild, curly black hair, a cropped dark-brown leather
-- jacket with a popped collar and fur-trimmed hem, a black sweetheart crop top with a buckled
-- corset band, a bare midriff, a slung belt with pouches and a hanging tongue, a torn black coat
-- tail, strapped black trousers, gold-rimmed knee guards and brown boots. Feminine body (Slim):
-- the render's huge shoulder pads become flat seams so the shoulders stay narrow. Face: our own
-- decal from assets/faces/make_edis_face.py. Hair: two Blender meshes, head and back fall
-- (tools/make_edis_hair_ugc.py), so it can be longer than one mesh's triangle limit allows.
do
	local skin, hair, top, jacket, jacketDark = { 236, 200, 170 }, { 22, 20, 26 }, { 26, 24, 28 }, { 66, 48, 42 }, { 46, 36, 32 }
	local pants, leather, fur, steel, gold, boot = { 32, 30, 34 }, { 84, 58, 42 }, { 156, 132, 100 }, { 150, 154, 162 }, { 180, 144, 72 }, { 58, 44, 38 }
	table.insert(COSTUMES, costume("hero_edis", "Slim", {
		Skin = skin, UpperTorso = skin, LowerTorso = pants, UpperArm = jacket, LowerArm = jacket, Hand = top,
		UpperLeg = pants, LowerLeg = pants, Foot = boot,
	}, {
		-- Hair meshes: each centred on its export's bounding box and turned 180 degrees to undo
		-- the importer's rotation.
		piece("HairMesh", "Head", { 2.398, 2.972, 1.806 }, { 0.0013, -0.4191, 0.099 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://95018278281793", Scale = { 0.01, 0.01, 0.01 } },
		})),
		piece("HairBackMesh", "Head", { 2.411, 4.223, 1.928 }, { -0.0009, -1.0643, 0.3998 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://75343037988699", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Black sweetheart crop top over a bare midriff, with a buckled corset band under the bust
		piece("CropTop", "UpperTorso", { 2.04, 0.92, 1.04 }, { 0, 0.3, 0 }, top, { Material = "Fabric" }),
		piece("Neckline", "UpperTorso", { 0.34, 0.34, 0.04 }, { 0, 0.66, -0.53 }, skin, { Rotation = { 0, 0, 45 } }),
		piece("CorsetBand", "UpperTorso", { 2.06, 0.3, 1.06 }, { 0, -0.04, 0 }, top, { Material = "Fabric" }),
		piece("CorsetBuckleA", "UpperTorso", { 0.3, 0.07, 0.04 }, { 0, 0.04, -0.55 }, steel, METAL),
		-- Cropped open leather jacket: front panels, back, popped collar, fur-trimmed hem
		piece("JacketL", "UpperTorso", { 0.55, 1.08, 1.08 }, { -0.75, 0.26, 0 }, jacket, { Material = "Fabric" }),
		piece("JacketR", "UpperTorso", { 0.55, 1.08, 1.08 }, { 0.75, 0.26, 0 }, jacket, { Material = "Fabric" }),
		piece("JacketBack", "UpperTorso", { 2.08, 1.08, 0.12 }, { 0, 0.26, 0.5 }, jacket, { Material = "Fabric" }),
		piece("CollarBack", "UpperTorso", { 1.3, 0.4, 0.12 }, { 0, 0.96, 0.44 }, jacketDark, with(LOOSE, { Material = "Fabric", Rotation = { -12, 0, 0 } })),
		piece("CollarL", "UpperTorso", { 0.12, 0.38, 0.5 }, { -0.64, 0.92, 0.12 }, jacketDark, with(LOOSE, { Material = "Fabric" })),
		piece("CollarR", "UpperTorso", { 0.12, 0.38, 0.5 }, { 0.64, 0.92, 0.12 }, jacketDark, with(LOOSE, { Material = "Fabric" })),
		piece("FurL", "UpperTorso", { 0.6, 0.16, 1.12 }, { -0.74, -0.3, 0 }, fur, { Material = "Fabric" }),
		piece("FurR", "UpperTorso", { 0.6, 0.16, 1.12 }, { 0.74, -0.3, 0 }, fur, { Material = "Fabric" }),
		-- Sleeves: flat shoulder seams (no pads), strap bands, darker cuffs over fingerless gloves
		piece("ShoulderSeamL", "LeftUpperArm", { 1.04, 0.12, 1.04 }, { 0, 0.5, 0 }, jacketDark, { Material = "Fabric" }),
		piece("ShoulderSeamR", "RightUpperArm", { 1.04, 0.12, 1.04 }, { 0, 0.5, 0 }, jacketDark, { Material = "Fabric" }),
		piece("ArmStrapL", "LeftUpperArm", { 1.06, 0.1, 1.06 }, { 0, -0.05, 0 }, leather),
		piece("ArmStrapR", "RightUpperArm", { 1.06, 0.1, 1.06 }, { 0, -0.05, 0 }, leather),
		piece("CuffL", "LeftLowerArm", { 1.06, 0.3, 1.06 }, { 0, -0.3, 0 }, jacketDark, { Material = "Fabric" }),
		piece("CuffR", "RightLowerArm", { 1.06, 0.3, 1.06 }, { 0, -0.3, 0 }, jacketDark, { Material = "Fabric" }),
		-- Slung belt with a steel buckle, a hanging tongue and two pouches
		piece("Belt", "LowerTorso", { 2.08, 0.18, 1.08 }, { 0, 0.06, 0 }, leather),
		piece("BeltBuckle", "LowerTorso", { 0.28, 0.2, 0.06 }, { 0.22, 0.06, -0.56 }, steel, METAL),
		piece("BeltTongue", "LowerTorso", { 0.16, 0.6, 0.05 }, { -0.06, -0.3, -0.57 }, leather, LOOSE),
		piece("PouchL", "LowerTorso", { 0.34, 0.32, 0.22 }, { -0.6, -0.04, -0.62 }, leather),
		piece("PouchR", "LowerTorso", { 0.34, 0.32, 0.22 }, { 0.6, -0.04, -0.62 }, leather),
		-- Torn black coat tail: a back panel and side panels flaring out over the hips, tattered tips
		piece("CoatTail", "LowerTorso", { 2.0, 2.3, 0.1 }, { 0, -1.2, 0.6 }, top, with(LOOSE, { Material = "Fabric", Rotation = { -9, 0, 0 } })),
		piece("CoatSideL", "LowerTorso", { 0.1, 1.9, 0.85 }, { -1.06, -1.05, 0.22 }, top, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -9 } })),
		piece("CoatSideR", "LowerTorso", { 0.1, 1.9, 0.85 }, { 1.06, -1.05, 0.22 }, top, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, 9 } })),
		piece("TatterA", "LowerTorso", { 0.08, 0.5, 0.6 }, { -0.65, -2.55, 0.8 }, top, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("TatterB", "LowerTorso", { 0.08, 0.6, 0.6 }, { 0.05, -2.6, 0.8 }, top, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("TatterC", "LowerTorso", { 0.08, 0.45, 0.6 }, { 0.68, -2.52, 0.8 }, top, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, -90, 180 } })),
		-- Strapped trousers, gold-rimmed knee guards
		piece("ThighStrapL", "LeftUpperLeg", { 1.06, 0.1, 1.06 }, { 0, 0.15, 0 }, leather),
		piece("ThighStrapR", "RightUpperLeg", { 1.06, 0.1, 1.06 }, { 0, 0.15, 0 }, leather),
		piece("KneeRimL", "LeftLowerLeg", { 0.1, 0.52, 0.52 }, { 0, 0.4, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneeRimR", "RightLowerLeg", { 0.1, 0.52, 0.52 }, { 0, 0.4, -0.53 }, gold, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("KneePlateL", "LeftLowerLeg", { 0.1, 0.42, 0.42 }, { 0.04, 0, 0 }, jacketDark, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimL" })),
		piece("KneePlateR", "RightLowerLeg", { 0.1, 0.42, 0.42 }, { 0.04, 0, 0 }, jacketDark, with(METAL, { Shape = "Cylinder", RelativeTo = "KneeRimR" })),
		-- Brown boots to mid-shin with a gold rim, dark soles
		piece("BootShaftL", "LeftLowerLeg", { 1.06, 0.62, 1.06 }, { 0, -0.29, 0 }, boot),
		piece("BootShaftR", "RightLowerLeg", { 1.06, 0.62, 1.06 }, { 0, -0.29, 0 }, boot),
		piece("BootRimL", "LeftLowerLeg", { 1.08, 0.06, 1.08 }, { 0, 0.03, 0 }, gold, METAL),
		piece("BootRimR", "RightLowerLeg", { 1.08, 0.06, 1.08 }, { 0, 0.03, 0 }, gold, METAL),
		piece("BootSoleL", "LeftFoot", { 1.04, 0.07, 1.22 }, { 0, -0.13, -0.08 }, jacketDark),
		piece("BootSoleR", "RightFoot", { 1.04, 0.07, 1.22 }, { 0, -0.13, -0.08 }, jacketDark),
	}, "rbxassetid://126833628923084"))
end

-- 14. GIDE (1★ Miner - Veteran Ironvein Axeman) ------------------------------------------
-- From his reference art: stocky veteran miner (Heavy body) with messy dark-brown hair, a scarred
-- stern face, a weathered stone-grey tunic with a high stand collar and frog clasps down the
-- chest, an asymmetric brown leather harness with a steel chest ring, heavy riveted iron pauldrons,
-- bolted steel bracer plates over leather forearm wraps, a utility belt with a five-point brass
-- star buckle and hip pouches, a tattered dark slate cape, thigh straps, angular steel knee
-- guards with brass chevron trim, and heavy miner boots. Face: our own decal from
-- assets/faces/make_gide_face.py. Hair: our Blender mesh (tools/make_gide_hair_ugc.py).
do
	local skin, hair, tunic, tunicDark = { 236, 196, 158 }, { 108, 72, 48 }, { 146, 138, 126 }, { 112, 106, 96 }
	local leather, darkLeather, pants, cape = { 76, 52, 38 }, { 50, 36, 28 }, { 36, 36, 40 }, { 34, 38, 46 }
	local steel, gold = { 122, 126, 132 }, { 200, 162, 78 }
	table.insert(COSTUMES, costume("hero_gide", "Heavy", {
		Skin = skin, UpperTorso = tunic, LowerTorso = pants, UpperArm = tunic, LowerArm = leather, Hand = darkLeather,
		UpperLeg = pants, LowerLeg = darkLeather, Foot = darkLeather,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 2.099, 1.511, 1.741 }, { 0.0, 0.3342, 0.0802 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://115502888193432", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Sideburns: a hair-coloured band lying flat on the round head in front of each ear, from
		-- under the temple locks down the cheek, ending in a point at the jaw (the hair mesh leaves
		-- the side of the face bare there).
		piece("SideburnL", "Head", { 0.07, 0.4, 0.26 }, { -0.5755, 0.05, -0.2562 }, hair, with(LOOSE, { Rotation = { 0, -24, 0 } })),
		piece("SideburnTipL", "Head", { 0.07, 0.3, 0.26 }, { -0.5755, -0.3, -0.2562 }, hair, with(WEDGE, LOOSE, { Rotation = { 0, -24, 180 } })),
		piece("SideburnR", "Head", { 0.07, 0.4, 0.26 }, { 0.5755, 0.05, -0.2562 }, hair, with(LOOSE, { Rotation = { 0, 24, 0 } })),
		piece("SideburnTipR", "Head", { 0.07, 0.3, 0.26 }, { 0.5755, -0.3, -0.2562 }, hair, with(WEDGE, LOOSE, { Rotation = { 0, 24, 180 } })),
		-- High stand collar and V-neckline over the stone-grey miner tunic
		piece("Neckline", "UpperTorso", { 0.36, 0.36, 0.04 }, { 0, 0.62, -0.51 }, skin, { Rotation = { 0, 0, 45 } }),
		piece("CollarBack", "UpperTorso", { 1.36, 0.36, 0.14 }, { 0, 0.94, 0.44 }, tunicDark, with(LOOSE, { Material = "Fabric", Rotation = { -8, 0, 0 } })),
		piece("CollarL", "UpperTorso", { 0.12, 0.34, 0.56 }, { -0.64, 0.90, 0.08 }, tunicDark, with(LOOSE, { Material = "Fabric" })),
		piece("CollarR", "UpperTorso", { 0.12, 0.34, 0.56 }, { 0.64, 0.90, 0.08 }, tunicDark, with(LOOSE, { Material = "Fabric" })),
		-- Centre tunic seam and two dark frog-fastener clasps
		piece("TunicSeam", "UpperTorso", { 0.06, 1.36, 0.04 }, { 0, -0.08, -0.51 }, tunicDark, { Material = "Fabric" }),
		piece("FrogClaspA", "UpperTorso", { 0.38, 0.06, 0.05 }, { 0, 0.36, -0.52 }, darkLeather),
		piece("FrogClaspC", "UpperTorso", { 0.38, 0.06, 0.05 }, { 0, -0.2, -0.52 }, darkLeather),
		-- Asymmetric leather shoulder harness, diagonal chest strap and steel ring
		piece("HarnessL", "UpperTorso", { 0.22, 0.95, 1.08 }, { -0.72, 0.30, 0 }, leather),
		piece("HarnessR", "UpperTorso", { 0.22, 0.95, 1.08 }, { 0.72, 0.30, 0 }, leather),
		piece("ChestStrap", "UpperTorso", { 0.20, 1.65, 0.06 }, { 0, 0.02, -0.54 }, leather, { Rotation = { 0, 0, -52 } }),
		piece("HarnessRing", "UpperTorso", { 0.06, 0.32, 0.32 }, { -0.54, 0.28, -0.55 }, steel, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		-- Tattered dark slate cape behind the back
		piece("CapeBack", "UpperTorso", { 2.16, 1.60, 0.12 }, { 0, 0, 0.54 }, cape, with(LOOSE, { Material = "Fabric", Rotation = { -5, 0, 0 } })),
		piece("CapeLower", "LowerTorso", { 2.24, 2.15, 0.12 }, { 0, -1.10, 0.64 }, cape, with(LOOSE, { Material = "Fabric", Rotation = { -9, 0, 0 } })),
		piece("CapeTatterL", "LowerTorso", { 0.08, 0.55, 0.65 }, { -0.68, -2.38, 0.82 }, cape, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("CapeTatterR", "LowerTorso", { 0.08, 0.55, 0.65 }, { 0.68, -2.38, 0.82 }, cape, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, -90, 180 } })),
		-- Heavy riveted iron pauldrons, leather arm bands and steel forearm bracer plates
		piece("PauldronL", "LeftUpperArm", { 1.18, 0.72, 1.18 }, { -0.06, 0.32, 0 }, steel, with(LOOSE, METAL, { Rotation = { 0, 0, 8 } })),
		piece("PauldronRimL", "LeftUpperArm", { 1.22, 0.10, 1.22 }, { 0, -0.34, 0 }, gold, with(LOOSE, METAL, { RelativeTo = "PauldronL" })),
		piece("PauldronR", "RightUpperArm", { 1.18, 0.72, 1.18 }, { 0.06, 0.32, 0 }, steel, with(LOOSE, METAL, { Rotation = { 0, 0, -8 } })),
		piece("PauldronRimR", "RightUpperArm", { 1.22, 0.10, 1.22 }, { 0, -0.34, 0 }, gold, with(LOOSE, METAL, { RelativeTo = "PauldronR" })),
		piece("ArmStrapL", "LeftUpperArm", { 1.08, 0.14, 1.08 }, { 0, -0.34, 0 }, leather),
		piece("ArmStrapR", "RightUpperArm", { 1.08, 0.14, 1.08 }, { 0, -0.34, 0 }, leather),
		piece("BracerPlateL", "LeftLowerArm", { 0.12, 0.68, 0.76 }, { -0.52, 0.02, 0 }, steel, METAL),
		piece("BracerPlateR", "RightLowerArm", { 0.12, 0.68, 0.76 }, { 0.52, 0.02, 0 }, steel, METAL),
		-- Utility belt with a brass star buckle, hanging belt tongue and hip pouches
		piece("Belt", "LowerTorso", { 2.08, 0.26, 1.08 }, { 0, 0.04, 0 }, leather),
		piece("StarBuckleA", "LowerTorso", { 0.30, 0.30, 0.08 }, { 0, 0.04, -0.57 }, gold, METAL),
		piece("StarBuckleB", "LowerTorso", { 0.30, 0.30, 0.08 }, { 0, 0.04, -0.57 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("BeltTongue", "LowerTorso", { 0.18, 0.68, 0.06 }, { -0.14, -0.34, -0.57 }, darkLeather, LOOSE),
		piece("PouchL", "LowerTorso", { 0.42, 0.38, 0.24 }, { -0.66, 0.02, -0.62 }, leather),
		piece("PouchR", "LowerTorso", { 0.42, 0.38, 0.24 }, { 0.66, 0.02, -0.62 }, leather),
		-- Leather thigh straps, steel knee/shin guards with brass trim, and heavy miner boots
		piece("ThighStrapAL", "LeftUpperLeg", { 1.06, 0.12, 1.06 }, { 0, 0.18, 0 }, leather),
		piece("ThighStrapAR", "RightUpperLeg", { 1.06, 0.12, 1.06 }, { 0, 0.18, 0 }, leather),
		piece("KneeGuardL", "LeftLowerLeg", { 0.68, 0.68, 0.12 }, { 0, 0.10, -0.54 }, steel, METAL),
		piece("KneeTrimL", "LeftLowerLeg", { 0.44, 0.44, 0.06 }, { 0, 0.18, -0.05 }, gold, with(METAL, { RelativeTo = "KneeGuardL", Rotation = { 0, 0, 45 } })),
		piece("KneeGuardR", "RightLowerLeg", { 0.68, 0.68, 0.12 }, { 0, 0.10, -0.54 }, steel, METAL),
		piece("KneeTrimR", "RightLowerLeg", { 0.44, 0.44, 0.06 }, { 0, 0.18, -0.05 }, gold, with(METAL, { RelativeTo = "KneeGuardR", Rotation = { 0, 0, 45 } })),
		piece("BootToeL", "LeftFoot", { 1.06, 0.16, 0.38 }, { 0, -0.06, -0.44 }, gold, METAL),
		piece("BootToeR", "RightFoot", { 1.06, 0.16, 0.38 }, { 0, -0.06, -0.44 }, gold, METAL),
		piece("BootSoleL", "LeftFoot", { 1.08, 0.07, 1.25 }, { 0, -0.13, -0.08 }, steel, METAL),
		piece("BootSoleR", "RightFoot", { 1.08, 0.07, 1.25 }, { 0, -0.13, -0.08 }, steel, METAL),
	}, "rbxassetid://88342609507901"))
end

-- 15. SHURN (1★ Scholar - Wandering Hearthstone Scholar) --------------------------------
-- From his reference art: sturdy young scholar (Heavy body) with swept-back medium chestnut-brown
-- hair and a loose forehead strand over his left brow, a serious studious expression, a weathered
-- charcoal-slate scholar coat with four horizontal frog-clasp toggles down the chest, a draped
-- brown cloth hood/cowl around the neck, puffed upper sleeves with tattered lower edges over light
-- grey-taupe forearm cloth wraps, a brown leather utility belt with a five-point bronze star
-- buckle, a hanging belt tongue, two front leather pouches and a left-hip drawstring reagent bag,
-- split front coat tails and a tattered brown travelling cloak, dark charcoal trousers, and cuffed
-- brown leather boots. Face: our own decal from assets/faces/make_shurn_face.py. Hair: our Blender
-- mesh (tools/make_shurn_hair_ugc.py).
do
	local skin, hair, coat, coatDark = { 236, 196, 158 }, { 124, 88, 58 }, { 64, 66, 70 }, { 48, 50, 54 }
	local cowl, wraps, leather, darkLeather = { 92, 70, 54 }, { 134, 128, 118 }, { 104, 74, 52 }, { 68, 48, 34 }
	local pouchBag, pants, bronze = { 142, 126, 102 }, { 38, 40, 44 }, { 176, 138, 86 }
	table.insert(COSTUMES, costume("hero_shurn", "Heavy", {
		Skin = skin, UpperTorso = coat, LowerTorso = pants, UpperArm = coat, LowerArm = wraps, Hand = skin,
		UpperLeg = pants, LowerLeg = darkLeather, Foot = leather,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 1.792, 1.492, 1.733 }, { -0.0116, 0.3452, 0.0637 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://115542883011217", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Draped brown cloth scholar cowl / hood around the neck and shoulders
		piece("Neckline", "UpperTorso", { 0.36, 0.36, 0.04 }, { 0, 0.62, -0.51 }, skin, { Rotation = { 0, 0, 45 } }),
		piece("CowlFront", "UpperTorso", { 1.44, 0.28, 0.18 }, { 0, 0.72, -0.48 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { 10, 0, 0 } })),
		piece("CowlBack", "UpperTorso", { 1.62, 0.42, 0.24 }, { 0, 0.88, 0.42 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { -12, 0, 0 } })),
		piece("CowlL", "UpperTorso", { 0.22, 0.34, 0.92 }, { -0.68, 0.82, -0.02 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, 12 } })),
		piece("CowlR", "UpperTorso", { 0.22, 0.34, 0.92 }, { 0.68, 0.82, -0.02 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -12 } })),
		-- Centre coat placket and four horizontal strap frog clasps down the chest
		piece("CoatPlacket", "UpperTorso", { 0.18, 1.28, 0.04 }, { 0, -0.06, -0.51 }, coatDark, { Material = "Fabric" }),
		piece("FrogClaspA", "UpperTorso", { 0.44, 0.07, 0.06 }, { 0, 0.38, -0.53 }, wraps),
		piece("FrogClaspB", "UpperTorso", { 0.44, 0.07, 0.06 }, { 0, 0.15, -0.53 }, wraps),
		piece("FrogClaspC", "UpperTorso", { 0.44, 0.07, 0.06 }, { 0, -0.08, -0.53 }, wraps),
		piece("FrogClaspD", "UpperTorso", { 0.44, 0.07, 0.06 }, { 0, -0.31, -0.53 }, wraps),
		-- Tattered brown travelling cloak behind the back
		piece("CloakUpper", "UpperTorso", { 2.12, 1.58, 0.12 }, { 0, -0.02, 0.54 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { -5, 0, 0 } })),
		piece("CloakLower", "LowerTorso", { 2.22, 2.15, 0.12 }, { 0, -1.10, 0.64 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { -9, 0, 0 } })),
		piece("CloakTatterL", "LowerTorso", { 0.08, 0.55, 0.65 }, { -0.68, -2.38, 0.82 }, cowl, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("CloakTatterR", "LowerTorso", { 0.08, 0.55, 0.65 }, { 0.68, -2.38, 0.82 }, cowl, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, -90, 180 } })),
		-- Puffed scholar upper sleeves, tattered sleeve hems, and layered forearm cloth wraps
		piece("SleevePuffL", "LeftUpperArm", { 1.16, 0.76, 1.16 }, { -0.04, 0.26, 0 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, 6 } })),
		piece("SleeveHemL", "LeftUpperArm", { 1.12, 0.18, 1.12 }, { 0, -0.32, 0 }, coatDark, with(LOOSE, { Material = "Fabric" })),
		piece("SleevePuffR", "RightUpperArm", { 1.16, 0.76, 1.16 }, { 0.04, 0.26, 0 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -6 } })),
		piece("SleeveHemR", "RightUpperArm", { 1.12, 0.18, 1.12 }, { 0, -0.32, 0 }, coatDark, with(LOOSE, { Material = "Fabric" })),
		piece("WrapBandAL", "LeftLowerArm", { 1.06, 0.14, 1.06 }, { 0, 0.18, 0 }, coatDark, { Material = "Fabric" }),
		piece("WrapBandBL", "LeftLowerArm", { 1.06, 0.14, 1.06 }, { 0, -0.14, 0 }, coatDark, { Material = "Fabric" }),
		piece("WrapBandAR", "RightLowerArm", { 1.06, 0.14, 1.06 }, { 0, 0.18, 0 }, coatDark, { Material = "Fabric" }),
		piece("WrapBandBR", "RightLowerArm", { 1.06, 0.14, 1.06 }, { 0, -0.14, 0 }, coatDark, { Material = "Fabric" }),
		-- Double leather belt, five-point bronze star buckle, hanging belt tongue, hip pouches & reagent bag
		piece("Belt", "LowerTorso", { 2.08, 0.26, 1.08 }, { 0, 0.04, 0 }, leather),
		piece("CrossBelt", "LowerTorso", { 2.10, 0.14, 1.10 }, { 0, -0.06, 0 }, darkLeather, LOOSE),
		piece("StarBuckleA", "LowerTorso", { 0.30, 0.30, 0.08 }, { 0, 0.02, -0.57 }, bronze, METAL),
		piece("StarBuckleB", "LowerTorso", { 0.30, 0.30, 0.08 }, { 0, 0.02, -0.57 }, bronze, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("BeltTongue", "LowerTorso", { 0.18, 0.68, 0.06 }, { -0.16, -0.36, -0.57 }, leather, LOOSE),
		piece("PouchL", "LowerTorso", { 0.38, 0.36, 0.22 }, { -0.62, 0.00, -0.60 }, darkLeather),
		piece("PouchR", "LowerTorso", { 0.42, 0.40, 0.24 }, { 0.68, 0.00, -0.60 }, darkLeather),
		piece("ReagentBag", "LowerTorso", { 0.36, 0.48, 0.36 }, { -0.98, -0.22, -0.18 }, pouchBag, with(LOOSE, { Shape = "Ball", Material = "Fabric" })),
		-- Split front scholar coat tails flaring over the thighs
		piece("CoatSkirtFL", "LowerTorso", { 0.88, 1.52, 0.12 }, { -0.54, -0.86, -0.52 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, 10 } })),
		piece("CoatSkirtFR", "LowerTorso", { 0.88, 1.52, 0.12 }, { 0.54, -0.86, -0.52 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, -10 } })),
		piece("CoatSkirtSL", "LowerTorso", { 0.14, 1.56, 1.06 }, { -1.04, -0.88, 0.02 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, 8 } })),
		piece("CoatSkirtSR", "LowerTorso", { 0.14, 1.56, 1.06 }, { 1.04, -0.88, 0.02 }, coat, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -8 } })),
		-- Folded brown leather boot cuffs and heavy scholar boots
		piece("BootCuffL", "LeftLowerLeg", { 1.12, 0.24, 1.12 }, { 0, -0.02, 0 }, leather, LOOSE),
		piece("BootCuffR", "RightLowerLeg", { 1.12, 0.24, 1.12 }, { 0, -0.02, 0 }, leather, LOOSE),
		piece("BootShaftL", "LeftLowerLeg", { 1.06, 0.56, 1.06 }, { 0, -0.32, 0 }, darkLeather),
		piece("BootShaftR", "RightLowerLeg", { 1.06, 0.56, 1.06 }, { 0, -0.32, 0 }, darkLeather),
		piece("BootStrapL", "LeftFoot", { 1.06, 0.12, 0.34 }, { 0, 0.04, -0.18 }, darkLeather),
		piece("BootStrapR", "RightFoot", { 1.06, 0.12, 0.34 }, { 0, 0.04, -0.18 }, darkLeather),
		piece("BootSoleL", "LeftFoot", { 1.08, 0.07, 1.25 }, { 0, -0.13, -0.08 }, coatDark),
		piece("BootSoleR", "RightFoot", { 1.08, 0.07, 1.25 }, { 0, -0.13, -0.08 }, coatDark),
	}, "rbxassetid://120275678632025"))
end

-- 16. DIRAN (Exalted Healer - Covenant Battle-Cleric) ----------------------------------
-- From his reference art: sturdy battle-cleric (Heavy body) with long silver-white hair tied into a
-- high side-swept ponytail and face-framing center-parted bangs, calm amber-brown eyes, a layered
-- bronze-ochre cowl pinned with a four-point gold compass brooch, an off-white and forest-green
-- surcoat with gold filigree trim and chest star studs, ornate gold pauldrons and engraved bracers,
-- a leather utility belt with a five-point gold star buckle, hip pouches and green glass potion
-- vials, split white surcoat skirts over a central green tabard, a tattered dark burgundy cloak,
-- and steel-and-gold armored greaves. Face: our own decal from assets/faces/make_diran_face.py.
-- Hair: our Blender mesh (tools/make_diran_hair_ugc.py).
do
	local skin, hair, surcoat, green = { 236, 196, 158 }, { 192, 201, 214 }, { 228, 226, 220 }, { 48, 92, 58 }
	local cowl, cowlDark, cloak, gold = { 138, 104, 54 }, { 84, 58, 36 }, { 58, 32, 30 }, { 196, 158, 78 }
	local steel, leather, darkLeather, glove = { 142, 146, 154 }, { 96, 62, 40 }, { 62, 40, 26 }, { 42, 36, 34 }
	local potion = { 76, 168, 92 }
	table.insert(COSTUMES, costume("hero_diran", "Heavy", {
		Skin = skin, UpperTorso = surcoat, LowerTorso = green, UpperArm = green, LowerArm = surcoat, Hand = glove,
		UpperLeg = green, LowerLeg = steel, Foot = darkLeather,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 2.23, 2.03, 1.864 }, { -0.3083, 0.2557, 0.1526 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://95241080213006", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Layered bronze-ochre cowl around the neck and 4-point gold compass brooch
		piece("Neckline", "UpperTorso", { 0.36, 0.36, 0.04 }, { 0, 0.62, -0.51 }, green, { Rotation = { 0, 0, 45 } }),
		piece("CowlFront", "UpperTorso", { 1.48, 0.30, 0.20 }, { 0, 0.72, -0.48 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { 10, 0, 0 } })),
		piece("CowlLower", "UpperTorso", { 1.24, 0.22, 0.18 }, { 0, 0.50, -0.50 }, cowlDark, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, 0 } })),
		piece("CowlBack", "UpperTorso", { 1.64, 0.42, 0.24 }, { 0, 0.88, 0.42 }, cowlDark, with(LOOSE, { Material = "Fabric", Rotation = { -12, 0, 0 } })),
		piece("CowlL", "UpperTorso", { 0.24, 0.36, 0.94 }, { -0.68, 0.82, -0.02 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, 12 } })),
		piece("CowlR", "UpperTorso", { 0.24, 0.36, 0.94 }, { 0.68, 0.82, -0.02 }, cowl, with(LOOSE, { Material = "Fabric", Rotation = { 0, 0, -12 } })),
		piece("CompassBroochA", "UpperTorso", { 0.24, 0.24, 0.06 }, { 0.14, 0.60, -0.58 }, gold, with(LOOSE, METAL)),
		piece("CompassBroochB", "UpperTorso", { 0.24, 0.24, 0.06 }, { 0.14, 0.60, -0.58 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, 45 } })),
		-- Forest-green central chest panel with gold filigree trim and star studs
		piece("ChestPanel", "UpperTorso", { 0.56, 1.08, 0.04 }, { 0, -0.10, -0.51 }, green, { Material = "Fabric" }),
		piece("ChestTrimL", "UpperTorso", { 0.08, 1.08, 0.06 }, { -0.30, -0.10, -0.52 }, gold, METAL),
		piece("ChestTrimR", "UpperTorso", { 0.08, 1.08, 0.06 }, { 0.30, -0.10, -0.52 }, gold, METAL),
		piece("ChestStarTop", "UpperTorso", { 0.16, 0.16, 0.06 }, { 0, 0.24, -0.53 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("ChestStarLow", "UpperTorso", { 0.14, 0.14, 0.06 }, { 0, -0.10, -0.53 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		-- Tattered dark burgundy-brown cloak behind the back
		piece("CloakUpper", "UpperTorso", { 2.16, 1.60, 0.12 }, { 0, 0, 0.54 }, cloak, with(LOOSE, { Material = "Fabric", Rotation = { -5, 0, 0 } })),
		piece("CloakLower", "LowerTorso", { 2.26, 2.20, 0.12 }, { 0, -1.12, 0.64 }, cloak, with(LOOSE, { Material = "Fabric", Rotation = { -9, 0, 0 } })),
		piece("CloakTatterL", "LowerTorso", { 0.08, 0.58, 0.68 }, { -0.70, -2.42, 0.82 }, cloak, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, 90, 180 } })),
		piece("CloakTatterR", "LowerTorso", { 0.08, 0.58, 0.68 }, { 0.70, -2.42, 0.82 }, cloak, with(WEDGE, LOOSE, { Material = "Fabric", Rotation = { 0, -90, 180 } })),
		-- Ornate gold pauldrons, sleeve borders and engraved forearm bracer cuffs
		piece("PauldronL", "LeftUpperArm", { 1.18, 0.74, 1.18 }, { -0.06, 0.30, 0 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, 8 } })),
		piece("PauldronPlateL", "LeftUpperArm", { 1.12, 0.14, 1.12 }, { 0, -0.34, 0 }, gold, with(LOOSE, METAL)),
		piece("PauldronR", "RightUpperArm", { 1.18, 0.74, 1.18 }, { 0.06, 0.30, 0 }, gold, with(LOOSE, METAL, { Rotation = { 0, 0, -8 } })),
		piece("PauldronPlateR", "RightUpperArm", { 1.12, 0.14, 1.12 }, { 0, -0.34, 0 }, gold, with(LOOSE, METAL)),
		piece("BracerL", "LeftLowerArm", { 1.10, 0.54, 1.10 }, { 0, -0.06, 0 }, gold, METAL),
		piece("BracerRimL", "LeftLowerArm", { 1.14, 0.10, 1.14 }, { 0, -0.28, 0 }, steel, METAL),
		piece("BracerR", "RightLowerArm", { 1.10, 0.54, 1.10 }, { 0, -0.06, 0 }, gold, METAL),
		piece("BracerRimR", "RightLowerArm", { 1.14, 0.10, 1.14 }, { 0, -0.28, 0 }, steel, METAL),
		-- Utility belt with 5-point gold star buckle, hip pouches and green glass potion vials
		piece("Belt", "LowerTorso", { 2.10, 0.26, 1.10 }, { 0, 0.04, 0 }, leather),
		piece("StarBuckleA", "LowerTorso", { 0.32, 0.32, 0.08 }, { 0, 0.04, -0.58 }, gold, METAL),
		piece("StarBuckleB", "LowerTorso", { 0.32, 0.32, 0.08 }, { 0, 0.04, -0.58 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("BeltTongue", "LowerTorso", { 0.18, 0.68, 0.06 }, { 0.22, -0.34, -0.58 }, darkLeather, LOOSE),
		piece("PouchL", "LowerTorso", { 0.40, 0.38, 0.24 }, { -0.68, 0.02, -0.62 }, leather),
		piece("PouchR", "LowerTorso", { 0.40, 0.38, 0.24 }, { 0.68, 0.02, -0.62 }, leather),
		piece("PotionVialR", "LowerTorso", { 0.24, 0.26, 0.24 }, { 0.40, -0.14, -0.60 }, potion, with(LOOSE, { Shape = "Ball", Material = "Glass" })),
		piece("PotionVialL", "LowerTorso", { 0.24, 0.26, 0.24 }, { -0.94, -0.14, -0.32 }, potion, with(LOOSE, { Shape = "Ball", Material = "Glass" })),
		-- Split white surcoat skirts, central forest-green tabard with gold star & steel/gold greaves
		piece("SkirtFL", "LowerTorso", { 0.72, 1.54, 0.12 }, { -0.62, -0.86, -0.52 }, surcoat, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, 10 } })),
		piece("SkirtFR", "LowerTorso", { 0.72, 1.54, 0.12 }, { 0.62, -0.86, -0.52 }, surcoat, with(LOOSE, { Material = "Fabric", Rotation = { 8, 0, -10 } })),
		piece("CenterTabard", "LowerTorso", { 0.48, 1.58, 0.10 }, { 0, -0.90, -0.54 }, green, with(LOOSE, { Material = "Fabric", Rotation = { 6, 0, 0 } })),
		piece("TabardStar", "LowerTorso", { 0.22, 0.22, 0.06 }, { 0, -0.42, -0.58 }, gold, with(LOOSE, METAL, { Rotation = { 6, 0, 45 } })),
		piece("KneePlateL", "LeftLowerLeg", { 0.68, 0.66, 0.14 }, { 0, 0.12, -0.54 }, steel, METAL),
		piece("KneeTrimL", "LeftLowerLeg", { 0.44, 0.44, 0.06 }, { 0, 0.18, -0.05 }, gold, with(METAL, { RelativeTo = "KneePlateL", Rotation = { 0, 0, 45 } })),
		piece("KneePlateR", "RightLowerLeg", { 0.68, 0.66, 0.14 }, { 0, 0.12, -0.54 }, steel, METAL),
		piece("KneeTrimR", "RightLowerLeg", { 0.44, 0.44, 0.06 }, { 0, 0.18, -0.05 }, gold, with(METAL, { RelativeTo = "KneePlateR", Rotation = { 0, 0, 45 } })),
		piece("BootToeL", "LeftFoot", { 1.06, 0.18, 0.44 }, { 0, -0.04, -0.42 }, steel, METAL),
		piece("BootToeR", "RightFoot", { 1.06, 0.18, 0.44 }, { 0, -0.04, -0.42 }, steel, METAL),
	}, "rbxassetid://106105764225054"))
end

-- 17. VANE (6★ Scholar - Legendary Void Archmage) ------------------------------------------
-- From his reference art: a deep-purple archmage's coat with gold filigree edges over a black
-- undershirt, a high standing collar, a broad double mantle on the shoulders and across the back,
-- wide bell sleeves with gold rims, a violet chest tabard under a gold chain and amethyst pendant,
-- a violet sash with a gold diamond buckle, a long open over-robe that flares at the back and
-- sides over violet front tabards, and dark purple boots with gold straps.
-- Gold earrings. The crystal staff and the floating sigil in the art are the STAFF weapon and
-- VFX, not costume. Face: our own decal from assets/faces/make_vane_face.py.
-- Hair: our Blender mesh (tools/make_vane_hair_ugc.py).
do
	local skin, hair, robe, violet = { 226, 178, 138 }, { 120, 50, 200 }, { 70, 28, 110 }, { 130, 64, 180 }
	local dark, gold, gem, boot = { 34, 24, 44 }, { 200, 160, 70 }, { 190, 100, 255 }, { 52, 30, 66 }
	local FABRIC = { Material = "Fabric" }
	table.insert(COSTUMES, costume("hero_vane", "Standard", {
		Skin = skin, UpperTorso = dark, LowerTorso = robe, UpperArm = robe, LowerArm = robe, Hand = skin,
		UpperLeg = dark, LowerLeg = boot, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 1.773, 1.309, 1.756 }, { -0.0042, 0.3519, 0.071 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://121356449188059", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Open coat over the black undershirt, gold edges down the opening
		piece("CoatL", "UpperTorso", { 0.72, 1.62, 1.08 }, { -0.66, 0, 0 }, robe, FABRIC),
		piece("CoatR", "UpperTorso", { 0.72, 1.62, 1.08 }, { 0.66, 0, 0 }, robe, FABRIC),
		piece("CoatBack", "UpperTorso", { 2.08, 1.62, 0.2 }, { 0, 0, 0.48 }, robe, FABRIC),
		piece("CoatTrimL", "UpperTorso", { 0.06, 1.62, 0.08 }, { -0.3, 0, -0.55 }, gold, METAL),
		piece("CoatTrimR", "UpperTorso", { 0.06, 1.62, 0.08 }, { 0.3, 0, -0.55 }, gold, METAL),
		-- High standing collar, flared back from the neck
		piece("CollarBack", "UpperTorso", { 1.4, 0.55, 0.12 }, { 0, 0.98, 0.5 }, violet, with(LOOSE, FABRIC, { Rotation = { -12, 0, 0 } })),
		piece("CollarL", "UpperTorso", { 0.12, 0.5, 0.6 }, { -0.64, 0.94, 0.18 }, violet, with(LOOSE, FABRIC, { Rotation = { 0, 0, 12 } })),
		piece("CollarR", "UpperTorso", { 0.12, 0.5, 0.6 }, { 0.64, 0.94, 0.18 }, violet, with(LOOSE, FABRIC, { Rotation = { 0, 0, -12 } })),
		-- Violet chest tabard under a gold V chain and an amethyst pendant
		piece("ChestTabard", "UpperTorso", { 0.54, 1.2, 0.05 }, { 0, -0.15, -0.53 }, violet, FABRIC),
		piece("ChainL", "UpperTorso", { 0.42, 0.05, 0.06 }, { -0.15, 0.48, -0.57 }, gold, with(METAL, { Rotation = { 0, 0, -30 } })),
		piece("ChainR", "UpperTorso", { 0.42, 0.05, 0.06 }, { 0.15, 0.48, -0.57 }, gold, with(METAL, { Rotation = { 0, 0, 30 } })),
		piece("Pendant", "UpperTorso", { 0.22, 0.22, 0.06 }, { 0, 0.32, -0.58 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("PendantGem", "UpperTorso", { 0.12, 0.12, 0.05 }, { 0, 0.32, -0.62 }, gem, with(NEON, { Rotation = { 0, 0, 45 } })),
		-- Broad mantle: a gold-rimmed capelet on each shoulder and a panel across the back
		piece("MantleL", "LeftUpperArm", { 1.3, 0.24, 1.3 }, { -0.08, 0.46, 0 }, robe, with(FABRIC, { Rotation = { 0, 0, 12 } })),
		piece("MantleTrimL", "LeftUpperArm", { 1.2, 0.06, 1.32 }, { -0.06, -0.14, 0 }, gold, with(METAL, { RelativeTo = "MantleL" })),
		piece("MantleR", "RightUpperArm", { 1.3, 0.24, 1.3 }, { 0.08, 0.46, 0 }, robe, with(FABRIC, { Rotation = { 0, 0, -12 } })),
		piece("MantleTrimR", "RightUpperArm", { 1.2, 0.06, 1.32 }, { 0.06, -0.14, 0 }, gold, with(METAL, { RelativeTo = "MantleR" })),
		piece("MantleBack", "UpperTorso", { 2.2, 0.9, 0.12 }, { 0, 0.35, 0.62 }, robe, with(LOOSE, FABRIC, { Rotation = { -8, 0, 0 } })),
		piece("MantleBackTrim", "UpperTorso", { 2.22, 0.06, 0.14 }, { 0, -0.44, 0 }, gold, with(LOOSE, METAL, { RelativeTo = "MantleBack" })),
		-- Wide bell sleeves with gold rims
		piece("SleeveL", "LeftLowerArm", { 1.3, 0.5, 1.3 }, { 0, -0.24, 0 }, robe, with(LOOSE, FABRIC)),
		piece("SleeveRimL", "LeftLowerArm", { 1.32, 0.06, 1.32 }, { 0, -0.46, 0 }, gold, with(LOOSE, METAL)),
		piece("SleeveR", "RightLowerArm", { 1.3, 0.5, 1.3 }, { 0, -0.24, 0 }, robe, with(LOOSE, FABRIC)),
		piece("SleeveRimR", "RightLowerArm", { 1.32, 0.06, 1.32 }, { 0, -0.46, 0 }, gold, with(LOOSE, METAL)),
		-- Violet sash with a gold diamond buckle and an amethyst
		piece("Sash", "LowerTorso", { 2.08, 0.32, 1.08 }, { 0, 0.02, 0 }, violet, FABRIC),
		piece("SashTrim", "LowerTorso", { 2.1, 0.05, 1.1 }, { 0, -0.15, 0 }, gold, METAL),
		piece("Buckle", "LowerTorso", { 0.34, 0.34, 0.08 }, { 0, 0.02, -0.58 }, gold, with(METAL, { Rotation = { 0, 0, 45 } })),
		piece("BuckleGem", "LowerTorso", { 0.16, 0.16, 0.06 }, { 0, 0.02, -0.63 }, gem, with(NEON, { Rotation = { 0, 0, 45 } })),
		-- Long open over-robe: a flared back panel with a gold hem, flared side panels, violet front tabards
		piece("RobeBack", "LowerTorso", { 2.1, 2.7, 0.12 }, { 0, -1.45, 0.6 }, robe, with(LOOSE, FABRIC, { Rotation = { -10, 0, 0 } })),
		piece("RobeBackHem", "LowerTorso", { 2.12, 0.08, 0.14 }, { 0, -1.31, 0 }, gold, with(LOOSE, METAL, { RelativeTo = "RobeBack" })),
		piece("RobeSideL", "LowerTorso", { 0.12, 2.5, 1.1 }, { -1.1, -1.35, 0.05 }, robe, with(LOOSE, FABRIC, { Rotation = { 0, 0, -8 } })),
		piece("RobeSideR", "LowerTorso", { 0.12, 2.5, 1.1 }, { 1.1, -1.35, 0.05 }, robe, with(LOOSE, FABRIC, { Rotation = { 0, 0, 8 } })),
		piece("TabardL", "LowerTorso", { 0.5, 2.0, 0.06 }, { -0.3, -1.1, -0.58 }, violet, with(LOOSE, FABRIC)),
		piece("TabardR", "LowerTorso", { 0.5, 2.0, 0.06 }, { 0.3, -1.1, -0.58 }, violet, with(LOOSE, FABRIC)),
		-- Boots: gold shin straps and gold soles
		piece("BootStrapL", "LeftLowerLeg", { 1.08, 0.1, 1.08 }, { 0, -0.3, 0 }, gold, METAL),
		piece("BootStrapR", "RightLowerLeg", { 1.08, 0.1, 1.08 }, { 0, -0.3, 0 }, gold, METAL),
		piece("BootSoleL", "LeftFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.08 }, gold, METAL),
		piece("BootSoleR", "RightFoot", { 1.1, 0.07, 1.28 }, { 0, -0.13, -0.08 }, gold, METAL),
		-- Gold earrings (1.2-head units)
		piece("EarringL", "Head", { 0.07, 0.16, 0.07 }, { -0.61, -0.22, 0.02 }, gold, METAL),
		piece("EarringR", "Head", { 0.07, 0.16, 0.07 }, { 0.61, -0.22, 0.02 }, gold, METAL),
	}, "rbxassetid://76929313677044"))
end

-- 18. AELI (Superior Marksman - Elven Ranger) ---------------------------------------------
-- Adapted from the elven-ranger reference art as a woman (Slim body, docs/hero-art-pipeline.md
-- §4.2 "Feminine body"): a fitted forest-green ranger's coat with a high standing collar, a
-- corset band and narrow belt cinching the waist, silver frog clasps and leaf medallions, a fur
-- ruff, flat silver shoulder caps over thin moss-green capelets (nothing widens the shoulder
-- line), slim silver bracers with glowing green runes, a leather bandolier and hip pouch, coat
-- skirts with silver hems that flare out below the belt, tall brown boots, and a long moss-green
-- cape wrapping her sides with a tattered leaf hem. Pointed elf ears. Her ash-blond hair (our
-- Blender mesh, tools/make_aeli_hair_ugc.py) gathers at the back of the crown under a silver
-- clasp into a long braid that hangs behind her right shoulder and ends in a silver cuff. The bow
-- is the BOW weapon, not costume. Face: our own decal from assets/faces/make_aeli_face.py.
do
	local skin, hair, green, moss = { 232, 196, 160 }, { 206, 192, 164 }, { 50, 72, 44 }, { 128, 142, 96 }
	local silver, leather, darkLeather, trousers = { 196, 200, 206 }, { 96, 62, 42 }, { 66, 42, 30 }, { 58, 58, 48 }
	local boot, fur, glow, darkGreen = { 82, 58, 42 }, { 150, 136, 118 }, { 150, 255, 170 }, { 36, 54, 34 }
	local FABRIC = { Material = "Fabric" }
	table.insert(COSTUMES, costume("hero_aeli", "Slim", {
		Skin = skin, UpperTorso = green, LowerTorso = green, UpperArm = green, LowerArm = green, Hand = skin,
		UpperLeg = trousers, LowerLeg = boot, Foot = boot,
	}, {
		-- Hair mesh: centred on the export's bounding box and turned 180 degrees to undo the
		-- importer's rotation.
		piece("HairMesh", "Head", { 1.665, 3.263, 1.877 }, { 0.004, -0.6155, 0.1939 }, hair, with(LOOSE, {
			Rotation = { 0, 180, 0 },
			Mesh = { MeshId = "rbxassetid://70386605530551", Scale = { 0.01, 0.01, 0.01 } },
		})),
		-- Pointed elf ears through the hair (1.2-head units): tips up and back, leaning out.
		piece("EarL", "Head", { 0.06, 0.46, 0.24 }, { -0.74, 0.04, 0.06 }, skin, with(WEDGE, { Rotation = { 20, 0, 14 } })),
		piece("EarR", "Head", { 0.06, 0.46, 0.24 }, { 0.74, 0.04, 0.06 }, skin, with(WEDGE, { Rotation = { 20, 0, -14 } })),
		-- Silver clasp where the hair gathers into the braid, and the braid's silver cuff.
		piece("HairClasp", "Head", { 0.38, 0.12, 0.22 }, { 0.08, 0.68, 0.72 }, silver, with(METAL, LOOSE, { Rotation = { -35, 0, 0 } })),
		piece("HairClaspLeaf", "Head", { 0.04, 0.24, 0.12 }, { 0.08, 0.8, 0.66 }, silver, with(METAL, WEDGE, LOOSE, { Rotation = { -20, 0, 0 } })),
		piece("BraidCuff", "Head", { 0.2, 0.34, 0.34 }, { 0.58, -1.92, 0.88 }, silver, with(METAL, LOOSE, { Shape = "Cylinder", Rotation = { 0, 0, 90 } })),
		-- High standing collar and a fur ruff that stays inside the shoulder line
		piece("CollarBack", "UpperTorso", { 1.2, 0.42, 0.12 }, { 0, 0.96, 0.42 }, green, with(LOOSE, FABRIC, { Rotation = { -10, 0, 0 } })),
		piece("CollarL", "UpperTorso", { 0.44, 0.36, 0.1 }, { -0.32, 0.92, -0.4 }, green, with(LOOSE, FABRIC, { Rotation = { 0, 22, 0 } })),
		piece("CollarR", "UpperTorso", { 0.44, 0.36, 0.1 }, { 0.32, 0.92, -0.4 }, green, with(LOOSE, FABRIC, { Rotation = { 0, -22, 0 } })),
		piece("FurRuff", "UpperTorso", { 1.9, 0.3, 1.2 }, { 0, 0.74, 0.04 }, fur, with(LOOSE, FABRIC)),
		-- Fitted front: a silver frog clasp, leaf medallions and a leather bandolier
		piece("Clasp", "UpperTorso", { 0.22, 0.07, 0.05 }, { 0, 0.2, -0.53 }, silver, METAL),
		piece("MedallionL", "UpperTorso", { 0.06, 0.2, 0.2 }, { -0.5, 0.52, -0.53 }, silver, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("MedallionR", "UpperTorso", { 0.06, 0.2, 0.2 }, { 0.5, 0.52, -0.53 }, silver, with(METAL, { Shape = "Cylinder", Rotation = { 0, 90, 0 } })),
		piece("Bandolier", "UpperTorso", { 0.2, 1.8, 0.06 }, { 0.1, 0.02, -0.53 }, leather, { Rotation = { 0, 0, -30 } }),
		-- Corset band: a darker green band at the bottom of the torso cinches the waist
		piece("Corset", "UpperTorso", { 2.04, 0.34, 1.04 }, { 0, -0.6, 0 }, darkGreen, FABRIC),
		piece("CorsetLace", "UpperTorso", { 0.06, 0.3, 0.05 }, { 0, -0.6, -0.54 }, silver, METAL),
		-- Long moss-green cape wrapping her sides, with a tattered leaf hem
		piece("CapeBack", "UpperTorso", { 2.0, 3.6, 0.08 }, { 0, -1.4, 0.64 }, moss, with(LOOSE, FABRIC, { Rotation = { -6, 0, 0 } })),
		piece("CapeSideL", "UpperTorso", { 0.08, 3.0, 0.9 }, { -1.08, -1.3, 0.3 }, moss, with(LOOSE, FABRIC, { Rotation = { 0, 0, -7 } })),
		piece("CapeSideR", "UpperTorso", { 0.08, 3.0, 0.9 }, { 1.08, -1.3, 0.3 }, moss, with(LOOSE, FABRIC, { Rotation = { 0, 0, 7 } })),
		piece("CapeTatterL", "UpperTorso", { 0.08, 0.5, 0.7 }, { -0.45, -3.42, 0.78 }, moss, with(WEDGE, LOOSE, FABRIC, { Rotation = { 0, 90, 180 } })),
		piece("CapeTatterR", "UpperTorso", { 0.08, 0.5, 0.7 }, { 0.45, -3.48, 0.78 }, moss, with(WEDGE, LOOSE, FABRIC, { Rotation = { 0, -90, 180 } })),
		-- Flat silver shoulder caps over thin moss capelets, both within the arm's width
		piece("ShoulderCapL", "LeftUpperArm", { 1.04, 0.12, 1.04 }, { 0, 0.5, 0 }, silver, with(METAL, { Rotation = { 0, 0, 6 } })),
		piece("CapeletL", "LeftUpperArm", { 1.04, 0.1, 1.04 }, { 0, -0.1, 0 }, moss, with(FABRIC, { RelativeTo = "ShoulderCapL" })),
		piece("ShoulderCapR", "RightUpperArm", { 1.04, 0.12, 1.04 }, { 0, 0.5, 0 }, silver, with(METAL, { Rotation = { 0, 0, -6 } })),
		piece("CapeletR", "RightUpperArm", { 1.04, 0.1, 1.04 }, { 0, -0.1, 0 }, moss, with(FABRIC, { RelativeTo = "ShoulderCapR" })),
		-- Slim silver bracers with a thin glowing rune on the outer face
		piece("BracerL", "LeftLowerArm", { 1.08, 0.56, 1.08 }, { 0, -0.12, 0 }, silver, METAL),
		piece("BracerRuneL", "LeftLowerArm", { 0.03, 0.34, 0.08 }, { -0.55, -0.12, 0 }, glow, NEON),
		piece("BracerR", "RightLowerArm", { 1.08, 0.56, 1.08 }, { 0, -0.12, 0 }, silver, METAL),
		piece("BracerRuneR", "RightLowerArm", { 0.03, 0.34, 0.08 }, { 0.55, -0.12, 0 }, glow, NEON),
		-- Narrow belt and buckle, and a pouch on her right hip
		piece("Belt", "LowerTorso", { 2.06, 0.18, 1.06 }, { 0, 0.08, 0 }, leather),
		piece("Buckle", "LowerTorso", { 0.28, 0.2, 0.07 }, { 0, 0.08, -0.56 }, silver, METAL),
		piece("Pouch", "LowerTorso", { 0.38, 0.38, 0.24 }, { 0.64, -0.26, -0.6 }, leather, LOOSE),
		piece("PouchFlap", "LowerTorso", { 0.4, 0.14, 0.26 }, { 0, 0.15, -0.01 }, darkLeather, with(LOOSE, { RelativeTo = "Pouch" })),
		-- Coat skirts flaring out below the belt so the hips read wider than the waist
		piece("SkirtL", "LowerTorso", { 1.0, 1.15, 0.08 }, { -0.52, -0.72, -0.56 }, green, with(LOOSE, FABRIC, { Rotation = { 6, 0, -10 } })),
		piece("SkirtR", "LowerTorso", { 1.0, 1.15, 0.08 }, { 0.52, -0.72, -0.56 }, green, with(LOOSE, FABRIC, { Rotation = { 6, 0, 10 } })),
		piece("SkirtHemL", "LowerTorso", { 1.0, 0.06, 0.09 }, { 0, -0.57, 0 }, silver, with(LOOSE, METAL, { RelativeTo = "SkirtL" })),
		piece("SkirtHemR", "LowerTorso", { 1.0, 0.06, 0.09 }, { 0, -0.57, 0 }, silver, with(LOOSE, METAL, { RelativeTo = "SkirtR" })),
		-- Tall boots: a thin top rim and strap, no heavy cuff; dark soles
		piece("BootRimL", "LeftLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.52, 0 }, darkLeather),
		piece("BootRimR", "RightLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.52, 0 }, darkLeather),
		piece("BootStrapL", "LeftLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.12, 0 }, darkLeather),
		piece("BootStrapR", "RightLowerLeg", { 1.06, 0.08, 1.06 }, { 0, 0.12, 0 }, darkLeather),
		piece("BootSoleL", "LeftFoot", { 1.04, 0.07, 1.22 }, { 0, -0.13, -0.08 }, darkLeather),
		piece("BootSoleR", "RightFoot", { 1.04, 0.07, 1.22 }, { 0, -0.13, -0.08 }, darkLeather),
	}, "rbxassetid://71843671065006"))
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
