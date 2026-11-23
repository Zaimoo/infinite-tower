--!strict
-- Floor 28, Skybridge Cliffs (Thunder Highlands; docs/prompts/thunder-highlands-floor-layouts-prompt.md, guide
-- image reference/Thunder Highlands 28.jpg): granite needles rising sheer out of a sea of storm cloud, joined by
-- the Kairnfolk's rope-and-copper suspension skybridges (built by TowerRoomBuilder's SKYBRIDGE masonry).
-- TowerBiomeAssets calls Build(ctx) for layout.Authored == "thunder:3" with its own builders; the shared helpers,
-- palette and tints come from ThunderHighlands.
--
-- On the summit, two copper-banded crown towers lean their heads together with lightning arcing in the gap.
-- The abyss is a sculpted cloud sea (cloud-bank meshes, drifting mist, violet underglow from invisible
-- anchors; never flat boxes), with freestanding sea-stack spires rising out of it, two of them snapped off.
-- On the needles: cable capstans at the two pylons, the supply windlass on the ledge, the Storm Roc's talon
-- nest and shed feathers on the Gale Roost, a fulgurite spire on the Fulgurite Needle, an anemometer mast on
-- the Sky-Spire, squall-horn perches, a snapped skybridge stub off the East Sea-Stack, copper grounding cables
-- draped down the needle faces and chains hanging under the spans, prayer pennants and storm lanterns at the
-- bridgeheads, thunder-glass waystones, bonsai pines on the rims and stormgrass: three skyline layers.
local ThunderHighlands = require(script.Parent.ThunderHighlands)

local ThunderFloor28 = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local C = ThunderHighlands.Palette
local Tints = ThunderHighlands.Tints
local KAIRN = Tints.KAIRN
local CLOUD = rgb(204, 206, 220)
local CLOUD_DEEP = rgb(164, 166, 188)
local UNDERGLOW = rgb(196, 168, 255)
local CLOUD_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = CLOUD, Material = Enum.Material.SmoothPlastic } })
local CLOUD_DEEP_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = CLOUD_DEEP, Material = Enum.Material.SmoothPlastic } })
local FEATHER_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = rgb(78, 80, 92), Material = Enum.Material.Fabric },
	TRIM = { Color = rgb(206, 200, 186), Material = Enum.Material.SmoothPlastic },
})
local NEST_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = rgb(78, 80, 92), Material = Enum.Material.Fabric },
	TRIM = { Color = rgb(206, 200, 186), Material = Enum.Material.SmoothPlastic },
})
local FULGURITE_TINT = ThunderHighlands.Tinted(KAIRN, {
	CRYSTAL = { Color = rgb(170, 140, 236), Material = Enum.Material.Glass, Transparency = 0.2 },
})
local CROWN_TINT = Tints.GRANITE
local HOIST_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = rgb(186, 172, 148), Material = Enum.Material.Fabric } })

-- The twin crown towers stand on the shelf behind the Crown, their half-arches reaching toward each other.
local CROWN_SCALE = 2.0
local CROWN_Z = -333
local CROWN_WEST_X, CROWN_EAST_X = -64, 40
-- The arc node at each arch tip (template local X 22.6, Y 63.4), and the template's height.
local ARC_TIP_X, ARC_TIP_Y, CROWN_TOP = 22.6, 63.4, 72.5
-- The snapped skybridge's deck height in its template (it stands on its dangling cables).
local STUB_DECK = 18.1
-- The grounding chain's anchor plate height in its template (it stands on its weight).
local CHAIN_TOP = 42.3

-- Freestanding sea-stack spires out of the cloud sea: x, z, scale, snapped (height factor).
local STACKS = {
	{ Id = "SeaStackSouthWest", X = -60, Z = 95, S = 1.2, H = 1 },
	{ Id = "SeaStackSouthEast", X = 62, Z = 100, S = 1.0, H = 0.5 },
	{ Id = "SeaStackEast", X = 88, Z = -112, S = 1.4, H = 1 },
	{ Id = "SeaStackWest", X = -82, Z = -128, S = 1.1, H = 0.55 },
	{ Id = "SeaStackFarEast", X = 258, Z = -195, S = 1.0, H = 1 },
	{ Id = "SeaStackFarWest", X = -258, Z = -170, S = 1.2, H = 1 },
	{ Id = "SeaStackNorth", X = -62, Z = -165, S = 0.9, H = 1 },
}

-- Every fixed Floor 28 landmark's footprint, for the specs (no landmark on a walkway or in a camp) and the census.
-- Y is its foot (nil: the abyss floor); Top its height above that.
ThunderFloor28.Landmarks = (function()
	local list = {
		{ Id = "CrownTowerWest", X = CROWN_WEST_X + 15.9 * CROWN_SCALE, Z = CROWN_Z, Y = 40, HalfX = 15.45 * CROWN_SCALE, HalfZ = 7 * CROWN_SCALE, Top = CROWN_TOP * CROWN_SCALE },
		{ Id = "CrownTowerEast", X = CROWN_EAST_X - 15.9 * CROWN_SCALE, Z = CROWN_Z, Y = 40, HalfX = 15.45 * CROWN_SCALE, HalfZ = 7 * CROWN_SCALE, Top = CROWN_TOP * CROWN_SCALE },
		{ Id = "FulguriteSpire", X = 277, Z = -100, Y = 34, HalfX = 8.5, HalfZ = 7.9, Top = 49.7 },
		{ Id = "TalonNest", X = -277, Z = -78, Y = 14, HalfX = 9, HalfZ = 9, Top = 4.2 },
		{ Id = "CapstanWest", X = -198, Z = -200, Y = 28, HalfX = 7.7, HalfZ = 5.6, Top = 8.4 },
		{ Id = "CapstanEast", X = 195, Z = -218, Y = 30, HalfX = 7.7, HalfZ = 5.6, Top = 8.4 },
		{ Id = "SupplyHoist", X = -170, Z = 156, Y = 0, HalfX = 5.4, HalfZ = 9.6, Top = 16.9 },
		{ Id = "AnemometerMast", X = 31, Z = -48, Y = 20, HalfX = 4.2, HalfZ = 3.9, Top = 22.7 },
		{ Id = "SquallPerchWest", X = -117.5, Z = -74, Y = 16, HalfX = 4.8, HalfZ = 4.8, Top = 20.2 },
		{ Id = "SquallPerchEast", X = 134, Z = -60, Y = 24, HalfX = 4.8, HalfZ = 4.8, Top = 20.2 },
		{ Id = "SnappedSkybridge", X = 218, Z = -7, Y = 12 - STUB_DECK, HalfX = 8.6, HalfZ = 10.1, Top = 34.9 },
	}
	for _, st in STACKS do
		table.insert(list, { Id = st.Id, X = st.X, Z = st.Z, HalfX = 9.8 * st.S, HalfZ = 9.6 * st.S, Top = 73.9 * st.S * st.H, Stack = true })
	end
	return table.freeze(list)
end)() :: { any }

function ThunderFloor28.Build(ctx: any)
	local H = ThunderHighlands.Helpers(ctx)
	local origin: Vector3, layout, field, bottom: number, w: number, d: number, P = H.origin, H.layout, H.field, H.bottom, H.w, H.d, H.P
	local surfaceAt, lowestGround, boxAt, rod, lump, light = H.surfaceAt, H.lowestGround, H.boxAt, H.rod, H.lump, H.light
	local noCollide, emitter, piece, glowOf = H.noCollide, H.emitter, H.piece, H.glowOf
	local fallbackCairn, fallbackPine, fallbackTuft, fallbackFlags = H.fallbackCairn, H.fallbackPine, H.fallbackTuft, H.fallbackFlags
	local fallbackRuneStone, fallbackCrystals = H.fallbackRuneStone, H.fallbackCrystals
	local landmarks, props, cover = 0, 0, 0
	local abyss = if field then field.Bottom else bottom - 4

	-- ===================================================================================================
	-- Native fallbacks for the Floor 28 kit (until it is imported). cf: the piece's origin, front +Z.
	-- ===================================================================================================
	local function fallbackCrown(cf: CFrame, s: number)
		for k, stage in { { 11, 0, 22 }, { 9.6, 22, 22 }, { 8.4, 44, 16 } } do
			boxAt("CrownTowerShaft", V(stage[1], stage[3], stage[1]) * s, cf * CFrame.new(0, (stage[2] + stage[3] / 2) * s, 0), if k % 2 == 0 then C.SLATE_DARK else C.GRANITE, Enum.Material.Slate)
			boxAt("CrownTowerCopperBand", V(stage[1] + 0.5, 1.6, stage[1] + 0.5) * s, cf * CFrame.new(0, (stage[2] + stage[3] * 0.72) * s, 0), C.COPPER, Enum.Material.Metal)
		end
		boxAt("CrownTowerCorbel", V(10.2, 1.4, 10.2) * s, cf * CFrame.new(0, 60.7 * s, 0), C.SLATE, Enum.Material.Slate)
		for k = 0, 5 do
			local f = k / 5
			local x = 4.4 + 16 * f
			local y = 54 + 9 * math.sin(f * math.pi * 0.62)
			boxAt("CrownArchVoussoir", V(3.6, 3.2, 3.4) * s, cf * CFrame.new(x * s, y * s, 0) * CFrame.Angles(0, 0, math.rad(30 - f * 40)), C.SLATE, Enum.Material.Slate)
		end
		boxAt("CrownArchGlowSeam", V(1.6, 1.6, 1.6) * s, cf * CFrame.new(ARC_TIP_X * s, ARC_TIP_Y * s, 0), C.STORM, Enum.Material.Neon).CanCollide = false
	end
	local function fallbackStack(cf: CFrame, s: number, hf: number)
		local hTotal = 66 * hf
		for k, col in { { 0, 0, 1, 6.2 }, { 4.6, 1.4, 0.76, 4.8 }, { -4.2, 1.8, 0.85, 5 }, { 1.2, -4.4, 0.66, 4.6 } } do
			local h = hTotal * col[3]
			boxAt("StackColumn", V(col[4], h, col[4] * 0.92) * s, cf * CFrame.new(col[1] * s, h / 2 * s, col[2] * s) * CFrame.Angles(0, k * 0.4, 0), if k % 2 == 0 then C.SLATE_DARK else C.GRANITE, Enum.Material.Slate)
		end
	end
	local function fallbackCloud(cf: CFrame, sx: number, sy: number, color: Color3)
		for k, b in { { 0, 0, 22, 7 }, { -16, 4, 16, 5.5 }, { 15, -3, 17, 6 }, { -6, -10, 14, 5 }, { 9, 10, 13, 4.5 } } do
			local at = (cf * CFrame.new(b[1] * sx, b[4] * 0.45 * sy, b[2] * sx)).Position
			local cloud = lump("CloudBankMist", at, V(b[3] * 1.4 * sx, b[4] * 1.8 * sy, b[3] * sx), if k % 2 == 0 then color else CLOUD_DEEP, Enum.Material.SmoothPlastic)
			cloud.CanCollide = false
			cloud.CanQuery = false
		end
	end
	local function fallbackCapstan(cf: CFrame)
		local drum = boxAt("CapstanDrum", V(7.4, 4.4, 4.4), cf * CFrame.new(0, 5.2, 0), C.TIMBER, Enum.Material.Wood)
		drum.Shape = Enum.PartType.Cylinder
		for _, sx in { -1, 1 } do
			boxAt("CapstanCheek", V(1, 6.6, 1.4), cf * CFrame.new(sx * 4.4, 3.8, 0), C.TIMBER_DARK, Enum.Material.Wood)
			boxAt("CapstanCopperBand", V(0.4, 4.7, 4.7), cf * CFrame.new(sx * 3.7, 5.2, 0), C.VERDIGRIS, Enum.Material.Metal)
		end
	end
	local function fallbackHoist(cf: CFrame)
		for _, sx in { -1, 1 } do
			rod("HoistJibLeg", (cf * CFrame.new(sx * 4.6, 0, -2)).Position, (cf * CFrame.new(sx * 0.6, 16, 7)).Position, 0.4, C.TIMBER, Enum.Material.Wood)
		end
		rod("HoistRope", (cf * CFrame.new(0, 15, 7)).Position, (cf * CFrame.new(0, 4.6, 8)).Position, 0.1, C.SLATE_DARK, Enum.Material.Fabric).CanCollide = false
		boxAt("HoistCrate", V(3.2, 3, 3.2), cf * CFrame.new(0, 3, 8), C.TIMBER, Enum.Material.Wood)
	end
	local function fallbackFeather(cf: CFrame, s: number)
		boxAt("RocFeatherVane", V(16, 0.2, 5) * s, cf * CFrame.new(0, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(4)), rgb(78, 80, 92), Enum.Material.Fabric).CanCollide = false
		boxAt("RocFeatherQuill", V(16, 0.5, 0.5) * s, cf * CFrame.new(0, 0.8 * s, 0), rgb(206, 200, 186), Enum.Material.SmoothPlastic).CanCollide = false
	end
	local function fallbackNest(cf: CFrame)
		for k = 0, 11 do
			local a = k * math.pi / 6
			local p0 = cf * CFrame.new(math.cos(a) * 9.5, 1.6 + (k % 3) * 0.8, math.sin(a) * 9.5)
			local p1 = cf * CFrame.new(math.cos(a + 0.9) * 10.5, 2 + (k % 2), math.sin(a + 0.9) * 10.5)
			rod("NestLog", p0.Position, p1.Position, 0.6, C.TIMBER_DARK, Enum.Material.Wood)
		end
	end
	local function fallbackFulgurite(cf: CFrame, s: number)
		for k, shoot in { { 0, 0, 40, 1.9 }, { 3, 1.2, 26, 1.3 }, { -2.6, -1, 30, 1.4 } } do
			boxAt("FulguriteShoot", V(shoot[4] * 1.6, shoot[3], shoot[4] * 1.6) * s, cf * CFrame.new(shoot[1] * s, shoot[3] / 2 * s, shoot[2] * s) * CFrame.Angles(0, k, 0), rgb(170, 140, 236), Enum.Material.Glass, 0.2)
			boxAt("FulguriteGlowSeam", V(0.5, shoot[3] * 0.8, 0.5) * s, cf * CFrame.new(shoot[1] * s, shoot[3] * 0.45 * s, shoot[2] * s), C.STORM, Enum.Material.Neon).CanCollide = false
		end
	end
	local function fallbackAnemometer(cf: CFrame)
		boxAt("AnemometerMastPole", V(0.6, 22, 0.6), cf * CFrame.new(0, 11, 0), C.COPPER, Enum.Material.Metal)
		boxAt("AnemometerArms", V(6.4, 0.3, 0.3), cf * CFrame.new(0, 22, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		boxAt("AnemometerArms", V(0.3, 0.3, 6.4), cf * CFrame.new(0, 22, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackPerch(cf: CFrame)
		boxAt("PerchPole", V(1, 20, 1), cf * CFrame.new(0, 10, 0), C.TIMBER, Enum.Material.Wood)
		boxAt("PerchBar", V(8, 0.6, 0.6), cf * CFrame.new(0, 19, 0), C.TIMBER, Enum.Material.Wood).CanCollide = false
		for _, sx in { -1, 1 } do
			boxAt("PerchHorn", V(2.4, 2.4, 4), cf * CFrame.new(sx * 2, 14, 2) * CFrame.Angles(math.rad(20), sx * math.rad(30), 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		end
	end
	local function fallbackStub(cf: CFrame)
		local deck = cf * CFrame.new(0, STUB_DECK, 0)
		for _, sx in { -1, 1 } do
			boxAt("StubPylon", V(3.6, 16, 3.6), deck * CFrame.new(sx * 6, 8, 0), C.SLATE, Enum.Material.Slate)
		end
		for k = 0, 6 do
			boxAt("StubPlank", V(if k < 4 then 8 else 4 + (k % 2) * 2, 0.2, 1.2), deck * CFrame.new(if k < 4 then 0 else -2, 0.1, 1 + k * 1.5), C.TIMBER, Enum.Material.Wood)
		end
	end
	local function fallbackWaystone(cf: CFrame)
		boxAt("WaystonePillar", V(2.6, 7.6, 2.2), cf * CFrame.new(0, 3.8, 0), C.GRANITE, Enum.Material.Slate)
		boxAt("WaystoneLensGlowSeam", V(1.2, 1.2, 0.3), cf * CFrame.new(0, 5, 1.2), C.STORM, Enum.Material.Neon).CanCollide = false
	end
	local function fallbackChain(cf: CFrame, sy: number)
		rod("GroundingChainCopper", (cf * CFrame.new(0, CHAIN_TOP * sy, 0)).Position, (cf * CFrame.new(0.4, 0.6, 0)).Position, 0.3, C.COPPER, Enum.Material.Metal)
	end

	for _, lm in ThunderFloor28.Landmarks do
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
	-- The lowest walking surface within r of (x, z) (terraces, skybridges and the abyss return ramps), so a
	-- cloud bank or a hanging piece keeps under every walkway near it.
	local function lowestWalkNear(x: number, z: number, r: number): number
		local low = math.huge
		local function along(link: any)
			local dx, dz = link.BX - link.AX, link.BZ - link.AZ
			local lengthSq = math.max(dx * dx + dz * dz, 1e-6)
			local t = math.clamp(((x - link.AX) * dx + (z - link.AZ) * dz) / lengthSq, 0, 1)
			local px, pz = link.AX + dx * t, link.AZ + dz * t
			local reach = r + (link.Width or 28) / 2 + 6
			if (px - x) ^ 2 + (pz - z) ^ 2 < reach * reach then
				local span = reach / math.sqrt(lengthSq)
				for _, tt in { math.clamp(t - span, 0, 1), math.clamp(t + span, 0, 1) } do
					low = math.min(low, link.AY + (link.BY - link.AY) * tt)
				end
			end
		end
		for _, link in layout.Links do
			along(link)
		end
		for _, link in layout.ReturnLinks or {} do
			along(link)
		end
		for id, p in P do
			if math.abs(x - p.X) < p.Width / 2 + r + 6 and math.abs(z - p.Z) < p.Depth / 2 + r + 6 then
				low = math.min(low, p.Y)
			end
		end
		return low
	end
	-- Open abyss floor at (x, z): no needle, ledge or mountain under it.
	local function openAbyss(x: number, z: number): boolean
		return field == nil or field.Height(x, z) < abyss + 3
	end

	-- ===================================================================================================
	-- 1. The Skybridge Crown: the twin crown towers behind it, their half-arches reaching toward each other
	--    with lightning arcing across the gap between their copper saddles.
	-- ===================================================================================================
	local apex = P.Apex
	for _, tower in { { "CrownTowerWest", CROWN_WEST_X, 0 }, { "CrownTowerEast", CROWN_EAST_X, 180 } } do
		local x, yaw = tower[2], tower[3]
		local made = piece(tower[1], x, CROWN_Z, yaw, "CrownAnchorTower", CROWN_SCALE, CROWN_TINT, function(cf) fallbackCrown(cf, CROWN_SCALE) end, apex.Y - 1.2, true)
		light(glowOf(made), C.STORM, 1.2, 40)
	end
	local westTip = V(CROWN_WEST_X + ARC_TIP_X * CROWN_SCALE, apex.Y - 1.2 + ARC_TIP_Y * CROWN_SCALE, CROWN_Z)
	local eastTip = V(CROWN_EAST_X - ARC_TIP_X * CROWN_SCALE, apex.Y - 1.2 + ARC_TIP_Y * CROWN_SCALE, CROWN_Z)
	ctx.group("CrownLightningArc", function()
		ctx.tag("OnTerrain", true)
		local kinks = { 0, 1.6, -1.2, 2.2, -0.8, 0 }
		local prev = westTip
		for i = 1, #kinks - 1 do
			local f = i / (#kinks - 1)
			local pt = westTip:Lerp(eastTip, f) + V(0, kinks[i + 1] * 1.4, kinks[i + 1] * 0.6)
			local seg = rod("CrownArcGlowSeam", prev, pt, 0.35, rgb(232, 220, 255), Enum.Material.Neon)
			seg.CanCollide = false
			seg.CanQuery = false
			prev = pt
		end
		local node = ctx.block("CrownArcNodeGlowSeam", V(1, 1, 1), (westTip + eastTip) / 2, C.STORM, Enum.Material.Neon, nil, 1)
		node.CanCollide = false
		node.CanQuery = false
		light(node, UNDERGLOW, 2.2, 80)
	end)
	emitter("CrownArcSparks", (westTip + eastTip) / 2, C.STORM, 0.7, 10, 4, 1.1, 180, true)
	-- Cairns and pennants on the Crown's back corners, clear of the portals.
	for _, corner in { { apex.X - 58, -306 }, { apex.X + 58, -306 } } do
		piece("CrownCairn", corner[1], corner[2], corner[1] * 0.7, "TrailCairnTall", 1.1, KAIRN, function(cf) fallbackCairn(cf, 1.1) end, apex.Y)
	end
	landmarks += 3
	props += 5

	-- ===================================================================================================
	-- 2. The cloud sea: sculpted cloud banks drifting over the abyss floor (always under every walkway near
	--    them), slow mist and violet underglow from invisible anchors. No flat boxes.
	-- ===================================================================================================
	local rng = Random.new(28 * 7919)
	local clouds = 0
	local function cloudBank(x: number, z: number, base: number, sx: number, sy: number, deep: boolean)
		ctx.group("CloudBank", function()
			ctx.tag("OnTerrain", true)
			local cf = CFrame.new(x, base, z) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0)
			if ctx.has("CloudBankLayer") then
				noCollide(ctx.kitAt("CloudBankLayer", cf, V(sx, sy, sx), if deep then CLOUD_DEEP_TINT else CLOUD_TINT))
			else
				fallbackCloud(cf, sx, sy, if deep then CLOUD_DEEP else CLOUD)
			end
		end)
		clouds += 1
	end
	-- The low sea: banks blanketing the abyss floor, their tops always 4+ studs under the walkways above.
	-- Where the walkways are high (the north gorge), a second layer of billows heaps up between the needles.
	for row, gz in { -330, -296, -262, -228, -194, -160, -126, -92, -58, -24, 10, 44, 78, 112, 140 } do
		for gx = -300, 300, 40 do
			local x = gx + rng:NextNumber(-9, 9) + (if row % 2 == 0 then 20 else 0)
			local z = gz + rng:NextNumber(-8, 8)
			local sx = rng:NextNumber(0.95, 1.45)
			if math.abs(x) < w / 2 - 16 and math.abs(z) < d / 2 - 16 and openAbyss(x, z) then
				local ceiling = lowestWalkNear(x, z, 16 * sx) - 4
				local base = abyss - 2.2
				local sy = math.clamp((math.min(ceiling, abyss + 9) - base) / 11.7, 0, 0.95)
				if sy >= 0.3 then
					cloudBank(x, z, base, sx, sy, rng:NextNumber() < 0.3)
				end
				local high = math.min(ceiling, abyss + 30)
				if high > abyss + 16 and rng:NextNumber() < 0.7 then
					local sx2 = sx * rng:NextNumber(0.7, 0.95)
					local sy2 = math.min(0.9, (high - (abyss + 4)) / 11.7)
					cloudBank(x + rng:NextNumber(-10, 10), z + rng:NextNumber(-8, 8), high - 11.7 * sy2, sx2, sy2, false)
				end
			end
		end
	end
	props += clouds
	ctx.setAttribute("Floor28CloudBanks", clouds)
	-- Violet underglow from invisible anchors low in the abyss, and slow mist drifting over the cloud tops.
	for k, spot in { { -150, 110 }, { 150, 110 }, { -90, -40 }, { 90, -40 }, { -40, -200 }, { 230, -150 } } do
		ctx.group("AbyssUnderglow", function()
			ctx.tag("OnTerrain", true)
			local anchor = ctx.block("AbyssUnderglowMistAnchor", V(1, 1, 1), V(spot[1], abyss + 2, spot[2]), UNDERGLOW, Enum.Material.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			anchor.CanQuery = false
			light(anchor, UNDERGLOW, if k <= 2 then 0.9 else 0.7, 70)
		end)
	end
	for _, spot in { { -120, 60 }, { 120, 60 }, { 0, -110 }, { -200, -120 } } do
		emitter("AbyssMist", V(spot[1], abyss + 6, spot[2]), CLOUD, 26, 2, 2, 14, 40, false)
	end
	landmarks += 1

	-- ===================================================================================================
	-- 3. Sea-stack spires out of the cloud sea (two snapped off mid-height, their broken cables trailing),
	--    and on the far walls a range of needle peaks with a distant hanging bridge between two of them.
	-- ===================================================================================================
	for _, st in STACKS do
		local y = lowestGround(st.X, st.Z, 6) - 2
		ctx.group("SeaStackSpire", function()
			ctx.tag("OnTerrain", true)
			local cf = CFrame.new(st.X, y, st.Z) * CFrame.Angles(0, math.rad(st.X * 1.7), 0)
			if ctx.has("SeaStackSpire") then
				ctx.kitAt("SeaStackSpire", cf, V(st.S, st.S * st.H, st.S), KAIRN)
			else
				fallbackStack(cf, st.S, st.H)
			end
			if st.H < 1 then
				-- The snapped top: a broken cable from it trailing down into the clouds.
				local top = V(st.X + 2, y + 66 * st.S * st.H, st.Z)
				local prev = top
				for i = 1, 5 do
					local pt = top + V(3 + i * 1.2, -i * 7, i * 0.8)
					local strand = rod("SnappedCableCopper", prev, pt, 0.3, C.COPPER, Enum.Material.Metal)
					strand.CanCollide = false
					strand.CanQuery = false
					prev = pt
				end
			end
		end)
	end
	landmarks += 1
	props += #STACKS
	if field then
		local farSpots = { { -300, -300, 1.7 }, { 300, -290, 1.9 }, { -306, 60, 1.5 }, { 306, 40, 1.6 }, { -200, -340, 1.4 }, { 210, -338, 1.5 } }
		local tops: { Vector3 } = {}
		for k, spot in farSpots do
			local x, z, s = spot[1], spot[2], spot[3]
			local y = lowestGround(x, z, 6) - 3
			piece("FarNeedle", x, z, k * 47, "SeaStackSpire", s, KAIRN, function(cf) fallbackStack(cf, s, 1) end, y, true)
			table.insert(tops, V(x, y + 60 * s, z))
		end
		-- A distant hanging bridge between the two north-west needles, far over every walkway.
		ctx.group("FarSkybridge", function()
			ctx.tag("OnTerrain", true)
			local a, b = tops[1], tops[5]
			for _, dy in { 0, -3 } do
				local prev = a + V(0, dy, 0)
				for i = 1, 8 do
					local f = i / 8
					local pt = a:Lerp(b, f) + V(0, dy - 12 * 4 * f * (1 - f), 0)
					local strand = rod("FarSkybridgeRope", prev, pt, 0.5, C.TIMBER_DARK, Enum.Material.Fabric)
					strand.CanCollide = false
					strand.CanQuery = false
					prev = pt
				end
			end
		end)
		landmarks += 1
		props += #farSpots + 1
	end

	-- ===================================================================================================
	-- 4. The needles' work: cable capstans at both pylons, the supply windlass on the Cloudbreak Ledge, the
	--    anemometer mast on the Sky-Spire, squall-horn perches on the pinion crags.
	-- ===================================================================================================
	local sw, se = P.SkyAnchorW, P.SkyAnchorE
	piece("CableWinchCapstan", -198, -200, 90, "CableWinchCapstan", 1, KAIRN, fallbackCapstan, sw.Y)
	piece("CableWinchCapstan", 195, -218, -90, "CableWinchCapstan", 1, KAIRN, fallbackCapstan, se.Y)
	piece("SupplyHoist", -170, 156, 180, "SupplyHoistWindlass", 1, HOIST_TINT, fallbackHoist, P.Basin.Y)
	piece("AnemometerMast", 31, -48, 25, "AnemometerMast", 1, KAIRN, fallbackAnemometer, P.Crossing.Y)
	piece("SquallHornPerch", -117.5, -74, -90, "SquallHornPerch", 1, Tints.FLAG, fallbackPerch, P.NeedleWest.Y)
	piece("SquallHornPerch", 134, -60, 90, "SquallHornPerch", 1, Tints.FLAG, fallbackPerch, P.NeedleEast.Y)
	landmarks += 4
	props += 6

	-- ===================================================================================================
	-- 5. The Gale Roost: the Storm Roc's talon nest (the first hint of it), shed feathers on the roost and
	--    caught on the needles, feathers drifting off it on the gale.
	-- ===================================================================================================
	piece("TalonNest", -277, -78, 20, "TalonNestPlatform", 0.7, NEST_TINT, fallbackNest, P.GaleRoost.Y)
	emitter("GaleFeathers", V(-277, P.GaleRoost.Y + 6, -78), rgb(96, 98, 110), 1.2, 1.5, 3, 8, 50, false)
	local feathers = 0
	for _, spot in { { -280, -48, 1 }, { -252, -82, 0.8 }, { -112, -100, 0.9 }, { 196, -60, 0.8 }, { -150, 230, 1.1 } } do
		local x, z, s = spot[1], spot[2], spot[3]
		if ctx.footprintClear(x, z, 8 * s, 4 * s) and campFree(x, z, 8 * s) then
			local m = piece("ShedRocFeather", x, z, x * 2.3, "ShedRocFeather", s, FEATHER_TINT, function(cf) fallbackFeather(cf, s) end)
			noCollide(m)
			feathers += 1
		end
	end
	landmarks += 1
	props += 1 + feathers

	-- ===================================================================================================
	-- 6. The Fulgurite Needle: a spire of lightning-fused glass bursting out of the cap, crackling violet.
	-- ===================================================================================================
	local fn = P.FulminiteNeedle
	local spire = piece("FulguriteSpire", 277, -100, 30, "FulguriteSpireTall", 1.2, FULGURITE_TINT, function(cf) fallbackFulgurite(cf, 1.2) end, fn.Y)
	light(glowOf(spire), C.STORM, 1.6, 50)
	emitter("FulguriteStatic", V(277, fn.Y + 30, -100), C.STORM, 0.5, 8, 3, 1, 180, true)
	-- The scar the strikes left: storm-glass spikes round its foot.
	for _, spot in { { 281, -81 }, { 266, -122 } } do
		piece("FulguriteShards", spot[1], spot[2], spot[1] * 3, "StormCrystalSpikes", 0.7, KAIRN, function(cf) fallbackCrystals(cf, 0.7) end, fn.Y)
	end
	landmarks += 1
	props += 3

	-- ===================================================================================================
	-- 7. The snapped skybridge off the East Sea-Stack's north rim: its planks end in a jagged break over the
	--    mist, cairns and a rope barrier across its root so it never reads as a way on.
	-- ===================================================================================================
	local eg = P.EastGallery
	piece("SnappedSkybridge", 218, -7, 180, "SnappedBridgeStub", 1, KAIRN, fallbackStub, eg.Y - STUB_DECK, true)
	for _, sx in { -1, 1 } do
		piece("StubBarrierCairn", 218 + sx * 5, 1, sx * 40, "TrailCairnTall", 0.7, KAIRN, function(cf) fallbackCairn(cf, 0.7) end, eg.Y)
	end
	ctx.group("StubBarrierRope", function()
		local a, b = V(213, eg.Y + 4, 1), V(223, eg.Y + 4, 1)
		local prev = a
		for i = 1, 4 do
			local pt = a:Lerp(b, i / 4) - V(0, math.sin(i / 4 * math.pi) * 0.8, 0)
			local strand = rod("StubBarrierRopeHemp", prev, pt, 0.18, C.TIMBER, Enum.Material.Fabric)
			strand.CanCollide = false
			prev = pt
		end
	end)
	landmarks += 1
	props += 4

	-- ===================================================================================================
	-- 8. The bridgeheads: a prayer-pennant line strung between each skybridge's pylon heads at its upper end,
	--    storm lanterns hung from its main cables, and a thunder-glass waystone beside each end.
	-- ===================================================================================================
	local suspended = layout.Suspended and layout.Suspended.Links or {}
	local dyes = { rgb(196, 56, 48), rgb(226, 186, 62), rgb(62, 98, 178), rgb(232, 226, 210) }
	local pennants, lanterns, waystones = 0, 0, 0
	for _, link in layout.Links do
		if not suspended[link.Id] then
			continue
		end
		local a, b = V(link.AX, link.AY, link.AZ), V(link.BX, link.BY, link.BZ)
		local flat = V(b.X - a.X, 0, b.Z - a.Z)
		local flatUnit = if flat.Magnitude > 0.01 then flat.Unit else V(0, 0, -1)
		local right = V(-flatUnit.Z, 0, flatUnit.X)
		local half = link.Width / 2
		-- The same pylon heads TowerRoomBuilder's skybridge hangs its cables from.
		local function head(endPt: Vector3, outward: Vector3, side: number): Vector3
			return endPt + right * (side * (half + 2.6)) + outward * 1.2 + V(0, 19, 0)
		end
		local top = if b.Y >= a.Y then b else a
		local outTop = if top == b then flatUnit else -flatUnit
		-- Pennants across the bridge mouth, 15+ studs over the deck.
		ctx.group("RampArch", function()
			ctx.tag("OnTerrain", true)
			local h0, h1 = head(top, outTop, -1), head(top, outTop, 1)
			local n = 10
			local prev = h0
			for i = 1, n do
				local f = i / n
				local pt = h0:Lerp(h1, f) - V(0, math.sin(f * math.pi) * 1.2, 0)
				local line = rod("PennantLine", prev, pt, 0.08, C.TIMBER_DARK, Enum.Material.Fabric)
				line.CanCollide = false
				line.CanQuery = false
				if i < n then
					local flag = boxAt("PrayerPennant", V(1.4, 1.6, 0.1), CFrame.lookAt(pt - V(0, 0.9, 0), pt - V(0, 0.9, 0) + flatUnit), dyes[i % 4 + 1], Enum.Material.Fabric)
					flag.CanCollide = false
					flag.CanQuery = false
				end
				prev = pt
			end
		end)
		pennants += 1
		-- Storm lanterns at the cables' quarter points (copper cages, violet storm-glass, no lights of their own).
		local length = (b - a).Magnitude
		if length > 40 then
			ctx.group("RampArch", function()
				ctx.tag("OnTerrain", true)
				for _, side in { -1, 1 } do
					local h0, h1 = head(a, -flatUnit, side), head(b, flatUnit, side)
					for _, f in { 0.22, 0.78 } do
						local onDeck = a:Lerp(b, f) + right * (side * (half - 0.6))
						local headLine = h0:Lerp(h1, f)
						local bow = 4 * f * (1 - f)
						local cable = V(headLine.X + (onDeck.X - headLine.X) * bow, headLine.Y - (headLine.Y - onDeck.Y - 4.4) * bow, headLine.Z + (onDeck.Z - headLine.Z) * bow)
						local hook = rod("LanternHook", cable, cable - V(0, 1.4, 0), 0.08, C.COPPER, Enum.Material.Metal)
						hook.CanCollide = false
						hook.CanQuery = false
						local cage = boxAt("StormLanternCage", V(0.9, 1.3, 0.9), CFrame.new(cable - V(0, 2.1, 0)), C.COPPER, Enum.Material.Metal)
						cage.CanCollide = false
						cage.CanQuery = false
						local glass = boxAt("StormLanternGlowSeam", V(0.6, 0.9, 0.6), CFrame.new(cable - V(0, 2.1, 0)), rgb(214, 196, 255), Enum.Material.Neon)
						glass.CanCollide = false
						glass.CanQuery = false
					end
				end
			end)
			lanterns += 4
		end
		-- A waystone beside each end, on the terrace off the landing.
		for _, e in { { a, -flatUnit }, { b, flatUnit } } do
			local endPt: Vector3, outward: Vector3 = e[1], e[2]
			-- Clear of the landing pad's lane (half-width + 3), a little in from the end.
			local placed = false
			for _, spot in { { 1, 15, 8 }, { -1, 15, 8 }, { 1, 15, 16 }, { -1, 15, 16 }, { 1, 19, 4 }, { -1, 19, 4 } } do
				if placed then break end
				local side = spot[1]
				local at = endPt + right * (side * (half + spot[2])) - outward * spot[3]
				local gy, onPlat = surfaceAt(at.X, at.Z)
				if onPlat and math.abs(gy - endPt.Y) < 0.5 and ctx.footprintClear(at.X, at.Z, 2.2, 2.2) and campFree(at.X, at.Z, 2) then
					local stone = piece("SkybridgeWaystone", at.X, at.Z, math.deg(math.atan2(flatUnit.X, flatUnit.Z)), "SkybridgeWaystone", 1, KAIRN, fallbackWaystone, gy)
					noCollide(stone)
					waystones += 1
					placed = true
				end
			end
		end
	end
	props += pennants + lanterns + waystones
	ctx.setAttribute("Floor28Pennants", pennants)
	ctx.setAttribute("Floor28Lanterns", lanterns)
	ctx.setAttribute("Floor28Waystones", waystones)
	landmarks += 2

	-- ===================================================================================================
	-- 9. Copper grounding: chains hanging under the high spans into the cloud sea, and braided copper cables
	--    bolted to the needle rims and draped down their faces.
	-- ===================================================================================================
	local chains = 0
	for _, link in layout.Links do
		if not suspended[link.Id] then
			continue
		end
		local midY = (link.AY + link.BY) / 2
		if midY >= 14 then
			local dx, dz = link.BX - link.AX, link.BZ - link.AZ
			local len = math.sqrt(dx * dx + dz * dz)
			local rx, rz = -dz / len, dx / len
			for _, f in { 0.38, 0.62 } do
				local side = if f < 0.5 then -1 else 1
				local x = link.AX + dx * f + rx * side * (link.Width / 2 - 1.4)
				local z = link.AZ + dz * f + rz * side * (link.Width / 2 - 1.4)
				local deckY = link.AY + (link.BY - link.AY) * f
				local topY = deckY - 3.2
				local sy = math.clamp((topY - (abyss + 3)) / CHAIN_TOP, 0.3, 1)
				ctx.group("CliffGroundingChain", function()
					ctx.tag("OnTerrain", true)
					local cf = CFrame.new(x, topY - CHAIN_TOP * sy, z) * CFrame.Angles(0, math.atan2(dx, dz), 0)
					if ctx.has("CliffGroundingChain") then
						noCollide(ctx.kitAt("CliffGroundingChain", cf, V(1, sy, 1), KAIRN))
					else
						fallbackChain(cf, sy)
					end
				end)
				chains += 1
			end
		end
	end
	local draped = 0
	if field then
		for id, p in P do
			if id == "Sanctuary" or id == "Basin" or (layout.Decks and layout.Decks[id]) then
				continue
			end
			for k = 0, 3 do
				local a = k * math.pi / 2 + 0.6 + p.X * 0.01
				local nx, nz = math.cos(a), math.sin(a)
				-- From the rim (just inside the edge) straight out and down the face.
				local ex = p.X + nx * (p.Width / 2 - 1)
				local ez = p.Z + nz * (p.Depth / 2 - 1)
				if ctx.footprintClear(ex, ez, 3, 3) and campFree(ex, ez, 2) then
					ctx.group("CliffGroundingChain", function()
						ctx.tag("OnTerrain", true)
						boxAt("GroundingAnchorPlate", V(2.4, 0.5, 2.4), CFrame.new(ex, p.Y + 0.1, ez), C.SLATE_DARK, Enum.Material.Metal).CanCollide = false
						local prev = V(ex, p.Y + 0.3, ez)
						for step = 1, 14 do
							local dist = step * 4
							local x, z = ex + nx * dist, ez + nz * dist
							local y = field.Height(x, z) + 1.2
							local pt = V(x, math.min(y, prev.Y - 0.5), z)
							local strand = rod("GroundingCableCopper", prev, pt, 0.32, C.COPPER, Enum.Material.Metal)
							strand.CanCollide = false
							strand.CanQuery = false
							prev = pt
							if y < abyss + 2 then
								break
							end
						end
					end)
					draped += 1
				end
			end
		end
	end
	props += chains + draped
	ctx.setAttribute("Floor28Chains", chains)
	ctx.setAttribute("Floor28DrapedCables", draped)
	landmarks += 1

	-- ===================================================================================================
	-- 10. Bonsai pines clinging to the needle rims and the ledge, leaning down the gale; vignettes on every
	--     terrace and at both ends of every link; stormgrass and stones on the rock.
	-- ===================================================================================================
	local taken: { { number } } = {}
	for _, lm in ThunderFloor28.Landmarks do
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
	for id, p in P do
		if id == "Sanctuary" then
			continue
		end
		local tries = if id == "Basin" then 40 else 10
		local want = if id == "Basin" then 8 else 3
		local made = 0
		for _ = 1, tries do
			if made >= want then break end
			-- A spot on the rim, inside the edge.
			local edgeX = rng:NextNumber() < 0.5
			local x = if edgeX then p.X + (if rng:NextNumber() < 0.5 then -1 else 1) * (p.Width / 2 - 4) else p.X + rng:NextNumber(-p.Width / 2 + 6, p.Width / 2 - 6)
			local z = if edgeX then p.Z + rng:NextNumber(-p.Depth / 2 + 6, p.Depth / 2 - 6) else p.Z + (if rng:NextNumber() < 0.5 then -1 else 1) * (p.Depth / 2 - 4)
			if id == "Basin" then
				z = p.Z - p.Depth / 2 + rng:NextNumber(3, 9)
			end
			local s = rng:NextNumber(0.4, 0.62)
			local cx, cz = x + 5 * s, z
			if spotFree(cx, cz, 7 * s + 1) then
				table.insert(taken, { cx, cz, 7 * s + 1 })
				piece("BonsaiPine", x, z, ThunderHighlands.DownwindYaw + rng:NextNumber(-14, 14), "WindBentPine", s, KAIRN, function(cf) fallbackPine(cf, s) end, p.Y)
				pines += 1
				made += 1
			end
		end
	end
	props += pines
	type ClutterKind = { Name: string, Kit: string?, Scale: number, Tint: any?, Fallback: ((cf: CFrame) -> ())?, R: number }
	local kinds: { ClutterKind } = {
		{ Name = "Cairn", Kit = "Cairn", Scale = 0.9, Tint = KAIRN, Fallback = function(cf) fallbackCairn(cf, 0.5) end, R = 3 },
		{ Name = "Boulders", Kit = "BoulderCluster", Scale = 0.7, Tint = KAIRN, Fallback = function(cf)
			lump("NeedleBoulder", (cf * CFrame.new(0, 1, 0)).Position, V(5, 3, 4), C.SLATE, Enum.Material.Slate)
		end, R = 3.6 },
		{ Name = "SmallCairn", Kit = "TrailCairnTall", Scale = 0.55, Tint = KAIRN, Fallback = function(cf) fallbackCairn(cf, 0.55) end, R = 1.8 },
		{ Name = "RuneStone", Kit = "RuneStandingStone", Scale = 0.6, Tint = KAIRN, Fallback = function(cf) fallbackRuneStone(cf, 0.6) end, R = 2.2 },
		{ Name = "CapacitorCask", Kit = "CapacitorCask", Scale = 0.8, Tint = KAIRN, Fallback = function(cf)
			ctx.cyl("CapacitorCaskBody", (cf * CFrame.new(0, 1.8, 0)).Position, 1.4, 3.6, C.TIMBER, Enum.Material.Wood)
		end, R = 2 },
		{ Name = "RopeCoil", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			ctx.cyl("RopeCoilHemp", (cf * CFrame.new(0, 0.4, 0)).Position, 1.4, 0.8, rgb(148, 126, 92), Enum.Material.Fabric)
		end, R = 1.6 },
		{ Name = "PlankStack", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			for j = 0, 2 do
				boxAt("SparePlank", V(6, 0.3, 1.2), cf * CFrame.new(0, 0.15 + j * 0.3, (j - 1) * 1.3) * CFrame.Angles(0, j * 0.08, 0), C.TIMBER, Enum.Material.Wood)
			end
		end, R = 3.2 },
		{ Name = "StormShards", Kit = "StormCrystalSpikes", Scale = 0.4, Tint = KAIRN, Fallback = function(cf) fallbackCrystals(cf, 0.4) end, R = 2.2 },
		{ Name = "RocFeather", Kit = "ShedRocFeather", Scale = 0.45, Tint = FEATHER_TINT, Fallback = function(cf) fallbackFeather(cf, 0.45) end, R = 3.6 },
	}
	local function vignette(cx: number, cz: number, spread: number, count: number, y: number?)
		local made = 0
		for _ = 1, count * 6 do
			if made >= count then break end
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, spread)
			local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
			local kind = kinds[rng:NextInteger(1, #kinds)]
			local rad = kind.R
			local gy, onPlat = surfaceAt(x, z)
			local ok = if y ~= nil then (onPlat and math.abs(gy - y) < 0.5) else (field == nil or field.Slope(x, z) < 0.9)
			if ok and math.abs(x) < w / 2 - 8 and math.abs(z) < d / 2 - 8 and spotFree(x, z, rad) then
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
					props += vignette(p.X + sx * (p.Width / 2 - 7), p.Z + sz * (p.Depth / 2 - 7), 10, 4, p.Y)
				end
			end
		end
	end
	-- The Cloudbreak Ledge's two rims: the lookout edge over the drop and the back under the arrival stair.
	local basin = P.Basin
	for x = -basin.Width / 2 + 20, basin.Width / 2 - 20, 26 do
		for _, sz in { -1, 1 } do
			props += vignette(x, basin.Z + sz * (basin.Depth / 2 - 6), 7, 2, basin.Y)
		end
	end
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		for e, endpoint in { { link.AX, link.AZ, link.AY }, { link.BX, link.BZ, link.BY } } do
			local inward = if e == 1 then -1 else 1
			for _, side in { -1, 1 } do
				props += vignette(endpoint[1] + nx * side * 26 + dx / len * inward * 6, endpoint[2] + nz * side * 26 + dz / len * inward * 6, 5, 2, endpoint[3])
			end
		end
	end
	-- Scattered vignettes on the mountain ledges round the room and on the needles' shoulders.
	for _ = 1, 90 do
		local x, z = rng:NextNumber(-w / 2 + 24, w / 2 - 24), rng:NextNumber(-d / 2 + 24, d / 2 - 40)
		if field and not openAbyss(x, z) and field.Slope(x, z) < 0.9 and not onTerrace(x, z, 2) then
			props += vignette(x, z, 10, 2)
		end
	end
	-- Stormgrass and loose stones on the rock tops and the ledge, never in a camp or on a walkway.
	for _ = 1, 7000 do
		if cover >= 520 then break end
		local x, z = rng:NextNumber(-w / 2 + 16, w / 2 - 16), rng:NextNumber(-d / 2 + 16, d / 2 - 16)
		local gy, onPlat = surfaceAt(x, z)
		local deck = false
		if onPlat and layout.Decks then
			for id, p in P do
				if layout.Decks[id] and math.abs(x - p.X) <= p.Width / 2 and math.abs(z - p.Z) <= p.Depth / 2 then
					deck = true
				end
			end
		end
		local r = 1.5
		local rock = onPlat or (field ~= nil and field.Slope(x, z) < 0.8 and not openAbyss(x, z))
		if rock and not deck and spotFree(x, z, r) then
			table.insert(taken, { x, z, r })
			ctx.reserve(x, z, r)
			local s = rng:NextNumber(0.8, 1.4)
			local m = if rng:NextNumber() < 0.22
				then piece("GroundCover", x, z, rng:NextNumber(0, 360), "BoulderCluster", rng:NextNumber(0.22, 0.4), KAIRN, function(cf)
					lump("NeedleStone", (cf * CFrame.new(0, 0.3, 0)).Position, V(2.2, 0.9, 1.8), C.SLATE, Enum.Material.Slate)
				end, if onPlat then gy else nil)
				else piece("GroundCover", x, z, ThunderHighlands.DownwindYaw + rng:NextNumber(-12, 12), "StormgrassTuft", s, KAIRN, function(cf) fallbackTuft(cf, s) end, if onPlat then gy else nil)
			noCollide(m)
			cover += 1
		end
	end
	-- Prayer-flag lines on the ledge's rim either side of the arrival, poles and all.
	for _, spot in { { -40, 238 }, { 40, 238 } } do
		if ctx.footprintClear(spot[1], spot[2], 16, 3) then
			piece("LedgeFlags", spot[1], spot[2], 0, "PrayerFlagLine", 0.6, Tints.FLAG, function(cf) fallbackFlags(cf, 0.6) end, P.Basin.Y)
			props += 1
		end
	end

	ctx.setAttribute("Floor28Landmarks", landmarks)
	ctx.setAttribute("Floor28Props", props)
	ctx.setAttribute("Floor28GroundCover", cover)
	ctx.setAttribute("Floor28Pines", pines)
end

return table.freeze(ThunderFloor28)
