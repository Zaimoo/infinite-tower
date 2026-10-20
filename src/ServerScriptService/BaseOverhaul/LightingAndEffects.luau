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
	ClockTime = 17.3,
	Brightness = 2.4,
	Ambient = Color3.fromRGB(112, 98, 104),
	OutdoorAmbient = Color3.fromRGB(145, 122, 128),
	ColorShift_Top = Color3.fromRGB(225, 155, 160),
	ColorShift_Bottom = Color3.fromRGB(105, 42, 50),
	EnvironmentDiffuseScale = 0.75,
	EnvironmentSpecularScale = 0.80,

	-- Atmosphere (Dark Red Storm Horizon & Haze)
	AtmosphereDensity = 0.08,
	AtmosphereOffset = 0.12,
	AtmosphereColor = Color3.fromRGB(135, 34, 44),
	AtmosphereDecay = Color3.fromRGB(52, 16, 22),
	AtmosphereGlare = 0,
	AtmosphereHaze = 0,

	-- ColorCorrection (Subtle contrast + warm crimson tint without washing out UI/Gameplay)
	TintColor = Color3.fromRGB(255, 240, 242),
	Contrast = 0.07,
	Saturation = 0.05,
	BrightnessOffset = 0.03,

	-- Bloom (Makes the white fountain water and dull-red tower windows pop)
	BloomIntensity = 0,
	BloomSize = 10,
	BloomThreshold = 1.5,
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
 -- Keep one subtle bloom layer so glow does not stack.
 for _, effect in Lighting:GetChildren() do
  if effect:IsA("BloomEffect") and effect ~= bloom then
   effect.Enabled = false
  elseif effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") then
   effect.Enabled = false
  end
 end
	bloom.Enabled = false
	bloom.Intensity = cfg.BloomIntensity
	bloom.Size = cfg.BloomSize
	bloom.Threshold = cfg.BloomThreshold
end

return LightingAndEffects
