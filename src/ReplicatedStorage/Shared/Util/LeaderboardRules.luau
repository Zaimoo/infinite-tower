--!strict
-- ReplicatedStorage/Shared/Util/LeaderboardRules.luau
-- Pure shared constants and layout rules for the 3-monument world leaderboard ensemble
-- (Top Robux Donated, Top Power, Top Playtime). Contains no Roblox service dependencies
-- so both Studio runtime and offline CLI Luau specs execute the exact same logic.

local LeaderboardRules = {}

export type LeaderboardKind = "Donated" | "Power" | "Playtime"

LeaderboardRules.MAX_ROWS = 100
LeaderboardRules.ROW_HEIGHT = 56
LeaderboardRules.ROW_PADDING = 6
LeaderboardRules.LIST_TOP_BOTTOM_PAD = 12
LeaderboardRules.PIXELS_PER_STUD = 50
LeaderboardRules.SCREEN_SIZE = Vector3.new(9.4, 12.4, 0.5)
LeaderboardRules.SCREEN_Y = 8.2

LeaderboardRules.TITLES = table.freeze({
	Donated = "Top Robux Donated",
	Power = "Top Power",
	Playtime = "Top Playtime",
} :: { [LeaderboardKind]: string })

-- Han Islate (`hero_han`) palette from SkillVfxCatalog for the Top Power centerpiece.
LeaderboardRules.HAN_PALETTE = table.freeze({
	Primary = Color3.fromRGB(70, 140, 255),
	Secondary = Color3.fromRGB(22, 24, 34),
	Core = Color3.fromRGB(170, 215, 255),
})

LeaderboardRules.RANK_COLORS = table.freeze({
	First = Color3.fromRGB(255, 215, 0),
	Second = Color3.fromRGB(216, 228, 250),
	Third = Color3.fromRGB(255, 122, 0),
	Default = Color3.fromRGB(255, 255, 255),
})

function LeaderboardRules.TitleFor(kind: LeaderboardKind): string
	return LeaderboardRules.TITLES[kind] or "Leaderboard"
end

-- Colors only the top 3 ranks (#1 gold, #2 silver, #3 orange/bronze); #4+ stay crisp white.
function LeaderboardRules.RankColor(rank: number): Color3
	if rank == 1 then
		return LeaderboardRules.RANK_COLORS.First
	elseif rank == 2 then
		return LeaderboardRules.RANK_COLORS.Second
	elseif rank == 3 then
		return LeaderboardRules.RANK_COLORS.Third
	end
	return LeaderboardRules.RANK_COLORS.Default
end

-- Computes exact ScrollingFrame canvas pixel height for `rowCount` rows so scrolling stops
-- at the actual last player (e.g. 54th when 54 exist) up to MAX_ROWS (100).
function LeaderboardRules.CanvasHeight(rowCount: number): number
	local count = math.clamp(math.floor(rowCount or 0), 0, LeaderboardRules.MAX_ROWS)
	if count <= 0 then
		return 0
	end
	return count * LeaderboardRules.ROW_HEIGHT + (count - 1) * LeaderboardRules.ROW_PADDING + LeaderboardRules.LIST_TOP_BOTTOM_PAD
end

-- Clamps a sorted leaderboard list to at most `maxRows` (defaults to 100).
function LeaderboardRules.ClampSorted<T>(entries: { T }, maxRows: number?): { T }
	local limit = math.max(0, math.floor(maxRows or LeaderboardRules.MAX_ROWS))
	if #entries <= limit then
		return entries
	end
	local out = table.create(limit)
	table.move(entries, 1, limit, 1, out)
	return out
end

-- Formats integer Robux values with thousands commas (e.g. 250000 -> "250,000 R$").
function LeaderboardRules.FormatRobux(amount: number): string
	local whole = math.max(0, math.floor(amount or 0))
	local str = tostring(whole)
	local count: number
	while true do
		str, count = string.gsub(str, "^(-?%d+)(%d%d%d)", "%1,%2")
		if count == 0 then
			break
		end
	end
	return str .. " R$"
end

return LeaderboardRules
