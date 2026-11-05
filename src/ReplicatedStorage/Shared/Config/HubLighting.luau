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
	-- Golden afternoon over the fortresses: warm sun, soft blue bounce light, clear air, gentle glow
	Sanctuary = {
		Ambient = Color3.fromRGB(96, 90, 82),
		OutdoorAmbient = Color3.fromRGB(152, 142, 124),
		ColorShift_Top = Color3.fromRGB(255, 228, 176),
		ColorShift_Bottom = Color3.fromRGB(120, 142, 176),
		EnvironmentDiffuseScale = 0.9,
		EnvironmentSpecularScale = 0.8,
		ExposureCompensation = 0.3,

		AtmosphereDensity = 0.12,
		AtmosphereOffset = 0,
		AtmosphereColor = Color3.fromRGB(214, 210, 200),
		AtmosphereDecay = Color3.fromRGB(128, 164, 220),
		AtmosphereGlare = 0,
		AtmosphereHaze = 0,

		TintColor = Color3.fromRGB(255, 247, 234),
		Contrast = 0.05,
		Saturation = 0.18,
		BrightnessOffset = 0.03,

		BloomIntensity = 0.55,
		BloomSize = 28,
		BloomThreshold = 1.05,

		SunRaysIntensity = 0.16,
		SunRaysSpread = 0.8,
	},
	-- The tower's shadow: crimson murk, drained colour, heavy haze, red glows that bloom
	Dread = {
		Ambient = Color3.fromRGB(34, 18, 24),
		OutdoorAmbient = Color3.fromRGB(66, 34, 42),
		ColorShift_Top = Color3.fromRGB(160, 60, 60),
		ColorShift_Bottom = Color3.fromRGB(34, 20, 30),
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 0.5,
		ExposureCompensation = -0.45,

		AtmosphereDensity = 0.42,
		AtmosphereOffset = 0,
		AtmosphereColor = Color3.fromRGB(78, 30, 36),
		AtmosphereDecay = Color3.fromRGB(32, 12, 18),
		AtmosphereGlare = 0,
		AtmosphereHaze = 1.6,

		TintColor = Color3.fromRGB(255, 212, 212),
		Contrast = 0.18,
		Saturation = -0.2,
		BrightnessOffset = -0.04,

		BloomIntensity = 0.75,
		BloomSize = 30,
		BloomThreshold = 0.95,

		SunRaysIntensity = 0.04,
		SunRaysSpread = 0.5,
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
		AtmosphereGlare = 0.15,
		AtmosphereHaze = 0.45,

		TintColor = Color3.fromRGB(238, 242, 252),
		Contrast = 0.08,
		Saturation = 0.06,
		BrightnessOffset = 0,

		BloomIntensity = 0.42,
		BloomSize = 24,
		BloomThreshold = 1.15,

		SunRaysIntensity = 0.09,
		SunRaysSpread = 0.7,
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
