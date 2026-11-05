--!strict
-- ServerScriptService/Core/OutskirtsEnvironmentBuilder.luau
-- Builds lush, organic Southern Outskirts wilderness:
-- 1. Lush rolling grass meadow floor with subtle terrain tone variations
-- 2. Natural winding, curved dirt patrol trail connecting from rear gatehouse across the frontier
-- 3. High-detail asymmetrical pine and broadleaf tree models with organic roots and canopies
-- 4. Varied wild shrubs, berry bushes, flowering heath, and mossy granite boulders
local OutskirtsBuilder = {}

local V = Vector3.new

local function makePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, canCollide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Grass
	p.Anchored = true
	p.CanCollide = if canCollide ~= nil then canCollide else false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeCylinder(parent: Instance, name: string, radius: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, canCollide: boolean?): Part
	local p = makePart(parent, name, V(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, canCollide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function makeSphere(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, canCollide: boolean?): Part
	local p = makePart(parent, name, V(diameter, diameter, diameter), cf, color, material, canCollide)
	p.Shape = Enum.PartType.Ball
	return p
end

--============================================================================
-- 1. LUSH GRASS MEADOW FLOOR & TRANSITION APRON
--============================================================================
function OutskirtsBuilder.BuildTerrainFloor(folder: Instance, origin: CFrame)
	-- Main solid grass ground (160 studs wide x 100 studs deep, flush against dividing wall Z = 60)
	local ground = makePart(folder, "OutskirtsGrounds", V(160, 6, 100), origin * CFrame.new(0, -3, 110), Color3.fromRGB(72, 115, 54), Enum.Material.Grass, true)
	ground.CanTouch = true
	ground.CanQuery = true

	-- Subtle organic tone patches for natural meadow variation
	local grassTones = {
		{ Pos = V(-35, 0.04, 90), Size = V(55, 0.08, 40), Color = Color3.fromRGB(64, 105, 48) },
		{ Pos = V(35, 0.04, 95), Size = V(50, 0.08, 38), Color = Color3.fromRGB(80, 126, 62) },
		{ Pos = V(-25, 0.04, 130), Size = V(60, 0.08, 35), Color = Color3.fromRGB(62, 100, 46) },
		{ Pos = V(28, 0.04, 128), Size = V(55, 0.08, 36), Color = Color3.fromRGB(76, 120, 58) },
		{ Pos = V(0, 0.04, 145), Size = V(80, 0.08, 22), Color = Color3.fromRGB(54, 90, 42) },
	}
	for i, patch in ipairs(grassTones) do
		makePart(folder, "MeadowTone_" .. i, patch.Size, origin * CFrame.new(patch.Pos), patch.Color, Enum.Material.Grass, false)
	end

	-- Cobblestone threshold apron right outside the rear fortress gatehouse (X = 14, Z = 60 to 70)
	-- Smoothly transitions from citadel stone out into the wilderness
	local apron = makePart(folder, "GatehouseApron", V(26, 0.2, 12), origin * CFrame.new(14, 0.08, 65), Color3.fromRGB(76, 80, 88), Enum.Material.Slate, false)
	for x = -8, 8, 4 do
		makePart(folder, "ApronPaver", V(4.5, 0.22, 10), origin * CFrame.new(14 + x, 0.1, 65), Color3.fromRGB(64, 66, 72), Enum.Material.Basalt, false)
	end
end

--============================================================================
-- 2. WINDING, CURVED DIRT PATROL PATHWAY
--============================================================================
function OutskirtsBuilder.BuildCurvedPath(folder: Instance, origin: CFrame)
	-- Curve function for the east-west patrol trail
	-- Snakes naturally across Z = 102 to Z = 118 between X = -68 and X = 68
	local function getPathZ(x: number): number
		return 110 + math.sin(x * 0.055) * 8 + math.cos(x * 0.11) * 3
	end

	local numSegments = 20
	local minX, maxX = -68, 68
	local step = (maxX - minX) / numSegments

	local dirtColor1 = Color3.fromRGB(108, 86, 62)
	local dirtColor2 = Color3.fromRGB(122, 98, 72)

	for i = 1, numSegments do
		local x1 = minX + (i - 1) * step
		local x2 = minX + i * step
		local z1 = getPathZ(x1)
		local z2 = getPathZ(x2)

		local midX = (x1 + x2) * 0.5
		local midZ = (z1 + z2) * 0.5
		local length = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2) + 2.0
		local angleY = math.atan2(z2 - z1, x2 - x1)

		local pathWidth = 10 + math.sin(i * 0.7) * 1.5
		local segColor = (i % 2 == 0) and dirtColor1 or dirtColor2

		-- Main dirt path slice (Enum.Material.Ground per spec)
		local segCF = origin * CFrame.new(midX, 0.12, midZ) * CFrame.Angles(0, -angleY, 0)
		makePart(folder, "WildernessPatrolTrailSeg_" .. i, V(length, 0.22, pathWidth), segCF, segColor, Enum.Material.Ground, false)

		-- Soft grass-dirt blend fringe along the edges
		for _, side in {-1, 1} do
			local fringeZ = side * (pathWidth * 0.5 + 1.0)
			local fringeCF = segCF * CFrame.new(0, -0.04, fringeZ)
			makePart(folder, "TrailFringe", V(length * 0.9, 0.16, 2.2), fringeCF, Color3.fromRGB(68, 92, 52), Enum.Material.LeafyGrass, false)
		end

		-- Periodic embedded stone pavers along the trail
		if i % 2 == 1 then
			local paverOffset = math.sin(i * 1.3) * 2.5
			local paverCF = segCF * CFrame.new(0, 0.06, paverOffset) * CFrame.Angles(0, math.rad(i * 23), 0)
			makePart(folder, "TrailPaver", V(3.5, 0.18, 3.2), paverCF, Color3.fromRGB(88, 92, 98), Enum.Material.Slate, false)
		end
	end

	-- Connector path from Dividing Wall Gatehouse Apron (X = 14, Z = 67) curving gently to Guardpost & main trail (X = 12, Z = 112)
	local connectorSteps = 6
	for j = 1, connectorSteps do
		local t = j / connectorSteps
		local cz = 67 + (112 - 67) * t
		local cx = 14 + (12 - 14) * t + math.sin(t * math.pi) * 3
		local width = 9 - t * 1.0
		makePart(folder, "GateConnectorPath_" .. j, V(width, 0.20, 8.0), origin * CFrame.new(cx, 0.12, cz), dirtColor1, Enum.Material.Ground, false)

		if j % 2 == 0 then
			makePart(folder, "ConnectorPaver", V(3.8, 0.18, 3.5), origin * CFrame.new(cx + math.sin(j) * 1.5, 0.16, cz), Color3.fromRGB(86, 90, 96), Enum.Material.Slate, false)
		end
	end
end

--============================================================================
-- 3. ASYMMETRICAL PROCEDURAL TREE BUILDERS (25-30 Layered Conical Pines)
--============================================================================

-- Ancient Mountain Pine: Tapered conifer with leaning trunk, root flares, and multi-tier conical boughs
local function buildHighlandPine(folder: Instance, origin: CFrame, localPos: Vector3, scale: number, leanYaw: number)
	local barkColor = Color3.fromRGB(58, 42, 28)
	local pineNeedle1 = Color3.fromRGB(45, 75, 42)
	local pineNeedle2 = Color3.fromRGB(52, 84, 48)
	local pineNeedle3 = Color3.fromRGB(36, 62, 34)

	local trunkH = 18 * scale
	local trunkR = 1.35 * scale

	-- Root flares hugging the grass
	for r = 0, 3 do
		local rAngle = math.rad(r * 90 + leanYaw)
		local rootCF = origin * CFrame.new(localPos + V(math.cos(rAngle) * trunkR * 1.6, 0.6 * scale, math.sin(rAngle) * trunkR * 1.6))
			* CFrame.Angles(0, rAngle, math.rad(28))
		makeCylinder(folder, "PineRoot", trunkR * 0.7, 3.2 * scale, rootCF, barkColor, Enum.Material.Wood, false)
	end

	-- Leaning trunk in 2 segments for natural organic posture
	local leanPitch = math.rad(3.5)
	local lowerTrunkCF = origin * CFrame.new(localPos + V(0, trunkH * 0.28, 0)) * CFrame.Angles(0, math.rad(leanYaw), leanPitch)
	makeCylinder(folder, "PineTrunkLower", trunkR, trunkH * 0.58, lowerTrunkCF, barkColor, Enum.Material.Wood, true)

	local upperTrunkCF = lowerTrunkCF * CFrame.new(0, trunkH * 0.45, 0) * CFrame.Angles(0, math.rad(12), math.rad(-2.0))
	makeCylinder(folder, "PineTrunkUpper", trunkR * 0.75, trunkH * 0.50, upperTrunkCF, barkColor, Enum.Material.Wood, true)

	-- 5 Asymmetric foliage tiers tapering upward
	local tiers = {
		{ Y = trunkH * 0.42, Radius = 8.5 * scale, Height = 4.2 * scale, Color = pineNeedle1 },
		{ Y = trunkH * 0.60, Radius = 7.0 * scale, Height = 3.8 * scale, Color = pineNeedle2 },
		{ Y = trunkH * 0.76, Radius = 5.4 * scale, Height = 3.4 * scale, Color = pineNeedle1 },
		{ Y = trunkH * 0.90, Radius = 3.8 * scale, Height = 3.0 * scale, Color = pineNeedle3 },
		{ Y = trunkH * 1.02, Radius = 2.0 * scale, Height = 3.2 * scale, Color = pineNeedle2 },
	}

	for idx, tier in ipairs(tiers) do
		local tierCF = origin * CFrame.new(localPos + V(math.sin(idx * 1.7) * 0.8 * scale, tier.Y, math.cos(idx * 2.1) * 0.8 * scale))
			* CFrame.Angles(0, math.rad(leanYaw + idx * 37), 0)

		-- Main conifer disk
		makeCylinder(folder, "PineBoughDisk_" .. idx, tier.Radius, tier.Height, tierCF, tier.Color, Enum.Material.Grass, false)

		-- Staggered perimeter branchlet tufts for organic silhouette
		for b = 0, 5 do
			local bAngle = math.rad(b * 60 + idx * 25)
			local bDist = tier.Radius * 0.82
			local tuftCF = tierCF * CFrame.new(math.cos(bAngle) * bDist, -tier.Height * 0.15, math.sin(bAngle) * bDist)
			makeSphere(folder, "PineTuft", tier.Radius * 0.45, tuftCF, tier.Color, Enum.Material.Grass, false)
		end
	end

	-- Apex pine cone finial
	local apexCF = origin * CFrame.new(localPos + V(0, trunkH * 1.12, 0))
	makeSphere(folder, "PineApex", 2.2 * scale, apexCF, pineNeedle3, Enum.Material.Grass, false)
end

-- Broadleaf Wilderness Oak: Sprawling canopy with gnarled branching limbs and multi-cluster foliage clouds
local function buildWildernessOak(folder: Instance, origin: CFrame, localPos: Vector3, scale: number, rotationYaw: number)
	local woodColor = Color3.fromRGB(72, 52, 36)
	local leafColor1 = Color3.fromRGB(60, 104, 52)
	local leafColor2 = Color3.fromRGB(74, 122, 62)
	local leafColor3 = Color3.fromRGB(50, 90, 44)

	local trunkH = 14 * scale
	local trunkR = 1.6 * scale

	-- Central heavy trunk
	local trunkCF = origin * CFrame.new(localPos + V(0, trunkH * 0.45, 0)) * CFrame.Angles(0, math.rad(rotationYaw), math.rad(4.0))
	makeCylinder(folder, "OakTrunk", trunkR, trunkH * 0.9, trunkCF, woodColor, Enum.Material.Wood, true)

	-- 3 Asymmetric spreading limbs
	local limbs = {
		{ Angle = math.rad(rotationYaw + 20), Pitch = math.rad(38), Length = 8.5 * scale, HeightOffset = trunkH * 0.65 },
		{ Angle = math.rad(rotationYaw + 140), Pitch = math.rad(42), Length = 7.8 * scale, HeightOffset = trunkH * 0.72 },
		{ Angle = math.rad(rotationYaw + 265), Pitch = math.rad(35), Length = 9.2 * scale, HeightOffset = trunkH * 0.60 },
	}

	for lIdx, limb in ipairs(limbs) do
		local limbMid = localPos + V(
			math.cos(limb.Angle) * limb.Length * 0.45,
			limb.HeightOffset + math.sin(limb.Pitch) * limb.Length * 0.4,
			math.sin(limb.Angle) * limb.Length * 0.45
		)
		local limbCF = origin * CFrame.new(limbMid) * CFrame.Angles(0, limb.Angle, limb.Pitch)
		makeCylinder(folder, "OakLimb_" .. lIdx, trunkR * 0.6, limb.Length, limbCF, woodColor, Enum.Material.Wood, false)
	end

	-- 7 Organic foliage clusters forming an expansive, asymmetrical canopy
	local clusters = {
		{ Offset = V(0, trunkH * 1.05, 0), Size = 13.5 * scale, Color = leafColor1 },
		{ Offset = V(5.5 * scale, trunkH * 0.92, 2.5 * scale), Size = 11.0 * scale, Color = leafColor2 },
		{ Offset = V(-5.0 * scale, trunkH * 0.96, -3.2 * scale), Size = 10.5 * scale, Color = leafColor3 },
		{ Offset = V(-2.8 * scale, trunkH * 0.88, 5.8 * scale), Size = 10.0 * scale, Color = leafColor1 },
		{ Offset = V(6.0 * scale, trunkH * 0.82, -4.5 * scale), Size = 9.2 * scale, Color = leafColor2 },
		{ Offset = V(-6.8 * scale, trunkH * 0.78, 1.5 * scale), Size = 9.5 * scale, Color = leafColor3 },
		{ Offset = V(1.5 * scale, trunkH * 1.18, -1.0 * scale), Size = 9.0 * scale, Color = leafColor2 },
	}

	for cIdx, cluster in ipairs(clusters) do
		local clusterCF = origin * CFrame.new(localPos + cluster.Offset)
		makeSphere(folder, "OakCanopyCluster_" .. cIdx, cluster.Size, clusterCF, cluster.Color, Enum.Material.Grass, false)
	end
end

--============================================================================
-- 4. WILD SHRUBS, BERRY BUSHES & MOSSY BOULDERS
--============================================================================

local function buildWildBush(folder: Instance, origin: CFrame, localPos: Vector3, scale: number, hasBerries: boolean)
	local bushColor = hasBerries and Color3.fromRGB(66, 112, 56) or Color3.fromRGB(78, 126, 64)

	-- 4 Overlapping organic spheres for lush bush form
	local spheres = {
		{ Offset = V(0, 1.2 * scale, 0), Size = 3.6 * scale },
		{ Offset = V(1.3 * scale, 0.9 * scale, 0.6 * scale), Size = 2.8 * scale },
		{ Offset = V(-1.2 * scale, 0.95 * scale, -0.5 * scale), Size = 2.9 * scale },
		{ Offset = V(0.3 * scale, 0.85 * scale, -1.2 * scale), Size = 2.7 * scale },
	}

	for sIdx, s in ipairs(spheres) do
		makeSphere(folder, "BushLobe", s.Size, origin * CFrame.new(localPos + s.Offset), bushColor, Enum.Material.Grass, false)
	end

	-- Decorative bright berries if enabled
	if hasBerries then
		local berryColor = Color3.fromRGB(220, 55, 45)
		local berryOffsets = {
			V(1.2 * scale, 1.8 * scale, 0.8 * scale),
			V(-0.9 * scale, 1.6 * scale, 1.1 * scale),
			V(0.2 * scale, 2.0 * scale, -0.9 * scale),
			V(-1.3 * scale, 1.4 * scale, -0.6 * scale),
		}
		for bIdx, bo in ipairs(berryOffsets) do
			makeSphere(folder, "BushBerry", 0.55 * scale, origin * CFrame.new(localPos + bo), berryColor, Enum.Material.Neon, false)
		end
	end
end

local function buildMossyBoulder(folder: Instance, origin: CFrame, localPos: Vector3, size: Vector3, rotY: number)
	local rockCF = origin * CFrame.new(localPos + V(0, size.Y * 0.42, 0)) * CFrame.Angles(0, math.rad(rotY), math.rad(6))
	makePart(folder, "MossyBoulder", size, rockCF, Color3.fromRGB(92, 95, 102), Enum.Material.Slate, true)

	-- Moss cap on top of the boulder
	local mossCF = rockCF * CFrame.new(0, size.Y * 0.44, 0)
	makePart(folder, "BoulderMoss", V(size.X * 0.85, 0.22, size.Z * 0.85), mossCF, Color3.fromRGB(74, 118, 58), Enum.Material.Grass, false)
end

--============================================================================
-- 5. MASTER ORCHESTRATION: ASYMMETRICAL WILDERNESS SCENE
--============================================================================
function OutskirtsBuilder.Build(folder: Instance, origin: CFrame)
	-- 1. Lush grass ground & fortress gatehouse transition apron
	OutskirtsBuilder.BuildTerrainFloor(folder, origin)

	-- 2. Winding curved patrol path & connector
	OutskirtsBuilder.BuildCurvedPath(folder, origin)

	-- 3. Dense Layered Conical Pine Forest (28 Highland Conifers & Craggy Woods)
	-- A. Deep Forest Ridge (Z = 144 to 154)
	local backdropTrees = {
		{ Pos = V(-68, 0, 150), Scale = 1.30, Species = "PINE", Yaw = 14 },
		{ Pos = V(-52, 0, 146), Scale = 1.18, Species = "PINE", Yaw = 78 },
		{ Pos = V(-36, 0, 152), Scale = 1.35, Species = "PINE", Yaw = 45 },
		{ Pos = V(-20, 0, 145), Scale = 1.15, Species = "PINE", Yaw = 130 },
		{ Pos = V(-4, 0, 152), Scale = 1.32, Species = "PINE", Yaw = 62 },
		{ Pos = V(14, 0, 148), Scale = 1.25, Species = "PINE", Yaw = 32 },
		{ Pos = V(30, 0, 152), Scale = 1.36, Species = "PINE", Yaw = 165 },
		{ Pos = V(48, 0, 146), Scale = 1.18, Species = "PINE", Yaw = 95 },
		{ Pos = V(66, 0, 150), Scale = 1.32, Species = "PINE", Yaw = 112 },
	}

	-- B. South/West Wilderness Copse (Dense clustering framing the lower outskirts)
	local westernGrove = {
		{ Pos = V(-68, 0, 130), Scale = 1.22, Species = "PINE", Yaw = 40 },
		{ Pos = V(-58, 0, 120), Scale = 1.12, Species = "PINE", Yaw = 95 },
		{ Pos = V(-68, 0, 96), Scale = 1.18, Species = "PINE", Yaw = 160 },
		{ Pos = V(-56, 0, 80), Scale = 1.05, Species = "PINE", Yaw = 210 },
		{ Pos = V(-68, 0, 68), Scale = 0.98, Species = "PINE", Yaw = 55 },
	}

	-- C. North/East Frontier Woodlands (Framing the upper outskirts behind Market)
	local easternGrove = {
		{ Pos = V(68, 0, 130), Scale = 1.24, Species = "PINE", Yaw = 72 },
		{ Pos = V(58, 0, 120), Scale = 1.14, Species = "PINE", Yaw = 120 },
		{ Pos = V(68, 0, 96), Scale = 1.20, Species = "PINE", Yaw = 35 },
		{ Pos = V(56, 0, 80), Scale = 1.08, Species = "PINE", Yaw = 150 },
		{ Pos = V(68, 0, 68), Scale = 1.00, Species = "PINE", Yaw = 85 },
	}

	-- D. Standalone Landmark Pines framing the Campfire & Palisade Watch
	local landmarkTrees = {
		{ Pos = V(-24, 0, 96), Scale = 0.95, Species = "PINE", Yaw = 50 },
		{ Pos = V(36, 0, 96), Scale = 0.98, Species = "PINE", Yaw = 185 },
	}

	local allTrees = { backdropTrees, westernGrove, easternGrove, landmarkTrees }
	for _, group in ipairs(allTrees) do
		for _, t in ipairs(group) do
			if t.Species == "PINE" then
				buildHighlandPine(folder, origin, t.Pos, t.Scale, t.Yaw)
			else
				buildWildernessOak(folder, origin, t.Pos, t.Scale, t.Yaw)
			end
		end
	end

	-- 4. Wild Shrubs & Berry Bushes scattered naturally
	local bushes = {
		-- Pathside clusters (curved path ambiance)
		{ Pos = V(-48, 0, 108), Scale = 1.1, Berries = true },
		{ Pos = V(-38, 0, 120), Scale = 0.9, Berries = false },
		{ Pos = V(-22, 0, 106), Scale = 1.1, Berries = true },
		{ Pos = V(-12, 0, 122), Scale = 0.95, Berries = false },
		{ Pos = V(18, 0, 120), Scale = 1.1, Berries = true },
		{ Pos = V(28, 0, 108), Scale = 0.85, Berries = false },
		{ Pos = V(44, 0, 122), Scale = 1.15, Berries = true },

		-- Near Guard Post (X = 12, Z = 115)
		{ Pos = V(-4, 0, 118), Scale = 0.9, Berries = true },
		{ Pos = V(12, 0, 115), Scale = 0.95, Berries = false },
		{ Pos = V(-6, 0, 104), Scale = 0.8, Berries = false },

		-- Fortress Rear Wall Base (Z = 68 to 74)
		{ Pos = V(-46, 0, 72), Scale = 1.05, Berries = false },
		{ Pos = V(-26, 0, 73), Scale = 0.95, Berries = true },
		{ Pos = V(28, 0, 73), Scale = 1.0, Berries = false },
		{ Pos = V(48, 0, 72), Scale = 1.1, Berries = true },

		-- Woodland Undergrowth
		{ Pos = V(-58, 0, 142), Scale = 1.2, Berries = true },
		{ Pos = V(-36, 0, 146), Scale = 1.0, Berries = false },
		{ Pos = V(20, 0, 145), Scale = 1.1, Berries = true },
		{ Pos = V(52, 0, 142), Scale = 1.15, Berries = false },
	}

	for _, b in ipairs(bushes) do
		buildWildBush(folder, origin, b.Pos, b.Scale, b.Berries)
	end

	-- 5. Mossy Granite Boulders
	local boulders = {
		{ Pos = V(-52, 0, 118), Size = V(4.8, 2.8, 4.2), RotY = 32 },
		{ Pos = V(-32, 0, 102), Size = V(3.8, 2.4, 3.4), RotY = 75 },
		{ Pos = V(-10, 0, 126), Size = V(4.2, 2.5, 3.8), RotY = 15 },
		{ Pos = V(18, 0, 104), Size = V(4.5, 2.7, 4.0), RotY = 110 },
		{ Pos = V(46, 0, 118), Size = V(4.2, 2.5, 3.6), RotY = 48 },
		{ Pos = V(58, 0, 105), Size = V(5.0, 3.0, 4.5), RotY = 85 },
		{ Pos = V(-20, 0, 74), Size = V(3.6, 2.2, 3.2), RotY = 20 },
		{ Pos = V(38, 0, 74), Size = V(3.8, 2.3, 3.4), RotY = 140 },
	}

	for _, r in ipairs(boulders) do
		buildMossyBoulder(folder, origin, r.Pos, r.Size, r.RotY)
	end
end

return OutskirtsBuilder
