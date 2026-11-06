--!strict
-- ServerScriptService/Core/PlotManager.server.luau
-- Assigns 1 of 6 Waiting Room plots to each Master, manages physical Plot Worker/Bed visuals,
-- and enforces server-authoritative private plot ownership and gate access.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubLayout = require(Shared:WaitForChild("Config"):WaitForChild("HubLayout"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local OutskirtsRules = require(Shared:WaitForChild("Util"):WaitForChild("OutskirtsRules"))

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TeleportRequest = Remotes:FindFirstChild("TeleportRequest") :: RemoteEvent?
if not TeleportRequest then
	TeleportRequest = Instance.new("RemoteEvent")
	TeleportRequest.Name = "TeleportRequest"
	TeleportRequest.Parent = Remotes
end

local LastTeleportAt: { [Player]: number } = {}

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

	local guardPost = facilities.GuardPost
	local guardPostLevel = if guardPost and type(guardPost.Level) == "number" then guardPost.Level else 1
	local frontier = OutskirtsRules.ResolveFrontierInfo(profile.HighestClearedFloor, profile.MaxFloorReached)
	if plotModel:GetAttribute("OutskirtsFloorId") ~= frontier.FloorId then
		plotModel:SetAttribute("OutskirtsFloorId", frontier.FloorId)
	end
	if plotModel:GetAttribute("OutskirtsBiomeId") ~= frontier.BiomeId then
		plotModel:SetAttribute("OutskirtsBiomeId", frontier.BiomeId)
	end
	if plotModel:GetAttribute("GuardPostLevel") ~= guardPostLevel then
		plotModel:SetAttribute("GuardPostLevel", guardPostLevel)
	end

	local workersContainer = plotModel:FindFirstChild("ActivePlotWorkers")
	if not workersContainer then
		workersContainer = Instance.new("Folder")
		workersContainer.Name = "ActivePlotWorkers"
		workersContainer.Parent = plotModel
	end

	local heroes = profile.Heroes or {}
	local artifacts = profile.Artifacts or {}
	local keepNames: { [string]: boolean } = {}

	local function setAttrIfChanged(inst: Instance, attrName: string, attrValue: any)
		if inst:GetAttribute(attrName) ~= attrValue then
			inst:SetAttribute(attrName, attrValue)
		end
	end

	local function syncFacilityWorkers(facilityName: string, assignedList: any)
		if type(assignedList) ~= "table" then
			return
		end
		for slotIndex, uuid in ipairs(assignedList) do
			local hero = heroes[uuid]
			if not hero then
				continue
			end
			local childName = "Worker_" .. tostring(uuid)
			keepNames[childName] = true

			local entry = workersContainer:FindFirstChild(childName)
			if not entry or not entry:IsA("Configuration") then
				if entry then
					entry:Destroy()
				end
				local created = Instance.new("Configuration")
				created.Name = childName
				entry = created
			end

			local seed = HeroCatalog.Seeds[hero.TemplateId]
			local archetype = hero.Archetype or (seed and seed.Archetype) or "Vanguard"
			local rarity = hero.Rarity or HeroCatalog.RarityOf(hero.TemplateId)
			local artUUID = hero.EquippedArtifactUUID
			local artifact = if artUUID and artUUID ~= "" then artifacts[artUUID] else nil
			local artifactId = if artifact and type(artifact.TemplateId) == "string" then artifact.TemplateId else ""
			local artifactType = if artifact and type(artifact.Type) == "string"
				then artifact.Type
				else OutskirtsRules.DefaultWeaponForArchetype(archetype)
			local artifactRarity = if artifact and type(artifact.Rarity) == "number" then artifact.Rarity else 1

			setAttrIfChanged(entry, "Facility", facilityName)
			setAttrIfChanged(entry, "Slot", slotIndex)
			setAttrIfChanged(entry, "UUID", tostring(uuid))
			setAttrIfChanged(entry, "TemplateId", tostring(hero.TemplateId or "hero_han"))
			setAttrIfChanged(entry, "Archetype", tostring(archetype))
			setAttrIfChanged(entry, "Rarity", rarity)
			setAttrIfChanged(entry, "Stars", hero.Stars or 1)
			setAttrIfChanged(entry, "Level", hero.Level or 1)
			setAttrIfChanged(entry, "EquippedArtifactId", artifactId)
			setAttrIfChanged(entry, "EquippedArtifactType", artifactType)
			setAttrIfChanged(entry, "EquippedArtifactRarity", artifactRarity)
			setAttrIfChanged(entry, "ComaUntilTimestamp", hero.ComaUntilTimestamp or 0)
			if entry.Parent ~= workersContainer then
				entry.Parent = workersContainer
			end
		end
	end

	syncFacilityWorkers("GuardPost", guardPost and guardPost.AssignedHeroUUIDs)
	if (levels.Market or 0) > 0 and facilities.Market then
		syncFacilityWorkers("Market", facilities.Market.AssignedHeroUUIDs)
	end
	if (levels.TrainingGrounds or 0) > 0 and facilities.TrainingGrounds then
		syncFacilityWorkers("TrainingGrounds", facilities.TrainingGrounds.AssignedHeroUUIDs)
	end

	for _, child in ipairs(workersContainer:GetChildren()) do
		if not keepNames[child.Name] then
			child:Destroy()
		end
	end
	if plotModel:GetAttribute("OutskirtsSynced") ~= true then
		plotModel:SetAttribute("OutskirtsSynced", true)
	end
	if plotModel:GetAttribute("PlotWorkersSynced") ~= true then
		plotModel:SetAttribute("PlotWorkersSynced", true)
	end
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
		local targetCFrame = spawnLoc.CFrame * CFrame.new(0, 4, 0)
		char:PivotTo(targetCFrame)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		local TowerFloorService = require(script.Parent.TowerFloorService)
		TowerFloorService.ExitToOverworld(player, targetCFrame.Position, true)
	end
end

function PlotManager.TeleportPlayerToHub(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then
		return
	end

	local arrivalPart = workspace:FindFirstChild("HubArrival", true) :: BasePart?
	local basePos: Vector3
	if arrivalPart then
		basePos = arrivalPart.Position + Vector3.new(0, 3.4, 0)
	elseif (HubLayout :: any).HubArrival then
		basePos = (HubLayout :: any).HubArrival
	else
		basePos = Vector3.new(0, HubLayout.IslandSurfaceY + 3.8, -975)
	end

	-- Slight horizontal scatter across the 10-stud red runner so multiple players don't overlap
	local scatterIndex = (player.UserId % 5) - 2
	local spawnPos = Vector3.new(basePos.X + scatterIndex * 1.5, basePos.Y, basePos.Z)

	-- Look north towards the Wayfinder Dais & Statue plinth
	local lookTarget = Vector3.new(0, spawnPos.Y, HubLayout.ParkCentre.Z)
	local targetCFrame = CFrame.lookAt(spawnPos, lookTarget)

	char:PivotTo(targetCFrame)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	local TowerFloorService = require(script.Parent.TowerFloorService)
	TowerFloorService.ExitToOverworld(player, spawnPos, false)
end

function PlotManager.TeleportPlayerToTower(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then
		return
	end

	-- Prefer actual TowerHubArrival or EntrancePortalTrigger in workspace if available
	local arrivalPart = workspace:FindFirstChild("TowerHubArrival", true) :: BasePart?
	local portalTrigger = workspace:FindFirstChild("EntrancePortalTrigger", true) :: BasePart?

	local basePos: Vector3
	local lookTarget: Vector3

	if portalTrigger and arrivalPart then
		local gateZ = portalTrigger.Position.Z
		basePos = Vector3.new(portalTrigger.Position.X, arrivalPart.Position.Y + arrivalPart.Size.Y * 0.5, gateZ - 10)
		lookTarget = Vector3.new(portalTrigger.Position.X, basePos.Y, gateZ)
	elseif arrivalPart then
		basePos = Vector3.new(arrivalPart.Position.X, arrivalPart.Position.Y + arrivalPart.Size.Y * 0.5, arrivalPart.Position.Z - 15)
		lookTarget = Vector3.new(arrivalPart.Position.X, basePos.Y, arrivalPart.Position.Z)
	else
		basePos = Vector3.new(0, 16.2, -342)
		lookTarget = Vector3.new(0, 16.2, -332)
	end

	local angle = (player.UserId % 8) * (math.pi / 4)
	local scatter = Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 2)
	local spawnPos = basePos + scatter + Vector3.new(0, 3.5, 0)
	local targetCFrame = CFrame.lookAt(spawnPos, Vector3.new(lookTarget.X, spawnPos.Y, lookTarget.Z))

	char:PivotTo(targetCFrame)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	local TowerFloorService = require(script.Parent.TowerFloorService)
	TowerFloorService.ExitToOverworld(player, spawnPos, false)
end

if TeleportRequest then
	TeleportRequest.OnServerEvent:Connect(function(player: Player, destination: any)
		if destination ~= "Island" and destination ~= "Hub" and destination ~= "Tower" and destination ~= "TowerGate" then
			return
		end

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not hrp or not humanoid or humanoid.Health <= 0 then
			return
		end

		-- 1. Cooldown guard (1.5s per player to match HUD debounce)
		local now = os.clock()
		local last = LastTeleportAt[player] or 0
		if now - last < 1.5 then
			return
		end

		-- 2. Duel guard
		if _G.CombatSimulation and _G.CombatSimulation.IsInDuel and _G.CombatSimulation.IsInDuel(player) then
			local dm = getDataManager()
			if dm and dm.SendToast then
				dm.SendToast(player, "Cannot fast-travel during a duel!", "WARN")
			end
			return
		end

		-- 3. Boss lock guard (while inside the Tower)
		local TowerFloorService = require(script.Parent.TowerFloorService)
		local state = TowerFloorService.GetState(player)
		if state and state.FloorId and state.FloorId > 0 then
			if _G.CombatSimulation and _G.CombatSimulation.IsBossLocked and _G.CombatSimulation.IsBossLocked(player, state.FloorId) then
				local dm = getDataManager()
				if dm and dm.SendToast then
					dm.SendToast(player, "🔒 Travel is sealed until the boss falls.", "WARN")
				end
				return
			end
		end

		-- 4. Contested cargo guard: drop a carried relic prior to teleporting
		local carrying = char:GetAttribute("CarryingRelic") ~= nil
		if carrying then
			if _G.RelicService and _G.RelicService.DropCarriedRelic then
				_G.RelicService.DropCarriedRelic(player)
			end
			local dm = getDataManager()
			if dm and dm.SendToast then
				dm.SendToast(player, "Contested cargo dropped before fast travel.", "INFO")
			end
		end

		-- 5. Execute teleport
		LastTeleportAt[player] = now
		if destination == "Island" then
			PlotManager.TeleportPlayerToPlot(player)
			PlotManager.RefreshPlotVisuals(player)
		elseif destination == "Hub" then
			PlotManager.TeleportPlayerToHub(player)
		elseif destination == "Tower" or destination == "TowerGate" then
			PlotManager.TeleportPlayerToTower(player)
		end
	end)
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
	-- Nearest-to-the-gate first, so small servers cluster by the tower (HubLayout.AssignmentOrder)
	for _, i in HubLayout.AssignmentOrder do
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
	LastTeleportAt[player] = nil
	local idx = PlayerToPlotIndex[player]
	if idx then
		AssignedPlots[idx] = nil
		PlayerToPlotIndex[player] = nil
		local plotModel = PlotsFolder:FindFirstChild("Plot_" .. tostring(idx)) :: Model?
		if plotModel then
			plotModel:SetAttribute("OwnerUserId", 0)
			plotModel:SetAttribute("OwnerName", "Unclaimed")
			plotModel:SetAttribute("OutskirtsFloorId", nil)
			plotModel:SetAttribute("OutskirtsBiomeId", nil)
			plotModel:SetAttribute("GuardPostLevel", nil)
			plotModel:SetAttribute("OutskirtsSynced", false)
			plotModel:SetAttribute("PlotWorkersSynced", false)
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
