--!strict
-- Hand-authored set pieces for Astral Archives Floor 42: Orbiting Stacks (astral:2, EXPANDED_ENCOUNTER).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 42).
--
-- A working brass orrery: three concentric floating orbits round the Sun-Lectern (Apex, dead centre at Y 44),
-- crowned by a 156.5-stud tall brass Armillary Sphere high above the dais and the first hairline Rift tear
-- in the sky above the Sun.
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

-- Warm brass noon Halcyr palette (pale starlight gold glow, hue ~45°, sat ~0.38 — never orange/red).
local HALCYR_42 = table.freeze({
	STONE = swatch(224, 216, 198, Mat.Limestone),
	ALT = swatch(38, 46, 88, Mat.Marble),
	TRIM = swatch(220, 188, 106, Mat.Metal),
	METAL = swatch(186, 150, 82, Mat.Metal),
	WOOD = swatch(52, 40, 44, Mat.Wood),
	SILK = swatch(238, 230, 210, Mat.Fabric),
	GLOW = swatch(248, 224, 156, Mat.Neon),
	CRYSTAL = swatch(138, 182, 228, Mat.Glass, 0.22),
	MOSS = swatch(108, 146, 128, Mat.Grass),
})

local PLANET_TINTS = {
	tinted(HALCYR_42, { ALT = swatch(74, 112, 168, Mat.Marble), CRYSTAL = swatch(148, 196, 236, Mat.Glass, 0.2) }), -- Folio (cerulean)
	tinted(HALCYR_42, { ALT = swatch(128, 96, 162, Mat.Marble), CRYSTAL = swatch(174, 156, 226, Mat.Glass, 0.2) }), -- Codex (amethyst-slate)
	tinted(HALCYR_42, { ALT = swatch(76, 134, 126, Mat.Marble), CRYSTAL = swatch(138, 206, 198, Mat.Glass, 0.2) }), -- Atlas (jade-teal)
	tinted(HALCYR_42, { ALT = swatch(164, 142, 92, Mat.Marble), CRYSTAL = swatch(226, 208, 152, Mat.Glass, 0.2) }), -- Almanac (ochre-gold)
	tinted(HALCYR_42, { ALT = swatch(146, 178, 214, Mat.Ice), CRYSTAL = swatch(194, 226, 250, Mat.Glass, 0.15) }), -- Aphelion (frost)
	tinted(HALCYR_42, { ALT = swatch(86, 98, 148, Mat.Marble), CRYSTAL = swatch(166, 184, 234, Mat.Glass, 0.2) }), -- Concordance (indigo)
}

local GOLD_LIGHT = rgb(248, 224, 156)
local FROST_LIGHT = rgb(196, 226, 255)

-- Floor 42's 19 landmark footprints (local floor space, 660 x 680).
AstralFloor42.Landmarks = table.freeze({
	-- 1. Armillary Sphere Tall (>= 150 studs, 156.5 studs) hovering 22 studs clear over the Sun-Lectern
	{ Id = "SunArmillarySphere", X = 0, Z = -70, Y = 66, HalfX = 56.6, HalfZ = 56.6, Top = 156.5, Straddles = true },
	-- 2. The Sun-Lectern Globe suspended dead-centre inside the Armillary Sphere (34 studs clear above Apex Y=44!)
	{ Id = "SunLecternGlobe", X = 0, Z = -70, Y = 78, HalfX = 12.4, HalfZ = 12.4, Top = 36.8, Straddles = true },
	-- 3. The Orrery Gate arch straddling arrival above Sanctuary -> Basin
	{ Id = "TheOrreryGate", X = 0, Z = 278, Y = 8, HalfX = 21.8, HalfZ = 3.5, Top = 31.8, Straddles = true },
	-- 4. Folio Ring Bookcase (outer west rim of WestGallery, clear of camp)
	{ Id = "FolioRingBookcase", X = -256, Z = 20, Y = 8, HalfX = 5.0, HalfZ = 14.4, Top = 13.6 },
	-- 5. Codex Ring Bookcase (outer east rim of EastGallery, clear of camp)
	{ Id = "CodexRingBookcase", X = 256, Z = 20, Y = 12, HalfX = 5.0, HalfZ = 14.4, Top = 13.6 },
	-- 6. Folio Planet Globe mast
	{ Id = "FolioPlanetGlobe", X = -254, Z = 56, Y = 8, HalfX = 6.6, HalfZ = 6.6, Top = 25.1 },
	-- 7. Codex Planet Globe mast
	{ Id = "CodexPlanetGlobe", X = 254, Z = 56, Y = 12, HalfX = 6.6, HalfZ = 6.6, Top = 25.1 },
	-- 8. Folio Moon Phase Disc
	{ Id = "FolioMoonPhaseDisc", X = -100, Z = 56, Y = 18, HalfX = 6.4, HalfZ = 2.0, Top = 15.0 },
	-- 9. Codex Moon Phase Disc
	{ Id = "CodexMoonPhaseDisc", X = 100, Z = 56, Y = 20, HalfX = 6.4, HalfZ = 2.0, Top = 15.0 },
	-- 10. Glossary Marginalia Stack (outer west rim of MoonW)
	{ Id = "GlossaryStack", X = -298, Z = -80, Y = 22, HalfX = 5.2, HalfZ = 4.0, Top = 7.6 },
	-- 11. Marginalia Stack (outer east rim of MoonE)
	{ Id = "MarginaliaStack", X = 298, Z = -80, Y = 24, HalfX = 5.2, HalfZ = 4.0, Top = 7.6 },
	-- 12. Atlas Globe Stand (north-west of OuterNW)
	{ Id = "AtlasGlobeStand", X = -244, Z = -256, Y = 26, HalfX = 9.6, HalfZ = 5.4, Top = 15.2 },
	-- 13. Almanac Star-Table Slate (north-east of OuterNE)
	{ Id = "AlmanacStarTable", X = 244, Z = -256, Y = 28, HalfX = 9.2, HalfZ = 2.8, Top = 13.2 },
	-- 14. Lexicon Lectern Row (west rim of MiddleW)
	{ Id = "LexiconLecternRow", X = -212, Z = -110, Y = 32, HalfX = 2.4, HalfZ = 7.2, Top = 6.6 },
	-- 15. Concordance Lectern Row (east rim of MiddleE)
	{ Id = "ConcordanceLecternRow", X = 212, Z = -110, Y = 36, HalfX = 2.4, HalfZ = 7.2, Top = 6.6 },
	-- 16. The Aphelion lone telescope (north of Aphelion, looking out into Starfield)
	{ Id = "AphelionTelescope", X = 0, Z = -308, Y = 40, HalfX = 5.4, HalfZ = 6.5, Top = 12.2 },
	-- 17. Perihelion Court Brass Sundial (north edge facing the impassable void gap toward the Sun)
	{ Id = "PerihelionSundial", X = 0, Z = 38, Y = 16, HalfX = 9.2, HalfZ = 9.2, Top = 7.0 },
	-- 18. Plinth West Ring Gear half-sunk in north rim of Orrery Plinth
	{ Id = "PlinthRingGearW", X = -126, Z = 136, Y = 0, HalfX = 10.4, HalfZ = 3.6, Top = 10.8 },
	-- 19. Plinth East Ring Gear half-sunk in north rim of Orrery Plinth
	{ Id = "PlinthRingGearE", X = 126, Z = 136, Y = 0, HalfX = 10.4, HalfZ = 3.6, Top = 10.8 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AstralFloor42.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local bottom: number, P = H.bottom, H.P
	local _boxAt, lump, light, piece, noCollide = H.boxAt, H.lump, H.light, H.piece, H.noCollide
	local function boxAt(name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, trans: number?): Part
		return _boxAt(name, size, cf, color, mat, trans)
	end

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
	local function tagDetail(m: Instance?)
		if not m then return end
		noCollide(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
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
		pe.Color = ColorSequence.new(rgb(246, 236, 206), rgb(242, 220, 152))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1.0), NumberSequenceKeypoint.new(1, 0.4) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3.5, 5.5)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1.0, 2.5)
		pe.SpreadAngle = Vector2.new(55, 55)
		pe.RotSpeed = NumberRange.new(-45, 45)
		pe.Acceleration = V(0, 0.5, 0)
		pe.Parent = anchor
	end

	for _, lm in AstralFloor42.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- 1. Colossal Tall Armillary Sphere hovering over The Sun-Lectern (already carries its blazing golden Sun core!)
	do
		local lm = AstralFloor42.Landmarks[1]
		local m = piece("AstralOrbitRail", lm.X, lm.Z, 0, "ArmillarySphereTall", 0.94, HALCYR_42, function(cf)
			for i = 1, 3 do
				ctx.ring("ArmillaryArc", cf.Position + V(0, 74, 0), 50 + i * 3, 2.2, HALCYR_42.TRIM.Color, Mat.Metal, CFrame.Angles(0.35 * i, 0.6 * i, 0), 0, math.pi * 2, 20)
			end
			lump("ArmillarySunCore", cf.Position + V(0, 76, 0), V(24, 24, 24), HALCYR_42.GLOW.Color, Mat.Neon)
		end, 46)
		pin(m)
		noCollide(m)
		if m then addLight(H.glowOf(m), GOLD_LIGHT, 2.6, 125) end
	end

	-- 2. Giant circular brass-rimmed cosmic galaxy mirror pool directly beneath the Sun on the Nebula Floor
	do
		ctx.group("AstralIsleUnderside", function()
			local poolDisc = ctx.cyl("NebulaGalaxyBasin", V(0, bottom + 0.35, -70), 222, 0.7, rgb(32, 54, 108), Mat.Glass, 0.18)
			poolDisc:SetAttribute("ConjunctionGlyph", true)
			safeTag(poolDisc, "ConjunctionGlyph")
			ctx.ring("NebulaPoolBrassRim", V(0, bottom + 1.1, -70), 225, 5.2, HALCYR_42.TRIM.Color, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 48)
			ctx.ring("NebulaPoolMidRing", V(0, bottom + 0.85, -70), 152, 2.2, HALCYR_42.GLOW.Color, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 36)
			ctx.ring("NebulaPoolInnerRing", V(0, bottom + 0.85, -70), 86, 1.6, rgb(142, 198, 252), Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
			noCollide(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 3. The Orrery Gate straddling arrival
	do
		local lm = AstralFloor42.Landmarks[3]
		local m = piece("AstralGateRing", lm.X, lm.Z, 0, "OrreryGateArch", 1.0, HALCYR_42, function(cf)
			ctx.ring("OrreryGateArc", cf.Position + V(0, 16, 0), 20, 2.2, HALCYR_42.METAL.Color, Mat.Metal, nil, 0, math.pi, 14)
		end, lm.Y)
		pin(m)
		noCollide(m)
		if m then addLight(H.glowOf(m), GOLD_LIGHT, 1.4, 52) end
	end

	-- 4–5. Folio & Codex circular reading rooms (RingBookcase)
	for _, spec in { { AstralFloor42.Landmarks[4], 90 }, { AstralFloor42.Landmarks[5], -90 } } do
		local lm = spec[1]
		pin(piece(lm.Id, lm.X, lm.Z, spec[2], "RingBookcase", 1.18, HALCYR_42, function(cf)
			boxAt("RingShelf", cf * CFrame.new(0, 6.5, 0), V(26, 13, 6), HALCYR_42.WOOD.Color, Mat.Wood)
		end, lm.Y))
	end

	-- 6–7. Department Planet Globes (6 distinct planet tints across the orrery)
	for idx, spec in {
		{ AstralFloor42.Landmarks[6], PLANET_TINTS[1] },
		{ AstralFloor42.Landmarks[7], PLANET_TINTS[2] },
	} do
		local lm = spec[1]
		local mp = piece(lm.Id, lm.X, lm.Z, idx * 45, "PlanetGlobe", 1.25, spec[2], function(cf)
			ctx.cyl("PlanetMast", cf.Position + V(0, 10, 0), 1.0, 20, HALCYR_42.METAL.Color, Mat.Metal)
			lump("PlanetSphere", cf.Position + V(0, 20, 0), V(9, 9, 9), spec[2].ALT.Color, Mat.Marble)
		end, lm.Y)
		pin(mp)
	end

	-- Extra planet globes perched off Atlas, Almanac, Aphelion & Concordance
	for i, pl in {
		{ -242, 26, -214, PLANET_TINTS[3] },
		{ 242, 28, -214, PLANET_TINTS[4] },
		{ -40, 40, -296, PLANET_TINTS[5] },
		{ 210, 36, -82, PLANET_TINTS[6] },
	} do
		local mp = piece("PlanetGlobeExtra", pl[1], pl[3], i * 60, "PlanetGlobe", 0.9, pl[4], function(cf)
			ctx.cyl("PlanetMast", cf.Position + V(0, 9, 0), 0.9, 18, HALCYR_42.METAL.Color, Mat.Metal)
			lump("PlanetSphere", cf.Position + V(0, 18, 0), V(8, 8, 8), pl[4].ALT.Color, Mat.Marble)
		end, pl[2])
		pin(mp)
		noCollide(mp)
	end

	-- 8–9. Moon Phase Discs
	for _, lm in { AstralFloor42.Landmarks[8], AstralFloor42.Landmarks[9] } do
		pin(piece(lm.Id, lm.X, lm.Z, 0, "MoonPhaseDisc", 1.0, HALCYR_42, function(cf)
			ctx.cyl("MoonDisc", cf.Position + V(0, 7.5, 0), 6, 1.8, HALCYR_42.TRIM.Color, Mat.Metal)
		end, lm.Y))
	end

	-- 10–15. Department props: Glossary, Marginalia, Atlas, Almanac, Lexicon, Concordance
	do
		for _, lm in { AstralFloor42.Landmarks[10], AstralFloor42.Landmarks[11] } do
			local ms = piece(lm.Id, lm.X, lm.Z, 20, "MarginaliaStack", 1.0, HALCYR_42, function(cf)
				boxAt("SlipBoxes", cf * CFrame.new(0, 3.6, 0), V(9, 7.2, 6), HALCYR_42.WOOD.Color, Mat.Wood)
			end, lm.Y)
			pin(ms)
			tagDetail(ms)
		end
		local at = AstralFloor42.Landmarks[12]
		pin(piece(at.Id, at.X, at.Z, 30, "GlobeStand", 1.0, HALCYR_42, function(cf)
			boxAt("AtlasGlobe", cf * CFrame.new(0, 7.5, 0), V(16, 15, 9), HALCYR_42.WOOD.Color, Mat.Wood)
		end, at.Y))
		local al = AstralFloor42.Landmarks[13]
		pin(piece(al.Id, al.X, al.Z, -30, "StarTableSlate", 1.0, HALCYR_42, function(cf)
			boxAt("StarSlate", cf * CFrame.new(0, 6.5, 0), V(16, 13, 4), HALCYR_42.ALT.Color, Mat.Slate)
		end, al.Y))
		for _, spec in { { AstralFloor42.Landmarks[14], 90 }, { AstralFloor42.Landmarks[15], -90 } } do
			local lm = spec[1]
			pin(piece(lm.Id, lm.X, lm.Z, spec[2], "LecternRow", 1.0, HALCYR_42, function(cf)
				boxAt("LecternBank", cf * CFrame.new(0, 3.2, 0), V(13, 6.4, 3.4), HALCYR_42.WOOD.Color, Mat.Wood)
			end, lm.Y))
		end
	end

	-- 16. The Aphelion lone telescope (frosted star-glass planet)
	do
		local lm = AstralFloor42.Landmarks[16]
		local mt = piece(lm.Id, lm.X, lm.Z, 0, "AphelionTelescope", 1.0, PLANET_TINTS[5], function(cf)
			boxAt("FrostScope", cf * CFrame.new(0, 6, 0), V(8, 12, 10), PLANET_TINTS[5].METAL.Color, Mat.Metal)
		end, lm.Y)
		pin(mt)
		if mt then addLight(H.glowOf(mt), FROST_LIGHT, 1.3, 46) end
	end

	-- 17. Perihelion Court Brass Sundial (faces the 74-stud impassable void gap toward the Sun)
	do
		local lm = AstralFloor42.Landmarks[17]
		local ms = piece(lm.Id, lm.X, lm.Z, 0, "SundialBrass", 1.0, HALCYR_42, function(cf)
			ctx.cyl("SundialBase", cf.Position + V(0, 1.4, 0), 8.5, 2.8, HALCYR_42.METAL.Color, Mat.Metal)
		end, lm.Y)
		pin(ms)
	end

	-- 18–19. Half-sunk Ring Gears in the Orrery Plinth's north rim
	for _, lm in { AstralFloor42.Landmarks[18], AstralFloor42.Landmarks[19] } do
		pin(piece(lm.Id, lm.X, lm.Z, 0, "RingGearHalf", 1.0, HALCYR_42, function(cf)
			boxAt("PlinthGear", cf * CFrame.new(0, 5, 0), V(20, 10, 6), HALCYR_42.METAL.Color, Mat.Metal)
		end, lm.Y))
	end

	-- Continuous Grand Concentric Brass Orbit Rings framing the entire outer starfield perimeter (matching guide art!)
	ctx.group("AstralOrbitRail", function()
		for _, orbit in {
			{ R = 304, Y = 68, Thick = 3.2 },
			{ R = 324, Y = 80, Thick = 3.6 },
			{ R = 344, Y = 92, Thick = 4.0 },
		} do
			ctx.ring("OuterOrreryBand", V(0, orbit.Y, -70), orbit.R, orbit.Thick, HALCYR_42.TRIM.Color, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 60)
			ctx.ring("OuterOrreryUnderRim", V(0, orbit.Y - 2.2, -70), orbit.R, orbit.Thick * 0.65, HALCYR_42.METAL.Color, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 60)
		end
		-- Ornamental horizontal brass cogwheels riding the outer orbit rings
		for _, g in {
			{ -150, 92, -378, 16 }, { 190, 80, -338, 14 }, { -295, 68, -210, 13 }, { 298, 68, -195, 13 },
		} do
			ctx.ring("OrbitCogWheel", V(g[1], g[2], g[3]), g[4], 2.2, HALCYR_42.TRIM.Color, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 16)
		end
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	-- Gear undersides flush beneath the Sun-Lectern, middle orbit & galleries (kit height = 34.1; top ALWAYS <= plat.Y - 1.5!)
	for _, row in {
		{ "Apex", 1.15 },
		{ "MiddleW", 0.86 },
		{ "MiddleE", 0.86 },
		{ "WestGallery", 0.92 },
		{ "EastGallery", 0.92 },
		{ "Crossing", 0.86 },
		{ "Aphelion", 0.86 },
	} do
		local plat = P[row[1]]
		if plat then
			local sc: number = row[2]
			local baseY = plat.Y - 34.1 * sc - 1.6
			local u = piece("AstralIsleUnderside", plat.X, plat.Z, 0, "OrreryGearUnderside", sc, HALCYR_42, function(cf)
				ctx.cyl("GearCone", cf.Position + V(0, 12, 0), 18 * sc, 24, HALCYR_42.METAL.Color, Mat.Metal)
			end, baseY)
			pin(u)
			noCollide(u)
			-- Brass & gold island collar rim matching the guide art
			ctx.group("AstralIsleUnderside", function()
				local rimR = math.max(plat.Width, plat.Depth) * 0.5 + 3.2
				ctx.ring("OrreryIsleCollar", V(plat.X, plat.Y - 1.4, plat.Z), rimR, 1.5, HALCYR_42.TRIM.Color, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 24)
				noCollide(ctx.current())
				pin(ctx.current())
			end)
		end
	end

	-- Conjunction Index Lamps: lit only at the four conjunctions & Sun approaches (so lit lamps show the way inward!)
	local conjLamps = {
		{ -100, 18, -8, true },  -- Folio Moon conjunction
		{ 100, 20, -8, true },   -- Codex Moon conjunction
		{ -200, 26, -202, true },-- Atlas conjunction
		{ 200, 28, -202, true }, -- Almanac conjunction
		{ -136, 32, -110, true },-- Lexicon stair head
		{ 136, 36, -110, true }, -- Concordance stair head
		{ -56, 44, -70, true },  -- Sun west
		{ 56, 44, -70, true },   -- Sun east
	}
	for i, sp in conjLamps do
		local ml = piece("AstralIndexLamp", sp[1], sp[3], i * 45, "IndexLamp", 1.0, HALCYR_42, function(cf)
			ctx.cyl("LampPost", cf.Position + V(0, 6, 0), 0.7, 12, HALCYR_42.METAL.Color, Mat.Metal)
			lump("LampBulb", cf.Position + V(0, 11.5, 0), V(2.2, 2.8, 2.2), HALCYR_42.GLOW.Color, Mat.Neon)
		end, sp[2])
		pin(ml)
		tagDetail(ml)
		if ml then
			ml:SetAttribute("ConjunctionLamp", true)
			safeTag(ml, "ConjunctionLamp")
			if sp[4] then addLight(H.glowOf(ml), GOLD_LIGHT, 1.3, 44) end
		end
	end

	-- The first jagged hairline Rift tear cracking diagonally in the high north sky above the Sun
	ctx.group("AstralSkyHairlineRift", function()
		local pts = {
			V(18, 175, -245), V(46, 194, -252), V(38, 210, -256), V(74, 228, -264), V(98, 248, -270), V(132, 268, -278),
		}
		for i = 1, #pts - 1 do
			local seg = ctx.beam("HairlineRiftCrack", pts[i], pts[i + 1], if i == 3 then 2.6 else 1.5, rgb(174, 114, 255), Mat.Neon, 0.08)
			seg:SetAttribute("ConjunctionGlyph", true)
			safeTag(seg, "ConjunctionGlyph")
		end
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	pageEmitter(V(-170, 38, -110), 3)
	pageEmitter(V(170, 42, -110), 3)
	pageEmitter(V(0, 50, -70), 4)

	ctx.setAttribute("AstralFloor", 42)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor42
