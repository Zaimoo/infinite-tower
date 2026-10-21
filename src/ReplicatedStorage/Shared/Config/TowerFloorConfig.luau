--!strict
-- Part 1 data only. Names, layouts, encounters and balance are proposed defaults.
-- Requiring this module does not build rooms, change travel, or spawn encounters.
local MobCatalog = require(script.Parent.MobCatalog)
local StatBalance = require(script.Parent.StatBalance)

export type Encounter = { EnemyId: string, Count: number }
export type Floor = {
	Id: number,
	DisplayName: string,
	BiomeId: string,
	BiomeIndex: number,
	IndexInBiome: number,
	LayoutId: string,
	EnvironmentVariantId: string,
	Unlocked: boolean,
	BossEnemyId: string?,
	Encounters: { Encounter },
	Difficulty: { HPMultiplier: number, DamageMultiplier: number },
	Rewards: { GoldMultiplier: number, XPMultiplier: number },
	ContentStatus: string,
}

local Config = {}
Config.Version = 1
Config.ContentStatus = "PROPOSED_DEFAULTS"
Config.BalanceStatus = "PROVISIONAL_NOT_PLAYTESTED"
Config.FloorCount = 50
Config.FloorsPerBiome = 5
Config.HubFloorId = 0 -- context only, never a playable floor/catalog record

-- These curves are inputs for later combat integration, not existing WorldBossConfig
-- replacements. Rewards stay physical; these values do not grant a travel payout.
Config.Scaling = table.freeze({ HPPerFloor = 1.08, DamagePerFloor = 1.045, RewardPerFloor = 1.055 })
Config.BaseStatsByRole = table.freeze({
	REGULAR = table.freeze({ MaxHP = 850, ATK = 18, GoldReward = 80, XPReward = 20 }),
	ELITE = table.freeze({ MaxHP = 2200, ATK = 35, GoldReward = 210, XPReward = 55 }),
	BOSS = table.freeze({ MaxHP = 12000, ATK = 55, GoldReward = 800, XPReward = 200 }),
})

local floorNames = {
	{ "Overgrown Threshold", "Broken Aqueduct", "Rootway Crossing", "Vinebound Bastion", "Mossbound Court" },
	{ "Sporelit Entry", "Mycelium Galleries", "Blooming Chasm", "Rotcap Keep", "Matriarch's Hollow" },
	{ "Drowned Steps", "Coral Cloister", "Tidal Channels", "Pearlguard Vault", "Leviathan's Basin" },
	{ "Cinder Gate", "Buried Caravan", "Glasswind Ravine", "Sunscar Fortress", "Colossus Dais" },
	{ "Rimefall Approach", "Frozen Barracks", "Shattered Iceway", "Whiteguard Keep", "Frostbound Throne" },
	{ "Stormgrass Rise", "Thunderhead Outpost", "Skybridge Cliffs", "Tempest Redoubt", "Roc's Eyrie" },
	{ "Slagworks Entry", "Molten Assembly", "Furnace Causeway", "Ironflame Bulwark", "Titan's Crucible" },
	{ "Blighted Verge", "Twisted Orchard", "Briar Labyrinth", "Heartrot Stronghold", "Sovereign's Grove" },
	{ "Starlit Vestibule", "Orbiting Stacks", "Fractured Index", "Runeguard Athenaeum", "Rift Warden's Observatory" },
	{ "Abyssal Descent", "Crimson Procession", "Voidspan Crossing", "Dreadguard Citadel", "Overlord's Throne" },
}
local variantKinds = { "INTRODUCTION", "EXPANDED_ENCOUNTER", "TERRAIN_VARIATION", "ELITE_STRONGHOLD", "BOSS_ARENA" }
local floors: { Floor } = {}
local layouts = {}
local environments = {}

for biomeIndex, biome in ipairs(MobCatalog.Biomes) do
	for indexInBiome = 1, Config.FloorsPerBiome do
		local id = (biomeIndex - 1) * Config.FloorsPerBiome + indexInBiome
		local layoutId = string.format("tower_floor_%02d", id)
		local environmentId = string.format("tower_environment_%02d", id)
		local encounters: { Encounter } = {
			table.freeze({ EnemyId = biome.RegularEnemyIds[1], Count = 4 + indexInBiome }),
			table.freeze({ EnemyId = biome.RegularEnemyIds[2], Count = 1 + indexInBiome }),
		}
		local bossId: string? = nil
		if indexInBiome >= 4 then
			table.insert(encounters, table.freeze({ EnemyId = biome.EliteEnemyId, Count = indexInBiome == 4 and 2 or 1 }))
		end
		if indexInBiome == 5 then
			bossId = biome.BossEnemyId
			table.insert(encounters, table.freeze({ EnemyId = biome.BossEnemyId, Count = 1 }))
		end
		-- Identifier registries are design records, not evidence of built geometry/art.
		layouts[layoutId] = table.freeze({ Id = layoutId, FloorId = id, BiomeId = biome.Id, VariantKind = variantKinds[indexInBiome], Status = "NOT_STARTED" })
		environments[environmentId] = table.freeze({ Id = environmentId, FloorId = id, BiomeId = biome.Id, Status = "NOT_STARTED" })
		floors[id] = table.freeze({
			Id = id,
			DisplayName = floorNames[biomeIndex][indexInBiome],
			BiomeId = biome.Id,
			BiomeIndex = biomeIndex,
			IndexInBiome = indexInBiome,
			LayoutId = layoutId,
			EnvironmentVariantId = environmentId,
			Unlocked = true,
			BossEnemyId = bossId,
			Encounters = table.freeze(encounters),
			Difficulty = table.freeze({ HPMultiplier = Config.Scaling.HPPerFloor ^ (id - 1), DamageMultiplier = Config.Scaling.DamagePerFloor ^ (id - 1) }),
			Rewards = table.freeze({ GoldMultiplier = Config.Scaling.RewardPerFloor ^ (id - 1), XPMultiplier = Config.Scaling.RewardPerFloor ^ (id - 1) }),
			ContentStatus = "NOT_STARTED",
		})
	end
end

Config.Floors = table.freeze(floors)
Config.Layouts = table.freeze(layouts)
Config.Environments = table.freeze(environments)

-- Never coerce strings, round fractions, or clamp invalid client destinations.
function Config.IsFloorId(value: any): boolean
	return type(value) == "number" and value == value and value >= 1 and value <= Config.FloorCount and value % 1 == 0
end

function Config.Get(floorId: any): Floor?
	if not Config.IsFloorId(floorId) then return nil end
	return floors[floorId]
end

function Config.GetAdjacent(floorId: any, direction: any): Floor?
	if not Config.IsFloorId(floorId) or (direction ~= -1 and direction ~= 1) then return nil end
	return Config.Get(floorId + direction)
end

-- Caller chooses a catalog enemy; stats are pure previews until Part 3 integrates
-- them. Validate both floor and enemy membership to avoid borrowing another biome.
function Config.GetEnemyStats(floorId: any, enemyId: any): any?
	local floor = Config.Get(floorId)
	local enemy = type(enemyId) == "string" and MobCatalog.Get(enemyId) or nil
	if not floor or not enemy or enemy.BiomeId ~= floor.BiomeId then return nil end
	local included = false
	for _, encounter in ipairs(floor.Encounters) do
		if encounter.EnemyId == enemyId then included = true; break end
	end
	if not included then return nil end
	local base = Config.BaseStatsByRole[enemy.Role]
	if not base then return nil end
	return table.freeze({
		MaxHP = (StatBalance.GetFloorStats(floorId,enemy.Role) :: any).MaxHP,
		ATK = (StatBalance.GetFloorStats(floorId,enemy.Role) :: any).ATK,
		GoldReward = math.round(base.GoldReward * floor.Rewards.GoldMultiplier),
		XPReward = math.round(base.XPReward * floor.Rewards.XPMultiplier),
	})
end

return table.freeze(Config)
