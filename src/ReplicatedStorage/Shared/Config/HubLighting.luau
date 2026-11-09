--!strict
-- HubLighting.luau
-- Lighting presets and where each applies (GDD §3.6). The plots and the Cloister Commons sit in a warm,
-- hopeful "Sanctuary" light; the Crimson Tower and its causeway sink into a dark "Dread" light; the
-- off-map tower floors keep the original "Storm" grade. The server applies Sanctuary as the baseline
-- (LightingAndEffects); each client blends by where its character stands (HubLightingController).
-- Brightness is left to the player's Settings slider, so presets shift ExposureCompensation instead.

local HubLighting = {}

export type Preset = {
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ColorShift_Top: Color3,
	ColorShift_Bottom: Color3,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	ExposureCompensation: number,

	AtmosphereDensity: number,
	AtmosphereOffset: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereGlare: number,
	AtmosphereHaze: number,

	TintColor: Color3,
	Contrast: number,
	Saturation: number,
	BrightnessOffset: number,

	BloomIntensity: number,
	BloomSize: number,
	BloomThreshold: number,

	SunRaysIntensity: number,
	SunRaysSpread: number,
}

HubLighting.ClockTime = 14.8 -- Shared by every preset so the sun never swings while blending

local Presets: { [string]: Preset } = {
	-- Hub & Fortress Plots: cool slate-blue moonlight contrasting with warm orange wall torches (image_8b03db.jpg)
	Sanctuary = {
		Ambient = Color3.fromRGB(58, 66, 80),
		OutdoorAmbient = Color3.fromRGB(68, 78, 96),
		ColorShift_Top = Color3.fromRGB(205, 215, 230),
		ColorShift_Bottom = Color3.fromRGB(100, 110, 125),
		EnvironmentDiffuseScale = 0.65,
		EnvironmentSpecularScale = 0.55,
		ExposureCompensation = 0.1,

		AtmosphereDensity = 0.35,
		AtmosphereOffset = 0,
		AtmosphereColor = Color3.fromRGB(18, 16, 24),
		AtmosphereDecay = Color3.fromRGB(12, 10, 16),
		AtmosphereGlare = 0,
		AtmosphereHaze = 1.5,

		TintColor = Color3.fromRGB(240, 245, 252),
		Contrast = 0.08,
		Saturation = -0.10,
		BrightnessOffset = 0.01,

		BloomIntensity = 0.45,
		BloomSize = 24,
		BloomThreshold = 1.05,

		SunRaysIntensity = 0,
		SunRaysSpread = 0,
	},
	-- The tower's shadow: intense heavy mist, deep storm murk, high fog density wrapping the tower
	Dread = {
		Ambient = Color3.fromRGB(38, 24, 30),
		OutdoorAmbient = Color3.fromRGB(68, 42, 50),
		ColorShift_Top = Color3.fromRGB(160, 60, 60),
		ColorShift_Bottom = Color3.fromRGB(34, 20, 30),
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 0.45,
		ExposureCompensation = -0.3,

		AtmosphereDensity = 0.85,
		AtmosphereOffset = 0,
		AtmosphereColor = Color3.fromRGB(60, 40, 48),
		AtmosphereDecay = Color3.fromRGB(30, 16, 22),
		AtmosphereGlare = 0,
		AtmosphereHaze = 4.2,

		TintColor = Color3.fromRGB(250, 205, 210),
		Contrast = 0.16,
		Saturation = -0.22,
		BrightnessOffset = -0.03,

		BloomIntensity = 0.75,
		BloomSize = 30,
		BloomThreshold = 0.95,

		SunRaysIntensity = 0,
		SunRaysSpread = 0,
	},
	-- Off-map tower floors: the original moody storm grade, unchanged
	Storm = {
		Ambient = Color3.fromRGB(38, 44, 58),
		OutdoorAmbient = Color3.fromRGB(62, 72, 90),
		ColorShift_Top = Color3.fromRGB(165, 180, 210),
		ColorShift_Bottom = Color3.fromRGB(48, 56, 74),
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.65,
		ExposureCompensation = 0,

		AtmosphereDensity = 0.24,
		AtmosphereOffset = 0.08,
		AtmosphereColor = Color3.fromRGB(115, 125, 140),
		AtmosphereDecay = Color3.fromRGB(68, 76, 92),
		AtmosphereGlare = 0,
		AtmosphereHaze = 0.45,

		TintColor = Color3.fromRGB(238, 242, 252),
		Contrast = 0.08,
		Saturation = 0.06,
		BrightnessOffset = 0,

		BloomIntensity = 0.42,
		BloomSize = 24,
		BloomThreshold = 1.15,

		SunRaysIntensity = 0,
		SunRaysSpread = 0,
	},
	-- Misty/windy moor: dense atmospheric fog, cool desaturated light, heavy horizon haze
	FoggyWind = {
		Ambient = Color3.fromRGB(72, 78, 88),
		OutdoorAmbient = Color3.fromRGB(108, 118, 130),
		ColorShift_Top = Color3.fromRGB(175, 185, 200),
		ColorShift_Bottom = Color3.fromRGB(88, 98, 112),
		EnvironmentDiffuseScale = 0.5,
		EnvironmentSpecularScale = 0.45,
		ExposureCompensation = 0.05,

		AtmosphereDensity = 0.79,
		AtmosphereOffset = 0.05,
		AtmosphereColor = Color3.fromRGB(170, 180, 192),
		AtmosphereDecay = Color3.fromRGB(115, 125, 138),
		AtmosphereGlare = 0,
		AtmosphereHaze = 3.2,

		TintColor = Color3.fromRGB(225, 235, 245),
		Contrast = 0.08,
		Saturation = -0.15,
		BrightnessOffset = 0,

		BloomIntensity = 0.35,
		BloomSize = 20,
		BloomThreshold = 1.1,

		SunRaysIntensity = 0,
		SunRaysSpread = 0,
	},
}
HubLighting.Presets = Presets

-- Dread fades in between these distances from the tower centre: full on the walkway ring (R 375 ± 11),
-- none by the Cloister's south edge (R 476) and beyond, so the causeway walk is the transition.
HubLighting.DreadFullRadius = 395
HubLighting.DreadNoneRadius = 470
HubLighting.FloorsBeyond = 6000 -- Off-map tower floors start at X, Z >= 12000

-- Returns the preset name a position sits in, and the Dread weight (0..1) when in the hub.
function HubLighting.Classify(x: number, z: number): (string, number)
	if x >= HubLighting.FloorsBeyond or z >= HubLighting.FloorsBeyond then
		return "Storm", 0
	end
	local d = math.sqrt(x * x + z * z)
	local t = math.clamp((HubLighting.DreadNoneRadius - d) / (HubLighting.DreadNoneRadius - HubLighting.DreadFullRadius), 0, 1)
	return "Hub", t * t * (3 - 2 * t) -- smoothstep
end

return HubLighting
