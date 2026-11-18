--!nocheck
-- tests/studio-leaderboard-import.luau
-- Studio (Edit mode) helper to finalize imported Blender FBX monuments:
--   assets/models/leaderboards/leaderboard_pediment_frame.fbx
--   assets/models/leaderboards/leaderboard_power_monolith.fbx
--
-- Usage:
--   1. In Roblox Studio: File > Import 3D and select the two .fbx files above (keep separate parts).
--   2. Run this script in the Command Bar or through Studio MCP execute_luau.
--   3. It stores the finalized MeshPart models under ReplicatedStorage.Assets.CustomFacilityMeshes
--      and prints the JSON MeshId map for assets/models/leaderboards/mesh_ids.json.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local LeaderboardMeshData = require(Assets:WaitForChild("LeaderboardMeshData"))

local customMeshes = Assets:FindFirstChild("CustomFacilityMeshes")
if not customMeshes then
	customMeshes = Instance.new("Folder")
	customMeshes.Name = "CustomFacilityMeshes"
	customMeshes.Parent = Assets
end

local TARGETS = {
	leaderboard_pediment_frame = "LeaderboardPedimentFrame",
	leaderboard_power_monolith = "LeaderboardPowerMonolith",
}

local meshIds = {}
local summary = {}

for modelKey, studioName in pairs(TARGETS) do
	local source = workspace:FindFirstChild(modelKey) or workspace:FindFirstChild(studioName)
	if not source then
		summary[modelKey] = "NOT_IN_WORKSPACE"
		continue
	end

	local specs = LeaderboardMeshData.Models[modelKey]
	local specByName = {}
	for _, s in ipairs(specs) do
		specByName[s.Name] = s
	end

	local container = Instance.new("Model")
	container.Name = studioName
	local idsForModel = {}
	local count = 0

	for _, desc in ipairs(source:GetDescendants()) do
		if desc:IsA("MeshPart") then
			local clean = string.gsub(desc.Name, "%.%d+$", "")
			local spec = specByName[clean]
			local mp = desc:Clone()
			mp.Name = clean
			mp.Anchored = true
			if spec then
				mp.Size = spec.Size
				mp.Material = spec.Material
				mp.Color = spec.Color
				mp.CanCollide = spec.Collidable
				mp.CanQuery = spec.Collidable
				mp.CanTouch = false
			end
			mp.Parent = container
			idsForModel[clean] = mp.MeshId
			count += 1
		end
	end

	local old = customMeshes:FindFirstChild(studioName)
	if old then
		old:Destroy()
	end
	container.Parent = customMeshes
	source:Destroy()
	meshIds[modelKey] = idsForModel
	summary[modelKey] = string.format("IMPORTED %d MeshParts -> ReplicatedStorage.Assets.CustomFacilityMeshes.%s", count, studioName)
end

local jsonIds = HttpService:JSONEncode(meshIds)
print("[LeaderboardImport]", HttpService:JSONEncode(summary))
print("MESH_IDS_JSON=" .. jsonIds)
return jsonIds
