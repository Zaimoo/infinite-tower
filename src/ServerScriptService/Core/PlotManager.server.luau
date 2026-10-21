--!strict
-- ServerScriptService/Core/PlotManager.server.luau
-- Assigns 1 of 6 Waiting Room plots to each Master & manages physical Plot Worker/Bed visuals

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

local ArtPackVisuals = require(ReplicatedStorage.Assets:WaitForChild("ArtPackVisuals"))
local PlotManager = {}
local AssignedPlots: { [number]: Player? } = {} -- [1..5] = Player
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

function PlotManager.GetPlotOwner(plotIndex: number): Player?
	return AssignedPlots[plotIndex]
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
	if art then torso.Transparency=1;head.Transparency=1 end
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

local function assignPlotToPlayer(player: Player)
	local dm = getDataManager()
	local chosenIdx = 1
	for i = 1, 5 do
		if AssignedPlots[i] == nil then
			chosenIdx = i
			break
		end
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
		local spawnLoc = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
		if spawnLoc then
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
			local workers = plotModel:FindFirstChild("ActivePlotWorkers")
			if workers then
				workers:ClearAllChildren()
			end
		end
	end
end)

_G.PlotManager = PlotManager

