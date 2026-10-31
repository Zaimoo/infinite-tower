--!strict
-- Shared authoritative progress calculations and types for Tower Floor Loop.
local RS = game:GetService("ReplicatedStorage")
local TowerFloorConfig = require(RS.Shared.Config.TowerFloorConfig)
local MobCatalog = require(RS.Shared.Config.MobCatalog)

export type PlayerFloorProgress = {
	FloorId: number,
	CurrentKills: number,
	RequiredKills: number,
	BossSpawned: boolean,
	BossNetId: number?,
	BossDefeated: boolean,
	SurgeSpawned: boolean,
}

local TowerProgress = {}

TowerProgress.BOSS_PARTICIPATION_THRESHOLD = 0.03

-- Target kills required to summon the floor boss: round(20 + 1.2 * floorId). Phase 6 raised it from 12 + 0.5f so floors take longer.
function TowerProgress.GetRequiredKills(floorId: number): number
	if floorId <= 0 then
		return 0
	end
	return math.max(1, math.round(20 + 1.2 * floorId))
end

-- Create fresh floor session progress
function TowerProgress.CreateProgress(floorId: number): PlayerFloorProgress
	return {
		FloorId = floorId,
		CurrentKills = 0,
		RequiredKills = TowerProgress.GetRequiredKills(floorId),
		BossSpawned = false,
		BossNetId = nil,
		BossDefeated = false,
		SurgeSpawned = false,
	}
end

-- Mob kill progress values: Regular = 1, Elite = 3
function TowerProgress.GetKillProgressValue(role: string): number
	if role == "ELITE" then
		return 3
	elseif role == "REGULAR" then
		return 1
	end
	return 1
end

-- Advances player kill progress and returns true if boss spawn condition was just triggered
function TowerProgress.RecordKill(progress: PlayerFloorProgress, role: string): boolean
	if progress.BossSpawned or progress.BossDefeated then
		return false
	end
	local add = TowerProgress.GetKillProgressValue(role)
	progress.CurrentKills += add
	if progress.CurrentKills >= progress.RequiredKills then
		progress.BossSpawned = true
		return true
	end
	return false
end


-- Minimum artifact rarity tier a Biome Boss drops on its first clear: tiers 1-2 Rare, 3-4 Superior, 5-6 Exalted,
-- 7-8 Legendary, 9-10 Mythical. Capped at Mythical (7) until higher tiers ship after launch.
function TowerProgress.BossArtifactRarity(bossTier: number): number
	return math.min(7, 2 + math.ceil(bossTier / 2))
end

-- Personal surge pack: fires once per floor visit when a player's progress crosses SurgeAt of the threshold.
-- Biome Boss floors (every 5th) skip it because the boss itself is the event.
TowerProgress.SurgeAt = 0.5

function TowerProgress.CheckSurge(progress: PlayerFloorProgress): boolean
	if progress.SurgeSpawned or progress.BossSpawned or progress.BossDefeated then
		return false
	end
	if progress.FloorId % 5 == 0 then
		return false
	end
	if progress.CurrentKills >= progress.RequiredKills * TowerProgress.SurgeAt then
		progress.SurgeSpawned = true
		return true
	end
	return false
end
-- Resolves the floor boss template: the biome Boss on floor 5 of a biome, the biome Alpha on floors 1-4.
function TowerProgress.GetFloorBossEnemyId(floorId: number): string
	local floor = TowerFloorConfig.Get(floorId)
	if not floor then
		return "mob_moss_crawler"
	end
	if floor.BossEnemyId then
		return floor.BossEnemyId
	end
	local biome = MobCatalog.Biomes[floor.BiomeIndex]
	if biome then
		return biome.AlphaEnemyId or biome.EliteEnemyId or biome.BossEnemyId
	end
	return "elite_vinebound"
end

-- Checks if player dealt at least 3% of total boss HP
function TowerProgress.CheckParticipation(damageDealt: number, maxHP: number, isKiller: boolean?): boolean
	if isKiller == true then
		return true
	end
	if maxHP <= 0 then
		return false
	end
	return (damageDealt / maxHP) >= TowerProgress.BOSS_PARTICIPATION_THRESHOLD
end

return table.freeze(TowerProgress)
