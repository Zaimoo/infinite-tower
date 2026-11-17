--!strict
-- GothicTowerShell.luau
-- Swaps the part-built look of `CentralCrimsonTower` for the Blender remodel: a dark-slate gothic drum with
-- crimson tracery windows and a balcony on every tier, a lantern crown, pinnacle turrets and a great spire
-- (tools/blender/generate_gothic_tower_remodel.py -> assets/models/central_tower/GothicTowerRemodel.fbx).
--
-- Import: in Studio, import GothicTowerRemodel.fbx with the 3D Importer at file scale (1 unit = 1 stud), without
-- merging meshes, and put the Model in ReplicatedStorage.Assets.TowerMeshes named `GothicTower`. It must
-- contain the TowerOrigin, TowerAxisX and TowerAxisY marker cubes, which give the frame the meshes were made in.
-- Until it is there (or when TowerBuilder.Config no longer matches the modelled layout) the part tower stays.
--
-- What stays from the part tower: the ground slab, crag, cloud bank and storm VFX, the bridge threshold, the
-- portal trigger, the sky beacon, the root parts and their sockets, and `TowerRings` (now invisible), which
-- remain the tower's collision. Each stage's tier is modelled once (objects named `...Tier<N>...`) and cloned
-- up its stage here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GothicTowerShell = {}

GothicTowerShell.TEMPLATE_FOLDER = "TowerMeshes"
GothicTowerShell.TEMPLATE_NAME = "GothicTower"
GothicTowerShell.ORIGIN_MARKER = "TowerOrigin"
GothicTowerShell.AXIS_X_MARKER = "TowerAxisX"
GothicTowerShell.AXIS_Y_MARKER = "TowerAxisY"
GothicTowerShell.MARKER_AXIS_DISTANCE = 10
GothicTowerShell.CONTAINER_NAME = "GothicTowerShell"
-- Bump when the generator's output changes, so baked hubs rebuild with the new meshes
GothicTowerShell.MeshVersion = 2

-- The layout the meshes were modelled for. TowerBuilder.Config must match it, since `TowerRings` (the
-- collision) and the crown sockets follow the config.
GothicTowerShell.Layout = table.freeze({
	TowerDiameter = 650,
	BaseHeight = 84,
	MidSegmentHeight = 96,
	MidSegmentCount = 16,
	StageSegmentCounts = table.freeze({ 4, 4, 4, 4 }),
	StageDiameters = table.freeze({ 650, 602, 554, 506 }),
	CrownInset = 36,
	CrownLanternHeight = 104,
	GreatSpireHeight = 420,
})

type Look = { Material: Enum.Material, Color: Color3, CastShadow: boolean }

-- The tower keeps the part tower's palette (TowerBuilder.Config): dark slate walls, the slightly lighter
-- ashlar tone on mouldings, tracery and balconies, and the crimson glow in the windows.
local function looksFor(cfg: { [string]: any }): { [string]: Look }
	return {
		Stone = { Material = cfg.Zone1MasonryMaterial, Color = cfg.Zone1MasonryColor, CastShadow = true },
		Trim = { Material = cfg.Zone1MasonryMaterial, Color = cfg.Zone1AshlarColor, CastShadow = true },
		Glass = { Material = cfg.Zone2WindowMaterial, Color = cfg.Zone2WindowColor, CastShadow = false },
	}
end

-- Invisible blocks around the gate porch (tower space: origin at the tower's bottom centre, gate facing -Z)
local PORCH_COLLIDERS = {
	{ Name = "PorchCollider_L", Min = Vector3.new(-43, 0, -345), Max = Vector3.new(-20, 104, -316) },
	{ Name = "PorchCollider_R", Min = Vector3.new(20, 0, -345), Max = Vector3.new(43, 104, -316) },
	{ Name = "PorchCollider_Top", Min = Vector3.new(-20, 79, -345), Max = Vector3.new(20, 104, -316) },
}

-- Part-tower pieces the meshes replace are destroyed; these are kept (by parent model, then name)
local KEEP: { [string]: { [string]: boolean } } = {
	Tower_Base_Entrance = { BaseOriginRoot = true, BridgeThresholdApron = true, ThresholdIronCurb_L = true, ThresholdIronCurb_R = true, BasePlinthTier1 = true, BasePlinthTier2 = true },
	TowerBaseEntrance = { EntrancePortalTrigger = true },
	Tower_Crown = { CrownOriginRoot = true, SkyBeaconOrb = true, SkyBeaconBeam = true },
}
-- Kept, but only as invisible colliders under the mesh
local HIDE = { BasePlinthTier1 = true, BasePlinthTier2 = true }

function GothicTowerShell.Template(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(GothicTowerShell.TEMPLATE_FOLDER)
	local template = folder and folder:FindFirstChild(GothicTowerShell.TEMPLATE_NAME)
	if template and template:IsA("Model") and template:FindFirstChild(GothicTowerShell.ORIGIN_MARKER, true) then
		return template
	end
	return nil
end

local function sameList(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if b[i] ~= v then
			return false
		end
	end
	return true
end

-- True when `cfg` builds the layout the meshes were modelled for.
function GothicTowerShell.MatchesLayout(cfg: { [string]: any }): boolean
	local layout = GothicTowerShell.Layout
	return cfg.TowerDiameter == layout.TowerDiameter
		and cfg.BaseHeight == layout.BaseHeight
		and cfg.MidSegmentHeight == layout.MidSegmentHeight
		and cfg.MidSegmentCount == layout.MidSegmentCount
		and cfg.CrownInset == layout.CrownInset
		and cfg.CrownLanternHeight == layout.CrownLanternHeight
		and cfg.GreatSpireHeight == layout.GreatSpireHeight
		and sameList(cfg.StageSegmentCounts, layout.StageSegmentCounts)
		and sameList(cfg.StageDiameters, layout.StageDiameters)
end

-- True when the meshes are imported and fit `cfg`, so TowerBuilder can skip the parts they replace.
function GothicTowerShell.CanApply(cfg: { [string]: any }): boolean
	if not GothicTowerShell.Template() then
		return false
	end
	if not GothicTowerShell.MatchesLayout(cfg) then
		warn("[GothicTowerShell] TowerBuilder.Config no longer matches the modelled tower layout. Keeping the part tower; re-run the generator.")
		return false
	end
	return true
end

-- Appended to the hub's overhaul version, so importing the meshes rebuilds a baked hub once.
function GothicTowerShell.VersionTag(): string
	return if GothicTowerShell.Template() then string.format("GothicTower:%d", GothicTowerShell.MeshVersion) else ""
end

local function templateFrame(template: Model): CFrame?
	local origin = template:FindFirstChild(GothicTowerShell.ORIGIN_MARKER, true)
	local axisX = template:FindFirstChild(GothicTowerShell.AXIS_X_MARKER, true)
	local axisY = template:FindFirstChild(GothicTowerShell.AXIS_Y_MARKER, true)
	if not (origin and origin:IsA("BasePart") and axisX and axisX:IsA("BasePart") and axisY and axisY:IsA("BasePart")) then
		warn("[GothicTowerShell] template has no TowerOrigin/TowerAxisX/TowerAxisY markers.")
		return nil
	end
	local toX = axisX.Position - origin.Position
	local toY = axisY.Position - origin.Position
	local d = GothicTowerShell.MARKER_AXIS_DISTANCE
	if math.abs(toX.Magnitude - d) > 0.05 or math.abs(toY.Magnitude - d) > 0.05 or math.abs(toX.Unit:Dot(toY.Unit)) > 0.01 then
		warn(string.format("[GothicTowerShell] template was imported scaled or skewed (markers %.2f and %.2f studs apart, expected %d).", toX.Magnitude, toY.Magnitude, d))
		return nil
	end
	return CFrame.fromMatrix(origin.Position, toX.Unit, toY.Unit)
end

local function lookFor(looks: { [string]: Look }, name: string): Look?
	if string.find(name, "_Glass") then
		return looks.Glass
	elseif string.find(name, "_Trim") then
		return looks.Trim
	elseif string.find(name, "_Stone") then
		return looks.Stone
	end
	return nil
end

local function removeWindowSockets(root: Instance?)
	if not root then
		return
	end
	for _, child in root:GetChildren() do
		if child:IsA("Attachment") and string.find(child.Name, "^VFX_Window_Glow") then
			child:Destroy()
		end
	end
end

local function stripPartTower(towerModel: Model)
	for modelName, keep in KEEP do
		local model = towerModel:FindFirstChild(modelName)
		if model then
			for _, child in model:GetChildren() do
				if not keep[child.Name] then
					child:Destroy()
				elseif HIDE[child.Name] and child:IsA("BasePart") then
					child.Transparency = 1
					child.CastShadow = false
				end
			end
		end
	end
	local base = towerModel:FindFirstChild("Tower_Base_Entrance")
	removeWindowSockets(base and base:FindFirstChild("BaseOriginRoot"))
	local crown = towerModel:FindFirstChild("Tower_Crown")
	removeWindowSockets(crown and crown:FindFirstChild("CrownOriginRoot"))

	local stack = towerModel:FindFirstChild("Tower_Mid_Segments")
	if stack then
		for _, seg in stack:GetChildren() do
			for _, child in seg:GetChildren() do
				if child.Name ~= "SegmentOriginRoot" then
					child:Destroy()
				end
			end
			removeWindowSockets(seg:FindFirstChild("SegmentOriginRoot"))
		end
	end

	-- The rings stay as the tower's collision, hidden inside the mesh
	local rings = towerModel:FindFirstChild("TowerRings")
	if rings then
		for _, ring in rings:GetChildren() do
			if ring:IsA("BasePart") then
				ring.Transparency = 1
				ring.CastShadow = false
			end
		end
	end
end

-- Replaces the part tower's look with the meshes. `origin` is the tower's bottom centre (Config.CenterPosition).
-- Returns true when the swap happened.
function GothicTowerShell.Apply(towerModel: Model, origin: Vector3, cfg: { [string]: any }): boolean
	if not GothicTowerShell.CanApply(cfg) then
		return false
	end
	local template = GothicTowerShell.Template() :: Model
	local bakeFrame = templateFrame(template)
	if not bakeFrame then
		return false
	end
	local frame = CFrame.new(origin)

	stripPartTower(towerModel)

	local looks = looksFor(cfg)
	local container = Instance.new("Folder")
	container.Name = GothicTowerShell.CONTAINER_NAME
	local placed = 0
	for _, source in template:GetDescendants() do
		if not source:IsA("BasePart") or source.Name == GothicTowerShell.ORIGIN_MARKER or source.Name == GothicTowerShell.AXIS_X_MARKER or source.Name == GothicTowerShell.AXIS_Y_MARKER then
			continue
		end
		local isSocket = string.find(source.Name, "^VFX_Window_Glow") ~= nil
		local look = lookFor(looks, source.Name)
		if not isSocket and not look then
			continue
		end
		-- A stage's tier is modelled once, at the stage's first tier, and repeated up the stage
		local stage = tonumber(string.match(source.Name, "Tier(%d+)"))
		local copies = if stage then cfg.StageSegmentCounts[stage] or 1 else 1
		local relative = bakeFrame:ToObjectSpace(source.CFrame)
		for copy = 1, copies do
			local part = source:Clone()
			part.Name = if copies > 1 then string.format("%s_%d", source.Name, copy) else source.Name
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			if isSocket then
				part.Transparency = 1
				part.CastShadow = false
			elseif look then
				part.Material = look.Material
				part.Color = look.Color
				part.CastShadow = look.CastShadow
				part.Transparency = 0
			end
			part.CFrame = frame * CFrame.new(0, (copy - 1) * cfg.MidSegmentHeight, 0) * relative
			part.Parent = container
			placed += 1
		end
	end

	for _, spec in PORCH_COLLIDERS do
		local block = Instance.new("Part")
		block.Name = spec.Name
		block.Anchored = true
		block.CanCollide = true
		block.CanQuery = true
		block.CanTouch = false
		block.CastShadow = false
		block.Transparency = 1
		block.Size = spec.Max - spec.Min
		block.CFrame = frame * CFrame.new((spec.Min + spec.Max) * 0.5)
		block.Parent = container
	end

	container.Parent = towerModel
	towerModel:SetAttribute("ShellMeshed", true)
	towerModel:SetAttribute("ShellMeshParts", placed)
	return true
end

return GothicTowerShell
