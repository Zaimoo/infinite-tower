--!strict
-- ReplicatedStorage/Shared/Util/RewardRules.luau
-- Pure rules for the free rewards (GDD §4.8): daily calendar, weekly chest, playtime tiers, promo
-- codes and the friend boost. No Roblox services, so tests/rewards.spec.luau runs them in the CLI.
-- The server (Core/RewardsService) is the only caller that mutates a profile; the client uses the
-- read-only helpers (View, Describe, ClaimableCount) to draw the Rewards window.
--
-- State lives at profile.Rewards:
--   Daily    = { Streak, LastClaimDay }           -- UTC day numbers (floor(unix / 86400))
--   Weekly   = { LastClaimWeek }                  -- UTC week numbers, Monday-based
--   Playtime = { Day, Seconds, Claimed = { bool x tiers } }
--   Codes    = { [CODE] = true }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.RewardsConfig)

export type Reward = Config.Reward
export type State = {
	Daily: { Streak: number, LastClaimDay: number },
	Weekly: { LastClaimWeek: number },
	Playtime: { Day: number, Seconds: number, Claimed: { boolean } },
	Codes: { [string]: boolean },
}
export type View = {
	Now: number,
	DayResetsIn: number,
	WeekResetsIn: number,
	Daily: { CanClaim: boolean, Index: number, Streak: number },
	Weekly: { CanClaim: boolean },
	Playtime: { Seconds: number, Claimed: { boolean } },
}

local DAY = 86400
local WEEK = 7 * DAY
-- 1 January 1970 was a Thursday; shifting by three days puts the week boundary on Monday.
local WEEK_SHIFT = 3 * DAY

local RewardRules = {}

local function int(value: any, min: number, max: number): number
	if type(value) ~= "number" or value ~= value then return min end
	return math.clamp(math.floor(value), min, max)
end

function RewardRules.DayOf(now: number): number
	return math.floor(now / DAY)
end

function RewardRules.WeekOf(now: number): number
	return math.floor((now + WEEK_SHIFT) / WEEK)
end

function RewardRules.NewState(): State
	return {
		Daily = { Streak = 0, LastClaimDay = 0 },
		Weekly = { LastClaimWeek = 0 },
		Playtime = { Day = 0, Seconds = 0, Claimed = {} },
		Codes = {},
	}
end

-- Creates or repairs profile.Rewards. Old saves have no table; a damaged one is rebuilt field by
-- field so a bad value can never grant a reward twice or raise an error mid-claim.
function RewardRules.EnsureState(profile: any): State
	local raw = profile.Rewards
	if type(raw) ~= "table" then
		raw = {}
		profile.Rewards = raw
	end
	local daily = if type(raw.Daily) == "table" then raw.Daily else {}
	raw.Daily = daily
	daily.Streak = int(daily.Streak, 0, 1e6)
	daily.LastClaimDay = int(daily.LastClaimDay, 0, 1e7)

	local weekly = if type(raw.Weekly) == "table" then raw.Weekly else {}
	raw.Weekly = weekly
	weekly.LastClaimWeek = int(weekly.LastClaimWeek, 0, 1e7)

	local playtime = if type(raw.Playtime) == "table" then raw.Playtime else {}
	raw.Playtime = playtime
	playtime.Day = int(playtime.Day, 0, 1e7)
	playtime.Seconds = int(playtime.Seconds, 0, DAY)
	local claimed = {}
	local saved = if type(playtime.Claimed) == "table" then playtime.Claimed else {}
	for i = 1, #Config.Playtime do claimed[i] = saved[i] == true end
	playtime.Claimed = claimed

	local codes = {}
	if type(raw.Codes) == "table" then
		for code, used in raw.Codes do
			if type(code) == "string" and used == true then codes[code] = true end
		end
	end
	raw.Codes = codes
	return raw
end

-- Starts a new playtime day when the UTC day has changed. Returns true when it reset.
function RewardRules.Touch(state: State, now: number): boolean
	local day = RewardRules.DayOf(now)
	if state.Playtime.Day == day then return false end
	state.Playtime.Day = day
	state.Playtime.Seconds = 0
	for i = 1, #Config.Playtime do state.Playtime.Claimed[i] = false end
	return true
end

function RewardRules.AddPlaytime(state: State, now: number, seconds: number)
	RewardRules.Touch(state, now)
	if seconds ~= seconds or seconds <= 0 then return end
	-- Nothing unlocks past the last tier, so the counter stops there.
	local cap = Config.Playtime[#Config.Playtime].Minutes * 60
	state.Playtime.Seconds = math.min(cap, state.Playtime.Seconds + seconds)
end

-- Which calendar entry a claim made at `now` pays, and the streak it would set.
local function nextDaily(state: State, now: number): (boolean, number, number)
	local day = RewardRules.DayOf(now)
	local last = state.Daily.LastClaimDay
	if day <= last then
		-- Already claimed today: show the entry that was just paid.
		local streak = math.max(1, state.Daily.Streak)
		return false, (streak - 1) % #Config.Daily + 1, streak
	end
	local streak = if day == last + 1 then state.Daily.Streak + 1 else 1
	return true, (streak - 1) % #Config.Daily + 1, streak
end

function RewardRules.ClaimDaily(state: State, now: number): (Reward?, string?)
	local canClaim, index, streak = nextDaily(state, now)
	if not canClaim then return nil, "Already claimed today." end
	state.Daily.Streak = streak
	state.Daily.LastClaimDay = RewardRules.DayOf(now)
	return Config.Daily[index], nil
end

function RewardRules.ClaimWeekly(state: State, now: number): (Reward?, string?)
	local week = RewardRules.WeekOf(now)
	if week <= state.Weekly.LastClaimWeek then return nil, "Already claimed this week." end
	state.Weekly.LastClaimWeek = week
	return Config.Weekly, nil
end

function RewardRules.ClaimPlaytime(state: State, now: number, index: any): (Reward?, string?)
	RewardRules.Touch(state, now)
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then return nil, "Unknown reward." end
	local tier = Config.Playtime[index]
	if not tier then return nil, "Unknown reward." end
	if state.Playtime.Claimed[index] then return nil, "Already claimed today." end
	if state.Playtime.Seconds < tier.Minutes * 60 then return nil, "Keep playing to unlock this reward." end
	state.Playtime.Claimed[index] = true
	return tier.Reward, nil
end

-- Uppercase letters and digits only; nil when the input cannot be a code.
function RewardRules.NormalizeCode(raw: any): string?
	if type(raw) ~= "string" or #raw > Config.MaxCodeLength * 2 then return nil end
	local code = string.upper((string.gsub(raw, "[%s%-_]", "")))
	if code == "" or #code > Config.MaxCodeLength or string.find(code, "[^A-Z0-9]") then return nil end
	return code
end

-- `codes` is the server's list (Core/RewardCodes). An unknown code and a malformed one give the
-- same answer, so replies never reveal which strings are close to a real code.
function RewardRules.RedeemCode(state: State, now: number, raw: any, codes: { [string]: any }): (Reward?, string?, string?)
	local code = RewardRules.NormalizeCode(raw)
	local entry = code and codes[code]
	if not code or type(entry) ~= "table" then return nil, "That code isn't valid.", nil end
	if state.Codes[code] then return nil, "You already redeemed that code.", nil end
	if type(entry.Expires) == "number" and now >= entry.Expires then return nil, "That code has expired.", nil end
	state.Codes[code] = true
	return entry.Reward, nil, code
end

-- Adds a reward to the profile's balances.
function RewardRules.Grant(profile: any, reward: Reward)
	profile.Currencies = profile.Currencies or {}
	if reward.Gold then profile.Currencies.Gold = (profile.Currencies.Gold or 0) + reward.Gold end
	if reward.Gems then profile.Currencies.Gems = (profile.Currencies.Gems or 0) + reward.Gems end
	if reward.PromotionStones then
		profile.PitMaterials = profile.PitMaterials or {}
		profile.PitMaterials.PromotionStone = (profile.PitMaterials.PromotionStone or 0) + reward.PromotionStones
	end
end

local function grouped(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then break end
	end
	return s
end

-- "+500 Gold · +20 Gems". `plus` false drops the signs (for reward cards).
function RewardRules.Describe(reward: Reward, plus: boolean?): string
	local sign = if plus == false then "" else "+"
	local parts = {}
	if reward.Gems then table.insert(parts, string.format("%s%s Gems", sign, grouped(reward.Gems))) end
	if reward.Gold then table.insert(parts, string.format("%s%s Gold", sign, grouped(reward.Gold))) end
	if reward.PromotionStones then
		table.insert(parts, string.format("%s%d Promotion Stone%s", sign, reward.PromotionStones, if reward.PromotionStones == 1 then "" else "s"))
	end
	return table.concat(parts, " · ")
end

-- Gold multiplier for `friends` Roblox friends in the same server.
function RewardRules.FriendBoost(friends: number): number
	if friends ~= friends then return 1 end
	local counted = math.clamp(math.floor(friends), 0, Config.FriendBoost.MaxFriends)
	return 1 + counted * Config.FriendBoost.PerFriend
end

-- What the client needs to draw the window. Does not mutate `state`.
function RewardRules.View(state: State, now: number): View
	local canDaily, index, streak = nextDaily(state, now)
	local today = state.Playtime.Day == RewardRules.DayOf(now)
	local claimed = {}
	for i = 1, #Config.Playtime do claimed[i] = today and state.Playtime.Claimed[i] == true end
	return {
		Now = now,
		DayResetsIn = DAY - now % DAY,
		WeekResetsIn = WEEK - (now + WEEK_SHIFT) % WEEK,
		Daily = { CanClaim = canDaily, Index = index, Streak = if canDaily then streak - 1 else streak },
		Weekly = { CanClaim = RewardRules.WeekOf(now) > state.Weekly.LastClaimWeek },
		Playtime = { Seconds = if today then state.Playtime.Seconds else 0, Claimed = claimed },
	}
end

-- Rewards ready to claim in a view; `extraSeconds` is playtime the client has counted since the view.
function RewardRules.ClaimableCount(view: View, extraSeconds: number?): number
	local count = 0
	if view.Daily.CanClaim then count += 1 end
	if view.Weekly.CanClaim then count += 1 end
	local seconds = view.Playtime.Seconds + (extraSeconds or 0)
	for i, tier in Config.Playtime do
		if not view.Playtime.Claimed[i] and seconds >= tier.Minutes * 60 then count += 1 end
	end
	return count
end

-- "2d 4h", "3h 12m", "4m 09s".
function RewardRules.FormatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= DAY then return string.format("%dd %dh", s // DAY, s % DAY // 3600) end
	if s >= 3600 then return string.format("%dh %02dm", s // 3600, s % 3600 // 60) end
	return string.format("%dm %02ds", s // 60, s % 60)
end

return RewardRules
