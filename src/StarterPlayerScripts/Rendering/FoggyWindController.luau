--!strict
-- StarterPlayerScripts/Rendering/FoggyWindController.luau
-- Live prototype controller for dynamic fog and windy weather effects (without rain).
--
-- Responsibilities:
-- 1. Drives workspace.GlobalWind with organic Perlin-noise gusting (swaying terrain grass).
-- 2. Keeps workspace.Terrain free of volumetric Clouds: at 0.84 cover they cost about a third of the hub's
--    frame in Studio profiling (~13 -> ~20 FPS without them), so the sky relies on Atmosphere and the cloud bank.
-- 3. Emits camera-local drifting mist sheets and airborne bokeh specks (wind without rain).
-- 4. Blends atmospheric fog via HubLightingController and workspace attributes.
-- 5. Streams ambient wind sound loop.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local FoggyWindController = {}

export type WeatherConfig = {
	Enabled: boolean,
	WindStrength: number, -- Base wind studs/s (default 30)
	WindAngleDeg: number, -- Wind angle in degrees (default 35)
	FogDensity: number, -- Atmosphere density (default 0.52)
	FogHaze: number, -- Atmosphere haze (default 3.2)
	ParticlesEnabled: boolean,
	AudioEnabled: boolean,
}

local State: WeatherConfig = {
	Enabled = true, -- Always enabled naturally in the world
	WindStrength = 30,
	WindAngleDeg = 35,
	FogDensity = 0.79,
	FogHaze = 3.2,
	ParticlesEnabled = true,
	AudioEnabled = true,
}

local currentWeight = 0
local BLEND_SPEED = 2.0 -- ~1.5 s smooth fade in / out

local emitterPart: Part? = nil
local mistEmitter: ParticleEmitter? = nil
local specksEmitter: ParticleEmitter? = nil
local windSound: Sound? = nil
local isStarted = false

local SMOKE_TEXTURE = "rbxassetid://243660364"
local WIND_AUDIO_ID = "rbxassetid://9116258071"

--============================================================================
-- PARTICLES SETUP (CAMERA-LOCAL DRIFTING MIST & WIND SPECKS)
--============================================================================
local function ensureEmitterPart(): Part
	if emitterPart and emitterPart.Parent then
		return emitterPart
	end

	local container = Workspace:FindFirstChild("ClientVisualEntities") or Workspace
	local part = Instance.new("Part")
	part.Name = "FoggyWindEmitter"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(2, 2, 2)
	part.Parent = container
	emitterPart = part

	local attachment = Instance.new("Attachment")
	attachment.Name = "WeatherVFXAttachment"
	attachment.Parent = part

	-- 1. Drifting Mist Sheets (Rolling ground fog)
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "DriftingMist"
	mist.Texture = SMOKE_TEXTURE
	mist.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(190, 200, 212)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(175, 185, 198)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(160, 170, 182)),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.2, 0.93), -- faint: the camera looks through it all the time
		NumberSequenceKeypoint.new(0.7, 0.94),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 22),
		NumberSequenceKeypoint.new(0.5, 38),
		NumberSequenceKeypoint.new(1.0, 52),
	})
	mist.Lifetime = NumberRange.new(2.5, 4.2)
	mist.Rate = 0
	mist.Speed = NumberRange.new(20, 32)
	mist.SpreadAngle = Vector2.new(180, 18)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-12, 12)
	mist.Parent = attachment
	mistEmitter = mist

	-- 2. Wind Specks (Bokeh moisture orbs caught in the gale)
	local specks = Instance.new("ParticleEmitter")
	specks.Name = "WindSpecks"
	specks.Texture = SMOKE_TEXTURE
	specks.Color = ColorSequence.new(Color3.fromRGB(225, 235, 245))
	specks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.9),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	specks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.8),
		NumberSequenceKeypoint.new(0.5, 2.0),
		NumberSequenceKeypoint.new(1.0, 0.4),
	})
	specks.Lifetime = NumberRange.new(1.2, 2.2)
	specks.Rate = 0
	specks.Speed = NumberRange.new(30, 50)
	specks.SpreadAngle = Vector2.new(180, 28)
	specks.Parent = attachment
	specksEmitter = specks

	return part
end

--============================================================================
-- AMBIENT SOUND SETUP
--============================================================================
local function ensureAudio(): Sound
	if windSound and windSound.Parent then
		return windSound
	end
	local s = Instance.new("Sound")
	s.Name = "FoggyWindAmbience"
	s.SoundId = WIND_AUDIO_ID
	s.Looped = true
	s.Volume = 0
	s.RollOffMode = Enum.RollOffMode.Linear
	s.Parent = SoundService
	windSound = s
	return s
end

--============================================================================
-- OVERCAST CLOUDS SETUP
--============================================================================
-- Remove any volumetric Clouds (older builds of this controller created them, and a place file may carry one).
local function removeClouds()
	for _, child in Workspace.Terrain:GetChildren() do
		if child:IsA("Clouds") then
			child:Destroy()
		end
	end
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--============================================================================
-- FRAME UPDATE
--============================================================================
local function onHeartbeat(dt: number)
	local targetWeight = if State.Enabled then 1 else 0
	local k = 1 - math.exp(-BLEND_SPEED * dt)
	currentWeight += (targetWeight - currentWeight) * k

	if math.abs(currentWeight - targetWeight) < 0.001 then
		currentWeight = targetWeight
	end

	-- 1. Dynamic Wind & Gusting via Perlin noise, scaled by proximity to tower
	if currentWeight > 0.001 then
		local prox = Workspace:GetAttribute("WeatherTowerProximity") :: number? or 0
		local targetSpeed = lerp(20, 36, prox)
		local t = os.clock()
		local gust = math.noise(t * 0.45, 0, 0) -- organic gust variation
		local gustMult = 1 + gust * (0.3 + 0.15 * prox)
		local activeSpeed = targetSpeed * gustMult * currentWeight

		local rad = math.rad(State.WindAngleDeg)
		local windDir = Vector3.new(math.cos(rad), 0, math.sin(rad))
		Workspace.GlobalWind = windDir * activeSpeed

		-- 3. Move particle emitter with Camera
		local cam = Workspace.CurrentCamera
		if cam then
			local part = ensureEmitterPart()
			-- Offset slightly upwind of camera so particles drift through view
			local spawnOffset = -windDir * 12 + Vector3.new(0, -2, 0)
			part.CFrame = CFrame.new(cam.CFrame.Position + spawnOffset)
		end

		-- 4. Particle Rates scaled by tower proximity (faint on plots, heavy near tower)
		local pMult = if State.ParticlesEnabled then currentWeight else 0
		local particleAccel = windDir * activeSpeed * 0.45
		local mistTargetRate = lerp(1, 10, prox)
		local specksTargetRate = lerp(5, 24, prox)
		if mistEmitter then
			mistEmitter.Rate = mistTargetRate * pMult
			mistEmitter.Acceleration = particleAccel
		end
		if specksEmitter then
			specksEmitter.Rate = specksTargetRate * pMult
			specksEmitter.Acceleration = particleAccel * 1.5
		end

		-- 5. Audio scaled by proximity
		local audio = ensureAudio()
		if State.AudioEnabled and currentWeight > 0.01 then
			audio.Volume = lerp(0.18, 0.42, prox) * currentWeight
			if not audio.IsPlaying then
				audio:Play()
			end
		else
			audio.Volume = 0
			if audio.IsPlaying and currentWeight <= 0.01 then
				audio:Stop()
			end
		end
	else
		-- Fully disabled: restore defaults
		Workspace.GlobalWind = Vector3.new(0, 0, 0)
		if mistEmitter then mistEmitter.Rate = 0 end
		if specksEmitter then specksEmitter.Rate = 0 end
		if windSound and windSound.IsPlaying then
			windSound.Volume = 0
			windSound:Stop()
		end
	end
end

--============================================================================
-- PUBLIC API
--============================================================================
function FoggyWindController.Start()
	if isStarted then return end
	isStarted = true

	ensureEmitterPart()
	ensureAudio()
	removeClouds()
	Workspace.Terrain.ChildAdded:Connect(function(child)
		if child:IsA("Clouds") then
			task.defer(child.Destroy, child)
		end
	end)

	RunService.Heartbeat:Connect(onHeartbeat)
end

function FoggyWindController.SetEnabled(enabled: boolean)
	State.Enabled = enabled
end

function FoggyWindController.Toggle(): boolean
	State.Enabled = not State.Enabled
	return State.Enabled
end

function FoggyWindController.SetWindStrength(strength: number)
	State.WindStrength = math.clamp(strength, 0, 80)
end

function FoggyWindController.SetFogDensity(density: number)
	State.FogDensity = math.clamp(density, 0.05, 0.85)
end

function FoggyWindController.SetFogHaze(haze: number)
	State.FogHaze = math.clamp(haze, 0.1, 8.0)
end

function FoggyWindController.SetParticlesEnabled(enabled: boolean)
	State.ParticlesEnabled = enabled
end

function FoggyWindController.SetAudioEnabled(enabled: boolean)
	State.AudioEnabled = enabled
end

function FoggyWindController.GetConfig(): WeatherConfig
	return table.clone(State)
end

function FoggyWindController.GetCurrentWeight(): number
	return currentWeight
end

return FoggyWindController