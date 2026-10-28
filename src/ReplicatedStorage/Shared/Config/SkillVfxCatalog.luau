--!strict
-- ReplicatedStorage/Shared/Config/SkillVfxCatalog.luau
-- How each hero's attacks look (docs/projectile-skill-vfx-plan.md, section 6). Pure data, read by
-- CombatVfx/SkillVfx on the client. Cosmetic only: damage, targets and timing come from the
-- server's HERO_CUE. Lookup order: Heroes[heroId] -> Weapons[weaponType].
--
-- Each tier names a Style, the SkillVfx player that draws it:
--   Basic    SHOT (bow arrow), BOLT (caster projectile), SLASH (melee arc on the target)
--   Special  VOLLEY (bow), CLEAVE (Vanguard cone), CROSS (Striker), TREMOR (Miner),
--            CHAIN (Scholar), MEND (Healer)
--   Skill    STORM (bow), BULWARK (Vanguard), TEMPEST (Striker), CRYSTALS (Miner),
--            PILLAR (Scholar), SANCTUARY (Healer)
-- The other fields are that style's knobs; a style ignores the ones it does not use.

export type Palette = {
	Primary: Color3, -- trail, glow and main strokes
	Secondary: Color3, -- rings, sigils, accents
	Core: Color3, -- bright centre of bursts
}

export type TierRecipe = {
	Style: string,
	Projectile: string?, -- ProjectileVfx kind: "ARROW" | "ASTRAL" | "BOLT" | "ORB"
	Scale: number?, -- projectile or slash size multiplier
	Arc: number?, -- studs of lift at mid-flight per 10 studs of distance
	Trail: number?, -- trail lifetime, seconds
	Impact: number?, -- impact burst diameter, studs
	-- VOLLEY
	Count: number?, -- arrows in the volley (the centre one hits; the rest fan out)
	Spread: number?, -- fan half-angle in degrees
	Pierce: number?, -- studs the centre arrow carries on past the target
	Rings: boolean?, -- rings along the centre arrow's path
	-- STORM: a flare climbs from the bow, a sigil opens, then one wave of arrows per damage tick.
	FlareHeight: number?,
	SigilRadius: number?,
	RainPerWave: number?,
	RainHeight: number?,
	-- Area styles
	Radius: number?, -- studs: cone reach, tremor, tempest, crystal field, healing circle, taunt
	Slashes: number?, -- TEMPEST: slash arcs around the target
	Spikes: number?, -- CRYSTALS / TREMOR: spikes at the centre (plus one under each hit enemy)
	PillarHeight: number?, -- PILLAR: column height, studs
	Linger: number?, -- seconds a ground effect or shell lasts after impact
	Implode: boolean?, -- TEMPEST: a dark sphere collapses before the burst (rift)
	Shake: number?, -- camera shake for the local player's own hero
}

export type Recipe = {
	Palette: Palette,
	Basic: TierRecipe,
	Special: TierRecipe,
	Skill: TierRecipe,
}

local SkillVfxCatalog = {}

-- Weapon type -> archetype, to read a hero's tick timing from ArchetypeCombatSkills.
SkillVfxCatalog.WeaponArchetype = table.freeze({
	BOW = "Marksman",
	SWORD_SHIELD = "Vanguard",
	DAGGERS = "Striker",
	AXE = "Miner",
	STAFF = "Scholar",
	TOME = "Healer",
})

-- Every Style SkillVfx knows, per tier.
SkillVfxCatalog.Styles = table.freeze({
	Basic = table.freeze({ SHOT = true, BOLT = true, SLASH = true }),
	Special = table.freeze({ VOLLEY = true, CLEAVE = true, CROSS = true, TREMOR = true, CHAIN = true, MEND = true }),
	Skill = table.freeze({ STORM = true, BULWARK = true, TEMPEST = true, CRYSTALS = true, PILLAR = true, SANCTUARY = true }),
})

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Weapon defaults: the look of a hero without its own entry. Radii match the archetype kits.
SkillVfxCatalog.Weapons = table.freeze({
	BOW = {
		Palette = { Primary = rgb(255, 226, 160), Secondary = rgb(255, 196, 92), Core = rgb(255, 250, 230) },
		Basic = { Style = "SHOT", Projectile = "ARROW", Scale = 1.0, Arc = 0.35, Trail = 0.12, Impact = 1.6 },
		Special = { Style = "VOLLEY", Projectile = "ARROW", Scale = 1.25, Arc = 0.15, Trail = 0.18, Impact = 2.6, Count = 3, Spread = 7, Pierce = 10, Rings = true },
		Skill = { Style = "STORM", Projectile = "ARROW", Scale = 1.3, Trail = 0.2, Impact = 2.0, FlareHeight = 26, SigilRadius = 16, RainPerWave = 4, RainHeight = 30, Shake = 0.2 },
	},
	SWORD_SHIELD = {
		Palette = { Primary = rgb(235, 240, 255), Secondary = rgb(255, 214, 120), Core = rgb(255, 255, 255) },
		Basic = { Style = "SLASH", Scale = 1.0, Impact = 1.6 },
		Special = { Style = "CLEAVE", Scale = 1.2, Radius = 10, Impact = 2.2 },
		Skill = { Style = "BULWARK", Radius = 25, Linger = 6, Impact = 3, Shake = 0.2 },
	},
	DAGGERS = {
		Palette = { Primary = rgb(220, 235, 255), Secondary = rgb(150, 190, 255), Core = rgb(255, 255, 255) },
		Basic = { Style = "SLASH", Scale = 0.8, Impact = 1.2 },
		Special = { Style = "CROSS", Scale = 1.0, Impact = 1.8 },
		Skill = { Style = "TEMPEST", Radius = 12, Slashes = 6, Impact = 3, Shake = 0.2 },
	},
	AXE = {
		Palette = { Primary = rgb(150, 230, 255), Secondary = rgb(120, 160, 200), Core = rgb(235, 250, 255) },
		Basic = { Style = "SLASH", Scale = 1.2, Impact = 1.8 },
		Special = { Style = "TREMOR", Radius = 8, Spikes = 3, Impact = 2.4 },
		Skill = { Style = "CRYSTALS", Radius = 18, Spikes = 5, Impact = 3, Linger = 1.2, Shake = 0.25 },
	},
	STAFF = {
		Palette = { Primary = rgb(150, 140, 255), Secondary = rgb(110, 210, 255), Core = rgb(240, 240, 255) },
		Basic = { Style = "BOLT", Projectile = "ORB", Scale = 1.0, Arc = 0.1, Trail = 0.2, Impact = 1.8 },
		Special = { Style = "CHAIN", Projectile = "ORB", Scale = 1.1, Arc = 0.05, Trail = 0.2, Impact = 2.0, Radius = 14 },
		Skill = { Style = "PILLAR", Radius = 20, PillarHeight = 40, Linger = 3, Impact = 4, Shake = 0.3 },
	},
	TOME = {
		Palette = { Primary = rgb(255, 245, 190), Secondary = rgb(120, 255, 160), Core = rgb(255, 255, 240) },
		Basic = { Style = "BOLT", Projectile = "BOLT", Scale = 1.0, Arc = 0.15, Trail = 0.18, Impact = 1.6 },
		Special = { Style = "MEND", Projectile = "BOLT", Scale = 1.1, Arc = 0.1, Trail = 0.2, Impact = 2.0 },
		Skill = { Style = "SANCTUARY", Radius = 25, PillarHeight = 14, Linger = 1.2, Impact = 3 },
	},
} :: { [string]: Recipe })

SkillVfxCatalog.Heroes = table.freeze({
	-- Marksman ---------------------------------------------------------------------------------
	-- Wind-Step Shot / Piercing Gale Volley / Sylphid Arrow Storm: wind cyan and emerald.
	hero_jenna = {
		Palette = { Primary = rgb(120, 235, 255), Secondary = rgb(90, 255, 170), Core = rgb(225, 255, 250) },
		Basic = { Style = "SHOT", Projectile = "ARROW", Scale = 1.0, Arc = 0.35, Trail = 0.15, Impact = 1.8 },
		Special = { Style = "VOLLEY", Projectile = "ARROW", Scale = 1.3, Arc = 0.12, Trail = 0.22, Impact = 2.8, Count = 3, Spread = 7, Pierce = 12, Rings = true },
		Skill = { Style = "STORM", Projectile = "ARROW", Scale = 1.3, Trail = 0.22, Impact = 2.2, FlareHeight = 28, SigilRadius = 16, RainPerWave = 4, RainHeight = 32, Shake = 0.22 },
	},
	-- Astral Arrow / Nebula Piercer / Constellation Judgment: violet and star white-gold.
	hero_astrea = {
		Palette = { Primary = rgb(190, 150, 255), Secondary = rgb(255, 225, 140), Core = rgb(255, 255, 255) },
		Basic = { Style = "SHOT", Projectile = "ASTRAL", Scale = 1.0, Arc = 0.25, Trail = 0.18, Impact = 2.0 },
		Special = { Style = "VOLLEY", Projectile = "ASTRAL", Scale = 1.4, Arc = 0.08, Trail = 0.3, Impact = 3.2, Count = 3, Spread = 6, Pierce = 14, Rings = true },
		Skill = { Style = "STORM", Projectile = "ASTRAL", Scale = 1.2, Trail = 0.25, Impact = 2.4, FlareHeight = 34, SigilRadius = 16, RainPerWave = 5, RainHeight = 36, Shake = 0.25 },
	},

	-- Vanguard ---------------------------------------------------------------------------------
	-- Bastion Strike / Aegis Shield Bash / Fortress Bulwark: steel white and gold.
	hero_aaron = {
		Palette = { Primary = rgb(235, 240, 255), Secondary = rgb(255, 210, 110), Core = rgb(255, 255, 255) },
		Basic = { Style = "SLASH", Scale = 1.0, Impact = 1.6 },
		Special = { Style = "CLEAVE", Scale = 1.2, Radius = 10, Impact = 2.4 },
		Skill = { Style = "BULWARK", Radius = 25, Linger = 6, Impact = 3, Shake = 0.2 },
	},
	-- Molten Cleave / Magma Breaker / Infernal Juggernaut: molten orange and ember red.
	hero_ignis = {
		Palette = { Primary = rgb(255, 140, 40), Secondary = rgb(255, 70, 30), Core = rgb(255, 230, 150) },
		Basic = { Style = "SLASH", Scale = 1.1, Impact = 1.8 },
		Special = { Style = "CLEAVE", Scale = 1.3, Radius = 10, Impact = 2.6 },
		Skill = { Style = "BULWARK", Radius = 25, Linger = 6, Impact = 3.4, Shake = 0.3 },
	},
	-- Abyssal Reap / Dread Shockwave / Obsidian Bastion: abyssal violet and black glass.
	hero_morrigan = {
		Palette = { Primary = rgb(150, 80, 220), Secondary = rgb(40, 20, 60), Core = rgb(220, 180, 255) },
		Basic = { Style = "SLASH", Scale = 1.1, Impact = 1.6 },
		Special = { Style = "CLEAVE", Scale = 1.3, Radius = 10, Impact = 2.4 },
		Skill = { Style = "BULWARK", Radius = 25, Linger = 6, Impact = 3.2, Shake = 0.25 },
	},

	-- Striker ----------------------------------------------------------------------------------
	-- Gale Slash / Crescent Cross-Cut / Relentless Blade Flurry: pale wind green and white.
	hero_han = {
		Palette = { Primary = rgb(200, 255, 220), Secondary = rgb(120, 230, 170), Core = rgb(255, 255, 255) },
		Basic = { Style = "SLASH", Scale = 0.8, Impact = 1.2 },
		Special = { Style = "CROSS", Scale = 1.0, Impact = 1.8 },
		Skill = { Style = "TEMPEST", Radius = 12, Slashes = 6, Impact = 3, Shake = 0.2 },
	},
	-- Twin Fang Cut / Shadow Rend / Phantom Lotus Execution: shadow purple and lotus pink.
	hero_velkist = {
		Palette = { Primary = rgb(190, 110, 255), Secondary = rgb(255, 120, 200), Core = rgb(255, 220, 245) },
		Basic = { Style = "SLASH", Scale = 0.8, Impact = 1.2 },
		Special = { Style = "CROSS", Scale = 1.2, Impact = 2.0 },
		Skill = { Style = "TEMPEST", Radius = 12, Slashes = 8, Impact = 3.2, Shake = 0.22 },
	},
	-- Void Lance Strike / Rift Sever / Dimensional Cataclysm: void indigo and rift cyan.
	hero_archon = {
		Palette = { Primary = rgb(90, 220, 255), Secondary = rgb(60, 30, 140), Core = rgb(230, 250, 255) },
		Basic = { Style = "SLASH", Scale = 0.9, Impact = 1.4 },
		Special = { Style = "CROSS", Scale = 1.3, Impact = 2.2 },
		Skill = { Style = "TEMPEST", Radius = 12, Slashes = 6, Impact = 4, Implode = true, Shake = 0.3 },
	},

	-- Miner ------------------------------------------------------------------------------------
	-- Pickaxe Cleave / Resonance Tremor / Crystalline Excavation: crystal cyan and stone.
	hero_catio = {
		Palette = { Primary = rgb(130, 235, 255), Secondary = rgb(150, 140, 120), Core = rgb(230, 255, 255) },
		Basic = { Style = "SLASH", Scale = 1.2, Impact = 1.8 },
		Special = { Style = "TREMOR", Radius = 8, Spikes = 3, Impact = 2.4 },
		Skill = { Style = "CRYSTALS", Radius = 18, Spikes = 6, Impact = 3, Linger = 1.4, Shake = 0.25 },
	},

	-- Scholar ----------------------------------------------------------------------------------
	-- Ruby Firebolt / Wildfire Chain / Crimson Hellfire Pillar: crimson and flame orange.
	hero_eolka = {
		Palette = { Primary = rgb(255, 60, 60), Secondary = rgb(255, 150, 40), Core = rgb(255, 225, 180) },
		Basic = { Style = "BOLT", Projectile = "ORB", Scale = 1.0, Arc = 0.1, Trail = 0.22, Impact = 2.0 },
		Special = { Style = "CHAIN", Projectile = "ORB", Scale = 1.15, Arc = 0.05, Trail = 0.22, Impact = 2.2, Radius = 14 },
		Skill = { Style = "PILLAR", Radius = 20, PillarHeight = 45, Linger = 3, Impact = 4.5, Shake = 0.3 },
	},
	-- Solar Ray / Corona Arc / Supernova Starfall: solar gold and white-hot.
	hero_solaris = {
		Palette = { Primary = rgb(255, 210, 70), Secondary = rgb(255, 130, 40), Core = rgb(255, 255, 230) },
		Basic = { Style = "BOLT", Projectile = "BOLT", Scale = 1.1, Arc = 0.05, Trail = 0.25, Impact = 2.0 },
		Special = { Style = "CHAIN", Projectile = "ORB", Scale = 1.2, Arc = 0.05, Trail = 0.25, Impact = 2.4, Radius = 14 },
		Skill = { Style = "PILLAR", Radius = 20, PillarHeight = 60, Linger = 3, Impact = 6, Shake = 0.35 },
	},

	-- Healer -----------------------------------------------------------------------------------
	-- Emerald Bolt / Verdant Mend / Sanctuary Miracle: emerald and soft gold.
	hero_valeria = {
		Palette = { Primary = rgb(90, 255, 150), Secondary = rgb(255, 235, 150), Core = rgb(235, 255, 240) },
		Basic = { Style = "BOLT", Projectile = "BOLT", Scale = 1.0, Arc = 0.15, Trail = 0.2, Impact = 1.6 },
		Special = { Style = "MEND", Projectile = "BOLT", Scale = 1.1, Arc = 0.1, Trail = 0.22, Impact = 2.0 },
		Skill = { Style = "SANCTUARY", Radius = 25, PillarHeight = 16, Linger = 1.4, Impact = 3 },
	},
} :: { [string]: Recipe })

local TIER_KEYS = table.freeze({ BASIC = "Basic", SPECIAL = "Special", SKILL = "Skill" })

-- The recipe and palette for a hero's tier, or nil when neither the hero nor its weapon has one.
function SkillVfxCatalog.Get(heroId: string?, weaponType: string?, tier: string): (TierRecipe?, Palette?)
	local recipe: Recipe? = (heroId and SkillVfxCatalog.Heroes[heroId]) or (weaponType and SkillVfxCatalog.Weapons[weaponType]) or nil
	local key = TIER_KEYS[tier]
	if not recipe or not key then
		return nil, nil
	end
	return (recipe :: any)[key], recipe.Palette
end

return table.freeze(SkillVfxCatalog)
