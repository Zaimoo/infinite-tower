--!strict
-- StarterPlayerScripts/Rendering/HubLightingController.client.luau
-- Blends this player's lighting by where their character stands (HubLighting): warm "Sanctuary" light on
-- the plots and the Masters' Commons, crimson "Dread" as they cross the causeway to the tower, and the
-- "Storm" grade on the off-map tower floors, tinted per biome (HubLighting.TowerPreset). Lighting changes
-- made here are local to this client.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLighting"))

type Preset = HubLighting.Preset

local LocalPlayer = Players.LocalPlayer
local Presets = HubLighting.Presets

local BLEND_RATE = 2.5 -- per second; ~1 s to settle after a step change such as a teleport

-- With Colour FX off (Settings, e.g. Max Performance) the Atmosphere is thinned to this wherever the player is.
-- SettingsGraphicsEngine sets the Lighting attribute; this script is the only one that writes the Atmosphere.
local COLOR_FX_ATTRIBUTE = "SettingsColorFX"
local REDUCED_ATMOSPHERE_DENSITY = 0.10
local REDUCED_ATMOSPHERE_HAZE = 0

local function colorFXEnabled(): boolean
	return Lighting:GetAttribute(COLOR_FX_ATTRIBUTE) ~= false
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Linear blend of every preset field (numbers and Color3s).
local function mix(a: Preset, b: Preset, t: number): Preset
	local out = {}
	for key, av in a :: any do
		local bv = (b :: any)[key]
		out[key] = if typeof(av) == "Color3" then (av :: Color3):Lerp(bv, t) else lerp(av, bv, t)
	end
	return out :: any
end

-- The effect LightingAndEffects drives: the named one if present, else the first enabled one of that class.
-- The Settings menu's own effects ("Settings*") are left alone.
local function effect<T>(className: string, name: string): T?
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return found :: any
	end
	for _, child in Lighting:GetChildren() do
		if child.ClassName == className and string.sub(child.Name, 1, 8) ~= "Settings" then
			if not child:IsA("PostEffect") or child.Enabled then
				return child :: any
			end
		end
	end
	return nil
end

local function apply(p: Preset)
	Lighting.Ambient = p.Ambient
	Lighting.OutdoorAmbient = p.OutdoorAmbient
	Lighting.ColorShift_Top = p.ColorShift_Top
	Lighting.ColorShift_Bottom = p.ColorShift_Bottom
	Lighting.EnvironmentDiffuseScale = p.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = p.EnvironmentSpecularScale
	Lighting.ExposureCompensation = p.ExposureCompensation

	local atmosphere = effect("Atmosphere", "TowerStormAtmosphere") :: Atmosphere?
	if atmosphere then
		local full = colorFXEnabled()
		atmosphere.Density = if full then p.AtmosphereDensity else REDUCED_ATMOSPHERE_DENSITY
		atmosphere.Offset = p.AtmosphereOffset
		atmosphere.Color = p.AtmosphereColor
		atmosphere.Decay = p.AtmosphereDecay
		atmosphere.Glare = 0 -- Keep glare 0 to eliminate harsh directional ray bloom
		atmosphere.Haze = if full then p.AtmosphereHaze else REDUCED_ATMOSPHERE_HAZE
	end
	local cc = effect("ColorCorrectionEffect", "TowerStormColorCorrection") :: ColorCorrectionEffect?
	if cc then
		cc.TintColor = p.TintColor
		cc.Contrast = p.Contrast
		cc.Saturation = p.Saturation
		cc.Brightness = p.BrightnessOffset
	end
	local bloom = effect("BloomEffect", "TowerStormBloom") :: BloomEffect?
	if bloom then
		bloom.Intensity = p.BloomIntensity
		bloom.Size = p.BloomSize
		bloom.Threshold = p.BloomThreshold
	end
	-- Destroy any SunRaysEffect to prevent crepuscular light shafts across walls/abyss
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("SunRaysEffect") then
			child.Enabled = false
			child.Intensity = 0
			child:Destroy()
		end
	end
end

-- Target weights: how much Dread and how much Storm the current position calls for, and on a tower floor
-- the floor whose biome (and own floor) grade tints Storm (HubLighting.TowerPreset).
local function targetWeights(): (number, number, number?)
	local pos: Vector3
	if _G.IsViewingSquad and _G.IsViewingSquad() then
		local cam = workspace.CurrentCamera
		pos = if cam then cam.CFrame.Position else Vector3.new(12000, 1000, 12000)
	else
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		pos = if root then root.Position else workspace.CurrentCamera.Focus.Position
	end
	local zone, dread = HubLighting.Classify(pos.X, pos.Z)
	if zone == "Storm" then
		return 0, 1, HubLighting.TowerFloorAt(pos.X, pos.Z)
	end
	return dread, 0, nil
end

local dreadW, stormW, startFloor = targetWeights()

-- A floor's grade: its biome's, with the floor's own over it when it has one (HubLighting.FloorGrades).
local function floorPreset(floorId: number?): Preset
	return HubLighting.TowerPreset(if floorId then math.ceil(floorId / 5) else nil, floorId)
end

local lastDread, lastStorm = -1, -1
-- The tower grade in use, blended from the previous floor's toward the current one's (towerT 0 -> 1).
local towerFrom: Preset = floorPreset(startFloor)
local towerTo: Preset = towerFrom
local towerT = 1

-- Colour FX switched: re-apply on the next step even if the player has not moved
Lighting:GetAttributeChangedSignal(COLOR_FX_ATTRIBUTE):Connect(function()
	lastDread, lastStorm = -1, -1
end)

local function stepHubLighting(dt: number)
	local wantDread, wantStorm, wantFloor = targetWeights()
	local k = 1 - math.exp(-BLEND_RATE * dt)
	dreadW += (wantDread - dreadW) * k
	stormW += (wantStorm - stormW) * k

	-- Off the floors the grade keeps its last floor's, so leaving a floor fades out from that floor's look.
	-- Presets are cached, so floors that share a grade (most of a biome) don't restart the blend.
	local wantGrade = if wantFloor then floorPreset(wantFloor) else nil
	if wantGrade and wantGrade ~= towerTo then
		towerFrom = if towerT >= 1 then towerTo else mix(towerFrom, towerTo, towerT)
		towerTo = wantGrade
		towerT = 0
	end
	local gradeMoving = towerT < 1
	if gradeMoving then
		towerT = math.min(1, towerT + k * (1 - towerT) + dt * 0.05)
		if towerT > 0.998 then
			towerT = 1
		end
	end

	if not gradeMoving and math.abs(dreadW - lastDread) < 0.002 and math.abs(stormW - lastStorm) < 0.002 then
		return
	end
	lastDread, lastStorm = dreadW, stormW

	-- Publish dread weight (tower proximity) for VFX/wind scaling
	workspace:SetAttribute("WeatherTowerProximity", dreadW)

	local hub = mix(Presets.Sanctuary, Presets.Dread, dreadW)
	local tower = if towerT >= 1 then towerTo else mix(towerFrom, towerTo, towerT)
	apply(mix(hub, tower, stormW))
end
-- Heartbeat, not RenderStepped: nothing here tracks the camera or a moving character, so it need not hold up the frame
RunService.Heartbeat:Connect(function(dt: number)
	debug.profilebegin("HubLighting")
	stepHubLighting(dt)
	debug.profileend()
end)
