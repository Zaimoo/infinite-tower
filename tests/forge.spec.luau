--!strict
-- tests/forge.spec.luau
-- Authoritative unit and regression tests for Blacksmith Forge System:
--   1. 84-Weapon Catalog (6 archetypes x 7 rarity tiers x 2 variants)
--   2. Gold Gacha Summon Banner & 120-pull Hard Pity (Exalted+)
--   3. God's Blessing luck integration across 7 tiers
--   4. Baseline 50 inventory limits for Heroes & Artifacts
--   5. Artifact selling valuation formula
--   6. Universal 1★ summoned baseline and star promotion
--   7. Combat stat snapshots and high-tier scaling

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local SummonLuck = require(ReplicatedStorage.Shared.Util.SummonLuck)
local Promotion = require(ReplicatedStorage.Shared.Util.WeaponPromotion)
local Stats = require(ReplicatedStorage.Shared.Util.StatFormulas)
local Heroes = require(ReplicatedStorage.Shared.Config.HeroCatalog)

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print("PASS " .. name)
	else
		print("FAIL " .. name .. ": " .. tostring(err))
		error(err)
	end
end

local function assertEqual(a: any, b: any, msg: string?)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "Assertion failed", tostring(b), tostring(a)))
	end
end

-- 1. 84-Weapon Matrix Catalog Verification
test("84 master catalog weapons exist across 6 archetypes and 7 rarity tiers", function()
	local countsByType: { [string]: number } = {}
	local countsByTier: { [number]: number } = {}
	local totalSeeds = 0

	for id, seed in pairs(ArtifactCatalog.Seeds) do
		totalSeeds += 1
		countsByType[seed.Type] = (countsByType[seed.Type] or 0) + 1
		local tier = seed.RarityTier or 1
		countsByTier[tier] = (countsByTier[tier] or 0) + 1

		assert(seed.DisplayName and #seed.DisplayName > 0, id .. " missing DisplayName")
		assert(seed.Description and #seed.Description > 0, id .. " missing Description")
		assert(seed.Variant == "Standard" or seed.Variant == "Enhanced", id .. " invalid variant")
		assert(seed.RarityTier >= 1 and seed.RarityTier <= 7, id .. " invalid RarityTier")
	end

	assertEqual(totalSeeds, 84, "Master catalog must have exactly 84 weapons")
	for _role, weaponType in pairs(ArtifactCatalog.ArchetypeWeaponType) do
		assertEqual(countsByType[weaponType], 14, string.format("Weapon type %s must have exactly 14 weapons (2 per tier)", weaponType))
	end
	for tier = 1, 7 do
		assertEqual(countsByTier[tier], 12, string.format("Rarity Tier %d must have exactly 12 weapons (6 archetypes x 2 variants)", tier))
	end
end)

test("Every (tier, archetype) pair has exactly 1 Standard and 1 Enhanced variant", function()
	for tier = 1, 7 do
		for _, weaponType in ipairs(ArtifactCatalog.ArchetypeTypes) do
			local std, enh = ArtifactCatalog.GetTierPair(tier, weaponType)
			assert(std ~= nil, string.format("Missing Standard variant for tier %d, type %s", tier, weaponType))
			assert(enh ~= nil, string.format("Missing Enhanced variant for tier %d, type %s", tier, weaponType))
			assertEqual(std.Variant, "Standard")
			assertEqual(enh.Variant, "Enhanced")
			assertEqual(std.StatMultiplier, 1.0, "Standard variant has 1.0x power multiplier")
			assertEqual(enh.StatMultiplier, 1.20, "Enhanced variant has 1.20x power multiplier")
			assert(enh.SpeedBonusAdditive > 0, "Enhanced variant has positive additive attack speed bonus")
		end
	end
end)

-- 2. Class Restrictions
test("Each archetype equips exactly one weapon type", function()
	local expected = {
		Vanguard = "SWORD_SHIELD",
		Striker = "DAGGERS",
		Marksman = "BOW",
		Miner = "AXE",
		Scholar = "STAFF",
		Healer = "TOME",
	}
	local weaponTypes = { "SWORD_SHIELD", "DAGGERS", "BOW", "AXE", "STAFF", "TOME" }
	for role, allowedType in pairs(expected) do
		for _, weaponType in ipairs(weaponTypes) do
			assertEqual(ArtifactCatalog.CanHeroEquip(role, weaponType :: any), weaponType == allowedType, role .. " / " .. weaponType)
		end
		assert(not ArtifactCatalog.CanHeroEquip(role, "RING" :: any), role .. " cannot equip RING")
		assert(not ArtifactCatalog.CanHeroEquip(role, "SHIELD" :: any), role .. " cannot equip SHIELD")
		assert(not ArtifactCatalog.CanHeroEquip(role, "SWORD" :: any), role .. " cannot equip legacy SWORD")
	end
end)

test("All 84 weapons appear in CatalogOrder", function()
	assertEqual(#ArtifactCatalog.CatalogOrder, 84, "CatalogOrder must contain all 84 items")
	local seen = {}
	for _, id in ipairs(ArtifactCatalog.CatalogOrder) do
		assert(ArtifactCatalog.Seeds[id] ~= nil, "CatalogOrder references unknown seed: " .. tostring(id))
		assert(not seen[id], "Duplicate id in CatalogOrder: " .. tostring(id))
		seen[id] = true
	end
end)

-- 3. Gold Gacha Summon Banner & 120-pull Hard Pity (Exalted+)
test("Artifact banner operates with Gold currency and 120-pull Exalted+ hard pity", function()
	local banner = ArtifactCatalog.Banner
	assert(banner ~= nil, "ArtifactCatalog.Banner missing")
	assertEqual(banner.Currency, "Gold", "Banner currency is Gold")
	assertEqual(banner.Cost1X, 5000, "1X summon costs 5,000 Gold")
	assertEqual(banner.Cost10X, 45000, "10X summon costs 45,000 Gold (10% discount)")
	assertEqual(banner.MaxPity, 120, "Hard pity is 120 summons")
	assertEqual(banner.PityRarityTier, 5, "Hard pity guarantees Exalted (Tier 5) or higher")

	-- Pity math calculations
	assertEqual(ArtifactCatalog.GetPityRemaining(0), 120, "0 pity means 120 remaining")
	assertEqual(ArtifactCatalog.GetPityRemaining(50), 70, "50 pulls gives 70 remaining")
	assertEqual(ArtifactCatalog.GetPityRemaining(119), 1, "119 pulls gives 1 remaining to guaranteed Exalted+")
	assertEqual(ArtifactCatalog.GetPityRemaining(120), 120, "120 pulls resets to 120 remaining")
end)

test("Banner base rarity rates sum to 1.0 and God's Blessing luck scales upper tiers", function()
	local rates = ArtifactCatalog.Banner.BaseRarityRates
	assertEqual(#rates, 7, "Base rates define 7 rarity tiers")
	local sum = 0
	for _, r in ipairs(rates) do sum += r end
	assert(math.abs(sum - 1.0) < 1e-6, "Base rarity rates must sum to 1.0")

	-- God's Blessing Luck check
	local boosted = SummonLuck.ApplyLuck(rates, 0.25)
	local boostedSum = 0
	for _, r in ipairs(boosted) do boostedSum += r end
	assert(math.abs(boostedSum - 1.0) < 1e-6, "Boosted rarity rates must sum to 1.0")
	assert(boosted[1] < rates[1], "Common tier absorbs the luck bonus")
	for tier = 2, 7 do
		assertEqual(boosted[tier], rates[tier] * 1.25, "Tiers 2-7 receive exact (1 + luck) scaling")
	end
end)

-- 4. Baseline 50 Inventory Capacity Limits
test("Baseline inventory capacity for Heroes and Artifacts is 50", function()
	assertEqual(Balance.MaxHeroInventory, 50, "MaxHeroInventory must be 50")
	assertEqual(Balance.MaxArtifactInventory, 50, "MaxArtifactInventory must be 50")
end)

test("The 120-pull pity roll only lands Exalted or higher and follows the luck-boosted rates", function()
	local banner = ArtifactCatalog.Banner
	local plain = SummonLuck.ApplyLuck(banner.BaseRarityRates, 0)
	local lucky = SummonLuck.ApplyLuck(banner.BaseRarityRates, 0.5)
	for i = 0, 999 do
		local tier = SummonLuck.RollAtLeast(lucky, banner.PityRarity, i / 1000)
		assert(tier >= banner.PityRarity and tier <= #lucky, "pity roll out of range: " .. tier)
	end
	-- Luck scales every upper tier equally, so the Exalted/Legendary/Mythical split is unchanged by luck.
	local function mythicShare(rates: { number }): number
		return rates[7] / (rates[5] + rates[6] + rates[7])
	end
	assert(math.abs(mythicShare(plain) - mythicShare(lucky)) < 1e-9, "luck should not skew the pity split")
	assertEqual(SummonLuck.RollAtLeast(plain, banner.PityRarity, 0), 7, "lowest roll is the rarest tier")
	assertEqual(SummonLuck.RollAtLeast(plain, banner.PityRarity, 0.999), 5, "highest roll is Exalted")
end)

test("Promotion donors are any weapon of the same rarity tier and star rank", function()
	local target = { Type = "BOW", Rarity = 5, Star = 2 }
	assert(Promotion.IsDonorFor(target, { Type = "BOW", Rarity = 5, Star = 2 }), "same tier, stars and type")
	assert(Promotion.IsDonorFor(target, { Type = "STAFF", Rarity = 5, Star = 2 }), "different weapon type allowed")
	assert(Promotion.IsDonorFor(target, { Type = "SWORD_SHIELD", Rarity = 5, Star = 2 }), "vanguard weapon for bow allowed")
	assert(Promotion.IsDonorFor(target, { Type = "DAGGERS", Rarity = 5, Star = 2 }), "striker weapon for bow allowed")
	assert(not Promotion.IsDonorFor(target, { Type = "BOW", Rarity = 4, Star = 2 }), "lower tier")
	assert(not Promotion.IsDonorFor(target, { Type = "BOW", Rarity = 5, Star = 1 }), "different star rank")
	assert(not Promotion.IsDonorFor(target, target), "itself")
	local std, enh = ArtifactCatalog.GetTierPair(5, "BOW")
	assert(std and enh)
	assert(Promotion.IsDonorFor({ Type = std.Type, Rarity = std.RarityTier, Star = 1 }, { Type = enh.Type, Rarity = enh.RarityTier, Star = 1 }), "the other variant")
end)

-- 5. Artifact Selling Valuation
test("Artifact sell price calculates accurately across all 7 tiers and star levels", function()
	assertEqual(ArtifactCatalog.CalculateSellPrice(1, 1), 100)
	assertEqual(ArtifactCatalog.CalculateSellPrice(1, 2), 150)
	assertEqual(ArtifactCatalog.CalculateSellPrice(1, 3), 200)
	assertEqual(ArtifactCatalog.CalculateSellPrice(2, 1), 250)
	assertEqual(ArtifactCatalog.CalculateSellPrice(3, 1), 600)
	assertEqual(ArtifactCatalog.CalculateSellPrice(3, 3), 1200)
	assertEqual(ArtifactCatalog.CalculateSellPrice(4, 1), 1500)
	assertEqual(ArtifactCatalog.CalculateSellPrice(5, 1), 5000)
	assertEqual(ArtifactCatalog.CalculateSellPrice(6, 1), 12000)
	assertEqual(ArtifactCatalog.CalculateSellPrice(7, 1), 40000)
	assertEqual(ArtifactCatalog.CalculateSellPrice(7, 7), 160000) -- 40,000 * (1 + 0.5 * 6)
end)

test("Selling a pull is worth under 15% of its cost even at maximum summon luck", function()
	local FacilityConfig = require(ReplicatedStorage.Shared.Config.FacilityConfig)
	local banner = ArtifactCatalog.Banner
	local perPullCost = math.min(banner.Cost1X, banner.Cost10X / 10)
	local rates = SummonLuck.ApplyLuck(banner.BaseRarityRates, FacilityConfig.Constants.MaxSummonLuck)
	local ev = 0
	for tier, rate in ipairs(rates) do
		ev += rate * ArtifactCatalog.CalculateSellPrice(tier, 1)
	end
	assert(ev < 0.15 * perPullCost, string.format("sell EV %.0f is not under 15%% of %d", ev, perPullCost))
end)

test("Every rarity tier and weapon type has both a Standard and an Enhanced weapon", function()
	for tier = 1, 7 do
		for _, weaponType in ipairs(ArtifactCatalog.ArchetypeTypes) do
			local std, enh = ArtifactCatalog.GetTierPair(tier, weaponType)
			assert(std and not std.IsHighStat, string.format("tier %d %s lacks a Standard weapon", tier, weaponType))
			assert(enh and enh.IsHighStat, string.format("tier %d %s lacks an Enhanced weapon", tier, weaponType))
		end
	end
end)

-- 6. Weapon Star Progression & Fodder Rules
test("Weapon star progression replaces enhancement and ignores legacy fields", function()
	local p, speed = ArtifactCatalog.CalculateEffectiveStats(7, 7, 0, "art_blade_of_the_rift")
	assertEqual(p, 112000)
	assertEqual(speed, 0.30)

	local legacy = ArtifactCatalog.CalculateEffectiveStats(7, 7, 999, "art_blade_of_the_rift")
	assertEqual(legacy, p)

	assertEqual(ArtifactCatalog.MaxStars, 7)
	assertEqual(ArtifactCatalog.GetFodderRequirement(6), 6)
	assertEqual(ArtifactCatalog.GetFodderRequirement(7), 0)
end)

test("Enhanced variants provide 20 percent higher power and additive speed", function()
	local stdPower, stdSpeed = ArtifactCatalog.CalculateEffectiveStats(1, 5, nil, "art_paladin_claymore")
	local enhPower, enhSpeed = ArtifactCatalog.CalculateEffectiveStats(1, 5, nil, "art_aegis_of_valor")
	assertEqual(enhPower, math.round(stdPower * 1.20))
	assert(enhSpeed > stdSpeed, "Enhanced weapon has higher attack speed")
end)

local function fixture()
	local p = {
		Currencies = { Gold = 300000, Gems = 1000 },
		Heroes = {},
		Artifacts = {
			target = { TemplateId = "art_astral_executioner", Type = "SWORD_SHIELD", Star = 6, Rarity = 7, Level = 999 },
		},
	}
	local types = { "SWORD_SHIELD", "DAGGERS", "BOW", "AXE", "STAFF", "TOME" }
	local donors = {}
	for i = 1, 6 do
		local id = "donor" .. i
		-- Alternate weapon types across archetypes: any type is valid as long as rarity and stars match.
		local templateId = if i % 2 == 0 then "art_genesis_worldbreaker" else "art_astral_executioner"
		p.Artifacts[id] = { TemplateId = templateId, Type = types[i] or "SWORD_SHIELD", Star = 6, Rarity = 7 }
		table.insert(donors, id)
	end
	return p, donors
end

test("Six-donor final promotion preserves rarity and commits exact resources once", function()
	local p, d = fixture()
	local target = p.Artifacts.target
	local ok, _, star = Promotion.Promote(p, "target", d)
	assert(ok)
	assertEqual(star, 7)
	assertEqual(target.Rarity, 7)
	assertEqual(target.Level, 999)
	assertEqual(p.Currencies.Gold, 50000)
	assertEqual(p.Currencies.Gems, 500)
	for _, id in ipairs(d) do assert(p.Artifacts[id] == nil) end
	assert(not Promotion.Promote(p, "target", d))
	assertEqual(p.Currencies.Gold, 50000)
end)

test("Every promotion step charges exactly once and retains identity, rarity and speed", function()
	for star = 1, 6 do
		local p, d = fixture()
		p.Artifacts.target.Star = star
		for _, donorId in ipairs(d) do
			p.Artifacts[donorId].Star = star
		end
		for i = 6, star + 1, -1 do d[i] = nil end
		local rule = Balance.WeaponPromotionCosts[star]
		local before = p.Artifacts.target
		local ok = Promotion.Promote(p, "target", d)
		assert(ok)
		assert(p.Artifacts.target == before)
		assertEqual(before.Star, star + 1)
		assertEqual(before.Rarity, 7)
		assertEqual(p.Currencies.Gold, 300000 - rule.Gold)
		assertEqual(p.Currencies.Gems, 1000 - rule.Gems)
		local _, speed = ArtifactCatalog.CalculateEffectiveStats(before.Star, before.Rarity)
		assertEqual(speed, 0.3)
		assert(not Promotion.Promote(p, "target", d))
		assertEqual(p.Currencies.Gold, 300000 - rule.Gold)
	end
end)

test("Malformed, stale, protected and insufficient promotions reject without mutation", function()
	for _, change in ipairs({
		function(_p, d) d[6] = d[1] end,
		function(_p, d) d[6] = "target" end,
		function(_p, d) d[6] = "foreign" end,
		function(_p, d) d[6] = nil end,
		function(_p, d) d[7] = "extra" end,
		function(_p, d) d.fake = "donor1" end,
		function(p, _d) p.Artifacts.donor1.Locked = true end,
		function(p, _d) p.Artifacts.donor1.EquippedHeroUUID = "hero" end,
		function(p, _d) p.Heroes.hero = { EquippedArtifactUUID = "donor1" } end,
		function(p, _d) p.Artifacts.donor1.Star = p.Artifacts.target.Star - 1 end,
		function(p, _d) p.Artifacts.donor1.Rarity = 6 end,
		function(p, _d) p.Currencies.Gold = 0 end,
		function(p, _d) p.Currencies.Gems = 0 end,
		function(p, _d) p.Artifacts.target.Star = 0 / 0 end,
	}) do
		local p, d = fixture()
		change(p, d)
		local gold, gems = p.Currencies.Gold, p.Currencies.Gems
		local ok = Promotion.Promote(p, "target", d)
		assert(not ok)
		assertEqual(p.Currencies.Gold, gold)
		assertEqual(p.Currencies.Gems, gems)
		assert(p.Artifacts.donor1 ~= nil)
		assertEqual(p.Artifacts.target.Rarity, 7)
	end
end)

test("Vanguard mythical artifact can be promoted using striker mythical artifact with same stars", function()
	local p = {
		Currencies = { Gold = 50000, Gems = 500 },
		Heroes = {},
		Artifacts = {
			target_vanguard = { TemplateId = "art_genesis_worldbreaker", Type = "SWORD_SHIELD", Star = 1, Rarity = 7 },
			donor_striker = { TemplateId = "art_void_reapers", Type = "DAGGERS", Star = 1, Rarity = 7 },
		},
	}
	local ok, msg, star = Promotion.Promote(p, "target_vanguard", { "donor_striker" })
	assert(ok, "Promotion with striker daggers for vanguard sword should succeed: " .. tostring(msg))
	assertEqual(star, 2)
	assert(p.Artifacts.donor_striker == nil, "Donor striker weapon consumed")
	assertEqual(p.Artifacts.target_vanguard.Star, 2)
end)

test("Promotion fails if donor has different star count", function()
	local p = {
		Currencies = { Gold = 50000, Gems = 500 },
		Heroes = {},
		Artifacts = {
			target_vanguard = { TemplateId = "art_genesis_worldbreaker", Type = "SWORD_SHIELD", Star = 2, Rarity = 7 },
			donor_striker = { TemplateId = "art_void_reapers", Type = "DAGGERS", Star = 1, Rarity = 7 },
		},
	}
	local ok, msg = Promotion.Promote(p, "target_vanguard", { "donor_striker" })
	assert(not ok, "Promotion should fail when star ranks do not match")
end)

test("All hero/weapon tiers are finite, monotonic and independent of legacy levels", function()
	for id, seed in pairs(Heroes.Seeds) do
		local hero = { TemplateId = id, Stars = 5, Level = 50, QualityScalar = 1, CurrentStamina = 100 }
		for r = 1, 16 do
			local last = 0
			for star = 1, 7 do
				local artifact = { TemplateId = "art_iron_broadsword", Rarity = r, Star = star, Level = 10000 }
				local v = Stats.GetCombatSnapshot(hero, artifact)
				assert(v.AttackDamage > last)
				last = v.AttackDamage
				assert(v.AttackSpeed <= 5)
				assertEqual(v.MovementSpeed, 20)
				local expectedPower = Balance.RarityPower[r] * Balance.WeaponStarMultipliers[star]
				local growth = 1.5 ^ 4 * 1.08 ^ 49 * Balance.HeroRarityCombat(seed.Rarity)
				assertEqual(v.AttackDamage, math.round(seed.BaseATK_1Star * 1 * growth * (1 + expectedPower / 40) * 1))
				assert(math.abs(v.AttackSpeed - (1 + Balance.RaritySpeed[r]) / seed.AttackInterval) < 1e-9)
				assertEqual(v.Health, math.round(seed.BaseHP_1Star * 1 * growth * 1))
			end
		end
	end
end)

test("Low-quality mixed squad exceeds one billion DPS at 75 percent uptime", function()
	local total = 0
	for _, id in ipairs({ "hero_han", "hero_jenna", "hero_aaron", "hero_velkist", "hero_eolka" }) do
		-- Han here is one summoned while he was Common: owned heroes keep their saved rarity.
		local h = { TemplateId = id, Rarity = if id == "hero_han" then 1 else nil, Stars = 7, Level = 70, QualityScalar = 0.9, CurrentStamina = 100 }
		local v = Stats.GetCombatSnapshot(h, { Star = 7, Rarity = 7 })
		total += v.DPS
	end
	assert(math.abs(total * 0.75 - 6952335172) < 2)
	assert(total * 0.75 > 1e9)
	assertEqual(Balance.GetFloorStats(50, "BOSS").MaxHP, 303887290571)
end)

test("Legacy trait and imprint fields cannot restore retired stat bonuses", function()
	local hero = { TemplateId = "hero_han", Stars = 5, Level = 50, QualityScalar = 1, CurrentStamina = 100 }
	local clean = Stats.GetCombatSnapshot(hero, { Star = 7, Rarity = 7 })
	hero.PassiveTrait = "Blood Pact"
	hero.TraitATKBonus = 100
	hero.TraitHPBonus = 100
	hero.InheritedImprints = { melee_memory = 3 }
	local legacy = Stats.GetCombatSnapshot(hero, { Star = 7, Rarity = 7, Level = 999 }, false, true)
	assertEqual(legacy.AttackDamage, clean.AttackDamage)
	assertEqual(legacy.Health, clean.Health)
	assertEqual(legacy.AttackSpeed, clean.AttackSpeed)
end)

test("Formatting supports damage and health above unsigned 32-bit range", function()
	assertEqual(Balance.Format(110844632813), "110.84B")
	assertEqual(Balance.Format(0 / 0), "0")
end)

print("All Forge spec tests passed successfully!")
