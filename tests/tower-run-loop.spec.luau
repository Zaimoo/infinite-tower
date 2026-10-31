-- Phase 6 tower run-loop specs. Bundled by run.ps1 after the module list; `nodes`, `register` and `require` come from the shim.
local CampWaves = require(nodes["ReplicatedStorage.Shared.Util.CampWaves"])
local Combat = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end
local function role(enemyId: string): string?
	local e = Combat.Get(enemyId)
	return e and e.Role or nil
end
local function count(t: any): number
	local n = 0
	for _ in t do n += 1 end
	return n
end

test("Phase 6 M1: a camp respawns as one wave after its last member dies", function()
	local now = 100
	-- Others in the camp still live: keep waiting.
	assert(CampWaves.ScheduleRespawn(95, true, now) == nil)
	-- Everyone is dead: the whole camp returns CampRespawnSeconds later.
	assert(CampWaves.ScheduleRespawn(95, false, now) == now + Combat.CampRespawnSeconds)
	-- A lone survivor cannot hold the wave back past CampMaxWaitSeconds.
	assert(CampWaves.ScheduleRespawn(now - Combat.CampMaxWaitSeconds, true, now) == now)
	assert(CampWaves.ScheduleRespawn(now - Combat.CampMaxWaitSeconds + 1, true, now) == nil)
end)

test("Phase 6 M1: extra Masters scale camps up inside the live-mob budget", function()
	assert(CampWaves.ExtraCount(5, 1) == 0)
	assert(CampWaves.ExtraCount(5, 2) == 2)
	assert(CampWaves.ExtraCount(5, 3) == 4)
	for index = 1, 5 do
		local biomeCamps = Combat.Floors[index] -- biome 1, floors 1-5
		local base = 0
		for _, p in biomeCamps do
			local r = role(p.EnemyId)
			if r ~= "BOSS" and p.CampId ~= "CAMP_APEX_SANCTUM" then base += 1 end
		end
		local solo = CampWaves.EffectivePlacements(index, biomeCamps, 1, role)
		assert(count(solo) == #biomeCamps, "one Master changes nothing")
		for masters = 2, 6 do
			local merged = CampWaves.EffectivePlacements(index, biomeCamps, masters, role)
			local live = 0
			for slot, p in merged do
				local r = role(p.EnemyId)
				if r ~= "BOSS" and p.CampId ~= "CAMP_APEX_SANCTUM" then live += 1 end
				if slot >= Combat.ExtraSlotBase then
					assert(r == "REGULAR", "scaled-in members are Regulars")
					local camp
					for _, c in Layout.Get(index).Camps do if "CAMP_" .. c.Id == p.CampId then camp = c end end
					local terrace = Layout.Get(index).Platforms[camp.Platform]
					assert(math.abs(p.X - terrace.X) + 4 < terrace.Width / 2 and math.abs(p.Z - terrace.Z) + 4 < terrace.Depth / 2, "extra member stays on its terrace")
				else
					assert(slot <= #biomeCamps, "layout slots keep their index")
				end
			end
			assert(live <= math.max(Combat.MaxLiveMobsPerFloor, base), string.format("floor %d with %d Masters has %d live mobs", index, masters, live))
			assert(live >= base, "more Masters never means fewer mobs")
		end
	end
	-- Floor 1 (16 mobs) with 3 Masters grows; floor 4 (35 mobs) with 6 Masters is clamped at the budget.
	local f1 = CampWaves.EffectivePlacements(1, Combat.Floors[1], 3, role)
	assert(count(f1) > #Combat.Floors[1])
	local f4 = CampWaves.EffectivePlacements(4, Combat.Floors[4], 6, role)
	local live4 = 0
	for _, p in f4 do
		if role(p.EnemyId) ~= "BOSS" and p.CampId ~= "CAMP_APEX_SANCTUM" then live4 += 1 end
	end
	assert(live4 == Combat.MaxLiveMobsPerFloor, "floor 4 clamps at the budget, got " .. live4)
end)


local StatFormulas = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local Balance = require(nodes["ReplicatedStorage.Shared.Config.StatBalance"])
local Hardcore = require(nodes["ReplicatedStorage.Shared.Config.TowerHardcoreConfig"])

-- The default starter pair: Catio (3-star Rare) and Han (1-star Common) with Common 1-star weapons, Lv. 1.
local function starterPower(): number
	local catio = { TemplateId = "hero_catio", Stars = 3, Level = 1, QualityScalar = 1.02, Rarity = 3, ComaUntilTimestamp = 0 }
	local han = { TemplateId = "hero_han", Stars = 1, Level = 1, QualityScalar = 1.05, Rarity = 1, ComaUntilTimestamp = 0 }
	return StatFormulas.GetHeroPower(catio, { Star = 1, Rarity = 1, TemplateId = "art_miner_pickaxe" })
		+ StatFormulas.GetHeroPower(han, { Star = 1, Rarity = 1, TemplateId = "art_rusty_daggers" })
end

test("Phase 6 M3: floor 1 is sized to the default starter pair, not a full squad", function()
	local starter = starterPower()
	local rec1 = Floors.RecommendedPower(1)
	assert(math.abs(starter - rec1) / rec1 <= 0.2, string.format("starter %d vs floor 1 recommendation %d", starter, rec1))
	-- After the 900-gem starter 10-pull (one extra Rare) with three slots open, the squad still sits under floor 3.
	local catio = { TemplateId = "hero_catio", Stars = 3, Level = 1, QualityScalar = 1, Rarity = 3, ComaUntilTimestamp = 0 }
	local pulled = starter + StatFormulas.GetHeroPower(catio, { Star = 1, Rarity = 1, TemplateId = "art_miner_pickaxe" })
	assert(pulled <= Floors.RecommendedPower(3), string.format("squad after the starter pull %d vs floor 3 recommendation %d", pulled, Floors.RecommendedPower(3)))
	assert(Hardcore.StarterGems == 900)
end)

test("Phase 6 M3: expected squad size grows with the floor and enemy stats rise inside each biome", function()
	assert(Balance.ExpectedSquadSize(1) == 2 and Balance.ExpectedSquadSize(5) == 3 and Balance.ExpectedSquadSize(10) == 4)
	assert(Balance.ExpectedSquadSize(15) == 5 and Balance.ExpectedSquadSize(50) == 5)
	for biome = 0, 9 do
		for _, role in { "REGULAR", "ELITE", "ALPHA", "BOSS" } do
			local last
			for i = 1, 5 do
				local s = Balance.GetFloorStats(biome * 5 + i, role)
				assert(s.MaxHP > 0 and s.ATK > 0)
				if last then assert(s.MaxHP >= last.MaxHP and s.ATK >= last.ATK, role .. " should not get easier inside a biome") end
				last = s
			end
		end
	end
	-- The sawtooth: the first floor of the next biome is a breather compared with the boss floor's jump, not a reset.
	local boss5, reg6 = Balance.GetFloorStats(5, "REGULAR"), Balance.GetFloorStats(6, "REGULAR")
	assert(reg6.MaxHP >= boss5.MaxHP * 0.8, "next biome never starts far below the boss floor")
	assert(Balance.GetFloorStats(1, "ALPHA").MaxHP > Balance.GetFloorStats(1, "ELITE").MaxHP)
	assert(Balance.GetFloorStats(1, "ALPHA").MaxHP < Balance.GetFloorStats(1, "BOSS").MaxHP)
end)

local Mobs = require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local TowerProgress = require(nodes["ReplicatedStorage.Shared.Util.TowerProgress"])

test("Phase 6 M3b: each biome has one Alpha, used as the boss of floors 1-4 only", function()
	for biomeIndex, biome in ipairs(Mobs.Biomes) do
		local alpha, elite = Mobs.Get(biome.AlphaEnemyId), Mobs.Get(biome.EliteEnemyId)
		assert(alpha and alpha.Alpha == true and alpha.Role == "ELITE" and alpha.BiomeId == biome.Id)
		assert(alpha.Id ~= elite.Id and alpha.DisplayName ~= elite.DisplayName, "Alpha is a different enemy from the camp Elite")
		assert(alpha.Rig.ProposedFamily == elite.Rig.ProposedFamily and alpha.Bounds.Height > elite.Bounds.Height)
		local kit = Combat.Get(alpha.Id)
		assert(kit.Alpha == true and #kit.Attacks == 3, "Alpha kit: cleave, targeted disc and self quake")
		local hasQuake = false
		for _, a in kit.Attacks do if a.Shape == "SELF_DISC" then hasQuake = true end end
		assert(hasQuake)
		for i = 1, 5 do
			local id = (biomeIndex - 1) * 5 + i
			local floor = Floors.Get(id)
			local listed = false
			for _, e in floor.Encounters do if e.EnemyId == biome.AlphaEnemyId then listed = true end end
			assert(listed == (i < 5), "Alpha is on floors 1-4 of its biome only")
			assert(TowerProgress.GetFloorBossEnemyId(id) == (if i == 5 then biome.BossEnemyId else biome.AlphaEnemyId))
			local stats = Floors.GetEnemyStats(id, biome.AlphaEnemyId)
			assert((stats ~= nil) == (i < 5))
			if stats then
				local eliteStats = Floors.GetEnemyStats(id, biome.EliteEnemyId)
				assert(stats.MaxHP > eliteStats.MaxHP and stats.ATK > eliteStats.ATK, "Alpha out-stats the camp Elite")
			end
		end
	end
end)

local RelicConfig = require(nodes["ReplicatedStorage.Shared.Config.RelicConfig"])

-- Expected gems per kill: the flat kill gem, plus the relic roll's expected payout, with a camp Elite's guaranteed Geode.
local KILLS_PER_HOUR = 900 -- ~15 kills/min
local ELITE_SHARE = 0.08
local function gemsPerKill(floorId: number, role: string): number
	local reward = Floors.GetKillRewards(floorId, role)
	local geode, urn, core = RelicConfig.MANA_GEODE.Payout.Gems, RelicConfig.CURSED_URN.Payout.Gems, RelicConfig.ABYSSAL_CORE.Payout.Gems
	local tiers = reward.CoreChance * core + reward.UrnChance * urn + (1 - reward.CoreChance - reward.UrnChance) * geode
	local value = reward.Gems + reward.RelicChance * tiers
	if role == "ELITE" then value += (1 - reward.RelicChance) * geode end
	return value
end
local function gemsPerHour(floorId: number): number
	return KILLS_PER_HOUR * ((1 - ELITE_SHARE) * gemsPerKill(floorId, "REGULAR") + ELITE_SHARE * gemsPerKill(floorId, "ELITE"))
end

test("Phase 6 M4: gem income per hour sits near the 2,000 / 4,500 / 10,000 targets and never falls with depth", function()
	for floorId, target in { [1] = 2000, [25] = 4500, [50] = 10000 } do
		local rate = gemsPerHour(floorId)
		assert(math.abs(rate - target) / target <= 0.25, string.format("floor %d earns %d gems/h, target %d", floorId, rate, target))
	end
	local last = 0
	for floorId = 1, 50 do
		local rate = gemsPerHour(floorId)
		assert(rate >= last, "gem income never falls with depth")
		last = rate
	end
	-- Relic gems are flat per tier; only Gold scales with the floor.
	assert(RelicConfig.MANA_GEODE.Payout.Gems < RelicConfig.CURSED_URN.Payout.Gems and RelicConfig.CURSED_URN.Payout.Gems < RelicConfig.ABYSSAL_CORE.Payout.Gems)
	-- A camp Elite always drops a relic on every floor.
	for floorId = 1, 50 do
		assert(Floors.RollRelic(floorId, "ELITE", 0.999999, 0.5) ~= nil)
		assert(Floors.RollRelic(floorId, "REGULAR", 0.999999, 0.5) == nil)
	end
end)


test("Phase 6 M4: Biome Boss first-clear artifacts are Rare or better and capped at Mythical", function()
	local expected = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7 }
	for tier = 1, 10 do
		assert(TowerProgress.BossArtifactRarity(tier) == expected[tier], "tier " .. tier)
	end
	assert(TowerProgress.BossArtifactRarity(50) == 7)
end)

local TowerRun = require(nodes["ReplicatedStorage.Shared.Util.TowerRun"])

test("Phase 6 M5: the climb streak grows on consecutive clears, restarts on a gap and ignores repeats", function()
	local run = TowerRun.New(3, 0)
	assert(run.Streak == 0 and TowerRun.StreakMultiplier(0) == 1)
	assert(TowerRun.RecordFloorClear(run, 3) == 1, "the first clear starts the streak")
	assert(TowerRun.RecordFloorClear(run, 3) == 1, "clearing the same floor again changes nothing")
	assert(TowerRun.RecordFloorClear(run, 4) == 2 and TowerRun.RecordFloorClear(run, 5) == 3)
	assert(run.FloorsCleared == 3 and run.BestStreak == 3)
	assert(TowerRun.RecordFloorClear(run, 9) == 1, "a gap restarts the streak at 1")
	assert(run.BestStreak == 3, "the best streak is remembered")
	assert(math.abs(TowerRun.StreakMultiplier(3) - 1.3) < 1e-9)
	assert(TowerRun.StreakMultiplier(10) == 2 and TowerRun.StreakMultiplier(40) == 2, "the bonus caps at +100%")
end)

test("Phase 6 M5: banking makes earnings safe without touching the streak; a wipe takes 25% of what is unbanked", function()
	local run = TowerRun.New(1, 0)
	TowerRun.AddEarnings(run, 1000, 41, 12)
	TowerRun.AddRelicPayout(run, 250, 10)
	TowerRun.RecordFloorClear(run, 1)
	assert(run.UnbankedGold == 1000 and run.GoldEarned == 1000 and run.Kills == 12)
	assert(run.UnbankedGems == 41 and run.RelicGold == 250 and run.RelicGems == 10, "relic payouts are banked, not at risk")
	local lossGold, lossGems = TowerRun.WipeLoss(run, 5000, 500)
	assert(lossGold == 250 and lossGems == 10, "25% of unbanked, rounded down")
	-- Never more than the balance holds.
	local capGold, capGems = TowerRun.WipeLoss(run, 100, 3)
	assert(capGold == 100 and capGems == 3)
	local bankedGold, bankedGems = TowerRun.Bank(run)
	assert(bankedGold == 1000 and bankedGems == 41 and run.UnbankedGold == 0 and run.UnbankedGems == 0)
	assert(run.Streak == 1, "banking does not reset the streak")
	local afterGold, afterGems = TowerRun.WipeLoss(run, 5000, 500)
	assert(afterGold == 0 and afterGems == 0, "banked earnings cannot be lost")
	local summary = TowerRun.Summary(run, "WIPE", 90, 250, 10)
	assert(summary.Reason == "WIPE" and summary.Seconds == 90 and summary.LossGold == 250 and summary.BestStreak == 1)
end)


test("Phase 6: Rift Attunement caps one hero's tower power by the Master's highest floor and rises as they climb", function()
	local astrea = { TemplateId = "hero_astrea", Stars = 7, Level = 1, QualityScalar = 1, Rarity = 7, ComaUntilTimestamp = 0 }
	local weapon = { Star = 1, Rarity = 1, TemplateId = "art_hunters_shortbow" }
	local raw = StatFormulas.GetHeroPower(astrea, weapon)
	local last = 0
	for floorReached = 1, 50 do
		local cap = StatFormulas.GetAttunementCap(floorReached)
		assert(cap >= last, "the cap never falls as the Master climbs")
		last = cap
	end
	local cap10 = StatFormulas.GetAttunementCap(10)
	assert(raw > cap10, string.format("a Mythical pull must exceed what floor 10 allows: raw %d cap10 %d", raw, cap10))
	local mult = StatFormulas.GetAttunedMultiplier(astrea, weapon, 1, cap10)
	assert(mult < 1 and mult > 0, "mult " .. tostring(mult))
	-- One factor scales ATK and HP together, landing the hero exactly on the cap and keeping its attack speed.
	local attuned = StatFormulas.GetHeroPower(astrea, weapon, mult)
	assert(math.abs(attuned - cap10) / cap10 < 0.001, string.format("attuned %d vs cap %d", attuned, cap10))
	local full = StatFormulas.GetCombatSnapshot(astrea, weapon, false, false, 1)
	local capped = StatFormulas.GetCombatSnapshot(astrea, weapon, false, false, mult)
	assert(capped.AttackInterval == full.AttackInterval and capped.AttackSpeed == full.AttackSpeed)
	assert(math.abs(capped.Health / full.Health - mult) < 1e-3 and math.abs(capped.AttackDamage / full.AttackDamage - mult) < 1e-3)
	-- Heroes under the cap are untouched, and the starter pair is under floor 1's cap.
	local catio = { TemplateId = "hero_catio", Stars = 3, Level = 1, QualityScalar = 1, Rarity = 3, ComaUntilTimestamp = 0 }
	assert(StatFormulas.GetAttunedMultiplier(catio, { Star = 1, Rarity = 1, TemplateId = "art_miner_pickaxe" }, 1.2, StatFormulas.GetAttunementCap(1)) == 1.2)
	assert(StatFormulas.GetAttunedMultiplier(astrea, weapon, 1.2, nil) == 1.2, "no cap means no change")
	-- Labor is not capped: the effective labor formula does not take the cap at all.
	assert(StatFormulas.GetEffectiveLabor(astrea, "FACILITY_GUARD_POST") > 0)
end)


test("Phase 6 M6: the sim runs at 10 Hz and finer ticks let weapon attack-speed bonuses show", function()
	assert(Balance.TickSeconds == 0.1)
	assert(Balance.ScheduledInterval(0.85) == 0.9 and Balance.ScheduledInterval(0.79) == 0.8 and Balance.ScheduledInterval(0.05) == 0.1)
	local han = { TemplateId = "hero_han", Stars = 1, Level = 1, QualityScalar = 1, Rarity = 1, ComaUntilTimestamp = 0 }
	local bare = StatFormulas.GetCombatSnapshot(han, nil)
	local uncommon = StatFormulas.GetCombatSnapshot(han, { Star = 1, Rarity = 2, TemplateId = "art_rusty_daggers" })
	-- At 5 Hz (0.2 s steps) an Uncommon weapon's +7.5% left Han at a 1.0 s tick; at 10 Hz it now drops him from 0.9 s to 0.8 s.
	assert(bare.TickInterval == 0.9 and uncommon.TickInterval == 0.8, string.format("bare %.1f uncommon %.1f", bare.TickInterval, uncommon.TickInterval))
	assert(uncommon.DPS > bare.DPS)
end)

print("Phase 6 run-loop tests: " .. passed .. " passed")
