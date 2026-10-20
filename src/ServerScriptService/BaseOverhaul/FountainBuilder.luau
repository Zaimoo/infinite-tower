--!strict
-- FountainBuilder.luau
-- ModuleScript: Builds the Default Plaza Fountain at the center of each island.
-- Includes a 48-stud dark stone circular plaza with inlaid rings, 3 stacked basins,
-- bright white flowing water (Neon + Beams + mist ParticleEmitters), soft blue-white PointLight,
-- looping water Sound, and StarterObject/Removable attributes for easy player removal or relocation.

local FountainBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
FountainBuilder.Config = {
	-- Circular Plaza Dimensions (40 to 60 studs across)
	PlazaDiameter = 48,
	PlazaHeight = 0.6,
	InlaidRingOuterDiameter = 38,
	InlaidRingInnerDiameter = 26,

	-- Three-Tier Stacked Basins
	Tier1BasinDiameter = 20,
	Tier1Height = 3.2,
	Tier2BasinDiameter = 12,
	Tier2Height = 3.8,
	Tier3BasinDiameter = 6.5,
	Tier3Height = 3.5,

	-- Colors & Materials
	PlazaMaterial = Enum.Material.Slate,
	PlazaColor = Color3.fromRGB(68, 70, 78),
	InlayMaterial = Enum.Material.Basalt,
	InlayColor = Color3.fromRGB(36, 38, 44),
	BasinStoneMaterial = Enum.Material.Marble,
	BasinStoneColor = Color3.fromRGB(92, 95, 105),
	BasinRimColor = Color3.fromRGB(165, 170, 182),

	-- Water & Lighting
	WaterColor = Color3.fromRGB(235, 248, 255),
	WaterFoamColor = Color3.fromRGB(255, 255, 255),
	LightColor = Color3.fromRGB(195, 230, 255),
	LightBrightness = 1.6,
	LightRange = 36,

	-- Audio
	WaterSoundId = "rbxassetid://9120557629", -- Looping fountain water ambience (ProSoundEffects Water Fountain 1)
	WaterVolume = 0.35,
	WaterMaxDistance = 85,

	-- Build System Compatibility Attributes
	StarterObjectTag = true,
	PlayerRemovable = true,
}

--============================================================================
-- HELPER FUNCTIONS
--============================================================================
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
	-- Roblox Cylinders have their circular axis along X, so rotate 90 deg on Z to stand upright
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

local function createWaterfallBeams(
	parent: Instance,
	topRadius: number,
	bottomRadius: number,
	topY: number,
	bottomY: number,
	count: number,
	waterColor: Color3
)
	local ringHolder = Instance.new("Part")
	ringHolder.Name = "WaterfallBeamHolder"
	ringHolder.Size = Vector3.new(1, 1, 1)
	ringHolder.Transparency = 1
	ringHolder.Anchored = true
	ringHolder.CanCollide = false
	ringHolder.CanTouch = false
	ringHolder.CanQuery = false
	ringHolder.Position = Vector3.new(0, (topY + bottomY) * 0.5, 0)
	ringHolder.Parent = parent

	local halfH = (topY - bottomY) * 0.5
	for i = 1, count do
		local angle = ((i - 1) / count) * (math.pi * 2)
		local ca, sa = math.cos(angle), math.sin(angle)

		local a0 = Instance.new("Attachment")
		a0.Name = string.format("FallTop_%d", i)
		a0.Position = Vector3.new(ca * topRadius, halfH, sa * topRadius)
		a0.Parent = ringHolder

		local a1 = Instance.new("Attachment")
		a1.Name = string.format("FallBottom_%d", i)
		a1.Position = Vector3.new(ca * bottomRadius, -halfH, sa * bottomRadius)
		a1.Parent = ringHolder

		local beam = Instance.new("Beam")
		beam.Name = string.format("WaterfallSheet_%d", i)
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(waterColor, Color3.fromRGB(255, 255, 255))
		beam.LightEmission = 0.85
		beam.LightInfluence = 0.15
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.15),
			NumberSequenceKeypoint.new(0.7, 0.05),
			NumberSequenceKeypoint.new(1.0, 0.35),
		})
		beam.Width0 = (2 * math.pi * topRadius / count) * 1.15
		beam.Width1 = (2 * math.pi * bottomRadius / count) * 1.15
		beam.FaceCamera = false
		beam.CurveSize0 = 0.6
		beam.CurveSize1 = -0.4
		beam.Parent = ringHolder
	end
end

--============================================================================
-- BUILDER
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

	-- 1. Dark Stone Circular Plaza with Concentric Inlaid Ring Pattern
	local plazaBase = makeCylinder({
		Name = "PlazaBase",
		Diameter = cfg.PlazaDiameter,
		Height = cfg.PlazaHeight,
		Position = Vector3.new(0, cfg.PlazaHeight * 0.5, 0),
		Material = cfg.PlazaMaterial,
		Color = cfg.PlazaColor,
		Decorative = false,
		Parent = fountainModel,
	})
	fountainModel.PrimaryPart = plazaBase

	makeCylinder({
		Name = "PlazaInlayOuterRing",
		Diameter = cfg.InlaidRingOuterDiameter,
		Height = cfg.PlazaHeight + 0.08,
		Position = Vector3.new(0, cfg.PlazaHeight * 0.5 + 0.04, 0),
		Material = cfg.InlayMaterial,
		Color = cfg.InlayColor,
		Decorative = true,
		Parent = fountainModel,
	})

	makeCylinder({
		Name = "PlazaInnerStoneDisk",
		Diameter = cfg.InlaidRingOuterDiameter - 3.0,
		Height = cfg.PlazaHeight + 0.14,
		Position = Vector3.new(0, cfg.PlazaHeight * 0.5 + 0.07, 0),
		Material = cfg.PlazaMaterial,
		Color = cfg.PlazaColor,
		Decorative = true,
		Parent = fountainModel,
	})

	makeCylinder({
		Name = "PlazaInlayInnerRing",
		Diameter = cfg.InlaidRingInnerDiameter,
		Height = cfg.PlazaHeight + 0.20,
		Position = Vector3.new(0, cfg.PlazaHeight * 0.5 + 0.10, 0),
		Material = cfg.InlayMaterial,
		Color = cfg.InlayColor,
		Decorative = true,
		Parent = fountainModel,
	})

	-- 2. Tier 1: Wide Base Basin
	local y1 = cfg.PlazaHeight + cfg.Tier1Height * 0.5
	makeCylinder({
		Name = "Tier1_OuterWall",
		Diameter = cfg.Tier1BasinDiameter,
		Height = cfg.Tier1Height,
		Position = Vector3.new(0, y1, 0),
		Material = cfg.BasinStoneMaterial,
		Color = cfg.BasinStoneColor,
		Decorative = false,
		Parent = fountainModel,
	})
	makeCylinder({
		Name = "Tier1_Rim",
		Diameter = cfg.Tier1BasinDiameter + 1.2,
		Height = 0.7,
		Position = Vector3.new(0, cfg.PlazaHeight + cfg.Tier1Height - 0.2, 0),
		Material = cfg.BasinStoneMaterial,
		Color = cfg.BasinRimColor,
		Decorative = true,
		Parent = fountainModel,
	})
	makeCylinder({
		Name = "Tier1_WaterPool",
		Diameter = cfg.Tier1BasinDiameter - 1.6,
		Height = 0.35,
		Position = Vector3.new(0, cfg.PlazaHeight + cfg.Tier1Height + 0.05, 0),
		Material = Enum.Material.Neon,
		Color = cfg.WaterColor,
		Decorative = true,
		Parent = fountainModel,
	})

	-- 3. Tier 2: Middle Stacked Basin
	local tier1TopY = cfg.PlazaHeight + cfg.Tier1Height
	local y2 = tier1TopY + cfg.Tier2Height * 0.5
	makeCylinder({
		Name = "Tier2_BasinBody",
		Diameter = cfg.Tier2BasinDiameter,
		Height = cfg.Tier2Height,
		Position = Vector3.new(0, y2, 0),
		Material = cfg.BasinStoneMaterial,
		Color = cfg.BasinStoneColor,
		Decorative = false,
		Parent = fountainModel,
	})
	makeCylinder({
		Name = "Tier2_WaterPool",
		Diameter = cfg.Tier2BasinDiameter - 1.0,
		Height = 0.35,
		Position = Vector3.new(0, tier1TopY + cfg.Tier2Height + 0.05, 0),
		Material = Enum.Material.Neon,
		Color = cfg.WaterColor,
		Decorative = true,
		Parent = fountainModel,
	})

	-- 4. Tier 3: Top Crown Basin & Spout
	local tier2TopY = tier1TopY + cfg.Tier2Height
	local y3 = tier2TopY + cfg.Tier3Height * 0.5
	local topBasin = makeCylinder({
		Name = "Tier3_TopBasin",
		Diameter = cfg.Tier3BasinDiameter,
		Height = cfg.Tier3Height,
		Position = Vector3.new(0, y3, 0),
		Material = cfg.BasinStoneMaterial,
		Color = cfg.BasinStoneColor,
		Decorative = false,
		Parent = fountainModel,
	})
	local tier3TopY = tier2TopY + cfg.Tier3Height
	local topCrest = makeCylinder({
		Name = "Tier3_WaterCrest",
		Diameter = cfg.Tier3BasinDiameter - 0.6,
		Height = 1.1,
		Position = Vector3.new(0, tier3TopY + 0.4, 0),
		Material = Enum.Material.Neon,
		Color = cfg.WaterFoamColor,
		Decorative = true,
		Parent = fountainModel,
	})

	-- 5. Cascading White Water Beams over Tier 3 -> Tier 2 and Tier 2 -> Tier 1
	createWaterfallBeams(
		fountainModel,
		(cfg.Tier3BasinDiameter * 0.5) - 0.1,
		(cfg.Tier3BasinDiameter * 0.5) + 1.1,
		tier3TopY + 0.3,
		tier2TopY + 0.1,
		10,
		cfg.WaterFoamColor
	)
	createWaterfallBeams(
		fountainModel,
		(cfg.Tier2BasinDiameter * 0.5) - 0.1,
		(cfg.Tier2BasinDiameter * 0.5) + 1.6,
		tier2TopY + 0.15,
		tier1TopY + 0.1,
		14,
		cfg.WaterColor
	)

	-- 6. Soft Blue-White PointLight, Top Water Plume & Base Mist ParticleEmitters, and Looping Sound
	local light = Instance.new("PointLight")
	light.Name = "FountainGlow"
	light.Color = cfg.LightColor
	light.Brightness = cfg.LightBrightness
	light.Range = cfg.LightRange
	light.Shadows = false
	light.Parent = topCrest

	local plumeEmitter = Instance.new("ParticleEmitter")
	plumeEmitter.Name = "TopWaterPlume"
	plumeEmitter.Texture = "rbxassetid://243660364"
	plumeEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), cfg.WaterColor)
	plumeEmitter.LightEmission = 0.8
	plumeEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.15),
		NumberSequenceKeypoint.new(0.6, 0.35),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	plumeEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.4),
		NumberSequenceKeypoint.new(0.5, 2.6),
		NumberSequenceKeypoint.new(1.0, 3.8),
	})
	plumeEmitter.Lifetime = NumberRange.new(0.8, 1.2)
	plumeEmitter.Rate = 14
	plumeEmitter.Speed = NumberRange.new(8, 11)
	plumeEmitter.SpreadAngle = Vector2.new(25, 25)
	plumeEmitter.Acceleration = Vector3.new(0, -24, 0)
	plumeEmitter.Parent = topCrest

	local mistEmitter = Instance.new("ParticleEmitter")
	mistEmitter.Name = "BaseWaterMist"
	mistEmitter.Texture = "rbxassetid://243660364"
	mistEmitter.Color = ColorSequence.new(cfg.WaterColor)
	mistEmitter.LightEmission = 0.65
	mistEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.9),
		NumberSequenceKeypoint.new(0.4, 0.65),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	mistEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 4.5),
		NumberSequenceKeypoint.new(1.0, 9.0),
	})
	mistEmitter.Lifetime = NumberRange.new(1.8, 2.8)
	mistEmitter.Rate = 8
	mistEmitter.Speed = NumberRange.new(1.5, 3.0)
	mistEmitter.SpreadAngle = Vector2.new(180, 15)
	mistEmitter.Parent = topBasin

	local sound = Instance.new("Sound")
	sound.Name = "FountainWaterLoop"
	sound.SoundId = cfg.WaterSoundId
	sound.Volume = cfg.WaterVolume
	sound.RollOffMaxDistance = cfg.WaterMaxDistance
	sound.RollOffMinDistance = 10
	sound.Looped = true
	sound.Parent = topBasin
	sound:Play()

	if parentIsland then
		fountainModel.Parent = parentIsland
	end

	return fountainModel
end

return FountainBuilder
