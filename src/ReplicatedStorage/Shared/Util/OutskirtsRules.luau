--!strict
-- ReplicatedStorage/Shared/Util/OutskirtsRules.luau
-- Pure frontier floor/biome resolution, wave composition, and plot-local waypoint layout
-- for the Outskirts Guard Post visual wave defense loop.

local Shared = script.Parent.Parent
local Config = Shared:WaitForChild("Config")
local TowerFloorConfig = require(Config:WaitForChild("TowerFloorConfig"))
local MobCatalog = require(Config:WaitForChild("MobCatalog"))
local FirstBiomeCombat = require(Config:WaitForChild("FirstBiomeCombat"))

export type FrontierInfo = {
	FloorId: number,
	FloorDisplayName: string,
	BiomeId: string,
	BiomeDisplayName: string,
	BiomeIndex: number,
	IndexInBiome: number,
	PreviewEnemyId: string,
}

export type WaveSpawnEntry = {
	EnemyId: string,
	Role: string,
	LaneIndex: number,
	SpawnDelay: number,
	HitsToDefeat: number,
	Scale: number,
	TargetsBuildingFirst: boolean,
}

export type DefenderSlot = {
	Rally: Vector3,
	PatrolMinX: number,
	PatrolMaxX: number,
}

export type SpawnLane = {
	Spawn: Vector3,
	Mid: Vector3,
	BuildingTarget: Vector3,
}

local OutskirtsRules = {}

OutskirtsRules.Bounds = table.freeze({
	MinX = -120,
	MaxX = 120,
	MinZ = 96,
	MaxZ = 220,
})

OutskirtsRules.Timing = table.freeze({
	PatrolSeconds = 4.2,
	FirstWavePatrolSeconds = 1.6,
	AftermathSeconds = 2.8,
	HeroAttackInterval = 1.25,
	MobAttackInterval = 1.65,
})

OutskirtsRules.GuardPostCenter = Vector3.new(15, 0, 158)

OutskirtsRules.GatehouseRunIn = table.freeze({
	Vector3.new(32, 0, 100),
	Vector3.new(27, 0, 126),
	Vector3.new(18, 0, 150),
})

OutskirtsRules.BuildingAttackTargets = table.freeze({
	Vector3.new(8, 0, 152),
	Vector3.new(15.5, 0, 165.5),
	Vector3.new(23.5, 0, 161.5),
})

OutskirtsRules.CampfireRestSlots = table.freeze({
	Vector3.new(5.5, 0, 160.5),
	Vector3.new(10.5, 0, 165.8),
	Vector3.new(7.2, 0, 164.2),
	Vector3.new(13.8, 0, 163.5),
	Vector3.new(6.0, 0, 157.2),
})

OutskirtsRules.DefenderSlots = table.freeze({
	table.freeze({ Rally = Vector3.new(15, 0, 170), PatrolMinX = -4, PatrolMaxX = 30 }),
	table.freeze({ Rally = Vector3.new(4, 0, 169), PatrolMinX = -36, PatrolMaxX = -4 }),
	table.freeze({ Rally = Vector3.new(27, 0, 169), PatrolMinX = 28, PatrolMaxX = 60 }),
	table.freeze({ Rally = Vector3.new(-6, 0, 167), PatrolMinX = -66, PatrolMaxX = -34 }),
	table.freeze({ Rally = Vector3.new(37, 0, 167), PatrolMinX = 56, PatrolMaxX = 86 }),
} :: { DefenderSlot })

OutskirtsRules.SpawnLanes = table.freeze({
	table.freeze({
		Spawn = Vector3.new(-40, 0, 210),
		Mid = Vector3.new(-16, 0, 188),
		BuildingTarget = Vector3.new(8, 0, 152),
	}),
	table.freeze({
		Spawn = Vector3.new(16, 0, 214),
		Mid = Vector3.new(16, 0, 190),
		BuildingTarget = Vector3.new(15.5, 0, 165.5),
	}),
	table.freeze({
		Spawn = Vector3.new(54, 0, 210),
		Mid = Vector3.new(38, 0, 188),
		BuildingTarget = Vector3.new(23.5, 0, 161.5),
	}),
} :: { SpawnLane })

OutskirtsRules.DefaultArchetypeWeapons = table.freeze({
	Marksman = "BOW",
	Vanguard = "SWORD_SHIELD",
	Striker = "DAGGERS",
	Miner = "AXE",
	Scholar = "STAFF",
	Healer = "TOME",
})

-- Exact east-west wilderness dirt trail curve from OutskirtsEnvironmentBuilder.
function OutskirtsRules.TrailZ(x: number): number
	return 160 + math.sin(x * 0.038) * 12 + math.cos(x * 0.082) * 4
end

function OutskirtsRules.TrailPoint(x: number): Vector3
	local clampedX = math.clamp(x, -110, 110)
	return Vector3.new(clampedX, 0, OutskirtsRules.TrailZ(clampedX))
end

-- Resolves the player's highest unlocked Tower frontier floor (1..50).
-- A fresh profile (HighestClearedFloor = 0, MaxFloorReached = 1) resolves to Floor 1 (verdant_ruins).
-- Clearing Floor 5 advances the frontier to Floor 6 (fungal_hollow), capped at Floor 50 (abyssal_throne).
function OutskirtsRules.ResolveFrontierFloor(highestClearedFloor: number?, maxFloorReached: number?): number
	local cleared = if type(highestClearedFloor) == "number" and highestClearedFloor == highestClearedFloor
		then math.floor(highestClearedFloor)
		else 0
	local reached = if type(maxFloorReached) == "number" and maxFloorReached == maxFloorReached
		then math.floor(maxFloorReached)
		else 0
	local unlockedFromClears = if cleared > 0 then cleared + 1 else 1
	return math.clamp(math.max(unlockedFromClears, reached, 1), 1, TowerFloorConfig.FloorCount)
end

function OutskirtsRules.ResolveFrontierInfo(highestClearedFloor: number?, maxFloorReached: number?): FrontierInfo
	local floorId = OutskirtsRules.ResolveFrontierFloor(highestClearedFloor, maxFloorReached)
	local floor = assert(TowerFloorConfig.Get(floorId), "Invalid frontier floor")
	local biome = assert(MobCatalog.Biomes[floor.BiomeIndex], "Invalid frontier biome")

	local previewEnemyId = biome.RegularEnemyIds[2] or biome.RegularEnemyIds[1]
	if floor.IndexInBiome >= 5 then
		previewEnemyId = biome.AlphaEnemyId
	elseif floor.IndexInBiome == 4 then
		previewEnemyId = biome.EliteEnemyId
	end

	return {
		FloorId = floor.Id,
		FloorDisplayName = floor.DisplayName,
		BiomeId = floor.BiomeId,
		BiomeDisplayName = floor.BiomeDisplayName,
		BiomeIndex = floor.BiomeIndex,
		IndexInBiome = floor.IndexInBiome,
		PreviewEnemyId = previewEnemyId,
	}
end

local function makeWaveEntry(
	enemyId: string,
	role: string,
	slotIdx: number,
	waveIdx: number,
	targetsBuildingFirst: boolean
): WaveSpawnEntry
	local combatSpec = FirstBiomeCombat.Entries[enemyId]
	local laneIndex = ((slotIdx + waveIdx - 2) % #OutskirtsRules.SpawnLanes) + 1
	local hits = 3
	local scale = 1.0
	if role == "ALPHA" then
		hits = 6
		local h = if combatSpec and type(combatSpec.Height) == "number" then combatSpec.Height else 10
		scale = if h > 12 then 0.82 else 0.92
	elseif role == "ELITE" then
		hits = 5
	elseif role == "SUPPORT" then
		hits = 3
	else
		hits = if slotIdx % 2 == 0 then 4 else 3
	end
	return {
		EnemyId = enemyId,
		Role = role,
		LaneIndex = laneIndex,
		SpawnDelay = (slotIdx - 1) * 0.32,
		HitsToDefeat = hits,
		Scale = scale,
		TargetsBuildingFirst = targetsBuildingFirst,
	}
end

-- Builds a deterministic wave of biome enemies for the resolved frontier floor.
-- Keeps giant 22-stud Biome Bosses inside the Tower while scaling from Regulars -> Supports -> Elites -> gilded Alphas.
function OutskirtsRules.ResolveWaveRoster(
	floorId: number,
	guardPostLevel: number?,
	workerCount: number?,
	waveIndex: number?
): { WaveSpawnEntry }
	local clampedFloor = math.clamp(
		if type(floorId) == "number" and floorId == floorId then math.floor(floorId) else 1,
		1,
		TowerFloorConfig.FloorCount
	)
	local floor = assert(TowerFloorConfig.Get(clampedFloor), "Missing floor config")
	local biome = assert(MobCatalog.Biomes[floor.BiomeIndex], "Missing biome config")

	local level = math.clamp(if type(guardPostLevel) == "number" then math.floor(guardPostLevel) else 1, 1, 5)
	local workers = math.clamp(if type(workerCount) == "number" then math.floor(workerCount) else 1, 0, 5)
	local wave = math.max(1, if type(waveIndex) == "number" then math.floor(waveIndex) else 1)

	-- Even an unstaffed Guard Post (0 workers) can preview a small 2-mob scouting party if needed;
	-- staffed Guard Posts face 3..6 attackers depending on Adventurer count and Guard Post level.
	local totalCount = if workers <= 0
		then 2
		else math.clamp(2 + workers + math.floor((level - 1) / 2), 3, 6)

	local reg1 = biome.RegularEnemyIds[1]
	local reg2 = biome.RegularEnemyIds[2] or reg1
	local supportId = biome.SupportEnemyId
	local eliteId = biome.EliteEnemyId
	local alphaId = biome.AlphaEnemyId
	local idxInBiome = floor.IndexInBiome

	local roster: { WaveSpawnEntry } = table.create(totalCount)
	for i = 1, totalCount do
		local enemyId = if (i + wave) % 2 == 0 then reg1 else reg2
		local role = "REGULAR"

		if idxInBiome >= 5 and i == 1 then
			enemyId = alphaId
			role = "ALPHA"
		elseif idxInBiome >= 5 and i == 2 and totalCount >= 4 and wave % 2 == 0 then
			enemyId = eliteId
			role = "ELITE"
		elseif idxInBiome == 4 and i == 1 then
			enemyId = eliteId
			role = "ELITE"
		elseif idxInBiome == 3 and i == 1 and wave % 3 == 0 then
			enemyId = eliteId
			role = "ELITE"
		elseif idxInBiome >= 2 and i == totalCount and supportId ~= nil then
			if idxInBiome >= 3 or wave % 2 == 0 then
				enemyId = supportId
				role = "SUPPORT"
			end
		end

		-- Ensure at least the last melee regular/raider pushes directly toward Building_GuardPost
		-- so the Guard Post building itself is visibly threatened until intercepted.
		local targetsBuildingFirst = (i == totalCount and role ~= "SUPPORT") or (i == 2 and totalCount >= 3)
		table.insert(roster, makeWaveEntry(enemyId, role, i, wave, targetsBuildingFirst))
	end

	return roster
end

function OutskirtsRules.DefaultWeaponForArchetype(archetype: string?): string
	return OutskirtsRules.DefaultArchetypeWeapons[archetype or ""] or "SWORD_SHIELD"
end

return table.freeze(OutskirtsRules)
