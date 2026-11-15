--!strict
-- ServerScriptService/BaseOverhaul/SceneryBake.luau
-- Swaps a builder's plain parts for a handful of Blender-merged MeshParts.
--
-- Some hub scenery is thousands of small blocks (FortressWalls is ~2,300 per plot). Each one is an
-- instance to replicate, stream and cull. tools/blender/bake_scenery_meshes.py merges the same geometry
-- into one mesh per material and colour; this module then removes the parts and places those meshes.
--
--   * A part is baked when it is plain scenery: opaque, no children (lights, emitters, attachments stay
--     on real parts), no CollectionService tags, and a block, cylinder or wedge.
--   * A baked part that collides is kept as an invisible collider, so walking, navigation and raycasts
--     are unchanged. One that does not collide is destroyed.
--   * The mesh must match the parts it replaces. Each bake records a Signature of the baked parts
--     (BakedSceneryIndex); if the builder has changed since, the signature differs and the parts are left
--     alone with a warning. Re-run the bake (docs/performance-plan.md) to pick the change up.
--   * The imported template is ReplicatedStorage.Assets.BakedScenery.<AssetName>. Until it is imported,
--     Apply does nothing and the builder's parts are used as before.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Index = require(script.Parent:WaitForChild("BakedSceneryIndex"))

local SceneryBake = {}

SceneryBake.TEMPLATE_FOLDER = "BakedScenery"
-- Three marker cubes exported with the meshes: the bake's origin and points MARKER_AXIS_DISTANCE studs
-- along its X and Y axes. Their positions give the bake's frame however the import placed the model.
SceneryBake.ORIGIN_MARKER = "BakeOrigin"
SceneryBake.AXIS_X_MARKER = "BakeAxisX"
SceneryBake.AXIS_Y_MARKER = "BakeAxisY"
SceneryBake.MARKER_AXIS_DISTANCE = 10
SceneryBake.COLLIDER_ATTRIBUTE = "BakedCollider"
SceneryBake.CONTAINER_NAME = "BakedMeshes"

-- Sizes and positions are compared to 0.01 stud, rotation matrix entries to 0.001.
local LENGTH_STEPS = 100
local ROTATION_STEPS = 1000

local function quantize(value: number, steps: number): number
	return math.round(value * steps) + 0 -- "+ 0" turns -0 into 0
end

-- "B" block, "C" cylinder, "W" wedge; nil when the part's shape is not one the bake can rebuild.
function SceneryBake.ShapeCode(part: BasePart): string?
	if part:IsA("WedgePart") then
		return "W"
	elseif part:IsA("Part") then
		if part.Shape == Enum.PartType.Block then
			return "B"
		elseif part.Shape == Enum.PartType.Cylinder then
			return "C"
		end
	end
	return nil
end

function SceneryBake.IsBakeable(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	if part.Transparency ~= 0 or part:GetAttribute(SceneryBake.COLLIDER_ATTRIBUTE) == true then
		return false
	end
	if #part:GetChildren() > 0 or #CollectionService:GetTags(part) > 0 then
		return false
	end
	return SceneryBake.ShapeCode(part) ~= nil
end

function SceneryBake.BakeableParts(root: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, d in root:GetDescendants() do
		if SceneryBake.IsBakeable(d) then
			table.insert(parts, d :: BasePart)
		end
	end
	return parts
end

-- The material-and-colour group a part is merged into, e.g. "Slate_3b4048".
function SceneryBake.GroupKey(part: BasePart): string
	return part.Material.Name .. "_" .. string.lower(part.Color:ToHex())
end

-- One part as numbers, in `frame`'s space: 3 size, 3 position and 9 rotation entries, all quantized.
function SceneryBake.Describe(part: BasePart, frame: CFrame): { number }
	local cf = frame:ToObjectSpace(part.CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local size = part.Size
	return {
		quantize(size.X, LENGTH_STEPS), quantize(size.Y, LENGTH_STEPS), quantize(size.Z, LENGTH_STEPS),
		quantize(x, LENGTH_STEPS), quantize(y, LENGTH_STEPS), quantize(z, LENGTH_STEPS),
		quantize(r00, ROTATION_STEPS), quantize(r01, ROTATION_STEPS), quantize(r02, ROTATION_STEPS),
		quantize(r10, ROTATION_STEPS), quantize(r11, ROTATION_STEPS), quantize(r12, ROTATION_STEPS),
		quantize(r20, ROTATION_STEPS), quantize(r21, ROTATION_STEPS), quantize(r22, ROTATION_STEPS),
	}
end

local function hashString(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		-- FNV-1a prime 16777619 = 2^24 + 403, multiplied in two steps so the product stays exact in a double
		h = bit32.band(bit32.lshift(h, 24) + h * 403, 0xFFFFFFFF)
	end
	return h
end

-- Identifies a set of bakeable parts regardless of their order: "<count>-<sum>-<xor>".
function SceneryBake.Signature(root: Instance, frame: CFrame): string
	local count, sum, xor = 0, 0, 0
	for _, part in SceneryBake.BakeableParts(root) do
		local text = (SceneryBake.ShapeCode(part) :: string) .. "|" .. SceneryBake.GroupKey(part) .. "|" .. table.concat(SceneryBake.Describe(part, frame), ",")
		local h = hashString(text)
		count += 1
		sum = (sum + h) % 4294967296
		xor = bit32.bxor(xor, h)
	end
	return string.format("%d-%08x-%08x", count, sum, xor)
end

function SceneryBake.Template(assetName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(SceneryBake.TEMPLATE_FOLDER)
	local template = folder and folder:FindFirstChild(assetName)
	if template and template:IsA("Model") and template:FindFirstChild(SceneryBake.ORIGIN_MARKER, true) then
		return template
	end
	return nil
end

-- Names every bake that is ready to use. HubOverhaul appends it to its version, so importing or
-- re-baking a template rebuilds the baked hub on the next server start.
function SceneryBake.VersionTag(): string
	local names: { string } = {}
	for name in Index do
		table.insert(names, name)
	end
	table.sort(names)
	local tags: { string } = {}
	for _, name in names do
		if SceneryBake.Template(name) then
			table.insert(tags, name .. ":" .. Index[name].Signature)
		end
	end
	return table.concat(tags, ";")
end

-- Replaces `root`'s bakeable parts with the baked meshes for `assetName`. `frame` is the space the bake
-- was made in (the builder's local origin). Returns true when the swap happened.
function SceneryBake.Apply(root: Instance, frame: CFrame, assetName: string): boolean
	local entry = Index[assetName]
	local template = SceneryBake.Template(assetName)
	if not entry or not template then
		return false
	end
	local signature = SceneryBake.Signature(root, frame)
	if signature ~= entry.Signature then
		warn(string.format(
			"[SceneryBake] %s: parts no longer match the baked mesh (built %s, baked %s). Keeping parts; re-run the bake.",
			assetName, signature, entry.Signature
		))
		return false
	end
	local marker = template:FindFirstChild(SceneryBake.ORIGIN_MARKER, true)
	local markerX = template:FindFirstChild(SceneryBake.AXIS_X_MARKER, true)
	local markerY = template:FindFirstChild(SceneryBake.AXIS_Y_MARKER, true)
	if not (marker and marker:IsA("BasePart") and markerX and markerX:IsA("BasePart") and markerY and markerY:IsA("BasePart")) then
		warn(string.format("[SceneryBake] %s: template has no BakeOrigin/BakeAxisX/BakeAxisY markers. Keeping parts.", assetName))
		return false
	end
	local toX = markerX.Position - marker.Position
	local toY = markerY.Position - marker.Position
	local d = SceneryBake.MARKER_AXIS_DISTANCE
	if math.abs(toX.Magnitude - d) > 0.05 or math.abs(toY.Magnitude - d) > 0.05 or math.abs(toX.Unit:Dot(toY.Unit)) > 0.01 then
		warn(string.format("[SceneryBake] %s: template was imported scaled or skewed (markers %.2f and %.2f studs apart, expected %d). Keeping parts.",
			assetName, toX.Magnitude, toY.Magnitude, d))
		return false
	end
	-- The bake's frame in the template's world space
	local bakeFrame = CFrame.fromMatrix(marker.Position, toX.Unit, toY.Unit)
	local isMarker = { [marker :: Instance] = true, [markerX :: Instance] = true, [markerY :: Instance] = true }

	for _, part in SceneryBake.BakeableParts(root) do
		if part.CanCollide then
			part.Transparency = 1
			part.CastShadow = false
			part:SetAttribute(SceneryBake.COLLIDER_ATTRIBUTE, true)
		else
			part:Destroy()
		end
	end

	local container = Instance.new("Folder")
	container.Name = SceneryBake.CONTAINER_NAME
	for _, source in template:GetDescendants() do
		local look = entry.Meshes[source.Name]
		if source:IsA("MeshPart") and not isMarker[source] and look then
			local mesh = source:Clone()
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = false
			mesh.Massless = true
			mesh.Material = (Enum.Material :: any)[look.Material]
			mesh.Color = Color3.fromHex(look.Color)
			mesh.CFrame = frame * bakeFrame:ToObjectSpace(source.CFrame)
			mesh.Parent = container
		end
	end
	container.Parent = root
	return true
end

return SceneryBake
