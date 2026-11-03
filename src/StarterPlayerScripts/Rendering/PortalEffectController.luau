--!strict
-- StarterPlayerScripts/Rendering/PortalEffectController.luau
-- Client-side state machine, TweenService door hinge animator, and VFX controller
-- for the Wall-Mounted Gothic Corner Summoning Portal (`Building_Summoning` / `SummoningPortal`).
--
-- Supports both:
--   1. Instant state toggling (`SetState(portal, "Closed" | "Active", true)`)
--   2. Smooth TweenService door-opening transitions (`75°–85°` inward swing into the
--      deep Gothic archway vault) when a player approaches, interacts with `[F] Summon Heroes`,
--      or triggers a banner pull in `FacilityController.luau`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))

export type PortalState = "Closed" | "Active"

type DoorLeafRecord = {
	Instance: Instance,
	ClosedCF: CFrame,
	OpenCF: CFrame,
	HingeCF: CFrame?,
	RelToHinge: CFrame?,
	OpenAngleRad: number,
	AlphaValue: NumberValue,
	ActiveTween: Tween?,
}

type ManagedPortal = {
	Model: Model,
	State: PortalState,
	LeftDoor: DoorLeafRecord?,
	RightDoor: DoorLeafRecord?,
	DoorsGroup: Instance?,
	VortexGroup: Instance?,
	VortexSpinParts: { { Part: BasePart, BaseCF: CFrame, Speed: number } },
	LightningParts: { BasePart },
	GodRayBeams: { Beam },
	SkyBeams: { Beam },
	VolumetricShaft: BasePart?,
	PointLight: PointLight?,
	VortexEmitter: ParticleEmitter?,
	SummonHoldUntil: number,
}

local PortalEffectController = {}

local ManagedPortals: { [Model]: ManagedPortal } = {}
local Started = false

local OPEN_TWEEN_INFO = TweenInfo.new(1.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local LIGHT_TWEEN_INFO = TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local COLOR_CYAN_VORTEX = Color3.fromRGB(0, 229, 255)   -- #00E5FF Zone 4
local COLOR_RUNE_GLOW   = Color3.fromRGB(34, 211, 238)  -- #22D3EE Zone 3
local COLOR_EXALTED_GOLD = Color3.fromRGB(255, 215, 90)

local function setInstancePivot(inst: Instance, cf: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

local function getInstancePivot(inst: Instance): CFrame
	if inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("BasePart") then
		return inst.CFrame
	end
	return CFrame.identity
end

local function setHierarchyTransparency(root: Instance?, transparency: number, skipNames: { [string]: boolean }?)
	if not root then
		return
	end
	if root:IsA("BasePart") then
		if not (skipNames and skipNames[root.Name]) then
			root.LocalTransparencyModifier = transparency
		end
	end
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name ~= "HingePivot" and desc.Name ~= "PrimaryRoot" then
			if not (skipNames and skipNames[desc.Name]) then
				desc.LocalTransparencyModifier = transparency
			end
		end
	end
end

local function buildDoorRecord(doorInst: Instance?, isLeft: boolean, openAngleDeg: number): DoorLeafRecord?
	if not doorInst then
		return nil
	end

	local closedCF = (doorInst:GetAttribute("ClosedCFrame") :: CFrame?) or getInstancePivot(doorInst)
	local openCF = doorInst:GetAttribute("OpenCFrame") :: CFrame?
	local hingeCF = doorInst:GetAttribute("HingeCFrame") :: CFrame?
	local openAngleRad = (doorInst:GetAttribute("OpenAngleRad") :: number?)
		or math.rad(if isLeft then -openAngleDeg else openAngleDeg)
	local relToHinge = if hingeCF then hingeCF:ToObjectSpace(closedCF) else nil

	if not openCF then
		if hingeCF and relToHinge then
			openCF = (hingeCF * CFrame.Angles(0, openAngleRad, 0)) * relToHinge
		else
			openCF = closedCF * CFrame.Angles(0, openAngleRad, 0)
		end
	end

	local alphaVal = Instance.new("NumberValue")
	alphaVal.Name = "DoorSwingAlpha"
	alphaVal.Value = 0
	alphaVal.Parent = doorInst

	local record: DoorLeafRecord = {
		Instance = doorInst,
		ClosedCF = closedCF,
		OpenCF = openCF :: CFrame,
		HingeCF = hingeCF,
		RelToHinge = relToHinge,
		OpenAngleRad = openAngleRad,
		AlphaValue = alphaVal,
		ActiveTween = nil,
	}

	alphaVal.Changed:Connect(function(alpha: number)
		if record.HingeCF and record.RelToHinge then
			setInstancePivot(
				doorInst,
				(record.HingeCF * CFrame.Angles(0, record.OpenAngleRad * alpha, 0)) * record.RelToHinge
			)
		else
			setInstancePivot(doorInst, record.ClosedCF:Lerp(record.OpenCF, alpha))
		end
	end)

	return record
end

function PortalEffectController.BindPortal(portalModel: Model): ManagedPortal?
	if ManagedPortals[portalModel] then
		return ManagedPortals[portalModel]
	end

	local summonCfg = FacilityConfig.FacilityLayout.SummoningPortal
	local openAngleDeg = (summonCfg and summonCfg.DoorOpenAngleDeg) or 80

	local doorsGroup = portalModel:FindFirstChild("Portal_Doors_ClosedMesh", true)
	local leftDoorInst = portalModel:FindFirstChild("Portal_Door_Left", true)
	local rightDoorInst = portalModel:FindFirstChild("Portal_Door_Right", true)
	local vortexGroup = portalModel:FindFirstChild("Portal_Active_VortexMesh", true)

	local spinParts: { { Part: BasePart, BaseCF: CFrame, Speed: number } } = {}
	local lightningParts: { BasePart } = {}

	if vortexGroup then
		for _, desc in ipairs(vortexGroup:GetDescendants()) do
			if desc:IsA("BasePart") then
				if desc.Name == "PortalVortexDisc" then
					table.insert(spinParts, { Part = desc, BaseCF = desc.CFrame, Speed = 0.85 })
				elseif desc.Name == "PortalInnerCore" then
					table.insert(spinParts, { Part = desc, BaseCF = desc.CFrame, Speed = -1.45 })
				elseif string.find(desc.Name, "LightningArc") then
					table.insert(lightningParts, desc)
				end
			end
		end
	end
	for _, desc in ipairs(portalModel:GetDescendants()) do
		if desc:IsA("BasePart") and string.find(desc.Name, "LightningArc") and not table.find(lightningParts, desc) then
			table.insert(lightningParts, desc)
		end
	end

	local godRayBeams: { Beam } = {}
	local skyBeams: { Beam } = {}
	local pointLight: PointLight? = nil
	local vortexEmitter: ParticleEmitter? = nil

	for _, desc in ipairs(portalModel:GetDescendants()) do
		if desc:IsA("Beam") then
			if string.find(desc.Name, "GodRayBeam") then
				table.insert(godRayBeams, desc)
			elseif string.find(desc.Name, "SkyColumn") or string.find(desc.Name, "VolumetricLightColumn") then
				table.insert(skyBeams, desc)
			end
		elseif desc:IsA("PointLight") and (desc.Name == "PortalPointLight" or not pointLight) then
			pointLight = desc
		elseif desc:IsA("ParticleEmitter") and desc.Name == "PortalVortexParticles" then
			vortexEmitter = desc
		end
	end

	local volumetricShaft = portalModel:FindFirstChild("VolumetricLightShaft", true) :: BasePart?

	local managed: ManagedPortal = {
		Model = portalModel,
		State = "Closed",
		LeftDoor = buildDoorRecord(leftDoorInst, true, openAngleDeg),
		RightDoor = buildDoorRecord(rightDoorInst, false, openAngleDeg),
		DoorsGroup = doorsGroup,
		VortexGroup = vortexGroup,
		VortexSpinParts = spinParts,
		LightningParts = lightningParts,
		GodRayBeams = godRayBeams,
		SkyBeams = skyBeams,
		VolumetricShaft = volumetricShaft,
		PointLight = pointLight,
		VortexEmitter = vortexEmitter,
		SummonHoldUntil = 0,
	}

	ManagedPortals[portalModel] = managed
	portalModel.Destroying:Connect(function()
		ManagedPortals[portalModel] = nil
	end)

	-- Initialize in Closed idle state (doors shut with glowing vertical seam, sky beacon visible)
	PortalEffectController.SetState(portalModel, "Closed", true)
	return managed
end

local function animateDoorLeaf(record: DoorLeafRecord?, targetAlpha: number, instant: boolean?)
	if not record then
		return
	end
	if record.ActiveTween then
		record.ActiveTween:Cancel()
		record.ActiveTween = nil
	end
	if instant then
		record.AlphaValue.Value = targetAlpha
		if record.HingeCF and record.RelToHinge then
			setInstancePivot(
				record.Instance,
				(record.HingeCF * CFrame.Angles(0, record.OpenAngleRad * targetAlpha, 0)) * record.RelToHinge
			)
		else
			setInstancePivot(record.Instance, record.ClosedCF:Lerp(record.OpenCF, targetAlpha))
		end
	else
		local info = if targetAlpha > 0.5 then OPEN_TWEEN_INFO else CLOSE_TWEEN_INFO
		local tween = TweenService:Create(record.AlphaValue, info, { Value = targetAlpha })
		record.ActiveTween = tween
		tween:Play()
	end
end

function PortalEffectController.SetState(portalModel: Model, newState: PortalState, instant: boolean?)
	local managed = ManagedPortals[portalModel] or PortalEffectController.BindPortal(portalModel)
	if not managed then
		return
	end
	if managed.State == newState and not instant then
		return
	end

	managed.State = newState
	portalModel:SetAttribute("PortalState", newState)
	local isActive = (newState == "Active")
	local targetAlpha = if isActive then 1.0 else 0.0

	-- 1. Swing Hinged Doors (or toggle combined closed doors mesh if unsplit)
	if managed.LeftDoor or managed.RightDoor then
		animateDoorLeaf(managed.LeftDoor, targetAlpha, instant)
		animateDoorLeaf(managed.RightDoor, targetAlpha, instant)
		if managed.DoorsGroup then
			local centerSeam = managed.DoorsGroup:FindFirstChild("CenterSeamNeon", true)
			if centerSeam and centerSeam:IsA("BasePart") then
				centerSeam.LocalTransparencyModifier = if isActive then 1 else 0
			end
		end
	elseif managed.DoorsGroup then
		setHierarchyTransparency(managed.DoorsGroup, if isActive then 1 else 0)
	end

	-- 2. Reveal / Dim Recessed Vortex Plane (keep BackingWallShield opaque at all times)
	if managed.VortexGroup then
		setHierarchyTransparency(managed.VortexGroup, if isActive then 0 else 0.65, { BackingWallShield = true })
	end

	-- 3. Particle Emitter & PointLight Intensity
	if managed.VortexEmitter then
		managed.VortexEmitter.Rate = if isActive then 38 else 8
	end
	if managed.PointLight then
		local goalBrightness = if isActive then 4.2 else 1.8
		local goalRange = if isActive then 44 else 26
		local goalColor = if isActive then COLOR_CYAN_VORTEX else COLOR_RUNE_GLOW
		if instant then
			managed.PointLight.Brightness = goalBrightness
			managed.PointLight.Range = goalRange
			managed.PointLight.Color = goalColor
		else
			TweenService:Create(managed.PointLight, LIGHT_TWEEN_INFO, {
				Brightness = goalBrightness,
				Range = goalRange,
				Color = goalColor,
			}):Play()
		end
	end

	-- 4. Outward Volumetric Light Rays (spill across steps when doors open)
	for _, beam in ipairs(managed.GodRayBeams) do
		beam.Enabled = isActive
	end

	-- 5. Vertical Sky-Beam Column intensification
	for _, skyBeam in ipairs(managed.SkyBeams) do
		skyBeam.Width0 = if isActive then 15.0 else 12.0
		skyBeam.Width1 = if isActive then 20.0 else 16.0
	end
	if managed.VolumetricShaft then
		managed.VolumetricShaft.Transparency = if isActive then 0.78 else 0.88
	end
end

function PortalEffectController.TriggerSummonBurst(portalModel: Model?, rarityTier: number?)
	local targetModel = portalModel
	if not targetModel then
		for model in pairs(ManagedPortals) do
			targetModel = model
			break
		end
	end
	if not targetModel then
		return
	end

	local managed = ManagedPortals[targetModel] or PortalEffectController.BindPortal(targetModel)
	if not managed then
		return
	end

	managed.SummonHoldUntil = os.clock() + 6.0
	PortalEffectController.SetState(targetModel, "Active", false)

	if managed.VortexEmitter then
		managed.VortexEmitter:Emit(35)
	end
	if managed.PointLight then
		local isHighTier = (rarityTier or 1) >= 5
		managed.PointLight.Color = if isHighTier then COLOR_EXALTED_GOLD else COLOR_CYAN_VORTEX
		managed.PointLight.Brightness = 7.5
		managed.PointLight.Range = 56
		TweenService:Create(managed.PointLight, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = 4.2,
			Range = 44,
			Color = COLOR_CYAN_VORTEX,
		}):Play()
	end
end

function PortalEffectController.Start()
	if Started then
		return
	end
	Started = true

	local localPlayer = Players.LocalPlayer
	local summonCfg = FacilityConfig.FacilityLayout.SummoningPortal
	local openRadius = (summonCfg and summonCfg.ProximityOpenRadius) or 24

	local function scanWorkspaceForPortals(root: Instance)
		for _, desc in ipairs(root:GetDescendants()) do
			if desc:IsA("Model") and (desc.Name == "Building_Summoning" or desc.Name == "SummoningPortal") then
				PortalEffectController.BindPortal(desc)
			end
		end
	end

	local plotsFolder = Workspace:FindFirstChild("WaitingRoomPlots")
	if plotsFolder then
		scanWorkspaceForPortals(plotsFolder)
		plotsFolder.DescendantAdded:Connect(function(desc)
			if desc:IsA("Model") and (desc.Name == "Building_Summoning" or desc.Name == "SummoningPortal") then
				task.defer(function()
					if desc.Parent then
						PortalEffectController.BindPortal(desc)
					end
				end)
			end
		end)
	end

	-- 60 FPS Vortex Swirl, Lightning Flicker & Proximity Door Trigger Loop
	RunService.RenderStepped:Connect(function(_dt: number)
		local now = os.clock()
		local char = localPlayer and localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local playerPos = hrp and hrp.Position

		for model, managed in pairs(ManagedPortals) do
			if not model.Parent then
				ManagedPortals[model] = nil
				continue
			end

			-- Check proximity to automatically swing open the Gothic doors when the Master approaches
			local rootPart = model.PrimaryPart
			if rootPart and playerPos then
				local dist = (playerPos - rootPart.Position).Magnitude
				local shouldBeActive = (dist <= openRadius) or (now < managed.SummonHoldUntil)
				local desiredState: PortalState = if shouldBeActive then "Active" else "Closed"
				if managed.State ~= desiredState then
					PortalEffectController.SetState(model, desiredState, false)
				end
			end

			-- Animate swirling vortex layers & crackling lightning arcs when active or opening
			if managed.State == "Active" or (managed.LeftDoor and managed.LeftDoor.AlphaValue.Value > 0.05) then
				for _, spin in ipairs(managed.VortexSpinParts) do
					if spin.Part.Parent then
						spin.Part.CFrame = spin.BaseCF * CFrame.Angles(now * spin.Speed, 0, 0)
					end
				end

				for idx, bolt in ipairs(managed.LightningParts) do
					if bolt.Parent then
						local pulse = math.sin(now * 18.0 + idx * 1.7)
						bolt.Transparency = if pulse > -0.2 then 0.05 else 0.75
					end
				end
			end
		end
	end)
end

_G.PortalEffectController = PortalEffectController

return PortalEffectController
