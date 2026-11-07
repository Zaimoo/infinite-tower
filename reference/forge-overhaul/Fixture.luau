--!strict
-- Synthetic data only. Nothing here reads or writes a player's profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

local function fixture()
	local snapshot: any = { Revision = 1, Gold = 115940, Gems = 600, Heroes = {}, Artifacts = {} }
	local function artifact(id: string, template: string, owner: string?, locked: boolean?, star: number?)
		local seed = Catalog.Seeds[template]
		snapshot.Artifacts[id] = { UUID = id, TemplateId = template, DisplayName = seed.DisplayName, Type = seed.Type, Rarity = seed.RarityTier, Star = star or 1, EquippedHeroUUID = owner, Locked = locked }
	end
	local function hero(id: string, template: string, name: string, archetype: string, weapon: string?)
		snapshot.Heroes[id] = { UUID = id, TemplateId = template, DisplayName = name, Archetype = archetype, Level = 1, Stars = 1, QualityScalar = 1, EquippedArtifactUUID = weapon }
	end

	hero("hero-jenna-0001", "hero_jenna", "Jenna", "Marksman", "bow-current")
	hero("hero-jenna-0002", "hero_jenna", "Jenna", "Marksman", "bow-protected")
	hero("hero-jenna-0003", "hero_jenna", "Jenna", "Marksman", nil)
	hero("hero-valeria-0004", "hero_valeria", "Valeria", "Healer", nil)
	artifact("bow-current", "art_reinforced_longbow", "hero-jenna-0001")
	artifact("bow-target", "art_crystal_greatbow")
	artifact("bow-material", "art_crystal_greatbow")
	artifact("bow-protected", "art_crystal_greatbow", "hero-jenna-0002")
	artifact("bow-locked", "art_crystal_greatbow", nil, true)
	artifact("sword-target", "art_runic_longsword")
	artifact("sword-material", "art_runic_longsword")
	artifact("sword-invested", "art_knightly_estoc", nil, false, 1)
	artifact("bow-max", "art_crystal_greatbow", nil, false, 7)
	return snapshot
end

return fixture
