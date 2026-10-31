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
				spawned += 1
			end
		end
		if spawned > 0 then api.Changed() end
		return spawned
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
				-- A camp is "alive" while any member lives (or has not been created yet).
				local campAlive = {}
				for slot, placement in effective do
					local existing = ledger.Slots[slot]
					if not existing or existing.IsAlive then campAlive[placement.CampId] = true end
				end
				for slot, placement in effective do
					local e = table.clone(Config.Get(placement.EnemyId))
					-- Bosses and Apex Sanctum encounters are never pre-placed: each floor boss/champion is summoned strictly by a player's own kill threshold (SpawnBoss).
					-- Camp Elites do spawn; a summoned champion is always Role BOSS, so they never count as it.
					if e.Role == "BOSS" or placement.CampId == "CAMP_APEX_SANCTUM" then continue end
					local floorStats = TowerFloorConfig.GetEnemyStats(floor, placement.EnemyId)
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
					local m = ledger.Slots[slot]
					if not m then
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
							LocalPosition = Vector3.new(placement.X, placement.Y or 0, placement.Z),
						}
						ledger.Slots[slot] = m
						if e.Role == "BOSS" then ledger.BossGeneration = m.LifeGeneration end
					end
					m.LeashRadius = placement.LeashRadius or Config.LeashRange
					m.CampId = placement.CampId
					if m.RoomGeneration ~= room.RoomGeneration then
						m.EntityGeneration += 1
						m.RoomGeneration = room.RoomGeneration
						m.HomePosition = api.Navigation.Ground(room.Origin + Vector3.new(placement.X, (placement.Y or 0) + 6, placement.Z), nil, 2, 12) or room.Origin + Vector3.new(placement.X, placement.Y or 0, placement.Z)
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
					end
					if not m.IsAlive and now >= m.RespawnAt then
						m.IsAlive = true
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
					if slot >= Config.ExtraSlotBase and not effective[slot] and not m.IsAlive then
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
			local target = nil
			for _, t in targets do
				if Timeline.Matches(t, action.Target) then target = t; break end
			end
			local definition = Config.Attack(m.EnemyId, action.AttackId)
			local result = Timeline.Step(action, m, target, definition, now, safe, targets, function(v, mult)
				if not api.Navigation.CanAttack(m.Position, v.Position) then return end
				self.Metrics.Hits += 1
				api.Damage(v, math.max(1, math.round(m.ATK * mult)), m)
			end)
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
		if fromHome > (m.LeashRadius or Config.LeashRange) or safe(m) or not target then
			m.State = fromHome > 3 and "RESET" or "IDLE"
			if fromHome > 3 then
				api.Navigation.Step(m, m.HomePosition, e.MoveSpeed * math.min(dt, .3), os.clock())
			end
			return
		end
		local delta = target.Position - m.Position
		m.Yaw = math.atan2(-delta.X, -delta.Z)
		local chosen = nil
		for i = #e.Attacks, 1, -1 do
			local a = e.Attacks[i]
			if now >= (m.Cooldowns[a.Id] or 0) and nearest <= a.Range and api.Navigation.CanAttack(m.Position, target.Position) then
				chosen = a
				break
			end
		end
		if chosen then
			m.Action = Timeline.Start(m, target, chosen, now)
			m.ActionSequence = m.Action.ActionSequence
			m.State = "WINDUP"
			m.Cooldowns[chosen.Id] = now + chosen.CooldownSeconds
			self.Metrics.Started += 1
			api.Send(m, self:PublicAction(m.Action, "START"))
		else
			m.State = "CHASE"
			if nearest > e.Attacks[1].Range * .85 then
				api.Navigation.Step(m, target.Position, e.MoveSpeed * math.min(dt, .3), os.clock())
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
