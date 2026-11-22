--!strict
-- Hand-authored set pieces for Corrupted Grove Floor 34: Heartrot Stronghold (corrupted:4).
-- Design: docs/prompts/corrupted-grove-floor-layouts-prompt.md (Floor 34).
--
-- The Hollin wardens' last refuge built up five colossal elder trunks over a deeply corrupted violet-black
-- rot bog (Bottom = -6, Surface = "BLIGHT"), climbing tree to tree on bracket decks and branch bridges to
-- the Heartrot Crown (Apex, Y 52) cradled in the fork of the Great Rotwood at the back-west.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local CorruptedFloor34 = {}

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

-- Deep violet-black canopy gloom palette: blackened plum-bark elders, electric violet-magenta heartrot
-- cavities (hue ~300°, distinct from crimson enemy telegraphs), glowing purple shelf fungi, warm amber
-- warden lanterns, rot-soaked Pale Bands and shadowed mossy drapes.
local STRONGHOLD = table.freeze({
	WOOD = swatch(48, 28, 58, Mat.Wood), -- gnarled blackened-plum elder bark & dark timber
	TRIM = swatch(166, 148, 138, Mat.Wood), -- weathered timber planks, daub walls & rope
	ALT = swatch(138, 108, 76, Mat.Fabric), -- torn cedar shingles & stilt-hut thatch
	FOLIAGE = swatch(46, 60, 66, Mat.Grass), -- gloomy blighted canopy foliage
	CORAL = swatch(204, 96, 212, Mat.Grass), -- blighted canopy blossoms
	CAP = swatch(154, 34, 158, Mat.SmoothPlastic), -- giant purple-magenta shelf fungi & rot-lilies
	ACCENT = swatch(216, 188, 238, Mat.Grass),
	MOSS = swatch(56, 72, 62, Mat.Grass), -- damp shadowed hanging moss curtains
	SILK = swatch(214, 156, 206, Mat.Fabric), -- rot-stained Hollin Pale Bands
	STONE = swatch(82, 70, 104, Mat.Slate), -- bog-stained violet fieldstone
	METAL = swatch(52, 44, 64, Mat.Metal), -- iron climbing pegs, cistern hoops & jar lids
	GLOW = swatch(234, 64, 252, Mat.Neon), -- blazing violet-magenta heartrot cavities & sap
	CANDLE = swatch(255, 194, 118, Mat.Neon), -- warm warden lanterns, keep arrow slits & clean seed jars
	STEM = swatch(50, 32, 62, Mat.Wood),
	BULB = swatch(224, 72, 248, Mat.Neon),
})

local ROTWOOD_TINT = tinted(STRONGHOLD, {
	WOOD = swatch(38, 22, 48, Mat.Wood),
	GLOW = swatch(244, 72, 255, Mat.Neon),
	SILK = swatch(204, 114, 188, Mat.Fabric), -- giant rot-soaked Pale Band
	CAP = swatch(142, 28, 148, Mat.SmoothPlastic),
})

local KEEP_TINT = tinted(STRONGHOLD, {
	WOOD = swatch(68, 48, 52, Mat.Wood),
	TRIM = swatch(184, 166, 150, Mat.Wood),
	ALT = swatch(124, 88, 74, Mat.Wood), -- weathered split-shingle roofs
	CANDLE = swatch(255, 198, 122, Mat.Neon),
})

local FUNGUS_TINT = tinted(STRONGHOLD, {
	CAP = swatch(172, 42, 178, Mat.SmoothPlastic),
	GLOW = swatch(238, 84, 252, Mat.Neon),
})

local BOG_TINT = tinted(STRONGHOLD, {
	WOOD = swatch(42, 26, 48, Mat.Wood),
	MOSS = swatch(50, 68, 58, Mat.Grass),
})

local LAMP_TINT = tinted(STRONGHOLD, {
	GLOW = swatch(255, 192, 116, Mat.Neon),
})

local ROT_LIGHT = rgb(232, 68, 252)
local LAMP_LIGHT = rgb(255, 190, 116)
local SHAFT_COL = rgb(214, 178, 248)

-- Floor 34's 22 landmark footprints (local floor space), spec-checked offline against every walkway
-- lane, camp (34-stud clearance) and boss portal, and reserved so clutter keeps off them.
CorruptedFloor34.Landmarks = table.freeze({
	{ Id = "GreatRotwood", X = -150, Z = -368, Y = 10, HalfX = 32.5, HalfZ = 26.8, Top = 187.0 },
	{ Id = "GateElmTrunk", X = -56, Z = -82, Y = -6, HalfX = 15.0, HalfZ = 15.0, Top = 154.0 },
	{ Id = "SapElmTrunk", X = -225, Z = -60, Y = -6, HalfX = 15.0, HalfZ = 15.0, Top = 150.0 },
	{ Id = "BracketElmTrunk", X = 232, Z = -40, Y = -6, HalfX = 15.0, HalfZ = 15.0, Top = 148.0 },
	{ Id = "WestKeepTrunk", X = -318, Z = -168, Y = -6, HalfX = 15.0, HalfZ = 15.0, Top = 156.0 },
	{ Id = "EastKeepTrunk", X = 312, Z = -160, Y = -6, HalfX = 15.0, HalfZ = 15.0, Top = 156.0 },
	{ Id = "CrownKeep", X = -236, Z = -310, Y = 52, HalfX = 12.6, HalfZ = 10.6, Top = 23.0 },
	{ Id = "WestBoleKeep", X = -304, Z = -214, Y = 32, HalfX = 12.6, HalfZ = 10.6, Top = 23.0 },
	{ Id = "EastBoleKeep", X = 292, Z = -124, Y = 36, HalfX = 12.6, HalfZ = 10.6, Top = 23.0 },
	{ Id = "BracketFungus", X = 206, Z = -36, Y = 12, HalfX = 14.5, HalfZ = 13.5, Top = 15.0 },
	{ Id = "SapCisternTap", X = -192, Z = -62, Y = 26, HalfX = 7.5, HalfZ = 6.5, Top = 14.0 },
	{ Id = "SeedVaultCradle", X = 148, Z = -150, Y = 30, HalfX = 7.6, HalfZ = 5.0, Top = 14.0 },
	{ Id = "WeepingGallowsLandmark", X = -316, Z = -338, Y = 48, HalfX = 13.6, HalfZ = 6.8, Top = 36.0 },
	{ Id = "MendersWardHut", X = -336, Z = -22, Y = -4, HalfX = 10.2, HalfZ = 9.0, Top = 22.0 },
	{ Id = "RootgatePalisadeW", X = -56, Z = 128, Y = 8, HalfX = 11.0, HalfZ = 3.2, Top = 16.5 },
	{ Id = "RootgatePalisadeE", X = 56, Z = 128, Y = 8, HalfX = 11.0, HalfZ = 3.2, Top = 16.5 },
	{ Id = "WestStockadeWall", X = -258, Z = 110, Y = 12, HalfX = 11.0, HalfZ = 3.2, Top = 16.5 },
	{ Id = "EastStockadeWall", X = 258, Z = 102, Y = 14, HalfX = 11.0, HalfZ = 3.2, Top = 16.5 },
	{ Id = "CanopyLookout", X = 132, Z = -318, Y = 44, HalfX = 9.0, HalfZ = 5.0, Top = 20.5 },
	{ Id = "SunkenBogBoat", X = -82, Z = 46, Y = -6, HalfX = 8.6, HalfZ = 5.4, Top = 7.5 },
	{ Id = "SeveredBogBridge", X = 96, Z = 40, Y = -6, HalfX = 9.0, HalfZ = 7.5, Top = 18.0 },
	{ Id = "MotherGraftNear", X = 256, Z = -356, Y = 46, HalfX = 32.0, HalfZ = 28.0, Top = 182.0 },
}) :: { Landmark }

function CorruptedFloor34.Build(ctx: any)
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
	local rng = Random.new(34 * 8191)

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 12 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end

	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end

	for _, lm in CorruptedFloor34.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	local taken: { { number } } = {}
	for _, lm in CorruptedFloor34.Landmarks do
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

	-- Modular elder trunk builder: places RootFlare, Bole (A or B), and high Fork as three independent
	-- OnTerrain models so every elder reaches 145-156 studs without one giant clearance box risking the whole tree.
	local function buildElderTrunk(kind: string, x: number, z: number, yaw: number, boleKind: string, yBase: number, s: number)
		local wc, wm = sw(ROTWOOD_TINT, "WOOD")
		local gc, gm = sw(ROTWOOD_TINT, "GLOW")
		local mRoot = piece(kind .. "Root", x, z, yaw, "ElderTrunkRootFlare", s, ROTWOOD_TINT, function(cf)
			rod("RootBole", cf.Position, cf.Position + V(0, 44 * s, 0), 7.5 * s, wc, wm)
		end, yBase)
		pin(mRoot)
		local mBole = piece(kind .. "Bole", x, z, yaw + 18, boleKind, s, ROTWOOD_TINT, function(cf)
			rod("MidBole", cf.Position, cf.Position + V(0, 62 * s, 0), 6.2 * s, wc, wm)
			local g = rod("BoleRotSeam", cf.Position + V(0, 10, -6), cf.Position + V(0, 50, -6), 0.9, gc, gm)
			addLight(g, ROT_LIGHT, 1.4, 52)
		end, yBase + 40 * s)
		pin(mBole)
		if mBole and ctx.has(boleKind) then
			addLight(H.glowOf(mBole), ROT_LIGHT, 1.4, 52)
		end
		-- Canopy Fork starts at yBase + 98*s (~92+ studs above bog), cleanly above every walkway & camp!
		local mFork = piece(kind .. "Fork", x, z, yaw - 24, "ElderTrunkFork", s * 1.12, STRONGHOLD, function(cf)
			for k = 0, 4 do
				local a = k * 2 * math.pi / 5
				rod("ForkBough", cf.Position + V(0, 6, 0), cf.Position + V(math.cos(a) * 22, 34, math.sin(a) * 22), 2.4, wc, wm)
			end
		end, yBase + 98 * s)
		pin(mFork)
		noCollide(mFork)
	end

	---------------------------------------------------------------------------------------------------
	-- 1. The Great Rotwood (~187 studs tall behind Heartrot Crown at -150, -368): colossal split elder
	--    with a blazing magenta heartrot cavity and giant rot-soaked Pale Band cradling the Apex.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor34.Landmarks[1]
		local baseY = lm.Y :: number
		local made = piece("GreatRotwood", lm.X, lm.Z, 0, "GreatRotwoodCavity", V(1.05, 1.15, 0.78) :: any, ROTWOOD_TINT, function(cf)
			local wc, wm = sw(ROTWOOD_TINT, "WOOD")
			local gc, gm = sw(ROTWOOD_TINT, "GLOW")
			for _, s in { -1, 1 } do
				rod("RotwoodHalf", (cf * CFrame.new(s * 7, 0, 2)).Position, (cf * CFrame.new(s * 18, 175, 4)).Position, 10.5, wc, wm)
			end
			local cavity = lump("RotwoodCore", (cf * CFrame.new(0, 62, -2)).Position, V(18, 40, 12), gc, gm)
			addLight(cavity, ROT_LIGHT, 2.2, 85)
		end, baseY)
		pin(made)
		if made and ctx.has("GreatRotwoodCavity") then
			addLight(H.glowOf(made), ROT_LIGHT, 2.2, 85)
		end
		ctx.group("GreatRotwoodSpores", function()
			plume(V(lm.X, baseY + 68, lm.Z + 12), rgb(238, 86, 252), 6.0, 9, 6.5, 4.8)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 2–6. The Five Colossal Elder Trunks (Trees I–V, each 148–156 studs tall, beside their decks).
	---------------------------------------------------------------------------------------------------
	do
		local trunks = {
			{ CorruptedFloor34.Landmarks[2], 12, "ElderTrunkBoleA", 1.02 }, -- Tree I: Gate Elm (split & banded)
			{ CorruptedFloor34.Landmarks[3], -32, "ElderTrunkBoleA", 1.00 }, -- Tree II: Sap Elm (tapped)
			{ CorruptedFloor34.Landmarks[4], 45, "ElderTrunkBoleB", 0.98 }, -- Tree III: Bracket Elm (fungus-shelved)
			{ CorruptedFloor34.Landmarks[5], -18, "ElderTrunkBoleB", 1.04 }, -- Tree IV: West Keep Elder
			{ CorruptedFloor34.Landmarks[6], 28, "ElderTrunkBoleA", 1.04 }, -- Tree V: East Keep Elder
		}
		for _, tr in trunks do
			local lm = tr[1]
			buildElderTrunk(lm.Id, lm.X, lm.Z, tr[2], tr[3], lm.Y :: number, tr[4])
			landmarks += 1
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 7–9. The Three Hollin Treehouse Keeps (Heartrot Crown Keep, West Bole Keep, East Bole Keep).
	---------------------------------------------------------------------------------------------------
	do
		local keeps = {
			{ CorruptedFloor34.Landmarks[7], 78 },
			{ CorruptedFloor34.Landmarks[8], 42 },
			{ CorruptedFloor34.Landmarks[9], -48 },
		}
		for _, kp in keeps do
			local lm = kp[1]
			local m = piece(lm.Id, lm.X, lm.Z, kp[2], "TreehouseKeep", 1.0, KEEP_TINT, function(cf)
				local wc, wm = sw(KEEP_TINT, "WOOD")
				local ac, am = sw(KEEP_TINT, "ALT")
				local cc, cm = sw(KEEP_TINT, "CANDLE")
				boxAt("KeepBody", V(22, 13, 16), cf * CFrame.new(0, 7.5, 0), wc, wm)
				boxAt("KeepRoof", V(14, 1.2, 18), cf * CFrame.new(-4, 17, 0) * CFrame.Angles(0, 0, 0.35), ac, am)
				local win = boxAt("KeepSlit", V(1.6, 3.2, 0.8), cf * CFrame.new(0, 9, -8.1), cc, cm)
				addLight(win, LAMP_LIGHT, 1.3, 38)
			end, lm.Y)
			pin(m)
			if m and ctx.has("TreehouseKeep") then
				local cPart = m:FindFirstChild("CANDLE", true) or H.glowOf(m)
				addLight(cPart, LAMP_LIGHT, 1.3, 38)
			end
			landmarks += 1
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 10. Bracket Ledge Giant Shelf Fungus + 2 stepped sub-brackets below it.
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor34.Landmarks[10]
		local m = piece("BracketFungus", lm.X, lm.Z, 90, "ShelfFungusBracket", 1.0, FUNGUS_TINT, function(cf)
			local cc, cm = sw(FUNGUS_TINT, "CAP")
			lump("ShelfFan", (cf * CFrame.new(0, 6, 0)).Position, V(26, 5, 22), cc, cm)
		end, lm.Y)
		pin(m)
		if m and ctx.has("ShelfFungusBracket") then
			addLight(H.glowOf(m), ROT_LIGHT, 1.1, 36)
		end
		-- Two smaller stepped shelf brackets clinging to Tree III below the main ledge.
		for idx, off in { { 216, -24, 4, 0.62, 115 }, { 218, -54, 1, 0.56, 65 } } do
			local sub = piece("BracketSubShelf", off[1], off[2], off[5], "ShelfFungusBracket", off[4], FUNGUS_TINT, function(cf)
				local cc, cm = sw(FUNGUS_TINT, "CAP")
				lump("SubShelf", (cf * CFrame.new(0, 3, 0)).Position, V(14, 3, 12), cc, cm)
			end, off[3])
			pin(sub)
			props += 1
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 11. Sap Cistern Tap (pouring glowing magenta sap into the cooperage tub on Sap Cistern).
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor34.Landmarks[11]
		local m = piece("SapCisternTap", lm.X, lm.Z, 90, "SapTapCistern", 1.0, STRONGHOLD, function(cf)
			local wc, wm = sw(STRONGHOLD, "WOOD")
			local gc, gm = sw(STRONGHOLD, "GLOW")
			ctx.cyl("CisternTub", (cf * CFrame.new(0, 3.2, 0)).Position, 4.6, 6.4, wc, wm)
			local sap = ctx.cyl("CisternSap", (cf * CFrame.new(0, 5.8, 0)).Position, 4.2, 0.8, gc, gm)
			addLight(sap, ROT_LIGHT, 1.2, 34)
		end, lm.Y)
		pin(m)
		if m and ctx.has("SapTapCistern") then
			addLight(H.glowOf(m), ROT_LIGHT, 1.2, 34)
		end
		ctx.group("SapCisternMist", function()
			plume(V(lm.X, (lm.Y :: number) + 6, lm.Z), rgb(228, 86, 246), 3.0, 5, 3.2, 3.4)
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 12. Seed Vault Cradle (hollow limb with clean glowing seed jars + thorn-caged Heartrot Core jar).
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor34.Landmarks[12]
		local m = piece("SeedVaultCradle", lm.X, lm.Z, -90, "SeedJarStack", 1.0, KEEP_TINT, function(cf)
			local wc, wm = sw(KEEP_TINT, "WOOD")
			local cc, cm = sw(KEEP_TINT, "CANDLE")
			boxAt("VaultCradle", V(12, 4, 6), cf * CFrame.new(0, 2, 0), wc, wm)
			local jar = boxAt("VaultJar", V(2.4, 3.6, 2.4), cf * CFrame.new(0, 5.8, 0), cc, cm)
			addLight(jar, LAMP_LIGHT, 1.1, 32)
		end, lm.Y)
		pin(m)
		if m and ctx.has("SeedJarStack") then
			local cPart = m:FindFirstChild("CANDLE", true) or H.glowOf(m)
			addLight(cPart, LAMP_LIGHT, 1.1, 32)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 13. Weeping Gallows (sombre dead tree hung with Pale-Band-wrapped ropes at the far back-west).
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor34.Landmarks[13]
		local m = piece("WeepingGallowsLandmark", lm.X, lm.Z, 18, "WeepingGallowsTree", 1.0, STRONGHOLD, function(cf)
			local wc, wm = sw(STRONGHOLD, "WOOD")
			rod("GallowsTrunk", cf.Position, cf.Position + V(0, 32, 0), 2.2, wc, wm)
			rod("GallowsArm", cf.Position + V(-11, 27, 0), cf.Position + V(11, 30, 0), 1.1, wc, wm)
		end, lm.Y)
		pin(m)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 14. Mender's Ward Stilt Hut (rickety stilt hut standing in the western bog beside MenderWard).
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor34.Landmarks[14]
		local m = piece("MendersWardHut", lm.X, lm.Z, 90, "StiltHut", 1.0, KEEP_TINT, function(cf)
			local wc, wm = sw(KEEP_TINT, "WOOD")
			local ac, am = sw(KEEP_TINT, "ALT")
			local cc, cm = sw(KEEP_TINT, "CANDLE")
			boxAt("HutCabin", V(16, 8, 12), cf * CFrame.new(0, 11, 0), wc, wm)
			boxAt("HutRoof", V(18, 5, 14), cf * CFrame.new(0, 17, 0), ac, am)
			local win = boxAt("HutLamp", V(1.6, 2.0, 1.6), cf * CFrame.new(7, 10, -7), cc, cm)
			addLight(win, LAMP_LIGHT, 1.2, 34)
		end, lm.Y)
		pin(m)
		if m and ctx.has("StiltHut") then
			addLight(m:FindFirstChild("CANDLE", true), LAMP_LIGHT, 1.2, 34)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 15–18. Rootgate & Twin Stockade Palisades (sharpened timber walls with Pale Bands & briars).
	---------------------------------------------------------------------------------------------------
	do
		local walls = {
			{ CorruptedFloor34.Landmarks[15], 16 },
			{ CorruptedFloor34.Landmarks[16], -16 },
			{ CorruptedFloor34.Landmarks[17], 28 },
			{ CorruptedFloor34.Landmarks[18], -28 },
		}
		for _, wl in walls do
			local lm = wl[1]
			local m = piece(lm.Id, lm.X, lm.Z, wl[2], "StakePalisadeSegment", 1.0, STRONGHOLD, function(cf)
				local wc, wm = sw(STRONGHOLD, "WOOD")
				boxAt("PalisadeWall", V(20, 11, 2.2), cf * CFrame.new(0, 5.5, 0), wc, wm)
			end, lm.Y)
			pin(m)
			landmarks += 1
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 19. Canopy Walk Lookout (branch hanger lantern + Hollin bench overlooking the Mother Graft).
	---------------------------------------------------------------------------------------------------
	do
		local lm = CorruptedFloor34.Landmarks[19]
		local m = piece("CanopyLookout", lm.X, lm.Z, 180, "BranchBridgeHanger", 1.0, KEEP_TINT, function(cf)
			local wc, wm = sw(KEEP_TINT, "WOOD")
			local cc, cm = sw(KEEP_TINT, "CANDLE")
			rod("LookoutPost", cf.Position, cf.Position + V(0, 19, 0), 1.1, wc, wm)
			local glow = lump("LookoutLamp", (cf * CFrame.new(7, 14, 0)).Position, V(2, 2.4, 2), cc, cm)
			addLight(glow, LAMP_LIGHT, 1.2, 34)
		end, lm.Y)
		pin(m)
		if m and ctx.has("BranchBridgeHanger") then
			addLight(m:FindFirstChild("CANDLE", true), LAMP_LIGHT, 1.2, 34)
		end
		-- Carved Hollin lookout bench right beside the hanger.
		local bench = piece("CanopyBench", lm.X - 6, lm.Z + 3, 180, "HollinBench", 1.0, KEEP_TINT, function(cf)
			local wc, wm = sw(KEEP_TINT, "WOOD")
			boxAt("LookoutBench", V(8, 2.2, 2.8), cf * CFrame.new(0, 1.1, 0), wc, wm)
		end, lm.Y)
		pin(bench)
		props += 1
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 20–21. Sunken Warden's Boat & Severed Branch Bridge dangling uselessly into the rot bog.
	---------------------------------------------------------------------------------------------------
	do
		local boat = CorruptedFloor34.Landmarks[20]
		local mb = piece("SunkenBogBoat", boat.X, boat.Z, 34, "SunkenWardenBoat", 1.0, BOG_TINT, function(cf)
			local wc, wm = sw(BOG_TINT, "WOOD")
			boxAt("BogSkiff", V(15, 2.4, 6.2), cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0.15, 0, -0.2), wc, wm)
		end, bottom + 0.8)
		pin(mb)
		noCollide(mb)
		landmarks += 1

		-- Severed branch bridge hanging steeply into the bog muck — unmistakably broken & unwalkable!
		local sev = CorruptedFloor34.Landmarks[21]
		ctx.group("SeveredBogBridge", function()
			local wc, wm = sw(BOG_TINT, "WOOD")
			local rc, rm = sw(STRONGHOLD, "TRIM")
			local cf = CFrame.new(sev.X, bottom + 6.5, sev.Z) * CFrame.Angles(math.rad(42), math.rad(-26), math.rad(12))
			pin(noCollide(boxAt("SeveredDeck", V(14, 1.2, 16), cf, wc, wm)))
			for _, sx in { -6, 6 } do
				pin(noCollide(rod("SeveredRope", (cf * CFrame.new(sx, 0.5, -7)).Position, (cf * CFrame.new(sx, 14, -7)).Position, 0.25, rc, rm)))
			end
		end)
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 22. Mother Graft Near Horizon (much nearer than Floor 33, looming over the back-east canopy).
	---------------------------------------------------------------------------------------------------
	do
		local mg = CorruptedFloor34.Landmarks[22]
		local m = piece("MotherGraftNear", mg.X, mg.Z, -18, "HeartrotSpringTrunk", 1.95, ROTWOOD_TINT, function(cf)
			local wc, wm = sw(ROTWOOD_TINT, "WOOD")
			local gc, gm = sw(ROTWOOD_TINT, "GLOW")
			rod("MotherGraftBole", cf.Position, cf.Position + V(0, 175, 0), 16, wc, wm)
			local g = lump("MotherGraftHeart", (cf * CFrame.new(0, 32, 12)).Position, V(16, 28, 10), gc, gm)
			addLight(g, ROT_LIGHT, 1.6, 75)
		end, mg.Y)
		pin(m)
		if m and ctx.has("HeartrotSpringTrunk") then
			addLight(H.glowOf(m), ROT_LIGHT, 1.6, 75)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 23. Bog Stair Arrival Arch + flanking palisades + hanging warm arrival lantern.
	---------------------------------------------------------------------------------------------------
	do
		local safe = P.Sanctuary
		local z = safe.Z - safe.Depth / 2 + 3
		local stile = piece("BogStairArch", 0, z, 0, "HollinStileArch", 1.05, STRONGHOLD, function(cf)
			local wc, wm = sw(STRONGHOLD, "WOOD")
			for _, s in { -1, 1 } do
				rod("BogStilePost", (cf * CFrame.new(s * 22, 0, 0)).Position, (cf * CFrame.new(s * 22, 18, 0)).Position, 1.3, wc, wm)
			end
			boxAt("BogStileBeam", V(46, 2.2, 2.2), cf * CFrame.new(0, 20, 0), wc, wm)
		end, safe.Y)
		pin(stile)
		noCollide(stile)
		for _, sx in { -44, 44 } do
			local pw = piece("ArrivalPalisade", sx, z, 0, "StakePalisadeSegment", 0.9, STRONGHOLD, function(cf)
				local wc, wm = sw(STRONGHOLD, "WOOD")
				boxAt("ArrivalStake", V(18, 10, 2), cf * CFrame.new(0, 5, 0), wc, wm)
			end, safe.Y)
			pin(pw)
			props += 1
		end
		local lantern = piece("BogStairLantern", 23.5, z - 1.5, 0, "HangingLantern", 1.0, LAMP_TINT, function(cf)
			local gc, gm = sw(LAMP_TINT, "GLOW")
			local g = boxAt("BogLampGlow", V(1.6, 2.2, 1.6), cf * CFrame.new(0, 2, 0), gc, gm)
			addLight(g, LAMP_LIGHT, 1.3, 34)
		end, safe.Y + 11.5)
		noCollide(lantern)
		if lantern and ctx.has("HangingLantern") then
			addLight(H.glowOf(lantern), LAMP_LIGHT, 1.3, 34)
		end
		landmarks += 1
	end

	---------------------------------------------------------------------------------------------------
	-- 24. Corrupted BLIGHT Bog & Root-Plate Veins + Canopy-Gap Sunbeam Light Shafts (never over camps).
	---------------------------------------------------------------------------------------------------
	do
		local vc, vm = sw(ROTWOOD_TINT, "WOOD")
		local gc, gm = sw(ROTWOOD_TINT, "GLOW")
		-- Glowing magenta heartrot fissures snaking across the rot bog and climbing the five elder bases.
		local bogVeins = {
			{ { -148, -338 }, { -126, -264 }, { -96, -198 } },
			{ { -154, -338 }, { -188, -260 }, { -228, -206 } },
			{ { -56, -82 }, { -98, -110 }, { -146, -124 } },
			{ { -56, -82 }, { -34, -36 }, { -68, 22 } },
			{ { -225, -60 }, { -262, -96 }, { -298, -142 } },
			{ { 232, -40 }, { 268, -94 }, { 296, -144 } },
			{ { 232, -40 }, { 166, 12 }, { 108, 48 } },
			{ { -82, 46 }, { -142, 44 }, { -186, 18 } },
			{ { 42, 124 }, { 96, 148 }, { 150, 154 } },
			{ { -42, 124 }, { -96, 150 }, { -148, 152 } },
			{ { 42, -210 }, { 88, -224 }, { 156, -238 } },
			{ { -28, -208 }, { -86, -228 }, { -134, -258 } },
		}
		for _, chain in bogVeins do
			for i = 1, #chain - 1 do
				local a2, b2 = chain[i], chain[i + 1]
				local ya = (if field then field.Height(a2[1], a2[2]) else bottom) + 0.7
				local yb = (if field then field.Height(b2[1], b2[2]) else bottom) + 0.7
				ctx.group("BogBlightVein", function()
					pin(noCollide(rod("BogBlightGlow", V(a2[1], ya, a2[2]), V(b2[1], yb, b2[2]), 0.72, gc, gm)))
					pin(noCollide(rod("BogRootTendril", V(a2[1] + 1.6, ya + 0.4, a2[2] - 1.2), V(b2[1] + 1.6, yb + 0.4, b2[2] - 1.2), 1.2, vc, vm)))
				end)
			end
		end

		-- 4 atmospheric canopy-gap light shafts pouring down onto open rot-bog pools (off every camp & lane).
		for _, sh in { { -104, 10 }, { 106, 26 }, { 48, -212 }, { -126, -158 } } do
			ctx.group("CanopyLightShaft", function()
				local beam = ctx.block("LightShaftCone", V(18, 195, 18), V(sh[1], bottom + 98, sh[2]), SHAFT_COL, Mat.Neon, Enum.PartType.Cylinder, 0.91)
				beam.CFrame = CFrame.new(origin + V(sh[1], bottom + 98, sh[2])) * CFrame.Angles(0, 0, math.rad(82))
				beam.CastShadow = false
				pin(noCollide(beam))
			end)
		end

		-- 4 bog spore/mist plumes over the rot bog (total emitters = 6 <= 12).
		for _, sp in { { -115, 8 }, { 118, 22 }, { -88, -148 }, { 112, -216 } } do
			ctx.group("BogSporeMist", function()
				plume(V(sp[1], bottom + 3, sp[2]), rgb(176, 82, 232), 5.5, 4, 2.2, 5.0)
			end)
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 25. Branch Bridge Hangers, Broken Barricades, Bole Stair Posts, Bog Life & Perimeter Treeline.
	---------------------------------------------------------------------------------------------------
	-- Branch bridge hangers at safe offsets beside key bridge landings.
	local hangerSpots = {
		{ -36, 18, 20, 45 }, { 38, 18, 20, -45 }, { -114, -44, 26, 22 }, { 126, -34, 18, -22 },
		{ -198, -124, 32, 35 }, { 196, -120, 36, -35 }, { 92, -244, 44, -60 }, { -76, -244, 52, 60 },
	}
	for _, hs in hangerSpots do
		if free(hs[1], hs[2], 6) then
			local m = piece("BridgeHangerProp", hs[1], hs[2], hs[4], "BranchBridgeHanger", 0.92, KEEP_TINT, function(cf)
				local wc, wm = sw(KEEP_TINT, "WOOD")
				rod("HangerPost", cf.Position, cf.Position + V(0, 17, 0), 0.9, wc, wm)
			end, hs[3])
			pin(m)
			take(hs[1], hs[2], 6)
			props += 1
		end
	end

	-- Broken timber barricades & Pale Band cairns near climb tops & stockades.
	local extraTemplates = { "WattleFence", "FieldstoneCairn", "SawnStumpCluster", "FelledBandLog", "ThornKnotCluster", "BlightTree", "DeadTree", "CliffRockA", "CliffRockB", "CrutchPoleProp" }
	for _, spot in {
		{ -52, 246, "WattleFence" }, { 52, 246, "WattleFence" }, { -168, 248, "FieldstoneCairn" }, { 168, 248, "FieldstoneCairn" },
		{ -234, 228, "SawnStumpCluster" }, { 234, 228, "SawnStumpCluster" }, { -306, 214, "FelledBandLog" }, { 306, 214, "FelledBandLog" },
		{ -52, 186, "BlightTree" }, { 54, 186, "BlightTree" }, { -174, 188, "DeadTree" }, { 174, 188, "DeadTree" },
		{ -236, 176, "BlightTree" }, { 236, 176, "BlightTree" }, { -312, 186, "DeadTree" }, { 312, 186, "DeadTree" },
		{ -36, 218, "CliffRockA" }, { 38, 216, "CliffRockB" }, { -164, 214, "ThornKnotCluster" }, { 166, 214, "ThornKnotCluster" },
	} do
		local x, z, tpl = spot[1], spot[2], spot[3]
		if free(x, z, 6) then
			local gy = if field then field.Height(x, z) - 0.6 else 0
			local m = piece("LandingProp", x, z, rng:NextNumber(0, 360), tpl, rng:NextNumber(0.85, 1.15), STRONGHOLD, function(cf)
				local wc, wm = sw(STRONGHOLD, "WOOD")
				boxAt("PropStub", V(6, 4, 4), cf * CFrame.new(0, 2, 0), wc, wm)
			end, gy)
			pin(m)
			take(x, z, 6)
			props += 1
		end
	end

	-- Perimeter dead-forest & canopy-edge wall framing (searching inward to level ground so zero roots float!).
	local wallTrees = { "BlightTree", "DeadTree", "PaleBandTree", "GraftedFruitTreeC" }
	local wallRocks = { "CliffRockA", "CliffRockB", "BoulderCluster", "ThornKnotCluster", "Obelisk" }
	for attempt = 1, 560 do
		local side = attempt % 4
		local x, z = 0, 0
		if side == 0 then
			x = rng:NextNumber(-w / 2 + 24, w / 2 - 24)
			z = rng:NextNumber(-d / 2 + 24, -d / 2 + 120)
		elseif side == 1 then
			x = rng:NextNumber(-w / 2 + 24, w / 2 - 24)
			z = rng:NextNumber(d / 2 - 140, d / 2 - 24)
		elseif side == 2 then
			x = rng:NextNumber(-w / 2 + 24, -w / 2 + 110)
			z = rng:NextNumber(-d / 2 + 30, d / 2 - 30)
		else
			x = rng:NextNumber(w / 2 - 110, w / 2 - 24)
			z = rng:NextNumber(-d / 2 + 30, d / 2 - 30)
		end
		if free(x, z, 8) and (not field or field.Slope(x, z) < 0.72) then
			local gy = if field then field.Height(x, z) - 1.2 else bottom
			local isTree = attempt % 3 ~= 0
			local tpl = if isTree then wallTrees[(attempt % #wallTrees) + 1] else wallRocks[(attempt % #wallRocks) + 1]
			local sc = if isTree then rng:NextNumber(0.95, 1.45) else rng:NextNumber(0.85, 1.35)
			local m = piece(if isTree then "PerimeterElder" else "PerimeterCrag", x, z, rng:NextNumber(0, 360), tpl, sc, ROTWOOD_TINT, function(cf)
				local wc, wm = sw(ROTWOOD_TINT, "WOOD")
				rod("RimTrunk", cf.Position, cf.Position + V(0, 24, 0), 1.8, wc, wm)
			end, gy)
			pin(m)
			take(x, z, 8)
			props += 1
		end
	end

	-- Bog floor props (half-sunk logs, shelf clusters, thorn knots, blight rocks, rot-rose clusters) & dense
	-- corrupted bog ground cover (rot-blooms, blight pods, reeds, spore moss, autumn grass tufts).
	local bogProps = { "FelledBandLog", "SawnStumpCluster", "ThornKnotCluster", "CliffRockA", "CliffRockB", "BoulderCluster", "RuinRubble", "GiantMushroom", "ShelfFungusBracket", "BlightTree", "DeadTree", "GraftKnotPost", "StakePalisadeSegment" }
	for i = 1, 950 do
		local x = rng:NextNumber(-w / 2 + 26, w / 2 - 26)
		local z = rng:NextNumber(-d / 2 + 26, d / 2 - 26)
		if props < 560 and free(x, z, 5) and (not field or field.Slope(x, z) < 0.75) then
			local gy = if field then field.Height(x, z) - 0.6 else bottom
			local tpl = bogProps[(i % #bogProps) + 1]
			local sc = if tpl == "ShelfFungusBracket" then rng:NextNumber(0.35, 0.55) elseif tpl == "StakePalisadeSegment" then 0.65 else rng:NextNumber(0.75, 1.25)
			local m = piece("BogStrongholdProp", x, z, rng:NextNumber(0, 360), tpl, sc, if i % 4 == 0 then FUNGUS_TINT else BOG_TINT, function(cf)
				local wc, wm = sw(BOG_TINT, "WOOD")
				lump("BogClump", cf.Position + V(0, 1.8, 0), V(5, 3.2, 5), wc, wm)
			end, gy)
			pin(m)
			take(x, z, 5)
			props += 1
		end
	end

	local coverTemplates = { "RotBloomCluster", "BlightPod", "ReedPondCluster", "SporeMoss", "AutumnGrassTuft", "MushroomCluster", "FoliageBush", "PadCap" }
	for i = 1, 1200 do
		if cover >= 420 then break end
		local x = rng:NextNumber(-w / 2 + 20, w / 2 - 20)
		local z = rng:NextNumber(-d / 2 + 20, d / 2 - 20)
		if free(x, z, 2.5) and (not field or field.Slope(x, z) < 0.85) then
			local gy = if field then field.Height(x, z) - 0.2 else bottom
			local tpl = coverTemplates[(i % #coverTemplates) + 1]
			local sc = rng:NextNumber(0.8, 1.35)
			local m = piece("BogGroundCover", x, z, rng:NextNumber(0, 360), tpl, sc, if i % 3 == 0 then FUNGUS_TINT else STRONGHOLD, function(cf)
				local cc, cm = sw(FUNGUS_TINT, "CAP")
				lump("BogTuft", cf.Position + V(0, 0.9, 0), V(3.2, 1.6, 3.2), cc, cm)
			end, gy)
			pin(m)
			noCollide(m)
			cover += 1
		end
	end

	ctx.setAttribute("Floor34Landmarks", landmarks)
	ctx.setAttribute("Floor34Props", props)
	ctx.setAttribute("Floor34GroundCover", cover)
end

return CorruptedFloor34
