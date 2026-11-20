--!strict
-- Hand-authored set pieces for Infernal Foundry Floor 24, Ironflame Bulwark
-- (docs/prompts/infernal-foundry-floor-layouts-prompt.md).
--
-- Inspired by the Ironflame Bulwark fortress art: two north-south lava channels cutting the cavern into three
-- iron-walled strips, The Pour boiling in front of the blazing Ironflame Gatehouse, twin sluice towers with
-- angled chain winches and iron portcullis gates barring the lava canals, slag cannons on the West Gun Deck,
-- powder kegs and a hoist in the Powder Store, a roaring signal fire tower on the Signal Bastion, colossal
-- steam drop-hammers under a vaulted arch in the Hammer Hall, siege ballistas and armour racks on the
-- battlements, ruined siege barricades in the Mustering Yard, the monumental Ironflame Citadel keep with its
-- hammer-ring doors crowning the north crag, and six molten lava falls pouring down the outer cavern walls.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local InfernalFloor24 = {}

local V = Vector3.new
local rgb = Color3.fromRGB

local C = InfernalFoundry.Colors
local IRON = C.IRON
local IRON_DARK = C.IRON_DARK
local BRICK = C.BRICK
local BRICK_DARK = C.BRICK_DARK
local BRASS = C.BRASS
local RUST = C.RUST
local TIMBER = C.TIMBER
local COAL = C.COAL
local SLAG = C.SLAG
local EMBER = C.EMBER
local LAMP = C.LAMP

local SOOT = InfernalFoundry.SOOT
local ORE_TINT = InfernalFoundry.ORE_TINT
local LAMP_TINT = InfernalFoundry.LAMP_TINT
local tinted = InfernalFoundry.Tinted

export type Landmark = InfernalFoundry.Landmark

-- Every Floor 24 landmark's scaled footprint (local floor space), checked offline by the specs against every
-- walkway lane, every camp (34-stud clearance), and the 715 x 810 room bounds.
InfernalFloor24.Landmarks = table.freeze({
	-- Monumental Ironflame Citadel keep & Hammer-Ring doors behind the Apex portals (scale 1.55x1.55x1.25 -> 141.8 studs tall).
	{ Id = "IronflameCitadel", X = 0, Z = -384, Y = 36, HalfX = 50.5, HalfZ = 15.5, Top = 141.8 },
	{ Id = "CitadelTurretWest", X = -82, Z = -376, Y = -4, HalfX = 15.1, HalfZ = 15.1, Top = 118.0 },
	{ Id = "CitadelTurretEast", X = 82, Z = -376, Y = -4, HalfX = 15.1, HalfZ = 15.1, Top = 118.0 },
	{ Id = "CitadelFlueWest", X = -126, Z = -386, Y = -4, HalfX = 9.9, HalfZ = 13.0, Top = 135.5 },
	{ Id = "CitadelFlueEast", X = 126, Z = -386, Y = -4, HalfX = 9.9, HalfZ = 13.0, Top = 135.5 },
	-- West & East Bulwark Tower Keeps standing just off the outer bastion flanks.
	{ Id = "WestBulwarkKeep", X = -302, Z = -190, Y = -4, HalfX = 17.0, HalfZ = 17.0, Top = 132.0 },
	{ Id = "EastBulwarkKeep", X = 302, Z = -300, Y = -4, HalfX = 17.8, HalfZ = 17.8, Top = 134.0 },
	-- Great Signal Fire Watchtower behind the dead-end Signal Bastion + Signal Brazier on the deck.
	{ Id = "SignalWatchtower", X = -230, Z = -366, Y = -4, HalfX = 16.0, HalfZ = 16.0, Top = 136.0 },
	{ Id = "SignalBastionBrazier", X = -230, Z = -327, Y = 32, HalfX = 8.4, HalfZ = 8.4, Top = 29.7 },
	{ Id = "SignalBastionBallista", X = -198, Z = -325, Y = 32, HalfX = 8.5, HalfZ = 8.5, Top = 7.4 },
	-- Ironflame Gatehouse (flame-jet portcullis overlooking The Pour) + flanking Gate Sluice Towers & Winches.
	{ Id = "IronflameGatehouse", X = 0, Z = 2, Y = 14, HalfX = 19.9, HalfZ = 6.0, Top = 31.9 },
	{ Id = "GateSluiceTowerW", X = -54, Z = 20, Y = -6, HalfX = 9.4, HalfZ = 9.4, Top = 50.8 },
	{ Id = "GateSluiceTowerE", X = 54, Z = 20, Y = -6, HalfX = 9.4, HalfZ = 9.4, Top = 50.8 },
	{ Id = "GateChainWinchW", X = -54, Z = 36, Y = -4, HalfX = 4.7, HalfZ = 4.7, Top = 16.5 },
	{ Id = "GateChainWinchE", X = 54, Z = 36, Y = -4, HalfX = 4.7, HalfZ = 4.7, Top = 16.5 },
	-- Sealed Flame-Jet Portcullis at the north back wall of Ironflame Forge + Forge Siege Ballista.
	{ Id = "ForgeFlamePortcullis", X = 0, Z = -196, Y = 20, HalfX = 19.9, HalfZ = 6.0, Top = 31.9 },
	{ Id = "ForgeBallista", X = -28, Z = -178, Y = 20, HalfX = 8.0, HalfZ = 8.0, Top = 7.2 },
	-- Twin Channel Sluice Towers standing in the West & East lava channels + Portcullis Channel Gates.
	{ Id = "WestSluiceTowerN", X = -115, Z = -58, Y = -6, HalfX = 9.4, HalfZ = 9.4, Top = 50.8 },
	{ Id = "WestSluiceGateS", X = -115, Z = 54, Y = -6, HalfX = 16.6, HalfZ = 2.0, Top = 23.1 },
	{ Id = "WestSluiceGateN", X = -115, Z = -116, Y = -6, HalfX = 16.6, HalfZ = 2.0, Top = 23.1 },
	{ Id = "EastSluiceTowerS", X = 115, Z = -14, Y = -6, HalfX = 9.4, HalfZ = 9.4, Top = 50.8 },
	{ Id = "EastSluiceTowerN", X = 115, Z = -126, Y = -6, HalfX = 9.4, HalfZ = 9.4, Top = 50.8 },
	{ Id = "EastSluiceGateS", X = 115, Z = 38, Y = -6, HalfX = 16.6, HalfZ = 2.0, Top = 23.1 },
	{ Id = "EastSluiceGateN", X = 115, Z = -182, Y = -6, HalfX = 16.6, HalfZ = 2.0, Top = 23.1 },
	-- West Gun Deck Slag Cannon battery (mounted along the outer west parapet, >= 36 studs from camp center).
	{ Id = "SlagCannonW1", X = -272, Z = 36, Y = 8, HalfX = 6.8, HalfZ = 3.8, Top = 9.4 },
	{ Id = "SlagCannonW2", X = -272, Z = 60, Y = 8, HalfX = 6.8, HalfZ = 3.8, Top = 9.4 },
	{ Id = "SlagCannonW3", X = -272, Z = 84, Y = 8, HalfX = 6.8, HalfZ = 3.8, Top = 9.4 },
	-- Powder Store munitions loft: Powder Keg Stacks + Jib Hoist on the west edge.
	{ Id = "PowderHoist", X = -261, Z = -50, Y = 16, HalfX = 4.0, HalfZ = 9.5, Top = 29.2 },
	{ Id = "PowderKegsN", X = -258, Z = -80, Y = 16, HalfX = 4.5, HalfZ = 3.5, Top = 7.2 },
	{ Id = "PowderKegsS", X = -202, Z = -78, Y = 16, HalfX = 4.5, HalfZ = 3.5, Top = 7.2 },
	-- Hammer Hall (East strip vaulted bay): Colossal Steam Drop-Hammers + Quench Tank.
	{ Id = "DropHammerN", X = 266, Z = -206, Y = 18, HalfX = 6.2, HalfZ = 8.2, Top = 44.2 },
	{ Id = "DropHammerS", X = 266, Z = -174, Y = 18, HalfX = 6.2, HalfZ = 8.2, Top = 44.2 },
	{ Id = "HammerHallQuench", X = 290, Z = -190, Y = -4, HalfX = 8.5, HalfZ = 12.0, Top = 30.0 },
	-- East Foundry Deck Slag Cannon + Bulwark Bastion Ballista.
	{ Id = "SlagCannonE1", X = 272, Z = -54, Y = 10, HalfX = 6.8, HalfZ = 3.8, Top = 9.4 },
	{ Id = "EastBastionBallista", X = 266, Z = -332, Y = 30, HalfX = 8.0, HalfZ = 8.0, Top = 7.2 },
	-- Mustering Yard ruined barricades & garrison armour racks along the Pour's southern edge (clear of Basin camps).
	{ Id = "YardBarricadeW", X = -36, Z = 160, Y = 0, HalfX = 7.8, HalfZ = 3.0, Top = 6.2 },
	{ Id = "YardBarricadeE", X = 58, Z = 156, Y = 0, HalfX = 7.8, HalfZ = 3.0, Top = 6.2 },
	{ Id = "YardArmouryW", X = -204, Z = 278, Y = 0, HalfX = 4.2, HalfZ = 2.0, Top = 8.8 },
	{ Id = "YardArmouryE", X = 204, Z = 278, Y = 0, HalfX = 4.2, HalfZ = 2.0, Top = 8.8 },
}) :: { Landmark }

function InfernalFloor24.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, w: number, d: number, P = H.field, H.bottom, ctx.w, H.d, H.P
	local surfaceAt, boxAt, rod, lump, light, plume, piece = H.surfaceAt, H.boxAt, H.rod, H.lump, H.light, H.plume, H.piece
	local glowOf, noCollide, fallbackStack, fallbackHeap, fallbackCart = H.glowOf, H.noCollide, H.fallbackStack, H.fallbackHeap, H.fallbackCart
	local landmarks, props, cover = 0, 0, 0

	local MOLTEN = tinted(SOOT, { GLOW = { Color = rgb(255, 168, 56), Material = Enum.Material.Neon } })
	local SIEGE_STONE = tinted(SOOT, {
		STONE = { Color = rgb(64, 58, 66), Material = Enum.Material.Brick },
		METAL = { Color = rgb(78, 76, 82), Material = Enum.Material.Metal },
		GLOW = { Color = rgb(255, 146, 48), Material = Enum.Material.Neon },
	})
	local CHARRED_WOOD = tinted(SOOT, {
		WOOD = { Color = rgb(52, 38, 30), Material = Enum.Material.Wood },
		MOSS = { Color = SLAG, Material = Enum.Material.Basalt },
		STEM = { Color = IRON_DARK, Material = Enum.Material.Metal },
	})
	local CRUST = tinted(SOOT, { ALT = { Color = rgb(32, 28, 32), Material = Enum.Material.Basalt }, STONE = { Color = rgb(50, 44, 48), Material = Enum.Material.Basalt } })
	local QUENCH = tinted(SOOT, { CRYSTAL = { Color = rgb(20, 26, 34), Material = Enum.Material.Glass, Transparency = 0.15 } })
	local lavaY = if field then field.LiquidLevel else bottom

	for _, lm in InfernalFloor24.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- Battered basalt-and-iron plinth rising out of the lava channels or chasm floor.
	local function plinth(x: number, z: number, halfX: number, halfZ: number, top: number)
		local b = bottom - 5
		local h = math.max(2, top - b)
		boxAt("BulwarkPlinthWall", V(halfX * 2, h, halfZ * 2), CFrame.new(x, b + h / 2, z), BRICK_DARK, Enum.Material.Brick)
		boxAt("BulwarkPlinthCap", V(halfX * 2 + 1.2, 1.1, halfZ * 2 + 1.2), CFrame.new(x, top - 0.5, z), IRON_DARK, Enum.Material.Metal)
	end

	-- Native fallbacks for all 12 Floor 24 templates (render cleanly even before FBX import).
	local function fallbackBulwark(cf: CFrame)
		boxAt("BulwarkBody", V(24, 9.5, 4.2), cf * CFrame.new(0, 4.75, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("BulwarkBand", V(24.4, 0.8, 4.6), cf * CFrame.new(0, 6.2, 0), IRON_DARK, Enum.Material.Metal)
		for _, mx in { -9, -3, 3, 9 } do
			boxAt("BulwarkMerlon", V(3.8, 3.0, 3.8), cf * CFrame.new(mx, 11.0, 0), BRICK, Enum.Material.Brick)
		end
	end
	local function fallbackSluiceTower(cf: CFrame, sx: number?, sy: number?)
		local sw, sh = sx or 1, sy or 1
		boxAt("SluiceTowerShaft", V(15 * sw, 44 * sh, 15 * sw), cf * CFrame.new(0, 22 * sh, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("SluiceTowerCrown", V(17.6 * sw, 3.6 * sh, 17.6 * sw), cf * CFrame.new(0, 45.5 * sh, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("SluiceTowerSlitGlow", V(1.6 * sw, 4.5 * sh, 0.4), cf * CFrame.new(0, 24 * sh, 7.6 * sw), EMBER, Enum.Material.Neon)
	end
	local function fallbackSluiceGate(cf: CFrame)
		boxAt("SluiceGateBeam", V(32, 2.2, 2.4), cf * CFrame.new(0, 20.8, 0), IRON_DARK, Enum.Material.Metal)
		for k = -5, 5 do
			boxAt("SluiceGateBar", V(0.7, 18, 0.7), cf * CFrame.new(k * 2.6, 10, 0), IRON, Enum.Material.Metal)
		end
	end
	local function fallbackCannon(cf: CFrame)
		boxAt("CannonCarriage", V(5.2, 3.8, 10.6), cf * CFrame.new(0, 2.8, 0), TIMBER, Enum.Material.Wood)
		local barrel = boxAt("CannonBarrel", V(13.8, 3.2, 3.2), cf * CFrame.new(0, 6.2, 1.5) * CFrame.Angles(math.rad(-9), math.pi / 2, 0), IRON_DARK, Enum.Material.Metal)
		barrel.Shape = Enum.PartType.Cylinder
		boxAt("CannonMuzzleGlow", V(1.6, 1.6, 0.4), cf * CFrame.new(0, 7.3, 8.6), EMBER, Enum.Material.Neon)
	end
	local function fallbackBrazier(cf: CFrame, s: number?)
		local sc = s or 1
		boxAt("BrazierPlinth", V(12 * sc, 10 * sc, 12 * sc), cf * CFrame.new(0, 5 * sc, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("BrazierBowl", V(15 * sc, 4.5 * sc, 15 * sc), cf * CFrame.new(0, 12.5 * sc, 0), IRON_DARK, Enum.Material.Metal)
		local fire = boxAt("BrazierFlameGlow", V(10 * sc, 11 * sc, 10 * sc), cf * CFrame.new(0, 20 * sc, 0), EMBER, Enum.Material.Neon)
		fire.CanCollide = false
	end
	local function fallbackDropHammer(cf: CFrame)
		boxAt("DropHammerAnvil", V(15, 6.5, 11), cf * CFrame.new(0, 3.25, 0), BRICK_DARK, Enum.Material.Brick)
		for _, sx in { -5.5, 5.5 } do
			boxAt("DropHammerCol", V(2.4, 30, 4.5), cf * CFrame.new(sx, 18, 0), IRON, Enum.Material.Metal)
		end
		boxAt("DropHammerCrown", V(14.5, 5, 6.5), cf * CFrame.new(0, 34, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("DropHammerTup", V(6.8, 6.4, 5.2), cf * CFrame.new(0, 18, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("DropHammerBilletGlow", V(4.4, 1.0, 2.2), cf * CFrame.new(0, 7.2, 0), EMBER, Enum.Material.Neon)
	end
	local function fallbackPowder(cf: CFrame)
		boxAt("PowderPallet", V(8.6, 0.6, 6.4), cf * CFrame.new(0, 0.3, 0), TIMBER, Enum.Material.Wood)
		for _, off in { { -2.2, -1.2 }, { 0, -1.2 }, { -1.1, 1.2 }, { 2.0, 0 } } do
			ctx.cyl("PowderKeg", (cf * CFrame.new(off[1], 2.2, off[2])).Position, 1.05, 3.4, TIMBER, Enum.Material.Wood)
		end
	end
	local function fallbackPortcullis(cf: CFrame)
		for _, sx in { -13.75, 13.75 } do
			boxAt("GatePier", V(10.5, 28, 10), cf * CFrame.new(sx, 14, 0), BRICK_DARK, Enum.Material.Brick)
		end
		boxAt("GateLintel", V(17.5, 12, 10), cf * CFrame.new(0, 22, 0), BRICK, Enum.Material.Brick)
		local flame = boxAt("GateFlameWallGlow", V(16, 14, 1.4), cf * CFrame.new(0, 7.2, 0), EMBER, Enum.Material.Neon)
		flame.CanCollide = false
	end
	local function fallbackWinch(cf: CFrame)
		for _, sx in { -3.4, 3.4 } do
			boxAt("WinchFrame", V(1.2, 8.8, 2.0), cf * CFrame.new(sx, 4.4, 0), IRON_DARK, Enum.Material.Metal)
		end
		local drum = boxAt("WinchDrum", V(6.6, 3.4, 3.4), cf * CFrame.new(0, 4.4, 0), IRON, Enum.Material.Metal)
		drum.Shape = Enum.PartType.Cylinder
	end
	local function fallbackBallista(cf: CFrame)
		boxAt("BallistaBase", V(6.4, 4.2, 6.4), cf * CFrame.new(0, 2.1, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("BallistaStock", V(2.0, 1.4, 14.2), cf * CFrame.new(0, 5.4, 0), TIMBER, Enum.Material.Wood)
		boxAt("BallistaBow", V(18.0, 1.4, 1.4), cf * CFrame.new(0, 5.6, 4.2), TIMBER, Enum.Material.Wood)
	end
	local function fallbackArmour(cf: CFrame)
		boxAt("ArmourStand", V(7.6, 8.2, 1.0), cf * CFrame.new(0, 4.1, 0), TIMBER, Enum.Material.Wood)
		boxAt("ArmourCuirass", V(2.4, 3.2, 1.4), cf * CFrame.new(-1.2, 5.0, 0.4), IRON, Enum.Material.Metal)
		boxAt("ArmourShield", V(2.4, 4.8, 0.5), cf * CFrame.new(1.6, 3.0, 0.4), IRON_DARK, Enum.Material.Metal)
	end
	local function fallbackCitadel(cf: CFrame, sx: number, sy: number, sz: number)
		for _, side in { -1, 1 } do
			boxAt("CitadelTurret", V(15 * sx, 80 * sy, 18 * sz), cf * CFrame.new(side * 24.5 * sx, 40 * sy, 0), BRICK_DARK, Enum.Material.Brick)
			local fire = boxAt("CitadelTurretFlameGlow", V(5 * sx, 8 * sy, 5 * sz), cf * CFrame.new(side * 24.5 * sx, 84 * sy, 0), EMBER, Enum.Material.Neon)
			fire.CanCollide = false
		end
		boxAt("CitadelKeepWall", V(36 * sx, 68 * sy, 16 * sz), cf * CFrame.new(0, 34 * sy, 0), BRICK, Enum.Material.Brick)
		boxAt("CitadelDoorLeaves", V(27 * sx, 46 * sy, 2.5 * sz), cf * CFrame.new(0, 23 * sy, 8 * sz), IRON_DARK, Enum.Material.Metal)
		local ring = ctx.ring("CitadelHammerRing", (cf * CFrame.new(0, 26 * sy, 9.6 * sz)).Position, 9.6 * sx, 1.6 * sx, BRASS, Enum.Material.Metal)
		ring.CFrame = cf * CFrame.new(0, 26 * sy, 9.6 * sz)
		boxAt("CitadelDoorSeamGlow", V(1.2 * sx, 44 * sy, 0.8), cf * CFrame.new(0, 23 * sy, 9.2 * sz), EMBER, Enum.Material.Neon)
	end
	local function fallbackAnvil(cf: CFrame)
		boxAt("AnvilBlock", V(4.2, 2.0, 3.4), cf * CFrame.new(0, 1.0, 0), TIMBER, Enum.Material.Wood)
		boxAt("AnvilBody", V(4.8, 1.8, 2.4), cf * CFrame.new(0, 2.9, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("AnvilHorn", V(2.0, 1.0, 1.4), cf * CFrame.new(3.0, 3.2, 0), IRON, Enum.Material.Metal)
	end
	local function fallbackBarricade(cf: CFrame)
		boxAt("BarricadeLog", V(14.5, 1.4, 1.4), cf * CFrame.new(0, 2.4, 0), TIMBER, Enum.Material.Wood)
		for k = -2, 2 do
			local stake = boxAt("BarricadeStake", V(0.7, 6.2, 0.7), cf * CFrame.new(k * 2.8, 2.8, 0) * CFrame.Angles(math.rad(-28), 0, 0), TIMBER, Enum.Material.Wood)
			stake.CanCollide = false
		end
	end

	-- =====================================================================================================
	-- 1. Ironflame Citadel Keep & Monumental Hammer-Ring Doors (Apex north backdrop, 141.8 studs tall)
	-- =====================================================================================================
	local apex = P.Apex
	ctx.group("IronflameCitadel", function()
		local cf = CFrame.new(0, apex.Y, -384)
		if ctx.has("CitadelDoors") then
			local mdl = ctx.kitAt("CitadelDoors", cf, V(1.55, 1.55, 1.25), SIEGE_STONE)
			local g = glowOf(mdl)
			if g then light(g, EMBER, 2.2, 90) end
		else
			fallbackCitadel(cf, 1.55, 1.55, 1.25)
		end
		-- Massive rocky bastion plinth anchoring the keep down into the north cliff.
		plinth(0, -384, 52, 16, apex.Y)
		-- Flanking threshold braziers with point lights at the Citadel steps.
		for _, sx in { -1, 1 } do
			local b = boxAt("CitadelStepBrazierGlow", V(3.6, 3.6, 3.6), CFrame.new(sx * 28, apex.Y + 12, -366), EMBER, Enum.Material.Neon)
			b.CanCollide = false
			light(b, EMBER, 1.8, 60)
		end
	end)
	-- Twin Citadel Flanking Bastion Turrets + Smoking Rear Flue Stacks.
	for _, sx in { -1, 1 } do
		plinth(sx * 82, -376, 16, 16, 22)
		ctx.group("CitadelTurret", function()
			ctx.tag("OnTerrain", true)
			local cf = CFrame.new(sx * 82, 22, -376)
			if ctx.has("SluiceTower") then
				ctx.kitAt("SluiceTower", cf, V(1.6, 1.85, 1.6), SIEGE_STONE)
			else
				fallbackSluiceTower(cf, 1.6, 1.85)
			end
		end)
		piece("CitadelTurretBrazier", sx * 82, -376, 0, "SignalBrazier", 0.6, MOLTEN, function(cf) fallbackBrazier(cf, 0.6) end, 114)
		piece("CitadelFlueStack", sx * 126, -386, 0, "FlueStack", 1.35, SOOT, function(cf) fallbackStack(cf, 1.35) end, -4)
		plume(V(sx * 126, 133, -386), rgb(52, 46, 52), 14, 3, 7, 10)
	end
	landmarks += 2
	props += 7

	-- =====================================================================================================
	-- 2. West & East Bulwark Tower Keeps + Great Signal Fire Watchtower (the iconic flaming left tower!)
	-- =====================================================================================================
	plinth(-302, -190, 17, 17, 10)
	ctx.group("WestBulwarkKeep", function()
		ctx.tag("OnTerrain", true)
		local cf = CFrame.new(-302, 10, -190) * CFrame.Angles(0, math.rad(90), 0)
		if ctx.has("SluiceTower") then
			ctx.kitAt("SluiceTower", cf, V(1.8, 2.1, 1.8), SIEGE_STONE)
		else
			fallbackSluiceTower(cf, 1.8, 2.1)
		end
	end)
	local wbBrazier = piece("WestBulwarkBrazier", -302, -190, 0, "SignalBrazier", 0.72, MOLTEN, function(cf) fallbackBrazier(cf, 0.72) end, 116)
	local wbGlow = glowOf(wbBrazier)
	if wbGlow then light(wbGlow, EMBER, 1.6, 70) end

	plinth(302, -300, 18, 18, 12)
	ctx.group("EastBulwarkKeep", function()
		ctx.tag("OnTerrain", true)
		local cf = CFrame.new(302, 12, -300) * CFrame.Angles(0, math.rad(-90), 0)
		if ctx.has("SluiceTower") then
			ctx.kitAt("SluiceTower", cf, V(1.88, 2.25, 1.88), SIEGE_STONE)
		else
			fallbackSluiceTower(cf, 1.88, 2.25)
		end
	end)
	local ebBrazier = piece("EastBulwarkBrazier", 302, -300, 0, "SignalBrazier", 0.72, MOLTEN, function(cf) fallbackBrazier(cf, 0.72) end, 125)
	local ebGlow = glowOf(ebBrazier)
	if ebGlow then light(ebGlow, EMBER, 1.6, 70) end

	-- Signal Bastion: roaring deck beacon + colossal watchtower directly behind it with billowing smoke plume!
	local sigDeck = P.SignalBastion
	local deckBeacon = piece("SignalBastionBrazier", -230, -327, 0, "SignalBrazier", 1.0, MOLTEN, function(cf) fallbackBrazier(cf, 1.0) end, sigDeck.Y)
	local sbGlow = glowOf(deckBeacon)
	if sbGlow then light(sbGlow, rgb(255, 160, 50), 2.2, 72) end
	plume(V(-230, sigDeck.Y + 26, -327), EMBER, 3.0, 10, 9, 2.0)

	plinth(-230, -366, 16, 16, 16)
	ctx.group("SignalWatchtower", function()
		ctx.tag("OnTerrain", true)
		local cf = CFrame.new(-230, 16, -366)
		if ctx.has("SluiceTower") then
			ctx.kitAt("SluiceTower", cf, V(1.65, 1.9, 1.65), SIEGE_STONE)
		else
			fallbackSluiceTower(cf, 1.65, 1.9)
		end
	end)
	piece("SignalTowerFire", -230, -366, 0, "SignalBrazier", 0.95, MOLTEN, function(cf) fallbackBrazier(cf, 0.95) end, 112)
	-- Giant billowing smoke column rising from the Signal Watchtower (signature silhouette in the reference art!).
	plume(V(-230, 138, -366), rgb(78, 72, 74), 16, 4, 8, 10)
	piece("SignalBastionBallista", -198, -325, 115, "SiegeBallista", 0.85, SOOT, fallbackBallista, sigDeck.Y)
	landmarks += 3
	props += 8

	-- =====================================================================================================
	-- 3. Ironflame Gatehouse (Flame-Jet Portcullis overlooking The Pour) + Twin Gate Sluice Towers & Winches
	-- =====================================================================================================
	local cr = P.Crossing
	local gatehouse = piece("IronflameGatehouse", 0, 2, 0, "FlameJetPortcullis", 1.0, MOLTEN, fallbackPortcullis, cr.Y)
	local gateGlow = glowOf(gatehouse)
	if gateGlow then light(gateGlow, rgb(255, 148, 42), 2.4, 78) end
	plume(V(0, cr.Y + 7, 4), rgb(255, 152, 46), 3.6, 10, 8, 1.6)

	for _, sx in { -1, 1 } do
		plinth(sx * 54, 20, 10, 10, -6)
		piece("GateSluiceTower", sx * 54, 20, 0, "SluiceTower", 1.0, SIEGE_STONE, fallbackSluiceTower, -6)
		plinth(sx * 54, 36, 5.2, 5.2, -4)
		piece("GateChainWinch", sx * 54, 36, 0, "ChainWinch", 1.0, SOOT, fallbackWinch, -4)
		-- Flanking threshold braziers on the gatehouse cheeks.
		piece("GateWatchBrazier", sx * 24, 4, 0, "SignalBrazier", 0.32, MOLTEN, function(cf) fallbackBrazier(cf, 0.32) end, cr.Y)
	end
	landmarks += 3
	props += 7

	-- =====================================================================================================
	-- 4. Sealed Ironflame Forge (dead-end north of the Gate) + Stepped Citadel Cliff Buttress behind it
	-- =====================================================================================================
	local forge = P.IronflameForge
	local forgeGate = piece("ForgeFlamePortcullis", 0, -196, 0, "FlameJetPortcullis", 1.0, MOLTEN, fallbackPortcullis, forge.Y)
	local fgGlow = glowOf(forgeGate)
	if fgGlow then light(fgGlow, rgb(255, 142, 38), 2.0, 66) end
	plume(V(0, forge.Y + 6, -192), rgb(255, 150, 48), 3.0, 8, 8, 1.5)
	piece("ForgeBallista", -28, -178, -35, "SiegeBallista", 0.82, SOOT, fallbackBallista, forge.Y)
	-- Heavy forging anvils, cooling racks, and armour stands inside the sealed forge.
	for _, spot in { { -28, -150 }, { 28, -150 }, { 28, -176 } } do
		ctx.group("ForgeAnvil", function()
			fallbackAnvil(CFrame.new(spot[1], forge.Y, spot[2]) * CFrame.Angles(0, math.rad(spot[1] < 0 and 90 or -90), 0))
		end)
	end
	piece("ForgeCoolingRack", 30, -162, -90, "CoolingRack", 0.9, MOLTEN, nil, forge.Y)
	piece("ForgeArmour", -32, -138, 90, "ArmourRack", 1.0, SOOT, fallbackArmour, forge.Y)
	piece("ForgeArmour", 32, -138, -90, "ArmourRack", 1.0, SOOT, fallbackArmour, forge.Y)
	landmarks += 2
	props += 10

	-- =====================================================================================================
	-- 5. Twin Channel Sluice Towers & Portcullis Channel Gates barring both Lava Channels
	-- =====================================================================================================
	-- West lava channel (X = -115): sluice tower north of WestSluice + spiked iron portcullis gates north & south.
	plinth(-115, -58, 10, 10, -6)
	piece("WestSluiceTowerN", -115, -58, 0, "SluiceTower", 1.0, SIEGE_STONE, fallbackSluiceTower, -6)
	piece("WestSluiceGateS", -115, 54, 0, "SluiceGateChain", 1.0, SOOT, fallbackSluiceGate, -6)
	piece("WestSluiceGateN", -115, -116, 0, "SluiceGateChain", 1.0, SOOT, fallbackSluiceGate, -6)
	-- East lava channel (X = +115): twin sluice towers flanking EastSluice + spiked portcullis gates north & south.
	plinth(115, -14, 10, 10, -6)
	piece("EastSluiceTowerS", 115, -14, 0, "SluiceTower", 1.0, SIEGE_STONE, fallbackSluiceTower, -6)
	plinth(115, -126, 10, 10, -6)
	piece("EastSluiceTowerN", 115, -126, 0, "SluiceTower", 1.0, SIEGE_STONE, fallbackSluiceTower, -6)
	piece("EastSluiceGateS", 115, 38, 0, "SluiceGateChain", 1.0, SOOT, fallbackSluiceGate, -6)
	piece("EastSluiceGateN", 115, -182, 0, "SluiceGateChain", 1.0, SOOT, fallbackSluiceGate, -6)
	-- Chain winches on the free edges of WestSluice & EastSluice decks.
	piece("WestSluiceWinch", -115, -26, 180, "ChainWinch", 0.55, SOOT, fallbackWinch, P.WestSluice.Y)
	piece("EastSluiceWinch", 115, -86, 180, "ChainWinch", 0.55, SOOT, fallbackWinch, P.EastSluice.Y)
	landmarks += 2
	props += 9

	-- =====================================================================================================
	-- 6. The Pour (molten pit south of Ironflame Gate) + Anchored Spillway Chute + Invisible Lava Lights
	-- =====================================================================================================
	ctx.group("ThePourChute", function()
		ctx.tag("OnTerrain", true)
		-- Solid basalt-and-iron spillway buttress anchored from under Ironflame Gate (Y=14) down into the lava bed.
		plinth(0, 10, 8.5, 6.5, 11.5)
		for _, sx in { -5.4, 5.4 } do
			local pierH = math.max(4, 5.8 - (bottom - 5))
			boxAt("PourChutePier", V(2.2, pierH, 2.8), CFrame.new(sx, (bottom - 5) + pierH / 2, 22), IRON_DARK, Enum.Material.Metal)
		end
		-- Iron spillway trough sloping DOWNWARD (+22 deg around X slopes +Z down) from the headwall toward The Pour.
		local chuteCF = CFrame.new(0, 8.2, 16) * CFrame.Angles(math.rad(22), 0, 0)
		boxAt("PourChuteTrough", V(11.6, 2.0, 20), chuteCF, IRON_DARK, Enum.Material.Metal)
		for _, sx in { -5.4, 5.4 } do
			boxAt("PourChuteWall", V(1.3, 3.6, 20.4), chuteCF * CFrame.new(sx, 1.7, 0), IRON, Enum.Material.Metal)
			boxAt("PourChuteBand", V(1.6, 4.0, 1.2), chuteCF * CFrame.new(sx, 1.7, 8.2), BRASS, Enum.Material.Metal)
		end
		-- Continuous molten magma stream flowing down the chute and arching smoothly into The Pour's lava surface.
		local lipPos = (chuteCF * CFrame.new(0, 0.9, 9.6)).Position
		local stream = boxAt("PourMagmaStreamGlowSeam", V(8.6, 0.9, 19.6), chuteCF * CFrame.new(0, 0.9, 0.2), rgb(255, 168, 52), Enum.Material.Neon)
		stream.CanCollide = false
		stream.CanQuery = false
		local arcPts = {
			lipPos,
			V(0, lipPos.Y - 1.2, lipPos.Z + 3.2),
			V(0, (lipPos.Y + lavaY) * 0.5, lipPos.Z + 5.6),
			V(0, lavaY - 0.8, lipPos.Z + 7.2),
		}
		for k = 1, #arcPts - 1 do
			local p0, p1 = arcPts[k], arcPts[k + 1]
			local segLen = (p1 - p0).Magnitude + 0.8
			local wSeg = 8.4 - k * 0.7
			local seg = boxAt("PourCascadeGlowSeam", V(wSeg, 1.8, segLen), CFrame.lookAt((p0 + p1) / 2, p1), rgb(255, 178, 64), Enum.Material.Neon)
			seg.CanCollide = false
			seg.CanQuery = false
		end
		-- Circular molten splash pool & bright ripples where the spillway hits The Pour (never a square sheet).
		local splashZ = lipPos.Z + 7.4
		local splash = ctx.cyl("PourSplashGlowSeam", V(0, lavaY + 0.15, splashZ), 8.5, 0.35, rgb(255, 194, 86), Enum.Material.Neon)
		splash.CanCollide = false
		splash.CanQuery = false
		light(splash, EMBER, 2.4, 82)
		-- Invisible point-light anchors over The Pour & both lava channels so the CrackedLava terrain glows naturally
		-- with zero flat orange boxes sitting on top of the lava.
		for _, spot in { { 0, 86 }, { -115, -4 }, { 115, -66 } } do
			local g = boxAt("PourLavaLightAnchor", V(2, 2, 2), CFrame.new(spot[1], lavaY + 3.5, spot[2]), EMBER, Enum.Material.SmoothPlastic, 1)
			g.CanCollide = false
			g.CanQuery = false
			light(g, EMBER, 2.0, 72)
		end
	end)
	plume(V(0, lavaY + 1.5, 33), rgb(255, 168, 62), 4.2, 10, 8, 2.0)
	plume(V(0, lavaY + 2, 92), rgb(90, 68, 62), 9, 4, 4, 6)
	plume(V(-115, lavaY + 1.5, 22), EMBER, 1.4, 7, 6, 2.4)
	plume(V(115, lavaY + 1.5, -36), EMBER, 1.4, 7, 6, 2.4)
	-- Cooled volcanic crust floes drifting in The Pour & lava channels.
	local floeCount = 0
	for k, spot in {
		{ -34, 78 }, { 36, 92 }, { -16, 114 }, { 22, 64 },
		{ -115, 92 }, { -115, -86 }, { -115, -168 }, { -115, -242 },
		{ 115, 84 }, { 115, -152 }, { 115, -238 }, { 115, -296 },
	} do
		local m = piece("CrustFloe", spot[1], spot[2], k * 47, "CrustIsland", 0.72 + (k % 3) * 0.14, CRUST, function(cf)
			lump("CrustSlab", (cf * CFrame.new(0, 0.4, 0)).Position, V(12, 1.4, 9), SLAG, Enum.Material.Basalt)
		end, lavaY - 0.15)
		noCollide(m)
		floeCount += 1
	end
	landmarks += 1
	props += floeCount + 1

	-- =====================================================================================================
	-- 7. West Gun Deck (Slag Cannons & Bulwarks) + Powder Store (Powder Kegs & Munitions Hoist)
	-- =====================================================================================================
	local wg = P.WestGallery
	for _, z in { 36, 60, 84 } do
		piece("SlagCannon", -272, z, 90, "SlagCannon", 0.86, MOLTEN, fallbackCannon, wg.Y)
	end
	-- Bulwark parapets lining the strips overlooking both lava channels (strictly off links & camps).
	local bulwarkSpots = {
		-- West strip outer & channel parapets
		{ -275, -190, 90, P.WestBastion.Y, 0.9 },
		{ -194, -190, -90, P.WestBastion.Y, 0.85 },
		{ -268, -310, 90, P.SignalBastion.Y, 0.9 },
		{ -192, -304, -90, P.SignalBastion.Y, 0.8 },
		-- East strip channel & outer parapets
		{ 274, -80, -90, P.EastGallery.Y, 0.9 },
		{ 230, -40, 0, P.EastGallery.Y, 1.0 },
		{ 192, -190, 90, P.HammerHall.Y, 1.0 },
		{ 188, -300, 90, P.EastBastion.Y, 0.9 },
		{ 274, -300, -90, P.EastBastion.Y, 0.9 },
	}
	for _, b in bulwarkSpots do
		piece("BulwarkWall", b[1], b[2], b[3], "BulwarkWall", b[5], SIEGE_STONE, fallbackBulwark, b[4])
	end

	local ps = P.PowderStore
	piece("PowderHoist", -261, -50, 90, "JibCrane", 0.9, SOOT, function(cf)
		boxAt("PowderHoistMast", V(2.4, 24, 2.4), cf * CFrame.new(0, 12, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("PowderHoistBoom", V(1.0, 1.0, 14), cf * CFrame.new(0, 23, 6), IRON, Enum.Material.Metal)
	end, ps.Y)
	for _, spot in { { -258, -80, 15 }, { -258, -64, -10 }, { -202, -78, 170 }, { -202, -52, 195 } } do
		piece("PowderKegStack", spot[1], spot[2], spot[3], "PowderKegStack", 0.95, SOOT, fallbackPowder, ps.Y)
	end
	landmarks += 2
	props += 8 + #bulwarkSpots

	-- =====================================================================================================
	-- 8. Hammer Hall (Vaulted Industrial Forge Bay with Colossal Drop-Hammers) + East Strip Defences
	-- =====================================================================================================
	local hh = P.HammerHall
	for k, z in { -206, -174 } do
		local hammer = piece("DropHammer", 266, z, -90, "DropHammer", 1.0, MOLTEN, fallbackDropHammer, hh.Y)
		local hg = glowOf(hammer)
		if hg then light(hg, EMBER, 1.5, 44) end
		plume(V(262, hh.Y + 6, z), rgb(216, 214, 220), 6.5, 4, 4, 5.5)
		ctx.group("HammerHallAnvil", function()
			fallbackAnvil(CFrame.new(254, hh.Y, z + (if k == 1 then 10 else -10)))
		end)
	end
	-- Vaulted forge bay hood framing the east side of Hammer Hall (matches the huge right archway in the image!).
	ctx.group("HammerHallVaultBay", function()
		ctx.tag("OnTerrain", true)
		local bx = 286
		for _, pz in { -224, -190, -156 } do
			boxAt("VaultBayPier", V(12, 68, 10), CFrame.new(bx, hh.Y + 28, pz), BRICK_DARK, Enum.Material.Brick)
		end
		boxAt("VaultBayRoof", V(28, 7, 82), CFrame.new(bx - 6, hh.Y + 63, -190), IRON_DARK, Enum.Material.Metal)
		boxAt("VaultBayParapet", V(3, 5, 82), CFrame.new(bx - 18, hh.Y + 69, -190), BRICK, Enum.Material.Brick)
		-- Overhead heavy forge chains hanging from the vaulted bay crown.
		for _, cz in { -206, -190, -174 } do
			local ch = rod("VaultBayChain", V(272, hh.Y + 60, cz), V(272, hh.Y + 34, cz), 0.45, IRON_DARK, Enum.Material.Metal)
			ch.CanCollide = false
		end
	end)
	-- Roof-mounted siege ballista overlooking the chasm atop the Hammer Hall vault roof (reference art right wall!).
	piece("HammerHallRoofBallista", 276, -190, -90, "SiegeBallista", 1.0, SOOT, fallbackBallista, hh.Y + 66.5)
	plinth(290, -190, 9, 12, hh.Y - 4)
	piece("HammerHallQuench", 290, -190, 90, "QuenchTank", 0.72, QUENCH, function(cf)
		boxAt("HammerQuenchBody", V(16, 4, 10), cf * CFrame.new(0, 2, 0), IRON_DARK, Enum.Material.Metal)
	end, hh.Y - 4)
	piece("SlagCannon", 272, -54, -90, "SlagCannon", 0.86, MOLTEN, fallbackCannon, P.EastGallery.Y)
	piece("EastBastionBallista", 266, -332, -135, "SiegeBallista", 0.82, SOOT, fallbackBallista, P.EastBastion.Y)
	landmarks += 2
	props += 9

	-- =====================================================================================================
	-- 9. Mustering Yard (Ruined Siege Barricades & Garrison Armour Racks — foreground of the reference art!)
	-- =====================================================================================================
	local yard = P.Basin
	local barricadeSpots = {
		{ -36, 160, 12 }, { 58, 156, -14 },
		{ -168, 176, 22 }, { 86, 162, -26 },
		{ -208, 184, 32 }, { 148, 174, -18 },
		{ -248, 198, 26 }, { 208, 184, -30 },
		{ -178, 276, -10 }, { 178, 276, 12 },
		{ -248, 266, 22 }, { 248, 266, -24 },
	}
	for _, b in barricadeSpots do
		local m = piece("RuinedBarricade", b[1], b[2], b[3], "Barricade", 0.92, CHARRED_WOOD, fallbackBarricade, yard.Y)
		noCollide(m)
	end
	for _, spot in { { -204, 278, 180 }, { 204, 278, 180 }, { -270, 224, 90 }, { 270, 224, -90 } } do
		piece("GarrisonArmourRack", spot[1], spot[2], spot[3], "ArmourRack", 1.0, SOOT, fallbackArmour, yard.Y)
	end
	-- Garrison supply wagons, ore carts, signal cabin, and blade displays framing the outer Mustering Yard.
	piece("YardGuardCabin", 268, 274, -135, "SignalCabin", 1.0, LAMP_TINT, H.fallbackCabin, yard.Y)
	piece("YardOreCart", -276, 258, 40, "OreCart", 1.0, ORE_TINT, fallbackCart, yard.Y)
	piece("YardOreCart", 276, 252, -35, "OreCart", 1.0, SOOT, fallbackCart, yard.Y)
	piece("YardBladeDisplay", -186, 284, 180, "BladeDisplay", 1.0, SOOT, nil, yard.Y)
	piece("YardBladeDisplay", 186, 284, 180, "BladeDisplay", 1.0, SOOT, nil, yard.Y)
	landmarks += 1
	props += #barricadeSpots + 9

	-- =====================================================================================================
	-- 10. Far Backdrop: Outer Volcanic Cavern Walls, Six Molten Lava Falls, and Cavern Roof Ribs
	-- =====================================================================================================
	local lavaFallSpots = {
		{ -344, -120, 90, 126, 14 },
		{ -344, -280, 90, 138, 14 },
		{ 344, -60, -90, 126, 14 },
		{ 344, -260, -90, 138, 14 },
		{ -135, -392, 0, 148, 18 },
		{ 135, -392, 0, 148, 18 },
	}
	for k, f in lavaFallSpots do
		ctx.group("LavaFallCascade", function()
			ctx.tag("OnTerrain", true)
			local fx, fz, yaw, fh, fw = f[1], f[2], f[3], f[4], f[5]
			local cf = CFrame.new(fx, bottom + fh / 2, fz) * CFrame.Angles(0, math.rad(yaw), 0)
			local sheet = boxAt("LavaFallCurtainGlowSeam", V(fw, fh, 3.2), cf, rgb(255, 132, 34), Enum.Material.Neon)
			sheet.CanCollide = false
			sheet.CanQuery = false
			local core = boxAt("LavaFallCoreGlowSeam", V(fw * 0.45, fh, 3.8), cf * CFrame.new(0, 0, 0.5), rgb(255, 210, 96), Enum.Material.Neon)
			core.CanCollide = false
			core.CanQuery = false
			if k <= 4 then
				light(core, EMBER, 1.5, 64)
			end
		end)
		if k >= 5 then
			plume(V(f[1], lavaY + 4, f[2] + 10), rgb(255, 160, 62), 6, 6, 8, 2.5)
		end
	end
	-- Distant furnace towers & bellows ducts banking the outer volcanic cavern perimeter.
	for _, spot in { { -312, 8, 90 }, { 312, 30, -90 }, { -310, -104, 90 }, { 310, -128, -90 } } do
		piece("OuterFurnaceTower", spot[1], spot[2], spot[3], "FurnaceTower", 1.15, SIEGE_STONE, function(cf)
			boxAt("OuterTowerShaft", V(18, 56, 18), cf * CFrame.new(0, 28, 0), BRICK_DARK, Enum.Material.Brick)
		end, -4)
	end
	for _, spot in { { -286, -65, 90 }, { 286, -135, -90 }, { -286, -250, 90 }, { 286, -245, -90 } } do
		piece("WallBellowsDuct", spot[1], spot[2], spot[3], "BellowsDuctRun", 1.1, SOOT, nil, -4)
	end
	-- Dark volcanic cavern ribs framing the upper rock ceiling (evokes the dark cavern overhang in the art).
	ctx.group("CavernCeilingArch", function()
		ctx.tag("OnTerrain", true)
		local ceilY = ctx.h - 14
		for _, z in { -310, -170, -30, 110 } do
			for _, sx in { -1, 1 } do
				local p0 = V(sx * (w / 2 - 8), ceilY - 62, z)
				local p1 = V(sx * (w * 0.28), ceilY, z)
				local rib = rod("CavernStalactiteRib", p0, p1, 6.5, rgb(34, 30, 36), Enum.Material.Basalt)
				rib.CanCollide = false
				rib.CanQuery = false
			end
		end
	end)
	landmarks += 2
	props += #lavaFallSpots + 8

	-- =====================================================================================================
	-- 11. Rich Multi-Template Siege & Foundry Prop Pass + Ground Cover (hits Floor 24's ≥450 / ≥300 ladder)
	-- =====================================================================================================
	local clutter, groundCover = H.workClutter(InfernalFloor24.Landmarks, 24, 58, 380)
	props += clutter
	cover += groundCover

	-- Extra varied fortress props (reusing 16+ distinct kit templates across terraces, yard & dry banks so
	-- distinct templates >= 25 and no single template exceeds 12% of placed props).
	local extraKinds = {
		{ Name = "SiegeBarricade", Kit = "Barricade", Scale = 0.65, Tint = CHARRED_WOOD, R = 4.5 },
		{ Name = "RuinDebris", Kit = "RuinRubble", Scale = 0.75, Tint = CRUST, R = 4.0 },
		{ Name = "KegCluster", Kit = "PowderKegStack", Scale = 0.7, Tint = SOOT, R = 3.4 },
		{ Name = "GarrisonRack", Kit = "ArmourRack", Scale = 0.75, Tint = SOOT, R = 3.2 },
		{ Name = "SteamRelief", Kit = "SteamVent", Scale = 0.85, Tint = SOOT, R = 2.6 },
		{ Name = "WeaponRack", Kit = "BladeDisplay", Scale = 0.8, Tint = SOOT, R = 3.0 },
		{ Name = "PartsStand", Kit = "PartsRack", Scale = 0.75, Tint = SOOT, R = 3.6 },
		{ Name = "IronScrap", Kit = "ScrapHeap", Scale = 0.6, Tint = SOOT, R = 4.6 },
		{ Name = "FoundryCauldron", Kit = "MessCauldron", Scale = 0.8, Tint = SOOT, R = 3.2 },
		{ Name = "BasaltUrn", Kit = "StoneUrn", Scale = 0.9, Tint = SIEGE_STONE, R = 2.4 },
		{ Name = "GearWheel", Kit = "WallGear", Scale = 0.25, Tint = SOOT, R = 3.4 },
		{ Name = "WatchLamp", Kit = "SignalLamp", Scale = 0.95, Tint = LAMP_TINT, R = 1.8 },
		{ Name = "CliffOutcropA", Kit = "CliffRockA", Scale = 0.55, Tint = CRUST, R = 4.8 },
		{ Name = "CliffOutcropB", Kit = "CliffRockB", Scale = 0.55, Tint = CRUST, R = 4.8 },
		{ Name = "CoolingBlades", Kit = "CoolingRack", Scale = 0.65, Tint = MOLTEN, R = 3.4 },
		{ Name = "CoalMound", Kit = "CoalHeap", Scale = 0.55, Tint = SOOT, R = 3.8 },
	}
	local rng = Random.new(24 * 6133)
	local extraPlaced = 0
	local extraTaken: { { number } } = {}
	for _, lm in InfernalFloor24.Landmarks do
		table.insert(extraTaken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
	end
	local function extraFree(x: number, z: number, r: number): boolean
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
	for attempt = 1, 900 do
		if extraPlaced >= 160 then break end
		local x = rng:NextNumber(-w / 2 + 24, w / 2 - 24)
		local z = rng:NextNumber(-d / 2 + 30, d / 2 - 70)
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

	ctx.setAttribute("Floor24Landmarks", landmarks)
	ctx.setAttribute("Floor24Props", props)
	ctx.setAttribute("Floor24GroundCover", cover)
end

return table.freeze(InfernalFloor24)
