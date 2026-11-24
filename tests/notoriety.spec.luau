--!strict
-- tests/notoriety.spec.luau
-- Reputation (B6): what counts, the daily per-victim cap, titles and ISO week keys (NotorietyRules),
-- and the v10 save migration that adds profile.Notoriety.

local Rules = require(nodes["ReplicatedStorage.Shared.Util.NotorietyRules"])
local Migrations = require(nodes["ServerScriptService.Core.ProfileMigrations"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local MONDAY = 1767571200 -- Monday 5 January 2026, 00:00 UTC (ISO 2026W02)
local DAY = 86400

test("notoriety: ISO week keys roll over on Monday, and early January can belong to last year", function()
	assert(Rules.WeekKey(MONDAY) == "2026W02", Rules.WeekKey(MONDAY))
	assert(Rules.WeekKey(MONDAY - 1) == "2026W01", "Sunday night is the week before")
	assert(Rules.WeekKey(MONDAY + 6 * DAY + DAY - 1) == "2026W02", "through Sunday")
	assert(Rules.WeekKey(1735689600) == "2025W01", "Wed 1 Jan 2025 is in 2025W01")
	assert(Rules.WeekKey(1609459200) == "2020W53", "Fri 1 Jan 2021 belongs to 2020W53")
	assert(Rules.WeekKey(1795392000) == "2026W48", "Mon 23 Nov 2026")
end)

test("notoriety: training thefts, friends and robbing rivals never count", function()
	local state = Rules.NewState()
	assert(not Rules.Record(state, "THEFT", 42, MONDAY, false, true), "a Rival lesson's theft")
	assert(not Rules.Record(state, "THEFT", 42, MONDAY, true, false), "between friends")
	assert(not Rules.Record(state, "THEFT", -1000, MONDAY, false, false), "a server-run rival")
	assert(state.Thefts == 0 and state.WeekThefts == 0)
	assert(Rules.Record(state, "THEFT", 42, MONDAY, false, false))
	assert(state.Thefts == 1 and state.WeekThefts == 1 and state.Week == "2026W02")
end)

test("notoriety: at most three counted acts against the same Master per UTC day", function()
	local state = Rules.NewState()
	for _ = 1, Rules.DAILY_CAP do assert(Rules.Record(state, "CLAIM", 7, MONDAY + 10, false, false)) end
	assert(not Rules.Record(state, "ESCAPE", 7, MONDAY + 20, false, false), "the cap covers every kind")
	assert(Rules.Record(state, "CLAIM", 8, MONDAY + 30, false, false), "another victim still counts")
	assert(Rules.Record(state, "CLAIM", 7, MONDAY + DAY, false, false), "a new UTC day resets the cap")
	assert(state.BountiesClaimed == 5 and state.WeekHunts == 5)
	assert(Rules.Record(state, "ESCAPE", 9, MONDAY + 7 * DAY, false, false))
	assert(state.Week == "2026W03" and state.WeekHunts == 0 and state.WeekThefts == 1, "weekly totals restart each week")
	assert(state.BountiesClaimed == 5 and state.Escapes == 1, "lifetime totals keep going")
end)

test("notoriety: acts ten or more floors below your best clear are farming", function()
	assert(not Rules.Overlevel(11, 2), "nine floors below still counts")
	assert(Rules.Overlevel(12, 2), "a veteran on Floor 2")
	assert(Rules.Overlevel(50, 40))
	assert(not Rules.Overlevel(40, 0), "outside the tower is never overlevel")
end)

test("notoriety: titles follow the further track", function()
	local state = Rules.NewState()
	assert(Rules.Title(state) == nil)
	state.Thefts = 4
	assert(Rules.Title(state) == nil, "below the first rung")
	state.Escapes = 1
	assert(Rules.Title(state) == "Pickpocket", "escapes count toward the thief track")
	state.BountiesClaimed = 25
	assert(Rules.Title(state) == "Warden", "the hunter track is further")
	state.Thefts = 30
	assert(Rules.Title(state) == "Notorious Thief", "equal rungs: the larger count")
end)

test("notoriety: a broken save is repaired, and v10 adds zeros to old profiles", function()
	local repaired = Rules.Ensure({ Thefts = -3, BountiesClaimed = 0 / 0, Escapes = "x", ByVictim = { ["7"] = 2, [5] = 1 }, Week = 4 })
	assert(repaired.Thefts == 0 and repaired.BountiesClaimed == 0 and repaired.Escapes == 0)
	assert(repaired.ByVictim["7"] == 2 and repaired.Week == "")
	assert(Migrations.CurrentSchema >= 11)
	local old: any = { SchemaVersion = 9, Heroes = {}, Settings = {} }
	Migrations.ToV10(old)
	assert(old.SchemaVersion == 10 and old.Notoriety.Thefts == 0 and old.Notoriety.WeekHunts == 0)
	old.Notoriety.Thefts = 6
	Migrations.ToV10(old)
	assert(old.Notoriety.Thefts == 6, "running it again changes nothing")
end)

print(string.format("notoriety.spec: %d passed", passed))
