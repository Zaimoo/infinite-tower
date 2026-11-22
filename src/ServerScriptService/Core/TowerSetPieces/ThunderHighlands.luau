--!strict
-- Hand-authored set pieces for the Thunder Highlands floors (docs/prompts/thunder-highlands-floor-layouts-prompt.md).
-- TowerBiomeAssets calls Floor26(ctx) for layout.Authored == "thunder:1" with its own builders (ctx), so this
-- module needs nothing from the place at load time and its placement data can be checked by the specs.
--
-- Floor 26, Stormgrass Rise (reference/Thunder Highlands 26.jpg): the Kairnfolk's lower grazing slopes. A dolmen
-- bell-gate on the arrival trail between cairns with copper forked-bolt capstones, dry-stone walls across the
-- moor, a ruined post windmill on its knoll, a sheepfold with its bothy and hurdles on the Cairn Fold, a ring of
-- rune stones round the Standing Stones linked by glowing grounding chains, the shepherd's croft and prayer flags
-- on the Watch, violet storm-glass on the Fulgurite Outcrop and in its strike crater, the twin falls down the
-- headwall, the split granite tor on top of it crowned by a copper forked-bolt totem, an urn shrine on the West
-- Wind-Crag, the summit totem behind the Stormgrass Crown, ridge totems on the far peaks, and wind-bent pines and
-- stormgrass all combed one way by the north-west gale: three skyline layers.
local ThunderHighlands = {}

local V = Vector3.new
local rgb = Color3.fromRGB

-- Kairnfolk palette.
local SLATE = rgb(112, 114, 116)
local SLATE_DARK = rgb(70, 74, 80)
local GRANITE = rgb(128, 126, 120)
local TURF = rgb(78, 110, 62)
local COPPER = rgb(186, 110, 62)
local VERDIGRIS = rgb(88, 150, 132)
local TIMBER = rgb(92, 74, 58)
local TIMBER_DARK = rgb(64, 52, 44)
local WOOL = rgb(222, 216, 202)
local PEAT = rgb(52, 40, 34)
local PINE = rgb(46, 82, 58)
local STORM = rgb(176, 140, 255) -- electric violet
local STORM_GLASS = rgb(150, 112, 255)
local LAMP = rgb(255, 204, 140)
local WATER = rgb(150, 196, 212)
local FOAM = rgb(234, 242, 246)

-- The storm blows from the north-west: every leaning piece (pines, grass, flags) turns its +X lean down-wind,
-- toward the south-east (+X, +Z), at this yaw.
local DOWNWIND_YAW = -45

export type Landmark = {
	Id: string,
	X: number, -- footprint centre (local floor space)
	Z: number,
	Y: number?, -- the surface it stands on; nil: the ground (terrain) under it
	HalfX: number, -- footprint half extents, already turned by the piece's yaw
	HalfZ: number,
	Top: number, -- height above its surface
	Straddles: boolean?, -- a gate that spans a walkway on purpose (its uprights are listed on their own)
}

-- Every Floor 26 landmark's footprint, for the specs (no landmark on a walkway or in a camp) and the census.
ThunderHighlands.Floor26Landmarks = table.freeze({
	-- The headwall: the split granite tor on its turf top, the forked-bolt totem on the tor's east crown, the
	-- twin falls down its south face into the plunge tarn.
	{ Id = "HeadwallTor", X = 3, Z = -95, Y = 58, HalfX = 21, HalfZ = 18, Top = 60 },
	{ Id = "CrownTotem", X = 10.5, Z = -95, Y = 108, HalfX = 8.6, HalfZ = 5.4, Top = 40 },
	{ Id = "FallWest", X = -6, Z = -55, Y = -2, HalfX = 9, HalfZ = 5, Top = 68 },
	{ Id = "FallEast", X = 16, Z = -55.5, Y = -2, HalfX = 9, HalfZ = 5, Top = 68 },
	-- The Windmill Knoll: the windmill on the knoll's south-west shoulder, sails to the gale, outside the camp.
	{ Id = "HighlandWindmill", X = -196, Z = 48, Y = 4, HalfX = 19.4, HalfZ = 19.4, Top = 40 },
	-- The Standing Stones: seven rune stones round the platform on the moor.
	{ Id = "RuneStone0", X = 200, Z = 2, HalfX = 4.6, HalfZ = 4.6, Top = 22 },
	{ Id = "RuneStone30", X = 193.6, Z = 23, HalfX = 4.6, HalfZ = 4.6, Top = 22 },
	{ Id = "RuneStone60", X = 176, Z = 38.4, HalfX = 4.6, HalfZ = 4.6, Top = 22 },
	{ Id = "RuneStone95", X = 147.8, Z = 43.8, HalfX = 4.6, HalfZ = 4.6, Top = 22 },
	{ Id = "RuneStone180", X = 104, Z = 2, HalfX = 4.6, HalfZ = 4.6, Top = 22 },
	{ Id = "RuneStoneN30", X = 193.6, Z = -19, HalfX = 4.6, HalfZ = 4.6, Top = 22 },
	{ Id = "RuneStoneN40", X = 188.8, Z = -25, HalfX = 4.6, HalfZ = 4.6, Top = 22 },
	-- The Cairn Fold: the sheepfold (walls, hurdles, bothy, sheep) on the fold's east half.
	{ Id = "FoldCroft", X = 23, Z = -0.5, Y = 8, HalfX = 9.3, HalfZ = 13.6, Top = 17 },
	{ Id = "SheepPen", X = 26, Z = 28.5, Y = 8, HalfX = 7.5, HalfZ = 14, Top = 5 },
	-- The Shepherd's Watch: the croft, the prayer-flag line and the watch cairn.
	{ Id = "ShepherdCroft", X = -195.4, Z = -146, Y = 10, HalfX = 14.7, HalfZ = 10, Top = 18.3 },
	{ Id = "WatchFlags", X = -140, Z = -125, Y = 10, HalfX = 1.2, HalfZ = 14.6, Top = 9 },
	{ Id = "WatchCairn", X = -150, Z = -150, Y = 10, HalfX = 2.8, HalfZ = 2.8, Top = 16 },
	-- The Fulgurite Outcrop and its strike crater.
	{ Id = "SpurCrystalsNE", X = 200, Z = -140, Y = 12, HalfX = 6.7, HalfZ = 5.2, Top = 16 },
	{ Id = "SpurCrystalsNW", X = 157, Z = -140, Y = 12, HalfX = 5.2, HalfZ = 4, Top = 12.3 },
	{ Id = "SpurCrystalsE", X = 206, Z = -106, Y = 12, HalfX = 4.3, HalfZ = 3.3, Top = 10 },
	{ Id = "CraterCrystals", X = 150, Z = -204, HalfX = 19, HalfZ = 19, Top = 20 },
	-- The bell-gate on the arrival trail: its two uprights, and the capstone with its bells high over the trail.
	{ Id = "BellGateWestUpright", X = -26.1, Z = 150, Y = 0, HalfX = 4.7, HalfZ = 3.8, Top = 36 },
	{ Id = "BellGateEastUpright", X = 26.1, Z = 150, Y = 0, HalfX = 4.7, HalfZ = 3.8, Top = 36 },
	{ Id = "BellGateCapstone", X = 0, Z = 150, Y = 20.5, HalfX = 32, HalfZ = 5.6, Top = 15, Straddles = true },
	{ Id = "GateCairnWest", X = -38, Z = 150, Y = 0, HalfX = 3.1, HalfZ = 3.1, Top = 17 },
	{ Id = "GateCairnEast", X = 38, Z = 150, Y = 0, HalfX = 3.1, HalfZ = 3.1, Top = 17 },
	-- The urn shrine on the West Wind-Crag, and the summit totem on the shelf behind the Stormgrass Crown.
	{ Id = "UrnShrine", X = -101, Z = -116, Y = 16, HalfX = 9, HalfZ = 9, Top = 14 },
	{ Id = "SummitTotem", X = 0, Z = -260, Y = 22, HalfX = 12.4, HalfZ = 7.7, Top = 56 },
}) :: { Landmark }

-- The two falls down the headwall's south face, and how wide each sheet is (WaterfallRibbon at X scale 0.9).
ThunderHighlands.FallXs = table.freeze({ -6, 16 })
ThunderHighlands.FallHalfWidth = 8.1

export type FallFit = {
	Z0: number, -- the sheet's foot (at x = fx), just in front of the face
	Yaw: number, -- radians: the sheet turned square to the face (its +X along the face)
	Tilt: number, -- radians: leaned back (negative) so its top meets the lip
	Length: number, -- along the leaning sheet, foot to lip
	LipY: number, -- the rendered top of the face
}

-- Fits a fall to the cliff behind it (pure maths on the terrain field, so the specs can check it). The face's
-- foot (where it leaves the tarn) and lip (where it meets the turf top) are read at points across the fall's
-- width and a line fitted through each; the sheet stands square to the face along the foot line, leans back to
-- the lip line and is stretched to the rendered top. Then it steps forward until no point of it is behind the
-- rock (smooth terrain renders up to about 2.5 studs over the field's height), so the water runs the whole face
-- from lip to pool without rock showing through it.
function ThunderHighlands.FitFall(field: any, fx: number, fy: number, halfWidth: number): FallFit
	-- The lip's height where it is lowest across the fall, so no corner of the sheet stands above the turf.
	local top = math.huge
	for k = -2, 2 do
		local highest = -math.huge
		for z = -56, -74, -2 do
			highest = math.max(highest, field.Height(fx + halfWidth * k / 2, z))
		end
		top = math.min(top, highest)
	end
	local xs, feet, lips = {}, {}, {}
	for k = -3, 3 do
		local dx = halfWidth * k / 3
		local foot, lip = nil, nil
		for z = -40, -84, -0.5 do
			local h = field.Height(fx + dx, z)
			if not foot and h > field.LiquidLevel + 2 then foot = z end
			if h >= top - 4 then
				lip = z
				break
			end
		end
		if foot and lip then
			table.insert(xs, dx)
			table.insert(feet, foot)
			table.insert(lips, lip)
		end
	end
	-- The face's run across the fall (least squares on the foot), then each line shifted forward to clear
	-- every sample.
	local n = #xs
	local mx, mz = 0, 0
	for i = 1, n do
		mx += xs[i] / n
		mz += feet[i] / n
	end
	local sxx, sxz = 0, 0
	for i = 1, n do
		sxx += (xs[i] - mx) ^ 2
		sxz += (xs[i] - mx) * (feet[i] - mz)
	end
	local slope = if sxx > 0 then sxz / sxx else 0
	local footB, lipB = -math.huge, -math.huge
	for i = 1, n do
		footB = math.max(footB, feet[i] - slope * xs[i])
		lipB = math.max(lipB, lips[i] - slope * xs[i])
	end
	local lipY = top + 1
	local yaw = -math.atan(slope)
	local cosYaw, sinYaw = math.cos(yaw), math.sin(yaw)
	local z0, z1 = footB + 1.5, lipB + 1.5
	local tilt, length = 0, 0
	for _ = 1, 30 do
		local rise = lipY - fy
		local run = math.max(0, (z0 - z1) * cosYaw)
		tilt = -math.atan2(run, rise)
		length = math.sqrt(rise * rise + run * run)
		local sinT, cosT = math.sin(tilt), math.cos(tilt)
		local worst = -math.huge
		for k = -4, 4 do
			local u = halfWidth * k / 4
			for f = 0.03, 1, 0.03 do
				local v = f * length
				local x = fx + u * cosYaw + v * sinT * sinYaw
				local y = fy + v * cosT
				local z = z0 - u * sinYaw + v * sinT * cosYaw
				worst = math.max(worst, field.Height(x, z) + 2.5 - y)
			end
		end
		if worst <= 0 then
			break
		end
		z0 += 0.5
		z1 += 0.5
	end
	return { Z0 = z0, Yaw = yaw, Tilt = tilt, Length = length, LipY = lipY }
end

-- The kit's Kairnfolk tints (every Floor 26 template uses these roles).
local KAIRN = table.freeze({
	STONE = { Color = SLATE, Material = Enum.Material.Slate },
	MOSS = { Color = TURF, Material = Enum.Material.Grass },
	METAL = { Color = COPPER, Material = Enum.Material.Metal },
	ACCENT = { Color = VERDIGRIS, Material = Enum.Material.Metal },
	WOOD = { Color = TIMBER, Material = Enum.Material.Wood },
	TRIM = { Color = SLATE_DARK, Material = Enum.Material.Slate },
	ALT = { Color = WOOL, Material = Enum.Material.Fabric },
	GLOW = { Color = STORM, Material = Enum.Material.Neon },
	FOLIAGE = { Color = PINE, Material = Enum.Material.Grass },
	CRYSTAL = { Color = STORM_GLASS, Material = Enum.Material.Glass, Transparency = 0.15 },
	GOLD = { Color = rgb(176, 132, 70), Material = Enum.Material.Metal },
})
local function tinted(base: any, changes: { [string]: any }): any
	local o = table.clone(base)
	for role, swatch in changes do
		o[role] = swatch
	end
	return o
end
local GRANITE_TINT = tinted(KAIRN, { STONE = { Color = GRANITE, Material = Enum.Material.Granite }, ALT = { Color = SLATE_DARK, Material = Enum.Material.Slate } })
local CROFT_TINT = tinted(KAIRN, { GLOW = { Color = LAMP, Material = Enum.Material.Neon } })
local SAIL_TINT = tinted(KAIRN, { ALT = { Color = rgb(186, 172, 148), Material = Enum.Material.Fabric } })
local SHEEP_TINT = tinted(KAIRN, { TRIM = { Color = rgb(40, 36, 34), Material = Enum.Material.SmoothPlastic } })
local FLAG_TINT = tinted(KAIRN, {
	ALT = { Color = rgb(196, 56, 48), Material = Enum.Material.Fabric },
	ACCENT = { Color = rgb(226, 186, 62), Material = Enum.Material.Fabric },
	GOLD = { Color = rgb(62, 98, 178), Material = Enum.Material.Fabric },
	TRIM = { Color = rgb(150, 132, 104), Material = Enum.Material.Fabric },
})
local WATER_TINT = tinted(KAIRN, {
	-- Pale, frothing white water: Glass rendered the sheet as a flat turquoise board.
	CRYSTAL = { Color = rgb(206, 228, 236), Material = Enum.Material.SmoothPlastic, Transparency = 0.25 },
	ALT = { Color = FOAM, Material = Enum.Material.SmoothPlastic },
})

function ThunderHighlands.Floor26(ctx: any)
	local origin: Vector3 = ctx.origin
	local layout = ctx.layout
	local field = ctx.field
	local bottom: number = ctx.bottom
	local w: number, d: number = ctx.w, ctx.d
	local P = layout.Platforms
	local landmarks, props, cover = 0, 0, 0

	-- The surface at (x, z): a terrace's or deck's top, else the terrain (or the chasm floor without terrain).
	local function surfaceAt(x: number, z: number): (number, boolean)
		for id, p in P do
			if id ~= "Sanctuary" and math.abs(x - p.X) <= p.Width / 2 and math.abs(z - p.Z) <= p.Depth / 2 then
				return p.Y, true
			end
		end
		if field then
			return field.Height(x, z) + 1.6, false
		end
		return bottom, false
	end
	-- The lowest ground under a footprint (so a broad piece sinks in rather than hovering on a slope).
	local function lowestGround(x: number, z: number, half: number): number
		if not field then
			return bottom
		end
		local low = math.huge
		for _, ox in { -half, 0, half } do
			for _, oz in { -half, 0, half } do
				low = math.min(low, field.Height(x + ox, z + oz))
			end
		end
		return low + 1.4
	end
	local function boxAt(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, trans: number?): Part
		local p = ctx.block(name, size, cf.Position, color, mat, nil, trans)
		p.CFrame = CFrame.new(origin) * cf
		return p
	end
	-- A cylinder from a to b (local space).
	local function rod(name: string, a: Vector3, b: Vector3, radius: number, color: Color3, mat: Enum.Material): Part
		local len = math.max(0.1, (b - a).Magnitude)
		local p = ctx.block(name, V(len, radius * 2, radius * 2), (a + b) / 2, color, mat, Enum.PartType.Cylinder)
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b) * CFrame.Angles(0, math.pi / 2, 0)
		return p
	end
	local function lump(name: string, at: Vector3, size: Vector3, color: Color3, mat: Enum.Material): Part
		return ctx.orb(name, at, size, color, mat)
	end
	local function light(p: Instance?, color: Color3, brightness: number, range: number)
		if p then ctx.pointLight(p, color, brightness, range) end
	end
	local function noCollide(m: Instance?)
		if not m then return end
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				p.CastShadow = false
			end
		end
	end
	-- A drifting emitter (falls spray, chimney smoke, static sparks), counted in the floor's emitter budget.
	local function emitter(name: string, at: Vector3, color: Color3, size: number, rate: number, speed: number, lifetime: number, spread: number, glow: boolean)
		local anchor = ctx.block(name .. "MistAnchor", V(1, 1, 1), at, color, Enum.Material.SmoothPlastic, nil, 1)
		anchor.CanCollide = false
		anchor.CanQuery = false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = name
		pe.Color = ColorSequence.new(color)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, if glow then 0.2 else 0.55), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
		pe.Rate = rate
		pe.Speed = NumberRange.new(speed * 0.5, speed)
		pe.SpreadAngle = Vector2.new(spread, spread)
		-- The gale carries everything south-east.
		pe.Acceleration = V(1.6, if glow then 0 else 0.8, 1.6)
		pe.RotSpeed = NumberRange.new(-25, 25)
		pe.LightEmission = if glow then 0.9 else 0
		pe.Parent = anchor
		return anchor
	end

	-- Places a kit template (or its native fallback) as one prop at (x, z) on whatever is under it, and returns
	-- the prop (its PropKind Model). On open terrain it is tagged OnTerrain, so the settle pass leaves it.
	local function piece(kind: string, x: number, z: number, yawDeg: number, kitName: string?, s: number, override: any?, fallback: ((cf: CFrame) -> ())?, y: number?, onTerrain: boolean?): Instance?
		local gy, onDeck = surfaceAt(x, z)
		local baseY = y or gy
		local prop: Instance? = nil
		ctx.group(kind, function()
			prop = ctx.current()
			if (not onDeck and y == nil) or onTerrain then
				ctx.tag("OnTerrain", true)
			end
			local cf = CFrame.new(x, baseY, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
			if kitName and ctx.has(kitName) then
				ctx.kitAt(kitName, cf * CFrame.new(0, if onDeck and y == nil then 0 else -0.35, 0), s, override)
			elseif fallback then
				fallback(cf)
			end
		end)
		return prop
	end
	local function glowOf(prop: Instance?): Instance?
		return if prop then prop:FindFirstChild("GLOW", true) else nil
	end

	-- =====================================================================================================
	-- Native fallbacks (until the Floor 26 kit is imported). cf: the piece's origin on its surface, front +Z.
	-- =====================================================================================================
	local function fallbackTotem(cf: CFrame, s: number)
		for k, r in { 5.6, 4.2, 3.0 } do
			ctx.cyl("TotemCairnTier", (cf * CFrame.new(0, (k - 0.5) * 2 * s, 0)).Position, r * s, 2.1 * s, if k % 2 == 0 then SLATE_DARK else SLATE, Enum.Material.Slate)
		end
		boxAt("TotemShaft", V(3.4, 24, 3.4) * s, cf * CFrame.new(0, 18 * s, 0) * CFrame.Angles(0, math.pi / 4, 0), GRANITE, Enum.Material.Granite)
		for k = 1, 3 do
			ctx.cyl("TotemCopperRing", (cf * CFrame.new(0, (6 + k * 6) * s, 0)).Position, 2.6 * s, 0.8 * s, COPPER, Enum.Material.Metal)
		end
		for _, sx in { -1, 1 } do
			local blade = boxAt("TotemStormBlade", V(8, 9, 0.8) * s, cf * CFrame.new(sx * 5 * s, 34 * s, 0) * CFrame.Angles(0, 0, sx * math.rad(-18)), COPPER, Enum.Material.Metal)
			blade.CanCollide = false
			local bolt = boxAt("TotemBoltGlowSeam", V(0.5, 7, 0.3) * s, cf * CFrame.new(sx * 5 * s, 34 * s, -0.6 * s) * CFrame.Angles(0, 0, sx * math.rad(20)), STORM, Enum.Material.Neon)
			bolt.CanCollide = false
		end
		boxAt("TotemSpike", V(1.2, 10, 1.2) * s, cf * CFrame.new(0, 36 * s, 0), COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackTor(cf: CFrame, s: number)
		for _, side in { { -11, 78 }, { 12, 84 } } do
			local x, h = side[1], side[2]
			local z = 0
			local k = 0
			while z < h do
				local bh = 8 + (k % 3)
				local wdt = 24 - (z / h) * 8
				boxAt("TorGraniteBlock", V(wdt, bh + 0.5, 28 - (z / h) * 9) * s, cf * CFrame.new(x * s, (z + bh / 2) * s, 0) * CFrame.Angles(0, (k % 2) * 0.06, 0), if k % 2 == 0 then GRANITE else SLATE, Enum.Material.Granite)
				z += bh
				k += 1
			end
		end
	end
	local function fallbackWindmill(cf: CFrame, s: number)
		ctx.cyl("WindmillDrumWall", (cf * CFrame.new(0, 4.5 * s, 0)).Position, 8.6 * s, 9 * s, SLATE, Enum.Material.Slate)
		boxAt("WindmillPost", V(2.4, 6, 2.4) * s, cf * CFrame.new(0, 12.5 * s, 0), TIMBER_DARK, Enum.Material.Wood)
		boxAt("WindmillBody", V(12, 17, 14) * s, cf * CFrame.new(0, 22.5 * s, 0), TIMBER, Enum.Material.Wood)
		for _, sx in { -1, 1 } do
			boxAt("WindmillRoof", V(8, 0.6, 16) * s, cf * CFrame.new(sx * 3.2 * s, 33.6 * s, 0) * CFrame.Angles(0, 0, sx * math.rad(-38)), SLATE_DARK, Enum.Material.Slate)
		end
		local hub = cf * CFrame.new(0, 28 * s, 8.8 * s)
		for k = 0, 3 do
			local a = math.rad(28 + k * 90)
			local len = (if k == 2 then 10 else 21) * s
			local sail = boxAt("WindmillSail", V(len, 4, 0.4) * s, hub * CFrame.Angles(0, 0, a) * CFrame.new(len / 2, 0, 0), TIMBER, Enum.Material.Wood)
			sail.Size = V(len, 4 * s, 0.4 * s)
			sail.CanCollide = false
		end
		local tail = rod("WindmillTailPole", (cf * CFrame.new(0, 17 * s, -7 * s)).Position, (cf * CFrame.new(0, 0.4 * s, -23 * s)).Position, 0.55 * s, TIMBER_DARK, Enum.Material.Wood)
		tail.CanCollide = false
	end
	local function fallbackRuneStone(cf: CFrame, s: number)
		lump("RuneStandingStone", (cf * CFrame.new(0, 6.5 * s, 0)).Position, V(4.6, 14, 2.4) * s, SLATE, Enum.Material.Slate)
		local rune = boxAt("RuneBoltGlowSeam", V(0.5, 5, 0.2) * s, cf * CFrame.new(0, 6 * s, -1.25 * s) * CFrame.Angles(0, 0, math.rad(14)), STORM, Enum.Material.Neon)
		rune.CanCollide = false
	end
	local function fallbackCroft(cf: CFrame, s: number)
		boxAt("CroftWall", V(20, 7.5, 12) * s, cf * CFrame.new(0, 3.75 * s, 0), SLATE, Enum.Material.Slate)
		for _, sz in { -1, 1 } do
			boxAt("CroftTurfRoof", V(21.6, 0.9, 8) * s, cf * CFrame.new(0, 9.6 * s, sz * 3.1 * s) * CFrame.Angles(sz * math.rad(36), 0, 0), TURF, Enum.Material.Grass)
		end
		boxAt("CroftChimneyWall", V(2.4, 5, 2.4) * s, cf * CFrame.new(8.4 * s, 10.5 * s, 0), SLATE_DARK, Enum.Material.Slate)
		boxAt("CroftDoor", V(2.6, 4.6, 0.4) * s, cf * CFrame.new(-3 * s, 2.3 * s, 6.05 * s), TIMBER, Enum.Material.Wood)
		local win = boxAt("CroftWindowGlowSeam", V(1.8, 1.5, 0.2) * s, cf * CFrame.new(4 * s, 3.6 * s, 6.05 * s), LAMP, Enum.Material.Neon)
		win.CanCollide = false
	end
	local function fallbackWall(cf: CFrame, s: number)
		boxAt("DryStoneWallRun", V(24, 3, 1.6) * s, cf * CFrame.new(0, 1.5 * s, 0), SLATE, Enum.Material.Slate)
		boxAt("DryStoneWallCoping", V(24, 0.8, 1.9) * s, cf * CFrame.new(0, 3.3 * s, 0), SLATE_DARK, Enum.Material.Slate)
	end
	local function fallbackHurdle(cf: CFrame, s: number)
		for _, x in { -6, -2, 2, 6 } do
			boxAt("HurdlePost", V(0.6, 4.6, 0.6) * s, cf * CFrame.new(x * s, 2.3 * s, 0), TIMBER_DARK, Enum.Material.Wood)
		end
		for _, y in { 1, 2, 3, 4 } do
			boxAt("HurdleRail", V(12, 0.4, 0.3) * s, cf * CFrame.new(0, y * s, 0), TIMBER, Enum.Material.Wood)
		end
	end
	local function fallbackCairn(cf: CFrame, s: number)
		for k = 0, 5 do
			lump("TrailCairnStone", (cf * CFrame.new(0, (0.6 + k * 1.05) * s, 0)).Position, V(4.2 - k * 0.45, 1.2, 3.6 - k * 0.4) * s, if k % 2 == 0 then SLATE else GRANITE, Enum.Material.Slate)
		end
		boxAt("CairnCopperBolt", V(0.6, 4, 0.4) * s, cf * CFrame.new(0, 8.6 * s, 0) * CFrame.Angles(0, 0, math.rad(16)), COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackPine(cf: CFrame, s: number)
		local base = cf.Position
		local top = (cf * CFrame.new(14 * s, 28 * s, 0)).Position
		rod("WindPineTrunk", base, top, 0.9 * s, TIMBER_DARK, Enum.Material.Wood)
		for k = 0, 3 do
			local at = (cf * CFrame.new((7 + k * 2.4) * s, (15 + k * 3.4) * s, 0)).Position
			lump("WindPineNeedles", at, V(13 - k * 1.6, 3, 9 - k) * s, PINE, Enum.Material.Grass)
		end
	end
	local function fallbackTuft(cf: CFrame, s: number)
		lump("StormgrassClump", (cf * CFrame.new(0.4 * s, 0.6 * s, 0)).Position, V(3.2, 1.6, 2.6) * s, rgb(92, 120, 64), Enum.Material.Grass)
	end
	local function fallbackDolmen(cf: CFrame, s: number)
		for _, sx in { -1, 1 } do
			lump("DolmenUprightMonolith", (cf * CFrame.new(sx * 18 * s, 10 * s, 0)).Position, V(6.4, 20.5, 5.2) * s, SLATE, Enum.Material.Slate)
		end
		lump("DolmenCapstoneMonolith", (cf * CFrame.new(0, 21.4 * s, 0)).Position, V(44, 4.6, 7.6) * s, GRANITE, Enum.Material.Slate)
		for k, x in { -8, 0, 8 } do
			local bell = ctx.block("DolmenStormBell", V(2.4, 2.6, 2.4) * s, (cf * CFrame.new(x * s, (16.6 - (if k == 2 then 0.4 else 0)) * s, 0)).Position, rgb(176, 132, 70), Enum.Material.Metal)
			bell.CanCollide = false
		end
	end
	local function fallbackSheep(cf: CFrame, s: number)
		lump("SheepFleece", (cf * CFrame.new(0, 2 * s, 0)).Position, V(2.6, 2.4, 4.4) * s, WOOL, Enum.Material.Fabric)
		lump("SheepHead", (cf * CFrame.new(0, 1.4 * s, 2.6 * s)).Position, V(1, 1, 1.6) * s, rgb(40, 36, 34), Enum.Material.SmoothPlastic)
	end
	-- A fall (sy: its height over the template's 60 studs), standing on its foot.
	local function fallbackFall(cf: CFrame, sy: number)
		local sheet = boxAt("HeadwallFallWater", V(9, 60 * sy, 1.2), cf * CFrame.new(0, 30 * sy, 1), WATER, Enum.Material.SmoothPlastic, 0.25)
		sheet.CanCollide = false
		lump("HeadwallFallFoam", (cf * CFrame.new(0, 0.8, 1.5)).Position, V(12, 3, 6), FOAM, Enum.Material.SmoothPlastic)
	end
	local function fallbackFlags(cf: CFrame, s: number)
		for _, sx in { -1, 1 } do
			boxAt("FlagPole", V(0.6, 11, 0.6) * s, cf * CFrame.new(sx * 15 * s, 5.5 * s, 0), TIMBER_DARK, Enum.Material.Wood)
		end
		for k = 1, 14 do
			local f = k / 15
			local x = (-15 + f * 30) * s
			local y = (11 - 3.2 * math.sin(f * math.pi) - 1) * s
			local dyes = { rgb(196, 56, 48), rgb(226, 186, 62), rgb(62, 98, 178) }
			local flag = boxAt("PrayerFlag", V(1.5, 1.7, 0.1) * s, cf * CFrame.new(x, y, 0), dyes[k % 3 + 1], Enum.Material.Fabric)
			flag.CanCollide = false
		end
	end
	local function fallbackCrystals(cf: CFrame, s: number)
		lump("StormGlassBed", (cf * CFrame.new(0, 0.3 * s, 0)).Position, V(11, 1.6, 9) * s, SLATE_DARK, Enum.Material.Basalt)
		for k = 0, 5 do
			local a = k * 1.05
			local h = (6 + (k % 3) * 4) * s
			local shard = boxAt("StormGlassShard", V(1.6 * s, h, 1.6 * s), cf * CFrame.new(math.cos(a) * 2.6 * s, h / 2, math.sin(a) * 2.6 * s) * CFrame.Angles(math.sin(a) * 0.3, 0, math.cos(a) * 0.3), STORM_GLASS, Enum.Material.Glass, 0.15)
			shard.CanCollide = k % 2 == 0
		end
	end

	for _, lm in ThunderHighlands.Floor26Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =====================================================================================================
	-- 1. The headwall: the split granite tor on its turf top, the copper forked-bolt totem on the tor's east
	--    crown crackling with static, and the twin falls spilling down the south face into the plunge tarn.
	-- =====================================================================================================
	local torScale = 0.62
	local torY = lowestGround(3, -95, 14)
	piece("HeadwallTor", 3, -95, 0, "SplitGraniteTor", torScale, GRANITE_TINT, function(cf) fallbackTor(cf, torScale) end, torY, true)
	local crownY = torY + 86.7 * torScale
	local crown = piece("CrownTotem", 10.3, -95, 0, "ForkedBoltTotem", 0.95, KAIRN, function(cf) fallbackTotem(cf, 0.95) end, crownY)
	light(glowOf(crown), STORM, 1.6, 60)
	emitter("CrownStaticSparks", V(10.3, crownY + 38, -95), STORM, 0.5, 6, 3, 1.2, 180, true)
	landmarks += 2
	props += 2
	for k, fx in ThunderHighlands.FallXs do
		local fy = if field then field.LiquidLevel - 0.6 else bottom
		local fit = if field then ThunderHighlands.FitFall(field, fx, fy, ThunderHighlands.FallHalfWidth)
			else { Z0 = -53, Yaw = 0, Tilt = 0, Length = 62, LipY = fy + 62 }
		local footZ = fit.Z0
		local sy = fit.Length / 60
		local cf = CFrame.new(fx, fy, fit.Z0) * CFrame.Angles(0, fit.Yaw, 0) * CFrame.Angles(fit.Tilt, 0, 0)
		ctx.group("HeadwallFall", function()
			ctx.tag("OnTerrain", true)
			if ctx.has("WaterfallRibbon") then
				ctx.kitAt("WaterfallRibbon", cf, V(ThunderHighlands.FallHalfWidth / 9, sy, 1), WATER_TINT)
			else
				fallbackFall(cf, sy)
			end
		end)
		emitter("FallSprayMist", V(fx, fy + 2, fit.Z0 + 4), FOAM, 4, 6, 3, 2.6, 40, false)
		-- Spray tumbling off the lip down the face of the fall.
		local lipAt = cf * CFrame.new(0, fit.Length - 1, 1)
		local lip = emitter("FallLipSpray", lipAt.Position, FOAM, 2.2, 10, 4, 3, 25, false)
		local spray = lip:FindFirstChildOfClass("ParticleEmitter")
		if spray then
			spray.EmissionDirection = Enum.NormalId.Bottom
			spray.Acceleration = V(0.6, -16, 0.6)
		end
		-- Spray-slick boulders at the foot, either side of the plunge.
		for _, sx in { -1, 1 } do
			piece("FallBoulders", fx + sx * 11, footZ + 7 + k, sx * 40, "BoulderCluster", 0.7, KAIRN, function(cf)
				lump("FallBoulder", (cf * CFrame.new(0, 1, 0)).Position, V(6, 3.4, 5), SLATE_DARK, Enum.Material.Slate)
			end)
		end
	end
	landmarks += 2
	props += 6

	-- =====================================================================================================
	-- 2. The Windmill Knoll: the ruined post windmill on the knoll's south-west shoulder, its sails turned
	--    into the gale and its tail pole down-wind; sacks and a millstone at its door.
	-- =====================================================================================================
	local wg = P.WestGallery
	local mill = piece("HighlandWindmill", -192, 44, 135, "HighlandWindmill", 0.85, SAIL_TINT, function(cf) fallbackWindmill(cf, 0.85) end, wg.Y)
	if mill then
		-- The millstone leaning against the drum.
		ctx.group("Millstone", function()
			local at = V(-182, wg.Y, 50)
			local stone = ctx.cyl("Millstone", at + V(0, 2.4, 0), 2.6, 1, GRANITE, Enum.Material.Granite)
			stone.CFrame = CFrame.new(origin + at + V(0, 2.4, 0)) * CFrame.Angles(0, math.rad(30), math.rad(80))
		end)
	end
	for k, spot in { { -176, 46 }, { -199, 30 }, { -184, 24 } } do
		piece("MillSacks", spot[1], spot[2], k * 41, nil, 1, nil, function(cf)
			for j = 0, 1 do
				lump("MillSack", (cf * CFrame.new(j * 1.8, 1.1, j * 0.6)).Position, V(1.8, 2.2, 1.6), rgb(188, 170, 136), Enum.Material.Fabric)
			end
		end, wg.Y)
	end
	landmarks += 1
	props += 5

	-- =====================================================================================================
	-- 3. The Standing Stones: seven rune stones ringing the platform on the moor, glowing grounding chains slung
	--    between neighbours (never across a walkway), a copper grounding stake at the ring's heart-line.
	-- =====================================================================================================
	local eg = P.EastGallery
	local ringStones = { { 0, 200, 2 }, { 30, 193.6, 23 }, { 60, 176, 38.4 }, { 95, 147.8, 43.8 }, { 180, 104, 2 }, { -30, 193.6, -19 }, { -40, 188.8, -25 } }
	local stoneTops: { [number]: Vector3 } = {}
	for k, st in ringStones do
		local x, z = st[2], st[3]
		local gy = lowestGround(x, z, 2.5)
		-- Each stone faces the ring's centre.
		local yaw = math.deg(math.atan2(eg.X - x, eg.Z - z))
		piece("RuneStone", x, z, yaw, "RuneStandingStone", 1.4, KAIRN, function(cf) fallbackRuneStone(cf, 1.4) end, gy, true)
		stoneTops[k] = V(x, gy + 14, z)
	end
	-- Chains between ring neighbours, sagging; skipped where a walkway runs between them.
	local chainPairs = { { 6, 7 }, { 6, 1 }, { 1, 2 }, { 2, 3 }, { 3, 4 } }
	local chained = 0
	for _, pair in chainPairs do
		local a, b = stoneTops[pair[1]], stoneTops[pair[2]]
		local clear = true
		for t = 0.2, 0.8, 0.3 do
			local m = a:Lerp(b, t)
			if not ctx.footprintClear(m.X, m.Z, 1.5, 1.5) then clear = false end
		end
		if clear then
			ctx.group("GroundingChain", function()
				local segs = 6
				local prev = a
				for s = 1, segs do
					local t = s / segs
					local p = a:Lerp(b, t) - V(0, math.sin(t * math.pi) * 3.4, 0)
					local link = rod("GroundingChainCopper", prev, p, 0.22, COPPER, Enum.Material.Metal)
					link.CanCollide = false
					local spark = rod("GroundingChainGlowSeam", prev + V(0, 0.3, 0), p + V(0, 0.3, 0), 0.08, STORM, Enum.Material.Neon)
					spark.CanCollide = false
					prev = p
				end
			end)
			chained += 1
		end
	end
	ctx.setAttribute("Floor26ChainsHung", chained)
	-- A low violet glow in the ring (one light for the whole circle).
	ctx.group("StoneRingGlow", function()
		local anchor = ctx.block("StoneRingGlowAnchor", V(1, 1, 1), V(eg.X + 30, eg.Y + 10, eg.Z + 20), STORM, Enum.Material.SmoothPlastic, nil, 1)
		anchor.CanCollide = false
		anchor.CanQuery = false
		light(anchor, STORM, 0.9, 50)
	end)
	landmarks += 1
	props += #ringStones + chained

	-- =====================================================================================================
	-- 4. The Cairn Fold: the fold-keeper's croft on the fold's north-east, its door facing the fold, and the
	--    sheep pen against its south gable (a dry-stone wall east and south, hurdles and a gap on the west),
	--    sheep penned inside, a cairn at the fold's corner.
	-- =====================================================================================================
	local cr = P.Crossing
	local foldCroft = piece("FoldCroft", 23, -0.5, -90, "ShepherdCroft", 1.2, CROFT_TINT, function(cf) fallbackCroft(cf, 1.2) end, cr.Y)
	light(glowOf(foldCroft), LAMP, 0.8, 22)
	piece("SheepfoldWall", 32, 28.5, 90, "DryStoneWall", 1.1, KAIRN, function(cf) fallbackWall(cf, 1.1) end, cr.Y)
	piece("SheepfoldWall", 26, 42, 180, "DryStoneWall", 0.55, KAIRN, function(cf) fallbackWall(cf, 0.55) end, cr.Y)
	piece("SheepfoldHurdle", 19.5, 20.5, 90, "RamHurdleFence", 1, KAIRN, function(cf) fallbackHurdle(cf, 1) end, cr.Y)
	piece("SheepfoldHurdle", 19.5, 36.5, 90, "RamHurdleFence", 1, KAIRN, function(cf) fallbackHurdle(cf, 1) end, cr.Y)
	for k, spot in { { 25, 22 }, { 28.5, 33 }, { 23, 30 }, { 26, 38.5 } } do
		piece("PennedSheep", spot[1], spot[2], k * 77, "HighlandSheep", 1, SHEEP_TINT, function(cf) fallbackSheep(cf, 1) end, cr.Y)
	end
	piece("FoldCairn", -38, 42, 20, "TrailCairnTall", 1, KAIRN, function(cf) fallbackCairn(cf, 1) end, cr.Y)
	landmarks += 1
	props += 10

	-- =====================================================================================================
	-- 5. The Shepherd's Watch: the croft on the platform's west edge with its peat smoke, a prayer-flag line
	--    along the north edge, the watch cairn and sheep, wool bales by the door.
	-- =====================================================================================================
	local sw = P.ShepherdWatch
	local croft = piece("ShepherdCroft", -196, -146, 0, "ShepherdCroft", 1.3, CROFT_TINT, function(cf) fallbackCroft(cf, 1.3) end, sw.Y)
	light(glowOf(croft), LAMP, 0.9, 28)
	emitter("CroftPeatSmoke", V(-185, sw.Y + 19, -146), rgb(150, 146, 150), 2.5, 2, 2, 5, 12, false)
	piece("WatchFlags", -140, -125, 90, "PrayerFlagLine", 0.8, FLAG_TINT, function(cf) fallbackFlags(cf, 0.8) end, sw.Y)
	piece("WatchCairn", -150, -150, 15, "TrailCairnTall", 1.2, KAIRN, function(cf) fallbackCairn(cf, 1.2) end, sw.Y)
	for k, spot in { { -170, -136 }, { -160, -132 }, { -215, -128 } } do
		piece("WatchSheep", spot[1], spot[2], k * 63 + 20, "HighlandSheep", 1, SHEEP_TINT, function(cf) fallbackSheep(cf, 1) end, sw.Y)
	end
	piece("WoolBales", -214, -116, 10, nil, 1, nil, function(cf)
		for j = 0, 2 do
			ctx.cyl("WoolBale", (cf * CFrame.new(j * 2.6 - 2.6, 1.2, 0)).Position, 1.2, 2.2, WOOL, Enum.Material.Fabric)
		end
	end, sw.Y)
	landmarks += 3
	props += 8

	-- =====================================================================================================
	-- 6. The Fulgurite Outcrop and its strike crater: storm-glass erupting on the spur's free corners, and a burst
	--    of it in the scorched crater upslope, crackling.
	-- =====================================================================================================
	local fs = P.FulguriteSpur
	for _, spot in { { 200, -140, 1.1, 20 }, { 157, -140, 0.85, -40 }, { 206, -106, 0.7, 70 } } do
		piece("SpurStormGlass", spot[1], spot[2], spot[4], "StormCrystalSpikes", spot[3], KAIRN, function(cf) fallbackCrystals(cf, spot[3]) end, fs.Y)
	end
	local craterY = lowestGround(150, -204, 4)
	local craterGlass = piece("CraterStormGlass", 150, -204, 0, "StormCrystalSpikes", 1.4, KAIRN, function(cf) fallbackCrystals(cf, 1.4) end, craterY, true)
	light(glowOf(craterGlass), STORM, 1.5, 44)
	for k, off in { { 15, 0 }, { -15, 2 }, { 1, 15 }, { -2, -15 } } do
		local x, z = 150 + off[1], -204 + off[2]
		piece("CraterStormGlass", x, z, k * 83, "StormCrystalSpikes", 0.6 + (k % 2) * 0.25, KAIRN, function(cf) fallbackCrystals(cf, 0.7) end, lowestGround(x, z, 3), true)
	end
	emitter("CraterStaticSparks", V(150, craterY + 6, -204), STORM, 0.4, 8, 5, 0.8, 180, true)
	local spurLightAnchor = piece("SpurGlowAnchor", fs.X + 10, fs.Z - 18, 0, nil, 1, nil, function(cf)
		local a = boxAt("SpurGlowAnchor", V(1, 1, 1), cf * CFrame.new(0, 6, 0), STORM, Enum.Material.SmoothPlastic, 1)
		a.CanCollide = false
		a.CanQuery = false
		light(a, STORM, 0.8, 34)
	end, fs.Y)
	noCollide(spurLightAnchor)
	landmarks += 2
	props += 8

	-- =====================================================================================================
	-- 7. The arrival: the dolmen bell-gate spanning the trail onto the moor (its capstone and bells high over
	--    the walk), cairns with copper forked-bolt capstones either side, dry-stone walls running off across the
	--    moor from the gate, copper grounding stakes along them.
	-- =====================================================================================================
	ctx.group("RampArch", function()
		-- A gate that spans the walkway on purpose (walkway and camp clearance leave a RampArch alone).
		local cf = CFrame.new(0, P.Basin.Y, 150)
		if ctx.has("DolmenBellGate") then
			ctx.kitAt("DolmenBellGate", cf * CFrame.new(0, -0.4, 0), 1.45, KAIRN)
		else
			fallbackDolmen(cf, 1.45)
		end
	end)
	for _, sx in { -1, 1 } do
		local cairn = piece("GateCairn", sx * 38, 150, sx * 25, "TrailCairnTall", 1.3, KAIRN, function(cf) fallbackCairn(cf, 1.3) end, P.Basin.Y)
		light(glowOf(cairn), STORM, 0.6, 18)
	end
	landmarks += 2
	props += 3
	-- Field walls: along the moor's south edge either side of the gate, and along its north edge between the
	-- trails up to the contours. Each segment is kept only where its whole length is clear of the walkways.
	local walls = 0
	local function wallRun(x0: number, x1: number, z: number)
		local seg = 25
		local n = math.floor(math.abs(x1 - x0) / seg)
		for k = 0, n - 1 do
			local cx = x0 + (x1 - x0) * (k + 0.5) / n
			if ctx.footprintClear(cx, z, seg / 2 + 1, 2.5) then
				local _, onDeck = surfaceAt(cx, z)
				piece("FieldWall", cx, z, (k % 2) * 180 + (k * 7) % 5 - 2, "DryStoneWall", 1, KAIRN, function(cf) fallbackWall(cf, 1) end, if onDeck then nil else lowestGround(cx, z, 3), not onDeck)
				walls += 1
				if k % 2 == 0 then
					-- A copper grounding stake at the segment's end, its tip ticking violet.
					piece("GroundingStake", cx + seg / 2 + 1.5, z, 0, nil, 1, nil, function(cf)
						boxAt("GroundingStakeCopper", V(0.5, 6, 0.5), cf * CFrame.new(0, 3, 0), COPPER, Enum.Material.Metal)
						boxAt("GroundingStakeVerdigris", V(0.9, 0.6, 0.9), cf * CFrame.new(0, 6.2, 0), VERDIGRIS, Enum.Material.Metal)
						local tip = boxAt("GroundingStakeGlowSeam", V(0.3, 0.8, 0.3), cf * CFrame.new(0, 6.9, 0), STORM, Enum.Material.Neon)
						tip.CanCollide = false
					end)
				end
			end
		end
	end
	wallRun(-200, -50, 186)
	wallRun(50, 200, 186)
	wallRun(-210, -110, 80)
	wallRun(110, 210, 80)
	props += walls

	-- =====================================================================================================
	-- 8. The West Wind-Crag's storm-charged urn shrine: a great copper-banded storm urn between two rune stones,
	--    a cairn behind, the urn's mouth glowing.
	-- =====================================================================================================
	local wc = P.WestCrag
	local urn = piece("UrnShrine", -101, -116, 30, "StoneUrn", 1.7, tinted(KAIRN, { ACCENT = { Color = COPPER, Material = Enum.Material.Metal } }), function(cf)
		ctx.cyl("StormUrnBody", (cf * CFrame.new(0, 3.5, 0)).Position, 3, 7, SLATE, Enum.Material.Slate)
		ctx.cyl("StormUrnBand", (cf * CFrame.new(0, 5, 0)).Position, 3.2, 0.8, COPPER, Enum.Material.Metal)
	end, wc.Y)
	if urn then
		ctx.group("UrnGlow", function()
			local mouth = ctx.block("StormUrnGlowSeam", V(3.2, 0.4, 3.2), V(-101, wc.Y + 7.4, -116), STORM, Enum.Material.Neon)
			mouth.CanCollide = false
			light(mouth, STORM, 0.9, 26)
		end)
	end
	piece("ShrineStone", -108, -107, 40, "RuneStandingStone", 0.8, KAIRN, function(cf) fallbackRuneStone(cf, 0.8) end, wc.Y)
	piece("ShrineStone", -93, -123, -50, "RuneStandingStone", 0.8, KAIRN, function(cf) fallbackRuneStone(cf, 0.8) end, wc.Y)
	piece("ShrineCairn", -108, -122, 0, "TrailCairnTall", 0.9, KAIRN, function(cf) fallbackCairn(cf, 0.9) end, wc.Y)
	landmarks += 1
	props += 5

	-- =====================================================================================================
	-- 9. The Stormgrass Crown: the great summit totem on the shelf behind the summit, cairns at the summit's
	--    corners, a prayer-flag line along its west edge, cairns at the head of the slate stair.
	-- =====================================================================================================
	local apex = P.Apex
	local summit = piece("SummitTotem", 0, -260, 0, "ForkedBoltTotem", 1.3, KAIRN, function(cf) fallbackTotem(cf, 1.3) end, apex.Y - 2)
	light(glowOf(summit), STORM, 1.4, 54)
	emitter("SummitStaticSparks", V(0, apex.Y + 50, -260), STORM, 0.5, 6, 3, 1.2, 180, true)
	for _, corner in { { -52, -242 }, { 52, -242 }, { -56, -184 }, { 56, -184 } } do
		piece("SummitCairn", corner[1], corner[2], corner[1] * 0.7, "TrailCairnTall", 1.1, KAIRN, function(cf) fallbackCairn(cf, 1.1) end, apex.Y)
	end
	piece("SummitFlags", -56, -206, 90, "PrayerFlagLine", 0.7, FLAG_TINT, function(cf) fallbackFlags(cf, 0.7) end, apex.Y)
	piece("SummitFlags", 56, -206, 90, "PrayerFlagLine", 0.7, FLAG_TINT, function(cf) fallbackFlags(cf, 0.7) end, apex.Y)
	landmarks += 1
	props += 7

	-- =====================================================================================================
	-- 10. The far layer: forked-bolt totems on the ridge tops round the room, and prayer flags on the passes.
	-- =====================================================================================================
	if field then
		for k, spot in { { -236, -150 }, { 238, -40 }, { -238, 120 }, { 236, 190 }, { -150, -252 }, { 160, -250 } } do
			local x, z = spot[1], spot[2]
			piece("RidgeTotem", x, z, k * 53, "ForkedBoltTotem", 0.75, KAIRN, function(cf) fallbackTotem(cf, 0.75) end, lowestGround(x, z, 4), true)
		end
		landmarks += 1
		props += 6
	end

	-- =====================================================================================================
	-- 11. Wind-bent pines: groves on the moor's flanks, the outer slopes and round the spurs, every one leaning
	--     south-east down the gale.
	-- =====================================================================================================
	local rng = Random.new(26 * 7919)
	local taken: { { number } } = {}
	for _, lm in ThunderHighlands.Floor26Landmarks do
		table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 3 })
	end
	local function campFree(x: number, z: number, r: number): boolean
		for _, camp in layout.Camps do
			if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (36 + r) ^ 2 then
				return false
			end
		end
		return true
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
	local groves = { { -224, 150 }, { 224, 140 }, { -228, 20 }, { 228, -110 }, { -130, -190 }, { 120, -190 }, { -60, 196 }, { 70, 200 },
		{ -236, -60 }, { 90, -10 }, { -120, 196 }, { 140, 196 }, { 232, 40 }, { -100, -40 }, { 60, -50 }, { -200, -200 } }
	for _, grove in groves do
		for _ = 1, 6 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 18)
			local x, z = grove[1] + math.cos(a) * r, grove[2] + math.sin(a) * r
			-- The canopy streams 15 studs down-wind of the trunk: keep the whole lean clear of the walkways.
			local cx, cz = x + 7, z + 7
			if math.abs(x) < w / 2 - 10 and math.abs(z) < d / 2 - 10 and spotFree(cx, cz, 9) and (not field or field.Kind(x, z) ~= "POOL") then
				table.insert(taken, { cx, cz, 9 })
				local s = rng:NextNumber(0.7, 1.15)
				piece("WindBentPine", x, z, DOWNWIND_YAW + rng:NextNumber(-9, 9), "WindBentPine", s, KAIRN, function(cf) fallbackPine(cf, s) end)
				pines += 1
			end
		end
	end
	props += pines

	-- =====================================================================================================
	-- 12. Moorland clutter (every terrace a vignette, both ends of every link dressed) and ground cover.
	-- =====================================================================================================
	type ClutterKind = { Name: string, Kit: string?, Scale: number, Tint: any?, Fallback: ((cf: CFrame) -> ())?, R: number }
	local kinds: { ClutterKind } = {
		{ Name = "Cairn", Kit = "Cairn", Scale = 0.9, Tint = KAIRN, Fallback = function(cf) fallbackCairn(cf, 0.5) end, R = 3 },
		{ Name = "Boulders", Kit = "BoulderCluster", Scale = 0.7, Tint = KAIRN, Fallback = function(cf)
			lump("MoorBoulder", (cf * CFrame.new(0, 1, 0)).Position, V(5, 3, 4), SLATE, Enum.Material.Slate)
		end, R = 3.6 },
		{ Name = "Sheep", Kit = "HighlandSheep", Scale = 1, Tint = SHEEP_TINT, Fallback = function(cf) fallbackSheep(cf, 1) end, R = 2.6 },
		{ Name = "PeatStack", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			for j = 0, 2 do
				boxAt("PeatTurf", V(3.2, 0.9, 1.4), cf * CFrame.new(0, 0.45 + j * 0.9, (j % 2) * 0.3), PEAT, Enum.Material.Ground)
			end
		end, R = 2.4 },
		{ Name = "WoolBale", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			ctx.cyl("WoolBale", (cf * CFrame.new(0, 1.2, 0)).Position, 1.2, 2.2, WOOL, Enum.Material.Fabric)
		end, R = 2 },
		{ Name = "Hurdle", Kit = "RamHurdleFence", Scale = 0.7, Tint = KAIRN, Fallback = function(cf) fallbackHurdle(cf, 0.7) end, R = 4.6 },
		{ Name = "GroundingStake", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			boxAt("GroundingStakeCopper", V(0.5, 5, 0.5), cf * CFrame.new(0, 2.5, 0), COPPER, Enum.Material.Metal)
			boxAt("GroundingStakeVerdigris", V(0.9, 0.5, 0.9), cf * CFrame.new(0, 5.2, 0), VERDIGRIS, Enum.Material.Metal)
		end, R = 1.4 },
		{ Name = "SmallCairn", Kit = "TrailCairnTall", Scale = 0.55, Tint = KAIRN, Fallback = function(cf) fallbackCairn(cf, 0.55) end, R = 1.8 },
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
				if kind.Name ~= "Hurdle" then noCollide(m) end
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
	for _ = 1, 48 do
		props += vignette(rng:NextNumber(-w / 2 + 30, w / 2 - 30), rng:NextNumber(-d / 2 + 40, d / 2 - 60), 14, 3)
	end
	-- Ground cover: stormgrass and heather tufts combed down-wind, with loose moor stones (cheap, never solid).
	for _ = 1, 1100 do
		local x, z = rng:NextNumber(-w / 2 + 16, w / 2 - 16), rng:NextNumber(-d / 2 + 16, d / 2 - 16)
		local _, onDeck = surfaceAt(x, z)
		local r = 1.5
		if not onDeck and spotFree(x, z, r) and (not field or (field.Slope(x, z) < 0.8 and field.Kind(x, z) ~= "POOL")) then
			table.insert(taken, { x, z, r })
			ctx.reserve(x, z, r)
			local stone = rng:NextNumber() < 0.2
			local s = rng:NextNumber(0.8, 1.5)
			local m = if stone
				then piece("GroundCover", x, z, rng:NextNumber(0, 360), "BoulderCluster", rng:NextNumber(0.22, 0.4), KAIRN, function(cf)
					lump("MoorStone", (cf * CFrame.new(0, 0.3, 0)).Position, V(2.2, 0.9, 1.8), SLATE, Enum.Material.Slate)
				end)
				else piece("GroundCover", x, z, DOWNWIND_YAW + rng:NextNumber(-12, 12), "StormgrassTuft", s, KAIRN, function(cf) fallbackTuft(cf, s) end)
			noCollide(m)
			cover += 1
		end
	end

	ctx.setAttribute("Floor26Landmarks", landmarks)
	ctx.setAttribute("Floor26Props", props)
	ctx.setAttribute("Floor26GroundCover", cover)
	ctx.setAttribute("Floor26Pines", pines)
end

return table.freeze(ThunderHighlands)
