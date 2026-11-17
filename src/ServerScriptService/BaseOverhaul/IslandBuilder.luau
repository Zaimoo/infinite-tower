--!strict
-- IslandBuilder.luau
-- ModuleScript: Builds a single reusable floating fortress island (flat cobblestone top + jagged tapered rock underside + cloud wisps).
-- All decorative underside parts have CanCollide, CanTouch, and CanQuery disabled for mobile performance.

local SceneryBake = require(script.Parent:WaitForChild("SceneryBake"))

local IslandBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
IslandBuilder.Config = {
	-- Top Buildable Surface Dimensions (Citadel Courtyard: 160 x 120 studs; Outskirts: 160 x 100 studs)
	TopWidth = 160, -- X dimension (studs)
	TopLength = 120, -- Courtyard walking surface Z dimension (studs) [-60, +60]
	CitadelLength = 120, -- Z dimension of cobblestone Courtyard (studs) [-60, +60]
	TotalLength = 220, -- Full island footprint [-60, +160] supporting rocky underside
	TopThickness = 6, -- Thickness of the top stone slab (studs)
	CenterOffsetZ = 100, -- Anchor offset for IslandRoot so front gate lands flush at bridge
	UndersideCenterZ = 50, -- Midpoint between Citadel [-60, +60] and Outskirts [+60, +160]
	chamferSize = 16, -- Corner bevel size to give a fortress silhouette

	-- Underside Rock Formation
	UndersideDepth = 95, -- Total depth of the tapered rocky mass below the top slab
	UndersideLayers = 5, -- Number of stepped rock tiers tapering inward
	OuterSpireCount = 16, -- Jagged rock spires around the upper/mid underside perimeter
	InnerStalactiteCount = 10, -- Deep jagged rock points tapering toward the bottom tip
	RandomSeed = 4042026, -- Fixed seed so all 6 cloned islands have identical geometry

	-- Materials & Colors (Weathered Grey Castle Flagstone Courtyard Palette)
	TopMaterial = Enum.Material.Slate,
	TopColor = Color3.fromRGB(74, 78, 86), -- Neutral weathered castle stone sub-layer
	DampMossMaterial = Enum.Material.Slate,
	DampMossColor = Color3.fromRGB(58, 62, 70),
	RimMaterial = Enum.Material.Cobblestone,
	RimColor = Color3.fromRGB(62, 66, 70),
	RockMaterial = Enum.Material.Slate,
	RockColorUpper = Color3.fromRGB(65, 68, 72),
	RockColorDeep = Color3.fromRGB(42, 45, 50),

	-- Underside Cloud Wisps
	EnableCloudWisps = true,
	CloudColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 190, 205)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 115, 130)),
	}),
}

local PartKit = require(script.Parent:WaitForChild("PartKit"))
local makePart = PartKit.Part
local makeWedge = PartKit.Wedge

local cachedEnvSpawner: any = false
local function getEnvSpawner(): any?
	if cachedEnvSpawner ~= false then
		return cachedEnvSpawner
	end
	local mod = script.Parent and script.Parent:FindFirstChild("EnvironmentSpawner")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		cachedEnvSpawner = if ok then res else nil
	else
		cachedEnvSpawner = nil
	end
	return cachedEnvSpawner
end

--============================================================================
-- MOSSY FLAGSTONE COURTYARD GROUND BUILDER (image_892b9a.jpg)
--============================================================================
-- Generates the concentric fountain plaza, 8-10 stud wide radial flagstone walkways,
-- damp perimeter moss patches, and math.noise-driven weathered grey flagstone scatter.
-- All parts are ultra-thin (0.02-0.08 studs), CanCollide=false, CanQuery=false, CanTouch=false,
-- Massless=true, CastShadow=false, keeping total ground detail parts <= 250 per plot.
local function buildMossyFlagstoneCourtyard(
	islandModel: Model,
	courtyardCenterCF: CFrame,
	courtyardSize: Vector2,
	seed: number
): Folder
	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "CourtyardGroundTiles"
	tilesFolder.Parent = islandModel

	local tileRng = Random.new(seed + 892)
	local noiseSeed = (seed % 997) * 0.137

	-- 4 Weathered Gothic Stone Tones (Cool Castle Grey Palette)
	local COLOR_WEATHERED_SLATE = Color3.fromRGB(74, 78, 86) -- #4A4E56 Primary Flagstone
	local COLOR_LIGHT_ASH = Color3.fromRGB(88, 92, 100) -- #585C64 Highlight Ash Flagstone
	local COLOR_DARK_BASALT = Color3.fromRGB(56, 60, 68) -- #383C44 Shadow / Basalt
	local COLOR_MOSS_OLIVE = Color3.fromRGB(66, 70, 78) -- #42464E Secondary Weathered Slate

	local primaryStonePalette = {
		COLOR_WEATHERED_SLATE,
		COLOR_LIGHT_ASH,
		COLOR_DARK_BASALT,
		COLOR_WEATHERED_SLATE,
		COLOR_MOSS_OLIVE,
	}
	local curbStonePalette = {
		COLOR_LIGHT_ASH,
		COLOR_WEATHERED_SLATE,
		COLOR_DARK_BASALT,
		COLOR_LIGHT_ASH,
	}

	local partCount = 0
	local MAX_GROUND_PARTS = 246

	local function makeGroundTile(
		name: string,
		size: Vector3,
		localCF: CFrame,
		color: Color3,
		material: Enum.Material
	): Part?
		if partCount >= MAX_GROUND_PARTS then
			return nil
		end
		partCount += 1
		return makePart({
			Name = name,
			Size = size,
			CFrame = courtyardCenterCF * localCF,
			Material = material,
			Color = color,
			Decorative = true,
			Massless = true,
			Parent = tilesFolder,
		})
	end

	-- 1. Courtyard dimensions (fallback procedural scatter uses uniform grey slate without moss patches)
	local halfW = courtyardSize.X * 0.5
	local halfL = courtyardSize.Y * 0.5

	-- 2. Facility clearances (radial paths and concentric fountain rings removed — pure flagstone courtyard floor)
	local trainingCornerLen = math.sqrt(66.8 * 66.8 + 46.8 * 46.8)
	local trainingDirX, trainingDirZ = -66.8 / trainingCornerLen, 46.8 / trainingCornerLen

	local trainCenterX, trainCenterZ = trainingDirX * 49.0, trainingDirZ * 49.0
	local trainYaw = -math.atan2(66.8, 46.8)
	local trainCos, trainSin = math.cos(trainYaw), math.sin(trainYaw)
	local function trainingHalfWidthAtZ(lz: number): number
		if lz < -13.0 or lz > 28.2 then
			return -1
		elseif lz <= -9.85 then
			local t = (lz + 13.0) / 3.15
			return 5.6 + t * (16.6 - 5.6)
		elseif lz <= 2.55 then
			local t = (lz + 9.85) / 12.4
			return 16.6 + t * (24.4 - 16.6)
		elseif lz <= 18.85 then
			local t = (lz - 2.55) / 16.3
			return 24.4 + t * (12.6 - 24.4)
		else
			local t = (lz - 18.85) / 9.35
			return math.max(0.5, 12.6 * (1 - t))
		end
	end

	-- Helper to check if a courtyard (x, z) point overlaps any facility footprint
	local function isPointOnWalkwayOrFacility(px: number, pz: number): boolean
		local distCenter = math.sqrt(px * px + pz * pz)
		if distCenter < 14.5 then
			return true
		end
		-- Keep random courtyard flagstones outside Market's enlarged organic flagstone bazaar perimeter
		local distMarket = math.sqrt((px - 50) ^ 2 + (pz - 36) ^ 2)
		if distMarket < 21.5 then
			return true
		end
		-- Keep random courtyard flagstones outside Training Grounds' arena floor polygon
		local tdx, tdz = px - trainCenterX, pz - trainCenterZ
		local tlx = tdx * trainCos - tdz * trainSin
		local tlz = tdx * trainSin + tdz * trainCos
		local halfWTrain = trainingHalfWidthAtZ(tlz)
		if halfWTrain > 0 and math.abs(tlx) < (halfWTrain + 1.6) then
			return true
		end
		return false
	end

	-- 3. Organic Flagstone Courtyard Scatter (Deterministic math.noise across intermediate & perimeter zones)
	local marginWallX = halfW - 9.0 -- 71 studs (inside castle walls)
	local marginWallZ = halfL - 8.5 -- 51.5 studs (inside castle walls)
	local stepX = 8.2
	local stepZ = 7.8

	local gx = -marginWallX + 3.5
	while gx <= marginWallX - 3.5 do
		local gz = -marginWallZ + 3.5
		while gz <= marginWallZ - 3.5 do
			local jitterX = gx + tileRng:NextNumber(-1.4, 1.4)
			local jitterZ = gz + tileRng:NextNumber(-1.4, 1.4)

			if not isPointOnWalkwayOrFacility(jitterX, jitterZ) then
				local distToWall = math.min(marginWallX - math.abs(jitterX), marginWallZ - math.abs(jitterZ))
				local n = math.noise(jitterX * 0.08, jitterZ * 0.08, noiseSeed)

				if distToWall < 6.0 then
					-- Perimeter castle wall drop-off: mostly open moss, occasional loose weathered edge stone
					if n > 0.18 then
						local w = tileRng:NextNumber(2.5, 3.4)
						local l = tileRng:NextNumber(2.5, 3.2)
						local yaw = math.rad(tileRng:NextNumber(-3.0, 3.0))
						makeGroundTile(
							"PerimeterEdgeStone",
							Vector3.new(w, 0.04, l),
							CFrame.new(jitterX, 0.02, jitterZ) * CFrame.Angles(0, yaw, 0),
							COLOR_MOSS_OLIVE,
							Enum.Material.Cobblestone
						)
					end
				elseif n > -0.10 then
					-- High noise (> -0.10): Weathered Slate / Ash / Basalt flagstones (0.06 studs high) with mossy gaps
					local w = tileRng:NextNumber(3.6, 5.5)
					local l = tileRng:NextNumber(3.2, 4.5)
					local yaw = math.rad(tileRng:NextNumber(-3.0, 3.0))
					local tonePick = tileRng:NextInteger(1, 4)
					local col = if tonePick == 1
						then COLOR_WEATHERED_SLATE
						elseif tonePick == 2 then COLOR_LIGHT_ASH
						elseif tonePick == 3 then COLOR_DARK_BASALT
						else COLOR_MOSS_OLIVE
					local mat = if tonePick == 3
						then Enum.Material.Rock
						elseif tonePick == 4 then Enum.Material.Cobblestone
						else Enum.Material.Slate

					makeGroundTile(
						"CourtyardFlagstone",
						Vector3.new(w, 0.06, l),
						CFrame.new(jitterX, 0.03, jitterZ) * CFrame.Angles(0, yaw, 0),
						col,
						mat
					)
				elseif n > -0.35 then
					-- Medium noise (-0.35 to -0.10): Smaller olive-tinted flagstones partially sunken (0.03 studs high)
					local w = tileRng:NextNumber(2.5, 3.8)
					local l = tileRng:NextNumber(2.5, 3.5)
					local yaw = math.rad(tileRng:NextNumber(-3.0, 3.0))
					makeGroundTile(
						"MossySunkenStone",
						Vector3.new(w, 0.03, l),
						CFrame.new(jitterX, 0.015, jitterZ) * CFrame.Angles(0, yaw, 0),
						COLOR_MOSS_OLIVE,
						Enum.Material.Cobblestone
					)
				end
			end
			gz += stepZ
		end
		gx += stepX
	end

	return tilesFolder
end

IslandBuilder.BuildMossyFlagstoneCourtyard = buildMossyFlagstoneCourtyard

-- Builds an Island model centered at origin CFrame.identity where Y = 0 is the flat top walking surface.
function IslandBuilder.Build(customConfig: { [string]: any }?): Model
	local cfg = table.clone(IslandBuilder.Config)
	if customConfig then
		for k, v in pairs(customConfig) do
			(cfg :: any)[k] = v
		end
	end

	local rng = Random.new(cfg.RandomSeed)

	local islandModel = Instance.new("Model")
	islandModel.Name = "FloatingFortressIsland"

	local centerZ = cfg.CenterOffsetZ or 100
	local undersideZ = cfg.UndersideCenterZ or 50
	local courtyardL = cfg.CitadelLength or cfg.TopLength or 120
	local totalL = cfg.TotalLength or 220

	-- Invisible Island Anchor at geometric center of entire island mass (centerZ = 100)
	-- Serves as PrimaryPart so pivoting to RingRadius aligns front gate with the bridge
	local islandRoot = makePart({
		Name = "IslandRoot",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(0, -cfg.TopThickness * 0.5, centerZ),
		Transparency = 1,
		CanCollide = false,
		Decorative = true,
		Parent = islandModel,
	})
	islandModel.PrimaryPart = islandRoot

	-- 1. Primary Flat Buildable Top Surface (Courtyard only: covers [-90, +90], stops at rear wall)
	-- Does NOT reach the Outskirts [+90, +230], preventing coplanar Z-fighting with OutskirtsGrounds
	local topSlab = makePart({
		Name = "IslandTopSurface",
		Size = Vector3.new(cfg.TopWidth, cfg.TopThickness, courtyardL),
		CFrame = CFrame.new(0, -cfg.TopThickness * 0.5, 0),
		Material = cfg.TopMaterial,
		Color = cfg.TopColor,
		Decorative = false,
		Parent = islandModel,
	})

	-- Subtle Stone Rim Framing around the courtyard top slab
	local rimHeight = cfg.TopThickness + 1.0
	local rimThickness = 4.0
	local halfW = cfg.TopWidth * 0.5
	local halfCourtyardL = courtyardL * 0.5

	local rimDefs = {
		{ Name = "RimNorth", Size = Vector3.new(cfg.TopWidth + 2, rimHeight, rimThickness), Pos = Vector3.new(0, -rimHeight * 0.5 + 0.2, -halfCourtyardL) },
		{ Name = "RimEast", Size = Vector3.new(rimThickness, rimHeight, courtyardL), Pos = Vector3.new(halfW, -rimHeight * 0.5 + 0.2, 0) },
		{ Name = "RimWest", Size = Vector3.new(rimThickness, rimHeight, courtyardL), Pos = Vector3.new(-halfW, -rimHeight * 0.5 + 0.2, 0) },
	}
	for _, r in ipairs(rimDefs) do
		makePart({
			Name = r.Name,
			Size = r.Size,
			CFrame = CFrame.new(r.Pos),
			Material = cfg.RimMaterial,
			Color = cfg.RimColor,
			Decorative = true,
			Parent = islandModel,
		})
	end

	-- 1B. Weathered Grey Flagstone Courtyard Ground (prefer single Blender-authored asset; fallback to parts)
	local envSpawner = getEnvSpawner()
	if envSpawner and envSpawner.HasTemplate("CastleCourtyard_Ground") then
		envSpawner.SpawnCastleCourtyardGround(islandModel, CFrame.identity)
	else
		local courtyardTiles = buildMossyFlagstoneCourtyard(islandModel, CFrame.identity, Vector2.new(cfg.TopWidth, courtyardL), cfg.RandomSeed)
		-- Swap the thin tile slabs for the Blender-merged meshes when they are imported (SceneryBake)
		SceneryBake.Apply(courtyardTiles, CFrame.identity, "CourtyardGroundTiles")
	end

	-- 1C. Courtyard Carved Stone Benches (Phase 2.3 Accent Props)
	local accentsFolder = Instance.new("Folder")
	accentsFolder.Name = "CourtyardAccents"
	accentsFolder.Parent = islandModel

	local stoneBenchColor = Color3.fromRGB(92, 96, 106)
	local goldAccentColor = Color3.fromRGB(196, 152, 58)

	-- 2 Carved Gothic Stone Benches flanking the outer ring promenade (facing the fountain)
	for idx, benchAngDeg in ipairs({ -108, 18 }) do
		local a = math.rad(benchAngDeg)
		local bx = math.sin(a) * 19.8
		local bz = math.cos(a) * 19.8
		local benchCF = CFrame.lookAt(Vector3.new(bx, 0, bz), Vector3.new(0, 0, 0))

		makePart({
			Name = string.format("GothicBench_Seat_%d", idx),
			Size = Vector3.new(4.6, 0.35, 1.55),
			CFrame = benchCF * CFrame.new(0, 1.35, 0),
			Material = Enum.Material.Slate,
			Color = stoneBenchColor,
			Decorative = true,
			Parent = accentsFolder,
		})
		makePart({
			Name = string.format("GothicBench_Backrest_%d", idx),
			Size = Vector3.new(4.4, 1.35, 0.32),
			CFrame = benchCF * CFrame.new(0, 2.15, 0.62),
			Material = Enum.Material.Slate,
			Color = stoneBenchColor,
			Decorative = true,
			Parent = accentsFolder,
		})
		makePart({
			Name = string.format("GothicBench_GoldRelief_%d", idx),
			Size = Vector3.new(3.6, 0.65, 0.08),
			CFrame = benchCF * CFrame.new(0, 2.20, 0.44),
			Material = Enum.Material.Metal,
			Color = goldAccentColor,
			Decorative = true,
			Parent = accentsFolder,
		})
		for _, side in ipairs({ -1, 1 }) do
			makePart({
				Name = string.format("GothicBench_Armrest_%d_%s", idx, if side < 0 then "L" else "R"),
				Size = Vector3.new(0.42, 1.85, 1.65),
				CFrame = benchCF * CFrame.new(side * 2.15, 0.92, 0),
				Material = Enum.Material.Slate,
				Color = stoneBenchColor,
				Decorative = true,
				Parent = accentsFolder,
			})
		end
	end

	-- 2. Decorative Tapered Rocky Underside (Non-collidable, low part count for mobile)
	local undersideFolder = Instance.new("Folder")
	undersideFolder.Name = "RockyUnderside"
	undersideFolder.Parent = islandModel

	local currentY = -cfg.TopThickness
	local layerHeight = (cfg.UndersideDepth * 0.58) / cfg.UndersideLayers

	for layer = 1, cfg.UndersideLayers do
		local t = (layer - 1) / math.max(1, cfg.UndersideLayers - 1)
		local scale = 1.0 - (t * 0.58)
		local layerW = cfg.TopWidth * scale
		local layerL = totalL * scale
		local col = cfg.RockColorUpper:Lerp(cfg.RockColorDeep, t)
		local yawJitter = math.rad((layer % 2 == 0 and 1 or -1) * (layer * 3.5))

		makePart({
			Name = string.format("RockTier_%d", layer),
			Size = Vector3.new(layerW, layerHeight + 2, layerL),
			CFrame = CFrame.new(0, currentY - layerHeight * 0.5, undersideZ) * CFrame.Angles(0, yawJitter, 0),
			Material = cfg.RockMaterial,
			Color = col,
			Decorative = true,
			Parent = undersideFolder,
		})
		currentY -= layerHeight
	end

	-- 3. Outer Craggy Rock Wedges & Jagged Spires (Ripped-earth silhouette)
	for i = 1, cfg.OuterSpireCount do
		local angle = ((i - 1) / cfg.OuterSpireCount) * (math.pi * 2) + rng:NextNumber(-0.08, 0.08)
		local rx = (cfg.TopWidth * 0.44) * rng:NextNumber(0.86, 1.02)
		local rz = (totalL * 0.44) * rng:NextNumber(0.86, 1.02)
		local px = math.cos(angle) * rx
		local pz = undersideZ + math.sin(angle) * rz
		local spireH = rng:NextNumber(34, 58)
		local spireW = rng:NextNumber(18, 28)
		local spireD = rng:NextNumber(16, 24)
		local tilt = math.rad(rng:NextNumber(12, 24))
		local tColor = rng:NextNumber(0.15, 0.65)

		makeWedge({
			Name = string.format("OuterCrag_%d", i),
			Size = Vector3.new(spireW, spireH, spireD),
			CFrame = CFrame.new(px, -cfg.TopThickness - spireH * 0.42, pz)
				* CFrame.Angles(0, -angle + math.pi * 0.5, 0)
				* CFrame.Angles(tilt, 0, math.rad(math.pi)),
			Material = cfg.RockMaterial,
			Color = cfg.RockColorUpper:Lerp(cfg.RockColorDeep, tColor),
			Decorative = true,
			Parent = undersideFolder,
		})
	end

	-- 4. Deep Inner Jagged Points & Central Root Spike
	for i = 1, cfg.InnerStalactiteCount do
		local angle = ((i - 1) / cfg.InnerStalactiteCount) * (math.pi * 2) + 0.25
		local radius = rng:NextNumber(20, 50)
		local px = math.cos(angle) * radius
		local pz = undersideZ + math.sin(angle) * radius
		local pointH = rng:NextNumber(42, 68)
		local pointW = rng:NextNumber(12, 20)

		makeWedge({
			Name = string.format("DeepPoint_%d", i),
			Size = Vector3.new(pointW, pointH, pointW),
			CFrame = CFrame.new(px, currentY - pointH * 0.30, pz)
				* CFrame.Angles(math.rad(170), angle, math.rad(rng:NextNumber(-10, 10))),
			Material = cfg.RockMaterial,
			Color = cfg.RockColorDeep,
			Decorative = true,
			Parent = undersideFolder,
		})
	end

	-- Central Apex Point at the very bottom
	makeWedge({
		Name = "CentralApexSpike",
		Size = Vector3.new(26, 60, 26),
		CFrame = CFrame.new(0, -cfg.UndersideDepth + 12, undersideZ) * CFrame.Angles(math.rad(180), math.rad(45), 0),
		Material = cfg.RockMaterial,
		Color = cfg.RockColorDeep,
		Decorative = true,
		Parent = undersideFolder,
	})

	-- 5. Subtle Cloud Wisps around the Underside
	if cfg.EnableCloudWisps then
		local cloudAnchor = makePart({
			Name = "UndersideCloudEmitter",
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(0, -cfg.TopThickness - 22, undersideZ),
			Transparency = 1,
			Decorative = true,
			Parent = undersideFolder,
		})

		local clouds = Instance.new("ParticleEmitter")
		clouds.Name = "CloudWisps"
		clouds.Texture = "rbxassetid://243660364" -- Soft built-in cloud/smoke puff
		clouds.Color = cfg.CloudColor
		clouds.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.25, 0.78),
			NumberSequenceKeypoint.new(0.75, 0.82),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		clouds.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 18),
			NumberSequenceKeypoint.new(0.5, 28),
			NumberSequenceKeypoint.new(1.0, 34),
		})
		clouds.Lifetime = NumberRange.new(6, 9)
		clouds.Rate = 5 -- Low rate for mobile performance
		clouds.Speed = NumberRange.new(2, 5)
		clouds.SpreadAngle = Vector2.new(180, 12)
		clouds.Rotation = NumberRange.new(0, 360)
		clouds.RotSpeed = NumberRange.new(-12, 12)
		clouds.Shape = Enum.ParticleEmitterShape.Cylinder
		clouds.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		clouds.Parent = cloudAnchor
	end

	return islandModel
end

-- Removes any courtyard Gothic lantern models around the island fountain while preserving benches.
function IslandBuilder.CleanupCourtyardLanterns(accentsFolder: Instance)
	for _, child in accentsFolder:GetChildren() do
		if child.Name:find("^GothicLantern_") then
			child:Destroy()
		end
	end
end

return IslandBuilder
