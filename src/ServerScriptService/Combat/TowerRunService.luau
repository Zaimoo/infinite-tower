--!strict
-- Server-side holder for each Master's tower run (Phase 6 M5). Pure rules live in Shared.Util.TowerRun; this module owns the
-- per-player state and the RunState / RunSummary remotes the HUD reads. The client only displays what is sent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerRun = require(ReplicatedStorage.Shared.Util.TowerRun)
local Telemetry = require(script.Parent.TowerTelemetry)

local Service = {}
local runs: { [Player]: TowerRun.Run } = {}

local function remote(name: string): RemoteEvent?
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local towerRemotes = folder and folder:FindFirstChild("TowerRemotes")
	local r = towerRemotes and towerRemotes:FindFirstChild(name)
	return if r and r:IsA("RemoteEvent") then r else nil
end

local function publish(player: Player, run: TowerRun.Run?)
	local r = remote("RunState")
	if not r or player.Parent ~= Players then return end
	r:FireClient(player, if run then {
		Streak = run.Streak, BestStreak = run.BestStreak, UnbankedGold = run.UnbankedGold, UnbankedGems = run.UnbankedGems,
		StreakMultiplier = TowerRun.StreakMultiplier(run.Streak),
	} else { Streak = 0, BestStreak = 0, UnbankedGold = 0, UnbankedGems = 0, StreakMultiplier = 1 })
end

function Service.Get(player: Player): TowerRun.Run?
	return runs[player]
end

-- Called while the Master stands on a tower floor; starts the run on the first call after the hub or plot.
function Service.Ensure(player: Player, floorId: number): TowerRun.Run
	local run = runs[player]
	if not run then
		run = TowerRun.New(floorId, os.clock())
		runs[player] = run
		publish(player, run)
	end
	TowerRun.Visit(run, floorId)
	return run
end

function Service.AddEarnings(player: Player, gold: number, gems: number, kills: number?)
	local run = runs[player]
	if not run then return end -- an assigned squad farming while its Master is home has no run to put at risk
	TowerRun.AddEarnings(run, gold, gems, kills)
	publish(player, run)
end

function Service.AddRelicPayout(player: Player, gold: number, gems: number)
	local run = runs[player]
	if run then TowerRun.AddRelicPayout(run, gold, gems) end
end

function Service.RecordFloorClear(player: Player, floorId: number, firstClear: boolean?): number
	local run = runs[player]
	if not run then return 0 end
	local streak = TowerRun.RecordFloorClear(run, floorId)
	Telemetry.FloorClear(player, floorId, firstClear == true, streak)
	publish(player, run)
	return streak
end

-- Multiplier for a relic banked right now.
function Service.RelicMultiplier(player: Player): number
	local run = runs[player]
	return if run then TowerRun.StreakMultiplier(run.Streak) else 1
end

function Service.Bank(player: Player)
	local run = runs[player]
	if not run or (run.UnbankedGold == 0 and run.UnbankedGems == 0) then return end
	TowerRun.Bank(run)
	publish(player, run)
end

-- Ends the run and tells the client. `loss` is applied by the caller (it owns the profile); pass what it took.
function Service.End(player: Player, reason: string, lossGold: number?, lossGems: number?): any?
	local run = runs[player]
	if not run then return nil end
	runs[player] = nil
	local summary = TowerRun.Summary(run, reason, os.clock(), lossGold, lossGems)
	Telemetry.RunEnd(player, summary)
	local r = remote("RunSummary")
	if r and player.Parent == Players then r:FireClient(player, summary) end
	publish(player, nil)
	return summary
end

function Service.Discard(player: Player)
	runs[player] = nil
end

Players.PlayerRemoving:Connect(Service.Discard)

return Service
