--!strict
-- ServerScriptService/Core/RewardCodes.luau
-- Promo codes (GDD §4.8). Server-only on purpose: anything under ReplicatedStorage can be read by
-- an exploiter, so the list must never move there.
--
-- Keys are UPPERCASE letters and digits (players may type any case, with spaces). Each profile can
-- redeem a code once. `Expires` is an optional Unix time (UTC) after which the code stops working.
-- To retire a code, set Expires in the past rather than deleting it, so the key is never reused
-- for a second payout.

export type Code = { Reward: { Gold: number?, Gems: number?, PromotionStones: number? }, Expires: number? }

local RewardCodes: { [string]: Code } = {
	WELCOME = { Reward = { Gems = 300, Gold = 5000 } },
	TOWER = { Reward = { Gold = 15000, PromotionStones = 3 } },
	MASTER = { Reward = { Gems = 150 } },
}

return RewardCodes
