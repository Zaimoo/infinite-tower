--!strict
debug.setmemorycategory("CombatSim")
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
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local HeroNavigation = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("HeroNavigation"))

local Tower=require(script.Parent.Parent.Core.TowerFloorService)
Tower.Init()
local Protocol=require(Shared.Util.TowerProtocol)
local SanctuaryRules=require(Shared.Util.TowerSanctuaryRules)
local SupportRules=require(Shared.Util.SupportRules)
local AffixRules=require(Shared.Util.AffixRules)
local FirstBiome=require(Shared.Config.FirstBiomeCombat)
local TowerLayout=require(Shared.Config.TowerLayout)
local PortalAssets=require(Shared.Config.TowerPortalAssets)
local TowerRewards=require(Shared.Config.TowerFloorConfig)
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))
local TowerHardcore=require(Shared.Config.TowerHardcoreConfig)
local StatBalance=require(Shared.Config.StatBalance)
local EncounterRuntime=require(script.Parent.TowerEncounterRuntime)
local TowerRuns=require(script.Parent.TowerRunService)
local TowerRun=require(Shared.Util.TowerRun)
local AttackTimeline=require(Shared.Util.AttackTimeline)
local HeroActionTiming=require(Shared.Util.HeroActionTiming)
local HeroImpactQueue=require(script.Parent.HeroImpactQueue)
local HeroTargeting=require(script.Parent.HeroTargeting)
local HeroSkillEffects=require(script.Parent.HeroSkillEffects)
local SquadMovement=require(script.Parent.SquadMovement)
local HeroImpacts=HeroImpactQueue.new()
local TowerProgress=require(Shared.Util.TowerProgress)
local TowerRoomBuilder=require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("TowerRoomBuilder"))
local TowerPortalKit=require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("TowerPortalKit"))
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
local DuelStateRemote = TowerRemotes:WaitForChild("DuelState") :: RemoteEvent
local SquadWipeStateRemote = CombatRemotes:WaitForChild("SquadWipeState") :: RemoteEvent
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

local SprintStateRemote = CombatRemotes:FindFirstChild("SprintState") :: RemoteEvent?
if not SprintStateRemote then
	SprintStateRemote = Instance.new("RemoteEvent")
	SprintStateRemote.Name = "SprintState"
	SprintStateRemote.Parent = CombatRemotes
end
SprintStateRemote.OnServerEvent:Connect(function(player: Player, isSprinting: any)
	local sprinting = isSprinting == true
	player:SetAttribute("IsSprinting", sprinting)
	if player.Character then
		player.Character:SetAttribute("IsSprinting", sprinting)
	end
end)

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
local MASTER_FORMATION_RADIUS = 6.0
local FOLLOW_CATCHUP_RADIUS = 14.0
local FOLLOW_CATCHUP_SPAN = 50.0
local FOLLOW_CATCHUP_MAX_BONUS = 0.65
local MASTER_SPRINT_MULTIPLIER = 3.0
local SPRINT_FOLLOW_BUFFER = 1.05
local SPRINT_VELOCITY_THRESHOLD = 22.0
local LEASH_DISTANCE = 160.0
local LEASH_VERTICAL_TELEPORT_DISTANCE = 45.0
-- Effective combat stats come from the profile (level, stars, weapon, training, attunement cap). They
-- change rarely, so each hero re-derives them at most this often instead of every sim tick.
local STAT_REFRESH_SECONDS = 1.0

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
	StatsRefreshAt: number?,
	MoveSpeed: number,
	Stamina: number,
	SlotIndex: number,
	TargetNetId: number?,
	TargetId: number?,
	IsFocusTarget: boolean?,
	FocusOverride: boolean?,
	RecallOverride: boolean?,
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
	TauntedByNetId: number?,
	TauntExpires: number?,
	DuelId: number?, -- set while the hero fights in a bounty duel
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
	TauntedByNetId: number?,
	TauntExpires: number?,
	TargetNetId: number?,
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

-- Contested relics (GDD 6.1): one contest per stolen relic, keyed by RelicId.
local Contests: { [number]: LootDuel.Contest } = {}
local ThiefFlagUntil: { [Player]: number } = {}
local LastChallengeRequest: { [Player]: number } = {}

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

local CombatSimulation = {}
local NextNetId = 1
local function allocateNetId(): number
	local id = NextNetId
	NextNetId += 1
	assert(NextNetId < 4294967295, "Entity ID space exhausted")
	return id
end

local ActiveMasters: { [Player]: MasterCombatState } = {}
local MasterVelocityTracking: { [Player]: { LastPos: Vector3, LastClock: number, HorizontalSpeed: number } } = {}
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
   entry.FloorId=e.FloorId;entry.RoomGeneration=e.RoomGeneration;entry.EntityGeneration=e.EntityGeneration;entry.Position=e.Position;entry.IsAlive=(e.CurrentHP or 0)>0 and e.State~="COMA";table.insert(metadata,entry)
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
	return SquadMovement.RadialOffset(slotIndex)
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

local function getAssignedFloorAnchorPlan(owner: Player, floorId: number, room: any, masterState: MasterCombatState?, now: number): {
	AnchorPosition: Vector3,
	RegroupAnchor: Vector3,
	ObjectiveNetId: number?,
	ObjectiveMob: any?,
	Retained: boolean,
}
	local basinRoot = getAssignedSpawnRoot(room) - Vector3.new(0, 3, 0)
	if not room or floorId <= 0 then
		return {
			AnchorPosition = basinRoot,
			RegroupAnchor = basinRoot,
			ObjectiveNetId = nil,
			ObjectiveMob = nil,
			Retained = false,
		}
	end
	return SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = floorId,
		RoomGeneration = room.RoomGeneration or room.Generation or 1,
		Origin = room.Origin,
		DefaultSpawnPosition = basinRoot,
		Heroes = masterState and masterState.DeployedHeroes,
		Mobs = ActiveMobsByNetId,
		FocusedTargetNetId = masterState and masterState.FocusedTargetNetId,
		Now = now,
		IsMobEligible = function(mob: any): boolean
			return mob.IsAlive and Tower.Same(mob, room) and not Tower.GetSafety(mob, mob.Position).CombatSafe
		end,
		PlaceOnGround = function(base: Vector3, offset: Vector3): Vector3
			return HeroNavigation.PlaceOnGround(base, offset)
		end,
	})
end

local function getAssignedFloorAnchor(floorId: number, room: any, masterState: MasterCombatState?, owner: Player?, now: number?): Vector3
	local resolvedOwner = owner
	if not resolvedOwner and masterState then
		for _, h in pairs(masterState.DeployedHeroes) do
			resolvedOwner = h.Owner
			break
		end
	end
	if resolvedOwner then
		return getAssignedFloorAnchorPlan(resolvedOwner, floorId, room, masterState, now or os.clock()).AnchorPosition
	end
	return getAssignedSpawnRoot(room) - Vector3.new(0, 3, 0)
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
	local masterPos=towerState.SquadAssignment and getAssignedFloorAnchor(towerState.SquadFloorId, room, masterState) or getMasterGroundPosition(player) or (room.Arrival.Position - Vector3.new(0, 3, 0))
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
			SquadMovement.ClearHero(player, simHero.NetId)
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
			local spawnPos = HeroNavigation.PlaceOnGround(masterPos, getFormationOffset(slotIndex))
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
				TargetId = masterState.FocusedTargetNetId,
				IsFocusTarget = masterState.FocusedTargetNetId ~= nil,
				FocusOverride = nil,
				RecallOverride = nil,
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

local registerPickup: (player: Player, dropId: number, killerUserId: number, killerName: string, label: string) -> boolean

DropCarriedItemRemote.OnServerEvent:Connect(function(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local dropped = false
	if _G.RelicService and _G.RelicService.DropCarriedRelic then
		dropped = _G.RelicService.DropCarriedRelic(player)
	end
	if dropped then
		getDataManager().SendToast(player, "Dropped carried item. You can pick it up again.", "INFO")
	end
end)

local function knockHeroIntoComa(simHero: SimHero, _baseComaSeconds: number?)
	HeroNavigation.Clear(simHero)
	SquadMovement.ClearHero(simHero.Owner, simHero.NetId)
	local dm = getDataManager()
	local profile = dm.GetProfile(simHero.Owner)

	-- Phase 2 Hard Death Rules: dead heroes collapse in place with CurrentHP = 0, State = "COMA"
	-- No 60-second coma and no hospital/infirmary timers!
	simHero.CurrentHP = 0
	simHero.State = "COMA"
	simHero.TargetNetId = nil
	simHero.TargetId = nil
	simHero.IsFocusTarget = false
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

	Tower.BroadcastAt(CombatVFXRemote, simHero, "HERO_COMA", simHero.Position, simHero.NetId)

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
			if _G.RelicService then
				_G.RelicService.FumbleRelicOnAoEHit(simHero.Owner)
			end
			masterState.CarriedLoot = { Gold = 0, Gems = 0 }
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
	SquadMovement.Reset(player)
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
	SquadMovement.Reset(player)
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

local challengeThief: (hunter: Player, thief: Player) -> () -- defined with the bounty duels below

-- [Loot Thief] marker: a character attribute for game logic, a nameplate everyone can see, and the
-- bounty prompt (F) other Masters use to challenge the thief. The thief's own client hides the prompt.
local function applyThiefTag(player: Player)
	local char = player.Character
	if not char then return end
	local flagged = (ThiefFlagUntil[player] or 0) > os.clock()
	char:SetAttribute("IsLootThief", flagged)
	local root = char:FindFirstChild("HumanoidRootPart")
	local bountyPrompt = root and root:FindFirstChild("BountyPrompt")
	if flagged and root and not bountyPrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BountyPrompt"
		prompt.ActionText = "Claim Bounty"
		prompt.ObjectText = player.DisplayName .. " [Loot Thief]"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = LootDuel.CHALLENGE_RANGE
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(hunter: Player)
			challengeThief(hunter, player)
		end)
		prompt.Parent = root
	elseif not flagged and bountyPrompt then
		bountyPrompt:Destroy()
	end
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

-- Runs on every relic pickup. Returns true when the pickup was a theft (and opened a bounty).
registerPickup = function(player: Player, dropId: number, killerUserId: number, killerName: string, label: string): boolean
	local dm = getDataManager()
	if not LootDuel.IsTheft(killerUserId, player.UserId) then
		-- The owner took their drop back without a fight: the contest is over.
		local contest = Contests[dropId]
		if contest and contest.Status == "CONTESTED" and contest.OwnerUserId == player.UserId then
			contest.Status = "RESOLVED"
			closeContestPrompt(contest)
			local thief = Players:GetPlayerByUserId(contest.ThiefUserId)
			if thief then refreshThiefFlag(thief) end
		end
		return false
	end
	-- A re-steal replaces any older contest for this drop; the newest thief carries the bounty.
	local previous = Contests[dropId]
	if previous and previous.Status == "CONTESTED" then
		previous.Status = "EXPIRED"
		local previousThief = Players:GetPlayerByUserId(previous.ThiefUserId)
		if previousThief then refreshThiefFlag(previousThief) end
	end
	local contest = LootDuel.NewContest(dropId, killerUserId, player.UserId, os.clock())
	Contests[dropId] = contest
	refreshThiefFlag(player)

	local victimPlayer = Players:GetPlayerByUserId(killerUserId)
	-- The bounty is public: every other Master on the floor can hunt the thief down.
	local thiefState = Tower.GetState(player)
	for _, other in Players:GetPlayers() do
		if other ~= player and other ~= victimPlayer and Tower.Same(Tower.GetState(other), thiefState) then
			dm.SendToast(other, string.format("🎯 BOUNTY: %s stole %s's %s! Get close and press F to duel for it.", player.DisplayName, killerName, label), "INFO")
		end
	end
	if victimPlayer then
		dm.SendToast(victimPlayer, string.format("🚨 %s STOLE YOUR %s! Get close and press F to duel for it!", player.DisplayName, string.upper(label)), "WARN")
		LootContestedRemote:FireClient(victimPlayer, {
			Kind = "STOLEN", DropId = dropId, ThiefUserId = player.UserId, ThiefName = player.DisplayName,
			Label = label, Seconds = LootDuel.THIEF_FLAG_SECONDS,
		})
	end
	dm.SendToast(player, string.format("⚠️ You stole %s's %s! You are a [Loot Thief] with a bounty on you: any Master who reaches you can duel you for it.", killerName, label), "WARN")
	return true
end

-- Relics live in RelicService; it reports every pickup here so stealing one opens a bounty.
-- Contests are keyed by relic id.
function CombatSimulation.ReportRelicPickup(player: Player, relicId: number, killerUserId: number?, label: string): boolean
	local killer = killerUserId and Players:GetPlayerByUserId(killerUserId)
	return registerPickup(player, relicId, killerUserId or 0, if killer then killer.DisplayName else "another Master", label)
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
-- 6a. BOUNTY DUELS (GDD 6.1)
-- Any Master except the thief (the robbed owner included) walks up to a [Loot Thief] and presses F;
-- both squads fight on a floating hex arena above the floor while their Masters wait in place.
-- Nobody is wiped, teleported or loses progress: heroes return to their pre-duel HP afterwards, the
-- winner takes the drop and the loser (hunter or thief) is locked out of it.
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

-- A contested relic either lies on the floor or rides over somebody's head.
local function findDrop(dropId: number): (any?, Player?)
	local relics = _G.RelicService
	local relic = relics and relics.GetRelic and relics.GetRelic(dropId)
	if relic then
		return relic, relic.Carrier
	end
	return nil, nil
end

local function startDuel(owner: Player, contest: LootDuel.Contest?): (boolean, string?)
	-- `owner` is the bounty hunter (side A); the thief defends as side B.
	local ok, reason = LootDuel.CanChallenge(contest, owner.UserId, os.clock())
	if not ok or not contest then return false, reason end
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
		SquadMovement.Reset(squad.Player)
		DuelByPlayer[squad.Player] = duel
	end

	Duels[id] = duel
	contest.Status = "DUELING"
	contest.ChallengerUserId = owner.UserId
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
	dm.SendToast(owner, string.format("⚔️ Bounty duel against %s! Winner takes the drop.", thief.DisplayName), "WARN")
	dm.SendToast(thief, string.format("⚔️ %s claimed your bounty and challenged you to a duel for the stolen drop!", owner.DisplayName), "WARN")
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
		Tower.BroadcastAt(CombatVFXRemote, victim, "HERO_COMA", victim.Position, victim.NetId)
		sendDuelState(duel, { Kind = "SCORE" })
	end
end

-- Duel heroes skip leash, navigation and mob acquisition: they walk straight across the flat
-- arena at the nearest standing enemy (or whoever taunted them) and fight with their own kit.
local function stepDuelHero(simHero: SimHero, dt: number, now: number)
	local duel = simHero.DuelId and Duels[simHero.DuelId]
	if not duel or duel.Phase ~= "FIGHT" or simHero.State == "COMA" then return end
	if simHero.TauntExpires and now >= simHero.TauntExpires then
		if simHero.TargetNetId == simHero.TauntedByNetId then
			simHero.TargetNetId = nil
		end
		simHero.TauntedByNetId = nil
		simHero.TauntExpires = nil
	end
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
		Taunt = function(target: any, attacker: any, duration: number)
			target.TargetNetId = attacker.NetId
			target.TauntedByNetId = attacker.NetId
			target.TauntExpires = now + duration
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
	local record = findDrop(contest.DropId)
	LootDuel.Resolve(contest, record, winner.UserId)
	if record then
		record.KillerName = winner.DisplayName
	end
	if record and winner.Parent == Players and _G.RelicService then
		_G.RelicService.GiveRelicTo(winner, contest.DropId)
	end

	local dm = getDataManager()
	local hunterLost = loser.UserId ~= contest.ThiefUserId
	if winner.Parent == Players then
		dm.SendToast(winner, string.format("🏆 You won the duel against %s! The contested drop is yours.", loser.DisplayName), "SUCCESS")
	end
	if loser.Parent == Players then
		dm.SendToast(loser, if hunterLost
			then string.format("💀 You lost the duel. %s keeps the drop and you are locked out of it.", winner.DisplayName)
			else string.format("💀 You lost the duel. %s claims the drop and you are locked out of it.", winner.DisplayName), "WARN")
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
		SquadMovement.Reset(squad.Player)
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

-- Fired by the thief's F prompt. The prompt's range is enforced by the client, so the server re-checks it.
challengeThief = function(hunter: Player, thief: Player)
	if hunter == thief or hunter.Parent ~= Players or thief.Parent ~= Players then return end
	local now = os.clock()
	if now - (LastChallengeRequest[hunter] or -math.huge) < LootDuel.CHALLENGE_COOLDOWN then return end
	LastChallengeRequest[hunter] = now
	local hunterPos, thiefPos = getMasterRootPosition(hunter), getMasterRootPosition(thief)
	if not hunterPos or not thiefPos or (hunterPos - thiefPos).Magnitude > LootDuel.CHALLENGE_RANGE + 4 then
		getDataManager().SendToast(hunter, string.format("Get closer to %s to claim the bounty.", thief.DisplayName), "WARN")
		return
	end
	-- A thief with several open bounties is challenged for their newest steal.
	local chosen: LootDuel.Contest? = nil
	for _, contest in pairs(Contests) do
		if contest.ThiefUserId == thief.UserId and contest.Status == "CONTESTED"
			and (not chosen or contest.ExpiresAt > chosen.ExpiresAt) then
			chosen = contest
		end
	end
	local ok, reason = startDuel(hunter, chosen)
	if not ok then
		getDataManager().SendToast(hunter, reason or "The duel cannot start right now.", "WARN")
	end
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

	-- 3. Clicking another Master (or their hero) never starts a fight: squads only meet inside a
	-- bounty duel, which is claimed by walking up to a [Loot Thief] and pressing F.
	if targetPlayer and targetPlayer ~= player then
		if DuelByPlayer[player] then return end
		local targetChar = targetPlayer.Character
		if targetChar and targetChar:GetAttribute("IsLootThief") then
			dm.SendToast(player, string.format("Walk up to %s and press F to claim the bounty.", targetPlayer.DisplayName), "INFO")
		end
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
						simHero.TargetId = targetNetId
						simHero.IsFocusTarget = true
						simHero.FocusOverride = true
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
		masterState.FocusedTargetNetId = nil
		for _, simHero in pairs(masterState.DeployedHeroes) do
			simHero.TargetNetId = nil
			simHero.TargetId = nil
			simHero.IsFocusTarget = false
			simHero.RecallOverride = true
		end
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

-- Mobs a hero may auto-target: alive, in the hero's room generation and outside safe zones.
local function isHostileMob(simHero: SimHero, mob: SimMob): boolean
	return mob.IsAlive and Tower.Same(simHero, mob) and not Tower.GetSafety(mob, mob.Position).CombatSafe
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
		Absorb = function(mob: any, amount: number): number
			return if Encounters then Encounters:OnMobHit(mob, amount) else amount
		end,
		Taunt = function(mob: any, attacker: any, duration: number)
			mob.TargetNetId = attacker.NetId
			mob.TauntedByNetId = attacker.NetId
			mob.TauntExpires = now + duration
			if Encounters then
				Encounters:Taunt(mob, attacker, duration, now)
			end
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
		if Encounters then
			damage = Encounters:OnMobHit(mob, damage) -- WARD shields soak first; a hit interrupts a support's cast
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
			if simHero.TargetNetId == mob.NetId or simHero.TargetId == mob.NetId then
				simHero.TargetNetId = nil
				simHero.TargetId = nil
				simHero.IsFocusTarget = false
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

local function updateMasterMovementPolicy(player: Player, dt: number, now: number)
	local squadState = Tower.GetState(player)
	local assignedRoom = squadState.SquadAssignment and Tower.GetRoom(squadState.SquadFloorId)
	local floorId = if assignedRoom then squadState.SquadFloorId else (squadState.FloorId or 0)
	local roomGen = if assignedRoom then squadState.SquadRoomGeneration else (squadState.RoomGeneration or 1)
	local room = Tower.GetRoom(floorId)
	local ownerChar = player.Character
	local ownerHum = ownerChar and ownerChar:FindFirstChildOfClass("Humanoid")
	local ownerHrp = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootPos = ownerHrp and ownerHrp.Position or nil
	local supportedPos = if not assignedRoom and ownerHrp then HeroNavigation.Ground(ownerHrp.Position, nil, 3, 50) else nil
	local isSprintingAttr = player:GetAttribute("IsSprinting") == true or (ownerChar ~= nil and ownerChar:GetAttribute("IsSprinting") == true)
	SquadMovement.UpdateMaster(player, {
		FloorId = floorId,
		RoomGeneration = roomGen,
		Assigned = assignedRoom ~= nil,
		RawRootPosition = rootPos,
		SupportedPosition = supportedPos,
		Origin = room and room.Origin,
		IsJumping = isPlayerJumping(player),
		IsSprintingAttr = isSprintingAttr,
		HumanoidWalkSpeed = ownerHum and ownerHum.WalkSpeed or 16.0,
		RootVelocity = ownerHrp and ownerHrp.AssemblyLinearVelocity or Vector3.zero,
		Now = now,
		DeltaTime = dt,
		CanWalk = function(from: Vector3, goal: Vector3): boolean
			return HeroNavigation.CanShortcut(from, goal)
		end,
	})
end

local lastMasterPolicyClock: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function buildFreeSquadAssistList(
	player: Player,
	hero: SimHero,
	masterState: MasterCombatState,
	anchorPos: Vector3,
	now: number,
	maxLeash: number
): { number }
	local list: { number } = {}
	local seen: { [number]: boolean } = {}

	-- 1. Master Focused Target takes top priority
	if masterState.FocusedTargetNetId then
		local focusedMob = ActiveMobsByNetId[masterState.FocusedTargetNetId]
		if focusedMob and focusedMob.IsAlive and isHostileMob(hero, focusedMob) then
			table.insert(list, masterState.FocusedTargetNetId)
			seen[masterState.FocusedTargetNetId] = true
			return list
		end
	end

	-- 2. Squad commitment: if any hero has a valid target, adopt that target and its camp
	local primaryCampId: string? = nil
	local heroes: { SimHero } = {}
	for _, h in pairs(masterState.DeployedHeroes) do
		if h.State ~= "COMA" and h.CurrentHP > 0 then
			table.insert(heroes, h)
		end
	end
	table.sort(heroes, function(a, b)
		return (a.SlotIndex or 99) < (b.SlotIndex or 99)
	end)

	for _, ally in ipairs(heroes) do
		local tId = ally.TargetId or ally.TargetNetId
		if tId and not seen[tId] then
			local mob = ActiveMobsByNetId[tId]
			if mob and mob.IsAlive and isHostileMob(hero, mob) then
				seen[tId] = true
				table.insert(list, tId)
				if not primaryCampId and (mob :: any).CampId then
					primaryCampId = (mob :: any).CampId
				end
			end
		end
	end

	-- If a camp was identified, include remaining alive mobs in the same camp so squad commits together
	if primaryCampId then
		for netId, mob in pairs(ActiveMobsByNetId) do
			if not seen[netId] and (mob :: any).CampId == primaryCampId and mob.IsAlive and isHostileMob(hero, mob) then
				seen[netId] = true
				table.insert(list, netId)
			end
		end
		return list
	end

	-- 3. If no squad hero has an active target (idle squad on ramp, 2 camps spawn simultaneously):
	-- Anchor initial auto-aggro choice to anchorPos (Master's or lead hero's position) using elevation-weighted distance.
	if #list == 0 then
		local ctx: HeroTargeting.Context = {
			MasterPos = anchorPos,
			Assigned = false,
			Leash = maxLeash,
			Now = now,
			SquadAnchorPos = anchorPos,
		}
		local initialTargetNetId = HeroTargeting.Acquire(hero, ActiveMobsByNetId, ctx, isHostileMob, nil)
		if initialTargetNetId then
			table.insert(list, initialTargetNetId)
			local chosenMob = ActiveMobsByNetId[initialTargetNetId]
			local chosenCampId = chosenMob and (chosenMob :: any).CampId
			if chosenCampId then
				for netId, mob in pairs(ActiveMobsByNetId) do
					if netId ~= initialTargetNetId and (mob :: any).CampId == chosenCampId and mob.IsAlive and isHostileMob(hero, mob) then
						table.insert(list, netId)
					end
				end
			end
		end
	end

	return list
end

local function stepHeroSimulation(simHero: SimHero, dt: number, now: number)
	local movementHero: any = simHero
	if simHero.DuelId then
		stepDuelHero(simHero, dt, now)
		return
	end
	if simHero.State == "COMA" then
		return
	end
	if lastMasterPolicyClock[simHero.Owner] ~= now then
		lastMasterPolicyClock[simHero.Owner] = now
		updateMasterMovementPolicy(simHero.Owner, dt, now)
	end
	local squadState = Tower.GetState(simHero.Owner)
	local assignedRoom = squadState.SquadAssignment and Tower.GetRoom(squadState.SquadFloorId)
	local masterState = ActiveMasters[simHero.Owner]
	local assignedAnchor = if assignedRoom
		then getAssignedFloorAnchorPlan(simHero.Owner, squadState.SquadFloorId, assignedRoom, masterState, now)
		else nil
	local masterPos = if assignedAnchor
		then assignedAnchor.AnchorPosition
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

	if now >= (simHero.StatsRefreshAt or 0) then
		simHero.StatsRefreshAt = now + STAT_REFRESH_SECONDS
		local profile = getDataManager().GetProfile(simHero.Owner)
		local currentHero = profile and profile.Heroes[simHero.HeroUUID]
		if currentHero then
			local artifact = StatFormulas.GetEquippedArtifact(profile, currentHero)
			local trainingMult = attunedMultiplier(simHero.Owner, profile, currentHero, artifact)
			local effATK, effHP, _, interval = StatFormulas.GetEffectiveCombatStats(currentHero, false, false, artifact, trainingMult)
			simHero.AttackInterval = interval
			simHero.EffectiveATK = effATK
			simHero.MaxHP = effHP
		end
	end
	simHero.CurrentHP = math.min(simHero.CurrentHP, simHero.MaxHP)

	local maxLeash = assignedRoom and FirstBiome.LeashRange or (masterState and masterState.TargetEnemyUserId ~= nil) and 150.0 or LEASH_DISTANCE
	if getHorizontalDistance(simHero.Position, masterPos) > maxLeash or math.abs(simHero.Position.Y - masterPos.Y) > LEASH_VERTICAL_TELEPORT_DISTANCE then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

	-- Master sprint & horizontal velocity detection (WalkSpeed, IsSprinting attribute, root velocity, and per-tick displacement)
	local ownerChar = simHero.Owner.Character
	local ownerHum = ownerChar and ownerChar:FindFirstChildOfClass("Humanoid")
	local ownerHrp = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humWalkSpeed = if assignedRoom then 16.0 elseif ownerHum then ownerHum.WalkSpeed else 16.0
	local rootVel = if not assignedRoom and ownerHrp then ownerHrp.AssemblyLinearVelocity else Vector3.zero
	local trackedVel = if not assignedRoom and MasterVelocityTracking[simHero.Owner] then MasterVelocityTracking[simHero.Owner].HorizontalSpeed else 0.0
	local horizVel = math.max(Vector3.new(rootVel.X, 0, rootVel.Z).Magnitude, trackedVel)

	local isMasterSprinting = not assignedRoom and (
		simHero.Owner:GetAttribute("IsSprinting") == true
		or (ownerChar ~= nil and ownerChar:GetAttribute("IsSprinting") == true)
		or humWalkSpeed > SPRINT_VELOCITY_THRESHOLD
		or horizVel > SPRINT_VELOCITY_THRESHOLD
	)
	local effectiveMasterWalkSpeed = if assignedRoom
		then 16.0
		elseif isMasterSprinting and humWalkSpeed <= SPRINT_VELOCITY_THRESHOLD then humWalkSpeed * MASTER_SPRINT_MULTIPLIER
		else humWalkSpeed

	local seed = HeroCatalog.Seeds[simHero.TemplateId]
	local heroBaseSpeed = (seed and seed.MovementSpeed) or 20.0
	simHero.MoveSpeed = heroBaseSpeed
	local isOverdrive = now < simHero.OverdriveUntil
	local overdriveMult = if isOverdrive then 1.20 else 1.0
	local baseFollowSpeed = (if assignedRoom
		then heroBaseSpeed
		else math.max(heroBaseSpeed, effectiveMasterWalkSpeed * SPRINT_FOLLOW_BUFFER, horizVel)) * overdriveMult

	-- Recall's aggro drop and safe zones pacify; HeroTargeting.Select drops the target while it lasts.
	-- Also disengage to follow when the Master sprints away beyond formation catch-up radius without a close focused target.
	local distToMasterFlat = getHorizontalDistance(simHero.Position, masterPos)
	local focusedMob = if masterState and masterState.FocusedTargetNetId then ActiveMobsByNetId[masterState.FocusedTargetNetId] else nil
	local hasCloseFocus = focusedMob ~= nil and focusedMob.IsAlive and getHorizontalDistance(masterPos, focusedMob.Position) <= HeroTargeting.MASTER_DROP_RADIUS
	local sprintDisengage = not assignedRoom and isMasterSprinting and distToMasterFlat > FOLLOW_CATCHUP_RADIUS and not hasCloseFocus
	if sprintDisengage and masterState and masterState.FocusedTargetNetId and not hasCloseFocus then
		masterState.FocusedTargetNetId = nil
	end
	local isPacified = now < simHero.PacifiedUntil
		or Tower.GetSafety(simHero, simHero.Position).CombatSafe == true
		or sprintDisengage

	-- Free-following squads fight around the Master and disengage when the Master walks off;
	-- assigned squads roam the floor up to maxLeash and join squadmates' fights.
	local squadAnchorPos = masterPos
	if not assignedRoom and masterState and not squadAnchorPos then
		local bestSlot = 999
		for _, h in pairs(masterState.DeployedHeroes) do
			if h.State ~= "COMA" and h.CurrentHP > 0 and (h.SlotIndex or 99) < bestSlot then
				squadAnchorPos = h.Position
				bestSlot = h.SlotIndex or 99
			end
		end
	end

	local engage: HeroTargeting.Context = {
		MasterPos = masterPos,
		Assigned = assignedRoom ~= nil,
		Leash = maxLeash,
		Now = now,
		FocusedTargetNetId = masterState and masterState.FocusedTargetNetId,
		SquadAnchorPos = squadAnchorPos,
		RouteCost = if assignedRoom
			then function(from: Vector3, to: Vector3): number
				return SquadMovement.RouteCost(simHero.FloorId, from, to, assignedRoom.Origin)
			end
			else nil,
	}
	local assist: { number }? = nil
	if assignedRoom and masterState then
		assist = SquadMovement.BuildAssignedAssistList(simHero.Owner, simHero, masterState.DeployedHeroes)
	elseif not assignedRoom and masterState and squadAnchorPos then
		assist = buildFreeSquadAssistList(simHero.Owner, simHero, masterState, squadAnchorPos, now, maxLeash)
	end
	local targetMob: SimMob? = HeroTargeting.Select(simHero, ActiveMobsByNetId, engage, isHostileMob, isPacified, assist)
	simHero.TargetId = simHero.TargetNetId
	local targetPos: Vector3? = targetMob and targetMob.Position
	local targetEnemyHero: SimHero? = nil -- outside duels heroes only ever fight mobs (stepDuelHero handles hero-vs-hero)

	if simHero.State == "FOLLOW_MASTER" or not targetPos then
		movementHero.AlternativeAttackGoal = nil
		if not assignedRoom then
			local plan = SquadMovement.PlanActiveFollow(simHero.Owner, simHero, masterPos, now, {
				HeroBaseSpeed = heroBaseSpeed,
				Overdrive = isOverdrive,
				PlaceOnGround = function(base: Vector3, offset: Vector3): Vector3
					return HeroNavigation.PlaceOnGround(base, offset)
				end,
				CanShortcut = function(from: Vector3, goal: Vector3): boolean
					return HeroNavigation.CanShortcut(from, goal)
				end,
			})
			movementHero.ServerRouteLag = plan.RouteLag
			movementHero.FormationTarget = plan.TerminalGoal
			movementHero.TrailGoal = plan.Goal
			local distToTerminal = (plan.TerminalGoal - simHero.Position).Magnitude
			if distToTerminal > .5 then
				local outcome = HeroNavigation.Step(simHero, plan.Goal, plan.FollowSpeed * dt, now, dt)
				movementHero.NavigationStatus = outcome.Status
			else
				HeroNavigation.Pause(simHero)
			end
		else
			local regroupAnchor = if assignedAnchor then assignedAnchor.RegroupAnchor else masterPos
			local plan = SquadMovement.PlanAssignedRegroup(simHero.Owner, simHero, regroupAnchor, now, {
				HeroBaseSpeed = heroBaseSpeed,
				Overdrive = isOverdrive,
				PlaceOnGround = function(base: Vector3, offset: Vector3): Vector3
					return HeroNavigation.PlaceOnGround(base, offset)
				end,
			})
			movementHero.ServerRouteLag = plan.RouteLag
			movementHero.FormationTarget = plan.TerminalGoal
			movementHero.TrailGoal = plan.Goal
			local distToGoal = (plan.Goal - simHero.Position).Magnitude

			if distToGoal > .5 then
				local outcome = HeroNavigation.Step(simHero, plan.Goal, plan.FollowSpeed * dt, now, dt)
				movementHero.NavigationStatus = outcome.Status
			else
				HeroNavigation.Pause(simHero)
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

	SquadMovement.MarkCombat(simHero.Owner, simHero)

	local distToTarget = (simHero.Position - targetPos).Magnitude
	if distToTarget > simHero.AttackRange or not HeroNavigation.CanAttack(simHero.Position, targetPos) then
		simHero.State = "MOVE_TO_TARGET"
		local moveGoal = targetPos
		local altGoal = movementHero.AlternativeAttackGoal
		if targetMob and altGoal and altGoal.NetId == targetMob.NetId and altGoal.Generation == (targetMob.EntityGeneration or 0) then
			if (altGoal.Position - targetPos).Magnitude <= simHero.AttackRange and HeroNavigation.CanAttack(altGoal.Position, targetPos) then
				moveGoal = altGoal.Position
			else
				movementHero.AlternativeAttackGoal = nil
			end
		end
		local distToGoal = (simHero.Position - moveGoal).Magnitude
		local stepDist = if moveGoal == targetPos
			then math.min(math.max(.5, distToTarget - simHero.AttackRange * .85), baseFollowSpeed * dt)
			else math.min(math.max(.5, distToGoal), baseFollowSpeed * dt)
		local outcome = HeroNavigation.Step(simHero, moveGoal, stepDist, now, dt)
		movementHero.NavigationStatus = outcome.Status
		if outcome.Status == "UNREACHABLE" and targetMob then
			SquadMovement.HandleCombatMoveOutcome(simHero.Owner, simHero, targetMob, outcome, now, {
				ExcludeSeconds = 5,
				PlaceOnGround = function(base: Vector3, offset: Vector3): Vector3
					return HeroNavigation.PlaceOnGround(base, offset)
				end,
				CanAttack = function(from: Vector3, to: Vector3): boolean
					return HeroNavigation.CanAttack(from, to)
				end,
				CanShortcut = function(from: Vector3, to: Vector3): boolean
					return HeroNavigation.CanShortcut(from, to)
				end,
				ClearNavigation = function(h: any)
					HeroNavigation.Clear(h)
				end,
			})
		elseif outcome.Status == "ARRIVED" then
			movementHero.AlternativeAttackGoal = nil
		end

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
		HeroNavigation.Pause(simHero)
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

local ENEMY_STATE_TO_ENUM: { [string]: number } = { IDLE = 20, CHASE = 21, WINDUP = 22, RECOVERY = 23, RESET = 24, PATROL = 25 }
-- One reused wire record per sim entity (weak keys, so despawned entities drop out). The encoder only
-- reads these fields, so cloning the whole sim table every snapshot was wasted allocation.
local SnapshotRecords: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local function broadcastReplicationSnapshot(now: number)
 SnapshotSequence=(SnapshotSequence+1)%4294967296
 local serverNow=Workspace:GetServerTimeNow()
 local byFloor={}
 for _,collection in {ActiveHeroesByNetId,ActiveMobsByNetId} do for _,e in pairs(collection) do
  if e.IsAlive==false then continue end
  local room=Tower.GetRoom(e.FloorId)
  if not room or room.RoomGeneration~=e.RoomGeneration then continue end
  if not Protocol.InBounds(e.Position,room.Origin,room.Bounds) then
   warn("Tower entity recovered outside bounds",e.NetId);e.Position=room.Arrival.Position-Vector3.new(0,3.5,0);HeroNavigation.Clear(e)
  end
  local hero=e.Owner~=nil
  local entry=SnapshotRecords[e];if not entry then entry={};SnapshotRecords[e]=entry end
  entry.NetId=e.NetId;entry.EntityGeneration=e.EntityGeneration;entry.Position=e.Position;entry.Yaw=e.Yaw
  entry.CurrentHP=e.CurrentHP;entry.MaxHP=e.MaxHP;entry.Stamina=e.Stamina;entry.ActionSequence=e.ActionSequence
  entry.StateEnum=hero and (STATE_TO_ENUM[e.State] or 1) or (e.TowerEnemy and ENEMY_STATE_TO_ENUM[e.State] or (10+(e.Phase or 1)))
  entry.Flags=hero and (1+(now<e.OverdriveUntil and 2 or 0)+(now<e.PacifiedUntil and 4 or 0))
   or (e.TowerEnemy and (((SupportRules.Shielded(e,serverNow) or (e.AffixShield or 0)>0) and 8 or 0)+(SupportRules.Roused(e,serverNow) and 16 or 0)
    +(AffixRules.IsAffixed(e) and 32 or 0))) or 0
  local list=byFloor[e.FloorId];if not list then list={};byFloor[e.FloorId]=list end
  table.insert(list,entry)
 end end
 -- Encode once per floor + room generation; players there differ only by ViewEpoch in the header.
 local encoded={}
 for _,p in Players:GetPlayers() do
  local c=Tower.Context(p)
  local key=`{c.FloorId}:{c.RoomGeneration}`
  local shared=encoded[key]
  if not shared then
   shared={ViewEpoch=c.ViewEpoch,Packets=Protocol.Encode(c,byFloor[c.FloorId] or {},SnapshotSequence,serverNow)}
   encoded[key]=shared
  end
  local packets=if shared.ViewEpoch==c.ViewEpoch then shared.Packets else Protocol.WithViewEpoch(shared.Packets,c.ViewEpoch)
  for _,packet in packets do TowerRemotes.TowerSnapshot:FireClient(p,packet) end
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

local function resetPlayerTowerEncounter(player: Player, reason: string?)
	local progress = ActivePlayerProgress[player]
	local state = Tower.GetState(player)
	local floorId = (progress and progress.FloorId) or (state and state.FloorId) or 0
	ActivePlayerProgress[player] = nil

	if floorId > 0 and Encounters then
		local others = 0
		for p, _ in pairs(ActiveMasters) do
			if p ~= player and p.Parent == Players and Tower.GetState(p).FloorId == floorId then
				others += 1
			end
		end
		if others == 0 then
			Encounters:ClearFloorBoss(floorId)
		end
	end

	if FloorProgressRemote and player.Parent == Players then
		FloorProgressRemote:FireClient(player, TowerProgress.CreateProgress(0))
	end
end

-- Phase H: when a floor's boss falls, two portals rise at the back of the Apex (TowerLayout.PortalSpots),
-- built with TowerPortalKit in the biome's colours: Ascend (or Return to Hub on floor 50) and Rerun,
-- which sends the Master back to this floor's Sanctuary with a fresh kill counter. Both need the Master
-- to have cleared this floor themselves; both are hold-to-use prompts with a debounce.
local function spawnFloorAscensionPortal(floorId: number, _position: Vector3?)
	local room = Tower.GetRoom(floorId)
	if not room or not room.Model then return end
	if room.Model:FindFirstChild("FloorAscensionPortal") then return end
	local floorSpec = TowerRewards.Get(floorId)
	if not floorSpec then return end

	local nextFloorId = floorId + 1
	local isMaxFloor = floorId >= 50
	local theme = TowerRoomBuilder.Theme(floorSpec.BiomeId)
	local stone, gold = TowerPortalKit.Palette(theme)
	local spots = TowerLayout.PortalSpots(floorSpec.IndexInBiome)

	local holder = Instance.new("Model")
	holder.Name = "FloorAscensionPortal"
	holder.Parent = room.Model

	local debounce: { [Player]: number } = {}
	local function travelRequest(state: any): any
		return {
			ContractVersion = 1,
			RequestId = HttpService:GenerateGUID(false),
			CharacterGeneration = state.CharacterGeneration,
			ExpectedLocationRevision = state.LocationRevision,
			ExpectedSquadRevision = state.SquadRevision,
		}
	end
	-- Shared gate: on this floor, not travelling, cleared it themselves, and not spamming.
	local function allowed(player: Player): any
		local now = os.clock()
		if (debounce[player] or 0) > now then return nil end
		debounce[player] = now + 4.0
		local state = Tower.GetState(player)
		if not state or state.FloorId ~= floorId or Tower.IsTransitioning(player) then return nil end
		local profile = getDataManager().GetProfile(player)
		if not profile or (profile.HighestClearedFloor or 0) < floorId then
			getDataManager().SendToast(player, "Defeat this floor's boss yourself to use its portals.", "WARN")
			return nil
		end
		return state
	end

	local function portal(spotName: string, glow: Color3, actionText: string, objectText: string, onUse: (Player, any) -> ())
		local spot = spots[spotName]
		local ground = HeroNavigation.Ground(room.Origin + Vector3.new(spot.X, spot.Y + 6, spot.Z), nil, 2, 12)
			or room.Origin + Vector3.new(spot.X, spot.Y, spot.Z)
		local _, trigger = TowerPortalKit.Build(holder, CFrame.new(ground), {
			Name = "BossPortal_" .. spotName,
			TriggerName = "PortalTrigger",
			Scale = PortalAssets.BossScale,
			Glow = glow,
			Stone = stone,
			Gold = gold,
			StoneMaterial = theme.TrimMaterial,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = spotName .. "Prompt"
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight = false
		prompt.Parent = trigger
		prompt.Triggered:Connect(function(player: Player)
			local state = allowed(player)
			if state then onUse(player, state) end
		end)
	end

	portal("Ascend", theme.LightColor, if isMaxFloor then "Return to Hub" else string.format("Ascend to Floor %d", nextFloorId), "Floor Portal",
		function(player, state)
			if isMaxFloor then
				Tower.ReturnToHub(player, travelRequest(state))
			else
				Tower.VisitFloor(player, nextFloorId, travelRequest(state))
			end
		end)

	portal("Rerun", Color3.fromRGB(120, 245, 150), string.format("Rerun Floor %d", floorId), "Floor Portal",
		function(player, state)
			-- Rerunning the floor revives KO'd heroes just like transitioning floors.
			reviveDownedOnTransition(player)
			-- A fresh kill counter for this floor, no leftover surge pack, then back to the Sanctuary.
			local progress = TowerProgress.CreateProgress(floorId)
			ActivePlayerProgress[player] = progress
			if FloorProgressRemote then FloorProgressRemote:FireClient(player, progress) end
			local ledger = Tower.Encounters and Tower.Encounters[floorId]
			if ledger and ledger.Surge then
				for netId, m in pairs(ledger.Surge) do
					if m.SummonedByUserId == player.UserId then
						ActiveMobsByNetId[netId] = nil
						ledger.Surge[netId] = nil
					end
				end
			end
			getDataManager().SendToast(player, string.format("Rerunning Floor %d: the kill counter starts again.", floorId), "INFO")
			Tower.VisitFloor(player, floorId, travelRequest(state))
		end)

	for _, p in Players:GetPlayers() do
		local state = Tower.GetState(p)
		if state and state.FloorId == floorId then
			getDataManager().SendToast(p, "Portals opened at the back of the Apex: Ascend or Rerun.", "SUCCESS")
		end
	end
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
  for _,entry in saved.Heroes do for _,key in {"Position","FloorId","RoomGeneration","EntityGeneration","TargetNetId","State","PacifiedUntil","ActionSequence"} do entry.Ref[key]=entry[key] end;HeroNavigation.Clear(entry.Ref);SquadMovement.Reset(entry.Ref.Owner) end
 end,
 CanRecall=function(player) local m=ActiveMasters[player];return m~=nil and os.clock()-m.LastRecallClock>=RECALL_COOLDOWN end,
  Transfer=function(player,room,recall,anchor)
   local m=ActiveMasters[player];if not m then return end
   SquadMovement.Reset(player)
   m.FocusedTargetNetId=nil;m.TargetEnemyUserId=nil
   if recall then m.LastRecallClock=os.clock();ProgressionActivity[player]=os.clock() end
   local changedFloor=false
   for _,h in pairs(m.DeployedHeroes) do
    if h.FloorId~=room.FloorId then changedFloor=true end
    h.FloorId=room.FloorId;h.RoomGeneration=room.RoomGeneration;h.EntityGeneration+=1
    local spawnBase = anchor or (if room.FloorId > 0 then getAssignedSpawnRoot(room) else room.Arrival.Position)
    h.Position=HeroNavigation.PlaceNear(spawnBase,getFormationOffset(h.SlotIndex))
    h.TargetNetId=nil;h.TargetId=nil;h.IsFocusTarget=false;h.RecallOverride=true
    if h.CurrentHP > 0 and h.State ~= "COMA" then
     h.State = "FOLLOW_MASTER"
    else
     h.State = "COMA"
    end
    h.PacifiedUntil=os.clock()+2;h.ActionSequence=0;HeroNavigation.Clear(h)
    for _,other in pairs(ActiveHeroesByNetId) do if other.TargetNetId==h.NetId then other.TargetNetId=nil;if other.CurrentHP > 0 and other.State ~= "COMA" then other.State="FOLLOW_MASTER" end end end
   end
   if room.FloorId == 0 then
    resetPlayerTowerEncounter(player, "EXIT_TO_HUB_OR_PLOT")
    restoreSquadOnPlot(player)
   else
    -- Moving between floors revives downed heroes at a fraction of their HP; it no longer heals anyone
    -- (same-floor recalls do nothing). The tower sanctuary is where standing heroes recover.
    if changedFloor then
     reviveDownedOnTransition(player)
    end
    local existing = ActivePlayerProgress[player]
    if not existing or existing.FloorId ~= room.FloorId or changedFloor then
     local progress = TowerProgress.CreateProgress(room.FloorId)
     ActivePlayerProgress[player] = progress
     if FloorProgressRemote then
      FloorProgressRemote:FireClient(player, progress)
     end
    else
     if existing.CurrentKills >= existing.RequiredKills and not existing.BossDefeated then
      local activeBoss = Encounters and Encounters:GetActiveBoss(room.FloorId)
      if not activeBoss then
       summonFloorBoss(player, existing)
      end
     end
     if FloorProgressRemote then
      FloorProgressRemote:FireClient(player, existing)
     end
    end
   end
   syncSquadStatus(player)
  end,
 Pins=function(id,gen)
  if Encounters and Encounters:Pins(id,gen) then return true end
  return false
 end,
 ResetPlayerTowerEncounter=resetPlayerTowerEncounter,
 Bootstrap=sendBootstrap,BootstrapAll=bootstrapAll,
})
if RunService:IsStudio() then CombatSimulation.DebugEntities=function() return ActiveHeroesByNetId,ActiveMobsByNetId end end
if RunService:IsStudio() then
 -- Phase 0 harness invokes the unchanged native state machine with isolated actors.
 CombatSimulation.DebugStepHero=stepHeroSimulation
 CombatSimulation.DebugStuckTracking=function(netId: number)
  return HeroNavigation.DebugTracking(netId)
 end
end

Encounters=EncounterRuntime.new({Tower=Tower,Heroes=ActiveHeroesByNetId,Mobs=ActiveMobsByNetId,Navigation=HeroNavigation,Allocate=allocateNetId,
 Changed=bootstrapAll,
 Announce=function(floorId,text)
  for _,p in Players:GetPlayers() do
   local s=Tower.GetState(p)
   if s and s.FloorId==floorId then getDataManager().SendToast(p,text,"WARN") end
  end
 end,
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
      local eventMods = (mob :: any).EventMods -- stamped at spawn by a timed tower event (Phase G)
      local killGold = math.round(reward.Gold * marketMult * AffixRules.GoldMultiplierFor(mob) * (eventMods and eventMods.GoldMult or 1))
      profile.Currencies.Gold += killGold
      profile.Currencies.Gems += reward.Gems
      TowerRuns.AddEarnings(killer, killGold, reward.Gems, if masterHere then 1 else 0)
      local stones = TowerRewards.RollPromotionStones(mob.FloorId, mob.Role, math.random(), math.random())
      if stones > 0 then
       profile.PitMaterials = profile.PitMaterials or {}
       profile.PitMaterials.PromotionStone = (profile.PitMaterials.PromotionStone or 0) + stones
       dm.SendToast(killer, string.format("✨ +%d Promotion Stone%s dropped from %s!", stones, if stones == 1 then "" else "s", mob.DisplayName or "Elite"), "SUCCESS")
      end
      dm.SyncProfile(killer)
      -- An affixed Elite (Phase F) drops relics far more often; tiers stay by role, so Cores stay Elite-only.
      local tier = TowerRewards.RollRelic(mob.FloorId, mob.Role, AffixRules.DropRoll(mob, math.random()), math.random(), eventMods)
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
     if progress and progress.FloorId == mob.FloorId and not (mob :: any).NoKillCredit then
      local stamped = (mob :: any).EventMods
      local shouldSpawn = TowerProgress.RecordKill(progress, mob.Role, stamped and stamped.KillMult or nil)
      if not shouldSpawn and TowerProgress.CheckSurge(progress) then
       Encounters:SpawnSurge(mob.FloorId, killer, mob.Position)
       getDataManager().SendToast(killer, "A surge pack is bearing down on your squad!", "WARN")
      end
      local activeBoss = Encounters and Encounters:GetActiveBoss(mob.FloorId)
      if (shouldSpawn or (progress.CurrentKills >= progress.RequiredKills and not activeBoss and not progress.BossDefeated)) then
       summonFloorBoss(killer, progress)
      end
      if FloorProgressRemote then
       FloorProgressRemote:FireClient(killer, progress)
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
       local bossEventMods = (mob :: any).EventMods
       local bossGold = math.round(reward.Gold * marketMult * (if firstClear then 3 else 1) * (bossEventMods and bossEventMods.GoldMult or 1))
       -- Kill gems: Biome Bosses pay the BOSS rate, other floor bosses the ALPHA rate, plus first-clear bonuses.
       local bossGems = TowerRewards.GetKillRewards(mob.FloorId, if bossTier > 0 then "BOSS" else "ALPHA").Gems
       if firstClear then bossGems += 10 + 2 * mob.FloorId end
       if firstBiomeClear then bossGems += 300 * bossTier end
       local stoneRole = if bossTier > 0 then "BOSS" else "ALPHA"
       local bossStones = if firstClear
        then TowerRewards.GetFirstClearPromotionStones(mob.FloorId, stoneRole)
        else TowerRewards.RollPromotionStones(mob.FloorId, stoneRole, math.random(), math.random())
       if profile then
        profile.Currencies.Gold += bossGold
        profile.Currencies.Gems += bossGems
        if bossStones > 0 then
         profile.PitMaterials = profile.PitMaterials or {}
         profile.PitMaterials.PromotionStone = (profile.PitMaterials.PromotionStone or 0) + bossStones
        end
        profile.HighestClearedFloor = math.max(profile.HighestClearedFloor or 0, mob.FloorId)
        profile.MaxFloorReached = math.max(profile.MaxFloorReached or 0, mob.FloorId + 1)
        dm.SyncProfile(p)
        if dm.ReportProgress then dm.ReportProgress(p, "FloorCleared") end
        TowerRuns.AddEarnings(p, bossGold, bossGems, 0)
        TowerRuns.RecordFloorClear(p, mob.FloorId, firstClear)
        CombatSimulation.RefreshPlayerHeroStats(p) -- a new highest floor raises the Rift Attunement cap
       end

       -- One contested relic roll per boss kill, tagged to the killer: guaranteed on a first clear, the boss's drop
       -- chance afterwards. Alphas (floors 1-4 of a biome) and Biome Bosses drop the Calamity Heart; a first
       -- Biome Boss clear pays at least a Cursed Urn.
       if p == killer and _G.RelicService then
        local relicRole = if bossTier > 0 then "BOSS" else "ALPHA"
        local relicTier = TowerRewards.RollRelic(mob.FloorId, relicRole, if firstClear then 0 else math.random(), math.random(),
         bossEventMods) -- Stamped at spawn (Alpha Hunt raises the Heart share; Calamity Hour raises tiers)
        if relicTier and firstBiomeClear then
         local biome = RelicConfig.GetBiomeForFloor(mob.FloorId)
         if biome and relicTier == biome.DropTable[1] then
          relicTier = biome.DropTable[2]
         elseif relicTier == "MANA_GEODE" then
          relicTier = "CURSED_URN"
         end
        end
        if relicTier then _G.RelicService.SpawnRelic(relicTier, mob.Position, p.UserId) end
       end

       if bossTier > 0 then
        dm.RecordBiomeBossClear(p, bossTier)
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

       local stoneText = if bossStones > 0 then string.format(", +%d Promotion Stone%s", bossStones, if bossStones == 1 then "" else "s") else ""
       dm.SendToast(p, string.format("Floor %d Boss Defeated! Unlocked Floor %d! (+%d Gold, +%d Gem%s)", mob.FloorId, mob.FloorId + 1, bossGold, bossGems, stoneText), "SUCCESS")
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
	-- A respawned thief keeps the [Loot Thief] nameplate until the flag runs out.
	task.spawn(function()
		if char:WaitForChild("Head", 5) and player.Character == char then
			applyThiefTag(player)
		end
	end)
end

local function handlePlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		SquadMovement.Reset(player)
		bindCharacterCargoListeners(player, char)
	end)
	if player.Character then
		bindCharacterCargoListeners(player, player.Character)
	end
	player.CharacterRemoving:Connect(function()
		SquadMovement.Reset(player)
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
	LastChallengeRequest[player] = nil
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
	SquadMovement.Reset(player)
	lastMasterPolicyClock[player] = nil
	MasterVelocityTracking[player] = nil
end)

local accumulator = 0.0
local function stepCombatHeartbeat(deltaTime: number)
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
	debug.profilebegin("CombatSim.Encounters")
	Encounters:Tick(dt)
	debug.profileend()

	for player in pairs(ActiveMasters) do
		local rootPos = getMasterRootPosition(player)
		if rootPos then
			local prev = MasterVelocityTracking[player]
			if prev and dt > 0.001 then
				local stepHoriz = getHorizontalDistance(rootPos, prev.LastPos)
				local instSpeed = stepHoriz / dt
				-- Ignore cross-room / recall teleports (> 120 studs/s) when estimating movement velocity
				if instSpeed <= 120.0 then
					prev.HorizontalSpeed = instSpeed
				else
					prev.HorizontalSpeed = 0.0
				end
				prev.LastPos = rootPos
				prev.LastClock = now
			else
				MasterVelocityTracking[player] = { LastPos = rootPos, LastClock = now, HorizontalSpeed = 0.0 }
			end
		else
			MasterVelocityTracking[player] = nil
		end
		lastMasterPolicyClock[player] = now
		updateMasterMovementPolicy(player, dt, now)
	end

	debug.profilebegin("CombatSim.Heroes")
	for _, simHero in pairs(ActiveHeroesByNetId) do
		stepHeroSimulation(simHero, dt, now)
		-- Phase 6: the tower sanctuary is where standing heroes recover. Downed heroes only stand back up on a transition.
		if simHero.FloorId > 0 and simHero.State ~= "COMA" and simHero.CurrentHP > 0 and simHero.CurrentHP < simHero.MaxHP
			and not simHero.DuelId and Tower.GetSafety(simHero, simHero.Position).CanRecoverWipe == true then
			simHero.CurrentHP = math.min(simHero.MaxHP, simHero.CurrentHP + simHero.MaxHP * TowerHardcore.SanctuaryHealPerSecond * dt)
		end
	end
	debug.profileend()
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
		debug.profilebegin("CombatSim.Snapshot")
		broadcastReplicationSnapshot(now)
		debug.profileend()
	end
end
RunService.Heartbeat:Connect(function(deltaTime: number)
	debug.profilebegin("CombatSim.Heartbeat")
	stepCombatHeartbeat(deltaTime)
	debug.profileend()
end)

local function warpSquad(player: Player, targetPos: Vector3, isIsland: boolean)
	SquadMovement.Reset(player)
	local masterState = ActiveMasters[player]
	if not masterState then return end
	masterState.FocusedTargetNetId = nil
	masterState.TargetEnemyUserId = nil
	for _, h in pairs(masterState.DeployedHeroes) do
		h.FloorId = 0
		h.RoomGeneration = 1
		h.EntityGeneration += 1
		h.Position = HeroNavigation.PlaceNear(targetPos, getFormationOffset(h.SlotIndex))
		h.TargetNetId = nil
		if h.CurrentHP > 0 and h.State ~= "COMA" then
			h.State = "FOLLOW_MASTER"
		else
			h.State = "COMA"
		end
		h.PacifiedUntil = os.clock() + 2
		h.ActionSequence = 0
		HeroNavigation.Clear(h)
		for _, other in pairs(ActiveHeroesByNetId) do
			if other.TargetNetId == h.NetId then
				other.TargetNetId = nil
				if other.CurrentHP > 0 and other.State ~= "COMA" then
					other.State = "FOLLOW_MASTER"
				end
			end
		end
	end
	if isIsland then
		restoreSquadOnPlot(player)
	end
	resetPlayerTowerEncounter(player, if isIsland then "WARP_ISLAND" else "WARP_HUB")
end

local function isPlayerInDuel(player: Player): boolean
	return DuelByPlayer[player] ~= nil
end

local function isBossLocked(player: Player, floorId: number): boolean
	local boss = Encounters and Encounters:GetActiveBoss(floorId)
	if not boss then return false end
	if ((boss.DamageLedger and boss.DamageLedger[player.UserId]) or 0) <= 0 then return false end
	local m = ActiveMasters[player]
	return m ~= nil and not m.IsSquadWiped
end

CombatSimulation.Contests = Contests
CombatSimulation.StartDuel = startDuel
CombatSimulation.WarpSquad = warpSquad
CombatSimulation.IsInDuel = isPlayerInDuel
CombatSimulation.IsBossLocked = isBossLocked
CombatSimulation.RestoreSquadOnPlot = restoreSquadOnPlot
-- Timed tower events reset every camp on the floors they touch (TowerEventService). Server only.
CombatSimulation.ResetTowerCamps = function(floors: { number }): number
	if not Encounters then return 0 end
	local now = os.clock()
	local removed = 0
	for _, floorId in floors do removed += Encounters:ResetCamps(floorId, now) end
	return removed
end
CombatSimulation.ResetPlayerTowerEncounter = resetPlayerTowerEncounter
_G.CombatSimulation = CombatSimulation
