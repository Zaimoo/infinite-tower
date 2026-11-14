--!strict
-- ReplicatedStorage/Shared/Config/ArtifactCatalog.luau
-- Authoritative configuration for Equippable Artifacts (Weapons), 7 Star Tiers, 16 Rarity Multipliers, and Blacksmith Forge Roll System.

-- Each archetype wields exactly one weapon type (see ArchetypeRestrictions).
export type WeaponType = "BOW" | "SWORD_SHIELD" | "DAGGERS" | "AXE" | "TOME" | "STAFF"

export type RarityInfo = {
	Index: number,
	Name: string,
	Multiplier: number,
	Power: number?,
	SpeedBonus: number?,
	Color: Color3,
	HexColor: string,
}

export type StarBaseStats = {
	Star: number,
	BaseAttackPower: number,
	BaseAttackSpeed: number, -- As percentage, e.g. 0.05 = +5%
}

export type ArtifactSeed = {
	TemplateId: string,
	DisplayName: string,
	Type: WeaponType,
	RarityTier: number,
	IsHighStat: boolean,
	Variant: ("Standard" | "Enhanced" | "Gildforged")?,
	VisualElement: string?,
	StatMultiplier: number,
	SpeedBonusAdditive: number,
	ModelAssetId: string, -- Key in ReplicatedStorage.Assets.Weapons
	Description: string,
	BaseATK: number?,
	BaseDEF: number?,
	BaseHP: number?,
	BaseSPD: number?,
	BaseCritRate: number?,
	BaseEvasion: number?,
	BaseAttackSpeed: number?,
}

local B = require(script.Parent.StatBalance)
local ArtifactCatalog = {}


--============================================================================
-- 1. ARTIFACT BANNER CONFIGURATION (GOLD GACHA)
--============================================================================

export type ArtifactBannerConfig = {
	BannerId: string,
	Title: string,
	FeaturedHeroWatermark: string,
	Currency: string,
	Cost1X: number,
	Cost10X: number,
	MaxPity: number,
	PityRarity: number,
	PityRarityTier: number?,
	BaseRarityRates: { number },
}

local Banner: ArtifactBannerConfig = {
	BannerId = "banner_echoes_of_the_rift",
	Title = "ECHOES OF THE RIFT",
	FeaturedHeroWatermark = "★ 120-PULL EXALTED+ HARD PITY",
	Currency = "Gold",
	Cost1X = 5000,
	Cost10X = 45000,
	MaxPity = 120,
	PityRarity = 5, -- Exalted (Tier 5) or higher
	PityRarityTier = 5,
	BaseRarityRates = { 0.549, 0.250, 0.120, 0.055, 0.020, 0.005, 0.001 },
}
ArtifactCatalog.Banner = Banner

function ArtifactCatalog.GetPityRemaining(bannerPity: number?): number
	local p = bannerPity or 0
	return math.max(1, Banner.MaxPity - (p % Banner.MaxPity))
end

--============================================================================
-- 2. CLASS RESTRICTIONS (HERO ARCHETYPE -> PERMITTED WEAPON TYPES)
--============================================================================

local ArchetypeWeaponType: { [string]: WeaponType } = {
	Vanguard = "SWORD_SHIELD",
	Striker = "DAGGERS",
	Marksman = "BOW",
	Berserker = "AXE",
	Scholar = "STAFF",
	Healer = "TOME",
}
ArtifactCatalog.ArchetypeWeaponType = ArchetypeWeaponType

local ArchetypeOrder: { WeaponType } = {
	"SWORD_SHIELD",
	"DAGGERS",
	"BOW",
	"AXE",
	"STAFF",
	"TOME",
}
ArtifactCatalog.ArchetypeOrder = ArchetypeOrder
ArtifactCatalog.ArchetypeTypes = ArchetypeOrder

local ArchetypeRestrictions: { [string]: { WeaponType } } = {}
for archetype, weaponType in pairs(ArchetypeWeaponType) do
	ArchetypeRestrictions[archetype] = { weaponType }
end
ArtifactCatalog.ArchetypeRestrictions = ArchetypeRestrictions

function ArtifactCatalog.CanHeroEquip(heroArchetype: string, weaponType: WeaponType): boolean
	return ArchetypeWeaponType[heroArchetype] == weaponType
end

--============================================================================
-- 3. THE 7 STAR TIERS (BASE STATS)
--============================================================================

local StarTiers: { [number]: StarBaseStats } = {
	[1] = { Star = 1, BaseAttackPower = 15,  BaseAttackSpeed = 0.05 },
	[2] = { Star = 2, BaseAttackPower = 35,  BaseAttackSpeed = 0.10 },
	[3] = { Star = 3, BaseAttackPower = 75,  BaseAttackSpeed = 0.16 },
	[4] = { Star = 4, BaseAttackPower = 150, BaseAttackSpeed = 0.24 },
	[5] = { Star = 5, BaseAttackPower = 300, BaseAttackSpeed = 0.34 },
	[6] = { Star = 6, BaseAttackPower = 550, BaseAttackSpeed = 0.46 },
	[7] = { Star = 7, BaseAttackPower = 950, BaseAttackSpeed = 0.60 },
}
ArtifactCatalog.StarTiers = StarTiers

function ArtifactCatalog.GetStarBaseStats(star: number): (number, number)
	local clampedStar = math.clamp(math.floor(star or 1), 1, 7)
	local entry = StarTiers[clampedStar]
	return entry.BaseAttackPower, entry.BaseAttackSpeed
end

--============================================================================
-- 4. THE 16 RARITY TIERS (STAT MULTIPLIERS & PALETTE)
--============================================================================

local Rarities: { [number]: RarityInfo } = {
	[1]  = { Index = 1,  Name = "Common",       Multiplier = 1.00,  Color = Color3.fromHex("#B0B0B0"), HexColor = "#B0B0B0" },
	[2]  = { Index = 2,  Name = "Uncommon",     Multiplier = 1.15,  Color = Color3.fromHex("#4BB543"), HexColor = "#4BB543" },
	[3]  = { Index = 3,  Name = "Rare",         Multiplier = 1.35,  Color = Color3.fromHex("#2980B9"), HexColor = "#2980B9" },
	[4]  = { Index = 4,  Name = "Superior",     Multiplier = 1.60,  Color = Color3.fromHex("#8E44AD"), HexColor = "#8E44AD" },
	[5]  = { Index = 5,  Name = "Exalted",      Multiplier = 1.90,  Color = Color3.fromHex("#D35400"), HexColor = "#D35400" },
	[6]  = { Index = 6,  Name = "Legendary",    Multiplier = 2.30,  Color = Color3.fromHex("#F1C40F"), HexColor = "#F1C40F" },
	[7]  = { Index = 7,  Name = "Mythical",     Multiplier = 2.80,  Color = Color3.fromHex("#E74C3C"), HexColor = "#E74C3C" },
	[8]  = { Index = 8,  Name = "Transcendent", Multiplier = 3.40,  Color = Color3.fromHex("#1ABC9C"), HexColor = "#1ABC9C" },
	[9]  = { Index = 9,  Name = "Ascendant",    Multiplier = 4.10,  Color = Color3.fromHex("#E056FD"), HexColor = "#E056FD" },
	[10] = { Index = 10, Name = "Ethereal",     Multiplier = 5.00,  Color = Color3.fromHex("#686DE0"), HexColor = "#686DE0" },
	[11] = { Index = 11, Name = "Immortal",     Multiplier = 6.10,  Color = Color3.fromHex("#FF7979"), HexColor = "#FF7979" },
	[12] = { Index = 12, Name = "Divine",       Multiplier = 7.50,  Color = Color3.fromHex("#F9CA24"), HexColor = "#F9CA24" },
	[13] = { Index = 13, Name = "Celestial",    Multiplier = 9.20,  Color = Color3.fromHex("#00D2D3"), HexColor = "#00D2D3" },
	[14] = { Index = 14, Name = "Primordial",   Multiplier = 11.30, Color = Color3.fromHex("#FF3838"), HexColor = "#FF3838" },
	[15] = { Index = 15, Name = "Supreme",      Multiplier = 14.00, Color = Color3.fromHex("#BADC58"), HexColor = "#BADC58" },
	[16] = { Index = 16, Name = "Origin",       Multiplier = 18.00, Color = Color3.fromHex("#FF9FF3"), HexColor = "#FF9FF3" },
}
ArtifactCatalog.Rarities = Rarities

function ArtifactCatalog.GetRarityInfo(rarityIndex: number): RarityInfo
	local clamped = math.clamp(math.floor(rarityIndex or 1), 1, 16)
	return Rarities[clamped]
end

--============================================================================
-- 5. FODDER REQUIREMENT, STAT FORMULAS & LIQUIDATION VALUATION
--============================================================================

ArtifactCatalog.MaxStars = 7
ArtifactCatalog.StarMultipliers = B.WeaponStarMultipliers
ArtifactCatalog.StarPromotionCosts = B.WeaponPromotionCosts

for tier, info in pairs(Rarities) do
	info.Power = B.RarityPower[tier]
	info.SpeedBonus = B.RaritySpeed[tier]
end

local RarityBaseSellPrice: { [number]: number } = {
	[1] = 100,
	[2] = 250,
	[3] = 600,
	[4] = 1500,
	[5] = 5000,
	[6] = 12000,
	[7] = 40000,
}
ArtifactCatalog.RarityBaseSellPrice = RarityBaseSellPrice

function ArtifactCatalog.IsGildforged(seedOrId: any): boolean
	if seedOrId == "Gildforged" then
		return true
	end
	local seeds = ArtifactCatalog.Seeds
	local seed = if type(seedOrId) == "string"
		then (seeds and seeds[seedOrId])
		elseif type(seedOrId) == "table" then (
			if seedOrId.Variant == "Gildforged"
				then seedOrId
				elseif type(seedOrId.TemplateId) == "string" and seeds then seeds[seedOrId.TemplateId]
				else nil
		)
		else nil
	return seed ~= nil and (seed :: any).Variant == "Gildforged"
end

function ArtifactCatalog.CalculateSellPrice(rarity: number, star: number, seedOrId: any?): number
	if seedOrId ~= nil and ArtifactCatalog.IsGildforged(seedOrId) then
		return 0
	end
	local rawRarity = math.floor(rarity or 1)
	if rawRarity >= 8 then
		return 0
	end
	local r = math.clamp(rawRarity, 1, 7)
	local s = math.clamp(math.floor(star or 1), 1, 7)
	local basePrice = RarityBaseSellPrice[r] or 100
	return math.floor(basePrice * (1 + 0.5 * (s - 1)))
end

function ArtifactCatalog.GetStarPromotionCost(currentStar: number): any?
	return B.Integer(currentStar, 1, 6) and B.WeaponPromotionCosts[currentStar] or nil
end

function ArtifactCatalog.GetFodderRequirement(currentStar: number): number
	local rule = ArtifactCatalog.GetStarPromotionCost(currentStar)
	return rule and rule.Donors or 0
end

--============================================================================
-- 7. THE 84-WEAPON ROSTER (2 PER ARCHETYPE PER RARITY TIER)
--============================================================================
local Seeds: { [string]: ArtifactSeed } = {
	art_iron_broadsword = {
		TemplateId = "art_iron_broadsword",
		DisplayName = "Iron Broadsword",
		Type = "SWORD_SHIELD",
		RarityTier = 1,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_iron_broadsword",
		Description = "Utilitarian cast-grey iron blade with rough fuller hammer marks and wooden corner-banded heater shield.",
	},
	art_tempered_bastard_sword = {
		TemplateId = "art_tempered_bastard_sword",
		DisplayName = "Tempered Bastard Sword",
		Type = "SWORD_SHIELD",
		RarityTier = 1,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.010,
		ModelAssetId = "art_tempered_bastard_sword",
		Description = "Double-quenched carbon steel blade with fluted crossguard and reinforced steel buckler.",
	},
	art_rusty_daggers = {
		TemplateId = "art_rusty_daggers",
		DisplayName = "Rogue Daggers",
		Type = "DAGGERS",
		RarityTier = 1,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_rusty_daggers",
		Description = "Pair of simple drop-point trench daggers with leather cord wraps and blackened tips.",
	},
	art_serrated_skewers = {
		TemplateId = "art_serrated_skewers",
		DisplayName = "Serrated Skewers",
		Type = "DAGGERS",
		RarityTier = 1,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.010,
		ModelAssetId = "art_serrated_skewers",
		Description = "Deeply serrated butchering daggers with curved knuckle rings and brass pommel weights.",
	},
	art_hunters_shortbow = {
		TemplateId = "art_hunters_shortbow",
		DisplayName = "Hunter's Shortbow",
		Type = "BOW",
		RarityTier = 1,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_hunters_shortbow",
		Description = "Lightweight curved yew hunting bow with waxed hemp string and smooth ash grip.",
	},
	art_reinforced_longbow = {
		TemplateId = "art_reinforced_longbow",
		DisplayName = "Reinforced Yew Longbow",
		Type = "BOW",
		RarityTier = 1,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.010,
		ModelAssetId = "art_reinforced_longbow",
		Description = "Stouter yew stave backed with cured tendon cordage, firing heavy field arrows.",
	},
	art_miner_pickaxe = {
		TemplateId = "art_miner_pickaxe",
		DisplayName = "Raider's Greataxe",
		Type = "AXE",
		RarityTier = 1,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_miner_pickaxe",
		Description = "Two-handed bearded war axe on a long ash haft, with a hammer poll and leather grip wraps.",
	},
	art_heavy_hewing_axe = {
		TemplateId = "art_heavy_hewing_axe",
		DisplayName = "Heavy Hewing Axe",
		Type = "AXE",
		RarityTier = 1,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.010,
		ModelAssetId = "art_heavy_hewing_axe",
		Description = "Broad-faced two-handed hewing axe with iron langets and a counter-weighted poll.",
	},
	art_apprentice_cane = {
		TemplateId = "art_apprentice_cane",
		DisplayName = "Apprentice Wand-Staff",
		Type = "STAFF",
		RarityTier = 1,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_apprentice_cane",
		Description = "Slender birch rod with polished copper socket holding cloudy river quartz focus.",
	},
	art_scholars_spire = {
		TemplateId = "art_scholars_spire",
		DisplayName = "Scholar's Spire",
		Type = "STAFF",
		RarityTier = 1,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.010,
		ModelAssetId = "art_scholars_spire",
		Description = "Carved rowan staff banded with brass astrological markings and faceted amber focus.",
	},
	art_novice_tome = {
		TemplateId = "art_novice_tome",
		DisplayName = "Novice Prayerbook",
		Type = "TOME",
		RarityTier = 1,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_novice_tome",
		Description = "Pocket calfskin booklet inscribed with foundational cleansing scriptures and linen clasp.",
	},
	art_acolytes_litany = {
		TemplateId = "art_acolytes_litany",
		DisplayName = "Acolyte's Litany",
		Type = "TOME",
		RarityTier = 1,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.010,
		ModelAssetId = "art_acolytes_litany",
		Description = "Embossed pigskin codex with stamped brass corner fittings and soothing verse marginalia.",
	},
	art_runic_longsword = {
		TemplateId = "art_runic_longsword",
		DisplayName = "Runic Longsword",
		Type = "SWORD_SHIELD",
		RarityTier = 2,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_runic_longsword",
		Description = "Cobalt-treated steel knightly blade etched with faint emerald rune grooves and matching runic pavise.",
	},
	art_knightly_estoc = {
		TemplateId = "art_knightly_estoc",
		DisplayName = "Knightly Estoc",
		Type = "SWORD_SHIELD",
		RarityTier = 2,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.015,
		ModelAssetId = "art_knightly_estoc",
		Description = "Needle-pointed triangular thrusting sword with full basket hilt and convex teardrop kite shield.",
	},
	art_viper_kris = {
		TemplateId = "art_viper_kris",
		DisplayName = "Viper Kris",
		Type = "DAGGERS",
		RarityTier = 2,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_viper_kris",
		Description = "Flamboyant serpentine wavy-bladed daggers tipped with emerald venom gloss and snake-eye brass hilts.",
	},
	art_silent_dirks = {
		TemplateId = "art_silent_dirks",
		DisplayName = "Silent Dirk Pair",
		Type = "DAGGERS",
		RarityTier = 2,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.015,
		ModelAssetId = "art_silent_dirks",
		Description = "Needle-point stiletto dirks with non-reflective blued steel blades and lead-dampened guards.",
	},
	art_recurve_composite = {
		TemplateId = "art_recurve_composite",
		DisplayName = "Wind-Scout Recurve",
		Type = "BOW",
		RarityTier = 2,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_recurve_composite",
		Description = "Slender composite recurve layered with pale ashwood, horn tips, and falcon feather accents.",
	},
	art_gale_force_composite = {
		TemplateId = "art_gale_force_composite",
		DisplayName = "Gale-Force Composite",
		Type = "BOW",
		RarityTier = 2,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.015,
		ModelAssetId = "art_gale_force_composite",
		Description = "Deeply reflexed composite bow bound in emerald silk sinew with carved ivory riser tips.",
	},
	art_canyon_splitter = {
		TemplateId = "art_canyon_splitter",
		DisplayName = "Canyon Splitter",
		Type = "AXE",
		RarityTier = 2,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_canyon_splitter",
		Description = "Long-hafted bearded greataxe with raw amethyst geode chips bedded along the spine.",
	},
	art_quakestone_greataxe = {
		TemplateId = "art_quakestone_greataxe",
		DisplayName = "Quakestone Greataxe",
		Type = "AXE",
		RarityTier = 2,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.015,
		ModelAssetId = "art_quakestone_greataxe",
		Description = "Broad crescent greataxe of granite-tempered steel on a hexagonal brass shaft.",
	},
	art_ruby_staff = {
		TemplateId = "art_ruby_staff",
		DisplayName = "Ruby Channeling Staff",
		Type = "STAFF",
		RarityTier = 2,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_ruby_staff",
		Description = "Polished hickory staff holding an uncut igneous crystal head that amplifies casting cadence.",
	},
	art_pyromancers_torch_rod = {
		TemplateId = "art_pyromancers_torch_rod",
		DisplayName = "Pyromancer's Torch-Rod",
		Type = "STAFF",
		RarityTier = 2,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.015,
		ModelAssetId = "art_pyromancers_torch_rod",
		Description = "Dark iron rod terminating in an open-caged brazier casting continual fiery ember wisps.",
	},
	art_cleric_scripture = {
		TemplateId = "art_cleric_scripture",
		DisplayName = "Cleric Scripture",
		Type = "TOME",
		RarityTier = 2,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_cleric_scripture",
		Description = "White calfskin volume with silver-embossed holy wards and trailing azure silk bookmark ribbons.",
	},
	art_mendicants_psalter = {
		TemplateId = "art_mendicants_psalter",
		DisplayName = "Mendicant's Psalter",
		Type = "TOME",
		RarityTier = 2,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.015,
		ModelAssetId = "art_mendicants_psalter",
		Description = "Gold-leafed prayerbook with illuminated margins depicting dawn light and soothing aura petals.",
	},
	art_paladin_spatha = {
		TemplateId = "art_paladin_spatha",
		DisplayName = "Paladin Spatha",
		Type = "SWORD_SHIELD",
		RarityTier = 3,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_paladin_spatha",
		Description = "Noble chivalric broadsword with winged crossguard and radiant sun-crested heater shield.",
	},
	art_vanguard_warden_bastion = {
		TemplateId = "art_vanguard_warden_bastion",
		DisplayName = "Vanguard Warden Bastion",
		Type = "SWORD_SHIELD",
		RarityTier = 3,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_vanguard_warden_bastion",
		Description = "Heavy tower-blade with full-length blood channel and massive scalloped fortress shield.",
	},
	art_shadow_fangs = {
		TemplateId = "art_shadow_fangs",
		DisplayName = "Shadow Fangs",
		Type = "DAGGERS",
		RarityTier = 3,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_shadow_fangs",
		Description = "Twin obsidian stilettos trailing purple-black abyssal smoke, set in skeletal dragon-rib hilts.",
	},
	art_phantom_stiletto = {
		TemplateId = "art_phantom_stiletto",
		DisplayName = "Phantom Stiletto",
		Type = "DAGGERS",
		RarityTier = 3,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_phantom_stiletto",
		Description = "Translucent spirit-glass blades that blur into ethereal silhouettes during rapid thrusts.",
	},
	art_stormstrider_longbow = {
		TemplateId = "art_stormstrider_longbow",
		DisplayName = "Stormstrider Longbow",
		Type = "BOW",
		RarityTier = 3,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_stormstrider_longbow",
		Description = "Tall elven recurve inlaid with storm-silver alloy and eagle-wing riser accents.",
	},
	art_thunderhead_recurve = {
		TemplateId = "art_thunderhead_recurve",
		DisplayName = "Thunderhead Recurve",
		Type = "BOW",
		RarityTier = 3,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_thunderhead_recurve",
		Description = "Taut recurve wrapped in coiled copper lightning wires that discharge spark showers on draw.",
	},
	art_battleaxe_cleaver = {
		TemplateId = "art_battleaxe_cleaver",
		DisplayName = "Warforged Battleaxe",
		Type = "AXE",
		RarityTier = 3,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_battleaxe_cleaver",
		Description = "Double-bitted gunmetal greataxe with a spear finial, bronze collar and rune-lit cheeks.",
	},
	art_iron_juggernaut_cleaver = {
		TemplateId = "art_iron_juggernaut_cleaver",
		DisplayName = "Iron-Juggernaut Cleaver",
		Type = "AXE",
		RarityTier = 3,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_iron_juggernaut_cleaver",
		Description = "Slab-iron executioner greataxe with boiler-plate rivets, furnace slots and a counterweight hammer.",
	},
	art_frostweaver_scepter = {
		TemplateId = "art_frostweaver_scepter",
		DisplayName = "Frostweaver Scepter",
		Type = "STAFF",
		RarityTier = 3,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_frostweaver_scepter",
		Description = "Pale driftwood staff crowned with an intricate snowflake crystal radiating drifting frost mist.",
	},
	art_glacial_monolith = {
		TemplateId = "art_glacial_monolith",
		DisplayName = "Glacial Monolith",
		Type = "STAFF",
		RarityTier = 3,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_glacial_monolith",
		Description = "Translucent blue glacial ice rod suspended with floating frost-rime shards orbiting the crown.",
	},
	art_hermetic_grimoire = {
		TemplateId = "art_hermetic_grimoire",
		DisplayName = "Hermetic Grimoire",
		Type = "TOME",
		RarityTier = 3,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_hermetic_grimoire",
		Description = "Aged midnight-blue velvet book bound in wrought-iron brackets with a glowing alchemy circle.",
	},
	art_restorative_codex = {
		TemplateId = "art_restorative_codex",
		DisplayName = "Restorative Codex",
		Type = "TOME",
		RarityTier = 3,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_restorative_codex",
		Description = "Embossed silver-leaf volume that floats open, turning pages automatically upon mana contact.",
	},
	art_crystal_claymore = {
		TemplateId = "art_crystal_claymore",
		DisplayName = "Crystal Claymore",
		Type = "SWORD_SHIELD",
		RarityTier = 4,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_crystal_claymore",
		Description = "Translucent amethyst-bladed greatsword paired with an interlocking prismatic crystal barrier.",
	},
	art_resonant_bulwark = {
		TemplateId = "art_resonant_bulwark",
		DisplayName = "Resonant Bulwark",
		Type = "SWORD_SHIELD",
		RarityTier = 4,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_resonant_bulwark",
		Description = "Vibrating sonic steel broadsword with an acoustic hexagonal aegis that deflects kinetic blows.",
	},
	art_phantom_edge = {
		TemplateId = "art_phantom_edge",
		DisplayName = "Phantom Edge",
		Type = "DAGGERS",
		RarityTier = 4,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_phantom_edge",
		Description = "Semitransparent spirit glass daggers with ornate filigree crossguards and phase-strike luminescence.",
	},
	art_nightstalker_katar = {
		TemplateId = "art_nightstalker_katar",
		DisplayName = "Nightstalker Katar",
		Type = "DAGGERS",
		RarityTier = 4,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_nightstalker_katar",
		Description = "Punching katars forged of black meteoric iron with dual glowing violet plasma edges.",
	},
	art_crystal_greatbow = {
		TemplateId = "art_crystal_greatbow",
		DisplayName = "Crystal Greatbow",
		Type = "BOW",
		RarityTier = 4,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_crystal_greatbow",
		Description = "Towering prismatic mana-quartz bow with condensed cerulean mana string that hums melodically.",
	},
	art_prismatic_arbalest = {
		TemplateId = "art_prismatic_arbalest",
		DisplayName = "Prismatic Arbalest",
		Type = "BOW",
		RarityTier = 4,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_prismatic_arbalest",
		Description = "Intricate crystal-limbed mechanical greatbow with floating mana focus sights.",
	},
	art_magma_behemoth = {
		TemplateId = "art_magma_behemoth",
		DisplayName = "Magma Cleaver",
		Type = "AXE",
		RarityTier = 4,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_magma_behemoth",
		Description = "Jagged black basalt greataxe fractured with molten lava veins, backed by an obsidian counter-spike.",
	},
	art_obsidian_hell_splitter = {
		TemplateId = "art_obsidian_hell_splitter",
		DisplayName = "Obsidian Hell-Splitter",
		Type = "AXE",
		RarityTier = 4,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_obsidian_hell_splitter",
		Description = "Jagged volcanic glass double greataxe, ember-veined, with blood-red searing edges.",
	},
	art_archmage_rod = {
		TemplateId = "art_archmage_rod",
		DisplayName = "Archmage Caduceus",
		Type = "STAFF",
		RarityTier = 4,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_archmage_rod",
		Description = "Petrified ebony wood staff with entwined brass serpents suspending a hovering multi-faceted arcane prism.",
	},
	art_chronomancers_spindle = {
		TemplateId = "art_chronomancers_spindle",
		DisplayName = "Chronomancer's Spindle",
		Type = "STAFF",
		RarityTier = 4,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_chronomancers_spindle",
		Description = "Ornate brass clockwork staff with spinning interlocking astrolabe gears around a quartz core.",
	},
	art_valeria_sanctuary = {
		TemplateId = "art_valeria_sanctuary",
		DisplayName = "Sanctuary Gospel",
		Type = "TOME",
		RarityTier = 4,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_valeria_sanctuary",
		Description = "Valeria's signature grimoire style: Gold-leaf spine with emerald centerpiece emitting restorative motes.",
	},
	art_seraphs_testament = {
		TemplateId = "art_seraphs_testament",
		DisplayName = "Seraph's Testament",
		Type = "TOME",
		RarityTier = 4,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_seraphs_testament",
		Description = "Gilded cathedral tome whose pages radiate warm golden feathered halos when healing spells are cast.",
	},
	art_paladin_claymore = {
		TemplateId = "art_paladin_claymore",
		DisplayName = "Holy Claymore",
		Type = "SWORD_SHIELD",
		RarityTier = 5,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_paladin_claymore",
		Description = "Consecrated white-silver executioner sword with angelic wing quillons and radiant sunburst kite shield.",
	},
	art_aegis_of_valor = {
		TemplateId = "art_aegis_of_valor",
		DisplayName = "Aegis of Valor",
		Type = "SWORD_SHIELD",
		RarityTier = 5,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_aegis_of_valor",
		Description = "Gilded royal arming sword paired with an incandescent solar shield projecting humming barrier domes.",
	},
	art_bloodthirst_twinblades = {
		TemplateId = "art_bloodthirst_twinblades",
		DisplayName = "Bloodthirst Twinblades",
		Type = "DAGGERS",
		RarityTier = 5,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_bloodthirst_twinblades",
		Description = "Jagged crimson Damascus demonic falchions with arterial filigree dripping phantom blood embers.",
	},
	art_crimson_carnage = {
		TemplateId = "art_crimson_carnage",
		DisplayName = "Crimson Carnage",
		Type = "DAGGERS",
		RarityTier = 5,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_crimson_carnage",
		Description = "Asymmetrical curved demonic scythe-daggers forged of living bone that thrum with predatory frenzy.",
	},
	art_phoenix_flatbow = {
		TemplateId = "art_phoenix_flatbow",
		DisplayName = "Phoenix Greatbow",
		Type = "BOW",
		RarityTier = 5,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_phoenix_flatbow",
		Description = "Swept crimson-gold limbs sculpted like flaming phoenix wings emitting rippling heat shimmers.",
	},
	art_solar_flare_recurve = {
		TemplateId = "art_solar_flare_recurve",
		DisplayName = "Solar Flare Recurve",
		Type = "BOW",
		RarityTier = 5,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_solar_flare_recurve",
		Description = "Blinding incandescent bow with floating corona rings that materializes searing sunlight javelins.",
	},
	art_titan_earthshaker = {
		TemplateId = "art_titan_earthshaker",
		DisplayName = "Titan Earthshaker",
		Type = "AXE",
		RarityTier = 5,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_titan_earthshaker",
		Description = "Monumental double greataxe on a marble haft, its golden crescents ringed with seismic runes.",
	},
	art_mountain_breaker = {
		TemplateId = "art_mountain_breaker",
		DisplayName = "Mountain Breaker",
		Type = "AXE",
		RarityTier = 5,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_mountain_breaker",
		Description = "Monolithic hewn-stone greataxe with a golden edge, a rune column and a stone hammer back.",
	},
	art_infernal_pillar = {
		TemplateId = "art_infernal_pillar",
		DisplayName = "Pillar of Muspelheim",
		Type = "STAFF",
		RarityTier = 5,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_infernal_pillar",
		Description = "Dark iron battle-staff with open caged brazier containing an eternal roiling miniature flame star.",
	},
	art_void_channeler = {
		TemplateId = "art_void_channeler",
		DisplayName = "Void Channeler",
		Type = "STAFF",
		RarityTier = 5,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_void_channeler",
		Description = "Abyssal black-stone staff crowned with a miniature gravitational singularity dragging light inward.",
	},
	art_necronomicon_pages = {
		TemplateId = "art_necronomicon_pages",
		DisplayName = "Codex of the Deep",
		Type = "TOME",
		RarityTier = 5,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_necronomicon_pages",
		Description = "Aged forbidden leather tome with an iridescent demonic eye on the cover that blinks rhythmically.",
	},
	art_lifebinders_chronicle = {
		TemplateId = "art_lifebinders_chronicle",
		DisplayName = "Lifebinder's Chronicle",
		Type = "TOME",
		RarityTier = 5,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.020,
		ModelAssetId = "art_lifebinders_chronicle",
		Description = "Living wooden-covered grimoire entwined with blooming sacred vines that shed luminescent pollen.",
	},
	art_blade_of_the_rift = {
		TemplateId = "art_blade_of_the_rift",
		DisplayName = "Blade of the Rift",
		Type = "SWORD_SHIELD",
		RarityTier = 6,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_blade_of_the_rift",
		Description = "Dimensional cosmic glass blade swirling with inner nebula stars and antique cathedral portal shield.",
	},
	art_aegis_core = {
		TemplateId = "art_aegis_core",
		DisplayName = "Aegis Core",
		Type = "SWORD_SHIELD",
		RarityTier = 6,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.025,
		ModelAssetId = "art_aegis_core",
		Description = "Hexagonal floating segmented gold plates orbiting a hyper-dense glowing rift power core.",
	},
	art_eclipse_daggers = {
		TemplateId = "art_eclipse_daggers",
		DisplayName = "Eclipse Daggers",
		Type = "DAGGERS",
		RarityTier = 6,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_eclipse_daggers",
		Description = "Opposing celestial twins: one forged of lunar silver, one of solar gold, with crescent eclipse guards.",
	},
	art_abyssal_razor = {
		TemplateId = "art_abyssal_razor",
		DisplayName = "Abyssal Razor",
		Type = "DAGGERS",
		RarityTier = 6,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.025,
		ModelAssetId = "art_abyssal_razor",
		Description = "Void-matter shadow daggers that leave pitch-black cuts suspended in three-dimensional space.",
	},
	art_celestial_zenith = {
		TemplateId = "art_celestial_zenith",
		DisplayName = "Celestial Zenith",
		Type = "BOW",
		RarityTier = 6,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_celestial_zenith",
		Description = "Pristine white marble and polished gold riser with floating orbital ring sights and starlight string.",
	},
	art_supernova_greatbow = {
		TemplateId = "art_supernova_greatbow",
		DisplayName = "Supernova Greatbow",
		Type = "BOW",
		RarityTier = 6,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.025,
		ModelAssetId = "art_supernova_greatbow",
		Description = "Colossal cosmic recurve radiating stellar flares that nocks superheated fusion plasma bolts.",
	},
	art_valkyrie_waraxe = {
		TemplateId = "art_valkyrie_waraxe",
		DisplayName = "Valkyrie Waraxe",
		Type = "AXE",
		RarityTier = 6,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_valkyrie_waraxe",
		Description = "Winged greataxe with a sweeping platinum crescent, braided shaft and cyan teardrop gems.",
	},
	art_world_shaper = {
		TemplateId = "art_world_shaper",
		DisplayName = "World Shaper",
		Type = "AXE",
		RarityTier = 6,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.025,
		ModelAssetId = "art_world_shaper",
		Description = "Foundry greataxe with a forge-hammer back, floating brass conduit rings and a caged anti-gravity core.",
	},
	art_solaris_sunburst = {
		TemplateId = "art_solaris_sunburst",
		DisplayName = "Solaris Sun Scepter",
		Type = "STAFF",
		RarityTier = 6,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_solaris_sunburst",
		Description = "Golden solar eclipse crown with rotating orbital rings suspending an incandescent sun core.",
	},
	art_chronos_stave = {
		TemplateId = "art_chronos_stave",
		DisplayName = "Chronos Time-Weft",
		Type = "STAFF",
		RarityTier = 6,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.025,
		ModelAssetId = "art_chronos_stave",
		Description = "Complex astronomical clockwork mechanism rotating in 3D around an unmoving time singularity.",
	},
	art_seraphic_psalms = {
		TemplateId = "art_seraphic_psalms",
		DisplayName = "Seraphic Liturgy",
		Type = "TOME",
		RarityTier = 6,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_seraphic_psalms",
		Description = "Heavy gilded cathedral tome that floats opened with radiating translucent golden wings extending from the spine.",
	},
	art_divine_providence = {
		TemplateId = "art_divine_providence",
		DisplayName = "Divine Providence",
		Type = "TOME",
		RarityTier = 6,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.025,
		ModelAssetId = "art_divine_providence",
		Description = "Radiant crystalline codex made of prism diamond leaves that project prismatic restorative beams.",
	},
	art_astral_executioner = {
		TemplateId = "art_astral_executioner",
		DisplayName = "Astral Executioner",
		Type = "SWORD_SHIELD",
		RarityTier = 7,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_astral_executioner",
		Description = "Starlight alloy chisel-tipped blade with constellation runes and monolithic starry mirror shield.",
	},
	art_genesis_worldbreaker = {
		TemplateId = "art_genesis_worldbreaker",
		DisplayName = "Worldbreaker Bastion",
		Type = "SWORD_SHIELD",
		RarityTier = 7,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.050,
		ModelAssetId = "art_genesis_worldbreaker",
		Description = "Colossal cosmic bastion forged from a collapsed star; gravitational lensing warps space around its rim.",
	},
	art_abyssal_ravagers = {
		TemplateId = "art_abyssal_ravagers",
		DisplayName = "Abyssal Ravagers",
		Type = "DAGGERS",
		RarityTier = 7,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_abyssal_ravagers",
		Description = "Floating dark-matter phantom daggers tethered by purple lightning arcs around the hero's wrists.",
	},
	art_void_reapers = {
		TemplateId = "art_void_reapers",
		DisplayName = "Void Reapers",
		Type = "DAGGERS",
		RarityTier = 7,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.050,
		ModelAssetId = "art_void_reapers",
		Description = "Twin rift scythe-daggers that slice through the fabric of dimensions, leaving tearing cosmic rifts.",
	},
	art_astrea_cosmic_bow = {
		TemplateId = "art_astrea_cosmic_bow",
		DisplayName = "Cosmic Sagittarius",
		Type = "BOW",
		RarityTier = 7,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_astrea_cosmic_bow",
		Description = "Astrea's pinnacle relic: stave formed of pure starlight constellation lines; nocks pure energy lances.",
	},
	art_infinity_genesis_bow = {
		TemplateId = "art_infinity_genesis_bow",
		DisplayName = "Infinity Bow of Genesis",
		Type = "BOW",
		RarityTier = 7,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.050,
		ModelAssetId = "art_infinity_genesis_bow",
		Description = "Transcendent cosmic arc whose string is a beam of creation light, firing arrows that warp space-time.",
	},
	art_world_carver = {
		TemplateId = "art_world_carver",
		DisplayName = "World Carver",
		Type = "AXE",
		RarityTier = 7,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_world_carver",
		Description = "Colossal dark-matter crescent split by rift fissures, with shards torn loose drifting off its hooked back.",
	},
	art_genesis_sunderer = {
		TemplateId = "art_genesis_sunderer",
		DisplayName = "Genesis Sunderer",
		Type = "AXE",
		RarityTier = 7,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.050,
		ModelAssetId = "art_genesis_sunderer",
		Description = "Four-bladed primordial greataxe crowned by an orbiting creation core; seismic ripples shatter reality.",
	},
	art_eye_of_singularity = {
		TemplateId = "art_eye_of_singularity",
		DisplayName = "Eye of the Singularity",
		Type = "STAFF",
		RarityTier = 7,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_eye_of_singularity",
		Description = "Stave of black cosmic glass culminating in an event horizon core that bends ambient light.",
	},
	art_omega_archon_caduceus = {
		TemplateId = "art_omega_archon_caduceus",
		DisplayName = "Omega Archon Caduceus",
		Type = "STAFF",
		RarityTier = 7,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.050,
		ModelAssetId = "art_omega_archon_caduceus",
		Description = "Primordial staff crowned by an uncoiling infinity loop of cosmic plasma, channeling raw arcane genesis.",
	},
	art_akashic_records = {
		TemplateId = "art_akashic_records",
		DisplayName = "Akashic Infinity",
		Type = "TOME",
		RarityTier = 7,
		IsHighStat = false,
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		ModelAssetId = "art_akashic_records",
		Description = "Boundless astral codex without covers: floating holographic tablets orbiting an ethereal singularity.",
	},
	art_book_of_primordial_genesis = {
		TemplateId = "art_book_of_primordial_genesis",
		DisplayName = "Book of Primordial Genesis",
		Type = "TOME",
		RarityTier = 7,
		IsHighStat = true,
		StatMultiplier = 1.20,
		SpeedBonusAdditive = 0.050,
		ModelAssetId = "art_book_of_primordial_genesis",
		Description = "Transcendent scripture of life itself, written in eternal light that resurrects fallen allies and grants immortality.",
	},

	-- ------------------------------------------------------------------------
	-- THE GILDED ANVIL (6 Tier-8 Transcendent Gildforged Weapons, 1 per Archetype)
	-- ------------------------------------------------------------------------
	art_gild_dawnwarden_oath = {
		TemplateId = "art_gild_dawnwarden_oath",
		DisplayName = "Dawnwarden's Oath",
		Type = "SWORD_SHIELD",
		RarityTier = 8,
		IsHighStat = false,
		Variant = "Gildforged",
		VisualElement = "SUNLIGHT",
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		BaseATK = 10000,
		BaseHP = 0,
		ModelAssetId = "art_gild_dawnwarden_oath",
		Description = "White-gold longsword sworn to a kite shield whose sun-disc boss rises and sets in the hand of its bearer.",
	},
	art_gild_eclipse_sisters = {
		TemplateId = "art_gild_eclipse_sisters",
		DisplayName = "Eclipse Sisters",
		Type = "DAGGERS",
		RarityTier = 8,
		IsHighStat = false,
		Variant = "Gildforged",
		VisualElement = "ECLIPSE",
		StatMultiplier = 1.00,
		SpeedBonusAdditive = 0.000,
		BaseATK = 10000,
		BaseHP = 0,
		ModelAssetId = "art_gild_eclipse_sisters",
		Description = "Twin daggers Umbra and Corona: one of black glass edged in light, one of gold wreathed in black flame.",
	},
}
ArtifactCatalog.Seeds = Seeds
for _, seed in pairs(Seeds) do
	if not seed.Variant then
		(seed :: any).Variant = if seed.IsHighStat then "Enhanced" else "Standard"
	end
end

-- Master order of all 84 weapons for the Artifact Index and catalog viewers
local CatalogOrder: { string } = {
	"art_iron_broadsword",
	"art_tempered_bastard_sword",
	"art_rusty_daggers",
	"art_serrated_skewers",
	"art_hunters_shortbow",
	"art_reinforced_longbow",
	"art_miner_pickaxe",
	"art_heavy_hewing_axe",
	"art_apprentice_cane",
	"art_scholars_spire",
	"art_novice_tome",
	"art_acolytes_litany",
	"art_runic_longsword",
	"art_knightly_estoc",
	"art_viper_kris",
	"art_silent_dirks",
	"art_recurve_composite",
	"art_gale_force_composite",
	"art_canyon_splitter",
	"art_quakestone_greataxe",
	"art_ruby_staff",
	"art_pyromancers_torch_rod",
	"art_cleric_scripture",
	"art_mendicants_psalter",
	"art_paladin_spatha",
	"art_vanguard_warden_bastion",
	"art_shadow_fangs",
	"art_phantom_stiletto",
	"art_stormstrider_longbow",
	"art_thunderhead_recurve",
	"art_battleaxe_cleaver",
	"art_iron_juggernaut_cleaver",
	"art_frostweaver_scepter",
	"art_glacial_monolith",
	"art_hermetic_grimoire",
	"art_restorative_codex",
	"art_crystal_claymore",
	"art_resonant_bulwark",
	"art_phantom_edge",
	"art_nightstalker_katar",
	"art_crystal_greatbow",
	"art_prismatic_arbalest",
	"art_magma_behemoth",
	"art_obsidian_hell_splitter",
	"art_archmage_rod",
	"art_chronomancers_spindle",
	"art_valeria_sanctuary",
	"art_seraphs_testament",
	"art_paladin_claymore",
	"art_aegis_of_valor",
	"art_bloodthirst_twinblades",
	"art_crimson_carnage",
	"art_phoenix_flatbow",
	"art_solar_flare_recurve",
	"art_titan_earthshaker",
	"art_mountain_breaker",
	"art_infernal_pillar",
	"art_void_channeler",
	"art_necronomicon_pages",
	"art_lifebinders_chronicle",
	"art_blade_of_the_rift",
	"art_aegis_core",
	"art_eclipse_daggers",
	"art_abyssal_razor",
	"art_celestial_zenith",
	"art_supernova_greatbow",
	"art_valkyrie_waraxe",
	"art_world_shaper",
	"art_solaris_sunburst",
	"art_chronos_stave",
	"art_seraphic_psalms",
	"art_divine_providence",
	"art_astral_executioner",
	"art_genesis_worldbreaker",
	"art_abyssal_ravagers",
	"art_void_reapers",
	"art_astrea_cosmic_bow",
	"art_infinity_genesis_bow",
	"art_world_carver",
	"art_genesis_sunderer",
	"art_eye_of_singularity",
	"art_omega_archon_caduceus",
	"art_akashic_records",
	"art_book_of_primordial_genesis",
}
ArtifactCatalog.CatalogOrder = CatalogOrder


-- Structured lookup for gacha rolls: [tier][weaponType] = { Standard = seed, Enhanced = seed }
local RosterByTierAndType: { [number]: { [WeaponType]: { Standard: ArtifactSeed, Enhanced: ArtifactSeed } } } = {}
for tier = 1, 7 do
	RosterByTierAndType[tier] = {}
end

for _, seed in pairs(Seeds) do
	local t = seed.RarityTier
	if t and t >= 1 and t <= 7 then
		local byType = RosterByTierAndType[t]
		if not byType[seed.Type] then
			byType[seed.Type] = {} :: any
		end
		if seed.IsHighStat then
			byType[seed.Type].Enhanced = seed
		else
			byType[seed.Type].Standard = seed
		end
	end
end
ArtifactCatalog.RosterByTierAndType = RosterByTierAndType

function ArtifactCatalog.GetTierPair(tier: number, weaponType: WeaponType): (ArtifactSeed?, ArtifactSeed?)
	local byTier = RosterByTierAndType[tier]
	if not byTier then return nil, nil end
	local pair = byTier[weaponType]
	if not pair then return nil, nil end
	return pair.Standard, pair.Enhanced
end

function ArtifactCatalog.GetStatBreakdown(seedId: string, star: number, rarityIndex: number, _legacyLevel: number?): { [string]: number }
	local safeStar = B.Integer(star, 1, 7) and star or 1
	local r = B.Integer(rarityIndex, 1, 16) and rarityIndex or 1
	local seed = ArtifactCatalog.Seeds[seedId]
	local mult = seed and seed.StatMultiplier or 1.00
	local speedAdd = seed and seed.SpeedBonusAdditive or 0
	local basePower = (B.RarityPower[r] or 20) * mult
	local power = basePower * B.WeaponStarMultipliers[safeStar]
	local baseSpeed = (B.RaritySpeed[r] or 0.05) + speedAdd
	return {
		ATK = power,
		Power = power,
		["Attack Speed"] = baseSpeed * 100,
		DamageMultiplier = 1 + power / B.WeaponPowerDivisor,
	}
end

function ArtifactCatalog.CalculateEffectiveStats(star: number, rarityIndex: number, legacyLevel: number?, seedId: string?): (number, number, { [string]: number })
	local result = ArtifactCatalog.GetStatBreakdown(seedId or "", star, rarityIndex, legacyLevel)
	return result.Power, result["Attack Speed"] / 100, result
end

function ArtifactCatalog.CalculateEffectiveInterval(baseInterval: number, speed: number): number
	local interval = B.Finite(baseInterval) and math.max(0.2, baseInterval) or 1
	return math.max(0.2, interval / (1 + (B.Finite(speed) and math.max(0, speed) or 0)))
end

return ArtifactCatalog
