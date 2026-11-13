--!strict
-- ReplicatedStorage/Shared/Config/SkillVfxCatalog.luau
-- How each hero's attacks look (docs/projectile-skill-vfx-plan.md, section 6). Pure data, read by
-- CombatVfx/SkillVfx on the client. Cosmetic only: damage, targets and timing come from the
-- server's HERO_CUE. Lookup order: Heroes[heroId] -> Weapons[weaponType].
--
-- Each tier names a Style, the SkillVfx player that draws it:
--   Basic    SHOT (bow arrow), BOLT (caster projectile), SLASH (melee arc on the target)
--   Special  VOLLEY (bow), CLEAVE (Vanguard cone), CROSS (Striker), TREMOR (Berserker),
--            CHAIN (Scholar), MEND (Healer), PLUNGE (two falling stabs; Han),
--            BEAM (an instant straight laser from the attacker through the target; Vane),
--            PIERCER (one heavy bolt that punches through and leaves a fading ribbon; Astrea),
--            WHIRL (crescents sweeping a full circle round the attacker, one per damage tick; Rhyman)
--   Skill    STORM (bow), BULWARK (Vanguard), TEMPEST (Striker), CRYSTALS (Berserker),
--            PILLAR (Scholar), SANCTUARY (Healer), WAKE (a dash streak and a lingering circle of
--            slashes, one wave per damage tick; Han), SINGULARITY (a black hole on the aim point
--            that pulses on every damage tick and collapses on the last; Vane),
--            CONSTELLATION (a constellation draws itself over the aim point, then its stars
--            fall as bolts, one wave per damage tick; Astrea), EXECUTE (one tall vertical cut
--            through the target, a blade of light from above and a fissure past it; Rhyman)
-- The other fields are that style's knobs; a style ignores the ones it does not use.
-- A hero's attack clip may carry a Charge marker (HeroClips) before Release; at it SkillVfx
-- plays the style's wind-up, if it has one (BOLT: a glyph in the casting hand, Origin LEFT_HAND;
-- BEAM: energy gathering on the staff tip; SINGULARITY: the floor dimming and drawing inward;
-- PIERCER: starlight drawn into the nocked arrow; CONSTELLATION: crescents of light round the
-- spinning archer; WHIRL: dust drawn in round his feet; EXECUTE: the target marked from above).

export type Palette = {
	Primary: Color3, -- trail, glow and main strokes
	Secondary: Color3, -- rings, sigils, accents
	Core: Color3, -- bright centre of bursts
	Accent: Color3?, -- optional fourth colour: small highlights (Vane's gold), or what a nebula cools to (Astrea)
}

export type TierRecipe = {
	Style: string,
	Projectile: string?, -- ProjectileVfx kind: "ARROW" | "ASTRAL" | "BOLT" | "ORB" | "VOID" | "STARBOLT"
	-- Where it leaves the hero: "CHEST" (default: the bow's nock at release, else the chest) |
	-- "LEFT_HAND" | "STAFF_TIP" | "NOCK" (the bow's nock, followed live while a charge plays)
	Origin: string?,
	ImpactStyle: string?, -- projectile impact: "BURST" (default) | "IMPLODE" (collapses inward, then flashes)
	Scale: number?, -- projectile or slash size multiplier
	Arc: number?, -- studs of lift at mid-flight per 10 studs of distance
	Trail: number?, -- trail lifetime, seconds
	Impact: number?, -- impact burst diameter, studs
	-- VOLLEY
	Count: number?, -- arrows in the volley (the centre one hits; the rest fan out)
	Spread: number?, -- fan half-angle in degrees
	Pierce: number?, -- studs the centre arrow carries on past the target
	Rings: boolean?, -- rings along the centre arrow's path
	-- RICOCHET: bounce arrows from the target to the enemies the hit carried on to (Radius: how
	-- far around the target to look for them).
	Bounces: number?,
	-- TWIN: where along the flight the arrow splits (0..1).
	Split: number?,
	-- STORM: a flare climbs from the bow, a sigil opens, then one wave of arrows per damage tick.
	FlareHeight: number?,
	SigilRadius: number?,
	RainPerWave: number?,
	RainHeight: number?, -- CONSTELLATION: how high over the aim point the figure hangs
	-- Area styles
	Radius: number?, -- studs: cone reach, tremor, tempest, crystal field, healing circle, taunt
	Slashes: number?, -- TEMPEST: slash arcs around the target. WAKE: slash arcs per wave
	Spikes: number?, -- CRYSTALS / TREMOR: spikes at the centre (plus one under each hit enemy)
	PillarHeight: number?, -- PILLAR: column height, studs
	Linger: number?, -- seconds a ground effect or shell lasts after impact (PIERCER: the ribbon's fade)
	Implode: boolean?, -- TEMPEST: a dark sphere collapses before the burst (rift)
	-- BEAM: must match the kit's BEAM_LINE (SecondaryParam, BeamWidth).
	Length: number?, -- studs from the attacker's feet
	Width: number?, -- studs across (PIERCER: the ribbon's width when fresh)
	-- SINGULARITY
	Core: number?, -- event sphere diameter, studs
	Tether: boolean?, -- a flickering line from the caster's left hand to the hole while it forms
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
	AXE = "Berserker",
	STAFF = "Scholar",
	TOME = "Healer",
})

-- Every Style SkillVfx knows, per tier.
SkillVfxCatalog.Styles = table.freeze({
	Basic = table.freeze({ GILT_CUT = true, SHOT = true, BOLT = true, SLASH = true }),
	Special = table.freeze({ MIRROR_STEP = true, RICOCHET = true, VOLLEY = true, CLEAVE = true, CROSS = true, TREMOR = true, CHAIN = true, MEND = true, PLUNGE = true, BEAM = true, PIERCER = true, WHIRL = true }),
	Skill = table.freeze({ SHATTERDANCE = true, TWIN = true, STORM = true, BULWARK = true, TEMPEST = true, CRYSTALS = true, PILLAR = true, SANCTUARY = true, WAKE = true, SINGULARITY = true, CONSTELLATION = true, EXECUTE = true }),
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
		Basic = { Style = "BOLT", Projectile = "ORB", Scale = 1.0, Arc = 0.15, Trail = 0.18, Impact = 1.6 },
		Special = { Style = "MEND", Projectile = "ORB", Scale = 1.1, Arc = 0.1, Trail = 0.2, Impact = 2.0 },
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
	-- Leafwind Arrow / Thornbriar Volley / Canopy's Wrath: forest green and silver, pale leaf core.
	hero_aeli = {
		Palette = { Primary = rgb(120, 220, 120), Secondary = rgb(200, 210, 215), Core = rgb(225, 255, 220) },
		Basic = { Style = "SHOT", Projectile = "ARROW", Scale = 1.0, Arc = 0.3, Trail = 0.16, Impact = 1.8 },
		Special = { Style = "VOLLEY", Projectile = "ARROW", Scale = 1.25, Arc = 0.12, Trail = 0.22, Impact = 2.6, Count = 3, Spread = 7, Pierce = 12, Rings = true },
		Skill = { Style = "STORM", Projectile = "ARROW", Scale = 1.25, Trail = 0.22, Impact = 2.2, FlareHeight = 28, SigilRadius = 16, RainPerWave = 4, RainHeight = 32, Shake = 0.22 },
	},
	-- Astral Arrow / Nebula Piercer / Constellation Judgment: violet and star white-gold, cooling
	-- to deep nebula indigo. Nebula Piercer is one star-bolt charged on the string that leaves a
	-- fading ribbon; Constellation Judgment draws the Archer (VfxMath.ARCHER) over the target and
	-- drops its sixteen stars as bolts.
	hero_astrea = {
		Palette = { Primary = rgb(190, 150, 255), Secondary = rgb(255, 225, 140), Core = rgb(255, 255, 255), Accent = rgb(84, 52, 190) },
		Basic = { Style = "SHOT", Projectile = "ASTRAL", Scale = 1.0, Arc = 0.25, Trail = 0.18, Impact = 2.0 },
		Special = { Style = "PIERCER", Projectile = "STARBOLT", Origin = "NOCK", Scale = 1.3, Arc = 0, Trail = 0.3, Impact = 3.4, Pierce = 14, Rings = true, Width = 1.2, Linger = 0.75, Shake = 0.1 },
		Skill = { Style = "CONSTELLATION", Projectile = "STARBOLT", Origin = "NOCK", Scale = 0.9, Trail = 0.22, Impact = 2.6, Radius = 16, FlareHeight = 30, RainHeight = 20, Shake = 0.28 },
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
	-- Gloam Cut / Nightfall Fangs / Abyssal Wake: smoky black and cold blue.
	hero_han = {
		Palette = { Primary = rgb(70, 140, 255), Secondary = rgb(22, 24, 34), Core = rgb(170, 215, 255) },
		Basic = { Style = "SLASH", Scale = 0.9, Impact = 1.3 },
		Special = { Style = "PLUNGE", Scale = 1.15, Radius = 4, Impact = 2.2 },
		Skill = { Style = "WAKE", Radius = 12, Slashes = 5, Linger = 0.35, Impact = 3.4, Shake = 0.3 },
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

	-- Ravenclaw Cut / Umbral Crosscut / Midnight Requiem: amber steel on smoky black.
	hero_edis = {
		Palette = { Primary = rgb(255, 176, 86), Secondary = rgb(48, 40, 56), Core = rgb(255, 238, 205) },
		Basic = { Style = "SLASH", Scale = 0.9, Impact = 1.3 },
		Special = { Style = "CROSS", Scale = 1.25, Impact = 2.1 },
		Skill = { Style = "TEMPEST", Radius = 12, Slashes = 10, Impact = 3.6, Shake = 0.28 },
	},

	-- Berserker ------------------------------------------------------------------------------------
	-- Ironvein Chop / Bedrock Sundering / Tunnelbreaker Fault: brass gold and slate stone.
	hero_gide = {
		Palette = { Primary = rgb(215, 175, 95), Secondary = rgb(115, 110, 102), Core = rgb(255, 235, 190) },
		Basic = { Style = "SLASH", Scale = 1.2, Impact = 1.8 },
		Special = { Style = "TREMOR", Radius = 8, Spikes = 3, Impact = 2.4 },
		Skill = { Style = "CRYSTALS", Radius = 18, Spikes = 6, Impact = 3, Linger = 1.4, Shake = 0.25 },
	},
	-- Warbrand Cleave / Reaver's Whirl / Headsman's Verdict: blood crimson on dark maroon, a
	-- pale steel core and a dull gold accent. Reaver's Whirl sweeps crescents a full circle round
	-- him (Radius = the kit's WHIRLWIND reach); Headsman's Verdict is one tall vertical cut.
	hero_rhyman = {
		Palette = { Primary = rgb(214, 52, 64), Secondary = rgb(96, 26, 38), Core = rgb(255, 232, 214), Accent = rgb(226, 178, 92) },
		Basic = { Style = "SLASH", Scale = 1.3, Impact = 1.9 },
		Special = { Style = "WHIRL", Radius = 9, Scale = 1.0, Impact = 2.2, Shake = 0.12 },
		Skill = { Style = "EXECUTE", Radius = 4, Scale = 1.0, PillarHeight = 16, Impact = 4.5, Linger = 0.9, Shake = 0.4 },
	},
	-- Riftsteel Cleave / Resonance Tremor / Crystalline Excavation: crystal cyan and stone.
	hero_catio = {
		Palette = { Primary = rgb(130, 235, 255), Secondary = rgb(150, 140, 120), Core = rgb(230, 255, 255) },
		Basic = { Style = "SLASH", Scale = 1.2, Impact = 1.8 },
		Special = { Style = "TREMOR", Radius = 8, Spikes = 3, Impact = 2.4 },
		Skill = { Style = "CRYSTALS", Radius = 18, Spikes = 6, Impact = 3, Linger = 1.4, Shake = 0.25 },
	},

	-- Scholar ----------------------------------------------------------------------------------
	-- Cinder Spark / Arcing Hearthbolt / Dawnstone Convergence: warm amber-gold and hearthstone glow.
	hero_shurn = {
		Palette = { Primary = rgb(255, 195, 95), Secondary = rgb(215, 130, 55), Core = rgb(255, 245, 215) },
		Basic = { Style = "BOLT", Projectile = "ORB", Scale = 0.95, Arc = 0.1, Trail = 0.2, Impact = 1.8 },
		Special = { Style = "CHAIN", Projectile = "ORB", Scale = 1.1, Arc = 0.05, Trail = 0.2, Impact = 2.1, Radius = 14 },
		Skill = { Style = "PILLAR", Radius = 20, PillarHeight = 42, Linger = 3, Impact = 4.2, Shake = 0.28 },
	},
	-- Null Bolt / Singularity Lance / Event Horizon: void violet on black, white-violet core, gold
	-- accent (docs/vane-spell-animations-plan.md). Null Bolt is flicked from the left hand and
	-- swallows its hit; Singularity Lance is a straight laser off the staff tip; Event Horizon
	-- is a black hole that pulses with every tick and collapses on the last.
	hero_vane = {
		Palette = { Primary = rgb(170, 80, 255), Secondary = rgb(30, 16, 44), Core = rgb(240, 220, 255), Accent = rgb(225, 180, 90) },
		Basic = { Style = "BOLT", Projectile = "VOID", Origin = "LEFT_HAND", ImpactStyle = "IMPLODE", Scale = 0.9, Arc = 0, Trail = 0.18, Impact = 1.9 },
		Special = { Style = "BEAM", Origin = "STAFF_TIP", Length = 36, Width = 4, Impact = 2.2, Linger = 0.3, Shake = 0.12 },
		Skill = { Style = "SINGULARITY", Radius = 16, Core = 2.6, Impact = 5, Linger = 0.4, Shake = 0.3, Tether = true },
	},
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
		Basic = { Style = "BOLT", Projectile = "ORB", Scale = 1.0, Arc = 0.15, Trail = 0.2, Impact = 1.6 },
		Special = { Style = "MEND", Projectile = "ORB", Scale = 1.1, Arc = 0.1, Trail = 0.22, Impact = 2.0 },
		Skill = { Style = "SANCTUARY", Radius = 25, PillarHeight = 16, Linger = 1.4, Impact = 3 },
	},
	-- Runeward Bolt / Compass Mend / Vitality Covenant: sage-emerald rune light and compass gold.
	hero_diran = {
		Palette = { Primary = rgb(110, 235, 165), Secondary = rgb(245, 210, 115), Core = rgb(245, 255, 235) },
		Basic = { Style = "BOLT", Projectile = "ORB", Scale = 1.05, Arc = 0.14, Trail = 0.2, Impact = 1.8 },
		Special = { Style = "MEND", Projectile = "ORB", Scale = 1.15, Arc = 0.1, Trail = 0.22, Impact = 2.1 },
		Skill = { Style = "SANCTUARY", Radius = 25, PillarHeight = 18, Linger = 1.5, Impact = 3.2 },
	},

	-- The Gilded Mirror (docs/gilded-mirror-plan.md §6.2): gilt and glass over each hero's rarity colour.
	-- Glint Shot / Ricochet / Twin Reflection, from her reference art: glowing crimson arrows with long,
	-- laser-like trails and gilt sparks. Ricochet glints off the target and bounces on to the next
	-- enemy; Twin Reflection's held draw glows, then the arrow shatters through a gilt mirror
	-- mid-flight into two halves, one per target.
	hero_isabelle = {
		Palette = { Primary = rgb(255, 46, 84), Secondary = rgb(212, 175, 90), Core = rgb(255, 222, 228), Accent = rgb(150, 14, 40) },
		Basic = { Style = "SHOT", Projectile = "ARROW", Scale = 1.0, Arc = 0.12, Trail = 0.3, Impact = 1.8 },
		Special = { Style = "RICOCHET", Projectile = "ARROW", Scale = 1.4, Arc = 0.1, Trail = 0.4, Impact = 3.0, Bounces = 1, Radius = 14 },
		Skill = { Style = "TWIN", Projectile = "ARROW", Origin = "NOCK", Scale = 1.6, Arc = 0.05, Trail = 0.45, Impact = 3.6, Split = 0.42, Radius = 16, Shake = 0.3 },
	},
	-- Gilt Cut: an X of teal and gilt crescents. Mirror Step: a glass afterimage where she stood, a
	-- streak to behind the target and a lance-bright stab through it. Shatterdance: five glass
	-- clones of Nyx stand before mirror panes around the target; each in turn lunges in, slashes
	-- and shatters, then a shockwave over the skill's radius.
	hero_nyx = {
		Palette = { Primary = rgb(40, 226, 196), Secondary = rgb(212, 175, 90), Core = rgb(235, 255, 250), Accent = rgb(12, 110, 104) },
		Basic = { Style = "GILT_CUT", Scale = 0.9, Impact = 1.6 },
		Special = { Style = "MIRROR_STEP", Impact = 2.6, Shake = 0.15 },
		Skill = { Style = "SHATTERDANCE", Radius = 12, Impact = 3.4, Shake = 0.25 },
	},
	-- Gilt Edge / Polished Bash / Looking-Glass Bulwark: pearl white and gilt; the wall glows pink-violet.
	hero_caspian = {
		Palette = { Primary = rgb(236, 232, 255), Secondary = rgb(224, 96, 253), Core = rgb(255, 255, 255), Accent = rgb(212, 175, 90) },
		Basic = { Style = "SLASH", Scale = 1.0, Impact = 1.6 },
		Special = { Style = "CLEAVE", Scale = 1.2, Radius = 10, Impact = 2.4 },
		Skill = { Style = "BULWARK", Radius = 25, Linger = 6, Impact = 3.2, Shake = 0.2 },
	},
	-- Shard Bolt / Refraction / Hall of Mirrors: indigo glass; the prism chains to three shards and the
	-- Skill raises a ring of mirror crystals that stays for its pulses.
	hero_seraphine = {
		Palette = { Primary = rgb(120, 125, 240), Secondary = rgb(190, 215, 255), Core = rgb(245, 245, 255), Accent = rgb(212, 175, 90) },
		Basic = { Style = "BOLT", Projectile = "ORB", Scale = 0.9, Arc = 0.05, Trail = 0.18, Impact = 1.8 },
		Special = { Style = "CHAIN", Projectile = "ORB", Scale = 1.25, Arc = 0.05, Trail = 0.22, Impact = 2.4, Radius = 14 },
		Skill = { Style = "CRYSTALS", Radius = 16, Spikes = 4, Impact = 3.4, Linger = 4, Shake = 0.22 },
	},
	-- Gilt Cleave / Last Stand / Gilded Frenzy: rose and gold; the slam bursts into gold shards.
	hero_rourke = {
		Palette = { Primary = rgb(255, 130, 150), Secondary = rgb(212, 175, 90), Core = rgb(255, 240, 220), Accent = rgb(255, 214, 120) },
		Basic = { Style = "SLASH", Scale = 1.3, Impact = 2.0 },
		Special = { Style = "TREMOR", Radius = 8, Spikes = 4, Impact = 2.8, Shake = 0.15 },
		Skill = { Style = "CRYSTALS", Radius = 18, Spikes = 7, Impact = 3.4, Linger = 1.2, Shake = 0.35 },
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
