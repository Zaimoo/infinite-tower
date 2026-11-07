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
		atmosphere.Density = p.AtmosphereDensity
		atmosphere.Offset = p.AtmosphereOffset
		atmosphere.Color = p.AtmosphereColor
		atmosphere.Decay = p.AtmosphereDecay
		atmosphere.Glare = p.AtmosphereGlare
		atmosphere.Haze = p.AtmosphereHaze
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
	local rays = effect("SunRaysEffect", "TowerStormSunRays") :: SunRaysEffect?
	if rays then
		if p.SunRaysIntensity > 0.005 then
			rays.Enabled = true
			rays.Intensity = p.SunRaysIntensity
			rays.Spread = p.SunRaysSpread
		else
			rays.Enabled = false
			rays.Intensity = 0
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
local weatherW = 0
local lastDread, lastStorm, lastWeather = -1, -1, -1

local function stepHubLighting(dt: number)
	local wantDread, wantStorm = targetWeights()
	local wantWeather = math.clamp(workspace:GetAttribute("WeatherFoggyWindWeight") :: number? or 0, 0, 1)

	local k = 1 - math.exp(-BLEND_RATE * dt)
	dreadW += (wantDread - dreadW) * k
	stormW += (wantStorm - stormW) * k
	weatherW += (wantWeather - weatherW) * k

	local customDensity = workspace:GetAttribute("WeatherFogDensity") :: number?
	local customHaze = workspace:GetAttribute("WeatherFogHaze") :: number?

	if math.abs(dreadW - lastDread) < 0.002 and math.abs(stormW - lastStorm) < 0.002 and math.abs(weatherW - lastWeather) < 0.002 and not customDensity and not customHaze then
		return
	end
	lastDread, lastStorm, lastWeather = dreadW, stormW, weatherW
	local hub = mix(Presets.Sanctuary, Presets.Dread, dreadW)
	local base = mix(hub, Presets.Storm, stormW)

	local finalPreset = base
	if Presets.FoggyWind and weatherW > 0.001 then
		local foggyPreset = Presets.FoggyWind
		if customDensity or customHaze then
			foggyPreset = table.clone(Presets.FoggyWind)
			if customDensity then
				foggyPreset.AtmosphereDensity = customDensity
			end
			if customHaze then
				foggyPreset.AtmosphereHaze = customHaze
			end
		end
		finalPreset = mix(base, foggyPreset, weatherW)
	end

	apply(finalPreset)
end
RunService.RenderStepped:Connect(function(dt: number)
	debug.profilebegin("HubLighting")
	stepHubLighting(dt)
	debug.profileend()
end)
