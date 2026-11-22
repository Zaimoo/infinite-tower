--!strict
-- Hand-authored set pieces for Corrupted Grove Floor 32: Twisted Orchard (corrupted:2).
-- Guide image: reference/Corrupted Grove 32.jpg. Design: docs/prompts/corrupted-grove-floor-layouts-prompt.md.
--
-- The Hollin's grafting orchard climbing a south-facing terraced slope to the E-W Graft Ridge (Crookback Ridge
-- Y 40, The Grafted Crown Y 48, Thorn Saddle Y 44) and descending behind the crest into the hidden Pressing
-- Hollow (Apex Y 36), where the colossal domed Great Cider Press draws the orchard's rot.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local CorruptedFloor32 = {}

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

-- Overripe rose-dusk orchard palette: warm weathered timber, mossy fieldstone, rose-stained linen Pale Bands,
-- warm golden-amber leaves, soft rose-pink blossoms, bruised plum fruit, and vivid magenta rot-glow (hue ~305°,
-- never crimson/red so enemy telegraphs stay unmistakable).
local ORCHARD = table.freeze({
	WOOD = swatch(82, 58, 52, Mat.Wood), -- gnarled orchard bark and weathered oak
	TRIM = swatch(186, 152, 110, Mat.Wood), -- pale cut timber, crutch poles, ladders, screw threads
	ALT = swatch(198, 146, 72, Mat.Fabric), -- woven wicker skeps, baskets, terracotta pots, golden straw
	FOLIAGE = swatch(196, 134, 58, Mat.Grass), -- warm autumn-gold orchard foliage
	CORAL = swatch(238, 152, 178, Mat.Grass), -- overripe rose-pink orchard blossoms & ripe apples
	CAP = swatch(134, 42, 108, Mat.SmoothPlastic), -- bruised plum-violet foliage & overripe fruit pulp
	ACCENT = swatch(242, 232, 236, Mat.Grass), -- pale white blossoms
	MOSS = swatch(102, 92, 58, Mat.Grass), -- olive orchard moss
	SILK = swatch(224, 186, 198, Mat.Fabric), -- Pale Bands stained faint pink at the knot
	STONE = swatch(112, 100, 92, Mat.Slate), -- mossy fieldstone walls & footings
	METAL = swatch(66, 56, 62, Mat.Metal), -- forged vat & press hoops
	GLOW = swatch(238, 86, 212, Mat.Neon), -- magenta rot-fruit & oozing cider must (hue ~308°)
	CANDLE = swatch(255, 196, 120, Mat.Neon), -- warm hearth/lantern/hive flame
	STEM = swatch(64, 44, 54, Mat.Wood),
})

-- The Grafted Crown's five-species palette: pink blossom (CORAL), golden autumn (ALT), olive fruiting (FOLIAGE),
-- deep plum-berry (CAP), pale white blossom (ACCENT), and stained linen Pale Bands (SILK).
local CROWN_TINT = tinted(ORCHARD, {
	WOOD = swatch(74, 50, 48, Mat.Wood),
	CORAL = swatch(244, 156, 188, Mat.Grass),
	ALT = swatch(224, 154, 52, Mat.Grass),
	FOLIAGE = swatch(114, 136, 58, Mat.Grass),
	CAP = swatch(138, 38, 92, Mat.Grass),
	ACCENT = swatch(240, 234, 238, Mat.Grass),
	SILK = swatch(228, 210, 206, Mat.Fabric),
	GLOW = swatch(242, 88, 218, Mat.Neon),
})

-- Blossoming pink-and-gold orchard variant (for south/mid orchard rows and pleached arches).
local BLOSSOM = tinted(ORCHARD, {
	FOLIAGE = swatch(172, 138, 66, Mat.Grass),
	CORAL = swatch(246, 162, 190, Mat.Grass),
})

-- Deeper dusk-plum variant for upper rows near the ridge, Thorn Saddle, and the Pressing Hollow.
local ROTTEN = tinted(ORCHARD, {
	WOOD = swatch(52, 36, 46, Mat.Wood),
	FOLIAGE = swatch(124, 52, 98, Mat.Grass),
	CORAL = swatch(198, 92, 156, Mat.Grass),
	CAP = swatch(118, 34, 102, Mat.SmoothPlastic),
	MOSS = swatch(76, 46, 68, Mat.Grass),
	SILK = swatch(210, 152, 182, Mat.Fabric),
	STONE = swatch(88, 76, 82, Mat.Slate),
})

local LAMP_TINT = tinted(ORCHARD, {
	GLOW = swatch(255, 184, 108, Mat.Neon),
})

local SKEP_TINT = tinted(ORCHARD, {
	ALT = swatch(206, 158, 78, Mat.Fabric),
	TRIM = swatch(154, 114, 58, Mat.Wood),
	GLOW = swatch(255, 178, 96, Mat.Neon),
	CANDLE = swatch(255, 224, 156, Mat.Neon),
})

local BENCH_TINT = tinted(ORCHARD, {
	ALT = swatch(174, 96, 64, Mat.SmoothPlastic), -- terracotta clay rootstock pots
	GLOW = swatch(255, 174, 88, Mat.Neon), -- warm bubbling grafting wax
})

local BLOOM = tinted(ORCHARD, {
	STEM = swatch(54, 32, 50, Mat.SmoothPlastic),
	CAP = swatch(214, 78, 186, Mat.SmoothPlastic),
	GLOW = swatch(248, 110, 224, Mat.Neon),
})

local ROT_LIGHT = rgb(236, 88, 212)
local LAMP_LIGHT = rgb(255, 182, 108)

-- Floor 32's landmark footprints (local floor space, scaled), checked offline by the specs against every
-- walkway lane, camp (34-stud clearance) and portal spot, and reserved so clutter passes keep off them.
CorruptedFloor32.Landmarks = table.freeze({
	{ Id = "GreatCiderPress", X = -108, Z = -280, Y = 40, HalfX = 25.0, HalfZ = 27.0, Top = 130.5 },
	{ Id = "PressHouseRoof", X = -108, Z = -280, Y = 40, HalfX = 33.1, HalfZ = 32.2, Top = 54.4 },
	{ Id = "GraftedCrownTree", X = 72, Z = -164, Y = 48, HalfX = 40.4, HalfZ = 18.4, Top = 61.0 },
	{ Id = "WindfallPileMain", X = -110, Z = 10, Y = 6, HalfX = 8.5, HalfZ = 7.3, Top = 5.6 },
	{ Id = "WindfallPileSide", X = -92, Z = 4, Y = 6, HalfX = 6.8, HalfZ = 5.8, Top = 4.5 },
	{ Id = "WindfallArbor", X = -112, Z = -12, Y = 6, HalfX = 8.2, HalfZ = 7.2, Top = 8.9 },
	{ Id = "GraftersBenchWest", X = -50, Z = 40, Y = 16, HalfX = 5.5, HalfZ = 7.4, Top = 7.8 },
	{ Id = "GraftersBenchEast", X = 50, Z = 40, Y = 16, HalfX = 5.5, HalfZ = 7.4, Top = 7.8 },
	{ Id = "GraftersShedEast", X = 58, Z = 58, Y = 16, HalfX = 8.2, HalfZ = 7.2, Top = 8.9 },
	{ Id = "WestEspalierMain", X = -214, Z = -68, Y = 24, HalfX = 5.0, HalfZ = 14.8, Top = 13.9 },
	{ Id = "WestEspalierNorth", X = -208, Z = -104, Y = 24, HalfX = 9.5, HalfZ = 12.5, Top = 13.9 },
	{ Id = "SkepBenchMain", X = 115, Z = -76, Y = 28, HalfX = 3.2, HalfZ = 10.8, Top = 9.6 },
	{ Id = "SkepBenchNorth", X = 114, Z = -106, Y = 28, HalfX = 3.2, HalfZ = 10.8, Top = 9.6 },
	{ Id = "CiderVatMain", X = 264, Z = -110, Y = 20, HalfX = 12.0, HalfZ = 12.8, Top = 10.6 },
	{ Id = "CooperageShed", X = 248, Z = -132, Y = 20, HalfX = 8.2, HalfZ = 7.2, Top = 8.9 },
	{ Id = "CrookbackPear", X = -174, Z = -182, Y = 40, HalfX = 15.2, HalfZ = 8.8, Top = 26.3 },
	{ Id = "CrookbackBench", X = -156, Z = -176, Y = 40, HalfX = 5.2, HalfZ = 2.6, Top = 5.2 },
	{ Id = "ThornSaddleArchEast", X = 180, Z = -186, Y = 44, HalfX = 8.5, HalfZ = 18.0, Top = 25.4 },
	{ Id = "ThornSaddleArchNorth", X = 162, Z = -220, Y = 44, HalfX = 18.2, HalfZ = 6.5, Top = 25.4 },
	{ Id = "FelledRowLog", X = 266, Z = -18, HalfX = 6.6, HalfZ = 25.0, Top = 11.6 },
}) :: { Landmark }

function CorruptedFloor32.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number, P = H.field, H.bottom, H.d, H.P
	local w: number = ctx.w
	local layout = ctx.layout
	local surfaceAt, boxAt, lump, light, piece, noCollide, plume =
		H.surfaceAt, H.boxAt, H.lump, H.light, H.piece, H.noCollide, H.plume
	local origin: Vector3 = ctx.origin
	local waterY = if field then field.LiquidLevel else bottom

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

	local landmarks, props, cover = 0, 0, 0
	local lightsUsed = 0
	local rng = Random.new(32 * 7919)

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 18 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end

	for _, lm in CorruptedFloor32.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	local taken: { { number } } = {}
	for _, lm in CorruptedFloor32.Landmarks do
		table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
	end
	local function free(x: number, z: number, r: number): boolean
		if math.abs(x) > w / 2 - 12 or math.abs(z) > d / 2 - 12 then return false end
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
	local function dry(x: number, z: number): boolean
		return not field or (field.Kind(x, z) ~= "POOL" and field.Slope(x, z) < 0.85)
	end
	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end
	local function level(x: number, z: number, r: number, tol: number): boolean
		if not field then return true end
		local lo, hi = math.huge, -math.huge
		for _, o in { { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } } do
			local y = field.Height(x + o[1], z + o[2])
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
		return hi - lo <= tol
	end

	---------------------------------------------------------------------------------------------------
	-- Part-built fallbacks (used automatically until CorruptedF32Kit.fbx is imported into Studio).
	---------------------------------------------------------------------------------------------------
	local function fallbackOrchardTree(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local wc, wm = sw(tint, "WOOD")
			local fc, fm = sw(tint, "FOLIAGE")
			local cc, cm = sw(tint, "CORAL")
			local sc, sm = sw(tint, "SILK")
			local gc, gm = sw(tint, "GLOW")
			rod("OrchardTrunk", (cf * CFrame.new(0, -0.5, 0)).Position, (cf * CFrame.new(1.2, 15, 0.3)).Position, 1.9, wc, wm)
			ctx.cyl("PaleBand", (cf * CFrame.new(0.6, 6.5, 0.1)).Position, 2.1, 1.3, sc, sm)
			for k = 0, 3 do
				local a = k * math.pi / 2 + 0.3
				local tip = cf * CFrame.new(math.cos(a) * 8.5, 19, math.sin(a) * 8.5)
				rod("OrchardBough", (cf * CFrame.new(0.8, 12, 0)).Position, tip.Position, 0.7, wc, wm)
				lump("OrchardCrown", (tip * CFrame.new(0, 2, 0)).Position, V(11, 7, 10), if k % 2 == 0 then cc else fc, if k % 2 == 0 then cm else fm)
				lump("RotFruit", (tip * CFrame.new(0, -2.2, 0)).Position, V(1.3, 1.5, 1.3), gc, gm)
			end
		end
	end

	local function fallbackPleachedArch(cf: CFrame)
		local wc, wm = sw(BLOSSOM, "WOOD")
		local cc, cm = sw(BLOSSOM, "CORAL")
		local sc, sm = sw(BLOSSOM, "STONE")
		local gc, gm = sw(BLOSSOM, "GLOW")
		for _, s in { -1, 1 } do
			boxAt("ArchFoot", V(5, 4.4, 5), cf * CFrame.new(s * 21.5, 2.2, 0), sc, sm)
			rod("ArchPier", (cf * CFrame.new(s * 21.5, 1, 0)).Position, (cf * CFrame.new(s * 21.5, 20, 0)).Position, 1.2, wc, wm)
		end
		for k = 0, 7 do
			local u0, u1 = -1 + k / 4, -1 + (k + 1) / 4
			local p0 = (cf * CFrame.new(u0 * 21.5, 19.5 + 9.2 * (1 - u0 * u0), 0)).Position
			local p1 = (cf * CFrame.new(u1 * 21.5, 19.5 + 9.2 * (1 - u1 * u1), 0)).Position
			rod("ArchRib", p0, p1, 0.95, wc, wm)
			lump("ArchBlossom", (p0 + p1) / 2 + V(0, 2, 0), V(8.5, 5, 7), cc, cm)
			if k >= 2 and k <= 5 then
				lump("ArchFruit", (p0 + p1) / 2 + V(0, -2.2, 0), V(1.3, 1.5, 1.3), gc, gm)
			end
		end
	end

	local LANTERN_DROP = 5.2
	local function lantern(kind: string, x: number, hookY: number, z: number, withLight: boolean)
		local made = piece(kind, x, z, rng:NextNumber(0, 360), "HangingLantern", 1, LAMP_TINT, function(cf)
			local gc, gm = sw(LAMP_TINT, "GLOW")
			local wc, wm = sw(LAMP_TINT, "WOOD")
			boxAt("LanternCord", V(0.15, 1.6, 0.15), cf * CFrame.new(0, LANTERN_DROP - 0.8, 0), wc, wm)
			local glass = boxAt("LanternGlass", V(1.8, 2.4, 1.8), cf * CFrame.new(0, LANTERN_DROP - 3.8, 0), gc, gm)
			if withLight then addLight(glass, LAMP_LIGHT, 1.1, 28) end
		end, hookY - LANTERN_DROP)
		if withLight and made and ctx.has("HangingLantern") then
			addLight(H.glowOf(made), LAMP_LIGHT, 1.1, 28)
		end
		noCollide(made)
	end

	---------------------------------------------------------------------------------------------------
	-- 1. The Great Cider Press & Press-House Roof (Pressing Hollow back-west rim, ~130.5 studs tall)
	--    plus the tall dark press-house smoke plume rising above the Graft Ridge (visible from arrival!).
	---------------------------------------------------------------------------------------------------
	do
		local press = CorruptedFloor32.Landmarks[1]
		local roof = CorruptedFloor32.Landmarks[2]
		local baseY = press.Y :: number
		local madePress = piece("GreatCiderPress", press.X, press.Z, 28, "GreatCiderPress", 1.2, ORCHARD, function(cf)
			local sc, sm = sw(ORCHARD, "STONE")
			local wc, wm = sw(ORCHARD, "WOOD")
			local tc, tm = sw(ORCHARD, "TRIM")
			local gc, gm = sw(ORCHARD, "GLOW")
			ctx.cyl("PressBase", (cf * CFrame.new(0, 3, 0)).Position, 20, 6, sc, sm)
			ctx.cyl("PressTub", (cf * CFrame.new(0, 14, 0)).Position, 16, 18, wc, wm)
			boxAt("PressBeam", V(40, 6, 11), cf * CFrame.new(0, 52, 0), wc, wm)
			ctx.cyl("PressScrew", (cf * CFrame.new(0, 74, 0)).Position, 4, 112, tc, tm)
			local must = lump("PressMust", (cf * CFrame.new(0, 4, 22)).Position, V(10, 4, 10), gc, gm)
			addLight(must, ROT_LIGHT, 1.8, 65)
		end, baseY)
		pin(madePress)
		if madePress and ctx.has("GreatCiderPress") then
			addLight(H.glowOf(madePress), ROT_LIGHT, 1.8, 65)
		end

		local madeRoof = piece("PressHouseRoof", roof.X, roof.Z, 28, "PressHouseRoof", 1.05, ORCHARD, function(cf)
			local wc, wm = sw(ORCHARD, "WOOD")
			local ac, am = sw(ORCHARD, "ALT")
			for k = 0, 7 do
				local a = k * math.pi / 4
				rod("PressRib", (cf * CFrame.new(math.cos(a) * 30, 0, math.sin(a) * 30)).Position, (cf * CFrame.new(math.cos(a) * 7, 50, math.sin(a) * 7)).Position, 1.6, wc, wm)
			end
			ctx.cyl("PressFlueCollar", (cf * CFrame.new(0, 50, 0)).Position, 8, 5, ac, am)
		end, baseY)
		pin(madeRoof)

		-- Press-house smoke rising high from the willow dome's flue collar above the ridge crest.
		ctx.group("PressHouseSmoke", function()
			plume(V(press.X, baseY + 56, press.Z), rgb(118, 86, 104), 14, 7, 15, 7.5)
		end)
		landmarks += 3
	end

	---------------------------------------------------------------------------------------------------
	-- 2. The Grafted Crown: colossal five-species grafted tree standing on the Graft Ridge crest,
	--    reaching Y ~112 as the floor's unmistakable beacon from the arrival.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor32.Landmarks[3]
		local gy = surfaceAt(lm.X, lm.Z)
		local y = math.max(lm.Y :: number, gy - 4.0)
		local made = piece("GraftedCrownTree", lm.X, lm.Z, 8, "GraftedCrownTree", 1.0, CROWN_TINT, function(cf)
			local wc, wm = sw(CROWN_TINT, "WOOD")
			local gc, gm = sw(CROWN_TINT, "GLOW")
			rod("CrownTrunk", (cf * CFrame.new(0, -1, 0)).Position, (cf * CFrame.new(0, 23, 0)).Position, 5.5, wc, wm)
			local limbs = {
				{ -26, 35, -2, CROWN_TINT.CORAL },
				{ -16, 46, 2, CROWN_TINT.ALT },
				{ 1, 50, 0, CROWN_TINT.FOLIAGE },
				{ 18, 45, 2, CROWN_TINT.CAP },
				{ 22, 29, -3, CROWN_TINT.ACCENT },
			}
			for _, l in limbs do
				rod("CrownLimb", (cf * CFrame.new(0, 21, 0)).Position, (cf * CFrame.new(l[1], l[2], l[3])).Position, 2.0, wc, wm)
				lump("CrownCanopy", (cf * CFrame.new(l[1], l[2] + 3, l[3])).Position, V(18, 12, 16), l[4].Color, l[4].Material)
			end
			rod("CrownDeadLimb", (cf * CFrame.new(2, 20, 0)).Position, (cf * CFrame.new(33, 37, 1)).Position, 1.5, wc, wm)
			local seam = lump("CrownGraftGlow", (cf * CFrame.new(0, 18, 4.5)).Position, V(4, 7, 3), gc, gm)
			addLight(seam, ROT_LIGHT, 1.5, 55)
		end, y)
		pin(made)
		if made and ctx.has("GraftedCrownTree") then
			addLight(H.glowOf(made), ROT_LIGHT, 1.5, 55)
		end
		-- Drifting blossom petals & spores from the Grafted Crown.
		ctx.group("CrownBlossomDrift", function()
			plume(V(lm.X, y + 36, lm.Z), rgb(246, 168, 198), 4.5, 5, 5, 5.0)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 3. The Orchard Gate (Sanctuary exit, tagged HollinStile) + wattle fences + lantern.
	---------------------------------------------------------------------------------------------------
	do
		local safe = P.Sanctuary
		local z = safe.Z - safe.Depth / 2 + 3
		local gate = piece("HollinStile", 0, z, 0, "PleachedArch", 1.0, BLOSSOM, fallbackPleachedArch, safe.Y)
		pin(gate)
		noCollide(gate)
		lantern("OrchardGateLantern", 23.5, safe.Y + 15.5, z - 2.0, true)
		lantern("OrchardGateLantern", -23.5, safe.Y + 15.5, z - 2.0, false)
		for _, x in { -56, -42, -30, 30, 42, 56 } do
			local f = piece("OrchardGateFence", x, z, 0, "WattleFence", 1.0, ORCHARD, function(cf)
				local wc, wm = sw(ORCHARD, "WOOD")
				boxAt("WattlePanel", V(14, 4.4, 0.6), cf * CFrame.new(0, 2.2, 0), wc, wm)
			end, safe.Y)
			pin(f)
			props += 1
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 4. The Grafters' Stair (Crossing -> GraftedCrown): a living flowering tunnel of four chained
	--    PleachedArches climbing the stairs (40-stud inner span, 22+ clear overhead, tagged RampArch).
	---------------------------------------------------------------------------------------------------
	do
		for idx, frac in { 0.16, 0.40, 0.64, 0.86 } do
			local z = 12 + (-109 - 12) * frac
			local y = 16 + (48 - 16) * frac
			local arch = piece("RampArch", 0, z, if idx % 2 == 0 then 180 else 0, "PleachedArch", 1.0, BLOSSOM, fallbackPleachedArch, y)
			pin(arch)
			noCollide(arch)
			if idx == 2 or idx == 4 then
				addLight(H.glowOf(arch), ROT_LIGHT, 1.1, 36)
			end
			props += 1
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 5. Windfall Hollow (slatted drying deck at -100, 6, 20): heaped rotting fruit, arbor lean-to,
	--    dripping magenta must puddles off the deck rim.
	---------------------------------------------------------------------------------------------------
	do
		local p1, p2, arbor = CorruptedFloor32.Landmarks[4], CorruptedFloor32.Landmarks[5], CorruptedFloor32.Landmarks[6]
		local m1 = piece("WindfallPileMain", p1.X, p1.Z, 20, "FruitBasketPile", 1.25, ORCHARD, function(cf)
			local cc, cm = sw(ORCHARD, "CAP")
			local gc, gm = sw(ORCHARD, "GLOW")
			lump("WindfallHeap", (cf * CFrame.new(0, 2, 0)).Position, V(12, 4.5, 10), cc, cm)
			local glow = lump("WindfallGlow", (cf * CFrame.new(1, 3.8, 0)).Position, V(3, 1.6, 3), gc, gm)
			addLight(glow, ROT_LIGHT, 1.0, 28)
		end, p1.Y)
		pin(m1)
		noCollide(m1)
		if m1 and ctx.has("FruitBasketPile") then
			addLight(H.glowOf(m1), ROT_LIGHT, 1.0, 28)
		end

		local m2 = piece("WindfallPileSide", p2.X, p2.Z, -35, "FruitBasketPile", 1.0, BLOSSOM, function(cf)
			local cc, cm = sw(BLOSSOM, "CORAL")
			lump("WindfallHeap", (cf * CFrame.new(0, 1.8, 0)).Position, V(9, 3.6, 8), cc, cm)
		end, p2.Y)
		pin(m2)
		noCollide(m2)

		local ma = piece("WindfallArbor", arbor.X, arbor.Z, 180, "WardensLeanTo", 1.0, ORCHARD, function(cf)
			local wc, wm = sw(ORCHARD, "WOOD")
			local ac, am = sw(ORCHARD, "ALT")
			boxAt("ArborRoof", V(16, 1, 10), cf * CFrame.new(0, 6.5, 0) * CFrame.Angles(0.35, 0, 0), ac, am)
			for _, x in { -7, 7 } do
				boxAt("ArborPost", V(0.8, 8.5, 0.8), cf * CFrame.new(x, 4.2, -4), wc, wm)
			end
		end, arbor.Y)
		pin(ma)
		-- Timber stilt posts supporting the Windfall Hollow slatted drying deck down into the slope.
		ctx.group("WindfallDeckStilts", function()
			local wc, wm = sw(ORCHARD, "WOOD")
			local wf = P.Windfall
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local px, pz = wf.X + sx * (wf.Width / 2 - 3), wf.Z + sz * (wf.Depth / 2 - 3)
					local gy = if field then field.Height(px, pz) - 1 else bottom
					if wf.Y - gy > 1.5 then
						local post = rod("WindfallStilt", V(px, gy, pz), V(px, wf.Y - 0.5, pz), 1.1, wc, wm)
						noCollide(post)
					end
				end
			end
		end)
		-- Glowing must seepage dripping off the windfall deck edge.
		ctx.group("WindfallMustSeep", function()
			local s = lump("MustPool", V(-124, surfaceAt(-124, 24) + 0.15, 24), V(9, 0.4, 7), rgb(212, 68, 188), Mat.SmoothPlastic)
			s.Transparency = 0.18
			noCollide(s)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 6. Grafters' Yard (Crossing at 0, 16, 40): flanking grafting benches with clay rootstock pots
	--    and bubbling wax cauldrons, tool shed, wattle enclosure fences, warm lanterns (off 34-stud camp).
	---------------------------------------------------------------------------------------------------
	do
		local bw, be, shed = CorruptedFloor32.Landmarks[7], CorruptedFloor32.Landmarks[8], CorruptedFloor32.Landmarks[9]
		local function placeBench(id: string, lm: Landmark, yaw: number, withLight: boolean)
			local m = piece(id, lm.X, lm.Z, yaw, "GraftingBench", 1.0, BENCH_TINT, function(cf)
				local wc, wm = sw(BENCH_TINT, "WOOD")
				local gc, gm = sw(BENCH_TINT, "GLOW")
				boxAt("BenchTop", V(10.5, 0.7, 4.2), cf * CFrame.new(-1, 3.5, 0), wc, wm)
				local wax = lump("WaxCauldron", (cf * CFrame.new(6, 2.5, 0)).Position, V(2.8, 2.4, 2.8), gc, gm)
				if withLight then addLight(wax, LAMP_LIGHT, 1.1, 30) end
			end, lm.Y)
			pin(m)
			if withLight and m and ctx.has("GraftingBench") then
				addLight(H.glowOf(m), LAMP_LIGHT, 1.1, 30)
			end
		end
		placeBench("GraftersBenchWest", bw, 90, true)
		placeBench("GraftersBenchEast", be, -90, true)

		local ms = piece("GraftersShedEast", shed.X, shed.Z, -135, "WardensLeanTo", 1.0, ORCHARD, function(cf)
			local wc, wm = sw(ORCHARD, "WOOD")
			local ac, am = sw(ORCHARD, "ALT")
			boxAt("ShedRoof", V(16, 1, 10), cf * CFrame.new(0, 6.5, 0) * CFrame.Angles(0.35, 0, 0), ac, am)
			boxAt("ShedPost", V(0.8, 8, 0.8), cf * CFrame.new(0, 4, -4), wc, wm)
		end, shed.Y)
		pin(ms)

		lantern("YardLantern", bw.X + 4, (bw.Y :: number) + 9.2, bw.Z + 8, false)
		lantern("YardLantern", be.X - 4, (be.Y :: number) + 9.2, be.Z + 8, false)

		for _, f in { { -46, 20, 80 }, { -46, 58, 100 }, { 46, 20, -80 }, { 46, 58, -100 } } do
			if free(f[1], f[2], 7) then
				take(f[1], f[2], 7)
				piece("YardWattleFence", f[1], f[2], f[3], "WattleFence", 1.0, ORCHARD, function(cf)
					local wc, wm = sw(ORCHARD, "WOOD")
					boxAt("WattlePanel", V(14, 4.4, 0.6), cf * CFrame.new(0, 2.2, 0), wc, wm)
				end)
				props += 1
			end
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 7. West Espalier (-170, 24, -70): mossy fieldstone garden walls with fan-trained fruit trees,
	--    half twisting off the stone with magenta rot, plus an orchard ladder beside them.
	---------------------------------------------------------------------------------------------------
	do
		local e1, e2 = CorruptedFloor32.Landmarks[10], CorruptedFloor32.Landmarks[11]
		local function placeEspalier(id: string, lm: Landmark, yaw: number, withLight: boolean)
			local m = piece(id, lm.X, lm.Z, yaw, "EspalierWall", 1.0, BLOSSOM, function(cf)
				local sc, sm = sw(BLOSSOM, "STONE")
				local cc, cm = sw(BLOSSOM, "CORAL")
				boxAt("EspalierStone", V(26.5, 12, 3), cf * CFrame.new(0, 6, 0), sc, sm)
				lump("EspalierCrown", (cf * CFrame.new(0, 9, 2.5)).Position, V(18, 6, 4), cc, cm)
			end, lm.Y)
			pin(m)
			if withLight and m and ctx.has("EspalierWall") then
				addLight(H.glowOf(m), ROT_LIGHT, 0.95, 28)
			end
		end
		placeEspalier("WestEspalierMain", e1, 90, false)
		placeEspalier("WestEspalierNorth", e2, 50, false)
		if free(-202, -54, 4) then
			take(-202, -54, 4)
			local lad = piece("EspalierLadder", -202, -54, 75, "CrutchPoleProp", 1.0, ORCHARD, function(cf)
				local tc, tm = sw(ORCHARD, "TRIM")
				boxAt("Ladder", V(2, 10, 0.5), cf * CFrame.new(0, 5, 0), tc, tm)
			end, 24)
			pin(lad)
			noCollide(lad)
			props += 1
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 8. Skep Terrace (EastEspalier at 150, 28, -80): benches of woven wicker bee-skeps, most dead,
	--    two humming warmly beneath a glowing magenta-amber swarm.
	---------------------------------------------------------------------------------------------------
	do
		local s1, s2 = CorruptedFloor32.Landmarks[12], CorruptedFloor32.Landmarks[13]
		local function placeSkeps(id: string, lm: Landmark, yaw: number, withSwarm: boolean)
			local m = piece(id, lm.X, lm.Z, yaw, "BeeSkepBench", 1.0, SKEP_TINT, function(cf)
				local wc, wm = sw(SKEP_TINT, "WOOD")
				local ac, am = sw(SKEP_TINT, "ALT")
				local gc, gm = sw(SKEP_TINT, "GLOW")
				boxAt("SkepBench", V(21.5, 0.9, 4.6), cf * CFrame.new(0, 3.1, 0), wc, wm)
				for k = -2, 2 do
					local skep = lump("BeeSkep", (cf * CFrame.new(k * 3.8, 5.4, 0)).Position, V(3.3, 3.8, 3.3), ac, am)
					if k == 0 or k == 1 then
						local g = lump("SkepGlow", (cf * CFrame.new(k * 3.8, 4.4, 1.7)).Position, V(1.1, 1.1, 0.5), gc, gm)
						if withSwarm and k == 0 then addLight(g, LAMP_LIGHT, 1.0, 28) end
					end
					noCollide(skep)
				end
			end, lm.Y)
			pin(m)
			if withSwarm and m and ctx.has("BeeSkepBench") then
				addLight(H.glowOf(m), LAMP_LIGHT, 1.0, 28)
			end
			if withSwarm then
				ctx.group(id .. "Swarm", function()
					plume(V(lm.X, (lm.Y :: number) + 6.5, lm.Z), rgb(246, 134, 214), 1.4, 10, 2.5, 2.4)
				end)
			end
		end
		placeSkeps("SkepBenchMain", s1, 90, true)
		placeSkeps("SkepBenchNorth", s2, 90, true)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 9. Cider Vats (250, 20, -110): cooperage shed, split oak cider vat pouring glowing magenta must
	--    down the eastern slope, barrels and a warm cooperage lantern.
	---------------------------------------------------------------------------------------------------
	do
		local vat, shed = CorruptedFloor32.Landmarks[14], CorruptedFloor32.Landmarks[15]
		local mv = piece("CiderVatMain", vat.X, vat.Z, -25, "CiderVatSplit", 1.1, ORCHARD, function(cf)
			local wc, wm = sw(ORCHARD, "WOOD")
			local gc, gm = sw(ORCHARD, "GLOW")
			ctx.cyl("VatBody", (cf * CFrame.new(0, 4.6, 0)).Position, 6.8, 9.2, wc, wm)
			local spill = lump("VatMustSpill", (cf * CFrame.new(0, 1.2, 9.5)).Position, V(9, 1.2, 9), gc, gm)
			addLight(spill, ROT_LIGHT, 1.3, 38)
		end, vat.Y)
		pin(mv)
		if mv and ctx.has("CiderVatSplit") then
			addLight(H.glowOf(mv), ROT_LIGHT, 1.3, 38)
		end

		local ms = piece("CooperageShed", shed.X, shed.Z, 0, "WardensLeanTo", 1.0, ORCHARD, function(cf)
			local wc, wm = sw(ORCHARD, "WOOD")
			local ac, am = sw(ORCHARD, "ALT")
			boxAt("CooperRoof", V(16, 1, 10), cf * CFrame.new(0, 6.5, 0) * CFrame.Angles(0.35, 0, 0), ac, am)
			boxAt("CooperPost", V(0.8, 8.2, 0.8), cf * CFrame.new(-7, 4.1, -4), wc, wm)
		end, shed.Y)
		pin(ms)
		lantern("VatsLantern", shed.X - 6, (shed.Y :: number) + 8.6, shed.Z + 5, true)

		-- Magenta cider-must trickle running down the eastern slope below the burst vat.
		ctx.group("CiderVatMustRun", function()
			for k = 0, 5 do
				local rx = vat.X + 4 + k * 2.2
				local rz = vat.Z + 18 + k * 8.5
				local ry = surfaceAt(rx, rz)
				local p = lump("VatMustStream", V(rx, ry + 0.15, rz), V(5.5 - k * 0.4, 0.45, 7.5), rgb(228, 76, 206), Mat.SmoothPlastic)
				p.Transparency = 0.18
				noCollide(p)
			end
			plume(V(vat.X, (vat.Y :: number) + 6, vat.Z), rgb(236, 110, 214), 3.0, 5, 3.2, 3.0)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 10. Crookback Ridge (-130, 40, -175): the hunched pear tree bent double by its own graft over
	--     the Hollin wooden bench looking back south across the orchard, plus ridge-walk wattle fences.
	---------------------------------------------------------------------------------------------------
	do
		local pear, bench = CorruptedFloor32.Landmarks[16], CorruptedFloor32.Landmarks[17]
		local mp = piece("CrookbackPear", pear.X, pear.Z, -18, "GraftedFruitTreeC", 1.15, BLOSSOM, fallbackOrchardTree(BLOSSOM), pear.Y)
		pin(mp)
		local mb = piece("CrookbackBench", bench.X, bench.Z, 12, "HollinBench", 1.0, ORCHARD, function(cf)
			local wc, wm = sw(ORCHARD, "WOOD")
			boxAt("HollinBenchSeat", V(9.4, 0.6, 2.8), cf * CFrame.new(0, 2.2, 0), wc, wm)
			boxAt("HollinBenchBack", V(9.2, 2.2, 0.5), cf * CFrame.new(0, 3.8, -1.4), wc, wm)
		end, bench.Y)
		pin(mb)
		-- Ridge-walk wattle fence guarding the south edge between Crookback Ridge and the Grafted Crown.
		for _, f in { { -116, -148, 12 }, { -84, -146, 15 }, { -62, -138, 16 } } do
			if free(f[1], f[2], 7) then
				take(f[1], f[2], 7)
				piece("RidgeWalkFence", f[1], f[2], f[3], "WattleFence", 1.0, ORCHARD, function(cf)
					local wc, wm = sw(ORCHARD, "WOOD")
					boxAt("WattlePanel", V(14, 4.4, 0.6), cf * CFrame.new(0, 2.2, 0), wc, wm)
				end)
				props += 1
			end
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 11. Thorn Saddle (145, 44, -185): tangled black-rose briar arches choking the eastern ridge,
	--     with a warden-cut gap and rot-blooms creeping across the crest.
	---------------------------------------------------------------------------------------------------
	do
		local t1, t2 = CorruptedFloor32.Landmarks[18], CorruptedFloor32.Landmarks[19]
		for _, spec in { { "ThornSaddleArchEast", t1, -72 }, { "ThornSaddleArchNorth", t2, 12 } } do
			local lm = spec[2] :: Landmark
			local m = piece(spec[1] :: string, lm.X, lm.Z, spec[3] :: number, "ThornBrambleArch", 1.0, ROTTEN, function(cf)
				local wc, wm = sw(ROTTEN, "WOOD")
				local cc, cm = sw(ROTTEN, "CAP")
				for _, s in { -1, 1 } do
					rod("BriarLeg", (cf * CFrame.new(s * 15, 0, 0)).Position, (cf * CFrame.new(0, 22, 0)).Position, 1.6, wc, wm)
				end
				lump("BriarCrown", (cf * CFrame.new(0, 21, 0)).Position, V(22, 6, 8), cc, cm)
			end, lm.Y)
			pin(m)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 12. Felled Row (east slope below Cider Vats, X ~248..282, Z ~-50..+15): felled band-tied log,
	--     a straight line of fresh-sawn stumps and two smouldering burnt brash piles.
	---------------------------------------------------------------------------------------------------
	do
		local fl = CorruptedFloor32.Landmarks[20]
		local ml = piece("FelledRowLog", fl.X, fl.Z, 82, "FelledBandLog", 0.8, ROTTEN, function(cf)
			local wc, wm = sw(ROTTEN, "WOOD")
			rod("FelledLog", (cf * CFrame.new(-24, 2.6, 0)).Position, (cf * CFrame.new(24, 2.0, 0)).Position, 2.8, wc, wm)
		end)
		noCollide(ml)
		for idx, st in { { 254, -46 }, { 268, -42 }, { 252, -6 }, { 274, 8 }, { 256, 22 } } do
			if free(st[1], st[2], 5) then
				take(st[1], st[2], 5)
				local m = piece("FelledRowStumps", st[1], st[2], idx * 47, "SawnStumpCluster", 0.85, ORCHARD, function(cf)
					local wc, wm = sw(ORCHARD, "WOOD")
					ctx.cyl("SawnStump", (cf * CFrame.new(0, 1.2, 0)).Position, 2.4, 2.4, wc, wm)
				end)
				noCollide(m)
				props += 1
			end
		end
		-- Two smouldering burnt brash piles with wisps of grey-rose smoke.
		for idx, br in { { 264, -30 }, { 262, 12 } } do
			local by = surfaceAt(br[1], br[2])
			ctx.group("FelledBrashPile", function()
				local charred = rgb(44, 34, 38)
				for k = 0, 5 do
					local a = k * math.pi / 3 + idx
					local p = rod("BrashBranch", V(br[1] + math.cos(a) * 6, by + 0.5, br[2] + math.sin(a) * 6), V(br[1] - math.cos(a) * 3, by + 2.4, br[2] - math.sin(a) * 3), 0.42, charred, Mat.Wood)
					noCollide(p)
				end
				local ember = lump("BrashEmber", V(br[1], by + 0.6, br[2]), V(4.2, 1.0, 3.8), rgb(224, 84, 178), Mat.Neon)
				noCollide(ember)
				plume(V(br[1], by + 1.8, br[2]), rgb(146, 120, 134), 3.6, 4, 6, 4.2)
			end)
			props += 1
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 13. Terraced Orchard Rows (E-W lines across the south-facing slope) + glowing windfall puddles
	--     under trees + ladders & baskets beside orchard trunks!
	---------------------------------------------------------------------------------------------------
	local treeTemplates = { "GraftedFruitTreeA", "GraftedFruitTreeB", "GraftedFruitTreeC" }
	local rowZs = { 126, 94, 58, 18, -24, -68, -112 }
	local rowPlaced = 0
	for rIdx, rz in rowZs do
		local x = -270 + (rIdx % 2) * 15
		while x <= 270 do
			local tx = x + rng:NextNumber(-6, 6)
			local tz = rz + rng:NextNumber(-5, 5)
			local _, onDeck = surfaceAt(tx, tz)
			if not onDeck and dry(tx, tz) and level(tx, tz, 6, 4.4) and free(tx, tz, 6) then
				take(tx, tz, 6)
				local tpl = treeTemplates[((rIdx + math.floor((x + 300) / 30)) % 3) + 1]
				local s = rng:NextNumber(0.72, 0.96)
				local tint = if tz < -60 then ROTTEN elseif (rIdx + math.floor(x / 32)) % 2 == 0 then BLOSSOM else ORCHARD
				piece("OrchardRowTree", tx, tz, rng:NextNumber(0, 360), tpl, s, tint, fallbackOrchardTree(tint))
				rowPlaced += 1
				-- Pair every third orchard tree with a ladder/crutch prop or glowing windfall puddle nearby.
				if rowPlaced % 3 == 0 then
					local px, pz = tx + rng:NextNumber(-10, 10), tz + rng:NextNumber(7, 11)
					if dry(px, pz) and free(px, pz, 3.5) then
						take(px, pz, 3.5)
						local propM = piece("OrchardWorkProp", px, pz, rng:NextNumber(0, 360), "CrutchPoleProp", rng:NextNumber(0.85, 1.05), ORCHARD, function(cf)
							local tc, tm = sw(ORCHARD, "TRIM")
							boxAt("OrchardLadder", V(2, 9, 0.5), cf * CFrame.new(0, 4.5, 0), tc, tm)
						end)
						noCollide(propM)
						props += 1
					end
				elseif rowPlaced % 3 == 1 then
					local px, pz = tx + rng:NextNumber(-6, 6), tz + rng:NextNumber(-6, 6)
					local py, pDeck = surfaceAt(px, pz)
					if not pDeck and dry(px, pz) then
						ctx.group("RotFruitPuddle", function()
							local puddle = lump("RotFruitPuddle", V(px, py + 0.08, pz), V(rng:NextNumber(5, 8), 0.2, rng:NextNumber(4, 7)), rgb(222, 76, 198), Mat.SmoothPlastic)
							puddle.Transparency = 0.28
							noCollide(puddle)
						end)
						props += 1
					end
				end
			end
			x += 30
		end
	end
	props += rowPlaced
	landmarks += 1

	---------------------------------------------------------------------------------------------------
	-- 14. Far Skyline & Perimeter Treeline: terraced orchard crowns along the south/east/west wall
	--     feet, darkening to blighted and dead trees behind the north ridge (using wallFoot so zero
	--     roots hang in mid-air on cliff walls).
	---------------------------------------------------------------------------------------------------
	local function wallFoot(side: number, along: number): (number?, number?)
		local function at(inset: number): (number, number)
			if side == 1 then return -w / 2 + inset, along
			elseif side == 2 then return w / 2 - inset, along
			elseif side == 3 then return along, -d / 2 + inset
			else return along, d / 2 - inset end
		end
		for inset = 10, 118, 3 do
			local x, z = at(inset)
			local x2, z2 = at(inset + 14)
			if field and level(x, z, 6, 3.0) and level(x2, z2, 6, 3.0) and math.abs(field.Height(x, z) - field.Height(x2, z2)) < 4 then
				return at(inset + rng:NextNumber(0, 10))
			end
		end
		return nil, nil
	end
	do
		local rimMade = 0
		for _ = 1, 520 do
			if rimMade >= 56 then break end
			local side = rng:NextInteger(1, 4)
			local along = if side <= 2 then rng:NextNumber(-d / 2 + 34, d / 2 - 34) else rng:NextNumber(-w / 2 + 34, w / 2 - 34)
			local x, z = wallFoot(side, along)
			if not x or not z then continue end
			local _, onDeck = surfaceAt(x, z)
			if not onDeck and dry(x, z) and free(x, z, 7) then
				take(x, z, 7)
				if z < -160 then
					local dead = rng:NextNumber() < 0.4
					local s = rng:NextNumber(0.65, 1.0)
					piece("HorizonBlightTree", x, z, rng:NextNumber(0, 360), if dead then "DeadTree" else "BlightTree", s, ROTTEN, fallbackOrchardTree(ROTTEN))
				else
					local pick = rng:NextNumber()
					local tpl = if pick < 0.35 then "PaleBandTree" elseif pick < 0.7 then "GraftedFruitTreeA" else "GraftedFruitTreeB"
					local s = rng:NextNumber(0.9, 1.25)
					piece("HorizonOrchardTree", x, z, rng:NextNumber(0, 360), tpl, s, if pick < 0.5 then BLOSSOM else ORCHARD, fallbackOrchardTree(BLOSSOM))
				end
				rimMade += 1
			end
		end
		props += rimMade
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 15. Link dressing at both ends of all 15 links (off every lane): graft-knot posts, wattle fence
	--     stubs, orchard baskets, ladders, rot-bloom clusters and benches.
	---------------------------------------------------------------------------------------------------
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		for _, endpoint in { { link.AX, link.AZ }, { link.BX, link.BZ } } do
			for _, side in { -1, 1 } do
				local x, z
				for _, reach in { 26, 32, 38 } do
					local tx, tz = endpoint[1] + nx * side * reach, endpoint[2] + nz * side * reach
					local _, onDeck = surfaceAt(tx, tz)
					if free(tx, tz, 3.2) and (onDeck or dry(tx, tz)) then
						x, z = tx, tz
						break
					end
				end
				if x and z then
					take(x, z, 3.2)
					local pick = rng:NextInteger(1, 4)
					local m
					if pick == 1 then
						m = piece("LinkGraftPost", x, z, rng:NextNumber(0, 360), "GraftKnotPost", 0.95, ORCHARD, function(cf)
							local wc, wm = sw(ORCHARD, "WOOD")
							boxAt("GraftPost", V(1.6, 7, 1.6), cf * CFrame.new(0, 3.5, 0), wc, wm)
						end)
					elseif pick == 2 then
						m = piece("LinkFruitBasket", x, z, rng:NextNumber(0, 360), "FruitBasketPile", 0.55, BLOSSOM, function(cf)
							local ac, am = sw(BLOSSOM, "ALT")
							ctx.cyl("Basket", (cf * CFrame.new(0, 1, 0)).Position, 1.6, 2, ac, am)
						end)
					elseif pick == 3 then
						m = piece("LinkCrutchProp", x, z, rng:NextNumber(0, 360), "CrutchPoleProp", 0.85, ORCHARD, function(cf)
							local tc, tm = sw(ORCHARD, "TRIM")
							boxAt("CrutchProp", V(1.5, 8, 0.5), cf * CFrame.new(0, 4, 0), tc, tm)
						end)
					else
						m = piece("LinkRotBlooms", x, z, rng:NextNumber(0, 360), "RotBloomCluster", 1.35, BLOOM, function(cf)
							local cc, cm = sw(BLOOM, "CAP")
							lump("RotBloom", (cf * CFrame.new(0, 1.6, 0)).Position, V(3, 1, 3), cc, cm)
						end)
					end
					noCollide(m)
					props += 1
				end
			end
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 16. Terrace vignettes & orchard slope clutter: diverse Hollin orchard props (no single template
	--     exceeding 12% of placed props!). Reuses 12+ distinct templates so variety beats >= 25.
	---------------------------------------------------------------------------------------------------
	type Clutter = { Name: string, Kit: string?, Scale: number, Tint: any, Fallback: (cf: CFrame) -> (), R: number }
	local orchardClutter: { Clutter } = {
		{ Name = "FruitBaskets", Kit = "FruitBasketPile", Scale = 0.65, Tint = BLOSSOM, Fallback = function(cf) local cc, cm = sw(BLOSSOM, "CORAL"); lump("ApplePile", (cf * CFrame.new(0, 1.2, 0)).Position, V(5, 2.2, 4.5), cc, cm) end, R = 4.2 },
		{ Name = "OrchardLadders", Kit = "CrutchPoleProp", Scale = 0.9, Tint = ORCHARD, Fallback = function(cf) local tc, tm = sw(ORCHARD, "TRIM"); boxAt("Ladder", V(1.8, 9, 0.5), cf * CFrame.new(0, 4.5, 0), tc, tm) end, R = 3.2 },
		{ Name = "WaxUrn", Kit = "StoneUrn", Scale = 0.42, Tint = BENCH_TINT, Fallback = function(cf) local ac, am = sw(BENCH_TINT, "ALT"); ctx.cyl("ClayPot", (cf * CFrame.new(0, 1.2, 0)).Position, 1.3, 2.4, ac, am) end, R = 2.4 },
		{ Name = "OrchardStumps", Kit = "SawnStumpCluster", Scale = 0.55, Tint = ORCHARD, Fallback = function(cf) local wc, wm = sw(ORCHARD, "WOOD"); ctx.cyl("Stump", (cf * CFrame.new(0, 1, 0)).Position, 2, 2, wc, wm) end, R = 3.6 },
		{ Name = "OrchardBoulder", Kit = "BoulderCluster", Scale = 0.72, Tint = ORCHARD, Fallback = function(cf) local sc, sm = sw(ORCHARD, "STONE"); lump("FieldBoulder", (cf * CFrame.new(0, 1.1, 0)).Position, V(5, 2.8, 4.4), sc, sm) end, R = 3.4 },
		{ Name = "WattleRail", Kit = "WattleFence", Scale = 0.75, Tint = ORCHARD, Fallback = function(cf) local wc, wm = sw(ORCHARD, "WOOD"); boxAt("WattleStub", V(10, 3.6, 0.6), cf * CFrame.new(0, 1.8, 0), wc, wm) end, R = 5.2 },
		{ Name = "GraftMarker", Kit = "GraftKnotPost", Scale = 0.85, Tint = ORCHARD, Fallback = function(cf) local wc, wm = sw(ORCHARD, "WOOD"); boxAt("MarkerPost", V(1.4, 6.5, 1.4), cf * CFrame.new(0, 3.2, 0), wc, wm) end, R = 2.6 },
		{ Name = "OrchardBench", Kit = "HollinBench", Scale = 0.9, Tint = ORCHARD, Fallback = function(cf) local wc, wm = sw(ORCHARD, "WOOD"); boxAt("Bench", V(8, 2.5, 2.6), cf * CFrame.new(0, 1.3, 0), wc, wm) end, R = 4.6 },
		{ Name = "OrchardRubble", Kit = "RuinRubble", Scale = 0.7, Tint = ORCHARD, Fallback = function(cf) local sc, sm = sw(ORCHARD, "STONE"); lump("StonePile", (cf * CFrame.new(0, 1, 0)).Position, V(5, 2, 4.5), sc, sm) end, R = 3.5 },
		{ Name = "RotBloomBed", Kit = "RotBloomCluster", Scale = 1.4, Tint = BLOOM, Fallback = function(cf) local cc, cm = sw(BLOOM, "CAP"); lump("RotBloom", (cf * CFrame.new(0, 1.6, 0)).Position, V(3.2, 1.2, 3.2), cc, cm) end, R = 3.0 },
		{ Name = "BlightPodClump", Kit = "BlightPod", Scale = 0.9, Tint = ROTTEN, Fallback = function(cf) local gc, gm = sw(ROTTEN, "GLOW"); lump("BlightPod", (cf * CFrame.new(0, 0.9, 0)).Position, V(2.0, 2.0, 2.0), gc, gm) end, R = 2.8 },
		{ Name = "OrchardFern", Kit = "FernCluster", Scale = 1.15, Tint = BLOSSOM, Fallback = function(cf) local fc, fm = sw(BLOSSOM, "FOLIAGE"); lump("Fern", (cf * CFrame.new(0, 0.8, 0)).Position, V(4, 1.6, 4), fc, fm) end, R = 3.2 },
		{ Name = "OrchardBush", Kit = "FoliageBush", Scale = 0.85, Tint = BLOSSOM, Fallback = function(cf) local cc, cm = sw(BLOSSOM, "CORAL"); lump("BlossomBush", (cf * CFrame.new(0, 1.4, 0)).Position, V(5, 3, 4.5), cc, cm) end, R = 3.6 },
	}
	local clutterCursor = 0
	local function vignette(cx: number, cz: number, spread: number, count: number, deckY: number?): number
		local made = 0
		for _ = 1, count * 6 do
			if made >= count then break end
			local a, rr = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, spread)
			local x, z = cx + math.cos(a) * rr, cz + math.sin(a) * rr
			clutterCursor = (clutterCursor % #orchardClutter) + 1
			local kind = orchardClutter[clutterCursor]
			local gy, onDeck = surfaceAt(x, z)
			local okHeight = deckY == nil or (onDeck and math.abs(gy - deckY) < 0.5)
			if okHeight and (onDeck or dry(x, z)) and free(x, z, kind.R) then
				take(x, z, kind.R)
				local m = piece(kind.Name, x, z, rng:NextNumber(0, 360), kind.Kit, kind.Scale, kind.Tint, kind.Fallback, if onDeck then gy else nil)
				noCollide(m)
				made += 1
			end
		end
		return made
	end
	for id, p in P do
		if id ~= "Sanctuary" and id ~= "Basin" then
			for _, sx in { -1, 0, 1 } do
				for _, sz in { -1, 0, 1 } do
					if sx ~= 0 or sz ~= 0 then
						props += vignette(p.X + sx * (p.Width / 2 - 6), p.Z + sz * (p.Depth / 2 - 6), 8, 2, p.Y)
					end
				end
			end
		end
	end
	-- Orchard Lawn edges & open slope vignettes.
	for k = 0, 19 do
		props += vignette(-270 + k * 28.4, 142 + (k % 2) * 62, 11, 4, 0)
	end
	for _ = 1, 78 do
		props += vignette(rng:NextNumber(-w / 2 + 24, w / 2 - 24), rng:NextNumber(-d / 2 + 40, 128), 16, 4)
	end

	---------------------------------------------------------------------------------------------------
	-- 17. Low Orchard Lawn rot-fruit puddles (Terrain.Pools): floating pink scum, rot-lilies & reeds.
	---------------------------------------------------------------------------------------------------
	local LILY = tinted(ROTTEN, {
		FOLIAGE = swatch(96, 74, 58, Mat.Grass),
		MOSS = swatch(78, 56, 52, Mat.Grass),
		GLOW = swatch(238, 86, 212, Mat.Neon),
		GOLD = swatch(224, 92, 186, Mat.SmoothPlastic),
	})
	for _, pool in (layout.Terrain and layout.Terrain.Pools) or {} do
		for _ = 1, 4 do
			local a, rr = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.1, 1.15)
			local x, z = pool.X + math.cos(a) * pool.RX * rr, pool.Z + math.sin(a) * pool.RZ * rr
			if field and free(x, z, 2.8) then
				local kind = field.Kind(x, z)
				local _, onDeck = surfaceAt(x, z)
				if kind == "POOL" and not onDeck then
					take(x, z, 2.8)
					local m = piece("OrchardPoolLily", x, z, rng:NextNumber(0, 360), "GlowLilyCluster", rng:NextNumber(0.45, 0.7), LILY, function(cf)
						local fc, fm = sw(LILY, "FOLIAGE")
						lump("LilyPad", (cf * CFrame.new(0, 0.1, 0)).Position, V(3.6, 0.2, 3.2), fc, fm)
					end, waterY - 0.05)
					pin(m)
					noCollide(m)
					props += 1
				elseif not onDeck and dry(x, z) then
					take(x, z, 2.8)
					local m = piece("OrchardPoolReeds", x, z, rng:NextNumber(0, 360), "ReedPondCluster", rng:NextNumber(0.55, 0.85), ORCHARD, function(cf)
						local fc, fm = sw(ORCHARD, "FOLIAGE")
						boxAt("Reed", V(0.3, 4.2, 0.3), cf * CFrame.new(0, 2.1, 0), fc, fm)
					end)
					noCollide(m)
					props += 1
				end
			end
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 18. Ground cover (>= 270 target): warm orchard grass tufts, rose wildflowers (rot-blooms),
	--     bracken ferns and small blight pods across the Lawn, terraced benches and hollow rim.
	---------------------------------------------------------------------------------------------------
	for _ = 1, 1800 do
		if cover >= 420 then break end
		local x, z = rng:NextNumber(-w / 2 + 16, w / 2 - 16), rng:NextNumber(-d / 2 + 16, d / 2 - 42)
		local _, onDeck = surfaceAt(x, z)
		local r = 2.4
		if not onDeck and dry(x, z) and free(x, z, r) then
			take(x, z, r)
			local roll = rng:NextNumber()
			local m
			if roll < 0.45 then
				m = piece("OrchardGrass", x, z, rng:NextNumber(0, 360), "AutumnGrassTuft", rng:NextNumber(1.0, 1.55), if z < -80 then ROTTEN else BLOSSOM, function(cf)
					local fc, fm = sw(BLOSSOM, "FOLIAGE")
					lump("GrassTuft", (cf * CFrame.new(0, 0.7, 0)).Position, V(2.4, 1.4, 2.0), fc, fm)
				end)
			elseif roll < 0.75 then
				m = piece("OrchardWildbloom", x, z, rng:NextNumber(0, 360), "RotBloomCluster", rng:NextNumber(0.85, 1.35), BLOOM, function(cf)
					local cc, cm = sw(BLOOM, "CAP")
					lump("RotBloom", (cf * CFrame.new(0, 1.4, 0)).Position, V(2.8, 1.0, 2.8), cc, cm)
				end)
			elseif roll < 0.90 then
				m = piece("OrchardBracken", x, z, rng:NextNumber(0, 360), "FernCluster", rng:NextNumber(0.85, 1.25), ORCHARD, function(cf)
					local fc, fm = sw(ORCHARD, "FOLIAGE")
					lump("Bracken", (cf * CFrame.new(0, 0.8, 0)).Position, V(3.8, 1.5, 3.8), fc, fm)
				end)
			else
				m = piece("OrchardPods", x, z, rng:NextNumber(0, 360), "BlightPod", rng:NextNumber(0.55, 0.85), ROTTEN, function(cf)
					local gc, gm = sw(ROTTEN, "GLOW")
					lump("BlightPod", (cf * CFrame.new(0, 0.7, 0)).Position, V(1.6, 1.6, 1.6), gc, gm)
				end)
			end
			noCollide(m)
			cover += 1
		end
	end

	ctx.setAttribute("Floor32Landmarks", landmarks)
	ctx.setAttribute("Floor32Props", props)
	ctx.setAttribute("Floor32GroundCover", cover)
end

return table.freeze(CorruptedFloor32)
