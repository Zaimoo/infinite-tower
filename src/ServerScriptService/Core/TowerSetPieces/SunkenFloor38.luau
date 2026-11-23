--!strict
-- Hand-authored set pieces for Sunken Sanctuary Floor 38: Tidal Channels (sunken:3).
-- Guide image: reference/Sunken Sanctuary 38.jpg. Design: docs/prompts/sunken-sanctuary-floor-layouts-prompt.md.
--
-- The Nereth waterworks under a grey-teal storm tide: a staircase of five stepped canal tide-locks climbing north
-- between two rising towpath rails, bridged at Tail Gate, Middle Gate and Head Gate (`BridgeStyles = "LOCKGATE"`).
-- Back-west stands the 168-stud open Sea-Gate framed by colossal trident statues and opening straight into the
-- storming Tidewall; back-east rises the 149-stud slender gothic Tidebell Tower; flanking side channels hold the
-- Tide Mill (colossal foaming undershot waterwheel), Sluice House (triple foaming discharge arches), curved timber
-- Eel Weir, Upper Pound with moored drowned barges, lockhouse sluice winches, tide-gauge columns, harbour bollards
-- with warm storm lanterns, jammed lock barges, sculpted overflow waterfall ribbons, and a misty high viaduct
-- aqueduct spanning the northern storm ridge.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local SunkenFloor38 = {}

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

-- Storm-tide waterworks palette: wet dark basalt/slate masonry, weathered pale limestone trim, rain-slick dark
-- timber, verdigris bronze bells & doors, small warm amber storm lanterns, and luminous aqua-cyan tide runes
-- (the floor's sole saturated hue, never red or orange so enemy telegraphs stay unmistakable).
local STORM = table.freeze({
	STONE = swatch(74, 84, 88, Mat.Slate), -- wet dark basalt/slate lock masonry
	TRIM = swatch(138, 148, 146, Mat.Limestone), -- weathered wet limestone quoins & plaques
	METAL = swatch(52, 60, 64, Mat.Metal), -- dark storm-wet iron & bronze straps
	ACCENT = swatch(72, 126, 114, Mat.Metal), -- verdigris bronze doors, roofs & Tidebells
	GOLD = swatch(198, 168, 96, Mat.Metal), -- worn bell lips & bronze gears
	GLOW = swatch(92, 242, 236, Mat.Neon), -- aqua-cyan trident & tide-wave runes
	CANDLE = swatch(255, 198, 118, Mat.Neon), -- warm amber storm lanterns & mill windows
	WOOD = swatch(68, 56, 48, Mat.Wood), -- rain-slick dark canal timber
	SILK = swatch(44, 78, 76, Mat.Fabric), -- dark teal storm pennants & damp nets
	FOLIAGE = swatch(54, 92, 76, Mat.Grass), -- wet channel kelp & reeds
	MOSS = swatch(58, 86, 68, Mat.Grass), -- dark waterline canal moss
	CORAL = swatch(142, 162, 178, Mat.SmoothPlastic), -- pale storm-washed reef & barnacle crust
	ALT = swatch(204, 224, 226, Mat.SmoothPlastic), -- frothy foam crests, wicker & wet hemp rope
	CRYSTAL = swatch(134, 212, 214, Mat.Glass, 0.28), -- foaming sluice torrents & overflow ribbons
})
local STATUE_WET = tinted(STORM, {
	STONE = swatch(64, 76, 80, Mat.Basalt),
	TRIM = swatch(102, 116, 116, Mat.Slate),
	ACCENT = swatch(62, 112, 100, Mat.Metal),
	GOLD = swatch(134, 152, 120, Mat.Metal),
})

local AQUA_LIGHT = rgb(92, 242, 236)
local LANTERN_LIGHT = rgb(255, 196, 116)
local STORM_BOUNCE = rgb(78, 156, 162)

-- Floor 38's landmark footprints (room-local, scaled and turned), spec-checked offline against every walkway
-- lane, every camp, both return ramps and both boss portals.
SunkenFloor38.Floor38Landmarks = table.freeze({
	{ Id = "SeaGateMonument", X = -200, Z = -356, Y = 48, HalfX = 47.3, HalfZ = 12.8, Top = 168.5 },
	{ Id = "SeaGateWestStatue", X = -282, Z = -318, Y = 22, HalfX = 14.0, HalfZ = 14.0, Top = 104 },
	{ Id = "SeaGateEastStatue", X = -114, Z = -346, Y = 22, HalfX = 14.0, HalfZ = 14.0, Top = 104 },
	{ Id = "TidebellTower", X = 186, Z = -348, Y = 44, HalfX = 16.0, HalfZ = 12.1, Top = 149.2 },
	{ Id = "TideMillBuilding", X = 304, Z = 62, Y = -6, HalfX = 16.0, HalfZ = 16.0, Top = 36.4 },
	{ Id = "SluiceHouseBuilding", X = -304, Z = -22, Y = 12, HalfX = 17.1, HalfZ = 12.7, Top = 36.6 },
	{ Id = "EelWeirEastA", X = 304, Z = -120, Y = -8, HalfX = 10.5, HalfZ = 5.0, Top = 10.0 },
	{ Id = "EelWeirEastB", X = 294, Z = -168, Y = -8, HalfX = 10.5, HalfZ = 5.0, Top = 10.0 },
	{ Id = "UpperPoundBargeA", X = 312, Z = -250, Y = -6, HalfX = 6.0, HalfZ = 14.5, Top = 10.5 },
	{ Id = "UpperPoundBargeB", X = 282, Z = -304, Y = -6, HalfX = 14.5, HalfZ = 6.0, Top = 10.5 },
	{ Id = "TailwaterWreckWest", X = -170, Z = 132, Y = -9, HalfX = 14.5, HalfZ = 6.5, Top = 10.5 },
	{ Id = "TailwaterWreckEast", X = 188, Z = 136, Y = -9, HalfX = 14.5, HalfZ = 6.5, Top = 10.5 },
	{ Id = "Lock1MitreGate", X = 0, Z = 36, Y = -8, HalfX = 22.2, HalfZ = 5.5, Top = 17.7 },
	{ Id = "Lock2MitreGate", X = 0, Z = -12, Y = -4, HalfX = 22.2, HalfZ = 5.5, Top = 17.7 },
	{ Id = "Lock2JammedBarge", X = -14, Z = -40, Y = 1, HalfX = 14.5, HalfZ = 7.0, Top = 10.5 },
	{ Id = "Lock3MitreGate", X = 0, Z = -72, Y = 2, HalfX = 22.2, HalfZ = 5.5, Top = 17.7 },
	{ Id = "Lock4MitreGate", X = 0, Z = -140, Y = 8, HalfX = 22.2, HalfZ = 5.5, Top = 17.7 },
	{ Id = "Lock5MitreGate", X = 0, Z = -206, Y = 14, HalfX = 22.2, HalfZ = 5.5, Top = 17.7 },
	{ Id = "Lock1BellGallows", X = 58, Z = 6, Y = 0, HalfX = 8.0, HalfZ = 4.5, Top = 22.1 },
	{ Id = "Lock2BellGallows", X = 58, Z = -18, Y = 6, HalfX = 8.0, HalfZ = 4.5, Top = 22.1 },
	{ Id = "Lock4BellGallows", X = -58, Z = -146, Y = 18, HalfX = 8.0, HalfZ = 4.5, Top = 22.1 },
	{ Id = "Lock5BellGallows", X = 58, Z = -212, Y = 24, HalfX = 8.0, HalfZ = 4.5, Top = 22.1 },
	{ Id = "StormTidewallNorth", X = 0, Z = -366, Y = -10, HalfX = 345, HalfZ = 3.5, Top = 258 },
}) :: { Landmark }

function SunkenFloor38.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number = H.field, H.bottom, H.d
	local w: number = ctx.w
	local layout = ctx.layout
	local P = layout.Platforms
	local boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local origin: Vector3 = ctx.origin
	local waterY: number = if field then field.LiquidLevel else bottom
	local landmarks, props, cover = 0, 0, 0
	local kindsUsed: { [string]: number } = {}
	local rng = Random.new(38 * 7927)

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

	for _, lm in SunkenFloor38.Floor38Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end
	local taken: { { number } } = {}
	for _, lm in SunkenFloor38.Floor38Landmarks do
		if lm.Id ~= "StormTidewallNorth" then
			table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
		end
	end
	local function free(x: number, z: number, r: number): boolean
		if math.abs(x) > w / 2 - 12 or math.abs(z) > d / 2 - 16 then return false end
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
	-- Part-built fallbacks (active until SunkenF38Kit.fbx is imported into ServerStorage.TowerBiomeKit).
	---------------------------------------------------------------------------------------------------
	local function fbSeaGate(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local tc, tm = sw(STORM, "TRIM")
		local vc, vm = sw(STORM, "ACCENT")
		local glc, glm = sw(STORM, "GLOW")
		for _, sx in { -1, 1 } do
			boxAt("SeaGatePier", V(16, 108, 19), cf * CFrame.new(sx * 34, 54, 0), sc, sm)
			boxAt("SeaGateTurret", V(10, 26, 10), cf * CFrame.new(sx * 34, 121, 0), sc, sm)
			boxAt("SeaGateSpire", V(8, 22, 8), cf * CFrame.new(sx * 34, 145, 0), vc, vm)
			boxAt("SeaGateRuneCol", V(2.4, 56, 0.8), cf * CFrame.new(sx * 34, 58, 10.0), glc, glm)
			-- Swung-open monumental bronze relief doors (kept tucked against piers, clear of boss portals)
			boxAt("SeaGateDoor", V(19, 84, 3.2), cf * CFrame.new(sx * 24, 43, 5) * CFrame.Angles(0, sx * 0.72, 0), vc, vm)
		end
		for k = 0, 7 do
			local a = math.pi * (k + 0.5) / 8
			boxAt("SeaGateArchSeg", V(16, 10, 14), cf * CFrame.new(math.cos(a) * 34, 106 + math.sin(a) * 40, 0) * CFrame.Angles(0, 0, a), sc, sm)
		end
		boxAt("SeaGateKeystone", V(13, 15, 16), cf * CFrame.new(0, 148, 0), tc, tm)
		boxAt("SeaGateTridentGlow", V(8, 14, 1.2), cf * CFrame.new(0, 154, 8.5), glc, glm)
		boxAt("SeaGateFinial", V(2.4, 15, 2.4), cf * CFrame.new(0, 161, 0), vc, vm)
	end
	local function fbTidebellTower(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local tc, tm = sw(STORM, "TRIM")
		local vc, vm = sw(STORM, "ACCENT")
		local gc, gm = sw(STORM, "GOLD")
		local glc, glm = sw(STORM, "GLOW")
		local slc, slm = sw(STORM, "SILK")
		boxAt("TowerBase", V(23, 20, 23), cf * CFrame.new(0, 10, 0), sc, sm)
		boxAt("TowerShaft", V(16, 68, 16), cf * CFrame.new(0, 54, 0), sc, sm)
		boxAt("TowerRune", V(3.4, 18, 0.8), cf * CFrame.new(0, 52, 8.4), glc, glm)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				boxAt("TowerBelfryPier", V(3.4, 26, 3.4), cf * CFrame.new(sx * 6.2, 101, sz * 6.2), sc, sm)
			end
		end
		boxAt("TowerCornice", V(19, 2.6, 19), cf * CFrame.new(0, 115, 0), tc, tm)
		local bell = boxAt("TowerBell", V(9.5, 9.5, 9.5), cf * CFrame.new(0, 99, 0) * CFrame.Angles(0, 0, math.pi / 2), vc, vm)
		bell.Shape = Enum.PartType.Cylinder
		boxAt("TowerBellRim", V(10.5, 1.2, 10.5), cf * CFrame.new(0, 94.5, 0), gc, gm)
		for k = 0, 4 do
			local sz = 16 * (1 - k * 0.18)
			boxAt("TowerSpire", V(sz, 6.4, sz), cf * CFrame.new(0, 119 + k * 6.2, 0), vc, vm)
		end
		boxAt("TowerPennant", V(11, 7.6, 0.4), cf * CFrame.new(14, 80, 0), slc, slm)
	end
	local function fbTideMill(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local vc, vm = sw(STORM, "ACCENT")
		local wc, wm = sw(STORM, "WOOD")
		local cc, cm = sw(STORM, "CANDLE")
		local cr, crm = sw(STORM, "CRYSTAL")
		boxAt("MillHouseBody", V(22, 23, 27), cf * CFrame.new(-4.5, 11.5, 0), sc, sm)
		boxAt("MillRoof", V(24, 9, 29), cf * CFrame.new(-4.5, 27.5, 0), vc, vm)
		boxAt("MillWindow", V(0.8, 4.8, 4.2), cf * CFrame.new(6.8, 17, 4), cc, cm)
		local wheel = boxAt("MillWaterwheel", V(4.2, 24, 24), cf * CFrame.new(9.8, 12.5, 0), wc, wm)
		wheel.Shape = Enum.PartType.Cylinder
		boxAt("MillRaceFoam", V(7, 3.2, 14), cf * CFrame.new(10, 1.6, 5), cr, crm, 0.25)
	end
	local function fbSluiceHouse(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local vc, vm = sw(STORM, "ACCENT")
		local cc, cm = sw(STORM, "CANDLE")
		local glc, glm = sw(STORM, "GLOW")
		local cr, crm = sw(STORM, "CRYSTAL")
		boxAt("SluiceBase", V(29, 22, 18), cf * CFrame.new(0, 11, 0), sc, sm)
		boxAt("SluiceRoof", V(31, 8, 20), cf * CFrame.new(0, 26, 0), vc, vm)
		for _, ax in { -8.4, 0, 8.4 } do
			boxAt("SluiceWin", V(3.2, 4, 0.7), cf * CFrame.new(ax, 16.5, 9.2), cc, cm)
			boxAt("SluiceJet", V(4.0, 6.2, 7.5), cf * CFrame.new(ax, 3.2, 11.0), cr, crm, 0.28)
		end
		boxAt("SluiceRune", V(2.0, 5.4, 0.6), cf * CFrame.new(-12.5, 16.5, 9.2), glc, glm)
	end
	local function fbLockWall(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local tc, tm = sw(STORM, "TRIM")
		local glc, glm = sw(STORM, "GLOW")
		boxAt("LockWallBody", V(24, 18, 10), cf * CFrame.new(0, 9, 0), sc, sm)
		boxAt("LockWallCap", V(25.2, 1.6, 11), cf * CFrame.new(0, 18.6, 0), tc, tm)
		boxAt("LockWallRune", V(4.6, 3.2, 0.6), cf * CFrame.new(0, 13, 5.4), glc, glm)
	end
	local function fbMitreGate(cf: CFrame)
		local wc, wm = sw(STORM, "WOOD")
		local mc, mm = sw(STORM, "METAL")
		local glc, glm = sw(STORM, "GLOW")
		local cr, crm = sw(STORM, "CRYSTAL")
		for _, sx in { -1, 1 } do
			boxAt("MitreLeaf", V(15.6, 14.5, 2.2), cf * CFrame.new(sx * 7.6, 7.25, -0.6) * CFrame.Angles(0, sx * 0.18, 0), wc, wm)
			boxAt("MitreBeam", V(14.5, 1.5, 1.5), cf * CFrame.new(sx * 14, 16, -0.6), wc, wm)
		end
		boxAt("MitreStrap", V(30, 1.0, 2.8), cf * CFrame.new(0, 12, -0.6), mc, mm)
		boxAt("MitreWaveGlow", V(6.4, 2.6, 0.5), cf * CFrame.new(0, 10.5, 1.2), glc, glm)
		boxAt("MitreOverflow", V(7.5, 13.5, 2.4), cf * CFrame.new(0, 7.0, 2.6), cr, crm, 0.3)
	end
	local function fbBellGallows(cf: CFrame)
		local wc, wm = sw(STORM, "WOOD")
		local vc, vm = sw(STORM, "ACCENT")
		local gc, gm = sw(STORM, "GOLD")
		local glc, glm = sw(STORM, "GLOW")
		boxAt("GallowsMast", V(2.4, 21, 2.4), cf * CFrame.new(-4.2, 10.5, 0), wc, wm)
		boxAt("GallowsArm", V(14, 1.8, 1.8), cf * CFrame.new(1.6, 20.6, 0), wc, wm)
		local bell = boxAt("GallowsBell", V(6.8, 7.2, 7.2), cf * CFrame.new(4.8, 15.6, 0) * CFrame.Angles(0, 0, math.pi / 2), vc, vm)
		bell.Shape = Enum.PartType.Cylinder
		boxAt("GallowsBellLip", V(7.8, 0.8, 7.8), cf * CFrame.new(4.8, 12.2, 0), gc, gm)
		boxAt("GallowsBellGlow", V(7.2, 0.5, 7.2), cf * CFrame.new(4.8, 12.8, 0), glc, glm)
	end
	local function fbEelWeir(cf: CFrame)
		local wc, wm = sw(STORM, "WOOD")
		local ac, am = sw(STORM, "ALT")
		local cc, cm = sw(STORM, "CANDLE")
		for k = -4, 4 do
			boxAt("WeirPiling", V(0.9, 7.5, 0.9), cf * CFrame.new(k * 2.1, 3.75, math.abs(k) * 0.45), wc, wm)
		end
		for _, kx in { -5, -1.6, 1.6, 5 } do
			lump("WickerTrap", (cf * CFrame.new(kx, 2.2, 1.8)).Position, V(2.4, 2.0, 4.2), ac, am)
		end
		boxAt("WeirLantern", V(1.1, 1.4, 1.1), cf * CFrame.new(8.5, 8.2, 1.8), cc, cm)
	end
	local function fbBarge(cf: CFrame)
		local wc, wm = sw(STORM, "WOOD")
		boxAt("BargeHull", V(24, 4.8, 9.8), cf * CFrame.new(0, 2.4, 0), wc, wm)
		boxAt("BargeCrate", V(3.4, 2.8, 3.4), cf * CFrame.new(-6, 6.0, 0), wc, wm)
		boxAt("BargeMast", V(1.0, 9.2, 1.0), cf * CFrame.new(3.5, 5.6, 0), wc, wm)
	end
	local function fbTideGauge(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local glc, glm = sw(STORM, "GLOW")
		local vc, vm = sw(STORM, "ACCENT")
		boxAt("GaugeShaft", V(3.4, 16, 3.4), cf * CFrame.new(0, 8, 0), sc, sm)
		boxAt("GaugeGlow", V(2.0, 10, 0.5), cf * CFrame.new(0, 9, 1.8), glc, glm)
		boxAt("GaugeFinial", V(2.2, 3.2, 0.6), cf * CFrame.new(0, 18, 0), vc, vm)
	end
	local function fbSluiceGear(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local vc, vm = sw(STORM, "ACCENT")
		local mc, mm = sw(STORM, "METAL")
		boxAt("GearBase", V(7.6, 5.2, 5.0), cf * CFrame.new(0, 2.6, 0), sc, sm)
		boxAt("GearScrew", V(1.0, 9.5, 1.0), cf * CFrame.new(0, 5.2, 0), mc, mm)
		local wh = boxAt("GearWheel", V(0.7, 5.6, 5.6), cf * CFrame.new(3.8, 6.2, 0), vc, vm)
		wh.Shape = Enum.PartType.Cylinder
	end
	local function fbBollard(cf: CFrame)
		local sc, sm = sw(STORM, "STONE")
		local mc, mm = sw(STORM, "METAL")
		local cc, cm = sw(STORM, "CANDLE")
		boxAt("BollardPost", V(2.4, 3.0, 2.4), cf * CFrame.new(-0.5, 1.5, 0), sc, sm)
		boxAt("LanternPost", V(0.4, 5.5, 0.4), cf * CFrame.new(-1.8, 2.75, 1.2), mc, mm)
		boxAt("LanternGlow", V(1.0, 1.2, 1.0), cf * CFrame.new(-0.9, 4.4, 1.2), cc, cm)
	end
	local function fbOverflow(cf: CFrame)
		local cr, crm = sw(STORM, "CRYSTAL")
		local ac, am = sw(STORM, "ALT")
		boxAt("OverflowSheet", V(15, 15, 2.6), cf * CFrame.new(0, 7.6, 1.2) * CFrame.Angles(0.22, 0, 0), cr, crm, 0.3)
		lump("OverflowFoam", (cf * CFrame.new(0, 1.5, 3.2)).Position, V(17, 3.2, 5.6), ac, am)
	end
	local function fbStatue(cf: CFrame, s: number)
		local tc, tm = sw(STATUE_WET, "TRIM")
		local vc, vm = sw(STATUE_WET, "ACCENT")
		boxAt("StatueRobe", V(14, 38, 12) * s, cf * CFrame.new(0, 19 * s, 0), tc, tm)
		lump("StatueHead", (cf * CFrame.new(0, 44 * s, 0)).Position, V(8, 10, 8) * s, tc, tm)
		rod("StatueTrident", (cf * CFrame.new(9 * s, 0, 2 * s)).Position, (cf * CFrame.new(9 * s, 60 * s, 2 * s)).Position, 0.8 * s, vc, vm)
	end

	local function place(kind: string, kitName: string?, x: number, z: number, yaw: number, s: number, tint: any, fallback: ((CFrame) -> ())?, y: number?, roll: CFrame?): Instance?
		local m = piece(kind, x, z, yaw, kitName, s, tint, fallback, y, roll)
		if m then count(kitName or kind) end
		return m
	end

	---------------------------------------------------------------------------------------------------
	-- 1. The Sea-Gate (Apex, back-west, 168.5 studs tall -> 226.5 above bottom!) + flanking trident statues.
	---------------------------------------------------------------------------------------------------
	local seaGate = place("SeaGateMonument", "SeaGateArch", -200, -356, 0, 1.0, STORM, fbSeaGate, 48)
	if seaGate then
		pin(seaGate)
		landmarks += 1
		local g = H.glowOf(seaGate)
		if g then light(g, AQUA_LIGHT, 1.6, 85) end
	end
	local stW = place("SeaGateWestStatue", "RobedStatueTrident", -282, -318, 35, 1.6, STATUE_WET, function(cf) fbStatue(cf, 1.6) end, 22)
	if stW then pin(stW); landmarks += 1 end
	local stE = place("SeaGateEastStatue", "RobedStatueStaff", -114, -346, -25, 1.6, STATUE_WET, function(cf) fbStatue(cf, 1.6) end, 22)
	if stE then pin(stE); landmarks += 1 end

	---------------------------------------------------------------------------------------------------
	-- 2. The Slender Tidebell Tower (back-east, 149.2 studs tall behind BellTower terrace).
	---------------------------------------------------------------------------------------------------
	local bellTower = place("TidebellTower", "TidebellTowerSlim", 186, -348, -22, 1.0, STORM, fbTidebellTower, 44)
	if bellTower then
		pin(bellTower)
		landmarks += 1
		local g = H.glowOf(bellTower)
		if g then light(g, AQUA_LIGHT, 1.3, 65) end
	end

	---------------------------------------------------------------------------------------------------
	-- 3. The Five Stepped Lock Chambers (Mitre gates, lock walls, bell gallows, overflow cascades &
	--    drowned barge jammed in Lock 2!).
	---------------------------------------------------------------------------------------------------
	local lockSpecs = {
		{ id = 1, zGate = 36, zMid = 20, yGate = -8, yWall = -6, gallowsX = 58, gallowsY = 0, gallowsYaw = 180 },
		{ id = 2, zGate = -12, zMid = -36, yGate = -4, yWall = 0, gallowsX = 58, gallowsY = 6, gallowsYaw = 180 },
		{ id = 3, zGate = -72, zMid = -100, yGate = 2, yWall = 6, gallowsX = nil, gallowsY = 0, gallowsYaw = 0 },
		{ id = 4, zGate = -140, zMid = -168, yGate = 8, yWall = 12, gallowsX = -58, gallowsY = 18, gallowsYaw = 0 },
		{ id = 5, zGate = -206, zMid = -234, yGate = 14, yWall = 18, gallowsX = 58, gallowsY = 24, gallowsYaw = 180 },
	}
	for _, lk in lockSpecs do
		local mg = place("LockMitreGate", "MitreGatePair", 0, lk.zGate, 0, 1.0, STORM, fbMitreGate, lk.yGate)
		if mg then
			pin(mg)
			landmarks += 1
			if lk.id == 1 or lk.id == 3 or lk.id == 5 then
				local g = H.glowOf(mg)
				if g then light(g, AQUA_LIGHT, 1.1, 46) end
			end
		end
		-- Sculpted foaming overflow ribbons spilling down each lock step!
		if lk.id == 1 or lk.id == 2 or lk.id == 4 or lk.id == 5 then
			local ov = place("LockOverflow", "OverflowRibbon", 0, lk.zGate + 5, 0, 1.15, STORM, fbOverflow, lk.yGate - 2)
			if ov then pin(ov); noCollide(ov); props += 1 end
		end
		-- Retaining lock chamber cheek walls left & right of the water basin
		for _, sx in { -1, 1 } do
			local cx = sx * 58
			if free(cx, lk.zMid, 8) then
				local lw = place("LockChamberWall", "LockChamberWall", cx, lk.zMid, if sx < 0 then 90 else -90, 1.0, STORM, fbLockWall, lk.yWall)
				if lw then pin(lw); props += 1 end
			end
		end
		-- Cantilevered timber bell gallows hanging a bronze Tidebell at each opening lock!
		if lk.gallowsX then
			local gz = if lk.id == 1 then 6 else lk.zGate - 4
			local bg = place("LockBellGallows", "BellGallowsBracket", lk.gallowsX, gz, lk.gallowsYaw, 1.05, STORM, fbBellGallows, lk.gallowsY)
			if bg then pin(bg); landmarks += 1 end
		end
	end
	-- Drowned barge jammed diagonally inside Lock 2 (Water = +4)
	local jammedBarge = place("Lock2JammedBarge", "MooredBarge", -14, -40, 28, 1.0, STORM, fbBarge, 1.0, CFrame.Angles(math.rad(10), 0, math.rad(-14)))
	if jammedBarge then pin(jammedBarge); landmarks += 1 end

	---------------------------------------------------------------------------------------------------
	-- 4. Side-Channel Buildings & Waterworks: Tide Mill, Sluice House, Eel Weir, Upper Pound & Tailwater.
	---------------------------------------------------------------------------------------------------
	local tideMill = place("TideMillBuilding", "TideMillHouse", 304, 62, 180, 1.0, STORM, fbTideMill, -6)
	if tideMill then
		pin(tideMill); landmarks += 1
		local fl = tideMill:FindFirstChild("CANDLE", true) or tideMill:FindFirstChild("MillWindow", true)
		if fl then light(fl, LANTERN_LIGHT, 1.1, 44) end
		pinnedGroup("TideMillSpray", function()
			local anchor = ctx.block("MillSprayAnchor", V(8, 1, 8), V(294, -3, 62), rgb(210, 240, 240), Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "MillWheelSpray"
			pe.Color = ColorSequence.new(rgb(228, 246, 246))
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 5.2) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			pe.Lifetime = NumberRange.new(1.0, 1.8)
			pe.Rate = 12
			pe.Speed = NumberRange.new(3, 6)
			pe.SpreadAngle = Vector2.new(45, 35)
			pe.Parent = anchor
		end)
	end
	local sluiceHouse = place("SluiceHouseBuilding", "SluiceHouseKeep", -304, -22, 90, 1.0, STORM, fbSluiceHouse, 12)
	if sluiceHouse then
		pin(sluiceHouse); landmarks += 1
		local fl = sluiceHouse:FindFirstChild("CANDLE", true) or sluiceHouse:FindFirstChild("SluiceWin", true)
		if fl then light(fl, LANTERN_LIGHT, 1.1, 44) end
		pinnedGroup("SluiceSpray", function()
			local anchor = ctx.block("SluiceSprayAnchor", V(4, 1, 12), V(-290, 10, -22), rgb(210, 240, 240), Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "SluiceFoam"
			pe.Color = ColorSequence.new(rgb(228, 246, 246))
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 4.8) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			pe.Lifetime = NumberRange.new(1.0, 1.8)
			pe.Rate = 12
			pe.Speed = NumberRange.new(4, 7)
			pe.SpreadAngle = Vector2.new(30, 30)
			pe.Parent = anchor
		end)
	end
	-- Eel Weir curved piling traps across east side channel
	local weirA = place("EelWeirEastA", "EelTrapRack", 304, -120, -90, 1.05, STORM, fbEelWeir, -8)
	local weirB = place("EelWeirEastB", "EelTrapRack", 294, -168, -75, 1.0, STORM, fbEelWeir, -8)
	if weirA then pin(weirA); landmarks += 1 end
	if weirB then pin(weirB); landmarks += 1 end
	-- Upper Pound moored drowned barges
	local pBargeA = place("UpperPoundBargeA", "MooredBarge", 312, -250, 90, 1.0, STORM, fbBarge, -6)
	local pBargeB = place("UpperPoundBargeB", "MooredBarge", 282, -304, 15, 1.0, STORM, fbBarge, -6)
	if pBargeA then pin(pBargeA); landmarks += 1 end
	if pBargeB then pin(pBargeB); landmarks += 1 end
	-- Tailwater half-sunk canal wrecks (foreground of the guide image!)
	local twW = place("TailwaterWreckWest", "MooredBarge", -170, 132, 22, 1.05, STORM, fbBarge, -9, CFrame.Angles(math.rad(14), 0, math.rad(12)))
	local twE = place("TailwaterWreckEast", "MooredBarge", 188, 136, -18, 1.05, STORM, fbBarge, -9, CFrame.Angles(math.rad(-12), 0, math.rad(-16)))
	if twW then pin(twW); landmarks += 1 end
	if twE then pin(twE); landmarks += 1 end

	-- Lock-keeper's machinery: bronze sluice winding wheels, tide-gauge columns & harbour storm-lantern bollards
	for _, sg in {
		{ P.WestLockhouse.X - 24, P.WestLockhouse.Z + 18, 90, P.WestLockhouse.Y },
		{ P.EastLockhouse.X + 24, P.EastLockhouse.Z + 18, -90, P.EastLockhouse.Y },
		{ P.UpperWest.X - 24, P.UpperWest.Z - 16, 90, P.UpperWest.Y },
		{ P.UpperEast.X + 24, P.UpperEast.Z - 16, -90, P.UpperEast.Y },
		{ P.HeadGate.X, P.HeadGate.Z - 20, 0, P.HeadGate.Y },
		{ P.SluiceHouse.X - 18, P.SluiceHouse.Z - 14, 90, P.SluiceHouse.Y },
	} do
		if free(sg[1], sg[2], 4.5) then
			take(sg[1], sg[2], 4.5)
			local m = place("LockSluiceGear", "SluiceGear", sg[1], sg[2], sg[3], 1.0, STORM, fbSluiceGear, sg[4])
			if m then pin(m); props += 1 end
		end
	end
	-- Arrival Lock-keeper's Stair framing: twin bell gallows, tide-gauge columns & storm banners!
	local safe = layout.Sanctuary
	for _, sx in { -1, 1 } do
		local gx, gz = sx * 30, safe.Z - safe.Depth / 2 + 8
		local bg = place("ArrivalBellGallows", "BellGallowsBracket", gx, gz, if sx < 0 then 0 else 180, 0.95, STORM, fbBellGallows, safe.Y)
		if bg then pin(bg); props += 1 end
		local tg = place("ArrivalTideGauge", "TideGaugeColumn", sx * 44, gz + 6, 0, 1.05, STORM, fbTideGauge, safe.Y)
		if tg then
			pin(tg); props += 1
			if sx == 1 then
				local g = H.glowOf(tg)
				if g then light(g, AQUA_LIGHT, 1.0, 36) end
			end
		end
	end
	-- Deck undercroft piers under TideMill, SluiceHouse, EelWeir & Pound
	pinnedGroup("ChannelDeckPiers", function()
		local sc, sm = sw(STORM, "STONE")
		for _, id in { "TideMill", "SluiceHouse", "EelWeir", "Pound" } do
			local dk = P[id]
			local pierH = dk.Y - 3 - (bottom - 2)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					boxAt("ChannelPier", V(4.8, pierH, 4.8), CFrame.new(dk.X + sx * (dk.Width / 2 - 5), bottom - 2 + pierH / 2, dk.Z + sz * (dk.Depth / 2 - 5)), sc, sm).CanCollide = false
				end
			end
		end
	end)

	---------------------------------------------------------------------------------------------------
	-- 5. Far Skyline — Brooding Storm Tidewall (north & pressing right behind the west Sea-Gate),
	--    towering misty stone viaduct aqueduct spanning the north ridge, distant falls & rain haze!
	---------------------------------------------------------------------------------------------------
	pinnedGroup("StormTidewall", function()
		local face = rgb(28, 72, 82)
		local segs = 14
		for k = 0, segs - 1 do
			local x0 = -w / 2 + k * w / segs
			local x = x0 + w / segs / 2
			local bow = 4 * math.cos((x / (w / 2)) * math.pi / 2)
			local slab = ctx.block("StormWallWater", V(w / segs + 1, 254, 4), V(x, -10 + 127, -d / 2 + 5 + bow), face, Mat.SmoothPlastic, nil, 0.22)
			slab.CanCollide = false; slab.CanQuery = false; slab.CastShadow = false
			local crest = ctx.block("StormWallFoam", V(w / segs + 1, 8, 6), V(x, 78 + (k % 3) * 8, -d / 2 + 8 + bow), rgb(188, 218, 220), Mat.SmoothPlastic, nil, 0.22)
			crest.CanCollide = false; crest.CastShadow = false
		end
		-- Storming sea wall pressing right along the back-west behind the Sea-Gate!
		for k = 0, 5 do
			local z = -d / 2 + 28 + k * 58
			local westSea = ctx.block("StormWallWest", V(4, 240, 60), V(-w / 2 + 5, 110, z), face, Mat.SmoothPlastic, nil, 0.24)
			westSea.CanCollide = false; westSea.CanQuery = false; westSea.CastShadow = false
		end
		-- High misty stone viaduct aqueduct spanning the ridge between Sea-Gate (-110) and Tidebell Tower (+145)
		local vc, vm = sw(STORM, "STONE")
		local deckY = 146
		ctx.block("DistantViaductDeck", V(240, 7, 10), V(20, deckY, -d / 2 + 12), vc, vm, nil, 0.18).CanCollide = false
		for k = 0, 7 do
			local vx = -85 + k * 30
			ctx.block("DistantViaductPier", V(8, 86, 10), V(vx, deckY - 46, -d / 2 + 12), vc, vm, nil, 0.2).CanCollide = false
		end
		-- Distant storm mist & rain-sheet emitters (3 total: strictly within <= 12 emitter budget)
		for _, rx in { -140, 0, 140 } do
			local rainAnchor = ctx.block("StormRainAnchor", V(180, 1, 180), V(rx, 155, -60), face, Mat.SmoothPlastic, nil, 1)
			rainAnchor.CanCollide = false
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "StormRainHaze"
			pe.Color = ColorSequence.new(rgb(180, 212, 218))
			pe.Size = NumberSequence.new(0.25)
			pe.Squash = NumberSequence.new(4.0)
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 0.96) })
			pe.Lifetime = NumberRange.new(1.8, 2.6)
			pe.Rate = 24
			pe.Speed = NumberRange.new(48, 62)
			pe.EmissionDirection = Enum.NormalId.Bottom
			pe.SpreadAngle = Vector2.new(8, 8)
			pe.Parent = rainAnchor
		end
	end)
	landmarks += 1

	---------------------------------------------------------------------------------------------------
	-- 6. Rich towpath, lock-bank & channel scatter: >= 32 distinct templates across new F38 kit +
	--    reused core/shared templates on main, no single template > 12%, >= 500 props, >= 380 cover!
	---------------------------------------------------------------------------------------------------
	type Kind = { Name: string, Kit: string, S: { number }, R: number, Fallback: (CFrame) -> (), Wet: boolean, Cap: number }
	local kinds: { Kind } = {
		{ Name = "BollardRope", Kit = "BollardRope", S = { 0.9, 1.25 }, R = 3.2, Fallback = fbBollard, Wet = false, Cap = 42 },
		{ Name = "TideGaugeColumn", Kit = "TideGaugeColumn", S = { 0.85, 1.15 }, R = 3.2, Fallback = fbTideGauge, Wet = true, Cap = 32 },
		{ Name = "SluiceGear", Kit = "SluiceGear", S = { 0.75, 1.05 }, R = 4.6, Fallback = fbSluiceGear, Wet = false, Cap = 22 },
		{ Name = "BellGallowsBracket", Kit = "BellGallowsBracket", S = { 0.7, 0.95 }, R = 6.2, Fallback = fbBellGallows, Wet = false, Cap = 16 },
		{ Name = "EelTrapRack", Kit = "EelTrapRack", S = { 0.65, 0.95 }, R = 7.5, Fallback = fbEelWeir, Wet = true, Cap = 14 },
		{ Name = "OverflowRibbon", Kit = "OverflowRibbon", S = { 0.65, 1.0 }, R = 6.5, Fallback = fbOverflow, Wet = true, Cap = 18 },
		{ Name = "LockChamberWall", Kit = "LockChamberWall", S = { 0.6, 0.85 }, R = 9.0, Fallback = fbLockWall, Wet = true, Cap = 14 },
		{ Name = "MooredBarge", Kit = "MooredBarge", S = { 0.7, 0.95 }, R = 10.5, Fallback = fbBarge, Wet = true, Cap = 10 },
		-- Reused core/shared biome templates tinted to wet storm-tide DEEPWARD palette:
		{ Name = "BoulderCluster", Kit = "BoulderCluster", S = { 0.7, 1.35 }, R = 5.0, Fallback = fbBollard, Wet = true, Cap = 44 },
		{ Name = "RuinRubble", Kit = "RuinRubble", S = { 0.7, 1.25 }, R = 4.5, Fallback = fbBollard, Wet = true, Cap = 44 },
		{ Name = "CoralCluster", Kit = "CoralCluster", S = { 0.9, 1.6 }, R = 4.4, Fallback = fbBollard, Wet = true, Cap = 38 },
		{ Name = "ReedPondCluster", Kit = "ReedPondCluster", S = { 0.9, 1.5 }, R = 3.2, Fallback = fbBollard, Wet = true, Cap = 42 },
		{ Name = "GlowLilyCluster", Kit = "GlowLilyCluster", S = { 0.85, 1.35 }, R = 3.0, Fallback = fbBollard, Wet = true, Cap = 34 },
		{ Name = "StoneUrn", Kit = "StoneUrn", S = { 0.7, 1.05 }, R = 2.8, Fallback = fbBollard, Wet = false, Cap = 32 },
		{ Name = "ForgeScrap", Kit = "ForgeScrap", S = { 0.75, 1.2 }, R = 3.6, Fallback = fbBollard, Wet = false, Cap = 32 },
		{ Name = "Cairn", Kit = "Cairn", S = { 0.8, 1.25 }, R = 3.4, Fallback = fbBollard, Wet = false, Cap = 28 },
		{ Name = "Obelisk", Kit = "Obelisk", S = { 0.45, 0.7 }, R = 4.2, Fallback = fbTideGauge, Wet = false, Cap = 22 },
		{ Name = "ArchPierBase", Kit = "ArchPierBase", S = { 0.55, 0.8 }, R = 5.6, Fallback = fbLockWall, Wet = true, Cap = 22 },
		{ Name = "ArchPierSegment", Kit = "ArchPierSegment", S = { 0.5, 0.75 }, R = 5.2, Fallback = fbLockWall, Wet = true, Cap = 18 },
		{ Name = "ArchCrown", Kit = "ArchCrown", S = { 0.45, 0.65 }, R = 7.6, Fallback = fbLockWall, Wet = true, Cap = 12 },
		{ Name = "CurtainWallRuins", Kit = "CurtainWallRuins", S = { 0.5, 0.75 }, R = 8.2, Fallback = fbLockWall, Wet = false, Cap = 14 },
		{ Name = "GothicPillarColonnade", Kit = "GothicPillarColonnade", S = { 0.5, 0.7 }, R = 8.0, Fallback = fbLockWall, Wet = false, Cap = 12 },
		{ Name = "FieldstoneWeir", Kit = "FieldstoneWeir", S = { 0.6, 0.9 }, R = 6.2, Fallback = fbEelWeir, Wet = true, Cap = 16 },
		{ Name = "HangingLantern", Kit = "HangingLantern", S = { 0.9, 1.25 }, R = 2.6, Fallback = fbBollard, Wet = false, Cap = 26 },
		{ Name = "MillWheel", Kit = "MillWheel", S = { 0.55, 0.8 }, R = 6.0, Fallback = fbSluiceGear, Wet = true, Cap = 10 },
		{ Name = "DolmenBellGate", Kit = "DolmenBellGate", S = { 0.55, 0.75 }, R = 7.2, Fallback = fbBellGallows, Wet = false, Cap = 10 },
		{ Name = "FoliageBush", Kit = "FoliageBush", S = { 0.75, 1.25 }, R = 3.4, Fallback = fbBollard, Wet = false, Cap = 32 },
		{ Name = "VaultRibArch", Kit = "VaultRibArch", S = { 0.5, 0.7 }, R = 7.6, Fallback = fbLockWall, Wet = true, Cap = 10 },
		{ Name = "WaterfallRibbon", Kit = "WaterfallRibbon", S = { 0.6, 0.9 }, R = 5.8, Fallback = fbOverflow, Wet = true, Cap = 14 },
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
					local m = place(k.Name, k.Kit, x, z, rng:NextNumber(0, 360), s, STORM, k.Fallback, y)
					if m then
						if k.Name ~= "BoulderCluster" and k.Name ~= "LockChamberWall" and k.Name ~= "MooredBarge" then noCollide(m) end
						used[k.Name] = (used[k.Name] or 0) + 1
						props += 1
						return true
					end
				end
			end
		end
		return false
	end

	-- Terrace corners & quay edges (every terrace becomes a distinct waterworks vignette).
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
	-- Tailwater Quay perimeter bollards, barrels & wrecks (camps at ±110 stay clear).
	for _ = 1, 70 do
		scatterOne(rng:NextNumber(-w / 2 + 18, w / 2 - 18), rng:NextNumber(P.Basin.Z - 42, P.Basin.Z + 44), P.Basin.Y, false)
	end
	-- Both ends of every link dressed off the lane (with storm lanterns & bollards).
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
	-- Open banks, side channels & canal walls (target >= 520 placed props!).
	for _ = 1, 2800 do
		if props >= 525 then break end
		scatterOne(rng:NextNumber(-w / 2 + 16, w / 2 - 16), rng:NextNumber(-d / 2 + 24, d / 2 - 46), nil, true)
	end

	-- Ground cover: wet canal reeds, rubble & moss litter (>= 400).
	local coverKits = { "ReedPondCluster", "FoliageBush", "RuinRubble" }
	for _ = 1, 2500 do
		if cover >= 400 then break end
		local x, z = rng:NextNumber(-w / 2 + 14, w / 2 - 14), rng:NextNumber(-d / 2 + 20, d / 2 - 20)
		local _, onDeck = H.surfaceAt(x, z)
		if not onDeck and (not field or field.Slope(x, z) < 0.85) then
			local okCamp = true
			for _, camp in layout.Camps do
				if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < 38 ^ 2 then okCamp = false break end
			end
			if okCamp and ctx.footprintClear(x, z, 1.8, 1.8) then
				local ck = coverKits[(cover % #coverKits) + 1]
				local m = place("GroundCover", ck, x, z, rng:NextNumber(0, 360), rng:NextNumber(0.45, 0.9), STORM, fbBollard)
				noCollide(m)
				cover += 1
			end
		end
	end

	-- Broad cool storm-tide bounce over the lock flight (2 lights; total floor lights <= 22/24!).
	pinnedGroup("StormCanalBounce", function()
		for _, at in { V(0, 14, 20), V(0, 30, -165) } do
			local anchor = ctx.block("CanalBounceAnchor", V(1, 1, 1), at, STORM_BOUNCE, Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			light(anchor, STORM_BOUNCE, 0.65, 115)
		end
	end)

	local distinct = 0
	for _ in kindsUsed do distinct += 1 end
	ctx.setAttribute("SetPieceLandmarks", landmarks)
	ctx.setAttribute("SetPieceProps", props)
	ctx.setAttribute("SetPieceGroundCover", cover)
	ctx.setAttribute("SetPieceTemplates", distinct)
end

return SunkenFloor38
