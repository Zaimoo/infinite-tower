--!strict
-- ServerScriptService/Core/OnboardingService.luau
-- Server owner of profile.Onboarding and profile.Unlocks (Phase 4 §2.2). Gameplay handlers call
-- Report(player, event) after an authoritative success; locked systems are checked with IsUnlocked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Onboarding = require(ReplicatedStorage.Shared.Util.Onboarding)

export type Dependencies = {
	GetProfile: (Player) -> any,
	SendToast: (Player, string, string?) -> (),
	SyncProfile: (Player) -> (),
	SyncRemote: RemoteEvent,
}

local OnboardingService = {}
local deps: Dependencies? = nil

-- Human-readable hint for each gated system, shown when a locked action is rejected.
local LOCK_HINTS: { [string]: string } = {
	Squad = "Summon your first hero to unlock squad management.",
	Tower = "Deploy your squad at the War Banner to unlock the Tower.",
	Forge = "Clear Floor 1 of the Tower to unlock the Forge.",
	Facilities = "Upgrade a weapon at the Forge to unlock facilities.",
	FortressTree = "Upgrade a weapon at the Forge to unlock the Fortress Tree.",
	Pit = "Put a hero to work at a facility to unlock The Pit.",
	TowerFloor5 = "Level up a hero in The Pit to unlock Floor 5 and beyond.",
}

function OnboardingService.Init(dependencies: Dependencies)
	deps = dependencies
end

function OnboardingService.EnsureState(profile: any)
	if type(profile.Onboarding) ~= "table" then
		profile.Onboarding = Onboarding.NewState()
	end
	if type(profile.Unlocks) ~= "table" then
		profile.Unlocks = { Summon = true }
	end
end

function OnboardingService.IsUnlocked(player: Player, key: string): boolean
	local d = deps
	local profile = d and d.GetProfile(player)
	return profile ~= nil and Onboarding.IsUnlocked(profile.Unlocks, key)
end

function OnboardingService.LockedMessage(key: string): string
	return LOCK_HINTS[key] or "This system is still locked."
end

-- Rejects with a toast when `key` is locked. Returns true when the action may proceed.
function OnboardingService.Require(player: Player, key: string): boolean
	if OnboardingService.IsUnlocked(player, key) then
		return true
	end
	local d = deps
	if d then
		d.SendToast(player, "🔒 " .. OnboardingService.LockedMessage(key), "WARN")
	end
	return false
end

function OnboardingService.Push(player: Player)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return end
	OnboardingService.EnsureState(profile)
	local step = Onboarding.ActiveStep(profile.Onboarding)
	d.SyncRemote:FireClient(player, {
		Step = step and {
			Id = step.Id,
			Index = profile.Onboarding.StepIndex,
			Total = #Onboarding.Steps,
			Title = step.Title,
			Description = step.Description,
			Progress = profile.Onboarding.StepProgress,
			TargetCount = step.TargetCount,
			Reward = step.Reward,
		} or nil,
		Unlocks = profile.Unlocks,
	})
end

function OnboardingService.Report(player: Player, eventName: string)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return end
	OnboardingService.EnsureState(profile)
	local completed = Onboarding.Report(profile.Onboarding, profile.Unlocks, eventName)
	if not completed then return end
	local reward = completed.Reward
	local parts = {}
	if reward then
		if reward.Gold then
			profile.Currencies.Gold += reward.Gold
			table.insert(parts, string.format("+%d Gold", reward.Gold))
		end
		if reward.Gems then
			profile.Currencies.Gems += reward.Gems
			table.insert(parts, string.format("+%d Gems", reward.Gems))
		end
	end
	local suffix = if #parts > 0 then " (" .. table.concat(parts, ", ") .. ")" else ""
	d.SendToast(player, "✅ Goal complete: " .. completed.Title .. suffix, "SUCCESS")
	d.SyncProfile(player)
	OnboardingService.Push(player)
end

-- Studio prototype helper: open every system and finish the quest chain.
function OnboardingService.UnlockAll(player: Player)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return end
	OnboardingService.EnsureState(profile)
	for _, step in Onboarding.Steps do
		for _, key in step.Unlocks do
			profile.Unlocks[key] = true
		end
		profile.Onboarding.CompletedSteps[step.Id] = true
	end
	profile.Onboarding.StepIndex = #Onboarding.Steps + 1
	profile.Onboarding.StepProgress = 0
	OnboardingService.Push(player)
end

return OnboardingService
