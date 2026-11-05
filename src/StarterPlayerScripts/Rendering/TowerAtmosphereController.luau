--!strict
-- StarterPlayerScripts/Rendering/TowerAtmosphereController.luau
-- Client-side assembly, material zone mapper, and dynamic weather/VFX controller for the
-- Central Gothic Infinite Tower (`CentralCrimsonTower` / `ReplicatedStorage.Assets.PlotFacilities.CentralTower`).
--
-- Responsibilities (Step 3 Specification):
--   1. Places `Tower_Base_Entrance` at the center of the arena, utilizing `Bridge_Snap_Point`
--      to align seamlessly with the Hub's connecting bridge (`TowerEntranceApproach` / `TowerHubArrival`).
--   2. Stacks `Tower_Mid_Segment` vertically `X` number of times (`StackCount`) to create the
--      infinite non-tapering gothic column effect.
--   3. Caps the bottom and top of the tower with `Cloud_Ring_Bottom` and `Cloud_Ring_Top`.
--   4. Applies the 4 Material Zones:
--        - Zone 1 (Masonry):         Weathered Dark Slate (#18151D)
--        - Zone 2 (Window Emissive): Intense Crimson Glow (#FF2222, Enum.Material.Neon)
--        - Zone 3 (Trims/Iron):      Wrought Iron (#111111)
--        - Zone 4 (Cloud Meshes):    Dark Storm Grey (#2A2A35)
--   5. Spawns native Roblox `ParticleEmitter` instances (thick rolling fog & storm clouds + rising
--      crimson embers) at the `VFX_Fog_Base` and `VFX_Storm_Peak` attachments to blend the solid
--      Blender cloud meshes with dynamic game weather.
--   6. Inserts crimson `PointLight` instances at the `VFX_Window_Glow` sockets and animates a
--      subtle breathing/flicker across the gothic window arches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubLayout = require(Shared:WaitForChild("Config"):WaitForChild("HubLayout"))
local HubPresence = require(script.Parent:WaitForChild("HubPresence"))

local TowerAtmosphereController = {}

--============================================================================
-- CONFIGURATION & 4 MATERIAL ZONES
--============================================================================
TowerAtmosphereController.Config = {
	ArenaCenter = Vector3.new(0, HubLayout.TowerWalkwayY, 0), -- (0, 16, 0)
	BridgeTargetSnapPoint = Vector3.new(0, HubLayout.TowerWalkwayY, -358), -- Front edge of TowerHubArrival / Bridge
	DefaultStackCount = 8, -- Number of stacked `Tower_Mid_Segment` modules
	BaseSegmentHeight = 84,
	MidSegmentHeight = 96,

	-- Material Zone Palette
	Zone1Masonry = {
		Color = Color3.fromRGB(24, 21, 29), -- #18151D Weathered Dark Slate
		Material = Enum.Material.Slate,
	},
	Zone2WindowEmissive = {
		Color = Color3.fromRGB(255, 34, 34), -- #FF2222 Intense Crimson Glow
		Material = Enum.Material.Neon,
	},
	Zone3WroughtIron = {
		Color = Color3.fromRGB(17, 17, 17), -- #111111 Wrought Iron
		Material = Enum.Material.Metal,
	},
	Zone4StormCloud = {
		Color = Color3.fromRGB(42, 42, 53), -- #2A2A35 Dark Storm Grey
		Material = Enum.Material.SmoothPlastic,
	},

	-- Particle Textures
	SmokeTexture = "rbxassetid://243660364",
	EmberTexture = "rbxassetid://241685484",
}

type WindowLightRecord = {
	Light: PointLight,
	BaseBrightness: number,
	BaseRange: number,
	Phase: number,
}

local Started = false
local WindowLights: { WindowLightRecord } = {}
local InjectedAttachments: { [Attachment]: boolean } = {}

--============================================================================
-- HELPER: MATERIAL ZONE CLASSIFICATION & APPLICATION
--============================================================================
local function applyMaterialZones(root: Instance)
	local cfg = TowerAtmosphereController.Config
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Transparency < 0.95 then
			local zone = desc:GetAttribute("MaterialZone") :: string?
			local nameLower = string.lower(desc.Name)

			if zone == "Zone2_WindowEmissive" or string.find(nameLower, "window") and (string.find(nameLower, "pane") or desc.Material == Enum.Material.Neon) then
				desc.Material = cfg.Zone2WindowEmissive.Material
				desc.Color = cfg.Zone2WindowEmissive.Color
			elseif zone == "Zone3_WroughtIron" or string.find(nameLower, "iron") or string.find(nameLower, "mullion") or string.find(nameLower, "transom") or string.find(nameLower, "portcullis") or string.find(nameLower, "finial") or string.find(nameLower, "spur") then
				desc.Material = cfg.Zone3WroughtIron.Material
				desc.Color = cfg.Zone3WroughtIron.Color
			elseif zone == "Zone4_StormCloud" or string.find(nameLower, "cloud") then
				desc.Material = cfg.Zone4StormCloud.Material
				desc.Color = cfg.Zone4StormCloud.Color
			elseif zone == "Zone1_Masonry" then
				desc.Material = cfg.Zone1Masonry.Material
			end
		end
	end
end

--============================================================================
-- HELPER: FIND SOCKET OFFSET (`Bridge_Snap_Point`, `VFX_*`)
--============================================================================
local function getSocketLocalOffset(moduleInst: Instance, socketName: string): Vector3?
	local found = moduleInst:FindFirstChild(socketName, true)
	if not found then
		return nil
	end
	local pivotCF = if moduleInst:IsA("Model") then moduleInst:GetPivot() elseif moduleInst:IsA("BasePart") then moduleInst.CFrame else CFrame.identity
	if found:IsA("Attachment") then
		return pivotCF:PointToObjectSpace(found.WorldPosition)
	elseif found:IsA("BasePart") then
		return pivotCF:PointToObjectSpace(found.Position)
	elseif found:IsA("Model") then
		return pivotCF:PointToObjectSpace(found:GetPivot().Position)
	end
	return nil
end

local function pivotInstance(inst: Instance, targetCF: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(targetCF)
	elseif inst:IsA("BasePart") then
		inst.CFrame = targetCF
	end
end

local function getModuleHeight(inst: Instance, fallbackHeight: number): number
	if inst:IsA("Model") then
		local _, size = inst:GetBoundingBox()
		if size.Y > 1 then
			return size.Y
		end
	elseif inst:IsA("BasePart") then
		if inst.Size.Y > 1 then
			return inst.Size.Y
		end
	end
	return fallbackHeight
end

--============================================================================
-- VFX INJECTION AT `VFX_Fog_Base`, `VFX_Storm_Peak`, AND `VFX_Window_Glow`
--============================================================================
local function spawnFogBaseParticles(att: Attachment)
	if InjectedAttachments[att] or att:FindFirstChild("TowerBaseRollingFog") then
		return
	end
	InjectedAttachments[att] = true
	local cfg = TowerAtmosphereController.Config

	local rollingFog = Instance.new("ParticleEmitter")
	rollingFog.Name = "TowerBaseRollingFog"
	rollingFog.Texture = cfg.SmokeTexture
	rollingFog.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(68, 64, 78)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(44, 42, 54)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(26, 24, 34)),
	})
	rollingFog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.22, 0.38),
		NumberSequenceKeypoint.new(0.75, 0.48),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	rollingFog.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 32),
		NumberSequenceKeypoint.new(0.5, 54),
		NumberSequenceKeypoint.new(1.0, 72),
	})
	rollingFog.Lifetime = NumberRange.new(7, 11)
	rollingFog.Rate = 9
	rollingFog.Speed = NumberRange.new(5, 11)
	rollingFog.SpreadAngle = Vector2.new(180, 14)
	rollingFog.Rotation = NumberRange.new(0, 360)
	rollingFog.RotSpeed = NumberRange.new(-16, 16)
	rollingFog.Parent = att
end

local function spawnStormPeakParticles(att: Attachment)
	if InjectedAttachments[att] or att:FindFirstChild("TowerPeakStormClouds") then
		return
	end
	InjectedAttachments[att] = true
	local cfg = TowerAtmosphereController.Config

	local stormSmoke = Instance.new("ParticleEmitter")
	stormSmoke.Name = "TowerPeakStormClouds"
	stormSmoke.Texture = cfg.SmokeTexture
	stormSmoke.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(30, 28, 38)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(54, 30, 38)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(18, 16, 24)),
	})
	stormSmoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.25, 0.25),
		NumberSequenceKeypoint.new(0.80, 0.35),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	stormSmoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 48),
		NumberSequenceKeypoint.new(0.5, 76),
		NumberSequenceKeypoint.new(1.0, 96),
	})
	stormSmoke.Lifetime = NumberRange.new(8, 13)
	stormSmoke.Rate = 12
	stormSmoke.Speed = NumberRange.new(8, 16)
	stormSmoke.SpreadAngle = Vector2.new(180, 18)
	stormSmoke.Rotation = NumberRange.new(0, 360)
	stormSmoke.RotSpeed = NumberRange.new(-22, 22)
	stormSmoke.Parent = att

	local stormEmbers = Instance.new("ParticleEmitter")
	stormEmbers.Name = "TowerStormEmbers"
	stormEmbers.Texture = cfg.EmberTexture
	stormEmbers.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 130, 65)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 34, 34)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(95, 14, 22)),
	})
	stormEmbers.LightEmission = 1.0
	stormEmbers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.10),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	stormEmbers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 2.2),
		NumberSequenceKeypoint.new(0.5, 3.4),
		NumberSequenceKeypoint.new(1.0, 0.6),
	})
	stormEmbers.Lifetime = NumberRange.new(4, 8)
	stormEmbers.Rate = 10
	stormEmbers.Speed = NumberRange.new(12, 24)
	stormEmbers.SpreadAngle = Vector2.new(180, 35)
	stormEmbers.Acceleration = Vector3.new(0, -4, 0)
	stormEmbers.Parent = att
end

local function spawnWindowPointLight(att: Attachment, phaseIndex: number)
	if InjectedAttachments[att] or att:FindFirstChild("GothicWindowPointLight") then
		return
	end
	InjectedAttachments[att] = true
	local cfg = TowerAtmosphereController.Config

	local light = Instance.new("PointLight")
	light.Name = "GothicWindowPointLight"
	light.Color = cfg.Zone2WindowEmissive.Color
	light.Brightness = 2.6
	light.Range = 38
	light.Shadows = false
	light.Parent = att

	table.insert(WindowLights, {
		Light = light,
		BaseBrightness = 2.6,
		BaseRange = 38,
		Phase = phaseIndex * 0.85,
	})
end

-- Scans any tower hierarchy (imported FBX or procedural `CentralCrimsonTower`) and injects
-- ParticleEmitters and PointLights into all `VFX_Fog_Base*`, `VFX_Storm_Peak*`, and `VFX_Window_Glow*` sockets.
function TowerAtmosphereController.InjectVFX(towerRoot: Instance)
	applyMaterialZones(towerRoot)

	local windowCounter = 0
	for _, desc in ipairs(towerRoot:GetDescendants()) do
		if desc:IsA("Attachment") then
			if string.find(desc.Name, "^VFX_Fog_Base") then
				spawnFogBaseParticles(desc)
			elseif string.find(desc.Name, "^VFX_Storm_Peak") then
				spawnStormPeakParticles(desc)
			elseif string.find(desc.Name, "^VFX_Window_Glow") then
				windowCounter += 1
				spawnWindowPointLight(desc, windowCounter)
			end
		elseif desc:IsA("BasePart") then
			-- If Blender exported Empty markers as tiny BaseParts/Meshes instead of Attachments, convert/attach to them
			if string.find(desc.Name, "^VFX_Fog_Base") then
				desc.Transparency = 1
				desc.CanCollide = false
				local att = desc:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", desc)
				att.Name = desc.Name
				spawnFogBaseParticles(att)
			elseif string.find(desc.Name, "^VFX_Storm_Peak") then
				desc.Transparency = 1
				desc.CanCollide = false
				local att = desc:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", desc)
				att.Name = desc.Name
				spawnStormPeakParticles(att)
			elseif string.find(desc.Name, "^VFX_Window_Glow") then
				desc.Transparency = 1
				desc.CanCollide = false
				local att = desc:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", desc)
				att.Name = desc.Name
				windowCounter += 1
				spawnWindowPointLight(att, windowCounter)
			end
		end
	end
end

--============================================================================
-- STEP 3: ASSEMBLE IMPORTED BLENDER MODULAR TOWER KIT (IF PRESENT IN ASSETS)
--============================================================================
function TowerAtmosphereController.AssembleFromImportedKit(
	kitFolder: Instance,
	targetContainer: Instance,
	stackCount: number?
): Model?
	local baseTemplate = kitFolder:FindFirstChild("Tower_Base_Entrance")
	local midTemplate = kitFolder:FindFirstChild("Tower_Mid_Segment")
	local cloudBotTemplate = kitFolder:FindFirstChild("Cloud_Ring_Bottom")
	local cloudTopTemplate = kitFolder:FindFirstChild("Cloud_Ring_Top")

	if not (baseTemplate and midTemplate) then
		return nil
	end

	local cfg = TowerAtmosphereController.Config
	local numMid = stackCount or cfg.DefaultStackCount

	local assembled = Instance.new("Model")
	assembled.Name = "CentralGothicTower_Assembled"

	-- 1. Place `Tower_Base_Entrance` at the center of the arena, aligning `Bridge_Snap_Point`
	--    with the Hub's connecting bridge (`BridgeTargetSnapPoint`)
	local baseClone = baseTemplate:Clone()
	local snapLocalOffset = getSocketLocalOffset(baseClone, "Bridge_Snap_Point")
	local baseOriginCF = CFrame.new(cfg.ArenaCenter)
	if snapLocalOffset then
		-- Align horizontally along Z so `Bridge_Snap_Point` lands on `BridgeTargetSnapPoint`
		local desiredOriginPos = Vector3.new(
			cfg.ArenaCenter.X,
			cfg.ArenaCenter.Y - snapLocalOffset.Y,
			cfg.BridgeTargetSnapPoint.Z - snapLocalOffset.Z
		)
		baseOriginCF = CFrame.new(desiredOriginPos)
	end
	pivotInstance(baseClone, baseOriginCF)
	baseClone.Parent = assembled

	local baseHeight = getModuleHeight(baseClone, cfg.BaseSegmentHeight)

	-- 2. Stack `Tower_Mid_Segment` vertically `numMid` times along the Y-axis
	local midHeight = getModuleHeight(midTemplate, cfg.MidSegmentHeight)
	for i = 1, numMid do
		local segClone = midTemplate:Clone()
		segClone.Name = string.format("Tower_Mid_Segment_%02d", i)
		local segY = baseOriginCF.Position.Y + baseHeight + (i - 1) * midHeight
		pivotInstance(segClone, CFrame.new(baseOriginCF.Position.X, segY, baseOriginCF.Position.Z))
		segClone.Parent = assembled
	end

	local topOfStackY = baseOriginCF.Position.Y + baseHeight + numMid * midHeight

	-- 3. Cap the bottom (just above archway) and top (peak of stack) with the Blender cloud meshes
	if cloudBotTemplate then
		local botCloud = cloudBotTemplate:Clone()
		pivotInstance(botCloud, CFrame.new(baseOriginCF.Position.X, baseOriginCF.Position.Y + baseHeight * 0.72, baseOriginCF.Position.Z))
		botCloud.Parent = assembled
	end

	if cloudTopTemplate then
		local topCloud = cloudTopTemplate:Clone()
		pivotInstance(topCloud, CFrame.new(baseOriginCF.Position.X, topOfStackY - midHeight * 0.2, baseOriginCF.Position.Z))
		topCloud.Parent = assembled
	end

	assembled.Parent = targetContainer

	-- 4 & 5. Spawn native Roblox ParticleEmitters & crimson PointLights at the Blender Empty sockets
	TowerAtmosphereController.InjectVFX(assembled)

	return assembled
end

--============================================================================
-- RUNTIME BOOTSTRAP & WINDOW GLOW PULSE LOOP
--============================================================================
function TowerAtmosphereController.Start()
	if Started then
		return
	end
	Started = true

	local function bindExistingTower()
		local overhaul = Workspace:FindFirstChild("BaseOverhaulGeometry")
		local existingTower = overhaul and overhaul:FindFirstChild("CentralCrimsonTower")

		-- Check if the user imported the FBX kit into ReplicatedStorage.Assets.PlotFacilities.CentralTower
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local plotFacilities = assets and assets:FindFirstChild("PlotFacilities")
		local centralTowerKit = plotFacilities and plotFacilities:FindFirstChild("CentralTower")

		if centralTowerKit and overhaul and not overhaul:FindFirstChild("CentralGothicTower_Assembled") then
			TowerAtmosphereController.AssembleFromImportedKit(
				centralTowerKit,
				existingTower or overhaul,
				TowerAtmosphereController.Config.DefaultStackCount
			)
		end

		if existingTower then
			TowerAtmosphereController.InjectVFX(existingTower)
		end
	end

	bindExistingTower()

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "BaseOverhaulGeometry" then
			task.defer(bindExistingTower)
			child.ChildAdded:Connect(function(sub)
				if sub.Name == "CentralCrimsonTower" then
					task.defer(function()
						TowerAtmosphereController.InjectVFX(sub)
					end)
				end
			end)
		end
	end)

	local overhaul = Workspace:FindFirstChild("BaseOverhaulGeometry")
	if overhaul then
		overhaul.ChildAdded:Connect(function(sub)
			if sub.Name == "CentralCrimsonTower" then
				task.defer(function()
					TowerAtmosphereController.InjectVFX(sub)
				end)
			end
		end)
	end

	-- Subtle 60 FPS atmospheric crimson window glow pulse (paused when player is inside a tower floor)
	RunService.RenderStepped:Connect(function()
		if HubPresence.InTower() or #WindowLights == 0 then
			return
		end
		debug.profilebegin("TowerAtmosphereWindowGlow")
		local now = os.clock()
		for i = #WindowLights, 1, -1 do
			local rec = WindowLights[i]
			if not rec.Light.Parent then
				table.remove(WindowLights, i)
			else
				local wave = math.sin(now * 1.85 + rec.Phase) * 0.35 + math.sin(now * 4.3 + rec.Phase * 1.7) * 0.12
				rec.Light.Brightness = rec.BaseBrightness + wave
			end
		end
		debug.profileend("TowerAtmosphereWindowGlow")
	end)
end

_G.TowerAtmosphereController = TowerAtmosphereController

return TowerAtmosphereController
