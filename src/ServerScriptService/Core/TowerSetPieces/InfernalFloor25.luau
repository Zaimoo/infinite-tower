--!strict
-- Hand-authored set pieces for Infernal Foundry Floor 25, Titan's Crucible (Boss Arena)
-- (docs/prompts/infernal-foundry-floor-layouts-prompt.md).
--
-- Compact 740 x 795 x 250 cathedral-cavern boss arena inspired by the Titan's Crucible concept art: the colossal
-- 179.5-stud Great Crucible on twin geared trunnion towers behind the 170 x 124 dark-iron boss dais, the glowing
-- Titan Heart Grate beating inside its throat, cathedral Vault Rib Arches and basalt columns ringing the dais,
-- twin towering Great Bellows ("the lungs") feeding sweeping Duct Manifolds across WestDuct & EastDuct, the Pour
-- Spout funnel catching the molten fall north of the Pour Gate pinch, upper Chain Galleries with overhead girder
-- trusses & Hanging Chain Runs well above walk height, giant Titan Fist & Helm moulds and gear-driven Pattern
-- Lathes on the west wing, stacked steel Ingot Pallets and a gallery of finished weapons on the east wing, ladle
-- carts and cooling ingots on the Casting Floor, and six molten lava falls pouring down the dark cavern walls.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local InfernalFloor25 = {}

local V = Vector3.new
local rgb = Color3.fromRGB

local C = InfernalFoundry.Colors
local IRON = C.IRON
local IRON_DARK = C.IRON_DARK
local BRICK = C.BRICK
local BRICK_DARK = C.BRICK_DARK
local BRASS = C.BRASS
local TIMBER = C.TIMBER
local SLAG = C.SLAG
local EMBER = C.EMBER

local SOOT = InfernalFoundry.SOOT
local ORE_TINT = InfernalFoundry.ORE_TINT
local LAMP_TINT = InfernalFoundry.LAMP_TINT
local tinted = InfernalFoundry.Tinted

export type Landmark = InfernalFoundry.Landmark

-- Every Floor 25 landmark's scaled footprint (local floor space), checked offline by the specs against every
-- walkway lane, every camp (34-stud clearance), boss portals, and the 740 x 795 room bounds.
InfernalFloor25.Landmarks = table.freeze({
	-- Colossal centrepiece: The Great Crucible behind the boss dais (scale 1.55x1.85x0.72 -> 179.5 studs tall!).
	-- Front edge sits at Z = -367.5 (strictly behind the dais at -364 and boss portals at -352; never overhangs arena).
	{ Id = "GreatCrucible", X = 0, Z = -382, Y = 44, HalfX = 58.3, HalfZ = 14.5, Top = 179.5 },
	{ Id = "TitanHeartGrate", X = 0, Z = -367, Y = 52, HalfX = 15.2, HalfZ = 2.4, Top = 30.4 },
	-- Colossal Foundry Flue Stacks & Cathedral Vault Rib Arches framing the dais.
	{ Id = "CrucibleFlueW", X = -104, Z = -381, Y = -6, HalfX = 11.7, HalfZ = 15.4, Top = 160.6 },
	{ Id = "CrucibleFlueE", X = 104, Z = -381, Y = -6, HalfX = 11.7, HalfZ = 15.4, Top = 160.6 },
	{ Id = "VaultColumnNW", X = -102, Z = -356, Y = -6, HalfX = 11.6, HalfZ = 11.6, Top = 180.0 },
	{ Id = "VaultColumnNE", X = 102, Z = -356, Y = -6, HalfX = 11.6, HalfZ = 11.6, Top = 180.0 },
	{ Id = "VaultColumnSW", X = -138, Z = -336, Y = -6, HalfX = 11.6, HalfZ = 11.6, Top = 180.0 },
	{ Id = "VaultColumnSE", X = 138, Z = -336, Y = -6, HalfX = 11.6, HalfZ = 11.6, Top = 180.0 },
	-- Twin Great Bellows Towers flanking WestBastion & EastBastion ("the lungs").
	{ Id = "WestBellowsTower", X = -296, Z = -215, Y = -6, HalfX = 21.0, HalfZ = 23.5, Top = 128.0 },
	{ Id = "EastBellowsTower", X = 296, Z = -215, Y = -6, HalfX = 21.0, HalfZ = 23.5, Top = 128.0 },
	-- Colossal Curved Duct Manifolds sweeping out of the Bellows Towers into WestDuct & EastDuct.
	{ Id = "WestDuctManifold", X = -134, Z = -126, Y = 24, HalfX = 11.5, HalfZ = 6.5, Top = 25.0 },
	{ Id = "EastDuctManifold", X = 134, Z = -126, Y = 26, HalfX = 11.5, HalfZ = 6.5, Top = 25.0 },
	{ Id = "WestDuctRiser", X = -196, Z = -136, Y = -6, HalfX = 14.0, HalfZ = 14.0, Top = 56.0 },
	{ Id = "EastDuctRiser", X = 196, Z = -136, Y = -6, HalfX = 14.0, HalfZ = 14.0, Top = 56.0 },
	-- The Pour Spout overlook funnel (dead-end north of Pour Gate).
	{ Id = "PourSpoutFunnel", X = 0, Z = -156, Y = 28, HalfX = 11.7, HalfZ = 11.8, Top = 22.2 },
	-- Pour Gate south flanking braziers on basalt corbel piers off the south lip (clear of camp & landings).
	{ Id = "PourGateBrazierW", X = -14, Z = -4, Y = 20, HalfX = 4.2, HalfZ = 4.2, Top = 15.0 },
	{ Id = "PourGateBrazierE", X = 14, Z = -4, Y = 20, HalfX = 4.2, HalfZ = 4.2, Top = 15.0 },
	-- Upper Chain Galleries: Chain Gallery Rails & Titan Tool Anvils.
	{ Id = "WestChainRailN", X = -200, Z = -350, Y = 36, HalfX = 14.0, HalfZ = 1.6, Top = 6.2 },
	{ Id = "EastChainRailN", X = 200, Z = -350, Y = 40, HalfX = 14.0, HalfZ = 1.6, Top = 6.2 },
	-- Pattern Shop (west dead-end side chamber): Pattern Lathes & Titan Helm Mould.
	{ Id = "PatternLatheW", X = -280, Z = -56, Y = 12, HalfX = 4.5, HalfZ = 12.6, Top = 14.0 },
	{ Id = "PatternLatheN", X = -254, Z = -72, Y = 12, HalfX = 12.6, HalfZ = 4.5, Top = 14.0 },
	{ Id = "PatternHelmMould", X = -230, Z = -66, Y = 12, HalfX = 9.2, HalfZ = 9.2, Top = 15.0 },
	-- West Mould Station outer casting apron: Titan Fist & Helm Moulds + Jib Crane (>= 36 studs from camp at -210, 68).
	{ Id = "WestTitanFistMould", X = -260, Z = 68, Y = 8, HalfX = 9.0, HalfZ = 11.5, Top = 9.4 },
	{ Id = "WestTitanHelmMould", X = -256, Z = 100, Y = 8, HalfX = 9.5, HalfZ = 9.5, Top = 15.5 },
	{ Id = "WestMouldCrane", X = -258, Z = 36, Y = 8, HalfX = 4.0, HalfZ = 10.5, Top = 32.4 },
	-- Ingot Store (east dead-end side chamber): Stacked Ingot Pallets & Weapon Gallery.
	{ Id = "IngotPalletE1", X = 280, Z = -60, Y = 14, HalfX = 4.6, HalfZ = 7.2, Top = 5.0 },
	{ Id = "IngotPalletE2", X = 256, Z = -72, Y = 14, HalfX = 7.2, HalfZ = 4.6, Top = 5.0 },
	{ Id = "IngotWeaponGallery", X = 230, Z = -70, Y = 14, HalfX = 8.5, HalfZ = 3.0, Top = 9.0 },
	-- East Mould Station outer apron: Titan Fist Mould, Ingot Pallets & Weapon Displays (>= 36 studs from camp at 210, 68).
	{ Id = "EastTitanFistMould", X = 260, Z = 68, Y = 8, HalfX = 9.0, HalfZ = 11.5, Top = 9.4 },
	{ Id = "EastMouldPallet", X = 256, Z = 100, Y = 8, HalfX = 7.2, HalfZ = 4.6, Top = 5.0 },
	{ Id = "EastMouldCrane", X = 258, Z = 36, Y = 8, HalfX = 4.0, HalfZ = 10.5, Top = 32.4 },
	-- Casting Floor (Basin): Ladle Carts, Cooling Ingots, Titan Tool Anvils & Flank Cranes (clear of camps ±110, 228).
	{ Id = "CastingLadleW", X = -44, Z = 272, Y = 0, HalfX = 8.5, HalfZ = 5.5, Top = 15.4 },
	{ Id = "CastingLadleE", X = 44, Z = 272, Y = 0, HalfX = 8.5, HalfZ = 5.5, Top = 15.4 },
	{ Id = "CastingMouldW", X = -196, Z = 184, Y = 0, HalfX = 9.0, HalfZ = 6.0, Top = 2.0 },
	{ Id = "CastingMouldE", X = 196, Z = 184, Y = 0, HalfX = 9.0, HalfZ = 6.0, Top = 2.0 },
	{ Id = "CastingIngotsW", X = -230, Z = 268, Y = 0, HalfX = 7.2, HalfZ = 4.6, Top = 5.0 },
	{ Id = "CastingIngotsE", X = 230, Z = 268, Y = 0, HalfX = 7.2, HalfZ = 4.6, Top = 5.0 },
	{ Id = "CastingCraneW", X = -296, Z = 228, Y = 0, HalfX = 11.2, HalfZ = 3.2, Top = 32.4 },
	{ Id = "CastingCraneE", X = 296, Z = 228, Y = 0, HalfX = 11.2, HalfZ = 3.2, Top = 32.4 },
}) :: { Landmark }

function InfernalFloor25.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, w: number, d: number, P = H.field, H.bottom, ctx.w, H.d, H.P
	local surfaceAt, boxAt, rod, lump, light, plume, piece = H.surfaceAt, H.boxAt, H.rod, H.lump, H.light, H.plume, H.piece
	local glowOf, noCollide, fallbackStack, fallbackHeap, fallbackCart = H.glowOf, H.noCollide, H.fallbackStack, H.fallbackHeap, H.fallbackCart
	local landmarks, props, cover = 0, 0, 0

	local MOLTEN_GOLD = tinted(SOOT, {
		GLOW = { Color = rgb(255, 206, 92), Material = Enum.Material.Neon },
		GOLD = { Color = rgb(186, 138, 64), Material = Enum.Material.Metal },
	})
	local HEART_GLOW = tinted(SOOT, {
		GLOW = { Color = rgb(255, 224, 128), Material = Enum.Material.Neon },
		GOLD = { Color = rgb(206, 152, 68), Material = Enum.Material.Metal },
	})
	local CRUCIBLE_IRON = tinted(SOOT, {
		STONE = { Color = rgb(48, 42, 46), Material = Enum.Material.Basalt },
		METAL = { Color = rgb(62, 58, 62), Material = Enum.Material.Metal },
		GLOW = { Color = rgb(255, 198, 84), Material = Enum.Material.Neon },
	})
	local PATTERN_WOOD = tinted(SOOT, {
		WOOD = { Color = rgb(138, 98, 62), Material = Enum.Material.Wood },
		GOLD = { Color = rgb(180, 134, 62), Material = Enum.Material.Metal },
	})
	local CRUST = tinted(SOOT, { ALT = { Color = rgb(30, 26, 30), Material = Enum.Material.Basalt }, STONE = { Color = rgb(48, 42, 46), Material = Enum.Material.Basalt } })
	local lavaY = if field then field.LiquidLevel else bottom

	for _, lm in InfernalFloor25.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	local function plinth(x: number, z: number, halfX: number, halfZ: number, top: number)
		local b = bottom - 6
		local h = math.max(2, top - b)
		boxAt("CruciblePlinthWall", V(halfX * 2, h, halfZ * 2), CFrame.new(x, b + h / 2, z), BRICK_DARK, Enum.Material.Brick)
		boxAt("CruciblePlinthCap", V(halfX * 2 + 1.4, 1.2, halfZ * 2 + 1.4), CFrame.new(x, top - 0.6, z), IRON_DARK, Enum.Material.Metal)
	end

	-- Native fallbacks for all 12 Floor 25 templates.
	local function fallbackCrucible(cf: CFrame, sx: number, sy: number, sz: number)
		for _, side in { -1, 1 } do
			boxAt("CruciblePier", V(14 * sx, 68 * sy, 24 * sz), cf * CFrame.new(side * 30 * sx, 34 * sy, 0), BRICK_DARK, Enum.Material.Brick)
		end
		local drum = boxAt("CrucibleDrum", V(24 * sz, 43 * sy, 43 * sx), cf * CFrame.new(0, 64 * sy, 0) * CFrame.Angles(0, math.pi / 2, 0), IRON_DARK, Enum.Material.Metal)
		drum.Shape = Enum.PartType.Cylinder
		local mouth = boxAt("CrucibleMouthGlow", V(32 * sx, 32 * sy, 2 * sz), cf * CFrame.new(0, 64 * sy, 12 * sz), rgb(255, 206, 92), Enum.Material.Neon)
		mouth.CanCollide = false
		boxAt("CrucibleCrown", V(24 * sx, 16 * sy, 18 * sz), cf * CFrame.new(0, 88 * sy, 0), BRICK, Enum.Material.Brick)
	end
	local function fallbackHeartGrate(cf: CFrame)
		local heart = boxAt("TitanHeartGlow", V(18, 18, 2), cf * CFrame.new(0, 14, 0), rgb(255, 224, 128), Enum.Material.Neon)
		heart.CanCollide = false
		for k = -3, 3 do
			boxAt("TitanHeartBar", V(0.8, 20, 1.2), cf * CFrame.new(k * 2.5, 14, 1.2), IRON_DARK, Enum.Material.Metal)
		end
	end
	local function fallbackBellows(cf: CFrame, s: number)
		boxAt("BellowsPlinth", V(24 * s, 14 * s, 22 * s), cf * CFrame.new(0, 7 * s, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("BellowsBody", V(16 * s, 44 * s, 14 * s), cf * CFrame.new(0, 36 * s, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("BellowsRocker", V(20 * s, 3 * s, 5 * s), cf * CFrame.new(0, 60 * s, 0), IRON, Enum.Material.Metal)
	end
	local function fallbackFistMould(cf: CFrame)
		boxAt("FistMouldFlask", V(20, 4.2, 16), cf * CFrame.new(0, 2.1, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("FistMouldCast", V(12, 4.6, 10), cf * CFrame.new(0, 5.4, 0), IRON, Enum.Material.Metal)
		boxAt("FistMouldGlow", V(14, 0.3, 1.2), cf * CFrame.new(0, 4.4, 6), EMBER, Enum.Material.Neon)
	end
	local function fallbackHelmMould(cf: CFrame)
		boxAt("HelmMouldFlask", V(18, 4.0, 18), cf * CFrame.new(0, 2.0, 0), IRON_DARK, Enum.Material.Metal)
		ctx.cyl("HelmMouldDome", (cf * CFrame.new(0, 9.5, 0)).Position, 6.0, 11.0, IRON, Enum.Material.Metal)
		boxAt("HelmVisorGlow", V(7.6, 3.4, 0.8), cf * CFrame.new(0, 9.6, 6.2), EMBER, Enum.Material.Neon)
	end
	local function fallbackHangingChain(cf: CFrame, sy: number)
		boxAt("ChainTrolley", V(7.4, 3.4, 5.2), cf * CFrame.new(0, 33 * sy, 0), IRON, Enum.Material.Metal)
		local ch = boxAt("ChainDrop", V(0.9, 28 * sy, 0.9), cf * CFrame.new(0, 18 * sy, 0), IRON_DARK, Enum.Material.Metal)
		ch.CanCollide = false
		boxAt("ChainHook", V(3.6, 4.2, 2.4), cf * CFrame.new(0, 4 * sy, 0), BRASS, Enum.Material.Metal)
	end
	local function fallbackPourSpout(cf: CFrame)
		boxAt("SpoutPedestal", V(15, 13, 15), cf * CFrame.new(0, 6.5, 0), BRICK_DARK, Enum.Material.Brick)
		ctx.cyl("SpoutBasin", (cf * CFrame.new(0, 17.5, 0)).Position, 9.6, 7.5, IRON, Enum.Material.Metal)
		boxAt("SpoutPoolGlow", V(15, 0.4, 15), cf * CFrame.new(0, 21.4, 0), rgb(255, 206, 92), Enum.Material.Neon)
	end
	local function fallbackDuct(cf: CFrame, s: number?)
		local sc = s or 1
		boxAt("DuctShoe", V(12 * sc, 2 * sc, 12 * sc), cf * CFrame.new(0, 1 * sc, 3 * sc), IRON_DARK, Enum.Material.Metal)
		ctx.cyl("DuctRiser", (cf * CFrame.new(0, 10 * sc, 3 * sc)).Position, 4.4 * sc, 16 * sc, IRON, Enum.Material.Metal)
		boxAt("DuctHorizontal", V(8.8 * sc, 8.8 * sc, 18 * sc), cf * CFrame.new(0, 18 * sc, -6 * sc), IRON, Enum.Material.Metal)
	end
	local function fallbackIngotPallet(cf: CFrame)
		boxAt("IngotBase", V(14, 0.8, 8.6), cf * CFrame.new(0, 0.4, 0), TIMBER, Enum.Material.Wood)
		boxAt("IngotBeams", V(13.4, 2.8, 7.8), cf * CFrame.new(0, 2.2, 0), IRON, Enum.Material.Metal)
		boxAt("IngotHotBarGlow", V(4, 1.0, 1.4), cf * CFrame.new(0, 4.1, 0), EMBER, Enum.Material.Neon)
	end
	local function fallbackLathe(cf: CFrame)
		boxAt("LatheBed", V(22, 4.8, 7.2), cf * CFrame.new(0, 2.4, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("LatheHead", V(6.2, 7.6, 6.8), cf * CFrame.new(-8, 8.4, 0), IRON, Enum.Material.Metal)
		local drum = boxAt("LatheDrum", V(10.5, 5.2, 5.2), cf * CFrame.new(0.8, 8.8, 0), TIMBER, Enum.Material.Wood)
		drum.Shape = Enum.PartType.Cylinder
	end
	local function fallbackVaultArch(cf: CFrame, s: number)
		ctx.cyl("VaultCol", (cf * CFrame.new(0, 35 * s, 0)).Position, 5.5 * s, 70 * s, BRICK_DARK, Enum.Material.Basalt)
		boxAt("VaultCap", V(14 * s, 6 * s, 14 * s), cf * CFrame.new(0, 72 * s, 0), IRON_DARK, Enum.Material.Metal)
	end
	local function fallbackChainRail(cf: CFrame)
		boxAt("ChainRailBar", V(22, 0.7, 0.7), cf * CFrame.new(0, 5.0, 0), IRON_DARK, Enum.Material.Metal)
		for k = -1, 1 do
			boxAt("ChainRailPost", V(0.9, 5.0, 0.9), cf * CFrame.new(k * 9.5, 2.5, 0), IRON_DARK, Enum.Material.Metal)
		end
	end
	local function fallbackTitanAnvil(cf: CFrame)
		boxAt("TitanAnvilBase", V(8.4, 3.6, 6.4), cf * CFrame.new(0, 1.8, 0), BRICK_DARK, Enum.Material.Basalt)
		boxAt("TitanAnvilBody", V(9.6, 3.4, 4.8), cf * CFrame.new(0, 5.3, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("TitanAnvilHorn", V(4.2, 1.8, 2.8), cf * CFrame.new(6.2, 5.8, 0), IRON, Enum.Material.Metal)
	end

	-- =====================================================================================================
	-- 1. THE GREAT CRUCIBLE (179.5-stud colossal centrepiece behind the boss dais; NEVER overhangs arena!)
	--    + Titan Heart Grate + Cathedral Vault Rib Arches & Basalt Columns ringing the dais
	-- =====================================================================================================
	local apex = P.Apex
	ctx.group("GreatCrucibleCentrepiece", function()
		local cf = CFrame.new(0, apex.Y, -382)
		plinth(0, -382, 60, 15, apex.Y)
		if ctx.has("GreatCrucible") then
			local mdl = ctx.kitAt("GreatCrucible", cf, V(1.55, 1.85, 0.72), CRUCIBLE_IRON)
			local g = glowOf(mdl)
			if g then light(g, rgb(255, 206, 92), 2.8, 120) end
		else
			fallbackCrucible(cf, 1.55, 1.85, 0.72)
		end
		local pour = boxAt("CruciblePourGlowSeam", V(14, 92, 6.0), CFrame.new(0, apex.Y + 42, -370), rgb(255, 212, 102), Enum.Material.Neon)
		pour.CanCollide = false
		pour.CanQuery = false
		light(pour, rgb(255, 192, 76), 2.2, 96)
	end)
	local heart = piece("TitanHeartGrate", 0, -367, 0, "TitanHeartGrate", 1.0, HEART_GLOW, fallbackHeartGrate, apex.Y + 8)
	local hg = glowOf(heart)
	if hg then light(hg, rgb(255, 218, 110), 2.0, 80) end
	plume(V(0, apex.Y + 44, -368), rgb(255, 204, 96), 6.0, 12, 10, 2.2)

	for _, sx in { -1, 1 } do
		piece("CrucibleFlueStack", sx * 104, -381, 0, "FlueStack", 1.6, SOOT, function(cf) fallbackStack(cf, 1.6) end, -6)
		plume(V(sx * 104, 158, -381), rgb(52, 46, 48), 16, 3, 7, 10)
		for _, spot in { { 102, -356 }, { 138, -336 } } do
			local cx, cz = sx * spot[1], spot[2]
			ctx.group("VaultRibArch", function()
				ctx.tag("OnTerrain", true)
				local cf = CFrame.new(cx, -6, cz) * CFrame.Angles(0, math.rad(if sx < 0 then 0 else 180), 0)
				if ctx.has("VaultRibArch") then
					ctx.kitAt("VaultRibArch", cf, 1.52, CRUCIBLE_IRON)
				else
					fallbackVaultArch(cf, 1.52)
				end
			end)
		end
	end
	landmarks += 3
	props += 8

	-- =====================================================================================================
	-- 2. Twin Great Bellows Towers ("the lungs") + Sweeping Duct Manifolds into WestDuct & EastDuct
	-- =====================================================================================================
	for _, sx in { -1, 1 } do
		plinth(sx * 296, -215, 21, 22, 16)
		ctx.group("GreatBellowsTower", function()
			ctx.tag("OnTerrain", true)
			local cf = CFrame.new(sx * 296, 16, -215) * CFrame.Angles(0, math.rad(if sx < 0 then 90 else -90), 0)
			if ctx.has("GreatBellows") then
				ctx.kitAt("GreatBellows", cf, 1.65, SOOT)
			else
				fallbackBellows(cf, 1.65)
			end
		end)
		plume(V(sx * 296, 126, -215), rgb(188, 184, 188), 11, 4, 6, 7)
		local ductDeck = if sx < 0 then P.WestDuct else P.EastDuct
		piece("DuctManifold", sx * 134, -126, if sx < 0 then -90 else 90, "DuctManifold", 0.92, SOOT, function(cf) fallbackDuct(cf, 0.92) end, ductDeck.Y)
		plinth(sx * 196, -136, 11, 11, 22)
		piece("BellowsDuctRiser", sx * 196, -136, if sx < 0 then 90 else -90, "DuctManifold", 1.32, SOOT, function(cf) fallbackDuct(cf, 1.32) end, 22)
	end
	landmarks += 2
	props += 6

	-- =====================================================================================================
	-- 3. The Pour Spout Overlook + Molten Overflow Cascade down to the Boiling Lava Lake (Bottom -6)
	--    + Pour Gate Flanking Watch Braziers
	-- =====================================================================================================
	local spout = P.PourSpout
	local funnel = piece("PourSpoutChute", 0, -156, 0, "PourSpoutChute", 1.0, MOLTEN_GOLD, fallbackPourSpout, spout.Y)
	local fg = glowOf(funnel)
	if fg then light(fg, rgb(255, 198, 84), 2.2, 74) end
	ctx.group("CrucibleOverflowFall", function()
		ctx.tag("OnTerrain", true)
		local spill = boxAt("DaisOverflowWall", V(28, 48, 8), CFrame.new(0, 20, -236), BRICK_DARK, Enum.Material.Brick)
		spill.CanCollide = false
		local fall = boxAt("CrucibleOverflowGlowSeam", V(10, 50, 4.0), CFrame.new(0, 20, -231), rgb(255, 202, 86), Enum.Material.Neon)
		fall.CanCollide = false
		fall.CanQuery = false
		light(fall, rgb(255, 184, 64), 2.0, 84)
		local splash = ctx.cyl("OverflowSplashGlowSeam", V(0, lavaY + 0.15, -229), 12, 0.4, rgb(255, 210, 96), Enum.Material.Neon)
		splash.CanCollide = false
		splash.CanQuery = false
	end)
	plume(V(0, lavaY + 3, -227), rgb(255, 186, 76), 6.0, 10, 8, 2.2)

	local cr = P.Crossing
	for _, sx in { -1, 1 } do
		plinth(sx * 14, -4, 4.4, 4.4, cr.Y)
		local br = piece("PourGateBrazier", sx * 14, -4, 0, "SignalBrazier", 0.5, MOLTEN_GOLD, function(cf)
			boxAt("GateBrazierBowl", V(6, 5, 6), cf * CFrame.new(0, 5, 0), IRON_DARK, Enum.Material.Metal)
			boxAt("GateBrazierFlameGlow", V(4.5, 5, 4.5), cf * CFrame.new(0, 10, 0), EMBER, Enum.Material.Neon)
		end, cr.Y)
		local bg = glowOf(br)
		if bg then light(bg, EMBER, 1.5, 54) end
	end
	landmarks += 2
	props += 4

	-- =====================================================================================================
	-- 4. Upper Chain Galleries (WestChainGallery & EastChainGallery) + Overhead Vault Runways & Hanging Chains
	-- =====================================================================================================
	for _, sx in { -1, 1 } do
		local cg = if sx < 0 then P.WestChainGallery else P.EastChainGallery
		piece("ChainGalleryRail", sx * 200, -350, 0, "ChainGalleryRail", 1.25, SOOT, fallbackChainRail, cg.Y)
		piece("ChainGalleryRail", sx * 166, -325, if sx < 0 then 90 else -90, "ChainGalleryRail", 1.2, SOOT, fallbackChainRail, cg.Y)
		ctx.group("ChainGalleryAnvil", function()
			fallbackTitanAnvil(CFrame.new(sx * 222, cg.Y, -338) * CFrame.Angles(0, math.rad(sx * -45), 0))
		end)
		-- Registered overhead vault crane runway girder (Y = 142) carrying HangingChainRuns well above walk height!
		ctx.group("VaultChainRunway", function()
			ctx.tag("OnTerrain", true)
			local runX = sx * 212
			local runY = 142
			boxAt("ChainRunwayBeam", V(5, 5, 310), CFrame.new(runX, runY, -185), IRON_DARK, Enum.Material.Metal)
			for _, pz in { -325, -215, -110, -30 } do
				local strutOut = rod("ChainRunwayWallBrace", V(sx * (w / 2 - 12), runY + 16, pz), V(runX, runY, pz), 1.6, IRON_DARK, Enum.Material.Metal)
				strutOut.CanCollide = false
				strutOut.CanQuery = false
			end
			for _, cz in { -305, -175, -60 } do
				local sy = 1.65
				local hookY = runY - 35.25 * sy
				local cf = CFrame.new(runX, hookY, cz)
				if ctx.has("HangingChainRun") then
					local mdl = ctx.kitAt("HangingChainRun", cf, V(1.3, sy, 1.3), MOLTEN_GOLD)
					noCollide(mdl)
				else
					fallbackHangingChain(cf, sy)
				end
			end
		end)
	end
	landmarks += 2
	props += 12

	-- =====================================================================================================
	-- 5. Pattern Shop & West Mould Station (Pattern Lathes, Giant Titan Fist & Helm Moulds, Jib Crane)
	-- =====================================================================================================
	local pShop = P.PatternShop
	piece("PatternLathe", -280, -56, 90, "PatternLathe", 1.0, PATTERN_WOOD, fallbackLathe, pShop.Y)
	piece("PatternLathe", -254, -72, 0, "PatternLathe", 1.0, PATTERN_WOOD, fallbackLathe, pShop.Y)
	piece("PatternHelmMould", -230, -66, 35, "TitanMouldHelm", 0.8, MOLTEN_GOLD, fallbackHelmMould, pShop.Y)
	piece("PatternRack", -282, -26, 90, "PatternRack", 1.0, PATTERN_WOOD, nil, pShop.Y)

	local wMould = P.WestGallery
	piece("WestTitanFistMould", -260, 68, 90, "TitanMouldFist", 1.0, MOLTEN_GOLD, fallbackFistMould, wMould.Y)
	piece("WestTitanHelmMould", -256, 100, 125, "TitanMouldHelm", 0.82, MOLTEN_GOLD, fallbackHelmMould, wMould.Y)
	piece("WestMouldCrane", -258, 36, 0, "JibCrane", 1.0, SOOT, nil, wMould.Y)
	landmarks += 2
	props += 7

	-- =====================================================================================================
	-- 6. Ingot Store & East Mould Station (Stacked Ingot Pallets, Titan Mould, Gallery of Finished Weapons)
	-- =====================================================================================================
	local iStore = P.IngotStore
	piece("IngotPallet", 280, -60, 90, "IngotPallet", 1.0, MOLTEN_GOLD, fallbackIngotPallet, iStore.Y)
	piece("IngotPallet", 256, -72, 0, "IngotPallet", 1.0, SOOT, fallbackIngotPallet, iStore.Y)
	piece("IngotPallet", 280, -32, 90, "IngotPallet", 1.0, SOOT, fallbackIngotPallet, iStore.Y)
	for _, spot in { { 226, -70, 0 }, { 236, -70, 0 }, { 254, 46, -90 }, { 254, 86, -90 } } do
		local y = if spot[2] < 0 then iStore.Y else P.EastGallery.Y
		piece("FinishedWeaponDisplay", spot[1], spot[2], spot[3], "BladeDisplay", 1.05, MOLTEN_GOLD, nil, y)
	end
	piece("IngotArmourRack", 226, -30, 90, "ArmourRack", 1.0, SOOT, nil, iStore.Y)

	local eMould = P.EastGallery
	piece("EastTitanFistMould", 260, 68, -90, "TitanMouldFist", 1.0, MOLTEN_GOLD, fallbackFistMould, eMould.Y)
	piece("EastMouldPallet", 256, 100, 0, "IngotPallet", 1.0, MOLTEN_GOLD, fallbackIngotPallet, eMould.Y)
	piece("EastMouldCrane", 258, 36, 0, "JibCrane", 1.0, SOOT, nil, eMould.Y)
	landmarks += 3
	props += 11

	-- =====================================================================================================
	-- 7. Casting Floor (Basin): Ladle Carts, Cooling Ingots, Titan Tool Anvils & Flank Jib Cranes
	-- =====================================================================================================
	local yard = P.Basin
	for _, sx in { -1, 1 } do
		local ladle = piece("CastingLadle", sx * 44, 272, sx * -90, "SlagLadleCart", 1.0, MOLTEN_GOLD, fallbackCart, yard.Y)
		local lg = glowOf(ladle)
		if lg then light(lg, EMBER, 1.4, 46) end
		piece("CastingMould", sx * 196, 184, 0, "MouldBed", 1.05, MOLTEN_GOLD, nil, yard.Y)
		piece("CastingIngots", sx * 230, 268, sx * 12, "IngotPallet", 1.0, MOLTEN_GOLD, fallbackIngotPallet, yard.Y)
		piece("CastingCrane", sx * 296, 228, sx * -90, "JibCrane", 1.0, SOOT, nil, yard.Y)
		piece("CastingOreCart", sx * 172, 270, sx * 30, "OreCart", 1.0, ORE_TINT, fallbackCart, yard.Y)
		ctx.group("CastingTitanAnvil", function()
			fallbackTitanAnvil(CFrame.new(sx * 260, yard.Y, 190) * CFrame.Angles(0, math.rad(sx * -35), 0))
		end)
	end
	landmarks += 3
	props += 12

	-- =====================================================================================================
	-- 8. Far Backdrop: Six Molten Lava Falls, Colossal Cathedral Vault Ribs (Y 250), & Invisible Lava Lights
	-- =====================================================================================================
	local lavaFallSpots = {
		{ -358, -100, 90, 158, 15 },
		{ -358, -265, 90, 170, 15 },
		{ 358, -100, -90, 158, 15 },
		{ 358, -265, -90, 170, 15 },
		{ -156, -386, 0, 182, 18 },
		{ 156, -386, 0, 182, 18 },
	}
	for k, f in lavaFallSpots do
		ctx.group("LavaFallCascade", function()
			ctx.tag("OnTerrain", true)
			local fx, fz, yaw, fh, fw = f[1], f[2], f[3], f[4], f[5]
			local cf = CFrame.new(fx, bottom + fh / 2, fz) * CFrame.Angles(0, math.rad(yaw), 0)
			local sheet = boxAt("LavaFallCurtainGlowSeam", V(fw, fh, 3.4), cf, rgb(255, 146, 38), Enum.Material.Neon)
			sheet.CanCollide = false
			sheet.CanQuery = false
			local core = boxAt("LavaFallCoreGlowSeam", V(fw * 0.48, fh, 4.0), cf * CFrame.new(0, 0, 0.5), rgb(255, 218, 104), Enum.Material.Neon)
			core.CanCollide = false
			core.CanQuery = false
			if k <= 4 then
				light(core, rgb(255, 168, 56), 1.6, 72)
			end
		end)
		if k >= 5 then
			plume(V(f[1], lavaY + 5, f[2] + 12), rgb(255, 174, 68), 7, 6, 8, 2.5)
		end
	end

	ctx.group("CathedralVaultCeiling", function()
		ctx.tag("OnTerrain", true)
		local vaultTop = ctx.h - 10
		local springY = vaultTop - 78
		local halfSpan = w / 2 - 14
		for _, z in { -300, -170, -45, 80, 200 } do
			local segs = 12
			for k = 0, segs - 1 do
				local a0, a1 = math.pi * k / segs, math.pi * (k + 1) / segs
				local p0 = V(-math.cos(a0) * halfSpan, springY + math.sin(a0) * 74, z)
				local p1 = V(-math.cos(a1) * halfSpan, springY + math.sin(a1) * 74, z)
				local rib = rod("CathedralVaultRib", p0, p1, 4.2, rgb(38, 34, 38), Enum.Material.Basalt)
				rib.Shape = Enum.PartType.Block
				rib.Size = V((p1 - p0).Magnitude + 2, 7.0, 7.6)
				rib.CanCollide = false
				rib.CanQuery = false
			end
		end
	end)

	-- Boiling lava lake: organic volcanic crust floes + invisible PointLight anchors (ZERO flat orange boxes!).
	local floeCount = 0
	for k, spot in {
		{ -80, 50 }, { 80, 50 }, { -122, -10 }, { 122, -10 },
		{ -62, -100 }, { 62, -100 }, { -142, -210 }, { 142, -210 },
		{ -48, 120 }, { 48, 120 }, { 0, 34 }, { -102, -180 }, { 102, -180 }, { 0, -200 },
	} do
		local m = piece("CrustFloe", spot[1], spot[2], k * 41, "CrustIsland", 0.78 + (k % 3) * 0.16, CRUST, function(cf)
			lump("CrustSlab", (cf * CFrame.new(0, 0.4, 0)).Position, V(13, 1.5, 9.5), SLAG, Enum.Material.Basalt)
		end, lavaY - 0.15)
		noCollide(m)
		floeCount += 1
	end
	for _, spot in { { 0, 42 }, { -105, -48 }, { 105, -48 }, { 0, -110 }, { -96, -190 }, { 96, -190 } } do
		local anchor = boxAt("LavaLakeLightAnchor", V(2, 2, 2), CFrame.new(spot[1], lavaY + 4, spot[2]), EMBER, Enum.Material.SmoothPlastic, 1)
		anchor.CanCollide = false
		anchor.CanQuery = false
		light(anchor, rgb(255, 152, 42), 1.9, 80)
	end
	plume(V(-105, lavaY + 2, 8), EMBER, 2.0, 7, 6, 2.5)
	plume(V(105, lavaY + 2, 8), EMBER, 2.0, 7, 6, 2.5)
	plume(V(0, lavaY + 2, 26), rgb(96, 74, 66), 11, 4, 4, 6)
	landmarks += 2
	props += #lavaFallSpots + floeCount

	-- =====================================================================================================
	-- 9. Rich Multi-Template Foundry Prop Pass + Ground Cover (keeps the 170 x 124 boss dais clear!)
	-- =====================================================================================================
	local clutter, groundCover = H.workClutter(InfernalFloor25.Landmarks, 25, 72, 420)
	props += clutter
	cover += groundCover

	local extraKinds = {
		{ Name = "IngotStack", Kit = "IngotPallet", Scale = 0.72, Tint = MOLTEN_GOLD, R = 4.6 },
		{ Name = "CoolingBladeRack", Kit = "CoolingRack", Scale = 0.72, Tint = MOLTEN_GOLD, R = 3.6 },
		{ Name = "WeaponStand", Kit = "BladeDisplay", Scale = 0.85, Tint = SOOT, R = 3.2 },
		{ Name = "ArmourStand", Kit = "ArmourRack", Scale = 0.8, Tint = SOOT, R = 3.4 },
		{ Name = "PatternStand", Kit = "PatternRack", Scale = 0.8, Tint = PATTERN_WOOD, R = 3.8 },
		{ Name = "PartsStand", Kit = "PartsRack", Scale = 0.8, Tint = SOOT, R = 3.6 },
		{ Name = "MouldTray", Kit = "MouldBed", Scale = 0.6, Tint = MOLTEN_GOLD, R = 4.6 },
		{ Name = "SteamRelief", Kit = "SteamVent", Scale = 0.9, Tint = SOOT, R = 2.6 },
		{ Name = "PowderKegs", Kit = "PowderKegStack", Scale = 0.72, Tint = SOOT, R = 3.4 },
		{ Name = "ChainWinchRig", Kit = "ChainWinch", Scale = 0.65, Tint = SOOT, R = 3.6 },
		{ Name = "ScrapMound", Kit = "ScrapHeap", Scale = 0.65, Tint = SOOT, R = 4.6 },
		{ Name = "CoalMound", Kit = "CoalHeap", Scale = 0.58, Tint = SOOT, R = 3.8 },
		{ Name = "FoundryCauldron", Kit = "MessCauldron", Scale = 0.85, Tint = SOOT, R = 3.2 },
		{ Name = "WatchLamp", Kit = "SignalLamp", Scale = 1.0, Tint = LAMP_TINT, R = 1.8 },
		{ Name = "GearWheel", Kit = "WallGear", Scale = 0.25, Tint = SOOT, R = 3.4 },
		{ Name = "BasaltUrn", Kit = "StoneUrn", Scale = 0.95, Tint = CRUCIBLE_IRON, R = 2.4 },
		{ Name = "CliffOutcropA", Kit = "CliffRockA", Scale = 0.58, Tint = CRUST, R = 4.8 },
		{ Name = "CliffOutcropB", Kit = "CliffRockB", Scale = 0.58, Tint = CRUST, R = 4.8 },
	}
	local rng = Random.new(25 * 7417)
	local extraPlaced = 0
	local extraTaken: { { number } } = {}
	for _, lm in InfernalFloor25.Landmarks do
		table.insert(extraTaken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
	end
	local function extraFree(x: number, z: number, r: number): boolean
		if math.abs(x - apex.X) < apex.Width / 2 + 8 and math.abs(z - apex.Z) < apex.Depth / 2 + 8 then
			return false
		end
		for _, t in extraTaken do
			if (t[1] - x) ^ 2 + (t[2] - z) ^ 2 < (t[3] + r) ^ 2 then
				return false
			end
		end
		for _, camp in ctx.layout.Camps do
			if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (36 + r) ^ 2 then
				return false
			end
		end
		return ctx.footprintClear(x, z, r + 1.2, r + 1.2)
	end
	for attempt = 1, 1100 do
		if extraPlaced >= 195 then break end
		local x = rng:NextNumber(-w / 2 + 24, w / 2 - 24)
		local z = rng:NextNumber(-d / 2 + 34, d / 2 - 70)
		local kind = extraKinds[(attempt - 1) % #extraKinds + 1]
		local gy, onDeck = surfaceAt(x, z)
		local dry = onDeck or not field or (field.Kind(x, z) ~= "POOL" and field.Slope(x, z) < 0.75)
		if dry and extraFree(x, z, kind.R) then
			table.insert(extraTaken, { x, z, kind.R })
			ctx.reserve(x, z, kind.R)
			local m = piece(kind.Name, x, z, rng:NextNumber(0, 360), kind.Kit, kind.Scale, kind.Tint, function(cf)
				fallbackHeap(cf, SLAG, Enum.Material.Basalt)
			end, if onDeck then gy else nil)
			noCollide(m)
			extraPlaced += 1
		end
	end
	props += extraPlaced

	ctx.setAttribute("Floor25Landmarks", landmarks)
	ctx.setAttribute("Floor25Props", props)
	ctx.setAttribute("Floor25GroundCover", cover)
end

return table.freeze(InfernalFloor25)
