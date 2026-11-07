--!strict
-- IslandBuilder.luau
-- ModuleScript: Builds a single reusable floating fortress island (flat cobblestone top + jagged tapered rock underside + cloud wisps).
-- All decorative underside parts have CanCollide, CanTouch, and CanQuery disabled for mobile performance.

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

	-- Materials & Colors (Atmospheric Gothic Fortress Palette)
	TopMaterial = Enum.Material.Cobblestone,
	TopColor = Color3.fromRGB(78, 82, 86),
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
-- BUILDER
--============================================================================
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

	-- 1B. Concentric Interlocking Cobblestone Rings, Radial Paths & Gothic Lampposts (Phase 2 Overhaul)
	local pathsFolder = Instance.new("Folder")
	pathsFolder.Name = "CobblestonePaths"
	pathsFolder.Parent = islandModel

	local pathPalette = {
		Color3.fromRGB(76, 80, 86),
		Color3.fromRGB(86, 90, 96),
		Color3.fromRGB(70, 74, 80),
		Color3.fromRGB(80, 84, 90),
	}
	local innerBrickPalette = {
		Color3.fromRGB(88, 84, 82),
		Color3.fromRGB(96, 92, 88),
		Color3.fromRGB(82, 78, 76),
		Color3.fromRGB(92, 88, 84),
	}
	local curbBlockPalette = {
		Color3.fromRGB(102, 104, 110),
		Color3.fromRGB(88, 90, 96),
		Color3.fromRGB(110, 112, 118),
		Color3.fromRGB(94, 96, 102),
		Color3.fromRGB(82, 84, 90),
	}

	local radialBranchAngles = {
		math.atan2(0, -1), -- Bridge (0, -56)
		math.atan2(36, -25.5), -- Summoning Portal
		math.atan2(38, -1.8), -- Blacksmith Forge
		math.atan2(34, 24.3), -- Market
		math.atan2(14, 56), -- Outskirts Gate
		math.atan2(-44, -28), -- Synthesis Chamber
		math.atan2(-25, 19.7), -- Training Grounds
	}

	local function isNearBranchAngle(theta: number): boolean
		for _, bAngle in ipairs(radialBranchAngles) do
			local diff = math.atan2(math.sin(theta - bAngle), math.cos(theta - bAngle))
			if math.abs(diff) < 0.20 then
				return true
			end
		end
		return false
	end

	-- Ring 1: Inner Brick Apron Ring (R = 13.4, Width = 1.8, 32 interlocking brick segments)
	local innerRingR = 13.4
	local innerRingW = 1.8
	local innerSegments = 32
	local curbWidth = 0.72

	for i = 1, innerSegments do
		local a0 = ((i - 1) / innerSegments) * math.pi * 2
		local a1 = (i / innerSegments) * math.pi * 2
		local aMid = (a0 + a1) * 0.5
		local chord = 2 * innerRingR * math.sin((a1 - a0) * 0.5) + 0.22
		local cx = math.sin(aMid) * innerRingR
		local cz = math.cos(aMid) * innerRingR
		local tangentDir = Vector3.new(math.cos(aMid), 0, -math.sin(aMid))
		local segCF = CFrame.lookAt(Vector3.new(cx, 0.13, cz), Vector3.new(cx, 0.13, cz) + tangentDir)

		makePart({
			Name = string.format("InnerBrickRing_Slab_%d", i),
			Size = Vector3.new(innerRingW, 0.26, chord),
			CFrame = segCF,
			Material = Enum.Material.Brick,
			Color = innerBrickPalette[((i - 1) % #innerBrickPalette) + 1],
			Decorative = true,
			Parent = pathsFolder,
		})

		-- Inner raised stone curb hugging the Fountain plinth
		local curbInR = innerRingR - innerRingW * 0.5 - 0.28
		local curbInChord = 2 * curbInR * math.sin((a1 - a0) * 0.5) + 0.14
		local ix = math.sin(aMid) * curbInR
		local iz = math.cos(aMid) * curbInR
		makePart({
			Name = string.format("InnerBrickRing_Curb_%d", i),
			Size = Vector3.new(0.56, 0.34, curbInChord),
			CFrame = CFrame.lookAt(Vector3.new(ix, 0.17, iz), Vector3.new(ix, 0.17, iz) + tangentDir),
			Material = Enum.Material.Pavement,
			Color = curbBlockPalette[((i - 1) % #curbBlockPalette) + 1],
			Decorative = true,
			Parent = pathsFolder,
		})
	end

	-- Ring 2: Outer Concentric Cobblestone Promenade Ring (R = 16.4, Width = 3.4, 28 segments)
	local ringRadius = 16.4
	local ringWidth = 3.4
	local ringSegments = 28

	for i = 1, ringSegments do
		local a0 = ((i - 1) / ringSegments) * math.pi * 2
		local a1 = (i / ringSegments) * math.pi * 2
		local aMid = (a0 + a1) * 0.5
		local chord = 2 * ringRadius * math.sin((a1 - a0) * 0.5) + 0.35
		local cx = math.sin(aMid) * ringRadius
		local cz = math.cos(aMid) * ringRadius
		local tangentDir = Vector3.new(math.cos(aMid), 0, -math.sin(aMid))
		local segCF = CFrame.lookAt(Vector3.new(cx, 0.12, cz), Vector3.new(cx, 0.12, cz) + tangentDir)
		local col = pathPalette[((i - 1) % #pathPalette) + 1]

		makePart({
			Name = string.format("RingRoad_Slab_%d", i),
			Size = Vector3.new(ringWidth, 0.24, chord),
			CFrame = segCF,
			Material = Enum.Material.Cobblestone,
			Color = col,
			Decorative = true,
			Parent = pathsFolder,
		})

		-- Radial stone divider header band
		local divX = math.sin(a1) * ringRadius
		local divZ = math.cos(a1) * ringRadius
		local divTangent = Vector3.new(math.cos(a1), 0, -math.sin(a1))
		makePart({
			Name = string.format("RingRoad_Divider_%d", i),
			Size = Vector3.new(ringWidth - 0.18, 0.26, 0.42),
			CFrame = CFrame.lookAt(Vector3.new(divX, 0.13, divZ), Vector3.new(divX, 0.13, divZ) + divTangent),
			Material = Enum.Material.Pavement,
			Color = Color3.fromRGB(98, 100, 106),
			Decorative = true,
			Parent = pathsFolder,
		})

		-- Mid dividing stone curb between Ring 1 (Inner Brick) and Ring 2 (Outer Cobble)
		local midCurbR = ringRadius - ringWidth * 0.5 - 0.24
		local midChord = 2 * midCurbR * math.sin((a1 - a0) * 0.5) + 0.16
		local mx = math.sin(aMid) * midCurbR
		local mz = math.cos(aMid) * midCurbR
		makePart({
			Name = string.format("RingRoad_CurbInner_%d", i),
			Size = Vector3.new(0.48, 0.30, midChord),
			CFrame = CFrame.lookAt(Vector3.new(mx, 0.15, mz), Vector3.new(mx, 0.15, mz) + tangentDir),
			Material = Enum.Material.Pavement,
			Color = curbBlockPalette[((i - 1) % #curbBlockPalette) + 1],
			Decorative = true,
			Parent = pathsFolder,
		})

		-- Outer curb (skipped where radiating roads branch out so paths merge seamlessly)
		if not isNearBranchAngle(aMid) then
			local outerR = ringRadius + ringWidth * 0.5 + curbWidth * 0.5
			local outerChord = 2 * outerR * math.sin((a1 - a0) * 0.5) + 0.18
			local ox = math.sin(aMid) * outerR
			local oz = math.cos(aMid) * outerR
			makePart({
				Name = string.format("RingRoad_CurbOuter_%d", i),
				Size = Vector3.new(curbWidth, 0.30, outerChord),
				CFrame = CFrame.lookAt(Vector3.new(ox, 0.15, oz), Vector3.new(ox, 0.15, oz) + tangentDir),
				Material = Enum.Material.Pavement,
				Color = curbBlockPalette[((i + 1) % #curbBlockPalette) + 1],
				Decorative = true,
				Parent = pathsFolder,
			})
		end
	end

	local function buildCobblePath(name: string, p0: Vector3, p1: Vector3, width: number, segments: number)
		local dir = p1 - p0
		local totalDist = dir.Magnitude
		if totalDist < 1 then
			return
		end
		local unit = dir.Unit
		local segLen = totalDist / segments
		local lookCF = CFrame.lookAt(Vector3.zero, unit)

		for s = 1, segments do
			local t = (s - 0.5) / segments
			local pos = p0:Lerp(p1, t)
			local col = pathPalette[((s - 1) % #pathPalette) + 1]

			makePart({
				Name = string.format("%s_Slab_%d", name, s),
				Size = Vector3.new(width, 0.24, segLen - 0.18),
				CFrame = CFrame.new(pos.X, 0.12, pos.Z) * lookCF,
				Material = Enum.Material.Cobblestone,
				Color = col,
				Decorative = true,
				Parent = pathsFolder,
			})

			if s < segments then
				local bandPos = p0:Lerp(p1, s / segments)
				makePart({
					Name = string.format("%s_Divider_%d", name, s),
					Size = Vector3.new(width - 0.2, 0.26, 0.45),
					CFrame = CFrame.new(bandPos.X, 0.13, bandPos.Z) * lookCF,
					Material = Enum.Material.Pavement,
					Color = Color3.fromRGB(96, 98, 102),
					Decorative = true,
					Parent = pathsFolder,
				})
			end

			local subBlocks = math.max(2, math.floor(segLen / 3.0))
			local blockLen = segLen / subBlocks
			for b = 1, subBlocks do
				local bt = ((s - 1) + (b - 0.5) / subBlocks) / segments
				local bPos = p0:Lerp(p1, bt)
				for _, side in ipairs({ -1, 1 }) do
					local innerOffset = lookCF.RightVector * (side * (width * 0.5 + curbWidth * 0.5))
					local innerCol = curbBlockPalette[((s + b) % #curbBlockPalette) + 1]
					makePart({
						Name = string.format("%s_Curb_%d_%d_%s", name, s, b, side < 0 and "L" or "R"),
						Size = Vector3.new(curbWidth, 0.30, blockLen * 0.92),
						CFrame = CFrame.new(bPos.X + innerOffset.X, 0.15, bPos.Z + innerOffset.Z) * lookCF,
						Material = Enum.Material.Pavement,
						Color = innerCol,
						Decorative = true,
						Parent = pathsFolder,
					})
				end
			end
		end
	end

	-- Radiating courtyard pathways connecting the Outer Promenade Ring -> Stations & Outskirts Gate
	buildCobblePath("Path_BridgeToFountain", Vector3.new(0, 0, -56), Vector3.new(0, 0, -17.6), 4.6, 5)
	buildCobblePath("Path_FountainToPortal", Vector3.new(14.2, 0, -10.1), Vector3.new(36, 0, -25.5), 4.2, 4)
	buildCobblePath("Path_FountainToForge", Vector3.new(17.6, 0, -0.8), Vector3.new(38, 0, -1.8), 4.2, 4)
	buildCobblePath("Path_FountainToMarket", Vector3.new(14.3, 0, 10.2), Vector3.new(34, 0, 24.3), 4.2, 4)
	buildCobblePath("Path_FountainToGate", Vector3.new(4.2, 0, 17.1), Vector3.new(14, 0, 56), 4.6, 5)
	buildCobblePath("Path_FountainToSynthesis", Vector3.new(-14.8, 0, -9.4), Vector3.new(-22.9, 0, -14.6), 4.2, 3)
	buildCobblePath("Path_FountainToTraining", Vector3.new(-13.8, 0, 10.9), Vector3.new(-25, 0, 19.7), 4.2, 3)

	-- 1C. Courtyard Gothic Lampposts & Carved Stone Benches (Phase 2.3 Accent Lighting & Props)
	local accentsFolder = Instance.new("Folder")
	accentsFolder.Name = "CourtyardAccents"
	accentsFolder.Parent = islandModel

	local ironColor = Color3.fromRGB(28, 30, 36)
	local stoneBenchColor = Color3.fromRGB(92, 96, 106)
	local goldAccentColor = Color3.fromRGB(196, 152, 58)
	local warmFlameColor = Color3.fromRGB(255, 182, 88)
	local warmLightColor = Color3.fromRGB(255, 172, 76)

	-- 4 Gothic Lampposts at the corners of the radiating paths (Brightness 1.5, Range 15)
	local lampAnglesDeg = { -152, -72, 68, 152 }
	local lampRadius = 19.6
	for idx, angDeg in ipairs(lampAnglesDeg) do
		local a = math.rad(angDeg)
		local lx = math.sin(a) * lampRadius
		local lz = math.cos(a) * lampRadius
		local baseCF = CFrame.new(lx, 0, lz) * CFrame.Angles(0, a, 0)

		makePart({
			Name = string.format("Lamppost_Plinth_%d", idx),
			Size = Vector3.new(1.35, 1.2, 1.35),
			CFrame = baseCF * CFrame.new(0, 0.6, 0),
			Material = Enum.Material.Slate,
			Color = stoneBenchColor,
			Decorative = true,
			Parent = accentsFolder,
		})
		makePart({
			Name = string.format("Lamppost_Shaft_%d", idx),
			Size = Vector3.new(0.38, 7.6, 0.38),
			CFrame = baseCF * CFrame.new(0, 5.0, 0),
			Material = Enum.Material.Metal,
			Color = ironColor,
			Decorative = true,
			Parent = accentsFolder,
		})
		makePart({
			Name = string.format("Lamppost_Crossbar_%d", idx),
			Size = Vector3.new(1.15, 0.22, 0.22),
			CFrame = baseCF * CFrame.new(0, 8.6, 0),
			Material = Enum.Material.Metal,
			Color = goldAccentColor,
			Decorative = true,
			Parent = accentsFolder,
		})
		makePart({
			Name = string.format("Lamppost_CageCap_%d", idx),
			Size = Vector3.new(1.1, 0.35, 1.1),
			CFrame = baseCF * CFrame.new(0, 10.15, 0),
			Material = Enum.Material.Metal,
			Color = ironColor,
			Decorative = true,
			Parent = accentsFolder,
		})
		local lanternGlass = makePart({
			Name = string.format("Lamppost_Lantern_%d", idx),
			Size = Vector3.new(0.76, 1.15, 0.76),
			CFrame = baseCF * CFrame.new(0, 9.4, 0),
			Material = Enum.Material.Neon,
			Color = warmFlameColor,
			Transparency = 0.18,
			Decorative = true,
			Parent = accentsFolder,
		})
		local lampLight = Instance.new("PointLight")
		lampLight.Name = "WarmCourtyardLampLight"
		lampLight.Color = warmLightColor
		lampLight.Brightness = 1.5
		lampLight.Range = 15
		lampLight.Shadows = false
		lampLight.Parent = lanternGlass
	end

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

return IslandBuilder
