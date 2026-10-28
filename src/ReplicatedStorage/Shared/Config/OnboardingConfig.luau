--!strict
-- ReplicatedStorage/Shared/Config/OnboardingConfig.luau
-- The first-session quest chain (docs/rework-plan/PHASE_4_ONBOARDING_AND_PROGRESSION.md §2.1).
-- Each step unlocks the next systems; server handlers reject actions on systems still locked.

export type Step = {
	Id: string,
	Title: string, -- Displayed in the Goal Tracker
	Description: string, -- Subtitle or guidance hint
	Event: string, -- Authoritative server trigger name
	TargetCount: number, -- Required repetitions (usually 1)
	Unlocks: { string }, -- System keys unlocked upon completion
	Reward: { Gold: number?, Gems: number? }?,
}

local Steps: { Step } = {
	{
		Id = "step_summon",
		Title = "Summon your first hero",
		Description = "Visit the Summoning Altar on your Fortress Plot",
		Event = "HeroSummoned",
		TargetCount = 1,
		Unlocks = { "Squad" },
		Reward = { Gems = 200 },
	},
	{
		Id = "step_deploy",
		Title = "Deploy your squad",
		Description = "Assign a hero to a squad slot at the War Banner",
		Event = "SquadDeployed",
		TargetCount = 1,
		Unlocks = { "Tower" },
		Reward = { Gold = 500 },
	},
	{
		Id = "step_floor1",
		Title = "Clear Floor 1 of the Tower",
		Description = "Defeat the Floor 1 boss in the Infinite Tower",
		Event = "FloorCleared",
		TargetCount = 1,
		Unlocks = { "Forge" },
		Reward = { Gold = 1000 },
	},
	{
		Id = "step_forge",
		Title = "Upgrade a weapon at the Forge",
		Description = "Ascend an artifact weapon at the Blacksmith",
		Event = "ArtifactUpgraded",
		TargetCount = 1,
		Unlocks = { "Facilities", "FortressTree" },
		Reward = { Gems = 100 },
	},
	{
		Id = "step_facilities",
		Title = "Assign a hero to work",
		Description = "Put a benched hero to work at the Outskirts Guard Post",
		Event = "FacilityAssigned",
		TargetCount = 1,
		Unlocks = { "Pit" },
		Reward = { Gold = 750 },
	},
	{
		Id = "step_pit",
		Title = "Level up a hero in The Pit",
		Description = "Synthesize duplicate heroes to level up your squad",
		Event = "PitUsed",
		TargetCount = 1,
		Unlocks = { "TowerFloor5" },
		Reward = { Gems = 250 },
	},
	{
		Id = "step_tree",
		Title = "Grow your fortress",
		Description = "Unlock a new node in the Fortress Tree at the Architect's Table",
		Event = "TreeNodeUnlocked",
		TargetCount = 1,
		Unlocks = {},
		Reward = { Gold = 1000 },
	},
}

for _, step in Steps do
	table.freeze(step.Unlocks)
	if step.Reward then
		table.freeze(step.Reward)
	end
	table.freeze(step)
end

return table.freeze(Steps)
