--!strict
-- StarterPlayerScripts/Rendering/HubLightingController.client.luau
-- Blends this player's lighting by where their character stands (HubLighting): warm "Sanctuary" light on
-- the plots and the Masters' Commons, crimson "Dread" as they cross the causeway to the tower, and the
-- original "Storm" grade on the off-map tower floors. Lighting changes made here are local to this client.

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

-- Target weights: how much Dread and how much Storm the current position calls for.
local function targetWeights(): (number, number)
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
		return 0, 1
	end
	return dread, 0
end

local dreadW, stormW = targetWeights()
local lastDread, lastStorm = -1, -1

-- Colour FX switched: re-apply on the next step even if the player has not moved
Lighting:GetAttributeChangedSignal(COLOR_FX_ATTRIBUTE):Connect(function()
	lastDread, lastStorm = -1, -1
end)

local function stepHubLighting(dt: number)
	local wantDread, wantStorm = targetWeights()
	local k = 1 - math.exp(-BLEND_RATE * dt)
	dreadW += (wantDread - dreadW) * k
	stormW += (wantStorm - stormW) * k

	if math.abs(dreadW - lastDread) < 0.002 and math.abs(stormW - lastStorm) < 0.002 then
		return
	end
	lastDread, lastStorm = dreadW, stormW

	-- Publish dread weight (tower proximity) for VFX/wind scaling
	workspace:SetAttribute("WeatherTowerProximity", dreadW)

	local hub = mix(Presets.Sanctuary, Presets.Dread, dreadW)
	apply(mix(hub, Presets.Storm, stormW))
end
-- Heartbeat, not RenderStepped: nothing here tracks the camera or a moving character, so it need not hold up the frame
RunService.Heartbeat:Connect(function(dt: number)
	debug.profilebegin("HubLighting")
	stepHubLighting(dt)
	debug.profileend()
end)
