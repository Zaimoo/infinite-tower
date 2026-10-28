--!strict
-- tests/phase4-progression.luau
-- Phase 4: Fortress Tree, God's Blessing summon luck, inherent hero rarity and lowered hero odds,
-- the onboarding chain and the v3 save migration (docs/rework-plan/PHASE_4_ONBOARDING_AND_PROGRESSION.md).

local TreeConfig = require(nodes["ReplicatedStorage.Shared.Config.FortressTreeConfig"])
local FortressTree = require(nodes["ReplicatedStorage.Shared.Util.FortressTree"])
local SummonLuck = require(nodes["ReplicatedStorage.Shared.Util.SummonLuck"])
local Onboarding = require(nodes["ReplicatedStorage.Shared.Util.Onboarding"])
local HeroCatalog = require(nodes["ReplicatedStorage.Shared.Config.HeroCatalog"])
local FacilityConfig = require(nodes["ReplicatedStorage.Shared.Config.FacilityConfig"])
local Stats = require(nodes["ReplicatedStorage.Shared.Util.StatFormulas"])
local Migrations = require(nodes["ServerScriptService.Core.ProfileMigrations"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end

-- Fortress Tree --------------------------------------------------------------------------------

test("Phase 4: a new tree owns only the root and the Guard Post's first level", function()
	local tree = FortressTree.DefaultTree()
	assert(FortressTree.Owns(tree, "root") and FortressTree.Owns(tree, "gp_1"))
	local owned = 0
	for _ in tree.Nodes do owned += 1 end
	assert(owned == 2, "only the two default nodes")
	assert(FortressTree.FacilityLevel(tree, "GuardPost") == 1)
	for _, facility in { "Market", "TrainingGrounds", "GodsBlessing" } do
		assert(FortressTree.FacilityLevel(tree, facility) == 0, facility .. " starts unbuilt")
	end
	assert(#TreeConfig.Nodes == 33, "root + 4 facility branches x (5 levels + 2 perks) + 4 squad slots")
	assert(FortressTree.SquadSlots(tree) == 1, "a new Master starts with one squad slot")
end)

test("Phase 4: the tree rejects unknown, owned, out-of-order, floor-gated and unaffordable nodes", function()
	local tree = FortressTree.DefaultTree()
	local open = { FortressTree = true, Squad = true }
	assert(not FortressTree.CanUnlock(tree, "mk_1", 1e9, 99, { Squad = true }), "Fortress Tree still locked by onboarding")
	assert(not FortressTree.CanUnlock(tree, "nope", 1e9, 99, open), "unknown node")
	assert(not FortressTree.CanUnlock(tree, 42, 1e9, 99, open), "non-string id")
	assert(not FortressTree.CanUnlock(tree, "gp_1", 1e9, 99, open), "already owned")
	assert(not FortressTree.CanUnlock(tree, "mk_2", 1e9, 99, open), "level 2 before level 1")
	assert(not FortressTree.CanUnlock(tree, "mk_1", 999, 99, open), "Market costs 1,000 Gold")
	assert(FortressTree.CanUnlock(tree, "mk_1", 1000, 0, open))
	assert(not FortressTree.CanUnlock(tree, "gb_1", 1e9, 4, open), "Divine branch needs Floor 5")
	assert(FortressTree.CanUnlock(tree, "gb_1", 2500, 5, open))
	tree.Nodes.mk_1, tree.Nodes.mk_2 = true, true
	assert(not FortressTree.CanUnlock(tree, "mk_3", 1e9, 4, open), "level 3 needs Floor 5")
	assert(FortressTree.CanUnlock(tree, "mk_3", 1e9, 5, open))
	assert(not FortressTree.CanUnlock(tree, "mk_extra_stall", 1e9, 99, open), "perk needs level 3 first")
end)

test("Phase 4: squad slots 2-5 open through the Command branch once the Squad system is unlocked", function()
	local tree = FortressTree.DefaultTree()
	assert(not FortressTree.CanUnlock(tree, "sq_1", 1e9, 99, { Summon = true }), "needs the first summon (Squad)")
	assert(FortressTree.CanUnlock(tree, "sq_1", 500, 0, { Squad = true }), "does not need the Fortress Tree system")
	assert(not FortressTree.CanUnlock(tree, "sq_2", 1e9, 99, { Squad = true }), "slots open in order")
	tree.Nodes.sq_1 = true
	assert(FortressTree.SquadSlots(tree) == 2)
	tree.Nodes.sq_2 = true
	assert(not FortressTree.CanUnlock(tree, "sq_3", 1e9, 4, { Squad = true }), "slot 4 needs Floor 5")
	tree.Nodes.sq_3 = true
	assert(not FortressTree.CanUnlock(tree, "sq_4", 1e9, 9, { Squad = true }), "slot 5 needs Floor 10")
	tree.Nodes.sq_4 = true
	assert(FortressTree.SquadSlots(tree) == 5, "a full squad")
	assert(FortressTree.FacilityLevel(tree, "Market") == 0, "slot nodes never count as a facility")
end)

test("Phase 4: facility level counts consecutive level nodes and perks add their bonuses", function()
	local tree = FortressTree.DefaultTree()
	tree.Nodes.tg_1, tree.Nodes.tg_2, tree.Nodes.tg_3 = true, true, true
	tree.Nodes.tg_5 = true -- a hole at level 4 from a bad save cannot skip ahead
	assert(FortressTree.FacilityLevel(tree, "TrainingGrounds") == 3)
	tree.Nodes.tg_drill_sergeant, tree.Nodes.gp_night_watch, tree.Nodes.gb_saints_favor = true, true, true
	local perks = FortressTree.PerkBonuses(tree)
	assert(perks.TrainingWorkers == 1 and perks.OfflineMinutes == 120 and near(perks.BlessingLuck, 0.03))
	assert(perks.MarketWorkers == 0 and perks.MarketBonus == 0)
	assert(Stats.GetFacilityMaxWorkers("TrainingGrounds", 3, perks) == 3, "2 at Lv.3 plus Drill Sergeant")
	assert(Stats.GetFacilityMaxWorkers("Market", 0, perks) == 0, "an unbuilt facility has no slots")
end)

test("Phase 4: perks feed the facility formulas", function()
	local perks = FortressTree.PerkBonuses({ Nodes = { gp_long_patrols = true, mk_appraiser = true, tg_veteran_drills = true, gp_night_watch = true } })
	local base = Stats.GetPassiveGoldRate(5, 0, 0)
	assert(near(Stats.GetPassiveGoldRate(5, 0, 0, perks), base * 1.10, 0.01), "Long Patrols +10% base rate")
	assert(near(Stats.GetMarketLootMultiplier(5, 0, perks), 1.45), "Market Lv.5 40% + Appraiser 5%")
	assert(near(Stats.GetTrainingCombatMultiplier(5, 0, perks), 1.35), "Training Lv.5 32% + Veteran Drills 3%")
	local _, capped = Stats.CalculateOfflineGold(1, 10, 10000, perks)
	assert(capped == 240 + 120, "Night Watch adds 2 hours to the Lv.1 cap")
end)

test("Phase 4: migration grants level nodes for bought levels and never perks", function()
	local tree = FortressTree.NodesFromFacilityLevels({ GuardPost = { Level = 3 }, Market = { Level = 1 }, TrainingGrounds = { Level = 0 } })
	assert(FortressTree.FacilityLevel(tree, "GuardPost") == 3 and FortressTree.FacilityLevel(tree, "Market") == 1)
	assert(FortressTree.FacilityLevel(tree, "TrainingGrounds") == 0 and FortressTree.FacilityLevel(tree, "GodsBlessing") == 0)
	for _, node in TreeConfig.Nodes do
		if node.Kind == "PERK" then assert(not tree.Nodes[node.Id], "no perk from migration: " .. node.Id) end
	end
	assert(FortressTree.FacilityLevel(FortressTree.NodesFromFacilityLevels(nil), "GuardPost") == 1, "Guard Post Lv.1 is always owned")
end)

-- God's Blessing summon luck --------------------------------------------------------------------

test("Phase 4: summon luck follows level, labor and perk, capped at +50%", function()
	assert(SummonLuck.Luck(0, 500, 0.03) == 0, "no blessing before the angel is built")
	assert(near(SummonLuck.Luck(1, 0), 0.04))
	assert(near(SummonLuck.Luck(5, 40), 0.48), "the spec example: 0.32 + 0.004 x 40")
	assert(near(SummonLuck.Luck(5, 40, 0.03), 0.50), "Saint's Favor cannot pass the cap")
	assert(near(SummonLuck.Luck(5, 1000), FacilityConfig.Constants.MaxSummonLuck))
end)

test("Phase 4: boosted odds keep summing to 1 and match the spec table", function()
	local base = HeroCatalog.LimitedBanner.Rates :: { number }
	local boosted = SummonLuck.ApplyLuck(base, 0.48)
	local expected = { 0.408, 0.3552, 0.148, 0.06216, 0.02072, 0.004884, 0.001036 }
	local sum = 0
	for i, rate in boosted do
		sum += rate
		assert(near(rate, expected[i], 1e-9), "tier " .. i)
	end
	assert(near(sum, 1, 1e-12))
	assert(base[1] == 0.6, "ApplyLuck never mutates the catalog")
	for _, banner in { HeroCatalog.PermanentBanner, HeroCatalog.LimitedBanner } do
		local total = 0
		for _, rate in SummonLuck.ApplyLuck(banner.Rates :: { number }, FacilityConfig.Constants.MaxSummonLuck) do
			assert(rate >= 0)
			total += rate
		end
		assert(near(total, 1, 1e-12))
	end
end)

test("Phase 4: rolls pick rare tiers on low numbers and the 10-pull guarantee floors the tier", function()
	local rates = { 0.6, 0.24, 0.10, 0.042, 0.014, 0.0033, 0.0007 }
	assert(SummonLuck.Roll(rates, 0) == 7)
	assert(SummonLuck.Roll(rates, 0.0006) == 7 and SummonLuck.Roll(rates, 0.0008) == 6)
	assert(SummonLuck.Roll(rates, 0.9999) == 1)
	for _, r in { 0, 0.25, 0.5, 0.75, 0.9999 } do
		assert(SummonLuck.RollAtLeast(rates, 3, r) >= 3)
	end
	assert(SummonLuck.RollAtLeast(rates, 3, 0.9999) == 3)
end)

-- Hero rarity & banner odds ----------------------------------------------------------------------

test("Phase 4: every launch hero's rarity equals its summoned star and only scales stats", function()
	for id, seed in HeroCatalog.Seeds do
		assert(seed.Rarity == seed.BaseStar, id .. " rarity tier")
		assert(HeroCatalog.RarityOf(id) == seed.Rarity)
	end
	assert(HeroCatalog.RarityName(1) == "Common" and HeroCatalog.RarityName(7) == "Mythical")
	-- A Common hero keeps the pre-rarity numbers; others gain 1.35x per tier on combat, 1.12x on labor.
	local han = { TemplateId = "hero_han", Stars = 1, Level = 1, QualityScalar = 1 }
	assert(Stats.GetCombatSnapshot(han).AttackDamage == 40)
	local astrea = { TemplateId = "hero_astrea", Stars = 7, Level = 1, QualityScalar = 1 }
	assert(Stats.GetCombatSnapshot(astrea).AttackDamage == math.round(48 * 3 ^ 6 * 1.35 ^ 6))
	assert(HeroCatalog.Seeds.hero_astrea.NativeHP == 1014981, "GDD roster table value")
	-- A saved Rarity field wins over the template, so a future rarity change cannot move old heroes.
	local saved = { TemplateId = "hero_han", Rarity = 2, Stars = 1, Level = 1, QualityScalar = 1 }
	assert(Stats.GetCombatSnapshot(saved).AttackDamage == math.round(40 * 1.35))
	assert(Stats.GetEffectiveLabor({ TemplateId = "hero_valeria", Stars = 4, Level = 1, QualityScalar = 1 }, "FACILITY_GODS_BLESSING")
		== math.round(18 * 1.12 ^ 3 * 1.35 ^ 3 * 1.25 * 100) / 100, "Healers get +25% synergy at God's Blessing")
end)

test("Phase 4: hero banners use the lowered odds, raised pity and a Rare 10-pull floor", function()
	local perm, lim = HeroCatalog.PermanentBanner, HeroCatalog.LimitedBanner
	assert(perm.MaxPity == 80 and lim.MaxPity == 90)
	assert(perm.TenPullMinTier == 3 and lim.TenPullMinTier == 3)
	assert(near(perm.Rates[5], 0.005) and near(lim.Rates[7], 0.0007))
	for _, banner in { perm, lim } do
		local sum = 0
		for _, rate in banner.Rates do sum += rate end
		assert(near(sum, 1, 1e-9), banner.BannerId .. " rates sum to 1")
	end
end)

-- Onboarding & migration -------------------------------------------------------------------------

test("Phase 4: onboarding advances only on the active step's event and merges unlocks", function()
	local state = Onboarding.NewState()
	local unlocks = { Summon = true }
	assert(Onboarding.IsUnlocked(unlocks, "Summon") and not Onboarding.IsUnlocked(unlocks, "Squad"))
	assert(Onboarding.Report(state, unlocks, "FloorCleared") == nil, "out-of-order events are ignored")
	local step = Onboarding.Report(state, unlocks, "HeroSummoned")
	assert(step and step.Id == "step_summon" and unlocks.Squad and state.StepIndex == 2)
	for _, event in { "SquadDeployed", "FloorCleared", "ArtifactUpgraded", "FacilityAssigned", "PitUsed", "TreeNodeUnlocked" } do
		assert(Onboarding.Report(state, unlocks, event), event)
	end
	assert(unlocks.Tower and unlocks.Forge and unlocks.Facilities and unlocks.FortressTree and unlocks.Pit and unlocks.TowerFloor5)
	assert(Onboarding.ActiveStep(state) == nil, "chain complete")
end)

test("Phase 4: v3 migration stamps rarity, keeps stars, builds the tree and grandfathers unlocks", function()
	local profile: any = {
		SchemaVersion = 2,
		MaxFloorReached = 6,
		Heroes = {
			a = { TemplateId = "hero_ignis", Stars = 5, Level = 37, Assignment = "SQUAD_SLOT_1" },
			b = { TemplateId = "hero_han", Stars = 3, Level = 12, Assignment = "SQUAD_SLOT_3" },
		},
		Facilities = { GuardPost = { Level = 2 }, Market = { Level = 1 }, TrainingGrounds = { Level = 1 } },
	}
	Migrations.Run(profile)
	assert(profile.SchemaVersion == 3)
	assert(profile.Heroes.a.Rarity == 5 and profile.Heroes.a.Stars == 5 and profile.Heroes.a.Level == 37)
	assert(profile.Heroes.b.Rarity == 1 and profile.Heroes.b.Stars == 3)
	assert(FortressTree.FacilityLevel(profile.FortressTree, "GuardPost") == 2)
	assert(FortressTree.FacilityLevel(profile.FortressTree, "Market") == 1)
	assert(profile.Facilities.GodsBlessing.Level == 0)
	assert(FortressTree.SquadSlots(profile.FortressTree) == 3, "keeps every slot a saved hero stands in")
	assert(profile.Unlocks.Tower and profile.Unlocks.Forge and profile.Unlocks.FortressTree and profile.Unlocks.Pit)
	-- Steps whose systems are already open are skipped, so the tracker shows a real next goal.
	assert(Onboarding.ActiveStep(profile.Onboarding).Id == "step_pit")
	Migrations.Run(profile)
	assert(profile.Heroes.a.Rarity == 5, "migration is idempotent")
end)

test("Phase 5: Squad Power sums round(10 x DPS + Health) over deployed heroes only", function()
	local han = { TemplateId = "hero_han", Stars = 1, Level = 1, QualityScalar = 1, Assignment = "SQUAD_SLOT_1" }
	local jenna = { TemplateId = "hero_jenna", Stars = 1, Level = 1, QualityScalar = 1, Assignment = "SQUAD_SLOT_2", ComaUntilTimestamp = os.time() + 60 }
	local benched = { TemplateId = "hero_ignis", Stars = 5, Level = 50, QualityScalar = 1, Assignment = "BENCHED" }
	local profile = { Heroes = { a = han, b = jenna, c = benched }, Artifacts = {} }
	local function expected(hero: any): number
		local v = Stats.GetCombatSnapshot(hero)
		return math.round(10 * (v.AttackDamage / v.TickInterval) + v.Health)
	end
	local total, perHero = Stats.GetSquadPower(profile, 1)
	assert(perHero.a == expected(han) and perHero.b == expected(jenna), "a downed hero still counts")
	assert(perHero.c == nil, "benched heroes do not count")
	assert(total == perHero.a + perHero.b)
	local boosted = Stats.GetSquadPower(profile, 1.2)
	assert(boosted > total, "the Training Grounds multiplier raises Squad Power")
end)

test("Phase 5: Recommended Power starts near a fresh squad and rises biome to biome", function()
	local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
	local first = Floors.RecommendedPower(1)
	assert(first >= 500 and first <= 900, "Floor 1 matches a fresh one-star hero (~700), got " .. first)
	-- A boss floor can out-rank the next biome's first floor, so compare one biome apart.
	for id = 1, Floors.FloorCount - 5 do
		assert(Floors.RecommendedPower(id + 5) > Floors.RecommendedPower(id), "Recommended Power rises a biome later, floor " .. id)
	end
	assert(Floors.RecommendedPower(0) == 0 and Floors.RecommendedPower(99) == 0, "unknown floors have no recommendation")
end)

test("Phase 5: store summon packs become Gems for players restricted from paid random items", function()
	local Shop = require(nodes["ReplicatedStorage.Shared.Config.ShopConfig"])
	local pack = assert(Shop.ById("pack_summon_10"))
	local safe = Shop.SafeGrant(pack.Grant, true)
	assert(safe.Kind == "Gems" and safe.Amount == 10 * Shop.GemsPerSummon, "restricted players get Gems")
	assert(Shop.SafeGrant(pack.Grant, false).Kind == "Summons", "others get the summons")
	local gems = assert(Shop.ById("gems_550"))
	assert(Shop.SafeGrant(gems.Grant, true) == gems.Grant, "currency grants are unchanged")
	for _, list in { Shop.Featured.Offers, Shop.Gems, Shop.Gold } do
		for _, offer in list do
			assert(offer.RobuxPrice > 0 and offer.Grant.Amount > 0, offer.Id .. " has a price and a grant")
		end
	end
end)

print(string.format("phase4-progression: %d tests passed", passed))
