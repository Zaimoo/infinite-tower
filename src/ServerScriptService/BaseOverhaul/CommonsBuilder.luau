--!strict
-- CommonsBuilder.luau
-- ModuleScript: builds The Masters' Commons, the round public park in front of the tower gate
-- that the 6 fortress plots surround (GDD §3.5, docs/commons-hub-layout-plan.md §4).
-- Park-local frame: origin at HubLayout.ParkCentre, y = 0 is the walking surface (world Y = 12),
-- -Z is north (away from the tower), +Z is south (toward the tower gate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local HubLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout"))
local PartKit = require(script.Parent:WaitForChild("PartKit"))

local CommonsBuilder = {}

--============================================================================
-- CONFIGURATION TABLE
--============================================================================
CommonsBuilder.Config = {
	RandomSeed = 6502026,
	TopThickness = 6,
	RimBandWidth = 10,
	UndersideDepth = 140,
	UndersideLayers = 6,
	OuterSpireCount = 16,
	InnerStalactiteCount = 10,

	WallRadius = 167,
	WallHeight = 3.5,
	WallStepDeg = 5,
	BarrierHeight = 12,
	LampRadius = 162,
	LoopInner = 138,
	LoopOuter = 156,
	PathInner = 40,
	PathWidth = 10,
	PlazaRadius = 36,

	-- Banner colour per plot (Plot_1 .. Plot_6), shown on each gate landing
	PlotColors = {
		Color3.fromRGB(196, 58, 58),
		Color3.fromRGB(214, 142, 46),
		Color3.fromRGB(206, 190, 70),
		Color3.fromRGB(70, 160, 92),
		Color3.fromRGB(66, 128, 204),
		Color3.fromRGB(150, 86, 196),
	},
}

-- Palette
local GRASS = Color3.fromRGB(64, 92, 52)
local SLATE = Color3.fromRGB(58, 62, 68)
local SLATE_DARK = Color3.fromRGB(40, 42, 48)
local COBBLE = Color3.fromRGB(92, 88, 84)
local MARBLE = Color3.fromRGB(200, 196, 188)
local STATUE = Color3.fromRGB(222, 218, 208)
local CRIMSON = Color3.fromRGB(145, 28, 38)
local CYAN = Color3.fromRGB(80, 220, 255)
local IRON = Color3.fromRGB(40, 40, 44)
local WOOD = Color3.fromRGB(92, 64, 42)
local HEDGE = Color3.fromRGB(40, 70, 38)
local LANTERN = Color3.fromRGB(255, 196, 120)
local ROCK_UPPER = Color3.fromRGB(65, 68, 72)
local ROCK_DEEP = Color3.fromRGB(42, 45, 50)

-- One tint per tower biome, in floor order (MobCatalog.Biomes)
local BIOME_COLORS = {
	Color3.fromRGB(88, 170, 82), -- Verdant Ruins
	Color3.fromRGB(150, 92, 190), -- Fungal Hollow
	Color3.fromRGB(214, 184, 120), -- Ashen Dunes
	Color3.fromRGB(150, 210, 240), -- Frozen Citadel
	Color3.fromRGB(240, 120, 40), -- Infernal Foundry
	Color3.fromRGB(240, 200, 60), -- Thunder Highlands
	Color3.fromRGB(110, 50, 100), -- Corrupted Grove
	Color3.fromRGB(50, 170, 160), -- Sunken Sanctuary
	Color3.fromRGB(140, 110, 240), -- Astral Archives
	Color3.fromRGB(190, 30, 46), -- Abyssal Throne
}

--============================================================================
-- HELPER FUNCTIONS
--============================================================================
local makePart = PartKit.Part
local makeWedge = PartKit.Wedge

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Park-local (x, z) for a bearing in degrees and a radius.
local function polar(deg: number, r: number): (number, number)
	local dx, dz = HubLayout.BearingDir(deg)
	return dx * r, dz * r
end

-- Smallest signed difference between two bearings, in degrees.
local function bearingDelta(a: number, b: number): number
	return (a - b + 540) % 360 - 180
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function cylinderY(name: string, radius: number, height: number, topY: number, cf: CFrame, color: Color3, material: Enum.Material, decorative: boolean, parent: Instance): Part
	return makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = cf * CFrame.new(0, topY - height * 0.5, 0) * CFrame.Angles(0, 0, math.pi * 0.5),
		Color = color,
		Material = material,
		Decorative = decorative,
		Parent = parent,
	})
end

-- Openings in the rim wall: one per plot bridge plus the South Gate.
local function rimOpenings(cfg: typeof(CommonsBuilder.Config)): { { number } }
	local list = {}
	local plotHalf = math.deg(math.asin((HubLayout.PlotGateWidth * 0.5) / cfg.WallRadius))
	for _, deg in HubLayout.PlotBearingsDeg do
		table.insert(list, { deg % 360, plotHalf })
	end
	local southHalf = math.deg(math.asin((HubLayout.SouthGateWidth * 0.5) / cfg.WallRadius))
	table.insert(list, { HubLayout.SouthGateBearingDeg % 360, southHalf })
	table.sort(list, function(a, b)
		return a[1] < b[1]
	end)
	return list
end

-- Calls fn(midDeg, stepDeg) for every wall segment on the closed arcs between openings.
local function forEachRimArc(cfg: typeof(CommonsBuilder.Config), fn: (number, number, number) -> ())
	local openings = rimOpenings(cfg)
	for i, o in openings do
		local nextO = openings[i % #openings + 1]
		local a0 = o[1] + o[2]
		local a1 = nextO[1] - nextO[2]
		if a1 <= a0 then
			a1 += 360
		end
		local n = math.max(1, math.ceil((a1 - a0) / cfg.WallStepDeg))
		local step = (a1 - a0) / n
		for s = 1, n do
			fn(a0 + (s - 0.5) * step, step, s)
		end
	end
end

local function isInOpening(cfg: typeof(CommonsBuilder.Config), deg: number, pad: number): boolean
	for _, o in rimOpenings(cfg) do
		if math.abs(bearingDelta(deg, o[1])) < o[2] + pad then
			return true
		end
	end
	return false
end

-- CFrame on the park at bearing/radius with -Z looking back at the park centre.
local function facingCentre(root: CFrame, deg: number, r: number, y: number): CFrame
	local x, z = polar(deg, r)
	local pos = root * CFrame.new(x, y, z)
	local centre = root * CFrame.new(0, y, 0)
	if r < 0.01 then
		return pos
	end
	return CFrame.lookAt(pos.Position, centre.Position)
end

local function bench(name: string, cf: CFrame, parent: Instance)
	-- cf: seat centre at ground level, -Z is the direction the sitter faces
	makePart({ Name = name .. "_Seat", Size = Vector3.new(6, 0.6, 2), CFrame = cf * CFrame.new(0, 1.6, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = parent })
	makePart({ Name = name .. "_Back", Size = Vector3.new(6, 2, 0.4), CFrame = cf * CFrame.new(0, 2.9, 0.9), Color = SLATE, Material = Enum.Material.Slate, Decorative = true, Parent = parent })
	for _, side in { -1, 1 } do
		makePart({ Name = name .. "_Leg", Size = Vector3.new(0.6, 1.3, 1.6), CFrame = cf * CFrame.new(side * 2.5, 0.65, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = parent })
	end
end

local function flatStrip(name: string, root: CFrame, x0: number, z0: number, x1: number, z1: number, width: number, y: number, thick: number, color: Color3, material: Enum.Material, parent: Instance): Part
	local a = Vector3.new(x0, 0, z0)
	local b = Vector3.new(x1, 0, z1)
	local mid = (a + b) * 0.5
	local len = (b - a).Magnitude
	return makePart({
		Name = name,
		Size = Vector3.new(width, thick, len),
		CFrame = root * CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(b.X, y, b.Z)),
		Color = color,
		Material = material,
		Decorative = true,
		Parent = parent,
	})
end

--============================================================================
-- A. ISLAND MASS
--============================================================================
local function buildIsland(model: Model, root: CFrame, cfg: typeof(CommonsBuilder.Config), rng: Random): Part
	local f = folder("Island", model)
	local r = HubLayout.ParkRadius
	local grassR = r - cfg.RimBandWidth

	local top = cylinderY("CommonsTopSurface", grassR, cfg.TopThickness, 0, root, GRASS, Enum.Material.Grass, false, f)
	cylinderY("CommonsRimBand", r, cfg.TopThickness - 0.1, -0.05, root, SLATE, Enum.Material.Slate, false, f)

	local underside = folder("RockyUnderside", f)
	local currentY = -cfg.TopThickness
	local layerH = (cfg.UndersideDepth * 0.58) / cfg.UndersideLayers
	for layer = 1, cfg.UndersideLayers do
		local t = (layer - 1) / math.max(1, cfg.UndersideLayers - 1)
		local tierR = (r - 5) * (1 - t * 0.76)
		local tier = cylinderY(string.format("RockTier_%d", layer), tierR, layerH + 2, currentY + 1, root, ROCK_UPPER:Lerp(ROCK_DEEP, t), Enum.Material.Slate, true, underside)
		tier.CFrame = tier.CFrame * CFrame.Angles(math.rad(layer * 7), 0, 0)
		currentY -= layerH
	end

	for i = 1, cfg.OuterSpireCount do
		local angle = ((i - 1) / cfg.OuterSpireCount) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local rr = r * 0.86 * rng:NextNumber(0.9, 1.02)
		local h = rng:NextNumber(34, 58)
		makeWedge({
			Name = string.format("OuterCrag_%d", i),
			Size = Vector3.new(rng:NextNumber(18, 28), h, rng:NextNumber(16, 24)),
			CFrame = root
				* CFrame.new(math.cos(angle) * rr, -cfg.TopThickness - h * 0.42, math.sin(angle) * rr)
				* CFrame.Angles(0, -angle + math.pi * 0.5, 0)
				* CFrame.Angles(math.rad(rng:NextNumber(12, 24)), 0, math.pi),
			Color = ROCK_UPPER:Lerp(ROCK_DEEP, rng:NextNumber(0.15, 0.65)),
			Material = Enum.Material.Slate,
			Decorative = true,
			Parent = underside,
		})
	end

	for i = 1, cfg.InnerStalactiteCount do
		local angle = ((i - 1) / cfg.InnerStalactiteCount) * math.pi * 2 + 0.25
		local rr = rng:NextNumber(20, 60)
		local h = rng:NextNumber(42, 68)
		local w = rng:NextNumber(12, 20)
		makeWedge({
			Name = string.format("DeepPoint_%d", i),
			Size = Vector3.new(w, h, w),
			CFrame = root * CFrame.new(math.cos(angle) * rr, currentY - h * 0.3, math.sin(angle) * rr) * CFrame.Angles(math.rad(170), angle, math.rad(rng:NextNumber(-10, 10))),
			Color = ROCK_DEEP,
			Material = Enum.Material.Slate,
			Decorative = true,
			Parent = underside,
		})
	end
	makeWedge({
		Name = "CentralApexSpike",
		Size = Vector3.new(30, 64, 30),
		CFrame = root * CFrame.new(0, -cfg.UndersideDepth + 12, 0) * CFrame.Angles(math.pi, math.rad(45), 0),
		Color = ROCK_DEEP,
		Material = Enum.Material.Slate,
		Decorative = true,
		Parent = underside,
	})

	local cloudAnchor = makePart({ Name = "UndersideCloudEmitter", Size = Vector3.new(4, 1, 4), CFrame = root * CFrame.new(0, -cfg.TopThickness - 22, 0), Transparency = 1, Decorative = true, Parent = underside })
	local clouds = Instance.new("ParticleEmitter")
	clouds.Name = "CloudWisps"
	clouds.Texture = "rbxassetid://243660364"
	clouds.Color = ColorSequence.new(Color3.fromRGB(185, 190, 205), Color3.fromRGB(110, 115, 130))
	clouds.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.78),
		NumberSequenceKeypoint.new(0.75, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	clouds.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(0.5, 28), NumberSequenceKeypoint.new(1, 34) })
	clouds.Lifetime = NumberRange.new(6, 9)
	clouds.Rate = 5
	clouds.Speed = NumberRange.new(2, 5)
	clouds.SpreadAngle = Vector2.new(180, 12)
	clouds.Rotation = NumberRange.new(0, 360)
	clouds.RotSpeed = NumberRange.new(-12, 12)
	clouds.Shape = Enum.ParticleEmitterShape.Cylinder
	clouds.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	clouds.Parent = cloudAnchor

	return top
end

--============================================================================
-- B. RIM BALUSTRADE & C. LAMP PYLONS
--============================================================================
local function buildRim(model: Model, root: CFrame, cfg: typeof(CommonsBuilder.Config))
	local f = folder("RimBalustrade", model)
	local barriers = folder("InvisibleEdgeBarriers", f)
	local R = cfg.WallRadius
	forEachRimArc(cfg, function(mid: number, step: number, index: number)
		local segLen = 2 * R * math.tan(math.rad(step * 0.5)) + 0.4
		local cf = facingCentre(root, mid, R, 0)
		makePart({ Name = "RimWall", Size = Vector3.new(segLen, cfg.WallHeight, 2), CFrame = cf * CFrame.new(0, cfg.WallHeight * 0.5, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
		if index % 2 == 0 then
			makePart({ Name = "RimCrenel", Size = Vector3.new(segLen * 0.5, 1.2, 2.4), CFrame = cf * CFrame.new(0, cfg.WallHeight + 0.6, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
		end
		local barrier = makePart({
			Name = "Barrier",
			Size = Vector3.new(segLen, cfg.BarrierHeight, 1),
			CFrame = cf * CFrame.new(0, cfg.BarrierHeight * 0.5, 1.6),
			Transparency = 1,
			CastShadow = false,
			Parent = barriers,
		})
		barrier.CanQuery = false
		barrier.CanTouch = false
	end)

	local lamps = folder("LampPylons", model)
	local lit = 0
	for i = 0, 23 do
		local deg = 7.5 + i * 15
		if not isInOpening(cfg, deg, 3) then
			local cf = facingCentre(root, deg, cfg.LampRadius, 0)
			makePart({ Name = "LampPost", Size = Vector3.new(1, 9, 1), CFrame = cf * CFrame.new(0, 4.5, 0), Color = IRON, Material = Enum.Material.Metal, Parent = lamps })
			makePart({ Name = "LampCap", Size = Vector3.new(2.2, 0.5, 2.2), CFrame = cf * CFrame.new(0, 9.6, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = lamps })
			local lantern = makePart({ Name = "LampLantern", Size = Vector3.new(1.4, 1.6, 1.4), CFrame = cf * CFrame.new(0, 8.5, 0), Color = LANTERN, Material = Enum.Material.Neon, Decorative = true, Parent = lamps })
			lit += 1
			if lit % 2 == 1 then
				light(lantern, LANTERN, 16, 1.2)
			end
		end
	end
end

--============================================================================
-- D. MASTERS' LOOP, E. GATE LANDINGS, F. RADIAL PATHS
--============================================================================
local function buildLoopAndPaths(model: Model, root: CFrame, cfg: typeof(CommonsBuilder.Config))
	local loop = folder("MastersLoop", model)
	local midR = (cfg.LoopInner + cfg.LoopOuter) * 0.5
	local width = cfg.LoopOuter - cfg.LoopInner
	for i = 0, 47 do
		local deg = i * 7.5
		local len = 2 * cfg.LoopOuter * math.tan(math.rad(3.75)) + 0.4
		makePart({
			Name = "LoopSlab",
			Size = Vector3.new(len, 0.2, width),
			CFrame = facingCentre(root, deg, midR, 0.1),
			Color = if i % 2 == 0 then COBBLE else COBBLE:Lerp(SLATE, 0.25),
			Material = Enum.Material.Cobblestone,
			Decorative = true,
			Parent = loop,
		})
	end

	local landings = folder("GateLandings", model)
	for index, deg in HubLayout.PlotBearingsDeg do
		local g = folder("Gate_" .. index, landings)
		g:SetAttribute("PlotIndex", index)
		local apron = facingCentre(root, deg, 164, 0)
		makePart({ Name = "Apron", Size = Vector3.new(24, 0.24, 16), CFrame = apron * CFrame.new(0, 0.12, 0), Color = COBBLE, Material = Enum.Material.Cobblestone, Decorative = true, Parent = g })
		local rune = cylinderY("GateRune", 4, 0.1, 0.3, apron, CYAN, Enum.Material.Neon, true, g)
		rune.Transparency = 0.35
		for _, side in { -1, 1 } do
			local post = apron * CFrame.new(side * 13, 0, 2)
			makePart({ Name = "BannerPylon", Size = Vector3.new(2, 14, 2), CFrame = post * CFrame.new(0, 7, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = g })
			makePart({ Name = "BannerArm", Size = Vector3.new(0.4, 0.4, 3.6), CFrame = post * CFrame.new(0, 13, -1.8), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = g })
			makePart({ Name = "Banner", Size = Vector3.new(0.2, 7, 3), CFrame = post * CFrame.new(0, 9.3, -2), Color = cfg.PlotColors[index], Material = Enum.Material.Fabric, Decorative = true, Parent = g })
		end
		local tablet = makePart({ Name = "GateTablet", Size = Vector3.new(10, 4, 1), CFrame = apron * CFrame.new(-17, 2.4, -4), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = g })
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Nameplate"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = tablet
		local label = Instance.new("TextLabel")
		label.Name = "OwnerLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(240, 232, 214)
		label.Text = string.format("PLOT %d\nUnclaimed", index)
		label.Parent = gui

		-- F. Radial path with hedges and flower beds, from the plaza edge to the Loop
		local paths = folder("RadialPath_" .. index, model)
		local x0, z0 = polar(deg, cfg.PathInner)
		local x1, z1 = polar(deg, cfg.LoopInner)
		flatStrip("PathSlab", root, x0, z0, x1, z1, cfg.PathWidth, 0.12, 0.24, COBBLE, Enum.Material.Cobblestone, paths)
		local dx, dz = HubLayout.BearingDir(deg)
		local px, pz = -dz, dx -- perpendicular to the path
		local midR = (cfg.PathInner + cfg.LoopInner) * 0.5
		for _, side in { -1, 1 } do
			for _, seg in { { cfg.PathInner + 4, midR - 5 }, { midR + 5, cfg.LoopInner - 2 } } do
				local ax, az = polar(deg, seg[1])
				local bx, bz = polar(deg, seg[2])
				local ox, oz = px * side * 7, pz * side * 7
				flatStrip("Hedge", root, ax + ox, az + oz, bx + ox, bz + oz, 2, 1, 2, HEDGE, Enum.Material.Grass, paths)
				local fx, fz = px * side * 9.5, pz * side * 9.5
				local bed = flatStrip("FlowerBed", root, ax + fx, az + fz, bx + fx, bz + fz, 2, 0.4, 0.8, ({ Color3.fromRGB(220, 90, 120), Color3.fromRGB(240, 210, 90), Color3.fromRGB(160, 120, 220) })[(index + side) % 3 + 1], Enum.Material.Grass, paths)
				bed.Name = "FlowerBed"
			end
		end
	end
end

--============================================================================
-- G. PILGRIM'S WAY & H. SOUTH GATE
--============================================================================
local function buildPilgrimsWay(model: Model, root: CFrame, cfg: typeof(CommonsBuilder.Config))
	local f = folder("PilgrimsWay", model)
	local r0, r1 = cfg.PlazaRadius, HubLayout.ParkRadius
	local w = HubLayout.BoulevardWidth
	flatStrip("Boulevard", root, 0, r0, 0, r1, w, 0.12, 0.24, COBBLE, Enum.Material.Cobblestone, f)
	flatStrip("CrimsonRunner", root, 0, r0 - 2, 0, r1, 10, 0.27, 0.1, CRIMSON, Enum.Material.Granite, f)

	for k = 0, 3 do
		for _, side in { -1, 1 } do
			local bz = 64 + k * 28
			local bx = side * (w * 0.5 + 3)
			makePart({ Name = "BrazierStand", Size = Vector3.new(1.2, 4, 1.2), CFrame = root * CFrame.new(bx, 2, bz), Color = IRON, Material = Enum.Material.Metal, Parent = f })
			local bowl = cylinderY("BrazierBowl", 1.6, 1, 4.6, root * CFrame.new(bx, 0, bz), IRON, Enum.Material.Metal, true, f)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 6
			fire.Color = Color3.fromRGB(255, 140, 40)
			fire.SecondaryColor = Color3.fromRGB(200, 40, 20)
			fire.Parent = bowl
			if side == 1 then
				light(bowl, Color3.fromRGB(255, 150, 70), 18, 1.4)
			end

			local pz = 50 + k * 28
			local pole = root * CFrame.new(bx, 0, pz)
			makePart({ Name = "BannerPole", Size = Vector3.new(0.8, 18, 0.8), CFrame = pole * CFrame.new(0, 9, 0), Color = IRON, Material = Enum.Material.Metal, Parent = f })
			makePart({ Name = "BannerBar", Size = Vector3.new(4.6, 0.4, 0.4), CFrame = pole * CFrame.new(-side * 2.2, 17.2, 0), Color = IRON, Material = Enum.Material.Metal, Decorative = true, Parent = f })
			makePart({ Name = "CrimsonBanner", Size = Vector3.new(4, 8, 0.2), CFrame = pole * CFrame.new(-side * 2.2, 12.8, 0), Color = CRIMSON, Material = Enum.Material.Fabric, Decorative = true, Parent = f })
		end
	end

	-- H. South Gate: twin pylons + lintel framing the tower
	local gate = folder("SouthGate", model)
	local gz = cfg.WallRadius
	local half = HubLayout.SouthGateWidth * 0.5
	for _, side in { -1, 1 } do
		local base = root * CFrame.new(side * (half + 3), 0, gz)
		makePart({ Name = "GatePylon", Size = Vector3.new(6, 30, 6), CFrame = base * CFrame.new(0, 15, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = gate })
		for _, y in { 8, 16, 24 } do
			makePart({ Name = "PylonBand", Size = Vector3.new(6.4, 1.2, 6.4), CFrame = base * CFrame.new(0, y, 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = gate })
		end
		makePart({ Name = "PylonCap", Size = Vector3.new(8, 2, 8), CFrame = base * CFrame.new(0, 31, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		-- Crouching gargoyle facing north over the park
		local g = base * CFrame.new(0, 32, 0)
		makePart({ Name = "GargoyleBody", Size = Vector3.new(2.6, 2.4, 3.4), CFrame = g * CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(-15), 0, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		makePart({ Name = "GargoyleHead", Size = Vector3.new(1.6, 1.6, 1.8), CFrame = g * CFrame.new(0, 2.7, -1.8), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		for _, ws in { -1, 1 } do
			makeWedge({ Name = "GargoyleWing", Size = Vector3.new(0.4, 3, 2.6), CFrame = g * CFrame.new(ws * 1.6, 3, 0.6) * CFrame.Angles(0, 0, ws * math.rad(25)), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
		end
	end
	makePart({ Name = "GateLintel", Size = Vector3.new(HubLayout.SouthGateWidth + 12, 4, 4), CFrame = root * CFrame.new(0, 25, gz), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = gate })
	makePart({ Name = "LintelTrim", Size = Vector3.new(HubLayout.SouthGateWidth + 12.4, 0.8, 4.4), CFrame = root * CFrame.new(0, 23.2, gz), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = gate })
	local sign = makePart({ Name = "TowerSign", Size = Vector3.new(22, 4, 0.6), CFrame = root * CFrame.new(0, 20.4, gz), Color = SLATE, Material = Enum.Material.Slate, Decorative = true, Parent = gate })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0.2
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fondamento
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(235, 200, 160)
		label.Text = "THE INFINITE TOWER"
		label.Parent = gui
	end
end

--============================================================================
-- I. WAYFINDER DAIS
--============================================================================
local function buildDais(model: Model, root: CFrame, cfg: typeof(CommonsBuilder.Config))
	local f = folder("WayfinderDais", model)
	cylinderY("Plaza", cfg.PlazaRadius, 0.3, 0.3, root, MARBLE, Enum.Material.Marble, true, f)
	cylinderY("PlazaCurb", cfg.PlazaRadius + 1.2, 0.26, 0.26, root, SLATE, Enum.Material.Slate, true, f)

	-- Compass rose: 4 crimson strips through the centre
	for i = 0, 3 do
		makePart({ Name = "CompassStrip", Size = Vector3.new(1.6, 0.06, cfg.PlazaRadius * 2 - 4), CFrame = root * CFrame.new(0, 0.32, 0) * CFrame.Angles(0, math.rad(i * 45), 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = f })
	end
	-- Cyan arrows down each plot's path
	for index, deg in HubLayout.PlotBearingsDeg do
		local x0, z0 = polar(deg, 20)
		local x1, z1 = polar(deg, 31)
		local shaft = flatStrip("WayArrow_" .. index, root, x0, z0, x1, z1, 1.5, 0.34, 0.06, CYAN, Enum.Material.Neon, f)
		shaft.Transparency = 0.3
		local head = makeWedge({ Name = "WayArrowHead_" .. index, Size = Vector3.new(0.06, 4, 3), CFrame = facingCentre(root, deg, 32.5, 0.34) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color = CYAN, Material = Enum.Material.Neon, Decorative = true, Parent = f })
		head.Transparency = 0.3
	end

	-- Three 1-stud dais tiers and the statue plinth
	cylinderY("DaisTier1", 18, 1, 1.3, root, SLATE, Enum.Material.Slate, false, f)
	cylinderY("DaisTier2", 14, 1, 2.3, root, MARBLE, Enum.Material.Marble, false, f)
	cylinderY("DaisTier3", 10, 1, 3.3, root, SLATE, Enum.Material.Slate, false, f)
	makePart({ Name = "StatuePlinth", Size = Vector3.new(6, 4, 6), CFrame = root * CFrame.new(0, 5.3, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })

	-- Statue of the First Master, facing the tower (+Z), sword raised toward it
	local statue = Instance.new("Model")
	statue.Name = "StatueOfTheFirstMaster"
	statue.Parent = f
	local s = root * CFrame.new(0, 7.3, 0) * CFrame.Angles(0, math.pi, 0) -- -Z of s points south
	local function sp(name: string, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?)
		makePart({ Name = name, Size = size, CFrame = s * cf, Color = color or STATUE, Material = material or Enum.Material.Marble, Decorative = true, Parent = statue })
	end
	for _, side in { -1, 1 } do
		sp("Leg", Vector3.new(1.4, 5, 1.6), CFrame.new(side * 0.9, 2.5, 0))
	end
	sp("Torso", Vector3.new(3.6, 4.5, 2), CFrame.new(0, 7.25, 0))
	sp("Belt", Vector3.new(3.8, 0.6, 2.2), CFrame.new(0, 5.3, 0), Color3.fromRGB(190, 186, 176))
	sp("Head", Vector3.new(2, 2.2, 2), CFrame.new(0, 10.6, 0))
	sp("Hood", Vector3.new(2.6, 2.4, 2.4), CFrame.new(0, 10.9, 0.3), Color3.fromRGB(205, 200, 190))
	makeWedge({ Name = "CloakL", Size = Vector3.new(2.4, 9, 2.6), CFrame = s * CFrame.new(-1.2, 4.6, 1.9) * CFrame.Angles(0, math.pi, 0), Color = STATUE, Material = Enum.Material.Marble, Decorative = true, Parent = statue })
	makeWedge({ Name = "CloakR", Size = Vector3.new(2.4, 9, 2.6), CFrame = s * CFrame.new(1.2, 4.6, 1.9) * CFrame.Angles(0, math.pi, 0), Color = STATUE, Material = Enum.Material.Marble, Decorative = true, Parent = statue })
	sp("ArmLeft", Vector3.new(1, 4.2, 1), CFrame.new(-2.3, 7, 0) * CFrame.Angles(0, 0, math.rad(-6)))
	local shoulder = CFrame.new(2.3, 9, 0) * CFrame.Angles(math.rad(-60), 0, 0) -- raised forward toward the tower
	sp("ArmRight", Vector3.new(1, 4.4, 1), shoulder * CFrame.new(0, 2.2, 0))
	sp("SwordGrip", Vector3.new(0.5, 1.6, 0.5), shoulder * CFrame.new(0, 4.6, 0), IRON, Enum.Material.Metal)
	sp("SwordGuard", Vector3.new(2.4, 0.4, 0.6), shoulder * CFrame.new(0, 5.5, 0), IRON, Enum.Material.Metal)
	sp("SwordBlade", Vector3.new(0.5, 8, 0.15), shoulder * CFrame.new(0, 9.7, 0), Color3.fromRGB(255, 70, 80), Enum.Material.Neon)

	-- Wayfinder Crystal floating above the statue
	local crystal = makePart({
		Name = "WayfinderCrystal",
		Size = Vector3.new(4, 4, 4),
		CFrame = root * CFrame.new(0, 27, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)),
		Color = CYAN,
		Material = Enum.Material.Neon,
		Decorative = true,
		Parent = f,
	})
	crystal.Transparency = 0.1
	crystal:SetAttribute("BaseY", crystal.Position.Y)
	CollectionService:AddTag(crystal, "CommonsSpinner")
	light(crystal, CYAN, 24, 2)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "CrystalSparkle"
	sparkle.Color = ColorSequence.new(CYAN)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 6
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = crystal

	-- Five squad plinths with hero silhouettes
	for k = 0, 4 do
		local deg = 36 + k * 72
		local x, z = polar(deg, 26)
		local base = CFrame.lookAt((root * CFrame.new(x, 0, z)).Position, (root * CFrame.new(0, 0, 0)).Position)
		cylinderY("SquadPlinth", 1.6, 2, 2.3, base, SLATE, Enum.Material.Slate, false, f)
		makePart({ Name = "SquadSilhouetteLegs", Size = Vector3.new(0.9, 1.2, 0.5), CFrame = base * CFrame.new(0, 2.9, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
		makePart({ Name = "SquadSilhouetteBody", Size = Vector3.new(1.1, 1.4, 0.6), CFrame = base * CFrame.new(0, 4.2, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
		makePart({ Name = "SquadSilhouetteHead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = base * CFrame.new(0, 5.35, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
	end

	for _, deg in { 48, -48, 150, -150 } do
		bench("PlazaBench", facingCentre(root, deg, 32, 0.3), f)
	end
end

--============================================================================
-- J. REFLECTING POOL (north wedge)
--============================================================================
local function buildPool(model: Model, root: CFrame)
	local f = folder("ReflectingPool", model)
	local pc = root * CFrame.new(0, 0, -95)
	local poolR = 26 -- keeps the coping clear of the ±24° path hedges
	cylinderY("PoolFloor", poolR, 0.2, 0.18, pc, Color3.fromRGB(25, 40, 50), Enum.Material.Slate, true, f)
	local water = cylinderY("PoolWater", poolR, 0.4, 0.4, pc, Color3.fromRGB(60, 110, 140), Enum.Material.Glass, false, f)
	water.Transparency = 0.15
	for i = 0, 31 do
		local a = math.rad(i * 11.25)
		local len = 2 * (poolR + 1) * math.tan(math.rad(5.625)) + 0.3
		local pos = pc * CFrame.new(math.sin(a) * (poolR + 1), 0.6, -math.cos(a) * (poolR + 1))
		makePart({ Name = "Coping", Size = Vector3.new(len, 1.2, 2), CFrame = CFrame.lookAt(pos.Position, (pc * CFrame.new(0, 0.6, 0)).Position), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	end
	-- Stepping stones east-west (the footbridge carries the centre)
	for _, x in { -19, -13, -7, 7, 13, 19 } do
		cylinderY("SteppingStone", 2, 1, 1.0, pc * CFrame.new(x, 0, 0), Color3.fromRGB(120, 116, 110), Enum.Material.Slate, false, f)
	end
	-- Arched footbridge north-south: 4.3° ramps up to a 1.8-high deck
	local deckY = 1.8
	makePart({ Name = "FootbridgeDeck", Size = Vector3.new(6, 0.6, 24), CFrame = pc * CFrame.new(0, deckY - 0.3, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	for _, dir in { -1, 1 } do
		local run = 24
		local ang = math.atan(deckY / run)
		makePart({
			Name = "FootbridgeRamp",
			Size = Vector3.new(6, 0.6, math.sqrt(run * run + deckY * deckY)),
			CFrame = pc * CFrame.new(0, deckY * 0.5 - 0.3, dir * (12 + run * 0.5)) * CFrame.Angles(dir * ang, 0, 0),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
			Parent = f,
		})
	end
	for _, side in { -1, 1 } do
		makePart({ Name = "FootbridgeRail", Size = Vector3.new(0.4, 2.4, 24), CFrame = pc * CFrame.new(side * 2.8, deckY + 1.2, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	-- Lily pads in a crescent on the north side
	for i = 0, 5 do
		local a = math.rad(-70 + i * 28)
		cylinderY("LilyPad", 1.5, 0.08, 0.46, pc * CFrame.new(math.sin(a) * 17, 0, -math.cos(a) * 17), Color3.fromRGB(70, 140, 70), Enum.Material.Grass, true, f)
	end
	-- Weeping willows on the north bank
	for _, side in { -1, 1 } do
		local w = pc * CFrame.new(side * 18, 0, -34)
		makePart({ Name = "WillowTrunk", Size = Vector3.new(2.2, 11, 2.2), CFrame = w * CFrame.new(0, 5.5, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
		for j, ball in { { 0, 12, 0, 13 }, { -3, 10.5, 2, 9 }, { 3, 10.5, -2, 9 } } do
			makePart({ Name = "WillowCanopy_" .. j, Shape = Enum.PartType.Ball, Size = Vector3.new(ball[4], ball[4], ball[4]), CFrame = w * CFrame.new(ball[1], ball[2], ball[3]), Color = Color3.fromRGB(110, 150, 70), Material = Enum.Material.Grass, Decorative = true, Parent = f })
		end
		for k = 0, 5 do
			local a = math.rad(k * 60)
			makePart({ Name = "WillowFrond", Size = Vector3.new(1.2, 7, 1.2), CFrame = w * CFrame.new(math.cos(a) * 5.5, 7, math.sin(a) * 5.5), Color = Color3.fromRGB(96, 136, 62), Material = Enum.Material.Grass, Decorative = true, Parent = f })
		end
	end
	-- Fountain jet in the middle of the pool
	local jet = makePart({ Name = "FountainJet", Size = Vector3.new(1, 0.2, 1), CFrame = pc * CFrame.new(9, 0.5, 10), Transparency = 1, Decorative = true, Parent = f })
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Size = NumberSequence.new(0.6, 0.2)
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Rate = 30
	spray.Speed = NumberRange.new(10, 13)
	spray.SpreadAngle = Vector2.new(6, 6)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = jet
end

--============================================================================
-- K. LANTERN ORCHARDS (north-west & north-east wedges)
--============================================================================
local function buildOrchards(model: Model, root: CFrame, rng: Random)
	local f = folder("LanternOrchards", model)
	for _, centreDeg in { -48, 48 } do
		local o = folder(centreDeg < 0 and "OrchardNW" or "OrchardNE", f)
		local rows = { { 78, { -12, -4, 4, 12 } }, { 112, { -14, -5, 5, 14 } } }
		for rowIndex, row in rows do
			for i, offset in row[2] do
				local x, z = polar(centreDeg + offset, row[1])
				local t = root * CFrame.new(x, 0, z)
				local scale = rng:NextNumber(0.9, 1.15)
				makePart({ Name = "BlossomTrunk", Size = Vector3.new(1.6, 7 * scale, 1.6), CFrame = t * CFrame.new(0, 3.5 * scale, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = o })
				local blossom = if (rowIndex + i) % 2 == 0 then Color3.fromRGB(255, 183, 197) else Color3.fromRGB(250, 240, 245)
				for j, b in { { 0, 8.5, 0, 9 }, { -2.4, 7.4, 1.2, 7 }, { 2.2, 7.6, -1.4, 6 } } do
					makePart({ Name = "BlossomCanopy_" .. j, Shape = Enum.PartType.Ball, Size = Vector3.one * b[4] * scale, CFrame = t * CFrame.new(b[1] * scale, b[2] * scale, b[3] * scale), Color = blossom, Material = Enum.Material.SmoothPlastic, Decorative = true, Parent = o })
				end
			end
		end
		-- Lantern posts between the rows; two carry lights
		for i, offset in { -9, 0, 9 } do
			local x, z = polar(centreDeg + offset, 95)
			local p = root * CFrame.new(x, 0, z)
			makePart({ Name = "LanternPost", Size = Vector3.new(0.6, 6, 0.6), CFrame = p * CFrame.new(0, 3, 0), Color = WOOD, Material = Enum.Material.Wood, Parent = o })
			makePart({ Name = "LanternArm", Size = Vector3.new(2.4, 0.3, 0.3), CFrame = p * CFrame.new(1.1, 5.8, 0), Color = WOOD, Material = Enum.Material.Wood, Decorative = true, Parent = o })
			local lantern = makePart({ Name = "PaperLantern", Size = Vector3.new(1, 1.4, 1), CFrame = p * CFrame.new(2, 4.9, 0), Color = Color3.fromRGB(255, 120, 90), Material = Enum.Material.Neon, Decorative = true, Parent = o })
			if i ~= 2 then
				light(lantern, Color3.fromRGB(255, 160, 110), 14, 1)
			end
		end
		-- Benches facing the Loop
		for _, offset in { -8, 8 } do
			local deg = centreDeg + offset
			local x, z = polar(deg, 132)
			local pos = root * CFrame.new(x, 0, z)
			local ox, oz = polar(deg, 200)
			bench("OrchardBench", CFrame.lookAt(pos.Position, (root * CFrame.new(ox, 0, oz)).Position), o)
		end
		-- Fireflies
		local fx, fz = polar(centreDeg, 95)
		local anchor = makePart({ Name = "FireflyAnchor", Size = Vector3.new(30, 1, 30), CFrame = root * CFrame.new(fx, 3, fz), Transparency = 1, Decorative = true, Parent = o })
		local flies = Instance.new("ParticleEmitter")
		flies.Name = "Fireflies"
		flies.Color = ColorSequence.new(Color3.fromRGB(255, 240, 140))
		flies.LightEmission = 1
		flies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
		flies.Lifetime = NumberRange.new(5, 7)
		flies.Rate = 4
		flies.Speed = NumberRange.new(0.5, 1.5)
		flies.SpreadAngle = Vector2.new(180, 180)
		flies.Shape = Enum.ParticleEmitterShape.Box
		flies.Parent = anchor
	end
end

--============================================================================
-- L. LEADERBOARD PAVILION (east wedge)
--============================================================================
-- Open colonnade with a centre wall: the Playtime board faces the dais, the Power board faces the Loop.
local function buildPavilion(model: Model, root: CFrame)
	local f = folder("LeaderboardPavilion", model)
	local p = facingCentre(root, 96, 100, 0)
	local halfW, halfD = 22, 17
	makePart({ Name = "PavilionFloor", Size = Vector3.new(halfW * 2, 1, halfD * 2), CFrame = p * CFrame.new(0, 0.5, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	for _, x in { -halfW + 1, halfW - 1 } do
		for _, z in { -halfD + 1, halfD - 1 } do
			makePart({ Name = "Column", Size = Vector3.new(2, 14, 2), CFrame = p * CFrame.new(x, 8, z), Color = MARBLE, Material = Enum.Material.Marble, Parent = f })
		end
	end
	makePart({ Name = "CentreWall", Size = Vector3.new(halfW * 2 - 4, 14, 1.2), CFrame = p * CFrame.new(0, 8, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	makePart({ Name = "RoofTrim", Size = Vector3.new(halfW * 2 + 4.4, 0.6, halfD * 2 + 4.4), CFrame = p * CFrame.new(0, 15.3, 0), Color = CRIMSON, Material = Enum.Material.Granite, Decorative = true, Parent = f })
	makePart({ Name = "Roof", Size = Vector3.new(halfW * 2 + 4, 1.5, halfD * 2 + 4), CFrame = p * CFrame.new(0, 16.35, 0), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })
	for _, z in { -halfD - 1, halfD + 1 } do
		for i = 0, 5 do
			makePart({ Name = "RoofCrenel", Size = Vector3.new(3, 1.6, 2), CFrame = p * CFrame.new(-halfW + 2 + i * 8, 17.9, z), Color = SLATE_DARK, Material = Enum.Material.Slate, Decorative = true, Parent = f })
		end
	end
	-- Mount points for the shared world leaderboards: on the floor, LookVector toward the viewers
	makePart({ Name = "BoardSlot_Playtime", Size = Vector3.new(1, 1, 1), CFrame = p * CFrame.new(0, 1, -1.4), Transparency = 1, Decorative = true, Parent = f })
	makePart({ Name = "BoardSlot_Power", Size = Vector3.new(1, 1, 1), CFrame = p * CFrame.new(0, 1, 1.4) * CFrame.Angles(0, math.pi, 0), Transparency = 1, Decorative = true, Parent = f })
	for _, z in { -10, 10 } do
		local lamp = makePart({ Name = "PavilionLamp", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = p * CFrame.new(0, 14.4, z), Color = LANTERN, Material = Enum.Material.Neon, Decorative = true, Parent = f })
		light(lamp, LANTERN, 18, 1.1)
	end
end

--============================================================================
-- M. GAZEBO & BANDSTAND (west wedge)
--============================================================================
local function buildGazebo(model: Model, root: CFrame)
	local f = folder("Gazebo", model)
	local g = facingCentre(root, -96, 95, 0)
	cylinderY("GazeboFloor", 13, 1, 1, g, SLATE, Enum.Material.Slate, false, f)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		makePart({ Name = "GazeboPost", Size = Vector3.new(1, 10, 1), CFrame = g * CFrame.new(math.sin(a) * 12, 6, -math.cos(a) * 12), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	for i, tier in { { 15, 11 }, { 10, 12.5 }, { 5, 14 } } do
		cylinderY("GazeboRoof_" .. i, tier[1], 1.5, tier[2] + 0.75, g, if i == 2 then CRIMSON else SLATE_DARK, Enum.Material.Slate, true, f)
	end
	local finial = makePart({ Name = "GazeboFinial", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = g * CFrame.new(0, 15.6, 0), Color = LANTERN, Material = Enum.Material.Neon, Decorative = true, Parent = f })
	light(finial, LANTERN, 20, 1)
	-- Ring bench, open toward the park centre (-Z of g)
	for i = 1, 7 do
		local a = math.rad(i * 45)
		local pos = g * CFrame.new(math.sin(a) * 9, 1, -math.cos(a) * 9)
		bench("GazeboBench", CFrame.lookAt(pos.Position, (g * CFrame.new(0, 1, 0)).Position), f)
	end
end

--============================================================================
-- N. BIOME STONES (south-west wedge)
--============================================================================
local function buildBiomeStones(model: Model, root: CFrame)
	local f = folder("BiomeStones", model)
	local x, z = polar(-150, 100)
	local c = root * CFrame.new(x, 0, z)
	makePart({ Name = "StoneAltar", Size = Vector3.new(6, 1.5, 4), CFrame = c * CFrame.new(0, 0.75, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	for i, color in BIOME_COLORS do
		local a = math.rad((i - 1) * 36)
		local h = 8 + ((i * 7) % 5)
		local pos = c * CFrame.new(math.sin(a) * 20, h * 0.5, -math.cos(a) * 20)
		local face = CFrame.lookAt(pos.Position, (c * CFrame.new(0, h * 0.5, 0)).Position)
		local stone = makePart({ Name = string.format("Menhir_%02d", i), Size = Vector3.new(3, h, 2), CFrame = face * CFrame.Angles(0, 0, math.rad(((i % 3) - 1) * 3)), Color = SLATE_DARK:Lerp(color, 0.45), Material = Enum.Material.Slate, Parent = f })
		stone:SetAttribute("BiomeIndex", i)
		local rune = makePart({ Name = "Rune", Size = Vector3.new(0.4, h * 0.55, 0.2), CFrame = face * CFrame.new(0, 0.5, -1.05), Color = color, Material = Enum.Material.Neon, Decorative = true, Parent = stone })
		rune.Transparency = 0.4
	end
end

--============================================================================
-- O. OVERLOOK TERRACE (south-east wedge)
--============================================================================
local function buildOverlook(model: Model, root: CFrame)
	local f = folder("OverlookTerrace", model)
	local t = facingCentre(root, 150, 100, 0) -- -Z toward the park centre, +Z toward the tower side
	local h = 4
	makePart({ Name = "TerraceBlock", Size = Vector3.new(44, h, 30), CFrame = t * CFrame.new(0, h * 0.5, 0), Color = SLATE, Material = Enum.Material.Slate, Parent = f })
	makePart({ Name = "TerraceTop", Size = Vector3.new(44, 0.2, 30), CFrame = t * CFrame.new(0, h + 0.1, 0), Color = COBBLE, Material = Enum.Material.Cobblestone, Decorative = true, Parent = f })
	-- 16-long ramps at both ends (14°, within the 15° slope rule)
	local run = 16
	local ang = math.atan(h / run)
	for _, side in { -1, 1 } do
		makePart({
			Name = "TerraceRamp",
			Size = Vector3.new(math.sqrt(run * run + h * h), 0.8, 8),
			CFrame = t * CFrame.new(side * (22 + run * 0.5), h * 0.5 - 0.4, 0) * CFrame.Angles(0, 0, -side * ang),
			Color = SLATE,
			Material = Enum.Material.Slate,
			Parent = f,
		})
		for _, zr in { { -15, -4 }, { 4, 15 } } do
			local len = zr[2] - zr[1]
			makePart({ Name = "Balustrade", Size = Vector3.new(1, 3, len), CFrame = t * CFrame.new(side * 21.5, h + 1.5, (zr[1] + zr[2]) * 0.5), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })
		end
		-- Crimson banners at the outer corners
		local pole = t * CFrame.new(side * 20, h, 13.5)
		makePart({ Name = "BannerPole", Size = Vector3.new(0.8, 12, 0.8), CFrame = pole * CFrame.new(0, 6, 0), Color = IRON, Material = Enum.Material.Metal, Parent = f })
		makePart({ Name = "CrimsonBanner", Size = Vector3.new(3.6, 6, 0.2), CFrame = pole * CFrame.new(-side * 2, 8, 0), Color = CRIMSON, Material = Enum.Material.Fabric, Decorative = true, Parent = f })
	end
	makePart({ Name = "Balustrade", Size = Vector3.new(44, 3, 1), CFrame = t * CFrame.new(0, h + 1.5, 14.5), Color = SLATE_DARK, Material = Enum.Material.Slate, Parent = f })
	-- Brass telescopes aimed at the tower top
	local towerTop = Vector3.new(0, 300, 0)
	for _, x in { -10, 10 } do
		local base = t * CFrame.new(x, h, 11)
		makePart({ Name = "TelescopeStand", Size = Vector3.new(0.6, 3.4, 0.6), CFrame = base * CFrame.new(0, 1.7, 0), Color = IRON, Material = Enum.Material.Metal, Parent = f })
		local pivot = (base * CFrame.new(0, 3.6, 0)).Position
		makePart({ Name = "TelescopeTube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.9, 0.9), CFrame = CFrame.lookAt(pivot, towerTop) * CFrame.Angles(0, math.pi * 0.5, 0), Color = Color3.fromRGB(181, 140, 62), Material = Enum.Material.Metal, Decorative = true, Parent = f })
	end
	local benchPos = t * CFrame.new(0, h + 0.2, 4)
	bench("OverlookBench", CFrame.lookAt(benchPos.Position, (t * CFrame.new(0, h + 0.2, 40)).Position), f)
end

--============================================================================
-- BUILD
--============================================================================
function CommonsBuilder.Build(container: Instance): Model
	local cfg = CommonsBuilder.Config
	local rng = Random.new(cfg.RandomSeed)
	local old = container:FindFirstChild("MastersCommons")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "MastersCommons"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = CFrame.new(HubLayout.ParkCentre)

	model.PrimaryPart = buildIsland(model, root, cfg, rng)
	buildRim(model, root, cfg)
	buildLoopAndPaths(model, root, cfg)
	buildPilgrimsWay(model, root, cfg)
	buildDais(model, root, cfg)
	buildPool(model, root)
	buildOrchards(model, root, rng)
	buildPavilion(model, root)
	buildGazebo(model, root)
	buildBiomeStones(model, root)
	buildOverlook(model, root)

	model.Parent = container
	return model
end

-- Keeps each gate landing's nameplate in sync with its plot's OwnerName (set by PlotManager).
function CommonsBuilder.BindGateTablets(commons: Instance, plotsFolder: Instance)
	local landings = commons:FindFirstChild("GateLandings")
	if not landings then
		return
	end
	for _, gate in landings:GetChildren() do
		local index = gate:GetAttribute("PlotIndex")
		local tablet = gate:FindFirstChild("GateTablet")
		local label = tablet and tablet:FindFirstChild("OwnerLabel", true) :: TextLabel?
		local plot = plotsFolder:FindFirstChild("Plot_" .. tostring(index))
		if label and plot then
			local function refresh()
				local owner = plot:GetAttribute("OwnerName")
				local claimed = type(owner) == "string" and owner ~= "" and owner ~= "Unclaimed"
				label.Text = if claimed then string.format("PLOT %d\n%s's Fortress", index, owner) else string.format("PLOT %d\nUnclaimed", index)
			end
			refresh()
			plot:GetAttributeChangedSignal("OwnerName"):Connect(refresh)
		end
	end
end

return CommonsBuilder
