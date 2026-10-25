--!strict
-- Tower progress tracking and boss gate mechanics
local RS = game:GetService("ReplicatedStorage")
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

function TowerProgress.CreateProgress(floorId: number): PlayerFloorProgress
	return {
		FloorId = floorId,
		CurrentKills = 0,
		RequiredKills = math.max(1, math.round(12 + 0.5 * floorId)),
		BossSpawned = false,
		BossNetId = nil,
		BossDefeated = false,
	}
end

function TowerProgress.RecordKill(progress: PlayerFloorProgress, role: string): boolean
	local pts = if role == "ELITE" then 2 else 1
	progress.CurrentKills += pts
	if progress.CurrentKills >= progress.RequiredKills and not progress.BossSpawned then
		progress.BossSpawned = true
		return true
	end
	return false
end

function TowerProgress.CheckParticipation(damage: number, maxHP: number, isKiller: boolean): boolean
	if isKiller then
		return true
	end
	if maxHP <= 0 then
		return false
	end
	return (damage / maxHP) >= 0.03
end

function TowerProgress.GetFloorBossEnemyId(floorId: number): string
	local biomeIndex = math.clamp(math.ceil(floorId / 5), 1, #MobCatalog.Biomes)
	local biome = MobCatalog.Biomes[biomeIndex]
	if biome then
		return biome.BossEnemyId
	end
	return "boss_mossbound_guardian"
end

return TowerProgress
