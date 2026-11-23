--!strict
-- Floor 29, Tempest Redoubt (Thunder Highlands; docs/prompts/thunder-highlands-floor-layouts-prompt.md, guide
-- image reference/Thunder Highlands 29.jpg): the Kairnfolk's two-tier mountain acropolis on an east-west cliff
-- fault (TowerTerrain CLIFF_FAULT), its lower ward on rock over a misty chasm and its citadel on the plateau
-- above. TowerBiomeAssets calls Build(ctx) for layout.Authored == "thunder:4" with its own builders; the shared
-- helpers, palette and tints come from ThunderHighlands. The arched Thunder-Viaduct itself is TowerRoomBuilder's
-- (layout.Viaducts).
--
-- Lower ward: the barbican gatehouse (twin drum towers, raised portcullis, war banners) at the mouth of the walled
-- causeway, copper-caged nexus braziers along the Outer Causeway, the sheep fold in the West Ram Yard and the
-- thunder-ram stables in the East, and the great copper signal horns on both Horn Posts. The fault: a stepped
-- scarp with storm-water falls down it into the mist, copper conduits climbing it beside the viaduct, and
-- retaining buttresses under both switchbacks. Upper citadel: the Storm-Bell Gate astride the viaduct's grand
-- steps (its giant verdigris bell hung in the arch), round Stormkeep towers, lightning-spear ballistae over the
-- fault, the Crag Channeler's dais, crenellated curtain walls round every ward, the citadel keep behind the
-- Redoubt crowned by its copper-ringed storm spire, and the Capacitor Spire on the west crackling violet, braided
-- copper cables strung between them. A half-toppled watchtower on the western cliff, war banners at the
-- bridgeheads, pines, cairns and stormgrass: three skyline layers.
local ThunderHighlands = require(script.Parent.ThunderHighlands)

local ThunderFloor29 = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local C = ThunderHighlands.Palette
local Tints = ThunderHighlands.Tints
local KAIRN = Tints.KAIRN
local CLOUD = rgb(196, 196, 214)
local CLOUD_DEEP = rgb(150, 148, 178)
local UNDERGLOW = rgb(186, 156, 255)
local BELL = rgb(92, 152, 134)
local CLOUD_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = CLOUD, Material = Enum.Material.SmoothPlastic } })
local CLOUD_DEEP_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = CLOUD_DEEP, Material = Enum.Material.SmoothPlastic } })
-- War banners: Kairnfolk storm-red cloth with a gold forked bolt.
local BANNER_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = rgb(150, 44, 40), Material = Enum.Material.Fabric },
	ACCENT = { Color = rgb(226, 186, 62), Material = Enum.Material.Fabric },
})
local REDOUBT_TINT = ThunderHighlands.Tinted(KAIRN, {
	ALT = { Color = rgb(150, 44, 40), Material = Enum.Material.Fabric },
	CRYSTAL = { Color = rgb(186, 160, 255), Material = Enum.Material.Glass, Transparency = 0.25 },
})
local STABLE_TINT = ThunderHighlands.Tinted(KAIRN, { ALT = { Color = rgb(196, 170, 104), Material = Enum.Material.Grass } })

-- The citadel keep: centred on the shelf behind the Redoubt.
local KEEP_SCALE = 1.26
local KEEP_Z = -374.3
local KEEP_TOP = 129.2
-- The storm spire's rings on the keep (template heights) for the cables.
local KEEP_RING_Y = 89
-- The Capacitor Spire on its deck, and its nexus cage's height in the template.
local SPIRE_X, SPIRE_Z, SPIRE_SCALE = -305, -320, 1.3
local SPIRE_CAGE_Y = 53.5
-- The Storm-Bell Gate astride the top of the viaduct steps, and the barbican gate at the causeway's mouth.
local BELL_GATE_Z = -134
local BARBICAN_Z = 182
-- Signal horns on the Horn Posts (mouths to the south, over the lower ward).
local HORN_Z = -46
local HORN_X = 322

-- Every fixed Floor 29 landmark's footprint, for the specs (no landmark on a walkway or in a camp) and the census.
-- Y is its foot (nil: the ground); Top its height above that.
ThunderFloor29.Landmarks = table.freeze({
	{ Id = "CitadelKeep", X = 0, Z = KEEP_Z, Y = 46.5, HalfX = 22.4 * KEEP_SCALE, HalfZ = 16.3 * KEEP_SCALE, Top = KEEP_TOP * KEEP_SCALE },
	{ Id = "CapacitorSpire", X = SPIRE_X, Z = SPIRE_Z, Y = 38, HalfX = 8.8 * SPIRE_SCALE, HalfZ = 8.4 * SPIRE_SCALE, Top = 65.3 * SPIRE_SCALE },
	{ Id = "BellGateWestPylon", X = -28.3, Z = BELL_GATE_Z, Y = 36, HalfX = 5.6, HalfZ = 5.6, Top = 42.4 },
	{ Id = "BellGateEastPylon", X = 28.3, Z = BELL_GATE_Z, Y = 36, HalfX = 5.6, HalfZ = 5.6, Top = 42.4 },
	{ Id = "BellGateSpan", X = 0, Z = BELL_GATE_Z, Y = 59, HalfX = 34.4, HalfZ = 6.6, Top = 20, Straddles = true },
	{ Id = "BarbicanWestTower", X = -29, Z = BARBICAN_Z, Y = 0, HalfX = 7.9, HalfZ = 7.9, Top = 31.8 },
	{ Id = "BarbicanEastTower", X = 29, Z = BARBICAN_Z, Y = 0, HalfX = 7.9, HalfZ = 7.9, Top = 31.8 },
	{ Id = "BarbicanSpan", X = 0, Z = BARBICAN_Z, Y = 13, HalfX = 36.9, HalfZ = 8.1, Top = 19, Straddles = true },
	{ Id = "StormkeepTowerSW", X = -246, Z = -147, Y = 30, HalfX = 9.4, HalfZ = 9.4, Top = 40.3 },
	{ Id = "StormkeepTowerW", X = -252, Z = -174, Y = 30, HalfX = 9.4, HalfZ = 9.4, Top = 40.3 },
	{ Id = "StormkeepTowerSE", X = 246, Z = -147, Y = 32, HalfX = 9.4, HalfZ = 9.4, Top = 40.3 },
	{ Id = "StormkeepTowerNE", X = 248, Z = -208, Y = 32, HalfX = 9.4, HalfZ = 9.4, Top = 40.3 },
	{ Id = "SignalHornWest", X = -HORN_X, Z = HORN_Z + 4.2, Y = 16, HalfX = 6.5, HalfZ = 14.9, Top = 18.1 },
	{ Id = "SignalHornEast", X = HORN_X, Z = HORN_Z + 4.2, Y = 16, HalfX = 6.5, HalfZ = 14.9, Top = 18.1 },
	{ Id = "RamStable", X = 242, Z = 114, Y = 14, HalfX = 11.2, HalfZ = 6.6, Top = 13.1 },
	{ Id = "SheepFold", X = -236, Z = 110, Y = 12, HalfX = 11.2, HalfZ = 5.2, Top = 5.2 },
	{ Id = "BallistaWest", X = -176, Z = -142, Y = 30, HalfX = 6.8, HalfZ = 8.2, Top = 7.8 },
	{ Id = "BallistaEast", X = 176, Z = -142, Y = 32, HalfX = 6.8, HalfZ = 8.2, Top = 7.8 },
	{ Id = "ChannelerDais", X = 32, Z = -170, Y = 36, HalfX = 9, HalfZ = 9, Top = 9 },
	{ Id = "ShatteredWatchtower", X = -340, Z = 70, HalfX = 11.6, HalfZ = 11.6, Top = 26 },
	{ Id = "ButtressWestA", X = -226, Z = -9, Y = -10, HalfX = 5.1, HalfZ = 9.1, Top = 32 },
	{ Id = "ButtressWestB", X = -162, Z = -9, Y = -10, HalfX = 5.1, HalfZ = 9.1, Top = 32 },
	{ Id = "ButtressEastA", X = 162, Z = -9, Y = -10, HalfX = 5.1, HalfZ = 9.1, Top = 34 },
	{ Id = "ButtressEastB", X = 226, Z = -9, Y = -10, HalfX = 5.1, HalfZ = 9.1, Top = 34 },
}) :: { any }

function ThunderFloor29.Build(ctx: any)
	local H = ThunderHighlands.Helpers(ctx)
	local origin: Vector3, layout, field, bottom: number, w: number, d: number, P = H.origin, H.layout, H.field, H.bottom, H.w, H.d, H.P
	local surfaceAt, lowestGround, boxAt, rod, lump, light = H.surfaceAt, H.lowestGround, H.boxAt, H.rod, H.lump, H.light
	local noCollide, emitter, piece, glowOf = H.noCollide, H.emitter, H.piece, H.glowOf
	local fallbackCairn, fallbackPine, fallbackTuft, fallbackFlags = H.fallbackCairn, H.fallbackPine, H.fallbackTuft, H.fallbackFlags
	local fallbackRuneStone, fallbackCrystals, fallbackSheep, fallbackFall = H.fallbackRuneStone, H.fallbackCrystals, H.fallbackSheep, H.fallbackFall
	local landmarks, props, cover = 0, 0, 0
	local abyss = if field then field.Bottom else bottom - 4
	local rng = Random.new(29 * 7919)

	-- ===================================================================================================
	-- Native fallbacks for the Floor 29 kit (until it is imported). cf: the piece's origin, front +Z.
	-- ===================================================================================================
	local function fallbackKeep(cf: CFrame, s: number)
		boxAt("KeepHall", V(36, 30, 24) * s, cf * CFrame.new(0, 15 * s, 0), C.SLATE, Enum.Material.Slate)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local turret = ctx.cyl("KeepTurret", (cf * CFrame.new(sx * 17.5 * s, 18.5 * s, sz * 11.5 * s)).Position, 4.4 * s, 37 * s, C.GRANITE, Enum.Material.Slate)
				turret.CanCollide = true
			end
		end
		boxAt("KeepTower", V(18, 26, 16) * s, cf * CFrame.new(0, 43 * s, 0), C.GRANITE, Enum.Material.Slate)
		ctx.cyl("KeepDrum", (cf * CFrame.new(0, 62 * s, 0)).Position, 7.6 * s, 12 * s, C.SLATE_DARK, Enum.Material.Slate)
		boxAt("KeepSpire", V(5, 52, 5) * s, cf * CFrame.new(0, 95 * s, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		for k, r in { 10, 8, 6, 4.2 } do
			local y = ({ 78, 89, 99, 108 })[k]
			local ring = ctx.cyl("KeepSpireRing", (cf * CFrame.new(0, y * s, 0)).Position, r * s, 1.2 * s, C.COPPER, Enum.Material.Metal)
			ring.CanCollide = false
		end
		boxAt("KeepSpireTipGlowSeam", V(2.4, 2.4, 2.4) * s, cf * CFrame.new(0, 121.5 * s, 0), C.STORM, Enum.Material.Neon).CanCollide = false
	end
	local function fallbackCapacitor(cf: CFrame, s: number)
		boxAt("CapacitorTower", V(12, 26, 12) * s, cf * CFrame.new(0, 13 * s, 0), C.SLATE, Enum.Material.Slate)
		boxAt("CapacitorMast", V(2.4, 26, 2.4) * s, cf * CFrame.new(0, 44 * s, 0), C.COPPER, Enum.Material.Metal).CanCollide = false
		for k, r in { 6.2, 5, 3.9 } do
			local ring = ctx.cyl("CapacitorCoil", (cf * CFrame.new(0, ({ 36, 42, 47.5 })[k] * s, 0)).Position, r * s, 1.2 * s, C.COPPER, Enum.Material.Metal)
			ring.CanCollide = false
		end
		local core = ctx.orb("CapacitorNexusGlowSeam", (cf * CFrame.new(0, SPIRE_CAGE_Y * s, 0)).Position, V(6, 6, 6) * s, C.STORM, Enum.Material.Neon)
		core.CanCollide = false
	end
	local function fallbackBellGate(cf: CFrame)
		for _, sx in { -1, 1 } do
			boxAt("BellGatePylon", V(10, 40, 10), cf * CFrame.new(sx * 28, 20, 0), C.SLATE, Enum.Material.Slate)
		end
		boxAt("BellGateLintel", V(48, 8, 10), cf * CFrame.new(0, 38, 0), C.GRANITE, Enum.Material.Slate)
		local bell = ctx.cyl("StormBell", (cf * CFrame.new(0, 27, 0)).Position, 5.5, 8, BELL, Enum.Material.Metal)
		bell.CanCollide = false
	end
	local function fallbackBarbican(cf: CFrame)
		for _, sx in { -1, 1 } do
			local tower = ctx.cyl("BarbicanTower", (cf * CFrame.new(sx * 29, 15, 0)).Position, 7.4, 30, C.SLATE, Enum.Material.Slate)
			tower.CanCollide = true
		end
		boxAt("BarbicanGateBlock", V(46, 8, 12), cf * CFrame.new(0, 22, 0), C.GRANITE, Enum.Material.Slate)
		boxAt("BarbicanPortcullis", V(40, 5, 0.6), cf * CFrame.new(0, 18.4, -3), C.SLATE_DARK, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackRoundTower(cf: CFrame, s: number)
		local drum = ctx.cyl("StormkeepDrum", (cf * CFrame.new(0, 16 * s, 0)).Position, 9 * s, 32 * s, C.SLATE, Enum.Material.Slate)
		drum.CanCollide = true
		ctx.cyl("StormkeepCopperBand", (cf * CFrame.new(0, 22 * s, 0)).Position, 9.4 * s, 1 * s, C.COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackWall(cf: CFrame, len: number, sy: number)
		boxAt("CurtainWallRun", V(len, 8.3 * sy, 2.4), cf * CFrame.new(0, 4.15 * sy, 0), C.SLATE, Enum.Material.Slate)
		for k = 0, math.max(1, math.floor(len / 4)) - 1 do
			boxAt("CurtainWallMerlon", V(2.2, 1.8 * sy, 2.4), cf * CFrame.new(-len / 2 + 2 + k * 4, (8.3 + 0.9) * sy, 0), C.SLATE_DARK, Enum.Material.Slate)
		end
	end
	local function fallbackHorn(cf: CFrame, s: number)
		boxAt("HornPlinth", V(8, 5, 8) * s, cf * CFrame.new(0, 2.5 * s, 0), C.SLATE, Enum.Material.Slate)
		rod("HornThroatCopper", (cf * CFrame.new(0, 9 * s, -8 * s)).Position, (cf * CFrame.new(0, 11 * s, 15 * s)).Position, 1.6 * s, C.COPPER, Enum.Material.Metal)
		local mouth = rod("HornMouthCopper", (cf * CFrame.new(0, 11.4 * s, 16.4 * s)).Position, (cf * CFrame.new(0, 11.6 * s, 17.8 * s)).Position, 6 * s, C.COPPER, Enum.Material.Metal)
		mouth.CanCollide = false
	end
	local function fallbackStable(cf: CFrame)
		boxAt("StableBackWall", V(20, 10, 2), cf * CFrame.new(0, 5, -4.5), C.SLATE, Enum.Material.Slate)
		for k = 0, 4 do
			boxAt("StablePost", V(0.7, 7.2, 0.7), cf * CFrame.new(-9 + k * 4.5, 3.6, 5), C.TIMBER, Enum.Material.Wood)
		end
		boxAt("StableRoof", V(21.6, 0.5, 12.6), cf * CFrame.new(0, 9.2, 0) * CFrame.Angles(math.rad(-15), 0, 0), C.SLATE_DARK, Enum.Material.Slate)
	end
	local function fallbackPen(cf: CFrame)
		for _, sz in { -1, 1 } do
			boxAt("FoldWall", V(22, 3, 1.4), cf * CFrame.new(0, 1.5, sz * 5), C.SLATE, Enum.Material.Slate)
		end
		boxAt("FoldWall", V(1.4, 3, 10), cf * CFrame.new(-11, 1.5, 0), C.SLATE, Enum.Material.Slate)
	end
	local function fallbackBallista(cf: CFrame)
		ctx.cyl("BallistaPlinth", (cf * CFrame.new(0, 1.2, 0)).Position, 4.8, 2.4, C.SLATE, Enum.Material.Slate)
		boxAt("BallistaStock", V(2.2, 1.4, 13), cf * CFrame.new(0, 5.4, 0), C.TIMBER, Enum.Material.Wood)
		boxAt("BallistaArms", V(13, 0.6, 0.6), cf * CFrame.new(0, 5.8, 3), C.TIMBER_DARK, Enum.Material.Wood).CanCollide = false
		boxAt("BallistaSpear", V(0.6, 0.6, 16), cf * CFrame.new(0, 6.4, 1), C.COPPER, Enum.Material.Metal).CanCollide = false
	end
	local function fallbackBrazier(cf: CFrame)
		boxAt("BrazierPedestal", V(2.4, 5.6, 2.4), cf * CFrame.new(0, 2.8, 0), C.GRANITE, Enum.Material.Slate)
		ctx.cyl("BrazierBowl", (cf * CFrame.new(0, 6.1, 0)).Position, 2, 1, C.COPPER, Enum.Material.Metal)
		local core = ctx.orb("BrazierNexusGlowSeam", (cf * CFrame.new(0, 7.9, 0)).Position, V(2.2, 2.2, 2.2), C.STORM, Enum.Material.Neon)
		core.CanCollide = false
	end
	local function fallbackBanner(cf: CFrame, s: number)
		boxAt("BannerPole", V(0.6, 17, 0.6) * s, cf * CFrame.new(0, 8.5 * s, 0), C.TIMBER_DARK, Enum.Material.Wood)
		boxAt("BannerCloth", V(4, 9, 0.15) * s, cf * CFrame.new(0, 10.4 * s, 0.4 * s), rgb(150, 44, 40), Enum.Material.Fabric).CanCollide = false
	end
	local function fallbackRuin(cf: CFrame)
		for k = 0, 6 do
			local a = k * math.pi / 3.5
			boxAt("WatchtowerRuinCourse", V(4.2, 26 - k * 2.6, 2.2), cf * CFrame.new(math.cos(a) * 6.6, (26 - k * 2.6) / 2, math.sin(a) * 6.6) * CFrame.Angles(0, -a, 0), if k % 2 == 0 then C.SLATE else C.GRANITE, Enum.Material.Slate)
		end
	end
	local function fallbackButtress(cf: CFrame, sy: number)
		for k, step in { { 16, 0, 8 }, { 12.5, 8, 8 }, { 9, 16, 8 }, { 5.6, 24, 6 } } do
			boxAt("FaultButtress", V(8 - k * 0.6, step[3], step[1]) * V(1, sy, 1), cf * CFrame.new(0, (step[2] + step[3] / 2) * sy, -(16 - step[1]) / 2), C.SLATE, Enum.Material.Slate)
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

	for _, lm in ThunderFloor29.Landmarks do
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
	-- The lowest walking surface within r of (x, z), so mist banks keep under every walkway near them.
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
		for _, p in P do
			if math.abs(x - p.X) < p.Width / 2 + r + 6 and math.abs(z - p.Z) < p.Depth / 2 + r + 6 then
				low = math.min(low, p.Y)
			end
		end
		return low
	end
	local function openChasm(x: number, z: number): boolean
		return field == nil or field.Height(x, z) < abyss + 3
	end

	-- ===================================================================================================
	-- 1. The Tempest Redoubt: the citadel keep on the shelf behind it, crowned by the copper-ringed storm spire
	--    catching sky lightning, banners and cairns on the Redoubt's back corners.
	-- ===================================================================================================
	local apex = P.Apex
	local keepY = apex.Y - 1.5
	local keep = piece("CitadelKeep", 0, KEEP_Z, 0, "RedoubtCitadelKeep", KEEP_SCALE, REDOUBT_TINT, function(cf) fallbackKeep(cf, KEEP_SCALE) end, keepY, true)
	light(glowOf(keep), C.STORM, 2.2, 90)
	local spireTip = V(0, keepY + 122 * KEEP_SCALE, KEEP_Z)
	emitter("KeepSpireSparks", spireTip, C.STORM, 0.8, 10, 4, 1.1, 180, true)
	-- Sky lightning forking down onto the spire's tip.
	ctx.group("KeepSkyBolt", function()
		ctx.tag("OnTerrain", true)
		local prev = spireTip + V(0, 2, 0)
		for i, kink in { { 3, 9, -2 }, { -4, 8, 1 }, { 5, 10, 3 }, { -2, 9, -1 } } do
			local pt = prev + V(kink[1], kink[2], kink[3])
			local seg = rod("KeepSkyBoltGlowSeam", prev, pt, 0.3 - i * 0.04, rgb(232, 220, 255), Enum.Material.Neon)
			seg.CanCollide = false
			seg.CanQuery = false
			prev = pt
		end
	end)
	for _, corner in { { -58, -330 }, { 58, -330 } } do
		piece("RedoubtBanner", corner[1], corner[2], 0, "WarBannerPole", 1.2, BANNER_TINT, function(cf) fallbackBanner(cf, 1.2) end, apex.Y)
		piece("RedoubtCairn", corner[1] + (if corner[1] < 0 then -6 else 6), corner[2] - 10, corner[1] * 0.7, "TrailCairnTall", 1.1, KAIRN, function(cf) fallbackCairn(cf, 1.1) end, apex.Y)
	end
	landmarks += 1
	props += 5

	-- ===================================================================================================
	-- 2. The Capacitor Spire on its deck: nested copper coils round a caged violet nexus, static crackling,
	--    lightning arcing from the cage; braided copper cables slung from it and the Stormkeeps to the keep.
	-- ===================================================================================================
	local coil = P.WestCoilSpire
	local spire = piece("CapacitorSpire", SPIRE_X, SPIRE_Z, 30, "CapacitorCoilSpire", SPIRE_SCALE, REDOUBT_TINT, function(cf) fallbackCapacitor(cf, SPIRE_SCALE) end, coil.Y)
	light(glowOf(spire), C.STORM, 2.4, 70)
	local cage = V(SPIRE_X, coil.Y + SPIRE_CAGE_Y * SPIRE_SCALE, SPIRE_Z)
	emitter("CapacitorStatic", cage, C.STORM, 0.6, 12, 4, 1, 180, true)
	ctx.group("CapacitorArcs", function()
		ctx.tag("OnTerrain", true)
		for k, dir in { V(-1, 0.6, 0.3), V(0.8, 0.9, -0.5), V(0.3, -0.5, 1) } do
			local prev = cage + dir.Unit * 5
			for i = 1, 4 do
				local pt = prev + dir.Unit * 3.4 + V(math.sin(i * 2.1 + k) * 1.8, math.cos(i * 1.7) * 1.4, math.sin(i * 1.3 + k * 2) * 1.6)
				local seg = rod("CapacitorArcGlowSeam", prev, pt, 0.22, rgb(232, 220, 255), Enum.Material.Neon)
				seg.CanCollide = false
				seg.CanQuery = false
				prev = pt
			end
		end
	end)
	local keepRing = V(0, keepY + KEEP_RING_Y * KEEP_SCALE, KEEP_Z)
	local cables = 0
	local function cable(a: Vector3, b: Vector3, sag: number)
		ctx.group("CopperGroundingCable", function()
			ctx.tag("OnTerrain", true)
			local prev = a
			local n = math.max(6, math.floor((b - a).Magnitude / 18))
			for i = 1, n do
				local f = i / n
				local pt = a:Lerp(b, f) - V(0, sag * 4 * f * (1 - f), 0)
				local strand = rod("CopperGroundingCable", prev, pt, 0.45, C.COPPER, Enum.Material.Metal)
				strand.CanCollide = false
				strand.CanQuery = false
				prev = pt
			end
		end)
		cables += 1
	end
	cable(cage + V(3, 2, 0), keepRing + V(-8, 0, 0), 30)
	landmarks += 1
	props += 2

	-- ===================================================================================================
	-- 3. The Storm-Bell Gate astride the top of the viaduct's grand steps (a gate that spans the walkway on
	--    purpose), its giant verdigris storm-bell hung in the arch 23 studs over the steps; and the barbican
	--    gatehouse at the mouth of the walled causeway into the Lower Barbican.
	-- ===================================================================================================
	local ug = P.UpperGate
	ctx.group("RampArch", function()
		local cf = CFrame.new(0, ug.Y, BELL_GATE_Z)
		if ctx.has("StormBellGatehouse") then
			ctx.kitAt("StormBellGatehouse", cf * CFrame.new(0, -0.3, 0), 1, REDOUBT_TINT)
		else
			fallbackBellGate(cf)
		end
	end)
	local bellLamp = ctx.block("StormBellGlowSeam", V(1, 1, 1), V(0, ug.Y + 34, BELL_GATE_Z - 1.4), C.STORM, Enum.Material.Neon, nil, 1)
	bellLamp.CanCollide = false
	bellLamp.CanQuery = false
	light(bellLamp, rgb(214, 196, 255), 1.4, 40)
	local basin = P.Basin
	ctx.group("RampArch", function()
		local cf = CFrame.new(0, basin.Y, BARBICAN_Z)
		if ctx.has("BarbicanGatehouse") then
			ctx.kitAt("BarbicanGatehouse", cf * CFrame.new(0, -0.3, 0), 1, BANNER_TINT)
		else
			fallbackBarbican(cf)
		end
	end)
	landmarks += 2
	props += 2

	-- ===================================================================================================
	-- 4. The Stormkeeps: round towers on the bastions' outer corners, lightning-spear ballistae trained over the
	--    fault, and braided copper cables from the tower heads up to the keep's storm spire.
	-- ===================================================================================================
	local towerScale = 0.9
	for _, spec in { { "StormkeepTowerSW", -246, -147, P.WestBastion }, { "StormkeepTowerW", -252, -174, P.WestBastion },
		{ "StormkeepTowerSE", 246, -147, P.EastBastion }, { "StormkeepTowerNE", 248, -208, P.EastBastion } } do
		local t = spec[4]
		piece("StormkeepTower", spec[2], spec[3], rng:NextNumber(0, 360), "StormkeepRoundTower", towerScale, BANNER_TINT, function(cf) fallbackRoundTower(cf, towerScale) end, t.Y)
		if spec[1] == "StormkeepTowerSW" or spec[1] == "StormkeepTowerSE" then
			cable(V(spec[2], t.Y + 33 * towerScale, spec[3]), keepRing + V(if spec[2] < 0 then -6 else 6, -4, 4), 26)
		end
	end
	piece("LightningBallista", -176, -142, 0, "LightningSpearBallista", 1, KAIRN, fallbackBallista, P.WestBastion.Y)
	piece("LightningBallista", 176, -142, 0, "LightningSpearBallista", 1, KAIRN, fallbackBallista, P.EastBastion.Y)
	ctx.setAttribute("Floor29Cables", cables)
	landmarks += 2
	props += 6 + cables

	-- ===================================================================================================
	-- 5. The Crag Channeler's dais beside the Storm-Bell Gate: a slate disc inlaid with a giant forked-bolt
	--    mosaic, four rune stones round it and a storm-glass bed at its heart.
	-- ===================================================================================================
	ctx.group("ChannelerDais", function()
		local at = V(32, ug.Y, -170)
		local disc = ctx.cyl("ChannelerDaisSlab", at + V(0, 0.15, 0), 8.6, 0.5, C.SLATE_DARK, Enum.Material.Slate)
		disc.CanCollide = false
		local rim = ctx.cyl("ChannelerDaisCopperRim", at + V(0, 0.1, 0), 9, 0.4, C.COPPER, Enum.Material.Metal)
		rim.CanCollide = false
		local zig = { V(-1.6, 0, 6.4), V(2.2, 0, 1.8), V(-1.2, 0, -0.6), V(2.4, 0, -6.4) }
		for i = 1, #zig - 1 do
			local seg = rod("ChannelerBoltGlowSeam", at + zig[i] + V(0, 0.45, 0), at + zig[i + 1] + V(0, 0.45, 0), 0.35, C.STORM, Enum.Material.Neon)
			seg.CanCollide = false
			seg.CanQuery = false
		end
	end)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		piece("ChannelerStone", 32 + math.cos(a) * 7, -170 + math.sin(a) * 7, math.deg(-a), "RuneStandingStone", 0.55, KAIRN, function(cf) fallbackRuneStone(cf, 0.55) end, ug.Y)
	end
	landmarks += 1
	props += 5

	-- ===================================================================================================
	-- 6. The lower ward's work: the sheep fold in the West Ram Yard, thunder-ram stables in the East, the great
	--    copper signal horns on both Horn Posts aimed south over the ward, copper-caged nexus braziers along the
	--    Outer Causeway's lip.
	-- ===================================================================================================
	local wg, eg = P.WestGallery, P.EastGallery
	piece("ThunderRamStable", 242, 114, 180, "ThunderRamStable", 1, STABLE_TINT, fallbackStable, eg.Y)
	piece("SheepFold", -236, 110, 0, "RamPenChute", 1, KAIRN, fallbackPen, wg.Y)
	for k, spot in { { -244, 110 }, { -232, 112 }, { -238, 113 } } do
		piece("FoldSheep", spot[1], spot[2], k * 70, "HighlandSheep", 1.1, Tints.SHEEP, function(cf) fallbackSheep(cf, 1.1) end, wg.Y)
	end
	for _, sx in { -1, 1 } do
		local horn = P[if sx < 0 then "WestHornPost" else "EastHornPost"]
		piece("SignalHorn", sx * HORN_X, HORN_Z, 0, "SignalHornCannon", 1, KAIRN, function(cf) fallbackHorn(cf, 1) end, horn.Y)
	end
	local braziers = 0
	for _, x in { -150, -70, 70, 150 } do
		local z = basin.Z - basin.Depth / 2 + 4
		if ctx.footprintClear(x, z, 2.4, 2.4) and campFree(x, z, 2) then
			local b = piece("NexusBrazier", x, z, 0, "NexusBrazierPedestal", 1.1, REDOUBT_TINT, fallbackBrazier, basin.Y)
			light(glowOf(b), C.STORM, 1.1, 26)
			braziers += 1
		end
	end
	-- Pairs flanking the arrival from the Storm Road.
	for _, sx in { -1, 1 } do
		local b = piece("NexusBrazier", sx * 30, basin.Z + basin.Depth / 2 - 6, 0, "NexusBrazierPedestal", 1.1, REDOUBT_TINT, fallbackBrazier, basin.Y)
		braziers += 1
		noCollide(b)
	end
	ctx.setAttribute("Floor29Braziers", braziers)
	landmarks += 3
	props += 6 + braziers

	-- ===================================================================================================
	-- 7. The fault: storm-water falls down the scarp into the mist, copper conduits climbing the face beside the
	--    viaduct, retaining buttresses under both switchbacks.
	-- ===================================================================================================
	local falls = 0
	if field then
		for _, fx in { -112, 104, 292 } do
			-- The scarp's foot (first rise off the chasm floor, going north) and its lip (the plateau's edge).
			local foot, lip = nil, nil
			for z = -50, -130, -0.5 do
				local h = field.Height(fx, z)
				if not foot and h > abyss + 2 then foot = z end
				if foot and h >= abyss + 24 then
					lip = z
					break
				end
			end
			if foot and lip then
				local lipY = math.huge
				for k = -1, 1 do
					lipY = math.min(lipY, field.Height(fx + k * 7, lip - 2))
				end
				local fy = abyss - 0.4
				local sy = (lipY + 1 - fy) / 60
				local cf = CFrame.new(fx, fy, foot + 2.6)
				ctx.group("FaultFall", function()
					ctx.tag("OnTerrain", true)
					if ctx.has("WaterfallRibbon") then
						ctx.kitAt("WaterfallRibbon", cf, V(0.9, sy, 1), Tints.WATER)
					else
						fallbackFall(cf, sy)
					end
				end)
				emitter("FaultFallSpray", V(fx, abyss + 2, foot + 6), C.FOAM, 4, 5, 3, 2.6, 40, false)
				falls += 1
			end
		end
		-- Conduits: braided copper climbing the scarp face either side of the viaduct, bolted to the rock, from
		-- the chasm floor to a junction box on the lip.
		ctx.group("CliffConduit", function()
			ctx.tag("OnTerrain", true)
			for _, cx in { -44, -40, 40, 44 } do
				local foot, lip = nil, nil
				for z = -50, -130, -0.5 do
					local h = field.Height(cx, z)
					if not foot and h > abyss + 2 then foot = z end
					if foot and h >= abyss + 24 then
						lip = z
						break
					end
				end
				if foot and lip then
					local lipY = field.Height(cx, lip - 1.5)
					local base = V(cx, abyss + 0.3, foot + 1.6)
					local top = V(cx, lipY + 0.6, foot + 1.6)
					local pipe = rod("CliffConduitCopper", base, top, 0.45, C.COPPER, Enum.Material.Metal)
					pipe.CanCollide = false
					pipe.CanQuery = false
					local over = rod("CliffConduitCopper", top, V(cx, lipY + 0.6, lip - 4), 0.45, C.COPPER, Enum.Material.Metal)
					over.CanCollide = false
					over.CanQuery = false
					for y = base.Y + 4, top.Y - 1, 5 do
						local clamp = boxAt("CliffConduitClamp", V(1.4, 0.5, 1.2), CFrame.new(cx, y, foot + 1.3), C.VERDIGRIS, Enum.Material.Metal)
						clamp.CanCollide = false
						clamp.CanQuery = false
					end
					local junction = boxAt("ConduitJunctionBox", V(2.4, 2.4, 1.8), CFrame.new(cx, lipY + 1.2, lip - 4.5), C.COPPER, Enum.Material.Metal)
					junction.CanCollide = false
				end
			end
		end)
	end
	ctx.setAttribute("Floor29Falls", falls)
	for _, spec in { { -226, P.WestSwitchback }, { -162, P.WestSwitchback }, { 162, P.EastSwitchback }, { 226, P.EastSwitchback } } do
		local x, t = spec[1], spec[2]
		local sy = (t.Y - abyss) / 31
		local edgeZ = t.Z + t.Depth / 2
		ctx.group("FaultButtress", function()
			ctx.tag("OnTerrain", true)
			local cf = CFrame.new(x, abyss - 0.2, edgeZ + 9) * CFrame.Angles(0, math.pi, 0)
			if ctx.has("FaultRetainingButtress") then
				ctx.kitAt("FaultRetainingButtress", cf, V(1, sy, 1), KAIRN)
			else
				fallbackButtress(cf, sy)
			end
		end)
	end
	landmarks += 3
	props += falls + 5

	-- ===================================================================================================
	-- 8. Curtain walls: crenellated parapets just inside every ward's edges, broken wherever a path crosses,
	--    clear of the camps, the landmarks and the gates.
	-- ===================================================================================================
	local walls = 0
	local landmarkRects = ThunderFloor29.Landmarks
	local function nearLandmark(x: number, z: number, pad: number): boolean
		for _, lm in landmarkRects do
			if math.abs(x - lm.X) < lm.HalfX + pad and math.abs(z - lm.Z) < lm.HalfZ + pad then
				return true
			end
		end
		return false
	end
	local function wallRing(t: any, inset: number, sy: number)
		local hx, hz = t.Width / 2 - inset, t.Depth / 2 - inset
		local corners = { V(-hx, 0, -hz), V(hx, 0, -hz), V(hx, 0, hz), V(-hx, 0, hz) }
		for i = 1, #corners do
			local a, b = corners[i], corners[i % #corners + 1]
			local length = (b - a).Magnitude
			local n = math.max(1, math.round(length / 15))
			local seg = length / n
			for k = 0, n - 1 do
				local m = a:Lerp(b, (k + 0.5) / n)
				local x, z = t.X + m.X, t.Z + m.Z
				local yaw = math.deg(math.atan2(-(b.Z - a.Z), b.X - a.X))
				if ctx.footprintClear(x, z, seg / 2 + 0.5, 1.8) and campFree(x, z, 2) and not nearLandmark(x, z, 3) then
					local sx = (seg + 0.3) / 16
					ctx.group("CurtainWall", function()
						local cf = CFrame.new(x, t.Y - 0.25, z) * CFrame.Angles(0, math.rad(yaw), 0)
						if ctx.has("CurtainWallSegment") then
							ctx.kitAt("CurtainWallSegment", cf, V(sx, sy, 1), KAIRN)
						else
							fallbackWall(cf, seg + 0.3, sy)
						end
					end)
					walls += 1
				end
			end
		end
	end
	for _, id in { "Crossing", "WestGallery", "EastGallery", "WestHornPost", "EastHornPost", "UpperGate", "WestBastion", "EastBastion", "Apex", "WestCoilSpire", "ViaductPier" } do
		wallRing(P[id], 1.6, 0.6)
	end
	props += walls
	ctx.setAttribute("Floor29CurtainWalls", walls)
	landmarks += 1

	-- ===================================================================================================
	-- 9. The chasm: mist banks drifting over the slate floor (always 4+ studs under every walkway near them),
	--    violet underglow from invisible anchors, slow mist emitters; the half-toppled watchtower on the
	--    western cliff; far relay spires on the peaks.
	-- ===================================================================================================
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
	for row, gz in { -70, -40, -10, 20, 50, 80, 110, 140, 165 } do
		for gx = -320, 320, 40 do
			local x = gx + rng:NextNumber(-9, 9) + (if row % 2 == 0 then 20 else 0)
			local z = gz + rng:NextNumber(-8, 8)
			local sx = rng:NextNumber(0.85, 1.3)
			if math.abs(x) < w / 2 - 16 and openChasm(x, z) then
				local ceiling = lowestWalkNear(x, z, 16 * sx) - 4
				local base = abyss - 2.2
				local sy = math.clamp((math.min(ceiling, abyss + 8) - base) / 11.7, 0, 0.85)
				if sy >= 0.3 then
					cloudBank(x, z, base, sx, sy, rng:NextNumber() < 0.35)
				end
			end
		end
	end
	props += clouds
	ctx.setAttribute("Floor29CloudBanks", clouds)
	for k, spot in { { -120, 150 }, { 120, 150 }, { -110, -60 }, { 110, -60 } } do
		ctx.group("ChasmUnderglow", function()
			ctx.tag("OnTerrain", true)
			local anchor = ctx.block("ChasmUnderglowMistAnchor", V(1, 1, 1), V(spot[1], abyss + 2, spot[2]), UNDERGLOW, Enum.Material.SmoothPlastic, nil, 1)
			anchor.CanCollide = false
			anchor.CanQuery = false
			light(anchor, UNDERGLOW, if k <= 2 then 0.8 else 0.7, 70)
		end)
	end
	for _, spot in { { -100, 40 }, { 100, 40 }, { 0, -66 } } do
		emitter("ChasmMist", V(spot[1], abyss + 6, spot[2]), CLOUD, 24, 2, 2, 14, 40, false)
	end
	piece("ShatteredWatchtower", -340, 70, 70, "ShatteredWatchtower", 1, KAIRN, function(cf) fallbackRuin(cf) end, lowestGround(-340, 70, 8), true)
	if field then
		for k, spot in { { -330, -250 }, { 330, -260 }, { -335, 200 }, { 335, 190 }, { 330, -100 } } do
			local x, z = spot[1], spot[2]
			piece("FarRelaySpire", x, z, k * 47, "CapacitorCoilSpire", 0.7, REDOUBT_TINT, function(cf) fallbackCapacitor(cf, 0.7) end, lowestGround(x, z, 6) - 1, true)
		end
		props += 5
	end
	landmarks += 3
	props += 1

	-- ===================================================================================================
	-- 10. Bridgeheads: a tattered war banner either side of every link's upper end; pines, vignettes and
	--     stormgrass on the wards, the cliff ledges and the mountain shelves.
	-- ===================================================================================================
	local taken: { { number } } = {}
	for _, lm in ThunderFloor29.Landmarks do
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
	local banners = 0
	for _, link in layout.Links do
		local a, b = V(link.AX, link.AY, link.AZ), V(link.BX, link.BY, link.BZ)
		local top = if b.Y >= a.Y then b else a
		local flat = V(b.X - a.X, 0, b.Z - a.Z)
		local flatUnit = if flat.Magnitude > 0.01 then flat.Unit else V(0, 0, -1)
		local outward = if top == b then flatUnit else -flatUnit
		local right = V(-flatUnit.Z, 0, flatUnit.X)
		for _, side in { -1, 1 } do
			for _, offs in { { 24, 6 }, { 26, 12 }, { 30, 4 } } do
				local at = top + right * (side * offs[1]) + outward * offs[2]
				local gy, onPlat = surfaceAt(at.X, at.Z)
				if onPlat and math.abs(gy - top.Y) < 0.5 and spotFree(at.X, at.Z, 2.4) then
					table.insert(taken, { at.X, at.Z, 2.4 })
					local m = piece("BridgeheadBanner", at.X, at.Z, math.deg(math.atan2(flatUnit.X, flatUnit.Z)), "WarBannerPole", 1, BANNER_TINT, function(cf) fallbackBanner(cf, 1) end, gy)
					noCollide(m)
					banners += 1
					break
				end
			end
		end
	end
	props += banners
	ctx.setAttribute("Floor29Banners", banners)
	local pines = 0
	for id, p in P do
		if id == "Sanctuary" then
			continue
		end
		local tries = if id == "Basin" then 50 else 10
		local want = if id == "Basin" then 10 else 2
		local made = 0
		for _ = 1, tries do
			if made >= want then break end
			local edgeX = rng:NextNumber() < 0.5
			local x = if edgeX then p.X + (if rng:NextNumber() < 0.5 then -1 else 1) * (p.Width / 2 - 5) else p.X + rng:NextNumber(-p.Width / 2 + 6, p.Width / 2 - 6)
			local z = if edgeX then p.Z + rng:NextNumber(-p.Depth / 2 + 6, p.Depth / 2 - 6) else p.Z + (if rng:NextNumber() < 0.5 then -1 else 1) * (p.Depth / 2 - 5)
			if id == "Basin" then
				z = p.Z + (if rng:NextNumber() < 0.5 then -1 else 1) * (p.Depth / 2 - rng:NextNumber(4, 9))
			end
			local s = rng:NextNumber(0.45, 0.7)
			local cx, cz = x + 5 * s, z
			if spotFree(cx, cz, 7 * s + 1) then
				table.insert(taken, { cx, cz, 7 * s + 1 })
				piece("WindBentPine", x, z, ThunderHighlands.DownwindYaw + rng:NextNumber(-12, 12), "WindBentPine", s, KAIRN, function(cf) fallbackPine(cf, s) end, p.Y)
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
			lump("WardBoulder", (cf * CFrame.new(0, 1, 0)).Position, V(5, 3, 4), C.SLATE, Enum.Material.Slate)
		end, R = 3.6 },
		{ Name = "SmallCairn", Kit = "TrailCairnTall", Scale = 0.55, Tint = KAIRN, Fallback = function(cf) fallbackCairn(cf, 0.55) end, R = 1.8 },
		{ Name = "CapacitorCask", Kit = "CapacitorCask", Scale = 0.8, Tint = KAIRN, Fallback = function(cf)
			ctx.cyl("CapacitorCaskBody", (cf * CFrame.new(0, 1.8, 0)).Position, 1.4, 3.6, C.TIMBER, Enum.Material.Wood)
		end, R = 2 },
		{ Name = "WireReel", Kit = "CopperWireReel", Scale = 0.6, Tint = KAIRN, Fallback = function(cf)
			ctx.cyl("WireReelDrum", (cf * CFrame.new(0, 1.6, 0)).Position, 1.6, 2.4, C.COPPER, Enum.Material.Metal)
		end, R = 2.4 },
		{ Name = "SpearRack", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			boxAt("SpearRackFrame", V(4.4, 0.4, 0.6), cf * CFrame.new(0, 2.6, 0), C.TIMBER_DARK, Enum.Material.Wood)
			for k = 0, 3 do
				local spear = boxAt("RackSpear", V(0.25, 5.4, 0.25), cf * CFrame.new(-1.6 + k * 1.05, 2.7, 0.2) * CFrame.Angles(math.rad(-8), 0, 0), C.COPPER, Enum.Material.Metal)
				spear.CanCollide = false
			end
		end, R = 2.6 },
		{ Name = "HayBales", Kit = nil, Scale = 1, Tint = nil, Fallback = function(cf)
			for j = 0, 1 do
				boxAt("HayBale", V(2.6, 1.4, 1.6), cf * CFrame.new(j * 2.8 - 1.4, 0.7, 0) * CFrame.Angles(0, j * 0.2, 0), rgb(196, 170, 104), Enum.Material.Grass)
			end
		end, R = 3 },
		{ Name = "StormShards", Kit = "StormCrystalSpikes", Scale = 0.4, Tint = KAIRN, Fallback = function(cf) fallbackCrystals(cf, 0.4) end, R = 2.2 },
		{ Name = "RuneStone", Kit = "RuneStandingStone", Scale = 0.55, Tint = KAIRN, Fallback = function(cf) fallbackRuneStone(cf, 0.55) end, R = 2.2 },
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
					props += vignette(p.X + sx * (p.Width / 2 - 8), p.Z + sz * (p.Depth / 2 - 8), 10, 4, p.Y)
				end
			end
		end
	end
	for x = -basin.Width / 2 + 20, basin.Width / 2 - 20, 28 do
		for _, sz in { -1, 1 } do
			props += vignette(x, basin.Z + sz * (basin.Depth / 2 - 7), 7, 2, basin.Y)
		end
	end
	for _, link in layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		for e, endpoint in { { link.AX, link.AZ, link.AY }, { link.BX, link.BZ, link.BY } } do
			local inward = if e == 1 then -1 else 1
			for _, side in { -1, 1 } do
				props += vignette(endpoint[1] + nx * side * 27 + dx / len * inward * 6, endpoint[2] + nz * side * 27 + dz / len * inward * 6, 5, 2, endpoint[3])
			end
		end
	end
	-- The plateau between the citadel wards and the mountain shelves.
	for _ = 1, 110 do
		local x, z = rng:NextNumber(-w / 2 + 24, w / 2 - 24), rng:NextNumber(-d / 2 + 24, d / 2 - 40)
		if field and not openChasm(x, z) and field.Slope(x, z) < 0.9 and not onTerrace(x, z, 2) then
			props += vignette(x, z, 10, 2)
		end
	end
	for _ = 1, 8000 do
		if cover >= 560 then break end
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
		local ground = onPlat or (field ~= nil and field.Slope(x, z) < 0.8 and not openChasm(x, z))
		if ground and not deck and spotFree(x, z, r) then
			table.insert(taken, { x, z, r })
			ctx.reserve(x, z, r)
			local s = rng:NextNumber(0.8, 1.4)
			local m = if rng:NextNumber() < 0.22
				then piece("GroundCover", x, z, rng:NextNumber(0, 360), "BoulderCluster", rng:NextNumber(0.22, 0.4), KAIRN, function(cf)
					lump("WardStone", (cf * CFrame.new(0, 0.3, 0)).Position, V(2.2, 0.9, 1.8), C.SLATE, Enum.Material.Slate)
				end, if onPlat then gy else nil)
				else piece("GroundCover", x, z, ThunderHighlands.DownwindYaw + rng:NextNumber(-12, 12), "StormgrassTuft", s, KAIRN, function(cf) fallbackTuft(cf, s) end, if onPlat then gy else nil)
			noCollide(m)
			cover += 1
		end
	end
	-- Prayer-flag lines either side of the arrival.
	for _, spot in { { -48, 276 }, { 48, 276 } } do
		if ctx.footprintClear(spot[1], spot[2], 16, 3) then
			piece("CausewayFlags", spot[1], spot[2], 0, "PrayerFlagLine", 0.6, Tints.FLAG, function(cf) fallbackFlags(cf, 0.6) end, basin.Y)
			props += 1
		end
	end

	ctx.setAttribute("Floor29Landmarks", landmarks)
	ctx.setAttribute("Floor29Props", props)
	ctx.setAttribute("Floor29GroundCover", cover)
	ctx.setAttribute("Floor29Pines", pines)
end

return table.freeze(ThunderFloor29)
