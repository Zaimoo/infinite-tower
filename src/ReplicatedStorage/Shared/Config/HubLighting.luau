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
