--!strict
-- Phase 6 M7: tower run-loop analytics. Server-only, low-cardinality custom events (names and field values are categories,
-- never free text or ids), and always pcalled so a telemetry failure can never touch gameplay.
local AnalyticsService = game:GetService("AnalyticsService")

local Telemetry = {}

local FIELDS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function log(player: Player, event: string, value: number, ...: string)
	local fields: { [string]: string } = {}
	for i, text in { ... } do
		if FIELDS[i] then fields[FIELDS[i]] = text end
	end
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogCustomEvent(player, event, value, fields)
		end)
	end)
end

-- value = floor id; fields = "first" or "repeat", the floor-in-biome slot ("boss" on every 5th floor).
function Telemetry.FloorClear(player: Player, floorId: number, firstClear: boolean, streak: number)
	log(player, "tower_floor_clear", floorId, if firstClear then "first" else "repeat", if floorId % 5 == 0 then "boss" else "alpha", tostring(math.min(streak, 10)))
end

-- value = floors cleared in the run; fields = why it ended, and (for wipes) whether unbanked earnings were lost.
function Telemetry.RunEnd(player: Player, summary: any)
	log(player, "tower_run_end", summary.FloorsCleared, summary.Reason, tostring(math.min(summary.BestStreak, 10)))
	if summary.Reason == "WIPE" then
		log(player, "tower_wipe", summary.HighestFloor, if (summary.LossGold or 0) > 0 or (summary.LossGems or 0) > 0 then "lost_earnings" else "banked")
	end
end

return Telemetry
