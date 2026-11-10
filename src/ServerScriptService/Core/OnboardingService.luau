--!strict
-- ServerScriptService/Core/OnboardingService.luau
-- Server owner of profile.Onboarding and profile.Unlocks (Phase 4 §2.2). Gameplay handlers call
-- Report(player, event) after an authoritative success; locked systems are checked with IsUnlocked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuideConfig = require(ReplicatedStorage.Shared.Config.GuideConfig)
local Onboarding = require(ReplicatedStorage.Shared.Util.Onboarding)
local GuideLessons = require(script.Parent.GuideLessons)

export type Dependencies = {
	GetProfile: (Player) -> any,
	SendToast: (Player, string, string?) -> (),
	SyncProfile: (Player) -> (),
	SyncRemote: RemoteEvent,
	PitLesson: (any, boolean, boolean) -> string?,
}

local OnboardingService = {}
local deps: Dependencies? = nil
local latest: { [Player]: any } = {}
local lastRequest: { [Player]: number } = {}
local sessionStarted: { [Player]: number } = {}
local offered: { [Player]: { [string]: boolean } } = {}

local function telemetry(player: Player, event: string, label: string, version: string, value: number?)
	if RunService:IsStudio() then return end
	task.defer(function()
		if player.Parent ~= Players then return end
		pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, event, value or 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = label,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = version,
		})
	end)
end

-- Human-readable hint for each gated system, shown when a locked action is rejected.
local LOCK_HINTS: { [string]: string } = {
	Squad = "Summon your first hero to unlock squad management.",
	Tower = "Deploy your squad at the War Banner to unlock the Tower.",
	Forge = "Clear Floor 1 of the Tower to unlock the Forge.",
	Facilities = "Upgrade a weapon at the Forge to unlock facilities.",
	FortressTree = "Upgrade a weapon at the Forge to unlock Upgrades.",
	Pit = "Put a hero to work at a facility to unlock The Pit.",
	TowerFloor5 = "Level up a hero in The Pit to unlock Floor 5 and beyond.",
}

function OnboardingService.Init(dependencies: Dependencies)
	deps = dependencies
	dependencies.SyncRemote.OnServerEvent:Connect(function(player: Player, action: any, id: any)
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < 0.35 then return end
		lastRequest[player] = now
		local profile = dependencies.GetProfile(player)
		if not profile then return end
		local guide = profile.Onboarding.Guide
		if action == "Refresh" then
			OnboardingService.Push(player, true)
		elseif guide and guide.Enabled and action == "Snooze" and type(id) == "string"
			and latest[player] and latest[player].Step and latest[player].Step.Id == id then
			guide.Snoozed[id] = os.time() + 900
			telemetry(player, "GuideSnoozed", id, "v2")
			OnboardingService.Push(player)
		elseif guide and guide.Enabled and action == "Resume" then
			table.clear(guide.Snoozed)
			OnboardingService.Push(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		latest[player] = nil
		lastRequest[player] = nil
		sessionStarted[player] = nil
		offered[player] = nil
	end)
	-- Ready heroes can recover and raids can open without a profile transaction.
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				local profile = dependencies.GetProfile(player)
				if profile and profile.Onboarding.Guide and profile.Onboarding.Guide.Enabled then
					OnboardingService.Push(player)
				end
			end
		end
	end)
end

function OnboardingService.EnsureState(profile: any)
	if type(profile.Onboarding) ~= "table" then
		profile.Onboarding = Onboarding.NewState()
	end
	if type(profile.Unlocks) ~= "table" then
		profile.Unlocks = { Summon = true }
	end
	local guide = Onboarding.EnsureGuide(profile.Onboarding)
	if guide.Enabled == nil then
		guide.Enabled = workspace:GetAttribute("OnboardingV2") ~= false
		-- Progress from an older build is evidence for access and lesson placement, not a payout.
		if (profile.HighestClearedFloor or 0) >= 1 or (profile.MaxFloorReached or 0) >= 2 then
			guide.Facts.Ready = true
			guide.Facts.Visit = true
			guide.Facts.Clear = true
			guide.Facts.Return = true
		end
		local completed = profile.Onboarding.CompletedSteps
		guide.Facts.Summon = completed.step_summon
		guide.Facts.Upgrade = completed.step_forge
		guide.Facts.Tree = completed.step_tree
		for _, facility in { "GuardPost", "Market", "TrainingGrounds", "GodsBlessing" } do
			local data = profile.Facilities and profile.Facilities[facility]
			if data and #(data.AssignedHeroUUIDs or {}) > 0 then guide.Facts[facility] = true end
		end
		if profile.Raid and (profile.Raid.Participations or 0) > 0 then guide.Facts.Raid = true end
	end
	if guide.Enabled then Onboarding.UpdateAccess(profile, Onboarding.HasReadySquad(profile, os.time())) end
end

function OnboardingService.IsUnlocked(player: Player, key: string): boolean
	local d = deps
	local profile = d and d.GetProfile(player)
	if profile and key == "Tower" and profile.Onboarding.Guide and profile.Onboarding.Guide.Enabled then
		Onboarding.UpdateAccess(profile, Onboarding.HasReadySquad(profile, os.time()))
	end
	return profile ~= nil and Onboarding.IsUnlocked(profile.Unlocks, key)
end

local V2_LOCK_HINTS: { [string]: string } = {
	Tower = "Deploy a rested hero in Squad to enter the Tower.",
	TowerFloor5 = "Clear Floor 4 to unlock Floor 5.",
	Forge = "Clear Floor 1 to unlock weapon upgrades.",
	Facilities = "Clear Floor 1 to assign heroes to facilities.",
	FortressTree = "Clear Floor 1 to unlock Upgrades.",
	Pit = "Clear Floor 1 to unlock The Pit.",
}

function OnboardingService.LockedMessage(key: string, player: Player?): string
	local d = deps
	local profile = d and player and d.GetProfile(player)
	if profile and profile.Onboarding.Guide and profile.Onboarding.Guide.Enabled and V2_LOCK_HINTS[key] then
		return V2_LOCK_HINTS[key]
	end
	return LOCK_HINTS[key] or "This system is still locked."
end

-- Rejects with a toast when `key` is locked. Returns true when the action may proceed.
function OnboardingService.Require(player: Player, key: string): boolean
	if OnboardingService.IsUnlocked(player, key) then
		return true
	end
	local d = deps
	if d then
		d.SendToast(player, "🔒 " .. OnboardingService.LockedMessage(key, player), "WARN")
	end
	return false
end

local function mark(player: Player, facts: { [string]: boolean }, id: string, version: string): boolean
	if facts[id] then return false end
	facts[id] = true
	telemetry(player, "GuideCompleted", id, version)
	local started = sessionStarted[player]
	if started and (id == "Visit" or id == "Clear" or id == "Return") then
		telemetry(player, "GuideTimeFromJoin", id, version, os.clock() - started)
	end
	return true
end

function OnboardingService.Push(player: Player, force: boolean?)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return end
	OnboardingService.EnsureState(profile)
	local guide = profile.Onboarding.Guide
	local now = os.time()
	sessionStarted[player] = sessionStarted[player] or os.clock()
	local version = if guide.Enabled then "v2" else "legacy"
	local ready = Onboarding.HasReadySquad(profile, now)
	mark(player, guide.Facts, "Bootstrap", version)
	if ready then mark(player, guide.Facts, "Ready", version) end
	local step: any
	if guide.Enabled then
		local character = player.Character
		local floor = if character then (character:GetAttribute("TowerFloorId") :: number? or 0) else 0
		local carrying = character ~= nil and character:GetAttribute("CarryingRelic") ~= nil
		local combat = _G.CombatSimulation
		local raid = _G.RaidService
		step = GuideLessons.Select(profile, {
			Floor = floor,
			Carrying = carrying,
			TravelSealed = carrying and floor > 0 and combat ~= nil and combat.IsBossLocked ~= nil and combat.IsBossLocked(player, floor),
			Ready = ready,
			CanRaid = raid ~= nil and raid.CanGuide ~= nil and not guide.Facts.Raid and raid.CanGuide(player),
			Now = now,
			PitLesson = d.PitLesson,
		})
	else
		local legacy = Onboarding.ActiveStep(profile.Onboarding)
		step = legacy and {
			Id = legacy.Id,
			Index = profile.Onboarding.StepIndex,
			Total = #Onboarding.Steps,
			Title = legacy.Title,
			Description = legacy.Description,
			Progress = profile.Onboarding.StepProgress,
			TargetCount = legacy.TargetCount,
			Reward = legacy.Reward,
		} or nil
	end
	local previous = latest[player]
	local old = previous and previous.Step
	local same = old == nil and step == nil or old and step and old.Id == step.Id
		and old.Description == step.Description and old.Control == step.Control and old.Progress == step.Progress
	if previous and same and not force then return end
	if step then
		local seen = offered[player] or {}
		offered[player] = seen
		if not seen[step.Id] then
			seen[step.Id] = true
			telemetry(player, "GuideOffered", step.Id, version)
		end
	end
	local message = { Step = step, V2 = guide.Enabled, Revision = if previous then previous.Revision + 1 else 1 }
	latest[player] = message
	d.SyncRemote:FireClient(player, message)
end

local GUIDE_EVENTS: { [string]: string } = {
	HeroSummoned = "Summon", ArtifactUpgraded = "Upgrade", ArtifactEquipped = "Equip",
	TreeNodeUnlocked = "Tree", RelicBanked = "Bank", RaidEntered = "Raid",
}
local PIT_EVENTS: { [string]: string } = { SYNTHESIS = "Synthesis", PROMOTION = "Promotion", CONVERSION = "Conversion", CRAFT = "Craft" }
local REWARDS: { [string]: number } = { Summon = 1, Clear = 3, Upgrade = 4, GuardPost = 5, Synthesis = 6, Promotion = 6, Tree = 7 }
local WORKERS: { [string]: boolean } = { GuardPost = true, Market = true, TrainingGrounds = true, GodsBlessing = true }

function OnboardingService.Report(player: Player, eventName: string, detail: (string | number)?)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return end
	OnboardingService.EnsureState(profile)
	local guide = profile.Onboarding.Guide
	local completed: any
	local completedTitle: string?
	local id = GUIDE_EVENTS[eventName]
	if eventName == "FloorCleared" and detail == 1 then id = "Clear" end
	if eventName == "FloorVisited" and detail == 1 then id = "Visit" end
	if eventName == "TowerReturned" and guide.Facts.Clear then id = "Return" end
	if eventName == "PitUsed" and type(detail) == "string" then id = PIT_EVENTS[detail] end
	if eventName == "FacilityAssigned" and type(detail) == "string" and WORKERS[detail] then id = detail end
	local first = id ~= nil and mark(player, guide.Facts, id, if guide.Enabled then "v2" else "legacy")
	if guide.Enabled then
		if not id or not first then
			OnboardingService.Push(player)
			return
		end
		local rewardIndex = REWARDS[id]
		local legacy = rewardIndex and Onboarding.Steps[rewardIndex]
		if legacy and not profile.Onboarding.CompletedSteps[legacy.Id] then
			profile.Onboarding.CompletedSteps[legacy.Id] = true
			completed = legacy
			local lesson = (GuideConfig :: any)[id]
			completedTitle = lesson and lesson.Title
		end
		if not completed then OnboardingService.Push(player); return end
	else
		if eventName == "FloorCleared" and detail ~= 1 then return end
		completed = Onboarding.Report(profile.Onboarding, profile.Unlocks, eventName)
		if completed then telemetry(player, "GuideCompleted", completed.Id, "legacy") end
	end
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
	d.SendToast(player, "✅ Goal complete: " .. (completedTitle or completed.Title) .. suffix, "SUCCESS")
	d.SyncProfile(player)
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
	for _, lesson in GuideConfig do profile.Onboarding.Guide.Facts[lesson.Id] = true end
	OnboardingService.Push(player)
end

return OnboardingService
