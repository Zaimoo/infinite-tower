--!strict
-- FountainBuilder.luau
-- ModuleScript: Builds the Overhauled Gothic Tiered Goddess Fountain (`PlazaFountain`)
-- at the center of each plot island courtyard.
--
-- Features (per fountain_overhaul_plan.md):
--   1. Multi-tiered gothic stone & antique-gold architecture (`Fountain_Base_And_Tiers`):
--      - Stepped circular foundation plinth (diameter 25.2 studs).
--      - Tier 1 wide ground basin (diameter 23.0 studs) with 4 semi-circular outer catch
--        basins at 45/135/225/315 deg and 4 square gold-topped rim piers at 0/90/180/270 deg.
--      - Tier 2 lower-mid basin with 4 ornate arched spout hoods pouring into the 4 outer
--        catch basins and 12 carved rim spouts pouring into the Tier 1 pool.
--      - 8-column gothic arch colonnade supporting Tier 3.
--      - Tier 3 upper-mid basin with 8 carved gargoyle spouts.
--      - Fluted pedestal with 4 golden volute brackets supporting Tier 4.
--      - Tier 4 top crown basin with 4 spouts and central statue plinth.
--   2. 1:1 Classical/Gothic Draped Goddess Statue (`Goddess_Statue`):
--      - Standing on the top plinth facing -Z (toward PlotSpawn & front bridge gate).
--      - Flowing pleated marble chiton, golden waist girdle & sash ribbon, shoulder shawl,
--        wavy hair locks, ornate golden diadem crown, left arm raised in serene blessing,
--        and right arm cradling a tilted stone-and-gold amphora pouring water.
--   3. Non-Neon UV-Scrolling Basin Water (`Water_Surface_Meshes`):
--      - Deep cyan/blue `#0EA5E9` water discs using `Glass`/`SmoothPlastic` (no blinding Neon)
--        with dual scrolling `Texture` layers driven by `FountainVFXController.luau`.
--   4. Balanced Waterfall Beams, Mist Particles & Ambient PointLight:
--      - 29 named `Waterfall_Spout_1..29` and `Waterfall_Impact_1..29` attachments.
--      - `Beam` waterfalls with `TextureSpeed = 2.5`, `LightEmission = 0.4`, fading transparency.
--      - Soft cyan/white mist `ParticleEmitter` instances at water impact rings.
--      - Single central `PointLight` in the bottom basin (`#38BDF8`, Brightness 1.75, Range 24).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local FountainBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
FountainBuilder.Config = {
	-- Outer Foundation & Tier Dimensions (fits inside PlazaFountainClearRadius = 16.5)
	PlazaDiameter = 25.2,
	PlazaHeight = 0.55,

	Tier1BasinDiameter = 23.0,
	Tier1Height = 3.0,
	CatchBasinRadius = 11.25,
	CatchBasinDiameter = 4.3,

	Tier2BasinDiameter = 15.6,
	Tier2TopY = 6.58,

	Tier3BasinDiameter = 10.8,
	Tier3TopY = 11.9,

	Tier4BasinDiameter = 6.5,
	Tier4TopY = 15.42,
	StatueBaseY = 15.85,

	-- Gothic Stone, Antique Gold & Marble Palette
	StoneDarkMaterial = Enum.Material.Slate,
	StoneDarkColor = Color3.fromRGB(56, 61, 71), -- #383D47
	StoneLightMaterial = Enum.Material.Slate,
	StoneLightColor = Color3.fromRGB(88, 96, 110), -- #58606E
	MarbleMaterial = Enum.Material.Marble,
	MarbleColor = Color3.fromRGB(205, 210, 220), -- #CDD2DC
	GoldMaterial = Enum.Material.Metal,
	GoldColor = Color3.fromRGB(200, 155, 60), -- #C89B3C

	-- Balanced Water & Ambient Lighting (Phase 3)
	WaterColor = Color3.fromRGB(14, 165, 233), -- #0EA5E9 Deep Cyan/Blue
	WaterFoamColor = Color3.fromRGB(186, 230, 253), -- Soft Sky Foam
	WaterRippleTexture = "rbxassetid://6078620892", -- Tileable water caustic/ripple texture
	WaterfallBeamTexture = "rbxassetid://243660364", -- Cascading water/mist sprite
	WaterfallTextureSpeed = 2.5,
	WaterfallLightEmission = 0.4, -- Magical glow without blowing out bloom

	LightColor = Color3.fromRGB(56, 189, 248), -- #38BDF8 Light Blue
	LightBrightness = 1.75, -- Subtle 1.5 - 2.0 range
	LightRange = 24,

	-- Audio
	WaterSoundId = "rbxassetid://9120557629",
	WaterVolume = 0.35,
	WaterMaxDistance = 85,

	-- Build System Compatibility Attributes
	StarterObjectTag = true,
	PlayerRemovable = true,
}

--============================================================================
-- PRIMITIVE HELPERS
--============================================================================
local function makePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.CastShadow = collide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeCylinder(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local isDecorative = props.Decorative == true
	if isDecorative then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
	else
		p.CanCollide = true
		p.CanTouch = false
		p.CanQuery = true
	end
	local pos: Vector3 = props.Position or Vector3.zero
	local height: number = props.Height or 1
	local diameter: number = props.Diameter or 4
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	for k, v in pairs(props) do
		if k ~= "Decorative" and k ~= "Parent" and k ~= "Position" and k ~= "Height" and k ~= "Diameter" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function makeBall(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = makePart(parent, name, size, cf, color, material, false)
	p.Shape = Enum.PartType.Ball
	return p
end

local function ringCF(angleDeg: number, radius: number, y: number): CFrame
	local a = math.rad(angleDeg)
	return CFrame.new(math.sin(a) * radius, y, math.cos(a) * radius) * CFrame.Angles(0, a, 0)
end

local function makeHollowRimRing(
	parent: Instance,
	namePrefix: string,
	outerDiameter: number,
	rimThickness: number,
	rimHeight: number,
	centerY: number,
	segments: number,
	color: Color3,
	material: Enum.Material
)
	local midR = (outerDiameter - rimThickness) * 0.5
	local segAngle = (math.pi * 2) / segments
	local chord = 2 * midR * math.sin(segAngle * 0.5) + 0.22
	for i = 1, segments do
		local a = (i - 0.5) * segAngle
		local cf = CFrame.new(math.sin(a) * midR, centerY, math.cos(a) * midR) * CFrame.Angles(0, a, 0)
		makePart(parent, string.format("%s_Seg_%d", namePrefix, i), Vector3.new(chord, rimHeight, rimThickness), cf, color, material, false)
	end
end

-- Adds dual UV-scrolling Texture instances onto a non-Neon water surface part
local function attachScrollingWaterTextures(waterPart: BasePart, cfg: { [string]: any })
	waterPart:SetAttribute("FountainWaterSurface", true)
	-- Note: Roblox Cylinders have their circular top face on +X (Right) because they are rolled +90 deg on Z.
	local topFace = if waterPart:IsA("Part") and waterPart.Shape == Enum.PartType.Cylinder
		then Enum.NormalId.Right
		else Enum.NormalId.Top

	local texA = Instance.new("Texture")
	texA.Name = "WaterRippleTextureA"
	texA.Face = topFace
	texA.Texture = cfg.WaterRippleTexture
	texA.Color3 = Color3.fromRGB(224, 242, 254)
	texA.Transparency = 0.35
	texA.StudsPerTileU = 5.5
	texA.StudsPerTileV = 5.5
	texA.Parent = waterPart

	local texB = Instance.new("Texture")
	texB.Name = "WaterRippleTextureB"
	texB.Face = topFace
	texB.Texture = cfg.WaterRippleTexture
	texB.Color3 = cfg.WaterFoamColor
	texB.Transparency = 0.48
	texB.StudsPerTileU = 3.8
	texB.StudsPerTileV = 3.8
	texB.Parent = waterPart
end

--============================================================================
-- 1. PROCEDURAL 1:1 GODDESS STATUE BUILDER
--============================================================================
local function buildGoddessStatue(parent: Instance, baseY: number, cfg: { [string]: any }): Model
	local statueModel = Instance.new("Model")
	statueModel.Name = "Goddess_Statue"

	local marble = cfg.MarbleColor
	local marbleMat = cfg.MarbleMaterial
	local gold = cfg.GoldColor
	local goldMat = cfg.GoldMaterial
	local stoneDark = cfg.StoneDarkColor
	local stoneLight = cfg.StoneLightColor
	local stoneMat = cfg.StoneDarkMaterial

	-- Plinth inside Tier 4 Basin
	local plinth = makeCylinder({
		Name = "StatuePlinth",
		Diameter = 2.85,
		Height = 1.1,
		Position = Vector3.new(0, baseY - 0.55, 0),
		Material = stoneMat,
		Color = stoneLight,
		Decorative = true,
		Parent = statueModel,
	})
	statueModel.PrimaryPart = plinth

	makeCylinder({
		Name = "StatuePlinthGoldRing",
		Diameter = 2.72,
		Height = 0.22,
		Position = Vector3.new(0, baseY - 0.1, 0),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = statueModel,
	})

	-- Flowing Pleated Chiton Skirt (6 tapering tiers with 8 vertical fluted drapery ribs)
	local skirtTiers = {
		{ H = 0.65, Y = 0.32, W = 2.45, D = 2.25 },
		{ H = 0.70, Y = 0.98, W = 2.22, D = 2.04 },
		{ H = 0.70, Y = 1.66, W = 1.98, D = 1.82 },
		{ H = 0.68, Y = 2.32, W = 1.74, D = 1.60 },
		{ H = 0.62, Y = 2.95, W = 1.54, D = 1.40 },
		{ H = 0.55, Y = 3.50, W = 1.42, D = 1.26 },
	}
	for idx, tier in ipairs(skirtTiers) do
		makePart(
			statueModel,
			"ChitonSkirt_" .. idx,
			Vector3.new(tier.W, tier.H, tier.D),
			CFrame.new(0, baseY + tier.Y, 0),
			marble,
			marbleMat,
			false
		)
	end
	-- Vertical drapery pleats along the skirt
	for k = 0, 7 do
		local a = math.rad(k * 45 + 22.5)
		local r = 0.88
		makePart(
			statueModel,
			"ChitonPleat_" .. (k + 1),
			Vector3.new(0.26, 3.4, 0.32),
			CFrame.new(math.sin(a) * r, baseY + 1.75, math.cos(a) * r)
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(math.rad(-7), 0, 0),
			marble,
			marbleMat,
			false
		)
	end

	-- Golden Waist Girdle & Front Sash Ribbon (-Z is front)
	local waistY = baseY + 3.62
	makeCylinder({
		Name = "GoldenWaistGirdle",
		Diameter = 1.52,
		Height = 0.30,
		Position = Vector3.new(0, waistY, 0),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = statueModel,
	})
	makePart(
		statueModel,
		"GoldenSashRibbon",
		Vector3.new(0.26, 2.35, 0.14),
		CFrame.new(0.06, waistY - 1.18, -0.82) * CFrame.Angles(math.rad(6), 0, math.rad(-3)),
		gold,
		goldMat,
		false
	)

	-- Draped Classical Bodice & Bust
	makePart(
		statueModel,
		"GoddessTorso",
		Vector3.new(1.56, 1.85, 1.32),
		CFrame.new(0, baseY + 4.62, -0.02),
		marble,
		marbleMat,
		false
	)
	makePart(
		statueModel,
		"GoddessBustDrape",
		Vector3.new(1.48, 0.88, 1.38),
		CFrame.new(0, baseY + 4.82, -0.10),
		marble,
		marbleMat,
		false
	)
	makeCylinder({
		Name = "GoldenNecklineCollar",
		Diameter = 1.36,
		Height = 0.22,
		Position = Vector3.new(0, baseY + 5.62, -0.02),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = statueModel,
	})

	-- Flowing Left Shoulder Shawl / Himation Drape
	makePart(
		statueModel,
		"ShoulderShawlUpper",
		Vector3.new(0.52, 2.25, 0.68),
		CFrame.new(-0.92, baseY + 4.55, 0.18) * CFrame.Angles(math.rad(8), 0, math.rad(10)),
		marble,
		marbleMat,
		false
	)
	makePart(
		statueModel,
		"ShoulderShawlLower",
		Vector3.new(0.48, 2.45, 0.62),
		CFrame.new(-1.06, baseY + 2.35, 0.32) * CFrame.Angles(math.rad(4), 0, math.rad(4)),
		marble,
		marbleMat,
		false
	)

	-- Neck, Sculpted Classical Head, Wavy Hair & Ornate Golden Diadem Crown
	makeCylinder({
		Name = "GoddessNeck",
		Diameter = 0.56,
		Height = 0.65,
		Position = Vector3.new(0, baseY + 5.96, -0.02),
		Material = marbleMat,
		Color = marble,
		Decorative = true,
		Parent = statueModel,
	})
	local headY = baseY + 6.76
	makePart(statueModel, "GoddessHead", Vector3.new(0.96, 1.18, 1.02), CFrame.new(0, headY, -0.04), marble, marbleMat, false)
	makePart(statueModel, "GoddessHairBack", Vector3.new(1.08, 1.24, 0.78), CFrame.new(0, headY - 0.04, 0.22), marble, marbleMat, false)
	for _, side in ipairs({ -1, 1 }) do
		makePart(
			statueModel,
			"HairTress_" .. (if side < 0 then "L" else "R"),
			Vector3.new(0.34, 1.38, 0.36),
			CFrame.new(side * 0.50, headY - 0.55, -0.08) * CFrame.Angles(0, 0, math.rad(-side * 8)),
			marble,
			marbleMat,
			false
		)
	end

	-- Golden Diadem Crown with 7 floral/star spikes
	local crownY = headY + 0.48
	makeCylinder({
		Name = "GoldenCrownBand",
		Diameter = 1.12,
		Height = 0.22,
		Position = Vector3.new(0, crownY, 0),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = statueModel,
	})
	for k = -3, 3 do
		local ang = math.rad(180 + k * 24)
		local spikeH = 0.34 - math.abs(k) * 0.045
		makePart(
			statueModel,
			"CrownSpike_" .. (k + 4),
			Vector3.new(0.12, spikeH, 0.09),
			CFrame.new(math.sin(ang) * 0.52, crownY + 0.11 + spikeH * 0.5, math.cos(ang) * 0.52) * CFrame.Angles(0, ang, 0),
			gold,
			goldMat,
			false
		)
	end

	-- Left Arm Raised Outward & Upward in Serene Blessing
	makePart(
		statueModel,
		"LeftUpperArm",
		Vector3.new(0.42, 1.35, 0.42),
		CFrame.new(-1.12, baseY + 5.75, -0.14) * CFrame.Angles(math.rad(16), 0, math.rad(48)),
		marble,
		marbleMat,
		false
	)
	local blessingHand = makePart(
		statueModel,
		"LeftForearmBlessing",
		Vector3.new(0.34, 1.45, 0.34),
		CFrame.new(-1.68, baseY + 6.78, -0.34) * CFrame.Angles(math.rad(12), 0, math.rad(22)),
		marble,
		marbleMat,
		false
	)
	blessingHand:SetAttribute("BlessingHandAnchor", true)

	-- Right Arm Cradling the Tilted Pouring Amphora (Water Jug)
	makePart(
		statueModel,
		"RightUpperArm",
		Vector3.new(0.42, 1.35, 0.42),
		CFrame.new(1.06, baseY + 4.95, -0.16) * CFrame.Angles(math.rad(18), 0, math.rad(-36)),
		marble,
		marbleMat,
		false
	)
	makePart(
		statueModel,
		"RightForearmJug",
		Vector3.new(0.36, 1.15, 0.36),
		CFrame.new(1.46, baseY + 4.12, -0.42) * CFrame.Angles(math.rad(28), 0, math.rad(-18)),
		marble,
		marbleMat,
		false
	)

	-- Ornate Tilted Amphora (Water Jug) pouring downward from right hip
	local jugP0 = Vector3.new(1.18, baseY + 4.28, -0.18)
	local jugP1 = Vector3.new(1.76, baseY + 3.50, -0.68)
	local jugMid = (jugP0 + jugP1) * 0.5
	local jugCF = CFrame.lookAt(jugMid, jugP1) * CFrame.Angles(math.rad(-90), 0, 0)

	makePart(statueModel, "AmphoraBelly", Vector3.new(1.28, 0.82, 1.28), jugCF, stoneDark, stoneMat, false).Shape = Enum.PartType.Ball
	makePart(statueModel, "AmphoraGoldBand", Vector3.new(0.22, 1.34, 1.34), jugCF * CFrame.Angles(0, 0, math.rad(90)), gold, goldMat, false).Shape = Enum.PartType.Cylinder
	makePart(statueModel, "AmphoraNeck", Vector3.new(0.55, 0.58, 0.58), jugCF * CFrame.new(0, 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)), stoneLight, stoneMat, false).Shape = Enum.PartType.Cylinder
	makePart(statueModel, "AmphoraMouthRim", Vector3.new(0.18, 0.78, 0.78), jugCF * CFrame.new(0, 0.58, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, goldMat, false).Shape = Enum.PartType.Cylinder

	statueModel.Parent = parent
	return statueModel
end

--============================================================================
-- 2. WATERFALL BEAM & IMPACT MIST FACTORY
--============================================================================
local function createSpoutBeamAndMist(
	socketHolder: BasePart,
	index: number,
	spoutPos: Vector3,
	impactPos: Vector3,
	width0: number,
	width1: number,
	curve0: number,
	curve1: number,
	emitMist: boolean,
	cfg: { [string]: any }
)
	local horiz = Vector3.new(impactPos.X - spoutPos.X, 0, impactPos.Z - spoutPos.Z)
	local radialDir = if horiz.Magnitude > 0.01 then horiz.Unit else Vector3.new(0, 0, -1)

	local aSpout = Instance.new("Attachment")
	aSpout.Name = string.format("Waterfall_Spout_%d", index)
	aSpout.Position = spoutPos
	aSpout.Axis = (radialDir * 0.65 - Vector3.yAxis * 0.75).Unit
	aSpout.Parent = socketHolder

	local aImpact = Instance.new("Attachment")
	aImpact.Name = string.format("Waterfall_Impact_%d", index)
	aImpact.Position = impactPos
	aImpact.Axis = Vector3.new(0, 1, 0)
	aImpact.Parent = socketHolder

	-- Primary translucent cyan-white water ribbon
	local bodyBeam = Instance.new("Beam")
	bodyBeam.Name = string.format("WaterfallBody_%d", index)
	bodyBeam.Attachment0 = aSpout
	bodyBeam.Attachment1 = aImpact
	bodyBeam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(224, 242, 254)),
		ColorSequenceKeypoint.new(0.45, cfg.WaterFoamColor),
		ColorSequenceKeypoint.new(1.0, cfg.WaterColor),
	})
	bodyBeam.LightEmission = cfg.WaterfallLightEmission
	bodyBeam.LightInfluence = 0.35
	bodyBeam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.12),
		NumberSequenceKeypoint.new(0.92, 0.38),
		NumberSequenceKeypoint.new(1.0, 0.85),
	})
	bodyBeam.Width0 = width0
	bodyBeam.Width1 = width1
	bodyBeam.FaceCamera = true
	bodyBeam.Segments = 14
	bodyBeam.CurveSize0 = curve0
	bodyBeam.CurveSize1 = curve1
	bodyBeam.Parent = socketHolder

	-- Animated UV-scrolling white foam stream overlay (TextureSpeed = 2.5, LightEmission = 0.4)
	local beam = Instance.new("Beam")
	beam.Name = string.format("WaterfallSheet_%d", index)
	beam.Attachment0 = aSpout
	beam.Attachment1 = aImpact
	beam.Texture = cfg.WaterfallBeamTexture
	beam.TextureSpeed = cfg.WaterfallTextureSpeed
	beam.TextureLength = 1.6
	beam.Color = ColorSequence.new(Color3.fromRGB(240, 249, 255), cfg.WaterFoamColor)
	beam.LightEmission = cfg.WaterfallLightEmission
	beam.LightInfluence = 0.25
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.05),
		NumberSequenceKeypoint.new(0.65, 0.05),
		NumberSequenceKeypoint.new(0.9, 0.25),
		NumberSequenceKeypoint.new(1.0, 0.90),
	})
	beam.Width0 = width0 * 0.92
	beam.Width1 = width1 * 1.05
	beam.FaceCamera = true
	beam.Segments = 14
	beam.CurveSize0 = curve0
	beam.CurveSize1 = curve1
	beam.Parent = socketHolder

	if emitMist then
		local mist = Instance.new("ParticleEmitter")
		mist.Name = string.format("SpoutImpactMist_%d", index)
		mist.Texture = cfg.WaterfallBeamTexture
		mist.Color = ColorSequence.new(Color3.fromRGB(224, 242, 254), cfg.WaterColor)
		mist.LightEmission = 0.35
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.72),
			NumberSequenceKeypoint.new(0.45, 0.58),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		mist.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.85),
			NumberSequenceKeypoint.new(0.6, 1.85),
			NumberSequenceKeypoint.new(1.0, 2.75),
		})
		mist.Lifetime = NumberRange.new(0.75, 1.25)
		mist.Rate = 6
		mist.Speed = NumberRange.new(1.2, 2.6)
		mist.SpreadAngle = Vector2.new(75, 25)
		mist.Acceleration = Vector3.new(0, -3.5, 0)
		mist.Parent = aImpact
	end
end

--============================================================================
-- 3. OPTIONAL IMPORTED BLENDER MESH INTEGRATION
--============================================================================
local function findImportedFountainTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("CustomFacilityMeshes")
	local template = custom and custom:FindFirstChild("GoddessFountain")
	if template and template:IsA("Model") and template:FindFirstChildWhichIsA("MeshPart", true) then
		return template
	end
	return nil
end

local function applyImportedFountainMeshes(fountainModel: Model, template: Model, cfg: { [string]: any })
	-- Hide procedural visual parts while keeping collider parts and compatibility parts intact
	local keepHiddenColliders: { [string]: boolean } = {
		PlazaBase = true,
		Tier1_OuterWall = true,
		Tier1_Rim = true,
		Tier1_WaterPool = true,
		Tier2_BasinBody = true,
		Tier2_WaterPool = true,
		Tier3_TopBasin = true,
		Tier3_WaterCrest = true,
		WaterfallSocketHolder = true,
	}
	for _, desc in ipairs(fountainModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			if keepHiddenColliders[desc.Name] then
				desc.Transparency = 1
				for _, child in ipairs(desc:GetChildren()) do
					if child:IsA("Texture") then
						child:Destroy()
					end
				end
			else
				desc:Destroy()
			end
		end
	end

	local clone = template:Clone()
	clone:PivotTo(fountainModel:GetPivot())
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("MeshPart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			if desc.Name == "Fountain_Base_And_Tiers" then
				desc.Color = cfg.StoneDarkColor
				desc.Material = cfg.StoneDarkMaterial
			elseif desc.Name == "Goddess_Statue" then
				desc.Color = cfg.MarbleColor
				desc.Material = cfg.MarbleMaterial
			elseif desc.Name == "Water_Surface_Meshes" then
				desc.Color = cfg.WaterColor
				desc.Material = Enum.Material.Glass
				desc.Transparency = 0.15
				desc.CastShadow = false
				attachScrollingWaterTextures(desc, cfg)
			end
			desc.Parent = fountainModel
		end
	end
	clone:Destroy()
end

--============================================================================
-- 4. MAIN BUILDER
--============================================================================
-- Builds the PlazaFountain model centered at (0, 0, 0) in local island coordinates.
function FountainBuilder.Build(parentIsland: Instance?, customConfig: { [string]: any }?): Model
	local cfg = table.clone(FountainBuilder.Config)
	if customConfig then
		for k, v in pairs(customConfig) do
			(cfg :: any)[k] = v
		end
	end

	local fountainModel = Instance.new("Model")
	fountainModel.Name = "PlazaFountain"
	fountainModel:SetAttribute("StarterObject", cfg.StarterObjectTag)
	fountainModel:SetAttribute("Removable", cfg.PlayerRemovable)
	fountainModel:SetAttribute("ObjectCategory", "DefaultPlazaFountain")
	fountainModel:SetAttribute("GoddessFountainOverhaul", true)

	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Fountain_Base_And_Tiers"
	baseFolder.Parent = fountainModel

	local waterFolder = Instance.new("Folder")
	waterFolder.Name = "Water_Surface_Meshes"
	waterFolder.Parent = fountainModel

	local stoneDark = cfg.StoneDarkColor
	local stoneLight = cfg.StoneLightColor
	local stoneMat = cfg.StoneDarkMaterial
	local gold = cfg.GoldColor
	local goldMat = cfg.GoldMaterial

	-- 1. Upright Root Pivot & Stepped Foundation Plinth
	local rootPivot = makePart(
		fountainModel,
		"FountainRootPivot",
		Vector3.new(1, 1, 1),
		CFrame.new(0, 0, 0),
		stoneDark,
		stoneMat,
		false
	)
	rootPivot.Transparency = 1
	fountainModel.PrimaryPart = rootPivot

	makeCylinder({
		Name = "PlazaBase",
		Diameter = cfg.PlazaDiameter,
		Height = cfg.PlazaHeight,
		Position = Vector3.new(0, cfg.PlazaHeight * 0.5, 0),
		Material = stoneMat,
		Color = stoneDark,
		Decorative = false,
		Parent = fountainModel,
	})

	makeCylinder({
		Name = "PlazaStepRim",
		Diameter = cfg.PlazaDiameter - 0.8,
		Height = 0.25,
		Position = Vector3.new(0, cfg.PlazaHeight + 0.12, 0),
		Material = stoneMat,
		Color = stoneLight,
		Decorative = true,
		Parent = baseFolder,
	})

	-- 2. Tier 1: Wide Ground Basin + Gold Filigree Band + 4 Catch Basins + 4 Square Corner Piers
	local tier1WallH = cfg.Tier1Height - 0.45
	local y1 = cfg.PlazaHeight + tier1WallH * 0.5
	makeCylinder({
		Name = "Tier1_OuterWall",
		Diameter = cfg.Tier1BasinDiameter,
		Height = tier1WallH,
		Position = Vector3.new(0, y1, 0),
		Material = stoneMat,
		Color = stoneDark,
		Decorative = false,
		Parent = fountainModel,
	})
	makeCylinder({
		Name = "Tier1_GoldFiligreeBand",
		Diameter = cfg.Tier1BasinDiameter + 0.24,
		Height = 0.48,
		Position = Vector3.new(0, y1 + 0.2, 0),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = baseFolder,
	})
	-- Invisible cylinder for AngelStatue.luau rim height/radius calculations + 20-segment hollow stone rim
	local tier1Rim = makeCylinder({
		Name = "Tier1_Rim",
		Diameter = cfg.Tier1BasinDiameter + 0.8,
		Height = 0.55,
		Position = Vector3.new(0, cfg.PlazaHeight + cfg.Tier1Height - 0.1, 0),
		Material = stoneMat,
		Color = stoneLight,
		Transparency = 1,
		Decorative = true,
		Parent = fountainModel,
	})
	makeHollowRimRing(baseFolder, "Tier1_HollowRim", cfg.Tier1BasinDiameter + 0.8, 1.25, 0.58, cfg.PlazaHeight + cfg.Tier1Height - 0.08, 24, stoneLight, stoneMat)

	local tier1Pool = makeCylinder({
		Name = "Tier1_WaterPool",
		Diameter = cfg.Tier1BasinDiameter - 1.2,
		Height = 0.28,
		Position = Vector3.new(0, cfg.PlazaHeight + tier1WallH + 0.14, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = cfg.WaterColor,
		Reflectance = 0.25,
		Decorative = true,
		Parent = fountainModel,
	})
	attachScrollingWaterTextures(tier1Pool, cfg)

	-- 4 Square Corner Piers with Gold Relief Tops (0, 90, 180, 270 deg)
	for k = 0, 3 do
		local ang = k * 90
		makePart(baseFolder, "Tier1_CornerPier_" .. (k + 1), Vector3.new(2.2, 3.1, 2.2), ringCF(ang, 11.45, 2.1), stoneLight, stoneMat, true)
		makePart(baseFolder, "Tier1_CornerCap_" .. (k + 1), Vector3.new(2.45, 0.32, 2.45), ringCF(ang, 11.45, 3.72), stoneDark, stoneMat, false)
		makePart(baseFolder, "Tier1_CornerGoldPlaque_" .. (k + 1), Vector3.new(1.85, 0.12, 1.85), ringCF(ang, 11.45, 3.92), gold, goldMat, false)
		makePart(baseFolder, "Tier1_CornerFrontRelief_" .. (k + 1), Vector3.new(1.45, 1.55, 0.12), ringCF(ang, 12.56, 2.15), gold, goldMat, false)
	end

	-- 4 Semi-Circular Outer Catch Basins (45, 135, 225, 315 deg)
	for k = 0, 3 do
		local angRad = math.rad(45 + k * 90)
		local bx = math.sin(angRad) * cfg.CatchBasinRadius
		local bz = math.cos(angRad) * cfg.CatchBasinRadius
		makeCylinder({
			Name = "CatchBasin_Wall_" .. (k + 1),
			Diameter = cfg.CatchBasinDiameter,
			Height = 2.25,
			Position = Vector3.new(bx, 1.68, bz),
			Material = stoneMat,
			Color = stoneDark,
			Decorative = false,
			Parent = baseFolder,
		})
		makeHollowRimRing(baseFolder, "CatchBasin_Rim_" .. (k + 1), cfg.CatchBasinDiameter + 0.35, 0.65, 0.38, 2.98, 12, stoneLight, stoneMat)
		for _, p in ipairs(baseFolder:GetChildren()) do
			if string.find(p.Name, "^CatchBasin_Rim_" .. (k + 1) .. "_Seg_") and p:IsA("BasePart") then
				p.CFrame = CFrame.new(bx, 0, bz) * p.CFrame
			end
		end
		makeCylinder({
			Name = "CatchBasin_GoldBand_" .. (k + 1),
			Diameter = cfg.CatchBasinDiameter + 0.16,
			Height = 0.38,
			Position = Vector3.new(bx, 1.95, bz),
			Material = goldMat,
			Color = gold,
			Decorative = true,
			Parent = baseFolder,
		})
		local catchWater = makeCylinder({
			Name = "CatchBasin_Water_" .. (k + 1),
			Diameter = cfg.CatchBasinDiameter - 0.7,
			Height = 0.22,
			Position = Vector3.new(bx, 2.92, bz),
			Material = Enum.Material.SmoothPlastic,
			Color = cfg.WaterColor,
			Reflectance = 0.25,
			Decorative = true,
			Parent = waterFolder,
		})
		attachScrollingWaterTextures(catchWater, cfg)
	end

	-- 3. Tier 2: Lower-Mid Basin + 4 Ornate Arched Spout Hoods + 12 Rim Spouts
	makeCylinder({
		Name = "Tier2_BasinBody",
		Diameter = cfg.Tier2BasinDiameter,
		Height = 2.9,
		Position = Vector3.new(0, 4.65, 0),
		Material = stoneMat,
		Color = stoneDark,
		Decorative = false,
		Parent = fountainModel,
	})
	makeHollowRimRing(baseFolder, "Tier2_HollowRim", cfg.Tier2BasinDiameter + 0.5, 1.05, 0.45, 6.32, 20, stoneLight, stoneMat)
	makeCylinder({
		Name = "Tier2_GoldBand",
		Diameter = cfg.Tier2BasinDiameter + 0.18,
		Height = 0.42,
		Position = Vector3.new(0, 4.95, 0),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = baseFolder,
	})
	local tier2Pool = makeCylinder({
		Name = "Tier2_WaterPool",
		Diameter = cfg.Tier2BasinDiameter - 1.1,
		Height = 0.24,
		Position = Vector3.new(0, 6.22, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = cfg.WaterColor,
		Reflectance = 0.25,
		Decorative = true,
		Parent = fountainModel,
	})
	attachScrollingWaterTextures(tier2Pool, cfg)

	for k = 0, 3 do
		local ang = 45 + k * 90
		makePart(baseFolder, "Tier2_ArchSpoutHood_" .. (k + 1), Vector3.new(2.35, 2.35, 1.55), ringCF(ang, 7.55, 5.65), stoneLight, stoneMat, false)
		makePart(baseFolder, "Tier2_ArchSpoutCap_" .. (k + 1), Vector3.new(2.55, 0.45, 1.75), ringCF(ang, 7.62, 6.92), stoneDark, stoneMat, false)
		makePart(baseFolder, "Tier2_ArchSpoutGold_" .. (k + 1), Vector3.new(1.85, 1.65, 1.35), ringCF(ang, 7.75, 5.95), gold, goldMat, false)
		makePart(baseFolder, "Tier2_ArchSpoutLip_" .. (k + 1), Vector3.new(0.85, 0.55, 0.95), ringCF(ang, 8.32, 5.65), stoneDark, stoneMat, false)
	end

	-- 4. Gothic Arch Colonnade between Tier 2 and Tier 3 (8 columns + gothic arches)
	makeCylinder({
		Name = "Tier3_CorePillar",
		Diameter = 5.0,
		Height = 4.6,
		Position = Vector3.new(0, 8.5, 0),
		Material = stoneMat,
		Color = stoneDark,
		Decorative = false,
		Parent = baseFolder,
	})
	local colR = 4.45
	for k = 0, 7 do
		local ang = k * 45
		local radA = math.rad(ang)
		local cx, cz = math.sin(radA) * colR, math.cos(radA) * colR
		makeCylinder({
			Name = "GothicColBase_" .. (k + 1),
			Diameter = 1.32,
			Height = 0.55,
			Position = Vector3.new(cx, 6.55, cz),
			Material = stoneMat,
			Color = stoneLight,
			Decorative = true,
			Parent = baseFolder,
		})
		makeCylinder({
			Name = "GothicColShaft_" .. (k + 1),
			Diameter = 0.88,
			Height = 3.2,
			Position = Vector3.new(cx, 8.35, cz),
			Material = stoneMat,
			Color = stoneDark,
			Decorative = true,
			Parent = baseFolder,
		})
		makeCylinder({
			Name = "GothicColCapital_" .. (k + 1),
			Diameter = 1.38,
			Height = 0.48,
			Position = Vector3.new(cx, 10.1, cz),
			Material = goldMat,
			Color = gold,
			Decorative = true,
			Parent = baseFolder,
		})
		local midAng = ang + 22.5
		makePart(baseFolder, "GothicArchRib_" .. (k + 1), Vector3.new(1.85, 0.62, 0.75), ringCF(midAng, colR * 0.94, 10.35), stoneLight, stoneMat, false)
		makePart(baseFolder, "GothicArchKeystone_" .. (k + 1), Vector3.new(0.52, 0.75, 0.85), ringCF(midAng, colR * 0.96, 10.38), gold, goldMat, false)
	end

	-- 5. Tier 3: Upper-Mid Basin + 8 Carved Gargoyle Spouts
	local topBasin = makeCylinder({
		Name = "Tier3_TopBasin",
		Diameter = cfg.Tier3BasinDiameter,
		Height = 1.15,
		Position = Vector3.new(0, 10.95, 0),
		Material = stoneMat,
		Color = stoneDark,
		Decorative = false,
		Parent = fountainModel,
	})
	makeHollowRimRing(baseFolder, "Tier3_HollowRim", cfg.Tier3BasinDiameter + 0.45, 0.85, 0.38, 11.72, 16, stoneLight, stoneMat)
	makeCylinder({
		Name = "Tier3_GoldBand",
		Diameter = cfg.Tier3BasinDiameter + 0.16,
		Height = 0.35,
		Position = Vector3.new(0, 11.15, 0),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = baseFolder,
	})
	local tier3Pool = makeCylinder({
		Name = "Tier3_WaterPool",
		Diameter = cfg.Tier3BasinDiameter - 0.9,
		Height = 0.24,
		Position = Vector3.new(0, 11.65, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = cfg.WaterColor,
		Reflectance = 0.25,
		Decorative = true,
		Parent = waterFolder,
	})
	attachScrollingWaterTextures(tier3Pool, cfg)

	for k = 0, 7 do
		local ang = 22.5 + k * 45
		makePart(baseFolder, "Tier3_GargoyleSpout_" .. (k + 1), Vector3.new(0.95, 0.65, 0.85), ringCF(ang, 5.45, 11.45), stoneLight, stoneMat, false)
		makePart(baseFolder, "Tier3_GargoyleLip_" .. (k + 1), Vector3.new(0.55, 0.42, 0.65), ringCF(ang, 5.68, 11.38), gold, goldMat, false)
	end

	-- 6. Fluted Pedestal with Volute Brackets + Tier 4 Top Crown Basin
	makeCylinder({
		Name = "Tier4_PedestalColumn",
		Diameter = 3.6,
		Height = 2.8,
		Position = Vector3.new(0, 13.1, 0),
		Material = stoneMat,
		Color = stoneDark,
		Decorative = false,
		Parent = baseFolder,
	})
	for k = 0, 3 do
		local ang = 45 + k * 90
		makePart(baseFolder, "Tier4_VoluteBracket_" .. (k + 1), Vector3.new(0.58, 1.85, 0.85), ringCF(ang, 1.85, 12.95) * CFrame.Angles(math.rad(-12), 0, 0), gold, goldMat, false)
	end
	makeCylinder({
		Name = "Tier4_CrownBasin",
		Diameter = cfg.Tier4BasinDiameter,
		Height = 0.85,
		Position = Vector3.new(0, 14.68, 0),
		Material = stoneMat,
		Color = stoneDark,
		Decorative = false,
		Parent = baseFolder,
	})
	makeHollowRimRing(baseFolder, "Tier4_HollowRim", cfg.Tier4BasinDiameter + 0.35, 0.68, 0.34, 15.25, 14, stoneLight, stoneMat)
	makeCylinder({
		Name = "Tier4_GoldBand",
		Diameter = cfg.Tier4BasinDiameter + 0.14,
		Height = 0.28,
		Position = Vector3.new(0, 14.82, 0),
		Material = goldMat,
		Color = gold,
		Decorative = true,
		Parent = baseFolder,
	})

	-- Keep `Tier3_WaterCrest` as the top basin water pool so AngelStatue.luau finds the fountain's top pool!
	local topCrest = makeCylinder({
		Name = "Tier3_WaterCrest",
		Diameter = cfg.Tier4BasinDiameter - 0.75,
		Height = 0.24,
		Position = Vector3.new(0, 15.22, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = cfg.WaterColor,
		Reflectance = 0.25,
		Decorative = true,
		Parent = fountainModel,
	})
	attachScrollingWaterTextures(topCrest, cfg)

	-- 7. Build the 1:1 Classical/Gothic Draped Goddess Statue on the Top Plinth
	buildGoddessStatue(fountainModel, cfg.StatueBaseY, cfg)

	-- 8. Waterfall Spout Sockets, Beams & Splash/Mist Emitters (Phase 3.2 & 3.3)
	local socketHolder = makePart(
		fountainModel,
		"WaterfallSocketHolder",
		Vector3.new(1, 1, 1),
		CFrame.new(0, 0, 0),
		stoneDark,
		stoneMat,
		false
	)
	socketHolder.Transparency = 1

	local spoutIndex = 1
	-- Spout 1: Goddess Amphora Jug pouring into Top Crown Basin
	createSpoutBeamAndMist(
		socketHolder,
		spoutIndex,
		Vector3.new(1.76, 19.35, -0.68),
		Vector3.new(2.05, 15.12, -0.82),
		0.48,
		0.95,
		0.55,
		-0.35,
		true,
		cfg
	)
	spoutIndex += 1

	-- Spouts 2..5: 4 Tier 4 Top Crown Spouts -> Tier 3 Pool
	for k = 0, 3 do
		local a = math.rad(k * 90)
		local sa, ca = math.sin(a), math.cos(a)
		createSpoutBeamAndMist(
			socketHolder,
			spoutIndex,
			Vector3.new(sa * 3.52, 15.0, ca * 3.52),
			Vector3.new(sa * 4.15, 11.62, ca * 4.15),
			0.95,
			1.45,
			0.45,
			-0.35,
			true,
			cfg
		)
		spoutIndex += 1
	end

	-- Spouts 6..13: 8 Tier 3 Gargoyle Spouts -> Tier 2 Pool
	for k = 0, 7 do
		local a = math.rad(22.5 + k * 45)
		local sa, ca = math.sin(a), math.cos(a)
		createSpoutBeamAndMist(
			socketHolder,
			spoutIndex,
			Vector3.new(sa * 5.82, 11.35, ca * 5.82),
			Vector3.new(sa * 6.35, 6.22, ca * 6.35),
			1.15,
			1.75,
			0.65,
			-0.45,
			k % 2 == 0,
			cfg
		)
		spoutIndex += 1
	end

	-- Spouts 14..17: 4 Large Tier 2 Arched Spout Hoods -> 4 Outer Catch Basins
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local sa, ca = math.sin(a), math.cos(a)
		createSpoutBeamAndMist(
			socketHolder,
			spoutIndex,
			Vector3.new(sa * 8.65, 5.62, ca * 8.65),
			Vector3.new(sa * cfg.CatchBasinRadius, 2.95, ca * cfg.CatchBasinRadius),
			1.55,
			2.15,
			1.15,
			-0.55,
			true,
			cfg
		)
		spoutIndex += 1
	end

	-- Spouts 18..29: 12 Tier 2 Rim Spouts (3 per quadrant) -> Tier 1 Main Pool
	for q = 0, 3 do
		local baseAng = q * 90
		for _, subOff in ipairs({ -18, 0, 18 }) do
			local a = math.rad((baseAng + subOff) % 360)
			local sa, ca = math.sin(a), math.cos(a)
			createSpoutBeamAndMist(
				socketHolder,
				spoutIndex,
				Vector3.new(sa * 8.15, 6.02, ca * 8.15),
				Vector3.new(sa * 9.15, 3.22, ca * 9.15),
				1.10,
				1.55,
				0.55,
				-0.35,
				subOff == 0,
				cfg
			)
			spoutIndex += 1
		end
	end

	-- 9. Ambient Fountain Lighting (Phase 3.4: single central PointLight in bottom basin)
	local light = Instance.new("PointLight")
	light.Name = "FountainGlow"
	light.Color = cfg.LightColor
	light.Brightness = cfg.LightBrightness
	light.Range = cfg.LightRange
	light.Shadows = false
	light.Parent = tier1Pool

	-- Subtle ambient base mist across the bottom basin
	local mistEmitter = Instance.new("ParticleEmitter")
	mistEmitter.Name = "BaseWaterMist"
	mistEmitter.Texture = cfg.WaterfallBeamTexture
	mistEmitter.Color = ColorSequence.new(Color3.fromRGB(224, 242, 254), cfg.WaterColor)
	mistEmitter.LightEmission = 0.35
	mistEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.92),
		NumberSequenceKeypoint.new(0.45, 0.72),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	mistEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 4.0),
		NumberSequenceKeypoint.new(1.0, 8.5),
	})
	mistEmitter.Lifetime = NumberRange.new(2.0, 3.2)
	mistEmitter.Rate = 6
	mistEmitter.Speed = NumberRange.new(1.0, 2.2)
	mistEmitter.SpreadAngle = Vector2.new(180, 12)
	mistEmitter.Parent = tier1Rim

	-- Looping Fountain Water Ambience Sound
	local sound = Instance.new("Sound")
	sound.Name = "FountainWaterLoop"
	sound.SoundId = cfg.WaterSoundId
	sound.Volume = cfg.WaterVolume
	sound:SetAttribute("OrigVolume", cfg.WaterVolume)
	local sgAmbience = SoundService:FindFirstChild("SG_Ambience")
	if sgAmbience and sgAmbience:IsA("SoundGroup") then
		sound.SoundGroup = sgAmbience
	end
	sound.RollOffMaxDistance = cfg.WaterMaxDistance
	sound.RollOffMinDistance = 10
	sound.Looped = true
	sound.Parent = topBasin
	sound:Play()

	-- Apply imported Blender MeshParts if present under ReplicatedStorage.Assets.CustomFacilityMeshes.GoddessFountain
	local importedTemplate = findImportedFountainTemplate()
	if importedTemplate then
		applyImportedFountainMeshes(fountainModel, importedTemplate, cfg)
	end

	if parentIsland then
		fountainModel.Parent = parentIsland
	end

	return fountainModel
end

return FountainBuilder
