--!strict
-- tests/onboarding-funnel.spec.luau
-- First-session funnel (docs/first-session-and-social-plan.md A1, GDD §4.7): fixed milestones,
-- sequential 1-based steps, and the guide events that complete them.

local Funnel = require(nodes["ReplicatedStorage.Shared.Util.OnboardingFunnel"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function same(a: { number }, b: { number }): boolean
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

test("funnel: milestones are unique and indexed from 1", function()
	assert(Funnel.Milestones[1] == "Joined", "Joined is step 1")
	assert(Funnel.Milestones[#Funnel.Milestones] == "BankedStolenRelic", "the stolen bank is last")
	for i, name in Funnel.Milestones do
		assert(Funnel.Index[name] == i, name .. " indexed")
	end
end)

test("funnel: a milestone logs every earlier step not yet logged, in order", function()
	assert(same(Funnel.StepsToLog(0, "Joined"), { 1 }), "first step")
	assert(same(Funnel.StepsToLog(1, "SquadSet"), { 2, 3, 4 }), "skipped steps are filled in")
	assert(same(Funnel.StepsToLog(4, "SquadSet"), {}), "never logged twice")
	assert(same(Funnel.StepsToLog(6, "SquadSet"), {}), "an earlier milestone after a later one logs nothing")
	assert(same(Funnel.StepsToLog(0, "NotAMilestone"), {}), "unknown names log nothing")
end)

test("funnel: guide events map to their milestones", function()
	local function one(list: { string }, name: string): boolean
		return #list == 1 and list[1] == name
	end
	assert(one(Funnel.FromEvent("HeroSummoned"), "FirstPull"), "summon")
	assert(one(Funnel.FromEvent("LimitedSummoned"), "LimitedPull"), "limited summon")
	assert(one(Funnel.FromEvent("SquadDeployed"), "SquadSet"), "squad")
	assert(one(Funnel.FromEvent("FloorVisited", 1), "EnteredTower"), "floor 1 visit")
	assert(one(Funnel.FromEvent("FloorVisited", 2), "ReachedFloor2"), "floor 2 visit")
	assert(#Funnel.FromEvent("FloorVisited", 3) == 0, "floor 3 visit is not a milestone")
	assert(one(Funnel.FromEvent("FloorCleared", 1), "ClearedFloor1"), "floor 1 clear")
	assert(#Funnel.FromEvent("FloorCleared", 2) == 0, "floor 2 clear is not a milestone")
	assert(one(Funnel.FromEvent("RelicBanked"), "BankedRelic"), "bank")
	local stolen = Funnel.FromEvent("RelicBanked", "Stolen")
	assert(#stolen == 2 and stolen[1] == "BankedRelic" and stolen[2] == "BankedStolenRelic", "stolen bank")
end)

print(string.format("onboarding-funnel.spec: %d passed", passed))
