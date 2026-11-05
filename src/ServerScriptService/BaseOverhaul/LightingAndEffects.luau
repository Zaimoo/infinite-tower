--!strict
-- LightingAndEffects.luau
-- ModuleScript: Configures Atmosphere, ColorCorrection, Bloom, SunRays, and Lighting. The server applies the
-- hopeful "Sanctuary" preset as the baseline everyone joins with; HubLightingController then blends each
-- player's view toward "Dread" near the tower or "Storm" on the tower floors (HubLighting presets).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLighting"))

local LightingAndEffects = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
LightingAndEffects.Config = table.clone(HubLighting.Presets.Sanctuary) :: { [string]: any }
LightingAndEffects.Config.ClockTime = HubLighting.ClockTime
LightingAndEffects.Config.Brightness = 1.65

--============================================================================
-- APPLY FUNCTION
--============================================================================
function LightingAndEffects.Apply(customConfig: { [string]: any }?)
	local cfg = table.clone(LightingAndEffects.Config)
	if customConfig then
		for k, v in pairs(customConfig) do
			(cfg :: any)[k] = v
		end
	end

	local lightingAny: any = Lighting
	pcall(function()
		lightingAny.Technology = Enum.Technology.Future
	end)
	pcall(function()
		lightingAny.LightingStyle = Enum.LightingStyle.Realistic
		lightingAny.PrioritizeLightingQuality = true
	end)
	Lighting.GlobalShadows = true

	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient
	Lighting.ColorShift_Top = cfg.ColorShift_Top
	Lighting.ColorShift_Bottom = cfg.ColorShift_Bottom
	Lighting.EnvironmentDiffuseScale = cfg.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = cfg.EnvironmentSpecularScale
	Lighting.ExposureCompensation = cfg.ExposureCompensation

	local atmosphere = Lighting:FindFirstChild("TowerStormAtmosphere") :: Atmosphere?
		or Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "TowerStormAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = cfg.AtmosphereDensity
	atmosphere.Offset = cfg.AtmosphereOffset
	atmosphere.Color = cfg.AtmosphereColor
	atmosphere.Decay = cfg.AtmosphereDecay
	atmosphere.Glare = cfg.AtmosphereGlare
	atmosphere.Haze = cfg.AtmosphereHaze

	local cc = Lighting:FindFirstChild("TowerStormColorCorrection") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TowerStormColorCorrection"
		cc.Parent = Lighting
	end
	cc.Enabled = true
	cc.TintColor = cfg.TintColor
	cc.Contrast = cfg.Contrast
	cc.Saturation = cfg.Saturation
	cc.Brightness = cfg.BrightnessOffset

	local bloom = Lighting:FindFirstChild("TowerStormBloom") :: BloomEffect?
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "TowerStormBloom"
		bloom.Parent = Lighting
	end
	bloom.Enabled = true
	bloom.Intensity = cfg.BloomIntensity
	bloom.Size = cfg.BloomSize
	bloom.Threshold = cfg.BloomThreshold

	local sunRays = Lighting:FindFirstChild("TowerStormSunRays") :: SunRaysEffect?
		or Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "TowerStormSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Enabled = true
	sunRays.Intensity = cfg.SunRaysIntensity
	sunRays.Spread = cfg.SunRaysSpread

	-- Rune Forest Skybox
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "RuneForestSky"
		sky.Parent = Lighting
	else
		sky.Name = "RuneForestSky"
	end
	sky.SkyboxBk = "rbxassetid://73287257796967"
	sky.SkyboxDn = "rbxassetid://95571517151564"
	sky.SkyboxFt = "rbxassetid://93852950520084"
	sky.SkyboxLf = "rbxassetid://73675662307776"
	sky.SkyboxRt = "rbxassetid://111303043418465"
	sky.SkyboxUp = "rbxassetid://84372379620971"
	sky.SunTextureId = "rbxasset://sky/sun.jpg"
	sky.MoonTextureId = "rbxasset://sky/moon.jpg"
	sky.SunAngularSize = 21
	sky.MoonAngularSize = 11
	sky.CelestialBodiesShown = true
	sky.StarCount = 3000

	-- Disable competing bloom/blur layers so glow does not stack.
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BloomEffect") and effect ~= bloom then
			effect.Enabled = false
		elseif effect:IsA("SunRaysEffect") and effect ~= sunRays then
			effect.Enabled = false
		elseif effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
			effect.Enabled = false
		end
	end
end

return LightingAndEffects
