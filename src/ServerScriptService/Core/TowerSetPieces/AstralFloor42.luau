--!strict
-- Hand-authored set pieces for Astral Archives Floor 42: Orbiting Stacks (astral:2, EXPANDED_ENCOUNTER).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 42) & reference/Astral Archives 42.jpg.
--
-- A working brass orrery suspended over a luminous cosmic Nebula Sea and swirling galaxy vortex pool:
-- three concentric floating orbits round the elevated Sun-Lectern (Apex, dead centre at Y=44), crowned by
-- the 156.5-stud tall brass Armillary Sphere and blazing Sun core, framed by three grand outer brass orbit
-- rings with cogwheels and the first hairline violet Rift tear in the high north sky.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AstralFloor42 = {}

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

-- Warm brass noon Halcyr palette (pale starlight gold glow, hue ~45°, sat ~0.36 — never orange/red).
local HALCYR_42 = table.freeze({
	STONE = swatch(228, 220, 204, Mat.Marble),
	ALT = swatch(36, 46, 90, Mat.Marble),
	TRIM = swatch(222, 190, 108, Mat.Metal),
	METAL = swatch(186, 152, 82, Mat.Metal),
	WOOD = swatch(94, 62, 42, Mat.Wood),
	SILK = swatch(242, 234, 214, Mat.Fabric),
	GLOW = swatch(250, 228, 160, Mat.Neon),
	CRYSTAL = swatch(138, 192, 238, Mat.Glass, 0.20),
	MOSS = swatch(102, 146, 124, Mat.Grass),
})

-- Hide the flat grey STONE top lid on OrreryGearUnderside & StarIsleUndersideS so our crisp marble/ice island
-- deck caps read cleanly while the dark faceted slate hull & protruding golden brass cogwheels shine underneath!
local GEAR_UNDERSIDE_TINT = tinted(HALCYR_42, {
	STONE = swatch(228, 220, 204, Mat.Marble, 1),
	ALT = swatch(38, 46, 78, Mat.Slate),
	METAL = swatch(186, 152, 82, Mat.Metal),
	TRIM = swatch(222, 190, 108, Mat.Metal),
	GLOW = swatch(250, 228, 160, Mat.Neon),
})

local FROST_UNDERSIDE_TINT = tinted(HALCYR_42, {
	STONE = swatch(204, 232, 248, Mat.Ice, 1),
	ALT = swatch(112, 168, 214, Mat.Glacier),
	CRYSTAL = swatch(166, 224, 255, Mat.Ice, 0.14),
	GLOW = swatch(206, 236, 255, Mat.Neon),
})

local PLANET_TINTS = {
	tinted(HALCYR_42, { ALT = swatch(188, 146, 86, Mat.Marble), CRYSTAL = swatch(232, 206, 148, Mat.Glass, 0.2) }), -- Folio (warm ochre/Saturn)
	tinted(HALCYR_42, { ALT = swatch(74, 156, 182, Mat.Marble), CRYSTAL = swatch(148, 218, 238, Mat.Glass, 0.2) }), -- Codex (cerulean-teal)
	tinted(HALCYR_42, { ALT = swatch(76, 142, 132, Mat.Marble), CRYSTAL = swatch(138, 210, 200, Mat.Glass, 0.2) }), -- Atlas (jade-teal)
	tinted(HALCYR_42, { ALT = swatch(178, 134, 96, Mat.Marble), CRYSTAL = swatch(228, 198, 156, Mat.Glass, 0.2) }), -- Almanac (copper-ochre)
	tinted(HALCYR_42, { ALT = swatch(132, 182, 226, Mat.Ice), CRYSTAL = swatch(194, 230, 255, Mat.Glass, 0.15) }), -- Aphelion (frost-blue)
	tinted(HALCYR_42, { ALT = swatch(96, 112, 168, Mat.Marble), CRYSTAL = swatch(168, 192, 240, Mat.Glass, 0.2) }), -- Concordance (indigo)
}

local GOLD_LIGHT = rgb(250, 228, 160)
local FROST_LIGHT = rgb(196, 228, 255)
local CYAN_LIGHT = rgb(144, 206, 252)

local MARBLE_LIGHT = rgb(232, 224, 208)
local MARBLE_WARM = rgb(218, 208, 190)
local SLATE_BLUE = rgb(62, 82, 118)
local SLATE_BLUE_DARK = rgb(44, 60, 94)
local LAPIS_DEEP = rgb(32, 42, 86)
local LAPIS_MID = rgb(48, 66, 124)
local GOLD_BRIGHT = rgb(224, 192, 110)
local BRASS_AGED = rgb(186, 152, 82)
local GLOW_GOLD = rgb(250, 230, 166)
local CYAN_GLOW = rgb(124, 214, 255)
local FROST_ICE = rgb(204, 232, 248)
local FROST_TRIM = rgb(146, 198, 234)
local SILVER_LIGHT = rgb(214, 228, 252)

-- Floor 42's 19 landmark footprints (local floor space, 660 x 680).
-- Every single landmark is 100% grounded on its island or integrated marble bay, and spec-checked against
-- every walkway lane, camp (34-stud clearance), portal (12-stud clearance) and room bounds.
AstralFloor42.Landmarks = table.freeze({
	-- 1. Armillary Sphere Tall (>= 150 studs, 156.5 studs) seated flush on the Sun-Lectern dais (Apex Y=44)
	{ Id = "SunArmillarySphere", X = 0, Z = -70, Y = 44, HalfX = 56.6, HalfZ = 56.6, Top = 156.5, Straddles = true },
	-- 2. The Sun-Lectern Globe suspended dead-centre inside the Armillary Sphere (34 studs clear above Apex Y=44)
	{ Id = "SunLecternGlobe", X = 0, Z = -70, Y = 78, HalfX = 12.4, HalfZ = 12.4, Top = 36.8, Straddles = true },
	-- 3. The Orrery Gate arch straddling arrival above Sanctuary -> Basin
	{ Id = "TheOrreryGate", X = 0, Z = 278, Y = 8, HalfX = 21.8, HalfZ = 3.5, Top = 31.8, Straddles = true },
	-- 4. Folio Ring Bookcase (grounded on WestGallery's integrated western curved reading bay, clear of camp)
	{ Id = "FolioRingBookcase", X = -260, Z = 28, Y = 10, HalfX = 4.5, HalfZ = 10.5, Top = 13.6 },
	-- 5. Codex Ring Bookcase (grounded on EastGallery's integrated eastern curved reading bay, clear of camp)
	{ Id = "CodexRingBookcase", X = 260, Z = 28, Y = 12, HalfX = 4.5, HalfZ = 10.5, Top = 13.6 },
	-- 6. Folio Planet Globe mast (grounded on WestGallery's reading bay, clear of camp & south bridge landing)
	{ Id = "FolioPlanetGlobe", X = -254, Z = 48, Y = 10, HalfX = 5.0, HalfZ = 5.0, Top = 25.1 },
	-- 7. Codex Planet Globe mast (grounded on EastGallery's reading bay, clear of camp & south bridge landing)
	{ Id = "CodexPlanetGlobe", X = 254, Z = 48, Y = 12, HalfX = 5.0, HalfZ = 5.0, Top = 25.1 },
	-- 8. Folio Moon Phase Disc (grounded cleanly on MoonSW's integrated south medallion bay, facing Sanctuary)
	{ Id = "FolioMoonPhaseDisc", X = -110, Z = 56, Y = 15, HalfX = 6.2, HalfZ = 2.0, Top = 15.0 },
	-- 9. Codex Moon Phase Disc (grounded cleanly on MoonSE's integrated south medallion bay, facing Sanctuary)
	{ Id = "CodexMoonPhaseDisc", X = 110, Z = 56, Y = 17, HalfX = 6.2, HalfZ = 2.0, Top = 15.0 },
	-- 10. Glossary Marginalia Stack (grounded on MoonW's integrated western stack bay)
	{ Id = "GlossaryStack", X = -300, Z = -74, Y = 20, HalfX = 5.2, HalfZ = 4.0, Top = 7.6 },
	-- 11. Marginalia Stack (grounded on MoonE's integrated eastern stack bay)
	{ Id = "MarginaliaStack", X = 300, Z = -74, Y = 22, HalfX = 5.2, HalfZ = 4.0, Top = 7.6 },
	-- 12. Atlas Globe Stand (grounded on OuterNW's integrated NW alcove bay)
	{ Id = "AtlasGlobeStand", X = -216, Z = -248, Y = 25, HalfX = 9.6, HalfZ = 5.4, Top = 15.2 },
	-- 13. Almanac Star-Table Slate (grounded on OuterNE's integrated NE alcove bay)
	{ Id = "AlmanacStarTable", X = 216, Z = -248, Y = 27, HalfX = 9.2, HalfZ = 2.8, Top = 13.2 },
	-- 14. Lexicon Lectern Row (grounded on MiddleW's integrated western lectern bay)
	{ Id = "LexiconLecternRow", X = -180, Z = -110, Y = 30, HalfX = 2.4, HalfZ = 7.2, Top = 6.6 },
	-- 15. Concordance Lectern Row (grounded on MiddleE's integrated eastern lectern bay)
	{ Id = "ConcordanceLecternRow", X = 180, Z = -110, Y = 34, HalfX = 2.4, HalfZ = 7.2, Top = 6.6 },
	-- 16. The Aphelion lone telescope (grounded on Aphelion's integrated frosty northern observatory bay)
	{ Id = "AphelionTelescope", X = 0, Z = -302, Y = 39, HalfX = 5.4, HalfZ = 6.5, Top = 12.2 },
	-- 17. Perihelion Court Brass Sundial (grounded on Crossing's integrated northern marble dais bay, clear of camp)
	{ Id = "PerihelionSundial", X = 0, Z = 32, Y = 8, HalfX = 9.2, HalfZ = 9.2, Top = 7.0 },
	-- 18. Plinth West Ring Gear half-sunk solidly on Basin's slate-blue north terrace
	{ Id = "PlinthRingGearW", X = -156, Z = 174, Y = 0, HalfX = 10.4, HalfZ = 3.6, Top = 10.8 },
	-- 19. Plinth East Ring Gear half-sunk solidly on Basin's slate-blue north terrace
	{ Id = "PlinthRingGearE", X = 156, Z = 174, Y = 0, HalfX = 10.4, HalfZ = 3.6, Top = 10.8 },
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

function AstralFloor42.Build(ctx: any)
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
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, HALCYR_42.SILK.Color, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(246, 236, 206), rgb(246, 224, 156))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1.0), NumberSequenceKeypoint.new(1, 0.4) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3.5, 5.5)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1.0, 2.4)
		pe.SpreadAngle = Vector2.new(55, 55)
		pe.RotSpeed = NumberRange.new(-45, 45)
		pe.Acceleration = V(0, 0.5, 0)
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

	-- Helper: build a warm glowing golden pedestal brazier (flanking arrival arch & Apex dais)
	local function buildBrazier(pos: Vector3, scale: number, withLight: boolean)
		local s = scale
		ctx.cyl("BrazierBase", pos + V(0, 0.5 * s, 0), 1.6 * s, 1.0 * s, MARBLE_LIGHT, Mat.Marble)
		ctx.cyl("BrazierStem", pos + V(0, 2.3 * s, 0), 0.65 * s, 2.8 * s, BRASS_AGED, Mat.Metal)
		ctx.cyl("BrazierBowl", pos + V(0, 4.0 * s, 0), 1.5 * s, 0.85 * s, GOLD_BRIGHT, Mat.Metal)
		local flame = lump("BrazierFlame", pos + V(0, 4.9 * s, 0), V(1.6 * s, 2.0 * s, 1.6 * s), GLOW_GOLD, Mat.Neon)
		flame:SetAttribute("ConjunctionGlyph", true)
		safeTag(flame, "ConjunctionGlyph")
		if withLight then
			addLight(flame, GOLD_LIGHT, 1.3, 44)
		end
	end

	-- Helper: build a classical golden-trimmed marble alcove bay merged seamlessly into an island rim
	local function buildOrreryBay(x: number, y: number, z: number, radius: number, undersideDepth: number)
		ctx.group("AstralIsleDeck", function()
			ctx.cyl("BayMarbleCap", V(x, y - 0.54, z), radius, 1.2, MARBLE_LIGHT, Mat.Marble)
			ctx.cyl("BayLapisBand", V(x, y - 2.25, z), radius - 0.35, 2.4, LAPIS_DEEP, Mat.Marble)
			ctx.ring("BayGoldUpper", V(x, y - 0.52, z), radius + 0.28, 0.78, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
			ctx.ring("BayGoldLower", V(x, y - 3.40, z), radius - 0.40, 0.65, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
		local availH = math.max(8, math.min(undersideDepth, (y - 3.2) - (-5.4)))
		local sx = (radius * 2.02) / 48.48
		local sy = availH / 34.1
		local mu = placeKitScaled("AstralIsleUnderside", x, (y - 3.2) - availH, z, (x * 0.9 + z * 0.7) % 360, "OrreryGearUnderside", V(sx, sy, sx), GEAR_UNDERSIDE_TINT, function(cf)
			ctx.cyl("BayGearCone", cf.Position + V(0, availH * 0.5, 0), radius * 0.72, availH, LAPIS_DEEP, Mat.Slate)
		end)
		makeDecor(mu)
	end

	-- Helper: build small decorative floating open books above library & lectern islands (Image 1 detail!)
	local function buildFloatingOpenBook(pos: Vector3, yawDeg: number, scale: number)
		local s = scale
		local cf = CFrame.new(pos) * CFrame.Angles(math.rad(-14), math.rad(yawDeg), 0)
		for _, side in { -1, 1 } do
			local pcf = cf * CFrame.new(side * 1.15 * s, 0, 0) * CFrame.Angles(0, 0, math.rad(-side * 22))
			boxAt("FloatBookCover", pcf * CFrame.new(0, -0.14 * s, 0), V(2.3 * s, 0.16 * s, 2.8 * s), rgb(104, 64, 44), Mat.Wood)
			boxAt("FloatBookPage", pcf, V(2.1 * s, 0.16 * s, 2.55 * s), HALCYR_42.SILK.Color, Mat.Fabric)
		end
	end

	-- Helper: build a small neat stack of bound archive books on marble
	local function buildGroundBookStack(pos: Vector3, count: number, seed: number)
		for k = 0, count - 1 do
			local ang = math.rad(((seed * 29 + k * 37) % 50) - 25)
			local w = 2.8 - (k % 3) * 0.25
			local d = 2.1 - ((k + 1) % 3) * 0.18
			local h = 0.55
			local cf = CFrame.new(pos + V(0, h * 0.5 + k * (h + 0.03), 0)) * CFrame.Angles(0, ang, 0)
			local col = if k % 3 == 0 then rgb(108, 66, 44) elseif k % 3 == 1 then LAPIS_MID else rgb(82, 54, 88)
			boxAt("DeskBookCover", cf, V(w, h, d), col, Mat.Wood)
			boxAt("DeskBookPage", cf * CFrame.new(0.08, 0, 0), V(w * 0.90, h * 0.72, d * 0.90), HALCYR_42.SILK.Color, Mat.Fabric)
		end
	end

	-- Helper: create a true additive volumetric golden beam (LightEmission = 1)
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
		b.Color = ColorSequence.new(color, rgb(255, 248, 220))
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, math.min(0.92, peakAlpha + 0.24)),
			NumberSequenceKeypoint.new(0.22, peakAlpha),
			NumberSequenceKeypoint.new(0.65, math.min(0.95, peakAlpha + 0.16)),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		b.Parent = anchor
	end

	-- Reserve every landmark footprint so generic scatter respects them
	for _, lm in AstralFloor42.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =========================================================================
	-- A. DEEP-SPACE COSMIC NEBULA SEA + GIANT SWIRLING GALAXY VORTEX POOL
	-- Sits cleanly ABOVE the Basalt voxel top (Y = -4.0) at Y = -3.45 .. -2.55,
	-- hiding every raw black terrain bump completely and matching Image 1's iconic
	-- luminous circular brass-rimmed cosmic galaxy basin!
	-- =========================================================================
	ctx.group("AstralNebulaSea", function()
		-- Opaque deep midnight-indigo cosmic void floor covering the whole room & margins (no "Sea"/"Pool" in name -> 100% opaque!)
		boxAt("AstralVoidFloor", CFrame.new(V(0, -3.50, -10)), V(780, 0.30, 800), rgb(11, 15, 38), Mat.SmoothPlastic, 0)

		-- Outer ambient twilight nebula clouds
		for idx, nd in {
			{ -235, -3.28, -180, 145, rgb(36, 54, 134), 0.72 },
			{ 235, -3.27, -180, 145, rgb(62, 42, 134), 0.72 },
			{ -240, -3.26, 95, 130, rgb(44, 48, 128), 0.74 },
			{ 240, -3.25, 95, 130, rgb(34, 62, 136), 0.74 },
		} do
			local disc = ctx.cyl("NebulaOuterCloud_" .. idx, V(nd[1], nd[2], nd[3]), nd[4], 0.14, nd[5], Mat.SmoothPlastic, nd[6])
			disc.Transparency = nd[6]
		end

		-- Iconic Giant Circular Brass-Rimmed Swirling Galaxy Basin directly beneath the Sun (0, -70) (Image 1!)
		local gx, gz = 0, -70
		local galaxyBase = ctx.cyl("AstralGalaxyDisc", V(gx, -3.22, gz), 226, 0.20, rgb(24, 52, 118), Mat.SmoothPlastic, 0)
		galaxyBase:SetAttribute("ConjunctionGlyph", true)
		safeTag(galaxyBase, "ConjunctionGlyph")
		-- Luminous layered cyan-indigo & violet nebula vortex glow discs inside the galaxy rim
		local glowOuter = ctx.cyl("NebulaVortexOuter", V(gx, -3.08, gz), 218, 0.14, rgb(48, 114, 196), Mat.SmoothPlastic, 0.45)
		glowOuter.Transparency = 0.45
		local glowMid = ctx.cyl("NebulaVortexMid", V(gx, -3.00, gz), 162, 0.14, rgb(82, 162, 236), Mat.SmoothPlastic, 0.48)
		glowMid.Transparency = 0.48
		local glowCore = ctx.cyl("NebulaVortexCore", V(gx, -2.92, gz), 96, 0.14, rgb(126, 108, 224), Mat.SmoothPlastic, 0.46)
		glowCore.Transparency = 0.46
		-- Gleaming unbroken 360-deg brass-and-gold outer bezel rim & glowing inner zodiac orbit tracks
		ctx.ring("AstralGalaxyBrassRimOuter", V(gx, -2.62, gz), 230, 5.4, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 56)
		ctx.ring("AstralGalaxyBrassRimInner", V(gx, -2.78, gz), 224, 2.2, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 56)
		ctx.ring("AstralGalaxyMidRing", V(gx, -2.84, gz), 156, 1.8, CYAN_GLOW, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 40)
		ctx.ring("AstralGalaxyInnerRing", V(gx, -2.82, gz), 92, 1.5, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
		-- Swirling starlight spiral arms radiating through the cosmic galaxy disc
		for arm = 0, 3 do
			local baseAng = arm * (math.pi / 2) + 0.35
			for s = 1, 14 do
				local t = s / 14
				local r = 28 + t * 184
				local a = baseAng + t * 2.25
				local sx = gx + math.cos(a) * r
				local sz = gz + math.sin(a) * r
				local blobR = 26 - t * 10
				local col = if arm % 2 == 0 then rgb(104, 198, 255) else rgb(166, 134, 242)
				local swirl = ctx.cyl("NebulaSwirl_" .. arm .. "_" .. s, V(sx, -2.88 + (arm % 2) * 0.02, sz), blobR, 0.12, col, Mat.SmoothPlastic, 0.68 + t * 0.14)
				swirl.Transparency = 0.68 + t * 0.14
			end
		end
		-- Sparkling pinpoint starfield glints across the entire Nebula Sea & galaxy disc
		for i = 1, 160 do
			local sx = math.sin(i * 12.9898) * 320
			local sz = math.cos(i * 78.233) * 325 - 15
			local szStar = if i % 6 == 0 then 2.4 else 1.25
			local starCol = if i % 4 == 0 then GLOW_GOLD elseif i % 3 == 0 then CYAN_GLOW else SILVER_LIGHT
			local st = lump("AstralStarGlint", V(sx, -2.72, sz), V(szStar, 0.24, szStar), starCol, Mat.Neon)
			if i % 7 == 0 then
				st:SetAttribute("ConjunctionGlyph", true)
				safeTag(st, "ConjunctionGlyph")
			end
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. CIRCULAR MARBLE-AND-GOLD FLOATING ORRERY ISLANDS, GEARWORK UNDERSIDES & BALUSTRADES
	-- Every floating island gets a crisp marble (or frosty crystal for Aphelion) deck cap,
	-- gleaming golden trim collars, dark lapis frieze band, full-width brass clockwork
	-- underside (with its flat grey STONE lid hidden), distinctive floor inlays, and
	-- golden-trimmed marble balustrades automatically gapped cleanly at every bridge & bay!
	-- =========================================================================
	local bridgeAnglesByPlat: { [string]: { { number } } } = {}
	for _, link in ctx.layout.Links do
		local pFrom = P[link.From]
		local pTo = P[link.To]
		if pFrom and pTo then
			bridgeAnglesByPlat[link.From] = bridgeAnglesByPlat[link.From] or {}
			table.insert(bridgeAnglesByPlat[link.From], { math.atan2(link.AZ - pFrom.Z, link.AX - pFrom.X), link.Width })
			bridgeAnglesByPlat[link.To] = bridgeAnglesByPlat[link.To] or {}
			table.insert(bridgeAnglesByPlat[link.To], { math.atan2(link.BZ - pTo.Z, link.BX - pTo.X), link.Width })
		end
	end

	-- Extra angular openings where an integrated architectural alcove bay attaches seamlessly to an island
	local bayOpenings: { [string]: { { number } } } = {
		Crossing = { { -math.pi / 2, 0.56 } },           -- North dais bay for PerihelionSundial
		WestGallery = { { math.rad(172), 0.72 } },       -- West library reading alcove bay
		EastGallery = { { math.rad(8), 0.72 } },         -- East library reading alcove bay
		MoonSW = { { math.rad(100), 0.44 } },            -- South medallion bay for FolioMoonPhaseDisc
		MoonSE = { { math.rad(80), 0.44 } },             -- South medallion bay for CodexMoonPhaseDisc
		MoonW = { { math.pi, 0.52 } },                   -- West stack alcove bay for GlossaryStack
		MoonE = { { 0.0, 0.52 } },                       -- East stack alcove bay for MarginaliaStack
		OuterNW = { { math.rad(-135), 0.70 } },          -- NW Globe & Chests alcove bay
		OuterNE = { { math.rad(-45), 0.70 } },           -- NE Star-Table Mirrors alcove bay
		MiddleW = { { math.pi, 0.68 } },                 -- West Lexicon lectern bay
		MiddleE = { { 0.0, 0.68 } },                     -- East Concordance lectern bay
		Aphelion = { { -math.pi / 2, 0.60 } },           -- North frost observatory bay for AphelionTelescope
	}

	-- Island specs: { PlatformId, Radius (matched to clean rim-to-rim RoundDecks), DesiredDepth, FloorStyle }
	local circularIsles = {
		{ "WestGallery", 44.2, 15.0, "LIBRARY" },
		{ "EastGallery", 44.2, 17.0, "LIBRARY" },
		{ "Crossing", 38.2, 13.0, "SUNDIAL" },
		{ "MoonSW", 31.2, 19.0, "MOON" },
		{ "MoonSE", 31.2, 21.0, "MOON" },
		{ "MoonW", 30.2, 24.0, "RING" },
		{ "MoonE", 30.2, 26.0, "RING" },
		{ "OuterNW", 33.2, 29.0, "GLOBE" },
		{ "OuterNE", 33.2, 31.0, "GLOBE" },
		{ "MiddleW", 33.2, 33.0, "LECTERN" },
		{ "MiddleE", 33.2, 36.0, "LECTERN" },
		{ "Aphelion", 33.2, 38.0, "FROST" },
		{ "Apex", 64.2, 46.0, "SUN_DAIS" },
	}

	for _, row in circularIsles do
		local id: string = row[1]
		local plat = P[id]
		if not plat then continue end
		local radius: number = row[2]
		local wantDepth: number = row[3]
		local style: string = row[4]
		local isFrost = style == "FROST"
		local px, py, pz = plat.X, plat.Y, plat.Z

		-- 1. Crisp circular marble (or icy crystal) terrace cap + frieze drum + gold rim collars + floor mosaic
		ctx.group("AstralIsleDeck", function()
			local capTopOff = 0.06
			local capCol = if isFrost then FROST_ICE else MARBLE_LIGHT
			local capMat = if isFrost then Mat.Ice else Mat.Marble
			local bandCol = if isFrost then rgb(104, 162, 212) else LAPIS_DEEP
			local bandMat = if isFrost then Mat.Glacier else Mat.Marble
			local rimCol = if isFrost then FROST_TRIM else GOLD_BRIGHT
			local rimMat = if isFrost then Mat.Ice else Mat.Metal

			ctx.cyl(id .. "MarbleCap", V(px, py + capTopOff - 0.60, pz), radius, 1.2, capCol, capMat)
			ctx.cyl(id .. "FriezeBand", V(px, py - 2.35, pz), radius - 0.35, 2.5, bandCol, bandMat)
			ctx.ring(id .. "RimTop", V(px, py + capTopOff - 0.50, pz), radius + 0.30, 0.90, rimCol, rimMat, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 30)
			ctx.ring(id .. "RimBot", V(px, py - 3.55, pz), radius - 0.45, 0.72, if isFrost then rgb(124, 186, 232) else BRASS_AGED, rimMat, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 30)

			-- Distinctive floor inlays matching Image 1 (flush above cap, non-colliding)
			if style == "SUN_DAIS" then
				-- Grand golden concentric zodiac & sun-dial floor mosaic on the elevated Sun-Lectern Arena
				ctx.cyl("SunDaisInlayBand", V(px, py + 0.08, pz), radius * 0.84, 0.14, MARBLE_WARM, Mat.Marble)
				ctx.cyl("SunDaisInnerCore", V(px, py + 0.10, pz), radius * 0.54, 0.14, MARBLE_LIGHT, Mat.Marble)
				ctx.ring("SunDaisGoldOuter", V(px, py + 0.17, pz), radius * 0.84, 0.72, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 36)
				ctx.ring("SunDaisGlowMid", V(px, py + 0.18, pz), radius * 0.64, 0.48, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
				ctx.ring("SunDaisGoldInner", V(px, py + 0.19, pz), radius * 0.42, 0.52, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
				ctx.ring("SunDaisCoreRing", V(px, py + 0.20, pz), radius * 0.20, 0.40, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)
				for i = 0, 11 do
					local a = i * (math.pi / 6)
					local ray = boxAt("SunDaisSpoke", CFrame.new(V(px + math.cos(a) * radius * 0.52, py + 0.16, pz + math.sin(a) * radius * 0.52)) * CFrame.Angles(0, -a, 0), V(radius * 0.62, 0.10, 0.46), GOLD_BRIGHT, Mat.Metal)
					ray:SetAttribute("ConjunctionGlyph", true)
					safeTag(ray, "ConjunctionGlyph")
				end
			elseif style == "SUNDIAL" then
				-- Perihelion Court iconic golden engraved sundial floor mosaic (matching Image 1's center island!)
				ctx.cyl("PerihelionDialOuter", V(px, py + 0.08, pz), radius * 0.72, 0.14, rgb(214, 186, 122), Mat.Marble)
				ctx.cyl("PerihelionDialInner", V(px, py + 0.11, pz), radius * 0.48, 0.14, rgb(198, 166, 98), Mat.Metal)
				ctx.ring("PerihelionRing1", V(px, py + 0.17, pz), radius * 0.72, 0.52, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 26)
				ctx.ring("PerihelionRing2", V(px, py + 0.18, pz), radius * 0.48, 0.36, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
				for i = 0, 7 do
					local a = i * (math.pi / 4)
					boxAt("PerihelionRay", CFrame.new(V(px + math.cos(a) * radius * 0.44, py + 0.16, pz + math.sin(a) * radius * 0.44)) * CFrame.Angles(0, -a, 0), V(radius * 0.54, 0.10, 0.42), BRASS_AGED, Mat.Metal)
				end
			elseif style == "FROST" then
				-- Frosted crystalline observatory deck with glowing ice-blue starlight rings & protruding crystal shards around rim
				ctx.cyl("AphelionFrostCore", V(px, py + 0.08, pz), radius * 0.66, 0.14, rgb(176, 218, 246), Mat.Glass, 0.18)
				ctx.ring("AphelionFrostRing", V(px, py + 0.16, pz), radius * 0.66, 0.42, CYAN_GLOW, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
				for k = 0, 11 do
					local a = k * (math.pi / 6)
					local dist = radius - 1.2
					local shardH = 8 + (k % 3) * 4.5
					local sp = V(px + math.cos(a) * dist, py - 2.4 - shardH * 0.45, pz + math.sin(a) * dist)
					local shard = boxAt("AphelionIceIcicle", CFrame.new(sp) * CFrame.Angles(math.rad((k % 2 == 0) and 8 or -6), -a, math.rad(12)), V(3.8, shardH, 4.6), if k % 2 == 0 then FROST_ICE else rgb(142, 200, 238), Mat.Ice, 0.12)
					shard.Transparency = 0.10
				end
			elseif style == "LIBRARY" or style == "LECTERN" then
				ctx.cyl(id .. "ReadingTile", V(px, py + 0.08, pz), radius * 0.62, 0.12, MARBLE_WARM, Mat.Marble)
				ctx.ring(id .. "ReadingGold", V(px, py + 0.16, pz), radius * 0.62, 0.42, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
			elseif style == "MOON" then
				ctx.cyl(id .. "MoonDial", V(px, py + 0.08, pz), radius * 0.66, 0.12, LAPIS_DEEP, Mat.Marble)
				ctx.ring(id .. "MoonGold", V(px, py + 0.16, pz), radius * 0.66, 0.46, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
				ctx.ring(id .. "MoonGlow", V(px, py + 0.17, pz), radius * 0.38, 0.30, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)
			else
				ctx.ring(id .. "GoldRing", V(px, py + 0.15, pz), radius * 0.70, 0.40, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		-- 2. Full-width sculpted clockwork gearwork underside (or icy crystal cluster for Aphelion!)
		local maxAvail = math.max(9.0, (py - 3.4) - (-5.4))
		local useDepth = math.min(wantDepth, maxAvail)
		if isFrost then
			local scaleXZ = (radius * 2.04) / 32.5
			local scaleY = useDepth / 28.07
			local mu = placeKitScaled("AstralIsleUnderside", px, (py - 3.4) - useDepth, pz, 24, "StarIsleUndersideS", V(scaleXZ, scaleY, scaleXZ), FROST_UNDERSIDE_TINT, function(cf)
				ctx.cyl("AphelionIceCone", cf.Position + V(0, useDepth * 0.5, 0), radius * 0.76, useDepth, rgb(124, 184, 228), Mat.Ice)
			end)
			makeDecor(mu)
		else
			local scaleXZ = (radius * 2.04) / 48.48
			local scaleY = useDepth / 34.1
			local mu = placeKitScaled("AstralIsleUnderside", px, (py - 3.4) - useDepth, pz, (px * 0.5 + pz * 0.4) % 360, "OrreryGearUnderside", V(scaleXZ, scaleY, scaleXZ), GEAR_UNDERSIDE_TINT, function(cf)
				ctx.cyl(id .. "GearCone", cf.Position + V(0, useDepth * 0.5, 0), radius * 0.78, useDepth, LAPIS_DEEP, Mat.Slate)
			end)
			makeDecor(mu)
			-- Extra oversized brass cogwheels protruding cleanly beneath Apex (matching Image 1's grand centerpiece gearwork!)
			if style == "SUN_DAIS" then
				ctx.group("AstralIsleUnderside", function()
					for _, g in {
						{ 0, py - 10.5, radius * 0.72, 18.0, 0 },
						{ -radius * 0.60, py - 15.0, radius * 0.42, 14.0, 52 },
						{ radius * 0.60, py - 15.0, radius * 0.42, 14.0, -52 },
						{ -radius * 0.65, py - 12.0, -radius * 0.35, 15.0, 120 },
						{ radius * 0.65, py - 12.0, -radius * 0.35, 15.0, -120 },
					} do
						local gp = V(px + g[1], g[2], pz + g[3])
						local grot = CFrame.Angles(0, math.rad(g[5]), 0)
						ctx.ring("ApexUnderCog", gp, g[4], 2.2, GOLD_BRIGHT, Mat.Metal, grot, 0, math.pi * 2, 16)
						ctx.ring("ApexUnderCogInner", gp, g[4] * 0.55, 1.4, BRASS_AGED, Mat.Metal, grot, 0, math.pi * 2, 12)
					end
					makeDecor(ctx.current())
					pin(ctx.current())
				end)
			end
		end

		-- 3. Classical marble-and-gold perimeter balustrades (automatically gapped cleanly at EVERY bridge & alcove bay!)
		local openings: { { number } } = {}
		for _, ba in bridgeAnglesByPlat[id] or {} do
			local halfSpan = math.asin(math.clamp((ba[2] * 0.5 + 3.8) / radius, 0.20, 0.78))
			table.insert(openings, { ba[1], halfSpan })
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
			local segs = if radius >= 55 then 40 else 28
			local step = (math.pi * 2) / segs
			local rimR = radius - 0.9
			local balPlinthCol = if isFrost then FROST_ICE else MARBLE_LIGHT
			local balPlinthMat = if isFrost then Mat.Ice else Mat.Marble
			local balRailCol = if isFrost then FROST_TRIM else GOLD_BRIGHT
			local balRailMat = if isFrost then Mat.Ice else Mat.Metal
			local fenceColliders: { BasePart } = {}
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
				boxAt("IsleBalPlinth", cf * CFrame.new(0, 0.5, 0), V(1.15, 0.95, segLen), balPlinthCol, balPlinthMat)
				boxAt("IsleBalRail", cf * CFrame.new(0, 2.85, 0), V(0.88, 0.45, segLen), balRailCol, balRailMat)
				boxAt("IsleBalPost", cf * CFrame.new(0, 1.75, 0), V(0.65, 1.9, 0.65), if isFrost then FROST_ICE else MARBLE_WARM, balPlinthMat)
				local col = boxAt("IsleBalCollider", cf * CFrame.new(0, 1.8, 0), V(1.2, 3.6, segLen + 0.2), balPlinthCol, balPlinthMat, 1)
				table.insert(fenceColliders, col)
				local prevOpen = isOpenAngle(aMid - step)
				local nextOpen = isOpenAngle(aMid + step)
				if prevOpen then
					boxAt("IsleNewel", CFrame.new(p0 + V(0, 1.8, 0)), V(1.5, 3.5, 1.5), balPlinthCol, balPlinthMat)
					lump("IsleNewelOrb", p0 + V(0, 4.05, 0), V(1.4, 1.4, 1.4), GOLD_BRIGHT, Mat.Metal)
				end
				if nextOpen then
					boxAt("IsleNewel", CFrame.new(p1 + V(0, 1.8, 0)), V(1.5, 3.5, 1.5), balPlinthCol, balPlinthMat)
					lump("IsleNewelOrb", p1 + V(0, 4.05, 0), V(1.4, 1.4, 1.4), GOLD_BRIGHT, Mat.Metal)
				end
			end
			makeDecor(ctx.current())
			for _, c in fenceColliders do
				c.CanCollide = true
				c.CanQuery = true
			end
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- C. THE ORRERY PLINTH (Basin: X=0, Y=0, Z=198, W=628, D=92)
	-- Matches Image 1's iconic foreground terrace: cream-marble central walkway
	-- descending from The Orrery Gate, flanked by slate-blue tiled side wings with
	-- golden cornices, half-sunk brass gears, and perimeter marble-and-gold balustrades!
	-- =========================================================================
	local basin = P.Basin
	if basin then
		ctx.group("AstralConcourseDeck", function()
			local bx, by, bz = basin.X, basin.Y, basin.Z
			local bw, bd = basin.Width, basin.Depth
			local halfW, halfD = bw * 0.5, bd * 0.5

			-- Crisp vellum-white marble base deck cap & deep slate-blue masonry retaining wall down into the Nebula Sea
			boxAt("PlinthMarbleFloor", CFrame.new(V(bx, by - 0.48, bz)), V(bw + 4, 1.12, bd), MARBLE_LIGHT, Mat.Marble)
			boxAt("PlinthRetainingSkirt", CFrame.new(V(bx, by - 3.45, bz)), V(bw + 2, 4.9, bd - 0.4), SLATE_BLUE_DARK, Mat.Slate)
			-- Gleaming golden trim cornices framing all four edges of the Plinth
			boxAt("PlinthGoldCorniceN", CFrame.new(V(bx, by - 0.60, bz - halfD - 0.15)), V(bw + 5, 0.90, 1.0), GOLD_BRIGHT, Mat.Metal)
			boxAt("PlinthGoldCorniceS", CFrame.new(V(bx, by - 0.60, bz + halfD + 0.15)), V(bw + 5, 0.90, 1.0), GOLD_BRIGHT, Mat.Metal)
			for _, sx in { -1, 1 } do
				boxAt("PlinthGoldCorniceSide", CFrame.new(V(bx + sx * (halfW + 2.1), by - 0.60, bz)), V(1.0, 0.90, bd + 1.2), GOLD_BRIGHT, Mat.Metal)
			end

			-- Flanking slate-blue tiled side wings sized cleanly to Basin's width!
			local wingW = math.max(120, halfW - 50)
			for _, sx in { -1, 1 } do
				local wingCx = bx + sx * (44 + wingW * 0.5)
				boxAt("PlinthBlueWing", CFrame.new(V(wingCx, by + 0.11, bz)), V(wingW, 0.14, bd - 10), SLATE_BLUE, Mat.Slate)
				-- Gold borders & subtle tile grid seams framing each blue side wing
				for _, sz in { -1, 1 } do
					boxAt("PlinthWingGoldZ", CFrame.new(V(wingCx, by + 0.19, bz + sz * (bd - 10) * 0.5)), V(wingW + 1.2, 0.12, 0.75), GOLD_BRIGHT, Mat.Metal)
				end
				for _, ex in { -1, 1 } do
					boxAt("PlinthWingGoldX", CFrame.new(V(wingCx + ex * wingW * 0.5, by + 0.19, bz)), V(0.75, 0.12, bd - 8.8), GOLD_BRIGHT, Mat.Metal)
				end
			end

			-- Central cream-marble ceremonial runner from Sanctuary stairs straight to Perihelion bridge
			boxAt("PlinthCenterRunner", CFrame.new(V(bx, by + 0.12, bz)), V(84, 0.14, bd - 6), MARBLE_LIGHT, Mat.Marble)
			for _, sx in { -1, 1 } do
				boxAt("PlinthRunnerGold", CFrame.new(V(bx + sx * 42, by + 0.20, bz)), V(0.85, 0.12, bd - 5), GOLD_BRIGHT, Mat.Metal)
			end
			-- Golden brass astrolabe medallion inlaid in the center of the Plinth walkway
			ctx.ring("PlinthMedallionOuter", V(bx, by + 0.22, bz), 18.0, 0.45, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
			ctx.ring("PlinthMedallionInner", V(bx, by + 0.23, bz), 10.0, 0.30, GLOW_GOLD, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 18)

			-- Cream marble grand stair tread dressing along Sanctuary -> Basin ramp (Z=278..244, Y=8..0)
			local steps = 10
			for s = 1, steps do
				local t = (s - 0.5) / steps
				local sy = 8.0 * (1 - t)
				local sz = 278.0 + (244.0 - 278.0) * t
				boxAt("ArrivalMarbleStep", CFrame.new(V(0, sy - 0.15, sz)), V(28.0, 0.50, 3.6), if s % 2 == 0 then MARBLE_LIGHT else MARBLE_WARM, Mat.Marble)
				boxAt("ArrivalStepGold", CFrame.new(V(0, sy + 0.12, sz - 1.70)), V(27.6, 0.14, 0.35), GOLD_BRIGHT, Mat.Metal)
			end

			-- Classical marble-and-gold balustrades along all Plinth edges (exact gaps for the 3 straight bridges!)
			local fenceColliders: { BasePart } = {}
			local function balustradeSpan(x0: number, z0: number, x1: number, z1: number)
				local a, b = V(x0, by, z0), V(x1, by, z1)
				local len = (b - a).Magnitude
				if len < 4 then return end
				local mid = (a + b) * 0.5
				local cf = CFrame.lookAt(mid, b)
				boxAt("PlinthBalPlinth", cf * CFrame.new(0, 0.55, 0), V(1.3, 1.1, len), MARBLE_LIGHT, Mat.Marble)
				boxAt("PlinthBalRail", cf * CFrame.new(0, 3.10, 0), V(0.95, 0.45, len), GOLD_BRIGHT, Mat.Metal)
				local col = boxAt("PlinthBalCollider", cf * CFrame.new(0, 1.8, 0), V(1.35, 3.6, len + 0.4), MARBLE_LIGHT, Mat.Marble, 1)
				table.insert(fenceColliders, col)
				local posts = math.max(2, math.floor(len / 9))
				for i = 0, posts do
					local pt = a:Lerp(b, i / posts)
					local isEnd = (i == 0 or i == posts)
					boxAt("PlinthBalPost", CFrame.new(pt + V(0, if isEnd then 1.9 else 1.8, 0)), V(if isEnd then 1.8 else 0.75, if isEnd then 3.8 else 2.1, if isEnd then 1.8 else 0.75), MARBLE_LIGHT, Mat.Marble)
					if isEnd then
						lump("PlinthBalOrb", pt + V(0, 4.3, 0), V(1.5, 1.5, 1.5), GOLD_BRIGHT, Mat.Metal)
					end
				end
			end

			-- Auto-gap north balustrade around the 3 straight outgoing bridges (X = -222, 0, +222)
			local northZ = bz - halfD + 0.9
			local gaps: { { number } } = {}
			for _, link in ctx.layout.Links do
				if link.From == "Basin" or link.To == "Basin" then
					local ax = if link.From == "Basin" then link.AX else link.BX
					local bz2 = if link.From == "Basin" then link.BZ else link.AZ
					if bz2 < bz then
						local halfOpen = link.Width * 0.5 + 0.6
						table.insert(gaps, { ax - halfOpen, ax + halfOpen })
					end
				end
			end
			table.sort(gaps, function(g1, g2) return g1[1] < g2[1] end)
			local curX = -halfW + 8
			for _, g in gaps do
				if g[1] - curX >= 6 then
					balustradeSpan(curX, northZ, g[1], northZ)
				end
				curX = math.max(curX, g[2])
			end
			if (halfW - 8) - curX >= 6 then
				balustradeSpan(curX, northZ, halfW - 8, northZ)
			end

			-- South, West, and East Plinth balustrades (gapped around Sanctuary arrival stair X=[-24..+24])
			local southZ = bz + halfD - 1.1
			balustradeSpan(-halfW + 8, southZ, -26, southZ)
			balustradeSpan(26, southZ, halfW - 8, southZ)
			balustradeSpan(-halfW + 1.5, northZ + 6, -halfW + 1.5, southZ - 6)
			balustradeSpan(halfW - 1.5, northZ + 6, halfW - 1.5, southZ - 6)

			-- Warm golden braziers framing the Sanctuary arrival stair foot & Plinth corners
			local brazX = halfW - 10
			for _, bp in {
				V(-26, by, southZ - 1.5), V(26, by, southZ - 1.5),
				V(-brazX, by, northZ + 3), V(brazX, by, northZ + 3),
			} do
				buildBrazier(bp, 1.0, false)
			end

			makeDecor(ctx.current())
			for _, c in fenceColliders do
				c.CanCollide = true
				c.CanQuery = true
			end
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- D. LANDMARKS (1..19) — ALL 100% GROUNDED, COHERENT & TRUE TO IMAGE 1
	-- =========================================================================

	-- 1–2. Colossal Tall Armillary Sphere seated flush on The Sun-Lectern (Apex Y=44) + Radiant Sun Core!
	do
		local lm = AstralFloor42.Landmarks[1]
		local ly = lm.Y :: number
		local m = piece("AstralOrbitRail", lm.X, lm.Z, 0, "ArmillarySphereTall", 1.0, HALCYR_42, function(cf)
			for i = 1, 3 do
				ctx.ring("ArmillaryArc", cf.Position + V(0, 74, 0), 50 + i * 3, 2.2, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(0.35 * i, 0.6 * i, 0), 0, math.pi * 2, 24)
			end
			lump("ArmillarySunCore", cf.Position + V(0, 76, 0), V(24, 24, 24), GLOW_GOLD, Mat.Neon)
		end, ly)
		pin(m)
		noCollide(m)
		if m then addLight(H.glowOf(m), GOLD_LIGHT, 2.8, 140) end

		-- Radiant golden Sun-Lectern halo + warm crown lighting shining from the Armillary's heart!
		ctx.group("AstralSanctumRays", function()
			local sunCenter = V(lm.X, ly + 84, lm.Z)
			local halo = lump("SunCoreAura", sunCenter, V(30, 30, 30), GLOW_GOLD, Mat.Neon)
			halo.Transparency = 0.58
			addLight(halo, GOLD_LIGHT, 2.8, 150)
			-- 4 warm golden braziers ringing Apex's balustrade clear of both staircases & portals!
			for _, bp in {
				V(-44, ly, -30), V(44, ly, -30),
				V(-44, ly, -110), V(44, ly, -110),
			} do
				buildBrazier(bp, 1.2, false)
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 3. The Orrery Gate arch straddling arrival on Sanctuary's front threshold (0, 8, 278)
	do
		local lm = AstralFloor42.Landmarks[3]
		local m = piece("AstralGateRing", lm.X, lm.Z, 0, "OrreryGateArch", 1.0, HALCYR_42, function(cf)
			ctx.ring("OrreryGateArc", cf.Position + V(0, 16, 0), 20, 2.2, BRASS_AGED, Mat.Metal, nil, 0, math.pi, 14)
		end, lm.Y)
		pin(m)
		noCollide(m)
		if m then addLight(H.glowOf(m), GOLD_LIGHT, 1.5, 54) end
	end

	-- 4–7. Folio & Codex Circular Reading Library Islands (integrated outer marble reading bays + 3 curved RingBookcases + PlanetGlobe + floating open books!)
	for _, spec in {
		{ lmBook = AstralFloor42.Landmarks[4], lmGlobe = AstralFloor42.Landmarks[6], plat = P.WestGallery, bayX = -244, bayZ = 32, side = -1, pTint = PLANET_TINTS[1] },
		{ lmBook = AstralFloor42.Landmarks[5], lmGlobe = AstralFloor42.Landmarks[7], plat = P.EastGallery, bayX = 244, bayZ = 32, side = 1, pTint = PLANET_TINTS[2] },
	} do
		local plat = spec.plat
		if not plat then continue end
		local py = plat.Y
		local bx, bz = spec.bayX, spec.bayZ
		local side = spec.side
		-- Seamless circular marble reading alcove bay merged cleanly into the island's outer rim!
		buildOrreryBay(bx, py, bz, 28.0, 16.0)

		-- Curved wooden bookcase wall hugging the outer rim of the reading bay (3 cohesive curved sections facing INWARD, 100% on marble!)
		local baseAng = if side < 0 then math.pi else 0
		for bIdx, degOff in { 0, -34, 34 } do
			local a = baseAng + math.rad(degOff)
			local rx = bx + math.cos(a) * 16.5
			local rz = bz + math.sin(a) * 16.5
			-- RingBookcase shelves face -Z in local space, so +180 faces the open bookshelves cleanly inward toward the reading room!
			local inwardYaw = math.deg(math.atan2(plat.X - rx, plat.Z - rz)) + 180
			local name = if bIdx == 1 then spec.lmBook.Id else (spec.lmBook.Id .. "_" .. bIdx)
			local mb = piece(name, rx, rz, inwardYaw, "RingBookcase", 0.88, HALCYR_42, function(cf)
				boxAt("RingShelf", cf * CFrame.new(0, 5.5, 0), V(20, 11, 5), HALCYR_42.WOOD.Color, Mat.Wood)
			end, py)
			pin(mb)
			if bIdx > 1 then tagDetail(mb) end
		end

		-- Department Planet Globe mast grounded solidly on the reading bay's south rim (Image 1!)
		local gl = spec.lmGlobe
		local mp = piece(gl.Id, gl.X, gl.Z, if side < 0 then 35 else -35, "PlanetGlobe", 1.15, spec.pTint, function(cf)
			ctx.cyl("PlanetMast", cf.Position + V(0, 10, 0), 1.0, 20, BRASS_AGED, Mat.Metal)
			lump("PlanetSphere", cf.Position + V(0, 20, 0), V(9, 9, 9), spec.pTint.ALT.Color, Mat.Marble)
		end, gl.Y)
		pin(mp)

		-- Book stacks & whimsical floating open tomes right above the curved shelves (Image 1 detail!)
		ctx.group("AstralLibraryDetails", function()
			buildGroundBookStack(V(bx - side * 4, py, bz + 12), 4, side + 3)
			buildFloatingOpenBook(V(bx + side * 12, py + 15.5, bz - 10), side * 40, 1.0)
			buildFloatingOpenBook(V(bx + side * 16, py + 18.0, bz + 6), -side * 25, 0.9)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 8–9. Folio & Codex Moon Phase Discs (grounded cleanly on MoonSW & MoonSE south medallion bays, facing Sanctuary!)
	for _, spec in {
		{ AstralFloor42.Landmarks[8], 12, -110, 52 },
		{ AstralFloor42.Landmarks[9], -12, 110, 52 },
	} do
		local lm = spec[1]
		local ly = lm.Y :: number
		buildOrreryBay(spec[3], ly, spec[4], 14.5, 16.0)
		local md = piece(lm.Id, lm.X, lm.Z, spec[2], "MoonPhaseDisc", 0.96, HALCYR_42, function(cf)
			ctx.cyl("MoonDisc", cf.Position + V(0, 7.0, 0), 5.6, 1.6, GOLD_BRIGHT, Mat.Metal)
		end, ly)
		pin(md)
		if md then addLight(H.glowOf(md), GOLD_LIGHT, 1.1, 38) end
	end

	-- 10–11. Glossary & Marginalia Book Stacks (grounded cleanly on integrated outer stack bays!)
	for idx, lm in { AstralFloor42.Landmarks[10], AstralFloor42.Landmarks[11] } do
		local side = if idx == 1 then -1 else 1
		local py = lm.Y :: number
		buildOrreryBay(side * 294, py, -74, 17.5, 22.0)
		local ms = piece(lm.Id, lm.X, lm.Z, side * 25, "MarginaliaStack", 1.0, HALCYR_42, function(cf)
			boxAt("SlipBoxes", cf * CFrame.new(0, 3.6, 0), V(9, 7.2, 6), HALCYR_42.WOOD.Color, Mat.Wood)
		end, py)
		pin(ms)
		tagDetail(ms)
		-- Companion book stack & floating open books tucked neatly inside the bay (100% grounded!)
		local ms2 = piece(lm.Id .. "_Twin", side * 288, -83, -side * 40, "MarginaliaStack", 0.72, HALCYR_42, function(cf)
			boxAt("SlipBoxes2", cf * CFrame.new(0, 2.8, 0), V(6.5, 5.6, 4.5), HALCYR_42.WOOD.Color, Mat.Wood)
		end, py)
		pin(ms2)
		tagDetail(ms2)
		ctx.group("AstralStackBooks", function()
			buildFloatingOpenBook(V(lm.X, py + 12.5, lm.Z - 4), side * 30, 0.95)
			buildFloatingOpenBook(V(side * 286, py + 14.8, -70), -side * 20, 0.85)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 12. Atlas Globe Stand & Map Chests (grounded on OuterNW's integrated NW alcove bay + Jade PlanetGlobe!)
	do
		local at = AstralFloor42.Landmarks[12]
		local ay = at.Y :: number
		buildOrreryBay(-214, ay, -246, 24.5, 28.0)
		local mg = piece(at.Id, at.X, at.Z, 42, "GlobeStand", 1.0, HALCYR_42, function(cf)
			boxAt("AtlasGlobe", cf * CFrame.new(0, 7.5, 0), V(16, 15, 9), HALCYR_42.WOOD.Color, Mat.Wood)
		end, ay)
		pin(mg)
		local mp = piece("PlanetGlobeAtlas", -227, -236, 55, "PlanetGlobe", 0.92, PLANET_TINTS[3], function(cf)
			ctx.cyl("PlanetMast", cf.Position + V(0, 9, 0), 0.9, 18, BRASS_AGED, Mat.Metal)
			lump("PlanetSphere", cf.Position + V(0, 18, 0), V(8, 8, 8), PLANET_TINTS[3].ALT.Color, Mat.Marble)
		end, ay)
		pin(mp)
		noCollide(mp)
		ctx.group("AtlasBooks", function()
			buildFloatingOpenBook(V(-212, ay + 16.5, -246), 35, 0.95)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 13. Almanac Star-Table Slates / Astral Mirrors (grounded on OuterNE's integrated NE alcove bay + Ochre PlanetGlobe!)
	do
		local al = AstralFloor42.Landmarks[13]
		local ay = al.Y :: number
		buildOrreryBay(214, ay, -246, 24.5, 30.0)
		local ms = piece(al.Id, al.X, al.Z, -42, "StarTableSlate", 1.0, HALCYR_42, function(cf)
			boxAt("StarSlate", cf * CFrame.new(0, 6.5, 0), V(16, 13, 4), LAPIS_DEEP, Mat.Slate)
		end, ay)
		pin(ms)
		local mp = piece("PlanetGlobeAlmanac", 227, -236, -55, "PlanetGlobe", 0.92, PLANET_TINTS[4], function(cf)
			ctx.cyl("PlanetMast", cf.Position + V(0, 9, 0), 0.9, 18, BRASS_AGED, Mat.Metal)
			lump("PlanetSphere", cf.Position + V(0, 18, 0), V(8, 8, 8), PLANET_TINTS[4].ALT.Color, Mat.Marble)
		end, ay)
		pin(mp)
		noCollide(mp)
		ctx.group("AlmanacBooks", function()
			buildFloatingOpenBook(V(212, ay + 15.5, -246), -35, 0.95)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 14–15. Lexicon & Concordance Lectern Islands (integrated reading bays + curved LecternRows facing the Sun!)
	for _, spec in {
		{ lm = AstralFloor42.Landmarks[14], bayX = -172, bayZ = -110, side = -1, yaw = 90, extraX = -138, extraZ = -128, extraYaw = 32, pTint = PLANET_TINTS[6] },
		{ lm = AstralFloor42.Landmarks[15], bayX = 172, bayZ = -110, side = 1, yaw = -90, extraX = 138, extraZ = -128, extraYaw = -32, pTint = PLANET_TINTS[6] },
	} do
		local lm = spec.lm
		local ly = lm.Y :: number
		buildOrreryBay(spec.bayX, ly, spec.bayZ, 22.0, 32.0)
		local ml1 = piece(lm.Id, lm.X, lm.Z, spec.yaw, "LecternRow", 1.0, HALCYR_42, function(cf)
			boxAt("LecternBank", cf * CFrame.new(0, 3.2, 0), V(13, 6.4, 3.4), HALCYR_42.WOOD.Color, Mat.Wood)
		end, ly)
		pin(ml1)
		-- Companion LecternRow on the island's inner north arc (100% grounded on marble, matching Image 1's ring of lecterns!)
		local ml2 = piece(lm.Id .. "_North", spec.extraX, spec.extraZ, spec.extraYaw, "LecternRow", 0.90, HALCYR_42, function(cf)
			boxAt("LecternBankN", cf * CFrame.new(0, 3.0, 0), V(11, 6.0, 3.2), HALCYR_42.WOOD.Color, Mat.Wood)
		end, ly)
		pin(ml2)
		tagDetail(ml2)
		ctx.group("LecternFloatingBooks", function()
			buildFloatingOpenBook(V(lm.X, ly + 10.2, lm.Z - 4), spec.yaw, 0.9)
			buildFloatingOpenBook(V(spec.extraX, ly + 9.6, spec.extraZ), spec.extraYaw, 0.85)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 16. The Aphelion Icy Observatory Telescope + Frost PlanetGlobe (100% grounded on Aphelion's integrated frost observatory bay!)
	do
		local lm = AstralFloor42.Landmarks[16]
		local ly = lm.Y :: number
		-- Seamless frosty crystalline northern observatory bay merged into Aphelion
		ctx.group("AstralIsleDeck", function()
			ctx.cyl("AphelionBayCap", V(0, ly - 0.54, -296), 21.5, 1.2, FROST_ICE, Mat.Ice)
			ctx.cyl("AphelionBayBand", V(0, ly - 2.25, -296), 21.1, 2.4, rgb(104, 162, 212), Mat.Glacier)
			ctx.ring("AphelionBayRim", V(0, ly - 0.52, -296), 21.8, 0.78, FROST_TRIM, Mat.Ice, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 22)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
		local mu = placeKitScaled("AstralIsleUnderside", 0, (ly - 3.2) - 24.0, -296, 48, "StarIsleUndersideS", V(43.5 / 32.5, 24.0 / 28.07, 43.5 / 32.5), FROST_UNDERSIDE_TINT, function(cf)
			ctx.cyl("AphelionBayIceCone", cf.Position + V(0, 12, 0), 16, 24, rgb(124, 184, 228), Mat.Ice)
		end)
		makeDecor(mu)

		local mt = piece(lm.Id, lm.X, lm.Z, 18, "AphelionTelescope", 1.12, PLANET_TINTS[5], function(cf)
			boxAt("FrostScope", cf * CFrame.new(0, 6, 0), V(8, 12, 10), PLANET_TINTS[5].METAL.Color, Mat.Metal)
		end, ly)
		pin(mt)
		if mt then addLight(H.glowOf(mt), FROST_LIGHT, 1.5, 52) end

		local mp = piece("PlanetGlobeAphelion", -14, -298, 30, "PlanetGlobe", 0.95, PLANET_TINTS[5], function(cf)
			ctx.cyl("PlanetMast", cf.Position + V(0, 9, 0), 0.9, 18, BRASS_AGED, Mat.Metal)
			lump("PlanetSphere", cf.Position + V(0, 18, 0), V(8, 8, 8), PLANET_TINTS[5].ALT.Color, Mat.Ice)
		end, ly)
		pin(mp)
		noCollide(mp)
		ctx.group("AphelionBooks", function()
			buildGroundBookStack(V(13, ly, -296), 5, 9)
			buildFloatingOpenBook(V(12, ly + 11.0, -295), -25, 0.95)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 17. Perihelion Court Brass Sundial (grounded cleanly on Crossing's integrated northern marble dais bay, clear of camp!)
	do
		local lm = AstralFloor42.Landmarks[17]
		local ly = lm.Y :: number
		buildOrreryBay(0, ly, 36, 20.5, 13.0)
		local ms = piece(lm.Id, lm.X, lm.Z, 0, "SundialBrass", 1.05, HALCYR_42, function(cf)
			ctx.cyl("SundialBase", cf.Position + V(0, 1.4, 0), 8.5, 2.8, BRASS_AGED, Mat.Metal)
		end, ly)
		pin(ms)
		if ms then addLight(H.glowOf(ms), GOLD_LIGHT, 1.2, 42) end
	end

	-- 18–19. Half-sunk Brass Ring Gears seated solidly on Basin's slate-blue north wings (Image 1 foreground!)
	for _, spec in {
		{ AstralFloor42.Landmarks[18], -1 },
		{ AstralFloor42.Landmarks[19], 1 },
	} do
		local lm = spec[1]
		local side = spec[2]
		local mg = piece(lm.Id, lm.X, lm.Z, 0, "RingGearHalf", 1.05, HALCYR_42, function(cf)
			boxAt("PlinthGear", cf * CFrame.new(0, 5, 0), V(20, 10, 6), BRASS_AGED, Mat.Metal)
		end, lm.Y)
		pin(mg)
		-- Companion smaller half-gear angled beside it on the slate-blue wing (matching Image 1's paired Plinth gears!)
		local mg2 = piece(lm.Id .. "_Small", lm.X + side * 24, lm.Z + 12, side * -18, "RingGearHalf", 0.68, HALCYR_42, function(cf)
			boxAt("PlinthGearSm", cf * CFrame.new(0, 3.5, 0), V(14, 7, 4.5), BRASS_AGED, Mat.Metal)
		end, lm.Y)
		pin(mg2)
		tagDetail(mg2)
	end

	-- =========================================================================
	-- E. GRAND CONCENTRIC BRASS ORBIT RINGS & COGWHEELS FRAMING THE HORIZON (Image 1!)
	-- Radius 395..445 passes cleanly BEHIND Sanctuary (Z=+325..+375) so ZERO yellow bar
	-- ever blocks the player's arrival sightline to the Sun-Lectern Armillary Sphere,
	-- while wrapping majestically around the left, north, and right cosmic skyline!
	-- =========================================================================
	ctx.group("AstralOrbitRail", function()
		local ringTilt = CFrame.Angles(math.pi / 2 + math.rad(4.5), 0, 0)
		for idx, orbit in {
			{ R = 392, Y = 66, Thick = 3.2 },
			{ R = 418, Y = 78, Thick = 3.6 },
			{ R = 446, Y = 90, Thick = 4.0 },
		} do
			ctx.ring("OuterOrreryBand_" .. idx, V(0, orbit.Y, -70), orbit.R, orbit.Thick, GOLD_BRIGHT, Mat.Metal, ringTilt, 0, math.pi * 2, 72)
			ctx.ring("OuterOrreryUnderRim_" .. idx, V(0, orbit.Y - 2.4, -70), orbit.R, orbit.Thick * 0.60, BRASS_AGED, Mat.Metal, ringTilt, 0, math.pi * 2, 72)
		end
		-- Ornamental horizontal brass cogwheels riding the outer orbit rings (matching Image 1's floating ring cogs!)
		for _, g in {
			{ -170, 114, -448, 22 }, { 215, 102, -408, 19 },
			{ -380, 74, -180, 17 }, { 382, 74, -172, 17 },
			{ -318, 92, -312, 16 }, { 318, 92, -312, 16 },
		} do
			ctx.ring("OrbitCogWheel", V(g[1], g[2], g[3]), g[4], 2.4, GOLD_BRIGHT, Mat.Metal, ringTilt, 0, math.pi * 2, 16)
			ctx.ring("OrbitCogWheelHub", V(g[1], g[2], g[3]), g[4] * 0.45, 1.8, BRASS_AGED, Mat.Metal, ringTilt, 0, math.pi * 2, 12)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- F. CONJUNCTION INDEX LAMPS (tucked along island rims arching inward — never blocking lanes!)
	-- Lit only at the conjunctions & Sun approaches so lit golden lamps guide the route inward!
	-- =========================================================================
	-- { x, y, z, withLight, lookAtX, lookAtZ }
	local conjLamps = {
		{ -86, 15, 0, true, -104, 22 },          -- Folio Moon NE conjunction rim
		{ 86, 17, 0, true, 104, 22 },            -- Codex Moon NW conjunction rim
		{ -174, 25, -242, true, -198, -230 },    -- Atlas NE rim
		{ 174, 27, -242, true, 198, -230 },      -- Almanac NW rim
		{ -130, 30, -92, true, -152, -110 },     -- Lexicon stair head approach
		{ 130, 34, -92, true, 152, -110 },       -- Concordance stair head approach
		{ -52, 44, -94, true, 0, -70 },          -- Sun-Lectern NW approach
		{ 52, 44, -94, true, 0, -70 },           -- Sun-Lectern NE approach
	}
	for _, sp in conjLamps do
		local inwardYaw = math.deg(math.atan2(sp[5] - sp[1], sp[6] - sp[3]))
		local ml = piece("AstralIndexLamp", sp[1], sp[3], inwardYaw, "IndexLamp", 1.05, HALCYR_42, function(cf)
			ctx.cyl("LampPost", cf.Position + V(0, 6, 0), 0.7, 12, BRASS_AGED, Mat.Metal)
			lump("LampBulb", cf.Position + V(0, 11.5, 0), V(2.2, 2.8, 2.2), GLOW_GOLD, Mat.Neon)
		end, sp[2])
		pin(ml)
		tagDetail(ml)
		if ml then
			ml:SetAttribute("ConjunctionLamp", true)
			safeTag(ml, "ConjunctionLamp")
			if sp[4] then addLight(H.glowOf(ml), GOLD_LIGHT, 1.35, 44) end
		end
	end

	-- =========================================================================
	-- G. HAIRLINE VIOLET RIFT TEAR IN THE HIGH NORTH SKY (Image 1!)
	-- =========================================================================
	ctx.group("AstralSkyHairlineRift", function()
		local pts = {
			V(24, 176, -268), V(56, 196, -276), V(46, 214, -280), V(84, 232, -288), V(112, 254, -296), V(148, 274, -304),
		}
		for i = 1, #pts - 1 do
			local seg = ctx.beam("HairlineRiftCrack", pts[i], pts[i + 1], if i == 3 then 2.8 else 1.6, rgb(186, 124, 255), Mat.Neon, 0.06)
			seg:SetAttribute("ConjunctionGlyph", true)
			safeTag(seg, "ConjunctionGlyph")
			local glow = ctx.beam("HairlineRiftGlow", pts[i], pts[i + 1], if i == 3 then 7.2 else 4.6, rgb(134, 78, 238), Mat.Neon, 0.68)
			glow:SetAttribute("ConjunctionGlyph", true)
			safeTag(glow, "ConjunctionGlyph")
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Floating tomes orbiting the Sun-Lectern spire (purely cosmetic, well above walk surface!)
	local tomes = piece("AstralOrbitTomes", 0, -70, 20, "FloatingTomeCluster", 1.85, HALCYR_42, function(cf)
		for i = 1, 6 do
			local a = i * math.pi * 2 / 6
			boxAt("SunOrbitTome", cf * CFrame.new(math.cos(a) * 26, 2 + (i % 3) * 3.0, math.sin(a) * 26), V(3.8, 0.9, 2.8), HALCYR_42.SILK.Color, Mat.Fabric)
		end
	end, 78)
	pin(tomes)
	makeDecor(tomes)

	pageEmitter(V(-152, 36, -110), 3)
	pageEmitter(V(152, 40, -110), 3)
	pageEmitter(V(0, 52, -70), 4)
	pageEmitter(V(-222, 16, 26), 2)
	pageEmitter(V(222, 18, 26), 2)

	ctx.setAttribute("AstralFloor", 42)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor42
