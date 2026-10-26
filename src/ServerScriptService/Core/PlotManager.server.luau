--!strict
-- ServerScriptService/Core/PlotManager.server.luau
-- Assigns 1 of 6 Waiting Room plots to each Master, manages physical Plot Worker/Bed visuals,
-- and enforces server-authoritative private plot ownership and gate access.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

local ArtPackVisuals = require(ReplicatedStorage.Assets:WaitForChild("ArtPackVisuals"))
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

local function createWorkerAvatarPart(parent: Instance, hero: any, cframe: CFrame, isSleepingInBed: boolean?)
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	local color = seed and seed.Color or Color3.fromRGB(110, 185, 255)

	local model = Instance.new("Model")
	model.Name = "PlotWorker_" .. tostring(hero.UUID)
	model.Parent = parent

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.0, 2.6, 1.1)
	torso.Color = color
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = true
	torso.CanCollide = false
	if isSleepingInBed then
		torso.CFrame = cframe * CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(90), 0, 0)
	else
		torso.CFrame = cframe * CFrame.new(0, 2.3, 0)
	end
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = Color3.fromRGB(245, 215, 190)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CFrame = torso.CFrame * CFrame.new(0, 2.0, 0)
	head.Parent = model

	local ground = cframe
	if isSleepingInBed then ground=cframe*CFrame.new(0,1.2,0)*CFrame.Angles(math.rad(90),0,0)*CFrame.new(0,-1.9,0) end
	local art=ArtPackVisuals.AttachAt(model,hero.TemplateId or "hero_han",ground,isSleepingInBed and .72 or 1)
	if art then
		torso.Transparency=1;head.Transparency=1
		-- Hero rigs are unanchored assemblies; anchor the root so the worker stays on its bed
		-- (joints keep the rest pose, since server-side Motor6D poses do not replicate).
		local root=art:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then root.Anchored=true end
	end
end

function PlotManager.RefreshPlotVisuals(player: Player)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	local plotModel = PlotManager.GetPlayerPlotModel(player)
	if not profile or not plotModel then
		return
	end

	local workersContainer = plotModel:FindFirstChild("ActivePlotWorkers")
	if not workersContainer then
		workersContainer = Instance.new("Folder")
		workersContainer.Name = "ActivePlotWorkers"
		workersContainer.Parent = plotModel
	end
	workersContainer:ClearAllChildren()

	-- Render Infirmary Healers & Resting/Comatose Heroes on Recuperation Beds in Building_Infirmary
	local pb = plotModel:FindFirstChild("PlotBuildings")
	local infModel = pb and pb:FindFirstChild("Building_Infirmary")
	if infModel then
		local bedIdx = 1
		for _, hero in pairs(profile.Heroes) do
			if hero.Assignment == "FACILITY_INFIRMARY" and bedIdx <= 5 then
				local bedPart = (infModel:FindFirstChild("Mattress_" .. tostring(bedIdx))
					or infModel:FindFirstChild("BedFrame_" .. tostring(bedIdx))) :: BasePart?
				if bedPart then
					createWorkerAvatarPart(workersContainer, hero, bedPart.CFrame, true)
					bedIdx += 1
				end
			end
		end
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
		end
	end
end)

_G.PlotManager = PlotManager

return PlotManager
