--!strict
-- ServerScriptService/Core/BattlePassService.luau
-- Server owner of profile.BattlePass (GDD §4.9). The rules are pure (Shared/Util/BattlePassRules);
-- this module adds the clock, the remote, the rate limit, XP grants from gameplay and the season
-- rollover.
--
-- Remote (ReplicatedStorage.Remotes.BattlePassRemotes):
--   BattlePassRequest (RemoteFunction): action "CLAIM" (track "Free" | "Premium", level) or
--       "CLAIM_ALL". Returns { Ok, Message }. The state itself reaches the client in the profile
--       sync (profile.BattlePass).
-- Premium is unlocked only by ShopService, from a granted Robux receipt (UnlockPremium). In Studio
-- the action "DEV_UNLOCK" does the same so the premium row can be play-tested without a product.
--
-- The client only sends requests; seasons use the server clock (os.time, UTC).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.BattlePassConfig)
local BattlePassRules = require(ReplicatedStorage.Shared.Util.BattlePassRules)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)

export type Dependencies = {
	GetProfile: (Player) -> any,
	SendToast: (Player, string, string?) -> (),
	SyncProfile: (Player) -> (), -- progression-only sync: balances changed, the squad did not
	XpMultiplier: (Player) -> number, -- Pass XP Potion
}

local BattlePassService = {}
local deps: Dependencies? = nil

local SEASON_CHECK = 5
local MAX_REQUESTS_PER_SECOND = 4

local recentRequests: { [Player]: { number } } = {}

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local kept = {}
	for _, t in recentRequests[player] or {} do
		if now - t < 1 then table.insert(kept, t) end
	end
	local allowed = #kept < MAX_REQUESTS_PER_SECOND
	if allowed then table.insert(kept, now) end
	recentRequests[player] = kept
	return allowed
end

-- Moves the profile to the current season. A finished season's unlocked, unclaimed rewards are
-- granted here, in the same step that resets the track, so they are paid exactly once.
local function rollover(player: Player, profile: any, state: BattlePassRules.State, now: number)
	local owed = BattlePassRules.Rollover(state, now)
	if not owed then return end
	local d = deps
	if #owed > 0 then
		local reward = RewardRules.Merge(owed)
		RewardRules.Grant(profile, reward)
		if d then d.SendToast(player, "Season ended|Unclaimed rewards delivered: " .. RewardRules.Describe(reward), "SUCCESS") end
	end
	if d then
		d.SendToast(player, "Battle Pass|" .. BattlePassRules.SeasonName(state.Season) .. " has begun", "INFO")
		d.SyncProfile(player)
	end
end

local function current(player: Player): (any, BattlePassRules.State?)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not profile then return nil, nil end
	local now = os.time()
	local state = BattlePassRules.EnsureState(profile, now)
	rollover(player, profile, state, now)
	return profile, state
end

-- Old saves gain profile.BattlePass here too (ProfileMigrations v11 also adds it).
function BattlePassService.EnsureState(profile: any)
	BattlePassRules.EnsureState(profile, os.time())
end

-- Battle Pass XP for a gameplay action (a key of BattlePassConfig.Xp). The caller syncs the profile
-- as part of its own reward; a level-up syncs here so the rail badge appears at once.
function BattlePassService.AddXp(player: Player, source: string, count: number?)
	local base = Config.Xp[source]
	local d = deps
	if not base or not d then return end
	local profile, state = current(player)
	if not profile or not state then return end
	local amount = math.round(base * math.max(1, count or 1) * d.XpMultiplier(player))
	local gained = BattlePassRules.AddXp(state, amount)
	if gained > 0 then
		local level = BattlePassRules.LevelOf(state.Xp)
		d.SendToast(player, string.format("Battle Pass|Level %d reached · reward ready", level), "SUCCESS")
		d.SyncProfile(player)
	end
end

-- Unlocks the premium row for the current season (ShopService, after a granted receipt). Returns
-- the toast line. A second unlock in one season is paid as XP, so a receipt never buys nothing.
function BattlePassService.UnlockPremium(player: Player): string
	local profile, state = current(player)
	assert(profile and state, "profile not loaded")
	if BattlePassRules.UnlockPremium(state) then
		return "Premium Pass unlocked: " .. BattlePassRules.SeasonName(state.Season)
	end
	BattlePassRules.AddXp(state, Config.DuplicatePremiumLevels * Config.XpPerLevel)
	return string.format("Premium Pass already owned: +%d Battle Pass levels", Config.DuplicatePremiumLevels)
end

local function handle(player: Player, action: any, track: any, level: any): any
	local d = deps
	if not d or not d.GetProfile(player) then return { Ok = false, Message = "Your save is still loading." } end
	if not allowRequest(player) then return { Ok = false, Message = "Slow down." } end
	if type(action) ~= "string" then return { Ok = false, Message = "Unknown request." } end
	local profile, state = current(player)
	if not profile or not state then return { Ok = false, Message = "Your save is still loading." } end

	local reward: BattlePassRules.Reward
	if action == "CLAIM" then
		local claimed, problem = BattlePassRules.Claim(state, track, level)
		if not claimed then return { Ok = false, Message = problem or "Not available." } end
		reward = claimed
	elseif action == "CLAIM_ALL" then
		local rewards = BattlePassRules.ClaimAll(state)
		if #rewards == 0 then return { Ok = false, Message = "Nothing to claim yet." } end
		reward = RewardRules.Merge(rewards)
	elseif action == "DEV_UNLOCK" and RunService:IsStudio() then
		local message = BattlePassService.UnlockPremium(player)
		d.SyncProfile(player)
		return { Ok = true, Message = message }
	else
		return { Ok = false, Message = "Unknown request." }
	end

	-- The claim was recorded and the reward is granted in the same step (nothing yields between
	-- them), so a repeated request can never pay twice.
	RewardRules.Grant(profile, reward)
	local text = RewardRules.Describe(reward)
	d.SendToast(player, "Battle Pass|" .. text, "SUCCESS")
	d.SyncProfile(player)
	return { Ok = true, Message = text }
end

function BattlePassService.Init(dependencies: Dependencies)
	deps = dependencies

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local folder = remotes:FindFirstChild("BattlePassRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BattlePassRemotes"
		folder.Parent = remotes
	end
	local request = folder:FindFirstChild("BattlePassRequest") :: RemoteFunction?
	if not request then
		request = Instance.new("RemoteFunction")
		request.Name = "BattlePassRequest"
		request.Parent = folder
	end
	;(request :: RemoteFunction).OnServerInvoke = handle

	Players.PlayerRemoving:Connect(function(player) recentRequests[player] = nil end)

	-- A season can end while a player is online: check every loaded profile on a slow tick. This
	-- also rolls a save that was last played in an earlier season, shortly after it loads.
	task.spawn(function()
		while true do
			task.wait(SEASON_CHECK)
			for _, player in Players:GetPlayers() do
				current(player)
			end
		end
	end)
end

return BattlePassService
