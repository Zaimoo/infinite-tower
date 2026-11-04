--!strict
-- Server-only director. Retained slots belong to the floor, never to its viewers.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS.Shared.Config.FirstBiomeCombat)
local MobCatalog = require(RS.Shared.Config.MobCatalog)
local TowerFloorConfig = require(RS.Shared.Config.TowerFloorConfig)
local StatBalance = require(RS.Shared.Config.StatBalance)
local Timeline = require(RS.Shared.Util.AttackTimeline)
local TowerProgress = require(RS.Shared.Util.TowerProgress)
local CampWaves = require(RS.Shared.Util.CampWaves)
local TowerLayout = require(RS.Shared.Config.TowerLayout)
local CampRoster = require(RS.Shared.Util.CampRoster)
local SupportRules = require(RS.Shared.Util.SupportRules)
local PatrolPath = require(RS.Shared.Util.PatrolPath)
local AffixRules = require(RS.Shared.Util.AffixRules)
local Runtime = {}

function Runtime.new(api: any): any
	local self: any = { API = api, Metrics = { Started = 0, Impacts = 0, Canceled = 0, Deaths = 0, Hits = 0 } }
	function self:Enabled(): boolean
		if RunService:IsStudio() and workspace:GetAttribute("TowerCombatPreview") == false then return false end
		return Config.ReleaseEnabled or (RunService:IsStudio() and workspace:GetAttribute("TowerCombatPreview") == true)
	end
	function self:Safe(e)
		return api.Tower.GetSafety(e, e.Position).CombatSafe == true
	end
	function self:Targets(): any
		local targets = {}
		for _, h in pairs(api.Heroes) do
			if Timeline.Alive(h) and not h.DuelId then table.insert(targets, h) end
		end
		-- Only heroes participate in enemy targeting and area damage; duelling squads are off-limits.
		return targets
	end
	function self:PublicAction(a, kind)
		local room = api.Tower.GetRoom(a.Actor.FloorId)
		local r = {
			Kind = kind,
			Actor = table.clone(a.Actor),
			ActionSequence = a.ActionSequence,
			EnemyId = a.EnemyId,
			AttackId = a.AttackId,
			AnimationKey = a.AnimationKey,
			Target = table.clone(a.Target),
			StartServerTime = a.StartServerTime,
			WindupSeconds = a.WindupSeconds,
			TravelSeconds = a.TravelSeconds or 0,
			ImpactOffsetSeconds = a.ImpactOffsetSeconds,
			RecoverySeconds = a.RecoverySeconds,
			Origin = a.Origin - (room and room.Origin or Vector3.zero),
			Aim = a.Aim - (room and room.Origin or Vector3.zero),
			Yaw = a.Yaw,
			Shape = a.Shape,
			Radius = a.Radius,
			Range = a.Range,
			CancelReason = a.CancelReason,
		}
		return r
	end
	function self:Cancel(m, reason)
		if m.Action and Timeline.Cancel(m.Action, reason) then
			self.Metrics.Canceled += 1
			api.Send(m, self:PublicAction(m.Action, "CANCEL"))
		end
		m.Action = nil
		m.ActionSequence = 0
	end
	function self:ActiveActions(context)
		local actions = {}
		for _, m in pairs(api.Mobs) do
			if m.TowerEnemy and m.Action and api.Tower.Same(m, context) then
				table.insert(actions, self:PublicAction(m.Action, "START"))
			end
		end
		return actions
	end
	function self:BossPresentation(context)
		for _, m in pairs(api.Mobs) do
			if m.TowerEnemy and m.Role == "BOSS" and m.IsAlive and api.Tower.Same(m, context) then
				return {
					Enabled = m.IsAlive,
					NetId = m.NetId,
					FloorId = m.FloorId,
					EnemyId = m.EnemyId,
					Name = m.DisplayName,
					CurrentHP = m.CurrentHP,
					MaxHP = m.MaxHP,
					Phase = m.Phase,
				}
			end
		end
		return { Enabled = false }
	end
	function self:GetActiveBoss(floorId: number)
		for _, m in pairs(api.Mobs) do
			if m.TowerEnemy and m.Role == "BOSS" and m.FloorId == floorId and m.IsAlive then
				return m
			end
		end
		return nil
	end
	function self:SpawnBoss(floorId: number, player: any?)
		local activeBoss = self:GetActiveBoss(floorId)
		if activeBoss then
			return activeBoss
		end
		local room = api.Tower.GetRoom(floorId)
		if not room or room.Status ~= "READY" then
			return nil
		end
		local floorSpec = TowerFloorConfig.Get(floorId)
		if not floorSpec then
			return nil
		end
		local enemyId = TowerProgress.GetFloorBossEnemyId(floorId)
		local cat = MobCatalog.Get(enemyId)
		local e = table.clone(Config.Get(enemyId))
		local layout = TowerLayout.Get(floorSpec.IndexInBiome)
		local apexPlatform = layout.Platforms.Apex or layout.Platforms.Crossing or layout.Platforms.Basin
		local posX, posY, posZ = apexPlatform.X, apexPlatform.Y, apexPlatform.Z
		local homePos = api.Navigation.Ground(room.Origin + Vector3.new(posX, posY + 6, posZ), nil, 2, 12) or (room.Origin + Vector3.new(posX, posY, posZ))

		local maxHP, atk, gold = 12000, 55, 800
		local floorStats = TowerFloorConfig.GetEnemyStats(floorId, enemyId)
		if floorStats then
			maxHP = floorStats.MaxHP
			atk = floorStats.ATK
			gold = floorStats.GoldReward
		else
			local numeric = StatBalance.GetFloorStats(floorId, "BOSS")
			if numeric then
				maxHP = numeric.MaxHP
				atk = numeric.ATK
			else
				maxHP = math.round(12000 * (1.08 ^ (floorId - 1)))
				atk = math.round(55 * (1.045 ^ (floorId - 1)))
			end
			gold = math.round(800 * (1.055 ^ (floorId - 1)))
		end

		local netId = api.Allocate()
		local now = workspace:GetServerTimeNow()
		local boss = {
			NetId = netId,
			EntityGeneration = 1,
			FloorId = floorId,
			RoomGeneration = room.RoomGeneration,
			EnemyId = enemyId,
			SpecId = enemyId,
			DisplayName = e.DisplayName or (cat and cat.DisplayName) or "Floor Boss",
			TowerEnemy = true,
			Role = "BOSS",
			MobType = "RING2_ELITE",
			RingIndex = 3,
			Slot = 80000 + netId,
			LifeGeneration = 1,
			CurrentHP = maxHP,
			MaxHP = maxHP,
			ATK = atk,
			GoldReward = gold,
			IsAlive = true,
			State = "IDLE",
			Yaw = math.pi,
			Phase = 1,
			DamageLedger = {},
			Cooldowns = {},
			ActionCounter = 0,
			ActionSequence = 0,
			RespawnAt = math.huge,
			BornAt = now,
			HomePosition = homePos,
			Position = homePos,
			LocalPosition = Vector3.new(posX, posY, posZ),
			LeashRadius = 120,
			CampId = "CAMP_APEX_SANCTUM",
			SummonedByUserId = player and player.UserId or nil,
			Summoned = true,
		}

		api.Mobs[netId] = boss
		api.Send(boss, {
			Kind = "BOSS_SPAWN",
			Actor = Timeline.Identity(boss),
			EnemyId = enemyId,
			StartServerTime = now,
		})
		api.Changed()
		return boss
	end
	function self:Death(m, killer)
		if not m.IsAlive then return end
		self:Cancel(m, "ACTOR_DEATH")
		m.IsAlive = false
		m.CurrentHP = 0
		m.State = "DEAD"
		api.Navigation.Clear(m)
		local ledger = api.Tower.Encounters[m.FloorId]
		local key = tostring(m.Slot) .. ":" .. tostring(m.LifeGeneration)
		if ledger.PayoutClaims[key] then return end
		ledger.PayoutClaims[key] = true
		self.Metrics.Deaths += 1
		-- Summoned bosses and surge packs never respawn on a timer; the next one needs a fresh kill threshold.
		-- Camp members wait for the rest of their camp, then SyncRooms respawns the whole camp as a wave.
		m.DiedAt = workspace:GetServerTimeNow()
		m.RespawnAt = if m.Summoned or (m.CampId and m.Role ~= "BOSS") then math.huge else m.DiedAt + (m.Role == "BOSS" and Config.BossRespawnSeconds or Config.RespawnSeconds)
		api.Send(m, { Kind = "DEATH", Actor = Timeline.Identity(m), EnemyId = m.EnemyId, StartServerTime = workspace:GetServerTimeNow(), Duration = 1.6 })
		-- Claim before any reward/profile callback. Travel and simultaneous hits cannot retry it.
		api.Reward(m, killer)
		if AffixRules.Has(m, "SPLITTING") then self:SpawnSplit(m) end
		api.Changed()
		if m.Summoned then
			task.delay(3, function()
				if not m.IsAlive and api.Mobs[m.NetId] == m then
					api.Mobs[m.NetId] = nil
					if ledger.Surge then ledger.Surge[m.NetId] = nil end
					api.Changed()
				end
			end)
		end
	end
	-- Living affixed Elites in the same room as `m` (for WARDED and COMMANDER auras).
	function self:AffixedNear(m)
		local list = {}
		for _, o in pairs(api.Mobs) do
			if o.TowerEnemy and o.IsAlive and o.Affixes and Timeline.Same(o, m) then table.insert(list, o) end
		end
		return list
	end
	-- Affixes are a chance summon (Phase F): a camp Elite may emerge affixed each time it spawns. Any
	-- other mob is plain. Sets the name plate and announces an affixed Elite to the floor.
	-- Timed tower events (Phase G): stamp the running event's modifiers on a mob as it spawns. The mob
	-- keeps them (stats and rewards) until it dies, even if the event ends first.
	function self:StampEvent(m)
		local mods = _G.TowerEvents and _G.TowerEvents.GetMods(m.FloorId) or nil
		m.EventMods = mods
		if mods then
			m.MaxHP = math.round(m.MaxHP * (mods.HP or 1))
			m.CurrentHP = m.MaxHP
			m.ATK = math.max(1, math.round(m.ATK * (mods.ATK or 1)))
		end
		return mods
	end
	function self:RollAffixes(m, e, plan, floorSpec, now)
		local mods = self:StampEvent(m)
		local affixes = {}
		if e.Role == "ELITE" and not e.Alpha and plan and floorSpec then
			affixes = AffixRules.Roll(plan.Rng, floorSpec.BiomeIndex, mods ~= nil and mods.ForceAffix == true)
		end
		AffixRules.Prepare(m, affixes, workspace:GetServerTimeNow())
		local cat = MobCatalog.Get(m.EnemyId)
		m.DisplayName = AffixRules.DisplayName(e.DisplayName or (cat and cat.DisplayName) or m.EnemyId, affixes)
		if #affixes > 0 and api.Announce then
			api.Announce(m.FloorId, string.format("A %s has emerged! It drops relics %dx as often.", m.DisplayName, AffixRules.RelicDropMultiplier))
		end
	end
	-- SPLITTING: two Regulars of the Elite's biome step out where it fell. They never respawn and give
	-- no kill progress, so splitting cannot be farmed for boss summons.
	function self:SpawnSplit(parent)
		local room = api.Tower.GetRoom(parent.FloorId)
		local floorSpec = TowerFloorConfig.Get(parent.FloorId)
		local ledger = api.Tower.Encounters[parent.FloorId]
		if not room or room.Status ~= "READY" or not floorSpec or not ledger then return end
		local biome = MobCatalog.Biomes[floorSpec.BiomeIndex]
		ledger.Surge = ledger.Surge or {}
		for i = 1, AffixRules.SplitCount do
			local enemyId = biome.RegularEnemyIds[(i - 1) % #biome.RegularEnemyIds + 1]
			local e = Config.Get(enemyId)
			local stats = TowerFloorConfig.GetEnemyStats(parent.FloorId, enemyId)
			local side = if i == 1 then -4 else 4
			local ground = api.Navigation.Ground(parent.Position + Vector3.new(side, 6, 0), nil, 2, 12) or parent.Position
			local netId = api.Allocate()
			local now = workspace:GetServerTimeNow()
			local m = {
				NetId = netId, EntityGeneration = 1, FloorId = parent.FloorId, RoomGeneration = room.RoomGeneration,
				EnemyId = enemyId, SpecId = enemyId, DisplayName = e.DisplayName, TowerEnemy = true, Role = e.Role,
				MobType = "RING1_MOB", RingIndex = 1, Slot = 90000 + netId, LifeGeneration = 1,
				CurrentHP = stats and stats.MaxHP or e.MaxHP, MaxHP = stats and stats.MaxHP or e.MaxHP,
				ATK = stats and stats.ATK or e.ATK, GoldReward = stats and stats.GoldReward or e.Gold,
				IsAlive = true, State = "IDLE", Yaw = parent.Yaw or math.pi, Phase = 1, DamageLedger = {}, Cooldowns = {},
				ActionCounter = 0, ActionSequence = 0, RespawnAt = math.huge, BornAt = now,
				HomePosition = ground, Position = ground, LocalPosition = ground - room.Origin,
				LeashRadius = 60, CampId = "CAMP_SPLIT", Summoned = true, NoKillCredit = true,
			}
			api.Mobs[netId] = m
			ledger.Surge[netId] = m
			self:StampEvent(m)
		end
	end
	-- Placements the floor should hold right now: the layout plus scaled-in members when several Masters share it.
	function self:EffectivePlacements(floor, placements)
		local masters = if api.Tower.MastersOnFloor then api.Tower.MastersOnFloor(floor) else 1
		local floorSpec = TowerFloorConfig.Get(floor)
		if masters <= 1 or not floorSpec then return table.clone(placements) end
		return CampWaves.EffectivePlacements(floorSpec.IndexInBiome, placements, masters, function(enemyId)
			local cat = Config.Get(enemyId)
			return cat and cat.Role or nil
		end)
	end
	-- Personal surge pack: one Elite and a few Regulars step out around the squad. They never respawn.
	function self:SpawnSurge(floorId: number, player: any, anchor: Vector3)
		local room = api.Tower.GetRoom(floorId)
		local floorSpec = TowerFloorConfig.Get(floorId)
		local ledger = api.Tower.Encounters[floorId]
		if not room or room.Status ~= "READY" or not floorSpec or not ledger or floorSpec.IndexInBiome == 5 then return 0 end
		local biome = MobCatalog.Biomes[floorSpec.BiomeIndex]
		local layout = TowerLayout.Get(floorSpec.IndexInBiome)
		ledger.Surge = ledger.Surge or {}
		local roster = { biome.EliteEnemyId }
		for i = 1, Config.SurgeRegulars do table.insert(roster, biome.RegularEnemyIds[(i - 1) % 2 + 1]) end
		-- From biome 3 a support replaces the last Regular (1 Elite, 2 Regulars, 1 support).
		if floorSpec.BiomeIndex >= 3 and biome.SupportEnemyId then roster[#roster] = biome.SupportEnemyId end
		local context = { FloorId = floorId, RoomGeneration = room.RoomGeneration }
		local spawned = 0
		for _, enemyId in ipairs(roster) do
			local ground
			for _ = 1, 12 do
				local angle = math.random() * math.pi * 2
				local dist = Config.SurgeMinDistance + math.random() * (Config.SurgeMaxDistance - Config.SurgeMinDistance)
				local g = api.Navigation.Ground(anchor + Vector3.new(math.cos(angle) * dist, 6, math.sin(angle) * dist), nil, 2, 12)
				if g then
					local l = g - room.Origin
					if math.abs(l.X) < layout.Width / 2 - 8 and math.abs(l.Z) < layout.Depth / 2 - 8 and api.Tower.GetSafety(context, g).CombatSafe ~= true then
						ground = g
						break
					end
				end
			end
			local e = Config.Get(enemyId)
			if ground and e then
				e = table.clone(e)
				local stats = TowerFloorConfig.GetEnemyStats(floorId, enemyId)
				if stats then e.MaxHP, e.ATK, e.Gold = stats.MaxHP, stats.ATK, stats.GoldReward end
				if e.Support then
					e.MaxHP = math.round(e.MaxHP * SupportRules.HpScale)
					e.ATK = math.max(1, math.round(e.ATK * SupportRules.AtkScale))
				end
				local netId = api.Allocate()
				local now = workspace:GetServerTimeNow()
				local m = {
					NetId = netId, EntityGeneration = 1, FloorId = floorId, RoomGeneration = room.RoomGeneration,
					EnemyId = enemyId, SpecId = enemyId, DisplayName = e.DisplayName, TowerEnemy = true, Role = e.Role,
					MobType = if e.Role == "REGULAR" then "RING1_MOB" else "RING2_ELITE", RingIndex = if e.Role == "REGULAR" then 1 else 2,
					Slot = 70000 + netId, LifeGeneration = 1, CurrentHP = e.MaxHP, MaxHP = e.MaxHP, ATK = e.ATK, GoldReward = e.Gold,
					IsAlive = true, State = "IDLE", Yaw = math.pi, Phase = 1, DamageLedger = {}, Cooldowns = {},
					ActionCounter = 0, ActionSequence = 0, RespawnAt = math.huge, BornAt = now,
					HomePosition = ground, Position = ground, LocalPosition = ground - room.Origin,
					LeashRadius = 120, CampId = "CAMP_SURGE", SummonedByUserId = player and player.UserId or nil, Summoned = true,
				}
				api.Mobs[netId] = m
				ledger.Surge[netId] = m
				self:StampEvent(m)
				spawned += 1
			end
		end
		if spawned > 0 then api.Changed() end
		return spawned
	end
	-- The floor's camp roster (CampRoster): which Regular type each member is (every camp holds all of
	-- the biome's Regulars), which camps an Elite leads, and where each member stands. Created once per floor ledger; a camp's next wave is planned the
	-- moment its last member dies, so a camp that is fighting never changes.
	function self:Roster(floor, room, ledger)
		if ledger.Roster then return ledger.Roster end
		local floorSpec = TowerFloorConfig.Get(floor)
		local layout = TowerLayout.Get(floorSpec.IndexInBiome)
		local biome = MobCatalog.Biomes[floorSpec.BiomeIndex]
		local campIds, upper, layoutCamps = {}, {}, {}
		for _, camp in layout.Camps do
			if camp.Id ~= "APEX_SANCTUM" then
				local id = "CAMP_" .. camp.Id
				table.insert(campIds, id)
				upper[id] = camp.Platform ~= "Basin"
				layoutCamps[id] = camp
			end
		end
		local rng = CampRoster.Rng(CampRoster.Seed(floor, room.RoomGeneration, 0, 0))
		-- Supports (Phase D) start on the third floor of the first biome.
		local supportsEligible = biome.SupportEnemyId ~= nil and (floorSpec.BiomeIndex > 1 or floorSpec.IndexInBiome >= 3)
		local roster = {
			Biome = biome,
			CampIds = campIds,
			Elites = CampRoster.AssignElites(rng, campIds, layout.EliteCount, upper, floorSpec.IndexInBiome >= 3),
			SupportsEligible = supportsEligible,
			Supports = if supportsEligible then CampRoster.AssignSupports(rng, campIds) else {},
			Camps = {},
		}
		for index, id in campIds do
			local camp = layoutCamps[id]
			roster.Camps[id] = {
				Index = index, Center = Vector3.new(camp.X, camp.Y, camp.Z), Radius = camp.Radius,
				Types = {}, Bag = {}, Wave = 0, Offsets = {}, Rolled = true,
				Rng = CampRoster.Rng(CampRoster.Seed(floor, room.RoomGeneration, index, 0)),
			}
		end
		for slot, placement in ipairs(Config.Floors[floor]) do
			local plan = roster.Camps[placement.CampId]
			if plan and not plan.LeaderSlot then plan.LeaderSlot = slot end
		end
		-- Patrols (Phase E): the Basin loop on every floor, plus one other route from the third floor of a
		-- biome. Three mixed fighters walk it; from biome 4 a patrol may bring the floor's support.
		local routes = TowerLayout.PatrolRoutes(floorSpec.IndexInBiome)
		local routeIds = { "BASIN_LOOP" }
		if floorSpec.IndexInBiome >= 3 then
			local others = {}
			for id in routes do
				if id ~= "BASIN_LOOP" then table.insert(others, id) end
			end
			table.sort(others)
			if #others > 0 then table.insert(routeIds, others[math.floor(rng() * #others) + 1]) end
		end
		roster.Patrols, roster.PatrolOrder = {}, {}
		for k, routeId in routeIds do
			local id = "PATROL_" .. routeId
			local route = routes[routeId]
			local offsets = {}
			for i, o in PatrolPath.Formation do offsets[Config.PatrolSlotBase + k * 10 + i] = o end
			local patrolRng = CampRoster.Rng(CampRoster.Seed(floor, room.RoomGeneration, 100 + k, 0))
			roster.Patrols[id] = {
				Index = 100 + k, Slot = k, Route = route, Walk = PatrolPath.Start(route),
				Center = Vector3.new(route[1].X, route[1].Y, route[1].Z),
				Types = {}, Bag = {}, Wave = 0, Offsets = offsets, Rolled = true, Rng = patrolRng,
				Support = supportsEligible and floorSpec.BiomeIndex >= 4 and patrolRng() < 0.5,
			}
			table.insert(roster.PatrolOrder, id)
		end
		ledger.Roster = roster
		return roster
	end
	-- Patrols: replan a wiped patrol (fresh type mix, maybe a support, back to the route start), and
	-- walk each living patrol's anchor along its route while it is not fighting.
	function self:StepPatrols(floor, room, ledger, roster, now)
		for _, id in roster.PatrolOrder do
			local plan = roster.Patrols[id]
			local alive, engaged, settled = false, false, true
			for i = 1, #PatrolPath.Formation do
				local m = ledger.Slots[Config.PatrolSlotBase + plan.Slot * 10 + i]
				if m and m.IsAlive then
					alive = true
					if m.Action or m.State == "CHASE" or m.State == "WINDUP" or m.State == "RECOVERY" then engaged = true end
					if m.HomePosition and (m.Position - m.HomePosition).Magnitude > 6 then settled = false end
				end
			end
			local created = ledger.Slots[Config.PatrolSlotBase + plan.Slot * 10 + 1] ~= nil
			if alive or not created then
				plan.Rolled = false
			elseif not plan.Rolled then
				plan.Rolled = true
				plan.Wave += 1
				plan.Rng = CampRoster.Rng(CampRoster.Seed(floor, room.RoomGeneration, plan.Index, plan.Wave))
				plan.Types, plan.Bag = {}, {}
				plan.Support = roster.SupportsEligible and roster.Biome.SupportEnemyId ~= nil
					and (TowerFloorConfig.Get(floor) :: any).BiomeIndex >= 4 and plan.Rng() < 0.5
				plan.Walk = PatrolPath.Start(plan.Route)
			end
			local dt = math.clamp(now - (plan.LastStep or now), 0, 0.5)
			plan.LastStep = now
			if alive and not engaged and settled then
				PatrolPath.Advance(plan.Route, plan.Walk, PatrolPath.Speed * dt)
			end
			plan.Center = Vector3.new(plan.Walk.X, plan.Walk.Y, plan.Walk.Z)
		end
	end
	-- True while a Master or hero stands within `radius` of a world point on this floor.
	local function heroNear(floor, point, radius)
		for _, h in pairs(api.Heroes) do
			if h.FloorId == floor and h.Position and (h.Position - point).Magnitude <= radius then return true end
		end
		return false
	end
	-- A camp member's Regular type this wave, dealt on first use from the camp's shuffled bag.
	local function memberType(plan, slot, pool)
		local enemyId = plan.Types[slot]
		if not enemyId then
			enemyId = CampRoster.DealType(plan.Rng, plan.Bag, pool)
			plan.Types[slot] = enemyId
		end
		return enemyId
	end
	-- Where a camp member stands this wave, relative to the room origin. Rolled on first use.
	local function memberOffset(plan, slot)
		local offset = plan.Offsets[slot]
		if not offset then
			local taken = {}
			for _, other in plan.Offsets do table.insert(taken, other) end
			offset = CampRoster.RollOffsets(plan.Rng, plan.Radius, 1, 8, taken)[1]
			plan.Offsets[slot] = offset
		end
		return plan.Center + Vector3.new(offset.X, 0, offset.Z)
	end
	function self:SyncRooms(now)
		local changed = false
		for floor, placements in pairs(Config.Floors) do
			local room = api.Tower.GetRoom(floor)
			local ledger = api.Tower.Encounters[floor]
			if room and room.Status == "READY" and self:Enabled() then
				ledger.Slots = ledger.Slots or {}
				ledger.EncountersEnabled = true
				room.Model:SetAttribute("EncountersEnabled", true)
				local sign = room.Model:FindFirstChildWhichIsA("SurfaceGui", true)
				local label = sign and sign:FindFirstChildWhichIsA("TextLabel")
				if label and not room.CombatLabeled then
					local floorSpec = TowerFloorConfig.Get(floor)
					if floorSpec then
						label.Text = string.format(
							"FLOOR %d · %s\n%s · %s",
							floor,
							floorSpec.DisplayName,
							string.upper(floorSpec.BiomeDisplayName),
							string.gsub(floorSpec.VariantKind, "_", " ")
						)
					end
					room.CombatLabeled = true
				end
				local effective = self:EffectivePlacements(floor, placements)
				local roster = self:Roster(floor, room, ledger)
				-- Each camp the roster gives a support fields one more member, within the live-mob budget.
				local live = 0
				for _, placement in effective do
					if placement.CampId ~= "CAMP_APEX_SANCTUM" then live += 1 end
				end
				for campId in roster.Supports do
					local plan = roster.Camps[campId]
					if plan and live < Config.MaxLiveMobsPerFloor then
						effective[Config.SupportSlotBase + plan.Index] = {
							EnemyId = roster.Biome.SupportEnemyId, X = plan.Center.X, Y = plan.Center.Y, Z = plan.Center.Z,
							CampId = campId, LeashRadius = 60, Support = true,
						}
						live += 1
					end
				end
				self:StepPatrols(floor, room, ledger, roster, now)
				for _, id in roster.PatrolOrder do
					local plan = roster.Patrols[id]
					local size = if plan.Support then 4 else 3
					if live + size <= Config.MaxLiveMobsPerFloor then
						for i = 1, size do
							effective[Config.PatrolSlotBase + plan.Slot * 10 + i] = {
								EnemyId = roster.Biome.RegularEnemyIds[1], X = plan.Center.X, Y = plan.Center.Y, Z = plan.Center.Z,
								CampId = id, LeashRadius = Config.PatrolLeash, Patrol = id, Support = i == 4,
							}
						end
						live += size
					end
				end
				-- A camp is "alive" while any member lives (or has not been created yet). A support slot
				-- that does not exist yet does not count: it joins with the camp's next wave.
				local campAlive = {}
				local campRespawnAt = {}
				for slot, placement in effective do
					local existing = ledger.Slots[slot]
					if (not existing and not placement.Support) or (existing and existing.IsAlive) then
						campAlive[placement.CampId] = true
					elseif existing and existing.RespawnAt ~= math.huge then
						campRespawnAt[placement.CampId] = math.max(campRespawnAt[placement.CampId] or 0, existing.RespawnAt)
					end
				end
				-- A camp whose last member just died plans its next wave now: a fresh mix of Regular types,
				-- new spots, and its Elite (if any) moves to another cleared camp.
				for campId, plan in roster.Camps do
					if campAlive[campId] then
						plan.Rolled = false
					elseif not plan.Rolled then
						plan.Rolled = true
						plan.Wave += 1
						local rng = CampRoster.Rng(CampRoster.Seed(floor, room.RoomGeneration, plan.Index, plan.Wave))
						plan.Types = {}
						plan.Bag = {}
						plan.Offsets = {}
						plan.Rng = rng
						if roster.SupportsEligible then
							roster.Supports[campId] = CampRoster.RerollSupport(rng, campId, roster.Supports, #roster.CampIds) or nil
						end
						if roster.Elites[campId] then
							local cleared = {}
							for otherId in roster.Camps do cleared[otherId] = not campAlive[otherId] end
							local target = CampRoster.MoveElite(rng, campId, roster.Elites, roster.CampIds, cleared)
							if target ~= campId then
								roster.Elites[campId] = nil
								roster.Elites[target] = true
							end
						end
					end
				end
				local floorMods = _G.TowerEvents and _G.TowerEvents.GetMods(floor) or nil
				for slot, placement in effective do
					local plan = roster.Camps[placement.CampId] or roster.Patrols[placement.CampId]
					local enemyId = placement.EnemyId
					local localPos = Vector3.new(placement.X, placement.Y or 0, placement.Z)
					if plan then
						enemyId = if placement.Support then roster.Biome.SupportEnemyId
							elseif slot == plan.LeaderSlot and (roster.Elites[placement.CampId] or (floorMods and floorMods.AllCampsElite)) then roster.Biome.EliteEnemyId
							else memberType(plan, slot, roster.Biome.RegularEnemyIds)
						localPos = memberOffset(plan, slot)
					end
					local e = table.clone(Config.Get(enemyId))
					-- Bosses and Apex Sanctum encounters are never pre-placed: each floor boss/champion is summoned strictly by a player's own kill threshold (SpawnBoss).
					-- Camp Elites do spawn; a summoned champion is always Role BOSS, so they never count as it.
					if e.Role == "BOSS" or placement.CampId == "CAMP_APEX_SANCTUM" then continue end
					local floorStats = TowerFloorConfig.GetEnemyStats(floor, enemyId)
					if floorStats then
						e.MaxHP = floorStats.MaxHP
						e.ATK = floorStats.ATK
						e.Gold = floorStats.GoldReward
					else
						local numeric = StatBalance.GetFloorStats(floor, e.Role)
						if numeric then
							e.MaxHP = numeric.MaxHP
							e.ATK = numeric.ATK
						end
					end
					if e.Support then
						e.MaxHP = math.round(e.MaxHP * SupportRules.HpScale)
						e.ATK = math.max(1, math.round(e.ATK * SupportRules.AtkScale))
					end
					local m = ledger.Slots[slot]
					local joinsLater = false
					if not m then
						-- A support added to a cleared camp waits and returns with the camp's next wave.
						joinsLater = placement.Support == true and not campAlive[placement.CampId]
						local cat = MobCatalog.Get(e.EnemyId)
						m = {
							NetId = api.Allocate(),
							EntityGeneration = 0,
							FloorId = floor,
							RoomGeneration = 0,
							EnemyId = e.EnemyId,
							SpecId = e.EnemyId,
							DisplayName = e.DisplayName or (cat and cat.DisplayName) or e.EnemyId,
							TowerEnemy = true,
							Role = e.Role,
							MobType = e.Role == "REGULAR" and "RING1_MOB" or "RING2_ELITE",
							RingIndex = e.Role == "REGULAR" and 1 or 2,
							Slot = slot,
							LifeGeneration = 1,
							CurrentHP = e.MaxHP,
							MaxHP = e.MaxHP,
							ATK = e.ATK,
							GoldReward = e.Gold,
							IsAlive = true,
							State = "IDLE",
							Yaw = math.pi,
							Phase = 1,
							DamageLedger = {},
							Cooldowns = {},
							ActionCounter = 0,
							ActionSequence = 0,
							RespawnAt = 0,
							BornAt = now,
							LocalPosition = localPos,
						}
						if joinsLater then
							m.IsAlive = false
							m.CurrentHP = 0
							m.State = "DEAD"
							m.DiedAt = now
							m.RespawnAt = campRespawnAt[placement.CampId] or math.huge
						end
						if m.IsAlive then self:RollAffixes(m, e, plan, TowerFloorConfig.Get(floor), now) end
						ledger.Slots[slot] = m
						if e.Role == "BOSS" then ledger.BossGeneration = m.LifeGeneration end
					end
					m.LeashRadius = placement.LeashRadius or Config.LeashRange
					m.CampId = placement.CampId
					m.Patrol = placement.Patrol
					if placement.Patrol and m.IsAlive and m.RoomGeneration == room.RoomGeneration then
						m.HomePosition = api.Navigation.Ground(room.Origin + localPos + Vector3.new(0, 6, 0), nil, 2, 12) or room.Origin + localPos
					end
					if m.RoomGeneration ~= room.RoomGeneration then
						m.EntityGeneration += 1
						m.RoomGeneration = room.RoomGeneration
						m.HomePosition = api.Navigation.Ground(room.Origin + localPos + Vector3.new(0, 6, 0), nil, 2, 12) or room.Origin + localPos
						m.Position = if m.LastOrigin then room.Origin + m.LocalPosition else m.HomePosition
						api.Navigation.Clear(m)
					end
					if not api.Mobs[m.NetId] then
						if m.LastOrigin then m.EntityGeneration += 1 end
						api.Mobs[m.NetId] = m
						changed = true
					end
					if not m.IsAlive and m.RespawnAt == math.huge and not m.Summoned then
						m.RespawnAt = CampWaves.ScheduleRespawn(m.DiedAt, campAlive[placement.CampId] == true, now) or math.huge
						if placement.Patrol and m.RespawnAt ~= math.huge then
							m.RespawnAt += Config.PatrolRespawnSeconds - Config.CampRespawnSeconds
						elseif floorMods and floorMods.RespawnSeconds and m.RespawnAt ~= math.huge then
							m.RespawnAt += floorMods.RespawnSeconds - Config.CampRespawnSeconds
						end
					end
					-- A wiped patrol waits while anyone stands near its route start.
					if placement.Patrol and not m.IsAlive and now >= m.RespawnAt and heroNear(floor, room.Origin + localPos, Config.PatrolClearRadius) then
						m.RespawnAt = now + 2
					end
					if not m.IsAlive and now >= m.RespawnAt then
						-- The wave's plan may give this slot a new type and a new spot. The EntityGeneration
						-- bump below makes clients rebuild the model from the new metadata.
						if m.EnemyId ~= e.EnemyId then
							local cat = MobCatalog.Get(e.EnemyId)
							m.EnemyId = e.EnemyId
							m.SpecId = e.EnemyId
							m.DisplayName = e.DisplayName or (cat and cat.DisplayName) or e.EnemyId
							m.Role = e.Role
							m.MobType = e.Role == "REGULAR" and "RING1_MOB" or "RING2_ELITE"
							m.RingIndex = e.Role == "REGULAR" and 1 or 2
						end
						m.MaxHP = e.MaxHP
						m.ATK = e.ATK
						m.GoldReward = e.Gold
						m.HomePosition = api.Navigation.Ground(room.Origin + localPos + Vector3.new(0, 6, 0), nil, 2, 12) or room.Origin + localPos
						SupportRules.Reset(m)
						m.IsAlive = true
						m.CurrentHP = m.MaxHP
						self:RollAffixes(m, e, plan, TowerFloorConfig.Get(floor), now)
						m.CurrentHP = m.MaxHP
						m.Position = m.HomePosition
						m.EntityGeneration += 1
						m.LifeGeneration += 1
						m.DamageLedger = {}
						m.Cooldowns = {}
						m.State = "IDLE"
						m.Phase = 1
						m.ActionSequence = 0
						m.BornAt = now
						if e.Role == "BOSS" then ledger.BossGeneration = m.LifeGeneration end
						changed = true
					end
				end
				-- Scaled-in members that are no longer wanted leave once they are dead.
				for slot, m in pairs(ledger.Slots) do
					if slot >= Config.PatrolSlotBase and not effective[slot] and not m.IsAlive then
						if api.Mobs[m.NetId] then api.Mobs[m.NetId] = nil; changed = true end
						ledger.Slots[slot] = nil
					end
				end
			elseif ledger and ledger.Slots then
				ledger.EncountersEnabled = false
				if room and room.Model then
					room.Model:SetAttribute("EncountersEnabled", false)
					room.CombatLabeled = false
				end
				for _, m in pairs(ledger.Slots) do
					if api.Mobs[m.NetId] then
						self:Cancel(m, "ROOM_RETIRED_OR_DISABLED")
						m.LocalPosition = m.Position - (room and room.Origin or m.LastOrigin)
						api.Navigation.Clear(m)
						api.Mobs[m.NetId] = nil
						changed = true
					end
				end
				for netId, m in pairs(ledger.Surge or {}) do
					self:Cancel(m, "ROOM_RETIRED_OR_DISABLED")
					api.Mobs[netId] = nil
					ledger.Surge[netId] = nil
					changed = true
				end
			end
		end
		if changed then api.Changed() end
	end
	-- Living tower mobs in the same room as `m`, within `radius`. ROUSE's aura includes the caster.
	function self:Allies(m, radius, includeSelf)
		local allies = {}
		for _, o in pairs(api.Mobs) do
			if o.TowerEnemy and o.IsAlive and (includeSelf or o ~= m) and Timeline.Same(o, m)
				and (o.Position - m.Position).Magnitude <= radius then
				table.insert(allies, o)
			end
		end
		return allies
	end
	-- Called by the combat sim for every hero hit on a mob, before HP is taken. A WARD shield soaks
	-- what it can, and a hit during a support's cast windup interrupts the cast (its cooldown stays
	-- spent). Returns the damage left to apply.
	function self:OnMobHit(m, damage)
		if not m.TowerEnemy then return damage end
		local serverNow = workspace:GetServerTimeNow()
		damage = math.round(damage * AffixRules.AuraDefense(m, self:AffixedNear(m)))
		if m.Affixes then damage = AffixRules.Absorb(m, damage, serverNow) end
		damage = SupportRules.Absorb(m, damage, serverNow)
		if m.Action and m.Action.Status == "WINDUP" then
			local spec = Config.Get(m.EnemyId)
			local definition = spec and spec.Support and Config.Attack(m.EnemyId, m.Action.AttackId)
			if definition and definition.Shape:sub(1, 4) == "ALLY" then
				self:Cancel(m, "INTERRUPTED")
				m.State = "IDLE"
			end
		end
		return damage
	end
	-- A support's turn (no action running): cast its kit when there is something to cast on, else hold
	-- KiteGap behind its nearest ally, away from the squad. Returns false when it has no ally left, so
	-- it falls back to its weak bolt like an ordinary Regular.
	function self:StepSupport(m, e, target, targets, now, dt)
		local allies = self:Allies(m, SupportRules.AllyRange, false)
		if #allies == 0 then return false end
		local kitMove = e.Attacks[1]
		if now >= (m.Cooldowns[kitMove.Id] or 0) then
			local squad = {}
			for _, t in targets do
				if Timeline.Alive(t) and api.Tower.Same(m, t) then table.insert(squad, t.Position) end
			end
			local castOn = SupportRules.PickTarget(e.Support, m, allies, squad, now)
			if castOn then
				if castOn ~= m then
					local toAlly = castOn.Position - m.Position
					m.Yaw = math.atan2(-toAlly.X, -toAlly.Z)
				end
				m.Action = Timeline.Start(m, castOn, kitMove, now)
				m.ActionSequence = m.Action.ActionSequence
				m.State = "WINDUP"
				m.Cooldowns[kitMove.Id] = now + kitMove.CooldownSeconds
				self.Metrics.Started += 1
				api.Send(m, self:PublicAction(m.Action, "START"))
				return true
			end
		end
		local anchor, anchorDistance = allies[1], math.huge
		for _, ally in allies do
			local d = (ally.Position - m.Position).Magnitude
			if d < anchorDistance then anchor, anchorDistance = ally, d end
		end
		local spot = SupportRules.KitePoint(anchor.Position, target.Position)
		local goal = Vector3.new(spot.X, anchor.Position.Y, spot.Z)
		local toHero = target.Position - m.Position
		m.Yaw = math.atan2(-toHero.X, -toHero.Z)
		m.State = "CHASE"
		if (goal - m.Position).Magnitude > 3 and (goal - m.HomePosition).Magnitude < (m.LeashRadius or Config.LeashRange) * 0.8 then
			api.Navigation.Step(m, goal, e.MoveSpeed * SupportRules.SpeedMultiplier(m, now) * math.min(dt, .3), os.clock())
		end
		return true
	end
	function self:Step(m, dt, now, targets)
		if not m.IsAlive then return end
		local e = Config.Get(m.EnemyId)
		local room = api.Tower.GetRoom(m.FloorId)
		if not room or room.RoomGeneration ~= m.RoomGeneration then return end
		m.LastOrigin = room.Origin
		m.LocalPosition = m.Position - room.Origin
		if m.Role == "BOSS" then
			m.Phase = m.CurrentHP <= m.MaxHP * 0.5 and 2 or 1
			if now - m.BornAt < 2.2 then
				m.State = "IDLE"
				return
			end
		end
		local function safe(v) return self:Safe(v) end
		if m.Action then
			local action = m.Action
			local definition = Config.Attack(m.EnemyId, action.AttackId)
			local allyCast = definition ~= nil and definition.Shape:sub(1, 4) == "ALLY"
			local target = nil
			if allyCast then
				-- A support's kit targets an ally mob (or itself, for ROUSE's aura).
				local mob = api.Mobs[action.Target.NetId]
				if mob and Timeline.Matches(mob, action.Target) then target = mob end
			else
				for _, t in targets do
					if Timeline.Matches(t, action.Target) then target = t; break end
				end
			end
			local candidates = targets
			local onHit = function(v, mult)
				if not api.Navigation.CanAttack(m.Position, v.Position) then return end
				self.Metrics.Hits += 1
				local amount = math.max(1, math.round(m.ATK * mult * SupportRules.AtkMultiplier(m, now)
					* AffixRules.AtkMultiplier(m) * AffixRules.AuraAtk(m, self:AffixedNear(m))))
				api.Damage(v, amount, m)
				if AffixRules.Has(m, "VAMPIRIC") then
					m.CurrentHP = math.min(m.MaxHP, m.CurrentHP + math.round(amount * AffixRules.VampiricFraction))
				end
			end
			if allyCast then
				candidates = if definition.Shape == "ALLY_AURA" then self:Allies(m, definition.Radius, true) elseif target then { target } else {}
				onHit = function(v)
					SupportRules.Apply(e.Support, v, now)
				end
			end
			local result = Timeline.Step(action, m, target, definition, now, safe, candidates, onHit)
			if result then
				if result == "IMPACT" then self.Metrics.Impacts += 1
				elseif result == "CANCEL" then self.Metrics.Canceled += 1 end
				api.Send(m, self:PublicAction(action, result))
			end
			m.State = action.Status
			if result == "CANCEL" or result == "COMPLETE" then
				m.Action = nil
				m.ActionSequence = 0
			end
			return
		end
		local fromHome = (m.Position - m.HomePosition).Magnitude
		local target = nil
		local nearest = e.AggroRange
		for _, t in targets do
			if Timeline.Alive(t) and api.Tower.Same(m, t) and not safe(t) and (t.Position - m.HomePosition).Magnitude < (m.LeashRadius or Config.LeashRange) then
				local d = (m.Position - t.Position).Magnitude
				if d < nearest then
					nearest = d
					target = t
				end
			end
		end
		if m.Affixes then AffixRules.Regen(m, workspace:GetServerTimeNow()) end
		local speed = e.MoveSpeed * SupportRules.SpeedMultiplier(m, now) * AffixRules.SpeedMultiplier(m)
		if fromHome > (m.LeashRadius or Config.LeashRange) or safe(m) or not target then
			m.State = if fromHome <= 3 then "IDLE" elseif m.Patrol then "PATROL" else "RESET"
			if fromHome > 3 then
				api.Navigation.Step(m, m.HomePosition, speed * math.min(dt, .3), os.clock())
			end
			return
		end
		if e.Support and self:StepSupport(m, e, target, targets, now, dt) then
			return
		end
		local delta = target.Position - m.Position
		m.Yaw = math.atan2(-delta.X, -delta.Z)
		local chosen = nil
		local chaseRange = math.huge
		for i = #e.Attacks, 1, -1 do
			local a = e.Attacks[i]
			if a.Shape:sub(1, 4) == "ALLY" then continue end -- support kits are cast in StepSupport
			chaseRange = math.min(chaseRange, a.Range)
			if now >= (m.Cooldowns[a.Id] or 0) and nearest <= a.Range and api.Navigation.CanAttack(m.Position, target.Position) then
				chosen = a
				break
			end
		end
		if chosen then
			m.Action = Timeline.Start(m, target, chosen, now)
			m.ActionSequence = m.Action.ActionSequence
			m.State = "WINDUP"
			m.Cooldowns[chosen.Id] = now + chosen.CooldownSeconds * AffixRules.CooldownMultiplier(m)
			self.Metrics.Started += 1
			api.Send(m, self:PublicAction(m.Action, "START"))
		else
			m.State = "CHASE"
			if nearest > chaseRange * .85 then
				api.Navigation.Step(m, target.Position, speed * math.min(dt, .3), os.clock())
			end
		end
	end
	function self:Tick(dt)
		local now = workspace:GetServerTimeNow()
		self:SyncRooms(now)
		local targets = self:Targets()
		for _, m in pairs(api.Mobs) do
			if m.TowerEnemy and not m.Action then
				self:Step(m, dt, now, targets)
			end
		end
	end
	function self:StepActions()
		local active = false
		for _, m in pairs(api.Mobs) do
			if m.TowerEnemy and m.Action then active = true; break end
		end
		if not active then return end
		local now = workspace:GetServerTimeNow()
		local targets = self:Targets()
		for _, m in pairs(api.Mobs) do
			if m.TowerEnemy and m.Action then
				self:Step(m, 0, now, targets)
			end
		end
	end
	function self:Pins(floor, generation)
		for _, m in pairs(api.Mobs) do
			if m.TowerEnemy and m.FloorId == floor and m.RoomGeneration == generation and m.Action then
				return true
			end
		end
		return false
	end
	return self
end

return Runtime
