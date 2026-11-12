--!strict
-- ReplicatedStorage/Shared/Config/RewardsConfig.luau
-- Free rewards (GDD §4.8): the daily login calendar, the weekly chest, playtime rewards and the
-- friend boost. Promo codes are NOT here: clients can read this module, so the code list lives on
-- the server (ServerScriptService/Core/RewardCodes).
--
-- All resets use UTC: days roll over at 00:00 UTC and weeks on Monday 00:00 UTC.

export type Reward = { Gold: number?, Gems: number?, PromotionStones: number? }
export type PlaytimeTier = { Minutes: number, Reward: Reward }

local RewardsConfig = {}

-- Daily login calendar. One claim per UTC day. Claiming on consecutive days walks through the
-- seven entries and then loops; missing a day restarts at Day 1.
RewardsConfig.Daily = table.freeze({
	table.freeze({ Gold = 2000 }),
	table.freeze({ Gems = 50 }),
	table.freeze({ Gold = 5000 }), -- one Forge pull
	table.freeze({ PromotionStones = 2 }),
	table.freeze({ Gems = 100 }), -- one Call of the Rift pull
	table.freeze({ Gold = 10000 }),
	table.freeze({ Gems = 300, PromotionStones = 3 }), -- three Call of the Rift pulls
} :: { Reward })

-- Weekly chest. One claim per UTC week (Monday to Sunday).
RewardsConfig.Weekly = table.freeze({ Gold = 30000, Gems = 500, PromotionStones = 5 } :: Reward)

-- Playtime rewards. Time played today (UTC) unlocks each tier once; everything resets at 00:00 UTC.
-- At most 7 tiers, and the last one is at most 60 minutes (checked below).
RewardsConfig.Playtime = table.freeze({
	table.freeze({ Minutes = 5, Reward = table.freeze({ Gold = 1000 }) }),
	table.freeze({ Minutes = 10, Reward = table.freeze({ Gems = 25 }) }),
	table.freeze({ Minutes = 15, Reward = table.freeze({ Gold = 2500 }) }),
	table.freeze({ Minutes = 20, Reward = table.freeze({ Gems = 40 }) }),
	table.freeze({ Minutes = 30, Reward = table.freeze({ PromotionStones = 2 }) }),
	table.freeze({ Minutes = 45, Reward = table.freeze({ Gold = 5000 }) }),
	table.freeze({ Minutes = 60, Reward = table.freeze({ Gems = 100 }) }),
} :: { PlaytimeTier })

RewardsConfig.MaxPlaytimeTiers = 7
RewardsConfig.MaxPlaytimeMinutes = 60

-- Friend boost: every Roblox friend in the same server raises the Gold from kills, floor bosses
-- and banked relics. Gems, Promotion Stones and drop chances are not affected.
RewardsConfig.FriendBoost = table.freeze({
	PerFriend = 0.10,
	MaxFriends = 3, -- +30% at most
})

RewardsConfig.MaxCodeLength = 24

assert(#RewardsConfig.Daily == 7, "RewardsConfig: the daily calendar has 7 days")
assert(#RewardsConfig.Playtime <= RewardsConfig.MaxPlaytimeTiers, "RewardsConfig: at most 7 playtime tiers")
do
	local last = 0
	for _, tier in RewardsConfig.Playtime do
		assert(tier.Minutes > last, "RewardsConfig: playtime tiers must ascend")
		last = tier.Minutes
	end
	assert(last <= RewardsConfig.MaxPlaytimeMinutes, "RewardsConfig: playtime tiers end within 60 minutes")
end

return RewardsConfig
