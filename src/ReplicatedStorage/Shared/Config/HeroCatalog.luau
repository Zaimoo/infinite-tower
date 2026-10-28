--!strict
-- ReplicatedStorage/Shared/Config/HeroCatalog.luau
-- Authoritative Hero Seed & Banner Configuration
-- Features:
--   1. Permanent Banner: "Call of the Rift" (rarity tiers 1-5, exactly 1 character per tier)
--   2. Limited Time Banner: "A Star's Arrival" (rarity tiers 1-7, exactly 1 character per tier)
--   3. Inherent hero rarity (Phase 4 §7): fixed per template, multiplies base stats only.
--      Heroes are still summoned at their template's BaseStar, which equals their tier at launch.

export type HeroSeed = {
	HeroId: string,
	DisplayName: string,
	BannerOrigin: "STANDARD" | "WORLD_BOSS" | "LIMITED",
	DropWeight: number, -- Relative weight within tier
	BaseStar: number,
	Rarity: number?, -- Inherent rarity tier (1 Common .. 7 Mythical at launch); derived from BaseStar below
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
	PassiveTraitName: string,
	TraitATKBonus: number,
	TraitHPBonus: number,
	TraitLaborBonus: number,
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
	Subtitle = "5-STAR PERMANENT HERO BANNER",
	MaxStar = 5,
	MaxPity = 80,
	TenPullMinTier = 3, -- every 10-pull includes a Rare or better hero
	Rates = {
		[1] = 0.700, -- 70.0% Common Han
		[2] = 0.200, -- 20.0% Uncommon Aaron
		[3] = 0.070, -- 7.0% Rare Catio
		[4] = 0.025, -- 2.5% Superior Valeria
		[5] = 0.005, -- 0.5% Exalted Ignis
	},
	HeroesByStar = {
		[1] = "hero_han",
		[2] = "hero_aaron",
		[3] = "hero_catio",
		[4] = "hero_valeria",
		[5] = "hero_ignis",
	},
}

HeroCatalog.LimitedBanner = {
	BannerId = "banner_a_stars_arrival",
	Title = "A STAR'S ARRIVAL",
	Subtitle = "7-STAR LIMITED RATE-UP EVENT",
	MaxStar = 7,
	MaxPity = 90,
	TenPullMinTier = 3, -- every 10-pull includes a Rare or better hero
	FeaturedHeroId = "hero_astrea",
	Rates = {
		[1] = 0.6000, -- 60.0% Common Jenna
		[2] = 0.2400, -- 24.0% Uncommon Velkist
		[3] = 0.1000, -- 10.0% Rare Eolka
		[4] = 0.0420, -- 4.2% Superior Morrigan
		[5] = 0.0140, -- 1.4% Exalted Archon
		[6] = 0.0033, -- 0.33% Legendary Solaris
		[7] = 0.0007, -- 0.07% Mythical Astrea (Featured)
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
}

-- Legacy fallback drop rates
HeroCatalog.BannerDropRates = HeroCatalog.PermanentBanner.Rates

--============================================================================
-- HERO SEEDS
--============================================================================

HeroCatalog.Seeds = {
	-- ------------------------------------------------------------------------
	-- CALL OF THE RIFT (Permanent Banner: 1★ to 5★)
	-- ------------------------------------------------------------------------
	hero_han = {
		HeroId = "hero_han",
		DisplayName = "Han",
		BannerOrigin = "STANDARD",
		DropWeight = 60.0,
		BaseStar = 1,
		Archetype = "Striker",
		BaseHP_1Star = 300,
		BaseATK_1Star = 40,
		NativeHP = 300,
		NativeATK = 40,
		AttackInterval = 0.85,
		AttackRange = 6,
		BaseLabor_1Star = 14.0,
		NativeLabor = 14.0,
		PreferredFacility = "FACILITY_TRAINING",
		PassiveTraitName = "Unyielding Adaptation (+10% ATK, -10% Stamina Drain)",
		TraitATKBonus = 0.10,
		TraitHPBonus = 0.0,
		TraitLaborBonus = 0.0,
		Color = Color3.fromRGB(70, 155, 255),
	},
	hero_aaron = {
		HeroId = "hero_aaron",
		DisplayName = "Aaron",
		BannerOrigin = "STANDARD",
		DropWeight = 25.0,
		BaseStar = 2,
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
		PassiveTraitName = "Phalanx Guard (+25% Max HP, -15% AoE Taken)",
		TraitATKBonus = 0.0,
		TraitHPBonus = 0.25,
		TraitLaborBonus = 0.0,
		Color = Color3.fromRGB(255, 155, 60),
	},
	hero_catio = {
		HeroId = "hero_catio",
		DisplayName = "Catio",
		BannerOrigin = "STANDARD",
		DropWeight = 10.0,
		BaseStar = 3,
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
		PassiveTraitName = "Quartermaster's Ledger (+25% Labor Output)",
		TraitATKBonus = 0.0,
		TraitHPBonus = 0.0,
		TraitLaborBonus = 0.25,
		Color = Color3.fromRGB(255, 205, 75),
	},
	hero_valeria = {
		HeroId = "hero_valeria",
		DisplayName = "Valeria",
		BannerOrigin = "STANDARD",
		DropWeight = 4.0,
		BaseStar = 4,
		Archetype = "Healer",
		BaseHP_1Star = 260,
		BaseATK_1Star = 18,
		NativeHP = 1168,
		NativeATK = 81,
		AttackInterval = 1.25,
		AttackRange = 24,
		BaseLabor_1Star = 18.0,
		NativeLabor = 44.3,
		PreferredFacility = "FACILITY_GODS_BLESSING",
		PassiveTraitName = "Sanctuary Aegis (+30% Healing, +20% Coma Recovery)",
		TraitATKBonus = 0.0,
		TraitHPBonus = 0.15,
		TraitLaborBonus = 0.30,
		Color = Color3.fromRGB(100, 232, 175),
	},
	hero_ignis = {
		HeroId = "hero_ignis",
		DisplayName = "Ignis",
		BannerOrigin = "STANDARD",
		DropWeight = 1.0,
		BaseStar = 5,
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
		PassiveTraitName = "Rift Warlord (+35% ATK, +20% DMG Reduction)",
		TraitATKBonus = 0.35,
		TraitHPBonus = 0.20,
		TraitLaborBonus = 0.0,
		Color = Color3.fromRGB(255, 85, 40),
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
		PassiveTraitName = "Windstep Precision (+15% ASPD, +5% Move Spd)",
		TraitATKBonus = 0.15,
		TraitHPBonus = 0.0,
		TraitLaborBonus = 0.0,
		Color = Color3.fromRGB(80, 200, 255),
	},
	hero_velkist = {
		HeroId = "hero_velkist",
		DisplayName = "Velkist",
		BannerOrigin = "LIMITED",
		DropWeight = 25.0,
		BaseStar = 2,
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
		PassiveTraitName = "Bloodthirst Frenzy (+20% ATK, +1s Overdrive)",
		TraitATKBonus = 0.20,
		TraitHPBonus = 0.0,
		TraitLaborBonus = 0.0,
		Color = Color3.fromRGB(235, 55, 85),
	},
	hero_eolka = {
		HeroId = "hero_eolka",
		DisplayName = "Eolka",
		BannerOrigin = "LIMITED",
		DropWeight = 13.5,
		BaseStar = 3,
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
		PassiveTraitName = "Crimson Pyromancy (+25% ATK, +30% Labor Output)",
		TraitATKBonus = 0.25,
		TraitHPBonus = 0.0,
		TraitLaborBonus = 0.30,
		Color = Color3.fromRGB(255, 80, 195),
	},
	hero_morrigan = {
		HeroId = "hero_morrigan",
		DisplayName = "Morrigan",
		BannerOrigin = "LIMITED",
		DropWeight = 6.5,
		BaseStar = 4,
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
		PassiveTraitName = "Abyssal Bulwark (+30% Max HP, +15% Reflect DMG)",
		TraitATKBonus = 0.0,
		TraitHPBonus = 0.30,
		TraitLaborBonus = 0.0,
		Color = Color3.fromRGB(160, 100, 240),
	},
	hero_archon = {
		HeroId = "hero_archon",
		DisplayName = "Sovereign Archon",
		BannerOrigin = "LIMITED",
		DropWeight = 3.5,
		BaseStar = 5,
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
		PassiveTraitName = "Dimensional Dominion (+30% Boss DMG, +25% All Labor)",
		TraitATKBonus = 0.30,
		TraitHPBonus = 0.15,
		TraitLaborBonus = 0.25,
		Color = Color3.fromRGB(190, 85, 255),
	},
	hero_solaris = {
		HeroId = "hero_solaris",
		DisplayName = "Solaris",
		BannerOrigin = "LIMITED",
		DropWeight = 1.2,
		BaseStar = 6,
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
		PassiveTraitName = "Supernova Flare (+40% ATK, +25% AoE Radius)",
		TraitATKBonus = 0.40,
		TraitHPBonus = 0.10,
		TraitLaborBonus = 0.20,
		Color = Color3.fromRGB(255, 215, 0),
	},
	hero_astrea = {
		HeroId = "hero_astrea",
		DisplayName = "Astrea",
		BannerOrigin = "LIMITED",
		DropWeight = 0.3,
		BaseStar = 7,
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
		PassiveTraitName = "Cosmic Zenith (+50% ATK, +30% ASPD, +35% Boss DMG)",
		TraitATKBonus = 0.50,
		TraitHPBonus = 0.20,
		TraitLaborBonus = 0.35,
		Color = Color3.fromRGB(235, 220, 255),
	},
}

-- Hero rarity uses the weapon tier names (GDD §4.1). Tiers 8-16 are reserved for future heroes.
HeroCatalog.RarityNames = table.freeze({ "Common", "Uncommon", "Rare", "Superior", "Exalted", "Legendary", "Mythical" })

-- Derived compatibility fields; immutable one-star seeds remain authoritative.
-- Launch heroes have one hero per tier, so the inherent rarity equals the summoned star.
for _, seed in pairs(HeroCatalog.Seeds) do
 seed.Rarity = seed.Rarity or seed.BaseStar
 local growth = 3^(seed.BaseStar-1) * StatBalance.HeroRarityCombatMultiplier^(seed.Rarity-1)
 seed.NativeHP = math.round(seed.BaseHP_1Star * growth)
 seed.NativeATK = math.round(seed.BaseATK_1Star * growth)
 seed.MovementSpeed = 20
end

function HeroCatalog.RarityOf(templateId: string?): number
	local seed = templateId and HeroCatalog.Seeds[templateId]
	return if seed then seed.Rarity or seed.BaseStar else 1
end

function HeroCatalog.RarityName(tier: number?): string
	return HeroCatalog.RarityNames[math.clamp(math.floor(tier or 1), 1, #HeroCatalog.RarityNames)]
end

HeroCatalog.PoolByStar = {
	[1] = { "hero_han", "hero_jenna" },
	[2] = { "hero_aaron", "hero_velkist" },
	[3] = { "hero_catio", "hero_eolka" },
	[4] = { "hero_valeria", "hero_morrigan" },
	[5] = { "hero_ignis", "hero_archon" },
	[6] = { "hero_solaris" },
	[7] = { "hero_astrea" },
}

return HeroCatalog
