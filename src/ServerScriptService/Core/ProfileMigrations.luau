--!strict
-- ServerScriptService/Core/ProfileMigrations.luau
-- Lazy save migrations run by DataManager when a profile loads. Never assume an old profile has the
-- new shape: every field is created or derived here before gameplay code reads it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroCatalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)
local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)
local Onboarding = require(ReplicatedStorage.Shared.Util.Onboarding)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)

local ProfileMigrations = {}

ProfileMigrations.CurrentSchema = 7

-- Rarity a template had when these old saves were written, where it differs from today's catalog.
-- Han was the Common starter before he became Mythical; Valeria was Superior before moving to Exalted.
local LEGACY_RARITY: { [string]: number } = { hero_han = 1, hero_valeria = 4 }

local function legacyRarity(templateId: string?): number
	return (templateId and LEGACY_RARITY[templateId]) or HeroCatalog.RarityOf(templateId)
end

local function blankFacility(level: number): any
	return {
		Level = level,
		AssignedHeroUUIDs = {},
	}
end
ProfileMigrations.BlankFacility = blankFacility

-- v3 (Phase 4): onboarding and unlocks, Fortress Tree from bought facility levels, God's Blessing,
-- and the inherent rarity of every owned hero. Stars and levels are untouched.
function ProfileMigrations.ToV3(profile: any)
	if (profile.SchemaVersion or 1) >= 3 then return end
	Onboarding.MigrateUnlocks(profile)
	profile.Facilities = profile.Facilities or {}
	-- Saves from before squad slots were locked keep every slot a hero already stands in.
	local highestSlot = 1
	for _, hero in pairs(profile.Heroes or {}) do
		local slot = tonumber(string.match(hero.Assignment or "", "^SQUAD_SLOT_(%d+)$"))
		if slot then highestSlot = math.max(highestSlot, slot) end
	end
	profile.FortressTree = FortressTree.NodesFromFacilityLevels(profile.Facilities, highestSlot)
	profile.Facilities.GodsBlessing = profile.Facilities.GodsBlessing or blankFacility(0)
	for _, hero in pairs(profile.Heroes or {}) do
		hero.Rarity = legacyRarity(hero.TemplateId)
	end
	profile.SchemaVersion = 3
end

-- v4: every hero is summoned at 1★ and its rarity carries the power its old summon star gave. Owned heroes drop
-- the stars they got for free at summon (Rarity - 1) and keep any promotions bought on top. Levels above the new
-- cap (Stars x 10) are clamped, and the XP toward the next level is cleared.
function ProfileMigrations.ToV4(profile: any)
	if (profile.SchemaVersion or 1) >= 4 then return end
	for _, hero in pairs(profile.Heroes or {}) do
		local rarity = hero.Rarity or legacyRarity(hero.TemplateId)
		hero.Rarity = rarity
		local stars = if type(hero.Stars) == "number" then math.floor(hero.Stars) else 1
		hero.Stars = math.max(1, stars - (rarity - 1))
		local cap = hero.Stars * 10
		if type(hero.Level) ~= "number" or hero.Level > cap then
			hero.Level = math.min(type(hero.Level) == "number" and hero.Level or 1, cap)
			hero.XP = 0
		end
	end
	profile.SchemaVersion = 4
end

-- v5: levels are per star (Lv 1-10 each), promotion resets to Lv 1. Convert the old absolute level to the level
-- within the current star; a level below this star's floor becomes Lv 1 (stats only rise), above 10 becomes Lv 10.
function ProfileMigrations.ToV5(profile: any)
	if (profile.SchemaVersion or 1) >= 5 then return end
	for _, hero in pairs(profile.Heroes or {}) do
		local stars = if type(hero.Stars) == "number" then math.max(1, math.floor(hero.Stars)) else 1
		local old = if type(hero.Level) == "number" then math.floor(hero.Level) else 1
		local level = math.clamp(old - (stars - 1) * 10, 1, 10)
		if level ~= old - (stars - 1) * 10 then hero.XP = 0 end
		hero.Level = level
	end
	profile.SchemaVersion = 5
end

-- Facility fields from removed systems: the manual claim chest and the plot rune espionage (Bless / Leech / Purge).
local LEGACY_FACILITY_FIELDS = { "UncollectedOutput", "BlessedUntil", "LeechedUntil", "LeechVisitorUserId", "LastRuneTimestamp", "LastRuneWasLeech" }

-- What an Imprint Catalyst cost to craft, refunded for any still held when imprints were removed.
local CATALYST_REFUND = { Gold = 150, Gems = 15, SoulEssence = 4 }

-- v7: drop the removed social systems (pacts, mercenaries, mimic chests, rune espionage) and their facility fields,
-- the removed Pit imprints (hero memories, imprint slots, Imprint Catalysts, refunded at their crafting cost) and the
-- display-only passive trait name each hero carried.
function ProfileMigrations.ToV7(profile: any)
	if (profile.SchemaVersion or 1) >= 7 then return end
	profile.Social = nil
	for _, facility in pairs(profile.Facilities or {}) do
		if type(facility) == "table" then
			for _, key in ipairs(LEGACY_FACILITY_FIELDS) do facility[key] = nil end
		end
	end
	for _, hero in pairs(profile.Heroes or {}) do
		hero.InheritedImprints = nil
		hero.PassiveTrait = nil
		hero.ImprintCapacity = nil
		if type(hero.SynthesisHistory) == "table" then hero.SynthesisHistory.ImprintsPerformed = nil end
	end
	local materials = profile.PitMaterials
	if type(materials) == "table" then
		local catalysts = materials.ImprintCatalyst
		if type(catalysts) == "number" and catalysts == catalysts and catalysts > 0 and catalysts < math.huge then
			catalysts = math.floor(catalysts)
			profile.Currencies = profile.Currencies or {}
			profile.Currencies.Gold = (profile.Currencies.Gold or 0) + catalysts * CATALYST_REFUND.Gold
			profile.Currencies.Gems = (profile.Currencies.Gems or 0) + catalysts * CATALYST_REFUND.Gems
			materials.SoulEssence = (tonumber(materials.SoulEssence) or 0) + catalysts * CATALYST_REFUND.SoulEssence
		end
		materials.ImprintCatalyst = nil
	end
	profile.SchemaVersion = 7
end

function ProfileMigrations.Run(profile: any)
	ProfileMigrations.ToV3(profile)
	ProfileMigrations.ToV4(profile)
	ProfileMigrations.ToV5(profile)
	if profile.SchemaVersion < 6 then
		profile.Onboarding = profile.Onboarding or Onboarding.NewState()
		Onboarding.EnsureGuide(profile.Onboarding)
		profile.SchemaVersion = 6
	end
	ProfileMigrations.ToV7(profile)
	profile.Settings = SettingsConfig.Sanitize(profile.Settings)
end

return ProfileMigrations
