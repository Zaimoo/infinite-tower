-- Verification gate for the redesigned 3-monument world leaderboard rules.
local Rules = require(nodes["ReplicatedStorage.Shared.Util.LeaderboardRules"])

local passed, failed = 0, 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function sameColor(a, b)
	return math.abs(a.R - b.R) < 1e-4 and math.abs(a.G - b.G) < 1e-4 and math.abs(a.B - b.B) < 1e-4
end

test("Board titles use uniform Top naming for all three monuments", function()
	assert(Rules.TitleFor("Donated") == "Top Robux Donated", "expected Top Robux Donated")
	assert(Rules.TitleFor("Power") == "Top Power", "expected Top Power")
	assert(Rules.TitleFor("Playtime") == "Top Playtime", "expected Top Playtime")
end)

test("RankColor colors only Top 3 (#1 gold, #2 silver, #3 orange) and leaves #4+ white", function()
	assert(sameColor(Rules.RankColor(1), Color3.fromRGB(255, 215, 0)), "#1 must be gold")
	assert(sameColor(Rules.RankColor(2), Color3.fromRGB(216, 228, 250)), "#2 must be silver")
	assert(sameColor(Rules.RankColor(3), Color3.fromRGB(255, 122, 0)), "#3 must be bronze/orange")
	for rank = 4, 100 do
		assert(sameColor(Rules.RankColor(rank), Color3.fromRGB(255, 255, 255)), "#" .. rank .. " must be white")
	end
end)

test("CanvasHeight stops cleanly at the exact row count (e.g. 54) and caps at 100", function()
	assert(Rules.CanvasHeight(0) == 0, "empty board has 0 canvas height")
	local h1 = Rules.CanvasHeight(1)
	local h54 = Rules.CanvasHeight(54)
	local h100 = Rules.CanvasHeight(100)
	local h150 = Rules.CanvasHeight(150)
	assert(h1 == 56 + 12, "1 row height mismatch: " .. tostring(h1))
	assert(h54 == 54 * 56 + 53 * 6 + 12, "54-row canvas height must match 54 cards exactly: " .. tostring(h54))
	assert(h100 == 100 * 56 + 99 * 6 + 12, "100-row canvas height mismatch: " .. tostring(h100))
	assert(h150 == h100, "canvas height must cap at MAX_ROWS (100)")
end)

test("ClampSorted preserves smaller lists (54) and truncates lists over 100 to 100", function()
	local list54 = {}
	for i = 1, 54 do table.insert(list54, { UserId = i }) end
	local kept54 = Rules.ClampSorted(list54, 100)
	assert(#kept54 == 54, "expected 54 entries preserved, got " .. tostring(#kept54))

	local list140 = {}
	for i = 1, 140 do table.insert(list140, { UserId = i }) end
	local clamped = Rules.ClampSorted(list140, 100)
	assert(#clamped == 100, "expected 100 entries clamped, got " .. tostring(#clamped))
	assert(clamped[1].UserId == 1 and clamped[100].UserId == 100, "clamp must keep the top 100 in order")
end)

test("FormatRobux formats integer Robux amounts with thousands commas", function()
	assert(Rules.FormatRobux(0) == "0 R$", "got " .. Rules.FormatRobux(0))
	assert(Rules.FormatRobux(49) == "49 R$", "got " .. Rules.FormatRobux(49))
	assert(Rules.FormatRobux(1250) == "1,250 R$", "got " .. Rules.FormatRobux(1250))
	assert(Rules.FormatRobux(250000) == "250,000 R$", "got " .. Rules.FormatRobux(250000))
end)

print(string.format("LeaderboardRedesign: %d passed, %d failed", passed, failed))
if failed > 0 then error("leaderboard redesign tests failed") end
