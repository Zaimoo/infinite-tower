--!strict
-- IslandBuilder.luau
-- ModuleScript: Builds a single reusable floating fortress island (flat cobblestone top + jagged tapered rock underside + cloud wisps).
-- All decorative underside parts have CanCollide, CanTouch, and CanQuery disabled for mobile performance.

local GothicLanternSpawner = require(script.Parent:WaitForChild("GothicLanternSpawner"))

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

	-- Materials & Colors (Mossy Gothic Flagstone Courtyard Palette — image_892b9a.jpg)
	TopMaterial = Enum.Material.LeafyGrass,
	TopColor = Color3.fromRGB(53, 74, 46), -- #354A2E Deep Forest Moss sub-layer
	DampMossMaterial = Enum.Material.Ground,
	DampMossColor = Color3.fromRGB(42, 59, 36), -- #2A3B24 Damp Earth / Perimeter Moss
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

	-- 4 Weathered Gothic Stone Tones + Damp Moss Earth Palette (Extracted from image_892b9a.jpg)
	local COLOR_WEATHERED_SLATE = Color3.fromRGB(62, 66, 74) -- #3E424A Primary Flagstone
	local COLOR_LIGHT_ASH = Color3.fromRGB(78, 84, 92) -- #4E545C Highlight Ash Flagstone
	local COLOR_DARK_BASALT = Color3.fromRGB(43, 46, 52) -- #2B2E34 Shadow / Damp Basalt
	local COLOR_MOSS_OLIVE = Color3.fromRGB(63, 74, 60) -- #3F4A3C Moss-Tinted Olive Stone
	local COLOR_DAMP_MOSS = Color3.fromRGB(42, 59, 36) -- #2A3B24 Damp Earth / Perimeter Moss

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

	-- 1. Darker Damp-Moss Earth Patches (0.02 studs thin at Y = 0.01) near perimeter castle walls & corners
	local halfW = courtyardSize.X * 0.5
	local halfL = courtyardSize.Y * 0.5
	local dampMossPatches = {
		{ Pos = Vector3.new(halfW - 18, 0.01, -halfL + 16), Size = Vector3.new(26, 0.02, 22), Yaw = 4 },
		{ Pos = Vector3.new(halfW - 16, 0.01, halfL - 18), Size = Vector3.new(24, 0.02, 24), Yaw = -6 },
		{ Pos = Vector3.new(-halfW + 18, 0.01, -halfL + 18), Size = Vector3.new(26, 0.02, 24), Yaw = 5 },
		{ Pos = Vector3.new(-halfW + 18, 0.01, halfL - 18), Size = Vector3.new(26, 0.02, 24), Yaw = -4 },
		{ Pos = Vector3.new(halfW - 12, 0.01, 0), Size = Vector3.new(16, 0.02, 34), Yaw = 2 },
		{ Pos = Vector3.new(-halfW + 12, 0.01, 2), Size = Vector3.new(16, 0.02, 32), Yaw = -3 },
		{ Pos = Vector3.new(-22, 0.01, -halfL + 10), Size = Vector3.new(28, 0.02, 12), Yaw = 1 },
		{ Pos = Vector3.new(24, 0.01, -halfL + 10), Size = Vector3.new(28, 0.02, 12), Yaw = -2 },
		{ Pos = Vector3.new(-18, 0.01, halfL - 10), Size = Vector3.new(30, 0.02, 12), Yaw = 2 },
		{ Pos = Vector3.new(40, 0.01, halfL - 10), Size = Vector3.new(24, 0.02, 12), Yaw = -2 },
	}
	for idx, patch in ipairs(dampMossPatches) do
		makeGroundTile(
			string.format("DampMossPatch_%d", idx),
			patch.Size,
			CFrame.new(patch.Pos) * CFrame.Angles(0, math.rad(patch.Yaw), 0),
			COLOR_DAMP_MOSS,
			Enum.Material.Ground
		)
	end

	-- 2. Radial Walkway Definitions (Connecting Fountain Plaza to Bridge Gate, Outskirts Gate & all 5 Stations)
	local trainingCornerLen = math.sqrt(66.8 * 66.8 + 46.8 * 46.8)
	local trainingDirX, trainingDirZ = -66.8 / trainingCornerLen, 46.8 / trainingCornerLen
	local radialWalkways = {
		{ Name = "Path_BridgeGate", P0 = Vector3.new(0, 0, -19.6), P1 = Vector3.new(0, 0, -56.0), Width = 9.2, Segments = 5 },
		{ Name = "Path_SummoningPortal", P0 = Vector3.new(16.0, 0, -11.4), P1 = Vector3.new(41.5, 0, -29.5), Width = 8.4, Segments = 4 },
		{ Name = "Path_BlacksmithForge", P0 = Vector3.new(19.6, 0, -0.8), P1 = Vector3.new(44.5, 0, -1.8), Width = 8.4, Segments = 4 },
		{ Name = "Path_Market", P0 = Vector3.new(16.2, 0, 11.2), P1 = Vector3.new(36.0, 0, 25.4), Width = 8.4, Segments = 4 },
		{ Name = "Path_OutskirtsGate", P0 = Vector3.new(4.8, 0, 19.0), P1 = Vector3.new(14.0, 0, 56.0), Width = 9.0, Segments = 5 },
		{ Name = "Path_SynthesisChamber", P0 = Vector3.new(-16.6, 0, -10.6), P1 = Vector3.new(-32.0, 0, -20.4), Width = 8.4, Segments = 3 },
		{ Name = "Path_TrainingArea", P0 = Vector3.new(trainingDirX * 19.65, 0, trainingDirZ * 19.65), P1 = Vector3.new(trainingDirX * 39.2, 0, trainingDirZ * 39.2), Width = 8.4, Segments = 3 },
	}

	local radialBranchAngles = {}
	for _, rw in ipairs(radialWalkways) do
		table.insert(radialBranchAngles, math.atan2(rw.P0.X, rw.P0.Z))
	end

	local function isNearBranchAngle(theta: number): boolean
		for _, bAngle in ipairs(radialBranchAngles) do
			local diff = math.atan2(math.sin(theta - bAngle), math.cos(theta - bAngle))
			if math.abs(diff) < 0.24 then
				return true
			end
		end
		return false
	end

	-- Helper to check if a courtyard (x, z) point overlaps any radial walkway or facility footprint
	local function isPointOnWalkwayOrFacility(px: number, pz: number): boolean
		local distCenter = math.sqrt(px * px + pz * pz)
		if distCenter < 21.6 then
			return true
		end
		for _, rw in ipairs(radialWalkways) do
			local ax, az = rw.P0.X, rw.P0.Z
			local bx, bz = rw.P1.X, rw.P1.Z
			local abx, abz = bx - ax, bz - az
			local abLenSq = abx * abx + abz * abz
			if abLenSq > 0.01 then
				local t = math.clamp(((px - ax) * abx + (pz - az) * abz) / abLenSq, 0, 1)
				local cx = ax + t * abx
				local cz = az + t * abz
				local dx, dz = px - cx, pz - cz
				if (dx * dx + dz * dz) < ((rw.Width * 0.5 + 2.8) ^ 2) then
					return true
				end
			end
		end
		return false
	end

	-- 3. Concentric Fountain Plaza (Radius ~ 12.2 to 20.4 studs, 0.06 stud flagstones + 0.08 stud curbs)
	-- Ring 1: Inner Flagstone Apron Ring (R = 14.0, Width = 3.2, 16 slabs with 0.18 stud mossy gaps)
	local innerRingR = 14.0
	local innerRingW = 3.2
	local innerSegments = 16
	local mortarGap = 0.18

	for i = 1, innerSegments do
		local a0 = ((i - 1) / innerSegments) * math.pi * 2
		local a1 = (i / innerSegments) * math.pi * 2
		local aMid = (a0 + a1) * 0.5
		local chord = 2 * innerRingR * math.sin((a1 - a0) * 0.5) - mortarGap
		local cx = math.sin(aMid) * innerRingR
		local cz = math.cos(aMid) * innerRingR
		local tangentDir = Vector3.new(math.cos(aMid), 0, -math.sin(aMid))
		local yawJitter = math.rad(tileRng:NextNumber(-1.5, 1.5))
		local segCF = CFrame.lookAt(Vector3.new(cx, 0.03, cz), Vector3.new(cx, 0.03, cz) + tangentDir)
			* CFrame.Angles(0, yawJitter, 0)

		makeGroundTile(
			string.format("PlazaInner_Flagstone_%d", i),
			Vector3.new(innerRingW, 0.06, chord),
			segCF,
			primaryStonePalette[((i - 1) % #primaryStonePalette) + 1],
			if i % 2 == 0 then Enum.Material.Slate else Enum.Material.Cobblestone
		)

		-- Inner raised stone curb hugging the Fountain plinth (0.08 studs high)
		local curbInR = innerRingR - innerRingW * 0.5 - 0.38
		local curbInChord = 2 * curbInR * math.sin((a1 - a0) * 0.5) - 0.15
		local ix = math.sin(aMid) * curbInR
		local iz = math.cos(aMid) * curbInR
		makeGroundTile(
			string.format("PlazaInner_Curb_%d", i),
			Vector3.new(0.60, 0.08, curbInChord),
			CFrame.lookAt(Vector3.new(ix, 0.04, iz), Vector3.new(ix, 0.04, iz) + tangentDir),
			curbStonePalette[((i - 1) % #curbStonePalette) + 1],
			Enum.Material.Slate
		)
	end

	-- Ring 2: Outer Flagstone Plaza Ring (R = 17.8, Width = 3.8, 20 slabs with 0.22 stud mossy gaps)
	local outerRingR = 17.8
	local outerRingW = 3.8
	local outerSegments = 20
	local curbWidth = 0.78

	for i = 1, outerSegments do
		local a0 = ((i - 1) / outerSegments) * math.pi * 2
		local a1 = (i / outerSegments) * math.pi * 2
		local aMid = (a0 + a1) * 0.5
		local chord = 2 * outerRingR * math.sin((a1 - a0) * 0.5) - 0.22
		local cx = math.sin(aMid) * outerRingR
		local cz = math.cos(aMid) * outerRingR
		local tangentDir = Vector3.new(math.cos(aMid), 0, -math.sin(aMid))
		local yawJitter = math.rad(tileRng:NextNumber(-2.0, 2.0))
		local segCF = CFrame.lookAt(Vector3.new(cx, 0.03, cz), Vector3.new(cx, 0.03, cz) + tangentDir)
			* CFrame.Angles(0, yawJitter, 0)

		makeGroundTile(
			string.format("PlazaOuter_Flagstone_%d", i),
			Vector3.new(outerRingW, 0.06, chord),
			segCF,
			primaryStonePalette[((i + 1) % #primaryStonePalette) + 1],
			if i % 3 == 0 then Enum.Material.Cobblestone else Enum.Material.Slate
		)

		-- Outer raised curb stones (0.08 studs high, skipped where radial walkways branch out)
		if not isNearBranchAngle(aMid) then
			local outerCurbR = outerRingR + outerRingW * 0.5 + curbWidth * 0.5 + 0.14
			local outerChord = 2 * outerCurbR * math.sin((a1 - a0) * 0.5) - 0.20
			local ox = math.sin(aMid) * outerCurbR
			local oz = math.cos(aMid) * outerCurbR
			makeGroundTile(
				string.format("PlazaOuter_Curb_%d", i),
				Vector3.new(curbWidth, 0.08, outerChord),
				CFrame.lookAt(Vector3.new(ox, 0.04, oz), Vector3.new(ox, 0.04, oz) + tangentDir),
				curbStonePalette[((i + 2) % #curbStonePalette) + 1],
				Enum.Material.Slate
			)
		end
	end

	-- 4. Build Radial Cobblestone/Slate Walkways (8.4-9.2 studs wide, 0.06 stud slabs + 0.08 stud curbs)
	for _, rw in ipairs(radialWalkways) do
		local dir = rw.P1 - rw.P0
		local totalDist = dir.Magnitude
		if totalDist >= 1 then
			local unit = dir.Unit
			local segLen = totalDist / rw.Segments
			local lookCF = CFrame.lookAt(Vector3.zero, unit)
			local innerWidth = rw.Width - curbWidth * 2 - 0.30

			for s = 1, rw.Segments do
				local t = (s - 0.5) / rw.Segments
				local pos = rw.P0:Lerp(rw.P1, t)
				local yawJitter = math.rad(tileRng:NextNumber(-2.2, 2.2))
				local col = primaryStonePalette[((s + tileRng:NextInteger(0, 3)) % #primaryStonePalette) + 1]
				local mat = if (s % 2 == 0) then Enum.Material.Cobblestone else Enum.Material.Slate

				makeGroundTile(
					string.format("%s_Slab_%d", rw.Name, s),
					Vector3.new(innerWidth, 0.06, segLen - 0.24),
					CFrame.new(pos.X, 0.03, pos.Z) * lookCF * CFrame.Angles(0, yawJitter, 0),
					col,
					mat
				)

				-- Left and Right raised curb flagstones (0.08 studs high) with mortar gap
				for _, side in ipairs({ -1, 1 }) do
					local curbOffset = lookCF.RightVector * (side * (rw.Width * 0.5 - curbWidth * 0.5))
					local curbCol = curbStonePalette[((s + (if side > 0 then 1 else 2)) % #curbStonePalette) + 1]
					local curbYaw = math.rad(tileRng:NextNumber(-1.5, 1.5))
					makeGroundTile(
						string.format("%s_Curb_%d_%s", rw.Name, s, if side < 0 then "L" else "R"),
						Vector3.new(curbWidth, 0.08, segLen - 0.28),
						CFrame.new(pos.X + curbOffset.X, 0.04, pos.Z + curbOffset.Z)
							* lookCF
							* CFrame.Angles(0, curbYaw, 0),
						curbCol,
						Enum.Material.Slate
					)
				end
			end
		end
	end

	-- 5. Organic Mossy Flagstone Courtyard Scatter (Deterministic math.noise across intermediate & perimeter zones)
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

	-- 1B. Mossy Green & Grey Flagstone Courtyard Ground (Concentric Plaza, Radial Walkways & Mossy Scatter)
	buildMossyFlagstoneCourtyard(islandModel, CFrame.identity, Vector2.new(cfg.TopWidth, courtyardL), cfg.RandomSeed)

	-- 1C. Courtyard Gothic Lampposts & Carved Stone Benches (Phase 2.3 Accent Lighting & Props)
	local accentsFolder = Instance.new("Folder")
	accentsFolder.Name = "CourtyardAccents"
	accentsFolder.Parent = islandModel

	local ironColor = Color3.fromRGB(28, 30, 36)
	local stoneBenchColor = Color3.fromRGB(92, 96, 106)
	local goldAccentColor = Color3.fromRGB(196, 152, 58)

	-- 4 Blender-authored Gothic Medieval Lantern Posts at the corners of the radiating paths
	IslandBuilder.SpawnCourtyardLanterns(accentsFolder, CFrame.identity)

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

-- Spawns the 4 courtyard Gothic Medieval Lantern Posts (overhanging lantern -Z points inward toward the fountain)
function IslandBuilder.SpawnCourtyardLanterns(accentsFolder: Instance, courtyardTopCF: CFrame?)
	GothicLanternSpawner.CleanupLegacyLamps(accentsFolder)
	local origin = courtyardTopCF or CFrame.identity
	local lampAnglesDeg = { -152, -72, 68, 152 }
	local lampRadius = 19.6
	for idx, angDeg in ipairs(lampAnglesDeg) do
		local name = string.format("GothicLantern_%d", idx)
		if accentsFolder:FindFirstChild(name) then
			continue
		end
		local a = math.rad(angDeg)
		local lx = math.sin(a) * lampRadius
		local lz = math.cos(a) * lampRadius
		local baseCF = origin * CFrame.new(lx, 0, lz) * CFrame.Angles(0, a, 0)
		GothicLanternSpawner.Spawn(accentsFolder, baseCF, name)
	end
end

return IslandBuilder
