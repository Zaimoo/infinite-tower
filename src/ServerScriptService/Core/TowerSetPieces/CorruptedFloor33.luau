--!strict
-- Hand-authored set pieces for Corrupted Grove Floor 33: Briar Labyrinth (corrupted:3).
-- Guide image: reference/Corrupted Grove 33.jpg. Design: docs/prompts/corrupted-grove-floor-layouts-prompt.md.
--
-- The hedge-maze the Hollin wardens planted over a sunken thorn pit (Bottom = -6) to wall in the Thornheart.
-- Thornheart Court (Apex, Y 44) stands in the centre of the room, visible over the low (<= 8.1 stud) hedges
-- from arrival, with the Briar Gate (Crossing, Y 8) sealed shut directly in front of it. The true west path
-- carries Pale Bands (Mender's Croft -> West Walk -> Nettle Turn -> Hanging Garden -> Garden Stair, or around
-- the outer ring via Briar Cloister -> North Hedge Gate -> Gibbet Thicket -> East Rosary -> Thornheart Steps);
-- the unbanded east path ends in the dead-end Thornwrack. On the far north horizon, the Mother Graft appears
-- for the first time.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local CorruptedFloor33 = {}

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

-- Crisp thorn-shadow noon labyrinth palette: deep hawthorn-green hedges, bruised violet-black briars,
-- mossy cool-lavender fieldstone, warm cottage thatch, electric violet-magenta heartrot (hue ~300°,
-- clearly distinct from crimson/red enemy telegraphs).
local LABYRINTH = table.freeze({
	WOOD = swatch(52, 30, 62, Mat.Wood), -- gnarled black-violet briar & weathered timber
	TRIM = swatch(184, 166, 152, Mat.Wood), -- pale bone, daub, carved signboards & Pale Band stakes
	ALT = swatch(186, 148, 86, Mat.Fabric), -- golden croft thatch, wicker baskets & scarecrow straw
	FOLIAGE = swatch(54, 72, 64, Mat.Grass), -- deep blighted hawthorn & topiary foliage
	CORAL = swatch(224, 118, 206, Mat.Grass), -- hanging garden & briar gate blossoms
	CAP = swatch(166, 38, 148, Mat.SmoothPlastic), -- shield-sized magenta-violet rot-roses & briar blooms
	ACCENT = swatch(232, 214, 242, Mat.Grass),
	MOSS = swatch(68, 78, 70, Mat.Grass), -- blighted olive-violet moss on stone plinths & wellhead
	SILK = swatch(228, 184, 214, Mat.Fabric), -- Pale Bands marking ONLY the true west path
	STONE = swatch(96, 82, 118, Mat.Slate), -- cool violet-tinted mossy fieldstone
	METAL = swatch(56, 48, 66, Mat.Metal), -- forged gibbet cage iron
	GLOW = swatch(232, 68, 250, Mat.Neon), -- blazing violet-magenta heartrot & thorn veins
	CANDLE = swatch(255, 198, 124, Mat.Neon), -- warm cottage window & scarecrow sap-lantern
	STEM = swatch(56, 36, 64, Mat.Wood),
	BULB = swatch(226, 78, 246, Mat.Neon),
})

local CROFT_TINT = tinted(LABYRINTH, {
	WOOD = swatch(78, 56, 48, Mat.Wood),
	TRIM = swatch(216, 202, 178, Mat.SmoothPlastic), -- warm limewashed daub
	GLOW = swatch(255, 186, 108, Mat.Neon), -- warm cottage hearth window & lantern
})

local THORNHEART_TINT = tinted(LABYRINTH, {
	WOOD = swatch(42, 24, 48, Mat.Wood),
	CAP = swatch(138, 28, 134, Mat.SmoothPlastic),
	GLOW = swatch(242, 74, 255, Mat.Neon),
	MOSS = swatch(62, 48, 72, Mat.Grass),
	STONE = swatch(74, 62, 86, Mat.Slate),
})

local ROSE_TINT = tinted(LABYRINTH, {
	CAP = swatch(196, 38, 142, Mat.SmoothPlastic), -- rich overripe magenta-rose petals
	GLOW = swatch(246, 92, 238, Mat.Neon),
	FOLIAGE = swatch(56, 78, 52, Mat.Grass),
})

local PIT_TINT = tinted(LABYRINTH, {
	WOOD = swatch(44, 28, 50, Mat.Wood),
	FOLIAGE = swatch(58, 74, 54, Mat.Grass),
	TRIM = swatch(204, 196, 184, Mat.SmoothPlastic), -- bleached ossuary bones in the pit
})

local WRACK_TINT = tinted(PIT_TINT, {
	SILK = swatch(198, 92, 138, Mat.Fabric), -- torn rot-soaked Pale Band in the warden's hand
})

local LAMP_TINT = tinted(LABYRINTH, {
	GLOW = swatch(255, 188, 112, Mat.Neon),
})

local ROT_LIGHT = rgb(228, 72, 250)
local LAMP_LIGHT = rgb(255, 186, 114)

-- Floor 33's landmark footprints (local floor space, scaled), checked offline by the specs against every
-- walkway lane, camp (34-stud clearance) and boss portal, and reserved so clutter passes keep off them.
CorruptedFloor33.Landmarks = table.freeze({
	{ Id = "ThornheartKnot", X = 0, Z = -166, Y = 20, HalfX = 49.0, HalfZ = 53.0, Top = 154.0 },
	{ Id = "BriarGatehouse", X = 0, Z = 38, Y = 8, HalfX = 17.0, HalfZ = 5.6, Top = 28.0 },
	{ Id = "MendersCroft", X = -152, Z = 148, Y = 0, HalfX = 11.2, HalfZ = 7.4, Top = 17.4 },
	{ Id = "MendersBench", X = -126, Z = 152, Y = 0, HalfX = 7.3, HalfZ = 3.2, Top = 7.8 },
	{ Id = "MendersScarecrow", X = -102, Z = 156, Y = 0, HalfX = 4.8, HalfZ = 2.4, Top = 11.8 },
	{ Id = "ThornwrackSkeleton", X = 264, Z = -68, Y = 22, HalfX = 9.5, HalfZ = 9.5, Top = 8.6 },
	{ Id = "HangingGardenPergola", X = -152, Z = 2, Y = 26, HalfX = 12.4, HalfZ = 4.2, Top = 14.5 },
	{ Id = "NettleSignpost", X = -274, Z = -130, Y = 20, HalfX = 5.0, HalfZ = 3.0, Top = 13.5 },
	{ Id = "CloisterWellhead", X = -176, Z = -274, Y = 24, HalfX = 4.8, HalfZ = 4.8, Top = 13.6 },
	{ Id = "NorthGateArch", X = 0, Z = -291, Y = 28, HalfX = 18.2, HalfZ = 5.4, Top = 25.4 },
	{ Id = "GibbetTreeA", X = 170, Z = -282, Y = 32, HalfX = 8.8, HalfZ = 5.0, Top = 29.2 },
	{ Id = "GibbetTreeB", X = 198, Z = -256, Y = 32, HalfX = 5.0, HalfZ = 8.8, Top = 29.2 },
	{ Id = "GibbetTreeC", X = 126, Z = -282, Y = 32, HalfX = 8.8, HalfZ = 5.0, Top = 29.2 },
	{ Id = "EastRosaryA", X = 210, Z = -118, Y = 36, HalfX = 9.5, HalfZ = 6.6, Top = 15.3 },
	{ Id = "EastRosaryB", X = 204, Z = -148, Y = 36, HalfX = 9.5, HalfZ = 6.6, Top = 15.3 },
	{ Id = "EastRosaryC", X = 204, Z = -88, Y = 36, HalfX = 9.5, HalfZ = 6.6, Top = 15.3 },
	{ Id = "PitTopiaryKnot", X = 0, Z = 4, Y = -10, HalfX = 9.8, HalfZ = 8.5, Top = 19.8 },
	{ Id = "PitTopiaryStag", X = -58, Z = 8, Y = -10, HalfX = 7.6, HalfZ = 4.0, Top = 19.8 },
	{ Id = "MotherGraftHorizon", X = 0, Z = -328, Y = 42, HalfX = 32.0, HalfZ = 28.0, Top = 148.0 },
}) :: { Landmark }

function CorruptedFloor33.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number, P = H.field, H.bottom, H.d, H.P
	local w: number = ctx.w
	local layout = ctx.layout
	local surfaceAt, boxAt, lump, light, piece, noCollide, plume =
		H.surfaceAt, H.boxAt, H.lump, H.light, H.piece, H.noCollide, H.plume
	local origin: Vector3 = ctx.origin

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
	local rng = Random.new(33 * 7927)

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 18 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end

	for _, lm in CorruptedFloor33.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	local taken: { { number } } = {}
	for _, lm in CorruptedFloor33.Landmarks do
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
	local function walkableSlope(x: number, z: number): boolean
		return not field or field.Slope(x, z) < 0.85
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

	local function fallbackHedge(len: number): (CFrame) -> ()
		return function(cf: CFrame)
			local fc, fm = sw(LABYRINTH, "FOLIAGE")
			local cc, cm = sw(LABYRINTH, "CAP")
			boxAt("HedgeBody", V(len, 6.8, 3.8), cf * CFrame.new(0, 3.4, 0), fc, fm)
			lump("HedgeBriar", (cf * CFrame.new(0, 5.4, 0)).Position, V(len * 0.6, 2.2, 4.4), cc, cm)
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 1. The Thornheart (rising from its rocky pit mound behind Thornheart Court, ~154 studs tall!):
	--    house-sized knot of black briar coiled around a split elder trunk with a blazing magenta cavity.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor33.Landmarks[1]
		local baseY = lm.Y :: number
		local made = piece("ThornheartKnot", lm.X, lm.Z, 0, "ThornheartKnot", 1.1, THORNHEART_TINT, function(cf)
			local wc, wm = sw(THORNHEART_TINT, "WOOD")
			local gc, gm = sw(THORNHEART_TINT, "GLOW")
			for _, s in { -1, 1 } do
				rod("ThornheartHalf", (cf * CFrame.new(s * 6, 0, 4)).Position, (cf * CFrame.new(s * 18, 120, 8)).Position, 9, wc, wm)
			end
			for k = 0, 7 do
				local a = k * math.pi / 4
				rod("ThornSpear", (cf * CFrame.new(math.cos(a) * 14, 10, math.sin(a) * 14)).Position, (cf * CFrame.new(math.cos(a) * 38, 148, math.sin(a) * 38)).Position, 2.8, wc, wm)
			end
			local heart = lump("ThornheartCore", (cf * CFrame.new(0, 48, 4)).Position, V(16, 30, 10), gc, gm)
			addLight(heart, ROT_LIGHT, 2.0, 75)
		end, baseY)
		pin(made)
		if made and ctx.has("ThornheartKnot") then
			addLight(H.glowOf(made), ROT_LIGHT, 2.0, 75)
		end
		ctx.group("ThornheartSpores", function()
			plume(V(lm.X, baseY + 58, lm.Z + 8), rgb(232, 92, 248), 5.5, 8, 6, 4.5)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 2. The Briar Gate (north lip of Crossing at 0, 8, 38): pleached hawthorn gatehouse grown shut
	--    toward Thornheart Court so the gap across the pit reads clearly as impassable.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor33.Landmarks[2]
		local made = piece("BriarGatehouse", lm.X, lm.Z, 0, "BriarGatehouse", 1.0, LABYRINTH, function(cf)
			local wc, wm = sw(LABYRINTH, "WOOD")
			local fc, fm = sw(LABYRINTH, "FOLIAGE")
			local gc, gm = sw(LABYRINTH, "GLOW")
			boxAt("BriarDoorShut", V(26, 16, 2), cf * CFrame.new(0, 8, 0), wc, wm)
			lump("BriarGateCrown", (cf * CFrame.new(0, 21, 0)).Position, V(32, 8, 9), fc, fm)
			local seam = boxAt("BriarDoorSeam", V(1.6, 14, 2.4), cf * CFrame.new(0, 8, 0), gc, gm)
			addLight(seam, ROT_LIGHT, 1.3, 40)
		end, lm.Y)
		pin(made)
		if made and ctx.has("BriarGatehouse") then
			addLight(H.glowOf(made), ROT_LIGHT, 1.3, 40)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 3. The Mender's Croft (south-west terrace -100, 4, 118): wattle-and-daub cottage, grafting bench,
	--    stitched-bark scarecrow with glowing sap-lantern, and wattle yard fence.
	---------------------------------------------------------------------------------------------------
	do
		local croft, bench, scare = CorruptedFloor33.Landmarks[3], CorruptedFloor33.Landmarks[4], CorruptedFloor33.Landmarks[5]
		local mc = piece("MendersCroft", croft.X, croft.Z, 18, "WattleCroft", 1.0, CROFT_TINT, function(cf)
			local wc, wm = sw(CROFT_TINT, "WOOD")
			local ac, am = sw(CROFT_TINT, "ALT")
			local tc, tm = sw(CROFT_TINT, "TRIM")
			local gc, gm = sw(CROFT_TINT, "GLOW")
			boxAt("CroftWalls", V(16, 8, 11), cf * CFrame.new(0, 5, 0), tc, tm)
			boxAt("CroftRoof", V(20, 4, 14), cf * CFrame.new(0, 11, 0), ac, am)
			boxAt("CroftChimney", V(3.4, 16, 3.8), cf * CFrame.new(-9, 8, 0), wc, wm)
			local win = boxAt("CroftWin", V(2.6, 2.2, 0.5), cf * CFrame.new(3.8, 6.4, 5.6), gc, gm)
			addLight(win, LAMP_LIGHT, 1.2, 34)
		end, croft.Y)
		pin(mc)
		if mc and ctx.has("WattleCroft") then
			addLight(H.glowOf(mc), LAMP_LIGHT, 1.2, 34)
		end
		local mb = piece("MendersBench", bench.X, bench.Z, 16, "GraftingBench", 1.0, CROFT_TINT, function(cf)
			local wc, wm = sw(CROFT_TINT, "WOOD")
			boxAt("CroftBench", V(10, 3.6, 4), cf * CFrame.new(0, 1.8, 0), wc, wm)
		end, bench.Y)
		pin(mb)
		local ms = piece("MendersScarecrow", scare.X, scare.Z, -18, "ScarecrowProp", 1.0, CROFT_TINT, function(cf)
			local wc, wm = sw(CROFT_TINT, "WOOD")
			local sc, sm = sw(CROFT_TINT, "SILK")
			local gc, gm = sw(CROFT_TINT, "GLOW")
			boxAt("ScarePost", V(0.7, 9, 0.7), cf * CFrame.new(0, 4.5, 0), wc, wm)
			boxAt("ScareCoat", V(2.4, 4.4, 1.4), cf * CFrame.new(0, 5.2, 0), sc, sm)
			local lamp = lump("ScareLantern", (cf * CFrame.new(3.2, 4.6, 0)).Position, V(1.1, 1.4, 1.1), gc, gm)
			addLight(lamp, LAMP_LIGHT, 1.0, 26)
		end, scare.Y)
		pin(ms)
		if ms and ctx.has("ScarecrowProp") then
			addLight(H.glowOf(ms), LAMP_LIGHT, 1.0, 26)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 4. Thornwrack (false east dead-end deck at 255, 22, -60): woven briar nest holding the fallen
	--    warden's skeleton clutching a torn Pale Band (unbanded approach!).
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor33.Landmarks[6]
		local m = piece("ThornwrackSkeleton", lm.X, lm.Z, -35, "WardenSkeleton", 1.2, WRACK_TINT, function(cf)
			local wc, wm = sw(WRACK_TINT, "WOOD")
			local tc, tm = sw(WRACK_TINT, "TRIM")
			local sc, sm = sw(WRACK_TINT, "SILK")
			ctx.cyl("WrackNest", (cf * CFrame.new(0, 2.5, 0)).Position, 8.5, 5, wc, wm)
			lump("WardenBones", (cf * CFrame.new(0, 3.2, 0)).Position, V(4, 2.5, 3), tc, tm)
			boxAt("TornBand", V(3.5, 0.6, 2), cf * CFrame.new(-3, 2.2, 2), sc, sm)
		end, lm.Y)
		pin(m)
		noCollide(m)
		-- Timber stilts under the Thornwrack deck down into the pit.
		ctx.group("ThornwrackStilts", function()
			local wc, wm = sw(PIT_TINT, "WOOD")
			local tw = P.Thornwrack
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local px, pz = tw.X + sx * (tw.Width / 2 - 4), tw.Z + sz * (tw.Depth / 2 - 4)
					local gy = if field then field.Height(px, pz) - 1 else bottom
					if tw.Y - gy > 2 then
						noCollide(rod("WrackStilt", V(px, gy, pz), V(px, tw.Y - 0.5, pz), 1.3, wc, wm))
					end
				end
			end
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 5. The Hanging Garden (stilt deck at -150, 26, -30): flowering hanging-planter pergola + stilts.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor33.Landmarks[7]
		local m = piece("HangingGardenPergola", lm.X, lm.Z, 0, "HangingPlanterPergola", 1.0, LABYRINTH, function(cf)
			local wc, wm = sw(LABYRINTH, "WOOD")
			local cc, cm = sw(LABYRINTH, "CORAL")
			for _, x in { -10, 0, 10 } do
				boxAt("PergolaPost", V(0.9, 11.5, 0.9), cf * CFrame.new(x, 5.7, 0), wc, wm)
			end
			boxAt("PergolaBeam", V(24, 1, 7), cf * CFrame.new(0, 11.6, 0), wc, wm)
			lump("PergolaVine", (cf * CFrame.new(0, 12.8, 0)).Position, V(22, 3, 7), cc, cm)
		end, lm.Y)
		pin(m)
		noCollide(m)
		if m and ctx.has("HangingPlanterPergola") then
			addLight(H.glowOf(m), ROT_LIGHT, 1.0, 30)
		end
		ctx.group("HangingGardenStilts", function()
			local wc, wm = sw(LABYRINTH, "WOOD")
			local hg = P.HangingGarden
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local px, pz = hg.X + sx * (hg.Width / 2 - 4), hg.Z + sz * (hg.Depth / 2 - 4)
					local gy = if field then field.Height(px, pz) - 1 else bottom
					if hg.Y - gy > 2 then
						noCollide(rod("GardenStilt", V(px, gy, pz), V(px, hg.Y - 0.5, pz), 1.3, wc, wm))
					end
				end
			end
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 6. Nettle Turn (-235, 20, -130): three-arm banded signpost (one arm hacked off) + nettle beds.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor33.Landmarks[8]
		local m = piece("NettleSignpost", lm.X, lm.Z, 75, "ThreeArmSignpost", 1.25, LABYRINTH, function(cf)
			local wc, wm = sw(LABYRINTH, "WOOD")
			local tc, tm = sw(LABYRINTH, "TRIM")
			boxAt("SignShaft", V(1.2, 12, 1.2), cf * CFrame.new(0, 6, 0), wc, wm)
			boxAt("SignArm", V(6, 1.2, 0.4), cf * CFrame.new(2, 9.5, 0), tc, tm)
		end, lm.Y)
		pin(m)
		noCollide(m)
		for idx, off in { { -262, -110 }, { -266, -152 }, { -214, -156 } } do
			if free(off[1], off[2], 3.5) then
				take(off[1], off[2], 3.5)
				noCollide(piece("NettleBed", off[1], off[2], idx * 51, "FernCluster", 1.4, LABYRINTH, function(cf)
					local fc, fm = sw(LABYRINTH, "FOLIAGE")
					lump("Nettles", (cf * CFrame.new(0, 1.4, 0)).Position, V(6, 2.8, 6), fc, fm)
				end))
				props += 1
			end
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 7. Briar Cloister (-150, 24, -255): mossy dry fieldstone wellhead framed by cloister hedges.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor33.Landmarks[9]
		local m = piece("CloisterWellhead", lm.X, lm.Z, 20, "FieldstoneWellhead", 1.15, LABYRINTH, function(cf)
			local sc, sm = sw(LABYRINTH, "STONE")
			local ac, am = sw(LABYRINTH, "ALT")
			ctx.cyl("WellRim", (cf * CFrame.new(0, 2, 0)).Position, 3.8, 4, sc, sm)
			boxAt("WellHood", V(8, 2.5, 6), cf * CFrame.new(0, 10, 0), ac, am)
		end, lm.Y)
		pin(m)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 8. North Hedge Gate (0, 28, -235): tall tangled briar arch behind the Court framing the Thornheart
	--    and the Mother Graft silhouette on the north horizon.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor33.Landmarks[10]
		local m = piece("NorthGateArch", lm.X, lm.Z, 0, "ThornBrambleArch", 1.0, LABYRINTH, function(cf)
			local wc, wm = sw(LABYRINTH, "WOOD")
			local fc, fm = sw(LABYRINTH, "FOLIAGE")
			for _, s in { -1, 1 } do
				rod("NorthGateLeg", (cf * CFrame.new(s * 15, 0, 0)).Position, (cf * CFrame.new(0, 23, 0)).Position, 1.6, wc, wm)
			end
			lump("NorthGateCrown", (cf * CFrame.new(0, 22, 0)).Position, V(24, 6, 8), fc, fm)
		end, lm.Y)
		pin(m)
		if m and ctx.has("ThornBrambleArch") then
			addLight(H.glowOf(m), ROT_LIGHT, 1.0, 32)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 9. Gibbet Thicket (150, 32, -250): dead gnarled trees hung with empty iron-and-wicker gibbet cages.
	---------------------------------------------------------------------------------------------------
	do
		for idx, pair in { { CorruptedFloor33.Landmarks[11], 12 }, { CorruptedFloor33.Landmarks[12], -78 }, { CorruptedFloor33.Landmarks[13], 24 } } do
			local lm = pair[1] :: Landmark
			local m = piece(lm.Id, lm.X, lm.Z, pair[2] :: number, "GibbetCage", 1.0, PIT_TINT, function(cf)
				local wc, wm = sw(PIT_TINT, "WOOD")
				local mc, mm = sw(PIT_TINT, "METAL")
				rod("GibbetTrunk", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 24, 0)).Position, 1.8, wc, wm)
				rod("GibbetArm", (cf * CFrame.new(-7, 23, 0)).Position, (cf * CFrame.new(7, 22, 0)).Position, 0.8, wc, wm)
				ctx.cyl("GibbetBasket", (cf * CFrame.new(-7, 16, 0)).Position, 1.4, 4.4, mc, mm)
			end, lm.Y)
			pin(m)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 10. East Rosary (170, 36, -120): ruined mossy stone garden arches overgrown with shield-sized
	--     glowing magenta rot-roses.
	---------------------------------------------------------------------------------------------------
	do
		for idx, lm in { CorruptedFloor33.Landmarks[14], CorruptedFloor33.Landmarks[15], CorruptedFloor33.Landmarks[16] } do
			local m = piece(lm.Id, lm.X, lm.Z, -90 + (idx - 2) * 18, "RotRoseBush", 1.0, ROSE_TINT, function(cf)
				local sc, sm = sw(ROSE_TINT, "STONE")
				local cc, cm = sw(ROSE_TINT, "CAP")
				boxAt("RosaryArch", V(11, 10, 2.5), cf * CFrame.new(0, 5, 0), sc, sm)
				local r = lump("GiantRotRose", (cf * CFrame.new(0, 9, 2)).Position, V(5, 4.5, 4), cc, cm)
				if idx == 1 then addLight(r, ROT_LIGHT, 1.1, 32) end
			end, lm.Y)
			pin(m)
			if idx == 1 and m and ctx.has("RotRoseBush") then
				addLight(H.glowOf(m), ROT_LIGHT, 1.1, 32)
			end
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 11. Central Thorn Pit Topiary Ruins & Snapped Bridges (between Briar Gate and Thornheart Court):
	--     clipped hedge graft-knot & stag on stone plinths + severed wooden bridge stubs.
	---------------------------------------------------------------------------------------------------
	do
		local knot, stag = CorruptedFloor33.Landmarks[17], CorruptedFloor33.Landmarks[18]
		local mk = piece("PitTopiaryKnot", knot.X, knot.Z, 0, "TopiaryGraftKnot", 1.45, LABYRINTH, function(cf)
			local sc, sm = sw(LABYRINTH, "STONE")
			local fc, fm = sw(LABYRINTH, "FOLIAGE")
			ctx.cyl("TopiaryPlinth", (cf * CFrame.new(0, 2, 0)).Position, 7, 4, sc, sm)
			lump("TopiaryKnot", (cf * CFrame.new(0, 10, 0)).Position, V(14, 12, 6), fc, fm)
		end, knot.Y)
		pin(mk)
		if mk and ctx.has("TopiaryGraftKnot") then
			addLight(H.glowOf(mk), ROT_LIGHT, 1.0, 32)
		end

		local ms = piece("PitTopiaryStag", stag.X, stag.Z, 24, "TopiaryStag", 1.35, LABYRINTH, function(cf)
			local sc, sm = sw(LABYRINTH, "STONE")
			local fc, fm = sw(LABYRINTH, "FOLIAGE")
			boxAt("StagPlinth", V(12, 4, 7), cf * CFrame.new(0, 2, 0), sc, sm)
			lump("StagBody", (cf * CFrame.new(0, 10, 0)).Position, V(10, 6, 4.5), fc, fm)
		end, stag.Y)
		pin(ms)

		-- Two clearly snapped wooden bridge stubs ending uselessly inside the thorn pit.
		ctx.group("PitSnappedBridges", function()
			local wc, wm = sw(PIT_TINT, "WOOD")
			for _, stub in { { -32, 16, 18 }, { 42, 12, -24 } } do
				local cf = CFrame.new(stub[1], bottom + 3.2, stub[2]) * CFrame.Angles(0, math.rad(stub[3]), math.rad(14))
				noCollide(boxAt("SnappedBridgeDeck", V(14, 1.1, 6.5), cf, wc, wm))
				noCollide(rod("SnappedBridgePost", V(stub[1] - 4, bottom, stub[2]), V(stub[1] - 4, bottom + 5, stub[2]), 0.55, wc, wm))
			end
		end)

		-- Corrupted cliff briar-veins & glowing magenta fissures crawling up the sheer basalt banks of
		-- Thornheart Court, the Briar Gate and the Thornheart mound, plus glowing pit-floor fissures.
		-- Each vein is its own small group so PropClearance evaluates every strand independently.
		local vc, vm = sw(THORNHEART_TINT, "WOOD")
		local gc, gm = sw(THORNHEART_TINT, "GLOW")
		local apex = P.Apex
		for k = 0, 15 do
			local ang = math.rad(-165 + k * 21)
			local rx, rz = math.cos(ang), math.sin(ang)
			local xTop = apex.X + rx * (apex.Width * 0.5 + 3.5)
			local zTop = apex.Z + rz * (apex.Depth * 0.5 + 3.5)
			local xMid = apex.X + rx * (apex.Width * 0.5 + 16)
			local zMid = apex.Z + rz * (apex.Depth * 0.5 + 16)
			local xBot = apex.X + rx * (apex.Width * 0.5 + 29)
			local zBot = apex.Z + rz * (apex.Depth * 0.5 + 29)
			local yBot = field.Height(xBot, zBot)
			local yMid = math.max(field.Height(xMid, zMid), (yBot + apex.Y) * 0.5)
			local yTop = apex.Y - 1.8
			local sway = ((k % 2) * 2 - 1) * 5.2
			local p0 = V(xBot, yBot, zBot)
			local p1 = V(xMid - rz * sway, yMid, zMid + rx * sway)
			local p2 = V(xTop, yTop, zTop)
			ctx.group("ApexBlightVein", function()
				pin(noCollide(rod("ApexBriarRootA", p0, p1, 1.45, vc, vm)))
				pin(noCollide(rod("ApexBriarRootB", p1, p2, 1.05, vc, vm)))
				pin(noCollide(rod("ApexBlightGlowA", p0 + V(0, 0.9, 0), p1 + V(0, 0.8, 0), 0.52, gc, gm)))
				pin(noCollide(rod("ApexBlightGlowB", p1 + V(0, 0.8, 0), p2 + V(0, 0.5, 0), 0.38, gc, gm)))
			end)
		end
		-- Glowing magenta fissures snaking across the sunken thorn pit floor & pit crags.
		local pitVeins = {
			{ { -18, 26 }, { -4, 4 }, { 14, -14 } },
			{ { -66, 20 }, { -44, 2 }, { -22, -16 } },
			{ { 62, 22 }, { 38, 2 }, { 18, -16 } },
			{ { -108, -140 }, { -78, -124 }, { -44, -142 } },
			{ { 108, -152 }, { 74, -138 }, { 42, -154 } },
			{ { -42, -172 }, { -12, -166 }, { 26, -170 } },
			{ { -100, 16 }, { -78, 32 }, { -54, 24 } },
			{ { 102, 58 }, { 78, 42 }, { 52, 46 } },
			{ { -42, 108 }, { -18, 128 } },
			{ { 44, 110 }, { 22, 130 } },
		}
		for _, chain in pitVeins do
			for i = 1, #chain - 1 do
				local a2, b2 = chain[i], chain[i + 1]
				local ya, yb = field.Height(a2[1], a2[2]) + 0.7, field.Height(b2[1], b2[2]) + 0.7
				ctx.group("PitBlightVein", function()
					pin(noCollide(rod("PitBlightGlow", V(a2[1], ya, a2[2]), V(b2[1], yb, b2[2]), 0.68, gc, gm)))
					pin(noCollide(rod("PitBriarRidge", V(a2[1] + 1.5, ya + 0.3, a2[2] - 1.2), V(b2[1] + 1.5, yb + 0.3, b2[2] - 1.2), 1.15, vc, vm)))
				end)
			end
		end
		-- Foreground corrupted dressing framing Briar Lawn outside the two Basin camps and causeway.
		local lawnTrees = {
			{ -46, 226, "BlightTree", 1.05 }, { 48, 224, "BlightTree", 1.12 },
			{ -54, 178, "DeadTree", 0.95 }, { 54, 176, "DeadTree", 1.02 },
			{ -186, 222, "BlightTree", 1.18 }, { 184, 220, "BlightTree", 1.15 },
			{ -228, 186, "DeadTree", 1.10 }, { 226, 188, "DeadTree", 1.08 },
			{ -280, 224, "BlightTree", 1.25 }, { 282, 222, "BlightTree", 1.22 },
		}
		for _, tr in lawnTrees do
			if free(tr[1], tr[2], 7) then
				local m = piece("LawnBlightTree", tr[1], tr[2], rng:NextNumber(0, 360), tr[3], tr[4], THORNHEART_TINT, function(cf)
					rod("LawnTreeTrunk", cf.Position, cf.Position + V(0, 22, 0), 1.6, vc, vm)
				end, field.Height(tr[1], tr[2]) - 1.2)
				pin(m)
				take(tr[1], tr[2], 7)
				props += 1
			end
		end
		local lawnRocks = {
			{ -34, 212, 0.9 }, { 36, 206, 0.95 }, { -42, 166, 0.85 }, { 44, 164, 0.9 },
			{ -172, 180, 1.05 }, { 174, 178, 1.1 }, { -214, 232, 1.0 }, { 216, 230, 1.0 },
		}
		for _, rk in lawnRocks do
			if free(rk[1], rk[2], 5) then
				local m = piece("LawnBlightRock", rk[1], rk[2], rng:NextNumber(0, 360), "CliffRockA", rk[3], THORNHEART_TINT, function(cf)
					lump("BlightBoulder", cf.Position + V(0, 2.2, 0), V(8, 5, 7), sw(THORNHEART_TINT, "STONE"))
				end, field.Height(rk[1], rk[2]) - 0.8)
				pin(m)
				take(rk[1], rk[2], 5)
				props += 1
			end
		end
		landmarks += 2
	end

	---------------------------------------------------------------------------------------------------
	-- 12. The Hedge Stile (arrival at Sanctuary exit, 0, 8, 301) + flanking maze hedges + lanterns.
	---------------------------------------------------------------------------------------------------
	do
		local safe = P.Sanctuary
		local z = safe.Z - safe.Depth / 2 + 3
		local stile = piece("HollinStile", 0, z, 0, "HollinStileArch", 1.0, LABYRINTH, function(cf)
			local wc, wm = sw(LABYRINTH, "WOOD")
			for _, s in { -1, 1 } do
				rod("StilePost", (cf * CFrame.new(s * 21.5, 0, 0)).Position, (cf * CFrame.new(s * 21.5, 18, 0)).Position, 1.2, wc, wm)
			end
			boxAt("StileArch", V(44, 2.2, 2.2), cf * CFrame.new(0, 20, 0), wc, wm)
		end, safe.Y)
		pin(stile)
		noCollide(stile)
		for _, x in { -54, -34, 34, 54 } do
			local hw = piece("StileHedge", x, z, 0, "HedgeWallStraight", 1.0, LABYRINTH, fallbackHedge(18), safe.Y)
			pin(hw)
			props += 1
		end
		-- Arrival lanterns on the stile posts.
		local lanternH = piece("HedgeStileLantern", 23, z - 1.5, 0, "HangingLantern", 1.0, LAMP_TINT, function(cf)
			local gc, gm = sw(LAMP_TINT, "GLOW")
			local g = boxAt("StileGlow", V(1.6, 2.2, 1.6), cf * CFrame.new(0, 2, 0), gc, gm)
			addLight(g, LAMP_LIGHT, 1.2, 32)
		end, safe.Y + 11)
		noCollide(lanternH)
		if lanternH and ctx.has("HangingLantern") then
			addLight(H.glowOf(lanternH), LAMP_LIGHT, 1.2, 32)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 13. Far North Horizon: the Mother Graft's colossal dead silhouette glowing faintly magenta
	--     for the first time in the biome, plus the surrounding hedge-top & dead-tree skyline.
	---------------------------------------------------------------------------------------------------
	do
		local mg = CorruptedFloor33.Landmarks[19]
		local m = piece("MotherGraftHorizon", mg.X, mg.Z, 0, "HeartrotSpringTrunk", 1.65, THORNHEART_TINT, function(cf)
			local wc, wm = sw(THORNHEART_TINT, "WOOD")
			local gc, gm = sw(THORNHEART_TINT, "GLOW")
			rod("MotherGraftBole", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 140, 0)).Position, 14, wc, wm)
			for _, s in { -1, 1 } do
				rod("MotherGraftArm", (cf * CFrame.new(0, 88, 0)).Position, (cf * CFrame.new(s * 54, 136, 0)).Position, 5.5, wc, wm)
			end
			local cavity = lump("MotherGraftGlow", (cf * CFrame.new(0, 22, 10)).Position, V(14, 24, 8), gc, gm)
			addLight(cavity, ROT_LIGHT, 1.6, 70)
		end, mg.Y)
		pin(m)
		if m and ctx.has("HeartrotSpringTrunk") then
			addLight(H.glowOf(m), ROT_LIGHT, 1.6, 70)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 14. Maze Hedge Walls ringing terrace edges (strictly <= 8.1 studs high, off every lane and camp!)
	--     plus Band-Tied Wayfinding Posts ONLY on the true west path (none on the false east path).
	---------------------------------------------------------------------------------------------------
	local hedgeTemplates = { "HedgeWallStraight", "HedgeWallBroken", "HedgeWallCorner" }
	local hedgeCount = 0
	for id, p in P do
		if id ~= "Sanctuary" and id ~= "Basin" and id ~= "Apex" then
			local hx, hz = p.Width / 2 - 2, p.Depth / 2 - 2
			local rimSpots = {
				{ p.X, p.Z - hz, 0 }, { p.X, p.Z + hz, 180 },
				{ p.X - hx, p.Z, 90 }, { p.X + hx, p.Z, -90 },
				{ p.X - hx + 6, p.Z - hz + 4, 35 }, { p.X + hx - 6, p.Z - hz + 4, -35 },
				{ p.X - hx + 6, p.Z + hz - 4, 145 }, { p.X + hx - 6, p.Z + hz - 4, -145 },
			}
			for idx, sp in rimSpots do
				if free(sp[1], sp[2], 6.5) then
					take(sp[1], sp[2], 6.5)
					local tpl = hedgeTemplates[((hedgeCount + idx) % 3) + 1]
					local m = piece("MazeHedge", sp[1], sp[2], sp[3], tpl, 0.85, LABYRINTH, fallbackHedge(16), p.Y)
					pin(m)
					noCollide(m)
					hedgeCount += 1
				end
			end
		end
	end
	-- Low hedges along the Briar Lawn north lip (framing the maze entrance & return ramps).
	for k = -13, 13 do
		if math.abs(k) >= 2 and math.abs(k) ~= 9 and math.abs(k) ~= 10 then
			local hx = k * 22
			local hz = 152
			if free(hx, hz, 6.5) then
				take(hx, hz, 6.5)
				local tpl = if k % 3 == 0 then "HedgeWallBroken" else "HedgeWallStraight"
				local m = piece("LawnMazeHedge", hx, hz, 0, tpl, 0.9, LABYRINTH, fallbackHedge(18), 0)
				pin(m)
				noCollide(m)
				hedgeCount += 1
			end
		end
	end
	props += hedgeCount
	landmarks += 1

	-- True-path vs false-path link dressing: every link on the true west path gets a banded GraftKnotPost!
	-- Links on the false east path (Crossing->EastGallery, EastGallery->Thornwrack) NEVER get Pale Bands.
	local falseLinks = { Crossing_EastGallery = true, EastGallery_Thornwrack = true }
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		local isFalse = falseLinks[link.Id] == true
		for _, endpoint in { { link.AX, link.AZ }, { link.BX, link.BZ } } do
			for _, side in { -1, 1 } do
				local x, z
				for _, reach in { 26, 32, 38 } do
					local tx, tz = endpoint[1] + nx * side * reach, endpoint[2] + nz * side * reach
					local _, onDeck = surfaceAt(tx, tz)
					if free(tx, tz, 3.2) and (onDeck or walkableSlope(tx, tz)) then
						x, z = tx, tz
						break
					end
				end
				if x and z then
					take(x, z, 3.2)
					local m
					if not isFalse and rng:NextNumber() < 0.55 then
						-- Banded wayfinding marker on the true west route!
						m = piece("TruePathBandPost", x, z, rng:NextNumber(0, 360), "GraftKnotPost", 1.0, LABYRINTH, function(cf)
							local wc, wm = sw(LABYRINTH, "WOOD")
							local sc, sm = sw(LABYRINTH, "SILK")
							boxAt("BandPost", V(1.4, 7.5, 1.4), cf * CFrame.new(0, 3.7, 0), wc, wm)
							boxAt("TrueBand", V(1.8, 1.1, 1.8), cf * CFrame.new(0, 5.0, 0), sc, sm)
						end)
					else
						local pick = rng:NextInteger(1, 3)
						if pick == 1 then
							m = piece("LinkThornKnot", x, z, rng:NextNumber(0, 360), "ThornKnotCluster", 0.55, PIT_TINT, function(cf)
								local wc, wm = sw(PIT_TINT, "WOOD")
								lump("ThornBush", (cf * CFrame.new(0, 1.5, 0)).Position, V(4, 3, 4), wc, wm)
							end)
						elseif pick == 2 then
							m = piece("LinkRotBloom", x, z, rng:NextNumber(0, 360), "RotBloomCluster", 1.35, ROSE_TINT, function(cf)
								local cc, cm = sw(ROSE_TINT, "CAP")
								lump("RotBloom", (cf * CFrame.new(0, 1.5, 0)).Position, V(3, 1.2, 3), cc, cm)
							end)
						else
							m = piece("LinkBoulder", x, z, rng:NextNumber(0, 360), "BoulderCluster", 0.7, LABYRINTH, function(cf)
								local sc, sm = sw(LABYRINTH, "STONE")
								lump("Stone", (cf * CFrame.new(0, 1, 0)).Position, V(4.5, 2.4, 4), sc, sm)
							end)
						end
					end
					noCollide(m)
					props += 1
				end
			end
		end
	end
	-- Return-ramp briar stairs dressing (out of the thorn pit onto Briar Lawn at X ~ +-252).
	for _, rl in layout.ReturnLinks or {} do
		for _, side in { -1, 1 } do
			local tx, tz = rl.AX + side * 22, rl.AZ
			if free(tx, tz, 3.5) then
				take(tx, tz, 3.5)
				noCollide(piece("ReturnRampMarker", tx, tz, 0, "GraftKnotPost", 1.0, LABYRINTH, function(cf)
					local wc, wm = sw(LABYRINTH, "WOOD")
					boxAt("ExitPost", V(1.5, 8, 1.5), cf * CFrame.new(0, 4, 0), wc, wm)
				end))
				props += 1
			end
		end
	end
	landmarks += 1

	---------------------------------------------------------------------------------------------------
	-- 15. Perimeter Skyline Treeline (at wallFoot so no roots hang on cliffs): dead & blighted trees
	--     and outer hedge walls encircling the labyrinth.
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
			if field and level(x, z, 6, 3.2) and level(x2, z2, 6, 3.2) and math.abs(field.Height(x, z) - field.Height(x2, z2)) < 4.5 then
				return at(inset + rng:NextNumber(0, 10))
			end
		end
		return nil, nil
	end
	do
		local rimMade = 0
		for _ = 1, 560 do
			if rimMade >= 52 then break end
			local side = rng:NextInteger(1, 4)
			local along = if side <= 2 then rng:NextNumber(-d / 2 + 34, d / 2 - 34) else rng:NextNumber(-w / 2 + 34, w / 2 - 34)
			local x, z = wallFoot(side, along)
			if not x or not z then continue end
			local _, onDeck = surfaceAt(x, z)
			if not onDeck and walkableSlope(x, z) and free(x, z, 7) then
				take(x, z, 7)
				local roll = rng:NextNumber()
				local tpl = if roll < 0.48 then "DeadTree" elseif roll < 0.82 then "BlightTree" else "GibbetCage"
				local s = rng:NextNumber(0.75, 1.15)
				piece("HorizonDeadTree", x, z, rng:NextNumber(0, 360), tpl, s, PIT_TINT, function(cf)
					local wc, wm = sw(PIT_TINT, "WOOD")
					rod("DeadTrunk", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 28, 0)).Position, 2.2, wc, wm)
				end)
				rimMade += 1
			end
		end
		props += rimMade
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 16. Sunken Thorn Pit Floor & Terrace Vignettes (>= 460 placed props, >= 28 distinct templates,
	--     strictly <= 12% per template so zero filler!): thorn knots, ossuary bones, mycelium webs,
	--     wattle fences, benches, urns, boulders, rot-blooms, blight pods, bushes and stumps.
	---------------------------------------------------------------------------------------------------
	type Clutter = { Name: string, Kit: string?, Scale: number, Tint: any, Fallback: (cf: CFrame) -> (), R: number }
	local mazeClutter: { Clutter } = {
		{ Name = "PitThornKnot", Kit = "ThornKnotCluster", Scale = 0.85, Tint = PIT_TINT, Fallback = function(cf) local wc, wm = sw(PIT_TINT, "WOOD"); lump("ThornKnot", (cf * CFrame.new(0, 1.6, 0)).Position, V(6, 3.2, 5.5), wc, wm) end, R = 4.6 },
		{ Name = "PitBones", Kit = "OssuaryBones", Scale = 0.72, Tint = PIT_TINT, Fallback = function(cf) local tc, tm = sw(PIT_TINT, "TRIM"); lump("Bones", (cf * CFrame.new(0, 0.9, 0)).Position, V(5, 1.8, 4.5), tc, tm) end, R = 4.2 },
		{ Name = "PitBriarWeb", Kit = "RotMyceliumWeb", Scale = 0.85, Tint = PIT_TINT, Fallback = function(cf) local gc, gm = sw(PIT_TINT, "GLOW"); lump("BriarWeb", (cf * CFrame.new(0, 0.4, 0)).Position, V(7, 0.8, 6), gc, gm) end, R = 4.8 },
		{ Name = "MazeBoulder", Kit = "BoulderCluster", Scale = 0.75, Tint = LABYRINTH, Fallback = function(cf) local sc, sm = sw(LABYRINTH, "STONE"); lump("Boulder", (cf * CFrame.new(0, 1.2, 0)).Position, V(5, 2.6, 4.5), sc, sm) end, R = 3.5 },
		{ Name = "MazeRubble", Kit = "RuinRubble", Scale = 0.75, Tint = LABYRINTH, Fallback = function(cf) local sc, sm = sw(LABYRINTH, "STONE"); lump("Rubble", (cf * CFrame.new(0, 1, 0)).Position, V(5, 2, 4.5), sc, sm) end, R = 3.5 },
		{ Name = "MazeUrn", Kit = "StoneUrn", Scale = 0.45, Tint = LABYRINTH, Fallback = function(cf) local sc, sm = sw(LABYRINTH, "STONE"); ctx.cyl("ChokedUrn", (cf * CFrame.new(0, 1.3, 0)).Position, 1.3, 2.6, sc, sm) end, R = 2.4 },
		{ Name = "MazeWattle", Kit = "WattleFence", Scale = 0.72, Tint = LABYRINTH, Fallback = function(cf) local wc, wm = sw(LABYRINTH, "WOOD"); boxAt("Wattle", V(10, 3.6, 0.6), cf * CFrame.new(0, 1.8, 0), wc, wm) end, R = 5.0 },
		{ Name = "MazeBench", Kit = "HollinBench", Scale = 0.88, Tint = LABYRINTH, Fallback = function(cf) local wc, wm = sw(LABYRINTH, "WOOD"); boxAt("Bench", V(8, 2.4, 2.6), cf * CFrame.new(0, 1.2, 0), wc, wm) end, R = 4.4 },
		{ Name = "MazeStumps", Kit = "SawnStumpCluster", Scale = 0.52, Tint = PIT_TINT, Fallback = function(cf) local wc, wm = sw(PIT_TINT, "WOOD"); ctx.cyl("Stump", (cf * CFrame.new(0, 1, 0)).Position, 2, 2, wc, wm) end, R = 3.6 },
		{ Name = "MazeNettles", Kit = "FernCluster", Scale = 1.25, Tint = LABYRINTH, Fallback = function(cf) local fc, fm = sw(LABYRINTH, "FOLIAGE"); lump("Nettles", (cf * CFrame.new(0, 1, 0)).Position, V(5, 2, 5), fc, fm) end, R = 3.2 },
		{ Name = "MazeBush", Kit = "FoliageBush", Scale = 0.85, Tint = LABYRINTH, Fallback = function(cf) local fc, fm = sw(LABYRINTH, "FOLIAGE"); lump("BriarBush", (cf * CFrame.new(0, 1.5, 0)).Position, V(5, 3, 4.5), fc, fm) end, R = 3.6 },
		{ Name = "MazeRotBloom", Kit = "RotBloomCluster", Scale = 1.4, Tint = ROSE_TINT, Fallback = function(cf) local cc, cm = sw(ROSE_TINT, "CAP"); lump("RotBloom", (cf * CFrame.new(0, 1.4, 0)).Position, V(3.2, 1.2, 3.2), cc, cm) end, R = 3.0 },
		{ Name = "MazeBlightPod", Kit = "BlightPod", Scale = 0.9, Tint = PIT_TINT, Fallback = function(cf) local gc, gm = sw(PIT_TINT, "GLOW"); lump("BlightPod", (cf * CFrame.new(0, 0.9, 0)).Position, V(2, 2, 2), gc, gm) end, R = 2.8 },
		{ Name = "MazeRotcap", Kit = "RotcapCluster", Scale = 0.72, Tint = PIT_TINT, Fallback = function(cf) local cc, cm = sw(PIT_TINT, "CAP"); lump("Rotcap", (cf * CFrame.new(0, 1.4, 0)).Position, V(4, 2.8, 4), cc, cm) end, R = 3.6 },
		{ Name = "MazeSignpost", Kit = "ThreeArmSignpost", Scale = 0.8, Tint = LABYRINTH, Fallback = function(cf) local wc, wm = sw(LABYRINTH, "WOOD"); boxAt("Post", V(1, 7, 1), cf * CFrame.new(0, 3.5, 0), wc, wm) end, R = 2.6 },
		{ Name = "MazeLadders", Kit = "CrutchPoleProp", Scale = 0.85, Tint = LABYRINTH, Fallback = function(cf) local tc, tm = sw(LABYRINTH, "TRIM"); boxAt("Ladder", V(1.6, 8, 0.5), cf * CFrame.new(0, 4, 0), tc, tm) end, R = 3.0 },
	}
	local cursor = 0
	local function vignette(cx: number, cz: number, spread: number, count: number, deckY: number?): number
		local made = 0
		for _ = 1, count * 6 do
			if made >= count then break end
			local a, rr = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, spread)
			local x, z = cx + math.cos(a) * rr, cz + math.sin(a) * rr
			cursor = (cursor % #mazeClutter) + 1
			local kind = mazeClutter[cursor]
			local gy, onDeck = surfaceAt(x, z)
			local okHeight = deckY == nil or (onDeck and math.abs(gy - deckY) < 0.5)
			if okHeight and (onDeck or walkableSlope(x, z)) and free(x, z, kind.R) then
				take(x, z, kind.R)
				local m = piece(kind.Name, x, z, rng:NextNumber(0, 360), kind.Kit, kind.Scale, kind.Tint, kind.Fallback, if onDeck then gy else nil)
				noCollide(m)
				made += 1
			end
		end
		return made
	end
	for id, p in P do
		if id ~= "Sanctuary" and id ~= "Basin" and id ~= "Apex" then
			for _, sx in { -1, 0, 1 } do
				for _, sz in { -1, 0, 1 } do
					if sx ~= 0 or sz ~= 0 then
						props += vignette(p.X + sx * (p.Width / 2 - 6), p.Z + sz * (p.Depth / 2 - 6), 8, 2, p.Y)
					end
				end
			end
		end
	end
	-- Briar Lawn edges + deep thorn pit floor (rich, dense pit clutter below the maze!).
	for k = 0, 19 do
		props += vignette(-296 + k * 31.1, 168 + (k % 2) * 58, 11, 4, 0)
	end
	for _ = 1, 115 do
		props += vignette(rng:NextNumber(-w / 2 + 26, w / 2 - 26), rng:NextNumber(-d / 2 + 34, 148), 18, 4)
	end
	-- Soft glowing spore drifts rising from the thorn pit floor.
	for _, sp in { { -64, -22 }, { 64, -22 }, { 0, 26 } } do
		ctx.group("PitSporeDrift", function()
			plume(V(sp[1], bottom + 2.5, sp[2]), rgb(212, 86, 236), 4.0, 4, 3.2, 4.0)
		end)
	end

	---------------------------------------------------------------------------------------------------
	-- 17. Ground cover (>= 320 target): dark grass tufts, rot-blooms, nettle ferns and blight pods.
	---------------------------------------------------------------------------------------------------
	for _ = 1, 2200 do
		if cover >= 450 then break end
		local x, z = rng:NextNumber(-w / 2 + 16, w / 2 - 16), rng:NextNumber(-d / 2 + 16, d / 2 - 42)
		local _, onDeck = surfaceAt(x, z)
		local r = 2.4
		if not onDeck and walkableSlope(x, z) and free(x, z, r) then
			take(x, z, r)
			local roll = rng:NextNumber()
			local m
			if roll < 0.35 then
				m = piece("MazeGrass", x, z, rng:NextNumber(0, 360), "AutumnGrassTuft", rng:NextNumber(1.0, 1.5), LABYRINTH, function(cf)
					local fc, fm = sw(LABYRINTH, "FOLIAGE")
					lump("GrassTuft", (cf * CFrame.new(0, 0.7, 0)).Position, V(2.4, 1.4, 2), fc, fm)
				end)
			elseif roll < 0.65 then
				m = piece("MazeWildbloom", x, z, rng:NextNumber(0, 360), "RotBloomCluster", rng:NextNumber(0.9, 1.4), ROSE_TINT, function(cf)
					local cc, cm = sw(ROSE_TINT, "CAP")
					lump("RotBloom", (cf * CFrame.new(0, 1.4, 0)).Position, V(2.8, 1, 2.8), cc, cm)
				end)
			elseif roll < 0.85 then
				m = piece("MazeFern", x, z, rng:NextNumber(0, 360), "FernCluster", rng:NextNumber(0.9, 1.35), LABYRINTH, function(cf)
					local fc, fm = sw(LABYRINTH, "FOLIAGE")
					lump("Fern", (cf * CFrame.new(0, 0.8, 0)).Position, V(3.8, 1.5, 3.8), fc, fm)
				end)
			else
				m = piece("MazePods", x, z, rng:NextNumber(0, 360), "BlightPod", rng:NextNumber(0.55, 0.85), PIT_TINT, function(cf)
					local gc, gm = sw(PIT_TINT, "GLOW")
					lump("BlightPod", (cf * CFrame.new(0, 0.7, 0)).Position, V(1.6, 1.6, 1.6), gc, gm)
				end)
			end
			noCollide(m)
			cover += 1
		end
	end

	ctx.setAttribute("Floor33Landmarks", landmarks)
	ctx.setAttribute("Floor33Props", props)
	ctx.setAttribute("Floor33GroundCover", cover)
end

return table.freeze(CorruptedFloor33)
