--!strict
-- ServerScriptService/Core/PlotManager.server.luau
-- Assigns 1 of 6 Waiting Room plots to each Master, manages physical Plot Worker/Bed visuals,
-- and enforces server-authoritative private plot ownership and gate access.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

local FacilityPresence = require(script.Parent:WaitForChild("FacilityPresence"))
local PlotManager = {}
local AssignedPlots: { [number]: Player? } = {} -- [1..6] = Player
local PlayerToPlotIndex: { [Player]: number } = {}

local function getDataManager(): any
	while not _G.DataManager do
		task.wait(0.05)
	end
	return _G.DataManager
end

function PlotManager.GetPlayerPlotModel(player: Player): Model?
	local idx = PlayerToPlotIndex[player]
	if not idx then
		return nil
	end
	return PlotsFolder:FindFirstChild("Plot_" .. tostring(idx)) :: Model?
end

function PlotManager.GetPlayerPlotIndex(player: Player): number?
	return PlayerToPlotIndex[player]
end

function PlotManager.GetPlotOwner(plotIndex: number): Player?
	return AssignedPlots[plotIndex]
end

-- Validates that the caller owns an active plot, and optionally that targetPlot matches their owned plot.
-- Rejects if targetPlot belongs to another player.
function PlotManager.IsPlayerPlotOwner(player: Player, targetPlot: any?): boolean
	if not player or not player:IsDescendantOf(Players) then
		return false
	end

	local ownedPlot = PlotManager.GetPlayerPlotModel(player)
	if not ownedPlot then
		return false
	end

	local ownerUserId = ownedPlot:GetAttribute("OwnerUserId")
	if ownerUserId ~= player.UserId then
		return false
	end

	if targetPlot ~= nil then
		if typeof(targetPlot) == "Instance" then
			if targetPlot ~= ownedPlot and not targetPlot:IsDescendantOf(ownedPlot) then
				return false
			end
		elseif type(targetPlot) == "number" then
			if PlayerToPlotIndex[player] ~= targetPlot then
				return false
			end
		elseif type(targetPlot) == "string" then
			if ownedPlot.Name ~= targetPlot then
				return false
			end
		end
	end

	return true
end

function PlotManager.RefreshPlotVisuals(player: Player)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	local plotModel = PlotManager.GetPlayerPlotModel(player)
	if not profile or not plotModel then
		return
	end

	-- Support facilities stand on the plot only once built in the Fortress Tree (Phase 4 §5.6).
	local facilities = profile.Facilities or {}
	local levels: { [string]: number } = {}
	for _, name in { "Market", "TrainingGrounds", "GodsBlessing" } do
		local data = facilities[name]
		levels[name] = if data and type(data.Level) == "number" then data.Level else 0
	end
	FacilityPresence.Apply(plotModel, levels)

	local workersContainer = plotModel:FindFirstChild("ActivePlotWorkers")
	if not workersContainer then
		workersContainer = Instance.new("Folder")
		workersContainer.Name = "ActivePlotWorkers"
		workersContainer.Parent = plotModel
	end
	workersContainer:ClearAllChildren()
end

-- Lantern burst on the God's Blessing angel after a lucky summon.
function PlotManager.PulseBlessing(player: Player)
	local plotModel = PlotManager.GetPlayerPlotModel(player)
	if plotModel then
		FacilityPresence.Pulse(plotModel)
	end
end

function PlotManager.TeleportPlayerToPlot(player: Player)
	local plotModel = PlotManager.GetPlayerPlotModel(player)
	if not plotModel then
		return
	end
	local spawnLoc = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if spawnLoc and hrp then
		hrp.CFrame = spawnLoc.CFrame * CFrame.new(0, 4, 0)
		require(script.Parent.TowerFloorService).CommitRespawn(player)
	end
end

local function setupPlotGateBarrier(plotModel: Model)
	local barrier = plotModel:FindFirstChild("GateBarrier", true) :: BasePart?
	if not barrier then
		return
	end

	-- Open visiting: gate opening is completely walkable in both directions
	barrier.CanCollide = false
	barrier.CanTouch = false
	barrier.Transparency = 1
end

local function initializePlotModel(plotModel: Model)
	plotModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	if not plotModel:GetAttribute("OwnerUserId") then
		plotModel:SetAttribute("OwnerUserId", 0)
	end
	if not plotModel:GetAttribute("OwnerName") then
		plotModel:SetAttribute("OwnerName", "Unclaimed")
	end

	local anchor = plotModel:FindFirstChild("PlotBeaconAnchor") :: Model?
	if not anchor then
		local island = plotModel:FindFirstChild("FloatingFortressIsland")
		local surface = island and island:FindFirstChild("IslandTopSurface") :: BasePart?
		local pos = surface and surface.Position or (plotModel:FindFirstChild("PlotSpawn") and (plotModel.PlotSpawn :: BasePart).Position or Vector3.zero)
		local anchorModel = Instance.new("Model")
		anchorModel.Name = "PlotBeaconAnchor"
		anchorModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

		local anchorPart = Instance.new("Part")
		anchorPart.Name = "AnchorPart"
		anchorPart.Size = Vector3.new(2, 2, 2)
		anchorPart.Transparency = 1
		anchorPart.CanCollide = false
		anchorPart.CanTouch = false
		anchorPart.CanQuery = false
		anchorPart.Anchored = true
		anchorPart.CFrame = CFrame.new(pos.X, 12, pos.Z)
		anchorPart.Parent = anchorModel

		anchorModel.PrimaryPart = anchorPart
		anchorModel.Parent = plotModel
		anchor = anchorModel
	end
	if anchor then
		anchor.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		anchor:SetAttribute("OwnerUserId", plotModel:GetAttribute("OwnerUserId") or 0)
		anchor:SetAttribute("OwnerName", plotModel:GetAttribute("OwnerName") or "Unclaimed")
	end

	local spawnLoc = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
	if spawnLoc then
		spawnLoc.Neutral = false
	end

	setupPlotGateBarrier(plotModel)

	-- The fountain is placed by the island builder, possibly after the plot's facilities were applied.
	plotModel.ChildAdded:Connect(function(child)
		if child.Name == "PlazaFountain" then
			task.defer(FacilityPresence.Reapply, plotModel)
		end
	end)
	FacilityPresence.Reapply(plotModel)
end

-- Initialize all current and future plots
for _, plot in ipairs(PlotsFolder:GetChildren()) do
	if plot:IsA("Model") then
		initializePlotModel(plot)
	end
end

PlotsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		task.wait(0.2)
		initializePlotModel(child)
	end
end)

local function assignPlotToPlayer(player: Player)
	local dm = getDataManager()
	local chosenIdx: number? = nil
	for i = 1, 6 do
		if AssignedPlots[i] == nil then
			chosenIdx = i
			break
		end
	end
	if not chosenIdx then
		warn(string.format("[PlotManager] All plots occupied! Cannot assign plot for %s (%d)", player.Name, player.UserId))
		return
	end
	AssignedPlots[chosenIdx] = player
	PlayerToPlotIndex[player] = chosenIdx

	local profile = dm.GetProfile(player)
	if profile then
		profile.PlotIndex = chosenIdx
	end

	local plotModel = PlotsFolder:FindFirstChild("Plot_" .. tostring(chosenIdx)) :: Model?
	if plotModel then
		plotModel:SetAttribute("OwnerUserId", player.UserId)
		plotModel:SetAttribute("OwnerName", player.DisplayName)
		local anchor = plotModel:FindFirstChild("PlotBeaconAnchor") :: Model?
		if anchor then
			anchor:SetAttribute("OwnerUserId", player.UserId)
			anchor:SetAttribute("OwnerName", player.DisplayName)
		end
		local spawnLoc = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
		if spawnLoc then
			spawnLoc.Neutral = false
			player.RespawnLocation = spawnLoc
		end
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		PlotManager.TeleportPlayerToPlot(player)
		PlotManager.RefreshPlotVisuals(player)
	end)

	if player.Character then
		task.defer(function()
			PlotManager.TeleportPlayerToPlot(player)
			PlotManager.RefreshPlotVisuals(player)
		end)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(assignPlotToPlayer, p)
end
Players.PlayerAdded:Connect(assignPlotToPlayer)

Players.PlayerRemoving:Connect(function(player: Player)
	local idx = PlayerToPlotIndex[player]
	if idx then
		AssignedPlots[idx] = nil
		PlayerToPlotIndex[player] = nil
		local plotModel = PlotsFolder:FindFirstChild("Plot_" .. tostring(idx)) :: Model?
		if plotModel then
			plotModel:SetAttribute("OwnerUserId", 0)
			plotModel:SetAttribute("OwnerName", "Unclaimed")
			local anchor = plotModel:FindFirstChild("PlotBeaconAnchor") :: Model?
			if anchor then
				anchor:SetAttribute("OwnerUserId", 0)
				anchor:SetAttribute("OwnerName", "Unclaimed")
			end
			local workers = plotModel:FindFirstChild("ActivePlotWorkers")
			if workers then
				workers:ClearAllChildren()
			end
			FacilityPresence.Reset(plotModel)
		end
	end
end)

_G.PlotManager = PlotManager

return PlotManager
