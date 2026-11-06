--!strict
-- ReplicatedStorage/Assets/RelicModelBuilder.luau
-- Code-authored relic models, one per RelicConfig tier, plus the per-tier effect budget.
-- Models are client-side visuals: RelicVisualController builds one around each server relic root
-- (an invisible hitbox in Workspace.PhysicalRelics) and moves it every frame.
--   - MANA_GEODE: a cracked rock shell with cyan crystals bursting from the cavity
--   - CURSED_URN: a bronze amphora with glowing rune bands, iron straps and a sealed lid
--   - ABYSSAL_CORE: a violet void nucleus in a glass shell, crossed orbit rings and an obsidian cage
--   - CALAMITY_HEART: a crimson heart with arteries, dark veins and jagged crystal growths

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicConfig = require(ReplicatedStorage.Shared.Config.RelicConfig)

local RelicModelBuilder = {}

export type RelicFx = {
	LightRange: number,
	LightBrightness: number,
	BeamHeight: number, -- vertical loot pillar, hidden while carried
	MoteRate: number, -- rising sparkle particles per second
	Smoke: boolean, -- cursed wisps leaking from the urn
	Beat: boolean, -- heart-beat light pulse
}

-- Rarer relics read louder: brighter light, a taller pillar and more motes.
local defaultFxByTier = {
	[1] = { LightRange = 10, LightBrightness = 1.5, BeamHeight = 20, MoteRate = 6, Smoke = false, Beat = false },
	[2] = { LightRange = 12, LightBrightness = 2, BeamHeight = 30, MoteRate = 10, Smoke = true, Beat = false },
	[3] = { LightRange = 16, LightBrightness = 3, BeamHeight = 45, MoteRate = 16, Smoke = false, Beat = false },
	[4] = { LightRange = 24, LightBrightness = 4, BeamHeight = 70, MoteRate = 24, Smoke = false, Beat = true },
}

local fxMap: { [string]: RelicFx } = {
	MANA_GEODE = table.freeze({ LightRange = 10, LightBrightness = 1.5, BeamHeight = 20, MoteRate = 6, Smoke = false, Beat = false }),
	CURSED_URN = table.freeze({ LightRange = 12, LightBrightness = 2, BeamHeight = 30, MoteRate = 10, Smoke = true, Beat = false }),
	ABYSSAL_CORE = table.freeze({ LightRange = 16, LightBrightness = 3, BeamHeight = 45, MoteRate = 16, Smoke = false, Beat = false }),
	CALAMITY_HEART = table.freeze({ LightRange = 24, LightBrightness = 4, BeamHeight = 70, MoteRate = 24, Smoke = false, Beat = true }),
}

if RelicConfig and RelicConfig.Items then
	for itemId, item in pairs(RelicConfig.Items) do
		local bTier = item.BiomeTier or 1
		local f = defaultFxByTier[bTier] or defaultFxByTier[1]
		fxMap[itemId] = table.freeze({
			LightRange = f.LightRange,
			LightBrightness = f.LightBrightness,
			BeamHeight = f.BeamHeight,
			MoteRate = f.MoteRate,
			Smoke = f.Smoke or (item.Rarity == "Origin"),
			Beat = f.Beat,
		})
	end
end

RelicModelBuilder.Fx = table.freeze(fxMap)

local function makePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = true
	p.Parent = parent
	return p
end

-- A vertical cylinder (Roblox cylinders run along X).
local function cylinder(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return makePart(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

local function ball(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return makePart(parent, name, Vector3.one * diameter, cf, color, material, Enum.PartType.Ball)
end

-- A ring of short blocks in the local XZ plane of `cf`.
local function ring(parent: Instance, name: string, radius: number, thickness: number, segments: number, cf: CFrame, color: Color3, material: Enum.Material?)
	local arc = 2 * math.pi * radius / segments * 1.08
	for i = 1, segments do
		local a = (i / segments) * 2 * math.pi
		makePart(parent, name, Vector3.new(arc, thickness, thickness), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, radius), color, material)
	end
end

-- A crystal: a diamond-section shard with a smaller tip, pointing along the local +Y of `cf`.
local function crystal(parent: Instance, name: string, width: number, length: number, cf: CFrame, color: Color3)
	local diamond = cf * CFrame.Angles(0, math.rad(45), 0)
	makePart(parent, name, Vector3.new(width, length, width), diamond * CFrame.new(0, length / 2, 0), color, Enum.Material.Neon)
	makePart(parent, name .. "Tip", Vector3.new(width * 0.55, width * 0.9, width * 0.55), diamond * CFrame.new(0, length + width * 0.3, 0), color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon)
end

local function buildGeode(model: Model, color: Color3)
	local rock, rockDark = Color3.fromRGB(92, 86, 104), Color3.fromRGB(58, 54, 68)
	cylinder(model, "Base", 1.1, 2.6, CFrame.new(0, -1.35, 0), rockDark, Enum.Material.Slate)
	-- Jagged shell: slabs leaning outward around the cavity, alternating heights.
	for i = 1, 7 do
		local a = (i / 7) * 2 * math.pi
		local h = if i % 2 == 0 then 2.3 else 1.7
		makePart(model, "Shell", Vector3.new(1.25, h, 0.45),
			CFrame.Angles(0, a, 0) * CFrame.new(0, -1.0 + h / 2, 1.2) * CFrame.Angles(math.rad(18), 0, 0),
			if i % 3 == 0 then rockDark else rock, Enum.Material.Slate)
	end
	cylinder(model, "Cavity", 0.3, 2.3, CFrame.new(0, -0.75, 0), color:Lerp(Color3.new(0, 0, 0), 0.55), Enum.Material.Glass)
	-- Crystal cluster bursting from the cavity.
	local shards = { { 0, 0, 0, 0.55, 2.2 }, { 14, 0, 25, 0.42, 1.7 }, { -18, 70, -10, 0.4, 1.6 }, { 20, 140, 15, 0.38, 1.5 },
		{ -12, 210, -22, 0.44, 1.8 }, { 24, 290, 8, 0.34, 1.3 } }
	for i, s in shards do
		crystal(model, "Crystal" .. i, s[4], s[5],
			CFrame.new(0, -0.8, 0) * CFrame.Angles(0, math.rad(s[2]), 0) * CFrame.Angles(math.rad(s[1]), 0, math.rad(s[3])),
			if i % 2 == 0 then color:Lerp(Color3.new(1, 1, 1), 0.2) else color)
	end
end

local function buildUrn(model: Model, color: Color3)
	local bronze, iron = Color3.fromRGB(122, 84, 46), Color3.fromRGB(52, 50, 58)
	cylinder(model, "Foot", 0.4, 1.4, CFrame.new(0, -1.7, 0), bronze, Enum.Material.CorrodedMetal)
	ball(model, "Body", 2.6, CFrame.new(0, -0.3, 0), bronze, Enum.Material.CorrodedMetal)
	cylinder(model, "RuneBand", 0.18, 2.66, CFrame.new(0, -0.3, 0), color, Enum.Material.Neon)
	cylinder(model, "RuneBandUpper", 0.14, 2.28, CFrame.new(0, 0.35, 0), color, Enum.Material.Neon)
	cylinder(model, "Strap", 0.22, 2.0, CFrame.new(0, -1.15, 0), iron, Enum.Material.DiamondPlate)
	cylinder(model, "Neck", 0.9, 1.0, CFrame.new(0, 1.1, 0), bronze, Enum.Material.CorrodedMetal)
	cylinder(model, "Lip", 0.25, 1.5, CFrame.new(0, 1.6, 0), bronze, Enum.Material.CorrodedMetal)
	cylinder(model, "Lid", 0.3, 1.2, CFrame.new(0, 1.85, 0), iron, Enum.Material.Metal)
	ball(model, "LidKnob", 0.45, CFrame.new(0, 2.15, 0), color, Enum.Material.Neon)
	makePart(model, "LidCrack", Vector3.new(1.0, 0.06, 0.08), CFrame.new(0, 2.01, 0.2) * CFrame.Angles(0, math.rad(30), 0), color, Enum.Material.Neon)
	-- C-shaped handles from neck to shoulder.
	for _, side in { -1, 1 } do
		makePart(model, "HandleTop", Vector3.new(0.6, 0.2, 0.2), CFrame.new(side * 0.75, 1.3, 0), bronze, Enum.Material.CorrodedMetal)
		makePart(model, "HandleSide", Vector3.new(0.2, 1.0, 0.2), CFrame.new(side * 1.05, 0.85, 0), bronze, Enum.Material.CorrodedMetal)
		makePart(model, "HandleFoot", Vector3.new(0.35, 0.2, 0.2), CFrame.new(side * 0.95, 0.4, 0) * CFrame.Angles(0, 0, math.rad(side * 30)), bronze, Enum.Material.CorrodedMetal)
	end
end

local function buildCore(model: Model, color: Color3)
	local obsidian = Color3.fromRGB(26, 20, 36)
	ball(model, "Nucleus", 1.3, CFrame.identity, color, Enum.Material.Neon)
	local shell = ball(model, "Shell", 2.3, CFrame.identity, color:Lerp(Color3.new(0, 0, 0), 0.6), Enum.Material.Glass)
	shell.Transparency = 0.55
	ring(model, "OrbitA", 1.55, 0.14, 16, CFrame.Angles(math.rad(70), 0, math.rad(20)), color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon)
	ring(model, "OrbitB", 1.55, 0.14, 16, CFrame.Angles(math.rad(-70), 0, math.rad(-20)), color, Enum.Material.Neon)
	-- Obsidian cage: four ribs with caps.
	for i = 1, 4 do
		local a = math.rad(45 + i * 90)
		makePart(model, "Rib", Vector3.new(0.22, 3.0, 0.22), CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 1.3), obsidian, Enum.Material.Basalt)
	end
	cylinder(model, "CapTop", 0.3, 1.1, CFrame.new(0, 1.55, 0), obsidian, Enum.Material.Basalt)
	cylinder(model, "CapBottom", 0.3, 1.1, CFrame.new(0, -1.55, 0), obsidian, Enum.Material.Basalt)
end

local function buildHeart(model: Model, color: Color3)
	local flesh, vein = Color3.fromRGB(150, 18, 36), Color3.fromRGB(60, 8, 22)
	ball(model, "LobeLeft", 1.9, CFrame.new(-0.55, 0.45, 0), flesh, Enum.Material.SmoothPlastic)
	ball(model, "LobeRight", 1.9, CFrame.new(0.55, 0.45, 0), flesh, Enum.Material.SmoothPlastic)
	ball(model, "Body", 2.1, CFrame.new(0, -0.2, 0), flesh, Enum.Material.SmoothPlastic)
	makePart(model, "Apex", Vector3.new(1.45, 1.45, 1.45), CFrame.new(0, -1.0, 0) * CFrame.Angles(0, 0, math.rad(45)), flesh, Enum.Material.SmoothPlastic)
	ball(model, "Glow", 1.2, CFrame.new(0, 0.1, -0.55), color, Enum.Material.Neon)
	cylinder(model, "Aorta", 1.0, 0.55, CFrame.new(0.3, 1.55, 0) * CFrame.Angles(0, 0, math.rad(-12)), flesh, Enum.Material.SmoothPlastic)
	cylinder(model, "Artery", 0.8, 0.4, CFrame.new(-0.4, 1.45, 0.2) * CFrame.Angles(math.rad(10), 0, math.rad(18)), vein, Enum.Material.SmoothPlastic)
	for i, v in { { -0.5, 0.2, 0.95, 20 }, { 0.45, -0.1, 0.98, -25 }, { 0.05, 0.6, 1.0, 5 }, { -0.2, -0.6, 0.85, 40 } } do
		makePart(model, "Vein" .. i, Vector3.new(0.12, 1.3, 0.12), CFrame.new(v[1], v[2], v[3]) * CFrame.Angles(0, 0, math.rad(v[4])), vein, Enum.Material.SmoothPlastic)
	end
	-- Calamity crystal growths jutting from the flesh.
	local spikes = { { 1.0, 0.8, 0.3, -50, 20 }, { -1.05, 0.7, -0.2, 55, -15 }, { 0.6, -0.5, -0.8, -30, -60 }, { -0.5, 1.2, -0.6, 25, -40 }, { 0.2, 0.3, -1.0, 0, -80 } }
	for i, s in spikes do
		crystal(model, "Spike" .. i, 0.32, 0.9, CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(math.rad(s[5]), 0, math.rad(s[4])), color)
	end
end

local builders: { [string]: (Model, Color3) -> () } = {
	MANA_GEODE = buildGeode,
	CURSED_URN = buildUrn,
	ABYSSAL_CORE = buildCore,
	CALAMITY_HEART = buildHeart,
}

if RelicConfig and RelicConfig.Items then
	for itemId, item in pairs(RelicConfig.Items) do
		if item.BiomeTier == 1 then
			builders[itemId] = buildGeode
		elseif item.BiomeTier == 2 then
			builders[itemId] = buildUrn
		elseif item.BiomeTier == 3 then
			builders[itemId] = buildCore
		else
			builders[itemId] = buildHeart
		end
	end
end

-- Builds an anchored, non-colliding relic model centred on the origin. PrimaryPart "Anchor" sits at the
-- centre and carries the light and mote emitters, so the caller only has to PivotTo it.
function RelicModelBuilder.Build(tierId: string): Model
	local spec = (RelicConfig :: any)[tierId] or RelicConfig.MANA_GEODE
	local fx = RelicModelBuilder.Fx[tierId] or RelicModelBuilder.Fx.MANA_GEODE
	local model = Instance.new("Model")
	model.Name = "RelicVisual_" .. tierId

	local anchor = makePart(model, "Anchor", Vector3.one * 0.2, CFrame.identity, spec.Color)
	anchor.Transparency = 1
	model.PrimaryPart = anchor
	;(builders[tierId] or buildGeode)(model, spec.Color)

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = spec.Color
	light.Range = fx.LightRange
	light.Brightness = fx.LightBrightness
	light.Shadows = false
	light.Parent = anchor

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(spec.Color, Color3.new(1, 1, 1))
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(1.2, 2.0)
	motes.Speed = NumberRange.new(1.5, 3.5)
	motes.SpreadAngle = Vector2.new(60, 60)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Acceleration = Vector3.new(0, 1.5, 0)
	motes.Rate = fx.MoteRate
	motes.Parent = anchor

	-- One-shot spawn burst; the controller calls :Emit on it when the relic appears.
	local burst = motes:Clone()
	burst.Name = "Burst"
	burst.Rate = 0
	burst.Speed = NumberRange.new(8, 14)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	burst.Parent = anchor

	if fx.Smoke then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "CursedSmoke"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(96, 40, 120), Color3.fromRGB(40, 90, 50))
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
		smoke.Lifetime = NumberRange.new(1.5, 2.5)
		smoke.Speed = NumberRange.new(0.8, 1.6)
		smoke.SpreadAngle = Vector2.new(25, 25)
		smoke.Rate = 5
		local lidVent = Instance.new("Attachment")
		lidVent.Name = "LidVent"
		lidVent.Position = Vector3.new(0, 2.0, 0)
		lidVent.Parent = anchor
		smoke.Parent = lidVent
	end

	-- Contested particle trail for higher-tier relics (Tier 3 Idols and Tier 4 Cores)
	if (spec.BiomeTier and spec.BiomeTier >= 3) or tierId == "ABYSSAL_CORE" or tierId == "CALAMITY_HEART" then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "ContestedAura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(spec.Color, Color3.new(1, 1, 1))
		aura.LightEmission = 0.8
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		aura.Lifetime = NumberRange.new(0.8, 1.6)
		aura.Speed = NumberRange.new(1.0, 2.5)
		aura.SpreadAngle = Vector2.new(45, 45)
		aura.Rate = 8
		aura.Parent = anchor
	end

	return model
end

return RelicModelBuilder
