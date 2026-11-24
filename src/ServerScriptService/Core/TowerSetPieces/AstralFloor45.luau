--!strict
-- Hand-authored set pieces for Astral Archives Floor 45: Rift Warden's Observatory (astral:5, BOSS_ARENA).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 45).
--
-- The Warden's watch: a diagonal Rift torn end-to-end across the 900 x 795 floor, stitched by three shelf
-- sutures, with the slow-turning Rift Eye glowing deep in its bed, twin brass Azimuth Rings carrying the
-- last two burning gold lamps either side of the 204 x 152 Observing Floor dais, and the colossal 298-stud
-- Great Telescope framed by torn Observatory dome ribs behind the dais against a half-black sky.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AstralFloor45 = {}

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

-- Rift-eye Observatory palette: dark indigo-slate stone, weathered brass, ebony wood, cold silver-white lens
-- highlights on the dais, pale gold ONLY on the two Azimuth Ring lamps & The Last Lamp (no orange/red!),
-- and void violet strictly down in the Rift bed and sky.
local RIFTWARD_45 = table.freeze({
	STONE = swatch(166, 166, 174, Mat.Limestone),
	ALT = swatch(30, 34, 62, Mat.Marble),
	TRIM = swatch(204, 174, 100, Mat.Metal),
	METAL = swatch(164, 134, 76, Mat.Metal),
	WOOD = swatch(42, 32, 36, Mat.Wood),
	SILK = swatch(224, 218, 206, Mat.Fabric),
	GLOW = swatch(244, 224, 162, Mat.Neon),
	CRYSTAL = swatch(164, 206, 246, Mat.Glass, 0.22),
	MOSS = swatch(68, 84, 108, Mat.Grass),
})

local RIFT_EYE_TINT = tinted(RIFTWARD_45, {
	ALT = swatch(24, 14, 48, Mat.Neon),
	CRYSTAL = swatch(138, 78, 236, Mat.Glass, 0.2),
	GLOW = swatch(172, 104, 255, Mat.Neon),
	SILK = swatch(216, 198, 248, Mat.Fabric),
})

local RIFT_LIP_TINT = tinted(RIFTWARD_45, {
	CRYSTAL = swatch(148, 104, 236, Mat.Glass, 0.24),
	GLOW = swatch(166, 122, 248, Mat.Neon),
})

local SILVER_LENS_TINT = tinted(RIFTWARD_45, {
	GLOW = swatch(224, 234, 255, Mat.Neon),
	CRYSTAL = swatch(196, 222, 255, Mat.Glass, 0.16),
})

local GOLD_LIGHT = rgb(244, 224, 162)
local SILVER_LIGHT = rgb(224, 234, 255)
local VIOLET_LIGHT = rgb(154, 92, 244)

-- Floor 45's 24 landmark footprints (local floor space, 900 x 795).
-- Every non-straddling piece stays completely clear of the 204 x 152 boss dais, portals (-289), lanes and camps.
AstralFloor45.Landmarks = table.freeze({
	-- 1–2. The Great Telescope (colossal centrepiece: 106.35 + 191.4 = 297.75 >= 285 studs, behind Apex back wall!)
	{ Id = "GreatTelescopeMount", X = 0, Z = -356, Y = 68, HalfX = 30.0, HalfZ = 30.0, Top = 106.4 },
	{ Id = "GreatTelescopeTube", X = 0, Z = -334, Y = 170, HalfX = 23.0, HalfZ = 62.0, Top = 191.4, Straddles = true },
	-- 3. Open-ribbed Observatory Dome behind the Telescope mount (far-layer frame)
	{ Id = "ObservatoryDomeRibs", X = 0, Z = -342, Y = 68, HalfX = 81.5, HalfZ = 46.8, Top = 141.9, Straddles = true },
	-- 4–5. Colossal Brass Azimuth Rings straddling the West & East Ring anchor terraces (240° open arch)
	{ Id = "WestAzimuthRing", X = -205, Z = -235, Y = 56, HalfX = 18.2, HalfZ = 4.2, Top = 40.9, Straddles = true },
	{ Id = "EastAzimuthRing", X = 215, Z = -235, Y = 60, HalfX = 18.2, HalfZ = 4.2, Top = 40.9, Straddles = true },
	-- 6. The Rift Eye turning deep in the Rift bed (Y = -10, 36 studs below walk surfaces)
	{ Id = "RiftEyeVoid", X = 12, Z = -32, Y = -10, HalfX = 31.1, HalfZ = 31.7, Top = 5.3 },
	-- 7–8. Dais Outer Meridian Footings (south-west and south-east outer rims of Observing Floor, off the boss arena)
	{ Id = "MeridianFootingW", X = -88, Z = -142, Y = 68, HalfX = 19.6, HalfZ = 4.2, Top = 6.8 },
	{ Id = "MeridianFootingE", X = 88, Z = -142, Y = 68, HalfX = 19.6, HalfZ = 4.2, Top = 6.8 },
	-- 9. Rift Overlook cantilevered brass deck with overturned Grand Indexer's chair
	{ Id = "RiftOverlookDeck", X = -60, Z = -132, Y = 30, HalfX = 7.2, HalfZ = 7.8, Top = 12.7 },
	-- 10–11. West & East Transit Towers (outer flanks of WestBastion & EastBastion, >= 80 studs from camps)
	{ Id = "WestTransitTower", X = -414, Z = -80, Y = 32, HalfX = 13.0, HalfZ = 13.0, Top = 34.2 },
	{ Id = "EastTransitTower", X = 384, Z = -150, Y = 40, HalfX = 13.0, HalfZ = 13.0, Top = 34.2 },
	-- 12–13. Transit Instruments flanking the towers
	{ Id = "WestTransitInstrument", X = -410, Z = -46, Y = 32, HalfX = 5.5, HalfZ = 6.5, Top = 14.9 },
	{ Id = "EastTransitInstrument", X = 384, Z = -116, Y = 40, HalfX = 5.5, HalfZ = 6.5, Top = 14.9 },
	-- 14–15. Lens Gallery grinding benches turned toward the Rift
	{ Id = "LensGalleryBenchA", X = 112, Z = -100, Y = 36, HalfX = 5.8, HalfZ = 2.4, Top = 9.4 },
	{ Id = "LensGalleryBenchB", X = 150, Z = -20, Y = 36, HalfX = 2.4, HalfZ = 5.8, Top = 9.4 },
	-- 16. Fallen Orrery on Orrery Crest
	{ Id = "OrreryCrestFallen", X = 392, Z = -310, Y = 46, HalfX = 12.8, HalfZ = 10.8, Top = 20.8 },
	-- 17. Grand Star-Lectern open at the last page
	{ Id = "StarLecternGrand", X = -170, Z = -52, Y = 20, HalfX = 8.5, HalfZ = 8.5, Top = 10.0 },
	-- 18. Spilled Ink Pool decal on The Ink Pools
	{ Id = "InkPoolSpill", X = -165, Z = 48, Y = 16, HalfX = 7.0, HalfZ = 7.0, Top = 3.9 },
	-- 19. Fallen Catalogue toppled cabinet range
	{ Id = "FallenCatalogueRange", X = 232, Z = 136, Y = 4, HalfX = 12.8, HalfZ = 9.6, Top = 10.6 },
	-- 20. Proof Room press with the blank sheet
	{ Id = "ProofRoomPress", X = 50, Z = 96, Y = 22, HalfX = 7.0, HalfZ = 2.8, Top = 6.8 },
	-- 21–23. Crystallised Starlight Rift Lips along the diagonal tear
	{ Id = "WestRiftLipCrystal", X = -352, Z = -250, Y = 48, HalfX = 12.8, HalfZ = 7.4, Top = 13.7 },
	{ Id = "MidRiftLipCrystal", X = -118, Z = -68, Y = 2, HalfX = 12.8, HalfZ = 7.4, Top = 13.7 },
	{ Id = "EastRiftLipCrystal", X = 378, Z = 118, Y = 0, HalfX = 12.8, HalfZ = 7.4, Top = 13.7 },
	-- 24. The Last Lamp at the Sanctuary (still gold, still steady)
	{ Id = "TheLastLampPost", X = 30, Z = 344, Y = 8, HalfX = 2.0, HalfZ = 2.4, Top = 12.6 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AstralFloor45.Build(ctx: any)
	local H = InfernalFoundry.Helpers(ctx)
	local bottom: number = H.bottom
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
		if emittersUsed >= 14 then return end
		emittersUsed += 1
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, RIFTWARD_45.SILK.Color, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(232, 224, 212), rgb(164, 114, 248))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1.05), NumberSequenceKeypoint.new(1, 0.3) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(2.6, 4.4)
		pe.Rate = rate
		pe.Speed = NumberRange.new(2.2, 4.8)
		pe.SpreadAngle = Vector2.new(65, 65)
		pe.RotSpeed = NumberRange.new(-90, 90)
		pe.Acceleration = V(0, -1.8, 0)
		pe.Parent = anchor
	end

	for _, lm in AstralFloor45.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- 1–3. The Great Telescope (297.8 studs tall) + Torn Observatory Dome Ribs behind the Apex dais
	do
		local mount = AstralFloor45.Landmarks[1]
		local mm = piece("GreatTelescopeMount", mount.X, mount.Z, 0, "GreatTelescopeMount", 1.0, SILVER_LENS_TINT, function(cf)
			boxAt("TelescopeMountBase", cf * CFrame.new(0, 52, 0), V(54, 104, 54), RIFTWARD_45.STONE.Color, Mat.Limestone)
		end, mount.Y)
		pin(mm)
		if mm then addLight(H.glowOf(mm) or mm:FindFirstChildWhichIsA("BasePart", true), SILVER_LIGHT, 2.8, 130) end

		local tube = AstralFloor45.Landmarks[2]
		local mt = piece("AstralDome", tube.X, tube.Z, -12, "GreatTelescopeTube", 1.0, SILVER_LENS_TINT, function(cf)
			boxAt("TelescopeBarrel", cf * CFrame.new(0, 88, 0) * CFrame.Angles(math.rad(-26), 0, 0), V(28, 175, 28), RIFTWARD_45.METAL.Color, Mat.Metal)
		end, tube.Y)
		pin(mt)
		noCollide(mt)
		if mt then addLight(H.glowOf(mt) or mt:FindFirstChildWhichIsA("BasePart", true), SILVER_LIGHT, 2.4, 120) end

		local dome = AstralFloor45.Landmarks[3]
		local md = piece("AstralDome", dome.X, dome.Z, 0, "ObservatoryDomeRibs", 1.0, RIFTWARD_45, function(cf)
			for i = -2, 2 do
				ctx.ring("ObservatoryRib", cf.Position + V(0, 40, 0), 76, 3.2, RIFTWARD_45.METAL.Color, Mat.Metal, CFrame.Angles(0, i * 0.42, 0), 0, math.pi, 16)
			end
		end, dome.Y)
		pin(md)
		noCollide(md)
	end

	-- 4–5. Colossal Brass Azimuth Rings either side of the dais (carrying the last two burning gold lamps!)
	for _, spec in { { AstralFloor45.Landmarks[4], 90 }, { AstralFloor45.Landmarks[5], -90 } } do
		local lm = spec[1]
		local ma = piece("AstralGateRing", lm.X, lm.Z, spec[2], "AzimuthRing", 1.22, RIFTWARD_45, function(cf)
			ctx.ring("AzimuthArc", cf.Position + V(0, 20, 0), 18, 2.4, RIFTWARD_45.TRIM.Color, Mat.Metal, nil, -0.3, math.pi + 0.3, 18)
		end, lm.Y)
		pin(ma)
		noCollide(ma)
		if ma then
			ma:SetAttribute("ConjunctionLamp", true)
			safeTag(ma, "ConjunctionLamp")
			addLight(H.glowOf(ma) or ma:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.5, 90)
		end
	end

	-- 6. The Rift Eye turning deep in the Rift bed (sculpted vortex + jagged RiftLipCrystals — NO flat boxes!)
	do
		local eye = AstralFloor45.Landmarks[6]
		local me = piece("AstralRiftEye", eye.X, eye.Z, 0, "RiftEyeMesh", 2.55, RIFT_EYE_TINT, function(cf)
			ctx.cyl("RiftEyeDisc", cf.Position + V(0, 2, 0), 62, 3.5, RIFT_EYE_TINT.GLOW.Color, Mat.Neon)
		end, bottom + 0.4)
		pin(me)
		noCollide(me)
		if me then
			me:SetAttribute("ConjunctionRiftEye", true)
			safeTag(me, "ConjunctionRiftEye")
			addLight(H.glowOf(me) or me:FindFirstChildWhichIsA("BasePart", true), VIOLET_LIGHT, 3.2, 130)
		end
		pageEmitter(V(eye.X, bottom + 6, eye.Z), 6)
		-- Crystalline violet Rift Lip teeth lining BOTH rims of the diagonal Rift chasm (exact match to guide art!)
		for i, cr in {
			{ 285, 84, 30, 1.15 }, { 195, 58, 20, 1.25 }, { 125, 18, 12, 1.30 },
			{ -55, -28, -20, 1.35 }, { -145, -88, -32, 1.30 }, { -275, -162, -15, 1.20 },
			{ 88, -62, 165, 1.25 }, { -12, -98, 150, 1.30 }, { -185, -182, 160, 1.20 }, { 240, 22, 155, 1.15 },
		} do
			local mc = piece("RiftBedGlows", cr[1], cr[2], cr[3], "RiftLipCrystal", cr[4], RIFT_LIP_TINT, function(cf)
				ctx.cyl("RiftLipFallback", cf.Position + V(0, 6, 0), 8, 12, RIFT_LIP_TINT.GLOW.Color, Mat.Neon)
			end, bottom + 0.2)
			pin(mc)
			noCollide(mc)
			if mc and (i == 2 or i == 5) then
				addLight(H.glowOf(mc) or mc:FindFirstChildWhichIsA("BasePart", true), VIOLET_LIGHT, 2.2, 85)
			end
		end
		-- Iconic lashed bookcase SutureShelfSpans flanking the Middle & West Suture chasm crossings
		for _, ss in {
			{ 82, 26, -34, 24 },
			{ -4, 26, -6, 24 },
			{ -188, 42, -172, 28 },
		} do
			local ms = piece("AstralGateRing", ss[1], ss[3], ss[4], "SutureShelfSpan", 1.1, RIFTWARD_45, function(cf)
				boxAt("SutureShelfFlank", cf * CFrame.new(0, 5, 0), V(12, 10, 24), RIFTWARD_45.WOOD.Color, Mat.Wood)
			end, ss[2])
			pin(ms)
			noCollide(ms)
		end
	end

	-- 7–23. Observatory wings, transit towers, lens benches, fallen orrery, grand lectern, rift crystals
	local propSpecs = {
		{ AstralFloor45.Landmarks[7], "MeridianFooting", 0, RIFTWARD_45, 1.0 },
		{ AstralFloor45.Landmarks[8], "MeridianFooting", 0, RIFTWARD_45, 1.0 },
		{ AstralFloor45.Landmarks[9], "RiftOverlookDeck", 0, RIFTWARD_45, 1.15 },
		{ AstralFloor45.Landmarks[10], "TransitTower", 90, RIFTWARD_45, 1.30 },
		{ AstralFloor45.Landmarks[11], "TransitTower", -90, RIFTWARD_45, 1.30 },
		{ AstralFloor45.Landmarks[12], "TransitInstrument", 60, SILVER_LENS_TINT, 1.15 },
		{ AstralFloor45.Landmarks[13], "TransitInstrument", -60, SILVER_LENS_TINT, 1.15 },
		{ AstralFloor45.Landmarks[14], "LensBench", 0, SILVER_LENS_TINT, 1.15 },
		{ AstralFloor45.Landmarks[15], "LensBench", -90, SILVER_LENS_TINT, 1.15 },
		{ AstralFloor45.Landmarks[16], "FallenOrrery", -25, RIFTWARD_45, 1.40 },
		{ AstralFloor45.Landmarks[17], "StarLecternGrand", 35, RIFTWARD_45, 1.20 },
		{ AstralFloor45.Landmarks[18], "InkPoolDecal", 0, RIFTWARD_45, 1.15 },
		{ AstralFloor45.Landmarks[19], "ToppledCabinetRange", -30, RIFTWARD_45, 1.10 },
		{ AstralFloor45.Landmarks[20], "ProofPress", -90, RIFTWARD_45, 1.10 },
		{ AstralFloor45.Landmarks[21], "RiftLipCrystal", 40, RIFT_LIP_TINT, 1.25 },
		{ AstralFloor45.Landmarks[22], "RiftLipCrystal", -20, RIFT_LIP_TINT, 1.25 },
		{ AstralFloor45.Landmarks[23], "RiftLipCrystal", -35, RIFT_LIP_TINT, 1.25 },
	}
	for _, spec in propSpecs do
		local lm = spec[1]
		local m = piece(lm.Id, lm.X, lm.Z, spec[3], spec[2], spec[5], spec[4], function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, lm.Top * 0.5, 0), V(lm.HalfX * 1.8, lm.Top, lm.HalfZ * 1.8), RIFTWARD_45.STONE.Color, Mat.Slate)
		end, lm.Y)
		pin(m)
		if spec[2] == "InkPoolDecal" or spec[2] == "RiftLipCrystal" then
			tagDetail(m)
		end
		if spec[2] == "StarLecternGrand" or spec[2] == "FallenOrrery" then
			addLight(H.glowOf(m) or (m and m:FindFirstChildWhichIsA("BasePart", true)), GOLD_LIGHT, 1.5, 58)
		end
	end

	-- 24. The Last Lamp at Sanctuary (still warm gold, still steady!)
	do
		local lm = AstralFloor45.Landmarks[24]
		local ml = piece(lm.Id, lm.X, lm.Z, 0, "IndexLamp", 1.0, RIFTWARD_45, function(cf)
			ctx.cyl("LastLampPost", cf.Position + V(0, 6, 0), 0.7, 12, RIFTWARD_45.METAL.Color, Mat.Metal)
			lump("LastLampBulb", cf.Position + V(0, 11.5, 0), V(2.4, 3.0, 2.4), RIFTWARD_45.GLOW.Color, Mat.Neon)
		end, lm.Y)
		pin(ml)
		tagDetail(ml)
		if ml then
			ml:SetAttribute("ConjunctionLamp", true)
			safeTag(ml, "ConjunctionLamp")
			addLight(H.glowOf(ml), GOLD_LIGHT, 1.6, 52)
		end
	end

	-- Flush worn gold meridian line across the Observing Floor dais (dark & uncluttered for boss telegraphs!)
	ctx.group("ObservatoryMeridianLine", function()
		local line = boxAt("GoldMeridianLine", CFrame.new(V(0, 68.12, -225)), V(1.2, 0.14, 134), RIFTWARD_45.TRIM.Color, Mat.Metal)
		line:SetAttribute("ConjunctionGlyph", true)
		safeTag(line, "ConjunctionGlyph")
		local cross = boxAt("GoldMeridianCross", CFrame.new(V(0, 68.12, -225)), V(176, 0.14, 1.2), RIFTWARD_45.TRIM.Color, Mat.Metal)
		cross:SetAttribute("ConjunctionGlyph", true)
		safeTag(cross, "ConjunctionGlyph")
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	-- Jagged branching torn-sky cosmic rift sweeping behind the Observatory Dome (never a stiff straight bar!)
	ctx.group("AstralTornSky", function()
		local pts = {
			V(45, 220, -340), V(125, 248, -352), V(185, 266, -358),
			V(260, 294, -365), V(340, 316, -372), V(410, 336, -380),
		}
		for i = 1, #pts - 1 do
			local seg = ctx.beam("TornSkyRift", pts[i], pts[i + 1], 2.2 + (i % 3) * 1.4, rgb(186, 118, 255), Mat.Neon, 0.08)
			seg:SetAttribute("ConjunctionGlyph", true)
			safeTag(seg, "ConjunctionGlyph")
		end
		for _, fork in {
			{ V(125, 248, -352), V(165, 232, -356) },
			{ V(260, 294, -365), V(232, 318, -368) },
		} do
			local fSeg = ctx.beam("TornSkyFork", fork[1], fork[2], 1.4, rgb(216, 168, 255), Mat.Neon, 0.14)
			fSeg:SetAttribute("ConjunctionGlyph", true)
			safeTag(fSeg, "ConjunctionGlyph")
		end
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	-- Pages lifted and pulled toward the Rift Eye across the floor
	pageEmitter(V(40, 32, -20), 5)
	pageEmitter(V(-230, 46, -165), 4)
	pageEmitter(V(235, 16, 65), 4)
	pageEmitter(V(0, 74, -225), 3)

	ctx.setAttribute("AstralFloor", 45)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor45
