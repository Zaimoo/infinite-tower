--!strict
-- studio-hubpaths-import.luau
-- Paste/run in Roblox Studio Command Bar after File > Import 3D of:
--   assets/models/environment/HubCobblePaths.fbx
-- It normalizes the imported Model into ReplicatedStorage.Assets.Environment.HubCobblePaths,
-- applies each part's Runesmith/castle material & color, and rebuilds the Hub paths and fantasy bridges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder", ReplicatedStorage)
assets.Name = "Assets"
local env = assets:FindFirstChild("Environment") or Instance.new("Folder", assets)
env.Name = "Environment"

local imported = Workspace:FindFirstChild("HubCobblePaths") or env:FindFirstChild("HubCobblePaths") or assets:FindFirstChild("HubCobblePaths")
assert(imported, "Import assets/models/environment/HubCobblePaths.fbx into Workspace or ReplicatedStorage.Assets.Environment first.")

imported.Name = "HubCobblePaths"
imported.Parent = env

for _, desc in imported:GetDescendants() do
	if desc:IsA("BasePart") then
		if desc.Name == "Hub_PlotBridgeParapets" or desc.Name == "Hub_PlotBridgeSpires" then
			desc.Material = Enum.Material.Slate
			desc.Color = Color3.fromRGB(104, 106, 110)
		else
			desc.Material = Enum.Material.Cobblestone
			desc.Color = Color3.fromRGB(116, 112, 98)
		end
		desc.MaterialVariant = ""
		desc.Anchored = true
		desc.CanCollide = false
		desc.CanQuery = false
		desc.CanTouch = false
		desc.CastShadow = true
	end
end

local baseOverhaul = ServerScriptService:WaitForChild("BaseOverhaul")
local HubOverhaul = require(baseOverhaul:WaitForChild("HubOverhaul"))
local BridgeBuilder = require(baseOverhaul:WaitForChild("BridgeBuilder"))

HubOverhaul.Build(true)
BridgeBuilder.Build()
print("[studio-hubpaths-import] Applied imported HubCobblePaths & Fantasy Castle Bridge meshes across Hub and IslandTowerBridges.")
