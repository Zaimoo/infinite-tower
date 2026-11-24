--!strict
-- Hand-authored set pieces for Sunken Sanctuary Floor 40: Leviathan's Basin (sunken:5, BOSS_ARENA).
-- Guide image: reference/Sunken Sanctuary 40.jpg. Design: docs/prompts/sunken-sanctuary-floor-layouts-prompt.md.
--
-- The inner basin of the drowned Great Temple beneath the Sea-Dome, where the Tidal Leviathan broke
-- the Great Tidebell and turned the basin into a living whirlpool:
--   * Colossal 272-stud torn twin-buttress stump of the Great Tidebell Tower rising north of the dais
--     with its twisted bronze bell-yoke, shattered bell remnant, hanging trident banners, and twin
--     waist-broken statues of the Nereth tide-king and tide-queen flanking it on rock islands.
--   * Overhead geodesic Sea-Dome sealing the abyss with dark ocean silhouettes (Tidal Leviathan shadow,
--     whales, mantas, sharks — animated client-side via "SunkenDomeSwimmer"), pierced directly over
--     Leviathan's Dais by the glowing Eye of Daylight oculus pouring soft volumetric shafts downward.
--   * Animated 3-layer Maelstrom Vortex ("SunkenMaelstromRing" + "MaelstromSprayEmitter", driven purely
--     client-side by MaelstromVortexController.client.luau at zero server replication cost) spiraling
--     around the sheer central rock pillar beneath Leviathan's Dais, joined by swirling drowned debris
--     and hydrothermal bubble columns.
--   * Clean, flat 196 x 144 boss arena on Leviathan's Dais with a flush non-colliding dark-limestone,
--     blue, and gold trident + tide-spiral mosaic, ringed strictly on its outer perimeter by aqua flame
--     brazier pedestals, hanging pillar banners, broken bell-tower footings, and four rim waterfalls.
--   * Twin climbing Reef Horns (West & East) dressed in bioluminescent violet, lavender-pink, pale ochre,
--     and cyan-aqua table corals (zero red or orange anywhere on the floor), ruined Tide Gate piers,
--     Drowned Altar with dropped bell-hammer, High Cantor's Pulpit, Pearl Reliquary (scaled heart door),
--     twin Chain Towers, twin Chain Anchor Bollards, wrecked Bell Barge, Kelp Shrine, drowned perimeter
--     colonnade, and The Last Bell at Sanctuary.
local CollectionService = game:GetService("CollectionService")

local InfernalFoundry = require(script.Parent.InfernalFoundry)

local SunkenFloor40 = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Mat = Enum.Material

export type Landmark = InfernalFoundry.Landmark

local function swatch(r: number, g: number, b: number, mat: Enum.Material, trans: number?): any
	return { Color = rgb(r, g, b), Material = mat, Transparency = trans }
end

local function tinted(base: any, changes: { [string]: any }): any
	local o = table.clone(base)
	for role, s in changes do
		o[role] = s
	end
	return o
end

-- Deep abyssal basin palette: zero red or orange anywhere on the floor so boss telegraphs pop clearly.
-- Bioluminescent corals strictly use violet, lavender-pink, pale gold-ochre, and cyan-aqua per the guide image.
local BASIN_PAL = table.freeze({
	STONE = swatch(64, 78, 88, Mat.Slate), -- dark wet abyssal limestone & basalt
	TRIM = swatch(132, 146, 150, Mat.Limestone), -- carved pale sea-worn limestone arches & plinths
	METAL = swatch(48, 54, 62, Mat.Metal), -- dark bronze binding chains, dome ribs & bollards
	ACCENT = swatch(56, 126, 124, Mat.Metal), -- verdigris bronze Tidebells, tridents & reliefs
	GOLD = swatch(204, 174, 96, Mat.Metal), -- worn gilt trident sigils, chain rings & altar trim
	GLOW = swatch(96, 240, 255, Mat.Neon), -- cyan-aqua rune fire, maelstrom foam & coral rims
	CANDLE = swatch(154, 246, 255, Mat.Neon), -- cool daylight-aqua lanterns (zero warm orange)
	WOOD = swatch(62, 52, 46, Mat.Wood), -- sunken salt-bleached bell-barge timber
	SILK = swatch(28, 72, 98, Mat.Fabric), -- deep navy-teal Nereth trident banners
	FOLIAGE = swatch(38, 102, 96, Mat.Grass), -- towering abyssal kelp & seagrass
	MOSS = swatch(44, 88, 78, Mat.Grass), -- wet marine algae & pillar moss
	CORAL = swatch(154, 114, 224, Mat.SmoothPlastic), -- bioluminescent violet reef coral (never red/orange)
	ALT = swatch(32, 142, 168, Mat.SmoothPlastic), -- deep turquoise maelstrom water walls & shell stone
	CRYSTAL = swatch(128, 232, 248, Mat.Glass, 0.28), -- translucent Sea-Dome glass, wave crests & cascades
})

local CORAL_LAVENDER = tinted(BASIN_PAL, {
	CORAL = swatch(196, 134, 218, Mat.SmoothPlastic), -- soft lavender-pink table corals
	GLOW = swatch(166, 228, 255, Mat.Neon),
})
local CORAL_AQUA = tinted(BASIN_PAL, {
	CORAL = swatch(82, 206, 218, Mat.SmoothPlastic), -- glowing cyan-aqua sea-fans & coral caps
	GLOW = swatch(122, 248, 255, Mat.Neon),
})
local CORAL_OCHRE = tinted(BASIN_PAL, {
	CORAL = swatch(198, 184, 136, Mat.SmoothPlastic), -- pale gold-ochre reef fans (zero orange/red)
	GLOW = swatch(168, 236, 244, Mat.Neon),
})
local MAELSTROM_OUTER_PAL = tinted(BASIN_PAL, {
	ALT = swatch(24, 114, 144, Mat.Glass, 0.22),
	CRYSTAL = swatch(74, 198, 224, Mat.Glass, 0.30),
	SILK = swatch(216, 246, 255, Mat.SmoothPlastic, 0.14),
	GLOW = swatch(140, 244, 255, Mat.Neon, 0.18),
})
local MAELSTROM_INNER_PAL = tinted(BASIN_PAL, {
	ALT = swatch(36, 152, 182, Mat.Glass, 0.16),
	CRYSTAL = swatch(124, 234, 248, Mat.Glass, 0.24),
	SILK = swatch(234, 252, 255, Mat.Neon, 0.18),
	GLOW = swatch(172, 250, 255, Mat.Neon, 0.08),
})
local SEADOME_PAL = tinted(BASIN_PAL, {
	METAL = swatch(26, 42, 58, Mat.Metal),
	STONE = swatch(32, 48, 62, Mat.Slate),
	ACCENT = swatch(38, 86, 102, Mat.Metal),
	CRYSTAL = swatch(36, 118, 156, Mat.Glass, 0.56),
})

local DAYLIGHT_KEY = rgb(214, 244, 255)
local AQUA_LIGHT = rgb(94, 238, 255)
local VIOLET_REEF = rgb(156, 182, 255)

-- Floor 40's spec-checked landmark footprints (room-local, scaled and turned), verified clear of every
-- walkway lane, every camp, both return ramps, the 196 x 144 Leviathan's Dais arena, and both boss portals
-- (Ascend 16,64,-235; Rerun -16,64,-235). Tallest landmark: GreatTidebellTower (Top = 272.0 >= 265).
SunkenFloor40.Floor40Landmarks = table.freeze({
	{ Id = "GreatTidebellTower", X = 0, Z = -345, Y = -10, HalfX = 70.0, HalfZ = 22.0, Top = 272.0 },
	{ Id = "BrokenTideStatueWest", X = -142, Z = -328, Y = 18, HalfX = 12.2, HalfZ = 10.9, Top = 48.6 },
	{ Id = "BrokenTideStatueEast", X = 142, Z = -328, Y = 18, HalfX = 12.2, HalfZ = 10.9, Top = 48.6 },
	{ Id = "WestChainAnchorBollard", X = -152, Z = -262, Y = 52, HalfX = 9.8, HalfZ = 9.8, Top = 26.4 },
	{ Id = "EastChainAnchorBollard", X = 152, Z = -262, Y = 56, HalfX = 9.8, HalfZ = 9.8, Top = 26.4 },
	{ Id = "WestChainTower", X = -346, Z = -120, Y = 36, HalfX = 15.2, HalfZ = 15.8, Top = 70.7 },
	{ Id = "EastChainTower", X = 346, Z = -120, Y = 38, HalfX = 15.2, HalfZ = 15.8, Top = 70.7 },
	{ Id = "DrownedAltarShrine", X = 0, Z = -28, Y = 26, HalfX = 10.6, HalfZ = 10.8, Top = 14.3 },
	{ Id = "HighCantorPulpit", X = -258, Z = -360, Y = 44, HalfX = 9.0, HalfZ = 9.4, Top = 24.7 },
	{ Id = "PearlReliquaryShrine", X = 258, Z = -360, Y = 42, HalfX = 10.5, HalfZ = 9.5, Top = 29.0 },
	{ Id = "BellBargeWreckEast", X = 408, Z = 72, Y = 28, HalfX = 8.2, HalfZ = 23.1, Top = 25.4 },
	{ Id = "KelpShrineStones", X = -406, Z = 74, Y = 24, HalfX = 9.0, HalfZ = 9.0, Top = 49.2 },
	{ Id = "TideGatePierWest", X = -68, Z = 138, Y = 12, HalfX = 9.5, HalfZ = 8.5, Top = 31.2 },
	{ Id = "TideGatePierEast", X = 68, Z = 138, Y = 12, HalfX = 9.5, HalfZ = 8.5, Top = 31.2 },
	{ Id = "WestCrestLookout", X = -394, Z = -246, Y = 48, HalfX = 10.5, HalfZ = 8.5, Top = 31.2 },
	{ Id = "EastCrestLookout", X = 394, Z = -246, Y = 50, HalfX = 10.5, HalfZ = 8.5, Top = 31.2 },
	{ Id = "TheLastBellPost", X = -52, Z = 368, Y = 8, HalfX = 6.0, HalfZ = 6.0, Top = 22.0 },
	{ Id = "WrackShoreBellWest", X = -255, Z = 272, Y = 0, HalfX = 6.0, HalfZ = 6.0, Top = 13.0 },
	{ Id = "WrackShoreBellEast", X = 255, Z = 272, Y = 0, HalfX = 6.0, HalfZ = 6.0, Top = 13.0 },
	{ Id = "WestReefCoralSpire", X = -342, Z = 8, Y = 20, HalfX = 10.0, HalfZ = 8.0, Top = 18.0 },
	{ Id = "EastReefCoralSpire", X = 342, Z = 8, Y = 22, HalfX = 10.0, HalfZ = 8.0, Top = 18.0 },
	{ Id = "PerimeterColonnadeNW", X = -318, Z = -362, Y = -4, HalfX = 16.0, HalfZ = 10.0, Top = 44.0 },
	{ Id = "PerimeterColonnadeNE", X = 318, Z = -362, Y = -4, HalfX = 16.0, HalfZ = 10.0, Top = 44.0 },
	{ Id = "MaelstromBubbleVentW", X = -135, Z = 15, Y = 4, HalfX = 7.5, HalfZ = 6.2, Top = 8.0 },
	{ Id = "MaelstromBubbleVentE", X = 135, Z = 15, Y = 4, HalfX = 7.5, HalfZ = 6.2, Top = 8.0 },
	{ Id = "TidewallBasinNorth", X = 0, Z = -394, Y = -10, HalfX = 390.0, HalfZ = 3.0, Top = 310.0 },
}) :: { Landmark }

function SunkenFloor40.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number = H.field, H.bottom, H.d
	local w: number = ctx.w
	local layout = ctx.layout
	local P = layout.Platforms
	local noCollide = H.noCollide
	local origin: Vector3 = ctx.origin
	local waterY: number = if field then field.LiquidLevel else bottom
	local landmarks, props, cover = 0, 0, 0
	local kindsUsed: { [string]: number } = {}
	local rng = Random.new(40 * 8191)

	local function boxAt(name: string, size: Vector3, pos: Vector3, yaw: number, color: Color3, mat: Enum.Material, trans: number?): Part
		return H.boxAt(name, size, CFrame.new(pos) * CFrame.Angles(0, yaw, 0), color, mat, trans)
	end
	local function lump(name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material): Part
		return H.lump(name, pos, size, color, mat)
	end
	local function light(pos: Vector3, color: Color3, brightness: number, range: number)
		local anchor = ctx.block("LightAnchor", V(0.5, 0.5, 0.5), pos, color, Mat.SmoothPlastic, nil, 1)
		noCollide(anchor)
		H.light(anchor, color, brightness, range)
	end
	local function isClear(x: number, z: number, r: number): boolean
		for _, camp in layout.Camps do
			if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (38 + r) ^ 2 then
				return false
			end
		end
		return ctx.footprintClear(x, z, r + 1, r + 1)
	end
	-- Keep all scatter strictly off Leviathan's Dais interior (196 x 144), Sanctuary, and PortalSpots.
	local function offDais(x: number, z: number, pad: number?): boolean
		local p = pad or 10
		local apex = P.Apex
		if math.abs(x - apex.X) <= (apex.Width * 0.5 + p) and math.abs(z - apex.Z) <= (apex.Depth * 0.5 + p) then
			return false
		end
		local safe = layout.Sanctuary
		if safe and math.abs(x - safe.X) <= (safe.Width * 0.5 + p + 8) and math.abs(z - safe.Z) <= (safe.Depth * 0.5 + p + 8) then
			return false
		end
		return true
	end
	local function groundY(x: number, z: number): number
		if field then
			return (field.Sample(x, z))
		end
		return bottom
	end
	local function placeKit(
		templateName: string,
		propKind: string,
		pos: Vector3,
		yaw: number,
		scale: number,
		palette: any?,
		solid: boolean?,
		isLandmark: boolean?,
		isCover: boolean?,
		fallback: (() -> ())?
	): Instance?
		local placed: Instance? = nil
		ctx.group(propKind, function()
			ctx.tag("OnTerrain", true)
			if isLandmark then
				ctx.tag("Landmark", true)
				landmarks += 1
			end
			if ctx.has(templateName) then
				placed = ctx.kitAt(templateName, CFrame.new(pos) * CFrame.Angles(0, yaw, 0), scale, palette or BASIN_PAL, solid)
				kindsUsed[templateName] = (kindsUsed[templateName] or 0) + 1
			elseif fallback then
				fallback()
				placed = ctx.current()
			end
		end)
		if isCover then
			cover += 1
		else
			props += 1
		end
		return placed
	end

	local function addEmitter(parent: BasePart, tag: string, opts: {
		Color: ColorSequence,
		Size: NumberSequence,
		Trans: NumberSequence,
		Rate: number,
		Life: NumberRange,
		Speed: NumberRange,
		Spread: Vector2,
		Accel: Vector3?,
		LightEm: number?,
	})
		local em = Instance.new("ParticleEmitter")
		em.Name = tag
		em.Color = opts.Color
		em.Size = opts.Size
		em.Transparency = opts.Trans
		em.Rate = opts.Rate
		em.Lifetime = opts.Life
		em.Speed = opts.Speed
		em.SpreadAngle = opts.Spread
		em.Acceleration = opts.Accel or V(0, 0, 0)
		em.LightEmission = opts.LightEm or 0.35
		em.RotSpeed = NumberRange.new(-45, 45)
		em.Parent = parent
		em:SetAttribute("BaseRate", opts.Rate)
		CollectionService:AddTag(em, tag)
	end

	local function buildWaterfallRibbon(name: string, x: number, yTop: number, yBot: number, z: number, width: number, yaw: number, withMist: boolean)
		local span = math.max(8, yTop - yBot)
		ctx.group(name, function()
			ctx.tag("OnTerrain", true)
			local rib = boxAt("CascadeCore", V(width, span, 1.4), V(x, yBot + span * 0.5, z), yaw, rgb(124, 224, 242), Mat.Glass, 0.34)
			noCollide(rib)
			local foam = boxAt("CascadeFoam", V(width * 0.65, span * 0.96, 0.7), V(x, yBot + span * 0.5, z), yaw, rgb(224, 250, 255), Mat.Neon, 0.56)
			noCollide(foam)
			local splash = lump("CascadeSplash", V(width * 1.45, 3.2, width * 0.95), V(x, yBot + 1.4, z), rgb(216, 248, 255), Mat.SmoothPlastic)
			splash.Transparency = 0.25
			noCollide(splash)
			if withMist then
				addEmitter(splash, "MaelstromSprayEmitter", {
					Color = ColorSequence.new(rgb(186, 246, 255), rgb(232, 252, 255)),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.5), NumberSequenceKeypoint.new(1, 9.5) }),
					Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1.0) }),
					Rate = 10,
					Life = NumberRange.new(1.2, 2.2),
					Speed = NumberRange.new(4, 10),
					Spread = Vector2.new(45, 45),
					Accel = V(0, 4, 0),
					LightEm = 0.45,
				})
			end
		end)
		props += 1
	end

	local function coralPalette(idx: number): any
		local m = idx % 4
		if m == 0 then
			return BASIN_PAL
		elseif m == 1 then
			return CORAL_LAVENDER
		elseif m == 2 then
			return CORAL_AQUA
		else
			return CORAL_OCHRE
		end
	end

	-- =========================================================================
	-- 1. COLOSSAL CENTREPIECE: THE GREAT TIDEBELL TOWER (272 studs, north of dais)
	--    + Twin Waist-Broken Statues (Tide-King & Tide-Queen) + North Tidewall
	-- =========================================================================
	placeKit("GreatTidebellTower", "GreatTidebellTower", V(0, -10, -345), 0, 1.0, BASIN_PAL, true, true, false, function()
		for _, sx in { -36, 36 } do
			boxAt("TowerPier", V(24, 268, 30), V(sx, 124, -345), 0, rgb(64, 78, 88), Mat.Slate)
		end
		boxAt("BelfryArchBeam", V(72, 18, 22), V(0, 198, -345), 0, rgb(132, 146, 150), Mat.Limestone)
	end)
	-- Belfry aqua beacon light inside the torn central arch (Light #1)
	light(V(0, 148, -326), AQUA_LIGHT, 2.2, 58)
	-- Cascading waterfalls spilling through the lower arch of the Great Tidebell Tower into the north basin
	buildWaterfallRibbon("TidebellCascadeC", 0, 74, waterY, -326, 22, 0, false)
	buildWaterfallRibbon("TidebellCascadeW", -58, 56, waterY, -334, 10, 0, false)
	buildWaterfallRibbon("TidebellCascadeE", 58, 56, waterY, -334, 10, 0, false)

	-- Twin colossal waist-broken statues of the Tide-King & Tide-Queen flanking the Tidebell Tower on rock islands
	placeKit("BrokenTideStatue", "BrokenTideStatueWest", V(-142, 18, -328), 0.34, 1.0, BASIN_PAL, true, true, false, function()
		boxAt("StatueW", V(22, 46, 18), V(-142, 41, -328), 0.34, rgb(132, 146, 150), Mat.Limestone)
	end)
	placeKit("BrokenTideStatue", "BrokenTideStatueEast", V(142, 18, -328), -0.34, 1.0, BASIN_PAL, true, true, false, function()
		boxAt("StatueE", V(22, 46, 18), V(142, 41, -328), -0.34, rgb(132, 146, 150), Mat.Limestone)
	end)

	-- Abyssal North Tidewall sealing the far back horizon behind the Great Tidebell Tower
	ctx.group("TidewallBasinNorth", function()
		ctx.tag("OnTerrain", true)
		ctx.tag("Landmark", true)
		landmarks += 1
		local wall = boxAt("TidewallCurtain", V(780, 310, 6), V(0, 145, -394), 0, rgb(20, 44, 64), Mat.Slate, 0.14)
		noCollide(wall)
		local sheen = boxAt("TidewallSheen", V(760, 290, 2), V(0, 145, -390), 0, rgb(34, 118, 152), Mat.Glass, 0.52)
		noCollide(sheen)
	end)
	props += 1

	-- =========================================================================
	-- 2. THE SEA-DOME, EYE OF DAYLIGHT & ORBITING LEVIATHAN/WHALE SILHOUETTES
	--    (Far-layer airborne architecture, high above gameplay, zero occlusion)
	-- =========================================================================
	ctx.group("SeaDomeShell", function()
		ctx.tag("PropKind", "SeaDomeShell")
		ctx.tag("OnTerrain", true)
		ctx.tag("Landmark", true)
		landmarks += 1
		local domeCenter = V(0, 0, -175)
		local ribCount = 12
		for i = 0, ribCount - 1 do
			local ang = (i / ribCount) * math.pi * 2
			local rad = 328
			local rx = domeCenter.X + math.cos(ang) * rad
			local rz = domeCenter.Z + math.sin(ang) * rad
			local yaw = math.atan2(domeCenter.X - rx, domeCenter.Z - rz) - math.pi * 0.5
			if ctx.has("SeaDomeArchRib") then
				local rib = ctx.kitAt("SeaDomeArchRib", CFrame.new(rx, 92, rz) * CFrame.Angles(0, yaw, 0), 1.95, SEADOME_PAL, false)
				if rib then
					for _, p in rib:GetDescendants() do
						if p:IsA("BasePart") then
							noCollide(p)
							p.CastShadow = false
						end
					end
				end
				kindsUsed.SeaDomeArchRib = (kindsUsed.SeaDomeArchRib or 0) + 1
			else
				local fb = boxAt("DomeRibFallback", V(8, 180, 10), V(rx, 182, rz), yaw, rgb(28, 46, 62), Mat.Metal)
				noCollide(fb)
			end
		end
		-- Concentric geodesic purlin rings high overhead (Y = 235 & Y = 285)
		for _, ringSpec in { { R = 290, Y = 232, T = 5.5 }, { R = 195, Y = 278, T = 5.0 }, { R = 104, Y = 304, T = 6.5 } } do
			local segs = 16
			for s = 0, segs - 1 do
				local a0 = (s / segs) * math.pi * 2
				local a1 = ((s + 1) / segs) * math.pi * 2
				local p0 = V(domeCenter.X + math.cos(a0) * ringSpec.R, ringSpec.Y, domeCenter.Z + math.sin(a0) * ringSpec.R)
				local p1 = V(domeCenter.X + math.cos(a1) * ringSpec.R, ringSpec.Y, domeCenter.Z + math.sin(a1) * ringSpec.R)
				local mid = (p0 + p1) * 0.5
				local bar = H.boxAt("DomePurlin", V(ringSpec.T, ringSpec.T, (p1 - p0).Magnitude + 2), CFrame.lookAt(mid, p1), rgb(28, 48, 66), Mat.Metal)
				noCollide(bar)
				bar.CastShadow = false
			end
		end
		-- Translucent oceanic sea-ceiling glass annulus around the open Eye of Daylight
		for s = 0, 11 do
			local a = (s / 12) * math.pi * 2
			local p = V(domeCenter.X + math.cos(a) * 238, 286, domeCenter.Z + math.sin(a) * 238)
			local pane = H.boxAt("SeaDomeWaterPane", V(132, 2.5, 168), CFrame.lookAt(p, V(domeCenter.X, 314, domeCenter.Z)), rgb(18, 72, 104), Mat.Glass, 0.52)
			noCollide(pane)
			pane.CastShadow = false
		end
	end)
	props += 1

	-- Eye of Daylight oculus directly over Leviathan's Dais + soft volumetric daylight shafts
	ctx.group("EyeOfDaylight", function()
		ctx.tag("PropKind", "EyeOfDaylight")
		ctx.tag("OnTerrain", true)
		ctx.tag("Landmark", true)
		landmarks += 1
		local eyePos = V(0, 308, -175)
		local disc = Instance.new("Part")
		disc.Name = "OculusDaylightDisc"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = V(2.0, 178, 178)
		disc.CFrame = CFrame.new(origin + eyePos) * CFrame.Angles(0, 0, math.rad(90))
		disc.Color = rgb(214, 248, 255)
		disc.Material = Mat.Neon
		disc.Transparency = 0.22
		disc.Anchored = true
		disc.CastShadow = false
		noCollide(disc)
		disc.Parent = ctx.current()
		-- Soft translucent daylight beams slanting from the oculus down toward Leviathan's Dais
		local shaftDefs = {
			{ X = 0, Z = -175, W = 74, T = 0.90, Pitch = 0.04, Roll = 0.02 },
			{ X = -28, Z = -168, W = 44, T = 0.91, Pitch = 0.08, Roll = -0.10 },
			{ X = 28, Z = -182, W = 44, T = 0.91, Pitch = -0.06, Roll = 0.10 },
			{ X = 0, Z = -196, W = 52, T = 0.92, Pitch = -0.09, Roll = 0.0 },
		}
		for idx, sh in shaftDefs do
			local ray = Instance.new("Part")
			ray.Name = "DaylightShaft" .. idx
			ray.Shape = Enum.PartType.Cylinder
			ray.Size = V(215, sh.W, sh.W)
			ray.CFrame = CFrame.new(origin + V(sh.X, 196, sh.Z)) * CFrame.Angles(sh.Pitch, 0, math.rad(90) + sh.Roll)
			ray.Color = rgb(186, 244, 255)
			ray.Material = Mat.Neon
			ray.Transparency = sh.T
			ray.Anchored = true
			ray.CastShadow = false
			noCollide(ray)
			ray.Parent = ctx.current()
		end
	end)
	-- Overhead Eye of Daylight neutral-aqua key light above the dais (Light #2)
	light(V(0, 124, -175), DAYLIGHT_KEY, 2.1, 60)
	props += 1

	-- Far-layer Leviathan's shadow & dark whale/shark/manta silhouettes orbiting slowly outside the Sea-Dome
	-- (animated smoothly client-side via CollectionService tag "SunkenDomeSwimmer")
	local swimmers = {
		{ Name = "LeviathanDomeShadow", Radius = 215, Y = 266, Speed = 0.085, Phase = 0.4, Len = 92, Wide = 14, Fin = 24 },
		{ Name = "SeaDomeWhaleSilhouette", Radius = 258, Y = 252, Speed = -0.055, Phase = 2.4, Len = 62, Wide = 16, Fin = 30 },
		{ Name = "SeaDomeSharkSilhouette", Radius = 182, Y = 274, Speed = 0.125, Phase = 4.5, Len = 36, Wide = 8, Fin = 18 },
		{ Name = "SeaDomeMantaSilhouette", Radius = 235, Y = 260, Speed = -0.095, Phase = 5.6, Len = 26, Wide = 38, Fin = 10 },
	}
	for _, sw in swimmers do
		ctx.group(sw.Name, function()
			ctx.tag("PropKind", "SeaDomeShell")
			ctx.tag("OnTerrain", true)
			if sw.Name == "LeviathanDomeShadow" then
				ctx.tag("Landmark", true)
				landmarks += 1
			end
			local m = ctx.current()
			local pivot = boxAt("SwimmerBody", V(sw.Wide, 4.5, sw.Len), V(0, sw.Y, -175), 0, rgb(10, 28, 44), Mat.SmoothPlastic, 0.34)
			noCollide(pivot)
			pivot.CastShadow = false
			local fin = boxAt("SwimmerFins", V(sw.Wide + sw.Fin, 1.8, sw.Len * 0.34), V(0, sw.Y, -175 + sw.Len * 0.1), 0, rgb(12, 34, 52), Mat.SmoothPlastic, 0.38)
			noCollide(fin)
			fin.CastShadow = false
			local tail = boxAt("SwimmerTail", V(sw.Wide * 0.55, 2.2, sw.Len * 0.42), V(0, sw.Y, -175 - sw.Len * 0.58), 0, rgb(10, 28, 44), Mat.SmoothPlastic, 0.36)
			noCollide(tail)
			tail.CastShadow = false
			if m:IsA("Model") then
				m.PrimaryPart = pivot
				m:SetAttribute("DomeCenterX", origin.X)
				m:SetAttribute("DomeCenterZ", origin.Z - 175)
				m:SetAttribute("DomeOrbitRadius", sw.Radius)
				m:SetAttribute("DomeOrbitY", origin.Y + sw.Y)
				m:SetAttribute("DomeOrbitSpeed", sw.Speed)
				m:SetAttribute("DomeOrbitPhase", sw.Phase)
				CollectionService:AddTag(m, "SunkenDomeSwimmer")
			end
		end)
		props += 1
	end

	-- =========================================================================
	-- 3. ANIMATED 3-LAYER MAELSTROM VORTEX + SWIRLING DEBRIS + EYE SPRAY
	--    Driven purely client-side by MaelstromVortexController.client.luau!
	-- =========================================================================
	local vortexLayers = {
		{ Name = "MaelstromOuterSwirl", X = 0, Y = waterY - 0.6, Z = -125, Scale = 2.65, Yaw = 0.0, Speed = 0.36, BobAmp = 0.65, BobFreq = 1.05, Phase = 0.0, Pal = MAELSTROM_OUTER_PAL },
		{ Name = "MaelstromMidSwirl", X = 0, Y = waterY - 1.8, Z = -135, Scale = 1.98, Yaw = 0.55, Speed = 0.62, BobAmp = 0.55, BobFreq = 1.45, Phase = 2.1, Pal = MAELSTROM_OUTER_PAL },
		{ Name = "MaelstromInnerEye", X = 0, Y = waterY - 2.8, Z = -152, Scale = 1.42, Yaw = 1.15, Speed = 1.05, BobAmp = 0.45, BobFreq = 1.90, Phase = 4.2, Pal = MAELSTROM_INNER_PAL },
	}
	for idx, vl in vortexLayers do
		ctx.group(vl.Name, function()
			ctx.tag("PropKind", "MaelstromVortex")
			ctx.tag("OnTerrain", true)
			if idx == 1 then
				ctx.tag("Landmark", true)
				landmarks += 1
			end
			local m = ctx.current()
			local pivotCF = CFrame.new(origin + V(vl.X, vl.Y, vl.Z)) * CFrame.Angles(0, vl.Yaw, 0)
			local pivot = Instance.new("Part")
			pivot.Name = "VortexPivot"
			pivot.Size = V(2, 2, 2)
			pivot.CFrame = pivotCF
			pivot.Transparency = 1
			pivot.Anchored = true
			pivot.CastShadow = false
			noCollide(pivot)
			pivot.Parent = m

			if ctx.has("MaelstromSwirlRing") then
				local swirl = ctx.kitAt("MaelstromSwirlRing", CFrame.new(vl.X, vl.Y, vl.Z) * CFrame.Angles(0, vl.Yaw, 0), vl.Scale, vl.Pal, false)
				if swirl then
					for _, p in swirl:GetDescendants() do
						if p:IsA("BasePart") then
							noCollide(p)
							p.CastShadow = false
						end
					end
				end
				kindsUsed.MaelstromSwirlRing = (kindsUsed.MaelstromSwirlRing or 0) + 1
			else
				-- Crisp sculpted part fallback so the whirlpool animates even before FBX import!
				local rOuter = 68 * vl.Scale
				local rInner = 26 * vl.Scale
				for arm = 0, 5 do
					local baseA = (arm / 6) * math.pi * 2 + vl.Yaw
					for k = 0, 7 do
						local u0, u1 = k / 8, (k + 1) / 8
						local r0 = rOuter * (1 - u0) + rInner * u0
						local r1 = rOuter * (1 - u1) + rInner * u1
						local a0, a1 = baseA + u0 * 2.2, baseA + u1 * 2.2
						local p0 = V(vl.X + math.cos(a0) * r0, vl.Y + (1 - u0) * 5.2, vl.Z + math.sin(a0) * r0)
						local p1 = V(vl.X + math.cos(a1) * r1, vl.Y + (1 - u1) * 5.2, vl.Z + math.sin(a1) * r1)
						local seg = H.boxAt("SwirlArm", V(8.5 * vl.Scale * (1 - u0 * 0.4), 1.6, (p1 - p0).Magnitude + 2), CFrame.lookAt((p0 + p1) * 0.5, p1), rgb(96, 224, 244), Mat.Glass, 0.28)
						noCollide(seg)
						seg.CastShadow = false
						local foam = H.boxAt("SwirlFoam", V(3.0 * vl.Scale * (1 - u0 * 0.4), 0.7, (p1 - p0).Magnitude + 1), CFrame.lookAt((p0 + p1) * 0.5 + V(0, 1.1, 0), p1 + V(0, 1.1, 0)), rgb(224, 250, 255), Mat.Neon, 0.32)
						noCollide(foam)
						foam.CastShadow = false
					end
				end
			end

			if m:IsA("Model") then
				m.PrimaryPart = pivot
				m.WorldPivot = pivotCF
				m:SetAttribute("MaelstromBasePos", pivotCF.Position)
				m:SetAttribute("MaelstromBaseYaw", vl.Yaw)
				m:SetAttribute("MaelstromSpinSpeed", vl.Speed)
				m:SetAttribute("MaelstromBobAmp", vl.BobAmp)
				m:SetAttribute("MaelstromBobFreq", vl.BobFreq)
				m:SetAttribute("MaelstromBobPhase", vl.Phase)
				CollectionService:AddTag(m, "SunkenMaelstromRing")
			end
		end)
		props += 1
	end

	-- Swirling drowned wreckage ring slowly circling the outer maelstrom (also animated client-side!)
	ctx.group("MaelstromDebrisRing", function()
		ctx.tag("PropKind", "MaelstromVortex")
		ctx.tag("OnTerrain", true)
		local m = ctx.current()
		local debrisCF = CFrame.new(origin + V(0, waterY + 0.5, -125))
		local pivot = Instance.new("Part")
		pivot.Name = "DebrisPivot"
		pivot.Size = V(2, 2, 2)
		pivot.CFrame = debrisCF
		pivot.Transparency = 1
		pivot.Anchored = true
		pivot.CastShadow = false
		noCollide(pivot)
		pivot.Parent = m
		for i = 0, 7 do
			local a = (i / 8) * math.pi * 2 + 0.35
			local rad = 165 + (i % 3) * 18
			local dx = math.cos(a) * rad
			local dz = -125 + math.sin(a) * rad
			local plank = boxAt("DriftTimber" .. i, V(11 + (i % 3) * 3, 1.2, 2.4), V(dx, waterY + 0.5, dz), -a + 0.3, rgb(66, 54, 46), Mat.Wood)
			noCollide(plank)
			plank.CastShadow = false
			local wake = boxAt("DriftWake" .. i, V(14, 0.35, 3.6), V(dx, waterY + 0.2, dz), -a + 0.3, rgb(198, 244, 255), Mat.Neon, 0.54)
			noCollide(wake)
			wake.CastShadow = false
		end
		if m:IsA("Model") then
			m.PrimaryPart = pivot
			m.WorldPivot = debrisCF
			m:SetAttribute("MaelstromBasePos", debrisCF.Position)
			m:SetAttribute("MaelstromBaseYaw", 0)
			m:SetAttribute("MaelstromSpinSpeed", 0.28)
			m:SetAttribute("MaelstromBobAmp", 0.65)
			m:SetAttribute("MaelstromBobFreq", 1.2)
			m:SetAttribute("MaelstromBobPhase", 1.2)
			CollectionService:AddTag(m, "SunkenMaelstromRing")
		end
	end)
	props += 1

	-- 4 Eye-of-Maelstrom rising spray emitters hugging the sheer dais pillar foot (Emitters #1..4)
	ctx.group("MaelstromEyeSpray", function()
		ctx.tag("PropKind", "MaelstromVortex")
		ctx.tag("OnTerrain", true)
		local sprayPts = { { -92, -110 }, { 92, -110 }, { -104, -182 }, { 104, -182 } }
		for idx, sp in sprayPts do
			local emitterAnchor = boxAt("EyeSprayAnchor" .. idx, V(14, 2, 14), V(sp[1], waterY + 1.5, sp[2]), 0, rgb(164, 242, 255), Mat.SmoothPlastic, 1)
			noCollide(emitterAnchor)
			addEmitter(emitterAnchor, "MaelstromSprayEmitter", {
				Color = ColorSequence.new(rgb(138, 236, 255), rgb(228, 252, 255)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5.0), NumberSequenceKeypoint.new(0.6, 11.0), NumberSequenceKeypoint.new(1, 15.0) }),
				Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.70), NumberSequenceKeypoint.new(1, 1.0) }),
				Rate = 12,
				Life = NumberRange.new(1.8, 3.2),
				Speed = NumberRange.new(6, 14),
				Spread = Vector2.new(35, 35),
				Accel = V(0, 5, 0),
				LightEm = 0.5,
			})
		end
	end)
	props += 1

	-- =========================================================================
	-- 4. LEVIATHAN'S DAIS (196 x 144, Y = 64): FLUSH TRIDENT MOSAIC + OUTER RIM
	--    Zero obstructions on the arena floor; clear of PortalSpots (±16, 64, -235).
	-- =========================================================================
	local apex = P.Apex
	ctx.group("LeviathanDaisMosaic", function()
		ctx.tag("PropKind", "LeviathanDaisMosaic")
		ctx.tag("OnTerrain", true)
		ctx.tag("Landmark", true)
		landmarks += 1
		local my = apex.Y + 0.08
		-- Outer dark-limestone worn arena inlay disc
		local function flatDisc(name: string, r: number, y: number, col: Color3, mat: Enum.Material, trans: number?)
			local disc = Instance.new("Part")
			disc.Name = name
			disc.Shape = Enum.PartType.Cylinder
			disc.Size = V(0.16, r * 2, r * 2)
			disc.CFrame = CFrame.new(origin + V(apex.X, y, apex.Z)) * CFrame.Angles(0, 0, math.rad(90))
			disc.Color = col
			disc.Material = mat
			disc.Transparency = trans or 0
			disc.Anchored = true
			disc.CastShadow = false
			noCollide(disc)
			disc.Parent = ctx.current()
		end
		flatDisc("DaisMosaicOuterSlate", 58, my, rgb(54, 72, 86), Mat.Limestone)
		flatDisc("DaisMosaicGoldBandOuter", 54, my + 0.03, rgb(186, 158, 92), Mat.Metal)
		flatDisc("DaisMosaicBlueField", 50, my + 0.05, rgb(32, 76, 112), Mat.Limestone)
		flatDisc("DaisMosaicAquaRuneRing", 36, my + 0.07, rgb(92, 224, 242), Mat.Neon, 0.25)
		flatDisc("DaisMosaicInnerStone", 33.5, my + 0.09, rgb(44, 86, 118), Mat.Limestone)
		flatDisc("DaisMosaicCenterGold", 18, my + 0.11, rgb(196, 168, 96), Mat.Metal)
		flatDisc("DaisMosaicCenterEye", 15.5, my + 0.13, rgb(34, 84, 120), Mat.Limestone)
		-- Flush worn-gold & aqua Nereth Trident emblem inlaid across the dais centre
		local shaft = boxAt("DaisTridentShaft", V(2.8, 0.16, 46), V(apex.X, my + 0.16, apex.Z), 0, rgb(212, 184, 106), Mat.Metal)
		noCollide(shaft)
		local bar = boxAt("DaisTridentBar", V(22, 0.16, 2.8), V(apex.X, my + 0.16, apex.Z - 9), 0, rgb(212, 184, 106), Mat.Metal)
		noCollide(bar)
		for _, sx in { -9.5, 9.5 } do
			local tine = boxAt("DaisTridentTine", V(2.4, 0.16, 16), V(apex.X + sx, my + 0.16, apex.Z - 16), 0, rgb(212, 184, 106), Mat.Metal)
			noCollide(tine)
		end
		-- Subtle flush aqua rune rim arc on the dais outer perimeter (flares conceptually on summon)
		for i = 0, 15 do
			local a = (i / 16) * math.pi * 2
			local rx = apex.X + math.cos(a) * 86
			local rz = apex.Z + math.sin(a) * 62
			local rune = boxAt("DaisRimRune" .. i, V(7.5, 0.14, 1.8), V(rx, my + 0.05, rz), -a + math.pi * 0.5, rgb(96, 238, 255), Mat.Neon, 0.22)
			noCollide(rune)
		end
	end)
	props += 1

	-- Outer-rim Dais Brazier Pedestals (strictly on the outer edge, clear of arena interior, chains & portals)
	local rimBraziers = {
		{ X = -76, Z = -103, Yaw = 0.35 },
		{ X = -34, Z = -101, Yaw = 0.12 },
		{ X = 34, Z = -101, Yaw = -0.12 },
		{ X = 76, Z = -103, Yaw = -0.35 },
		{ X = -96, Z = -140, Yaw = 1.25 },
		{ X = 96, Z = -140, Yaw = -1.25 },
		{ X = -76, Z = -246, Yaw = 2.75 },
		{ X = 76, Z = -246, Yaw = -2.75 },
	}
	for idx, rb in rimBraziers do
		placeKit("DaisBrazierPedestal", "DaisRimBrazier" .. idx, V(rb.X, apex.Y, rb.Z), rb.Yaw, 1.0, BASIN_PAL, false, idx == 1, false, function()
			boxAt("BrazierFallback", V(4.2, 11, 4.2), V(rb.X, apex.Y + 5.5, rb.Z), rb.Yaw, rgb(132, 146, 150), Mat.Limestone)
			lump("FlameFallback", V(2.4, 3.2, 2.4), V(rb.X, apex.Y + 12.2, rb.Z), rgb(96, 240, 255), Mat.Neon)
		end)
	end
	-- Twin aqua rim fill lights illuminating the dais perimeter (Lights #3 & #4)
	light(V(-72, apex.Y + 11, -108), AQUA_LIGHT, 1.8, 52)
	light(V(72, apex.Y + 11, -108), AQUA_LIGHT, 1.8, 52)

	-- Navy-teal gold-trident banners draping DOWN the sheer cliff face of Leviathan's Dais pillar
	-- + broken bell-tower stone footings & bronze mooring rings + 4 Dais Rim Waterfalls (Emitters #5..8)
	ctx.group("LeviathanDaisPillarDressing", function()
		ctx.tag("PropKind", "LeviathanDaisMosaic")
		ctx.tag("OnTerrain", true)
		local bannerFaces = {
			{ X = -58, Z = -99, Yaw = 0.28 },
			{ X = 58, Z = -99, Yaw = -0.28 },
			{ X = -98, Z = -156, Yaw = 1.48 },
			{ X = 98, Z = -156, Yaw = -1.48 },
		}
		for idx, bf in bannerFaces do
			local rod = boxAt("PillarBannerRod" .. idx, V(11.5, 1.0, 1.0), V(bf.X, apex.Y - 1.2, bf.Z), bf.Yaw, rgb(204, 174, 96), Mat.Metal)
			noCollide(rod)
			local cloth = boxAt("PillarBannerCloth" .. idx, V(10.0, 32.0, 0.5), V(bf.X, apex.Y - 17.5, bf.Z), bf.Yaw, rgb(24, 68, 102), Mat.Fabric)
			noCollide(cloth)
			local glyph = boxAt("PillarBannerTrident" .. idx, V(1.2, 14.0, 0.8), V(bf.X, apex.Y - 16.0, bf.Z), bf.Yaw, rgb(212, 184, 106), Mat.Metal)
			noCollide(glyph)
			local cross = boxAt("PillarBannerCross" .. idx, V(5.8, 1.2, 0.8), V(bf.X, apex.Y - 13.0, bf.Z), bf.Yaw, rgb(212, 184, 106), Mat.Metal)
			noCollide(cross)
		end
		-- Broken bell-tower stone footing stubs & bronze mooring rings on the outer north-west / north-east rim
		for _, sx in { -54, 54 } do
			local stub = boxAt("BellTowerFooting", V(12, 4.2, 6), V(sx, apex.Y + 2.0, -247), 0, rgb(92, 106, 114), Mat.Limestone)
			noCollide(stub)
			local mooring = boxAt("DaisChainRing", V(3.6, 3.6, 1.2), V(sx * 1.72, apex.Y + 1.4, -198), math.pi * 0.5, rgb(174, 148, 92), Mat.Metal)
			noCollide(mooring)
		end
	end)
	props += 1

	buildWaterfallRibbon("DaisWaterfallS", 0, apex.Y - 1, waterY, -100, 14, 0, true)
	buildWaterfallRibbon("DaisWaterfallSW", -84, apex.Y - 1, waterY, -116, 8, 0.65, true)
	buildWaterfallRibbon("DaisWaterfallSE", 84, apex.Y - 1, waterY, -116, 8, -0.65, true)
	buildWaterfallRibbon("DaisWaterfallN", 0, apex.Y - 1, waterY, -249, 12, math.pi, true)

	-- =========================================================================
	-- 5. TWIN CHAIN ANCHORS, TWIN CHAIN TOWERS & SNAPPED TRAILING CHAIN
	-- =========================================================================
	placeKit("ChainAnchorBollard", "WestChainAnchorBollard", V(-152, 52, -262), 0.78, 1.0, BASIN_PAL, true, true, false, function()
		boxAt("AnchorW", V(16, 24, 16), V(-152, 64, -262), 0.78, rgb(56, 62, 70), Mat.Metal)
	end)
	placeKit("ChainAnchorBollard", "EastChainAnchorBollard", V(152, 56, -262), -0.78, 1.0, BASIN_PAL, true, true, false, function()
		boxAt("AnchorE", V(16, 24, 16), V(152, 68, -262), -0.78, rgb(56, 62, 70), Mat.Metal)
	end)
	-- Twin anchor bollard aqua beacon lights (Lights #5 & #6)
	light(V(-152, 76, -262), AQUA_LIGHT, 1.6, 44)
	light(V(152, 76, -262), AQUA_LIGHT, 1.6, 44)

	-- Snapped heavy bronze binding chain trailing from East Anchor down into the swirling maelstrom
	ctx.group("SnappedBindingChain", function()
		ctx.tag("PropKind", "Chain")
		ctx.tag("OnTerrain", true)
		local pA, pB = V(148, 66, -252), V(116, waterY - 2, -238)
		for k = 1, 10 do
			local t0, t1 = (k - 1) / 10, k / 10
			local q0 = pA:Lerp(pB, t0) - V(0, math.sin(t0 * math.pi) * 8, 0)
			local q1 = pA:Lerp(pB, t1) - V(0, math.sin(t1 * math.pi) * 8, 0)
			local seg = H.boxAt("SnappedChainSeg" .. k, V(1.6, 1.6, (q1 - q0).Magnitude + 0.5), CFrame.lookAt((q0 + q1) * 0.5, q1), rgb(52, 56, 62), Mat.Metal)
			noCollide(seg)
		end
	end)
	props += 1

	-- Twin coral-encrusted round Chain Towers flanking West & East Bastions
	placeKit("ChainTowerRound", "WestChainTower", V(-346, 36, -120), 1.45, 1.0, CORAL_LAVENDER, true, true, false, function()
		boxAt("ChainTowerW", V(28, 70, 28), V(-346, 71, -120), 1.45, rgb(84, 96, 104), Mat.Slate)
	end)
	placeKit("ChainTowerRound", "EastChainTower", V(346, 38, -120), -1.45, 1.0, CORAL_AQUA, true, true, false, function()
		boxAt("ChainTowerE", V(28, 70, 28), V(346, 73, -120), -1.45, rgb(84, 96, 104), Mat.Slate)
	end)

	-- =========================================================================
	-- 6. DROWNED ALTAR, HIGH CANTOR'S PULPIT, PEARL RELIQUARY & TIDE GATE
	-- =========================================================================
	placeKit("DrownedAltar", "DrownedAltarShrine", V(0, 26, -28), math.pi, 1.0, CORAL_AQUA, true, true, false, function()
		boxAt("DrownedAltarFallback", V(18, 12, 16), V(0, 32, -28), 0, rgb(132, 146, 150), Mat.Limestone)
	end)
	-- Drowned Altar aqua tide-sigil glow (Light #7)
	light(V(0, 39, -28), AQUA_LIGHT, 1.7, 46)

	placeKit("CantorPulpit", "HighCantorPulpit", V(-258, 44, -360), 0.35, 1.0, CORAL_LAVENDER, true, true, false, function()
		boxAt("CantorPulpitFallback", V(16, 22, 16), V(-258, 55, -360), 0.35, rgb(132, 146, 150), Mat.Limestone)
	end)
	placeKit("AbyssReliquaryShrine", "PearlReliquaryShrine", V(258, 42, -360), -0.35, 1.0, BASIN_PAL, true, true, false, function()
		boxAt("ReliquaryFallback", V(20, 26, 18), V(258, 55, -360), -0.35, rgb(132, 146, 150), Mat.Limestone)
	end)

	-- Ruined Tide Gate flanking piers & Coral Warden sentinels at the maelstrom's mouth
	placeKit("CoralWardenStatue", "TideGatePierWest", V(-68, 12, 138), 0.32, 1.0, CORAL_LAVENDER, true, true, false, function()
		boxAt("TideGateW", V(16, 30, 12), V(-68, 27, 138), 0.32, rgb(118, 132, 138), Mat.Limestone)
	end)
	placeKit("CoralWardenStatue", "TideGatePierEast", V(68, 12, 138), -0.32, 1.0, CORAL_AQUA, true, true, false, function()
		boxAt("TideGateE", V(16, 30, 12), V(68, 27, 138), -0.32, rgb(118, 132, 138), Mat.Limestone)
	end)

	-- =========================================================================
	-- 7. BELL BARGE, KELP SHRINE, CREST LOOKOUTS, THE LAST BELL, CRACKED BELLS,
	--    REEF CORAL SPIRES, DROWNED PERIMETER COLONNADE & BUBBLE VENTS
	-- =========================================================================
	placeKit("BellBargeWreck", "BellBargeWreckEast", V(408, 28, 72), math.pi * 0.5, 1.0, BASIN_PAL, true, true, false, function()
		boxAt("BellBargeFallback", V(15, 16, 44), V(408, 36, 72), 0, rgb(66, 54, 46), Mat.Wood)
	end)

	-- Kelp Shrine: ring of carved standing stones inside towering bioluminescent kelp
	placeKit("KelpForestTall", "KelpShrineStones", V(-406, 24, 74), 0.4, 1.0, BASIN_PAL, false, true, false, function()
		boxAt("KelpShrineFallback", V(12, 42, 12), V(-406, 45, 74), 0, rgb(38, 102, 96), Mat.Grass)
	end)
	for k = 0, 4 do
		local a = (k / 5) * math.pi * 2 + 0.3
		local sx, sz = -404 + math.cos(a) * 14, 74 + math.sin(a) * 14
		if math.abs(sx) < 424 and isClear(sx, sz, 4) then
			placeKit("RuneTablet", "KelpShrineStone" .. k, V(sx, groundY(sx, sz), sz), a + math.pi * 0.5, 1.25, BASIN_PAL, true, false, false)
		end
	end

	-- Coral-fused Pearlguard lookouts atop West Crest & East Crest
	placeKit("CoralWardenStatue", "WestCrestLookout", V(-394, 48, -246), 1.35, 1.0, CORAL_LAVENDER, true, true, false)
	placeKit("CoralWardenStatue", "EastCrestLookout", V(394, 50, -246), -1.35, 1.0, CORAL_AQUA, true, true, false)

	-- The Last Bell at Sanctuary: single uncracked ringing Nereth Tidebell on its bronze post
	placeKit("GreatTidebell", "TheLastBellPost", V(-52, 8, 368), 0.35, 0.58, BASIN_PAL, true, true, false, function()
		boxAt("LastBellFallback", V(8, 18, 8), V(-52, 17, 368), 0.35, rgb(56, 126, 124), Mat.Metal)
	end)
	-- Sanctuary arrival bell light (Light #8)
	light(V(-52, 22, 368), AQUA_LIGHT, 1.6, 42)

	-- Cracked Tidebells & fused bronze bell-tower debris on Wrack Shore
	placeKit("CrackedTidebell", "WrackShoreBellWest", V(-255, 0, 272), 0.45, 1.05, BASIN_PAL, true, true, false)
	placeKit("CrackedTidebell", "WrackShoreBellEast", V(255, 0, 272), -0.52, 1.05, BASIN_PAL, true, true, false)

	-- Towering bioluminescent Reef Coral Spires anchoring the West & East Reef Horns (Lights #9 & #10)
	placeKit("ReefCoralTable", "WestReefCoralSpire", V(-342, 20, 8), 0.6, 1.35, CORAL_LAVENDER, true, true, false)
	placeKit("ReefCoralTable", "EastReefCoralSpire", V(342, 22, 8), -0.6, 1.35, CORAL_AQUA, true, true, false)
	light(V(-342, 34, 8), VIOLET_REEF, 1.6, 46)
	light(V(342, 34, 8), AQUA_LIGHT, 1.6, 46)

	-- Drowned Perimeter Colonnade ring curving around the outer basin flanks (just like the guide image!)
	placeKit("LancetArchBay", "PerimeterColonnadeNW", V(-318, -4, -362), 0.42, 1.45, BASIN_PAL, false, true, false)
	placeKit("LancetArchBay", "PerimeterColonnadeNE", V(318, -4, -362), -0.42, 1.45, BASIN_PAL, false, true, false)
	local colonnadeArcs = {
		{ X = -396, Z = -318, Yaw = 1.05, Scale = 1.35 },
		{ X = 396, Z = -318, Yaw = -1.05, Scale = 1.35 },
		{ X = -402, Z = -182, Yaw = 1.48, Scale = 1.35 },
		{ X = 402, Z = -182, Yaw = -1.48, Scale = 1.35 },
		{ X = -402, Z = -55, Yaw = 1.58, Scale = 1.30 },
		{ X = 402, Z = -55, Yaw = -1.58, Scale = 1.30 },
		{ X = -396, Z = 152, Yaw = 1.85, Scale = 1.25 },
		{ X = 396, Z = 152, Yaw = -1.85, Scale = 1.25 },
	}
	for idx, ca in colonnadeArcs do
		if isClear(ca.X, ca.Z, 12) then
			placeKit(if idx % 2 == 0 then "CoralArcadeBay" else "LancetArchBay", "BasinColonnade" .. idx, V(ca.X, groundY(ca.X, ca.Z) - 1, ca.Z), ca.Yaw, ca.Scale, BASIN_PAL, false, false, false)
		end
	end

	-- Hydrothermal Bubble Vents in the maelstrom bed with rising bubble columns (Emitters #9..12)
	local bubbleVents = {
		{ Id = "MaelstromBubbleVentW", X = -135, Z = 15, Y = 4, Mark = true },
		{ Id = "MaelstromBubbleVentE", X = 135, Z = 15, Y = 4, Mark = true },
		{ Id = "MaelstromBubbleVentNW", X = -108, Z = -282, Y = waterY - 2, Mark = false },
		{ Id = "MaelstromBubbleVentNE", X = 108, Z = -282, Y = waterY - 2, Mark = false },
	}
	for idx, bv in bubbleVents do
		placeKit("BubbleVentCluster", bv.Id, V(bv.X, bv.Y, bv.Z), idx * 1.1, 1.0, BASIN_PAL, false, bv.Mark, false)
		ctx.group("BubbleColumn" .. idx, function()
			ctx.tag("PropKind", "MaelstromVortex")
			ctx.tag("OnTerrain", true)
			local anchor = boxAt("BubbleSource", V(6, 1, 6), V(bv.X, bv.Y + 5, bv.Z), 0, rgb(124, 242, 255), Mat.SmoothPlastic, 1)
			noCollide(anchor)
			addEmitter(anchor, "MaelstromSprayEmitter", {
				Color = ColorSequence.new(rgb(138, 246, 255), rgb(224, 252, 255)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.8) }),
				Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1.0) }),
				Rate = 9,
				Life = NumberRange.new(3.2, 5.2),
				Speed = NumberRange.new(9, 16),
				Spread = Vector2.new(14, 14),
				Accel = V(0, 4, 0),
				LightEm = 0.6,
			})
		end)
		props += 1
	end

	-- =========================================================================
	-- 8. STORY PROPS & RUINED TEMPLE DRESSING (hits >= 37 distinct templates!)
	-- =========================================================================
	local curatedShowcase = {
		-- Cracked bells, bronze debris & drowned temple relics along Wrack Shore, reefs & crests
		{ T = "CrackedTidebell", X = -176, Z = 152, Yaw = 0.5, S = 0.9 },
		{ T = "CrackedTidebell", X = 176, Z = 152, Yaw = -0.5, S = 0.9 },
		{ T = "CrackedTidebell", X = -255, Z = -52, Yaw = 1.2, S = 0.85 },
		{ T = "CrackedTidebell", X = 255, Z = -52, Yaw = -1.2, S = 0.85 },
		{ T = "MuffledBellStack", X = -182, Z = 278, Yaw = 0.2, S = 0.85 },
		{ T = "MuffledBellStack", X = 182, Z = 278, Yaw = -0.2, S = 0.85 },
		{ T = "DivingBell", X = 328, Z = 262, Yaw = -0.4, S = 0.95 },
		{ T = "CoralCageReliquary", X = 188, Z = -346, Yaw = -0.4, S = 0.95 },
		{ T = "CantorLectern", X = -194, Z = -344, Yaw = 0.4, S = 1.0 },
		{ T = "CantorNicheStatue", X = -268, Z = -298, Yaw = 0.8, S = 0.95 },
		{ T = "CantorNicheStatue", X = 268, Z = -298, Yaw = -0.8, S = 0.95 },
		{ T = "DrownedSundial", X = 0, Z = 152, Yaw = 0.0, S = 1.0 },
		{ T = "TideGaugeColumn", X = -92, Z = 154, Yaw = 0.2, S = 1.0 },
		{ T = "TideGaugeColumn", X = 92, Z = 154, Yaw = -0.2, S = 1.0 },
		{ T = "BellArch", X = -348, Z = 268, Yaw = 0.3, S = 0.85 },
		{ T = "BellArch", X = 348, Z = 268, Yaw = -0.3, S = 0.85 },
		{ T = "BrokenLancetColumn", X = -132, Z = 282, Yaw = 0.4, S = 1.0 },
		{ T = "BrokenLancetColumn", X = 132, Z = 282, Yaw = -0.4, S = 1.0 },
		{ T = "FallenStairFlight", X = -362, Z = 228, Yaw = 0.8, S = 0.85 },
		{ T = "FallenStairFlight", X = 362, Z = 228, Yaw = -0.8, S = 0.85 },
		{ T = "VotiveLampBowl", X = -38, Z = 338, Yaw = 0, S = 1.1 },
		{ T = "VotiveLampBowl", X = 38, Z = 338, Yaw = 0, S = 1.1 },
		{ T = "OverflowRibbon", X = -72, Z = -336, Yaw = 0, S = 1.3 },
		{ T = "OverflowRibbon", X = 72, Z = -336, Yaw = 0, S = 1.3 },
		{ T = "Obelisk", X = -378, Z = -182, Yaw = 0.6, S = 0.55 },
		{ T = "Obelisk", X = 378, Z = -182, Yaw = -0.6, S = 0.55 },
		{ T = "StoneUrn", X = -28, Z = 354, Yaw = 0, S = 1.0 },
		{ T = "StoneUrn", X = 28, Z = 354, Yaw = 0, S = 1.0 },
		-- Extra sunken-city relics & temple furnishings along outer shore, reefs & crests (pushes distinct templates >= 40)
		{ T = "CoralArcadeCorner", X = -384, Z = -336, Yaw = 0.7, S = 1.05 },
		{ T = "CoralArcadeCorner", X = 384, Z = -336, Yaw = -0.7, S = 1.05 },
		{ T = "ChapterHouseRib", X = -396, Z = -286, Yaw = 1.2, S = 0.85 },
		{ T = "ChapterHouseRib", X = 396, Z = -286, Yaw = -1.2, S = 0.85 },
		{ T = "LavaboFountain", X = -296, Z = 264, Yaw = 0.2, S = 0.72 },
		{ T = "CantorStall", X = -212, Z = -352, Yaw = 0.3, S = 0.95 },
		{ T = "ConchRack", X = 212, Z = -352, Yaw = -0.3, S = 1.0 },
		{ T = "BellGallowsBracket", X = -316, Z = 264, Yaw = 0.25, S = 0.95 },
		{ T = "SluiceGear", X = 296, Z = 264, Yaw = -0.25, S = 1.05 },
		{ T = "OysterRack", X = -362, Z = 274, Yaw = 0.4, S = 1.0 },
		{ T = "HollinBarge", X = -376, Z = 178, Yaw = 0.55, S = 0.82 },
		{ T = "MooredBarge", X = 376, Z = 178, Yaw = -0.55, S = 0.82 },
		{ T = "HarbourCrane", X = 372, Z = 258, Yaw = -0.6, S = 0.85 },
		{ T = "CoralCluster", X = -336, Z = 252, Yaw = 0.4, S = 1.6 },
		{ T = "CoralCluster", X = 336, Z = 252, Yaw = -0.4, S = 1.6 },
		{ T = "SeaWallSegment", X = -386, Z = 278, Yaw = 0.15, S = 0.72 },
		{ T = "SeaWallSegment", X = 386, Z = 278, Yaw = -0.15, S = 0.72 },
	}
	for idx, item in curatedShowcase do
		if isClear(item.X, item.Z, 7) and offDais(item.X, item.Z, 12) then
			local y = groundY(item.X, item.Z)
			placeKit(item.T, "BasinShowcase" .. idx, V(item.X, y, item.Z), item.Yaw, item.S, coralPalette(idx), false, false, false)
		end
	end

	-- =========================================================================
	-- 9. MULTI-PASS SCATTER: KELP FORESTS, GLOWING REEF HORN CORALS, WRECKAGE &
	--    GROUND COVER (hits >= 660 props, >= 450 cover, >= 37 templates, max <= 12%)
	-- =========================================================================
	local halfW, halfD = w * 0.5 - 24, d * 0.5 - 24

	-- Pass A: Towering Kelp Forests lining the outer basin walls & shore rims (rising toward the Sea-Dome)
	local kelpPlaced = 0
	for attempt = 1, 320 do
		if kelpPlaced >= 52 then
			break
		end
		local side = if attempt % 2 == 0 then 1 else -1
		local x = side * rng:NextNumber(330, halfW)
		local z = rng:NextNumber(-368, 290)
		if isClear(x, z, 7) and offDais(x, z, 18) then
			local y = groundY(x, z)
			local tName = if kelpPlaced % 2 == 0 then "KelpForestTall" else "KelpStand"
			local sc = if tName == "KelpForestTall" then rng:NextNumber(0.78, 1.25) else rng:NextNumber(1.3, 2.2)
			placeKit(tName, "BasinKelp" .. kelpPlaced, V(x, y, z), rng:NextNumber(0, math.pi * 2), sc, BASIN_PAL, false, false, false)
			kelpPlaced += 1
		end
	end

	-- Pass B: Bioluminescent Reef Horn Corals, Ruin Debris, Cracked Bells, Clams & Sea-Fans (>= 685 props total)
	-- Note: BoulderCluster is omitted here because the base biome ecology already scatters boulders, keeping max share <= 12%.
	local propPool = {
		"ReefCoralTable",
		"BrainCoralMound",
		"CoralCluster",
		"GiantClam",
		"BrokenLancetColumn",
		"RuneTablet",
		"VotiveLampBowl",
		"ShellMidden",
		"TidepoolRockRing",
		"RuinRubble",
		"StoneUrn",
		"CrackedTidebell",
		"BubbleVentCluster",
		"DaisBrazierPedestal",
		"KelpStand",
		"SeaFan",
		"AnemoneCluster",
		"TideGaugeColumn",
		"CantorLectern",
		"DrownedSundial",
		"MuffledBellStack",
		"ConchRack",
		"CantorStall",
		"OysterRack",
		"SluiceGear",
		"BellGallowsBracket",
		"DivingBell",
		"CoralCageReliquary",
	}
	local propCount: { [string]: number } = {}
	local maxPerProp = 34
	local targetProps = 700
	for attempt = 1, 7500 do
		if props >= targetProps then
			break
		end
		local x = rng:NextNumber(-halfW, halfW)
		local z = rng:NextNumber(-376, 332)
		local distEye = math.sqrt(x * x + (z + 130) ^ 2)
		if distEye < 158 then
			continue
		end
		if not offDais(x, z, 12) or not isClear(x, z, 4) then
			continue
		end
		local y = groundY(x, z)
		if y < waterY - 3.0 then
			continue
		end
		local pickIdx = ((attempt + rng:NextInteger(0, #propPool - 1)) % #propPool) + 1
		local tName = propPool[pickIdx]
		if (propCount[tName] or 0) >= maxPerProp then
			continue
		end
		local sc = if tName == "ReefCoralTable" then rng:NextNumber(0.65, 1.22)
			elseif tName == "CoralCluster" then rng:NextNumber(1.1, 1.95)
			elseif tName == "RuinRubble" then rng:NextNumber(0.9, 1.45)
			elseif tName == "CrackedTidebell" or tName == "MuffledBellStack" then rng:NextNumber(0.65, 0.92)
			elseif tName == "DaisBrazierPedestal" or tName == "DivingBell" or tName == "CoralCageReliquary" then rng:NextNumber(0.72, 0.92)
			else rng:NextNumber(0.82, 1.32)
		placeKit(tName, "BasinProp" .. props, V(x, y, z), rng:NextNumber(0, math.pi * 2), sc, coralPalette(attempt), false, false, false)
		propCount[tName] = (propCount[tName] or 0) + 1
	end

	-- Pass C: Low Bioluminescent Ground Cover along the Reef Horns, Wrack Shore & Crests (>= 490 cover)
	local coverPool = {
		"SeagrassTuft",
		"AnemoneCluster",
		"SeaFan",
		"ShellMidden",
		"TidepoolRockRing",
		"BrainCoralMound",
		"CoralCluster",
		"GiantClam",
		"KelpStand",
		"RuinRubble",
		"VotiveLampBowl",
		"RuneTablet",
		"StoneUrn",
	}
	local coverCount: { [string]: number } = {}
	local maxPerCover = 48
	local targetCover = 490
	for attempt = 1, 4500 do
		if cover >= targetCover then
			break
		end
		local x = rng:NextNumber(-halfW, halfW)
		local z = rng:NextNumber(-372, 326)
		local distEye = math.sqrt(x * x + (z + 130) ^ 2)
		if distEye < 162 then
			continue
		end
		if not offDais(x, z, 12) or not isClear(x, z, 3) then
			continue
		end
		local y = groundY(x, z)
		if y < waterY - 2.0 then
			continue
		end
		local pickIdx = ((attempt + rng:NextInteger(0, #coverPool - 1)) % #coverPool) + 1
		local tName = coverPool[pickIdx]
		if (coverCount[tName] or 0) >= maxPerCover then
			continue
		end
		local sc = if tName == "SeagrassTuft" then rng:NextNumber(0.9, 1.6)
			elseif tName == "AnemoneCluster" or tName == "SeaFan" then rng:NextNumber(0.85, 1.45)
			else rng:NextNumber(0.55, 0.95)
		placeKit(tName, "BasinCover" .. cover, V(x, y, z), rng:NextNumber(0, math.pi * 2), sc, coralPalette(attempt + 1), false, false, true)
		coverCount[tName] = (coverCount[tName] or 0) + 1
	end

	-- Record floor telemetry attributes on BiomeAssets for inspection & verification
	local distinctKinds = 0
	for _ in kindsUsed do
		distinctKinds += 1
	end
	ctx.tag("SunkenF40Landmarks", landmarks)
	ctx.tag("SunkenF40Props", props)
	ctx.tag("SunkenF40Cover", cover)
	ctx.tag("SunkenF40DistinctTemplates", distinctKinds)
end

return SunkenFloor40
