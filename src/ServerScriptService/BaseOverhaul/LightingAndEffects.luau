--!strict
-- LightingAndEffects.luau
-- ModuleScript: Configures Atmosphere, ColorCorrection, Bloom, and Lighting to create
-- a dark crimson storm mood around the central Tower while keeping player islands and UI readable.

local Lighting = game:GetService("Lighting")

local LightingAndEffects = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
LightingAndEffects.Config = {
	-- Core Lighting Properties (Readable gameplay + dramatic crimson-horizon storm)
	ClockTime = 17.3, -- Late afternoon/dusk so island stone and tower architecture stay crisp & readable
	Brightness = 2.4,
	Ambient = Color3.fromRGB(112, 98, 104), -- Balanced ambient so dark stone plots remain readable
	OutdoorAmbient = Color3.fromRGB(145, 122, 128),
	ColorShift_Top = Color3.fromRGB(225, 155, 160),
	ColorShift_Bottom = Color3.fromRGB(105, 42, 50),
	EnvironmentDiffuseScale = 0.75,
	EnvironmentSpecularScale = 0.80,

	-- Atmosphere (Dark Red Storm Horizon & Haze)
	AtmosphereDensity = 0.28, -- Low enough to see the 860-stud tower clearly from the islands
	AtmosphereOffset = 0.12,
	AtmosphereColor = Color3.fromRGB(135, 34, 44), -- Crimson storm tint in the distance
	AtmosphereDecay = Color3.fromRGB(52, 16, 22), -- Deep dark red/black decay
	AtmosphereGlare = 0.30,
	AtmosphereHaze = 1.55,

	-- ColorCorrection (Subtle contrast + warm crimson tint without washing out UI/Gameplay)
	TintColor = Color3.fromRGB(255, 240, 242),
	Contrast = 0.07,
	Saturation = 0.05,
	BrightnessOffset = 0.03,

	-- Bloom (Makes the white fountain water and dull-red tower windows pop)
	BloomIntensity = 0.45,
	BloomSize = 22,
	BloomThreshold = 0.95,
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

	-- 1. Core Lighting
	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient
	Lighting.ColorShift_Top = cfg.ColorShift_Top
	Lighting.ColorShift_Bottom = cfg.ColorShift_Bottom
	Lighting.EnvironmentDiffuseScale = cfg.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = cfg.EnvironmentSpecularScale

	-- 2. Atmosphere
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

	-- 3. ColorCorrectionEffect
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

	-- 4. BloomEffect
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
end

return LightingAndEffects
