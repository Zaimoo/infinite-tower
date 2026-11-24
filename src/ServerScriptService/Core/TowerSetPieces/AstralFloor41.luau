--!strict
-- Hand-authored set pieces for Astral Archives Floor 41: Starlit Vestibule (astral:1, INTRODUCTION).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 41) & reference/Astral Archives 41.jpg.
--
-- Floating archipelago of circular marble-and-lapis star-isles suspended over a luminous cosmic Nebula Sea,
-- connected by starlight crystal bridges and crowned by the Grand Tome Sanctum (Lectern of First Light) on
-- the elevated Nib Star (back-east). Every architectural element is coherent and grounded (no mid-area gates
-- or void-facing dead-end arches).
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AstralFloor41 = {}

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

-- Halcyr first-light palette: vellum-white marble, deep lapis-indigo marble, warm gold leaf, aged brass,
-- rich walnut/ebony bookcases, vellum pages, pale starlight gold glow (hue ~46°, never orange/red),
-- star-glass cyan crystal and lush star-moss.
local HALCYR_41 = table.freeze({
	STONE = swatch(232, 226, 212, Mat.Marble),
	ALT = swatch(34, 44, 88, Mat.Marble),
	TRIM = swatch(218, 186, 108, Mat.Metal),
	METAL = swatch(188, 154, 86, Mat.Metal),
	WOOD = swatch(82, 54, 38, Mat.Wood),
	SILK = swatch(242, 236, 218, Mat.Fabric),
	GLOW = swatch(248, 228, 166, Mat.Neon),
	CRYSTAL = swatch(124, 204, 248, Mat.Glass, 0.16),
	MOSS = swatch(92, 146, 102, Mat.Grass),
})

-- Underside tint: hide the kit's flat grey STONE lid (we dress each island top with crisp marble rings)
-- while keeping the dark faceted slate underside (ALT), luminous cyan crystal tips (CRYSTAL), and hanging gold lanterns!
local UNDERSIDE_TINT = tinted(HALCYR_41, {
	STONE = swatch(232, 226, 212, Mat.Marble, 1),
	ALT = swatch(42, 48, 72, Mat.Slate),
	CRYSTAL = swatch(112, 214, 255, Mat.Neon, 0.18),
	GLOW = swatch(252, 228, 152, Mat.Neon),
})

-- RobedStatueStaff uses Roles = { TRIM (robe body), ACCENT (trim/shawl), GOLD (staff/ornaments), GLOW (orb) }.
-- Tinting TRIM as carved pale white marble turns the flanking sages into sculptural marble archivists!
local STATUE_TINT = tinted(HALCYR_41, {
	TRIM = swatch(224, 222, 214, Mat.Marble),
	ACCENT = swatch(172, 178, 194, Mat.Limestone),
	GOLD = swatch(224, 192, 114, Mat.Metal),
	GLOW = swatch(252, 232, 172, Mat.Neon),
})

local INK_TINT = tinted(HALCYR_41, {
	ALT = swatch(38, 66, 154, Mat.Neon),
	CRYSTAL = swatch(96, 176, 252, Mat.Glass, 0.16),
})

local GOLD_LIGHT = rgb(248, 228, 166)
local CYAN_LIGHT = rgb(144, 206, 252)
local SILVER_LIGHT = rgb(214, 228, 252)

local MARBLE_LIGHT = rgb(234, 228, 214)
local MARBLE_WARM = rgb(222, 214, 198)
local LAPIS_DEEP = rgb(30, 40, 84)
local LAPIS_MID = rgb(44, 62, 118)
local GOLD_BRIGHT = rgb(222, 190, 108)
local BRASS_AGED = rgb(186, 152, 82)
local GLOW_GOLD = rgb(248, 228, 166)
local CYAN_GLOW = rgb(120, 214, 255)

-- Floor 41's 19 landmark footprints (local floor space), spec-checked offline against every walkway
-- lane, camp (34-stud clearance), portal (12-stud clearance) and room bounds (600 x 620).
AstralFloor41.Landmarks = table.freeze({
	-- 1. Lectern of First Light / Grand Tome Sanctum (135.2 studs) crowning the northern apse of Nib Star
	{ Id = "LecternOfFirstLight", X = 175, Z = -284, Y = 36, HalfX = 12.0, HalfZ = 11.8, Top = 135.2 },
	-- 2. The Index Gate straddling the arrival threshold from Sanctuary down onto Readers' Concourse
	{ Id = "TheIndexGate", X = 0, Z = 248, Y = 8, HalfX = 21.5, HalfZ = 4.6, Top = 41.8, Straddles = true },
	-- 3. Catalogue Isle ebony card-catalogue cabinets + framed Nereth tide-chart ("received wet")
	{ Id = "CatalogueCabinets", X = 122, Z = -38, Y = 11, HalfX = 5.5, HalfZ = 3.8, Top = 10.2 },
	-- 4. The Inkwell swirling star-well on EastGallery's integrated eastern scrying bay (clear of camp)
	{ Id = "TheInkwellBasin", X = 236, Z = 24, Y = 12, HalfX = 11.2, HalfZ = 11.2, Top = 6.8 },
	-- 5. Copyist's Desk beside The Inkwell scrying bay
	{ Id = "InkwellCopyistDesk", X = 240, Z = 8, Y = 12, HalfX = 4.2, HalfZ = 3.2, Top = 6.5 },
	-- 6. The Blotter unified chained marble slab (4 monumental golden chains rising from Blotter's 4 corners)
	{ Id = "BlotterChainedSlab", X = 190, Z = -89, Y = 23, HalfX = 30.0, HalfZ = 26.0, Top = 148.0, Straddles = true },
	-- 7. Vane Root Archivist Watch Alcove (replaces the nonsensical mid-area gate with a coherent rim colonnade)
	{ Id = "VaneRootWatchpost", X = -238, Z = 25, Y = 8, HalfX = 8.0, HalfZ = 10.0, Top = 14.0 },
	-- 8. Lamplighters' Isle lamp-store rack seated cleanly inside Shaft's open south-east marble rim
	{ Id = "LamplighterRack", X = -73, Z = 0, Y = 16, HalfX = 5.5, HalfZ = 3.5, Top = 11.5 },
	-- 9. The Calamus central golden armillary sphere crowning Crossing's northern dais bay
	{ Id = "CalamusArmillary", X = 0, Z = -128, Y = 24, HalfX = 8.4, HalfZ = 8.4, Top = 35.0 },
	-- 10. First Barb curved reading library alcove (W rim bay of Barb1, cleanly inside marble & clear of landings)
	{ Id = "Barb1Bookcase", X = -243, Z = -100, Y = 20, HalfX = 5.5, HalfZ = 6.5, Top = 13.0 },
	-- 11. Second Barb curved reading library alcove (NW rim bay of Barb2, cleanly inside marble & clear of landings)
	{ Id = "Barb2Bookcase", X = -148, Z = -194, Y = 26, HalfX = 6.0, HalfZ = 6.0, Top = 13.0 },
	-- 12. Vane Tip curved reading library alcove (N rim bay of Barb3, cleanly inside marble & clear of landings)
	{ Id = "Barb3Bookcase", X = -32, Z = -264, Y = 32, HalfX = 6.5, HalfZ = 5.5, Top = 13.0 },
	-- 13. Colossal West Carved-Marble Hooded Sage holding a glowing golden armillary on a floating islet
	{ Id = "WestArchivistStatue", X = -268, Z = -18, Y = 14, HalfX = 12.0, HalfZ = 12.0, Top = 96.0 },
	-- 14. Colossal East Carved-Marble Hooded Sage holding a glowing golden armillary on a floating islet
	{ Id = "EastArchivistStatue", X = 270, Z = 65, Y = 14, HalfX = 12.0, HalfZ = 12.0, Top = 96.0 },
	-- 15. Far Archive Tower NW (distant floating domed library stack)
	{ Id = "FarArchiveTowerNW", X = -268, Z = -268, Y = 22, HalfX = 14.0, HalfZ = 14.0, Top = 88.0 },
	-- 16. Far Archive Tower NE (distant floating domed library stack)
	{ Id = "FarArchiveTowerNE", X = 268, Z = -268, Y = 30, HalfX = 14.0, HalfZ = 14.0, Top = 88.0 },
	-- 17. Far Archive Tower SW (distant floating domed library stack)
	{ Id = "FarArchiveTowerSW", X = -268, Z = 250, Y = 16, HalfX = 13.0, HalfZ = 13.0, Top = 80.0 },
	-- 18. Far Archive Tower N (distant floating library spire behind the reading arc)
	{ Id = "FarArchiveTowerN", X = -115, Z = -282, Y = 36, HalfX = 13.0, HalfZ = 13.0, Top = 84.0 },
	-- 19. Far Archive Tower E (distant floating library spire flanking the eastern void)
	{ Id = "FarArchiveTowerE", X = 274, Z = -152, Y = 24, HalfX = 13.0, HalfZ = 13.0, Top = 80.0 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

local function normalizeAngle(a: number): number
	while a <= -math.pi do a += math.pi * 2 end
	while a > math.pi do a -= math.pi * 2 end
	return a
end

local function angleDist(a: number, b: number): number
	return math.abs(normalizeAngle(a - b))
end

function AstralFloor41.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local P = H.P
	local _boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

	local lightsUsed = 0
	local emittersUsed = 0
	local function addLight(p: Instance?, color: Color3, brightness: number, range: number)
		if p and lightsUsed < 16 then
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
	local function pageEmitter(pos: Vector3, rate: number)
		if emittersUsed >= 10 then return end
		emittersUsed += 1
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, HALCYR_41.SILK.Color, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(248, 240, 218), rgb(244, 226, 170))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1.05), NumberSequenceKeypoint.new(1, 0.4) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3.5, 6.2)
		pe.Rate = rate
		pe.Speed = NumberRange.new(0.8, 2.2)
		pe.SpreadAngle = Vector2.new(45, 45)
		pe.RotSpeed = NumberRange.new(-40, 40)
		pe.Acceleration = V(0, 0.65, 0)
		pe.Parent = anchor
	end

	-- Helper: place a kit template with explicit per-axis Vector3 scale inside a named PropKind group
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

	-- Helper: build a sculptural celestial globe on a stepped marble pedestal
	local function buildGlobePedestal(pos: Vector3, scale: number)
		local s = scale
		boxAt("GlobePlinth", CFrame.new(pos + V(0, 1.5 * s, 0)), V(3.4 * s, 3.0 * s, 3.4 * s), MARBLE_LIGHT, Mat.Marble)
		boxAt("GlobePlinthLapis", CFrame.new(pos + V(0, 1.5 * s, 0)), V(2.4 * s, 2.2 * s, 3.55 * s), LAPIS_DEEP, Mat.Marble)
		boxAt("GlobePlinthLapisX", CFrame.new(pos + V(0, 1.5 * s, 0)), V(3.55 * s, 2.2 * s, 2.4 * s), LAPIS_DEEP, Mat.Marble)
		boxAt("GlobeCap", CFrame.new(pos + V(0, 3.15 * s, 0)), V(3.8 * s, 0.45 * s, 3.8 * s), GOLD_BRIGHT, Mat.Metal)
		ctx.cyl("GlobeStem", pos + V(0, 4.1 * s, 0), 0.55 * s, 1.5 * s, BRASS_AGED, Mat.Metal)
		local orb = lump("CelestialGlobe", pos + V(0, 5.7 * s, 0), V(2.5 * s, 2.5 * s, 2.5 * s), CYAN_GLOW, Mat.Glass)
		orb.Transparency = 0.22
		lump("CelestialGlobeCore", pos + V(0, 5.7 * s, 0), V(1.35 * s, 1.35 * s, 1.35 * s), GLOW_GOLD, Mat.Neon)
		ctx.ring("CelestialGlobeRing", pos + V(0, 5.7 * s, 0), 1.65 * s, 0.16 * s, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.rad(28), 0, math.rad(16)), 0, math.pi * 2, 12)
	end

	-- Helper: build a warm glowing golden pedestal brazier (flanking stairs & Sanctum rim)
	local function buildBrazier(pos: Vector3, scale: number, withLight: boolean)
		local s = scale
		ctx.cyl("BrazierBase", pos + V(0, 0.5 * s, 0), 1.7 * s, 1.0 * s, MARBLE_LIGHT, Mat.Marble)
		ctx.cyl("BrazierStem", pos + V(0, 2.4 * s, 0), 0.7 * s, 3.0 * s, BRASS_AGED, Mat.Metal)
		ctx.cyl("BrazierBowl", pos + V(0, 4.1 * s, 0), 1.6 * s, 0.9 * s, GOLD_BRIGHT, Mat.Metal)
		local flame = lump("BrazierFlame", pos + V(0, 5.1 * s, 0), V(1.7 * s, 2.1 * s, 1.7 * s), GLOW_GOLD, Mat.Neon)
		flame:SetAttribute("ConjunctionGlyph", true)
		safeTag(flame, "ConjunctionGlyph")
		if withLight then
			addLight(flame, GOLD_LIGHT, 1.35, 44)
		end
	end

	-- Helper: build a classical white-marble reading bench
	local function buildMarbleBench(pos: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		boxAt("BenchSeat", cf * CFrame.new(0, 2.2, 0), V(11.5, 0.85, 3.2), MARBLE_LIGHT, Mat.Marble)
		boxAt("BenchTrim", cf * CFrame.new(0, 1.7, 0), V(11.8, 0.25, 3.4), GOLD_BRIGHT, Mat.Metal)
		for _, sx in { -4.4, 4.4 } do
			boxAt("BenchLeg", cf * CFrame.new(sx, 1.0, 0), V(1.4, 2.0, 2.8), MARBLE_WARM, Mat.Marble)
		end
	end

	-- Helper: build a floating stack of giant leather-bound tomes in the cosmic void
	local function buildFloatingBookStack(pos: Vector3, count: number, baseScale: number, seed: number)
		for k = 0, count - 1 do
			local ang = math.rad(((seed * 37 + k * 23) % 44) - 22)
			local w = (10.5 - (k % 3) * 1.2) * baseScale
			local d = (7.8 - ((k + 1) % 3) * 0.8) * baseScale
			local h = 2.1 * baseScale
			local yOff = k * (h + 0.15 * baseScale)
			local cf = CFrame.new(pos + V(math.sin(k * 1.4 + seed) * 0.6 * baseScale, yOff, math.cos(k * 1.1 + seed) * 0.5 * baseScale)) * CFrame.Angles(0, ang, 0)
			local coverCol = if k % 3 == 0 then LAPIS_MID elseif k % 3 == 1 then rgb(104, 64, 44) else rgb(72, 46, 86)
			boxAt("VoidBookCover", cf, V(w, h, d), coverCol, Mat.Wood)
			boxAt("VoidBookPages", cf * CFrame.new(0.25 * baseScale, 0, 0), V(w * 0.92, h * 0.72, d * 0.92), HALCYR_41.SILK.Color, Mat.Fabric)
			boxAt("VoidBookSpineGold", cf * CFrame.new(-w * 0.49, 0, 0), V(0.35 * baseScale, h * 0.96, d * 0.96), GOLD_BRIGHT, Mat.Metal)
		end
	end

	-- Helper: build a seamless grounded circular marble alcove bay (with lapis collar & crystal underside)
	local function buildMarbleBay(x: number, y: number, z: number, radius: number, undersideDepth: number)
		ctx.group("AstralIsleDeck", function()
			ctx.cyl("BayMarbleCap", V(x, y - 0.52, z), radius, 1.2, MARBLE_LIGHT, Mat.Marble)
			ctx.cyl("BayLapisBand", V(x, y - 2.2, z), radius - 0.35, 2.3, LAPIS_DEEP, Mat.Marble)
			ctx.ring("BayGoldUpper", V(x, y - 0.55, z), radius + 0.25, 0.75, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)
			ctx.ring("BayGoldLower", V(x, y - 3.35, z), radius - 0.4, 0.65, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
		local availH = math.max(8, math.min(undersideDepth, (y - 3.2) - (-5.4)))
		local sx = (radius * 2.02) / 32.5
		local sy = availH / 28.07
		local mu = placeKitScaled("AstralIsleUnderside", x, (y - 3.2) - availH, z, (x + z) * 2.3, "StarIsleUndersideS", V(sx, sy, sx), UNDERSIDE_TINT, function(cf)
			ctx.cyl("BayCrystalCone", cf.Position + V(0, availH * 0.5, 0), radius * 0.7, availH, CYAN_GLOW, Mat.Glass)
		end)
		makeDecor(mu)
	end

	-- Reserve every landmark footprint so generic scatter respects them
	for _, lm in AstralFloor41.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- Helper: create a true additive volumetric golden light beam (LightEmission = 1, never dark against black sky!)
	local function addVolumetricBeam(name: string, p0: Vector3, p1: Vector3, width0: number, width1: number, color: Color3, peakAlpha: number)
		local anchor = ctx.block(name .. "_Anchor", V(1, 1, 1), (p0 + p1) * 0.5, color, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
		anchor:SetAttribute("SolidScenery", false)
		local a0 = Instance.new("Attachment")
		a0.Position = p0 - (p0 + p1) * 0.5
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Position = p1 - (p0 + p1) * 0.5
		a1.Parent = anchor
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = width0
		b.Width1 = width1
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(color, rgb(255, 246, 212))
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, math.min(0.92, peakAlpha + 0.24)),
			NumberSequenceKeypoint.new(0.18, peakAlpha),
			NumberSequenceKeypoint.new(0.60, math.min(0.95, peakAlpha + 0.16)),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		b.Parent = anchor
	end

	-- =========================================================================
	-- A. DEEP-SPACE COSMIC NEBULA SEA (sits cleanly ABOVE the Basalt floor at Y=-6)
	-- Deep velvety midnight-indigo cosmic void + subtle circular twilight nebula discs & crisp stars!
	-- =========================================================================
	ctx.group("AstralNebulaSea", function()
		-- Opaque deep midnight-indigo cosmic void floor hiding raw basalt completely
		boxAt("NebulaSeaSheet", CFrame.new(V(0, -5.35, -20)), V(660, 0.30, 680), rgb(7, 10, 28), Mat.SmoothPlastic, 0)
		-- Soft circular twilight-indigo & muted amethyst nebula pools (no harsh flat bright-blue squares!)
		local nebulaDiscs = {
			{ -155, -5.12, -95, 130, rgb(28, 48, 118), 0.76 },
			{ 135, -5.10, -135, 145, rgb(48, 34, 112), 0.76 },
			{ 5, -5.08, 20, 140, rgb(24, 58, 122), 0.78 },
			{ -175, -5.06, 75, 115, rgb(54, 34, 108), 0.78 },
			{ 180, -5.04, 45, 120, rgb(26, 62, 128), 0.76 },
			{ 170, -5.02, -220, 130, rgb(64, 52, 126), 0.75 },
		}
		for idx, nd in nebulaDiscs do
			local disc = ctx.cyl("NebulaCloud_" .. idx, V(nd[1], nd[2], nd[3]), nd[4], 0.16, nd[5], Mat.Neon)
			disc.Transparency = nd[6]
		end
		-- Sparkling pinpoint starfield glints scattered across the Nebula Sea
		for i = 1, 118 do
			local sx = math.sin(i * 12.9898) * 288
			local sz = math.cos(i * 78.233) * 294 - 15
			local szStar = if i % 6 == 0 then 2.1 else 1.1
			local starCol = if i % 4 == 0 then GLOW_GOLD elseif i % 3 == 0 then CYAN_GLOW else SILVER_LIGHT
			local st = lump("NebulaSeaStar", V(sx, -4.82, sz), V(szStar, 0.24, szStar), starCol, Mat.Neon)
			if i % 7 == 0 then
				st:SetAttribute("ConjunctionGlyph", true)
				safeTag(st, "ConjunctionGlyph")
			end
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. CIRCULAR MARBLE ISLAND DRESSING, UNDERSIDES & PERIMETER BALUSTRADES
	-- Every floating island gets a razor-sharp circular white-marble terrace cap,
	-- lapis-and-gold inlaid floor rings, deep lapis frieze collar, full-width
	-- faceted rock & glowing cyan crystal underside with hanging gold lanterns,
	-- and classical curved marble balustrades automatically gapped at every bridge!
	-- =========================================================================
	local bridgeAnglesByPlat: { [string]: { number } } = {}
	for _, link in ctx.layout.Links do
		local pFrom = P[link.From]
		local pTo = P[link.To]
		if pFrom and pTo then
			bridgeAnglesByPlat[link.From] = bridgeAnglesByPlat[link.From] or {}
			table.insert(bridgeAnglesByPlat[link.From], math.atan2(link.AZ - pFrom.Z, link.AX - pFrom.X))
			bridgeAnglesByPlat[link.To] = bridgeAnglesByPlat[link.To] or {}
			table.insert(bridgeAnglesByPlat[link.To], math.atan2(link.BZ - pTo.Z, link.BX - pTo.X))
		end
	end

	-- Extra angular openings where an integrated architectural bay attaches seamlessly to an island
	local bayOpenings: { [string]: { { number } } } = {
		Crossing = { { -math.pi / 2, 0.45 } },          -- North bay for CalamusArmillary
		EastGallery = { { 0.0, 0.54 } },                -- East bay for TheInkwellBasin
		WestGallery = { { math.pi, 0.45 } },            -- West bay for VaneRootWatchpost
		Apex = { { -math.pi / 2, 0.48 } },              -- North apse for LecternOfFirstLight
		Barb1 = { { math.pi, 0.85 } },                  -- West reading library alcove bay
		Barb2 = { { math.rad(-126), 0.85 } },           -- NW reading library alcove bay
		Barb3 = { { math.rad(-94), 0.85 } },            -- N reading library alcove bay
	}

	-- Island specs: { PlatformId, Radius (matched to clean rim-to-rim RoundDecks), UndersideKit, KitWidth, KitHeight, DesiredDepth, FloorStyle }
	local circularIsles = {
		{ "WestGallery", 44.2, "StarIsleUndersideM", 48.3, 34.07, 13.5, "RING" },
		{ "EastGallery", 44.2, "StarIsleUndersideM", 48.3, 34.07, 17.5, "RING" },
		{ "Catalogue", 34.2, "StarIsleUndersideS", 32.5, 28.07, 13.5, "RING" },
		{ "Shaft", 34.2, "StarIsleUndersideS", 32.5, 28.07, 20.5, "RING" },
		{ "Barb1", 32.2, "StarIsleUndersideS", 32.5, 28.07, 24.5, "LIBRARY" },
		{ "Crossing", 40.2, "StarIsleUndersideM", 48.3, 34.07, 28.5, "CALAMUS" },
		{ "Barb2", 32.2, "StarIsleUndersideS", 32.5, 28.07, 30.5, "LIBRARY" },
		{ "NibLanding", 34.2, "StarIsleUndersideS", 32.5, 28.07, 32.0, "GOLD_RING" },
		{ "Barb3", 32.2, "StarIsleUndersideS", 32.5, 28.07, 35.0, "LIBRARY" },
		{ "Apex", 58.2, "StarIsleUndersideL", 68.1, 42.07, 39.5, "SANCTUM" },
	}

	for _, row in circularIsles do
		local id: string = row[1]
		local plat = P[id]
		if not plat then continue end
		local radius: number = row[2]
		local kitName: string = row[3]
		local kitW: number = row[4]
		local kitH: number = row[5]
		local wantDepth: number = row[6]
		local style: string = row[7]
		local px, py, pz = plat.X, plat.Y, plat.Z

		-- 1. Crisp circular marble terrace cap + lapis frieze band + gold rings + decorative floor inlays
		ctx.group("AstralIsleDeck", function()
			local capTopOff = 0.06
			ctx.cyl(id .. "MarbleCap", V(px, py + capTopOff - 0.60, pz), radius, 1.2, MARBLE_LIGHT, Mat.Marble)
			-- Lapis-indigo carved frieze drum underneath the marble lip
			ctx.cyl(id .. "LapisFrieze", V(px, py - 2.35, pz), radius - 0.35, 2.5, LAPIS_DEEP, Mat.Marble)
			-- Gleaming upper & lower gold trim collars
			ctx.ring(id .. "GoldRimTop", V(px, py + capTopOff - 0.50, pz), radius + 0.3, 0.85, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
			ctx.ring(id .. "GoldRimBot", V(px, py - 3.55, pz), radius - 0.45, 0.72, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)

			-- Distinctive floor medallion inlays matching Image 2 (flush above marble cap, non-colliding)
			if style == "CALAMUS" then
				-- Iconic concentric navy-and-gold astronomical dial on the central hub!
				ctx.cyl("CalamusDialOuter", V(px, py + 0.08, pz), radius * 0.78, 0.14, LAPIS_DEEP, Mat.Marble)
				ctx.cyl("CalamusDialInner", V(px, py + 0.11, pz), radius * 0.56, 0.14, MARBLE_WARM, Mat.Marble)
				ctx.cyl("CalamusDialCore", V(px, py + 0.13, pz), radius * 0.30, 0.14, LAPIS_MID, Mat.Marble)
				ctx.ring("CalamusGoldRing1", V(px, py + 0.17, pz), radius * 0.78, 0.45, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
				ctx.ring("CalamusGoldRing2", V(px, py + 0.18, pz), radius * 0.56, 0.40, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
				ctx.ring("CalamusGoldRing3", V(px, py + 0.19, pz), radius * 0.30, 0.32, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)
				for i = 0, 7 do
					local a = i * math.pi / 4
					local ray = boxAt("CalamusRadial", CFrame.new(V(px + math.cos(a) * radius * 0.54, py + 0.16, pz + math.sin(a) * radius * 0.54)) * CFrame.Angles(0, -a, 0), V(radius * 0.48, 0.10, 0.42), GOLD_BRIGHT, Mat.Metal)
					ray:SetAttribute("ConjunctionGlyph", true)
					safeTag(ray, "ConjunctionGlyph")
				end
			elseif style == "SANCTUM" then
				-- Grand golden sun-ring floor mosaic on the elevated Nib Star boss arena
				ctx.ring("SanctumGoldRingOuter", V(px, py + capTopOff + 0.08, pz), radius * 0.80, 0.65, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
				ctx.ring("SanctumGoldRingMid", V(px, py + capTopOff + 0.09, pz), radius * 0.55, 0.42, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
				ctx.ring("SanctumGoldRingInner", V(px, py + capTopOff + 0.09, pz), radius * 0.28, 0.36, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)
			elseif style == "LIBRARY" then
				-- Soft pale star-glass & gold circular reading rug inlay in the middle of each library island
				ctx.cyl(id .. "ReadingInlay", V(px, py + 0.07, pz), radius * 0.58, 0.12, rgb(210, 224, 232), Mat.Marble)
				ctx.ring(id .. "ReadingRing", V(px, py + 0.15, pz), radius * 0.58, 0.36, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
			elseif style == "GOLD_RING" then
				ctx.ring(id .. "LandingGoldRing", V(px, py + 0.15, pz), radius * 0.66, 0.50, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
				ctx.ring(id .. "LandingGlowRing", V(px, py + 0.16, pz), radius * 0.38, 0.30, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)
			else
				ctx.ring(id .. "FloorGoldRing", V(px, py + 0.14, pz), radius * 0.72, 0.38, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		-- 2. Full-width sculpted faceted rock & glowing cyan crystal underside + hanging gold lanterns
		local maxAvail = math.max(9.0, (py - 3.4) - (-5.4))
		local useDepth = math.min(wantDepth, maxAvail)
		local scaleXZ = (radius * 2.02) / kitW
		local scaleY = useDepth / kitH
		local mu = placeKitScaled("AstralIsleUnderside", px, (py - 3.4) - useDepth, pz, (px * 0.7 + pz * 0.3) % 360, kitName, V(scaleXZ, scaleY, scaleXZ), UNDERSIDE_TINT, function(cf)
			ctx.cyl(id .. "UndersideCone", cf.Position + V(0, useDepth * 0.5, 0), radius * 0.78, useDepth, rgb(42, 48, 72), Mat.Slate)
		end)
		makeDecor(mu)

		-- 3. Classical white-marble perimeter balustrades with gold handrails (automatically gapped at bridges & bays!)
		local openings: { { number } } = {}
		for _, ba in bridgeAnglesByPlat[id] or {} do
			-- Match the 28-stud bridgehead pier tightly so circular balustrades meet the pier curbs cleanly
			local halfSpan = math.asin(math.clamp(16.2 / radius, 0.22, 0.72))
			table.insert(openings, { ba, halfSpan })
		end
		for _, bo in bayOpenings[id] or {} do
			table.insert(openings, bo)
		end
		local function isOpenAngle(ang: number): boolean
			for _, op in openings do
				if angleDist(ang, op[1]) < op[2] then
					return true
				end
			end
			return false
		end

		ctx.group("AstralIsleBalustrade", function()
			local segs = if radius >= 55 then 36 else 28
			local step = (math.pi * 2) / segs
			local rimR = radius - 0.9
			for k = 0, segs - 1 do
				local a0 = -math.pi + k * step
				local aMid = a0 + step * 0.5
				if isOpenAngle(aMid) then continue end
				local p0 = V(px + math.cos(a0) * rimR, py, pz + math.sin(a0) * rimR)
				local a1 = a0 + step
				local p1 = V(px + math.cos(a1) * rimR, py, pz + math.sin(a1) * rimR)
				local segLen = (p1 - p0).Magnitude + 0.35
				local mid = (p0 + p1) * 0.5
				local cf = CFrame.lookAt(mid, p1)
				-- Base plinth, middle baluster rail & gold top handrail
				boxAt("IsleBalPlinth", cf * CFrame.new(0, 0.5, 0), V(1.15, 0.95, segLen), MARBLE_LIGHT, Mat.Marble)
				boxAt("IsleBalRail", cf * CFrame.new(0, 2.85, 0), V(0.85, 0.45, segLen), GOLD_BRIGHT, Mat.Metal)
				boxAt("IsleBalPost", cf * CFrame.new(0, 1.75, 0), V(0.65, 1.9, 0.65), MARBLE_WARM, Mat.Marble)
				-- Corner newel pillar with gold orb if adjacent segment is a bridge opening
				local prevOpen = isOpenAngle(aMid - step)
				local nextOpen = isOpenAngle(aMid + step)
				if prevOpen then
					boxAt("IsleNewel", CFrame.new(p0 + V(0, 1.8, 0)), V(1.5, 3.5, 1.5), MARBLE_LIGHT, Mat.Marble)
					lump("IsleNewelOrb", p0 + V(0, 4.05, 0), V(1.4, 1.4, 1.4), GOLD_BRIGHT, Mat.Metal)
				end
				if nextOpen then
					boxAt("IsleNewel", CFrame.new(p1 + V(0, 1.8, 0)), V(1.5, 3.5, 1.5), MARBLE_LIGHT, Mat.Marble)
					lump("IsleNewelOrb", p1 + V(0, 4.05, 0), V(1.4, 1.4, 1.4), GOLD_BRIGHT, Mat.Metal)
				end
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- C. GRAND READERS' CONCOURSE PROMENADE (Basin: X=0, Y=0, Z=165, W=568, D=96)
	-- Transforms the flat sandy terrain beach into Image 2's classical white-marble
	-- observation terrace with deep lapis starry constellation mosaic, perimeter
	-- balustrades, reading benches & celestial globes — ZERO nonsensical mid-area gates!
	-- =========================================================================
	local basin = P.Basin
	if basin then
		ctx.group("AstralConcourseDeck", function()
			local bx, by, bz = basin.X, basin.Y, basin.Z
			local bw, bd = basin.Width, basin.Depth
			local halfW, halfD = bw * 0.5, bd * 0.5

			-- Crisp vellum-white marble promenade surface cap (matches Basin's exact north edge Z=117.0!)
			boxAt("ConcourseMarbleFloor", CFrame.new(V(bx, by - 0.48, bz)), V(bw + 4, 1.12, bd), MARBLE_LIGHT, Mat.Marble)
			-- Classical stepped marble & lapis terrace retaining wall/skirt along front & sides into the Nebula Sea
			boxAt("ConcourseLapisSkirt", CFrame.new(V(bx, by - 3.4, bz)), V(bw + 2, 4.8, bd - 0.4), LAPIS_DEEP, Mat.Marble)
			boxAt("ConcourseGoldCorniceN", CFrame.new(V(bx, by - 0.65, bz - halfD - 0.1)), V(bw + 5, 0.85, 0.9), GOLD_BRIGHT, Mat.Metal)
			boxAt("ConcourseGoldCorniceS", CFrame.new(V(bx, by - 0.65, bz + halfD + 0.1)), V(bw + 5, 0.85, 0.9), GOLD_BRIGHT, Mat.Metal)
			for _, sx in { -1, 1 } do
				boxAt("ConcourseGoldCorniceSide", CFrame.new(V(bx + sx * (halfW + 2.1), by - 0.65, bz)), V(0.9, 0.85, bd + 1), GOLD_BRIGHT, Mat.Metal)
			end

			-- Grand central deep-lapis starry constellation mosaic plaza (matching Image 2's foreground!)
			boxAt("ConcourseLapisMosaicCenter", CFrame.new(V(bx, by + 0.06, bz + 2)), V(164, 0.14, 58), LAPIS_DEEP, Mat.Marble)
			boxAt("ConcourseLapisMosaicWest", CFrame.new(V(bx - 165, by + 0.06, bz)), V(130, 0.14, 52), LAPIS_DEEP, Mat.Marble)
			boxAt("ConcourseLapisMosaicEast", CFrame.new(V(bx + 165, by + 0.06, bz)), V(130, 0.14, 52), LAPIS_DEEP, Mat.Marble)
			-- Gold borders framing the three starry mosaic panels
			for _, panel in { { bx, bz + 2, 164, 58 }, { bx - 165, bz, 130, 52 }, { bx + 165, bz, 130, 52 } } do
				local cx, cz, pw, pd = panel[1], panel[2], panel[3], panel[4]
				for _, sz in { -1, 1 } do
					boxAt("MosaicGoldEdgeZ", CFrame.new(V(cx, by + 0.13, cz + sz * pd * 0.5)), V(pw + 1.2, 0.12, 0.75), GOLD_BRIGHT, Mat.Metal)
				end
				for _, sx in { -1, 1 } do
					boxAt("MosaicGoldEdgeX", CFrame.new(V(cx + sx * pw * 0.5, by + 0.13, cz)), V(0.75, 0.12, pd + 1.2), GOLD_BRIGHT, Mat.Metal)
				end
			end

			-- Clean, non-overlapping golden constellation arcs in the west & east panels + framing the central astrolabe!
			local starChains = {
				{ V(-70, 0.15, 178), V(-52, 0.15, 152), V(-34, 0.15, 168) },
				{ V(34, 0.15, 168), V(52, 0.15, 152), V(70, 0.15, 178) },
				{ V(-215, 0.15, 176), V(-188, 0.15, 150), V(-152, 0.15, 174), V(-118, 0.15, 154) },
				{ V(118, 0.15, 154), V(152, 0.15, 174), V(188, 0.15, 150), V(215, 0.15, 176) },
			}
			for _, chain in starChains do
				for i, pt in chain do
					local node = boxAt("ConcourseStarNode", CFrame.new(pt) * CFrame.Angles(0, math.pi / 4, 0), V(1.6, 0.10, 1.6), GLOW_GOLD, Mat.Neon)
					node:SetAttribute("ConjunctionGlyph", true)
					safeTag(node, "ConjunctionGlyph")
					if i > 1 then
						local prev = chain[i - 1]
						local segMid = (prev + pt) * 0.5
						local seg = boxAt("ConcourseStarLine", CFrame.lookAt(segMid, pt), V(0.32, 0.08, (pt - prev).Magnitude), GLOW_GOLD, Mat.Neon, 0.15)
						seg:SetAttribute("ConjunctionGlyph", true)
						safeTag(seg, "ConjunctionGlyph")
					end
				end
			end

			-- White marble stair tread dressing along Sanctuary -> Basin ramp (flush, non-colliding)
			local steps = 10
			for s = 1, steps do
				local t = (s - 0.5) / steps
				local sy = 8.0 * (1 - t)
				local sz = 247.0 + (209.0 - 247.0) * t
				boxAt("ArrivalMarbleStep", CFrame.new(V(0, sy - 0.15, sz)), V(26.5, 0.5, 3.9), if s % 2 == 0 then MARBLE_LIGHT else MARBLE_WARM, Mat.Marble)
				boxAt("ArrivalStepGold", CFrame.new(V(0, sy + 0.12, sz - 1.85)), V(26.2, 0.14, 0.35), GOLD_BRIGHT, Mat.Metal)
			end

			-- Classical marble balustrades framing the Concourse promenade edges (exact openings for EVERY bridge & return ramp!)
			local function balustradeSpan(x0: number, z0: number, x1: number, z1: number)
				local a, b = V(x0, by, z0), V(x1, by, z1)
				local len = (b - a).Magnitude
				if len < 4 then return end
				local mid = (a + b) * 0.5
				local cf = CFrame.lookAt(mid, b)
				boxAt("ConcourseBalPlinth", cf * CFrame.new(0, 0.55, 0), V(1.3, 1.1, len), MARBLE_LIGHT, Mat.Marble)
				boxAt("ConcourseBalRail", cf * CFrame.new(0, 3.1, 0), V(0.95, 0.45, len), GOLD_BRIGHT, Mat.Metal)
				local posts = math.max(2, math.floor(len / 8))
				for i = 0, posts do
					local pt = a:Lerp(b, i / posts)
					local isEnd = (i == 0 or i == posts)
					boxAt("ConcourseBalPost", CFrame.new(pt + V(0, if isEnd then 1.9 else 1.8, 0)), V(if isEnd then 1.8 else 0.75, if isEnd then 3.8 else 2.1, if isEnd then 1.8 else 0.75), MARBLE_LIGHT, Mat.Marble)
					if isEnd then
						lump("ConcourseBalOrb", pt + V(0, 4.3, 0), V(1.5, 1.5, 1.5), GOLD_BRIGHT, Mat.Metal)
					end
				end
			end

			-- Compute exact X-openings along Basin's north edge from the 3 straight outgoing bridges only!
			-- (Unconnected void ReturnLinks are hidden, so Basin's north balustrade runs cleanly across X=±222.)
			local northZ = bz - halfD + 0.8
			local gaps: { { number } } = {}
			for _, link in ctx.layout.Links do
				if link.From == "Basin" or link.To == "Basin" then
					local ax, az = if link.From == "Basin" then link.AX else link.BX, if link.From == "Basin" then link.AZ else link.BZ
					local bx2, bz2 = if link.From == "Basin" then link.BX else link.AX, if link.From == "Basin" then link.BZ else link.AZ
					if bz2 < bz then
						local xCross = ax
						local halfOpen = link.Width * 0.5 + 0.6
						table.insert(gaps, { xCross - halfOpen, xCross + halfOpen })
					end
				end
			end
			table.sort(gaps, function(g1, g2) return g1[1] < g2[1] end)
			local merged: { { number } } = {}
			for _, g in gaps do
				local last = merged[#merged]
				if last and g[1] <= last[2] + 4 then
					last[2] = math.max(last[2], g[2])
				else
					table.insert(merged, { g[1], g[2] })
				end
			end
			local curX = -halfW + 10
			local northSpans: { { number } } = {}
			for _, g in merged do
				if g[1] - curX >= 6 then
					table.insert(northSpans, { curX, g[1] })
				end
				curX = math.max(curX, g[2])
			end
			if (halfW - 10) - curX >= 6 then
				table.insert(northSpans, { curX, halfW - 10 })
			end
			for _, sp in northSpans do
				balustradeSpan(sp[1], northZ, sp[2], northZ)
				-- Place marble benches cleanly in solid balustrade spans >= 28 studs wide (never blocking bridges or return ramps!)
				local spanW = sp[2] - sp[1]
				if spanW >= 28 then
					local count = math.min(2, math.floor(spanW / 38) + 1)
					for k = 1, count do
						local bxBench = sp[1] + spanW * (k / (count + 1))
						buildMarbleBench(V(bxBench, by, northZ + 5.5), 0)
					end
				end
			end

			-- South promenade balustrade (gapped generously around Sanctuary arrival stair X=[-24..+24])
			local southZ = bz + halfD - 1.2
			balustradeSpan(-halfW + 10, southZ, -26, southZ)
			balustradeSpan(26, southZ, halfW - 10, southZ)
			-- East & West promenade end balustrades
			balustradeSpan(-halfW + 1.5, northZ + 8, -halfW + 1.5, southZ - 8)
			balustradeSpan(halfW - 1.5, northZ + 8, halfW - 1.5, southZ - 8)

			-- Celestial globes on pedestals framing the arrival stair & promenade corners
			for _, gp in {
				V(-28, by, southZ - 1.5), V(28, by, southZ - 1.5),
				V(-278, by, northZ + 3), V(278, by, northZ + 3),
				V(-278, by, southZ - 3), V(278, by, southZ - 3),
			} do
				buildGlobePedestal(gp, 1.0)
			end
			-- South reading benches tucked neatly against the south balustrade
			for _, bxBench in { -180, -68, 68, 180 } do
				buildMarbleBench(V(bxBench, by, southZ - 5.5), 180)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- Central golden compass-star astrolabe medallion inside the central lapis plaza (clean, no overlapping zig-zag!)
	ctx.group("ConcourseStarMap", function()
		ctx.ring("ConcourseAstrolabeOuter", V(0, 0.16, 167), 20.0, 0.45, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
		ctx.ring("ConcourseAstrolabeInner", V(0, 0.17, 167), 10.5, 0.32, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)
		for i = 0, 7 do
			local a = i * math.pi / 4
			local len = if i % 2 == 0 then 19.5 else 13.0
			local bar = boxAt("ConcourseGlyphRay", CFrame.new(V(math.cos(a) * (len * 0.5 + 2.0), 0.16, 167 + math.sin(a) * (len * 0.5 + 2.0))) * CFrame.Angles(0, -a, 0), V(len, 0.10, 0.34), GLOW_GOLD, Mat.Neon)
			bar:SetAttribute("ConjunctionGlyph", true)
			safeTag(bar, "ConjunctionGlyph")
		end
		lump("ConcourseAstrolabeCore", V(0, 0.18, 167), V(3.2, 0.24, 3.2), GLOW_GOLD, Mat.Neon)
		makeDecor(ctx.current())
	end)

	-- =========================================================================
	-- D. LANDMARKS (1..19) — ALL SOLIDLY GROUNDED, COHERENT & TRUE TO IMAGE 2
	-- =========================================================================

	-- 1. The Lectern of First Light / Grand Tome Sanctum (135.2 studs) on Apex's integrated northern marble apse
	do
		local lm = AstralFloor41.Landmarks[1]
		local ly = lm.Y :: number
		-- Integrated northern circular marble shrine apse bridging smoothly to Apex's rim
		buildMarbleBay(lm.X, ly, lm.Z + 6, 26.0, 38.0)

		local m = piece("LecternOfFirstLight", lm.X, lm.Z, 0, "LecternSpire", 1.0, HALCYR_41, function(cf)
			boxAt("LecternShaft", cf * CFrame.new(0, 62, 0), V(14, 124, 14), MARBLE_LIGHT, Mat.Marble)
			local crown = lump("LecternCrownBook", (cf * CFrame.new(0, 128, 0)).Position, V(18, 10, 12), GLOW_GOLD, Mat.Neon)
			addLight(crown, GOLD_LIGHT, 2.2, 90)
		end, ly)
		pin(m)
		if m and ctx.has("LecternSpire") then
			addLight(H.glowOf(m), GOLD_LIGHT, 2.2, 95)
		end

		-- Eye-level Grand Golden Shrine Archway + Radiant Giant Open Golden Tome + Warm Diagonal God-Rays (Image 2!)
		ctx.group("AstralSanctumRays", function()
			local sx, sy, sz = lm.X, ly, lm.Z + 2
			-- Stepped circular golden-trimmed shrine dais under the Lectern spire
			ctx.cyl("SanctumDais1", V(sx, sy + 0.6, sz), 16.5, 1.2, MARBLE_LIGHT, Mat.Marble)
			ctx.cyl("SanctumDais2", V(sx, sy + 1.6, sz), 13.5, 1.0, LAPIS_DEEP, Mat.Marble)
			ctx.ring("SanctumDaisGold", V(sx, sy + 2.15, sz), 13.8, 0.45, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)

			-- Ornate golden arched crown framing the eye-level Sanctum Shrine (Y + 14..38)
			ctx.ring("SanctumHaloArch", V(sx, sy + 28, sz), 14.5, 0.85, GOLD_BRIGHT, Mat.Metal, CFrame.identity, 0, math.pi * 2, 24)
			local radiantCore = lump("SanctumRadiantSun", V(sx, sy + 32, sz), V(7.5, 7.5, 7.5), GLOW_GOLD, Mat.Neon)
			radiantCore.Transparency = 0.25
			addLight(radiantCore, GOLD_LIGHT, 2.0, 88)

			-- Iconic giant glowing floating Open Golden Tome hovering prominently in front of the Sanctum crown (visible from arrival!)
			local tomeY = sy + 42
			local tomeZ = sz + 11
			for _, side in { -1, 1 } do
				local pageCF = CFrame.new(V(sx + side * 7.8, tomeY, tomeZ)) * CFrame.Angles(math.rad(-20), 0, math.rad(-side * 22))
				boxAt("GrandTomeCover", pageCF * CFrame.new(0, -0.65, 0), V(15.6, 0.75, 18.0), GOLD_BRIGHT, Mat.Metal)
				local page = boxAt("GrandTomePage", pageCF, V(14.6, 0.90, 16.8), GLOW_GOLD, Mat.Neon)
				page:SetAttribute("ConjunctionGlyph", true)
				safeTag(page, "ConjunctionGlyph")
			end
			boxAt("GrandTomeSpine", CFrame.new(V(sx, tomeY - 2.8, tomeZ)) * CFrame.Angles(math.rad(-20), 0, 0), V(2.4, 1.2, 18.4), BRASS_AGED, Mat.Metal)

			-- Soft diagonal warm golden ADDITIVE volumetric god-rays streaming down onto the Grand Tome Sanctum!
			for rIdx, spec in {
				{ V(0, 0, 0), 26.0, 48.0, 0.58 },
				{ V(-18, 4, 8), 16.0, 32.0, 0.68 },
				{ V(18, 2, -6), 18.0, 34.0, 0.66 },
			} do
				local rayBot = V(sx, sy + 10, sz + 6) + spec[1]
				local rayTop = rayBot + V(58, 148, -26)
				addVolumetricBeam("SanctumGodRay_" .. rIdx, rayBot, rayTop, spec[2], spec[3], GLOW_GOLD, spec[4])
			end

			-- 4 glowing golden braziers ringing the Nib Star perimeter balustrade (cleanly inside R = 58.2!)
			for _, bp in {
				V(132, ly, -196), V(218, ly, -196),
				V(134, ly, -256), V(216, ly, -256),
			} do
				buildBrazier(bp, 1.15, false)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		-- Two dramatic orbiting rings of glowing floating books (one eye-level around the Grand Tome, one high on the spire!)
		for ringIdx, rSpec in { { ly + 24, 1.55, 15 }, { ly + 72, 1.25, 110 } } do
			local tomes = piece("AstralOrbitTomes", lm.X, lm.Z + 2, rSpec[3], "FloatingTomeCluster", rSpec[2], HALCYR_41, function(cf)
				for i = 1, 6 do
					local a = i * math.pi * 2 / 6
					boxAt("FloatingTome_" .. ringIdx, cf * CFrame.new(math.cos(a) * 16, 2 + (i % 3) * 2.5, math.sin(a) * 16), V(3.6, 0.9, 2.6), HALCYR_41.SILK.Color, Mat.Fabric)
				end
			end, rSpec[1])
			pin(tomes)
			noCollide(tomes)
		end
		pageEmitter(V(lm.X, ly + 32, lm.Z + 12), 4)
	end

	-- 2. The Index Gate (grand celestial ring-gate straddling Sanctuary arrival stair)
	do
		local lm = AstralFloor41.Landmarks[2]
		local m = piece("AstralGateRing", lm.X, lm.Z, 0, "IndexGateRing", 1.0, HALCYR_41, function(cf)
			ctx.ring("IndexGateFallback", cf.Position + V(0, 21, 0), 19, 2.4, GOLD_BRIGHT, Mat.Metal, nil, 0, math.pi * 2, 18)
		end, lm.Y)
		pin(m)
		noCollide(m)
		if m then
			addLight(H.glowOf(m), GOLD_LIGHT, 1.6, 56)
		end
	end

	-- 3. Catalogue Isle card-catalogue cabinets + framed Nereth tide-chart ("received wet") — facing inward into Catalogue!
	do
		local lm = AstralFloor41.Landmarks[3]
		local ly = lm.Y :: number
		local m = piece("CatalogueCabinets", lm.X, lm.Z, -36, "CatalogueCabinet", 0.96, HALCYR_41, function(cf)
			boxAt("CardCabinet", cf * CFrame.new(0, 5.2, 0), V(13, 10.4, 6), HALCYR_41.WOOD.Color, Mat.Wood)
		end, ly)
		pin(m)
		-- Brass-framed water-stained slate tide-chart from Floor 37 ("received wet"), facing inward beside the cabinet!
		ctx.group("NerethTideChart", function()
			local at = V(106, ly + 4.8, -41)
			boxAt("TideChartFrame", CFrame.new(at) * CFrame.Angles(0, math.rad(0), 0), V(4.4, 5.6, 0.5), BRASS_AGED, Mat.Metal)
			local slate = boxAt("TideChartSlate", CFrame.new(at) * CFrame.Angles(0, math.rad(0), 0) * CFrame.new(0, 0, 0.25), V(3.6, 4.6, 0.2), rgb(64, 96, 114), Mat.Slate)
			slate:SetAttribute("Label", "received wet")
			makeDecor(ctx.current())
		end)
		pageEmitter(V(lm.X, ly + 6, lm.Z), 3)
	end

	-- 4–5. The Inkwell swirling arcane scrying pool & copyist desks on EastGallery's integrated eastern marble bay
	do
		local lm = AstralFloor41.Landmarks[4]
		local ly = lm.Y :: number
		-- Seamless circular eastern Scrying Bay merged directly into EastGallery's eastern rim
		buildMarbleBay(lm.X, ly, lm.Z, 24.0, 17.5)

		local m = piece("TheInkwellBasin", lm.X, lm.Z, 0, "InkwellBasin", 1.05, INK_TINT, function(cf)
			ctx.cyl("InkwellRim", cf.Position + V(0, 2.2, 0), 12, 4.4, MARBLE_LIGHT, Mat.Marble)
			ctx.cyl("InkwellPool", cf.Position + V(0, 3.6, 0), 10.2, 0.6, rgb(38, 72, 178), Mat.Neon)
		end, ly)
		pin(m)
		if m then addLight(H.glowOf(m) or m:FindFirstChildWhichIsA("BasePart", true), CYAN_LIGHT, 1.4, 48) end

		local dk = AstralFloor41.Landmarks[5]
		local md = piece("InkwellCopyistDesk", dk.X, dk.Z, -18, "CopyistDesk", 0.95, HALCYR_41, function(cf)
			boxAt("CopyDesk", cf * CFrame.new(0, 2.8, 0), V(7.5, 5.6, 4.5), HALCYR_41.WOOD.Color, Mat.Wood)
		end, dk.Y)
		pin(md)
		tagDetail(md)
		-- Companion copyist desk on the southern rim of the Scrying Bay (100% grounded on bay!)
		local md2 = piece("InkwellCopyistDeskSouth", 240, 40, -162, "CopyistDesk", 0.95, HALCYR_41, function(cf)
			boxAt("CopyDeskS", cf * CFrame.new(0, 2.8, 0), V(7.5, 5.6, 4.5), HALCYR_41.WOOD.Color, Mat.Wood)
		end, ly)
		pin(md2)
		tagDetail(md2)
	end

	-- 6. The Blotter: UNIFIED cracked vellum-marble slab hung by 4 monumental golden chains (NO duplicate mini slab!)
	do
		local blotter = P.Blotter
		if blotter then
			local bx, by, bz = blotter.X, blotter.Y, blotter.Z
			local bw, bd = blotter.Width, blotter.Depth
			ctx.group("BlotterChainedSlab", function()
				-- Chiseled weathered marble underside bevel & dark-indigo cosmic star-ink blot inlaid flush in the center!
				boxAt("BlotterSlabTrim", CFrame.new(V(bx, by - 4.4, bz)), V(bw - 3, 2.2, bd - 3), rgb(172, 166, 154), Mat.Limestone)
				boxAt("BlotterGoldCornerTrim", CFrame.new(V(bx, by - 1.2, bz)), V(bw + 0.6, 0.55, bd + 0.6), BRASS_AGED, Mat.Metal)
				-- Organic multi-lobe star-ink blot flush on top of Blotter (non-colliding, matching Image 2!)
				ctx.cyl("BlotterInkCenter", V(bx, by + 0.08, bz), 11.5, 0.14, LAPIS_DEEP, Mat.Glass)
				ctx.cyl("BlotterInkGlow", V(bx, by + 0.11, bz), 6.2, 0.10, rgb(58, 72, 162), Mat.Neon)
				for _, lobe in { { -10, -5, 5.2 }, { 9, -6, 6.0 }, { 11, 6, 4.8 }, { -8, 8, 5.6 }, { 2, -12, 4.0 } } do
					ctx.cyl("BlotterInkLobe", V(bx + lobe[1], by + 0.07, bz + lobe[2]), lobe[3], 0.14, LAPIS_DEEP, Mat.Glass)
				end

				-- 4 monumental sculpted golden-brass link chains anchored to the 4 corners rising 155 studs into the cosmos!
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local cx = bx + sx * (bw * 0.45)
						local cz = bz + sz * (bd * 0.45)
						-- Corner brass anchor shackle plate & bolted ring
						boxAt("BlotterAnchorPlate", CFrame.new(V(cx, by + 0.45, cz)), V(4.2, 0.9, 4.2), BRASS_AGED, Mat.Metal)
						ctx.ring("BlotterAnchorRing", V(cx, by + 2.1, cz), 1.8, 0.55, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(0, math.pi / 4, 0), 0, math.pi * 2, 12)
						-- Bold golden chain column + alternating sculptural chain links so it reads richly up close & from afar
						ctx.beam("BlotterSkyChainCore", V(cx, by + 2.0, cz), V(cx, by + 152, cz), 1.15, BRASS_AGED, Mat.Metal, 0)
						for k = 0, 23 do
							local ly = by + 5.2 + k * 6.0
							local rotY = if k % 2 == 0 then 0 else math.pi / 2
							boxAt("BlotterChainLink", CFrame.new(V(cx, ly, cz)) * CFrame.Angles(0, rotY, 0), V(2.4, 4.4, 0.85), if k % 2 == 0 then GOLD_BRIGHT else BRASS_AGED, Mat.Metal)
						end
					end
				end
				noCollide(ctx.current())
				pin(ctx.current())
			end)
		end
	end

	-- 7. Vane Root Archivist Watch Alcove (clean, reasonable perimeter colonnade — NO nonsensical mid-area gate!)
	do
		local vr = AstralFloor41.Landmarks[7]
		local vy = vr.Y :: number
		buildMarbleBay(vr.X + 4, vy, vr.Z, 20.0, 12.5)
		ctx.group("VaneRootWatchpost", function()
			-- Curved 4-column classical marble colonnade hugging the western outer rim (never blocking open combat space)
			for i = -1.5, 1.5, 1 do
				local a = math.pi + i * 0.34
				local cx = (vr.X + 4) + math.cos(a) * 15.5
				local cz = vr.Z + math.sin(a) * 15.5
				ctx.cyl("WatchColumn", V(cx, vy + 6.2, cz), 1.25, 12.4, MARBLE_LIGHT, Mat.Marble)
				boxAt("WatchColBase", CFrame.new(V(cx, vy + 0.6, cz)), V(3.2, 1.2, 3.2), MARBLE_WARM, Mat.Marble)
				boxAt("WatchColCap", CFrame.new(V(cx, vy + 12.6, cz)), V(3.4, 0.9, 3.4), GOLD_BRIGHT, Mat.Metal)
			end
			-- Curved golden architrave beam uniting the 4 rim columns
			ctx.ring("WatchArchitrave", V(vr.X + 4, vy + 13.4, vr.Z), 15.5, 1.1, MARBLE_LIGHT, Mat.Marble, CFrame.Angles(math.pi / 2, 0, 0), math.pi - 0.56, math.pi + 0.56, 8)
			ctx.ring("WatchArchitraveGold", V(vr.X + 4, vy + 14.1, vr.Z), 15.5, 0.5, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), math.pi - 0.56, math.pi + 0.56, 8)
			-- Brass Archivist's Register Lectern + open ledger nestled inside the colonnade bay
			ctx.cyl("RegisterPed", V(vr.X + 2, vy + 2.4, vr.Z), 0.75, 4.8, BRASS_AGED, Mat.Metal)
			boxAt("RegisterDesk", CFrame.new(V(vr.X + 2, vy + 5.0, vr.Z)) * CFrame.Angles(0, math.rad(90), math.rad(-22)), V(3.6, 0.4, 2.6), GOLD_BRIGHT, Mat.Metal)
			boxAt("RegisterLedger", CFrame.new(V(vr.X + 2.2, vy + 5.35, vr.Z)) * CFrame.Angles(0, math.rad(90), math.rad(-22)), V(3.0, 0.35, 2.1), HALCYR_41.SILK.Color, Mat.Fabric)
			-- Twin warm golden braziers framing the watch alcove
			buildBrazier(V(vr.X + 6, vy, vr.Z - 11), 1.0, false)
			buildBrazier(V(vr.X + 6, vy, vr.Z + 11), 1.0, true)
			noCollide(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 8. Lamplighters' Isle lamp-store rack & warm perimeter braziers (clean courtyard, grounded inside Shaft's R=34.2 rim!)
	do
		local lr = AstralFloor41.Landmarks[8]
		local ly = lr.Y :: number
		local mlr = piece("LamplighterRack", lr.X, lr.Z, -145, "LamplighterRack", 0.90, HALCYR_41, function(cf)
			boxAt("LampRack", cf * CFrame.new(0, 6, 0), V(14, 12, 3), BRASS_AGED, Mat.Metal)
		end, ly)
		pin(mlr)
		if mlr then addLight(H.glowOf(mlr), GOLD_LIGHT, 1.25, 42) end
		ctx.group("LamplighterBraziers", function()
			buildBrazier(V(-108, ly, -4), 1.0, false)
			buildBrazier(V(-72, ly, -4), 1.0, false)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 9. The Calamus Central Golden Armillary Sphere (crowning Crossing's integrated northern marble dais bay!)
	do
		local ca = AstralFloor41.Landmarks[9]
		local cy = ca.Y :: number
		buildMarbleBay(ca.X, cy, ca.Z + 2, 19.5, 28.0)
		local mca = piece("CalamusArmillary", ca.X, ca.Z, 20, "CalamusArmillary", 1.32, HALCYR_41, function(cf)
			ctx.ring("CalamusRing", cf.Position + V(0, 16, 0), 10, 1.3, GOLD_BRIGHT, Mat.Metal, nil, 0, math.pi * 2, 16)
		end, cy)
		pin(mca)
		makeDecor(mca)
		if mca then addLight(H.glowOf(mca), GOLD_LIGHT, 1.8, 62) end
	end

	-- 10–12. The Three Sweeping Library Islands (Barb1, Barb2, Barb3, R=32.2):
	-- Each has an integrated outer marble reading bay extending cleanly behind the curved bookcase arc so
	-- every bookcase, planter, and study desk sits 100% solidly grounded on marble with zero void overhang!
	local libraryArcs = {
		-- { LandmarkIdx, CenterX, CenterZ, Y, OuterArcAngleRad, UndersideDepth }
		{ 10, -215, -100, 20, math.pi, 22.0 },            -- W outer arc of Barb1
		{ 11, -130, -170, 26, math.rad(-126), 28.0 },     -- NW outer arc of Barb2
		{ 12, -30, -235, 32, math.rad(-94), 32.0 },       -- N outer arc of Barb3
	}
	for _, arc in libraryArcs do
		local lm = AstralFloor41.Landmarks[arc[1]]
		local cx, cz, cy, centerAng, underD = arc[2], arc[3], arc[4], arc[5], arc[6]
		-- Seamless circular marble reading alcove bay merged cleanly into the island's outer arc!
		local bayX = cx + math.cos(centerAng) * 19.0
		local bayZ = cz + math.sin(centerAng) * 19.0
		buildMarbleBay(bayX, cy, bayZ, 24.5, underD)

		-- 3 curved bookcases seated tightly along the outer rim of the reading bay (radius 14.5 from bay center -> max corner 18.2 << 24.5 bay rim!)
		for bIdx, degOff in { 0, -46, 46 } do
			local a = centerAng + math.rad(degOff)
			local bx = bayX + math.cos(a) * 14.0
			local bz = bayZ + math.sin(a) * 14.0
			local inwardYaw = math.deg(math.atan2(cx - bx, cz - bz))
			local name = if bIdx == 1 then lm.Id else (lm.Id .. "_" .. bIdx)
			local mb = piece(name, bx, bz, inwardYaw, "BookcaseCurved", 0.72, HALCYR_41, function(cf)
				boxAt("BarbShelf", cf * CFrame.new(0, 6.2, 0), V(14, 12, 4.2), HALCYR_41.WOOD.Color, Mat.Wood)
			end, cy)
			pin(mb)
			if bIdx > 1 then tagDetail(mb) end
		end
		-- Cozy wooden study desk centered cleanly in the reading alcove facing the island center
		local dx = bayX + math.cos(centerAng) * 2.5
		local dz = bayZ + math.sin(centerAng) * 2.5
		local deskYaw = math.deg(math.atan2(cx - dx, cz - dz))
		local md = piece(lm.Id .. "Desk", dx, dz, deskYaw, "CopyistDesk", 0.85, HALCYR_41, function(cf)
			boxAt("LibraryDesk", cf * CFrame.new(0, 2.5, 0), V(6.8, 5.0, 4.0), HALCYR_41.WOOD.Color, Mat.Wood)
		end, cy)
		pin(md)
		tagDetail(md)
		-- Two star-moss planters neatly flanking the reading desk inside the bay (100% on marble, clear of all bridge landings!)
		for pIdx, degOff in { -70, 70 } do
			local a = centerAng + math.rad(degOff)
			local px2 = bayX + math.cos(a) * 12.2
			local pz2 = bayZ + math.sin(a) * 12.2
			local plantYaw = math.deg(math.atan2(cx - px2, cz - pz2))
			local mp = piece(lm.Id .. "Planter" .. pIdx, px2, pz2, plantYaw, "StarMossPlanter", 0.62, HALCYR_41, function(cf)
				boxAt("MossPlanter", cf * CFrame.new(0, 1.8, 0), V(8.0, 3.4, 3.4), HALCYR_41.MOSS.Color, Mat.Grass)
			end, cy)
			pin(mp)
			tagDetail(mp)
		end
	end

	-- 13–14. Colossal Flanking Carved-Marble Hooded Sage Statues holding glowing golden Armillary Spheres!
	for _, pair in { { AstralFloor41.Landmarks[13], 72 }, { AstralFloor41.Landmarks[14], -108 } } do
		local lm = pair[1]
		local sy = lm.Y :: number
		local yaw = pair[2]
		local ms = piece(lm.Id, lm.X, lm.Z, yaw, "RobedStatueStaff", 1.50, STATUE_TINT, function(cf)
			boxAt("ArchivistBody", cf * CFrame.new(0, 28, 0), V(14, 56, 14), MARBLE_LIGHT, Mat.Marble)
		end, sy)
		pin(ms)
		-- Mossy floating rock islet with glowing cyan crystal spikes right under the sage's plinth
		ctx.group(lm.Id .. "Isle", function()
			ctx.cyl("SageIsletMoss", V(lm.X, sy - 0.6, lm.Z), 18.5, 1.4, HALCYR_41.MOSS.Color, Mat.Grass)
			ctx.cyl("SageIsletRim", V(lm.X, sy - 2.0, lm.Z), 17.5, 2.0, rgb(56, 62, 82), Mat.Slate)
			-- Center the golden multi-ring Armillary Sphere directly around the statue's held glowing staff orb!
			local radYaw = math.rad(yaw)
			local staffGlow = H.glowOf(ms)
			local armPos = if staffGlow and staffGlow:IsA("BasePart")
				then (staffGlow.Position - ctx.origin)
				else V(lm.X + math.sin(radYaw) * 8.5, sy + 88, lm.Z + math.cos(radYaw) * 8.5)
			lump("SageArmillaryCore", armPos, V(5.8, 5.8, 5.8), GLOW_GOLD, Mat.Neon)
			ctx.ring("SageArmRing1", armPos, 10.5, 0.80, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.rad(18), radYaw, 0), 0, math.pi * 2, 20)
			ctx.ring("SageArmRing2", armPos, 8.4, 0.65, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.rad(-38), radYaw + 0.8, 0.4), 0, math.pi * 2, 18)
			ctx.ring("SageArmRing3", armPos, 6.4, 0.55, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.rad(64), radYaw, 0.7), 0, math.pi * 2, 16)
			addVolumetricBeam("SageUpBeam", armPos, armPos + V(0, 74, 0), 12.0, 22.0, GLOW_GOLD, 0.56)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
		local u = placeKitScaled(lm.Id .. "Underside", lm.X, sy - 21.0, lm.Z, yaw, "StarIsleUndersideS", V(1.18, 0.72, 1.18), UNDERSIDE_TINT, function(cf)
			ctx.cyl("StatueIsleCone", cf.Position + V(0, 10, 0), 14, 20, rgb(42, 48, 72), Mat.Slate)
		end)
		makeDecor(u)
	end

	-- 15–19. Five Distant Floating Domed Library Towers + Hovering Giant Book Stacks in the Starfield!
	local towerSpecs = {
		{ 15, 1.55, 38 },
		{ 16, 1.55, -135 },
		{ 17, 1.35, 110 },
		{ 18, 1.45, 15 },
		{ 19, 1.40, -82 },
	}
	for _, ts in towerSpecs do
		local lm = AstralFloor41.Landmarks[ts[1]]
		local mt = piece(lm.Id, lm.X, lm.Z, ts[3], "FarArchiveTower", ts[2], HALCYR_41, function(cf)
			boxAt("FarTower", cf * CFrame.new(0, 32, 0), V(20, 64, 18), MARBLE_LIGHT, Mat.Marble)
		end, lm.Y)
		pin(mt)
		noCollide(mt)
	end
	-- Drifting giant book stacks framing the floating background towers (matching Image 2!)
	ctx.group("AstralSkyQuill", function()
		buildFloatingBookStack(V(-238, 52, -238), 5, 1.15, 1)
		buildFloatingBookStack(V(-280, 40, -195), 4, 1.0, 2)
		buildFloatingBookStack(V(-155, 58, -268), 4, 1.05, 3)
		buildFloatingBookStack(V(276, 42, -210), 5, 1.10, 4)
		buildFloatingBookStack(V(276, 32, -88), 4, 0.95, 5)
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- E. THE QUILL CONSTELLATION INDEX LAMPS (tucked along island sides/balustrades, arching inward — never blocking pathways!)
	-- =========================================================================
	-- { x, y, z, withLight, lookAtX, lookAtZ }
	local lampSpots = {
		{ -56, 0, 121, true, -56, 165 },       -- Concourse west (against north balustrade, arching south)
		{ 56, 0, 121, true, 56, 165 },         -- Concourse east (against north balustrade, arching south)
		{ -158, 8, 47.5, true, -190, 25 },     -- Vane Root SE rim (arching inward)
		{ -90, 16, -53.5, true, -90, -24 },    -- Lamplighters' Isle N rim (arching inward)
		{ 0, 24, -49.5, true, 0, -85 },        -- The Calamus S rim (clear of center & all 4 bridges, arching inward)
		{ 67.5, 28, -166.7, true, 80, -140 },  -- Nib Landing NW rim (arching inward)
		{ 218.4, 36, -194.6, true, 175, -225 },-- Nib Star SE rim (arching inward)
		{ -217.4, 20, -72.6, false, -215, -100 }, -- Barb1 S rim (arching inward)
		{ -129.0, 26, -142.5, false, -130, -170 },-- Barb2 S rim (arching inward)
		{ -27.6, 32, -207.6, false, -30, -235 },  -- Barb3 S rim (arching inward)
		{ 162.3, 12, 51.7, false, 190, 24 },   -- The Inkwell SW rim (arching inward)
		{ 216, 23, -89, true, 190, -89 },      -- The Blotter E edge (arching west inward)
	}
	for _, sp in lampSpots do
		local inwardYaw = math.deg(math.atan2(sp[5] - sp[1], sp[6] - sp[3]))
		local ml = piece("AstralIndexLamp", sp[1], sp[3], inwardYaw, "IndexLamp", 1.05, HALCYR_41, function(cf)
			ctx.cyl("LampPost", cf.Position + V(0, 6, 0), 0.7, 12, BRASS_AGED, Mat.Metal)
			lump("LampBulb", cf.Position + V(0, 11.5, 0), V(2.2, 2.8, 2.2), GLOW_GOLD, Mat.Neon)
		end, sp[2])
		pin(ml)
		tagDetail(ml)
		if ml then
			ml:SetAttribute("ConjunctionLamp", true)
			safeTag(ml, "ConjunctionLamp")
			if sp[4] then
				addLight(H.glowOf(ml), GOLD_LIGHT, 1.35, 44)
			end
		end
	end

	-- =========================================================================
	-- F. FEATHERED SKY QUILL CONSTELLATION (tilted visibly in the NW sky like Image 2!)
	-- =========================================================================
	ctx.group("AstralSkyQuill", function()
		-- Curved golden feather quill silhouette tilted toward the Sanctuary arrival camera
		local quillSpine = {
			V(-172, 124, -192), V(-152, 138, -202), V(-130, 152, -212),
			V(-106, 165, -222), V(-82, 174, -230), V(-60, 180, -236),
		}
		local upperVane = {
			V(-152, 138, -202), V(-138, 158, -206), V(-116, 174, -214),
			V(-90, 184, -224), V(-60, 180, -236),
		}
		local lowerVane = {
			V(-152, 138, -202), V(-124, 140, -210), V(-98, 152, -220),
			V(-76, 166, -228), V(-60, 180, -236),
		}
		local function drawStarPath(pts: { Vector3 }, thickness: number, col: Color3)
			for i = 1, #pts - 1 do
				local seg = ctx.beam("QuillSkyLine", pts[i], pts[i + 1], thickness, col, Mat.Neon, 0.14)
				seg:SetAttribute("ConjunctionGlyph", true)
				safeTag(seg, "ConjunctionGlyph")
			end
		end
		drawStarPath(quillSpine, 0.72, GLOW_GOLD)
		drawStarPath(upperVane, 0.48, GLOW_GOLD)
		drawStarPath(lowerVane, 0.48, GLOW_GOLD)

		-- Trailing constellation stars streaming east from the Quill nib toward the Grand Tome Sanctum!
		local stars = {
			V(-172, 124, -192), V(-134, 128, -206), V(-98, 136, -218),
			V(-64, 150, -228), V(-24, 158, -236), V(18, 170, -242),
			V(-106, 165, -222), V(-60, 180, -236),
		}
		for i, pt in stars do
			local sz = if i == 1 or i == 6 or i == 8 then 4.6 else 3.2
			local st = lump("QuillSkyStar", pt, V(sz, sz, sz), GLOW_GOLD, Mat.Neon)
			st:SetAttribute("ConjunctionGlyph", true)
			safeTag(st, "ConjunctionGlyph")
		end
		for i = 1, 5 do
			local seg = ctx.beam("QuillSkyConstellation", stars[i], stars[i + 1], 0.45, SILVER_LIGHT, Mat.Neon, 0.22)
			seg:SetAttribute("ConjunctionGlyph", true)
			safeTag(seg, "ConjunctionGlyph")
		end
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	-- Gentle ambient page drifts near the Concourse, Calamus, Library Arc & Inkwell
	pageEmitter(V(-60, 6, 150), 3)
	pageEmitter(V(0, 28, -85), 3)
	pageEmitter(V(-130, 30, -170), 2)
	pageEmitter(V(190, 18, 30), 2)

	ctx.setAttribute("AstralFloor", 41)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor41
