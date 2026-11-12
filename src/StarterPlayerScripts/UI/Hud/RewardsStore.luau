--!strict
-- StarterPlayerScripts/UI/Hud/RewardsStore.luau
-- Client mirror of the free rewards (GDD §4.8). The server sends a State (RewardRules.View plus the
-- friend boost) on join, at the daily reset, when the boost changes and in every claim reply. The
-- client only counts playtime forward between those messages so timers and the rail badge stay
-- live; the server decides every claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("RewardRules"))

local RewardsStore = {}

local changed = Instance.new("BindableEvent")
RewardsStore.Changed = changed.Event
RewardsStore.State = nil :: any
RewardsStore.ReceivedAt = 0

local request: RemoteFunction? = nil
local refreshing = false

local function accept(state: any)
	if type(state) ~= "table" or type(state.Playtime) ~= "table" or type(state.Daily) ~= "table" then return end
	RewardsStore.State = state
	RewardsStore.ReceivedAt = os.clock()
	changed:Fire()
end

-- Seconds since the last server State.
function RewardsStore.Elapsed(): number
	return if RewardsStore.State then os.clock() - RewardsStore.ReceivedAt else 0
end

-- Rewards ready to claim right now (the rail badge).
function RewardsStore.Claimable(): number
	local state = RewardsStore.State
	if not state then return 0 end
	return RewardRules.ClaimableCount(state, RewardsStore.Elapsed())
end

-- Sends a request and adopts the State in the reply. Yields. Returns (ok, message).
function RewardsStore.Request(action: string, arg: any?): (boolean, string?)
	local remote = request
	if not remote then return false, "Rewards are still loading." end
	local ok, result = pcall(function() return remote:InvokeServer(action, arg) end)
	if not ok or type(result) ~= "table" then return false, "Couldn't reach the server. Try again." end
	accept(result.State)
	return result.Ok == true, if type(result.Message) == "string" then result.Message else nil
end

-- Asks for a fresh State (after a reset passed while the window was open).
function RewardsStore.Refresh()
	if refreshing then return end
	refreshing = true
	task.spawn(function()
		RewardsStore.Request("GET")
		task.wait(2)
		refreshing = false
	end)
end

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RewardsRemotes", 60)
	if not folder then return end
	local sync = folder:WaitForChild("RewardsSync", 30)
	if sync and sync:IsA("RemoteEvent") then sync.OnClientEvent:Connect(accept) end
	local func = folder:WaitForChild("RewardsRequest", 30)
	if func and func:IsA("RemoteFunction") then
		request = func
		-- The save may still be loading on join: ask until the server has a State.
		for _ = 1, 20 do
			if RewardsStore.State then break end
			RewardsStore.Request("GET")
			if not RewardsStore.State then task.wait(1.5) end
		end
	end
end)

return RewardsStore
