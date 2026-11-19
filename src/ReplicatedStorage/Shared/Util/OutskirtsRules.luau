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
	MinX = -75,
	MaxX = 75,
	MinZ = 62,
	MaxZ = 158,
})

OutskirtsRules.Timing = table.freeze({
	PatrolSeconds = 4.2,
	FirstWavePatrolSeconds = 1.6,
	AftermathSeconds = 2.8,
	HeroAttackInterval = 1.25,
	MobAttackInterval = 1.65,
})

OutskirtsRules.GuardPostCenter = Vector3.new(12, 0, 96)

OutskirtsRules.GatehouseRunIn = table.freeze({
	Vector3.new(14, 0, 68),
	Vector3.new(14, 0, 82),
	Vector3.new(14, 0, 96),
})

OutskirtsRules.BuildingAttackTargets = table.freeze({
	Vector3.new(-3.5, 0, 102.5),
	Vector3.new(12.0, 0, 98.0),
	Vector3.new(24.0, 0, 89.5),
})

OutskirtsRules.CampfireRestSlots = table.freeze({
	Vector3.new(-4.8, 0, 90.0),
	Vector3.new(-2.0, 0, 92.7),
	Vector3.new(0.8, 0, 90.2),
	Vector3.new(-0.8, 0, 86.5),
	Vector3.new(-2.8, 0, 86.9),
})

OutskirtsRules.DefenderSlots = table.freeze({
	table.freeze({ Rally = Vector3.new(12, 0, 108), PatrolMinX = -5, PatrolMaxX = 25 }),
	table.freeze({ Rally = Vector3.new(-2, 0, 108), PatrolMinX = -30, PatrolMaxX = -5 }),
	table.freeze({ Rally = Vector3.new(24, 0, 105), PatrolMinX = 22, PatrolMaxX = 50 }),
	table.freeze({ Rally = Vector3.new(-14, 0, 107), PatrolMinX = -55, PatrolMaxX = -28 }),
	table.freeze({ Rally = Vector3.new(34, 0, 106), PatrolMinX = 45, PatrolMaxX = 68 }),
} :: { DefenderSlot })

OutskirtsRules.SpawnLanes = table.freeze({
	table.freeze({
		Spawn = Vector3.new(-30, 0, 150),
		Mid = Vector3.new(-12, 0, 134),
		BuildingTarget = Vector3.new(-3.5, 0, 102.5),
	}),
	table.freeze({
		Spawn = Vector3.new(12, 0, 152),
		Mid = Vector3.new(12, 0, 135),
		BuildingTarget = Vector3.new(12.0, 0, 98.0),
	}),
	table.freeze({
		Spawn = Vector3.new(42, 0, 150),
		Mid = Vector3.new(30, 0, 134),
		BuildingTarget = Vector3.new(24.0, 0, 89.5),
	}),
} :: { SpawnLane })

OutskirtsRules.DefaultArchetypeWeapons = table.freeze({
	Marksman = "BOW",
	Vanguard = "SWORD_SHIELD",
	Striker = "DAGGERS",
	Berserker = "AXE",
	Scholar = "STAFF",
	Healer = "TOME",
})

OutskirtsRules.RangedWeapons = table.freeze({
	BOW = true,
	STAFF = true,
	TOME = true,
})

OutskirtsRules.SquadSkirmish = table.freeze({
	EngageRadius = 36,
	LeashRadius = 44,
	HysteresisMargin = 8,
	SprintDisengageDistance = 16,
	ReturnSnapDistance = 85,
	ReturnArriveDistance = 0.65,
	GatehouseReturnPoint = Vector3.new(14, 0, 66),
	ClampBounds = table.freeze({
		MinX = -72,
		MaxX = 72,
		MinZ = 65,
		MaxZ = 154,
	}),
	AttackCycle = table.freeze({ 1, 1, 2, 1, 3 }),
})

-- Exact east-west wilderness dirt trail curve from OutskirtsEnvironmentBuilder.
function OutskirtsRules.TrailZ(x: number): number
	return 110 + math.sin(x * 0.055) * 8 + math.cos(x * 0.11) * 3
end

function OutskirtsRules.TrailPoint(x: number): Vector3
	local clampedX = math.clamp(x, -68, 68)
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

local function flatDist(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Returns true when a plot-local position lies inside the southern Outskirts wilderness (south of the Z=57 dividing wall).
function OutskirtsRules.IsLocalPointInOutskirts(localPos: Vector3): boolean
	local b = OutskirtsRules.Bounds
	return localPos.X >= b.MinX
		and localPos.X <= b.MaxX
		and localPos.Z >= b.MinZ
		and localPos.Z <= b.MaxZ
		and math.abs(localPos.Y) <= 10
end

-- Clamps a plot-local position onto OutskirtsGrounds so skirmishing heroes stay clear of the dividing wall and island edges.
function OutskirtsRules.ClampToOutskirts(localPos: Vector3): Vector3
	local c = OutskirtsRules.SquadSkirmish.ClampBounds
	return Vector3.new(
		math.clamp(localPos.X, c.MinX, c.MaxX),
		0,
		math.clamp(localPos.Z, c.MinZ, c.MaxZ)
	)
end

-- Resolves visual skirmish range and ranged flag for a squad hero from its weapon type and catalog attack range.
function OutskirtsRules.ResolveSquadAttackRange(seedAttackRange: number?, weaponType: string?): (number, boolean)
	local w = weaponType or "UNARMED"
	if w == "UNARMED" then
		return 5.0, false
	end
	local isRanged = OutskirtsRules.RangedWeapons[w] == true
	local raw = if type(seedAttackRange) == "number" and seedAttackRange == seedAttackRange then seedAttackRange else 6
	if isRanged then
		return math.clamp(raw, 22, 32), true
	end
	return math.clamp(raw, 4.8, 7.5), false
end

-- Computes a slot-spread melee standoff position around a mob inside Outskirts bounds so squadmates fan out.
function OutskirtsRules.ResolveMeleeStandoff(
	mobLocalPos: Vector3,
	heroLocalPos: Vector3,
	slotIndex: number,
	desiredRange: number
): Vector3
	local dx = heroLocalPos.X - mobLocalPos.X
	local dz = heroLocalPos.Z - mobLocalPos.Z
	local baseAngle = if (dx * dx + dz * dz) > 1e-4 then math.atan2(dz, dx) else -math.pi * 0.5
	local slot = math.clamp(math.floor(slotIndex or 1), 1, 5)
	-- Spread slots symmetrically around the approach vector: 0, +38, -38, +76, -76 deg.
	local slotOffsets = { 0, 0.66, -0.66, 1.32, -1.32 }
	local angle = baseAngle + (slotOffsets[slot] or 0)
	local radius = math.max(3.6, desiredRange * 0.85)
	local raw = Vector3.new(
		mobLocalPos.X + math.cos(angle) * radius,
		0,
		mobLocalPos.Z + math.sin(angle) * radius
	)
	return OutskirtsRules.ClampToOutskirts(raw)
end

-- Picks the best live Outskirts mob within engage/leash radius of the squad hero's anchor, with target-lock hysteresis.
function OutskirtsRules.PickSquadTargetMob(
	heroLocalPos: Vector3,
	anchorLocalPos: Vector3,
	currentTargetId: number?,
	mobs: { [number]: any }
): any?
	local cfg = OutskirtsRules.SquadSkirmish
	local currentMob = if currentTargetId then mobs[currentTargetId] else nil
	local currentValid = currentMob ~= nil
		and currentMob.Spawned == true
		and currentMob.DeathAt == nil
		and flatDist(anchorLocalPos, currentMob.LocalPos) <= cfg.LeashRadius

	local function scoreMob(mob: any): number
		local dist = flatDist(heroLocalPos, mob.LocalPos)
		local threatBonus = if mob.AttackingBuilding then -18 elseif mob.TargetsBuildingFirst then -6 else 0
		return dist + threatBonus
	end

	local bestMob: any? = if currentValid then currentMob else nil
	local bestScore = if currentValid then scoreMob(currentMob) else math.huge

	for id, mob in pairs(mobs) do
		if mob.Spawned and mob.DeathAt == nil then
			local anchorDist = flatDist(anchorLocalPos, mob.LocalPos)
			if anchorDist <= cfg.EngageRadius then
				local score = scoreMob(mob)
				if bestMob == nil then
					bestMob = mob
					bestScore = score
				elseif id ~= currentTargetId then
					local margin = if currentValid and bestMob == currentMob then cfg.HysteresisMargin else 0
					if score + margin < bestScore then
						bestMob = mob
						bestScore = score
					end
				end
			end
		end
	end

	return bestMob
end

-- Steers a returning hero through the rear gatehouse threshold when crossing back north of the Z=57 dividing wall.
function OutskirtsRules.ResolveReturnGoal(currentLocalPos: Vector3, anchorLocalPos: Vector3): Vector3
	local gate = OutskirtsRules.SquadSkirmish.GatehouseReturnPoint
	if currentLocalPos.Z > 64 and anchorLocalPos.Z < 60 then
		if math.abs(currentLocalPos.X - gate.X) > 8 or currentLocalPos.Z > 70 then
			return gate
		end
	end
	return anchorLocalPos
end

return table.freeze(OutskirtsRules)
