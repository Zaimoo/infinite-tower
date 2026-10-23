--!strict
-- WallsBuilder.luau
-- ModuleScript: Builds 28-stud high crenellated fortress walls around the Grand Citadel Courtyard (260 x 180 studs).
-- Features:
--   1. North Gatehouse facing the Drawbridge and Tower (-Z)
--   2. South Vaulted Gatehouse archway opening into the Rear Outskirts (+Z)
--   3. Corner Bastions and Merlons
-- Implements GDD Section 3.4.

local WallsBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
WallsBuilder.Config = {
	-- Perimeter Dimensions (Grand Citadel & Courtyard: 260 x 180 studs)
	PerimeterWidth = 260,
	PerimeterLength = 180,

	-- Wall Geometry (GDD Section 3.4: 28-stud high crenellated stone walls)
	WallHeight = 28,
	WallThickness = 6,
	BastionSize = 12,
	BastionHeight = 34,

	-- Crenellations (Merlons on top of the wall)
	MerlonWidth = 6,
	MerlonHeight = 4.0,
	MerlonSpacing = 12,

	-- Front Gate Opening (Facing the Tower, -Z local direction)
	IncludeFrontOpening = true,
	OpeningWidth = 24,
	OpeningArchHeight = 18,
	BlockOpeningWithInvisibleBarrier = false, -- Non-collidable so players walk across bridge into fortress

	-- Rear Gate Opening (Facing the Outskirts, +Z local direction)
	IncludeRearOpening = true,
	RearOpeningWidth = 24,
	RearOpeningArchHeight = 18,

	-- Invisible Backup Safety Barrier
	InvisibleBarrierHeight = 48,

	-- Materials & Colors
	WallMaterial = Enum.Material.Brick,
	WallColor = Color3.fromRGB(135, 133, 140),
	TrimMaterial = Enum.Material.Cobblestone,
	TrimColor = Color3.fromRGB(105, 103, 110),
	BastionColor = Color3.fromRGB(115, 113, 120),
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
		p.CanTouch = false
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

local function populateMerlonsAlongSpan(
	parent: Instance,
	startPos: Vector3,
	endPos: Vector3,
	wallThickness: number,
	cfg: typeof(WallsBuilder.Config)
)
	local delta = endPos - startPos
	local length = delta.Magnitude
	if length < cfg.MerlonWidth then
		return
	end
	local dir = delta.Unit
	local yaw = math.atan2(-dir.X, -dir.Z)
	local count = math.max(1, math.floor(length / cfg.MerlonSpacing))
	for i = 1, count do
		local alpha = (i - 0.5) / count
		local pos = startPos:Lerp(endPos, alpha)
		makePart({
			Name = "WallMerlon",
			Size = Vector3.new(wallThickness + 0.8, cfg.MerlonHeight, cfg.MerlonWidth),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = true,
			Parent = parent,
		})
	end
end

--============================================================================
-- BUILDER
--============================================================================
function WallsBuilder.Build(parentIsland: Instance?, customConfig: { [string]: any }?): Model
	local cfg = table.clone(WallsBuilder.Config)
	if customConfig then
		for k, v in pairs(customConfig) do
			(cfg :: any)[k] = v
		end
	end

	local wallsModel = Instance.new("Model")
	wallsModel.Name = "FortressWalls"

	local halfW = cfg.PerimeterWidth * 0.5 - (cfg.WallThickness * 0.5)
	local halfL = cfg.PerimeterLength * 0.5 - (cfg.WallThickness * 0.5)
	local wallCenterY = cfg.WallHeight * 0.5
	local merlonCenterY = cfg.WallHeight + (cfg.MerlonHeight * 0.5)

	-- 1. Four Corner Bastion Towers
	local corners = {
		Vector3.new(-halfW, 0, -halfL),
		Vector3.new(halfW, 0, -halfL),
		Vector3.new(-halfW, 0, halfL),
		Vector3.new(halfW, 0, halfL),
	}
	for i, cPos in ipairs(corners) do
		makePart({
			Name = string.format("CornerBastion_%d", i),
			Size = Vector3.new(cfg.BastionSize, cfg.BastionHeight, cfg.BastionSize),
			CFrame = CFrame.new(cPos.X, cfg.BastionHeight * 0.5, cPos.Z),
			Material = cfg.TrimMaterial,
			Color = cfg.BastionColor,
			Decorative = false,
			Parent = wallsModel,
		})
		makePart({
			Name = string.format("CornerBastionCap_%d", i),
			Size = Vector3.new(cfg.BastionSize + 2, 2.5, cfg.BastionSize + 2),
			CFrame = CFrame.new(cPos.X, cfg.BastionHeight + 1.25, cPos.Z),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = true,
			Parent = wallsModel,
		})
	end

	-- 2. Left Wall (-X) and Right Wall (+X)
	makePart({
		Name = "Wall_West",
		Size = Vector3.new(cfg.WallThickness, cfg.WallHeight, cfg.PerimeterLength),
		CFrame = CFrame.new(-halfW, wallCenterY, 0),
		Material = cfg.WallMaterial,
		Color = cfg.WallColor,
		Decorative = false,
		Parent = wallsModel,
	})
	populateMerlonsAlongSpan(
		wallsModel,
		Vector3.new(-halfW, merlonCenterY, -halfL + cfg.BastionSize),
		Vector3.new(-halfW, merlonCenterY, halfL - cfg.BastionSize),
		cfg.WallThickness,
		cfg
	)

	makePart({
		Name = "Wall_East",
		Size = Vector3.new(cfg.WallThickness, cfg.WallHeight, cfg.PerimeterLength),
		CFrame = CFrame.new(halfW, wallCenterY, 0),
		Material = cfg.WallMaterial,
		Color = cfg.WallColor,
		Decorative = false,
		Parent = wallsModel,
	})
	populateMerlonsAlongSpan(
		wallsModel,
		Vector3.new(halfW, merlonCenterY, -halfL + cfg.BastionSize),
		Vector3.new(halfW, merlonCenterY, halfL - cfg.BastionSize),
		cfg.WallThickness,
		cfg
	)

	-- 3. Front Wall (-Z, facing the Central Tower and Drawbridge)
	if cfg.IncludeFrontOpening then
		local sideSpan = (cfg.PerimeterWidth - cfg.OpeningWidth) * 0.5
		local leftCenterX = -(cfg.OpeningWidth * 0.5 + sideSpan * 0.5)
		local rightCenterX = (cfg.OpeningWidth * 0.5 + sideSpan * 0.5)

		makePart({
			Name = "Wall_FrontLeft",
			Size = Vector3.new(sideSpan, cfg.WallHeight, cfg.WallThickness),
			CFrame = CFrame.new(leftCenterX, wallCenterY, -halfL),
			Material = cfg.WallMaterial,
			Color = cfg.WallColor,
			Decorative = false,
			Parent = wallsModel,
		})
		makePart({
			Name = "Wall_FrontRight",
			Size = Vector3.new(sideSpan, cfg.WallHeight, cfg.WallThickness),
			CFrame = CFrame.new(rightCenterX, wallCenterY, -halfL),
			Material = cfg.WallMaterial,
			Color = cfg.WallColor,
			Decorative = false,
			Parent = wallsModel,
		})

		-- Gate Pillars & Upper Arch Lintel
		local lintelHeight = math.max(4, cfg.WallHeight - cfg.OpeningArchHeight)
		makePart({
			Name = "GateLintel",
			Size = Vector3.new(cfg.OpeningWidth + 4, lintelHeight, cfg.WallThickness + 2),
			CFrame = CFrame.new(0, cfg.OpeningArchHeight + lintelHeight * 0.5, -halfL),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = false,
			Parent = wallsModel,
		})
		for _, signX in ipairs({ -1, 1 }) do
			makePart({
				Name = signX < 0 and "GatePillar_Left" or "GatePillar_Right",
				Size = Vector3.new(5.0, cfg.WallHeight + 4, cfg.WallThickness + 3.0),
				CFrame = CFrame.new(signX * (cfg.OpeningWidth * 0.5 + 2.0), (cfg.WallHeight + 4) * 0.5, -halfL),
				Material = cfg.TrimMaterial,
				Color = cfg.BastionColor,
				Decorative = false,
				Parent = wallsModel,
			})
		end

		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(-halfW + cfg.BastionSize, merlonCenterY, -halfL),
			Vector3.new(-cfg.OpeningWidth * 0.5, merlonCenterY, -halfL),
			cfg.WallThickness,
			cfg
		)
		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(cfg.OpeningWidth * 0.5, merlonCenterY, -halfL),
			Vector3.new(halfW - cfg.BastionSize, merlonCenterY, -halfL),
			cfg.WallThickness,
			cfg
		)
	end

	-- 4. Rear Wall (+Z, facing the Southern Outskirts)
	if cfg.IncludeRearOpening then
		local rearSpan = (cfg.PerimeterWidth - cfg.RearOpeningWidth) * 0.5
		local leftCenterX = -(cfg.RearOpeningWidth * 0.5 + rearSpan * 0.5)
		local rightCenterX = (cfg.RearOpeningWidth * 0.5 + rearSpan * 0.5)

		makePart({
			Name = "Wall_BackLeft",
			Size = Vector3.new(rearSpan, cfg.WallHeight, cfg.WallThickness),
			CFrame = CFrame.new(leftCenterX, wallCenterY, halfL),
			Material = cfg.WallMaterial,
			Color = cfg.WallColor,
			Decorative = false,
			Parent = wallsModel,
		})
		makePart({
			Name = "Wall_BackRight",
			Size = Vector3.new(rearSpan, cfg.WallHeight, cfg.WallThickness),
			CFrame = CFrame.new(rightCenterX, wallCenterY, halfL),
			Material = cfg.WallMaterial,
			Color = cfg.WallColor,
			Decorative = false,
			Parent = wallsModel,
		})

		-- Vaulted Rear Archway Lintel
		local lintelHeight = math.max(4, cfg.WallHeight - cfg.RearOpeningArchHeight)
		makePart({
			Name = "RearGateLintel",
			Size = Vector3.new(cfg.RearOpeningWidth + 4, lintelHeight, cfg.WallThickness + 2),
			CFrame = CFrame.new(0, cfg.RearOpeningArchHeight + lintelHeight * 0.5, halfL),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = false,
			Parent = wallsModel,
		})
		for _, signX in ipairs({ -1, 1 }) do
			makePart({
				Name = signX < 0 and "RearGatePillar_Left" or "RearGatePillar_Right",
				Size = Vector3.new(5.0, cfg.WallHeight + 4, cfg.WallThickness + 3.0),
				CFrame = CFrame.new(signX * (cfg.RearOpeningWidth * 0.5 + 2.0), (cfg.WallHeight + 4) * 0.5, halfL),
				Material = cfg.TrimMaterial,
				Color = cfg.BastionColor,
				Decorative = false,
				Parent = wallsModel,
			})
		end

		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(-halfW + cfg.BastionSize, merlonCenterY, halfL),
			Vector3.new(-cfg.RearOpeningWidth * 0.5, merlonCenterY, halfL),
			cfg.WallThickness,
			cfg
		)
		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(cfg.RearOpeningWidth * 0.5, merlonCenterY, halfL),
			Vector3.new(halfW - cfg.BastionSize, merlonCenterY, halfL),
			cfg.WallThickness,
			cfg
		)
	end

	-- 5. Invisible Backup Collision Barriers
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "InvisibleEdgeBarriers"
	barrierFolder.Parent = wallsModel

	local bY = cfg.InvisibleBarrierHeight * 0.5
	local rearSpan = (cfg.PerimeterWidth - cfg.RearOpeningWidth) * 0.5
	local leftRearX = -(cfg.RearOpeningWidth * 0.5 + rearSpan * 0.5)
	local rightRearX = (cfg.RearOpeningWidth * 0.5 + rearSpan * 0.5)

	local barrierDefs = {
		{ Name = "Barrier_West", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(-halfW - 1.5, bY, 0) },
		{ Name = "Barrier_East", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(halfW + 1.5, bY, 0) },
		-- Rear barriers flanking the central archway
		{ Name = "Barrier_BackLeft", Size = Vector3.new(rearSpan, cfg.InvisibleBarrierHeight, 2), Pos = Vector3.new(leftRearX, bY, halfL + 1.5) },
		{ Name = "Barrier_BackRight", Size = Vector3.new(rearSpan, cfg.InvisibleBarrierHeight, 2), Pos = Vector3.new(rightRearX, bY, halfL + 1.5) },
	}

	for _, b in ipairs(barrierDefs) do
		makePart({
			Name = b.Name,
			Size = b.Size,
			CFrame = CFrame.new(b.Pos),
			Transparency = 1,
			CastShadow = false,
			Decorative = false,
			Parent = barrierFolder,
		})
	end

	if parentIsland then
		wallsModel.Parent = parentIsland
	end

	return wallsModel
end

return WallsBuilder
