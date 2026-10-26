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
}

local TowerProgress = {}

TowerProgress.BOSS_PARTICIPATION_THRESHOLD = 0.03

-- Target kills required to summon the floor boss: round(12 + 0.5 * floorId)
function TowerProgress.GetRequiredKills(floorId: number): number
	if floorId <= 0 then
		return 0
	end
	return math.max(1, math.round(12 + 0.5 * floorId))
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
	}
end

-- Mob kill progress values: Regular = 1, Elite = 2
function TowerProgress.GetKillProgressValue(role: string): number
	if role == "ELITE" then
		return 2
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

-- Resolves the appropriate Boss/Champion enemy template ID for any floor
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
		return biome.EliteEnemyId or biome.BossEnemyId
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
