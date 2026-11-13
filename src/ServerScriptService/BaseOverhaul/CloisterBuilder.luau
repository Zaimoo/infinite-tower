--!strict
-- CloisterBuilder.luau
-- ModuleScript: builds the Cloister Commons, the solid rounded-rectangle garden hub in front of the tower gate
-- (GDD §3.5): the Wayfinder Dais at the centre, cobbled paths from it to every plot landing and the South
-- Gate, and a landing for each of the 8 plots on its outer edge.
-- Hub-local frame: origin at HubLayout.HubCentre, y = 0 is the walking surface (world Y = 12),
-- -Z is north (away from the tower), +Z is south (toward the tower gate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local HubLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout"))
local PartKit = require(script.Parent:WaitForChild("PartKit"))
local WallsBuilder = require(script.Parent:WaitForChild("WallsBuilder"))
local GothicLanternSpawner = require(script.Parent:WaitForChild("GothicLanternSpawner"))

local CloisterBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
CloisterBuilder.Config = {
	RandomSeed = 6502026,
	TopThickness = 6,
	WallHeight = 3.5,
	PathWidth = 16,
	PlazaRadius = 36,
	PavilionScale = 1.7, -- Room for the shared boards at SharedLeaderboards.BoardScale

	-- Banner colour per plot (Plot_1 .. Plot_8), shown on each gate landing
	PlotColors = {
		Color3.fromRGB(196, 58, 58),
		Color3.fromRGB(214, 142, 46),
		Color3.fromRGB(206, 190, 70),
		Color3.fromRGB(90, 172, 72),
		Color3.fromRGB(56, 160, 160),
		Color3.fromRGB(66, 128, 204),
		Color3.fromRGB(130, 90, 204),
		Color3.fromRGB(200, 90, 160),
	},
}

-- Palette
local GRASS = Color3.fromRGB(64, 92, 52)
local SLATE = Color3.fromRGB(58, 62, 68)
local SLATE_DARK = Color3.fromRGB(40, 42, 48)
local COBBLE = Color3.fromRGB(92, 88, 84)
local MARBLE = Color3.fromRGB(200, 196, 188)
local STATUE = Color3.fromRGB(222, 218, 208)
local CRIMSON = Color3.fromRGB(145, 28, 38)
local CYAN = Color3.fromRGB(80, 220, 255)
local IRON = Color3.fromRGB(40, 40, 44)
local WOOD = Color3.fromRGB(92, 64, 42)
local HEDGE = Color3.fromRGB(40, 70, 38)
local LANTERN = Color3.fromRGB(255, 196, 120)
local ROCK_UPPER = Color3.fromRGB(65, 68, 72)
local ROCK_DEEP = Color3.fromRGB(42, 45, 50)

-- One tint per tower biome, in floor order (MobCatalog.Biomes)
local BIOME_COLORS = {
	Color3.fromRGB(88, 170, 82), -- Verdant Ruins
	Color3.fromRGB(150, 92, 190), -- Fungal Hollow
	Color3.fromRGB(214, 184, 120), -- Ashen Dunes
	Color3.fromRGB(150, 210, 240), -- Frozen Citadel
	Color3.fromRGB(240, 120, 40), -- Infernal Foundry
	Color3.fromRGB(240, 200, 60), -- Thunder Highlands
	Color3.fromRGB(110, 50, 100), -- Corrupted Grove
	Color3.fromRGB(50, 170, 160), -- Sunken Sanctuary
	Color3.fromRGB(140, 110, 240), -- Astral Archives
	Color3.fromRGB(190, 30, 46), -- Abyssal Throne
}

--============================================================================
-- HELPER FUNCTIONS
--============================================================================
local makePart = PartKit.Part
local makeWedge = PartKit.Wedge

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Park-local (x, z) for a bearing in degrees and a radius.
local function polar(deg: number, r: number): (number, number)
	local a = math.rad(deg)
	return math.sin(a) * r, -math.cos(a) * r
end

-- Smallest signed difference between two bearings, in degrees.
local function bearingDelta(a: number, b: number): number
	return (a - b + 540) % 360 - 180
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function cylinderY(name: string, radius: number, height: number, topY: number, cf: CFrame, color: Color3, material: Enum.Material, decorative: boolean, parent: Instance): Part
	return makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = cf * CFrame.new(0, topY - height * 0.5, 0) * CFrame.Angles(0, 0, math.pi * 0.5),
		Color = color,
		Material = material,
		Decorative = decorative,
		Parent = parent,
	})
end

-- CFrame on the park at bearing/radius with -Z looking back at the park centre.
local function facingCentre(root: CFrame, deg: number, r: number, y: number): CFrame
	local x, z = polar(deg, r)
	local pos = root * CFrame.new(x, y, z)
	local centre = root * CFrame.new(0, y, 0)
	if r < 0.01 then
		return pos
	end
	return CFrame.lookAt(pos.Position, centre.Position)
end

local function bench(name: string, cf: CFrame, parent: Instance)
	-- cf: seat centre at ground level, -Z is the direction the sitter faces
	makePart({ Name = name .. "_Seat", Size = Vector3.new(6, 0.6, 2), CFrame = cf * CFrame.new(0, 1.6, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = parent })
	makePart({ Name = name .. "_Back", Size = Vector3.new(6, 2, 0.4), CFrame = cf * CFrame.new(0, 2.9, 0.9), Color = SLATE, Material = Enum.Material.Slate, Decorative = true, Parent = parent })
	for _, side in { -1, 1 } do
		makePart({ Name = name .. "_Leg", Size = Vector3.new(0.6, 1.3, 1.6), CFrame = cf * CFrame.new(side * 2.5, 0.65, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = parent })
	end
end

local function flatStrip(name: string, root: CFrame, x0: number, z0: number, x1: number, z1: number, width: number, y: number, thick: number, color: Color3, material: Enum.Material, parent: Instance): Part
	local a = Vector3.new(x0, 0, z0)
	local b = Vector3.new(x1, 0, z1)
	local mid = (a + b) * 0.5
	local len = (b - a).Magnitude
	return makePart({
		Name = name,
		Size = Vector3.new(width, thick, len),
		CFrame = root * CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(b.X, y, b.Z)),
		Color = color,
		Material = material,
		Decorative = true,
		Parent = parent,
	})
end

--============================================================================
-- ROUNDED-RECTANGLE GEOMETRY
--============================================================================
-- Walks the edge of a hub-local rounded rectangle and calls fn(x, z, nx, nz, len, isArc) for each piece,
-- where (x, z) is the piece's midpoint on the edge, (nx, nz) the outward normal and len its length.
-- Straight sides are cut into pieces of at most `step`; the corner arcs use `arcStep` (default `step`).
local function walkRoundedRect(hx: number, hz: number, r: number, step: number, fn: (number, number, number, number, number, boolean) -> (), arcStep: number?)
	local cx, cz = hx - r, hz - r
	local function straight(x0: number, z0: number, x1: number, z1: number, nx: number, nz: number)
		local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		if len < 0.01 then
			return
		end
		local n = math.max(1, math.ceil(len / step))
		for i = 1, n do
			local t = (i - 0.5) / n
			fn(x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, nx, nz, len / n, false)
		end
	end
	straight(-cx, hz, cx, hz, 0, 1)
	straight(-cx, -hz, cx, -hz, 0, -1)
	straight(hx, -cz, hx, cz, 1, 0)
	straight(-hx, -cz, -hx, cz, -1, 0)
	if r > 0 then
		local arc = math.pi * 0.5 * r
		local n = math.max(2, math.ceil(arc / (arcStep or step)))
		for _, q in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			for i = 1, n do
				local a = (i - 0.5) / n * math.pi * 0.5
				local nx, nz = q[1] * math.cos(a), q[2] * math.sin(a)
				fn(q[1] * cx + nx * r, q[2] * cz + nz * r, nx, nz, arc / n, true)
			end
		end
	end
end

-- CFrame at hub-local (x, z) on an edge, its -Z looking inward against the outward normal (nx, nz).
local function edgeCF(root: CFrame, x: number, z: number, nx: number, nz: number, y: number): CFrame
	local pos = (root * CFrame.new(x, y, z)).Position
	return CFrame.lookAt(pos, pos - Vector3.new(nx, 0, nz))
end

-- Pieces that must overlap (corner slices, curved wall pieces) would flicker if their faces shared a height
-- (z-fighting). Each gets a tiny drop that cycles through 6 levels, so no overlapping pair matches.
local function layerDrop(index: number, step: number?): number
	return (index % 6 + 1) * (step or 0.025)
end

-- Invisible safety barriers must stand higher than a jump made from the top of a 3-4 stud wall
local BARRIER_HEIGHT = 20

local function nearAny(x: number, z: number, points: { { number } }, radius: number): boolean
	for _, p in points do
		if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < (radius + (p[3] or 0)) ^ 2 then
			return true
		end
	end
	return false
end

-- Hub-local openings in the outer rim: each plot landing plus the South Gate. {x, z, halfWidth}
local function outerOpenings(): { { number } }
	local list = {}
	local c = HubLayout.HubCentre
	for i = 1, HubLayout.PlotCount do
		local land = HubLayout.HubLandingPoint(i)
		table.insert(list, { land.X - c.X, land.Z - c.Z, HubLayout.PlotGateWidth * 0.5 })
	end
	table.insert(list, { 0, HubLayout.HubHalfZ, HubLayout.SouthGateWidth * 0.5 })
	return list
end

-- Radius of the Wayfinder Dais plaza once scaled (PlazaRadius 36 x 1.5); paths end just under its curb.
local DAIS_EDGE = 56

-- Hub-local garden paths as {x0, z0, x1, z1, width}: one from each plot landing straight to the dais, one
-- from the dais north through the Reflecting Pool, and last the Pilgrim's Way from the South Gate.
local function gardenPaths(): { { number } }
	local c = HubLayout.HubCentre
	local list = {}
	for i = 1, HubLayout.PlotCount do
		local land = HubLayout.HubLandingPoint(i)
		local lx, lz = land.X - c.X, land.Z - c.Z
		local len = math.sqrt(lx * lx + lz * lz)
		table.insert(list, { lx, lz, lx / len * DAIS_EDGE, lz / len * DAIS_EDGE, CloisterBuilder.Config.PathWidth })
	end
	table.insert(list, { 0, -HubLayout.HubHalfZ + 30, 0, -DAIS_EDGE, CloisterBuilder.Config.PathWidth })
	table.insert(list, { 0, HubLayout.HubHalfZ, 0, DAIS_EDGE, HubLayout.BoulevardWidth })
	return list
end

local function segmentDistance(px: number, pz: number, seg: { number }): number
	local dx, dz = seg[3] - seg[1], seg[4] - seg[2]
	local t = math.clamp(((px - seg[1]) * dx + (pz - seg[2]) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((seg[1] + t * dx - px) ^ 2 + (seg[2] + t * dz - pz) ^ 2)
end

-- A low wall along a rounded-rect edge, offset inward by `inset` (negative = outward), broken at the
-- openings, with an invisible safety barrier on the side that drops away.
local function edgeWall(parent: Instance, root: CFrame, hx: number, hz: number, r: number, inset: number, height: number, openings: { { number } }, outwardIsDrop: boolean)
	local barriers = folder("InvisibleEdgeBarriers", parent)
	local barrierZ = if outwardIsDrop then 1.6 else -1.6
	local pieceIndex = 0
	local function emit(x: number, z: number, nx: number, nz: number, len: number, isArc: boolean?)
		pieceIndex += 1
		local cf = edgeCF(root, x - nx * inset, z - nz * inset, nx, nz, 0)
		local h = if isArc then height + layerDrop(pieceIndex, 0.03) else height
		makePart({ Name = "EdgeWall", Size = Vector3.new(len + 0.6, h, 2 + (if isArc then pieceIndex % 3 * 0.02 else 0)), CFrame = cf * CFrame.new(0, h * 0.5, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = parent })
		local barrier = makePart({ Name = "Barrier", Size = Vector3.new(len + 0.6, BARRIER_HEIGHT, 1), CFrame = cf * CFrame.new(0, BARRIER_HEIGHT * 0.5, barrierZ), Transparency = 1, CastShadow = false, Parent = barriers })
		barrier.CanQuery = false
		barrier.CanTouch = false
		-- Crenels every 16 studs along the piece
		local count = math.floor(len / 16)
		for k = 1, count do
			local off = (k - (count + 1) * 0.5) * 16
			makePart({ Name = "EdgeCrenel", Size = Vector3.new(6, 1.2, 2.4), CFrame = cf * CFrame.new(off, height + 0.6, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = parent })
		end
	end
	-- Group contiguous straight pieces into runs; flush a run at every opening and before each arc piece
	-- A run remembers its first and last piece midpoints; pieces on one side are equal length, so the next
	-- piece is contiguous when its midpoint sits one piece length past the last one (in either direction).
	local run: { x0: number, z0: number, x1: number, z1: number, nx: number, nz: number, len: number, piece: number }? = nil
	local function flush()
		if run then
			emit((run.x0 + run.x1) * 0.5, (run.z0 + run.z1) * 0.5, run.nx, run.nz, run.len)
			run = nil
		end
	end
	walkRoundedRect(hx, hz, r, 4, function(x, z, nx, nz, len, isArc)
		if nearAny(x, z, openings, 2) then
			flush()
			return
		end
		if isArc then
			flush()
			emit(x, z, nx, nz, len, true)
			return
		end
		local r0 = run
		if r0 and r0.nx == nx and r0.nz == nz and math.abs(math.sqrt((x - r0.x1) ^ 2 + (z - r0.z1) ^ 2) - r0.piece) < 0.01 then
			r0.x1, r0.z1, r0.len = x, z, r0.len + len
		else
			flush()
			run = { x0 = x, z0 = z, x1 = x, z1 = z, nx = nx, nz = nz, len = len, piece = len }
		end
	end, 12)
	flush()
end

-- Tapered rock clusters hanging under a stretch of ground.
local function rockChunk(parent: Instance, base: CFrame, w: number, d: number, depth: number, rng: Random)
	local y = -CloisterBuilder.Config.TopThickness
	for tier = 1, 3 do
		local t = (tier - 1) / 2
		local h = depth / 3
		makePart({
			Name = "RockTier",
			Size = Vector3.new(w * (1 - t * 0.55), h + 2, d * (1 - t * 0.55)),
			CFrame = base * CFrame.new(0, y - h * 0.5, 0) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0),
			Color = ROCK_UPPER:Lerp(ROCK_DEEP, t),
			Material = Enum.Material.Slate,
			Decorative = true,
			Parent = parent,
		})
		y -= h
	end
	makeWedge({
		Name = "RockSpike",
		Size = Vector3.new(w * 0.35, depth * 0.5, d * 0.35),
		CFrame = base * CFrame.new(0, y - depth * 0.2, 0) * CFrame.Angles(math.pi, rng:NextNumber(0, math.pi), 0),
		Color = ROCK_DEEP,
		Material = Enum.Material.Slate,
		Decorative = true,
		Parent = parent,
	})
end

--============================================================================
-- A. BAND, VOID EDGES AND ISLAND
--============================================================================
local function buildGround(model: Model, root: CFrame, cfg: typeof(CloisterBuilder.Config), rng: Random): Part
	local f = folder("Ground", model)
	local hx, hz, r = HubLayout.HubHalfX, HubLayout.HubHalfZ, HubLayout.OuterCornerRadius
	local th = cfg.TopThickness

	-- Solid rounded rectangle: a full-length middle slab, a side slab each way between the corners, and four
	-- corner discs. The slabs meet edge to edge; the discs overlap them, so they sit a few hundredths lower.
	local first = makePart({ Name = "CommonsSurface", Size = Vector3.new((hx - r) * 2, th, hz * 2), CFrame = root * CFrame.new(0, -th * 0.5, 0), Color = GRASS, Material = Enum.Material.Grass, Parent = f })
	for _, side in { -1, 1 } do
		makePart({ Name = "CommonsSurface", Size = Vector3.new(r, th, (hz - r) * 2), CFrame = root * CFrame.new(side * (hx - r * 0.5), -th * 0.5, 0), Color = GRASS, Material = Enum.Material.Grass, Parent = f })
	end
	for _, q in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		cylinderY("CommonsCorner", r, th, -0.06, root * CFrame.new(q[1] * (hx - r), 0, q[2] * (hz - r)), GRASS, Enum.Material.Grass, false, f)
	end
	-- Stone kerb along the outer edge, standing 0.1 proud of the grass so their side faces never coincide
	local kerbIndex = 0
	walkRoundedRect(hx, hz, r, 400, function(x, z, nx, nz, len)
		kerbIndex += 1
		makePart({ Name = "OuterKerb", Size = Vector3.new(len + 0.6, th - 0.1, 6), CFrame = edgeCF(root, x - nx * 2.9, z - nz * 2.9, nx, nz, -0.3 - layerDrop(kerbIndex)) * CFrame.new(0, -(th - 0.1) * 0.5, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	end, 12)

	-- Rocky underside: chunks around the rim and a tapered mass under the middle
	local under = folder("RockyUnderside", f)
	walkRoundedRect(hx - 50, hz - 50, r - 40, 90, function(x, z, nx, nz)
		rockChunk(under, edgeCF(root, x, z, nx, nz, 0), rng:NextNumber(70, 95), 90, rng:NextNumber(50, 80), rng)
	end)
	rockChunk(under, root, hx * 1.6, hz * 1.6, 160, rng)

	return first
end

--============================================================================
-- B. RIM WALL, VOID BALUSTRADES, LAMPS AND PROMENADE
--============================================================================
local function spawnRimLanterns(lamps: Instance, root: CFrame)
	local hx, hz, ro = HubLayout.HubHalfX, HubLayout.HubHalfZ, HubLayout.OuterCornerRadius
	local n = 0
	local openings = outerOpenings()
	walkRoundedRect(hx - 6, hz - 6, ro - 6, 70, function(x, z, nx, nz)
		if nearAny(x, z, openings, 10) then
			return
		end
		n += 1
		local name = string.format("GothicLantern_Rim_%d", n)
		if lamps:FindFirstChild(name) then
			return
		end
		local cf = edgeCF(root, x, z, nx, nz, 0)
		GothicLanternSpawner.Spawn(lamps, cf, name)
	end)
end

local function buildEdges(model: Model, root: CFrame, cfg: typeof(CloisterBuilder.Config))
	local hx, hz, ro = HubLayout.HubHalfX, HubLayout.HubHalfZ, HubLayout.OuterCornerRadius
	edgeWall(folder("RimWall", model), root, hx, hz, ro, 1.5, cfg.WallHeight, outerOpenings(), true)

	-- Gothic medieval lantern posts along the outer rim
	spawnRimLanterns(folder("LampPylons", model), root)

	-- Cobbled paths from every landing to the dais. Neighbouring paths cross near the dais, so each sits at
	-- its own height to avoid z-fighting. (The last entry is the Pilgrim's Way, built by the terrace.)
	local walk = folder("GardenPaths", model)
	local paths = gardenPaths()
	for i = 1, #paths - 1 do
		local p = paths[i]
		local t = 0.24 + (i % 3) * 0.03
		flatStrip("GardenPath", root, p[1], p[2], p[3], p[4], p[5], t * 0.5, t, if i % 2 == 0 then COBBLE else COBBLE:Lerp(SLATE, 0.2), Enum.Material.Cobblestone, walk)
	end
end

--============================================================================
-- D. GATE LANDINGS (one per plot)
--============================================================================
local function buildLandings(model: Model, root: CFrame, cfg: typeof(CloisterBuilder.Config))
	local landings = folder("GateLandings", model)
	local c = HubLayout.HubCentre
	for index = 1, HubLayout.PlotCount do
		local slot = HubLayout.PlotSlots[index]
		local land = HubLayout.HubLandingPoint(index)
		local g = folder("Gate_" .. index, landings)
		g:SetAttribute("PlotIndex", index)
		local apron = edgeCF(root, land.X - c.X - slot.DX * 8, land.Z - c.Z - slot.DZ * 8, slot.DX, slot.DZ, 0)
		makePart({ Name = "Apron", Size = Vector3.new(26, 0.36, 16), CFrame = apron * CFrame.new(0, 0.18, 0), Color = COBBLE, Material = Enum.Material.Cobblestone, Decorative = true, Parent = g })
		local rune = cylinderY("GateRune", 4, 0.1, 0.32, apron, CYAN, Enum.Material.Neon, true, g)
		rune.Transparency = 0.35
		for _, side in { -1, 1 } do
			local post = apron * CFrame.new(side * 14, 0, 4)
			makePart({ Name = "BannerPylon", Size = Vector3.new(2, 14, 2), CFrame = post * CFrame.new(0, 7, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = g })
			makePart({ Name = "BannerArm", Size = Vector3.new(0.4, 0.4, 4.6), CFrame = post * CFrame.new(0, 13, -2.3), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = g })
			WallsBuilder.SpawnBanner(
				g,
				"GateBanner_" .. (if side < 0 then "L" else "R"),
				post * CFrame.new(0, 12.8, -2.8) * CFrame.Angles(0, math.pi * 0.5, 0),
				{ Scale = 1.0, DoubleSided = true, IncludeCrossbar = true }
			)
		end
	end
end

--============================================================================
-- E. GRAND TERRACE: SOUTH GATE AND PILGRIM'S WAY
--============================================================================
local function buildGrandTerrace(model: Model, root: CFrame)
	local f = folder("PilgrimsWay", model)
	local hz = HubLayout.HubHalfZ
	local w = HubLayout.BoulevardWidth
	flatStrip("Boulevard", root, 0, hz, 0, DAIS_EDGE, w, 0.18, 0.36, COBBLE, Enum.Material.Cobblestone, f)
	flatStrip("CrimsonRunner", root, 0, hz, 0, -50, 10, 0.4, 0.06, CRIMSON, Enum.Material.Granite, f)
	makePart({
		Name = "HubArrival",
		Size = Vector3.new(10, 1, 6),
		CFrame = root * CFrame.new(0, 0.4, 61),
		Transparency = 1,
		Decorative = true,
		Parent = f,
	})
	for k = 0, 1 do
		for _, side in { -1, 1 } do
			local bz = hz - 30 - k * 50
			local bx = side * (w * 0.5 + 3)
			makePart({ Name = "BrazierStand", Size = Vector3.new(1.2, 4, 1.2), CFrame = root * CFrame.new(bx, 2, bz), Color = IRON, Material = Enum.Material.Metal, Parent = f })
			local bowl = cylinderY("BrazierBowl", 1.6, 1, 4.6, root * CFrame.new(bx, 0, bz), IRON, Enum.Material.Metal, true, f)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 6
			fire.Color = Color3.fromRGB(255, 140, 40)
			fire.SecondaryColor = Color3.fromRGB(200, 40, 20)
			fire.Parent = bowl
			if side == 1 then
				light(bowl, Color3.fromRGB(255, 150, 70), 18, 1.4)
			end
			local pole = root * CFrame.new(bx, 0, bz - 25)
			makePart({ Name = "BannerPole", Size = Vector3.new(0.8, 18, 0.8), CFrame = pole * CFrame.new(0, 9, 0), Color = IRON, Material = Enum.Material.Metal, Parent = f })
			makePart({ Name = "BannerBracket", Size = Vector3.new(0.6, 0.24, 0.24), CFrame = pole * CFrame.new(-side * 0.45, 17.2, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = f })
			WallsBuilder.SpawnBanner(
				f,
				string.format("PilgrimsBanner_%d_%s", k + 1, if side < 0 then "L" else "R"),
				pole * CFrame.new(-side * 2.55, 17.2, 0),
				{ Scale = 1.15, DoubleSided = true, IncludeCrossbar = true }
			)
		end
	end

	-- South Gate: twin pylons + lintel framing the tower
	local gate = folder("SouthGate", model)
	local gz = hz - 1.5
	local half = HubLayout.SouthGateWidth * 0.5
	for _, side in { -1, 1 } do
		local base = root * CFrame.new(side * (half + 3), 0, gz)
		makePart({ Name = "GatePylon", Size = Vector3.new(6, 30, 6), CFrame = base * CFrame.new(0, 15, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = gate })
		for _, y in { 8, 16, 24 } do
			makePart({ Name = "PylonBand", Size = Vector3.new(6.4, 1.2, 6.4), CFrame = base * CFrame.new(0, y, 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = gate })
		end
		makePart({ Name = "PylonCap", Size = Vector3.new(8, 2, 8), CFrame = base * CFrame.new(0, 31, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		local g = base * CFrame.new(0, 32, 0)
		makePart({ Name = "GargoyleBody", Size = Vector3.new(2.6, 2.4, 3.4), CFrame = g * CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(-15), 0, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		makePart({ Name = "GargoyleHead", Size = Vector3.new(1.6, 1.6, 1.8), CFrame = g * CFrame.new(0, 2.7, -1.8), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		for _, ws in { -1, 1 } do
			makeWedge({ Name = "GargoyleWing", Size = Vector3.new(0.4, 3, 2.6), CFrame = g * CFrame.new(ws * 1.6, 3, 0.6) * CFrame.Angles(0, 0, ws * math.rad(25)), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		end
	end
	makePart({ Name = "GateLintel", Size = Vector3.new(HubLayout.SouthGateWidth + 12, 4, 4), CFrame = root * CFrame.new(0, 25, gz), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = gate })
	makePart({ Name = "LintelTrim", Size = Vector3.new(HubLayout.SouthGateWidth + 12.4, 0.8, 4.4), CFrame = root * CFrame.new(0, 23.2, gz), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = gate })
	local sign = makePart({ Name = "TowerSign", Size = Vector3.new(22, 4, 0.6), CFrame = root * CFrame.new(0, 20.4, gz), Color = SLATE, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0.2
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fondamento
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(235, 200, 160)
		label.Text = "THE INFINITE TOWER"
		label.Parent = gui
	end
end

--============================================================================
-- K. LANTERN ORCHARD (a square grove of blossom trees round a lantern walk)
--============================================================================
-- o: frame at the grove centre, its Z axis running along the lantern walk, X across it.
local function spawnOrchardLanterns(f: Instance, o: CFrame)
	for k, z in { -24, 24 } do
		for _, side in { -1, 1 } do
			local name = string.format("GothicLantern_Orchard_%d_%s", k, if side < 0 then "W" else "E")
			if f:FindFirstChild(name) then
				continue
			end
			local p = o * CFrame.new(side * 12, 0, z)
			local baseCF = CFrame.lookAt(p.Position, (o * CFrame.new(0, 0, z)).Position)
			GothicLanternSpawner.Spawn(f, baseCF, name)
		end
	end
end

local function buildOrchard(model: Model, name: string, o: CFrame, rng: Random)
	local f = folder(name, model)
	local i = 0
	for _, x in { -32, 32 } do
		for _, z in { -22, 22 } do
			i += 1
			local t = o * CFrame.new(x + rng:NextNumber(-3, 3), 0, z + (if x > 0 then 11 else -11))
			local scale = rng:NextNumber(0.9, 1.15)
			makePart({ Name = "BlossomTrunk", Size = Vector3.new(1.6, 7 * scale, 1.6), CFrame = t * CFrame.new(0, 3.5 * scale, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
			local blossom = if i % 2 == 0 then Color3.fromRGB(255, 183, 197) else Color3.fromRGB(250, 240, 245)
			for j, b in { { 0, 8.5, 0, 9 }, { -2.4, 7.4, 1.2, 7 }, { 2.2, 7.6, -1.4, 6 } } do
				makePart({ Name = "BlossomCanopy_" .. j, Shape = Enum.PartType.Ball, Size = Vector3.one * b[4] * scale, CFrame = t * CFrame.new(b[1] * scale, b[2] * scale, b[3] * scale), Color = blossom, Material = Enum.Material.SmoothPlastic, Decorative = true, Parent = f })
			end
		end
	end
	spawnOrchardLanterns(f, o)
	for _, side in { -1, 1 } do
		bench("OrchardBench", o * CFrame.new(side * 16, 0, 0) * CFrame.Angles(0, side * math.pi * 0.5, 0), f)
	end
	local anchor = makePart({ Name = "FireflyAnchor", Size = Vector3.new(90, 1, 80), CFrame = o * CFrame.new(0, 3, 0), Transparency = 1, Decorative = true, Parent = f })
	local flies = Instance.new("ParticleEmitter")
	flies.Name = "Fireflies"
	flies.Color = ColorSequence.new(Color3.fromRGB(255, 240, 140))
	flies.LightEmission = 1
	flies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	flies.Lifetime = NumberRange.new(5, 7)
	flies.Rate = 4
	flies.Speed = NumberRange.new(0.5, 1.5)
	flies.SpreadAngle = Vector2.new(180, 180)
	flies.Shape = Enum.ParticleEmitterShape.Box
	flies.Parent = anchor
end

--============================================================================
-- P. GARDEN PROPS (trees, benches, lamps, flower beds)
--============================================================================
local OAK_LEAVES = { Color3.fromRGB(72, 128, 60), Color3.fromRGB(88, 142, 66), Color3.fromRGB(64, 116, 56) }
local PINE_NEEDLES = Color3.fromRGB(46, 92, 52)
local FLOWERS = { Color3.fromRGB(220, 90, 120), Color3.fromRGB(240, 210, 90), Color3.fromRGB(160, 120, 220), Color3.fromRGB(245, 245, 245) }

local function oakTree(parent: Instance, base: CFrame, rng: Random)
	local s = rng:NextNumber(0.9, 1.25)
	makePart({ Name = "OakTrunk", Size = Vector3.new(2.2, 9, 2.2) * s, CFrame = base * CFrame.new(0, 4.5 * s, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = parent })
	for j, b in { { 0, 11, 0, 12 }, { -3.2, 9.6, 1.6, 9 }, { 3, 9.8, -1.8, 8.5 }, { 0.6, 13.6, 0.4, 8 } } do
		makePart({ Name = "OakCanopy_" .. j, Shape = Enum.PartType.Ball, Size = Vector3.one * b[4] * s, CFrame = base * CFrame.new(b[1] * s, b[2] * s, b[3] * s), Color = OAK_LEAVES[(j % #OAK_LEAVES) + 1], Material = Enum.Material.Grass, Decorative = true, Parent = parent })
	end
end

local function pineTree(parent: Instance, base: CFrame, rng: Random)
	local s = rng:NextNumber(0.9, 1.3)
	makePart({ Name = "PineTrunk", Size = Vector3.new(1.6, 6, 1.6) * s, CFrame = base * CFrame.new(0, 3 * s, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = parent })
	for j, t in { { 5.5, 12 }, { 9, 9 }, { 12.2, 6 }, { 14.8, 3.2 } } do
		cylinderY("PineTier_" .. j, t[2] * 0.5 * s, 3 * s, (t[1] + 1.5) * s, base, PINE_NEEDLES, Enum.Material.Grass, true, parent)
	end
end

local function flowerBed(parent: Instance, base: CFrame, color: Color3)
	makePart({ Name = "BedKerb", Size = Vector3.new(14, 0.8, 7), CFrame = base * CFrame.new(0, 0.4, 0), Color = SLATE, Material = Enum.Material.Slate, Decorative = true, Parent = parent })
	makePart({ Name = "FlowerBed", Size = Vector3.new(12.6, 1.1, 5.6), CFrame = base * CFrame.new(0, 0.6, 0), Color = color, Material = Enum.Material.Grass, Decorative = true, Parent = parent })
	makePart({ Name = "BedShrub", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), CFrame = base * CFrame.new(0, 1.6, 0), Color = HEDGE, Material = Enum.Material.Grass, Decorative = true, Parent = parent })
end

-- Hub-local feature spots, {x, z, clearRadius}; the garden scatter keeps clear of them.
local FEATURES = {
	Dais = { 0, 0, 64 },
	Pool = { 0, -160, 58 },
	Gazebo = { -90, 165, 30 },
	Pavilion = { 90, 165, 50 },
	Overlook = { -150, 280, 52 },
	BiomeStones = { 150, 275, 30 },
	OrchardWest = { -192, -75, 54 },
	OrchardEast = { 192, -75, 54 },
}

local function gardenClearings(): { { number } }
	local list = {}
	for _, feature in FEATURES do
		table.insert(list, feature)
	end
	local portal = HubLayout.RaidPortal
	table.insert(list, { portal.X, portal.Z, portal.ClearRadius + 6 })
	local c = HubLayout.HubCentre
	for i = 1, HubLayout.PlotCount do
		local slot = HubLayout.PlotSlots[i]
		local land = HubLayout.HubLandingPoint(i)
		table.insert(list, { land.X - c.X - slot.DX * 14, land.Z - c.Z - slot.DZ * 14, 28 }) -- landing apron and banners
	end
	table.insert(list, { 0, HubLayout.HubHalfZ - 40, 50 }) -- South Gate braziers and banners
	return list
end

local function spawnGardenLanterns(f: Instance, root: CFrame, clearPoints: { { number } }?)
	local paths = gardenPaths()
	local clear = clearPoints or gardenClearings()
	local lamps = 0
	for i = 1, #paths - 1 do
		local p = paths[i]
		local dx, dz = p[3] - p[1], p[4] - p[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		local off = p[5] * 0.5 + 3
		for k = 1, math.floor((len - 24) / 48) do
			local side = if k % 2 == 0 then 1 else -1
			local along = 12 + k * 48
			local x, z = p[1] + ux * along - uz * off * side, p[2] + uz * along + ux * off * side
			if not nearAny(x, z, clear, 0) then
				lamps += 1
				local name = string.format("GothicLantern_Path_%d", lamps)
				if not f:FindFirstChild(name) then
					local pos = (root * CFrame.new(x, 0, z)).Position
					local baseCF = CFrame.lookAt(pos, pos + Vector3.new(uz * side, 0, -ux * side))
					GothicLanternSpawner.Spawn(f, baseCF, name)
				end
			end
		end
	end
end

-- Lamps down both sides of every path, then trees, flower beds and benches scattered over the open lawn
-- (kept off the paths, features, landings and the rim).
local function buildGarden(model: Model, root: CFrame, rng: Random)
	local f = folder("Garden", model)
	local paths = gardenPaths()
	local clear = gardenClearings()
	spawnGardenLanterns(f, root, clear)

	local hx, hz, r = HubLayout.HubHalfX, HubLayout.HubHalfZ, HubLayout.OuterCornerRadius
	local inset, step = 22, 38
	local placed = 0
	for gx = -hx + inset, hx - inset, step do
		for gz = -hz + inset, hz - inset, step do
			local x, z = gx + rng:NextNumber(-7, 7), gz + rng:NextNumber(-7, 7)
			local ox, oz = math.max(math.abs(x) - (hx - r), 0), math.max(math.abs(z) - (hz - r), 0)
			local insideRim = math.abs(x) < hx - inset and math.abs(z) < hz - inset and math.sqrt(ox * ox + oz * oz) < r - inset
			local onPath = false
			for _, p in paths do
				if segmentDistance(x, z, p) < p[5] * 0.5 + 9 then
					onPath = true
					break
				end
			end
			if insideRim and not onPath and not nearAny(x, z, clear, 6) then
				placed += 1
				local pos = (root * CFrame.new(x, 0, z)).Position
				local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				local roll = rng:NextNumber()
				if roll < 0.4 then
					oakTree(f, base, rng)
				elseif roll < 0.65 then
					pineTree(f, base, rng)
				elseif roll < 0.82 then
					flowerBed(f, base, FLOWERS[(placed % #FLOWERS) + 1])
				elseif roll < 0.92 then
					bench("GardenBench", CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z)), f)
				end
			end
		end
	end
end

-- Builds a feature into its own model, scales it up about its anchor, then hands its parts to `model`.
local function grand(model: Model, anchor: CFrame, scale: number, build: (Model, CFrame) -> ())
	local m = Instance.new("Model")
	build(m, anchor)
	m.WorldPivot = anchor
	m:ScaleTo(scale)
	for _, child in m:GetChildren() do
		child.Parent = model
	end
	m:Destroy()
end

--============================================================================
-- I. WAYFINDER DAIS
--============================================================================
local function buildDais(model: Model, root: CFrame, cfg: typeof(CloisterBuilder.Config))
	local f = folder("WayfinderDais", model)
	cylinderY("Plaza", cfg.PlazaRadius, 0.3, 0.3, root, MARBLE, Enum.Material.Marble, true, f)
	cylinderY("PlazaCurb", cfg.PlazaRadius + 1.2, 0.26, 0.26, root, SLATE, Enum.Material.Slate, true, f)

	-- Compass rose: 4 crimson strips through the centre
	for i = 0, 3 do
		makePart({ Name = "CompassStrip", Size = Vector3.new(1.6, 0.06, cfg.PlazaRadius * 2 - 4), CFrame = root * CFrame.new(0, 0.32 + i * 0.015, 0) * CFrame.Angles(0, math.rad(i * 45), 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = f })
	end
	-- Cyan arrows down each plot's path
	for index = 1, HubLayout.PlotCount do
		local delta = HubLayout.HubLandingPoint(index) - root.Position
		local deg = math.deg(math.atan2(delta.X, -delta.Z))
		local x0, z0 = polar(deg, 20)
		local x1, z1 = polar(deg, 31)
		local shaft = flatStrip("WayArrow_" .. index, root, x0, z0, x1, z1, 1.5, 0.34, 0.06, CYAN, Enum.Material.Neon, f)
		shaft.Transparency = 0.3
		local head = makeWedge({ Name = "WayArrowHead_" .. index, Size = Vector3.new(0.06, 4, 3), CFrame = facingCentre(root, deg, 32.5, 0.34) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color = CYAN, Material = Enum.Material.Neon, Decorative = true, Parent = f })
		head.Transparency = 0.3
	end

	-- Three 1-stud dais tiers and the statue plinth
	cylinderY("DaisTier1", 18, 1, 1.3, root, SLATE, Enum.Material.Slate, false, f)
	cylinderY("DaisTier2", 14, 1, 2.3, root, MARBLE, Enum.Material.Marble, false, f)
	cylinderY("DaisTier3", 10, 1, 3.3, root, SLATE, Enum.Material.Slate, false, f)
	makePart({ Name = "StatuePlinth", Size = Vector3.new(6, 4, 6), CFrame = root * CFrame.new(0, 5.3, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })

	-- Statue of the First Master, facing the tower (+Z), sword raised toward it
	local statue = Instance.new("Model")
	statue.Name = "StatueOfTheFirstMaster"
	statue.Parent = f
	local s = root * CFrame.new(0, 7.3, 0) * CFrame.Angles(0, math.pi, 0) -- -Z of s points south
	local function sp(name: string, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?)
		makePart({ Name = name, Size = size, CFrame = s * cf, Color = color or STATUE, Material = material or Enum.Material.Marble, Decorative = true, Parent = statue })
	end
	for _, side in { -1, 1 } do
		sp("Leg", Vector3.new(1.4, 5, 1.6), CFrame.new(side * 0.9, 2.5, 0))
	end
	sp("Torso", Vector3.new(3.6, 4.5, 2), CFrame.new(0, 7.25, 0))
	sp("Belt", Vector3.new(3.8, 0.6, 2.2), CFrame.new(0, 5.3, 0), Color3.fromRGB(190, 186, 176))
	sp("Head", Vector3.new(2, 2.2, 2), CFrame.new(0, 10.6, 0))
	sp("Hood", Vector3.new(2.6, 2.4, 2.4), CFrame.new(0, 10.9, 0.3), Color3.fromRGB(205, 200, 190))
	makeWedge({ Name = "CloakL", Size = Vector3.new(2.4, 9, 2.6), CFrame = s * CFrame.new(-1.2, 4.6, 1.9) * CFrame.Angles(0, math.pi, 0), Color = STATUE, Material = Enum.Material.Marble, Decorative = true, Parent = statue })
	makeWedge({ Name = "CloakR", Size = Vector3.new(2.4, 9, 2.6), CFrame = s * CFrame.new(1.2, 4.6, 1.9) * CFrame.Angles(0, math.pi, 0), Color = STATUE, Material = Enum.Material.Marble, Decorative = true, Parent = statue })
	sp("ArmLeft", Vector3.new(1, 4.2, 1), CFrame.new(-2.3, 7, 0) * CFrame.Angles(0, 0, math.rad(-6)))
	local shoulder = CFrame.new(2.3, 9, 0) * CFrame.Angles(math.rad(-60), 0, 0) -- raised forward toward the tower
	sp("ArmRight", Vector3.new(1, 4.4, 1), shoulder * CFrame.new(0, 2.2, 0))
	sp("SwordGrip", Vector3.new(0.5, 1.6, 0.5), shoulder * CFrame.new(0, 4.6, 0), IRON, Enum.Material.Metal)
	sp("SwordGuard", Vector3.new(2.4, 0.4, 0.6), shoulder * CFrame.new(0, 5.5, 0), IRON, Enum.Material.Metal)
	sp("SwordBlade", Vector3.new(0.5, 8, 0.15), shoulder * CFrame.new(0, 9.7, 0), Color3.fromRGB(255, 70, 80), Enum.Material.Neon)

	-- Wayfinder Crystal floating above the statue
	local crystal = makePart({
		Name = "WayfinderCrystal",
		Size = Vector3.new(4, 4, 4),
		CFrame = root * CFrame.new(0, 27, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)),
		Color = CYAN,
		Material = Enum.Material.Neon,
		Decorative = true,
		Parent = f,
	})
	crystal.Transparency = 0.1
	crystal:SetAttribute("BaseY", crystal.Position.Y)
	CollectionService:AddTag(crystal, "CommonsSpinner")
	light(crystal, CYAN, 24, 2)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "CrystalSparkle"
	sparkle.Color = ColorSequence.new(CYAN)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 6
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = crystal

	-- Five squad plinths with hero silhouettes
	for k = 0, 4 do
		local deg = 36 + k * 72
		local x, z = polar(deg, 26)
		local base = CFrame.lookAt((root * CFrame.new(x, 0, z)).Position, (root * CFrame.new(0, 0, 0)).Position)
		cylinderY("SquadPlinth", 1.6, 2, 2.3, base, SLATE, Enum.Material.Slate, false, f)
		makePart({ Name = "SquadSilhouetteLegs", Size = Vector3.new(0.9, 1.2, 0.5), CFrame = base * CFrame.new(0, 2.9, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
		makePart({ Name = "SquadSilhouetteBody", Size = Vector3.new(1.1, 1.4, 0.6), CFrame = base * CFrame.new(0, 4.2, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
		makePart({ Name = "SquadSilhouetteHead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = base * CFrame.new(0, 5.35, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
	end

	for _, deg in { 48, -48, 150, -150 } do
		bench("PlazaBench", facingCentre(root, deg, 32, 0.3), f)
	end
end

--============================================================================
-- J. REFLECTING POOL (north wedge)
--============================================================================
local function buildPool(model: Model, root: CFrame)
	local f = folder("ReflectingPool", model)
	local pc = root
	local poolR = 26 -- keeps the coping clear of the ±24° path hedges
	cylinderY("PoolFloor", poolR, 0.2, 0.18, pc, Color3.fromRGB(25, 40, 50), Enum.Material.Slate, true, f)
	local water = cylinderY("PoolWater", poolR, 0.4, 0.4, pc, Color3.fromRGB(60, 110, 140), Enum.Material.Glass, false, f)
	water.Transparency = 0.15
	for i = 0, 31 do
		local a = math.rad(i * 11.25)
		local len = 2 * (poolR + 1) * math.tan(math.rad(5.625)) + 0.3
		local pos = pc * CFrame.new(math.sin(a) * (poolR + 1), 0.6, -math.cos(a) * (poolR + 1))
		makePart({ Name = "Coping", Size = Vector3.new(len, 1.2 + (i % 2) * 0.04, 2), CFrame = CFrame.lookAt(pos.Position, (pc * CFrame.new(0, 0.6, 0)).Position), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	end
	-- Stepping stones east-west (the footbridge carries the centre)
	for _, x in { -19, -13, -7, 7, 13, 19 } do
		cylinderY("SteppingStone", 2, 1, 1.0, pc * CFrame.new(x, 0, 0), Color3.fromRGB(120, 116, 110), Enum.Material.Slate, false, f)
	end
	-- Arched footbridge north-south: 4.3° ramps up to a 1.8-high deck
	local deckY = 1.8
	makePart({ Name = "FootbridgeDeck", Size = Vector3.new(6, 0.6, 24), CFrame = pc * CFrame.new(0, deckY - 0.3, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	for _, dir in { -1, 1 } do
		local run = 24
		local ang = math.atan(deckY / run)
		makePart({
			Name = "FootbridgeRamp",
			Size = Vector3.new(6, 0.6, math.sqrt(run * run + deckY * deckY)),
			CFrame = pc * CFrame.new(0, deckY * 0.5 - 0.3, dir * (12 + run * 0.5)) * CFrame.Angles(dir * ang, 0, 0),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
			Parent = f,
		})
	end
	for _, side in { -1, 1 } do
		makePart({ Name = "FootbridgeRail", Size = Vector3.new(0.4, 2.4, 24), CFrame = pc * CFrame.new(side * 2.8, deckY + 1.2, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	-- Lily pads in a crescent on the north side
	for i = 0, 5 do
		local a = math.rad(-70 + i * 28)
		cylinderY("LilyPad", 1.5, 0.08, 0.46, pc * CFrame.new(math.sin(a) * 17, 0, -math.cos(a) * 17), Color3.fromRGB(70, 140, 70), Enum.Material.Grass, true, f)
	end
	-- Weeping willows on the north bank
	for _, side in { -1, 1 } do
		local w = pc * CFrame.new(side * 18, 0, -34)
		makePart({ Name = "WillowTrunk", Size = Vector3.new(2.2, 11, 2.2), CFrame = w * CFrame.new(0, 5.5, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
		for j, ball in { { 0, 12, 0, 13 }, { -3, 10.5, 2, 9 }, { 3, 10.5, -2, 9 } } do
			makePart({ Name = "WillowCanopy_" .. j, Shape = Enum.PartType.Ball, Size = Vector3.new(ball[4], ball[4], ball[4]), CFrame = w * CFrame.new(ball[1], ball[2], ball[3]), Color = Color3.fromRGB(110, 150, 70), Material = Enum.Material.Grass, Decorative = true, Parent = f })
		end
		for k = 0, 5 do
			local a = math.rad(k * 60)
			makePart({ Name = "WillowFrond", Size = Vector3.new(1.2, 7, 1.2), CFrame = w * CFrame.new(math.cos(a) * 5.5, 7, math.sin(a) * 5.5), Color = Color3.fromRGB(96, 136, 62), Material = Enum.Material.Grass, Decorative = true, Parent = f })
		end
	end
	-- Fountain jet in the middle of the pool
	local jet = makePart({ Name = "FountainJet", Size = Vector3.new(1, 0.2, 1), CFrame = pc * CFrame.new(9, 0.5, 10), Transparency = 1, Decorative = true, Parent = f })
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Size = NumberSequence.new(0.6, 0.2)
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Rate = 30
	spray.Speed = NumberRange.new(10, 13)
	spray.SpreadAngle = Vector2.new(6, 6)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = jet
end

--============================================================================
-- L. LEADERBOARD PAVILION (east wedge)
--============================================================================
-- Open colonnade with a centre wall: the Playtime board faces the dais, the Power board faces the Loop.
local function buildPavilion(model: Model, root: CFrame)
	local f = folder("LeaderboardPavilion", model)
	local p = root
	local halfW, halfD = 22, 17
	makePart({ Name = "PavilionFloor", Size = Vector3.new(halfW * 2, 1, halfD * 2), CFrame = p * CFrame.new(0, 0.5, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	for _, x in { -halfW + 1, halfW - 1 } do
		for _, z in { -halfD + 1, halfD - 1 } do
			makePart({ Name = "Column", Size = Vector3.new(2, 14, 2), CFrame = p * CFrame.new(x, 8, z), Color = MARBLE, Material = Enum.Material.Marble, Parent = f })
		end
	end
	makePart({ Name = "CentreWall", Size = Vector3.new(halfW * 2 - 4, 14, 1.2), CFrame = p * CFrame.new(0, 8, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	makePart({ Name = "RoofTrim", Size = Vector3.new(halfW * 2 + 4.4, 0.6, halfD * 2 + 4.4), CFrame = p * CFrame.new(0, 15.3, 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = f })
	makePart({ Name = "Roof", Size = Vector3.new(halfW * 2 + 4, 1.5, halfD * 2 + 4), CFrame = p * CFrame.new(0, 16.35, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })
	for _, z in { -halfD - 1, halfD + 1 } do
		for i = 0, 5 do
			makePart({ Name = "RoofCrenel", Size = Vector3.new(3, 1.6, 2), CFrame = p * CFrame.new(-halfW + 2 + i * 8, 17.9, z), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
		end
	end
	-- Mount points for the shared world leaderboards: on the floor, LookVector toward the viewers
	makePart({ Name = "BoardSlot_Playtime", Size = Vector3.new(1, 1, 1), CFrame = p * CFrame.new(0, 1, -1.4), Transparency = 1, Decorative = true, Parent = f })
	makePart({ Name = "BoardSlot_Power", Size = Vector3.new(1, 1, 1), CFrame = p * CFrame.new(0, 1, 1.4) * CFrame.Angles(0, math.pi, 0), Transparency = 1, Decorative = true, Parent = f })
	for _, z in { -10, 10 } do
		local lamp = makePart({ Name = "PavilionLamp", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = p * CFrame.new(0, 14.4, z), Color = LANTERN, Material = Enum.Material.Neon, Decorative = true, Parent = f })
		light(lamp, LANTERN, 18, 1.1)
	end
end

--============================================================================
-- M. GAZEBO & BANDSTAND (west wedge)
--============================================================================
local function buildGazebo(model: Model, root: CFrame)
	local f = folder("Gazebo", model)
	local g = root
	cylinderY("GazeboFloor", 13, 1, 1, g, SLATE, Enum.Material.Slate, false, f)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		makePart({ Name = "GazeboPost", Size = Vector3.new(1, 10, 1), CFrame = g * CFrame.new(math.sin(a) * 12, 6, -math.cos(a) * 12), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	for i, tier in { { 15, 11 }, { 10, 12.5 }, { 5, 14 } } do
		cylinderY("GazeboRoof_" .. i, tier[1], 1.5, tier[2] + 0.75, g, if i == 2 then CRIMSON else SLATE_DARK, Enum.Material.Slate, true, f)
	end
	local finial = makePart({ Name = "GazeboFinial", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = g * CFrame.new(0, 15.6, 0), Color = LANTERN, Material = Enum.Material.Neon, Decorative = true, Parent = f })
	light(finial, LANTERN, 20, 1)
	-- Ring bench, open toward the park centre (-Z of g)
	for i = 1, 7 do
		local a = math.rad(i * 45)
		local pos = g * CFrame.new(math.sin(a) * 9, 1, -math.cos(a) * 9)
		bench("GazeboBench", CFrame.lookAt(pos.Position, (g * CFrame.new(0, 1, 0)).Position), f)
	end
end

--============================================================================
-- N. BIOME STONES (south-west wedge)
--============================================================================
local function buildBiomeStones(model: Model, root: CFrame)
	local f = folder("BiomeStones", model)
	local c = root
	makePart({ Name = "StoneAltar", Size = Vector3.new(6, 1.5, 4), CFrame = c * CFrame.new(0, 0.75, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	for i, color in BIOME_COLORS do
		local a = math.rad((i - 1) * 36)
		local h = 8 + ((i * 7) % 5)
		local pos = c * CFrame.new(math.sin(a) * 20, h * 0.5, -math.cos(a) * 20)
		local face = CFrame.lookAt(pos.Position, (c * CFrame.new(0, h * 0.5, 0)).Position)
		local stone = makePart({ Name = string.format("Menhir_%02d", i), Size = Vector3.new(3, h, 2), CFrame = face * CFrame.Angles(0, 0, math.rad(((i % 3) - 1) * 3)), Color = SLATE_DARK:Lerp(color, 0.45), Material = Enum.Material.Slate, Parent = f })
		stone:SetAttribute("BiomeIndex", i)
		local rune = makePart({ Name = "Rune", Size = Vector3.new(0.4, h * 0.55, 0.2), CFrame = face * CFrame.new(0, 0.5, -1.05), Color = color, Material = Enum.Material.Neon, Decorative = true, Parent = stone })
		rune.Transparency = 0.4
	end
end

--============================================================================
-- O. OVERLOOK TERRACE (south-east wedge)
--============================================================================
local function buildOverlook(model: Model, root: CFrame)
	local f = folder("OverlookTerrace", model)
	local t = root -- -Z toward the hub, +Z toward the tower
	local h = 4
	makePart({ Name = "TerraceBlock", Size = Vector3.new(44, h, 30), CFrame = t * CFrame.new(0, h * 0.5, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	makePart({ Name = "TerraceTop", Size = Vector3.new(44, 0.2, 30), CFrame = t * CFrame.new(0, h + 0.1, 0), Color = COBBLE, Material = Enum.Material.Cobblestone, Decorative = true, Parent = f })
	-- 16-long ramps at both ends (14°, within the 15° slope rule)
	local run = 16
	local ang = math.atan(h / run)
	for _, side in { -1, 1 } do
		makePart({
			Name = "TerraceRamp",
			Size = Vector3.new(math.sqrt(run * run + h * h), 0.8, 8),
			CFrame = t * CFrame.new(side * (22 + run * 0.5), h * 0.5 - 0.4, 0) * CFrame.Angles(0, 0, -side * ang),
			Color = SLATE,
			Material = Enum.Material.Slate,
			Parent = f,
		})
		for _, zr in { { -15, -4 }, { 4, 15 } } do
			local len = zr[2] - zr[1]
			makePart({ Name = "Balustrade", Size = Vector3.new(1, 3.06, len), CFrame = t * CFrame.new(side * 21.5, h + 1.53, (zr[1] + zr[2]) * 0.5), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })
		end
		-- Heraldic crimson-and-gold banners at the outer corners
		local pole = t * CFrame.new(side * 20, h, 13.5)
		makePart({ Name = "BannerPole", Size = Vector3.new(0.8, 12, 0.8), CFrame = pole * CFrame.new(0, 6, 0), Color = IRON, Material = Enum.Material.Metal, Parent = f })
		makePart({ Name = "BannerBracket", Size = Vector3.new(0.55, 0.22, 0.22), CFrame = pole * CFrame.new(-side * 0.45, 11.4, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = f })
		WallsBuilder.SpawnBanner(
			f,
			"OverlookBanner_" .. (if side < 0 then "L" else "R"),
			pole * CFrame.new(-side * 2.3, 11.4, 0),
			{ Scale = 1.0, DoubleSided = true, IncludeCrossbar = true }
		)
	end
	makePart({ Name = "Balustrade", Size = Vector3.new(44, 3, 1), CFrame = t * CFrame.new(0, h + 1.5, 14.5), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })
	-- Brass telescopes aimed at the tower top
	local towerTop = Vector3.new(0, 300, 0)
	for _, x in { -10, 10 } do
		local base = t * CFrame.new(x, h, 11)
		makePart({ Name = "TelescopeStand", Size = Vector3.new(0.6, 3.4, 0.6), CFrame = base * CFrame.new(0, 1.7, 0), Color = IRON, Material = Enum.Material.Metal, Parent = f })
		local pivot = (base * CFrame.new(0, 3.6, 0)).Position
		makePart({ Name = "TelescopeTube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.9, 0.9), CFrame = CFrame.lookAt(pivot, towerTop) * CFrame.Angles(0, math.pi * 0.5, 0), Color = Color3.fromRGB(181, 140, 62), Material = Enum.Material.Metal, Decorative = true, Parent = f })
	end
	local benchPos = t * CFrame.new(0, h + 0.2, 4)
	bench("OverlookBench", CFrame.lookAt(benchPos.Position, (t * CFrame.new(0, h + 0.2, 40)).Position), f)
end

--============================================================================
-- BUILD
--============================================================================
function CloisterBuilder.Build(container: Instance): Model
	local cfg = CloisterBuilder.Config
	local rng = Random.new(cfg.RandomSeed)
	local old = container:FindFirstChild("MastersCommons")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "MastersCommons"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = CFrame.new(HubLayout.HubCentre)
	local function at(feature: { number }): CFrame
		local pos = (root * CFrame.new(feature[1], 0, feature[2])).Position
		return CFrame.lookAt(pos, pos - Vector3.zAxis) -- -Z faces north
	end

	model.PrimaryPart = buildGround(model, root, cfg, rng)
	buildEdges(model, root, cfg)
	buildLandings(model, root, cfg)
	buildGrandTerrace(model, root)

	-- The dais (and its statue) at the exact centre, the pool to the north, the gazebo and the leaderboard
	-- pavilion either side of the Pilgrim's Way. Each is scaled up about its anchor.
	grand(model, root, 1.5, function(m, anchor)
		buildDais(m, anchor, cfg)
	end)
	grand(model, root * CFrame.new(FEATURES.Pool[1], 0, FEATURES.Pool[2]), 1.3, buildPool)
	grand(model, at(FEATURES.Gazebo), 1.5, buildGazebo)
	-- Top Playtime faces the dais (north), Top Power faces the South Gate
	grand(model, at(FEATURES.Pavilion), CloisterBuilder.Config.PavilionScale, buildPavilion)

	-- South corners: the overlook facing the tower and the biome stones. Orchards on the west and east lawns.
	grand(model, at(FEATURES.Overlook), 1.2, buildOverlook)
	buildBiomeStones(model, at(FEATURES.BiomeStones))
	buildOrchard(model, "OrchardWest", at(FEATURES.OrchardWest), rng)
	buildOrchard(model, "OrchardEast", at(FEATURES.OrchardEast), rng)
	buildGarden(model, root, rng)

	model.Parent = container
	return model
end

-- Populates (or backfills after prefab import) every hub perimeter, garden pathway & orchard Gothic lantern.
function CloisterBuilder.SpawnHubLanterns(commons: Instance)
	GothicLanternSpawner.CleanupLegacyLamps(commons)
	local root = CFrame.new(HubLayout.HubCentre)
	local lamps = commons:FindFirstChild("LampPylons")
	if not lamps then
		lamps = folder("LampPylons", commons)
	end
	spawnRimLanterns(lamps, root)

	local garden = commons:FindFirstChild("Garden")
	if garden then
		spawnGardenLanterns(garden, root)
	end

	for _, orchardInfo in {
		{ Name = "OrchardWest", Feat = FEATURES.OrchardWest },
		{ Name = "OrchardEast", Feat = FEATURES.OrchardEast },
	} do
		local orchardFolder = commons:FindFirstChild(orchardInfo.Name)
		if orchardFolder then
			local pos = (root * CFrame.new(orchardInfo.Feat[1], 0, orchardInfo.Feat[2])).Position
			local o = CFrame.lookAt(pos, pos - Vector3.zAxis)
			spawnOrchardLanterns(orchardFolder, o)
		end
	end
end

return CloisterBuilder
