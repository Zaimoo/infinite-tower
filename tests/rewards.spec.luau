--!strict
-- tests/rewards.spec.luau
-- Free rewards (GDD §4.8): daily calendar, weekly chest, playtime tiers, promo codes and the
-- friend boost (RewardRules + RewardsConfig + the server's RewardCodes).

local Config = require(nodes["ReplicatedStorage.Shared.Config.RewardsConfig"])
local Rules = require(nodes["ReplicatedStorage.Shared.Util.RewardRules"])
local Codes = require(nodes["ServerScriptService.Core.RewardCodes"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local DAY = 86400
-- Monday 5 January 2026, 00:00 UTC.
local MONDAY = 1767571200

test("rewards: the calendar has 7 days and playtime has at most 7 tiers within one hour", function()
	assert(#Config.Daily == 7, "7 daily entries")
	assert(#Config.Playtime <= 7, "at most 7 playtime tiers")
	assert(Config.Playtime[#Config.Playtime].Minutes <= 60, "last tier within 60 minutes")
	assert(MONDAY % DAY == 0 and Rules.WeekOf(MONDAY) == Rules.WeekOf(MONDAY - 1) + 1, "weeks start on Monday 00:00 UTC")
	assert(Rules.WeekOf(MONDAY + 7 * DAY - 1) == Rules.WeekOf(MONDAY), "Sunday night is the same week")
end)

test("rewards: daily claims once per UTC day, walks the calendar and loops", function()
	local state = Rules.NewState()
	for i = 1, 8 do
		local now = MONDAY + (i - 1) * DAY + 3600
		local view = Rules.View(state, now)
		assert(view.Daily.CanClaim and view.Daily.Index == (i - 1) % 7 + 1, "day " .. i .. " is offered")
		local reward = Rules.ClaimDaily(state, now)
		assert(reward == Config.Daily[(i - 1) % 7 + 1], "day " .. i .. " pays its entry")
		local again, problem = Rules.ClaimDaily(state, now + 60)
		assert(again == nil and problem ~= nil, "second claim the same day is refused")
		assert(not Rules.View(state, now + 60).Daily.CanClaim, "view shows it claimed")
	end
	assert(state.Daily.Streak == 8, "streak counts every consecutive day")
end)

test("rewards: a missed day restarts the calendar at Day 1", function()
	local state = Rules.NewState()
	Rules.ClaimDaily(state, MONDAY)
	Rules.ClaimDaily(state, MONDAY + DAY)
	local view = Rules.View(state, MONDAY + 3 * DAY)
	assert(view.Daily.CanClaim and view.Daily.Index == 1 and view.Daily.Streak == 0, "streak lost after a gap")
	assert(Rules.ClaimDaily(state, MONDAY + 3 * DAY) == Config.Daily[1] and state.Daily.Streak == 1, "restarts at Day 1")
	-- A clock that moved backwards can never open a second claim.
	assert(Rules.ClaimDaily(state, MONDAY + 2 * DAY) == nil, "earlier day is refused")
end)

test("rewards: the weekly chest pays once per Monday-based week", function()
	local state = Rules.NewState()
	assert(Rules.ClaimWeekly(state, MONDAY + 2 * DAY) == Config.Weekly, "first claim")
	assert(Rules.ClaimWeekly(state, MONDAY + 6 * DAY + DAY - 1) == nil, "same week refused")
	local view = Rules.View(state, MONDAY + 6 * DAY)
	assert(not view.Weekly.CanClaim and view.WeekResetsIn == DAY, "one day until the reset")
	assert(Rules.ClaimWeekly(state, MONDAY + 7 * DAY) == Config.Weekly, "next Monday pays again")
end)

test("rewards: playtime tiers unlock by time played, pay once and reset daily", function()
	local state = Rules.NewState()
	local now = MONDAY + 100
	Rules.AddPlaytime(state, now, 299)
	local early, problem = Rules.ClaimPlaytime(state, now, 1)
	assert(early == nil and problem ~= nil, "5 minute tier is locked at 4:59")
	Rules.AddPlaytime(state, now, 1)
	assert(Rules.ClaimPlaytime(state, now, 1) == Config.Playtime[1].Reward, "unlocks at 5:00")
	assert(Rules.ClaimPlaytime(state, now, 1) == nil, "pays once")
	for _, bad in { 0, 8, 1.5, -1, 0 / 0, "1", {} } do
		assert(Rules.ClaimPlaytime(state, now, bad :: any) == nil, "bad index is refused")
	end
	Rules.AddPlaytime(state, now, 10 * 3600)
	assert(state.Playtime.Seconds == 3600, "counter stops at the last tier")
	assert(Rules.ClaimableCount(Rules.View(state, now)) == #Config.Playtime - 1 + 2, "six tiers plus daily and weekly are ready")
	for i = 2, #Config.Playtime do assert(Rules.ClaimPlaytime(state, now, i), "tier " .. i) end
	-- Next UTC day: time and claims start over.
	local tomorrow = now + DAY
	assert(Rules.View(state, tomorrow).Playtime.Seconds == 0, "view shows a fresh day before the first tick")
	Rules.AddPlaytime(state, tomorrow, 300)
	assert(state.Playtime.Seconds == 300 and Rules.ClaimPlaytime(state, tomorrow, 1), "tier 1 pays again the next day")
end)

test("rewards: codes are case-insensitive, one use per profile, and can expire", function()
	local codes = { HELLO = { Reward = { Gems = 5 } }, OLD = { Reward = { Gold = 1 }, Expires = MONDAY } }
	local state = Rules.NewState()
	local reward, _, id = Rules.RedeemCode(state, MONDAY, " hel-lo ", codes)
	assert(reward and reward.Gems == 5 and id == "HELLO", "normalised and redeemed")
	local again, problem = Rules.RedeemCode(state, MONDAY, "HELLO", codes)
	assert(again == nil and problem == "You already redeemed that code.", "one use")
	assert(Rules.RedeemCode(state, MONDAY, "OLD", codes) == nil and not state.Codes.OLD, "expired code is not consumed")
	for _, bad in { "", "NOPE", "a b!", string.rep("A", 200), 12, {}, true } do
		assert(Rules.RedeemCode(state, MONDAY, bad :: any, codes) == nil, "invalid input is refused")
	end
	for code, entry in Codes do
		assert(Rules.NormalizeCode(code) == code, "server code " .. code .. " is uppercase letters and digits")
		assert(Rules.Describe(entry.Reward) ~= "", "server code " .. code .. " pays something")
	end
end)

test("rewards: grants add to balances and describe themselves", function()
	local profile: any = { Currencies = { Gold = 10, Gems = 1 } }
	Rules.Grant(profile, { Gold = 500, Gems = 20, PromotionStones = 2 })
	assert(profile.Currencies.Gold == 510 and profile.Currencies.Gems == 21 and profile.PitMaterials.PromotionStone == 2, "granted")
	assert(Rules.Describe({ Gold = 10000, Gems = 150, PromotionStones = 1 }) == "+150 Gems · +10,000 Gold · +1 Promotion Stone", "describe")
	assert(Rules.FormatDuration(2 * DAY + 4 * 3600) == "2d 4h" and Rules.FormatDuration(249) == "4m 09s", "durations")
end)

test("rewards: the friend boost is +10% Gold per friend, capped", function()
	assert(Rules.FriendBoost(0) == 1 and Rules.FriendBoost(-3) == 1 and Rules.FriendBoost(0 / 0) == 1, "no friends, no boost")
	assert(math.abs(Rules.FriendBoost(1) - 1.1) < 1e-9 and math.abs(Rules.FriendBoost(2) - 1.2) < 1e-9, "per friend")
	local cap = 1 + Config.FriendBoost.PerFriend * Config.FriendBoost.MaxFriends
	assert(math.abs(Rules.FriendBoost(7) - cap) < 1e-9, "a full server of friends is capped")
end)

test("rewards: damaged or missing saved state is rebuilt without granting anything", function()
	local profile: any = { Rewards = { Daily = "x", Weekly = { LastClaimWeek = 0 / 0 }, Playtime = { Seconds = -50, Claimed = { true, "yes" } }, Codes = { A = true, B = 1, [3] = true } } }
	local state = Rules.EnsureState(profile)
	assert(state.Daily.Streak == 0 and state.Weekly.LastClaimWeek == 0 and state.Playtime.Seconds == 0, "numbers repaired")
	assert(state.Playtime.Claimed[1] == true and state.Playtime.Claimed[2] == false and #state.Playtime.Claimed == #Config.Playtime, "claims are booleans")
	assert(state.Codes.A == true and state.Codes.B == nil and state.Codes[3 :: any] == nil, "only redeemed string codes are kept")
	local fresh: any = {}
	assert(Rules.EnsureState(fresh) == fresh.Rewards and fresh.Rewards.Daily.LastClaimDay == 0, "old saves gain the table")
end)

print(string.format("rewards.spec: %d passed", passed))
