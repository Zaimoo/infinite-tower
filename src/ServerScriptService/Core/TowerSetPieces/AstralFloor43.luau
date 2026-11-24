--!strict
-- Hand-authored set pieces for Astral Archives Floor 43: Fractured Index (astral:3, TERRAIN_VARIATION).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 43) & reference/Astral Archives 43.jpg.
--
-- Where the Index Engine broke: four tilted ranges of sharp fractured grey-slate fault plates rising toward
-- The Lifted Index (back-west, Y=52) over a luminous glowing violet Rift chasm, split by three alternating-pinch
-- rifts with floating jagged Shard decks, hanging brass chains, fossilised shelf-strata embedded in the cliff
-- scarps, sculpted waterfalls of tumbling ivory pages, the Shelfmark Stair with glowing cyan runes, the cracked
-- astrolabe & 8-lectern Ruled Court, the 180-stud split Index Engine + gear bank + twin flanking shelf towers
-- back-east, and wispy volumetric split violet-teal aurora curtains overhead.
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

-- Riftward fractured palette: legible cool weathered grey-slate stone, rich warm mahogany/walnut shelving,
-- aged antique brass & worn gold leaf, ivory vellum pages, pale starlight gold lamps, and luminous void violet
-- strictly in the deep chasm & sky aurora.
local RIFTWARD_43 = table.freeze({
	STONE = swatch(138, 144, 160, Mat.Slate),
	ALT = swatch(62, 68, 92, Mat.Slate),
	TRIM = swatch(214, 182, 106, Mat.Metal),
	METAL = swatch(178, 144, 80, Mat.Metal),
	WOOD = swatch(96, 62, 42, Mat.Wood),
	SILK = swatch(240, 232, 214, Mat.Fabric),
	GLOW = swatch(252, 228, 158, Mat.Neon),
	CRYSTAL = swatch(124, 186, 238, Mat.Glass, 0.18),
	MOSS = swatch(82, 118, 122, Mat.Grass),
})

-- Hide the flat grey STONE top lid on ShardSlabM / ShardSlabL so our crisp cracked flagstone deck caps shine
-- cleanly while the jagged dark slate rock underside & hanging brass chains dangle dramatically into the rift!
local SHARD_UNDERSIDE_TINT = tinted(RIFTWARD_43, {
	STONE = swatch(112, 118, 134, Mat.Slate, 1),
	ALT = swatch(56, 62, 86, Mat.Slate),
	METAL = swatch(176, 142, 78, Mat.Metal),
	TRIM = swatch(212, 180, 102, Mat.Metal),
	CRYSTAL = swatch(162, 106, 244, Mat.Neon, 0.22),
	GLOW = swatch(252, 228, 158, Mat.Neon),
})

-- Ink vat tint: glossy spilling indigo-violet ink puddle matching reference bottom-left!
local INK_VAT_TINT = tinted(RIFTWARD_43, {
	ALT = swatch(54, 46, 136, Mat.Glass),
	CRYSTAL = swatch(88, 72, 198, Mat.Glass, 0.10),
	GLOW = swatch(132, 106, 238, Mat.Neon),
})

-- Rich warm mahogany & stone tint for LiftedIndexGallery & library bookcases
local LIBRARY_TINT = tinted(RIFTWARD_43, {
	STONE = swatch(148, 152, 166, Mat.Slate),
	WOOD = swatch(112, 72, 46, Mat.Wood),
	TRIM = swatch(224, 190, 110, Mat.Metal),
	SILK = swatch(242, 234, 214, Mat.Fabric),
	GLOW = swatch(255, 232, 164, Mat.Neon),
})

local STONE_TOP = rgb(116, 122, 138)
local STONE_LIGHT = rgb(134, 140, 156)
local STONE_DARK = rgb(78, 84, 102)
local CLIFF_ROCK = rgb(58, 64, 84)
local CLIFF_DEEP = rgb(44, 48, 68)
local GOLD_BRIGHT = rgb(222, 188, 106)
local BRASS_AGED = rgb(178, 144, 78)
local WOOD_WARM = rgb(104, 68, 44)
local WOOD_DARK = rgb(74, 48, 34)
local VELLUM_PAGE = rgb(242, 234, 216)

local RIFT_VIOLET = rgb(156, 86, 246)
local RIFT_MAGENTA = rgb(194, 92, 242)
local AURORA_TEAL = rgb(82, 216, 198)
local RUNE_CYAN = rgb(96, 218, 248)
local GOLD_LIGHT = rgb(252, 226, 154)

-- Floor 43's 20 landmark footprints (local floor space, 720 x 750).
-- Every single landmark is 100% grounded on its plate or integrated fractured cliff terrace bay, and
-- spec-checked against all walkway lanes, camps (>= 34 studs), portals (>= 12 studs) and room bounds.
AstralFloor43.Landmarks = table.freeze({
	-- 1. Index Engine Core (>= 175 studs, 179.7 studs) split down the middle behind Engine terrace
	{ Id = "IndexEngineCore", X = 256, Z = -348, Y = 44, HalfX = 35.0, HalfZ = 13.8, Top = 179.7 },
	-- 2. Index Engine Gear Bank rising directly behind IndexEngineCore (cohesive machine silhouette!)
	{ Id = "IndexEngineGearBank", X = 264, Z = -366, Y = 44, HalfX = 45.6, HalfZ = 7.2, Top = 86.1 },
	-- 3. Index Engine Shelf Tower tightly flanking east side of IndexEngineCore
	{ Id = "IndexEngineShelfTower", X = 322, Z = -334, Y = 44, HalfX = 18.4, HalfZ = 8.0, Top = 93.0 },
	-- 4. Lifted Index Gallery grounded solidly on Apex's integrated north terrace & crag behind portals (-321)
	{ Id = "LiftedIndexGallery", X = -210, Z = -357, Y = 52, HalfX = 32.0, HalfZ = 12.0, Top = 31.6 },
	-- 5. Colophon Wall grounded on P4C's integrated north stone terrace
	{ Id = "ColophonWall", X = 60, Z = -348, Y = 48, HalfX = 13.6, HalfZ = 2.0, Top = 16.8 },
	-- 6. Bindery Press (wooden screw press + gold thread spools) grounded on P2W's western terrace bay
	{ Id = "BinderyPress", X = -260, Z = -80, Y = 28, HalfX = 8.4, HalfZ = 3.6, Top = 12.4 },
	-- 7. Errata Press grounded on P2E's eastern terrace bay
	{ Id = "ErrataPress", X = 232, Z = -95, Y = 20, HalfX = 6.5, HalfZ = 3.2, Top = 9.7 },
	-- 8. Reading Plate Tilted Desk grounded on P2C's south-east cliff shelf
	{ Id = "ReadingTiltedDesk", X = 0, Z = -40, Y = 24, HalfX = 4.8, HalfZ = 5.0, Top = 6.0 },
	-- 9. Ledger Plate Tall Ledger Stack grounded on P3C's northern cliff bay
	{ Id = "LedgerStackTall", X = 20, Z = -214, Y = 36, HalfX = 5.0, HalfZ = 4.8, Top = 14.1 },
	-- 10. Ink-Cellar Cracked Ink Vat grounded on P3E's eastern cliff bay
	{ Id = "InkCellarVat", X = 290, Z = -185, Y = 32, HalfX = 4.8, HalfZ = 7.0, Top = 5.8 },
	-- 11. Toppled Shelf Range grounded on WestGallery's integrated western cliff terrace bay
	{ Id = "WestrangeToppledShelf", X = -280, Z = 70, Y = 16, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 12. Toppled Shelf Range grounded on EastGallery's integrated eastern cliff terrace bay
	{ Id = "EastrangeToppledShelf", X = 264, Z = 75, Y = 8, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 13. Card Drawer Spill tumbling from Engine across its western ledge toward Rift C
	{ Id = "EngineCardSpill", X = 202, Z = -300, Y = 44, HalfX = 6.0, HalfZ = 4.4, Top = 2.4 },
	-- 14. Broken Orrery Ring + fallen column grounded solidly on Basin west foreground terrace
	{ Id = "BrokenOrreryRingW", X = -194, Z = 258, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 15. Broken Orrery Ring + fallen column grounded solidly on Basin east foreground terrace
	{ Id = "BrokenOrreryRingE", X = 194, Z = 258, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 16. Scarp Shelf Strata embedded flush into WestGallery's north-west rocky cliff face
	{ Id = "ScarpStrataWest", X = -278, Z = 28, Y = 0, HalfX = 16.8, HalfZ = 6.0, Top = 16.0 },
	-- 17. Scarp Shelf Strata embedded flush into P2W's north-west rocky cliff face
	{ Id = "ScarpStrataP2W", X = -268, Z = -114, Y = 10, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 18. Scarp Shelf Strata embedded flush into P3E's north-east rocky cliff face
	{ Id = "ScarpStrataP3E", X = 290, Z = -218, Y = 14, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 19. Page Fall Ribbon cascading directly off Reading Plate's south cliff lip into Rift A
	{ Id = "PageFallRiftA", X = -8, Z = -30, Y = 0, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
	-- 20. Page Fall Ribbon cascading directly off Ledger Plate's north cliff lip into Rift C
	{ Id = "PageFallRiftC", X = 46, Z = -224, Y = 12, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
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
		local anchor = ctx.block("PageDriftAnchor", V(1, 1, 1), pos, VELLUM_PAGE, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		anchor:SetAttribute("ConjunctionPageEmitter", true)
		safeTag(anchor, "ConjunctionPageEmitter")
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralPages"
		pe.Color = ColorSequence.new(rgb(244, 236, 218), rgb(206, 184, 242))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.5, 1.1), NumberSequenceKeypoint.new(1, 0.35) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.32), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(3.2, 5.4)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1.4, 3.2)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.RotSpeed = NumberRange.new(-65, 65)
		pe.Acceleration = V(0, -1.4, 0)
		pe.Parent = anchor
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

	-- Helper: weathered grey-slate & antique-brass stone balustrade span
	local function balustradeSpan(x0: number, z0: number, x1: number, z1: number, y: number, withEndOrbs: boolean?)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local len = (b - a).Magnitude
		if len < 4 then return end
		local mid = (a + b) * 0.5
		local cf = CFrame.lookAt(mid, b)
		boxAt("FractureBalPlinth", cf * CFrame.new(0, 0.55, 0), V(1.35, 1.1, len), STONE_LIGHT, Mat.Slate)
		boxAt("FractureBalRail", cf * CFrame.new(0, 3.05, 0), V(1.05, 0.45, len), BRASS_AGED, Mat.Metal)
		boxAt("FractureBalCapStone", cf * CFrame.new(0, 2.75, 0), V(1.25, 0.30, len), STONE_TOP, Mat.Slate)
		local posts = math.max(2, math.floor(len / 8.5))
		for i = 0, posts do
			local pt = a:Lerp(b, i / posts)
			local isEnd = (i == 0 or i == posts)
			local pw = if isEnd then 1.85 else 0.72
			local ph = if isEnd then 3.85 else 2.1
			boxAt("FractureBalPost", CFrame.new(pt + V(0, ph * 0.5 + 0.1, 0)), V(pw, ph, pw), if isEnd then STONE_LIGHT else STONE_TOP, Mat.Slate)
			if isEnd and withEndOrbs ~= false then
				lump("FractureBalOrb", pt + V(0, 4.35, 0), V(1.45, 1.45, 1.45), GOLD_BRIGHT, Mat.Metal)
			end
		end
	end

	-- Helper: classical wooden/brass lectern standing on a stone pedestal (for the Ruled Court 8-lectern ring!)
	local function buildWoodenLectern(pos: Vector3, yawDeg: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		boxAt("LecternFoot", cf * CFrame.new(0, 0.45, 0), V(2.6, 0.9, 2.6), STONE_LIGHT, Mat.Slate)
		boxAt("LecternStem", cf * CFrame.new(0, 2.25, 0), V(1.4, 2.8, 1.4), WOOD_WARM, Mat.Wood)
		boxAt("LecternBrassBand", cf * CFrame.new(0, 3.45, 0), V(1.65, 0.3, 1.65), GOLD_BRIGHT, Mat.Metal)
		local deskCF = cf * CFrame.new(0, 4.05, 0) * CFrame.Angles(math.rad(-22), 0, 0)
		boxAt("LecternBoard", deskCF, V(3.0, 0.35, 2.2), WOOD_DARK, Mat.Wood)
		boxAt("LecternPage", deskCF * CFrame.new(0, 0.22, 0), V(2.3, 0.14, 1.6), VELLUM_PAGE, Mat.Fabric)
	end

	-- Helper: tall upright wooden library bookcase packed with antique spines
	local function buildStandingBookcase(pos: Vector3, yawDeg: number, scale: number)
		local s = scale
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		local w, h, d = 12.0 * s, 14.5 * s, 3.4 * s
		boxAt("CaseBack", cf * CFrame.new(0, h * 0.5, -d * 0.36), V(w, h, 0.7 * s), WOOD_DARK, Mat.Wood)
		for _, sx in { -1, 1 } do
			boxAt("CaseSide", cf * CFrame.new(sx * (w * 0.5 - 0.5 * s), h * 0.5, 0), V(1.0 * s, h, d), WOOD_WARM, Mat.Wood)
		end
		boxAt("CaseCrown", cf * CFrame.new(0, h + 0.4 * s, 0.2 * s), V(w + 1.2 * s, 1.1 * s, d + 0.8 * s), WOOD_WARM, Mat.Wood)
		boxAt("CaseCrownTrim", cf * CFrame.new(0, h + 1.0 * s, 0.2 * s), V(w + 1.4 * s, 0.35 * s, d + 1.0 * s), BRASS_AGED, Mat.Metal)
		boxAt("CasePlinth", cf * CFrame.new(0, 0.6 * s, 0), V(w + 0.6 * s, 1.2 * s, d + 0.4 * s), WOOD_DARK, Mat.Wood)
		for row = 0, 3 do
			local ry = (2.2 + row * 3.0) * s
			boxAt("CaseShelf", cf * CFrame.new(0, ry, 0), V(w - 1.2 * s, 0.4 * s, d - 0.5 * s), WOOD_WARM, Mat.Wood)
			for b = 0, 3 do
				local bx = (-w * 0.34 + b * (w * 0.22))
				local bh = (2.0 + ((row + b) % 3) * 0.22) * s
				local bCol = if (row + b) % 3 == 0 then rgb(124, 58, 44) elseif (row + b) % 3 == 1 then rgb(58, 76, 118) else rgb(138, 112, 66)
				boxAt("CaseBooks", cf * CFrame.new(bx, ry + bh * 0.5 + 0.2 * s, 0.25 * s), V(2.1 * s, bh, 1.8 * s), bCol, Mat.Wood)
			end
		end
	end

	-- Helper: build a fractured rocky cliff platform skirt + faceted rock buttresses plunging into the violet chasm.
	-- Uses PropKind = "AstralIsleDeck" (exempt from Walkway & Camp pruning, and seated solidly on RiftVoidFloor so Settle keeps it exact!).
	local function buildFracturedCliffIsland(id: string, x: number, y: number, z: number, w: number, d: number, seed: number)
		local cliffBottom = bottom - 0.35
		local totalH = math.max(5.5, y - cliffBottom)
		ctx.group("AstralIsleDeck", function()
			boxAt(id .. "DeckLip", CFrame.new(V(x, y - 0.72, z)), V(w + 1.4, 1.4, d + 1.4), STONE_TOP, Mat.Slate)
			boxAt(id .. "BrassUnderTrim", CFrame.new(V(x, y - 1.55, z)), V(w + 1.8, 0.40, d + 1.8), BRASS_AGED, Mat.Metal)
			local hullH = math.max(3.5, totalH - 1.6)
			boxAt(id .. "CliffHullUpper", CFrame.new(V(x, y - 1.6 - hullH * 0.30, z)), V(w - 1.5, hullH * 0.62, d - 1.5), CLIFF_ROCK, Mat.Slate)
			boxAt(id .. "CliffHullLower", CFrame.new(V(x, cliffBottom + hullH * 0.26, z)), V(w * 0.86, hullH * 0.54, d * 0.86), CLIFF_DEEP, Mat.Slate)

			local halfW, halfD = w * 0.5, d * 0.5
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local rockW = math.min(20, w * 0.24)
					local rockD = math.min(20, d * 0.24)
					local rockH = hullH * (0.78 + ((seed + sx * 3 + sz * 5) % 3) * 0.08)
					local rx = x + sx * (halfW - rockW * 0.22)
					local rz = z + sz * (halfD - rockD * 0.22)
					local cf = CFrame.new(V(rx, y - 1.8 - rockH * 0.5, rz))
						* CFrame.Angles(math.rad(sz * 6), math.rad((seed * 17 + sx * 11 + sz * 7) % 24 - 12), math.rad(-sx * 6))
					boxAt(id .. "CornerCrag", cf, V(rockW, rockH, rockD), if (sx + sz) == 0 then CLIFF_ROCK else CLIFF_DEEP, Mat.Slate)
				end
			end
			local nRibsX = math.clamp(math.floor(w / 52), 1, 5)
			for i = 1, nRibsX do
				local rx = x - halfW + (w * i / (nRibsX + 1))
				for _, sz in { -1, 1 } do
					local rh = hullH * (0.68 + ((i + seed) % 3) * 0.10)
					local cf = CFrame.new(V(rx, y - 1.9 - rh * 0.5, z + sz * (halfD - 1.0)))
						* CFrame.Angles(math.rad(sz * 7), math.rad(((i * 23 + seed) % 16) - 8), 0)
					boxAt(id .. "WallCragZ", cf, V(15, rh, 10), if i % 2 == 0 then CLIFF_ROCK else CLIFF_DEEP, Mat.Slate)
				end
			end
			local nRibsZ = math.clamp(math.floor(d / 46), 1, 3)
			for i = 1, nRibsZ do
				local rz = z - halfD + (d * i / (nRibsZ + 1))
				for _, sx in { -1, 1 } do
					local rh = hullH * (0.66 + ((i + seed) % 3) * 0.10)
					local cf = CFrame.new(V(x + sx * (halfW - 1.0), y - 1.9 - rh * 0.5, rz))
						* CFrame.Angles(0, math.rad(((i * 19 + seed) % 16) - 8), math.rad(-sx * 7))
					boxAt(id .. "WallCragX", cf, V(10, rh, 15), if i % 2 == 0 then CLIFF_DEEP else CLIFF_ROCK, Mat.Slate)
				end
			end

			local nFlags = math.clamp(math.floor((w * d) / 680), 4, 14)
			for k = 1, nFlags do
				local fx = x + math.sin(k * 2.13 + seed) * (halfW * 0.72)
				local fz = z + math.cos(k * 1.71 + seed * 1.3) * (halfD * 0.70)
				local fw = 8.0 + ((k * 7 + seed) % 6)
				local fd = 6.5 + ((k * 5 + seed) % 5)
				local fcf = CFrame.new(V(fx, y + 0.04 + (k % 3) * 0.015, fz)) * CFrame.Angles(0, math.rad(((k * 17 + seed) % 16) - 8), 0)
				boxAt(id .. "Flagstone", fcf, V(fw, 0.10, fd), if k % 2 == 0 then STONE_LIGHT else STONE_DARK, Mat.Slate)
			end
			local crackCF = CFrame.new(V(x + math.sin(seed) * halfW * 0.15, y + 0.09, z + math.cos(seed) * halfD * 0.15))
				* CFrame.Angles(0, math.rad((seed * 37) % 140 - 70), 0)
			boxAt(id .. "FloorCrack", crackCF, V(math.min(w, d) * 0.56, 0.08, 0.75), CLIFF_DEEP, Mat.Slate)

			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	local function buildHangingChain(p0: Vector3, p1: Vector3, sag: number, segs: number)
		local prev = p0
		for i = 1, segs do
			local t = i / segs
			local nextPt = p0:Lerp(p1, t) - V(0, 4 * t * (1 - t) * sag, 0)
			ctx.beam("ChasmBrassChain", prev, nextPt, 0.65, BRASS_AGED, Mat.Metal)
			prev = nextPt
		end
	end

	local function buildMountainCrag(pos: Vector3, size: Vector3, yawDeg: number, tiltDeg: number)
		local cf = CFrame.new(pos + V(0, size.Y * 0.42, 0)) * CFrame.Angles(math.rad(tiltDeg), math.rad(yawDeg), math.rad(tiltDeg * 0.5))
		boxAt("MountainCragBody", cf, size, CLIFF_ROCK, Mat.Slate)
		boxAt("MountainCragFace", cf * CFrame.new(size.X * 0.18, -size.Y * 0.12, size.Z * 0.22) * CFrame.Angles(0, math.rad(18), math.rad(-8)),
			V(size.X * 0.72, size.Y * 0.74, size.Z * 0.68), CLIFF_DEEP, Mat.Slate)
		boxAt("MountainCragCap", cf * CFrame.new(0, size.Y * 0.44, 0) * CFrame.Angles(math.rad(10), math.rad(25), math.rad(-10)),
			V(size.X * 0.62, size.Y * 0.24, size.Z * 0.62), STONE_DARK, Mat.Slate)
	end

	-- Soft, wispy, translucent additive aurora curtain (never opaque white bands!)
	local function addAuroraCurtain(name: string, p0: Vector3, p1: Vector3, height0: number, height1: number, col0: Color3, col1: Color3, peakAlpha: number)
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
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.CurveSize0 = 36
		b.CurveSize1 = -36
		b.Segments = 24
		b.Color = ColorSequence.new(col0, col1)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.22, peakAlpha + 0.08),
			NumberSequenceKeypoint.new(0.50, peakAlpha),
			NumberSequenceKeypoint.new(0.78, peakAlpha + 0.08),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		b.Parent = anchor
	end

	for _, lm in AstralFloor43.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =========================================================================
	-- A. LUMINOUS GLOWING VIOLET RIFT CHASM SEA (PropKind = "AstralNebulaSea")
	-- Sits cleanly below all platforms (Y = -6.35 .. -5.20), bathing every rift
	-- between the fractured fault plates in Image 1's dramatic glowing violet void!
	-- =========================================================================
	ctx.group("AstralNebulaSea", function()
		-- Opaque deep indigo-violet abyssal floor covering the entire room & margins (rests on Ground)
		boxAt("RiftVoidFloor", CFrame.new(V(0, -6.35, -10)), V(860, 0.35, 880), rgb(16, 10, 34), Mat.SmoothPlastic, 0)

		-- Luminous glowing amethyst & magenta Rift glow pools snaking beneath Rifts A, B, C & foreground chasm!
		local riftGlowPools = {
			{ -155, -5.90, 148, 125, rgb(128, 56, 218), 0.50 },
			{ 0, -5.88, 152, 138, rgb(148, 66, 236), 0.44 },
			{ 148, -5.90, 148, 125, rgb(128, 56, 218), 0.50 },
			{ 230, -5.84, -12, 118, rgb(152, 64, 240), 0.42 },
			{ 65, -5.82, -6, 132, rgb(170, 80, 248), 0.38 },
			{ -100, -5.80, 4, 122, rgb(160, 74, 246), 0.40 },
			{ -235, -5.82, -138, 116, rgb(152, 68, 240), 0.42 },
			{ -108, -5.78, -158, 136, rgb(176, 84, 248), 0.36 },
			{ 68, -5.82, -132, 112, rgb(146, 62, 232), 0.44 },
			{ -115, -5.80, -218, 128, rgb(166, 76, 248), 0.38 },
			{ 132, -5.78, -244, 132, rgb(182, 88, 250), 0.36 },
			{ 235, -5.82, -264, 98, rgb(158, 70, 244), 0.42 },
		}
		for idx, rp in riftGlowPools do
			local disc = ctx.cyl("RiftGlowPool_" .. idx, V(rp[1], rp[2], rp[3]), rp[4], 0.16, rp[5], Mat.Neon)
			disc.Transparency = rp[6]
			if idx % 3 == 0 then
				disc:SetAttribute("ConjunctionGlyph", true)
				safeTag(disc, "ConjunctionGlyph")
			end
		end

		-- Bright glowing violet fracture veins pulsing along the deepest Rift axes
		local riftVeins = {
			{ V(320, -5.62, -14), V(185, -5.62, -10), V(-100, -5.62, 6), V(-170, -5.62, -8) },
			{ V(-320, -5.62, -132), V(-110, -5.62, -145), V(40, -5.62, -128), V(195, -5.62, -132) },
			{ V(-320, -5.62, -218), V(-110, -5.62, -215), V(140, -5.62, -246), V(248, -5.62, -265) },
		}
		for vIdx, chain in riftVeins do
			for i = 1, #chain - 1 do
				local seg = ctx.beam("RiftVeinGlow_" .. vIdx, chain[i], chain[i + 1], 16.0, RIFT_MAGENTA, Mat.Neon, 0.50)
				seg:SetAttribute("ConjunctionGlyph", true)
				safeTag(seg, "ConjunctionGlyph")
			end
		end

		-- Sparkling deep-space pinpoint stars around the outer void margins
		for i = 1, 110 do
			local sx = math.sin(i * 12.9898) * 390
			local sz = math.cos(i * 78.233) * 395 - 10
			local sSize = if i % 6 == 0 then 2.2 else 1.2
			local sCol = if i % 4 == 0 then GOLD_LIGHT elseif i % 3 == 0 then AURORA_TEAL else rgb(216, 208, 255)
			lump("VoidStarGlint", V(sx, -5.55, sz), V(sSize, 0.24, sSize), sCol, Mat.Neon)
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Floating fractured void rock fragments & deep violet chasm PointLights (Airborne + Exempt: "RiftBedGlows")
	ctx.group("RiftBedGlows", function()
		for idx, fr in {
			{ -122, 2.5, 146, 14, 10, 12, 18 },
			{ 118, 1.5, 148, 16, 11, 13, -24 },
			{ -318, 4.0, 188, 20, 14, 18, 28 },
			{ 318, 4.0, 188, 20, 14, 18, -28 },
			{ 82, 5.5, 8, 16, 12, 15, 34 },
			{ -25, 11.0, -136, 14, 10, 13, -15 },
			{ -188, 14.0, -162, 18, 12, 16, 22 },
			{ 78, 16.0, -242, 15, 11, 14, -32 },
			{ 288, 6.0, -6, 17, 12, 15, 19 },
		} do
			local cf = CFrame.new(V(fr[1], fr[2], fr[3])) * CFrame.Angles(math.rad(6), math.rad(fr[7]), math.rad(-5))
			boxAt("VoidShardTop_" .. idx, cf * CFrame.new(0, fr[5] * 0.45, 0), V(fr[4], 1.6, fr[6]), STONE_TOP, Mat.Slate)
			boxAt("VoidShardRock_" .. idx, cf * CFrame.new(0, -fr[5] * 0.1, 0), V(fr[4] * 0.86, fr[5], fr[6] * 0.86), CLIFF_ROCK, Mat.Slate)
			boxAt("VoidShardTip_" .. idx, cf * CFrame.new(0, -fr[5] * 0.65, 0), V(fr[4] * 0.48, fr[5] * 0.65, fr[6] * 0.48), CLIFF_DEEP, Mat.Slate)
		end
		for i, pt in {
			V(40, -1.5, 2),
			V(-105, -1.5, -155),
			V(125, -1.5, -240),
		} do
			local anchor = ctx.block("RiftGlowAnchor" .. i, V(2, 2, 2), pt, RIFT_VIOLET, Mat.SmoothPlastic, nil, 1)
			addLight(anchor, RIFT_VIOLET, 2.8, 120)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. FRACTURED GREY-SLATE CLIFF PLATES & INTEGRATED LANDMARK TERRACE BAYS
	-- All use PropKind = "AstralIsleDeck" (exempt from Walkway/Camp pruning, grounded to bottom!).
	-- =========================================================================
	local plateOrder = {
		"WestGallery", "Crossing", "EastGallery",
		"P2W", "P2C", "P2E",
		"P3C", "P3E", "P4C",
		"Engine", "Apex",
	}
	for idx, pid in plateOrder do
		local plat = P[pid]
		if plat then
			buildFracturedCliffIsland(pid, plat.X, plat.Y, plat.Z, plat.Width, plat.Depth, idx * 13 + 7)
		end
	end

	buildFracturedCliffIsland("ApexGalleryApse", -210, 52, -348, 134, 46, 101)
	buildFracturedCliffIsland("EngineCragTerrace", 262, 44, -342, 178, 66, 102)
	buildFracturedCliffIsland("EngineWestSpillBay", 206, 44, -300, 34, 38, 103)
	buildFracturedCliffIsland("P4CColophonBay", 60, 48, -344, 68, 30, 104)
	buildFracturedCliffIsland("WestGalleryBay", -278, 16, 70, 46, 68, 105)
	buildFracturedCliffIsland("EastGalleryBay", 264, 8, 75, 48, 68, 106)
	buildFracturedCliffIsland("P2WBinderyBay", -262, 28, -80, 44, 56, 107)
	buildFracturedCliffIsland("P2CDeskBay", -6, 24, -44, 34, 28, 108)
	buildFracturedCliffIsland("P2EErrataBay", 232, 20, -95, 42, 54, 109)
	buildFracturedCliffIsland("P3CLedgerBay", 22, 36, -212, 58, 28, 110)
	buildFracturedCliffIsland("P3EInkCellarBay", 290, 32, -185, 44, 56, 111)

	-- =========================================================================
	-- C. SANCTUARY (THE SHELFMARK STAIR) & BASIN (THE INDEX FLOOR + RULED COURT)
	-- Uses PropKind = "AstralConcourseDeck" (exempt from Walkway & Camp pruning!).
	-- =========================================================================
	local sanctuary = P.Sanctuary
	if sanctuary then
		local sx, sy, sz = sanctuary.X, sanctuary.Y, sanctuary.Z
		buildFracturedCliffIsland("SanctuaryBase", sx, sy, sz, sanctuary.Width, sanctuary.Depth, 201)
		ctx.group("AstralConcourseDeck", function()
			local frontZ = sz - sanctuary.Depth * 0.5 + 1.0
			balustradeSpan(sx - 62, frontZ, -17, frontZ, sy, true)
			balustradeSpan(17, frontZ, sx + 62, frontZ, sy, true)

			-- The Shelfmark Stair (Sanctuary -> Basin, Z = 312..274, Y = 8..0):
			-- Weathered slate steps with GLOWING CYAN/TEAL SHELFMARK RUNE GLYPHS on every tread (Image 1!)
			local steps = 10
			for s = 1, steps do
				local t = (s - 0.5) / steps
				local stepY = 8.0 * (1 - t)
				local stepZ = 312.0 + (274.0 - 312.0) * t
				boxAt("ShelfmarkTread", CFrame.new(V(0, stepY - 0.14, stepZ)), V(26.6, 0.45, 3.9), if s % 2 == 0 then STONE_LIGHT else STONE_TOP, Mat.Slate)
				boxAt("ShelfmarkBrassLip", CFrame.new(V(0, stepY + 0.12, stepZ - 1.85)), V(26.2, 0.14, 0.30), BRASS_AGED, Mat.Metal)
				for g = -2, 2 do
					if (s + g) % 2 == 0 or g == 0 then
						local gx = g * 4.4 + math.sin(s * 1.9 + g) * 0.9
						local gw = 1.6 + ((s + math.abs(g)) % 3) * 0.85
						local glyph = boxAt("ShelfmarkRune", CFrame.new(V(gx, stepY + 0.16, stepZ - 0.3)), V(gw, 0.08, 0.55), RUNE_CYAN, Mat.Neon, 0.08)
						glyph:SetAttribute("ConjunctionGlyph", true)
						safeTag(glyph, "ConjunctionGlyph")
					end
				end
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	local basin = P.Basin
	if basin then
		local bx, by, bz = basin.X, basin.Y, basin.Z
		local bw, bd = basin.Width, basin.Depth
		local halfW, halfD = bw * 0.5, bd * 0.5
		buildFracturedCliffIsland("BasinIndexFloor", bx, by, bz, bw, bd, 202)

		ctx.group("AstralConcourseDeck", function()
			local northZ = bz - halfD + 1.0
			local southZ = bz + halfD - 1.0
			local gaps: { { number } } = {}
			for _, link in ctx.layout.Links do
				if link.From == "Basin" or link.To == "Basin" then
					local ax = if link.From == "Basin" then link.AX else link.BX
					local bz2 = if link.From == "Basin" then link.BZ else link.AZ
					if bz2 < bz then
						local halfOpen = link.Width * 0.5 + 1.5
						table.insert(gaps, { ax - halfOpen, ax + halfOpen })
					end
				end
			end
			table.sort(gaps, function(g1, g2) return g1[1] < g2[1] end)
			local curX = -halfW + 8
			for _, g in gaps do
				if g[1] - curX >= 6 then
					balustradeSpan(curX, northZ, g[1], northZ, by, true)
				end
				curX = math.max(curX, g[2])
			end
			if (halfW - 8) - curX >= 6 then
				balustradeSpan(curX, northZ, halfW - 8, northZ, by, true)
			end
			balustradeSpan(-halfW + 8, southZ, -22, southZ, by, true)
			balustradeSpan(22, southZ, halfW - 8, southZ, by, true)
			balustradeSpan(-halfW + 1.5, northZ + 6, -halfW + 1.5, southZ - 6, by, false)
			balustradeSpan(halfW - 1.5, northZ + 6, halfW - 1.5, southZ - 6, by, false)

			-- ICONIC CENTER ARRIVAL ASTROLABE COURT & 8-LECTERN RING (X = 0, Z = 230, matching Image 1 foreground!)
			local cx, cz = 0, 230
			ctx.cyl("AstrolabeStoneRim", V(cx, by + 0.08, cz), 27.5, 0.22, STONE_LIGHT, Mat.Slate)
			ctx.cyl("AstrolabeInnerDisc", V(cx, by + 0.14, cz), 24.0, 0.16, STONE_TOP, Mat.Slate)
			ctx.ring("AstrolabeGoldOuter", V(cx, by + 0.23, cz), 27.2, 0.65, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
			ctx.ring("AstrolabeGoldInner", V(cx, by + 0.24, cz), 23.6, 0.48, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 28)
			ctx.ring("AstrolabeCoreRing", V(cx, by + 0.25, cz), 8.5, 0.36, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)
			for i = 0, 7 do
				local a = i * math.pi / 4
				local len = if i % 2 == 0 then 22.0 else 15.5
				local ray = boxAt("AstrolabeStarRay", CFrame.new(V(cx + math.cos(a) * (len * 0.5 + 1.0), by + 0.23, cz + math.sin(a) * (len * 0.5 + 1.0))) * CFrame.Angles(0, -a, 0), V(len, 0.10, if i % 2 == 0 then 1.05 else 0.62), GOLD_BRIGHT, Mat.Metal)
				ray:SetAttribute("ConjunctionGlyph", true)
				safeTag(ray, "ConjunctionGlyph")
			end
			boxAt("AstrolabeCrack1", CFrame.new(V(cx + 3, by + 0.26, cz - 1)) * CFrame.Angles(0, math.rad(28), 0), V(26, 0.12, 0.95), CLIFF_DEEP, Mat.Slate)
			boxAt("AstrolabeCrack2", CFrame.new(V(cx - 8, by + 0.26, cz + 5)) * CFrame.Angles(0, math.rad(-14), 0), V(16, 0.12, 0.72), CLIFF_DEEP, Mat.Slate)

			-- Ring of 8 ornate wooden/brass lecterns encircling the cracked astrolabe (wide open N/S central avenue!)
			for _, deg in { -145, -115, -65, -35, 35, 65, 115, 145 } do
				local a = math.rad(deg)
				local lx = cx + math.sin(a) * 23.2
				local lz = cz + math.cos(a) * 23.2
				local faceInYaw = math.deg(math.atan2(cx - lx, cz - lz))
				buildWoodenLectern(V(lx, by, lz), faceInYaw)
			end

			-- Fallen fluted marble column stubs & loose vellum pages framing Basin foreground (Image 1!)
			for _, colSpec in {
				{ -46, 250, 26, 9.5, 2.2 },
				{ 46, 250, -30, 9.5, 2.2 },
				{ -252, 242, 15, 8.0, 2.0 },
				{ 252, 242, -18, 8.0, 2.0 },
			} do
				local cf = CFrame.new(V(colSpec[1], by + colSpec[5] * 0.85, colSpec[2])) * CFrame.Angles(0, math.rad(colSpec[3]), math.pi / 2)
				local cyl = boxAt("FallenColumn", cf, V(colSpec[5] * 2, colSpec[4], colSpec[5] * 2), STONE_LIGHT, Mat.Marble)
				cyl.Shape = Enum.PartType.Cylinder
			end
			for i = 1, 18 do
				local px = -240 + i * 26 + math.sin(i * 3.1) * 14
				local pz = 210 + math.cos(i * 2.4) * 32
				boxAt("ScatteredPage", CFrame.new(V(px, by + 0.14, pz)) * CFrame.Angles(0, math.rad(i * 41), 0), V(2.4, 0.08, 1.8), VELLUM_PAGE, Mat.Fabric)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- D. THE LIFTED INDEX (APEX: BACK-WEST Y=52) — MOUNTAIN CRAGS, MOSAIC & GALLERY
	-- Uses PropKind = "AstralSanctumRays" & "AstralIsleBalustrade" (exempt!).
	-- =========================================================================
	local apex = P.Apex
	if apex then
		local ax, ay, az = apex.X, apex.Y, apex.Z
		ctx.group("AstralSanctumRays", function()
			ctx.cyl("LiftedMosaicOuter", V(ax, ay + 0.07, az), 38.0, 0.14, STONE_LIGHT, Mat.Slate)
			ctx.cyl("LiftedMosaicInner", V(ax, ay + 0.11, az), 24.0, 0.14, STONE_TOP, Mat.Slate)
			ctx.ring("LiftedGoldRing1", V(ax, ay + 0.19, az), 38.0, 0.65, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
			ctx.ring("LiftedGoldRing2", V(ax, ay + 0.20, az), 24.0, 0.45, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 26)
			ctx.ring("LiftedGoldRing3", V(ax, ay + 0.21, az), 12.0, 0.35, GOLD_LIGHT, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)

			buildStandingBookcase(V(-266, ay, -328), 78, 1.35)
			buildStandingBookcase(V(-154, ay, -336), -78, 1.35)

			-- Towering fractured mountain crags rising directly behind & west of LiftedIndexGallery (Image 1 top-left!)
			buildMountainCrag(V(-210, ay - 6, -372), V(94, 82, 30), 4, -8)
			buildMountainCrag(V(-276, ay - 6, -356), V(58, 72, 42), 24, -6)
			buildMountainCrag(V(-142, ay - 6, -358), V(54, 58, 36), -22, -6)
			buildMountainCrag(V(-292, ay - 14, -296), V(44, 54, 62), 12, -10)

			local sZ = az + apex.Depth * 0.5 - 1.2
			for _, lp in { V(-182, ay, sZ), V(-146, ay, sZ) } do
				ctx.cyl("StairHeadLampPost", lp + V(0, 6.2, 0), 0.55, 12.4, BRASS_AGED, Mat.Metal)
				local orb = lump("StairHeadLampBulb", lp + V(0, 12.8, 0), V(2.4, 2.8, 2.4), GOLD_LIGHT, Mat.Neon)
				orb:SetAttribute("ConjunctionLamp", true)
				safeTag(orb, "ConjunctionLamp")
				addLight(orb, GOLD_LIGHT, 2.0, 65)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		ctx.group("AstralIsleBalustrade", function()
			local sZ = az + apex.Depth * 0.5 - 1.2
			local wX = ax - apex.Width * 0.5 + 1.5
			local eX = ax + apex.Width * 0.5 - 1.5
			balustradeSpan(wX + 4, sZ, -182, sZ, ay, true)
			balustradeSpan(wX, az - 42, wX, sZ - 4, ay, true)
			balustradeSpan(eX, -270, eX, sZ - 4, ay, true)
			balustradeSpan(eX, -334, eX, -310, ay, true)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- E. LANDMARKS (1..20) — COHESIVE, REPOSITIONED & 100% GROUNDED!
	-- =========================================================================

	-- 1–3. THE BROKEN INDEX ENGINE (Back-East Y=44):
	do
		local core = AstralFloor43.Landmarks[1]
		local mc = piece("IndexEngineCore", core.X, core.Z, -18, "IndexEngineCore", 1.0, RIFTWARD_43, function(cf)
			boxAt("EngineLeft", cf * CFrame.new(-16, 86, 0) * CFrame.Angles(0, 0, math.rad(5)), V(24, 172, 22), RIFTWARD_43.METAL.Color, Mat.Metal)
			boxAt("EngineRight", cf * CFrame.new(16, 86, 0) * CFrame.Angles(0, 0, math.rad(-5)), V(24, 172, 22), RIFTWARD_43.METAL.Color, Mat.Metal)
			lump("EngineRiftCrack", (cf * CFrame.new(0, 74, 4)).Position, V(10, 90, 6), RIFT_VIOLET, Mat.Neon)
		end, core.Y)
		pin(mc)
		if mc then addLight(H.glowOf(mc), GOLD_LIGHT, 2.4, 125) end

		local gb = AstralFloor43.Landmarks[2]
		local mgb = piece("IndexEngineGearBank", gb.X, gb.Z, -18, "IndexEngineGearBank", 1.32, RIFTWARD_43, function(cf)
			boxAt("GearBank", cf * CFrame.new(0, 46, 0), V(94, 94, 12), RIFTWARD_43.METAL.Color, Mat.Metal)
		end, gb.Y)
		pin(mgb)
		if mgb then addLight(mgb.PrimaryPart or mgb:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.0, 115) end

		local st = AstralFloor43.Landmarks[3]
		pin(piece("IndexEngineShelfTower", st.X, st.Z, -32, "IndexEngineShelfTower", 1.05, LIBRARY_TINT, function(cf)
			boxAt("ShelfTower", cf * CFrame.new(0, 46, 0), V(32, 92, 14), WOOD_WARM, Mat.Wood)
		end, st.Y))

		local stW = piece("IndexEngineShelfTowerWest", 190, -342, -6, "IndexEngineShelfTower", 0.96, LIBRARY_TINT, function(cf)
			boxAt("ShelfTowerW", cf * CFrame.new(0, 44, 0), V(30, 88, 14), WOOD_WARM, Mat.Wood)
		end, core.Y)
		pin(stW)
		makeDecor(stW)

		ctx.group("AstralIsleDeck", function()
			buildMountainCrag(V(338, core.Y - 8, -354), V(52, 68, 42), -18, -6)
			buildMountainCrag(V(172, core.Y - 8, -356), V(48, 56, 38), 22, -6)
			for i = 1, 22 do
				local px = 216 + (i % 7) * 14 + math.sin(i * 2.1) * 6
				local pz = -336 + math.floor(i / 7) * 11 + math.cos(i * 1.7) * 4
				boxAt("EngineSpillPage", CFrame.new(V(px, (core.Y :: number) + 0.16 + (i % 3) * 0.08, pz)) * CFrame.Angles(0, math.rad(i * 33), 0), V(3.2, 0.14, 2.4), VELLUM_PAGE, Mat.Fabric)
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 4. THE LIFTED INDEX GALLERY (Prominent curved two-tier mahogany library rotunda solidly grounded behind Apex!)
	do
		local lm = AstralFloor43.Landmarks[4]
		local mg = piece("LiftedIndexGallery", lm.X, lm.Z, 0, "LiftedIndexGallery", 1.44, LIBRARY_TINT, function(cf)
			boxAt("LiftedGallery", cf * CFrame.new(0, 18, 0), V(74, 36, 24), WOOD_WARM, Mat.Wood)
		end, lm.Y)
		pin(mg)
		if mg then addLight(H.glowOf(mg) or mg:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.6, 120) end
	end

	-- 5–15. Grounded Plate Landmarks
	local plateSpecs = {
		{ AstralFloor43.Landmarks[5], "ColophonWall", 0, LIBRARY_TINT, 1.08 },
		{ AstralFloor43.Landmarks[6], "BinderyPress", 90, LIBRARY_TINT, 1.15 },
		{ AstralFloor43.Landmarks[7], "ErrataPress", -90, LIBRARY_TINT, 1.12 },
		{ AstralFloor43.Landmarks[8], "CatalogueDeskTilted", 18, LIBRARY_TINT, 1.15 },
		{ AstralFloor43.Landmarks[9], "LedgerStackTall", 0, LIBRARY_TINT, 1.15 },
		{ AstralFloor43.Landmarks[10], "InkVatCracked", -80, INK_VAT_TINT, 1.18 },
		{ AstralFloor43.Landmarks[11], "ToppledShelfRange", 72, LIBRARY_TINT, 1.10 },
		{ AstralFloor43.Landmarks[12], "ToppledShelfRange", -72, LIBRARY_TINT, 1.10 },
		{ AstralFloor43.Landmarks[13], "CardDrawerSpill", 25, LIBRARY_TINT, 1.18 },
		{ AstralFloor43.Landmarks[14], "BrokenOrreryRing", 35, RIFTWARD_43, 1.25 },
		{ AstralFloor43.Landmarks[15], "BrokenOrreryRing", -35, RIFTWARD_43, 1.25 },
	}
	for _, spec in plateSpecs do
		local lm = spec[1]
		local m = piece(lm.Id, lm.X, lm.Z, spec[3], spec[2], spec[5], spec[4], function(cf)
			boxAt(lm.Id .. "Fallback", cf * CFrame.new(0, lm.Top * 0.5, 0), V(lm.HalfX * 1.8, lm.Top, lm.HalfZ * 1.8), WOOD_WARM, Mat.Wood)
		end, lm.Y)
		pin(m)
		if spec[2] == "CardDrawerSpill" or spec[2] == "CatalogueDeskTilted" then
			tagDetail(m)
		end
	end

	-- Extra rich library dressing grounded solidly on the integrated cliff bays (PropKind = "AstralIsleDeck" so never pruned!)
	ctx.group("AstralIsleDeck", function()
		buildStandingBookcase(V(-292, 16, 48), 96, 1.15)
		buildStandingBookcase(V(-294, 16, 86), 82, 1.10)
		buildMountainCrag(V(-316, 12, 72), V(32, 42, 64), 10, -8)

		buildStandingBookcase(V(278, 8, 52), -96, 1.15)
		buildStandingBookcase(V(280, 8, 92), -80, 1.10)
		buildMountainCrag(V(304, 4, 76), V(32, 42, 64), -10, -8)

		buildStandingBookcase(V(-276, 28, -96), 72, 1.05)
		ctx.cyl("BinderyColumnStub", V(-272, 32.5, -62), 2.3, 9.0, STONE_LIGHT, Mat.Marble)

		buildStandingBookcase(V(-56, 24, -100), 6, 1.05)
		buildStandingBookcase(V(-8, 36, -214), 12, 1.08)
		buildStandingBookcase(V(42, 36, -214), -14, 1.05)

		buildStandingBookcase(V(302, 32, -168), -102, 1.10)
		buildMountainCrag(V(60, 42, -366), V(68, 44, 24), 4, -6)

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Companion spilled indigo ink vat on WestGallery south-west bay (Image 1 bottom-left!)
	do
		local wVat = piece("WestrangeInkVat", -268, 96, 40, "InkVatCracked", 1.05, INK_VAT_TINT, function(cf)
			ctx.cyl("WestInkPuddle", cf.Position + V(0, 0.2, 0), 5.0, 0.3, rgb(64, 52, 164), Mat.Glass)
		end, 16)
		pin(wVat)
		tagDetail(wVat)
	end

	-- Companion tilted reading desks on WestGallery, EastGallery & P3C/P3E bays
	for _, dSpec in {
		{ -268, 54, 16, 115, 1.05 },
		{ 258, 58, 8, -110, 1.05 },
		{ 40, -198, 36, -20, 1.0 },
		{ 284, -166, 32, -75, 1.0 },
	} do
		local md = piece("StudyDeskExtra", dSpec[1], dSpec[2], dSpec[4], "CatalogueDeskTilted", dSpec[5], LIBRARY_TINT, function(cf)
			boxAt("DeskFallback", cf * CFrame.new(0, 2.5, 0), V(8, 5, 6), WOOD_WARM, Mat.Wood)
		end, dSpec[3])
		pin(md)
		tagDetail(md)
	end

	-- 16–18. Scarp Shelf Strata embedded FLUSH into the fractured rocky cliff faces (PropKind = "AstralIsleUnderside" so never dropped!)
	for _, row in {
		{ AstralFloor43.Landmarks[16], 180 },
		{ AstralFloor43.Landmarks[17], 180 },
		{ AstralFloor43.Landmarks[18], 0 },
	} do
		local lm = row[1]
		local ms = piece("AstralIsleUnderside", lm.X, lm.Z, row[2], "ScarpShelfStrata", 1.0, LIBRARY_TINT, function(cf)
			boxAt("ShelfStrata", cf * CFrame.new(0, 8, 0), V(32, 16, 10), CLIFF_ROCK, Mat.Slate)
		end, lm.Y)
		pin(ms)
		makeDecor(ms)
	end
	for _, extraStrata in {
		{ -278, 105, -2, 0 },
		{ 264, 110, -8, 0 },
		{ -210, -234, 34, 0 },
		{ -40, -44, 6, 0 },
	} do
		local ms = piece("AstralIsleUnderside", extraStrata[1], extraStrata[2], extraStrata[4], "ScarpShelfStrata", 0.96, LIBRARY_TINT, function(cf)
			boxAt("ShelfStrataExtra", cf * CFrame.new(0, 8, 0), V(30, 16, 9), CLIFF_ROCK, Mat.Slate)
		end, extraStrata[3])
		pin(ms)
		makeDecor(ms)
	end

	-- 19–20. Sculpted Page Fall Ribbons anchored directly onto real cliff lips pouring into the glowing violet rifts!
	for _, idx in { 19, 20 } do
		local lm = AstralFloor43.Landmarks[idx]
		local mp = piece("AstralIsleUnderside", lm.X, lm.Z, 0, "PageFallRibbon", 1.65, RIFTWARD_43, function(cf)
			boxAt("PageCascade", cf * CFrame.new(0, 10, 0), V(8, 20, 10), VELLUM_PAGE, Mat.Fabric)
		end, lm.Y)
		pin(mp)
		makeDecor(mp)
		pageEmitter(V(lm.X, (lm.Y :: number) + 14, lm.Z), 4)
	end
	for _, extra in {
		{ -258, 16, 106, 12, 1.55 },   -- WestGallery SW cliff lip pouring into foreground chasm (Image 1 bottom-left!)
		{ 246, 8, 112, -16, 1.45 },    -- EastGallery SE cliff lip pouring into foreground chasm (Image 1 bottom-right!)
		{ 20, 36, -144, 0, 1.60 },     -- P3C Ledger Plate south cliff lip cascading into Rift B!
		{ 212, 44, -278, 28, 1.75 },   -- Broken Index Engine cliff lip pouring into Rift C!
	} do
		local mp = piece("AstralIsleUnderside", extra[1], extra[3], extra[4], "PageFallRibbon", extra[5], RIFTWARD_43, function(cf)
			boxAt("PageCascade", cf * CFrame.new(0, 10, 0), V(8, 20, 10), VELLUM_PAGE, Mat.Fabric)
		end, extra[2] - 24)
		pin(mp)
		makeDecor(mp)
	end

	-- =========================================================================
	-- F. FLOATING JAGGED SHARD ISLANDS, HANGING BRASS CHAINS & CROOKED INDEX LAMPS
	-- =========================================================================
	for _, row in {
		{ "ShardA", "ShardSlabM", 25.114, 29.314, 22.261, 56, 48, 24.0 },
		{ "ShardE", "ShardSlabM", 25.114, 29.314, 22.261, 56, 48, 16.0 },
		{ "ShardB", "ShardSlabL", 38.027, 35.314, 32.010, 56, 48, 34.0 },
		{ "ShardC", "ShardSlabM", 25.114, 29.314, 22.261, 56, 48, 36.0 },
	} do
		local id: string = row[1]
		local plat = P[id]
		if not plat then continue end
		local kitName: string = row[2]
		local kitW: number, kitH: number, kitD: number = row[3], row[4], row[5]
		local pw: number, pd: number = row[6], row[7]
		local wantDepth: number = row[8]
		local availH = math.max(10.0, math.min(wantDepth, (plat.Y - 2.6) - (bottom - 0.5)))

		ctx.group("AstralIsleUnderside", function()
			boxAt(id .. "ShardRim", CFrame.new(V(plat.X, plat.Y - 0.85, plat.Z)), V(pw + 1.2, 1.7, pd + 1.2), STONE_TOP, Mat.Slate)
			boxAt(id .. "ShardBrassBand", CFrame.new(V(plat.X, plat.Y - 1.85, plat.Z)), V(pw + 1.5, 0.42, pd + 1.5), BRASS_AGED, Mat.Metal)
			boxAt(id .. "ShardCrack", CFrame.new(V(plat.X, plat.Y + 0.08, plat.Z)) * CFrame.Angles(0, math.rad(24), 0), V(pw * 0.65, 0.08, 0.72), CLIFF_DEEP, Mat.Slate)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		local sx = (pw * 1.06) / kitW
		local sy = availH / kitH
		local sz = (pd * 1.06) / kitD
		local ms = placeKitScaled("AstralIsleUnderside", plat.X, (plat.Y - 2.4) - availH, plat.Z, (plat.X * 0.3) % 360, kitName, V(sx, sy, sz), SHARD_UNDERSIDE_TINT, function(cf)
			ctx.cyl("ShardUndersideCone", cf.Position + V(0, availH * 0.5, 0), pw * 0.44, availH, CLIFF_ROCK, Mat.Slate)
		end)
		makeDecor(ms)
	end

	-- Iconic catenary hanging brass chains anchoring floating shards across the violet chasm (Airborne + Exempt!)
	ctx.group("AstralIsleUnderside", function()
		local chainPairs = {
			{ V(-126, 15, 16), V(-182, 13, 46), 11, 8 },
			{ V(-76, 15, 22), V(-46, 10, 56), 9, 8 },
			{ V(-122, 15, -18), V(-182, 24, -56), 12, 8 },
			{ V(166, 8, 8), V(164, 6, 46), 8, 6 },
			{ V(212, 8, -26), V(206, 17, -68), 10, 8 },
			{ V(-134, 27, -148), V(-180, 25, -104), 12, 8 },
			{ V(-84, 27, -144), V(-58, 21, -102), 11, 8 },
			{ V(-130, 27, -186), V(-186, 46, -242), 16, 10 },
			{ V(116, 37, -230), V(54, 33, -196), 12, 8 },
			{ V(162, 37, -262), V(220, 40, -282), 11, 8 },
			{ V(-122, 2, 146), V(-184, 10, 104), 10, 8 },
			{ V(118, 1, 148), V(164, 4, 108), 10, 8 },
		}
		for _, cp in chainPairs do
			buildHangingChain(cp[1], cp[2], cp[3], cp[4])
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Warm glowing Crooked Index Lamps on all 4 floating shards + key bridgeheads
	local lampSpecs = {
		{ -122, 18, 22, 35, true },
		{ 212, 10, 6, -45, true },
		{ -132, 30, -146, 55, true },
		{ 162, 40, -228, -55, true },
		{ -46, 12, 110, 18, true },
		{ -238, 28, -56, 40, true },
		{ 208, 20, -70, -40, true },
		{ 48, 36, -150, -25, false },
		{ 226, 44, -278, 32, true },
	}
	for _, sp in lampSpecs do
		local ml = piece("AstralIndexLamp", sp[1], sp[3], sp[4], "CrookedIndexLamp", 1.08, RIFTWARD_43, function(cf)
			ctx.cyl("CrookedPost", cf.Position + V(0, 6, 0), 0.7, 12, BRASS_AGED, Mat.Metal)
			lump("CrookedBulb", cf.Position + V(0, 11.5, 0), V(2.2, 2.8, 2.2), GOLD_LIGHT, Mat.Neon)
		end, sp[2])
		pin(ml)
		tagDetail(ml)
		if ml then
			ml:SetAttribute("ConjunctionLamp", true)
			safeTag(ml, "ConjunctionLamp")
			if sp[5] then
				addLight(H.glowOf(ml), GOLD_LIGHT, 1.9, 60)
			end
		end
	end

	-- =========================================================================
	-- G. WISPY VOLUMETRIC SPLIT VIOLET-TEAL AURORA CURTAINS & SKY-RIFT LIGHTNING
	-- Soft, translucent, graceful high-altitude ribbons matching Image 1's sky!
	-- =========================================================================
	ctx.group("AstralSplitAurora", function()
		-- Two long, continuous graceful curves (zero blocky segment kinks, soft ethereal transparency!)
		addAuroraCurtain("AuroraTealSweep", V(-270, 215, -360), V(250, 265, -420), 34, 46, AURORA_TEAL, rgb(104, 232, 212), 0.68)
		addAuroraCurtain("AuroraVioletSweep", V(-210, 198, -345), V(290, 240, -405), 40, 52, RIFT_VIOLET, RIFT_MAGENTA, 0.66)
		addAuroraCurtain("AuroraTealWisp", V(-130, 234, -385), V(165, 258, -415), 18, 24, rgb(136, 248, 230), AURORA_TEAL, 0.74)

		local lightningBranches = {
			{ V(-220, 175, -340), V(-172, 202, -358), V(-138, 224, -372), V(-104, 246, -384) },
			{ V(-172, 202, -358), V(-202, 228, -368) },
			{ V(256, 196, -350), V(304, 216, -368), V(354, 236, -384), V(398, 256, -396) },
			{ V(304, 216, -368), V(332, 194, -362) },
		}
		for bIdx, pts in lightningBranches do
			for i = 1, #pts - 1 do
				local crack = ctx.beam("SkyRiftLightning_" .. bIdx, pts[i], pts[i + 1], 0.95, RUNE_CYAN, Mat.Neon, 0.25)
				crack:SetAttribute("ConjunctionGlyph", true)
				safeTag(crack, "ConjunctionGlyph")
				local halo = ctx.beam("SkyRiftLightningHalo_" .. bIdx, pts[i], pts[i + 1], 3.2, RIFT_VIOLET, Mat.Neon, 0.78)
				halo:SetAttribute("ConjunctionGlyph", true)
				safeTag(halo, "ConjunctionGlyph")
			end
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	pageEmitter(V(240, 54, -298), 4)
	pageEmitter(V(-110, 36, -165), 3)
	pageEmitter(V(-210, 58, -285), 3)
	pageEmitter(V(-8, 24, -30), 3)

	ctx.setAttribute("AstralFloor", 43)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor43
