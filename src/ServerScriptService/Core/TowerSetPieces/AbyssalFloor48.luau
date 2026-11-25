--!strict
-- Hand-authored set pieces for Abyssal Throne Floor 48: Voidspan Crossing (abyssal:3, TERRAIN_VARIATION).
-- Design: docs/prompts/abyssal-throne-floor-layouts-prompt.md (Floor 48) & Abyssal Throne 48.jpg.
--
-- The Vahl court's crossing of the great void:
--   * Four towering 214-stud iron-collared obsidian Anchor Spires with giant capstans and suspended
--     counterweights stand just outside the four anchor footings, carrying four colossal forged iron
--     chains in a sweeping dipping saltire across the chasm.
--   * Where the four great chains converge hangs the central iron Keystone cage-platform (Y=22, the
--     lowest point past the near rim), lit by the floor's brightest pale bone-white Wardlight; along
--     each diagonal arm hang the four Bead decks in iron suspension cradles. All overhead chains and
--     cradles maintain >= 18 studs clear above every deck and walkway link.
--   * Narrow wall-bolted Gibbet Ledges flank the east and west chasm walls with dangling iron cages;
--     near-rim terraces dress each faction role (The Hookward's gantries & reaver hooks, The Chainwright's
--     Yard's house-sized half-forged link, The Ashgrate's grated ash pits, Capstan Quay's seized windlasses).
--   * On the back-east Apex stands the obsidian Far Gatehouse crowned with the gold-rimmed Chained Crown
--     sigil (adapted to pale bone-white Wardlights; zero orange anywhere).
--   * Deep on the void floor (Y = -9.5, 17-31+ studs below every walk surface) pools the churning violet
--     Undertow lighting the saltire from below.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AbyssalFloor48 = {}

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

-- Vahl / Throneward palette (§5.4 & §5.7):
-- Bone-white Wardlights only near walk surfaces (hue ~44 deg, sat ~0.09).
-- Crimson silk is strictly matte Fabric (never Neon). Zero orange anywhere.
local VAHL_48 = table.freeze({
	STONE = swatch(24, 22, 30, Mat.Basalt),         -- obsidian & dark basalt
	ALT = swatch(206, 200, 188, Mat.Limestone),     -- bone-white marble trim
	METAL = swatch(44, 46, 54, Mat.Metal),          -- blackened forged iron
	TRIM = swatch(62, 64, 74, Mat.Metal),           -- dark iron bands & chain collars
	SILK = swatch(118, 22, 36, Mat.Fabric),         -- matte wine-crimson silk
	ACCENT = swatch(194, 158, 68, Mat.Metal),       -- old gold (Chained Crown rim, sparingly)
	GLOW = swatch(244, 238, 222, Mat.Neon),         -- pale bone-white Wardlight (hue 44, sat 0.09)
	CRYSTAL = swatch(96, 48, 126, Mat.Glass, 0.25), -- caged void shard (non-Neon near walk)
	MOSS = swatch(72, 68, 76, Mat.Basalt),          -- ash drifts
	WOOD = swatch(56, 42, 34, Mat.Wood),            -- charred ironwood
	GOLD = swatch(186, 152, 70, Mat.Metal),         -- tarnished gold/brass accents
	FOLIAGE = swatch(48, 44, 52, Mat.Slate),        -- gnarled dead blightwood bark
})

-- Deep void-floor Undertow tint (used ONLY at Y = -9.5 on the void chasm floor, >= 31 studs below Keystone)
local VOID_POOL_TINT = tinted(VAHL_48, {
	STONE = swatch(14, 10, 24, Mat.SmoothPlastic),
	ALT = swatch(62, 28, 118, Mat.SmoothPlastic),
	CRYSTAL = swatch(128, 62, 220, Mat.Glass, 0.20),
	GLOW = swatch(156, 86, 246, Mat.Neon),
})

local SHUTTER_TINT = tinted(VAHL_48, {
	GLOW = swatch(74, 72, 78, Mat.SmoothPlastic),
})

local OBSIDIAN = rgb(24, 22, 30)
local BASALT_DARK = rgb(18, 16, 22)
local IRON_BLACK = rgb(44, 46, 54)
local IRON_DARK = rgb(62, 64, 74)
local BONE_MARBLE = rgb(206, 200, 188)
local WINE_SILK = rgb(118, 22, 36)
local OLD_GOLD = rgb(194, 158, 68)
local ASH_GREY = rgb(74, 70, 78)
local CHARRED_WOOD = rgb(56, 42, 34)

-- §5.7: Bone-white Wardlight (hue ~44 deg, saturation ~0.09) and deep void violet (void floor ONLY)
local WARD_GLOW = rgb(244, 238, 222)
local WARD_SOFT = rgb(236, 228, 210)
local VOID_VIOLET = rgb(148, 78, 236)
local VOID_DEEP = rgb(78, 34, 146)

local ABYSS_Y = -10.0
local VOID_POOL_Y = -9.5

-- Floor 48's 26 landmark footprints (local floor space, 760 x 760 room), verified clear of every
-- walkway lane, camp (34-stud radius + mob slots), return ramp and Apex portal spot.
-- Overhead saltire chains, KeystoneCage, HungBeadPlatforms and ChainStairGate straddle on purpose.
AbyssalFloor48.Landmarks = table.freeze({
	-- 1–4. The Four Towering Anchor Spires (Top = 214 >= 205, standing on rock piers off all lanes)
	{ Id = "WestAnchorSpire", X = -112, Z = 8, Y = 26, HalfX = 12.0, HalfZ = 12.0, Top = 214.0 },
	{ Id = "EastAnchorSpire", X = 112, Z = 8, Y = 30, HalfX = 12.0, HalfZ = 12.0, Top = 214.0 },
	{ Id = "FarWestAnchorSpire", X = -114, Z = -256, Y = 38, HalfX = 12.0, HalfZ = 12.0, Top = 214.0 },
	{ Id = "FarEastAnchorSpire", X = 144, Z = -244, Y = 42, HalfX = 12.0, HalfZ = 12.0, Top = 214.0 },
	-- 5–8. The Four Colossal Saltire Chains sweeping >= 24 studs above every deck and bridge
	{ Id = "SaltireChainNW", X = -56, Z = -40, Y = 46, HalfX = 62.0, HalfZ = 56.0, Top = 96.0, Straddles = true },
	{ Id = "SaltireChainNE", X = 56, Z = -40, Y = 46, HalfX = 62.0, HalfZ = 56.0, Top = 96.0, Straddles = true },
	{ Id = "SaltireChainFW", X = -57, Z = -180, Y = 46, HalfX = 62.0, HalfZ = 80.0, Top = 104.0, Straddles = true },
	{ Id = "SaltireChainFE", X = 72, Z = -175, Y = 46, HalfX = 76.0, HalfZ = 76.0, Top = 104.0, Straddles = true },
	-- 9. The Keystone Cage-Platform (lowest point of the saltire, brightest bone-white Wardlight)
	{ Id = "KeystoneCage", X = 0, Z = -105, Y = 22, HalfX = 28.0, HalfZ = 24.0, Top = 45.0, Straddles = true },
	-- 10–13. The Four Hung Bead Suspension Cradles
	{ Id = "BeadNWCradle", X = -32, Z = -35, Y = 26, HalfX = 24.0, HalfZ = 10.0, Top = 31.0, Straddles = true },
	{ Id = "BeadNECradle", X = 32, Z = -35, Y = 30, HalfX = 24.0, HalfZ = 10.0, Top = 31.0, Straddles = true },
	{ Id = "BeadFWCradle", X = -32, Z = -175, Y = 31, HalfX = 24.0, HalfZ = 10.0, Top = 31.0, Straddles = true },
	{ Id = "BeadFECradle", X = 32, Z = -175, Y = 33, HalfX = 24.0, HalfZ = 10.0, Top = 31.0, Straddles = true },
	-- 14. The Far Gatehouse behind Apex (back-east rim, gold-rimmed Chained Crown sigil, clear of portals)
	{ Id = "FarGatehouse", X = 170, Z = -364, Y = 56, HalfX = 30.0, HalfZ = 10.0, Top = 55.0 },
	-- 15. The Chainwright's Yard colossal half-forged link (east forge bay of Crossing, clear of camp)
	{ Id = "ChainwrightForgedLink", X = 58, Z = 115, Y = 12, HalfX = 12.0, HalfZ = 9.0, Top = 14.0 },
	-- 16. The Hookward pulley gantry (west flank bay of WestGallery, clear of camp)
	{ Id = "HookwardPulleyGantry", X = -274, Z = 102, Y = 8, HalfX = 9.0, HalfZ = 4.0, Top = 14.0 },
	-- 17. The Ashgrate iron ash-pit grate (east flank bay of EastGallery, clear of camp)
	{ Id = "AshgratePitDeck", X = 274, Z = 102, Y = 16, HalfX = 10.0, HalfZ = 9.0, Top = 3.0 },
	-- 18–19. Capstan Quay great seized capstans (far west and east of Basin camps)
	{ Id = "CapstanQuayWest", X = -205, Z = 250, Y = 0, HalfX = 9.0, HalfZ = 8.0, Top = 15.0 },
	{ Id = "CapstanQuayEast", X = 205, Z = 250, Y = 0, HalfX = 9.0, HalfZ = 8.0, Top = 15.0 },
	-- 20–21. Colossal suspended Counterweights hanging off the near Anchor Spires
	{ Id = "CounterweightNW", X = -126, Z = 24, Y = 2, HalfX = 6.0, HalfZ = 6.0, Top = 29.0 },
	{ Id = "CounterweightNE", X = 126, Z = 24, Y = 2, HalfX = 6.0, HalfZ = 6.0, Top = 29.0 },
	-- 22–23. Wall-bolted Gibbet Ledge cages overhanging the sheer east and west chasm walls
	{ Id = "GibbetLedgeWest", X = -342, Z = -100, Y = 36, HalfX = 7.0, HalfZ = 7.0, Top = 24.0 },
	{ Id = "GibbetLedgeEast", X = 342, Z = -100, Y = 20, HalfX = 7.0, HalfZ = 7.0, Top = 24.0 },
	-- 24. The Spireward guard tower behind the far west anchor
	{ Id = "SpirewardGuardKeep", X = -106, Z = -334, Y = 48, HalfX = 12.0, HalfZ = 12.0, Top = 56.0 },
	-- 25. The Undertow central void pool directly below the Keystone
	{ Id = "VoidUndertowCenter", X = 0, Z = -105, Y = -9.5, HalfX = 36.0, HalfZ = 36.0, Top = 4.2 },
	-- 26. The Chain Stair arrival gatehouse straddling Sanctuary -> Basin
	{ Id = "ChainStairGate", X = 0, Z = 314, Y = 8, HalfX = 34.0, HalfZ = 8.0, Top = 32.0, Straddles = true },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AbyssalFloor48.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = H.P
	local _boxAt, rod, lump, light, noCollide = H.boxAt, H.rod, H.lump, H.light, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	local props = 0
	local cover = 0
	local lightsUsed = 0
	local emittersUsed = 0
	local kindsUsed: { [string]: number } = {}
	local reserved: { { number } } = {}

	local function recordTemplate(templateName: string)
		kindsUsed[templateName] = (kindsUsed[templateName] or 0) + 1
	end

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 14 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end

	local function makeDecor(m: Instance?)
		if not m then return end
		noCollide(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d:SetAttribute("SolidScenery", false)
			end
		end
	end

	local function tagDirge(inst: Instance?, tagName: string)
		if not inst then return end
		inst:SetAttribute(tagName, true)
		safeTag(inst, tagName)
	end

	local function tagDetail(m: Instance?)
		if not m then return end
		makeDecor(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				safeTag(d, "TowerDetail")
			end
		end
	end

	local function placeTemplate(
		propKind: string,
		templateName: string,
		cf: CFrame,
		scale: Vector3 | number,
		override: any?,
		isCover: boolean?,
		solid: boolean?,
		dirgeTag: string?,
		fallback: ((c: CFrame) -> ())?
	): Instance?
		local prop: Instance? = nil
		ctx.group(propKind, function()
			prop = ctx.current()
			ctx.tag("OnTerrain", true)
			if ctx.has(templateName) then
				ctx.kitAt(templateName, cf, scale, override)
			elseif fallback then
				fallback(cf)
			else
				local s = if typeof(scale) == "number" then scale else scale.Y
				boxAt(templateName .. "_Proxy", cf * CFrame.new(0, 2.5 * s, 0), V(3.0 * s, 5.0 * s, 3.0 * s), IRON_BLACK, Mat.Metal)
			end
		end)
		recordTemplate(templateName)
		if isCover then
			cover += 1
			tagDetail(prop)
		else
			props += 1
			if not solid then
				makeDecor(prop)
			end
		end
		if dirgeTag and prop then
			tagDirge(prop, dirgeTag)
		end
		return prop
	end

	local function addAshEmitter(pos: Vector3, rate: number, isVoidMote: boolean?)
		if emittersUsed >= 11 then return end
		emittersUsed += 1
		local anchor = ctx.block(if isVoidMote then "VoidMoteAnchor" else "DirgeAshAnchor", V(1, 1, 1), pos, if isVoidMote then VOID_VIOLET else ASH_GREY, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("SolidScenery", false)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = if isVoidMote then "VoidMoteDrift" else "DirgeAshDrift"
		if isVoidMote then
			pe.Color = ColorSequence.new(VOID_DEEP, VOID_VIOLET)
			pe.LightEmission = 0.75
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(0.5, 2.4), NumberSequenceKeypoint.new(1, 0.6) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1.0) })
			pe.Acceleration = V(0, 2.2, -1.5)
		else
			pe.Color = ColorSequence.new(rgb(138, 134, 146), rgb(78, 74, 84))
			pe.LightEmission = 0.0
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0.25) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.8, 0.55), NumberSequenceKeypoint.new(1, 1.0) })
			pe.Acceleration = V(0, 0.9, -2.8) -- drifts north toward the Throne
		end
		pe.Lifetime = NumberRange.new(3.0, 5.5)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1.5, 3.8)
		pe.SpreadAngle = Vector2.new(40, 40)
		pe.RotSpeed = NumberRange.new(-35, 35)
		pe.Parent = anchor
		tagDirge(pe, "DirgeAshEmitter")
	end

	local function buildObsidianPier(name: string, x: number, topY: number, z: number, radius: number)
		local hSpan = math.max(8.0, topY - ABYSS_Y)
		ctx.group(name, function()
			ctx.tag("OnTerrain", true)
			local cap = ctx.cyl(name .. "_Cap", V(x, topY - 0.6, z), radius, 1.2, OBSIDIAN, Mat.Basalt)
			local shaft = ctx.cyl(name .. "_Shaft", V(x, ABYSS_Y + hSpan * 0.5, z), radius * 0.88, hSpan - 1.0, BASALT_DARK, Mat.Basalt)
			local band = ctx.cyl(name .. "_IronBand", V(x, topY - 2.4, z), radius + 0.5, 1.0, IRON_BLACK, Mat.Metal)
			band.CanCollide, band.CanQuery, band.CastShadow = false, false, false
			cap.CanCollide, cap.CanQuery = true, true
			shaft.CanCollide, shaft.CanQuery = true, true
		end)
	end

	-- Ground Y helper for perimeter/basin scatter
	local field = H.field
	local function groundY(x: number, z: number): number
		for id, plat in P do
			if id ~= "Sanctuary" and math.abs(x - plat.X) <= plat.Width * 0.5 and math.abs(z - plat.Z) <= plat.Depth * 0.5 then
				return plat.Y
			end
		end
		if field then
			return (field.Sample(x, z))
		end
		return ABYSS_Y
	end

	local function isSpotFree(x: number, z: number, r: number, skipLaneCheck: boolean?): boolean
		for _, sp in reserved do
			local dx, dz = sp[1] - x, sp[2] - z
			if dx * dx + dz * dz < (sp[3] + r) ^ 2 then
				return false
			end
		end
		for _, camp in ctx.layout.Camps do
			local dx, dz = camp.X - x, camp.Z - z
			if dx * dx + dz * dz < (36 + r) ^ 2 then
				return false
			end
		end
		if not skipLaneCheck and not ctx.footprintClear(x, z, r + 1.5, r + 1.5) then
			return false
		end
		return true
	end

	local function reserve(x: number, z: number, r: number)
		table.insert(reserved, { x, z, r })
		ctx.reserve(x, z, r)
	end

	for _, lm in AbyssalFloor48.Landmarks do
		if not lm.Straddles then
			reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2)
		end
	end

	-- =========================================================================
	-- A. VOID FLOOR & UNDERTOW POOL (strictly at Y = -9.5 inside the chasm!)
	--    31+ studs below Keystone (Y=22) and > 40 studs clear of near/far rims.
	-- =========================================================================
	ctx.group("AbyssalVoidFloor", function()
		ctx.tag("OnTerrain", true)
		local floorBed = boxAt("VoidChasmBed", CFrame.new(V(0, ABYSS_Y - 0.3, -105)), V(680, 0.8, 300), BASALT_DARK, Mat.Basalt)
		makeDecor(floorBed)
	end)

	-- Sculpted undulating VoidPoolMesh discs across the void floor (Y = -9.5)
	for idx, vp in {
		{ X = 0, Z = -105, S = 1.65, Light = true },
		{ X = -105, Z = -105, S = 1.35, Light = true },
		{ X = 105, Z = -105, S = 1.35, Light = true },
		{ X = -55, Z = -42, S = 1.05, Light = false },
		{ X = 55, Z = -42, S = 1.05, Light = false },
		{ X = -55, Z = -168, S = 1.05, Light = false },
		{ X = 55, Z = -168, S = 1.05, Light = false },
	} do
		local m = placeTemplate("AbyssalUndertow", "VoidPoolMesh",
			CFrame.new(V(vp.X, VOID_POOL_Y, vp.Z)) * CFrame.Angles(0, idx * 0.8, 0),
			V(vp.S, 1.0, vp.S), VOID_POOL_TINT, false, false, "DirgeUndertow",
			function(cf)
				local d1 = ctx.cyl("VoidPoolDisc", cf.Position + V(0, 0.4, 0), 34 * vp.S, 0.6, VOID_DEEP, Mat.SmoothPlastic)
				local d2 = ctx.cyl("VoidPoolCore", cf.Position + V(0, 0.8, 0), 18 * vp.S, 0.4, VOID_VIOLET, Mat.Neon, 0.25)
				tagDirge(d1, "DirgeUndertow")
				tagDirge(d2, "DirgeUndertow")
			end)
		if vp.Light then
			local anchor = ctx.block("UndertowLight_" .. idx, V(1, 1, 1), V(vp.X, VOID_POOL_Y + 2.5, vp.Z), VOID_VIOLET, Mat.SmoothPlastic, nil, 1)
			makeDecor(anchor)
			addLight(anchor, VOID_VIOLET, 2.4, 115)
		end
		if idx <= 3 then
			addAshEmitter(V(vp.X, VOID_POOL_Y + 2.0, vp.Z), 5, true)
		end
	end

	-- Thin pale bone-white hairline Rift wound high in the black vault (Y = 278)
	ctx.group("AbyssalSkyVault", function()
		ctx.tag("OnTerrain", true)
		local p0 = ctx.block("VaultRiftA", V(1, 1, 1), V(-180, 278, -60), WARD_GLOW, Mat.SmoothPlastic, nil, 1)
		local p1 = ctx.block("VaultRiftB", V(1, 1, 1), V(180, 278, -140), WARD_GLOW, Mat.SmoothPlastic, nil, 1)
		makeDecor(p0)
		makeDecor(p1)
		local a0 = Instance.new("Attachment"); a0.Parent = p0
		local a1 = Instance.new("Attachment"); a1.Parent = p1
		local b = Instance.new("Beam")
		b.Name = "RiftHairlineWound"
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 2.2
		b.Width1 = 2.2
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(WARD_GLOW)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.25, 0.35),
			NumberSequenceKeypoint.new(0.50, 0.15),
			NumberSequenceKeypoint.new(0.75, 0.35),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		b.Parent = p0
	end)

	-- =========================================================================
	-- B. FOUR ANCHOR SPIRES, COUNTERWEIGHTS & SALTIRE GREAT CHAINS (>= 18 CLEAR)
	-- =========================================================================
	local spireDefs = {
		{ Id = "WestAnchorSpire", X = -112, Y = 26, Z = 8, Yaw = -135, CwX = -126, CwZ = 24 },
		{ Id = "EastAnchorSpire", X = 112, Y = 30, Z = 8, Yaw = 135, CwX = 126, CwZ = 24 },
		{ Id = "FarWestAnchorSpire", X = -114, Y = 38, Z = -256, Yaw = -45, CwX = -128, CwZ = -270 },
		{ Id = "FarEastAnchorSpire", X = 144, Y = 42, Z = -244, Yaw = 45, CwX = 158, CwZ = -258 },
	}
	for idx, sp in spireDefs do
		buildObsidianPier(sp.Id .. "_Pier", sp.X, sp.Y, sp.Z, 13.0)
		local m = placeTemplate(sp.Id, "AnchorSpire",
			CFrame.new(V(sp.X, sp.Y, sp.Z)) * CFrame.Angles(0, math.rad(sp.Yaw), 0),
			1.0, VAHL_48, false, true, nil,
			function(cf)
				boxAt("AnchorSpireShaft", cf * CFrame.new(0, 107, 0), V(16, 214, 16), OBSIDIAN, Mat.Basalt)
				local lamp = lump("AnchorSpireWard", (cf * CFrame.new(0, 38, 12)).Position, V(2, 2.5, 2), WARD_GLOW, Mat.Neon)
				tagDirge(lamp, "DirgeWardlight")
			end)
		if m and idx <= 2 then
			tagDirge(m, "DirgeWardlight")
			local g = H.glowOf(m)
			if g then addLight(g, WARD_GLOW, 2.0, 64) end
		end
		-- Suspended colossal iron counterweight hanging on the outer flank of each spire
		local cwY = if idx <= 2 then 2 else 14
		placeTemplate("Counterweight_" .. idx, "Counterweight",
			CFrame.new(V(sp.CwX, cwY, sp.CwZ)) * CFrame.Angles(0, math.rad(sp.Yaw), 0),
			1.0, VAHL_48, false, false, "DirgeChain",
			function(cf)
				boxAt("CounterweightBody", cf * CFrame.new(0, 12, 0), V(8, 16, 8), IRON_BLACK, Mat.Metal)
			end)
		-- Caged void shard reliquary & coiled bollard at each spire footing
		local relX = sp.X + (if sp.X < 0 then -16 else 16)
		local relZ = sp.Z + (if sp.Z > 0 then -12 else 12)
		if isSpotFree(relX, relZ, 5) then
			reserve(relX, relZ, 5)
			placeTemplate("SpireReliquary_" .. idx, "AbyssReliquaryShrine",
				CFrame.new(V(relX, sp.Y - 2, relZ)) * CFrame.Angles(0, math.rad(sp.Yaw), 0),
				0.42, VAHL_48, false, false, nil)
		end
	end

	-- The Keystone Cage-Platform (Y = 22, open diagonal entries, brightest bone-white Wardlight at Y = 49)
	local ks = placeTemplate("AbyssalChainCage", "KeystoneCage",
		CFrame.new(V(0, 22, -105)), 1.0, VAHL_48, false, false, "DirgeWardlight",
		function(cf)
			for _, p in { V(-25, 11, 0), V(25, 11, 0), V(0, 11, -21), V(0, 11, 21) } do
				boxAt("KeystonePier", cf * CFrame.new(p), V(4, 22, 4), IRON_BLACK, Mat.Metal)
			end
			lump("KeystoneWard", (cf * CFrame.new(0, 27, 0)).Position, V(3.5, 4.5, 3.5), WARD_GLOW, Mat.Neon)
		end)
	if ks then
		local g = H.glowOf(ks)
		if g then addLight(g, WARD_GLOW, 3.2, 88) end
	end

	-- Four Hung Bead Cradles (straddling BeadNW, BeadNE, BeadFW, BeadFE cleanly along diagonal path yaw)
	local beadSpecs = {
		{ Id = "BeadNW", Yaw = -24 },
		{ Id = "BeadNE", Yaw = 24 },
		{ Id = "BeadFW", Yaw = 24 },
		{ Id = "BeadFE", Yaw = -24 },
	}
	for _, bs in beadSpecs do
		local plat = P[bs.Id]
		if plat then
			placeTemplate("AbyssalChainCage", "HungBeadPlatform",
				CFrame.new(V(plat.X, plat.Y, plat.Z)) * CFrame.Angles(0, math.rad(bs.Yaw), 0),
				1.0, VAHL_48, false, false, "DirgeWardlight",
				function(cf)
					boxAt("BeadArch", cf * CFrame.new(0, 25, 0), V(42, 2, 3), IRON_BLACK, Mat.Metal)
				end)
		end
	end

	-- Four Colossal Saltire Great Chains (all chain geometry strictly >= 24 studs above every deck!)
	local function spanGreatChain(name: string, pStart: Vector3, pEnd: Vector3, sag: number, segments: number, scaleThick: number)
		for k = 0, segments - 1 do
			local t0 = k / segments
			local t1 = (k + 1) / segments
			local a = pStart:Lerp(pEnd, t0) - V(0, sag * 4 * t0 * (1 - t0), 0)
			local b = pStart:Lerp(pEnd, t1) - V(0, sag * 4 * t1 * (1 - t1), 0)
			local dVec = b - a
			local len = dVec.Magnitude
			local mid = (a + b) * 0.5
			-- GreatChainSegment runs along local X (~34.5 studs at scale 1)
			local dir = dVec.Unit
			local right = dir:Cross(V(0, 1, 0)).Unit
			local up = right:Cross(dir).Unit
			local rot = CFrame.fromMatrix(mid, dir, up, -right)
			local sx = len / 32.0
			placeTemplate("AbyssalGreatChain", "GreatChainSegment", rot, V(sx, scaleThick, scaleThick),
				VAHL_48, false, false, "DirgeChain",
				function(cf)
					rod("ChainRunProxy", a, b, 1.3 * scaleThick, IRON_BLACK, Mat.Metal)
				end)
		end
	end

	-- Saltire lower chains converging onto KeystoneCage's upper diagonal horns (Y = 46.5 -> 24.5 studs above Keystone!)
	spanGreatChain("SaltireNW", V(-112, 166, 8), V(-21.5, 46.5, -87.5), 24, 4, 1.15)
	spanGreatChain("SaltireNE", V(112, 170, 8), V(21.5, 46.5, -87.5), 24, 4, 1.15)
	spanGreatChain("SaltireFW", V(-21.5, 46.5, -122.5), V(-114, 178, -256), 24, 5, 1.15)
	spanGreatChain("SaltireFE", V(21.5, 46.5, -122.5), V(144, 182, -244), 24, 5, 1.15)

	-- Upper sweeping catenary stay-chains joining the four spires high overhead (Y >= 120, matching the jpg!)
	local function placeCatenarySpan(name: string, a: Vector3, b: Vector3, lowDrop: number)
		local mid = (a + b) * 0.5
		local dVec = b - a
		local flat = V(dVec.X, 0, dVec.Z)
		local span = flat.Magnitude
		local dir = flat.Unit
		local right = dir:Cross(V(0, 1, 0)).Unit
		local lowY = math.min(a.Y, b.Y) - lowDrop
		local cf = CFrame.fromMatrix(V(mid.X, lowY, mid.Z), dir, V(0, 1, 0), -right)
		placeTemplate("AbyssalGreatChain", "GreatChainCatenary", cf, V(span / 55.0, (lowDrop + 12) / 17.3, 1.0),
			VAHL_48, false, false, "DirgeChain",
			function()
				rod("CatenaryProxy", a, b, 1.1, IRON_BLACK, Mat.Metal)
			end)
	end
	placeCatenarySpan("RimStayNear", V(-112, 146, 8), V(112, 150, 8), 22)
	placeCatenarySpan("RimStayFar", V(-114, 158, -256), V(144, 162, -244), 24)
	placeCatenarySpan("SideStayW", V(-112, 134, 8), V(-114, 146, -256), 26)
	placeCatenarySpan("SideStayE", V(112, 138, 8), V(144, 150, -244), 26)

	-- =========================================================================
	-- C. CATENARY BRIDGE UNDERSIDES & GIBBET LEDGE CAGES
	-- =========================================================================
	-- Dress the eight catenary bridge spans from underneath with CatenarySpanDeck (top sits flush under bridge!)
	local catenaryLinks = {
		AnchorNW_BeadNW = true, BeadNW_Keystone = true,
		AnchorNE_BeadNE = true, BeadNE_Keystone = true,
		Keystone_BeadFW = true, Keystone_BeadFE = true,
		BeadFW_AnchorFW = true, BeadFE_AnchorFE = true,
	}
	for _, link in ctx.layout.Links do
		if catenaryLinks[link.Id] then
			local a = V(link.AX, link.AY, link.AZ)
			local b = V(link.BX, link.BY, link.BZ)
			local dVec = b - a
			local len = dVec.Magnitude
			local mid = (a + b) * 0.5
			local cf = CFrame.lookAt(mid - V(0, 4.9, 0), b - V(0, 4.9, 0))
			placeTemplate("CatenaryBridgeFrame", "CatenarySpanDeck", cf, V(1.45, 1.0, math.max(0.8, (len - 6) / 26.0)),
				VAHL_48, false, false, nil)
		end
	end

	-- Wall-bolted Gibbet Ledges overhanging West (-342) and East (+342) chasm walls
	for _, gb in {
		{ X = -342, Y = 36, Z = -100, Yaw = -90, Light = true },
		{ X = -342, Y = 34, Z = -142, Yaw = -90, Light = false },
		{ X = 342, Y = 20, Z = -100, Yaw = 90, Light = true },
		{ X = 342, Y = 18, Z = -58, Yaw = 90, Light = false },
	} do
		buildObsidianPier("GibbetWallPier", gb.X + (if gb.X < 0 then -12 else 12), gb.Y + 26, gb.Z, 10.0)
		local mg = placeTemplate("GibbetCageWall", "GibbetLedgeCage",
			CFrame.new(V(gb.X, gb.Y - 12, gb.Z)) * CFrame.Angles(0, math.rad(gb.Yaw), 0),
			1.0, VAHL_48, false, false, "DirgeChain",
			function(cf)
				boxAt("GibbetProxy", cf * CFrame.new(0, 12, 0), V(5, 18, 5), IRON_BLACK, Mat.Metal)
			end)
		if mg then
			tagDirge(mg, "DirgeWardlight")
			if gb.Light then
				local g = H.glowOf(mg)
				if g then addLight(g, WARD_GLOW, 1.6, 52) end
			end
		end
	end

	-- =========================================================================
	-- D. TERRACE SIGNATURE LANDMARKS & FLANKING VIGNETTES
	-- =========================================================================
	-- 1. The Chain Stair Arrival Gatehouse (Sanctuary -> Basin)
	local sg = placeTemplate("AbyssalSanctuaryGate", "GatehouseArch",
		CFrame.new(V(0, 8, 314)), V(0.88, 1.05, 1.0), VAHL_48, false, false, nil,
		function(cf)
			for _, sx in { -22, 22 } do
				boxAt("ChainGatePier", cf * CFrame.new(sx, 14, 0), V(8, 28, 8), OBSIDIAN, Mat.Basalt)
			end
		end)
	if sg then
		local g = H.glowOf(sg)
		if g then addLight(g, WARD_GLOW, 1.8, 60) end
	end

	-- 2. The Far Gatehouse behind Apex (gold-rimmed Chained Crown sigil, clear of portals & APEX_SANCTUM!)
	buildObsidianPier("FarGatehouse_Pier", 170, 56, -364, 24.0)
	local fg = placeTemplate("FarGatehouse", "FarGatehouse",
		CFrame.new(V(170, 56, -364)), 1.0, VAHL_48, false, true, "DirgeWardlight",
		function(cf)
			boxAt("FarGateProxy", cf * CFrame.new(0, 26, 0), V(54, 52, 16), OBSIDIAN, Mat.Basalt)
			lump("FarGateWard", (cf * CFrame.new(0, 48, 0)).Position, V(3, 3, 3), WARD_GLOW, Mat.Neon)
		end)
	if fg then
		local g = H.glowOf(fg)
		if g then addLight(g, WARD_GLOW, 2.4, 72) end
	end

	-- 3. The Chainwright's Yard (Crossing) — HalfForgedLink on solid east forge-bay extension
	buildObsidianPier("CrossingForgeBay", 58, 12, 115, 16.0)
	local hfl = placeTemplate("ChainwrightForgedLink", "HalfForgedLink",
		CFrame.new(V(58, 12, 115)) * CFrame.Angles(0, math.rad(-90), 0), 1.0, VAHL_48, false, true, "DirgeWardlight",
		function(cf)
			boxAt("HalfForgedProxy", cf * CFrame.new(0, 6, 0), V(20, 12, 12), IRON_BLACK, Mat.Metal)
		end)
	if hfl then
		local g = H.glowOf(hfl)
		if g then addLight(g, WARD_GLOW, 1.6, 54) end
	end
	addAshEmitter(V(58, 15, 115), 5, false)

	-- 4. The Hookward (WestGallery) — HookPulleyRack on solid west bay extension
	buildObsidianPier("HookwardBay", -274, 8, 102, 14.0)
	local hpr = placeTemplate("HookwardPulleyGantry", "HookPulleyRack",
		CFrame.new(V(-274, 8, 102)) * CFrame.Angles(0, math.rad(90), 0), 1.0, VAHL_48, false, true, "DirgeWardlight",
		function(cf)
			boxAt("HookGantryProxy", cf * CFrame.new(0, 7, 0), V(14, 14, 5), IRON_BLACK, Mat.Metal)
		end)
	if hpr then
		local g = H.glowOf(hpr)
		if g then addLight(g, WARD_GLOW, 1.6, 52) end
	end

	-- 5. The Ashgrate (EastGallery) — AshGrateFloor on solid east bay extension + rising ash emitter
	buildObsidianPier("AshgrateBay", 274, 16, 102, 14.0)
	placeTemplate("AshgratePitDeck", "AshGrateFloor",
		CFrame.new(V(274, 16, 102)) * CFrame.Angles(0, math.rad(-90), 0), 1.0, VAHL_48, false, false, nil)
	addAshEmitter(V(274, 17.5, 102), 8, false)
	addAshEmitter(V(224, 17.5, 68), 6, false)

	-- 6. Capstan Quay great seized capstans (far west and east of Basin camps)
	for _, cx in { -205, 205 } do
		placeTemplate("CapstanQuayGreat", "ChainCapstanGreat",
			CFrame.new(V(cx, 0, 250)) * CFrame.Angles(0, math.rad(if cx < 0 then 22 else -22), 0),
			1.0, VAHL_48, false, true, nil)
	end

	-- 7. The Spireward guard tower behind FarWestAnchor
	buildObsidianPier("SpirewardKeep_Pier", -106, 48, -334, 14.0)
	placeTemplate("SpirewardGuardKeep", "ChainTowerRound",
		CFrame.new(V(-106, 48, -334)) * CFrame.Angles(0, math.rad(25), 0), 0.78, VAHL_48, false, true, nil)

	-- =========================================================================
	-- E. LINK DRESSING (every link dressed at both ends with Wardlights, bollards & racks)
	-- =========================================================================
	local dressedWardlights = 0
	for idx, link in ctx.layout.Links do
		local dx, dz = link.BX - link.AX, link.BZ - link.AZ
		local len = math.max(1, math.sqrt(dx * dx + dz * dz))
		local nx, nz = -dz / len, dx / len
		local yaw = math.atan2(dx, dz)
		for epIdx, ep in { { link.AX, link.AY, link.AZ }, { link.BX, link.BY, link.BZ } } do
			for _, side in { -1, 1 } do
				local px = ep[1] + nx * side * (link.Width * 0.5 + 4.5)
				local pz = ep[3] + nz * side * (link.Width * 0.5 + 4.5)
				if isSpotFree(px, pz, 2.5, true) then
					-- Check link endpoint sits on a terrace (skip mid-void ends on Bead edges if outside terrace)
					local onPlat = false
					for _, plat in P do
						if math.abs(px - plat.X) <= plat.Width * 0.5 + 2 and math.abs(pz - plat.Z) <= plat.Depth * 0.5 + 2 and math.abs(plat.Y - ep[2]) <= 2 then
							onPlat = true
							break
						end
					end
					if onPlat then
						reserve(px, pz, 2.5)
						local pick = (idx + epIdx + (if side > 0 then 1 else 0)) % 4
						if pick == 0 then
							local wl = placeTemplate("LinkWardlight", "HangingLantern",
								CFrame.new(V(px, ep[2], pz)) * CFrame.Angles(0, yaw, 0),
								1.15, VAHL_48, false, false, "DirgeWardlight")
							dressedWardlights += 1
							if wl and dressedWardlights <= 3 then
								local g = H.glowOf(wl)
								if g then addLight(g, WARD_GLOW, 1.4, 46) end
							end
						elseif pick == 1 then
							placeTemplate("LinkBollard", "ChainBollard",
								CFrame.new(V(px, ep[2], pz)) * CFrame.Angles(0, yaw, 0),
								0.85, VAHL_48, false, false, nil)
						elseif pick == 2 then
							placeTemplate("LinkChainPost", "BollardRope",
								CFrame.new(V(px, ep[2], pz)) * CFrame.Angles(0, yaw, 0),
								0.95, VAHL_48, false, false, nil)
						else
							placeTemplate("LinkBrazier", "DaisBrazierPedestal",
								CFrame.new(V(px, ep[2], pz)) * CFrame.Angles(0, yaw, 0),
								0.55, VAHL_48, false, false, "DirgeWardlight")
						end
					end
				end
			end
		end
	end

	-- =========================================================================
	-- F. FAR HORIZON: DREADGUARD CITADEL SILHOUETTES, DISTANT SPIRES & COURT WATCHERS
	-- =========================================================================
	local farTowers = {
		{ T = "StormkeepRoundTower", X = -340, Y = 22, Z = -345, S = 1.45, Yaw = 15 },
		{ T = "StormkeepRoundTower", X = 340, Y = 24, Z = -345, S = 1.45, Yaw = -15 },
		{ T = "ChainTowerRound", X = -220, Y = 34, Z = -356, S = 1.15, Yaw = 10 },
		{ T = "ChainTowerRound", X = 40, Y = 36, Z = -356, S = 1.05, Yaw = -12 },
		{ T = "CurtainWallSegment", X = -280, Y = 32, Z = -356, S = 2.2, Yaw = 0 },
		{ T = "CurtainWallSegment", X = -165, Y = 34, Z = -358, S = 2.0, Yaw = 0 },
		{ T = "CurtainWallSegment", X = 290, Y = 30, Z = -356, S = 2.0, Yaw = 0 },
		{ T = "CurtainWallRuins", X = -352, Y = 18, Z = -240, S = 1.4, Yaw = 90 },
		{ T = "CurtainWallRuins", X = 352, Y = 18, Z = -240, S = 1.4, Yaw = -90 },
		{ T = "VaultRibArch", X = -344, Y = -4, Z = -18, S = 0.72, Yaw = 90 },
		{ T = "VaultRibArch", X = 344, Y = -4, Z = -18, S = 0.72, Yaw = -90 },
		{ T = "GothicPillarColonnade", X = -342, Y = 0, Z = 175, S = 0.95, Yaw = 90 },
		{ T = "GothicPillarColonnade", X = 342, Y = 0, Z = 175, S = 0.95, Yaw = -90 },
	}
	for i, ft in farTowers do
		buildObsidianPier("FarLedge_" .. i, ft.X, ft.Y, ft.Z, 14.0)
		placeTemplate("FarCitadelHorizon", ft.T,
			CFrame.new(V(ft.X, ft.Y, ft.Z)) * CFrame.Angles(0, math.rad(ft.Yaw), 0),
			ft.S, VAHL_48, false, false, nil)
	end

	-- Still Vahl court silhouettes on distant high ledges (bow on the Dirge!)
	for i, sil in {
		{ -348, 52, -210, 90 }, { -348, 48, -165, 90 }, { -348, 56, -45, 90 },
		{ 348, 48, -210, -90 }, { 348, 44, -165, -90 }, { 348, 50, -45, -90 },
		{ -255, 62, -356, 0 }, { 8, 60, -356, 0 },
	} do
		ctx.group("DirgeCourtSilhouette_" .. i, function()
			ctx.tag("OnTerrain", true)
			local s = 1.65
			local cf = CFrame.new(V(sil[1], sil[2], sil[3])) * CFrame.Angles(0, math.rad(sil[4]), 0)
			boxAt("SilhouetteCloak", cf * CFrame.new(0, 4.5 * s, 0), V(2.4 * s, 9.0 * s, 1.6 * s), OBSIDIAN, Mat.Basalt)
			boxAt("SilhouetteCrown", cf * CFrame.new(0, 10.0 * s, 0), V(1.6 * s, 2.0 * s, 1.4 * s), IRON_BLACK, Mat.Metal)
			makeDecor(ctx.current())
			tagDirge(ctx.current(), "DirgeSilhouette")
			props += 1
		end)
	end

	-- =========================================================================
	-- G. MULTI-TERRACE VIGNETTES & MULTI-TEMPLATE SCATTER (>= 580 PROPS, <= 11% EACH)
	-- =========================================================================
	local rng = Random.new(48 * 9173)

	-- Curated terrace vignettes matching every terrace's story role (Basin, Galleries, Crossing, Anchors, Gibbets, Spireward, Apex perimeter)
	local terraceProps: { { T: string, X: number, Y: number, Z: number, Yaw: number, S: number, O: any? } } = {
		-- Sanctuary (Chain Stair) flanking Wardlights & bollards
		{ T = "HangingLantern", X = -34, Y = 8, Z = 330, Yaw = 0, S = 1.25 },
		{ T = "HangingLantern", X = 34, Y = 8, Z = 330, Yaw = 0, S = 1.25 },
		{ T = "ChainBollard", X = -44, Y = 8, Z = 334, Yaw = 20, S = 0.95 },
		{ T = "ChainBollard", X = 44, Y = 8, Z = 334, Yaw = -20, S = 0.95 },
		-- Basin (The Capstan Quay): seized winches, capstans, iron ingot pallets, chain hoists, blade/armour racks
		{ T = "ChainWinch", X = -255, Y = 0, Z = 258, Yaw = 18, S = 0.85 },
		{ T = "ChainWinch", X = 255, Y = 0, Z = 258, Yaw = -18, S = 0.85 },
		{ T = "ChainWinch", X = -58, Y = 0, Z = 266, Yaw = 0, S = 0.80 },
		{ T = "ChainWinch", X = 58, Y = 0, Z = 266, Yaw = 0, S = 0.80 },
		{ T = "ChainAnchorBollard", X = -318, Y = 0, Z = 238, Yaw = 90, S = 0.55 },
		{ T = "ChainAnchorBollard", X = 318, Y = 0, Z = 238, Yaw = -90, S = 0.55 },
		{ T = "ChainGalleryRail", X = -325, Y = 0, Z = 272, Yaw = 0, S = 0.85 },
		{ T = "ChainGalleryRail", X = 325, Y = 0, Z = 272, Yaw = 0, S = 0.85 },
		{ T = "ArmourRack", X = -172, Y = 0, Z = 270, Yaw = 165, S = 0.90 },
		{ T = "ArmourRack", X = 172, Y = 0, Z = 270, Yaw = -165, S = 0.90 },
		{ T = "BladeDisplay", X = -156, Y = 0, Z = 270, Yaw = 170, S = 0.95 },
		{ T = "BladeDisplay", X = 156, Y = 0, Z = 270, Yaw = -170, S = 0.95 },
		{ T = "IngotPallet", X = -238, Y = 0, Z = 222, Yaw = 25, S = 0.90 },
		{ T = "IngotPallet", X = 238, Y = 0, Z = 222, Yaw = -25, S = 0.90 },
		-- WestGallery (The Hookward) outer perimeter off-camp
		{ T = "BladeDisplay", X = -252, Y = 8, Z = 128, Yaw = 120, S = 0.95 },
		{ T = "PartsRack", X = -250, Y = 8, Z = 76, Yaw = 65, S = 0.85 },
		{ T = "ChainHoist", X = -254, Y = 8, Z = 86, Yaw = 80, S = 0.72 },
		-- EastGallery (The Ashgrate) outer perimeter off-camp
		{ T = "AshGrateFloor", X = 248, Y = 16, Z = 132, Yaw = -45, S = 0.65 },
		{ T = "CoalHeap", X = 250, Y = 16, Z = 74, Yaw = 30, S = 0.95 },
		{ T = "ShutteredLamp", X = 248, Y = 16, Z = 122, Yaw = -110, S = 1.0 },
		-- Crossing (The Chainwright's Yard) south-west/north-west off-camp corners
		{ T = "PartsRack", X = -38, Y = 12, Z = 90, Yaw = 45, S = 0.85 },
		{ T = "IngotPallet", X = 38, Y = 12, Z = 90, Yaw = -45, S = 0.85 },
		{ T = "ChainHoist", X = 42, Y = 12, Z = 140, Yaw = -135, S = 0.75 },
		-- AnchorNW & AnchorNE Rim Walk bollards & chained lamps
		{ T = "ChainBollard", X = -82, Y = 28, Z = 12, Yaw = 15, S = 0.9 },
		{ T = "ChainBollard", X = 82, Y = 32, Z = 12, Yaw = -15, S = 0.9 },
		{ T = "ChainGalleryRail", X = 0, Y = 30, Z = 50, Yaw = 0, S = 0.85 },
		{ T = "RuneTablet", X = -76, Y = 28, Z = 48, Yaw = 35, S = 0.95 },
		{ T = "RuneTablet", X = 76, Y = 32, Z = 48, Yaw = -35, S = 0.95 },
		-- GibbetW & GibbetE ledges
		{ T = "GibbetCage", X = -316, Y = 36, Z = -94, Yaw = 85, S = 0.75 },
		{ T = "GibbetCage", X = 316, Y = 20, Z = -94, Yaw = -85, S = 0.75 },
		{ T = "ShutteredLamp", X = -314, Y = 36, Z = -116, Yaw = 90, S = 1.0 },
		{ T = "ShutteredLamp", X = 314, Y = 20, Z = -116, Yaw = -90, S = 1.0 },
		-- Spireward (guard-court behind far west anchor)
		{ T = "ArmourRack", X = -82, Y = 48, Z = -340, Yaw = 180, S = 0.95 },
		{ T = "BladeDisplay", X = -42, Y = 48, Z = -340, Yaw = 180, S = 0.95 },
		{ T = "ChainBollard", X = -84, Y = 48, Z = -302, Yaw = 135, S = 0.90 },
		-- Apex (The Far Gate) outer rim off-arena & off-portals
		{ T = "DaisBrazierPedestal", X = 124, Y = 56, Z = -336, Yaw = 0, S = 0.75 },
		{ T = "DaisBrazierPedestal", X = 216, Y = 56, Z = -336, Yaw = 0, S = 0.75 },
		{ T = "ChainAnchorBollard", X = 218, Y = 56, Z = -274, Yaw = -45, S = 0.52 },
		{ T = "AbyssReliquaryShrine", X = 218, Y = 56, Z = -305, Yaw = -90, S = 0.42 },
	}
	for idx, tp in terraceProps do
		if isSpotFree(tp.X, tp.Z, 3.0) then
			reserve(tp.X, tp.Z, 3.5)
			placeTemplate("TerraceVignette_" .. idx, tp.T,
				CFrame.new(V(tp.X, tp.Y, tp.Z)) * CFrame.Angles(0, math.rad(tp.Yaw), 0),
				tp.S, tp.O or VAHL_48, false, false, nil)
		end
	end

	-- Diverse scatter pool across Basin outer margins, outer chasm slopes, perimeter terraces & wall-foot
	-- 28 templates in pool, capped at 24 each -> max single-template share stays <= 4.5% (well under 11%!)
	local scatterPool = {
		{ T = "ObsidianSpire", S0 = 0.35, S1 = 0.65 },
		{ T = "ChainBollard", S0 = 0.65, S1 = 1.05 },
		{ T = "ChainAnchorBollard", S0 = 0.35, S1 = 0.52 },
		{ T = "HangingAbyssChain", S0 = 0.45, S1 = 0.72 },
		{ T = "GreatChainSegment", S0 = 0.32, S1 = 0.48 },
		{ T = "ChainCapstanGreat", S0 = 0.48, S1 = 0.72 },
		{ T = "HalfForgedLink", S0 = 0.42, S1 = 0.68 },
		{ T = "AshGrateFloor", S0 = 0.48, S1 = 0.75 },
		{ T = "HookPulleyRack", S0 = 0.55, S1 = 0.85 },
		{ T = "ChainWinch", S0 = 0.58, S1 = 0.88 },
		{ T = "ChainHoist", S0 = 0.55, S1 = 0.85 },
		{ T = "ChainGalleryRail", S0 = 0.62, S1 = 0.95 },
		{ T = "ArmourRack", S0 = 0.72, S1 = 1.05 },
		{ T = "BladeDisplay", S0 = 0.75, S1 = 1.10 },
		{ T = "PartsRack", S0 = 0.72, S1 = 1.05 },
		{ T = "IngotPallet", S0 = 0.65, S1 = 0.98 },
		{ T = "AbyssReliquaryShrine", S0 = 0.36, S1 = 0.52 },
		{ T = "GibbetCage", S0 = 0.55, S1 = 0.82 },
		{ T = "BellGallowsBracket", S0 = 0.58, S1 = 0.85 },
		{ T = "CrackedTidebell", S0 = 0.62, S1 = 0.92 },
		{ T = "RuneTablet", S0 = 0.75, S1 = 1.15 },
		{ T = "BrokenLancetColumn", S0 = 0.55, S1 = 0.88 },
		{ T = "GothicPillarColonnade", S0 = 0.45, S1 = 0.72 },
		{ T = "BollardRope", S0 = 0.80, S1 = 1.20 },
		{ T = "ShutteredLamp", S0 = 0.85, S1 = 1.15 },
		{ T = "HangingLantern", S0 = 0.95, S1 = 1.28 },
		{ T = "DaisBrazierPedestal", S0 = 0.55, S1 = 0.82 },
		{ T = "BlightTree", S0 = 0.45, S1 = 0.78 },
		{ T = "DeadTree", S0 = 0.52, S1 = 0.85 },
		{ T = "CurtainWallRuins", S0 = 0.48, S1 = 0.75 },
	}
	local scatterCounts: { [string]: number } = {}
	local maxPerTemplate = 24
	local targetProps = 630

	-- Pass 1: Dense rim & terrace-edge dressing along Basin, outer perimeter banks and side ledges
	for attempt = 1, 9500 do
		if props >= targetProps then break end
		local zone = attempt % 4
		local x, z
		if zone == 0 then
			-- Basin broad flanks & south rim
			x = rng:NextNumber(-355, 355)
			z = rng:NextNumber(192, 345)
		elseif zone == 1 then
			-- West & East outer cliff ledges / rim banks
			local side = if attempt % 2 == 0 then -1 else 1
			x = side * rng:NextNumber(255, 360)
			z = rng:NextNumber(-350, 200)
		elseif zone == 2 then
			-- North far rim & Spireward flanks
			x = rng:NextNumber(-340, 340)
			z = rng:NextNumber(-362, -245)
		else
			-- Near-rim outer shoulders (around Crossing, WestGallery, EastGallery)
			x = rng:NextNumber(-330, 330)
			z = rng:NextNumber(-10, 185)
		end

		-- Never place scatter inside the open central void chasm (leave the saltire & Undertow clean!)
		if math.abs(x) < 245 and z > -215 and z < -10 then
			continue
		end
		-- Keep Sanctuary & Apex center arenas completely clean
		if math.abs(x) < 70 and z > 305 then continue end
		if math.abs(x - 170) < 52 and math.abs(z + 305) < 40 then continue end

		local rad = 4.2
		if not isSpotFree(x, z, rad) then continue end

		local y = groundY(x, z)
		-- Keep off steep cliff dropoffs
		local yCheck = groundY(x + 3, z)
		if math.abs(y - yCheck) > 4.5 then continue end

		local pickIdx = ((attempt + rng:NextInteger(0, #scatterPool - 1)) % #scatterPool) + 1
		local spec = scatterPool[pickIdx]
		if (scatterCounts[spec.T] or 0) >= maxPerTemplate then continue end

		local sc = rng:NextNumber(spec.S0, spec.S1)
		local yaw = rng:NextNumber(0, 360)
		local ov = if spec.T == "ShutteredLamp" then SHUTTER_TINT else VAHL_48
		reserve(x, z, rad * 0.85)
		placeTemplate("AbyssalProp_" .. props, spec.T,
			CFrame.new(V(x, y - 0.25, z)) * CFrame.Angles(0, math.rad(yaw), 0),
			sc, ov, false, false, nil)
		scatterCounts[spec.T] = (scatterCounts[spec.T] or 0) + 1
	end

	-- Pass 2: Ground Cover clumps tagged TowerDetail (>= 460 clumps of ash, rubble, void shards, scrap)
	local coverPool = {
		{ T = "BoulderCluster", S0 = 0.45, S1 = 0.88 },
		{ T = "RuinRubble", S0 = 0.50, S1 = 0.95 },
		{ T = "VoidShards", S0 = 0.55, S1 = 1.05 },
		{ T = "CoalHeap", S0 = 0.40, S1 = 0.78 },
		{ T = "ScrapHeap", S0 = 0.40, S1 = 0.75 },
		{ T = "ForgeScrap", S0 = 0.45, S1 = 0.82 },
		{ T = "StoneUrn", S0 = 0.55, S1 = 0.90 },
		{ T = "ArchPierSegment", S0 = 0.45, S1 = 0.75 },
	}
	local targetCover = 470
	for attempt = 1, 7000 do
		if cover >= targetCover then break end
		local x = rng:NextNumber(-355, 355)
		local z = rng:NextNumber(-362, 345)
		if math.abs(x) < 245 and z > -215 and z < -10 then continue end
		if math.abs(x) < 68 and z > 308 then continue end
		if math.abs(x - 170) < 48 and math.abs(z + 305) < 36 then continue end

		local rad = 2.2
		if not isSpotFree(x, z, rad) then continue end

		local y = groundY(x, z)
		local spec = coverPool[(attempt % #coverPool) + 1]
		local sc = rng:NextNumber(spec.S0, spec.S1)
		local yaw = rng:NextNumber(0, 360)
		reserve(x, z, 1.8)
		placeTemplate("AbyssalCover_" .. cover, spec.T,
			CFrame.new(V(x, y - 0.15, z)) * CFrame.Angles(0, math.rad(yaw), 0),
			sc, VAHL_48, true, false, nil)
	end

	local distinctTemplates = 0
	for _ in kindsUsed do
		distinctTemplates += 1
	end

	ctx.setAttribute("PlacedPropCount", props)
	ctx.setAttribute("GroundCoverCount", cover)
	ctx.setAttribute("DistinctTemplateCount", distinctTemplates)
	ctx.setAttribute("SetPieceLightCount", lightsUsed)
	ctx.setAttribute("AbyssalFloor", 48)
end

return AbyssalFloor48
