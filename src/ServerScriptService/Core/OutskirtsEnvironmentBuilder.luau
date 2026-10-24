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
	-- Main solid grass ground (260 studs wide x 140 studs deep)
	local ground = makePart(folder, "OutskirtsGrounds", V(260, 6, 140), origin * CFrame.new(0, -3, 160), Color3.fromRGB(72, 115, 54), Enum.Material.Grass, true)
	ground.CanTouch = true
	ground.CanQuery = true

	-- Subtle organic tone patches for natural meadow variation
	local grassTones = {
		{ Pos = V(-65, 0.04, 130), Size = V(90, 0.08, 60), Color = Color3.fromRGB(64, 105, 48) },
		{ Pos = V(70, 0.04, 135), Size = V(85, 0.08, 55), Color = Color3.fromRGB(80, 126, 62) },
		{ Pos = V(-50, 0.04, 195), Size = V(110, 0.08, 50), Color = Color3.fromRGB(62, 100, 46) },
		{ Pos = V(55, 0.04, 190), Size = V(100, 0.08, 54), Color = Color3.fromRGB(76, 120, 58) },
		{ Pos = V(0, 0.04, 215), Size = V(140, 0.08, 30), Color = Color3.fromRGB(54, 90, 42) },
	}
	for i, patch in ipairs(grassTones) do
		makePart(folder, "MeadowTone_" .. i, patch.Size, origin * CFrame.new(patch.Pos), patch.Color, Enum.Material.Grass, false)
	end

	-- Cobblestone threshold apron right outside the rear fortress gatehouse (Z = 90 to 104)
	-- Smoothly transitions from citadel stone out into the wilderness
	local apron = makePart(folder, "GatehouseApron", V(38, 0.2, 16), origin * CFrame.new(0, 0.08, 97), Color3.fromRGB(85, 88, 94), Enum.Material.Slate, true)
	for x = -16, 16, 8 do
		makePart(folder, "ApronPaver", V(6.5, 0.22, 14), origin * CFrame.new(x, 0.1, 97), Color3.fromRGB(70, 72, 78), Enum.Material.Basalt, false)
	end
end

--============================================================================
-- 2. WINDING, CURVED DIRT PATROL PATHWAY
--============================================================================
function OutskirtsBuilder.BuildCurvedPath(folder: Instance, origin: CFrame)
	-- Curve function for the east-west patrol trail
	-- Snakes naturally across Z = 145 to Z = 175 between X = -118 and X = 118
	local function getPathZ(x: number): number
		return 160 + math.sin(x * 0.038) * 15 + math.cos(x * 0.082) * 5
	end

	local numSegments = 28
	local minX, maxX = -116, 116
	local step = (maxX - minX) / numSegments

	local dirtColor1 = Color3.fromRGB(124, 102, 76)
	local dirtColor2 = Color3.fromRGB(140, 118, 90)

	for i = 1, numSegments do
		local x1 = minX + (i - 1) * step
		local x2 = minX + i * step
		local z1 = getPathZ(x1)
		local z2 = getPathZ(x2)

		local midX = (x1 + x2) * 0.5
		local midZ = (z1 + z2) * 0.5
		local length = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2) + 2.5
		local angleY = math.atan2(z2 - z1, x2 - x1)

		local pathWidth = 16 + math.sin(i * 0.7) * 2.5
		local segColor = (i % 2 == 0) and dirtColor1 or dirtColor2

		-- Main dirt path slice
		local segCF = origin * CFrame.new(midX, 0.12, midZ) * CFrame.Angles(0, -angleY, 0)
		makePart(folder, "WildernessPatrolTrailSeg_" .. i, V(length, 0.22, pathWidth), segCF, segColor, Enum.Material.Sand, false)

		-- Soft grass-dirt blend fringe along the edges
		for _, side in {-1, 1} do
			local fringeZ = side * (pathWidth * 0.5 + 1.2)
			local fringeCF = segCF * CFrame.new(0, -0.04, fringeZ)
			makePart(folder, "TrailFringe", V(length * 0.9, 0.16, 2.8), fringeCF, Color3.fromRGB(95, 110, 65), Enum.Material.LeafyGrass, false)
		end

		-- Periodic embedded stone pavers along the trail
		if i % 2 == 1 then
			local paverOffset = math.sin(i * 1.3) * 4
			local paverCF = segCF * CFrame.new(0, 0.06, paverOffset) * CFrame.Angles(0, math.rad(i * 23), 0)
			makePart(folder, "TrailPaver", V(4.2, 0.18, 3.8), paverCF, Color3.fromRGB(105, 108, 114), Enum.Material.Slate, false)
		end
	end

	-- Connector path from Gatehouse Apron (Z = 104) curving gently into the main trail (Z = 150)
	local connectorSteps = 7
	for j = 1, connectorSteps do
		local t = j / connectorSteps
		local cz = 104 + (150 - 104) * t
		local cx = math.sin(t * math.pi) * 8 -- gentle S-curve to the side
		local width = 14 - t * 2
		makePart(folder, "GateConnectorPath_" .. j, V(width, 0.20, 8.5), origin * CFrame.new(cx, 0.12, cz), dirtColor1, Enum.Material.Sand, false)

		if j % 2 == 0 then
			makePart(folder, "ConnectorPaver", V(4.5, 0.18, 4.0), origin * CFrame.new(cx + math.sin(j) * 2, 0.16, cz), Color3.fromRGB(98, 100, 106), Enum.Material.Slate, false)
		end
	end
end

--============================================================================
-- 3. ASYMMETRICAL PROCEDURAL TREE BUILDERS
--============================================================================

-- Ancient Mountain Pine: Tapered conifer with leaning trunk, root flares, and multi-tier conical boughs
local function buildHighlandPine(folder: Instance, origin: CFrame, localPos: Vector3, scale: number, leanYaw: number)
	local barkColor = Color3.fromRGB(64, 46, 32)
	local pineNeedle1 = Color3.fromRGB(36, 68, 44)
	local pineNeedle2 = Color3.fromRGB(44, 80, 52)
	local pineNeedle3 = Color3.fromRGB(30, 58, 38)

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

	-- 3. Asymmetrical Trees (Natural groves, varied species, varying depths and heights)
	-- A. Deep Southern Forest Ridge (Z = 205 to 224) - Natural organic backdrop
	local backdropTrees = {
		{ Pos = V(-118, 0, 218), Scale = 1.35, Species = "PINE", Yaw = 14 },
		{ Pos = V(-96, 0, 212), Scale = 1.15, Species = "OAK", Yaw = 78 },
		{ Pos = V(-74, 0, 222), Scale = 1.40, Species = "PINE", Yaw = 45 },
		{ Pos = V(-48, 0, 208), Scale = 0.95, Species = "OAK", Yaw = 130 },
		{ Pos = V(-22, 0, 220), Scale = 1.30, Species = "PINE", Yaw = 88 },
		{ Pos = V(14, 0, 216), Scale = 1.25, Species = "PINE", Yaw = 32 },
		{ Pos = V(42, 0, 224), Scale = 1.45, Species = "OAK", Yaw = 165 },
		{ Pos = V(68, 0, 210), Scale = 1.05, Species = "PINE", Yaw = 112 },
		{ Pos = V(94, 0, 222), Scale = 1.38, Species = "PINE", Yaw = 56 },
		{ Pos = V(116, 0, 214), Scale = 1.20, Species = "OAK", Yaw = 205 },
	}

	-- B. Western Wilderness Copse (Dense clustering near the west cliff)
	local westernGrove = {
		{ Pos = V(-108, 0, 155), Scale = 1.20, Species = "OAK", Yaw = 40 },
		{ Pos = V(-92, 0, 135), Scale = 1.10, Species = "PINE", Yaw = 95 },
		{ Pos = V(-114, 0, 115), Scale = 0.90, Species = "PINE", Yaw = 160 },
	}

	-- C. Eastern Frontier Woodlands (Framing the eastern frontier)
	local easternGrove = {
		{ Pos = V(102, 0, 160), Scale = 1.25, Species = "PINE", Yaw = 72 },
		{ Pos = V(88, 0, 130), Scale = 1.15, Species = "OAK", Yaw = 120 },
		{ Pos = V(112, 0, 110), Scale = 0.95, Species = "PINE", Yaw = 35 },
	}

	-- D. Standalone Landmark Trees framing the wilderness
	local landmarkTrees = {
		{ Pos = V(-38, 0, 126), Scale = 0.85, Species = "PINE", Yaw = 50 },
		{ Pos = V(48, 0, 128), Scale = 0.90, Species = "OAK", Yaw = 185 },
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
		{ Pos = V(-82, 0, 148), Scale = 1.1, Berries = true },
		{ Pos = V(-68, 0, 172), Scale = 0.9, Berries = false },
		{ Pos = V(-42, 0, 152), Scale = 1.2, Berries = true },
		{ Pos = V(-24, 0, 174), Scale = 1.0, Berries = false },
		{ Pos = V(22, 0, 172), Scale = 1.15, Berries = true },
		{ Pos = V(38, 0, 150), Scale = 0.85, Berries = false },
		{ Pos = V(64, 0, 175), Scale = 1.25, Berries = true },
		{ Pos = V(84, 0, 152), Scale = 1.0, Berries = false },

		-- Near Guard Post (X = 0, Z = 160)
		{ Pos = V(-14, 0, 164), Scale = 0.9, Berries = true },
		{ Pos = V(15, 0, 158), Scale = 0.95, Berries = false },
		{ Pos = V(-12, 0, 142), Scale = 0.8, Berries = false },

		-- Fortress Rear Wall Base (Z = 100 to 108)
		{ Pos = V(-78, 0, 105), Scale = 1.05, Berries = false },
		{ Pos = V(-45, 0, 106), Scale = 0.95, Berries = true },
		{ Pos = V(42, 0, 106), Scale = 1.0, Berries = false },
		{ Pos = V(75, 0, 105), Scale = 1.1, Berries = true },

		-- Woodland Undergrowth
		{ Pos = V(-102, 0, 204), Scale = 1.3, Berries = true },
		{ Pos = V(-62, 0, 214), Scale = 1.1, Berries = false },
		{ Pos = V(30, 0, 210), Scale = 1.2, Berries = true },
		{ Pos = V(82, 0, 202), Scale = 1.15, Berries = false },
	}

	for _, b in ipairs(bushes) do
		buildWildBush(folder, origin, b.Pos, b.Scale, b.Berries)
	end

	-- 5. Mossy Granite Boulders
	local boulders = {
		{ Pos = V(-88, 0, 168), Size = V(5.5, 3.2, 4.8), RotY = 32 },
		{ Pos = V(-55, 0, 142), Size = V(4.2, 2.6, 3.8), RotY = 75 },
		{ Pos = V(-18, 0, 180), Size = V(4.8, 2.8, 4.2), RotY = 15 },
		{ Pos = V(28, 0, 144), Size = V(5.0, 3.0, 4.5), RotY = 110 },
		{ Pos = V(72, 0, 168), Size = V(4.6, 2.7, 4.0), RotY = 48 },
		{ Pos = V(95, 0, 145), Size = V(6.0, 3.6, 5.2), RotY = 85 },
		{ Pos = V(-32, 0, 108), Size = V(4.0, 2.4, 3.5), RotY = 20 },
		{ Pos = V(58, 0, 108), Size = V(4.4, 2.5, 3.8), RotY = 140 },
	}

	for _, r in ipairs(boulders) do
		buildMossyBoulder(folder, origin, r.Pos, r.Size, r.RotY)
	end
end

return OutskirtsBuilder
