--!strict
-- ServerScriptService/Tycoon/BlacksmithService.server.luau
-- Authoritative Blacksmith Facility & Upgrade System
-- Cleans up legacy station instances and interfaces with PlotBuildings.Building_Blacksmith.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

local BlacksmithService = {}

function BlacksmithService.ConfigurePlot(plotModel: Instance)
	-- Remove legacy standalone station if present (now replaced by ornate Building_Blacksmith in PlotBuildings)
	local legacyStation = plotModel:FindFirstChild("Facility_Blacksmith")
	if legacyStation then
		legacyStation:Destroy()
	end
end

-- Initialize for all current plots and future plots
for _, plot in ipairs(PlotsFolder:GetChildren()) do
	task.spawn(BlacksmithService.ConfigurePlot, plot)
end

PlotsFolder.ChildAdded:Connect(function(child)
	task.defer(BlacksmithService.ConfigurePlot, child)
end)

_G.BlacksmithService = BlacksmithService

return BlacksmithService
