--!strict
-- LightingAndEffects.luau
-- ModuleScript: Configures Atmosphere, ColorCorrection, Bloom, SunRays, and Lighting to create
-- a rich, readable, atmospheric mood around the central Tower while keeping gameplay clear.

local Lighting = game:GetService("Lighting")

local LightingAndEffects = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
LightingAndEffects.Config = {
	-- Core Lighting Properties (Phase 4.1 Atmospheric Moody Contrast)
	ClockTime = 14.8,
	Brightness = 1.65,
	Ambient = Color3.fromRGB(38, 44, 58),
	OutdoorAmbient = Color3.fromRGB(62, 72, 90),
	ColorShift_Top = Color3.fromRGB(165, 180, 210),
	ColorShift_Bottom = Color3.fromRGB(48, 56, 74),
	EnvironmentDiffuseScale = 0.60,
	EnvironmentSpecularScale = 0.65,

	-- Atmosphere (Phase 4.1 Gothic Mist & Distant Horizon)
	AtmosphereDensity = 0.24,
	AtmosphereOffset = 0.08,
	AtmosphereColor = Color3.fromRGB(115, 125, 140),
	AtmosphereDecay = Color3.fromRGB(68, 76, 92),
	AtmosphereGlare = 0.15,
	AtmosphereHaze = 0.45,

	-- ColorCorrection (Subtle contrast + balanced tone without washing out UI/Gameplay)
	TintColor = Color3.fromRGB(238, 242, 252),
	Contrast = 0.08,
	Saturation = 0.06,
	BrightnessOffset = 0.0,

	-- Bloom (Subtle cinematic glow clamped so standard materials and liquid blocks never blow out)
	BloomIntensity = 0.42,
	BloomSize = 24,
	BloomThreshold = 1.15,

	-- SunRays (Natural environmental atmospheric godrays through skylights and canopy)
	SunRaysIntensity = 0.09,
	SunRaysSpread = 0.70,
}

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
