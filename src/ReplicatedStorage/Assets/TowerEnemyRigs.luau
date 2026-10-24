--!strict
-- Editable native model source for all 40 Tower enemies across 10 biomes.
-- Each limb is articulated by a named Motor6D; no uploaded asset IDs are implied.
local Config = require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local R = {}

type Palette = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Trim: Color3,
	Glow: Color3,
	Mat: Enum.Material,
}

local Palettes: { [string]: Palette } = {
	verdant_ruins = {
		Primary = Color3.fromRGB(65, 48, 37),
		Secondary = Color3.fromRGB(73, 88, 85),
		Accent = Color3.fromRGB(65, 111, 54),
		Trim = Color3.fromRGB(188, 151, 69),
		Glow = Color3.fromRGB(153, 240, 125),
		Mat = Enum.Material.Slate,
	},
	fungal_hollow = {
		Primary = Color3.fromRGB(58, 42, 74),
		Secondary = Color3.fromRGB(92, 68, 116),
		Accent = Color3.fromRGB(72, 168, 154),
		Trim = Color3.fromRGB(210, 145, 235),
		Glow = Color3.fromRGB(110, 255, 220),
		Mat = Enum.Material.SmoothPlastic,
	},
	sunken_sanctuary = {
		Primary = Color3.fromRGB(36, 72, 88),
		Secondary = Color3.fromRGB(58, 108, 122),
		Accent = Color3.fromRGB(214, 102, 92),
		Trim = Color3.fromRGB(205, 182, 120),
		Glow = Color3.fromRGB(95, 225, 255),
		Mat = Enum.Material.Slate,
	},
	ashen_dunes = {
		Primary = Color3.fromRGB(122, 92, 64),
		Secondary = Color3.fromRGB(82, 62, 48),
		Accent = Color3.fromRGB(178, 134, 82),
		Trim = Color3.fromRGB(230, 185, 95),
		Glow = Color3.fromRGB(255, 165, 72),
		Mat = Enum.Material.Sandstone,
	},
	frozen_citadel = {
		Primary = Color3.fromRGB(68, 96, 128),
		Secondary = Color3.fromRGB(135, 178, 215),
		Accent = Color3.fromRGB(185, 225, 250),
		Trim = Color3.fromRGB(215, 230, 248),
		Glow = Color3.fromRGB(130, 235, 255),
		Mat = Enum.Material.Ice,
	},
	thunder_highlands = {
		Primary = Color3.fromRGB(64, 68, 92),
		Secondary = Color3.fromRGB(98, 106, 138),
		Accent = Color3.fromRGB(138, 122, 185),
		Trim = Color3.fromRGB(235, 200, 95),
		Glow = Color3.fromRGB(255, 230, 105),
		Mat = Enum.Material.Slate,
	},
	infernal_foundry = {
		Primary = Color3.fromRGB(48, 38, 42),
		Secondary = Color3.fromRGB(84, 52, 48),
		Accent = Color3.fromRGB(165, 68, 38),
		Trim = Color3.fromRGB(215, 135, 58),
		Glow = Color3.fromRGB(255, 115, 42),
		Mat = Enum.Material.Metal,
	},
	corrupted_grove = {
		Primary = Color3.fromRGB(48, 36, 46),
		Secondary = Color3.fromRGB(76, 52, 68),
		Accent = Color3.fromRGB(118, 56, 98),
		Trim = Color3.fromRGB(168, 132, 92),
		Glow = Color3.fromRGB(215, 95, 245),
		Mat = Enum.Material.Wood,
	},
	astral_archives = {
		Primary = Color3.fromRGB(42, 46, 82),
		Secondary = Color3.fromRGB(78, 86, 138),
		Accent = Color3.fromRGB(132, 118, 210),
		Trim = Color3.fromRGB(232, 205, 132),
		Glow = Color3.fromRGB(155, 215, 255),
		Mat = Enum.Material.SmoothPlastic,
	},
	abyssal_throne = {
		Primary = Color3.fromRGB(32, 22, 34),
		Secondary = Color3.fromRGB(68, 28, 44),
		Accent = Color3.fromRGB(148, 32, 54),
		Trim = Color3.fromRGB(212, 168, 92),
		Glow = Color3.fromRGB(255, 68, 98),
		Mat = Enum.Material.Metal,
	},
}

local function part(parent: Instance, name: string, size: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function R.Build(model: Model, root: BasePart, enemyId: string): any
	local spec = assert(Config.Get(enemyId), "Missing tower enemy rig: " .. enemyId)
	local pal = Palettes[spec.BiomeId] or Palettes.verdant_ruins
	local family = spec.CatalogFamily or spec.RigFamily
	local folder = Instance.new("Model")
	folder.Name = "TowerEnemyArt"
	folder.Parent = model

	local rig: any = {
		Joints = {},
		Parts = {},
		Root = root,
		Model = folder,
		Spec = spec,
		EnemyId = enemyId,
		Distance = 0,
	}

	local function limb(name: string, parent: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, mat: Enum.Material?): Part
		local p = part(folder, name, size, color, shape, mat or pal.Mat)
		p.CFrame = parent.CFrame * offset
		p:SetAttribute("NetId", model:GetAttribute("NetId"))
		table.insert(rig.Parts, p)
		local pivot = CFrame.identity
		if name == "ArmL" or name == "ArmR" or name == "ForearmL" or name == "ForearmR" or name == "LegL" or name == "LegR" or name == "KneeL" or name == "KneeR" then
			pivot = CFrame.new(0, size.Y / 2, 0)
		elseif name == "Head" then
			pivot = CFrame.new(0, -size.Y / 2, 0)
		elseif name:match("^Leg%-1") then
			pivot = CFrame.new(size.X / 2, 0, 0)
		elseif name:match("^Leg1_") then
			pivot = CFrame.new(-size.X / 2, 0, 0)
		end
		local bind = offset * pivot
		local j = Instance.new("Motor6D")
		j.Name = name
		j.Part0 = parent
		j.Part1 = p
		j.C0 = bind
		j.C1 = pivot
		j.Parent = parent
		rig.Joints[name] = { Motor = j, Bind = bind }
		return p
	end

	local function detail(name: string, parent: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
		local p = part(folder, name, size, color, shape, material or pal.Mat)
		p.CFrame = parent.CFrame * offset
		p:SetAttribute("NetId", model:GetAttribute("NetId"))
		table.insert(rig.Parts, p)
		local w = Instance.new("WeldConstraint")
		w.Part0 = parent
		w.Part1 = p
		w.Parent = p
		return p
	end

	if family == "CRAWLER" or family == "INSECT" or family == "CRUSTACEAN" or family == "SCORPION" or spec.RigFamily == "SIX_LEGGED_CRAWLER" then
		local scale = if family == "SCORPION" then 1.35 elseif family == "CRUSTACEAN" then 1.12 else 1.0
		local function v(x: number, y: number, z: number) return Vector3.new(x, y, z) * scale end
		local body = limb("Body", root, v(3.2, 1.5, 4.4), CFrame.new(0, .35 * scale, 0), pal.Primary, Enum.PartType.Ball)
		for i = 1, 3 do
			local shell = detail("OverlappingCarapace", body, v(3.35, 1.05, 1.7), CFrame.new(0, .6 * scale, (i - 2) * 1.25 * scale) * CFrame.Angles(math.rad((i - 2) * 8), 0, 0), i % 2 == 0 and pal.Accent or pal.Secondary, Enum.PartType.Ball)
			detail("ShellRidge", shell, v(.24, .28, 1.3), CFrame.new(0, .5 * scale, 0), pal.Trim)
		end
		if enemyId == "mob_spore_skitter" then
			detail("FungalCap", body, v(3.8, .9, 3.8), CFrame.new(0, 1.15, 0), pal.Accent, Enum.PartType.Cylinder)
			detail("SporeSpot", body, v(1.4, .3, 1.4), CFrame.new(0, 1.55, 0), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
		elseif enemyId == "mob_dune_scarab" then
			detail("ScarabHorn", body, v(.35, 1.4, .5), CFrame.new(0, .9, -2.2) * CFrame.Angles(math.rad(42), 0, 0), pal.Trim)
		elseif enemyId == "mob_rune_mite" then
			detail("AstralHalo", body, v(.25, 2.8, 2.8), CFrame.new(0, 1.35, 0) * CFrame.Angles(0, 0, math.pi / 2), pal.Glow, Enum.PartType.Cylinder, Enum.Material.Neon)
		elseif family == "SCORPION" then
			local tail1 = detail("TailSegment1", body, v(.8, 2.2, .8), CFrame.new(0, 1.2, 1.8) * CFrame.Angles(math.rad(28), 0, 0), pal.Secondary)
			local tail2 = detail("TailSegment2", tail1, v(.65, 2.0, .65), CFrame.new(0, 1.6, -.6) * CFrame.Angles(math.rad(52), 0, 0), pal.Accent)
			detail("VenomStinger", tail2, v(.5, 1.1, .5), CFrame.new(0, 1.1, -.45) * CFrame.Angles(math.rad(35), 0, 0), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
		end
		local head = limb("Head", body, v(2.2, 1.3, 1.5), CFrame.new(0, -.1 * scale, -2.7 * scale), pal.Secondary, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			detail("Eye", head, v(.4, .45, .32), CFrame.new(side * .75 * scale, .28 * scale, -.65 * scale), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
			local jawSize = (family == "CRUSTACEAN" or family == "SCORPION") and v(.85, .55, 2.2) or v(.45, .45, 1.65)
			local jaw = limb(side == -1 and "JawL" or "JawR", head, jawSize, CFrame.new(side * .75 * scale, -.42 * scale, -.95 * scale) * CFrame.Angles(0, side * -.28, 0), pal.Trim)
			detail("Fang", jaw, v(.28, .65, .35), CFrame.new(0, -.2 * scale, -.65 * scale) * CFrame.Angles(.5, 0, 0), pal.Accent)
			for i = 1, 3 do
				local hip = limb("Leg" .. side .. "_" .. i, body, v(1.65, .34, .42), CFrame.new(side * 1.75 * scale, -.35 * scale, (i - 2) * 1.5 * scale) * CFrame.Angles(0, side * (i - 2) * -.3, side * -.25), pal.Primary)
				local shin = limb("Knee" .. side .. "_" .. i, hip, v(.32, 1.15, .35), CFrame.new(side * .8 * scale, -.65 * scale, 0) * CFrame.Angles(0, 0, side * .28), pal.Secondary)
				detail("RootToe", shin, v(.45, .22, .8), CFrame.new(0, -.55 * scale, -.2 * scale), pal.Trim)
			end
		end
	elseif family == "QUADRUPED" then
		local scale = spec.Role == "ELITE" and 1.35 or 1.0
		local function v(x: number, y: number, z: number) return Vector3.new(x, y, z) * scale end
		local body = limb("Body", root, v(2.4, 2.1, 4.8), CFrame.new(0, .35 * scale, 0), pal.Primary)
		detail("SpineRidge", body, v(.6, .55, 4.2), CFrame.new(0, 1.15 * scale, 0), pal.Accent)
		detail("Tail", body, v(.5, .5, 2.2), CFrame.new(0, .3 * scale, 2.9 * scale) * CFrame.Angles(math.rad(-28), 0, 0), pal.Secondary)
		local head = limb("Head", body, v(1.8, 1.6, 2.1), CFrame.new(0, .85 * scale, -2.6 * scale), pal.Secondary)
		detail("Snout", head, v(1.2, .85, 1.4), CFrame.new(0, -.25 * scale, -1.1 * scale), pal.Primary)
		for _, side in { -1, 1 } do
			detail("Eye", head, v(.28, .28, .28), CFrame.new(side * .65 * scale, .25 * scale, -.75 * scale), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
			if enemyId == "elite_thunder_ram" then
				detail("RamHorn", head, v(.55, 1.5, 1.5), CFrame.new(side * 1.05 * scale, .45 * scale, -.2 * scale) * CFrame.Angles(math.rad(25), 0, -side * .45), pal.Trim, Enum.PartType.Cylinder)
			else
				detail("EarCrest", head, v(.3, .85, .45), CFrame.new(side * .65 * scale, .95 * scale, .2 * scale) * CFrame.Angles(math.rad(-18), 0, -side * .2), pal.Accent)
			end
			local frontLeg = limb(side == -1 and "ArmL" or "ArmR", body, v(.75, 1.5, .85), CFrame.new(side * 1.05 * scale, -.65 * scale, -1.65 * scale), pal.Secondary)
			local frontShin = limb(side == -1 and "ForearmL" or "ForearmR", frontLeg, v(.65, 1.3, .75), CFrame.new(0, -1.25 * scale, 0), pal.Primary)
			detail("FrontPaw", frontShin, v(.8, .4, 1.1), CFrame.new(0, -.65 * scale, -.2 * scale), pal.Trim)
			local hindLeg = limb(side == -1 and "LegL" or "LegR", body, v(.85, 1.6, .95), CFrame.new(side * 1.05 * scale, -.65 * scale, 1.65 * scale), pal.Secondary)
			local hindShin = limb(side == -1 and "KneeL" or "KneeR", hindLeg, v(.7, 1.35, .8), CFrame.new(0, -1.3 * scale, 0), pal.Primary)
			detail("HindPaw", hindShin, v(.85, .4, 1.15), CFrame.new(0, -.68 * scale, -.2 * scale), pal.Trim)
		end
	elseif family == "AVIAN" or family == "GIANT_AVIAN" then
		local boss = spec.Role == "BOSS"
		local scale = boss and 2.15 or 1.0
		local function v(x: number, y: number, z: number) return Vector3.new(x, y, z) * scale end
		local body = limb("Body", root, v(2.5, 2.6, 3.2), CFrame.new(0, .55 * scale, 0) * CFrame.Angles(math.rad(-14), 0, 0), pal.Primary, Enum.PartType.Ball)
		detail("BreastPlumage", body, v(2.1, 2.0, 1.2), CFrame.new(0, .1 * scale, -1.2 * scale), pal.Accent, Enum.PartType.Ball)
		detail("TailFeathers", body, v(2.2, .35, 2.6), CFrame.new(0, -.35 * scale, 2.2 * scale) * CFrame.Angles(math.rad(18), 0, 0), pal.Secondary)
		local head = limb("Head", body, v(1.5, 1.6, 1.7), CFrame.new(0, 1.65 * scale, -1.1 * scale), pal.Secondary, Enum.PartType.Ball)
		detail("HookBeak", head, v(.65, .75, 1.5), CFrame.new(0, -.15 * scale, -1.15 * scale) * CFrame.Angles(math.rad(22), 0, 0), pal.Trim)
		detail("StormCrest", head, v(.35, 1.2, 1.4), CFrame.new(0, .85 * scale, .2 * scale) * CFrame.Angles(math.rad(-24), 0, 0), pal.Glow, nil, Enum.Material.Neon)
		for _, side in { -1, 1 } do
			detail("Eye", head, v(.28, .28, .25), CFrame.new(side * .58 * scale, .18 * scale, -.58 * scale), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
			local wing = limb(side == -1 and "ArmL" or "ArmR", body, v(2.6, .45, 1.8), CFrame.new(side * 1.65 * scale, .55 * scale, -.2 * scale) * CFrame.Angles(0, 0, side * .18), pal.Secondary)
			local pinion = limb(side == -1 and "ForearmL" or "ForearmR", wing, v(2.8, .35, 1.5), CFrame.new(side * 2.1 * scale, -.15 * scale, .15 * scale), pal.Accent)
			detail("WingTip", pinion, v(1.8, .22, .9), CFrame.new(side * 1.5 * scale, 0, .2 * scale), pal.Trim)
			local leg = limb(side == -1 and "LegL" or "LegR", body, v(.75, 1.5, .75), CFrame.new(side * .82 * scale, -1.45 * scale, .25 * scale), pal.Secondary)
			local shin = limb(side == -1 and "KneeL" or "KneeR", leg, v(.55, 1.35, .6), CFrame.new(0, -1.25 * scale, 0), pal.Trim)
			detail("Talons", shin, v(.95, .35, 1.4), CFrame.new(0, -.68 * scale, -.25 * scale), pal.Primary)
		end
	elseif family == "SERPENT" then
		local scale = 1.65
		local function v(x: number, y: number, z: number) return Vector3.new(x, y, z) * scale end
		local body = limb("Body", root, v(2.8, 4.2, 2.8), CFrame.new(0, .6 * scale, 0), pal.Primary)
		detail("VentralScales", body, v(2.2, 3.8, .7), CFrame.new(0, 0, -1.25 * scale), pal.Accent)
		local core = detail("AbyssalHeart", body, v(.9, 1.4, .4), CFrame.new(0, .5 * scale, -1.55 * scale), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
		local l = Instance.new("PointLight"); l.Range = 18; l.Brightness = .55; l.Color = pal.Glow; l.Parent = core
		local head = limb("Head", body, v(2.4, 2.0, 2.8), CFrame.new(0, 2.6 * scale, -.4 * scale), pal.Secondary)
		detail("LeviathanCrest", head, v(.4, 1.8, 2.4), CFrame.new(0, 1.1 * scale, .3 * scale) * CFrame.Angles(math.rad(-20), 0, 0), pal.Glow, nil, Enum.Material.Neon)
		for _, side in { -1, 1 } do
			detail("Eye", head, v(.38, .32, .32), CFrame.new(side * .88 * scale, .25 * scale, -.95 * scale), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
			detail("GillFrill", head, v(1.4, 1.3, .3), CFrame.new(side * 1.45 * scale, .1 * scale, -.1 * scale) * CFrame.Angles(0, side * .45, 0), pal.Accent)
			local fin = limb(side == -1 and "ArmL" or "ArmR", body, v(1.1, 2.2, 1.4), CFrame.new(side * 1.85 * scale, .6 * scale, 0) * CFrame.Angles(0, 0, side * .25), pal.Secondary)
			local foreFin = limb(side == -1 and "ForearmL" or "ForearmR", fin, v(.8, 2.0, 1.8), CFrame.new(0, -1.7 * scale, -.2 * scale), pal.Accent)
			detail("CoralClaw", foreFin, v(.4, 1.1, .5), CFrame.new(0, -1.1 * scale, -.4 * scale), pal.Trim)
			local coil = limb(side == -1 and "LegL" or "LegR", body, v(1.4, 1.5, 3.2), CFrame.new(side * 1.1 * scale, -1.9 * scale, .8 * scale), pal.Primary)
			local tail = limb(side == -1 and "KneeL" or "KneeR", coil, v(1.1, 1.1, 3.0), CFrame.new(0, -.5 * scale, 2.2 * scale), pal.Secondary)
			detail("TailFin", tail, v(.3, 1.4, 2.2), CFrame.new(0, .5 * scale, .8 * scale), pal.Glow, nil, Enum.Material.Neon)
		end
	else
		local boss = spec.Role == "BOSS"
		local elite = spec.Role == "ELITE"
		local scale = if boss then 2.0 elseif elite then 1.18 elseif family == "SMALL_BIPED" then .68 else .92
		local function v(x: number, y: number, z: number) return Vector3.new(x, y, z) * scale end
		local function cf(x: number, y: number, z: number) return CFrame.new(v(x, y, z)) end

		local torso = limb("Body", root, v(3.1, 3.4, 1.8), cf(0, .45, 0), boss and pal.Secondary or pal.Primary)
		detail("ChestSlab", torso, v(2.7, 2.1, .6), cf(0, .25, -1.05) * CFrame.Angles(.08, 0, 0), pal.Secondary)
		local core = detail("Heartstone", torso, v(.8, 1.25, .3), cf(0, .4, -1.4) * CFrame.Angles(0, 0, .65), pal.Glow, nil, Enum.Material.Neon)
		local l = Instance.new("PointLight"); l.Range = boss and 16 or 8; l.Brightness = .45; l.Color = pal.Glow; l.Parent = core
		local head = limb("Head", torso, v(1.8, 1.6, 1.6), cf(0, 2.55, 0), pal.Secondary)
		detail("Brow", head, v(2, .5, 1.85), cf(0, .35, -.06) * CFrame.Angles(0, 0, .03), pal.Primary)

		if family == "FUNGAL_BIPED" or family == "FUNGAL_COLOSSUS" or enemyId == "elite_mycelial_brute" then
			detail("MushroomCap", head, v(3.2, .85, 3.2), cf(0, .95, 0), pal.Accent, Enum.PartType.Cylinder)
		end

		for _, side in { -1, 1 } do
			detail("Eye", head, v(.32, .22, .2), cf(side * .48, .05, -.85), pal.Glow, nil, Enum.Material.Neon)
			local crown = detail("BranchCrown", head, v(.32, 1.85, .36), cf(side * 1.1, 1.1, .15) * CFrame.Angles(0, 0, -side * .5), pal.Primary)
			detail("CrownAccent", crown, v(.7, .22, .7), cf(0, .75, 0) * CFrame.Angles(0, .4, 0), pal.Accent)

			local arm = limb(side == -1 and "ArmL" or "ArmR", torso, v(1.25, 2.1, 1.25), cf(side * 2.15, .25, 0) * CFrame.Angles(0, 0, side * .1), boss and pal.Secondary or pal.Primary)
			detail("ShoulderGuard", arm, v(1.8, .8, 1.7), cf(0, .9, 0) * CFrame.Angles(.12, 0, side * .12), pal.Accent, Enum.PartType.Ball)
			local fore = limb(side == -1 and "ForearmL" or "ForearmR", arm, v(1.45, 1.9, 1.5), cf(0, -1.8, -.12), boss and pal.Secondary or pal.Primary)
			for finger = 1, 3 do
				detail("RootFinger", fore, v(.27, .9, .35), cf((finger - 2) * .43, -1.1, -.4) * CFrame.Angles(.25, 0, 0), pal.Trim)
			end

			if side == 1 and (family == "CASTER_BIPED" or family == "FUNGAL_BIPED") then
				local staff = detail("CasterStaff", fore, v(.28, 4.2, .28), cf(0, -1.1, -.85) * CFrame.Angles(math.rad(75), 0, 0), pal.Trim)
				detail("StaffOrb", staff, v(.75, .75, .75), cf(0, 2.2, 0), pal.Glow, Enum.PartType.Ball, Enum.Material.Neon)
			elseif side == 1 and (family == "WEAPON_BIPED" or family == "ARMORED_BIPED" or family == "HEAVY_BIPED" or family == "ROYAL_BIPED" or family == "ROYAL_COLOSSUS" or family == "ARCANE_COLOSSUS") then
				local weapon = detail("SignatureWeapon", fore, v(.32, 3.8, .75), cf(0, -1.2, -1.25) * CFrame.Angles(math.rad(82), 0, 0), pal.Trim)
				detail("WeaponEdge", weapon, v(.14, 3.4, .28), cf(0, .2, -.32), pal.Glow, nil, Enum.Material.Neon)
			elseif side == -1 and (family == "ARMORED_BIPED" and spec.Role == "ELITE") then
				detail("BulwarkShield", fore, v(.4, 2.8, 2.1), cf(-.65, -.4, -.4), pal.Trim)
			end

			local thigh = limb(side == -1 and "LegL" or "LegR", torso, v(1.1, 1.6, 1.25), cf(side * .88, -2.35, 0), pal.Secondary)
			local shin = limb(side == -1 and "KneeL" or "KneeR", thigh, v(1, 1.3, 1.15), cf(0, -1.35, 0), pal.Accent)
			detail("RootFoot", shin, v(1.4, .6, 2.1), cf(0, -.72, -.4), pal.Primary)
			for i = 1, 3 do
				detail("GrowingMoss", torso, v(.7, .28, .7), cf(side * (1.1 + i * .1), .9 - i * .5, .3) * CFrame.Angles(.3, 0, .4), pal.Accent, Enum.PartType.Ball)
			end
		end

		if boss then
			for i = 1, 5 do
				local a = (i - 3) * .3
				detail("AncientCrown", head, v(.32, 1.7 - math.abs(i - 3) * .22, .55), cf((i - 3) * .48, 1.35, .1) * CFrame.Angles(0, 0, -a), pal.Trim)
			end
			detail("BackMonolith", torso, v(2.2, 4.1, 1.2), cf(0, .85, 1.25) * CFrame.Angles(.12, 0, 0), pal.Secondary)
		end
	end

	model:SetAttribute("TowerEnemyId", enemyId)
	model:SetAttribute("ArtPackAssetId", enemyId)
	folder:SetAttribute("Source", "TowerEnemyRigs.luau")
	folder:SetAttribute("RigFamily", spec.RigFamily)
	return rig
end

return R
