--!strict
-- WallsBuilder.luau
-- ModuleScript: Builds tall crenellated fortress walls around the island perimeter,
-- with an optional arched front gate facing the Tower (-Z local) and an invisible backup collision barrier.

local WallsBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
WallsBuilder.Config = {
	-- Perimeter Dimensions (Matches IslandBuilder TopWidth / TopLength)
	PerimeterWidth = 148,
	PerimeterLength = 136,

	-- Wall Geometry
	WallHeight = 18, -- Tall enough that standard JumpPower (50) cannot jump over
	WallThickness = 5,
	BastionSize = 9, -- Corner pillar thickness
	BastionHeight = 22,

	-- Crenellations (Merlons on top of the wall)
	MerlonWidth = 6,
	MerlonHeight = 3.5,
	MerlonSpacing = 12,

	-- Front Gate Opening (Facing the Tower, -Z local direction)
	IncludeFrontOpening = true, -- Set true so players have a clear portal/entry archway facing the Tower
	OpeningWidth = 22,
	OpeningArchHeight = 14,
	BlockOpeningWithInvisibleBarrier = true, -- Prevents accidental walk-offs into open sky while keeping the visual gate

	-- Invisible Backup Safety Barrier
	InvisibleBarrierHeight = 42, -- Extends well above the wall top so players can never fall off

	-- Materials & Colors
	WallMaterial = Enum.Material.Brick,
	WallColor = Color3.fromRGB(142, 140, 148),
	TrimMaterial = Enum.Material.Cobblestone,
	TrimColor = Color3.fromRGB(112, 110, 118),
	BastionColor = Color3.fromRGB(122, 120, 128),
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
			Size = Vector3.new(wallThickness + 0.6, cfg.MerlonHeight, cfg.MerlonWidth),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = true, -- Decorative crenellations; main wall + invisible barrier handle collisions
			Parent = parent,
		})
	end
end

--============================================================================
-- BUILDER
--============================================================================
-- Attaches or returns a Folder/Model of fortress walls centered at local Y = 0 (island top surface).
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
			Size = Vector3.new(cfg.BastionSize + 1.5, 2, cfg.BastionSize + 1.5),
			CFrame = CFrame.new(cPos.X, cfg.BastionHeight + 1, cPos.Z),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = true,
			Parent = wallsModel,
		})
	end

	-- 2. Back Wall (+Z), Left Wall (-X), Right Wall (+X)
	makePart({
		Name = "Wall_Back",
		Size = Vector3.new(cfg.PerimeterWidth, cfg.WallHeight, cfg.WallThickness),
		CFrame = CFrame.new(0, wallCenterY, halfL),
		Material = cfg.WallMaterial,
		Color = cfg.WallColor,
		Decorative = false,
		Parent = wallsModel,
	})
	populateMerlonsAlongSpan(
		wallsModel,
		Vector3.new(-halfW + cfg.BastionSize, merlonCenterY, halfL),
		Vector3.new(halfW - cfg.BastionSize, merlonCenterY, halfL),
		cfg.WallThickness,
		cfg
	)

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

	-- 3. Front Wall (-Z, facing the Central Tower)
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
		local lintelHeight = math.max(3, cfg.WallHeight - cfg.OpeningArchHeight)
		makePart({
			Name = "GateLintel",
			Size = Vector3.new(cfg.OpeningWidth + 4, lintelHeight, cfg.WallThickness + 1.5),
			CFrame = CFrame.new(0, cfg.OpeningArchHeight + lintelHeight * 0.5, -halfL),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = false,
			Parent = wallsModel,
		})
		for _, signX in ipairs({ -1, 1 }) do
			makePart({
				Name = signX < 0 and "GatePillar_Left" or "GatePillar_Right",
				Size = Vector3.new(4.5, cfg.WallHeight + 3, cfg.WallThickness + 2.5),
				CFrame = CFrame.new(signX * (cfg.OpeningWidth * 0.5 + 1.5), (cfg.WallHeight + 3) * 0.5, -halfL),
				Material = cfg.TrimMaterial,
				Color = cfg.BastionColor,
				Decorative = false,
				Parent = wallsModel,
			})
		end

		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(-halfW + cfg.BastionSize, merlonCenterY, -halfL),
			Vector3.new(halfW - cfg.BastionSize, merlonCenterY, -halfL),
			cfg.WallThickness,
			cfg
		)
	else
		makePart({
			Name = "Wall_Front",
			Size = Vector3.new(cfg.PerimeterWidth, cfg.WallHeight, cfg.WallThickness),
			CFrame = CFrame.new(0, wallCenterY, -halfL),
			Material = cfg.WallMaterial,
			Color = cfg.WallColor,
			Decorative = false,
			Parent = wallsModel,
		})
		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(-halfW + cfg.BastionSize, merlonCenterY, -halfL),
			Vector3.new(halfW - cfg.BastionSize, merlonCenterY, -halfL),
			cfg.WallThickness,
			cfg
		)
	end

	-- 4. Invisible Backup Collision Barrier along all 4 edges
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "InvisibleEdgeBarriers"
	barrierFolder.Parent = wallsModel

	local bY = cfg.InvisibleBarrierHeight * 0.5
	local barrierDefs = {
		{ Name = "Barrier_Back", Size = Vector3.new(cfg.PerimeterWidth + 4, cfg.InvisibleBarrierHeight, 2), Pos = Vector3.new(0, bY, halfL + 1.5) },
		{ Name = "Barrier_West", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(-halfW - 1.5, bY, 0) },
		{ Name = "Barrier_East", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(halfW + 1.5, bY, 0) },
	}
	if cfg.BlockOpeningWithInvisibleBarrier or not cfg.IncludeFrontOpening then
		table.insert(barrierDefs, {
			Name = "Barrier_Front",
			Size = Vector3.new(cfg.PerimeterWidth + 4, cfg.InvisibleBarrierHeight, 2),
			Pos = Vector3.new(0, bY, -halfL - 1.5),
		})
	end

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
