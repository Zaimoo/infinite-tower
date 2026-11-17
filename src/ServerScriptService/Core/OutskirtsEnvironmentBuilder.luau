--!strict
-- ServerScriptService/Core/OutskirtsEnvironmentBuilder.luau
-- Builds lush, organic Southern Outskirts wilderness:
-- 1. Lush rolling grass meadow floor with subtle terrain tone variations
-- 2. Natural winding, curved dirt patrol trail connecting from rear gatehouse across the frontier
-- 3. High-detail asymmetrical pine and broadleaf tree models with organic roots and canopies
-- 4. Varied wild shrubs, berry bushes, flowering heath, and mossy granite boulders
local OutskirtsBuilder = {}

local V = Vector3.new
local cachedEnvSpawner: any = false

local function getEnvSpawner(): any?
	if cachedEnvSpawner ~= false then
		return cachedEnvSpawner
	end
	local sss = script.Parent and script.Parent.Parent
	local baseOverhaul = sss and sss:FindFirstChild("BaseOverhaul")
	local mod = baseOverhaul and baseOverhaul:FindFirstChild("EnvironmentSpawner")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		cachedEnvSpawner = if ok then res else nil
	else
		cachedEnvSpawner = nil
	end
	return cachedEnvSpawner
end

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
	local ground = makePart(folder, "OutskirtsGrounds", V(160, 6, 100), origin * CFrame.new(0, -3, 110), Color3.fromRGB(64, 106, 56), Enum.Material.Grass, true)
	ground.CanTouch = true
	ground.CanQuery = true

	local envSpawner = getEnvSpawner()
	if envSpawner and (envSpawner.HasTemplate("Outskirts_Ground") or envSpawner.HasTemplate("Outskirts_Pathway")) then
		return
	end

	-- Procedural fallback ground tone patches & gatehouse apron when Blender assets aren't present
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

	makePart(folder, "GatehouseApron", V(26, 0.2, 12), origin * CFrame.new(14, 0.08, 65), Color3.fromRGB(76, 80, 88), Enum.Material.Slate, false)
	for x = -8, 8, 4 do
		makePart(folder, "ApronPaver", V(4.5, 0.22, 10), origin * CFrame.new(14 + x, 0.1, 65), Color3.fromRGB(64, 66, 72), Enum.Material.Basalt, false)
	end
end

--============================================================================
-- 2. WINDING, CURVED DIRT PATROL PATHWAY & STEPPING STONES
--============================================================================
function OutskirtsBuilder.BuildCurvedPath(folder: Instance, origin: CFrame)
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("Outskirts_Ground") then
		envSpawner.SpawnOutskirtsGround(folder, origin * CFrame.new(12, 0, 96))
		return
	elseif envSpawner and envSpawner.HasTemplate("Outskirts_Pathway") then
		envSpawner.SpawnOutskirtsPathway(folder, origin * CFrame.new(12, 0.02, 96))
		return
	end

	-- Procedural fallback pathway
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
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("HighlandPineTree") then
		local rng = Random.new(math.abs(math.round(localPos.X * 13 + localPos.Z * 31)) + 1)
		envSpawner.SpawnPine(folder, origin * CFrame.new(localPos) * CFrame.Angles(0, math.rad(leanYaw), 0), scale, rng)
		return
	end

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
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("HeroOakTree") then
		local rng = Random.new(math.abs(math.round(localPos.X * 17 + localPos.Z * 29)) + 7)
		envSpawner.SpawnOak(folder, origin * CFrame.new(localPos) * CFrame.Angles(0, math.rad(rotationYaw), 0), scale, rng)
		return
	end

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
-- 4. LUSH BUSHES, WOODLAND FERNS, GRASS TUFTS & MOSSY BOULDERS
--============================================================================

local function buildWildBush(folder: Instance, origin: CFrame, localPos: Vector3, scale: number, yawDeg: number?)
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("Outskirts_LushBush") then
		local rng = Random.new(math.abs(math.round(localPos.X * 23 + localPos.Z * 19)) + 13)
		local yaw = if yawDeg ~= nil then math.rad(yawDeg) else nil
		envSpawner.SpawnOutskirtsBush(folder, origin * CFrame.new(localPos), scale, yaw, rng)
		return
	elseif envSpawner and envSpawner.HasTemplate("WildForestShrub") then
		local rng = Random.new(math.abs(math.round(localPos.X * 23 + localPos.Z * 19)) + 13)
		envSpawner.SpawnShrub(folder, origin * CFrame.new(localPos), scale, rng)
		return
	end

	local bushColor = Color3.fromRGB(78, 126, 64)
	local spheres = {
		{ Offset = V(0, 1.2 * scale, 0), Size = 3.6 * scale },
		{ Offset = V(1.3 * scale, 0.9 * scale, 0.6 * scale), Size = 2.8 * scale },
		{ Offset = V(-1.2 * scale, 0.95 * scale, -0.5 * scale), Size = 2.9 * scale },
		{ Offset = V(0.3 * scale, 0.85 * scale, -1.2 * scale), Size = 2.7 * scale },
	}
	for _, s in ipairs(spheres) do
		makeSphere(folder, "BushLobe", s.Size, origin * CFrame.new(localPos + s.Offset), bushColor, Enum.Material.Grass, false)
	end
end

local function buildWoodlandFern(folder: Instance, origin: CFrame, localPos: Vector3, scale: number, yawDeg: number?)
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("Outskirts_WoodlandFern") then
		local rng = Random.new(math.abs(math.round(localPos.X * 31 + localPos.Z * 17)) + 29)
		local yaw = if yawDeg ~= nil then math.rad(yawDeg) else nil
		envSpawner.SpawnOutskirtsFern(folder, origin * CFrame.new(localPos), scale, yaw, rng)
	end
end

local function buildGrassTuft(folder: Instance, origin: CFrame, localPos: Vector3, scale: number, yawDeg: number?)
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("Outskirts_GrassTuft") then
		local rng = Random.new(math.abs(math.round(localPos.X * 41 + localPos.Z * 37)) + 7)
		local yaw = if yawDeg ~= nil then math.rad(yawDeg) else nil
		envSpawner.SpawnOutskirtsGrassTuft(folder, origin * CFrame.new(localPos), scale, yaw, rng)
	end
end

local function buildMossyBoulder(folder: Instance, origin: CFrame, localPos: Vector3, sizeOrScale: Vector3 | number, rotY: number)
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("Outskirts_MossyBoulder") then
		local scale = if typeof(sizeOrScale) == "number" then sizeOrScale else (sizeOrScale.Y / 2.2)
		local rng = Random.new(math.abs(math.round(localPos.X * 19 + localPos.Z * 29)) + 5)
		envSpawner.SpawnOutskirtsBoulder(folder, origin * CFrame.new(localPos), scale, math.rad(rotY), rng)
		return
	end

	local size = if typeof(sizeOrScale) == "Vector3" then sizeOrScale else V(3.8, 2.2, 3.4) * sizeOrScale
	local rockCF = origin * CFrame.new(localPos + V(0, size.Y * 0.42, 0)) * CFrame.Angles(0, math.rad(rotY), math.rad(6))
	makePart(folder, "MossyBoulder", size, rockCF, Color3.fromRGB(92, 95, 102), Enum.Material.Slate, true)

	local mossCF = rockCF * CFrame.new(0, size.Y * 0.44, 0)
	makePart(folder, "BoulderMoss", V(size.X * 0.85, 0.22, size.Z * 0.85), mossCF, Color3.fromRGB(74, 118, 58), Enum.Material.Grass, false)
end

--============================================================================
-- 5. MASTER ORCHESTRATION: ASYMMETRICAL WILDERNESS SCENE
--============================================================================
function OutskirtsBuilder.Build(folder: Instance, origin: CFrame)
	-- 1. Lush grass ground & textured stepping-stone pathway
	OutskirtsBuilder.BuildTerrainFloor(folder, origin)
	OutskirtsBuilder.BuildCurvedPath(folder, origin)

	-- 2. Dense Layered Highland Pine Framing & Forest Perimeter
	-- Framing cluster matching reference composition (guardpost local +12, +96)
	local framingTrees = {
		{ Pos = V(-11, 0, 72), Scale = 1.00, Species = "PINE", Yaw = 25 },
		{ Pos = V(-24, 0, 80), Scale = 1.18, Species = "PINE", Yaw = 85 },
		{ Pos = V(-22, 0, 118), Scale = 1.15, Species = "PINE", Yaw = 140 },
		{ Pos = V(-26, 0, 128), Scale = 1.05, Species = "PINE", Yaw = 50 },
		{ Pos = V(40, 0, 69), Scale = 1.10, Species = "PINE", Yaw = 110 },
		{ Pos = V(48, 0, 76), Scale = 1.20, Species = "PINE", Yaw = 40 },
		{ Pos = V(39, 0, 89), Scale = 1.02, Species = "PINE", Yaw = 170 },
		{ Pos = V(50, 0, 86), Scale = 1.18, Species = "PINE", Yaw = 95 },
		{ Pos = V(37, 0, 106), Scale = 1.08, Species = "PINE", Yaw = 200 },
		{ Pos = V(48, 0, 116), Scale = 1.18, Species = "PINE", Yaw = 65 },
		{ Pos = V(40, 0, 128), Scale = 1.15, Species = "PINE", Yaw = 135 },
	}

	-- Deep Forest Ridge (Z = 144 to 154)
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

	-- Outer Western & Eastern Woodlands
	local westernGrove = {
		{ Pos = V(-68, 0, 130), Scale = 1.22, Species = "PINE", Yaw = 40 },
		{ Pos = V(-58, 0, 120), Scale = 1.12, Species = "PINE", Yaw = 95 },
		{ Pos = V(-68, 0, 96), Scale = 1.18, Species = "PINE", Yaw = 160 },
		{ Pos = V(-56, 0, 80), Scale = 1.05, Species = "PINE", Yaw = 210 },
		{ Pos = V(-68, 0, 68), Scale = 0.98, Species = "PINE", Yaw = 55 },
	}

	local easternGrove = {
		{ Pos = V(68, 0, 130), Scale = 1.24, Species = "PINE", Yaw = 72 },
		{ Pos = V(58, 0, 120), Scale = 1.14, Species = "PINE", Yaw = 120 },
		{ Pos = V(68, 0, 96), Scale = 1.20, Species = "PINE", Yaw = 35 },
		{ Pos = V(56, 0, 80), Scale = 1.08, Species = "PINE", Yaw = 150 },
		{ Pos = V(68, 0, 68), Scale = 1.00, Species = "PINE", Yaw = 85 },
	}

	local allTrees = { framingTrees, backdropTrees, westernGrove, easternGrove }
	for _, group in ipairs(allTrees) do
		for _, t in ipairs(group) do
			if t.Species == "PINE" then
				buildHighlandPine(folder, origin, t.Pos, t.Scale, t.Yaw)
			else
				buildWildernessOak(folder, origin, t.Pos, t.Scale, t.Yaw)
			end
		end
	end

	-- 3. Plump Lush Bushes (matching reference clusters + woodland borders)
	local bushes = {
		{ Pos = V(23.5, 0, 65.5), Scale = 1.00, Yaw = 35 },
		{ Pos = V(25.5, 0, 69.5), Scale = 0.85, Yaw = 120 },
		{ Pos = V(1.5, 0, 66.5), Scale = 0.95, Yaw = 70 },
		{ Pos = V(-6.5, 0, 100.5), Scale = 0.92, Yaw = 210 },
		{ Pos = V(1.5, 0, 101.2), Scale = 0.85, Yaw = 15 },
		{ Pos = V(-1.0, 0, 121.0), Scale = 1.00, Yaw = 95 },
		{ Pos = V(-6.0, 0, 126.5), Scale = 1.05, Yaw = 165 },
		{ Pos = V(23.5, 0, 106.5), Scale = 1.05, Yaw = 55 },
		-- Perimeter woodland bushes
		{ Pos = V(-46, 0, 72), Scale = 1.05, Yaw = 40 },
		{ Pos = V(-32, 0, 104), Scale = 1.00, Yaw = 140 },
		{ Pos = V(-48, 0, 122), Scale = 1.10, Yaw = 225 },
		{ Pos = V(48, 0, 102), Scale = 1.05, Yaw = 80 },
		{ Pos = V(54, 0, 134), Scale = 1.15, Yaw = 190 },
	}
	for _, b in ipairs(bushes) do
		buildWildBush(folder, origin, b.Pos, b.Scale, b.Yaw)
	end

	-- 4. Woodland Ferns nestled along gate walls, fence & pine roots
	local ferns = {
		{ Pos = V(-2.5, 0, 67.5), Scale = 1.00, Yaw = 40 },
		{ Pos = V(-1.5, 0, 101.5), Scale = 1.05, Yaw = 135 },
		{ Pos = V(34.0, 0, 99.5), Scale = 1.00, Yaw = 75 },
		{ Pos = V(38.0, 0, 79.0), Scale = 0.95, Yaw = 200 },
		{ Pos = V(-15.0, 0, 118.0), Scale = 1.00, Yaw = 30 },
		{ Pos = V(-34.0, 0, 72.0), Scale = 1.05, Yaw = 110 },
		{ Pos = V(46.0, 0, 108.0), Scale = 1.00, Yaw = 260 },
		{ Pos = V(-42.0, 0, 116.0), Scale = 1.10, Yaw = 15 },
	}
	for _, f in ipairs(ferns) do
		buildWoodlandFern(folder, origin, f.Pos, f.Scale, f.Yaw)
	end

	-- 5. Chiseled Mossy Boulders
	local boulders = {
		{ Pos = V(30.5, 0, 110.0), Scale = 1.35, RotY = 30 },
		{ Pos = V(44.5, 0, 81.0), Scale = 1.25, RotY = 115 },
		{ Pos = V(-48.0, 0, 118.0), Scale = 1.40, RotY = 45 },
		{ Pos = V(-32.0, 0, 72.0), Scale = 1.15, RotY = 160 },
		{ Pos = V(56.0, 0, 106.0), Scale = 1.30, RotY = 85 },
	}
	for _, r in ipairs(boulders) do
		buildMossyBoulder(folder, origin, r.Pos, r.Scale, r.RotY)
	end

	-- 6. Dense Forest Grass Tufts hugging fence posts, trail borders, stones & bushes
	local grassTufts = {
		-- Around gatehouse & patio edges
		{ Pos = V(-4.0, 0, 68.5), Scale = 1.25, Yaw = 20 },
		{ Pos = V(7.0, 0, 69.5), Scale = 1.15, Yaw = 85 },
		{ Pos = V(20.5, 0, 69.0), Scale = 1.20, Yaw = 140 },
		{ Pos = V(24.5, 0, 72.0), Scale = 1.15, Yaw = 45 },
		-- Hugging outer split-rail fence base along the dirt trail border
		{ Pos = V(-21.8, 0, 97.6), Scale = 1.35, Yaw = 35 },
		{ Pos = V(-19.2, 0, 98.1), Scale = 1.25, Yaw = 110 },
		{ Pos = V(-16.0, 0, 99.2), Scale = 1.30, Yaw = 195 },
		{ Pos = V(-12.0, 0, 101.0), Scale = 1.40, Yaw = 60 },
		{ Pos = V(-9.2, 0, 102.6), Scale = 1.30, Yaw = 240 },
		{ Pos = V(-6.5, 0, 104.1), Scale = 1.35, Yaw = 15 },
		{ Pos = V(-3.8, 0, 105.7), Scale = 1.25, Yaw = 90 },
		{ Pos = V(-1.2, 0, 106.4), Scale = 1.35, Yaw = 160 },
		{ Pos = V(2.2, 0, 108.6), Scale = 1.30, Yaw = 215 },
		{ Pos = V(5.0, 0, 109.2), Scale = 1.40, Yaw = 75 },
		{ Pos = V(5.5, 0, 106.3), Scale = 1.25, Yaw = 310 },
		{ Pos = V(5.8, 0, 103.0), Scale = 1.30, Yaw = 140 },
		{ Pos = V(6.3, 0, 99.5), Scale = 1.35, Yaw = 45 },
		{ Pos = V(7.1, 0, 95.4), Scale = 1.20, Yaw = 200 },
		-- Inside campfire edge & connector trail border
		{ Pos = V(-6.5, 0, 82.0), Scale = 1.15, Yaw = 130 },
		{ Pos = V(6.5, 0, 77.0), Scale = 1.25, Yaw = 55 },
		{ Pos = V(19.0, 0, 76.5), Scale = 1.20, Yaw = 200 },
		{ Pos = V(20.5, 0, 92.5), Scale = 1.30, Yaw = 115 },
		{ Pos = V(17.5, 0, 97.0), Scale = 1.25, Yaw = 35 },
		{ Pos = V(7.5, 0, 92.0), Scale = 1.15, Yaw = 175 },
		{ Pos = V(19.5, 0, 103.5), Scale = 1.35, Yaw = 270 },
		-- Main foreground trail borders & meadow pockets
		{ Pos = V(-11.0, 0, 106.5), Scale = 1.30, Yaw = 210 },
		{ Pos = V(-17.5, 0, 105.0), Scale = 1.25, Yaw = 40 },
		{ Pos = V(-24.0, 0, 102.0), Scale = 1.35, Yaw = 120 },
		{ Pos = V(-32.0, 0, 99.0), Scale = 1.30, Yaw = 290 },
		{ Pos = V(-38.0, 0, 104.0), Scale = 1.40, Yaw = 75 },
		{ Pos = V(-20.0, 0, 114.5), Scale = 1.35, Yaw = 160 },
		{ Pos = V(-13.5, 0, 116.5), Scale = 1.45, Yaw = 25 },
		{ Pos = V(-7.0, 0, 118.0), Scale = 1.30, Yaw = 195 },
		{ Pos = V(-2.5, 0, 119.5), Scale = 1.25, Yaw = 85 },
		{ Pos = V(4.0, 0, 121.0), Scale = 1.35, Yaw = 240 },
		{ Pos = V(10.5, 0, 118.0), Scale = 1.30, Yaw = 145 },
		{ Pos = V(16.5, 0, 115.0), Scale = 1.40, Yaw = 320 },
		{ Pos = V(22.5, 0, 117.5), Scale = 1.35, Yaw = 15 },
		{ Pos = V(28.5, 0, 115.5), Scale = 1.25, Yaw = 105 },
		{ Pos = V(34.5, 0, 117.0), Scale = 1.30, Yaw = 200 },
		{ Pos = V(40.0, 0, 112.0), Scale = 1.40, Yaw = 50 },
		{ Pos = V(26.0, 0, 101.0), Scale = 1.30, Yaw = 65 },
		{ Pos = V(32.5, 0, 104.5), Scale = 1.25, Yaw = 175 },
		-- Tower perimeter & pine tree base accents
		{ Pos = V(35.0, 0, 74.5), Scale = 1.25, Yaw = 270 },
		{ Pos = V(36.0, 0, 86.0), Scale = 1.35, Yaw = 95 },
		{ Pos = V(31.0, 0, 91.5), Scale = 1.20, Yaw = 185 },
		{ Pos = V(27.0, 0, 93.0), Scale = 1.25, Yaw = 40 },
		{ Pos = V(-24.0, 0, 70.0), Scale = 1.30, Yaw = 130 },
		{ Pos = V(-28.0, 0, 94.0), Scale = 1.35, Yaw = 55 },
		{ Pos = V(-36.0, 0, 118.0), Scale = 1.30, Yaw = 225 },
		{ Pos = V(-28.0, 0, 121.0), Scale = 1.40, Yaw = 80 },
		{ Pos = V(12.0, 0, 126.0), Scale = 1.35, Yaw = 155 },
		{ Pos = V(39.0, 0, 122.0), Scale = 1.25, Yaw = 300 },
	}
	for _, g in ipairs(grassTufts) do
		buildGrassTuft(folder, origin, g.Pos, g.Scale, g.Yaw)
	end
end

return OutskirtsBuilder
