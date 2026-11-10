--!strict
-- Pure run-loop rules for one Master's tower run (Phase 6 M5). A run starts on the first tower floor after the hub or plot and
-- ends on a return home, a squad wipe or a disconnect. No Roblox services, so specs can run it directly.
local RS = game:GetService("ReplicatedStorage")
local Hardcore = require(RS.Shared.Config.TowerHardcoreConfig)

export type Run = {
	StartFloor: number,
	HighestFloor: number,
	Streak: number,
	BestStreak: number,
	LastClearedFloor: number?,
	FloorsCleared: number,
	Kills: number,
	GoldEarned: number, -- kill and boss Gold credited straight to the profile this run
	GemsEarned: number,
	UnbankedGold: number, -- part of the above earned since the last bank; a wipe takes a share of it
	UnbankedGems: number,
	RelicGold: number, -- relic payouts banked this run, shown in the summary only
	RelicGems: number,
	StartedAt: number,
}

local TowerRun = {}

export type RelicReceipt = {
	RelicName: string,
	Gold: number,
	Gems: number,
	StreakGold: number,
	StreakGems: number,
	PromotionStones: number,
}

function TowerRun.New(startFloor: number, now: number): Run
	return {
		StartFloor = startFloor, HighestFloor = startFloor, Streak = 0, BestStreak = 0, LastClearedFloor = nil,
		FloorsCleared = 0, Kills = 0, GoldEarned = 0, GemsEarned = 0, UnbankedGold = 0, UnbankedGems = 0,
		RelicGold = 0, RelicGems = 0, StartedAt = now,
	}
end

function TowerRun.Visit(run: Run, floorId: number)
	run.HighestFloor = math.max(run.HighestFloor, floorId)
end

-- Kill and boss rewards go straight to the profile but stay at risk until the next bank.
function TowerRun.AddEarnings(run: Run, gold: number, gems: number, kills: number?)
	run.Kills += kills or 0
	run.GoldEarned += gold
	run.GemsEarned += gems
	run.UnbankedGold += gold
	run.UnbankedGems += gems
end

function TowerRun.AddRelicPayout(run: Run, gold: number, gems: number)
	run.RelicGold += gold
	run.RelicGems += gems
end

-- +1 when the cleared floor follows the previous credited clear (or is the first); a gap restarts the streak at 1;
-- clearing the same floor again changes nothing. Returns the streak after the clear.
function TowerRun.StreakAfterClear(streak: number, lastClearedFloor: number?, floorId: number): number
	if floorId == lastClearedFloor then return streak end
	return if lastClearedFloor == nil or floorId == lastClearedFloor + 1 then streak + 1 else 1
end

function TowerRun.RecordFloorClear(run: Run, floorId: number): number
	local last = run.LastClearedFloor
	if last == floorId then
		return run.Streak
	end
	run.FloorsCleared += 1
	run.Streak = TowerRun.StreakAfterClear(run.Streak, last, floorId)
	run.LastClearedFloor = floorId
	run.BestStreak = math.max(run.BestStreak, run.Streak)
	return run.Streak
end

-- Banked relic value bonus: +10% per floor in the streak, capped at +100%.
function TowerRun.StreakMultiplier(streak: number): number
	return 1 + math.min(Hardcore.StreakBonusCap, Hardcore.StreakBonusPerFloor * math.max(0, streak))
end

function TowerRun.PortalHint(action: string, destinationFloor: number, streak: number, lastClearedFloor: number?): string
	if action == "RETURN" then return "Return to Hub · Ends your run" end
	local preview = TowerRun.StreakAfterClear(streak, lastClearedFloor, destinationFloor)
	local multiplier = TowerRun.StreakMultiplier(preview)
	local bonus = math.round((multiplier - 1) * 100)
	if destinationFloor == lastClearedFloor then
		return string.format("%s Floor %d · Keeps +%d%%", if action == "RERUN" then "Rerun" else "Clear", destinationFloor, bonus)
	elseif lastClearedFloor and destinationFloor ~= lastClearedFloor + 1 then
		return "Clearing this floor starts a new streak"
	elseif multiplier == TowerRun.StreakMultiplier(streak) then
		return string.format("Clear Floor %d · Relic bonus stays at max", destinationFloor)
	end
	return string.format("Clear Floor %d for +%d%% relic rewards", destinationFloor, bonus)
end

-- Round each final credit only once, and compare it with what would have been credited at zero streak.
function TowerRun.RelicCredit(basePayout: number, streakMultiplier: number): (number, number)
	local credited = math.round(basePayout * streakMultiplier)
	return credited, credited - math.round(basePayout)
end

-- Entering a sanctuary or pad makes unbanked earnings safe. Returns what was banked.
function TowerRun.Bank(run: Run): (number, number)
	local gold, gems = run.UnbankedGold, run.UnbankedGems
	run.UnbankedGold, run.UnbankedGems = 0, 0
	return gold, gems
end

-- What a wipe takes: a fraction of the unbanked earnings, never more than the balance and never banked currency beyond it.
function TowerRun.WipeLoss(run: Run, goldBalance: number, gemBalance: number): (number, number)
	local gold = math.min(math.floor(run.UnbankedGold * Hardcore.WipeLossFraction), math.max(0, goldBalance))
	local gems = math.min(math.floor(run.UnbankedGems * Hardcore.WipeLossFraction), math.max(0, gemBalance))
	return gold, gems
end

function TowerRun.Summary(run: Run, reason: string, now: number, lossGold: number?, lossGems: number?): any
	return {
		Reason = reason,
		StartFloor = run.StartFloor,
		HighestFloor = run.HighestFloor,
		FloorsCleared = run.FloorsCleared,
		Kills = run.Kills,
		Streak = run.Streak,
		BestStreak = run.BestStreak,
		GoldEarned = run.GoldEarned,
		GemsEarned = run.GemsEarned,
		RelicGold = run.RelicGold,
		RelicGems = run.RelicGems,
		LossGold = lossGold or 0,
		LossGems = lossGems or 0,
		Seconds = math.max(0, now - run.StartedAt),
	}
end

return table.freeze(TowerRun)
