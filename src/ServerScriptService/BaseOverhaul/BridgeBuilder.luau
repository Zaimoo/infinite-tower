local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout"))
local CausewayBuilder = require(script.Parent:WaitForChild("CausewayBuilder"))

local B = {}

function B.Build()
	local world = workspace:WaitForChild("BaseOverhaulGeometry")
	local tower = world:WaitForChild("CentralCrimsonTower")
	local old = world:FindFirstChild("IslandTowerBridges")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "IslandTowerBridges"
	f.Parent = world

	local function part(n: string, size: Vector3, cf: CFrame, rail: boolean): Part
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.Material = rail and Enum.Material.Granite or Enum.Material.Slate
		p.Color = rail and Color3.fromRGB(112, 26, 37) or Color3.fromRGB(55, 45, 52)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if rail then
			local mod = Instance.new("PathfindingModifier")
			mod.Label = "BridgeRail"
			mod.Parent = p
		end
		p.Parent = f
		return p
	end

	-- Plot bridges belong to the hopeful fortress side: pale warm stone and cream marble rails
	local SANCTUARY_DECK = { Color = Color3.fromRGB(168, 156, 138), Material = Enum.Material.Cobblestone }
	local SANCTUARY_RAIL = { Color = Color3.fromRGB(226, 216, 192), Material = Enum.Material.Marble }

	local function span(n: string, a: Vector3, b: Vector3, w: number, rails: boolean, railInset: number?, railEndInset: number?, sanctuary: boolean?)
		local cf = CFrame.lookAt((a + b) / 2, b)
		local len = (b - a).Magnitude + 1
		local deck = part(n, Vector3.new(w, 2, len), cf * CFrame.new(0, -1, 0), false)
		if sanctuary then
			deck.Color, deck.Material = SANCTUARY_DECK.Color, SANCTUARY_DECK.Material
		end
		if rails then
			local rA = if railInset then a + (b - a).Unit * railInset else a
			local rB = if railEndInset then b - (b - a).Unit * railEndInset else b
			local rLen = (rB - rA).Magnitude + 1
			local rCf = CFrame.lookAt((rA + rB) / 2, rB)
			for _, side in { -1, 1 } do
				local rail = part(n .. "_Rail", Vector3.new(1, 4, rLen), rCf * CFrame.new(side * (w / 2 - 0.5), 2, 0), true)
				if sanctuary then
					rail.Color, rail.Material = SANCTUARY_RAIL.Color, SANCTUARY_RAIL.Material
				end
			end
		end
	end

	local radius = HubLayout.TowerWalkwayRadius
	local y = HubLayout.TowerWalkwayY
	local surfaceY = HubLayout.IslandSurfaceY

	-- Plot gate -> Masters' Commons rim, one straight bridge per plot (both ends at the island surface)
	local connected = 0
	for i = 1, #HubLayout.PlotBearingsDeg do
		local plot = workspace.WaitingRoomPlots:FindFirstChild("Plot_" .. i)
		if plot then
			local island = plot:WaitForChild("FloatingFortressIsland", 10)
			if island then
				local walls = island:FindFirstChild("FortressWalls")
				local gate = walls and walls:FindFirstChild("GateLintel")
				if gate and gate:IsA("BasePart") then
					connected += 1
					local start = Vector3.new(gate.Position.X, surfaceY, gate.Position.Z) - gate.CFrame.LookVector * 4
					local landing = HubLayout.BearingPoint(HubLayout.PlotBearingsDeg[i], HubLayout.ParkRadius - 2)
					span("IslandBridge_" .. i, start, landing, HubLayout.PlotBridgeWidth, true, 4, 6, true)
					local edgeBarriers = walls:FindFirstChild("InvisibleEdgeBarriers")
					local barrier = edgeBarriers and edgeBarriers:FindFirstChild("Barrier_Front")
					if barrier then barrier.CanCollide = false barrier.CanTouch = false end
				end
			end
		end
	end

	-- Pilgrim's Causeway: tower walkway -> Commons South Gate (gentle 16 -> 12 slope)
	CausewayBuilder.Build(f)
	local angles = { -math.pi / 2 }

	local function near(a: number, b: number, t: number): boolean
		return math.abs(math.atan2(math.sin(a - b), math.cos(a - b))) < t
	end

	for i = 1, 120 do
		local a = (i - 1) * math.pi * 2 / 120
		local b = i * math.pi * 2 / 120
		local mid = (a + b) / 2
		local p = Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
		local q = Vector3.new(math.cos(b) * radius, y, math.sin(b) * radius)
		span("TowerWalkway_" .. i, p, q, 22, false)
		local cf = CFrame.lookAt((p + q) / 2, q)
		local open = false
		for _, angle in angles do if near(mid, angle, 0.065) then open = true end end
		if not open then part("OuterRail", Vector3.new(1, 4, (q - p).Magnitude + 0.5), cf * CFrame.new(-10.5, 2, 0), true) end
		if not near(mid, -math.pi / 2, 0.09) then part("InnerRail", Vector3.new(1, 4, (q - p).Magnitude + 0.5), cf * CFrame.new(10.5, 2, 0), true) end
		if i % 30 == 0 then task.wait() end
	end

	-- 1. Bridge approach from walkway to entrance terrace
	local approachFront = Vector3.new(0, y, -358)
	span("TowerEntranceApproach", Vector3.new(0, y, -radius - 1), approachFront, HubLayout.CausewayWidth, true)

	-- 2. Legacy square plaza slab poked into Plot_1 and Plot_6; the tower's CrackedGroundSlab is the floor
	local oldPlaza = world:FindFirstChild("TowerPlazaFoundation")
	if oldPlaza then oldPlaza:Destroy() end

	-- 3. Grand Entrance Arrival Platform (seamlessly joins bridge at -358, gate at -332, foyer to -290)
	local oldArrival = world:FindFirstChild("TowerHubArrival")
	if oldArrival then oldArrival:Destroy() end
	local oldRunner = world:FindFirstChild("TowerHubArrival_Runner")
	if oldRunner then oldRunner:Destroy() end
	local oldRailL = world:FindFirstChild("TowerHubArrival_RailL")
	if oldRailL then oldRailL:Destroy() end
	local oldRailR = world:FindFirstChild("TowerHubArrival_RailR")
	if oldRailR then oldRailR:Destroy() end

	local arrivalSlab = Instance.new("Part")
	arrivalSlab.Name = "TowerHubArrival"
	arrivalSlab.Size = Vector3.new(96, 2.4, 70)
	arrivalSlab.Position = Vector3.new(0, 15, -325)
	arrivalSlab.Anchored = true
	arrivalSlab.CanCollide = true
	arrivalSlab.CanQuery = true
	arrivalSlab.Material = Enum.Material.Slate
	arrivalSlab.Color = Color3.fromRGB(55, 45, 52)
	arrivalSlab.TopSurface = Enum.SurfaceType.Smooth
	arrivalSlab.BottomSurface = Enum.SurfaceType.Smooth
	arrivalSlab.Parent = world

	local runner = Instance.new("Part")
	runner.Name = "TowerHubArrival_Runner"
	runner.Size = Vector3.new(32, 0.2, 68)
	runner.Position = Vector3.new(0, 16.1, -325)
	runner.Anchored = true
	runner.CanCollide = false
	runner.Material = Enum.Material.Granite
	runner.Color = Color3.fromRGB(145, 28, 38)
	runner.TopSurface = Enum.SurfaceType.Smooth
	runner.BottomSurface = Enum.SurfaceType.Smooth
	runner.Parent = world

	-- Outer balustrade safety rails on arrival terrace
	for _, side in { -1, 1 } do
		local rail = Instance.new("Part")
		rail.Name = side < 0 and "TowerHubArrival_RailL" or "TowerHubArrival_RailR"
		rail.Size = Vector3.new(1.2, 4, 24)
		rail.Position = Vector3.new(side * 47.4, 18, -348)
		rail.Anchored = true
		rail.CanCollide = true
		rail.Material = Enum.Material.Granite
		rail.Color = Color3.fromRGB(112, 26, 37)
		rail.TopSurface = Enum.SurfaceType.Smooth
		rail.BottomSurface = Enum.SurfaceType.Smooth
		rail.Parent = world
	end

	-- 4. Entrance Portal Trigger configuration
	local entrance = tower:FindFirstChild("TowerBaseEntrance")
	local portal = entrance and entrance:FindFirstChild("EntrancePortalTrigger")
	if portal and portal:IsA("BasePart") then
		portal.CanCollide = false
		local a = portal:FindFirstChild("PromptAttachment") or Instance.new("Attachment")
		a.Name = "PromptAttachment"
		a.Position = Vector3.new(0, -portal.Size.Y / 2 + 5, 0)
		a.Parent = portal

		local prompt = a:FindFirstChild("TowerSelectorPrompt") or Instance.new("ProximityPrompt")
		prompt.Name = "TowerSelectorPrompt"
		prompt.ActionText = "Choose floor"
		prompt.ObjectText = "Infinite Tower"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.MaxActivationDistance = 24
		prompt.RequiresLineOfSight = false
		prompt.Parent = a
	end

	-- 5. Solidify base cylinder if present
	local base = tower:FindFirstChild("CrackedSmokyBase")
	local slab = base and base:FindFirstChild("CrackedGroundSlab")
	if slab and slab:IsA("BasePart") then
		slab.CanCollide = true
	end

	f:SetAttribute("ConnectedIslandCount", connected)
	return f
end

return B
