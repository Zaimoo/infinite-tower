--!strict
-- Hand-authored set pieces for Astral Archives Floor 43: Fractured Index (astral:3, TERRAIN_VARIATION).
-- Design: docs/prompts/astral-archives-floor-layouts-prompt.md (Floor 43) & reference/Astral Archives 43.jpg.
--
-- Where the Index Engine broke: a clean orthogonal 3-column archipelago of tall craggy grey-slate cliff islands
-- plunging deep into a dark misty violet Rift abyss, linked by 24 straight 0°/90° flush-connected stone bridges
-- and chained floating shard decks; foreground Ruled Court with cracked circular astrolabe, 8 wooden lecterns,
-- twin golden armillary spheres and cyan-runed Shelfmark Stair; solid walkable outer cliff terrace bays holding
-- every bookcase, press, ink vat and reading desk clear of all walkways; back-west Lifted Index Gallery nestled
-- in jagged mountain peaks atop a straight lantern-lit grand staircase; back-east 183-stud split Index Engine
-- with interlocking bronze gears, flanking shelf towers & cascading page waterfalls; and ethereal teal-violet
-- aurora veils arching across the starry sky between both peaks.
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

local SHARD_UNDERSIDE_TINT = tinted(RIFTWARD_43, {
	STONE = swatch(112, 118, 134, Mat.Slate, 1),
	ALT = swatch(52, 58, 78, Mat.Slate),
	METAL = swatch(176, 142, 78, Mat.Metal),
	TRIM = swatch(212, 180, 102, Mat.Metal),
	CRYSTAL = swatch(136, 86, 214, Mat.Neon, 0.34),
	GLOW = swatch(252, 228, 158, Mat.Neon),
})

local INK_VAT_TINT = tinted(RIFTWARD_43, {
	ALT = swatch(54, 46, 136, Mat.Glass),
	CRYSTAL = swatch(88, 72, 198, Mat.Glass, 0.10),
	GLOW = swatch(132, 106, 238, Mat.Neon),
})

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

-- Deep visual abyss floor so every cliff island plunges 34..88 studs down into moody misty depths!
local ABYSS_Y = -36

-- Floor 43's 20 landmark footprints (local floor space, 720 x 750, clean orthogonal 3-column archipelago).
-- Every single landmark sits on a solid walkable outer terrace bay strictly clear of all bridges, camps & portals!
AstralFloor43.Landmarks = table.freeze({
	-- 1. Index Engine Core (>= 175 studs, 183 studs at 1.02) split down the middle behind Engine terrace
	{ Id = "IndexEngineCore", X = 206, Z = -344, Y = 44, HalfX = 35.0, HalfZ = 13.8, Top = 183.3 },
	-- 2. Index Engine Gear Bank rising directly behind IndexEngineCore
	{ Id = "IndexEngineGearBank", X = 214, Z = -362, Y = 44, HalfX = 45.6, HalfZ = 7.2, Top = 88.0 },
	-- 3. Index Engine Shelf Tower tightly flanking east side of IndexEngineCore
	{ Id = "IndexEngineShelfTower", X = 272, Z = -334, Y = 44, HalfX = 18.4, HalfZ = 8.0, Top = 93.0 },
	-- 4. Lifted Index Gallery grounded solidly on Apex's integrated north terrace behind portals (-324)
	{ Id = "LiftedIndexGallery", X = -176, Z = -358, Y = 52, HalfX = 32.0, HalfZ = 12.0, Top = 31.6 },
	-- 5. Colophon Wall grounded on P4C's solid north stone terrace
	{ Id = "ColophonWall", X = 0, Z = -344, Y = 48, HalfX = 13.6, HalfZ = 2.0, Top = 16.8 },
	-- 6. Bindery Press (wooden screw press + gold thread spools) grounded on P2W's solid western terrace bay
	{ Id = "BinderyPress", X = -242, Z = -80, Y = 28, HalfX = 8.4, HalfZ = 3.6, Top = 12.4 },
	-- 7. Errata Press grounded on P2E's solid eastern terrace bay
	{ Id = "ErrataPress", X = 250, Z = -80, Y = 20, HalfX = 6.5, HalfZ = 3.2, Top = 9.7 },
	-- 8. Reading Plate Tilted Desk grounded on P2C's solid south-east corner bay (clear of all 4 cardinal bridges!)
	{ Id = "ReadingTiltedDesk", X = 28, Z = -40, Y = 24, HalfX = 4.8, HalfZ = 5.0, Top = 6.0 },
	-- 9. Ledger Plate Tall Ledger Stack grounded on P3C's solid north-east corner bay (clear of all 4 cardinal bridges!)
	{ Id = "LedgerStackTall", X = 32, Z = -218, Y = 36, HalfX = 5.0, HalfZ = 4.8, Top = 14.1 },
	-- 10. Ink-Cellar Cracked Ink Vat grounded on P3E's solid eastern cliff bay
	{ Id = "InkCellarVat", X = 250, Z = -180, Y = 32, HalfX = 4.8, HalfZ = 7.0, Top = 5.8 },
	-- 11. Toppled Shelf Range grounded on WestGallery's solid western cliff bay
	{ Id = "WestrangeToppledShelf", X = -244, Z = 76, Y = 16, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 12. Toppled Shelf Range grounded on EastGallery's solid eastern cliff bay
	{ Id = "EastrangeToppledShelf", X = 252, Z = 76, Y = 8, HalfX = 7.5, HalfZ = 7.6, Top = 8.0 },
	-- 13. Card Drawer Spill grounded on Engine's solid eastern spill bay (clear of south & west bridges!)
	{ Id = "EngineCardSpill", X = 238, Z = -296, Y = 44, HalfX = 6.0, HalfZ = 4.4, Top = 2.4 },
	-- 14. Broken Orrery Ring grounded solidly on Basin west foreground corner
	{ Id = "BrokenOrreryRingW", X = -176, Z = 252, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 15. Broken Orrery Ring grounded solidly on Basin east foreground corner
	{ Id = "BrokenOrreryRingE", X = 186, Z = 252, Y = 0, HalfX = 7.4, HalfZ = 5.6, Top = 7.8 },
	-- 16. Scarp Shelf Strata embedded flush into WestGalleryBay's north cliff face
	{ Id = "ScarpStrataWest", X = -242, Z = 40, Y = 0, HalfX = 16.8, HalfZ = 6.0, Top = 16.0 },
	-- 17. Scarp Shelf Strata embedded flush into P2WBinderyBay's north cliff face
	{ Id = "ScarpStrataP2W", X = -240, Z = -111, Y = 10, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 18. Scarp Shelf Strata embedded flush into P3EInkCellarBay's north cliff face
	{ Id = "ScarpStrataP3E", X = 250, Z = -209, Y = 14, HalfX = 16.8, HalfZ = 6.0, Top = 18.0 },
	-- 19. Page Fall Ribbon cascading directly off P2CDeskBay's south cliff lip into Rift A
	{ Id = "PageFallRiftA", X = 28, Z = -24, Y = 0, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
	-- 20. Page Fall Ribbon cascading directly off P3C's north-west cliff lip into Rift C
	{ Id = "PageFallRiftC", X = -30, Z = -212, Y = 12, HalfX = 5.0, HalfZ = 7.0, Top = 22.8 },
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

	-- Helper: weathered grey-slate & antique-brass stone balustrade span (returns solid collider for post-makeDecor re-enable)
	local fenceColliders: { BasePart } = {}
	local function enableFences()
		for _, c in fenceColliders do
			c.CanCollide = true
			c.CanQuery = true
		end
		table.clear(fenceColliders)
	end
	local function balustradeSpan(x0: number, z0: number, x1: number, z1: number, y: number, withEndOrbs: boolean?)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local len = (b - a).Magnitude
		if len < 4 then return end
		local mid = (a + b) * 0.5
		local cf = CFrame.lookAt(mid, b)
		boxAt("FractureBalPlinth", cf * CFrame.new(0, 0.55, 0), V(1.35, 1.1, len), STONE_LIGHT, Mat.Slate)
		boxAt("FractureBalRail", cf * CFrame.new(0, 3.05, 0), V(1.05, 0.45, len), BRASS_AGED, Mat.Metal)
		boxAt("FractureBalCapStone", cf * CFrame.new(0, 2.75, 0), V(1.25, 0.30, len), STONE_TOP, Mat.Slate)
		local col = boxAt("FractureBalCollider", cf * CFrame.new(0, 1.8, 0), V(1.4, 3.6, len + 0.4), STONE_LIGHT, Mat.Slate, 1)
		table.insert(fenceColliders, col)
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
	-- When `isWalkableBay` is true, creates a 100% SOLID walkable top stone deck (`CanCollide = true`) so players
	-- never phase or fall through outer terrace bays! When false (main TowerRoomBuilder platform), keeps all trim
	-- strictly BELOW `y` (`top = y - 0.14`) so there is ZERO z-fighting with the main platform slab!
	local function buildFracturedCliffIsland(id: string, x: number, y: number, z: number, w: number, d: number, seed: number, isWalkableBay: boolean?)
		local cliffBottom = ABYSS_Y + 1.0
		local totalH = math.max(24.0, y - cliffBottom)
		ctx.group("AstralIsleDeck", function()
			local solidBayDeck: Part? = nil
			if isWalkableBay then
				-- Flush solid walkable stone bay deck (matches main platform top cleanly, 100% collidable!)
				solidBayDeck = boxAt(id .. "WalkDeck", CFrame.new(V(x, y - 0.90, z)), V(w, 1.8, d), STONE_TOP, Mat.Slate)
			else
				-- On main platforms, keep the cornice lip strictly BELOW `y` (-0.14) to eliminate coplanar z-fighting!
				boxAt(id .. "DeckLip", CFrame.new(V(x, y - 1.14, z)), V(w + 1.2, 2.0, d + 1.2), STONE_TOP, Mat.Slate)
			end
			boxAt(id .. "BrassUnderTrim", CFrame.new(V(x, y - 2.15, z)), V(w + 1.4, 0.40, d + 1.4), BRASS_AGED, Mat.Metal)

			-- Multi-tiered tapered cliff core plunging deep into the abyss
			local hullH = totalH - 2.3
			local h1, h2, h3 = hullH * 0.34, hullH * 0.36, hullH * 0.34
			boxAt(id .. "CliffTier1", CFrame.new(V(x, y - 2.3 - h1 * 0.5, z)), V(w - 1.2, h1, d - 1.2), CLIFF_ROCK, Mat.Slate)
			boxAt(id .. "CliffTier2", CFrame.new(V(x, y - 2.3 - h1 * 0.85 - h2 * 0.5, z)), V(w * 0.86, h2, d * 0.86), CLIFF_MID, Mat.Slate)
			boxAt(id .. "CliffTier3", CFrame.new(V(x, cliffBottom + h3 * 0.5, z)), V(w * 0.66, h3, d * 0.66), CLIFF_DEEP, Mat.Slate)

			-- Tall angled jagged rock crags wrapping corners & cliff walls, tapering inward toward the depths
			local halfW, halfD = w * 0.5, d * 0.5
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local rockW = math.min(22, w * 0.28)
					local rockD = math.min(22, d * 0.28)
					local rockH = hullH * (0.74 + ((seed + sx * 3 + sz * 5) % 3) * 0.08)
					local rx = x + sx * (halfW - rockW * 0.36)
					local rz = z + sz * (halfD - rockD * 0.36)
					local cf = CFrame.new(V(rx, y - 2.4 - rockH * 0.5, rz))
						* CFrame.Angles(math.rad(-sz * 8), math.rad((seed * 17 + sx * 11 + sz * 7) % 24 - 12), math.rad(sx * 8))
					boxAt(id .. "CornerCrag", cf, V(rockW, rockH, rockD), if (sx + sz) == 0 then CLIFF_ROCK else CLIFF_MID, Mat.Slate)
				end
			end
			local nRibsX = math.clamp(math.floor(w / 46), 1, 5)
			for i = 1, nRibsX do
				local rx = x - halfW + (w * i / (nRibsX + 1))
				for _, sz in { -1, 1 } do
					local rh = hullH * (0.64 + ((i + seed) % 3) * 0.11)
					local cf = CFrame.new(V(rx, y - 2.3 - rh * 0.5, z + sz * (halfD - 3.8)))
						* CFrame.Angles(math.rad(-sz * 9), math.rad(((i * 23 + seed) % 16) - 8), 0)
					boxAt(id .. "WallCragZ", cf, V(16, rh, 11), if i % 2 == 0 then CLIFF_ROCK else CLIFF_MID, Mat.Slate)
				end
			end
			local nRibsZ = math.clamp(math.floor(d / 40), 1, 3)
			for i = 1, nRibsZ do
				local rz = z - halfD + (d * i / (nRibsZ + 1))
				for _, sx in { -1, 1 } do
					local rh = hullH * (0.62 + ((i + seed) % 3) * 0.11)
					local cf = CFrame.new(V(x + sx * (halfW - 3.8), y - 2.3 - rh * 0.5, rz))
						* CFrame.Angles(0, math.rad(((i * 19 + seed) % 16) - 8), math.rad(sx * 9))
					boxAt(id .. "WallCragX", cf, V(11, rh, 16), if i % 2 == 0 then CLIFF_MID else CLIFF_ROCK, Mat.Slate)
				end
			end

			-- Subtle weathered flagstones raised cleanly above `y` (`bottom = y + 0.02`) so zero z-fighting!
			local nFlags = math.clamp(math.floor((w * d) / 720), 2, 10)
			for k = 1, nFlags do
				local fx = x + math.sin(k * 2.13 + seed) * (halfW * 0.62)
				local fz = z + math.cos(k * 1.71 + seed * 1.3) * (halfD * 0.60)
				local fw = 7.0 + ((k * 7 + seed) % 5)
				local fd = 6.0 + ((k * 5 + seed) % 4)
				local fcf = CFrame.new(V(fx, y + 0.05 + (k % 2) * 0.015, fz)) * CFrame.Angles(0, math.rad(((k * 17 + seed) % 16) - 8), 0)
				boxAt(id .. "Flagstone", fcf, V(fw, 0.05, fd), if k % 2 == 0 then STONE_LIGHT else STONE_DARK, Mat.Slate)
			end
			local crackCF = CFrame.new(V(x + math.sin(seed) * halfW * 0.14, y + 0.06, z + math.cos(seed) * halfD * 0.14))
				* CFrame.Angles(0, math.rad((seed * 37) % 140 - 70), 0)
			boxAt(id .. "FloorCrack", crackCF, V(math.min(w, d) * 0.50, 0.04, 0.65), CLIFF_DEEP, Mat.Slate)

			makeDecor(ctx.current())
			-- Re-enable solid collision on walkable outer terrace bays so players walk on them seamlessly!
			if solidBayDeck then
				solidBayDeck.CanCollide = true
				solidBayDeck.CanQuery = true
				solidBayDeck.CanTouch = true
			end
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
		boxAt("MountainCragBase", baseCF * CFrame.new(0, size.Y * 0.12, 0) * CFrame.Angles(math.rad(tiltDeg * 0.4), math.rad(8), math.rad(-tiltDeg * 0.3)),
			V(size.X * 1.05, size.Y * 0.52, size.Z * 1.05), CLIFF_DEEP, Mat.Slate)
		boxAt("MountainCragMid", baseCF * CFrame.new(-size.X * 0.08, size.Y * 0.44, size.Z * 0.06) * CFrame.Angles(math.rad(tiltDeg), math.rad(-14), math.rad(tiltDeg * 0.6)),
			V(size.X * 0.74, size.Y * 0.52, size.Z * 0.72), CLIFF_ROCK, Mat.Slate)
		boxAt("MountainCragShoulder", baseCF * CFrame.new(size.X * 0.24, size.Y * 0.30, -size.Z * 0.06) * CFrame.Angles(math.rad(-tiltDeg * 0.7), math.rad(22), math.rad(-14)),
			V(size.X * 0.50, size.Y * 0.46, size.Z * 0.56), CLIFF_MID, Mat.Slate)
		boxAt("MountainCragPeak", baseCF * CFrame.new(-size.X * 0.04, size.Y * 0.74, 0) * CFrame.Angles(math.rad(tiltDeg * 1.2), math.rad(28), math.rad(14)),
			V(size.X * 0.40, size.Y * 0.36, size.Z * 0.38), STONE_DARK, Mat.Slate)
		boxAt("MountainCragSpire", baseCF * CFrame.new(-size.X * 0.02, size.Y * 0.90, 0) * CFrame.Angles(math.rad(16), math.rad(-18), math.rad(-18)),
			V(size.X * 0.20, size.Y * 0.22, size.Z * 0.20), STONE_DARK, Mat.Slate)
	end

	-- Ethereal wispy aurora veil: ultra-sheer non-overlapping ribbons + soft glowing aurora mist clouds!
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
		boxAt("RiftVoidFloor", CFrame.new(V(0, ABYSS_Y, -10)), V(920, 0.5, 920), rgb(10, 8, 22), Mat.SmoothPlastic, 0)

		local riftGlowPools = {
			{ -90, ABYSS_Y + 0.6, 146, 68, rgb(104, 46, 182), 0.72 },
			{ 92, ABYSS_Y + 0.6, 146, 68, rgb(104, 46, 182), 0.72 },
			{ -88, ABYSS_Y + 0.7, -4, 86, rgb(134, 58, 212), 0.68 },
			{ 92, ABYSS_Y + 0.7, -4, 86, rgb(126, 54, 202), 0.70 },
			{ -88, ABYSS_Y + 0.8, -134, 92, rgb(142, 62, 220), 0.66 },
			{ 92, ABYSS_Y + 0.7, -134, 82, rgb(120, 52, 198), 0.72 },
			{ -88, ABYSS_Y + 0.8, -242, 88, rgb(146, 64, 224), 0.66 },
			{ 92, ABYSS_Y + 0.7, -242, 82, rgb(128, 56, 208), 0.70 },
		}
		for idx, rp in riftGlowPools do
			local disc = ctx.cyl("RiftGlowPool_" .. idx, V(rp[1], rp[2], rp[3]), rp[4], 0.20, rp[5], Mat.Neon)
			disc.Transparency = rp[6]
			if idx % 3 == 0 then
				disc:SetAttribute("ConjunctionGlyph", true)
				safeTag(disc, "ConjunctionGlyph")
			end
		end

		local riftVeins = {
			{ V(240, ABYSS_Y + 1.0, -4), V(92, ABYSS_Y + 1.0, -4), V(-88, ABYSS_Y + 1.0, -4), V(-220, ABYSS_Y + 1.0, -4) },
			{ V(-240, ABYSS_Y + 1.0, -134), V(-88, ABYSS_Y + 1.0, -134), V(92, ABYSS_Y + 1.0, -134), V(230, ABYSS_Y + 1.0, -134) },
			{ V(-240, ABYSS_Y + 1.0, -242), V(-88, ABYSS_Y + 1.0, -242), V(92, ABYSS_Y + 1.0, -242), V(230, ABYSS_Y + 1.0, -242) },
		}
		for vIdx, chain in riftVeins do
			for i = 1, #chain - 1 do
				local seg = ctx.beam("RiftVeinGlow_" .. vIdx, chain[i], chain[i + 1], 11.0, RIFT_MAGENTA, Mat.Neon, 0.74)
				seg:SetAttribute("ConjunctionGlyph", true)
				safeTag(seg, "ConjunctionGlyph")
			end
		end

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

	-- Soft rising misty purple fog deep in the chasms
	riftMistEmitter(V(-90, -24, 10), 42)
	riftMistEmitter(V(92, -24, 10), 42)
	riftMistEmitter(V(-90, -22, -134), 46)
	riftMistEmitter(V(92, -22, -242), 46)

	-- Deep chasm violet uplights + 2 far-outer decorative foreground shards (ZERO floating blocks near any bridge!)
	ctx.group("RiftBedGlows", function()
		for idx, fr in {
			{ -295, -2.0, 180, 20, 18, 18, 26 }, -- far outer foreground left (75+ studs from Basin & WestGallery!)
			{ 300, -2.0, 180, 20, 18, 18, -26 }, -- far outer foreground right (75+ studs from Basin & EastGallery!)
		} do
			local cf = CFrame.new(V(fr[1], fr[2], fr[3])) * CFrame.Angles(math.rad(6), math.rad(fr[7]), math.rad(-5))
			boxAt("VoidShardTop_" .. idx, cf * CFrame.new(0, fr[5] * 0.45, 0), V(fr[4], 1.8, fr[6]), STONE_TOP, Mat.Slate)
			boxAt("VoidShardRock_" .. idx, cf * CFrame.new(0, -fr[5] * 0.1, 0), V(fr[4] * 0.84, fr[5], fr[6] * 0.84), CLIFF_ROCK, Mat.Slate)
			boxAt("VoidShardTip_" .. idx, cf * CFrame.new(0, -fr[5] * 0.68, 0), V(fr[4] * 0.46, fr[5] * 0.72, fr[6] * 0.46), CLIFF_DEEP, Mat.Slate)
		end
		for i, pt in {
			V(-90, -16, -4),
			V(92, -16, -4),
			V(-90, -14, -134),
			V(92, -12, -242),
		} do
			local anchor = ctx.block("RiftGlowAnchor" .. i, V(2, 2, 2), pt, RIFT_VIOLET, Mat.SmoothPlastic, nil, 1)
			addLight(anchor, RIFT_VIOLET, 2.2, 105)
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- =========================================================================
	-- B. FRACTURED GREY-SLATE CLIFF PLATES & SOLID WALKABLE OUTER TERRACE BAYS
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
			buildFracturedCliffIsland(pid, plat.X, plat.Y, plat.Z, plat.Width, plat.Depth, idx * 13 + 7, false)
		end
	end

	-- Every outer cliff bay sits strictly OUTSIDE its main platform edge (zero z-fighting!) AND is 100% SOLID WALKABLE!
	buildFracturedCliffIsland("ApexGalleryApse", -176, 52, -354, 124, 36, 101, true)
	buildFracturedCliffIsland("EngineCragTerrace", 214, 44, -345, 160, 44, 102, true)
	buildFracturedCliffIsland("EngineEastSpillBay", 238, 44, -296, 36, 54, 103, true)
	buildFracturedCliffIsland("P4CColophonBay", 0, 48, -340, 76, 32, 104, true)
	buildFracturedCliffIsland("WestGalleryBay", -242, 16, 76, 48, 68, 105, true)
	buildFracturedCliffIsland("EastGalleryBay", 252, 8, 76, 48, 66, 106, true)
	buildFracturedCliffIsland("P2WBinderyBay", -240, 28, -80, 48, 58, 107, true)
	buildFracturedCliffIsland("P2CDeskBay", 28, 24, -40, 24, 22, 108, true)
	buildFracturedCliffIsland("P2EErrataBay", 250, 20, -80, 48, 58, 109, true)
	buildFracturedCliffIsland("P3CLedgerBay", 32, 36, -218, 26, 22, 110, true)
	buildFracturedCliffIsland("P3EInkCellarBay", 250, 32, -180, 48, 54, 111, true)

	-- =========================================================================
	-- C. SANCTUARY (THE SHELFMARK STAIR) & BASIN (THE INDEX FLOOR + RULED COURT)
	-- =========================================================================
	local sanctuary = P.Sanctuary
	if sanctuary then
		local sx, sy, sz = sanctuary.X, sanctuary.Y, sanctuary.Z
		buildFracturedCliffIsland("SanctuaryBase", sx, sy, sz, sanctuary.Width, sanctuary.Depth, 201, false)
		ctx.group("AstralConcourseDeck", function()
			local frontZ = sz - sanctuary.Depth * 0.5 + 1.0
			balustradeSpan(sx - 62, frontZ, -17, frontZ, sy, true)
			balustradeSpan(17, frontZ, sx + 62, frontZ, sy, true)

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
			enableFences()
			pin(ctx.current())
		end)
	end

	local basin = P.Basin
	if basin then
		local bx, by, bz = basin.X, basin.Y, basin.Z
		local bw, bd = basin.Width, basin.Depth
		local halfW, halfD = bw * 0.5, bd * 0.5
		buildFracturedCliffIsland("BasinIndexFloor", bx, by, bz, bw, bd, 202, false)

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

			-- ICONIC CENTER ARRIVAL ASTROLABE COURT & 8-LECTERN RING (X = 0, Z = 225)
			local cx, cz = 0, bz
			ctx.cyl("AstrolabeStoneRim", V(cx, by + 0.08, cz), 27.5, 0.14, STONE_LIGHT, Mat.Slate)
			ctx.cyl("AstrolabeInnerDisc", V(cx, by + 0.15, cz), 24.0, 0.12, STONE_TOP, Mat.Slate)
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
			boxAt("AstrolabeCrack1", CFrame.new(V(cx + 3, by + 0.26, cz - 1)) * CFrame.Angles(0, math.rad(28), 0), V(26, 0.08, 0.95), CLIFF_DEEP, Mat.Slate)
			boxAt("AstrolabeCrack2", CFrame.new(V(cx - 8, by + 0.26, cz + 5)) * CFrame.Angles(0, math.rad(-14), 0), V(16, 0.08, 0.72), CLIFF_DEEP, Mat.Slate)

			for _, deg in { -145, -115, -65, -35, 35, 65, 115, 145 } do
				local a = math.rad(deg)
				local lx = cx + math.sin(a) * 23.2
				local lz = cz + math.cos(a) * 23.2
				local faceInYaw = math.deg(math.atan2(cx - lx, cz - lz))
				buildWoodenLectern(V(lx, by, lz), faceInYaw)
			end

			for _, colSpec in {
				{ -46, 248, 26, 9.5, 2.2 },
				{ 46, 248, -30, 9.5, 2.2 },
				{ -204, 224, 15, 8.0, 2.0 },
				{ 204, 224, -18, 8.0, 2.0 },
			} do
				local cf = CFrame.new(V(colSpec[1], by + colSpec[5] * 0.85, colSpec[2])) * CFrame.Angles(0, math.rad(colSpec[3]), math.pi / 2)
				local cyl = boxAt("FallenColumn", cf, V(colSpec[5] * 2, colSpec[4], colSpec[5] * 2), STONE_LIGHT, Mat.Marble)
				cyl.Shape = Enum.PartType.Cylinder
			end
			for i = 1, 14 do
				local px = -180 + i * 25 + math.sin(i * 3.1) * 10
				local pz = 200 + math.cos(i * 2.4) * 28
				boxAt("ScatteredPage", CFrame.new(V(px, by + 0.12, pz)) * CFrame.Angles(0, math.rad(i * 41), 0), V(2.4, 0.06, 1.8), VELLUM_PAGE, Mat.Fabric)
			end

			makeDecor(ctx.current())
			enableFences()
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- D. THE LIFTED INDEX (APEX: BACK-WEST Y=52) — MOUNTAIN PEAKS, MOSAIC & GALLERY
	-- =========================================================================
	local apex = P.Apex
	if apex then
		local ax, ay, az = apex.X, apex.Y, apex.Z
		ctx.group("AstralSanctumRays", function()
			ctx.cyl("LiftedMosaicOuter", V(ax, ay + 0.08, az), 34.0, 0.10, STONE_LIGHT, Mat.Slate)
			ctx.cyl("LiftedMosaicInner", V(ax, ay + 0.13, az), 22.0, 0.10, STONE_TOP, Mat.Slate)
			ctx.ring("LiftedGoldRing1", V(ax, ay + 0.19, az), 34.0, 0.65, GOLD_BRIGHT, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 32)
			ctx.ring("LiftedGoldRing2", V(ax, ay + 0.20, az), 22.0, 0.45, BRASS_AGED, Mat.Metal, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 26)
			ctx.ring("LiftedGoldRing3", V(ax, ay + 0.21, az), 11.0, 0.35, GOLD_LIGHT, Mat.Neon, CFrame.Angles(math.pi / 2, 0, 0), 0, math.pi * 2, 20)

			-- Flanking wing bookcases strictly on the outer NW & NE corners of Apex (clear of both S & E bridges!)
			buildStandingBookcase(V(ax - 54, ay, az - 30), 82, 1.35)
			buildStandingBookcase(V(ax + 54, ay, az - 30), -82, 1.35)

			-- Towering jagged mountain peaks cleanly BEHIND LiftedIndexGallery (never clipping its archway!)
			buildMountainCrag(V(ax, ay - 6, az - 98), V(98, 108, 30), 4, -6)
			buildMountainCrag(V(ax - 74, ay - 6, az - 78), V(60, 88, 40), 24, -6)
			buildMountainCrag(V(ax + 72, ay - 6, az - 82), V(54, 72, 34), -22, -6)
			buildMountainCrag(V(ax - 84, ay - 14, az - 10), V(40, 62, 54), 12, -8)

			-- Warm glowing lantern posts flanking the top of the straight grand staircase (ShardB -> Apex at X = ax!)
			local sZ = az + apex.Depth * 0.5 - 1.2
			for _, lp in { V(ax - 17, ay, sZ), V(ax + 17, ay, sZ) } do
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
			-- South edge split cleanly around the straight grand staircase (ax ± 12.2)
			balustradeSpan(wX + 3, sZ, ax - 12.2, sZ, ay, true)
			balustradeSpan(ax + 12.2, sZ, eX - 3, sZ, ay, true)
			-- West edge solid balustrade
			balustradeSpan(wX, az - 34, wX, sZ - 4, ay, true)
			-- East edge split cleanly around P4C -> Apex bridge (az ± 12.2)
			balustradeSpan(eX, az + 12.2, eX, sZ - 4, ay, true)
			balustradeSpan(eX, az - 34, eX, az - 12.2, ay, true)
			makeDecor(ctx.current())
			enableFences()
			pin(ctx.current())
		end)
	end

	-- =========================================================================
	-- E. LANDMARKS (1..20) — COHESIVE, SOLIDLY GROUNDED & ZERO PATH BLOCKING!
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

		local stW = piece("IndexEngineShelfTowerWest", 144, -340, -6, "IndexEngineShelfTower", 0.96, LIBRARY_TINT, function(cf)
			boxAt("ShelfTowerW", cf * CFrame.new(0, 44, 0), V(30, 88, 14), WOOD_WARM, Mat.Wood)
		end, core.Y)
		pin(stW)
		makeDecor(stW)

		ctx.group("AstralIsleDeck", function()
			buildMountainCrag(V(294, core.Y - 8, -352), V(52, 72, 40), -18, -6)
			buildMountainCrag(V(124, core.Y - 8, -354), V(46, 58, 36), 22, -6)
			for i = 1, 20 do
				local px = 166 + (i % 7) * 14 + math.sin(i * 2.1) * 5
				local pz = -332 + math.floor(i / 7) * 8 + math.cos(i * 1.7) * 3
				boxAt("EngineSpillPage", CFrame.new(V(px, (core.Y :: number) + 0.12 + (i % 3) * 0.05, pz)) * CFrame.Angles(0, math.rad(i * 33), 0), V(3.2, 0.10, 2.4), VELLUM_PAGE, Mat.Fabric)
			end
			makeDecor(ctx.current())
			pin(ctx.current())
		end)
	end

	-- 4. THE LIFTED INDEX GALLERY (Prominent curved two-tier mahogany library rotunda grounded behind Apex!)
	do
		local lm = AstralFloor43.Landmarks[4]
		local mg = piece("LiftedIndexGallery", lm.X, lm.Z, 0, "LiftedIndexGallery", 1.44, LIBRARY_TINT, function(cf)
			boxAt("LiftedGallery", cf * CFrame.new(0, 18, 0), V(74, 36, 24), WOOD_WARM, Mat.Wood)
		end, lm.Y)
		pin(mg)
		if mg then addLight(H.glowOf(mg) or mg:FindFirstChildWhichIsA("BasePart", true), GOLD_LIGHT, 2.8, 130) end
	end

	-- 5–15. Grounded Plate Landmarks (every single one on its solid outer terrace bay!)
	local plateSpecs = {
		{ AstralFloor43.Landmarks[5], "ColophonWall", 0, LIBRARY_TINT, 1.08 },
		{ AstralFloor43.Landmarks[6], "BinderyPress", 90, LIBRARY_TINT, 1.15 },
		{ AstralFloor43.Landmarks[7], "ErrataPress", -90, LIBRARY_TINT, 1.12 },
		{ AstralFloor43.Landmarks[8], "CatalogueDeskTilted", 18, LIBRARY_TINT, 1.10 },
		{ AstralFloor43.Landmarks[9], "LedgerStackTall", 0, LIBRARY_TINT, 1.12 },
		{ AstralFloor43.Landmarks[10], "InkVatCracked", -80, INK_VAT_TINT, 1.18 },
		{ AstralFloor43.Landmarks[11], "ToppledShelfRange", 72, LIBRARY_TINT, 1.10 },
		{ AstralFloor43.Landmarks[12], "ToppledShelfRange", -72, LIBRARY_TINT, 1.10 },
		{ AstralFloor43.Landmarks[13], "CardDrawerSpill", 25, LIBRARY_TINT, 1.15 },
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

	-- Extra rich library bookcases & jagged mountain peaks strictly on SOLID OUTER BAYS (ZERO blocking walkways!)
	ctx.group("AstralIsleDeck", function()
		-- WestGalleryBay outer western rim (X = -258, backed cleanly by peaks at -300)
		buildStandingBookcase(V(-258, 16, 56), 92, 1.15)
		buildStandingBookcase(V(-258, 16, 96), 86, 1.12)
		buildMountainCrag(V(-300, 10, 76), V(38, 56, 68), 10, -8)

		-- EastGalleryBay outer eastern rim (X = +268, backed cleanly by peaks at +310)
		buildStandingBookcase(V(268, 8, 56), -92, 1.15)
		buildStandingBookcase(V(268, 8, 96), -86, 1.12)
		buildMountainCrag(V(310, 2, 76), V(38, 56, 68), -10, -8)

		-- P2WBinderyBay outer western rim (X = -256, backed cleanly by peak at -298)
		buildStandingBookcase(V(-256, 28, -98), 78, 1.08)
		ctx.cyl("BinderyColumnStub", V(-252, 32.5, -60), 2.3, 9.0, STONE_LIGHT, Mat.Marble)
		buildMountainCrag(V(-298, 22, -80), V(36, 56, 60), 12, -8)

		-- P2EErrataBay outer eastern rim (X = +266, backed cleanly by peak at +308)
		buildStandingBookcase(V(266, 20, -96), -82, 1.08)
		buildMountainCrag(V(308, 14, -80), V(36, 54, 58), -12, -8)

		-- P3EInkCellarBay outer eastern rim (X = +266, backed cleanly by peak at +308)
		buildStandingBookcase(V(266, 32, -166), -98, 1.10)
		buildMountainCrag(V(308, 26, -180), V(38, 58, 62), -12, -8)

		-- P4CColophonBay outer northern backdrop peak (X = 0, Z = -372)
		buildMountainCrag(V(0, 42, -372), V(70, 52, 24), 4, -6)

		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Companion spilled indigo ink vat on WestGalleryBay south-west corner (Image 1 bottom-left!)
	do
		local wVat = piece("WestrangeInkVat", -236, 100, 40, "InkVatCracked", 1.08, INK_VAT_TINT, function(cf)
			ctx.cyl("WestInkPuddle", cf.Position + V(0, 0.2, 0), 5.0, 0.3, rgb(64, 52, 164), Mat.Glass)
		end, 16)
		pin(wVat)
		tagDetail(wVat)
	end

	-- Companion reading desks strictly on outer bays (never on walkways!)
	for _, dSpec in {
		{ -234, 56, 16, 115, 1.02 },
		{ 244, 56, 8, -110, 1.02 },
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
		{ -242, 112, -2, 0 },
		{ 252, 111, -8, 0 },
		{ -214, -254, 34, 0 },
	} do
		local ms = piece("AstralIsleUnderside", extraStrata[1], extraStrata[2], extraStrata[4], "ScarpShelfStrata", 0.96, LIBRARY_TINT, function(cf)
			boxAt("ShelfStrataExtra", cf * CFrame.new(0, 8, 0), V(30, 16, 9), CLIFF_ROCK, Mat.Slate)
		end, extraStrata[3])
		pin(ms)
		makeDecor(ms)
	end

	-- 19–20. Sculpted Page Fall Ribbons anchored FLUSH at real cliff lips pouring downward into the violet rifts!
	for _, spec in {
		{ AstralFloor43.Landmarks[19], 24 }, -- P2CDeskBay south lip (Y=24)
		{ AstralFloor43.Landmarks[20], 36 }, -- P3C NW lip (Y=36)
	} do
		local lm = spec[1]
		local lipY = spec[2]
		local mp = piece("AstralIsleUnderside", lm.X, lm.Z, 0, "PageFallRibbon", 1.40, RIFTWARD_43, function(cf)
			boxAt("PageCascade", cf * CFrame.new(0, 10, 0), V(8, 20, 10), VELLUM_PAGE, Mat.Fabric)
		end, lipY - 30)
		pin(mp)
		makeDecor(mp)
		pageEmitter(V(lm.X, lipY - 4, lm.Z), 4)
	end
	for _, extra in {
		{ -136, 16, 110, -24, 1.38 },   -- WestGallery SE cliff lip pouring into foreground chasm (Image 1 bottom-left!)
		{ 146, 8, 109, 24, 1.34 },      -- EastGallery SW cliff lip pouring into foreground chasm (Image 1 bottom-right!)
		{ -28, 36, -153, 0, 1.40 },     -- P3C south-west cliff lip cascading into Rift B!
		{ 154, 44, -268, 28, 1.48 },    -- Broken Index Engine SW cliff lip pouring into Rift C!
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
		{ "ShardA", "ShardSlabM", 25.114, 29.314, 22.261, 58, 44, 30.0 },
		{ "ShardE", "ShardSlabM", 25.114, 29.314, 22.261, 58, 44, 26.0 },
		{ "ShardB", "ShardSlabL", 38.027, 35.314, 32.010, 68, 44, 38.0 },
		{ "ShardC", "ShardSlabM", 25.114, 29.314, 22.261, 54, 46, 38.0 },
	} do
		local id: string = row[1]
		local plat = P[id]
		if not plat then continue end
		local kitName: string = row[2]
		local kitW: number, kitH: number, kitD: number = row[3], row[4], row[5]
		local pw: number, pd: number = row[6], row[7]
		local availH: number = row[8]

		-- Keep Shard rim strictly BELOW `plat.Y` (`top = plat.Y - 0.14`) so zero z-fighting with the solid Shard deck!
		ctx.group("AstralIsleUnderside", function()
			boxAt(id .. "ShardRim", CFrame.new(V(plat.X, plat.Y - 1.14, plat.Z)), V(pw + 1.0, 2.0, pd + 1.0), STONE_TOP, Mat.Slate)
			boxAt(id .. "ShardBrassBand", CFrame.new(V(plat.X, plat.Y - 2.20, plat.Z)), V(pw + 1.4, 0.42, pd + 1.4), BRASS_AGED, Mat.Metal)
			boxAt(id .. "ShardCrack", CFrame.new(V(plat.X, plat.Y + 0.06, plat.Z)) * CFrame.Angles(0, math.rad(24), 0), V(pw * 0.58, 0.04, 0.65), CLIFF_DEEP, Mat.Slate)
			makeDecor(ctx.current())
			pin(ctx.current())
		end)

		local sx = (pw * 1.04) / kitW
		local sy = availH / kitH
		local sz = (pd * 1.04) / kitD
		local ms = placeKitScaled("AstralIsleUnderside", plat.X, (plat.Y - 2.5) - availH, plat.Z, (plat.X * 0.3) % 360, kitName, V(sx, sy, sz), SHARD_UNDERSIDE_TINT, function(cf)
			ctx.cyl("ShardUndersideCone", cf.Position + V(0, availH * 0.5, 0), pw * 0.44, availH, CLIFF_ROCK, Mat.Slate)
		end)
		makeDecor(ms)
	end

	-- Iconic catenary hanging brass chains anchoring floating shards cleanly across the violet chasm
	ctx.group("AstralIsleUnderside", function()
		local chainPairs = {
			{ V(-28, 15, 6), V(-134, 13, 44), 12, 8 },
			{ V(28, 15, 6), V(146, 6, 44), 12, 8 },
			{ V(-28, 15, -18), V(-136, 25, -52), 12, 8 },
			{ V(28, 15, -18), V(146, 17, -52), 12, 8 },
			{ V(-144, 36, -162), V(-38, 22, -108), 13, 8 },
			{ V(-144, 36, -200), V(-118, 48, -258), 14, 10 },
			{ V(70, 39, -276), V(36, 33, -206), 12, 8 },
			{ V(122, 39, -276), V(148, 30, -206), 12, 8 },
		}
		for _, cp in chainPairs do
			buildHangingChain(cp[1], cp[2], cp[3], cp[4])
		end
		makeDecor(ctx.current())
		pin(ctx.current())
	end)

	-- Warm glowing Crooked Index Lamps strictly at outer corners of floating shards & platforms (ZERO bridge blocking!)
	local lampSpecs = {
		{ -24, 18, 16, 35, true },
		{ 210, 14, 16, -45, true },
		{ -204, 39, -162, 55, true },
		{ 96, 42, -314, 0, true },
		{ -36, 12, 102, 18, true },
		{ -210, 28, -56, 40, true },
		{ 220, 20, -56, -40, true },
		{ 34, 36, -158, -25, false },
		{ 214, 44, -274, -32, true },
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
	-- =========================================================================
	ctx.group("AstralSplitAurora", function()
		addAuroraCurtain("AuroraTealSweep", V(-185, 168, -360), V(175, 202, -382), 18, 24, AURORA_TEAL, rgb(86, 226, 208), 0.80)
		addAuroraCurtain("AuroraVioletSweep", V(-125, 138, -348), V(215, 168, -370), 22, 28, RIFT_VIOLET, RIFT_MAGENTA, 0.82)
		addAuroraCurtain("AuroraTealWisp", V(-75, 186, -372), V(130, 208, -386), 12, 16, rgb(120, 242, 224), AURORA_TEAL, 0.86)

		addAuroraMistCloud(V(-60, 152, -356), AURORA_TEAL, RIFT_VIOLET, 130)
		addAuroraMistCloud(V(65, 174, -368), RIFT_VIOLET, AURORA_TEAL, 140)

		local lightningBranches = {
			{ V(-188, 128, -338), V(-146, 152, -352), V(-112, 170, -362), V(-80, 186, -370) },
			{ V(-146, 152, -352), V(-172, 174, -360) },
			{ V(214, 156, -344), V(256, 174, -358), V(298, 192, -370), V(334, 208, -378) },
			{ V(256, 174, -358), V(284, 154, -354) },
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

	pageEmitter(V(186, 54, -296), 4)
	pageEmitter(V(-176, 44, -180), 3)
	pageEmitter(V(-176, 58, -296), 3)
	pageEmitter(V(28, 24, -24), 3)

	ctx.setAttribute("AstralFloor", 43)
	ctx.setAttribute("AstralLights", lightsUsed)
end

return AstralFloor43
