--!strict
-- ServerScriptService/Combat/CombatSimulation.server.luau
-- 5 Hz (0.20s) Server-Authoritative Tower Combat & Encounter Simulation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local ArchetypeCombatSkills = require(Shared:WaitForChild("Config"):WaitForChild("ArchetypeCombatSkills"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local PitBalance = require(Shared:WaitForChild("Config"):WaitForChild("PitBalanceConfig"))
local ArtPackVisuals = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ArtPackVisuals"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local HeroNavigation = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("HeroNavigation"))

local Tower=require(script.Parent.Parent.Core.TowerFloorService)
Tower.Init()
local Protocol=require(Shared.Util.TowerProtocol)
local SanctuaryRules=require(Shared.Util.TowerSanctuaryRules)
local FirstBiome=require(Shared.Config.FirstBiomeCombat)
local TowerLayout=require(Shared.Config.TowerLayout)
local TowerRewards=require(Shared.Config.TowerFloorConfig)
local TowerHardcore=require(Shared.Config.TowerHardcoreConfig)
local StatBalance=require(Shared.Config.StatBalance)
local EncounterRuntime=require(script.Parent.TowerEncounterRuntime)
local TowerRuns=require(script.Parent.TowerRunService)
local TowerRun=require(Shared.Util.TowerRun)
local AttackTimeline=require(Shared.Util.AttackTimeline)
local HeroActionTiming=require(Shared.Util.HeroActionTiming)
local HeroImpactQueue=require(script.Parent.HeroImpactQueue)
local HeroSkillEffects=require(script.Parent.HeroSkillEffects)
local HeroImpacts=HeroImpactQueue.new()
local TowerProgress=require(Shared.Util.TowerProgress)
local LootDuel=require(Shared.Util.LootDuel)
local DuelArena=require(script.Parent.DuelArena)
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
local LootContestedRemote = TowerRemotes:WaitForChild("LootContested") :: RemoteEvent
local InitiateRetaliationRemote = TowerRemotes:WaitForChild("InitiateRetaliation") :: RemoteEvent
local DuelStateRemote = TowerRemotes:WaitForChild("DuelState") :: RemoteEvent
local SquadWipeStateRemote = CombatRemotes:WaitForChild("SquadWipeState") :: RemoteEvent
local CarriedLootSyncRemote = CombatRemotes:WaitForChild("CarriedLootSync") :: RemoteEvent
local PhysicalLootFolder = Workspace:WaitForChild("PhysicalLoot") :: Folder
local FloorProgressRemote = TowerRemotes:WaitForChild("FloorProgress") :: RemoteEvent
local SquadDefeatedRemote = TowerRemotes:WaitForChild("SquadDefeated") :: RemoteEvent
local SquadStatusRemote = TowerRemotes:WaitForChild("SquadStatus") :: RemoteEvent
local ActivePlayerProgress: { [Player]: TowerProgress.PlayerFloorProgress } = {}

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

-- Training Grounds multiplier, reduced by Rift Attunement when a hero out-powers what its Master's highest floor allows.
local function attunedMultiplier(player: Player, profile: any, hero: any, artifact: any?): number
	local training = getDataManager().GetTrainingMultiplier and getDataManager().GetTrainingMultiplier(player) or 1.0
	return StatFormulas.GetAttunedMultiplier(hero, artifact, training, StatFormulas.GetAttunementCap(profile.MaxFloorReached))
end

--============================================================================
-- 1. CONSTANTS & SIMULATION TYPES
--============================================================================

local TICK_INTERVAL = StatBalance.TickSeconds -- 10 Hz server simulation (Phase 6 M6)
-- Snapshots stay at 5 Hz (every second tick) until a Studio profile with six busy floors clears the 25 KB/s client budget.
local SNAPSHOT_EVERY_TICKS = 2
local snapshotTick = 0
local FIELD_LOOT_DESPAWN_SECONDS = 90
local MASTER_FORMATION_RADIUS = 6.0
local LEASH_DISTANCE = 65.0

local OVERDRIVE_COOLDOWN = 20.0
local OVERDRIVE_DURATION = 5.0
local OVERDRIVE_STAMINA_COST = 5.0
local OVERDRIVE_ATK_SPEED_MULT = 1.40

local RECALL_COOLDOWN = 6.0
local RECALL_PACIFY_DURATION = 2.0

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
	Archetype: string?,
	AttackCount: number?,
	BarrierHP: number?,
	BarrierExpires: number?,
	DuelId: number?, -- set while the hero fights in a retaliation duel
	DuelSide: LootDuel.Side?,
	DefenseShredUntil: number?,
}

export type SimMob = {
	NetId: number,
	FloorId: number,
	RoomGeneration: number,
	EntityGeneration: number,
	SpecId: string,
	DisplayName: string,
	MobType: string?,
	RingIndex: number?,
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
	DefenseShredUntil: number?,
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

-- Contested drops (GDD 6.1): one contest per stolen drop, keyed by LootId.
local Contests: { [number]: LootDuel.Contest } = {}
local ThiefFlagUntil: { [Player]: number } = {}
local LastRetaliationRequest: { [Player]: number } = {}
local LastPickupDenial: { [Player]: number } = {}

type DuelSquad = { Player: Player, Heroes: { SimHero }, Saved: { [SimHero]: any }, Frozen: any? }
type Duel = {
	Id: number,
	Contest: LootDuel.Contest,
	FloorId: number,
	Center: Vector3,
	Forward: Vector3,
	Arena: Model,
	Phase: "INTRO" | "FIGHT" | "OUTRO",
	FightAt: number,
	EndsAt: number,
	OutroUntil: number,
	Sides: { A: DuelSquad, B: DuelSquad },
	Winner: LootDuel.Side?,
}
local Duels: { [number]: Duel } = {}
local DuelByPlayer: { [Player]: Duel } = {}
local NextDuelId = 1
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
local HeroStuckTracking: { [number]: { LastDist: number, LastClock: number } } = {}
local ActiveHeroesByNetId: { [number]: SimHero } = {}
local ActiveMobsByNetId: { [number]: SimMob } = {}
-- Progression is awarded on a confirmed PvE death, outside the simulation's per-tick work.
-- Only recent, deliberate Master commands qualify; idle auto-attacks do not level a squad.
local ProgressionActivity: { [Player]: number } = {}
local ProgressionHits: { [number]: { [number]: { Damage: number, At: number } } } = {}
local ProgressionAwards: { [number]: number } = {}

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
			DuelSide = h.DuelSide,
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

local function getMasterGroundPosition(player: Player): Vector3?
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end
	local ground = HeroNavigation.Ground(hrp.Position, nil, 3, 50)
	return ground or (hrp.Position - Vector3.new(0, 3, 0))
end

local function getAssignedSpawnRoot(room: any): Vector3
	if not room or (room.FloorId or 0) <= 0 then
		return room and room.Arrival and room.Arrival.Position or Vector3.new(0, 3, 0)
	end
	local idx = ((room.FloorId - 1) % 5) + 1
	local layout = TowerLayout.Get(idx)
	local basin = layout.Platforms.Basin
	return room.Origin + Vector3.new(basin.X, basin.Y + 3, basin.Z)
end

local function getAssignedFloorAnchor(floorId: number, room: any, masterState: MasterCombatState?): Vector3
	local basinRoot = getAssignedSpawnRoot(room)
	if not room or floorId <= 0 then
		return basinRoot
	end
	if masterState then
		for _, h in pairs(masterState.DeployedHeroes) do
			if h.State ~= "COMA" and h.CurrentHP > 0 and h.TargetNetId then
				local mob = ActiveMobsByNetId[h.TargetNetId]
				if mob and mob.IsAlive and Tower.Same(mob, room) and not Tower.GetSafety(mob, mob.Position).CombatSafe then
					return mob.Position + Vector3.new(0, 3, 0)
				end
			end
		end
	end
	local refPos = basinRoot
	if masterState then
		local sum = Vector3.zero
		local count = 0
		for _, h in pairs(masterState.DeployedHeroes) do
			if h.State ~= "COMA" and h.CurrentHP > 0 and h.FloorId == floorId then
				sum += h.Position
				count += 1
			end
		end
		if count > 0 then
			refPos = sum / count
		end
	end
	local nearestMob: SimMob? = nil
	local nearestDist = math.huge
	for _, mob in pairs(ActiveMobsByNetId) do
		if mob.IsAlive and Tower.Same(mob, room) and not Tower.GetSafety(mob, mob.Position).CombatSafe then
			local d = (mob.Position - refPos).Magnitude
			if d < nearestDist then
				nearestDist = d
				nearestMob = mob
			end
		end
	end
	if nearestMob then
		return nearestMob.Position + Vector3.new(0, 3, 0)
	end
	return basinRoot
end

local function isPlayerJumping(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp then return false end
	return hum.FloorMaterial == Enum.Material.Air and hrp.AssemblyLinearVelocity.Y > 2.5
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
			local trainingMult = attunedMultiplier(player, profile, hero, StatFormulas.GetEquippedArtifact(profile,hero))
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

local syncSquadStatus: (player: Player) -> ()

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
	local masterPos=towerState.SquadAssignment and getAssignedFloorAnchor(towerState.SquadFloorId, room, masterState) or getMasterGroundPosition(player) or room.Arrival.Position
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
		local trainingMult = attunedMultiplier(player, profile, heroData, artifact)
		local effATK, effHP, _, effInterval = StatFormulas.GetEffectiveCombatStats(heroData, false, false, artifact, trainingMult)
		local existing = masterState.DeployedHeroes[uuid]
		if existing then
			rosterChanged=rosterChanged or existing.SlotIndex~=slotIndex
			existing.Stars = heroData.Stars
			existing.Level = heroData.Level
			existing.EffectiveATK = effATK
			existing.MaxHP = effHP
			existing.CurrentHP = math.min(existing.CurrentHP, effHP)
			existing.Stamina = heroData.CurrentStamina or existing.Stamina or 0.0
			existing.SlotIndex = slotIndex
			existing.AttackInterval = effInterval
			existing.EquippedArtifactId = artifact and artifact.TemplateId
			existing.EquippedArtifactRarity = artifact and artifact.Rarity
			existing.EquippedArtifactType = artifact and artifact.Type
			existing.EquippedArtifactStar = artifact and artifact.Star
			existing.Archetype = (HeroCatalog.Seeds[heroData.TemplateId] and HeroCatalog.Seeds[heroData.TemplateId].Archetype) or "Striker"
			existing.AttackCount = existing.AttackCount or 0
			existing.BarrierHP = existing.BarrierHP or 0
			existing.BarrierExpires = existing.BarrierExpires or 0
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
				Stamina = heroData.CurrentStamina or 0.0,
				SlotIndex = slotIndex,
				TargetNetId = masterState.FocusedTargetNetId,
				AttackCooldown = 0.2,
				PacifiedUntil = 0,
				OverdriveUntil = 0,
				EquippedArtifactId = artifact and artifact.TemplateId,
				EquippedArtifactRarity = artifact and artifact.Rarity,
				EquippedArtifactType = artifact and artifact.Type,
				EquippedArtifactStar = artifact and artifact.Star,
				Archetype = (HeroCatalog.Seeds[heroData.TemplateId] and HeroCatalog.Seeds[heroData.TemplateId].Archetype) or "Striker",
				AttackCount = 0,
				BarrierHP = 0,
				BarrierExpires = 0,
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
 syncSquadStatus(player)
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

function CombatSimulation.BankHeldLoot(player: Player, location: any?): boolean
	local held = CarrierToHeldLoot[player]
	if not held then return false end
	local dm = getDataManager()
	local prof = dm.GetProfile(player)
	if not prof then return false end

	CarrierToHeldLoot[player] = nil
	local loc = location or Tower.GetState(player)
	local floorId = if loc and type(loc.FloorId) == "number" then loc.FloorId else 0
	local prefix = if floorId > 0 then string.format("📦 Unpackaged Field Loot at Floor %d Safe Zone: ", floorId) else "🏦 Safely Banked Field Cargo: "

	if held.LootType == "GOLD" then
		local marketMult = dm.GetMarketMultiplier and dm.GetMarketMultiplier(player) or 1.0
		local finalGold = math.round(held.Amount * marketMult)
		prof.Currencies.Gold += finalGold
		dm.SendToast(
			player,
			if marketMult > 1.0
				then prefix .. string.format("+%d GOLD (Market: +%.1f%%)!", finalGold, (marketMult - 1) * 100)
				else prefix .. string.format("+%d GOLD!", finalGold),
			"SUCCESS"
		)
	elseif held.LootType == "GEMS" then
		prof.Currencies.Gems += held.Amount
		dm.SendToast(
			player,
			prefix .. string.format("+%d GEMS!", held.Amount),
			"SUCCESS"
		)
	end
	dm.SyncProfile(player)

	if held.Weld and held.Weld.Parent then
		held.Weld:Destroy()
	end
	if held.Part and held.Part.Parent then
		held.Part:Destroy()
	end

	clearLootCarryState(player)
	return true
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
	local despawnTime = now + FIELD_LOOT_DESPAWN_SECONDS
	local dropped = {
		LootId = held.LootId, LootType = held.LootType, Amount = held.Amount,
		FloorId=held.FloorId,RoomGeneration=held.RoomGeneration,
		Part = part, Prompt = held.OriginalPrompt, Billboard = held.Billboard,
		KillerUserId = openLoot and 0 or held.KillerUserId,
		KillerName = openLoot and "Open" or held.KillerName,
		SpawnTime = held.SpawnTime, DespawnTime = despawnTime,
		PickupBlockedUserId = player.UserId, PickupBlockedUntil = now + 1.5,
		LockedOut = held.LockedOut, DuelLocked = held.DuelLocked,
	}
	ActiveLootDrops[held.LootId] = dropped
	if held.OriginalPrompt then
		held.OriginalPrompt.ActionText = "Hold / Carry"
		held.OriginalPrompt.Enabled = true
	end
	task.delay(FIELD_LOOT_DESPAWN_SECONDS, function()
		if ActiveLootDrops[held.LootId] == dropped then
			ActiveLootDrops[held.LootId] = nil
			if part and part.Parent and not part:FindFirstChildOfClass("WeldConstraint") then
				part:Destroy()
			end
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

local function knockHeroIntoComa(simHero: SimHero, _baseComaSeconds: number?)
	HeroNavigation.Clear(simHero)
	local dm = getDataManager()
	local profile = dm.GetProfile(simHero.Owner)

	-- Phase 2 Hard Death Rules: dead heroes collapse in place with CurrentHP = 0, State = "COMA"
	-- No 60-second coma and no hospital/infirmary timers!
	simHero.CurrentHP = 0
	simHero.State = "COMA"
	simHero.TargetNetId = nil
	ProgressionAwards[simHero.NetId] = nil

	if profile then
		local heroInstance = profile.Heroes[simHero.HeroUUID]
		if heroInstance then
			heroInstance.ComaUntilTimestamp = 0 -- schema default; nil breaks numeric comparisons
		end
	end

	dm.SendToast(
		simHero.Owner,
		string.format("%s collapsed! (No mid-run revives)", simHero.DisplayName),
		"WARN"
	)
	dm.SyncProfile(simHero.Owner)

	Tower.BroadcastAt(CombatVFXRemote, simHero, "HERO_KO", simHero.Position, simHero.NetId)

	local masterState = ActiveMasters[simHero.Owner]

	-- Squad Wipe Detection: Check if ALL deployed heroes are now in Coma (CurrentHP <= 0)
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

		local towerState = Tower.GetState(simHero.Owner)
		local wipeFloor = if towerState.SquadFloorId and towerState.SquadFloorId > 0 then towerState.SquadFloorId else towerState.FloorId
		local playerOnWipeFloor = (towerState.FloorId == wipeFloor and wipeFloor > 0)

		if playerOnWipeFloor then
			-- Phase 6 wipe loss: a share of the Gold and Gems earned since the last bank is gone, and the run (and streak) ends.
			local run = TowerRuns.Get(simHero.Owner)
			local profile = dm.GetProfile(simHero.Owner)
			local lossGold, lossGems = 0, 0
			if run and profile then
				lossGold, lossGems = TowerRun.WipeLoss(run, profile.Currencies.Gold, profile.Currencies.Gems)
				profile.Currencies.Gold -= lossGold
				profile.Currencies.Gems -= lossGems
				dm.SyncProfile(simHero.Owner)
			end
			if run then
				TowerRuns.End(simHero.Owner, "WIPE", lossGold, lossGems)
				if lossGold > 0 or lossGems > 0 then
					dm.SendToast(simHero.Owner, string.format("Wiped: lost %d Gold and %d Gems earned since you last banked. Banked loot is safe.", lossGold, lossGems), "WARN")
				end
			end
			CombatSimulation.DropCarriedLoot(simHero.Owner, true)
			if _G.RelicService then
				_G.RelicService.FumbleRelicOnAoEHit(simHero.Owner)
			end
			masterState.CarriedLoot = { Gold = 0, Gems = 0 }
			CarriedLootSyncRemote:FireClient(simHero.Owner, 0, 0)
		end

		SquadWipeStateRemote:FireClient(simHero.Owner, true)
		if SquadDefeatedRemote then
			SquadDefeatedRemote:FireClient(simHero.Owner, wipeFloor)
		end

		if playerOnWipeFloor then
			dm.SendToast(
				simHero.Owner,
				string.format("ALL HEROES FALLEN on Floor %d! Carried loot dropped. Teleporting to Fortress Plot...", wipeFloor),
				"WARN"
			)
		else
			dm.SendToast(
				simHero.Owner,
				string.format("Assigned squad fallen on Floor %d! Squad recalled and recovered.", wipeFloor),
				"WARN"
			)
		end

		task.defer(function()
			if Tower.RecallWipedSquad then
				Tower.RecallWipedSquad(simHero.Owner)
			end
			if playerOnWipeFloor then
				-- PlotManager is a Script (not a ModuleScript); it publishes itself as _G.PlotManager.
				local PlotManager = _G.PlotManager
				if PlotManager and PlotManager.TeleportPlayerToPlot then
					PlotManager.TeleportPlayerToPlot(simHero.Owner)
				else
					Tower.CommitRespawn(simHero.Owner)
				end
			end
		end)
	end

	syncSquadStatus(simHero.Owner)
	broadcastMetadata(nil)
end

syncSquadStatus = function(player: Player)
	local masterState = ActiveMasters[player]
	if not masterState then return end
	local total = 0
	local alive = 0
	local fallen = 0
	local fallenNames = {}
	local heroStatuses = {}
	for _, h in pairs(masterState.DeployedHeroes) do
		total += 1
		local isDown = h.State == "COMA" or h.CurrentHP <= 0
		if isDown then
			fallen += 1
			table.insert(fallenNames, h.DisplayName or "Hero")
			table.insert(heroStatuses, { Name = h.DisplayName or "Hero", Alive = false, HpPct = 0 })
		else
			alive += 1
			local pct = math.round((h.CurrentHP / math.max(1, h.MaxHP)) * 100)
			table.insert(heroStatuses, { Name = h.DisplayName or "Hero", Alive = true, HpPct = pct })
		end
	end
	local isWiped = total > 0 and alive == 0
	if player.Character then
		player.Character:SetAttribute("AliveHeroCount", alive)
		player.Character:SetAttribute("TotalHeroCount", total)
		player.Character:SetAttribute("FallenHeroCount", fallen)
		player.Character:SetAttribute("SquadWiped", isWiped)
	end
	if SquadStatusRemote then
		SquadStatusRemote:FireClient(player, {
			TotalCount = total,
			AliveCount = alive,
			FallenCount = fallen,
			IsWiped = isWiped,
			FallenHeroes = fallenNames,
			HeroStatuses = heroStatuses,
		})
	end
end

local function restoreSquadOnPlot(player: Player)
	local masterState = ActiveMasters[player]
	if masterState then
		for _, h in pairs(masterState.DeployedHeroes) do
			h.CurrentHP = h.MaxHP
			h.State = "FOLLOW_MASTER"
			ActiveHeroesByNetId[h.NetId] = h
		end
		masterState.IsSquadWiped = false
		masterState.CanCollectLoot = true
		if player.Character then
			player.Character:SetAttribute("SquadWiped", false)
		end
		SquadWipeStateRemote:FireClient(player, false)
	end

	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if profile then
		for _, hero in pairs(profile.Heroes) do
			hero.ComaUntilTimestamp = 0
		end
		dm.SyncProfile(player)
	end
	syncSquadStatus(player)
	broadcastMetadata(nil)
end

-- Phase 6: a floor transition no longer restores the squad. Downed heroes stand back up at a fraction of their HP
-- and standing heroes keep whatever damage they carry. (Going home still calls restoreSquadOnPlot.)
local function reviveDownedOnTransition(player: Player)
	local masterState = ActiveMasters[player]
	if not masterState then return end
	local revived = 0
	for _, h in pairs(masterState.DeployedHeroes) do
		if h.State == "COMA" or h.CurrentHP <= 0 then
			h.CurrentHP = math.max(1, math.floor(h.MaxHP * TowerHardcore.ReviveHPFraction))
			h.State = "FOLLOW_MASTER"
			ActiveHeroesByNetId[h.NetId] = h
			revived += 1
		end
	end
	masterState.IsSquadWiped = false
	masterState.CanCollectLoot = true
	if player.Character then
		player.Character:SetAttribute("SquadWiped", false)
	end
	SquadWipeStateRemote:FireClient(player, false)
	if revived > 0 then
		getDataManager().SendToast(player, string.format("%d fallen hero%s stood back up at %d%% HP.", revived, if revived == 1 then "" else "es", math.round(TowerHardcore.ReviveHPFraction * 100)), "SUCCESS")
	end
	syncSquadStatus(player)
	broadcastMetadata(nil)
end



--============================================================================
--============================================================================
-- PHYSICAL CONTESTED LOOT SYSTEM (3D MESH ASSETS & OVERHEAD HOLDING)
--============================================================================

-- [Loot Thief] marker: a character attribute for game logic plus a nameplate everyone can see.
local function applyThiefTag(player: Player)
	local char = player.Character
	if not char then return end
	local flagged = (ThiefFlagUntil[player] or 0) > os.clock()
	char:SetAttribute("IsLootThief", flagged)
	local head = char:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("LootThiefTag")
	if flagged and head and not tag then
		local bb = Instance.new("BillboardGui")
		bb.Name = "LootThiefTag"
		bb.Size = UDim2.fromOffset(150, 30)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 220
		-- Gilded Grimoire crimson plate with inked heavy type.
		local plate = Instance.new("Frame")
		plate.Size = UDim2.fromScale(1, 1)
		plate.BackgroundTransparency = 0.1
		plate.Parent = bb
		GildedGrimoire.Frame(plate, { Class = "Compact", Tone = "Crimson" })
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -12, 1, -6)
		label.Position = UDim2.fromOffset(6, 3)
		label.BackgroundTransparency = 1
		label.Text = "LOOT THIEF"
		label.TextColor3 = Color3.fromRGB(255, 150, 140)
		label.TextScaled = true
		label.ZIndex = 3
		label.Parent = plate
		GildedGrimoire.StyleText(label, "Title")
		bb.Parent = head
	elseif not flagged and tag then
		tag:Destroy()
	end
end

-- The flag lasts as long as the thief's newest open contest.
local function refreshThiefFlag(player: Player)
	local latest = 0
	for _, contest in pairs(Contests) do
		if contest.ThiefUserId == player.UserId and (contest.Status == "CONTESTED" or contest.Status == "DUELING") then
			latest = math.max(latest, contest.ExpiresAt)
		end
	end
	ThiefFlagUntil[player] = if latest > os.clock() then latest else nil
	applyThiefTag(player)
end

local function closeContestPrompt(contest: LootDuel.Contest)
	local owner = Players:GetPlayerByUserId(contest.OwnerUserId)
	if owner then
		LootContestedRemote:FireClient(owner, { Kind = "CLEAR", DropId = contest.DropId })
	end
end

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
	local allowed, denial = LootDuel.CanPickUp(loot, player.UserId)
	if not allowed then
		-- Touched fires every frame while standing on the drop; toast at most every few seconds.
		if os.clock() - (LastPickupDenial[player] or 0) > 4 then
			LastPickupDenial[player] = os.clock()
			getDataManager().SendToast(player, "🔒 " .. (denial or "You cannot pick this up."), "WARN")
		end
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
		dm.SendToast(player, "⚠️ You are already carrying loot! Drop it with [R] or unpackage it at a Floor Safe Sanctuary or Hub bank first.", "WARN")
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp or hum.Health <= 0 then
		return
	end
	if (hrp.Position - loot.Part.Position).Magnitude > 12 then return end

	Tower.GetState(player).BankArmed = true
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
		FloorId=loot.FloorId,RoomGeneration=loot.RoomGeneration,SpawnTime=loot.SpawnTime,DespawnTime=math.huge,
		Part = part,
		Weld = weld,
		LootType = lootType,
		Amount = amount,
		KillerUserId = killerUserId,
		KillerName = killerName,
		OriginalPrompt = loot.Prompt,
		Billboard = loot.Billboard,
		LockedOut = loot.LockedOut,
	}

	local g = (lootType == "GOLD" and amount or 0)
	local gm = (lootType == "GEMS" and amount or 0)
	CarriedLootSyncRemote:FireClient(player, g, gm)

	Tower.BroadcastAt(CombatVFXRemote,Tower.GetState(player),"LOOT_PICKUP",hrp.Position)

	local isStolen = LootDuel.IsTheft(killerUserId, player.UserId)
	if not isStolen then
		-- The owner took their drop back without a fight: the contest is over.
		local contest = Contests[lootId]
		if contest and contest.Status == "CONTESTED" and contest.OwnerUserId == player.UserId then
			contest.Status = "RESOLVED"
			closeContestPrompt(contest)
			local thief = Players:GetPlayerByUserId(contest.ThiefUserId)
			if thief then refreshThiefFlag(thief) end
		end
		dm.SendToast(player, string.format("🎒 Holding %d %s (-15%% Spd)! Bring it to a Floor Safe Sanctuary or Hub bank to unpackage!", amount, lootType), "INFO")
	else
		-- A re-steal replaces any older contest for this drop; the newest thief is the one challenged.
		local previous = Contests[lootId]
		if previous and previous.Status == "CONTESTED" then
			previous.Status = "EXPIRED"
			local previousThief = Players:GetPlayerByUserId(previous.ThiefUserId)
			if previousThief then refreshThiefFlag(previousThief) end
		end
		local contest = LootDuel.NewContest(lootId, killerUserId, player.UserId, os.clock())
		Contests[lootId] = contest
		refreshThiefFlag(player)

		local victimPlayer = Players:GetPlayerByUserId(killerUserId)
		if victimPlayer then
			dm.SendToast(victimPlayer, string.format("🚨 %s STOLE YOUR %d %s! Retaliate to duel for it!", player.DisplayName, amount, lootType), "WARN")
			LootContestedRemote:FireClient(victimPlayer, {
				Kind = "STOLEN", DropId = lootId, ThiefUserId = player.UserId, ThiefName = player.DisplayName,
				LootType = lootType, Amount = amount, Seconds = LootDuel.THIEF_FLAG_SECONDS,
			})
		end

		dm.SendToast(player, string.format("⚠️ You stole %s's loot! You are a [Loot Thief] — they can challenge you to a duel for it.", killerName), "WARN")
	end
end

function spawnPhysicalLoot(lootType: "GOLD" | "GEMS", amount: number, worldPos: Vector3, killerPlayer: Player?, customLabel: string?): any
	local lootId = NextLootId
	NextLootId += 1

	local part: BasePart? = nil
	local color = Color3.fromRGB(255, 205, 45)
	local icon = "Gold"

	if lootType == "GOLD" then
		part = ArtPackVisuals.Mesh("prop_bounty_bag")
		if part then
			part.Size = Vector3.new(2.4, 2.8, 1.8)
		end
		color = Color3.fromRGB(255, 205, 45)
		icon = "Gold"
	elseif lootType == "GEMS" then
		part = ArtPackVisuals.Mesh("prop_rift_tether_crystal")
		if part then
			part.Size = Vector3.new(2.4, 3.4, 2.4)
		end
		color = Color3.fromRGB(0, 230, 255)
		icon = "Gems"
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

	-- Gilded Grimoire loot plate: bronze for gold, teal for gems, with a drawn currency icon.
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 0.12
	frame.Parent = bb
	GildedGrimoire.Frame(frame, { Class = "Compact", Tone = if lootType == "GEMS" then "Teal" else "Bronze" })

	local lootIcon = GrimoireIcons.Create(icon, 34, frame, 3)
	lootIcon.AnchorPoint = Vector2.new(0, 0.5)
	lootIcon.Position = UDim2.new(0, 6, 0.5, 0)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -52, 0.54, 0)
	titleLbl.Position = UDim2.new(0, 46, 0, 3)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = string.format("%d %s", amount, if lootType == "GEMS" then "Gems" elseif lootType == "GOLD" then "Gold" else lootType)
	titleLbl.TextColor3 = color
	titleLbl.TextScaled = true
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 3
	titleLbl.Parent = frame
	GildedGrimoire.StyleText(titleLbl, "Number")

	local ownerLbl = Instance.new("TextLabel")
	ownerLbl.Size = UDim2.new(1, -52, 0.38, 0)
	ownerLbl.Position = UDim2.new(0, 46, 0.56, 0)
	ownerLbl.BackgroundTransparency = 1
	if killerPlayer then
		ownerLbl.Text = string.format("Killer: %s", killerPlayer.DisplayName)
		ownerLbl.TextColor3 = Color3.fromRGB(255, 226, 150)
	else
		ownerLbl.Text = customLabel or "Open loot · free for all"
		ownerLbl.TextColor3 = Color3.fromRGB(140, 245, 190)
	end
	ownerLbl.TextScaled = true
	ownerLbl.TextXAlignment = Enum.TextXAlignment.Left
	ownerLbl.ZIndex = 3
	ownerLbl.Parent = frame
	GildedGrimoire.StyleText(ownerLbl, "Body")

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
		DespawnTime = os.clock() + FIELD_LOOT_DESPAWN_SECONDS,
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

	task.delay(FIELD_LOOT_DESPAWN_SECONDS, function()
		if ActiveLootDrops[lootId] == lootData then
			ActiveLootDrops[lootId] = nil
			if part and part.Parent and not part:FindFirstChildOfClass("WeldConstraint") then
				part:Destroy()
			end
		end
	end)

	return lootData
end


-- 5. MOB DEATH & RELIC DROPS
--============================================================================

local function awardParticipationXP(mob: SimMob)
	local hits = ProgressionHits[mob.NetId]
	ProgressionHits[mob.NetId] = nil
	if not hits then return end
	local now = os.clock()
	local cfg = PitBalance.CombatXP
	local amount = ((mob :: any).Role == "BOSS") and cfg.Boss
		or (((mob :: any).Role == "ELITE") and cfg.Ring2 or cfg.Ring1)
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
				and hero.State ~= "COMA" and hero.CurrentHP > 0
				and (Tower.GetState(owner).SquadAssignment == mob.FloorId or now - (ProgressionActivity[owner] or -math.huge) <= cfg.ActivityWindow)
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
	mob.IsAlive = false
	awardParticipationXP(mob)
	ActiveMobsByNetId[mob.NetId] = nil
	broadcastMetadata(nil)
end

--============================================================================
-- 6. MASTER COMMAND HANDLERS ([CLICK] FOCUS, [Q] OVERDRIVE, [E] RECALL)
--============================================================================

--============================================================================
-- 6a. RETALIATION DUELS (GDD 6.1, docs/rework-plan/PHASE_3_TOWER_PVP_RETALIATION.md)
-- The drop's owner challenges the thief; both squads fight on a floating hex arena above the
-- floor while their Masters wait in place. Nobody is wiped, teleported or loses progress: heroes
-- return to their pre-duel HP afterwards, and the loser (owner or thief) is locked out of the drop.
--============================================================================

local DUEL_MOVE_SPEED = 18.0
local performHeroAttack: (simHero: SimHero, targetPos: Vector3, targetMob: SimMob?, targetEnemyHero: SimHero?, distToTarget: number, now: number, dt: number, isOverdrive: boolean) -> ()

local function duelSquad(duel: Duel, side: LootDuel.Side): DuelSquad
	return if side == "A" then duel.Sides.A else duel.Sides.B
end

local function liveDuelHeroes(squad: DuelSquad): { SimHero }
	local alive = {}
	for _, h in squad.Heroes do
		if ActiveHeroesByNetId[h.NetId] == h and h.State ~= "COMA" and h.CurrentHP > 0 then
			table.insert(alive, h)
		end
	end
	return alive
end

local function squadHpFraction(squad: DuelSquad): number
	local total = 0
	for _, h in liveDuelHeroes(squad) do
		total += h.CurrentHP / math.max(1, h.MaxHP)
	end
	return total
end

local function sendDuelState(duel: Duel, payload: { [string]: any })
	for _, side in { "A", "B" } :: { LootDuel.Side } do
		local squad = duelSquad(duel, side)
		if squad.Player.Parent == Players then
			local message = table.clone(payload)
			message.DuelId = duel.Id
			message.Side = side
			message.AliveA = #liveDuelHeroes(duel.Sides.A)
			message.AliveB = #liveDuelHeroes(duel.Sides.B)
			DuelStateRemote:FireClient(squad.Player, message)
		end
	end
end

-- Masters wait where they stand for the duel: no walking off to bank the contested drop.
local function freezeMaster(squad: DuelSquad)
	local hum = squad.Player.Character and squad.Player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	squad.Frozen = { Humanoid = hum, WalkSpeed = hum.WalkSpeed, JumpPower = hum.JumpPower, JumpHeight = hum.JumpHeight }
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
end

local function thawMaster(squad: DuelSquad)
	local frozen = squad.Frozen
	squad.Frozen = nil
	if frozen and frozen.Humanoid.Parent then
		frozen.Humanoid.WalkSpeed = frozen.WalkSpeed
		frozen.Humanoid.JumpPower = frozen.JumpPower
		frozen.Humanoid.JumpHeight = frozen.JumpHeight
	end
end

-- A contested drop either lies on the floor or rides over somebody's head.
local function findDrop(dropId: number): (any?, Player?)
	local ground = ActiveLootDrops[dropId]
	if ground then
		return ground, nil
	end
	for carrier, held in pairs(CarrierToHeldLoot) do
		if held.LootId == dropId then
			return held, carrier
		end
	end
	return nil, nil
end

local function startDuel(owner: Player, contest: LootDuel.Contest): (boolean, string?)
	local ok, reason = LootDuel.CanRetaliate(contest, owner.UserId, os.clock())
	if not ok then return false, reason end
	local thief = Players:GetPlayerByUserId(contest.ThiefUserId)
	if not thief then return false, "The thief has left the server." end
	if DuelByPlayer[owner] or DuelByPlayer[thief] then return false, "One of you is already in a duel." end
	if Tower.IsTransitioning(owner) or Tower.IsTransitioning(thief) then return false, "Wait until both Masters have finished travelling." end
	local ownerState, thiefState = Tower.GetState(owner), Tower.GetState(thief)
	if ownerState.FloorId == 0 or not Tower.Same(ownerState, thiefState) then
		return false, string.format("%s is not on your floor.", thief.DisplayName)
	end
	local record = findDrop(contest.DropId)
	if not record then return false, "The stolen drop is gone." end
	local ownerPos, thiefPos = getMasterRootPosition(owner), getMasterRootPosition(thief)
	local room = Tower.GetRoom(ownerState.FloorId)
	if not ActiveMasters[owner] or not ActiveMasters[thief] or not ownerPos or not thiefPos or not room then
		return false, "The duel cannot start right now."
	end

	local squads: { [string]: DuelSquad } = {}
	for side, player in { A = owner, B = thief } do
		local heroes = {}
		for _, h in pairs(ActiveMasters[player].DeployedHeroes) do
			if h.State ~= "COMA" and h.CurrentHP > 0 and Tower.Same(h, ownerState) then
				table.insert(heroes, h)
			end
		end
		if #heroes == 0 then
			return false, string.format("%s has no heroes standing on this floor.", if player == owner then "Your squad" else player.DisplayName)
		end
		table.sort(heroes, function(a, b) return a.SlotIndex < b.SlotIndex end)
		squads[side] = { Player = player, Heroes = heroes, Saved = {} }
	end

	-- The arena floats just under the room's ceiling bound above the owner, so it stays inside
	-- the room-local replication bounds and clear of all floor geometry.
	local margin = DuelArena.Radius() + 10
	local localPos = ownerPos - room.Origin
	local min, max = room.Bounds.Min, room.Bounds.Max
	local cx = if min.X + margin < max.X - margin then math.clamp(localPos.X, min.X + margin, max.X - margin) else (min.X + max.X) / 2
	local cz = if min.Z + margin < max.Z - margin then math.clamp(localPos.Z, min.Z + margin, max.Z - margin) else (min.Z + max.Z) / 2
	local center = room.Origin + Vector3.new(cx, max.Y - LootDuel.ARENA_LIFT, cz)
	local delta = Vector3.new(thiefPos.X - ownerPos.X, 0, thiefPos.Z - ownerPos.Z)
	local forward = if delta.Magnitude > 0.5 then delta.Unit else Vector3.new(0, 0, 1)

	local id = NextDuelId
	NextDuelId += 1
	local now = os.clock()
	local duel: Duel = {
		Id = id,
		Contest = contest,
		FloorId = ownerState.FloorId,
		Center = center,
		Forward = forward,
		Arena = DuelArena.Build(id, center, forward),
		Phase = "INTRO",
		FightAt = now + LootDuel.DUEL_INTRO_SECONDS,
		EndsAt = now + LootDuel.DUEL_INTRO_SECONDS + LootDuel.DUEL_MAX_SECONDS,
		OutroUntil = 0,
		Sides = { A = squads.A, B = squads.B },
		Winner = nil,
	}

	local duelCap = math.huge
	for _, side in { "A", "B" } :: { LootDuel.Side } do
		local sideProfile = getDataManager().GetProfile(duelSquad(duel, side).Player)
		duelCap = math.min(duelCap, StatFormulas.GetAttunementCap(sideProfile and sideProfile.MaxFloorReached))
	end

	local frame = DuelArena.Frame(center, forward)
	for _, side in { "A", "B" } :: { LootDuel.Side } do
		local squad = duelSquad(duel, side)
		local archetypes = {}
		for i, h in squad.Heroes do
			archetypes[i] = h.Archetype or "Striker"
		end
		local facing = if side == "A" then forward else -forward
		for slot, index in LootDuel.FormationOrder(archetypes) do
			local h = squad.Heroes[index]
			squad.Saved[h] = { HP = h.CurrentHP, State = h.State, Stamina = h.Stamina, BarrierHP = h.BarrierHP,
				BarrierExpires = h.BarrierExpires, AttackCount = h.AttackCount, FloorId = h.FloorId,
				ATK = h.EffectiveATK, MaxHP = h.MaxHP }
			-- Rift Attunement in a duel: both squads are held to the lower of the two Masters' caps, so a premium
			-- squad cannot simply out-power a Master who has climbed less. Restored from Saved when the duel ends.
			local tick = math.ceil(math.max(TICK_INTERVAL, h.AttackInterval) / TICK_INTERVAL - 1e-10) * TICK_INTERVAL
			local power = 10 * (h.EffectiveATK / tick) + h.MaxHP
			if power > duelCap then
				local f = duelCap / power
				h.EffectiveATK = math.max(1, math.round(h.EffectiveATK * f))
				h.MaxHP = math.max(1, math.round(h.MaxHP * f))
				h.CurrentHP = math.min(h.MaxHP, math.max(1, math.round(h.CurrentHP * f)))
			end
			HeroNavigation.Clear(h)
			h.DuelId, h.DuelSide = id, side
			h.Position = frame:PointToWorldSpace(LootDuel.SlotLocal(side, slot)) + Vector3.new(0, DuelArena.StandHeight, 0)
			h.Yaw = math.atan2(-facing.X, -facing.Z)
			h.TargetNetId = nil
			h.State = "FOLLOW_MASTER"
			h.AttackCooldown = 0.4
			h.PacifiedUntil = 0
			h.BarrierHP, h.BarrierExpires = 0, 0
			h.EntityGeneration += 1
			for _, other in pairs(ActiveHeroesByNetId) do
				if other.TargetNetId == h.NetId and other.DuelId ~= id then other.TargetNetId = nil end
			end
		end
		freezeMaster(squad)
		DuelByPlayer[squad.Player] = duel
	end

	Duels[id] = duel
	contest.Status = "DUELING"
	record.DuelLocked = true
	closeContestPrompt(contest)
	sendDuelState(duel, {
		Kind = "START",
		Center = center,
		Forward = forward,
		Radius = DuelArena.Radius(),
		NameA = owner.DisplayName,
		NameB = thief.DisplayName,
		FightAt = Workspace:GetServerTimeNow() + LootDuel.DUEL_INTRO_SECONDS,
		EndsAt = Workspace:GetServerTimeNow() + LootDuel.DUEL_INTRO_SECONDS + LootDuel.DUEL_MAX_SECONDS,
	})
	local dm = getDataManager()
	dm.SendToast(owner, string.format("⚔️ Retaliation duel against %s! Winner takes the drop.", thief.DisplayName), "WARN")
	dm.SendToast(thief, string.format("⚔️ %s challenged you to a retaliation duel for the stolen drop!", owner.DisplayName), "WARN")
	broadcastMetadata(nil)
	return true, nil
end

-- Hero-vs-hero damage inside a duel. KOs here never trigger a squad wipe.
local function duelDamage(victim: SimHero, amount: number, kind: string, overdrive: boolean)
	local duel = victim.DuelId and Duels[victim.DuelId]
	if not duel or duel.Phase ~= "FIGHT" or victim.State == "COMA" or victim.CurrentHP <= 0 then return end
	local now = os.clock()
	local damage = amount * LootDuel.DUEL_DAMAGE_SCALE
	if victim.DefenseShredUntil and now < victim.DefenseShredUntil then
		damage *= 1.20
	end
	damage = math.max(1, math.round(damage))
	local barrier = victim.BarrierHP or 0
	if barrier > 0 and (victim.BarrierExpires or 0) > now then
		local absorbed = math.min(barrier, damage)
		victim.BarrierHP = barrier - absorbed
		damage -= absorbed
	end
	local actual = math.min(victim.CurrentHP, damage)
	victim.CurrentHP = math.max(0, victim.CurrentHP - damage)
	Tower.BroadcastAt(CombatVFXRemote, victim, kind, victim.Position, actual, overdrive, true)
	if victim.CurrentHP <= 0 then
		HeroNavigation.Clear(victim)
		victim.State = "COMA"
		victim.TargetNetId = nil
		Tower.BroadcastAt(CombatVFXRemote, victim, "HERO_KO", victim.Position, victim.NetId)
		sendDuelState(duel, { Kind = "SCORE" })
	end
end

-- Duel heroes skip leash, navigation and mob acquisition: they walk straight across the flat
-- arena at the nearest standing enemy (or whoever taunted them) and fight with their own kit.
local function stepDuelHero(simHero: SimHero, dt: number, now: number)
	local duel = simHero.DuelId and Duels[simHero.DuelId]
	if not duel or duel.Phase ~= "FIGHT" or simHero.State == "COMA" then return end
	local enemies = liveDuelHeroes(duelSquad(duel, if simHero.DuelSide == "A" then "B" else "A"))
	local target: SimHero? = nil
	for _, enemy in enemies do
		if enemy.NetId == simHero.TargetNetId then target = enemy end
	end
	if not target then
		local best = math.huge
		for _, enemy in enemies do
			local d = getHorizontalDistance(simHero.Position, enemy.Position)
			if d < best then best, target = d, enemy end
		end
	end
	if not target or not Tower.Same(simHero, target) then return end
	simHero.TargetNetId = target.NetId
	local delta = target.Position - simHero.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local dist = flat.Magnitude
	if dist > 0.01 then
		simHero.Yaw = math.atan2(-flat.X, -flat.Z)
	end
	if dist > simHero.AttackRange then
		simHero.State = "MOVE_TO_TARGET"
		local step = math.min(dist - simHero.AttackRange * 0.85, DUEL_MOVE_SPEED * dt)
		simHero.Position += flat.Unit * math.max(0, step)
		return
	end
	simHero.State = "ATTACKING"
	performHeroAttack(simHero, target.Position, nil, target, dist, now, dt, false)
end

-- Skill context for a duel hero: the opposing squad stands in for the mob list.
local function duelSkillContext(simHero: SimHero, now: number): HeroSkillEffects.Context
	local duel = simHero.DuelId and Duels[simHero.DuelId]
	local enemies, allies = {}, {}
	if duel then
		for _, h in liveDuelHeroes(duelSquad(duel, if simHero.DuelSide == "A" then "B" else "A")) do
			enemies[h.NetId] = h
		end
		for _, h in duelSquad(duel, simHero.DuelSide or "A").Heroes do
			allies[h.HeroUUID] = h
		end
	end
	return {
		Mobs = enemies,
		Squad = allies,
		Now = now,
		Same = Tower.Same,
		IsCombatSafe = function(): boolean return false end,
		Broadcast = function(context: any, kind: string, position: Vector3, amount: number, overdrive: boolean, incoming: boolean)
			Tower.BroadcastAt(CombatVFXRemote, context, kind, position, amount, overdrive, incoming)
		end,
		HandleMobDeath = function() end,
		Eligible = function(target: any): boolean
			return target.DuelId == simHero.DuelId and target.State ~= "COMA" and target.CurrentHP > 0
		end,
		Damage = function(target: any, amount: number)
			duelDamage(target, amount, "HIT_SPARK", false)
		end,
	}
end

-- Hands the drop to the duel's winner. The loser is locked out of it for good (LootDuel.Resolve),
-- whether they were the owner or the thief. The drop is set at the winner's feet and picked up
-- for them when their hands are free.
local function applyDuelOutcome(duel: Duel)
	local contest = duel.Contest
	local winner = duelSquad(duel, duel.Winner or "B").Player
	local loser = duelSquad(duel, if duel.Winner == "A" then "B" else "A").Player
	local record, carrier = findDrop(contest.DropId)
	LootDuel.Resolve(contest, record, winner.UserId)
	if record then
		record.KillerName = winner.DisplayName
	end
	local winnerState = Tower.GetState(winner)
	if record and winner.Parent == Players and Tower.Same(record, winnerState) then
		if carrier and carrier ~= winner and Tower.Same(Tower.GetState(carrier), winnerState) then
			CombatSimulation.DropCarriedLoot(carrier)
		end
		local ground = ActiveLootDrops[contest.DropId]
		local root = winner.Character and winner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if ground and ground.Part and root then
			ground.PickupBlockedUserId = nil
			ground.Part.Position = Tower.GroundDrop(ground, root.Position + root.CFrame.LookVector * 4, ground.Part.Size.Y / 2)
			collectPhysicalLoot(winner, contest.DropId)
		end
	end

	local dm = getDataManager()
	local ownerLost = loser.UserId == contest.OwnerUserId
	if winner.Parent == Players then
		dm.SendToast(winner, string.format("🏆 You won the duel against %s! The contested drop is yours.", loser.DisplayName), "SUCCESS")
	end
	if loser.Parent == Players then
		dm.SendToast(loser, if ownerLost
			then string.format("💀 You lost the duel. %s keeps the drop and you are locked out of it.", winner.DisplayName)
			else string.format("💀 You lost the duel. %s takes the drop back and you are locked out of it.", winner.DisplayName), "WARN")
	end
	local thief = Players:GetPlayerByUserId(contest.ThiefUserId)
	if thief then refreshThiefFlag(thief) end
	closeContestPrompt(contest)
end

-- Ends the duel: squads go back to their Masters at pre-duel HP, the arena is removed and the
-- drop changes hands.
local function finishDuel(duel: Duel)
	if Duels[duel.Id] ~= duel then return end
	Duels[duel.Id] = nil
	local now = os.clock()
	local dm = getDataManager()
	for _, side in { "A", "B" } :: { LootDuel.Side } do
		local squad = duelSquad(duel, side)
		if DuelByPlayer[squad.Player] == duel then DuelByPlayer[squad.Player] = nil end
		thawMaster(squad)
		local profile = dm.GetProfile(squad.Player)
		local masterState = Tower.GetState(squad.Player)
		local root = getMasterRootPosition(squad.Player)
		for _, h in squad.Heroes do
			if h.DuelId ~= duel.Id then continue end
			h.DuelId, h.DuelSide = nil, nil
			HeroNavigation.Clear(h)
			local saved = squad.Saved[h]
			if saved then
				h.EffectiveATK, h.MaxHP = saved.ATK, saved.MaxHP -- undo the duel's attunement clamp
			end
			if saved and h.FloorId == saved.FloorId then
				h.CurrentHP = math.min(saved.HP, h.MaxHP)
				h.State = saved.State
				h.Stamina = saved.Stamina
				h.BarrierHP, h.BarrierExpires = saved.BarrierHP, saved.BarrierExpires
				h.AttackCount = saved.AttackCount
				if profile and profile.Heroes[h.HeroUUID] then
					profile.Heroes[h.HeroUUID].CurrentStamina = h.Stamina
				end
			end
			if h.State ~= "COMA" then h.State = "FOLLOW_MASTER" end
			local room = Tower.GetRoom(h.FloorId)
			if root and Tower.Same(h, masterState) then
				h.Position = HeroNavigation.PlaceNear(root, getFormationOffset(h.SlotIndex))
			elseif room then
				h.Position = room.Arrival.Position - Vector3.new(0, 3.5, 0)
			end
			h.TargetNetId = nil
			h.PacifiedUntil = now + 1.5
			h.EntityGeneration += 1
		end
	end
	duel.Arena:Destroy()
	applyDuelOutcome(duel)
	sendDuelState(duel, { Kind = "CLEAR" })
	for _, side in { "A", "B" } :: { LootDuel.Side } do
		local player = duelSquad(duel, side).Player
		if player.Parent == Players then syncSquadStatus(player) end
	end
	broadcastMetadata(nil)
end

local function concludeDuel(duel: Duel, winner: LootDuel.Side, reason: string)
	duel.Winner = winner
	duel.Phase = "OUTRO"
	duel.OutroUntil = os.clock() + LootDuel.DUEL_OUTRO_SECONDS
	for _, side in { "A", "B" } :: { LootDuel.Side } do
		for _, h in duelSquad(duel, side).Heroes do
			h.TargetNetId = nil
			if h.State ~= "COMA" then h.State = "FOLLOW_MASTER" end
		end
	end
	sendDuelState(duel, {
		Kind = "END",
		Winner = winner,
		Reason = reason,
		WinnerName = duelSquad(duel, winner).Player.DisplayName,
		OwnerWon = winner == "A",
		OutroSeconds = LootDuel.DUEL_OUTRO_SECONDS,
	})
end

local function duelForfeit(duel: Duel, side: LootDuel.Side): boolean
	local player = duelSquad(duel, side).Player
	return player.Parent ~= Players or Tower.IsTransitioning(player) or Tower.GetState(player).FloorId ~= duel.FloorId
end

local function stepDuels(now: number)
	for _, duel in pairs(Duels) do
		if duel.Phase == "OUTRO" then
			if now >= duel.OutroUntil then finishDuel(duel) end
			continue
		end
		local forfeitA, forfeitB = duelForfeit(duel, "A"), duelForfeit(duel, "B")
		if forfeitA or forfeitB then
			-- Someone left or travelled: no outro, the remaining Master wins at once.
			duel.Winner = if forfeitA then "B" else "A"
			finishDuel(duel)
		elseif duel.Phase == "INTRO" then
			if now >= duel.FightAt then
				duel.Phase = "FIGHT"
				sendDuelState(duel, { Kind = "FIGHT" })
			end
		else
			local a, b = duel.Sides.A, duel.Sides.B
			local timedOut = now >= duel.EndsAt
			local winner = LootDuel.DecideWinner(#liveDuelHeroes(a), #liveDuelHeroes(b), squadHpFraction(a), squadHpFraction(b), timedOut)
			if winner then
				concludeDuel(duel, winner, if timedOut then "TIMEOUT" else "KNOCKOUT")
			end
		end
	end
end

-- Open contests close when their window runs out or the drop is banked or despawns.
local function stepContests(now: number)
	for dropId, contest in pairs(Contests) do
		if contest.Status == "DUELING" then continue end
		local alive = findDrop(dropId) ~= nil
		if contest.Status == "CONTESTED" and (now >= contest.ExpiresAt or not alive) then
			contest.Status = "EXPIRED"
			closeContestPrompt(contest)
			local thief = Players:GetPlayerByUserId(contest.ThiefUserId)
			if thief then refreshThiefFlag(thief) end
		end
		if contest.Status ~= "CONTESTED" and not alive then
			Contests[dropId] = nil
		end
	end
	for player, untilClock in pairs(ThiefFlagUntil) do
		if now >= untilClock then refreshThiefFlag(player) end
	end
end

local function requestRetaliation(player: Player, contest: LootDuel.Contest?, thiefName: string?)
	local now = os.clock()
	if now - (LastRetaliationRequest[player] or -math.huge) < LootDuel.RETALIATE_COOLDOWN then return end
	LastRetaliationRequest[player] = now
	if not contest then
		getDataManager().SendToast(player, string.format("%s has not stolen from you.", thiefName or "That player"), "WARN")
		return
	end
	local ok, reason = startDuel(player, contest)
	if not ok then
		getDataManager().SendToast(player, reason or "The duel cannot start right now.", "WARN")
	end
end

InitiateRetaliationRemote.OnServerEvent:Connect(function(player: Player, dropId: any)
	if not Protocol.Integer(dropId, 1, NextLootId) then return end
	requestRetaliation(player, Contests[dropId])
end)

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

	-- 1. Resolve an enemy Master passed as optThiefUserId
	local targetPlayer: Player? = nil
	if Protocol.Integer(optThiefUserId, 1, 2^53) then
		targetPlayer = Players:GetPlayerByUserId(optThiefUserId)
	end

	-- 2. If targetNetId is an enemy hero, resolve enemy player
	if not targetPlayer and type(targetNetId) == "number" then
		local hitHero = ActiveHeroesByNetId[targetNetId]
		if hitHero and hitHero.Owner ~= player then
			targetPlayer = hitHero.Owner
		end
	end

	-- 3. Clicking a thief (or their hero) challenges them to a duel for their newest steal from you.
	-- Squads never fight in the open field; PvP only happens inside a retaliation duel.
	if targetPlayer and targetPlayer ~= player then
		if DuelByPlayer[player] then return end
		local chosen: LootDuel.Contest? = nil
		for _, contest in pairs(Contests) do
			if contest.OwnerUserId == player.UserId and contest.ThiefUserId == targetPlayer.UserId and contest.Status == "CONTESTED"
				and (not chosen or contest.ExpiresAt > chosen.ExpiresAt) then
				chosen = contest
			end
		end
		requestRetaliation(player, chosen, targetPlayer.DisplayName)
		return
	end
	if DuelByPlayer[player] then return end

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
		-- [Q] OVERDRIVE WHISTLE (20s CD, +40% Attack Speed for 5s to accelerate Skill Charge building)
		if (now - masterState.LastOverdriveClock) < OVERDRIVE_COOLDOWN then
			return
		end
		masterState.LastOverdriveClock = now
		ProgressionActivity[player] = now

		local profile = dm.GetProfile(player)
		for uuid, simHero in pairs(masterState.DeployedHeroes) do
			if simHero.State ~= "COMA" and simHero.CurrentHP > 0 then
				simHero.OverdriveUntil = now + OVERDRIVE_DURATION
				if profile and profile.Heroes[uuid] then
					profile.Heroes[uuid].CurrentStamina = simHero.Stamina
				end
			end
		end
		Tower.BroadcastAt(CombatVFXRemote,Tower.GetState(player),"WHISTLE_Q",masterPos)
		dm.SyncProfile(player)

	elseif commandCode == 2 then
		if DuelByPlayer[player] then return end
		Tower.Recall(player)
	end
end)

if FloorProgressRemote then
	FloorProgressRemote.OnServerEvent:Connect(function(player: Player)
		local progress = ActivePlayerProgress[player]
		if progress then
			FloorProgressRemote:FireClient(player, progress)
		else
			local state = Tower.GetState(player)
			if state and state.FloorId and state.FloorId > 0 then
				local newProg = TowerProgress.CreateProgress(state.FloorId)
				ActivePlayerProgress[player] = newProg
				FloorProgressRemote:FireClient(player, newProg)
			end
		end
	end)
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
	end
	-- Outside duels heroes only ever fight mobs (stepDuelHero handles hero-vs-hero).
	return nil, nil, nil
end

-- A hero attack scheduled by stepHeroSimulation is cancelled if, by its release frame, the
-- hero has fallen, left the room, been recalled or lost its owner. After release it lands.
local function canReleaseHeroImpact(impact: any): boolean
	local simHero: SimHero = impact.Attacker
	return ActiveHeroesByNetId[simHero.NetId] == simHero
		and simHero.State ~= "COMA"
		and simHero.EntityGeneration == impact.AttackerGeneration
		and Tower.Same(simHero, impact)
		and simHero.PacifiedUntil <= impact.ReleaseAt
		and simHero.Owner.Parent ~= nil
end

local function heroSkillContext(simHero: SimHero, now: number): HeroSkillEffects.Context
	if simHero.DuelId then
		return duelSkillContext(simHero, now)
	end
	local masterState = ActiveMasters[simHero.Owner]
	return {
		Mobs = ActiveMobsByNetId,
		Squad = masterState and masterState.DeployedHeroes,
		Now = now,
		Same = Tower.Same,
		IsCombatSafe = function(entity: any): boolean
			return Tower.GetSafety(entity, entity.Position).CombatSafe == true
		end,
		Broadcast = function(context: any, kind: string, position: Vector3, amount: number, overdrive: boolean, incoming: boolean)
			Tower.BroadcastAt(CombatVFXRemote, context, kind, position, amount, overdrive, incoming)
		end,
		HandleMobDeath = function(mob: any, killer: Player)
			handleMobDeath(mob, killer)
		end,
	}
end

-- Lands one tick of a hero attack (HeroImpactQueue). Basic and Special fizzle when their target
-- is gone; a Skill's area effects still land around the aim point.
local function resolveHeroImpact(impact: any, tick: number)
	local simHero: SimHero = impact.Attacker
	if simHero.Owner.Parent == nil then
		return
	end
	local now = os.clock()
	local mob: SimMob? = impact.TargetMob
	if mob and not (mob.IsAlive and mob.EntityGeneration == impact.TargetGeneration and Tower.Same(impact, mob) and not Tower.GetSafety(mob, mob.Position).CombatSafe) then
		mob = nil
	end
	-- Hero targets only exist inside a duel, and only an opponent in that same duel counts.
	local enemyHero: SimHero? = impact.TargetHero
	if enemyHero and not (simHero.DuelId ~= nil and enemyHero.DuelId == simHero.DuelId and enemyHero.State ~= "COMA" and enemyHero.CurrentHP > 0 and enemyHero.EntityGeneration == impact.TargetGeneration and Tower.Same(impact, enemyHero)) then
		enemyHero = nil
	end
	if not mob and not enemyHero and impact.Tier ~= "SKILL" then
		return
	end

	local livePos = if mob then mob.Position elseif enemyHero then enemyHero.Position else impact.Aim
	local bonus = HeroSkillEffects.Resolve(heroSkillContext(simHero, now), {
		Impact = impact,
		Attacker = simHero,
		Profile = impact.Profile,
		Tier = impact.Tier,
		Tick = tick,
		Primary = mob or enemyHero,
		Center = if impact.Tier == "SKILL" then impact.Aim else livePos,
	})
	local damage = math.round(impact.Atk * impact.DamageMult * bonus / impact.Ticks)
	local hitKind = if impact.Tier == "SKILL" then "HIT_SKILL" elseif impact.Tier == "SPECIAL" then "HIT_SPECIAL" else "HIT_SPARK"

	if mob then
		if mob.DefenseShredUntil and now < mob.DefenseShredUntil then
			damage = math.round(damage * 1.20)
		end
		local actualDamage = math.min(mob.CurrentHP, damage)
		local participation = ProgressionHits[mob.NetId]
		if not participation then
			participation = {}
			ProgressionHits[mob.NetId] = participation
		end
		local previous = participation[simHero.NetId]
		participation[simHero.NetId] = { Damage = (previous and previous.Damage or 0) + actualDamage, At = now, Owner=simHero.Owner, HeroUUID=simHero.HeroUUID, FloorId=impact.FloorId, RoomGeneration=impact.RoomGeneration, EntityGeneration=impact.AttackerGeneration }
		mob.CurrentHP = math.max(0, mob.CurrentHP - damage)
		mob.DamageLedger[simHero.Owner.UserId] = (mob.DamageLedger[simHero.Owner.UserId] or 0) + damage

		Tower.BroadcastAt(CombatVFXRemote,mob,hitKind, mob.Position, actualDamage, impact.Overdrive,false)
		if (mob :: any).TowerEnemy then
			CombatLifecycleRevision+=1
			Tower.BroadcastAt(TowerRemotes.TowerAction,mob,{Kind="HIT",Actor=AttackTimeline.Identity(mob),LifecycleRevision=CombatLifecycleRevision,StartServerTime=Workspace:GetServerTimeNow()})
		end

		if mob.CurrentHP <= 0 then
			if simHero.TargetNetId == mob.NetId then
				simHero.TargetNetId = nil
				simHero.State = "FOLLOW_MASTER"
			end
			handleMobDeath(mob, simHero.Owner)
		end
	elseif enemyHero then
		duelDamage(enemyHero, damage, hitKind, impact.Overdrive)
	end
end

-- One swing decision for a hero in range of its target: Basic/Basic/Special cadence, Skill on a
-- full gauge, cosmetic cue now and damage at the impact frame (HeroImpactQueue). Shared by the
-- PvE state machine and duel heroes.
performHeroAttack = function(simHero: SimHero, targetPos: Vector3, targetMob: SimMob?, targetEnemyHero: SimHero?, distToTarget: number, now: number, dt: number, isOverdrive: boolean)
	local profile = getDataManager().GetProfile(simHero.Owner)
	local effectiveInterval = simHero.AttackInterval / (isOverdrive and OVERDRIVE_ATK_SPEED_MULT or 1.0)
	simHero.AttackCooldown -= dt
	if simHero.AttackCooldown <= 0 then
		simHero.AttackCooldown = effectiveInterval

		local skillProfile = ArchetypeCombatSkills.GetSkillProfile(simHero.TemplateId, simHero.Archetype)
		local isSkillReady = (simHero.Stamina or 0) >= ArchetypeCombatSkills.Constants.MAX_STAMINA

		local attackType: "BASIC" | "SPECIAL" | "SKILL" = "BASIC"
		if isSkillReady then
			attackType = "SKILL"
		elseif ((simHero.AttackCount or 0) + 1) % skillProfile.Special.Cadence == 0 then
			attackType = "SPECIAL"
		end
		local tierDef: any = if attackType == "SKILL" then skillProfile.Skill elseif attackType == "SPECIAL" then skillProfile.Special else skillProfile.Basic

		-- The gauge moves on the decision so the Basic/Basic/Special cadence stays fixed;
		-- the damage itself waits for the impact (resolveHeroImpact).
		if attackType == "SKILL" then
			simHero.Stamina = 0
		else
			simHero.AttackCount = (simHero.AttackCount or 0) + 1
			simHero.Stamina = math.clamp((simHero.Stamina or 0) + tierDef.StaminaGain, 0, 100)
		end
		if profile and profile.Heroes[simHero.HeroUUID] then
			profile.Heroes[simHero.HeroUUID].CurrentStamina = simHero.Stamina
		end

		local timing = HeroActionTiming.For(simHero.TemplateId, simHero.EquippedArtifactType, attackType, tierDef, effectiveInterval, distToTarget)
		if attackType == "SKILL" then
			-- Ultimates hold the hero for their whole cast so the animation reads.
			simHero.AttackCooldown = math.max(effectiveInterval, timing.CastSeconds)
		end
		local ticks, tickSeconds = HeroActionTiming.Ticks(tierDef)
		local target: any = targetMob or targetEnemyHero

		-- Cosmetic cue: clients play the tier's clip over the cast time and time the effect to
		-- the same release and travel the impact queue uses (TowerProtocol.EncodeHeroCue).
		Tower.BroadcastAt(CombatVFXRemote, simHero, "HERO_CUE", Protocol.EncodeHeroCue({
			Tier = if attackType == "SKILL" then 3 elseif attackType == "SPECIAL" then 2 else 1,
			Overdrive = isOverdrive,
			NetId = simHero.NetId,
			EntityGeneration = simHero.EntityGeneration,
			TargetNetId = target and target.NetId,
			CastSeconds = timing.CastSeconds,
			ReleaseSeconds = timing.ReleaseSeconds,
			TravelSeconds = timing.TravelSeconds,
			StartServerTime = Workspace:GetServerTimeNow(),
			Aim = targetPos,
		}))

		HeroImpacts:Push({
			ReleaseAt = now + timing.ReleaseSeconds,
			At = now + timing.ImpactSeconds,
			Ticks = ticks,
			TickSeconds = tickSeconds,
			Tick = 0,
			Released = false,
			Attacker = simHero,
			AttackerGeneration = simHero.EntityGeneration,
			FloorId = simHero.FloorId,
			RoomGeneration = simHero.RoomGeneration,
			Tier = attackType,
			Profile = skillProfile,
			Atk = simHero.EffectiveATK,
			DamageMult = tierDef.DamageMultiplier,
			Overdrive = isOverdrive,
			Origin = simHero.Position,
			Aim = targetPos,
			TargetMob = targetMob,
			TargetHero = targetEnemyHero,
			TargetGeneration = target and target.EntityGeneration,
		})
	end
end

local function stepHeroSimulation(simHero: SimHero, dt: number, now: number)
	if simHero.DuelId then
		stepDuelHero(simHero, dt, now)
		return
	end
	if simHero.State == "COMA" then
		return
	end
	local squadState = Tower.GetState(simHero.Owner)
	local assignedRoom = squadState.SquadAssignment and Tower.GetRoom(squadState.SquadFloorId)
	local masterState = ActiveMasters[simHero.Owner]
	local masterPos = if assignedRoom
		then getAssignedFloorAnchor(squadState.SquadFloorId, assignedRoom, masterState)
		else (getMasterGroundPosition(simHero.Owner) or (masterState and getMasterRootPosition(simHero.Owner)))
	if not masterPos then
		return
	end

	-- Jump imitation: when the player jumps, squadmates perform a coordinated jump arc
	if not assignedRoom and isPlayerJumping(simHero.Owner) and simHero.State ~= "COMA" then
		if not simHero.JumpEnd or now >= simHero.JumpEnd then
			simHero.JumpStart = now + (simHero.SlotIndex - 1) * 0.05
			simHero.JumpDuration = 0.65
			simHero.JumpHeight = 4.8
			simHero.JumpEnd = simHero.JumpStart + simHero.JumpDuration
			simHero.GroundBaseY = simHero.Position.Y
		end
	end

	local dm = getDataManager()
	local profile = dm.GetProfile(simHero.Owner)
	if profile and profile.Heroes[simHero.HeroUUID] then
		local currentHero = profile.Heroes[simHero.HeroUUID]
		local trainingMult = attunedMultiplier(simHero.Owner, profile, currentHero, StatFormulas.GetEquippedArtifact(profile,currentHero))
		local effATK, effHP, _, interval = StatFormulas.GetEffectiveCombatStats(currentHero, false, false, StatFormulas.GetEquippedArtifact(profile,currentHero), trainingMult)
		simHero.AttackInterval = interval
		simHero.CurrentHP = math.min(simHero.CurrentHP,effHP)
		simHero.EffectiveATK = effATK
		simHero.MaxHP = effHP
	end

	local masterState = ActiveMasters[simHero.Owner]
	local maxLeash = assignedRoom and FirstBiome.LeashRange or (masterState and masterState.TargetEnemyUserId ~= nil) and 150.0 or LEASH_DISTANCE
	if getHorizontalDistance(simHero.Position, masterPos) > maxLeash or math.abs(simHero.Position.Y - masterPos.Y) > 40 then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

 local isPacified = now < simHero.PacifiedUntil or Tower.GetSafety(simHero,simHero.Position).CombatSafe==true
	if isPacified then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

	-- Hero movement speed is fixed to the player's Humanoid WalkSpeed (16 normal, 48 sprint, or relic penalties)
	local ownerChar = simHero.Owner.Character
	local ownerHum = ownerChar and ownerChar:FindFirstChildOfClass("Humanoid")
	local playerSpeed = if assignedRoom then 16.0 elseif ownerHum then ownerHum.WalkSpeed else 16.0
	simHero.MoveSpeed = playerSpeed
	local isOverdrive = now < simHero.OverdriveUntil
	local currentMoveSpeed = playerSpeed * (isOverdrive and 1.20 or 1.0)

	local targetPos, targetMob, targetEnemyHero = resolveTargetPositionAndAlive(simHero)
	if targetMob then
		local distMasterToMob = getHorizontalDistance(masterPos, targetMob.Position)
		local distHeroToMaster = getHorizontalDistance(simHero.Position, masterPos)
		-- Master must be within enemy radius (30.0 studs) for heroes to fight; if master moves away, disengage immediately.
		-- For assigned squads, heroes roam the floor up to maxLeash.
		if not assignedRoom and (distMasterToMob > 30.0 or distHeroToMaster > 35.0) then
			simHero.TargetNetId = nil
			simHero.State = "FOLLOW_MASTER"
			targetPos, targetMob, targetEnemyHero = nil, nil, nil
		elseif assignedRoom and distMasterToMob > maxLeash then
			simHero.TargetNetId = nil
			simHero.State = "FOLLOW_MASTER"
			targetPos, targetMob, targetEnemyHero = nil, nil, nil
		end
	end

	if not targetPos and not isPacified then
		-- For assigned squads, assist squadmates that already have an active target
		if assignedRoom and masterState then
			for _, ally in pairs(masterState.DeployedHeroes) do
				if ally.TargetNetId and ActiveMobsByNetId[ally.TargetNetId] and ActiveMobsByNetId[ally.TargetNetId].IsAlive then
					simHero.TargetNetId = ally.TargetNetId
					targetPos, targetMob, targetEnemyHero = resolveTargetPositionAndAlive(simHero)
					if targetPos then
						simHero.State = "MOVE_TO_TARGET"
						break
					end
				end
			end
		end

		if not targetPos then
			local combatRadius = if assignedRoom then maxLeash else 28.0
			local nearestDist = combatRadius
			local nearestMobId: number? = nil
			for netId, mob in pairs(ActiveMobsByNetId) do
				if mob.IsAlive and Tower.Same(simHero,mob) and not Tower.GetSafety(mob,mob.Position).CombatSafe then
					if math.abs(mob.Position.Y - simHero.Position.Y) < 30 and (not assignedRoom or math.abs(mob.Position.Y - masterPos.Y) < 35) then
						local d = if assignedRoom then getHorizontalDistance(simHero.Position, mob.Position) else getHorizontalDistance(masterPos, mob.Position)
						if d <= nearestDist then
							nearestDist = d
							nearestMobId = netId
						end
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
	end

	if simHero.State == "FOLLOW_MASTER" or not targetPos then
		local formation = getFormationOffset(simHero.SlotIndex)
		local distToMaster = (masterPos - simHero.Position).Magnitude
		-- When catching up from far away, tighten formation offset so squadmates file through gates and bridges cleanly
		local targetOffset = if distToMaster > 18 then formation * math.clamp(18 / distToMaster, 0.25, 1.0) else formation
		local goalPos = HeroNavigation.PlaceNear(masterPos, targetOffset)
		local distToGoal = (goalPos - simHero.Position).Magnitude
		if distToGoal > .5 then
			-- Hero speed is fixed to player speed with a bounded trailing catch-up
			local followSpeed = currentMoveSpeed
			if distToGoal > 8.0 then
				local catchUp = math.clamp((distToGoal - 8.0) / 24.0, 0, 0.35)
				followSpeed = currentMoveSpeed * (1.0 + catchUp)
			end

			-- Anti-stuck progress tracker: if hero fails to make progress toward master for > 1.5s or is > 55 studs away, recover immediately
			local tracker = HeroStuckTracking[simHero.NetId]
			if not tracker then
				tracker = { LastDist = distToGoal, LastClock = now }
				HeroStuckTracking[simHero.NetId] = tracker
			end

			local isStuck = (now - tracker.LastClock > 1.5) and (tracker.LastDist - distToGoal < 1.0)
			local isTooFar = distToGoal > 55.0 or math.abs(simHero.Position.Y - masterPos.Y) > 28.0

			if isTooFar or isStuck then
				simHero.Position = HeroNavigation.PlaceNear(masterPos, targetOffset)
				HeroNavigation.Clear(simHero)
				tracker.LastDist = 0
				tracker.LastClock = now
			else
				if tracker.LastDist - distToGoal > 1.0 then
					tracker.LastDist = distToGoal
					tracker.LastClock = now
				elseif distToGoal > tracker.LastDist + 2.0 then
					tracker.LastDist = distToGoal
				end
				HeroNavigation.Step(simHero, goalPos, followSpeed * dt, now)
			end
		end

		-- Apply jump arc if jumping
		if simHero.JumpStart and now >= simHero.JumpStart and now < simHero.JumpEnd then
			local jumpP = (now - simHero.JumpStart) / simHero.JumpDuration
			local jumpArc = 4 * (simHero.JumpHeight or 4.8) * jumpP * (1 - jumpP)
			simHero.Position = Vector3.new(simHero.Position.X, (simHero.GroundBaseY or simHero.Position.Y) + jumpArc, simHero.Position.Z)
		else
			simHero.GroundBaseY = simHero.Position.Y
			simHero.JumpStart = nil
			simHero.JumpEnd = nil
		end
		return
	end

	local distToTarget = (simHero.Position - targetPos).Magnitude
	if distToTarget > simHero.AttackRange or not HeroNavigation.CanAttack(simHero.Position, targetPos) then
		simHero.State = "MOVE_TO_TARGET"
		local stepDist = math.min(math.max(.5, distToTarget - simHero.AttackRange * .85), currentMoveSpeed * dt)
		HeroNavigation.Step(simHero, targetPos, stepDist, now)

		-- Apply jump arc if jumping while moving
		if simHero.JumpStart and now >= simHero.JumpStart and now < simHero.JumpEnd then
			local jumpP = (now - simHero.JumpStart) / simHero.JumpDuration
			local jumpArc = 4 * (simHero.JumpHeight or 4.8) * jumpP * (1 - jumpP)
			simHero.Position = Vector3.new(simHero.Position.X, (simHero.GroundBaseY or simHero.Position.Y) + jumpArc, simHero.Position.Z)
		else
			simHero.GroundBaseY = simHero.Position.Y
			simHero.JumpStart = nil
			simHero.JumpEnd = nil
		end
	else
		simHero.State = "ATTACKING"
		local delta = targetPos - simHero.Position
		if delta.Magnitude > 0.01 then
			simHero.Yaw = math.atan2(-delta.X, -delta.Z)
		end

		performHeroAttack(simHero, targetPos, targetMob, targetEnemyHero, distToTarget, now, dt, isOverdrive)
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
  entry.Flags=hero and (1+(now<e.OverdriveUntil and 2 or 0)+(now<e.PacifiedUntil and 4 or 0)) or 0
  byFloor[e.FloorId]=byFloor[e.FloorId] or {};table.insert(byFloor[e.FloorId],entry)
 end end
 for _,p in Players:GetPlayers() do
  local c=Tower.Context(p)
  for _,packet in Protocol.Encode(c,byFloor[c.FloorId] or {},SnapshotSequence,Workspace:GetServerTimeNow()) do TowerRemotes.TowerSnapshot:FireClient(p,packet) end
 end
end
-- Summons (or joins) the floor boss for a player whose own kill threshold is met. At most one boss is alive per floor.
local function summonFloorBoss(player: Player, progress: TowerProgress.PlayerFloorProgress)
 if not Encounters then return end
 local floorId = progress.FloorId
 local existing = Encounters:GetActiveBoss(floorId)
 local bossMob = existing or Encounters:SpawnBoss(floorId, player)
 -- If the room is not ready, leave the summon armed so the next kill retries it.
 progress.BossSpawned = bossMob ~= nil
 progress.BossNetId = bossMob and bossMob.NetId or nil
 if FloorProgressRemote then FloorProgressRemote:FireClient(player, progress) end
 local dm = getDataManager()
 if existing then
  dm.SendToast(player, string.format("Floor %d Boss is already awake! Defeat it to unlock Floor %d!", floorId, floorId + 1), "WARN")
 elseif bossMob then
  dm.SendToast(player, string.format("Floor %d Boss Summoned! Defeat it to unlock Floor %d!", floorId, floorId + 1), "WARN")
 end
end

local function spawnFloorAscensionPortal(floorId: number, position: Vector3)
	local room = Tower.GetRoom(floorId)
	if not room or not room.Model then return end
	if room.Model:FindFirstChild("FloorAscensionPortal") then return end

	local nextFloorId = floorId + 1
	local isMaxFloor = floorId >= 50
	local groundPos = HeroNavigation.Ground(position, nil, 4, 30) or position

	local portalModel = Instance.new("Model")
	portalModel.Name = "FloorAscensionPortal"

	-- Stone base plinth
	local plinth = Instance.new("Part")
	plinth.Name = "PortalPlinth"
	plinth.Size = Vector3.new(12, 1.2, 12)
	plinth.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.6, 0))
	plinth.Anchored = true
	plinth.CanCollide = true
	plinth.Material = Enum.Material.Slate
	plinth.Color = Color3.fromRGB(34, 28, 48)
	plinth.Parent = portalModel

	-- Glowing outer arch
	local arch = Instance.new("Part")
	arch.Name = "PortalArch"
	arch.Shape = Enum.PartType.Cylinder
	arch.Size = Vector3.new(0.8, 11, 11)
	arch.CFrame = CFrame.new(groundPos + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	arch.Anchored = true
	arch.CanCollide = false
	arch.Material = Enum.Material.Neon
	arch.Color = Color3.fromRGB(80, 215, 255)
	arch.Parent = portalModel

	-- Glowing inner vortex
	local vortex = Instance.new("Part")
	vortex.Name = "PortalVortex"
	vortex.Shape = Enum.PartType.Cylinder
	vortex.Size = Vector3.new(0.4, 9.2, 9.2)
	vortex.CFrame = CFrame.new(groundPos + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	vortex.Anchored = true
	vortex.CanCollide = false
	vortex.Transparency = 0.25
	vortex.Material = Enum.Material.Neon
	vortex.Color = Color3.fromRGB(50, 160, 255)
	vortex.Parent = portalModel

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(100, 220, 255)
	light.Range = 24
	light.Brightness = 2.8
	light.Parent = vortex

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 120, 255)),
	})
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Rate = 28
	pe.Speed = NumberRange.new(2, 6)
	pe.Lifetime = NumberRange.new(0.8, 1.8)
	pe.Parent = vortex

	-- Interaction trigger
	local trigger = Instance.new("Part")
	trigger.Name = "PortalTrigger"
	trigger.Size = Vector3.new(8, 10, 8)
	trigger.CFrame = CFrame.new(groundPos + Vector3.new(0, 5.5, 0))
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Parent = portalModel
	portalModel.PrimaryPart = trigger

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AscendPrompt"
	prompt.ActionText = if isMaxFloor then "Return to Hub" else string.format("Ascend to Floor %d", nextFloorId)
	prompt.ObjectText = "Floor Portal"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	local portalDebounce: { [Player]: number } = {}
	local function activatePortal(player: Player)
		local now = os.clock()
		if (portalDebounce[player] or 0) > now then return end
		portalDebounce[player] = now + 4.0

		local pState = Tower.GetState(player)
		if not pState or pState.FloorId ~= floorId then return end
		if Tower.IsTransitioning(player) then return end
		-- Only a Master who has cleared this floor may ascend (the prompt is shared by everyone in the room).
		local portalProfile = getDataManager().GetProfile(player)
		if not portalProfile or (portalProfile.HighestClearedFloor or 0) < floorId then
			getDataManager().SendToast(player, "Defeat this floor's boss yourself to ascend.", "WARN")
			return
		end

		if isMaxFloor then
			Tower.ReturnToHub(player, {
				ContractVersion = 1,
				RequestId = HttpService:GenerateGUID(false),
				CharacterGeneration = pState.CharacterGeneration,
				ExpectedLocationRevision = pState.LocationRevision,
				ExpectedSquadRevision = pState.SquadRevision,
			})
		else
			Tower.VisitFloor(player, nextFloorId, {
				ContractVersion = 1,
				RequestId = HttpService:GenerateGUID(false),
				CharacterGeneration = pState.CharacterGeneration,
				ExpectedLocationRevision = pState.LocationRevision,
				ExpectedSquadRevision = pState.SquadRevision,
			})
		end
	end

	-- Phase 6 M5: the portal is prompt-only. Walking through it no longer teleports you by accident.
	prompt.Triggered:Connect(activatePortal)

	portalModel.Parent = room.Model
end
local function squadCount(player: Player): number
 local state=ActiveMasters[player];local n=0
 if state then for _,h in pairs(state.DeployedHeroes) do if h.CurrentHP>0 and h.State~="COMA" then n+=1 end end end
 return n
end
Tower.RegisterAdapter("Combat",{
 Count=squadCount,
 -- Phase 6 boss lock: true while a summoned boss this Master has damaged is alive and the squad has not wiped.
 BossLocked=function(player,floorId)
  local boss=Encounters and Encounters:GetActiveBoss(floorId)
  if not boss then return false end
  if ((boss.DamageLedger and boss.DamageLedger[player.UserId]) or 0)<=0 then return false end
  local m=ActiveMasters[player]
  return m~=nil and not m.IsSquadWiped
 end,
 ValidateRoster=function(player)
  local m=ActiveMasters[player];local profile=_G.DataManager.GetProfile(player)
  if not m or not profile then return false end
  for uuid,h in pairs(m.DeployedHeroes) do
   local data=profile.Heroes[uuid]
   -- Downed (COMA) heroes still belong to the roster; partial squads may travel.
   if not data or data.Assignment~="SQUAD_SLOT_"..h.SlotIndex or (data.ComaUntilTimestamp or 0)>os.time() then return false end
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
   local changedFloor=false
   for _,h in pairs(m.DeployedHeroes) do
    if h.FloorId~=room.FloorId then changedFloor=true end
    h.FloorId=room.FloorId;h.RoomGeneration=room.RoomGeneration;h.EntityGeneration+=1
    local spawnBase = anchor or (if room.FloorId > 0 then getAssignedSpawnRoot(room) else room.Arrival.Position)
    h.Position=HeroNavigation.PlaceNear(spawnBase,getFormationOffset(h.SlotIndex))
    h.TargetNetId=nil
    if h.CurrentHP > 0 and h.State ~= "COMA" then
     h.State = "FOLLOW_MASTER"
    else
     h.State = "COMA"
    end
    h.PacifiedUntil=os.clock()+2;h.ActionSequence=0;HeroNavigation.Clear(h)
    for _,other in pairs(ActiveHeroesByNetId) do if other.TargetNetId==h.NetId then other.TargetNetId=nil;if other.CurrentHP > 0 and other.State ~= "COMA" then other.State="FOLLOW_MASTER" end end end
   end
   if room.FloorId == 0 then
    ActivePlayerProgress[player] = nil
    restoreSquadOnPlot(player)
   else
    -- Moving between floors revives downed heroes at a fraction of their HP; it no longer heals anyone
    -- (same-floor recalls do nothing). The tower sanctuary is where standing heroes recover.
    if changedFloor then
     reviveDownedOnTransition(player)
    end
    local existing = ActivePlayerProgress[player]
    if not existing or existing.FloorId ~= room.FloorId then
     local progress = TowerProgress.CreateProgress(room.FloorId)
     ActivePlayerProgress[player] = progress
     if FloorProgressRemote then
      FloorProgressRemote:FireClient(player, progress)
     end
    else
     if FloorProgressRemote then
      FloorProgressRemote:FireClient(player, existing)
     end
    end
   end
   syncSquadStatus(player)
  end,
 CaptureCargo=function(player) return CarrierToHeldLoot[player] end,
 DropCargo=function(player) CombatSimulation.DropCarriedLoot(player,true) end,
 StoreCargo=function(player, loc) return CombatSimulation.BankHeldLoot(player, loc) end,
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
  if victim.Player then return end -- The commander is not a combatant.
  if victim.DuelId then return end -- Mobs leave duelling squads alone.
  if not Tower.Same(victim,mob) or Tower.GetSafety(victim,victim.Position).CombatSafe then return end
  if victim.Player then
   local hp=victim.Humanoid.Health;victim.Humanoid:TakeDamage(damage)
   Tower.BroadcastAt(CombatVFXRemote,victim,"HIT_SPARK",victim.Position,hp-victim.Humanoid.Health,false,true)
  else
   local heroBarrier = victim.BarrierHP or 0
   if heroBarrier > 0 and (victim.BarrierExpires or 0) > os.clock() then
       local absorbed = math.min(heroBarrier, damage)
       victim.BarrierHP = heroBarrier - absorbed
       damage -= absorbed
   end
   local actualDamage=math.min(victim.CurrentHP,damage)
   victim.CurrentHP=math.max(0,victim.CurrentHP-damage)
   Tower.BroadcastAt(CombatVFXRemote,victim,"HIT_SPARK",victim.Position,actualDamage,false,true)
   if victim.CurrentHP<=0 then knockHeroIntoComa(victim,COMA_DURATION_DEFAULT) end
  end
 end,
  Reward=function(mob,killer)
   awardParticipationXP(mob)
   local dm = getDataManager()
   local isBoss = (mob :: any).Role == "BOSS"

   if not isBoss then
    if killer and killer.Parent == Players then
     -- Phase 6: an assigned squad farms Gold, gems and XP anywhere; relics and floor progress need its Master on the floor.
     local masterHere = Tower.GetState(killer).FloorId == mob.FloorId
     local marketMult = dm.GetMarketMultiplier and dm.GetMarketMultiplier(killer) or 1.0
     local profile = dm.GetProfile(killer)
     if profile then
      local reward = TowerRewards.GetKillRewards(mob.FloorId, mob.Role)
      local killGold = math.round(reward.Gold * marketMult)
      profile.Currencies.Gold += killGold
      profile.Currencies.Gems += reward.Gems
      TowerRuns.AddEarnings(killer, killGold, reward.Gems, if masterHere then 1 else 0)
      dm.SyncProfile(killer)
      local tier = TowerRewards.RollRelic(mob.FloorId, mob.Role, math.random(), math.random())
      if masterHere and tier and _G.RelicService then
       _G.RelicService.SpawnRelic(tier, mob.Position, killer.UserId)
      end
     end

     local progress = ActivePlayerProgress[killer]
     if masterHere then
     if not progress or progress.FloorId ~= mob.FloorId then
      progress = TowerProgress.CreateProgress(mob.FloorId)
      ActivePlayerProgress[killer] = progress
      if FloorProgressRemote then
       FloorProgressRemote:FireClient(killer, progress)
      end
     end
     if progress and progress.FloorId == mob.FloorId and not progress.BossSpawned then
      local shouldSpawn = TowerProgress.RecordKill(progress, mob.Role)
      if not shouldSpawn and TowerProgress.CheckSurge(progress) then
       Encounters:SpawnSurge(mob.FloorId, killer, mob.Position)
       getDataManager().SendToast(killer, "A surge pack is bearing down on your squad!", "WARN")
      end
      if FloorProgressRemote then
       FloorProgressRemote:FireClient(killer, progress)
      end
      if shouldSpawn then
       summonFloorBoss(killer, progress)
      end
     end
     end
    end
   else
    -- Boss Defeated: distribute full copies of uncontestable rewards to participants with >= 3% damage
    for p, _ in pairs(ActiveMasters) do
     local s = Tower.GetState(p)
     if s.FloorId == mob.FloorId and p.Parent == Players then -- Phase 6: only a Master standing on the floor can clear it
      local damage = (mob.DamageLedger and mob.DamageLedger[p.UserId]) or 0
      if TowerProgress.CheckParticipation(damage, mob.MaxHP, p == killer) then
       local marketMult = dm.GetMarketMultiplier and dm.GetMarketMultiplier(p) or 1.0
       local profile = dm.GetProfile(p)
       local reward = TowerRewards.GetKillRewards(mob.FloorId, "BOSS")
       -- Phase 6 M4: the first clear of a floor is the big payout (Gold x3, gems that grow with depth, a guaranteed relic);
       -- repeat kills only pay Gold and a coin-flip relic, so a cleared floor is a farm, not a gem fountain.
       local firstClear = profile ~= nil and mob.FloorId > (profile.HighestClearedFloor or 0)
       local bossTier = if mob.FloorId % 5 == 0 then math.floor(mob.FloorId / 5) else 0
       local firstBiomeClear = bossTier > 0 and profile ~= nil and bossTier > (profile.HighestClearedBiomeBoss or 0)
       local bossGold = math.round(reward.Gold * marketMult * (if firstClear then 3 else 1))
       local bossGems = if firstClear then 10 + 2 * mob.FloorId else 0
       if firstBiomeClear then bossGems += 300 * bossTier end
       if profile then
        profile.Currencies.Gold += bossGold
        profile.Currencies.Gems += bossGems
        profile.HighestClearedFloor = math.max(profile.HighestClearedFloor or 0, mob.FloorId)
        profile.MaxFloorReached = math.max(profile.MaxFloorReached or 0, mob.FloorId + 1)
        dm.SyncProfile(p)
        if dm.ReportProgress then dm.ReportProgress(p, "FloorCleared") end
        TowerRuns.AddEarnings(p, bossGold, bossGems, 0)
        TowerRuns.RecordFloorClear(p, mob.FloorId, firstClear)
        CombatSimulation.RefreshPlayerHeroStats(p) -- a new highest floor raises the Rift Attunement cap
       end

       -- One contested relic per boss kill, tagged to the killer: guaranteed on a first clear, 50% afterwards.
       if p == killer and _G.RelicService and (firstClear or math.random() < 0.5) then
        local relicTier = TowerRewards.RollRelic(mob.FloorId, "BOSS", 0, math.random())
        if relicTier then _G.RelicService.SpawnRelic(relicTier, mob.Position, p.UserId) end
       end

       if bossTier > 0 then
        dm.RecordBiomeBossClear(p, bossTier)
        if firstBiomeClear and dm.GrantBossArtifact then dm.GrantBossArtifact(p, bossTier) end
       end

       local progress = ActivePlayerProgress[p]
       if not progress or progress.FloorId ~= mob.FloorId then
        progress = TowerProgress.CreateProgress(mob.FloorId)
        ActivePlayerProgress[p] = progress
       end
       progress.BossDefeated = true
       progress.BossSpawned = true
       progress.CurrentKills = progress.RequiredKills
       if FloorProgressRemote then
        FloorProgressRemote:FireClient(p, progress)
       end

       dm.SendToast(p, string.format("Floor %d Boss Defeated! Unlocked Floor %d! (+%d Gold, +%d Gem)", mob.FloorId, mob.FloorId + 1, bossGold, bossGems), "SUCCESS")
      end
     end
    end
    spawnFloorAscensionPortal(mob.FloorId, mob.Position)
    -- Players who earned this boss through their own threshold but fell short of 3% damage
    -- keep their earned summon: a fresh boss appears for them once this one is cleaned up.
    for p, progress in pairs(ActivePlayerProgress) do
     if progress.FloorId == mob.FloorId and progress.BossSpawned and not progress.BossDefeated then
      progress.BossNetId = nil
      task.delay(3.5, function()
       if ActivePlayerProgress[p] == progress and p.Parent == Players and not progress.BossDefeated then
        summonFloorBoss(p, progress)
       end
      end)
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

local function bindCharacterCargoListeners(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			CombatSimulation.DropCarriedLoot(player, true)
		end)
	end
	char.Destroying:Connect(function()
		if CarrierToHeldLoot[player] then
			CombatSimulation.DropCarriedLoot(player, true)
		end
	end)
	-- A respawned thief keeps the [Loot Thief] nameplate until the flag runs out.
	task.spawn(function()
		if char:WaitForChild("Head", 5) and player.Character == char then
			applyThiefTag(player)
		end
	end)
end

local function handlePlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		bindCharacterCargoListeners(player, char)
	end)
	if player.Character then
		bindCharacterCargoListeners(player, player.Character)
	end
	player.CharacterRemoving:Connect(function()
		if CarrierToHeldLoot[player] then
			CombatSimulation.DropCarriedLoot(player, true)
		end
	end)
	task.delay(1.0, function()
		CombatSimulation.RebuildPlayerSquad(player)
		broadcastMetadata(player)
	end)
end

Players.PlayerAdded:Connect(handlePlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	handlePlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player: Player)
	ActivePlayerProgress[player] = nil
	-- Leaving forfeits a running duel; the drop is settled before the leaver's cargo spills.
	local duel = DuelByPlayer[player]
	if duel then
		duel.Winner = if duel.Sides.A.Player == player then "B" else "A"
		finishDuel(duel)
	end
	for _, contest in pairs(Contests) do
		if contest.Status == "CONTESTED" and (contest.OwnerUserId == player.UserId or contest.ThiefUserId == player.UserId) then
			contest.Status = "EXPIRED"
			closeContestPrompt(contest)
		end
	end
	ThiefFlagUntil[player] = nil
	LastRetaliationRequest[player] = nil
	LastPickupDenial[player] = nil
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
	HeroImpacts:Drain(os.clock(), canReleaseHeroImpact, resolveHeroImpact)
	accumulator += deltaTime
	if accumulator < TICK_INTERVAL then
		return
	end

	local dt = accumulator
	accumulator = 0.0
	local now = os.clock()
	Encounters:Tick(dt)

	for _, simHero in pairs(ActiveHeroesByNetId) do
		stepHeroSimulation(simHero, dt, now)
		-- Phase 6: the tower sanctuary is where standing heroes recover. Downed heroes only stand back up on a transition.
		if simHero.FloorId > 0 and simHero.State ~= "COMA" and simHero.CurrentHP > 0 and simHero.CurrentHP < simHero.MaxHP
			and not simHero.DuelId and Tower.GetSafety(simHero, simHero.Position).CanRecoverWipe == true then
			simHero.CurrentHP = math.min(simHero.MaxHP, simHero.CurrentHP + simHero.MaxHP * TowerHardcore.SanctuaryHealPerSecond * dt)
		end
	end
	stepDuels(now)
	stepContests(now)

	-- Sanctuary banking is scoped to the cargo's authoritative floor/generation.
	for player, masterState in pairs(ActiveMasters) do
		local rootPos = getMasterRootPosition(player)
		if rootPos then
			local location=Tower.GetState(player)
			local safety=Tower.GetSafety(location,rootPos)
			-- Phase 6 run lifecycle: a run starts on a tower floor and ends when the Master is back in the hub or on the plot.
			if not Tower.IsTransitioning(player) then
				if location.FloorId > 0 then
					TowerRuns.Ensure(player, location.FloorId)
				elseif TowerRuns.Get(player) then
					local summary = TowerRuns.End(player, "RETURN")
					if summary and (summary.FloorsCleared > 0 or summary.Kills > 0) then
						getDataManager().SendToast(player, string.format("Run over: floors %d-%d, %d cleared, best streak x%d, +%d Gold, +%d Gems",
							summary.StartFloor, summary.HighestFloor, summary.FloorsCleared, summary.BestStreak, summary.GoldEarned + summary.RelicGold, summary.GemsEarned + summary.RelicGems), "INFO")
					end
				end
			end
			if safety.CanBankCargo and not Tower.IsTransitioning(player) and not DuelByPlayer[player] then
				if CarrierToHeldLoot[player] then
					CombatSimulation.BankHeldLoot(player, location)
				end
				TowerRuns.Bank(player) -- the sanctuary makes unbanked earnings safe from a wipe

				if safety.CanRecoverWipe and masterState.IsSquadWiped then
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

	-- Carried loot does not despawn while held by a player.
	snapshotTick += 1
	if snapshotTick % SNAPSHOT_EVERY_TICKS == 0 then
		broadcastReplicationSnapshot(now)
	end
end)

CombatSimulation.SpawnPhysicalLoot = spawnPhysicalLoot
CombatSimulation.CollectPhysicalLoot = collectPhysicalLoot
CombatSimulation.Contests = Contests
CombatSimulation.StartDuel = startDuel
_G.CombatSimulation = CombatSimulation
