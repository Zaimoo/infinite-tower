--!strict
-- The Pit's tunable economy. Gems are the existing crystallized mana currency.
local Config = {}

Config.MaxDonors = 100
Config.MaxStars = 7
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
	-- Gold cost: every point of EXP fed into the recipient costs GoldPerXP Gold (rounded up), at least
	-- MinimumGold per synthesis. A 1★ Lv 1 donor (125 EXP) costs 125 Gold.
	GoldPerXP = 1,
	MinimumGold = 50,
}
Config.Promotion = {
	CombatMultiplier = 1.5, -- matches StatBalance.HeroPromotionMultiplier (heroes are summoned at 1★)
	LaborMultiplier = 1.35,
	[1] = { Gold = 1500, PromotionStone = 1 },
	[2] = { Gold = 7500, PromotionStone = 3 },
	[3] = { Gold = 35000, PromotionStone = 8 },
	[4] = { Gold = 150000, PromotionStone = 18 },
	[5] = { Gold = 450000, PromotionStone = 40 },
	[6] = { Gold = 1250000, PromotionStone = 85 },
}
Config.CombatXP = { Ring1 = 25, Ring2 = 65, Boss = 150, MaxGrant = 150, Cooldown = 8,
	ActivityWindow = 45, ParticipationWindow = 15, MinimumDamageFraction = 0.02, AwardCooldown = 8 }

return Config
