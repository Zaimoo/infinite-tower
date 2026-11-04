--!strict
-- ServerScriptService/Core/ProfileMigrations.luau
-- Lazy save migrations run by DataManager when a profile loads. Never assume an old profile has the
-- new shape: every field is created or derived here before gameplay code reads it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroCatalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)
local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)
local Onboarding = require(ReplicatedStorage.Shared.Util.Onboarding)

local ProfileMigrations = {}

ProfileMigrations.CurrentSchema = 4

local function blankFacility(level: number): any
	return {
		Level = level,
		AssignedHeroUUIDs = {},
		UncollectedOutput = 0,
		BlessedUntil = 0,
		LeechedUntil = 0,
		LeechVisitorUserId = nil,
		LastRuneTimestamp = 0,
		LastRuneWasLeech = false,
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
		hero.Rarity = HeroCatalog.RarityOf(hero.TemplateId)
	end
	profile.SchemaVersion = 3
end

-- v4: every hero is summoned at 1★ and its rarity carries the power its old summon star gave. Owned heroes drop
-- the stars they got for free at summon (Rarity - 1) and keep any promotions bought on top. Levels above the new
-- cap (Stars x 10) are clamped, and the XP toward the next level is cleared.
function ProfileMigrations.ToV4(profile: any)
	if (profile.SchemaVersion or 1) >= 4 then return end
	for _, hero in pairs(profile.Heroes or {}) do
		local rarity = hero.Rarity or HeroCatalog.RarityOf(hero.TemplateId)
		hero.Rarity = rarity
		hero.BankedLevels = hero.BankedLevels or 0
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

function ProfileMigrations.Run(profile: any)
	ProfileMigrations.ToV3(profile)
	ProfileMigrations.ToV4(profile)
end

return ProfileMigrations
