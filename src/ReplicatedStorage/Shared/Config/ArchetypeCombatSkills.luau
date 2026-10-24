--!strict
-- ReplicatedStorage/Shared/Config/ArchetypeCombatSkills.luau
-- Authoritative configuration for the 3-Tier Combat Attack & Skill System across all 6 Class Archetypes.
-- Implements GDD Section 4.4:
--   1. Basic Attack: Standard interval attack, generates +5 Stamina.
--   2. Special Attack: Procs every 3rd attack (Cadence: Basic -> Basic -> Special), generates +10 Stamina with amplified damage and secondary mechanics.
--   3. Skill Attack (Ultimate): Procs when Stamina reaches 100, consumes 100 Stamina (resets to 0) to execute archetype signature ability.

export type SecondaryEffectType =
	| "CONE_STAGGER"
	| "MULTI_CRIT"
	| "PIERCING_LINE"
	| "SEISMIC_STAGGER"
	| "ALLY_MINI_HEAL"
	| "CHAIN_LIGHTNING"

export type BasicAttackDef = {
	Name: string,
	DamageMultiplier: number,
	StaminaGain: number,
	VFXKey: string,
}

export type SpecialAttackDef = {
	Name: string,
	Cadence: number, -- Procs every Nth attack (default: 3)
	DamageMultiplier: number,
	StaminaGain: number,
	SecondaryEffect: SecondaryEffectType,
	SecondaryParam: number, -- e.g. heal percentage, cone radius, chain count
	VFXKey: string,
}

export type SkillAttackDef = {
	Name: string,
	StaminaCost: number, -- 100
	DamageMultiplier: number,
	HealPercent: number?, -- Fractional MaxHP (e.g. 0.35 for 35%)
	BarrierPercent: number?, -- Fractional MaxHP (e.g. 0.40 for 40%)
	Radius: number?, -- Radius in studs for AoE / Taunt
	Duration: number?, -- Duration in seconds for buffs / ground effects
	Description: string,
	VFXKey: string,
}

export type ArchetypeSkillProfile = {
	Archetype: "Vanguard" | "Striker" | "Marksman" | "Miner" | "Healer" | "Scholar",
	DisplayName: string,
	Role: string,
	Basic: BasicAttackDef,
	Special: SpecialAttackDef,
	Skill: SkillAttackDef,
}

local ArchetypeCombatSkills = {}

ArchetypeCombatSkills.Constants = {
	BASIC_STAMINA_GAIN = 5,
	SPECIAL_STAMINA_GAIN = 10,
	SPECIAL_CADENCE = 3,
	MAX_STAMINA = 100,
	SKILL_STAMINA_COST = 100,
}

ArchetypeCombatSkills.Profiles = {
	-- ------------------------------------------------------------------------
	-- 1. VANGUARD (Tank | Melee 6 studs | Interval ~1.20s | Swords, Axes, Shields)
	-- ------------------------------------------------------------------------
	Vanguard = {
		Archetype = "Vanguard",
		DisplayName = "Vanguard",
		Role = "Frontline Tank & Damage Absorber",
		Basic = {
			Name = "Shield Strike",
			DamageMultiplier = 1.00,
			StaminaGain = 5,
			VFXKey = "VANGUARD_BASIC",
		},
		Special = {
			Name = "Shield Bash",
			Cadence = 3,
			DamageMultiplier = 1.40,
			StaminaGain = 10,
			SecondaryEffect = "CONE_STAGGER",
			SecondaryParam = 10.0, -- 10-stud front cone
			VFXKey = "VANGUARD_SPECIAL",
		},
		Skill = {
			Name = "Fortress Aegis",
			StaminaCost = 100,
			DamageMultiplier = 0.00,
			BarrierPercent = 0.40, -- 40% Max HP personal damage barrier
			Radius = 25.0, -- Taunt radius
			Duration = 6.0, -- 6s barrier duration, 4s taunt
			Description = "Unleashes a resounding battle roar, taunting enemies within 25 studs for 4s, and gains a personal damage barrier equal to 40% Max HP for 6s.",
			VFXKey = "VANGUARD_SKILL",
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 2. STRIKER (Melee DPS | Melee 6 studs | Interval ~0.85s | Swords, Daggers, Shields)
	-- ------------------------------------------------------------------------
	Striker = {
		Archetype = "Striker",
		DisplayName = "Striker",
		Role = "Agile Melee Critical DPS",
		Basic = {
			Name = "Twin Slash",
			DamageMultiplier = 1.00,
			StaminaGain = 5,
			VFXKey = "STRIKER_BASIC",
		},
		Special = {
			Name = "Flurry Cross",
			Cadence = 3,
			DamageMultiplier = 1.60,
			StaminaGain = 10,
			SecondaryEffect = "MULTI_CRIT",
			SecondaryParam = 0.25, -- +25% bonus critical chance
			VFXKey = "STRIKER_SPECIAL",
		},
		Skill = {
			Name = "Blade Tempest",
			StaminaCost = 100,
			DamageMultiplier = 3.20,
			Radius = 12.0, -- 12-stud cyclone radius
			Duration = 0.6,
			Description = "Dashes through the primary target in an omni-directional blade flurry, dealing 3.20x ATK burst damage in a 12-stud radius.",
			VFXKey = "STRIKER_SKILL",
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 3. MARKSMAN (Ranged DPS | Range 28 studs | Interval ~0.80s | Bows)
	-- ------------------------------------------------------------------------
	Marksman = {
		Archetype = "Marksman",
		DisplayName = "Marksman",
		Role = "Long-Range Physical DPS & Armor Shredder",
		Basic = {
			Name = "Precision Shot",
			DamageMultiplier = 1.00,
			StaminaGain = 5,
			VFXKey = "MARKSMAN_BASIC",
		},
		Special = {
			Name = "Piercing Volley",
			Cadence = 3,
			DamageMultiplier = 1.50,
			StaminaGain = 10,
			SecondaryEffect = "PIERCING_LINE",
			SecondaryParam = 32.0, -- Pierces in line up to 32 studs
			VFXKey = "MARKSMAN_SPECIAL",
		},
		Skill = {
			Name = "Rain of Arrows",
			StaminaCost = 100,
			DamageMultiplier = 2.80,
			Radius = 16.0, -- 16-stud target area barrage
			Duration = 5.0, -- 5s 20% defense shred
			Description = "Calls down a concentrated arrow storm on the target area (16-stud radius) dealing 2.80x ATK over 4 rapid ticks and shredding enemy defense by 20% for 5s.",
			VFXKey = "MARKSMAN_SKILL",
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 4. MINER (Disruptor / Defense | Melee 6 studs | Interval ~1.05s | Axes, Shields)
	-- ------------------------------------------------------------------------
	Miner = {
		Archetype = "Miner",
		DisplayName = "Miner",
		Role = "Heavy Blunt Disruptor & Resource Extractor",
		Basic = {
			Name = "Maul Swing",
			DamageMultiplier = 1.00,
			StaminaGain = 5,
			VFXKey = "MINER_BASIC",
		},
		Special = {
			Name = "Seismic Slam",
			Cadence = 3,
			DamageMultiplier = 1.50,
			StaminaGain = 10,
			SecondaryEffect = "SEISMIC_STAGGER",
			SecondaryParam = 8.0, -- 8-stud ground shatter
			VFXKey = "MINER_SPECIAL",
		},
		Skill = {
			Name = "Crystalline Cataclysm",
			StaminaCost = 100,
			DamageMultiplier = 2.60,
			Radius = 18.0, -- 18-stud crystalline shockwave
			Duration = 1.0,
			Description = "Slams the ground to summon sharp crystalline spikes under all nearby enemies within 18 studs, dealing 2.60x ATK blunt AoE damage and yielding bonus temporary Mana/Shard drops.",
			VFXKey = "MINER_SKILL",
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 5. HEALER (Recovery Specialist | Range 24 studs | Interval ~1.25s | Staves, Tomes)
	-- ------------------------------------------------------------------------
	Healer = {
		Archetype = "Healer",
		DisplayName = "Healer",
		Role = "Squad Sustain & Restorative Sanctuary",
		Basic = {
			Name = "Holy Bolt",
			DamageMultiplier = 1.00,
			StaminaGain = 5,
			VFXKey = "HEALER_BASIC",
		},
		Special = {
			Name = "Radiant Pulse",
			Cadence = 3,
			DamageMultiplier = 1.20,
			StaminaGain = 10,
			SecondaryEffect = "ALLY_MINI_HEAL",
			SecondaryParam = 0.08, -- Restores 8% Max HP to lowest-HP ally within 30 studs
			VFXKey = "HEALER_SPECIAL",
		},
		Skill = {
			Name = "Sanctuary Miracle",
			StaminaCost = 100,
			DamageMultiplier = 0.00,
			HealPercent = 0.35, -- Immediately restores 35% Max HP to all active squad heroes
			Radius = 25.0, -- Squad aura radius
			Duration = 4.0, -- 4s duration (+3% HP/s regen)
			Description = "Chants a divine sanctuary circle around the squad, immediately restoring 35% Max HP to ALL active deployed heroes, clearing debuffs, and granting +3% HP/s regen for 4s.",
			VFXKey = "HEALER_SKILL",
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 6. SCHOLAR (Mage / Spell Specialist | Range 26 studs | Interval ~1.00s | Tomes, Staves)
	-- ------------------------------------------------------------------------
	Scholar = {
		Archetype = "Scholar",
		DisplayName = "Scholar",
		Role = "Elemental Catalyst & Burst Magic Specialist",
		Basic = {
			Name = "Arcane Spark",
			DamageMultiplier = 1.00,
			StaminaGain = 5,
			VFXKey = "SCHOLAR_BASIC",
		},
		Special = {
			Name = "Chain Lightning",
			Cadence = 3,
			DamageMultiplier = 1.40,
			StaminaGain = 10,
			SecondaryEffect = "CHAIN_LIGHTNING",
			SecondaryParam = 2.0, -- Chains to up to 2 adjacent mobs within 14 studs
			VFXKey = "SCHOLAR_SPECIAL",
		},
		Skill = {
			Name = "Supernova Cataclysm",
			StaminaCost = 100,
			DamageMultiplier = 3.50,
			Radius = 20.0, -- 20-stud meteor blast radius
			Duration = 3.0, -- 3s lingering ground flames
			Description = "Chants a dimensional portal above the battlefield, dropping a massive burning meteor on the target area (20-stud radius) that deals 3.50x ATK fire damage with burning ground flames for 3s.",
			VFXKey = "SCHOLAR_SKILL",
		},
	} :: ArchetypeSkillProfile,
}

-- Fallback profile if an unknown or custom archetype is provided
ArchetypeCombatSkills.DefaultProfile = ArchetypeCombatSkills.Profiles.Striker

function ArchetypeCombatSkills.GetSkillProfile(archetype: string?): ArchetypeSkillProfile
	if not archetype then
		return ArchetypeCombatSkills.DefaultProfile
	end
	local profile = ArchetypeCombatSkills.Profiles[archetype]
	return profile or ArchetypeCombatSkills.DefaultProfile
end

return table.freeze(ArchetypeCombatSkills)
