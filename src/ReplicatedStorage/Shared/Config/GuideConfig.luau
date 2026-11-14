--!strict
-- ReplicatedStorage/Shared/Config/GuideConfig.luau
-- The onboarding lessons (GDD §4.7). `Core` lessons form one linear chain, played in the order of
-- the player's chain (`Chains`, picked by their experiment arm): the player is held to the current
-- one (a spotlight on the control to press, or an arrow to walk along) until it is done. The other
-- lessons are conditional: they appear when their moment comes (carrying a relic, a hero at its
-- level cap, an open raid) and can be put off with "Later". A lesson can be core in one chain and
-- conditional in another (Bank).
--
-- Copy rules: Title is the goal in two to four words. Description says where to go. Action is the
-- two or three words shown beside the highlighted control.

export type Reward = { Gold: number?, Gems: number? }
export type Lesson = {
	Id: string,
	Title: string,
	Description: string,
	Action: string?,
	Target: string?, -- where the cue points: a plot building, "Squad", "Tower", "Hub", "Bank", "Upgrades", "Raid"
	Control: string?, -- a specific control or node, filled in by GuideLessons
	Core: boolean?,
	Index: number?, -- position in the core chain (1-based)
	Total: number?,
	Reward: Reward?,
}

local function lesson(id: string, title: string, description: string, action: string?, target: string?, reward: Reward?): Lesson
	return { Id = id, Title = title, Description = description, Action = action, Target = target, Reward = reward }
end

local Lessons: { [string]: Lesson } = {
	-- Core chain ---------------------------------------------------------------------------------
	Summon = lesson("Summon", "Summon a hero", "Go to the Summoning Altar.", "Summon here", "Summoning", { Gems = 200 }),
	Limited = lesson("Limited", "Try the limited banner", "Pull once on A Star's Arrival.", "Summon once", "Summoning", { Gems = 200 }),
	Squad = lesson("Squad", "Set your squad", "Open Squad and place a hero.", "Pick a hero", "Squad"),
	Visit = lesson("Visit", "Enter the Tower", "Go to Floor 1.", "Choose Floor 1", "Tower"),
	Clear = lesson("Clear", "Clear Floor 1", "Beat the enemies, then the boss.", nil, nil, { Gold = 5000 }),
	Return = lesson("Return", "Return to the Hub", "Take the portal or press Hub.", "Go back", "Hub"),
	Roll = lesson("Roll", "Forge a weapon", "Go to the Blacksmith.", "Roll once", "Blacksmith"),
	Equip = lesson("Equip", "Equip the weapon", "Go to the Blacksmith.", "Equip it", "Blacksmith", { Gems = 200 }),
	GuardPost = lesson("GuardPost", "Post a guard", "Go to the Guard Post.", "Assign a hero", "GuardPost", { Gold = 750 }),
	Tree = lesson("Tree", "Upgrade your fortress", "Open Upgrades.", "Build this", "Upgrades", { Gold = 1000 }),
	Synthesis = lesson("Synthesis", "Level up a hero", "Go to The Pit.", "Feed a spare hero", "ThePit", { Gems = 250 }),

	-- Conditional --------------------------------------------------------------------------------
	Ready = lesson("Ready", "Ready your squad", "Place a rested hero.", "Pick a hero", "Squad"),
	Recruit = lesson("Recruit", "Summon a spare hero", "Go to the Summoning Altar.", "Summon here", "Summoning"),
	Bank = lesson("Bank", "Bank your relic", "Carry it to a sanctuary.", nil, "Bank"),
	Upgrade = lesson("Upgrade", "Upgrade a weapon", "Go to the Blacksmith.", "Upgrade it", "Blacksmith", { Gems = 100 }),
	Promotion = lesson("Promotion", "Promote a hero", "Go to The Pit.", "Promote", "ThePit", { Gems = 100 }),
	Market = lesson("Market", "Staff the Market", "More Tower loot.", "Assign a hero", "Market"),
	TrainingGrounds = lesson("TrainingGrounds", "Staff the Training Grounds", "More squad power.", "Assign a hero", "TrainingGrounds"),
	GodsBlessing = lesson("GodsBlessing", "Staff God's Blessing", "Better summon luck.", "Assign a hero", "GodsBlessing"),
	Raid = lesson("Raid", "Join the raid", "Enter the Raid Portal.", nil, "Raid"),
}

-- The linear chains, first to last. v3 is the control arm. v4 (docs/first-session-and-social-plan.md
-- A3) adds the limited banner, makes banking the first relic a core step, and keeps the Forge and
-- fortress lessons for after the first return to the Hub.
local Chains = table.freeze({
	v3 = table.freeze({ "Summon", "Squad", "Visit", "Clear", "Return", "Roll", "Equip", "GuardPost", "Tree", "Synthesis" }),
	v4 = table.freeze({ "Summon", "Limited", "Squad", "Visit", "Clear", "Bank", "Return", "Roll", "Equip", "GuardPost", "Tree", "Synthesis" }),
})
local Chain = Chains.v3

for _, entry in Lessons do
	if entry.Reward then table.freeze(entry.Reward) end
	table.freeze(entry)
end

local GuideConfig: any = table.clone(Lessons)
GuideConfig.Chain = Chain -- the control chain (kept for older callers)
GuideConfig.Chains = Chains

-- Rewards that differ from the lesson's own in a chain. `false` pays nothing. In v4, Equip's
-- 200 Gems move to the Bank step, so they arrive in the first five minutes.
local RewardOverrides: { [string]: { [string]: Reward | false } } = {
	v4 = { Bank = table.freeze({ Gems = 200 }), Equip = false },
}

function GuideConfig.RewardFor(chainId: string, id: string): Reward?
	local override = RewardOverrides[chainId] and RewardOverrides[chainId][id]
	if override == false then return nil end
	if override then return override end
	local entry = Lessons[id]
	return entry and entry.Reward
end

-- A lesson's place in a chain: (index, total), or nil when it is not a core step of that chain.
function GuideConfig.Position(chainId: string, id: string): (number?, number)
	local chain = Chains[chainId] or Chains.v3
	for index, lessonId in chain do
		if lessonId == id then return index, #chain end
	end
	return nil, #chain
end

-- Every lesson, chain first, then the conditional ones (the Guide help panel lists them in this order).
local ordered: { Lesson } = {}
for _, id in Chains.v4 do
	if id ~= "Bank" then table.insert(ordered, Lessons[id]) end
end
for _, id in { "Bank", "Upgrade", "Promotion", "Market", "TrainingGrounds", "GodsBlessing", "Raid" } do table.insert(ordered, Lessons[id]) end
GuideConfig.Ordered = table.freeze(ordered)

-- Onboarding experiment arms (docs/first-session-and-social-plan.md, A1). A new profile's arm is
-- picked once, on its first join, from the "OnboardingArm" experience config (ConfigService), and
-- saved so the player never changes arms mid-onboarding. Profiles without an arm use DefaultArm.
-- Each arm names its chain and the Phase 1 features it gets.
export type Arm = { Chain: string, Showcase: boolean, FrameUltimate: boolean }
GuideConfig.Arms = table.freeze({
	control = table.freeze({ Chain = "v3", Showcase = false, FrameUltimate = false }),
	v1 = table.freeze({ Chain = "v4", Showcase = false, FrameUltimate = false }),
	v2 = table.freeze({ Chain = "v4", Showcase = true, FrameUltimate = true }),
})
GuideConfig.DefaultArm = "v2"

return table.freeze(GuideConfig)
