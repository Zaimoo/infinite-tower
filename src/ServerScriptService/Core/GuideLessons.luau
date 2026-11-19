--!strict
-- Selects the one lesson to show, from the player's committed progress and what they can do now.
-- Order of business (GDD §4.7):
--   1. a carried relic (bank it);
--   2. the core chain of the player's arm (GuideConfig.Chains), strictly in order. A step whose
--      action is not possible yet is passed over (never shown as a dead end) and comes back when
--      it is;
--   3. conditional lessons: promotion, raid, weapon upgrade, the other facilities.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.GuideConfig)
local HeroCatalog = require(Shared.Config.HeroCatalog)
local ArtifactCatalog = require(Shared.Config.ArtifactCatalog)
local TreeConfig = require(Shared.Config.FortressTreeConfig)
local Balance = require(Shared.Config.StatBalance)
local FortressTree = require(Shared.Util.FortressTree)
local Stats = require(Shared.Util.StatFormulas)
local Capacity = require(Shared.Util.InventoryCapacity)

export type Lesson = Config.Lesson
export type Context = {
	Floor: number,
	Carrying: boolean,
	TravelSealed: boolean?,
	Ready: boolean,
	CanRaid: boolean,
	Chain: string?, -- "v3" (control), "v4" or "v5" (v4 with the Rival lesson); nil means v3
	OwnRelic: boolean?, -- a relic this player owns lies on their floor, waiting to be carried
	RivalRelic: boolean?, -- the Rival lesson's relic lies on this player's floor (RivalLesson)
	RivalActive: boolean?, -- the Rival is coming for its relic, or duelling for it
	Now: number,
	PitLesson: (any, boolean, boolean) -> string?,
}

local GuideLessons = {}

-- A lesson with its text or target adjusted for the moment.
local function with(lesson: Lesson, changes: { [string]: any }): Lesson
	local copy: any = table.clone(lesson)
	for key, value in changes do copy[key] = value end
	return copy
end

local function inSquad(hero: any): boolean
	return string.match(hero.Assignment or "", "^SQUAD_SLOT_%d+$") ~= nil
end

local function upgradeCandidate(profile: any): string?
	local usable, equipped = {}, {}
	for _, hero in profile.Heroes do
		if hero.EquippedArtifactUUID then equipped[hero.EquippedArtifactUUID] = true end
	end
	local best: string? = nil
	local lowestCost = math.huge
	for uuid, artifact in profile.Artifacts do
		if not artifact.Locked and not artifact.EquippedHeroUUID and not equipped[uuid] then
			local key = `{artifact.Rarity}:{artifact.Star}`
			usable[key] = (usable[key] or 0) + 1
		end
	end
	for uuid, artifact in profile.Artifacts do
		local rule = Balance.WeaponPromotionCost(artifact.Star, artifact.Rarity)
		if rule and profile.Currencies.Gold >= rule.Gold and profile.Currencies.Gems >= rule.Gems then
			local key = `{artifact.Rarity}:{artifact.Star}`
			local selfCount = if artifact.Locked or artifact.EquippedHeroUUID or equipped[uuid] then 0 else 1
			if (usable[key] or 0) - selfCount >= rule.Donors
				and (rule.Gold < lowestCost or (rule.Gold == lowestCost and (best == nil or uuid < best))) then
				best, lowestCost = uuid, rule.Gold
			end
		end
	end
	return best
end

-- A squad hero with no weapon, and a spare weapon it can hold.
local function canEquip(profile: any, now: number): boolean
	for _, hero in profile.Heroes do
		if hero.EquippedArtifactUUID or not inSquad(hero) or (hero.ComaUntilTimestamp or 0) > now then continue end
		for _, artifact in profile.Artifacts do
			if not artifact.EquippedHeroUUID and ArtifactCatalog.CanHeroEquip(hero.Archetype, artifact.Type) then return true end
		end
	end
	return false
end

local function canSummon(profile: any): boolean
	return (profile.Currencies.Gems or 0) >= HeroCatalog.PermanentBanner.Cost1X
		and Capacity.HeroCount(profile) < Capacity.HeroCap(profile.FortressTree)
end

local function canSummonLimited(profile: any): boolean
	return (profile.Currencies.Gems or 0) >= HeroCatalog.LimitedBanner.Cost1X
		and Capacity.HeroCount(profile) < Capacity.HeroCap(profile.FortressTree)
end

local function canRoll(profile: any): boolean
	return (profile.Currencies.Gold or 0) >= ArtifactCatalog.Banner.Cost1X
		and Capacity.ArtifactCount(profile) < Capacity.ArtifactCap(profile.FortressTree)
end

-- A hero on the bench and fit to work or fight.
local function spareHero(profile: any, now: number): boolean
	for _, hero in profile.Heroes do
		if hero.Assignment == "BENCHED" and (hero.ComaUntilTimestamp or 0) <= now then return true end
	end
	return false
end

local function staffable(profile: any, lesson: Lesson): boolean
	local facility = profile.Facilities and profile.Facilities[lesson.Id]
	if not facility or facility.Level <= 0 or #facility.AssignedHeroUUIDs > 0 then return false end
	return Stats.GetFacilityMaxWorkers(lesson.Id, facility.Level, FortressTree.PerkBonuses(profile.FortressTree)) > 0
end

local function buildableNode(profile: any): any
	for _, node in TreeConfig.Nodes do
		if FortressTree.CanUnlock(profile.FortressTree, node.Id, profile.Currencies.Gold, profile.HighestClearedFloor or 0, profile.Unlocks) then
			return node
		end
	end
	return nil
end

local OTHER_FACILITIES = { Config.Market, Config.TrainingGrounds, Config.GodsBlessing }

local function selectLesson(profile: any, context: Context): Lesson?
	local guide = profile.Onboarding.Guide
	local facts = guide.Facts
	local unlocks = profile.Unlocks or {}
	local now = context.Now
	local atHub = context.Floor == 0
	local v4 = context.Chain == "v4" or context.Chain == "v5" -- v5 is v4 plus the Rival lesson
	local rival = context.Chain == "v5"
	local function open(lesson: Lesson): boolean
		return not facts[lesson.Id]
	end
	-- Conditional lessons can be put off; the core chain cannot.
	local function available(lesson: Lesson): boolean
		return open(lesson) and (guide.Snoozed[lesson.Id] or 0) <= now
	end

	-- v5: the relic won from the Rival goes home too.
	if context.Carrying and rival and facts.Duel and not context.RivalActive and available(Config.Haul) then
		if context.TravelSealed then
			return with(Config.Haul, { Description = "Bank it on this floor." })
		end
		return Config.Haul
	end
	-- Bank is a core step in v4, so Later does not put it off there.
	if context.Carrying and (if v4 then open(Config.Bank) else available(Config.Bank)) then
		if context.TravelSealed then
			return with(Config.Bank, { Description = "Travel is sealed. Bank it on this floor." })
		end
		return Config.Bank
	end

	-- Core chain ---------------------------------------------------------------------------------
	if atHub and open(Config.Summon) and canSummon(profile) then return Config.Summon end
	-- v4: step 1's Gems pay for one pull on A Star's Arrival, the banner worth saving for.
	if v4 and atHub and facts.Summon and open(Config.Limited) and canSummonLimited(profile) then return Config.Limited end
	if atHub and open(Config.Squad) and open(Config.Clear) and spareHero(profile, now) then return Config.Squad end
	-- No hero fit to fight: only nudge once before the squad tutorial / Floor 1 is done (and allow
	-- Later to dismiss it). Afterward, pause pre-Floor-1 Tower cues until a hero is placed rather
	-- than repeating "Ready your squad" whenever the player empties their squad or wipes.
	if not context.Ready then
		if atHub and open(Config.Squad) and open(Config.Clear) and available(Config.Ready) then
			return Config.Ready
		end
		if open(Config.Clear) then
			return nil
		end
	end
	if open(Config.Clear) then
		if context.Floor == 1 then return Config.Clear end
		return if atHub then Config.Visit else nil
	end
	-- v4: the first relic is a core step. Carrying it is handled above; here it still lies on the
	-- floor (sealed for a few seconds). With no relic to carry the step is passed over.
	if v4 and facts.Clear and open(Config.Bank) and context.Floor > 0 and context.OwnRelic then
		return with(Config.Bank, { Description = "Pick up your relic, then carry it to a sanctuary." })
	end
	-- v5: the Rival Master lesson. Its relic appears on the player's first Floor 2-4 visit after
	-- the first clear; until then, on Floor 1, point the way up (put off with Later).
	if rival and facts.Clear then
		if open(Config.Steal) then
			if context.RivalRelic then return Config.Steal end
			if context.Floor == 1 and context.Ready and not context.Carrying and available(Config.Climb) then return Config.Climb end
		elseif open(Config.Duel) and context.RivalActive then
			return Config.Duel
		end
	end
	if open(Config.Return) and context.Floor > 0 and context.Floor <= 50 then return Config.Return end
	if not atHub then return nil end

	if open(Config.Roll) and canRoll(profile) then return Config.Roll end
	if open(Config.Equip) and canEquip(profile, now) then return Config.Equip end
	if open(Config.GuardPost) and unlocks.Facilities and staffable(profile, Config.GuardPost) then
		if spareHero(profile, now) then return Config.GuardPost end
		if canSummon(profile) then return Config.Recruit end
	end
	if open(Config.Tree) and unlocks.FortressTree then
		local node = buildableNode(profile)
		if node then
			return with(Config.Tree, { Control = node.Id, Description = `Build {node.Name}.` })
		end
	end
	local pit: string? = nil
	if unlocks.Pit then
		pit = context.PitLesson(profile, available(Config.Promotion), open(Config.Synthesis))
		if pit == "Synthesis" then return Config.Synthesis end
		-- Nothing to feed: a spare hero makes the lesson possible.
		if pit == nil and open(Config.Synthesis) and not spareHero(profile, now) and canSummon(profile) then return Config.Recruit end
	end

	-- Conditional --------------------------------------------------------------------------------
	if pit == "Promotion" and available(Config.Promotion) then return Config.Promotion end
	if facts.Clear and context.Ready and context.CanRaid and available(Config.Raid) then return Config.Raid end
	if unlocks.Forge and available(Config.Upgrade) then
		local artifact = upgradeCandidate(profile)
		if artifact then
			return with(Config.Upgrade, { Control = artifact, Description = `Upgrade {profile.Artifacts[artifact].DisplayName}.` })
		end
	end
	if unlocks.Facilities and spareHero(profile, now) then
		for _, lesson in OTHER_FACILITIES do
			if available(lesson) and staffable(profile, lesson) then return lesson end
		end
	end
	return nil
end

-- The lesson to show, marked with its place in the player's chain (Core, Index, Total).
function GuideLessons.Select(profile: any, context: Context): Lesson?
	local lesson = selectLesson(profile, context)
	if not lesson then return nil end
	local chainId = context.Chain or "v3"
	local index, total = Config.Position(chainId, lesson.Id)
	local marked: any = with(lesson, { Core = index ~= nil, Total = total })
	marked.Index = index
	marked.Reward = Config.RewardFor(chainId, lesson.Id) -- a chain can move a lesson's reward
	return marked
end

-- The weapon type a first Forge roll should produce: one a squad hero can hold (a hero with no
-- weapon first), so the "Equip the weapon" step that follows always has something to equip.
function GuideLessons.StarterWeaponType(profile: any): string?
	local fallback: string? = nil
	local slots: { { Slot: number, Hero: any } } = {}
	for _, hero in profile.Heroes do
		local slot = tonumber(string.match(hero.Assignment or "", "^SQUAD_SLOT_(%d+)$"))
		if slot then table.insert(slots, { Slot = slot, Hero = hero }) end
	end
	table.sort(slots, function(a, b) return a.Slot < b.Slot end)
	for _, entry in slots do
		local allowed = ArtifactCatalog.ArchetypeRestrictions[entry.Hero.Archetype]
		local weaponType = allowed and allowed[1]
		if weaponType then
			if not entry.Hero.EquippedArtifactUUID then return weaponType end
			fallback = fallback or weaponType
		end
	end
	return fallback
end

return GuideLessons
