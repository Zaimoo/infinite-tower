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
local PlotQueue = require(Shared:WaitForChild("Util"):WaitForChild("PlotQueue"))

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

-- Players waiting for a plot when every plot is taken (FIFO). They stay behind the join loading
-- screen, which reads the replicated attributes below and shows "Server full" with their place.
--   PlotAssignState:   "PENDING" | "QUEUED" | "ASSIGNED"
--   PlotQueuePosition: 1-based place in the queue (0 once assigned)
--   PlotQueueTotal:    queue length
--   PlotTeleported:    true once the character stands on its plot (the loading screen reveals then)
local plotQueue = PlotQueue.new(
	HubLayout.AssignmentOrder,
	function(idx: number): boolean
		return PlotsFolder:FindFirstChild("Plot_" .. tostring(idx)) ~= nil
	end,
	function(player: Player): boolean
		return player.Parent == Players
	end
)

-- Every PlotSpawn is non-neutral, so without a neutral spawn Roblox drops a fresh character at the
-- world origin, which is inside the central tower (it lands in the crown, ~1,640 studs up). This
-- hidden neutral spawn on the Commons' south runner gives the engine a safe default instead.
local FALLBACK_SPAWN_NAME = "HubFallbackSpawn"
local function ensureFallbackSpawn(): SpawnLocation
	local existing = Workspace:FindFirstChild(FALLBACK_SPAWN_NAME)
	if existing and existing:IsA("SpawnLocation") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = FALLBACK_SPAWN_NAME
	spawnLoc.Size = Vector3.new(8, 1, 8)
	local arrival = HubLayout.HubArrival
	spawnLoc.CFrame = CFrame.new(arrival.X, HubLayout.IslandSurfaceY + 0.5, arrival.Z)
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = false
	spawnLoc.CanTouch = false
	spawnLoc.CanQuery = false
	spawnLoc.CastShadow = false
	spawnLoc.Transparency = 1
	spawnLoc.Neutral = true
	spawnLoc.Enabled = true
	spawnLoc.Duration = 0
	local decal = spawnLoc:FindFirstChildWhichIsA("Decal")
	if decal then
		decal:Destroy()
	end
	spawnLoc.Parent = Workspace
	return spawnLoc
end
ensureFallbackSpawn()

local function getDataManager(): any
	while not _G.DataManager do
		task.wait(0.05)
	end
	return _G.DataManager
end

function PlotManager.GetPlayerPlotModel(player: Player): Model?
	local idx = plotQueue.PlayerToPlot[player]
	if not idx then
		return nil
	end
	return PlotsFolder:FindFirstChild("Plot_" .. tostring(idx)) :: Model?
end

function PlotManager.GetPlayerPlotIndex(player: Player): number?
	return plotQueue.PlayerToPlot[player]
end

function PlotManager.GetPlotOwner(plotIndex: number): Player?
	return plotQueue.AssignedPlots[plotIndex]
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
			if plotQueue.PlayerToPlot[player] ~= targetPlot then
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

-- Studs a character may sit from its plot spawn before the placement counts as failed.
local PLACE_TOLERANCE = 40
-- Re-checks after a teleport: the engine's own spawn step can overwrite a PivotTo made the same
-- frame the character was added, which left fresh characters at the world origin (in the tower).
-- PlotTeleported is marked once the early checks settle, with one late safety re-check after.
local PLACE_EARLY_DELAYS = { 0.15, 0.4 }
local PLACE_LATE_DELAY = 1.0
local placeGeneration: { [Player]: number } = {}

local function plotTargetCFrame(player: Player, plotModel: Model): CFrame?
	local spawnLoc = plotModel:FindFirstChild("PlotSpawn") :: SpawnLocation?
	local targetCFrame = if spawnLoc
		then spawnLoc.CFrame * CFrame.new(0, 4, 0)
		else plotModel:GetPivot() * CFrame.new(0, 4, 0)
	-- A new Master (no summon yet) spawns facing their Summoning Altar, the guide's first step
	-- (plan A6).
	local dm = _G.DataManager
	local profile = dm and dm.GetProfile and dm.GetProfile(player)
	local guide = profile and profile.Onboarding and profile.Onboarding.Guide
	local altar = plotModel:FindFirstChild("Building_Summoning", true)
	if guide and guide.Enabled and not guide.Facts.Summon and altar and altar:IsA("Model") then
		local from = targetCFrame.Position
		local at = altar:GetPivot().Position
		local flat = Vector3.new(at.X, from.Y, at.Z)
		if (flat - from).Magnitude > 1 then targetCFrame = CFrame.lookAt(from, flat) end
	end
	return targetCFrame
end

-- Moves the character onto its plot now. Returns false when the character or its root part is not
-- there yet.
local function placeOnPlot(player: Player, plotModel: Model): (boolean, CFrame?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetCFrame = plotTargetCFrame(player, plotModel)
	if not (char and hrp and targetCFrame) then
		return false, nil
	end
	if hrp:GetAttribute("PlotQueueParked") then
		hrp:SetAttribute("PlotQueueParked", nil)
		hrp.Anchored = false
	end
	char:PivotTo(targetCFrame)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	return true, targetCFrame
end

function PlotManager.TeleportPlayerToPlot(player: Player)
	local plotModel = PlotManager.GetPlayerPlotModel(player)
	if not plotModel then
		return
	end
	placeGeneration[player] = (placeGeneration[player] or 0) + 1
	local generation = placeGeneration[player]
	local char = player.Character

	local placed, targetCFrame = placeOnPlot(player, plotModel)
	if placed and targetCFrame then
		local TowerFloorService = require(script.Parent.TowerFloorService)
		TowerFloorService.ExitToOverworld(player, targetCFrame.Position, true)
	end

	-- Retry until the root part exists, then verify the character stayed put.
	task.spawn(function()
		if not placed then
			local waitedChar = char or player.CharacterAdded:Wait()
			if waitedChar:WaitForChild("HumanoidRootPart", 10) == nil then
				return
			end
			if placeGeneration[player] ~= generation or player.Character ~= waitedChar then
				return
			end
			placed, targetCFrame = placeOnPlot(player, plotModel)
			if not (placed and targetCFrame) then
				return
			end
			local TowerFloorService = require(script.Parent.TowerFloorService)
			TowerFloorService.ExitToOverworld(player, targetCFrame.Position, true)
		end
		local target = (targetCFrame :: CFrame).Position
		local watchedChar = player.Character
		for _, seconds in PLACE_EARLY_DELAYS do
			task.wait(seconds)
			if placeGeneration[player] ~= generation or player.Character ~= watchedChar or player.Parent ~= Players then
				return
			end
			local hrp = watchedChar and watchedChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and (hrp.Position - target).Magnitude > PLACE_TOLERANCE then
				placeOnPlot(player, plotModel)
			end
		end
		if placeGeneration[player] == generation and player.Parent == Players then
			player:SetAttribute("PlotTeleported", true)
		end
		task.wait(PLACE_LATE_DELAY)
		if placeGeneration[player] ~= generation or player.Character ~= watchedChar or player.Parent ~= Players then
			return
		end
		local hrp = watchedChar and watchedChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and (hrp.Position - target).Magnitude > PLACE_TOLERANCE then
			placeOnPlot(player, plotModel)
		end
	end)
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
		-- Queued (server full) players wait behind the loading screen until they have a plot.
		if not plotQueue.PlayerToPlot[player] then
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
				dm.SendToast(player, "Can't travel|Finish the duel first", "WARN")
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
					dm.SendToast(player, "Travel sealed|Defeat the boss first", "WARN")
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
				dm.SendToast(player, "Dropped|Contested loot can't travel", "INFO")
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

-- Plot streaming. Nothing on a plot is Persistent except its small PlotBeaconAnchor, so clients stream
-- other players' plots in and out by distance.
--   * The island (walls, courtyard, outskirts) stays Default: its parts arrive a few at a time as a
--     player approaches. Making it one atomic unit sent ~2,800 instances in a single frame and hitched.
--   * The fountain, the statue and each building are Atomic: client effects bind to their children the
--     moment the model appears, so they must arrive whole. Each is a few hundred instances at most.
--   * The owner keeps their own plot loaded through a replication focus on the plot's anchor, which
--     streams the area around it for that player wherever their character is.
local NONATOMIC_PLOT_CHILDREN = { PlotBeaconAnchor = true, FloatingFortressIsland = true }

local function isAtomicPlotUnit(plotModel: Model, inst: Instance): boolean
	if not inst:IsA("Model") then
		return false
	end
	local parent = inst.Parent
	if parent == plotModel then
		return not NONATOMIC_PLOT_CHILDREN[inst.Name]
	end
	-- The buildings inside the PlotBuildings folder
	return parent ~= nil and parent:IsA("Folder") and parent.Parent == plotModel
end

local function applyPlotUnitStreaming(plotModel: Model, inst: Instance)
	if isAtomicPlotUnit(plotModel, inst) then
		(inst :: Model).ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

local function plotFocusPart(plotModel: Model): BasePart?
	local anchor = plotModel:FindFirstChild("PlotBeaconAnchor")
	local part = anchor and anchor:FindFirstChild("AnchorPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function setPlotReplicationFocus(plotModel: Model, owner: Player, focused: boolean)
	local part = plotFocusPart(plotModel)
	if not part then
		return
	end
	if focused then
		owner:AddReplicationFocus(part)
	else
		-- The player may already be leaving; a failed removal needs no handling.
		pcall(owner.RemoveReplicationFocus, owner, part)
	end
end

local function initializePlotModel(plotModel: Model)
	plotModel.ModelStreamingMode = Enum.ModelStreamingMode.Default
	local island = plotModel:FindFirstChild("FloatingFortressIsland")
	if island and island:IsA("Model") then
		island.ModelStreamingMode = Enum.ModelStreamingMode.Default
	end
	for _, child in plotModel:GetChildren() do
		applyPlotUnitStreaming(plotModel, child)
		if child:IsA("Folder") then
			for _, inner in child:GetChildren() do
				applyPlotUnitStreaming(plotModel, inner)
			end
		end
	end
	-- Buildings are rebuilt on facility upgrades: pick new units up as they arrive. Deferred so a
	-- builder that sets its own streaming mode after parenting does not win.
	plotModel.DescendantAdded:Connect(function(inst)
		if isAtomicPlotUnit(plotModel, inst) then
			task.defer(applyPlotUnitStreaming, plotModel, inst)
		end
	end)
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

	-- The fountain, walls and courtyard accents are placed by the island builder, possibly after the
	-- plot's facilities were applied: re-run presence so an unoccupied plot hides them again.
	plotModel.ChildAdded:Connect(function(child)
		if child.Name == "PlazaFountain" or child.Name == "FloatingFortressIsland" then
			task.defer(FacilityPresence.Reapply, plotModel)
		end
	end)
	local function watchIsland(island: Instance)
		island.ChildAdded:Connect(function(child)
			if child.Name == "FortressWalls" or child.Name == "CourtyardAccents" then
				task.defer(FacilityPresence.Reapply, plotModel)
			end
		end)
	end
	local currentIsland = plotModel:FindFirstChild("FloatingFortressIsland")
	if currentIsland then
		watchIsland(currentIsland)
	end
	plotModel.ChildAdded:Connect(function(child)
		if child.Name == "FloatingFortressIsland" then
			watchIsland(child)
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


local function setQueueAttributes(player: Player, state: string, position: number, total: number)
	player:SetAttribute("PlotAssignState", state)
	player:SetAttribute("PlotQueuePosition", position)
	player:SetAttribute("PlotQueueTotal", total)
end

-- Refreshes every queued player's place in line (1-based) and the queue length.
local function broadcastQueuePositions()
	for _, entry in plotQueue:QueueSnapshot() do
		setQueueAttributes(entry.Player, "QUEUED", entry.Position, entry.Total)
	end
end

-- A queued player's character waits, anchored, on the hub's south runner behind the loading screen.
local function parkQueuedCharacter(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hrp) then
		return
	end
	local arrival = HubLayout.HubArrival
	local scatter = ((player.UserId % 5) - 2) * 2
	char:PivotTo(CFrame.new(arrival.X + scatter, arrival.Y, arrival.Z))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.Anchored = true
	hrp:SetAttribute("PlotQueueParked", true)
end

-- Wires `player` onto plot `chosenIdx` and moves them onto it. Does not wait on DataManager:
-- the plot, respawn location and teleport happen at once; the profile bits follow when ready.
local function applyPlotClaim(player: Player, chosenIdx: number)
	setQueueAttributes(player, "ASSIGNED", 0, plotQueue:QueueLength())

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
		setPlotReplicationFocus(plotModel, player, true)
		-- An unoccupied plot stands empty: bring its buildings, fountain and walls back for the new owner
		FacilityPresence.Reapply(plotModel)
	end

	if player.Character then
		PlotManager.TeleportPlayerToPlot(player)
	end

	task.spawn(function()
		local dm = getDataManager()
		-- The profile may still be loading: wait for it (or for the player to leave / lose the plot).
		local profile = dm.GetProfile(player)
		local started = os.clock()
		while not profile and player.Parent == Players and plotQueue.PlayerToPlot[player] == chosenIdx and os.clock() - started < 60 do
			task.wait(0.2)
			profile = dm.GetProfile(player)
		end
		if plotQueue.PlayerToPlot[player] ~= chosenIdx then
			return
		end
		if profile then
			profile.PlotIndex = chosenIdx
			local guide = profile.Onboarding and profile.Onboarding.Guide
			local needsAltarFacing = guide ~= nil and guide.Enabled == true and not guide.Facts.Summon
			-- Re-face a brand-new Master toward their Summoning Altar now the guide state is known,
			-- or trigger placement if it hasn't run yet.
			if needsAltarFacing or (not placeGeneration[player] and player:GetAttribute("PlotTeleported") ~= true) then
				PlotManager.TeleportPlayerToPlot(player)
			end
		end
		PlotManager.RefreshPlotVisuals(player)
	end)
end

local function onCharacterAdded(player: Player, _char: Model)
	task.wait(0.25)
	if player.Parent ~= Players then
		return
	end
	if plotQueue.PlayerToPlot[player] then
		PlotManager.TeleportPlayerToPlot(player)
		task.spawn(PlotManager.RefreshPlotVisuals, player)
	elseif plotQueue:QueuePosition(player) then
		local char = player.Character
		if char then
			char:WaitForChild("HumanoidRootPart", 10)
		end
		if plotQueue:QueuePosition(player) then
			parkQueuedCharacter(player)
		end
	end
end

local function assignPlotToPlayer(player: Player)
	if plotQueue.PlayerToPlot[player] or plotQueue:QueuePosition(player) then
		return
	end
	player:SetAttribute("PlotTeleported", false)
	setQueueAttributes(player, "PENDING", 0, plotQueue:QueueLength())
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)

	local result = plotQueue:Join(player)
	if result.State == "ASSIGNED" and result.PlotIndex then
		applyPlotClaim(player, result.PlotIndex)
		return
	end

	-- Server full: wait in line behind the join loading screen.
	player.RespawnLocation = ensureFallbackSpawn()
	broadcastQueuePositions()
	warn(string.format("[PlotManager] All plots occupied: %s (%d) queued at #%d", player.Name, player.UserId, result.Position))
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

-- Hands freed plots to the front of the queue.
local function promoteQueue()
	for _, promotion in plotQueue:Promote() do
		applyPlotClaim(promotion.Player, promotion.PlotIndex)
	end
	broadcastQueuePositions()
end

function PlotManager.GetQueuePosition(player: Player): number?
	return plotQueue:QueuePosition(player)
end

function PlotManager.GetQueueLength(): number
	return plotQueue:QueueLength()
end

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(assignPlotToPlayer, p)
end
Players.PlayerAdded:Connect(assignPlotToPlayer)

Players.PlayerRemoving:Connect(function(player: Player)
	LastTeleportAt[player] = nil
	placeGeneration[player] = nil
	local idx, wasQueued = plotQueue:Release(player)
	if wasQueued then
		broadcastQueuePositions()
	end
	if idx then
		local plotModel = PlotsFolder:FindFirstChild("Plot_" .. tostring(idx)) :: Model?
		if plotModel then
			setPlotReplicationFocus(plotModel, player, false)
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
		-- The plot is free: the first player in line takes it (after the reset above).
		task.defer(promoteQueue)
	end
end)

-- Safety net: an overworld character inside the central tower's drum (above its gate porch) can
-- only have got there through a bad spawn. Send them home. Tower floors and the raid arena are
-- built far off-map, so they never match.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and not hrp.Anchored then
				local pos = hrp.Position
				if PlotQueue.IsInTowerCrownTrap(pos) then
					local ok, onOverworld = pcall(function()
						local tfs = require(script.Parent.TowerFloorService)
						local state = tfs.GetState(player)
						return state.FloorId == 0 and not tfs.IsTransitioning(player)
					end)
					local inDuel = _G.CombatSimulation and _G.CombatSimulation.IsInDuel and _G.CombatSimulation.IsInDuel(player)
					if ok and onOverworld and not inDuel then
						warn(string.format("[PlotManager] %s was inside the central tower at %s; returning them", player.Name, tostring(pos)))
						if plotQueue.PlayerToPlot[player] then
							PlotManager.TeleportPlayerToPlot(player)
						elseif plotQueue:QueuePosition(player) then
							parkQueuedCharacter(player)
						else
							PlotManager.TeleportPlayerToHub(player)
						end
					end
				end
			end
		end
	end
end)

_G.PlotManager = PlotManager

return PlotManager
