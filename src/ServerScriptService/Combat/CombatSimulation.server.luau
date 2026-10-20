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
local ArtPackVisuals = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ArtPackVisuals"))

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

local WORLD_BOSS_ORIGIN = Vector3.new(0, 16, 0)
local NOVA_INTERVAL = 20.0
local NOVA_TELEGRAPH_DURATION = 3.0
local NOVA_BLAST_RADIUS = 85.0
local NOVA_PUNISH_DURATION = 5.0
local NOVA_PUNISH_DAMAGE_MULT = 1.25
local COMA_DURATION_DEFAULT = 60

export type HeroSimState = "FOLLOW_MASTER" | "MOVE_TO_TARGET" | "ATTACKING" | "COMA"

export type SimHero = {
	NetId: number,
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
}

export type SimMob = {
	NetId: number,
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
	NextNetId = (NextNetId % 60000) + 1
	return id
end

local ActiveMasters: { [Player]: MasterCombatState } = {}
local ActiveHeroesByNetId: { [number]: SimHero } = {}
local ActiveMobsByNetId: { [number]: SimMob } = {}
local ActiveWorldBoss: SimMob? = nil
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
		})
	end
	for netId, m in pairs(ActiveMobsByNetId) do
		if m.IsAlive then
			table.insert(meta, {
				NetId = netId,
				IsHero = false,
				SpecId = m.SpecId,
				MobType = m.MobType,
				Name = m.DisplayName,
				RingIndex = m.RingIndex,
				MaxHP = m.MaxHP,
				Phase = m.Phase,
			})
		end
	end
	return meta
end

local function broadcastMetadata(targetPlayer: Player?)
	local payload = buildMetadataTable()
	if targetPlayer then
		EntityMetadataRemote:FireClient(targetPlayer, payload)
	else
		EntityMetadataRemote:FireAllClients(payload)
	end
end

local LastMetadataRequestByPlayer: { [Player]: number } = {}
EntityMetadataRemote.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	local lastRequest = LastMetadataRequestByPlayer[player]
	if lastRequest and now - lastRequest < 0.5 then
		return
	end
	LastMetadataRequestByPlayer[player] = now
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

	local masterPos = getMasterRootPosition(player) or Vector3.new(0, 14, -510)
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

	-- Remove heroes no longer deployed
	for uuid, simHero in pairs(masterState.DeployedHeroes) do
		if not desiredUUIDs[uuid] then
			ActiveHeroesByNetId[simHero.NetId] = nil
			masterState.DeployedHeroes[uuid] = nil
		end
	end

	-- Add or update deployed heroes
	for uuid, slotIndex in pairs(desiredUUIDs) do
		local heroData = profile.Heroes[uuid]
		local effATK, effHP, _ = StatFormulas.GetEffectiveCombatStats(heroData, false, false)
		local existing = masterState.DeployedHeroes[uuid]
		if existing then
			existing.Stars = heroData.Stars
			existing.Level = heroData.Level
			existing.EffectiveATK = effATK
			existing.MaxHP = effHP
			existing.CurrentHP = math.min(existing.CurrentHP, effHP)
			existing.Stamina = heroData.CurrentStamina
			existing.SlotIndex = slotIndex
		else
			local netId = allocateNetId()
			local spawnPos = masterPos + getFormationOffset(slotIndex)
			local newSim: SimHero = {
				NetId = netId,
				Owner = player,
				HeroUUID = uuid,
				TemplateId = heroData.TemplateId,
				DisplayName = heroData.DisplayName,
				Stars = heroData.Stars,
				Level = heroData.Level,
				State = "FOLLOW_MASTER",
				Position = Vector3.new(spawnPos.X, getGroundHeightForRadius(Vector2.new(spawnPos.X, spawnPos.Z).Magnitude), spawnPos.Z),
				Yaw = 0,
				CurrentHP = effHP,
				MaxHP = effHP,
				EffectiveATK = effATK,
				AttackRange = heroData.AttackRange or 6,
				AttackInterval = heroData.AttackInterval or 0.9,
				MoveSpeed = 20.0,
				Stamina = heroData.CurrentStamina or 100.0,
				SlotIndex = slotIndex,
				TargetNetId = masterState.FocusedTargetNetId,
				AttackCooldown = 0.2,
				PacifiedUntil = 0,
				OverdriveUntil = 0,
			}
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
	part.Position = ground and (ground.Position + Vector3.new(0, part.Size.Y / 2 + 0.2, 0)) or position
	part.Parent = PhysicalLootFolder

	local now = os.clock()
	local dropped = {
		LootId = held.LootId, LootType = held.LootType, Amount = held.Amount,
		Part = part, Prompt = held.OriginalPrompt, Billboard = held.Billboard,
		KillerUserId = openLoot and 0 or held.KillerUserId,
		KillerName = openLoot and "Open" or held.KillerName,
		SpawnTime = now, DespawnTime = now + 90,
		PickupBlockedUserId = player.UserId, PickupBlockedUntil = now + 1.5,
	}
	ActiveLootDrops[held.LootId] = dropped
	if held.OriginalPrompt then
		held.OriginalPrompt.ActionText = "Hold / Carry"
		held.OriginalPrompt.Enabled = true
	end
	task.delay(90, function()
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

	ActiveHeroesByNetId[simHero.NetId] = nil
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
			local pos = Vector3.new(math.cos(angle) * r, 2.0, math.sin(angle) * r)
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
			local pos = Vector3.new(math.cos(angle) * r, 4.0, math.sin(angle) * r)
			createSimMob(group.Id, pos, "RING2_ELITE")
		end
	end
end

function CombatSimulation.SpawnWorldBoss()
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
				local _, _, dps = StatFormulas.GetEffectiveCombatStats(h, false, false)
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

	local warden = createSimMob("boss_rift_warden", Vector3.new(0, 16, 22), "RIFT_BOSS")
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

-- Connect Physical Rift Lure Obelisk Prompt on Ring 3
local ring3 = Workspace:WaitForChild("ArenaRings"):WaitForChild("Ring3_CenterBossAltar")
local obelisk = ring3:FindFirstChild("RiftLureObelisk")
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
	local loot = ActiveLootDrops[lootId]
	if not loot or not loot.Part or not loot.Part.Parent then
		return
	end

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

	CombatVFXRemote:FireAllClients("LOOT_PICKUP", hrp.Position)

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

	local lootData = {
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

local function handleMobDeath(mob: SimMob, killerPlayer: Player)
	local dm = getDataManager()
	mob.IsAlive = false

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
	local atkR = math.sqrt(atkPos.X * atkPos.X + atkPos.Z * atkPos.Z)
	if atkR > 460 then
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
		if targetMob and targetMob.IsAlive then
			if getHorizontalDistance(masterPos, targetMob.Position) <= 95 then
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
		CombatVFXRemote:FireAllClients("WHISTLE_Q", masterPos)
		dm.SyncProfile(player)

	elseif commandCode == 2 then
		-- [E] EMERGENCY RECALL WHISTLE (6s CD, instant warp to Master + 2s aggro drop)
		if (now - masterState.LastRecallClock) < RECALL_COOLDOWN then
			return
		end
		masterState.LastRecallClock = now
		masterState.FocusedTargetNetId = nil

		for _, simHero in pairs(masterState.DeployedHeroes) do
			if simHero.State ~= "COMA" then
				local offset = getFormationOffset(simHero.SlotIndex)
				local newPos = masterPos + offset
				local r = math.sqrt(newPos.X * newPos.X + newPos.Z * newPos.Z)
				simHero.Position = Vector3.new(newPos.X, getGroundHeightForRadius(r), newPos.Z)
				simHero.TargetNetId = nil
				simHero.State = "FOLLOW_MASTER"
				simHero.PacifiedUntil = now + RECALL_PACIFY_DURATION
			end
		end
		CombatVFXRemote:FireAllClients("WHISTLE_E", masterPos)
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
				if dist <= 120 then
					local dir = (simHero.Position - WORLD_BOSS_ORIGIN)
					local unitXZ = Vector3.new(dir.X, 0, dir.Z)
					unitXZ = (unitXZ.Magnitude > 0.01) and unitXZ.Unit or Vector3.new(1, 0, 0)
					local p = WORLD_BOSS_ORIGIN + (unitXZ * 15.0)
					simHero.Position = Vector3.new(p.X, 16.0, p.Z)
				end
			end
		end

		BossTelegraphRemote:FireAllClients(
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

		BossTelegraphRemote:FireAllClients(
			2, -- 2 = CORE_EXPOSED_PUNISH_WINDOW (5.0s +25% DMG!)
			Vector2int16.new(0, 0),
			NOVA_BLAST_RADIUS,
			math.round(NOVA_PUNISH_DURATION * 1000)
		)

		-- Check Heroes inside R <= 85 studs ("Greed vs. Coma")
		local toComa = {}
		for _, simHero in pairs(ActiveHeroesByNetId) do
			if simHero.State ~= "COMA" then
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
				if mPos and getHorizontalDistance(mPos, WORLD_BOSS_ORIGIN) <= NOVA_BLAST_RADIUS then
					_G.RelicService.FumbleRelicOnAoEHit(p)
				end
			end
		end
	end
end

local function stepMobAndEliteAoEs(mob: SimMob, dt: number, now: number)
	if not mob.IsAlive then
		if mob.RespawnAt > 0 and now >= mob.RespawnAt then
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
				if mPos and getHorizontalDistance(mPos, mob.Position) <= 35 then
					hasNearby = true
					break
				end
			end
			if hasNearby then
				mob.AoEDetonateTime = now + castDuration
				mob.NextAoECastTime = now + cooldown
				BossTelegraphRemote:FireAllClients(
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
				if getHorizontalDistance(simHero.Position, mob.Position) <= mob.AoERadius then
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
					if mPos and getHorizontalDistance(mPos, mob.Position) <= mob.AoERadius then
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
		if mob and mob.IsAlive then
			return mob.Position, mob, nil
		end
		local enemyHero = ActiveHeroesByNetId[targetNetId]
		if enemyHero and enemyHero.State ~= "COMA" and enemyHero.CurrentHP > 0 then
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
				if h.State ~= "COMA" and h.CurrentHP > 0 then
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
	local masterPos = getMasterRootPosition(simHero.Owner)
	if not masterPos then
		return
	end

	local dm = getDataManager()
	local profile = dm.GetProfile(simHero.Owner)
	if profile and profile.Heroes[simHero.HeroUUID] then
		local effATK, effHP, _ = StatFormulas.GetEffectiveCombatStats(profile.Heroes[simHero.HeroUUID], false, false)
		simHero.EffectiveATK = effATK
		simHero.MaxHP = effHP
	end

	local masterState = ActiveMasters[simHero.Owner]
	local maxLeash = (masterState and masterState.TargetEnemyUserId ~= nil) and 150.0 or LEASH_DISTANCE
	if getHorizontalDistance(simHero.Position, masterPos) > maxLeash then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

	local isPacified = now < simHero.PacifiedUntil
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
		local nearestDist = 30.0
		local nearestMobId: number? = nil
		for netId, mob in pairs(ActiveMobsByNetId) do
			if mob.IsAlive then
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
		local goalPos = masterPos + getFormationOffset(simHero.SlotIndex)
		local delta = goalPos - simHero.Position
		local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if dist > 0.5 then
			local stepDist = math.min(dist, currentMoveSpeed * dt)
			local dir = Vector3.new(delta.X, 0, delta.Z).Unit
			local nextXZ = simHero.Position + (dir * stepDist)
			local r = math.sqrt(nextXZ.X * nextXZ.X + nextXZ.Z * nextXZ.Z)
			simHero.Position = Vector3.new(nextXZ.X, getGroundHeightForRadius(r), nextXZ.Z)
			simHero.Yaw = math.atan2(-dir.X, -dir.Z)
		end
		return
	end

	local distToTarget = getHorizontalDistance(simHero.Position, targetPos)
	if distToTarget > simHero.AttackRange then
		simHero.State = "MOVE_TO_TARGET"
		local delta = targetPos - simHero.Position
		local dir = Vector3.new(delta.X, 0, delta.Z).Unit
		local stepDist = math.min(distToTarget - (simHero.AttackRange * 0.85), currentMoveSpeed * dt)
		local nextXZ = simHero.Position + (dir * math.max(0, stepDist))
		local r = math.sqrt(nextXZ.X * nextXZ.X + nextXZ.Z * nextXZ.Z)
		simHero.Position = Vector3.new(nextXZ.X, getGroundHeightForRadius(r), nextXZ.Z)
		simHero.Yaw = math.atan2(-dir.X, -dir.Z)
	else
		simHero.State = "ATTACKING"
		local delta = targetPos - simHero.Position
		if delta.Magnitude > 0.01 then
			simHero.Yaw = math.atan2(-delta.X, -delta.Z)
		end

		local drainRate = getZoneStaminaDrainPerSec(simHero.Position)
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
				targetMob.CurrentHP = math.max(0, targetMob.CurrentHP - damage)
				targetMob.DamageLedger[simHero.Owner.UserId] = (targetMob.DamageLedger[simHero.Owner.UserId] or 0) + damage

				CombatVFXRemote:FireAllClients("HIT_SPARK", targetMob.Position, damage, isOverdrive)

				if targetMob.CurrentHP <= 0 then
					simHero.TargetNetId = nil
					simHero.State = "FOLLOW_MASTER"
					handleMobDeath(targetMob, simHero.Owner)
				end
			elseif targetEnemyHero then
				local pvpDamage = math.max(1, math.round(damage * 0.25))
				targetEnemyHero.CurrentHP = math.max(0, targetEnemyHero.CurrentHP - pvpDamage)
				CombatVFXRemote:FireAllClients("HIT_SPARK", targetEnemyHero.Position, pvpDamage, isOverdrive)

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
	local entities: { any } = {}
	for _, h in pairs(ActiveHeroesByNetId) do
		table.insert(entities, { IsHero = true, Ref = h })
	end
	for _, m in pairs(ActiveMobsByNetId) do
		if m.IsAlive then
			table.insert(entities, { IsHero = false, Ref = m })
		end
	end

	local count = math.min(#entities, 255)
	local buf = buffer.create(5 + (count * 12))
	buffer.writeu8(buf, 0, count)
	buffer.writef32(buf, 1, now)

	local offset = 5
	for i = 1, count do
		local entry = entities[i]
		local e = entry.Ref
		buffer.writeu16(buf, offset + 0, e.NetId)
		buffer.writei16(buf, offset + 2, math.clamp(math.round(e.Position.X * 10), -32767, 32767))
		buffer.writei16(buf, offset + 4, math.clamp(math.round(e.Position.Z * 10), -32767, 32767))

		local yawByte = math.clamp(math.round(((e.Yaw or 0) + math.pi) / (2 * math.pi) * 255), 0, 255)
		buffer.writeu8(buf, offset + 6, yawByte)

		local stateByte = entry.IsHero and (STATE_TO_ENUM[e.State] or 1) or (10 + (e.Phase or 1))
		buffer.writeu8(buf, offset + 7, stateByte)

		local hpPermille = math.clamp(math.round((e.CurrentHP / math.max(1, e.MaxHP)) * 1000), 0, 1000)
		buffer.writeu16(buf, offset + 8, hpPermille)

		local staminaByte = entry.IsHero and math.clamp(math.round(e.Stamina), 0, 100) or 100
		buffer.writeu8(buf, offset + 10, staminaByte)

		local flags = 0
		if entry.IsHero then
			if now < e.OverdriveUntil then
				flags = bit32.bor(flags, 1)
			end
			if now < e.PacifiedUntil then
				flags = bit32.bor(flags, 2)
			end
		elseif e.MobType == "WORLD_BOSS" and now < e.PunishWindowUntil then
			flags = bit32.bor(flags, 4) -- Core Exposed (+25% DMG)
		end
		buffer.writeu8(buf, offset + 11, flags)
		offset += 12
	end

	ReplicationTickRemote:FireAllClients(buf)
end

-- Initialize Mobs & Loop
populateArenaMobs()

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
	LastMetadataRequestByPlayer[player] = nil
	local masterState = ActiveMasters[player]
	if masterState then
		for _, simHero in pairs(masterState.DeployedHeroes) do
			ActiveHeroesByNetId[simHero.NetId] = nil
		end
		ActiveMasters[player] = nil
	end
end)

local accumulator = 0.0
RunService.Heartbeat:Connect(function(deltaTime: number)
	accumulator += deltaTime
	if accumulator < TICK_INTERVAL then
		return
	end

	local dt = accumulator
	accumulator = 0.0
	local now = os.clock()

	if not ActiveWorldBoss and now >= NextWorldBossSpawnClock then
		CombatSimulation.SpawnWorldBoss()
	end

	for _, mob in pairs(ActiveMobsByNetId) do
		stepMobAndEliteAoEs(mob, dt, now)
	end

	for _, simHero in pairs(ActiveHeroesByNetId) do
		stepHeroSimulation(simHero, dt, now)
	end

	-- Safe Zone Banking & Recovery Loop (R >= 460)
	for player, masterState in pairs(ActiveMasters) do
		local rootPos = getMasterRootPosition(player)
		if rootPos then
			local r = math.sqrt(rootPos.X * rootPos.X + rootPos.Z * rootPos.Z)
			if r >= 460 then
				local held = CarrierToHeldLoot[player]
				if held then
					local dm = getDataManager()
					local prof = dm.GetProfile(player)
					if prof then
						if held.LootType == "GOLD" then
							prof.Currencies.Gold += held.Amount
						elseif held.LootType == "GEMS" then
							prof.Currencies.Gems += held.Amount
						end

						dm.SendToast(
							player,
							string.format("🏦 Safely Banked Field Cargo: +%d %s!", held.Amount, held.LootType),
							"SUCCESS"
						)
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

	broadcastReplicationSnapshot(now)
end)

CombatSimulation.SpawnPhysicalLoot = spawnPhysicalLoot
CombatSimulation.CollectPhysicalLoot = collectPhysicalLoot
CombatSimulation.TheftGrudges = TheftGrudges
_G.CombatSimulation = CombatSimulation
