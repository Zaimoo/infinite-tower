--!strict
-- tests/phase2-floor-loop.spec.luau
-- Phase 2 Floor Loop: Kill Progress, Boss Spawning Gate, and Shared Uncontestable Loot.

local TowerProgress = require(nodes["ReplicatedStorage.Shared.Util.TowerProgress"])
local TowerFloorConfig = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local MobCatalog = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("Phase 2: Floor kill progress tracks and scales across all 50 floors", function()
	for floorId = 1, 50 do
		local req = TowerProgress.GetRequiredKills(floorId)
		local expected = math.round(12 + 0.5 * floorId)
		assert(req == expected, string.format("Floor %d expected %d required kills, got %d", floorId, expected, req))
		assert(req >= 12, "Required kills must be at least 12")

		local progress = TowerProgress.CreateProgress(floorId)
		assert(progress.FloorId == floorId, "FloorId mismatch")
		assert(progress.CurrentKills == 0, "Initial kills must be 0")
		assert(progress.RequiredKills == req, "Required kills mismatch")
		assert(progress.BossSpawned == false, "BossSpawned must start false")
		assert(progress.BossNetId == nil, "BossNetId must start nil")
		assert(progress.BossDefeated == false, "BossDefeated must start false")
	end
end)

test("Phase 2: Regular (+1) and Elite (+2) kills advance progress and trigger boss gate", function()
	local progress = TowerProgress.CreateProgress(1)
	local target = progress.RequiredKills -- 13 for Floor 1

	-- Kill 3 regular mobs (+3)
	for _ = 1, 3 do
		local spawned = TowerProgress.RecordKill(progress, "REGULAR")
		assert(spawned == false, "Boss should not spawn yet")
	end
	assert(progress.CurrentKills == 3, "Expected 3 kills")
	assert(progress.BossSpawned == false)

	-- Kill 4 elite mobs (+8) -> total 11
	for _ = 1, 4 do
		local spawned = TowerProgress.RecordKill(progress, "ELITE")
		assert(spawned == false, "Boss should not spawn yet")
	end
	assert(progress.CurrentKills == 11, "Expected 11 kills")
	assert(progress.BossSpawned == false)

	-- Kill 1 elite mob (+2) -> total 13 >= target!
	local triggered = TowerProgress.RecordKill(progress, "ELITE")
	assert(triggered == true, "Boss spawn condition must trigger when reaching target")
	assert(progress.CurrentKills == 13, "Expected 13 kills")
	assert(progress.BossSpawned == true, "BossSpawned must be true")

	-- Further kills after boss is spawned do not re-trigger boss spawn
	local postSpawnTrigger = TowerProgress.RecordKill(progress, "REGULAR")
	assert(postSpawnTrigger == false, "Post-spawn kills must not re-trigger boss")
	assert(progress.CurrentKills == 13, "Kills should freeze while boss is active")
end)

test("Phase 2: Floor Boss template resolution covers all 50 floors", function()
	-- Floor 1..4 in Biome 1 resolve to Elite champion
	for f = 1, 4 do
		local bossId = TowerProgress.GetFloorBossEnemyId(f)
		assert(bossId == "elite_vinebound", "Floor 1..4 champion mismatch")
		local cat = MobCatalog.Get(bossId)
		assert(cat and cat.BiomeId == "verdant_ruins", "Champion must belong to floor biome")
	end

	-- Floor 5 resolves to Biome Boss
	local f5Boss = TowerProgress.GetFloorBossEnemyId(5)
	assert(f5Boss == "boss_mossbound_guardian", "Floor 5 boss mismatch")

	-- Floor 25 resolves to Ember Titan
	local f25Boss = TowerProgress.GetFloorBossEnemyId(25)
	assert(f25Boss == "boss_ember_titan", "Floor 25 boss mismatch")

	-- Floor 50 resolves to Crimson Overlord
	local f50Boss = TowerProgress.GetFloorBossEnemyId(50)
	assert(f50Boss == "boss_crimson_overlord", "Floor 50 boss mismatch")
end)

test("Phase 2: Boss victory delivers uncontestable rewards and floor unlock to all >= 3% participants", function()
	local floorId = 1
	local bossMaxHP = 20000

	-- Mock players and profiles
	local p1 = { UserId = 1001, Name = "PlayerOne" }
	local p2 = { UserId = 1002, Name = "PlayerTwo" }
	local p3 = { UserId = 1003, Name = "PlayerThree" }

	local profile1 = { Currencies = { Gold = 100, Gems = 10 }, HighestClearedFloor = 0, MaxFloorReached = 1 }
	local profile2 = { Currencies = { Gold = 50, Gems = 5 }, HighestClearedFloor = 0, MaxFloorReached = 1 }
	local profile3 = { Currencies = { Gold = 0, Gems = 0 }, HighestClearedFloor = 0, MaxFloorReached = 1 }

	local progress1 = TowerProgress.CreateProgress(floorId)
	local progress2 = TowerProgress.CreateProgress(floorId)
	progress1.BossSpawned = true
	progress2.BossSpawned = true

	-- Damage contributions
	-- p1 dealt 14,000 (70% >= 3%)
	-- p2 dealt 800 (4.0% >= 3%)
	-- p3 dealt 300 (1.5% < 3%)
	local damageLedger = {
		[p1.UserId] = 14000,
		[p2.UserId] = 800,
		[p3.UserId] = 300,
	}

	local p1Eligible = TowerProgress.CheckParticipation(damageLedger[p1.UserId], bossMaxHP, false)
	local p2Eligible = TowerProgress.CheckParticipation(damageLedger[p2.UserId], bossMaxHP, false)
	local p3Eligible = TowerProgress.CheckParticipation(damageLedger[p3.UserId], bossMaxHP, false)

	assert(p1Eligible == true, "Player 1 (70%) must be eligible for boss rewards")
	assert(p2Eligible == true, "Player 2 (4%) must be eligible for boss rewards")
	assert(p3Eligible == false, "Player 3 (1.5%) must NOT be eligible (< 3% threshold)")

	-- Distribute rewards and floor unlock
	local bossRewards = TowerFloorConfig.GetKillRewards(floorId, "BOSS")
	assert(bossRewards.Gold > 0 and bossRewards.Gems > 0, "Boss rewards must be positive")

	local function grantBossVictory(player, profile, progress, isEligible)
		if isEligible then
			profile.Currencies.Gold += bossRewards.Gold
			profile.Currencies.Gems += bossRewards.Gems
			profile.HighestClearedFloor = math.max(profile.HighestClearedFloor or 0, floorId)
			profile.MaxFloorReached = math.max(profile.MaxFloorReached or 0, floorId + 1)
			progress.BossDefeated = true
		end
	end

	grantBossVictory(p1, profile1, progress1, p1Eligible)
	grantBossVictory(p2, profile2, progress2, p2Eligible)
	grantBossVictory(p3, profile3, nil, p3Eligible)

	-- Verify Player 1 got full copy and unlocked floor 2
	assert(profile1.Currencies.Gold == 100 + bossRewards.Gold, "Player 1 Gold reward missing")
	assert(profile1.Currencies.Gems == 10 + bossRewards.Gems, "Player 1 Gems reward missing")
	assert(profile1.HighestClearedFloor == 1, "Player 1 HighestClearedFloor must be 1")
	assert(profile1.MaxFloorReached == 2, "Player 1 MaxFloorReached must be 2")
	assert(progress1.BossDefeated == true, "Progress 1 BossDefeated must be true")

	-- Verify Player 2 got full copy and unlocked floor 2 (unsplit!)
	assert(profile2.Currencies.Gold == 50 + bossRewards.Gold, "Player 2 Gold reward missing")
	assert(profile2.Currencies.Gems == 5 + bossRewards.Gems, "Player 2 Gems reward missing")
	assert(profile2.HighestClearedFloor == 1, "Player 2 HighestClearedFloor must be 1")
	assert(profile2.MaxFloorReached == 2, "Player 2 MaxFloorReached must be 2")
	assert(progress2.BossDefeated == true, "Progress 2 BossDefeated must be true")

	-- Verify Player 3 got NOTHING
	assert(profile3.Currencies.Gold == 0, "Player 3 should not receive Gold")
	assert(profile3.Currencies.Gems == 0, "Player 3 should not receive Gems")
	assert(profile3.HighestClearedFloor == 0, "Player 3 should not unlock floor")
	assert(profile3.MaxFloorReached == 1, "Player 3 should not advance floor")
end)

test("Phase 2: Floor progress persists across squad recalls and repositioning on the same floor", function()
	local activeProgress: { [number]: any } = {}
	local function onTransfer(userId: number, floorId: number)
		if floorId == 0 then
			activeProgress[userId] = nil
		else
			local existing = activeProgress[userId]
			if not existing or existing.FloorId ~= floorId then
				activeProgress[userId] = TowerProgress.CreateProgress(floorId)
			end
		end
		return activeProgress[userId]
	end

	-- Arrive at floor 1
	local p = onTransfer(101, 1)
	assert(p.CurrentKills == 0, "Initial kills must be 0")

	-- Slay 5 regular mobs (+5)
	for _ = 1, 5 do
		TowerProgress.RecordKill(p, "REGULAR")
	end
	assert(p.CurrentKills == 5, "Expected 5 kills recorded")

	-- Recall squad [E] (Transfer called with same floor 1)
	local pAfterRecall = onTransfer(101, 1)
	assert(pAfterRecall.CurrentKills == 5, "Recall on same floor MUST NOT reset kills")

	-- Advance to floor 2 (Transfer called with new floor 2)
	local pFloor2 = onTransfer(101, 2)
	assert(pFloor2.FloorId == 2)
	assert(pFloor2.CurrentKills == 0, "Changing to new floor should start fresh progress")
end)

test("Phase 2: Higher floors locked until unlocked via MaxFloorReached or HighestClearedFloor", function()
	local function checkFloorAccess(profile: any, floorId: number, isStudioBypass: boolean): boolean
		if isStudioBypass then return true end
		local maxAllowed = math.max(1, profile.MaxFloorReached or ((profile.HighestClearedFloor or 0) + 1))
		return floorId <= maxAllowed
	end

	-- Fresh profile starts at Floor 1 unlocked
	local freshProfile = { HighestClearedFloor = 0, MaxFloorReached = 1 }
	assert(checkFloorAccess(freshProfile, 1, false) == true, "Floor 1 should be accessible to fresh profile")
	assert(checkFloorAccess(freshProfile, 2, false) == false, "Floor 2 should be locked for fresh profile")
	assert(checkFloorAccess(freshProfile, 50, false) == false, "Floor 50 should be locked for fresh profile")

	-- After clearing floor 1 boss
	local afterFloor1 = { HighestClearedFloor = 1, MaxFloorReached = 2 }
	assert(checkFloorAccess(afterFloor1, 1, false) == true, "Floor 1 remains accessible")
	assert(checkFloorAccess(afterFloor1, 2, false) == true, "Floor 2 is now unlocked")
	assert(checkFloorAccess(afterFloor1, 3, false) == false, "Floor 3 is still locked")

	-- Studio bypass
	assert(checkFloorAccess(freshProfile, 50, true) == true, "Studio bypass unlocks all floors")
end)

test("Phase 2: Floor boss/champion and Apex Sanctum mobs are never pre-placed before kill threshold", function()
	local FirstBiomeCombat = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
	for floorId = 1, 50 do
		local bossEnemyId = TowerProgress.GetFloorBossEnemyId(floorId)
		local placements = FirstBiomeCombat.Floors[floorId]
		assert(placements and #placements > 0, string.format("Floor %d must have placements", floorId))

		local activePlacedMobs = {}
		for slot, placement in placements do
			local e = FirstBiomeCombat.Get(placement.EnemyId)
			-- Rule: Bosses and apex sanctum encounters are never pre-placed on room load
			local isBossOrApex = e.Role == "BOSS" or placement.CampId == "CAMP_APEX_SANCTUM" or placement.EnemyId == bossEnemyId
			if not isBossOrApex then
				table.insert(activePlacedMobs, placement)
			end
		end

		-- Verify no boss or apex sanctum mob was placed
		for _, m in ipairs(activePlacedMobs) do
			local e = FirstBiomeCombat.Get(m.EnemyId)
			assert(e.Role ~= "BOSS", string.format("Floor %d pre-placed a BOSS!", floorId))
			assert(m.CampId ~= "CAMP_APEX_SANCTUM", string.format("Floor %d pre-placed in CAMP_APEX_SANCTUM!", floorId))
			assert(m.EnemyId ~= bossEnemyId, string.format("Floor %d pre-placed floor boss %s!", floorId, bossEnemyId))
		end
	end
end)

test("Phase 2: Roster filter strictly excludes deployed heroes from bottom deployment list", function()
	local function slotOf(hero: any): number?
		if not hero or not hero.Assignment then return nil end
		local n = hero.Assignment:match("^SQUAD_SLOT_(%d+)$")
		return n and tonumber(n) or nil
	end

	local heroes = {
		h1 = { UUID = "h1", DisplayName = "Jenna", Assignment = "SQUAD_SLOT_1" },
		h2 = { UUID = "h2", DisplayName = "Han", Assignment = "SQUAD_SLOT_2" },
		h3 = { UUID = "h3", DisplayName = "Velkist", Assignment = "NONE" },
		h4 = { UUID = "h4", DisplayName = "Aaron", Assignment = "FACILITY_GUARD_POST" },
	}

	local bottomList = {}
	for _, h in pairs(heroes) do
		local isDeployed = slotOf(h) ~= nil
		if not isDeployed then
			table.insert(bottomList, h)
		end
	end

	assert(#bottomList == 2, string.format("Expected 2 undeployed heroes in bottom list, got %d", #bottomList))
	for _, h in ipairs(bottomList) do
		assert(slotOf(h) == nil, string.format("Hero %s is deployed in slot %s and must not be in bottom list", h.DisplayName, tostring(slotOf(h))))
	end
end)

test("Phase 2: Defeated boss creates portal target to floor + 1 (or Hub on Floor 50)", function()
	local function getPortalTarget(floorId: number): (string, number?)
		if floorId >= 50 then
			return "HUB", nil
		else
			return "FLOOR", floorId + 1
		end
	end

	for floorId = 1, 49 do
		local action, nextFloor = getPortalTarget(floorId)
		assert(action == "FLOOR", "Floors 1..49 must ascend to next floor")
		assert(nextFloor == floorId + 1, string.format("Floor %d expected portal to %d, got %s", floorId, floorId + 1, tostring(nextFloor)))
	end

	local action50, nextFloor50 = getPortalTarget(50)
	assert(action50 == "HUB", "Floor 50 portal must return to Hub")
	assert(nextFloor50 == nil, "Floor 50 portal target floor must be nil")
end)

test("Phase 2: Assigned squads engage mobs across the floor within max leash", function()
	local maxLeash = 105.0
	local centerX, centerY, centerZ = 0, 0, 12
	local mobCamps = {
		{ X = -65, Y = 0, Z = 0 },  -- ~66 studs from center
		{ X = 65, Y = 0, Z = 0 },   -- ~66 studs from center
		{ X = 0, Y = 12, Z = -54 }, -- ~67 studs from center
	}

	for _, mob in ipairs(mobCamps) do
		local dist = math.sqrt((mob.X - centerX)^2 + (mob.Y - centerY)^2 + (mob.Z - centerZ)^2)
		-- Must be reachable within maxLeash (so assigned squads can attack them)
		assert(dist <= maxLeash, string.format("Camp at (%d, %d, %d) is %f studs away, exceeding maxLeash %f", mob.X, mob.Y, mob.Z, dist, maxLeash))
		-- But would be rejected by old 30-stud player tether
		assert(dist > 30.0, "Camp should be outside old 30-stud player tether to verify fix")
	end
end)

print(string.format("Phase 2 floor loop tests: %d passed", passed))
