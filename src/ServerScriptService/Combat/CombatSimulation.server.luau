--!strict
-- ServerScriptService/Combat/CombatSimulation.server.luau
-- 5 Hz (0.20s) Server-Authoritative Combat, Ring 1/2 Mob Spawner & World Boss State Machine

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldBossConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldBossConfig"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local PitBalance = require(Shared:WaitForChild("Config"):WaitForChild("PitBalanceConfig"))
local ArtPackVisuals = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ArtPackVisuals"))
local HeroNavigation = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("HeroNavigation"))

local Tower=require(script.Parent.Parent.Core.TowerFloorService)
Tower.Init()
local Protocol=require(Shared.Util.TowerProtocol)
local FirstBiome=require(Shared.Config.FirstBiomeCombat)
local EncounterRuntime=require(script.Parent.TowerEncounterRuntime)
local AttackTimeline=require(Shared.Util.AttackTimeline)
local Encounters: any=nil
local CombatLifecycleRevision=0
local TowerRemotes=ReplicatedStorage.Remotes.TowerRemotes
local CombatRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatRemotes")
local ReplicationTickRemote = CombatRemotes:WaitForChild("ReplicationTick") :: UnreliableRemoteEvent
local FocusTargetRemote = CombatRemotes:WaitForChild("FocusTarget") :: RemoteEvent
local WhistleCommandRemote = CombatRemotes:WaitForChild("WhistleCommand") :: RemoteEvent
local BossTelegraphRemote = CombatRemotes:WaitForChild("BossTelegraph") :: RemoteEvent
local CombatVFXRemote = CombatRemotes:WaitForChild("CombatVFX") :: UnreliableRemoteEvent
local EntityMetadataRemote = CombatRemotes:WaitForChild("EntityMetadataSync") :: RemoteEvent
local WorldBossTriggerRemote = CombatRemotes:WaitForChild("WorldBossTrigger") :: RemoteEvent
local LootStolenAlertRemote = CombatRemotes:WaitForChild("LootStolenAlert") :: RemoteEvent
local SquadWipeStateRemote = CombatRemotes:WaitForChild("SquadWipeState") :: RemoteEvent
local CarriedLootSyncRemote = CombatRemotes:WaitForChild("CarriedLootSync") :: RemoteEvent
local PhysicalLootFolder = Workspace:WaitForChild("PhysicalLoot") :: Folder
local DropCarriedItemRemote = CombatRemotes:FindFirstChild("DropCarriedItem") :: RemoteEvent?
if not DropCarriedItemRemote then
	DropCarriedItemRemote = Instance.new("RemoteEvent")
	DropCarriedItemRemote.Name = "DropCarriedItem"
	DropCarriedItemRemote.Parent = CombatRemotes
end

local function getDataManager(): any
	while not _G.DataManager do
		task.wait(0.05)
	end
	return _G.DataManager
end

--============================================================================
-- 1. CONSTANTS & SIMULATION TYPES
--============================================================================

local TICK_INTERVAL = 0.20 -- 5 Hz Server Heartbeat
local MASTER_FORMATION_RADIUS = 6.0
local LEASH_DISTANCE = 65.0

local OVERDRIVE_COOLDOWN = 20.0
local OVERDRIVE_DURATION = 5.0
local OVERDRIVE_STAMINA_COST = 5.0
local OVERDRIVE_ATK_SPEED_MULT = 1.40

local RECALL_COOLDOWN = 6.0
local RECALL_PACIFY_DURATION = 2.0

local TowerSpawnLayout = require(ReplicatedStorage:WaitForChild("TowerSpawnLayout"))
local WORLD_BOSS_ORIGIN = TowerSpawnLayout.Boss()
local NOVA_INTERVAL = 20.0
local NOVA_TELEGRAPH_DURATION = 3.0
local NOVA_BLAST_RADIUS = 85.0
local NOVA_PUNISH_DURATION = 5.0
local NOVA_PUNISH_DAMAGE_MULT = 1.25
local COMA_DURATION_DEFAULT = 60

export type HeroSimState = "FOLLOW_MASTER" | "MOVE_TO_TARGET" | "ATTACKING" | "COMA"

export type SimHero = {
	NetId: number,
	FloorId: number,
	RoomGeneration: number,
	EntityGeneration: number,
	Owner: Player,
	HeroUUID: string,
	TemplateId: string,
	DisplayName: string,
	Stars: number,
	Level: number,
	State: HeroSimState,
	Position: Vector3,
	Yaw: number,
	CurrentHP: number,
	MaxHP: number,
	EffectiveATK: number,
	AttackRange: number,
	AttackInterval: number,
	MoveSpeed: number,
	Stamina: number,
	SlotIndex: number,
	TargetNetId: number?,
	AttackCooldown: number,
	PacifiedUntil: number,
	OverdriveUntil: number,
	EquippedArtifactId: string?,
	EquippedArtifactRarity: number?,
	EquippedArtifactType: string?,
	EquippedArtifactStar: number?,
}

export type SimMob = {
	NetId: number,
	FloorId: number,
	RoomGeneration: number,
	EntityGeneration: number,
	SpecId: string,
	DisplayName: string,
	MobType: "RING1_MOB" | "RING2_ELITE" | "RIFT_BOSS" | "WORLD_BOSS",
	RingIndex: number,
	Position: Vector3,
	HomePosition: Vector3,
	Yaw: number,
	CurrentHP: number,
	MaxHP: number,
	ATK: number,
	AttackInterval: number,
	AttackCooldown: number,
	IsAlive: boolean,
	RespawnAt: number,
	NextAoECastTime: number,
	AoEDetonateTime: number?,
	AoERadius: number,
	Phase: number,
	NextNovaCastTime: number,
	NovaDetonateTime: number?,
	PunishWindowUntil: number,
	DespawnAt: number?,
	DamageLedger: { [number]: number },
}

export type MasterCombatState = {
	FocusedTargetNetId: number?,
	TargetEnemyUserId: number?,
	LastOverdriveClock: number,
	LastRecallClock: number,
	DeployedHeroes: { [string]: SimHero },
	CarriedLoot: { Gold: number, Gems: number },
	CanCollectLoot: boolean,
	IsSquadWiped: boolean,
}

local TheftGrudges: { [number]: { [number]: number } } = {} -- [victimUserId][thiefUserId] = expiresAt
local NextLootId = 1
local ActiveLootDrops: { [number]: any } = {}
local CarrierToHeldLoot: { [Player]: any } = {}

local CombatSimulation = {}
local NextNetId = 1
local function allocateNetId(): number
	local id = NextNetId
	NextNetId += 1
	assert(NextNetId < 4294967295, "Entity ID space exhausted")
	return id
end

local ActiveMasters: { [Player]: MasterCombatState } = {}
local ActiveHeroesByNetId: { [number]: SimHero } = {}
local ActiveMobsByNetId: { [number]: SimMob } = {}
local ActiveWorldBoss: SimMob? = nil
-- Progression is awarded on a confirmed PvE death, outside the simulation's per-tick work.
-- Only recent, deliberate Master commands qualify; idle auto-attacks do not level a squad.
local ProgressionActivity: { [Player]: number } = {}
local ProgressionHits: { [number]: { [number]: { Damage: number, At: number } } } = {}
local ProgressionAwards: { [number]: number } = {}
local NextWorldBossSpawnClock = os.clock() + 180 -- First automatic World Boss in 3m for prototype pacing (or instant via button!)

--============================================================================
-- 2. METADATA BROADCAST & HELPER FUNCTIONS
--============================================================================

local function buildMetadataTable(): { any }
	-- Send a dense list so despawned IDs cannot create holes in the remote payload.
	local meta: { any } = {}
	for netId, h in pairs(ActiveHeroesByNetId) do
		table.insert(meta, {
			NetId = netId,
			FloorId = 0, RoomGeneration = 1, EntityGeneration = 1,
			IsHero = true,
			OwnerUserId = h.Owner.UserId,
			OwnerName = h.Owner.DisplayName,
			HeroUUID = h.HeroUUID,
			TemplateId = h.TemplateId,
			Name = h.DisplayName,
			Stars = h.Stars,
			Level = h.Level,
			SlotIndex = h.SlotIndex,
			MaxHP = h.MaxHP,
			EquippedArtifactId = h.EquippedArtifactId,
			EquippedArtifactRarity = h.EquippedArtifactRarity,
			EquippedArtifactType = h.EquippedArtifactType,
			EquippedArtifactStar = h.EquippedArtifactStar,
		})
	end
	for netId, m in pairs(ActiveMobsByNetId) do
		if m.IsAlive then
			table.insert(meta, {
				NetId = netId,
			FloorId = 0, RoomGeneration = 1, EntityGeneration = 1,
				IsHero = false,
				SpecId = m.SpecId,
				EnemyId = (m :: any).EnemyId,
				TowerEnemy = (m :: any).TowerEnemy,
				Role = (m :: any).Role,
				BornAt = (m :: any).BornAt,
				MobType = m.MobType,
				Name = m.DisplayName,
				RingIndex = m.RingIndex,
				GroundY = m.HomePosition.Y,
				MaxHP = m.MaxHP,
				Phase = m.Phase,
			})
		end
	end
	return meta
end

local BootstrapRevision=0
local SnapshotSequence=0
local function sendBootstrap(player: Player)
 local context=Tower.Context(player)
 local metadata={}
 for _,entry in buildMetadataTable() do
  local e=ActiveHeroesByNetId[entry.NetId] or ActiveMobsByNetId[entry.NetId]
  if e and Tower.Same(e,context) then
   entry.FloorId=e.FloorId;entry.RoomGeneration=e.RoomGeneration;entry.EntityGeneration=e.EntityGeneration;table.insert(metadata,entry)
  end
 end
 BootstrapRevision+=1
 local count=math.max(1,math.ceil(#metadata/32))
 for i=1,count do
  local chunk={};for j=(i-1)*32+1,math.min(i*32,#metadata) do table.insert(chunk,metadata[j]) end
  TowerRemotes.TowerEntityState:FireClient(player,context,{Kind="BOOTSTRAP",BootstrapRevision=BootstrapRevision,LifecycleRevision=CombatLifecycleRevision,SnapshotSequence=SnapshotSequence,BatchIndex=i,BatchCount=count,Entities=chunk,
   Actions=i==1 and Encounters and Encounters:ActiveActions(context) or {},BossPresentation=Encounters and Encounters:BossPresentation(context) or {Enabled=false}})
 end
 TowerRemotes.TowerEntityState:FireClient(player,context,{Kind="COMPLETE",BootstrapRevision=BootstrapRevision,LifecycleRevision=CombatLifecycleRevision})
end
local function bootstrapAll() for _,p in Players:GetPlayers() do sendBootstrap(p) end end
local function broadcastMetadata(targetPlayer: Player?)
	if targetPlayer then sendBootstrap(targetPlayer) else bootstrapAll() end
end

local LastMetadataRequestByPlayer: { [Player]: number } = {}
EntityMetadataRemote.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	local lastRequest = LastMetadataRequestByPlayer[player]
	if lastRequest and now - lastRequest < 0.5 then
		return
	end
	LastMetadataRequestByPlayer[player] = now
	local context=Tower.Context(player);context.Stage="COMMIT";context.RequestId="ENTITY_RESYNC"
	TowerRemotes.Context:FireClient(player,context)
	broadcastMetadata(player)
end)

local function getHorizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getGroundHeightForRadius(r: number): number
	if r <= 122 then
		return 16.0
	elseif r <= 282 then
		return 4.0
	elseif r <= 462 then
		return 2.0
	end
	return 12.0
end

local function getZoneStaminaDrainPerSec(pos: Vector3): number
	local r = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	if r <= 122 then
		return 1.50 -- Ring 3
	elseif r <= 282 then
		return 1.20 -- Ring 2
	elseif r <= 462 then
		return 0.80 -- Ring 1
	end
	return 0.0 -- Safe Zone / Waiting Room Plot
end

local function getFormationOffset(slotIndex: number): Vector3
	local angle = ((slotIndex - 1) / 5) * (math.pi * 2)
	return Vector3.new(
		math.cos(angle) * MASTER_FORMATION_RADIUS,
		0,
		math.sin(angle) * MASTER_FORMATION_RADIUS
	)
end

local function getMasterRootPosition(player: Player): Vector3?
	local char = player.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and hrp.Position or nil
end

-- Refresh progression without rebuilding entities, resetting cooldowns, or healing.
-- Facility output reads StatFormulas from profile data on its existing 1 Hz loop.
function CombatSimulation.RefreshPlayerHeroStats(player: Player)
	local state = ActiveMasters[player]
	local profile = getDataManager().GetProfile(player)
	if not state or not profile then return end
	local metadataChanged = false
	for uuid, simHero in pairs(state.DeployedHeroes) do
		local hero = profile.Heroes[uuid]
		if hero then
			local trainingMult = getDataManager().GetTrainingMultiplier and getDataManager().GetTrainingMultiplier(player) or 1.0
			local atk, hp, _, interval = StatFormulas.GetEffectiveCombatStats(hero, false, false, StatFormulas.GetEquippedArtifact(profile,hero), trainingMult)
			metadataChanged = metadataChanged or simHero.Level ~= hero.Level or simHero.Stars ~= hero.Stars or simHero.MaxHP ~= hp
			simHero.Level, simHero.Stars = hero.Level, hero.Stars
			simHero.EffectiveATK, simHero.MaxHP, simHero.AttackInterval = atk, hp, interval
			simHero.CurrentHP = math.min(simHero.CurrentHP, hp)
		end
	end
	if metadataChanged then broadcastMetadata(nil) end
end

--============================================================================
-- 3. SQUAD MANAGEMENT & COMA RECALL
--============================================================================

function CombatSimulation.RebuildPlayerSquad(player: Player)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if not profile then
		return
	end

	local masterState = ActiveMasters[player]
	if not masterState then
		masterState = {
			FocusedTargetNetId = nil,
			LastOverdriveClock = -99,
			LastRecallClock = -99,
			DeployedHeroes = {},
			CarriedLoot = { Gold = 0, Gems = 0 },
			CanCollectLoot = true,
			IsSquadWiped = false,
		}
		ActiveMasters[player] = masterState
	end

	local towerState=Tower.GetState(player)
 local room=Tower.GetRoom(towerState.SquadFloorId) or Tower.GetRoom(0)
 local masterPos=towerState.SquadAssignment and (room.Origin+FirstBiome.AnchorLocal+Vector3.new(0,3,0)) or getMasterRootPosition(player) or room.Arrival.Position
		local desiredUUIDs: { [string]: number } = {}

	for slot = 1, 5 do
		local slotTag = "SQUAD_SLOT_" .. tostring(slot)
		for uuid, heroData in pairs(profile.Heroes) do
			if heroData.Assignment == slotTag and (heroData.ComaUntilTimestamp or 0) <= os.time() then
				desiredUUIDs[uuid] = slot
				break
			end
		end
	end

	local rosterChanged=false
	-- Remove heroes no longer deployed
	for uuid, simHero in pairs(masterState.DeployedHeroes) do
		if not desiredUUIDs[uuid] then
			rosterChanged=true
			HeroNavigation.Clear(simHero)
			ProgressionAwards[simHero.NetId] = nil
			ActiveHeroesByNetId[simHero.NetId] = nil
			masterState.DeployedHeroes[uuid] = nil
		end
	end

	-- Add or update deployed heroes
	for uuid, slotIndex in pairs(desiredUUIDs) do
		local heroData = profile.Heroes[uuid]
		local artifact = heroData.EquippedArtifactUUID and profile.Artifacts and profile.Artifacts[heroData.EquippedArtifactUUID]
		local trainingMult = dm.GetTrainingMultiplier and dm.GetTrainingMultiplier(player) or 1.0
		local effATK, effHP, _, effInterval = StatFormulas.GetEffectiveCombatStats(heroData, false, false, artifact, trainingMult)
		local existing = masterState.DeployedHeroes[uuid]
		if existing then
			rosterChanged=rosterChanged or existing.SlotIndex~=slotIndex
			existing.Stars = heroData.Stars
			existing.Level = heroData.Level
			existing.EffectiveATK = effATK
			existing.MaxHP = effHP
			existing.CurrentHP = math.min(existing.CurrentHP, effHP)
			existing.Stamina = heroData.CurrentStamina
			existing.SlotIndex = slotIndex
			existing.AttackInterval = effInterval
			existing.EquippedArtifactId = artifact and artifact.TemplateId
			existing.EquippedArtifactRarity = artifact and artifact.Rarity
			existing.EquippedArtifactType = artifact and artifact.Type
			existing.EquippedArtifactStar = artifact and artifact.Star
		else
			local netId = allocateNetId()
			rosterChanged=true
			local spawnPos = HeroNavigation.PlaceNear(masterPos, getFormationOffset(slotIndex))
			local newSim: SimHero = {
				NetId = netId,
			FloorId = 0, RoomGeneration = 1, EntityGeneration = 1,
				Owner = player,
				HeroUUID = uuid,
				TemplateId = heroData.TemplateId,
				DisplayName = heroData.DisplayName,
				Stars = heroData.Stars,
				Level = heroData.Level,
				State = "FOLLOW_MASTER",
				Position = spawnPos,
				Yaw = 0,
				CurrentHP = effHP,
				MaxHP = effHP,
				EffectiveATK = effATK,
				AttackRange = heroData.AttackRange or 6,
				AttackInterval = effInterval,
				MoveSpeed = 20.0,
				Stamina = heroData.CurrentStamina or 100.0,
				SlotIndex = slotIndex,
				TargetNetId = masterState.FocusedTargetNetId,
				AttackCooldown = 0.2,
				PacifiedUntil = 0,
				OverdriveUntil = 0,
				EquippedArtifactId = artifact and artifact.TemplateId,
				EquippedArtifactRarity = artifact and artifact.Rarity,
				EquippedArtifactType = artifact and artifact.Type,
				EquippedArtifactStar = artifact and artifact.Star,
			}
			newSim.FloorId=towerState.SquadFloorId;newSim.RoomGeneration=towerState.SquadRoomGeneration
			masterState.DeployedHeroes[uuid] = newSim
			ActiveHeroesByNetId[netId] = newSim
		end
	end

	if masterState.IsSquadWiped then
		local hasAliveHero = false
		for _, h in pairs(masterState.DeployedHeroes) do
			if h.State ~= "COMA" and h.CurrentHP > 0 then
				hasAliveHero = true
				break
			end
		end
		if hasAliveHero then
			masterState.IsSquadWiped = false
			masterState.CanCollectLoot = true
			if player.Character then
				player.Character:SetAttribute("SquadWiped", false)
			end
			SquadWipeStateRemote:FireClient(player, false)
			dm.SendToast(player, "🛡️ Squad operational! Field looting re-enabled.", "SUCCESS")
		end
	end

 local size=0;for _ in pairs(masterState.DeployedHeroes) do size+=1 end
 if rosterChanged or Tower.GetState(player).SquadSize~=size then Tower.RosterChanged(player,size) end
 broadcastMetadata(nil)
end

local collectPhysicalLoot: (player: Player, lootId: number) -> ()
local spawnPhysicalLoot: (lootType: "GOLD" | "GEMS", amount: number, worldPos: Vector3, killerPlayer: Player?, customLabel: string?) -> any

local function clearLootCarryState(player: Player)
	local char = player.Character
	if char then
		char:SetAttribute("CarryingLoot", false)
		char:SetAttribute("CarryingLootType", nil)
		char:SetAttribute("CarryingLootAmount", nil)
		char:SetAttribute("CarryingLootName", nil)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 16.0 end
	end
	CarrierToHeldLoot[player] = nil
	CarriedLootSyncRemote:FireClient(player, 0, 0)
end

function CombatSimulation.DropCarriedLoot(player: Player, openLoot: boolean?): boolean
	if Tower.IsTransitioning(player) then Tower.CancelPending(player,"CARGO_CHANGED") end
	local held = CarrierToHeldLoot[player]
	if not held then return false end
	if held.Weld then held.Weld:Destroy() end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local part = held.Part
	clearLootCarryState(player)
	if not part or not part.Parent then return true end

	local position = root and (root.Position + root.CFrame.LookVector * 8) or part.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char or part, PhysicalLootFolder, Workspace.PhysicalRelics}
	local ground = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -64, 0), params)
	part.Anchored = true
	part.Position = Tower.GroundDrop(held, position, part.Size.Y/2)
	part.Parent = PhysicalLootFolder

	local now = os.clock()
	local dropped = {
		LootId = held.LootId, LootType = held.LootType, Amount = held.Amount,
		FloorId=held.FloorId,RoomGeneration=held.RoomGeneration,
		Part = part, Prompt = held.OriginalPrompt, Billboard = held.Billboard,
		KillerUserId = openLoot and 0 or held.KillerUserId,
		KillerName = openLoot and "Open" or held.KillerName,
		SpawnTime = held.SpawnTime, DespawnTime = held.DespawnTime,
		PickupBlockedUserId = player.UserId, PickupBlockedUntil = now + 1.5,
	}
	ActiveLootDrops[held.LootId] = dropped
	if held.OriginalPrompt then
		held.OriginalPrompt.ActionText = "Hold / Carry"
		held.OriginalPrompt.Enabled = true
	end
	task.delay(math.max(0,held.DespawnTime-os.clock()), function()
		if ActiveLootDrops[held.LootId] == dropped then
			ActiveLootDrops[held.LootId] = nil
			part:Destroy()
		end
	end)
	return true
end

DropCarriedItemRemote.OnServerEvent:Connect(function(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local dropped = CombatSimulation.DropCarriedLoot(player)
	if _G.RelicService and _G.RelicService.DropCarriedRelic then
		dropped = _G.RelicService.DropCarriedRelic(player) or dropped
	end
	if dropped then
		getDataManager().SendToast(player, "Dropped carried item. You can pick it up again.", "INFO")
	end
end)

local function knockHeroIntoComa(simHero: SimHero, baseComaSeconds: number)
	HeroNavigation.Clear(simHero)
	local dm = getDataManager()
	local profile = dm.GetProfile(simHero.Owner)
	local effectiveComa = baseComaSeconds

	if profile then
		local inf = profile.Facilities.Infirmary
		local sumLabor = 0
		for _, wUUID in ipairs(inf.AssignedHeroUUIDs) do
			local wHero = profile.Heroes[wUUID]
			if wHero then
				sumLabor += StatFormulas.GetEffectiveLabor(wHero, "FACILITY_INFIRMARY")
			end
		end
		local _, reducedComa = StatFormulas.GetInfirmaryRates(inf.Level, sumLabor)
		effectiveComa = math.round(reducedComa)

		local heroInstance = profile.Heroes[simHero.HeroUUID]
		if heroInstance then
			heroInstance.CurrentStamina = 0
			heroInstance.ComaUntilTimestamp = os.time() + effectiveComa
			heroInstance.Assignment = "FACILITY_INFIRMARY"
		end
	end

	ProgressionAwards[simHero.NetId] = nil
	ActiveHeroesByNetId[simHero.NetId] = nil
	Tower.RosterChanged(simHero.Owner,math.max(0,Tower.GetState(simHero.Owner).SquadSize-1))
	local masterState = ActiveMasters[simHero.Owner]
	if masterState then
		masterState.DeployedHeroes[simHero.HeroUUID] = nil
	end

	dm.SendToast(
		simHero.Owner,
		string.format("🚑 %s entered a %ds COMA and was warped to your Infirmary!", simHero.DisplayName, effectiveComa),
		"WARN"
	)
	dm.SyncProfile(simHero.Owner)

	-- Squad Wipe Detection: Check if ALL deployed heroes are now in Coma
	local hasAliveHero = false
	if masterState then
		for _, h in pairs(masterState.DeployedHeroes) do
			if h.State ~= "COMA" and h.CurrentHP > 0 then
				hasAliveHero = true
				break
			end
		end
	end

	if not hasAliveHero and masterState and not masterState.IsSquadWiped then
		masterState.CanCollectLoot = false
		masterState.IsSquadWiped = true
		if simHero.Owner.Character then
			simHero.Owner.Character:SetAttribute("SquadWiped", true)
		end

		CombatSimulation.DropCarriedLoot(simHero.Owner, true)

		if _G.RelicService then
			_G.RelicService.FumbleRelicOnAoEHit(simHero.Owner)
		end

		masterState.CarriedLoot = { Gold = 0, Gems = 0 }
		CarriedLootSyncRemote:FireClient(simHero.Owner, 0, 0)
		SquadWipeStateRemote:FireClient(simHero.Owner, true)

		dm.SendToast(
			simHero.Owner,
			"💀 ALL HEROES FALLEN! All carried loot dropped! Return to your Waiting Room to recover your squad.",
			"WARN"
		)
	end

	broadcastMetadata(nil)
end

--============================================================================
-- 4. RING 1 / RING 2 MOB SPAWNER & WORLD BOSS DIRECTOR
--============================================================================

local function createSimMob(specId: string, pos: Vector3, mobType: "RING1_MOB" | "RING2_ELITE" | "RIFT_BOSS" | "WORLD_BOSS"): SimMob
	local spec = (WorldBossConfig.MobSpecs :: any)[specId]
	local netId = allocateNetId()
	local now = os.clock()
	local mob: SimMob = {
		NetId = netId,
			FloorId = 0, RoomGeneration = 1, EntityGeneration = 1,
		SpecId = specId,
		DisplayName = spec and spec.Name or "Dimensional Entity",
		MobType = mobType,
		RingIndex = spec and spec.Ring or 1,
		Position = pos,
		HomePosition = pos,
		Yaw = math.random() * math.pi * 2,
		CurrentHP = spec and spec.MaxHP or 1000,
		MaxHP = spec and spec.MaxHP or 1000,
		ATK = spec and spec.ATK or 25,
		AttackInterval = spec and spec.AttackInterval or 1.5,
		AttackCooldown = 1.0,
		IsAlive = true,
		RespawnAt = 0,
		NextAoECastTime = (spec and spec.AoECooldown and spec.AoECooldown > 0) and (now + math.random(4, 10)) or 0,
		AoEDetonateTime = nil,
		AoERadius = spec and spec.AoERadius or 0,
		Phase = 1,
		NextNovaCastTime = now + NOVA_INTERVAL,
		NovaDetonateTime = nil,
		PunishWindowUntil = 0,
		DespawnAt = nil,
		DamageLedger = {},
	}
	ActiveMobsByNetId[netId] = mob
	return mob
end

local function populateArenaMobs()
	local towerSpawnSlot = 0
	-- Ring 1: Outer Ruins (R = 295..445, Y = 2)
	local ring1List = {
		{ Id = "mob_mana_node", Count = 12, RMin = 305, RMax = 435 },
		{ Id = "mob_ruin_crawler", Count = 14, RMin = 300, RMax = 440 },
		{ Id = "mob_stone_sentinel", Count = 8, RMin = 295, RMax = 380 },
	}
	for _, group in ipairs(ring1List) do
		for i = 1, group.Count do
			local angle = ((i - 1) / group.Count) * (math.pi * 2) + (math.random() * 0.25)
			local r = group.RMin + math.random() * (group.RMax - group.RMin)
			towerSpawnSlot += 1
			local pos = TowerSpawnLayout.Regular(towerSpawnSlot)
			createSimMob(group.Id, pos, "RING1_MOB")
		end
	end

	-- Ring 2: Corrupted Grove (R = 135..265, Y = 4)
	local ring2List = {
		{ Id = "elite_corrupted_stalker", Count = 8, RMin = 155, RMax = 260 },
		{ Id = "elite_blighted_treant", Count = 6, RMin = 145, RMax = 240 },
		{ Id = "elite_abyssal_exec", Count = 4, RMin = 135, RMax = 165 },
	}
	for _, group in ipairs(ring2List) do
		for i = 1, group.Count do
			local angle = ((i - 1) / group.Count) * (math.pi * 2) + 0.3
			local r = group.RMin + math.random() * (group.RMax - group.RMin)
			towerSpawnSlot += 1
			local pos = TowerSpawnLayout.Regular(towerSpawnSlot)
			createSimMob(group.Id, pos, "RING2_ELITE")
		end
	end
end

function CombatSimulation.SpawnWorldBoss()
	if true then return end -- Part 2: legacy/new encounters disabled.
	if ActiveWorldBoss and ActiveWorldBoss.IsAlive then
		return
	end
	local dm = getDataManager()

	-- Dynamic HP Scaling Formula (Document 1 Section 5.1)
	local sumTop5DPS = 0
	local nPlayers = math.max(1, #Players:GetPlayers())
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = dm.GetProfile(p)
		if prof then
			local dpsList = {}
			for _, h in pairs(prof.Heroes) do
				local _, _, dps = StatFormulas.GetEffectiveCombatStats(h, false, false, StatFormulas.GetEquippedArtifact(prof,h))
				table.insert(dpsList, dps)
			end
			table.sort(dpsList, function(a, b) return a > b end)
			for i = 1, math.min(5, #dpsList) do
				sumTop5DPS += dpsList[i]
			end
		end
	end

	local dynamicMaxHP = math.max(75000, math.round(sumTop5DPS * 165 * (nPlayers ^ -0.15)))
	local now = os.clock()
	local netId = allocateNetId()

	local boss: SimMob = {
		NetId = netId,
			FloorId = 0, RoomGeneration = 1, EntityGeneration = 1,
		SpecId = "world_boss_sovereign",
		DisplayName = "THE DIMENSIONAL SOVEREIGN",
		MobType = "WORLD_BOSS",
		RingIndex = 3,
		Position = WORLD_BOSS_ORIGIN,
		HomePosition = WORLD_BOSS_ORIGIN,
		Yaw = 0,
		CurrentHP = dynamicMaxHP,
		MaxHP = dynamicMaxHP,
		ATK = 420,
		AttackInterval = 1.20,
		AttackCooldown = 1.20,
		IsAlive = true,
		RespawnAt = 0,
		NextAoECastTime = 0,
		AoEDetonateTime = nil,
		AoERadius = NOVA_BLAST_RADIUS,
		Phase = 1,
		NextNovaCastTime = now + 12.0, -- First Devouring Nova 12s after pull, then every 20.0s!
		NovaDetonateTime = nil,
		PunishWindowUntil = 0,
		DespawnAt = now + 300.0, -- 5-minute Despawn Timer
		DamageLedger = {},
	}

	ActiveMobsByNetId[netId] = boss
	ActiveWorldBoss = boss
	NextWorldBossSpawnClock = now + 1200.0

	dm.BroadcastToast(
		string.format("🔥 THE DIMENSIONAL SOVEREIGN HAS MANIFESTED AT RING 3 (HP: %d)! Watch for Devouring Nova every 20s!", dynamicMaxHP),
		"WARN"
	)
	broadcastMetadata(nil)
end

function CombatSimulation.SpawnRiftWarden(summoner: Player)
	if true then return end -- Do not consume lures until Part 3.
	local dm = getDataManager()
	local profile = dm.GetProfile(summoner)
	if not profile then
		return
	end
	if profile.RiftLuresOwned <= 0 then
		dm.SendToast(summoner, "You need a Rift Lure to summon The Rift Warden!", "WARN")
		return
	end
	profile.RiftLuresOwned -= 1
	dm.SyncProfile(summoner)

	local warden = createSimMob("boss_rift_warden", WORLD_BOSS_ORIGIN + Vector3.new(0, 0, 22), "RIFT_BOSS")
	dm.BroadcastToast(string.format("🌀 %s used a Rift Lure at Ring 3 to summon THE RIFT WARDEN!", summoner.DisplayName), "WARN")
	broadcastMetadata(nil)
end

-- WorldBossTrigger Remote (Allows HUD button to trigger World Boss for instant prototype testing)
WorldBossTriggerRemote.OnServerEvent:Connect(function(player: Player, mode: any)
	if mode == "SPAWN_WORLD_BOSS" then
		CombatSimulation.SpawnWorldBoss()
	elseif mode == "TRIGGER_NOVA_NOW" and ActiveWorldBoss and ActiveWorldBoss.IsAlive then
		ActiveWorldBoss.NextNovaCastTime = os.clock()
	elseif mode == "USE_RIFT_LURE" then
		CombatSimulation.SpawnRiftWarden(player)
	end
end)

-- The legacy altar is optional in the isolated-floor map and must not block combat startup.
local arenaRings = Workspace:FindFirstChild("ArenaRings")
local ring3 = arenaRings and arenaRings:FindFirstChild("Ring3_CenterBossAltar")
local obelisk = ring3 and ring3:FindFirstChild("RiftLureObelisk")
local lurePrompt = obelisk and obelisk:FindFirstChild("RiftLurePrompt") :: ProximityPrompt?
if lurePrompt then
	lurePrompt.Triggered:Connect(function(player: Player)
		CombatSimulation.SpawnRiftWarden(player)
	end)
end

--============================================================================
--============================================================================
-- PHYSICAL CONTESTED LOOT SYSTEM (3D MESH ASSETS & OVERHEAD HOLDING)
--============================================================================

function collectPhysicalLoot(player: Player, lootId: number)
	if Tower.IsTransitioning(player) then return end
	local loot = ActiveLootDrops[lootId]
	if not loot or not loot.Part or not loot.Part.Parent then
		return
	end

	if not Tower.Same(Tower.GetState(player),loot) or os.clock()>=loot.DespawnTime then return end
	if loot.PickupBlockedUserId == player.UserId and os.clock() < (loot.PickupBlockedUntil or 0) then
		return
	end

	local masterState = ActiveMasters[player]
	if not masterState then
		return
	end

	local dm = getDataManager()

	-- 1. Check Squad Wipe / Looting Lockout
	if not masterState.CanCollectLoot or (player.Character and player.Character:GetAttribute("SquadWiped") == true) then
		dm.SendToast(player, "🚫 SQUAD DOWN! You cannot collect loot until you recover your squad at your Waiting Room!", "WARN")
		return
	end

	-- 2. Check if player is already holding loot
	if CarrierToHeldLoot[player] ~= nil or (player.Character and (player.Character:GetAttribute("CarryingLoot") == true or player.Character:GetAttribute("CarryingRelic") ~= nil)) then
		dm.SendToast(player, "⚠️ You are already carrying loot! Drop it with [R] or bank it at the Perimeter Highway or Plot first.", "WARN")
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp or hum.Health <= 0 then
		return
	end
	if (hrp.Position - loot.Part.Position).Magnitude > 12 then return end

	ActiveLootDrops[lootId] = nil
	local part = loot.Part
	local lootType = loot.LootType
	local amount = loot.Amount
	local killerUserId = loot.KillerUserId
	local killerName = loot.KillerName

	if loot.Prompt then
		loot.Prompt.Enabled = false
	end

	-- Physically Weld Overhead with Holding Pose
	part.Anchored = false
	part.CFrame = hrp.CFrame * CFrame.new(0, 4.6, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = part
	weld.Parent = part

	-- Set Character Attributes to trigger Holding Animation & HUD banner
	char:SetAttribute("CarryingLoot", true)
	char:SetAttribute("CarryingLootType", lootType)
	char:SetAttribute("CarryingLootAmount", amount)
	char:SetAttribute("CarryingLootName", string.format("%d %s", amount, lootType))

	-- Movement penalty: -15% WalkSpeed while hauling cargo
	hum.WalkSpeed = 16.0 * 0.85

	CarrierToHeldLoot[player] = {
		LootId = lootId,
		FloorId=loot.FloorId,RoomGeneration=loot.RoomGeneration,SpawnTime=loot.SpawnTime,DespawnTime=loot.DespawnTime,
		Part = part,
		Weld = weld,
		LootType = lootType,
		Amount = amount,
		KillerUserId = killerUserId,
		KillerName = killerName,
		OriginalPrompt = loot.Prompt,
		Billboard = loot.Billboard,
	}

	local g = (lootType == "GOLD" and amount or 0)
	local gm = (lootType == "GEMS" and amount or 0)
	CarriedLootSyncRemote:FireClient(player, g, gm)

	Tower.BroadcastAt(CombatVFXRemote,Tower.GetState(player),"LOOT_PICKUP",hrp.Position)

	local isStolen = (killerUserId ~= 0 and killerUserId ~= player.UserId)
	if not isStolen then
		dm.SendToast(player, string.format("🎒 Holding %d %s (-15%% Spd)! Haul it to the Perimeter Highway to bank!", amount, lootType), "INFO")
	else
		TheftGrudges[killerUserId] = TheftGrudges[killerUserId] or {}
		TheftGrudges[killerUserId][player.UserId] = os.clock() + 180

		char:SetAttribute("IsLootThief", true)

		local victimPlayer = Players:GetPlayerByUserId(killerUserId)
		if victimPlayer then
			dm.SendToast(victimPlayer, string.format("🚨 %s STOLE YOUR %d %s! Click them to retaliate!", player.DisplayName, amount, lootType), "WARN")
			LootStolenAlertRemote:FireClient(victimPlayer, player.UserId, player.DisplayName, lootType, amount)
		end

		dm.SendToast(player, string.format("⚠️ You stole %s's loot! Their squad can now attack you in retaliation!", killerName), "WARN")
	end
end

function spawnPhysicalLoot(lootType: "GOLD" | "GEMS", amount: number, worldPos: Vector3, killerPlayer: Player?, customLabel: string?): any
	local lootId = NextLootId
	NextLootId += 1

	local part: BasePart? = nil
	local color = Color3.fromRGB(255, 205, 45)
	local icon = "💰"

	if lootType == "GOLD" then
		part = ArtPackVisuals.Mesh("prop_bounty_bag")
		if part then
			part.Size = Vector3.new(2.4, 2.8, 1.8)
		end
		color = Color3.fromRGB(255, 205, 45)
		icon = "💰"
	elseif lootType == "GEMS" then
		part = ArtPackVisuals.Mesh("prop_rift_tether_crystal")
		if part then
			part.Size = Vector3.new(2.4, 3.4, 2.4)
		end
		color = Color3.fromRGB(0, 230, 255)
		icon = "💎"
	end

	if not part then
		part = Instance.new("Part")
		part.Size = Vector3.new(2.2, 2.2, 2.2)
		part.Color = color
	end

	part.Name = string.format("Loot_%s_%d", lootType, lootId)
	part.CanCollide = false
	part.Anchored = true
	part.Position = Vector3.new(worldPos.X, math.max(2.5, worldPos.Y + 1.2), worldPos.Z)

	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0.1
	highlight.Parent = part

	local bb = Instance.new("BillboardGui")
	bb.Name = "LootBillboard"
	bb.Size = UDim2.new(0, 180, 0, 48)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.MaxDistance = 140
	bb.AlwaysOnTop = false
	bb.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	frame.BackgroundTransparency = 0.2
	frame.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -6, 0.52, 0)
	titleLbl.Position = UDim2.new(0, 3, 0, 1)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = string.format("%s %d %s", icon, amount, lootType)
	titleLbl.TextColor3 = color
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextScaled = true
	titleLbl.Parent = frame

	local ownerLbl = Instance.new("TextLabel")
	ownerLbl.Size = UDim2.new(1, -6, 0.44, 0)
	ownerLbl.Position = UDim2.new(0, 3, 0.52, 0)
	ownerLbl.BackgroundTransparency = 1
	if killerPlayer then
		ownerLbl.Text = string.format("👤 Killer: %s", killerPlayer.DisplayName)
		ownerLbl.TextColor3 = Color3.fromRGB(240, 220, 140)
	else
		ownerLbl.Text = customLabel or "🌐 OPEN LOOT (Free for All)"
		ownerLbl.TextColor3 = Color3.fromRGB(100, 240, 180)
	end
	ownerLbl.Font = Enum.Font.GothamMedium
	ownerLbl.TextScaled = true
	ownerLbl.Parent = frame

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hold / Carry"
	prompt.ObjectText = string.format("%d %s", amount, lootType)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	part.Parent = PhysicalLootFolder

	local killerUserId = killerPlayer and killerPlayer.UserId or 0
	local killerName = killerPlayer and killerPlayer.DisplayName or "Open"

	local context=assert(Tower.ContextAt(worldPos),"Loot spawn outside room bounds")
	local lootData = {
		FloorId=context.FloorId,RoomGeneration=context.RoomGeneration,
		LootId = lootId,
		LootType = lootType,
		Amount = amount,
		Part = part,
		Prompt = prompt,
		Billboard = bb,
		KillerUserId = killerUserId,
		KillerName = killerName,
		SpawnTime = os.clock(),
		DespawnTime = os.clock() + 90,
	}
	ActiveLootDrops[lootId] = lootData

	local function onCollect(player: Player)
		collectPhysicalLoot(player, lootId)
	end

	prompt.Triggered:Connect(onCollect)

	part.Touched:Connect(function(hit)
		local char = hit.Parent
		if char then
			local p = Players:GetPlayerFromCharacter(char)
			if p then
				onCollect(p)
			end
		end
	end)

	task.delay(90, function()
		if ActiveLootDrops[lootId] == lootData then
			ActiveLootDrops[lootId] = nil
			if part and part.Parent and not part:FindFirstChildOfClass("WeldConstraint") then
				part:Destroy()
			end
		end
	end)

	return lootData
end


-- 5. MOB DEATH, RELIC DROPS & WORLD BOSS 50/50 LOOT + PITY DISTRIBUTION
--============================================================================

local function awardParticipationXP(mob: SimMob)
	local hits = ProgressionHits[mob.NetId]
	ProgressionHits[mob.NetId] = nil
	if not hits then return end
	local now = os.clock()
	local cfg = PitBalance.CombatXP
	local amount = (mob.MobType == "WORLD_BOSS" or mob.MobType == "RIFT_BOSS" or (mob :: any).Role=="BOSS") and cfg.Boss
		or (mob.RingIndex >= 2 and cfg.Ring2 or cfg.Ring1)
	-- Defer profile changes until the current death/tick finishes iterating entities.
	task.defer(function()
		local dm = getDataManager()
		if not dm.GrantCombatXP then return end
		for netId, contribution in pairs(hits) do
			local hero = ActiveHeroesByNetId[netId]
			local owner = hero and hero.Owner
			local character = owner and owner.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if hero and owner and owner.Parent == Players and contribution.Owner==owner and contribution.HeroUUID==hero.HeroUUID and contribution.EntityGeneration==hero.EntityGeneration and Tower.Same(contribution,mob) and humanoid and humanoid.Health > 0
				and hero.State ~= "COMA" and hero.CurrentHP > 0 and hero.Stamina > 0
				and now - (ProgressionActivity[owner] or -math.huge) <= cfg.ActivityWindow
				and now - contribution.At <= cfg.ParticipationWindow
				and contribution.Damage >= mob.MaxHP * cfg.MinimumDamageFraction
				and now - (ProgressionAwards[netId] or -math.huge) >= cfg.AwardCooldown then
				ProgressionAwards[netId] = now
				dm.GrantCombatXP(owner, hero.HeroUUID, amount)
			end
		end
	end)
end

local function handleMobDeath(mob: SimMob, killerPlayer: Player)
	if (mob :: any).TowerEnemy then Encounters:Death(mob,killerPlayer);return end
	if not mob.IsAlive then return end
	local dm = getDataManager()
	mob.IsAlive = false
	awardParticipationXP(mob)

	if mob.MobType == "WORLD_BOSS" then
		ActiveWorldBoss = nil
		-- Compute Total Boss Damage & Shared Blood Pact Scores (Document 1 Section 5.4 & 6.1)
		local totalRawDamage = 0
		for _, dmg in pairs(mob.DamageLedger) do
			totalRawDamage += dmg
		end
		totalRawDamage = math.max(1, totalRawDamage)

		local rankedScores = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local raw = mob.DamageLedger[p.UserId] or 0
			local prof = dm.GetProfile(p)
			local combinedScore = raw
			local pct = (combinedScore / totalRawDamage) * 100.0
			table.insert(rankedScores, {
				Player = p,
				Profile = prof,
				Score = combinedScore,
				Pct = pct,
			})
		end

		table.sort(rankedScores, function(a, b)
			return a.Score > b.Score
		end)

		local rank1UserId = rankedScores[1] and rankedScores[1].Player.UserId or killerPlayer.UserId

		-- Part A: 50% Direct Payout + Boss Pity Meter
		for rankIdx, entry in ipairs(rankedScores) do
			if entry.Pct >= 3.0 and entry.Profile then
				local payout = WorldBossConfig.DirectPayoutByRank[math.min(6, rankIdx)]
				entry.Profile.Currencies.Gems += payout.Gems
				entry.Profile.Currencies.Gold += payout.Gold
				entry.Profile.BossPity = math.min(100, entry.Profile.BossPity + payout.PityGain)

				local wonArchon = (math.random() <= payout.ArchonChance) or (entry.Profile.BossPity >= 100)
				if wonArchon then
					entry.Profile.BossPity = 0
					local uuid, archon = dm.CreateHeroFromSeed("hero_archon", 1.12)
					entry.Profile.Heroes[uuid] = archon
					dm.BroadcastToast(string.format("👑 %s obtained the 3★ Boss Exclusive Hero: SOVEREIGN ARCHON!", entry.Player.DisplayName), "SUCCESS")
				end

				dm.SendToast(
					entry.Player,
					string.format(
						"🏆 World Boss Rank #%d (%.1f%% DMG): +%d Gems, +%d Gold (Boss Pity: %d%%)!",
						rankIdx, entry.Pct, payout.Gems, payout.Gold, entry.Profile.BossPity
					),
					"SUCCESS"
				)
				dm.SyncProfile(entry.Player)
			end
		end

		-- Part B: 50% Physical Drop — THE CALAMITY HEART (15s Rank #1 DPS Lock!)
		if _G.RelicService then
			_G.RelicService.SpawnRelic("CALAMITY_HEART", WORLD_BOSS_ORIGIN, rank1UserId)
			dm.BroadcastToast(
				string.format("❤️‍🔥 THE CALAMITY HEART HAS DROPPED AT RING 3! (15s Exclusive Lock for Rank #1 DPS: %s)", rankedScores[1] and rankedScores[1].Player.DisplayName or killerPlayer.DisplayName),
				"WARN"
			)
		end

		broadcastMetadata(nil)
		return
	end

	-- Standard Mob / Elite / Rift Warden Death
	local spec = (WorldBossConfig.MobSpecs :: any)[mob.SpecId]
	if spec then
		-- Point 1: Universal Physical Loot Drops
		if spec.GoldReward and spec.GoldReward > 0 then
			spawnPhysicalLoot("GOLD", spec.GoldReward, mob.Position, killerPlayer)
		end

		if mob.SpecId == "mob_mana_node" then
			spawnPhysicalLoot("GEMS", math.random(15, 30), mob.Position + Vector3.new(2, 0, 0), killerPlayer)
		elseif mob.MobType == "RING2_ELITE" then
			spawnPhysicalLoot("GEMS", math.random(12, 25), mob.Position + Vector3.new(2, 0, 0), killerPlayer)
		end

		if _G.RelicService and spec.Drops then
			for tierId, chance in pairs(spec.Drops) do
				if math.random() <= chance then
					_G.RelicService.SpawnRelic(tierId, mob.Position, killerPlayer.UserId)
					break
				end
			end
		end

		if spec.RespawnTime and spec.RespawnTime > 0 then
			mob.RespawnAt = os.clock() + spec.RespawnTime
		else
			ActiveMobsByNetId[mob.NetId] = nil
		end
	end

	broadcastMetadata(nil)
end

--============================================================================
-- 6. MASTER COMMAND HANDLERS ([CLICK] FOCUS, [Q] OVERDRIVE, [E] RECALL)
--============================================================================

local function canEngagePvP(attacker: Player, defender: Player): (boolean, string?)
	if attacker == defender then
		return false, "Cannot target your own squad!"
	end
	local now = os.clock()
	local atkPos = getMasterRootPosition(attacker)
	if not atkPos then
		return false, "Attacker position not found"
	end
 local atkState,defState=Tower.GetState(attacker),Tower.GetState(defender)
 local defPos=getMasterRootPosition(defender)
 if not Tower.Same(atkState,defState) or not defPos or Tower.GetSafety(atkState,atkPos).CombatSafe or Tower.GetSafety(defState,defPos).CombatSafe then
		return false, "Cannot engage in PvP inside the Safe Zone (Perimeter Highway / Plots)!"
	end

	-- 1. Attacker has active theft grudge against defender
	if TheftGrudges[attacker.UserId] and (TheftGrudges[attacker.UserId][defender.UserId] or 0) > now then
		return true, nil
	end

	-- 2. Defender is currently flagged as Loot Thief
	local defChar = defender.Character
	if defChar and defChar:GetAttribute("IsLootThief") == true then
		return true, nil
	end

	-- 3. Mutual Retaliation: Defender previously attacked attacker
	if TheftGrudges[defender.UserId] and (TheftGrudges[defender.UserId][attacker.UserId] or 0) > now then
		return true, nil
	end

	return false, string.format("%s is not flagged as a Loot Thief against you!", defender.DisplayName)
end

FocusTargetRemote.OnServerEvent:Connect(function(player: Player, targetNetId: any, optThiefUserId: any)
 if Tower.IsTransitioning(player) then return end
 local towerState=Tower.GetState(player)
 if towerState.SquadAssignment and towerState.FloorId~=towerState.SquadFloorId then return end
 local masterState = ActiveMasters[player]
 local masterPos = getMasterRootPosition(player)
 if not masterState or not masterPos then
		return
	end

	local dm = getDataManager()
	local now = os.clock()

	-- 1. Resolve enemy Player target if passed as optThiefUserId or high ID
	local targetPlayer: Player? = nil
	if type(optThiefUserId) == "number" and optThiefUserId > 0 then
		targetPlayer = Players:GetPlayerByUserId(optThiefUserId)
	elseif type(targetNetId) == "number" and targetNetId > 100000 then
		targetPlayer = Players:GetPlayerByUserId(targetNetId)
	end

	-- 2. If targetNetId is an enemy hero, resolve enemy player
	if not targetPlayer and type(targetNetId) == "number" then
		local hitHero = ActiveHeroesByNetId[targetNetId]
		if hitHero and hitHero.Owner ~= player then
			targetPlayer = hitHero.Owner
		end
	end

	-- 3. If targetPlayer resolved -> Retaliation Squad PvP
	if targetPlayer and targetPlayer ~= player then
		local auth, reason = canEngagePvP(player, targetPlayer)
		if not auth then
			dm.SendToast(player, reason or "Cannot attack target!", "WARN")
			return
		end

		masterState.TargetEnemyUserId = targetPlayer.UserId

		-- Pick target hero in enemy squad
		local targetMasterState = ActiveMasters[targetPlayer]
		local targetHeroNetId: number? = nil
		if targetMasterState then
			for _, h in pairs(targetMasterState.DeployedHeroes) do
				if h.State ~= "COMA" and h.CurrentHP > 0 then
					targetHeroNetId = h.NetId
					break
				end
			end
		end

		if targetHeroNetId then
			masterState.FocusedTargetNetId = targetHeroNetId
			for _, simHero in pairs(masterState.DeployedHeroes) do
				if simHero.State ~= "COMA" then
					simHero.TargetNetId = targetHeroNetId
					simHero.PacifiedUntil = 0
					simHero.State = "MOVE_TO_TARGET"
				end
			end
			dm.SendToast(player, string.format("⚔️ Retaliating against %s's squad!", targetPlayer.DisplayName), "WARN")
		else
			dm.SendToast(player, string.format("%s has no active heroes deployed!", targetPlayer.DisplayName), "INFO")
		end
		return
	end

	-- 4. PvE Mob Targeting
	if type(targetNetId) == "number" then
		local targetMob = ActiveMobsByNetId[targetNetId]
		if targetMob and targetMob.IsAlive and Tower.Same(targetMob,towerState) and not Tower.GetSafety(targetMob,targetMob.Position).CombatSafe then
			if getHorizontalDistance(masterPos, targetMob.Position) <= 95 then
				ProgressionActivity[player] = now
				masterState.TargetEnemyUserId = nil
				masterState.FocusedTargetNetId = targetNetId
				for _, simHero in pairs(masterState.DeployedHeroes) do
					if simHero.State ~= "COMA" then
						simHero.TargetNetId = targetNetId
						simHero.PacifiedUntil = 0
						simHero.State = "MOVE_TO_TARGET"
					end
				end
			end
		end
	end
end)

WhistleCommandRemote.OnServerEvent:Connect(function(player: Player, commandCode: any)
	if type(commandCode) ~= "number" then
		return
	end
	local masterState = ActiveMasters[player]
	local masterPos = getMasterRootPosition(player)
	if not masterState or not masterPos then
		return
	end

	local now = os.clock()
	local dm = getDataManager()

	if commandCode == 1 then
		-- [Q] OVERDRIVE WHISTLE (20s CD, -5 Stamina/hero, +40% Attack Speed for 5s)
		if (now - masterState.LastOverdriveClock) < OVERDRIVE_COOLDOWN then
			return
		end
		masterState.LastOverdriveClock = now
		ProgressionActivity[player] = now

		local profile = dm.GetProfile(player)
		for uuid, simHero in pairs(masterState.DeployedHeroes) do
			if simHero.State ~= "COMA" and simHero.Stamina >= OVERDRIVE_STAMINA_COST then
				simHero.Stamina = math.max(0, simHero.Stamina - OVERDRIVE_STAMINA_COST)
				simHero.OverdriveUntil = now + OVERDRIVE_DURATION
				if profile and profile.Heroes[uuid] then
					profile.Heroes[uuid].CurrentStamina = simHero.Stamina
				end
			end
		end
		Tower.BroadcastAt(CombatVFXRemote,Tower.GetState(player),"WHISTLE_Q",masterPos)
		dm.SyncProfile(player)

	elseif commandCode == 2 then
		Tower.Recall(player)
	end
end)

--============================================================================
-- 7. WORLD BOSS & ELITE AOE SIMULATION
--============================================================================

local function stepWorldBoss(boss: SimMob, dt: number, now: number)
	if not boss.IsAlive then
		return
	end
	local dm = getDataManager()

	if boss.DespawnAt and now >= boss.DespawnAt then
		boss.IsAlive = false
		ActiveWorldBoss = nil
		ProgressionHits[boss.NetId] = nil
		ActiveMobsByNetId[boss.NetId] = nil
		dm.BroadcastToast("⏳ The Dimensional Sovereign tore open a rift and vanished (5m timer expired)!", "WARN")
		broadcastMetadata(nil)
		return
	end

	local hpRatio = boss.CurrentHP / math.max(1, boss.MaxHP)
	if hpRatio <= 0.25 then
		boss.Phase = 3
	elseif hpRatio <= 0.50 then
		boss.Phase = 2
	else
		boss.Phase = 1
	end

	-- 1. Devouring Nova 3.0s Telegraph (Strictly every 20.0s)
	if boss.NovaDetonateTime == nil and now >= boss.NextNovaCastTime then
		boss.NovaDetonateTime = now + NOVA_TELEGRAPH_DURATION
		boss.NextNovaCastTime = now + NOVA_INTERVAL

		-- Phase 2+ Gravity Well: Pull all heroes on Ring 3 inward before Nova telegraph
		if boss.Phase >= 2 then
			for _, simHero in pairs(ActiveHeroesByNetId) do
				local dist = getHorizontalDistance(simHero.Position, WORLD_BOSS_ORIGIN)
				if dist <= 120 and math.abs(simHero.Position.Y - WORLD_BOSS_ORIGIN.Y) < 10 then
					local dir = (simHero.Position - WORLD_BOSS_ORIGIN)
					local unitXZ = Vector3.new(dir.X, 0, dir.Z)
					unitXZ = (unitXZ.Magnitude > 0.01) and unitXZ.Unit or Vector3.new(1, 0, 0)
					local p = WORLD_BOSS_ORIGIN + (unitXZ * 15.0)
					HeroNavigation.Displace(simHero, p)
				end
			end
		end

		Tower.BroadcastAt(BossTelegraphRemote,boss,
			1, -- 1 = DEVOURING_NOVA
			Vector2int16.new(math.round(WORLD_BOSS_ORIGIN.X), math.round(WORLD_BOSS_ORIGIN.Z)),
			NOVA_BLAST_RADIUS,
			math.round(NOVA_TELEGRAPH_DURATION * 1000)
		)
	end

	-- 2. Devouring Nova Detonation (t = 3.0s)
	if boss.NovaDetonateTime ~= nil and now >= boss.NovaDetonateTime then
		boss.NovaDetonateTime = nil
		boss.PunishWindowUntil = now + NOVA_PUNISH_DURATION

		Tower.BroadcastAt(BossTelegraphRemote,boss,
			2, -- 2 = CORE_EXPOSED_PUNISH_WINDOW (5.0s +25% DMG!)
			Vector2int16.new(0, 0),
			NOVA_BLAST_RADIUS,
			math.round(NOVA_PUNISH_DURATION * 1000)
		)

		-- Check Heroes inside R <= 85 studs ("Greed vs. Coma")
		local toComa = {}
		for _, simHero in pairs(ActiveHeroesByNetId) do
			if simHero.State ~= "COMA" and Tower.Same(simHero,boss) and not Tower.GetSafety(simHero,simHero.Position).CombatSafe then
				local distFromAltar = getHorizontalDistance(simHero.Position, WORLD_BOSS_ORIGIN)
				if distFromAltar <= NOVA_BLAST_RADIUS then
					if simHero.Stamina > 50.0 and boss.Phase == 1 then
						simHero.Stamina = math.max(0, simHero.Stamina - 50.0)
						simHero.CurrentHP = math.max(1, simHero.CurrentHP - math.round(simHero.MaxHP * 0.40))
						local profile = dm.GetProfile(simHero.Owner)
						if profile and profile.Heroes[simHero.HeroUUID] then
							profile.Heroes[simHero.HeroUUID].CurrentStamina = simHero.Stamina
						end
						dm.SendToast(simHero.Owner, string.format("⚠️ %s was hit by Devouring Nova (-50 Stamina)! Use [E] Recall from the Safe Rim!", simHero.DisplayName), "WARN")
					else
						table.insert(toComa, simHero)
					end
				end
			end
		end
		for _, h in ipairs(toComa) do
			knockHeroIntoComa(h, COMA_DURATION_DEFAULT)
		end

		-- Also check if any Relic Carrier is inside R <= 85 studs -> Fumble!
		if _G.RelicService then
			for _, p in ipairs(Players:GetPlayers()) do
				local mPos = getMasterRootPosition(p)
				if mPos and Tower.Same(Tower.GetState(p),boss) and not Tower.GetSafety(Tower.GetState(p),mPos).CombatSafe and getHorizontalDistance(mPos, WORLD_BOSS_ORIGIN) <= NOVA_BLAST_RADIUS then
					_G.RelicService.FumbleRelicOnAoEHit(p)
				end
			end
		end
	end
end

local function stepMobAndEliteAoEs(mob: SimMob, dt: number, now: number)
	if not mob.IsAlive then
		if mob.RespawnAt > 0 and now >= mob.RespawnAt then
			mob.EntityGeneration+=1
			mob.IsAlive = true
			mob.CurrentHP = mob.MaxHP
			mob.Position = mob.HomePosition
			mob.RespawnAt = 0
			broadcastMetadata(nil)
		end
		return
	end

	if mob.MobType == "WORLD_BOSS" then
		stepWorldBoss(mob, dt, now)
		return
	end

	if mob.AoERadius > 0 and mob.NextAoECastTime > 0 then
		local spec = (WorldBossConfig.MobSpecs :: any)[mob.SpecId]
		local castDuration = spec and spec.AoECastTime or 2.0
		local cooldown = spec and spec.AoECooldown or 10.0

		if mob.AoEDetonateTime == nil and now >= mob.NextAoECastTime then
			-- Only cast AoE if a hero or player is within 35 studs
			local hasNearby = false
			for _, p in ipairs(Players:GetPlayers()) do
				local mPos = getMasterRootPosition(p)
				if mPos and Tower.Same(Tower.GetState(p),mob) and not Tower.GetSafety(Tower.GetState(p),mPos).CombatSafe and getHorizontalDistance(mPos, mob.Position) <= 35 then
					hasNearby = true
					break
				end
			end
			if hasNearby then
				mob.AoEDetonateTime = now + castDuration
				mob.NextAoECastTime = now + cooldown
				Tower.BroadcastAt(BossTelegraphRemote,mob,
					3, -- 3 = ELITE_AOE_CIRCLE
					Vector2int16.new(math.round(mob.Position.X), math.round(mob.Position.Z)),
					mob.AoERadius,
					math.round(castDuration * 1000)
				)
			else
				mob.NextAoECastTime = now + 2.0
			end
		elseif mob.AoEDetonateTime ~= nil and now >= mob.AoEDetonateTime then
			mob.AoEDetonateTime = nil
			-- Check Hero hits
			local comas = {}
			for _, simHero in pairs(ActiveHeroesByNetId) do
				if Tower.Same(simHero,mob) and not Tower.GetSafety(simHero,simHero.Position).CombatSafe and getHorizontalDistance(simHero.Position, mob.Position) <= mob.AoERadius then
					simHero.Stamina = math.max(0, simHero.Stamina - 15)
					simHero.CurrentHP -= mob.ATK * 2
					if simHero.CurrentHP <= 0 or simHero.Stamina <= 0 then
						table.insert(comas, simHero)
					end
				end
			end
			for _, h in ipairs(comas) do
				knockHeroIntoComa(h, COMA_DURATION_DEFAULT)
			end
			-- Check Relic Carrier Fumbles!
			if _G.RelicService then
				for _, p in ipairs(Players:GetPlayers()) do
					local mPos = getMasterRootPosition(p)
					if mPos and Tower.Same(Tower.GetState(p),mob) and not Tower.GetSafety(Tower.GetState(p),mPos).CombatSafe and getHorizontalDistance(mPos, mob.Position) <= mob.AoERadius then
						_G.RelicService.FumbleRelicOnAoEHit(p)
					end
				end
			end
		end
	end
end

--============================================================================
-- 8. CORE 5 HZ HERO STATE MACHINE
--============================================================================

local function resolveTargetPositionAndAlive(simHero: SimHero): (Vector3?, SimMob?, SimHero?)
	local targetNetId = simHero.TargetNetId
	if targetNetId then
		local mob = ActiveMobsByNetId[targetNetId]
		if mob and mob.IsAlive and Tower.Same(simHero,mob) and not Tower.GetSafety(mob,mob.Position).CombatSafe then
			return mob.Position, mob, nil
		end
		local enemyHero = ActiveHeroesByNetId[targetNetId]
		if enemyHero and enemyHero.State ~= "COMA" and enemyHero.CurrentHP > 0 and Tower.Same(simHero,enemyHero) and not Tower.GetSafety(enemyHero,enemyHero.Position).CombatSafe then
			return enemyHero.Position, nil, enemyHero
		end
	end

	-- Check if Master has an active TargetEnemyUserId to switch to another living hero in that squad!
	local masterState = ActiveMasters[simHero.Owner]
	if masterState and masterState.TargetEnemyUserId then
		local enemyPlayer = Players:GetPlayerByUserId(masterState.TargetEnemyUserId)
		local enemyMasterState = enemyPlayer and ActiveMasters[enemyPlayer]
		if enemyMasterState then
			local nearestHero: SimHero? = nil
			local nearestDist = 9999
			for _, h in pairs(enemyMasterState.DeployedHeroes) do
				if h.State ~= "COMA" and h.CurrentHP > 0 and Tower.Same(simHero,h) and not Tower.GetSafety(h,h.Position).CombatSafe then
					local d = getHorizontalDistance(simHero.Position, h.Position)
					if d < nearestDist then
						nearestDist = d
						nearestHero = h
					end
				end
			end
			if nearestHero then
				simHero.TargetNetId = nearestHero.NetId
				return nearestHero.Position, nil, nearestHero
			else
				-- All heroes in enemy squad are defeated
				masterState.TargetEnemyUserId = nil
				masterState.FocusedTargetNetId = nil
				simHero.TargetNetId = nil
				local dm = getDataManager()
				dm.SendToast(simHero.Owner, string.format("🏆 Defeated %s's squad!", enemyPlayer.DisplayName), "SUCCESS")
			end
		else
			masterState.TargetEnemyUserId = nil
		end
	end

	return nil, nil, nil
end

local function stepHeroSimulation(simHero: SimHero, dt: number, now: number)
	if simHero.State == "COMA" then
		return
	end
 local squadState=Tower.GetState(simHero.Owner)
 local assignedRoom=squadState.SquadAssignment and Tower.GetRoom(squadState.SquadFloorId)
 local masterPos=assignedRoom and (assignedRoom.Origin+FirstBiome.AnchorLocal+Vector3.new(0,3,0)) or getMasterRootPosition(simHero.Owner)
	if not masterPos then
		return
	end

	local dm = getDataManager()
	local profile = dm.GetProfile(simHero.Owner)
	if profile and profile.Heroes[simHero.HeroUUID] then
		local currentHero = profile.Heroes[simHero.HeroUUID]
		local trainingMult = dm.GetTrainingMultiplier and dm.GetTrainingMultiplier(simHero.Owner) or 1.0
		local effATK, effHP, _, interval = StatFormulas.GetEffectiveCombatStats(currentHero, false, false, StatFormulas.GetEquippedArtifact(profile,currentHero), trainingMult)
		simHero.AttackInterval = interval
		simHero.CurrentHP = math.min(simHero.CurrentHP,effHP)
		simHero.EffectiveATK = effATK
		simHero.MaxHP = effHP
	end

	local masterState = ActiveMasters[simHero.Owner]
	local maxLeash = assignedRoom and FirstBiome.LeashRange or (masterState and masterState.TargetEnemyUserId ~= nil) and 150.0 or LEASH_DISTANCE
	if getHorizontalDistance(simHero.Position, masterPos) > maxLeash or math.abs(simHero.Position.Y - masterPos.Y) > 15 then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

 local isPacified = now < simHero.PacifiedUntil or Tower.GetSafety(simHero,simHero.Position).CombatSafe==true
	if isPacified then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

	local isOverdrive = now < simHero.OverdriveUntil
	local isExhausted = simHero.Stamina <= 0.0
	local currentMoveSpeed = simHero.MoveSpeed
		* (isOverdrive and 1.20 or 1.0)
		* (isExhausted and 0.50 or 1.0)

	local targetPos, targetMob, targetEnemyHero = resolveTargetPositionAndAlive(simHero)

	if not targetPos and not isPacified then
		local nearestDist = assignedRoom and FirstBiome.AcquisitionRange or 30.0
		local nearestMobId: number? = nil
		for netId, mob in pairs(ActiveMobsByNetId) do
			if mob.IsAlive and Tower.Same(simHero,mob) and not Tower.GetSafety(mob,mob.Position).CombatSafe and math.abs(mob.Position.Y - simHero.Position.Y) < 12 and math.abs(mob.Position.Y - masterPos.Y) < 12 then
				local d = getHorizontalDistance(masterPos, mob.Position)
				if d < nearestDist then
					nearestDist = d
					nearestMobId = netId
				end
			end
		end
		if nearestMobId then
			simHero.TargetNetId = nearestMobId
			targetPos, targetMob, targetEnemyHero = resolveTargetPositionAndAlive(simHero)
			simHero.State = "MOVE_TO_TARGET"
		else
			simHero.State = "FOLLOW_MASTER"
		end
	end

	if simHero.State == "FOLLOW_MASTER" or not targetPos then
		local goalPos = HeroNavigation.PlaceNear(masterPos, getFormationOffset(simHero.SlotIndex))
		if (goalPos - simHero.Position).Magnitude > .5 then
			HeroNavigation.Step(simHero, goalPos, currentMoveSpeed * dt, now)
		end
		return
	end

	local distToTarget = (simHero.Position - targetPos).Magnitude
	if distToTarget > simHero.AttackRange or not HeroNavigation.CanAttack(simHero.Position, targetPos) then
		simHero.State = "MOVE_TO_TARGET"
		local stepDist = math.min(math.max(.5, distToTarget - simHero.AttackRange * .85), currentMoveSpeed * dt)
		HeroNavigation.Step(simHero, targetPos, stepDist, now)
	else
		simHero.State = "ATTACKING"
		local delta = targetPos - simHero.Position
		if delta.Magnitude > 0.01 then
			simHero.Yaw = math.atan2(-delta.X, -delta.Z)
		end

		local drainRate = simHero.FloorId~=0 and 1.5 or getZoneStaminaDrainPerSec(simHero.Position)
		simHero.Stamina = math.max(0.0, simHero.Stamina - (drainRate * dt))
		if profile and profile.Heroes[simHero.HeroUUID] then
			profile.Heroes[simHero.HeroUUID].CurrentStamina = simHero.Stamina
		end

		local effectiveInterval = simHero.AttackInterval / (isOverdrive and OVERDRIVE_ATK_SPEED_MULT or 1.0)
		simHero.AttackCooldown -= dt
		if simHero.AttackCooldown <= 0 then
			simHero.AttackCooldown = effectiveInterval
			local exhaustionScalar = isExhausted and 0.20 or 1.00
			local damage = math.round(simHero.EffectiveATK * exhaustionScalar)

			if targetMob then
				if targetMob.MobType == "WORLD_BOSS" and now < targetMob.PunishWindowUntil then
					damage = math.round(damage * NOVA_PUNISH_DAMAGE_MULT)
				end
				local actualDamage = math.min(targetMob.CurrentHP, damage)
				local participation = ProgressionHits[targetMob.NetId]
				if not participation then
					participation = {}
					ProgressionHits[targetMob.NetId] = participation
				end
				local previous = participation[simHero.NetId]
				participation[simHero.NetId] = { Damage = (previous and previous.Damage or 0) + actualDamage, At = now, Owner=simHero.Owner, HeroUUID=simHero.HeroUUID, FloorId=simHero.FloorId, RoomGeneration=simHero.RoomGeneration, EntityGeneration=simHero.EntityGeneration }
				targetMob.CurrentHP = math.max(0, targetMob.CurrentHP - damage)
				targetMob.DamageLedger[simHero.Owner.UserId] = (targetMob.DamageLedger[simHero.Owner.UserId] or 0) + damage

				Tower.BroadcastAt(CombatVFXRemote,targetMob,"HIT_SPARK", targetMob.Position, actualDamage, isOverdrive,false)
				if (targetMob :: any).TowerEnemy then
					CombatLifecycleRevision+=1
					Tower.BroadcastAt(TowerRemotes.TowerAction,targetMob,{Kind="HIT",Actor=AttackTimeline.Identity(targetMob),LifecycleRevision=CombatLifecycleRevision,StartServerTime=Workspace:GetServerTimeNow()})
				end

				if targetMob.CurrentHP <= 0 then
					simHero.TargetNetId = nil
					simHero.State = "FOLLOW_MASTER"
					handleMobDeath(targetMob, simHero.Owner)
				end
			elseif targetEnemyHero then
				local pvpDamage = math.max(1, math.round(damage * 0.25))
				local actualDamage=math.min(targetEnemyHero.CurrentHP,pvpDamage)
				targetEnemyHero.CurrentHP = math.max(0, targetEnemyHero.CurrentHP - pvpDamage)
				Tower.BroadcastAt(CombatVFXRemote,targetEnemyHero,"HIT_SPARK", targetEnemyHero.Position, actualDamage, isOverdrive,true)

				-- Defending hero and defending Master auto-retaliate
				if targetEnemyHero.State == "FOLLOW_MASTER" or targetEnemyHero.TargetNetId == nil then
					targetEnemyHero.TargetNetId = simHero.NetId
					targetEnemyHero.State = "MOVE_TO_TARGET"
				end
				local defMasterState = ActiveMasters[targetEnemyHero.Owner]
				if defMasterState and not defMasterState.TargetEnemyUserId then
					defMasterState.TargetEnemyUserId = simHero.Owner.UserId
					TheftGrudges[targetEnemyHero.Owner.UserId] = TheftGrudges[targetEnemyHero.Owner.UserId] or {}
					TheftGrudges[targetEnemyHero.Owner.UserId][simHero.Owner.UserId] = now + 180
				end

				if targetEnemyHero.CurrentHP <= 0 then
					knockHeroIntoComa(targetEnemyHero, 30)
				end
			end
		end
	end
end

--============================================================================
-- 9. COMPACT BINARY BUFFER SERIALIZATION & 5 HZ HEARTBEAT
--============================================================================

local STATE_TO_ENUM: { [HeroSimState]: number } = {
	FOLLOW_MASTER = 1,
	MOVE_TO_TARGET = 2,
	ATTACKING = 3,
	COMA = 4,
}

local function broadcastReplicationSnapshot(now: number)
 SnapshotSequence=(SnapshotSequence+1)%4294967296
 local byFloor={}
 for _,collection in {ActiveHeroesByNetId,ActiveMobsByNetId} do for _,e in pairs(collection) do
  if e.IsAlive==false then continue end
  local room=Tower.GetRoom(e.FloorId)
  if not room or room.RoomGeneration~=e.RoomGeneration then continue end
  if not Protocol.InBounds(e.Position,room.Origin,room.Bounds) then
   warn("Tower entity recovered outside bounds",e.NetId);e.Position=room.Arrival.Position-Vector3.new(0,3.5,0);HeroNavigation.Clear(e)
  end
  local hero=e.Owner~=nil;local entry=table.clone(e)
  entry.StateEnum=hero and (STATE_TO_ENUM[e.State] or 1) or (e.TowerEnemy and ({IDLE=20,CHASE=21,WINDUP=22,RECOVERY=23,RESET=24})[e.State] or (10+(e.Phase or 1)))
  entry.Flags=hero and (1+(now<e.OverdriveUntil and 2 or 0)+(now<e.PacifiedUntil and 4 or 0)) or (e.MobType=="WORLD_BOSS" and now<e.PunishWindowUntil and 8 or 0)
  byFloor[e.FloorId]=byFloor[e.FloorId] or {};table.insert(byFloor[e.FloorId],entry)
 end end
 for _,p in Players:GetPlayers() do
  local c=Tower.Context(p)
  for _,packet in Protocol.Encode(c,byFloor[c.FloorId] or {},SnapshotSequence,Workspace:GetServerTimeNow()) do TowerRemotes.TowerSnapshot:FireClient(p,packet) end
 end
end
local function squadCount(player: Player): number
 local state=ActiveMasters[player];local n=0
 if state then for _,h in pairs(state.DeployedHeroes) do if h.CurrentHP>0 and h.State~="COMA" then n+=1 end end end
 return n
end
Tower.RegisterAdapter("Combat",{
 Count=squadCount,
 ValidateRoster=function(player)
  local m=ActiveMasters[player];local profile=_G.DataManager.GetProfile(player)
  if not m or not profile then return false end
  for uuid,h in pairs(m.DeployedHeroes) do
   local data=profile.Heroes[uuid]
   if not data or data.Assignment~="SQUAD_SLOT_"..h.SlotIndex or (data.ComaUntilTimestamp or 0)>os.time() or h.CurrentHP<=0 then return false end
  end
  return true
 end,
 CaptureSquad=function(player)
  local m=ActiveMasters[player];if not m then return {} end
  local saved={Master=m,FocusedTargetNetId=m.FocusedTargetNetId,TargetEnemyUserId=m.TargetEnemyUserId,LastRecallClock=m.LastRecallClock,Heroes={}}
  for _,h in pairs(m.DeployedHeroes) do table.insert(saved.Heroes,{Ref=h,Position=h.Position,FloorId=h.FloorId,RoomGeneration=h.RoomGeneration,EntityGeneration=h.EntityGeneration,
   TargetNetId=h.TargetNetId,State=h.State,PacifiedUntil=h.PacifiedUntil,ActionSequence=h.ActionSequence}) end
  return saved
 end,
 RestoreSquad=function(saved)
  if not saved.Master then return end
  saved.Master.FocusedTargetNetId=saved.FocusedTargetNetId;saved.Master.TargetEnemyUserId=saved.TargetEnemyUserId;saved.Master.LastRecallClock=saved.LastRecallClock
  for _,entry in saved.Heroes do for _,key in {"Position","FloorId","RoomGeneration","EntityGeneration","TargetNetId","State","PacifiedUntil","ActionSequence"} do entry.Ref[key]=entry[key] end;HeroNavigation.Clear(entry.Ref) end
 end,
 CanRecall=function(player) local m=ActiveMasters[player];return m~=nil and os.clock()-m.LastRecallClock>=RECALL_COOLDOWN end,
 Transfer=function(player,room,recall,anchor)
  local m=ActiveMasters[player];if not m then return end
  m.FocusedTargetNetId=nil;m.TargetEnemyUserId=nil
  if recall then m.LastRecallClock=os.clock();ProgressionActivity[player]=os.clock() end
  for _,h in pairs(m.DeployedHeroes) do
   h.FloorId=room.FloorId;h.RoomGeneration=room.RoomGeneration;h.EntityGeneration+=1
   h.Position=HeroNavigation.PlaceNear(anchor or room.Arrival.Position,getFormationOffset(h.SlotIndex))
   h.TargetNetId=nil;h.State="FOLLOW_MASTER";h.PacifiedUntil=os.clock()+2;h.ActionSequence=0;HeroNavigation.Clear(h)
   for _,other in pairs(ActiveHeroesByNetId) do if other.TargetNetId==h.NetId then other.TargetNetId=nil;other.State="FOLLOW_MASTER" end end
  end
 end,
 CaptureCargo=function(player) return CarrierToHeldLoot[player] end,
 DropCargo=function(player) CombatSimulation.DropCarriedLoot(player,true) end,
 Pins=function(id,gen)
  if Encounters and Encounters:Pins(id,gen) then return true end
  for _,items in {ActiveLootDrops,CarrierToHeldLoot} do for _,item in pairs(items) do if item.FloorId==id and item.RoomGeneration==gen and item.Part and item.Part.Parent then return true end end end
  return false
 end,
 Bootstrap=sendBootstrap,BootstrapAll=bootstrapAll,
})
if RunService:IsStudio() then CombatSimulation.DebugEntities=function() return ActiveHeroesByNetId,ActiveMobsByNetId,CarrierToHeldLoot end end

Encounters=EncounterRuntime.new({Tower=Tower,Heroes=ActiveHeroesByNetId,Mobs=ActiveMobsByNetId,Navigation=HeroNavigation,Allocate=allocateNetId,
 Changed=bootstrapAll,
 Send=function(context,message)
  CombatLifecycleRevision+=1;message.LifecycleRevision=CombatLifecycleRevision
  Tower.BroadcastAt(TowerRemotes.TowerAction,context,message)
 end,
 Damage=function(victim,damage,mob)
  if not Tower.Same(victim,mob) or Tower.GetSafety(victim,victim.Position).CombatSafe then return end
  if victim.Player then
   local hp=victim.Humanoid.Health;victim.Humanoid:TakeDamage(damage)
   Tower.BroadcastAt(CombatVFXRemote,victim,"HIT_SPARK",victim.Position,hp-victim.Humanoid.Health,false,true)
  else
   local actualDamage=math.min(victim.CurrentHP,damage)
   victim.CurrentHP=math.max(0,victim.CurrentHP-damage)
   Tower.BroadcastAt(CombatVFXRemote,victim,"HIT_SPARK",victim.Position,actualDamage,false,true)
   if victim.CurrentHP<=0 then knockHeroIntoComa(victim,COMA_DURATION_DEFAULT) end
  end
 end,
 Reward=function(mob,killer)
  awardParticipationXP(mob)
  local dm = getDataManager()
  if killer and killer.Parent==Players then
   local marketMult = dm.GetMarketMultiplier and dm.GetMarketMultiplier(killer) or 1.0
   local rewardGold = math.round(mob.GoldReward * marketMult)
   spawnPhysicalLoot("GOLD",rewardGold,mob.Position,killer,mob.DisplayName)
  end
  if (mob :: any).Role == "BOSS" and mob.FloorId and mob.FloorId % 5 == 0 then
   local bossTier = math.floor(mob.FloorId / 5)
   if killer and killer.Parent == Players then
    dm.RecordBiomeBossClear(killer, bossTier)
   end
   for p in pairs(ActiveMasters) do
    local s = Tower.GetState(p)
    if (s.FloorId == mob.FloorId or s.SquadFloorId == mob.FloorId) and p ~= killer then
     dm.RecordBiomeBossClear(p, bossTier)
    end
   end
  end
 end,
})
if RunService:IsStudio() then
 CombatSimulation.DebugEncounters=Encounters
 CombatSimulation.DebugBootstrap=bootstrapAll
 CombatSimulation.DebugKillTowerMob=function(mob,killer) assert(mob.TowerEnemy);Encounters:Death(mob,killer) end
end

-- Initialize Mobs & Loop
-- Legacy tower population disabled for the isolated-room migration.

Players.PlayerAdded:Connect(function(player: Player)
	task.delay(1.0, function()
		CombatSimulation.RebuildPlayerSquad(player)
		broadcastMetadata(player)
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.delay(0.5, function()
		CombatSimulation.RebuildPlayerSquad(p)
		broadcastMetadata(p)
	end)
end

Players.PlayerRemoving:Connect(function(player: Player)
	CombatSimulation.DropCarriedLoot(player,true)
	ProgressionActivity[player] = nil
	LastMetadataRequestByPlayer[player] = nil
	local masterState = ActiveMasters[player]
	if masterState then
		for _, simHero in pairs(masterState.DeployedHeroes) do
			HeroNavigation.Clear(simHero)
			ProgressionAwards[simHero.NetId] = nil
			ActiveHeroesByNetId[simHero.NetId] = nil
		end
		ActiveMasters[player] = nil
	end
end)

local accumulator = 0.0
RunService.Heartbeat:Connect(function(deltaTime: number)
	-- Movement/acquisition stays at 5 Hz; scheduled contacts resolve each heartbeat.
	Encounters:StepActions()
	accumulator += deltaTime
	if accumulator < TICK_INTERVAL then
		return
	end

	local dt = accumulator
	accumulator = 0.0
	local now = os.clock()
	Encounters:Tick(dt)

	if not ActiveWorldBoss and now >= NextWorldBossSpawnClock then
		CombatSimulation.SpawnWorldBoss()
	end

	for _, mob in pairs(ActiveMobsByNetId) do
		if not (mob :: any).TowerEnemy then stepMobAndEliteAoEs(mob, dt, now) end
	end

	for _, simHero in pairs(ActiveHeroesByNetId) do
		stepHeroSimulation(simHero, dt, now)
	end

	-- Safe Zone Banking & Recovery Loop (R >= 460)
	for player, masterState in pairs(ActiveMasters) do
		local rootPos = getMasterRootPosition(player)
		if rootPos then
			local location=Tower.GetState(player)
			local safety=Tower.GetSafety(location,rootPos)
			if safety.CanBankCargo and location.BankArmed and not Tower.IsTransitioning(player) then
				local held = CarrierToHeldLoot[player]
				if held then
					local dm = getDataManager()
					local prof = dm.GetProfile(player)
					if prof then
						if held.LootType == "GOLD" then
							local marketMult = dm.GetMarketMultiplier and dm.GetMarketMultiplier(player) or 1.0
							local finalGold = math.round(held.Amount * marketMult)
							prof.Currencies.Gold += finalGold
							dm.SendToast(
								player,
								if marketMult > 1.0
									then string.format("🏦 Safely Banked Field Cargo: +%d GOLD (Market: +%.1f%%)!", finalGold, (marketMult - 1) * 100)
									else string.format("🏦 Safely Banked Field Cargo: +%d GOLD!", finalGold),
								"SUCCESS"
							)
						elseif held.LootType == "GEMS" then
							prof.Currencies.Gems += held.Amount
							dm.SendToast(
								player,
								string.format("🏦 Safely Banked Field Cargo: +%d GEMS!", held.Amount),
								"SUCCESS"
							)
						end
						dm.SyncProfile(player)
					end

					if held.Weld and held.Weld.Parent then
						held.Weld:Destroy()
					end
					if held.Part and held.Part.Parent then
						held.Part:Destroy()
					end

					clearLootCarryState(player)
				end

				if masterState.IsSquadWiped then
					local hasHealthyHero = false
					for _, h in pairs(masterState.DeployedHeroes) do
						if h.State ~= "COMA" and h.CurrentHP > 0 then
							hasHealthyHero = true
							break
						end
					end
					if hasHealthyHero then
						masterState.IsSquadWiped = false
						masterState.CanCollectLoot = true
						if player.Character then
							player.Character:SetAttribute("SquadWiped", false)
						end
						SquadWipeStateRemote:FireClient(player, false)
						local dm = getDataManager()
						dm.SendToast(player, "🛡️ Squad operational! Field looting re-enabled.", "SUCCESS")
					end
				end
			end
		end
	end

 for p,held in pairs(CarrierToHeldLoot) do if now>=held.DespawnTime then
  if held.Weld then held.Weld:Destroy() end;if held.Part then held.Part:Destroy() end;clearLootCarryState(p)
 end end
 broadcastReplicationSnapshot(now)
end)

CombatSimulation.SpawnPhysicalLoot = spawnPhysicalLoot
CombatSimulation.CollectPhysicalLoot = collectPhysicalLoot
CombatSimulation.TheftGrudges = TheftGrudges
_G.CombatSimulation = CombatSimulation
