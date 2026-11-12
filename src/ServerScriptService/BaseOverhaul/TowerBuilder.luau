--!strict
-- TowerBuilder.luau
-- ModuleScript: Builds the centerpiece Dark-Slate & Crimson Gothic Tower at the center of the map.
--
-- Silhouette, bottom to top:
--   * `Cloud_Ring_Bottom`: a bank of cumulus clouds below and around the tower's floating crag
--   * `FloatingCrag`: tapered rock under the cracked ground slab
--   * `Tower_Base_Entrance` + `TowerBaseEntrance`: foundation drum and twin-turret gatehouse
--   * `Tower_Mid_Segments`: stepped stages, each narrower than the last, with battlemented galleries
--     and flying buttresses at the setbacks
--   * `Tower_Crown`: lantern drum, pinnacle turrets, great spire and a sky beacon
--
-- Material Zones (the `MaterialZone` attribute; `TowerAtmosphereController` re-applies them on clients)
-- and VFX Attachment Sockets:
--   - Zone 1 (Masonry):         Weathered Dark Slate (#18151D)
--   - Zone 2 (Window Emissive): Intense Crimson Glow (#FF2222, Enum.Material.Neon)
--   - Zone 3 (Trims/Iron):      Wrought Iron (#111111)
--   - Zone 4 (Cloud Bank):      `Zone4_CloudBank`, smoky charcoal-grey cumulus that keeps its own shading
--   - Sockets: `Bridge_Snap_Point`, `VFX_Fog_Base`, `VFX_Storm_Peak`, `VFX_Window_Glow`

local TowerBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
TowerBuilder.Config = {
	-- Position & Overall Scale
	CenterPosition = Vector3.new(0, 16, 0), -- Sits at center of map (Y=16 matches TowerWalkwayY & arrival bridge)
	BaseDiameter = 186, -- Legacy config reference
	TopDiameter = 186, -- Legacy config reference
	TowerDiameter = 650, -- World footprint diameter in studs (radius = 325, snaps to TowerHubArrival at Z = -325..-358)
	TowerHeight = 900, -- Legacy config reference; the real height follows from the segments, crown and spire
	MidSegmentCount = 8, -- Number of stacked `Tower_Mid_Segment` modules (each has 2 stories of pointed gothic windows)
	-- Stepped silhouette: how many mid segments each stage holds, and that stage's diameter.
	-- Stage 1 must stay at TowerDiameter so the gate and Hub Bridge still line up.
	StageSegmentCounts = { 3, 3, 2 },
	StageDiameters = { 650, 584, 516 },

	-- Crown above the last stage
	CrownInset = 36, -- How far the lantern drum steps in from the top stage's wall
	CrownLanternHeight = 104,
	CrownBays = 8, -- Lantern windows, and pinnacle turrets between them
	GreatSpireHeight = 420,
	GreatSpireSteps = 28,
	SkyBeamHeight = 1100,

	-- Floating crag under the ground slab: { diameter, height } tiers from the slab downward
	CragTiers = { { 780, 30 }, { 700, 42 }, { 575, 52 }, { 425, 62 }, { 270, 70 }, { 130, 64 } },
	CragShardCount = 14,
	CragColor = Color3.fromRGB(33, 29, 37),
	CragDeepColor = Color3.fromRGB(22, 19, 26),
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
	Zone4CloudMaterial = Enum.Material.Sand, -- matte: SmoothPlastic puts a glossy highlight on every dark puff

	-- Cloud bank below the tower (`Cloud_Ring_Bottom`). Each ring is a circle of cumulus clouds:
	-- TopOffset is the highest a cloud top reaches relative to the tower's ground level.
	CloudSeed = 20261112,
	-- Smoky charcoal grey: light enough to stand out against the black void below the hub
	CloudTopColor = Color3.fromRGB(124, 121, 132),
	CloudBodyColor = Color3.fromRGB(92, 89, 100),
	CloudShadowColor = Color3.fromRGB(54, 52, 62),
	-- Counts are high enough that neighbouring clouds overlap into one continuous bank
	CloudRings = {
		{ Count = 16, Radius = 525, Jitter = 12, ScaleMin = 1.0, ScaleMax = 1.25, TopOffset = 20, Phase = 0 },
		{ Count = 20, Radius = 650, Jitter = 28, ScaleMin = 0.85, ScaleMax = 1.1, TopOffset = -8, Phase = 0.5 },
		{ Count = 14, Radius = 790, Jitter = 40, ScaleMin = 0.6, ScaleMax = 0.85, TopOffset = -50, Phase = 0.25 },
	},
	-- No clouds where the hub is: in front of this Z (relative to the tower) and within this half-width.
	-- The Commons starts near Z = -300 and the plot islands reach X = ±552.
	CloudHubClearZ = -300,
	CloudHubClearHalfWidth = 700,

	-- Storm Clouds & Ember Particles
	DarkCloudColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(34, 32, 42)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(52, 36, 46)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(22, 20, 28)),
	}),
	LowerMistColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(116, 113, 124)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(86, 83, 94)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(56, 54, 64)),
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

-- A disc or drum whose round faces point along `faceCF`'s look vector (used for rose windows).
local function makeFacingDisc(props: { [string]: any }, faceCF: CFrame, thickness: number, diameter: number): Part
	local p = makePart(props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, diameter, diameter)
	p.CFrame = faceCF * CFrame.Angles(0, math.pi * 0.5, 0)
	return p
end

-- Builds a round Gothic rose window on the tower wall at `angleRad` (0 faces North / -Z, the Hub Bridge).
local function buildRoseWindowBay(
	parent: Instance,
	cfg: { [string]: any },
	origin: Vector3,
	radius: number,
	angleRad: number,
	centerY: number,
	diameter: number,
	namePrefix: string
)
	local outward = Vector3.new(math.sin(angleRad), 0, -math.cos(angleRad))
	local centerPos = Vector3.new(origin.X, centerY, origin.Z) + outward * (radius + 0.6)
	local faceCF = CFrame.lookAt(centerPos, centerPos + outward) -- local -Z points away from the tower

	makeFacingDisc({
		Name = namePrefix .. "_Surround",
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1AshlarColor,
		Decorative = true,
		Zone = "Zone1_Masonry",
		Parent = parent,
	}, faceCF * CFrame.new(0, 0, 0.4), 3.4, diameter + 8)
	makeFacingDisc({
		Name = namePrefix .. "_Pane",
		Material = cfg.Zone2WindowMaterial,
		Color = cfg.Zone2WindowColor,
		Transparency = 0.08,
		Decorative = true,
		Zone = "Zone2_WindowEmissive",
		Parent = parent,
	}, faceCF * CFrame.new(0, 0, -0.9), 2.2, diameter)
	for barIdx = 0, 1 do
		makePart({
			Name = namePrefix .. "_IronTracery",
			Size = Vector3.new(1.3, diameter * 0.98, 1.4),
			CFrame = faceCF * CFrame.new(0, 0, -2.3) * CFrame.Angles(0, 0, barIdx * math.pi * 0.5),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = parent,
		})
	end
end

-- A thin glowing crimson course running right round the tower at `y`.
local function makeNeonBand(parent: Instance, cfg: { [string]: any }, name: string, origin: Vector3, y: number, diameter: number)
	makeCylinder({
		Name = name,
		Diameter = diameter,
		Height = 1.4,
		Position = Vector3.new(origin.X, y, origin.Z),
		Material = cfg.Zone2WindowMaterial,
		Color = cfg.Zone2WindowColor,
		Decorative = true,
		Zone = "Zone2_WindowEmissive",
		Parent = parent,
	})
end

-- A stepped Gothic spire: stacked drums tapering from `baseDiameter` to `tipDiameter` with a slight
-- concave sweep. Returns the world position of the tip.
local function buildSpireCap(
	parent: Instance,
	cfg: { [string]: any },
	name: string,
	basePos: Vector3,
	baseDiameter: number,
	tipDiameter: number,
	height: number,
	steps: number
): Vector3
	local stepHeight = height / steps
	for step = 1, steps do
		local t = (step - 1) / steps
		local diameter = tipDiameter + (baseDiameter - tipDiameter) * (1 - t) ^ 1.3
		makeCylinder({
			Name = string.format("%s_Tier%02d", name, step),
			Diameter = diameter,
			Height = stepHeight,
			Position = basePos + Vector3.new(0, (step - 0.5) * stepHeight, 0),
			Material = cfg.Zone1MasonryMaterial,
			Color = if step % 2 == 1 then cfg.Zone1MasonryColor else cfg.Zone1AshlarColor,
			Decorative = true,
			Zone = "Zone1_Masonry",
			Parent = parent,
		})
	end
	return basePos + Vector3.new(0, height, 0)
end

--============================================================================
-- CLOUD BANK (`Cloud_Ring_Bottom`)
--============================================================================
-- One soft ellipsoid. A SpecialMesh sphere stretches to the part's Size, so puffs can be flattened.
local function makeCloudPuff(parent: Instance, cfg: { [string]: any }, name: string, size: Vector3, cf: CFrame, color: Color3)
	local puff = makePart({
		Name = name,
		Size = size,
		CFrame = cf,
		Material = cfg.Zone4CloudMaterial,
		Color = color,
		Decorative = true,
		Zone = "Zone4_CloudBank",
		Parent = parent,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = puff
end

-- Height of one cumulus above its flat underside, per unit of scale.
local CUMULUS_HEIGHT = 96

-- One cumulus cloud: a flat shadowed underside, a row of billows that humps in the middle, and a few
-- bright puffs on top. `baseCF` is the centre of the underside; local X is the cloud's long axis.
local function buildCumulus(parent: Instance, cfg: { [string]: any }, rng: Random, name: string, baseCF: CFrame, scale: number)
	local length, depth = 230 * scale, 140 * scale
	-- The underside is tucked inside the billows so it shades the belly without showing as a plate
	makeCloudPuff(
		parent,
		cfg,
		name .. "_Base",
		Vector3.new(length * 0.78, 52 * scale, depth * 0.8),
		baseCF * CFrame.new(0, 8 * scale, 0),
		cfg.CloudShadowColor
	)
	-- Two staggered rows of billows, large in the middle and smaller toward the ends
	for row = -1, 1, 2 do
		local bodyCount = rng:NextInteger(4, 5)
		for i = 1, bodyCount do
			local t = (i - 0.5) / bodyCount - 0.5 + rng:NextNumber(-0.04, 0.04)
			local hump = 1 - math.abs(t) * 1.5
			local size = (62 + 58 * hump + rng:NextNumber(-10, 14)) * scale
			makeCloudPuff(
				parent,
				cfg,
				name .. "_Billow",
				Vector3.new(size * rng:NextNumber(1.05, 1.3), size * rng:NextNumber(0.7, 0.86), size),
				baseCF
					* CFrame.new(t * length, (14 + 20 * hump) * scale, (row * 0.2 + rng:NextNumber(-0.08, 0.08)) * depth)
					* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0),
				cfg.CloudBodyColor
			)
		end
	end
	for _ = 1, rng:NextInteger(2, 3) do
		local size = rng:NextNumber(56, 84) * scale
		makeCloudPuff(
			parent,
			cfg,
			name .. "_Crown",
			Vector3.new(size, size * 0.86, size),
			baseCF * CFrame.new(
				rng:NextNumber(-0.26, 0.26) * length,
				rng:NextNumber(46, 60) * scale,
				rng:NextNumber(-0.15, 0.15) * depth
			),
			cfg.CloudTopColor
		)
	end
end

-- Builds `Cloud_Ring_Bottom`: three staggered rings of cumulus clouds below and around the tower's
-- floating crag, so the tower stands above a cloud bank. The side facing the hub is left open
-- (`CloudHubClearZ`), because the Commons and plot islands stand there.
local function buildCloudBank(parent: Instance, cfg: { [string]: any }, origin: Vector3): Model
	local cloudModel = Instance.new("Model")
	cloudModel.Name = "Cloud_Ring_Bottom"

	local rootPos = origin + Vector3.new(0, -40, 0)
	local root = makePart({
		Name = "Cloud_Ring_Bottom_Root",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(rootPos),
		Transparency = 1,
		Decorative = true,
		Parent = cloudModel,
	})
	cloudModel.PrimaryPart = root
	makeAttachment(root, "VFX_Fog_Base", rootPos)

	local rng = Random.new(cfg.CloudSeed)
	local cloudIndex = 0
	for ringIdx, ring in ipairs(cfg.CloudRings) do
		for i = 1, ring.Count do
			cloudIndex += 1
			local ang = ((i - 1 + ring.Phase) / ring.Count) * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
			local sa, ca = math.sin(ang), -math.cos(ang) -- angle 0 faces the gate (-Z)
			local scale = rng:NextNumber(ring.ScaleMin, ring.ScaleMax)
			local dist = ring.Radius + rng:NextNumber(-ring.Jitter, ring.Jitter)
			local topY = origin.Y + ring.TopOffset
			local basePos = Vector3.new(origin.X + sa * dist, topY - CUMULUS_HEIGHT * scale, origin.Z + ca * dist)
			-- The Cloister Commons and the plot islands sit in front of the gate; leave that side open
			-- rather than push clouds through their decks and trees.
			if basePos.Z - origin.Z < cfg.CloudHubClearZ and math.abs(basePos.X - origin.X) < cfg.CloudHubClearHalfWidth then
				continue
			end
			local baseCF = CFrame.lookAt(basePos, Vector3.new(origin.X, basePos.Y, origin.Z))
				* CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
			buildCumulus(cloudModel, cfg, rng, string.format("Cloud_%d_%02d", ringIdx, i), baseCF, scale)

			-- Every cloud carries a socket: the client wraps it in soft mist so the puffs lose their hard edges
			makeAttachment(root, string.format("VFX_Fog_Base_%02d", cloudIndex), basePos + Vector3.new(0, 34 * scale, 0))
		end
		task.wait()
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

	-- Floating crag: tapered rock under the slab, so the tower stands on an island rather than a disc
	local cragFolder = Instance.new("Folder")
	cragFolder.Name = "FloatingCrag"
	cragFolder.Parent = towerModel

	local cragY = origin.Y - 1.6 -- underside of the ground slab
	local cragRng = Random.new(cfg.CloudSeed + 1)
	for tierIdx, tier in ipairs(cfg.CragTiers) do
		local tierDiameter: number, tierHeight: number = tier[1], tier[2]
		makeCylinder({
			Name = string.format("CragTier_%02d", tierIdx),
			Diameter = tierDiameter,
			Height = tierHeight,
			Position = Vector3.new(origin.X, cragY - tierHeight * 0.5, origin.Z),
			Material = Enum.Material.Slate,
			Color = if tierIdx % 2 == 1 then cfg.CragColor else cfg.CragDeepColor,
			Decorative = true,
			Parent = cragFolder,
		})
		cragY -= tierHeight
	end
	for shardIdx = 1, cfg.CragShardCount do
		-- Jagged shards hanging off the upper tiers break up the stacked-drum outline
		local ang = ((shardIdx - 1) / cfg.CragShardCount) * math.pi * 2 + cragRng:NextNumber(-0.12, 0.12)
		local dist = cragRng:NextNumber(230, 365)
		local length = cragRng:NextNumber(70, 130)
		local width = cragRng:NextNumber(34, 62)
		makePart({
			Name = string.format("CragShard_%02d", shardIdx),
			Size = Vector3.new(width, length, width * cragRng:NextNumber(0.7, 1)),
			CFrame = CFrame.new(origin.X + math.cos(ang) * dist, origin.Y - 20 - length * 0.5, origin.Z + math.sin(ang) * dist)
				* CFrame.Angles(cragRng:NextNumber(-0.22, 0.22), cragRng:NextNumber(0, math.pi), cragRng:NextNumber(-0.22, 0.22)),
			Material = Enum.Material.Slate,
			Color = if shardIdx % 2 == 0 then cfg.CragColor else cfg.CragDeepColor,
			Decorative = true,
			Parent = cragFolder,
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
	-- Twin round gate turrets with iron collars, glowing arrow slits and stepped spires
	local turretDiameter = 26
	local turretHeight = cfg.EntranceHeight + 58
	local turretZ = cfg.GatehouseFrontZ + 2
	for _, signX in ipairs({ -1, 1 }) do
		local sideName = if signX < 0 then "Left" else "Right"
		local turretX = origin.X + signX * (cfg.EntranceWidth * 0.5 + turretDiameter * 0.5 + 2)
		makeCylinder({
			Name = "EntrancePillar_" .. sideName,
			Diameter = turretDiameter,
			Height = turretHeight,
			Position = Vector3.new(turretX, origin.Y + turretHeight * 0.5, turretZ),
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1MasonryColor,
			Decorative = false,
			Zone = "Zone1_Masonry",
			Parent = entranceModel,
		})
		for collarIdx, collarY in ipairs({ origin.Y + cfg.EntranceHeight + 8, origin.Y + turretHeight - 2.5 }) do
			makeCylinder({
				Name = string.format("EntranceTurretIronCollar_%s_%d", sideName, collarIdx),
				Diameter = turretDiameter + 5,
				Height = 4,
				Position = Vector3.new(turretX, collarY, turretZ),
				Material = cfg.Zone3IronMaterial,
				Color = cfg.Zone3IronColor,
				Decorative = true,
				Zone = "Zone3_WroughtIron",
				Parent = entranceModel,
			})
		end
		makePart({
			Name = "EntranceTurretSlit_" .. sideName,
			Size = Vector3.new(3, 24, 1.4),
			CFrame = CFrame.new(turretX, origin.Y + cfg.EntranceHeight + 32, turretZ - turretDiameter * 0.5 - 0.2),
			Material = cfg.Zone2WindowMaterial,
			Color = cfg.Zone2WindowColor,
			Transparency = 0.08,
			Decorative = true,
			Zone = "Zone2_WindowEmissive",
			Parent = entranceModel,
		})
		local turretTip = buildSpireCap(
			entranceModel,
			cfg,
			"EntranceTurretSpire_" .. sideName,
			Vector3.new(turretX, origin.Y + turretHeight, turretZ),
			turretDiameter + 6,
			2.5,
			52,
			5
		)
		makePart({
			Name = "EntranceSpireFinial_" .. sideName,
			Size = Vector3.new(2.4, 22, 2.4),
			CFrame = CFrame.new(turretTip + Vector3.new(0, 9, 0)),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = entranceModel,
		})
	end

	-- Gable wall between the turrets, carrying a rose window over the gate
	local gableBottomY = origin.Y + cfg.EntranceHeight + 12
	local gableHeight = 44
	local gableFrontZ = cfg.GatehouseFrontZ - 2
	makePart({
		Name = "EntranceGableWall",
		Size = Vector3.new(cfg.EntranceWidth + 8, gableHeight, 12),
		CFrame = CFrame.new(origin.X, gableBottomY + gableHeight * 0.5, gableFrontZ + 6),
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1MasonryColor,
		Decorative = true,
		Zone = "Zone1_Masonry",
		Parent = entranceModel,
	})
	do
		local rosePos = Vector3.new(origin.X, gableBottomY + gableHeight * 0.52, gableFrontZ)
		local roseFaceCF = CFrame.lookAt(rosePos, rosePos + Vector3.new(0, 0, -1))
		makeFacingDisc({
			Name = "EntranceRoseWindow_Surround",
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1AshlarColor,
			Decorative = true,
			Zone = "Zone1_Masonry",
			Parent = entranceModel,
		}, roseFaceCF, 3, 34)
		makeFacingDisc({
			Name = "EntranceRoseWindow_Pane",
			Material = cfg.Zone2WindowMaterial,
			Color = cfg.Zone2WindowColor,
			Transparency = 0.08,
			Decorative = true,
			Zone = "Zone2_WindowEmissive",
			Parent = entranceModel,
		}, roseFaceCF * CFrame.new(0, 0, -1.2), 2, 26)
		for spokeIdx = 0, 3 do
			makePart({
				Name = "EntranceRoseWindow_IronTracery",
				Size = Vector3.new(1.2, 26, 1.4),
				CFrame = roseFaceCF * CFrame.new(0, 0, -2.5) * CFrame.Angles(0, 0, spokeIdx * math.pi * 0.25),
				Material = cfg.Zone3IronMaterial,
				Color = cfg.Zone3IronColor,
				Decorative = true,
				Zone = "Zone3_WroughtIron",
				Parent = entranceModel,
			})
		end
	end
	-- Steep gable roof and iron apex finial
	local gableTopY = gableBottomY + gableHeight
	for _, signX in ipairs({ -1, 1 }) do
		local spanW = cfg.EntranceWidth * 0.5 + 6
		local riseH = 30
		makePart({
			Name = signX < 0 and "EntranceGableRoof_L" or "EntranceGableRoof_R",
			Size = Vector3.new(math.sqrt(spanW * spanW + riseH * riseH) + 2, 5, 14),
			CFrame = CFrame.new(origin.X + signX * (spanW * 0.5), gableTopY + riseH * 0.5 - 2, gableFrontZ + 6)
				* CFrame.Angles(0, 0, -signX * math.atan2(riseH, spanW)),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = entranceModel,
		})
	end
	makePart({
		Name = "EntranceGableFinial",
		Size = Vector3.new(2.4, 24, 2.4),
		CFrame = CFrame.new(origin.X, gableTopY + 38, gableFrontZ + 6),
		Material = cfg.Zone3IronMaterial,
		Color = cfg.Zone3IronColor,
		Decorative = true,
		Zone = "Zone3_WroughtIron",
		Parent = entranceModel,
	})

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
	-- 3. MODULE 2 STACK: `Tower_Mid_Segment` stacked in stepped stages
	--    Each stage is narrower than the one below (`StageDiameters`), with a battlemented gallery
	--    and flying buttresses at every setback. Also fills `TowerRings`
	--    (`TowerRingCore_NN` & `TowerRingLedge_NN`), which `TowerTraversalSetup` makes solid.
	--========================================================================
	local ringsFolder = Instance.new("Folder")
	ringsFolder.Name = "TowerRings"
	ringsFolder.Parent = towerModel

	local midStackFolder = Instance.new("Folder")
	midStackFolder.Name = "Tower_Mid_Segments"
	midStackFolder.Parent = towerModel

	local storyHeight = cfg.MidSegmentHeight * 0.5 -- 48 studs per window story

	-- Stage of each mid segment; segments past the configured counts stay in the last stage.
	local stageCount = #cfg.StageDiameters
	local stageOfSegment: { number } = {}
	do
		local stage, usedInStage = 1, 0
		for segIdx = 1, cfg.MidSegmentCount do
			if stage < stageCount and usedInStage >= (cfg.StageSegmentCounts[stage] or math.huge) then
				stage += 1
				usedInStage = 0
			end
			usedInStage += 1
			stageOfSegment[segIdx] = stage
		end
	end

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
	makeNeonBand(baseSegmentModel, cfg, "BaseCrimsonCourse", origin, origin.Y + cfg.BaseHeight - 5.6, cfg.TowerDiameter + 11)

	-- Battlements standing on a gallery ledge, set between the buttress lines.
	local function buildBattlements(parent: Instance, name: string, ringRadius: number, floorY: number)
		local merlonCount = bayCount * 2
		for merlonIdx = 1, merlonCount do
			local ang = (merlonIdx / merlonCount) * math.pi * 2
			local pos = Vector3.new(origin.X + math.sin(ang) * ringRadius, floorY + 4, origin.Z - math.cos(ang) * ringRadius)
			makePart({
				Name = string.format("%s_%02d", name, merlonIdx),
				Size = Vector3.new(ringRadius * 0.11, 8, 4.5),
				CFrame = CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z)),
				Material = cfg.Zone1MasonryMaterial,
				Color = cfg.Zone1AshlarColor,
				Decorative = true,
				Zone = "Zone1_Masonry",
				Parent = parent,
			})
		end
	end

	for segIdx = 1, cfg.MidSegmentCount do
		local segBaseY = origin.Y + cfg.BaseHeight + (segIdx - 1) * cfg.MidSegmentHeight
		local segTopY = segBaseY + cfg.MidSegmentHeight
		local stage = stageOfSegment[segIdx]
		local segDiameter: number = cfg.StageDiameters[stage]
		local segRadius = segDiameter * 0.5
		local nextStage = stageOfSegment[segIdx + 1]
		local isStageTop = nextStage ~= stage -- also true for the last segment
		local upperRadius: number? = if nextStage and nextStage ~= stage then cfg.StageDiameters[nextStage] * 0.5 else nil

		local segModel = Instance.new("Model")
		segModel.Name = string.format("Tower_Mid_Segment_%02d", segIdx)
		segModel:SetAttribute("SegmentIndex", segIdx)
		segModel:SetAttribute("Stage", stage)
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

			-- Dark-Slate Cylindrical Core (`Zone 1: #18151D`)
			makeCylinder({
				Name = string.format("TowerRingCore_%02d", ringIdx),
				Diameter = segDiameter,
				Height = storyHeight,
				Position = Vector3.new(origin.X, tierCenterY, origin.Z),
				Material = cfg.Zone1MasonryMaterial,
				Color = cfg.Zone1MasonryColor,
				Decorative = true,
				Zone = "Zone1_Masonry",
				Parent = ringsFolder,
			})

			-- Overhanging Gothic Gallery Cornice; the top of a stage gets a wide walkway gallery
			local isMajorGallery = (localTier == 2)
			local isSetbackGallery = isMajorGallery and isStageTop
			local ledgeOverhang = if isSetbackGallery then 30 elseif isMajorGallery then 18 else 10
			makeCylinder({
				Name = string.format("TowerRingLedge_%02d", ringIdx),
				Diameter = segDiameter + ledgeOverhang,
				Height = if isSetbackGallery then 6.0 elseif isMajorGallery then 4.8 else 3.0,
				Position = Vector3.new(origin.X, tierTopY - 1.8, origin.Z),
				Material = if isMajorGallery then cfg.Zone3IronMaterial else cfg.Zone1MasonryMaterial,
				Color = if isMajorGallery then cfg.Zone3IronColor else cfg.Zone1AshlarColor,
				Decorative = true,
				Zone = if isMajorGallery then "Zone3_WroughtIron" else "Zone1_Masonry",
				Parent = ringsFolder,
			})

			-- Lower story: a lancet window in every bay. Upper story: balconied lancets alternate
			-- with round rose windows so the wall has a rhythm instead of one repeated column.
			for bayIdx = 1, bayCount do
				local bayAngle = ((bayIdx - 1) / bayCount) * math.pi * 2
				local windowName = string.format("Window_%02d_%02d", ringIdx, bayIdx)
				if localTier == 2 and bayIdx % 2 == 0 then
					buildRoseWindowBay(segModel, cfg, origin, segRadius, bayAngle, tierBotY + storyHeight * 0.48, 19, windowName)
				else
					local addGlowSocket = (bayIdx % 4 == 1) and (localTier == 1)
					buildGothicWindowBay(
						segModel,
						cfg,
						origin,
						segRadius,
						bayAngle,
						tierBotY + 5.5,
						23,
						storyHeight - 12,
						isMajorGallery,
						windowName,
						if addGlowSocket then segRoot else nil
					)
				end
			end
		end

		-- Vertical Gothic Buttresses, Iron Pinnacles & Gargoyle Spurs along the Segment
		local pierRise = if upperRadius then 34 else 0 -- buttress piers rise above a setback gallery
		for bayIdx = 1, bayCount do
			local ribAngle = ((bayIdx - 0.5) / bayCount) * math.pi * 2
			local rSa, rCa = math.sin(ribAngle), -math.cos(ribAngle)
			local ribHeight = cfg.MidSegmentHeight + pierRise
			local ribPos = Vector3.new(
				origin.X + rSa * (segRadius + 5.0),
				segBaseY + ribHeight * 0.5,
				origin.Z + rCa * (segRadius + 5.0)
			)
			makePart({
				Name = string.format("GothicButtress_%02d_%02d", segIdx, bayIdx),
				Size = Vector3.new(9.5, ribHeight, 12.5),
				CFrame = CFrame.lookAt(ribPos, Vector3.new(origin.X, ribPos.Y, origin.Z)),
				Material = cfg.Zone1MasonryMaterial,
				Color = cfg.Zone1AshlarColor,
				Decorative = true,
				Zone = "Zone1_Masonry",
				Parent = segModel,
			})

			-- Wrought-Iron Spire Pinnacle & Outward Gargoyle Spur at Segment Crown (`Zone 3: #111111`)
			local crownPos = Vector3.new(
				origin.X + rSa * (segRadius + 11.5),
				segTopY,
				origin.Z + rCa * (segRadius + 11.5)
			)
			local pinnaclePos = Vector3.new(
				origin.X + rSa * (segRadius + (if upperRadius then 5.0 else 11.5)),
				segTopY + pierRise + 6,
				origin.Z + rCa * (segRadius + (if upperRadius then 5.0 else 11.5))
			)
			makePart({
				Name = string.format("IronButtressSpire_%02d_%02d", segIdx, bayIdx),
				Size = Vector3.new(4.2, if upperRadius then 22 else 16, 4.2),
				CFrame = CFrame.lookAt(pinnaclePos, Vector3.new(origin.X, pinnaclePos.Y, origin.Z)),
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

			-- Flying buttress: leaps from the pier head across the gallery to the narrower stage above
			if upperRadius then
				local footPos = Vector3.new(origin.X + rSa * (segRadius + 2), segTopY + 28, origin.Z + rCa * (segRadius + 2))
				local headPos = Vector3.new(origin.X + rSa * (upperRadius + 1), segTopY + 66, origin.Z + rCa * (upperRadius + 1))
				makePart({
					Name = string.format("FlyingButtress_%02d_%02d", segIdx, bayIdx),
					Size = Vector3.new(6, 7, (headPos - footPos).Magnitude + 6),
					CFrame = CFrame.lookAt((footPos + headPos) * 0.5, headPos),
					Material = cfg.Zone1MasonryMaterial,
					Color = cfg.Zone1AshlarColor,
					Decorative = true,
					Zone = "Zone1_Masonry",
					Parent = segModel,
				})
			end
		end

		if isStageTop then
			buildBattlements(segModel, string.format("GalleryMerlon_%02d", segIdx), segRadius + 12.5, segTopY + 1.2)
			makeNeonBand(segModel, cfg, string.format("GalleryCrimsonCourse_%02d", segIdx), origin, segTopY - 6.2, segDiameter + 20)
		end

		if segIdx % 2 == 0 then
			task.wait()
		end
	end

	--========================================================================
	-- 4. `Tower_Crown`: lantern drum, ring of pinnacle turrets, great spire and sky beacon
	--========================================================================
	local totalStackTopY = origin.Y + cfg.BaseHeight + cfg.MidSegmentCount * cfg.MidSegmentHeight
	local topStageRadius: number = cfg.StageDiameters[stageOfSegment[cfg.MidSegmentCount] or stageCount] * 0.5
	local lanternRadius = topStageRadius - cfg.CrownInset
	local lanternTopY = totalStackTopY + cfg.CrownLanternHeight

	local crownModel = Instance.new("Model")
	crownModel.Name = "Tower_Crown"
	crownModel.Parent = towerModel

	local crownRoot = makePart({
		Name = "CrownOriginRoot",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(origin.X, totalStackTopY, origin.Z),
		Transparency = 1,
		Decorative = true,
		Parent = crownModel,
	})
	crownModel.PrimaryPart = crownRoot

	makeCylinder({
		Name = "CrownLanternDrum",
		Diameter = lanternRadius * 2,
		Height = cfg.CrownLanternHeight,
		Position = Vector3.new(origin.X, totalStackTopY + cfg.CrownLanternHeight * 0.5, origin.Z),
		Material = cfg.Zone1MasonryMaterial,
		Color = cfg.Zone1MasonryColor,
		Decorative = true,
		Zone = "Zone1_Masonry",
		Parent = crownModel,
	})
	makeCylinder({
		Name = "CrownIronCornice",
		Diameter = lanternRadius * 2 + 22,
		Height = 5,
		Position = Vector3.new(origin.X, lanternTopY - 2.5, origin.Z),
		Material = cfg.Zone3IronMaterial,
		Color = cfg.Zone3IronColor,
		Decorative = true,
		Zone = "Zone3_WroughtIron",
		Parent = crownModel,
	})
	makeNeonBand(crownModel, cfg, "CrownCrimsonCourse", origin, lanternTopY - 6.4, lanternRadius * 2 + 12)

	local crownBays = cfg.CrownBays
	for crownIdx = 1, crownBays do
		-- Tall lantern windows between the turrets
		buildGothicWindowBay(
			crownModel,
			cfg,
			origin,
			lanternRadius,
			((crownIdx - 1) / crownBays) * math.pi * 2,
			totalStackTopY + 12,
			30,
			cfg.CrownLanternHeight - 30,
			false,
			string.format("CrownWindow_%02d", crownIdx),
			if crownIdx % 2 == 1 then crownRoot else nil
		)

		-- Pinnacle turret with its own stepped spire
		local turretAngle = ((crownIdx - 0.5) / crownBays) * math.pi * 2
		local turretBase = Vector3.new(
			origin.X + math.sin(turretAngle) * (lanternRadius + 8),
			totalStackTopY,
			origin.Z - math.cos(turretAngle) * (lanternRadius + 8)
		)
		local turretHeight = cfg.CrownLanternHeight + 34
		makeCylinder({
			Name = string.format("CrownTurret_%02d", crownIdx),
			Diameter = 34,
			Height = turretHeight,
			Position = turretBase + Vector3.new(0, turretHeight * 0.5, 0),
			Material = cfg.Zone1MasonryMaterial,
			Color = cfg.Zone1AshlarColor,
			Decorative = true,
			Zone = "Zone1_Masonry",
			Parent = crownModel,
		})
		makeCylinder({
			Name = string.format("CrownTurretIronCollar_%02d", crownIdx),
			Diameter = 40,
			Height = 4,
			Position = turretBase + Vector3.new(0, turretHeight - 2, 0),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = crownModel,
		})
		local turretTip = buildSpireCap(
			crownModel,
			cfg,
			string.format("CrownTurretSpire_%02d", crownIdx),
			turretBase + Vector3.new(0, turretHeight, 0),
			38,
			3,
			84,
			6
		)
		makePart({
			Name = string.format("CrownTurretIronFinial_%02d", crownIdx),
			Size = Vector3.new(2.2, 26, 2.2),
			CFrame = CFrame.new(turretTip + Vector3.new(0, 11, 0)),
			Material = cfg.Zone3IronMaterial,
			Color = cfg.Zone3IronColor,
			Decorative = true,
			Zone = "Zone3_WroughtIron",
			Parent = crownModel,
		})
	end
	buildBattlements(crownModel, "CrownMerlon", topStageRadius + 12.5, totalStackTopY + 1.2)

	-- Great spire over the lantern, tipped with an iron finial and the crimson sky beacon
	local spireTip = buildSpireCap(
		crownModel,
		cfg,
		"GreatSpire",
		Vector3.new(origin.X, lanternTopY, origin.Z),
		lanternRadius * 2 + 16,
		10,
		cfg.GreatSpireHeight,
		cfg.GreatSpireSteps
	)
	makePart({
		Name = "GreatSpireIronFinial",
		Size = Vector3.new(4.5, 64, 4.5),
		CFrame = CFrame.new(spireTip + Vector3.new(0, 30, 0)),
		Material = cfg.Zone3IronMaterial,
		Color = cfg.Zone3IronColor,
		Decorative = true,
		Zone = "Zone3_WroughtIron",
		Parent = crownModel,
	})
	local beaconPos = spireTip + Vector3.new(0, 70, 0)
	makePart({
		Name = "SkyBeaconOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(24, 24, 24),
		CFrame = CFrame.new(beaconPos),
		Material = cfg.Zone2WindowMaterial,
		Color = cfg.Zone2WindowColor,
		Decorative = true,
		Zone = "Zone2_WindowEmissive",
		Parent = crownModel,
	})
	-- The beam carries on upward out of sight: the tower has no visible end
	makeCylinder({
		Name = "SkyBeaconBeam",
		Diameter = 5,
		Height = cfg.SkyBeamHeight,
		Position = beaconPos + Vector3.new(0, cfg.SkyBeamHeight * 0.5, 0),
		Material = cfg.Zone2WindowMaterial,
		Color = cfg.Zone2WindowColor,
		Transparency = 0.55,
		Decorative = true,
		Zone = "Zone2_WindowEmissive",
		Parent = crownModel,
	})
	makeAttachment(crownRoot, "VFX_Storm_Peak", Vector3.new(origin.X, lanternTopY + cfg.GreatSpireHeight * 0.35, origin.Z))

	task.wait()

	--========================================================================
	-- 5. `Cloud_Ring_Bottom`: cumulus cloud bank below the tower, with `VFX_Fog_Base` sockets
	--========================================================================
	buildCloudBank(towerModel, cfg, origin)

	--========================================================================
	-- 6. Server-Baseline Atmospheric Mist, Storm & Ember Emitters (`TowerStormVFX`)
	--========================================================================
	local vfxFolder = Instance.new("Folder")
	vfxFolder.Name = "TowerStormVFX"
	vfxFolder.Parent = towerModel

	local stackHeight = totalStackTopY - origin.Y
	for i, bandY in ipairs({
		origin.Y - 30, -- charcoal smoke drifting through the cloud bank
		origin.Y + stackHeight * 0.42,
		origin.Y + stackHeight * 0.72,
		lanternTopY,
	}) do
		local isCloudMist = (i == 1)
		local bandWidth = if isCloudMist then cfg.CrackedGroundDiameter else cfg.TowerDiameter * 0.92
		local emitterPart = makePart({
			Name = string.format("StormEmitterBand_%d", i),
			Size = Vector3.new(bandWidth, 6, bandWidth),
			CFrame = CFrame.new(origin.X, bandY, origin.Z),
			Transparency = 1,
			Decorative = true,
			Parent = vfxFolder,
		})

		local darkClouds = Instance.new("ParticleEmitter")
		darkClouds.Name = if isCloudMist then "DriftingCloudMist" else "SwirlingDarkClouds"
		darkClouds.Texture = "rbxassetid://243660364"
		darkClouds.Color = if isCloudMist then cfg.LowerMistColor else cfg.DarkCloudColor
		darkClouds.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.25, if isCloudMist then 0.6 else 0.32),
			NumberSequenceKeypoint.new(0.75, if isCloudMist then 0.68 else 0.42),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		darkClouds.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 42),
			NumberSequenceKeypoint.new(0.5, 68),
			NumberSequenceKeypoint.new(1.0, 88),
		})
		darkClouds.Lifetime = NumberRange.new(8, 12)
		darkClouds.Rate = if isCloudMist then 6 else 10
		darkClouds.Speed = if isCloudMist then NumberRange.new(3, 8) else NumberRange.new(6, 14)
		darkClouds.SpreadAngle = Vector2.new(180, 15)
		darkClouds.Rotation = NumberRange.new(0, 360)
		darkClouds.RotSpeed = NumberRange.new(-20, 20)
		darkClouds.Parent = emitterPart

		if not isCloudMist then
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
	end

	towerModel:SetAttribute("TowerArchitectureVersion", 3)
	towerModel:SetAttribute("MidSegmentCount", cfg.MidSegmentCount)
	towerModel:SetAttribute("BridgeSnapPoint", Vector3.new(origin.X, origin.Y, cfg.BridgeSnapPointZ))

	if parent then
		towerModel.Parent = parent
	end

	return towerModel
end

return TowerBuilder
