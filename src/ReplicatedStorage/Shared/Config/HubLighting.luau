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

-- Tower floor grades (GDD §3.6): on a tower floor the Storm preset takes its biome's light and air, so
-- each biome reads at a glance (golden jungle haze, bioluminescent blue, ash glare, cold clear blue...).
-- Indexed by biome (1 = Verdant Ruins ... 10 = Abyssal Throne, TowerFloorConfig order); only the listed
-- fields change, the rest stay Storm's. Rooms sit on the off-map grid of TowerRoomBuilder.Origin.
local c = Color3.fromRGB
local BiomeGrades: { { [string]: any } } = {
	{ -- Verdant Ruins: warm sun through a jungle canopy
		Ambient = c(58, 74, 58), OutdoorAmbient = c(90, 116, 92), ColorShift_Top = c(240, 245, 210), ColorShift_Bottom = c(56, 84, 62),
		AtmosphereDensity = 0.24, AtmosphereColor = c(150, 190, 160), AtmosphereDecay = c(84, 124, 98), AtmosphereHaze = 0.5,
		TintColor = c(246, 255, 240), Saturation = 0.2, ExposureCompensation = 0,
	},
	{ -- Fungal Hollow: deep blue cavern, glowing caps
		Ambient = c(40, 48, 82), OutdoorAmbient = c(56, 66, 110), ColorShift_Top = c(150, 190, 255), ColorShift_Bottom = c(40, 30, 80),
		AtmosphereDensity = 0.3, AtmosphereColor = c(60, 70, 130), AtmosphereDecay = c(40, 40, 90), AtmosphereHaze = 0.8,
		TintColor = c(225, 235, 255), Saturation = 0.15, ExposureCompensation = -0.05, BloomIntensity = 0.45,
	},
	{ -- Ashen Dunes: hot orange dust
		Ambient = c(78, 54, 44), OutdoorAmbient = c(120, 82, 62), ColorShift_Top = c(255, 190, 130), ColorShift_Bottom = c(90, 50, 36),
		AtmosphereDensity = 0.36, AtmosphereColor = c(190, 120, 80), AtmosphereDecay = c(130, 70, 40), AtmosphereHaze = 1.6,
		TintColor = c(255, 236, 215), Saturation = 0.05,
	},
	{ -- Frozen Citadel: cold, clear blue
		Ambient = c(70, 88, 112), OutdoorAmbient = c(110, 135, 165), ColorShift_Top = c(210, 235, 255), ColorShift_Bottom = c(80, 100, 130),
		AtmosphereDensity = 0.30, AtmosphereColor = c(190, 215, 240), AtmosphereDecay = c(120, 150, 190), AtmosphereHaze = 1.0,
		TintColor = c(232, 244, 255), Saturation = -0.05, ExposureCompensation = 0.1,
	},
	{ -- Infernal Foundry: forge glow
		Ambient = c(82, 44, 36), OutdoorAmbient = c(110, 58, 44), ColorShift_Top = c(255, 150, 90), ColorShift_Bottom = c(90, 30, 20),
		AtmosphereDensity = 0.34, AtmosphereColor = c(120, 52, 36), AtmosphereDecay = c(110, 40, 20), AtmosphereHaze = 1.4,
		TintColor = c(255, 228, 210), Saturation = 0.1, BloomIntensity = 0.45,
	},
	{ -- Thunder Highlands: storm light
		Ambient = c(54, 58, 86), OutdoorAmbient = c(86, 92, 130), ColorShift_Top = c(190, 195, 255), ColorShift_Bottom = c(52, 56, 90),
		AtmosphereDensity = 0.32, AtmosphereColor = c(120, 125, 170), AtmosphereDecay = c(70, 72, 120), AtmosphereHaze = 1.1,
		TintColor = c(232, 236, 255), Saturation = 0, Contrast = 0.12,
	},
	{ -- Corrupted Grove: magenta murk
		Ambient = c(64, 38, 66), OutdoorAmbient = c(96, 58, 96), ColorShift_Top = c(240, 150, 220), ColorShift_Bottom = c(60, 30, 60),
		AtmosphereDensity = 0.38, AtmosphereColor = c(110, 60, 105), AtmosphereDecay = c(80, 30, 80), AtmosphereHaze = 1.3,
		TintColor = c(250, 232, 248), Saturation = 0.08,
	},
	{ -- Sunken Sanctuary: aqua caustics
		Ambient = c(48, 84, 92), OutdoorAmbient = c(80, 130, 140), ColorShift_Top = c(170, 240, 255), ColorShift_Bottom = c(40, 90, 110),
		AtmosphereDensity = 0.34, AtmosphereColor = c(90, 170, 180), AtmosphereDecay = c(40, 120, 140), AtmosphereHaze = 1.0,
		TintColor = c(228, 250, 255), Saturation = 0.1,
	},
	{ -- Astral Archives: indigo starlight
		Ambient = c(50, 54, 96), OutdoorAmbient = c(80, 86, 140), ColorShift_Top = c(190, 200, 255), ColorShift_Bottom = c(50, 50, 110),
		AtmosphereDensity = 0.26, AtmosphereColor = c(70, 80, 150), AtmosphereDecay = c(50, 50, 120), AtmosphereHaze = 0.7,
		TintColor = c(236, 238, 255), Saturation = 0.1, BloomIntensity = 0.45,
	},
	{ -- Abyssal Throne: violet void
		Ambient = c(44, 36, 62), OutdoorAmbient = c(64, 54, 92), ColorShift_Top = c(180, 140, 255), ColorShift_Bottom = c(30, 40, 60),
		AtmosphereDensity = 0.40, AtmosphereColor = c(50, 40, 80), AtmosphereDecay = c(30, 60, 80), AtmosphereHaze = 1.4,
		TintColor = c(240, 232, 255), Saturation = 0.05, ExposureCompensation = -0.05,
	},
}
HubLighting.BiomeGrades = BiomeGrades

-- Same grid as TowerRoomBuilder.Origin: floor id = row * 10 + col + 1, rooms 2,400 studs apart from (12000, 12000).
HubLighting.FloorGridOrigin = 12000
HubLighting.FloorGridSpacing = 2400

-- Per-floor grades, layered over the biome's: a hand-authored floor (TowerLayout AUTHORED) can set its own
-- time of day. ClockTime is shared by every preset (the sun never swings), so time of day is read through
-- colour shift, ambient and air. Only the listed fields change.
local FloorGrades: { [number]: { [string]: any } } = {
	-- Floor 1, Overgrown Threshold: dawn. Low warm gold from the east, cool shade, morning mist in the hollow.
	[1] = {
		Ambient = c(62, 70, 66), OutdoorAmbient = c(112, 108, 96), ColorShift_Top = c(255, 214, 158), ColorShift_Bottom = c(64, 82, 84),
		AtmosphereDensity = 0.3, AtmosphereColor = c(214, 190, 156), AtmosphereDecay = c(118, 132, 116), AtmosphereHaze = 1.25,
		TintColor = c(255, 244, 226), Saturation = 0.14, ExposureCompensation = -0.05, BloomIntensity = 0.32,
	},
	-- Floor 2, Broken Aqueduct: bright morning. Crisp daylight, cool teal water bounce, clear air with light spray haze.
	[2] = {
		Ambient = c(66, 78, 74), OutdoorAmbient = c(118, 128, 118), ColorShift_Top = c(248, 250, 232), ColorShift_Bottom = c(74, 114, 106),
		AtmosphereDensity = 0.22, AtmosphereColor = c(186, 222, 214), AtmosphereDecay = c(110, 146, 134), AtmosphereHaze = 0.78,
		TintColor = c(248, 255, 250), Saturation = 0.16, ExposureCompensation = 0.02, BloomIntensity = 0.26,
	},
	-- Floor 3, Rootway Crossing: high noon. Hard sunlit canopy shafts over the Knot, lush emerald gorge mist below.
	[3] = {
		Ambient = c(72, 82, 70), OutdoorAmbient = c(128, 134, 116), ColorShift_Top = c(255, 252, 220), ColorShift_Bottom = c(68, 104, 88),
		AtmosphereDensity = 0.25, AtmosphereColor = c(194, 228, 206), AtmosphereDecay = c(102, 138, 118), AtmosphereHaze = 0.95,
		TintColor = c(252, 255, 244), Saturation = 0.18, ExposureCompensation = 0.04, BloomIntensity = 0.28,
		SunRaysIntensity = 0.18, SunRaysSpread = 0.72,
	},
	-- Floor 4, Vinebound Bastion: overcast humid afternoon. Soft grey-green sky, dense low marsh mist over the moat.
	[4] = {
		Ambient = c(60, 68, 60), OutdoorAmbient = c(98, 108, 96), ColorShift_Top = c(206, 214, 192), ColorShift_Bottom = c(66, 86, 72),
		AtmosphereDensity = 0.42, AtmosphereColor = c(154, 174, 152), AtmosphereDecay = c(86, 108, 90), AtmosphereHaze = 1.65,
		TintColor = c(236, 244, 232), Saturation = -0.04, ExposureCompensation = -0.04, BloomIntensity = 0.24,
		SunRaysIntensity = 0.06, SunRaysSpread = 0.4,
	},
	-- Floor 5, Mossbound Court: golden hour fading to dusk. Warm amber horizon shafts meeting cool emerald cenote mist.
	[5] = {
		Ambient = c(64, 72, 62), OutdoorAmbient = c(122, 114, 92), ColorShift_Top = c(255, 218, 152), ColorShift_Bottom = c(56, 104, 88),
		AtmosphereDensity = 0.34, AtmosphereColor = c(196, 208, 172), AtmosphereDecay = c(124, 134, 96), AtmosphereHaze = 1.35,
		TintColor = c(255, 244, 224), Saturation = 0.16, ExposureCompensation = 0.02, BloomIntensity = 0.38,
		SunRaysIntensity = 0.22, SunRaysSpread = 0.85,
	},
	-- Floor 6, Sporelit Entry: underground twilight. Indigo ambient, cyan from above (the oculus) and violet
	-- from below (the glowpool), a violet haze thickening low over the water, and bloom up for the gills.
	[6] = {
		Ambient = c(44, 40, 86), OutdoorAmbient = c(60, 56, 112), ColorShift_Top = c(150, 232, 255), ColorShift_Bottom = c(96, 44, 150),
		AtmosphereDensity = 0.38, AtmosphereColor = c(84, 76, 150), AtmosphereDecay = c(52, 34, 104), AtmosphereHaze = 1.4,
		TintColor = c(228, 232, 255), Saturation = 0.24, ExposureCompensation = -0.08, BloomIntensity = 0.55,
		SunRaysIntensity = 0.06, SunRaysSpread = 0.35,
	},
	-- Floor 7, Mycelium Galleries: deeper in. Lower, more violet ambient, a thicker drip-mist haze, and the
	-- lamp niches' warmth standing out against the cold.
	[7] = {
		Ambient = c(36, 32, 74), OutdoorAmbient = c(50, 46, 98), ColorShift_Top = c(124, 212, 242), ColorShift_Bottom = c(112, 48, 162),
		AtmosphereDensity = 0.42, AtmosphereColor = c(76, 64, 138), AtmosphereDecay = c(44, 28, 96), AtmosphereHaze = 1.6,
		TintColor = c(226, 226, 255), Saturation = 0.26, ExposureCompensation = -0.12, BloomIntensity = 0.6,
	},
	-- Floor 8, Blooming Chasm: full bloom, the brightest Fungal floor. Strong cyan from the wide oculus, mist
	-- rising from the chasm, gills and crystals at their most saturated (the Lampkeepers' Rest is the one warm pool).
	[8] = {
		Ambient = c(54, 52, 102), OutdoorAmbient = c(76, 74, 132), ColorShift_Top = c(150, 240, 255), ColorShift_Bottom = c(112, 62, 172),
		AtmosphereDensity = 0.34, AtmosphereColor = c(84, 100, 164), AtmosphereDecay = c(56, 40, 112), AtmosphereHaze = 1.2,
		TintColor = c(232, 240, 255), Saturation = 0.3, ExposureCompensation = -0.02, BloomIntensity = 0.6,
	},
	-- Floor 9, Rotcap Keep: sickly rot. Yellow-green tint mixed into the violet, thick murky air, stronger
	-- contrast and bloom on the yellow-green rot glows; no warm light anywhere on the floor.
	[9] = {
		Ambient = c(56, 42, 82), OutdoorAmbient = c(84, 98, 62), ColorShift_Top = c(196, 248, 88), ColorShift_Bottom = c(118, 52, 176),
		AtmosphereDensity = 0.44, AtmosphereColor = c(96, 118, 72), AtmosphereDecay = c(78, 42, 118), AtmosphereHaze = 1.8,
		TintColor = c(232, 248, 204), Contrast = 0.14, Saturation = 0.22, ExposureCompensation = -0.06, BloomIntensity = 0.58,
	},
	-- Floor 10, Matriarch's Hollow: the heart of the Veinweb, and the opposite of Floor 9's murk. Clear, pale
	-- air lit silk-white from the great oculus over the dais, a cyan top light and a magenta floor bounce off
	-- the moat, and bloom on the silk, cocoons and converging veins (the Last Lamp at the arrival is the
	-- floor's sole warm flame).
	[10] = {
		Ambient = c(70, 62, 104), OutdoorAmbient = c(104, 98, 150), ColorShift_Top = c(200, 250, 255), ColorShift_Bottom = c(170, 60, 200),
		AtmosphereDensity = 0.3, AtmosphereColor = c(150, 140, 190), AtmosphereDecay = c(80, 50, 130), AtmosphereHaze = 1.0,
		TintColor = c(246, 242, 255), Contrast = 0.08, Saturation = 0.18, ExposureCompensation = 0.06, BloomIntensity = 0.7,
		SunRaysIntensity = 0.1, SunRaysSpread = 0.45,
	},
	-- Floor 11, Cinder Gate: searing white-hot desert noon, crisp pale mirage haze over dark volcanic ash & ochre sandstone.
	[11] = {
		Ambient = c(96, 84, 72), OutdoorAmbient = c(154, 138, 118), ColorShift_Top = c(255, 244, 214), ColorShift_Bottom = c(98, 72, 54),
		AtmosphereDensity = 0.24, AtmosphereColor = c(242, 224, 198), AtmosphereDecay = c(178, 134, 96), AtmosphereHaze = 0.90,
		TintColor = c(255, 248, 232), Saturation = 0.06, ExposureCompensation = 0.08, BloomIntensity = 0.34,
		SunRaysIntensity = 0.14, SunRaysSpread = 0.65,
	},
	-- Floor 12, Buried Caravan: afternoon sandstorm. Diffuse amber light & dense ochre dust keeping camps readable at 120 studs.
	[12] = {
		Ambient = c(104, 82, 58), OutdoorAmbient = c(150, 118, 86), ColorShift_Top = c(255, 212, 150), ColorShift_Bottom = c(98, 68, 46),
		AtmosphereDensity = 0.36, AtmosphereColor = c(228, 186, 134), AtmosphereDecay = c(156, 112, 72), AtmosphereHaze = 1.60,
		TintColor = c(255, 238, 212), Saturation = 0.04, ExposureCompensation = 0.02, BloomIntensity = 0.38,
		SunRaysIntensity = 0.22, SunRaysSpread = 0.75,
	},
	-- Floor 13, Glasswind Ravine: dusk in the ravine. Low orange light from the west, cool violet shade, amber glow through the Glass Arch.
	[13] = {
		Ambient = c(86, 72, 92), OutdoorAmbient = c(138, 108, 106), ColorShift_Top = c(255, 174, 96), ColorShift_Bottom = c(74, 62, 96),
		AtmosphereDensity = 0.24, AtmosphereColor = c(212, 156, 128), AtmosphereDecay = c(142, 96, 84), AtmosphereHaze = 1.05,
		TintColor = c(255, 232, 210), Saturation = 0.14, ExposureCompensation = 0.04, BloomIntensity = 0.36,
		SunRaysIntensity = 0.22, SunRaysSpread = 0.78,
	},
	-- Floor 14, Sunscar Fortress: readable desert night; dark blue ambient lit by smoky orange-amber kiln & lava bloom.
	[14] = {
		Ambient = c(66, 72, 104), OutdoorAmbient = c(102, 108, 138), ColorShift_Top = c(128, 148, 212), ColorShift_Bottom = c(148, 70, 34),
		AtmosphereDensity = 0.26, AtmosphereColor = c(122, 114, 146), AtmosphereDecay = c(82, 68, 92), AtmosphereHaze = 1.15,
		TintColor = c(236, 232, 248), Saturation = 0.10, ExposureCompensation = 0.05, BloomIntensity = 0.44,
		SunRaysIntensity = 0.08, SunRaysSpread = 0.50,
	},
	-- Floor 15, Colossus Dais: volcanic eruption at Cinderhold's vent. Crimson sky, molten underglow from below, thick ash haze & strong vent bloom.
	[15] = {
		Ambient = c(86, 56, 58), OutdoorAmbient = c(124, 82, 74), ColorShift_Top = c(242, 114, 84), ColorShift_Bottom = c(255, 112, 38),
		AtmosphereDensity = 0.34, AtmosphereColor = c(178, 98, 86), AtmosphereDecay = c(122, 56, 46), AtmosphereHaze = 1.45,
		TintColor = c(255, 230, 220), Saturation = 0.14, ExposureCompensation = 0.04, BloomIntensity = 0.48,
		SunRaysIntensity = 0.14, SunRaysSpread = 0.65,
	},
	-- Floor 16, Rimefall Approach: overcast whiteout morning. Flat bright cool winter light, thick white mist (camps kept clear) & pale ice bloom.
	[16] = {
		Ambient = c(102, 118, 136), OutdoorAmbient = c(154, 172, 192), ColorShift_Top = c(230, 240, 252), ColorShift_Bottom = c(126, 152, 180),
		AtmosphereDensity = 0.38, AtmosphereColor = c(218, 230, 244), AtmosphereDecay = c(162, 184, 210), AtmosphereHaze = 1.65,
		TintColor = c(240, 248, 255), Saturation = -0.10, Contrast = 0.06, ExposureCompensation = 0.12, BloomIntensity = 0.34,
		SunRaysIntensity = 0.04, SunRaysSpread = 0.45,
	},
	-- Floor 17 (Frozen Barracks): clear, cold noon — crisp high contrast, sharp blue shadows, thin sky, sparkling frost.
	[17] = {
		Ambient = c(74, 102, 138), OutdoorAmbient = c(138, 168, 204), ColorShift_Top = c(240, 248, 255), ColorShift_Bottom = c(92, 128, 174),
		AtmosphereDensity = 0.22, AtmosphereColor = c(206, 228, 252), AtmosphereDecay = c(138, 172, 214), AtmosphereHaze = 0.85,
		TintColor = c(234, 245, 255), Saturation = 0.02, Contrast = 0.18, ExposureCompensation = 0.18, BloomIntensity = 0.44,
		SunRaysIntensity = 0.12, SunRaysSpread = 0.35,
	},
	-- Floor 18 (Shattered Iceway): blizzard afternoon — dim diffuse storm light, blue-grey alpine haze, crisp silhouette contrast & camp readability at 120 studs.
	[18] = {
		Ambient = c(92, 108, 128), OutdoorAmbient = c(138, 156, 178), ColorShift_Top = c(212, 224, 240), ColorShift_Bottom = c(84, 106, 134),
		AtmosphereDensity = 0.36, AtmosphereColor = c(194, 210, 228), AtmosphereDecay = c(134, 154, 178), AtmosphereHaze = 1.55,
		TintColor = c(232, 242, 255), Saturation = -0.06, Contrast = 0.14, ExposureCompensation = 0.08, BloomIntensity = 0.32,
		SunRaysIntensity = 0.04, SunRaysSpread = 0.40,
	},
	-- Floor 19 (Whiteguard Keep): twilight with aurora — deep blue-indigo ambient, emerald-violet horizon haze, rimelight crystal bloom.
	[19] = {
		Ambient = c(72, 92, 138), OutdoorAmbient = c(116, 140, 186), ColorShift_Top = c(138, 206, 198), ColorShift_Bottom = c(88, 92, 156),
		AtmosphereDensity = 0.28, AtmosphereColor = c(144, 174, 208), AtmosphereDecay = c(102, 114, 168), AtmosphereHaze = 1.25,
		TintColor = c(226, 242, 255), Saturation = 0.08, Contrast = 0.12, ExposureCompensation = 0.14, BloomIntensity = 0.46,
		SunRaysIntensity = 0.06, SunRaysSpread = 0.45,
	},
	-- Floor 20 (Frostbound Throne): frozen night — moonlit indigo cathedral, still crisp air, cyan Stillheart & ice crystal bloom.
	[20] = {
		Ambient = c(74, 88, 128), OutdoorAmbient = c(116, 134, 178), ColorShift_Top = c(146, 204, 212), ColorShift_Bottom = c(72, 82, 132),
		AtmosphereDensity = 0.24, AtmosphereColor = c(132, 160, 198), AtmosphereDecay = c(92, 108, 156), AtmosphereHaze = 1.05,
		TintColor = c(226, 240, 255), Saturation = 0.04, Contrast = 0.16, ExposureCompensation = 0.16, BloomIntensity = 0.48,
		SunRaysIntensity = 0.05, SunRaysSpread = 0.42,
	},
	-- Floor 21 (Slagworks Entry): smoky red dawn, the only Infernal floor with open sky — a low red-orange key
	-- with a sulphur-yellow tint, soot haze thick enough to layer the flue stacks, and rays through the smoke.
	[21] = {
		Ambient = c(92, 58, 50), OutdoorAmbient = c(132, 82, 66), ColorShift_Top = c(255, 168, 112), ColorShift_Bottom = c(96, 42, 34),
		AtmosphereDensity = 0.3, AtmosphereColor = c(168, 98, 76), AtmosphereDecay = c(118, 58, 46), AtmosphereHaze = 1.6,
		TintColor = c(255, 236, 206), Saturation = 0.06, Contrast = 0.12, ExposureCompensation = 0.12, BloomIntensity = 0.4,
		SunRaysIntensity = 0.1, SunRaysSpread = 0.5,
	},
	-- Floor 22 (Molten Assembly): interior work-light under a closed vault — warm sodium amber, strong contrast,
	-- a thin steam haze, and bloom on the lamp strings and furnace mouths.
	[22] = {
		Ambient = c(98, 70, 50), OutdoorAmbient = c(118, 84, 60), ColorShift_Top = c(255, 186, 112), ColorShift_Bottom = c(84, 44, 30),
		AtmosphereDensity = 0.36, AtmosphereColor = c(150, 112, 88), AtmosphereDecay = c(96, 60, 44), AtmosphereHaze = 1.3,
		TintColor = c(255, 230, 196), Saturation = 0.08, Contrast = 0.2, ExposureCompensation = 0.2, BloomIntensity = 0.55,
		SunRaysIntensity = 0.14, SunRaysSpread = 0.3,
	},
	-- Floor 23 (Furnace Causeway): furnace glare, the hottest light so far — a white-orange key off the lava lake
	-- and six furnace mouths, heat haze, and heavy bloom kept just short of washing out the telegraphs.
	[23] = {
		Ambient = c(112, 62, 40), OutdoorAmbient = c(136, 76, 48), ColorShift_Top = c(255, 214, 150), ColorShift_Bottom = c(140, 52, 22),
		AtmosphereDensity = 0.34, AtmosphereColor = c(176, 104, 62), AtmosphereDecay = c(132, 54, 28), AtmosphereHaze = 1.8,
		TintColor = c(255, 236, 214), Saturation = 0.12, Contrast = 0.16, ExposureCompensation = 0.1, BloomIntensity = 0.7,
		SunRaysIntensity = 0.08, SunRaysSpread = 0.45,
	},
	-- Floor 24 (Ironflame Bulwark): siege-red night — deep crimson key off The Pour and lava falls against a cool
	-- steel-blue shadow fill across the iron-bound towers, smoky haze tuned so the Citadel and lava falls read.
	[24] = {
		Ambient = c(68, 66, 86), OutdoorAmbient = c(96, 82, 98), ColorShift_Top = c(255, 138, 92), ColorShift_Bottom = c(148, 42, 22),
		AtmosphereDensity = 0.31, AtmosphereColor = c(154, 78, 64), AtmosphereDecay = c(102, 46, 48), AtmosphereHaze = 1.65,
		TintColor = c(246, 224, 214), Saturation = 0.1, Contrast = 0.2, ExposureCompensation = 0.14, BloomIntensity = 0.62,
		SunRaysIntensity = 0.06, SunRaysSpread = 0.4,
	},
	-- Floor 25 (Titan's Crucible): molten heart — molten gold under-light rising from the lava lake and Great
	-- Crucible against a dark soot-black vaulted cavern, tuned so the 179-stud Crucible reads and boss telegraphs pop.
	[25] = {
		Ambient = c(86, 56, 42), OutdoorAmbient = c(104, 66, 46), ColorShift_Top = c(255, 198, 118), ColorShift_Bottom = c(196, 88, 26),
		AtmosphereDensity = 0.28, AtmosphereColor = c(162, 92, 54), AtmosphereDecay = c(88, 42, 30), AtmosphereHaze = 1.55,
		TintColor = c(255, 234, 204), Saturation = 0.12, Contrast = 0.22, ExposureCompensation = 0.12, BloomIntensity = 0.66,
		SunRaysIntensity = 0.08, SunRaysSpread = 0.44,
	},
	-- Floor 26 (Stormgrass Rise): storm-breaking highland dawn. A cool slate-blue ambient under a pale gold top
	-- light breaking through the clouds, a light valley mist that keeps the moor, the headwall tor and the far
	-- ridges in three distinct layers, and crisp contrast on the wet stormgrass.
	[26] = {
		Ambient = c(70, 78, 98), OutdoorAmbient = c(96, 106, 128), ColorShift_Top = c(255, 226, 178), ColorShift_Bottom = c(92, 84, 140),
		AtmosphereDensity = 0.26, AtmosphereColor = c(150, 158, 178), AtmosphereDecay = c(96, 92, 132), AtmosphereHaze = 1.0,
		TintColor = c(240, 242, 255), Saturation = 0.1, Contrast = 0.14, ExposureCompensation = 0.04, BloomIntensity = 0.42,
		SunRaysIntensity = 0.12, SunRaysSpread = 0.4,
	},
	-- Floor 27 (Thunderhead Outpost): gathering thunderhead noon. A silver-indigo overcast, stronger contrast,
	-- a thickening highland haze bruised violet-grey, and warm copper-fire pools from the beacons and the forge.
	[27] = {
		Ambient = c(70, 70, 96), OutdoorAmbient = c(98, 98, 128), ColorShift_Top = c(214, 218, 240), ColorShift_Bottom = c(120, 82, 66),
		AtmosphereDensity = 0.3, AtmosphereColor = c(128, 128, 156), AtmosphereDecay = c(84, 76, 116), AtmosphereHaze = 1.25,
		TintColor = c(232, 234, 250), Saturation = 0.04, Contrast = 0.16, ExposureCompensation = 0.02, BloomIntensity = 0.46,
		SunRaysIntensity = 0.06, SunRaysSpread = 0.35,
	},
	-- Floor 28, Skybridge Cliffs: a cloud-sea squall afternoon. Dark slate shadows above and a luminous
	-- silver-violet bounce off the cloud abyss below (ColorShift_Bottom), crisp gorge air with a deep chasm
	-- mist, the violet fulgurite needles and the skybridge copper popping against the dark sea-stacks.
	[28] = {
		Ambient = c(66, 68, 92), OutdoorAmbient = c(104, 106, 140), ColorShift_Top = c(176, 184, 214), ColorShift_Bottom = c(176, 150, 226),
		AtmosphereDensity = 0.28, AtmosphereColor = c(150, 150, 182), AtmosphereDecay = c(92, 84, 132), AtmosphereHaze = 1.15,
		TintColor = c(228, 230, 250), Saturation = 0.06, Contrast = 0.18, ExposureCompensation = 0.03, BloomIntensity = 0.5,
		SunRaysIntensity = 0.04, SunRaysSpread = 0.3,
	},
	-- Floor 29, Tempest Redoubt: electric dusk. A deep indigo-violet storm light, the last of the sun a bruised
	-- violet glow low behind the citadel, heavier haze in the chasm and strong bloom so the storm spire, the
	-- capacitor and the nexus braziers crackle against the dark masonry.
	[29] = {
		Ambient = c(58, 54, 92), OutdoorAmbient = c(92, 86, 140), ColorShift_Top = c(168, 156, 232), ColorShift_Bottom = c(190, 140, 246),
		AtmosphereDensity = 0.33, AtmosphereColor = c(124, 112, 172), AtmosphereDecay = c(78, 62, 128), AtmosphereHaze = 1.4,
		TintColor = c(220, 214, 250), Saturation = 0.1, Contrast = 0.22, ExposureCompensation = -0.02, BloomIntensity = 0.62,
		SunRaysIntensity = 0.06, SunRaysSpread = 0.36,
	},
	-- Floor 31, Blighted Verge: a sickly gold late afternoon. Warm low light over the autumn bank, the magenta
	-- murk of the biome thinned to a rose haze that thickens toward the rotten north-east; the least murky
	-- Corrupted floor.
	[31] = {
		Ambient = c(84, 62, 58), OutdoorAmbient = c(128, 96, 80), ColorShift_Top = c(255, 196, 128), ColorShift_Bottom = c(92, 46, 70),
		AtmosphereDensity = 0.26, AtmosphereColor = c(168, 118, 126), AtmosphereDecay = c(110, 56, 96), AtmosphereHaze = 0.75,
		TintColor = c(255, 238, 222), Saturation = 0.16, Contrast = 0.12, ExposureCompensation = 0.04, BloomIntensity = 0.42,
	},
	-- Floor 32, Twisted Orchard: overripe rose-violet dusk. Deep purple-violet dusk sky and haze,
	-- lush royal-violet shadows, glowing violet-magenta rot-fruit and cider must across the orchard slope.
	[32] = {
		Ambient = c(74, 34, 126), OutdoorAmbient = c(116, 58, 176), ColorShift_Top = c(198, 114, 255), ColorShift_Bottom = c(96, 30, 152),
		AtmosphereDensity = 0.35, AtmosphereColor = c(146, 58, 198), AtmosphereDecay = c(84, 24, 138), AtmosphereHaze = 1.3,
		TintColor = c(222, 184, 255), Saturation = 0.24, Contrast = 0.10, ExposureCompensation = 0.08, BloomIntensity = 0.52,
	},
	-- Floor 33, Briar Labyrinth: hard overhead thorn-shadow noon with deep corrupted violet-amethyst shadows
	-- over the blighted pit and low haze so the hedge maze and glowing magenta briars read crisply from above.
	[33] = {
		Ambient = c(84, 42, 134), OutdoorAmbient = c(128, 78, 186), ColorShift_Top = c(228, 184, 255), ColorShift_Bottom = c(96, 30, 148),
		AtmosphereDensity = 0.30, AtmosphereColor = c(144, 78, 198), AtmosphereDecay = c(88, 36, 142), AtmosphereHaze = 0.90,
		TintColor = c(236, 210, 255), Saturation = 0.14, Contrast = 0.18, ExposureCompensation = 0.08, BloomIntensity = 0.52,
	},
	-- Floor 34, Heartrot Stronghold: deep violet-black canopy gloom pierced by sun-ray shafts through
	-- high crown gaps and electric violet-magenta heartrot cavities; the darkest Corrupted floor while
	-- keeping camps, branch bridges and red enemy telegraphs clear.
	[34] = {
		Ambient = c(56, 30, 96), OutdoorAmbient = c(84, 52, 134), ColorShift_Top = c(186, 148, 242), ColorShift_Bottom = c(88, 22, 138),
		AtmosphereDensity = 0.40, AtmosphereColor = c(104, 54, 152), AtmosphereDecay = c(62, 24, 108), AtmosphereHaze = 1.40,
		TintColor = c(226, 200, 255), Saturation = 0.10, Contrast = 0.16, ExposureCompensation = -0.02, BloomIntensity = 0.54,
		SunRaysIntensity = 0.24, SunRaysSpread = 0.78,
	},
	-- Floor 35, Sovereign's Grove (Biome Boss: Blight Sovereign): blight eclipse — imperial crimson-violet
	-- sky and eclipse horizon with a cool lilac key on the Sovereign's Dais so the 252-stud Mother Graft,
	-- the Sovereign and every crimson boss telegraph read cleanly across the 795-stud sap mire.
	[35] = {
		Ambient = c(74, 34, 118), OutdoorAmbient = c(114, 64, 168), ColorShift_Top = c(216, 176, 255), ColorShift_Bottom = c(128, 24, 134),
		AtmosphereDensity = 0.28, AtmosphereColor = c(148, 48, 166), AtmosphereDecay = c(102, 22, 114), AtmosphereHaze = 0.95,
		TintColor = c(234, 210, 255), Saturation = 0.16, Contrast = 0.14, ExposureCompensation = 0.05, BloomIntensity = 0.60,
		SunRaysIntensity = 0.14, SunRaysSpread = 0.62,
	},
	-- Floor 39, Pearlguard Vault: deep blue coastal twilight lit by warm pearl-white glow spilling from the
	-- Pearl Vault conservatory dome. Cool silver-blue atmosphere keeps the fortified sea-walls, harbour water
	-- and red/orange combat telegraphs crisp while the vault dome shines as the brightest point on the floor.
	[39] = {
		Ambient = c(56, 72, 102), OutdoorAmbient = c(96, 116, 152), ColorShift_Top = c(170, 196, 252), ColorShift_Bottom = c(44, 72, 98),
		AtmosphereDensity = 0.30, AtmosphereColor = c(108, 134, 166), AtmosphereDecay = c(62, 82, 116), AtmosphereHaze = 1.05,
		TintColor = c(226, 236, 252), Saturation = 0.08, Contrast = 0.15, ExposureCompensation = 0.02, BloomIntensity = 0.52,
		SunRaysIntensity = 0.10, SunRaysSpread = 0.48,
	},
}
HubLighting.FloorGrades = FloorGrades

-- The floor id (1..50) of the tower floor room at (x, z), or nil off the floor grid.
function HubLighting.TowerFloorAt(x: number, z: number): number?
	local col = math.round((x - HubLighting.FloorGridOrigin) / HubLighting.FloorGridSpacing)
	local row = math.round((z - HubLighting.FloorGridOrigin) / HubLighting.FloorGridSpacing)
	if col < 0 or col > 9 or row < 0 or row > 4 then
		return nil
	end
	return row * 10 + col + 1
end

-- The biome index (1..10) of the tower floor room at (x, z), or nil off the floor grid.
function HubLighting.TowerBiomeAt(x: number, z: number): number?
	local floorId = HubLighting.TowerFloorAt(x, z)
	return if floorId then math.ceil(floorId / 5) else nil
end

local gradeCache: { [number]: Preset } = {}
local floorCache: { [number]: Preset } = {}

-- Storm with the biome's grade applied (Storm itself for nil or an unknown biome), and the floor's own
-- grade over that when floorId has one.
function HubLighting.TowerPreset(biomeIndex: number?, floorId: number?): Preset
	local floorGrade = floorId and FloorGrades[floorId]
	if floorId and floorGrade then
		local cached = floorCache[floorId]
		if cached then
			return cached
		end
		local out = table.clone(HubLighting.TowerPreset(biomeIndex)) :: any
		for key, value in floorGrade do
			out[key] = value
		end
		floorCache[floorId] = out
		return out
	end
	local grade = biomeIndex and BiomeGrades[biomeIndex]
	if not biomeIndex or not grade then
		return Presets.Storm
	end
	local cached = gradeCache[biomeIndex]
	if cached then
		return cached
	end
	local out = table.clone(Presets.Storm) :: any
	for key, value in grade do
		out[key] = value
	end
	gradeCache[biomeIndex] = out
	return out
end

return HubLighting
