--!strict
-- Part 1/4 enemy catalog. Native procedural rigs and clips are authored locally in
-- ReplicatedStorage.Assets.TowerEnemyRigs and ReplicatedStorage.Assets.TowerEnemyClips.
-- No uploaded Roblox asset or animation IDs are claimed (AssetId / AnimationId remain nil).
local Catalog: any = { Status = "LOCAL_AUTHORED_UNVERIFIED", SchemaVersion = 2, Biomes = {}, Entries = {} }

local function missing(): any
	return { Status = "MISSING" }
end

local function authoredClip(slot: string): any
	return {
		Status = "LOCAL_AUTHORED_UNVERIFIED",
		SourceModule = "ReplicatedStorage.Assets.TowerEnemyClips",
		Slot = slot,
	}
end

local function authoredEffects(): any
	return {
		Status = "LOCAL_AUTHORED_UNVERIFIED",
		SourceModule = "ReplicatedStorage.Assets.EnemyAnimationController",
	}
end

local function attack(id: string, animation: string, kind: string, windup: number, recovery: number, travel: number?): any
	local flight = travel or 0
	return {
		Id = id,
		Status = "LOCAL_AUTHORED_UNVERIFIED",
		AnimationKey = animation,
		Kind = kind,
		Windup = windup,
		ReleaseTime = windup,
		ImpactTime = windup + flight,
		TravelDuration = flight,
		Recovery = recovery,
		Duration = windup + flight + recovery,
		Phases = { "WINDUP", "IMPACT", "RECOVERY" },
		-- Server owns targeting, warning geometry, range, damage and hit deduplication.
		ImpactRule = if kind == "PROJECTILE" then "SERVER_SWEPT_PROJECTILE_SAME_FLOOR_ONCE"
			elseif kind == "GROUND_AREA" then "SERVER_TELEGRAPH_AREA_SAME_FLOOR_ONCE"
			else "SERVER_RANGE_AND_ARC_SAME_FLOOR_ONCE",
		Gameplay = {
			Status = "LOCAL_AUTHORED_UNVERIFIED",
			SourceModule = "ReplicatedStorage.Shared.Config.FirstBiomeCombat",
			RequiredFields = { "RangeAndShape", "TargetRule", "DamageRule", "TelegraphGeometry", "ProjectileSpeedAndCollisionIfRanged" },
		},
		CancelOnDeath = true,
		CancelOnContextChange = true,
		Effects = authoredEffects(),
		Audio = missing(),
	}
end

local function enemy(biome: string, role: string, id: string, name: string, family: string, anatomy: string,
	width: number, height: number, depth: number, basicKind: string, specialKind: string?): any
	local animations: any = {}
	for _, key in { "Idle", "Locomotion", "BasicAttack", "HitReaction", "Death" } do
		animations[key] = authoredClip(key)
	end
	local attacks = { attack(id .. "_basic", "BasicAttack", basicKind, .6, .8, if basicKind == "PROJECTILE" then .4 else nil) }
	if role == "ELITE" then
		animations.Special = authoredClip("Special")
		table.insert(attacks, attack(id .. "_special", "Special", specialKind or "GROUND_AREA", 1.2, 1.0))
	elseif role == "BOSS" then
		animations.Awakening = authoredClip("Awakening")
		animations.Signature1 = authoredClip("Signature1")
		animations.Signature2 = authoredClip("Signature2")
		table.insert(attacks, attack(id .. "_signature_1", "Signature1", specialKind or "GROUND_AREA", 1.8, 1.2))
		table.insert(attacks, attack(id .. "_signature_2", "Signature2", "GROUND_AREA", 2.2, 1.5))
	end
	local entry = {
		Id = id,
		BiomeId = biome,
		Role = role,
		DisplayName = name,
		Status = "LOCAL_AUTHORED_UNVERIFIED",
		Model = {
			Status = "LOCAL_AUTHORED_UNVERIFIED",
			SourceModule = "ReplicatedStorage.Assets.TowerEnemyRigs",
			PlannedTemplatePath = "ReplicatedStorage.Assets.TowerEnemies." .. id,
		},
		Rig = {
			Status = "LOCAL_AUTHORED_UNVERIFIED",
			ProposedFamily = family,
			Pivot = { Status = "LOCAL_AUTHORED_UNVERIFIED", Mode = "HumanoidRootPart" },
			FloorContact = { Status = "LOCAL_AUTHORED_UNVERIFIED", Mode = "Planted" },
		},
		Anatomy = {
			Status = "LOCAL_AUTHORED_UNVERIFIED",
			Description = anatomy,
			LocomotionMode = if family == "SERPENT" then "SLITHER" elseif family == "GIANT_AVIAN" or family == "AVIAN" then "WALK_WING_ASSISTED"
				elseif family == "CRAWLER" or family == "INSECT" or family == "SCORPION" or family == "CRUSTACEAN" then "CRAWL" else "WALK",
		},
		Bounds = { Status = "LOCAL_AUTHORED_UNVERIFIED", Width = width, Height = height, Depth = depth },
		Source = {
			Status = "LOCAL_AUTHORED_UNVERIFIED",
			NativeRigModule = "src/ReplicatedStorage/Assets/TowerEnemyRigs.luau",
			NativeClipModule = "src/ReplicatedStorage/Assets/TowerEnemyClips.luau",
			PlannedDirectory = "assets-source/tower/enemies/" .. id,
			PlannedModelSourcePath = "assets-source/tower/enemies/" .. id .. "/model.blend",
			PlannedAnimationSourcePath = "assets-source/tower/enemies/" .. id .. "/animations.blend",
		},
		Animations = animations,
		Attacks = attacks,
		Effects = authoredEffects(),
		Audio = missing(),
	}
	Catalog.Entries[id] = entry
	return entry
end

local function biome(id: string, name: string, regular1: any, regular2: any, elite: any, boss: any)
	table.insert(Catalog.Biomes, {
		Id = id,
		DisplayName = name,
		Status = "LOCAL_AUTHORED_UNVERIFIED",
		RegularEnemyIds = { regular1.Id, regular2.Id },
		EliteEnemyId = elite.Id,
		BossEnemyId = boss.Id,
	})
end

biome("verdant_ruins", "Verdant Ruins",
	enemy("verdant_ruins", "REGULAR", "mob_moss_crawler", "Moss Crawler", "CRAWLER", "Low six-legged crawler; mandible bite and lunge", 5, 3, 7, "BITE"),
	enemy("verdant_ruins", "REGULAR", "mob_ruin_guardian", "Ruin Guardian", "ARMORED_BIPED", "Stone biped with articulated arms; heavy strike", 5, 7, 4, "WEAPON_ARC"),
	enemy("verdant_ruins", "ELITE", "elite_vinebound", "Vinebound Elite", "ROOTED_BIPED", "Vine-bound biped with branch arms; root cast", 6, 8, 5, "WEAPON_ARC", "GROUND_AREA"),
	enemy("verdant_ruins", "BOSS", "boss_mossbound_guardian", "Mossbound Guardian", "STONE_COLOSSUS", "Broad stone colossus; slam and sweeping roots", 13, 17, 10, "SLAM", "GROUND_AREA"))

biome("fungal_hollow", "Fungal Hollow",
	enemy("fungal_hollow", "REGULAR", "mob_spore_skitter", "Spore Skitter", "CRAWLER", "Four-legged fungal crawler; cap and mandibles", 5, 3, 6, "BITE"),
	enemy("fungal_hollow", "REGULAR", "mob_lantern_spore", "Lantern Spore", "FUNGAL_BIPED", "Mobile stalk creature with articulated casting tendrils", 4, 6, 4, "PROJECTILE"),
	enemy("fungal_hollow", "ELITE", "elite_mycelial_brute", "Mycelial Brute", "HEAVY_BIPED", "Heavy mushroom biped with club-like forearms", 7, 9, 6, "WEAPON_ARC", "GROUND_AREA"),
	enemy("fungal_hollow", "BOSS", "boss_spore_matriarch", "Spore Matriarch", "FUNGAL_COLOSSUS", "Multi-limbed fungal matriarch with expanding spore crown", 15, 16, 13, "SLAM", "GROUND_AREA"))

biome("ashen_dunes", "Ashen Dunes",
	enemy("ashen_dunes", "REGULAR", "mob_dune_scarab", "Dune Scarab", "INSECT", "Six-legged scarab with biting head and shell", 5, 3, 7, "BITE"),
	enemy("ashen_dunes", "REGULAR", "mob_ash_raider", "Ash Raider", "WEAPON_BIPED", "Cloth-wrapped biped with curved blade", 4, 7, 4, "WEAPON_ARC"),
	enemy("ashen_dunes", "ELITE", "elite_glass_scorpion", "Glass Scorpion", "SCORPION", "Eight-legged scorpion with pincers and segmented tail", 9, 6, 11, "CLAW", "GROUND_AREA"),
	enemy("ashen_dunes", "BOSS", "boss_sandstone_colossus", "Sandstone Colossus", "STONE_COLOSSUS", "Massive stone biped with jointed slab arms", 15, 20, 12, "SLAM", "GROUND_AREA"))

biome("frozen_citadel", "Frozen Citadel",
	enemy("frozen_citadel", "REGULAR", "mob_frost_hound", "Frost Hound", "QUADRUPED", "Four-legged ice hound with articulated jaw", 4, 5, 8, "BITE"),
	enemy("frozen_citadel", "REGULAR", "mob_rime_sentry", "Rime Sentry", "WEAPON_BIPED", "Armored biped carrying an ice spear", 4, 7, 4, "WEAPON_ARC"),
	enemy("frozen_citadel", "ELITE", "elite_glacier_knight", "Glacier Knight", "ARMORED_BIPED", "Heavy biped with shield and broad ice blade", 7, 10, 6, "WEAPON_ARC", "GROUND_AREA"),
	enemy("frozen_citadel", "BOSS", "boss_frostbound_king", "Frostbound King", "ROYAL_BIPED", "Tall armored monarch with greatsword and articulated cloak", 11, 17, 9, "WEAPON_ARC", "GROUND_AREA"))

biome("infernal_foundry", "Infernal Foundry",
	enemy("infernal_foundry", "REGULAR", "mob_cinder_imp", "Cinder Imp", "SMALL_BIPED", "Small horned biped with clawed hands", 4, 4, 4, "CLAW"),
	enemy("infernal_foundry", "REGULAR", "mob_forge_construct", "Forge Construct", "ARMORED_BIPED", "Mechanical biped with jointed hammer arm", 5, 8, 5, "WEAPON_ARC"),
	enemy("infernal_foundry", "ELITE", "elite_molten_taskmaster", "Molten Taskmaster", "HEAVY_BIPED", "Armored biped wielding a long foundry chain", 7, 11, 6, "WEAPON_ARC", "GROUND_AREA"),
	enemy("infernal_foundry", "BOSS", "boss_ember_titan", "Ember Titan", "FORGE_COLOSSUS", "Massive furnace-bodied biped with articulated fists", 16, 21, 13, "SLAM", "GROUND_AREA"))

biome("thunder_highlands", "Thunder Highlands",
	enemy("thunder_highlands", "REGULAR", "mob_storm_talon", "Storm Talon", "AVIAN", "Two-legged raptor with wing-assisted running", 5, 6, 7, "CLAW"),
	enemy("thunder_highlands", "REGULAR", "mob_crag_channeler", "Crag Channeler", "CASTER_BIPED", "Horned biped with storm-channeling staff", 4, 7, 4, "PROJECTILE"),
	enemy("thunder_highlands", "ELITE", "elite_thunder_ram", "Thunder Ram", "QUADRUPED", "Heavy four-legged ram with articulated head and horns", 7, 7, 10, "RAM", "GROUND_AREA"),
	enemy("thunder_highlands", "BOSS", "boss_storm_roc", "Storm Roc", "GIANT_AVIAN", "Giant two-legged bird; jointed wings, neck and talons", 24, 16, 17, "CLAW", "GROUND_AREA"))

biome("corrupted_grove", "Corrupted Grove",
	enemy("corrupted_grove", "REGULAR", "mob_blight_wolf", "Blight Wolf", "QUADRUPED", "Four-legged wolf with thorned spine and jaw", 4, 5, 8, "BITE"),
	enemy("corrupted_grove", "REGULAR", "mob_thorn_weaver", "Thorn Weaver", "ROOTED_BIPED", "Branch-bodied caster with jointed tendrils", 5, 7, 5, "PROJECTILE"),
	enemy("corrupted_grove", "ELITE", "elite_rotwood_keeper", "Rotwood Keeper", "TREANT", "Heavy walking tree with articulated root legs and branch arms", 9, 12, 8, "SLAM", "GROUND_AREA"),
	enemy("corrupted_grove", "BOSS", "boss_blight_sovereign", "Blight Sovereign", "GROVE_COLOSSUS", "Crowned tree colossus with root limbs and grasping branches", 17, 22, 15, "SLAM", "GROUND_AREA"))

biome("sunken_sanctuary", "Sunken Sanctuary",
	enemy("sunken_sanctuary", "REGULAR", "mob_tide_claw", "Tide Claw", "CRUSTACEAN", "Six-legged armored crustacean with two pincers", 6, 4, 7, "CLAW"),
	enemy("sunken_sanctuary", "REGULAR", "mob_drowned_acolyte", "Drowned Acolyte", "CASTER_BIPED", "Robed amphibious biped carrying a ritual staff", 4, 7, 4, "PROJECTILE"),
	enemy("sunken_sanctuary", "ELITE", "elite_coral_warden", "Coral Warden", "ARMORED_BIPED", "Coral-armored biped with shield and hooked weapon", 7, 10, 6, "WEAPON_ARC", "GROUND_AREA"),
	enemy("sunken_sanctuary", "BOSS", "boss_tidal_leviathan", "Tidal Leviathan", "SERPENT", "Long articulated body and fins; slither locomotion", 12, 13, 24, "BITE", "GROUND_AREA"))

biome("astral_archives", "Astral Archives",
	enemy("astral_archives", "REGULAR", "mob_rune_mite", "Rune Mite", "CRAWLER", "Low articulated crawler with floating rune shell", 5, 3, 6, "BITE"),
	enemy("astral_archives", "REGULAR", "mob_astral_scribe", "Astral Scribe", "CASTER_BIPED", "Robed biped with articulated book and casting hands", 4, 7, 4, "PROJECTILE"),
	enemy("astral_archives", "ELITE", "elite_archive_executor", "Archive Executor", "ARMORED_BIPED", "Tall armored biped with segmented glaive", 7, 11, 6, "WEAPON_ARC", "GROUND_AREA"),
	enemy("astral_archives", "BOSS", "boss_archive_rift_warden", "Rift Warden", "ARCANE_COLOSSUS", "New articulated arcane guardian; legacy static mesh is unapproved", 13, 18, 11, "WEAPON_ARC", "GROUND_AREA"))

biome("abyssal_throne", "Abyssal Throne",
	enemy("abyssal_throne", "REGULAR", "mob_abyss_reaver", "Abyss Reaver", "WEAPON_BIPED", "Armored biped with hooked dual blades", 5, 8, 5, "WEAPON_ARC"),
	enemy("abyssal_throne", "REGULAR", "mob_void_invoker", "Void Invoker", "CASTER_BIPED", "Robed biped with articulated void-channeling arms", 5, 8, 5, "PROJECTILE"),
	enemy("abyssal_throne", "ELITE", "elite_throne_executioner", "Throne Executioner", "HEAVY_BIPED", "Heavy biped carrying an oversized execution axe", 8, 12, 7, "WEAPON_ARC", "GROUND_AREA"),
	enemy("abyssal_throne", "BOSS", "boss_crimson_overlord", "Crimson Overlord", "ROYAL_COLOSSUS", "Crowned armored colossus with sword and articulated mantle", 15, 22, 13, "WEAPON_ARC", "GROUND_AREA"))

function Catalog.Get(id: string): any
	return Catalog.Entries[id]
end

local function freeze(value: any): any
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

return freeze(Catalog)
