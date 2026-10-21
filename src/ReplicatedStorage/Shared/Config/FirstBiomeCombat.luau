--!strict
-- Executable Part 3 slice. The other 37 designs remain in the proposal catalog.
-- Combat is enabled on the two slice floors. Final art/animation polish is a later sprint.
local C: any = { ReleaseEnabled = true, RespawnSeconds = 25, BossRespawnSeconds = 300,
	AnchorLocal = Vector3.new(0, 0, 12), AcquisitionRange = 95, LeashRange = 105,
	-- Native articulated parts and authored pose clips; no uploaded IDs are implied.
	AssetStatus = "LOCAL_AUTHORED_UNVERIFIED", PublishedAccess = "NOT_VERIFIED", Entries = {}, Floors = {} }
local function move(id, slot, shape, windup, recovery, range, radius, damage, cooldown)
	return { Id=id, AnimationKey=slot, Shape=shape, WindupSeconds=windup, ImpactOffsetSeconds=windup,
		RecoverySeconds=recovery, Range=range, Radius=radius, HalfArcCos=.05, DamageMultiplier=damage,
		CooldownSeconds=cooldown, MaxLatenessSeconds=.45, TargetRule="QUALIFIED_LIVE_UNSAFE_SAME_ROOM",
		ImpactRule="SCHEDULED_SERVER_SHAPE_ONCE", TelegraphGeometry=shape }
end
C.Entries.mob_moss_crawler = { EnemyId="mob_moss_crawler", Role="REGULAR", Height=3.2, RootHeight=1.3,
	MoveSpeed=12, AggroRange=38, MaxHP=850, ATK=18, Gold=80,
	RigFamily="SIX_LEGGED_CRAWLER", ModelSource="Assets.TowerEnemyRigs", ClipSource="Assets.TowerEnemyClips",
	RequiredSlots={"Idle","Locomotion","BasicAttack","HitReaction","Death"},
	Attacks={move("moss_bite","BasicAttack","ARC",.65,.65,7,0,1,1.8)} }
C.Entries.elite_vinebound = { EnemyId="elite_vinebound", Role="ELITE", Height=8, RootHeight=4.3,
	MoveSpeed=9, AggroRange=48, MaxHP=2200, ATK=35, Gold=210,
	RigFamily="ROOTED_BIPED", ModelSource="Assets.TowerEnemyRigs", ClipSource="Assets.TowerEnemyClips",
	RequiredSlots={"Idle","Locomotion","BasicAttack","HitReaction","Death","Special"},
	Attacks={move("vine_cleave","BasicAttack","ARC",.9,.8,9,0,1,2.4),
		move("root_bloom","Special","TARGET_DISC",1.4,1,34,9,1.25,8)} }
C.Entries.boss_mossbound_guardian = { EnemyId="boss_mossbound_guardian", Role="BOSS", Height=17, RootHeight=8.5,
	MoveSpeed=7, AggroRange=75, MaxHP=16326, ATK=66, Gold=991,
	RigFamily="STONE_COLOSSUS", ModelSource="Assets.TowerEnemyRigs", ClipSource="Assets.TowerEnemyClips",
	RequiredSlots={"Idle","Locomotion","BasicAttack","HitReaction","Death","Awakening","Signature1","Signature2"},
	Attacks={move("guardian_crush","BasicAttack","ARC",1.1,1,13,0,1,3),
		move("moss_quake","Signature1","SELF_DISC",1.8,1.2,22,22,1.2,10),
		move("sweeping_roots","Signature2","TARGET_DISC",2.2,1.5,55,13,1.4,14)} }
C.Floors[1] = { {EnemyId="mob_moss_crawler",X=-16,Z=8}, {EnemyId="mob_moss_crawler",X=18,Z=-12},
	{EnemyId="mob_moss_crawler",X=-28,Z=-34}, {EnemyId="elite_vinebound",X=22,Z=-48} }
C.Floors[5] = { {EnemyId="mob_moss_crawler",X=-28,Z=8}, {EnemyId="mob_moss_crawler",X=28,Z=8},
	{EnemyId="elite_vinebound",X=-38,Z=-24}, {EnemyId="boss_mossbound_guardian",X=0,Z=-54} }
function C.Get(id) return C.Entries[id] end
function C.Attack(enemyId, attackId)
	local e=C.Get(enemyId);if e then for _,a in e.Attacks do if a.Id==attackId then return a end end end
	return nil
end
local function freeze(t)
	for _,v in pairs(t) do if type(v)=="table" and not table.isfrozen(v) then freeze(v) end end
	return table.freeze(t)
end
return freeze(C)
