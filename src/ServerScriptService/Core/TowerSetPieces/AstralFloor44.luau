--!strict
-- Hand-authored set pieces for Astral Archives Floor 44: Runeguard Athenaeum (astral:4, ELITE_STRONGHOLD).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 44) & Runeguard Athenaeum guide art.
--
-- Sealed by the Runeguard: three compact, stepped architectural fortress wards over two deep starry void
-- moats, separated wall-to-wall by luminous pale starlight-gold rune-ward glyph curtains anchored on grounded
-- stone moat piers, pierced ONLY by straight 0° north-south West & East Waygate bridges passing cleanly
-- through golden Waygate ring-portals (the floor's only unshuttered gold lamps). Solid walkable outer terrace
-- bays house every vignette facing its courtyard — Copyists' Yard awnings, Binders' Yard sewing frames,
-- Porters' Lodge lift-cage, flanking crenellated Runeguard Bastion Towers with lapis banners, the open-front
-- colonnaded Hall of Indices, the open-front Seal Forge smithy, the Court of Seals presses, the cliff-carved
-- Forbidden Vault ring door, the Reliquary of Lenses & shelves — crowned back-east by the 213-stud chained
-- Athenaeum Dome with glowing golden arched windows on a rocky cliff pedestal under a tapered violet sky Rift.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AstralFloor44 = {}

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

-- Sealed indigo dusk palette matching the Runeguard Athenaeum fortress artwork.
local RIFTWARD_44 = table.freeze({
	STONE = swatch(164, 166, 176, Mat.Slate),
	ALT = swatch(38, 52, 102, Mat.Marble),
	TRIM = swatch(224, 190, 108, Mat.Metal),
	METAL = swatch(178, 144, 78, Mat.Metal),
	WOOD = swatch(96, 64, 44, Mat.Wood),
	SILK = swatch(234, 224, 204, Mat.Fabric),
	GLOW = swatch(252, 228, 162, Mat.Neon),
	CRYSTAL = swatch(154, 198, 240, Mat.Glass, 0.22),
	MOSS = swatch(74, 98, 114, Mat.Grass),
})

local WARD_VEIL_TINT = tinted(RIFTWARD_44, {
	STONE = swatch(138, 142, 156, Mat.Slate),
	ALT = swatch(42, 54, 98, Mat.Marble),
	TRIM = swatch(236, 202, 118, Mat.Metal),
	METAL = swatch(188, 154, 84, Mat.Metal),
	GLOW = swatch(255, 230, 162, Mat.Neon),
	CRYSTAL = swatch(248, 220, 158, Mat.Glass, 0.34),
})

local WARD_PYLON_TINT = tinted(RIFTWARD_44, {
	STONE = swatch(154, 158, 170, Mat.Slate),
	ALT = swatch(44, 62, 118, Mat.Marble),
	CRYSTAL = swatch(74, 110, 186, Mat.Marble),
	GLOW = swatch(252, 226, 158, Mat.Neon),
})

local DOME_TINT = tinted(RIFTWARD_44, {
	STONE = swatch(204, 198, 186, Mat.Limestone),
	ALT = swatch(42, 62, 126, Mat.Marble),
	TRIM = swatch(234, 200, 112, Mat.Metal),
	METAL = swatch(198, 162, 86, Mat.Metal),
	WOOD = swatch(92, 60, 42, Mat.Wood),
	GLOW = swatch(255, 228, 152, Mat.Neon),
})

local TOWER_TINT = tinted(RIFTWARD_44, {
	STONE = swatch(140, 144, 158, Mat.Slate),
	ALT = swatch(82, 88, 108, Mat.Slate),
	TRIM = swatch(204, 172, 98, Mat.Metal),
	METAL = swatch(136, 116, 80, Mat.Metal),
	GLOW = swatch(250, 224, 154, Mat.Neon),
})

local LIBRARY_TINT = tinted(RIFTWARD_44, {
	STONE = swatch(166, 168, 178, Mat.Slate),
	WOOD = swatch(112, 74, 48, Mat.Wood),
	SILK = swatch(236, 226, 206, Mat.Fabric),
	TRIM = swatch(224, 190, 108, Mat.Metal),
	GLOW = swatch(252, 228, 160, Mat.Neon),
})

local SHUTTER_TINT = tinted(RIFTWARD_44, {
	STONE = swatch(132, 136, 150, Mat.Slate),
	ALT = swatch(48, 54, 78, Mat.Slate),
	GLOW = swatch(96, 102, 128, Mat.SmoothPlastic),
})

local CIRCLE_TINT = tinted(RIFTWARD_44, {
	STONE = swatch(154, 158, 170, Mat.Slate),
	ALT = swatch(134, 138, 152, Mat.Slate),
	TRIM = swatch(208, 178, 108, Mat.Metal),
	GLOW = swatch(232, 214, 164, Mat.SmoothPlastic),
})

local STONE_TOP = rgb(148, 152, 166)
local STONE_LIGHT = rgb(166, 170, 182)
local STONE_DARK = rgb(94, 98, 116)
local WALL_FACE = rgb(118, 122, 138)
local CLIFF_ROCK = rgb(62, 68, 86)
local CLIFF_MID = rgb(48, 52, 70)
local CLIFF_DEEP = rgb(32, 36, 54)
local LAPIS_BANNER = rgb(44, 68, 134)
local GOLD_BRIGHT = rgb(228, 194, 110)
local BRASS_AGED = rgb(180, 146, 80)
local WOOD_WARM = rgb(108, 72, 46)
local WOOD_DARK = rgb(74, 48, 34)
local VELLUM_PAGE = rgb(238, 228, 208)

local GOLD_LIGHT = rgb(252, 226, 156)
local WARD_LIGHT = rgb(254, 228, 162)
local RIFT_VIOLET = rgb(176, 98, 255)
local RIFT_CORE = rgb(226, 184, 255)

local ABYSS_Y = -36

-- Floor 44's 22 landmark footprints (tight compact 3-ward fortress inside 800 x 795 room).
AstralFloor44.Landmarks = table.freeze({
	-- 1–2. The Athenaeum Dome over The Sealed Stacks (103.8 + 109.3 = 213.1 >= 210 studs tall!)
	{ Id = "AthenaeumDomeCrown", X = 176, Z = -326, Y = 162, HalfX = 52.3, HalfZ = 52.4, Top = 109.3, Straddles = true },
	{ Id = "AthenaeumDomeDrum", X = 176, Z = -326, Y = 60, HalfX = 72.4, HalfZ = 51.6, Top = 103.8, Straddles = true },
	-- 3–4. The Two Waygate Ring-Portals (ONLY crossings of Ward 1 & Ward 2, ONLY unshuttered gold lamps)
	{ Id = "WestWaygateRing", X = -106, Z = -4, Y = 18, HalfX = 18.7, HalfZ = 4.0, Top = 37.9, Straddles = true },
	{ Id = "EastWaygateRing", X = 154, Z = -176, Y = 48, HalfX = 18.7, HalfZ = 4.0, Top = 37.9, Straddles = true },
	-- 5–6. West & East Runeguard Bastion Towers on solid outer flank bays (facing INWARD toward courts)
	{ Id = "WestRuneguardTower", X = -278, Z = -96, Y = 34, HalfX = 15.5, HalfZ = 15.5, Top = 36.6 },
	{ Id = "EastRuneguardTower", X = 300, Z = -96, Y = 42, HalfX = 15.5, HalfZ = 15.5, Top = 36.6 },
	-- 7. Hall of Indices great star-glyph board mounted inside the open-front north reading pavilion (facing SOUTH)
	{ Id = "HallIndexBoard", X = 14, Z = -152, Y = 30, HalfX = 11.4, HalfZ = 2.0, Top = 14.8 },
	-- 8. Seal Forge furnace & star-iron anvil inside the open-front smithy alcove (facing SOUTH)
	{ Id = "SealForgeAnvil", X = 206, Z = -146, Y = 38, HalfX = 8.4, HalfZ = 4.8, Top = 14.6 },
	-- 9. Court of Seals stamping press & oath-stones on north shrine bay (facing SOUTH)
	{ Id = "CourtSealPress", X = -4, Z = -362, Y = 52, HalfX = 9.0, HalfZ = 3.2, Top = 10.8 },
	-- 10. Forbidden Vault half-open geared brass ring door embedded in the north-west rocky cliff (facing SOUTH)
	{ Id = "ForbiddenVaultDoor", X = -112, Z = -378, Y = 56, HalfX = 13.0, HalfZ = 6.0, Top = 23.0 },
	-- 11. Reliquary of Lenses ground-lens rack on Reliquary solid west bay (facing EAST)
	{ Id = "ReliquaryLensRack", X = -266, Z = -224, Y = 50, HalfX = 2.6, HalfZ = 9.0, Top = 14.2 },
	-- 12. Lantern Walk chained confiscated tomes on LanternWalk north bay (facing SOUTH)
	{ Id = "LanternWalkTomeRack", X = -106, Z = -140, Y = 26, HalfX = 6.4, HalfZ = 5.6, Top = 17.6 },
	-- 13. Copyists' Yard shaded awning on WestGallery solid west bay (facing EAST)
	{ Id = "CopyistAwningW", X = -264, Z = 84, Y = 12, HalfX = 3.8, HalfZ = 6.0, Top = 9.6 },
	-- 14. Binders' Yard sewing frame on EastGallery solid east bay (facing WEST)
	{ Id = "BindersSewingFrame", X = 256, Z = 84, Y = 16, HalfX = 2.0, HalfZ = 6.4, Top = 8.4 },
	-- 15. Porters' Lodge book-cart lift-cage on Lodge solid north bay (facing SOUTH)
	{ Id = "PortersBookCart", X = 90, Z = 54, Y = 4, HalfX = 7.4, HalfZ = 4.8, Top = 16.2 },
	-- 16–18. First Rune-Ward Pylons along Z = -4 (flanking West Waygate at X = -106)
	{ Id = "Ward1PylonWest", X = -286, Z = -4, Y = 12, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward1PylonMid", X = -70, Z = -4, Y = 12, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward1PylonEast", X = 110, Z = -4, Y = 12, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	-- 19–21. Second Rune-Ward Pylons along Z = -176 (flanking East Waygate at X = +154)
	{ Id = "Ward2PylonWest", X = -286, Z = -176, Y = 36, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward2PylonMid", X = 10, Z = -176, Y = 36, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	{ Id = "Ward2PylonEast", X = 298, Z = -176, Y = 36, HalfX = 4.0, HalfZ = 4.0, Top = 27.0 },
	-- 22. Warded Court flush floor waiting medallion centered cleanly south of West Waygate
	{ Id = "WardedCircleFloor", X = -106, Z = 98, Y = 8, HalfX = 12.0, HalfZ = 12.0, Top = 0.4, Straddles = true },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AstralFloor44.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = H.P
	local _boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	-- Keep total room lights strictly <= 24 (TowerRoomBuilder adds ~8 portal/sanctuary lights, so cap at 14 here!)
	local lightsUsed = 0
	local emittersUsed = 0
	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 14 then
			lightsUsed += 1
			light(p, color, brightness, range)
		end
	end
	local function pin(m: Instance?)
		if m then m:SetAttribute("OnTerrain", true) end
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
	local function tagDetail(m: Instance?)
		if not m then return end
		makeDecor(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				safeTag(d, "TowerDetail")
			end
		end
	end

	local function placeKitScaled(groupName: string, x: number, y: number, z: number, yawDeg: number, kitName: string, scale: Vector3, override: any?, fallback: ((cf: CFrame) -> ())?): Instance?
		local prop: Instance? = nil
		ctx.group(groupName, function()
			prop = ctx.current()
			local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
			if ctx.has(kitName) then
				ctx.kitAt(kitName, cf, scale, override)
			elseif fallback then
				fallback(cf)
			end
		end)
		pin(prop)
		return prop
	end

	local function addLightCurtain(name: string, p0: Vector3, p1: Vector3, height0: number, height1: number, col0: Color3, col1: Color3, alpha: number, faceCam: boolean?, taperEnds: boolean?)
		local mid = (p0 + p1) * 0.5
		local anchor = ctx.block(name .. "_Anchor", V(1, 1, 1), mid, col0, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
		anchor:SetAttribute("SolidScenery", false)
		anchor:SetAttribute("ConjunctionGlyph", true)
		safeTag(anchor, "ConjunctionGlyph")
		local a0 = Instance.new("Attachment")
		a0.Position = p0 - mid
		a0.Axis = V(0, 1, 0)
		a0.SecondaryAxis = V(0, 0, 1)
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Position = p1 - mid
		a1.Axis = V(0, 1, 0)
		a1.SecondaryAxis = V(0, 0, 1)
		a1.Parent = anchor
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = height0
		b.Width1 = height1
		b.FaceCamera = faceCam == true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Segments = 16
		b.Color = ColorSequence.new(col0, col1)
		if taperEnds then
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, 1.0),
				NumberSequenceKeypoint.new(0.18, math.min(0.95, alpha + 0.16)),
				NumberSequenceKeypoint.new(0.50, alpha),
				NumberSequenceKeypoint.new(0.82, math.min(0.95, alpha + 0.16)),
				NumberSequenceKeypoint.new(1.0, 1.0),
			})
		else
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0.0, math.min(0.95, alpha + 0.08)),
				NumberSequenceKeypoint.new(0.06, alpha),
				NumberSequenceKeypoint.new(0.94, alpha),
				NumberSequenceKeypoint.new(1.0, math.min(0.95, alpha + 0.08)),
			})
		end
		b.Parent = anchor
	end

	local function pageEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 12 then return end
		emittersUsed += 1
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, VELLUM_PAGE, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(242, 232, 210), rgb(252, 228, 168))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.3) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3.0, 5.0)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1.0, 2.4)
		pe.SpreadAngle = Vector2.new(50, 50)
		pe.RotSpeed = NumberRange.new(-50, 50)
		pe.Acceleration = V(0, 0.35, 0)
		pe.Parent = anchor
	end

	local function moatMistEmitter(pos: Vector3, spread: number)
		if emittersUsed >= 12 then return end
		emittersUsed += 1
		local anchor = ctx.block("MoatMistAnchor", V(spread, 2, 18), pos, rgb(42, 50, 108), Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralMoatMist"
		pe.Color = ColorSequence.new(rgb(52, 62, 128), rgb(26, 32, 74))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(0.5, 22), NumberSequenceKeypoint.new(1, 28) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.86), NumberSequenceKeypoint.new(0.75, 0.90), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(5.5, 8.5)
		pe.Rate = 2.0
		pe.Speed = NumberRange.new(0.8, 2.0)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.LightEmission = 0.35
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = anchor
	end

	local fenceColliders: { BasePart } = {}
	local function enableFences()
		for _, c in fenceColliders do
			c.CanCollide = true
			c.CanQuery = true
		end
		table.clear(fenceColliders)
	end

	local function balustradeSpan(x0: number, z0: number, x1: number, z1: number, y: number, lampEvery: number?, withPointLight: boolean?)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local len = (b - a).Magnitude
		if len < 4 then return end
		local mid = (a + b) * 0.5
		local cf = CFrame.lookAt(mid, b)
		boxAt("WardBalWall", cf * CFrame.new(0, 1.35, 0), V(1.5, 2.7, len), WALL_FACE, Mat.Slate)
		boxAt("WardBalBase", cf * CFrame.new(0, 0.35, 0), V(1.9, 0.7, len + 0.4), STONE_DARK, Mat.Slate)
		boxAt("WardBalCap", cf * CFrame.new(0, 2.85, 0), V(1.85, 0.42, len + 0.4), STONE_LIGHT, Mat.Slate)
		boxAt("WardBalTrim", cf * CFrame.new(0, 3.14, 0), V(1.25, 0.22, len), BRASS_AGED, Mat.Metal)
		local col = boxAt("WardBalCollider", cf * CFrame.new(0, 1.8, 0), V(1.6, 3.6, len + 0.4), WALL_FACE, Mat.Slate, 1)
		table.insert(fenceColliders, col)
		local posts = math.max(2, math.floor(len / 20))
		for i = 0, posts do
			local pt = a:Lerp(b, i / posts)
			local isEnd = (i == 0 or i == posts)
			local pw = if isEnd then 2.4 else 2.0
			local ph = if isEnd then 3.8 else 3.4
			boxAt("WardBalPillar", CFrame.new(pt + V(0, ph * 0.5, 0)), V(pw, ph, pw), STONE_LIGHT, Mat.Slate)
			boxAt("WardBalPillarCap", CFrame.new(pt + V(0, ph + 0.22, 0)), V(pw + 0.35, 0.38, pw + 0.35), GOLD_BRIGHT, Mat.Metal)
			if lampEvery and lampEvery > 0 and i > 0 and i < posts and (i % lampEvery == 0) then
				ctx.cyl("WardLampPost", pt + V(0, ph + 3.2, 0), 0.32, 6.2, rgb(42, 46, 62), Mat.Metal)
				boxAt("WardLampHood", CFrame.new(pt + V(0, ph + 6.9, 0)), V(1.5, 0.45, 1.5), BRASS_AGED, Mat.Metal)
				local bulb = lump("WardLampGlow", pt + V(0, ph + 6.1, 0), V(1.3, 1.6, 1.3), GOLD_LIGHT, Mat.Neon)
				bulb:SetAttribute("ConjunctionLamp", true)
				safeTag(bulb, "ConjunctionLamp")
				if withPointLight then
					addLight(bulb, GOLD_LIGHT, 1.3, 46)
				end
			end
		end
	end

	local function streetLamp(pos: Vector3, emitLight: boolean?)
		ctx.cyl("StreetLampBase", pos + V(0, 0.9, 0), 0.75, 1.8, STONE_LIGHT, Mat.Slate)
		ctx.cyl("StreetLampShaft", pos + V(0, 5.2, 0), 0.28, 7.6, rgb(46, 50, 66), Mat.Metal)
		boxAt("StreetLampCap", CFrame.new(pos + V(0, 9.8, 0)), V(1.5, 0.42, 1.5), BRASS_AGED, Mat.Metal)
		local bulb = lump("StreetLampBulb", pos + V(0, 9.0, 0), V(1.3, 1.65, 1.3), GOLD_LIGHT, Mat.Neon)
		bulb:SetAttribute("ConjunctionLamp", true)
		safeTag(bulb, "ConjunctionLamp")
		if emitLight then
			addLight(bulb, GOLD_LIGHT, 1.35, 48)
		end
	end

	local function buildBench(pos: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		boxAt("BenchSeat", cf * CFrame.new(0, 1.6, 0), V(7.6, 0.42, 2.2), WOOD_WARM, Mat.Wood)
		boxAt("BenchBack", cf * CFrame.new(0, 2.9, -0.95), V(7.6, 1.8, 0.35), WOOD_DARK, Mat.Wood)
		for _, sx in { -3.1, 3.1 } do
			boxAt("BenchLeg", cf * CFrame.new(sx, 0.85, 0), V(0.55, 1.7, 2.1), STONE_DARK, Mat.Slate)
		end
	end

	local function buildCrateCluster(pos: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		for _, spec in {
			{ V(0, 1.4, 0), 2.8, 0 },
			{ V(3.1, 1.15, 0.5), 2.3, 16 },
			{ V(-2.9, 1.1, -0.6), 2.2, -18 },
			{ V(0.3, 3.9, -0.1), 2.2, 24 },
		} do
			local c = cf * CFrame.new(spec[1]) * CFrame.Angles(0, math.rad(spec[3]), 0)
			local sz = spec[2]
			boxAt("ArchiveCrate", c, V(sz, sz, sz), WOOD_WARM, Mat.Wood)
			boxAt("ArchiveCrateBand", c, V(sz + 0.14, 0.28, sz + 0.14), BRASS_AGED, Mat.Metal)
		end
	end

	local function buildStandingBookcase(pos: Vector3, yawDeg: number, scale: number)
		local s = scale
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		local w, h, d = 11.6 * s, 14.0 * s, 3.2 * s
		boxAt("CaseBack", cf * CFrame.new(0, h * 0.5, -d * 0.36), V(w, h, 0.7 * s), WOOD_DARK, Mat.Wood)
		for _, sx in { -1, 1 } do
			boxAt("CaseSide", cf * CFrame.new(sx * (w * 0.5 - 0.5 * s), h * 0.5, 0), V(1.0 * s, h, d), WOOD_WARM, Mat.Wood)
		end
		boxAt("CaseCrown", cf * CFrame.new(0, h + 0.4 * s, 0.2 * s), V(w + 1.2 * s, 1.0 * s, d + 0.7 * s), WOOD_WARM, Mat.Wood)
		boxAt("CaseCrownTrim", cf * CFrame.new(0, h + 0.95 * s, 0.2 * s), V(w + 1.4 * s, 0.32 * s, d + 0.9 * s), BRASS_AGED, Mat.Metal)
		boxAt("CasePlinth", cf * CFrame.new(0, 0.55 * s, 0), V(w + 0.5 * s, 1.1 * s, d + 0.3 * s), WOOD_DARK, Mat.Wood)
		for row = 0, 3 do
			local ry = (2.1 + row * 2.9) * s
			boxAt("CaseShelf", cf * CFrame.new(0, ry, 0), V(w - 1.2 * s, 0.38 * s, d - 0.5 * s), WOOD_WARM, Mat.Wood)
			for b = 0, 3 do
				local bx = (-w * 0.34 + b * (w * 0.22))
				local bh = (1.9 + ((row + b) % 3) * 0.22) * s
				local bCol = if (row + b) % 3 == 0 then rgb(126, 62, 48) elseif (row + b) % 3 == 1 then rgb(54, 72, 118) else rgb(146, 118, 68)
				boxAt("CaseBooks", cf * CFrame.new(bx, ry + bh * 0.5 + 0.2 * s, 0.22 * s), V(2.0 * s, bh, 1.7 * s), bCol, Mat.Wood)
			end
		end
	end

	local function buildRockOutcrop(pos: Vector3, size: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		boxAt("CliffCore", cf * CFrame.new(0, size.Y * 0.35, 0) * CFrame.Angles(math.rad(4), math.rad(6), math.rad(-3)),
			V(size.X, size.Y * 0.70, size.Z), CLIFF_ROCK, Mat.Slate)
		boxAt("CliffShoulderA", cf * CFrame.new(-size.X * 0.22, size.Y * 0.50, size.Z * 0.12) * CFrame.Angles(math.rad(-6), math.rad(16), math.rad(7)),
			V(size.X * 0.60, size.Y * 0.54, size.Z * 0.64), CLIFF_MID, Mat.Slate)
		boxAt("CliffShoulderB", cf * CFrame.new(size.X * 0.22, size.Y * 0.44, -size.Z * 0.10) * CFrame.Angles(math.rad(6), math.rad(-14), math.rad(-8)),
			V(size.X * 0.54, size.Y * 0.48, size.Z * 0.60), STONE_DARK, Mat.Slate)
		boxAt("CliffCrest", cf * CFrame.new(0, size.Y * 0.76, 0) * CFrame.Angles(math.rad(-3), math.rad(10), math.rad(4)),
			V(size.X * 0.46, size.Y * 0.36, size.Z * 0.46), CLIFF_ROCK, Mat.Slate)
	end

	-- IMPORTANT: Never use "Sea" inside `id` (TowerBiomeAssets treats names containing "Sea" as translucent liquid!).
	local function buildFortressFoundation(id: string, x: number, y: number, z: number, w: number, d: number, seed: number, isWalkableBay: boolean?, rockySkirt: boolean?)
		local bottomY = ABYSS_Y + 1.0
		local totalH = math.max(24.0, y - bottomY)
		ctx.group("AstralIsleDeck", function()
			local solidBayDeck: Part? = nil
			if isWalkableBay then
				solidBayDeck = boxAt(id .. "WalkDeck", CFrame.new(V(x, y - 0.90, z)), V(w, 1.8, d), STONE_TOP, Mat.Slate)
			else
				boxAt(id .. "DeckCornice", CFrame.new(V(x, y - 1.14, z)), V(w + 1.2, 2.0, d + 1.2), STONE_LIGHT, Mat.Slate)
			end
			boxAt(id .. "BrassFrieze", CFrame.new(V(x, y - 2.20, z)), V(w + 1.5, 0.42, d + 1.5), BRASS_AGED, Mat.Metal)

			local hullH = totalH - 2.4
			local h1, h2 = hullH * 0.46, hullH * 0.56
			boxAt(id .. "WallUpper", CFrame.new(V(x, y - 2.4 - h1 * 0.5, z)), V(w - 0.8, h1, d - 0.8), if rockySkirt then CLIFF_ROCK else WALL_FACE, Mat.Slate)
			boxAt(id .. "WallLower", CFrame.new(V(x, bottomY + h2 * 0.5, z)), V(w * 0.92, h2, d * 0.92), if rockySkirt then CLIFF_DEEP else CLIFF_MID, Mat.Slate)

			local halfW, halfD = w * 0.5, d * 0.5
			local nPilX = math.clamp(math.floor(w / 32), 2, 6)
			for i = 0, nPilX do
				local px = x - halfW + 4 + ((w - 8) * i / nPilX)
				for _, sz in { -1, 1 } do
					if rockySkirt then
						local cf = CFrame.new(V(px, y - 2.4 - hullH * 0.42, z + sz * (halfD - 1.5)))
							* CFrame.Angles(math.rad(-sz * 8), math.rad(((i * 19 + seed) % 18) - 9), 0)
						boxAt(id .. "RockButtressZ", cf, V(14, hullH * 0.78, 10), if i % 2 == 0 then CLIFF_ROCK else CLIFF_MID, Mat.Slate)
					else
						boxAt(id .. "PilasterZ", CFrame.new(V(px, y - 2.4 - h1 * 0.5, z + sz * (halfD - 0.4))), V(3.4, h1 + 0.6, 2.2), STONE_DARK, Mat.Slate)
					end
				end
			end
			local nPilZ = math.clamp(math.floor(d / 32), 1, 4)
			for i = 0, nPilZ do
				local pz = z - halfD + 4 + ((d - 8) * i / math.max(1, nPilZ))
				for _, sx in { -1, 1 } do
					if rockySkirt then
						local cf = CFrame.new(V(x + sx * (halfW - 1.5), y - 2.4 - hullH * 0.42, pz))
							* CFrame.Angles(0, math.rad(((i * 23 + seed) % 18) - 9), math.rad(sx * 8))
						boxAt(id .. "RockButtressX", cf, V(10, hullH * 0.78, 14), if i % 2 == 0 then CLIFF_MID else CLIFF_ROCK, Mat.Slate)
					else
						boxAt(id .. "PilasterX", CFrame.new(V(x + sx * (halfW - 0.4), y - 2.4 - h1 * 0.5, pz)), V(2.2, h1 + 0.6, 3.4), STONE_DARK, Mat.Slate)
					end
				end
			end

			local nFlags = math.clamp(math.floor((w * d) / 960), 2, 7)
			for k = 1, nFlags do
				local fx = x + math.sin(k * 2.17 + seed) * (halfW * 0.56)
				local fz = z + math.cos(k * 1.63 + seed * 1.2) * (halfD * 0.54)
				local fw = 7.5 + ((k * 5 + seed) % 5)
				local fd = 6.0 + ((k * 3 + seed) % 4)
				boxAt(id .. "Paver", CFrame.new(V(fx, y + 0.045 + (k % 2) * 0.012, fz)), V(fw, 0.04, fd), if k % 2 == 0 then STONE_LIGHT else STONE_TOP, Mat.Slate)
			end

			makeDecor(ctx.current())
			if solidBayDeck then
				solidBayDeck.CanCollide = true
				solidBayDeck.CanQuery = true
				solidBayDeck.CanTouch = true
			end
			pin(ctx.current())
		end)
	end

	local function buildFloorMedallion(cx: number, y: number, cz: number, radius: number)
		ctx.cyl("MedallionOuter", V(cx, y + 0.06, cz), radius, 0.08, STONE_LIGHT, Mat.Slate)
		ctx.cyl("MedallionInner", V(cx, y + 0.11, cz), radius * 0.72, 0.08, STONE_TOP, Mat.Slate)
		ctx.ring("MedallionRingOuter", V(cx, y + 0.16, cz), radius * 0.96, 0.45, STONE_DARK, Mat.Slate, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
		ctx.ring("MedallionRingMid", V(cx, y + 0.17, cz), radius * 0.68, 0.34, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
		ctx.ring("MedallionRingCore", V(cx, y + 0.17, cz), radius * 0.30, 0.28, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)
	end

	for _, lm in AstralFloor44.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =========================================================================
	-- A. DEEP STARRY VOID MOATS & NEBULA FLOOR (PropKind = "AstralNebulaSea")
	-- =========================================================================
	ctx.group("AstralNebulaSea", function()
		boxAt("AthenaeumVoidFloor", CFrame.new(V(0, ABYSS_Y, -20)), V(980, 0.6, 1060), rgb(10, 12, 28), Mat.SmoothPlastic, 0)

		for idx, np in {
			{ -180, ABYSS_Y + 0.6, -4, 86, rgb(34, 42, 104), 0.72 },
			{ 30, ABYSS_Y + 0.6, -4, 96, rgb(44, 48, 118), 0.70 },
			{ 210, ABYSS_Y + 0.6, -4, 82, rgb(36, 44, 108), 0.72 },
			{ -180, ABYSS_Y + 0.6, -176, 88, rgb(48, 42, 118), 0.70 },
			{ 20, ABYSS_Y + 0.6, -176, 94, rgb(56, 44, 128), 0.68 },
			{ 210, ABYSS_Y + 0.6, -176, 82, rgb(42, 46, 114), 0.72 },
		} do
			local disc = ctx.cyl("MoatNebulaCloud_" .. idx, V(np[1], np[2], np[3]), np[4], 0.2, np[5], Mat.Neon)
			disc.Transparency = np[6]
		end

		for i = 1, 130 do
			local sx = math.sin(i * 12.9898) * 380
			local sz = math.cos(i * 78.233) * 430 - 20
			local sSize = if i % 7 == 0 then 2.0 elseif i % 3 == 0 then 1.3 else 0.85
			local sCol = if i % 5 == 0 then GOLD_LIGHT elseif i % 3 == 0 then rgb(186, 206, 255) else rgb(232, 236, 255)
			lump("MoatStarGlint", V(sx, ABYSS_Y + 0.85, sz), V(sSize, 0.24, sSize), sCol, Mat.Neon)
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	moatMistEmitter(V(-190, -22, -4), 95)
	moatMistEmitter(V(130, -22, -4), 110)
	moatMistEmitter(V(-110, -22, -176), 110)
	moatMistEmitter(V(220, -22, -176), 80)

	-- =========================================================================
	-- B. FORTRESS FOUNDATIONS & SOLID WALKABLE OUTER TERRACE BAYS
	-- =========================================================================
	local mainOrder = {
		{ "Sanctuary", "SanctuaryBase" },
		{ "Basin", "BasinYard" },
		{ "WestGallery", "WestCopyYard" },
		{ "Crossing", "WardedCourt" },
		{ "Loft", "OverlookLoft" },
		{ "Lodge", "PortersLodge" },
		{ "EastGallery", "EastBindYard" },
		{ "Gate1", "WestGateDeck" },
		{ "WestBastion", "WestTowerCourt" },
		{ "LanternWalk", "LanternWalk" },
		{ "Hall", "IndexHall" },
		{ "Forge", "SmithyCourt" },
		{ "EastBastion", "EastTowerCourt" },
		{ "Gate2", "EastGateDeck" },
		{ "Reliquary", "LensReliquary" },
		{ "Vault", "VaultCourt" },
		{ "Seals", "OathCourt" },
		{ "Apex", "ApexStacks" },
	}
	for idx, entry in mainOrder do
		local plat = P[entry[1]]
		if plat then
			local rocky = (entry[1] == "Apex" or entry[1] == "Vault" or entry[1] == "Basin")
			buildFortressFoundation(entry[2], plat.X, plat.Y, plat.Z, plat.Width, plat.Depth, idx * 17 + 5, false, rocky)
		end
	end

	-- Compact solid 100%-walkable opaque outer terrace bays strictly outside main deck edges!
	buildFortressFoundation("WestGalleryCopyBay", -264, 12, 98, 48, 68, 101, true, false)
	buildFortressFoundation("EastGalleryBindBay", 256, 16, 98, 48, 68, 102, true, false)
	buildFortressFoundation("LodgeNorthBay", 90, 4, 55, 56, 28, 103, true, false)
	buildFortressFoundation("WestTowerBay", -278, 34, -96, 48, 72, 104, true, false)
	buildFortressFoundation("LanternWalkNorthBay", -106, 26, -139, 64, 28, 105, true, false)
	buildFortressFoundation("HallNorthGalleryBay", 14, 30, -145, 84, 40, 106, true, false)
	buildFortressFoundation("ForgeAlcoveBay", 206, 38, -138, 44, 42, 107, true, false)
	buildFortressFoundation("EastTowerBay", 300, 42, -96, 44, 72, 108, true, false)
	buildFortressFoundation("ReliquaryWestBay", -266, 50, -224, 36, 62, 109, true, false)
	buildFortressFoundation("ReliquaryNorthStacksBay", -210, 50, -267, 76, 24, 110, true, false)
	buildFortressFoundation("VaultNorthCliffBay", -112, 56, -382, 74, 18, 111, true, true)
	buildFortressFoundation("CourtOfOathsBay", -4, 52, -362, 76, 32, 112, true, false)
	buildFortressFoundation("ApexDomeEastBay", 238, 60, -316, 36, 94, 113, true, true)
	buildFortressFoundation("ApexDomeNorthBay", 174, 60, -375, 164, 24, 114, true, true)

	-- =========================================================================
	-- C. COURTYARD BALUSTRADES, MEDALLIONS, STREET LAMPS & CURTAIN WALLS
	-- =========================================================================
	local basin = P.Basin
	if basin then
		ctx.group("AstralConcourseDeck", function()
			local by, bz = basin.Y, basin.Z
			local halfW, halfD = basin.Width * 0.5, basin.Depth * 0.5
			local northZ = bz - halfD + 1.2
			local southZ = bz + halfD - 1.2

			buildFloorMedallion(0, by, bz, 20.0)

			balustradeSpan(-halfW + 4, southZ, -19, southZ, by, 3, false)
			balustradeSpan(19, southZ, halfW - 4, southZ, by, 3, false)
			streetLamp(V(-20, by, southZ - 2), true)
			streetLamp(V(20, by, southZ - 2), true)

			local gaps: { { number } } = {}
			for _, link in ctx.layout.Links do
				if link.From == "Basin" or link.To == "Basin" then
					local ax = if link.From == "Basin" then link.AX else link.BX
					local tz = if link.From == "Basin" then link.BZ else link.AZ
					if tz < bz then
						local hOpen = link.Width * 0.5 + 1.4
						table.insert(gaps, { ax - hOpen, ax + hOpen })
					end
				end
			end
			table.sort(gaps, function(g1, g2) return g1[1] < g2[1] end)
			local curX = -halfW + 4
			for _, g in gaps do
				if g[1] - curX >= 6 then
					balustradeSpan(curX, northZ, g[1], northZ, by, 0, false)
				end
				curX = math.max(curX, g[2])
			end
			if (halfW - 4) - curX >= 6 then
				balustradeSpan(curX, northZ, halfW - 4, northZ, by, 0, false)
			end
			balustradeSpan(-halfW + 1.5, northZ + 4, -halfW + 1.5, southZ - 4, by, 0, false)
			balustradeSpan(halfW - 1.5, northZ + 4, halfW - 1.5, southZ - 4, by, 0, false)

			buildBench(V(-50, by, northZ + 5), 0)
			buildBench(V(44, by, northZ + 5), 0)
			buildCrateCluster(V(224, by, bz - 10), -20)
			buildCrateCluster(V(228, by, bz + 12), 18)
			buildCrateCluster(V(-226, by, bz + 12), 25)

			for _, rx in { -200, -140, -80, 80, 140, 200 } do
				buildRockOutcrop(V(rx, by - 36, southZ + 8), V(44, 33, 24), (rx * 0.25) % 40 - 20)
			end

			makeDecor(ctx.current())
			enableFences()
			pin(ctx.current())
		end)
	end

	ctx.group("AstralIsleBalustrade", function()
		-- Outer Ward north moat-facing balustrades & lamps (West Waygate at X = -106 wide open!)
		balustradeSpan(-286, 65.5, -170, 65.5, 12, 2, false)
		balustradeSpan(-140, 65.5, -118, 65.5, 8, 0, false)
		balustradeSpan(-94, 65.5, -72, 65.5, 8, 0, false)
		balustradeSpan(-36, 70.5, 16, 70.5, 14, 1, false)
		buildBench(V(-20, 14, 75), 0)
		buildBench(V(2, 14, 75), 0)
		balustradeSpan(64, 42.5, 116, 42.5, 4, 2, false)
		balustradeSpan(162, 65.5, 278, 65.5, 16, 2, false)
		balustradeSpan(-286.5, 66, -286.5, 130, 12, 0, false)
		balustradeSpan(278.5, 66, 278.5, 130, 16, 0, false)

		-- Middle Ward south promenade balustrades with warm street lamps!
		balustradeSpan(-252, -61.5, -184, -61.5, 34, 2, false)
		balustradeSpan(-136, -68.5, -118, -68.5, 26, 0, false)
		balustradeSpan(-94, -68.5, -76, -68.5, 26, 0, false)
		balustradeSpan(-26, -68.5, 54, -68.5, 30, 1, false)
		balustradeSpan(123, -68.5, 185, -68.5, 38, 2, false)
		balustradeSpan(208, -61.5, 276, -61.5, 42, 2, false)

		-- Middle Ward north moat-facing balustrades (East Waygate at X = +154 wide open!)
		balustradeSpan(-252, -130.5, -184, -130.5, 34, 2, false)
		balustradeSpan(-136, -151.5, -76, -151.5, 26, 2, false)
		buildBench(V(-124, 26, -144), 0)
		buildBench(V(-88, 26, -144), 0)
		balustradeSpan(123, -123.5, 142, -123.5, 38, 0, false)
		balustradeSpan(166, -123.5, 182, -123.5, 38, 0, false)
		balustradeSpan(230, -130.5, 276, -130.5, 42, 2, false)

		-- Inner Ward balustrades & Court of Seals circular paved medallion
		buildFloorMedallion(-4, 52, -316, 18.5)
		balustradeSpan(-246, -194.5, -174, -194.5, 50, 2, false)
		balustradeSpan(-282.5, -195, -282.5, -253, 50, 0, false)
		balustradeSpan(-40, -287.5, 4, -287.5, 52, 2, false)

		-- Apex Dome terrace balustrades (open cleanly for Waygate Stair south & Seal Stair west!)
		balustradeSpan(94, -270.5, 142, -270.5, 60, 1, false)
		balustradeSpan(166, -270.5, 254, -270.5, 60, 1, false)
		balustradeSpan(93.5, -304, 93.5, -272, 60, 0, false)
		balustradeSpan(93.5, -361, 93.5, -328, 60, 0, false)
		balustradeSpan(254.5, -385, 254.5, -272, 60, 2, false)
		streetLamp(V(136, 60, -273), true)
		streetLamp(V(172, 60, -273), true)
		streetLamp(V(96, 60, -298), false)
		streetLamp(V(96, 60, -334), false)

		-- Tight Inner Ward Crenellated Fortress Curtain Wall + 4 Corner Turrets!
		local wallY = 50
		local wallH = 22
		local function curtainSpan(ax: number, az: number, bx: number, bz: number, baseY: number, h: number)
			local p0, p1 = V(ax, baseY, az), V(bx, baseY, bz)
			local len = (p1 - p0).Magnitude
			local mid = (p0 + p1) * 0.5
			local cf = CFrame.lookAt(mid, p1)
			local body = boxAt("CurtainWallBody", cf * CFrame.new(0, h * 0.5 - 8, 0), V(5.5, h + 16, len), WALL_FACE, Mat.Slate)
			table.insert(fenceColliders, body)
			boxAt("CurtainWallWalk", cf * CFrame.new(0, h, 0), V(6.4, 1.2, len + 1), STONE_LIGHT, Mat.Slate)
			local merlons = math.max(3, math.floor(len / 9.5))
			for m = 0, merlons do
				local pt = p0:Lerp(p1, m / merlons)
				boxAt("CurtainMerlon", CFrame.new(pt + V(0, h + 2.4, 0)), V(5.2, 3.6, 4.4), STONE_LIGHT, Mat.Slate)
			end
		end
		curtainSpan(-286, -390, 274, -390, wallY, wallH)
		curtainSpan(-286, -390, -286, -194, wallY, wallH)
		curtainSpan(274, -390, 274, -254, wallY, wallH)
		for _, tp in { V(-286, wallY, -390), V(62, wallY, -390), V(274, wallY, -390), V(274, wallY, -256) } do
			ctx.cyl("CornerTurretDrum", tp + V(0, 12, 0), 8.0, 42, WALL_FACE, Mat.Slate)
			ctx.cyl("CornerTurretCap", tp + V(0, 34, 0), 9.2, 2.2, STONE_LIGHT, Mat.Slate)
			for k = 0, 7 do
				local a = k * math.pi / 4
				boxAt("CornerTurretMerlon", CFrame.new(tp + V(math.cos(a) * 8.2, 36.8, math.sin(a) * 8.2)), V(2.7, 3.4, 2.7), STONE_LIGHT, Mat.Slate)
			end
		end

		makeDecor(ctx.current())
		enableFences()
		pin(ctx.current())
	end)

	-- =========================================================================
	-- D. LANDMARKS 1–4: THE ATHENAEUM DOME & THE TWO GOLDEN WAYGATE RINGS
	-- =========================================================================
	do
		local drum = AstralFloor44.Landmarks[2]
		local md = placeKitScaled("AstralDome", drum.X, drum.Y :: number, drum.Z, 0, "AthenaeumDomeDrum", V(1.02, 0.88, 1.02), DOME_TINT, function(cf)
			for i = 0, 7 do
				local a = i * math.pi / 4
				if math.abs(a - math.pi / 2) > 0.4 then
					boxAt("DomePier", cf * CFrame.new(math.cos(a) * 45, 52, math.sin(a) * 45), V(7.2, 104, 7.2), DOME_TINT.STONE.Color, Mat.Limestone)
				end
			end
		end)
		noCollide(md)
		if md then addLight(H.glowOf(md) or md:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.4, 125) end

		local crown = AstralFloor44.Landmarks[1]
		local mc = placeKitScaled("AstralDome", crown.X, crown.Y :: number, crown.Z, 0, "AthenaeumDomeCrown", V(1.02, 1.05, 1.02), DOME_TINT, function(cf)
			ctx.orb("DomeCap", cf.Position + V(0, 52, 0), V(96, 96, 96), DOME_TINT.ALT.Color, Mat.Marble)
		end)
		noCollide(mc)

		-- Warm glowing golden cathedral arched windows flush on BOTH outer and inner faces of the 9 drum bays!
		ctx.group("AstralDome", function()
			local cx, cy, cz = drum.X, drum.Y :: number, drum.Z
			for _, rWin in { 46.0 * 1.02 + 0.8, 46.0 * 1.02 - 2.3 } do
				for k = 0, 11 do
					local aMid = 2 * math.pi * (k + 0.5) / 12
					if math.sin(aMid) > 0.45 then
						continue
					end
					local wx = cx + math.cos(aMid) * rWin
					local wz = cz + math.sin(aMid) * rWin
					local wcf = CFrame.lookAt(V(wx, cy, wz), V(cx, cy, cz))
					for row = 0, 5 do
						local py = 36.0 + row * 7.8
						local paneW = if row == 5 then 5.0 else 7.2
						for _, sx in { -3.6, 3.6 } do
							if row == 5 and math.abs(sx) > 2 then
								local p = boxAt("DomeWinGlow", wcf * CFrame.new(sx * 0.65, py, 0), V(paneW, 6.4, 0.45), GOLD_LIGHT, Mat.Neon)
								p:SetAttribute("ConjunctionLamp", true)
								safeTag(p, "ConjunctionLamp")
							else
								local p = boxAt("DomeWinGlow", wcf * CFrame.new(sx, py, 0), V(paneW, 7.2, 0.45), GOLD_LIGHT, Mat.Neon)
								p:SetAttribute("ConjunctionLamp", true)
								safeTag(p, "ConjunctionLamp")
							end
						end
					end
					boxAt("DomeWinMullionV", wcf * CFrame.new(0, 56, -0.3), V(0.7, 48, 0.55), GOLD_BRIGHT, Mat.Metal)
					for _, my in { 43.5, 59.0, 74.5 } do
						boxAt("DomeWinMullionH", wcf * CFrame.new(0, my, -0.3), V(14.6, 0.7, 0.55), GOLD_BRIGHT, Mat.Metal)
					end
				end
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		-- Dramatic curved rocky cliff pedestal strictly BELOW Apex (`top <= 58.5`)!
		ctx.group("AstralIsleDeck", function()
			for _, crag in {
				{ 106, 12, -266, 30, 46, 16, 14 },
				{ 196, 12, -266, 36, 46, 16, -12 },
				{ 244, 12, -272, 32, 46, 24, -22 },
				{ 260, 12, -314, 26, 46, 44, 6 },
				{ 258, 12, -358, 30, 46, 38, -14 },
			} do
				buildRockOutcrop(V(crag[1], crag[2], crag[3]), V(crag[4], crag[5], crag[6]), crag[7])
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 3–4. THE TWO GOLDEN WAYGATE RING-PORTALS (standing squarely over the 0° straight N-S Waygate bridges!)
	for _, idx in { 3, 4 } do
		local lm = AstralFloor44.Landmarks[idx]
		local mw = piece("AstralGateRing", lm.X, lm.Z, 0, "WaygateRing", 1.0, RIFTWARD_44, function(cf)
			ctx.ring("WaygateFallback", cf.Position + V(0, 19, 0), 17, 2.6, GOLD_BRIGHT, Mat.Metal, nil, 0, math.pi * 2, 18)
		end, lm.Y)
		pin(mw)
		noCollide(mw)
		if mw then
			mw:SetAttribute("ConjunctionLamp", true)
			safeTag(mw, "ConjunctionLamp")
			addLight(H.glowOf(mw) or mw:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.5, 76)
		end
	end

	-- =========================================================================
	-- E. LANDMARKS 5–15: PROPERLY POSITIONED & COURT-FACING FORTRESS VIGNETTES
	-- =========================================================================
	local propSpecs = {
		{ AstralFloor44.Landmarks[5], "RuneguardTower", 90, 1.24, TOWER_TINT },   -- West Tower -> faces EAST
		{ AstralFloor44.Landmarks[6], "RuneguardTower", -90, 1.24, TOWER_TINT },  -- East Tower -> faces WEST
		{ AstralFloor44.Landmarks[7], "IndexBoard", 0, 1.04, LIBRARY_TINT },      -- Hall of Indices -> faces SOUTH
		{ AstralFloor44.Landmarks[8], "StarIronAnvil", 0, 1.08, RIFTWARD_44 },    -- Seal Forge -> faces SOUTH
		{ AstralFloor44.Landmarks[9], "SealPress", 0, 1.06, RIFTWARD_44 },        -- Court of Seals -> faces SOUTH
		{ AstralFloor44.Landmarks[10], "VaultRingDoor", 0, 1.12, RIFTWARD_44 },   -- Forbidden Vault -> faces SOUTH
		{ AstralFloor44.Landmarks[11], "LensRack", 90, 1.04, LIBRARY_TINT },      -- Reliquary lens rack -> faces EAST
		{ AstralFloor44.Landmarks[12], "ChainedTomeRack", 0, 1.02, RIFTWARD_44 }, -- Lantern Walk tomes -> faces SOUTH
		{ AstralFloor44.Landmarks[13], "CopyistAwning", 90, 1.04, LIBRARY_TINT }, -- Copyists' awning -> faces EAST
		{ AstralFloor44.Landmarks[14], "SewingFrame", -90, 1.04, LIBRARY_TINT },  -- Binders' frame -> faces WEST
		{ AstralFloor44.Landmarks[15], "BookCartLift", 0, 1.02, LIBRARY_TINT },   -- Porters' lift-cage -> faces SOUTH
	}
	for _, spec in propSpecs do
		local lm = spec[1]
		local m = piece(lm.Id, lm.X, lm.Z, spec[3], spec[2], spec[4], spec[5], function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, lm.Top * 0.5, 0), V(lm.HalfX * 1.8, lm.Top, lm.HalfZ * 1.8), STONE_LIGHT, Mat.Slate)
		end, lm.Y)
		pin(m)
		if spec[2] == "IndexBoard" or spec[2] == "StarIronAnvil" or spec[2] == "VaultRingDoor" then
			addLight(H.glowOf(m) or (m and m:FindFirstChildWhichIsA("BasePart", true)), GOLD_LIGHT, 2.0, 65)
		end
	end

	-- Extra Copyists' awnings on WestGalleryCopyBay & far outer Basin flanks
	for _, aw in {
		{ -264, 12, 114, 90, 1.02 },
		{ -224, 0, 238, 45, 0.94 },
		{ -214, 0, 274, 0, 0.92 },
		{ 224, 0, 268, -40, 0.94 },
	} do
		local ma = piece("CopyistAwningExtra", aw[1], aw[3], aw[4], "CopyistAwning", aw[5], LIBRARY_TINT, function(cf)
			boxAt("AwningFallback", cf * CFrame.new(0, 4.5, 0), V(10, 9, 6), VELLUM_PAGE, Mat.Fabric)
		end, aw[2])
		pin(ma)
		tagDetail(ma)
	end

	do
		local ms = piece("BindersSewingExtra", 256, 114, -90, "SewingFrame", 1.04, LIBRARY_TINT, function(cf)
			boxAt("SewingFallback", cf * CFrame.new(0, 3.8, 0), V(10, 7.6, 3), WOOD_WARM, Mat.Wood)
		end, 16)
		pin(ms)
		tagDetail(ms)
	end

	-- Open-Front Hall of Indices Pavilion + Seal Forge Enclosure + Cliff Vault + Reliquary Shelves
	ctx.group("AstralIsleDeck", function()
		-- 1. Open-Front Hall of Indices Pavilion on HallNorthGalleryBay (100% open to SOUTH!)
		local hx, hy, hz = 14, 30, -145
		local hw, hd, hh = 80, 34, 17
		boxAt("HallBackWall", CFrame.new(V(hx, hy + hh * 0.5, hz - hd * 0.5 + 1.4)), V(hw, hh, 2.8), WALL_FACE, Mat.Slate)
		boxAt("HallRoofSlab", CFrame.new(V(hx, hy + hh + 0.9, hz)), V(hw + 2.4, 1.8, hd + 1.8), STONE_LIGHT, Mat.Slate)
		boxAt("HallRoofInlay", CFrame.new(V(hx, hy + hh + 1.95, hz)), V(hw - 2.0, 0.45, hd - 2.0), STONE_DARK, Mat.Slate)
		for _, sz in { -1, 1 } do
			boxAt("HallRoofLipZ", CFrame.new(V(hx, hy + hh + 2.0, hz + sz * (hd * 0.5 + 0.7))), V(hw + 2.8, 0.65, 1.2), STONE_LIGHT, Mat.Slate)
			boxAt("HallRoofBrassZ", CFrame.new(V(hx, hy + hh + 2.4, hz + sz * (hd * 0.5 + 0.7))), V(hw + 2.8, 0.25, 0.75), BRASS_AGED, Mat.Metal)
		end
		for _, sx in { -1, 1 } do
			boxAt("HallEndWall", CFrame.new(V(hx + sx * (hw * 0.5 - 1.4), hy + hh * 0.5, hz)), V(2.8, hh, hd), WALL_FACE, Mat.Slate)
			boxAt("HallRoofLipX", CFrame.new(V(hx + sx * (hw * 0.5 + 0.9), hy + hh + 2.0, hz)), V(1.2, 0.65, hd + 2.2), STONE_LIGHT, Mat.Slate)
		end
		for i = 0, 5 do
			local px = hx - hw * 0.5 + 3.0 + (hw - 6.0) * (i / 5)
			boxAt("HallFrontPier", CFrame.new(V(px, hy + hh * 0.5, hz + hd * 0.5 - 1.4)), V(2.4, hh, 2.4), STONE_LIGHT, Mat.Slate)
			boxAt("HallPierCap", CFrame.new(V(px, hy + hh - 0.3, hz + hd * 0.5 - 1.4)), V(3.0, 0.6, 3.0), GOLD_BRIGHT, Mat.Metal)
			if i > 0 and i < 5 and i ~= 2 and i ~= 3 then
				boxAt("HallAlcoveWall", CFrame.new(V(px, hy + 6.5, hz - 3.5)), V(1.5, 13.0, 15.0), WOOD_DARK, Mat.Wood)
			end
			if i < 5 then
				local wx = px + (hw - 6.0) / 10
				boxAt("HallWindowGlowA", CFrame.new(V(wx, hy + 7.2, hz - hd * 0.5 + 2.9)), V(6.6, 5.2, 0.45), GOLD_LIGHT, Mat.Neon)
				boxAt("HallWindowGlowB", CFrame.new(V(wx, hy + 12.2, hz - hd * 0.5 + 2.9)), V(6.0, 4.4, 0.45), GOLD_LIGHT, Mat.Neon)
				boxAt("HallWindowFrame", CFrame.new(V(wx, hy + 9.5, hz - hd * 0.5 + 3.1)), V(0.7, 9.8, 0.6), BRASS_AGED, Mat.Metal)
				if i ~= 2 then
					boxAt("HallStudyDesk", CFrame.new(V(wx, hy + 2.2, hz + 5.5)), V(7.6, 0.5, 4.0), WOOD_WARM, Mat.Wood)
					boxAt("HallStudyPage", CFrame.new(V(wx, hy + 2.55, hz + 5.5)), V(2.2, 0.14, 1.7), VELLUM_PAGE, Mat.Fabric)
				end
			end
		end

		-- 2. Open-Front Stone Seal Forge Smithy Enclosure on ForgeAlcoveBay (100% open to SOUTH!)
		local fx, fy, fz = 206, 38, -146
		boxAt("ForgeBackWall", CFrame.new(V(fx, fy + 6.5, fz - 11.5)), V(40, 13, 2.4), WALL_FACE, Mat.Slate)
		boxAt("ForgeWestWall", CFrame.new(V(fx - 19, fy + 5.5, fz - 1.5)), V(2.4, 11, 21), WALL_FACE, Mat.Slate)
		boxAt("ForgeEastWall", CFrame.new(V(fx + 19, fy + 5.5, fz - 1.5)), V(2.4, 11, 21), WALL_FACE, Mat.Slate)
		boxAt("ForgeWallCap", CFrame.new(V(fx, fy + 13.3, fz - 11.5)), V(41, 0.8, 3.0), STONE_LIGHT, Mat.Slate)
		buildCrateCluster(V(fx - 13, fy, fz + 3), 18)

		-- 3. Royal Lapis-Indigo Runeguard Banners on West & East Bastion Towers!
		for _, bSpec in {
			{ -259, 34 + 21, -96, 90 },
			{ -278, 34 + 21, -77, 0 },
			{ 281, 42 + 21, -96, -90 },
			{ 300, 42 + 21, -77, 0 },
		} do
			local bcf = CFrame.new(V(bSpec[1], bSpec[2], bSpec[3])) * CFrame.Angles(0, math.rad(bSpec[4]), 0)
			boxAt("TowerBannerCloth", bcf, V(5.2, 12.6, 0.45), LAPIS_BANNER, Mat.Fabric)
			boxAt("TowerBannerTrim", bcf * CFrame.new(0, 6.0, 0.15), V(5.8, 0.7, 0.55), GOLD_BRIGHT, Mat.Metal)
			boxAt("TowerBannerEmblem", bcf * CFrame.new(0, 0.8, 0.22), V(2.0, 2.8, 0.25), GOLD_BRIGHT, Mat.Metal)
		end

		-- 4. Inner Ward Reliquary wooden bookcase rows on ReliquaryNorthStacksBay (facing SOUTH!)
		for i = 0, 2 do
			buildStandingBookcase(V(-230 + i * 19, 50, -267), 0, 1.04)
		end

		-- 5. Rocky slate cliff outcrop cleanly BEHIND & FLANKING the Forbidden Vault Ring Door!
		buildRockOutcrop(V(-156, 52, -377), V(42, 36, 26), 16)
		buildRockOutcrop(V(-112, 54, -394), V(70, 42, 18), 0)
		buildRockOutcrop(V(-70, 52, -382), V(38, 32, 22), -18)
		local vGlow = ctx.cyl("VaultMouthGlow", V(-112, 68.5, -377.5), 7.2, 0.5, GOLD_LIGHT, Mat.Neon)
		vGlow.CFrame = CFrame.new(ctx.origin + V(-112, 68.5, -377.5)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0, math.pi / 2, 0)

		-- 6. Companion Court of Seals oath-stone pedestals flanking CourtSealPress (facing SOUTH!)
		for _, sx in { -20, 20 } do
			local px, py, pz = -4 + sx, 52, -358
			boxAt("OathPedestal", CFrame.new(V(px, py + 2.5, pz)), V(5.0, 5.0, 4.0), STONE_LIGHT, Mat.Slate)
			boxAt("OathTablet", CFrame.new(V(px, py + 7.4, pz)), V(3.8, 5.2, 1.4), WALL_FACE, Mat.Slate)
			boxAt("OathRuneInlay", CFrame.new(V(px, py + 7.4, pz + 0.72)), V(1.3, 3.2, 0.2), GOLD_BRIGHT, Mat.Metal)
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- F. LANDMARKS 16–21: GROUNDED RUNE-WARD PYLONS & WALL-TO-WALL GLYPH VEILS
	-- =========================================================================
	local function buildMoatPylonPier(px: number, topY: number, pz: number)
		local pierH = math.max(12, topY - ABYSS_Y)
		boxAt("WardPylonPier", CFrame.new(V(px, ABYSS_Y + pierH * 0.5, pz)), V(9.2, pierH, 9.2), WALL_FACE, Mat.Slate)
		boxAt("WardPylonPlinth", CFrame.new(V(px, topY - 1.2, pz)), V(10.8, 2.4, 10.8), STONE_LIGHT, Mat.Slate)
		boxAt("WardPylonCollar", CFrame.new(V(px, topY - 2.6, pz)), V(11.2, 0.55, 11.2), BRASS_AGED, Mat.Metal)
	end

	local extraGatePylons = {
		{ -142, 12, -4 },
		{ 290, 12, -4 },
		{ -142, 36, -176 },
		{ 118, 36, -176 },
		{ 190, 36, -176 },
	}
	ctx.group("AstralIsleDeck", function()
		for _, idx in { 16, 17, 18, 19, 20, 21 } do
			local lm = AstralFloor44.Landmarks[idx]
			buildMoatPylonPier(lm.X, lm.Y :: number, lm.Z)
		end
		for _, ep in extraGatePylons do
			buildMoatPylonPier(ep[1], ep[2], ep[3])
		end
		for _, beamSpec in {
			{ -358, -142, 12, -4 },
			{ -70, 362, 12, -4 },
			{ -350, 118, 36, -176 },
			{ 190, 370, 36, -176 },
		} do
			local len = beamSpec[2] - beamSpec[1]
			local cx = (beamSpec[1] + beamSpec[2]) * 0.5
			boxAt("WardSillBeam", CFrame.new(V(cx, beamSpec[3] - 1.6, beamSpec[4])), V(len, 3.2, 4.6), WALL_FACE, Mat.Slate)
			boxAt("WardSillTrim", CFrame.new(V(cx, beamSpec[3] - 0.1, beamSpec[4])), V(len, 0.55, 5.0), BRASS_AGED, Mat.Metal)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	for _, idx in { 16, 17, 18, 19, 20, 21 } do
		local lm = AstralFloor44.Landmarks[idx]
		local mp = piece(lm.Id, lm.X, lm.Z, 0, "RunewardPylon", 1.15, WARD_PYLON_TINT, function(cf)
			boxAt("WardPylon", cf * CFrame.new(0, 14, 0), V(7.5, 28, 7.5), WARD_PYLON_TINT.STONE.Color, Mat.Slate)
		end, lm.Y)
		pin(mp)
		if idx == 17 or idx == 20 then
			addLight(H.glowOf(mp), WARD_LIGHT, 1.5, 64)
		end
	end
	for i, ep in extraGatePylons do
		local mp = piece("WardGatePylon_" .. i, ep[1], ep[3], 0, "RunewardPylon", 1.15, WARD_PYLON_TINT, function(cf)
			boxAt("WardPylon", cf * CFrame.new(0, 14, 0), V(7.5, 28, 7.5), WARD_PYLON_TINT.STONE.Color, Mat.Slate)
		end, ep[2])
		pin(mp)
		makeDecor(mp)
	end

	-- Continuous luminous pale-gold translucent Beam light curtains behind BOTH wall-to-wall rune walls!
	ctx.group("AstralWardVeil", function()
		local curtainSpans = {
			{ V(-358, 22, -4), V(-142, 22, -4), 17.0 },
			{ V(-70, 22, -4), V(362, 22, -4), 17.0 },
			{ V(-350, 46, -176), V(118, 46, -176), 17.0 },
			{ V(190, 46, -176), V(370, 46, -176), 17.0 },
		}
		for cIdx, cs in curtainSpans do
			addLightCurtain("WardGoldCurtain_" .. cIdx, cs[1], cs[2], cs[3], cs[3], rgb(252, 222, 146), rgb(244, 208, 134), 0.48, false, false)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Zero-gap Wall-to-Wall Sculpted Rune-Ward Glyph Veils (flush to every flanking Gate pylon!)
	local veilSpans: { { number } } = {}
	-- Ward 1 West (-160 + 18 = -142 flush to pylon -142!)
	for x = -160, -340, -36 do
		table.insert(veilSpans, { x, 12, -4 })
	end
	-- Ward 1 East (-52 - 18 = -70 flush to pylon -70!)
	for x = -52, 344, 36 do
		table.insert(veilSpans, { x, 12, -4 })
	end
	-- Ward 2 West (100 + 18 = 118 flush to pylon +118!)
	for x = 100, -332, -36 do
		table.insert(veilSpans, { x, 36, -176 })
	end
	-- Ward 2 East (208 - 18 = 190 flush to pylon +190!)
	for x = 208, 352, 36 do
		table.insert(veilSpans, { x, 36, -176 })
	end
	for i, sp in veilSpans do
		local mv = piece("AstralWardVeil", sp[1], sp[3], 0, "RunewardVeil", 1.0, WARD_VEIL_TINT, function(cf)
			boxAt("WardVeilFallback", cf * CFrame.new(0, 9.5, 0), V(36, 19, 1.6), WARD_VEIL_TINT.GLOW.Color, Mat.Neon, 0.35)
		end, sp[2])
		pin(mv)
		noCollide(mv)
		if mv then
			mv:SetAttribute("ConjunctionGlyph", true)
			safeTag(mv, "ConjunctionGlyph")
			if i == 10 or i == 25 then
				addLight(H.glowOf(mv), WARD_LIGHT, 1.4, 68)
			end
		end
	end

	-- 22. Warded Court flush floor waiting circle medallion (in CampExemptKinds "ConcourseStarMap"!)
	do
		local lm = AstralFloor44.Landmarks[22]
		local mp = piece("ConcourseStarMap", lm.X, lm.Z, 0, "WardedCirclePad", 1.0, CIRCLE_TINT, function(cf)
			ctx.cyl("WardedCircle", cf.Position + V(0, 0.14, 0), 12, 0.24, BRASS_AGED, Mat.Metal)
		end, lm.Y)
		pin(mp)
		tagDetail(mp)
	end

	-- Shuttered Runeguard Lamps along outer corners of the wards
	for _, sp in {
		{ -234, 12, 70, 0 }, { 226, 16, 70, 0 },
		{ -246, 34, -66, 90 }, { 270, 42, -66, -90 },
		{ -132, 26, -120, 0 }, { 182, 38, -120, 0 },
		{ -238, 50, -230, 45 }, { -22, 52, -336, 0 },
	} do
		local ms = piece("AstralShutteredLamp", sp[1], sp[3], sp[4], "ShutteredLamp", 1.05, SHUTTER_TINT, function(cf)
			ctx.cyl("ShutteredPost", cf.Position + V(0, 6, 0), 0.7, 12, SHUTTER_TINT.METAL.Color, Mat.Metal)
		end, sp[2])
		pin(ms)
		tagDetail(ms)
	end

	-- =========================================================================
	-- G. TAPERED LUMINOUS VIOLET SKY RIFT TEAR BEHIND THE ATHENAEUM DOME
	-- =========================================================================
	ctx.group("AstralSkyNorthRift", function()
		addLightCurtain("SkyRiftOuter", V(-180, 186, -388), V(205, 272, -396), 4, 4, rgb(120, 46, 212), rgb(164, 72, 238), 0.62, true, true)
		addLightCurtain("SkyRiftMidA", V(-145, 194, -388), V(20, 232, -392), 2, 15, rgb(156, 78, 246), RIFT_VIOLET, 0.34, true, false)
		addLightCurtain("SkyRiftMidB", V(20, 232, -392), V(180, 266, -396), 15, 2, RIFT_VIOLET, rgb(156, 78, 246), 0.34, true, false)
		addLightCurtain("SkyRiftCoreA", V(-110, 202, -387), V(20, 232, -391), 0.8, 5.0, RIFT_VIOLET, RIFT_CORE, 0.14, true, false)
		addLightCurtain("SkyRiftCoreB", V(20, 232, -391), V(148, 258, -395), 5.0, 0.8, RIFT_CORE, RIFT_VIOLET, 0.14, true, false)
		addLightCurtain("SkyRiftForkA", V(-36, 220, -389), V(-84, 238, -391), 3.0, 0.6, RIFT_VIOLET, RIFT_CORE, 0.42, true, true)
		addLightCurtain("SkyRiftForkB", V(56, 240, -392), V(20, 264, -394), 2.8, 0.6, RIFT_VIOLET, RIFT_CORE, 0.42, true, true)
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	pageEmitter(V(-106, 24, -4), 3)
	pageEmitter(V(154, 54, -176), 3)
	pageEmitter(V(166, 68, -312), 4)

	ctx.setAttribute("AstralFloor", 44)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor44
