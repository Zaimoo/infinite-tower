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

	-- Creates a flat dark void floor plane and subtle non-streaking dark mist beneath the bridge chasm
	local function createUnderBridgeAbyss(n: string, a: Vector3, b: Vector3, w: number)
		local mid = (a + b) / 2
		local delta = b - a
		local len = delta.Magnitude + 14
		local cf = CFrame.lookAt(Vector3.new(mid.X, -45, mid.Z), Vector3.new(b.X, -45, b.Z))

		local voidPlane = Instance.new("Part")
		voidPlane.Name = n .. "_AbyssVoidFloor"
		voidPlane.Size = Vector3.new(w * 2.4, 1, len)
		voidPlane.CFrame = cf
		voidPlane.Color = Color3.fromRGB(10, 8, 14)
		voidPlane.Material = Enum.Material.SmoothPlastic
		voidPlane.Reflectance = 0
		voidPlane.Anchored = true
		voidPlane.CanCollide = false
		voidPlane.CanTouch = false
		voidPlane.CanQuery = false
		voidPlane.CastShadow = false
		voidPlane.TopSurface = Enum.SurfaceType.Smooth
		voidPlane.BottomSurface = Enum.SurfaceType.Smooth
		voidPlane.Parent = f

		local mist = Instance.new("ParticleEmitter")
		mist.Name = "AbyssFogMist"
		mist.Texture = "rbxassetid://243660364"
		mist.LightEmission = 0 -- Essential: zero light emission prevents bright streaks or white crisscrossing
		mist.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(18, 16, 24)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(12, 10, 16)),
		})
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.3, 0.86),
			NumberSequenceKeypoint.new(0.7, 0.90),
			NumberSequenceKeypoint.new(1.0, 1.0),
		})
		mist.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 16),
			NumberSequenceKeypoint.new(0.5, 26),
			NumberSequenceKeypoint.new(1.0, 38),
		})
		mist.Lifetime = NumberRange.new(6.0, 9.0)
		mist.Rate = 2.0
		mist.Speed = NumberRange.new(0.4, 1.2)
		mist.SpreadAngle = Vector2.new(180, 15)
		mist.Rotation = NumberRange.new(0, 360)
		mist.RotSpeed = NumberRange.new(-5, 5)
		mist.Shape = Enum.ParticleEmitterShape.Box
		mist.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		mist.Parent = voidPlane
	end

	local radius = HubLayout.TowerWalkwayRadius
	local y = HubLayout.TowerWalkwayY
	local surfaceY = HubLayout.IslandSurfaceY

	-- Plot gate -> Cloister Commons outer edge, one short straight bridge per plot (both ends at the island surface)
	local connected = 0
	for i = 1, HubLayout.PlotCount do
		local plot = workspace.WaitingRoomPlots:FindFirstChild("Plot_" .. i)
		if plot then
			local island = plot:FindFirstChild("FloatingFortressIsland") or plot:WaitForChild("FloatingFortressIsland", 10)
			if island then
				local walls = island:FindFirstChild("FortressWalls")
				local gate = walls and (walls:FindFirstChild("GateLintel") or walls:FindFirstChild("GateLintel", true))
				local islandCF = HubLayout.PlotIslandCFrame(i)
				local start: Vector3
				if gate and gate:IsA("BasePart") then
					start = Vector3.new(gate.Position.X, surfaceY, gate.Position.Z) - gate.CFrame.LookVector * 4
				else
					local gateLook = islandCF.LookVector
					local gatePos = islandCF.Position + gateLook * 157
					start = Vector3.new(gatePos.X, surfaceY, gatePos.Z) - gateLook * 4
				end

				connected += 1
				local slot = HubLayout.PlotSlots[i]
				local landing = HubLayout.HubLandingPoint(i) - Vector3.new(slot.DX, 0, slot.DZ) * 2
				span("IslandBridge_" .. i, start, landing, HubLayout.PlotBridgeWidth, true, 4, 6, true)
				createUnderBridgeAbyss("IslandBridge_" .. i, start, landing, HubLayout.PlotBridgeWidth)
				local edgeBarriers = walls and (walls:FindFirstChild("InvisibleEdgeBarriers") or walls:FindFirstChild("InvisibleEdgeBarriers", true))
				local barrier = edgeBarriers and edgeBarriers:FindFirstChild("Barrier_Front")
				if barrier then barrier.CanCollide = false barrier.CanTouch = false end
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
	createUnderBridgeAbyss("TowerEntranceApproach", Vector3.new(0, y, -radius - 1), approachFront, HubLayout.CausewayWidth)

	-- 2. Legacy square plaza slab poked into the plots; the tower's CrackedGroundSlab is the floor
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
