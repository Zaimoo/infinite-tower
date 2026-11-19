--!strict
-- HubCobblePathsClient.client.luau
-- Hydrates EditableMesh-backed Hub cobble path and plot bridge MeshParts on the client
-- so scale=0.25 UVs and raised beveled side curbs render cleanly in live games even before FBX upload.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local HubPathMeshHydrator = require(Assets:WaitForChild("HubPathMeshHydrator"))

local function hydrateRoot(root: Instance)
	HubPathMeshHydrator.HydratePendingClientParts(root)
end

local function watchContainer(container: Instance)
	hydrateRoot(container)
	container.ChildAdded:Connect(function(child: Instance)
		if child.Name == "MastersCommons" or child.Name == "IslandTowerBridges" or child.Name == "HubCobblePaths" then
			task.defer(function()
				if child.Parent then
					hydrateRoot(child)
				end
			end)
		end
	end)
end

local existing = Workspace:FindFirstChild("BaseOverhaulGeometry")
if existing then
	watchContainer(existing)
end

Workspace.ChildAdded:Connect(function(child: Instance)
	if child.Name == "BaseOverhaulGeometry" then
		watchContainer(child)
	end
end)
