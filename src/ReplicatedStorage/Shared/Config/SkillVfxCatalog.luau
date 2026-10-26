--!strict
-- ReplicatedStorage/Shared/Config/SkillVfxCatalog.luau
-- How each hero's attacks look (docs/projectile-skill-vfx-plan.md, section 6). Pure data, read by
-- CombatVfx/SkillVfx on the client. Cosmetic only: damage, targets and timing come from the
-- server's HERO_CUE. Lookup order: Heroes[heroId] -> Weapons[weaponType].

export type Palette = {
	Primary: Color3, -- trail and glow
	Secondary: Color3, -- rings, sigils, accents
	Core: Color3, -- bright centre of bursts
}

export type TierRecipe = {
	Projectile: string, -- ProjectileVfx kind: "ARROW" | "ASTRAL"
	Scale: number?, -- projectile size (1 = a bow's own arrow, slightly enlarged)
	Arc: number?, -- studs of lift at mid-flight per 10 studs of distance
	Trail: number?, -- trail lifetime, seconds
	Impact: number?, -- impact burst diameter, studs
	Count: number?, -- arrows in the volley (the centre one hits; the rest fan out)
	Spread: number?, -- fan half-angle in degrees
	Pierce: number?, -- studs the centre arrow carries on past the target
	Rings: boolean?, -- spiralling rings along the centre arrow's path
	-- Skill: a flare climbs from the bow, a sigil opens over the aim point, then arrows rain
	-- down in one wave per damage tick.
	FlareHeight: number?,
	SigilRadius: number?,
	RainPerWave: number?,
	RainHeight: number?,
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

local MARKSMAN: Recipe = {
	Palette = {
		Primary = Color3.fromRGB(255, 226, 160),
		Secondary = Color3.fromRGB(255, 196, 92),
		Core = Color3.fromRGB(255, 250, 230),
	},
	Basic = { Projectile = "ARROW", Scale = 1.0, Arc = 0.35, Trail = 0.12, Impact = 1.6 },
	Special = { Projectile = "ARROW", Scale = 1.25, Arc = 0.15, Trail = 0.18, Impact = 2.6, Count = 3, Spread = 7, Pierce = 10, Rings = true },
	Skill = { Projectile = "ARROW", Scale = 1.3, Trail = 0.2, Impact = 2.0, FlareHeight = 26, SigilRadius = 16, RainPerWave = 4, RainHeight = 30, Shake = 0.2 },
}

SkillVfxCatalog.Weapons = table.freeze({
	BOW = MARKSMAN,
} :: { [string]: Recipe })

SkillVfxCatalog.Heroes = table.freeze({
	-- Wind-Step Shot / Piercing Gale Volley / Sylphid Arrow Storm: wind cyan and emerald.
	hero_jenna = {
		Palette = {
			Primary = Color3.fromRGB(120, 235, 255),
			Secondary = Color3.fromRGB(90, 255, 170),
			Core = Color3.fromRGB(225, 255, 250),
		},
		Basic = { Projectile = "ARROW", Scale = 1.0, Arc = 0.35, Trail = 0.15, Impact = 1.8 },
		Special = { Projectile = "ARROW", Scale = 1.3, Arc = 0.12, Trail = 0.22, Impact = 2.8, Count = 3, Spread = 7, Pierce = 12, Rings = true },
		Skill = { Projectile = "ARROW", Scale = 1.3, Trail = 0.22, Impact = 2.2, FlareHeight = 28, SigilRadius = 16, RainPerWave = 4, RainHeight = 32, Shake = 0.22 },
	},
	-- Astral Arrow / Nebula Piercer / Constellation Judgment: violet and star white-gold.
	hero_astrea = {
		Palette = {
			Primary = Color3.fromRGB(190, 150, 255),
			Secondary = Color3.fromRGB(255, 225, 140),
			Core = Color3.fromRGB(255, 255, 255),
		},
		Basic = { Projectile = "ASTRAL", Scale = 1.0, Arc = 0.25, Trail = 0.18, Impact = 2.0 },
		Special = { Projectile = "ASTRAL", Scale = 1.4, Arc = 0.08, Trail = 0.3, Impact = 3.2, Count = 3, Spread = 6, Pierce = 14, Rings = true },
		Skill = { Projectile = "ASTRAL", Scale = 1.2, Trail = 0.25, Impact = 2.4, FlareHeight = 34, SigilRadius = 16, RainPerWave = 5, RainHeight = 36, Shake = 0.25 },
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
