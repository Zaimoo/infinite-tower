--!strict
-- ReplicatedStorage/Shared/Util/OnboardingFunnel.luau
-- Pure rules for the first-session milestone funnel (docs/first-session-and-social-plan.md, A1).
-- The milestones are fixed, not guide step numbers, so every experiment arm feeds the same
-- Creator Hub onboarding funnel even when the guide chain changes. OnboardingService logs them.

local OnboardingFunnel = {}

OnboardingFunnel.Milestones = table.freeze({
	"Joined",
	"FirstPull",
	"LimitedPull",
	"SquadSet",
	"EnteredTower",
	"FirstUltimate",
	"ClearedFloor1",
	"PickedUpRelic",
	"BankedRelic",
	"ReachedFloor2",
	"FirstTheft",
	"FirstDuel",
	"DuelWon",
	"BankedStolenRelic",
})

local index: { [string]: number } = {}
for i, name in OnboardingFunnel.Milestones do
	index[name] = i
end
OnboardingFunnel.Index = table.freeze(index)

-- Funnel steps must be sequential and 1-based, so reaching a milestone also logs every earlier
-- step not yet logged. `logged` is the highest step already logged. Empty when the milestone was
-- reached before (or is unknown).
function OnboardingFunnel.StepsToLog(logged: number, name: string): { number }
	local target = index[name]
	local steps = {}
	if not target then return steps end
	for step = math.max(1, logged + 1), target do
		table.insert(steps, step)
	end
	return steps
end

-- The milestones an authoritative guide event (OnboardingService.Report) can complete.
function OnboardingFunnel.FromEvent(eventName: string, detail: (string | number)?): { string }
	if eventName == "HeroSummoned" then return { "FirstPull" } end
	if eventName == "LimitedSummoned" then return { "LimitedPull" } end
	if eventName == "SquadDeployed" then return { "SquadSet" } end
	if eventName == "FloorVisited" and detail == 1 then return { "EnteredTower" } end
	if eventName == "FloorVisited" and detail == 2 then return { "ReachedFloor2" } end
	if eventName == "FloorCleared" and detail == 1 then return { "ClearedFloor1" } end
	if eventName == "RelicBanked" then
		return if detail == "Stolen" then { "BankedRelic", "BankedStolenRelic" } else { "BankedRelic" }
	end
	return {}
end

return table.freeze(OnboardingFunnel)
