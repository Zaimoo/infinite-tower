--!strict
-- TowerBuilder.luau
-- ModuleScript: Builds the centerpiece Modular Dark-Slate & Crimson Gothic Tower at the center of the map
-- (matching `image_8c0265.jpg` and the Blender `tools/blender/generate_infinite_tower.py` kit).
--
-- Supports both:
--   1. Imported Blender FBX modules (`ReplicatedStorage.Assets.PlotFacilities.CentralTower`)
--   2. High-detail procedural modular fallback (`Tower_Base_Entrance`, `Tower_Mid_Segment`,
--      `Cloud_Ring_Bottom`, `Cloud_Ring_Top`) with identical 4 Material Zones and VFX Attachment Sockets:
--        - Zone 1 (Masonry):         Weathered Dark Slate (#18151D)
--        - Zone 2 (Window Emissive): Intense Crimson Glow (#FF2222, Enum.Material.Neon)
--        - Zone 3 (Trims/Iron):      Wrought Iron (#111111)
--        - Zone 4 (Cloud Meshes):    Dark Storm Grey (#2A2A35)
--        - Sockets: `Bridge_Snap_Point`, `VFX_Fog_Base`, `VFX_Storm_Peak`, `VFX_Window_Glow`

local TowerBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
TowerBuilder.Config = {
	-- Position & Overall Scale
	CenterPosition = Vector3.new(0, 16, 0), -- Sits at center of map (Y=16 matches TowerWalkwayY & arrival bridge)
	BaseDiameter = 186, -- Legacy config reference
	TopDiameter = 186, -- Non-tapering cylindrical gothic spire (matching reference image_8c0265.jpg)
	TowerDiameter = 650, -- World footprint diameter in studs (radius = 325, snaps to TowerHubArrival at Z = -325..-358)
	TowerHeight = 900, -- Total stacked height in studs
	MidSegmentCount = 8, -- Number of stacked `Tower_Mid_Segment` modules (each has 2 stories of pointed gothic windows)
	BaseHeight = 84, -- Height of `Tower_Base_Entrance` foundation module in studs
	MidSegmentHeight = 96, -- Height of each repeatable `Tower_Mid_Segment` module in studs (2 window tiers of 48 studs)
	BaysPerRing = 16, -- 16 Gothic architectural bays around circumference; Bay 1 (angle 0) faces North (-Z / Hub Bridge)

	-- Cracked Smoky Base Ground
	CrackedGroundDiameter = 796,
	CrackedFissureCount = 16,

	-- Entrance Gate at Base (-Z facing Pilgrim's Causeway & Hub Bridge)
	BridgeSnapPointZ = -358, -- Exact front threshold where `TowerEntranceApproach` bridge lands
	GatehouseFrontZ = -336,
	EntrancePortalZ = -332,
	EntranceWidth = 36,
	EntranceHeight = 46,

	-- 4 Material Zones (Step 2 Specification)
	Zone1MasonryMaterial = Enum.Material.Slate,
	Zone1MasonryColor = Color3.fromRGB(24, 21, 29), -- #18151D Weathered Dark Slate
	Zone1AshlarColor = Color3.fromRGB(34, 30, 41), -- Subtle coursed stone highlight
	Zone2WindowMaterial = Enum.Material.Neon,
	Zone2WindowColor = Color3.fromRGB(255, 34, 34), -- #FF2222 Intense Crimson Glow
	Zone2WindowInnerColor = Color3.fromRGB(255, 110, 65), -- Warm inner fire-glow gradient core
	Zone3IronMaterial = Enum.Material.Metal,
	Zone3IronColor = Color3.fromRGB(17, 17, 17), -- #111111 Wrought Iron
	Zone4CloudMaterial = Enum.Material.SmoothPlastic,
	Zone4CloudColor = Color3.fromRGB(42, 42, 53), -- #2A2A35 Dark Storm Grey
	Zone4CloudDeepColor = Color3.fromRGB(28, 28, 38),

	-- Storm Clouds & Ember Particles
	DarkCloudColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(34, 32, 42)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(52, 36, 46)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(22, 20, 28)),
	}),
	LowerMistColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(72, 68, 82)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(48, 44, 56)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(30, 28, 38)),
	}),
	EmberColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 145, 75)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 42, 42)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(110, 18, 24)),
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
	local isDecorative = props.Decorative ~= false
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
		if k ~= "Decorative" and k ~= "Parent" and k ~= "Diameter" and k ~= "Height" and k ~= "Position" and k ~= "Zone" then
			(p :: any)[k] = v
		end
	end
	if props.Zone then
		p:SetAttribute("MaterialZone", props.Zone)
	end
	p.Parent = props.Parent
	return p
end

local function makeWedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	local isDecorative = props.Decorative ~= false
	if isDecorative then
		w.CanCollide = false
		w.CanTouch = false
		w.CanQuery = false
		w.CastShadow = false
	else
		w.CanCollide = true
		w.CanTouch = false
		w.CanQuery = true
	end
	for k, v in pairs(props) do
		if k ~= "Decorative" and k ~= "Parent" and k ~= "Zone" then
			(w :: any)[k] = v
		end
	end
	if props.Zone then
		w:SetAttribute("MaterialZone", props.Zone)
	end
	w.Parent = props.Parent
	return w
end

local function makeCylinder(props: { [string]: any }): Part
	local p = makePart(props)
	p.Shape = Enum.PartType.Cylinder
	local pos: Vector3 = props.Position or Vector3.zero
	local height: number = props.Height or 1
	local diameter: number = props.Diameter or 4
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function makeAttachment(parent: BasePart, name: string, worldPos: Vector3): Attachment
	local att = Instance.new("Attachment")
	att.Name = name
	att.Position = parent.CFrame:PointToObjectSpace(worldPos)
	att.Parent = parent
	return att
end

-- Builds a pointed Gothic Window Bay on the cylindrical tower wall at `angleRad`
-- (where angleRad = 0 faces North / -Z toward the Hub Bridge).
local function buildGothicWindowBay(
	parent: Instance,
	cfg: { [string]: any },
	origin: Vector3,
	radius: number,
	angleRad: number,
	sillY: number,
	windowW: number,
	windowH: number,
	includeBalcony: boolean,
	namePrefix: string,
	socketHost: BasePart?
)
	local sa = math.sin(angleRad)
	local ca = -math.cos(angleRad) -- angle 0 -> (0, 0, -1) facing North / Hub Bridge
	local outward = Vector3.new(sa, 0, ca)
	local springH = windowH * 0.64
	local archH = windowH - springH
	local centerPos = Vector3.new(origin.X, sillY + springH * 0.5, origin.Z) + outward * (radius + 0.5)
	local bayCF = CFrame.lookAt(centerPos, centerPos + outward)

	-- 1. Recessed Glowing Crimson Window Pane (Zone 2: #FF2222 Neon)
	local paneColor = cfg.Zone2WindowColor
	makePart({
		Name = namePrefix .. "_PaneRect",
		Size = Vector3.new(windowW * 0.84, springH, 1.8),
		CFrame = bayCF,
		Material = cfg.Zone2WindowMaterial,
		Color = paneColor,
		Transparency = 0.08,
		Decorative = true,
		Zone = "Zone2_WindowEmissive",
		Parent = parent,
	})
	-- Pointed Gothic Lancet Arch Crown (2 WedgeParts back-to-back meeting at the center apex!)
	local archCenterCF = CFrame.lookAt(
		Vector3.new(origin.X, sillY + springH + archH * 0.5, origin.Z) + outward * (radius + 0.5),
		Vector3.new(origin.X, sillY + springH + archH * 0.5, origin.Z) + outward * (radius + 10)
	)
	for _, side in ipairs({ -1, 1 }) do
		makeWedge({
			Name = namePrefix .. (side < 0 and "_PaneArchL" or "_PaneArchR"),
			Size = Vector3.new(1.8, archH, windowW * 0.42),
			CFrame = archCenterCF
				* CFrame.new(side * (windowW * 0.21), 0, 0)
				* CFrame.Angles(0, -side * (math.pi * 0.5), 0),
			Material = cfg.Zone2WindowMaterial,
			Color = paneColor,
			Transparency = 0.08,
			Decorative = true,
			Zone = "Zone2_WindowEmissive",
			Parent = parent,
		})
	end

	-- 2. Pointed Gothic Dark-Slate Jambs, Sill & Hood Mould (Zone 1: #18151D)
	local jambW = 3.2
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = namePrefix .. (side < 0 and "_JambL" or "_JambR"),
			Size = Vector3.new(jambW, springH + 2.0, 4.2),
			CFrame = bayCF * CFrame.new(side * (windowW * 0.46 + jambW * 0.4), 0, 0.8),
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1AshlarColor,
			Decorative = true,
			Zone = "Zone1_Masonry",
			Parent = parent,
		})
		-- Pointed Gothic Hood Mould Slope meeting at the Lancet Apex
		local slopeLen = math.sqrt((windowW * 0.52) ^ 2 + (archH + 2.4) ^ 2)
		local slopeAngle = math.atan2(archH + 2.4, windowW * 0.52)
		makePart({
			Name = namePrefix .. (side < 0 and "_HoodL" or "_HoodR"),
			Size = Vector3.new(slopeLen, 2.8, 4.6),
			CFrame = archCenterCF
				* CFrame.new(side * (windowW * 0.26), 0.8, 0.9)
				* CFrame.Angles(0, 0, -side * slopeAngle),
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1AshlarColor,
			Decorative = true,
			Zone = "Zone1_Masonry",
			Parent = parent,
		})
	end

	-- Stone Window Sill Ledge
	makePart({
		Name = namePrefix .. "_Sill",
		Size = Vector3.new(windowW + 7.5, 2.8, 5.2),
		CFrame = CFrame.lookAt(
			Vector3.new(origin.X, sillY - 1.2, origin.Z) + outward * (radius + 1.4),
			Vector3.new(origin.X, sillY - 1.2, origin.Z) + outward * (radius + 12)
		),
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1AshlarColor,
		Decorative = true,
		Zone = "Zone1_Masonry",
		Parent = parent,
	})

	-- 3. Wrought-Iron Center Mullion & Transom Tracery Bars (Zone 3: #111111)
	makePart({
		Name = namePrefix .. "_IronMullionV",
		Size = Vector3.new(1.5, windowH * 0.92, 2.6),
		CFrame = CFrame.lookAt(
			Vector3.new(origin.X, sillY + windowH * 0.46, origin.Z) + outward * (radius + 0.9),
			Vector3.new(origin.X, sillY + windowH * 0.46, origin.Z) + outward * (radius + 10)
		),
		Material = cfg.Zone3IronMaterial,
		Color = cfg.Zone3IronColor,
		Decorative = true,
		Zone = "Zone3_WroughtIron",
		Parent = parent,
	})
	makePart({
		Name = namePrefix .. "_IronTransomH",
		Size = Vector3.new(windowW * 0.84, 1.3, 2.5),
		CFrame = CFrame.lookAt(
			Vector3.new(origin.X, sillY + springH - 0.5, origin.Z) + outward * (radius + 0.9),
			Vector3.new(origin.X, sillY + springH - 0.5, origin.Z) + outward * (radius + 10)
		),
		Material = cfg.Zone3IronMaterial,
		Color = cfg.Zone3IronColor,
		Decorative = true,
		Zone = "Zone3_WroughtIron",
		Parent = parent,
	})

	-- 4. Protruding Wrought-Iron Balcony with Finial Spikes (Zone 3: #111111)
	if includeBalcony then
		local balcCF = CFrame.lookAt(
			Vector3.new(origin.X, sillY - 1.5, origin.Z) + outward * (radius + 4.8),
			Vector3.new(origin.X, sillY - 1.5, origin.Z) + outward * (radius + 15)
		)
		makePart({
			Name = namePrefix .. "_BalconyDeck",
			Size = Vector3.new(windowW + 10, 2.4, 7.5),
			CFrame = balcCF,
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1MasonryColor,
			Decorative = true,
			Zone = "Zone1_Masonry",
			Parent = parent,
		})
		makePart({
			Name = namePrefix .. "_BalconyIronRail",
			Size = Vector3.new(windowW + 10.4, 4.8, 1.2),
			CFrame = balcCF * CFrame.new(0, 3.4, -3.2),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = parent,
		})
		for _, sx in ipairs({ -1, 1 }) do
			makePart({
				Name = namePrefix .. "_BalconyFinial",
				Size = Vector3.new(1.8, 8.2, 1.8),
				CFrame = balcCF * CFrame.new(sx * (windowW * 0.5 + 4.6), 4.8, -3.2),
				Material = cfg.Zone3IronMaterial,
				Color = cfg.Zone3IronColor,
				Decorative = true,
				Zone = "Zone3_WroughtIron",
				Parent = parent,
			})
		end
	end

	-- 5. Optional `VFX_Window_Glow` Attachment Socket inside the Gothic Window Arch
	if socketHost then
		local glowWorldPos = Vector3.new(origin.X, sillY + springH * 0.65, origin.Z) + outward * (radius + 3.0)
		makeAttachment(socketHost, "VFX_Window_Glow", glowWorldPos)
	end
end

-- Builds a stylized, low-poly solid storm cloud ring model (`Cloud_Ring_Bottom` or `Cloud_Ring_Top`)
local function buildStylizedCloudRing(
	parent: Instance,
	modelName: string,
	socketName: string,
	centerPos: Vector3,
	innerRadius: number,
	lobeCount: number,
	lobeScale: Vector3,
	partFrontGate: boolean,
	includeCoreCap: boolean,
	cfg: { [string]: any }
): Model
	local cloudModel = Instance.new("Model")
	cloudModel.Name = modelName

	local root = makePart({
		Name = modelName .. "_Root",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(centerPos),
		Transparency = 1,
		Decorative = true,
		Zone = "Zone4_StormCloud",
		Parent = cloudModel,
	})
	cloudModel.PrimaryPart = root
	makeAttachment(root, socketName, centerPos)

	if includeCoreCap then
		makeCylinder({
			Name = "StormCloudCoreCap",
			Diameter = innerRadius * 2.15,
			Height = lobeScale.Y * 0.85,
			Position = centerPos + Vector3.new(0, lobeScale.Y * 0.25, 0),
			Material = cfg.Zone4CloudMaterial,
			Color = cfg.Zone4CloudDeepColor,
			Decorative = true,
			Zone = "Zone4_StormCloud",
			Parent = cloudModel,
		})
	end

	for i = 1, lobeCount do
		-- Skip the front-center lobe (i == 1) on the bottom cloud ring so the Grand Gothic Gatehouse
		-- and central window column remain completely unobstructed when approaching from the Hub Bridge!
		if partFrontGate and i == 1 then
			continue
		end
		local ang = ((i - 1) / lobeCount) * math.pi * 2
		local sa, ca = math.sin(ang), -math.cos(ang)
		local isFrontFlank = partFrontGate and (i == 2 or i == lobeCount)
		local rDist = innerRadius + (if isFrontFlank then 24 else 8) + (i % 2) * 18
		local yOff = ((i % 3) - 1) * (lobeScale.Y * 0.14)
		local w = lobeScale.X * (0.9 + (i % 3) * 0.14)
		local h = lobeScale.Y * (0.78 + (i % 2) * 0.16)
		local d = lobeScale.Z * (0.9 + ((i + 1) % 3) * 0.14)

		local lobePos = centerPos + Vector3.new(sa * rDist, yOff, ca * rDist)
		local lobeCF = CFrame.lookAt(lobePos, Vector3.new(centerPos.X, lobePos.Y, centerPos.Z))
			* CFrame.Angles(math.rad((i % 3 - 1) * 5), math.rad((i % 2) * 12), 0)

		makeCylinder({
			Name = string.format("CloudLobe_%02d", i),
			Diameter = math.max(w, d),
			Height = h,
			Position = lobePos,
			Material = cfg.Zone4CloudMaterial,
			Color = if i % 2 == 0 then cfg.Zone4CloudColor else cfg.Zone4CloudDeepColor,
			Decorative = true,
			Zone = "Zone4_StormCloud",
			Parent = cloudModel,
		})

		-- Secondary billowy cloud puff cap (`Shape = Ball` with uniform gentle scale)
		local puffD = math.min(w, d) * 0.72
		makePart({
			Name = string.format("CloudUnderPuff_%02d", i),
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(puffD, puffD, puffD),
			CFrame = lobeCF * CFrame.new((i % 2 == 0 and 1 or -1) * w * 0.18, h * 0.22, -d * 0.12),
			Material = cfg.Zone4CloudMaterial,
			Color = cfg.Zone4CloudDeepColor,
			Decorative = true,
			Zone = "Zone4_StormCloud",
			Parent = cloudModel,
		})

		if i % 3 == 1 then
			makeAttachment(root, string.format("%s_%02d", socketName, i), lobePos)
		end
	end

	cloudModel.Parent = parent
	return cloudModel
end

--============================================================================
-- BUILDER
--============================================================================
function TowerBuilder.Build(parent: Instance?, customConfig: { [string]: any }?): Model
	local cfg = table.clone(TowerBuilder.Config)
	if customConfig then
		for k, v in pairs(customConfig) do
			(cfg :: any)[k] = v
		end
	end

	local towerModel = Instance.new("Model")
	towerModel.Name = "CentralCrimsonTower"

	local origin = cfg.CenterPosition
	local radius = cfg.TowerDiameter * 0.5 -- 325 studs
	local bayCount = cfg.BaysPerRing

	--========================================================================
	-- 1. Cracked, Dark, Smoky Base Ground with Faint Red Glow from Below
	--========================================================================
	local baseGroundFolder = Instance.new("Folder")
	baseGroundFolder.Name = "CrackedSmokyBase"
	baseGroundFolder.Parent = towerModel

	local basePlinth = makeCylinder({
		Name = "CrackedGroundSlab",
		Diameter = cfg.CrackedGroundDiameter,
		Height = 2.0,
		Position = origin + Vector3.new(0, -0.6, 0),
		Material = Enum.Material.CrackedLava,
		Color = Color3.fromRGB(24, 18, 24),
		Decorative = false,
		Zone = "Zone1_Masonry",
		Parent = baseGroundFolder,
	})
	towerModel.PrimaryPart = basePlinth

	for i = 1, cfg.CrackedFissureCount do
		local angle = ((i - 1) / cfg.CrackedFissureCount) * (math.pi * 2)
		local r = radius + 24
		local pos = origin + Vector3.new(math.cos(angle) * r, 0.35, math.sin(angle) * r)
		makePart({
			Name = string.format("CrimsonFissure_%d", i),
			Size = Vector3.new(3.2, 0.25, 48),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi * 0.5, 0),
			Material = cfg.Zone2WindowMaterial,
			Color = cfg.Zone2WindowColor,
			Transparency = 0.28,
			Decorative = true,
			Zone = "Zone2_WindowEmissive",
			Parent = baseGroundFolder,
		})
	end

	--========================================================================
	-- 2. MODULE 1: `Tower_Base_Entrance` (Foundation + Grand Gothic Gatehouse)
	--    Origin at bottom-center `origin` (0, 16, 0), with `Bridge_Snap_Point`
	--    at (0, 16, -358) aligned to the Pilgrim's Causeway / Hub Bridge!
	--========================================================================
	local baseSegmentModel = Instance.new("Model")
	baseSegmentModel.Name = "Tower_Base_Entrance"
	baseSegmentModel.Parent = towerModel

	local baseRoot = makePart({
		Name = "BaseOriginRoot",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(origin),
		Transparency = 1,
		Decorative = true,
		Parent = baseSegmentModel,
	})
	baseSegmentModel.PrimaryPart = baseRoot

	-- `Bridge_Snap_Point`: Exact center of the `Tower_Base_Entrance` threshold
	makeAttachment(baseRoot, "Bridge_Snap_Point", Vector3.new(origin.X, origin.Y, cfg.BridgeSnapPointZ))

	-- Stepped Dark-Slate Foundation Plinths
	makeCylinder({
		Name = "BasePlinthTier1",
		Diameter = cfg.TowerDiameter + 28,
		Height = 10,
		Position = origin + Vector3.new(0, 5, 0),
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1MasonryColor,
		Decorative = false,
		Zone = "Zone1_Masonry",
		Parent = baseSegmentModel,
	})
	makeCylinder({
		Name = "BasePlinthTier2",
		Diameter = cfg.TowerDiameter + 14,
		Height = 12,
		Position = origin + Vector3.new(0, 16, 0),
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1AshlarColor,
		Decorative = false,
		Zone = "Zone1_Masonry",
		Parent = baseSegmentModel,
	})

	-- Flat Stone Threshold Apron extending to `Bridge_Snap_Point` (-358)
	local thresholdLen = math.abs(cfg.BridgeSnapPointZ - (-radius + 12))
	local thresholdMidZ = (cfg.BridgeSnapPointZ + (-radius + 12)) * 0.5
	makePart({
		Name = "BridgeThresholdApron",
		Size = Vector3.new(cfg.EntranceWidth + 32, 3.2, thresholdLen),
		CFrame = CFrame.new(origin.X, origin.Y - 1.2, thresholdMidZ),
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1MasonryColor,
		Decorative = false,
		Zone = "Zone1_Masonry",
		Parent = baseSegmentModel,
	})
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = side < 0 and "ThresholdIronCurb_L" or "ThresholdIronCurb_R",
			Size = Vector3.new(2.2, 4.2, thresholdLen - 4),
			CFrame = CFrame.new(origin.X + side * (cfg.EntranceWidth * 0.5 + 14.5), origin.Y + 2.1, thresholdMidZ),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = false,
			Zone = "Zone3_WroughtIron",
			Parent = baseSegmentModel,
		})
	end

	-- Perimeter Gothic Windows & Buttresses on `Tower_Base_Entrance` (skipping Bay 1 where the gatehouse stands)
	for bayIdx = 1, bayCount do
		local bayAngle = ((bayIdx - 1) / bayCount) * math.pi * 2
		local ribAngle = ((bayIdx - 0.5) / bayCount) * math.pi * 2
		local rSa, rCa = math.sin(ribAngle), -math.cos(ribAngle)
		local ribPos = Vector3.new(origin.X + rSa * (radius + 5.5), origin.Y + cfg.BaseHeight * 0.5, origin.Z + rCa * (radius + 5.5))
		makePart({
			Name = string.format("BaseButtress_%02d", bayIdx),
			Size = Vector3.new(11, cfg.BaseHeight - 4, 14),
			CFrame = CFrame.lookAt(ribPos, Vector3.new(origin.X, ribPos.Y, origin.Z)),
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1AshlarColor,
			Decorative = true,
			Zone = "Zone1_Masonry",
			Parent = baseSegmentModel,
		})

		if bayIdx ~= 1 and bayIdx ~= 2 and bayIdx ~= bayCount then
			buildGothicWindowBay(
				baseSegmentModel,
				cfg,
				origin,
				radius,
				bayAngle,
				origin.Y + 24,
				24,
				44,
				(bayIdx % 2 == 0),
				string.format("BaseWindow_%02d", bayIdx),
				baseRoot
			)
		end
	end

	-- Preserve `TowerBaseEntrance` & `EntrancePortalTrigger` contract for `BridgeBuilder` and `TowerTraversalSetup`
	local entranceModel = Instance.new("Model")
	entranceModel.Name = "TowerBaseEntrance"
	entranceModel:SetAttribute("IsFunctional", true)
	entranceModel.Parent = towerModel

	local gateCenterY = origin.Y + cfg.EntranceHeight * 0.5
	local gateCF = CFrame.lookAt(
		Vector3.new(origin.X, gateCenterY, cfg.EntrancePortalZ),
		Vector3.new(origin.X, gateCenterY, cfg.EntrancePortalZ - 20)
	)

	-- Towering Gothic Flanking Buttress Piers & Wrought-Iron Spire Finials
	for _, signX in ipairs({ -1, 1 }) do
		local pierX = signX * (cfg.EntranceWidth * 0.5 + 8.5)
		makePart({
			Name = signX < 0 and "EntrancePillar_Left" or "EntrancePillar_Right",
			Size = Vector3.new(16, cfg.EntranceHeight + 22, 22),
			CFrame = CFrame.new(origin.X + pierX, origin.Y + (cfg.EntranceHeight + 22) * 0.5, cfg.GatehouseFrontZ + 4),
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1MasonryColor,
			Decorative = false,
			Zone = "Zone1_Masonry",
			Parent = entranceModel,
		})
		makePart({
			Name = signX < 0 and "EntranceSpireFinial_Left" or "EntranceSpireFinial_Right",
			Size = Vector3.new(6, 22, 6),
			CFrame = CFrame.new(origin.X + pierX, origin.Y + cfg.EntranceHeight + 33, cfg.GatehouseFrontZ),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = entranceModel,
		})
	end

	-- Pointed Gothic Arch Hood & Gable Over the Entrance
	local archApexY = origin.Y + cfg.EntranceHeight + 18
	for _, signX in ipairs({ -1, 1 }) do
		local spanW = cfg.EntranceWidth * 0.5 + 10
		local riseH = 22
		local slopeLen = math.sqrt(spanW * spanW + riseH * riseH)
		local roll = math.atan2(riseH, spanW)
		makePart({
			Name = signX < 0 and "EntranceGothicArch_L" or "EntranceGothicArch_R",
			Size = Vector3.new(slopeLen, 6.5, 22),
			CFrame = CFrame.new(origin.X + signX * (spanW * 0.5), archApexY - riseH * 0.5, cfg.GatehouseFrontZ + 4)
				* CFrame.Angles(0, 0, -signX * roll),
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1AshlarColor,
			Decorative = false,
			Zone = "Zone1_Masonry",
			Parent = entranceModel,
		})
	end

	-- Raised Wrought-Iron Portcullis Teeth inside Upper Gothic Arch
	for barIdx = -3, 3 do
		makePart({
			Name = string.format("PortcullisTooth_%d", barIdx + 4),
			Size = Vector3.new(1.4, 16, 1.8),
			CFrame = CFrame.new(origin.X + barIdx * 4.6, origin.Y + cfg.EntranceHeight - 2, cfg.GatehouseFrontZ - 2),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = entranceModel,
		})
	end

	-- Glowing Crimson Sanctuary Portal Trigger (`EntrancePortalTrigger`)
	local portalTrigger = makePart({
		Name = "EntrancePortalTrigger",
		Size = Vector3.new(cfg.EntranceWidth, cfg.EntranceHeight, 4.5),
		CFrame = gateCF,
		Material = cfg.Zone2WindowMaterial,
		Color = cfg.Zone2WindowColor,
		Transparency = 0.12,
		Decorative = false,
		Zone = "Zone2_WindowEmissive",
		Parent = entranceModel,
	})
	entranceModel.PrimaryPart = portalTrigger

	--========================================================================
	-- 3. MODULE 2 STACK: `Tower_Mid_Segment` Repeated Vertically (Non-Tapering)
	--    Also populates `TowerRings` (`TowerRingCore_01..18` & `TowerRingLedge_01..18`)
	--    so `TowerTraversalSetup` and all existing specs remain 100% compatible!
	--========================================================================
	local ringsFolder = Instance.new("Folder")
	ringsFolder.Name = "TowerRings"
	ringsFolder.Parent = towerModel

	local midStackFolder = Instance.new("Folder")
	midStackFolder.Name = "Tower_Mid_Segments"
	midStackFolder.Parent = towerModel

	local totalStories = 1 + cfg.MidSegmentCount * 2 -- 1 Base + 16 Mid stories = 17..18 rings
	local storyHeight = cfg.MidSegmentHeight * 0.5 -- 48 studs per window story

	-- Register Ring 01 for the Base Foundation Drum
	makeCylinder({
		Name = "TowerRingCore_01",
		Diameter = cfg.TowerDiameter,
		Height = cfg.BaseHeight,
		Position = Vector3.new(origin.X, origin.Y + cfg.BaseHeight * 0.5, origin.Z),
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1MasonryColor,
		Decorative = false,
		Zone = "Zone1_Masonry",
		Parent = ringsFolder,
	})
	makeCylinder({
		Name = "TowerRingLedge_01",
		Diameter = cfg.TowerDiameter + 16,
		Height = 4.5,
		Position = Vector3.new(origin.X, origin.Y + cfg.BaseHeight - 2.0, origin.Z),
		Material = cfg.Zone3IronMaterial,
		Color = cfg.Zone3IronColor,
		Decorative = true,
		Zone = "Zone3_WroughtIron",
		Parent = ringsFolder,
	})

	for segIdx = 1, cfg.MidSegmentCount do
		local segBaseY = origin.Y + cfg.BaseHeight + (segIdx - 1) * cfg.MidSegmentHeight
		local segModel = Instance.new("Model")
		segModel.Name = string.format("Tower_Mid_Segment_%02d", segIdx)
		segModel:SetAttribute("SegmentIndex", segIdx)
		segModel.Parent = midStackFolder

		local segRoot = makePart({
			Name = "SegmentOriginRoot",
			Size = Vector3.new(4, 4, 4),
			CFrame = CFrame.new(origin.X, segBaseY, origin.Z),
			Transparency = 1,
			Decorative = true,
			Parent = segModel,
		})
		segModel.PrimaryPart = segRoot

		-- 2 Stories per `Tower_Mid_Segment`
		for localTier = 1, 2 do
			local ringIdx = 1 + (segIdx - 1) * 2 + localTier
			local tierBotY = segBaseY + (localTier - 1) * storyHeight
			local tierCenterY = tierBotY + storyHeight * 0.5
			local tierTopY = tierBotY + storyHeight

			-- Non-tapering Dark-Slate Cylindrical Core (`Zone 1: #18151D`)
			makeCylinder({
				Name = string.format("TowerRingCore_%02d", ringIdx),
				Diameter = cfg.TowerDiameter,
				Height = storyHeight,
				Position = Vector3.new(origin.X, tierCenterY, origin.Z),
				Material = cfg.Zone1MasonryMaterial,
				Color = cfg.Zone1MasonryColor,
				Decorative = true,
				Zone = "Zone1_Masonry",
				Parent = ringsFolder,
			})

			-- Overhanging Gothic Gallery Cornice & Wrought-Iron Balustrade Ledge
			local isMajorGallery = (localTier == 2)
			makeCylinder({
				Name = string.format("TowerRingLedge_%02d", ringIdx),
				Diameter = cfg.TowerDiameter + (if isMajorGallery then 18 else 10),
				Height = if isMajorGallery then 4.8 else 3.0,
				Position = Vector3.new(origin.X, tierTopY - 1.8, origin.Z),
				Material = if isMajorGallery then cfg.Zone3IronMaterial else cfg.Zone1MasonryMaterial,
				Color = if isMajorGallery then cfg.Zone3IronColor else cfg.Zone1AshlarColor,
				Decorative = true,
				Zone = if isMajorGallery then "Zone3_WroughtIron" else "Zone1_Masonry",
				Parent = ringsFolder,
			})

			-- Pointed Gothic Arched Windows around the circumference
			for bayIdx = 1, bayCount do
				local bayAngle = ((bayIdx - 1) / bayCount) * math.pi * 2
				local includeBalc = isMajorGallery and (bayIdx % 2 == 1)
				local addGlowSocket = (bayIdx % 4 == 1) and (localTier == 1)
				buildGothicWindowBay(
					segModel,
					cfg,
					origin,
					radius,
					bayAngle,
					tierBotY + 5.5,
					23,
					storyHeight - 12,
					includeBalc,
					string.format("Window_%02d_%02d", ringIdx, bayIdx),
					if addGlowSocket then segRoot else nil
				)
			end
		end

		-- Continuous Vertical Gothic Buttresses & Gargoyle Finial Spurs along the Segment
		for bayIdx = 1, bayCount do
			local ribAngle = ((bayIdx - 0.5) / bayCount) * math.pi * 2
			local rSa, rCa = math.sin(ribAngle), -math.cos(ribAngle)
			local ribPos = Vector3.new(
				origin.X + rSa * (radius + 5.0),
				segBaseY + cfg.MidSegmentHeight * 0.5,
				origin.Z + rCa * (radius + 5.0)
			)
			local ribCF = CFrame.lookAt(ribPos, Vector3.new(origin.X, ribPos.Y, origin.Z))

			makePart({
				Name = string.format("GothicButtress_%02d_%02d", segIdx, bayIdx),
				Size = Vector3.new(9.5, cfg.MidSegmentHeight, 12.5),
				CFrame = ribCF,
				Material = cfg.Zone1MasonryMaterial,
				Color = cfg.Zone1AshlarColor,
				Decorative = true,
				Zone = "Zone1_Masonry",
				Parent = segModel,
			})

			-- Wrought-Iron Spire Pinnacle & Outward Gargoyle Spur at Segment Crown (`Zone 3: #111111`)
			local crownPos = Vector3.new(
				origin.X + rSa * (radius + 11.5),
				segBaseY + cfg.MidSegmentHeight,
				origin.Z + rCa * (radius + 11.5)
			)
			makePart({
				Name = string.format("IronButtressSpire_%02d_%02d", segIdx, bayIdx),
				Size = Vector3.new(4.2, 16, 4.2),
				CFrame = CFrame.lookAt(crownPos + Vector3.new(0, 6, 0), Vector3.new(origin.X, crownPos.Y + 6, origin.Z)),
				Material = cfg.Zone3IronMaterial,
				Color = cfg.Zone3IronColor,
				Decorative = true,
				Zone = "Zone3_WroughtIron",
				Parent = segModel,
			})
			makeWedge({
				Name = string.format("GothicGargoyleSpur_%02d_%02d", segIdx, bayIdx),
				Size = Vector3.new(3.2, 5.5, 11.0),
				CFrame = CFrame.lookAt(crownPos, crownPos + Vector3.new(rSa, 0, rCa)) * CFrame.Angles(math.pi, 0, 0),
				Material = cfg.Zone3IronMaterial,
				Color = cfg.Zone3IronColor,
				Decorative = true,
				Zone = "Zone3_WroughtIron",
				Parent = segModel,
			})
		end

		if segIdx % 2 == 0 then
			task.wait()
		end
	end

	--========================================================================
	-- 4. MODULES 3 & 4: `Cloud_Ring_Bottom` & `Cloud_Ring_Top` (Zone 4: #2A2A35)
	--    With `VFX_Fog_Base` and `VFX_Storm_Peak` Attachment Sockets!
	--========================================================================
	local totalStackTopY = origin.Y + cfg.BaseHeight + cfg.MidSegmentCount * cfg.MidSegmentHeight

	-- `Cloud_Ring_Bottom`: Wraps `Tower_Base_Entrance` just above the archway (Y = origin.Y + 68)
	buildStylizedCloudRing(
		towerModel,
		"Cloud_Ring_Bottom",
		"VFX_Fog_Base",
		Vector3.new(origin.X, origin.Y + 68, origin.Z),
		radius + 10,
		14,
		Vector3.new(135, 52, 115),
		true,
		false,
		cfg
	)

	-- `Cloud_Ring_Top`: Heavy overhanging storm cloud swallowing the peak of the tower stack
	buildStylizedCloudRing(
		towerModel,
		"Cloud_Ring_Top",
		"VFX_Storm_Peak",
		Vector3.new(origin.X, totalStackTopY - 22, origin.Z),
		radius + 26,
		16,
		Vector3.new(185, 78, 165),
		false,
		true,
		cfg
	)

	--========================================================================
	-- 5. Server-Baseline Atmospheric Storm & Ember Emitters (`TowerStormVFX`)
	--========================================================================
	local vfxFolder = Instance.new("Folder")
	vfxFolder.Name = "TowerStormVFX"
	vfxFolder.Parent = towerModel

	for i, bandY in ipairs({
		origin.Y + 68,
		origin.Y + (totalStackTopY - origin.Y) * 0.42,
		origin.Y + (totalStackTopY - origin.Y) * 0.72,
		totalStackTopY - 18,
	}) do
		local isLowerFog = (i <= 2)
		local emitterPart = makePart({
			Name = string.format("StormEmitterBand_%d", i),
			Size = Vector3.new(cfg.TowerDiameter * 0.92, 6, cfg.TowerDiameter * 0.92),
			CFrame = CFrame.new(origin.X, bandY, origin.Z),
			Transparency = 1,
			Decorative = true,
			Parent = vfxFolder,
		})

		local darkClouds = Instance.new("ParticleEmitter")
		darkClouds.Name = "SwirlingDarkClouds"
		darkClouds.Texture = "rbxassetid://243660364"
		darkClouds.Color = if isLowerFog then cfg.LowerMistColor else cfg.DarkCloudColor
		darkClouds.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.25, 0.32),
			NumberSequenceKeypoint.new(0.75, 0.42),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		darkClouds.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 42),
			NumberSequenceKeypoint.new(0.5, 68),
			NumberSequenceKeypoint.new(1.0, 88),
		})
		darkClouds.Lifetime = NumberRange.new(8, 12)
		darkClouds.Rate = 10
		darkClouds.Speed = NumberRange.new(6, 14)
		darkClouds.SpreadAngle = Vector2.new(180, 15)
		darkClouds.Rotation = NumberRange.new(0, 360)
		darkClouds.RotSpeed = NumberRange.new(-20, 20)
		darkClouds.Parent = emitterPart

		local redEmbers = Instance.new("ParticleEmitter")
		redEmbers.Name = "RisingRedEmbers"
		redEmbers.Texture = "rbxassetid://241685484"
		redEmbers.Color = cfg.EmberColor
		redEmbers.LightEmission = 1.0
		redEmbers.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.15),
			NumberSequenceKeypoint.new(0.7, 0.08),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		redEmbers.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 2.0),
			NumberSequenceKeypoint.new(0.5, 3.2),
			NumberSequenceKeypoint.new(1.0, 0.6),
		})
		redEmbers.Lifetime = NumberRange.new(5, 9)
		redEmbers.Rate = 14
		redEmbers.Speed = NumberRange.new(10, 24)
		redEmbers.SpreadAngle = Vector2.new(180, 35)
		redEmbers.Acceleration = Vector3.new(0, 6, 0)
		redEmbers.Parent = emitterPart
	end

	towerModel:SetAttribute("TowerArchitectureVersion", 2)
	towerModel:SetAttribute("MidSegmentCount", cfg.MidSegmentCount)
	towerModel:SetAttribute("BridgeSnapPoint", Vector3.new(origin.X, origin.Y, cfg.BridgeSnapPointZ))

	if parent then
		towerModel.Parent = parent
	end

	return towerModel
end

return TowerBuilder
