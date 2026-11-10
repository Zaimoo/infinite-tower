--!strict
-- ReplicatedStorage/Shared/Config/HeroCatalog.luau
-- Authoritative Hero Seed & Banner Configuration
-- Features:
--   1. Permanent Banner: "Call of the Rift" (rarity tiers 1-7, exactly 1 character per tier)
--   2. Limited Time Banner: "A Star's Arrival" (rarity tiers 1-7, exactly 1 character per tier)
--   3. Inherent hero rarity (Phase 4 §7): fixed per template, multiplies base stats only.
--      Every hero is summoned at 1★ (BaseStar); its rarity factor carries the power its tier used to get from stars.

export type HeroSeed = {
	HeroId: string,
	DisplayName: string,
	BannerOrigin: "STANDARD" | "WORLD_BOSS" | "LIMITED",
	DropWeight: number, -- Relative weight within tier
	BaseStar: number, -- summon star; 1 for every hero
	Rarity: number, -- Inherent rarity tier (1 Common .. 7 Mythical at launch); never changes
	Archetype: "Vanguard" | "Striker" | "Marksman" | "Miner" | "Healer" | "Scholar",
	BaseHP_1Star: number,
	BaseATK_1Star: number,
	NativeHP: number,
	NativeATK: number,
	AttackInterval: number,
	MovementSpeed: number?,
	AttackRange: number,
	BaseLabor_1Star: number,
	NativeLabor: number,
	PreferredFacility: string,
	Color: Color3,
}

local StatBalance = require(game:GetService("ReplicatedStorage").Shared.Config.StatBalance)

local HeroCatalog = {}

--============================================================================
-- BANNER CONFIGURATIONS
--============================================================================

HeroCatalog.PermanentBanner = {
	BannerId = "banner_call_of_the_rift",
	Title = "CALL OF THE RIFT",
	Subtitle = "7-STAR PERMANENT HERO BANNER",
	MaxStar = 7,
	MaxPity = 120,
	PityMinTier = 5, -- hard pity guarantees an Exalted or better hero (Ignis, Edis or Han)
	Cost1X = 100,
	Cost10X = 900,
	TenPullMinTier = 3, -- every 10-pull includes a Rare or better hero
	-- Retuned with the 100-gem relic economy: hours of play per copy match the old rates at the higher income.
	Rates = {
		[1] = 0.7514, -- 75.14% Common (Gide or Shurn)
		[2] = 0.1800, -- 18.0% Uncommon Aaron
		[3] = 0.0470, -- 4.7% Rare Catio
		[4] = 0.0165, -- 1.65% Superior
		[5] = 0.0033, -- 0.33% Exalted (Ignis or Diran)
		-- 0.15% Legendary Edis: the same Gems per copy as Solaris on A Star's Arrival (0.30% at twice the price).
		[6] = 0.0015,
		-- 0.03% Mythical Han: the same Gems per copy as Astrea on A Star's Arrival (0.06% at twice the price).
		[7] = 0.0003,
	},
	HeroesByStar = {
		[1] = "hero_gide",
		[2] = "hero_aaron",
		[3] = "hero_catio",
		[4] = "hero_catio",
		[5] = "hero_diran",
		[6] = "hero_edis",
		[7] = "hero_han",
	},
	HeroesPoolByStar = {
		[1] = { "hero_gide", "hero_shurn" },
		[5] = { "hero_ignis", "hero_diran" },
	},
}

HeroCatalog.LimitedBanner = {
	BannerId = "banner_a_stars_arrival",
	Title = "A STAR'S ARRIVAL",
	Subtitle = "7-STAR LIMITED RATE-UP EVENT",
	MaxStar = 7,
	MaxPity = 100,
	PityMinTier = 5, -- hard pity guarantees an Exalted or better hero (Archon, Valeria, Solaris or Astrea)
	Cost1X = 200,
	Cost10X = 1800,
	TenPullMinTier = 3, -- every 10-pull includes a Rare or better hero
	FeaturedHeroId = "hero_astrea",
	-- The 200-gem price does most of the offsetting; these rates are a light trim on top.
	Rates = {
		[1] = 0.6114, -- 61.14% Common Jenna
		[2] = 0.2400, -- 24.0% Uncommon Velkist
		[3] = 0.0950, -- 9.5% Rare Eolka
		[4] = 0.0380, -- 3.8% Superior Morrigan
		[5] = 0.0120, -- 1.2% Exalted (Archon or Valeria)
		[6] = 0.0030, -- 0.30% Legendary Solaris
		[7] = 0.0006, -- 0.06% Mythical Astrea (Featured)
	},
	HeroesByStar = {
		[1] = "hero_jenna",
		[2] = "hero_velkist",
		[3] = "hero_eolka",
		[4] = "hero_morrigan",
		[5] = "hero_archon",
		[6] = "hero_solaris",
		[7] = "hero_astrea",
	},
	HeroesPoolByStar = {
		[5] = { "hero_archon", "hero_valeria" },
	},
}

-- Legacy fallback drop rates
HeroCatalog.BannerDropRates = HeroCatalog.PermanentBanner.Rates

--============================================================================
-- HERO SEEDS
--============================================================================

HeroCatalog.Seeds = {
	-- ------------------------------------------------------------------------
	-- CALL OF THE RIFT (Permanent Banner: 1★ to 7★)
	-- ------------------------------------------------------------------------
	hero_gide = {
		HeroId = "hero_gide",
		DisplayName = "Gide",
		BannerOrigin = "STANDARD",
		DropWeight = 60.0,
		BaseStar = 1,
		Rarity = 1,
		Archetype = "Miner",
		BaseHP_1Star = 340,
		BaseATK_1Star = 36,
		NativeHP = 340,
		NativeATK = 36,
		AttackInterval = 1.05,
		AttackRange = 6,
		BaseLabor_1Star = 18.0,
		NativeLabor = 18.0,
		PreferredFacility = "FACILITY_MARKET",
		Color = Color3.fromRGB(168, 142, 98),
	},
	hero_shurn = {
		HeroId = "hero_shurn",
		DisplayName = "Shurn",
		BannerOrigin = "STANDARD",
		DropWeight = 60.0,
		BaseStar = 1,
		Rarity = 1,
		Archetype = "Scholar",
		BaseHP_1Star = 220,
		BaseATK_1Star = 46,
		NativeHP = 220,
		NativeATK = 46,
		AttackInterval = 1.00,
		AttackRange = 28,
		BaseLabor_1Star = 18.0,
		NativeLabor = 18.0,
		PreferredFacility = "FACILITY_TRAINING",
		Color = Color3.fromRGB(215, 175, 105),
	},
	hero_han = {
		HeroId = "hero_han",
		DisplayName = "Han",
		BannerOrigin = "STANDARD",
		DropWeight = 0.1,
		BaseStar = 1,
		-- Mythical since the Han rework. He used to be the Common starter: Hans summoned before then keep
		-- their saved Common rarity (StatFormulas reads the hero's own Rarity first). Base stats are unchanged.
		Rarity = 7,
		Archetype = "Striker",
		BaseHP_1Star = 300,
		BaseATK_1Star = 40,
		NativeHP = 661944,
		NativeATK = 88259,
		AttackInterval = 0.85,
		AttackRange = 6,
		BaseLabor_1Star = 14.0,
		NativeLabor = 83.6,
		PreferredFacility = "FACILITY_TRAINING",
		Color = Color3.fromRGB(70, 155, 255),
	},
	hero_aaron = {
		HeroId = "hero_aaron",
		DisplayName = "Aaron",
		BannerOrigin = "STANDARD",
		DropWeight = 25.0,
		BaseStar = 1,
		Rarity = 2,
		Archetype = "Vanguard",
		BaseHP_1Star = 450,
		BaseATK_1Star = 28,
		NativeHP = 743,
		NativeATK = 46,
		AttackInterval = 1.10,
		AttackRange = 7,
		BaseLabor_1Star = 16.0,
		NativeLabor = 21.6,
		PreferredFacility = "FACILITY_GUARD_POST",
		Color = Color3.fromRGB(255, 155, 60),
	},
	hero_catio = {
		HeroId = "hero_catio",
		DisplayName = "Catio",
		BannerOrigin = "STANDARD",
		DropWeight = 10.0,
		BaseStar = 1,
		Rarity = 3,
		Archetype = "Miner",
		BaseHP_1Star = 280,
		BaseATK_1Star = 24,
		NativeHP = 762,
		NativeATK = 65,
		AttackInterval = 1.05,
		AttackRange = 6,
		BaseLabor_1Star = 20.0,
		NativeLabor = 36.5,
		PreferredFacility = "FACILITY_MARKET",
		Color = Color3.fromRGB(255, 205, 75),
	},
	hero_diran = {
		HeroId = "hero_diran",
		DisplayName = "Diran",
		BannerOrigin = "STANDARD",
		DropWeight = 1.0,
		BaseStar = 1,
		Rarity = 5,
		Archetype = "Healer",
		BaseHP_1Star = 300,
		BaseATK_1Star = 22,
		NativeHP = 40356,
		NativeATK = 2959,
		AttackInterval = 1.20,
		AttackRange = 24,
		BaseLabor_1Star = 20.0,
		NativeLabor = 52.3,
		PreferredFacility = "FACILITY_GODS_BLESSING",
		Color = Color3.fromRGB(82, 188, 126),
	},
	hero_valeria = {
		HeroId = "hero_valeria",
		DisplayName = "Valeria",
		BannerOrigin = "LIMITED",
		DropWeight = 3.5,
		BaseStar = 1,
		Rarity = 5,
		Archetype = "Healer",
		BaseHP_1Star = 260,
		BaseATK_1Star = 18,
		NativeHP = 34975,
		NativeATK = 2421,
		AttackInterval = 1.25,
		AttackRange = 24,
		BaseLabor_1Star = 18.0,
		NativeLabor = 47.0,
		PreferredFacility = "FACILITY_GODS_BLESSING",
		Color = Color3.fromRGB(100, 232, 175),
	},
	hero_ignis = {
		HeroId = "hero_ignis",
		DisplayName = "Ignis",
		BannerOrigin = "STANDARD",
		DropWeight = 1.0,
		BaseStar = 1,
		Rarity = 5,
		Archetype = "Vanguard",
		BaseHP_1Star = 450,
		BaseATK_1Star = 26,
		NativeHP = 3335,
		NativeATK = 193,
		AttackInterval = 1.15,
		AttackRange = 8,
		BaseLabor_1Star = 16.0,
		NativeLabor = 53.1,
		PreferredFacility = "FACILITY_GUARD_POST",
		Color = Color3.fromRGB(255, 85, 40),
	},
	hero_edis = {
		HeroId = "hero_edis",
		DisplayName = "Edis Callen",
		BannerOrigin = "STANDARD",
		DropWeight = 0.5,
		BaseStar = 1,
		Rarity = 6,
		Archetype = "Striker",
		BaseHP_1Star = 320,
		BaseATK_1Star = 62,
		NativeHP = 174339,
		NativeATK = 33778,
		AttackInterval = 0.75,
		AttackRange = 6,
		BaseLabor_1Star = 16.0,
		NativeLabor = 63.2,
		PreferredFacility = "FACILITY_TRAINING",
		Color = Color3.fromRGB(214, 150, 82),
	},

	-- ------------------------------------------------------------------------
	-- A STAR'S ARRIVAL (Limited Time Banner: 1★ to 7★)
	-- ------------------------------------------------------------------------
	hero_jenna = {
		HeroId = "hero_jenna",
		DisplayName = "Jenna",
		BannerOrigin = "LIMITED",
		DropWeight = 50.0,
		BaseStar = 1,
		Rarity = 1,
		Archetype = "Marksman",
		BaseHP_1Star = 210,
		BaseATK_1Star = 34,
		NativeHP = 210,
		NativeATK = 34,
		AttackInterval = 0.80,
		AttackRange = 28,
		BaseLabor_1Star = 13.0,
		NativeLabor = 13.0,
		PreferredFacility = "FACILITY_GUARD_POST",
		Color = Color3.fromRGB(80, 200, 255),
	},
	hero_velkist = {
		HeroId = "hero_velkist",
		DisplayName = "Velkist",
		BannerOrigin = "LIMITED",
		DropWeight = 25.0,
		BaseStar = 1,
		Rarity = 2,
		Archetype = "Striker",
		BaseHP_1Star = 300,
		BaseATK_1Star = 44,
		NativeHP = 495,
		NativeATK = 73,
		AttackInterval = 0.75,
		AttackRange = 6,
		BaseLabor_1Star = 14.0,
		NativeLabor = 18.9,
		PreferredFacility = "FACILITY_TRAINING",
		Color = Color3.fromRGB(235, 55, 85),
	},
	hero_eolka = {
		HeroId = "hero_eolka",
		DisplayName = "Eolka",
		BannerOrigin = "LIMITED",
		DropWeight = 13.5,
		BaseStar = 1,
		Rarity = 3,
		Archetype = "Scholar",
		BaseHP_1Star = 230,
		BaseATK_1Star = 52,
		NativeHP = 626,
		NativeATK = 142,
		AttackInterval = 1.00,
		AttackRange = 30,
		BaseLabor_1Star = 22.0,
		NativeLabor = 40.1,
		PreferredFacility = "FACILITY_TRAINING",
		Color = Color3.fromRGB(220, 40, 24),
	},
	hero_morrigan = {
		HeroId = "hero_morrigan",
		DisplayName = "Morrigan",
		BannerOrigin = "LIMITED",
		DropWeight = 6.5,
		BaseStar = 1,
		Rarity = 4,
		Archetype = "Vanguard",
		BaseHP_1Star = 450,
		BaseATK_1Star = 24,
		NativeHP = 2021,
		NativeATK = 108,
		AttackInterval = 1.15,
		AttackRange = 7,
		BaseLabor_1Star = 16.0,
		NativeLabor = 39.4,
		PreferredFacility = "FACILITY_GUARD_POST",
		Color = Color3.fromRGB(160, 100, 240),
	},
	hero_archon = {
		HeroId = "hero_archon",
		DisplayName = "Sovereign Archon",
		BannerOrigin = "LIMITED",
		DropWeight = 3.5,
		BaseStar = 1,
		Rarity = 5,
		Archetype = "Striker",
		BaseHP_1Star = 350,
		BaseATK_1Star = 65,
		NativeHP = 2594,
		NativeATK = 482,
		AttackInterval = 0.80,
		AttackRange = 14,
		BaseLabor_1Star = 25.0,
		NativeLabor = 83.0,
		PreferredFacility = "ALL",
		Color = Color3.fromRGB(190, 85, 255),
	},
	hero_solaris = {
		HeroId = "hero_solaris",
		DisplayName = "Solaris",
		BannerOrigin = "LIMITED",
		DropWeight = 1.2,
		BaseStar = 1,
		Rarity = 6,
		Archetype = "Scholar",
		BaseHP_1Star = 240,
		BaseATK_1Star = 55,
		NativeHP = 2935,
		NativeATK = 673,
		AttackInterval = 0.95,
		AttackRange = 30,
		BaseLabor_1Star = 22.0,
		NativeLabor = 98.6,
		PreferredFacility = "FACILITY_TRAINING",
		Color = Color3.fromRGB(255, 215, 0),
	},
	hero_astrea = {
		HeroId = "hero_astrea",
		DisplayName = "Astrea",
		BannerOrigin = "LIMITED",
		DropWeight = 0.3,
		BaseStar = 1,
		Rarity = 7,
		Archetype = "Marksman",
		BaseHP_1Star = 230,
		BaseATK_1Star = 48,
		NativeHP = 4641,
		NativeATK = 969,
		AttackInterval = 0.70,
		AttackRange = 32,
		BaseLabor_1Star = 23.0,
		NativeLabor = 139.2,
		PreferredFacility = "ALL",
		Color = Color3.fromRGB(235, 220, 255),
	},
}

-- Hero rarity uses the weapon tier names (GDD §4.1). Tiers 8-16 are reserved for future heroes.
HeroCatalog.RarityNames = table.freeze({ "Common", "Uncommon", "Rare", "Superior", "Exalted", "Legendary", "Mythical" })

-- Derived compatibility fields; immutable one-star seeds remain authoritative.
-- Native stats are the stats at the summon star (1★), Lv. 1, quality 1.
for _, seed in pairs(HeroCatalog.Seeds) do
 local growth = StatBalance.HeroPromotionMultiplier^(seed.BaseStar-1) * StatBalance.HeroRarityCombat(seed.Rarity)
 seed.NativeHP = math.round(seed.BaseHP_1Star * growth)
 seed.NativeATK = math.round(seed.BaseATK_1Star * growth)
 seed.MovementSpeed = 20
end

function HeroCatalog.RarityOf(templateId: string?): number
	local seed = templateId and HeroCatalog.Seeds[templateId]
	return if seed then seed.Rarity else 1
end

function HeroCatalog.RarityName(tier: number?): string
	return HeroCatalog.RarityNames[math.clamp(math.floor(tier or 1), 1, #HeroCatalog.RarityNames)]
end

HeroCatalog.PoolByStar = {
	[1] = { "hero_gide", "hero_shurn", "hero_jenna" },
	[2] = { "hero_aaron", "hero_velkist" },
	[3] = { "hero_catio", "hero_eolka" },
	[4] = { "hero_morrigan" },
	[5] = { "hero_ignis", "hero_diran", "hero_archon", "hero_valeria" },
	[6] = { "hero_edis", "hero_solaris" },
	[7] = { "hero_han", "hero_astrea" },
}

return HeroCatalog
