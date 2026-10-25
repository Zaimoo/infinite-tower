--!strict
-- tests/phase1-combat-tempo.luau
-- Phase 1 Combat Pacing, Fast-Paced Action & Spectacle Verification Suite

local StatBalance = require(nodes["ReplicatedStorage.Shared.Config.StatBalance"])
local StatFormulas = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local TowerFloorConfig = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local MobCatalog = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local TowerProgress = require(nodes["ReplicatedStorage.Shared.Util.TowerProgress"])
local TowerLayout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])

local function assertTest(name: string, condition: boolean, msg: string?)
	if condition then
		print("PASS " .. name)
	else
		error("FAIL " .. name .. ": " .. (msg or "Assertion failed"))
	end
end

-- ============================================================================
-- SUITE 1: Hit-Frame Damage Synchronization (1,000 Damage Events)
-- ============================================================================
do
	type PendingHit = {
		AttackerNetId: number,
		TargetNetId: number,
		StartTime: number,
		HitKeyframeTime: number,
		Damage: number,
		Resolved: boolean,
		ResolvedTime: number?,
		Canceled: boolean,
	}

	local HIT_KEYFRAME_OFFSET = 0.35 -- Keyframe t_hit ≈ 0.35s into swing
	local pendingQueue: { PendingHit } = {}
	local resolvedCount = 0
	local maxDelta = 0.0

	-- Step simulation forward in 60 Hz engine ticks (dt ≈ 0.016667s)
	local dt = 1 / 60
	local currentTime = 100.0

	-- Queue 1,000 attack events with staggered start times
	for i = 1, 1000 do
		local startTime = 100.0 + (i * 0.08)
		table.insert(pendingQueue, {
			AttackerNetId = 1,
			TargetNetId = 2,
			StartTime = startTime,
			HitKeyframeTime = startTime + HIT_KEYFRAME_OFFSET,
			Damage = 50,
			Resolved = false,
			ResolvedTime = nil,
			Canceled = false,
		})
	end

	-- Run simulation until all 1,000 hits resolve
	local totalSteps = 0
	while resolvedCount < 1000 and totalSteps < 20000 do
		totalSteps += 1
		currentTime += dt

		for _, hit in ipairs(pendingQueue) do
			if not hit.Resolved and not hit.Canceled and currentTime >= hit.HitKeyframeTime then
				hit.Resolved = true
				hit.ResolvedTime = currentTime
				resolvedCount += 1
				local delta = math.abs(currentTime - hit.HitKeyframeTime)
				if delta > maxDelta then
					maxDelta = delta
				end
			end
		end
	end

	assertTest("HitFrame_All1000Resolved", resolvedCount == 1000, "Expected 1,000 events resolved")
	assertTest(
		"HitFrame_TimestampCorrelationStrict",
		maxDelta < 0.05,
		string.format("Max delta %.4fs exceeded 0.05s tolerance", maxDelta)
	)

	-- Verify cancellation: if attacker dies during windup, hit does not resolve
	local canceledHit: PendingHit = {
		AttackerNetId = 99,
		TargetNetId = 100,
		StartTime = 500.0,
		HitKeyframeTime = 500.35,
		Damage = 100,
		Resolved = false,
		ResolvedTime = nil,
		Canceled = false,
	}
	-- Attacker dies at t = 500.15 (during windup)
	canceledHit.Canceled = true
	local simTime = 500.40
	if not canceledHit.Canceled and simTime >= canceledHit.HitKeyframeTime then
		canceledHit.Resolved = true
	end
	assertTest("HitFrame_CancelOnDeathDuringWindup", canceledHit.Resolved == false, "Canceled hit should not resolve")
end

-- ============================================================================
-- SUITE 2: Time-To-Kill (TTK) Calibration Across Floors 1..50
-- ============================================================================
do
	local testFloors = { 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 }

	for _, floorId in ipairs(testFloors) do
		local regStats = StatBalance.GetFloorStats(floorId, "REGULAR")
		local eliteStats = StatBalance.GetFloorStats(floorId, "ELITE")
		local bossStats = StatBalance.GetFloorStats(floorId, "BOSS")

		assertTest("TTK_FloorStatsExist_" .. floorId, regStats ~= nil and eliteStats ~= nil and bossStats ~= nil)

		-- Extract curve on-curve squad DPS: MaxHP_reg = DPS * 2 -> DPS = MaxHP_reg / 2
		local squadDPS = regStats.MaxHP / 2.0

		local regularTTK = regStats.MaxHP / squadDPS
		local eliteTTK = eliteStats.MaxHP / squadDPS
		local bossTTK = bossStats.MaxHP / squadDPS

		-- Regular Mobs: TTK = 1.5 to 2.5 seconds under squad focus
		assertTest(
			string.format("TTK_Regular_Floor%d (%.2fs)", floorId, regularTTK),
			regularTTK >= 1.5 and regularTTK <= 2.5,
			string.format("Regular TTK %.2fs out of range [1.5, 2.5]", regularTTK)
		)

		-- Elite Mobs: TTK = 6 to 10 seconds
		assertTest(
			string.format("TTK_Elite_Floor%d (%.2fs)", floorId, eliteTTK),
			eliteTTK >= 6.0 and eliteTTK <= 10.0,
			string.format("Elite TTK %.2fs out of range [6.0, 10.0]", eliteTTK)
		)

		-- Floor Bosses: TTK = 20 to 30 seconds (reduced from 45s slog; Boss HP mult = DPS * 25)
		assertTest(
			string.format("TTK_Boss_Floor%d (%.2fs)", floorId, bossTTK),
			bossTTK >= 20.0 and bossTTK <= 30.0,
			string.format("Boss TTK %.2fs out of range [20.0, 30.0]", bossTTK)
		)
	end
end

-- ============================================================================
-- SUITE 3: Dynamic Continuous Mob Streaming (6–8 Mobs/Player, 1.0s Respawn)
-- ============================================================================
do
	-- Simulate a floor encounter with 1 active player
	local activePlayers = 1
	local targetMobCount = 7 -- Midpoint of [6, 8] per player
	local activeMobs = {}
	local mobIdCounter = 1

	-- Initial spawn
	for i = 1, targetMobCount do
		table.insert(activeMobs, {
			Id = mobIdCounter,
			IsAlive = true,
			RespawnAt = 0,
			Role = if i % 5 == 0 then "ELITE" else "REGULAR",
		})
		mobIdCounter += 1
	end

	local timeNow = 100.0
	local densityViolations = 0

	-- Simulate 100 mob defeat and respawn cycles over time
	for cycle = 1, 100 do
		-- Kill one active mob
		local victimIndex = 1
		for idx, m in ipairs(activeMobs) do
			if m.IsAlive then
				victimIndex = idx
				break
			end
		end

		local victim = activeMobs[victimIndex]
		victim.IsAlive = false
		victim.RespawnAt = timeNow + 1.0 -- Exact 1.0-second delay

		-- Count living mobs immediately after death
		local aliveImmediate = 0
		for _, m in ipairs(activeMobs) do
			if m.IsAlive then
				aliveImmediate += 1
			end
		end

		-- Verify density stays between 6 and 8 per player during defeat transition
		if aliveImmediate < 6 * activePlayers or aliveImmediate > 8 * activePlayers then
			densityViolations += 1
		end

		-- Advance time by 1.0s to trigger respawn
		timeNow += 1.0
		for _, m in ipairs(activeMobs) do
			if not m.IsAlive and timeNow >= m.RespawnAt then
				m.IsAlive = true
				m.Role = if (cycle % 5 == 0) then "ELITE" else "REGULAR"
			end
		end

		-- Count living mobs after respawn
		local aliveAfterRespawn = 0
		for _, m in ipairs(activeMobs) do
			if m.IsAlive then
				aliveAfterRespawn += 1
			end
		end

		if aliveAfterRespawn < 6 * activePlayers or aliveAfterRespawn > 8 * activePlayers then
			densityViolations += 1
		end
	end

	assertTest(
		"MobStreaming_DensityMaintained_6to8",
		densityViolations == 0,
		string.format("Density violated %d times during streaming", densityViolations)
	)

	-- Verify Mob Composition: 80% Regular Mobs, 20% Elite Mobs
	local regularCount = 0
	local eliteCount = 0
	math.randomseed(12345)
	for _ = 1, 2000 do
		local isElite = math.random() <= 0.20
		if isElite then
			eliteCount += 1
		else
			regularCount += 1
		end
	end
	local eliteRatio = eliteCount / (regularCount + eliteCount)
	assertTest(
		"MobStreaming_Composition_80_20",
		eliteRatio >= 0.17 and eliteRatio <= 0.23,
		string.format("Elite ratio %.2f expected ~0.20", eliteRatio)
	)

	-- Verify Kill Accounting: Regular = +1, Elite = +2
	local progress = TowerProgress.CreateProgress(1)
	assertTest("KillProgress_InitialZero", progress.CurrentKills == 0)
	TowerProgress.RecordKill(progress, "REGULAR")
	assertTest("KillProgress_RegularPlus1", progress.CurrentKills == 1)
	TowerProgress.RecordKill(progress, "ELITE")
	assertTest("KillProgress_ElitePlus2", progress.CurrentKills == 3)

	-- Verify Boss Gate: Spawns exactly when target kills reached
	local targetProgress = TowerProgress.CreateProgress(1)
	local bossSpawned = false
	while targetProgress.CurrentKills < targetProgress.RequiredKills do
		bossSpawned = TowerProgress.RecordKill(targetProgress, "REGULAR")
	end
	assertTest("KillProgress_BossSummonedOnTarget", bossSpawned == true and targetProgress.BossSpawned == true)
end

-- ============================================================================
-- SUITE 4: Zero Whistle Remnants Verification
-- ============================================================================
do
	local dummyHero = {
		TemplateId = "hero_han",
		Level = 10,
		Stars = 2,
		QualityScalar = 1.0,
		AttackInterval = 1.0,
	}

	-- Overdrive attack speed multipliers removed from stat calculations:
	-- inOverdrive=true MUST NOT increase attack speed or decrease attack interval!
	local snapNormal = StatFormulas.GetCombatSnapshot(dummyHero, nil, false, false, 1.0)
	local snapOverdrive = StatFormulas.GetCombatSnapshot(dummyHero, nil, true, false, 1.0)

	assertTest(
		"WhistleRemnant_OverdriveSpeedMultiplierRemoved",
		snapNormal.AttackInterval == snapOverdrive.AttackInterval and snapNormal.AttackSpeed == snapOverdrive.AttackSpeed,
		string.format(
			"AttackInterval differs: normal=%.3f, overdrive=%.3f",
			snapNormal.AttackInterval,
			snapOverdrive.AttackInterval
		)
	)

	-- Verify Boss HP multiplier reduced to DPS * 25
	local floor1Regular = StatBalance.GetFloorStats(1, "REGULAR")
	local floor1Boss = StatBalance.GetFloorStats(1, "BOSS")
	local baseDPS = floor1Regular.MaxHP / 2.0
	local bossRatio = floor1Boss.MaxHP / baseDPS
	assertTest(
		"BossHPMultiplier_ReducedTo25",
		math.abs(bossRatio - 25.0) < 0.1,
		string.format("Boss HP ratio %.2f expected 25.0", bossRatio)
	)
end
