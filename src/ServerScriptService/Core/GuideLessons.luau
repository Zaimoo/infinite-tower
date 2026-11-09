--!strict
-- Selects one lesson from the player's committed progress and currently available actions.
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
	Now: number,
	PitLesson: (any, boolean, boolean) -> string?,
}

local GuideLessons = {}

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
		local rule = Balance.WeaponPromotionCosts[artifact.Star]
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

local function canEquip(profile: any, now: number): boolean
	for _, hero in profile.Heroes do
		if hero.EquippedArtifactUUID or not string.match(hero.Assignment or "", "^SQUAD_SLOT_%d+$")
			or (hero.ComaUntilTimestamp or 0) > now then continue end
		for _, artifact in profile.Artifacts do
			if not artifact.EquippedHeroUUID and ArtifactCatalog.CanHeroEquip(hero.Archetype, artifact.Type) then return true end
		end
	end
	return false
end

local FACILITIES = { Config.GuardPost, Config.Market, Config.TrainingGrounds, Config.GodsBlessing }

function GuideLessons.Select(profile: any, context: Context): Lesson?
	local guide = profile.Onboarding.Guide
	local facts = guide.Facts
	local function available(lesson: Lesson): boolean
		return not facts[lesson.Id] and (guide.Snoozed[lesson.Id] or 0) <= context.Now
	end
	if context.Carrying and available(Config.Bank) then
		if context.TravelSealed then
			return { Id = Config.Bank.Id, Title = Config.Bank.Title, Target = Config.Bank.Target,
				Description = "Travel is sealed. Defeat the boss or bank at this floor’s sanctuary." }
		end
		return Config.Bank
	end
	if not facts.Clear then
		if not context.Ready and (guide.Snoozed.Ready or 0) <= context.Now then return Config.Ready end
		local core = if context.Floor == 1 then Config.Clear else Config.Visit
		if available(core) then return core end
	elseif not facts.Return and context.Floor > 0 and context.Floor <= 50 and available(Config.Return) then
		return Config.Return
	end
	if context.Floor ~= 0 then return nil end

	if facts.Clear and available(Config.Equip) and canEquip(profile, context.Now) then return Config.Equip end
	if profile.Unlocks.Facilities then
		local spare = false
		for _, hero in profile.Heroes do
			if hero.Assignment == "BENCHED" and (hero.ComaUntilTimestamp or 0) <= context.Now then spare = true; break end
		end
		if spare then
			local perks = FortressTree.PerkBonuses(profile.FortressTree)
			for _, lesson in FACILITIES do
				local facility = profile.Facilities[lesson.Id]
				if available(lesson) and facility and facility.Level > 0
					and #facility.AssignedHeroUUIDs == 0 and Stats.GetFacilityMaxWorkers(lesson.Id, facility.Level, perks) > 0 then
					return lesson
				end
			end
		end
	end
	if facts.Clear and context.CanRaid and available(Config.Raid) then return Config.Raid end
	if profile.Unlocks.Forge and available(Config.Upgrade) then
		local artifact = upgradeCandidate(profile)
		if artifact then
			return { Id = Config.Upgrade.Id, Title = Config.Upgrade.Title, Target = Config.Upgrade.Target,
				Control = artifact, Description = `Select {profile.Artifacts[artifact].DisplayName} at the Forge to preview its upgrade.` }
		end
	end
	if profile.Unlocks.FortressTree and available(Config.Tree) then
		for _, node in TreeConfig.Nodes do
			if FortressTree.CanUnlock(profile.FortressTree, node.Id, profile.Currencies.Gold, profile.HighestClearedFloor or 0, profile.Unlocks) then
				return { Id = Config.Tree.Id, Title = Config.Tree.Title, Target = Config.Tree.Target, Control = node.Id,
					Description = `Build {node.Name} for {node.Gold} Gold.` }
			end
		end
	end
	if profile.Unlocks.Pit then
		local pit = context.PitLesson(profile, available(Config.Promotion), available(Config.Synthesis))
		if pit == "Promotion" then return Config.Promotion end
		if pit == "Synthesis" then return Config.Synthesis end
	end
	if available(Config.Summon) and profile.Currencies.Gems >= HeroCatalog.PermanentBanner.Cost1X
		and Capacity.HeroCount(profile) < Capacity.HeroCap(profile.FortressTree) then
		return Config.Summon
	end
	return nil
end

return GuideLessons
