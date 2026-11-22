--!strict
-- Hand-authored set pieces for Corrupted Grove Floor 35: Sovereign's Grove (corrupted:5, Biome Boss: Blight Sovereign).
-- Design: docs/prompts/corrupted-grove-floor-layouts-prompt.md (Floor 35).
--
-- The Mother Graft's colossal root crown over an abyssal corrupted sap mire (Bottom = -8, Surface = "BLIGHT"):
-- three colossal roots (West Root, Taproot ending in the Heart Stair, East Root) fan out from the 184 x 136
-- Sovereign's Dais (Apex, Y 60) beneath the >= 230-stud dead colossus trunk of the Mother Graft.
-- The only green on the floor is the small ring of moss and ferns around the Last Warden at Taproot Foot.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local CorruptedFloor35 = {}

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

-- Blight eclipse palette: charred blackened-violet Mother Graft bark, electric violet-magenta heartrot
-- cavities and pulsing root seams (hue ~300°, distinct from crimson boss telegraphs), bloated purple
-- rot-blooms, shadowed violet moss (except the Last Warden's sole remnant green ring) and clean linen bands.
local SOVEREIGN = table.freeze({
	WOOD = swatch(42, 22, 54, Mat.Wood), -- blackened plum-charcoal Mother Graft bark & roots
	TRIM = swatch(172, 154, 152, Mat.Wood), -- bleached ossuary bone, warden robes & weathered posts
	ALT = swatch(128, 72, 134, Mat.Fabric), -- blighted canopy drapes
	FOLIAGE = swatch(56, 36, 76, Mat.Grass), -- blighted dead-violet pine needles
	CORAL = swatch(212, 82, 222, Mat.Grass),
	CAP = swatch(168, 32, 174, Mat.SmoothPlastic), -- colossal magenta-violet rot-blooms & rot-fruit
	ACCENT = swatch(224, 194, 246, Mat.Grass),
	MOSS = swatch(58, 42, 74, Mat.Grass), -- corrupted violet-grey hanging moss (NOT green!)
	SILK = swatch(218, 146, 212, Mat.Fabric), -- rot-stained Pale Bands
	STONE = swatch(64, 52, 84, Mat.Slate), -- dark violet-basalt root geode & cairn stones
	METAL = swatch(166, 172, 186, Mat.Metal), -- gleaming Hollin grafting knife
	GLOW = swatch(240, 62, 255, Mat.Neon), -- blazing violet-magenta Mother Graft cavity & sap
	CANDLE = swatch(255, 206, 126, Mat.Neon), -- luminous clean golden Heartrot Core seed & shrine lamps
	STEM = swatch(48, 28, 60, Mat.Wood),
	BULB = swatch(232, 72, 252, Mat.Neon),
})

local MOTHER_TINT = tinted(SOVEREIGN, {
	WOOD = swatch(34, 18, 46, Mat.Wood),
	GLOW = swatch(248, 74, 255, Mat.Neon),
	SILK = swatch(198, 102, 188, Mat.Fabric), -- enormous rot-soaked Pale Band below the heart
})

-- The ONLY green on Floor 35: the Last Warden's ring of living moss and ferns at Taproot Foot.
local LAST_WARDEN_TINT = tinted(SOVEREIGN, {
	MOSS = swatch(74, 132, 62, Mat.Grass),
	FOLIAGE = swatch(62, 124, 54, Mat.Grass),
	SILK = swatch(242, 236, 244, Mat.Fabric), -- clean white Pale Band
})

local LAST_BAND_TINT = tinted(SOVEREIGN, {
	SILK = swatch(248, 244, 252, Mat.Fabric), -- the single clean white Last Band at arrival
	CANDLE = swatch(255, 212, 142, Mat.Neon),
})

local BLOOM_TINT = tinted(SOVEREIGN, {
	CAP = swatch(192, 38, 196, Mat.SmoothPlastic),
	GLOW = swatch(246, 86, 255, Mat.Neon),
})

local ROT_LIGHT = rgb(238, 68, 255)
local SEED_LIGHT = rgb(255, 204, 124)

-- Floor 35's 23 landmark footprints (local floor space), spec-checked offline against every walkway
-- lane, camp (34-stud clearance) and boss portal (12-stud clearance). None touch the 184 x 136 Apex arena.
CorruptedFloor35.Landmarks = table.freeze({
	{ Id = "MotherGraftColossus", X = 0, Z = -383.5, Y = 58, HalfX = 49.2, HalfZ = 13.6, Top = 252.2 },
	{ Id = "MotherGraftOakW", X = -82, Z = -381, Y = 116, HalfX = 22.0, HalfZ = 11.0, Top = 32.0 },
	{ Id = "MotherGraftPineE", X = 84, Z = -381, Y = 122, HalfX = 24.0, HalfZ = 11.5, Top = 35.0 },
	{ Id = "MotherGraftFruitW", X = -114, Z = -376, Y = 148, HalfX = 20.0, HalfZ = 5.5, Top = 24.0 },
	{ Id = "MotherGraftOakE", X = 116, Z = -376, Y = 152, HalfX = 22.0, HalfZ = 11.0, Top = 32.0 },
	{ Id = "LastWarden", X = 54, Z = 106, Y = 12, HalfX = 7.6, HalfZ = 7.6, Top = 16.5 },
	{ Id = "WeepingPulpitRoot", X = -92, Z = 10, Y = 14, HalfX = 10.5, HalfZ = 10.0, Top = 16.0 },
	{ Id = "RotbloomNurseryBed", X = 94, Z = 12, Y = 18, HalfX = 9.0, HalfZ = 8.4, Top = 13.5 },
	{ Id = "FallenCrownLandmark", X = -376, Z = -122, Y = 28, HalfX = 12.2, HalfZ = 12.2, Top = 17.5 },
	{ Id = "SapfallWaterfall", X = 374, Z = -122, Y = -4, HalfX = 6.5, HalfZ = 9.2, Top = 35.5 },
	{ Id = "WestKneeBurl", X = -304, Z = -22, Y = 14, HalfX = 10.5, HalfZ = 13.2, Top = 14.5 },
	{ Id = "EastKneeBurl", X = 304, Z = -22, Y = 16, HalfX = 10.5, HalfZ = 13.2, Top = 14.5 },
	{ Id = "TaprootKnuckleBurl", X = -54, Z = 12, Y = 18, HalfX = 10.5, HalfZ = 13.2, Top = 14.5 },
	{ Id = "WestCrestShrine", X = -264, Z = -166, Y = 36, HalfX = 4.8, HalfZ = 4.4, Top = 14.8 },
	{ Id = "EastCrestShrine", X = 264, Z = -166, Y = 38, HalfX = 4.8, HalfZ = 4.4, Top = 14.8 },
	{ Id = "WestCrownGeode", X = -214, Z = -294, Y = 48, HalfX = 8.6, HalfZ = 7.6, Top = 20.6 },
	{ Id = "EastCrownSeed", X = 214, Z = -294, Y = 50, HalfX = 6.4, HalfZ = 6.6, Top = 15.2 },
	{ Id = "WestRootRidgeA", X = -282, Z = 36, Y = 4, HalfX = 17.6, HalfZ = 8.8, Top = 14.0 },
	{ Id = "WestRootRidgeB", X = -262, Z = -234, Y = 36, HalfX = 17.6, HalfZ = 8.8, Top = 14.0 },
	{ Id = "EastRootRidgeA", X = 282, Z = 36, Y = 6, HalfX = 17.6, HalfZ = 8.8, Top = 14.0 },
	{ Id = "EastRootRidgeB", X = 262, Z = -234, Y = 38, HalfX = 17.6, HalfZ = 8.8, Top = 14.0 },
	{ Id = "TaprootRidgeW", X = -42, Z = -94, Y = 22, HalfX = 17.6, HalfZ = 8.8, Top = 14.0 },
	{ Id = "TheLastBandPost", X = 28, Z = 344, Y = 8, HalfX = 4.8, HalfZ = 4.4, Top = 14.8 },
}) :: { Landmark }

function CorruptedFloor35.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number, P = H.field, H.bottom, H.d, H.P
	local w: number = ctx.w
	local layout = ctx.layout
	local boxAt, lump, light, piece, noCollide, plume = H.boxAt, H.lump, H.light, H.piece, H.noCollide, H.plume
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
	local rng = Random.new(35 * 9137)

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 12 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end

	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end

	for _, lm in CorruptedFloor35.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	local taken: { { number } } = {}
	for _, lm in CorruptedFloor35.Landmarks do
		table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
	end
	local function free(x: number, z: number, r: number): boolean
		if math.abs(x) > w / 2 - 14 or math.abs(z) > d / 2 - 14 then return false end
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
	-- 1. THE MOTHER GRAFT (~252 studs tall behind Sovereign's Dais at 0, 42, -383.5):
	--    the tallest landmark in the tower, parted around a blazing magenta cavity at Y ~160,
	--    bound by the giant rot-soaked Pale Band, with four grafted species limbs fanning high.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor35.Landmarks[1]
		local baseY = lm.Y :: number
		local made = piece("MotherGraftColossus", lm.X, lm.Z, 0, "MotherGraftTrunk", V(1.05, 1.15, 0.34) :: any, MOTHER_TINT, function(cf)
			local wc, wm = sw(MOTHER_TINT, "WOOD")
			local gc, gm = sw(MOTHER_TINT, "GLOW")
			for _, s in { -1, 1 } do
				rod("MotherHalf", (cf * CFrame.new(s * 11, 0, 0)).Position, (cf * CFrame.new(s * 24, 240, 0)).Position, 14, wc, wm)
			end
			local heart = lump("MotherHeartCore", (cf * CFrame.new(0, 118, -3)).Position, V(26, 56, 12), gc, gm)
			addLight(heart, ROT_LIGHT, 2.6, 110)
		end, baseY)
		pin(made)
		if made and ctx.has("MotherGraftTrunk") then
			addLight(H.glowOf(made), ROT_LIGHT, 2.6, 110)
		end
		ctx.group("MotherGraftSpores", function()
			plume(V(lm.X, baseY + 120, lm.Z + 10), rgb(244, 78, 255), 7.5, 10, 7.0, 5.2)
		end)
		landmarks += 1

		-- Four grafted species limbs jutting high off the Mother Graft's flanks (Oak, Pine, Fruit, Oak).
		local limbs = {
			{ CorruptedFloor35.Landmarks[2], "MotherGraftLimbOak", 180 },
			{ CorruptedFloor35.Landmarks[3], "MotherGraftLimbPine", 0 },
			{ CorruptedFloor35.Landmarks[4], "MotherGraftLimbFruit", 170 },
			{ CorruptedFloor35.Landmarks[5], "MotherGraftLimbOak", 12 },
		}
		for _, lb in limbs do
			local llm = lb[1]
			local m = piece(llm.Id, llm.X, llm.Z, lb[3], lb[2], 1.0, MOTHER_TINT, function(cf)
				local wc, wm = sw(MOTHER_TINT, "WOOD")
				rod("GraftedLimb", (cf * CFrame.new(-18, 2, 0)).Position, (cf * CFrame.new(18, 22, 0)).Position, 2.6, wc, wm)
			end, llm.Y)
			pin(m)
			noCollide(m)
			landmarks += 1
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 2. The Last Warden at Taproot Foot (54, 12, 106): half-grafted Hollin warden, knife in hand,
	--    with the ONLY ring of living green moss and ferns on Floor 35.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor35.Landmarks[6]
		local m = piece("LastWarden", lm.X, lm.Z, -25, "LastWardenGraft", 1.0, LAST_WARDEN_TINT, function(cf)
			local wc, wm = sw(LAST_WARDEN_TINT, "WOOD")
			local mc, mm = sw(LAST_WARDEN_TINT, "MOSS")
			rod("WardenRoot", cf.Position, cf.Position + V(0, 15, 0), 2.4, wc, wm)
			ctx.cyl("RemnantGreenRing", cf.Position + V(0, 0.4, 0), 6.5, 0.8, mc, mm)
		end, lm.Y)
		pin(m)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 3–6. The Four Root Spurs: Weeping Pulpit, Rotbloom Nursery, Fallen Crown Ring & Sapfall Ledge.
	---------------------------------------------------------------------------------------------------
	do
		-- Weeping Pulpit burl weeping glowing sap into the mire.
		local wp = CorruptedFloor35.Landmarks[7]
		local mw = piece("WeepingPulpitRoot", wp.X, wp.Z, 30, "RootKneeJunction", 0.9, SOVEREIGN, function(cf)
			local wc, wm = sw(SOVEREIGN, "WOOD")
			lump("PulpitBurl", cf.Position + V(0, 5, 0), V(18, 10, 16), wc, wm)
		end, wp.Y)
		pin(mw)
		landmarks += 1

		-- Rotbloom Nursery: colossal shield-sized pulsing blooms breathing spores.
		local rn = CorruptedFloor35.Landmarks[8]
		local mr = piece("RotbloomNurseryBed", rn.X, rn.Z, -35, "RotbloomGiant", 1.0, BLOOM_TINT, function(cf)
			local cc, cm = sw(BLOOM_TINT, "CAP")
			lump("NurseryBloom", cf.Position + V(0, 6, 0), V(16, 10, 15), cc, cm)
		end, rn.Y)
		pin(mr)
		if mr and ctx.has("RotbloomGiant") then
			addLight(H.glowOf(mr), ROT_LIGHT, 1.3, 40)
		end
		ctx.group("NurserySpores", function()
			plume(V(rn.X, (rn.Y :: number) + 8, rn.Z), rgb(236, 86, 252), 3.6, 6, 3.2, 3.8)
		end)
		landmarks += 1

		-- Fallen Crown Ring: broken circlet of Mother Graft crown branches.
		local fc = CorruptedFloor35.Landmarks[9]
		local mf = piece("FallenCrownLandmark", fc.X, fc.Z, 18, "FallenCrownBranch", 1.0, MOTHER_TINT, function(cf)
			local wc, wm = sw(MOTHER_TINT, "WOOD")
			for k = 0, 5 do
				local a = k * math.pi / 3
				rod("CrownTine", cf.Position + V(math.cos(a) * 10, 1, math.sin(a) * 10), cf.Position + V(math.cos(a) * 11, 13, math.sin(a) * 11), 1.2, wc, wm)
			end
		end, fc.Y)
		pin(mf)
		landmarks += 1

		-- Sapfall Ledge: sculpted curving magenta sap waterfall pouring off the root into the mire!
		local sf = CorruptedFloor35.Landmarks[10]
		local ms = piece("SapfallWaterfall", sf.X, sf.Z, -90, "SapfallRibbon", 1.0, BLOOM_TINT, function(cf)
			local gc, gm = sw(BLOOM_TINT, "GLOW")
			local fall = rod("SapFallStream", cf.Position + V(0, 32, 0), cf.Position + V(0, 0, -4), 2.2, gc, gm)
			addLight(fall, ROT_LIGHT, 1.5, 44)
		end, sf.Y)
		pin(ms)
		if ms and ctx.has("SapfallRibbon") then
			addLight(H.glowOf(ms), ROT_LIGHT, 1.5, 44)
		end
		ctx.group("SapfallSplashMist", function()
			plume(V(sf.X, bottom + 4, sf.Z), rgb(240, 74, 255), 4.0, 6, 3.8, 3.4)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 7–9. Knee Junction Burls (where the three colossal roots knit together, bursting with blight pods).
	---------------------------------------------------------------------------------------------------
	do
		for _, idx in { 11, 12, 13 } do
			local lm = CorruptedFloor35.Landmarks[idx]
			local m = piece(lm.Id, lm.X, lm.Z, idx * 47, "RootKneeJunction", 1.0, SOVEREIGN, function(cf)
				local wc, wm = sw(SOVEREIGN, "WOOD")
				lump("KneeBurl", cf.Position + V(0, 6, 0), V(20, 12, 22), wc, wm)
			end, lm.Y)
			pin(m)
			landmarks += 1
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 10–13. Root Crest Shrines & Relic Echoes (Heartrot Geode at West Crown, Thorn-Caged Seed at East Crown).
	---------------------------------------------------------------------------------------------------
	do
		for _, pair in { { CorruptedFloor35.Landmarks[14], 90 }, { CorruptedFloor35.Landmarks[15], -90 } } do
			local lm = pair[1]
			local m = piece(lm.Id, lm.X, lm.Z, pair[2], "WardenRootShrine", 1.0, SOVEREIGN, function(cf)
				local wc, wm = sw(SOVEREIGN, "WOOD")
				rod("ShrinePost", cf.Position, cf.Position + V(0, 14, 0), 1.0, wc, wm)
			end, lm.Y)
			pin(m)
			if m and ctx.has("WardenRootShrine") then
				addLight(m:FindFirstChild("CANDLE", true), SEED_LIGHT, 1.1, 32)
			end
			landmarks += 1
		end

		-- West Root Crown: split Heartrot Geode echoing the Blightroot Geode relic.
		local geo = CorruptedFloor35.Landmarks[16]
		local mg = piece("WestCrownGeode", geo.X, geo.Z, 45, "HeartrotGeode", 1.0, BLOOM_TINT, function(cf)
			local sc, sm = sw(BLOOM_TINT, "STONE")
			local gc, gm = sw(BLOOM_TINT, "GLOW")
			lump("GeodeShell", cf.Position + V(0, 6, 0), V(15, 12, 13), sc, sm)
			local core = lump("GeodeCore", cf.Position + V(0, 7, -3), V(5, 9, 5), gc, gm)
			addLight(core, ROT_LIGHT, 1.5, 44)
		end, geo.Y)
		pin(mg)
		if mg and ctx.has("HeartrotGeode") then
			addLight(H.glowOf(mg), ROT_LIGHT, 1.5, 44)
		end
		landmarks += 1

		-- East Root Crown: Thorn-Caged Seed echoing the Heartrot Core relic.
		local seed = CorruptedFloor35.Landmarks[17]
		local msd = piece("EastCrownSeed", seed.X, seed.Z, -45, "ThornCagedSeed", 1.0, LAST_BAND_TINT, function(cf)
			local cc, cm = sw(LAST_BAND_TINT, "CANDLE")
			local pod = lump("CleanSeedPod", cf.Position + V(0, 7.5, 0), V(5.6, 8.0, 5.6), cc, cm)
			addLight(pod, SEED_LIGHT, 1.4, 42)
		end, seed.Y)
		pin(msd)
		if msd and ctx.has("ThornCagedSeed") then
			addLight(msd:FindFirstChild("CANDLE", true), SEED_LIGHT, 1.4, 42)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 14–18. Colossal Root-Ridge Casings flanking the three great roots + The Last Band at Sanctuary.
	---------------------------------------------------------------------------------------------------
	do
		for _, pair in {
			{ CorruptedFloor35.Landmarks[18], 82 },
			{ CorruptedFloor35.Landmarks[19], 74 },
			{ CorruptedFloor35.Landmarks[20], -82 },
			{ CorruptedFloor35.Landmarks[21], -74 },
			{ CorruptedFloor35.Landmarks[22], 90 },
		} do
			local lm = pair[1]
			local m = piece(lm.Id, lm.X, lm.Z, pair[2], "RootRidgeSegment", 1.0, SOVEREIGN, function(cf)
				local wc, wm = sw(SOVEREIGN, "WOOD")
				rod("GreatRootCasing", (cf * CFrame.new(-15, 4, 0)).Position, (cf * CFrame.new(15, 4, 0)).Position, 4.8, wc, wm)
			end, lm.Y)
			pin(m)
			landmarks += 1
		end

		-- The Last Band: single clean white Pale Band on a carved shrine post at the Sanctuary edge.
		local lb = CorruptedFloor35.Landmarks[23]
		local mlb = piece("TheLastBandPost", lb.X, lb.Z, -18, "WardenRootShrine", 1.0, LAST_BAND_TINT, function(cf)
			local wc, wm = sw(LAST_BAND_TINT, "WOOD")
			local sc, sm = sw(LAST_BAND_TINT, "SILK")
			rod("LastBandStake", cf.Position, cf.Position + V(0, 14, 0), 0.9, wc, wm)
			boxAt("CleanLastBand", V(2.4, 1.4, 2.4), cf * CFrame.new(0, 9.2, 0), sc, sm)
		end, lb.Y)
		pin(mlb)
		if mlb and ctx.has("WardenRootShrine") then
			addLight(mlb:FindFirstChild("CANDLE", true), SEED_LIGHT, 1.2, 34)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 19. Sovereign's Dais Outer Rim (low Pale-Band stakes & root ribs strictly on outer edge, keeping
	--     the 184 x 136 Boss Arena and portal lanes 100% spotless!) + Heart Stair banded stakes.
	---------------------------------------------------------------------------------------------------
	do
		local apex = P.Apex
		local wc, wm = sw(MOTHER_TINT, "WOOD")
		local sc, sm = sw(SOVEREIGN, "SILK")
		-- 8 low Pale-Band stakes ringing the far outer perimeter of the 184 x 136 dais (clear of portals & entries).
		for _, off in {
			{ -86, -48 }, { -86, 48 }, { 86, -48 }, { 86, 48 },
			{ -52, 64 }, { 52, 64 }, { -68, -64 }, { 68, -64 },
		} do
			local sx, sz = apex.X + off[1], apex.Z + off[2]
			ctx.group("DaisRimStake", function()
				pin(noCollide(rod("RimStake", V(sx, apex.Y, sz), V(sx, apex.Y + 6.5, sz), 0.55, wc, wm)))
				pin(noCollide(boxAt("RimBand", V(1.3, 0.9, 1.3), CFrame.new(sx, apex.Y + 4.4, sz), sc, sm)))
			end)
			props += 1
		end
		-- Heart Stair banded stakes flanking TaprootSpine -> Apex outside UsableWidth.
		for _, sx in { -14, 14 } do
			for step = 0, 3 do
				local f = step / 3
				local z = -164 - f * 58
				local y = 41 + f * 17
				ctx.group("HeartStairStake", function()
					pin(noCollide(rod("StairStake", V(sx, y, z), V(sx, y + 7.2, z), 0.52, wc, wm)))
					pin(noCollide(boxAt("StairBand", V(1.25, 0.85, 1.25), CFrame.new(sx, y + 5.0, z), sc, sm)))
				end)
				props += 1
			end
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 20. Converging Glowing Heartrot Fissures across the Abyssal Sap Mire + High Perimeter Moss Mantles
	--     + Spore Drifts over the Mire.
	---------------------------------------------------------------------------------------------------
	do
		local vc, vm = sw(MOTHER_TINT, "WOOD")
		local gc, gm = sw(MOTHER_TINT, "GLOW")
		local mireVeins = {
			{ { -156, 152 }, { -126, 94 }, { -96, 48 } },
			{ { 156, 152 }, { 126, 94 }, { 96, 48 } },
			{ { -142, -88 }, { -116, -158 }, { -86, -218 } },
			{ { 142, -88 }, { 116, -158 }, { 86, -218 } },
			{ { -76, -86 }, { -54, -156 }, { -34, -222 } },
			{ { 76, -86 }, { 54, -156 }, { 34, -222 } },
			{ { -290, 92 }, { -312, 18 }, { -332, -62 } },
			{ { 290, 92 }, { 312, 18 }, { 332, -62 } },
			{ { -326, -192 }, { -276, -252 }, { -228, -312 } },
			{ { 326, -192 }, { 276, -252 }, { 228, -312 } },
		}
		for _, chain in mireVeins do
			for i = 1, #chain - 1 do
				local a2, b2 = chain[i], chain[i + 1]
				local ya = (if field then field.Height(a2[1], a2[2]) else bottom) + 0.8
				local yb = (if field then field.Height(b2[1], b2[2]) else bottom) + 0.8
				ctx.group("MireBlightVein", function()
					pin(noCollide(rod("MireBlightGlow", V(a2[1], ya, a2[2]), V(b2[1], yb, b2[2]), 0.85, gc, gm)))
					pin(noCollide(rod("MireRootSpine", V(a2[1] + 1.8, ya + 0.4, a2[2] - 1.2), V(b2[1] + 1.8, yb + 0.4, b2[2] - 1.2), 1.4, vc, vm)))
				end)
			end
		end

		-- High Moss Mantles hanging from the Mother Graft's outer canopy edge (far above walkways!).
		for _, mm in { { -145, -372, 138, 12 }, { 145, -372, 138, -12 }, { -255, -365, 118, 28 }, { 255, -365, 118, -28 } } do
			local m = piece("HighMossMantle", mm[1], mm[2], mm[4], "MossMantle", 1.35, MOTHER_TINT, function(cf)
				local mc, matM = sw(MOTHER_TINT, "MOSS")
				boxAt("MantleCurtain", V(28, 22, 3), cf * CFrame.new(0, 11, 0), mc, matM)
			end, mm[3])
			pin(m)
			noCollide(m)
			props += 1
		end

		-- 5 spore drift plumes rising from the sap mire (total emitters = 8 <= 12).
		for _, sp in { { -128, -108 }, { 128, -108 }, { -126, 98 }, { 126, 98 }, { 0, -214 } } do
			ctx.group("MireSporeDrift", function()
				plume(V(sp[1], bottom + 4, sp[2]), rgb(212, 74, 248), 5.8, 5, 2.6, 5.2)
			end)
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 21. Ring of Bowing Dead Elders around the Perimeter + Mire Shore Framing + Corrupted Ground Cover.
	---------------------------------------------------------------------------------------------------
	-- Ring of bowing dead elders around the room rim leaning inward toward the Mother Graft.
	local elderRing = {
		{ -356, 260 }, { -362, 150 }, { -366, 20 }, { -366, -210 }, { -352, -330 }, { -254, -366 },
		{ 356, 260 }, { 362, 150 }, { 366, 20 }, { 366, -210 }, { 352, -330 }, { 254, -366 },
	}
	for idx, er in elderRing do
		if free(er[1], er[2], 9) and (not field or field.Slope(er[1], er[2]) < 0.55) then
			local gy = if field then field.Height(er[1], er[2]) - 1.5 else bottom
			local yaw = math.deg(math.atan2(-er[1], -380 - er[2]))
			local m = piece("BowingDeadElder", er[1], er[2], yaw, if idx % 2 == 0 then "BlightTree" else "DeadTree", rng:NextNumber(1.35, 1.75), MOTHER_TINT, function(cf)
				local wc, wm = sw(MOTHER_TINT, "WOOD")
				rod("BowingTrunk", cf.Position, cf.Position + V(0, 34, 0), 2.4, wc, wm)
			end, gy, CFrame.Angles(math.rad(10), 0, 0))
			pin(m)
			take(er[1], er[2], 9)
			props += 1
		end
	end

	-- Mire Shore foreground framing & scattered mire life (keep the central arrival vista open to the Mother Graft!).
	local mireProps = { "ThornKnotCluster", "RootKneeJunction", "RootRidgeSegment", "CliffRockA", "CliffRockB", "BoulderCluster", "OssuaryBones", "FelledBandLog", "SawnStumpCluster", "BlightTree", "DeadTree", "GiantMushroom", "WardenSkeleton", "RotbloomGiant" }
	for i = 1, 1100 do
		local x = rng:NextNumber(-w / 2 + 24, w / 2 - 24)
		local z = rng:NextNumber(-d / 2 + 24, d / 2 - 24)
		if props < 620 and not (z > 110 and math.abs(x) < 115) and free(x, z, 5.5) and (not field or field.Slope(x, z) < 0.78) then
			local gy = if field then field.Height(x, z) - 0.8 else bottom
			local tpl = mireProps[(i % #mireProps) + 1]
			local sc = if tpl == "RootRidgeSegment" then 0.55 elseif tpl == "RootKneeJunction" then 0.52 elseif tpl == "RotbloomGiant" then 0.55 else rng:NextNumber(0.8, 1.35)
			local m = piece("MireProp", x, z, rng:NextNumber(0, 360), tpl, sc, if i % 4 == 0 then BLOOM_TINT else SOVEREIGN, function(cf)
				local wc, wm = sw(SOVEREIGN, "WOOD")
				lump("MireClump", cf.Position + V(0, 1.8, 0), V(5, 3, 5), wc, wm)
			end, gy)
			pin(m)
			take(x, z, 5.5)
			props += 1
		end
	end

	local coverTemplates = { "RotBloomCluster", "BlightPod", "PadCap", "SporeMoss", "MushroomCluster", "ReedPondCluster", "RuinRubble" }
	for i = 1, 1400 do
		if cover >= 480 then break end
		local x = rng:NextNumber(-w / 2 + 20, w / 2 - 20)
		local z = rng:NextNumber(-d / 2 + 20, d / 2 - 20)
		if free(x, z, 2.5) and (not field or field.Slope(x, z) < 0.85) then
			local gy = if field then field.Height(x, z) - 0.2 else bottom
			local tpl = coverTemplates[(i % #coverTemplates) + 1]
			local sc = rng:NextNumber(0.85, 1.4)
			local m = piece("MireGroundCover", x, z, rng:NextNumber(0, 360), tpl, sc, if i % 2 == 0 then BLOOM_TINT else SOVEREIGN, function(cf)
				local cc, cm = sw(BLOOM_TINT, "CAP")
				lump("MireTuft", cf.Position + V(0, 0.9, 0), V(3.4, 1.6, 3.4), cc, cm)
			end, gy)
			pin(m)
			noCollide(m)
			cover += 1
		end
	end

	ctx.setAttribute("Floor35Landmarks", landmarks)
	ctx.setAttribute("Floor35Props", props)
	ctx.setAttribute("Floor35GroundCover", cover)
end

return CorruptedFloor35
