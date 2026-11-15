--!strict
-- ReplicatedStorage/Shared/Util/NotorietyRules.luau
-- Reputation for the contested-loot game (docs/first-session-and-social-plan.md B6, GDD §6.1): what
-- counts as a theft, a bounty claimed or an escape, the nameplate titles, and the weekly board keys.
-- Pure: NotorietyService applies it to profile.Notoriety and the weekly OrderedDataStores.
--
-- Only fair fights count, or the boards would reward griefing: never a Rival lesson's training theft,
-- never between Roblox friends (two friends could farm each other), never OVERLEVEL_FLOORS or more
-- below your best clear, and at most DAILY_CAP per victim per UTC day. Protected first relics can't
-- be stolen at all.

local NotorietyRules = {}

NotorietyRules.DAILY_CAP = 3 -- counted acts against the same Master per UTC day
NotorietyRules.OVERLEVEL_FLOORS = 10 -- acts this far below your best clear don't count (as LootDuel's carry rule)

-- Whether an act on `floorId` by a Master whose best clear is `bestFloor` is low-floor farming
-- (a veteran robbing newcomers, or a main farming alt accounts on Floor 2). Those never count.
function NotorietyRules.Overlevel(bestFloor: number, floorId: number): boolean
	return floorId > 0 and bestFloor >= floorId + NotorietyRules.OVERLEVEL_FLOORS
end

export type State = {
	Thefts: number,
	BountiesClaimed: number,
	Escapes: number,
	Day: number, -- UTC day the per-victim counts belong to
	ByVictim: { [string]: number }, -- tostring(userId) -> counted acts against them today
	Week: string, -- ISO week the weekly totals belong to ("2026W47")
	WeekThefts: number, -- thefts and escapes this week (Top Thieves)
	WeekHunts: number, -- bounties claimed this week (Top Hunters)
}

export type Kind = "THEFT" | "CLAIM" | "ESCAPE"

function NotorietyRules.NewState(): State
	return { Thefts = 0, BountiesClaimed = 0, Escapes = 0, Day = 0, ByVictim = {}, Week = "", WeekThefts = 0, WeekHunts = 0 }
end

local function count(value: any): number
	return if type(value) == "number" and value == value and value >= 0 then math.floor(value) else 0
end

-- A saved state of any age in the current shape (missing or broken fields become their defaults).
function NotorietyRules.Ensure(state: any): State
	local out = NotorietyRules.NewState()
	if type(state) ~= "table" then return out end
	out.Thefts, out.BountiesClaimed, out.Escapes = count(state.Thefts), count(state.BountiesClaimed), count(state.Escapes)
	out.Day = count(state.Day)
	if type(state.ByVictim) == "table" then
		for key, value in state.ByVictim do
			if type(key) == "string" then out.ByVictim[key] = count(value) end
		end
	end
	out.Week = if type(state.Week) == "string" then state.Week else ""
	out.WeekThefts, out.WeekHunts = count(state.WeekThefts), count(state.WeekHunts)
	return out
end

-- Days since 1970-01-01 for a civil date (proleptic Gregorian; Howard Hinnant's algorithm).
local function daysFromCivil(y: number, m: number, d: number): number
	y -= if m <= 2 then 1 else 0
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local doy = (153 * (m + (if m > 2 then -3 else 9)) + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- The year of a day number (days since 1970-01-01).
local function yearOfDay(z: number): number
	z += 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local m = mp + (if mp < 10 then 3 else -9)
	return yoe + era * 400 + (if m <= 2 then 1 else 0)
end

-- The ISO 8601 week of a UTC time, as "2026W47": weeks start on Monday and belong to the year of
-- their Thursday.
function NotorietyRules.WeekKey(unix: number): string
	local day = unix // 86400
	local weekday = (day + 3) % 7 + 1 -- 1 = Monday ... 7 = Sunday; 1970-01-01 was a Thursday
	local thursday = day - weekday + 4
	local year = yearOfDay(thursday)
	local week = (thursday - daysFromCivil(year, 1, 1)) // 7 + 1
	return string.format("%dW%02d", year, week)
end

-- Records one act if it counts. `victimUserId`: the robbed owner (THEFT), the thief (CLAIM) or the
-- hunter (ESCAPE). Returns whether it counted. Rolls the per-victim counts over each UTC day and the
-- weekly totals over each ISO week.
function NotorietyRules.Record(state: State, kind: Kind, victimUserId: number, unix: number, isFriend: boolean, training: boolean): boolean
	if training or isFriend or victimUserId <= 0 then return false end
	local day = unix // 86400
	if state.Day ~= day then
		state.Day = day
		table.clear(state.ByVictim)
	end
	local week = NotorietyRules.WeekKey(unix)
	if state.Week ~= week then
		state.Week, state.WeekThefts, state.WeekHunts = week, 0, 0
	end
	local key = tostring(victimUserId)
	if (state.ByVictim[key] or 0) >= NotorietyRules.DAILY_CAP then return false end
	state.ByVictim[key] = (state.ByVictim[key] or 0) + 1
	if kind == "THEFT" then
		state.Thefts += 1
		state.WeekThefts += 1
	elseif kind == "ESCAPE" then
		state.Escapes += 1
		state.WeekThefts += 1
	else
		state.BountiesClaimed += 1
		state.WeekHunts += 1
	end
	return true
end

-- Nameplate titles: the thief track counts thefts and escapes, the hunter track bounties claimed.
-- The further track gives the title; nil below the first rung.
NotorietyRules.TITLES = table.freeze({
	Thief = table.freeze({ { At = 5, Title = "Pickpocket" }, { At = 25, Title = "Notorious Thief" } }),
	Hunter = table.freeze({ { At = 5, Title = "Bounty Hunter" }, { At = 25, Title = "Warden" } }),
})

local function rung(track: { { At: number, Title: string } }, n: number): (number, string?)
	local level, title = 0, nil
	for i, step in track do
		if n >= step.At then level, title = i, step.Title end
	end
	return level, title
end

function NotorietyRules.Title(state: State): string?
	local thiefCount = state.Thefts + state.Escapes
	local thiefLevel, thiefTitle = rung(NotorietyRules.TITLES.Thief, thiefCount)
	local hunterLevel, hunterTitle = rung(NotorietyRules.TITLES.Hunter, state.BountiesClaimed)
	if thiefLevel == 0 and hunterLevel == 0 then return nil end
	if hunterLevel > thiefLevel then return hunterTitle end
	if thiefLevel > hunterLevel then return thiefTitle end
	return if state.BountiesClaimed >= thiefCount then hunterTitle else thiefTitle
end

return table.freeze(NotorietyRules)
