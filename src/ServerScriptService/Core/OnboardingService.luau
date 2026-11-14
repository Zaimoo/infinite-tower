--!strict
-- ServerScriptService/Core/OnboardingService.luau
-- Server owner of profile.Onboarding and profile.Unlocks (Phase 4 §2.2). Gameplay handlers call
-- Report(player, event) after an authoritative success; locked systems are checked with IsUnlocked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuideConfig = require(ReplicatedStorage.Shared.Config.GuideConfig)
local ArtifactCatalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
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
	Squad = "Summon a hero first",
	Tower = "Set your squad first",
	Forge = "Clear Floor 1 first",
	Facilities = "Upgrade a weapon first",
	FortressTree = "Upgrade a weapon first",
	Pit = "Staff a facility first",
	TowerFloor5 = "Level a hero in The Pit first",
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
		elseif guide and guide.Enabled and action == "Skip" then
			-- Leave the tutorial: every core lesson counts as seen (no rewards) and nothing stays locked.
			for _, lessonId in GuideConfig.Chain do
				if not guide.Facts[lessonId] then
					guide.Facts[lessonId] = true
					telemetry(player, "GuideSkipped", lessonId, "v3")
				end
			end
			OnboardingService.Push(player, true)
			dependencies.SyncProfile(player)
		elseif guide and guide.Enabled and action == "Snooze" and type(id) == "string"
			and latest[player] and latest[player].Step and latest[player].Step.Id == id
			and not latest[player].Step.Core then -- the core chain cannot be put off
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
	if guide.Enabled and (guide :: any).Version ~= 3 then
		-- Linear chain (v3): credit what an existing player has plainly already done, so only the
		-- lessons they never met are played. Runs once per profile.
		(guide :: any).Version = 3
		local facts = guide.Facts
		local cleared = facts.Clear or (profile.HighestClearedFloor or 0) >= 1 or (profile.MaxFloorReached or 0) >= 2
		if cleared then
			facts.Summon = true
			facts.Squad = true
			-- They had every system before the chain existed: keep it that way.
			profile.Unlocks.Forge, profile.Unlocks.Facilities, profile.Unlocks.FortressTree, profile.Unlocks.Pit = true, true, true, true
			if facts.Upgrade or facts.Equip then facts.Roll = true end
			for _, hero in profile.Heroes or {} do
				if string.match(hero.Assignment or "", "^SQUAD_SLOT_%d+$") and hero.EquippedArtifactUUID then
					facts.Roll, facts.Equip = true, true
				end
			end
		end
	end
	if guide.Enabled then Onboarding.UpdateAccess(profile, Onboarding.HasReadySquad(profile, os.time()), guide.Facts) end
end

-- The weapon type the player's first Forge roll is steered to (nil once that lesson is done).
function OnboardingService.StarterWeaponType(player: Player): string?
	local d = deps
	local profile = d and d.GetProfile(player)
	if not profile then return nil end
	local guide = profile.Onboarding and profile.Onboarding.Guide
	if not guide or not guide.Enabled or guide.Facts.Roll then return nil end
	return GuideLessons.StarterWeaponType(profile)
end

function OnboardingService.IsUnlocked(player: Player, key: string): boolean
	local d = deps
	local profile = d and d.GetProfile(player)
	if profile and key == "Tower" and profile.Onboarding.Guide and profile.Onboarding.Guide.Enabled then
		Onboarding.UpdateAccess(profile, Onboarding.HasReadySquad(profile, os.time()), profile.Onboarding.Guide.Facts)
	end
	return profile ~= nil and Onboarding.IsUnlocked(profile.Unlocks, key)
end

local V2_LOCK_HINTS: { [string]: string } = {
	Tower = "Place a rested hero in Squad",
	TowerFloor5 = "Clear Floor 4 first",
	Forge = "Clear Floor 1 first",
	Facilities = "Forge your first weapon",
	FortressTree = "Forge your first weapon",
	Pit = "Forge your first weapon",
}

function OnboardingService.LockedMessage(key: string, player: Player?): string
	local d = deps
	local profile = d and player and d.GetProfile(player)
	if profile and profile.Onboarding.Guide and profile.Onboarding.Guide.Enabled and V2_LOCK_HINTS[key] then
		return V2_LOCK_HINTS[key]
	end
	return LOCK_HINTS[key] or "Not unlocked yet"
end

-- Rejects with a toast when `key` is locked. Returns true when the action may proceed.
function OnboardingService.Require(player: Player, key: string): boolean
	if OnboardingService.IsUnlocked(player, key) then
		return true
	end
	local d = deps
	if d then
		d.SendToast(player, "Locked|" .. OnboardingService.LockedMessage(key, player), "WARN")
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
	local version = if guide.Enabled then "v3" else "legacy"
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
	HeroSummoned = "Summon", SquadDeployed = "Squad", ArtifactSummoned = "Roll", ArtifactUpgraded = "Upgrade",
	ArtifactEquipped = "Equip", TreeNodeUnlocked = "Tree", RelicBanked = "Bank", RaidEntered = "Raid",
}
local PIT_EVENTS: { [string]: string } = { SYNTHESIS = "Synthesis", PROMOTION = "Promotion" }
local WORKERS: { [string]: boolean } = { GuardPost = true, Market = true, TrainingGrounds = true, GodsBlessing = true }
-- Rewards are paid once per lesson. Lessons that replaced a step of the old quest chain share its
-- CompletedSteps key, so a reward paid under the old chain is not paid again.
local LEGACY_STEP: { [string]: string } = {
	Summon = "step_summon", Clear = "step_floor1", Upgrade = "step_forge", GuardPost = "step_facilities",
	Synthesis = "step_pit", Tree = "step_tree",
}

function OnboardingService.Report(player: Player, eventName: string, detail: (string | number)?)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return end
	OnboardingService.EnsureState(profile)
	local guide = profile.Onboarding.Guide
	local completed: any
	local completedTitle: string?
	local reward: { Gold: number?, Gems: number? }? = nil
	local id = GUIDE_EVENTS[eventName]
	if eventName == "FloorCleared" and detail == 1 then id = "Clear" end
	if eventName == "FloorVisited" and detail == 1 then id = "Visit" end
	if eventName == "TowerReturned" and guide.Facts.Clear then id = "Return" end
	if eventName == "PitUsed" and type(detail) == "string" then id = PIT_EVENTS[detail] end
	if eventName == "FacilityAssigned" and type(detail) == "string" and WORKERS[detail] then id = detail end
	local first = id ~= nil and mark(player, guide.Facts, id, if guide.Enabled then "v3" else "legacy")
	if guide.Enabled then
		if not id or not first then
			OnboardingService.Push(player)
			return
		end
		local lesson = (GuideConfig :: any)[id]
		local key = LEGACY_STEP[id] or ("guide_" .. id)
		if lesson and lesson.Reward and not profile.Onboarding.CompletedSteps[key] then
			profile.Onboarding.CompletedSteps[key] = true
			completed, completedTitle = lesson, lesson.Title
			reward = table.clone(lesson.Reward)
			if id == "Clear" then
				-- The next lesson is a Forge roll: make sure the Gold for one is there.
				local short = ArtifactCatalog.Banner.Cost1X - (profile.Currencies.Gold or 0)
				reward.Gold = math.max(reward.Gold or 0, short)
			end
		end
		-- A finished lesson can open the next system.
		Onboarding.UpdateAccess(profile, Onboarding.HasReadySquad(profile, os.time()), guide.Facts)
		if not completed then
			OnboardingService.Push(player)
			d.SyncProfile(player)
			return
		end
	else
		if eventName == "FloorCleared" and detail ~= 1 then return end
		completed = Onboarding.Report(profile.Onboarding, profile.Unlocks, eventName)
		if completed then
			telemetry(player, "GuideCompleted", completed.Id, "legacy")
			reward = completed.Reward
		end
	end
	if not completed then return end
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
	local detailLine = if #parts > 0 then "|" .. table.concat(parts, " · ") else ""
	d.SendToast(player, (completedTitle or completed.Title) .. detailLine, "SUCCESS")
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
	for _, lesson in GuideConfig.Ordered do profile.Onboarding.Guide.Facts[lesson.Id] = true end
	profile.Unlocks.Facilities, profile.Unlocks.FortressTree, profile.Unlocks.Pit = true, true, true
	OnboardingService.Push(player)
end

return OnboardingService
