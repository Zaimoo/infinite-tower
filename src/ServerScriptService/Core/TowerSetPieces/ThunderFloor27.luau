--!strict
-- Floor 27, Thunderhead Outpost (Thunder Highlands; docs/prompts/thunder-highlands-floor-layouts-prompt.md, guide
-- image reference/Thunder Highlands 27.jpg): the Kairnfolk's hilltop ringfort and signal station. TowerBiomeAssets
-- calls Build(ctx) for layout.Authored == "thunder:2" with its own builders; the shared helpers, palette and tints
-- come from ThunderHighlands.
--
-- Dry-stone rampart rings banded with verdigris copper wall every terrace (gapped wherever a path crosses), a
-- stone gate-arch spans the arrival causeway, and a palisade of copper-tipped stakes runs along the Stockade
-- Apron's north edge with watch-bell gallows at both gates. In the fort: the Signal Broch's beacon braziers and
-- capacitor casks, cable masts slinging braided copper out to the two wind-harps on the ridge, the copper-smith's
-- forge and wire reels in the Forge Yard, ram pens and a loading chute in the Ram Yard, and the stepped broch keep
-- with its cage lantern and twin spires rising behind Thunderhead Lodge. Longhouse ruins on the outer slopes,
-- ridge beacons and totems on the far peaks, wind-bent pine shelterbelts and stormgrass: three skyline layers.
local ThunderHighlands = require(script.Parent.ThunderHighlands)

local ThunderFloor27 = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local C = ThunderHighlands.Palette
local Tints = ThunderHighlands.Tints
local KAIRN = Tints.KAIRN
local EMBER = rgb(255, 150, 70)
local FIRE_TINT = ThunderHighlands.Tinted(KAIRN, { GLOW = { Color = EMBER, Material = Enum.Material.Neon } })
local LANTERN_TINT = ThunderHighlands.Tinted(KAIRN, {
	CRYSTAL = { Color = rgb(196, 176, 255), Material = Enum.Material.Glass, Transparency = 0.35 },
})
local HARP_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = rgb(170, 150, 120), Material = Enum.Material.Fabric } })
local BELL_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = rgb(196, 70, 52), Material = Enum.Material.Fabric } })

-- The keep: centred behind the Lodge, between the spread boss portals, clear of the summit camp's mob slots.
local KEEP_SCALE = 2.15
local KEEP_Z = -278.8
-- The arrival gate-arch spans the causeway onto the Stockade Apron.
local GATE_Z, GATE_SCALE = 196, 1.08

-- Every fixed Floor 27 landmark's footprint, for the specs (no landmark on a walkway or in a camp) and the census.
-- (The rampart rings, the palisade and the gallows are fitted round the walkways when the floor is built.)
ThunderFloor27.Landmarks = table.freeze({
	{ Id = "LodgeKeep", X = 0, Z = KEEP_Z, Y = 31, HalfX = 23.5, HalfZ = 23.5, Top = 116.7 },
	{ Id = "WestWindHarp", X = -238.8, Z = -141, Y = 18, HalfX = 8.2, HalfZ = 5.1, Top = 60 },
	{ Id = "EastWindHarp", X = 238.7, Z = -143, Y = 24, HalfX = 9.3, HalfZ = 5.7, Top = 68 },
	{ Id = "BeaconWest", X = -30, Z = -62, Y = 16, HalfX = 4.1, HalfZ = 4.1, Top = 10 },
	{ Id = "BeaconEast", X = 30, Z = -62, Y = 16, HalfX = 4.1, HalfZ = 4.1, Top = 10 },
	{ Id = "CaskSW", X = -36, Z = 0, Y = 16, HalfX = 2.1, HalfZ = 2.1, Top = 7.2 },
	{ Id = "CaskSE", X = 36, Z = 0, Y = 16, HalfX = 2.1, HalfZ = 2.1, Top = 7.2 },
	{ Id = "CaskS1", X = -20, Z = 2, Y = 16, HalfX = 2.1, HalfZ = 2.1, Top = 7.2 },
	{ Id = "CaskS2", X = 20, Z = 2, Y = 16, HalfX = 2.1, HalfZ = 2.1, Top = 7.2 },
	{ Id = "CableMastWest", X = -40, Z = 2, Y = 16, HalfX = 3.9, HalfZ = 3.9, Top = 31.5 },
	{ Id = "CableMastEast", X = 40, Z = 2, Y = 16, HalfX = 3.9, HalfZ = 3.9, Top = 31.5 },
	{ Id = "CopperForge", X = 176, Z = 8, Y = 14, HalfX = 6.3, HalfZ = 6.3, Top = 21.4 },
	{ Id = "WireReelNorth", X = 181, Z = -22, Y = 14, HalfX = 3.1, HalfZ = 6.1, Top = 8.6 },
	{ Id = "WireReelSouth", X = 181, Z = -6, Y = 14, HalfX = 3.1, HalfZ = 6.1, Top = 8.6 },
	{ Id = "RamPen", X = -174, Z = 6, Y = 12, HalfX = 11.2, HalfZ = 5.2, Top = 5.2 },
	{ Id = "GateArchWestPier", X = -27, Z = GATE_Z, Y = 0, HalfX = 3.8, HalfZ = 3.8, Top = 24 },
	{ Id = "GateArchEastPier", X = 27, Z = GATE_Z, Y = 0, HalfX = 3.8, HalfZ = 3.8, Top = 24 },
	{ Id = "GateArchSpan", X = 0, Z = GATE_Z, Y = 22, HalfX = 31, HalfZ = 3.8, Top = 14, Straddles = true },
	{ Id = "LonghouseWest", X = -218, Z = 72, HalfX = 16.5, HalfZ = 8, Top = 4.2 },
	{ Id = "LonghouseEast", X = 218, Z = 72, HalfX = 16.5, HalfZ = 8, Top = 4.2 },
}) :: { any }

function ThunderFloor27.Build(ctx: any)
	local H = ThunderHighlands.Helpers(ctx)
	local origin: Vector3, layout, field, bottom: number, w: number, d: number, P = H.origin, H.layout, H.field, H.bottom, H.w, H.d, H.P
	local surfaceAt, lowestGround, boxAt, rod, lump, light = H.surfaceAt, H.lowestGround, H.boxAt, H.rod, H.lump, H.light
	local noCollide, emitter, piece, glowOf = H.noCollide, H.emitter, H.piece, H.glowOf
	local fallbackTotem, fallbackWall, fallbackHurdle, fallbackCairn, fallbackPine = H.fallbackTotem, H.fallbackWall, H.fallbackHurdle, H.fallbackCairn, H.fallbackPine
	local fallbackTuft, fallbackSheep, fallbackFlags = H.fallbackTuft, H.fallbackSheep, H.fallbackFlags
	local landmarks, props, cover = 0, 0, 0

	-- ===================================================================================================
	-- Native fallbacks for the Floor 27 kit (until it is imported). cf: the piece's origin, front +Z.
	-- ===================================================================================================
	local function fallbackKeep(cf: CFrame, s: number)
		for k, tier in { { 10.4, 16, 0 }, { 7.8, 14, 16 }, { 5.6, 11, 30 } } do
			ctx.cyl("KeepDrumWall", (cf * CFrame.new(0, (tier[3] + tier[2] / 2) * s, 0)).Position, tier[1] * s, tier[2] * s, if k % 2 == 0 then C.SLATE_DARK else C.SLATE, Enum.Material.Slate)
			ctx.cyl("KeepVerdigrisBand", (cf * CFrame.new(0, (tier[3] + tier[2] * 0.62) * s, 0)).Position, (tier[1] + 0.3) * s, 0.6 * s, C.VERDIGRIS, Enum.Material.Metal)
		end
		ctx.cyl("KeepTurfCrown", (cf * CFrame.new(0, 42.3 * s, 0)).Position, 5 * s, 2.6 * s, C.TURF, Enum.Material.Grass)
		local lantern = ctx.block("KeepLanternGlowSeam", V(3.6, 4.6, 3.6) * s, (cf * CFrame.new(0, 46.5 * s, 0)).Position, C.STORM, Enum.Material.Neon)
		lantern.CanCollide = false
		ctx.cyl("KeepLanternCap", (cf * CFrame.new(0, 49.6 * s, 0)).Position, 2.8 * s, 1.4 * s, C.COPPER, Enum.Material.Metal)
		for _, sx in { -1, 1 } do
			boxAt("KeepSpire", V(0.6, 10, 0.6) * s, cf * CFrame.new(sx * 4.2 * s, 48 * s, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		end
	end
	local function fallbackHarp(cf: CFrame, s: number)
		boxAt("HarpFooting", V(8.4, 2.4, 6) * s, cf * CFrame.new(0, 1.2 * s, 0), C.SLATE, Enum.Material.Slate)
		boxAt("HarpPost", V(1.4, 28, 1.4) * s, cf * CFrame.new(4.6 * s, 16 * s, 0), C.TIMBER, Enum.Material.Wood)
		for k = 0, 5 do
			local a = math.rad(-8 + k * 18)
			local seg = boxAt("HarpArcBeam", V(2, 9, 1.6) * s, cf * CFrame.new((-3 + 8 * (1 - math.cos(a))) * s, (4 + 36 * math.sin(math.rad(k * 16))) * s, 0) * CFrame.Angles(0, 0, -a * 0.6), C.TIMBER, Enum.Material.Wood)
			seg.CanCollide = false
		end
		for k = 0, 4 do
			local str = boxAt("HarpStringGlowSeam", V(0.2, 18 + k * 3, 0.2) * s, cf * CFrame.new((1 + k * 0.7) * s, (13 + k * 2.4) * s, 0) * CFrame.Angles(0, 0, math.rad(-12)), C.STORM, Enum.Material.Neon)
			str.CanCollide = false
		end
	end
	local function fallbackRampart(cf: CFrame, len: number)
		boxAt("RampartWall", V(len, 8, 3.2), cf * CFrame.new(0, 4, 0), C.SLATE, Enum.Material.Slate)
		boxAt("RampartVerdigrisBand", V(len, 0.5, 3.4), cf * CFrame.new(0, 5.3, 0), C.VERDIGRIS, Enum.Material.Metal)
		boxAt("RampartCoping", V(len, 0.7, 3.6), cf * CFrame.new(0, 8.2, 0), C.SLATE_DARK, Enum.Material.Slate)
	end
	local function fallbackPalisade(cf: CFrame)
		for k = 0, 13 do
			local h = 8.6 + (k * 7 % 5) * 0.4
			boxAt("PalisadeStake", V(0.9, h, 0.9), cf * CFrame.new(-6.5 + k, h / 2, 0), C.TIMBER, Enum.Material.Wood)
			boxAt("PalisadeCopperTip", V(0.6, 1.2, 0.6), cf * CFrame.new(-6.5 + k, h + 0.6, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		end
		boxAt("PalisadeRail", V(14.4, 0.5, 0.4), cf * CFrame.new(0, 3, 0.75), C.TIMBER_DARK, Enum.Material.Wood)
	end
	local function fallbackGallows(cf: CFrame)
		for _, sx in { -1, 1 } do
			boxAt("GallowsPost", V(0.8, 10, 0.8), cf * CFrame.new(sx * 3.2, 5, 0), C.TIMBER, Enum.Material.Wood)
		end
		boxAt("GallowsBeam", V(8.4, 0.9, 0.9), cf * CFrame.new(0, 10.1, 0), C.TIMBER, Enum.Material.Wood)
		local bell = ctx.block("GallowsStormBell", V(2.6, 2.4, 2.6), (cf * CFrame.new(0, 7.4, 0)).Position, rgb(176, 132, 70), Enum.Material.Metal)
		bell.CanCollide = false
	end
	local function fallbackBeacon(cf: CFrame, s: number)
		ctx.cyl("BeaconPlinthWall", (cf * CFrame.new(0, 2.5 * s, 0)).Position, 2.8 * s, 5 * s, C.SLATE, Enum.Material.Slate)
		ctx.cyl("BeaconBasket", (cf * CFrame.new(0, 6.1 * s, 0)).Position, 2.3 * s, 2.2 * s, C.COPPER, Enum.Material.Metal)
		local coals = ctx.block("BeaconCoalsGlowSeam", V(3.2, 0.8, 3.2) * s, (cf * CFrame.new(0, 7.3 * s, 0)).Position, EMBER, Enum.Material.Neon)
		coals.CanCollide = false
	end
	local function fallbackCask(cf: CFrame)
		ctx.cyl("CapacitorCaskBody", (cf * CFrame.new(0, 2.2, 0)).Position, 1.8, 4.4, C.TIMBER, Enum.Material.Wood)
		ctx.cyl("CapacitorCoil", (cf * CFrame.new(0, 2.6, 0)).Position, 2, 2.4, C.COPPER, Enum.Material.Metal)
		boxAt("CapacitorTerminalGlowSeam", V(0.6, 0.6, 0.6), cf * CFrame.new(0, 6.8, 0), C.STORM, Enum.Material.Neon).CanCollide = false
	end
	local function fallbackMast(cf: CFrame)
		boxAt("CableMastPole", V(1.2, 31, 1.2), cf * CFrame.new(0, 15.5, 0), C.TIMBER, Enum.Material.Wood)
		boxAt("CableMastCrossarm", V(7, 0.5, 0.5), cf * CFrame.new(0, 29.5, 0), C.COPPER, Enum.Material.Metal)
	end
	local function fallbackForge(cf: CFrame)
		boxAt("ForgeHearthWall", V(7, 3.6, 5.6), cf * CFrame.new(0, 1.8, 0), C.SLATE, Enum.Material.Slate)
		boxAt("ForgeFirebedGlowSeam", V(4.6, 0.4, 3.2), cf * CFrame.new(0, 3.8, 0), EMBER, Enum.Material.Neon).CanCollide = false
		boxAt("ForgeCopperHood", V(6, 4, 5), cf * CFrame.new(0, 8, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		boxAt("ForgeFlue", V(1.8, 7, 1.8), cf * CFrame.new(0, 13.5, 0.4), C.COPPER, Enum.Material.Metal).CanCollide = false
		boxAt("ForgeAnvil", V(3.2, 1.4, 1.2), cf * CFrame.new(0, 2.9, -6), C.SLATE_DARK, Enum.Material.Metal)
	end
	local function fallbackReel(cf: CFrame)
		local drum = boxAt("WireReelDrum", V(6.2, 5.2, 5.2), cf * CFrame.new(0, 4.4, 0), C.COPPER, Enum.Material.Metal)
		drum.Shape = Enum.PartType.Cylinder
	end
	local function fallbackPen(cf: CFrame)
		for _, z in { -4.5, 4.5 } do
			boxAt("RamPenRail", V(12, 0.4, 0.3), cf * CFrame.new(0, 2.4, z), C.TIMBER, Enum.Material.Wood)
		end
		boxAt("RamPenRail", V(0.3, 0.4, 9), cf * CFrame.new(6, 2.4, 0), C.TIMBER, Enum.Material.Wood)
		local chute = boxAt("RamChuteRamp", V(7, 0.4, 2.6), cf * CFrame.new(9.5, 1.8, 0) * CFrame.Angles(0, 0, math.rad(25)), C.TIMBER, Enum.Material.Wood)
		chute.CanCollide = false
	end
	local function fallbackLonghouse(cf: CFrame)
		for _, sz in { -1, 1 } do
			boxAt("LonghouseRuinWall", V(24, 3.2, 1.6), cf * CFrame.new(0, 1.6, sz * 4.6), C.SLATE, Enum.Material.Slate)
		end
		boxAt("LonghouseRuinWall", V(1.6, 2.4, 8), cf * CFrame.new(12.4, 1.2, 0), C.SLATE, Enum.Material.Slate)
	end
	local function fallbackGateArch(cf: CFrame, s: number)
		for _, sx in { -1, 1 } do
			boxAt("GateArchPierWall", V(6, 21, 6) * s, cf * CFrame.new(sx * 25 * s, 10.5 * s, 0), C.SLATE, Enum.Material.Slate)
		end
		for k = 0, 8 do
			local a = math.pi * (k + 0.5) / 9
			local at = cf * CFrame.new(-math.cos(a) * 25 * s, (21.7 + math.sin(a) * 9) * s, 0)
			boxAt("GateArchVoussoir", V(6.4, 2.8, 5.4) * s, at * CFrame.Angles(0, 0, math.atan2(9 * math.cos(a), 25 * math.sin(a))), C.SLATE_DARK, Enum.Material.Slate)
		end
	end

	for _, lm in ThunderFloor27.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
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

	-- ===================================================================================================
	-- 1. Thunderhead Lodge: the stepped broch keep behind the Lodge with its cage lantern and twin spires,
	--    static crackling off them; beacons and flags at the Lodge's corners.
	-- ===================================================================================================
	local apex = P.Apex
	local keep = piece("LodgeKeep", 0, KEEP_Z, 0, "BrochKeepTower", KEEP_SCALE, LANTERN_TINT, function(cf) fallbackKeep(cf, KEEP_SCALE) end, apex.Y - 1, true)
	light(glowOf(keep), C.STORM, 1.8, 70)
	emitter("KeepLanternSparks", V(0, apex.Y + 47 * KEEP_SCALE, KEEP_Z), C.STORM, 0.6, 7, 3, 1.2, 180, true)
	-- On the Lodge's flanks: its front corners carry the inner ramparts' landings, its back the portals.
	for _, corner in { { -60, -258 }, { 60, -258 } } do
		piece("LodgeCairn", corner[1], corner[2], corner[1] * 0.8, "TrailCairnTall", 1.1, KAIRN, function(cf) fallbackCairn(cf, 1.1) end, apex.Y)
	end
	piece("LodgeFlags", -58, -240, 90, "PrayerFlagLine", 0.75, Tints.FLAG, function(cf) fallbackFlags(cf, 0.75) end, apex.Y)
	piece("LodgeFlags", 58, -240, 90, "PrayerFlagLine", 0.75, Tints.FLAG, function(cf) fallbackFlags(cf, 0.75) end, apex.Y)
	landmarks += 1
	props += 5

	-- ===================================================================================================
	-- 2. The Signal Broch: beacon braziers flanking the foot of the Broch Ascent (their smoke the outpost's
	--    signal), capacitor casks along its south rim, and the two cable masts at its corners.
	-- ===================================================================================================
	local cr = P.Crossing
	for _, sx in { -1, 1 } do
		local beacon = piece("SignalBeacon", sx * 30, -62, 0, "BeaconBrazier", 1.2, FIRE_TINT, function(cf) fallbackBeacon(cf, 1.2) end, cr.Y)
		light(glowOf(beacon), EMBER, 1.6, 40)
		emitter("BeaconSmoke", V(sx * 30, cr.Y + 11, -62), rgb(70, 68, 72), 7, 4, 6, 7, 14, false)
	end
	for _, spot in { { -36, 0 }, { 36, 0 }, { -20, 2 }, { 20, 2 } } do
		piece("CapacitorCask", spot[1], spot[2], spot[1] * 3, "CapacitorCask", 1, KAIRN, fallbackCask, cr.Y)
	end
	local mastTops: { Vector3 } = {}
	for _, sx in { -1, 1 } do
		piece("CableMast", sx * 40, 2, 0, "CopperCableMast", 1, KAIRN, fallbackMast, cr.Y)
		table.insert(mastTops, V(sx * 40, cr.Y + 30.5, 2))
	end
	landmarks += 1
	props += 8

	-- ===================================================================================================
	-- 3. The Wind-Harps on the ridge: a tall harp on each outer tower (the east one the taller), and braided
	--    copper cables slung from the Broch's masts out to their heads, high over every walkway.
	-- ===================================================================================================
	local harps = {
		{ P.WestHarp, -240, -141, 0, 1.4, -238.8 },
		{ P.EastHarp, 240, -143, 180, 1.6, 238.7 },
	}
	for k, h in harps do
		local t, x, z, yaw, s = h[1], h[2], h[3], h[4], h[5]
		local harp = piece("WindHarp", x, z, yaw, "WindHarpTower", s, HARP_TINT, function(cf) fallbackHarp(cf, s) end, t.Y)
		light(glowOf(harp), C.STORM, 1.1, 40)
		emitter("HarpStaticSparks", V(x, t.Y + 26 * s, z), C.STORM, 0.4, 5, 3, 1, 180, true)
		-- The cable from the Broch mast to the harp's head (sagging a little, always 18+ studs over the walks).
		local a = mastTops[k]
		local b = V(x + (if yaw == 0 then -3 else 3) * s, t.Y + 40 * s, z)
		ctx.group("GroundingCable", function()
			-- Hung from the mast and the harp by design: the settle pass must not drop it to the ground.
			ctx.tag("OnTerrain", true)
			local segs = 10
			local prev = a
			for i = 1, segs do
				local f = i / segs
				local pt = a:Lerp(b, f) - V(0, math.sin(f * math.pi) * 6, 0)
				local braid = rod("GroundingCableCopper", prev, pt, 0.35, C.COPPER, Enum.Material.Metal)
				braid.CanCollide = false
				braid.CanQuery = false
				if i % 2 == 0 then
					local spark = rod("GroundingCableGlowSeam", prev + V(0, 0.4, 0), pt + V(0, 0.4, 0), 0.1, C.STORM, Enum.Material.Neon)
					spark.CanCollide = false
					spark.CanQuery = false
				end
				prev = pt
			end
		end)
	end
	landmarks += 2
	props += 4

	-- ===================================================================================================
	-- 4. The East Forge Yard: the copper-smith's forge (its smoke and glow), wire reels, casks and cable
	--    offcuts. The West Ram Yard: the ram pen and loading chute, rams, hurdles.
	-- ===================================================================================================
	local eg, wg = P.EastGallery, P.WestGallery
	local forge = piece("CopperForge", 176, 8, -90, "CopperForgeHearth", 1.1, FIRE_TINT, fallbackForge, eg.Y)
	light(glowOf(forge), EMBER, 1.3, 34)
	emitter("ForgeSmoke", V(176.4, eg.Y + 21, 8), rgb(84, 80, 84), 3, 3, 4, 6, 10, false)
	piece("WireReel", 181, -22, 0, "CopperWireReel", 1, KAIRN, fallbackReel, eg.Y)
	piece("WireReel", 181, -6, 0, "CopperWireReel", 1, KAIRN, fallbackReel, eg.Y)
	piece("ForgeCask", 166, 11, 30, "CapacitorCask", 0.9, KAIRN, fallbackCask, eg.Y)
	piece("RamPen", -174, 6, 0, "RamPenChute", 1, KAIRN, fallbackPen, wg.Y)
	for k, spot in { { -178, 4 }, { -172, 8 }, { -168, 3 } } do
		piece("PennedRam", spot[1], spot[2], k * 70, "HighlandSheep", 1.25, Tints.SHEEP, function(cf) fallbackSheep(cf, 1.25) end, wg.Y)
	end
	piece("RamHurdle", -182, -26, 90, "RamHurdleFence", 1, KAIRN, function(cf) fallbackHurdle(cf, 1) end, wg.Y)
	landmarks += 2
	props += 9

	-- ===================================================================================================
	-- 5. The arrival: the dry-stone gate-arch spanning the causeway onto the Stockade Apron, cairns at its feet.
	-- ===================================================================================================
	ctx.group("RampArch", function()
		-- A gate that spans the walkway on purpose (walkway and camp clearance leave a RampArch alone).
		local cf = CFrame.new(0, P.Basin.Y, GATE_Z)
		if ctx.has("InnerGateArch") then
			ctx.kitAt("InnerGateArch", cf * CFrame.new(0, -0.3, 0), GATE_SCALE, FIRE_TINT)
		else
			fallbackGateArch(cf, GATE_SCALE)
		end
	end)
	landmarks += 1
	props += 1

	-- ===================================================================================================
	-- 6. The rampart rings: dry-stone retaining walls banded in verdigris just outside every terrain terrace's
	--    edge (their copings a parapet above the walk), broken wherever a path crosses, clear of the camps and
	--    the keep. The decks are dry-stone platforms already.
	-- ===================================================================================================
	local ramparts = 0
	local function rampartRing(t: any, out: number)
		local hx, hz = t.Width / 2 + out, t.Depth / 2 + out
		local ch = 8 -- chamfered corners
		local corners = {
			V(-hx + ch, 0, -hz), V(hx - ch, 0, -hz), V(hx, 0, -hz + ch), V(hx, 0, hz - ch),
			V(hx - ch, 0, hz), V(-hx + ch, 0, hz), V(-hx, 0, hz - ch), V(-hx, 0, -hz + ch),
		}
		for i = 1, #corners do
			local a, b = corners[i], corners[i % #corners + 1]
			local length = (b - a).Magnitude
			local n = math.max(1, math.round(length / 15))
			local seg = length / n
			for k = 0, n - 1 do
				local m = a:Lerp(b, (k + 0.5) / n)
				local x, z = t.X + m.X, t.Z + m.Z
				local yaw = math.deg(math.atan2(-(b.Z - a.Z), b.X - a.X))
				local clear = ctx.footprintClear(x, z, seg / 2 + 0.5, 2.4) and campFree(x, z, 2)
					and (x * x + (z - KEEP_Z) ^ 2) > 30 * 30
				if clear then
					local sx = (seg + 0.6) / 16
					ctx.group("RampartWall", function()
						ctx.tag("OnTerrain", true)
						local cf = CFrame.new(x, t.Y - 6.3, z) * CFrame.Angles(0, math.rad(yaw), 0)
						if ctx.has("RampartWallSegment") then
							ctx.kitAt("RampartWallSegment", cf, V(sx, 1, 1), KAIRN)
						else
							fallbackRampart(cf, seg + 0.6)
						end
					end)
					ramparts += 1
				end
			end
		end
	end
	for _, id in { "WestGallery", "Crossing", "EastOuter", "WestInner", "EastHarp", "Apex" } do
		rampartRing(P[id], 2.2)
	end
	props += ramparts
	ctx.setAttribute("Floor27Ramparts", ramparts)

	-- ===================================================================================================
	-- 7. The stockade: a palisade of copper-tipped stakes along the Apron's north edge, opening where the two
	--    gate paths run up to the palisade bastions, a watch-bell gallows at both sides of each opening.
	-- ===================================================================================================
	local stakes, gallows = 0, 0
	local line = { V(-262, 0, -50), V(-205, 0, -5), V(-196, 0, 45), V(-152, 0, 100), V(-60, 0, 100), V(-34, 0, 92),
		V(34, 0, 92), V(60, 0, 100), V(152, 0, 100), V(196, 0, 45), V(205, 0, -5), V(262, 0, -50) }
	local kept: { { any } } = {}
	for i = 1, #line - 1 do
		local a, b = line[i], line[i + 1]
		local length = (b - a).Magnitude
		local n = math.max(1, math.round(length / 14))
		for k = 0, n - 1 do
			local m = a:Lerp(b, (k + 0.5) / n)
			local yaw = math.deg(math.atan2(-(b.Z - a.Z), b.X - a.X))
			local ok = ctx.footprintClear(m.X, m.Z, 7.6, 2.2) and campFree(m.X, m.Z, 4) and not onTerrace(m.X, m.Z, 3)
			table.insert(kept, { m, yaw, ok })
			if ok then
				piece("Palisade", m.X, m.Z, yaw + (k % 2) * 180, "PalisadeWallSpan", 1, KAIRN, fallbackPalisade, lowestGround(m.X, m.Z, 4), true)
				stakes += 1
			end
		end
	end
	-- Gallows where a run of stakes stops at a gate path (a kept span beside a cleared one).
	for i, e in kept do
		local prev, nextE = kept[i - 1], kept[i + 1]
		local atGap = e[3] and ((prev and not prev[3]) or (nextE and not nextE[3]))
		if atGap and gallows < 4 then
			local m: Vector3 = e[1]
			local toward = if prev and not prev[3] then prev[1] else nextE[1]
			local at = m:Lerp(toward, 0.35) + V(0, 0, 5)
			if ctx.footprintClear(at.X, at.Z, 6.5, 2) and not onTerrace(at.X, at.Z, 1) then
				piece("WatchBellGallows", at.X, at.Z, e[2], "WatchBellGallows", 1, BELL_TINT, fallbackGallows, lowestGround(at.X, at.Z, 3), true)
				gallows += 1
			end
		end
	end
	props += stakes + gallows
	ctx.setAttribute("Floor27PalisadeSpans", stakes)
	ctx.setAttribute("Floor27Gallows", gallows)
	landmarks += 1

	-- ===================================================================================================
	-- 8. The outer slopes: two ruined longhouses, ridge beacons and totems on the far peaks.
	-- ===================================================================================================
	for _, spot in { { -218, 72, 20 }, { 218, 72, -20 } } do
		piece("LonghouseRuin", spot[1], spot[2], spot[3], "LonghouseRuin", 1, KAIRN, fallbackLonghouse, lowestGround(spot[1], spot[2], 10), true)
	end
	landmarks += 2
	props += 2
	if field then
		for k, spot in { { -272, -200 }, { 272, -200 }, { -276, 40 }, { 276, 40 }, { -170, -285 }, { 170, -285 } } do
			local x, z = spot[1], spot[2]
			if k <= 2 then
				local beacon = piece("RidgeBeacon", x, z, 0, "BeaconBrazier", 1, ThunderHighlands.Tinted(KAIRN, { GLOW = { Color = C.STORM, Material = Enum.Material.Neon } }), function(cf) fallbackBeacon(cf, 1) end, lowestGround(x, z, 3), true)
				light(glowOf(beacon), C.STORM, 1, 50)
			else
				piece("RidgeTotem", x, z, k * 53, "ForkedBoltTotem", 0.75, KAIRN, function(cf) fallbackTotem(cf, 0.75) end, lowestGround(x, z, 4), true)
			end
		end
		landmarks += 1
		props += 6
	end

	-- ===================================================================================================
	-- 9. Wind-bent pine shelterbelts on the fort's leeward (south-east) and outer slopes, all leaning down
	--    the one gale; moorland clutter and stormgrass ground cover.
	-- ===================================================================================================
	local rng = Random.new(27 * 7919)
	local taken: { { number } } = {}
	for _, lm in ThunderFloor27.Landmarks do
		table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 3 })
	end
	local function spotFree(x: number, z: number, r: number): boolean
		for _, t in taken do
			if (t[1] - x) ^ 2 + (t[2] - z) ^ 2 < (t[3] + r) ^ 2 then
				return false
			end
		end
		return campFree(x, z, r) and ctx.footprintClear(x, z, r, r)
	end
	local pines = 0
	local groves = { { 230, 110 }, { 180, 112 }, { -230, 110 }, { -250, -10 }, { 250, -20 }, { 160, -200 }, { -160, -200 },
		{ 70, 60 }, { -70, 50 }, { 250, -250 }, { -250, -250 }, { 0, 70 } }
	for _, grove in groves do
		for _ = 1, 6 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 20)
			local x, z = grove[1] + math.cos(a) * r, grove[2] + math.sin(a) * r
			local cx, cz = x + 7, z + 7
			if math.abs(x) < w / 2 - 10 and math.abs(z) < d / 2 - 10 and not onTerrace(x, z, 4) and spotFree(cx, cz, 9) then
				table.insert(taken, { cx, cz, 9 })
				local s = rng:NextNumber(0.7, 1.15)
				piece("WindBentPine", x, z, ThunderHighlands.DownwindYaw + rng:NextNumber(-9, 9), "WindBentPine", s, KAIRN, function(cf) fallbackPine(cf, s) end)
				pines += 1
			end
		end
	end
	props += pines
	type ClutterKind = { Name: string, Kit: string?, Scale: number, Tint: any?, Fallback: ((cf: CFrame) -> ())?, R: number }
	local kinds: { ClutterKind } = {
		{ Name = "Cairn", Kit = "Cairn", Scale = 0.9, Tint = KAIRN, Fallback = function(cf) fallbackCairn(cf, 0.5) end, R = 3 },
		{ Name = "Boulders", Kit = "BoulderCluster", Scale = 0.7, Tint = KAIRN, Fallback = function(cf)
			lump("MoorBoulder", (cf * CFrame.new(0, 1, 0)).Position, V(5, 3, 4), C.SLATE, Enum.Material.Slate)
		end, R = 3.6 },
		{ Name = "CapacitorCask", Kit = "CapacitorCask", Scale = 0.8, Tint = KAIRN, Fallback = fallbackCask, R = 2 },
		{ Name = "PeatStack", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			for j = 0, 2 do
				boxAt("PeatTurf", V(3.2, 0.9, 1.4), cf * CFrame.new(0, 0.45 + j * 0.9, (j % 2) * 0.3), C.PEAT, Enum.Material.Ground)
			end
		end, R = 2.4 },
		{ Name = "WoolBale", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			ctx.cyl("WoolBale", (cf * CFrame.new(0, 1.2, 0)).Position, 1.2, 2.2, C.WOOL, Enum.Material.Fabric)
		end, R = 2 },
		{ Name = "GroundingStake", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			boxAt("GroundingStakeCopper", V(0.5, 5, 0.5), cf * CFrame.new(0, 2.5, 0), C.COPPER, Enum.Material.Metal)
			boxAt("GroundingStakeVerdigris", V(0.9, 0.5, 0.9), cf * CFrame.new(0, 5.2, 0), C.VERDIGRIS, Enum.Material.Metal)
		end, R = 1.4 },
		{ Name = "SmallCairn", Kit = "TrailCairnTall", Scale = 0.55, Tint = KAIRN, Fallback = function(cf) fallbackCairn(cf, 0.55) end, R = 1.8 },
		{ Name = "Ram", Kit = "HighlandSheep", Scale = 1.2, Tint = Tints.SHEEP, Fallback = function(cf) fallbackSheep(cf, 1.2) end, R = 2.8 },
	}
	local function vignette(cx: number, cz: number, spread: number, count: number, y: number?)
		local made = 0
		for _ = 1, count * 6 do
			if made >= count then break end
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, spread)
			local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
			local kind = kinds[rng:NextInteger(1, #kinds)]
			local rad = kind.R
			local gy = surfaceAt(x, z)
			local dry = y ~= nil or not field or field.Kind(x, z) ~= "POOL"
			if dry and math.abs(x) < w / 2 - 8 and math.abs(z) < d / 2 - 8 and spotFree(x, z, rad) and (y == nil or math.abs(gy - y) < 0.5) then
				table.insert(taken, { x, z, rad })
				ctx.reserve(x, z, rad)
				local m = piece(kind.Name, x, z, rng:NextNumber(0, 360), kind.Kit, kind.Scale, kind.Tint, kind.Fallback, y)
				noCollide(m)
				made += 1
			end
		end
		return made
	end
	for id, p in P do
		if id ~= "Sanctuary" then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					props += vignette(p.X + sx * (p.Width / 2 - 7), p.Z + sz * (p.Depth / 2 - 7), 8, 3, p.Y)
				end
			end
		end
	end
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		for _, endpoint in { { link.AX, link.AZ }, { link.BX, link.BZ } } do
			for _, side in { -1, 1 } do
				props += vignette(endpoint[1] + nx * side * 26, endpoint[2] + nz * side * 26, 6, 2)
			end
		end
	end
	for _ = 1, 50 do
		props += vignette(rng:NextNumber(-w / 2 + 30, w / 2 - 30), rng:NextNumber(-d / 2 + 40, d / 2 - 60), 14, 3)
	end
	for _ = 1, 1300 do
		local x, z = rng:NextNumber(-w / 2 + 16, w / 2 - 16), rng:NextNumber(-d / 2 + 16, d / 2 - 16)
		local _, onDeck = surfaceAt(x, z)
		local r = 1.5
		if not onDeck and spotFree(x, z, r) and (not field or (field.Slope(x, z) < 0.8 and field.Kind(x, z) ~= "POOL")) then
			table.insert(taken, { x, z, r })
			ctx.reserve(x, z, r)
			local s = rng:NextNumber(0.8, 1.5)
			local m = if rng:NextNumber() < 0.2
				then piece("GroundCover", x, z, rng:NextNumber(0, 360), "BoulderCluster", rng:NextNumber(0.22, 0.4), KAIRN, function(cf)
					lump("MoorStone", (cf * CFrame.new(0, 0.3, 0)).Position, V(2.2, 0.9, 1.8), C.SLATE, Enum.Material.Slate)
				end)
				else piece("GroundCover", x, z, ThunderHighlands.DownwindYaw + rng:NextNumber(-12, 12), "StormgrassTuft", s, KAIRN, function(cf) fallbackTuft(cf, s) end)
			noCollide(m)
			cover += 1
		end
	end

	ctx.setAttribute("Floor27Landmarks", landmarks)
	ctx.setAttribute("Floor27Props", props)
	ctx.setAttribute("Floor27GroundCover", cover)
	ctx.setAttribute("Floor27Pines", pines)
end

return table.freeze(ThunderFloor27)
