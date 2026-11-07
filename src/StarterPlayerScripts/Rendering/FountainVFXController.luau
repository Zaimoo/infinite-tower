--!strict
-- StarterPlayerScripts/Rendering/FountainVFXController.luau
-- Client-side flowing water VFX, UV ripple texture scroller, Beam waterfall binder,
-- impact mist emitter manager, and balanced ambient lighting controller for the
-- Central Gothic Goddess Fountain (`PlazaFountain`).
--
-- Phase 3 Specifications (fountain_overhaul_plan.md):
--   1. Basin Water (UV Scrolling):
--      - Deep cyan/blue `#0EA5E9` (`Color3.fromRGB(14, 165, 233)`), non-Neon (`Glass`)
--      - Smoothly scrolls `OffsetStudsU` and `OffsetStudsV` on `RenderStepped` across
--        dual ripple `Texture` layers (`WaterRippleTextureA`, `WaterRippleTextureB`).
--   2. Waterfalls & Spouts (`Beam` VFX):
--      - Connects `Waterfall_Spout_1..N` to `Waterfall_Impact_1..N`
--      - `TextureSpeed = 2.5`, `LightEmission = 0.4`, fading bottom `Transparency`
--   3. Splash & Mist Particles (`ParticleEmitter`):
--      - Soft low-opacity white/cyan mist at waterfall impact attachments (`LightEmission = 0.35`)
--   4. Ambient Fountain Lighting (`PointLight`):
--      - Single central `PointLight` in the bottom basin (`#38BDF8`, Brightness 1.75, Range 24).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

export type ManagedWaterTexture = {
	Texture: Texture,
	SpeedU: number,
	SpeedV: number,
	TileU: number,
	TileV: number,
}

export type ManagedFountain = {
	Model: Model,
	WaterTextures: { ManagedWaterTexture },
	WaterfallBeams: { Beam },
	ImpactEmitters: { ParticleEmitter },
	PointLight: PointLight?,
	BaseBrightness: number,
}

local FountainVFXController = {}

FountainVFXController.Config = table.freeze({
	WaterColor = Color3.fromRGB(14, 165, 233), -- #0EA5E9 Deep Cyan
	WaterSurfaceBaseColor = Color3.fromRGB(8, 108, 185), -- Deep Cerulean Pool Depth
	WaterFoamColor = Color3.fromRGB(186, 230, 253), -- Soft Sky Foam
	LightColor = Color3.fromRGB(56, 189, 248), -- #38BDF8 Light Blue
	LightBrightness = 1.75, -- Balanced 1.5 - 2.0 range
	LightRange = 24,
	BeamTextureSpeed = 2.5,
	BeamLightEmission = 0.4, -- Magical glow without blowing out bloom
	MistLightEmission = 0.35,
	RippleTextureId = "rbxassetid://118260672943381", -- Custom seamless cellular water caustics + sparkles
	WaterfallSpriteId = "rbxassetid://74951117913804", -- Custom vertical silky water strands
	SplashFoamRingId = "rbxassetid://105409048761236", -- Custom frothy splash boil + concentric ripple rings
	WaterSparkleId = "rbxassetid://129486097319512", -- Custom 4-point glowing water droplet/sparkle mote
	ScrollLayerASpeed = Vector2.new(0.85, 0.55),
	ScrollLayerBSpeed = Vector2.new(-0.62, 0.78),
})

local ManagedFountains: { [Model]: ManagedFountain } = {}
local Started = false

local WATER_PART_NAMES: { [string]: boolean } = {
	Water_Surface_Meshes = true,
	Tier1_WaterPool = true,
	Tier2_WaterPool = true,
	Tier3_WaterPool = true,
	Tier3_WaterCrest = true,
	CatchBasin_Water_1 = true,
	CatchBasin_Water_2 = true,
	CatchBasin_Water_3 = true,
	CatchBasin_Water_4 = true,
}

local function resolveTopFace(part: BasePart): Enum.NormalId
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		return Enum.NormalId.Right
	end
	return Enum.NormalId.Top
end

local function ensureWaterSurfaceTextures(waterPart: BasePart): (Texture, Texture)
	local cfg = FountainVFXController.Config
	-- Avoid standard Neon on basin water pools so bloom is never blown out
	if waterPart.Material == Enum.Material.Neon then
		waterPart.Material = Enum.Material.Glass
		waterPart.Transparency = 0.15
	end
	if waterPart:GetAttribute("OriginalColor") == nil then
		waterPart.Color = cfg.WaterSurfaceBaseColor or cfg.WaterColor
	end

	local topFace = resolveTopFace(waterPart)

	local texA = waterPart:FindFirstChild("WaterRippleTextureA") :: Texture?
	if not texA then
		local created = Instance.new("Texture")
		created.Name = "WaterRippleTextureA"
		created.Face = topFace
		created.Texture = cfg.RippleTextureId
		created.Color3 = Color3.fromRGB(220, 248, 255)
		created.Transparency = 0.45
		created.StudsPerTileU = 6.5
		created.StudsPerTileV = 6.5
		created.Parent = waterPart
		texA = created
	end

	local texB = waterPart:FindFirstChild("WaterRippleTextureB") :: Texture?
	if not texB then
		local created = Instance.new("Texture")
		created.Name = "WaterRippleTextureB"
		created.Face = topFace
		created.Texture = cfg.RippleTextureId
		created.Color3 = Color3.fromRGB(165, 243, 252)
		created.Transparency = 0.58
		created.StudsPerTileU = 4.2
		created.StudsPerTileV = 4.2
		created.Parent = waterPart
		texB = created
	end

	return texA :: Texture, texB :: Texture
end

local function ensureBeamBetweenAttachments(
	holder: Instance,
	index: number,
	aSpout: Attachment,
	aImpact: Attachment
): (Beam, ParticleEmitter?)
	local cfg = FountainVFXController.Config
	local beamName = string.format("WaterfallSheet_%d", index)
	local existingBeam = holder:FindFirstChild(beamName) :: Beam?

	local beam: Beam
	if existingBeam and existingBeam:IsA("Beam") then
		beam = existingBeam
	else
		beam = Instance.new("Beam")
		beam.Name = beamName
		beam.Attachment0 = aSpout
		beam.Attachment1 = aImpact
		beam.Texture = cfg.WaterfallSpriteId
		beam.TextureLength = 2.4
		beam.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(224, 242, 254)),
			ColorSequenceKeypoint.new(0.5, cfg.WaterFoamColor),
			ColorSequenceKeypoint.new(1.0, cfg.WaterColor),
		})
		beam.Width0 = 1.15
		beam.Width1 = 1.65
		beam.FaceCamera = true
		beam.Segments = 14
		beam.CurveSize0 = 0.55
		beam.CurveSize1 = -0.35
		beam.Parent = holder
	end

	-- Enforce Phase 3.2 Beam specifications
	beam.TextureSpeed = cfg.BeamTextureSpeed
	beam.LightEmission = cfg.BeamLightEmission
	beam.LightInfluence = 0.35
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.12),
		NumberSequenceKeypoint.new(0.65, 0.08),
		NumberSequenceKeypoint.new(0.9, 0.35),
		NumberSequenceKeypoint.new(1.0, 0.95),
	})

	local emitter = aImpact:FindFirstChildWhichIsA("ParticleEmitter")
	if emitter then
		emitter.LightEmission = cfg.MistLightEmission
	end

	return beam, emitter
end

function FountainVFXController.BindFountain(fountainModel: Model): ManagedFountain?
	if ManagedFountains[fountainModel] then
		return ManagedFountains[fountainModel]
	end

	local cfg = FountainVFXController.Config
	local waterTextures: { ManagedWaterTexture } = {}
	local waterfallBeams: { Beam } = {}
	local impactEmitters: { ParticleEmitter } = {}
	local spoutsByIndex: { [number]: Attachment } = {}
	local impactsByIndex: { [number]: Attachment } = {}
	local pointLight: PointLight? = nil

	for _, desc in ipairs(fountainModel:GetDescendants()) do
		if desc:IsA("BasePart") and not desc:IsA("MeshPart") then
			if (WATER_PART_NAMES[desc.Name] or desc:GetAttribute("FountainWaterSurface") == true) and desc.Transparency < 0.95 then
				local texA, texB = ensureWaterSurfaceTextures(desc)
				table.insert(waterTextures, {
					Texture = texA,
					SpeedU = cfg.ScrollLayerASpeed.X,
					SpeedV = cfg.ScrollLayerASpeed.Y,
					TileU = math.max(1, texA.StudsPerTileU),
					TileV = math.max(1, texA.StudsPerTileV),
				})
				table.insert(waterTextures, {
					Texture = texB,
					SpeedU = cfg.ScrollLayerBSpeed.X,
					SpeedV = cfg.ScrollLayerBSpeed.Y,
					TileU = math.max(1, texB.StudsPerTileU),
					TileV = math.max(1, texB.StudsPerTileV),
				})
			end
		elseif desc:IsA("Attachment") then
			local spoutNum = string.match(desc.Name, "^Waterfall_Spout_(%d+)$")
			if spoutNum then
				spoutsByIndex[tonumber(spoutNum) :: number] = desc
			else
				local impactNum = string.match(desc.Name, "^Waterfall_Impact_(%d+)$")
				if impactNum then
					impactsByIndex[tonumber(impactNum) :: number] = desc
				end
			end
		elseif desc:IsA("PointLight") and desc.Name == "FountainGlow" then
			pointLight = desc
		elseif desc:IsA("ParticleEmitter") then
			desc.LightEmission = math.min(desc.LightEmission, cfg.MistLightEmission)
			table.insert(impactEmitters, desc)
		end
	end

	-- Wire or validate all Waterfall_Spout_N -> Waterfall_Impact_N Beam pairs
	local socketHolder = (fountainModel:FindFirstChild("WaterfallSocketHolder") :: Instance?) or fountainModel
	for idx, aSpout in pairs(spoutsByIndex) do
		local aImpact = impactsByIndex[idx]
		if aImpact then
			local beam, emitter = ensureBeamBetweenAttachments(socketHolder, idx, aSpout, aImpact)
			table.insert(waterfallBeams, beam)
			if emitter and not table.find(impactEmitters, emitter) then
				table.insert(impactEmitters, emitter)
			end
		end
	end

	-- Collect any additional WaterfallBody_* and BasinFlowStream_* beams while preserving parallax speeds
	for _, desc in ipairs(fountainModel:GetDescendants()) do
		if desc:IsA("Beam") and not table.find(waterfallBeams, desc) then
			if string.find(desc.Name, "^WaterfallSheet_") then
				desc.TextureSpeed = cfg.BeamTextureSpeed
			end
			desc.LightEmission = math.min(desc.LightEmission, cfg.BeamLightEmission)
			table.insert(waterfallBeams, desc)
		end
	end

	-- Enforce Phase 3.4 Ambient Fountain Lighting on the bottom basin PointLight
	if not pointLight then
		local tier1Pool = fountainModel:FindFirstChild("Tier1_WaterPool", true) :: BasePart?
		if tier1Pool then
			local created = Instance.new("PointLight")
			created.Name = "FountainGlow"
			created.Parent = tier1Pool
			pointLight = created
		end
	end
	if pointLight then
		pointLight.Color = cfg.LightColor
		pointLight.Brightness = math.clamp(pointLight.Brightness, 1.5, 2.0)
		pointLight.Range = cfg.LightRange
		pointLight.Shadows = false
	end

	local managed: ManagedFountain = {
		Model = fountainModel,
		WaterTextures = waterTextures,
		WaterfallBeams = waterfallBeams,
		ImpactEmitters = impactEmitters,
		PointLight = pointLight,
		BaseBrightness = if pointLight then pointLight.Brightness else cfg.LightBrightness,
	}

	ManagedFountains[fountainModel] = managed
	fountainModel.Destroying:Connect(function()
		ManagedFountains[fountainModel] = nil
	end)

	return managed
end

function FountainVFXController.Step(dt: number, elapsed: number)
	for model, managed in pairs(ManagedFountains) do
		if not model.Parent then
			ManagedFountains[model] = nil
			continue
		end

		-- 1. UV Texture Scrolling across all basin water surfaces
		for _, wt in ipairs(managed.WaterTextures) do
			local tex = wt.Texture
			if tex.Parent then
				tex.OffsetStudsU = (tex.OffsetStudsU + wt.SpeedU * dt) % wt.TileU
				tex.OffsetStudsV = (tex.OffsetStudsV + wt.SpeedV * dt) % wt.TileV
			end
		end

		-- 2. Subtle organic water shimmer on the central PointLight (strictly within 1.5 - 2.0)
		local light = managed.PointLight
		if light and light.Parent then
			local shimmer = math.sin(elapsed * 2.2) * 0.12
			light.Brightness = math.clamp(managed.BaseBrightness + shimmer, 1.5, 2.0)
		end
	end
end

function FountainVFXController.Start()
	if Started then
		return
	end
	Started = true

	local function scanForFountains(root: Instance)
		for _, desc in ipairs(root:GetDescendants()) do
			if desc:IsA("Model") and desc.Name == "PlazaFountain" then
				FountainVFXController.BindFountain(desc)
			end
		end
	end

	local plotsFolder = Workspace:FindFirstChild("WaitingRoomPlots")
	if plotsFolder then
		scanForFountains(plotsFolder)
		plotsFolder.DescendantAdded:Connect(function(desc)
			if desc:IsA("Model") and desc.Name == "PlazaFountain" then
				task.defer(function()
					if desc.Parent then
						FountainVFXController.BindFountain(desc)
					end
				end)
			end
		end)
	end

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "WaitingRoomPlots" then
			scanForFountains(child)
			child.DescendantAdded:Connect(function(desc)
				if desc:IsA("Model") and desc.Name == "PlazaFountain" then
					task.defer(function()
						if desc.Parent then
							FountainVFXController.BindFountain(desc)
						end
					end)
				end
			end)
		end
	end)

	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		FountainVFXController.Step(dt, elapsed)
	end)
end

_G.FountainVFXController = FountainVFXController

return FountainVFXController
