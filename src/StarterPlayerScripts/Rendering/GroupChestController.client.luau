--!strict
-- StarterPlayerScripts/Rendering/GroupChestController.client.luau
-- Client controller for the Blender-authored Group Chest station in the hub:
--   * Hydrates EditableMesh parts via GroupChestMeshHydrator on bind and late replication.
--   * Drives ambient light-blue digital glitch VFX (orbiting/bobbing shards, periodic
--     glitch snaps, flickering crossing scanline beams, rising glitch sparks, light shimmer).
--   * Animates the hinged lid opening around the rear hinge (+105 deg around +X) with
--     glitch charge-up, 2 trailing neon holographic echo lids, burst particles & shockwave.
--   * Syncs GroupChestPrompt and GroupChestSign with RewardsStore.State.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local GroupChestMeshHydrator = require(Assets:WaitForChild("GroupChestMeshHydrator"))
local HubPresence = require(script.Parent:WaitForChild("HubPresence"))
local AudioManager = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("AudioManager"))
local RewardsStore = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Hud"):WaitForChild("RewardsStore"))

local STATION_TAG = "GroupChestStation"
local STATION_NAME = "GroupChestStation"
local HINGE_LOCAL_OFFSET = Vector3.new(0, 2.85, 2.15)

-- Positive rotation around +X swings the -Z chest front upward and backward from the +Z rear hinge.
local LID_OPEN_ANGLE_RAD = math.rad(105)
local LID_OPEN_TWEEN_INFO = TweenInfo.new(0.72, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LIGHT_SETTLE_TWEEN_INFO = TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local CHARGE_UP_SECONDS = 0.30
local ECHO_TRAIL_SECONDS = 0.78
local ERROR_SHAKE_SECONDS = 0.22

local COLOR_ELECTRIC_BLUE = Color3.fromRGB(46, 128, 255)
local COLOR_ICE_WHITE = Color3.fromRGB(185, 240, 255)
local COLOR_CYAN_GLOW = Color3.fromRGB(70, 210, 255)
local COLOR_CLAIMED_GREEN = Color3.fromRGB(110, 245, 165)
local COLOR_ERROR_TEXT = Color3.fromRGB(255, 115, 115)

local CLAIMED_SUBTITLE_TEXT = "CLAIMED · +50,000 GOLD · +2,000 GEMS"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local rng = Random.new()

type ShardRecord = {
	Part: BasePart,
	BaseCFrame: CFrame,
	BaseColor: Color3,
	Index: number,
	GlitchUntil: number,
	GlitchOffsetX: number,
	GlitchOffsetY: number,
	GlitchColor: Color3,
}

type ScanlineBeam = {
	Beam: Beam,
	Att0: Attachment,
	Att1: Attachment,
	BasePos0: Vector3,
	BasePos1: Vector3,
}

type EchoPartEntry = {
	Part: BasePart,
	RelOffset: CFrame,
}

type EchoLid = {
	Model: Model,
	TrailFactor: number,
	Parts: { EchoPartEntry },
}

type StationState = {
	Model: Model,
	BaseGroup: Model?,
	LidGroup: Model?,
	ClosedPivot: CFrame?,
	AlphaValue: NumberValue?,
	AlphaConn: RBXScriptConnection?,
	ActiveAlphaTween: Tween?,
	ActiveLightTween: Tween?,
	LidParts: { BasePart },
	BaseVisualParts: { BasePart },
	GlitchShardsFolder: Instance?,
	Shards: { [BasePart]: ShardRecord },
	InitialShardCFrames: { [string]: CFrame },
	ShardFallbackIndices: { [string]: number },
	CoreLightAnchor: BasePart?,
	Light: PointLight?,
	SparkEmitter: ParticleEmitter?,
	BurstEmitter: ParticleEmitter?,
	Scanlines: { ScanlineBeam },
	ScanlinesOrigin: CFrame?,
	Trigger: BasePart?,
	Prompt: ProximityPrompt?,
	PromptConn: RBXScriptConnection?,
	SignTitle: TextLabel?,
	SignSubtitle: TextLabel?,
	DefaultSubtitleText: string?,
	DefaultSubtitleColor: Color3?,
	RefreshQueued: boolean,
	PendingHydration: boolean,
	Claiming: boolean,
	PendingLiveClaim: boolean,
	IsOpening: boolean,
	IsOpen: boolean,
	NextGlitchTick: number,
	BeamPulseUntil: number,
	ErrorUntil: number,
	ErrorToken: number,
	Connections: { RBXScriptConnection },
	LidAttrConn: RBXScriptConnection?,
	TrackedLidGroup: Model?,
}

local stations: { [Model]: StationState } = {}

local function isReplaced(inst: Instance): boolean
	return inst:GetAttribute("ReplacedByHydratedMesh") == true
end

local function isClientVfx(inst: Instance): boolean
	return inst:GetAttribute("GroupChestClientVfx") == true
end

local function parseShardIndex(name: string, fallback: number): number
	local digits = string.match(name, "(%d+)$")
	return if digits then (tonumber(digits) or fallback) else fallback
end

local function getStationOrigin(state: StationState): CFrame
	if state.ClosedPivot then
		return state.ClosedPivot * CFrame.new(-HINGE_LOCAL_OFFSET)
	end
	if state.Trigger then
		return state.Trigger.CFrame
	end
	return state.Model:GetPivot()
end

local function getStationPosition(state: StationState): Vector3
	if state.CoreLightAnchor and state.CoreLightAnchor.Parent then
		return state.CoreLightAnchor.Position
	end
	if state.Trigger and state.Trigger.Parent then
		return state.Trigger.Position
	end
	return state.Model:GetPivot().Position
end

local function cancelTween(tw: Tween?): nil
	if tw then
		tw:Cancel()
	end
	return nil
end

local function setLidAlphaPivot(state: StationState, alpha: number)
	local lid = state.LidGroup
	local closedPivot = state.ClosedPivot
	if lid and lid.Parent and closedPivot then
		lid:PivotTo(closedPivot * CFrame.Angles(LID_OPEN_ANGLE_RAD * alpha, 0, 0))
	end
end

local function createScanlineBeam(anchor: BasePart, name: string, worldP0: Vector3, worldP1: Vector3): ScanlineBeam
	local localP0 = anchor.CFrame:PointToObjectSpace(worldP0)
	local localP1 = anchor.CFrame:PointToObjectSpace(worldP1)

	local att0 = Instance.new("Attachment")
	att0.Name = name .. "_Att0"
	att0.Position = localP0
	att0:SetAttribute("GroupChestClientVfx", true)
	att0.Parent = anchor

	local att1 = Instance.new("Attachment")
	att1.Name = name .. "_Att1"
	att1.Position = localP1
	att1:SetAttribute("GroupChestClientVfx", true)
	att1.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLOR_ELECTRIC_BLUE),
		ColorSequenceKeypoint.new(0.5, COLOR_ICE_WHITE),
		ColorSequenceKeypoint.new(1, COLOR_CYAN_GLOW),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.2, 0.10),
		NumberSequenceKeypoint.new(0.5, 0.04),
		NumberSequenceKeypoint.new(0.8, 0.10),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	beam.Width0 = 0.10
	beam.Width1 = 0.07
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Enabled = false
	beam:SetAttribute("GroupChestClientVfx", true)
	beam.Parent = anchor

	return {
		Beam = beam,
		Att0 = att0,
		Att1 = att1,
		BasePos0 = localP0,
		BasePos1 = localP1,
	}
end

type EmitterOpts = {
	Name: string,
	Rate: number,
	Lifetime: NumberRange,
	Speed: NumberRange,
	Spread: Vector2,
	Accel: Vector3,
	Drag: number,
	Size: NumberSequence,
	Transparency: NumberSequence,
	RotSpeed: NumberRange,
}

local function getOrCreateGlitchEmitter(anchor: BasePart, opts: EmitterOpts): ParticleEmitter
	local existing = anchor:FindFirstChild(opts.Name)
	if existing and existing:IsA("ParticleEmitter") then
		return existing
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = opts.Name
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLOR_ICE_WHITE),
		ColorSequenceKeypoint.new(0.45, COLOR_CYAN_GLOW),
		ColorSequenceKeypoint.new(1, COLOR_ELECTRIC_BLUE),
	})
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = opts.Rate
	emitter.Lifetime = opts.Lifetime
	emitter.Speed = opts.Speed
	emitter.SpreadAngle = opts.Spread
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = opts.Accel
	emitter.Drag = opts.Drag
	emitter.Size = opts.Size
	emitter.Transparency = opts.Transparency
	emitter.RotSpeed = opts.RotSpeed
	emitter.Rotation = NumberRange.new(0, 360)
	emitter:SetAttribute("GroupChestClientVfx", true)
	emitter.Parent = anchor
	return emitter
end

local function ensureCoreVfx(state: StationState)
	local anchor = state.CoreLightAnchor
	if not anchor or not anchor.Parent then
		return
	end

	if not state.SparkEmitter or state.SparkEmitter.Parent ~= anchor then
		state.SparkEmitter = getOrCreateGlitchEmitter(anchor, {
			Name = "GroupChestGlitchSparks",
			Rate = 12,
			Lifetime = NumberRange.new(0.9, 1.8),
			Speed = NumberRange.new(1.6, 3.8),
			Spread = Vector2.new(38, 38),
			Accel = Vector3.new(0, 1.5, 0),
			Drag = 1.2,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.08),
				NumberSequenceKeypoint.new(0.25, 0.22),
				NumberSequenceKeypoint.new(0.75, 0.14),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.65, 0.4),
				NumberSequenceKeypoint.new(1, 1),
			}),
			RotSpeed = NumberRange.new(-130, 130),
		})
	end

	if not state.BurstEmitter or state.BurstEmitter.Parent ~= anchor then
		state.BurstEmitter = getOrCreateGlitchEmitter(anchor, {
			Name = "GroupChestGlitchBurst",
			Rate = 0,
			Lifetime = NumberRange.new(0.55, 1.15),
			Speed = NumberRange.new(7, 17),
			Spread = Vector2.new(65, 65),
			Accel = Vector3.new(0, -4, 0),
			Drag = 2.8,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.18),
				NumberSequenceKeypoint.new(0.2, 0.34),
				NumberSequenceKeypoint.new(0.8, 0.14),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.65, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			RotSpeed = NumberRange.new(-180, 180),
		})
	end

	local origin = getStationOrigin(state)
	local p1a = origin:PointToWorldSpace(Vector3.new(-3.35, 1.95, -2.55))
	local p1b = origin:PointToWorldSpace(Vector3.new(3.35, 2.45, -2.55))
	local p2a = origin:PointToWorldSpace(Vector3.new(-3.35, 2.95, -2.48))
	local p2b = origin:PointToWorldSpace(Vector3.new(3.35, 2.15, -2.48))

	if #state.Scanlines == 0 or state.Scanlines[1].Beam.Parent ~= anchor then
		for _, old in state.Scanlines do
			old.Beam:Destroy()
			old.Att0:Destroy()
			old.Att1:Destroy()
		end
		table.clear(state.Scanlines)

		table.insert(state.Scanlines, createScanlineBeam(anchor, "GroupChestScanlineA", p1a, p1b))
		table.insert(state.Scanlines, createScanlineBeam(anchor, "GroupChestScanlineB", p2a, p2b))
		state.ScanlinesOrigin = origin
	elseif not state.ScanlinesOrigin or (state.ScanlinesOrigin.Position - origin.Position).Magnitude > 0.05 then
		local pairsList = { { p1a, p1b }, { p2a, p2b } }
		for idx, scan in state.Scanlines do
			local pts = pairsList[idx]
			if pts then
				scan.BasePos0 = anchor.CFrame:PointToObjectSpace(pts[1])
				scan.BasePos1 = anchor.CFrame:PointToObjectSpace(pts[2])
				scan.Att0.Position = scan.BasePos0
				scan.Att1.Position = scan.BasePos1
			end
		end
		state.ScanlinesOrigin = origin
	end
end

local function spawnShockwaveRing(origin: CFrame)
	local centerCF = origin * CFrame.new(0, 2.75, -0.25) * CFrame.Angles(0, 0, math.rad(90))

	local outer = Instance.new("Part")
	outer.Name = "GroupChestShockwaveRing"
	outer.Shape = Enum.PartType.Cylinder
	outer.Size = Vector3.new(0.14, 2.4, 2.4)
	outer.CFrame = centerCF
	outer.Material = Enum.Material.Neon
	outer.Color = COLOR_CYAN_GLOW
	outer.Transparency = 0.22
	outer.Anchored = true
	outer.CanCollide = false
	outer.CanTouch = false
	outer.CanQuery = false
	outer.CastShadow = false
	outer.Parent = Workspace

	local inner = outer:Clone()
	inner.Name = "GroupChestShockwaveCore"
	inner.Size = Vector3.new(0.08, 1.8, 1.8)
	inner.Color = COLOR_ICE_WHITE
	inner.Transparency = 0.15
	inner.Parent = Workspace

	TweenService:Create(
		outer,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 16.5, 16.5), Transparency = 1 }
	):Play()
	TweenService:Create(
		inner,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.04, 11.5, 11.5), Transparency = 1 }
	):Play()

	Debris:AddItem(outer, 0.62)
	Debris:AddItem(inner, 0.50)
end

local function createEchoLid(lidParts: { BasePart }, closedPivot: CFrame, trailFactor: number, index: number): EchoLid
	local echoModel = Instance.new("Model")
	echoModel.Name = "GroupChestLidEcho_" .. index
	local entries: { EchoPartEntry } = {}

	for _, src in lidParts do
		if src.Parent and not isReplaced(src) and src.Transparency < 0.99 then
			local clone = src:Clone()
			for _, child in clone:GetChildren() do
				if not child:IsA("DataModelMesh") then
					child:Destroy()
				end
			end
			clone.Color = COLOR_CYAN_GLOW
			clone.Material = Enum.Material.Neon
			clone.Transparency = 0.58
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
			clone.Massless = true
			clone.CastShadow = false
			clone.Parent = echoModel

			table.insert(entries, {
				Part = clone,
				RelOffset = closedPivot:ToObjectSpace(src.CFrame),
			})
		end
	end

	echoModel.WorldPivot = closedPivot
	echoModel.Parent = Workspace
	return {
		Model = echoModel,
		TrailFactor = trailFactor,
		Parts = entries,
	}
end

local function setScanlinesIdle(state: StationState)
	for _, scan in state.Scanlines do
		scan.Att0.Position = scan.BasePos0
		scan.Att1.Position = scan.BasePos1
		scan.Beam.Width0 = 0.10
		scan.Beam.Width1 = 0.07
		scan.Beam.Enabled = false
	end
end

local function runChargeUp(state: StationState): boolean
	local lidGroup = state.LidGroup
	local closedPivot = state.ClosedPivot
	AudioManager.Play3D("SummonCharge", getStationPosition(state))

	if state.SparkEmitter then
		state.SparkEmitter.Rate = 48
	end

	-- Phase 1 (0.0s - 0.30s): Glitch charge-up shudder + bright flickering scanlines
	local chargeStart = os.clock()
	while os.clock() - chargeStart < CHARGE_UP_SECONDS do
		if not state.Model.Parent then
			return false
		end
		if lidGroup and lidGroup.Parent and closedPivot then
			local jx = rng:NextNumber(-0.08, 0.08)
			local jz = rng:NextNumber(-0.04, 0.04)
			lidGroup:PivotTo(closedPivot * CFrame.new(jx, 0, jz))
		end
		for _, scan in state.Scanlines do
			if scan.Beam.Parent then
				scan.Beam.Enabled = rng:NextNumber() > 0.22
				scan.Beam.Width0 = rng:NextNumber(0.14, 0.24)
				scan.Beam.Width1 = rng:NextNumber(0.10, 0.18)
				local dy = rng:NextNumber(-0.32, 0.32)
				scan.Att0.Position = scan.BasePos0 + Vector3.new(0, dy, 0)
				scan.Att1.Position = scan.BasePos1 + Vector3.new(0, -dy * 0.5, 0)
			end
		end
		if state.Light and state.Light.Parent then
			state.Light.Brightness = rng:NextNumber(2.1, 4.4)
		end
		RunService.Heartbeat:Wait()
	end

	setLidAlphaPivot(state, 0)
	setScanlinesIdle(state)
	return state.Model.Parent ~= nil
end

local function runLidSwingAndBurst(state: StationState)
	local closedPivot = state.ClosedPivot
	local alphaValue = state.AlphaValue
	local origin = getStationOrigin(state)

	-- Phase 2 (0.30s - 1.05s): Hinged lid swing, 2 holographic echoes, light flare, burst & audio
	local echoes: { EchoLid } = {}
	if closedPivot and #state.LidParts > 0 then
		table.insert(echoes, createEchoLid(state.LidParts, closedPivot, 0.78, 1))
		table.insert(echoes, createEchoLid(state.LidParts, closedPivot, 0.54, 2))
	end

	if state.Light and state.Light.Parent then
		state.ActiveLightTween = cancelTween(state.ActiveLightTween)
		state.Light.Color = COLOR_ICE_WHITE
		state.Light.Brightness = 6.5
		state.Light.Range = 36
		local lightTween = TweenService:Create(state.Light, LIGHT_SETTLE_TWEEN_INFO, {
			Brightness = 2.6,
			Range = 24,
			Color = COLOR_CYAN_GLOW,
		})
		state.ActiveLightTween = lightTween
		lightTween:Play()
	end

	if state.SparkEmitter then
		state.SparkEmitter.Rate = 12
	end
	if state.BurstEmitter then
		state.BurstEmitter:Emit(45)
	end

	spawnShockwaveRing(origin)
	local burstPos = getStationPosition(state)
	AudioManager.Play3D("SummonBurstRare", burstPos)
	AudioManager.Play2D("Reward")

	if alphaValue then
		state.ActiveAlphaTween = cancelTween(state.ActiveAlphaTween)
		alphaValue.Value = 0
		local lidTween = TweenService:Create(alphaValue, LID_OPEN_TWEEN_INFO, { Value = 1 })
		state.ActiveAlphaTween = lidTween
		lidTween:Play()
	else
		setLidAlphaPivot(state, 1)
	end

	local swingStart = os.clock()
	while os.clock() - swingStart < ECHO_TRAIL_SECONDS do
		if not state.Model.Parent then
			break
		end
		local progress = math.clamp((os.clock() - swingStart) / ECHO_TRAIL_SECONDS, 0, 1)
		local alpha = if alphaValue then alphaValue.Value else 1
		local transp = 0.58 + 0.42 * (progress ^ 1.35)

		if closedPivot then
			for _, echo in echoes do
				local jx = rng:NextNumber(-0.045, 0.045)
				local jy = rng:NextNumber(-0.025, 0.025)
				local echoPivot = closedPivot
					* CFrame.Angles(LID_OPEN_ANGLE_RAD * (alpha * echo.TrailFactor), 0, 0)
					* CFrame.new(jx, jy, 0)
				for _, entry in echo.Parts do
					if entry.Part.Parent then
						entry.Part.CFrame = echoPivot * entry.RelOffset
						entry.Part.Transparency = transp
					end
				end
			end
		end
		RunService.Heartbeat:Wait()
	end

	for _, echo in echoes do
		echo.Model:Destroy()
	end
	if state.Model.Parent then
		if alphaValue then
			alphaValue.Value = 1
		end
		setLidAlphaPivot(state, 1)
	end
end

local function playOpenAnimation(state: StationState, instant: boolean)
	if not state.Model.Parent then
		return
	end
	if state.IsOpen and not instant then
		return
	end

	if instant then
		state.ActiveAlphaTween = cancelTween(state.ActiveAlphaTween)
		state.ActiveLightTween = cancelTween(state.ActiveLightTween)
		state.IsOpening = false
		state.IsOpen = true
		if state.AlphaValue then
			state.AlphaValue.Value = 1
		end
		setLidAlphaPivot(state, 1)
		if state.Light and state.Light.Parent then
			state.Light.Color = COLOR_CYAN_GLOW
			state.Light.Brightness = 2.6
			state.Light.Range = 24
		end
		if state.SparkEmitter then
			state.SparkEmitter.Rate = 12
		end
		return
	end

	if state.IsOpening then
		return
	end
	state.IsOpening = true

	task.spawn(function()
		if runChargeUp(state) then
			runLidSwingAndBurst(state)
			state.IsOpen = true
		end
		state.IsOpening = false
	end)
end

local function playErrorShake(state: StationState, message: string?)
	AudioManager.Play2D("Error")
	state.ErrorUntil = os.clock() + ERROR_SHAKE_SECONDS
	state.ErrorToken += 1
	local token = state.ErrorToken

	if state.SignSubtitle and state.SignSubtitle.Parent and not state.IsOpen then
		local sub = state.SignSubtitle
		if state.DefaultSubtitleText == nil then
			state.DefaultSubtitleText = sub.Text
			state.DefaultSubtitleColor = sub.TextColor3
		end
		if message and message ~= "" then
			sub.Text = string.upper(message)
			sub.TextColor3 = COLOR_ERROR_TEXT
			task.delay(2.2, function()
				if state.ErrorToken == token and not state.IsOpen and sub.Parent and state.DefaultSubtitleText then
					sub.Text = state.DefaultSubtitleText
					if state.DefaultSubtitleColor then
						sub.TextColor3 = state.DefaultSubtitleColor
					end
				end
			end)
		end
	end

	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < ERROR_SHAKE_SECONDS do
			if not state.Model.Parent or state.IsOpen or state.IsOpening then
				return
			end
			local progress = (os.clock() - start) / ERROR_SHAKE_SECONDS
			local damp = 1 - progress
			local dx = math.sin(progress * math.pi * 6) * 0.10 * damp
			if state.LidGroup and state.LidGroup.Parent and state.ClosedPivot then
				state.LidGroup:PivotTo(state.ClosedPivot * CFrame.new(dx, 0, 0))
			end
			RunService.Heartbeat:Wait()
		end
		if state.Model.Parent and not state.IsOpen and not state.IsOpening then
			setLidAlphaPivot(state, 0)
		end
	end)
end

local function isGroupChestClaimed(storeState: any): boolean
	return type(storeState) == "table"
		and type(storeState.GroupChest) == "table"
		and storeState.GroupChest.Claimed == true
end

local function applyStoreState(state: StationState, storeState: any)
	if not isGroupChestClaimed(storeState) then
		return
	end

	if not state.IsOpen and not state.IsOpening and not state.PendingLiveClaim then
		playOpenAnimation(state, true)
	end

	if state.Prompt and state.Prompt.Parent then
		state.Prompt.ActionText = "Claimed"
		state.Prompt.Enabled = false
	end

	if state.SignSubtitle and state.SignSubtitle.Parent then
		state.SignSubtitle.Text = CLAIMED_SUBTITLE_TEXT
		state.SignSubtitle.TextColor3 = COLOR_CLAIMED_GREEN
	end
end

local function connectPrompt(state: StationState, prompt: ProximityPrompt?)
	if state.Prompt == prompt then
		return
	end
	if state.PromptConn then
		state.PromptConn:Disconnect()
		state.PromptConn = nil
	end
	state.Prompt = prompt
	if not prompt then
		return
	end

	state.PromptConn = prompt.Triggered:Connect(function()
		if state.Claiming or state.IsOpen or state.IsOpening then
			return
		end
		state.Claiming = true
		state.PendingLiveClaim = true
		task.spawn(function()
			local ok, message = RewardsStore.Request("CLAIM_GROUP_CHEST")
			state.PendingLiveClaim = false
			state.Claiming = false
			if not state.Model.Parent then
				return
			end
			if ok then
				playOpenAnimation(state, false)
				applyStoreState(state, RewardsStore.State)
			else
				playErrorShake(state, message)
			end
		end)
	end)
end

local function bindLidGroup(state: StationState, lidGroup: Model?)
	if state.TrackedLidGroup == lidGroup then
		if lidGroup then
			local attrPivot = lidGroup:GetAttribute("ClosedPivot")
			if typeof(attrPivot) == "CFrame" then
				state.ClosedPivot = attrPivot
			end
		end
		return
	end

	if state.AlphaConn then
		state.AlphaConn:Disconnect()
		state.AlphaConn = nil
	end
	if state.LidAttrConn then
		state.LidAttrConn:Disconnect()
		state.LidAttrConn = nil
	end
	state.TrackedLidGroup = lidGroup
	state.LidGroup = lidGroup
	state.AlphaValue = nil

	if not lidGroup then
		return
	end

	local attrPivot = lidGroup:GetAttribute("ClosedPivot")
	state.ClosedPivot = if typeof(attrPivot) == "CFrame" then attrPivot else lidGroup:GetPivot()

	state.LidAttrConn = lidGroup:GetAttributeChangedSignal("ClosedPivot"):Connect(function()
		local updated = lidGroup:GetAttribute("ClosedPivot")
		if typeof(updated) == "CFrame" then
			state.ClosedPivot = updated
			ensureCoreVfx(state)
			if state.IsOpen then
				setLidAlphaPivot(state, 1)
			elseif not state.IsOpening then
				setLidAlphaPivot(state, 0)
			end
		end
	end)

	local existingAlpha = lidGroup:FindFirstChild("LidOpenAlpha")
	if existingAlpha then
		existingAlpha:Destroy()
	end
	local alphaValue = Instance.new("NumberValue")
	alphaValue.Name = "LidOpenAlpha"
	alphaValue.Value = if state.IsOpen then 1 else 0
	alphaValue.Parent = lidGroup
	state.AlphaValue = alphaValue

	state.AlphaConn = alphaValue.Changed:Connect(function(alpha: number)
		setLidAlphaPivot(state, alpha)
	end)
end

local function collectActiveParts(container: Instance?, out: { BasePart })
	table.clear(out)
	if not container then
		return
	end
	for _, desc in container:GetDescendants() do
		if desc:IsA("BasePart") and not isReplaced(desc) and not isClientVfx(desc) then
			table.insert(out, desc)
		end
	end
end

local function collectGlitchShards(state: StationState)
	local shardsFolder = state.Model:FindFirstChild("GlitchShards", true)
	state.GlitchShardsFolder = shardsFolder
	for part in state.Shards do
		if not part.Parent or isReplaced(part) or (shardsFolder and not part:IsDescendantOf(shardsFolder)) then
			state.Shards[part] = nil
		end
	end
	if not shardsFolder then
		return
	end
	for _, desc in shardsFolder:GetDescendants() do
		if not desc:IsA("BasePart") then
			continue
		end
		local idxAttr = desc:GetAttribute("ShardIndex")
		if type(idxAttr) == "number" then
			state.ShardFallbackIndices[desc.Name] = idxAttr
		end
		if isReplaced(desc) then
			if not state.InitialShardCFrames[desc.Name] then
				state.InitialShardCFrames[desc.Name] = desc.CFrame
			end
		elseif not isClientVfx(desc) and not state.Shards[desc] then
			local initialCF = state.InitialShardCFrames[desc.Name] or desc.CFrame
			state.InitialShardCFrames[desc.Name] = initialCF
			local index = if type(idxAttr) == "number"
				then idxAttr
				else (state.ShardFallbackIndices[desc.Name] or parseShardIndex(desc.Name, 1))
			state.Shards[desc] = {
				Part = desc,
				BaseCFrame = initialCF,
				BaseColor = desc.Color,
				Index = index,
				GlitchUntil = 0,
				GlitchOffsetX = 0,
				GlitchOffsetY = 0,
				GlitchColor = desc.Color,
			}
		end
	end
end

local function refreshStation(state: StationState)
	local model = state.Model
	if not model.Parent then
		return
	end

	local baseGroup = model:FindFirstChild("BaseGroup", true)
	state.BaseGroup = if baseGroup and baseGroup:IsA("Model") then baseGroup else nil

	local lidInst = model:FindFirstChild("LidGroup", true)
	bindLidGroup(state, if lidInst and lidInst:IsA("Model") then lidInst else nil)

	collectActiveParts(state.BaseGroup, state.BaseVisualParts)
	collectActiveParts(state.LidGroup, state.LidParts)
	collectGlitchShards(state)

	local coreAnchor = model:FindFirstChild("CoreLightAnchor", true)
	state.CoreLightAnchor = if coreAnchor and coreAnchor:IsA("BasePart") and not isReplaced(coreAnchor) then coreAnchor else nil

	local glitchLight: PointLight? = nil
	if state.CoreLightAnchor then
		local found = state.CoreLightAnchor:FindFirstChild("ChestGlitchLight", true)
		if found and found:IsA("PointLight") then
			glitchLight = found
		end
	end
	if not glitchLight then
		local found = model:FindFirstChild("ChestGlitchLight", true)
		if found and found:IsA("PointLight") then
			glitchLight = found
		end
	end
	state.Light = glitchLight

	local trigger = model:FindFirstChild("GroupChestTrigger", true) or model.PrimaryPart
	state.Trigger = if trigger and trigger:IsA("BasePart") then trigger else nil

	local promptInst = (if state.Trigger then state.Trigger:FindFirstChild("GroupChestPrompt", true) else nil)
		or model:FindFirstChild("GroupChestPrompt", true)
	connectPrompt(state, if promptInst and promptInst:IsA("ProximityPrompt") then promptInst else nil)

	local signInst = (if state.Trigger then state.Trigger:FindFirstChild("GroupChestSign", true) else nil)
		or model:FindFirstChild("GroupChestSign", true)
	if signInst and signInst:IsA("BillboardGui") then
		local title = signInst:FindFirstChild("Title", true)
		local subtitle = signInst:FindFirstChild("Subtitle", true)
		state.SignTitle = if title and title:IsA("TextLabel") then title else nil
		state.SignSubtitle = if subtitle and subtitle:IsA("TextLabel") then subtitle else nil
		if state.SignSubtitle and state.DefaultSubtitleText == nil then
			state.DefaultSubtitleText = state.SignSubtitle.Text
			state.DefaultSubtitleColor = state.SignSubtitle.TextColor3
		end
	end

	ensureCoreVfx(state)
	applyStoreState(state, RewardsStore.State)
end

local function hasPendingMesh(root: Instance): boolean
	for _, desc in root:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("PendingBlenderGroupChestMesh") == true then
			return true
		end
	end
	return false
end

local function scheduleHydrateAndRefresh(state: StationState, needsHydrate: boolean)
	if needsHydrate then
		state.PendingHydration = true
	end
	if state.RefreshQueued then
		return
	end
	state.RefreshQueued = true
	task.defer(function()
		state.RefreshQueued = false
		if not state.Model.Parent then
			return
		end
		if state.PendingHydration or hasPendingMesh(state.Model) then
			state.PendingHydration = false
			GroupChestMeshHydrator.HydratePendingClientParts(state.Model)
		end
		refreshStation(state)
	end)
end

local function unbindStation(model: Model)
	local state = stations[model]
	if not state then
		return
	end
	stations[model] = nil
	state.ActiveAlphaTween = cancelTween(state.ActiveAlphaTween)
	state.ActiveLightTween = cancelTween(state.ActiveLightTween)
	if state.AlphaConn then
		state.AlphaConn:Disconnect()
	end
	if state.LidAttrConn then
		state.LidAttrConn:Disconnect()
	end
	if state.PromptConn then
		state.PromptConn:Disconnect()
	end
	for _, conn in state.Connections do
		conn:Disconnect()
	end
end

local WATCHED_NAMES = {
	BaseGroup = true,
	LidGroup = true,
	GlitchShards = true,
	CoreLightAnchor = true,
	ChestGlitchLight = true,
	GroupChestTrigger = true,
	GroupChestPrompt = true,
	GroupChestSign = true,
	Title = true,
	Subtitle = true,
}

local function bindStation(inst: Instance)
	if not inst:IsA("Model") or stations[inst] or not inst:IsDescendantOf(Workspace) then
		return
	end

	local now = os.clock()
	local state: StationState = {
		Model = inst,
		BaseGroup = nil,
		LidGroup = nil,
		ClosedPivot = nil,
		AlphaValue = nil,
		AlphaConn = nil,
		ActiveAlphaTween = nil,
		ActiveLightTween = nil,
		LidParts = {},
		BaseVisualParts = {},
		GlitchShardsFolder = nil,
		Shards = {},
		InitialShardCFrames = {},
		ShardFallbackIndices = {},
		CoreLightAnchor = nil,
		Light = nil,
		SparkEmitter = nil,
		BurstEmitter = nil,
		Scanlines = {},
		ScanlinesOrigin = nil,
		Trigger = nil,
		Prompt = nil,
		PromptConn = nil,
		SignTitle = nil,
		SignSubtitle = nil,
		DefaultSubtitleText = nil,
		DefaultSubtitleColor = nil,
		RefreshQueued = false,
		PendingHydration = false,
		Claiming = false,
		PendingLiveClaim = false,
		IsOpening = false,
		IsOpen = false,
		NextGlitchTick = now + rng:NextNumber(0.18, 0.44),
		BeamPulseUntil = 0,
		ErrorUntil = 0,
		ErrorToken = 0,
		Connections = {},
		LidAttrConn = nil,
		TrackedLidGroup = nil,
	}
	stations[inst] = state

	GroupChestMeshHydrator.HydratePendingClientParts(inst)
	refreshStation(state)
	scheduleHydrateAndRefresh(state, true)

	table.insert(state.Connections, inst.DescendantAdded:Connect(function(desc: Instance)
		if isClientVfx(desc) or isReplaced(desc) then
			return
		end
		local pending = desc:GetAttribute("PendingBlenderGroupChestMesh") == true
		if pending or WATCHED_NAMES[desc.Name] or desc:IsA("BasePart") then
			scheduleHydrateAndRefresh(state, pending or desc:IsA("BasePart"))
		end
	end))

	table.insert(state.Connections, inst.Destroying:Connect(function()
		unbindStation(inst)
	end))
	table.insert(state.Connections, inst.AncestryChanged:Connect(function()
		if not inst:IsDescendantOf(Workspace) then
			unbindStation(inst)
		end
	end))
end

local function stepStationIdle(state: StationState, now: number)
	local stationRot = getStationOrigin(state).Rotation
	local isTick = now >= state.NextGlitchTick
	if isTick then
		state.NextGlitchTick = now + rng:NextNumber(0.18, 0.44)
		state.BeamPulseUntil = now + rng:NextNumber(0.06, 0.11)

		local activeShards: { ShardRecord } = {}
		for _, shard in state.Shards do
			if shard.Part.Parent and not isReplaced(shard.Part) then
				table.insert(activeShards, shard)
			end
		end

		if #activeShards > 0 then
			local snapCount = math.min(#activeShards, rng:NextInteger(1, 2))
			for _ = 1, snapCount do
				local picked = activeShards[rng:NextInteger(1, #activeShards)]
				picked.GlitchUntil = now + rng:NextNumber(0.05, 0.09)
				local sign = if rng:NextNumber() < 0.5 then -1 else 1
				picked.GlitchOffsetX = sign * rng:NextNumber(0.10, 0.16)
				picked.GlitchOffsetY = rng:NextNumber(-0.04, 0.04)
				picked.GlitchColor = if rng:NextNumber() < 0.5 then COLOR_ELECTRIC_BLUE else COLOR_ICE_WHITE
			end
		end

		for _, scan in state.Scanlines do
			local dy = rng:NextNumber(-0.28, 0.28)
			scan.Att0.Position = scan.BasePos0 + Vector3.new(0, dy, 0)
			scan.Att1.Position = scan.BasePos1 + Vector3.new(0, -dy * 0.6, 0)
			scan.Beam.Width0 = rng:NextNumber(0.08, 0.16)
			scan.Beam.Width1 = rng:NextNumber(0.05, 0.12)
		end
	end

	-- Smoothly orbit & bob all 6 Blender GlitchShards around their hydrated base positions
	local orbitRadius = if state.IsOpen then 0.22 else 0.16
	for _, shard in state.Shards do
		local part = shard.Part
		if part.Parent and not isReplaced(part) then
			local phase = shard.Index * 1.047
			local orbitAngle = now * (0.95 + (shard.Index % 3) * 0.18) + phase
			local bobY = math.sin(now * 2.15 + phase) * 0.24
			local localOrbit = Vector3.new(
				math.cos(orbitAngle) * orbitRadius,
				bobY,
				math.sin(orbitAngle) * orbitRadius * 0.75
			)
			local isGlitching = now < shard.GlitchUntil
			if isGlitching then
				localOrbit += Vector3.new(shard.GlitchOffsetX, shard.GlitchOffsetY, 0)
				part.Color = shard.GlitchColor
			else
				part.Color = shard.BaseColor
			end
			local worldPos = shard.BaseCFrame.Position + stationRot * localOrbit
			local localSpin = CFrame.Angles(
				math.sin(now * 1.4 + phase) * 0.12,
				now * 0.55 + phase,
				math.cos(now * 1.1 + phase) * 0.10
			)
			part.CFrame = CFrame.new(worldPos) * shard.BaseCFrame.Rotation * localSpin
		end
	end

	if not state.IsOpening then
		if state.SparkEmitter and not state.SparkEmitter.Enabled then
			state.SparkEmitter.Enabled = true
		end

		local pulsingBeam = now < state.BeamPulseUntil or (now < state.ErrorUntil and math.floor(now * 45) % 2 == 0)
		for _, scan in state.Scanlines do
			if scan.Beam.Parent then
				scan.Beam.Enabled = pulsingBeam
			end
		end

		if state.Light and state.Light.Parent then
			if now < state.ErrorUntil then
				state.Light.Brightness = 3.2
			elseif state.IsOpen then
				local glowWave = math.sin(now * 2.7) * 0.22
				state.Light.Brightness = math.clamp(2.6 + glowWave, 2.3, 2.9)
			else
				local wave = 2.02 + math.sin(now * 3.1) * 0.24 + (if pulsingBeam then 0.14 else 0)
				state.Light.Brightness = math.clamp(wave, 1.7, 2.4)
			end
		end
	end
end

-- Tag-based binding + fallback Workspace scan for GroupChestStation models.
for _, inst in CollectionService:GetTagged(STATION_TAG) do
	bindStation(inst)
end
CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(bindStation)
CollectionService:GetInstanceRemovedSignal(STATION_TAG):Connect(function(inst: Instance)
	if inst:IsA("Model") then
		unbindStation(inst)
	end
end)

for _, desc in Workspace:GetDescendants() do
	if desc:IsA("Model") and (desc.Name == STATION_NAME or desc:HasTag(STATION_TAG)) then
		bindStation(desc)
	end
end
Workspace.DescendantAdded:Connect(function(desc: Instance)
	if desc:IsA("Model") and (desc.Name == STATION_NAME or desc:HasTag(STATION_TAG)) then
		task.defer(bindStation, desc)
	end
end)

RewardsStore.Changed:Connect(function()
	local storeState = RewardsStore.State
	for _, state in stations do
		applyStoreState(state, storeState)
	end
end)

RunService.Heartbeat:Connect(function()
	local inTower = HubPresence.InTower()
	local now = os.clock()
	for model, state in stations do
		if not model.Parent then
			unbindStation(model)
			continue
		end
		if inTower then
			if state.SparkEmitter and state.SparkEmitter.Enabled then
				state.SparkEmitter.Enabled = false
			end
			for _, scan in state.Scanlines do
				if scan.Beam.Enabled then
					scan.Beam.Enabled = false
				end
			end
			continue
		end
		stepStationIdle(state, now)
	end
end)
