--!strict
-- ReplicatedStorage/Shared/Config/ArtifactCatalog.luau
-- Authoritative configuration for Equippable Artifacts (Weapons), 7 Star Tiers, 16 Rarity Multipliers & Blacksmith Upgrades.

export type WeaponType = "BOW" | "SWORD" | "DAGGERS" | "AXE" | "TOME" | "STAFF"

export type RarityInfo = {
	Index: number,
	Name: string,
	Multiplier: number,
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
}

local ArtifactCatalog = {}

--============================================================================
-- 1. CLASS RESTRICTIONS (HERO ARCHETYPE -> PERMITTED WEAPON TYPES)
--============================================================================

ArtifactCatalog.ArchetypeRestrictions = {
	Marksman = { "BOW" },
	Striker = { "SWORD", "DAGGERS" },
	Vanguard = { "SWORD", "AXE" },
	Miner = { "AXE" },
	Scholar = { "TOME", "STAFF" },
	Healer = { "STAFF", "TOME" },
}

function ArtifactCatalog.CanHeroEquip(heroArchetype: string, weaponType: WeaponType): boolean
	local allowed = ArtifactCatalog.ArchetypeRestrictions[heroArchetype]
	if not allowed then return false end
	for _, t in ipairs(allowed) do
		if t == weaponType then
			return true
		end
	end
	return false
end

--============================================================================
-- 2. THE 7 STAR TIERS (BASE STATS)
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
-- 3. THE 16 RARITY TIERS (STAT MULTIPLIERS & PALETTE)
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
-- 4. MATHEMATICAL COMBAT FORMULAS
--============================================================================

function ArtifactCatalog.CalculateEffectiveStats(star: number, rarityIndex: number): (number, number)
	local baseATK, baseSpeed = ArtifactCatalog.GetStarBaseStats(star)
	local rarity = ArtifactCatalog.GetRarityInfo(rarityIndex)
	local totalATKBonus = math.floor(baseATK * rarity.Multiplier)
	local totalSpeedBonus = baseSpeed * rarity.Multiplier
	return totalATKBonus, totalSpeedBonus
end

function ArtifactCatalog.CalculateEffectiveInterval(baseInterval: number, totalSpeedBonus: number): number
	local safeInterval = math.max(0.2, baseInterval)
	local safeSpeed = math.max(0, totalSpeedBonus)
	return math.max(0.12, safeInterval / (1 + safeSpeed))
end

--============================================================================
-- 5. BLACKSMITH UPGRADE COSTS (TIER R -> TIER R + 1)
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
-- 6. CATALOG SEEDS / TEMPLATES
--============================================================================

local Seeds: { [string]: ArtifactSeed } = {
	-- BOWS
	art_hunters_shortbow = {
		TemplateId = "art_hunters_shortbow",
		DisplayName = "Hunter's Shortbow",
		Type = "BOW",
		DefaultStar = 1,
		ModelAssetId = "weapon_bow",
		Description = "A lightweight hunting bow, balanced and easy to handle in scouts' hands.",
	},
	art_recurve_composite = {
		TemplateId = "art_recurve_composite",
		DisplayName = "Wind-Scout Recurve",
		Type = "BOW",
		DefaultStar = 2,
		ModelAssetId = "weapon_bow",
		Description = "Reinforced composite bow layered with flexible ashwood and horn.",
	},
	art_crystal_greatbow = {
		TemplateId = "art_crystal_greatbow",
		DisplayName = "Crystal Greatbow",
		Type = "BOW",
		DefaultStar = 3,
		ModelAssetId = "weapon_bow",
		Description = "Gleaming crystalline limbs that hum with condensed atmospheric mana.",
	},

	-- SWORDS
	art_iron_broadsword = {
		TemplateId = "art_iron_broadsword",
		DisplayName = "Iron Broadsword",
		Type = "SWORD",
		DefaultStar = 1,
		ModelAssetId = "weapon_sword",
		Description = "Standard-issue balanced iron blade favoured by frontline strikers.",
	},
	art_runic_longsword = {
		TemplateId = "art_runic_longsword",
		DisplayName = "Runic Longsword",
		Type = "SWORD",
		DefaultStar = 2,
		ModelAssetId = "weapon_sword",
		Description = "A double-edged steel longsword etched with runic blood-grooves.",
	},
	art_paladin_claymore = {
		TemplateId = "art_paladin_claymore",
		DisplayName = "Holy Claymore",
		Type = "SWORD",
		DefaultStar = 3,
		ModelAssetId = "weapon_sword",
		Description = "Massive consecrated two-hander capable of rending fiends asunder.",
	},

	-- DAGGERS
	art_rusty_daggers = {
		TemplateId = "art_rusty_daggers",
		DisplayName = "Rogue Daggers",
		Type = "DAGGERS",
		DefaultStar = 1,
		ModelAssetId = "weapon_daggers",
		Description = "Twin serrated trench daggers suited for swift vital strikes.",
	},
	art_shadow_fangs = {
		TemplateId = "art_shadow_fangs",
		DisplayName = "Shadow Fangs",
		Type = "DAGGERS",
		DefaultStar = 2,
		ModelAssetId = "weapon_daggers",
		Description = "Twin obsidian stilettos that leave faint trails of abyssal smoke.",
	},

	-- AXES
	art_miner_pickaxe = {
		TemplateId = "art_miner_pickaxe",
		DisplayName = "Prospector's Cleaver",
		Type = "AXE",
		DefaultStar = 1,
		ModelAssetId = "weapon_axe",
		Description = "Heavy tempered tool ideal for splitting both bedrock and armored foes.",
	},
	art_battleaxe_cleaver = {
		TemplateId = "art_battleaxe_cleaver",
		DisplayName = "Warforged Battleaxe",
		Type = "AXE",
		DefaultStar = 2,
		ModelAssetId = "weapon_axe",
		Description = "Beveled dual-headed axe built to smash through heavy shields.",
	},

	-- TOMES & STAVES (SCHOLAR)
	art_novice_tome = {
		TemplateId = "art_novice_tome",
		DisplayName = "Novice Pyromancer Tome",
		Type = "TOME",
		DefaultStar = 1,
		ModelAssetId = "weapon_tome",
		Description = "Leatherbound grimoire inscribed with foundational flame incantations.",
	},
	art_ruby_staff = {
		TemplateId = "art_ruby_staff",
		DisplayName = "Ruby Channeling Staff",
		Type = "STAFF",
		DefaultStar = 2,
		ModelAssetId = "weapon_staff",
		Description = "Staff tipped with an uncut igneous crystal that amplifies spellcasting cadence.",
	},
}
ArtifactCatalog.Seeds = Seeds

return ArtifactCatalog
