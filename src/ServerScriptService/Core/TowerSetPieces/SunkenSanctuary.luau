--!strict
-- Hand-authored set pieces for the Sunken Sanctuary floors (docs/prompts/sunken-sanctuary-floor-layouts-prompt.md).
--
-- Floor 36, Drowned Steps (guide image: reference/Sunken Sanctuary 36.webp): the Nereth city's sea-front at low
-- tide. Turquoise shallows and sandbars under a bright noon; the Pilgrims' Gate (a bell arch over the arrival);
-- the Pilgrim Stair's First Flight under bell arches and rune tablets, its middle flight fallen into the surf
-- with its bell drowned beside it; the Bell Stack, a sheer limestone sea-stack crowned by an open shrine of
-- lancet bays under a golden scallop canopy, the first great Tidebell hanging in it; the wrecked Hollin barge on
-- its sandbar (a graft-knot cider barrel in its hold, a Pale Band rag on its mast); the Tide Claws' shell midden;
-- Cantors' Rock and its ring of lecterns; the Votive Pool's floating lamp bowls; rockpools on the Tidepool Steps
-- and the Upper Pools, spilling seaward; the tide-queen and tide-king, sunk to the knee in the surf; broken
-- colonnades and bell arches standing in the sea; and the Tidewall, the sea standing like a cliff to the north
-- with fish in it and the drowned city's spires beyond.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local SunkenSanctuary = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Mat = Enum.Material

local function swatch(r: number, g: number, b: number, mat: Enum.Material, trans: number?): any
	return { Color = rgb(r, g, b), Material = mat, Transparency = trans }
end
-- Nereth tints: every role of every Floor 36 template, so the kit never falls back to the biome palette.
local NERETH = table.freeze({
	STONE = swatch(214, 206, 186, Mat.Limestone), -- pale limestone
	TRIM = swatch(232, 228, 216, Mat.Marble), -- white marble
	METAL = swatch(132, 100, 60, Mat.Metal), -- bronze
	ACCENT = swatch(96, 172, 152, Mat.Metal), -- verdigris
	GOLD = swatch(228, 186, 92, Mat.Metal),
	GLOW = swatch(120, 244, 240, Mat.Neon), -- aqua rune light
	CANDLE = swatch(255, 210, 140, Mat.Neon),
	WOOD = swatch(110, 90, 70, Mat.Wood),
	SILK = swatch(228, 222, 204, Mat.Fabric),
	FOLIAGE = swatch(74, 132, 92, Mat.Grass), -- kelp and seagrass
	MOSS = swatch(76, 116, 80, Mat.Grass), -- weed at the waterline
	CORAL = swatch(214, 132, 190, Mat.SmoothPlastic), -- pink-violet (never red or orange: telegraphs)
	ALT = swatch(238, 226, 208, Mat.SmoothPlastic), -- shell and nacre
	CRYSTAL = swatch(176, 236, 238, Mat.Glass, 0.25), -- pearl and still water
})
local function tinted(base: any, changes: { [string]: any }): any
	local o = table.clone(base)
	for role, s in changes do
		o[role] = s
	end
	return o
end
local CORAL_WHITE = tinted(NERETH, { CORAL = swatch(236, 230, 222, Mat.SmoothPlastic) })
local CORAL_AQUA = tinted(NERETH, { CORAL = swatch(110, 206, 196, Mat.SmoothPlastic), GLOW = swatch(150, 255, 236, Mat.Neon) })
local CORAL_OCHRE = tinted(NERETH, { CORAL = swatch(214, 184, 112, Mat.SmoothPlastic) })
local CORAL_TINTS = { NERETH, CORAL_WHITE, CORAL_AQUA, CORAL_OCHRE }
-- The weathered statues: pale stone streaked with weed, gilt crowns gone green.
local STATUE = tinted(NERETH, {
	TRIM = swatch(198, 196, 182, Mat.Limestone),
	ACCENT = swatch(86, 150, 128, Mat.Grass),
	GOLD = swatch(150, 170, 120, Mat.Metal),
	GLOW = swatch(120, 244, 240, Mat.Neon),
})
-- The drowned bell under the fallen flight: verdigris all over.
local DROWNED = tinted(NERETH, { METAL = swatch(84, 140, 124, Mat.Metal), GOLD = swatch(120, 150, 110, Mat.Metal) })
local AQUA_LIGHT = rgb(120, 244, 240)
local LAMP_LIGHT = rgb(255, 206, 140)

export type Landmark = InfernalFoundry.Landmark

-- Floor 36's landmark footprints (local floor space, already scaled and turned), checked offline by the specs
-- against every walkway lane and camp, and reserved so the scatter passes keep off them.
SunkenSanctuary.Floor36Landmarks = table.freeze({
	{ Id = "BellShrineNorthBay", X = -85, Z = -275, Y = 30, HalfX = 11.7, HalfZ = 3, Top = 48.4 },
	{ Id = "BellShrineEastBay", X = -36.5, Z = -250, Y = 32, HalfX = 9.4, HalfZ = 11.2, Top = 48.4 },
	{ Id = "BellShrineWestBay", X = -133.5, Z = -250, Y = 32, HalfX = 9.4, HalfZ = 11.2, Top = 48.4 },
	{ Id = "BellStackCanopy", X = -85, Z = -239, Y = 80, HalfX = 54.1, HalfZ = 45.7, Top = 65.9 },
	{ Id = "GreatTidebell", X = -85, Z = -236, Y = 58, HalfX = 12, HalfZ = 10.7, Top = 28 },
	{ Id = "FallenFlight", X = -36, Z = -92, Y = -8.5, HalfX = 18.2, HalfZ = 20.5, Top = 16 },
	{ Id = "DrownedBell", X = -54, Z = -100, Y = -8.5, HalfX = 8, HalfZ = 8, Top = 14 },
	{ Id = "HollinBarge", X = -225, Z = -52, HalfX = 6.1, HalfZ = 18.5, Top = 21.6 },
	{ Id = "ShellMidden", X = -205, Z = 72, Y = 4, HalfX = 6.8, HalfZ = 6.6, Top = 5.9 },
	{ Id = "TideQueen", X = -258, Z = -120, Y = -12, HalfX = 19, HalfZ = 23.7, Top = 122 },
	{ Id = "TideKing", X = 258, Z = -95, Y = -12, HalfX = 19, HalfZ = 23.7, Top = 122 },
	{ Id = "SurfColonnade", X = 92, Z = -234, Y = -8.5, HalfX = 50, HalfZ = 8, Top = 48.4 },
	{ Id = "RubbleBarArch", X = -62, Z = -124, Y = -6, HalfX = 17, HalfZ = 12, Top = 37.8 },
	{ Id = "EastSurfArch", X = 214, Z = -172, Y = -8.5, HalfX = 18, HalfZ = 10, Top = 37.8 },
	{ Id = "Tidewall", X = 0, Z = -294, Y = -4, HalfX = 285, HalfZ = 4, Top = 200 },
}) :: { Landmark }

-- The Pilgrim Stair's gap: where the middle flight fell (between the Pilgrims' Landing and the Bell Landing).
SunkenSanctuary.Floor36Gap = table.freeze({ X = -36, Z = -90 })

local function facing(x: number, z: number, tx: number, tz: number): number
	return math.deg(math.atan2(tx - x, tz - z))
end

function SunkenSanctuary.Floor36(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number = H.field, H.bottom, H.d
	local w: number = ctx.w
	local h: number = ctx.h
	local layout = ctx.layout
	local P = layout.Platforms
	local boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local origin: Vector3 = ctx.origin
	local waterY: number = if field then field.LiquidLevel else bottom
	local seabed = bottom - 4.5
	local landmarks, props, cover = 0, 0, 0
	local kindsUsed: { [string]: number } = {}
	local rng = Random.new(36 * 7907)

	local function rod(name: string, a: Vector3, b: Vector3, radius: number, color: Color3, mat: Enum.Material): Part
		local delta = b - a
		local len = math.max(0.1, delta.Magnitude)
		local p = ctx.block(name, V(len, radius * 2, radius * 2), (a + b) / 2, color, mat, Enum.PartType.Cylinder)
		local dir = if delta.Magnitude > 1e-3 then delta.Unit else Vector3.yAxis
		local ref = if math.abs(dir.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local up = (ref - dir * ref:Dot(dir)).Unit
		p.CFrame = CFrame.fromMatrix(origin + (a + b) / 2, dir, up, dir:Cross(up))
		return p
	end
	local function sw(tint: any, role: string): (Color3, Enum.Material)
		local s = tint[role]
		return s.Color, s.Material
	end
	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end
	-- A group placed at a deliberate height (in the surf, hung under a deck): the settle pass leaves it.
	local function pinnedGroup(kind: string, build: () -> ())
		ctx.group(kind, function()
			ctx.tag("OnTerrain", true)
			build()
		end)
	end
	local function count(kitName: string?)
		if kitName then kindsUsed[kitName] = (kindsUsed[kitName] or 0) + 1 end
	end

	for _, lm in SunkenSanctuary.Floor36Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end
	local taken: { { number } } = {}
	for _, lm in SunkenSanctuary.Floor36Landmarks do
		if lm.Id ~= "Tidewall" and lm.Id ~= "BellStackCanopy" and lm.Id ~= "GreatTidebell" then
			table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
		end
	end
	-- A spot is free when it keeps off every lane, every camp (36 studs plus its own radius) and every spot taken.
	local function free(x: number, z: number, r: number): boolean
		if math.abs(x) > w / 2 - 10 or math.abs(z) > d / 2 - 14 then return false end
		for _, camp in layout.Camps do
			if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (36 + r) ^ 2 then return false end
		end
		for _, t in taken do
			if (t[1] - x) ^ 2 + (t[2] - z) ^ 2 < (t[3] + r) ^ 2 then return false end
		end
		return ctx.footprintClear(x, z, r + 1, r + 1)
	end
	local function take(x: number, z: number, r: number)
		table.insert(taken, { x, z, r })
		ctx.reserve(x, z, r)
	end

	---------------------------------------------------------------------------------------------------
	-- Part-built fallbacks (until the Floor 36 kit is imported). cf: the piece's origin on its surface, front +Z.
	---------------------------------------------------------------------------------------------------
	local function fbBell(tint: any, s: number): (CFrame) -> ()
		return function(cf: CFrame)
			local mc, mm = sw(tint, "METAL")
			local gc, gm = sw(tint, "GOLD")
			-- Unrotated blocks only: the camp clearance reads a part's own Y size as its height.
			boxAt("TidebellWaist", V(9, 7, 9) * s, cf * CFrame.new(0, 9.5 * s, 0), mc, mm)
			boxAt("TidebellBody", V(12, 6.5, 12) * s, cf * CFrame.new(0, 4.2 * s, 0), mc, mm)
			boxAt("TidebellCrown", V(6, 2, 6) * s, cf * CFrame.new(0, 14 * s, 0), mc, mm)
			boxAt("TidebellLip", V(14, 1, 14) * s, cf * CFrame.new(0, 0.5 * s, 0), gc, gm)
			local wc, wm = sw(tint, "WOOD")
			boxAt("TidebellYoke", V(16, 2.2, 2) * s, cf * CFrame.new(0, 17.6 * s, 0), wc, wm)
		end
	end
	local function fbBay(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local sc, sm = sw(tint, "STONE")
			local tc, tm = sw(tint, "TRIM")
			for _, x in { -9, 9 } do
				boxAt("BayColumnBase", V(5.2, 2.4, 5.2), cf * CFrame.new(x, 1.2, 0), tc, tm)
				local col = boxAt("BayColumn", V(30, 3.9, 3.9), cf * CFrame.new(x, 17.4, 0) * CFrame.Angles(0, 0, math.pi / 2), sc, sm)
				col.Shape = Enum.PartType.Cylinder
				boxAt("BayCapital", V(5, 2.8, 5), cf * CFrame.new(x, 33.8, 0), tc, tm)
			end
			for _, sgn in { -1, 1 } do
				boxAt("BayArchHalf", V(13, 2.4, 3.4), cf * CFrame.new(sgn * 4.6, 40.5, 0) * CFrame.Angles(0, 0, sgn * -math.rad(48)), sc, sm)
			end
			boxAt("BayCoping", V(22.6, 1.6, 3), cf * CFrame.new(0, 47.6, 0), sc, sm)
		end
	end
	local function fbBrokenColumn(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local sc, sm = sw(tint, "STONE")
			local col = boxAt("BrokenColumnShaft", V(18, 3.9, 3.9), cf * CFrame.new(0, 9.4, 0) * CFrame.Angles(0, 0, math.pi / 2), sc, sm)
			col.Shape = Enum.PartType.Cylinder
			local drum = boxAt("BrokenColumnDrum", V(5.2, 3.9, 3.9), cf * CFrame.new(6, 1.95, -2) * CFrame.Angles(0, 0.4, 0), sc, sm)
			drum.Shape = Enum.PartType.Cylinder
		end
	end
	local function fbArch(tint: any, s: number): (CFrame) -> ()
		return function(cf: CFrame)
			local sc, sm = sw(tint, "STONE")
			local tc, tm = sw(tint, "TRIM")
			for _, x in { -14.8, 14.8 } do
				boxAt("BellArchPier", V(5, 22, 6.2) * s, cf * CFrame.new(x * s, 11 * s, 0), sc, sm)
			end
			for k = 0, 5 do
				local a0 = math.pi * (k + 0.5) / 6
				boxAt("BellArchVoussoir", V(8.2, 4.6, 6) * s, cf * CFrame.new(math.cos(a0) * 14.8 * s, (23 + math.sin(a0) * 11.5) * s, 0) * CFrame.Angles(0, 0, a0 - math.pi / 2 + math.pi / 2), sc, sm)
			end
			boxAt("BellArchKeystone", V(4, 5.4, 6.6) * s, cf * CFrame.new(0, 35 * s, 0), tc, tm)
			fbBell(tint, 0.42 * s)(cf * CFrame.new(0, 24.8 * s, 0))
		end
	end
	local function fbCanopy(cf: CFrame)
		local gc, gm = sw(NERETH, "GOLD")
		local tc, tm = sw(NERETH, "TRIM")
		for k = 0, 19 do
			local a = k * math.pi * 2 / 20
			boxAt("ShellCanopyRing", V(14.5, 3, 3), cf * CFrame.new(math.cos(a) * 44, 2, -6 + math.sin(a) * 38) * CFrame.Angles(0, -a + math.pi / 2, 0), tc, tm)
		end
		lump("ShellCanopyDome", (cf * CFrame.new(0, 24, -6)).Position, V(104, 36, 90), gc, gm)
	end
	local function fbBarge(cf: CFrame)
		local wc, wm = sw(NERETH, "WOOD")
		local tc, tm = sw(NERETH, "TRIM")
		for _, s in { -1, 1 } do
			boxAt("BargeSide", V(40, 6, 1.2), cf * CFrame.new(0, 4, s * 6) * CFrame.Angles(s * 0.12, 0, 0), wc, wm)
		end
		boxAt("BargeDeck", V(18, 0.6, 10), cf * CFrame.new(0, 6.5, 0), tc, tm)
		rod("BargeMast", (cf * CFrame.new(2, 1, 0)).Position, (cf * CFrame.new(2.6, 25, 0.4)).Position, 0.6, wc, wm)
		local sc, sm = sw(NERETH, "SILK")
		boxAt("BargeRag", V(8, 7, 0.2), cf * CFrame.new(1, 17, 0.8), sc, sm)
	end
	local function fbFlight(cf: CFrame)
		local sc, sm = sw(NERETH, "STONE")
		for k = 0, 9 do
			boxAt("FallenTread", V(18, 1.6, 3.4), cf * CFrame.new(((k * 7) % 5 - 2) * 1.5, 1 + (k % 3) * 1.2, -15 + k * 3.4) * CFrame.Angles(math.rad((k % 4) * 6 - 9), math.rad(k * 9 % 20 - 10), math.rad((k % 3) * 8 - 8)), sc, sm)
		end
	end
	local function fbLamp(cf: CFrame)
		local mc, mm = sw(NERETH, "METAL")
		local cc, cm = sw(NERETH, "CANDLE")
		local bowl = boxAt("VotiveBowl", V(0.8, 2.6, 2.6), cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), mc, mm)
		bowl.Shape = Enum.PartType.Cylinder
		boxAt("VotiveFlame", V(0.5, 1.2, 0.5), cf * CFrame.new(0, 1.3, 0), cc, cm)
	end
	local function fbMidden(cf: CFrame)
		local ac, am = sw(NERETH, "ALT")
		local cc, cm = sw(NERETH, "CORAL")
		lump("MiddenHeap", (cf * CFrame.new(0, 1, 0)).Position, V(13, 4, 11), ac, am)
		lump("MiddenCarapace", (cf * CFrame.new(3, 2.6, 1)).Position, V(3, 1.4, 2.4), cc, cm)
	end
	local function fbTablet(cf: CFrame)
		local sc, sm = sw(NERETH, "STONE")
		local gc, gm = sw(NERETH, "GLOW")
		boxAt("RuneTabletSlab", V(4.4, 9, 1.4), cf * CFrame.new(0, 4.5, 0), sc, sm)
		boxAt("RuneTabletGlyph", V(2.2, 2.2, 0.2), cf * CFrame.new(0, 6.6, 0.75), gc, gm)
	end
	local function fbLectern(cf: CFrame)
		local sc, sm = sw(NERETH, "STONE")
		local tc, tm = sw(NERETH, "TRIM")
		boxAt("LecternPillar", V(1.6, 4, 1.6), cf * CFrame.new(0, 2, 0), sc, sm)
		boxAt("LecternSlab", V(3.6, 0.45, 2.6), cf * CFrame.new(0, 4.5, 0) * CFrame.Angles(0.42, 0, 0), tc, tm)
	end
	local function fbTidepool(cf: CFrame)
		local sc, sm = sw(NERETH, "STONE")
		for k = 0, 7 do
			local a = k * math.pi / 4
			lump("TidepoolRock", (cf * CFrame.new(math.cos(a) * 6.5, 1, math.sin(a) * 5.5)).Position, V(4, 2.6, 3.4), sc, sm)
		end
		local wc, wm = sw(NERETH, "CRYSTAL")
		boxAt("TidepoolWater", V(11, 0.2, 9), cf * CFrame.new(0, 1, 0), wc, wm, 0.3)
	end
	local function fbClam(cf: CFrame)
		local ac, am = sw(NERETH, "ALT")
		lump("ClamValve", (cf * CFrame.new(0, 1, 0)).Position, V(8, 2.4, 6), ac, am)
		lump("ClamPearl", (cf * CFrame.new(0, 2.2, 0.4)).Position, V(2, 2, 2), rgb(240, 240, 236), Mat.SmoothPlastic)
	end
	local function fbKelp(cf: CFrame)
		local fc, fm = sw(NERETH, "FOLIAGE")
		for k = 0, 3 do
			local a = k * math.pi / 2
			rod("KelpStipe", (cf * CFrame.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)).Position, (cf * CFrame.new(math.cos(a) * 2.4, 18 + k * 2, math.sin(a) * 2.4)).Position, 0.35, fc, fm)
		end
	end
	local function fbCoral(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local cc, cm = sw(tint, "CORAL")
			for k = 0, 3 do
				local a = k * math.pi / 2 + 0.4
				rod("CoralBranch", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(math.cos(a) * 3, 5 + k, math.sin(a) * 3)).Position, 0.5, cc, cm)
			end
		end
	end
	local function fbFan(cf: CFrame)
		local cc, cm = sw(NERETH, "CORAL")
		boxAt("SeaFanBlade", V(7, 8, 0.3), cf * CFrame.new(0, 5, 0), cc, cm)
	end
	local function fbAnemone(cf: CFrame)
		local cc, cm = sw(NERETH, "CORAL")
		lump("AnemoneBody", (cf * CFrame.new(0, 1, 0)).Position, V(3, 2, 3), cc, cm)
	end
	local function fbSeagrass(cf: CFrame)
		local fc, fm = sw(NERETH, "FOLIAGE")
		boxAt("SeagrassBlade", V(0.3, 2.2, 1.6), cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.2), fc, fm)
	end
	local function fbStatue(cf: CFrame, s: number)
		local sc, sm = sw(STATUE, "TRIM")
		boxAt("StatueRobe", V(18, 40, 14) * s, cf * CFrame.new(0, 20 * s, 0), sc, sm)
		lump("StatueHead", (cf * CFrame.new(0, 46 * s, 0)).Position, V(9, 11, 9) * s, sc, sm)
		local gc, gm = sw(STATUE, "GOLD")
		rod("StatueTrident", (cf * CFrame.new(10 * s, 0, 3 * s)).Position, (cf * CFrame.new(10 * s, 64 * s, 3 * s)).Position, 0.9 * s, gc, gm)
	end

	-- One placement: a prop group at (x, z) on whatever is under it (or at y), counted towards the census.
	local function place(kind: string, kitName: string?, x: number, z: number, yaw: number, s: number, tint: any, fallback: ((CFrame) -> ())?, y: number?, roll: CFrame?): Instance?
		local m = piece(kind, x, z, yaw, kitName, s, tint, fallback, y, roll)
		if m then count(kitName or kind) end
		return m
	end

	---------------------------------------------------------------------------------------------------
	-- 1. The Bell Stack: an open shrine of lancet bays round the back of the sea-stack, a golden scallop canopy
	--    over the whole crown, and the first great Tidebell hanging under it, high over the Alpha's camp.
	---------------------------------------------------------------------------------------------------
	local apex = P.Apex
	for _, bay in {
		{ "BellShrineBay", -85, -275, 0, 30 },
		{ "BellShrineBay", -36.5, -250, facing(-36.5, -250, -85, -228), 32 },
		{ "BellShrineBay", -133.5, -250, facing(-133.5, -250, -85, -228), 32 },
	} do
		local m = place(bay[1] :: string, "LancetArchBay", bay[2] :: number, bay[3] :: number, bay[4] :: number, 1, NERETH, fbBay(NERETH), bay[5] :: number)
		if m then landmarks += 1 end
	end
	local canopy = place("BellStackCanopy", "GoldenShellCanopy", apex.X, -238, 0, 1.9, NERETH, fbCanopy, 80)
	if canopy then
		landmarks += 1
		local pearl = H.glowOf(canopy)
		if pearl then light(pearl, AQUA_LIGHT, 1.6, 70) end
	end
	local bell = place("BellStackTidebell", "GreatTidebell", apex.X, -236, 20, 1.5, NERETH, fbBell(NERETH, 1.5), 58)
	if bell then
		landmarks += 1
		pinnedGroup("BellStackTidebell", function()
			-- The bell's chain to the canopy's crown.
			rod("TidebellChain", V(apex.X, 86, -236), V(apex.X, 104, -238), 0.6, rgb(132, 100, 60), Mat.Metal)
		end)
	end

	---------------------------------------------------------------------------------------------------
	-- 2. The Pilgrim Stair: bell arches over the First Flight's foot and top and over the Bell Stair's foot,
	--    rune tablets flanking them, the landing's sheared north edge, and the fallen flight in the surf.
	---------------------------------------------------------------------------------------------------
	local function linkOf(id: string): any
		for _, link in layout.Links do
			if link.Id == id then return link end
		end
		return nil
	end
	local function archOver(link: any, atA: boolean, inset: number)
		if not link then return end
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		local x = if atA then link.AX - ux * inset else link.BX + ux * inset
		local z = if atA then link.AZ - uz * inset else link.BZ + uz * inset
		local y = if atA then link.AY else link.BY
		local yaw = math.deg(math.atan2(ux, uz))
		-- The arch's opening (32 studs at this scale) spans the 28-stud flight; its piers stand clear outside it.
		place("NerethBellArch", "BellArch", x, z, yaw, 1.3, NERETH, fbArch(NERETH, 1.3), y)
		props += 1
		-- Rune tablets beside the arch's piers, facing down the flight.
		for _, side in { -1, 1 } do
			local tx, tz = x + uz * side * 30, z - ux * side * 30
			if free(tx, tz, 3) then
				take(tx, tz, 3)
				local m = place("RuneTablet", "RuneTablet", tx, tz, yaw + 180, 1.1, NERETH, fbTablet, y)
				local glyph = H.glowOf(m)
				if glyph and side == 1 then light(glyph, AQUA_LIGHT, 0.9, 22) end
				props += 1
			end
		end
	end
	archOver(linkOf("Crossing_PilgrimLanding"), true, 2)
	archOver(linkOf("Crossing_PilgrimLanding"), false, 2)
	archOver(linkOf("BellLanding_Apex"), true, 2)

	-- The Pilgrims' Landing's sheared north edge: jagged slabs hanging off it over the surf.
	local landing = P.PilgrimLanding
	pinnedGroup("ShearedLandingEdge", function()
		local sc, sm = sw(NERETH, "STONE")
		for k = 0, 6 do
			local x = landing.X - landing.Width / 2 + 6 + k * (landing.Width - 12) / 6
			local drop = 2 + (k * 37 % 5)
			local blk = boxAt("ShearedSlab", V(8.4, drop + 3, 3.2), CFrame.new(x, landing.Y - 3 - drop / 2, landing.Z - landing.Depth / 2 - 1.2) * CFrame.Angles(math.rad((k % 3) * 7 - 7), 0, math.rad((k % 2) * 10 - 5)), sc, sm)
			blk.CanCollide = false
		end
		-- The piers that still carry the landing.
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local px, pz = landing.X + sx * (landing.Width / 2 - 6), landing.Z + sz * (landing.Depth / 2 - 6)
				local pierH = landing.Y - 3 - seabed
				local pier = boxAt("LandingPier", V(6, pierH, 6), CFrame.new(px, seabed + pierH / 2, pz), sc, sm)
				pier.CanCollide = false
			end
		end
	end)

	local flight = place("FallenFlight", "FallenStairFlight", -36, -92, -24.4, 0.8, NERETH, fbFlight, seabed)
	if flight then pin(flight); landmarks += 1 end
	local drowned = place("DrownedBell", "GreatTidebell", -54, -100, 30, 0.9, DROWNED, fbBell(DROWNED, 0.9), seabed + 2, CFrame.Angles(0, 0, math.rad(78)))
	if drowned then pin(drowned); landmarks += 1 end
	-- The Bell Landing's broken lip: the flight's top treads, snapped off over the gap.
	local bellLanding = P.BellLanding
	pinnedGroup("BrokenFlightTop", function()
		local sc, sm = sw(NERETH, "STONE")
		local tc, tm = sw(NERETH, "TRIM")
		for k = 0, 3 do
			boxAt("BrokenTread", V(16 - k * 2.5, 1.6, 3.4), CFrame.new(-10 + k * 0.8, bellLanding.Y - 2.6 - k * 1.6, bellLanding.Z + bellLanding.Depth / 2 + 4 + k * 3.2) * CFrame.Angles(math.rad(-4 * k), 0, math.rad(k * 3)), if k % 2 == 0 then sc else tc, if k % 2 == 0 then sm else tm).CanCollide = false
		end
	end)

	---------------------------------------------------------------------------------------------------
	-- 3. The Pilgrims' Gate: a bell arch over the arrival's exit, banners and rope posts.
	---------------------------------------------------------------------------------------------------
	local safe = layout.Sanctuary
	local gate = place("NerethBellArch", "BellArch", 0, safe.Z - safe.Depth / 2 + 6, 0, 1.3, NERETH, fbArch(NERETH, 1.3), safe.Y)
	if gate then
		landmarks += 1
		pinnedGroup("NerethBellArch", function()
			-- The gate's banners and rope barrier: the arch's own dressing (exempt like the arch, outside the exit lane).
			local sc, sm = sw(NERETH, "SILK")
			for _, s in { -1, 1 } do
				local bx = s * 22.2
				local banner = boxAt("GateBanner", V(4.6, 12, 0.3), CFrame.new(bx, safe.Y + 20, safe.Z - safe.Depth / 2 + 10.4), rgb(46, 148, 160), Mat.Fabric)
				banner.CanCollide = false
				boxAt("GateBannerShell", V(2.4, 2.4, 0.2), CFrame.new(bx, safe.Y + 22, safe.Z - safe.Depth / 2 + 10.6), sc, sm).CanCollide = false
			end
			-- Rope posts along the landing's sides, off its exit.
			local wc, wm = sw(NERETH, "WOOD")
			for _, s in { -1, 1 } do
				for k = 0, 3 do
					local px, pz = s * (safe.Width / 2 - 3), safe.Z - safe.Depth / 2 + 10 + k * 12
					boxAt("GateRopePost", V(1.2, 4, 1.2), CFrame.new(px, safe.Y + 2, pz), wc, wm)
					if k < 3 then
						local rope = boxAt("GateRope", V(0.3, 0.3, 12), CFrame.new(px, safe.Y + 3.2, pz + 6), rgb(170, 146, 108), Mat.Fabric)
						rope.CanCollide = false
					end
				end
			end
		end)
		for _, s in { -1, 1 } do
			local lampAt = V(s * 30, safe.Y, safe.Z - safe.Depth / 2 + 6)
			local m = place("GateLamp", "VotiveLampBowl", lampAt.X, lampAt.Z, 0, 1.6, NERETH, fbLamp, safe.Y + 4)
			ctx.group("GateLampPost", function()
				local tc, tm = sw(NERETH, "TRIM")
				boxAt("GateLampPedestal", V(2.6, 4, 2.6), CFrame.new(lampAt.X, safe.Y + 2, lampAt.Z), tc, tm)
			end)
			local flame = m and (m:FindFirstChild("CANDLE", true) or m:FindFirstChild("VotiveFlame", true))
			if flame and s == 1 then light(flame, LAMP_LIGHT, 1.1, 28) end
			props += 2
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 4. The Hollin barge beached on its sandbar beside the salvage deck, the Shell Midden and Cantors' Rock.
	---------------------------------------------------------------------------------------------------
	local barge = place("HollinBarge", "HollinBarge", -225, -52, 90, 0.8, NERETH, fbBarge)
	if barge then landmarks += 1 end
	local midden = place("ShellMidden", "ShellMidden", -205, 72, 30, 1, NERETH, fbMidden)
	if midden then landmarks += 1 end
	-- The Coral Warden's watch-post on the midden: a snapped column and a rune tablet off the camp.
	for _, spot in { { -206, 18, "BrokenLancetColumn", 0.8 }, { -134, 66, "RuneTablet", 1 }, { -208, 46, "GiantClam", 1.2 } } do
		local x, z = spot[1] :: number, spot[2] :: number
		if free(x, z, 6) then
			take(x, z, 6)
			local kit = spot[3] :: string
			place("MiddenWatch", kit, x, z, rng:NextNumber(0, 360), spot[4] :: number, NERETH,
				if kit == "BrokenLancetColumn" then fbBrokenColumn(NERETH) elseif kit == "RuneTablet" then fbTablet else fbClam)
			props += 1
		end
	end
	local cantor = P.CantorRock
	-- A half-ring on the rock's west side, clear of the two landings that cross its east half.
	local ringX, ringZ = cantor.X - 20, cantor.Z - 12
	for k = 0, 5 do
		local a = math.rad(100 + k * 32)
		local x, z = ringX + math.cos(a) * 9, ringZ + math.sin(a) * 9
		if free(x, z, 2.2) then
			take(x, z, 2.2)
			place("CantorLectern", "CantorLectern", x, z, facing(x, z, ringX, ringZ), 1.2, NERETH, fbLectern, cantor.Y)
			props += 1
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 5. The colossi, the surf ruins and the Tidewall.
	---------------------------------------------------------------------------------------------------
	local queen = place("TideQueen", "RobedStatueTrident", -258, -120, 90, 1.9, STATUE, function(cf) fbStatue(cf, 1.9) end, -12)
	if queen then pin(queen); landmarks += 1 end
	local king = place("TideKing", "RobedStatueStaff", 258, -95, -90, 1.9, STATUE, function(cf) fbStatue(cf, 1.9) end, -12)
	if king then pin(king); landmarks += 1 end
	pinnedGroup("StatueKelpCrowns", function()
		-- Kelp trailing from both crowns (the queen's and the king's heads stand ~110 over the surf).
		local fc, fm = sw(NERETH, "FOLIAGE")
		for _, at in { V(-258, 104, -120), V(258, 104, -95) } do
			for k = 0, 4 do
				local a = k * math.pi * 2 / 5
				rod("CrownKelp", at + V(math.cos(a) * 7, 0, math.sin(a) * 7), at + V(math.cos(a) * 9, -18 - k * 3, math.sin(a) * 9), 0.5, fc, fm).CanCollide = false
			end
		end
	end)

	local surf = 0
	for _, ruin in {
		{ "SurfColonnade", "LancetArchBay", 52, -232, 0 },
		{ "SurfColonnade", "BrokenLancetColumn", 88, -236, 0 },
		{ "SurfColonnade", "LancetArchBay", 124, -232, 0 },
		{ "SurfBellArch", "BellArch", -62, -124, 30 },
		{ "SurfBellArch", "BellArch", 214, -172, -20 },
	} do
		local kit = ruin[2] :: string
		local m = place(ruin[1] :: string, kit, ruin[3] :: number, ruin[4] :: number, ruin[5] :: number, 1, NERETH,
			if kit == "BellArch" then fbArch(NERETH, 1) elseif kit == "LancetArchBay" then fbBay(NERETH) else fbBrokenColumn(NERETH), seabed + 1)
		if m then pin(m); surf += 1 end
	end
	landmarks += surf

	pinnedGroup("TidewallFace", function()
		-- The sea standing as a cliff beyond the far shore: translucent water, a foam line, caustic bands and
		-- the dark shapes of fish shoals in it.
		local face = rgb(40, 150, 168)
		local segs = 12
		for k = 0, segs - 1 do
			local x0 = -w / 2 + k * w / segs
			local x = x0 + w / segs / 2
			local bow = 3 * math.cos((x / (w / 2)) * math.pi / 2)
			local slab = ctx.block("TidewallWater", V(w / segs + 1, 196, 4), V(x, -4 + 98, -d / 2 + 6 + bow), face, Mat.SmoothPlastic, nil, 0.22)
			slab.CanCollide = false
			slab.CanQuery = false
			slab.CastShadow = false
			local band = ctx.block("TidewallCaustic", V(w / segs + 1, 1.2, 0.4), V(x, 60 + (k % 3) * 34, -d / 2 + 8.2 + bow), rgb(150, 250, 246), Mat.Neon, nil, 0.55)
			band.CanCollide = false
			local foam = ctx.block("TidewallFoam", V(w / segs + 1, 6, 6), V(x, 64 + (k % 2) * 4, -d / 2 + 9 + bow), rgb(232, 248, 246), Mat.SmoothPlastic, nil, 0.15)
			foam.CanCollide = false
		end
		for k = 1, 22 do
			local x = rng:NextNumber(-w / 2 + 20, w / 2 - 20)
			local y = rng:NextNumber(80, 180)
			local fish = ctx.block("TidewallShoal", V(rng:NextNumber(6, 14), rng:NextNumber(1.2, 2.6), 0.3), V(x, y, -d / 2 + 8.6), rgb(26, 84, 104), Mat.SmoothPlastic, nil, 0.25)
			fish.CanCollide = false
			fish.CFrame = fish.CFrame * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12)))
		end
		-- The drowned city beyond: pale cathedral spires over the wall's crest.
		for k = 0, 8 do
			local x = -200 + k * 50 + rng:NextNumber(-10, 10)
			local tall = rng:NextNumber(14, 34) * (if k == 4 then 1.5 else 1)
			ctx.block("DrownedSpireTower", V(10, tall, 6), V(x, 192 + tall / 2, -d / 2 + 4), rgb(178, 214, 216), Mat.SmoothPlastic, nil, 0.35).CanCollide = false
			local tip = ctx.beam("DrownedSpireTip", V(x, 192 + tall, -d / 2 + 4), V(x, 192 + tall + 16, -d / 2 + 4), 2.4, rgb(178, 214, 216), Mat.SmoothPlastic, 0.35)
			tip.CanCollide = false
		end
		local mist = ctx.block("TidewallMistAnchor", V(w - 40, 1, 4), V(0, 62, -d / 2 + 12), face, Mat.SmoothPlastic, nil, 1)
		mist.CanCollide = false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "TidewallSpray"
		pe.Color = ColorSequence.new(rgb(236, 252, 250))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 18) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3, 5)
		pe.Rate = 10
		pe.Speed = NumberRange.new(2, 5)
		pe.SpreadAngle = Vector2.new(30, 10)
		pe.Parent = mist
	end)
	landmarks += 1

	---------------------------------------------------------------------------------------------------
	-- 6. The Votive Pool, the Tidepool Steps and the Upper Pools.
	---------------------------------------------------------------------------------------------------
	local votive = P.Votive
	local lampLights = 0
	local lamps = 0
	for _ = 1, 600 do
		if lamps >= 24 then break end
		local x, z = rng:NextNumber(votive.X - 70, votive.X + 120), rng:NextNumber(votive.Z - 60, votive.Z + 70)
		if field and field.Kind(x, z) == "POOL" and free(x, z, 1.6) then
			lamps += 1
			take(x, z, 1.6)
			local m = place("VotiveLamp", "VotiveLampBowl", x, z, rng:NextNumber(0, 360), rng:NextNumber(1.1, 1.5), NERETH, fbLamp, waterY - 0.3)
			pin(m)
			props += 1
			local flame = m and (m:FindFirstChild("CANDLE", true) or m:FindFirstChild("VotiveFlame", true))
			if flame and lampLights < 3 then
				lampLights += 1
				light(flame, LAMP_LIGHT, 0.9, 24)
			end
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = votive.X + sx * (votive.Width / 2 - 4), votive.Z + sz * (votive.Depth / 2 - 4)
			if free(x, z, 2.8) then
				take(x, z, 2.8)
				place("VotiveUrn", "StoneUrn", x, z, rng:NextNumber(0, 360), 0.8, NERETH, nil, votive.Y)
				props += 1
			end
		end
	end
	local function poolsOn(t: any, n: number, withKelp: boolean)
		local made = 0
		for _ = 1, n * 12 do
			if made >= n then break end
			local x = t.X + rng:NextNumber(-t.Width / 2 + 5, t.Width / 2 - 5)
			local z = t.Z + rng:NextNumber(-t.Depth / 2 + 5, t.Depth / 2 - 5)
			if free(x, z, 6.8) then
				take(x, z, 6.8)
				place("Rockpool", "TidepoolRockRing", x, z, rng:NextNumber(0, 360), 0.75, NERETH, fbTidepool, t.Y)
				made += 1
				props += 1
			end
		end
		if withKelp then
			for _ = 1, 3 do
				local x = t.X + rng:NextNumber(-t.Width / 2, t.Width / 2)
				local z = t.Z + rng:NextNumber(-t.Depth / 2, t.Depth / 2)
				if free(x, z, 3) then
					take(x, z, 3)
					place("AnemoneBed", "AnemoneCluster", x, z, rng:NextNumber(0, 360), 1.2, CORAL_AQUA, fbAnemone, t.Y)
					props += 1
				end
			end
		end
	end
	poolsOn(P.EastGallery, 3, true)
	poolsOn(P.UpperPools, 3, true)
	-- The Upper Pools spill seaward off their east lip in a thin fall.
	local up = P.UpperPools
	pinnedGroup("UpperPoolsFall", function()
		local top = V(up.X + up.Width / 2 + 2, up.Y - 0.6, up.Z + 8)
		local foot = V(up.X + up.Width / 2 + 14, waterY, up.Z + 14)
		local fall = ctx.beam("PoolFallRibbon", top, foot, 5, rgb(176, 240, 240), Mat.Glass, 0.35)
		fall.CanCollide = false
		local anchor = ctx.block("PoolFallMist", V(4, 1, 4), foot, rgb(220, 250, 250), Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide = false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "PoolFallSpray"
		pe.Color = ColorSequence.new(rgb(236, 252, 250))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(1.2, 2)
		pe.Rate = 14
		pe.Speed = NumberRange.new(3, 6)
		pe.SpreadAngle = Vector2.new(40, 40)
		pe.Parent = anchor
	end)

	-- Bubble columns rising from vents in the deep water under the Tidewall and in the barge's lagoon.
	for _, at in { V(40, waterY, -214), V(-196, waterY, -138) } do
		pinnedGroup("BubbleVent", function()
			local anchor = ctx.block("BubbleVentAnchor", V(3, 1, 3), at - V(0, 3, 0), rgb(200, 250, 250), Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "TideBubbles"
			pe.Color = ColorSequence.new(rgb(226, 252, 252))
			pe.Size = NumberSequence.new(0.6, 1.4)
			pe.Transparency = NumberSequence.new(0.3, 1)
			pe.Lifetime = NumberRange.new(1.5, 2.5)
			pe.Rate = 8
			pe.Speed = NumberRange.new(2, 4)
			pe.SpreadAngle = Vector2.new(12, 12)
			pe.Parent = anchor
		end)
	end

	---------------------------------------------------------------------------------------------------
	-- 7. Every terrace a vignette, both ends of every link dressed, and the living layers over the floor.
	---------------------------------------------------------------------------------------------------
	type Kind = { Name: string, Kit: string, S: { number }, R: number, Tints: { any }?, Fallback: (CFrame) -> (), Wet: boolean, Cap: number }
	local kinds: { Kind } = {
		{ Name = "CoralClump", Kit = "CoralCluster", S = { 1.2, 2.2 }, R = 5, Tints = CORAL_TINTS, Fallback = fbCoral(NERETH), Wet = true, Cap = 40 },
		{ Name = "SeaFan", Kit = "SeaFan", S = { 0.9, 1.5 }, R = 4, Tints = CORAL_TINTS, Fallback = fbFan, Wet = true, Cap = 38 },
		{ Name = "AnemoneBed", Kit = "AnemoneCluster", S = { 1, 1.6 }, R = 2.8, Tints = { NERETH, CORAL_AQUA, CORAL_WHITE }, Fallback = fbAnemone, Wet = true, Cap = 40 },
		{ Name = "GiantClam", Kit = "GiantClam", S = { 0.8, 1.4 }, R = 4.5, Tints = nil, Fallback = fbClam, Wet = true, Cap = 30 },
		{ Name = "KelpStand", Kit = "KelpStand", S = { 0.8, 1.3 }, R = 4, Tints = nil, Fallback = fbKelp, Wet = true, Cap = 38 },
		{ Name = "Boulders", Kit = "BoulderCluster", S = { 0.7, 1.3 }, R = 5, Tints = nil, Fallback = fbMidden, Wet = true, Cap = 36 },
		{ Name = "RuinRubble", Kit = "RuinRubble", S = { 0.7, 1.2 }, R = 4.5, Tints = nil, Fallback = fbBrokenColumn(NERETH), Wet = true, Cap = 34 },
		{ Name = "RuneTablet", Kit = "RuneTablet", S = { 0.8, 1.1 }, R = 3, Tints = nil, Fallback = fbTablet, Wet = false, Cap = 22 },
		{ Name = "BrokenColumn", Kit = "BrokenLancetColumn", S = { 0.6, 0.9 }, R = 8, Tints = nil, Fallback = fbBrokenColumn(NERETH), Wet = true, Cap = 24 },
		{ Name = "ShellHeap", Kit = "ShellMidden", S = { 0.4, 0.7 }, R = 4.5, Tints = nil, Fallback = fbMidden, Wet = false, Cap = 22 },
		{ Name = "Lectern", Kit = "CantorLectern", S = { 1, 1.2 }, R = 2.4, Tints = nil, Fallback = fbLectern, Wet = false, Cap = 12 },
		{ Name = "Urn", Kit = "StoneUrn", S = { 0.6, 0.9 }, R = 3, Tints = nil, Fallback = fbTablet, Wet = false, Cap = 16 },
		{ Name = "FallenArchCrown", Kit = "ArchCrown", S = { 0.5, 0.7 }, R = 9, Tints = nil, Fallback = fbBrokenColumn(NERETH), Wet = true, Cap = 8 },
	}
	local used: { [string]: number } = {}
	local function scatterOne(x: number, z: number, y: number?, wetOk: boolean): boolean
		local wet = field ~= nil and field.Kind(x, z) == "POOL"
		if wet and not wetOk then return false end
		if field and y == nil and field.Slope(x, z) > 0.9 then return false end
		for _ = 1, 4 do
			local k = kinds[rng:NextInteger(1, #kinds)]
			if (used[k.Name] or 0) < k.Cap and (k.Wet or not wet) then
				local s = rng:NextNumber(k.S[1], k.S[2])
				local r = k.R * s
				if free(x, z, r) then
					take(x, z, r)
					local tint = if k.Tints then k.Tints[rng:NextInteger(1, #k.Tints)] else NERETH
					local m = place(k.Name, k.Kit, x, z, rng:NextNumber(0, 360), s, tint, k.Fallback, y)
					if m then
						if k.Name ~= "BrokenColumn" and k.Name ~= "Boulders" then noCollide(m) end
						used[k.Name] = (used[k.Name] or 0) + 1
						props += 1
						return true
					end
				end
			end
		end
		return false
	end
	-- Terrace corners (decks and rocks alike), at the terrace's own height.
	for id, t in P do
		if id ~= "Sanctuary" and id ~= "Basin" then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					for _ = 1, 3 do
						scatterOne(t.X + sx * (t.Width / 2 - rng:NextNumber(4, 10)), t.Z + sz * (t.Depth / 2 - rng:NextNumber(4, 10)), t.Y, false)
					end
				end
			end
		end
	end
	-- The Tide-Flat's beach, its west and east ends (the camps' middles stay clear).
	for _ = 1, 40 do
		scatterOne(rng:NextNumber(-w / 2 + 16, w / 2 - 16), rng:NextNumber(P.Basin.Z - 40, P.Basin.Z + 44), P.Basin.Y, false)
	end
	-- Both ends of every link, off the lane.
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		for _, e in { { link.AX, link.AZ }, { link.BX, link.BZ } } do
			for _, side in { -1, 1 } do
				scatterOne(e[1] + nx * side * 24, e[2] + nz * side * 24, nil, true)
			end
		end
	end
	-- The shallows, sandbars and shore: coral, kelp, clams and ruins over open ground and the seabed.
	for _ = 1, 1400 do
		if props >= 380 then break end
		scatterOne(rng:NextNumber(-w / 2 + 14, w / 2 - 14), rng:NextNumber(-d / 2 + 24, d / 2 - 50), nil, true)
	end

	-- Ground cover: seagrass and shell litter, cheap and never solid, in the shallows and on the sand.
	for _ = 1, 1600 do
		if cover >= 300 then break end
		local x, z = rng:NextNumber(-w / 2 + 12, w / 2 - 12), rng:NextNumber(-d / 2 + 16, d / 2 - 16)
		local _, onDeck = H.surfaceAt(x, z)
		if not onDeck and (not field or field.Slope(x, z) < 0.8) then
			local r = 1.8
			local okCamp = true
			for _, camp in layout.Camps do
				if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < 38 ^ 2 then okCamp = false break end
			end
			if okCamp and ctx.footprintClear(x, z, r, r) then
				local m = place("GroundCover", "SeagrassTuft", x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.6), NERETH, fbSeagrass)
				noCollide(m)
				cover += 1
			end
		end
	end

	-- The noon sun's bounce off the shallows: two broad, faint aqua fills over the tide-flat.
	pinnedGroup("ShallowsBounce", function()
		for _, at in { V(-120, 10, 40), V(120, 10, -60) } do
			local anchor = ctx.block("ShallowsBounceAnchor", V(1, 1, 1), at, AQUA_LIGHT, Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			light(anchor, AQUA_LIGHT, 0.5, 90)
		end
	end)

	local distinct = 0
	for _ in kindsUsed do distinct += 1 end
	ctx.setAttribute("SetPieceLandmarks", landmarks)
	ctx.setAttribute("SetPieceProps", props)
	ctx.setAttribute("SetPieceGroundCover", cover)
	ctx.setAttribute("SetPieceTemplates", distinct)
end

return SunkenSanctuary
