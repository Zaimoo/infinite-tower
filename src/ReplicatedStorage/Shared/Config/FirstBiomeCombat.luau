--!strict
-- Executable Part 3/4 Tower Combat registry covering all 10 biomes, 40 enemies, and 50 floors.
-- Native articulated parts and authored pose clips; no uploaded Roblox asset IDs are implied.
local MobCatalog = require(script.Parent.MobCatalog)
local Layout = require(script.Parent.TowerLayout)
local TowerFloorConfig = require(script.Parent.TowerFloorConfig)

local C: any = {
	ReleaseEnabled = true,
	RespawnSeconds = 25,
	BossRespawnSeconds = 300,
	AnchorLocal = Vector3.new(0, 0, 12),
	AcquisitionRange = 95,
	LeashRange = 105,
	AssetStatus = "LOCAL_AUTHORED_UNVERIFIED",
	PublishedAccess = "NOT_VERIFIED",
	Entries = {},
	Floors = {},
}

local function move(id: string, slot: string, shape: string, windup: number, recovery: number, range: number, radius: number, damage: number, cooldown: number, travel: number?)
	local flight = travel or 0
	return {
		Id = id,
		AnimationKey = slot,
		Shape = shape,
		WindupSeconds = windup,
		TravelSeconds = flight,
		ImpactOffsetSeconds = windup + flight,
		RecoverySeconds = recovery,
		Range = range,
		Radius = radius,
		HalfArcCos = .05,
		DamageMultiplier = damage,
		CooldownSeconds = cooldown,
		MaxLatenessSeconds = .45,
		TargetRule = "QUALIFIED_LIVE_UNSAFE_SAME_ROOM",
		ImpactRule = if shape == "PROJECTILE" then "SERVER_SWEPT_PROJECTILE_SAME_FLOOR_ONCE" else "SCHEDULED_SERVER_SHAPE_ONCE",
		TelegraphGeometry = shape,
	}
end

local rootHeightByFamily: { [string]: number } = {
	CRAWLER = 1.3,
	INSECT = 1.3,
	CRUSTACEAN = 1.6,
	SCORPION = 2.2,
	QUADRUPED = 2.4,
	AVIAN = 2.8,
	SMALL_BIPED = 2.1,
	FUNGAL_BIPED = 3.0,
	CASTER_BIPED = 3.5,
	WEAPON_BIPED = 3.5,
	ARMORED_BIPED = 3.8,
	ROOTED_BIPED = 4.3,
	HEAVY_BIPED = 4.6,
	TREANT = 5.5,
	ROYAL_BIPED = 8.0,
	SERPENT = 4.2,
	GIANT_AVIAN = 7.2,
	STONE_COLOSSUS = 8.5,
	FUNGAL_COLOSSUS = 8.0,
	FORGE_COLOSSUS = 9.5,
	GROVE_COLOSSUS = 9.8,
	ARCANE_COLOSSUS = 8.8,
	ROYAL_COLOSSUS = 9.8,
}

for enemyId, cat in pairs(MobCatalog.Entries) do
	local role = cat.Role
	local family = cat.Rig.ProposedFamily
	local height = cat.Bounds.Height
	local rootHeight = rootHeightByFamily[family] or math.max(1.3, math.round(height * 0.48 * 10) / 10)
	local isBoss = role == "BOSS"
	local isElite = role == "ELITE"
	local basicAttackSpec = cat.Attacks[1]
	local isProjectile = basicAttackSpec and basicAttackSpec.Kind == "PROJECTILE"

	local requiredSlots = { "Idle", "Locomotion", "BasicAttack", "HitReaction", "Death" }
	if isElite then
		table.insert(requiredSlots, "Special")
	elseif isBoss then
		table.insert(requiredSlots, "Awakening")
		table.insert(requiredSlots, "Signature1")
		table.insert(requiredSlots, "Signature2")
	end

	local attacks: { any }
	if enemyId == "mob_moss_crawler" then
		attacks = { move("moss_bite", "BasicAttack", "ARC", .65, .65, 7, 0, 1, 1.8) }
	elseif enemyId == "elite_vinebound" then
		attacks = {
			move("vine_cleave", "BasicAttack", "ARC", .9, .8, 9, 0, 1, 2.4),
			move("root_bloom", "Special", "TARGET_DISC", 1.4, 1, 34, 9, 1.25, 8),
		}
	elseif enemyId == "boss_mossbound_guardian" then
		attacks = {
			move("guardian_crush", "BasicAttack", "ARC", 1.1, 1, 13, 0, 1, 3),
			move("moss_quake", "Signature1", "SELF_DISC", 1.8, 1.2, 22, 22, 1.2, 10),
			move("sweeping_roots", "Signature2", "TARGET_DISC", 2.2, 1.5, 55, 13, 1.4, 14),
		}
	elseif isBoss then
		attacks = {
			move(enemyId .. "_basic", "BasicAttack", "ARC", 1.1, 1.0, 14, 0, 1.0, 3.0),
			move(enemyId .. "_signature_1", "Signature1", "SELF_DISC", 1.8, 1.2, 22, 22, 1.2, 10.0),
			move(enemyId .. "_signature_2", "Signature2", "TARGET_DISC", 2.2, 1.5, 55, 13, 1.4, 14.0),
		}
	elseif isElite then
		attacks = {
			move(enemyId .. "_basic", "BasicAttack", "ARC", .9, .8, 9.5, 0, 1.0, 2.4),
			move(enemyId .. "_special", "Special", "TARGET_DISC", 1.4, 1.0, 34, 9, 1.25, 8.0),
		}
	elseif isProjectile then
		attacks = {
			move(enemyId .. "_basic", "BasicAttack", "PROJECTILE", .65, .75, 32, 2.4, 1.0, 2.2, .35),
		}
	else
		attacks = {
			move(enemyId .. "_basic", "BasicAttack", "ARC", .68, .68, 7.5, 0, 1.0, 1.9),
		}
	end

	C.Entries[enemyId] = {
		EnemyId = enemyId,
		DisplayName = cat.DisplayName,
		BiomeId = cat.BiomeId,
		Role = role,
		Height = if enemyId == "mob_moss_crawler" then 3.2 else height,
		Width = cat.Bounds.Width,
		Depth = cat.Bounds.Depth,
		RootHeight = rootHeight,
		MoveSpeed = if isBoss then 7 elseif isElite then 9 elseif isProjectile then 10 else 12,
		AggroRange = if isBoss then 75 elseif isElite then 48 elseif isProjectile then 44 else 38,
		MaxHP = if isBoss then 16326 elseif isElite then 2200 else 850,
		ATK = if isBoss then 66 elseif isElite then 35 else 18,
		Gold = if isBoss then 991 elseif isElite then 210 else 80,
		RigFamily = if enemyId == "mob_moss_crawler" then "SIX_LEGGED_CRAWLER" else family,
		CatalogFamily = family,
		ModelSource = "Assets.TowerEnemyRigs",
		ClipSource = "Assets.TowerEnemyClips",
		RequiredSlots = requiredSlots,
		Attacks = attacks,
	}
end

for floorId = 1, TowerFloorConfig.FloorCount do
	local floor = assert(TowerFloorConfig.Get(floorId))
	C.Floors[floorId] = Layout.Placements(MobCatalog.Biomes[floor.BiomeIndex], floor.IndexInBiome)
end
function C.Get(id: string)
	return C.Entries[id]
end

function C.Attack(enemyId: string, attackId: string)
	local e = C.Get(enemyId)
	if e then
		for _, a in e.Attacks do
			if a.Id == attackId then
				return a
			end
		end
	end
	return nil
end

local function freeze(t: any)
	for _, v in pairs(t) do
		if type(v) == "table" and not table.isfrozen(v) then
			freeze(v)
		end
	end
	return table.freeze(t)
end

return freeze(C)
