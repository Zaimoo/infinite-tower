--!strict
-- ReplicatedStorage/Shared/Util/Onboarding.luau
-- Pure onboarding rules (Phase 4 §2-§3): step progression, system unlocks and the v3 save migration
-- of those tables. OnboardingService owns the live state and applies rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Steps = require(ReplicatedStorage.Shared.Config.OnboardingConfig)

export type Guide = { Enabled: boolean?, Facts: { [string]: boolean }, Snoozed: { [string]: number } }
export type State = { StepIndex: number, StepProgress: number, CompletedSteps: { [string]: boolean }, Guide: Guide? }

local Onboarding = {}

Onboarding.Steps = Steps

-- Systems that are never gated.
Onboarding.AlwaysUnlocked = table.freeze({ Summon = true })

function Onboarding.NewState(): State
	return { StepIndex = 1, StepProgress = 0, CompletedSteps = {} }
end

function Onboarding.ActiveStep(state: State?): any
	return if state then Steps[state.StepIndex] else nil
end

function Onboarding.EnsureGuide(state: State): Guide
	local guide = state.Guide
	if guide then return guide end
	guide = { Facts = {}, Snoozed = {} }
	state.Guide = guide
	return guide
end

function Onboarding.HasReadySquad(profile: any, now: number): boolean
	for _, hero in profile.Heroes or {} do
		if string.match(hero.Assignment or "", "^SQUAD_SLOT_%d+$")
			and (hero.ComaUntilTimestamp or 0) <= now and not hero.IsHardAuditComa then
			return true
		end
	end
	return false
end

function Onboarding.UpdateAccess(profile: any, ready: boolean)
	local unlocks = profile.Unlocks
	unlocks.Squad = true
	if ready then unlocks.Tower = true end
	if (profile.HighestClearedFloor or 0) >= 1 or (profile.MaxFloorReached or 0) >= 2 then
		unlocks.Tower = true
		unlocks.Forge = true
		unlocks.Facilities = true
		unlocks.FortressTree = true
		unlocks.Pit = true
	end
	-- The normal floor-access check still requires MaxFloorReached to be at least 5.
	if (profile.MaxFloorReached or 0) >= 5 then unlocks.TowerFloor5 = true end
end

function Onboarding.IsUnlocked(unlocks: { [string]: boolean }?, key: string): boolean
	return Onboarding.AlwaysUnlocked[key] == true or (unlocks ~= nil and unlocks[key] == true)
end

-- Advances the state when `eventName` matches the active step. Returns the completed step (whose
-- Reward the caller grants) or nil. Unlocks are merged into `unlocks` in place.
function Onboarding.Report(state: State, unlocks: { [string]: boolean }, eventName: string): any
	local step = Steps[state.StepIndex]
	if not step or step.Event ~= eventName then
		return nil
	end
	state.StepProgress += 1
	if state.StepProgress < step.TargetCount then
		return nil
	end
	state.CompletedSteps[step.Id] = true
	for _, key in step.Unlocks do
		unlocks[key] = true
	end
	state.StepIndex += 1
	state.StepProgress = 0
	return step
end

-- v3 migration: fresh onboarding state, with existing players grandfathered by their progress.
function Onboarding.MigrateUnlocks(profile: any)
	profile.Onboarding = Onboarding.NewState()
	local unlocks: { [string]: boolean } = { Summon = true }
	local heroCount = 0
	for _ in pairs(profile.Heroes or {}) do
		heroCount += 1
	end
	local maxFloor = profile.MaxFloorReached or 0
	if heroCount > 1 then unlocks.Squad = true end
	if maxFloor >= 1 then unlocks.Tower = true end
	if maxFloor >= 2 then
		unlocks.Forge = true
		unlocks.Facilities = true
		unlocks.FortressTree = true
	end
	if maxFloor >= 5 then
		unlocks.Pit = true
	end
	profile.Unlocks = unlocks
	-- Skip steps whose systems the player already has, so the tracker shows a real next goal.
	local state = profile.Onboarding
	while true do
		local step = Steps[state.StepIndex]
		if not step or #step.Unlocks == 0 then break end
		local all = true
		for _, key in step.Unlocks do
			if not unlocks[key] then all = false break end
		end
		if not all then break end
		state.CompletedSteps[step.Id] = true
		state.StepIndex += 1
	end
end

return table.freeze(Onboarding)
