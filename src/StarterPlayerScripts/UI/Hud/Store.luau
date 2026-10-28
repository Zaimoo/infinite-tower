--!strict
-- StarterPlayerScripts/UI/Hud/Store.luau
-- Client-side read model for the Phase 5 HUD: the latest synced profile and onboarding step, with
-- one Changed signal. The server stays authoritative; this only mirrors what it sends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileDeltaSync = Remotes:WaitForChild("SyndicateRemotes"):WaitForChild("ProfileDeltaSync") :: RemoteEvent

local Store = {}

local changed = Instance.new("BindableEvent")
Store.Changed = changed.Event

Store.Profile = nil :: any
Store.Goal = nil :: any -- OnboardingSync.Step, or nil once the chain is complete
Store.Revision = 0

local function bump()
	Store.Revision += 1
	changed:Fire(Store.Revision)
end

-- HUDController merges Pit deltas into _G.CurrentProfile; read it after that handler has run.
ProfileDeltaSync.OnClientEvent:Connect(function(profile: any)
	task.defer(function()
		Store.Profile = _G.CurrentProfile or (type(profile) == "table" and not profile._PitDelta and profile) or Store.Profile
		bump()
	end)
end)

task.spawn(function()
	local progression = Remotes:WaitForChild("ProgressionRemotes", 30)
	local sync = progression and progression:WaitForChild("OnboardingSync", 30)
	if sync and sync:IsA("RemoteEvent") then
		sync.OnClientEvent:Connect(function(message: any)
			if type(message) ~= "table" then return end
			Store.Goal = if type(message.Step) == "table" then message.Step else nil
			bump()
		end)
	end
end)

if _G.CurrentProfile then
	Store.Profile = _G.CurrentProfile
end

return Store
