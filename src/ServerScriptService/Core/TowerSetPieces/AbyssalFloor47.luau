--!strict
-- Hand-authored set pieces for Abyssal Throne Floor 47: Crimson Procession (abyssal:2, EXPANDED_ENCOUNTER).
-- Design: docs/prompts/abyssal-throne-floor-layouts-prompt.md (Floor 47) & reference/Abyssal Throne 47.jpg.
--
-- Two processional columns -- the hooded Sworn on the west and the chained Bound on the east --
-- crossing paths at the bone-white inlaid Crossing of Oaths before climbing the matte wine-silk
-- Station Stairs onto the Crimson Bier island ringed by the violet Undertow moat, overseen by the
-- colossal 186-stud Warden-King Effigy carried on stone bearers straddling the Vigil Walk, backed by
-- stacked bone-white Ossuary urn niches under a narrowing pale Rift slit in the black vault.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)
local AbyssalCollision = require(script.Parent.AbyssalCollision)

local AbyssalFloor47 = {}

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

-- Vahl Crimson Vigil palette (§5.4 & §5.7):
-- Walkways & Wardlights glow bone-white / cold silver ONLY (hue ~42°, sat <= 0.12).
-- Crimson on/near walk surfaces is strictly matte Enum.Material.Fabric in deep wine (118, 22, 36).
-- Zero orange anywhere; zero Neon crimson or violet near walk surfaces.
local VAHL_47 = table.freeze({
	STONE = swatch(24, 22, 30, Mat.Basalt),
	ALT = swatch(224, 218, 204, Mat.Limestone),
	METAL = swatch(44, 44, 52, Mat.Metal),
	TRIM = swatch(62, 62, 72, Mat.Metal),
	SILK = swatch(118, 22, 36, Mat.Fabric),
	ACCENT = swatch(166, 138, 74, Mat.Metal),
	GLOW = swatch(244, 238, 222, Mat.Neon),
	CRYSTAL = swatch(96, 18, 32, Mat.SmoothPlastic),
	MOSS = swatch(84, 80, 90, Mat.Slate),
	GOLD = swatch(166, 138, 74, Mat.Metal),
	WOOD = swatch(48, 42, 46, Mat.Slate),
	CANDLE = swatch(244, 238, 222, Mat.Neon),
	CORAL = swatch(118, 22, 36, Mat.Fabric),
	FOLIAGE = swatch(74, 70, 80, Mat.Slate),
	CAP = swatch(34, 30, 40, Mat.Basalt),
	STEM = swatch(212, 206, 192, Mat.Limestone),
	BULB = swatch(244, 238, 222, Mat.Neon),
})

local SWORN_TINT = tinted(VAHL_47, {
	STONE = swatch(32, 30, 38, Mat.Basalt),
	ALT = swatch(226, 220, 206, Mat.Limestone),
})

local BOUND_TINT = tinted(VAHL_47, {
	STONE = swatch(22, 22, 28, Mat.Basalt),
	ALT = swatch(186, 180, 168, Mat.Limestone),
	TRIM = swatch(54, 56, 66, Mat.Metal),
})

local OSSUARY_TINT = tinted(VAHL_47, {
	ALT = swatch(232, 226, 212, Mat.Marble),
	STONE = swatch(28, 26, 34, Mat.Basalt),
})

local FAR_VAULT_TINT = tinted(VAHL_47, {
	STONE = swatch(16, 15, 22, Mat.Basalt),
	ALT = swatch(142, 138, 132, Mat.Slate),
	GLOW = swatch(222, 228, 238, Mat.Neon),
})

local WARDLIGHT_GLOW = rgb(244, 238, 222)
local COLD_SILVER = rgb(222, 228, 238)
local BONE_MARBLE = rgb(224, 218, 204)
local BONE_MUTED = rgb(176, 170, 158)
local OBSIDIAN = rgb(24, 22, 30)
local BASALT_MID = rgb(36, 34, 44)
local BLACK_IRON = rgb(44, 44, 52)
local CHAIN_IRON = rgb(62, 62, 72)
local WINE_SILK = rgb(118, 22, 36)
local OLD_GOLD = rgb(166, 138, 74)
local ASH_GREY = rgb(88, 84, 94)
local UNDERTOW_DEEP = rgb(72, 28, 138)
local UNDERTOW_GLOW = rgb(134, 68, 218)
local UNDERTOW_CORE = rgb(172, 114, 242)

-- Floor 47's 22 landmark footprints (local floor space, Room 700 x 700, Bottom = -4).
-- Verified clear of all 21 links + landings, 2 return links, 6 camps (incl. APEX_SANCTUM), and both portals.
AbyssalFloor47.Landmarks = table.freeze({
	-- 1. Colossal 186-stud Warden-King Effigy on Vaulted Stone Bearers straddling VigilW_VigilE at Z = -235!
	{ Id = "EffigyOnBearers", X = 0, Z = -235, Y = 36, HalfX = 26.6, HalfZ = 20.6, Top = 186.0, Straddles = true },
	-- 2. The Crimson Bier raised black-marble catafalque at Apex's north apse (clear of APEX_SANCTUM & portals)
	{ Id = "CrimsonBierCatafalque", X = 0, Z = -210, Y = 48, HalfX = 7.0, HalfZ = 4.6, Top = 22.4 },
	-- 3. The Oathgate arrival iron gate straddling Sanctuary -> Muster
	{ Id = "OathgateArrivalArch", X = 0, Z = 286, Y = 8, HalfX = 38.5, HalfZ = 7.2, Top = 30.4, Straddles = true },
	-- 4. Ossuary North Columbarium Wall behind The Ossuary
	{ Id = "OssuaryNorthNicheWall", X = 0, Z = -322, Y = 44, HalfX = 12.0, HalfZ = 3.5, Top = 25.4 },
	-- 5–6. Ossuary West & East Flanking Urn Walls (angled along north rim clear of Vigil->Ossuary landings)
	{ Id = "OssuaryWestNicheWall", X = -28, Z = -320, Y = 44, HalfX = 11.5, HalfZ = 4.2, Top = 25.4 },
	{ Id = "OssuaryEastNicheWall", X = 28, Z = -320, Y = 44, HalfX = 11.5, HalfZ = 4.2, Top = 25.4 },
	-- 7. Mourners' Gallery Veiled Balcony cantilevered north of Mourners facing the Bier across the open void (dead end)
	{ Id = "MournersGalleryBalcony", X = 0, Z = -85, Y = 22, HalfX = 15.5, HalfZ = 3.0, Top = 14.0 },
	-- 8. Shrine of Silk Vertical Loom Shrine (ShrineW south bay)
	{ Id = "ShrineOfSilkLoom", X = -200, Z = 151, Y = 4, HalfX = 7.8, HalfZ = 3.8, Top = 22.9 },
	-- 9. Shrine of Iron Cold Oath-Anvil Forge (ShrineE south bay)
	{ Id = "ShrineOfIronForge", X = 200, Z = 151, Y = 6, HalfX = 6.8, HalfZ = 5.0, Top = 16.9 },
	-- 10. Chapel of Ash Reliquary Shrine (ChapelW west bay)
	{ Id = "ChapelOfAshReliquary", X = -304, Z = -85, Y = 20, HalfX = 10.0, HalfZ = 10.0, Top = 29.0 },
	-- 11. Chapel of Chains Votive Gallows Rack (ChapelE east bay)
	{ Id = "ChapelOfChainsVotives", X = 302, Z = -85, Y = 24, HalfX = 3.2, HalfZ = 7.4, Top = 16.5 },
	-- 12–13. Halls of Sworn & Bound Chained Oath-Tablet Alcoves (NW/NE outer flank bays, >= 48 studs from camps)
	{ Id = "SwornHallOathAlcove", X = -146, Z = 52, Y = 8, HalfX = 7.0, HalfZ = 3.5, Top = 14.4 },
	{ Id = "BoundHallOathAlcove", X = 146, Z = 52, Y = 12, HalfX = 7.0, HalfZ = 3.5, Top = 14.4 },
	-- 14–15. Stations of Sworn & Bound Pulpits (NW/NE outer bays clear of StationStairs & Chapel links)
	{ Id = "StationSwornPulpit", X = -158, Z = -92, Y = 28, HalfX = 4.5, HalfZ = 3.5, Top = 19.7 },
	{ Id = "StationBoundPulpit", X = 158, Z = -92, Y = 32, HalfX = 4.5, HalfZ = 3.5, Top = 19.7 },
	-- 16–17. Vigils of Sworn & Bound Keeper Towers (back wall corners)
	{ Id = "VigilSwornKeeperTower", X = -252, Z = -260, Y = 36, HalfX = 15.0, HalfZ = 15.0, Top = 70.7 },
	{ Id = "VigilBoundKeeperTower", X = 252, Z = -260, Y = 40, HalfX = 15.0, HalfZ = 15.0, Top = 70.7 },
	-- 18–19. Muster West & East Fallen Standard Bollards
	{ Id = "MusterWestStandard", X = -266, Z = 236, Y = 0, HalfX = 9.8, HalfZ = 9.8, Top = 26.4 },
	{ Id = "MusterEastStandard", X = 266, Z = 236, Y = 0, HalfX = 9.8, HalfZ = 9.8, Top = 26.4 },
	-- 20–21. Far Vault Corner Spire Buttresses framing the black vault sky
	{ Id = "WestVaultButtressSpire", X = -324, Z = -318, Y = 12, HalfX = 12.0, HalfZ = 12.0, Top = 112.0 },
	{ Id = "EastVaultButtressSpire", X = 324, Z = -318, Y = 12, HalfX = 12.0, HalfZ = 12.0, Top = 112.0 },
	-- 22. Crossing of Oaths South Balcony Censer Stand (facing north into the Crossing)
	{ Id = "CrossingSouthProcession", X = 0, Z = 59, Y = 16, HalfX = 3.0, HalfZ = 3.0, Top = 11.9 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AbyssalFloor47.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = H.P
	local _boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	local lightsUsed = 0
	local emittersUsed = 0
	local placedPropCount = 0
	local groundCoverCount = 0
	local usedTemplates: { [string]: boolean } = {}
	local distinctTemplateCount = 0

	local function recordTemplate(tplName: string)
		placedPropCount += 1
		if not usedTemplates[tplName] then
			usedTemplates[tplName] = true
			distinctTemplateCount += 1
		end
	end

	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 16 then
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

	local function tagAllParts(m: Instance?, tagName: string)
		if not m then return end
		safeTag(m, tagName)
		m:SetAttribute(tagName, true)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				safeTag(d, tagName)
			end
		end
	end

	-- Place a tracked non-ground-cover prop using a named kit template (with native part fallback).
	local function placeProp(kind: string, tplName: string, x: number, y: number, z: number, yawDeg: number, scale: Vector3 | number, override: any?, fallback: ((cf: CFrame) -> ())?, nonColliding: boolean?): Instance?
		recordTemplate(tplName)
		local prop: Instance? = nil
		ctx.group(kind, function()
			prop = ctx.current()
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
			if ctx.has(tplName) then
				ctx.kitAt(tplName, cf, scale, override)
			elseif fallback then
				fallback(cf)
			end
		end)
		pin(prop)
		if nonColliding then
			makeDecor(prop)
		end
		return prop
	end

	-- Place a tracked TowerDetail ground-cover clump (non-colliding, culled at distance).
	local function placeGroundCover(kind: string, x: number, y: number, z: number, yawDeg: number, builder: (cf: CFrame) -> ())
		groundCoverCount += 1
		local prop: Instance? = nil
		ctx.group(kind, function()
			prop = ctx.current()
			builder(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0))
		end)
		pin(prop)
		tagDetail(prop)
	end

	-- Reusable fallback primitives for Vahl props
	local function fbPillar(cf: CFrame, w: number, h: number, d: number, col: Color3, trimCol: Color3?)
		boxAt("VahlPlinth", cf * CFrame.new(0, 0.5, 0), V(w + 0.6, 1.0, d + 0.6), trimCol or BONE_MARBLE, Mat.Limestone)
		boxAt("VahlBody", cf * CFrame.new(0, 1.0 + h * 0.5, 0), V(w, h, d), col, Mat.Basalt)
	end

	local function fbStatue(cf: CFrame, h: number, bodyCol: Color3, accentCol: Color3, hasGlow: boolean?)
		boxAt("StatuePlinth", cf * CFrame.new(0, 0.9, 0), V(3.6, 1.8, 3.6), OBSIDIAN, Mat.Basalt)
		boxAt("StatueRobe", cf * CFrame.new(0, 1.8 + h * 0.35, 0), V(2.4, h * 0.7, 2.4), bodyCol, Mat.Limestone)
		boxAt("StatueShoulders", cf * CFrame.new(0, 1.8 + h * 0.66, 0), V(3.2, 1.4, 2.0), accentCol, Mat.Metal)
		lump("StatueHead", cf:PointToWorldSpace(V(0, 1.8 + h * 0.82, 0)), V(1.8, 2.1, 1.8), bodyCol, Mat.Limestone)
		if hasGlow then
			local g = lump("WardlightCore", cf:PointToWorldSpace(V(0, 1.8 + h * 0.48, 1.5)), V(0.9, 1.2, 0.9), WARDLIGHT_GLOW, Mat.Neon)
			tagAllParts(g, "DirgeWardlight")
		end
	end

	local function fbBanner(cf: CFrame, h: number)
		boxAt("BannerBase", cf * CFrame.new(0, 0.7, 0), V(2.6, 1.4, 2.6), OBSIDIAN, Mat.Basalt)
		ctx.cyl("BannerPole", cf:PointToWorldSpace(V(0, h * 0.5, 0)), 0.28, h, BLACK_IRON, Mat.Metal)
		boxAt("BannerYard", cf * CFrame.new(0, h - 2.6, 0.6), V(3.6, 0.3, 0.3), BLACK_IRON, Mat.Metal)
		boxAt("BannerCloth", cf * CFrame.new(0, h - 8.2, 0.7), V(3.0, 10.6, 0.2), WINE_SILK, Mat.Fabric)
		local g = lump("BannerLamp", cf:PointToWorldSpace(V(0, h - 1.6, 1.1)), V(0.9, 1.2, 0.9), WARDLIGHT_GLOW, Mat.Neon)
		tagAllParts(g, "DirgeWardlight")
	end

	local function fbWardlightLantern(cf: CFrame, scale: number, withLight: boolean?)
		local s = scale
		local cap = boxAt("WardCap", cf * CFrame.new(0, 0.6 * s, 0), V(1.6 * s, 0.4 * s, 1.6 * s), BLACK_IRON, Mat.Metal)
		boxAt("WardFrame", cf * CFrame.new(0, -0.3 * s, 0), V(1.4 * s, 1.6 * s, 1.4 * s), CHAIN_IRON, Mat.Metal, 0.45)
		local bulb = lump("WardGlow", cf:PointToWorldSpace(V(0, -0.3 * s, 0)), V(0.95 * s, 1.25 * s, 0.95 * s), WARDLIGHT_GLOW, Mat.Neon)
		tagAllParts(bulb, "DirgeWardlight")
		if withLight then
			addLight(bulb, WARDLIGHT_GLOW, 1.45, 52)
		end
		return cap
	end

	local function addDirgeAshEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 11 then return end
		emittersUsed += 1
		local anchor = ctx.block("DirgeAshAnchor", V(1, 1, 1), pos, ASH_GREY, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
		anchor:SetAttribute("SolidScenery", false)
		tagAllParts(anchor, "DirgeAshEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "DirgeAshDrift"
		pe.Color = ColorSequence.new(rgb(186, 182, 174), rgb(118, 114, 126))
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.65),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.75, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Lifetime = NumberRange.new(3.8, 6.2)
		pe.Rate = rate
		pe.Speed = NumberRange.new(2.2, 4.8)
		pe.SpreadAngle = Vector2.new(28, 28)
		pe.RotSpeed = NumberRange.new(-60, 60)
		pe.Acceleration = V(0, 0.4, -3.2) -- Drawn gently northward toward the Bier & Throne!
		pe.Parent = anchor
	end

	-- Reserve every landmark footprint so generic scatter never intrudes
	for _, lm in AbyssalFloor47.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =========================================================================
	-- A. UNDERTOW RING MOAT AROUND THE CRIMSON BIER + PERIMETER VOID RIBBONS
	-- Strictly <= -5.6 Y inside the Rifts bed (Bottom - 4 = -8), using smooth
	-- sculpted layers (zero Neon near walkways, zero flat semi-transparent boxes).
	-- =========================================================================
	ctx.group("DirgeUndertowMoat", function()
		local cx, cz = 0, -160
		-- Outer dark obsidian channel bed & scrolling violet Undertow ring around Apex (R = 70..96)
		for seg = 0, 35 do
			local a = (seg + 0.5) * math.pi * 2 / 36
			local rx, rz = 84.0, 68.0
			local px = cx + math.cos(a) * rx
			local pz = cz + math.sin(a) * rz
			local segLen = 16.0
			local cf = CFrame.new(V(px, -6.2, pz)) * CFrame.Angles(0, -a, 0)
			local outer = boxAt("UndertowMoatBed_" .. seg, cf, V(18.0, 0.55, segLen), UNDERTOW_DEEP, Mat.SmoothPlastic, 0.12)
			local core = boxAt("UndertowMoatCore_" .. seg, cf * CFrame.new(0, 0.25, 0), V(9.5, 0.30, segLen * 0.94), UNDERTOW_GLOW, Mat.Glass, 0.22)
			local vein = boxAt("UndertowMoatVein_" .. seg, cf * CFrame.new(0, 0.36, 0), V(3.4, 0.16, segLen * 0.92), UNDERTOW_CORE, Mat.SmoothPlastic, 0.10)
			tagAllParts(outer, "DirgeUndertow")
			tagAllParts(core, "DirgeUndertow")
			tagAllParts(vein, "DirgeUndertow")
		end
		-- Two outer Undertow rivers flowing uphill (-Z, toward the Throne) along east & west chasms
		for _, sx in { -1, 1 } do
			for step = 0, 14 do
				local pz = 150 - step * 32
				local px = sx * (265 + math.sin(step * 0.6) * 14)
				local yaw = math.rad(sx * math.cos(step * 0.6) * 12)
				local cf = CFrame.new(V(px, -6.4, pz)) * CFrame.Angles(0, yaw, 0)
				local rib = boxAt("UndertowStream_" .. step, cf, V(16.0, 0.45, 34.0), UNDERTOW_DEEP, Mat.SmoothPlastic, 0.15)
				local core = boxAt("UndertowStreamCore_" .. step, cf * CFrame.new(0, 0.22, 0), V(6.5, 0.25, 33.0), UNDERTOW_GLOW, Mat.Glass, 0.22)
				tagAllParts(rib, "DirgeUndertow")
				tagAllParts(core, "DirgeUndertow")
			end
		end
		-- Two subtle Undertow point lights tucked deep inside the moat (Y = -5.2)
		local moatLightW = ctx.block("UndertowLightAnchorW", V(1, 1, 1), V(-84, -5.2, -160), UNDERTOW_GLOW, Mat.SmoothPlastic, nil, 1)
		local moatLightE = ctx.block("UndertowLightAnchorE", V(1, 1, 1), V(84, -5.2, -160), UNDERTOW_GLOW, Mat.SmoothPlastic, nil, 1)
		addLight(moatLightW, UNDERTOW_GLOW, 1.8, 76)
		addLight(moatLightE, UNDERTOW_GLOW, 1.8, 76)
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. WALKWAY INLAYS: CROSSING OF OATHS ROSETTE, APEX APSE & BIER BORDER
	-- Flush non-colliding bone-white marble floor inlays inspired by reference art.
	-- =========================================================================
	ctx.group("CrossingOathsInlay", function()
		local cross = P.Crossing
		if cross then
			local cx, cy, cz = cross.X, cross.Y, cross.Z
			-- Concentric bone-white marble rings + 8-fold crossing knot arcs flush on Crossing!
			ctx.ring("CrossingOuterMarbleRing", V(cx, cy + 0.06, cz), 29.0, 1.6, BONE_MARBLE, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
			ctx.ring("CrossingMidMarbleRing", V(cx, cy + 0.06, cz), 21.5, 1.0, BONE_MARBLE, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
			ctx.ring("CrossingInnerMarbleRing", V(cx, cy + 0.06, cz), 11.5, 0.75, BONE_MUTED, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)
			-- Crossing diagonal processional tracks inlaid across the rosette (West->East & East->West)
			for _, ang in { -38, 38, 0, 90 } do
				boxAt("CrossingTrackInlay", CFrame.new(V(cx, cy + 0.05, cz)) * CFrame.Angles(0, math.rad(ang), 0), V(58.0, 0.08, 2.2), BONE_MARBLE, Mat.Marble)
			end
			-- Broken oath-stone slab cracked cleanly flush at the centre (non-colliding!)
			boxAt("BrokenOathStoneLeft", CFrame.new(V(cx - 1.6, cy + 0.14, cz - 0.3)) * CFrame.Angles(0, math.rad(12), 0), V(2.8, 0.24, 4.2), OBSIDIAN, Mat.Basalt)
			boxAt("BrokenOathStoneRight", CFrame.new(V(cx + 1.8, cy + 0.14, cz + 0.5)) * CFrame.Angles(0, math.rad(-9), 0), V(2.6, 0.24, 3.9), BASALT_MID, Mat.Basalt)
		end

		-- Crimson Bier north apse bay supporting CrimsonBierCatafalque at (0, 48, -210) + Bier rim inlay
		local apex = P.Apex
		if apex then
			local ax, ay, az = apex.X, apex.Y, apex.Z
			ctx.ring("BierOuterMarbleBorder", V(ax, ay + 0.06, az), 44.0, 1.3, BONE_MARBLE, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 36)
			ctx.ring("BierInnerMarbleBorder", V(ax, ay + 0.06, az), 29.0, 0.75, BONE_MUTED, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
			-- Solid black-marble & bone-trimmed apse projecting from Apex's north edge under CrimsonBierCatafalque
			boxAt("BierCatafalqueApseTop", CFrame.new(V(0, ay - 0.8, -209.0)), V(22.0, 1.6, 15.0), OBSIDIAN, Mat.Basalt)
			boxAt("BierCatafalqueApseTrim", CFrame.new(V(0, ay - 0.1, -209.0)), V(23.2, 0.45, 16.0), BONE_MARBLE, Mat.Limestone)
			boxAt("BierCatafalqueApsePier", CFrame.new(V(0, (ay - 8) * 0.5, -209.5)), V(18.0, ay + 4, 12.0), BASALT_MID, Mat.Basalt)
		end

		-- Bone-white inlaid processional flag lines along Muster central avenue
		local basin = P.Basin
		if basin then
			for _, sx in { -1, 1 } do
				boxAt("MusterAvenueBorder", CFrame.new(V(sx * 16.0, basin.Y + 0.06, basin.Z)), V(1.6, 0.08, basin.Depth - 6), BONE_MARBLE, Mat.Marble)
			end
			-- Fallen standard socket circle on Muster south of Crossing approach
			ctx.ring("MusterStandardSocket", V(0, basin.Y + 0.07, basin.Z - 24), 7.5, 0.9, BONE_MUTED, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 16)
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- C. ARCHITECTURAL BAYS & SUBSTRUCTURES FOR OUTER LANDMARKS
	-- Every outer landmark stands solidly on a built marble/basalt alcove bay.
	-- =========================================================================
	ctx.group("VahlLandmarkBays", function()
		local baySpecs = {
			{ -146, 8, 52, 22, 18 },   -- SwornHallOathAlcove
			{ 146, 12, 52, 22, 18 },   -- BoundHallOathAlcove
			{ -158, 28, -92, 18, 18 }, -- StationSwornPulpit
			{ 158, 32, -92, 18, 18 },  -- StationBoundPulpit
			{ 0, 16, 59, 18, 18 },     -- CrossingSouthProcession
			{ 0, 22, -85, 38, 14 },    -- MournersGalleryBalcony
			{ -200, 4, 151, 24, 16 },  -- ShrineOfSilkLoom
			{ 200, 6, 151, 24, 16 },   -- ShrineOfIronForge
			{ -304, 20, -85, 28, 26 }, -- ChapelOfAshReliquary
			{ 302, 24, -85, 22, 24 },  -- ChapelOfChainsVotives
			{ -252, 36, -260, 34, 34 },-- VigilSwornKeeperTower
			{ 252, 40, -260, 34, 34 }, -- VigilBoundKeeperTower
			{ 0, 44, -322, 82, 18 },   -- OssuaryNorth/West/EastNicheWall
		}
		for idx, b in baySpecs do
			local bx, by, bz, bw, bd = b[1], b[2], b[3], b[4], b[5]
			boxAt("VahlBayCap_" .. idx, CFrame.new(V(bx, by - 0.8, bz)), V(bw, 1.6, bd), OBSIDIAN, Mat.Basalt)
			boxAt("VahlBayTrim_" .. idx, CFrame.new(V(bx, by - 0.1, bz)), V(bw + 1.0, 0.35, bd + 1.0), BONE_MARBLE, Mat.Limestone)
			boxAt("VahlBayPier_" .. idx, CFrame.new(V(bx, (by - 8) * 0.5, bz)), V(bw - 3, by + 4, bd - 3), BASALT_MID, Mat.Basalt)
		end
		-- Substructure piers under EffigyOnBearers flanks (outside VigilW_VigilE Z = -235 +- 15!)
		for _, sy in { -1, 1 } do
			local pz = -235 + sy * 17.5
			boxAt("EffigyPierWall", CFrame.new(V(0, 16, pz)), V(50.0, 40.0, 5.2), OBSIDIAN, Mat.Basalt)
			boxAt("EffigyPierCap", CFrame.new(V(0, 35.6, pz)), V(51.2, 0.9, 6.0), BONE_MARBLE, Mat.Limestone)
		end
		pin(ctx.current())
	end)

	-- =========================================================================
	-- D. PRIMARY LANDMARKS (22 exported footprints in AbyssalFloor47.Landmarks)
	-- =========================================================================
	-- 1. Colossal EffigyOnBearers straddling VigilW_VigilE (Z = -235)
	do
		local lm = AbyssalFloor47.Landmarks[1]
		local me = placeProp("EffigyOnBearers", "EffigyOnBearers", lm.X, lm.Y :: number, lm.Z, 0, 1.0, VAHL_47, function(cf)
			for _, sy in { -1, 1 } do
				boxAt("EffigyBearerWall", cf * CFrame.new(0, 16, sy * 17.5), V(50, 32, 5), OBSIDIAN, Mat.Basalt)
			end
			boxAt("EffigySlab", cf * CFrame.new(0, 33, 0), V(52, 4, 40), BONE_MARBLE, Mat.Limestone)
			boxAt("EffigyKingBody", cf * CFrame.new(-3, 46, -2) * CFrame.Angles(0, 0, math.rad(-34)), V(18, 12, 11), BLACK_IRON, Mat.Metal)
			boxAt("EffigyCanopy", cf * CFrame.new(0, 110, 12), V(46, 148, 8), OBSIDIAN, Mat.Basalt)
		end, true)
		if me then
			addLight(H.glowOf(me) or me:FindFirstChildWhichIsA("BasePart", true), COLD_SILVER, 2.4, 120)
		end
	end

	-- 2. CrimsonBierCatafalque at Apex's north apse
	do
		local lm = AbyssalFloor47.Landmarks[2]
		local mb = placeProp("CrimsonBierCatafalque", "CrimsonBierCatafalque", lm.X, lm.Y :: number, lm.Z, 0, 1.0, VAHL_47, function(cf)
			boxAt("BierBase", cf * CFrame.new(0, 2.2, 0), V(14, 4.4, 10), OBSIDIAN, Mat.Basalt)
			boxAt("BierSilkPall", cf * CFrame.new(0, 4.8, 0), V(11.5, 1.4, 8.2), WINE_SILK, Mat.Fabric)
			boxAt("BierCanopy", cf * CFrame.new(0, 15.5, 0), V(12.4, 3.2, 8.6), WINE_SILK, Mat.Fabric)
		end)
		if mb then
			addLight(H.glowOf(mb), WARDLIGHT_GLOW, 1.5, 56)
		end
	end

	-- 3. The Oathgate arrival gate straddling Sanctuary -> Muster
	do
		local lm = AbyssalFloor47.Landmarks[3]
		local mg = placeProp("OathgateArch", "GatehouseArch", lm.X, lm.Y :: number, lm.Z, 0, 1.0, VAHL_47, function(cf)
			for _, sx in { -1, 1 } do
				boxAt("OathgatePier", cf * CFrame.new(sx * 24, 15, 0), V(8, 30, 8), OBSIDIAN, Mat.Basalt)
			end
			boxAt("OathgateLintel", cf * CFrame.new(0, 28, 0), V(56, 6, 9), BLACK_IRON, Mat.Metal)
		end, true)
		if mg then
			addLight(H.glowOf(mg) or mg:FindFirstChildWhichIsA("BasePart", true), WARDLIGHT_GLOW, 1.8, 68)
		end
		-- Chained oath-tablets flanking the Oathgate piers
		for _, sx in { -1, 1 } do
			placeProp("OathgateTablet", "OathTabletChained", sx * 34, 8, 288, sx * -20, 0.9, VAHL_47, function(cf)
				fbPillar(cf, 5, 12, 2.5, BONE_MARBLE, OBSIDIAN)
			end)
		end
	end

	-- 4–6. The Ossuary Niche Walls (north, west, east) + Sovereign's Cursed Urns
	for _, spec in {
		{ lm = AbyssalFloor47.Landmarks[4], yaw = 0 },
		{ lm = AbyssalFloor47.Landmarks[5], yaw = 14 },
		{ lm = AbyssalFloor47.Landmarks[6], yaw = -14 },
	} do
		local lm = spec.lm
		local mo = placeProp(lm.Id, "OssuaryNicheWall", lm.X, lm.Y :: number, lm.Z, spec.yaw, 1.0, OSSUARY_TINT, function(cf)
			boxAt("OssuaryWall", cf * CFrame.new(0, 12, 0), V(24, 24, 6), BONE_MARBLE, Mat.Marble)
		end)
		if spec.yaw == 0 and mo then
			addLight(H.glowOf(mo), WARDLIGHT_GLOW, 1.6, 62)
		end
	end

	-- 7. Mourners' Gallery Balcony (row of veiled mourners facing the Bier across the void)
	do
		local lm = AbyssalFloor47.Landmarks[7]
		local ly = lm.Y :: number
		for i, mx in { -13, -7.8, -2.6, 2.6, 7.8, 13 } do
			local mm = placeProp("MournerVeiled", "MournerVeiled", mx, ly, lm.Z, 180, 0.92, VAHL_47, function(cf)
				fbStatue(cf, 12.5, WINE_SILK, BLACK_IRON, i == 3 or i == 4)
			end)
			if i == 3 and mm then
				addLight(H.glowOf(mm), WARDLIGHT_GLOW, 1.35, 48)
			end
		end
	end

	-- 8. Shrine of Silk Loom Shrine (plus silk bolts & censers)
	do
		local lm = AbyssalFloor47.Landmarks[8]
		local ms = placeProp(lm.Id, "SilkLoomShrine", lm.X, lm.Y :: number, lm.Z, 180, 1.0, VAHL_47, function(cf)
			fbPillar(cf, 14, 20, 6, OBSIDIAN, WINE_SILK)
		end)
		if ms then addLight(H.glowOf(ms), WARDLIGHT_GLOW, 1.4, 52) end
		placeProp("SilkLoomSide", "SilkLoomShrine", -222, 4, 124, 90, 0.85, VAHL_47, function(cf)
			fbPillar(cf, 12, 18, 5, OBSIDIAN, WINE_SILK)
		end)
	end

	-- 9. Shrine of Iron Forge Shrine (cold quenched iron -- zero fire!)
	do
		local lm = AbyssalFloor47.Landmarks[9]
		local mf = placeProp(lm.Id, "IronForgeShrine", lm.X, lm.Y :: number, lm.Z, 180, 1.0, VAHL_47, function(cf)
			fbPillar(cf, 12, 15, 8, BLACK_IRON, OBSIDIAN)
		end)
		if mf then addLight(H.glowOf(mf), WARDLIGHT_GLOW, 1.4, 52) end
		placeProp("IronForgeSide", "IronForgeShrine", 222, 6, 124, -90, 0.85, VAHL_47, function(cf)
			fbPillar(cf, 11, 14, 7, BLACK_IRON, OBSIDIAN)
		end)
	end

	-- 10. Chapel of Ash Reliquary Shrine
	do
		local lm = AbyssalFloor47.Landmarks[10]
		placeProp(lm.Id, "AbyssReliquaryShrine", lm.X, lm.Y :: number, lm.Z, 90, 1.0, VAHL_47, function(cf)
			fbPillar(cf, 16, 26, 16, OBSIDIAN, BONE_MARBLE)
		end)
	end

	-- 11. Chapel of Chains Votive Rack
	do
		local lm = AbyssalFloor47.Landmarks[11]
		placeProp(lm.Id, "ChainVotiveRack", lm.X, lm.Y :: number, lm.Z, -90, 1.0, VAHL_47, function(cf)
			fbPillar(cf, 14, 16, 4, BLACK_IRON, CHAIN_IRON)
		end)
		placeProp("ChapelChainRackN", "ChainVotiveRack", 270, 24, -108, 180, 0.92, VAHL_47, function(cf)
			fbPillar(cf, 13, 15, 4, BLACK_IRON, CHAIN_IRON)
		end)
	end

	-- 12–13. Halls of Sworn & Bound Chained Oath-Tablet Alcoves
	for _, spec in {
		{ lm = AbyssalFloor47.Landmarks[12], yaw = 140, tint = SWORN_TINT },
		{ lm = AbyssalFloor47.Landmarks[13], yaw = -140, tint = BOUND_TINT },
	} do
		local lm = spec.lm
		placeProp(lm.Id, "OathTabletChained", lm.X, lm.Y :: number, lm.Z, spec.yaw, 1.0, spec.tint, function(cf)
			fbPillar(cf, 6, 14, 3, BONE_MARBLE, BLACK_IRON)
		end)
		placeProp(lm.Id .. "_Lectern", "OathLectern", lm.X + (if spec.yaw > 0 then 6 else -6), lm.Y :: number, lm.Z + 4, spec.yaw, 1.0, spec.tint, function(cf)
			fbPillar(cf, 3.5, 7, 3.5, BLACK_IRON, BONE_MARBLE)
		end)
	end

	-- 14–15. Stations of Sworn & Bound Pulpits
	for _, spec in {
		{ lm = AbyssalFloor47.Landmarks[14], tpl = "ProcessionerSworn", tint = SWORN_TINT },
		{ lm = AbyssalFloor47.Landmarks[15], tpl = "ProcessionerBound", tint = BOUND_TINT },
	} do
		local lm = spec.lm
		placeProp(lm.Id, spec.tpl, lm.X, lm.Y :: number, lm.Z, 180, 1.0, spec.tint, function(cf)
			fbStatue(cf, 16, BONE_MARBLE, BLACK_IRON, true)
		end)
	end

	-- 16–17. Vigils of Sworn & Bound Keeper Towers
	for _, spec in {
		{ lm = AbyssalFloor47.Landmarks[16], tint = SWORN_TINT },
		{ lm = AbyssalFloor47.Landmarks[17], tint = BOUND_TINT },
	} do
		local lm = spec.lm
		placeProp(lm.Id, "ChainTowerRound", lm.X, lm.Y :: number, lm.Z, 0, 1.0, spec.tint, function(cf)
			fbPillar(cf, 24, 68, 24, OBSIDIAN, BLACK_IRON)
		end)
	end

	-- 18–19. Muster West & East Standard Bollards
	for _, lm in { AbyssalFloor47.Landmarks[18], AbyssalFloor47.Landmarks[19] } do
		placeProp(lm.Id, "ChainAnchorBollard", lm.X, lm.Y :: number, lm.Z, 0, 1.0, VAHL_47, function(cf)
			fbPillar(cf, 14, 24, 14, BLACK_IRON, BONE_MARBLE)
		end)
	end

	-- 20–21. Far Vault Corner Buttress Spires
	for _, lm in { AbyssalFloor47.Landmarks[20], AbyssalFloor47.Landmarks[21] } do
		placeProp(lm.Id, "ObsidianSpire", lm.X, lm.Y :: number, lm.Z, 0, 1.85, FAR_VAULT_TINT, function(cf)
			fbPillar(cf, 18, 110, 18, OBSIDIAN, BLACK_IRON)
		end, true)
	end

	-- 22. Crossing South Approach Censer Pedestal (clear of Crossing camp and links)
	do
		local lm = AbyssalFloor47.Landmarks[22]
		local mc = placeProp(lm.Id, "CenserStand", lm.X, lm.Y :: number, lm.Z, 0, 1.0, VAHL_47, function(cf)
			fbPillar(cf, 3.4, 11, 3.4, BLACK_IRON, WARDLIGHT_GLOW)
		end)
		if mc then addLight(H.glowOf(mc), WARDLIGHT_GLOW, 1.35, 48) end
	end

	-- =========================================================================
	-- E. THE TWO PROCESSIONAL COLUMNS (SWORN WEST, BOUND EAST) & KNEELING STATUES
	-- Lines of stone processioners along outer court edges facing inward/toward the Bier,
	-- plus kneeling vigil statues & wine-silk banner pylons flanking Station Stairs & Ramps.
	-- =========================================================================
	-- Helper to place a prop safely only if clear of camps and walkways
	local function placeClearProp(kind: string, tplName: string, x: number, y: number, z: number, yawDeg: number, scale: number, tint: any, fallback: (cf: CFrame) -> ())
		if not ctx.footprintClear(x, z, 3.5, 3.5) then
			return
		end
		for _, camp in ctx.layout.Camps do
			if math.abs(y - camp.Y) < 18 and (x - camp.X) ^ 2 + (z - camp.Z) ^ 2 < 36 * 36 then
				return
			end
		end
		placeProp(kind, tplName, x, y, z, yawDeg, scale, tint, fallback)
	end

	-- 1) The Muster (Basin Y=0) outer parade edges: Sworn West, Bound East, tablets, rails & banners
	local basin = P.Basin
	if basin then
		for i = 0, 14 do
			local bx = -318 + i * 20
			if math.abs(bx + 110) >= 38 and math.abs(bx) >= 34 then
				if i % 2 == 0 then
					placeClearProp("SwornProcessioner", "ProcessionerSworn", bx, 0, 168, 180, 0.96, SWORN_TINT, function(cf) fbStatue(cf, 16, BONE_MARBLE, BLACK_IRON, true) end)
				else
					placeClearProp("MusterRailW", "ChainGalleryRail", bx, 0, 165, 0, 0.90, SWORN_TINT, function(cf) fbPillar(cf, 16, 4.5, 1.5, BLACK_IRON, CHAIN_IRON) end)
				end
				placeClearProp("MusterTabletW", "OathTabletChained", bx, 0, 252, 0, 0.88, SWORN_TINT, function(cf) fbPillar(cf, 5, 12, 2.5, BONE_MARBLE, BLACK_IRON) end)
			end
			local ex = 318 - i * 20
			if math.abs(ex - 110) >= 38 and math.abs(ex) >= 34 then
				if i % 2 == 0 then
					placeClearProp("BoundProcessioner", "ProcessionerBound", ex, 0, 168, 180, 0.96, BOUND_TINT, function(cf) fbStatue(cf, 16, BASALT_MID, CHAIN_IRON, false) end)
				else
					placeClearProp("MusterRailE", "ChainGalleryRail", ex, 0, 165, 0, 0.90, BOUND_TINT, function(cf) fbPillar(cf, 16, 4.5, 1.5, BLACK_IRON, CHAIN_IRON) end)
				end
				placeClearProp("MusterTabletE", "OathTabletChained", ex, 0, 252, 0, 0.88, BOUND_TINT, function(cf) fbPillar(cf, 5, 12, 2.5, BONE_MARBLE, BLACK_IRON) end)
			end
		end
		-- Muster central avenue banners, kneelers & wardlights flanking the bone-white arrival walk
		for _, sx in { -1, 1 } do
			for idx, bz in { 176, 196, 216, 236, 252 } do
				placeClearProp("MusterAvenueBanner", "BannerPoleWine", sx * 24, 0, bz, sx * -90, 0.95, VAHL_47, function(cf) fbBanner(cf, 20) end)
				placeClearProp("MusterAvenueBrazier", "DaisBrazierPedestal", sx * 32, 0, bz - 5, 0, 0.72, VAHL_47, function(cf) fbPillar(cf, 3.2, 8, 3.2, BLACK_IRON, WARDLIGHT_GLOW) end)
				if idx % 2 == 1 then
					placeClearProp("MusterAvenueKneeler", "KneelingStatue", sx * 28, 0, bz + 5, sx * -90, 0.92, VAHL_47, function(cf) fbStatue(cf, 9, BONE_MARBLE, WINE_SILK, false) end)
				end
			end
		end
		-- Muster outer end-court kneeling vigil rows, censers & armour racks near West/East muster wings
		for _, sx in { -1, 1 } do
			local tpl = if sx < 0 then "ProcessionerSworn" else "ProcessionerBound"
			local tint = if sx < 0 then SWORN_TINT else BOUND_TINT
			for _, dz in { -34, -18, -2, 14, 30 } do
				placeClearProp("MusterFlankStatue", tpl, sx * 324, 0, 210 + dz, sx * -90, 0.95, tint, function(cf) fbStatue(cf, 16, BONE_MARBLE, BLACK_IRON, sx < 0) end)
			end
			for _, ax in { 172, 194, 216, 238 } do
				placeClearProp("MusterArmourRack", "ArmourRack", sx * ax, 0, 246, 0, 1.0, VAHL_47, function(cf) fbPillar(cf, 7, 8, 3, BLACK_IRON, CHAIN_IRON) end)
				placeClearProp("MusterLectern", "OathLectern", sx * ax, 0, 174, 180, 1.0, tint, function(cf) fbPillar(cf, 3.5, 7, 3.5, BLACK_IRON, BONE_MARBLE) end)
			end
		end
	end

	-- 2) Halls of Sworn & Bound (WestGallery Y=8, EastGallery Y=12) vignettes (strictly outside 36-stud camp clearance)
	for _, spec in {
		{ x = -110, y = 8, z = 95, side = -1, tpl = "ProcessionerSworn", tint = SWORN_TINT },
		{ x = 110, y = 12, z = 95, side = 1, tpl = "ProcessionerBound", tint = BOUND_TINT },
	} do
		for _, dz in { -28, -14, 14, 28 } do
			local px = spec.x + spec.side * 38
			local pz = spec.z + dz
			placeClearProp("GalleryProcessioner", spec.tpl, px, spec.y, pz, spec.side * -90, 0.92, spec.tint, function(cf) fbStatue(cf, 15, BONE_MARBLE, BLACK_IRON, spec.side < 0) end)
		end
		-- Lecterns, tablets, censers, and armour/votive racks along outer corners
		placeClearProp("GalleryLecternN", "OathLectern", spec.x + spec.side * 30, spec.y, spec.z - 30, spec.side * -135, 1.0, spec.tint, function(cf) fbPillar(cf, 3.5, 7, 3.5, BLACK_IRON, BONE_MARBLE) end)
		placeClearProp("GalleryLecternS", "OathLectern", spec.x + spec.side * 30, spec.y, spec.z + 30, spec.side * -45, 1.0, spec.tint, function(cf) fbPillar(cf, 3.5, 7, 3.5, BLACK_IRON, BONE_MARBLE) end)
		placeClearProp("GalleryCenser", "CenserStand", spec.x - spec.side * 32, spec.y, spec.z + 26, 0, 0.95, spec.tint, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("GalleryArmour", "ArmourRack", spec.x + spec.side * 34, spec.y, spec.z + 18, spec.side * -90, 1.0, spec.tint, function(cf) fbPillar(cf, 7, 8, 3, BLACK_IRON, CHAIN_IRON) end)
		if spec.side > 0 then
			placeClearProp("BoundGibbet", "GibbetCage", spec.x + 36, spec.y, spec.z - 22, -90, 0.85, BOUND_TINT, function(cf) fbPillar(cf, 6, 18, 6, BLACK_IRON, CHAIN_IRON) end)
			placeClearProp("BoundVotive", "ChainVotiveRack", spec.x + 32, spec.y, spec.z + 24, -135, 0.82, BOUND_TINT, function(cf) fbPillar(cf, 10, 13, 3, BLACK_IRON, CHAIN_IRON) end)
		else
			placeClearProp("SwornStela", "RuneStandingStone", spec.x - 36, spec.y, spec.z - 22, 90, 0.95, SWORN_TINT, function(cf) fbPillar(cf, 5, 12, 3, BONE_MARBLE, OBSIDIAN) end)
		end
	end

	-- 3) Shrines of Silk & Iron (ShrineW Y=4, ShrineE Y=6) vignettes
	for _, spec in {
		{ x = -200, y = 4, z = 122, side = -1, tpl = "ProcessionerSworn", tint = SWORN_TINT },
		{ x = 200, y = 6, z = 122, side = 1, tpl = "ProcessionerBound", tint = BOUND_TINT },
	} do
		placeClearProp("ShrineStat", spec.tpl, spec.x + spec.side * 24, spec.y, spec.z - 16, spec.side * -90, 0.95, spec.tint, function(cf) fbStatue(cf, 15, BONE_MARBLE, BLACK_IRON, true) end)
		placeClearProp("ShrineBanner", "BannerPoleWine", spec.x - spec.side * 24, spec.y, spec.z + 20, 180, 0.92, spec.tint, function(cf) fbBanner(cf, 20) end)
		placeClearProp("ShrineCenser", "CenserStand", spec.x + spec.side * 16, spec.y, spec.z - 22, 0, 0.95, spec.tint, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("ShrineTablet", "OathTabletChained", spec.x + spec.side * 24, spec.y, spec.z + 14, spec.side * -90, 0.9, spec.tint, function(cf) fbPillar(cf, 5, 12, 2.5, BONE_MARBLE, BLACK_IRON) end)
		placeClearProp("ShrineUrns", "StoneUrn", spec.x - spec.side * 22, spec.y, spec.z - 20, 0, 1.1, spec.tint, function(cf) fbPillar(cf, 4, 6, 4, BLACK_IRON, OLD_GOLD) end)
		placeClearProp("ShrineRail", "ChainGalleryRail", spec.x + spec.side * 28, spec.y, spec.z, 90, 0.9, spec.tint, function(cf) fbPillar(cf, 14, 5, 2, BLACK_IRON, CHAIN_IRON) end)
	end

	-- 4) Stations of Sworn & Bound (StationW Y=28, StationE Y=32) + Crossing (Y=16) outer rims
	for _, spec in {
		{ x = -145, y = 28, z = -55, side = -1, tpl = "ProcessionerSworn", tint = SWORN_TINT },
		{ x = 145, y = 32, z = -55, side = 1, tpl = "ProcessionerBound", tint = BOUND_TINT },
	} do
		for _, off in { { -26, -20 }, { -26, 20 }, { 26, -20 }, { 26, 20 } } do
			placeClearProp("StationProcessioner", spec.tpl, spec.x + off[1], spec.y, spec.z + off[2], if spec.side < 0 then 145 else -145, 0.90, spec.tint, function(cf) fbStatue(cf, 15, BONE_MARBLE, BLACK_IRON, spec.side < 0) end)
		end
		placeClearProp("StationLectern", "OathLectern", spec.x + spec.side * 26, spec.y, spec.z, spec.side * -90, 1.0, spec.tint, function(cf) fbPillar(cf, 3.5, 7, 3.5, BLACK_IRON, BONE_MARBLE) end)
		placeClearProp("StationTablet", "OathTabletChained", spec.x, spec.y, spec.z + 24, 180, 0.92, spec.tint, function(cf) fbPillar(cf, 5, 12, 2.5, BONE_MARBLE, BLACK_IRON) end)
		placeClearProp("StationCenser", "CenserStand", spec.x - spec.side * 20, spec.y, spec.z - 22, 0, 0.95, spec.tint, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("StationArmour", "ArmourRack", spec.x + spec.side * 24, spec.y, spec.z + 24, spec.side * -135, 1.0, spec.tint, function(cf) fbPillar(cf, 7, 8, 3, BLACK_IRON, CHAIN_IRON) end)
	end

	-- 5) Chapels of Ash & Chains (ChapelW Y=20, ChapelE Y=24) & Mourners' Gallery (Y=22)
	for _, spec in {
		{ x = -270, y = 20, z = -85, side = -1, tpl = "ProcessionerSworn", tint = SWORN_TINT },
		{ x = 270, y = 24, z = -85, side = 1, tpl = "ProcessionerBound", tint = BOUND_TINT },
	} do
		placeClearProp("ChapelStatueA", spec.tpl, spec.x + spec.side * 24, spec.y, spec.z - 20, spec.side * -90, 0.92, spec.tint, function(cf) fbStatue(cf, 15, BONE_MARBLE, BLACK_IRON, true) end)
		placeClearProp("ChapelStatueB", spec.tpl, spec.x + spec.side * 24, spec.y, spec.z + 20, spec.side * -90, 0.92, spec.tint, function(cf) fbStatue(cf, 15, BONE_MARBLE, BLACK_IRON, true) end)
		placeClearProp("ChapelCenser", "CenserStand", spec.x - spec.side * 22, spec.y, spec.z - 18, 0, 1.0, spec.tint, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("ChapelUrn", "StoneUrn", spec.x - spec.side * 22, spec.y, spec.z + 18, 0, 1.15, spec.tint, function(cf) fbPillar(cf, 4, 6, 4, BLACK_IRON, OLD_GOLD) end)
		placeClearProp("ChapelBones", "OssuaryBones", spec.x - spec.side * 24, spec.y, spec.z, 0, 0.95, spec.tint, function(cf) fbPillar(cf, 8, 5, 8, BONE_MARBLE, ASH_GREY) end)
		placeClearProp("ChapelSkeleton", "WardenSkeleton", spec.x + spec.side * 18, spec.y, spec.z + 20, 25, 0.75, spec.tint, function(cf) fbPillar(cf, 8, 4, 8, BONE_MARBLE, ASH_GREY) end)
		placeClearProp("ChapelGibbet", "GibbetCage", spec.x + spec.side * 24, spec.y, spec.z + 22, spec.side * -90, 0.85, spec.tint, function(cf) fbPillar(cf, 6, 18, 6, BLACK_IRON, CHAIN_IRON) end)
	end
	-- Mourners' Gallery side censers, kneeling vigil statues, & railing flanks (strictly south of Z=-80, NO bridge across void!)
	for _, sx in { -1, 1 } do
		placeClearProp("MournerKneel", "KneelingStatue", sx * 22, 22, -58, 180, 0.95, VAHL_47, function(cf) fbStatue(cf, 9, BONE_MARBLE, WINE_SILK, false) end)
		placeClearProp("MournerCenser", "CenserStand", sx * 22, 22, -72, 0, 0.92, VAHL_47, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("MournerBanner", "BannerPoleWine", sx * 24, 22, -46, 180, 0.88, VAHL_47, function(cf) fbBanner(cf, 18) end)
		placeClearProp("MournerTablet", "OathTabletChained", sx * 24, 22, -65, sx * -90, 0.8, VAHL_47, function(cf) fbPillar(cf, 5, 11, 2.5, BONE_MARBLE, BLACK_IRON) end)
	end

	-- 6) Vigils of Sworn & Bound (VigilW Y=36, VigilE Y=40) & The Ossuary (Y=44)
	for _, spec in {
		{ x = -215, y = 36, z = -235, side = -1, tpl = "ProcessionerSworn", tint = SWORN_TINT },
		{ x = 215, y = 40, z = -235, side = 1, tpl = "ProcessionerBound", tint = BOUND_TINT },
	} do
		for _, dx in { -22, 0, 22 } do
			placeClearProp("VigilKeeper", spec.tpl, spec.x + dx, spec.y, spec.z - 22, 180, 0.96, spec.tint, function(cf) fbStatue(cf, 16, BONE_MARBLE, BLACK_IRON, true) end)
		end
		placeClearProp("VigilMourner", "MournerVeiled", spec.x + spec.side * 24, spec.y, spec.z + 20, 180, 0.94, spec.tint, function(cf) fbStatue(cf, 13, WINE_SILK, BLACK_IRON, true) end)
		placeClearProp("VigilCenser", "CenserStand", spec.x - spec.side * 24, spec.y, spec.z + 20, 0, 0.95, spec.tint, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("VigilCage", "PermafrostCage", spec.x + spec.side * 26, spec.y, spec.z - 12, 0, 0.85, spec.tint, function(cf) fbPillar(cf, 6, 16, 6, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("VigilColonnade", "GothicPillarColonnade", spec.x + spec.side * 28, spec.y, spec.z - 22, 0, 0.85, spec.tint, function(cf) fbPillar(cf, 8, 36, 8, OBSIDIAN, BLACK_IRON) end)
	end
	for _, ox in { -24, 24 } do
		placeClearProp("OssuaryMourner", "MournerVeiled", ox, 44, -274, 180, 0.95, OSSUARY_TINT, function(cf) fbStatue(cf, 13, WINE_SILK, BLACK_IRON, true) end)
		placeClearProp("OssuaryCenser", "CenserStand", ox * 1.15, 44, -296, 0, 1.0, OSSUARY_TINT, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
		placeClearProp("OssuaryUrnPile", "OssuaryBones", ox * 0.65, 44, -310, 0, 1.0, OSSUARY_TINT, function(cf) fbPillar(cf, 8, 5, 8, BONE_MARBLE, ASH_GREY) end)
	end

	-- 7) Crimson Bier (Apex Y=48) outer rim pedestals, kneeling guards & bone-white Wardlights (arena center 100% clean!)
	for k = 0, 11 do
		local a = k * math.pi * 2 / 12
		local rx = math.cos(a) * 53.0
		local rz = -160 + math.sin(a) * 40.0
		-- Keep clear of Station Stairs landings (SW/SE around a = 2.0..2.7 & 0.4..1.1) and portal lanes (Z < -185)
		if rz > -186 and math.abs(rx) > 34 then
			local yaw = math.deg(math.atan2(-rx, -160 - rz))
			if k % 2 == 0 then
				placeClearProp("BierRimBrazier", "DaisBrazierPedestal", rx, 48, rz, yaw, 0.72, VAHL_47, function(cf) fbPillar(cf, 3.2, 8, 3.2, BLACK_IRON, WARDLIGHT_GLOW) end)
			else
				placeClearProp("BierRimKneeler", "KneelingStatue", rx, 48, rz, yaw, 0.90, VAHL_47, function(cf) fbStatue(cf, 9, BONE_MARBLE, WINE_SILK, false) end)
			end
		end
	end
	for _, sx in { -1, 1 } do
		placeClearProp("BierFlankBanner", "BannerPoleWine", sx * 42, 48, -196, sx * -135, 0.96, VAHL_47, function(cf) fbBanner(cf, 20) end)
		placeClearProp("BierFlankCenser", "CenserStand", sx * 36, 48, -200, 0, 0.95, VAHL_47, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
	end

	-- =========================================================================
	-- F. DRESSING EVERY LINK (21 links) WITH KNEELING STATUES, PROCESSIONAL RUNNERS,
	--    BANNER POLES, BOLLARDS & HANGING WARDLIGHT LANTERNS (OUTSIDE WALK LANES!)
	-- =========================================================================
	local lightLinkCount = 0
	for linkIdx, link in ctx.layout.Links do
		local ax, ay, az = link.AX, link.AY, link.AZ
		local bx, by, bz = link.BX, link.BY, link.BZ
		local dx, dz = bx - ax, bz - az
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 4 then continue end
		local ux, uz = dx / len, dz / len
		local rx, rz = -uz, ux
		local linkYaw = math.deg(math.atan2(ux, uz))
		local off = link.Width * 0.5 + 3.8
		local isProcessional = link.Kind == "STAIRS" or link.From == "Crossing" or link.To == "Crossing"

		-- Dress both ends off-lane with ChainAnchorBollards or ProcessionalStairRunners / Banners
		for endIdx, pt in { { ax, ay, az }, { bx, by, bz } } do
			for _, side in { -1, 1 } do
				local px = pt[1] + rx * side * off
				local py = pt[2]
				local pz = pt[3] + rz * side * off
				local faceYaw = linkYaw + (if side < 0 then 90 else -90)
				if isProcessional then
					local runner = placeClearProp("LinkProcessionalRunner", "ProcessionalStairRunner", px, py, pz, faceYaw, 0.88, VAHL_47, function(cf) fbBanner(cf, 17) end)
					if runner and endIdx == 1 and side == -1 and lightLinkCount < 5 and (linkIdx % 4 == 1) then
						lightLinkCount += 1
						addLight(H.glowOf(runner), WARDLIGHT_GLOW, 1.35, 48)
					end
				elseif (linkIdx + endIdx) % 2 == 0 then
					placeClearProp("LinkBollard", "ChainAnchorBollard", px, py, pz, faceYaw, 0.42, VAHL_47, function(cf) fbPillar(cf, 4, 8, 4, BLACK_IRON, CHAIN_IRON) end)
				else
					placeClearProp("LinkBanner", "BannerPoleWine", px, py, pz, faceYaw, 0.85, VAHL_47, function(cf) fbBanner(cf, 18) end)
				end
			end
		end

		-- Dress mid-span flanks of long processional stairs & Vigil Walk with kneeling statues & hanging Wardlights
		local steps = math.clamp(math.floor(len / 28), 1, 5)
		for k = 1, steps do
			local f = k / (steps + 1)
			local mx = ax + dx * f
			local my = ay + (by - ay) * f
			local mz = az + dz * f
			for _, side in { -1, 1 } do
				local px = mx + rx * side * (off + 0.8)
				local pz = mz + rz * side * (off + 0.8)
				local faceYaw = linkYaw + (if side < 0 then 90 else -90)
				if link.Kind == "STAIRS" or link.From == "Crossing" then
					placeClearProp("StairKneeler", "KneelingStatue", px, my, pz, faceYaw, 0.88, VAHL_47, function(cf) fbStatue(cf, 9, BONE_MARBLE, WINE_SILK, false) end)
				elseif k % 2 == 1 then
					placeClearProp("LinkLanternPost", "HangingLantern", px, my + 8.5, pz, faceYaw, 1.25, VAHL_47, function(cf)
						fbWardlightLantern(cf, 1.0, false)
					end)
				end
			end
		end
	end

	-- =========================================================================
	-- G. HANGING CAGED WARDLIGHTS, IRON CHAINS, CHASM ROCKS & PERIMETER VAULT RIBS
	-- Overhead Wardlights (>= 22 studs above walk surfaces) + perimeter gothic ribs
	-- framing the open black vault sky, plus distant silent court silhouettes.
	-- =========================================================================
	-- Hanging Wardlights along the two processional columns (pinned OnTerrain/non-colliding, high overhead!)
	for _, wl in {
		{ -165, 34, 155, true }, { -128, 36, 128, false }, { -95, 38, 60, false },
		{ -65, 42, 22, true },  { -112, 52, -30, false }, { -168, 56, -72, true },
		{ 165, 34, 155, true },  { 128, 36, 128, false },  { 95, 38, 60, false },
		{ 65, 42, 22, true },   { 112, 52, -30, false },  { 168, 56, -72, true },
		{ -235, 58, -155, false }, { 235, 58, -155, false },
		{ -125, 68, -235, true },  { 125, 68, -235, true },
		{ -42, 74, -275, false },  { 42, 74, -275, false },
		{ -215, 32, 85, false },   { 215, 32, 85, false },
		{ -270, 48, -15, false },  { 270, 48, -15, false },
		{ -75, 54, -108, false },  { 75, 54, -108, false },
	} do
		local wx, wy, wz, wantLight = wl[1], wl[2], wl[3], wl[4]
		local ml = placeProp("HangingWardlight", "HangingLantern", wx, wy, wz, 0, 1.55, VAHL_47, function(cf)
			fbWardlightLantern(cf, 1.4, false)
		end, true)
		tagAllParts(ml, "DirgeWardlight")
		if ml and wantLight then
			addLight(H.glowOf(ml) or ml:FindFirstChildWhichIsA("BasePart", true), WARDLIGHT_GLOW, 1.5, 64)
		end
		-- Iron chain rising from each hanging Wardlight into the black vault
		local mc = placeProp("WardlightChain", "HangingChainRun", wx, wy + 4, wz, 0, 1.4, VAHL_47, function(cf)
			ctx.cyl("ChainRod", cf.Position + V(0, 24, 0), 0.35, 48, CHAIN_IRON, Mat.Metal)
		end, true)
		tagAllParts(mc, "DirgeChain")
	end

	-- Perimeter Gothic Vault Ribs, Shattered Rose Windows, Curtain Walls & Chasm Spires (framing open black vault sky!)
	for side_i, sx in { -1, 1 } do
		for k = 0, 6 do
			local rz = 260 - k * 92
			local rx = sx * 336
			local yaw = sx * -90
			placeProp("VaultRibButtress", "VaultRibArch", rx, -4, rz, yaw, 1.15, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 14, 130, 14, OBSIDIAN, BLACK_IRON)
			end, true)
			local ch = placeProp("VaultRibChain", "HangingAbyssChain", rx - sx * 18, 84, rz, yaw, 1.1, FAR_VAULT_TINT, function(cf)
				ctx.cyl("RibChain", cf.Position + V(0, 14, 0), 0.55, 28, CHAIN_IRON, Mat.Metal)
			end, true)
			tagAllParts(ch, "DirgeChain")
			placeProp("VaultColonnade", "GothicPillarColonnade", rx - sx * 12, -4, rz + 32, yaw, 1.2, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 10, 48, 10, OBSIDIAN, BLACK_IRON)
			end, true)
		end
		for k = 0, 11 do
			local cz = 275 - k * 52
			placeProp("PerimeterCurtainWall", "CurtainWallSegment", sx * 334, -4, cz, sx * -90, 1.6, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 18, 22, 6, OBSIDIAN, BLACK_IRON)
			end, true)
			placeProp("PerimeterWallRuins", "CurtainWallRuins", sx * 324, 16, cz + 20, sx * -90, 1.25, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 28, 20, 8, OBSIDIAN, BASALT_MID)
			end, true)
		end
		for k = 0, 10 do
			local sz = 250 - k * 56
			placeProp("ChasmObsidianSpire", "ObsidianSpire", sx * 314, -4, sz, k * 42, 1.2 + (k % 3) * 0.25, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 14, 65, 14, OBSIDIAN, BLACK_IRON)
			end, true)
			placeProp("ChasmVoidShards", "VoidShards", sx * (276 + (k % 2) * 18), -6, sz - 20, k * 60, 1.5, VAHL_47, function(cf)
				fbPillar(cf, 6, 10, 6, rgb(76, 22, 48), OBSIDIAN)
			end, true)
			placeProp("ChasmBoulder", "BoulderCluster", sx * (252 + (k % 3) * 14), -4, sz + 12, k * 37, 1.8, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 12, 6, 10, OBSIDIAN, BASALT_MID)
			end, true)
		end
		-- Sanctuary (The Oathgate Y=8) arrival flanks: kneeling sentries, censers, oath tablets, rails & banners
		for _, sx in { -1, 1 } do
			for _, sz in { 296, 314, 332 } do
				placeClearProp("SanctuaryKneeler", "KneelingStatue", sx * 44, 8, sz, sx * -90, 0.92, VAHL_47, function(cf) fbStatue(cf, 9, BONE_MARBLE, WINE_SILK, false) end)
				placeClearProp("SanctuaryBanner", "BannerPoleWine", sx * 56, 8, sz, sx * -90, 0.90, VAHL_47, function(cf) fbBanner(cf, 19) end)
			end
			placeClearProp("SanctuaryCenser", "CenserStand", sx * 36, 8, 294, 0, 0.95, VAHL_47, function(cf) fbPillar(cf, 3, 10, 3, BLACK_IRON, WARDLIGHT_GLOW) end)
			placeClearProp("SanctuaryLectern", "OathLectern", sx * 50, 8, 304, sx * -120, 1.0, VAHL_47, function(cf) fbPillar(cf, 3.5, 7, 3.5, BLACK_IRON, BONE_MARBLE) end)
			placeClearProp("SanctuaryRail", "ChainGalleryRail", sx * 61, 8, 316, 90, 0.95, VAHL_47, function(cf) fbPillar(cf, 16, 4.5, 1.5, BLACK_IRON, CHAIN_IRON) end)
			placeClearProp("SanctuaryBackRail", "ChainGalleryRail", sx * 42, 8, 341, 0, 0.95, VAHL_47, function(cf) fbPillar(cf, 16, 4.5, 1.5, BLACK_IRON, CHAIN_IRON) end)
		end

		-- North & South perimeter court walls, stelae, spires, vault ribs and reliquary cages
		for k = 1, 6 do
			local nx = sx * (54 + k * 44)
			placeProp("NorthVaultWall", "CurtainWallSegment", nx, 4, -334, 0, 1.5, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 22, 24, 6, OBSIDIAN, BLACK_IRON)
			end, true)
			placeProp("NorthVaultColonnade", "GothicPillarColonnade", nx, 4, -322, 0, 1.15, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 10, 46, 10, OBSIDIAN, BLACK_IRON)
			end, true)
			placeProp("NorthVaultCage", "PermafrostCage", nx, 12, -310, 0, 0.9, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 6, 18, 6, BLACK_IRON, WARDLIGHT_GLOW)
			end, true)
			placeProp("NorthVaultStela", "RuneStandingStone", nx - sx * 16, 0, -295, 0, 1.2, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 6, 14, 4, BONE_MUTED, OBSIDIAN)
			end, true)
			placeProp("NorthVaultSpire", "ObsidianSpire", nx, -4, -304, k * 35, 1.1, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 12, 55, 12, OBSIDIAN, BLACK_IRON)
			end, true)
			-- South arrival perimeter walls, vault ribs & boulders behind The Muster
			local sz = 334
			local sxp = sx * (78 + k * 40)
			placeProp("SouthVaultWall", "CurtainWallSegment", sxp, -4, sz, 180, 1.5, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 22, 22, 6, OBSIDIAN, BLACK_IRON)
			end, true)
			placeProp("SouthVaultRuins", "CurtainWallRuins", sxp, 14, sz - 10, 180, 1.2, FAR_VAULT_TINT, function(cf)
				fbPillar(cf, 24, 18, 6, OBSIDIAN, BASALT_MID)
			end, true)
			if k % 2 == 1 then
				placeProp("SouthVaultRib", "VaultRibArch", sxp, -4, sz - 4, 180, 1.1, FAR_VAULT_TINT, function(cf)
					fbPillar(cf, 14, 120, 14, OBSIDIAN, BLACK_IRON)
				end, true)
				placeProp("SouthVaultSpire", "ObsidianSpire", sxp - sx * 12, -4, sz - 24, k * 50, 1.15, FAR_VAULT_TINT, function(cf)
					fbPillar(cf, 12, 58, 12, OBSIDIAN, BLACK_IRON)
				end, true)
			else
				placeProp("SouthVaultBoulder", "BoulderCluster", sxp, -4, sz - 28, k * 29, 1.7, FAR_VAULT_TINT, function(cf)
					fbPillar(cf, 12, 6, 10, OBSIDIAN, BASALT_MID)
				end, true)
			end
		end
		-- Overhead Vigil Walk & gallery chains + Wardlights (high overhead >= 26 studs above walk!)
		for k = 1, 5 do
			local vx = sx * (48 + k * 32)
			local ml = placeProp("VigilOverheadLantern", "HangingLantern", vx, 68, -235, 0, 1.5, VAHL_47, function(cf)
				fbWardlightLantern(cf, 1.4, false)
			end, true)
			tagAllParts(ml, "DirgeWardlight")
			local mc = placeProp("VigilOverheadChain", "HangingAbyssChain", vx, 74, -235, 0, 1.0, VAHL_47, function(cf)
				ctx.cyl("ChainRod", cf.Position + V(0, 14, 0), 0.4, 28, CHAIN_IRON, Mat.Metal)
			end, true)
			tagAllParts(mc, "DirgeChain")
			placeProp("MusterChasmChain", "HangingChainRun", sx * (135 + k * 34), 34, 138, 0, 1.25, FAR_VAULT_TINT, function(cf)
				ctx.cyl("ChainRod", cf.Position + V(0, 18, 0), 0.35, 36, CHAIN_IRON, Mat.Metal)
			end, true)
		end
		-- Far Shattered Rose Windows & Stormkeep Towers framing the Ossuary skyline
		placeProp("BackRoseWindow", "ShatteredRoseWindow", sx * 140, 20, -332, 0, 1.85, FAR_VAULT_TINT, function(cf)
			fbPillar(cf, 42, 72, 10, OBSIDIAN, BONE_MUTED)
		end, true)
		placeProp("MidRoseWindow", "ShatteredRoseWindow", sx * 330, 36, -155, sx * -90, 1.55, FAR_VAULT_TINT, function(cf)
			fbPillar(cf, 36, 62, 8, OBSIDIAN, BONE_MUTED)
		end, true)
		placeProp("BackCornerTower", "StormkeepRoundTower", sx * 316, 4, -220, 0, 1.45, FAR_VAULT_TINT, function(cf)
			fbPillar(cf, 28, 68, 28, OBSIDIAN, BLACK_IRON)
		end, true)
		placeProp("FrontCornerTower", "StormkeepRoundTower", sx * 322, 0, 285, 0, 1.25, FAR_VAULT_TINT, function(cf)
			fbPillar(cf, 24, 58, 24, OBSIDIAN, BLACK_IRON)
		end, true)
		-- Far broken ancestor statues & gibbets on high perimeter ledges
		for idx, dz in { -280, -200, -120, -40, 40, 120, 200 } do
			placeProp("FarLedgeStatue", "BrokenTideStatue", sx * 318, 24, dz, sx * -90, 0.85, FAR_VAULT_TINT, function(cf)
				fbStatue(cf, 38, BONE_MUTED, BLACK_IRON, false)
			end, true)
			if idx % 2 == 0 then
				placeProp("FarLedgeGibbet", "GibbetCage", sx * 308, 34, dz + 28, sx * -90, 0.9, FAR_VAULT_TINT, function(cf)
					fbPillar(cf, 6, 18, 6, BLACK_IRON, CHAIN_IRON)
				end, true)
			end
		end
	end

	-- Chasm floor rubble & ossuary debris clusters at the feet of terraces (non-colliding!)
	for k = 0, 24 do
		local a = k * 2.39996
		local r = 115 + (k % 6) * 34
		local rx = math.cos(a) * r
		local rz = -40 + math.sin(a) * r
		if math.abs(rx) < 310 and rz > -310 and rz < 260 then
			if k % 3 == 0 then
				placeClearProp("ChasmRubble", "RuinRubble", rx, -4, rz, k * 45, 1.35, FAR_VAULT_TINT, function(cf)
					fbPillar(cf, 8, 4, 8, BONE_MUTED, OBSIDIAN)
				end)
			elseif k % 3 == 1 then
				placeClearProp("ChasmUrns", "StoneUrn", rx, -4, rz, k * 45, 1.25, FAR_VAULT_TINT, function(cf)
					fbPillar(cf, 4, 6, 4, BLACK_IRON, OLD_GOLD)
				end)
			else
				placeClearProp("ChasmSkeleton", "WardenSkeleton", rx, -4, rz, k * 45, 0.85, FAR_VAULT_TINT, function(cf)
					fbPillar(cf, 8, 4, 8, BONE_MUTED, ASH_GREY)
				end)
			end
		end
	end

	-- Distant silent court silhouettes standing on far outer ledges (client Dirge makes them bow on toll!)
	ctx.group("DirgeFarSilhouettes", function()
		for _, sx in { -1, 1 } do
			for k = 0, 6 do
				local sz = 180 - k * 75
				local px = sx * 324
				local py = 28 + (k % 3) * 8
				local cf = CFrame.new(V(px, py, sz)) * CFrame.Angles(0, math.rad(sx * -90), 0)
				local sil = boxAt("CourtSilhouette_" .. sx .. "_" .. k, cf * CFrame.new(0, 7.5, 0), V(3.2, 15.0, 2.4), rgb(14, 12, 18), Mat.Basalt)
				tagAllParts(sil, "DirgeSilhouette")
			end
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- H. NARROWING PALE RIFT SLIT IN THE BLACK VAULT SKY & HIGH-ALTITUDE VIGIL GLOW
	-- Strictly >= 30 studs above every walk surface (Y = 120..255).
	-- =========================================================================
	ctx.group("BlackVaultRiftSlit", function()
		local pts = {
			V(-10, 158, -262), V(4, 186, -270), V(-6, 218, -278), V(2, 250, -286),
		}
		for i = 1, #pts - 1 do
			local core = ctx.beam("PaleRiftWoundCore", pts[i], pts[i + 1], 4.8 - i * 0.9, COLD_SILVER, Mat.SmoothPlastic, 0.08)
			local halo = ctx.beam("PaleRiftWoundHalo", pts[i], pts[i + 1], 16.0 - i * 2.5, rgb(210, 186, 198), Mat.SmoothPlastic, 0.55)
			core:SetAttribute("SolidScenery", false)
			halo:SetAttribute("SolidScenery", false)
		end
		-- Faint rose-crimson high-altitude glow strictly behind the Effigy & Ossuary (>= 70 studs above Apex!)
		local highGlow = ctx.beam("HighEffigyVigilAura", V(0, 126, -268), V(0, 210, -284), 46, rgb(148, 38, 62), Mat.SmoothPlastic, 0.78)
		highGlow:SetAttribute("SolidScenery", false)
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- I. GROUND COVER & SMALL CLUTTER (>= 420 TowerDetail clumps, non-colliding)
	-- Bone-white marble rubble, shattered oath-blades, torn wine pennants, ash drifts,
	-- and fallen Archive pages (46-47 only) across courts, chasm slopes & terrace feet.
	-- =========================================================================
	local rng = Random.new(47047)
	local function coverClear(x: number, z: number): boolean
		if not ctx.footprintClear(x, z, 2.2, 2.2) then
			return false
		end
		for _, camp in ctx.layout.Camps do
			if (x - camp.X) ^ 2 + (z - camp.Z) ^ 2 < 24 * 24 then
				return false
			end
		end
		return true
	end

	-- 1) Foreground & terrace-edge bone-white rubble, shattered blades, and ash drifts (matching reference image!)
	for i = 1, 240 do
		local rx = rng:NextNumber(-325, 325)
		local rz = rng:NextNumber(-315, 295)
		if math.abs(rx) < 62 and rz < -105 and rz > -210 then continue end -- Keep Bier arena & void moat clean
		if not coverClear(rx, rz) then continue end
		local gy, onDeck = H.surfaceAt(rx, rz)
		if gy < -3.5 then continue end
		local kindIdx = i % 5
		if kindIdx == 0 then
			-- Bone-white marble rubble cluster
			placeGroundCover("BoneRubbleClump", rx, gy, rz, rng:NextNumber(0, 360), function(cf)
				boxAt("RubbleA", cf * CFrame.new(0, 0.35, 0) * CFrame.Angles(0.2, 0.4, 0.1), V(2.2, 0.7, 1.8), BONE_MARBLE, Mat.Limestone)
				boxAt("RubbleB", cf * CFrame.new(1.1, 0.25, -0.7) * CFrame.Angles(-0.3, 1.0, 0.2), V(1.4, 0.5, 1.2), BONE_MUTED, Mat.Limestone)
				boxAt("RubbleC", cf * CFrame.new(-0.9, 0.22, 0.8) * CFrame.Angles(0.1, -0.6, -0.25), V(1.2, 0.45, 1.0), OBSIDIAN, Mat.Basalt)
			end)
		elseif kindIdx == 1 then
			-- Shattered iron oath-blade & torn wine pennant (non-collidable!)
			placeGroundCover("ShatteredBladeClump", rx, gy, rz, rng:NextNumber(0, 360), function(cf)
				boxAt("BrokenBlade", cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(68), 0.4, 0.2), V(0.35, 3.6, 0.14), BLACK_IRON, Mat.Metal)
				boxAt("BrokenGuard", cf * CFrame.new(0, 2.2, 0.4) * CFrame.Angles(math.rad(68), 0.4, 0.2), V(1.2, 0.22, 0.22), CHAIN_IRON, Mat.Metal)
				boxAt("TornPennant", cf * CFrame.new(0.6, 0.08, 0.4) * CFrame.Angles(0, 0.5, 0), V(1.6, 0.08, 2.4), WINE_SILK, Mat.Fabric)
			end)
		elseif kindIdx == 2 then
			-- Ash drift mound
			placeGroundCover("AshDriftClump", rx, gy, rz, rng:NextNumber(0, 360), function(cf)
				lump("AshMoundA", cf:PointToWorldSpace(V(0, 0.2, 0)), V(4.2, 0.8, 3.2), ASH_GREY, Mat.Slate)
				lump("AshMoundB", cf:PointToWorldSpace(V(1.6, 0.15, 0.8)), V(2.4, 0.5, 2.0), rgb(104, 100, 112), Mat.Slate)
			end)
		elseif kindIdx == 3 then
			-- Fallen Halcyr page drift (Floors 46-47 continuity!)
			placeGroundCover("FallenPageClump", rx, gy, rz, rng:NextNumber(0, 360), function(cf)
				boxAt("PageA", cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0.3, 0), V(1.1, 0.06, 0.85), rgb(236, 228, 212), Mat.Fabric)
				boxAt("PageB", cf * CFrame.new(0.8, 0.08, -0.5) * CFrame.Angles(0, -0.8, 0.05), V(1.0, 0.06, 0.8), rgb(224, 214, 196), Mat.Fabric)
			end)
		else
			-- Scattered chain link & bone shard clump
			placeGroundCover("ChainShardClump", rx, gy, rz, rng:NextNumber(0, 360), function(cf)
				boxAt("CutChainA", cf * CFrame.new(0, 0.16, 0), V(1.8, 0.28, 0.65), CHAIN_IRON, Mat.Metal)
				boxAt("BoneShard", cf * CFrame.new(-0.8, 0.18, 0.7) * CFrame.Angles(0, 0.7, 0.15), V(1.4, 0.32, 0.45), BONE_MARBLE, Mat.Limestone)
			end)
		end
		if not onDeck then
			-- Also allow extra chasm-slope ash/rubble density
		end
	end

	-- 2) Terrace-edge & Muster rim ground cover to guarantee >= 420 clumps
	local terraceTargets = {
		{ P.Basin, 96 }, { P.WestGallery, 26 }, { P.EastGallery, 26 },
		{ P.ShrineW, 20 }, { P.ShrineE, 20 }, { P.StationW, 22 }, { P.StationE, 22 },
		{ P.ChapelW, 20 }, { P.ChapelE, 20 }, { P.VigilW, 20 }, { P.VigilE, 20 },
		{ P.Ossuary, 22 }, { P.Crossing, 18 }, { P.Mourners, 14 },
	}
	for _, spec in terraceTargets do
		local plat, want = spec[1], spec[2]
		if not plat then continue end
		local placedHere = 0
		for attempt = 1, want * 3 do
			if placedHere >= want then break end
			local tx = plat.X + rng:NextNumber(-plat.Width * 0.46, plat.Width * 0.46)
			local tz = plat.Z + rng:NextNumber(-plat.Depth * 0.46, plat.Depth * 0.46)
			if not coverClear(tx, tz) then continue end
			placedHere += 1
			local mode = (attempt + placedHere) % 4
			placeGroundCover("TerraceDetailClump", tx, plat.Y, tz, rng:NextNumber(0, 360), function(cf)
				if mode == 0 then
					boxAt("MarbleChipA", cf * CFrame.new(0, 0.25, 0), V(1.8, 0.48, 1.4), BONE_MARBLE, Mat.Limestone)
					boxAt("MarbleChipB", cf * CFrame.new(0.9, 0.18, 0.6), V(1.1, 0.34, 0.9), BONE_MUTED, Mat.Limestone)
				elseif mode == 1 then
					lump("AshPatch", cf:PointToWorldSpace(V(0, 0.14, 0)), V(3.4, 0.45, 2.8), ASH_GREY, Mat.Slate)
				elseif mode == 2 then
					boxAt("FallenBlade", cf * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0.4, 0), V(0.32, 0.16, 2.8), BLACK_IRON, Mat.Metal)
					boxAt("TornCloth", cf * CFrame.new(0.5, 0.08, -0.3), V(1.3, 0.08, 1.5), WINE_SILK, Mat.Fabric)
				else
					boxAt("VahlPage", cf * CFrame.new(0, 0.05, 0), V(1.0, 0.05, 0.8), rgb(236, 228, 212), Mat.Fabric)
					boxAt("CutIronLink", cf * CFrame.new(-0.7, 0.14, 0.5), V(1.1, 0.24, 0.5), CHAIN_IRON, Mat.Metal)
				end
			end)
		end
	end

	-- 3) Fill any remaining ground cover up to 445+ along outer chasm floor & terrace rims
	local fillAttempt = 0
	while groundCoverCount < 445 and fillAttempt < 1600 do
		fillAttempt += 1
		local fx = rng:NextNumber(-336, 336)
		local fz = rng:NextNumber(-332, 332)
		if math.abs(fx) < 95 and fz < -95 and fz > -225 then continue end
		if not coverClear(fx, fz) then continue end
		local gy = H.surfaceAt(fx, fz)
		if gy < -4.2 then continue end
		placeGroundCover("ChasmAshClump", fx, gy, fz, rng:NextNumber(0, 360), function(cf)
			if fillAttempt % 2 == 0 then
				lump("ChasmAsh", cf:PointToWorldSpace(V(0, 0.25, 0)), V(4.5, 0.9, 3.6), ASH_GREY, Mat.Slate)
			else
				boxAt("ChasmShard", cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0.25, 0.3, -0.2), V(1.6, 1.4, 1.4), BASALT_MID, Mat.Basalt)
			end
		end)
	end

	-- =========================================================================
	-- J. DIRGE ASH & PAGE EMITTERS (<= 12 emitters, client-animated on toll)
	-- =========================================================================
	addDirgeAshEmitter(V(0, 12, 210), 4)
	addDirgeAshEmitter(V(-110, 14, 95), 3)
	addDirgeAshEmitter(V(110, 18, 95), 3)
	addDirgeAshEmitter(V(0, 22, 20), 4)
	addDirgeAshEmitter(V(-145, 34, -55), 3)
	addDirgeAshEmitter(V(145, 38, -55), 3)
	addDirgeAshEmitter(V(0, 30, -60), 4)
	addDirgeAshEmitter(V(0, 56, -160), 4)
	addDirgeAshEmitter(V(0, 52, -290), 4)
	addDirgeAshEmitter(V(0, 165, -268), 5)

	ctx.setAttribute("AbyssalFloor", 47)
	ctx.setAttribute("PlacedPropCount", placedPropCount)
	ctx.setAttribute("GroundCoverCount", groundCoverCount)
	ctx.setAttribute("DistinctTemplateCount", distinctTemplateCount)
	ctx.setAttribute("SetPieceLightCount", lightsUsed)
end

return AbyssalFloor47
