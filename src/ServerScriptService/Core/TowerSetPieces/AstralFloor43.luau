--!strict
-- Hand-authored set pieces for Astral Archives Floor 43: Fractured Index (astral:3, TERRAIN_VARIATION).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 43).
--
-- Where the Index Engine broke: four tilted ranges of fault plates rising toward the Lifted Index (back-west,
-- Y 52), split by three alternating-pinch rifts with floating shard decks, fossilised shelf-strata scarps,
-- sculpted page-falls, split violet-teal aurora overhead, and the 180-stud broken Index Engine back-east.
local CollectionService = game:GetService("CollectionService")
local InfernalFoundry = require(script.Parent.InfernalFoundry)

local AstralFloor43 = {}

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

-- Riftward fractured palette: darkened lapis-slate stone, weathered brass, ebony shelving, pale starlight
-- gold on shard lamps (never orange/red), void violet restricted strictly to rift beds & high aurora.
local RIFTWARD_43 = table.freeze({
	STONE = swatch(184, 180, 174, Mat.Limestone),
	ALT = swatch(42, 46, 78, Mat.Slate),
	TRIM = swatch(204, 174, 100, Mat.Metal),
	METAL = swatch(170, 138, 78, Mat.Metal),
	WOOD = swatch(48, 36, 40, Mat.Wood),
	SILK = swatch(232, 224, 206, Mat.Fabric),
	GLOW = swatch(244, 224, 162, Mat.Neon),
	CRYSTAL = swatch(118, 168, 222, Mat.Glass, 0.22),
	MOSS = swatch(82, 114, 118, Mat.Grass),
})

local RIFT_VIOLET = rgb(146, 92, 238)
local AURORA_TEAL = rgb(116, 212, 218)
local GOLD_LIGHT = rgb(244, 224, 162)

-- Floor 43's 20 landmark footprints (local floor space, 720 x 750).
AstralFloor43.Landmarks = table.freeze({
	-- 1. Index Engine Core (>= 175 studs, 179.7 studs) split down the middle at back-east
	{ Id = "IndexEngineCore", X = 298, Z = -352, Y = 44, HalfX = 35.0, HalfZ = 13.8, Top = 179.7 },
	-- 2. Index Engine Gear Bank behind Engine terrace
	{ Id = "IndexEngineGearBank", X = 216, Z = -362, Y = 44, HalfX = 45.6, HalfZ = 7.2, Top = 86.1 },
	-- 3. Index Engine Shelf Tower east flank
	{ Id = "IndexEngineShelfTower", X = 336, Z = -286, Y = 44, HalfX = 18.4, HalfZ = 8.0, Top = 93.0 },
	-- 4. Lifted Index Gallery behind Apex portals (-321)
	{ Id = "LiftedIndexGallery", X = -210, Z = -356, Y = 52, HalfX = 32.0, HalfZ = 12.0, Top = 31.6 },
	-- 5. Colophon Wall behind Colophon Plate (P4C)
	{ Id = "ColophonWall", X = 60, Z = -348, Y = 48, HalfX = 13.6, HalfZ = 2.0, Top = 16.8 },
	-- 6. Bindery Press (west edge of P2W)
	{ Id = "BinderyPress", X = -260, Z = -80, Y = 28, HalfX = 8.4, HalfZ = 3.6, Top = 12.4 },
	-- 7. Errata Press (east edge of P2E)
	{ Id = "ErrataPress", X = 232, Z = -95, Y = 20, HalfX = 6.5, HalfZ = 3.2, Top = 9.7 },
	-- 8. Reading Plate Tilted Desk (south-east edge of P2C)
	{ Id = "ReadingTiltedDesk", X = 0, Z = -40, Y = 24, HalfX = 4.8, HalfZ = 5.0, Top = 6.0 },
	-- 9. Ledger Plate Tall Ledger Stack (north rim of P3C)
	{ Id = "LedgerStackTall", X = 20, Z = -214, Y = 36, HalfX = 5.0, HalfZ = 4.8, Top = 14.1 },
	-- 10. Ink-Cellar Cracked Ink Vat (east edge of P3E)
	{ Id = "InkCellarVat", X = 290, Z = -185, Y = 32, HalfX = 4.8, HalfZ = 7.0, Top = 5.8 },
	-- 11. Toppled Shelf Range on Westrange outer rim
	{ Id = "WestrangeToppledShelf", X = -280, Z = 70, Y = 16, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 12. Toppled Shelf Range on Eastrange outer rim
	{ Id = "EastrangeToppledShelf", X = 264, Z = 75, Y = 8, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 13. Card Drawer Spill tumbling from Engine into Rift C
	{ Id = "EngineCardSpill", X = 202, Z = -300, Y = 38, HalfX = 6.0, HalfZ = 4.4, Top = 2.4 },
	-- 14. Broken Orrery Ring thrown onto Index Floor west edge
	{ Id = "BrokenOrreryRingW", X = -190, Z = 290, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 15. Broken Orrery Ring thrown onto Index Floor east edge
	{ Id = "BrokenOrreryRingE", X = 190, Z = 290, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 16. Scarp Shelf Strata on Westrange north scarp
	{ Id = "ScarpStrataWest", X = -288, Z = 20, Y = 4, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 17. Scarp Shelf Strata on P2W north scarp
	{ Id = "ScarpStrataP2W", X = -280, Z = -124, Y = 12, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 18. Scarp Shelf Strata on P3E north scarp
	{ Id = "ScarpStrataP3E", X = 304, Z = -224, Y = 18, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 19. Page Fall Ribbon cascading into Rift A
	{ Id = "PageFallRiftA", X = 60, Z = -12, Y = -4, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
	-- 20. Page Fall Ribbon cascading into Rift C
	{ Id = "PageFallRiftC", X = 46, Z = -228, Y = 10, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
}) :: { Landmark }

local function safeTag(inst: Instance?, tagName: string)
	if inst then
		pcall(function()
			CollectionService:AddTag(inst, tagName)
		end)
	end
end

function AstralFloor43.Build(ctx: any)
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
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, RIFTWARD_43.SILK.Color, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(236, 228, 208), rgb(186, 178, 224))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1.0), NumberSequenceKeypoint.new(1, 0.3) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3.0, 5.0)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1.5, 3.5)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.RotSpeed = NumberRange.new(-65, 65)
		pe.Acceleration = V(0, -1.2, 0)
		pe.Parent = anchor
	end

	for _, lm in AstralFloor43.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- 1–3. The Broken Index Engine (colossal 180-stud split brass machine + gear bank + shelf tower)
	do
		local core = AstralFloor43.Landmarks[1]
		local mc = piece("IndexEngineCore", core.X, core.Z, -18, "IndexEngineCore", 1.0, RIFTWARD_43, function(cf)
			boxAt("EngineLeft", cf * CFrame.new(-16, 86, 0) * CFrame.Angles(0, 0, math.rad(5)), V(24, 172, 22), RIFTWARD_43.METAL.Color, Mat.Metal)
			boxAt("EngineRight", cf * CFrame.new(16, 86, 0) * CFrame.Angles(0, 0, math.rad(-5)), V(24, 172, 22), RIFTWARD_43.METAL.Color, Mat.Metal)
			lump("EngineRiftCrack", (cf * CFrame.new(0, 74, 4)).Position, V(10, 90, 6), RIFT_VIOLET, Mat.Neon)
		end, core.Y)
		pin(mc)
		if mc then addLight(H.glowOf(mc), GOLD_LIGHT, 2.0, 95) end

		local gb = AstralFloor43.Landmarks[2]
		local mgb = piece("IndexEngineGearBank", gb.X, gb.Z, 0, "IndexEngineGearBank", 1.15, RIFTWARD_43, function(cf)
			boxAt("GearBank", cf * CFrame.new(0, 42, 0), V(84, 84, 12), RIFTWARD_43.METAL.Color, Mat.Metal)
		end, gb.Y)
		pin(mgb)
		if mgb then addLight(mgb.PrimaryPart or mgb:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 1.8, 100) end

		local st = AstralFloor43.Landmarks[3]
		pin(piece("IndexEngineShelfTower", st.X, st.Z, -85, "IndexEngineShelfTower", 1.05, RIFTWARD_43, function(cf)
			boxAt("ShelfTower", cf * CFrame.new(0, 46, 0), V(32, 92, 14), RIFTWARD_43.WOOD.Color, Mat.Wood)
		end, st.Y))
	end

	-- 4. The Lifted Index Gallery behind Apex portals (prominent curved mahogany gallery!)
	do
		local lm = AstralFloor43.Landmarks[4]
		local mg = piece("LiftedIndexGallery", lm.X, lm.Z, 0, "LiftedIndexGallery", 1.45, RIFTWARD_43, function(cf)
			boxAt("LiftedGallery", cf * CFrame.new(0, 15, 0), V(60, 30, 20), RIFTWARD_43.WOOD.Color, Mat.Wood)
		end, lm.Y)
		pin(mg)
		if mg then addLight(H.glowOf(mg) or mg:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.0, 95) end
	end

	-- 5–15. Plate landmarks: Colophon, Bindery, Errata, Reading, Ledger, Ink-Cellar, Toppled Shelves, Card Spill, Broken Rings
	local plateSpecs = {
		{ AstralFloor43.Landmarks[5], "ColophonWall", 0 },
		{ AstralFloor43.Landmarks[6], "BinderyPress", 90 },
		{ AstralFloor43.Landmarks[7], "ErrataPress", -90 },
		{ AstralFloor43.Landmarks[8], "CatalogueDeskTilted", 15 },
		{ AstralFloor43.Landmarks[9], "LedgerStackTall", 0 },
		{ AstralFloor43.Landmarks[10], "InkVatCracked", -80 },
		{ AstralFloor43.Landmarks[11], "ToppledShelfRange", 75 },
		{ AstralFloor43.Landmarks[12], "ToppledShelfRange", -75 },
		{ AstralFloor43.Landmarks[13], "CardDrawerSpill", 25 },
		{ AstralFloor43.Landmarks[14], "BrokenOrreryRing", 35 },
		{ AstralFloor43.Landmarks[15], "BrokenOrreryRing", -35 },
	}
	for _, spec in plateSpecs do
		local lm = spec[1]
		local m = piece(lm.Id, lm.X, lm.Z, spec[3], spec[2], 1.0, RIFTWARD_43, function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, lm.Top * 0.5, 0), V(lm.HalfX * 1.8, lm.Top, lm.HalfZ * 1.8), RIFTWARD_43.WOOD.Color, Mat.Wood)
		end, lm.Y)
		pin(m)
		if spec[2] == "CardDrawerSpill" or spec[2] == "CatalogueDeskTilted" then
			tagDetail(m)
		end
	end

	-- 16–18. Scarp Shelf Strata fossilised into the up-thrown plate faces
	for _, idx in { 16, 17, 18 } do
		local lm = AstralFloor43.Landmarks[idx]
		local ms = piece(lm.Id, lm.X, lm.Z, 0, "ScarpShelfStrata", 1.0, RIFTWARD_43, function(cf)
			boxAt("ShelfStrata", cf * CFrame.new(0, 8, 0), V(32, 16, 10), RIFTWARD_43.ALT.Color, Mat.Slate)
		end, lm.Y)
		pin(ms)
		noCollide(ms)
	end

	-- 19–20. Sculpted Page Fall Ribbons cascading down the rift walls (+ extra cascades into Rifts A & B)
	for _, idx in { 19, 20 } do
		local lm = AstralFloor43.Landmarks[idx]
		local mp = piece(lm.Id, lm.X, lm.Z, 0, "PageFallRibbon", 1.55, RIFTWARD_43, function(cf)
			boxAt("PageCascade", cf * CFrame.new(0, 10, 0), V(8, 20, 10), RIFTWARD_43.SILK.Color, Mat.Fabric)
		end, lm.Y)
		pin(mp)
		noCollide(mp)
		pageEmitter(V(lm.X, (lm.Y :: number) + 12, lm.Z), 4)
	end
	for _, extra in { { -190, 20, -4, 30 }, { 95, 16, -8, -25 }, { 12, 24, -128, 15 } } do
		local mp = piece("AstralIsleUnderside", extra[1], extra[3], extra[4], "PageFallRibbon", 1.45, RIFTWARD_43, function(cf)
			boxAt("PageCascade", cf * CFrame.new(0, 10, 0), V(8, 20, 10), RIFTWARD_43.SILK.Color, Mat.Fabric)
		end, extra[2] - 18)
		pin(mp)
		noCollide(mp)
	end

	-- Jagged floor-slab shard undersides pinned flush beneath the four floating shard decks (never poking above deck!)
	for _, row in {
		{ "ShardA", "ShardSlabM", 29.314, 0.92 },
		{ "ShardE", "ShardSlabM", 29.314, 0.90 },
		{ "ShardB", "ShardSlabL", 35.314, 0.94 },
		{ "ShardC", "ShardSlabM", 29.314, 0.92 },
	} do
		local plat = P[row[1]]
		if plat then
			local kitH: number = row[3]
			local sc: number = row[4]
			local baseY = plat.Y - kitH * sc - 1.4
			local ms = piece("AstralIsleUnderside", plat.X, plat.Z, 0, row[2], sc, RIFTWARD_43, function(cf)
				ctx.cyl("ShardUnderside", cf.Position + V(0, 10, 0), 16, 20, RIFTWARD_43.ALT.Color, Mat.Slate)
			end, baseY)
			pin(ms)
			noCollide(ms)
		end
	end

	-- Crooked Index Lamps: lit ONLY on the four floating shards (because only the shards still cross the rifts!)
	for i, name in { "ShardA", "ShardE", "ShardB", "ShardC" } do
		local plat = P[name]
		if plat then
			local ml = piece("AstralIndexLamp", plat.X + 20, plat.Z, i * 47, "CrookedIndexLamp", 1.0, RIFTWARD_43, function(cf)
				ctx.cyl("CrookedPost", cf.Position + V(0, 6, 0), 0.7, 12, RIFTWARD_43.METAL.Color, Mat.Metal)
				lump("CrookedBulb", cf.Position + V(0, 11.5, 0), V(2.2, 2.8, 2.2), RIFTWARD_43.GLOW.Color, Mat.Neon)
			end, plat.Y)
			pin(ml)
			tagDetail(ml)
			if ml then
				ml:SetAttribute("ConjunctionLamp", true)
				safeTag(ml, "ConjunctionLamp")
				addLight(H.glowOf(ml), GOLD_LIGHT, 1.5, 48)
			end
		end
	end

	-- Deep Rift chasm violet luminescence (sculpted crystal outcrops + violet light pools strictly in deep chasms!)
	ctx.group("RiftBedGlows", function()
		for i, pt in {
			V(45, bottom + 0.5, -8),
			V(-110, bottom + 0.5, -135),
			V(-25, bottom + 0.5, -214),
			V(140, bottom + 0.5, -245),
		} do
			local anchor = ctx.block("RiftGlowAnchor" .. i, V(2, 2, 2), pt + V(0, 3, 0), RIFT_VIOLET, Mat.SmoothPlastic, nil, 1)
			if i <= 3 then
				addLight(anchor, RIFT_VIOLET, 2.2, 85)
			end
		end
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	-- Organic curved Split Violet-Teal Aurora ribbon arcing across the Fracture sky (no rigid straight bars!)
	ctx.group("AstralSplitAurora", function()
		local nPts = 10
		local prevTeal: Vector3? = nil
		local prevVio: Vector3? = nil
		for i = 0, nPts do
			local u = i / nPts
			local x = -280 + u * 560
			local wave = math.sin(u * math.pi * 2.2) * 28
			local arcY = 205 + math.sin(u * math.pi) * 42 + math.cos(u * math.pi * 3) * 10
			local z = -140 - u * 150 + wave * 0.4
			local ptT = V(x, arcY + 8, z)
			local ptV = V(x + 12, arcY - 6, z - 16)
			if prevTeal and prevVio then
				local thick = 2.2 + math.sin(u * math.pi) * 3.8
				local tSeg = ctx.beam("AuroraTeal", prevTeal, ptT, thick, AURORA_TEAL, Mat.Neon, 0.25)
				local vSeg = ctx.beam("AuroraViolet", prevVio, ptV, thick * 0.9, RIFT_VIOLET, Mat.Neon, 0.25)
				tSeg:SetAttribute("ConjunctionGlyph", true)
				vSeg:SetAttribute("ConjunctionGlyph", true)
				safeTag(tSeg, "ConjunctionGlyph")
				safeTag(vSeg, "ConjunctionGlyph")
			end
			prevTeal, prevVio = ptT, ptV
		end
		noCollide(ctx.current())
		pin(ctx.current())
	end)

	pageEmitter(V(240, 48, -280), 4)
	pageEmitter(V(-110, 34, -165), 3)

	ctx.setAttribute("AstralFloor", 43)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor43
