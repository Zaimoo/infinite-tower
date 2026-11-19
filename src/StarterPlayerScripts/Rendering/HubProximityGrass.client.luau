--!strict
-- StarterPlayerScripts/Rendering/HubProximityGrass.client.luau
-- Zero-lag client-only proximity 3D grass for the Cloister Commons (MastersCommons).
-- Maintains a fixed pool of GPU-instanced grass clump MeshParts and moves only the
-- clumps within HubGrassMask.Config.ActiveRadius of the local player/camera via
-- a single workspace:BulkMoveTo call, sinking outer clumps smoothly into the ground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

debug.setmemorycategory("HubProximityGrass")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubLayout = require(Shared:WaitForChild("Config"):WaitForChild("HubLayout"))
local HubGrassMask = require(Shared:WaitForChild("Util"):WaitForChild("HubGrassMask"))
local HubPresence = require(script.Parent:WaitForChild("HubPresence"))

local cfg = HubGrassMask.Config
local HUB_CENTRE = HubLayout.HubCentre
local GROUND_Y = HubLayout.IslandSurfaceY + cfg.SurfaceOffsetY
local MOVE_THRESHOLD_SQ = 0.75 * 0.75
local HIDDEN_CFRAME = CFrame.new(0, -600, 0)
local CLUMP_SCALE = 1.12
local GRASS_COLORMAP_ID = "rbxassetid://115667914360010"
local GRASS_NORMALMAP_ID = "rbxassetid://105314617289066"
local GRASS_ROUGHMAP_ID = "rbxassetid://98943186118006"

type Candidate = {
	lx: number,
	lz: number,
	distSq: number,
	fade: number,
	density: number,
	yaw: number,
}

type RectBox = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

local LocalPlayer = Players.LocalPlayer

-- Build or clone the single shared grass clump prototype used across all pool instances.
local function createClumpPrototype(): (BasePart, number, number)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local env = assets and assets:FindFirstChild("Environment")

	local hubGrassTpl = env and env:FindFirstChild("HubGrassClump")
	if hubGrassTpl then
		local srcMesh = if hubGrassTpl:IsA("MeshPart")
			then hubGrassTpl
			else hubGrassTpl:FindFirstChildWhichIsA("MeshPart", true)
		if srcMesh and srcMesh:IsA("MeshPart") then
			local proto = srcMesh:Clone()
			proto.Name = "HubGrassClump"
			proto.Anchored = true
			proto.CanCollide = false
			proto.CanTouch = false
			proto.CanQuery = false
			proto.CastShadow = false
			proto.Massless = true
			proto.DoubleSided = true
			proto.Material = Enum.Material.Plastic
			proto.Color = Color3.fromRGB(163, 162, 165)
			proto.PivotOffset = CFrame.identity
			proto.Size = srcMesh.Size * CLUMP_SCALE

			local sa = proto:FindFirstChildWhichIsA("SurfaceAppearance")
			if sa then
				sa.AlphaMode = Enum.AlphaMode.Opaque
				pcall(function()
					sa.ColorMap = GRASS_COLORMAP_ID
					sa.NormalMap = GRASS_NORMALMAP_ID
					sa.RoughnessMap = GRASS_ROUGHMAP_ID
				end)
			end

			local pivotY = if hubGrassTpl:IsA("Model") then hubGrassTpl:GetPivot().Position.Y else (srcMesh.Position.Y - srcMesh.Size.Y * 0.5)
			local centerOffsetY = (srcMesh.Position.Y - pivotY) * CLUMP_SCALE
			local height = proto.Size.Y
			return proto, centerOffsetY, height
		end
	end

	local turfTpl = env and env:FindFirstChild("GroundProp_MeadowTurfClump")
	if turfTpl then
		local srcMesh = turfTpl:FindFirstChildWhichIsA("MeshPart", true)
		if srcMesh and srcMesh:IsA("MeshPart") then
			local proto = srcMesh:Clone()
			proto.Name = "HubGrassClump"
			proto.Anchored = true
			proto.CanCollide = false
			proto.CanTouch = false
			proto.CanQuery = false
			proto.CastShadow = false
			proto.Massless = true
			proto.DoubleSided = true
			proto.Material = Enum.Material.Grass
			proto.Color = Color3.fromRGB(142, 140, 66)
			proto.PivotOffset = CFrame.identity
			local turfScale = 0.62
			proto.Size = srcMesh.Size * turfScale
			local sa = proto:FindFirstChildWhichIsA("SurfaceAppearance")
			if sa then
				sa.AlphaMode = Enum.AlphaMode.Overlay
				sa.Color = Color3.fromRGB(205, 198, 128)
			end
			return proto, proto.Size.Y * 0.42, proto.Size.Y
		end
	end

	-- Lightweight procedural fallback before Blender assets load
	local fallback = Instance.new("Part")
	fallback.Name = "HubGrassFallback"
	fallback.Size = Vector3.new(1.5, 1.1, 0.25)
	fallback.Material = Enum.Material.Grass
	fallback.Color = Color3.fromRGB(118, 122, 50)
	fallback.Anchored = true
	fallback.CanCollide = false
	fallback.CanTouch = false
	fallback.CanQuery = false
	fallback.CastShadow = false
	fallback.Massless = true
	fallback.TopSurface = Enum.SurfaceType.Smooth
	fallback.BottomSurface = Enum.SurfaceType.Smooth
	return fallback, 0.55, 1.1
end

local container = Workspace:FindFirstChild("ClientHubProximityGrass") :: Folder?
if container then
	container:Destroy()
end
local grassFolder = Instance.new("Folder")
grassFolder.Name = "ClientHubProximityGrass"
grassFolder.Archivable = false
grassFolder.Parent = Workspace

local prototype, centerOffsetY, clumpHeight = createClumpPrototype()
local poolSize = cfg.MaxPoolSize
local poolParts: { BasePart } = table.create(poolSize)

for i = 1, poolSize do
	local clone = prototype:Clone()
	clone.Name = "Grass_" .. i
	clone.CFrame = HIDDEN_CFRAME
	clone.Parent = grassFolder
	poolParts[i] = clone
end
prototype:Destroy()

-- Track raised flowerbeds in MastersCommons.Garden so grass never grows inside planter boxes.
local flowerBedExclusions: { RectBox } = {}
local trackedBeds: { [Instance]: boolean } = {}
local needsRefresh = true

local function recordFlowerBed(inst: Instance)
	if trackedBeds[inst] then
		return
	end
	if inst:IsA("BasePart") and (inst.Name == "BedKerb" or inst.Name == "FlowerBed") then
		trackedBeds[inst] = true
		local lx = inst.Position.X - HUB_CENTRE.X
		local lz = inst.Position.Z - HUB_CENTRE.Z
		local halfSpan = math.max(inst.Size.X, inst.Size.Z) * 0.5 + 1.5
		table.insert(flowerBedExclusions, {
			minX = lx - halfSpan,
			maxX = lx + halfSpan,
			minZ = lz - halfSpan,
			maxZ = lz + halfSpan,
		})
		needsRefresh = true
	end
end

local function inFlowerBed(lx: number, lz: number): boolean
	for _, b in flowerBedExclusions do
		if lx >= b.minX and lx <= b.maxX and lz >= b.minZ and lz <= b.maxZ then
			return true
		end
	end
	return false
end

task.spawn(function()
	local geom = Workspace:WaitForChild("BaseOverhaulGeometry", 60)
	local commons = geom and geom:WaitForChild("MastersCommons", 60)
	local garden = commons and commons:WaitForChild("Garden", 60)
	if garden then
		for _, ch in garden:GetChildren() do
			recordFlowerBed(ch)
		end
		garden.ChildAdded:Connect(recordFlowerBed)
	end
end)

local activeCount = 0
local lastFocusX = math.huge
local lastFocusZ = math.huge
local moveParts: { BasePart } = table.create(poolSize)
local moveCFrames: { CFrame } = table.create(poolSize)
local candidates: { Candidate } = {}

local function parkAll()
	if activeCount == 0 then
		return
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
	for i = 1, activeCount do
		moveParts[i] = poolParts[i]
		moveCFrames[i] = HIDDEN_CFRAME
	end
	activeCount = 0
	lastFocusX = math.huge
	lastFocusZ = math.huge
	Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function focusPosition(): Vector3?
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = Workspace.CurrentCamera
	if cam then
		return cam.Focus.Position
	end
	return nil
end

local function updateProximityGrass()
	if HubPresence.InTower() then
		parkAll()
		return
	end

	local focus = focusPosition()
	if not focus then
		return
	end

	local fx = focus.X - HUB_CENTRE.X
	local fz = focus.Z - HUB_CENTRE.Z
	local reach = cfg.ActiveRadius
	if math.abs(fx) > (HubLayout.HubHalfX + reach) or math.abs(fz) > (HubLayout.HubHalfZ + reach) then
		parkAll()
		return
	end

	local dxMove = fx - lastFocusX
	local dzMove = fz - lastFocusZ
	if not needsRefresh and (dxMove * dxMove + dzMove * dzMove) < MOVE_THRESHOLD_SQ then
		return
	end

	needsRefresh = false
	lastFocusX = fx
	lastFocusZ = fz

	local cellSize = cfg.CellSize
	local rCells = math.ceil(reach / cellSize)
	local baseCX = math.round(fx / cellSize)
	local baseCZ = math.round(fz / cellSize)
	local reachSq = reach * reach

	table.clear(candidates)
	for cx = baseCX - rCells, baseCX + rCells do
		for cz = baseCZ - rCells, baseCZ + rCells do
			local ok, lx, lz, density, yaw = HubGrassMask.SampleCell(cx, cz)
			if ok and not inFlowerBed(lx, lz) then
				local dx = lx - fx
				local dz = lz - fz
				local dSq = dx * dx + dz * dz
				if dSq <= reachSq then
					local fade = HubGrassMask.FadeFactor(math.sqrt(dSq))
					if fade > 0.04 then
						table.insert(candidates, {
							lx = lx,
							lz = lz,
							distSq = dSq,
							fade = fade,
							density = density,
							yaw = yaw,
						})
					end
				end
			end
		end
	end

	local count = #candidates
	if count > poolSize then
		table.sort(candidates, function(a: Candidate, b: Candidate): boolean
			return a.distSq < b.distSq
		end)
		count = poolSize
	end

	table.clear(moveParts)
	table.clear(moveCFrames)

	for i = 1, count do
		local c = candidates[i]
		-- Subtle deterministic height embed variation + smooth emergence sink at outer perimeter
		local embedVariation = (math.clamp(c.density, 0.35, 0.95) - 0.85) * 0.35
		local sinkY = -(1 - c.fade) * (clumpHeight + 0.14)
		local worldY = GROUND_Y + centerOffsetY + embedVariation + sinkY
		local tilt = (1 - c.fade) * 0.18
		moveParts[i] = poolParts[i]
		moveCFrames[i] = CFrame.new(HUB_CENTRE.X + c.lx, worldY, HUB_CENTRE.Z + c.lz) * CFrame.Angles(tilt, c.yaw, 0)
	end

	for i = count + 1, activeCount do
		moveParts[i] = poolParts[i]
		moveCFrames[i] = HIDDEN_CFRAME
	end

	activeCount = count
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

RunService.Heartbeat:Connect(function()
	debug.profilebegin("HubProximityGrass")
	updateProximityGrass()
	debug.profileend()
end)

script.Destroying:Connect(function()
	if grassFolder and grassFolder.Parent then
		grassFolder:Destroy()
	end
end)
