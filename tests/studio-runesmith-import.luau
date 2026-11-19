--!nocheck
-- tests/studio-runesmith-import.luau
-- Studio (Edit mode) helper to finalize the imported Blender FBX for the Runesmith's Anvil Sanctuary:
--   1. In Roblox Studio: File > Import 3D and select:
--        - assets/models/runesmith_sanctuary/RunesmithSanctuary.fbx (keep separate parts)
--        - assets/models/environment/HubCommonsGround.fbx (updated chasm hole ground -> place under ReplicatedStorage.Assets.Environment.HubCommons_Ground)
--   2. Run this script in the Command Bar or through Studio MCP execute_luau.
--   3. It stores the finalized 22 MeshParts under ReplicatedStorage.Assets.CustomFacilityMeshes.RunesmithSanctuary
--      (so RunesmithMeshHydrator uses the uploaded MeshParts directly) and prints mesh_ids.json for RunesmithMeshData.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local RunesmithMeshData = require(Assets:WaitForChild("RunesmithMeshData"))

local customMeshes = Assets:FindFirstChild("CustomFacilityMeshes")
if not customMeshes then
	customMeshes = Instance.new("Folder")
	customMeshes.Name = "CustomFacilityMeshes"
	customMeshes.Parent = Assets
end

local source = workspace:FindFirstChild("RunesmithSanctuary") or workspace:FindFirstChild("runesmith_sanctuary")
if not source then
	warn("[RunesmithImport] RunesmithSanctuary model not found in Workspace. Import RunesmithSanctuary.fbx via File > Import 3D first.")
	return "NOT_IN_WORKSPACE"
end

local specs = RunesmithMeshData.Models.runesmith_sanctuary
local specByName = {}
for _, s in ipairs(specs) do
	specByName[s.Name] = s
end

local container = Instance.new("Model")
container.Name = "RunesmithSanctuary"
local idsForModel = {}
local count = 0

for _, desc in ipairs(source:GetDescendants()) do
	if desc:IsA("MeshPart") then
		local clean = string.gsub(desc.Name, "%.%d+$", "")
		local spec = specByName[clean]
		local mp = desc:Clone()
		mp.Name = clean
		mp.Anchored = true
		mp.PivotOffset = CFrame.identity
		if spec then
			mp.Size = spec.Size
			mp.Material = spec.Material
			mp.Color = spec.Color
			mp.CanCollide = false
			mp.CanQuery = false
			mp.CanTouch = false
			mp.CastShadow = spec.Material ~= Enum.Material.Neon
		end
		mp.Parent = container
		idsForModel[clean] = mp.MeshId
		count += 1
	end
end

local old = customMeshes:FindFirstChild("RunesmithSanctuary")
if old then
	old:Destroy()
end
container.Parent = customMeshes
source:Destroy()

local jsonIds = HttpService:JSONEncode({ runesmith_sanctuary = idsForModel })
print(string.format("[RunesmithImport] IMPORTED %d MeshParts -> ReplicatedStorage.Assets.CustomFacilityMeshes.RunesmithSanctuary", count))
print("MESH_IDS_JSON=" .. jsonIds)
return jsonIds
