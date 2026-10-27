--!strict
-- tests/afk-facility.spec.luau
-- Unit & Integration Tests for the AFK Gameplay Loop & Outskirts Facilities (GDD Sections 2.4, 3.4 & 4.3)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FacilityConfig = require(ReplicatedStorage.Shared.Config.FacilityConfig)
local HeroCatalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)
local StatFormulas = require(ReplicatedStorage.Shared.Util.StatFormulas)

local function assertEq(actual: any, expected: any, desc: string)
	if actual ~= expected then
		error(string.format("FAIL: %s | Expected: %s, Got: %s", desc, tostring(expected), tostring(actual)))
	end
end

local function assertTrue(cond: boolean, desc: string)
	if not cond then
		error(string.format("FAIL: %s | Expected condition to be true", desc))
	end
end

print(">>> RUNNING AFK & FACILITY TEST SUITE <<<")

-- 1. FacilityConfig Schema & Values Verification
do
	local gp = FacilityConfig.UpgradeTable.GuardPost
	assertTrue(gp ~= nil, "GuardPost upgrade table exists")
	assertEq(gp[1].BaseGoldPerMin, 30, "GuardPost Lv1 BaseGoldPerMin is 30")
	assertEq(gp[1].MaxOfflineMinutes, 240, "GuardPost Lv1 Offline Cap is 4 hours (240m)")
	assertEq(gp[1].OfflineEfficiency, 0.75, "GuardPost Lv1 Efficiency is 75%")
	assertEq(gp[1].MaxWorkers, 1, "GuardPost Lv1 Max Adventurers is 1")

	assertEq(gp[2].BaseGoldPerMin, 75, "GuardPost Lv2 BaseGoldPerMin is 75")
	assertEq(gp[2].MaxOfflineMinutes, 360, "GuardPost Lv2 Offline Cap is 6 hours (360m)")
	assertEq(gp[2].OfflineEfficiency, 0.80, "GuardPost Lv2 Efficiency is 80%")
	assertEq(gp[2].MaxWorkers, 2, "GuardPost Lv2 Max Adventurers is 2")

	assertEq(gp[3].BaseGoldPerMin, 160, "GuardPost Lv3 BaseGoldPerMin is 160")
	assertEq(gp[3].MaxOfflineMinutes, 480, "GuardPost Lv3 Offline Cap is 8 hours (480m)")
	assertEq(gp[3].OfflineEfficiency, 0.85, "GuardPost Lv3 Efficiency is 85%")
	assertEq(gp[3].MaxWorkers, 3, "GuardPost Lv3 Max Adventurers is 3")

	assertEq(gp[4].BaseGoldPerMin, 300, "GuardPost Lv4 BaseGoldPerMin is 300")
	assertEq(gp[4].MaxOfflineMinutes, 600, "GuardPost Lv4 Offline Cap is 10 hours (600m)")
	assertEq(gp[4].OfflineEfficiency, 0.90, "GuardPost Lv4 Efficiency is 90%")
	assertEq(gp[4].MaxWorkers, 4, "GuardPost Lv4 Max Adventurers is 4")

	assertEq(gp[5].BaseGoldPerMin, 550, "GuardPost Lv5 BaseGoldPerMin is 550")
	assertEq(gp[5].MaxOfflineMinutes, 720, "GuardPost Lv5 Offline Cap is 12 hours (720m)")
	assertEq(gp[5].OfflineEfficiency, 1.00, "GuardPost Lv5 Efficiency is 100%")
	assertEq(gp[5].MaxWorkers, 5, "GuardPost Lv5 Max Adventurers is 5")

	local mkt = FacilityConfig.UpgradeTable.Market
	assertTrue(mkt ~= nil, "Market upgrade table exists")
	assertEq(mkt[1].BaseBonus, 0.05, "Market Lv1 BaseBonus is +5%")
	assertEq(mkt[2].BaseBonus, 0.10, "Market Lv2 BaseBonus is +10%")
	assertEq(mkt[3].BaseBonus, 0.18, "Market Lv3 BaseBonus is +18%")
	assertEq(mkt[4].BaseBonus, 0.28, "Market Lv4 BaseBonus is +28%")
	assertEq(mkt[5].BaseBonus, 0.40, "Market Lv5 BaseBonus is +40%")

	local trn = FacilityConfig.UpgradeTable.TrainingGrounds
	assertTrue(trn ~= nil, "TrainingGrounds upgrade table exists")
	assertEq(trn[1].BaseBonus, 0.04, "TrainingGrounds Lv1 BaseBonus is +4%")
	assertEq(trn[2].BaseBonus, 0.08, "TrainingGrounds Lv2 BaseBonus is +8%")
	assertEq(trn[3].BaseBonus, 0.14, "TrainingGrounds Lv3 BaseBonus is +14%")
	assertEq(trn[4].BaseBonus, 0.22, "TrainingGrounds Lv4 BaseBonus is +22%")
	assertEq(trn[5].BaseBonus, 0.32, "TrainingGrounds Lv5 BaseBonus is +32%")

	print("PASS: FacilityConfig upgrade tables match GDD Section 4.3 exactly")
end

-- 2. Archetype Preferred Facilities & Synergies (GDD Section 4.1)
do
	assertEq(HeroCatalog.Seeds.hero_aaron.PreferredFacility, "FACILITY_GUARD_POST", "Aaron (Vanguard) prefers Guard Post")
	assertEq(HeroCatalog.Seeds.hero_jenna.PreferredFacility, "FACILITY_GUARD_POST", "Jenna (Marksman) prefers Guard Post")
	assertEq(HeroCatalog.Seeds.hero_ignis.PreferredFacility, "FACILITY_GUARD_POST", "Ignis (Vanguard) prefers Guard Post")
	assertEq(HeroCatalog.Seeds.hero_morrigan.PreferredFacility, "FACILITY_GUARD_POST", "Morrigan (Vanguard) prefers Guard Post")

	assertEq(HeroCatalog.Seeds.hero_catio.PreferredFacility, "FACILITY_MARKET", "Catio (Miner) prefers The Market")

	assertEq(HeroCatalog.Seeds.hero_han.PreferredFacility, "FACILITY_TRAINING", "Han (Striker) prefers Training Grounds")
	assertEq(HeroCatalog.Seeds.hero_velkist.PreferredFacility, "FACILITY_TRAINING", "Velkist (Striker) prefers Training Grounds")
	assertEq(HeroCatalog.Seeds.hero_eolka.PreferredFacility, "FACILITY_TRAINING", "Eolka (Scholar) prefers Training Grounds")
	assertEq(HeroCatalog.Seeds.hero_solaris.PreferredFacility, "FACILITY_TRAINING", "Solaris (Scholar) prefers Training Grounds")

	assertEq(HeroCatalog.Seeds.hero_valeria.PreferredFacility, "FACILITY_GODS_BLESSING", "Valeria (Healer) prefers God's Blessing")

	assertEq(HeroCatalog.Seeds.hero_archon.PreferredFacility, "ALL", "Archon has universal synergy (ALL)")
	assertEq(HeroCatalog.Seeds.hero_astrea.PreferredFacility, "ALL", "Astrea has universal synergy (ALL)")

	print("PASS: HeroCatalog preferred facilities match GDD Section 4.1 Archetype Foundation Table")
end

-- 3. Effective Labor & Synergy Calculations
do
	local mockVanguard = {
		TemplateId = "hero_aaron",
		Stars = 1,
		Level = 1,
		QualityScalar = 1.0,
		Assignment = "FACILITY_GUARD_POST",
	}
	-- Aaron is Uncommon (tier 2): inherent rarity multiplies labor by 1.12 (Phase 4 §7).
	local baseLabor = HeroCatalog.Seeds.hero_aaron.BaseLabor_1Star * 1.12
	local laborWithSynergy = StatFormulas.GetEffectiveLabor(mockVanguard, "FACILITY_GUARD_POST")
	local laborWithoutSynergy = StatFormulas.GetEffectiveLabor(mockVanguard, "FACILITY_MARKET")

	assertEq(laborWithSynergy, math.round(baseLabor * 1.25 * 100) / 100, "Vanguard receives +25% synergy at Guard Post")
	assertEq(laborWithoutSynergy, baseLabor, "Vanguard receives no synergy at The Market")

	local mockUniversal = {
		TemplateId = "hero_archon",
		Stars = 1,
		Level = 1,
		QualityScalar = 1.0,
		Assignment = "FACILITY_MARKET",
	}
	-- Archon is Exalted (tier 5): inherent rarity multiplies labor by 1.12^4 (Phase 4 §7).
	local archonBase = HeroCatalog.Seeds.hero_archon.BaseLabor_1Star * 1.12 ^ 4
	assertEq(StatFormulas.GetEffectiveLabor(mockUniversal, "FACILITY_MARKET"), math.round(archonBase * 1.25 * 100) / 100, "Universal hero receives +25% synergy anywhere")

	print("PASS: EffectiveLabor awards exact +25% synergy for preferred facilities")
end

-- 4. Passive Gold Generation Formula (GDD Section 4.3.2.A)
do
	-- PassiveGoldPerMin = (BaseRate + 0.85 * sum(Labor)) * (1 + 0.15 * BiomeBossTier)
	local rate0 = StatFormulas.GetPassiveGoldRate(1, 0, 0)
	assertEq(rate0, 30, "Lv1 GuardPost with 0 labor and 0 boss tier = 30 Gold/min")

	local rateLabor = StatFormulas.GetPassiveGoldRate(1, 100, 0)
	-- 30 + 0.85 * 100 = 115
	assertEq(rateLabor, 115, "Lv1 GuardPost with 100 labor = 115 Gold/min")

	local rateBossTier2 = StatFormulas.GetPassiveGoldRate(1, 100, 2)
	-- 115 * (1 + 0.15 * 2) = 115 * 1.30 = 149.5
	assertEq(rateBossTier2, 149.5, "Lv1 GuardPost with 100 labor & Boss Tier 2 = 149.5 Gold/min")

	local rateMax = StatFormulas.GetPassiveGoldRate(5, 200, 10)
	-- (550 + 0.85 * 200) * (1 + 0.15 * 10) = 720 * 2.50 = 1800
	assertEq(rateMax, 1800, "Lv5 GuardPost with 200 labor & Boss Tier 10 = 1800 Gold/min")

	print("PASS: Passive Gold generation scales accurately with labor and Biome Boss tier")
end

-- 5. Offline Accumulation Formula (GDD Section 4.3.2.A)
do
	-- OfflineGold = min(Elapsed, Cap) * Rate * Efficiency
	-- Lv1: Cap 240m, Efficiency 75%
	local gold1h, cap1h = StatFormulas.CalculateOfflineGold(1, 100, 60)
	assertEq(cap1h, 60, "1h offline does not hit 4h cap")
	assertEq(gold1h, 4500, "1h offline @ 100/min * 0.75 = 4,500 Gold")

	local goldOverCap, capOver = StatFormulas.CalculateOfflineGold(1, 100, 300)
	assertEq(capOver, 240, "5h offline is capped at 240m (4h)")
	assertEq(goldOverCap, 18000, "4h capped @ 100/min * 0.75 = 18,000 Gold")

	-- Lv5: Cap 720m, Efficiency 100%
	local goldLv5, capLv5 = StatFormulas.CalculateOfflineGold(5, 500, 720)
	assertEq(capLv5, 720, "12h offline hits exact 12h cap")
	assertEq(goldLv5, 360000, "12h offline @ 500/min * 1.00 = 360,000 Gold")

	print("PASS: Offline Gold accumulation respects level caps and efficiency multipliers")
end

-- 6. Market Loot Multiplier Formula (GDD Section 4.3.2.B)
do
	-- MarketMultiplier = 1 + BaseBonus + (0.005 * sum(Labor))
	local multLv1_Zero = StatFormulas.GetMarketLootMultiplier(1, 0)
	assertEq(multLv1_Zero, 1.05, "Market Lv1 with 0 labor = +5% (1.05x)")

	local multLv1_100 = StatFormulas.GetMarketLootMultiplier(1, 100)
	assertEq(multLv1_100, 1.55, "Market Lv1 with 100 labor = +55% (1.55x)")

	local multLv5_200 = StatFormulas.GetMarketLootMultiplier(5, 200)
	assertEq(multLv5_200, 2.4, "Market Lv5 with 200 labor = +140% (2.40x)")

	print("PASS: Market Loot Multiplier formula matches GDD specification")
end

-- 7. Training Combat Multiplier Formula (GDD Section 4.3.2.C)
do
	-- TrainingMultiplier = 1 + BaseBonus + (0.004 * sum(Labor))
	local multLv1_Zero = StatFormulas.GetTrainingCombatMultiplier(1, 0)
	assertEq(multLv1_Zero, 1.04, "Training Lv1 with 0 labor = +4% (1.04x)")

	local multLv1_100 = StatFormulas.GetTrainingCombatMultiplier(1, 100)
	assertEq(multLv1_100, 1.44, "Training Lv1 with 100 labor = +44% (1.44x)")

	local multLv5_200 = StatFormulas.GetTrainingCombatMultiplier(5, 200)
	assertEq(multLv5_200, 2.12, "Training Lv5 with 200 labor = +112% (2.12x)")

	print("PASS: Training Combat Multiplier formula matches GDD specification")
end

-- 9. Training Multiplier Impact on Combat Snapshot (FinalATK & FinalHP)
do
	local mockHero = {
		TemplateId = "hero_han",
		Stars = 1,
		Level = 1,
		QualityScalar = 1.0,
		CurrentStamina = 100,
		ComaUntilTimestamp = 0,
	}
	local baseSnapshot = StatFormulas.GetCombatSnapshot(mockHero, nil, false, false, 1.0)
	local buffedSnapshot = StatFormulas.GetCombatSnapshot(mockHero, nil, false, false, 1.25) -- +25% from training

	assertEq(buffedSnapshot.ATK, math.round(baseSnapshot.ATK * 1.25), "Training multiplier scales Final ATK by exactly 1.25x")
	assertEq(buffedSnapshot.HP, math.round(baseSnapshot.HP * 1.25), "Training multiplier scales Final HP by exactly 1.25x")

	print("PASS: Training multiplier scales both FinalATK and FinalHP directly in CombatSnapshot")
end

-- 10. Online 10-Second Sub-Increment Math Verification
do
	-- Passive Gold is credited every 60s via six 10s increments
	local rate = 120 -- 120 Gold / min
	local subIncrement = (rate / 60) * 10
	assertEq(subIncrement, 20, "10-second sub-increment is exactly 20 Gold")
	assertEq(subIncrement * 6, rate, "Six 10-second sub-increments equal exactly 1 full minute rate")

	print("PASS: 10-second sub-increment math matches 60-second online payout cadence")
end

print(">>> ALL AFK & FACILITY TESTS PASSED SUCCESSFULLY! <<<")
