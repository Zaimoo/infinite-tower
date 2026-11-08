--!strict
-- Raid Bosses (docs/raid-boss-plan.md). Every 30 minutes (wall clock, UTC :00 and :30) a raid boss
-- spawns in its own off-map arena, reached through the Raid Portal in the Cloister Commons.
-- RaidService runs the cycle and publishes it as ReplicatedStorage attributes; RaidRules holds the
-- pure math (schedule, HP budget, rewards) so it can be spec-tested.

export type Attack = {
	Id: string,
	DisplayName: string,
	Shape: "ARC" | "SELF_DISC" | "TARGET_DISC" | "PROJECTILE",
	Radius: number, -- studs (ARC: reach, PROJECTILE: corridor length)
	Windup: number, -- seconds
	DamageMult: number, -- x the boss's per-hit damage
	Count: number?, -- TARGET_DISC: how many heroes are targeted at once
	ArcDegrees: number?, -- ARC width (default 100)
	Signature: boolean?, -- opens a Punish Window when it lands
}

export type Boss = {
	Id: string,
	DisplayName: string,
	Title: string,
	Model: string, -- asset name in assets/models/raid (and RaidBossAssets)
	Root: string, -- root segment of the rig
	Accent: Color3, -- Neon/glow colour, portal tint and arena light
	Arena: { Floor: Color3, Trim: Color3, Fog: Color3 },
	Height: number, -- studs, for nameplates and hitbox
	HitRadius: number, -- studs from the boss centre that heroes attack from
	HoverHeight: number?, -- floating bosses (studs above the floor)
	MoveSpeed: number,
	AttackInterval: number, -- seconds between basic attacks
	Basic: Attack,
	Signatures: { Attack },
	Enrage: Attack,
	Adds: { Count: number, Template: string }?, -- Broodmother spiderlings on enrage (enemy id)
}

local Config = {}

-- Timings (seconds)
Config.IntervalSeconds = 1800
Config.WarningSeconds = 60
Config.ActiveSeconds = 300
Config.ResultsSeconds = 12
Config.LateJoinCutoffSeconds = 30 -- entry closes this long before the end
-- Studio: workspace.RaidFast = true
Config.Fast = { WarningSeconds = 5, ActiveSeconds = 30, ResultsSeconds = 6, LateJoinCutoffSeconds = 5 }

-- HP budget: every participant adds squadDPS x ActiveSeconds x HpFactor
Config.HpFactor = 0.75
Config.MinDPS = 25
Config.EnrageHPFraction = 0.5
Config.EnrageAtSeconds = 180
Config.EnrageAttackSpeed = 1.25
Config.PunishSeconds = 4
Config.PunishDamageTaken = 1.25

-- Rewards
Config.MaxGems = 2000
Config.MinShareCurve = 0.10 -- every qualifier gets at least this fraction
Config.ShareExponent = 0.6
Config.QualifyFractionOfMaxHP = 0.005
Config.QualifyTopN = 10
Config.GoldPerGem = 25
Config.KillUrnTopN = 3
Config.KillHeartChance = 0.10

-- World
Config.FloorId = 60 -- room-local protocol stores FloorId as a u8
Config.ArenaOrigin = Vector3.new(-14000, 1000, -14000)
Config.ArenaRadius = 160
Config.StagingDepth = 30
Config.PortalPromptDistance = 16
Config.BoardHz = 2
Config.BoardRows = 8
Config.LeaveCooldown = 2

-- Bosses. Rotation order is this list's order (RaidRules.BossFor).
Config.Bosses = table.freeze({
	table.freeze({
		Id = "HOLLOW_KING", DisplayName = "Vorthak", Title = "the Hollow King", Model = "HollowKing", Root = "Hips",
		Accent = Color3.fromRGB(255, 46, 58),
		Arena = { Floor = Color3.fromRGB(34, 30, 38), Trim = Color3.fromRGB(150, 110, 52), Fog = Color3.fromRGB(70, 12, 18) },
		Height = 34, HitRadius = 7, MoveSpeed = 10, AttackInterval = 2.4,
		Basic = { Id = "GREATSWORD_CLEAVE", DisplayName = "Greatsword Cleave", Shape = "ARC", Radius = 14, Windup = 0.9, DamageMult = 1 },
		Signatures = {
			{ Id = "ROYAL_DECREE", DisplayName = "Royal Decree", Shape = "TARGET_DISC", Radius = 10, Windup = 1.8, DamageMult = 2.5, Count = 3, Signature = true },
			{ Id = "THRONE_QUAKE", DisplayName = "Throne Quake", Shape = "SELF_DISC", Radius = 24, Windup = 2.0, DamageMult = 3, Signature = true },
		},
		Enrage = { Id = "CRIMSON_EXECUTION", DisplayName = "Crimson Execution", Shape = "ARC", Radius = 20, Windup = 1.6, DamageMult = 3.5, ArcDegrees = 270, Signature = true },
	}),
	table.freeze({
		Id = "THOUSAND_EYED", DisplayName = "Ozrith", Title = "the Thousand-Eyed", Model = "ThousandEyed", Root = "Body",
		Accent = Color3.fromRGB(186, 96, 255),
		Arena = { Floor = Color3.fromRGB(28, 22, 40), Trim = Color3.fromRGB(60, 200, 180), Fog = Color3.fromRGB(40, 16, 70) },
		Height = 27, HitRadius = 8, HoverHeight = 4, MoveSpeed = 8, AttackInterval = 2.0,
		Basic = { Id = "GAZE_BOLT", DisplayName = "Gaze Bolt", Shape = "PROJECTILE", Radius = 40, Windup = 0.8, DamageMult = 1 },
		Signatures = {
			{ Id = "EYE_RAIN", DisplayName = "Eye Rain", Shape = "TARGET_DISC", Radius = 7, Windup = 1.6, DamageMult = 2, Count = 5, Signature = true },
			{ Id = "VOID_PULSE", DisplayName = "Void Pulse", Shape = "SELF_DISC", Radius = 22, Windup = 1.9, DamageMult = 3, Signature = true },
		},
		Enrage = { Id = "UNBLINKING_RAY", DisplayName = "Unblinking Ray", Shape = "PROJECTILE", Radius = 60, Windup = 1.4, DamageMult = 4, Signature = true },
	}),
	table.freeze({
		Id = "BROODMOTHER", DisplayName = "Xal'Zhara", Title = "the Rift Broodmother", Model = "Broodmother", Root = "Thorax",
		Accent = Color3.fromRGB(126, 255, 74),
		Arena = { Floor = Color3.fromRGB(26, 32, 24), Trim = Color3.fromRGB(184, 192, 152), Fog = Color3.fromRGB(24, 50, 18) },
		Height = 20, HitRadius = 10, MoveSpeed = 12, AttackInterval = 1.8,
		Basic = { Id = "FANG_STRIKE", DisplayName = "Fang Strike", Shape = "ARC", Radius = 12, Windup = 0.7, DamageMult = 1 },
		Signatures = {
			{ Id = "VENOM_SPIT", DisplayName = "Venom Spit", Shape = "TARGET_DISC", Radius = 11, Windup = 1.5, DamageMult = 2.5, Count = 2, Signature = true },
			{ Id = "WEB_BURST", DisplayName = "Web Burst", Shape = "SELF_DISC", Radius = 20, Windup = 1.8, DamageMult = 3, Signature = true },
		},
		Enrage = { Id = "BROOD_SWARM", DisplayName = "Brood Swarm", Shape = "SELF_DISC", Radius = 16, Windup = 2.2, DamageMult = 2, Signature = true },
		Adds = { Count = 6, Template = "mob_moss_crawler" }, -- FirstBiomeCombat enemy id
	}),
	table.freeze({
		Id = "SHARDBOUND", DisplayName = "Aurelith", Title = "the Shardbound Colossus", Model = "Shardbound", Root = "Pelvis",
		Accent = Color3.fromRGB(84, 226, 255),
		Arena = { Floor = Color3.fromRGB(30, 36, 46), Trim = Color3.fromRGB(222, 180, 86), Fog = Color3.fromRGB(18, 52, 70) },
		Height = 30, HitRadius = 9, MoveSpeed = 9, AttackInterval = 2.6,
		Basic = { Id = "CRYSTAL_SLAM", DisplayName = "Crystal Slam", Shape = "ARC", Radius = 13, Windup = 1.0, DamageMult = 1.1 },
		Signatures = {
			{ Id = "SHARD_VOLLEY", DisplayName = "Shard Volley", Shape = "PROJECTILE", Radius = 36, Windup = 1.1, DamageMult = 2, Count = 3, Signature = true },
			{ Id = "PRISM_QUAKE", DisplayName = "Prism Quake", Shape = "SELF_DISC", Radius = 26, Windup = 2.1, DamageMult = 3, Signature = true },
		},
		Enrage = { Id = "CORE_OVERLOAD", DisplayName = "Core Overload", Shape = "SELF_DISC", Radius = 26, Windup = 1.6, DamageMult = 3.5, Signature = true },
	}),
}) :: { Boss }

function Config.Get(id: string): Boss?
	for _, boss in Config.Bosses do
		if boss.Id == id then return boss end
	end
	return nil
end

function Config.FullName(boss: Boss): string
	return `{boss.DisplayName}, {boss.Title}`
end

return table.freeze(Config)
