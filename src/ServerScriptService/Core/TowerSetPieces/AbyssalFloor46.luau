--!strict
-- Hand-authored set pieces for Abyssal Throne Floor 46: Abyssal Descent (abyssal:1, INTRODUCTION).
-- Design: docs/prompts/abyssal-throne-floor-layouts-prompt.md (Floor 46) & reference/Abyssal Throne 46.jpg.
--
-- Where the dark first catches what falls from the Archive above: the Fallstair opens onto the Fallstrand
-- littered with shattered Halcyr bookcases, brass armillary rings, fallen Index Lamps, and the half-written
-- "unwritten" page pinned to an obsidian spike reading "Vharos" in crimson ink. Ahead, braided violet
-- Undertow ribbons flow uphill between sculpted basalt eyots crossed on iron ChainFords, past Reaving Eyot,
-- the Ford of Pages, The Drift, Gallows Eyot, Wreck Shoal, Bonebar, the Weir of Hooks, and The Lip,
-- pouring upward into the black vault at the 172-stud Abyssal Upfall behind the back-west Apex under the
-- Pale Rift wound overhead.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)
local AbyssalCollision = require(script.Parent.AbyssalCollision)

local AbyssalFloor46 = {}

local V = Vector3.new
local rgb = Color3.fromRGB
local Mat = Enum.Material

export type Landmark = InfernalFoundry.Landmark

local function swatch(r: number, g: number, b: number, mat: Enum.Material, trans: number?): any
	return table.freeze({ Color = rgb(r, g, b), Material = mat, Transparency = trans })
end

local function tinted(base: any, changes: { [string]: any }): any
	local o = table.clone(base)
	for role, s in changes do
		o[role] = s
	end
	return table.freeze(o)
end

-- Vahl Abyssal palette (§5.4 & §5.7):
-- Walk-surface glow is strictly bone-white or pale silver (never crimson/orange/violet Neon near walkways).
-- Crimson appears ONLY on matte Fabric silk (wine 118, 22, 36) or matte/low-emission Glass geode cores.
local VAHL_TINT = table.freeze({
	STONE = swatch(24, 22, 30, Mat.Basalt),
	ALT = swatch(216, 210, 196, Mat.Marble),
	METAL = swatch(40, 38, 46, Mat.Metal),
	TRIM = swatch(62, 60, 70, Mat.Metal),
	SILK = swatch(118, 22, 36, Mat.Fabric),
	ACCENT = swatch(176, 140, 66, Mat.Metal),
	GLOW = swatch(244, 238, 222, Mat.Neon),
	CRYSTAL = swatch(142, 22, 34, Mat.Glass, 0.14),
	MOSS = swatch(66, 62, 72, Mat.Slate),
	WOOD = swatch(42, 30, 26, Mat.Wood),
})

local WARDLIGHT_TINT = tinted(VAHL_TINT, {
	GLOW = swatch(244, 238, 222, Mat.Neon),
})

local SILVER_WARD_TINT = tinted(VAHL_TINT, {
	GLOW = swatch(226, 228, 236, Mat.Neon),
	ACCENT = swatch(192, 188, 178, Mat.Metal),
})

local GEODE_TINT = tinted(VAHL_TINT, {
	CRYSTAL = swatch(142, 22, 34, Mat.Glass, 0.14),
	STONE = swatch(20, 18, 26, Mat.Basalt),
	MOSS = swatch(56, 52, 62, Mat.Slate),
})

local SILK_TINT = tinted(VAHL_TINT, {
	SILK = swatch(118, 22, 36, Mat.Fabric),
	ALT = swatch(224, 218, 204, Mat.Fabric),
})

local BONE_TINT = tinted(VAHL_TINT, {
	STONE = swatch(210, 204, 190, Mat.Marble),
	TRIM = swatch(174, 168, 156, Mat.Limestone),
	GLOW = swatch(244, 238, 222, Mat.Neon),
})

local ASH_TINT = tinted(VAHL_TINT, {
	STONE = swatch(34, 32, 40, Mat.Basalt),
	MOSS = swatch(74, 70, 80, Mat.Slate),
	ALT = swatch(228, 222, 208, Mat.Fabric),
})

-- Undertow lives exclusively in carved beds (Y <= -7.2, >= 7.2 studs below Basin and >= 11 studs below eyots/bridges).
local UNDERTOW_TINT = tinted(VAHL_TINT, {
	STONE = swatch(20, 18, 26, Mat.Basalt),
	CRYSTAL = swatch(98, 42, 182, Mat.Glass, 0.18),
	GLOW = swatch(132, 68, 224, Mat.Neon),
})

-- UpfallColumn keeps CRYSTAL as translucent Glass (lower/mid) and GLOW Neon strictly above local z = 78 (Y >= 70).
local UPFALL_TINT = tinted(VAHL_TINT, {
	STONE = swatch(22, 20, 28, Mat.Basalt),
	CRYSTAL = swatch(132, 68, 224, Mat.Glass, 0.20),
	GLOW = swatch(164, 96, 244, Mat.Neon),
})

local FAR_VAULT_TINT = tinted(VAHL_TINT, {
	STONE = swatch(16, 15, 22, Mat.Basalt),
	METAL = swatch(26, 24, 34, Mat.Metal),
	TRIM = swatch(36, 34, 46, Mat.Metal),
	GLOW = swatch(226, 228, 236, Mat.Neon),
})

AbyssalFloor46.Tints = table.freeze({
	Base = VAHL_TINT,
	Wardlight = WARDLIGHT_TINT,
	SilverWard = SILVER_WARD_TINT,
	Geode = GEODE_TINT,
	Silk = SILK_TINT,
	Bone = BONE_TINT,
	Ash = ASH_TINT,
	Undertow = UNDERTOW_TINT,
	Upfall = UPFALL_TINT,
	FarVault = FAR_VAULT_TINT,
})

local OBSIDIAN = rgb(24, 22, 30)
local OBSIDIAN_DARK = rgb(16, 14, 22)
local IRON_DARK = rgb(40, 38, 46)
local CHAIN_IRON = rgb(62, 60, 70)
local BONE_MARBLE = rgb(216, 210, 196)
local VELLUM_PAGE = rgb(232, 224, 206)
local WINE_SILK = rgb(118, 22, 36)
local OLD_GOLD = rgb(176, 140, 66)
local ASH_GREY = rgb(66, 62, 72)
local GEODE_CRIMSON = rgb(142, 22, 34)
local BONE_LIGHT = rgb(244, 238, 222)
local SILVER_LIGHT = rgb(226, 228, 236)
local UNDERTOW_VIOLET = rgb(132, 68, 224)
local UNDERTOW_DEEP = rgb(98, 42, 182)
local HORIZON_CRIMSON = rgb(138, 28, 48)

-- Floor 46's 20 landmark footprints (local floor space inside 640 x 640 x 240 room).
-- Every non-straddling landmark clears all 19 links, 2 return ramps, 5 camps, and 2 portals.
AbyssalFloor46.Landmarks = table.freeze({
	-- 1. Colossal Abyssal Upfall behind the back-west Apex (Y = -8, Top = 172 -> Y = 164, clear of portals Z = -272)
	{ Id = "AbyssalUpfall", X = -168, Z = -304, Y = -8, HalfX = 14.0, HalfZ = 14.0, Top = 172.0 },
	-- 2. Pale Rift Wound high overhead in the Black Vault shedding fluttering Halcyr pages
	{ Id = "PaleRiftWound", X = 0, Z = -40, Y = 215, HalfX = 95.0, HalfZ = 14.0, Top = 18.0, Straddles = true },
	-- 3. The "unwritten" page pinned to an obsidian spike beside The Fallstair reading "Vharos" in crimson ink
	{ Id = "VharosUnwrittenPage", X = -46, Z = 268, Y = 8, HalfX = 3.5, HalfZ = 3.5, Top = 10.5 },
	-- 4. Fallstrand fallen Archive bookcase wreck (west-center, clear of causeway & BASIN_WEST camp)
	{ Id = "FallstrandArchiveWreck", X = -58, Z = 180, Y = 0, HalfX = 7.5, HalfZ = 6.0, Top = 7.5 },
	-- 5. Fallstrand fallen brass armillary sphere (east-center, clear of causeway & BASIN_EAST camp)
	{ Id = "FallstrandArmillary", X = 58, Z = 184, Y = 0, HalfX = 7.0, HalfZ = 7.0, Top = 16.0 },
	-- 6. Fallstrand toppled Index Lamp & spilled folio drift
	{ Id = "FallstrandIndexLamp", X = -50, Z = 212, Y = 0, HalfX = 4.0, HalfZ = 4.0, Top = 6.5 },
	-- 7. Reaving Eyot hooked-blade rack (south rim of WestGallery, clear of camp & ChasmWest return link)
	{ Id = "ReavingEyotRack", X = -189, Z = 95, Y = 8, HalfX = 5.5, HalfZ = 3.0, Top = 10.2 },
	-- 8. Reaving Eyot Dreadguard execution block (NW corner of WestGallery)
	{ Id = "ReavingExecutionBlock", X = -215, Z = 20, Y = 8, HalfX = 4.5, HalfZ = 4.0, Top = 9.0 },
	-- 9. Reaving Eyot sentry gibbet cage (outer west basalt shelf of WestGallery)
	{ Id = "ReavingSentryGibbet", X = -222, Z = 34, Y = 8, HalfX = 3.0, HalfZ = 4.5, Top = 22.8 },
	-- 10. Ashbar split obsidian Trench Geode (NE corner of EastGallery)
	{ Id = "AshbarGeodeCluster", X = 215, Z = 24, Y = 4, HalfX = 5.0, HalfZ = 4.5, Top = 7.5 },
	-- 11. Ford of Pages fallen shelf & drifting Halcyr pages (Crossing outer west rim)
	{ Id = "FordOfPagesWreck", X = -44, Z = 68, Y = 12, HalfX = 6.0, HalfZ = 5.0, Top = 7.5 },
	-- 12. Cinder Eyot split blood-red obsidian geode (EyotW north tip)
	{ Id = "CinderEyotGeode", X = -114, Z = -90, Y = 16, HalfX = 5.0, HalfZ = 4.5, Top = 7.5 },
	-- 13. The Drift raft of fallen shelving wedged on EyotC west flank
	{ Id = "TheDriftShelvingRaft", X = -34, Z = -55, Y = 14, HalfX = 5.5, HalfZ = 5.0, Top = 8.0 },
	-- 14. Gallows Eyot upstream-facing iron gibbet row (EyotE north tip)
	{ Id = "GallowsEyotGibbet", X = 114, Z = -90, Y = 20, HalfX = 3.0, HalfZ = 4.5, Top = 22.8 },
	-- 15. Wreck Shoal shattered Halcyr stack (ShoalW west flank)
	{ Id = "WreckShoalStack", X = -254, Z = -126, Y = 22, HalfX = 6.0, HalfZ = 5.5, Top = 12.0 },
	-- 16. Midbraid reliquary shrine (ShoalC west flank)
	{ Id = "MidbraidReliquary", X = -42, Z = -168, Y = 24, HalfX = 6.5, HalfZ = 6.5, Top = 20.0 },
	-- 17. Bonebar fallen Vahl marble statue hand & ossuary rubble (ShoalE south-east rim)
	{ Id = "BonebarFallenHand", X = 215, Z = -76, Y = 28, HalfX = 5.5, HalfZ = 5.5, Top = 9.5 },
	-- 18. Weir of Hooks dredging iron arch (HeadE north rim)
	{ Id = "WeirOfHooksSpan", X = 160, Z = -284, Y = 32, HalfX = 11.0, HalfZ = 3.5, Top = 14.8 },
	-- 19. The Lip Chained Crown monolith keystone (HeadC north lip)
	{ Id = "TheLipKeystone", X = 25, Z = -294, Y = 30, HalfX = 5.5, HalfZ = 4.0, Top = 19.0 },
	-- 20. Main Undertow violet braid channel in the carved central bed (Y = -7.2)
	{ Id = "UndertowBraidMain", X = -55, Z = 10, Y = -7.2, HalfX = 10.5, HalfZ = 21.0, Top = 1.8 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

local function tagHierarchy(inst: Instance?, tagName: string)
	if not inst then return end
	safeTag(inst, tagName)
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			safeTag(d, tagName)
		end
	end
end

function AbyssalFloor46.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = H.P
	local _boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	local rng = Random.new(46001)
	local lightsUsed = 0
	local emittersUsed = 0
	local propCount = 0
	local coverCount = 0
	local usedTemplates: { [string]: number } = {}
	local placedSpots: { { number } } = {}

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 14 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end
	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
	end
	-- Walk-through dressing: no collision, queries, touches or shadows.
	local function ghost(m: Instance?)
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
	-- A placed prop: overhead, sky, glow, hanging and small pieces become ghosts; everything else a player can
	-- walk into keeps its collision (AbyssalCollision).
	local function makeDecor(m: Instance?)
		if not m then return end
		if AbyssalCollision.StaysSolid(m) then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanTouch = false
				end
			end
			return
		end
		ghost(m)
	end
	local function tagDetail(m: Instance?)
		if not m then return end
		ghost(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				safeTag(d, "TowerDetail")
			end
		end
	end

	-- Clearance helpers mirroring TowerLayout.Lanes and CampHitTest so nothing ever blocks lanes, camps, or portals.
	local laneSegments: { { number } } = {}
	local function addLaneSeg(ax: number, az: number, bx: number, bz: number, hw: number, minY: number, maxY: number)
		table.insert(laneSegments, { ax, az, bx, bz, hw, minY, maxY })
	end
	for _, link in ctx.layout.Links do
		local minY = math.min(link.AY, link.BY) - 2
		local maxY = math.max(link.AY, link.BY) + 18
		addLaneSeg(link.AX, link.AZ, link.BX, link.BZ, link.Width * 0.5 + 3.5, minY, maxY)
		for _, padName in { "LandingA", "LandingB" } do
			local pad = link[padName]
			if pad then
				addLaneSeg(pad.AX, pad.AZ, pad.BX, pad.BZ, pad.Width * 0.5 + 3.5, minY, maxY)
			end
		end
	end
	for _, link in ctx.layout.ReturnLinks do
		local minY = math.min(link.AY, link.BY) - 2
		local maxY = math.max(link.AY, link.BY) + 18
		addLaneSeg(link.AX, link.AZ, link.BX, link.BZ, link.Width * 0.5 + 3.5, minY, maxY)
	end
	if P.Basin then
		addLaneSeg(0, P.Basin.Z + P.Basin.Depth * 0.5, 0, P.Basin.Z - P.Basin.Depth * 0.5, 22, P.Basin.Y - 2, P.Basin.Y + 18)
	end
	if P.Sanctuary then
		addLaneSeg(0, P.Sanctuary.Z - 10, 0, P.Sanctuary.Z - P.Sanctuary.Depth * 0.5, 20, P.Sanctuary.Y - 2, P.Sanctuary.Y + 18)
	end
	local portals = { { -134, 40, -272 }, { -166, 40, -272 } }

	local function distSqToSeg(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		if len2 < 1e-4 then
			return (px - ax) ^ 2 + (pz - az) ^ 2
		end
		local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1)
		local cx, cz = ax + dx * t, az + dz * t
		return (px - cx) ^ 2 + (pz - cz) ^ 2
	end

	local function isSpotFree(x: number, z: number, r: number, y: number?, ignoreSpacing: boolean?): boolean
		if math.abs(x) + r > 312 or math.abs(z) + r > 312 then
			return false
		end
		local checkY = y or (H.surfaceAt(x, z))
		for _, camp in ctx.layout.Camps do
			if math.abs(checkY - camp.Y) < 20 then
				if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (36 + r) ^ 2 then
					return false
				end
			end
		end
		for _, pt in portals do
			if math.abs(checkY - pt[2]) < 20 then
				if (pt[1] - x) ^ 2 + (pt[3] - z) ^ 2 < (12 + r) ^ 2 then
					return false
				end
			end
		end
		for _, seg in laneSegments do
			if checkY >= seg[6] and checkY <= seg[7] then
				if distSqToSeg(x, z, seg[1], seg[2], seg[3], seg[4]) < (seg[5] + r) ^ 2 then
					return false
				end
			end
		end
		if not ignoreSpacing then
			for _, sp in placedSpots do
				if math.abs((sp[4] or checkY) - checkY) < 16 then
					if (sp[1] - x) ^ 2 + (sp[2] - z) ^ 2 < (sp[3] + r) ^ 2 then
						return false
					end
				end
			end
		end
		return true
	end

	-- Part-built fallbacks for every new F46 and reused template (used only before kit import).
	local function fbChainedCrown(cf: CFrame, s: number)
		boxAt("KeystonePlinth", cf * CFrame.new(0, 0.8 * s, 0), V(11 * s, 1.6 * s, 6.5 * s), BONE_MARBLE, Mat.Marble)
		boxAt("KeystoneMonolith", cf * CFrame.new(0, 9.2 * s, 0), V(9.2 * s, 15.2 * s, 4.6 * s), OBSIDIAN, Mat.Basalt)
		boxAt("KeystoneCrownSigil", cf * CFrame.new(0, 10.6 * s, -2.5 * s), V(3.2 * s, 3.2 * s, 0.5 * s), OLD_GOLD, Mat.Metal)
	end
	local function fbWardlight(cf: CFrame, s: number)
		boxAt("WardPost", cf * CFrame.new(0, 5.5 * s, 0), V(0.7 * s, 11 * s, 0.7 * s), IRON_DARK, Mat.Metal)
		boxAt("WardArm", cf * CFrame.new(0, 11.0 * s, -1.2 * s), V(0.5 * s, 0.5 * s, 2.8 * s), IRON_DARK, Mat.Metal)
		boxAt("WardFlame", cf * CFrame.new(0, 9.4 * s, -2.4 * s), V(1.1 * s, 1.5 * s, 1.1 * s), BONE_LIGHT, Mat.Neon)
	end
	local function fbGibbet(cf: CFrame, s: number)
		boxAt("GibbetPost", cf * CFrame.new(0, 10.5 * s, 1.8 * s), V(1.1 * s, 21 * s, 1.1 * s), IRON_DARK, Mat.Metal)
		boxAt("GibbetJib", cf * CFrame.new(0, 20 * s, -0.6 * s), V(0.9 * s, 0.9 * s, 6.2 * s), IRON_DARK, Mat.Metal)
		boxAt("GibbetCageBox", cf * CFrame.new(0, 12.4 * s, -3.2 * s), V(3.4 * s, 5.6 * s, 3.4 * s), CHAIN_IRON, Mat.Metal, 0.35)
	end
	local function fbGeode(cf: CFrame, s: number)
		lump("GeodeShellL", (cf * CFrame.new(-2.0 * s, 2.8 * s, 0)).Position, V(5.2 * s, 6.0 * s, 5.8 * s), OBSIDIAN, Mat.Basalt)
		lump("GeodeShellR", (cf * CFrame.new(2.0 * s, 2.8 * s, 0)).Position, V(5.2 * s, 6.0 * s, 5.8 * s), OBSIDIAN, Mat.Basalt)
		boxAt("GeodeCore", cf * CFrame.new(0, 3.2 * s, 0), V(2.4 * s, 4.6 * s, 2.4 * s), GEODE_CRIMSON, Mat.Glass, 0.14)
	end
	local function fbReavingRack(cf: CFrame, s: number)
		boxAt("ReavFrame", cf * CFrame.new(0, 4.8 * s, 0), V(10 * s, 9.2 * s, 1.8 * s), IRON_DARK, Mat.Metal)
		boxAt("ReavCape", cf * CFrame.new(4.2 * s, 5.6 * s, 0.6 * s), V(2.2 * s, 4.4 * s, 0.3 * s), WINE_SILK, Mat.Fabric)
	end
	local function fbExecBlock(cf: CFrame, s: number)
		boxAt("ExecPlinth", cf * CFrame.new(0, 1.0 * s, 0), V(8.2 * s, 2.0 * s, 7.2 * s), OBSIDIAN, Mat.Basalt)
		ctx.cyl("ExecStump", (cf * CFrame.new(0, 3.3 * s, 0)).Position, 2.2 * s, 2.6 * s, OBSIDIAN_DARK, Mat.Basalt)
		boxAt("ExecCleaver", cf * CFrame.new(0.4 * s, 5.6 * s, 0), V(0.35 * s, 3.6 * s, 2.8 * s), CHAIN_IRON, Mat.Metal)
	end
	local function fbWeir(cf: CFrame, s: number)
		for _, sx in { -9.0, 9.0 } do
			boxAt("WeirPier", cf * CFrame.new(sx * s, 6.5 * s, 0), V(2.8 * s, 13 * s, 3.8 * s), IRON_DARK, Mat.Metal)
		end
		boxAt("WeirBeam", cf * CFrame.new(0, 11.8 * s, 0), V(21 * s, 1.6 * s, 2.2 * s), IRON_DARK, Mat.Metal)
	end
	local function fbWreck(cf: CFrame, s: number)
		lump("WreckAsh", (cf * CFrame.new(0, 0.9 * s, 0)).Position, V(12 * s, 2.0 * s, 9 * s), ASH_GREY, Mat.Slate)
		boxAt("WreckCase", cf * CFrame.new(0, 3.0 * s, 0) * CFrame.Angles(math.rad(-22), 0, math.rad(12)), V(9.5 * s, 2.2 * s, 5.8 * s), rgb(42, 30, 26), Mat.Wood)
	end
	local function fbGeneric(name: string, col: Color3, mat: Enum.Material, sz: Vector3): (CFrame) -> ()
		return function(cf: CFrame)
			boxAt(name .. "Fb", cf * CFrame.new(0, sz.Y * 0.5, 0), sz, col, mat)
		end
	end

	local fallbacks: { [string]: (CFrame, number) -> () } = {
		ChainFordSpan = function(cf, s) boxAt("FordSpanFb", cf * CFrame.new(0, 1.0 * s, 0), V(14 * s, 2.0 * s, 24 * s), IRON_DARK, Mat.Metal) end,
		ChainPostIron = function(cf, s) boxAt("ChainPostFb", cf * CFrame.new(0, 5.2 * s, 0), V(3.2 * s, 10.4 * s, 3.2 * s), IRON_DARK, Mat.Metal) end,
		EyotSlabS = function(cf, s) ctx.cyl("EyotSFb", (cf * CFrame.new(0, 7 * s, 0)).Position, 14 * s, 14 * s, OBSIDIAN, Mat.Basalt) end,
		EyotSlabM = function(cf, s) ctx.cyl("EyotMFb", (cf * CFrame.new(0, 8 * s, 0)).Position, 22 * s, 16 * s, OBSIDIAN, Mat.Basalt) end,
		EyotSlabL = function(cf, s) ctx.cyl("EyotLFb", (cf * CFrame.new(0, 9 * s, 0)).Position, 30 * s, 18 * s, OBSIDIAN, Mat.Basalt) end,
		ReavingRack = fbReavingRack,
		VahlGibbetCage = fbGibbet,
		ExecutionBlock = fbExecBlock,
		WeirOfHooks = fbWeir,
		FallenStackWreck = fbWreck,
		ObsidianGeodeSplit = fbGeode,
		WardlightCage = fbWardlight,
		ChainedCrownKeystone = fbChainedCrown,
		UndertowRibbon = function(cf, s) boxAt("UndertowFb", cf * CFrame.new(0, 0.7 * s, 0), V(18 * s, 1.4 * s, 40 * s), UNDERTOW_DEEP, Mat.Glass, 0.2) end,
		UpfallColumn = function(cf, s) ctx.cyl("UpfallFb", (cf * CFrame.new(0, 84 * s, 0)).Position, 14 * s, 168 * s, UNDERTOW_VIOLET, Mat.Glass, 0.25) end,
		ObsidianSpire = fbGeneric("Spire", OBSIDIAN, Mat.Basalt, V(14, 48, 14)),
		HangingAbyssChain = fbGeneric("AbyssChain", CHAIN_IRON, Mat.Metal, V(24, 12, 2)),
		AbyssReliquaryShrine = fbGeneric("Reliquary", OBSIDIAN, Mat.Basalt, V(14, 20, 12)),
		ChainAnchorBollard = fbGeneric("Bollard", IRON_DARK, Mat.Metal, V(12, 18, 12)),
		ChainTowerRound = fbGeneric("ChainTower", OBSIDIAN, Mat.Basalt, V(22, 54, 22)),
		GatehouseArch = fbGeneric("GateArch", OBSIDIAN, Mat.Basalt, V(36, 24, 10)),
		CurtainWallRuins = fbGeneric("CurtainWall", OBSIDIAN, Mat.Basalt, V(24, 14, 6)),
		VaultRibArch = fbGeneric("VaultRib", IRON_DARK, Mat.Metal, V(30, 56, 10)),
		GothicPillarColonnade = fbGeneric("GothicPillar", OBSIDIAN, Mat.Basalt, V(9, 32, 9)),
		HangingLantern = fbWardlight,
		StoneUrn = fbGeneric("StoneUrn", BONE_MARBLE, Mat.Marble, V(4, 5.5, 4)),
		RuinRubble = fbGeneric("RuinRubble", ASH_GREY, Mat.Slate, V(7, 3.5, 7)),
		BoulderCluster = fbGeneric("Boulders", OBSIDIAN, Mat.Basalt, V(8, 3.2, 6)),
		BookcaseCurved = fbGeneric("Bookcase", rgb(42, 30, 26), Mat.Wood, V(14, 12, 4.5)),
		TomeStack = fbGeneric("TomeStack", VELLUM_PAGE, Mat.Fabric, V(5, 3, 3)),
		CalamusArmillary = fbGeneric("Armillary", OLD_GOLD, Mat.Metal, V(12, 18, 12)),
		ArmourRack = fbGeneric("ArmourRack", IRON_DARK, Mat.Metal, V(7, 8, 3)),
		BladeDisplay = fbGeneric("BladeDisplay", CHAIN_IRON, Mat.Metal, V(7, 8, 2.5)),
		GibbetCage = fbGibbet,
	}

	local function placeProp(kind: string, kitName: string, x: number, z: number, yawDeg: number, s: number, override: any?, y: number?, radius: number?, recordSpot: boolean?, roll: CFrame?, dirgeTag: string?): Instance?
		local fb = fallbacks[kitName]
		local m = piece(kind, x, z, yawDeg, kitName, s, override, function(cf)
			if fb then fb(cf, s) end
		end, y, roll)
		if m then
			pin(m)
			usedTemplates[kitName] = (usedTemplates[kitName] or 0) + 1
			propCount += 1
			if recordSpot ~= false then
				table.insert(placedSpots, { x, z, radius or 4.0, y or (H.surfaceAt(x, z)) })
			end
			if dirgeTag then
				tagHierarchy(m, dirgeTag)
			end
		end
		return m
	end

	-- Helper: Chained Crown Wine-Silk Banner (Mat.Fabric, never Neon!)
	local function placeChainedBanner(name: string, pos: Vector3, yawDeg: number, scale: number)
		local s = scale
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		ctx.group(name, function()
			boxAt("BannerPole", cf * CFrame.new(0, 8.5 * s, 0), V(0.45 * s, 17.0 * s, 0.45 * s), IRON_DARK, Mat.Metal)
			boxAt("BannerCrossbar", cf * CFrame.new(0, 15.6 * s, 0), V(5.2 * s, 0.35 * s, 0.35 * s), CHAIN_IRON, Mat.Metal)
			boxAt("BannerSpearTip", cf * CFrame.new(0, 17.6 * s, 0), V(0.6 * s, 1.4 * s, 0.6 * s), OLD_GOLD, Mat.Metal)
			-- Matte deep wine-crimson silk cloth (118, 22, 36)
			boxAt("BannerCloth", cf * CFrame.new(0, 10.6 * s, 0.25 * s), V(4.2 * s, 9.6 * s, 0.22 * s), WINE_SILK, Mat.Fabric)
			-- Bone-white Chained Crown sigil on front & back of banner (matte Fabric/Metal)
			ctx.ring("BannerChainRing", (cf * CFrame.new(0, 11.2 * s, 0.40 * s)).Position, 1.35 * s, 0.16 * s, SILVER_LIGHT, Mat.Metal, CFrame.Angles(0, math.rad(yawDeg), 0), 0, math.pi * 2, 10)
			boxAt("BannerCrownBand", cf * CFrame.new(0, 10.8 * s, 0.42 * s), V(1.3 * s, 0.35 * s, 0.18 * s), OLD_GOLD, Mat.Metal)
			for _, sx in { -0.5, 0, 0.5 } do
				boxAt("BannerCrownSpike", cf * CFrame.new(sx * s, 11.35 * s, 0.42 * s), V(0.24 * s, 0.85 * s, 0.18 * s), OLD_GOLD, Mat.Metal)
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- Helper: Particle emitters (capped <= 10)
	local function addEmitter(name: string, pos: Vector3, col0: Color3, col1: Color3, size0: number, size1: number, rate: number, speedMin: number, speedMax: number, accel: Vector3, lightEmission: number)
		if emittersUsed >= 10 then return end
		emittersUsed += 1
		local anchor = ctx.block(name .. "_Anchor", V(1, 1, 1), pos, col0, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
		anchor:SetAttribute("DirgeAshEmitter", true)
		safeTag(anchor, "DirgeAshEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = name
		pe.Color = ColorSequence.new(col0, col1)
		pe.LightEmission = lightEmission
		pe.LightInfluence = if lightEmission > 0 then 0 else 1
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size0),
			NumberSequenceKeypoint.new(0.5, (size0 + size1) * 0.55),
			NumberSequenceKeypoint.new(1, size1),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.75, 0.45),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		pe.Lifetime = NumberRange.new(3.2, 5.6)
		pe.Rate = rate
		pe.Speed = NumberRange.new(speedMin, speedMax)
		pe.SpreadAngle = Vector2.new(40, 40)
		pe.RotSpeed = NumberRange.new(-45, 45)
		pe.Acceleration = accel
		pe.Parent = anchor
	end

	for _, lm in AbyssalFloor46.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
		if not lm.Straddles then
			table.insert(placedSpots, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ), lm.Y or 0 })
		end
	end

	-- =========================================================================
	-- 1. MID-LAYER: CARVED BASALT RIVER BED, BRAIDED UNDERTOW & THE ABYSSAL UPFALL
	-- =========================================================================
	-- Dark carved river floor bed (Y = -8.0) and braided UndertowRibbon meshes running uphill (-Z) to the Upfall.
	ctx.group("DirgeUndertowBed", function()
		boxAt("AbyssRiverBasaltFloor", CFrame.new(V(0, -8.3, -10)), V(620, 0.6, 620), OBSIDIAN_DARK, Mat.Basalt)
		boxAt("UpfallBowlBed", CFrame.new(V(-168, -8.1, -286)), V(110, 0.6, 86), OBSIDIAN_DARK, Mat.Basalt)
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Braided violet Undertow ribbons flowing uphill (-Z) toward the Upfall at (-168, -301).
	-- Placed strictly at Y = -7.2 (>= 7.2 studs below Basin Y = 0 and >= 11 studs below every eyot/bridge!).
	local undertowStreams = {
		-- Main West braid channel -> Upfall bowl
		{ -110, 96, -12 }, { -135, 58, -18 }, { -115, 16, -24 }, { -152, -26, -28 },
		{ -145, -72, -20 }, { -172, -118, -14 }, { -162, -165, -8 }, { -170, -212, 4 }, { -168, -260, 0 },
		-- Center braid weaving around Crossing / EyotC / ShoalC -> swinging west to Upfall
		{ -55, 96, 8 }, { -52, 52, -10 }, { -52, 10, 12 }, { -48, -36, -14 },
		{ -52, -88, 12 }, { -58, -138, -16 }, { -78, -186, -28 }, { -108, -228, -34 }, { -138, -268, -38 },
		-- East-center braid -> curving north-west into the Upfall confluence
		{ 55, 96, -8 }, { 52, 50, 10 }, { 54, 6, -12 }, { 48, -42, 14 },
		{ 52, -92, -10 }, { 62, -144, -22 }, { 92, -192, -32 }, { 82, -236, -42 }, { -45, -286, -68 },
		-- Far East channel feeding Weir of Hooks -> confluence
		{ 122, 94, 14 }, { 128, 48, -12 }, { 155, -2, -18 }, { 155, -54, 14 },
		{ 152, -108, -14 }, { 150, -162, -18 }, { 120, -212, -30 },
	}
	for idx, u in undertowStreams do
		local m = placeProp("DirgeUndertow", "UndertowRibbon", u[1], u[2], u[3], 1.15, UNDERTOW_TINT, -7.2, 10.0, false, nil, "DirgeUndertow")
		makeDecor(m)
		if m and (idx == 4 or idx == 12 or idx == 21 or idx == 30) then
			-- Low-placed invisible anchor light in deep river bed (Y = -5.5, well below every walk surface)
			local anchor = ctx.block("UndertowBedGlow", V(1, 1, 1), V(u[1], -5.5, u[2]), UNDERTOW_VIOLET, Mat.SmoothPlastic, nil, 1)
			anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
			safeTag(anchor, "DirgeUndertow")
			addLight(anchor, UNDERTOW_VIOLET, 1.35, 68)
		end
	end

	-- LANDMARK 1: THE ABYSSAL UPFALL (colossal upward void river column behind Apex, Y = -8, Top = 164 >= 155!)
	do
		local uf = AbyssalFloor46.Landmarks[1]
		local mu = placeProp(uf.Id, "UpfallColumn", uf.X, uf.Z, 18, 1.02, UPFALL_TINT, uf.Y, uf.HalfX, false)
		makeDecor(mu)
		if mu then
			tagHierarchy(mu, "DirgeUndertow")
			-- High-sky violet light & upward void motes (>= 35 studs above Apex Y = 40!)
			local highAnchor = ctx.block("UpfallHighLight", V(1, 1, 1), V(uf.X, 95, uf.Z), UNDERTOW_VIOLET, Mat.SmoothPlastic, nil, 1)
			highAnchor.CanCollide, highAnchor.CanQuery, highAnchor.CanTouch, highAnchor.CastShadow = false, false, false, false
			safeTag(highAnchor, "DirgeUndertow")
			addLight(highAnchor, UNDERTOW_VIOLET, 2.4, 130)
		end
		-- Upward-flowing void motes rising from the Upfall throat
		addEmitter("UpfallVoidMotes", V(uf.X, 32, uf.Z), UNDERTOW_VIOLET, SILVER_LIGHT, 1.8, 0.5, 8, 10, 18, V(0, 14, 0), 0.9)
		addEmitter("UpfallVoidMist", V(uf.X, 8, uf.Z + 12), UNDERTOW_DEEP, UNDERTOW_VIOLET, 6.0, 14.0, 5, 4, 8, V(0, 7, 0), 0.65)
	end

	-- =========================================================================
	-- 2. EYOT BASALT SKIRTS & CHAIN-FORD BRIDGE DRESSING
	-- =========================================================================
	-- Sculpted dark basalt EyotSlab skirts under each terrain/deck eyot so every eyot rises sharply out of the Undertow!
	local eyotSkirts: { { id: string, kit: string, s: number, y: number } } = {
		{ id = "WestGallery", kit = "EyotSlabL", s = 1.38, y = -8.5 },
		{ id = "EastGallery", kit = "EyotSlabL", s = 1.38, y = -10.5 },
		{ id = "Crossing", kit = "EyotSlabL", s = 1.18, y = -5.0 },
		{ id = "EyotW", kit = "EyotSlabM", s = 1.30, y = -3.5 },
		{ id = "EyotC", kit = "EyotSlabM", s = 1.16, y = -4.5 },
		{ id = "EyotE", kit = "EyotSlabM", s = 1.30, y = -1.5 },
		{ id = "ShoalW", kit = "EyotSlabM", s = 1.30, y = -0.5 },
		{ id = "ShoalC", kit = "EyotSlabL", s = 1.06, y = -0.5 },
		{ id = "ShoalE", kit = "EyotSlabM", s = 1.32, y = 2.0 },
		{ id = "HeadC", kit = "EyotSlabM", s = 1.16, y = 4.0 },
		{ id = "HeadE", kit = "EyotSlabL", s = 1.04, y = 4.5 },
	}
	for idx, es in eyotSkirts do
		local plat = P[es.id]
		if plat then
			local m = placeProp("EyotSkirt_" .. es.id, es.kit, plat.X, plat.Z, (idx * 37) % 360, es.s, VAHL_TINT, es.y, 6, false)
			makeDecor(m)
		end
	end

	-- Grounded dark basalt outcrop shelves supporting outer-rim landmarks so nothing ever overhangs void
	local function buildBasaltBay(x: number, y: number, z: number, rad: number)
		ctx.group("EyotOutcropBay", function()
			local h = math.max(12, y + 8)
			ctx.cyl("BasaltBayTop", V(x, y - 0.8, z), rad, 1.6, OBSIDIAN, Mat.Basalt)
			ctx.cyl("BasaltBaySkirt", V(x, y - 1.6 - h * 0.5, z), rad * 0.86, h, OBSIDIAN_DARK, Mat.Basalt)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end
	for _, idx in { 7, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19 } do
		local lm = AbyssalFloor46.Landmarks[idx]
		buildBasaltBay(lm.X, lm.Y :: number, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 4.5)
	end

	-- Dress EVERY link off the lane at both ends with WardlightCages / ChainPostIrons / Chained Banners,
	-- and frame ford links with ChainFordSpan underside aprons & HangingAbyssChains!
	for idx, link in ctx.layout.Links do
		if link.From ~= "Sanctuary" then
			local dx, dz = link.BX - link.AX, link.BZ - link.AZ
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
			local nx, nz = -dz / len, dx / len
			local yaw = math.deg(math.atan2(dx, dz))
			-- Midpoint ChainFordSpan sub-structure tucked cleanly beneath the walk deck (never blocking walk surface!)
			if idx % 2 == 1 then
				local mx, mz = (link.AX + link.BX) * 0.5, (link.AZ + link.BZ) * 0.5
				local my = (link.AY + link.BY) * 0.5 - 2.4
				local pitch = math.atan2(link.BY - link.AY, len)
				local ms = placeProp("ChainFordSub_" .. link.Id, "ChainFordSpan", mx, mz, yaw, 1.05, VAHL_TINT, my, 4, false, CFrame.Angles(-pitch, 0, 0))
				makeDecor(ms)
			end
			-- Dress both ends strictly outside the 28-stud link + 3-stud shoulder (offset = 22.5 studs perpendicular)
			for endIdx, ep in { { link.AX, link.AY, link.AZ, 0 }, { link.BX, link.BY, link.BZ, 180 } } do
				for _, side in { -1, 1 } do
					local px = ep[1] + nx * side * 22.5
					local pz = ep[3] + nz * side * 22.5
					local py = ep[2]
					if isSpotFree(px, pz, 2.2, py, false) then
						local isWard = ((idx + endIdx + (side > 0 and 1 or 0)) % 2 == 0)
						if isWard then
							local mw = placeProp("FordWardlight", "WardlightCage", px, pz, yaw + ep[4] + (side * 35), 0.92, WARDLIGHT_TINT, py, 2.2, true, nil, "DirgeWardlight")
							makeDecor(mw)
							if mw and lightsUsed < 11 and (idx % 3 == 0) and side == 1 and endIdx == 1 then
								addLight(H.glowOf(mw), BONE_LIGHT, 1.25, 44)
							end
						else
							local mc = placeProp("FordChainPost", "ChainPostIron", px, pz, yaw + ep[4], 0.95, VAHL_TINT, py, 2.2, true, nil, "DirgeWardlight")
							makeDecor(mc)
						end
					end
				end
			end
		end
	end

	-- =========================================================================
	-- 3. NEAR LAYER LANDMARKS: SANCTUARY FALLSTAIR, "VHAROS" PAGE, FALLSTRAND & EYOTS
	-- =========================================================================
	-- LANDMARK 3: The half-written "unwritten" Halcyr page pinned to an obsidian spike beside The Fallstair: "Vharos"
	do
		local vp = AbyssalFloor46.Landmarks[3]
		local vy = vp.Y :: number
		ctx.group(vp.Id, function()
			-- Jagged obsidian spike rising out of Sanctuary's western marble stair rim
			boxAt("VharosSpikeBase", CFrame.new(V(vp.X, vy + 1.2, vp.Z)), V(4.4, 2.4, 4.4), OBSIDIAN, Mat.Basalt)
			boxAt("VharosObsidianSpike", CFrame.new(V(vp.X, vy + 5.2, vp.Z)) * CFrame.Angles(math.rad(-8), math.rad(14), math.rad(6)), V(2.4, 8.6, 2.0), OBSIDIAN_DARK, Mat.Basalt)
			-- Pinned vellum page from Sealed Stacks (Floor 44), facing the arrival camera (+Z/+X)
			local pageCF = CFrame.new(V(vp.X + 0.35, vy + 5.6, vp.Z + 1.15)) * CFrame.Angles(math.rad(6), math.rad(18), math.rad(-5))
			local pagePart = boxAt("VharosPinnedPage", pageCF, V(2.6, 3.4, 0.14), VELLUM_PAGE, Mat.Fabric)
			pagePart:SetAttribute("Label", "Vharos")
			-- Crimson ink strokes on the page (matte Fabric, never Neon!)
			boxAt("VharosCrimsonInkA", pageCF * CFrame.new(-0.15, 0.35, 0.10) * CFrame.Angles(0, 0, math.rad(-8)), V(1.65, 0.24, 0.06), WINE_SILK, Mat.Fabric)
			boxAt("VharosCrimsonInkB", pageCF * CFrame.new(0.10, -0.15, 0.10) * CFrame.Angles(0, 0, math.rad(5)), V(1.25, 0.18, 0.06), WINE_SILK, Mat.Fabric)
			-- Iron dagger-pin holding the parchment to the spike
			boxAt("VharosIronPin", pageCF * CFrame.new(0, 1.1, 0.18), V(0.32, 0.32, 0.85), CHAIN_IRON, Mat.Metal)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
		-- Flanking Chained Crown banners & Wardlights on The Fallstair (Sanctuary) outside the 36-stud exit lane
		placeChainedBanner("FallstairBannerW", V(-34, vy, 266), 18, 1.05)
		placeChainedBanner("FallstairBannerE", V(34, vy, 266), -18, 1.05)
		for _, sx in { -28, 28 } do
			local wl = placeProp("SanctuaryWardlight", "WardlightCage", sx, 261, if sx < 0 then 25 else -25, 1.0, WARDLIGHT_TINT, vy, 2.2, true, nil, "DirgeWardlight")
			makeDecor(wl)
			if wl and sx > 0 then
				addLight(H.glowOf(wl), BONE_LIGHT, 1.45, 52)
			end
		end
	end

	-- LANDMARKS 4–6: Fallstrand Archive Debris (FallenStackWreck, tilted Brass Armillary, toppled Index Lamp, Bone Urns)
	do
		local fw = AbyssalFloor46.Landmarks[4]
		local mfw = placeProp(fw.Id, "FallenStackWreck", fw.X, fw.Z, 28, 1.05, ASH_TINT, fw.Y, fw.HalfX, false)
		makeDecor(mfw)

		local fa = AbyssalFloor46.Landmarks[5]
		local mfa = placeProp(fa.Id, "CalamusArmillary", fa.X, fa.Z, -32, 0.82, VAHL_TINT, fa.Y, fa.HalfX, false, CFrame.Angles(math.rad(18), 0, math.rad(-14)))
		makeDecor(mfa)

		local fl = AbyssalFloor46.Landmarks[6]
		local mfl = placeProp(fl.Id, "WardlightCage", fl.X, fl.Z, 64, 0.95, SILVER_WARD_TINT, fl.Y, fl.HalfX, false, CFrame.Angles(math.rad(68), 0, math.rad(18)), "DirgeWardlight")
		makeDecor(mfl)
		-- Additional Archive bookcase & tome spill on Fallstrand far flanks (beyond BASIN_WEST/EAST camps at ±110)
		local fallDebris: { { x: number, z: number, yaw: number, kit: string, s: number, tint: any } } = {
			{ x = -178, z = 188, yaw = 24, kit = "FallenStackWreck", s = 1.0, tint = ASH_TINT },
			{ x = -232, z = 172, yaw = -38, kit = "BookcaseCurved", s = 0.78, tint = VAHL_TINT },
			{ x = 182, z = 192, yaw = -22, kit = "FallenStackWreck", s = 1.0, tint = ASH_TINT },
			{ x = 238, z = 168, yaw = 42, kit = "BookcaseCurved", s = 0.78, tint = VAHL_TINT },
			{ x = -268, z = 184, yaw = 15, kit = "ObsidianGeodeSplit", s = 1.0, tint = GEODE_TINT },
			{ x = 268, z = 184, yaw = -20, kit = "ObsidianGeodeSplit", s = 1.0, tint = GEODE_TINT },
		}
		for _, spec in fallDebris do
			if isSpotFree(spec.x, spec.z, 7.0, 0) then
				local m = placeProp("FallstrandDebris", spec.kit, spec.x, spec.z, spec.yaw, spec.s, spec.tint, 0, 6.5, true)
				makeDecor(m)
			end
		end
	end

	-- LANDMARKS 7–9: Reaving Eyot (WestGallery, Elite sentry post)
	local lmPlacements: { { lm: Landmark, kit: string, yaw: number, tint: any, s: number } } = {
		{ lm = AbyssalFloor46.Landmarks[7], kit = "ReavingRack", yaw = 36, tint = VAHL_TINT, s = 1.0 },
		{ lm = AbyssalFloor46.Landmarks[8], kit = "ExecutionBlock", yaw = 135, tint = VAHL_TINT, s = 1.0 },
		{ lm = AbyssalFloor46.Landmarks[9], kit = "VahlGibbetCage", yaw = 90, tint = VAHL_TINT, s = 1.0 },
		{ lm = AbyssalFloor46.Landmarks[10], kit = "ObsidianGeodeSplit", yaw = -38, tint = GEODE_TINT, s = 1.05 },
		{ lm = AbyssalFloor46.Landmarks[11], kit = "FallenStackWreck", yaw = 125, tint = ASH_TINT, s = 0.92 },
		{ lm = AbyssalFloor46.Landmarks[12], kit = "ObsidianGeodeSplit", yaw = 74, tint = GEODE_TINT, s = 0.95 },
		{ lm = AbyssalFloor46.Landmarks[13], kit = "FallenStackWreck", yaw = -90, tint = ASH_TINT, s = 0.94 },
		{ lm = AbyssalFloor46.Landmarks[14], kit = "VahlGibbetCage", yaw = 0, tint = VAHL_TINT, s = 1.0 },
		{ lm = AbyssalFloor46.Landmarks[15], kit = "FallenStackWreck", yaw = 82, tint = ASH_TINT, s = 1.02 },
		{ lm = AbyssalFloor46.Landmarks[16], kit = "AbyssReliquaryShrine", yaw = 90, tint = VAHL_TINT, s = 0.72 },
		{ lm = AbyssalFloor46.Landmarks[18], kit = "WeirOfHooks", yaw = 0, tint = VAHL_TINT, s = 1.0 },
		{ lm = AbyssalFloor46.Landmarks[19], kit = "ChainedCrownKeystone", yaw = 18, tint = VAHL_TINT, s = 1.0 },
	}
	for _, spec in lmPlacements do
		local lm = spec.lm
		local m = placeProp(lm.Id, spec.kit, lm.X, lm.Z, spec.yaw, spec.s, spec.tint, lm.Y, math.max(lm.HalfX, lm.HalfZ), false)
		makeDecor(m)
		if lm.Id == "TheLipKeystone" and m then
			addLight(m:FindFirstChildWhichIsA("BasePart", true), BONE_LIGHT, 1.35, 52)
		end
	end

	-- Extra upstream-facing gibbets on Gallows Eyot (EyotE)
	for _, gx in { { 126, -86, 20, 0 }, { 98, -86, 20, 12 } } do
		if isSpotFree(gx[1], gx[2], 3.5, gx[3]) then
			local mg = placeProp("GallowsGibbet", "VahlGibbetCage", gx[1], gx[2], gx[4], 0.96, VAHL_TINT, gx[3], 3.5, true)
			makeDecor(mg)
		end
	end

	-- LANDMARK 17: Bonebar fallen Vahl marble statue hand & ossuary rubble (ShoalE)
	do
		local bh = AbyssalFloor46.Landmarks[17]
		local by = bh.Y :: number
		ctx.group(bh.Id, function()
			local cf = CFrame.new(V(bh.X, by, bh.Z)) * CFrame.Angles(0, math.rad(-75), 0)
			boxAt("FallenHandWrist", cf * CFrame.new(0, 1.6, 2.5) * CFrame.Angles(math.rad(-14), 0, 0), V(5.2, 3.0, 5.4), BONE_MARBLE, Mat.Marble)
			boxAt("FallenHandPalm", cf * CFrame.new(0, 2.2, -1.2) * CFrame.Angles(math.rad(12), 0, 0), V(6.4, 2.4, 5.2), BONE_MARBLE, Mat.Marble)
			for i = -2, 2 do
				local ang = i * 0.18
				local fLen = 4.6 - math.abs(i) * 0.55
				boxAt("FallenHandFinger", cf * CFrame.new(i * 1.25, 3.8 - math.abs(i) * 0.3, -4.4) * CFrame.Angles(math.rad(36 + math.abs(i) * 8), ang, 0), V(1.05, 1.15, fLen), BONE_MARBLE, Mat.Marble)
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
		-- Companion ossuary urns & rubble on Bonebar
		local mu = placeProp("BonebarUrn", "StoneUrn", bh.X - 2, bh.Z + 18, 25, 1.0, BONE_TINT, by, 3.0, true)
		makeDecor(mu)
	end

	-- Apex rim framing (strictly OUTSIDE the 120x88 boss arena & clear of portals at (-134,-272) and (-166,-272))
	if P.Apex then
		local ax, ay, az = P.Apex.X, P.Apex.Y, P.Apex.Z
		local apexFrames: { { x: number, z: number, yaw: number, kit: string, s: number, tint: any } } = {
			{ x = ax - 54, z = az - 34, yaw = 42, kit = "ChainTowerRound", s = 0.72, tint = VAHL_TINT },
			{ x = ax + 54, z = az - 34, yaw = -42, kit = "ChainTowerRound", s = 0.72, tint = VAHL_TINT },
			{ x = ax - 56, z = az + 32, yaw = 120, kit = "ChainAnchorBollard", s = 0.65, tint = VAHL_TINT },
			{ x = ax + 56, z = az + 32, yaw = -120, kit = "ChainAnchorBollard", s = 0.65, tint = VAHL_TINT },
			{ x = ax - 54, z = az, yaw = 90, kit = "ObsidianSpire", s = 0.65, tint = FAR_VAULT_TINT },
			{ x = ax + 54, z = az, yaw = -90, kit = "ObsidianSpire", s = 0.65, tint = FAR_VAULT_TINT },
		}
		for _, sp in apexFrames do
			if isSpotFree(sp.x, sp.z, 6.0, ay) then
				local ma = placeProp("ApexRimFrame", sp.kit, sp.x, sp.z, sp.yaw, sp.s, sp.tint, ay, 6.0, true)
				makeDecor(ma)
			end
		end
		-- Pair of flanking Wardlights behind the portal spots on Apex rim
		for _, wx in { ax - 42, ax + 42 } do
			local mw = placeProp("ApexWardlight", "WardlightCage", wx, az - 36, 0, 1.05, WARDLIGHT_TINT, ay, 2.5, true, nil, "DirgeWardlight")
			makeDecor(mw)
			if mw then addLight(H.glowOf(mw), BONE_LIGHT, 1.5, 58) end
		end
	end

	-- =========================================================================
	-- 4. FAR SKYLINE LAYER: BLACK VAULT CLIFFS, COURT SILHOUETTES & PALE RIFT WOUND
	-- =========================================================================
	-- LANDMARK 2: Pale Rift Wound high overhead in the Black Vault (Y = 215), shedding Halcyr pages
	ctx.group("PaleRiftWound", function()
		local riftPts = {
			{ V(-115, 224, -145), V(-35, 218, -75), 18 },
			{ V(-35, 218, -75), V(45, 214, 0), 22 },
			{ V(45, 214, 0), V(120, 222, 85), 14 },
		}
		for _, seg in riftPts do
			local mid = (seg[1] + seg[2]) * 0.5
			local len = (seg[2] - seg[1]).Magnitude
			local cf = CFrame.lookAt(mid, seg[2])
			boxAt("RiftWoundOuter", cf, V(seg[3], 2.2, len + 4), SILVER_LIGHT, Mat.Neon, 0.35)
			boxAt("RiftWoundCore", cf, V(seg[3] * 0.45, 2.6, len + 2), BONE_LIGHT, Mat.Neon, 0.05)
		end
		-- High faint far-vault crimson horizon glow (>= 65 studs above Apex, far north edge!)
		for _, cx in { -220, 40, 220 } do
			boxAt("FarVaultCrimsonHorizon", CFrame.new(V(cx, 118, -315)), V(165, 36, 4), HORIZON_CRIMSON, Mat.SmoothPlastic, 0.72)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)
	-- Fluttering Halcyr pages falling from the Pale Rift wound & over the Ford of Pages
	addEmitter("RiftPageFallMain", V(0, 175, -10), VELLUM_PAGE, SILVER_LIGHT, 1.4, 0.7, 7, 3, 7, V(0, -4.5, -2.5), 0.15)
	addEmitter("FordPageDrift", V(0, 24, 60), VELLUM_PAGE, BONE_LIGHT, 1.0, 0.5, 5, 2, 5, V(-1.2, -1.5, -3.5), 0.1)
	addEmitter("BasinAshDriftW", V(-130, 8, 165), ASH_GREY, SILVER_LIGHT, 1.6, 0.8, 5, 2, 4, V(-1.0, 0.8, -3.0), 0.0)
	addEmitter("BasinAshDriftE", V(130, 8, 165), ASH_GREY, SILVER_LIGHT, 1.6, 0.8, 5, 2, 4, V(-1.0, 0.8, -3.0), 0.0)
	addEmitter("UpfallAshStream", V(-45, 26, -120), ASH_GREY, BONE_LIGHT, 1.4, 0.6, 5, 3, 6, V(-2.2, 2.4, -4.0), 0.0)

	-- Distant Black Vault ledges & court silhouettes (tagged "DirgeSilhouette") around perimeter
	local farVaultLedges: { { x: number, y: number, z: number, s: number, yaw: number, kit: string } } = {
		{ x = -292, y = 42, z = -260, s = 1.15, yaw = 28, kit = "ChainTowerRound" },
		{ x = -296, y = 36, z = -45, s = 1.05, yaw = 85, kit = "ObsidianSpire" },
		{ x = -294, y = 28, z = 110, s = 1.10, yaw = 90, kit = "CurtainWallRuins" },
		{ x = 294, y = 48, z = -265, s = 1.15, yaw = -25, kit = "ChainTowerRound" },
		{ x = 298, y = 40, z = -18, s = 1.10, yaw = -88, kit = "ObsidianSpire" },
		{ x = 294, y = 30, z = 108, s = 1.10, yaw = -90, kit = "CurtainWallRuins" },
		{ x = -72, y = 48, z = -304, s = 1.05, yaw = 10, kit = "GatehouseArch" },
		{ x = 96, y = 46, z = -304, s = 1.10, yaw = -14, kit = "VaultRibArch" },
		{ x = 232, y = 52, z = -302, s = 1.15, yaw = -22, kit = "ObsidianSpire" },
	}
	for _, fl in farVaultLedges do
		local m = placeProp("FarVaultSpire", fl.kit, fl.x, fl.z, fl.yaw, fl.s, FAR_VAULT_TINT, fl.y, 8, false)
		makeDecor(m)
	end
	-- Distant silent court silhouettes standing high on far obsidian ledges (bowing on Dirge toll)
	for idx, sp in {
		{ -288, 72, -165, 78 }, { -290, 68, -95, 85 }, { -286, 76, -225, 62 },
		{ 288, 74, -175, -75 }, { 290, 70, -80, -88 }, { 286, 78, -235, -62 },
		{ 88, 80, -306, 0 }, { -58, 82, -306, 12 },
	} do
		ctx.group("DirgeSilhouette_" .. idx, function()
			local cf = CFrame.new(V(sp[1], sp[2], sp[3])) * CFrame.Angles(0, math.rad(sp[4]), 0)
			boxAt("SilhouetteLedge", cf * CFrame.new(0, -4, 0), V(14, 8, 14), OBSIDIAN_DARK, Mat.Basalt)
			boxAt("SilhouetteCloak", cf * CFrame.new(0, 6.5, 0), V(3.8, 12.5, 2.8), OBSIDIAN, Mat.Slate)
			boxAt("SilhouetteHelm", cf * CFrame.new(0, 14.0, 0), V(2.0, 2.6, 2.0), IRON_DARK, Mat.Metal)
			tagHierarchy(ctx.current(), "DirgeSilhouette")
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- 5. BALANCED RICH DRESSING ACROSS ALL 34 DISTINCT TEMPLATES (CAP <= 28 EACH!)
	-- =========================================================================
	-- Every template is capped well below 11% of the ~475 placed props so zero template is filler.
	type KitSpec = { Kit: string, S: { number }, R: number, Tint: any, Cap: number, OnLand: boolean, Dirge: string? }
	local kitPool: { KitSpec } = {
		{ Kit = "ObsidianGeodeSplit", S = { 0.72, 1.05 }, R = 5.2, Tint = GEODE_TINT, Cap = 22, OnLand = true },
		{ Kit = "FallenStackWreck", S = { 0.72, 1.00 }, R = 6.2, Tint = ASH_TINT, Cap = 20, OnLand = true },
		{ Kit = "WardlightCage", S = { 0.82, 1.05 }, R = 2.4, Tint = WARDLIGHT_TINT, Cap = 22, OnLand = true, Dirge = "DirgeWardlight" },
		{ Kit = "ChainPostIron", S = { 0.85, 1.08 }, R = 2.4, Tint = VAHL_TINT, Cap = 22, OnLand = true, Dirge = "DirgeWardlight" },
		{ Kit = "ReavingRack", S = { 0.78, 1.00 }, R = 5.0, Tint = VAHL_TINT, Cap = 16, OnLand = true },
		{ Kit = "VahlGibbetCage", S = { 0.82, 1.05 }, R = 3.5, Tint = VAHL_TINT, Cap = 16, OnLand = true },
		{ Kit = "ExecutionBlock", S = { 0.78, 1.02 }, R = 4.2, Tint = VAHL_TINT, Cap = 16, OnLand = true },
		{ Kit = "WeirOfHooks", S = { 0.70, 0.95 }, R = 8.5, Tint = VAHL_TINT, Cap = 10, OnLand = false },
		{ Kit = "ChainedCrownKeystone", S = { 0.75, 0.98 }, R = 5.2, Tint = VAHL_TINT, Cap = 12, OnLand = true },
		{ Kit = "ChainFordSpan", S = { 0.70, 0.90 }, R = 8.5, Tint = VAHL_TINT, Cap = 14, OnLand = false },
		{ Kit = "EyotSlabS", S = { 0.70, 0.95 }, R = 10.5, Tint = VAHL_TINT, Cap = 14, OnLand = false },
		{ Kit = "EyotSlabM", S = { 0.65, 0.88 }, R = 14.0, Tint = VAHL_TINT, Cap = 10, OnLand = false },
		{ Kit = "EyotSlabL", S = { 0.60, 0.80 }, R = 18.0, Tint = VAHL_TINT, Cap = 8, OnLand = false },
		{ Kit = "UndertowRibbon", S = { 0.80, 1.05 }, R = 11.0, Tint = UNDERTOW_TINT, Cap = 26, OnLand = false, Dirge = "DirgeUndertow" },
		{ Kit = "ObsidianSpire", S = { 0.42, 0.75 }, R = 6.5, Tint = FAR_VAULT_TINT, Cap = 22, OnLand = false },
		{ Kit = "HangingAbyssChain", S = { 0.65, 0.95 }, R = 6.0, Tint = VAHL_TINT, Cap = 22, OnLand = false, Dirge = "DirgeChain" },
		{ Kit = "AbyssReliquaryShrine", S = { 0.55, 0.78 }, R = 6.2, Tint = VAHL_TINT, Cap = 14, OnLand = true },
		{ Kit = "ChainAnchorBollard", S = { 0.52, 0.75 }, R = 5.8, Tint = VAHL_TINT, Cap = 18, OnLand = true },
		{ Kit = "ChainTowerRound", S = { 0.48, 0.72 }, R = 8.5, Tint = FAR_VAULT_TINT, Cap = 12, OnLand = false },
		{ Kit = "GatehouseArch", S = { 0.45, 0.65 }, R = 12.0, Tint = FAR_VAULT_TINT, Cap = 8, OnLand = false },
		{ Kit = "CurtainWallRuins", S = { 0.55, 0.85 }, R = 8.5, Tint = FAR_VAULT_TINT, Cap = 16, OnLand = false },
		{ Kit = "VaultRibArch", S = { 0.45, 0.68 }, R = 10.0, Tint = FAR_VAULT_TINT, Cap = 12, OnLand = false },
		{ Kit = "GothicPillarColonnade", S = { 0.55, 0.80 }, R = 5.0, Tint = VAHL_TINT, Cap = 18, OnLand = true },
		{ Kit = "HangingLantern", S = { 0.95, 1.35 }, R = 2.0, Tint = WARDLIGHT_TINT, Cap = 22, OnLand = true, Dirge = "DirgeWardlight" },
		{ Kit = "StoneUrn", S = { 0.75, 1.15 }, R = 2.6, Tint = BONE_TINT, Cap = 26, OnLand = true },
		{ Kit = "RuinRubble", S = { 0.75, 1.25 }, R = 4.2, Tint = ASH_TINT, Cap = 26, OnLand = true },
		{ Kit = "BoulderCluster", S = { 0.80, 1.30 }, R = 4.6, Tint = VAHL_TINT, Cap = 26, OnLand = true },
		{ Kit = "BookcaseCurved", S = { 0.60, 0.85 }, R = 5.8, Tint = VAHL_TINT, Cap = 18, OnLand = true },
		{ Kit = "TomeStack", S = { 0.85, 1.35 }, R = 2.6, Tint = SILK_TINT, Cap = 26, OnLand = true },
		{ Kit = "CalamusArmillary", S = { 0.55, 0.80 }, R = 5.5, Tint = VAHL_TINT, Cap = 14, OnLand = true },
		{ Kit = "ArmourRack", S = { 0.80, 1.05 }, R = 3.2, Tint = VAHL_TINT, Cap = 18, OnLand = true },
		{ Kit = "BladeDisplay", S = { 0.80, 1.05 }, R = 3.2, Tint = VAHL_TINT, Cap = 18, OnLand = true },
		{ Kit = "GibbetCage", S = { 0.62, 0.85 }, R = 4.8, Tint = VAHL_TINT, Cap = 14, OnLand = true },
	}

	local function tryPlaceSpec(spec: KitSpec, x: number, z: number, y: number?, yaw: number?): boolean
		if (usedTemplates[spec.Kit] or 0) >= spec.Cap then
			return false
		end
		local s = rng:NextNumber(spec.S[1], spec.S[2])
		local r = spec.R * s
		local py = y
		if py == nil then
			local gy, onDeck = H.surfaceAt(x, z)
			py = gy
			if not onDeck and ctx.field then
				local kind = ctx.field.Kind(x, z)
				if kind == "POOL" and spec.OnLand then
					return false
				end
			end
		end
		if not isSpotFree(x, z, r, py, false) then
			return false
		end
		local m = placeProp(spec.Kit, spec.Kit, x, z, yaw or rng:NextNumber(0, 360), s, spec.Tint, py, r, true, nil, spec.Dirge)
		if m then
			makeDecor(m)
			return true
		end
		return false
	end

	-- Pass A: Guarantee every single template in kitPool is placed at least twice before randomized fill!
	for _, spec in kitPool do
		local attempts = 0
		while (usedTemplates[spec.Kit] or 0) < 2 and attempts < 80 do
			attempts += 1
			if spec.Kit == "UndertowRibbon" then
				local rx = rng:NextNumber(-220, 220)
				local rz = rng:NextNumber(-270, 95)
				tryPlaceSpec(spec, rx, rz, -7.2, rng:NextNumber(-35, 35))
			elseif not spec.OnLand then
				local side = if attempts % 2 == 0 then -1 else 1
				local rx = if attempts % 3 == 0 then rng:NextNumber(-295, 295) else side * rng:NextNumber(240, 298)
				local rz = if attempts % 3 == 0 then rng:NextNumber(-304, -278) else rng:NextNumber(-280, 120)
				tryPlaceSpec(spec, rx, rz, if spec.Kit == "ChainFordSpan" or spec.Kit == "HangingAbyssChain" then rng:NextNumber(14, 34) else -4.0)
			else
				local rx = rng:NextNumber(-285, 285)
				local rz = rng:NextNumber(138, 222)
				tryPlaceSpec(spec, rx, rz, 0)
			end
		end
	end

	-- Pass B: Rich vignette dressing along every terrace edge (off lanes and camps)
	for id, plat in P do
		if id ~= "Sanctuary" and id ~= "Basin" and id ~= "Apex" then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					for _ = 1, 5 do
						local spec = kitPool[rng:NextInteger(1, #kitPool)]
						if spec.OnLand then
							local px = plat.X + sx * (plat.Width * 0.5 - rng:NextNumber(4, 12))
							local pz = plat.Z + sz * (plat.Depth * 0.5 - rng:NextNumber(4, 12))
							tryPlaceSpec(spec, px, pz, plat.Y)
						end
					end
				end
			end
		end
	end

	-- Pass C: Fallstrand (Basin) rich Archive wreckage & Vahl perimeter vignettes
	for _ = 1, 220 do
		if propCount >= 280 then break end
		local spec = kitPool[rng:NextInteger(1, #kitPool)]
		if spec.OnLand then
			local px = rng:NextNumber(-292, 292)
			local pz = rng:NextNumber(136, 224)
			tryPlaceSpec(spec, px, pz, 0)
		end
	end

	-- Pass D: Outer banks, chasm floor outcrops, river boulders & far vault rim until propCount >= 475
	for _ = 1, 3200 do
		if propCount >= 480 then break end
		local spec = kitPool[rng:NextInteger(1, #kitPool)]
		local px = rng:NextNumber(-302, 302)
		local pz = rng:NextNumber(-305, 225)
		local py: number? = nil
		if spec.Kit == "UndertowRibbon" then
			if pz > 105 then continue end
			py = -7.2
		elseif not spec.OnLand then
			if math.abs(px) < 235 and pz > -275 and pz < 120 then
				py = -6.0
			else
				py = rng:NextNumber(-4.0, 18.0)
			end
		else
			if pz > 134 and pz < 226 then
				py = 0
			elseif math.abs(px) > 250 and pz < 110 then
				py = -4.0
			else
				continue
			end
		end
		tryPlaceSpec(spec, px, pz, py)
	end

	-- =========================================================================
	-- 6. GROUND COVER (NON-COLLIDABLE TowerDetail CLUMPS: >= 340 ASH, BONE, PAGES, SHARDS)
	-- =========================================================================
	local coverKinds = { "AshDrift", "HalcyrPages", "BoneSplinters", "ChainShards" }
	for _ = 1, 1800 do
		if coverCount >= 360 then break end
		local x = rng:NextNumber(-302, 302)
		local z = rng:NextNumber(-302, 295)
		local gy, onDeck = H.surfaceAt(x, z)
		-- Place ground cover on Fallstrand, terrace outer edges, or dark banks (never on steep cliffs or bridges)
		if onDeck or (z > 132 and z < 228) or (math.abs(x) > 245 and z < 120) or (z < -280) then
			if isSpotFree(x, z, 1.6, gy, true) then
				local kind = coverKinds[(coverCount % #coverKinds) + 1]
				local yaw = rng:NextNumber(0, 360)
				ctx.group("GroundCover", function()
					local cf = CFrame.new(V(x, gy, z)) * CFrame.Angles(0, math.rad(yaw), 0)
					if kind == "AshDrift" then
						lump("AshClump", (cf * CFrame.new(0, 0.25, 0)).Position, V(rng:NextNumber(2.8, 5.2), 0.7, rng:NextNumber(2.4, 4.4)), ASH_GREY, Mat.Slate)
					elseif kind == "HalcyrPages" then
						for p = 1, 2 do
							boxAt("FallenPage_" .. p, cf * CFrame.new((p - 1.5) * 1.1, 0.08, (p % 2) * 0.6) * CFrame.Angles(0, math.rad(p * 34), 0), V(1.3, 0.08, 0.95), VELLUM_PAGE, Mat.Fabric)
						end
					elseif kind == "BoneSplinters" then
						boxAt("BoneShardA", cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0.3, 0.1), V(2.0, 0.36, 0.55), BONE_MARBLE, Mat.Marble)
						boxAt("BoneShardB", cf * CFrame.new(0.8, 0.16, 0.5) * CFrame.Angles(0, -0.5, 0), V(1.4, 0.30, 0.45), BONE_MARBLE, Mat.Marble)
					else
						boxAt("ChainLinkShard", cf * CFrame.new(0, 0.2, 0), V(1.5, 0.32, 0.9), CHAIN_IRON, Mat.Metal)
					end
					tagDetail(ctx.current())
					pin(ctx.current())
				end)
				coverCount += 1
			end
		end
	end

	-- Extra scattered wine-silk Chained Crown banners on Fallstrand & gallery edges (non-collidable, matte Fabric)
	for _, bp in {
		{ -148, 0, 146, 25 }, { 148, 0, 146, -25 },
		{ -212, 8, 36, 65 }, { 212, 4, 36, -65 },
		{ -28, 24, -135, 35 }, { 28, 24, -185, 145 },
	} do
		if isSpotFree(bp[1], bp[3], 2.2, bp[2], true) then
			placeChainedBanner("VahlBanner", V(bp[1], bp[2], bp[3]), bp[4], 0.95)
		end
	end

	local distinctCount = 0
	for _ in usedTemplates do
		distinctCount += 1
	end

	ctx.setAttribute("PlacedPropCount", propCount)
	ctx.setAttribute("GroundCoverCount", coverCount)
	ctx.setAttribute("DistinctTemplateCount", distinctCount)
	ctx.setAttribute("SetPieceLightCount", lightsUsed)
end

return AbyssalFloor46
