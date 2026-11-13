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

		BloomIntensity = 0.25,
		BloomSize = 24,
		BloomThreshold = 1.25,

		SunRaysIntensity = 0,
		SunRaysSpread = 0,
	},
	-- The tower's shadow: crimson murk and mist around the tower, lit enough that the Master, their heroes and the
	-- causeway stay readable (the earlier grade, exposure -0.3 with dense haze, left the walkway near black).
	Dread = {
		Ambient = Color3.fromRGB(92, 70, 76),
		OutdoorAmbient = Color3.fromRGB(128, 98, 104),
		ColorShift_Top = Color3.fromRGB(200, 110, 105),
		ColorShift_Bottom = Color3.fromRGB(70, 48, 56),
		EnvironmentDiffuseScale = 0.55,
		EnvironmentSpecularScale = 0.45,
		ExposureCompensation = 0.05,

		AtmosphereDensity = 0.5,
		AtmosphereOffset = 0,
		AtmosphereColor = Color3.fromRGB(110, 72, 80),
		AtmosphereDecay = Color3.fromRGB(60, 34, 42),
		AtmosphereGlare = 0,
		AtmosphereHaze = 2.4,

		TintColor = Color3.fromRGB(255, 225, 228),
		Contrast = 0.10,
		Saturation = -0.12,
		BrightnessOffset = 0.02,

		BloomIntensity = 0.35,
		BloomSize = 28,
		BloomThreshold = 1.2,

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

		BloomIntensity = 0.3,
		BloomSize = 24,
		BloomThreshold = 1.25,

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

		BloomIntensity = 0.25,
		BloomSize = 20,
		BloomThreshold = 1.25,

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
