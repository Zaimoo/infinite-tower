--!strict
-- ReplicatedStorage/Shared/Config/BattlePassConfig.luau
-- The Battle Pass (GDD §4.9): a seasonal track of 30 levels with two reward rows.
--   * Free row: every player.
--   * Premium row: unlocked for the current season by a Robux purchase (ShopConfig.Pass). Buying it
--     late still pays every premium reward up to the level already reached.
--
-- Seasons run back to back on the UTC clock: season N starts at Epoch + (N - 1) * SeasonDays. A new
-- season resets XP, claims and Premium; rewards that were unlocked but not claimed are delivered
-- at the rollover, so nothing earned is lost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)

export type Reward = RewardsConfig.Reward

local BattlePassConfig = {}

-- Monday 16 November 2026, 00:00 UTC: the start of Season 1.
BattlePassConfig.Epoch = 1794787200
BattlePassConfig.SeasonDays = 28

-- Season names cycle in this order.
BattlePassConfig.SeasonNames = table.freeze({ "Rift Awakening", "Ashen Crown", "Tidebound", "Starfall Vigil" })

BattlePassConfig.MaxLevel = 30
BattlePassConfig.XpPerLevel = 1000

-- Battle Pass XP per action. The Pass XP Potion multiplies all of them.
BattlePassConfig.Xp = table.freeze({
	KillRegular = 5,
	KillElite = 20,
	KillAlpha = 60,
	FloorBoss = 60, -- a floor's boss (floors 1-4 of a biome)
	BiomeBoss = 150, -- every fifth floor
	FirstClear = 100, -- added the first time a floor is cleared
	RelicBanked = 25,
	Raid = 200, -- a raid the player qualified for
	DailyClaim = 150,
	WeeklyClaim = 500,
	PlaytimeClaim = 30,
} :: { [string]: number })

-- A second Premium purchase in the same season (it can only come from a retried or gifted receipt;
-- the window hides the button) is paid as this many levels of XP instead.
BattlePassConfig.DuplicatePremiumLevels = 10

BattlePassConfig.Free = table.freeze({
	{ Gold = 2000 },
	{ Potions = { GoldPotion = 1 } },
	{ Gems = 30 },
	{ Gold = 4000 },
	{ PromotionStones = 1 },
	{ Potions = { XpPotion = 1 } },
	{ Gold = 6000 },
	{ Gems = 40 },
	{ Potions = { LuckPotion = 1 } },
	{ Gems = 100, PromotionStones = 2 },
	{ Gold = 8000 },
	{ Potions = { GemPotion = 1 } },
	{ Gems = 50 },
	{ Gold = 10000 },
	{ PromotionStones = 2 },
	{ Potions = { PassXpPotion = 1 } },
	{ Gold = 12000 },
	{ Gems = 60 },
	{ Potions = { GoldPotion = 1 } },
	{ Gems = 150, PromotionStones = 3 },
	{ Gold = 15000 },
	{ Potions = { XpPotion = 1 } },
	{ Gems = 70 },
	{ Gold = 18000 },
	{ PromotionStones = 3 },
	{ Potions = { LuckPotion = 1 } },
	{ Gold = 22000 },
	{ Gems = 80 },
	{ Potions = { GemPotion = 1 } },
	{ Gems = 300, PromotionStones = 5 },
} :: { Reward })

BattlePassConfig.Premium = table.freeze({
	{ Gems = 200, Potions = { GoldPotion = 2 } },
	{ Gold = 8000 },
	{ Potions = { GemPotion = 1 } },
	{ Gems = 100 },
	{ PromotionStones = 3 },
	{ Potions = { LuckPotion = 2 } },
	{ Gold = 15000 },
	{ Gems = 120 },
	{ Potions = { XpPotion = 2 } },
	{ Gems = 300, PromotionStones = 5 },
	{ Gold = 20000 },
	{ Potions = { GoldPotion = 2 } },
	{ Gems = 150 },
	{ Potions = { PassXpPotion = 2 } },
	{ PromotionStones = 5 },
	{ Gems = 180 },
	{ Gold = 30000 },
	{ Potions = { GemPotion = 2 } },
	{ Gems = 200 },
	{ Gems = 500, PromotionStones = 8 },
	{ Gold = 40000 },
	{ Potions = { LuckPotion = 2 } },
	{ Gems = 220 },
	{ Potions = { XpPotion = 2 } },
	{ PromotionStones = 8 },
	{ Gems = 250 },
	{ Gold = 60000 },
	{ Potions = { GoldPotion = 3, GemPotion = 3 } },
	{ Gems = 300 },
	{ Gems = 1000, PromotionStones = 12, Potions = { LuckPotion = 3 } },
} :: { Reward })

assert(#BattlePassConfig.Free == BattlePassConfig.MaxLevel, "BattlePassConfig: the free row needs one reward per level")
assert(#BattlePassConfig.Premium == BattlePassConfig.MaxLevel, "BattlePassConfig: the premium row needs one reward per level")
assert(BattlePassConfig.Epoch % 86400 == 0, "BattlePassConfig: seasons start at 00:00 UTC")

return BattlePassConfig
