--!strict
-- The Pit's tunable economy. Gems are the existing crystallized mana currency.
local Config = {}

Config.MaxDonors = 100
Config.MaxStars = 5
Config.PreviewLifetime = 45
Config.PreviewCooldown = 0.12
Config.StateCooldown = 0.4
Config.LockCooldown = 0.15
Config.RareConfirmationStars = 5
Config.SchemaVersion = 2
Config.Synthesis = {
	BaseXP = 100,
	StarMultiplier = 3,
	LevelXP = 25,
	EfficiencyGrace = 5,
	EfficiencyLossPerLevel = 0.025,
	MinimumEfficiency = 0.55,
	ResearchBonus = 0.10,
	AffinityBonus = 0.05,
	OverflowNextLevels = 2,
	FocusedXPScale = 0.5,
}
Config.Promotion = {
	CombatMultiplier = 3,
	LaborMultiplier = 1.35,
	[1] = { Gold = 1500, PromotionStone = 1 },
	[2] = { Gold = 7500, PromotionStone = 3 },
	[3] = { Gold = 35000, PromotionStone = 8 },
	[4] = { Gold = 150000, PromotionStone = 18 },
}
Config.Conversion = {
	BaseEssence = { [1] = 4, [2] = 12, [3] = 36, [4] = 108, [5] = 324 },
	LevelsPerBonus = 5,
	EssencePerInvestmentLevel = 1,
	EssencePerImprintRank = 2,
}
Config.Recipes = {
	PromotionStone = { Name = "Promotion Stone", Gold = 100, Gems = 20, SoulEssence = 8, Output = 1 },
	ImprintCatalyst = { Name = "Imprint Catalyst", Gold = 150, Gems = 15, SoulEssence = 4, Output = 1 },
}
Config.Imprints = {
	GoldCost = 200,
	CatalystCost = 1,
	MaxRank = 3,
	SlotsByStar = { 1, 1, 2, 2, 3 },
	BonusCaps = { ATK = 0.12, HP = 0.12, Labor = 0.15 },
	Definitions = {
		melee_memory = { Name = "Blade Discipline", Category = "Combat", Description = "+2% ATK per rank for melee specialists.", DonorRoles = { Striker = true }, RecipientRoles = { Striker = true, Vanguard = true }, Effect = { ATK = 0.02 } },
		ranged_memory = { Name = "Measured Aim", Category = "Combat", Description = "+2% ATK per rank for ranged specialists.", DonorRoles = { Marksman = true }, RecipientRoles = { Marksman = true, Scholar = true }, Effect = { ATK = 0.02 } },
		bulwark_memory = { Name = "Guardian's Memory", Category = "Combat", Description = "+3% HP per rank for defensive specialists.", DonorRoles = { Vanguard = true }, RecipientRoles = { Vanguard = true, Healer = true }, Effect = { HP = 0.03 } },
		conduit_memory = { Name = "Labor Stewardship", Category = "Utility", Description = "+3% labor per rank for facility specialists.", DonorRoles = { Miner = true }, RecipientRoles = { Miner = true, Striker = true }, Effect = { Labor = 0.03 } },
		scholarly_memory = { Name = "Runic Method", Category = "Rare Trait", Description = "+3% labor and +1% ATK per rank.", DonorRoles = { Scholar = true }, RecipientRoles = { Scholar = true, Marksman = true }, Effect = { Labor = 0.03, ATK = 0.01 }, MinimumStars = 2 },
		restorative_memory = { Name = "Steady Recovery", Category = "Utility", Description = "+2% HP and +2% labor per rank for supportive specialists.", DonorRoles = { Healer = true }, RecipientRoles = { Healer = true, Vanguard = true }, Effect = { HP = 0.02, Labor = 0.02 } },
	},
}
Config.CombatXP = { Ring1 = 25, Ring2 = 65, Boss = 150, MaxGrant = 150, Cooldown = 8,
	ActivityWindow = 45, ParticipationWindow = 15, MinimumDamageFraction = 0.02, AwardCooldown = 8 }

return Config
