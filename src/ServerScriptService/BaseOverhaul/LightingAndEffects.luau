--!strict
-- LightingAndEffects.luau
-- ModuleScript: Configures Atmosphere, ColorCorrection, Bloom, SunRays, and Lighting. The server applies the
-- hopeful "Sanctuary" preset as the baseline everyone joins with; HubLightingController then blends each
-- player's view toward "Dread" near the tower or "Storm" on the tower floors (HubLighting presets).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLighting"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SettingsConfig"))

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

	-- Roblox's unified lighting replaced Lighting.Technology with LightingStyle + PrioritizeLightingQuality;
	-- lighting quality now follows each player's graphics level. The place file's own
	-- PrioritizeLightingQuality can win over the write below, so untick it in Studio too.
	local lightingAny: any = Lighting
	-- Separate pcalls: LightingStyle may be locked to plugins too, and a throw there must not skip the rest
	pcall(function()
		lightingAny.LightingStyle = Enum.LightingStyle.Realistic
	end)
	pcall(function()
		-- false lets lower graphics levels scale lighting down; at high quality nothing changes
		lightingAny.PrioritizeLightingQuality = false
	end)
	-- Baseline for everyone; each client then applies its own Settings choice (default off)
	Lighting.GlobalShadows = SettingsConfig.DEFAULTS.GlobalShadows

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
	atmosphere.Density = cfg.AtmosphereDensity or 0.35
	atmosphere.Offset = cfg.AtmosphereOffset or 0
	atmosphere.Color = cfg.AtmosphereColor or Color3.fromRGB(18, 16, 24)
	atmosphere.Decay = cfg.AtmosphereDecay or Color3.fromRGB(12, 10, 16)
	atmosphere.Glare = 0 -- Keep glare 0 to eliminate radial blooming and crepuscular streaks
	atmosphere.Haze = cfg.AtmosphereHaze or 1.5

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

	-- Disable and destroy any SunRaysEffect to prevent crisscrossing light shafts / god rays
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("SunRaysEffect") then
			effect.Enabled = false
			effect.Intensity = 0
			effect:Destroy()
		end
	end

	-- Sunset Skybox
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "SunsetSky"
		sky.Parent = Lighting
	else
		sky.Name = "SunsetSky"
	end
	sky.SkyboxBk = "rbxassetid://600830446"
	sky.SkyboxDn = "rbxassetid://600831635"
	sky.SkyboxFt = "rbxassetid://600832720"
	sky.SkyboxLf = "rbxassetid://600886090"
	sky.SkyboxRt = "rbxassetid://600833862"
	sky.SkyboxUp = "rbxassetid://600835177"
	sky.SunTextureId = "rbxasset://sky/sun.jpg"
	sky.MoonTextureId = "rbxasset://sky/moon.jpg"
	sky.SunAngularSize = 21
	sky.MoonAngularSize = 11
	sky.CelestialBodiesShown = true
	sky.StarCount = 3000

	-- Disable competing bloom/blur layers and eliminate any SunRays
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BloomEffect") and effect ~= bloom then
			effect.Enabled = false
		elseif effect:IsA("SunRaysEffect") then
			effect.Enabled = false
			effect.Intensity = 0
			effect:Destroy()
		elseif effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
			effect.Enabled = false
		end
	end
end

return LightingAndEffects
