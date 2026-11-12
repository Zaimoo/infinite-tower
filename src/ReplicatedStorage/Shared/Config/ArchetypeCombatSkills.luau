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
	| "BEAM_LINE" -- every mob on a line through the target (SecondaryParam = length; Vane)

export type Delivery = "MELEE" | "PROJECTILE" | "AREA"

-- Delivery timing, shared by every tier (docs/projectile-skill-vfx-plan.md). HeroActionTiming
-- turns these into release and impact times; CombatSimulation lands the hit at impact.
--   Delivery: how the blow reaches the target. MELEE (default) lands at the clip's Release marker.
--   ProjectileSpeed: studs/s from release to the target (PROJECTILE).
--   TravelSeconds: fixed release-to-impact delay (AREA: a flare arrow, a falling meteor).
--   Ticks / TickSeconds: the impact repeats Ticks times, its damage split evenly between them.

export type BasicAttackDef = {
	Name: string,
	DamageMultiplier: number,
	StaminaGain: number,
	VFXKey: string,
	Delivery: Delivery?,
	ProjectileSpeed: number?,
	TravelSeconds: number?,
	Ticks: number?,
	TickSeconds: number?,
}

export type SpecialAttackDef = {
	Name: string,
	Cadence: number, -- Procs every Nth attack (default: 3)
	DamageMultiplier: number,
	StaminaGain: number,
	SecondaryEffect: SecondaryEffectType,
	SecondaryParam: number, -- e.g. heal percentage, cone radius, chain count
	BeamWidth: number?, -- BEAM_LINE: hit width in studs, bodies included
	BeamDamage: number?, -- BEAM_LINE: ATK multiplier for every other mob on the line
	VFXKey: string,
	Delivery: Delivery?,
	ProjectileSpeed: number?,
	TravelSeconds: number?,
	Ticks: number?,
	TickSeconds: number?,
}

export type SkillAttackDef = {
	Name: string,
	StaminaCost: number, -- 100
	DamageMultiplier: number,
	HealPercent: number?, -- Fractional MaxHP (e.g. 0.35 for 35%)
	TargetLowestAlly: boolean?, -- True for single-target lowest-HP ally heals
	MaxHpBuffPercent: number?, -- Fractional MaxHP buff applied to the healed target (e.g. 0.25 for +25% Max HP)
	BarrierPercent: number?, -- Fractional MaxHP (e.g. 0.40 for 40%)
	Radius: number?, -- Radius in studs for AoE / Taunt
	Duration: number?, -- Duration in seconds for buffs / ground effects
	TauntDuration: number?, -- Duration in seconds for taunt
	Description: string,
	VFXKey: string,
	CastSeconds: number?, -- minimum animation lock; the hero's next attack waits for it
	Effect: "SINGULARITY"?, -- a hero's own skill effect instead of its archetype's (HeroSkillEffects)
	PullStudsPerTick: number?, -- SINGULARITY: studs each tick drags mobs towards the centre
	CoreRadius: number?, -- SINGULARITY: pulls stop this far from the centre
	Delivery: Delivery?,
	ProjectileSpeed: number?,
	TravelSeconds: number?,
	Ticks: number?,
	TickSeconds: number?,
}

export type ArchetypeSkillProfile = {
	Archetype: "Vanguard" | "Striker" | "Marksman" | "Berserker" | "Healer" | "Scholar",
	HeroId: string?, -- Set on per-hero kits; nil on archetype base profiles
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
	-- 1. VANGUARD (Tank | Melee 6 studs | Interval ~1.20s | Sword & Shield)
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
			TauntDuration = 4.0,
			Description = "Unleashes a resounding battle roar, taunting enemies within 25 studs for 4s, and gains a personal damage barrier equal to 40% Max HP for 6s.",
			VFXKey = "VANGUARD_SKILL",
			CastSeconds = 1.1,
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 2. STRIKER (Melee DPS | Melee 6 studs | Interval ~0.85s | Daggers)
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
			CastSeconds = 1.0,
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
			Delivery = "PROJECTILE",
			ProjectileSpeed = 95,
		},
		Special = {
			Name = "Piercing Volley",
			Cadence = 3,
			DamageMultiplier = 1.50,
			StaminaGain = 10,
			SecondaryEffect = "PIERCING_LINE",
			SecondaryParam = 32.0, -- Pierces in line up to 32 studs
			VFXKey = "MARKSMAN_SPECIAL",
			Delivery = "PROJECTILE",
			ProjectileSpeed = 120,
		},
		Skill = {
			Name = "Rain of Arrows",
			StaminaCost = 100,
			DamageMultiplier = 2.80,
			Radius = 16.0, -- 16-stud target area barrage
			Duration = 5.0, -- 5s 20% defense shred
			Description = "Calls down a concentrated arrow storm on the target area (16-stud radius) dealing 2.80x ATK over 4 rapid ticks and shredding enemy defense by 20% for 5s.",
			VFXKey = "MARKSMAN_SKILL",
			CastSeconds = 1.1,
			Delivery = "AREA",
			TravelSeconds = 0.35, -- flare arrow climbs, then the rain falls
			Ticks = 4,
			TickSeconds = 0.15,
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 4. BERSERKER (Two-handed bruiser | Melee 6 studs | Interval ~1.05s | Greataxes)
	-- ------------------------------------------------------------------------
	Berserker = {
		Archetype = "Berserker",
		DisplayName = "Berserker",
		Role = "Two-Handed Greataxe Bruiser & Ground Disruptor",
		Basic = {
			Name = "Greataxe Cleave",
			DamageMultiplier = 1.00,
			StaminaGain = 5,
			VFXKey = "BERSERKER_BASIC",
		},
		Special = {
			Name = "Seismic Slam",
			Cadence = 3,
			DamageMultiplier = 1.50,
			StaminaGain = 10,
			SecondaryEffect = "SEISMIC_STAGGER",
			SecondaryParam = 8.0, -- 8-stud ground shatter
			VFXKey = "BERSERKER_SPECIAL",
		},
		Skill = {
			Name = "Crystalline Cataclysm",
			StaminaCost = 100,
			DamageMultiplier = 2.60,
			Radius = 18.0, -- 18-stud crystalline shockwave
			Duration = 1.0,
			Description = "Slams the ground to summon sharp crystalline spikes under all nearby enemies within 18 studs, dealing 2.60x ATK blunt AoE damage and yielding bonus temporary Mana/Shard drops.",
			VFXKey = "BERSERKER_SKILL",
			CastSeconds = 1.15,
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 5. HEALER (Recovery Specialist | Range 24 studs | Interval ~1.25s | Tomes)
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
			Delivery = "PROJECTILE",
			ProjectileSpeed = 70,
		},
		Special = {
			Name = "Radiant Pulse",
			Cadence = 3,
			DamageMultiplier = 1.20,
			StaminaGain = 10,
			SecondaryEffect = "ALLY_MINI_HEAL",
			SecondaryParam = 0.08, -- Restores 8% Max HP to lowest-HP ally within 30 studs
			VFXKey = "HEALER_SPECIAL",
			Delivery = "PROJECTILE",
			ProjectileSpeed = 70,
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
			CastSeconds = 1.2,
			Delivery = "AREA",
		},
	} :: ArchetypeSkillProfile,

	-- ------------------------------------------------------------------------
	-- 6. SCHOLAR (Mage / Spell Specialist | Range 26 studs | Interval ~1.00s | Staves)
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
			Delivery = "PROJECTILE",
			ProjectileSpeed = 70,
		},
		Special = {
			Name = "Chain Lightning",
			Cadence = 3,
			DamageMultiplier = 1.40,
			StaminaGain = 10,
			SecondaryEffect = "CHAIN_LIGHTNING",
			SecondaryParam = 2.0, -- Chains to up to 2 adjacent mobs within 14 studs
			VFXKey = "SCHOLAR_SPECIAL",
			Delivery = "PROJECTILE",
			ProjectileSpeed = 80,
		},
		Skill = {
			Name = "Supernova Cataclysm",
			StaminaCost = 100,
			DamageMultiplier = 3.50,
			Radius = 20.0, -- 20-stud meteor blast radius
			Duration = 3.0, -- 3s lingering ground flames
			Description = "Chants a dimensional portal above the battlefield, dropping a massive burning meteor on the target area (20-stud radius) that deals 3.50x ATK fire damage with burning ground flames for 3s.",
			VFXKey = "SCHOLAR_SKILL",
			CastSeconds = 1.2,
			Delivery = "AREA",
			TravelSeconds = 0.3, -- the meteor falls
		},
	} :: ArchetypeSkillProfile,
}

-- Fallback profile if an unknown or custom archetype is provided
ArchetypeCombatSkills.DefaultProfile = ArchetypeCombatSkills.Profiles.Striker

-- ----------------------------------------------------------------------------
-- PER-HERO SKILL KITS (GDD Section 4.4 Hero Combat Skill Ledger)
-- Each hero inherits its archetype's numbers and secondary mechanics, then
-- overrides names, descriptions, and (optionally) multipliers with a bespoke kit.
-- ----------------------------------------------------------------------------
type HeroKitOverride = {
	Archetype: string,
	Basic: { [string]: any },
	Special: { [string]: any },
	Skill: { [string]: any },
}

local function buildHeroProfile(heroId: string, kit: HeroKitOverride): ArchetypeSkillProfile
	local base = ArchetypeCombatSkills.Profiles[kit.Archetype] or ArchetypeCombatSkills.DefaultProfile
	local function merge(baseDef: { [string]: any }, override: { [string]: any }): any
		local def = table.clone(baseDef)
		for key, value in override do
			def[key] = value
		end
		return table.freeze(def)
	end
	local profile = table.clone(base) :: any
	profile.HeroId = heroId
	profile.Basic = merge(base.Basic :: any, kit.Basic)
	profile.Special = merge(base.Special :: any, kit.Special)
	profile.Skill = merge(base.Skill :: any, kit.Skill)
	return table.freeze(profile) :: ArchetypeSkillProfile
end

local HERO_KITS: { [string]: HeroKitOverride } = {
	hero_han = {
		Archetype = "Striker",
		Basic = { Name = "Gloam Cut" },
		-- A leaping double stab with both daggers reversed: the 1.60x hit lands as two blows.
		Special = { Name = "Nightfall Fangs", Ticks = 2, TickSeconds = 0.1 },
		-- He dashes through the target and the cuts he leaves behind keep slashing the circle:
		-- the 3.20x burst is split over five waves instead of landing at once.
		Skill = {
			Name = "Abyssal Wake",
			Description = "Han dashes through the target and leaves a circle of lingering slashes behind him: 3.20x ATK over 5 waves to every enemy within 12 studs.",
			Ticks = 5,
			TickSeconds = 0.12,
		},
	},
	hero_aaron = {
		Archetype = "Vanguard",
		Basic = { Name = "Bastion Strike" },
		Special = { Name = "Aegis Shield Bash" },
		Skill = {
			Name = "Fortress Bulwark",
			Description = "Aaron plants his phalanx shield, taunting enemies within 25 studs for 4s and raising a barrier equal to 40% Max HP for 6s.",
		},
	},
	hero_catio = {
		Archetype = "Berserker",
		Basic = { Name = "Riftsteel Cleave" },
		Special = { Name = "Resonance Tremor" },
		Skill = {
			Name = "Crystalline Excavation",
			Description = "Catio strikes a resonant fault line, erupting crystal spikes under all enemies within 18 studs for 2.60x ATK blunt damage and bonus gem shards.",
		},
	},
	hero_gide = {
		Archetype = "Berserker",
		Basic = { Name = "Ironvein Chop" },
		Special = { Name = "Bedrock Sundering" },
		Skill = {
			Name = "Tunnelbreaker Fault",
			Description = "Gide drives his heavy axe into the floor, splitting a fault line that erupts jagged stone and crystal spikes under all enemies within 18 studs for 2.60x ATK blunt damage and bonus shard drops.",
		},
	},
	hero_valeria = {
		Archetype = "Healer",
		Basic = { Name = "Emerald Bolt" },
		Special = { Name = "Verdant Mend" },
		Skill = {
			Name = "Sanctuary Miracle",
			Description = "Valeria blooms an emerald sanctuary, restoring 35% Max HP to ALL deployed heroes, cleansing debuffs, and granting +3% HP/s regen for 4s.",
		},
	},
	hero_diran = {
		Archetype = "Healer",
		Basic = { Name = "Runeward Bolt" },
		Special = { Name = "Compass Mend" },
		Skill = {
			Name = "Vitality Covenant",
			HealPercent = 0.55,
			TargetLowestAlly = true,
			MaxHpBuffPercent = 0.25,
			Duration = 8.0,
			Description = "Diran invokes a sacred covenant from his grimoire, prioritizing the deployed ally with the lowest HP to restore 55% Max HP and buff their Max HP by 25% for 8s.",
		},
	},
	hero_ignis = {
		Archetype = "Vanguard",
		Basic = { Name = "Molten Cleave" },
		Special = { Name = "Magma Breaker" },
		Skill = {
			Name = "Infernal Juggernaut",
			Description = "Ignis ignites into a molten juggernaut, taunting enemies within 25 studs for 4s and encasing himself in a magma barrier equal to 40% Max HP for 6s.",
		},
	},
	hero_edis = {
		Archetype = "Striker",
		Basic = { Name = "Ravenclaw Cut" },
		Special = { Name = "Umbral Crosscut" },
		Skill = {
			Name = "Midnight Requiem",
			Description = "Edis vanishes into a whirl of black leather and steel, cutting through everything around the target for 3.20x ATK burst damage in a 12-stud radius.",
		},
	},
	hero_jenna = {
		Archetype = "Marksman",
		Basic = { Name = "Wind-Step Shot" },
		Special = { Name = "Piercing Gale Volley" },
		Skill = {
			Name = "Sylphid Arrow Storm",
			Description = "Jenna looses a sky-flare arrow that opens a wind sigil, raining gale arrows over a 16-stud radius for 2.80x ATK and shredding enemy defense by 20% for 5s.",
		},
	},
	hero_aeli = {
		Archetype = "Marksman",
		Basic = { Name = "Leafwind Arrow" },
		Special = { Name = "Thornbriar Volley" },
		Skill = {
			Name = "Canopy's Wrath",
			Description = "Aeli looses a seed-arrow into the sky that bursts into a canopy of leaf-bladed arrows over a 16-stud radius, dealing 2.80x ATK and shredding enemy defense by 20% for 5s.",
		},
	},
	hero_velkist = {
		Archetype = "Striker",
		Basic = { Name = "Twin Fang Cut" },
		Special = { Name = "Shadow Rend" },
		Skill = {
			Name = "Phantom Lotus Execution",
			Description = "Velkist blinks through the target in a blooming phantom lotus of blades, dealing 3.20x ATK burst damage in a 12-stud radius.",
		},
	},
	hero_eolka = {
		Archetype = "Scholar",
		Basic = { Name = "Ruby Firebolt" },
		Special = { Name = "Wildfire Chain" },
		Skill = {
			Name = "Crimson Hellfire Pillar",
			Description = "Eolka calls a crimson hellfire pillar onto the target area (20-stud radius), dealing 3.50x ATK fire damage and leaving burning ground for 3s.",
		},
	},
	hero_shurn = {
		Archetype = "Scholar",
		Basic = { Name = "Cinder Spark" },
		Special = { Name = "Arcing Hearthbolt" },
		Skill = {
			Name = "Dawnstone Convergence",
			Description = "Shurn raises his crystal-bound branch staff and calls down a radiant pillar of golden-amber light onto the target area (20-stud radius), dealing 3.50x ATK magic damage and scorching the ground for 3s.",
		},
	},
	-- Void archmage (docs/vane-hero-plan.md §3, vane-spell-animations-plan.md). Singularity Lance
	-- is an instant 36-stud beam through the target that hits every mob on the line. Event
	-- Horizon is a black hole for 4s: the 3.50x is split over 8 ticks 0.5s apart, and each tick
	-- drags mobs 1.5 studs inward (bosses and Alphas hold their ground).
	hero_vane = {
		Archetype = "Scholar",
		Basic = { Name = "Null Bolt" },
		Special = {
			Name = "Singularity Lance",
			SecondaryEffect = "BEAM_LINE",
			SecondaryParam = 36, -- beam length, studs
			BeamWidth = 4,
			BeamDamage = 0.8,
			Delivery = "AREA",
			TravelSeconds = 0, -- the beam is instant: it hits on the release frame
		},
		Skill = {
			Name = "Event Horizon",
			Description = "Vane collapses the space around the target into a miniature black hole for 4s (16-stud radius), dragging enemies inward and dealing 3.50x ATK void damage over 8 pulses.",
			Effect = "SINGULARITY",
			Radius = 16.0,
			Ticks = 8,
			TickSeconds = 0.5,
			PullStudsPerTick = 1.5,
			CoreRadius = 3,
			CastSeconds = 1.4,
			TravelSeconds = 0, -- the hole opens on the clench
		},
	},
	hero_morrigan = {
		Archetype = "Vanguard",
		Basic = { Name = "Abyssal Reap" },
		Special = { Name = "Dread Shockwave" },
		Skill = {
			Name = "Obsidian Bastion",
			Description = "Morrigan raises an obsidian bastion, taunting enemies within 25 studs for 4s and gaining an abyssal barrier equal to 40% Max HP for 6s.",
		},
	},
	hero_archon = {
		Archetype = "Striker",
		Basic = { Name = "Void Lance Strike" },
		Special = { Name = "Rift Sever" },
		Skill = {
			Name = "Dimensional Cataclysm",
			Description = "The Sovereign Archon tears open a dimensional rift around the target, dealing 3.20x ATK burst damage in a 12-stud radius.",
		},
	},
	hero_solaris = {
		Archetype = "Scholar",
		Basic = { Name = "Solar Ray" },
		Special = { Name = "Corona Arc" },
		Skill = {
			Name = "Supernova Starfall",
			Description = "Solaris collapses a miniature star onto the battlefield (20-stud radius), dealing 3.50x ATK fire damage with lingering solar flames for 3s.",
		},
	},
	hero_astrea = {
		Archetype = "Marksman",
		Basic = { Name = "Astral Arrow" },
		Special = { Name = "Nebula Piercer" },
		Skill = {
			Name = "Constellation Judgment",
			Description = "Astrea draws a constellation across the sky and fires its stars down over a 16-stud radius, dealing 2.80x ATK and shredding enemy defense by 20% for 5s.",
			CastSeconds = 1.4, -- the pirouette, the sky shot and the hand that calls the stars down
			TravelSeconds = 0.9, -- the arrow climbs and the constellation draws itself before the first stars fall
		},
	},
}

local heroProfiles: { [string]: ArchetypeSkillProfile } = {}
for heroId, kit in HERO_KITS do
	heroProfiles[heroId] = buildHeroProfile(heroId, kit)
end
ArchetypeCombatSkills.HeroProfiles = table.freeze(heroProfiles)

-- Resolves a hero-specific kit first (by HeroId / TemplateId), then falls back to an
-- archetype profile. Accepts either a HeroId or an Archetype as the first argument
-- for backward compatibility with archetype-only callers.
function ArchetypeCombatSkills.GetSkillProfile(heroIdOrArchetype: string?, fallbackArchetype: string?): ArchetypeSkillProfile
	if heroIdOrArchetype then
		local heroProfile = ArchetypeCombatSkills.HeroProfiles[heroIdOrArchetype]
		if heroProfile then
			return heroProfile
		end
		local archetypeProfile = ArchetypeCombatSkills.Profiles[heroIdOrArchetype]
		if archetypeProfile then
			return archetypeProfile
		end
	end
	if fallbackArchetype then
		return ArchetypeCombatSkills.Profiles[fallbackArchetype] or ArchetypeCombatSkills.DefaultProfile
	end
	return ArchetypeCombatSkills.DefaultProfile
end

return table.freeze(ArchetypeCombatSkills)
