--!strict
-- IslandBuilder.luau
-- ModuleScript: Builds a single reusable floating fortress island (flat cobblestone top + jagged tapered rock underside + cloud wisps).
-- All decorative underside parts have CanCollide, CanTouch, and CanQuery disabled for mobile performance.

local IslandBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
IslandBuilder.Config = {
	-- Top Buildable Surface Dimensions (Citadel Courtyard: 260 x 180 studs; Outskirts: 260 x 140 studs)
	TopWidth = 260, -- X dimension (studs)
	TopLength = 180, -- Courtyard walking surface Z dimension (studs) [-90, +90]
	CitadelLength = 180, -- Z dimension of cobblestone Courtyard (studs) [-90, +90]
	TotalLength = 320, -- Full island footprint [-90, +230] supporting rocky underside
	TopThickness = 6, -- Thickness of the top stone slab (studs)
	CenterOffsetZ = 70, -- Midpoint between Citadel [-90, +90] and Outskirts [+90, +230]
	chamferSize = 22, -- Corner bevel size to give a fortress silhouette

	-- Underside Rock Formation
	UndersideDepth = 135, -- Total depth of the tapered rocky mass below the top slab
	UndersideLayers = 6, -- Number of stepped rock tiers tapering inward
	OuterSpireCount = 20, -- Jagged rock spires around the upper/mid underside perimeter
	InnerStalactiteCount = 12, -- Deep jagged rock points tapering toward the bottom tip
	RandomSeed = 4042026, -- Fixed seed so all 6 cloned islands have identical geometry

	-- Materials & Colors (Atmospheric Gothic Fortress Palette)
	TopMaterial = Enum.Material.Slate,
	TopColor = Color3.fromRGB(70, 74, 80),
	RimMaterial = Enum.Material.Slate,
	RimColor = Color3.fromRGB(58, 62, 68),
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

--============================================================================
-- HELPER FUNCTIONS
--============================================================================
local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local isDecorative = props.Decorative == true
	if isDecorative then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
	else
		p.CanCollide = true
		p.CanTouch = true
		p.CanQuery = true
	end
	for k, v in pairs(props) do
		if k ~= "Decorative" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function makeWedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	local isDecorative = props.Decorative == true
	if isDecorative then
		w.CanCollide = false
		w.CanTouch = false
		w.CanQuery = false
		w.CastShadow = false
	else
		w.CanCollide = true
		w.CanTouch = true
		w.CanQuery = true
	end
	for k, v in pairs(props) do
		if k ~= "Decorative" and k ~= "Parent" then
			(w :: any)[k] = v
		end
	end
	w.Parent = props.Parent
	return w
end

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

	local centerZ = cfg.CenterOffsetZ or 70
	local courtyardL = cfg.CitadelLength or cfg.TopLength or 180
	local totalL = cfg.TotalLength or 320

	-- Invisible Island Anchor at geometric center of entire island mass (centerZ = 70)
	-- Serves as PrimaryPart so pivoting to RingRadius R=650 places courtyard at R=580 and outskirts at R=740
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

	-- 1B. Raised Modular Cobblestone Path Network (Thickness = 0.25 studs, varied grey-brown hues)
	local pathsFolder = Instance.new("Folder")
	pathsFolder.Name = "CobblestonePaths"
	pathsFolder.Parent = islandModel

	local pathPalette = {
		Color3.fromRGB(98, 95, 90),
		Color3.fromRGB(84, 82, 78),
		Color3.fromRGB(110, 105, 98),
		Color3.fromRGB(91, 88, 84),
	}
	local curbColor = Color3.fromRGB(58, 60, 66)

	-- Central Fountain Plaza Cobblestone Ring
	local plazaBase = Instance.new("Part")
	plazaBase.Shape = Enum.PartType.Cylinder
	plazaBase.Name = "FountainPlazaCobble"
	plazaBase.Size = Vector3.new(0.25, 44, 44)
	plazaBase.CFrame = CFrame.new(0, 0.125, 0) * CFrame.Angles(0, 0, math.rad(90))
	plazaBase.Anchored = true
	plazaBase.CanCollide = false
	plazaBase.CanTouch = false
	plazaBase.CanQuery = false
	plazaBase.CastShadow = false
	plazaBase.Material = Enum.Material.Cobblestone
	plazaBase.Color = Color3.fromRGB(96, 93, 88)
	plazaBase.Parent = pathsFolder

	local plazaRim = Instance.new("Part")
	plazaRim.Shape = Enum.PartType.Cylinder
	plazaRim.Name = "FountainPlazaCurb"
	plazaRim.Size = Vector3.new(0.20, 47, 47)
	plazaRim.CFrame = CFrame.new(0, 0.10, 0) * CFrame.Angles(0, 0, math.rad(90))
	plazaRim.Anchored = true
	plazaRim.CanCollide = false
	plazaRim.CanTouch = false
	plazaRim.CanQuery = false
	plazaRim.CastShadow = false
	plazaRim.Material = Enum.Material.Slate
	plazaRim.Color = curbColor
	plazaRim.Parent = pathsFolder

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
			local jitterW = width + ((s % 2 == 0) and 0.6 or -0.4)
			local col = pathPalette[((s - 1) % #pathPalette) + 1]

			makePart({
				Name = string.format("%s_Slab_%d", name, s),
				Size = Vector3.new(jitterW, 0.25, segLen + 0.5),
				CFrame = CFrame.new(pos.X, 0.125, pos.Z) * lookCF,
				Material = Enum.Material.Cobblestone,
				Color = col,
				Decorative = true,
				Parent = pathsFolder,
			})

			-- Curb stones along left & right edges
			for _, side in ipairs({ -1, 1 }) do
				local curbOffset = lookCF.RightVector * (side * (jitterW * 0.5 + 0.6))
				makePart({
					Name = string.format("%s_Curb_%d_%s", name, s, side < 0 and "L" or "R"),
					Size = Vector3.new(1.1, 0.28, segLen * 0.92),
					CFrame = CFrame.new(pos.X + curbOffset.X, 0.14, pos.Z + curbOffset.Z) * lookCF,
					Material = Enum.Material.Slate,
					Color = curbColor,
					Decorative = true,
					Parent = pathsFolder,
				})
			end
		end
	end

	-- Radiating courtyard pathways connecting Bridge -> Fountain -> Stations & Outskirts Gate
	buildCobblePath("Path_BridgeToFountain", Vector3.new(0, 0, -88), Vector3.new(0, 0, -18), 14, 7)
	buildCobblePath("Path_FountainToPortal", Vector3.new(14, 0, -12), Vector3.new(74, 0, -48), 11, 6)
	buildCobblePath("Path_FountainToMarket", Vector3.new(14, 0, 12), Vector3.new(70, 0, 42), 11, 6)
	buildCobblePath("Path_FountainToGate", Vector3.new(6, 0, 18), Vector3.new(32, 0, 88), 12, 7)
	buildCobblePath("Path_FountainToSynthesis", Vector3.new(-14, 0, -10), Vector3.new(-62, 0, -32), 11, 6)
	buildCobblePath("Path_FountainToTraining", Vector3.new(-14, 0, 12), Vector3.new(-54, 0, 42), 11, 5)

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
			CFrame = CFrame.new(0, currentY - layerHeight * 0.5, centerZ) * CFrame.Angles(0, yawJitter, 0),
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
		local pz = centerZ + math.sin(angle) * rz
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
		local pz = centerZ + math.sin(angle) * radius
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
		CFrame = CFrame.new(0, -cfg.UndersideDepth + 12, centerZ) * CFrame.Angles(math.rad(180), math.rad(45), 0),
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
			CFrame = CFrame.new(0, -cfg.TopThickness - 22, centerZ),
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
