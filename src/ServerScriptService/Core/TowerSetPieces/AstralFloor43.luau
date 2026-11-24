--!strict
-- Hand-authored set pieces for Astral Archives Floor 43: Fractured Index (astral:3, TERRAIN_VARIATION).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 43) & reference/Astral Archives 43.jpg.
--
-- Where the Index Engine broke: a compact, dramatic archipelago of tall craggy grey-slate cliff islands
-- plunging deep into a dark misty violet Rift abyss, linked by short flush-anchored stone-and-brass bridges
-- and chained floating shard decks; foreground Ruled Court with cracked circular astrolabe, 8 wooden lecterns,
-- twin golden armillary spheres and cyan-runed Shelfmark Stair; back-west Lifted Index Gallery nestled in
-- mountain crags atop a grand lantern-lit staircase; back-east 180-stud split Index Engine with interlocking
-- bronze gears, flanking shelf towers & cascading page waterfalls; and wispy teal-violet aurora arching
-- across the starry sky between both peaks.
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
-- aged antique brass & worn gold leaf, ivory vellum pages, pale starlight gold lamps, and moody void violet
-- strictly in the deep chasm depths & sky aurora.
local RIFTWARD_43 = table.freeze({
	STONE = swatch(138, 144, 160, Mat.Slate),
	ALT = swatch(56, 62, 84, Mat.Slate),
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
	ALT = swatch(52, 58, 78, Mat.Slate),
	METAL = swatch(176, 142, 78, Mat.Metal),
	TRIM = swatch(212, 180, 102, Mat.Metal),
	CRYSTAL = swatch(136, 86, 214, Mat.Neon, 0.34),
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
local CLIFF_ROCK = rgb(54, 60, 78)
local CLIFF_MID = rgb(44, 48, 66)
local CLIFF_DEEP = rgb(32, 36, 52)
local GOLD_BRIGHT = rgb(222, 188, 106)
local BRASS_AGED = rgb(178, 144, 78)
local WOOD_WARM = rgb(104, 68, 44)
local WOOD_DARK = rgb(74, 48, 34)
local VELLUM_PAGE = rgb(242, 234, 216)

local RIFT_VIOLET = rgb(134, 68, 218)
local RIFT_MAGENTA = rgb(168, 78, 224)
local AURORA_TEAL = rgb(86, 224, 206)
local RUNE_CYAN = rgb(96, 218, 248)
local GOLD_LIGHT = rgb(252, 226, 154)

-- Deep visual abyss floor so every cliff island plunges 34..86 studs down into moody misty depths!
local ABYSS_Y = -36

-- Floor 43's 20 landmark footprints (local floor space, 720 x 750, tightened compact archipelago).
-- Every single landmark is 100% grounded on its plate or integrated fractured cliff terrace bay, and
-- spec-checked against all walkway lanes, camps (>= 34 studs), portals (>= 12 studs) and room bounds.
AstralFloor43.Landmarks = table.freeze({
	-- 1. Index Engine Core (>= 175 studs, 183 studs at 1.02) split down the middle behind Engine terrace
	{ Id = "IndexEngineCore", X = 212, Z = -328, Y = 44, HalfX = 35.0, HalfZ = 13.8, Top = 183.3 },
	-- 2. Index Engine Gear Bank rising directly behind IndexEngineCore (cohesive machine silhouette!)
	{ Id = "IndexEngineGearBank", X = 220, Z = -346, Y = 44, HalfX = 45.6, HalfZ = 7.2, Top = 88.0 },
	-- 3. Index Engine Shelf Tower tightly flanking east side of IndexEngineCore
	{ Id = "IndexEngineShelfTower", X = 278, Z = -316, Y = 44, HalfX = 18.4, HalfZ = 8.0, Top = 93.0 },
	-- 4. Lifted Index Gallery grounded solidly on Apex's integrated north terrace & crag behind portals (-300)
	{ Id = "LiftedIndexGallery", X = -172, Z = -340, Y = 52, HalfX = 36.0, HalfZ = 14.0, Top = 35.6 },
	-- 5. Colophon Wall grounded on P4C's integrated north stone terrace
	{ Id = "ColophonWall", X = 38, Z = -330, Y = 48, HalfX = 13.6, HalfZ = 2.0, Top = 16.8 },
	-- 6. Bindery Press (wooden screw press + gold thread spools) grounded on P2W's western terrace bay
	{ Id = "BinderyPress", X = -228, Z = -64, Y = 28, HalfX = 8.4, HalfZ = 3.6, Top = 12.4 },
	-- 7. Errata Press grounded on P2E's eastern terrace bay
	{ Id = "ErrataPress", X = 208, Z = -100, Y = 20, HalfX = 6.5, HalfZ = 3.2, Top = 9.7 },
	-- 8. Reading Plate Tilted Desk grounded on P2C's south-east cliff shelf
	{ Id = "ReadingTiltedDesk", X = 14, Z = -30, Y = 24, HalfX = 4.8, HalfZ = 5.0, Top = 6.0 },
	-- 9. Ledger Plate Tall Ledger Stack grounded on P3C's northern cliff bay
	{ Id = "LedgerStackTall", X = 18, Z = -212, Y = 36, HalfX = 5.0, HalfZ = 4.8, Top = 14.1 },
	-- 10. Ink-Cellar Cracked Ink Vat grounded on P3E's eastern cliff bay
	{ Id = "InkCellarVat", X = 248, Z = -182, Y = 32, HalfX = 4.8, HalfZ = 7.0, Top = 5.8 },
	-- 11. Toppled Shelf Range grounded on WestGallery's integrated western cliff terrace bay
	{ Id = "WestrangeToppledShelf", X = -236, Z = 76, Y = 16, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 12. Toppled Shelf Range grounded on EastGallery's integrated eastern cliff terrace bay
	{ Id = "EastrangeToppledShelf", X = 234, Z = 78, Y = 8, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 13. Card Drawer Spill tumbling from Engine across its western ledge toward Rift C
	{ Id = "EngineCardSpill", X = 156, Z = -282, Y = 44, HalfX = 6.0, HalfZ = 4.4, Top = 2.4 },
	-- 14. Broken Orrery Ring + fallen column grounded solidly on Basin west foreground terrace
	{ Id = "BrokenOrreryRingW", X = -168, Z = 250, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 15. Broken Orrery Ring + fallen column grounded solidly on Basin east foreground terrace
	{ Id = "BrokenOrreryRingE", X = 168, Z = 250, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 16. Scarp Shelf Strata embedded flush into WestGallery's north-west rocky cliff face
	{ Id = "ScarpStrataWest", X = -234, Z = 36, Y = 0, HalfX = 16.8, HalfZ = 6.0, Top = 16.0 },
	-- 17. Scarp Shelf Strata embedded flush into P2W's north-west rocky cliff face
	{ Id = "ScarpStrataP2W", X = -232, Z = -96, Y = 10, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 18. Scarp Shelf Strata embedded flush into P3E's north-east rocky cliff face
	{ Id = "ScarpStrataP3E", X = 248, Z = -216, Y = 14, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 19. Page Fall Ribbon cascading directly off Reading Plate's south-east cliff lip into Rift A
	{ Id = "PageFallRiftA", X = 14, Z = -18, Y = 0, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
	-- 20. Page Fall Ribbon cascading directly off Ledger Plate's north-west cliff lip into Rift C
	{ Id = "PageFallRiftC", X = -10, Z = -206, Y = 12, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
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

	local function riftMistEmitter(pos: Vector3, spread: number)
		if emittersUsed >= 10 then return end
		emittersUsed += 1
		local anchor = ctx.block("RiftMistAnchor", V(spread, 2, spread), pos, RIFT_VIOLET, Mat.SmoothPlastic, nil, 1)
		anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = false, false, false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "RiftVioletMist"
		pe.Color = ColorSequence.new(rgb(138, 66, 224), rgb(82, 34, 152))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(0.5, 22), NumberSequenceKeypoint.new(1, 28) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.84), NumberSequenceKeypoint.new(0.75, 0.88), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(5.0, 8.0)
		pe.Rate = 2.5
		pe.Speed = NumberRange.new(1.2, 2.8)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.LightEmission = 0.55
		pe.EmissionDirection = Enum.NormalId.Top
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

	-- Helper: build a tall, craggy, multi-tiered rocky slate cliff massif plunging deep into the dark violet abyss.
	-- Uses PropKind = "AstralIsleDeck" (exempt from Walkway & Camp pruning, pinned with OnTerrain = true).
	local function buildFracturedCliffIsland(id: string, x: number, y: number, z: number, w: number, d: number, seed: number)
		local cliffBottom = ABYSS_Y + 1.0
		local totalH = math.max(24.0, y - cliffBottom)
		ctx.group("AstralIsleDeck", function()
			-- Thick weathered stone coping rim + antique brass frieze directly beneath the walking slab
			boxAt(id .. "DeckLip", CFrame.new(V(x, y - 0.85, z)), V(w + 1.4, 1.7, d + 1.4), STONE_TOP, Mat.Slate)
			boxAt(id .. "BrassUnderTrim", CFrame.new(V(x, y - 1.85, z)), V(w + 1.8, 0.42, d + 1.8), BRASS_AGED, Mat.Metal)

			-- Multi-tiered tapered cliff core plunging deep into the abyss (never thin wafer slabs!)
			local hullH = totalH - 2.0
			local h1, h2, h3 = hullH * 0.34, hullH * 0.36, hullH * 0.34
			boxAt(id .. "CliffTier1", CFrame.new(V(x, y - 2.0 - h1 * 0.5, z)), V(w - 1.0, h1, d - 1.0), CLIFF_ROCK, Mat.Slate)
			boxAt(id .. "CliffTier2", CFrame.new(V(x, y - 2.0 - h1 * 0.85 - h2 * 0.5, z)), V(w * 0.86, h2, d * 0.86), CLIFF_MID, Mat.Slate)
			boxAt(id .. "CliffTier3", CFrame.new(V(x, cliffBottom + h3 * 0.5, z)), V(w * 0.66, h3, d * 0.66), CLIFF_DEEP, Mat.Slate)

			-- Tall angled jagged rock crags wrapping corners & cliff walls, tapering inward toward the depths
			local halfW, halfD = w * 0.5, d * 0.5
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local rockW = math.min(24, w * 0.28)
					local rockD = math.min(24, d * 0.28)
					local rockH = hullH * (0.74 + ((seed + sx * 3 + sz * 5) % 3) * 0.08)
					local rx = x + sx * (halfW - rockW * 0.34)
					local rz = z + sz * (halfD - rockD * 0.34)
					local cf = CFrame.new(V(rx, y - 2.2 - rockH * 0.5, rz))
						* CFrame.Angles(math.rad(-sz * 8), math.rad((seed * 17 + sx * 11 + sz * 7) % 24 - 12), math.rad(sx * 8))
					boxAt(id .. "CornerCrag", cf, V(rockW, rockH, rockD), if (sx + sz) == 0 then CLIFF_ROCK else CLIFF_MID, Mat.Slate)
				end
			end
			local nRibsX = math.clamp(math.floor(w / 44), 2, 6)
			for i = 1, nRibsX do
				local rx = x - halfW + (w * i / (nRibsX + 1))
				for _, sz in { -1, 1 } do
					local rh = hullH * (0.64 + ((i + seed) % 3) * 0.11)
					local cf = CFrame.new(V(rx, y - 2.1 - rh * 0.5, z + sz * (halfD - 3.6)))
						* CFrame.Angles(math.rad(-sz * 9), math.rad(((i * 23 + seed) % 16) - 8), 0)
					boxAt(id .. "WallCragZ", cf, V(18, rh, 12), if i % 2 == 0 then CLIFF_ROCK else CLIFF_MID, Mat.Slate)
				end
			end
			local nRibsZ = math.clamp(math.floor(d / 38), 1, 4)
			for i = 1, nRibsZ do
				local rz = z - halfD + (d * i / (nRibsZ + 1))
				for _, sx in { -1, 1 } do
					local rh = hullH * (0.62 + ((i + seed) % 3) * 0.11)
					local cf = CFrame.new(V(x + sx * (halfW - 3.6), y - 2.1 - rh * 0.5, rz))
						* CFrame.Angles(0, math.rad(((i * 19 + seed) % 16) - 8), math.rad(sx * 9))
					boxAt(id .. "WallCragX", cf, V(12, rh, 18), if i % 2 == 0 then CLIFF_MID else CLIFF_ROCK, Mat.Slate)
				end
			end

			-- Subtle weathered stone flagstones & hairline fracture fissures across the walking deck
			local nFlags = math.clamp(math.floor((w * d) / 620), 4, 14)
			for k = 1, nFlags do
				local fx = x + math.sin(k * 2.13 + seed) * (halfW * 0.72)
				local fz = z + math.cos(k * 1.71 + seed * 1.3) * (halfD * 0.70)
				local fw = 8.0 + ((k * 7 + seed) % 6)
				local fd = 6.5 + ((k * 5 + seed) % 5)
				local fcf = CFrame.new(V(fx, y + 0.04 + (k % 3) * 0.015, fz)) * CFrame.Angles(0, math.rad(((k * 17 + seed) % 16) - 8), 0)
				boxAt(id .. "Flagstone", fcf, V(fw, 0.08, fd), if k % 2 == 0 then STONE_LIGHT else STONE_DARK, Mat.Slate)
			end
			local crackCF = CFrame.new(V(x + math.sin(seed) * halfW * 0.15, y + 0.08, z + math.cos(seed) * halfD * 0.15))
				* CFrame.Angles(0, math.rad((seed * 37) % 140 - 70), 0)
			boxAt(id .. "FloorCrack", crackCF, V(math.min(w, d) * 0.56, 0.06, 0.75), CLIFF_DEEP, Mat.Slate)

			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	local function buildHangingChain(p0: Vector3, p1: Vector3, sag: number, segs: number)
		local prev = p0
		for i = 1, segs do
			local t = i / segs
			local nextPt = p0:Lerp(p1, t) - V(0, 4 * t * (1 - t) * sag, 0)
			ctx.beam("ChasmBrassChain", prev, nextPt, 0.72, BRASS_AGED, Mat.Metal)
			prev = nextPt
		end
	end

	-- Sculpted stepped rocky slate mountain spire (tapered multi-faceted peak, never a flat cube!)
	local function buildMountainCrag(pos: Vector3, size: Vector3, yawDeg: number, tiltDeg: number)
		local baseCF = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
		-- Broad faceted base massif anchored down into the abyss
		boxAt("MountainCragBase", baseCF * CFrame.new(0, size.Y * 0.12, 0) * CFrame.Angles(math.rad(tiltDeg * 0.4), math.rad(8), math.rad(-tiltDeg * 0.3)),
			V(size.X * 1.05, size.Y * 0.52, size.Z * 1.05), CLIFF_DEEP, Mat.Slate)
		-- Stepped mid-slope crag shoulder
		boxAt("MountainCragMid", baseCF * CFrame.new(-size.X * 0.08, size.Y * 0.44, size.Z * 0.06) * CFrame.Angles(math.rad(tiltDeg), math.rad(-14), math.rad(tiltDeg * 0.6)),
			V(size.X * 0.74, size.Y * 0.52, size.Z * 0.72), CLIFF_ROCK, Mat.Slate)
		-- Secondary angled rock buttress on the opposite flank
		boxAt("MountainCragShoulder", baseCF * CFrame.new(size.X * 0.24, size.Y * 0.30, -size.Z * 0.06) * CFrame.Angles(math.rad(-tiltDeg * 0.7), math.rad(22), math.rad(-14)),
			V(size.X * 0.50, size.Y * 0.46, size.Z * 0.56), CLIFF_MID, Mat.Slate)
		-- Pointed upper summit ridge tapering sharply toward the night sky
		boxAt("MountainCragPeak", baseCF * CFrame.new(-size.X * 0.04, size.Y * 0.74, 0) * CFrame.Angles(math.rad(tiltDeg * 1.2), math.rad(28), math.rad(14)),
			V(size.X * 0.40, size.Y * 0.36, size.Z * 0.38), STONE_DARK, Mat.Slate)
		boxAt("MountainCragSpire", baseCF * CFrame.new(-size.X * 0.02, size.Y * 0.90, 0) * CFrame.Angles(math.rad(16), math.rad(-18), math.rad(-18)),
			V(size.X * 0.20, size.Y * 0.22, size.Z * 0.20), STONE_DARK, Mat.Slate)
	end

	-- Ethereal wispy aurora veil: ultra-sheer non-overlapping vertical-shimmer beams + soft glowing aurora mist clouds!
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
		b.CurveSize0 = 38
		b.CurveSize1 = -38
		b.Segments = 28
		b.Color = ColorSequence.new(col0, col1)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.18, math.min(0.96, peakAlpha + 0.12)),
			NumberSequenceKeypoint.new(0.48, peakAlpha),
			NumberSequenceKeypoint.new(0.82, math.min(0.96, peakAlpha + 0.12)),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		b.Parent = anchor
	end

	local function addAuroraMistCloud(pos: Vector3, colA: Color3, colB: Color3, spanX: number)
		local box = ctx.block("AuroraCloudAnchor", V(spanX, 16, 12), pos, colA, Mat.SmoothPlastic, nil, 1)
		box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = false, false, false, false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AuroraWispCloud"
		pe.Color = ColorSequence.new(colA, colB)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(0.45, 34), NumberSequenceKeypoint.new(1, 24) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.30, 0.78), NumberSequenceKeypoint.new(0.70, 0.82), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(6.0, 9.0)
		pe.Rate = 5
		pe.Speed = NumberRange.new(1.5, 4.0)
		pe.SpreadAngle = Vector2.new(20, 20)
		pe.LightEmission = 1
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = box
	end

	for _, lm in AstralFloor43.Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =========================================================================
	-- A. DEEP MOODY VIOLET RIFT ABYSS (PropKind = "AstralNebulaSea")
	-- Sits DEEP down at Y = -36 so tall craggy cliff walls plunge dramatically
	-- into dark starry indigo with soft misty purple glow only deep in the rifts!
	-- =========================================================================
	ctx.group("AstralNebulaSea", function()
		-- Deep dark starry indigo abyssal bed far below all platforms
		boxAt("RiftVoidFloor", CFrame.new(V(0, ABYSS_Y, -10)), V(920, 0.5, 920), rgb(10, 8, 22), Mat.SmoothPlastic, 0)

		-- Soft, moody deep-chasm violet nebula pools concentrated ONLY deep inside the narrow rifts
		local riftGlowPools = {
			{ -95, ABYSS_Y + 0.6, 146, 68, rgb(104, 46, 182), 0.72 },
			{ 82, ABYSS_Y + 0.6, 146, 68, rgb(104, 46, 182), 0.72 },
			{ -82, ABYSS_Y + 0.7, 8, 86, rgb(134, 58, 212), 0.68 },
			{ 58, ABYSS_Y + 0.7, 2, 82, rgb(126, 54, 202), 0.70 },
			{ 164, ABYSS_Y + 0.7, -4, 68, rgb(118, 50, 194), 0.72 },
			{ -104, ABYSS_Y + 0.8, -142, 92, rgb(142, 62, 220), 0.66 },
			{ 76, ABYSS_Y + 0.7, -130, 76, rgb(120, 52, 198), 0.72 },
			{ 114, ABYSS_Y + 0.8, -234, 88, rgb(146, 64, 224), 0.66 },
			{ -52, ABYSS_Y + 0.7, -230, 78, rgb(128, 56, 208), 0.70 },
		}
		for idx, rp in riftGlowPools do
			local disc = ctx.cyl("RiftGlowPool_" .. idx, V(rp[1], rp[2], rp[3]), rp[4], 0.20, rp[5], Mat.Neon)
			disc.Transparency = rp[6]
			if idx % 3 == 0 then
				disc:SetAttribute("ConjunctionGlyph", true)
				safeTag(disc, "ConjunctionGlyph")
			end
		end

		-- Subtle glowing violet rift fault veins snaking along the deepest chasm floor
		local riftVeins = {
			{ V(240, ABYSS_Y + 1.0, -8), V(120, ABYSS_Y + 1.0, -2), V(-82, ABYSS_Y + 1.0, 8), V(-172, ABYSS_Y + 1.0, -4) },
			{ V(-240, ABYSS_Y + 1.0, -136), V(-104, ABYSS_Y + 1.0, -148), V(58, ABYSS_Y + 1.0, -132), V(182, ABYSS_Y + 1.0, -138) },
			{ V(-240, ABYSS_Y + 1.0, -208), V(-88, ABYSS_Y + 1.0, -214), V(114, ABYSS_Y + 1.0, -236), V(212, ABYSS_Y + 1.0, -252) },
		}
		for vIdx, chain in riftVeins do
			for i = 1, #chain - 1 do
				local seg = ctx.beam("RiftVeinGlow_" .. vIdx, chain[i], chain[i + 1], 11.0, RIFT_MAGENTA, Mat.Neon, 0.74)
				seg:SetAttribute("ConjunctionGlyph", true)
				safeTag(seg, "ConjunctionGlyph")
			end
		end

		-- Delicate deep-space pinpoint stars around the outer chasm edges
		for i = 1, 90 do
			local sx = math.sin(i * 12.9898) * 380
			local sz = math.cos(i * 78.233) * 385 - 10
			local sSize = if i % 6 == 0 then 2.0 else 1.1
			local sCol = if i % 4 == 0 then GOLD_LIGHT elseif i % 3 == 0 then AURORA_TEAL else rgb(206, 198, 248)
			lump("VoidStarGlint", V(sx, ABYSS_Y + 0.85, sz), V(sSize, 0.24, sSize), sCol, Mat.Neon)
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Soft rising misty purple fog deep in the chasms (matches reference image's glowing purple rift mist!)
	riftMistEmitter(V(-92, -24, 10), 42)
	riftMistEmitter(V(78, -24, 14), 42)
	riftMistEmitter(V(-100, -22, -146), 46)
	riftMistEmitter(V(106, -22, -232), 46)

	-- Floating fractured void rock fragments strictly in OPEN chasm pockets (zero bridge clipping!)
	ctx.group("RiftBedGlows", function()
		for idx, fr in {
			{ -92, -3.5, 146, 14, 12, 12, 18 },   -- open pocket between Basin_WestGallery (-168) & Basin_Crossing (-8)
			{ 78, -4.0, 148, 15, 12, 13, -24 },   -- open pocket between Basin_Crossing (-8) & Basin_EastGallery (+166)
			{ -258, 1.0, 168, 20, 18, 18, 28 },   -- dramatic floating foreground shard bottom-left (Image 1!)
			{ 258, 1.0, 168, 20, 18, 18, -28 },   -- dramatic floating foreground shard bottom-right (Image 1!)
			{ 76, 1.0, 10, 15, 14, 14, 34 },      -- open pocket in Rift A east of Crossing
			{ -22, 6.0, -134, 14, 12, 13, -15 },  -- open pocket in Rift B south of P3C
			{ -188, 12.0, -154, 17, 15, 15, 22 }, -- open pocket west of ShardB
			{ 106, 12.0, -148, 15, 13, 14, -32 }, -- open pocket between P2E/P3C/P3E
			{ -60, 20.0, -232, 16, 14, 15, 19 },  -- open pocket between ShardB/P3C/P4C
		} do
			local cf = CFrame.new(V(fr[1], fr[2], fr[3])) * CFrame.Angles(math.rad(6), math.rad(fr[7]), math.rad(-5))
			boxAt("VoidShardTop_" .. idx, cf * CFrame.new(0, fr[5] * 0.45, 0), V(fr[4], 1.8, fr[6]), STONE_TOP, Mat.Slate)
			boxAt("VoidShardRock_" .. idx, cf * CFrame.new(0, -fr[5] * 0.1, 0), V(fr[4] * 0.84, fr[5], fr[6] * 0.84), CLIFF_ROCK, Mat.Slate)
			boxAt("VoidShardTip_" .. idx, cf * CFrame.new(0, -fr[5] * 0.68, 0), V(fr[4] * 0.46, fr[5] * 0.72, fr[6] * 0.46), CLIFF_DEEP, Mat.Slate)
		end
		-- Moody purple uplights deep inside the narrow chasms to rim-light the cliff undersides
		for i, pt in {
			V(-92, -16, 8),
			V(76, -16, 12),
			V(-102, -14, -148),
			V(112, -12, -236),
		} do
			local anchor = ctx.block("RiftGlowAnchor" .. i, V(2, 2, 2), pt, RIFT_VIOLET, Mat.SmoothPlastic, nil, 1)
			addLight(anchor, RIFT_VIOLET, 2.2, 105)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. FRACTURED GREY-SLATE CLIFF PLATES & INTEGRATED LANDMARK TERRACE BAYS
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

	-- Integrated rocky cliff terrace bays so every landmark & mountain crag is 100% grounded!
	buildFracturedCliffIsland("ApexGalleryApse", -172, 52, -328, 138, 50, 101)
	buildFracturedCliffIsland("EngineCragTerrace", 216, 44, -330, 166, 64, 102)
	buildFracturedCliffIsland("EngineWestSpillBay", 158, 44, -282, 32, 38, 103)
	buildFracturedCliffIsland("P4CColophonBay", 38, 48, -326, 68, 30, 104)
	buildFracturedCliffIsland("WestGalleryBay", -234, 16, 76, 44, 72, 105)
	buildFracturedCliffIsland("EastGalleryBay", 232, 8, 78, 44, 72, 106)
	buildFracturedCliffIsland("P2WBinderyBay", -228, 28, -64, 44, 56, 107)
	buildFracturedCliffIsland("P2CDeskBay", 14, 24, -32, 32, 26, 108)
	buildFracturedCliffIsland("P2EErrataBay", 208, 20, -100, 44, 54, 109)
	buildFracturedCliffIsland("P3CLedgerBay", 18, 36, -208, 58, 28, 110)
	buildFracturedCliffIsland("P3EInkCellarBay", 248, 32, -182, 44, 56, 111)

	-- =========================================================================
	-- C. SANCTUARY (THE SHELFMARK STAIR) & BASIN (THE INDEX FLOOR + RULED COURT)
	-- =========================================================================
	local sanctuary = P.Sanctuary
	if sanctuary then
		local sx, sy, sz = sanctuary.X, sanctuary.Y, sanctuary.Z
		buildFracturedCliffIsland("SanctuaryBase", sx, sy, sz, sanctuary.Width, sanctuary.Depth, 201)
		ctx.group("AstralConcourseDeck", function()
			local frontZ = sz - sanctuary.Depth * 0.5 + 1.0
			balustradeSpan(sx - 62, frontZ, -17, frontZ, sy, true)
			balustradeSpan(17, frontZ, sx + 62, frontZ, sy, true)

			-- The Shelfmark Stair (Sanctuary -> Basin, Z = 313..273, Y = 8..0):
			-- Weathered slate steps with GLOWING CYAN/TEAL SHELFMARK RUNE GLYPHS on every tread (Image 1!)
			local steps = 10
			for s = 1, steps do
				local t = (s - 0.5) / steps
				local stepY = 8.0 * (1 - t)
				local stepZ = 313.0 + (273.0 - 313.0) * t
				boxAt("ShelfmarkTread", CFrame.new(V(0, stepY - 0.14, stepZ)), V(26.6, 0.45, 4.1), if s % 2 == 0 then STONE_LIGHT else STONE_TOP, Mat.Slate)
				boxAt("ShelfmarkBrassLip", CFrame.new(V(0, stepY + 0.12, stepZ - 1.95)), V(26.2, 0.14, 0.30), BRASS_AGED, Mat.Metal)
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
						local halfOpen = link.Width * 0.5 + 1.6
						table.insert(gaps, { ax - halfOpen, ax + halfOpen })
					end
				end
			end
			table.sort(gaps, function(g1, g2) return g1[1] < g2[1] end)
			local curX = -halfW + 6
			for _, g in gaps do
				if g[1] - curX >= 6 then
					balustradeSpan(curX, northZ, g[1], northZ, by, true)
				end
				curX = math.max(curX, g[2])
			end
			if (halfW - 6) - curX >= 6 then
				balustradeSpan(curX, northZ, halfW - 6, northZ, by, true)
			end
			balustradeSpan(-halfW + 6, southZ, -22, southZ, by, true)
			balustradeSpan(22, southZ, halfW - 6, southZ, by, true)
			balustradeSpan(-halfW + 1.5, northZ + 6, -halfW + 1.5, southZ - 6, by, false)
			balustradeSpan(halfW - 1.5, northZ + 6, halfW - 1.5, southZ - 6, by, false)

			-- ICONIC CENTER ARRIVAL ASTROLABE COURT & 8-LECTERN RING (X = 0, Z = 225, matching Image 1 foreground!)
			local cx, cz = 0, bz
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

			-- Ring of 8 ornate wooden/brass lecterns encircling the cracked astrolabe (wide open N/S avenue!)
			for _, deg in { -145, -115, -65, -35, 35, 65, 115, 145 } do
				local a = math.rad(deg)
				local lx = cx + math.sin(a) * 23.2
				local lz = cz + math.cos(a) * 23.2
				local faceInYaw = math.deg(math.atan2(cx - lx, cz - lz))
				buildWoodenLectern(V(lx, by, lz), faceInYaw)
			end

			-- Fallen fluted marble column stubs & loose vellum pages framing Basin foreground (Image 1!)
			for _, colSpec in {
				{ -46, 246, 26, 9.5, 2.2 },
				{ 46, 246, -30, 9.5, 2.2 },
				{ -188, 224, 15, 8.0, 2.0 },
				{ 188, 224, -18, 8.0, 2.0 },
			} do
				local cf = CFrame.new(V(colSpec[1], by + colSpec[5] * 0.85, colSpec[2])) * CFrame.Angles(0, math.rad(colSpec[3]), math.pi / 2)
				local cyl = boxAt("FallenColumn", cf, V(colSpec[5] * 2, colSpec[4], colSpec[5] * 2), STONE_LIGHT, Mat.Marble)
				cyl.Shape = Enum.PartType.Cylinder
			end
			for i = 1, 14 do
				local px = -170 + i * 24 + math.sin(i * 3.1) * 10
				local pz = 200 + math.cos(i * 2.4) * 28
				boxAt("ScatteredPage", CFrame.new(V(px, by + 0.14, pz)) * CFrame.Angles(0, math.rad(i * 41), 0), V(2.4, 0.08, 1.8), VELLUM_PAGE, Mat.Fabric)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- D. THE LIFTED INDEX (APEX: BACK-WEST Y=52) — MOUNTAIN CRAGS, MOSAIC & GALLERY
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

			buildStandingBookcase(V(ax - 56, ay, az - 44), 78, 1.40)
			buildStandingBookcase(V(ax + 56, ay, az - 48), -78, 1.40)

			-- Towering fractured mountain peaks rising cleanly BEHIND LiftedIndexGallery (never clipping its archway!)
			buildMountainCrag(V(ax, ay - 6, az - 114), V(104, 112, 32), 4, -6)
			buildMountainCrag(V(ax - 76, ay - 6, az - 88), V(62, 92, 42), 24, -6)
			buildMountainCrag(V(ax + 76, ay - 6, az - 92), V(56, 74, 36), -22, -6)
			buildMountainCrag(V(ax - 92, ay - 14, az - 16), V(42, 64, 58), 12, -8)

			-- Warm glowing lantern posts flanking the top of the grand staircase (ShardB -> Apex)
			local sZ = az + apex.Depth * 0.5 - 1.2
			for _, lp in { V(ax + 12, ay, sZ), V(ax + 48, ay, sZ) } do
				ctx.cyl("StairHeadLampPost", lp + V(0, 6.2, 0), 0.55, 12.4, BRASS_AGED, Mat.Metal)
				local orb = lump("StairHeadLampBulb", lp + V(0, 12.8, 0), V(2.4, 2.8, 2.4), GOLD_LIGHT, Mat.Neon)
				orb:SetAttribute("ConjunctionLamp", true)
				safeTag(orb, "ConjunctionLamp")
				addLight(orb, GOLD_LIGHT, 2.2, 70)
			end

			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		ctx.group("AstralIsleBalustrade", function()
			local sZ = az + apex.Depth * 0.5 - 1.2
			local wX = ax - apex.Width * 0.5 + 1.5
			local eX = ax + apex.Width * 0.5 - 1.5
			balustradeSpan(wX + 4, sZ, ax + 10, sZ, ay, true)
			balustradeSpan(wX, az - 42, wX, sZ - 4, ay, true)
			balustradeSpan(eX, az + 6, eX, sZ - 4, ay, true)
			balustradeSpan(eX, az - 44, eX, az - 24, ay, true)
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
		local mc = piece("IndexEngineCore", core.X, core.Z, -18, "IndexEngineCore", 1.02, RIFTWARD_43, function(cf)
			boxAt("EngineLeft", cf * CFrame.new(-16, 86, 0) * CFrame.Angles(0, 0, math.rad(5)), V(24, 172, 22), RIFTWARD_43.METAL.Color, Mat.Metal)
			boxAt("EngineRight", cf * CFrame.new(16, 86, 0) * CFrame.Angles(0, 0, math.rad(-5)), V(24, 172, 22), RIFTWARD_43.METAL.Color, Mat.Metal)
			lump("EngineRiftCrack", (cf * CFrame.new(0, 74, 4)).Position, V(10, 90, 6), RIFT_VIOLET, Mat.Neon)
		end, core.Y)
		pin(mc)
		if mc then addLight(H.glowOf(mc), GOLD_LIGHT, 2.5, 130) end

		local gb = AstralFloor43.Landmarks[2]
		local mgb = piece("IndexEngineGearBank", gb.X, gb.Z, -18, "IndexEngineGearBank", 1.35, RIFTWARD_43, function(cf)
			boxAt("GearBank", cf * CFrame.new(0, 46, 0), V(94, 94, 12), RIFTWARD_43.METAL.Color, Mat.Metal)
		end, gb.Y)
		pin(mgb)
		if mgb then addLight(mgb.PrimaryPart or mgb:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.0, 115) end

		local st = AstralFloor43.Landmarks[3]
		pin(piece("IndexEngineShelfTower", st.X, st.Z, -32, "IndexEngineShelfTower", 1.05, LIBRARY_TINT, function(cf)
			boxAt("ShelfTower", cf * CFrame.new(0, 46, 0), V(32, 92, 14), WOOD_WARM, Mat.Wood)
		end, st.Y))

		local stW = piece("IndexEngineShelfTowerWest", 148, -324, -6, "IndexEngineShelfTower", 0.96, LIBRARY_TINT, function(cf)
			boxAt("ShelfTowerW", cf * CFrame.new(0, 44, 0), V(30, 88, 14), WOOD_WARM, Mat.Wood)
		end, core.Y)
		pin(stW)
		makeDecor(stW)

		ctx.group("AstralIsleDeck", function()
			buildMountainCrag(V(296, core.Y - 8, -338), V(54, 72, 44), -18, -6)
			buildMountainCrag(V(132, core.Y - 8, -340), V(48, 58, 38), 22, -6)
			for i = 1, 22 do
				local px = 172 + (i % 7) * 14 + math.sin(i * 2.1) * 6
				local pz = -316 + math.floor(i / 7) * 11 + math.cos(i * 1.7) * 4
				boxAt("EngineSpillPage", CFrame.new(V(px, (core.Y :: number) + 0.16 + (i % 3) * 0.08, pz)) * CFrame.Angles(0, math.rad(i * 33), 0), V(3.2, 0.14, 2.4), VELLUM_PAGE, Mat.Fabric)
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 4. THE LIFTED INDEX GALLERY (Prominent curved two-tier mahogany library rotunda grounded behind Apex!)
	do
		local lm = AstralFloor43.Landmarks[4]
		local mg = piece("LiftedIndexGallery", lm.X, lm.Z, 0, "LiftedIndexGallery", 1.62, LIBRARY_TINT, function(cf)
			boxAt("LiftedGallery", cf * CFrame.new(0, 18, 0), V(74, 36, 24), WOOD_WARM, Mat.Wood)
		end, lm.Y)
		pin(mg)
		if mg then addLight(H.glowOf(mg) or mg:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.8, 130) end
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

	-- Extra rich library dressing & flanking crag backdrops grounded solidly on the integrated cliff bays
	ctx.group("AstralIsleDeck", function()
		buildStandingBookcase(V(-246, 16, 54), 96, 1.18)
		buildStandingBookcase(V(-248, 16, 94), 82, 1.12)
		buildMountainCrag(V(-270, 10, 76), V(38, 52, 72), 10, -8)

		buildStandingBookcase(V(244, 8, 56), -96, 1.18)
		buildStandingBookcase(V(246, 8, 96), -80, 1.12)
		buildMountainCrag(V(268, 2, 78), V(38, 52, 72), -10, -8)

		buildStandingBookcase(V(-242, 28, -80), 72, 1.10)
		ctx.cyl("BinderyColumnStub", V(-238, 32.5, -46), 2.3, 9.0, STONE_LIGHT, Mat.Marble)
		buildMountainCrag(V(-264, 22, -64), V(36, 54, 62), 12, -8)

		buildStandingBookcase(V(-38, 24, -92), 6, 1.05)
		buildStandingBookcase(V(-8, 36, -210), 12, 1.10)
		buildStandingBookcase(V(42, 36, -210), -14, 1.08)

		buildStandingBookcase(V(258, 32, -166), -102, 1.12)
		buildMountainCrag(V(280, 26, -182), V(38, 56, 66), -12, -8)
		buildMountainCrag(V(42, 42, -348), V(72, 48, 26), 4, -6)

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Companion spilled indigo ink vat on WestGallery south-west bay (Image 1 bottom-left!)
	do
		local wVat = piece("WestrangeInkVat", -224, 104, 40, "InkVatCracked", 1.08, INK_VAT_TINT, function(cf)
			ctx.cyl("WestInkPuddle", cf.Position + V(0, 0.2, 0), 5.0, 0.3, rgb(64, 52, 164), Mat.Glass)
		end, 16)
		pin(wVat)
		tagDetail(wVat)
	end

	-- Companion tilted reading desks on WestGallery, EastGallery & P3C/P3E bays
	for _, dSpec in {
		{ -224, 58, 16, 115, 1.05 },
		{ 222, 62, 8, -110, 1.05 },
		{ 38, -196, 36, -20, 1.0 },
		{ 242, -162, 32, -75, 1.0 },
	} do
		local md = piece("StudyDeskExtra", dSpec[1], dSpec[2], dSpec[4], "CatalogueDeskTilted", dSpec[5], LIBRARY_TINT, function(cf)
			boxAt("DeskFallback", cf * CFrame.new(0, 2.5, 0), V(8, 5, 6), WOOD_WARM, Mat.Wood)
		end, dSpec[3])
		pin(md)
		tagDetail(md)
	end

	-- 16–18. Scarp Shelf Strata embedded FLUSH into the fractured rocky cliff faces
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
		{ -234, 112, -2, 0 },
		{ 232, 114, -8, 0 },
		{ -172, -214, 34, 0 },
		{ -22, -38, 6, 0 },
	} do
		local ms = piece("AstralIsleUnderside", extraStrata[1], extraStrata[2], extraStrata[4], "ScarpShelfStrata", 0.96, LIBRARY_TINT, function(cf)
			boxAt("ShelfStrataExtra", cf * CFrame.new(0, 8, 0), V(30, 16, 9), CLIFF_ROCK, Mat.Slate)
		end, extraStrata[3])
		pin(ms)
		makeDecor(ms)
	end

	-- 19–20. Sculpted Page Fall Ribbons anchored FLUSH at the cliff lip pouring downward into the violet rifts!
	-- (PageFallRibbon kit height at scale 1.45 is ~32 studs; sink placement Y so the top lip meets the terrace edge cleanly!)
	for _, spec in {
		{ AstralFloor43.Landmarks[19], 24 }, -- P2C terrace Y = 24
		{ AstralFloor43.Landmarks[20], 36 }, -- P3C terrace Y = 36
	} do
		local lm = spec[1]
		local lipY = spec[2]
		local mp = piece("AstralIsleUnderside", lm.X, lm.Z, 0, "PageFallRibbon", 1.42, RIFTWARD_43, function(cf)
			boxAt("PageCascade", cf * CFrame.new(0, 10, 0), V(8, 20, 10), VELLUM_PAGE, Mat.Fabric)
		end, lipY - 30)
		pin(mp)
		makeDecor(mp)
		pageEmitter(V(lm.X, lipY - 4, lm.Z), 4)
	end
	for _, extra in {
		{ -126, 16, 110, -28, 1.40 },   -- WestGallery SE cliff lip pouring into foreground chasm (Image 1 bottom-left!)
		{ 126, 8, 112, 28, 1.36 },      -- EastGallery SW cliff lip pouring into foreground chasm (Image 1 bottom-right!)
		{ 22, 36, -138, 0, 1.42 },      -- P3C Ledger Plate south cliff lip cascading into Rift B!
		{ 168, 44, -262, 28, 1.50 },    -- Broken Index Engine cliff lip pouring into Rift C!
	} do
		local mp = piece("AstralIsleUnderside", extra[1], extra[3], extra[4], "PageFallRibbon", extra[5], RIFTWARD_43, function(cf)
			boxAt("PageCascade", cf * CFrame.new(0, 10, 0), V(8, 20, 10), VELLUM_PAGE, Mat.Fabric)
		end, extra[2] - 30)
		pin(mp)
		makeDecor(mp)
	end

	-- =========================================================================
	-- F. FLOATING JAGGED SHARD ISLANDS, HANGING BRASS CHAINS & CROOKED INDEX LAMPS
	-- =========================================================================
	for _, row in {
		{ "ShardA", "ShardSlabM", 25.114, 29.314, 22.261, 54, 46, 30.0 },
		{ "ShardE", "ShardSlabM", 25.114, 29.314, 22.261, 54, 46, 26.0 },
		{ "ShardB", "ShardSlabL", 38.027, 35.314, 32.010, 58, 48, 38.0 },
		{ "ShardC", "ShardSlabM", 25.114, 29.314, 22.261, 54, 46, 38.0 },
	} do
		local id: string = row[1]
		local plat = P[id]
		if not plat then continue end
		local kitName: string = row[2]
		local kitW: number, kitH: number, kitD: number = row[3], row[4], row[5]
		local pw: number, pd: number = row[6], row[7]
		local availH: number = row[8]

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

	-- Iconic catenary hanging brass chains anchoring floating shards across the violet chasm
	ctx.group("AstralIsleUnderside", function()
		local chainPairs = {
			{ V(-108, 15, 18), V(-146, 13, 44), 10, 8 },
			{ V(-58, 15, 22), V(-34, 10, 56), 9, 8 },
			{ V(-104, 15, -12), V(-146, 24, -40), 11, 8 },
			{ V(140, 8, 10), V(140, 6, 44), 8, 6 },
			{ V(184, 8, -22), V(176, 17, -72), 10, 8 },
			{ V(-128, 30, -132), V(-152, 25, -88), 11, 8 },
			{ V(-78, 30, -128), V(-46, 21, -92), 11, 8 },
			{ V(-124, 30, -168), V(-156, 46, -222), 14, 10 },
			{ V(98, 36, -220), V(54, 33, -190), 11, 8 },
			{ V(142, 36, -252), V(174, 40, -268), 10, 8 },
			{ V(-92, -3, 146), V(-138, 8, 108), 10, 8 },
			{ V(78, -4, 148), V(132, 3, 110), 10, 8 },
		}
		for _, cp in chainPairs do
			buildHangingChain(cp[1], cp[2], cp[3], cp[4])
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Warm glowing Crooked Index Lamps on all 4 floating shards + key bridgeheads
	local lampSpecs = {
		{ -104, 18, 22, 35, true },
		{ 184, 10, 10, -45, true },
		{ -126, 34, -130, 55, true },
		{ 140, 40, -220, -55, true },
		{ -42, 12, 110, 18, true },
		{ -202, 28, -42, 40, true },
		{ 182, 20, -76, -40, true },
		{ 50, 36, -144, -25, false },
		{ 176, 44, -262, 32, true },
	}
	for _, sp in lampSpecs do
		local ml = piece("AstralIndexLamp", sp[1], sp[3], sp[4], "CrookedIndexLamp", 1.12, RIFTWARD_43, function(cf)
			ctx.cyl("CrookedPost", cf.Position + V(0, 6, 0), 0.7, 12, BRASS_AGED, Mat.Metal)
			lump("CrookedBulb", cf.Position + V(0, 11.5, 0), V(2.2, 2.8, 2.2), GOLD_LIGHT, Mat.Neon)
		end, sp[2])
		pin(ml)
		tagDetail(ml)
		if ml then
			ml:SetAttribute("ConjunctionLamp", true)
			safeTag(ml, "ConjunctionLamp")
			if sp[5] then
				addLight(H.glowOf(ml), GOLD_LIGHT, 2.1, 65)
			end
		end
	end

	-- =========================================================================
	-- G. WISPY ETHEREAL SPLIT VIOLET-TEAL AURORA VEIL & SKY-RIFT LIGHTNING
	-- Ultra-sheer non-overlapping ribbons + drifting glowing aurora clouds!
	-- =========================================================================
	ctx.group("AstralSplitAurora", function()
		-- Delicate sheer translucent aurora ribbons spaced apart so they NEVER additively blow out to white!
		addAuroraCurtain("AuroraTealSweep", V(-185, 168, -350), V(175, 202, -372), 18, 24, AURORA_TEAL, rgb(86, 226, 208), 0.80)
		addAuroraCurtain("AuroraVioletSweep", V(-125, 138, -338), V(215, 168, -360), 22, 28, RIFT_VIOLET, RIFT_MAGENTA, 0.82)
		addAuroraCurtain("AuroraTealWisp", V(-75, 186, -362), V(130, 208, -376), 12, 16, rgb(120, 242, 224), AURORA_TEAL, 0.86)

		-- Soft drifting ethereal teal & violet nebula/aurora clouds feathering the night sky
		addAuroraMistCloud(V(-60, 152, -346), AURORA_TEAL, RIFT_VIOLET, 130)
		addAuroraMistCloud(V(65, 174, -358), RIFT_VIOLET, AURORA_TEAL, 140)

		local lightningBranches = {
			{ V(-188, 128, -328), V(-146, 152, -342), V(-112, 170, -352), V(-80, 186, -360) },
			{ V(-146, 152, -342), V(-172, 174, -350) },
			{ V(214, 156, -334), V(256, 174, -348), V(298, 192, -360), V(334, 208, -368) },
			{ V(256, 174, -348), V(284, 154, -344) },
		}
		for bIdx, pts in lightningBranches do
			for i = 1, #pts - 1 do
				local crack = ctx.beam("SkyRiftLightning_" .. bIdx, pts[i], pts[i + 1], 0.72, RUNE_CYAN, Mat.Neon, 0.36)
				crack:SetAttribute("ConjunctionGlyph", true)
				safeTag(crack, "ConjunctionGlyph")
				local halo = ctx.beam("SkyRiftLightningHalo_" .. bIdx, pts[i], pts[i + 1], 2.4, RIFT_VIOLET, Mat.Neon, 0.84)
				halo:SetAttribute("ConjunctionGlyph", true)
				safeTag(halo, "ConjunctionGlyph")
			end
		end

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	pageEmitter(V(198, 54, -280), 4)
	pageEmitter(V(-104, 40, -148), 3)
	pageEmitter(V(-172, 58, -264), 3)
	pageEmitter(V(14, 24, -18), 3)

	ctx.setAttribute("AstralFloor", 43)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor43
