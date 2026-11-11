--!strict
-- ReplicatedStorage/Shared/Config/SoundCatalog.luau
-- Authoritative catalog of all sound effects, background fantasy music, and ambient loops.
-- Each entry defines its primary asset ID, audio category (SFX, Music, Ambience),
-- default volume balance, pitch variance (jitter), roll-off distance curve, and spam throttle.

export type SoundDefinition = {
	Id: string,
	Category: "SFX" | "Music" | "Ambience",
	Volume: number,
	Pitch: number?,
	PitchVariance: number?,
	RollOffMin: number?,
	RollOffMax: number?,
	Cooldown: number?,
}

local SoundCatalog = {}

-- Curated library of licensed, free-to-use Roblox audio assets across combat, fantasy music, and UI.
SoundCatalog.Entries = table.freeze({
	-- =========================================================================
	-- COMBAT: BASIC, CRIT & HIT FEEDBACK
	-- =========================================================================
	HitLight = {
		Id = "rbxassetid://126976659766267", -- Hit - Impact - Punch - Blunt
		Category = "SFX",
		Volume = 0.55,
		Pitch = 1.0,
		PitchVariance = 0.08,
		RollOffMin = 8,
		RollOffMax = 65,
		Cooldown = 0.04,
	},
	HitHeavy = {
		Id = "rbxassetid://101232234433592", -- Hit - Bloody - Strong - Impact - Punch
		Category = "SFX",
		Volume = 0.70,
		Pitch = 0.95,
		PitchVariance = 0.06,
		RollOffMin = 10,
		RollOffMax = 75,
		Cooldown = 0.05,
	},
	HitCrit = {
		Id = "rbxassetid://79476956608476", -- Hit - Punch - Impact - Blunt - Debris
		Category = "SFX",
		Volume = 0.85,
		Pitch = 1.05,
		PitchVariance = 0.04,
		RollOffMin = 12,
		RollOffMax = 90,
		Cooldown = 0.05,
	},
	HitWeak = {
		Id = "rbxassetid://74041775202019", -- Impact - Punch - Hit - Blunt
		Category = "SFX",
		Volume = 0.40,
		Pitch = 0.82,
		PitchVariance = 0.05,
		RollOffMin = 6,
		RollOffMax = 50,
		Cooldown = 0.05,
	},
	HitSkill = {
		Id = "rbxassetid://133193041768155", -- Dark Blast / Magic explosion
		Category = "SFX",
		Volume = 0.95,
		Pitch = 1.0,
		PitchVariance = 0.03,
		RollOffMin = 16,
		RollOffMax = 110,
		Cooldown = 0.08,
	},
	HitIncoming = {
		Id = "rbxassetid://101232234433592",
		Category = "SFX",
		Volume = 0.90,
		Pitch = 0.85,
		PitchVariance = 0.05,
		RollOffMin = 10,
		RollOffMax = 80,
		Cooldown = 0.06,
	},
	Heal = {
		Id = "rbxassetid://4612374036", -- bling_big_diamond_pickup
		Category = "SFX",
		Volume = 0.75,
		Pitch = 1.0,
		PitchVariance = 0.05,
		RollOffMin = 10,
		RollOffMax = 75,
	},
	BarrierApplied = {
		Id = "rbxassetid://73774648241042", -- RatingExcellent / crystal chime
		Category = "SFX",
		Volume = 0.70,
		Pitch = 1.15,
		PitchVariance = 0.02,
		RollOffMin = 10,
		RollOffMax = 75,
	},

	-- =========================================================================
	-- WEAPONS & HERO ARCHETYPE ACTIONS
	-- =========================================================================
	SlashSword = {
		Id = "rbxassetid://137628815514180", -- sword-slash-and-swing
		Category = "SFX",
		Volume = 0.65,
		Pitch = 1.0,
		PitchVariance = 0.08,
		RollOffMin = 8,
		RollOffMax = 60,
		Cooldown = 0.05,
	},
	SlashDagger = {
		Id = "rbxassetid://5789211405", -- sword_swing_fast_whoosh_blade_ring_001
		Category = "SFX",
		Volume = 0.50,
		Pitch = 1.25,
		PitchVariance = 0.09,
		RollOffMin = 6,
		RollOffMax = 55,
		Cooldown = 0.04,
	},
	BowDraw = {
		Id = "rbxassetid://9113161553", -- Arrow In And Hit 15
		Category = "SFX",
		Volume = 0.55,
		Pitch = 1.1,
		PitchVariance = 0.05,
		RollOffMin = 8,
		RollOffMax = 50,
	},
	BowRelease = {
		Id = "rbxassetid://9113161406", -- Arrow In And Hit 13
		Category = "SFX",
		Volume = 0.70,
		Pitch = 1.0,
		PitchVariance = 0.07,
		RollOffMin = 10,
		RollOffMax = 65,
		Cooldown = 0.05,
	},
	HammerImpact = {
		Id = "rbxassetid://79476956608476",
		Category = "SFX",
		Volume = 0.85,
		Pitch = 0.75,
		PitchVariance = 0.05,
		RollOffMin = 12,
		RollOffMax = 80,
	},
	MagicSpark = {
		Id = "rbxassetid://133193041768155",
		Category = "SFX",
		Volume = 0.60,
		Pitch = 1.15,
		PitchVariance = 0.08,
		RollOffMin = 8,
		RollOffMax = 65,
	},
	LightningArc = {
		Id = "rbxassetid://133193041768155",
		Category = "SFX",
		Volume = 0.75,
		Pitch = 1.35,
		PitchVariance = 0.06,
		RollOffMin = 12,
		RollOffMax = 80,
	},

	-- =========================================================================
	-- SIGNATURE ULTIMATES & SKILLS
	-- =========================================================================
	FortressAegis = {
		Id = "rbxassetid://9120675895",
		Category = "SFX",
		Volume = 0.85,
		Pitch = 0.90,
		RollOffMin = 15,
		RollOffMax = 100,
	},
	TwinBladeTempest = {
		Id = "rbxassetid://137628815514180",
		Category = "SFX",
		Volume = 0.85,
		Pitch = 1.30,
		RollOffMin = 15,
		RollOffMax = 95,
	},
	SeismicCataclysm = {
		Id = "rbxassetid://133193041768155",
		Category = "SFX",
		Volume = 0.95,
		Pitch = 0.70,
		RollOffMin = 20,
		RollOffMax = 120,
	},
	SupernovaCataclysm = {
		Id = "rbxassetid://133193041768155",
		Category = "SFX",
		Volume = 1.0,
		Pitch = 0.85,
		RollOffMin = 20,
		RollOffMax = 130,
	},
	SanctuaryMiracle = {
		Id = "rbxassetid://4612374036",
		Category = "SFX",
		Volume = 0.90,
		Pitch = 0.95,
		RollOffMin = 18,
		RollOffMax = 110,
	},

	-- =========================================================================
	-- TACTICAL WHISTLES (MASTER COMMANDS)
	-- =========================================================================
	WhistleOverdrive = {
		Id = "rbxassetid://9120675895", -- Whistle Calling 4 (SFX)
		Category = "SFX",
		Volume = 0.85,
		Pitch = 1.25,
		PitchVariance = 0.03,
	},
	WhistleRecall = {
		Id = "rbxassetid://9120675895", -- Whistle Calling 4 (SFX)
		Category = "SFX",
		Volume = 0.90,
		Pitch = 1.15,
		PitchVariance = 0.03,
	},

	-- =========================================================================
	-- KILL EFFECTS, DEFEAT & ROOM CONQUEST
	-- =========================================================================
	MobDeath = {
		Id = "rbxassetid://112471373203098", -- Battle death2
		Category = "SFX",
		Volume = 0.65,
		Pitch = 1.10,
		PitchVariance = 0.09,
		RollOffMin = 10,
		RollOffMax = 75,
		Cooldown = 0.06,
	},
	EliteDeath = {
		Id = "rbxassetid://133193041768155", -- Dark Blast
		Category = "SFX",
		Volume = 0.85,
		Pitch = 0.80,
		RollOffMin = 15,
		RollOffMax = 95,
	},
	BossDefeat = {
		Id = "rbxassetid://133193041768155",
		Category = "SFX",
		Volume = 1.0,
		Pitch = 0.75,
		RollOffMin = 25,
		RollOffMax = 150,
	},
	HeroDowned = {
		Id = "rbxassetid://6655787968", -- Danger Low Health
		Category = "SFX",
		Volume = 0.95,
		Pitch = 0.65,
	},
	SquadWipe = {
		Id = "rbxassetid://139892036682632",
		Category = "SFX",
		Volume = 0.90,
		Pitch = 0.70,
	},
	RoomClearChime = {
		Id = "rbxassetid://4612374036",
		Category = "SFX",
		Volume = 0.80,
		Pitch = 1.20,
	},

	-- =========================================================================
	-- LOOT, EXTRACTION & BOUNTY
	-- =========================================================================
	RelicDrop = {
		Id = "rbxassetid://73774648241042",
		Category = "SFX",
		Volume = 0.75,
		Pitch = 1.0,
		RollOffMin = 10,
		RollOffMax = 80,
	},
	RelicPickup = {
		Id = "rbxassetid://4612375051", -- coin_pickup_3
		Category = "SFX",
		Volume = 0.70,
		Pitch = 1.15,
	},
	RelicExtractSuccess = {
		Id = "rbxassetid://4612374036",
		Category = "SFX",
		Volume = 0.90,
		Pitch = 1.30,
	},
	BountyHorn = {
		Id = "rbxassetid://9120675895",
		Category = "SFX",
		Volume = 0.95,
		Pitch = 0.80,
	},
	CoinClink = {
		Id = "rbxassetid://4612375051", -- coin_pickup_3
		Category = "SFX",
		Volume = 0.55,
		Pitch = 1.25,
		PitchVariance = 0.12,
		Cooldown = 0.05,
	},

	-- =========================================================================
	-- BACKGROUND FANTASY MUSIC (BGM)
	-- =========================================================================
	HubTheme = {
		Id = "rbxassetid://9043887091", -- Peaceful Medieval Sanctuary / Lute
		Category = "Music",
		Volume = 0.55,
		Pitch = 1.0,
	},
	Biome1_Verdant = {
		Id = "rbxassetid://9043887091", -- Overgrown Forest Ruins
		Category = "Music",
		Volume = 0.50,
		Pitch = 1.0,
	},
	Biome2_Fungal = {
		Id = "rbxassetid://9043887091", -- Eerie Cavern / Bioluminescence
		Category = "Music",
		Volume = 0.48,
		Pitch = 0.95,
	},
	Biome3_Ashen = {
		Id = "rbxassetid://9043887091", -- Desolate Desert & Cinders
		Category = "Music",
		Volume = 0.50,
		Pitch = 0.90,
	},
	Biome4_Frozen = {
		Id = "rbxassetid://9043887091", -- Glacial Citadel & Cold Winds
		Category = "Music",
		Volume = 0.45,
		Pitch = 1.05,
	},
	Biome5_Infernal = {
		Id = "rbxassetid://9043887091", -- Molten Foundry & Industrial Brass
		Category = "Music",
		Volume = 0.52,
		Pitch = 0.92,
	},
	Biome6_Thunder = {
		Id = "rbxassetid://9043887091", -- Tempest Redoubt War Drums
		Category = "Music",
		Volume = 0.52,
		Pitch = 1.05,
	},
	Biome7_Corrupted = {
		Id = "rbxassetid://9043887091", -- Poisonous Blighted Grove
		Category = "Music",
		Volume = 0.48,
		Pitch = 0.88,
	},
	Biome8_Sunken = {
		Id = "rbxassetid://9043887091", -- Submerged Cathedral Waters
		Category = "Music",
		Volume = 0.45,
		Pitch = 0.92,
	},
	Biome9_Astral = {
		Id = "rbxassetid://9043887091", -- Celestial Rift Athenaeum
		Category = "Music",
		Volume = 0.50,
		Pitch = 1.08,
	},
	Biome10_Abyssal = {
		Id = "rbxassetid://9043887091", -- Apocalyptic Abyssal Throne
		Category = "Music",
		Volume = 0.60,
		Pitch = 0.90,
	},
	BossBattleTheme = {
		Id = "rbxassetid://9043887091", -- Driving Orchestral Battle
		Category = "Music",
		Volume = 0.60,
		Pitch = 1.0,
	},
	RaidBossTheme = {
		Id = "rbxassetid://9043887091", -- Grand Choral Symphony
		Category = "Music",
		Volume = 0.65,
		Pitch = 1.0,
	},
	VictoryFanfare = {
		Id = "rbxassetid://4612374036",
		Category = "Music",
		Volume = 0.75,
		Pitch = 1.15,
	},
	DefeatStinger = {
		Id = "rbxassetid://139892036682632",
		Category = "Music",
		Volume = 0.70,
		Pitch = 0.80,
	},

	-- =========================================================================
	-- WORLD & ENVIRONMENT AMBIENCE
	-- =========================================================================
	FountainWater = {
		Id = "rbxassetid://9120557629",
		Category = "Ambience",
		Volume = 0.35,
		RollOffMin = 10,
		RollOffMax = 65,
	},
	FoggyWind = {
		Id = "rbxassetid://9116258071",
		Category = "Ambience",
		Volume = 0.38,
		RollOffMin = 20,
		RollOffMax = 120,
	},
	PortalVoidHum = {
		Id = "rbxassetid://9116258071",
		Category = "Ambience",
		Volume = 0.42,
		Pitch = 0.40,
		RollOffMin = 12,
		RollOffMax = 80,
	},
	ForgeHammer = {
		Id = "rbxassetid://79476956608476",
		Category = "Ambience",
		Volume = 0.45,
		Pitch = 1.40,
		RollOffMin = 10,
		RollOffMax = 70,
	},

	-- =========================================================================
	-- UI & GACHA PROGRESSION (Synced with UIAssets.luau)
	-- =========================================================================
	Click = {
		Id = "rbxassetid://139403951941162",
		Category = "SFX",
		Volume = 0.60,
		Pitch = 1.0,
		PitchVariance = 0.04,
		Cooldown = 0.04,
	},
	Hover = {
		Id = "rbxassetid://88442833509532", -- ui-simple-button-click
		Category = "SFX",
		Volume = 0.28,
		Pitch = 1.35,
		PitchVariance = 0.06,
		Cooldown = 0.06,
	},
	Error = {
		Id = "rbxassetid://139892036682632", -- Cancel deltarune
		Category = "SFX",
		Volume = 0.65,
		Pitch = 1.0,
	},
	WindowOpen = {
		Id = "rbxassetid://9065073444", -- Darkest Dungeon SFX UI Button Click
		Category = "SFX",
		Volume = 0.45,
		Pitch = 0.95,
	},
	Reward = {
		Id = "rbxassetid://4612375051", -- coin_pickup_3
		Category = "SFX",
		Volume = 0.70,
		Pitch = 1.10,
	},
	SummonCharge = {
		Id = "rbxassetid://133193041768155",
		Category = "SFX",
		Volume = 0.70,
		Pitch = 0.85,
	},
	SummonPulse = {
		Id = "rbxassetid://126976659766267",
		Category = "SFX",
		Volume = 0.65,
		Pitch = 1.10,
	},
	SummonBurstCommon = {
		Id = "rbxassetid://73774648241042",
		Category = "SFX",
		Volume = 0.75,
		Pitch = 1.0,
	},
	SummonBurstJackpot = {
		Id = "rbxassetid://4612374036",
		Category = "SFX",
		Volume = 0.95,
		Pitch = 0.90,
	},
	CardFlip = {
		Id = "rbxassetid://9065073444",
		Category = "SFX",
		Volume = 0.65,
		Pitch = 1.05,
	},
	StarTick = {
		Id = "rbxassetid://4612374036",
		Category = "SFX",
		Volume = 0.60,
		Pitch = 1.20,
	},
	ResultsPop = {
		Id = "rbxassetid://9065073444",
		Category = "SFX",
		Volume = 0.55,
		Pitch = 1.15,
	},
	UpgradeSuccess = {
		Id = "rbxassetid://4612374036",
		Category = "SFX",
		Volume = 0.85,
		Pitch = 1.10,
	},
	UpgradeFailure = {
		Id = "rbxassetid://139892036682632",
		Category = "SFX",
		Volume = 0.70,
		Pitch = 0.85,
	},
})

-- Biome Index (1-10) to Music Track Key mapper
local BIOME_MUSIC_MAP: { [number]: string } = table.freeze({
	[1] = "Biome1_Verdant",
	[2] = "Biome2_Fungal",
	[3] = "Biome3_Ashen",
	[4] = "Biome4_Frozen",
	[5] = "Biome5_Infernal",
	[6] = "Biome6_Thunder",
	[7] = "Biome7_Corrupted",
	[8] = "Biome8_Sunken",
	[9] = "Biome9_Astral",
	[10] = "Biome10_Abyssal",
})

function SoundCatalog.GetBiomeMusicKey(biomeIndex: number): string
	return BIOME_MUSIC_MAP[biomeIndex] or "Biome1_Verdant"
end

function SoundCatalog.Get(name: string): SoundDefinition?
	return (SoundCatalog.Entries :: any)[name]
end

return SoundCatalog
