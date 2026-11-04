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
	BastionSize = 22,
	BastionHeight = 40,

	-- Crenellations (Merlons on top of the wall)
	MerlonWidth = 6.2,
	MerlonHeight = 4.2,
	MerlonSpacing = 12,

	-- Front Gate Opening (Facing the Tower, -Z local direction)
	IncludeFrontOpening = true,
	OpeningWidth = 24,
	OpeningArchHeight = 18,
	BlockOpeningWithInvisibleBarrier = false, -- Non-collidable so players walk across bridge into fortress

	-- Rear Gate Opening (Facing the Outskirts, +Z local direction, positioned between Market & Forge)
	IncludeRearOpening = true,
	RearGateCenterX = 32,
	RearOpeningWidth = 24,
	RearOpeningArchHeight = 18,

	-- Invisible Backup Safety Barrier
	InvisibleBarrierHeight = 48,

	-- Materials & Colors (Dark Gothic Castle Masonry matching reference)
	WallMaterial = Enum.Material.Slate,
	WallColor = Color3.fromRGB(68, 72, 78),
	TrimMaterial = Enum.Material.Slate,
	TrimColor = Color3.fromRGB(54, 58, 64),
	BastionColor = Color3.fromRGB(62, 66, 72),
	PlinthColor = Color3.fromRGB(48, 52, 58),
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
		makePart({
			Name = "WallMerlonCap",
			Size = Vector3.new(wallThickness + 1.3, 0.75, cfg.MerlonWidth + 0.5),
			CFrame = CFrame.new(pos + Vector3.new(0, cfg.MerlonHeight * 0.5 + 0.35, 0)) * CFrame.Angles(0, yaw, 0),
			Material = cfg.TrimMaterial,
			Color = Color3.fromRGB(82, 86, 92),
			Decorative = true,
			Parent = parent,
		})
	end
end

local function populateAshlarWallFace(
	parent: Instance,
	namePrefix: string,
	centerPos: Vector3,
	spanLen: number,
	wallHeight: number,
	wallThickness: number,
	alongZ: boolean
)
	local blockPal = {
		Color3.fromRGB(74, 78, 84),
		Color3.fromRGB(62, 66, 72),
		Color3.fromRGB(82, 86, 92),
		Color3.fromRGB(56, 60, 66),
		Color3.fromRGB(68, 72, 78),
	}
	local rows = 6
	local startY = 4.2
	local availH = wallHeight - 6.6
	local rowH = availH / rows
	local targetBlockLen = 10.5
	local cols = math.max(2, math.floor(spanLen / targetBlockLen))
	local blockLen = spanLen / cols

	for r = 1, rows do
		local cy = startY + (r - 0.5) * rowH
		local stagger = (r % 2 == 0) and (blockLen * 0.35) or 0
		for c = 1, cols do
			local localOffset = -spanLen * 0.5 + (c - 0.5) * blockLen + stagger
			local bLen = blockLen - 0.35
			if localOffset + bLen * 0.5 > spanLen * 0.5 then
				bLen = (spanLen * 0.5 - (localOffset - bLen * 0.5)) - 0.2
				localOffset = spanLen * 0.5 - bLen * 0.5 - 0.1
			end
			if bLen > 1.8 then
				local col = blockPal[((r * 3 + c * 5) % #blockPal) + 1]
				local bSize = if alongZ
					then Vector3.new(wallThickness + 0.45, rowH - 0.28, bLen)
					else Vector3.new(bLen, rowH - 0.28, wallThickness + 0.45)
				local bPos = if alongZ
					then Vector3.new(centerPos.X, cy, centerPos.Z + localOffset)
					else Vector3.new(centerPos.X + localOffset, cy, centerPos.Z)
				makePart({
					Name = string.format("%s_Ashlar_%d_%d", namePrefix, r, c),
					Size = bSize,
					CFrame = CFrame.new(bPos),
					Material = Enum.Material.Slate,
					Color = col,
					Decorative = true,
					Parent = parent,
				})
			end
		end
	end

	-- Horizontal mid-height ashlar stringcourse molding
	local bandSize = if alongZ
		then Vector3.new(wallThickness + 1.0, 0.9, spanLen)
		else Vector3.new(spanLen, 0.9, wallThickness + 1.0)
	makePart({
		Name = namePrefix .. "_Stringcourse",
		Size = bandSize,
		CFrame = CFrame.new(centerPos.X, 15.0, centerPos.Z),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(84, 88, 94),
		Decorative = true,
		Parent = parent,
	})
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
			Material = cfg.WallMaterial,
			Color = cfg.BastionColor,
			Decorative = false,
			Parent = wallsModel,
		})
		-- Coursed Ashlar Stone Rings on Corner Bastion Tower
		local bRingPal = {
			Color3.fromRGB(74, 78, 84),
			Color3.fromRGB(60, 64, 70),
			Color3.fromRGB(82, 86, 92),
			Color3.fromRGB(54, 58, 64),
		}
		for ring = 1, 7 do
			local ry = 4.8 + (ring - 0.5) * 4.4
			local rExpand = (ring % 2 == 1) and 0.45 or 0.15
			makePart({
				Name = string.format("CornerBastionCourse_%d_%d", i, ring),
				Size = Vector3.new(cfg.BastionSize + rExpand, 4.1, cfg.BastionSize + rExpand),
				CFrame = CFrame.new(cPos.X, ry, cPos.Z),
				Material = Enum.Material.Slate,
				Color = bRingPal[((ring + i) % #bRingPal) + 1],
				Decorative = true,
				Parent = wallsModel,
			})
		end
		-- Gothic Slit Windows on Bastion Tower Upper Faces
		for _, faceDir in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }) do
			local slitPos = Vector3.new(cPos.X, 26.5, cPos.Z) + faceDir * (cfg.BastionSize * 0.5 + 0.25)
			local slitSize = if math.abs(faceDir.X) > 0.5
				then Vector3.new(0.4, 5.2, 1.8)
				else Vector3.new(1.8, 5.2, 0.4)
			makePart({
				Name = string.format("BastionSlitWindow_%d", i),
				Size = slitSize,
				CFrame = CFrame.new(slitPos),
				Material = Enum.Material.Slate,
				Color = Color3.fromRGB(24, 26, 30),
				Decorative = true,
				Parent = wallsModel,
			})
		end
		makePart({
			Name = string.format("CornerBastionPlinth_%d", i),
			Size = Vector3.new(cfg.BastionSize + 3.2, 5.2, cfg.BastionSize + 3.2),
			CFrame = CFrame.new(cPos.X, 2.6, cPos.Z),
			Material = cfg.TrimMaterial,
			Color = cfg.PlinthColor or cfg.TrimColor,
			Decorative = true,
			Parent = wallsModel,
		})
		makePart({
			Name = string.format("CornerBastionMidBelt_%d", i),
			Size = Vector3.new(cfg.BastionSize + 1.6, 1.2, cfg.BastionSize + 1.6),
			CFrame = CFrame.new(cPos.X, 21.0, cPos.Z),
			Material = cfg.TrimMaterial,
			Color = Color3.fromRGB(84, 88, 94),
			Decorative = true,
			Parent = wallsModel,
		})
		makePart({
			Name = string.format("CornerBastionCorbel_%d", i),
			Size = Vector3.new(cfg.BastionSize + 1.8, 1.8, cfg.BastionSize + 1.8),
			CFrame = CFrame.new(cPos.X, cfg.BastionHeight - 0.9, cPos.Z),
			Material = cfg.TrimMaterial,
			Color = cfg.PlinthColor or cfg.TrimColor,
			Decorative = true,
			Parent = wallsModel,
		})
		makePart({
			Name = string.format("CornerBastionCap_%d", i),
			Size = Vector3.new(cfg.BastionSize + 3.0, 2.6, cfg.BastionSize + 3.0),
			CFrame = CFrame.new(cPos.X, cfg.BastionHeight + 1.3, cPos.Z),
			Material = cfg.TrimMaterial,
			Color = Color3.fromRGB(78, 82, 88),
			Decorative = true,
			Parent = wallsModel,
		})
		-- 12 Battlement Merlons crowning each Corner Bastion Tower (4 Corner L-Merlons + 8 Side Merlons)
		local bHalf = (cfg.BastionSize + 1.6) * 0.5
		local bMerlonY = cfg.BastionHeight + 2.6 + 2.1
		for _, mOff in ipairs({
			{ dx = -bHalf, dz = -bHalf, sx = 3.6, sz = 3.6 },
			{ dx = -bHalf, dz =  bHalf, sx = 3.6, sz = 3.6 },
			{ dx =  bHalf, dz = -bHalf, sx = 3.6, sz = 3.6 },
			{ dx =  bHalf, dz =  bHalf, sx = 3.6, sz = 3.6 },
			{ dx = -bHalf, dz =  0,     sx = 3.2, sz = 4.6 },
			{ dx =  bHalf, dz =  0,     sx = 3.2, sz = 4.6 },
			{ dx =  0,     dz = -bHalf, sx = 4.6, sz = 3.2 },
			{ dx =  0,     dz =  bHalf, sx = 4.6, sz = 3.2 },
		}) do
			makePart({
				Name = string.format("BastionMerlon_%d", i),
				Size = Vector3.new(mOff.sx, 4.2, mOff.sz),
				CFrame = CFrame.new(cPos.X + mOff.dx, bMerlonY, cPos.Z + mOff.dz),
				Material = cfg.TrimMaterial,
				Color = cfg.TrimColor,
				Decorative = true,
				Parent = wallsModel,
			})
			makePart({
				Name = string.format("BastionMerlonCap_%d", i),
				Size = Vector3.new(mOff.sx + 0.5, 0.7, mOff.sz + 0.5),
				CFrame = CFrame.new(cPos.X + mOff.dx, bMerlonY + 2.4, cPos.Z + mOff.dz),
				Material = cfg.TrimMaterial,
				Color = Color3.fromRGB(84, 88, 94),
				Decorative = true,
				Parent = wallsModel,
			})
		end
	end

	-- 2. Left Wall (-X) and Right Wall (+X) with Base Plinth, Coursed Ashlar Blocks, Overhang Cornice & Merlons
	for _, side in ipairs({ { Name = "West", X = -halfW, NormalX = 1 }, { Name = "East", X = halfW, NormalX = -1 } }) do
		makePart({
			Name = "Wall_" .. side.Name,
			Size = Vector3.new(cfg.WallThickness, cfg.WallHeight, cfg.PerimeterLength),
			CFrame = CFrame.new(side.X, wallCenterY, 0),
			Material = cfg.WallMaterial,
			Color = cfg.WallColor,
			Decorative = false,
			Parent = wallsModel,
		})
		populateAshlarWallFace(
			wallsModel,
			"Wall_" .. side.Name,
			Vector3.new(side.X, wallCenterY, 0),
			cfg.PerimeterLength - cfg.BastionSize * 1.6,
			cfg.WallHeight,
			cfg.WallThickness,
			true
		)
		makePart({
			Name = "Plinth_" .. side.Name,
			Size = Vector3.new(cfg.WallThickness + 2.6, 4.2, cfg.PerimeterLength),
			CFrame = CFrame.new(side.X, 2.1, 0),
			Material = cfg.TrimMaterial,
			Color = cfg.PlinthColor or cfg.TrimColor,
			Decorative = true,
			Parent = wallsModel,
		})
		makePart({
			Name = "Cornice_" .. side.Name,
			Size = Vector3.new(cfg.WallThickness + 2.2, 2.2, cfg.PerimeterLength),
			CFrame = CFrame.new(side.X, cfg.WallHeight - 1.1, 0),
			Material = cfg.TrimMaterial,
			Color = Color3.fromRGB(78, 82, 88),
			Decorative = true,
			Parent = wallsModel,
		})
		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(side.X, merlonCenterY, -halfL + cfg.BastionSize),
			Vector3.new(side.X, merlonCenterY, halfL - cfg.BastionSize),
			cfg.WallThickness,
			cfg
		)
	end

	-- Helper for Wall Torches & Medieval Banners
	local function addWallTorch(name: string, pos: Vector3, normalDir: Vector3)
		local bracket = makePart({
			Name = name .. "_Bracket",
			Size = Vector3.new(0.6, 2.4, 0.6),
			CFrame = CFrame.new(pos + normalDir * 0.8) * CFrame.Angles(math.rad(22), 0, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(36, 38, 44),
			Decorative = true,
			Parent = wallsModel,
		})
		local flame = makePart({
			Name = name .. "_Flame",
			Size = Vector3.new(0.9, 1.3, 0.9),
			CFrame = bracket.CFrame * CFrame.new(0, 1.4, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 165, 60),
			Decorative = true,
			Parent = wallsModel,
		})
		local pt = Instance.new("PointLight")
		pt.Color = Color3.fromRGB(255, 168, 72)
		pt.Brightness = 2.2
		pt.Range = 22
		pt.Shadows = false
		pt.Parent = flame

		local fireEmit = Instance.new("ParticleEmitter")
		fireEmit.Texture = "rbxassetid://243660364"
		fireEmit.Color = ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(235, 85, 25))
		fireEmit.LightEmission = 0.9
		fireEmit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		fireEmit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		fireEmit.Lifetime = NumberRange.new(0.4, 0.7)
		fireEmit.Rate = 10
		fireEmit.Speed = NumberRange.new(2, 4)
		fireEmit.Acceleration = Vector3.new(0, 6, 0)
		fireEmit.Parent = flame
	end

	local function addWallBanner(name: string, pos: Vector3)
		-- Horizontal Gold Rod
		makePart({
			Name = name .. "_Rod",
			Size = Vector3.new(4.6, 0.4, 0.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 5.2, -0.35)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(230, 185, 65),
			Decorative = true,
			Parent = wallsModel,
		})
		-- Crimson Fabric Drape
		makePart({
			Name = name .. "_Cloth",
			Size = Vector3.new(3.8, 10.0, 0.25),
			CFrame = CFrame.new(pos + Vector3.new(0, 0, -0.25)),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(148, 28, 32),
			Decorative = true,
			Parent = wallsModel,
		})
		-- Gold Crest Trim
		makePart({
			Name = name .. "_GoldBorder",
			Size = Vector3.new(2.2, 7.6, 0.30),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.2, -0.28)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(250, 204, 21),
			Decorative = true,
			Parent = wallsModel,
		})
		makePart({
			Name = name .. "_InnerField",
			Size = Vector3.new(1.6, 7.0, 0.34),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.2, -0.30)),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(120, 22, 26),
			Decorative = true,
			Parent = wallsModel,
		})
	end

	-- 3. Front Wall (-Z, facing the Central Tower and Drawbridge)
	if cfg.IncludeFrontOpening then
		local sideSpan = (cfg.PerimeterWidth - cfg.OpeningWidth) * 0.5
		local leftCenterX = -(cfg.OpeningWidth * 0.5 + sideSpan * 0.5)
		local rightCenterX = (cfg.OpeningWidth * 0.5 + sideSpan * 0.5)

		for _, seg in ipairs({
			{ Name = "FrontLeft", X = leftCenterX, Span = sideSpan },
			{ Name = "FrontRight", X = rightCenterX, Span = sideSpan },
		}) do
			makePart({
				Name = "Wall_" .. seg.Name,
				Size = Vector3.new(seg.Span, cfg.WallHeight, cfg.WallThickness),
				CFrame = CFrame.new(seg.X, wallCenterY, -halfL),
				Material = cfg.WallMaterial,
				Color = cfg.WallColor,
				Decorative = false,
				Parent = wallsModel,
			})
			populateAshlarWallFace(
				wallsModel,
				"Wall_" .. seg.Name,
				Vector3.new(seg.X, wallCenterY, -halfL),
				math.max(12, seg.Span - cfg.BastionSize * 0.9),
				cfg.WallHeight,
				cfg.WallThickness,
				false
			)
			makePart({
				Name = "Plinth_" .. seg.Name,
				Size = Vector3.new(seg.Span, 4.2, cfg.WallThickness + 2.6),
				CFrame = CFrame.new(seg.X, 2.1, -halfL),
				Material = cfg.TrimMaterial,
				Color = cfg.PlinthColor or cfg.TrimColor,
				Decorative = true,
				Parent = wallsModel,
			})
			makePart({
				Name = "Cornice_" .. seg.Name,
				Size = Vector3.new(seg.Span, 2.2, cfg.WallThickness + 2.2),
				CFrame = CFrame.new(seg.X, cfg.WallHeight - 1.1, -halfL),
				Material = cfg.TrimMaterial,
				Color = Color3.fromRGB(78, 82, 88),
				Decorative = true,
				Parent = wallsModel,
			})
		end

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
			local pillarX = signX * (cfg.OpeningWidth * 0.5 + 2.0)
			makePart({
				Name = signX < 0 and "GatePillar_Left" or "GatePillar_Right",
				Size = Vector3.new(5.0, cfg.WallHeight + 4, cfg.WallThickness + 3.0),
				CFrame = CFrame.new(pillarX, (cfg.WallHeight + 4) * 0.5, -halfL),
				Material = cfg.TrimMaterial,
				Color = cfg.BastionColor,
				Decorative = false,
				Parent = wallsModel,
			})
			-- Flanking Wall Torches on Bridge Entry Pillars (Interior & Exterior)
			addWallTorch("BridgeGateTorch_In_" .. tostring(signX), Vector3.new(pillarX, 11.5, -halfL + 4.2), Vector3.new(0, 0, 1))
			addWallTorch("BridgeGateTorch_Out_" .. tostring(signX), Vector3.new(pillarX, 11.5, -halfL - 4.2), Vector3.new(0, 0, -1))
		end

		-- Stacked Wooden Crates & Barrels flanking inside the Bridge Entryway
		local entryProps = {
			{ Size = Vector3.new(3.6, 3.6, 3.6), Pos = Vector3.new(-17, 1.8, -halfL + 6.5), Yaw = 12, Color = Color3.fromRGB(122, 86, 52) },
			{ Size = Vector3.new(3.2, 3.2, 3.2), Pos = Vector3.new(-21, 1.6, -halfL + 6.0), Yaw = -18, Color = Color3.fromRGB(108, 76, 46) },
			{ Size = Vector3.new(2.8, 2.8, 2.8), Pos = Vector3.new(-18.5, 5.0, -halfL + 6.2), Yaw = 28, Color = Color3.fromRGB(134, 96, 58) },
			{ Size = Vector3.new(3.6, 3.6, 3.6), Pos = Vector3.new(17, 1.8, -halfL + 6.5), Yaw = -15, Color = Color3.fromRGB(118, 82, 50) },
			{ Size = Vector3.new(3.0, 3.0, 3.0), Pos = Vector3.new(20.8, 1.5, -halfL + 6.2), Yaw = 20, Color = Color3.fromRGB(104, 72, 44) },
		}
		for idx, c in ipairs(entryProps) do
			makePart({
				Name = "GateEntryCrate_" .. idx,
				Size = c.Size,
				CFrame = CFrame.new(c.Pos) * CFrame.Angles(0, math.rad(c.Yaw), 0),
				Material = Enum.Material.WoodPlanks,
				Color = c.Color,
				Decorative = true,
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

	-- 4. Rear Dividing Wall (+Z, separating Courtyard from Forested Outskirts)
	if cfg.IncludeRearOpening then
		local gateX = cfg.RearGateCenterX or 32
		local halfOpen = cfg.RearOpeningWidth * 0.5
		local leftEdge = -cfg.PerimeterWidth * 0.5
		local rightEdge = cfg.PerimeterWidth * 0.5
		local gateLeftEdge = gateX - halfOpen
		local gateRightEdge = gateX + halfOpen

		local leftSpan = gateLeftEdge - leftEdge
		local rightSpan = rightEdge - gateRightEdge
		local leftCenterX = leftEdge + leftSpan * 0.5
		local rightCenterX = gateRightEdge + rightSpan * 0.5

		for _, seg in ipairs({
			{ Name = "BackLeft", X = leftCenterX, Span = leftSpan },
			{ Name = "BackRight", X = rightCenterX, Span = rightSpan },
		}) do
			makePart({
				Name = "Wall_" .. seg.Name,
				Size = Vector3.new(seg.Span, cfg.WallHeight, cfg.WallThickness),
				CFrame = CFrame.new(seg.X, wallCenterY, halfL),
				Material = cfg.WallMaterial,
				Color = cfg.WallColor,
				Decorative = false,
				Parent = wallsModel,
			})
			populateAshlarWallFace(
				wallsModel,
				"Wall_" .. seg.Name,
				Vector3.new(seg.X, wallCenterY, halfL),
				math.max(12, seg.Span - cfg.BastionSize * 0.9),
				cfg.WallHeight,
				cfg.WallThickness,
				false
			)
			makePart({
				Name = "Plinth_" .. seg.Name,
				Size = Vector3.new(seg.Span, 4.2, cfg.WallThickness + 2.6),
				CFrame = CFrame.new(seg.X, 2.1, halfL),
				Material = cfg.TrimMaterial,
				Color = cfg.PlinthColor or cfg.TrimColor,
				Decorative = true,
				Parent = wallsModel,
			})
			makePart({
				Name = "Cornice_" .. seg.Name,
				Size = Vector3.new(seg.Span, 2.2, cfg.WallThickness + 2.2),
				CFrame = CFrame.new(seg.X, cfg.WallHeight - 1.1, halfL),
				Material = cfg.TrimMaterial,
				Color = Color3.fromRGB(78, 82, 88),
				Decorative = true,
				Parent = wallsModel,
			})
		end

		-- Vaulted Rear Archway Lintel & Timber-and-Iron Gate Doors (framed open)
		local lintelHeight = math.max(4, cfg.WallHeight - cfg.RearOpeningArchHeight)
		makePart({
			Name = "RearGateLintel",
			Size = Vector3.new(cfg.RearOpeningWidth + 4, lintelHeight, cfg.WallThickness + 2),
			CFrame = CFrame.new(gateX, cfg.RearOpeningArchHeight + lintelHeight * 0.5, halfL),
			Material = cfg.TrimMaterial,
			Color = cfg.TrimColor,
			Decorative = false,
			Parent = wallsModel,
		})
		for _, signX in ipairs({ -1, 1 }) do
			local pillarX = gateX + signX * (halfOpen + 2.0)
			makePart({
				Name = signX < 0 and "RearGatePillar_Left" or "RearGatePillar_Right",
				Size = Vector3.new(5.0, cfg.WallHeight + 4, cfg.WallThickness + 3.0),
				CFrame = CFrame.new(pillarX, (cfg.WallHeight + 4) * 0.5, halfL),
				Material = cfg.TrimMaterial,
				Color = cfg.BastionColor,
				Decorative = false,
				Parent = wallsModel,
			})
			-- Open Timber & Iron Gate Leaves swung into the archway
			makePart({
				Name = signX < 0 and "RearGateDoor_Left" or "RearGateDoor_Right",
				Size = Vector3.new(1.2, cfg.RearOpeningArchHeight - 1.0, 9.5),
				CFrame = CFrame.new(gateX + signX * (halfOpen - 1.2), (cfg.RearOpeningArchHeight - 1.0) * 0.5, halfL + 2.2)
					* CFrame.Angles(0, math.rad(signX * -18), 0),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(92, 62, 38),
				Decorative = true,
				Parent = wallsModel,
			})
			addWallTorch("RearGateTorch_" .. tostring(signX), Vector3.new(pillarX, 11.5, halfL - 4.2), Vector3.new(0, 0, -1))
		end

		-- Medieval Crimson & Gold Crest Banners along the Dividing Wall (flanking Forge & Market)
		for idx, bx in ipairs({ 56, 14, -48 }) do
			addWallBanner("DividingWallBanner_" .. idx, Vector3.new(bx, 16.0, halfL - (cfg.WallThickness * 0.5)))
		end

		-- Interior Wall Torches & Courtyard Perimeter Props matching reference layout
		for idx, tz in ipairs({ -52, 48 }) do
			addWallTorch("NorthWallTorch_" .. idx, Vector3.new(halfW - 3.2, 11.5, tz), Vector3.new(-1, 0, 0))
		end
		for idx, tz in ipairs({ -52, 0, 52 }) do
			addWallTorch("SouthWallTorch_" .. idx, Vector3.new(-halfW + 3.2, 11.5, tz), Vector3.new(1, 0, 0))
		end
		for idx, tx in ipairs({ -56, 56 }) do
			addWallTorch("WestWallTorch_" .. idx, Vector3.new(tx, 11.5, -halfL + 3.8), Vector3.new(0, 0, 1))
		end
		for idx, tx in ipairs({ -44, -8, 68 }) do
			addWallTorch("EastWallTorch_" .. idx, Vector3.new(tx, 11.5, halfL - 3.8), Vector3.new(0, 0, -1))
		end

		-- Stacked Wooden Barrels, Crates & Weapon Racks along West (-Z) and East (+Z) Fortress Walls
		local wallCrateClusters = {
			{ Size = Vector3.new(3.4, 3.4, 3.4), Pos = Vector3.new(46, 1.7, -halfL + 6.2), Yaw = 14 },
			{ Size = Vector3.new(3.0, 3.0, 3.0), Pos = Vector3.new(50.2, 1.5, -halfL + 5.8), Yaw = -22 },
			{ Size = Vector3.new(2.8, 2.8, 2.8), Pos = Vector3.new(47.8, 4.8, -halfL + 6.0), Yaw = 8 },
			{ Size = Vector3.new(3.6, 3.6, 3.6), Pos = Vector3.new(-48, 1.8, -halfL + 6.2), Yaw = -16 },
			{ Size = Vector3.new(3.2, 3.2, 3.2), Pos = Vector3.new(-52.5, 1.6, -halfL + 5.9), Yaw = 24 },
			{ Size = Vector3.new(3.4, 3.4, 3.4), Pos = Vector3.new(-42, 1.7, halfL - 6.2), Yaw = 19 },
			{ Size = Vector3.new(3.0, 3.0, 3.0), Pos = Vector3.new(-37.8, 1.5, halfL - 5.8), Yaw = -12 },
		}
		for idx, wc in ipairs(wallCrateClusters) do
			makePart({
				Name = "WallSideCrate_" .. idx,
				Size = wc.Size,
				CFrame = CFrame.new(wc.Pos) * CFrame.Angles(0, math.rad(wc.Yaw), 0),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(114, 78, 48),
				Decorative = false,
				Parent = wallsModel,
			})
		end

		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(-halfW + cfg.BastionSize, merlonCenterY, halfL),
			Vector3.new(gateLeftEdge, merlonCenterY, halfL),
			cfg.WallThickness,
			cfg
		)
		populateMerlonsAlongSpan(
			wallsModel,
			Vector3.new(gateRightEdge, merlonCenterY, halfL),
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
	local gateX = cfg.RearGateCenterX or 32
	local halfOpen = cfg.RearOpeningWidth * 0.5
	local leftEdge = -cfg.PerimeterWidth * 0.5
	local rightEdge = cfg.PerimeterWidth * 0.5
	local leftSpan = (gateX - halfOpen) - leftEdge
	local rightSpan = rightEdge - (gateX + halfOpen)
	local leftRearX = leftEdge + leftSpan * 0.5
	local rightRearX = (gateX + halfOpen) + rightSpan * 0.5

	local barrierDefs = {
		{ Name = "Barrier_West", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(-halfW - 1.5, bY, 0) },
		{ Name = "Barrier_East", Size = Vector3.new(2, cfg.InvisibleBarrierHeight, cfg.PerimeterLength + 4), Pos = Vector3.new(halfW + 1.5, bY, 0) },
		-- Rear barriers flanking the dividing wall gate opening
		{ Name = "Barrier_BackLeft", Size = Vector3.new(leftSpan, cfg.InvisibleBarrierHeight, 2), Pos = Vector3.new(leftRearX, bY, halfL + 1.5) },
		{ Name = "Barrier_BackRight", Size = Vector3.new(rightSpan, cfg.InvisibleBarrierHeight, 2), Pos = Vector3.new(rightRearX, bY, halfL + 1.5) },
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
