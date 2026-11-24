--!strict
-- tests/forge-roll.spec.luau
-- Authoritative unit and regression tests for the Open Forge 3D Rolling System:
--   1. Uncapped RollLuck odds-ratio tail transform (monotonicity, bounds, normalization up to L=10,000)
--   2. RollLuck separation from God's Blessing SummonLuck & LuckPotion
--   3. FortressTree ForgePedestals branch (1 starter -> 6 max) and uncapped ForgeLuck repeatable node
--   4. ForgeRollRules state, full-refresh RollAll, string-keyed slot persistence, ValidatePurchase
--   5. Auto-Roll filter sanitization & pedestal matching
--   6. ShopConfig.Passes.ForgeAutoRoll & ProfileMigrations.ToV12

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local TreeConfig = require(ReplicatedStorage.Shared.Config.FortressTreeConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RelicConfig = require(ReplicatedStorage.Shared.Config.RelicConfig)
local TowerFloorConfig = require(ReplicatedStorage.Shared.Config.TowerFloorConfig)
local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)
local RollLuck = require(ReplicatedStorage.Shared.Util.RollLuck)
local SummonLuck = require(ReplicatedStorage.Shared.Util.SummonLuck)
local ForgeRollRules = require(ReplicatedStorage.Shared.Util.ForgeRollRules)
local Migrations = require(nodes["ServerScriptService.Core.ProfileMigrations"])

local passed = 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		print("FAIL " .. name .. ": " .. tostring(err))
		error(err)
	end
end

local function assertNear(a: number, b: number, eps: number, msg: string)
	if math.abs(a - b) > eps then
		error(string.format("%s: expected %.8f, got %.8f (eps %.8f)", msg, b, a, eps))
	end
end

-- 1. Uncapped RollLuck odds-ratio transform
test("RollLuck.ApplyLuck stays normalized and strictly positive from L=0 up to L=10,000", function()
	local base = ArtifactCatalog.RollRates
	local luckLevels = { 0, 0.25, 0.5, 1, 2, 5, 10, 50, 250, 1000, 10000 }
	local prevMythic = 0
	local prevCommon = 1
	for _, luck in ipairs(luckLevels) do
		local dist = RollLuck.ApplyLuck(base, luck)
		assert(#dist == 7, "must return 7 rarity probabilities")
		local sum = 0
		for tier = 1, 7 do
			assert(dist[tier] > 0 and dist[tier] < 1, string.format("tier %d out of (0,1) at L=%g: %g", tier, luck, dist[tier]))
			sum += dist[tier]
		end
		assertNear(sum, 1.0, 1e-9, string.format("sum == 1 at L=%g", luck))
		if luck == 0 then
			for tier = 1, 7 do
				assertNear(dist[tier], base[tier], 1e-9, "L=0 matches base tier " .. tier)
			end
		else
			assert(dist[7] > prevMythic, string.format("Mythical probability must strictly increase at L=%g", luck))
			assert(dist[1] < prevCommon, string.format("Common probability must strictly decrease at L=%g", luck))
		end
		prevMythic = dist[7]
		prevCommon = dist[1]
	end
end)

test("RollLuck.ForProfile is strictly independent of God's Blessing SummonLuck and Luck Potions", function()
	local profile: any = {
		FortressTree = FortressTree.DefaultTree(),
		Facilities = { GodsBlessing = { Level = 5, AssignedHeroUUIDs = { "h1" } } },
		Heroes = { h1 = { UUID = "h1", Archetype = "Healer", Level = 50, Stars = 7, Rarity = 7 } },
		ActiveBoosts = { Luck = { RemainingSeconds = 600 } },
	}
	assert(SummonLuck.ForProfile(profile) > 0.3, "God's Blessing + Luck Potion boosts hero SummonLuck")
	assert(RollLuck.ForProfile(profile) == 0, "Forge RollLuck ignores God's Blessing and Luck Potion")

	-- Unlock ForgeLuck foundation nodes + repeatable Eternal Stoking ranks
	profile.FortressTree.Nodes.rl_1 = true
	profile.FortressTree.Nodes.rl_2 = true
	profile.FortressTree.Nodes.rl_3 = true
	profile.FortressTree.Nodes.rl_4 = true
	assertNear(RollLuck.ForProfile(profile), 0.50, 1e-9, "rl_1..rl_4 grant +50% Roll Luck")

	profile.FortressTree.RollLuckRank = 20
	assertNear(RollLuck.ForProfile(profile), 1.50, 1e-9, "20 ranks of rl_endless add +100% uncapped Roll Luck")

	profile.FortressTree.RollLuckRank = 200
	assertNear(RollLuck.ForProfile(profile), 10.50, 1e-9, "200 ranks of rl_endless scale without cap")
end)

-- 2. FortressTree ForgePedestals (max 6) & Uncapped ForgeLuck
test("FortressTree ForgePedestals unlocks sequentially from 1 starter up to 6 max", function()
	local tree = FortressTree.DefaultTree()
	local open = { FortressTree = true, Forge = true }
	assert(FortressTree.ForgePedestals(tree) == 1, "starts with 1 starter pedestal")
	assert(not FortressTree.CanUnlock(tree, "fp_2", 1e9, 50, open), "fp_2 requires fp_1")
	assert(FortressTree.CanUnlock(tree, "fp_1", 1e9, 0, open), "fp_1 unlocks at Floor 0")

	local ids = { "fp_1", "fp_2", "fp_3", "fp_4", "fp_5" }
	for i, id in ipairs(ids) do
		assert(FortressTree.CanUnlock(tree, id, 1e9, 50, open), id .. " should be unlockable in order")
		tree.Nodes[id] = true
		assert(FortressTree.ForgePedestals(tree) == i + 1, "pedestal count matches unlocked nodes")
	end
	assert(FortressTree.ForgePedestals(tree) == 6, "max forge pedestals is 6")
	assert(not FortressTree.CanUnlock(tree, "fp_5", 1e9, 50, open), "fp_5 cannot be unlocked twice")
end)

test("FortressTree rl_endless is infinitely repeatable with exponential Gold scaling", function()
	local tree = FortressTree.DefaultTree()
	local open = { FortressTree = true, Forge = true }
	assert(not FortressTree.CanUnlock(tree, "rl_endless", 1e9, 50, open), "rl_endless requires rl_4")
	tree.Nodes.rl_1, tree.Nodes.rl_2, tree.Nodes.rl_3, tree.Nodes.rl_4 = true, true, true, true

	local prevCost = 0
	for rank = 0, 15 do
		tree.RollLuckRank = rank
		local cost = FortressTree.NodeCost(tree, "rl_endless")
		assert(cost > prevCost, string.format("rank %d cost %d must strictly exceed %d", rank, cost, prevCost))
		assert(not FortressTree.CanUnlock(tree, "rl_endless", cost - 1, 50, open), "insufficient Gold rejected at rank " .. rank)
		assert(FortressTree.CanUnlock(tree, "rl_endless", cost, 50, open), "exact Gold accepted at rank " .. rank)
		prevCost = cost
	end
end)

-- 3. Relic-Floor Scaled Pedestal Pricing Parity
test("Pedestal Gold prices scale directly from biome Cursed Urn Relic floor payouts", function()
	for tier = 1, 7 do
		local floorId = ArtifactCatalog.RarityTargetFloor[tier]
		local biome = assert(RelicConfig.GetBiomeForFloor(floorId), "biome exists for floor " .. floorId)
		local urnSpec = assert(RelicConfig.Items[biome.DropTable[2]], "tier-2 Urn relic exists for floor " .. floorId)
		local goldMult = TowerFloorConfig.RelicFloorMultipliers(floorId)
		local rawUrnGold = urnSpec.Payout.Gold * goldMult
		local stdCost = ArtifactCatalog.RarityStandardPedestalCost[tier]
		local enhCost = ArtifactCatalog.RarityEnhancedPedestalCost[tier]
		assert(math.abs(stdCost - rawUrnGold) / rawUrnGold < 0.02, string.format("tier %d stdCost %d tracks Floor %d Urn Gold %.0f", tier, stdCost, floorId, rawUrnGold))
		local ratio = enhCost / stdCost
		assert(ratio >= 1.28 and ratio <= 1.32, string.format("tier %d Enhanced/Standard ratio %.3f near 1.30x", tier, ratio))
	end
end)

-- 4. ForgeRollRules: full refresh, string-keyed slots, validation & single-slot purchase
test("ForgeRollRules.RollAll refreshes all unlocked pedestals using string keys and clears locked slots", function()
	local profile: any = {
		Currencies = { Gold = 1e9 },
		Artifacts = {},
		FortressTree = FortressTree.DefaultTree(),
	}
	profile.FortressTree.Nodes.fp_1 = true
	profile.FortressTree.Nodes.fp_2 = true -- 3 pedestals unlocked

	-- Pre-populate a stale slot 5 beyond unlocked count to verify cleanup
	local state = ForgeRollRules.EnsureState(profile)
	state.Slots["5"] = "art_rusty_shortsword"

	local s = 1337
	local function rng(): number
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
	local rolled = ForgeRollRules.RollAll(profile, rng, "SWORD_SHIELD")
	local count = 0
	for k, templateId in pairs(state.Slots) do
		assert(type(k) == "string", "slot keys must be strings for DataStore JSON safety")
		assert(ArtifactCatalog.Seeds[templateId] ~= nil, "rolled template must exist in ArtifactCatalog")
		count += 1
	end
	assert(count == 3, "exactly 3 unlocked pedestals populated")
	assert(state.Slots["1"] ~= nil and state.Slots["2"] ~= nil and state.Slots["3"] ~= nil, "string slots 1..3 populated")
	assert(rolled[1] == state.Slots["1"] and rolled[2] == state.Slots["2"] and rolled[3] == state.Slots["3"], "returned index table matches string slots")
	assert(state.Slots["5"] == nil, "locked slot 5 cleared")
	assert(ArtifactCatalog.Seeds[state.Slots["1"]].Type == "SWORD_SHIELD", "starter weapon type applied to slot 1 when player owns 0 artifacts")

	-- Simulate buying slot 2: leaves "1" and "3" intact without creating a sparse numeric array
	local ok, reason, seed, cost = ForgeRollRules.ValidatePurchase(profile, 2)
	assert(ok and seed ~= nil and cost ~= nil and reason == nil, "slot 2 purchase validates")
	state.Slots["2"] = nil
	assert(state.Slots["1"] ~= nil and state.Slots["2"] == nil and state.Slots["3"] ~= nil, "only bought pedestal clears")

	local okEmpty, errEmpty = ForgeRollRules.ValidatePurchase(profile, 2)
	assert(not okEmpty and errEmpty ~= nil, "re-buying empty pedestal rejected")

	local okLocked, errLocked = ForgeRollRules.ValidatePurchase(profile, 4)
	assert(not okLocked and errLocked ~= nil, "buying locked pedestal rejected")

	profile.Currencies.Gold = 0
	local okPoor, errPoor = ForgeRollRules.ValidatePurchase(profile, 1)
	assert(not okPoor and errPoor ~= nil, "buying without enough Gold rejected")
end)

test("Buying a pedestal leaves it empty until rerolled, while PopulateSlot fills only a newly unlocked pedestal", function()
	local profile: any = {
		Currencies = { Gold = 0 },
		Artifacts = { a1 = { UUID = "a1" } },
		FortressTree = FortressTree.DefaultTree(),
	}
	local s = 42
	local function rng(): number
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
	-- First-ever init populates starter pedestal 1
	assert(ForgeRollRules.EnsureUnlockedPopulated(profile, rng) == true, "brand-new profile populates starter pedestal once")
	local firstSlot = profile.ForgeRoll.Slots["1"]
	assert(firstSlot ~= nil and profile.ForgeRoll.Initialized == true)

	-- Simulating purchase: slot 1 is cleared and MUST NOT auto-replace on subsequent syncs!
	profile.ForgeRoll.Slots["1"] = nil
	assert(ForgeRollRules.EnsureUnlockedPopulated(profile, rng) == false, "bought pedestal does NOT auto-replace")
	assert(profile.ForgeRoll.Slots["1"] == nil, "slot 1 remains empty until player rerolls")

	-- Unlocking pedestal 2 via PopulateSlot fills ONLY slot 2 and leaves bought slot 1 empty
	profile.FortressTree.Nodes.fp_1 = true
	assert(ForgeRollRules.PopulateSlot(profile, 2, rng) == true, "newly unlocked pedestal 2 populated")
	assert(profile.ForgeRoll.Slots["1"] == nil, "bought pedestal 1 stays empty when unlocking slot 2")
	assert(profile.ForgeRoll.Slots["2"] ~= nil, "newly unlocked pedestal 2 now has an artifact")
	assert(ForgeRollRules.PopulateSlot(profile, 2, rng) == false, "PopulateSlot does not overwrite an occupied slot")
end)

-- 5. Auto-Roll filter sanitization & matching
test("ForgeRollRules Auto-Roll filter validates inputs and matches target rarity and weapon type", function()
	local minR, wType = ForgeRollRules.SanitizeFilter(6, "BOW")
	assert(minR == 6 and wType == "BOW")
	local badR, badW = ForgeRollRules.SanitizeFilter(99, "LASER")
	assert(badR == nil and badW == nil, "invalid filters rejected")

	local stdBow6, _ = ArtifactCatalog.GetTierPair(6, "BOW")
	local stdAxe6, _ = ArtifactCatalog.GetTierPair(6, "AXE")
	local stdBow3, _ = ArtifactCatalog.GetTierPair(3, "BOW")
	assert(stdBow6 and stdAxe6 and stdBow3)

	local anyState: ForgeRollRules.State = { Slots = {}, MinRarity = 6, WeaponType = "ANY" }
	local bowState: ForgeRollRules.State = { Slots = {}, MinRarity = 6, WeaponType = "BOW" }
	assert(ForgeRollRules.MatchesFilter(anyState, stdBow6.TemplateId), "Legendary matches Legendary+ ANY")
	assert(ForgeRollRules.MatchesFilter(bowState, stdBow6.TemplateId), "Legendary Bow matches Legendary+ BOW")
	assert(not ForgeRollRules.MatchesFilter(bowState, stdAxe6.TemplateId), "Legendary Axe does not match BOW filter")
	assert(not ForgeRollRules.MatchesFilter(bowState, stdBow3.TemplateId), "Rare Bow does not match Legendary+ filter")

	local matchProfile: any = {
		FortressTree = FortressTree.DefaultTree(),
		ForgeRoll = {
			Slots = {
				["1"] = stdBow3.TemplateId,
				["2"] = stdAxe6.TemplateId,
				["3"] = stdBow6.TemplateId,
			},
			MinRarity = 6,
			WeaponType = "BOW",
		},
	}
	matchProfile.FortressTree.Nodes.fp_1 = true
	matchProfile.FortressTree.Nodes.fp_2 = true
	local matches = ForgeRollRules.MatchingSlots(matchProfile)
	assert(#matches == 1 and matches[1] == 3, "MatchingSlots returns only slot 3")
end)

-- 6. ShopConfig GamePass & ProfileMigrations v12
test("ShopConfig exposes ForgeAutoRoll GamePass and ProfileMigrations upgrades to schema v12", function()
	local pass = ShopConfig.Passes and ShopConfig.Passes.ForgeAutoRoll
	assert(pass ~= nil, "ShopConfig.Passes.ForgeAutoRoll missing")
	assert(pass.Attribute == "OwnsForgeAutoRoll" and pass.RobuxPrice > 0, "ForgeAutoRoll GamePass metadata valid")

	assert(Migrations.CurrentSchema == 12, "CurrentSchema must be 12")
	local legacyProfile: any = {
		SchemaVersion = 11,
		Currencies = { Gold = 1000, Gems = 0 },
		Heroes = {},
		Artifacts = {},
		FortressTree = { Nodes = { root = true, gp_1 = true } },
	}
	Migrations.Run(legacyProfile)
	assert(legacyProfile.SchemaVersion == 12, "migrated to schema 12")
	assert(type(legacyProfile.ForgeRoll) == "table" and type(legacyProfile.ForgeRoll.Slots) == "table", "ForgeRoll initialized by ToV12")
	assert(legacyProfile.FortressTree.RollLuckRank == 0, "FortressTree.RollLuckRank initialized by ToV12")
end)

print(string.format("forge-roll: %d tests passed", passed))
