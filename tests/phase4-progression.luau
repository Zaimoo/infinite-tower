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
	assert(#TreeConfig.Nodes == 39, "root + 4 facility branches x (5 levels + 2 perks) + 4 squad slots + 6 storage")
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
	local expected = { 0.424872, 0.3552, 0.1406, 0.05624, 0.01776, 0.00444, 0.000888 }
	local sum = 0
	for i, rate in boosted do
		sum += rate
		assert(near(rate, expected[i], 1e-9), "tier " .. i)
	end
	assert(near(sum, 1, 1e-12))
	assert(base[1] == 0.6114, "ApplyLuck never mutates the catalog")
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

test("Phase 4: every launch hero is summoned at 1 star and its rarity only scales stats", function()
	for id, seed in HeroCatalog.Seeds do
		assert(seed.BaseStar == 1, id .. " is summoned at 1 star")
		assert(HeroCatalog.RarityOf(id) == seed.Rarity)
	end
	assert(HeroCatalog.RarityName(1) == "Common" and HeroCatalog.RarityName(7) == "Mythical")
	-- A Common hero keeps the pre-rarity numbers. Higher tiers carry their old summon-star bonus (3x and 1.35x per tier,
	-- on top of 1.35x and 1.12x), at 100% up to Rare and 50% from Superior; promotion adds 1.5x per star.
	local jenna = { TemplateId = "hero_jenna", Stars = 1, Level = 1, QualityScalar = 1 }
	assert(Stats.GetCombatSnapshot(jenna).AttackDamage == 34)
	-- Han is Mythical now, but a Han summoned while he was the Common starter keeps his saved rarity.
	assert(HeroCatalog.RarityOf("hero_han") == 7 and HeroCatalog.Seeds.hero_han.NativeATK == math.round(40 * (0.5 * (3 * 1.35) ^ 6)))
	assert(Stats.GetCombatSnapshot({ TemplateId = "hero_han", Stars = 1, Level = 1, QualityScalar = 1 }).AttackDamage == HeroCatalog.Seeds.hero_han.NativeATK)
	assert(Stats.GetCombatSnapshot({ TemplateId = "hero_han", Rarity = 1, Stars = 1, Level = 1, QualityScalar = 1 }).AttackDamage == 40)
	local astrea = { TemplateId = "hero_astrea", Stars = 7, Level = 1, QualityScalar = 1 }
	assert(Stats.GetCombatSnapshot(astrea).AttackDamage == math.round(48 * (1.5 ^ 6 * 1.08 ^ 60 * (0.5 * (3 * 1.35) ^ 6))))
	assert(HeroCatalog.Seeds.hero_astrea.NativeHP == math.round(230 * (1 * (0.5 * (3 * 1.35) ^ 6))), "GDD roster table value")
	-- A saved Rarity field wins over the template, so a future rarity change cannot move old heroes.
	local saved = { TemplateId = "hero_han", Rarity = 2, Stars = 1, Level = 1, QualityScalar = 1 }
	assert(Stats.GetCombatSnapshot(saved).AttackDamage == math.round(40 * (3 * 1.35)))
	assert(Stats.GetEffectiveLabor({ TemplateId = "hero_valeria", Stars = 4, Level = 1, QualityScalar = 1 }, "FACILITY_GODS_BLESSING")
		== math.round(18 * (0.5 * (1.35 * 1.12) ^ 4) * 1.35 ^ 3 * (1 + 0.05 * 30) * 1.25 * 100) / 100, "Healers get +25% synergy at God's Blessing")
end)

test("Phase 4: hero banners use the lowered odds, raised pity and a Rare 10-pull floor", function()
	local perm, lim = HeroCatalog.PermanentBanner, HeroCatalog.LimitedBanner
	assert(perm.MaxPity == 120 and lim.MaxPity == 100)
	assert(perm.PityMinTier == 5 and lim.PityMinTier == 5, "hard pity guarantees Exalted+ on both hero banners")
	assert(perm.TenPullMinTier == 3 and lim.TenPullMinTier == 3)
	assert(near(perm.Rates[5], 0.0033) and near(lim.Rates[7], 0.0006))
	assert(perm.Cost1X == 100 and perm.Cost10X == 900, "Call of the Rift costs 100 / 900")
	assert(lim.Cost1X == 200 and lim.Cost10X == 1800, "A Star's Arrival costs 200 / 1,800")
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

test("Phase 4: v3 through v8 migration stamps rarity, rebases stars, builds the tree and grandfathers unlocks", function()
	local profile: any = {
		SchemaVersion = 2,
		MaxFloorReached = 6,
		Heroes = {
			a = { TemplateId = "hero_ignis", Stars = 5, Level = 37, Assignment = "SQUAD_SLOT_1" },
			b = { TemplateId = "hero_han", Stars = 3, Level = 12, Assignment = "SQUAD_SLOT_3" },
		},
		Facilities = { GuardPost = { Level = 2, AssignedHeroUUIDs = { "a" }, UncollectedOutput = 40, BlessedUntil = 99, LeechedUntil = 99,
			LeechVisitorUserId = 7, LastRuneTimestamp = 5, LastRuneWasLeech = true }, Market = { Level = 1 }, TrainingGrounds = { Level = 1 } },
		Social = { PvPImmunityUntilTimestamp = 0, MimicIllusionMode = "TRUE_STATE", Stats = { LeechesPurged = 2 } },
		Currencies = { Gold = 1000, Gems = 50 },
		PitMaterials = { SoulEssence = 10, PromotionStone = 3, ImprintCatalyst = 2 },
	}
	profile.Heroes.a.InheritedImprints = { melee_memory = 2 }
	profile.Heroes.a.ImprintCapacity = 3
	profile.Heroes.a.PassiveTrait = "Rift Warlord (+35% ATK, +20% DMG Reduction)"
	profile.Heroes.a.SynthesisHistory = { DonorsConsumed = 4, ImprintsPerformed = 2 }
	Migrations.Run(profile)
	assert(profile.SchemaVersion == 8)
	assert(profile.Rewards.Daily.Streak == 0 and profile.Rewards.Weekly.LastClaimWeek == 0, "v8 adds unclaimed rewards")
	-- v7: imprints are gone and held catalysts are refunded at their crafting cost (150 Gold, 15 Gems, 4 Soul Essence).
	assert(profile.Heroes.a.InheritedImprints == nil and profile.Heroes.a.ImprintCapacity == nil, "v7 strips hero imprints")
	assert(profile.Heroes.a.PassiveTrait == nil, "v7 strips the passive trait label")
	assert(profile.Heroes.a.SynthesisHistory.ImprintsPerformed == nil and profile.Heroes.a.SynthesisHistory.DonorsConsumed == 4)
	assert(profile.PitMaterials.ImprintCatalyst == nil and profile.PitMaterials.SoulEssence == 18 and profile.PitMaterials.PromotionStone == 3)
	assert(profile.Currencies.Gold == 1300 and profile.Currencies.Gems == 80, "catalyst refund")
	-- v7: the retired social systems and their facility fields are gone; real facility data stays.
	assert(profile.Social == nil, "v7 drops the retired Social block")
	local gp = profile.Facilities.GuardPost
	assert(gp.Level == 2 and gp.AssignedHeroUUIDs[1] == "a", "v7 keeps facility levels and workers")
	assert(gp.UncollectedOutput == nil and gp.BlessedUntil == nil and gp.LeechedUntil == nil and gp.LeechVisitorUserId == nil
		and gp.LastRuneTimestamp == nil and gp.LastRuneWasLeech == nil, "v7 strips rune and claim-chest fields")
	-- v4: the 4 stars Ignis got for free at summon are removed, and the level is clamped to the new 1-star cap.
	assert(profile.Heroes.a.Rarity == 5 and profile.Heroes.a.Stars == 1 and profile.Heroes.a.Level == 10)
	assert(profile.Heroes.b.Rarity == 1 and profile.Heroes.b.Stars == 3)
	assert(FortressTree.FacilityLevel(profile.FortressTree, "GuardPost") == 2)
	assert(FortressTree.FacilityLevel(profile.FortressTree, "Market") == 1)
	assert(profile.Facilities.GodsBlessing.Level == 0)
	assert(FortressTree.SquadSlots(profile.FortressTree) == 3, "keeps every slot a saved hero stands in")
	assert(profile.Unlocks.Tower and profile.Unlocks.Forge and profile.Unlocks.FortressTree and profile.Unlocks.Pit)
	-- Steps whose systems are already open are skipped, so the tracker shows a real next goal.
	assert(Onboarding.ActiveStep(profile.Onboarding).Id == "step_pit")
	local guide = profile.Onboarding.Guide
	assert(guide and next(guide.Facts) == nil and guide.Enabled == nil)
	Migrations.Run(profile)
	assert(profile.Heroes.a.Rarity == 5 and profile.Onboarding.Guide == guide, "migration is idempotent")
end)

test("Guide: access follows a ready squad and Tower progress", function()
	local profile = {
		Heroes = { han = { Assignment = "SQUAD_SLOT_1", ComaUntilTimestamp = 10 } },
		Unlocks = {},
		HighestClearedFloor = 0,
		MaxFloorReached = 1,
	}
	assert(not Onboarding.HasReadySquad(profile, 9))
	Onboarding.UpdateAccess(profile, false)
	assert(profile.Unlocks.Squad and not profile.Unlocks.Tower)
	assert(Onboarding.HasReadySquad(profile, 10))
	Onboarding.UpdateAccess(profile, true)
	assert(profile.Unlocks.Tower and not profile.Unlocks.Forge)
	profile.HighestClearedFloor, profile.MaxFloorReached = 1, 2
	Onboarding.UpdateAccess(profile, true)
	assert(profile.Unlocks.Forge and profile.Unlocks.Facilities and profile.Unlocks.Pit and profile.Unlocks.FortressTree)
	assert(not profile.Unlocks.TowerFloor5)
	profile.MaxFloorReached = 5
	Onboarding.UpdateAccess(profile, true)
	assert(profile.Unlocks.TowerFloor5)
	Onboarding.UpdateAccess(profile, false)
	assert(profile.Unlocks.Tower and profile.Unlocks.TowerFloor5, "earned access persists during recovery")
end)

test("Guide: recovery, cargo, and affordable actions drive the next cue", function()
	local GuideLessons = require(nodes["ServerScriptService.Core.GuideLessons"])
	local state = Onboarding.NewState()
	local guide = Onboarding.EnsureGuide(state)
	local profile = {
		Onboarding = state, Unlocks = { Forge = true },
		Currencies = { Gold = 0, Gems = 0 }, Heroes = {}, Artifacts = {},
	}
	local context = { Floor = 0, Ready = false, Carrying = false, CanRaid = false, Now = 100, PitLesson = function() return nil end }
	assert(GuideLessons.Select(profile, context).Id == "Ready")
	context.Ready = true
	assert(GuideLessons.Select(profile, context).Id == "Visit")
	context.Floor = 1
	assert(GuideLessons.Select(profile, context).Id == "Clear")
	guide.Facts.Clear = true
	context.Carrying = true
	assert(GuideLessons.Select(profile, context).Id == "Bank")
	guide.Snoozed.Bank = 101
	assert(GuideLessons.Select(profile, context).Id == "Return")
	guide.Facts.Return = true
	context.Floor, context.Carrying = 0, false
	assert(GuideLessons.Select(profile, context) == nil, "do not recommend unaffordable transactions")
	context.CanRaid = true
	assert(GuideLessons.Select(profile, context).Id == "Raid")
	context.CanRaid = false
	assert(GuideLessons.Select(profile, context) == nil, "closed raid stops being recommended")
end)

test("Guide: with lesson facts, facilities and The Pit wait for the first forged weapon", function()
	local profile = { Heroes = {}, Unlocks = {}, HighestClearedFloor = 1, MaxFloorReached = 2 }
	local facts: { [string]: boolean } = {}
	Onboarding.UpdateAccess(profile, true, facts)
	assert(profile.Unlocks.Forge and not profile.Unlocks.Facilities and not profile.Unlocks.Pit and not profile.Unlocks.FortressTree)
	facts.Roll = true
	Onboarding.UpdateAccess(profile, true, facts)
	assert(profile.Unlocks.Facilities and profile.Unlocks.Pit and profile.Unlocks.FortressTree)
	-- Reaching Floor 3 opens everything even if a lesson was never finished.
	local stuck = { Heroes = {}, Unlocks = {}, HighestClearedFloor = 2, MaxFloorReached = 3 }
	Onboarding.UpdateAccess(stuck, true, {})
	assert(stuck.Unlocks.Facilities and stuck.Unlocks.Pit and stuck.Unlocks.FortressTree)
end)

test("Guide: the core chain plays in order, skips what is not possible yet and ends", function()
	local GuideLessons = require(nodes["ServerScriptService.Core.GuideLessons"])
	local GuideConfig = require(nodes["ReplicatedStorage.Shared.Config.GuideConfig"])
	local ArtifactCatalog = require(nodes["ReplicatedStorage.Shared.Config.ArtifactCatalog"])
	assert(#GuideConfig.Chain == 10 and GuideConfig.Chain[1] == "Summon" and GuideConfig.Chain[10] == "Synthesis")
	for index, id in GuideConfig.Chain do
		local lesson = GuideConfig[id]
		assert(lesson.Core and lesson.Index == index and lesson.Total == 10, id)
		assert(#lesson.Title <= 24 and #lesson.Description <= 36, id .. " copy stays short")
	end
	local state = Onboarding.NewState()
	local guide = Onboarding.EnsureGuide(state)
	local facts = guide.Facts
	local weapon = ArtifactCatalog.ArchetypeRestrictions.Vanguard[1]
	local profile: any = {
		Onboarding = state, Unlocks = {}, HighestClearedFloor = 0, MaxFloorReached = 1,
		Currencies = { Gold = 0, Gems = HeroCatalog.PermanentBanner.Cost1X },
		Heroes = {
			lead = { UUID = "lead", Archetype = "Vanguard", Assignment = "SQUAD_SLOT_1", Stars = 1, Level = 1 },
			spare = { UUID = "spare", Archetype = "Striker", Assignment = "BENCHED", Stars = 1, Level = 1 },
		},
		Artifacts = {},
		Facilities = { GuardPost = { Level = 1, AssignedHeroUUIDs = {} } },
		FortressTree = FortressTree.DefaultTree(),
	}
	local pit: string? = nil
	local context = { Floor = 0, Ready = true, Carrying = false, CanRaid = false, Now = 100, PitLesson = function() return pit end }
	local function nextId(): string?
		local lesson = GuideLessons.Select(profile, context)
		return lesson and lesson.Id
	end
	local function done(id: string)
		facts[id] = true
		Onboarding.UpdateAccess(profile, true, facts)
	end

	assert(nextId() == "Summon"); done("Summon")
	assert(nextId() == "Squad"); done("Squad")
	assert(nextId() == "Visit")
	context.Floor = 1
	assert(nextId() == "Clear")
	profile.HighestClearedFloor, profile.MaxFloorReached = 1, 2
	done("Clear")
	assert(nextId() == "Return"); done("Return")
	context.Floor = 0
	-- No Gold for a roll yet: the step is passed over rather than shown as a dead end.
	assert(nextId() == nil and not profile.Unlocks.Facilities)
	profile.Currencies.Gold = ArtifactCatalog.Banner.Cost1X
	assert(nextId() == "Roll")
	assert(GuideLessons.StarterWeaponType(profile) == weapon, "the first roll suits a squad hero")
	profile.Artifacts.blade = { UUID = "blade", Type = weapon, Rarity = 1, Star = 1, DisplayName = "Blade" }
	profile.Currencies.Gold = 0
	done("Roll")
	assert(profile.Unlocks.Facilities and profile.Unlocks.Pit)
	assert(nextId() == "Equip")
	profile.Heroes.lead.EquippedArtifactUUID, profile.Artifacts.blade.EquippedHeroUUID = "blade", "lead"
	done("Equip")
	assert(nextId() == "GuardPost")
	-- A core lesson cannot be put off.
	guide.Snoozed.GuardPost = context.Now + 900
	assert(nextId() == "GuardPost")
	profile.Heroes.spare.Assignment = "FACILITY_GUARD_POST"
	table.insert(profile.Facilities.GuardPost.AssignedHeroUUIDs, "spare")
	done("GuardPost")
	-- Nothing affordable in the tree and nobody to feed: a spare hero is the way forward.
	assert(nextId() == "Recruit")
	profile.Currencies.Gems = 0
	assert(nextId() == nil)
	pit = "Synthesis"
	assert(nextId() == "Synthesis"); done("Synthesis")
	pit = "Promotion"
	assert(nextId() == "Promotion", "promotion waits for a hero at its level cap")
	guide.Snoozed.Promotion = context.Now + 900
	assert(nextId() == nil, "conditional lessons can be put off")
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

test("Suggested floor power rises from biome to biome", function()
	local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
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
	assert(safe.Kind == "Gems" and safe.Amount == 10 * Shop.GemsPerSummon(pack.Grant.Banner) and Shop.GemsPerSummon("A_STARS_ARRIVAL") == 200, "restricted players get Gems")
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
