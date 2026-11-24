--!strict
-- Hand-authored set pieces for Sunken Sanctuary Floor 39: Pearlguard Vault (sunken:4).
-- Guide image: reference/Sunken Sanctuary 39.jpg. Design: docs/prompts/sunken-sanctuary-floor-layouts-prompt.md.
--
-- The Pearlguard's fortified two-wall harbour fortress under deep blue coastal twilight lit by warm pearl-white
-- glow from the Pearl Vault dome:
--   * Outer harbour strand & Divers' Wharf (bronze diving bell, barnacled pilings, coiled ropes, moored galleys,
--     harbour chain-boom) fronting the mossy Outer Sea-Wall and its single off-centre Sea Gate (scallop-pediment
--     raised bronze portcullis with muffled-bell barricades).
--   * Outer ward: striped-awning Pearl Market, Muster Yard with glaive racks & muffled-bell stacks facing the
--     bricked-up Drowned Gate, Oyster Pearl Beds over water, and Harbour Ward with its timber jib crane.
--   * Inner Sea-Wall crowned by the crenellated Wall-Walk (`BridgeStyles = "WALLWALK"`) linking the coral-draped
--     Coral Gate Tower (west) and the armillary-crowned Tide Tower (east).
--   * Inner ward: Wardens' Hall (aqua flame hearth & banners), Shell Chapel (oath stone & shell shrine),
--     Pearl Cistern (coral-crusted urns), Vault Stair (paired Coral Warden guardians), Reliquary (Coral Abyss Core),
--     East Rampart, and the back-east Pearl Vault crowned by the 218-stud verdigris-ribbed conservatory dome and
--     glowing Colossal Open Clam against the cascading Tidewall battlements.
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local SunkenFloor39 = {}

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

-- Deep twilight coastal fortress palette: weathered wet blue-grey limestone, pale pearl trim, verdigris bronze
-- domes & shields, worn gold filigree, dark rain-slick wharf timber, teal trident silk, pink-violet/pale-cream
-- coral (never red or orange so enemy telegraphs stay unmistakable), luminous pearl-white & aqua glows, and
-- warm golden-pearl vault light spilling from the Pearl Vault conservatory dome.
local VAULT_PAL = table.freeze({
	STONE = swatch(102, 114, 124, Mat.Slate), -- weathered twilight sea-wall limestone/slate
	TRIM = swatch(166, 174, 172, Mat.Limestone), -- carved pale limestone arches, quoins & reliefs
	METAL = swatch(58, 66, 76, Mat.Metal), -- dark bronze/iron portcullis, chains & frames
	ACCENT = swatch(74, 138, 128, Mat.Metal), -- verdigris bronze dome ribs, diving bell & shields
	GOLD = swatch(210, 178, 102, Mat.Metal), -- worn gilt tridents, armillary rings & vault finials
	GLOW = swatch(138, 244, 246, Mat.Neon), -- pearl-aqua ward runes & reliquary core
	CANDLE = swatch(255, 224, 158, Mat.Neon), -- warm golden-pearl vault light & wharf lanterns
	WOOD = swatch(74, 58, 46, Mat.Wood), -- rain-slick dark wharf & galley timber
	SILK = swatch(42, 92, 94, Mat.Fabric), -- deep teal trident banners, sailcloth & stall stripes
	FOLIAGE = swatch(52, 98, 84, Mat.Grass), -- wet harbour kelp & sea-fronds
	MOSS = swatch(60, 94, 72, Mat.Grass), -- sea-wall moss & barnacle weed
	CORAL = swatch(204, 146, 198, Mat.SmoothPlastic), -- pink-violet reef coral (never red/orange)
	ALT = swatch(234, 232, 224, Mat.SmoothPlastic), -- pearlescent clam shell, canvas & rope
	CRYSTAL = swatch(186, 224, 234, Mat.Glass, 0.30), -- pearl-vault conservatory glass & cascades
})
local CLAM_PEARL = tinted(VAULT_PAL, {
	ALT = swatch(244, 240, 232, Mat.SmoothPlastic),
	GLOW = swatch(242, 248, 255, Mat.Neon), -- luminous empty pearl-white cradle
})
local CORAL_CREAM = tinted(VAULT_PAL, {
	CORAL = swatch(224, 206, 168, Mat.SmoothPlastic),
})
local CORAL_AQUA = tinted(VAULT_PAL, {
	CORAL = swatch(122, 214, 208, Mat.SmoothPlastic),
})

local PEARL_LIGHT = rgb(244, 234, 204)
local AQUA_LIGHT = rgb(116, 238, 244)
local WHARF_LIGHT = rgb(255, 206, 128)

-- Floor 39's spec-checked landmark footprints (room-local, scaled and turned), verified offline against every
-- walkway lane, every camp, both harbour return ramps and both boss portals (Ascend 246,-340; Rerun 214,-340).
SunkenFloor39.Floor39Landmarks = table.freeze({
	{ Id = "PearlVaultDome", X = 230, Z = -374, Y = 56, HalfX = 72.7, HalfZ = 20.3, Top = 218.0 },
	{ Id = "ColossalClam", X = 230, Z = -369, Y = 56, HalfX = 22.4, HalfZ = 14.0, Top = 33.3 },
	{ Id = "CoralGateTower", X = -336, Z = -124, Y = 16, HalfX = 21.2, HalfZ = 16.0, Top = 84.0 },
	{ Id = "TideArmillaryTower", X = 342, Z = -148, Y = 20, HalfX = 12.1, HalfZ = 12.1, Top = 91.0 },
	{ Id = "DrownedGateWall", X = -28, Z = -94, Y = -19, HalfX = 32.0, HalfZ = 7.8, Top = 48.2 },
	{ Id = "InnerWallWestA", X = -108, Z = -104, Y = -10, HalfX = 22.5, HalfZ = 6.1, Top = 38.8 },
	{ Id = "InnerWallEastA", X = 68, Z = -110, Y = -10, HalfX = 22.5, HalfZ = 6.1, Top = 38.8 },
	{ Id = "InnerWallEastB", X = 156, Z = -118, Y = -10, HalfX = 22.5, HalfZ = 6.1, Top = 38.8 },
	{ Id = "OuterWallWestA", X = -128, Z = 134, Y = -4, HalfX = 22.5, HalfZ = 6.1, Top = 38.8 },
	{ Id = "OuterWallWestB", X = -48, Z = 134, Y = -4, HalfX = 22.5, HalfZ = 6.1, Top = 38.8 },
	{ Id = "OuterWallCenter", X = 28, Z = 134, Y = -4, HalfX = 22.5, HalfZ = 6.1, Top = 38.8 },
	{ Id = "OuterWallEast", X = 232, Z = 112, Y = -4, HalfX = 22.5, HalfZ = 6.1, Top = 38.8 },
	{ Id = "DiversWharfBell", X = -344, Z = 60, Y = 4, HalfX = 5.9, HalfZ = 4.8, Top = 14.5 },
	{ Id = "PearlMarketStallW", X = -234, Z = -8, Y = 12, HalfX = 7.8, HalfZ = 5.3, Top = 12.0 },
	{ Id = "PearlMarketStallS", X = -168, Z = 92, Y = 12, HalfX = 7.8, HalfZ = 5.3, Top = 12.0 },
	{ Id = "MusterBellBarricade", X = -30, Z = -84, Y = 20, HalfX = 10.7, HalfZ = 4.4, Top = 9.7 },
	{ Id = "PearlBedsRackA", X = 108, Z = -72, Y = -6, HalfX = 8.6, HalfZ = 4.3, Top = 7.0 },
	{ Id = "PearlBedsRackB", X = 152, Z = -34, Y = -6, HalfX = 8.6, HalfZ = 4.3, Top = 7.0 },
	{ Id = "HarbourCraneEast", X = 340, Z = -10, Y = 14, HalfX = 5.9, HalfZ = 10.4, Top = 26.3 },
	{ Id = "PearlguardGalleyWest", X = -235, Z = 138, Y = -6, HalfX = 25.8, HalfZ = 8.2, Top = 33.5 },
	{ Id = "PearlguardGalleyEast", X = 345, Z = 146, Y = -6, HalfX = 25.8, HalfZ = 8.2, Top = 33.5 },
	{ Id = "WardensHallGuardian", X = -120, Z = -242, Y = 24, HalfX = 11.2, HalfZ = 6.2, Top = 31.2 },
	{ Id = "ShellChapelShrine", X = -336, Z = -306, Y = 28, HalfX = 7.6, HalfZ = 8.0, Top = 18.0 },
	{ Id = "ReliquaryAbyssCore", X = 60, Z = -386, Y = 52, HalfX = 7.6, HalfZ = 8.0, Top = 18.0 },
	{ Id = "VaultStairGuardianN", X = 114, Z = -334, Y = 46, HalfX = 11.2, HalfZ = 6.2, Top = 31.2 },
	{ Id = "TidewallFortressNorth", X = 0, Z = -394, Y = -10, HalfX = 380, HalfZ = 3.0, Top = 282 },
}) :: { Landmark }

function SunkenFloor39.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local field, bottom: number, d: number = H.field, H.bottom, H.d
	local w: number = ctx.w
	local layout = ctx.layout
	local P = layout.Platforms
	local noCollide = H.noCollide
	local origin: Vector3 = ctx.origin
	local waterY: number = if field then field.LiquidLevel else bottom
	local landmarks, props, cover = 0, 0, 0
	local kindsUsed: { [string]: number } = {}
	local rng = Random.new(39 * 8191)

	local function boxAt(name: string, size: Vector3, pos: Vector3, yaw: number, color: Color3, mat: Enum.Material, trans: number?): Part
		return H.boxAt(name, size, CFrame.new(pos) * CFrame.Angles(0, yaw, 0), color, mat, trans)
	end
	local function lump(name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material): Part
		return H.lump(name, pos, size, color, mat)
	end
	local function light(pos: Vector3, color: Color3, brightness: number, range: number)
		local anchor = ctx.block("LightAnchor", V(0.5, 0.5, 0.5), pos, color, Mat.SmoothPlastic, nil, 1)
		noCollide(anchor)
		H.light(anchor, color, brightness, range)
	end
	local function isClear(x: number, z: number, r: number): boolean
		for _, camp in layout.Camps do
			if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (38 + r) ^ 2 then return false end
		end
		return ctx.footprintClear(x, z, r + 1, r + 1)
	end

	local function track(kind: string)
		kindsUsed[kind] = (kindsUsed[kind] or 0) + 1
	end
	local function groundY(x: number, z: number): number
		return if field then field.Height(x, z) + 2 else bottom
	end
	local function markOnTerrain()
		ctx.tag("OnTerrain", true)
	end
	local function put(name: string, x: number, y: number, z: number, scale: any, yaw: number, pal: any?, fallback: (() -> ())?, onGround: boolean?): boolean
		local s = if typeof(scale) == "number" then V(scale, scale, scale) else scale
		track(name)
		if ctx.has(name) then
			ctx.kitAt(name, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), s, pal or VAULT_PAL, true)
			if onGround then markOnTerrain() end
			return true
		elseif fallback then
			fallback()
			if onGround then markOnTerrain() end
			return true
		end
		return false
	end

	-- Part-built fallbacks so Floor 39 reads cleanly even before SunkenF39Kit.fbx is imported.
	local function fbVaultDome(x: number, y: number, z: number)
		for _, sx in { -54, -28, 0, 28, 54 } do
			boxAt("VaultPier", V(9, 88, 10), V(x + sx, y + 44, z), 0, VAULT_PAL.STONE.Color, Mat.Slate)
		end
		boxAt("VaultGlassWall", V(116, 72, 4), V(x, y + 46, z + 2), 0, VAULT_PAL.CRYSTAL.Color, Mat.Glass, 0.32)
		boxAt("VaultWarmGlow", V(86, 56, 2), V(x, y + 48, z - 1), 0, VAULT_PAL.CANDLE.Color, Mat.Neon)
		local dome = lump("VaultDomeShell", V(134, 104, 38), V(x, y + 132, z), VAULT_PAL.ACCENT.Color, Mat.Metal)
		dome.Shape = Enum.PartType.Ball
		boxAt("VaultCupolaSpire", V(14, 34, 14), V(x, y + 201, z), 0, VAULT_PAL.GOLD.Color, Mat.Metal)
	end
	local function fbColossalClam(x: number, y: number, z: number)
		boxAt("ClamPlinth", V(38, 6, 32), V(x, y + 3, z), 0, VAULT_PAL.TRIM.Color, Mat.Limestone)
		boxAt("ClamUpperShell", V(42, 26, 5), V(x, y + 19, z - 6), 0, CLAM_PEARL.ALT.Color, Mat.SmoothPlastic)
		local glow = lump("ClamPearlCradle", V(18, 9, 14), V(x, y + 10, z + 2), CLAM_PEARL.GLOW.Color, Mat.Neon)
		glow.Shape = Enum.PartType.Ball
	end
	local function fbSeaWall(x: number, y: number, z: number, yaw: number)
		boxAt("SeaWallBody", V(44, 34, 10), V(x, y + 17, z), yaw, VAULT_PAL.STONE.Color, Mat.Slate)
		boxAt("SeaWallCap", V(45, 4, 11), V(x, y + 36, z), yaw, VAULT_PAL.TRIM.Color, Mat.Limestone)
		boxAt("SeaWallBanner", V(5, 14, 1), V(x, y + 20, z + 5.6), yaw, VAULT_PAL.SILK.Color, Mat.Fabric)
	end
	local function fbDrownedGate(x: number, y: number, z: number)
		boxAt("DrownedGateCurtain", V(64, 44, 12), V(x, y + 22, z), 0, VAULT_PAL.STONE.Color, Mat.Slate)
		boxAt("DrownedGateSeal", V(26, 28, 3), V(x, y + 14, z + 6.5), 0, VAULT_PAL.ACCENT.Color, Mat.Metal)
		boxAt("DrownedGateTrident", V(3, 18, 1), V(x, y + 16, z + 8.2), 0, VAULT_PAL.GLOW.Color, Mat.Neon)
	end
	local function fbTower(x: number, y: number, z: number, hTow: number, hasArmillary: boolean)
		boxAt("FortTowerShaft", V(24, hTow * 0.72, 24), V(x, y + hTow * 0.36, z), 0, VAULT_PAL.STONE.Color, Mat.Slate)
		boxAt("FortTowerParapet", V(28, 6, 28), V(x, y + hTow * 0.74, z), 0, VAULT_PAL.TRIM.Color, Mat.Limestone)
		if hasArmillary then
			local orb = lump("ArmillaryCore", V(14, 14, 14), V(x, y + hTow * 0.88, z), VAULT_PAL.GOLD.Color, Mat.Metal)
			orb.Shape = Enum.PartType.Ball
		else
			local cap = lump("CoralTowerCap", V(18, 14, 18), V(x, y + hTow * 0.84, z), VAULT_PAL.ACCENT.Color, Mat.Metal)
			cap.Shape = Enum.PartType.Ball
		end
	end
	local function fbGatehouse(x: number, y: number, z: number, yaw: number)
		local cf = CFrame.new(origin + V(x, y, z)) * CFrame.Angles(0, yaw, 0)
		for _, sx in { -20.5, 20.5 } do
			local p = cf:PointToWorldSpace(V(sx, 18, 0)) - origin
			noCollide(boxAt("SeaGatePier", V(14, 36, 14), p, yaw, VAULT_PAL.STONE.Color, Mat.Slate))
		end
		local topP = cf:PointToWorldSpace(V(0, 32, 0)) - origin
		noCollide(boxAt("SeaGateHeader", V(56, 10, 14), topP, yaw, VAULT_PAL.TRIM.Color, Mat.Limestone))
		local portP = cf:PointToWorldSpace(V(0, 24, 0)) - origin
		noCollide(boxAt("SeaGatePortcullis", V(26, 4, 2), portP, yaw, VAULT_PAL.METAL.Color, Mat.Metal))
	end
	local function fbBellStack(x: number, y: number, z: number, yaw: number)
		boxAt("BellCribbing", V(14, 2, 8), V(x, y + 1, z), yaw, VAULT_PAL.WOOD.Color, Mat.Wood)
		for _, off in { V(-3, 4, 0), V(3, 4, 0), V(0, 7, 0) } do
			local b = lump("MuffledBell", V(5.5, 5.5, 5.5), V(x, y, z) + off, VAULT_PAL.SILK.Color, Mat.Fabric)
			b.Shape = Enum.PartType.Ball
		end
	end
	local function fbOysterRack(x: number, y: number, z: number, yaw: number)
		boxAt("OysterFrame", V(17, 5, 8), V(x, y + 2.5, z), yaw, VAULT_PAL.WOOD.Color, Mat.Wood)
		boxAt("OysterPearls", V(14, 1.5, 5), V(x, y + 5.8, z), yaw, VAULT_PAL.GLOW.Color, Mat.Neon)
	end
	local function fbDivingBell(x: number, y: number, z: number, yaw: number)
		boxAt("WharfDavit", V(10, 14, 9), V(x, y + 7, z), yaw, VAULT_PAL.WOOD.Color, Mat.Wood)
		local bell = lump("BrassBell", V(6.5, 7.5, 6.5), V(x, y + 5.5, z), VAULT_PAL.ACCENT.Color, Mat.Metal)
		bell.Shape = Enum.PartType.Ball
	end
	local function fbGalley(x: number, y: number, z: number, yaw: number)
		boxAt("GalleyHull", V(44, 7, 14), V(x, y + 3.5, z), yaw, VAULT_PAL.WOOD.Color, Mat.Wood)
		boxAt("GalleyMast", V(2, 28, 2), V(x, y + 18, z), yaw, VAULT_PAL.WOOD.Color, Mat.Wood)
		boxAt("GalleySail", V(18, 16, 1.5), V(x, y + 19, z), yaw, VAULT_PAL.SILK.Color, Mat.Fabric)
	end
	local function fbStatue(x: number, y: number, z: number, yaw: number)
		boxAt("WardenPlinth", V(11, 6, 11), V(x, y + 3, z), yaw, VAULT_PAL.STONE.Color, Mat.Slate)
		boxAt("WardenBody", V(8, 20, 6), V(x, y + 16, z), yaw, VAULT_PAL.TRIM.Color, Mat.Limestone)
		boxAt("WardenShield", V(4, 10, 8), V(x + 5, y + 16, z), yaw, VAULT_PAL.ACCENT.Color, Mat.Metal)
	end
	local function fbStall(x: number, y: number, z: number, yaw: number)
		boxAt("StallCounter", V(14, 4, 5), V(x, y + 2, z), yaw, VAULT_PAL.WOOD.Color, Mat.Wood)
		boxAt("StallAwning", V(15, 2, 10), V(x, y + 10.5, z), yaw, VAULT_PAL.SILK.Color, Mat.Fabric)
	end
	local function fbCrane(x: number, y: number, z: number, yaw: number)
		boxAt("CraneBase", V(9, 5, 9), V(x, y + 2.5, z), yaw, VAULT_PAL.STONE.Color, Mat.Slate)
		boxAt("CraneBoom", V(3, 22, 16), V(x, y + 15, z), yaw, VAULT_PAL.WOOD.Color, Mat.Wood)
	end
	local function fbReliquary(x: number, y: number, z: number, yaw: number)
		boxAt("ReliquaryPlinth", V(9, 6, 9), V(x, y + 3, z), yaw, VAULT_PAL.STONE.Color, Mat.Slate)
		local orb = lump("AbyssCoreOrb", V(5.5, 5.5, 5.5), V(x, y + 11.5, z), VAULT_PAL.GLOW.Color, Mat.Neon)
		orb.Shape = Enum.PartType.Ball
	end

	-- =========================================================================
	-- 1. THE PEARL VAULT DOME (218 STUDS) & COLOSSAL OPEN CLAM (APEX BACK-EAST)
	-- =========================================================================
	local apex = P.Apex
	ctx.group("PearlVaultDome", function()
		put("PearlVaultDome", 230, apex.Y, -374, 1.0, 0, VAULT_PAL, function()
			fbVaultDome(230, apex.Y, -374)
		end, true)
		-- Warm golden-pearl light spilling from the conservatory vault & oculus (2 lights)
		light(V(230, apex.Y + 46, -356), PEARL_LIGHT, 2.2, 60)
		light(V(230, apex.Y + 122, -366), PEARL_LIGHT, 1.9, 60)
		landmarks += 1
	end)
	ctx.reserve(230, -374, 60)

	ctx.group("ColossalClam", function()
		put("ColossalClam", 230, apex.Y, -369, 1.0, 0, CLAM_PEARL, function()
			fbColossalClam(230, apex.Y, -369)
		end, true)
		light(V(230, apex.Y + 14, -360), rgb(245, 250, 255), 2.1, 52)
		landmarks += 1
	end)

	-- Flush non-colliding pearl-and-verdigris tide-spiral mosaic on the Pearl Vault combat floor (like Floor 37)
	ctx.group("PearlVaultMosaic", function()
		ctx.tag("PropKind", "CloisterFloorMosaic")
		ctx.tag("OnTerrain", true)
		local ring = boxAt("VaultMosaicRing", V(56, 0.14, 56), V(apex.X, apex.Y + 0.08, apex.Z), 0, VAULT_PAL.TRIM.Color, Mat.Marble)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(origin + V(apex.X, apex.Y + 0.08, apex.Z)) * CFrame.Angles(0, 0, math.pi / 2)
		noCollide(ring)
		local inner = boxAt("VaultMosaicInner", V(36, 0.16, 36), V(apex.X, apex.Y + 0.09, apex.Z), 0, VAULT_PAL.ACCENT.Color, Mat.SmoothPlastic)
		inner.Shape = Enum.PartType.Cylinder
		inner.CFrame = CFrame.new(origin + V(apex.X, apex.Y + 0.09, apex.Z)) * CFrame.Angles(0, 0, math.pi / 2)
		noCollide(inner)
		local core = boxAt("VaultMosaicCore", V(14, 0.18, 14), V(apex.X, apex.Y + 0.10, apex.Z), 0, VAULT_PAL.GOLD.Color, Mat.Metal)
		core.Shape = Enum.PartType.Cylinder
		core.CFrame = CFrame.new(origin + V(apex.X, apex.Y + 0.10, apex.Z)) * CFrame.Angles(0, 0, math.pi / 2)
		noCollide(core)
	end)

	-- =========================================================================
	-- 2. CORAL GATE TOWER (WEST) & TIDE TOWER (EAST) + INNER SEA-WALL & DROWNED GATE
	-- =========================================================================
	ctx.group("CoralGateTower", function()
		put("CoralGateTower", -336, 16, -124, 1.0, 0.18, VAULT_PAL, function()
			fbTower(-336, 16, -124, 84, false)
		end, true)
		light(V(-336, 82, -124), AQUA_LIGHT, 1.6, 50)
		landmarks += 1
	end)
	ctx.reserve(-336, -124, 28)

	ctx.group("TideArmillaryTower", function()
		put("TideArmillaryTower", 342, 20, -148, 1.0, -0.18, VAULT_PAL, function()
			fbTower(342, 20, -148, 91, true)
		end, true)
		light(V(342, 98, -148), PEARL_LIGHT, 1.8, 54)
		landmarks += 1
	end)
	ctx.reserve(342, -148, 22)

	ctx.group("DrownedGateWall", function()
		put("DrownedGateWall", -28, -19, -94, 1.0, 0, VAULT_PAL, function()
			fbDrownedGate(-28, -19, -94)
		end, true)
		light(V(-28, 24, -84), AQUA_LIGHT, 1.5, 44)
		landmarks += 1
	end)
	ctx.reserve(-28, -94, 34)

	for _, seg in {
		{ id = "InnerWallWestA", x = -108, y = -10, z = -104, yaw = 0.08 },
		{ id = "InnerWallEastA", x = 68, y = -10, z = -110, yaw = -0.06 },
		{ id = "InnerWallEastB", x = 156, y = -10, z = -118, yaw = -0.08 },
		{ id = "OuterWallWestA", x = -128, y = -4, z = 134, yaw = 0 },
		{ id = "OuterWallWestB", x = -48, y = -4, z = 134, yaw = 0 },
		{ id = "OuterWallCenter", x = 28, y = -4, z = 134, yaw = 0 },
		{ id = "OuterWallEast", x = 232, y = -4, z = 112, yaw = -0.16 },
	} do
		ctx.group(seg.id, function()
			put("SeaWallSegment", seg.x, seg.y, seg.z, 1.0, seg.yaw, VAULT_PAL, function()
				fbSeaWall(seg.x, seg.y, seg.z, seg.yaw)
			end, true)
			landmarks += 1
		end)
		ctx.reserve(seg.x, seg.z, 22)
	end

	-- Outer Sea Gate Portcullis Gatehouse straddling the single outer-wall entrance (`Basin -> Crossing`),
	-- exempt via NerethBellArch so its 28-stud wide central opening frames the walkway cleanly.
	ctx.group("SeaGatePortcullis", function()
		ctx.tag("PropKind", "NerethBellArch")
		local gx, gy, gz, gyaw = 64, 2, 166, math.rad(-45)
		track("PortcullisGatehouse")
		if ctx.has("PortcullisGatehouse") then
			ctx.kitAt("PortcullisGatehouse", CFrame.new(gx, gy, gz) * CFrame.Angles(0, gyaw, 0), V(1, 1, 1), VAULT_PAL, false)
			markOnTerrain()
		else
			fbGatehouse(gx, gy, gz, gyaw)
			markOnTerrain()
		end
		light(V(gx, gy + 28, gz), WHARF_LIGHT, 1.6, 46)
		landmarks += 1
	end)

	-- =========================================================================
	-- 3. OUTER WARD VIGNETTES: DIVERS' WHARF, PEARL MARKET, MUSTER YARD, PEARL BEDS, HARBOUR WARD
	-- =========================================================================
	-- Divers' Wharf (west pier on piles): bronze diving bell, ropes, warm wharf light
	ctx.group("DiversWharfBell", function()
		put("DivingBell", -344, 4, 60, 1.0, math.rad(80), VAULT_PAL, function()
			fbDivingBell(-344, 4, 60, math.rad(80))
		end, true)
		light(V(-340, 14, 60), WHARF_LIGHT, 1.4, 38)
		landmarks += 1
	end)
	ctx.reserve(-344, 60, 12)

	-- Pearl Market: striped shell-awning stalls & warm lantern glow
	for _, st in {
		{ id = "PearlMarketStallW", x = -234, y = 12, z = -8, yaw = math.rad(78) },
		{ id = "PearlMarketStallS", x = -168, y = 12, z = 92, yaw = math.rad(180) },
	} do
		ctx.group(st.id, function()
			put("ShellAwningStall", st.x, st.y, st.z, 1.0, st.yaw, VAULT_PAL, function()
				fbStall(st.x, st.y, st.z, st.yaw)
			end, true)
			landmarks += 1
		end)
		ctx.reserve(st.x, st.z, 12)
	end

	-- Muster Yard: muffled-bell barricade & weapon racks facing the sealed Drowned Gate
	ctx.group("MusterBellBarricade", function()
		put("MuffledBellStack", -30, 20, -84, 1.0, math.rad(22), VAULT_PAL, function()
			fbBellStack(-30, 20, -84, math.rad(22))
		end, true)
		landmarks += 1
	end)
	ctx.reserve(-30, -84, 14)

	-- Additional muffled bell stacks beside the Sea Gate & Arrival Breakwater Steps (story beat!)
	for idx, mb in {
		{ x = 22, y = 0, z = 186, yaw = -0.35 },
		{ x = 166, y = 6, z = 148, yaw = 0.5 },
		{ x = -112, y = 0, z = 188, yaw = 0.2 },
		{ x = 178, y = 0, z = 192, yaw = -0.25 },
	} do
		if isClear(mb.x, mb.z, 10) then
			ctx.group("MuffledBellBarricade_" .. idx, function()
				put("MuffledBellStack", mb.x, groundY(mb.x, mb.z), mb.z, 0.85, mb.yaw, VAULT_PAL, function()
					fbBellStack(mb.x, groundY(mb.x, mb.z), mb.z, mb.yaw)
				end, true)
				props += 1
			end)
		end
	end

	-- Oyster Pearl Beds: cultivation racks standing in the eastern tank
	for _, rk in {
		{ id = "PearlBedsRackA", x = 108, y = -6, z = -72, yaw = 0.1 },
		{ id = "PearlBedsRackB", x = 152, y = -6, z = -34, yaw = -0.15 },
	} do
		ctx.group(rk.id, function()
			put("OysterRack", rk.x, rk.y, rk.z, 1.0, rk.yaw, VAULT_PAL, function()
				fbOysterRack(rk.x, rk.y, rk.z, rk.yaw)
			end, true)
			landmarks += 1
		end)
		ctx.reserve(rk.x, rk.z, 12)
	end

	-- Harbour Ward: timber jib crane + twin moored Pearlguard galleys + harbour chain-boom
	ctx.group("HarbourCraneEast", function()
		put("HarbourCrane", 340, 14, -10, 1.0, math.rad(-95), VAULT_PAL, function()
			fbCrane(340, 14, -10, math.rad(-95))
		end, true)
		landmarks += 1
	end)
	ctx.reserve(340, -10, 14)

	for _, gl in {
		{ id = "PearlguardGalleyWest", x = -235, y = -6, z = 138, yaw = math.rad(16) },
		{ id = "PearlguardGalleyEast", x = 345, y = -6, z = 146, yaw = math.rad(-164) },
	} do
		ctx.group(gl.id, function()
			put("PearlguardGalley", gl.x, gl.y, gl.z, 1.0, gl.yaw, VAULT_PAL, function()
				fbGalley(gl.x, gl.y, gl.z, gl.yaw)
			end, true)
			landmarks += 1
		end)
		ctx.reserve(gl.x, gl.z, 26)
	end

	-- Sunken harbour chain-boom stretched across the western & eastern harbour water
	ctx.group("HarbourChainBoom", function()
		ctx.tag("OnTerrain", true)
		for _, seg in {
			{ V(-278, waterY + 1.5, 168), V(-188, waterY + 0.5, 152) },
			{ V(-188, waterY + 0.5, 152), V(-85, waterY + 1.2, 166) },
			{ V(195, waterY + 1.2, 156), V(268, waterY + 0.4, 148) },
		} do
			local a, b = seg[1], seg[2]
			local link = ctx.beam("HarbourChainLink", a, b, 1.0, VAULT_PAL.METAL.Color, Mat.Metal)
			noCollide(link)
			local buoy = lump("ChainBoomBuoy", V(3.6, 3.6, 3.6), a:Lerp(b, 0.5), VAULT_PAL.ACCENT.Color, Mat.Metal)
			buoy.Shape = Enum.PartType.Ball
			noCollide(buoy)
		end
		props += 6
	end)

	-- =========================================================================
	-- 4. INNER WARD VIGNETTES: WARDENS' HALL, SHELL CHAPEL, PEARL CISTERN, VAULT STAIR, RELIQUARY
	-- =========================================================================
	ctx.group("WardensHallGuardian", function()
		put("CoralWardenStatue", -120, 24, -242, 1.0, math.rad(55), VAULT_PAL, function()
			fbStatue(-120, 24, -242, math.rad(55))
		end, true)
		landmarks += 1
	end)
	ctx.reserve(-120, -242, 14)

	ctx.group("ShellChapelShrine", function()
		put("CoralCageReliquary", -336, 28, -306, 1.0, math.rad(45), CORAL_CREAM, function()
			fbReliquary(-336, 28, -306, math.rad(45))
		end, true)
		light(V(-334, 40, -304), AQUA_LIGHT, 1.5, 42)
		landmarks += 1
	end)
	ctx.reserve(-336, -306, 12)

	ctx.group("ReliquaryAbyssCore", function()
		put("CoralCageReliquary", 60, 52, -386, 1.15, 0, VAULT_PAL, function()
			fbReliquary(60, 52, -386, 0)
		end, true)
		light(V(60, 68, -382), AQUA_LIGHT, 1.7, 46)
		landmarks += 1
	end)
	ctx.reserve(60, -386, 12)

	ctx.group("VaultStairGuardianN", function()
		put("CoralWardenStatue", 114, 46, -334, 1.05, math.rad(-25), CORAL_AQUA, function()
			fbStatue(114, 46, -334, math.rad(-25))
		end, true)
		landmarks += 1
	end)
	ctx.reserve(114, -334, 14)

	-- Pearl Cistern off-lane coral-crusted urns (echoing Tidebound Urn relic)
	ctx.group("PearlCisternRim", function()
		ctx.tag("OnTerrain", true)
		for i = 0, 5 do
			local ang = math.rad(-145 + i * 24)
			local ux, uz = -40 + math.cos(ang) * 44, -190 + math.sin(ang) * 38
			if isClear(ux, uz, 5) then
				put("StoneUrn", ux, groundY(ux, uz), uz, 1.4, ang, VAULT_PAL, nil, true)
				props += 1
			end
		end
	end)

	-- Arrival Breakwater Steps framing: twin hooded wharf beacons & trident obelisks (well clear of Sanctuary deck)
	for _, sx in { -78, 78 } do
		if isClear(sx, 330, 8) then
			ctx.group("ArrivalBeacon_" .. (if sx < 0 then "W" else "E"), function()
				put("Obelisk", sx, groundY(sx, 330), 330, V(0.7, 1.15, 0.7), 0, VAULT_PAL, nil, true)
				props += 1
			end)
		end
	end

	-- =========================================================================
	-- 5. FORTIFIED TIDEWALL BACKDROP, MISTY CASCADES & LEVIATHAN SHADOW (NORTH)
	-- =========================================================================
	ctx.group("TidewallFortressNorth", function()
		ctx.tag("OnTerrain", true)
		local wallZ = -394
		-- Monumental standing-sea glass wall darkening toward the top
		local lowerSea = boxAt("TidewallSeaLower", V(w - 14, 140, 4), V(0, 62, wallZ), 0, rgb(38, 92, 114), Mat.Glass, 0.24)
		local upperSea = boxAt("TidewallSeaUpper", V(w - 14, 146, 4), V(0, 204, wallZ), 0, rgb(22, 46, 72), Mat.Glass, 0.16)
		noCollide(lowerSea)
		noCollide(upperSea)
		-- Fortified Tidewall upper battlements & trident reliefs along the crest (matching guide image!)
		for i = -6, 6 do
			local bx = i * 56
			local pier = boxAt("TidewallBattlementPier", V(28, 72, 6), V(bx, 228, wallZ + 2), 0, rgb(96, 110, 122), Mat.Slate)
			noCollide(pier)
			if i % 2 == 0 then
				local fall = boxAt("TidewallCascade", V(14, 185, 2.5), V(bx + 26, 128, wallZ + 3.5), 0, rgb(206, 232, 242), Mat.Glass, 0.38)
				noCollide(fall)
			end
		end
		-- Vast dark Leviathan silhouette circling high inside the deep Tidewall (Floor 39 story beat!)
		for k = -4, 4 do
			local lx = -120 + k * 42
			local ly = 166 + math.sin(k * 0.72) * 18
			local seg = lump("LeviathanShadow_" .. k, V(48, 22 - math.abs(k) * 2.2, 5), V(lx, ly, wallZ - 2.5), rgb(14, 24, 38), Mat.SmoothPlastic)
			seg.Transparency = 0.28
			seg.Shape = Enum.PartType.Ball
			noCollide(seg)
		end
		landmarks += 1
	end)

	-- =========================================================================
	-- 6. RICH FORTRESS, HARBOUR & CORAL ECOSYSTEM SCATTER (TARGETS: >=570 PROPS, >=400 COVER, >=34 TEMPLATES)
	-- =========================================================================
	local fortressProps = {
		"CoralCluster", "BoulderCluster", "RuinRubble", "StoneUrn", "Obelisk", "CrystalSpire",
		"HangingLantern", "CliffRockA", "CliffRockB", "ArchPierBase", "ArchPierSegment", "LionGuardian",
		"RobedStatueTrident", "RobedStatueStaff", "ChasmIsland", "Cairn", "VoidShards", "BanyanTree",
		"MuffledBellStack", "OysterRack", "ShellAwningStall", "DivingBell", "HarbourCrane",
		"CoralWardenStatue", "CoralCageReliquary", "SeaWallSegment",
	}
	local propCap = 60 -- keeps every template well under the 12% variety rule (>= 570 props -> max 68)
	local placedByKind: { [string]: number } = {}

	local safe = layout.Sanctuary
	local function offSanctuary(x: number, z: number, pad: number): boolean
		return math.abs(x - safe.X) > (safe.Width * 0.5 + pad) or math.abs(z - safe.Z) > (safe.Depth * 0.5 + pad)
	end

	local function tryProp(name: string, x: number, z: number, minScale: number, maxScale: number, clearR: number, pal: any?): boolean
		if (placedByKind[name] or 0) >= propCap then return false end
		if math.abs(x) > w / 2 - 22 or math.abs(z) > d / 2 - 22 then return false end
		if not offSanctuary(x, z, clearR + 36) then return false end
		if not isClear(x, z, clearR) then return false end
		local y = groundY(x, z)
		local sc = minScale + rng:NextNumber() * (maxScale - minScale)
		local yaw = rng:NextNumber() * math.pi * 2
		if put(name, x, y, z, sc, yaw, pal or VAULT_PAL, nil, true) then
			placedByKind[name] = (placedByKind[name] or 0) + 1
			props += 1
			return true
		end
		return false
	end

	-- Pass A: Ensure broad template diversity across all 20+ core & Floor 39 templates on fortress flanks & harbour
	for _, name in fortressProps do
		local isBig = (name == "SeaWallSegment" or name == "PearlguardGalley" or name == "CoralGateTower")
		local target = if isBig then 2 elseif name == "MuffledBellStack" or name == "OysterRack" or name == "ShellAwningStall" or name == "DivingBell" or name == "HarbourCrane" or name == "CoralWardenStatue" or name == "CoralCageReliquary" then 6 else 28
		local attempts = 0
		local placed = 0
		while placed < target and attempts < target * 14 do
			attempts += 1
			local x = (rng:NextNumber() * 2 - 1) * (w / 2 - 28)
			local z = (rng:NextNumber() * 2 - 1) * (d / 2 - 30)
			-- Keep the Apex combat floor completely clean
			if math.abs(x - apex.X) < apex.Width / 2 + 12 and math.abs(z - apex.Z) < apex.Depth / 2 + 12 then
				continue
			end
			local pal = if name == "CoralCluster" or name == "CoralCageReliquary"
				then (if placed % 3 == 0 then CORAL_CREAM elseif placed % 3 == 1 then CORAL_AQUA else VAULT_PAL)
				else VAULT_PAL
			local clearR = if isBig then 20 elseif name == "BanyanTree" or name == "CliffRockA" or name == "CliffRockB" or name == "ChasmIsland" then 11 else 7.5
			local sMin, sMax = 0.55, 1.05
			if name == "CliffRockA" or name == "CliffRockB" then sMin, sMax = 0.7, 1.45
			elseif name == "CoralCluster" then sMin, sMax = 0.75, 1.55
			elseif name == "BanyanTree" then sMin, sMax = 0.55, 0.85
			elseif name == "MuffledBellStack" or name == "OysterRack" or name == "ShellAwningStall" or name == "DivingBell" then sMin, sMax = 0.75, 0.95
			elseif name == "HarbourCrane" or name == "CoralWardenStatue" or name == "CoralCageReliquary" then sMin, sMax = 0.7, 0.95
			end
			if tryProp(name, x, z, sMin, sMax, clearR, pal) then
				placed += 1
			end
		end
	end

	-- Pass B: Fill remaining prop budget to comfortably exceed 570 placed props while keeping every template <= 10%
	local fillerPool = {
		"CoralCluster", "BoulderCluster", "RuinRubble", "StoneUrn", "Obelisk", "CrystalSpire",
		"HangingLantern", "CliffRockA", "CliffRockB", "ArchPierBase", "ArchPierSegment", "Cairn",
		"VoidShards", "ChasmIsland", "FoliageBush", "FernCluster", "MushroomCluster", "ReedPondCluster",
	}
	local fillAttempts = 0
	while props < 595 and fillAttempts < 4200 do
		fillAttempts += 1
		local name = fillerPool[(fillAttempts % #fillerPool) + 1]
		local x = (rng:NextNumber() * 2 - 1) * (w / 2 - 24)
		local z = (rng:NextNumber() * 2 - 1) * (d / 2 - 26)
		if math.abs(x - apex.X) < apex.Width / 2 + 10 and math.abs(z - apex.Z) < apex.Depth / 2 + 10 then
			continue
		end
		local pal = if fillAttempts % 3 == 0 then CORAL_AQUA elseif fillAttempts % 3 == 1 then CORAL_CREAM else VAULT_PAL
		tryProp(name, x, z, 0.5, 1.15, 6.0, pal)
	end

	-- Pass C: Ground cover & small coastal clutter (>= 400 pieces: barnacle stones, shell clusters, kelp tufts, reef buds)
	local coverNames = { "FoliageBush", "FernCluster", "ReedPondCluster", "MushroomCluster", "RuinRubble", "BoulderCluster" }
	local coverAttempts = 0
	while cover < 420 and coverAttempts < 3400 do
		coverAttempts += 1
		local x = (rng:NextNumber() * 2 - 1) * (w / 2 - 20)
		local z = (rng:NextNumber() * 2 - 1) * (d / 2 - 22)
		if math.abs(x - apex.X) < apex.Width / 2 + 8 and math.abs(z - apex.Z) < apex.Depth / 2 + 8 then
			continue
		end
		if not offSanctuary(x, z, 16) then continue end
		if not isClear(x, z, 4.5) then continue end
		local cname = coverNames[(coverAttempts % #coverNames) + 1]
		local pal = if coverAttempts % 3 == 0 then CORAL_AQUA elseif coverAttempts % 3 == 1 then CORAL_CREAM else VAULT_PAL
		local sc = 0.34 + rng:NextNumber() * 0.34
		if put(cname, x, groundY(x, z), z, sc, rng:NextNumber() * math.pi * 2, pal, nil, true) then
			cover += 1
		end
	end

	local distinctCount = 0
	for _ in kindsUsed do
		distinctCount += 1
	end
	ctx.setAttribute("Floor39Landmarks", landmarks)
	ctx.setAttribute("Floor39Props", props)
	ctx.setAttribute("Floor39Cover", cover)
	ctx.setAttribute("Floor39Templates", distinctCount)
end

return SunkenFloor39
