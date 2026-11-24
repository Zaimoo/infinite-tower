--!strict
-- Floor 30, Roc's Eyrie (Thunder Highlands Boss Arena; docs/prompts/thunder-highlands-floor-layouts-prompt.md,
-- guide image reference/Thunder Highlands 30.jpg): the summit caldera at the roof of the Thunder Highlands, a
-- Twin-Wing Caldera Amphitheatre wrapping an open swirling Cloud-Eye abyss (Bottom = -8, TowerTerrain CLOUD_EYE).
-- TowerBiomeAssets calls Build(ctx) for layout.Authored == "thunder:5" with its own builders; shared helpers,
-- palette and tints come from ThunderHighlands.
--
-- Summit: the flat dark-slate 180 x 132 Roc's Eyrie boss dais (Y 56) ringed outside its combat zone by the Woven
-- Great Nest Rim (giant storm-blasted pine trunks and braided ropes), backed on the north shelf by the 208-stud
-- twin-peak Shattered Sky-Spire with crackling chasm lightning and seven curved copper-clad Lightning Crown Arches
-- framing the sky (never overhanging the boss dais, clear of the spread boss portals).
-- Centre: a copper-coped stone causeway juts from Eye-Rim Overlook to the circular Storm Eye Pulpit balustrade over
-- the swirling multi-layer cloud vortex, with sweeping Hanging Abyss Chains and tattered Kairnfolk banners draped
-- across the mist. West Wing: skybridge cliffs (TowerRoomBuilder SKYBRIDGE), colossal impaled Storm-Roc feathers,
-- a sea-stack Gale-Lantern watchtower, twin Wind-Harps, a crashed Shattered Crown Fragment, Caldera Rib Bones and
-- an Aerie Threshold Totem. East Wing: terraced crenellated dry-stone ramparts, roaring multi-tier waterfalls
-- plunging into the cloud eye, the highland Observatory Hall and Gale-Lantern Tower, and the Feather-Heart Shrine.
-- Foreground: weathered Threshold Ruin Arch, dry-stone walls, cairns, wind-bent pines and stormgrass: three skyline layers.
local ThunderHighlands = require(script.Parent.ThunderHighlands)

local ThunderFloor30 = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local C = ThunderHighlands.Palette
local Tints = ThunderHighlands.Tints
local KAIRN = Tints.KAIRN
local CLOUD = rgb(198, 196, 220)
local CLOUD_DEEP = rgb(138, 134, 170)
local UNDERGLOW = rgb(192, 168, 255)
local BONE = rgb(216, 208, 192)
local FEATHER_DARK = rgb(72, 74, 88)
local ROPE_TAN = rgb(146, 122, 92)

local CLOUD_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = CLOUD, Material = Enum.Material.SmoothPlastic } })
local CLOUD_DEEP_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = CLOUD_DEEP, Material = Enum.Material.SmoothPlastic } })
local BANNER_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = rgb(148, 44, 42), Material = Enum.Material.Fabric },
	ACCENT = { Color = rgb(224, 184, 66), Material = Enum.Material.Fabric },
})
local FEATHER_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = FEATHER_DARK, Material = Enum.Material.Fabric },
	TRIM = { Color = rgb(186, 184, 198), Material = Enum.Material.Metal },
})
local NEST_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = ROPE_TAN, Material = Enum.Material.Fabric },
	WOOD = { Color = rgb(78, 60, 46), Material = Enum.Material.Wood },
})
local BONE_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = BONE, Material = Enum.Material.SmoothPlastic },
	TRIM = { Color = rgb(176, 168, 152), Material = Enum.Material.SmoothPlastic },
})
local HEART_TINT = ThunderHighlands.Tinted(KAIRN, {
	GLOW = { Color = rgb(238, 224, 124), Material = Enum.Material.Neon },
	CRYSTAL = { Color = rgb(196, 168, 255), Material = Enum.Material.Glass, Transparency = 0.2 },
})
local TOWER_TINT = ThunderHighlands.Tinted(KAIRN, {
	GLOW = { Color = C.LAMP, Material = Enum.Material.Neon },
})
local FULGURITE_TINT = ThunderHighlands.Tinted(KAIRN, {
	CRYSTAL = { Color = rgb(172, 144, 240), Material = Enum.Material.Glass, Transparency = 0.2 },
})

-- The colossal centrepiece behind Roc's Eyrie: twin-peak Shattered Sky-Spire (126.49 * 1.62 = 204.9 studs tall,
-- sculpted slightly slimmer in Z so it stands wholly on the north shelf inside the room and clear of both portals).
local SPIRE_SX, SPIRE_SY, SPIRE_SZ = 1.25, 1.62, 0.72
local SPIRE_Z = -382.5
local SPIRE_Y = 46
local SPIRE_TOP = 126.49

-- Curved copper-clad Lightning Crown Arches ringing the Shattered Sky-Spire behind the Eyrie dais (never over it).
local CROWN_ARCHES = {
	{ Id = "CrownArchOuterW", X = -128, Z = -356, Y = 38, Scale = 1.48, Yaw = -22 },
	{ Id = "CrownArchMidW", X = -96, Z = -378, Y = 44, Scale = 1.36, Yaw = -10 },
	{ Id = "CrownArchInnerW", X = -58, Z = -384, Y = 46, Scale = 0.92, Yaw = 4 },
	{ Id = "CrownArchCenter", X = -14, Z = -378, Y = 46, Scale = 0.78, Yaw = 12 },
	{ Id = "CrownArchInnerE", X = 58, Z = -384, Y = 46, Scale = 0.92, Yaw = 176 },
	{ Id = "CrownArchMidE", X = 96, Z = -378, Y = 44, Scale = 1.36, Yaw = 190 },
	{ Id = "CrownArchOuterE", X = 128, Z = -356, Y = 38, Scale = 1.48, Yaw = 202 },
}

-- Every fixed Floor 30 landmark's footprint, for offline SAT lane/camp specs and the census.
-- Y is its foot (nil: the ground); Top its height above that.
ThunderFloor30.Landmarks = (function()
	local list: { any } = {
		-- Colossal centrepiece behind Roc's Eyrie (>= 200 studs tall, well clear of the +/-66 boss portals).
		{ Id = "ShatteredSkySpire", X = 0, Z = SPIRE_Z, Y = SPIRE_Y, HalfX = 51.2 * SPIRE_SX, HalfZ = 20.2 * SPIRE_SZ, Top = SPIRE_TOP * SPIRE_SY },
		-- Circular Storm Eye Pulpit balustrade centered on the north portion of EyePulpit (clear of LandingB).
		{ Id = "EyePulpitBalustrade", X = 0, Z = -26, Y = 16, HalfX = 16.2, HalfZ = 15.3, Top = 6.8, Straddles = true },
		-- Foreground ruined stone archway on the far western shelf of Thunderhead Threshold (Basin).
		{ Id = "ThresholdRuinArch", X = -286, Z = 256, Y = 0, HalfX = 21.0, HalfZ = 9.0, Top = 26.0 },
		-- West Wing cliff watchtower perched on the inner sea-stack shoulder of West Pinion Crag facing the Cloud Eye.
		{ Id = "GaleTowerWest", X = -114, Z = -44, Y = 20, HalfX = 7.5, HalfZ = 7.5, Top = 40.1 },
		-- East Wing cliff watchtower + gabled highland Observatory Hall overlooking the waterfalls.
		{ Id = "GaleTowerEast", X = 232, Z = -168, Y = 34, HalfX = 7.5, HalfZ = 7.5, Top = 40.1 },
		{ Id = "ObservatoryHallEast", X = 214, Z = -286, Y = 46, HalfX = 12.6, HalfZ = 9.0, Top = 21.1 },
		-- Twin Aerie Threshold Totems guarding both upper Eyrie approaches.
		{ Id = "AerieTotemWest", X = -212, Z = -286, Y = 44, HalfX = 5.4, HalfZ = 5.4, Top = 26.3 },
		{ Id = "AerieTotemEast", X = 214, Z = -242, Y = 46, HalfX = 5.4, HalfZ = 5.4, Top = 26.3 },
		-- Wind-Harp towers perched along the windswept western caldera ridge.
		{ Id = "WindHarpBastionW", X = -242, Z = -126, Y = 32, HalfX = 8.4, HalfZ = 8.4, Top = 36.0 },
		{ Id = "WindHarpCrownW", X = -302, Z = -288, Y = 40, HalfX = 8.4, HalfZ = 8.4, Top = 36.0 },
		-- Fallen broken Lightning Crown arch chunk on Shattered Crown Spire (WestCrown).
		{ Id = "ShatteredCrownFrag", X = -342, Z = -276, Y = 40, HalfX = 10.0, HalfZ = 7.5, Top = 21.5 },
		-- Feather-Heart lightning shrine on the eastern talon perch.
		{ Id = "FeatherHeartShrine", X = 344, Z = -28, Y = 18, HalfX = 6.5, HalfZ = 6.5, Top = 13.4 },
		-- Colossal shed Storm-Roc feathers impaled along the western & eastern crag edges.
		{ Id = "ColossalFeatherW1", X = -344, Z = -16, Y = 14, HalfX = 5.2, HalfZ = 4.2, Top = 36.0 },
		{ Id = "ColossalFeatherW2", X = -246, Z = 124, Y = 8, HalfX = 5.2, HalfZ = 4.2, Top = 34.5 },
		{ Id = "ColossalFeatherW3", X = -242, Z = -104, Y = 32, HalfX = 5.2, HalfZ = 4.2, Top = 38.0 },
		{ Id = "ColossalFeatherE1", X = 344, Z = 4, Y = 18, HalfX = 5.2, HalfZ = 4.2, Top = 34.5 },
		-- Bleached mountain-beast ribcages nestled in the scree below both Talon Perches (the Roc's larder).
		{ Id = "CalderaRibsWest", X = -352, Z = 54, HalfX = 10.6, HalfZ = 9.4, Top = 12.0 },
		{ Id = "CalderaRibsEast", X = 352, Z = 54, HalfX = 10.6, HalfZ = 9.4, Top = 12.0 },
		-- Fulgurite glass columns jutting from the inner caldera cliffs.
		{ Id = "FulguriteSpireWest", X = -296, Z = -162, HalfX = 8.5, HalfZ = 7.9, Top = 49.7 },
		{ Id = "FulguriteSpireEast", X = 278, Z = -94, HalfX = 8.5, HalfZ = 7.9, Top = 49.7 },
		-- Talon nest roost & cable capstans anchoring the skybridge rim.
		{ Id = "TalonNestPerchW", X = -340, Z = -36, Y = 14, HalfX = 9.2, HalfZ = 9.2, Top = 5.0 },
		{ Id = "CapstanPinionW", X = -186, Z = -14, Y = 20, HalfX = 5.8, HalfZ = 6.2, Top = 8.4 },
		{ Id = "CapstanPinionE", X = 124, Z = -46, Y = 22, HalfX = 5.8, HalfZ = 6.2, Top = 8.4 },
		-- Broken sky-observatory watchtower ruin on the far south-east rim of Basin.
		{ Id = "ObservatoryRuinSE", X = 296, Z = 256, Y = 0, HalfX = 11.4, HalfZ = 11.4, Top = 26.0 },
	}
	for _, a in CROWN_ARCHES do
		table.insert(list, { Id = a.Id, X = a.X, Z = a.Z, Y = a.Y, HalfX = 8.0 * a.Scale, HalfZ = 8.0 * a.Scale, Top = 85.0 * a.Scale })
	end
	return table.freeze(list)
end)() :: { any }

function ThunderFloor30.Build(ctx: any)
	local H = ThunderHighlands.Helpers(ctx)
	local origin: Vector3, layout, field, bottom: number, w: number, d: number, P = H.origin, H.layout, H.field, H.bottom, H.w, H.d, H.P
	local surfaceAt, lowestGround, boxAt, rod, lump = H.surfaceAt, H.lowestGround, H.boxAt, H.rod, H.lump
	local fallbackCairn, fallbackPine, fallbackTuft, fallbackFlags = H.fallbackCairn, H.fallbackPine, H.fallbackTuft, H.fallbackFlags
	local fallbackRuneStone, fallbackCrystals, fallbackFall = H.fallbackRuneStone, H.fallbackCrystals, H.fallbackFall
	local landmarks, props, cover = 0, 0, 0
	local abyss = if field then field.Bottom else bottom - 4
	local rng = Random.new(30 * 7919)

	local function noCollide(inst: Instance?)
		if not inst then return end
		if inst:IsA("BasePart") then
			inst.CanCollide = false
			inst.CanQuery = false
			inst.CastShadow = false
		end
		for _, p in inst:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				p.CastShadow = false
			end
		end
	end
	local function light(name: string, at: Vector3, color: Color3, brightness: number, range: number)
		local anchor = ctx.block(name .. "LightAnchor", V(1, 1, 1), at, color, Enum.Material.SmoothPlastic, nil, 1)
		noCollide(anchor)
		H.light(anchor, color, brightness, range)
	end
	local function emitter(name: string, at: Vector3, size: Vector3, cfg: { [string]: any })
		local anchor = ctx.block(name .. "EmitterAnchor", size, at, CLOUD, Enum.Material.SmoothPlastic, nil, 1)
		noCollide(anchor)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = name
		for key, val in cfg do
			(pe :: any)[key] = val
		end
		pe.Parent = anchor
		return anchor
	end
	local function piece(kitName: string, cf: CFrame, scale: Vector3 | number, override: any?, fallback: (() -> ())?)
		if ctx.has(kitName) then
			ctx.kitAt(kitName, cf, scale, override)
		elseif fallback then
			fallback()
		end
	end

	-- ===================================================================================================
	-- Native fallbacks for the 13 Floor 30 kit templates (until ThunderF30Kit.fbx is imported).
	-- ===================================================================================================
	local function fallbackSkySpire(cf: CFrame, s: number)
		-- Jagged twin volcanic-slate peaks split by a crackling central fissure (reads cleanly even pre-FBX!).
		for _, side in { -1, 1 } do
			local h = (if side < 0 then 126 else 118) * s
			local bx = side * 20 * s
			local tx = side * 12 * s
			for k = 0, 7 do
				local f = k / 8
				local f2 = (k + 1) / 8
				local taper = (1 - f * 0.84)
				local rx = (17 * taper + (if k % 2 == 0 then 1.8 else 0)) * s
				local rz = (12 * taper) * s
				local px = bx + (tx - bx) * f + side * (if k % 2 == 0 then 1.2 else -0.8) * s
				local py = (f + (f2 - f) * 0.5) * h
				local tilt = CFrame.Angles(math.rad(side * (3 + k)), math.rad(side * 12 * k), math.rad(-side * (6 + k * 0.8)))
				boxAt("SkySpirePeak", V(rx * 1.5, (f2 - f) * h * 1.28, rz * 1.4), cf * CFrame.new(px, py, (k % 2 - 0.5) * 1.5 * s) * tilt, if k % 2 == 0 then C.SLATE_DARK else C.SLATE, Enum.Material.Slate)
			end
			-- Flanking jagged shoulder buttress on outer side of each peak.
			local sh = h * 0.52
			boxAt("SkySpireButtress", V(18 * s, sh, 13 * s), cf * CFrame.new(side * 30 * s, sh * 0.45, 2 * s) * CFrame.Angles(0, 0, math.rad(side * 16)), C.SLATE_DARK, Enum.Material.Slate)
			-- Continuous hammered-copper lightning conductor spine running up the inner chasm cliff.
			rod("SkySpireCopperSpine", (cf * CFrame.new(side * 12 * s, 10 * s, -2 * s)).Position, (cf * CFrame.new(side * 10 * s, h * 0.82, -2 * s)).Position, 1.3 * s, C.COPPER, Enum.Material.Metal).CanCollide = false
		end
		for idx, z in { 38, 64, 90, 110 } do
			local a = (cf * CFrame.new(-9 * s, z * s, -2 * s)).Position
			local b = (cf * CFrame.new(9 * s, (z + 4) * s, -2 * s)).Position
			local m = a:Lerp(b, 0.5) + V(0, (if idx % 2 == 0 then 3.2 else -2.8) * s, 0)
			rod("SkySpireFissureBoltGlowSeam", a, m, 0.7 * s, C.STORM, Enum.Material.Neon).CanCollide = false
			rod("SkySpireFissureBoltGlowSeam", m, b, 0.7 * s, C.STORM, Enum.Material.Neon).CanCollide = false
		end
	end
	local function fallbackCrownArch(cf: CFrame, s: number)
		boxAt("CrownArchPlinth", V(11, 14, 11) * s, cf * CFrame.new(0, 7 * s, 0), C.SLATE_DARK, Enum.Material.Slate)
		local prev = (cf * CFrame.new(0, 13 * s, 0)).Position
		local prevOut = (cf * CFrame.new(-2.4 * s, 13 * s, 0)).Position
		for i = 1, 8 do
			local f = i / 8
			local ang = f * math.rad(70)
			local cx = (1 - math.cos(ang)) * 42 * s
			local cy = (13 + math.sin(ang) * 68) * s
			local nxt = (cf * CFrame.new(cx, cy, 0)).Position
			local nxtOut = (cf * CFrame.new(cx - math.cos(ang) * 2.4 * s, cy + math.sin(ang) * 2.0 * s, 0)).Position
			-- Dark slate structural inner rib + continuous burnished copper outer crest spine.
			rod("CrownArchStoneRib", prev, nxt, (4.8 - f * 1.8) * s, C.SLATE_DARK, Enum.Material.Slate).CanCollide = false
			rod("CrownArchCopperSpine", prevOut, nxtOut, (2.2 - f * 0.7) * s, C.COPPER, Enum.Material.Metal).CanCollide = false
			prev = nxt
			prevOut = nxtOut
		end
		boxAt("CrownArchTipGlowSeam", V(2.0, 2.0, 2.0) * s, CFrame.new(prevOut), C.STORM, Enum.Material.Neon).CanCollide = false
	end
	local function fallbackNestRim(cf: CFrame, s: number)
		boxAt("NestStoneLedge", V(26, 4.6, 7.2) * s, cf * CFrame.new(0, 2.3 * s, 0), C.SLATE_DARK, Enum.Material.Slate)
		for k, dy in { 5.4, 7.6, 9.6 } do
			rod("NestPineTrunk", (cf * CFrame.new(-13.5 * s, dy * s, (k - 2) * 1.4 * s)).Position, (cf * CFrame.new(13.5 * s, (dy + 0.6) * s, -(k - 2) * 1.2 * s)).Position, (3.2 - k * 0.4) * s, C.TIMBER, Enum.Material.Wood).CanCollide = false
		end
		for _, ox in { -8.5, 0, 8.5 } do
			boxAt("NestLashingBand", V(1.6, 6.4, 7.6) * s, cf * CFrame.new(ox * s, 7.4 * s, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		end
	end
	local function fallbackPulpitBalustrade(cf: CFrame)
		for k = 0, 15 do
			local a = k * math.pi * 2 / 16
			local da = math.abs(((a - math.pi / 2 + math.pi) % (2 * math.pi)) - math.pi)
			if da > math.rad(34) then
				local p = cf * CFrame.new(math.cos(a) * 15.2, 2.2, math.sin(a) * 15.2) * CFrame.Angles(0, -a, 0)
				boxAt("PulpitCurb", V(1.6, 1.8, 6.0), p * CFrame.new(0, -1.2, 0), C.SLATE, Enum.Material.Slate).CanCollide = false
				boxAt("PulpitCopperRail", V(0.7, 0.7, 6.2), p * CFrame.new(0, 2.2, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
			end
		end
	end
	local function fallbackColossalFeather(cf: CFrame, s: number)
		rod("FeatherQuill", cf.Position, (cf * CFrame.new(2.5 * s, 32 * s, 0)).Position, 0.9 * s, C.SLATE_DARK, Enum.Material.Metal).CanCollide = false
		boxAt("FeatherVane", V(7.2, 24, 0.5) * s, cf * CFrame.new(1.5 * s, 18 * s, 0) * CFrame.Angles(0, 0, math.rad(-5)), FEATHER_DARK, Enum.Material.Fabric).CanCollide = false
		boxAt("FeatherCopperEdge", V(0.5, 22, 0.7) * s, cf * CFrame.new(-2.1 * s, 18 * s, 0) * CFrame.Angles(0, 0, math.rad(-5)), C.COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackGaleTower(cf: CFrame, s: number)
		boxAt("GaleTowerBase", V(12.2, 12, 12.2) * s, cf * CFrame.new(0, 6 * s, 0), C.SLATE, Enum.Material.Slate)
		boxAt("GaleTowerShaft", V(10.4, 11, 10.4) * s, cf * CFrame.new(0, 17.5 * s, 0), C.GRANITE, Enum.Material.Slate)
		boxAt("GaleTowerBand", V(11.4, 0.9, 11.4) * s, cf * CFrame.new(0, 23 * s, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		ctx.orb("GaleTowerLanternGlowSeam", (cf * CFrame.new(0, 26.4 * s, 0)).Position, V(4.2, 4.2, 4.2) * s, C.LAMP, Enum.Material.Neon).CanCollide = false
		boxAt("GaleTowerRoof", V(12, 6, 12) * s, cf * CFrame.new(0, 32.5 * s, 0), C.SLATE_DARK, Enum.Material.Slate).CanCollide = false
	end
	local function fallbackObservatory(cf: CFrame, s: number)
		boxAt("ObsHallBody", V(22, 10.5, 14) * s, cf * CFrame.new(0, 5.25 * s, 0), C.SLATE, Enum.Material.Slate)
		boxAt("ObsHallRoof", V(24, 5.5, 15.6) * s, cf * CFrame.new(0, 13.2 * s, 0), C.SLATE_DARK, Enum.Material.Slate).CanCollide = false
		boxAt("ObsHallRidgeCopper", V(24.4, 0.9, 0.9) * s, cf * CFrame.new(0, 16.4 * s, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackRuinArch(cf: CFrame, s: number)
		for _, sx in { -1, 1 } do
			boxAt("RuinArchPier", V(6.2, 14, 7.2) * s, cf * CFrame.new(sx * 9.2 * s, 7 * s, 0), C.SLATE, Enum.Material.Slate)
			boxAt("RuinArchWing", V(8, 9.5, 4.2) * s, cf * CFrame.new(sx * 15.8 * s, 4.75 * s, 0), C.GRANITE, Enum.Material.Slate)
		end
		boxAt("RuinArchCrown", V(22, 4.2, 6.2) * s, cf * CFrame.new(0, 21.5 * s, 0), C.SLATE_DARK, Enum.Material.Slate).CanCollide = false
	end
	local function fallbackAerieTotem(cf: CFrame, s: number)
		ctx.cyl("AerieTotemBase", (cf * CFrame.new(0, 2.5 * s, 0)).Position, 5 * s, 5 * s, C.SLATE, Enum.Material.Slate)
		ctx.cyl("AerieTotemShaft", (cf * CFrame.new(0, 11 * s, 0)).Position, 3 * s, 12 * s, C.GRANITE, Enum.Material.Slate)
		ctx.cyl("AerieTotemTip", (cf * CFrame.new(0, 21 * s, 0)).Position, 1.4 * s, 8 * s, C.COPPER, Enum.Material.Metal).CanCollide = false
		ctx.orb("AerieTotemGlowSeam", (cf * CFrame.new(0, 25.5 * s, 0)).Position, V(1.6, 1.6, 1.6) * s, C.STORM, Enum.Material.Neon).CanCollide = false
	end
	local function fallbackFeatherHeart(cf: CFrame, s: number)
		ctx.cyl("HeartShrineBase", (cf * CFrame.new(0, 1.4 * s, 0)).Position, 6 * s, 2.8 * s, C.SLATE, Enum.Material.Slate)
		ctx.orb("FeatherHeartGlowSeam", (cf * CFrame.new(0, 8.6 * s, 0)).Position, V(4.4, 4.4, 4.4) * s, rgb(238, 224, 124), Enum.Material.Neon).CanCollide = false
	end
	local function fallbackCrownFrag(cf: CFrame, s: number)
		rod("CrownFragRib", (cf * CFrame.new(-6 * s, 2 * s, 0)).Position, (cf * CFrame.new(8 * s, 16 * s, 0)).Position, 4.8 * s, C.COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackRibBones(cf: CFrame, s: number)
		for k = -2, 2 do
			rod("CalderaRib", (cf * CFrame.new(k * 3.8 * s, 2 * s, 0)).Position, (cf * CFrame.new(k * 3.8 * s, 11 * s, 7 * s)).Position, 1.1 * s, BONE, Enum.Material.SmoothPlastic).CanCollide = false
			rod("CalderaRib", (cf * CFrame.new(k * 3.8 * s, 2 * s, 0)).Position, (cf * CFrame.new(k * 3.8 * s, 11 * s, -7 * s)).Position, 1.1 * s, BONE, Enum.Material.SmoothPlastic).CanCollide = false
		end
	end
	local function fallbackAbyssChain(cf: CFrame, sx: number, sy: number?)
		-- Smooth 6-segment catenary chain sweeping across the Cloud Eye with hanging weathered Kairnfolk banners.
		local sY = sy or sx
		local nSeg = 6
		local prev: Vector3? = nil
		for i = 0, nSeg do
			local t = i / nSeg
			local u = t * 2 - 1
			local sag = 9.5 * (1 - u * u)
			local pt = (cf * CFrame.new(u * 21 * sx, (18 - sag) * sY, 0)).Position
			if prev then
				rod("AbyssChainLink", prev, pt, 0.52 * sY, C.SLATE_DARK, Enum.Material.Metal).CanCollide = false
			end
			if i == 2 or i == 3 or i == 4 then
				local bh = (if i == 3 then 8.2 else 5.8) * sY
				local bw = (if i == 3 then 3.2 else 2.2) * sY
				local bcf = CFrame.new(pt - V(0, bh * 0.52, 0)) * (cf - cf.Position)
				boxAt("AbyssChainBanner", V(bw, bh, 0.22 * sY), bcf, if i == 3 then rgb(148, 44, 42) else rgb(118, 46, 44), Enum.Material.Fabric).CanCollide = false
				boxAt("AbyssChainBannerTrim", V(bw + 0.3 * sY, 0.55 * sY, 0.3 * sY), bcf * CFrame.new(0, bh * 0.46, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
			end
			prev = pt
		end
	end
	local function fallbackCloud(cf: CFrame, sx: number, sy: number, color: Color3)
		for k, b in { { 0, 0, 24, 7.5 }, { -17, 4, 17, 6 }, { 16, -3, 18, 6.2 }, { -6, -11, 15, 5.2 }, { 10, 11, 14, 4.8 } } do
			local at = (cf * CFrame.new(b[1] * sx, b[4] * 0.45 * sy, b[2] * sx)).Position
			local cloud = lump("CloudBankMist", at, V(b[3] * 1.4 * sx, b[4] * 1.8 * sy, b[3] * sx), if k % 2 == 0 then color else CLOUD_DEEP, Enum.Material.SmoothPlastic)
			cloud.CanCollide = false
			cloud.CanQuery = false
		end
	end
	local function fallbackWall(cf: CFrame, len: number, sy: number)
		boxAt("CurtainWallRun", V(len, 7.4 * sy, 2.2), cf * CFrame.new(0, 3.7 * sy, 0), C.SLATE, Enum.Material.Slate)
		for k = 0, math.max(1, math.floor(len / 4)) - 1 do
			boxAt("CurtainWallMerlon", V(2.0, 1.6 * sy, 2.2), cf * CFrame.new(-len / 2 + 2 + k * 4, (7.4 + 0.8) * sy, 0), C.SLATE_DARK, Enum.Material.Slate)
		end
	end
	local function fallbackWindHarp(cf: CFrame, s: number)
		boxAt("WindHarpPlinth", V(8, 3, 8) * s, cf * CFrame.new(0, 1.5 * s, 0), C.SLATE, Enum.Material.Slate)
		rod("WindHarpArch", (cf * CFrame.new(-3 * s, 3 * s, 0)).Position, (cf * CFrame.new(4 * s, 28 * s, 0)).Position, 1.4 * s, C.COPPER, Enum.Material.Metal).CanCollide = false
		for k = 1, 4 do
			rod("WindHarpStringGlowSeam", (cf * CFrame.new((-2 + k * 1.2) * s, 3 * s, 0)).Position, (cf * CFrame.new((-1 + k * 1.2) * s, (12 + k * 3.5) * s, 0)).Position, 0.18 * s, C.STORM, Enum.Material.Neon).CanCollide = false
		end
	end

	for _, lm in ThunderFloor30.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- The lowest walking surface within r of (x, z), so cloud banks keep >= 4 studs under every walkway near them.
	local function lowestWalkNear(x: number, z: number, r: number): number
		local low = math.huge
		local function along(link: any)
			local dx, dz = link.BX - link.AX, link.BZ - link.AZ
			local lengthSq = math.max(dx * dx + dz * dz, 1e-6)
			local t = math.clamp(((x - link.AX) * dx + (z - link.AZ) * dz) / lengthSq, 0, 1)
			local px, pz = link.AX + dx * t, link.AZ + dz * t
			local reach = r + (link.Width or 28) / 2 + 6
			if (px - x) ^ 2 + (pz - z) ^ 2 < reach * reach then
				local span = reach / math.sqrt(lengthSq)
				for _, tt in { math.clamp(t - span, 0, 1), math.clamp(t + span, 0, 1) } do
					low = math.min(low, link.AY + (link.BY - link.AY) * tt)
				end
			end
		end
		for _, link in layout.Links do
			along(link)
		end
		for _, link in layout.ReturnLinks or {} do
			along(link)
		end
		for id, p in P do
			if id ~= "Sanctuary" and math.abs(x - p.X) < p.Width / 2 + r + 4 and math.abs(z - p.Z) < p.Depth / 2 + r + 4 then
				low = math.min(low, p.Y)
			end
		end
		return low
	end

	local function campFree(x: number, z: number, r: number): boolean
		for _, camp in layout.Camps do
			if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (36 + r) ^ 2 then
				return false
			end
		end
		return true
	end

	local function onTerrace(x: number, z: number, pad: number): boolean
		for id, p in P do
			if id ~= "Sanctuary" and math.abs(x - p.X) < p.Width / 2 + pad and math.abs(z - p.Z) < p.Depth / 2 + pad then
				return true
			end
		end
		return false
	end

	local function linkFree(x: number, z: number, pad: number): boolean
		local function clear(link: any): boolean
			local dx, dz = link.BX - link.AX, link.BZ - link.AZ
			local lenSq = math.max(dx * dx + dz * dz, 1e-6)
			local t = math.clamp(((x - link.AX) * dx + (z - link.AZ) * dz) / lenSq, 0, 1)
			local px, pz = link.AX + dx * t, link.AZ + dz * t
			local reach = (link.Width or 28) / 2 + pad
			return (px - x) ^ 2 + (pz - z) ^ 2 >= reach * reach
		end
		for _, link in layout.Links do
			if not clear(link) then return false end
		end
		for _, link in layout.ReturnLinks or {} do
			if not clear(link) then return false end
		end
		return true
	end

	-- 1. Colossal centrepiece: The Shattered Sky-Spire (>= 204 studs tall) + 7 Lightning Crown Arches behind Apex.
	ctx.group("ShatteredSkySpire", function()
		local cf = CFrame.new(0, SPIRE_Y, SPIRE_Z)
		piece("ShatteredSkySpire", cf, V(SPIRE_SX, SPIRE_SY, SPIRE_SZ), KAIRN, function()
			fallbackSkySpire(cf, SPIRE_SY)
		end)
		-- Crackling overhead lightning arcs leaping between the twin peaks' high crowns (well behind Apex!).
		for k, yOff in { 118, 152, 184 } do
			local a = V(-20 + k * 2, SPIRE_Y + yOff, SPIRE_Z - 4)
			local b = V(20 - k * 2, SPIRE_Y + yOff + 6, SPIRE_Z - 4)
			local mid = a:Lerp(b, 0.5) + V(0, if k % 2 == 0 then 5 else -4, 3)
			noCollide(rod("SkySpireArcGlowSeam", a, mid, 0.85, C.STORM, Enum.Material.Neon))
			noCollide(rod("SkySpireArcGlowSeam", mid, b, 0.85, C.STORM, Enum.Material.Neon))
		end
		light("SkySpireGlow", V(0, SPIRE_Y + 115, SPIRE_Z + 18), C.STORM, 3.2, 60)
		emitter("SkySpireSparks", V(0, SPIRE_Y + 145, SPIRE_Z + 6), V(26, 40, 10), {
			Color = ColorSequence.new(Color3.new(1, 1, 1), C.STORM),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.4, 0.9), Rate = 16, Speed = NumberRange.new(10, 24), SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
		})
		landmarks += 1
		props += 7
	end)

	for _, a in CROWN_ARCHES do
		ctx.group(a.Id, function()
			local cf = CFrame.new(a.X, a.Y, a.Z) * CFrame.Angles(0, math.rad(a.Yaw), 0)
			piece("LightningCrownArch", cf, a.Scale, KAIRN, function()
				fallbackCrownArch(cf, a.Scale)
			end)
			landmarks += 1
			props += 1
		end)
	end
	-- Overhead sky-lightning filaments arcing between the outer and middle Lightning Crown Arches (behind Apex!).
	ctx.group("LightningCrownArcs", function()
		for _, pair in {
			{ V(-92, 136, -372), V(-58, 122, -388) },
			{ V(92, 136, -372), V(58, 122, -388) },
			{ V(-58, 124, -388), V(-18, 165, -394) },
			{ V(58, 124, -388), V(18, 162, -394) },
		} do
			local mid = pair[1]:Lerp(pair[2], 0.5) + V(0, 6, -4)
			noCollide(rod("CrownBoltGlowSeam", pair[1], mid, 0.65, C.STORM, Enum.Material.Neon))
			noCollide(rod("CrownBoltGlowSeam", mid, pair[2], 0.65, C.STORM, Enum.Material.Neon))
			props += 2
		end
	end)

	-- 2. The Woven Great Nest Rim wrapping Roc's Eyrie (Apex: 180 x 132 at Y 56, Z -364..-232, X -90..+90).
	-- Every segment stands strictly outside the walkable 180 x 132 floor (clear of boss camp, portals & both stairheads!).
	ctx.group("EyrieGreatNestRim", function()
		local ay = P.Apex.Y - 2.4
		-- North rim behind the portals (Z = -370, 6 segments).
		for _, nx in { -74, -44.5, -15, 15, 44.5, 74 } do
			local cf = CFrame.new(nx, ay, -370) * CFrame.Angles(0, math.pi, 0)
			piece("EyrieNestRimSegment", cf, 1.08, NEST_TINT, function() fallbackNestRim(cf, 1.08) end)
			props += 1
		end
		-- South rim facing the Cloud Eye and arrival camera (Z = -226, 6 segments).
		for _, sx in { -74, -44.5, -15, 15, 44.5, 74 } do
			local cf = CFrame.new(sx, ay, -226)
			piece("EyrieNestRimSegment", cf, 1.08, NEST_TINT, function() fallbackNestRim(cf, 1.08) end)
			props += 1
		end
		-- North-west & north-east side rims (leaving Z = -286..-238 wide open for WestAerie & EastAerie stairs!).
		for _, side in { -1, 1 } do
			for _, sz in { -350, -320 } do
				local cf = CFrame.new(side * 96, ay, sz) * CFrame.Angles(0, side * math.pi / 2, 0)
				piece("EyrieNestRimSegment", cf, 1.06, NEST_TINT, function() fallbackNestRim(cf, 1.06) end)
				props += 1
			end
		end
		-- Sweeping braided copper lashing cables & tattered hanging banners down the sheer Eyrie drum cliff!
		for _, bx in { -60, -24, 24, 60 } do
			local bcf = CFrame.new(bx, P.Apex.Y - 20, -225)
			noCollide(boxAt("EyrieDrumBanner", V(5.4, 14, 0.25), bcf, rgb(138, 42, 40), Enum.Material.Fabric))
			noCollide(boxAt("EyrieDrumBannerTrim", V(5.8, 0.9, 0.4), bcf * CFrame.new(0, 7.2, 0), C.COPPER, Enum.Material.Metal))
			props += 2
		end
		light("EyrieNorthRimGlow", V(0, P.Apex.Y + 10, -366), C.STORM, 2.2, 48)
		landmarks += 1
	end)

	-- 3. Storm Eye Pulpit: circular stone-and-copper balustrade + compass inlay over the swirling Cloud Eye.
	ctx.group("EyePulpitBalustrade", function()
		local cf = CFrame.new(0, P.EyePulpit.Y, -26)
		piece("EyePulpitBalustrade", cf, 1.0, KAIRN, function()
			fallbackPulpitBalustrade(cf)
		end)
		-- Circular masonry drum sleeve under the pulpit's north crown plunging into the cloud eye.
		local drumH = P.EyePulpit.Y - abyss
		local col = ctx.cyl("EyePulpitDrum", V(0, abyss + drumH / 2, -26), 15.8, drumH, C.SLATE_DARK, Enum.Material.Slate)
		col.CanCollide = false
		local band = ctx.cyl("EyePulpitCopperCollar", V(0, P.EyePulpit.Y - 2.4, -26), 16.4, 1.1, C.COPPER, Enum.Material.Metal)
		band.CanCollide = false
		light("EyePulpitGlow", V(0, P.EyePulpit.Y + 5, -26), C.STORM, 2.0, 42)
		landmarks += 1
		props += 3
	end)

	-- 4. Sweeping Hanging Abyss Chains with tattered banners draped across the open Cloud Eye (non-collidable!).
	-- Each sweeping span is a single continuous catenary arc in its own group (zero W-kink in mid-air!).
	local chainSpans = {
		-- Eye Pulpit west & east flanks out across the open Cloud Eye to the north faces of the Pinion crags.
		{ A = V(-34, 16, -32), B = V(-110, 20, -48) },
		{ A = V(34, 16, -32), B = V(110, 22, -48) },
		-- Eyrie drum cliff south face out across the chasm toward both Gale Bastion inner walls.
		{ A = V(-84, 48, -226), B = V(-142, 30, -108) },
		{ A = V(84, 48, -226), B = V(142, 32, -108) },
		-- Lower banners festooning the front of the Eyrie drum itself.
		{ A = V(-84, 48, -224), B = V(-24, 48, -224) },
		{ A = V(24, 48, -224), B = V(84, 48, -224) },
	}
	for spanIdx, sp in chainSpans do
		local dvec = sp.B - sp.A
		local dist = dvec.Magnitude
		local yaw = math.atan2(-dvec.Z, dvec.X)
		local mid = (sp.A + sp.B) * 0.5
		local s = dist / 42
		local sy = math.min(s, 1.5)
		ctx.group(string.format("AbyssChain_%d", spanIdx), function()
			local cf = CFrame.new(mid.X, mid.Y - 18 * sy, mid.Z) * CFrame.Angles(0, yaw, 0)
			local scaleV = V(s, sy, sy)
			piece("HangingAbyssChain", cf, scaleV, BANNER_TINT, function() fallbackAbyssChain(cf, s, sy) end)
			props += 1
		end)
	end
	landmarks += 1

	-- 5. Foreground Threshold Ruin Arch (left of Basin) & Broken Sky-Observatory Ruin (right of Basin).
	ctx.group("ThresholdRuinArch", function()
		local cf = CFrame.new(-286, P.Basin.Y, 256) * CFrame.Angles(0, math.rad(22), 0)
		piece("ThresholdRuinArch", cf, 1.0, KAIRN, function() fallbackRuinArch(cf, 1.0) end)
		landmarks += 1
		props += 1
	end)
	ctx.group("ObservatoryRuinSE", function()
		local cf = CFrame.new(296, P.Basin.Y, 256) * CFrame.Angles(0, math.rad(-140), 0)
		piece("ShatteredWatchtower", cf, 1.0, KAIRN, function()
			boxAt("ObsRuinWall", V(14, 18, 14), cf * CFrame.new(0, 9, 0), C.SLATE, Enum.Material.Slate)
		end)
		landmarks += 1
		props += 1
	end)

	-- 6. West Wing Landmarks: Sea-stack Gale-Lantern Tower, Wind-Harps, Colossal Roc Feathers, Shattered Crown, Totem.
	ctx.group("GaleTowerWest", function()
		local cf = CFrame.new(-114, P.WestPinion.Y, -44) * CFrame.Angles(0, math.rad(35), 0)
		piece("GaleLanternTower", cf, 1.0, TOWER_TINT, function() fallbackGaleTower(cf, 1.0) end)
		light("GaleTowerWestGlow", V(-114, P.WestPinion.Y + 26, -44), C.LAMP, 2.2, 44)
		landmarks += 1
		props += 2
	end)
	for _, wh in {
		{ Id = "WindHarpBastionW", X = -242, Y = P.WestBastion.Y, Z = -126, Yaw = 28 },
		{ Id = "WindHarpCrownW", X = -302, Y = P.WestCrown.Y, Z = -288, Yaw = 45 },
	} do
		ctx.group(wh.Id, function()
			local cf = CFrame.new(wh.X, wh.Y, wh.Z) * CFrame.Angles(0, math.rad(wh.Yaw), 0)
			piece("WindHarpTower", cf, 1.05, KAIRN, function() fallbackWindHarp(cf, 1.05) end)
			landmarks += 1
			props += 1
		end)
	end
	ctx.group("ShatteredCrownFrag", function()
		local cf = CFrame.new(-342, P.WestCrown.Y, -276) * CFrame.Angles(0, math.rad(18), 0)
		piece("ShatteredCrownFragment", cf, 1.0, KAIRN, function() fallbackCrownFrag(cf, 1.0) end)
		landmarks += 1
		props += 1
	end)
	ctx.group("AerieTotemWest", function()
		local cf = CFrame.new(-212, P.WestAerie.Y, -286) * CFrame.Angles(0, math.rad(30), 0)
		piece("AerieThresholdTotem", cf, 1.0, KAIRN, function() fallbackAerieTotem(cf, 1.0) end)
		landmarks += 1
		props += 1
	end)
	for _, f in {
		{ Id = "ColossalFeatherW1", X = -344, Y = P.WestPerch.Y, Z = -16, S = 1.08, Yaw = 24, Pitch = 10 },
		{ Id = "ColossalFeatherW2", X = -246, Y = P.WestGallery.Y, Z = 124, S = 1.0, Yaw = -18, Pitch = 8 },
		{ Id = "ColossalFeatherW3", X = -242, Y = P.WestBastion.Y, Z = -104, S = 1.12, Yaw = 32, Pitch = 12 },
		{ Id = "ColossalFeatherE1", X = 344, Y = P.EastPerch.Y, Z = 4, S = 1.0, Yaw = -152, Pitch = 10 },
	} do
		ctx.group(f.Id, function()
			local cf = CFrame.new(f.X, f.Y, f.Z) * CFrame.Angles(0, math.rad(f.Yaw), math.rad(f.Pitch))
			piece("ColossalRocFeather", cf, f.S, FEATHER_TINT, function() fallbackColossalFeather(cf, f.S) end)
			landmarks += 1
			props += 1
		end)
	end
	ctx.group("TalonNestPerchW", function()
		local cf = CFrame.new(-340, P.WestPerch.Y, -36) * CFrame.Angles(0, math.rad(20), 0)
		piece("TalonNestPlatform", cf, 0.78, NEST_TINT, function()
			ctx.cyl("TalonNestRing", cf.Position + V(0, 1.2, 0), 8, 2.4, C.TIMBER, Enum.Material.Wood)
		end)
		landmarks += 1
		props += 1
	end)
	for _, cap in {
		{ Id = "CapstanPinionW", X = -186, Y = P.WestPinion.Y, Z = -14, Yaw = -40 },
		{ Id = "CapstanPinionE", X = 124, Y = P.EastPinion.Y, Z = -46, Yaw = 40 },
	} do
		ctx.group(cap.Id, function()
			local cf = CFrame.new(cap.X, cap.Y, cap.Z) * CFrame.Angles(0, math.rad(cap.Yaw), 0)
			piece("CableWinchCapstan", cf, 0.85, KAIRN, function()
				ctx.cyl("CapstanDrum", cf.Position + V(0, 3.5, 0), 3.2, 7, C.TIMBER, Enum.Material.Wood)
			end)
			landmarks += 1
			props += 1
		end)
	end

	-- 7. East Wing Landmarks: Gale-Lantern Tower + Observatory Hall, Aerie Totem, Feather-Heart Shrine, Roaring Waterfalls.
	ctx.group("GaleTowerEast", function()
		local cf = CFrame.new(232, P.EastBastion.Y, -168) * CFrame.Angles(0, math.rad(-42), 0)
		piece("GaleLanternTower", cf, 1.0, TOWER_TINT, function() fallbackGaleTower(cf, 1.0) end)
		light("GaleTowerEastGlow", V(232, P.EastBastion.Y + 26, -168), C.LAMP, 2.2, 44)
		landmarks += 1
		props += 2
	end)
	ctx.group("ObservatoryHallEast", function()
		local cf = CFrame.new(214, P.EastAerie.Y, -286) * CFrame.Angles(0, math.rad(-18), 0)
		piece("ObservatoryHall", cf, 1.0, TOWER_TINT, function() fallbackObservatory(cf, 1.0) end)
		light("ObsHallGlow", V(214, P.EastAerie.Y + 8, -278), C.LAMP, 1.8, 34)
		landmarks += 1
		props += 2
	end)
	ctx.group("AerieTotemEast", function()
		local cf = CFrame.new(214, P.EastAerie.Y, -242) * CFrame.Angles(0, math.rad(-35), 0)
		piece("AerieThresholdTotem", cf, 1.0, KAIRN, function() fallbackAerieTotem(cf, 1.0) end)
		landmarks += 1
		props += 1
	end)
	ctx.group("FeatherHeartShrine", function()
		local cf = CFrame.new(344, P.EastPerch.Y, -28) * CFrame.Angles(0, math.rad(-65), 0)
		piece("FeatherHeartShrine", cf, 1.0, HEART_TINT, function() fallbackFeatherHeart(cf, 1.0) end)
		light("FeatherHeartGlow", V(344, P.EastPerch.Y + 9, -28), rgb(238, 224, 124), 2.2, 38)
		landmarks += 1
		props += 2
	end)

	-- Roaring multi-tier rain-spill waterfalls plunging down the sheer eastern & western caldera cliffs into the cloud eye!
	local falls = {
		-- East cliff triple cascade tucked tightly into the dark slate cliff wall (matching the guide image right side!).
		{ X = 344, Z = 76, TopY = 52, Yaw = -80, W = 1.4, Mist = true },
		{ X = 294, Z = -74, TopY = 62, Yaw = -92, W = 1.6, Mist = true },
		{ X = 316, Z = -196, TopY = 74, Yaw = -100, W = 1.5, Mist = true },
		-- Distant western storm-spill rill down the far crags.
		{ X = -324, Z = -110, TopY = 56, Yaw = 85, W = 1.1, Mist = false },
	}
	for idx, fl in falls do
		ctx.group("CalderaWaterfall_" .. idx, function()
			local hFall = fl.TopY - abyss
			local cf = CFrame.new(fl.X, abyss, fl.Z) * CFrame.Angles(0, math.rad(fl.Yaw), 0)
			-- Dark slate cliff spill-rock backing so the cascade pours out of rock rather than free air.
			local back = boxAt("WaterfallCliffBack", V(14 * fl.W, hFall * 1.04, 10), cf * CFrame.new(0, hFall * 0.5, -5.5), C.SLATE_DARK, Enum.Material.Slate)
			back.CanCollide = false
			local lip = boxAt("WaterfallSpillLip", V(16 * fl.W, 4.5, 12), cf * CFrame.new(0, hFall, -3.5), C.SLATE, Enum.Material.Slate)
			lip.CanCollide = false
			local s = V(fl.W, hFall / 55, 1.1)
			piece("WaterfallRibbon", cf * CFrame.Angles(math.rad(-5), 0, 0), s, Tints.WATER, function()
				fallbackFall(cf, hFall / 60)
			end)
			if fl.Mist then
				emitter("WaterfallSpray" .. idx, V(fl.X, abyss + 6, fl.Z), V(18, 8, 18), {
					Color = ColorSequence.new(C.FOAM, CLOUD),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 14) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.52), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(1.8, 3.2), Rate = 9, Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(70, 70),
				})
			end
			props += 3
		end)
	end
	landmarks += 1

	-- 8. Caldera Rib Bones (Roc's larder below Talon Perches) + Fulgurite Glass Spires on the inner cliffs.
	for _, rb in {
		{ Id = "CalderaRibsWest", X = -352, Z = 54, Yaw = 35 },
		{ Id = "CalderaRibsEast", X = 352, Z = 54, Yaw = -35 },
	} do
		ctx.group(rb.Id, function()
			local gy = lowestGround(rb.X, rb.Z, 8)
			local cf = CFrame.new(rb.X, gy, rb.Z) * CFrame.Angles(0, math.rad(rb.Yaw), 0)
			piece("CalderaRibBones", cf, 1.0, BONE_TINT, function() fallbackRibBones(cf, 1.0) end)
			landmarks += 1
			props += 1
		end)
	end
	for _, fg in {
		{ Id = "FulguriteSpireWest", X = -296, Z = -162, Yaw = 20 },
		{ Id = "FulguriteSpireEast", X = 278, Z = -94, Yaw = -25 },
	} do
		ctx.group(fg.Id, function()
			local gy = lowestGround(fg.X, fg.Z, 6)
			local cf = CFrame.new(fg.X, gy, fg.Z) * CFrame.Angles(0, math.rad(fg.Yaw), 0)
			piece("FulguriteSpireTall", cf, 1.0, FULGURITE_TINT, function() fallbackCrystals(cf, 2.2) end)
			landmarks += 1
			props += 1
		end)
	end

	-- 9. Crenellated Dry-Stone Curtain Walls along the fortified East Wing & Basin foreground parapets.
	local wallRuns = 0
	local function wallRun(x0: number, z0: number, x1: number, z1: number, y: number, sy: number)
		local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		if len < 6 then return end
		local yaw = math.atan2(-(z1 - z0), x1 - x0)
		local segs = math.max(1, math.round(len / 16))
		for k = 1, segs do
			local f = (k - 0.5) / segs
			local wx, wz = x0 + (x1 - x0) * f, z0 + (z1 - z0) * f
			local sl = len / segs
			local cf = CFrame.new(wx, y, wz) * CFrame.Angles(0, yaw, 0)
			ctx.group("CalderaCurtainWall", function()
				piece("CurtainWallSegment", cf, V(sl / 16, sy, 1), KAIRN, function() fallbackWall(cf, sl, sy) end)
			end)
			wallRuns += 1
			props += 1
		end
	end
	-- Foreground east parapet along Basin + outer eastern cliff edges of EastGallery, EastBastion & EastAerie.
	wallRun(165, 180, 290, 180, P.Basin.Y, 0.72)
	wallRun(-255, 180, -165, 180, P.Basin.Y, 0.72)
	wallRun(252, 56, 252, 128, P.EastGallery.Y, 0.76)
	wallRun(238, -176, 238, -104, P.EastBastion.Y, 0.8)
	wallRun(216, -288, 216, -236, P.EastAerie.Y, 0.76)

	-- 10. Swirling Multi-Layer Cloud-Eye Vortex (Bottom = -8; zero flat boxes, always >= 5 studs below walkways!).
	-- Kept strictly inside the central amphitheatre chasm (cz <= 8) so no cloud bulges into the foreground ridges.
	local cloudCount = 0
	for ringIdx, spec in {
		{ R = 30, N = 8, Y = abyss + 1.5, SX = 1.3, SY = 0.9, Deep = true },
		{ R = 70, N = 14, Y = abyss + 3.0, SX = 1.55, SY = 1.05, Deep = false },
		{ R = 114, N = 18, Y = abyss + 4.2, SX = 1.65, SY = 1.1, Deep = true },
		{ R = 158, N = 22, Y = abyss + 4.8, SX = 1.75, SY = 1.15, Deep = false },
		{ R = 196, N = 22, Y = abyss + 3.8, SX = 1.75, SY = 1.05, Deep = true },
	} do
		for k = 1, spec.N do
			local a = (k / spec.N) * math.pi * 2 + ringIdx * 0.42
			local cx = math.cos(a) * spec.R + rng:NextNumber(-7, 7)
			local cz = -114 + math.sin(a) * (spec.R * 0.62) + rng:NextNumber(-6, 6)
			if cz <= 8 and math.abs(cx) < w / 2 - 24 and math.abs(cz) < d / 2 - 24 then
				local low = lowestWalkNear(cx, cz, 28 * spec.SX)
				local y = math.min(spec.Y, low - 14 * spec.SY - 6)
				if y > abyss - 5 then
					ctx.group("CloudBank", function()
						local cf = CFrame.new(cx, y, cz) * CFrame.Angles(0, a + math.rad(35), 0)
						piece("CloudBankLayer", cf, V(spec.SX, spec.SY, spec.SX), if spec.Deep then CLOUD_DEEP_TINT else CLOUD_TINT, function()
							fallbackCloud(cf, spec.SX, spec.SY, if spec.Deep then CLOUD_DEEP else CLOUD)
						end)
					end)
					cloudCount += 1
					props += 1
				end
			end
		end
	end
	-- Three invisible-anchor lilac-violet underglow lights + pooled swirling storm-mist emitters in the Cloud Eye!
	for k, pt in { V(-58, abyss + 10, -96), V(58, abyss + 10, -96), V(0, abyss + 12, -158) } do
		ctx.group("CloudEyeGlow_" .. k, function()
			light("CloudEyeUnderglow" .. k, pt, UNDERGLOW, 2.2, 60)
			emitter("CloudEyeSwirl" .. k, pt - V(0, 4, 0), V(68, 10, 68), {
				Color = ColorSequence.new(CLOUD, UNDERGLOW),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(0.5, 22), NumberSequenceKeypoint.new(1, 10) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.68), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(4, 7), Rate = 7, Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(85, 85),
			})
		end)
	end
	landmarks += 1

	-- 11. Ring of Eight Outer Caldera Lightning Rods & Far Supercell Peaks (third skyline layer!).
	local rodSpots = {
		{ -358, -320, 1.45 }, { -364, -160, 1.35 }, { -364, 10, 1.25 }, { -356, 170, 1.2 },
		{ 358, -320, 1.45 }, { 364, -160, 1.35 }, { 364, 10, 1.25 }, { 356, 170, 1.2 },
	}
	for idx, rs in rodSpots do
		ctx.group("SkylineRod_" .. idx, function()
			local gy = math.max(abyss, lowestGround(rs[1], rs[2], 6))
			local plinthH = 18 * rs[3]
			local cf = CFrame.new(rs[1], gy + plinthH - 1, rs[2]) * CFrame.Angles(0, math.atan2(-rs[1], -rs[2]), 0)
			-- Grounded dark-slate crag pedestal anchoring each skyline rod firmly to the caldera floor.
			local base = ctx.cyl("SkylineRodBase", V(rs[1], gy + plinthH * 0.5, rs[2]), 5.2 * rs[3], plinthH, C.SLATE_DARK, Enum.Material.Slate)
			base.CanCollide = false
			local cap = ctx.cyl("SkylineRodCap", V(rs[1], gy + plinthH - 0.5, rs[2]), 4.4 * rs[3], 2.0, C.COPPER, Enum.Material.Metal)
			cap.CanCollide = false
			piece("ForkedBoltTotem", cf, rs[3] * 0.9, KAIRN, function()
				boxAt("OuterLightningRod", V(3.6, 44, 3.6) * rs[3], cf * CFrame.new(0, 22 * rs[3], 0), C.COPPER, Enum.Material.Metal).CanCollide = false
			end)
			props += 1
		end)
	end
	-- Towering sea-stack rock needles & jagged far horizon crags ringing the open Cloud Eye & outer cliffs.
	for k, st in {
		{ -86, -124, 1.25 }, { 86, -124, 1.25 }, { -116, -172, 1.15 }, { 116, -172, 1.15 },
		{ -272, -334, 1.5 }, { 272, -334, 1.5 }, { -358, -228, 1.35 }, { 358, -228, 1.35 },
	} do
		ctx.group("CalderaStack_" .. k, function()
			local cf = CFrame.new(st[1], abyss, st[2]) * CFrame.Angles(0, k * 0.9, 0)
			piece("SeaStackSpire", cf, st[3], KAIRN, function()
				boxAt("CalderaStack", V(14, 62, 14) * st[3], cf * CFrame.new(0, 31 * st[3], 0), C.SLATE_DARK, Enum.Material.Slate).CanCollide = false
			end)
			props += 1
		end)
	end
	-- High supercell rain & distant storm-sky mist emitters (total room emitters <= 16!).
	for k, pt in { V(-140, 128, -190), V(140, 128, -190), V(0, 132, 40) } do
		ctx.group("SupercellRain_" .. k, function()
			emitter("SupercellRain" .. k, pt, V(210, 12, 190), {
				Color = ColorSequence.new(rgb(212, 214, 240), rgb(164, 160, 206)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.2) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.92) }),
				Lifetime = NumberRange.new(1.2, 2.0), Rate = 24, Speed = NumberRange.new(42, 58),
				EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(14, 14),
			})
		end)
	end
	landmarks += 1

	-- 12. Bridgehead & Terrace Vignette Dressing (all 19 links dressed at both ends + 32+ distinct templates total!).
	-- Reuse rich Kairnfolk & core templates on terrace corners outside camps and lanes!
	local terraceDecor: { { any } } = {
		-- Nexus braziers framing Basin arrival & Crossing approach.
		{ "NexusBrazierPedestal", -28, P.Basin.Y, 186, 0, KAIRN },
		{ "NexusBrazierPedestal", 28, P.Basin.Y, 186, 0, KAIRN },
		{ "NexusBrazierPedestal", -36, P.Crossing.Y, 124, 0, KAIRN },
		{ "NexusBrazierPedestal", 36, P.Crossing.Y, 124, 0, KAIRN },
		-- War banners & prayer flag lines snapping in the gale at bridgeheads.
		{ "WarBannerPole", -174, P.Basin.Y, 186, 18, BANNER_TINT },
		{ "WarBannerPole", 174, P.Basin.Y, 186, -18, BANNER_TINT },
		{ "WarBannerPole", -150, P.WestBastion.Y, -176, 15, BANNER_TINT },
		{ "WarBannerPole", 150, P.EastBastion.Y, -176, -15, BANNER_TINT },
		{ "WarBannerPole", -150, P.WestAerie.Y, -286, 20, BANNER_TINT },
		{ "WarBannerPole", 150, P.EastAerie.Y, -286, -20, BANNER_TINT },
		{ "PrayerFlagLine", -222, P.WestGallery.Y, 54, 42, Tints.FLAG },
		{ "PrayerFlagLine", 222, P.EastGallery.Y, 54, -42, Tints.FLAG },
		{ "PrayerFlagLine", -180, P.WestPinion.Y, -6, 12, Tints.FLAG },
		{ "PrayerFlagLine", 180, P.EastPinion.Y, -6, -12, Tints.FLAG },
		-- Waystones, anemometer masts, squall-horn perches, rune stones, shed feathers & storm crystals!
		{ "SkybridgeWaystone", -248, P.WestGallery.Y, 58, 30, KAIRN },
		{ "SkybridgeWaystone", -176, P.WestPinion.Y, 4, 20, KAIRN },
		{ "SkybridgeWaystone", -234, P.WestBastion.Y, -104, 15, KAIRN },
		{ "SkybridgeWaystone", -152, P.WestAerie.Y, -236, -15, KAIRN },
		{ "AnemometerMast", 178, P.EastPinion.Y, -44, -20, KAIRN },
		{ "AnemometerMast", -300, P.WestPerch.Y, -38, 12, KAIRN },
		{ "SquallHornPerch", -154, P.WestBastion.Y, -102, 25, KAIRN },
		{ "SquallHornPerch", 154, P.EastBastion.Y, -102, -25, KAIRN },
		{ "RuneStandingStone", -298, P.WestPerch.Y, 10, 40, KAIRN },
		{ "RuneStandingStone", 298, P.EastPerch.Y, 10, -40, KAIRN },
		{ "RuneStandingStone", -292, P.WestCrown.Y, -242, 15, KAIRN },
		{ "ShedRocFeather", -246, P.WestGallery.Y, 64, 30, FEATHER_TINT },
		{ "ShedRocFeather", 246, P.EastGallery.Y, 64, -30, FEATHER_TINT },
		{ "ShedRocFeather", -210, P.WestAerie.Y, -238, 12, FEATHER_TINT },
		{ "ShedRocFeather", 210, P.EastAerie.Y, -238, -12, FEATHER_TINT },
		{ "StormCrystalSpikes", -294, P.WestCrown.Y, -290, 20, FULGURITE_TINT },
		{ "StormCrystalSpikes", 344, P.EastPerch.Y, 10, -25, FULGURITE_TINT },
		{ "StormCrystalSpikes", -248, P.WestGallery.Y, 126, 15, FULGURITE_TINT },
		{ "StormCrystalSpikes", 248, P.EastGallery.Y, 126, -15, FULGURITE_TINT },
		{ "TrailCairnTall", -62, P.Basin.Y, 186, 0, KAIRN },
		{ "TrailCairnTall", 62, P.Basin.Y, 186, 0, KAIRN },
		{ "TrailCairnTall", -248, P.WestGallery.Y, 100, 10, KAIRN },
		{ "TrailCairnTall", 248, P.EastGallery.Y, 100, -10, KAIRN },
		{ "TrailCairnTall", -232, P.WestBastion.Y, -140, 22, KAIRN },
		{ "TrailCairnTall", 232, P.EastBastion.Y, -110, -22, KAIRN },
		{ "BeaconBrazier", -150, P.WestAerie.Y, -264, 0, TOWER_TINT },
		{ "BeaconBrazier", 150, P.EastAerie.Y, -264, 0, TOWER_TINT },
		{ "CapacitorCask", 248, P.EastGallery.Y, 120, 15, KAIRN },
		{ "CapacitorCask", 232, P.EastBastion.Y, -138, -15, KAIRN },
		{ "CopperWireReel", -342, P.WestPerch.Y, -4, 30, KAIRN },
		{ "CopperWireReel", 300, P.EastPerch.Y, -34, -30, KAIRN },
		{ "CopperCableMast", -176, P.WestPinion.Y, -18, 0, KAIRN },
		{ "CopperCableMast", 176, P.EastPinion.Y, -18, 0, KAIRN },
		{ "CliffGroundingChain", -236, P.WestBastion.Y - 42, -142, 90, KAIRN },
		{ "CliffGroundingChain", 236, P.EastBastion.Y - 42, -142, -90, KAIRN },
		{ "LightningSpearBallista", 156, P.EastBastion.Y, -174, -140, KAIRN },
		{ "SignalHornCannon", -288, P.WestCrown.Y, -266, -125, KAIRN },
		{ "StoneUrn", -34, P.Crossing.Y, 72, 0, KAIRN },
		{ "StoneUrn", 34, P.Crossing.Y, 72, 0, KAIRN },
		{ "RuinRubble", -254, P.Basin.Y, 266, 20, KAIRN },
		{ "RuinRubble", 254, P.Basin.Y, 266, -20, KAIRN },
		{ "Cairn", -216, P.Basin.Y, 274, 15, KAIRN },
		{ "Cairn", 216, P.Basin.Y, 274, -15, KAIRN },
		{ "BoulderCluster", -298, P.Basin.Y, 272, 10, KAIRN },
		{ "BoulderCluster", 298, P.Basin.Y, 272, -10, KAIRN },
	}
	for _, dItem in terraceDecor do
		local name, x, y, z, yaw, tint = dItem[1], dItem[2], dItem[3], dItem[4], dItem[5], dItem[6]
		ctx.group("TerraceVignette", function()
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
			piece(name, cf, 1.0, tint or KAIRN, function()
				if name == "TrailCairnTall" or name == "Cairn" then
					fallbackCairn(cf, 1.0)
				elseif name == "RuneStandingStone" or name == "SkybridgeWaystone" then
					fallbackRuneStone(cf, 1.0)
				elseif name == "StormCrystalSpikes" then
					fallbackCrystals(cf, 1.0)
				elseif name == "PrayerFlagLine" then
					fallbackFlags(cf, 1.0)
				else
					boxAt(name .. "StandIn", V(3.4, 5.2, 3.4), cf * CFrame.new(0, 2.6, 0), C.SLATE, Enum.Material.Slate).CanCollide = false
				end
			end)
			props += 1
		end)
	end

	-- 13. Wind-Bent Highland Pines, Cairns, Boulders & Dense Stormgrass Cover across outer caldera rims & terrace edges.
	local windYaw = math.rad(ThunderHighlands.DownwindYaw)
	local function sampleCalderaRim(): (number, number)
		-- Focus scatter onto the elevated caldera walls (west, east, south foreground & far north corners) rather
		-- than wasting tries inside the empty central Cloud Eye.
		local band = rng:NextNumber()
		if band < 0.38 then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			return side * rng:NextNumber(240, w / 2 - 20), rng:NextNumber(-d / 2 + 28, d / 2 - 28)
		elseif band < 0.68 then
			return rng:NextNumber(-w / 2 + 24, w / 2 - 24), rng:NextNumber(268, d / 2 - 22)
		elseif band < 0.86 then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			return side * rng:NextNumber(145, w / 2 - 24), rng:NextNumber(-d / 2 + 22, -305)
		else
			return rng:NextNumber(-w / 2 + 24, w / 2 - 24), rng:NextNumber(-d / 2 + 30, d / 2 - 30)
		end
	end

	local pineTemplates = { "WindBentPine", "PineTree" }
	local pinesPlaced, pineTries = 0, 0
	while pinesPlaced < 84 and pineTries < 900 do
		pineTries += 1
		local px, pz = sampleCalderaRim()
		if not onTerrace(px, pz, 14) and campFree(px, pz, 12) and linkFree(px, pz, 12) then
			local gy = lowestGround(px, pz, 3)
			if gy > abyss + 5 then
				local s = rng:NextNumber(0.7, 1.35)
				local tpl = pineTemplates[(pinesPlaced % 2) + 1]
				ctx.group("CalderaPine", function()
					local cf = CFrame.new(px, gy, pz) * CFrame.Angles(0, windYaw + rng:NextNumber(-0.25, 0.25), 0)
					piece(tpl, cf, s, KAIRN, function() fallbackPine(cf, s) end)
				end)
				pinesPlaced += 1
				props += 1
			end
		end
	end

	-- Outer caldera cliff boulders, cairns, rubble and fulgurite clusters (keeps props well above >= 580!).
	local rockTemplates = { "BoulderCluster", "Cairn", "RuinRubble", "StormCrystalSpikes", "TrailCairnTall" }
	local rocksPlaced, rockTries = 0, 0
	while rocksPlaced < 275 and rockTries < 2200 do
		rockTries += 1
		local rx, rz = sampleCalderaRim()
		if not onTerrace(rx, rz, 10) and campFree(rx, rz, 10) and linkFree(rx, rz, 10) then
			local gy = lowestGround(rx, rz, 2)
			if gy > abyss + 3 then
				local s = rng:NextNumber(0.65, 1.4)
				local tpl = rockTemplates[(rocksPlaced % #rockTemplates) + 1]
				ctx.group("CalderaRock", function()
					local cf = CFrame.new(rx, gy, rz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					piece(tpl, cf, s, if tpl == "StormCrystalSpikes" then FULGURITE_TINT else KAIRN, function()
						if tpl == "StormCrystalSpikes" then
							fallbackCrystals(cf, s)
						elseif tpl == "Cairn" or tpl == "TrailCairnTall" then
							fallbackCairn(cf, s)
						else
							lump("CalderaBoulder", cf.Position + V(0, 1.4 * s, 0), V(5.2, 3.2, 4.4) * s, C.SLATE_DARK, Enum.Material.Slate).CanCollide = false
						end
					end)
				end)
				rocksPlaced += 1
				props += 1
			end
		end
	end

	-- Low non-colliding cairns & stone rubble tucked along outer terrace rims (outside camps and Apex/Sanctuary).
	local rimTerraces = { P.Basin, P.WestGallery, P.EastGallery, P.WestBastion, P.EastBastion, P.WestCrown, P.WestPerch, P.EastPerch, P.WestPinion, P.EastPinion, P.WestAerie, P.EastAerie }
	local rimTemplates = { "RuinRubble", "Cairn", "BoulderCluster", "StoneUrn", "ShedRocFeather" }
	local rimPlaced, rimTries = 0, 0
	while rimPlaced < 68 and rimTries < 650 do
		rimTries += 1
		local t = rimTerraces[(rimTries % #rimTerraces) + 1]
		local edge = rimTries % 4
		local rx: number, rz: number
		if edge == 0 then
			rx = t.X + rng:NextNumber(-t.Width / 2 + 5, t.Width / 2 - 5)
			rz = t.Z + t.Depth / 2 - rng:NextNumber(2.5, 5.5)
		elseif edge == 1 then
			rx = t.X + rng:NextNumber(-t.Width / 2 + 5, t.Width / 2 - 5)
			rz = t.Z - t.Depth / 2 + rng:NextNumber(2.5, 5.5)
		elseif edge == 2 then
			rx = t.X - t.Width / 2 + rng:NextNumber(2.5, 5.5)
			rz = t.Z + rng:NextNumber(-t.Depth / 2 + 5, t.Depth / 2 - 5)
		else
			rx = t.X + t.Width / 2 - rng:NextNumber(2.5, 5.5)
			rz = t.Z + rng:NextNumber(-t.Depth / 2 + 5, t.Depth / 2 - 5)
		end
		if campFree(rx, rz, 8) and linkFree(rx, rz, 8) then
			local s = rng:NextNumber(0.6, 0.95)
			local tpl = rimTemplates[(rimPlaced % #rimTemplates) + 1]
			ctx.group("TerraceRimProp", function()
				local cf = CFrame.new(rx, t.Y, rz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				piece(tpl, cf, s, if tpl == "ShedRocFeather" then FEATHER_TINT else KAIRN, function()
					if tpl == "Cairn" then
						fallbackCairn(cf, s)
					else
						lump("RimStone", cf.Position + V(0, 1.1 * s, 0), V(3.6, 2.2, 3.0) * s, C.SLATE_DARK, Enum.Material.Slate).CanCollide = false
					end
				end)
			end)
			rimPlaced += 1
			props += 1
		end
	end

	-- Ground cover: wind-combed StormgrassTuft clumps along terrace borders & outer caldera slopes (>= 400).
	local coverTries = 0
	while cover < 470 and coverTries < 3200 do
		coverTries += 1
		local gx: number, gz: number, gy: number
		if cover < 185 then
			local t = rimTerraces[(coverTries % #rimTerraces) + 1]
			local edge = coverTries % 4
			if edge == 0 then
				gx = t.X + rng:NextNumber(-t.Width / 2 + 4, t.Width / 2 - 4)
				gz = t.Z + t.Depth / 2 - rng:NextNumber(1.8, 5.8)
			elseif edge == 1 then
				gx = t.X + rng:NextNumber(-t.Width / 2 + 4, t.Width / 2 - 4)
				gz = t.Z - t.Depth / 2 + rng:NextNumber(1.8, 5.8)
			elseif edge == 2 then
				gx = t.X - t.Width / 2 + rng:NextNumber(1.8, 5.8)
				gz = t.Z + rng:NextNumber(-t.Depth / 2 + 4, t.Depth / 2 - 4)
			else
				gx = t.X + t.Width / 2 - rng:NextNumber(1.8, 5.8)
				gz = t.Z + rng:NextNumber(-t.Depth / 2 + 4, t.Depth / 2 - 4)
			end
			gy = t.Y
		else
			gx, gz = sampleCalderaRim()
			if onTerrace(gx, gz, 5) then continue end
			gy = surfaceAt(gx, gz)
			if gy < abyss + 3 then continue end
		end
		if campFree(gx, gz, 6) and linkFree(gx, gz, 7) then
			local s = rng:NextNumber(0.75, 1.45)
			ctx.group("StormgrassCover", function()
				local cf = CFrame.new(gx, gy, gz) * CFrame.Angles(0, windYaw + rng:NextNumber(-0.35, 0.35), 0)
				piece("StormgrassTuft", cf, s, KAIRN, function() fallbackTuft(cf, s) end)
			end)
			cover += 1
		end
	end

	-- Expose census attributes on BiomeAssets (matching Floors 21-29).
	local root = ctx.current()
	if root then
		root:SetAttribute("Floor30Landmarks", landmarks)
		root:SetAttribute("Floor30Props", props)
		root:SetAttribute("Floor30GroundCover", cover)
		root:SetAttribute("Floor30WallRuns", wallRuns)
		root:SetAttribute("Floor30CloudBanks", cloudCount)
	end
end

return ThunderFloor30
