--!strict
-- Hand-authored set pieces for Sunken Sanctuary Floor 37: Coral Cloister (sunken:2).
-- Guide image: reference/Sunken Sanctuary 37.jpg. Design: docs/prompts/sunken-sanctuary-floor-layouts-prompt.md.
--
-- The Nereth cantors' double cloister, a figure-eight of two arcaded walks around two flooded squircle garths
-- under warm gold-green afternoon light: the Lay Gate flanked by robed Cantor niche statues and bells; Lay
-- Court with its tide-spiral plaza mosaic; the south garth (with a drowned stone sundial underwater) crossed by
-- the flagged Garth Causeway under twin bell arches; the domed Lavabo fountain house at the waist with its
-- giant scalloped shell basin and bronze fish-head spouts; the wide north garth keeping impassable turquoise
-- water between the Lavabo and Chapter Isle (with a second drowned sundial); Chapter Isle crowned by an open
-- octagonal ribbed-vault Chapter House, cantors' stalls and a blue-and-gold tide-spiral mosaic; side cloister
-- wings for the Dorter, Frater, Choir Loft, Sacristy and Scriptorium; the 150-stud Campanile Bell Tower behind
-- the isle flanked by coral-draped rear arcades; and the curved sunlit Tidewall on three sides with gliding
-- mantas and the drowned city's verdigris domes beyond.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local SunkenFloor37 = {}

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

-- Warm gold-green cloister palette: every role of every Floor 36/37 template explicitly tinted so nothing
-- falls back to the biome default. Coral stays pink-violet, pale cream, aqua or warm ochre — never crimson
-- (255, 25, 55) or hot orange (255, 95, 40) — so enemy telegraphs stay unmistakable.
local CLOISTER = table.freeze({
	STONE = swatch(216, 206, 182, Mat.Limestone), -- sun-warmed pale limestone
	TRIM = swatch(234, 228, 212, Mat.Marble), -- carved white marble trim & robes
	METAL = swatch(130, 102, 62, Mat.Metal), -- weathered temple bronze
	ACCENT = swatch(82, 162, 140, Mat.Metal), -- verdigris roofs, bells & cupola
	GOLD = swatch(232, 192, 98, Mat.Metal), -- warm afternoon gilt
	GLOW = swatch(112, 240, 234, Mat.Neon), -- aqua rune-light & tide-charts
	CANDLE = swatch(255, 214, 144, Mat.Neon), -- warm cloister lamps
	WOOD = swatch(112, 90, 68, Mat.Wood), -- drowned cedar & bell-yokes
	SILK = swatch(232, 226, 208, Mat.Fabric), -- pale cantor vestments & banners
	FOLIAGE = swatch(68, 134, 92, Mat.Grass), -- kelp curtains & seagrass
	MOSS = swatch(74, 118, 82, Mat.Grass), -- waterline algae & moss
	CORAL = swatch(216, 134, 192, Mat.SmoothPlastic), -- pink-violet reef coral
	ALT = swatch(240, 228, 208, Mat.SmoothPlastic), -- pearl & scallop shell
	CRYSTAL = swatch(154, 232, 228, Mat.Glass, 0.25), -- clear garth water & spouts
})
local CORAL_CREAM = tinted(CLOISTER, { CORAL = swatch(236, 226, 214, Mat.SmoothPlastic) })
local CORAL_AQUA = tinted(CLOISTER, { CORAL = swatch(104, 206, 194, Mat.SmoothPlastic), GLOW = swatch(148, 252, 236, Mat.Neon) })
local CORAL_OCHRE = tinted(CLOISTER, { CORAL = swatch(218, 186, 116, Mat.SmoothPlastic) })
local CORAL_LILAC = tinted(CLOISTER, { CORAL = swatch(184, 138, 216, Mat.SmoothPlastic) })
local CORAL_TINTS = { CLOISTER, CORAL_CREAM, CORAL_AQUA, CORAL_OCHRE, CORAL_LILAC }

local AQUA_LIGHT = rgb(116, 242, 236)
local LAMP_LIGHT = rgb(255, 212, 144)
local GARTH_LIGHT = rgb(104, 218, 198)

-- Floor 37's landmark footprints (room-local, scaled and turned), spec-checked offline against every walkway
-- lane, every camp and both boss portals, and reserved so the scatter passes keep off them.
SunkenFloor37.Floor37Landmarks = table.freeze({
	{ Id = "CampanileBellTower", X = 0, Z = -329, Y = 34, HalfX = 14.5, HalfZ = 14.2, Top = 150 },
	{ Id = "LavaboFountainHouse", X = 0, Z = -108, Y = 12, HalfX = 13.8, HalfZ = 13.6, Top = 32.5 },
	{ Id = "ChapterHouseNorthRib", X = 0, Z = -242, Y = 40, HalfX = 10.4, HalfZ = 6, Top = 41.5 },
	{ Id = "ChapterHouseNWRib", X = -44, Z = -224, Y = 40, HalfX = 10.4, HalfZ = 10.4, Top = 41.5 },
	{ Id = "ChapterHouseNERib", X = 44, Z = -224, Y = 40, HalfX = 10.4, HalfZ = 10.4, Top = 41.5 },
	{ Id = "ChapterHouseSWRib", X = -52, Z = -140, Y = 40, HalfX = 10.4, HalfZ = 10.4, Top = 41.5 },
	{ Id = "ChapterHouseSERib", X = 52, Z = -140, Y = 40, HalfX = 10.4, HalfZ = 10.4, Top = 41.5 },
	{ Id = "ChapterHouseSouthRib", X = 0, Z = -134, Y = 40, HalfX = 10.4, HalfZ = 6, Top = 41.5 },
	{ Id = "LayGateWestStatue", X = -32, Z = 289, Y = 8, HalfX = 4.5, HalfZ = 3.2, Top = 18.7 },
	{ Id = "LayGateEastStatue", X = 32, Z = 289, Y = 8, HalfX = 4.5, HalfZ = 3.2, Top = 18.7 },
	{ Id = "SouthGarthSundial", X = 54, Z = 70, Y = -10, HalfX = 11.2, HalfZ = 11.2, Top = 4.7 },
	{ Id = "NorthGarthSundial", X = -82, Z = -134, Y = -10, HalfX = 11.2, HalfZ = 11.2, Top = 4.7 },
	{ Id = "WestWalkArcade", X = -194, Z = 88, Y = 8, HalfX = 5.0, HalfZ = 24.0, Top = 30.3 },
	{ Id = "EastWalkArcade", X = 194, Z = 88, Y = 12, HalfX = 5.0, HalfZ = 24.0, Top = 30.3 },
	{ Id = "DorterWing", X = -270, Z = -46, Y = 4, HalfX = 8.0, HalfZ = 14.0, Top = 10.0 },
	{ Id = "FraterRefectory", X = 266, Z = -46, Y = 10, HalfX = 9.0, HalfZ = 14.0, Top = 8.0 },
	{ Id = "ChoirLoftStalls", X = -270, Z = -152, Y = 26, HalfX = 8.0, HalfZ = 14.0, Top = 9.0 },
	{ Id = "ScriptoriumWing", X = 270, Z = -152, Y = 30, HalfX = 8.0, HalfZ = 14.0, Top = 14.0 },
	{ Id = "SacristyPresses", X = -270, Z = -312, Y = 28, HalfX = 10.0, HalfZ = 6.0, Top = 14.2 },
	{ Id = "RearCloisterWest", X = -64, Z = -328, Y = 28, HalfX = 24.0, HalfZ = 5.0, Top = 30.3 },
	{ Id = "RearCloisterEast", X = 64, Z = -328, Y = 28, HalfX = 24.0, HalfZ = 5.0, Top = 30.3 },
	{ Id = "TidewallNorth", X = 0, Z = -341, Y = -4, HalfX = 315, HalfZ = 3.5, Top = 228 },
}) :: { Landmark }

-- The open north garth gap between the Lavabo and Chapter Isle (must stay open water, no bridge).
SunkenFloor37.NorthGarthGap = table.freeze({ X = 0, Z = -118 })

local function facing(x: number, z: number, tx: number, tz: number): number
	return math.deg(math.atan2(tx - x, tz - z))
end

function SunkenFloor37.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number = H.field, H.bottom, H.d
	local w: number = ctx.w
	local layout = ctx.layout
	local P = layout.Platforms
	local boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local origin: Vector3 = ctx.origin
	local waterY: number = if field then field.LiquidLevel else bottom
	local seabed = bottom - 5.5
	local landmarks, props, cover = 0, 0, 0
	local kindsUsed: { [string]: number } = {}
	local rng = Random.new(37 * 7919)

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
	local function pinnedGroup(kind: string, build: () -> ())
		ctx.group(kind, function()
			ctx.tag("OnTerrain", true)
			build()
		end)
	end
	local function count(kitName: string?)
		if kitName then kindsUsed[kitName] = (kindsUsed[kitName] or 0) + 1 end
	end

	for _, lm in SunkenFloor37.Floor37Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end
	local taken: { { number } } = {}
	for _, lm in SunkenFloor37.Floor37Landmarks do
		if lm.Id ~= "TidewallNorth" then
			table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
		end
	end
	-- A spot is free when it stays inside the room, clear of every camp (36 studs + radius), clear of taken spots
	-- and clear of every walkway lane.
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
	-- Part-built fallbacks (shown until SunkenF37Kit.fbx / SunkenF36Kit.fbx are uploaded to Roblox).
	-- Every fallback matches its Blender template's silhouette, roles and origin (standing on y = 0, +Z front).
	---------------------------------------------------------------------------------------------------
	local function fbMiniBell(tint: any, cf: CFrame, s: number)
		local ac, am = sw(tint, "ACCENT")
		local gc, gm = sw(tint, "GOLD")
		local wc, wm = sw(tint, "WOOD")
		boxAt("CloisterBellBody", V(3.0, 2.8, 3.0) * s, cf * CFrame.new(0, 1.6 * s, 0), ac, am)
		boxAt("CloisterBellLip", V(3.6, 0.5, 3.6) * s, cf * CFrame.new(0, 0.25 * s, 0), gc, gm)
		boxAt("CloisterBellYoke", V(3.8, 0.7, 0.7) * s, cf * CFrame.new(0, 3.3 * s, 0), wc, wm)
	end
	local function fbBellArch(tint: any, s: number): (CFrame) -> ()
		return function(cf: CFrame)
			local sc, sm = sw(tint, "STONE")
			local tc, tm = sw(tint, "TRIM")
			local cc, cm = sw(tint, "CORAL")
			for _, x in { -14.8, 14.8 } do
				boxAt("BellArchPier", V(4.8, 22, 6.0) * s, cf * CFrame.new(x * s, 11 * s, 0), sc, sm)
				boxAt("BellArchCap", V(5.6, 1.8, 6.6) * s, cf * CFrame.new(x * s, 22.5 * s, 0), tc, tm)
			end
			for k = 0, 5 do
				local a0 = math.pi * (k + 0.5) / 6
				boxAt("BellArchVoussoir", V(8.0, 4.2, 5.8) * s, cf * CFrame.new(math.cos(a0) * 14.8 * s, (23 + math.sin(a0) * 11.2) * s, 0) * CFrame.Angles(0, 0, a0), sc, sm)
			end
			boxAt("BellArchKeystone", V(4.0, 5.2, 6.4) * s, cf * CFrame.new(0, 34.6 * s, 0), tc, tm)
			lump("BellArchCoral", (cf * CFrame.new(5.5 * s, 36.2 * s, 0)).Position, V(7, 4, 5) * s, cc, cm)
			fbMiniBell(tint, cf * CFrame.new(0, 25.5 * s, 0), 1.45 * s)
		end
	end
	local function fbArcadeBay(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local sc, sm = sw(tint, "STONE")
			local tc, tm = sw(tint, "TRIM")
			local vc, vm = sw(tint, "ACCENT")
			local cc, cm = sw(tint, "CORAL")
			for _, x in { -9.2, 9.2 } do
				boxAt("ArcadePlinth", V(3.8, 1.8, 3.8), cf * CFrame.new(x, 0.9, 0), tc, tm)
				local col = boxAt("ArcadeCol", V(14.8, 2.3, 2.3), cf * CFrame.new(x, 9.2, 0) * CFrame.Angles(0, 0, math.pi / 2), sc, sm)
				col.Shape = Enum.PartType.Cylinder
				boxAt("ArcadeCap", V(3.4, 1.4, 3.4), cf * CFrame.new(x, 16.8, 0), tc, tm)
			end
			for k = 0, 5 do
				local a0 = math.pi * (k + 0.5) / 6
				boxAt("ArcadeVoussoir", V(5.2, 2.1, 3.0), cf * CFrame.new(math.cos(a0) * 9.2, 17.2 + math.sin(a0) * 6.0, 0) * CFrame.Angles(0, 0, a0), sc, sm)
			end
			boxAt("ArcadeCornice", V(22.4, 1.5, 3.8), cf * CFrame.new(0, 24.8, 0), sc, sm)
			for _, sy in { -1, 1 } do
				boxAt("ArcadeRoof", V(23.0, 0.9, 4.5), cf * CFrame.new(0, 26.8, sy * 1.9) * CFrame.Angles(sy * 0.42, 0, 0), vc, vm)
			end
			boxAt("ArcadeRidge", V(23.2, 1.0, 1.1), cf * CFrame.new(0, 28.0, 0), tc, tm)
			fbMiniBell(tint, cf * CFrame.new(0, 18.2, 0), 1.05)
			for _, cx in { -6.5, 0.5, 6.8 } do
				lump("ArcadeCoral", (cf * CFrame.new(cx, 28.8, 0.4)).Position, V(4.8, 3.2, 4.2), cc, cm)
			end
		end
	end
	local function fbArcadeCorner(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local sc, sm = sw(tint, "STONE")
			local tc, tm = sw(tint, "TRIM")
			local vc, vm = sw(tint, "ACCENT")
			local cc, cm = sw(tint, "CORAL")
			boxAt("CornerPier", V(4.4, 17.4, 4.4), cf * CFrame.new(0, 8.7, 0), sc, sm)
			boxAt("CornerCap", V(5.0, 1.6, 5.0), cf * CFrame.new(0, 17.6, 0), tc, tm)
			for _, ang in { 0, math.pi / 2 } do
				local rcf = cf * CFrame.Angles(0, ang, 0)
				boxAt("CornerWingCol", V(2.4, 16.5, 2.4), rcf * CFrame.new(11.5, 8.25, 0), sc, sm)
				boxAt("CornerWingBeam", V(12.6, 2.4, 3.2), rcf * CFrame.new(5.8, 22.8, 0), sc, sm)
				boxAt("CornerWingRoof", V(13.2, 1.2, 4.4), rcf * CFrame.new(5.8, 24.8, 0), vc, vm)
				fbMiniBell(tint, rcf * CFrame.new(5.8, 17.5, 0), 0.9)
			end
			boxAt("CornerSpire", V(5.6, 5.2, 5.6), cf * CFrame.new(0, 26.8, 0), vc, vm)
			lump("CornerCoral", (cf * CFrame.new(2, 27.6, 2)).Position, V(5.4, 3.6, 5.4), cc, cm)
		end
	end
	local function fbCampanile(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local tc, tm = sw(CLOISTER, "TRIM")
		local vc, vm = sw(CLOISTER, "ACCENT")
		local gc, gm = sw(CLOISTER, "GOLD")
		local glc, glm = sw(CLOISTER, "GLOW")
		local cc, cm = sw(CLOISTER, "CORAL")
		boxAt("CampanilePlinth", V(28, 12, 28), cf * CFrame.new(0, 6, 0), sc, sm)
		boxAt("CampanileShaft", V(20.6, 66, 20.6), cf * CFrame.new(0, 45, 0), sc, sm)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				boxAt("CampanileButtress", V(3.6, 74, 3.6), cf * CFrame.new(sx * 10.2, 42, sz * 10.2), tc, tm)
			end
		end
		for _, zy in { 30, 52, 76 } do
			boxAt("CampanileBand", V(23.4, 2.0, 23.4), cf * CFrame.new(0, zy, 0), tc, tm)
		end
		-- Glowing tide-spiral medallion on the south face
		boxAt("CampanileRune", V(5.6, 5.6, 0.8), cf * CFrame.new(0, 62, 10.6), glc, glm)
		-- Open belfry chamber with twin hanging bells
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				boxAt("BelfryPier", V(4.6, 28, 4.6), cf * CFrame.new(sx * 8.2, 92, sz * 8.2), sc, sm)
			end
		end
		boxAt("BelfryCornice", V(24.6, 3.2, 24.6), cf * CFrame.new(0, 107.4, 0), tc, tm)
		fbMiniBell(CLOISTER, cf * CFrame.new(-3.8, 84, 0), 2.2)
		fbMiniBell(CLOISTER, cf * CFrame.new(3.8, 84, 0), 2.2)
		-- Steep tiered verdigris spire reaching Y = 150
		for k = 0, 5 do
			local f = k / 6
			local sz = 21 * (1 - f * 0.86)
			boxAt("CampanileSpire", V(sz, 6.6, sz), cf * CFrame.new(0, 111.5 + k * 6.0, 0), vc, vm)
		end
		boxAt("CampanileFinial", V(1.6, 6.0, 1.6), cf * CFrame.new(0, 147, 0), gc, gm)
		for _, pt in { V(-11, 20, 10), V(11, 32, 10), V(0, 77, 11) } do
			lump("CampanileCoral", (cf * CFrame.new(pt)).Position, V(7, 5, 6), cc, cm)
		end
	end
	local function fbChapterRib(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local sc, sm = sw(tint, "STONE")
			local tc, tm = sw(tint, "TRIM")
			local vc, vm = sw(tint, "ACCENT")
			local cc, cm = sw(tint, "CORAL")
			local glc, glm = sw(tint, "GLOW")
			for _, sx in { -1, 1 } do
				boxAt("ChapterPier", V(3.4, 21, 3.8), cf * CFrame.new(sx * 8.4, 10.5, 0), sc, sm)
				boxAt("ChapterButtress", V(2.4, 11, 4.0), cf * CFrame.new(sx * 8.4, 5.5, -3.2), sc, sm)
				boxAt("ChapterCap", V(4.0, 1.6, 4.4), cf * CFrame.new(sx * 8.4, 21.4, 0), tc, tm)
				-- Continuous sweeping broken gothic vault ribs arching inward (+Z in Roblox)
				local prevPt = (cf * CFrame.new(sx * 8.4, 21.8, 0)).Position
				for k = 1, 5 do
					local f = k / 5
					local nextPt = (cf * CFrame.new(sx * 8.4 * (1 - f * 0.45), 21.8 + math.sin(f * math.pi * 0.52) * 19.2, f * 13.8)).Position
					rod("ChapterVaultRib", prevPt, nextPt, 1.05 - f * 0.25, sc, sm).CanCollide = false
					prevPt = nextPt
				end
			end
			boxAt("ChapterParapet", V(15.2, 3.2, 2.0), cf * CFrame.new(0, 1.6, -0.5), sc, sm)
			for _, sx in { -1, 1 } do
				boxAt("ChapterArch", V(10.5, 2.2, 2.8), cf * CFrame.new(sx * 4.2, 26.2, 0) * CFrame.Angles(0, 0, sx * -0.78), sc, sm)
			end
			boxAt("ChapterEave", V(19.6, 1.4, 3.4), cf * CFrame.new(0, 30.8, -0.6), vc, vm)
			lump("ChapterOrb", (cf * CFrame.new(0, 26.2, 0)).Position, V(2.2, 2.2, 2.2), glc, glm)
			lump("ChapterCoral", (cf * CFrame.new(0, 32.4, -0.6)).Position, V(8.0, 3.6, 4.4), cc, cm)
		end
	end
	local function fbLavabo(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local tc, tm = sw(CLOISTER, "TRIM")
		local vc, vm = sw(CLOISTER, "ACCENT")
		local ac, am = sw(CLOISTER, "ALT")
		local gc, gm = sw(CLOISTER, "GOLD")
		local glc, glm = sw(CLOISTER, "GLOW")
		local wc, wm = sw(CLOISTER, "CRYSTAL")
		local cc, cm = sw(CLOISTER, "CORAL")
		local base = boxAt("LavaboBasin", V(2.8, 24.4, 24.4), cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), tc, tm)
		base.Shape = Enum.PartType.Cylinder
		local pool = boxAt("LavaboPool", V(0.5, 20.0, 20.0), cf * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, 0, math.pi / 2), wc, wm, 0.25)
		pool.Shape = Enum.PartType.Cylinder
		-- Giant glowing scalloped shell bowl in the center
		lump("LavaboShellBowl", (cf * CFrame.new(0, 6.4, 0)).Position, V(10.6, 4.8, 9.8), ac, am)
		lump("LavaboShellGlow", (cf * CFrame.new(0, 7.8, 0)).Position, V(6.4, 1.4, 6.0), rgb(255, 218, 148), Mat.Neon)
		-- 6 columns + ribbed verdigris cupola dome
		for k = 0, 5 do
			local a = k * math.pi / 3
			local col = boxAt("LavaboCol", V(13.5, 1.7, 1.7), cf * CFrame.new(math.cos(a) * 10.4, 9.8, math.sin(a) * 10.4) * CFrame.Angles(0, 0, math.pi / 2), sc, sm)
			col.Shape = Enum.PartType.Cylinder
		end
		local drum = boxAt("LavaboDrum", V(2.2, 22.0, 22.0), cf * CFrame.new(0, 18.8, 0) * CFrame.Angles(0, 0, math.pi / 2), tc, tm)
		drum.Shape = Enum.PartType.Cylinder
		lump("LavaboDome", (cf * CFrame.new(0, 23.2, 0)).Position, V(22.0, 11.0, 22.0), vc, vm)
		boxAt("LavaboFinial", V(1.4, 4.2, 1.4), cf * CFrame.new(0, 29.0, 0), gc, gm)
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.4
			lump("LavaboCoral", (cf * CFrame.new(math.cos(a) * 10.4, 20.6, math.sin(a) * 10.4)).Position, V(4.2, 3.0, 4.2), cc, cm)
		end
		local _ = glc, glm
	end
	local function fbStall(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local tc, tm = sw(CLOISTER, "TRIM")
		local wc, wm = sw(CLOISTER, "WOOD")
		boxAt("StallBase", V(10.4, 1.0, 4.6), cf * CFrame.new(0, 0.5, 0), sc, sm)
		boxAt("StallSeat", V(9.6, 0.5, 2.2), cf * CFrame.new(0, 2.4, 0.4), wc, wm)
		boxAt("StallBack", V(10.2, 6.2, 1.0), cf * CFrame.new(0, 4.1, -1.5), sc, sm)
		boxAt("StallCap", V(10.6, 0.8, 1.5), cf * CFrame.new(0, 7.3, -1.5), tc, tm)
	end
	local function fbConchRack(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local ac, am = sw(CLOISTER, "ALT")
		local vc, vm = sw(CLOISTER, "ACCENT")
		boxAt("ConchRackFrame", V(6.6, 5.4, 1.4), cf * CFrame.new(0, 2.7, 0), sc, sm)
		for _, y in { 2.5, 4.6 } do
			boxAt("ConchRackBar", V(5.8, 0.4, 0.4), cf * CFrame.new(0, y, 0.5), vc, vm)
			for _, sx in { -1.4, 1.4 } do
				lump("ConchHorn", (cf * CFrame.new(sx, y + 0.4, 0.7)).Position, V(1.8, 1.2, 1.2), ac, am)
			end
		end
	end
	local function fbRefectoryTable(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local wc, wm = sw(CLOISTER, "WOOD")
		local gc, gm = sw(CLOISTER, "GOLD")
		local cc, cm = sw(CLOISTER, "CANDLE")
		for _, sx in { -6.5, 0, 6.5 } do
			boxAt("TableTrestle", V(1.4, 3.0, 4.0), cf * CFrame.new(sx, 1.5, 0), sc, sm)
		end
		boxAt("TableTop", V(17.4, 0.6, 4.8), cf * CFrame.new(0, 3.3, 0), wc, wm)
		for _, sz in { -3.5, 3.5 } do
			boxAt("TableBench", V(16.0, 0.45, 1.4), cf * CFrame.new(0, 1.85, sz), wc, wm)
		end
		boxAt("Candelabrum", V(2.2, 1.8, 0.4), cf * CFrame.new(0, 4.5, 0), gc, gm)
		boxAt("CandleFlame", V(1.6, 0.8, 0.3), cf * CFrame.new(0, 5.6, 0), cc, cm)
	end
	local function fbScriptoriumDesk(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local vc, vm = sw(CLOISTER, "ACCENT")
		local gc, gm = sw(CLOISTER, "GOLD")
		local glc, glm = sw(CLOISTER, "GLOW")
		boxAt("ScribeDesk", V(8.6, 3.4, 3.8), cf * CFrame.new(0, 1.7, 0.8), sc, sm)
		boxAt("ChartFrame", V(9.6, 9.6, 1.1), cf * CFrame.new(0, 8.4, -2.0), sc, sm)
		boxAt("ChartSlate", V(8.2, 8.0, 1.25), cf * CFrame.new(0, 8.4, -1.95), vc, vm)
		boxAt("ChartGlow", V(4.2, 4.2, 0.25), cf * CFrame.new(0, 8.4, -1.25), glc, glm)
		boxAt("ChartGold", V(6.2, 0.3, 0.25), cf * CFrame.new(0, 8.4, -1.22), gc, gm)
	end
	local function fbSacristyPress(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local slc, slm = sw(CLOISTER, "SILK")
		local vc, vm = sw(CLOISTER, "ACCENT")
		local wc, wm = sw(CLOISTER, "WOOD")
		boxAt("PressFrame", V(7.8, 12.6, 3.6), cf * CFrame.new(-1.2, 6.3, 0), sc, sm)
		for _, rx in { -2.5, 0.1 } do
			boxAt("CantorRobe", V(2.0, 6.4, 1.0), cf * CFrame.new(rx, 6.0, 0.4), slc, slm)
		end
		local bin = boxAt("RopeBin", V(3.4, 3.8, 3.8), cf * CFrame.new(4.6, 1.7, 0.2) * CFrame.Angles(0, 0, math.pi / 2), vc, vm)
		bin.Shape = Enum.PartType.Cylinder
		lump("BellRopeCoil", (cf * CFrame.new(4.6, 3.8, 0.2)).Position, V(2.8, 1.6, 2.8), wc, wm)
	end
	local function fbNicheStatue(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local tc, tm = sw(CLOISTER, "TRIM")
		local ac, am = sw(CLOISTER, "ALT")
		local vc, vm = sw(CLOISTER, "ACCENT")
		boxAt("NicheBase", V(7.4, 3.2, 4.8), cf * CFrame.new(0, 1.6, 0), sc, sm)
		boxAt("NicheBack", V(7.4, 14.5, 1.6), cf * CFrame.new(0, 10.4, -1.4), sc, sm)
		boxAt("StatueBody", V(3.4, 10.6, 2.8), cf * CFrame.new(0, 8.8, 0.2), tc, tm)
		lump("StatueHead", (cf * CFrame.new(0, 14.8, 0.3)).Position, V(2.2, 2.4, 2.2), tc, tm)
		lump("StatueConch", (cf * CFrame.new(-0.2, 11.4, 1.5)).Position, V(1.6, 1.4, 1.4), ac, am)
		boxAt("StatueStaff", V(0.5, 12.6, 0.5), cf * CFrame.new(1.9, 10.2, 1.0), vc, vm)
	end
	local function fbSundial(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local tc, tm = sw(CLOISTER, "TRIM")
		local vc, vm = sw(CLOISTER, "ACCENT")
		local gc, gm = sw(CLOISTER, "GOLD")
		local disc = boxAt("SundialDisc", V(1.2, 22.0, 22.0), cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), sc, sm)
		disc.Shape = Enum.PartType.Cylinder
		local face = boxAt("SundialFace", V(0.3, 18.8, 18.8), cf * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.pi / 2), tc, tm)
		face.Shape = Enum.PartType.Cylinder
		for k = 0, 5 do
			boxAt("SundialSpoke", V(16.0, 0.25, 0.45), cf * CFrame.new(0, 1.42, 0) * CFrame.Angles(0, k * math.pi / 6, 0), gc, gm)
		end
		boxAt("SundialGnomon", V(0.6, 3.6, 6.2), cf * CFrame.new(0, 2.8, -0.6) * CFrame.Angles(0.4, 0, 0), vc, vm)
	end
	local function fbBrainCoral(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local cc, cm = sw(tint, "CORAL")
			local sc, sm = sw(tint, "STONE")
			lump("BrainCoralBase", (cf * CFrame.new(0, 1.2, 0)).Position, V(9.4, 2.4, 8.6), sc, sm)
			lump("BrainCoralDomeA", (cf * CFrame.new(0, 3.0, 0)).Position, V(6.6, 4.6, 6.2), cc, cm)
			lump("BrainCoralDomeB", (cf * CFrame.new(2.8, 2.2, 1.2)).Position, V(4.6, 3.4, 4.4), cc, cm)
		end
	end
	local function fbDorterCot(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local slc, slm = sw(CLOISTER, "SILK")
		local wc, wm = sw(CLOISTER, "WOOD")
		local cc, cm = sw(CLOISTER, "CANDLE")
		boxAt("CotPlinth", V(7.8, 1.5, 4.4), cf * CFrame.new(0, 0.75, 0), sc, sm)
		boxAt("CotBedding", V(7.2, 0.8, 3.8), cf * CFrame.new(0, 1.85, 0), slc, slm)
		for _, sx in { -3.6, 3.6 } do
			for _, sz in { -1.9, 1.9 } do
				boxAt("CotPost", V(0.45, 8.2, 0.45), cf * CFrame.new(sx, 4.2, sz), wc, wm)
			end
		end
		boxAt("CotCurtain", V(7.0, 5.6, 0.25), cf * CFrame.new(0, 5.2, -1.8), slc, slm)
		boxAt("CotLampStand", V(1.5, 2.4, 1.5), cf * CFrame.new(-4.9, 1.2, -0.4), sc, sm)
		lump("CotLampGlow", (cf * CFrame.new(-4.9, 2.8, -0.4)).Position, V(0.9, 0.9, 0.9), cc, cm)
	end
	local function fbLamp(cf: CFrame)
		local mc, mm = sw(CLOISTER, "METAL")
		local cc, cm = sw(CLOISTER, "CANDLE")
		local bowl = boxAt("VotiveBowl", V(0.8, 2.6, 2.6), cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), mc, mm)
		bowl.Shape = Enum.PartType.Cylinder
		boxAt("VotiveFlame", V(0.5, 1.2, 0.5), cf * CFrame.new(0, 1.3, 0), cc, cm)
	end
	local function fbTablet(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local gc, gm = sw(CLOISTER, "GLOW")
		boxAt("RuneTabletSlab", V(4.4, 9, 1.4), cf * CFrame.new(0, 4.5, 0), sc, sm)
		boxAt("RuneTabletGlyph", V(2.2, 2.2, 0.2), cf * CFrame.new(0, 6.6, 0.75), gc, gm)
	end
	local function fbLectern(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local tc, tm = sw(CLOISTER, "TRIM")
		boxAt("LecternPillar", V(1.6, 4, 1.6), cf * CFrame.new(0, 2, 0), sc, sm)
		boxAt("LecternSlab", V(3.6, 0.45, 2.6), cf * CFrame.new(0, 4.5, 0) * CFrame.Angles(0.42, 0, 0), tc, tm)
	end
	local function fbClam(cf: CFrame)
		local ac, am = sw(CLOISTER, "ALT")
		lump("ClamValve", (cf * CFrame.new(0, 1, 0)).Position, V(7.5, 2.2, 5.8), ac, am)
		lump("ClamPearl", (cf * CFrame.new(0, 2.1, 0.4)).Position, V(1.8, 1.8, 1.8), rgb(242, 240, 234), Mat.SmoothPlastic)
	end
	local function fbKelp(cf: CFrame)
		local fc, fm = sw(CLOISTER, "FOLIAGE")
		for k = 0, 3 do
			local a = k * math.pi / 2
			rod("KelpStipe", (cf * CFrame.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)).Position, (cf * CFrame.new(math.cos(a) * 2.2, 17 + k * 2, math.sin(a) * 2.2)).Position, 0.34, fc, fm)
		end
	end
	local function fbCoral(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local cc, cm = sw(tint, "CORAL")
			for k = 0, 3 do
				local a = k * math.pi / 2 + 0.4
				rod("CoralBranch", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(math.cos(a) * 2.8, 4.8 + k, math.sin(a) * 2.8)).Position, 0.48, cc, cm)
			end
		end
	end
	local function fbFan(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local cc, cm = sw(tint, "CORAL")
			boxAt("SeaFanBlade", V(6.6, 7.6, 0.3), cf * CFrame.new(0, 4.6, 0), cc, cm)
		end
	end
	local function fbAnemone(tint: any): (CFrame) -> ()
		return function(cf: CFrame)
			local cc, cm = sw(tint, "CORAL")
			lump("AnemoneBody", (cf * CFrame.new(0, 1, 0)).Position, V(3, 2, 3), cc, cm)
		end
	end
	local function fbSeagrass(cf: CFrame)
		local fc, fm = sw(CLOISTER, "FOLIAGE")
		boxAt("SeagrassBlade", V(0.3, 2.2, 1.6), cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.2), fc, fm)
	end
	local function fbBrokenCol(cf: CFrame)
		local sc, sm = sw(CLOISTER, "STONE")
		local col = boxAt("BrokenColShaft", V(15, 3.6, 3.6), cf * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, 0, math.pi / 2), sc, sm)
		col.Shape = Enum.PartType.Cylinder
	end
	local function fbGreatBell(cf: CFrame)
		fbMiniBell(CLOISTER, cf, 3.2)
	end

	local function place(kind: string, kitName: string?, x: number, z: number, yaw: number, s: number, tint: any, fallback: ((CFrame) -> ())?, y: number?, roll: CFrame?): Instance?
		local m = piece(kind, x, z, yaw, kitName, s, tint, fallback, y, roll)
		if m then count(kitName or kind) end
		return m
	end

	---------------------------------------------------------------------------------------------------
	-- 1. The Bell Tower (tallest landmark: 150 studs tall at Y 34 -> 188 over bottom, framing Chapter Isle).
	---------------------------------------------------------------------------------------------------
	local campanile = place("CampanileBellTower", "CampanileTower", 0, -329, 0, 1.0, CLOISTER, fbCampanile, 34)
	if campanile then
		pin(campanile)
		landmarks += 1
		local rune = H.glowOf(campanile)
		if rune then light(rune, AQUA_LIGHT, 1.2, 55) end
	end

	---------------------------------------------------------------------------------------------------
	-- 2. The Chapter House on Chapter Isle: 6 octagonal ribbed-vault bays round the rim, curved cantors'
	--    stalls, north Cantor niche statue, and a flush blue-and-gold tide-spiral mosaic on the clean floor.
	---------------------------------------------------------------------------------------------------
	local apex = P.Apex
	for idx, bay in {
		{ "ChapterHouseRib", 0, -242, 0 },
		{ "ChapterHouseRib", -44, -224, facing(-44, -224, apex.X, apex.Z) },
		{ "ChapterHouseRib", 44, -224, facing(44, -224, apex.X, apex.Z) },
		{ "ChapterHouseRib", -52, -140, facing(-52, -140, apex.X, apex.Z) },
		{ "ChapterHouseRib", 52, -140, facing(52, -140, apex.X, apex.Z) },
		{ "ChapterHouseRib", 0, -134, 180 },
	} do
		local tint = CORAL_TINTS[((idx - 1) % #CORAL_TINTS) + 1]
		local m = place(bay[1] :: string, "ChapterHouseRib", bay[2] :: number, bay[3] :: number, bay[4] :: number, 1.0, tint, fbChapterRib(tint), apex.Y)
		if m then
			pin(m)
			landmarks += 1
			if idx == 1 then
				local g = H.glowOf(m)
				if g then light(g, AQUA_LIGHT, 1.0, 44) end
			end
		end
	end
	-- Cantor niche statue standing at the back of the Chapter House, between the two boss portals (±16, -217).
	local chapterStatue = place("ChapterCantorStatue", "CantorNicheStatue", 0, -232, 0, 1.05, CLOISTER, fbNicheStatue, apex.Y)
	if chapterStatue then pin(chapterStatue); props += 1 end
	-- Cantors' curved stone choir stalls tucked inside the four diagonal perimeter bays (clear of 34-stud camp).
	for _, st in { { -42, -222 }, { 42, -222 }, { -44, -149 }, { 44, -149 } } do
		local m = place("ChapterStall", "CantorStall", st[1], st[2], facing(st[1], st[2], apex.X, apex.Z), 0.95, CLOISTER, fbStall, apex.Y)
		if m then pin(m); props += 1 end
	end
	-- Flush blue-and-gold tide-spiral mosaics on Chapter Isle and Lay Court (non-collidable, camp/lane exempt).
	local function floorMosaic(cx: number, y: number, cz: number, radius: number)
		pinnedGroup("CloisterFloorMosaic", function()
			local outer = boxAt("MosaicRingOuter", V(0.24, radius * 2, radius * 2), CFrame.new(cx, y + 0.14, cz) * CFrame.Angles(0, 0, math.pi / 2), rgb(44, 108, 128), Mat.Marble)
			outer.Shape = Enum.PartType.Cylinder
			outer.CanCollide = false; outer.CanQuery = false; outer.CastShadow = false
			local inner = boxAt("MosaicRingInner", V(0.26, radius * 1.62, radius * 1.62), CFrame.new(cx, y + 0.16, cz) * CFrame.Angles(0, 0, math.pi / 2), rgb(228, 222, 206), Mat.Marble)
			inner.Shape = Enum.PartType.Cylinder
			inner.CanCollide = false; inner.CanQuery = false; inner.CastShadow = false
			local core = boxAt("MosaicCore", V(0.28, radius * 0.92, radius * 0.92), CFrame.new(cx, y + 0.18, cz) * CFrame.Angles(0, 0, math.pi / 2), rgb(48, 126, 146), Mat.Marble)
			core.Shape = Enum.PartType.Cylinder
			core.CanCollide = false; core.CanQuery = false; core.CastShadow = false
			for k = 0, 11 do
				local a = k * math.pi / 6
				local r = radius * (0.22 + 0.68 * (k / 11))
				local tile = boxAt("MosaicSpiralTile", V(2.4, 0.24, 2.4), CFrame.new(cx + math.cos(a) * r, y + 0.22, cz + math.sin(a) * r) * CFrame.Angles(0, -a, 0), rgb(224, 186, 94), Mat.Metal)
				tile.CanCollide = false; tile.CanQuery = false; tile.CastShadow = false
			end
		end)
	end
	floorMosaic(apex.X, apex.Y, apex.Z, 15)
	floorMosaic(0, P.Basin.Y, 200, 22)

	-- Lush coral reef skirt clinging around Chapter Isle's sheer rock face at the waterline (well below Apex Y 40).
	for k = 0, 15 do
		local a = k * math.pi * 2 / 16
		local rx, rz = math.cos(a) * 63, math.sin(a) * 47
		local cx, cz = apex.X + rx, apex.Z + rz
		local tint = CORAL_TINTS[(k % #CORAL_TINTS) + 1]
		local y = waterY + 2 + (k % 3) * 5
		if k % 2 == 0 then
			local cm = place("IsleCliffCoral", "BrainCoralMound", cx, cz, math.deg(a), 1.35, tint, fbBrainCoral(tint), y)
			if cm then pin(cm); noCollide(cm); props += 1 end
		else
			local cf2 = place("IsleCliffCoral", "CoralCluster", cx, cz, math.deg(a), 2.1, tint, fbCoral(tint), y)
			if cf2 then pin(cf2); noCollide(cf2); props += 1 end
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 3. The Lavabo: domed round fountain house on a carved pier right at the north rim of the Crossing,
	--    visible dead-center down the Garth Causeway while leaving the Crossing camp and lanes clean.
	---------------------------------------------------------------------------------------------------
	pinnedGroup("LavaboFountainPier", function()
		local sc, sm = sw(CLOISTER, "STONE")
		local tc, tm = sw(CLOISTER, "TRIM")
		local pierH = 12 - seabed
		local pier = boxAt("LavaboPier", V(pierH, 28.4, 28.4), CFrame.new(0, seabed + pierH / 2, -108) * CFrame.Angles(0, 0, math.pi / 2), sc, sm)
		pier.Shape = Enum.PartType.Cylinder
		local trim = boxAt("LavaboPierCap", V(1.6, 29.6, 29.6), CFrame.new(0, 11.4, -108) * CFrame.Angles(0, 0, math.pi / 2), tc, tm)
		trim.Shape = Enum.PartType.Cylinder
	end)
	local lavabo = place("LavaboFountainHouse", "LavaboFountain", 0, -108, 0, 1.08, CLOISTER, fbLavabo, 12)
	if lavabo then
		pin(lavabo)
		landmarks += 1
		local shellGlow = H.glowOf(lavabo)
		if shellGlow then light(shellGlow, LAMP_LIGHT, 1.4, 48) end
		pinnedGroup("LavaboMist", function()
			local anchor = ctx.block("LavaboMistAnchor", V(4, 1, 4), V(0, 19.5, -108), rgb(210, 248, 244), Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "LavaboWaterSpray"
			pe.Color = ColorSequence.new(rgb(232, 252, 250))
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.6) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			pe.Lifetime = NumberRange.new(1.0, 1.8)
			pe.Rate = 10
			pe.Speed = NumberRange.new(1.5, 3.2)
			pe.SpreadAngle = Vector2.new(35, 35)
			pe.Parent = anchor
		end)
	end

	---------------------------------------------------------------------------------------------------
	-- 4. Lay Gate & Garth Causeway: grand bell arches, flanking Cantor niche statues, warm lanterns.
	---------------------------------------------------------------------------------------------------
	local safe = layout.Sanctuary
	local layGate = place("NerethBellArch", "BellArch", 0, safe.Z - safe.Depth / 2 + 6, 0, 1.32, CLOISTER, fbBellArch(CLOISTER, 1.32), safe.Y)
	if layGate then
		landmarks += 1
		pinnedGroup("NerethBellArch", function()
			for _, s in { -1, 1 } do
				local banner = boxAt("LayGateBanner", V(4.6, 12, 0.3), CFrame.new(s * 22.4, safe.Y + 20, safe.Z - safe.Depth / 2 + 10.4), rgb(44, 146, 154), Mat.Fabric)
				banner.CanCollide = false
				boxAt("LayGateTrim", V(2.0, 10.4, 0.2), CFrame.new(s * 22.4, safe.Y + 20, safe.Z - safe.Depth / 2 + 10.6), rgb(228, 192, 102), Mat.Fabric).CanCollide = false
			end
		end)
	end
	for _, sx in { -1, 1 } do
		local st = place("LayGateStatue", "CantorNicheStatue", sx * 32, safe.Z - safe.Depth / 2 + 6, 0, 1.0, CLOISTER, fbNicheStatue, safe.Y)
		if st then pin(st); landmarks += 1 end
		local lamp = place("LayGateLamp", "VotiveLampBowl", sx * 42, safe.Z - safe.Depth / 2 + 6, 0, 1.6, CLOISTER, fbLamp, safe.Y + 4)
		if lamp then
			pin(lamp)
			ctx.group("LayGateLampPost", function()
				local tc, tm = sw(CLOISTER, "TRIM")
				boxAt("LampPedestal", V(2.6, 4, 2.6), CFrame.new(sx * 42, safe.Y + 2, safe.Z - safe.Depth / 2 + 6), tc, tm)
			end)
			local fl = lamp:FindFirstChild("CANDLE", true) or lamp:FindFirstChild("VotiveFlame", true)
			if fl and sx == 1 then light(fl, LAMP_LIGHT, 1.1, 34) end
			props += 2
		end
	end
	-- Twin bell arches framing the south and north ends of the Garth Causeway (straight from the guide image!).
	local function linkOf(id: string): any
		for _, lk in layout.Links do
			if lk.Id == id then return lk end
		end
		return nil
	end
	local causeway = linkOf("Basin_Crossing")
	if causeway then
		local southArch = place("NerethBellArch", "BellArch", causeway.AX, causeway.AZ - 2, 0, 1.15, CLOISTER, fbBellArch(CLOISTER, 1.15), causeway.AY)
		local northArch = place("NerethBellArch", "BellArch", causeway.BX, causeway.BZ + 2, 0, 1.15, CLOISTER, fbBellArch(CLOISTER, 1.15), causeway.BY)
		if southArch then landmarks += 1 end
		if northArch then landmarks += 1 end
	end

	---------------------------------------------------------------------------------------------------
	-- 5. Cloister Arcades: continuous outer-edge arcades framing Lay Court, West Walk, East Walk,
	--    Cantors' Walk, Coral Walk and the sweeping rear colonnade left & right of the Bell Tower.
	---------------------------------------------------------------------------------------------------
	local arcadePlacements = {
		-- South foreground outer arcade flanking Lay Gate
		{ -72, 266, 0, 0, 1.0 }, { -96, 266, 0, 0, 1.0 }, { -120, 266, 0, 0, 1.0 },
		{ 72, 266, 0, 0, 1.0 }, { 96, 266, 0, 0, 1.0 }, { 120, 266, 0, 0, 1.0 },
		-- West Walk outer arcade (east-facing, clear of Dorter spur exit)
		{ -194, 76, 8, 90, 1.0 }, { -194, 100, 8, 90, 1.0 }, { -194, 124, 4, 90, 1.0 },
		-- East Walk outer arcade (west-facing, clear of Frater spur exit)
		{ 194, 76, 12, -90, 1.0 }, { 194, 100, 12, -90, 1.0 }, { 194, 124, 6, -90, 1.0 },
		-- Mid outer cloister wing bays framing the Dorter/Choir & Frater/Scriptorium corridors
		{ -284, -92, 12, 90, 1.0 }, { 284, -92, 16, -90, 1.0 },
		{ -284, -220, 24, 90, 1.0 }, { 284, -220, 24, -90, 1.0 },
		-- Rear cloister colonnade flanking the Bell Tower (straight out of the guide image's back row!)
		{ -48, -328, 28, 0, 1.0 }, { -72, -328, 28, 0, 1.0 }, { -96, -328, 24, 10, 1.0 },
		{ 48, -328, 28, 0, 1.0 }, { 72, -328, 28, 0, 1.0 }, { 96, -328, 24, -10, 1.0 },
		-- Outer north-east & north-west corner cloister turns
		{ 148, -280, 24, -35, 1.0 }, { 170, -264, 24, -45, 1.0 },
		{ -148, -280, 20, 35, 1.0 }, { -170, -264, 20, 45, 1.0 },
	}
	for idx, a in arcadePlacements do
		local tint = CORAL_TINTS[((idx - 1) % #CORAL_TINTS) + 1]
		local m = place("CloisterArcadeBay", "CoralArcadeBay", a[1], a[2], a[4], a[5], tint, fbArcadeBay(tint), a[3])
		if m then pin(m); props += 1 end
	end
	-- Corner cloister piers turning the far south-west, south-east, north-west and north-east corners.
	for idx, c in {
		{ -144, 266, 0, 0 }, { 144, 266, 0, -90 },
		{ -122, -326, 24, 90 }, { 122, -326, 24, 180 },
	} do
		local tint = CORAL_TINTS[((idx + 1) % #CORAL_TINTS) + 1]
		local m = place("CloisterArcadeCorner", "CoralArcadeCorner", c[1], c[2], c[4], 1.0, tint, fbArcadeCorner(tint), c[3])
		if m then pin(m); props += 1 end
	end
	landmarks += 4 -- West Walk arcade, East Walk arcade, Rear West & Rear East cloister runs

	---------------------------------------------------------------------------------------------------
	-- 6. The Five Monastic Side Wings (Dorter, Frater, Choir Loft, Scriptorium, Sacristy) — each a
	--    distinct narrative vignette pulled directly from the guide image and Floor 37 plan.
	---------------------------------------------------------------------------------------------------
	-- 6a. The Dorter (west wing, Y 4): cantors' stone cots, kelp drapes and warm bedside lamps.
	local dorter = P.Dorter
	for idx, dz in { -14, 0, 14 } do
		local m = place("DorterCot", "DorterCot", dorter.X - 18, dorter.Z + dz, 90, 0.95, CLOISTER, fbDorterCot, dorter.Y)
		if m then
			pin(m); props += 1
			if idx == 2 then
				local fl = m:FindFirstChild("CANDLE", true) or m:FindFirstChild("CotLampGlow", true)
				if fl then light(fl, LAMP_LIGHT, 1.0, 32) end
			end
		end
	end
	place("DorterStatue", "CantorNicheStatue", dorter.X - 12, dorter.Z - 20, 20, 0.85, CLOISTER, fbNicheStatue, dorter.Y)
	landmarks += 1

	-- 6b. The Frater (east wing deck, Y 10): long refectory tables set for an unfinished meal + undercroft piers.
	local frater = P.Frater
	pinnedGroup("FraterUndercroft", function()
		local sc, sm = sw(CLOISTER, "STONE")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local pierH = frater.Y - 3 - seabed
				boxAt("FraterPier", V(5.2, pierH, 5.2), CFrame.new(frater.X + sx * (frater.Width / 2 - 5), seabed + pierH / 2, frater.Z + sz * (frater.Depth / 2 - 5)), sc, sm).CanCollide = false
			end
		end
	end)
	for idx, dz in { -10, 10 } do
		local m = place("FraterTable", "RefectoryTable", frater.X + 14, frater.Z + dz, 90, 0.95, CLOISTER, fbRefectoryTable, frater.Y)
		if m then
			pin(m); props += 1
			if idx == 1 then
				local fl = m:FindFirstChild("CANDLE", true) or m:FindFirstChild("CandleFlame", true)
				if fl then light(fl, LAMP_LIGHT, 1.0, 34) end
			end
		end
	end
	place("FraterUrn", "StoneUrn", frater.X + 20, frater.Z - 20, 40, 0.85, CLOISTER, nil, frater.Y)
	landmarks += 1

	-- 6c. The Choir Loft (upper-west deck, Y 26): tiered cantors' choir stalls, conch racks and lecterns.
	local choir = P.ChoirLoft
	pinnedGroup("ChoirCorbels", function()
		local sc, sm = sw(CLOISTER, "STONE")
		for _, sz in { -16, 0, 16 } do
			local pierH = choir.Y - 3 - seabed
			boxAt("ChoirPier", V(4.8, pierH, 4.8), CFrame.new(choir.X - 18, seabed + pierH / 2, choir.Z + sz), sc, sm).CanCollide = false
		end
	end)
	for _, dz in { -11, 11 } do
		local st = place("ChoirStall", "CantorStall", choir.X - 18, choir.Z + dz, 90, 0.95, CLOISTER, fbStall, choir.Y)
		if st then pin(st); props += 1 end
	end
	for idx, dz in { -16, 16 } do
		local cr = place("ChoirConchRack", "ConchRack", choir.X - 4, choir.Z + dz, if dz < 0 then 0 else 180, 1.05, CLOISTER, fbConchRack, choir.Y)
		if cr then
			pin(cr); props += 1
			if idx == 1 then
				local g = H.glowOf(cr)
				if g then light(g, AQUA_LIGHT, 0.9, 28) end
			end
		end
	end
	place("ChoirLectern", "CantorLectern", choir.X - 10, choir.Z, 90, 1.1, CLOISTER, fbLectern, choir.Y)
	landmarks += 1

	-- 6d. The Scriptorium (upper-east deck, Y 30): carved stone desks with framed slate celestial/tide-charts!
	local scriptorium = P.Scriptorium
	pinnedGroup("ScriptoriumCorbels", function()
		local sc, sm = sw(CLOISTER, "STONE")
		for _, sz in { -16, 0, 16 } do
			local pierH = scriptorium.Y - 3 - seabed
			boxAt("ScriptoriumPier", V(4.8, pierH, 4.8), CFrame.new(scriptorium.X + 18, seabed + pierH / 2, scriptorium.Z + sz), sc, sm).CanCollide = false
		end
	end)
	for idx, dz in { -11, 11 } do
		local dk = place("ScriptoriumDesk", "ScriptoriumDesk", scriptorium.X + 18, scriptorium.Z + dz, -90, 1.0, CLOISTER, fbScriptoriumDesk, scriptorium.Y)
		if dk then
			pin(dk); props += 1
			if idx == 1 then
				local g = H.glowOf(dk)
				if g then light(g, AQUA_LIGHT, 1.0, 32) end
			end
		end
	end
	place("ScriptoriumLectern", "CantorLectern", scriptorium.X + 6, scriptorium.Z + 18, -135, 1.05, CLOISTER, fbLectern, scriptorium.Y)
	landmarks += 1

	-- 6e. The Sacristy (far north-west, Y 28): vestment presses with hanging cantor robes, bell-rope bins & spare bell.
	local sacristy = P.Sacristy
	for _, dx in { -12, 12 } do
		local pr = place("SacristyPress", "SacristyPress", sacristy.X + dx, sacristy.Z - 14, 0, 1.0, CLOISTER, fbSacristyPress, sacristy.Y)
		if pr then pin(pr); props += 1 end
	end
	local spareBell = place("SacristySpareBell", "GreatTidebell", sacristy.X - 18, sacristy.Z + 6, 35, 0.52, CLOISTER, fbGreatBell, sacristy.Y)
	if spareBell then pin(spareBell); props += 1 end
	landmarks += 1

	---------------------------------------------------------------------------------------------------
	-- 7. The Two Flooded Garths: submerged Drowned Sundials, stone garth curbs, underwater reef mounds,
	--    floating votive lamp bowls and rising bubble vents.
	---------------------------------------------------------------------------------------------------
	local southSundial = place("SouthGarthSundial", "DrownedSundial", 54, 70, 22, 1.0, CLOISTER, fbSundial, seabed + 0.6)
	if southSundial then pin(southSundial); landmarks += 1 end
	local northSundial = place("NorthGarthSundial", "DrownedSundial", -82, -134, -35, 1.0, CLOISTER, fbSundial, seabed + 0.6)
	if northSundial then pin(northSundial); landmarks += 1 end

	-- Floating warm votive lamps near the Garth Causeway & Lavabo, and bubble columns in both garths.
	local lampPlaced = 0
	for _ = 1, 320 do
		if lampPlaced >= 20 then break end
		local x = rng:NextNumber(-92, 92)
		local z = if lampPlaced % 2 == 0 then rng:NextNumber(-4, 138) else rng:NextNumber(-248, -108)
		if field and field.Kind(x, z) == "POOL" and free(x, z, 2.0) then
			lampPlaced += 1
			take(x, z, 2.0)
			local m = place("VotiveLamp", "VotiveLampBowl", x, z, rng:NextNumber(0, 360), rng:NextNumber(1.0, 1.4), CLOISTER, fbLamp, waterY - 0.25)
			pin(m)
			props += 1
		end
	end
	for _, at in { V(-52, waterY, 72), V(58, waterY, -142), V(-74, waterY, -234) } do
		pinnedGroup("BubbleVent", function()
			local anchor = ctx.block("BubbleVentAnchor", V(3, 1, 3), at - V(0, 3, 0), rgb(200, 250, 248), Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "TideBubbles"
			pe.Color = ColorSequence.new(rgb(228, 252, 250))
			pe.Size = NumberSequence.new(0.6, 1.3)
			pe.Transparency = NumberSequence.new(0.3, 1)
			pe.Lifetime = NumberRange.new(1.5, 2.5)
			pe.Rate = 7
			pe.Speed = NumberRange.new(2, 4)
			pe.SpreadAngle = Vector2.new(14, 14)
			pe.Parent = anchor
		end)
	end

	-- Cantor statues in niches along the four cloister walks (off camps and lanes).
	for _, st in {
		{ -178, 92, 90 }, { 178, 92, -90 },
		{ -188, -214, 90 }, { 188, -214, -90 },
	} do
		if free(st[1], st[2], 4.5) then
			take(st[1], st[2], 4.5)
			local m = place("WalkCantorStatue", "CantorNicheStatue", st[1], st[2], st[3], 0.9, CLOISTER, fbNicheStatue)
			if m then props += 1 end
		end
	end

	-- Glowing aqua rune tablets at the Garth Causeway and both Isle Stair heads (Tidecall glyph trail).
	for _, rt in {
		{ -24, 152, 0 }, { 24, 152, 0 },
		{ -116, -158, 45 }, { 116, -158, -45 },
		{ -28, -276, 15 }, { 28, -276, -15 },
	} do
		if free(rt[1], rt[2], 3.2) then
			take(rt[1], rt[2], 3.2)
			local m = place("RuneTablet", "RuneTablet", rt[1], rt[2], rt[3], 1.05, CLOISTER, fbTablet)
			if m then props += 1 end
		end
	end

	---------------------------------------------------------------------------------------------------
	-- 8. Far Skyline — The Tidewall (closer now on north, upper-west and upper-east), gliding manta ray
	--    silhouettes, fish shoals, and the drowned city's verdigris domes beyond the cloister roofs.
	---------------------------------------------------------------------------------------------------
	pinnedGroup("TidewallCloister", function()
		local face = rgb(38, 154, 166)
		local segs = 14
		for k = 0, segs - 1 do
			local x0 = -w / 2 + k * w / segs
			local x = x0 + w / segs / 2
			local bow = 4 * math.cos((x / (w / 2)) * math.pi / 2)
			local slab = ctx.block("TidewallWater", V(w / segs + 1, 224, 4), V(x, -4 + 112, -d / 2 + 5 + bow), face, Mat.SmoothPlastic, nil, 0.22)
			slab.CanCollide = false; slab.CanQuery = false; slab.CastShadow = false
			local band = ctx.block("TidewallCaustic", V(w / segs + 1, 1.4, 0.4), V(x, 70 + (k % 3) * 38, -d / 2 + 7.2 + bow), rgb(156, 250, 242), Mat.Neon, nil, 0.55)
			band.CanCollide = false; band.CastShadow = false
			local foam = ctx.block("TidewallFoam", V(w / segs + 1, 6, 6), V(x, 76 + (k % 2) * 4, -d / 2 + 8 + bow), rgb(236, 250, 246), Mat.SmoothPlastic, nil, 0.16)
			foam.CanCollide = false; foam.CastShadow = false
		end
		-- Flanking Tidewall wings pressing closer along the northern west and east edges!
		for _, sx in { -1, 1 } do
			for k = 0, 5 do
				local z = -d / 2 + 30 + k * 54
				local wing = ctx.block("TidewallSideWater", V(4, 210, 56), V(sx * (w / 2 - 4), 101, z), face, Mat.SmoothPlastic, nil, 0.24)
				wing.CanCollide = false; wing.CanQuery = false; wing.CastShadow = false
			end
		end
		-- Sculpted manta ray silhouettes gliding high inside the sunlit Tidewall (straight from guide image!)
		for _, manta in { { -180, 158, -10 }, { -68, 174, 8 }, { 126, 166, -14 }, { 232, 182, 12 } } do
			local mx, my, yaw = manta[1], manta[2], math.rad(manta[3])
			local mz = -d / 2 + 9.5
			local body = ctx.block("TidewallMantaBody", V(22, 1.2, 10), V(mx, my, mz), rgb(22, 76, 94), Mat.SmoothPlastic, nil, 0.18)
			body.CFrame = body.CFrame * CFrame.Angles(math.rad(14), 0, yaw)
			body.CanCollide = false; body.CastShadow = false
			local tail = ctx.block("TidewallMantaTail", V(14, 0.6, 0.6), V(mx - 12, my - 2, mz), rgb(22, 76, 94), Mat.SmoothPlastic, nil, 0.2)
			tail.CFrame = tail.CFrame * CFrame.Angles(0, 0, yaw - 0.15)
			tail.CanCollide = false; tail.CastShadow = false
		end
		-- Fish shoals shimmering inside the water wall
		for _ = 1, 24 do
			local fx = rng:NextNumber(-w / 2 + 24, w / 2 - 24)
			local fy = rng:NextNumber(88, 196)
			local fish = ctx.block("TidewallShoal", V(rng:NextNumber(5, 13), rng:NextNumber(1.1, 2.4), 0.3), V(fx, fy, -d / 2 + 8.6), rgb(28, 86, 102), Mat.SmoothPlastic, nil, 0.26)
			fish.CanCollide = false; fish.CastShadow = false
			fish.CFrame = fish.CFrame * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12)))
		end
		-- The drowned city's verdigris domed pavilions & spires rising over the Tidewall crest
		for k = 0, 8 do
			local x = -240 + k * 60 + rng:NextNumber(-8, 8)
			if math.abs(x) > 26 then
				local tall = rng:NextNumber(18, 36)
				ctx.block("DrownedCityTower", V(14, tall, 10), V(x, 218 + tall / 2, -d / 2 + 4), rgb(186, 218, 214), Mat.SmoothPlastic, nil, 0.34).CanCollide = false
				local dome = ctx.block("DrownedCityDome", V(16, 11, 12), V(x, 218 + tall + 4, -d / 2 + 4), rgb(88, 166, 148), Mat.SmoothPlastic, Enum.PartType.Ball, 0.3)
				dome.CanCollide = false
			end
		end
	end)
	landmarks += 1

	---------------------------------------------------------------------------------------------------
	-- 9. Rich living layers & terrace vignettes: balanced variety across >= 30 distinct templates with
	--    no single template exceeding 12% of placed props (target >= 440 props, >= 360 ground cover).
	---------------------------------------------------------------------------------------------------
	type Kind = { Name: string, Kit: string, S: { number }, R: number, Tints: { any }?, Fallback: (CFrame) -> (), Wet: boolean, Cap: number }
	local kinds: { Kind } = {
		{ Name = "BrainCoralMound", Kit = "BrainCoralMound", S = { 0.7, 1.3 }, R = 5.4, Tints = CORAL_TINTS, Fallback = fbBrainCoral(CLOISTER), Wet = true, Cap = 42 },
		{ Name = "CoralCluster", Kit = "CoralCluster", S = { 1.1, 2.0 }, R = 4.6, Tints = CORAL_TINTS, Fallback = fbCoral(CLOISTER), Wet = true, Cap = 42 },
		{ Name = "SeaFan", Kit = "SeaFan", S = { 0.9, 1.5 }, R = 3.8, Tints = CORAL_TINTS, Fallback = fbFan(CLOISTER), Wet = true, Cap = 42 },
		{ Name = "AnemoneCluster", Kit = "AnemoneCluster", S = { 1.0, 1.6 }, R = 2.6, Tints = { CLOISTER, CORAL_AQUA, CORAL_CREAM, CORAL_LILAC }, Fallback = fbAnemone(CLOISTER), Wet = true, Cap = 42 },
		{ Name = "KelpStand", Kit = "KelpStand", S = { 0.75, 1.25 }, R = 3.8, Tints = nil, Fallback = fbKelp, Wet = true, Cap = 40 },
		{ Name = "GiantClam", Kit = "GiantClam", S = { 0.8, 1.3 }, R = 4.4, Tints = nil, Fallback = fbClam, Wet = true, Cap = 34 },
		{ Name = "BoulderCluster", Kit = "BoulderCluster", S = { 0.65, 1.2 }, R = 4.8, Tints = nil, Fallback = fbBrainCoral(CORAL_CREAM), Wet = true, Cap = 36 },
		{ Name = "RuinRubble", Kit = "RuinRubble", S = { 0.65, 1.15 }, R = 4.2, Tints = nil, Fallback = fbBrokenCol, Wet = true, Cap = 36 },
		{ Name = "StoneUrn", Kit = "StoneUrn", S = { 0.65, 1.0 }, R = 2.8, Tints = nil, Fallback = fbTablet, Wet = false, Cap = 28 },
		{ Name = "CantorLectern", Kit = "CantorLectern", S = { 0.95, 1.2 }, R = 2.5, Tints = nil, Fallback = fbLectern, Wet = false, Cap = 22 },
		{ Name = "ConchRack", Kit = "ConchRack", S = { 0.8, 1.05 }, R = 3.4, Tints = nil, Fallback = fbConchRack, Wet = false, Cap = 18 },
		{ Name = "CantorStall", Kit = "CantorStall", S = { 0.75, 0.95 }, R = 4.8, Tints = nil, Fallback = fbStall, Wet = false, Cap = 16 },
		{ Name = "RuneTablet", Kit = "RuneTablet", S = { 0.8, 1.05 }, R = 2.8, Tints = nil, Fallback = fbTablet, Wet = false, Cap = 22 },
		{ Name = "BrokenLancetColumn", Kit = "BrokenLancetColumn", S = { 0.55, 0.85 }, R = 7.2, Tints = nil, Fallback = fbBrokenCol, Wet = true, Cap = 24 },
		{ Name = "VotiveLampBowl", Kit = "VotiveLampBowl", S = { 1.0, 1.5 }, R = 2.0, Tints = nil, Fallback = fbLamp, Wet = true, Cap = 28 },
		{ Name = "TidepoolRockRing", Kit = "TidepoolRockRing", S = { 0.55, 0.8 }, R = 6.2, Tints = nil, Fallback = fbBrainCoral(CORAL_AQUA), Wet = true, Cap = 18 },
		{ Name = "ReedPondCluster", Kit = "ReedPondCluster", S = { 0.8, 1.3 }, R = 3.2, Tints = nil, Fallback = fbKelp, Wet = true, Cap = 28 },
		{ Name = "GlowLilyCluster", Kit = "GlowLilyCluster", S = { 0.8, 1.3 }, R = 3.0, Tints = nil, Fallback = fbAnemone(CORAL_AQUA), Wet = true, Cap = 28 },
		{ Name = "ArchCrown", Kit = "ArchCrown", S = { 0.45, 0.65 }, R = 7.8, Tints = nil, Fallback = fbBrokenCol, Wet = true, Cap = 10 },
	}
	local used: { [string]: number } = {}
	local function scatterOne(x: number, z: number, y: number?, wetOk: boolean): boolean
		local wet = field ~= nil and field.Kind(x, z) == "POOL"
		if wet and not wetOk then return false end
		if field and y == nil and field.Slope(x, z) > 0.95 then return false end
		for _ = 1, 5 do
			local k = kinds[rng:NextInteger(1, #kinds)]
			if (used[k.Name] or 0) < k.Cap and (k.Wet or not wet) then
				local s = rng:NextNumber(k.S[1], k.S[2])
				local r = k.R * s
				if free(x, z, r) then
					take(x, z, r)
					local tint = if k.Tints then k.Tints[rng:NextInteger(1, #k.Tints)] else CLOISTER
					local m = place(k.Name, k.Kit, x, z, rng:NextNumber(0, 360), s, tint, k.Fallback, y)
					if m then
						if k.Name ~= "BrokenLancetColumn" and k.Name ~= "BoulderCluster" then noCollide(m) end
						used[k.Name] = (used[k.Name] or 0) + 1
						props += 1
						return true
					end
				end
			end
		end
		return false
	end

	-- Terrace corners & rims (every terrace gets rich cloister/reef vignettes).
	for id, t in P do
		if id ~= "Sanctuary" and id ~= "Basin" then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					for _ = 1, 4 do
						scatterOne(t.X + sx * (t.Width / 2 - rng:NextNumber(4, 11)), t.Z + sz * (t.Depth / 2 - rng:NextNumber(4, 11)), t.Y, false)
					end
				end
			end
		end
	end
	-- Lay Court perimeter & plaza edges (camps at ±110 stay clear).
	for _ = 1, 60 do
		scatterOne(rng:NextNumber(-w / 2 + 18, w / 2 - 18), rng:NextNumber(P.Basin.Z - 42, P.Basin.Z + 44), P.Basin.Y, false)
	end
	-- Both ends of every link dressed off the lane.
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
		local nx, nz = -dz / len, dx / len
		for _, e in { { link.AX, link.AZ }, { link.BX, link.BZ } } do
			for _, side in { -1, 1 } do
				scatterOne(e[1] + nx * side * 24, e[2] + nz * side * 24, nil, true)
			end
		end
	end
	-- Garths, sheer coral aprons, outer cloister margins & northern coral overgrowth (target >= 460 props).
	for _ = 1, 2400 do
		if props >= 470 then break end
		scatterOne(rng:NextNumber(-w / 2 + 14, w / 2 - 14), rng:NextNumber(-d / 2 + 22, d / 2 - 46), nil, true)
	end

	-- Ground cover: lush seagrass & small coral clutter in both garths and along stone margins (>= 380).
	for _ = 1, 2200 do
		if cover >= 390 then break end
		local x, z = rng:NextNumber(-w / 2 + 12, w / 2 - 12), rng:NextNumber(-d / 2 + 18, d / 2 - 18)
		local _, onDeck = H.surfaceAt(x, z)
		if not onDeck and (not field or field.Slope(x, z) < 0.85) then
			local okCamp = true
			for _, camp in layout.Camps do
				if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < 38 ^ 2 then okCamp = false break end
			end
			if okCamp and ctx.footprintClear(x, z, 1.8, 1.8) then
				local m = place("GroundCover", "SeagrassTuft", x, z, rng:NextNumber(0, 360), rng:NextNumber(0.85, 1.65), CLOISTER, fbSeagrass)
				noCollide(m)
				cover += 1
			end
		end
	end

	-- Warm afternoon bounce off both flooded garths (2 broad, soft turquoise-green fills; total floor lights <= 22).
	pinnedGroup("GarthWaterBounce", function()
		for _, at in { V(0, 10, 65), V(0, 18, -182) } do
			local anchor = ctx.block("GarthBounceAnchor", V(1, 1, 1), at, GARTH_LIGHT, Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			light(anchor, GARTH_LIGHT, 0.65, 110)
		end
	end)

	local distinct = 0
	for _ in kindsUsed do distinct += 1 end
	ctx.setAttribute("SetPieceLandmarks", landmarks)
	ctx.setAttribute("SetPieceProps", props)
	ctx.setAttribute("SetPieceGroundCover", cover)
	ctx.setAttribute("SetPieceTemplates", distinct)
end

return SunkenFloor37
