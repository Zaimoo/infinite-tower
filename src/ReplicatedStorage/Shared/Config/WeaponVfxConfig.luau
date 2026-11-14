--!strict
-- ReplicatedStorage/Shared/Config/WeaponVfxConfig.luau
-- Authoritative VFX band mappings, rarity palettes, element themes, and budget definitions.

export type VfxBand = number

export type ElementType = "PHYSICAL" | "WIND" | "LIGHTNING" | "CRYSTAL" | "FIRE" | "CELESTIAL" | "COSMIC" | "VOID"

export type ElementStyle = {
	PrimaryColor: Color3,
	AccentColor: Color3,
	ParticleTexture: string,
	TrailTexture: string,
	Wisps: boolean,
	Sparks: boolean,
}

export type ArtifactVfxProfile = {
	Band: VfxBand,
	Element: ElementType,
	Color: Color3,
	Accent: Color3,
	LightRange: number,
	LightBrightness: number,
	MoteRate: number,
	AuraRate: number,
}

local WeaponVfxConfig = {}

-- 16 Rarity Tiers mapped to Bands (0-5)
-- Every launch tier (1-7) progresses smoothly from clean physical to pinnacle cosmic radiance.
WeaponVfxConfig.RarityBands = table.freeze({
	[1]  = 0, -- Common (Clean materials, silver attack trail)
	[2]  = 1, -- Uncommon (Tip glint sparkles, elemental swing trail)
	[3]  = 2, -- Rare (PointLight, spark motes, swing trail)
	[4]  = 3, -- Superior (PointLight, drifting motes, soft aura wisps, trail)
	[5]  = 4, -- Exalted (Radiant PointLight, energetic motes, flame/solar aura, 2-layer trail)
	[6]  = 5, -- Legendary (Brilliant PointLight, dense motes, celestial aura, wide trail)
	[7]  = 5, -- Mythical / Launch Origin (Cosmic aura, starburst motes, pinnacle radiance)
	[8]  = 5, -- Transcendent
	[9]  = 5, -- Ascendant
	[10] = 5, -- Ethereal
	[11] = 5, -- Immortal
	[12] = 5, -- Divine
	[13] = 5, -- Celestial
	[14] = 5, -- Primordial
	[15] = 5, -- Supreme
	[16] = 5, -- Origin
} :: { [number]: VfxBand })

-- Standard Rarity Hex / Color palette
WeaponVfxConfig.RarityColors = table.freeze({
	[1]  = Color3.fromHex("#B0B0B0"), -- Common
	[2]  = Color3.fromHex("#4BB543"), -- Uncommon
	[3]  = Color3.fromHex("#2980B9"), -- Rare
	[4]  = Color3.fromHex("#8E44AD"), -- Superior
	[5]  = Color3.fromHex("#D35400"), -- Exalted
	[6]  = Color3.fromHex("#F1C40F"), -- Legendary
	[7]  = Color3.fromHex("#E74C3C"), -- Mythical
	[8]  = Color3.fromHex("#1ABC9C"), -- Transcendent
	[9]  = Color3.fromHex("#E056FD"), -- Ascendant
	[10] = Color3.fromHex("#686DE0"), -- Ethereal
	[11] = Color3.fromHex("#FF7979"), -- Immortal
	[12] = Color3.fromHex("#F9CA24"), -- Divine
	[13] = Color3.fromHex("#00D2D3"), -- Celestial
	[14] = Color3.fromHex("#FF3838"), -- Primordial
	[15] = Color3.fromHex("#BADC58"), -- Supreme
	[16] = Color3.fromHex("#FF9FF3"), -- Origin
} :: { [number]: Color3 })

-- Elemental visual profiles
WeaponVfxConfig.Elements = table.freeze({
	PHYSICAL = table.freeze({
		PrimaryColor = Color3.fromRGB(220, 220, 230),
		AccentColor = Color3.fromRGB(180, 180, 190),
		ParticleTexture = "", -- Soft circle
		TrailTexture = "",
		Wisps = false,
		Sparks = false,
	}),
	WIND = table.freeze({
		PrimaryColor = Color3.fromRGB(110, 235, 160),
		AccentColor = Color3.fromRGB(180, 255, 215),
		ParticleTexture = "",
		TrailTexture = "",
		Wisps = true,
		Sparks = false,
	}),
	LIGHTNING = table.freeze({
		PrimaryColor = Color3.fromRGB(80, 205, 255),
		AccentColor = Color3.fromRGB(240, 250, 140),
		ParticleTexture = "", -- Star sparkle
		TrailTexture = "",
		Wisps = false,
		Sparks = true,
	}),
	CRYSTAL = table.freeze({
		PrimaryColor = Color3.fromRGB(185, 115, 255),
		AccentColor = Color3.fromRGB(80, 230, 255),
		ParticleTexture = "",
		TrailTexture = "",
		Wisps = false,
		Sparks = true,
	}),
	FIRE = table.freeze({
		PrimaryColor = Color3.fromRGB(255, 95, 30),
		AccentColor = Color3.fromRGB(255, 215, 60),
		ParticleTexture = "",
		TrailTexture = "",
		Wisps = true,
		Sparks = true,
	}),
	CELESTIAL = table.freeze({
		PrimaryColor = Color3.fromRGB(255, 230, 130),
		AccentColor = Color3.fromRGB(255, 255, 255),
		ParticleTexture = "",
		TrailTexture = "",
		Wisps = true,
		Sparks = true,
	}),
	COSMIC = table.freeze({
		PrimaryColor = Color3.fromRGB(240, 75, 110),
		AccentColor = Color3.fromRGB(140, 85, 255),
		ParticleTexture = "",
		TrailTexture = "",
		Wisps = true,
		Sparks = true,
	}),
	VOID = table.freeze({
		PrimaryColor = Color3.fromRGB(255, 135, 240),
		AccentColor = Color3.fromRGB(90, 230, 255),
		ParticleTexture = "",
		TrailTexture = "",
		Wisps = true,
		Sparks = false,
	}),
} :: { [ElementType]: ElementStyle })

-- Specific mapping for Bows and future weapon types
WeaponVfxConfig.ArtifactElements = table.freeze({
	-- Bows
	art_hunters_shortbow = "PHYSICAL",
	art_reinforced_longbow = "PHYSICAL",
	art_recurve_composite = "WIND",
	art_gale_force_composite = "WIND",
	art_stormstrider_longbow = "LIGHTNING",
	art_thunderhead_recurve = "LIGHTNING",
	art_crystal_greatbow = "CRYSTAL",
	art_prismatic_arbalest = "CRYSTAL",
	art_phoenix_flatbow = "FIRE",
	art_solar_flare_recurve = "FIRE",
	art_celestial_zenith = "CELESTIAL",
	art_supernova_greatbow = "COSMIC",
	art_astrea_cosmic_bow = "COSMIC",
	art_infinity_genesis_bow = "VOID",

	-- Swords & Shields (Vanguard)
	art_iron_broadsword = "PHYSICAL",
	art_tempered_bastard_sword = "PHYSICAL",
	art_runic_longsword = "WIND",
	art_knightly_estoc = "PHYSICAL",
	art_paladin_spatha = "CELESTIAL",
	art_vanguard_warden_bastion = "LIGHTNING",
	art_crystal_claymore = "CRYSTAL",
	art_resonant_bulwark = "CRYSTAL",
	art_paladin_claymore = "CELESTIAL",
	art_aegis_of_valor = "CELESTIAL",
	art_blade_of_the_rift = "COSMIC",
	art_aegis_core = "COSMIC",
	art_astral_executioner = "COSMIC",
	art_genesis_worldbreaker = "VOID",

	-- Striker Dual Daggers (Batch 3)
	art_rusty_daggers = "PHYSICAL",
	art_serrated_skewers = "PHYSICAL",
	art_viper_kris = "WIND",
	art_silent_dirks = "PHYSICAL",
	art_shadow_fangs = "VOID",
	art_phantom_stiletto = "CRYSTAL",
	art_phantom_edge = "CRYSTAL",
	art_nightstalker_katar = "LIGHTNING",
	art_bloodthirst_twinblades = "FIRE",
	art_crimson_carnage = "FIRE",
	art_eclipse_daggers = "CELESTIAL",
	art_abyssal_razor = "VOID",
	art_abyssal_ravagers = "COSMIC",
	art_void_reapers = "VOID",

	-- Berserker Axes (Batch 4)
	art_miner_pickaxe = "PHYSICAL",
	art_heavy_hewing_axe = "PHYSICAL",
	art_canyon_splitter = "CRYSTAL",
	art_quakestone_greataxe = "PHYSICAL",
	art_battleaxe_cleaver = "LIGHTNING",
	art_iron_juggernaut_cleaver = "FIRE",
	art_magma_behemoth = "FIRE",
	art_obsidian_hell_splitter = "FIRE",
	art_titan_earthshaker = "CELESTIAL",
	art_mountain_breaker = "PHYSICAL",
	art_valkyrie_waraxe = "CELESTIAL",
	art_world_shaper = "CELESTIAL",
	art_world_carver = "VOID",
	art_genesis_sunderer = "COSMIC",

	-- Scholar Staves (Batch 5)
	art_apprentice_cane = "PHYSICAL",
	art_scholars_spire = "PHYSICAL",
	art_ruby_staff = "FIRE",
	art_pyromancers_torch_rod = "FIRE",
	art_frostweaver_scepter = "CRYSTAL",
	art_glacial_monolith = "CRYSTAL",
	art_archmage_rod = "LIGHTNING",
	art_chronomancers_spindle = "LIGHTNING",
	art_infernal_pillar = "FIRE",
	art_void_channeler = "VOID",
	art_solaris_sunburst = "CELESTIAL",
	art_chronos_stave = "CELESTIAL",
	art_eye_of_singularity = "VOID",
	art_omega_archon_caduceus = "COSMIC",

	-- Healer Tomes (Batch 6)
	art_novice_tome = "PHYSICAL",
	art_acolytes_litany = "PHYSICAL",
	art_cleric_scripture = "CELESTIAL",
	art_mendicants_psalter = "CELESTIAL",
	art_hermetic_grimoire = "WIND",
	art_restorative_codex = "CRYSTAL",
	art_valeria_sanctuary = "CELESTIAL",
	art_seraphs_testament = "CELESTIAL",
	art_necronomicon_pages = "VOID",
	art_lifebinders_chronicle = "WIND",
	art_seraphic_psalms = "CELESTIAL",
	art_divine_providence = "CELESTIAL",
	art_akashic_records = "COSMIC",
	art_book_of_primordial_genesis = "VOID",
} :: { [string]: ElementType })

-- Balanced particle & lighting rates: punchy, radiant anime VFX accents with clear gameplay presence
WeaponVfxConfig.Budget = table.freeze({
	Band1 = table.freeze({ MoteRate = 2,  AuraRate = 0,  LightRange = 3.2,  LightBrightness = 0.22 }),
	Band2 = table.freeze({ MoteRate = 4,  AuraRate = 0,  LightRange = 4.2,  LightBrightness = 0.35 }),
	Band3 = table.freeze({ MoteRate = 6,  AuraRate = 6,  LightRange = 5.2,  LightBrightness = 0.48 }),
	Band4 = table.freeze({ MoteRate = 10, AuraRate = 10, LightRange = 6.2,  LightBrightness = 0.60 }),
	Band5 = table.freeze({ MoteRate = 14, AuraRate = 14, LightRange = 7.2,  LightBrightness = 0.75 }),
})

function WeaponVfxConfig.GetProfile(artifactId: string?, rarityTier: number?): ArtifactVfxProfile
	local tier = math.clamp(rarityTier or 1, 1, 16)
	local band = WeaponVfxConfig.RarityBands[tier] or 0
	local rarityColor = WeaponVfxConfig.RarityColors[tier] or Color3.fromRGB(180, 180, 180)
	local elemKey = (artifactId and WeaponVfxConfig.ArtifactElements[artifactId]) or "PHYSICAL"
	local elemStyle = WeaponVfxConfig.Elements[elemKey] or WeaponVfxConfig.Elements.PHYSICAL

	local bConfig = if band == 1 then WeaponVfxConfig.Budget.Band1
		elseif band == 2 then WeaponVfxConfig.Budget.Band2
		elseif band == 3 then WeaponVfxConfig.Budget.Band3
		elseif band == 4 then WeaponVfxConfig.Budget.Band4
		elseif band == 5 then WeaponVfxConfig.Budget.Band5
		else nil

	return {
		Band = band,
		Element = elemKey,
		Color = rarityColor,
		Accent = elemStyle.AccentColor,
		LightRange = bConfig and bConfig.LightRange or 0,
		LightBrightness = bConfig and bConfig.LightBrightness or 0,
		MoteRate = bConfig and bConfig.MoteRate or 0,
		AuraRate = bConfig and bConfig.AuraRate or 0,
	}
end

return table.freeze(WeaponVfxConfig)
