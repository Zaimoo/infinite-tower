--!strict
-- Hand-authored set pieces for the Corrupted Grove floors (docs/prompts/corrupted-grove-floor-layouts-prompt.md).
--
-- Floor 31, Blighted Verge (guide image: reference/Corrupted Grove 31.webp): the edge of the grove, where the
-- Hollin grove-wardens still held the line. An autumn-gold south bank of banded beeches; a blight-brook rising
-- at the split, glowing Heartrot Spring in the north-east corner and meandering west to a sinkhole; the
-- wardens' thatched Weir Mill and its wheel on the brook, a fieldstone weir at the Weir Ford, their lean-to at
-- the Woodcutters' Ring, the great oak on the Last Green, lanterns in the Lantern Copse, the Warding Shrine
-- cairn, the felled Blight Line hung with Pale Bands, and a rotten north bank of twisted trees and rot-blooms.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local CorruptedGrove = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Mat = Enum.Material

-- Hollin tints: every role of every Floor 31 template, so the kit never falls back to the biome palette.
local function swatch(r: number, g: number, b: number, mat: Enum.Material, trans: number?): any
	return { Color = rgb(r, g, b), Material = mat, Transparency = trans }
end
local AUTUMN = table.freeze({
	WOOD = swatch(92, 76, 64, Mat.Wood), -- grey-brown beech bark and weathered timber
	TRIM = swatch(196, 168, 124, Mat.Wood), -- pale cut wood, carved rings, wattle
	ALT = swatch(164, 128, 76, Mat.Fabric), -- thatch and straw
	FOLIAGE = swatch(214, 150, 54, Mat.Grass), -- golden autumn leaves
	MOSS = swatch(112, 102, 58, Mat.Grass),
	SILK = swatch(232, 226, 210, Mat.Fabric), -- clean linen Pale Bands
	STONE = swatch(112, 104, 90, Mat.Slate), -- mossy fieldstone
	GLOW = swatch(255, 186, 104, Mat.Neon), -- lantern glass, mill windows
	CANDLE = swatch(255, 214, 150, Mat.Neon),
	STEM = swatch(70, 56, 46, Mat.Wood),
	CAP = swatch(196, 120, 56, Mat.Grass),
})
local function tinted(base: any, changes: { [string]: any }): any
	local o = table.clone(base)
	for role, s in changes do
		o[role] = s
	end
	return o
end
local AMBER = tinted(AUTUMN, { FOLIAGE = swatch(198, 108, 42, Mat.Grass) })
local BRACKEN = tinted(AUTUMN, { FOLIAGE = swatch(170, 104, 50, Mat.Grass), MOSS = swatch(98, 84, 52, Mat.Grass) })
-- The rotten bank: bruised bark, plum leaves, magenta rot light, bands stained pink.
local ROTTEN = tinted(AUTUMN, {
	WOOD = swatch(48, 34, 46, Mat.Wood),
	FOLIAGE = swatch(112, 42, 98, Mat.Grass),
	MOSS = swatch(72, 42, 66, Mat.Grass),
	GLOW = swatch(236, 92, 214, Mat.Neon),
	SILK = swatch(214, 164, 186, Mat.Fabric),
	STONE = swatch(84, 74, 78, Mat.Slate),
	CRYSTAL = swatch(236, 92, 214, Mat.Glass, 0.2),
	CAP = swatch(138, 36, 118, Mat.SmoothPlastic),
})
local BLOOM = tinted(AUTUMN, {
	STEM = swatch(52, 30, 50, Mat.SmoothPlastic),
	CAP = swatch(206, 72, 184, Mat.SmoothPlastic),
	GLOW = swatch(255, 120, 230, Mat.Neon),
})
local ROT_LIGHT = rgb(236, 92, 214)
local LAMP_LIGHT = rgb(255, 186, 110)

export type Landmark = InfernalFoundry.Landmark

-- The blight-brook's centreline (TowerLayout AUTHORED[31] Terrain.Pools), west to east, for the two banks.
local BROOK = { { -262, -84 }, { -180, -78 }, { -100, -14 }, { -20, 2 }, { 40, -8 }, { 120, -64 }, { 230, -70 }, { 280, -70 } }
local function brookZ(x: number): number
	if x <= BROOK[1][1] then return BROOK[1][2] end
	for i = 1, #BROOK - 1 do
		local a, b = BROOK[i], BROOK[i + 1]
		if x <= b[1] then
			return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
		end
	end
	return BROOK[#BROOK][2]
end
-- South of the brook is the healthy (autumn) bank; north of it, the rotten one.
CorruptedGrove.HealthyBank = function(x: number, z: number): boolean
	return z > brookZ(x)
end

-- Floor 31's landmark footprints (local floor space, scaled), checked offline by the specs against every
-- walkway lane and camp, and reserved so the clutter passes keep off them.
CorruptedGrove.Floor31Landmarks = table.freeze({
	{ Id = "HeartrotSpring", X = 206, Z = -240, Y = 4, HalfX = 30, HalfZ = 30, Top = 113.6 },
	{ Id = "WeirMill", X = 95, Z = -62, Y = -7.6, HalfX = 13.8, HalfZ = 9.6, Top = 24.9 },
	{ Id = "MillWheel", X = 110.4, Z = -62, Y = -10.1, HalfX = 3.1, HalfZ = 9.6, Top = 19.1 },
	{ Id = "WeirFordWeir", X = 150, Z = -62, Y = -8, HalfX = 6.1, HalfZ = 19.2, Top = 6.5 },
	{ Id = "WardensLeanTo", X = -222, Z = -52, Y = 10, HalfX = 7.3, HalfZ = 8.2, Top = 8.9 },
	{ Id = "WoodcuttersStumps", X = -190, Z = -54, Y = 10, HalfX = 7.1, HalfZ = 6.9, Top = 3 },
	{ Id = "LastGreenOak", X = 96, Z = 70, Y = 6, HalfX = 4, HalfZ = 4, Top = 48.2 },
	{ Id = "WardingCairn", X = -192, Z = -130, Y = 16, HalfX = 8.6, HalfZ = 8.6, Top = 10.5 },
	{ Id = "BlightLineLog", X = -40, Z = -188, Y = 18, HalfX = 31, HalfZ = 6.4, Top = 14.4 },
	{ Id = "RothollowBlightTree", X = 234, Z = -122, Y = 20, HalfX = 5, HalfZ = 5, Top = 50 },
	{ Id = "Sinkhole", X = -256, Z = -86, Y = -4, HalfX = 14, HalfZ = 14, Top = 26 },
}) :: { Landmark }

function CorruptedGrove.Floor31(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number, P = H.field, H.bottom, H.d, H.P
	local w: number = ctx.w
	local layout = ctx.layout
	local surfaceAt, boxAt, lump, light, piece, noCollide = H.surfaceAt, H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local origin: Vector3 = ctx.origin
	-- A cylinder from a to b (local space). Built from a full frame, not CFrame.lookAt, so the near-vertical
	-- trunks of this floor's fallbacks keep their length (lookAt degenerates straight up).
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
	local waterY = if field then field.LiquidLevel else bottom
	local landmarks, props, cover = 0, 0, 0
	local rng = Random.new(31 * 7907)

	for _, lm in CorruptedGrove.Floor31Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- A spot is free when it keeps off every lane, every camp (36 studs plus its own radius) and every spot taken.
	local taken: { { number } } = {}
	for _, lm in CorruptedGrove.Floor31Landmarks do
		table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
	end
	local function free(x: number, z: number, r: number): boolean
		if math.abs(x) > w / 2 - 10 or math.abs(z) > d / 2 - 10 then return false end
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
		return not field or (field.Kind(x, z) ~= "POOL" and field.Slope(x, z) < 0.8)
	end
	-- A piece set at a deliberate height in or on the brook (the mill's footing, the weir, lilies on the water):
	-- the settle pass would drop it onto the brook bed, so it counts as standing on the terrain.
	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end

	---------------------------------------------------------------------------------------------------
	-- Part-built fallbacks (until the Floor 31 kit is imported). cf: the piece's origin on its surface, front +Z.
	---------------------------------------------------------------------------------------------------
	local function sw(tint: any, role: string): (Color3, Enum.Material)
		local s = tint[role]
		return s.Color, s.Material
	end
	local function fallbackTree(tint: any, banded: boolean): (CFrame) -> ()
		return function(cf: CFrame)
			local wc, wm = sw(tint, "WOOD")
			local fc, fm = sw(tint, "FOLIAGE")
			rod("BeechTrunk", (cf * CFrame.new(0, -0.5, 0)).Position, (cf * CFrame.new(0.6, 24, 0.3)).Position, 1.8, wc, wm)
			for k = 0, 3 do
				local a = k * math.pi / 2 + 0.4
				rod("BeechBough", (cf * CFrame.new(0, 17, 0)).Position, (cf * CFrame.new(math.cos(a) * 9, 26, math.sin(a) * 9)).Position, 0.6, wc, wm)
				lump("BeechCrown", (cf * CFrame.new(math.cos(a) * 9, 28, math.sin(a) * 9)).Position, V(12, 8, 11), fc, fm)
			end
			lump("BeechCrown", (cf * CFrame.new(0, 31, 0)).Position, V(17, 11, 16), fc, fm)
			if banded then
				local sc, sm = sw(tint, "SILK")
				ctx.cyl("PaleBand", (cf * CFrame.new(0, 3.6, 0)).Position, 2.0, 1.5, sc, sm)
			end
		end
	end
	local function fallbackPost(cf: CFrame)
		local wc, wm = sw(AUTUMN, "WOOD")
		boxAt("GraftKnotPostShaft", V(1.6, 7, 1.6), cf * CFrame.new(0, 3.5, 0), wc, wm)
		for _, s in { -1, 1 } do
			boxAt("GraftKnotBranch", V(0.8, 0.8, 5.4), cf * CFrame.new(0, 8.4, 0) * CFrame.Angles(0, 0, s * math.rad(45)) * CFrame.Angles(math.pi / 2, 0, 0), wc, wm)
		end
		local sc, sm = sw(AUTUMN, "SILK")
		boxAt("GraftKnotBand", V(1.9, 1, 1.9), cf * CFrame.new(0, 4.6, 0), sc, sm)
	end
	-- The lantern stands on its foot; its cord rises LANTERN_DROP studs to the hook it hangs from.
	local LANTERN_DROP = 5.2
	local function fallbackLantern(cf: CFrame, tint: any): BasePart
		local gc, gm = sw(tint, "GLOW")
		local wc, wm = sw(tint, "WOOD")
		boxAt("LanternCord", V(0.15, 1.6, 0.15), cf * CFrame.new(0, LANTERN_DROP - 0.8, 0), wc, wm)
		boxAt("LanternCap", V(2.2, 0.6, 2.2), cf * CFrame.new(0, LANTERN_DROP - 2.3, 0), wc, wm)
		return boxAt("LanternGlass", V(1.8, 2.4, 1.8), cf * CFrame.new(0, LANTERN_DROP - 3.8, 0), gc, gm)
	end
	local function lantern(kind: string, x: number, hookY: number, z: number, tint: any)
		local made = piece(kind, x, z, rng:NextNumber(0, 360), "HangingLantern", 1, tint, function(cf)
			light(fallbackLantern(cf, tint), LAMP_LIGHT, 1.2, 30)
		end, hookY - LANTERN_DROP)
		if made and ctx.has("HangingLantern") then
			local glow = H.glowOf(made)
			if glow then light(glow, LAMP_LIGHT, 1.2, 30) end
		end
		noCollide(made)
	end

	---------------------------------------------------------------------------------------------------
	-- 1. The Heartrot Spring (beside the Apex, north-east): the split elder, its rot-heart, the brook's source.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[1]
		-- The elder stands in the low ground east of the Apex, the spring welling up from its roots.
		local y = surfaceAt(lm.X, lm.Z)
		local made = piece("HeartrotSpring", lm.X, lm.Z, 214, "HeartrotSpringTrunk", 1.25, ROTTEN, function(cf)
			local wc, wm = sw(ROTTEN, "WOOD")
			local gc, gm = sw(ROTTEN, "GLOW")
			for _, s in { -1, 1 } do
				rod("SpringTrunkHalf", (cf * CFrame.new(s * 5, -2, 2)).Position, (cf * CFrame.new(s * 16, 100, 7)).Position, 9, wc, wm)
			end
			for k = 0, 8 do
				local a = k * math.pi * 2 / 9
				rod("SpringTrunkRoot", (cf * CFrame.new(math.cos(a) * 6, 12, math.sin(a) * 6)).Position, (cf * CFrame.new(math.cos(a) * 34, -1, math.sin(a) * 34)).Position, 3.4, wc, wm)
			end
			local heart = lump("SpringRotHeart", (cf * CFrame.new(0, 11, -3)).Position, V(9, 20, 5), gc, gm)
			rod("SpringRotSeam", (cf * CFrame.new(0, 14, -2)).Position, (cf * CFrame.new(0, 64, -2)).Position, 1.6, gc, gm)
			light(heart, ROT_LIGHT, 1.6, 60)
		end, y)
		pin(made)
		if made and ctx.has("HeartrotSpringTrunk") then
			local glow = H.glowOf(made)
			if glow then light(glow, ROT_LIGHT, 1.6, 60) end
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 2. The wardens' mill on the brook between the Fallen-Log Ford and the weir, its wheel in the race.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[2]
		-- The footing stands in the race; the wheel hangs from the mill's axle (6.5 up), dipping into the water.
		local millY = waterY - 2
		local made = piece("WeirMill", lm.X, lm.Z, 0, "HollinWaterMill", 1, AUTUMN, function(cf)
			local sc, sm = sw(AUTUMN, "STONE")
			local tc, tm = sw(AUTUMN, "TRIM")
			local wc, wm = sw(AUTUMN, "WOOD")
			local ac, am = sw(AUTUMN, "ALT")
			local gc, gm = sw(AUTUMN, "GLOW")
			boxAt("MillFooting", V(22, 5.2, 16), cf * CFrame.new(0, 2.6, 0), sc, sm)
			boxAt("MillWalls", V(19, 10, 13), cf * CFrame.new(0, 10.2, 0), tc, tm)
			for _, x in { -9.4, 9.4 } do
				for _, z in { -6.4, 6.4 } do
					boxAt("MillPost", V(1.1, 11, 1.1), cf * CFrame.new(x, 10.6, z), wc, wm)
				end
			end
			for _, s in { -1, 1 } do
				boxAt("MillThatch", V(24, 1.9, 10.6), cf * CFrame.new(0, 19.2, s * 4.4) * CFrame.Angles(s * 0.72, 0, 0), ac, am)
			end
			local win = boxAt("MillWindowGlow", V(2.2, 2, 0.3), cf * CFrame.new(4.4, 11.2, 6.65), gc, gm)
			light(win, LAMP_LIGHT, 1.0, 28)
		end, millY)
		pin(made)
		if made and ctx.has("HollinWaterMill") then
			local glow = H.glowOf(made)
			if glow then light(glow, LAMP_LIGHT, 1.0, 28) end
		end
		local wl = CorruptedGrove.Floor31Landmarks[3]
		pin(piece("MillWheel", wl.X, wl.Z, 0, "MillWheel", 1, AUTUMN, function(cf)
			local wc, wm = sw(AUTUMN, "WOOD")
			for k = 0, 8 do
				local a = k * math.pi / 9
				boxAt("MillWheelPaddle", V(3.8, 0.4, 18), cf * CFrame.new(0, 9, 0) * CFrame.Angles(a, 0, 0), wc, wm)
			end
			ctx.cyl("MillWheelHub", (cf * CFrame.new(0, 9, 0)).Position, 2.2, 5.6, wc, wm)
		end, millY + 6.5 - 9))
		landmarks += 2
	end

	---------------------------------------------------------------------------------------------------
	-- 3. The fieldstone weir across the brook beside the Weir Ford (its spill face downstream, west).
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[4]
		pin(piece("FieldstoneWeir", lm.X, lm.Z, -90, "FieldstoneWeir", 1, AUTUMN, function(cf)
			local sc, sm = sw(AUTUMN, "STONE")
			for k = 0, 2 do
				boxAt("WeirStep", V(38, 6 - k * 2, 4.4), cf * CFrame.new(0, (6 - k * 2) / 2, 2 - k * 4), sc, sm)
			end
		end, waterY - 2.4))
		-- White water on the spill face: foam lumps (not a flat sheet).
		ctx.group("WeirFoam", function()
			for k = -3, 3 do
				local f = lump("WeirFoam", V(lm.X - 6.5, waterY + 0.2, lm.Z + k * 5), V(4.2, 1.1, 4.6), rgb(232, 214, 236), Mat.SmoothPlastic)
				f.Transparency = 0.25
			end
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 4. The Pale Glade (West Gallery): banded beeches round the glade, a graft-knot post.
	---------------------------------------------------------------------------------------------------
	for i, spot in { { -206, 52, 1.0 }, { -198, 80, 0.9 }, { -168, 86, 0.95 }, { -218, 66, 0.85 }, { -182, 98, 0.8 } } do
		if free(spot[1], spot[2], 4) then
			take(spot[1], spot[2], 4)
			piece("PaleGladeBeech", spot[1], spot[2], i * 71, "PaleBandTree", spot[3], if i % 2 == 0 then AMBER else AUTUMN, fallbackTree(AUTUMN, true))
			props += 1
		end
	end
	if free(-200, 32, 3) then
		take(-200, 32, 3)
		piece("GraftKnotPost", -200, 32, 60, "GraftKnotPost", 1.1, AUTUMN, fallbackPost)
	end
	landmarks += 1

	---------------------------------------------------------------------------------------------------
	-- 5. The Woodcutters' Ring: the wardens' lean-to, fire ring and fresh-sawn stumps.
	---------------------------------------------------------------------------------------------------
	do
		local lt = CorruptedGrove.Floor31Landmarks[5]
		piece("WardensLeanTo", lt.X, lt.Z, 90, "WardensLeanTo", 1, AUTUMN, function(cf)
			local wc, wm = sw(AUTUMN, "WOOD")
			local ac, am = sw(AUTUMN, "ALT")
			for _, x in { -7, 7 } do
				boxAt("LeanToPole", V(0.8, 8.6, 0.8), cf * CFrame.new(x, 4.3, -4), wc, wm)
				boxAt("LeanToPole", V(0.8, 4, 0.8), cf * CFrame.new(x, 2, 4), wc, wm)
			end
			boxAt("LeanToThatch", V(16.4, 1, 10.4), cf * CFrame.new(0, 6.4, 0.2) * CFrame.Angles(0.42, 0, 0), ac, am)
		end, lt.Y)
		local st = CorruptedGrove.Floor31Landmarks[6]
		local stumps = piece("WoodcuttersStumps", st.X, st.Z, 30, "SawnStumpCluster", 1, AUTUMN, function(cf)
			local wc, wm = sw(AUTUMN, "WOOD")
			local tc, tm = sw(AUTUMN, "TRIM")
			for _, s in { { 0, 0, 2.6, 2.4 }, { 5.2, 2.6, 1.9, 1.6 }, { -4.6, 3.2, 1.6, 1.3 } } do
				ctx.cyl("SawnStump", (cf * CFrame.new(s[1], s[4] / 2, s[2])).Position, s[3], s[4], wc, wm)
				ctx.cyl("SawnStumpFace", (cf * CFrame.new(s[1], s[4] + 0.1, s[2])).Position, s[3] - 0.2, 0.2, tc, tm)
			end
		end, st.Y)
		noCollide(stumps)
		lantern("WoodcuttersLantern", lt.X + 4, lt.Y + 8.2, lt.Z + 7, AUTUMN)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 6. The Last Green: the great banded oak on the fieldstone knoll, its lantern, boulders round the rim.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[7]
		piece("LastGreenOak", lm.X, lm.Z, 200, "PaleBandTree", 1.35, AUTUMN, fallbackTree(AUTUMN, true), lm.Y)
		lantern("LastGreenLantern", lm.X - 7, lm.Y + 17, lm.Z - 3, AUTUMN)
		for _, b in { { 98, 76, 1.2 }, { 22, 56, 1.0 }, { 96, 22, 0.9 }, { 30, 78, 0.8 }, { 64, 82, 1.1 } } do
			if free(b[1], b[2], 4 * b[3]) then
				take(b[1], b[2], 4 * b[3])
				piece("LastGreenBoulder", b[1], b[2], b[1] * 7, "BoulderCluster", b[3], AUTUMN, function(cf)
					local sc, sm = sw(AUTUMN, "STONE")
					lump("KnollBoulder", (cf * CFrame.new(0, 1.2, 0)).Position, V(7, 3.6, 6) * b[3], sc, sm)
				end)
				props += 1
			end
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 7. The Lantern Copse (East Gallery): banded beeches hung with wicker lanterns, a trail shrine post.
	---------------------------------------------------------------------------------------------------
	do
		local hung = 0
		for i, spot in { { 214, 20, 0.85 }, { 204, 38, 0.8 }, { 222, -30, 0.9 }, { 228, -4, 0.75 } } do
			if free(spot[1], spot[2], 4) then
				take(spot[1], spot[2], 4)
				local gy = surfaceAt(spot[1], spot[2])
				piece("LanternCopseBeech", spot[1], spot[2], i * 53, "PaleBandTree", spot[3], if i == 3 then tinted(AMBER, { SILK = ROTTEN.SILK }) else AMBER, fallbackTree(AMBER, true))
				if hung < 2 and i % 2 == 1 then
					hung += 1
					lantern("CopseLantern", spot[1] - 6, gy + 15, spot[2] + 2, AUTUMN)
				end
				props += 1
			end
		end
		if free(160, 30, 3) then
			take(160, 30, 3)
			piece("GraftKnotPost", 160, 30, 200, "GraftKnotPost", 1, AUTUMN, fallbackPost)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 8. The Warding Shrine: the cairn on its stone ring, banded stakes, a wattle screen.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[8]
		piece("WardingCairn", lm.X, lm.Z, 150, "FieldstoneCairn", 1, tinted(AUTUMN, { SILK = ROTTEN.SILK }), function(cf)
			local sc, sm = sw(AUTUMN, "STONE")
			for k = 0, 5 do
				local s = 7 - k
				lump("CairnStone", (cf * CFrame.new(0, 0.8 + k * 1.5, 0)).Position, V(s, 1.8, s * 0.9), sc, sm)
			end
		end, lm.Y)
		for _, f in { { -200, -104, 10 }, { -186, -150, -15 } } do
			if free(f[1], f[2], 7) then
				take(f[1], f[2], 7)
				piece("WattleFence", f[1], f[2], f[3], "WattleFence", 1, AUTUMN, function(cf)
					local wc, wm = sw(AUTUMN, "WOOD")
					boxAt("WattlePanel", V(14, 4.4, 0.6), cf * CFrame.new(0, 2.2, 0), wc, wm)
				end)
				props += 1
			end
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 9. Rothollow: where the brook first turns; a twisted blight tree over a bed of rot-blooms.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[10]
		local tree = piece("RothollowBlightTree", lm.X, lm.Z, 40, "BlightTree", 0.8, ROTTEN, fallbackTree(ROTTEN, false))
		local glow = H.glowOf(tree)
		local core = lump("RothollowRotGlow", V(lm.X - 2, (surfaceAt(lm.X - 2, lm.Z + 4)) + 1, lm.Z + 4), V(4, 3, 4), ROT_LIGHT, Mat.Neon)
		light(glow or core, ROT_LIGHT, 1.4, 40)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 10. The Blight Line: the felled trunk laid across the north bank, Pale Bands torn and hanging.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[9]
		local made = piece("BlightLineLog", lm.X, lm.Z, 0, "FelledBandLog", 1, ROTTEN, function(cf)
			local wc, wm = sw(ROTTEN, "WOOD")
			local sc, sm = sw(ROTTEN, "SILK")
			rod("FelledLogTrunk", (cf * CFrame.new(-30, 3.4, 0)).Position, (cf * CFrame.new(30, 2.4, 0)).Position, 3.6, wc, wm)
			for k = -2, 2 do
				ctx.block("FelledLogBand", V(1, 7.6, 7.6), (cf * CFrame.new(k * 11, 3.0, 0)).Position, sc, sm)
			end
		end)
		noCollide(made)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 11. The sinkhole where the brook drains into the west wall: a dark rock throat glowing faintly.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedGrove.Floor31Landmarks[11]
		ctx.group("Sinkhole", function()
			local sc, sm = sw(ROTTEN, "STONE")
			for _, r in { { -10, -8, 12 }, { 8, -10, 10 }, { -2, 10, 9 } } do
				lump("SinkholeRock", V(lm.X + r[1], bottom + r[3] * 0.6, lm.Z + r[2]), V(r[3] * 1.6, r[3] * 1.4, r[3] * 1.3), sc, sm)
			end
			lump("SinkholeThroat", V(lm.X - 4, waterY - 0.6, lm.Z), V(14, 2, 12), rgb(30, 18, 34), Mat.SmoothPlastic)
			local seep = lump("SinkholeRotSeep", V(lm.X - 2, waterY + 0.2, lm.Z), V(6, 0.6, 5), ROT_LIGHT, Mat.Neon)
			light(seep, ROT_LIGHT, 1.0, 30)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 12. The Warden's Stile (arrival): the woven arch over the path, wattle fences along the stile's edge.
	---------------------------------------------------------------------------------------------------
	do
		local safe = P.Sanctuary
		local z = safe.Z - safe.Depth / 2 + 3
		piece("HollinStile", 0, z, 0, "HollinStileArch", 1, AUTUMN, function(cf)
			local wc, wm = sw(AUTUMN, "WOOD")
			for _, s in { -1, 1 } do
				rod("StilePost", (cf * CFrame.new(s * 21.5, -0.5, 0)).Position, (cf * CFrame.new(s * 21.5, 17, 0)).Position, 1.2, wc, wm)
			end
			for k = 0, 7 do
				local u0, u1 = -1 + k / 4, -1 + (k + 1) / 4
				rod("StileWithy", (cf * CFrame.new(u0 * 21.5, 16 + 8 * (1 - u0 * u0), 0)).Position, (cf * CFrame.new(u1 * 21.5, 16 + 8 * (1 - u1 * u1), 0)).Position, 0.9, wc, wm)
			end
		end, safe.Y)
		lantern("StileLantern", 23, safe.Y + 15, z - 1.6, AUTUMN)
		for _, x in { -60, -46, -32, 32, 46, 60 } do
			piece("StileWattleFence", x, z, 0, "WattleFence", 1, AUTUMN, function(cf)
				local wc, wm = sw(AUTUMN, "WOOD")
				boxAt("WattlePanel", V(14, 4.4, 0.6), cf * CFrame.new(0, 2.2, 0), wc, wm)
			end, safe.Y)
			props += 1
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 13. The two banks' trees: golden banded beeches south of the brook, twisted blight and dead trees north,
	-- and a wall of both round the room's rim (the forest beyond).
	---------------------------------------------------------------------------------------------------
	local function grove(count: number, healthy: boolean, rim: boolean)
		local made = 0
		for _ = 1, count * 12 do
			if made >= count then break end
			local x, z
			if rim then
				-- On the wall slopes, inside the room.
				local side = rng:NextInteger(1, 4)
				local inset = rng:NextNumber(14, 30)
				if side == 1 then x, z = -w / 2 + inset, rng:NextNumber(-d / 2 + 30, d / 2 - 80)
				elseif side == 2 then x, z = w / 2 - inset, rng:NextNumber(-d / 2 + 30, d / 2 - 80)
				elseif side == 3 then x, z = rng:NextNumber(-w / 2 + 30, w / 2 - 30), -d / 2 + inset
				else x, z = rng:NextNumber(-w / 2 + 30, w / 2 - 30), d / 2 - 64 - inset * 0.3 end
			else
				x, z = rng:NextNumber(-w / 2 + 24, w / 2 - 24), rng:NextNumber(-d / 2 + 30, 96)
			end
			if CorruptedGrove.HealthyBank(x, z) == healthy and math.abs(z - brookZ(x)) > 14 then
				local r = if rim then 6 else 5
				local _, onDeck = surfaceAt(x, z)
				if not onDeck and (rim or dry(x, z)) and free(x, z, r) then
					take(x, z, r)
					if healthy then
						local s = rng:NextNumber(0.8, 1.15) * (if rim then 1.3 else 1)
						piece(if rim then "RimBeech" else "BankBeech", x, z, rng:NextNumber(0, 360), "PaleBandTree", s, if rng:NextNumber() < 0.45 then AMBER else AUTUMN, fallbackTree(AUTUMN, false))
					else
						local dead = rng:NextNumber() < 0.35
						local s = rng:NextNumber(0.55, 0.85) * (if rim then 1.25 else 1)
						piece(if rim then "RimBlightTree" else "BankBlightTree", x, z, rng:NextNumber(0, 360), if dead then "DeadTree" else "BlightTree", s, ROTTEN, fallbackTree(ROTTEN, false))
					end
					made += 1
				end
			end
		end
		return made
	end
	props += grove(20, true, false)
	props += grove(20, false, false)
	props += grove(24, true, true)
	props += grove(26, false, true)

	---------------------------------------------------------------------------------------------------
	-- 14. Dressing at both ends of every link (off the lanes): posts, fences, stumps, blooms by bank.
	---------------------------------------------------------------------------------------------------
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		for _, endpoint in { { link.AX, link.AZ }, { link.BX, link.BZ } } do
			for _, side in { -1, 1 } do
				local x, z
				for _, reach in { 27, 32, 38 } do
					local tx, tz = endpoint[1] + nx * side * reach, endpoint[2] + nz * side * reach
					local _, onDeck = surfaceAt(tx, tz)
					if free(tx, tz, 3) and (onDeck or dry(tx, tz)) then
						x, z = tx, tz
						break
					end
				end
				if x and z then
					take(x, z, 3)
					local healthy = CorruptedGrove.HealthyBank(x, z)
					local pick = rng:NextInteger(1, 3)
					local m
					if pick == 1 then
						m = piece("LinkGraftPost", x, z, rng:NextNumber(0, 360), "GraftKnotPost", 0.9, if healthy then AUTUMN else tinted(AUTUMN, { SILK = ROTTEN.SILK }), fallbackPost)
					elseif healthy then
						m = piece("LinkStumps", x, z, rng:NextNumber(0, 360), "SawnStumpCluster", 0.6, AUTUMN, function(cf)
							local wc, wm = sw(AUTUMN, "WOOD")
							ctx.cyl("SawnStump", (cf * CFrame.new(0, 1, 0)).Position, 2, 2, wc, wm)
						end)
					else
						m = piece("LinkRotBlooms", x, z, rng:NextNumber(0, 360), "RotBloomCluster", 1.3, BLOOM, function(cf)
							local cc, cm = sw(BLOOM, "CAP")
							lump("RotBloom", (cf * CFrame.new(0, 1.8, 0)).Position, V(3, 1, 3), cc, cm)
						end)
					end
					noCollide(m)
					props += 1
				end
			end
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 15. Every terrace a vignette: the wardens' clutter in each free corner and along the free edges (wax
	-- and cider pots, firewood, stumps, baskets, boulders and ferns on the south bank; rot-blooms, blight pods,
	-- toppled pots and torn-band stakes on the north).
	---------------------------------------------------------------------------------------------------
	local function stake(cf: CFrame, tint: any)
		local wc, wm = sw(tint, "WOOD")
		local sc, sm = sw(tint, "SILK")
		boxAt("BandStake", V(0.6, 5, 0.6), cf * CFrame.new(0, 2.5, 0), wc, wm)
		boxAt("BandStakeBand", V(0.9, 0.6, 0.9), cf * CFrame.new(0, 3.8, 0), sc, sm)
	end
	local function firewood(cf: CFrame)
		local wc, wm = sw(AUTUMN, "WOOD")
		for k = 0, 2 do
			rod("Firewood", (cf * CFrame.new(-2.5, 0.6 + k * 1.1, (k - 1) * 0.6)).Position, (cf * CFrame.new(2.5, 0.6 + k * 1.1, (k - 1) * 0.6)).Position, 0.55, wc, wm)
		end
	end
	local function basket(cf: CFrame)
		local ac, am = sw(AUTUMN, "ALT")
		ctx.cyl("WickerBasket", (cf * CFrame.new(0, 1, 0)).Position, 1.4, 2, ac, am)
		lump("BasketApples", (cf * CFrame.new(0, 2.1, 0)).Position, V(2.2, 0.8, 2.2), rgb(176, 92, 40), Mat.SmoothPlastic)
	end
	type Clutter = { Name: string, Kit: string?, Scale: number, Tint: any, Fallback: (cf: CFrame) -> (), R: number }
	local southKinds: { Clutter } = {
		{ Name = "WaxPots", Kit = "StoneUrn", Scale = 0.35, Tint = AUTUMN, Fallback = function(cf) local sc, sm = sw(AUTUMN, "STONE"); ctx.cyl("WaxPot", (cf * CFrame.new(0, 1, 0)).Position, 1.1, 2, sc, sm) end, R = 2 },
		{ Name = "Firewood", Kit = nil, Scale = 1, Tint = AUTUMN, Fallback = firewood, R = 3 },
		{ Name = "AppleBasket", Kit = nil, Scale = 1, Tint = AUTUMN, Fallback = basket, R = 2 },
		{ Name = "SawnStump", Kit = "SawnStumpCluster", Scale = 0.45, Tint = AUTUMN, Fallback = function(cf) local wc, wm = sw(AUTUMN, "WOOD"); ctx.cyl("SawnStump", (cf * CFrame.new(0, 1, 0)).Position, 1.8, 2, wc, wm) end, R = 3.4 },
		{ Name = "FieldBoulder", Kit = "BoulderCluster", Scale = 0.7, Tint = AUTUMN, Fallback = function(cf) local sc, sm = sw(AUTUMN, "STONE"); lump("FieldBoulder", (cf * CFrame.new(0, 1, 0)).Position, V(5, 2.8, 4.4), sc, sm) end, R = 3.2 },
		{ Name = "BankBracken", Kit = "FernCluster", Scale = 1.2, Tint = BRACKEN, Fallback = function(cf) local fc, fm = sw(BRACKEN, "FOLIAGE"); lump("Bracken", (cf * CFrame.new(0, 0.8, 0)).Position, V(4, 1.6, 4), fc, fm) end, R = 3 },
		{ Name = "BandStake", Kit = nil, Scale = 1, Tint = AUTUMN, Fallback = function(cf) stake(cf, AUTUMN) end, R = 1.2 },
	}
	local northKinds: { Clutter } = {
		{ Name = "RotBloomBed", Kit = "RotBloomCluster", Scale = 1.5, Tint = BLOOM, Fallback = function(cf) local cc, cm = sw(BLOOM, "CAP"); lump("RotBloom", (cf * CFrame.new(0, 1.6, 0)).Position, V(3, 1, 3), cc, cm) end, R = 3 },
		{ Name = "BlightPodBed", Kit = "BlightPod", Scale = 1.0, Tint = ROTTEN, Fallback = function(cf) local gc, gm = sw(ROTTEN, "GLOW"); lump("BlightPod", (cf * CFrame.new(0, 0.8, 0)).Position, V(1.8, 1.8, 1.8), gc, gm) end, R = 2.2 },
		{ Name = "ToppledPot", Kit = "StoneUrn", Scale = 0.35, Tint = ROTTEN, Fallback = function(cf) local sc, sm = sw(ROTTEN, "STONE"); ctx.cyl("ToppledPot", (cf * CFrame.new(0, 1, 0)).Position, 1.1, 2, sc, sm) end, R = 2 },
		{ Name = "TornBandStake", Kit = nil, Scale = 1, Tint = ROTTEN, Fallback = function(cf) stake(cf, ROTTEN) end, R = 1.2 },
		{ Name = "RotStump", Kit = "SawnStumpCluster", Scale = 0.45, Tint = ROTTEN, Fallback = function(cf) local wc, wm = sw(ROTTEN, "WOOD"); ctx.cyl("RotStump", (cf * CFrame.new(0, 1, 0)).Position, 1.8, 2, wc, wm) end, R = 3.4 },
		{ Name = "BlightBoulder", Kit = "BoulderCluster", Scale = 0.7, Tint = ROTTEN, Fallback = function(cf) local sc, sm = sw(ROTTEN, "STONE"); lump("BlightBoulder", (cf * CFrame.new(0, 1, 0)).Position, V(5, 2.8, 4.4), sc, sm) end, R = 3.2 },
	}
	local function vignette(cx: number, cz: number, spread: number, count: number, deckY: number?): number
		local made = 0
		for _ = 1, count * 6 do
			if made >= count then break end
			local a, rr = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, spread)
			local x, z = cx + math.cos(a) * rr, cz + math.sin(a) * rr
			local list = if CorruptedGrove.HealthyBank(x, z) then southKinds else northKinds
			local kind = list[rng:NextInteger(1, #list)]
			local gy, onDeck = surfaceAt(x, z)
			local level = deckY == nil or (onDeck and math.abs(gy - deckY) < 0.5)
			if level and (onDeck or dry(x, z)) and free(x, z, kind.R) then
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
						props += vignette(p.X + sx * (p.Width / 2 - 6), p.Z + sz * (p.Depth / 2 - 6), 7, 2, p.Y)
					end
				end
			end
		end
	end
	-- The Verge Meadow's edges and the open banks between terraces.
	for k = 0, 13 do
		props += vignette(-230 + k * 35.4, 120 + (k % 2) * 50, 10, 3, 0)
	end
	for _ = 1, 26 do
		props += vignette(rng:NextNumber(-w / 2 + 30, w / 2 - 30), rng:NextNumber(-d / 2 + 40, 96), 14, 3)
	end

	---------------------------------------------------------------------------------------------------
	-- 16. The brook itself: rot-lilies and scum on the water (the place-wide teal water reads brown in the
	-- grove's light, so what floats on it says "water"), reeds and fieldstones along both banks.
	---------------------------------------------------------------------------------------------------
	local LILY = tinted(ROTTEN, {
		FOLIAGE = swatch(86, 70, 52, Mat.Grass),
		MOSS = swatch(72, 58, 46, Mat.Grass),
		GLOW = swatch(236, 92, 214, Mat.Neon),
		GOLD = swatch(206, 72, 184, Mat.SmoothPlastic),
		WOOD = swatch(58, 44, 40, Mat.Wood),
	})
	local REEDS = tinted(AUTUMN, { FOLIAGE = swatch(176, 138, 72, Mat.Grass), GLOW = swatch(210, 160, 96, Mat.Grass), WOOD = swatch(96, 76, 52, Mat.Wood) })
	local brookProps = 0
	for i, pool in (layout.Terrain and layout.Terrain.Pools) or {} do
		for _ = 1, 4 do
			local a, rr = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.15, 1.25)
			local x, z = pool.X + math.cos(a) * pool.RX * rr, pool.Z + math.sin(a) * pool.RZ * rr
			if field and free(x, z, 3) then
				local kind = field.Kind(x, z)
				local _, onDeck = surfaceAt(x, z)
				if kind == "POOL" and not onDeck then
					take(x, z, 3)
					local m = piece("RotLilies", x, z, rng:NextNumber(0, 360), "GlowLilyCluster", rng:NextNumber(0.5, 0.8), LILY, function(cf)
						local gc, gm = sw(LILY, "GOLD")
						local fc, fm = sw(LILY, "FOLIAGE")
						lump("LilyPad", (cf * CFrame.new(0, 0.1, 0)).Position, V(4, 0.25, 3.4), fc, fm)
						lump("RotLily", (cf * CFrame.new(0.6, 0.5, 0.3)).Position, V(1.2, 0.8, 1.2), gc, gm)
					end, waterY - 0.05)
					pin(m)
					noCollide(m)
					brookProps += 1
				elseif not onDeck and dry(x, z) then
					take(x, z, 3)
					local reeds = rng:NextNumber() < 0.6
					local m = piece(if reeds then "BrookReeds" else "BankStone", x, z, rng:NextNumber(0, 360), if reeds then "ReedPondCluster" else "BoulderCluster", rng:NextNumber(0.6, 0.9),
						if reeds then (if CorruptedGrove.HealthyBank(x, z) then REEDS else ROTTEN) else AUTUMN, function(cf)
							if reeds then
								local fc, fm = sw(REEDS, "FOLIAGE")
								for k = 0, 4 do
									boxAt("Reed", V(0.3, 5, 0.3), cf * CFrame.new((k - 2) * 0.7, 2.5, (k % 2) * 0.6) * CFrame.Angles(0, 0, math.rad((k - 2) * 6)), fc, fm)
								end
							else
								local sc, sm = sw(AUTUMN, "STONE")
								lump("BankStone", (cf * CFrame.new(0, 0.8, 0)).Position, V(4, 2, 3.6), sc, sm)
							end
						end)
					noCollide(m)
					brookProps += 1
				end
			end
		end
		-- A raft of pink rot-scum drifting at the edge of every third pool.
		if i % 3 == 0 then
			ctx.group("RotScum", function()
				for k = 0, 2 do
					local s = lump("RotScum", V(pool.X + (k - 1) * 4.5, waterY + 0.05, pool.Z + pool.RZ * 0.45), V(5 - k, 0.12, 3.5), rgb(184, 96, 168), Mat.SmoothPlastic)
					s.Transparency = 0.25
				end
			end)
		end
	end
	props += brookProps

	---------------------------------------------------------------------------------------------------
	-- 17. Ground cover: golden grass and bracken on the south bank, rot-blooms and blight pods on the north.
	---------------------------------------------------------------------------------------------------
	for _ = 1, 1400 do
		if cover >= 380 then break end
		local x, z = rng:NextNumber(-w / 2 + 14, w / 2 - 14), rng:NextNumber(-d / 2 + 14, d / 2 - 40)
		local _, onDeck = surfaceAt(x, z)
		local r = 2.4
		if not onDeck and dry(x, z) and free(x, z, r) then
			take(x, z, r)
			local healthy = CorruptedGrove.HealthyBank(x, z)
			local roll = rng:NextNumber()
			local m
			if healthy then
				if roll < 0.7 then
					m = piece("AutumnGrass", x, z, rng:NextNumber(0, 360), "AutumnGrassTuft", rng:NextNumber(1.0, 1.6), if roll < 0.3 then AMBER else AUTUMN, function(cf)
						local fc, fm = sw(AUTUMN, "FOLIAGE")
						lump("GrassTuft", (cf * CFrame.new(0, 0.8, 0)).Position, V(2.4, 1.6, 2), fc, fm)
					end)
				else
					m = piece("Bracken", x, z, rng:NextNumber(0, 360), "FernCluster", rng:NextNumber(0.9, 1.3), BRACKEN, function(cf)
						local fc, fm = sw(BRACKEN, "FOLIAGE")
						lump("Bracken", (cf * CFrame.new(0, 0.8, 0)).Position, V(4, 1.6, 4), fc, fm)
					end)
				end
			else
				if roll < 0.65 then
					m = piece("RotBlooms", x, z, rng:NextNumber(0, 360), "RotBloomCluster", rng:NextNumber(0.9, 1.4), BLOOM, function(cf)
						local cc, cm = sw(BLOOM, "CAP")
						lump("RotBloom", (cf * CFrame.new(0, 1.6, 0)).Position, V(3, 1, 3), cc, cm)
					end)
				else
					m = piece("BlightPods", x, z, rng:NextNumber(0, 360), "BlightPod", rng:NextNumber(0.6, 0.9), ROTTEN, function(cf)
						local gc, gm = sw(ROTTEN, "GLOW")
						lump("BlightPod", (cf * CFrame.new(0, 0.8, 0)).Position, V(1.6, 1.6, 1.6), gc, gm)
					end)
				end
			end
			noCollide(m)
			cover += 1
		end
	end

	ctx.setAttribute("Floor31Landmarks", landmarks)
	ctx.setAttribute("Floor31Props", props)
	ctx.setAttribute("Floor31GroundCover", cover)
end

return table.freeze(CorruptedGrove)
