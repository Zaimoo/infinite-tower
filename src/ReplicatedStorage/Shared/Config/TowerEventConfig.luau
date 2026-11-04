--!strict
-- Timed tower events (Phase G). Every server runs the same cycle: CalmSeconds of calm, a
-- WarningSeconds warning, then ActiveSeconds of one event. TowerEventService picks the event and
-- publishes it as ReplicatedStorage attributes; the HUD reads this table for names, icons and text.
--
-- Scope "TOWER" applies to every floor from MinFloor; "BIOME" applies only to the featured biome
-- (picked from biomes players in the server have unlocked). Difficulty events never touch floors 1-5.
-- Mods are stamped on each mob when it spawns, so a mob keeps its event's stats and rewards until it
-- dies, even after the event ends.

export type Mods = {
	HP: number?, -- MaxHP multiplier
	ATK: number?, -- ATK multiplier
	ForceAffix: boolean?, -- every camp Elite emerges affixed (Phase F)
	AllCampsElite: boolean?, -- every live camp is Elite-led
	RespawnSeconds: number?, -- camp respawn delay instead of the usual 10 s
	KillMult: number?, -- kill progress multiplier
	GoldMult: number?,
	DropMult: number?, -- relic drop chance multiplier
	CoreMult: number?, -- Abyssal Core share multiplier (Elites)
	HeartMult: number?, -- Calamity Heart share multiplier (Alphas, Biome Bosses)
	GeodeUpgrade: number?, -- chance a Mana Geode drop becomes a Cursed Urn
	UrnUpgrade: number?, -- chance an Elite's Cursed Urn drop becomes an Abyssal Core
	RelicRain: boolean?, -- relic meteors land on the featured biome's floors
}

export type Event = {
	Id: string,
	DisplayName: string,
	Icon: string, -- GrimoireIcons drawing
	Accent: Color3,
	Scope: "TOWER" | "BIOME",
	MinFloor: number,
	Weight: number,
	Description: string,
	MobEffects: { string },
	RewardEffects: { string },
	Mods: Mods,
}

local Config = {}

Config.CalmSeconds = 900
Config.WarningSeconds = 60
Config.ActiveSeconds = 300
Config.RelicRainSeconds = 30 -- one meteor per featured floor in play, this often
Config.MeteorWarningSeconds = 3

Config.Events = table.freeze({
	table.freeze({
		Id = "CALAMITY_HOUR",
		DisplayName = "Calamity Hour",
		Icon = "EventCalamity",
		Accent = Color3.fromRGB(150, 16, 30),
		Scope = "TOWER",
		MinFloor = 6,
		Weight = 3,
		Description = "The tower stirs. Monsters grow fiercer, and relics answer the bold.",
		MobEffects = { "Monsters: +60% HP, +35% ATK (floor 6+)", "Every Elite emerges affixed" },
		RewardEffects = { "Relic drop chance x2", "Better relic tiers" },
		Mods = { HP = 1.6, ATK = 1.35, ForceAffix = true, DropMult = 2, GeodeUpgrade = 0.3, UrnUpgrade = 0.15 },
	}),
	table.freeze({
		Id = "ELITE_TIDE",
		DisplayName = "Elite Tide",
		Icon = "EventEliteTide",
		Accent = Color3.fromRGB(196, 120, 24),
		Scope = "BIOME",
		MinFloor = 6,
		Weight = 2,
		Description = "Champions answer the call. Every camp marches under an Elite.",
		MobEffects = { "Every camp is Elite-led" },
		RewardEffects = { "Abyssal Core chance x1.5" },
		Mods = { AllCampsElite = true, CoreMult = 1.5 },
	}),
	table.freeze({
		Id = "RELIC_RAIN",
		DisplayName = "Relic Rain",
		Icon = "EventRelicRain",
		Accent = Color3.fromRGB(96, 34, 170),
		Scope = "BIOME",
		MinFloor = 1,
		Weight = 2,
		Description = "Shards of the old world fall from the vaults. Claim them before rivals do.",
		MobEffects = {},
		RewardEffects = { "A relic meteor lands every 30 s", "Contested: carry and bank to keep it" },
		Mods = { RelicRain = true },
	}),
	table.freeze({
		Id = "SWARM",
		DisplayName = "Swarm",
		Icon = "EventSwarm",
		Accent = Color3.fromRGB(220, 60, 20),
		Scope = "TOWER",
		MinFloor = 6,
		Weight = 2,
		Description = "The nests overflow. Camps return faster than ever.",
		MobEffects = { "Camps respawn in 4 s (floor 6+)" },
		RewardEffects = { "Kill progress x1.5" },
		Mods = { RespawnSeconds = 4, KillMult = 1.5 },
	}),
	table.freeze({
		Id = "GOLDEN_TIDE",
		DisplayName = "Golden Tide",
		Icon = "EventGoldenTide",
		Accent = Color3.fromRGB(255, 226, 120),
		Scope = "TOWER",
		MinFloor = 1,
		Weight = 2,
		Description = "The vaults spill over. Every kill rings with coin.",
		MobEffects = {},
		RewardEffects = { "Gold x2", "Market bonus still applies" },
		Mods = { GoldMult = 2 },
	}),
	table.freeze({
		Id = "ALPHA_HUNT",
		DisplayName = "Alpha Hunt",
		Icon = "EventAlphaHunt",
		Accent = Color3.fromRGB(20, 140, 200),
		Scope = "BIOME",
		MinFloor = 1,
		Weight = 2,
		Description = "The Alphas are restless. Their hoards lie open to whoever brings them down.",
		MobEffects = {},
		RewardEffects = { "Calamity Heart chance x3 on Alphas and Biome Bosses" },
		Mods = { HeartMult = 3 },
	}),
}) :: { Event }

function Config.Get(id: string?): Event?
	for _, event in Config.Events do
		if event.Id == id then return event end
	end
	return nil
end

return table.freeze(Config)
