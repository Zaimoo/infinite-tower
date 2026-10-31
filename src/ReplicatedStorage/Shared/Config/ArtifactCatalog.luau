--!strict
-- ReplicatedStorage/Shared/Config/ArtifactCatalog.luau
-- Authoritative configuration for Equippable Artifacts (Weapons), 7 Star Tiers, 16 Rarity Multipliers, Crafting & Forge Upgrades.

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
	DefaultStar: number,
	ModelAssetId: string, -- Key in ReplicatedStorage.Assets.Weapons
	Description: string,
	BaseATK: number?,
	BaseDEF: number?,
	BaseHP: number?,
	BaseSPD: number?,
	BaseCritRate: number?,
	BaseEvasion: number?,
	BaseAttackSpeed: number?,
	CraftCost: { [string]: number }?,
}

export type CraftingMaterialInfo = {
	Id: string,
	Name: string,
	Icon: string,
	Color: Color3,
	Description: string,
}

local B = require(script.Parent.StatBalance)
local ArtifactCatalog = {}

--============================================================================
-- 1. CRAFTING MATERIALS FOR FORGE
--============================================================================

local CraftingMaterials: { [string]: CraftingMaterialInfo } = {
	IronGear = {
		Id = "IronGear",
		Name = "Iron Gear",
		Icon = "⚙️",
		Color = Color3.fromRGB(180, 185, 195),
		Description = "Tempered machine cog salvaged from mechanical constructs.",
	},
	RiftOrb = {
		Id = "RiftOrb",
		Name = "Rift Orb",
		Icon = "🔮",
		Color = Color3.fromRGB(190, 120, 255),
		Description = "Concentrated cosmic energy condensed into an astral sphere.",
	},
	AegisGem = {
		Id = "AegisGem",
		Name = "Aegis Gem",
		Icon = "💎",
		Color = Color3.fromRGB(80, 200, 255),
		Description = "Luminous crystalline diamond imbued with defensive wards.",
	},
	StarDust = {
		Id = "StarDust",
		Name = "Star Dust",
		Icon = "✨",
		Color = Color3.fromRGB(255, 215, 80),
		Description = "Shimmering celestial particles that quicken cadence and agility.",
	},
	VoidPowder = {
		Id = "VoidPowder",
		Name = "Void Powder",
		Icon = "🌑",
		Color = Color3.fromRGB(160, 140, 200),
		Description = "Finely ground abyssal residue that destabilizes inertia.",
	},
}
ArtifactCatalog.CraftingMaterials = CraftingMaterials

--============================================================================
-- 1.5. ARTIFACT BANNER (ECHOES OF THE RIFT GACHA)
--============================================================================

export type ArtifactBannerConfig = {
	BannerId: string,
	Title: string,
	FeaturedHeroWatermark: string,
	Cost1X: number,
	Cost10X: number,
	MaxPity: number,
	Featured5Stars: { string },
	Pool4Stars: { string },
	Pool3Stars: { string },
	Pool12Stars: { string },
}

local Banner: ArtifactBannerConfig = {
	BannerId = "banner_echoes_of_the_rift",
	Title = "ECHOES OF THE RIFT",
	FeaturedHeroWatermark = "★ 5-STAR FEATURED HERO & ARTIFACTS",
	Cost1X = 160,
	Cost10X = 1600,
	MaxPity = 50,
	Featured5Stars = { "art_blade_of_the_rift", "art_aegis_core" },
	Pool4Stars = { "art_shadow_fangs", "art_crystal_greatbow", "art_paladin_claymore" },
	Pool3Stars = { "art_runic_longsword", "art_battleaxe_cleaver", "art_recurve_composite", "art_ruby_staff" },
	Pool12Stars = { "art_hunters_shortbow", "art_iron_broadsword", "art_rusty_daggers", "art_miner_pickaxe", "art_novice_tome" },
}
ArtifactCatalog.Banner = Banner

function ArtifactCatalog.GetPityRemaining(bannerPity: number?): number
	local p = bannerPity or 8 -- Default 8 gives 42 (50 - 8 = 42) to match mockup
	return math.max(1, Banner.MaxPity - (p % Banner.MaxPity))
end

--============================================================================
-- 2. CLASS RESTRICTIONS (HERO ARCHETYPE -> PERMITTED WEAPON TYPES)
--============================================================================

-- One weapon type per archetype; a hero holds a single equipped artifact.
local ArchetypeWeaponType: { [string]: WeaponType } = {
	Vanguard = "SWORD_SHIELD",
	Striker = "DAGGERS",
	Marksman = "BOW",
	Miner = "AXE",
	Scholar = "STAFF",
	Healer = "TOME",
}
ArtifactCatalog.ArchetypeWeaponType = ArchetypeWeaponType

-- List form kept for callers that format the permitted types.
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
-- 5. FODDER REQUIREMENT & STAT FORMULAS
--============================================================================

-- Level is retained only as an ignored argument for old callers.
ArtifactCatalog.MaxStars = 7
ArtifactCatalog.MaxEnhancementLevel = 0
ArtifactCatalog.StarMultipliers = B.WeaponStarMultipliers
ArtifactCatalog.StarPromotionCosts = B.WeaponPromotionCosts
for tier, info in pairs(Rarities) do
 info.Power = B.RarityPower[tier]
 info.SpeedBonus = B.RaritySpeed[tier]
end
function ArtifactCatalog.GetStarPromotionCost(currentStar: number): any?
 return B.Integer(currentStar,1,6) and B.WeaponPromotionCosts[currentStar] or nil
end
function ArtifactCatalog.GetFodderRequirement(currentStar: number): number
 local rule=ArtifactCatalog.GetStarPromotionCost(currentStar)
 return rule and rule.Donors or 0
end
function ArtifactCatalog.GetStatBreakdown(_seedId: string, star: number, rarityIndex: number, _legacyLevel: number?): { [string]: number }
 local safeStar=B.Integer(star,1,7) and star or 1
 local r=B.Integer(rarityIndex,1,16) and rarityIndex or 1
 local power=B.RarityPower[r]*B.WeaponStarMultipliers[safeStar]
 return {ATK=power, Power=power, ["Attack Speed"]=B.RaritySpeed[r]*100, DamageMultiplier=1+power/B.WeaponPowerDivisor}
end
function ArtifactCatalog.CalculateEffectiveStats(star: number, rarityIndex: number, legacyLevel: number?, seedId: string?): (number, number, { [string]: number })
 local result=ArtifactCatalog.GetStatBreakdown(seedId or "",star,rarityIndex,legacyLevel)
 return result.Power,result["Attack Speed"]/100,result
end
function ArtifactCatalog.CalculateEffectiveInterval(baseInterval: number, speed: number): number
 local interval=B.Finite(baseInterval) and math.max(.2,baseInterval) or 1
 return math.max(.2,interval/(1+(B.Finite(speed) and math.max(0,speed) or 0)))
end

--============================================================================
-- 6. BLACKSMITH UPGRADE COSTS (TIER R -> TIER R + 1)
--============================================================================

ArtifactCatalog.BlacksmithUpgradeCosts = {
	[1]  = { Gold = 250,      Gems = 0 },    -- Common -> Uncommon
	[2]  = { Gold = 600,      Gems = 0 },    -- Uncommon -> Rare
	[3]  = { Gold = 1500,     Gems = 0 },    -- Rare -> Superior
	[4]  = { Gold = 3500,     Gems = 0 },    -- Superior -> Exalted
	[5]  = { Gold = 8000,     Gems = 15 },   -- Exalted -> Legendary
	[6]  = { Gold = 18000,    Gems = 35 },   -- Legendary -> Mythical
	[7]  = { Gold = 40000,    Gems = 75 },   -- Mythical -> Transcendent
	[8]  = { Gold = 90000,    Gems = 150 },  -- Transcendent -> Ascendant
	[9]  = { Gold = 200000,   Gems = 300 },  -- Ascendant -> Ethereal
	[10] = { Gold = 450000,   Gems = 600 },  -- Ethereal -> Immortal
	[11] = { Gold = 1000000,  Gems = 1200 }, -- Immortal -> Divine
	[12] = { Gold = 2200000,  Gems = 2500 }, -- Divine -> Celestial
	[13] = { Gold = 5000000,  Gems = 5000 }, -- Celestial -> Primordial
	[14] = { Gold = 12000000, Gems = 10000 },-- Primordial -> Supreme
	[15] = { Gold = 30000000, Gems = 25000 },-- Supreme -> Origin
}

function ArtifactCatalog.GetUpgradeCost(currentRarityIndex: number): { Gold: number, Gems: number }?
	return ArtifactCatalog.BlacksmithUpgradeCosts[currentRarityIndex]
end

--============================================================================
-- 7. CATALOG SEEDS / TEMPLATES & RECIPES
--============================================================================

local Seeds: { [string]: ArtifactSeed } = {
	-- FEATURED RECIPES (FROM MOCKUP)
	art_blade_of_the_rift = {
		TemplateId = "art_blade_of_the_rift",
		DisplayName = "Blade of the Rift",
		Type = "SWORD_SHIELD",
		DefaultStar = 3,
		ModelAssetId = "weapon_sword_shield",
		Description = "A mastercrafted edge resonating with dimensional rift energy.",
		BaseATK = 150,
		BaseCritRate = 0.05,
		CraftCost = { IronGear = 5, RiftOrb = 3 },
	},
	art_aegis_core = {
		TemplateId = "art_aegis_core",
		DisplayName = "Aegis Core",
		Type = "SWORD_SHIELD",
		DefaultStar = 3,
		ModelAssetId = "weapon_sword_shield",
		Description = "A warding blade paired with an impenetrable aegis matrix radiating dense fields.",
		BaseDEF = 200,
		BaseHP = 500,
		CraftCost = { IronGear = 8, AegisGem = 2 },
	},

	-- BOWS
	art_hunters_shortbow = {
		TemplateId = "art_hunters_shortbow",
		DisplayName = "Hunter's Shortbow",
		Type = "BOW",
		DefaultStar = 1,
		ModelAssetId = "weapon_bow",
		Description = "A lightweight hunting bow, balanced and easy to handle in scouts' hands.",
		CraftCost = { IronGear = 4, StarDust = 4 },
	},
	art_recurve_composite = {
		TemplateId = "art_recurve_composite",
		DisplayName = "Wind-Scout Recurve",
		Type = "BOW",
		DefaultStar = 2,
		ModelAssetId = "weapon_bow",
		Description = "Reinforced composite bow layered with flexible ashwood and horn.",
		CraftCost = { IronGear = 6, RiftOrb = 2 },
	},
	art_crystal_greatbow = {
		TemplateId = "art_crystal_greatbow",
		DisplayName = "Crystal Greatbow",
		Type = "BOW",
		DefaultStar = 3,
		ModelAssetId = "weapon_bow",
		Description = "Gleaming crystalline limbs that hum with condensed atmospheric mana.",
		CraftCost = { RiftOrb = 4, AegisGem = 2 },
	},

	-- SWORD & SHIELD (VANGUARD)
	art_iron_broadsword = {
		TemplateId = "art_iron_broadsword",
		DisplayName = "Iron Broadsword",
		Type = "SWORD_SHIELD",
		DefaultStar = 1,
		ModelAssetId = "weapon_iron_broadsword",
		Description = "Standard-issue balanced iron blade favoured by frontline strikers.",
		CraftCost = { IronGear = 4, RiftOrb = 1 },
	},
	art_runic_longsword = {
		TemplateId = "art_runic_longsword",
		DisplayName = "Runic Longsword",
		Type = "SWORD_SHIELD",
		DefaultStar = 2,
		ModelAssetId = "weapon_sword_shield",
		Description = "A double-edged steel longsword etched with runic blood-grooves.",
		CraftCost = { IronGear = 6, RiftOrb = 2 },
	},
	art_paladin_claymore = {
		TemplateId = "art_paladin_claymore",
		DisplayName = "Holy Claymore",
		Type = "SWORD_SHIELD",
		DefaultStar = 3,
		ModelAssetId = "weapon_sword_shield",
		Description = "Massive consecrated two-hander capable of rending fiends asunder.",
		CraftCost = { IronGear = 8, AegisGem = 2 },
	},

	-- DAGGERS
	art_rusty_daggers = {
		TemplateId = "art_rusty_daggers",
		DisplayName = "Rogue Daggers",
		Type = "DAGGERS",
		DefaultStar = 1,
		ModelAssetId = "weapon_daggers",
		Description = "Twin serrated trench daggers suited for swift vital strikes.",
		CraftCost = { IronGear = 3, VoidPowder = 2 },
	},
	art_shadow_fangs = {
		TemplateId = "art_shadow_fangs",
		DisplayName = "Shadow Fangs",
		Type = "DAGGERS",
		DefaultStar = 2,
		ModelAssetId = "weapon_daggers",
		Description = "Twin obsidian stilettos that leave faint trails of abyssal smoke.",
		CraftCost = { StarDust = 6, VoidPowder = 4 },
	},

	-- AXES
	art_miner_pickaxe = {
		TemplateId = "art_miner_pickaxe",
		DisplayName = "Prospector's Cleaver",
		Type = "AXE",
		DefaultStar = 1,
		ModelAssetId = "weapon_axe",
		Description = "Heavy tempered tool ideal for splitting both bedrock and armored foes.",
		CraftCost = { IronGear = 5, RiftOrb = 1 },
	},
	art_battleaxe_cleaver = {
		TemplateId = "art_battleaxe_cleaver",
		DisplayName = "Warforged Battleaxe",
		Type = "AXE",
		DefaultStar = 2,
		ModelAssetId = "weapon_axe",
		Description = "Beveled dual-headed axe built to smash through heavy shields.",
		CraftCost = { IronGear = 8, AegisGem = 2 },
	},

	-- TOMES & STAVES (SCHOLAR / HEALER)
	art_novice_tome = {
		TemplateId = "art_novice_tome",
		DisplayName = "Novice Pyromancer Tome",
		Type = "TOME",
		DefaultStar = 1,
		ModelAssetId = "weapon_tome",
		Description = "Leatherbound grimoire inscribed with foundational flame incantations.",
		CraftCost = { StarDust = 5, RiftOrb = 2 },
	},
	art_ruby_staff = {
		TemplateId = "art_ruby_staff",
		DisplayName = "Ruby Channeling Staff",
		Type = "STAFF",
		DefaultStar = 2,
		ModelAssetId = "weapon_staff",
		Description = "Staff tipped with an uncut igneous crystal that amplifies spellcasting cadence.",
		CraftCost = { StarDust = 8, RiftOrb = 3 },
	},
}
ArtifactCatalog.Seeds = Seeds

-- List of recipes in presentation order for the Crafting UI
ArtifactCatalog.CraftingRecipeOrder = {
	"art_blade_of_the_rift",
	"art_aegis_core",
	"art_iron_broadsword",
	"art_runic_longsword",
	"art_paladin_claymore",
	"art_hunters_shortbow",
	"art_recurve_composite",
	"art_crystal_greatbow",
	"art_rusty_daggers",
	"art_shadow_fangs",
	"art_miner_pickaxe",
	"art_battleaxe_cleaver",
	"art_novice_tome",
	"art_ruby_staff",
}

return ArtifactCatalog
