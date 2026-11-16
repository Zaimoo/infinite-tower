--!strict
-- ReplicatedStorage/Shared/Util/BattlePassRules.luau
-- Pure rules for the Battle Pass (GDD §4.9): seasons, XP and levels, the free and premium reward
-- rows and the season rollover. No Roblox services, so tests/battlepass.spec.luau runs them in the
-- CLI. The server (Core/BattlePassService) is the only caller that mutates a profile; the client
-- uses the read-only helpers to draw the window from the synced profile.
--
-- State lives at profile.BattlePass:
--   Season  = season number the rest of the state belongs to
--   Xp      = XP earned this season (capped at MaxLevel * XpPerLevel)
--   Premium = the premium row is unlocked this season
--   Free    = bitmask of claimed free rewards (bit level - 1)
--   Paid    = bitmask of claimed premium rewards
--   Quests  = { Day, Week, Progress = { [questId] = count }, Claimed = { [questId] = true } }:
--             the UTC day and week the quest progress belongs to (a new day or week clears it)
-- The claims are bitmasks, not arrays, because XP changes on every kill and profile sync resends a
-- changed top-level key whole: the state stays five small values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.BattlePassConfig)

export type Reward = Config.Reward
export type Track = "Free" | "Premium"
export type Quest = Config.Quest
export type QuestState = {
	Day: number,
	Week: number,
	Progress: { [string]: number },
	Claimed: { [string]: boolean },
}
export type State = {
	Season: number,
	Xp: number,
	Premium: boolean,
	Free: number,
	Paid: number,
	Quests: QuestState,
}

local DAY = 86400
local WEEK = 7 * DAY
local SEASON = Config.SeasonDays * DAY
local MAX_XP = Config.MaxLevel * Config.XpPerLevel
assert(Config.MaxLevel <= 32, "BattlePassRules: claims are 32-bit masks")
-- Every level's bit set.
local ALL_LEVELS = if Config.MaxLevel == 32 then 0xFFFFFFFF else bit32.lshift(1, Config.MaxLevel) - 1

local BattlePassRules = {}

local function int(value: any, min: number, max: number): number
	if type(value) ~= "number" or value ~= value then return min end
	return math.clamp(math.floor(value), min, max)
end

-- Season number at `now` (1 before the epoch, so an early clock still has a season).
function BattlePassRules.SeasonOf(now: number): number
	return math.max(1, math.floor((now - Config.Epoch) / SEASON) + 1)
end

function BattlePassRules.SeasonEndsAt(season: number): number
	return Config.Epoch + season * SEASON
end

function BattlePassRules.SeasonName(season: number): string
	local names = Config.SeasonNames
	return string.format("Season %d: %s", season, names[(season - 1) % #names + 1])
end

-- Quest clocks: days are UTC days, weeks start on Monday 00:00 UTC (the epoch is a Monday).
function BattlePassRules.DayOf(now: number): number
	return math.floor(now / DAY)
end

function BattlePassRules.WeekOf(now: number): number
	return math.floor((now - Config.Epoch) / WEEK)
end

function BattlePassRules.DayEndsAt(day: number): number
	return (day + 1) * DAY
end

function BattlePassRules.WeekEndsAt(week: number): number
	return Config.Epoch + (week + 1) * WEEK
end

local QUEST_LISTS = { Config.DailyQuests, Config.WeeklyQuests }
local QUEST_BY_ID: { [string]: Quest } = {}
for _, list in QUEST_LISTS do
	for _, quest in list do QUEST_BY_ID[quest.Id] = quest end
end

local function newQuests(now: number): QuestState
	return { Day = BattlePassRules.DayOf(now), Week = BattlePassRules.WeekOf(now), Progress = {}, Claimed = {} }
end

function BattlePassRules.NewState(now: number): State
	return { Season = BattlePassRules.SeasonOf(now), Xp = 0, Premium = false, Free = 0, Paid = 0, Quests = newQuests(now) }
end

-- Creates or repairs state.Quests. Progress is kept only for known quests and never above the
-- goal; a claim is kept only for a finished quest, so a bad value can never pay XP twice.
local function ensureQuests(raw: any, now: number)
	local quests = raw.Quests
	if type(quests) ~= "table" then
		raw.Quests = newQuests(now)
		return
	end
	local function clock(value: any, fallback: number): number
		if type(value) ~= "number" or value ~= value or math.abs(value) > 1e9 then return fallback end
		return math.floor(value)
	end
	quests.Day = clock(quests.Day, BattlePassRules.DayOf(now))
	quests.Week = clock(quests.Week, BattlePassRules.WeekOf(now))
	local savedProgress = if type(quests.Progress) == "table" then quests.Progress else {}
	local savedClaimed = if type(quests.Claimed) == "table" then quests.Claimed else {}
	local progress: { [string]: number } = {}
	local claimed: { [string]: boolean } = {}
	for id, quest in QUEST_BY_ID do
		local count = int(savedProgress[id], 0, quest.Goal)
		if count > 0 then progress[id] = count end
		if count >= quest.Goal and savedClaimed[id] == true then claimed[id] = true end
	end
	quests.Progress = progress
	quests.Claimed = claimed
end

local function mask(saved: any): number
	if type(saved) ~= "number" or saved ~= saved or saved < 0 or saved > 0xFFFFFFFF then return 0 end
	return bit32.band(math.floor(saved), ALL_LEVELS)
end

local function bitOf(level: number): number
	return bit32.lshift(1, level - 1)
end

-- Creates or repairs profile.BattlePass. Old saves have no table; a damaged one is rebuilt field
-- by field so a bad value can never pay a reward twice or unlock Premium.
function BattlePassRules.EnsureState(profile: any, now: number): State
	local raw = profile.BattlePass
	if type(raw) ~= "table" then
		raw = BattlePassRules.NewState(now)
		profile.BattlePass = raw
	end
	raw.Season = int(raw.Season, 1, 1e6)
	raw.Xp = int(raw.Xp, 0, MAX_XP)
	raw.Premium = raw.Premium == true
	raw.Free = mask(raw.Free)
	raw.Paid = mask(raw.Paid)
	ensureQuests(raw, now)
	return raw
end

-- Level reached with `xp` (0 to MaxLevel). Level N needs N * XpPerLevel.
function BattlePassRules.LevelOf(xp: number): number
	return math.clamp(math.floor(xp / Config.XpPerLevel), 0, Config.MaxLevel)
end

-- XP inside the current level and the XP that level needs (both equal XpPerLevel at the max level).
function BattlePassRules.Progress(xp: number): (number, number)
	if BattlePassRules.LevelOf(xp) >= Config.MaxLevel then return Config.XpPerLevel, Config.XpPerLevel end
	return xp % Config.XpPerLevel, Config.XpPerLevel
end

-- Adds XP. Returns the levels gained (0 at the cap or for a bad amount).
function BattlePassRules.AddXp(state: State, amount: number): number
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then return 0 end
	local before = BattlePassRules.LevelOf(state.Xp)
	state.Xp = math.min(MAX_XP, state.Xp + math.floor(amount))
	return BattlePassRules.LevelOf(state.Xp) - before
end

local function isClaimed(state: State, track: Track, level: number): boolean
	return bit32.btest(if track == "Premium" then state.Paid else state.Free, bitOf(level))
end

local function markClaimed(state: State, track: Track, level: number)
	if track == "Premium" then
		state.Paid = bit32.bor(state.Paid, bitOf(level))
	else
		state.Free = bit32.bor(state.Free, bitOf(level))
	end
end

local function rewardsOf(track: Track): { Reward }
	return if track == "Premium" then Config.Premium else Config.Free
end

-- "Claimed", "Claim" (ready), "Locked" (level not reached) or "Premium" (reached, but the premium
-- row is not unlocked).
function BattlePassRules.Status(state: State, track: Track, level: number): string
	if level < 1 or level > Config.MaxLevel or isClaimed(state, track, level) then return "Claimed" end
	if level > BattlePassRules.LevelOf(state.Xp) then return "Locked" end
	if track == "Premium" and not state.Premium then return "Premium" end
	return "Claim"
end

function BattlePassRules.Claim(state: State, track: any, level: any): (Reward?, string?)
	if track ~= "Free" and track ~= "Premium" then return nil, "Unknown reward." end
	if type(level) ~= "number" or level ~= level or level % 1 ~= 0 or level < 1 or level > Config.MaxLevel then
		return nil, "Unknown reward."
	end
	local status = BattlePassRules.Status(state, track, level)
	if status == "Claimed" then return nil, "Already claimed." end
	if status == "Locked" then return nil, string.format("Reach level %d to claim this.", level) end
	if status == "Premium" then return nil, "Unlock the Premium Pass to claim this." end
	markClaimed(state, track, level)
	return rewardsOf(track)[level], nil
end

-- Claims everything that is ready. Returns the rewards (empty when there is nothing to claim).
function BattlePassRules.ClaimAll(state: State): { Reward }
	local rewards = {}
	for _, track: Track in { "Free", "Premium" } :: { Track } do
		for level = 1, Config.MaxLevel do
			if BattlePassRules.Status(state, track, level) == "Claim" then
				markClaimed(state, track, level)
				table.insert(rewards, rewardsOf(track)[level])
			end
		end
	end
	return rewards
end

-- Rewards ready to claim (the rail badge).
function BattlePassRules.ClaimableCount(state: State): number
	local count = 0
	for _, track: Track in { "Free", "Premium" } :: { Track } do
		for level = 1, Config.MaxLevel do
			if BattlePassRules.Status(state, track, level) == "Claim" then count += 1 end
		end
	end
	return count
end

-- Unlocks the premium row for the state's season. False when it was already unlocked.
function BattlePassRules.UnlockPremium(state: State): boolean
	if state.Premium then return false end
	state.Premium = true
	return true
end

-- Moves the state to the season at `now`. When the season changed, the old season's unlocked but
-- unclaimed rewards are returned (to be granted) and XP, claims and Premium start over. Returns
-- nil when the season is unchanged. A clock that moved backwards never rolls a season back.
function BattlePassRules.Rollover(state: State, now: number): { Reward }?
	local season = BattlePassRules.SeasonOf(now)
	if season <= state.Season then return nil end
	local owed = BattlePassRules.ClaimAll(state)
	state.Season = season
	state.Xp = 0
	state.Premium = false
	state.Free = 0
	state.Paid = 0
	return owed
end

-- Quests ---------------------------------------------------------------------------------------

-- The quest state, or nil when it is missing or damaged (the client reads a synced copy).
local function questsOf(state: State): QuestState?
	local quests = (state :: any).Quests
	if type(quests) ~= "table" or type(quests.Progress) ~= "table" or type(quests.Claimed) ~= "table" then return nil end
	return quests
end

-- A quest's count and its status: "Claimed", "Claim" (finished, XP ready) or "Progress".
function BattlePassRules.QuestStatus(state: State, quest: Quest): (number, string)
	local quests = questsOf(state)
	if not quests then return 0, "Progress" end
	local saved = quests.Progress[quest.Id]
	local count = if type(saved) == "number" then math.clamp(saved, 0, quest.Goal) else 0
	if quests.Claimed[quest.Id] == true then return quest.Goal, "Claimed" end
	return count, if count >= quest.Goal then "Claim" else "Progress"
end

-- Counts `amount` of `metric` towards every unfinished quest that tracks it. Returns the quests
-- this finished.
function BattlePassRules.QuestRecord(state: State, metric: string, amount: number?): { Quest }
	local finished: { Quest } = {}
	local quests = questsOf(state)
	local n = if type(amount) == "number" and amount == amount then math.floor(amount) else 1
	if not quests or n < 1 then return finished end
	for _, list in QUEST_LISTS do
		for _, quest in list do
			if quest.Metric ~= metric then continue end
			local before = quests.Progress[quest.Id] or 0
			if before >= quest.Goal then continue end
			local after = math.min(quest.Goal, before + n)
			quests.Progress[quest.Id] = after
			if after >= quest.Goal then table.insert(finished, quest) end
		end
	end
	return finished
end

-- Claims a finished quest. Returns its XP (before the Pass XP Potion), or nil and the reason.
function BattlePassRules.QuestClaim(state: State, id: any): (number?, string?)
	local quest = if type(id) == "string" then QUEST_BY_ID[id] else nil
	local quests = questsOf(state)
	if not quest or not quests then return nil, "Unknown quest." end
	local _, status = BattlePassRules.QuestStatus(state, quest)
	if status == "Claimed" then return nil, "Already claimed." end
	if status ~= "Claim" then return nil, "Finish the quest first." end
	quests.Claimed[quest.Id] = true
	return quest.Xp, nil
end

-- Claims every finished quest. Returns the XP (0 when nothing was ready).
function BattlePassRules.QuestClaimAll(state: State): number
	local xp = 0
	for id in QUEST_BY_ID do
		xp += BattlePassRules.QuestClaim(state, id) or 0
	end
	return xp
end

-- Finished quests with XP waiting (the rail badge and the Quests tab).
function BattlePassRules.QuestClaimableCount(state: State): number
	local count = 0
	for _, quest in QUEST_BY_ID do
		local _, status = BattlePassRules.QuestStatus(state, quest)
		if status == "Claim" then count += 1 end
	end
	return count
end

-- Moves the quests to the day and week at `now`. A period that ended has its progress cleared;
-- finished quests nobody claimed are returned as XP owed, so nothing earned is lost. Returns
-- (anything reset, XP owed). A clock that moved backwards resets nothing.
function BattlePassRules.QuestReset(state: State, now: number): (boolean, number)
	local quests = questsOf(state)
	if not quests then return false, 0 end
	local owed = 0
	local function expire(list: { Quest })
		for _, quest in list do
			local _, status = BattlePassRules.QuestStatus(state, quest)
			if status == "Claim" then owed += quest.Xp end
			quests.Progress[quest.Id] = nil
			quests.Claimed[quest.Id] = nil
		end
	end
	local changed = false
	local day, week = BattlePassRules.DayOf(now), BattlePassRules.WeekOf(now)
	if day > quests.Day then
		expire(Config.DailyQuests)
		quests.Day = day
		changed = true
	end
	if week > quests.Week then
		expire(Config.WeeklyQuests)
		quests.Week = week
		changed = true
	end
	return changed, owed
end

-- Read-only version of EnsureState for the client: nil until the profile carries a state.
function BattlePassRules.Read(profile: any): State?
	local raw = profile and profile.BattlePass
	if type(raw) ~= "table" or type(raw.Xp) ~= "number" or type(raw.Free) ~= "number" or type(raw.Paid) ~= "number" then return nil end
	return raw
end

return table.freeze(BattlePassRules)
