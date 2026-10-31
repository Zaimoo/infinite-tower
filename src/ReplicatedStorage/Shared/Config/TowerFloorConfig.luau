--!strict
-- Part 1/4 floor configuration. Names, layouts, encounters and scaling across all 50 floors.
-- Requiring this module does not build rooms, change travel, or spawn encounters.
local MobCatalog = require(script.Parent.MobCatalog)
local Layout = require(script.Parent.TowerLayout)
local StatBalance = require(script.Parent.StatBalance)

export type Encounter = { EnemyId: string, Count: number }
export type Floor = {
	Id: number,
	DisplayName: string,
	BiomeId: string,
	BiomeDisplayName: string,
	BiomeIndex: number,
	IndexInBiome: number,
	VariantKind: string,
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
Config.Version = 3
Config.ContentStatus = "LOCAL_AUTHORED_PROTOTYPE"
Config.BalanceStatus = "PROVISIONAL_NOT_PLAYTESTED"
Config.FloorCount = 50
Config.FloorsPerBiome = 5
Config.HubFloorId = 0 -- context only, never a playable floor/catalog record

-- These curves are inputs for tower combat integration
-- replacements. Rewards stay physical; these values do not grant a travel payout.
Config.Scaling = table.freeze({ HPPerFloor = 1.08, DamagePerFloor = 1.045, RewardPerFloor = 1.055 })
Config.BaseStatsByRole = table.freeze({
	REGULAR = table.freeze({ MaxHP = 850, ATK = 18, GoldReward = 80, XPReward = 20 }),
	ELITE = table.freeze({ MaxHP = 2200, ATK = 35, GoldReward = 210, XPReward = 55 }),
	ALPHA = table.freeze({ MaxHP = 6000, ATK = 45, GoldReward = 450, XPReward = 110 }),
	BOSS = table.freeze({ MaxHP = 12000, ATK = 55, GoldReward = 800, XPReward = 200 }),
})

local floorNames = {
	{ "Overgrown Threshold", "Broken Aqueduct", "Rootway Crossing", "Vinebound Bastion", "Mossbound Court" },
	{ "Sporelit Entry", "Mycelium Galleries", "Blooming Chasm", "Rotcap Keep", "Matriarch's Hollow" },
	{ "Cinder Gate", "Buried Caravan", "Glasswind Ravine", "Sunscar Fortress", "Colossus Dais" },
	{ "Rimefall Approach", "Frozen Barracks", "Shattered Iceway", "Whiteguard Keep", "Frostbound Throne" },
	{ "Slagworks Entry", "Molten Assembly", "Furnace Causeway", "Ironflame Bulwark", "Titan's Crucible" },
	{ "Stormgrass Rise", "Thunderhead Outpost", "Skybridge Cliffs", "Tempest Redoubt", "Roc's Eyrie" },
	{ "Blighted Verge", "Twisted Orchard", "Briar Labyrinth", "Heartrot Stronghold", "Sovereign's Grove" },
	{ "Drowned Steps", "Coral Cloister", "Tidal Channels", "Pearlguard Vault", "Leviathan's Basin" },
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
		local variantKind = variantKinds[indexInBiome]
		local counts = {}
		for _, placement in Layout.Placements(biome, indexInBiome) do
			counts[placement.EnemyId] = (counts[placement.EnemyId] or 0) + 1
		end
		local encounters: { Encounter } = {}
		for _, enemyId in {biome.RegularEnemyIds[1], biome.RegularEnemyIds[2], biome.EliteEnemyId, biome.AlphaEnemyId, biome.BossEnemyId} do
			if counts[enemyId] then table.insert(encounters, table.freeze({EnemyId=enemyId, Count=counts[enemyId]})) end
		end
		local bossId: string? = if indexInBiome==5 then biome.BossEnemyId else nil
		layouts[layoutId] = table.freeze({
			Id = layoutId,
			FloorId = id,
			BiomeId = biome.Id,
			VariantKind = variantKind,
			Status = "LOCAL_AUTHORED_PROTOTYPE",
			SourceModule = "ServerScriptService.Core.TowerRoomBuilder",
		})
		environments[environmentId] = table.freeze({
			Id = environmentId,
			FloorId = id,
			BiomeId = biome.Id,
			VariantKind = variantKind,
			Status = "LOCAL_AUTHORED_PROTOTYPE",
			SourceModule = "ServerScriptService.Core.TowerRoomBuilder",
		})
		floors[id] = table.freeze({
			Id = id,
			DisplayName = floorNames[biomeIndex][indexInBiome],
			BiomeId = biome.Id,
			BiomeDisplayName = biome.DisplayName,
			BiomeIndex = biomeIndex,
			IndexInBiome = indexInBiome,
			VariantKind = variantKind,
			LayoutId = layoutId,
			EnvironmentVariantId = environmentId,
			Unlocked = true,
			BossEnemyId = bossId,
			Encounters = table.freeze(encounters),
			Difficulty = table.freeze({ HPMultiplier = Config.Scaling.HPPerFloor ^ (id - 1), DamageMultiplier = Config.Scaling.DamagePerFloor ^ (id - 1) }),
			Rewards = table.freeze({ GoldMultiplier = Config.Scaling.RewardPerFloor ^ (id - 1), XPMultiplier = Config.Scaling.RewardPerFloor ^ (id - 1) }),
			ContentStatus = "LOCAL_AUTHORED_PROTOTYPE",
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

-- Validate both floor and enemy membership to avoid borrowing another biome.
function Config.GetEnemyStats(floorId: any, enemyId: any): any?
	local floor = Config.Get(floorId)
	local enemy = type(enemyId) == "string" and MobCatalog.Get(enemyId) or nil
	if not floor or not enemy or enemy.BiomeId ~= floor.BiomeId then return nil end
	local included = false
	for _, encounter in ipairs(floor.Encounters) do
		if encounter.EnemyId == enemyId then included = true; break end
	end
	if not included then return nil end
	local statRole = if enemy.Alpha then "ALPHA" else enemy.Role -- Floor Alphas have their own stat row
	local base = Config.BaseStatsByRole[statRole]
	if not base then return nil end
	return table.freeze({
		MaxHP = (StatBalance.GetFloorStats(floorId, statRole) :: any).MaxHP,
		ATK = (StatBalance.GetFloorStats(floorId, statRole) :: any).ATK,
		GoldReward = math.round(base.GoldReward * floor.Rewards.GoldMultiplier),
		XPReward = math.round(base.XPReward * floor.Rewards.XPMultiplier),
	})
end

-- Recommended Squad Power for a floor (Phase 5 tower hub). Each enemy counts like a hero does in
-- StatFormulas.GetHeroPower (MaxHP + 10 x ATK), summed over the floor's roster and scaled so a
-- fresh one-star squad (~700 power) matches Floor 1. Rounded to two significant figures.
-- Retuned in Phase 6: Floor 1 is sized to the default starter pair (Catio + Han, ~11,700 power), so it reads ~12,000.
Config.RecommendedPowerScale = 0.28

function Config.RecommendedPower(floorId: number): number
	local floor = Config.Get(floorId)
	if not floor then return 0 end
	local total = 0
	for _, encounter in ipairs(floor.Encounters) do
		local stats = Config.GetEnemyStats(floorId, encounter.EnemyId)
		if stats then
			total += (stats.MaxHP + 10 * stats.ATK) * encounter.Count
		end
	end
	local raw = total * Config.RecommendedPowerScale
	if raw < 100 then return math.round(raw) end
	local step = 10 ^ (math.floor(math.log10(raw)) - 1)
	return math.round(raw / step) * step
end

-- Provisional economy: a single hero summon costs 100 gems (10 cost 900).
-- Kill gems stay flat; gold, relic probability and relic value grow with floor.
function Config.GetKillRewards(floorId: number, role: string): any
 assert(Config.IsFloorId(floorId), "Invalid reward floor")
 local base = assert(Config.BaseStatsByRole[role], "Invalid enemy role")
 local progress = (floorId - 1) / (Config.FloorCount - 1)
 local bonus = if role == "BOSS" then 0.20 elseif role == "ELITE" then 0.04 else 0
 return {
  Gold = math.round(base.GoldReward * Config.Scaling.RewardPerFloor ^ (floorId - 1)),
  Gems = 1,
  RelicChance = 0.02 + 0.10 * progress + bonus,
  RelicMultiplier = 1 + 0.05 * (floorId - 1),
  CoreChance = 0.02 + 0.18 * progress,
  UrnChance = 0.18 + 0.22 * progress,
 }
end

function Config.RollRelic(floorId: number, role: string, dropRoll: number, tierRoll: number): string?
 local reward = Config.GetKillRewards(floorId, role)
 if dropRoll >= reward.RelicChance then
  -- Phase 6 M4: a camp Elite always leaves at least a Mana Geode, so every floor has stealable loot to fight over.
  if role == "ELITE" then return "MANA_GEODE" end
  return nil
 end
 if tierRoll < reward.CoreChance then return "ABYSSAL_CORE" end
 if tierRoll < reward.CoreChance + reward.UrnChance then return "CURSED_URN" end
 return "MANA_GEODE"
end

return table.freeze(Config)
