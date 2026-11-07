--!strict
-- StarterPlayerScripts/Rendering/SynthesisDoorController.luau
-- Client-side outward-opening double-door animator and interior sanctum VFX controller
-- for the enterable Synthesis Chamber ("The Pit" — `Building_ThePit` / `SynthesisChamber`).
--
-- Behavior:
--   * Throttled 10 Hz proximity check against `DoorTriggerCenter` (<= 26 studs) and
--     interior sanctum center (<= 18 studs), with a 32-stud close hysteresis buffer.
--   * Swings `Chamber_Door_Left` by -95 deg outward and `Chamber_Door_Right` by +95 deg
--     outward around their outer doorjamb hinges via `TweenService`
--     (`TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)`).
--   * Scales the interior Synthesis Anvil's `SynthesisCoreLight` (`PointLight`) and
--     `SynthesisCoreFlame` (`ParticleEmitter`) when the doors open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))

local SynthesisDoorController = {}

local pitCfg = FacilityConfig.FacilityLayout and FacilityConfig.FacilityLayout.SynthesisChamber
local OPEN_DISTANCE: number = (pitCfg and pitCfg.ProximityOpenRadius) or 26
local CLOSE_DISTANCE: number = (pitCfg and pitCfg.ProximityCloseRadius) or 32
local INTERIOR_RADIUS: number = (pitCfg and pitCfg.InteriorHoldRadius) or 18
local OUTWARD_ANGLE_DEG: number = (pitCfg and pitCfg.DoorOpenAngleDeg) or 95

local DOOR_TWEEN_INFO = TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local LIGHT_TWEEN_INFO = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

type DoorLeaf = {
	Target: Instance,
	ClosedPivot: CFrame,
	OpenAngleRad: number,
	AlphaValue: NumberValue,
	ActiveTween: Tween?,
}

export type ChamberState = {
	Model: Model,
	LeftDoor: DoorLeaf,
	RightDoor: DoorLeaf,
	TriggerSource: Instance,
	CenterSource: BasePart?,
	CoreBall: BasePart?,
	CoreBaseCF: CFrame?,
	CoreLight: PointLight?,
	AmbientLight: PointLight?,
	CoreEmitter: ParticleEmitter?,
	IsOpen: boolean,
}

local registeredChambers: { [Model]: ChamberState } = {}
local started = false

local function getPivot(inst: Instance): CFrame
	if inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("BasePart") then
		return inst.CFrame
	end
	return CFrame.identity
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

local function getWorldPosition(inst: Instance?): Vector3?
	if not inst then
		return nil
	end
	if inst:IsA("Attachment") then
		return inst.WorldPosition
	elseif inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function buildDoorLeaf(doorInst: Instance, isLeft: boolean, defaultDeg: number): DoorLeaf
	local closedPivot = (doorInst:GetAttribute("ClosedPivot") :: CFrame?)
		or (doorInst:GetAttribute("ClosedCFrame") :: CFrame?)
		or getPivot(doorInst)
	local angleDeg = (doorInst:GetAttribute("OpenAngleDeg") :: number?)
		or (if isLeft then -defaultDeg else defaultDeg)
	local openAngleRad = math.rad(angleDeg)

	local existingAlpha = doorInst:FindFirstChild("DoorSwingAlpha")
	if existingAlpha then
		existingAlpha:Destroy()
	end

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Name = "DoorSwingAlpha"
	alphaValue.Value = 0
	alphaValue.Parent = doorInst

	local leaf: DoorLeaf = {
		Target = doorInst,
		ClosedPivot = closedPivot,
		OpenAngleRad = openAngleRad,
		AlphaValue = alphaValue,
		ActiveTween = nil,
	}

	alphaValue.Changed:Connect(function(alpha: number)
		setPivot(doorInst, leaf.ClosedPivot * CFrame.Angles(0, leaf.OpenAngleRad * alpha, 0))
	end)

	return leaf
end

local function tweenDoorLeaf(leaf: DoorLeaf, targetAlpha: number, instant: boolean?)
	if leaf.ActiveTween then
		leaf.ActiveTween:Cancel()
		leaf.ActiveTween = nil
	end
	if instant then
		leaf.AlphaValue.Value = targetAlpha
		setPivot(leaf.Target, leaf.ClosedPivot * CFrame.Angles(0, leaf.OpenAngleRad * targetAlpha, 0))
	else
		local tween = TweenService:Create(leaf.AlphaValue, DOOR_TWEEN_INFO, { Value = targetAlpha })
		leaf.ActiveTween = tween
		tween:Play()
	end
end

function SynthesisDoorController.SetDoorsOpen(state: ChamberState, open: boolean, instant: boolean?)
	if state.IsOpen == open and not instant then
		return
	end
	state.IsOpen = open
	state.Model:SetAttribute("DoorsOpen", open)

	local targetAlpha = if open then 1 else 0
	tweenDoorLeaf(state.LeftDoor, targetAlpha, instant)
	tweenDoorLeaf(state.RightDoor, targetAlpha, instant)

	if state.CoreEmitter then
		state.CoreEmitter.Rate = if open then 22 else 6
	end
	if state.CoreLight then
		local goalBright = if open then 3.2 else 1.4
		local goalRange = if open then 32 else 22
		if instant then
			state.CoreLight.Brightness = goalBright
			state.CoreLight.Range = goalRange
		else
			TweenService:Create(state.CoreLight, LIGHT_TWEEN_INFO, {
				Brightness = goalBright,
				Range = goalRange,
			}):Play()
		end
	end
	if state.AmbientLight then
		local goalAmbient = if open then 1.8 else 0.8
		if instant then
			state.AmbientLight.Brightness = goalAmbient
		else
			TweenService:Create(state.AmbientLight, LIGHT_TWEEN_INFO, {
				Brightness = goalAmbient,
			}):Play()
		end
	end
end

function SynthesisDoorController.RegisterChamber(chamberModel: Model): ChamberState?
	if registeredChambers[chamberModel] then
		return registeredChambers[chamberModel]
	end

	local leftDoor = chamberModel:FindFirstChild("Chamber_Door_Left", true)
	local rightDoor = chamberModel:FindFirstChild("Chamber_Door_Right", true)
	local trigger = chamberModel:FindFirstChild("DoorTriggerCenter", true) or chamberModel.PrimaryPart

	if not (leftDoor and rightDoor and trigger) then
		return nil
	end

	local openDeg = (chamberModel:GetAttribute("DoorOpenAngleDeg") :: number?) or OUTWARD_ANGLE_DEG
	local coreBall = chamberModel:FindFirstChild("SynthesisCore", true) :: BasePart?
	local coreLight = chamberModel:FindFirstChild("SynthesisCoreLight", true) :: PointLight?
	local ambientLight = chamberModel:FindFirstChild("SanctumAmbientLight", true) :: PointLight?
	local coreEmitter = chamberModel:FindFirstChild("SynthesisCoreFlame", true) :: ParticleEmitter?

	local state: ChamberState = {
		Model = chamberModel,
		LeftDoor = buildDoorLeaf(leftDoor, true, openDeg),
		RightDoor = buildDoorLeaf(rightDoor, false, openDeg),
		TriggerSource = trigger,
		CenterSource = chamberModel.PrimaryPart,
		CoreBall = coreBall,
		CoreBaseCF = if coreBall then coreBall.CFrame else nil,
		CoreLight = coreLight,
		AmbientLight = ambientLight,
		CoreEmitter = coreEmitter,
		IsOpen = false,
	}

	registeredChambers[chamberModel] = state
	chamberModel.Destroying:Connect(function()
		registeredChambers[chamberModel] = nil
	end)

	SynthesisDoorController.SetDoorsOpen(state, false, true)
	return state
end

local function isSynthesisChamberModel(inst: Instance): boolean
	if not inst:IsA("Model") then
		return false
	end
	return inst.Name == "Building_ThePit"
		or inst.Name == "SynthesisChamber"
		or inst:GetAttribute("SynthesisChamber") == true
		or inst:GetAttribute("Facility") == "ThePit"
end

function SynthesisDoorController.Init()
	if started then
		return
	end
	started = true

	local localPlayer = Players.LocalPlayer

	local function scanRoot(root: Instance)
		for _, desc in ipairs(root:GetDescendants()) do
			if isSynthesisChamberModel(desc) then
				SynthesisDoorController.RegisterChamber(desc :: Model)
			end
		end
	end

	local plotsFolder = Workspace:FindFirstChild("WaitingRoomPlots")
	if plotsFolder then
		scanRoot(plotsFolder)
		plotsFolder.DescendantAdded:Connect(function(desc)
			if isSynthesisChamberModel(desc) then
				task.defer(function()
					if desc.Parent then
						SynthesisDoorController.RegisterChamber(desc :: Model)
					end
				end)
			end
		end)
	end

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "WaitingRoomPlots" then
			scanRoot(child)
			child.DescendantAdded:Connect(function(desc)
				if isSynthesisChamberModel(desc) then
					task.defer(function()
						if desc.Parent then
							SynthesisDoorController.RegisterChamber(desc :: Model)
						end
					end)
				end
			end)
		elseif isSynthesisChamberModel(child) then
			task.defer(function()
				if child.Parent then
					SynthesisDoorController.RegisterChamber(child :: Model)
				end
			end)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for _, state in pairs(registeredChambers) do
			if state.CoreBall and state.CoreBaseCF and state.CoreBall.Parent then
				local bob = math.sin(now * 2.4) * 0.22
				state.CoreBall.CFrame = state.CoreBaseCF * CFrame.new(0, bob, 0) * CFrame.Angles(0, now * 1.1, 0)
			end
		end

		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0

		local character = localPlayer and localPlayer.Character
		local rootPart = (character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)) :: BasePart?
		if not rootPart then
			return
		end

		local playerPos = rootPart.Position
		for model, state in pairs(registeredChambers) do
			if not model.Parent then
				registeredChambers[model] = nil
				continue
			end

			local trigPos = getWorldPosition(state.TriggerSource)
			local centerPos = getWorldPosition(state.CenterSource) or trigPos
			if not trigPos or not centerPos then
				continue
			end

			-- Horizontal distance to the front threshold & to the interior sanctum center
			local triggerDist = Vector3.new(playerPos.X - trigPos.X, 0, playerPos.Z - trigPos.Z).Magnitude
			local centerDist = Vector3.new(playerPos.X - centerPos.X, 0, playerPos.Z - centerPos.Z).Magnitude
			local insideSanctum = centerDist <= INTERIOR_RADIUS

			if not state.IsOpen and (triggerDist <= OPEN_DISTANCE or insideSanctum) then
				SynthesisDoorController.SetDoorsOpen(state, true, false)
			elseif state.IsOpen and (triggerDist >= CLOSE_DISTANCE and not insideSanctum) then
				SynthesisDoorController.SetDoorsOpen(state, false, false)
			end
		end
	end)
end

SynthesisDoorController.Start = SynthesisDoorController.Init
_G.SynthesisDoorController = SynthesisDoorController

return SynthesisDoorController
