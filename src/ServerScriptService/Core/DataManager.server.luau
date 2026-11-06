--!strict
-- ServerScriptService/Core/DataManager.server.luau
-- Authoritative Player Profile Schema, Session Locking, Gacha, Synthesis, Promotion & Tycoon Actions

print("[DataManager] SCRIPT STARTED EXECUTING")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local PitService = require(script.Parent:WaitForChild("PitService"))
local OfflineRewardService = require(script.Parent:WaitForChild("OfflineRewardService"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local StatBalance = require(Shared:WaitForChild("Config"):WaitForChild("StatBalance"))
local TowerHardcore = require(Shared:WaitForChild("Config"):WaitForChild("TowerHardcoreConfig"))
local TowerProgress = require(Shared:WaitForChild("Util"):WaitForChild("TowerProgress"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local Onboarding = require(Shared:WaitForChild("Util"):WaitForChild("Onboarding"))
local OnboardingService = require(script.Parent:WaitForChild("OnboardingService"))
local FortressTreeService = require(script.Parent:WaitForChild("FortressTreeService"))
local ProfileMigrations = require(script.Parent:WaitForChild("ProfileMigrations"))
local ProfilePersistence = require(script.Parent:WaitForChild("ProfilePersistence"))
local ForgeTransactions = require(script.Parent:WaitForChild("ForgeTransactions"))
local forgeTransactions = ForgeTransactions.new({
	Clock = function() return workspace:GetServerTimeNow() end,
	GenerateToken = function() return HttpService:GenerateGUID(false) end,
})

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TycoonRemotes = Remotes:WaitForChild("TycoonGachaRemotes")
local SyndicateRemotes = Remotes:WaitForChild("SyndicateRemotes")

local RequestSummonFunc = TycoonRemotes:WaitForChild("RequestSummon") :: RemoteFunction
local SynthesizeHeroesFunc = TycoonRemotes:WaitForChild("SynthesizeHeroes") :: RemoteFunction
local PromoteHeroStarFunc = TycoonRemotes:WaitForChild("PromoteHeroStar") :: RemoteFunction
local AssignHeroRoleFunc = TycoonRemotes:WaitForChild("AssignHeroRole") :: RemoteFunction
local FacilityInteractEvent = TycoonRemotes:WaitForChild("FacilityInteract") :: RemoteEvent
local PitRequestFunc = TycoonRemotes:FindFirstChild("PitRequest") :: RemoteFunction?
if not PitRequestFunc then
	PitRequestFunc = Instance.new("RemoteFunction")
	PitRequestFunc.Name = "PitRequest"
	PitRequestFunc.Parent = TycoonRemotes
end

local ProfileDeltaSyncEvent = SyndicateRemotes:WaitForChild("ProfileDeltaSync") :: RemoteEvent
local SystemToastEvent = SyndicateRemotes:WaitForChild("SystemToast") :: RemoteEvent

local ArtifactRemotes = Remotes:FindFirstChild("ArtifactRemotes")
if not ArtifactRemotes then
	ArtifactRemotes = Instance.new("Folder")
	ArtifactRemotes.Name = "ArtifactRemotes"
	ArtifactRemotes.Parent = Remotes
end

local RequestEquipArtifactFunc = ArtifactRemotes:FindFirstChild("RequestEquipArtifact") :: RemoteFunction?
if not RequestEquipArtifactFunc then
	RequestEquipArtifactFunc = Instance.new("RemoteFunction")
	RequestEquipArtifactFunc.Name = "RequestEquipArtifact"
	RequestEquipArtifactFunc.Parent = ArtifactRemotes
end

local RequestUnequipArtifactFunc = ArtifactRemotes:FindFirstChild("RequestUnequipArtifact") :: RemoteFunction?
if not RequestUnequipArtifactFunc then
	RequestUnequipArtifactFunc = Instance.new("RemoteFunction")
	RequestUnequipArtifactFunc.Name = "RequestUnequipArtifact"
	RequestUnequipArtifactFunc.Parent = ArtifactRemotes
end

local RequestToggleArtifactLockFunc = ArtifactRemotes:FindFirstChild("RequestToggleArtifactLock") :: RemoteFunction?
if not RequestToggleArtifactLockFunc then
	RequestToggleArtifactLockFunc = Instance.new("RemoteFunction")
	RequestToggleArtifactLockFunc.Name = "RequestToggleArtifactLock"
	RequestToggleArtifactLockFunc.Parent = ArtifactRemotes
end

local RequestSellArtifactsFunc = ArtifactRemotes:FindFirstChild("RequestSellArtifacts") :: RemoteFunction?
if not RequestSellArtifactsFunc then
	RequestSellArtifactsFunc = Instance.new("RemoteFunction")
	RequestSellArtifactsFunc.Name = "RequestSellArtifacts"
	RequestSellArtifactsFunc.Parent = ArtifactRemotes
end

local RequestUpgradeArtifactFunc = ArtifactRemotes:FindFirstChild("RequestUpgradeArtifact") :: RemoteFunction?
if not RequestUpgradeArtifactFunc then
	RequestUpgradeArtifactFunc = Instance.new("RemoteFunction")
	RequestUpgradeArtifactFunc.Name = "RequestUpgradeArtifact"
	RequestUpgradeArtifactFunc.Parent = ArtifactRemotes
end

local RequestSummonArtifactFunc = ArtifactRemotes:FindFirstChild("RequestSummonArtifact") :: RemoteFunction?
if not RequestSummonArtifactFunc then
	RequestSummonArtifactFunc = Instance.new("RemoteFunction")
	RequestSummonArtifactFunc.Name = "RequestSummonArtifact"
	RequestSummonArtifactFunc.Parent = ArtifactRemotes
end

local ForgeWorkbenchRequest = ArtifactRemotes:FindFirstChild("ForgeWorkbenchRequest") :: RemoteFunction?
if not ForgeWorkbenchRequest then
	ForgeWorkbenchRequest = Instance.new("RemoteFunction")
	ForgeWorkbenchRequest.Name = "ForgeWorkbenchRequest"
	ForgeWorkbenchRequest.Parent = ArtifactRemotes
end

-- Phase 4 progression remotes: the Fortress Tree purchase and the onboarding goal tracker.
local ProgressionRemotes = Remotes:FindFirstChild("ProgressionRemotes")
if not ProgressionRemotes then
	ProgressionRemotes = Instance.new("Folder")
	ProgressionRemotes.Name = "ProgressionRemotes"
	ProgressionRemotes.Parent = Remotes
end
local function progressionRemote(name: string, className: string): Instance
	local existing = (ProgressionRemotes :: Instance):FindFirstChild(name)
	if existing then return existing end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = ProgressionRemotes
	return remote
end
local UnlockTreeNodeFunc = progressionRemote("UnlockTreeNode", "RemoteFunction") :: RemoteFunction
local OnboardingSyncEvent = progressionRemote("OnboardingSync", "RemoteEvent") :: RemoteEvent

--============================================================================
-- 1. EXPORTED TYPE DEFINITIONS
--============================================================================

export type HeroArchetype = "Vanguard" | "Striker" | "Marksman" | "Miner" | "Healer" | "Scholar"

export type HeroAssignment =
	"BENCHED"
	| "SQUAD_SLOT_1"
	| "SQUAD_SLOT_2"
	| "SQUAD_SLOT_3"
	| "SQUAD_SLOT_4"
	| "SQUAD_SLOT_5"
	| "FACILITY_GUARD_POST"
	| "FACILITY_MARKET"
	| "FACILITY_TRAINING"
	| "FACILITY_GODS_BLESSING"

export type MimicChestMode = "TRUE_STATE" | "FOOLS_GOLD" | "VEIL_OF_POVERTY"

export type HeroInstance = {
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Archetype: HeroArchetype,
	Stars: number,
	Rarity: number?, -- Inherent rarity tier (Phase 4 §7); multiplies base stats, never changes
	Level: number,
	XP: number,
	QualityScalar: number,
	BaseHP: number,
	BaseATK: number,
	AttackRange: number,
	AttackInterval: number,
	BaseLabor: number,
	PassiveTrait: string,
	CurrentStamina: number,
	MaxStamina: number,
	ComaUntilTimestamp: number,
	IsHardAuditComa: boolean,
	Assignment: HeroAssignment,
	Locked: boolean,
	Favorite: boolean,
	OverflowXP: number,
	InheritedImprints: { [string]: number },
	ImprintCapacity: number,
	SynthesisHistory: any,
	EquippedArtifactUUID: string?,
}

export type ArtifactInstance = {
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Type: ArtifactCatalog.WeaponType,
	Star: number, -- 1..7
	Rarity: number, -- 1..16
	Level: number?, -- Legacy save field; ignored by combat and promotion.
	EquippedHeroUUID: string?,
	Locked: boolean,
}

export type FacilityData = {
	Level: number,
	AssignedHeroUUIDs: { string },
	UncollectedOutput: number,
	BlessedUntil: number,
	LeechedUntil: number,
	LeechVisitorUserId: number?,
	LastRuneTimestamp: number,
	LastRuneWasLeech: boolean,
}

export type SocialProfile = {
	Honor: number?,
	RogueUntilTimestamp: number?,
	PvPImmunityUntilTimestamp: number,
	ActivePactPartnerUserId: number?,
	LastShatterTimestamp: number,
	ListedMercenaryUUID: string?,
	ListedMercenaryFee: number,
	ListedMercenaryDirective: MercenaryDirective,
	GarnishedGemDebt: number,
	MimicIllusionMode: MimicChestMode,
	RentedMercenary: {
		OwnerUserId: number,
		OwnerName: string,
		HeroSnapshot: HeroInstance,
		Directive: MercenaryDirective,
		FeePaid: number,
		ExpiresAt: number,
		SiphonedGems: number,
		SaboteurArmed: boolean,
		Audited: boolean,
	}?,
	Stats: {
		PactsHonored: number,
		PactsBetrayed: number,
		SoulsAudited: number,
		RoguesDefeated: number,
		LeechesPurged: number,
	},
}

export type PlayerProfile = {
	SchemaVersion: number,
	UnlockedResearch: { [string]: boolean }?, -- Legacy Pit compatibility only; no research UI or unlocks.
	PitMaterials: { [string]: number },
	PitRevision: number,
	PlotIndex: number,
	Currencies: {
		Gold: number,
		Gems: number,
	},
	BossPity: number?,
	ArtifactBannerPity: number?,
	ArtifactBanner10Pity: number?,
	HeroBannerPity: number?,
	HeroPermanentPity: number?,
	HeroLimitedPity: number?,
	HeroLimitedFeaturedGuarantee: boolean?, -- 50/50 lost: the next A Star's Arrival pity is the featured hero
	RiftLuresOwned: number?,
	Heroes: { [string]: HeroInstance },
	DeployedSquadOrder: { string },
	Artifacts: { [string]: ArtifactInstance },
	Facilities: {
		GuardPost: FacilityData,
		Market: FacilityData,
		TrainingGrounds: FacilityData,
		GodsBlessing: FacilityData,
	},
	FortressTree: FortressTree.Tree,
	Onboarding: Onboarding.State,
	Unlocks: { [string]: boolean },
	HighestClearedBiomeBoss: number?,
	HighestClearedFloor: number?,
	MaxFloorReached: number?,
	LastLogoutTimestamp: number?,
	LastActiveTimestamp: number?,
	Social: SocialProfile,
}

--============================================================================
-- 2. PROFILE CREATION & HERO FACTORY
--============================================================================

local DataManager = {}
_G.DataManager = DataManager
print("[DataManager] _G.DataManager registered at line 145")
local ActiveProfiles: { [Player]: PlayerProfile } = {}

-- Support facilities start at level 0 (not built) until the Fortress Tree raises them.
local function createDefaultFacility(level: number?): FacilityData
	return ProfileMigrations.BlankFacility(level or 1)
end

function DataManager.EnsureFacilities(profile: any)
	if not profile.Facilities then
		profile.Facilities = {}
	end
	-- The Infirmary was removed (Phase 4); its heroes return to the bench in SyncProfile.
	profile.Facilities.Infirmary = nil
	if not profile.Facilities.GuardPost then
		profile.Facilities.GuardPost = createDefaultFacility()
	end
	if not profile.Facilities.Market then
		profile.Facilities.Market = createDefaultFacility(0)
	end
	if not profile.Facilities.TrainingGrounds then
		profile.Facilities.TrainingGrounds = createDefaultFacility(0)
	end
	if not profile.Facilities.GodsBlessing then
		profile.Facilities.GodsBlessing = createDefaultFacility(0)
	end
	if profile.HighestClearedBiomeBoss == nil then
		profile.HighestClearedBiomeBoss = 0
	end
	if profile.HighestClearedFloor == nil then
		profile.HighestClearedFloor = 0
	end
	if profile.MaxFloorReached == nil then
		profile.MaxFloorReached = math.max(1, (profile.HighestClearedFloor or 0) + 1)
	end
	if profile.LastActiveTimestamp == nil then
		profile.LastActiveTimestamp = os.time()
	end
	if profile.LastLogoutTimestamp == nil then
		profile.LastLogoutTimestamp = os.time()
	end
end

function DataManager.CreateArtifact(templateId: string, star: number?, rarity: number?): (string, ArtifactInstance)
	local seed = ArtifactCatalog.Seeds[templateId] or ArtifactCatalog.Seeds.art_hunters_shortbow or ArtifactCatalog.Seeds.art_iron_broadsword
	local uuid = "art_" .. string.gsub(HttpService:GenerateGUID(false), "-", ""):sub(1, 10)
	local artifact: ArtifactInstance = {
		UUID = uuid,
		TemplateId = seed.TemplateId,
		DisplayName = seed.DisplayName,
		Type = seed.Type,
		Star = star or 1,
		Rarity = seed.RarityTier or rarity or 1, -- rarity is inherent to the template
		EquippedHeroUUID = nil,
		Locked = false,
	}
	return uuid, artifact
end

-- One weapon type per archetype: re-derive saved artifact types from their
-- templates (legacy SWORD/SHIELD -> SWORD_SHIELD), drop removed templates such
-- as rings, and swap heroes off weapons their archetype can no longer hold.
function DataManager.MigrateArtifactTypes(profile: PlayerProfile)
	for uuid, artifact in pairs(profile.Artifacts) do
		local seed = ArtifactCatalog.Seeds[artifact.TemplateId]
		if seed then
			artifact.Type = seed.Type
		else
			local owner = artifact.EquippedHeroUUID and profile.Heroes[artifact.EquippedHeroUUID]
			if owner and owner.EquippedArtifactUUID == uuid then
				owner.EquippedArtifactUUID = nil
			end
			profile.Artifacts[uuid] = nil
		end
	end

	for heroUUID, hero in pairs(profile.Heroes) do
		local equipped = hero.EquippedArtifactUUID and profile.Artifacts[hero.EquippedArtifactUUID]
		if hero.EquippedArtifactUUID and not equipped then
			hero.EquippedArtifactUUID = nil
		elseif equipped and not ArtifactCatalog.CanHeroEquip(hero.Archetype, equipped.Type) then
			equipped.EquippedHeroUUID = nil
			hero.EquippedArtifactUUID = nil
			for uuid, candidate in pairs(profile.Artifacts) do
				if not candidate.EquippedHeroUUID and ArtifactCatalog.CanHeroEquip(hero.Archetype, candidate.Type) then
					candidate.EquippedHeroUUID = heroUUID
					hero.EquippedArtifactUUID = uuid
					break
				end
			end
		end
	end
end

function DataManager.CreateHeroFromSeed(seedId: string, forceQuality: number?): (string, HeroInstance)
	local seed = HeroCatalog.Seeds[seedId] or HeroCatalog.Seeds.hero_han
	local uuid = "h_" .. string.gsub(HttpService:GenerateGUID(false), "-", ""):sub(1, 10)
	local q = forceQuality or (math.round((0.90 + math.random() * 0.25) * 100) / 100)

	local hero: HeroInstance = {
		UUID = uuid,
		TemplateId = seed.HeroId,
		DisplayName = seed.DisplayName,
		Archetype = seed.Archetype :: HeroArchetype,
		Stars = seed.BaseStar, -- every hero is summoned at 1★
		Rarity = HeroCatalog.RarityOf(seed.HeroId),
		Level = 1,
		XP = 0,
		QualityScalar = q,
		BaseHP = seed.NativeHP,
		BaseATK = seed.NativeATK,
		AttackRange = seed.AttackRange,
		AttackInterval = seed.AttackInterval,
		BaseLabor = seed.NativeLabor,
		PassiveTrait = seed.PassiveTraitName,
		CurrentStamina = 100.0,
		MaxStamina = 100.0,
		ComaUntilTimestamp = 0,
		IsHardAuditComa = false,
		Assignment = "BENCHED",
		Locked = false,
		Favorite = false,
		OverflowXP = 0,
		InheritedImprints = {},
		ImprintCapacity = math.ceil(seed.Rarity / 2),
		SynthesisHistory = { DonorsConsumed = 0, XPGained = 0, ImprintsPerformed = 0, Promotions = 0 },
	}
	return uuid, hero
end

local function createDefaultPlayerProfile(): PlayerProfile
	local hanUUID, hanHero = DataManager.CreateHeroFromSeed("hero_han", 1.05)
	hanHero.Assignment = "SQUAD_SLOT_1"
	hanHero.Locked = true

	local jennaUUID, jennaHero = DataManager.CreateHeroFromSeed("hero_jenna", 1.00)
	jennaHero.Assignment = "BENCHED" -- squad slot 2 starts locked behind the Fortress Tree

	local catioUUID, catioHero = DataManager.CreateHeroFromSeed("hero_catio", 1.02)
	catioHero.Assignment = "BENCHED"

	-- Grant 1★ starter artifacts equipped to matching starting heroes
	local bowUUID, bowArt = DataManager.CreateArtifact("art_hunters_shortbow", 1, 1)
	local daggerUUID, daggerArt = DataManager.CreateArtifact("art_rusty_daggers", 1, 1)
	local axeUUID, axeArt = DataManager.CreateArtifact("art_miner_pickaxe", 1, 1)

	-- Additional starter artifacts for forge crafting and fodder testing
	local riftUUID, riftArt = DataManager.CreateArtifact("art_runic_longsword", 1)
	local f1_UUID, f1_Art = DataManager.CreateArtifact("art_iron_broadsword", 1, 1)
	local f2_UUID, f2_Art = DataManager.CreateArtifact("art_rusty_daggers", 1, 1)
	local f3_UUID, f3_Art = DataManager.CreateArtifact("art_hunters_shortbow", 1, 1)
	local f4_UUID, f4_Art = DataManager.CreateArtifact("art_miner_pickaxe", 1, 1)
	local f5_UUID, f5_Art = DataManager.CreateArtifact("art_novice_tome", 1, 1)

	jennaHero.EquippedArtifactUUID = bowUUID
	bowArt.EquippedHeroUUID = jennaUUID

	hanHero.EquippedArtifactUUID = daggerUUID
	daggerArt.EquippedHeroUUID = hanUUID

	catioHero.EquippedArtifactUUID = axeUUID
	axeArt.EquippedHeroUUID = catioUUID

	return {
		SchemaVersion = ProfileMigrations.CurrentSchema,
		PitMaterials = {
			SoulEssence = 0,
			PromotionStone = 2,
			ImprintCatalyst = 0,
		},
		PitRevision = 0,
		PlotIndex = 1,
		Currencies = {
			Gold = 500,
			Gems = TowerHardcore.StarterGems, -- Phase 6: one 10-pull with its guaranteed Rare (testers use DEV_GRANT_RESOURCES)
		},

		ArtifactBannerPity = 0,
		ArtifactBanner10Pity = 0,
		HeroBannerPity = 0,
		HeroPermanentPity = 0, -- Call of the Rift: Exalted+ hero guaranteed at HeroCatalog.PermanentBanner.MaxPity
		HeroLimitedPity = 0, -- A Star's Arrival: Exalted+ hero guaranteed at HeroCatalog.LimitedBanner.MaxPity
		HeroLimitedFeaturedGuarantee = false, -- 50/50: set when an Exalted+ pull is not the featured hero

		Heroes = {
			[hanUUID] = hanHero,
			[jennaUUID] = jennaHero,
			[catioUUID] = catioHero,
		},
		Artifacts = {
			[bowUUID] = bowArt,
			[daggerUUID] = daggerArt,
			[axeUUID] = axeArt,
			[riftUUID] = riftArt,
			[f1_UUID] = f1_Art,
			[f2_UUID] = f2_Art,
			[f3_UUID] = f3_Art,
			[f4_UUID] = f4_Art,
			[f5_UUID] = f5_Art,
		},
		DeployedSquadOrder = { hanUUID },
		Facilities = {
			GuardPost = createDefaultFacility(1),
			Market = createDefaultFacility(0),
			TrainingGrounds = createDefaultFacility(0),
			GodsBlessing = createDefaultFacility(0),
		},
		FortressTree = FortressTree.DefaultTree(),
		Onboarding = Onboarding.NewState(),
		Unlocks = { Summon = true },
		HighestClearedBiomeBoss = 0,
		HighestClearedFloor = 0,
		MaxFloorReached = 1,
		LastLogoutTimestamp = os.time(),
		LastActiveTimestamp = os.time(),
		Social = {
			PvPImmunityUntilTimestamp = 0,
			LastShatterTimestamp = 0,
			MimicIllusionMode = "TRUE_STATE",
			Stats = {
				RoguesDefeated = 0,
				LeechesPurged = 0,
			},
		},
	}
end

--============================================================================
-- 3. PUBLIC API & CLIENT SYNC
--============================================================================

function DataManager.GetProfile(player: Player): PlayerProfile?
	local profile = ActiveProfiles[player]
	if profile and (profile.SchemaVersion or 1) < 2 then PitService.EnsureDefaults(profile) end
	return profile
end

function DataManager.SendToast(player: Player, message: string, colorType: string?)
	SystemToastEvent:FireClient(player, message, colorType or "INFO")
end

function DataManager.BroadcastToast(message: string, colorType: string?)
	SystemToastEvent:FireAllClients(message, colorType or "ALERT")
end

-- Build a sanitized copy of profile for client UI (hiding secret directive of rented mercenary!)
function DataManager.SyncProfile(player: Player, progressionOnly: boolean?)
	local profile = ActiveProfiles[player]
	if not profile then
		return
	end

	-- Artifacts dictionary migration for existing profiles
	if not profile.Artifacts then
		profile.Artifacts = {}
	end
	if next(profile.Artifacts) == nil then
		local bUUID, bArt = DataManager.CreateArtifact("art_hunters_shortbow", 1, 1)
		local sUUID, sArt = DataManager.CreateArtifact("art_rusty_daggers", 1, 1)
		local aUUID, aArt = DataManager.CreateArtifact("art_miner_pickaxe", 1, 1)
		profile.Artifacts[bUUID] = bArt
		profile.Artifacts[sUUID] = sArt
		profile.Artifacts[aUUID] = aArt

		for _, h in pairs(profile.Heroes) do
			if h.TemplateId == "hero_jenna" and not h.EquippedArtifactUUID then
				h.EquippedArtifactUUID = bUUID
				bArt.EquippedHeroUUID = h.UUID
			elseif h.TemplateId == "hero_han" and not h.EquippedArtifactUUID then
				h.EquippedArtifactUUID = sUUID
				sArt.EquippedHeroUUID = h.UUID
			elseif h.TemplateId == "hero_catio" and not h.EquippedArtifactUUID then
				h.EquippedArtifactUUID = aUUID
				aArt.EquippedHeroUUID = h.UUID
			end
		end
	end
	DataManager.MigrateArtifactTypes(profile)
	-- Crafting was removed with the Gold banner: drop its old materials from the Backpack.
	if profile.PitMaterials then
		for _, id in { "IronGear", "RiftOrb", "AegisGem", "StarDust", "VoidPowder" } do
			profile.PitMaterials[id] = nil
		end
	end
	-- Forge Gold banner migration: rarity is inherent to the template, every artifact has a Locked
	-- flag, and the banner counters exist and sit below their guarantees.
	for _, art in pairs(profile.Artifacts) do
		local seed = ArtifactCatalog.Seeds[art.TemplateId]
		if seed and art.Rarity ~= seed.RarityTier then
			art.Rarity = seed.RarityTier
		end
		if type(art.Locked) ~= "boolean" then
			art.Locked = false
		end
	end
	local maxPity = ArtifactCatalog.Banner.MaxPity
	if type(profile.ArtifactBannerPity) ~= "number" then profile.ArtifactBannerPity = 0 end
	profile.ArtifactBannerPity = math.clamp(math.floor(profile.ArtifactBannerPity), 0, maxPity - 1)
	if type(profile.ArtifactBanner10Pity) ~= "number" then profile.ArtifactBanner10Pity = 0 end
	profile.ArtifactBanner10Pity = math.clamp(math.floor(profile.ArtifactBanner10Pity), 0, 9)
	-- 50/50 rule (added with Exalted+ hero pity): older profiles have no flag yet.
	if type(profile.HeroLimitedFeaturedGuarantee) ~= "boolean" then profile.HeroLimitedFeaturedGuarantee = false end

	-- Auto-migrate legacy SQUAD assignments or DeployedSquadOrder into the open squad slots
	local openSlots = DataManager.MaxSquadSlots(profile)
	local occupiedSlots: { [number]: string } = {}
	for uuid, h in pairs(profile.Heroes) do
		-- Migration: coma recovery once cleared this field to nil; the schema default is 0.
		if type(h.ComaUntilTimestamp) ~= "number" then
			h.ComaUntilTimestamp = 0
		end
		local slotNum = tonumber(string.match(h.Assignment or "", "^SQUAD_SLOT_(%d+)"))
		if slotNum and slotNum >= 1 and slotNum <= 5 then
			occupiedSlots[slotNum] = uuid
		end
	end
	-- One-time migration for saves from before squad slots. It must not run again: the order still
	-- lists a hero the player just benched, and re-deploying it made REMOVE look broken.
	local legacyOrder = not (profile :: any).SquadSlotsMigrated and next(occupiedSlots) == nil
	;(profile :: any).SquadSlotsMigrated = true
	if legacyOrder and profile.DeployedSquadOrder then
		for _, uuid in ipairs(profile.DeployedSquadOrder) do
			local h = profile.Heroes[uuid]
			if h and not string.find(h.Assignment or "", "^SQUAD_SLOT_") and not string.find(h.Assignment or "", "^FACILITY_") then
				for s = 1, openSlots do
					if not occupiedSlots[s] then
						h.Assignment = ("SQUAD_SLOT_" .. tostring(s)) :: HeroAssignment
						occupiedSlots[s] = uuid
						break
					end
				end
			end
		end
	end
	for uuid, h in pairs(profile.Heroes) do
		if h.Assignment == ("SQUAD" :: any) then
			for s = 1, openSlots do
				if not occupiedSlots[s] then
					h.Assignment = ("SQUAD_SLOT_" .. tostring(s)) :: HeroAssignment
					occupiedSlots[s] = uuid
					break
				end
			end
			if not string.find(h.Assignment or "", "^SQUAD_SLOT_") then
				h.Assignment = "BENCHED"
			end
		elseif not h.Assignment or h.Assignment == ("" :: any) or h.Assignment == ("FACILITY_INFIRMARY" :: any) then
			-- Unknown, empty or removed (Infirmary) assignments return to the bench.
			h.Assignment = "BENCHED"
		end
	end

	-- Heroes standing in a squad slot that is no longer open go back to the bench.
	for _, h in pairs(profile.Heroes) do
		local slotNum = tonumber(string.match(h.Assignment or "", "^SQUAD_SLOT_(%d+)$"))
		if slotNum and slotNum > openSlots then
			h.Assignment = "BENCHED"
		end
	end

	-- Reconcile DeployedSquadOrder from Hero Assignments
	local deployed: { string } = {}
	for slot = 1, 5 do
		local slotTag = "SQUAD_SLOT_" .. tostring(slot)
		for uuid, h in pairs(profile.Heroes) do
			if h.Assignment == slotTag then
				table.insert(deployed, uuid)
				break
			end
		end
	end
	profile.DeployedSquadOrder = deployed

	-- Notify CombatSimulation and PlotManager if loaded
	if not progressionOnly and _G.CombatSimulation and _G.CombatSimulation.RebuildPlayerSquad then
		_G.CombatSimulation.RebuildPlayerSquad(player)
	end
	if _G.PlotManager and _G.PlotManager.RefreshPlotVisuals then
		_G.PlotManager.RefreshPlotVisuals(player)
	end

	if progressionOnly and _G.CombatSimulation and _G.CombatSimulation.RefreshPlayerHeroStats then
		_G.CombatSimulation.RefreshPlayerHeroStats(player)
	end
	DataManager.UpdateSquadPower(player)
	forgeTransactions.Snapshot(profile)
	ProfileDeltaSyncEvent:FireClient(player, profile)
	OnboardingService.Push(player)
end

-- Squad Power and the player list (Phase 5 §2.3-2.4). The server computes Squad Power so the HUD
-- badge and every player's list column agree; leaderstats writes are throttled to one per 2 s.
local lastLeaderstatsWrite: { [Player]: number } = {}
local function ensureLeaderstats(player: Player): (IntValue, NumberValue)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local floor = folder:FindFirstChild("Floor") :: IntValue?
	if not floor then
		floor = Instance.new("IntValue")
		floor.Name = "Floor" -- first stat: Roblox sorts the player list by it
		floor.Parent = folder
	end
	local power = folder:FindFirstChild("Power") :: NumberValue?
	if not power then
		power = Instance.new("NumberValue")
		power.Name = "Power"
		power.Parent = folder
	end
	return floor :: IntValue, power :: NumberValue
end

function DataManager.UpdateSquadPower(player: Player)
	local profile = ActiveProfiles[player]
	if not profile then return end
	local total, perHero = StatFormulas.GetSquadPower(profile, DataManager.GetTrainingMultiplier(player))
	;(profile :: any).SquadPower = total
	;(profile :: any).SquadPowerByHero = perHero
	local floorStat, powerStat = ensureLeaderstats(player)
	floorStat.Value = profile.HighestClearedFloor or 0
	local now = os.clock()
	if powerStat.Value ~= total and now - (lastLeaderstatsWrite[player] or -99) >= 2 then
		lastLeaderstatsWrite[player] = now
		powerStat.Value = total
	elseif powerStat.Value ~= total then
		-- Catch up after the throttle window so the list never stays stale.
		task.delay(2, function()
			if player.Parent and ActiveProfiles[player] then
				lastLeaderstatsWrite[player] = os.clock()
				powerStat.Value = (ActiveProfiles[player] :: any).SquadPower or powerStat.Value
			end
		end)
	end

	local sss = game:GetService("ServerScriptService")
	local powerSys = sss:FindFirstChild("PowerLeaderboardSystem")
	local powerDS = powerSys and powerSys:FindFirstChild("PowerDataStore")
	if powerDS then
		local ok, mod = pcall(require, powerDS)
		if ok and mod and (mod :: any).RecordPower then
			(mod :: any).RecordPower(player.UserId, total)
		end
	end
end

-- Pit operations and participation EXP send only affected heroes. Consumers merge
-- this packet into their current session profile instead of replacing the roster.
function DataManager.SyncPitDelta(player: Player, changed: any, removed: any)
	local profile = ActiveProfiles[player]
	if not profile then return end
	if _G.CombatSimulation and _G.CombatSimulation.RefreshPlayerHeroStats then
		_G.CombatSimulation.RefreshPlayerHeroStats(player)
	end
	local facilityChanged = false
	for _, hero in pairs(changed) do
		if string.find(hero.Assignment or "", "^FACILITY_") then facilityChanged = true break end
	end
	if facilityChanged and _G.PlotManager and _G.PlotManager.RefreshPlotVisuals then
		_G.PlotManager.RefreshPlotVisuals(player)
	end
	DataManager.UpdateSquadPower(player)
	local forgeSnapshot = forgeTransactions.Snapshot(profile)
	ProfileDeltaSyncEvent:FireClient(player, { _PitDelta = true, Heroes = changed, Removed = removed, ForgeRevision = forgeSnapshot.Revision,
		Currencies = profile.Currencies, PitMaterials = profile.PitMaterials, PitRevision = profile.PitRevision,
		UnlockedResearch = profile.UnlockedResearch, SquadPower = (profile :: any).SquadPower,
		SquadPowerByHero = (profile :: any).SquadPowerByHero })
end

function DataManager.AdjustHonor(_player: Player, _delta: number, _markBetrayalRogue: boolean?)
end

function DataManager.IsPlayerRogue(_player: Player): boolean
	return false
end

-- One slot to start; the Fortress Tree's Command branch opens the other four (Phase 4).
function DataManager.MaxSquadSlots(profile: PlayerProfile): number
	return FortressTree.SquadSlots(profile and profile.FortressTree)
end

--============================================================================
-- 4. GACHA SUMMONING, THE PIT SYNTHESIS & STAR PROMOTION
--============================================================================

local function isLimitedBanner(bannerId: string?): boolean
	return bannerId == "banner_a_stars_arrival" or bannerId == "A_STARS_ARRIVAL" or bannerId == "LIMITED"
end

-- Summon luck from God's Blessing (Phase 4 §6.3), read when the pull is made.
function DataManager.GetSummonLuck(player: Player): number
	local profile = ActiveProfiles[player]
	local blessing = profile and profile.Facilities and profile.Facilities.GodsBlessing
	if not profile or not blessing or blessing.Level <= 0 then return 0 end
	local sumLabor = 0
	local now = os.time()
	for _, uuid in ipairs(blessing.AssignedHeroUUIDs) do
		local hero = profile.Heroes[uuid]
		if hero and (hero.ComaUntilTimestamp or 0) <= now then
			sumLabor += StatFormulas.GetEffectiveLabor(hero, "FACILITY_GODS_BLESSING")
		end
	end
	local perks = FortressTree.PerkBonuses(profile.FortressTree)
	return SummonLuck.Luck(blessing.Level, sumLabor, perks.BlessingLuck)
end

-- Rolls one rarity tier on a hero banner. Each tier holds one hero, summoned at its template star.
-- `minTier` forces the 10-pull guarantee. Returns the new hero and the tier rolled.
local function rollBannerHero(bannerId: string?, luck: number, minTier: number?): (string, HeroInstance, number)
	local banner = if isLimitedBanner(bannerId) then HeroCatalog.LimitedBanner else HeroCatalog.PermanentBanner
	local rates = SummonLuck.ApplyLuck(banner.Rates :: { number }, luck)
	local tier = if minTier then SummonLuck.RollAtLeast(rates, minTier, math.random()) else SummonLuck.Roll(rates, math.random())
	local chosenId = banner.HeroesByStar[tier]
	if not chosenId then
		local pool = HeroCatalog.PoolByStar[tier] or HeroCatalog.PoolByStar[1]
		chosenId = pool[math.random(1, #pool)]
	end
	local uuid, hero = DataManager.CreateHeroFromSeed(chosenId)
	return uuid, hero, tier
end

local function validateCallerPlotOwnership(player: Player, targetPlot: any?): boolean
	if _G.PlotManager and _G.PlotManager.IsPlayerPlotOwner then
		return _G.PlotManager.IsPlayerPlotOwner(player, targetPlot)
	end
	return true
end

-- Rolls `count` heroes on a banner (no cost): pity, the 10-pull floor and God's Blessing luck all
-- apply. Used by Gem summons and by Robux summon packs (ShopService).
function DataManager.RollSummons(player: Player, bannerId: string, count: number): ({ HeroInstance }, number, number, any, string, boolean)
	local profile = ActiveProfiles[player] :: PlayerProfile
	local isLimited = isLimitedBanner(bannerId)
	local banner = if isLimited then HeroCatalog.LimitedBanner else HeroCatalog.PermanentBanner
	local bannerKey = isLimited and "HeroLimitedPity" or "HeroPermanentPity"
	local pityTier = banner.PityMinTier or 5
	local featuredId = banner.FeaturedHeroId or banner.HeroesByStar[banner.MaxStar]

	if profile.HeroPermanentPity == nil then profile.HeroPermanentPity = profile.HeroBannerPity or 0 end
	if profile.HeroLimitedPity == nil then profile.HeroLimitedPity = 0 end

	local summonedList: { HeroInstance } = {}
	local luck = DataManager.GetSummonLuck(player)
	local bestTier = 0

	for pull = 1, count do
		local currentPity = (profile[bannerKey] or 0) + 1
		profile[bannerKey] = currentPity

		local uuid: string
		local hero: HeroInstance
		local tier: number

		if currentPity >= banner.MaxPity and isLimited and profile.HeroLimitedFeaturedGuarantee then
			-- 50/50 lost last time: this pity pull is the featured hero.
			uuid, hero = DataManager.CreateHeroFromSeed(featuredId)
			tier = banner.MaxStar
		elseif currentPity >= banner.MaxPity then
			-- Hard pity: an Exalted or better hero, split by the luck-boosted rates of those tiers.
			uuid, hero, tier = rollBannerHero(isLimited and "A_STARS_ARRIVAL" or "CALL_OF_THE_RIFT", luck, pityTier)
		else
			-- The 10th pull of a 10x is forced to Rare or better if the first nine were not.
			local guarantee = if count == 10 and pull == count and bestTier < banner.TenPullMinTier then banner.TenPullMinTier else nil
			uuid, hero, tier = rollBannerHero(isLimited and "A_STARS_ARRIVAL" or "CALL_OF_THE_RIFT", luck, guarantee)
		end
		if tier >= pityTier then
			profile[bannerKey] = 0 -- any Exalted+ hero, natural or pity, resets the counter
			if isLimited then
				-- 50/50: an Exalted+ hero that is not the featured one guarantees the featured hero at the next pity.
				profile.HeroLimitedFeaturedGuarantee = hero.TemplateId ~= featuredId
			end
		end
		bestTier = math.max(bestTier, tier)

		profile.Heroes[uuid] = hero
		table.insert(summonedList, hero)
	end

	-- Mirror permanent pity to legacy HeroBannerPity for backwards compatibility
	profile.HeroBannerPity = profile.HeroPermanentPity
	return summonedList, bestTier, luck, banner, bannerKey, isLimited
end

RequestSummonFunc.OnServerInvoke = function(player: Player, arg1: any, arg2: any, arg3: any)
	-- Support flexible calling signatures:
	-- (player, pullCount, targetPlot, bannerId) or (player, bannerId, pullCount, targetPlot)
	local bannerId = "CALL_OF_THE_RIFT"
	local pullCount = 1
	local targetPlot: any? = nil

	if type(arg1) == "string" and (arg1 == "CALL_OF_THE_RIFT" or arg1 == "A_STARS_ARRIVAL" or arg1:match("^banner_")) then
		bannerId = arg1
		pullCount = tonumber(arg2) or 1
		targetPlot = arg3
	else
		pullCount = tonumber(arg1) or 1
		targetPlot = arg2
		if type(arg3) == "string" then
			bannerId = arg3
		end
	end

	if not validateCallerPlotOwnership(player, targetPlot) then
		return { Success = false, Message = "Plot ownership validation failed" }
	end
	local profile = ActiveProfiles[player]
	if not profile then
		return { Success = false, Message = "Profile not loaded" }
	end

	local count = (pullCount == 10) and 10 or 1
	local currentHeroCount = 0
	for _ in pairs(profile.Heroes) do
		currentHeroCount += 1
	end
	if currentHeroCount + count > StatBalance.MaxHeroInventory then
		DataManager.SendToast(player, string.format("Hero inventory full! Maximum capacity is %d.", StatBalance.MaxHeroInventory), "WARN")
		return { Success = false, Message = "Hero inventory full" }
	end

	local costBanner = if isLimitedBanner(bannerId) then HeroCatalog.LimitedBanner else HeroCatalog.PermanentBanner
	local gemCost = if count == 10 then costBanner.Cost10X else costBanner.Cost1X

	if profile.Currencies.Gems < gemCost then
		DataManager.SendToast(player, string.format("Need %d Gems to Summon!", gemCost), "WARN")
		return { Success = false, Message = "Insufficient Gems" }
	end

	profile.Currencies.Gems -= gemCost
	local summonedList, bestTier, luck, banner, bannerKey, isLimited = DataManager.RollSummons(player, bannerId, count)

	local pityRemaining = math.max(1, banner.MaxPity - (profile[bannerKey] or 0))
	DataManager.SyncProfile(player)
	OnboardingService.Report(player, "HeroSummoned")
	if luck > 0 and bestTier >= 3 and _G.PlotManager and _G.PlotManager.PulseBlessing then
		_G.PlotManager.PulseBlessing(player)
	end

	-- No success toast: the client plays a per-pull reveal, and a toast would spoil it.
	return {
		Success = true,
		Summoned = summonedList,
		BannerId = isLimited and "A_STARS_ARRIVAL" or "CALL_OF_THE_RIFT",
		PityRemaining = pityRemaining,
		PermanentPityRemaining = math.max(1, HeroCatalog.PermanentBanner.MaxPity - profile.HeroPermanentPity),
		LimitedPityRemaining = math.max(1, HeroCatalog.LimitedBanner.MaxPity - profile.HeroLimitedPity),
		SummonLuck = luck,
	}
end

-- Legacy endpoints cannot bypass confirmed previews.
function DataManager.SynthesizeHeroes(player: Player, _targetUUID: string, _fodderUUIDs: { string }, targetPlot: any?): (boolean, string)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed"
	end
	return false, "Use the Synthesis chamber to synthesize heroes."
end
function DataManager.PromoteHeroStar(player: Player, _targetUUID: string, _fodderUUIDs: { string }, targetPlot: any?): (boolean, string)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed"
	end
	return false, "Use the Promotion chamber to promote heroes."
end
SynthesizeHeroesFunc.OnServerInvoke = DataManager.SynthesizeHeroes
PromoteHeroStarFunc.OnServerInvoke = DataManager.PromoteHeroStar

local pendingCombatSync: { [Player]: any } = {}
local pit = PitService.new({
	GetProfile = function(player: Player) return ActiveProfiles[player] end,
	GenerateToken = function() return HttpService:GenerateGUID(false) end,
	Clock = os.clock,
	SyncProfile = function(player: Player, changed: any, removed: any)
		DataManager.SyncPitDelta(player, changed or {}, removed or {})
	end,
	SyncCombatXP = function(player: Player, uuid: string, _hero: any)
		if not pendingCombatSync[player] then
			pendingCombatSync[player] = {}
			task.delay(0.25, function()
				local pending = pendingCombatSync[player]
				pendingCombatSync[player] = nil
				local profile = ActiveProfiles[player]
				if pending and profile then
					local changed = {}
					for pendingUUID in pairs(pending) do
						if profile.Heroes[pendingUUID] then changed[pendingUUID] = profile.Heroes[pendingUUID] end
					end
					if next(changed) then DataManager.SyncPitDelta(player, changed, {}) end
				end
			end)
		end
		pendingCombatSync[player][uuid] = true
	end,
})
DataManager.PitService = pit
function DataManager.GrantCombatXP(player: Player, uuid: string, amount: number): (boolean, any)
	return pit:GrantCombatXP(player, uuid, amount)
end
(PitRequestFunc :: RemoteFunction).OnServerInvoke = function(player: Player, command: any, payload: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed"
	end
	-- Viewing the roster stays open; changing it needs The Pit unlocked (Phase 4 onboarding).
	if (command == "PREVIEW" or command == "COMMIT") and not OnboardingService.IsUnlocked(player, "Pit") then
		local message = OnboardingService.LockedMessage("Pit")
		return { Success = false, Message = message, Reason = message }
	end
	local response = pit:Request(player, command, payload)
	if command == "COMMIT" and type(response) == "table" and response.Success then
		OnboardingService.Report(player, "PitUsed")
	end
	return response
end


--============================================================================
-- ARTIFACT & WEAPON MANAGEMENT (EQUIP, UNEQUIP & BLACKSMITH UPGRADE)
--============================================================================

function DataManager.GetArtifacts(player: Player): { [string]: ArtifactInstance }
	local profile = ActiveProfiles[player]
	if not profile then return {} end
	if not profile.Artifacts then profile.Artifacts = {} end
	return profile.Artifacts
end

function DataManager.EquipArtifact(player: Player, heroUUID: string, artifactUUID: string): (boolean, string?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded" end

	local hero = profile.Heroes[heroUUID]
	if not hero then return false, "Hero not found" end

	local artifact = profile.Artifacts and profile.Artifacts[artifactUUID]
	if not artifact then return false, "Artifact not found" end

	-- Enforce class archetype restrictions
	if not ArtifactCatalog.CanHeroEquip(hero.Archetype, artifact.Type) then
		local allowed = ArtifactCatalog.ArchetypeRestrictions[hero.Archetype]
		local allowedStr = allowed and table.concat(allowed, ", ") or "None"
		return false, string.format("%s (%s) cannot equip a %s! Permitted weapon types: %s", hero.DisplayName, hero.Archetype, artifact.Type, allowedStr)
	end

	-- Unequip from prior hero if held
	if artifact.EquippedHeroUUID and artifact.EquippedHeroUUID ~= heroUUID then
		local priorHero = profile.Heroes[artifact.EquippedHeroUUID]
		if priorHero then
			priorHero.EquippedArtifactUUID = nil
		end
	end

	-- Unequip existing artifact from target hero
	if hero.EquippedArtifactUUID and hero.EquippedArtifactUUID ~= artifactUUID then
		local oldArt = profile.Artifacts[hero.EquippedArtifactUUID]
		if oldArt then
			oldArt.EquippedHeroUUID = nil
		end
	end

	hero.EquippedArtifactUUID = artifactUUID
	artifact.EquippedHeroUUID = heroUUID

	DataManager.SyncProfile(player)
	DataManager.SendToast(player, string.format("Equipped %s to %s!", artifact.DisplayName, hero.DisplayName), "SUCCESS")
	return true, string.format("Equipped %s to %s", artifact.DisplayName, hero.DisplayName)
end

function DataManager.UnequipArtifact(player: Player, heroUUID: string): (boolean, string?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded" end

	local hero = profile.Heroes[heroUUID]
	if not hero then return false, "Hero not found" end

	if not hero.EquippedArtifactUUID then
		return false, "No artifact equipped on this hero"
	end

	local oldArt = profile.Artifacts and profile.Artifacts[hero.EquippedArtifactUUID]
	if oldArt then
		oldArt.EquippedHeroUUID = nil
	end
	hero.EquippedArtifactUUID = nil

	DataManager.SyncProfile(player)
	DataManager.SendToast(player, string.format("Unequipped weapon from %s.", hero.DisplayName), "INFO")
	return true, string.format("Unequipped weapon from %s", hero.DisplayName)
end

-- Locked artifacts can't be sold (and sell-all skips them). Returns the new lock state.
function DataManager.SetArtifactLocked(player: Player, artifactUUID: string, locked: boolean): (boolean, string?, boolean?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded", nil end
	local art = profile.Artifacts and profile.Artifacts[artifactUUID]
	if not art then return false, "Artifact not found", nil end
	art.Locked = locked
	DataManager.SyncProfile(player)
	return true, if locked then "Locked" else "Unlocked", locked
end

RequestEquipArtifactFunc.OnServerInvoke = function(player: Player, heroUUID: any, artifactUUID: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed"
	end
	if type(heroUUID) ~= "string" or type(artifactUUID) ~= "string" then
		return false, "Invalid parameters"
	end
	return DataManager.EquipArtifact(player, heroUUID, artifactUUID)
end

RequestUnequipArtifactFunc.OnServerInvoke = function(player: Player, heroUUID: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed"
	end
	if type(heroUUID) ~= "string" then
		return false, "Invalid parameters"
	end
	return DataManager.UnequipArtifact(player, heroUUID)
end

RequestToggleArtifactLockFunc.OnServerInvoke = function(player: Player, artifactUUID: any, locked: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed", nil
	end
	if type(artifactUUID) ~= "string" or #artifactUUID > 64 or type(locked) ~= "boolean" then
		return false, "Invalid parameters", nil
	end
	return DataManager.SetArtifactLocked(player, artifactUUID, locked)
end

function DataManager.SellArtifacts(player: Player, artifactUUIDs: { string }): (boolean, string?, number?, number?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded", 0, 0 end
	if not profile.Artifacts then return false, "No artifacts found", 0, 0 end
	if type(artifactUUIDs) ~= "table" or #artifactUUIDs == 0 then
		return false, "No artifacts selected for sale", 0, 0
	end

	if #artifactUUIDs > StatBalance.MaxArtifactInventory then
		return false, "Too many artifacts selected", 0, 0
	end

	local totalGold = 0
	local soldCount = 0
	local toDelete = {}
	local seen: { [string]: boolean } = {}

	for _, uuid in ipairs(artifactUUIDs) do
		if type(uuid) ~= "string" then
			return false, "Invalid artifact id", 0, 0
		end
		if not seen[uuid] then
			seen[uuid] = true
			local art = profile.Artifacts[uuid]
			if art then
				if art.EquippedHeroUUID then
					DataManager.SendToast(player, string.format("Cannot sell %s (equipped)!", art.DisplayName), "WARN")
					return false, string.format("Cannot sell %s: weapon is equipped", art.DisplayName), 0, 0
				end
				if art.Locked then
					DataManager.SendToast(player, string.format("Cannot sell %s (locked)!", art.DisplayName), "WARN")
					return false, string.format("Cannot sell %s: weapon is locked", art.DisplayName), 0, 0
				end
				local price = ArtifactCatalog.CalculateSellPrice(art.Rarity or 1, art.Star or 1)
				totalGold += price
				soldCount += 1
				table.insert(toDelete, uuid)
			end
		end
	end

	if soldCount == 0 then
		return false, "No valid artifacts selected", 0, 0
	end

	for _, uuid in ipairs(toDelete) do
		profile.Artifacts[uuid] = nil
	end

	profile.Currencies.Gold = (profile.Currencies.Gold or 0) + totalGold
	DataManager.SyncProfile(player)
	DataManager.SendToast(player, string.format("Sold %d artifact%s for %s Gold!", soldCount, soldCount == 1 and "" or "s", tostring(totalGold)), "SUCCESS")

	return true, string.format("Sold %d artifacts for %d Gold", soldCount, totalGold), totalGold, soldCount
end

function DataManager.UpgradeArtifact(player: Player, targetUUID: string, fodderUUIDs: { any }): (boolean, string?, number?)
 local profile=ActiveProfiles[player]
 if not profile then return false,"Profile not loaded",nil end
 local Promotion=require(ReplicatedStorage.Shared.Util.WeaponPromotion)
 local ok,message,star=Promotion.Promote(profile,targetUUID,fodderUUIDs)
 if ok then
  DataManager.SyncProfile(player,true)
  DataManager.SendToast(player,message,"SUCCESS")
 else
  -- The Forge UI does not show refusals itself, so say why (missing Gold, invalid donors...).
  DataManager.SendToast(player,message or "The promotion could not be completed.","WARN")
 end
 return ok,message,star
end

RequestSellArtifactsFunc.OnServerInvoke = function(player: Player, artifactUUIDs: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed", 0, 0
	end
	if type(artifactUUIDs) ~= "table" then
		return false, "Invalid parameters", 0, 0
	end
	if not OnboardingService.Require(player, "Forge") then
		return false, OnboardingService.LockedMessage("Forge"), 0, 0
	end
	return DataManager.SellArtifacts(player, artifactUUIDs)
end

RequestUpgradeArtifactFunc.OnServerInvoke = function(player: Player, targetUUID: any, fodderUUIDs: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed", nil
	end
	if type(targetUUID) ~= "string" or type(fodderUUIDs) ~= "table" then
		return false, "Invalid parameters", nil
	end
	if not OnboardingService.Require(player, "Forge") then -- toasts the unlock hint
		return false, OnboardingService.LockedMessage("Forge"), nil
	end
	local ok, message, star = DataManager.UpgradeArtifact(player, targetUUID, fodderUUIDs)
	if ok then
		OnboardingService.Report(player, "ArtifactUpgraded")
	end
	return ok, message, star
end

-- The new workbench uses one authoritative, idempotent command endpoint. Legacy summon/sell
-- endpoints remain available; their changes are included in the next structural revision.
(ForgeWorkbenchRequest :: RemoteFunction).OnServerInvoke = function(player: Player, action: any, payload: any, targetPlot: any?)
	local profile = ActiveProfiles[player]
	if not profile then error("Profile is still loading. Please reopen the Forge.") end
	if not validateCallerPlotOwnership(player, targetPlot) then error("Plot ownership validation failed") end
	if action == "STATE" then
		return forgeTransactions.Read(profile)
	elseif action == "RECONCILE" then
		return forgeTransactions.Reconcile(profile, payload)
	elseif action ~= "EXECUTE" then
		error("Invalid Forge action")
	end
	local result, committed = forgeTransactions.Execute(profile, payload, OnboardingService.IsUnlocked(player, "Forge"))
	-- The mutation and its receipt are complete before synchronization can yield or call other systems.
	if committed then
		task.defer(function()
			if ActiveProfiles[player] ~= profile then return end
			local kind = payload.Kind
			DataManager.SyncProfile(player, kind == "UPGRADE" or kind == "LOCK")
			if kind == "UPGRADE" then OnboardingService.Report(player, "ArtifactUpgraded") end
		end)
	end
	return result
end

-- The banner rolls a tier and a weapon type, then a variant. Fail at server start, not after taking
-- a player's Gold, if any tier/type pair is missing a weapon.
for tier = 1, #ArtifactCatalog.Banner.BaseRarityRates do
	for _, weaponType in ipairs(ArtifactCatalog.ArchetypeTypes) do
		local std, enh = ArtifactCatalog.GetTierPair(tier, weaponType)
		assert(std and enh, string.format("ArtifactCatalog is missing a tier %d %s weapon", tier, weaponType))
	end
end

function DataManager.SummonArtifact(player: Player, pullCount: any): (boolean, string?, { any }?, number?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded", nil, nil end

	local count = (pullCount == 10) and 10 or 1
	local cfg = ArtifactCatalog.Banner
	local cost = (count == 10) and cfg.Cost10X or cfg.Cost1X

	if not profile.Currencies or (profile.Currencies.Gold or 0) < cost then
		DataManager.SendToast(player, string.format("Need %d Gold to Summon!", cost), "WARN")
		return false, string.format("Need %d Gold to Summon!", cost), nil, nil
	end

	if not profile.Artifacts then profile.Artifacts = {} end
	local currentArtCount = 0
	for _ in pairs(profile.Artifacts) do
		currentArtCount += 1
	end
	if currentArtCount + count > StatBalance.MaxArtifactInventory then
		DataManager.SendToast(player, string.format("Artifact inventory full! Maximum capacity is %d.", StatBalance.MaxArtifactInventory), "WARN")
		return false, "Artifact inventory full", nil, nil
	end

	profile.Currencies.Gold -= cost
	if profile.ArtifactBannerPity == nil then profile.ArtifactBannerPity = 0 end
	if profile.ArtifactBanner10Pity == nil then profile.ArtifactBanner10Pity = 0 end

	local summonedList = {}
	local luck = DataManager.GetSummonLuck(player)
	local tierRates = SummonLuck.ApplyLuck(cfg.BaseRarityRates, luck)
	local archetypeTypes = ArtifactCatalog.ArchetypeTypes
	local bestTier = 1

	for _ = 1, count do
		profile.ArtifactBannerPity += 1
		profile.ArtifactBanner10Pity += 1

		local isGuaranteedExalted = (profile.ArtifactBannerPity >= cfg.MaxPity)
		local isGuaranteedRare = (profile.ArtifactBanner10Pity >= 10)

		local tier: number
		if isGuaranteedExalted then
			-- 120-pull hard pity: Exalted or higher, split by the luck-boosted rates of those tiers.
			tier = SummonLuck.RollAtLeast(tierRates, cfg.PityRarity, math.random())
		elseif isGuaranteedRare then
			tier = SummonLuck.RollAtLeast(tierRates, 3, math.random())
		else
			tier = SummonLuck.Roll(tierRates, math.random())
		end

		if tier > bestTier then
			bestTier = tier
		end

		if tier >= 5 then
			profile.ArtifactBannerPity = 0
		end
		if tier >= 3 then
			profile.ArtifactBanner10Pity = 0
		end

		-- Uniform archetype selection across 6 archetypes
		local chosenType = archetypeTypes[math.random(1, #archetypeTypes)]
		local stdSeed, enhSeed = ArtifactCatalog.GetTierPair(tier, chosenType)

		-- Variant roll: 60% Standard, 40% Enhanced
		local chosenSeed = if math.random() <= 0.60 then (stdSeed or enhSeed) else (enhSeed or stdSeed)
		assert(chosenSeed, string.format("No artifact for tier %d %s", tier, chosenType)) -- the load-time check makes this unreachable

		-- All summoned artifacts start at 1★ baseline
		local uuid, artifact = DataManager.CreateArtifact(chosenSeed.TemplateId, 1, tier)
		profile.Artifacts[uuid] = artifact
		table.insert(summonedList, artifact)
	end

	DataManager.SyncProfile(player)
	OnboardingService.Report(player, "ArtifactSummoned")
	if luck > 0 and bestTier >= 3 and _G.PlotManager and _G.PlotManager.PulseBlessing then
		_G.PlotManager.PulseBlessing(player)
	end

	local pityRemaining = math.max(1, cfg.MaxPity - profile.ArtifactBannerPity)
	return true, "Summon successful", summonedList, pityRemaining
end

RequestSummonArtifactFunc.OnServerInvoke = function(player: Player, pullCount: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed", nil, 0
	end
	return DataManager.SummonArtifact(player, pullCount)
end

--============================================================================
-- 5. HERO ASSIGNMENT (SQUAD, FACILITIES, BENCH & AUTO-SWAP EXHAUSTED)
--============================================================================

-- Assignment tag -> profile.Facilities key for the Fortress Tree support facilities.
local FACILITY_BY_TAG: { [string]: string } = {
	FACILITY_GUARD_POST = "GuardPost",
	FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "TrainingGrounds",
	FACILITY_GODS_BLESSING = "GodsBlessing",
}
local FACILITY_NAMES: { [string]: string } = {
	GuardPost = "The Outskirts Guard Post",
	Market = "The Market",
	TrainingGrounds = "The Training Grounds",
	GodsBlessing = "God's Blessing",
}

local function removeUUIDFromFacilities(profile: PlayerProfile, uuid: string)
	for _, fac in pairs(profile.Facilities) do
		for i = #fac.AssignedHeroUUIDs, 1, -1 do
			if fac.AssignedHeroUUIDs[i] == uuid then
				table.remove(fac.AssignedHeroUUIDs, i)
			end
		end
	end
end

AssignHeroRoleFunc.OnServerInvoke = function(player: Player, heroUUID: any, targetAssignment: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed"
	end
	local profile = ActiveProfiles[player]
	if not profile then
		return false, "Profile not loaded"
	end

	-- Special Smart Action from Document 4 Section 2.2: "AUTO_SWAP_EXHAUSTED"
	if heroUUID == "AUTO_SWAP_EXHAUSTED" then
		if not OnboardingService.Require(player, "Squad") then -- toasts the unlock hint
			return false, OnboardingService.LockedMessage("Squad")
		end
		local maxSlots = DataManager.MaxSquadSlots(profile)
		local swappedCount = 0

		-- 1. Bench any deployed hero still in a Coma
		for _, h in pairs(profile.Heroes) do
			if string.find(h.Assignment, "^SQUAD_SLOT_") and h.ComaUntilTimestamp > os.time() then
				h.Assignment = "BENCHED"
				swappedCount += 1
			end
		end

		-- 2. Fill empty squad slots (1..maxSlots) with highest-DPS rested Benched heroes
		for slot = 1, maxSlots do
			local slotName = ("SQUAD_SLOT_" .. slot) :: HeroAssignment
			local occupied = false
			for _, h in pairs(profile.Heroes) do
				if h.Assignment == slotName then
					occupied = true
					break
				end
			end
			if not occupied then
				local bestHero: HeroInstance? = nil
				local bestDPS = -1
				for _, h in pairs(profile.Heroes) do
					if h.Assignment == "BENCHED" and h.ComaUntilTimestamp <= os.time() then
						local _, _, dps = StatFormulas.GetEffectiveCombatStats(h, false, false, StatFormulas.GetEquippedArtifact(profile, h))
						if dps > bestDPS then
							bestDPS = dps
							bestHero = h
						end
					end
				end
				if bestHero then
					bestHero.Assignment = slotName
					swappedCount += 1
				end
			end
		end

		DataManager.SyncProfile(player)
		DataManager.SendToast(player, string.format("Auto-Rotated Squad (%d hero assignments updated)!", swappedCount), "SUCCESS")
		return true, "Auto-swapped exhausted heroes"
	end

	-- "AUTO_BEST": deploy the strongest ready heroes (by Squad Power) from the squad and bench.
	-- Facility workers stay at work; resting heroes are benched.
	if heroUUID == "AUTO_BEST" then
		if not OnboardingService.Require(player, "Squad") then -- toasts the unlock hint
			return false, OnboardingService.LockedMessage("Squad")
		end
		local maxSlots = DataManager.MaxSquadSlots(profile)
		local mult = DataManager.GetTrainingMultiplier(player)
		local candidates: { { Hero: HeroInstance, Power: number } } = {}
		for _, h in pairs(profile.Heroes) do
			local inSquad = string.find(h.Assignment, "^SQUAD_SLOT_") ~= nil
			if inSquad or h.Assignment == "BENCHED" then
				h.Assignment = "BENCHED"
				if h.ComaUntilTimestamp <= os.time() then
					table.insert(candidates, { Hero = h, Power = StatFormulas.GetHeroPower(h, StatFormulas.GetEquippedArtifact(profile, h), mult) })
				end
			end
		end
		table.sort(candidates, function(a, b) return a.Power > b.Power end)
		local placed = math.min(maxSlots, #candidates)
		for slot = 1, placed do
			candidates[slot].Hero.Assignment = ("SQUAD_SLOT_" .. slot) :: HeroAssignment
		end
		OnboardingService.Report(player, "SquadDeployed")
		DataManager.SyncProfile(player)
		return true, string.format("Deployed your %d strongest ready heroes.", placed)
	end

	if type(heroUUID) ~= "string" or type(targetAssignment) ~= "string" then
		return false, "Invalid parameters"
	end

	local hero = profile.Heroes[heroUUID]
	if not hero then
		return false, "Hero not found"
	end

	if hero.ComaUntilTimestamp > os.time() and targetAssignment ~= "BENCHED" then
		return false, "Hero is in a Coma and must rest on the bench!"
	end

	-- Support facilities (Phase 4): locked until built in the Fortress Tree; worker slots include perks.
	local supportFacility = FACILITY_BY_TAG[targetAssignment]
	local isSquad = string.find(targetAssignment, "^SQUAD_SLOT_") ~= nil or targetAssignment == "SQUAD_AUTO"
	if isSquad and not OnboardingService.Require(player, "Squad") then -- toasts the unlock hint
		return false, OnboardingService.LockedMessage("Squad")
	end
	if supportFacility then
		if not OnboardingService.Require(player, "Facilities") then -- toasts the unlock hint
			return false, OnboardingService.LockedMessage("Facilities")
		end
		local facData = (profile.Facilities :: any)[supportFacility] :: FacilityData?
		if not facData or facData.Level <= 0 then
			return false, string.format("%s isn't built yet. Unlock it in Upgrades.", FACILITY_NAMES[supportFacility])
		end
		local perks = FortressTree.PerkBonuses(profile.FortressTree)
		local maxWorkers = StatFormulas.GetFacilityMaxWorkers(supportFacility, facData.Level, perks)
		local others = 0
		for _, uuid in ipairs(facData.AssignedHeroUUIDs) do
			if uuid ~= heroUUID then others += 1 end
		end
		if others >= maxWorkers then
			return false, string.format("%s is full! (Max %d at Lv.%d)", FACILITY_NAMES[supportFacility], maxWorkers, facData.Level)
		end
	end

	-- Validate the squad slot before touching facilities, so a refused move changes nothing.
	if string.find(targetAssignment, "^SQUAD_SLOT_") then
		local slotNum = tonumber(string.match(targetAssignment, "^SQUAD_SLOT_(%d+)$") or "")
		if not slotNum or slotNum < 1 or slotNum > DataManager.MaxSquadSlots(profile) then
			return false, "That squad slot isn't open yet."
		end
	end

	removeUUIDFromFacilities(profile, heroUUID)

	if targetAssignment == "BENCHED" then
		hero.Assignment = "BENCHED"
	elseif string.find(targetAssignment, "^SQUAD_SLOT_") then
		local slotNum = tonumber(string.match(targetAssignment, "%d+"))
		local maxSlots = DataManager.MaxSquadSlots(profile)
		if not slotNum or slotNum < 1 or slotNum > maxSlots then
			return false, "Invalid squad slot"
		end
		local oldAssignment = hero.Assignment
		for _, h in pairs(profile.Heroes) do
			if h.Assignment == targetAssignment and h.UUID ~= heroUUID then
				h.Assignment = (string.find(oldAssignment, "^SQUAD_SLOT_") and oldAssignment) or "BENCHED"
			end
		end
		hero.Assignment = targetAssignment :: HeroAssignment
	elseif targetAssignment == "SQUAD_AUTO" then
		local maxSlots = DataManager.MaxSquadSlots(profile)
		local placed = false
		for slot = 1, maxSlots do
			local slotTag = ("SQUAD_SLOT_" .. slot) :: HeroAssignment
			local hasUnit = false
			for _, h in pairs(profile.Heroes) do
				if h.Assignment == slotTag then
					hasUnit = true
					break
				end
			end
			if not hasUnit then
				hero.Assignment = slotTag
				placed = true
				break
			end
		end
		if not placed then
			return false, string.format("All %d Squad Slots are full!", maxSlots)
		end
	elseif supportFacility then
		hero.Assignment = targetAssignment :: HeroAssignment
		table.insert(((profile.Facilities :: any)[supportFacility] :: FacilityData).AssignedHeroUUIDs, heroUUID)
	else
		return false, "Unknown assignment target"
	end

	if isSquad then
		OnboardingService.Report(player, "SquadDeployed")
	elseif supportFacility then
		OnboardingService.Report(player, "FacilityAssigned")
	end

	DataManager.SyncProfile(player)
	return true, string.format("Assigned %s -> %s", hero.DisplayName, hero.Assignment)
end

--============================================================================
-- 6. FACILITY INTERACTIONS (COLLECT & UPGRADE)
--============================================================================

FacilityInteractEvent.OnServerEvent:Connect(function(player: Player, action: any, param: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return
	end
	local profile = ActiveProfiles[player]
	if not profile or type(action) ~= "string" then
		return
	end

	if action == "UPGRADE_FACILITY" then
		-- Retired in Phase 4: facilities are unlocked and levelled only through the Fortress Tree.
		DataManager.SendToast(player, "Upgrade facilities in Upgrades at the Architect's Table.", "INFO")

	elseif action == "DEV_GRANT_RESOURCES" then
		-- Prototype helper so testers can also test mid/late-game features immediately if desired
		if not game:GetService("RunService"):IsStudio() then return end
		profile.Currencies.Gold += 25000
		profile.Currencies.Gems += 5000
		profile.PitMaterials.PromotionStone = (profile.PitMaterials.PromotionStone or 0) + 20
		profile.PitMaterials.SoulEssence = (profile.PitMaterials.SoulEssence or 0) + 100
		OnboardingService.UnlockAll(player)
		DataManager.SendToast(player, "[Prototype Boost] +25k Gold, +5k Gems, +20 Promotion Stones, all systems unlocked!", "SUCCESS")
		DataManager.SyncProfile(player)
	end
end)

function DataManager.GetMarketMultiplier(player: Player): number
	local profile = ActiveProfiles[player]
	if not profile or not profile.Facilities or not profile.Facilities.Market then return 1.0 end
	local market = profile.Facilities.Market
	local sumLabor = 0
	local now = os.time()
	for _, uuid in ipairs(market.AssignedHeroUUIDs) do
		local hero = profile.Heroes[uuid]
		if hero and (hero.ComaUntilTimestamp or 0) <= now then
			sumLabor += StatFormulas.GetEffectiveLabor(hero, "FACILITY_MARKET")
		end
	end
	return StatFormulas.GetMarketLootMultiplier(market.Level, sumLabor, FortressTree.PerkBonuses(profile.FortressTree))
end

function DataManager.GetTrainingMultiplier(player: Player): number
	local profile = ActiveProfiles[player]
	if not profile or not profile.Facilities or not profile.Facilities.TrainingGrounds then return 1.0 end
	local training = profile.Facilities.TrainingGrounds
	local sumLabor = 0
	local now = os.time()
	for _, uuid in ipairs(training.AssignedHeroUUIDs) do
		local hero = profile.Heroes[uuid]
		if hero and (hero.ComaUntilTimestamp or 0) <= now then
			sumLabor += StatFormulas.GetEffectiveLabor(hero, "FACILITY_TRAINING")
		end
	end
	return StatFormulas.GetTrainingCombatMultiplier(training.Level, sumLabor, FortressTree.PerkBonuses(profile.FortressTree))
end

function DataManager.RecordBiomeBossClear(player: Player, bossTier: number)
	local profile = ActiveProfiles[player]
	if not profile then return end
	DataManager.EnsureFacilities(profile)
	local currentTier = profile.HighestClearedBiomeBoss or 0
	if bossTier > currentTier then
		profile.HighestClearedBiomeBoss = bossTier
		profile.HighestClearedFloor = math.max(profile.HighestClearedFloor or 0, bossTier * 5)
		DataManager.SendToast(player, string.format("🏆 Biome Boss Milestone! Cleared Tier %d Boss (Floor %d)! Outskirts Passive Gold increased!", bossTier, bossTier * 5), "SUCCESS")
		DataManager.SyncProfile(player)
	end
end

function DataManager.GetPassiveGoldRate(player: Player): number
	local profile = ActiveProfiles[player]
	if not profile or not profile.Facilities or not profile.Facilities.GuardPost then return 0 end
	local guardPost = profile.Facilities.GuardPost
	local sumLabor = 0
	local now = os.time()
	for _, uuid in ipairs(guardPost.AssignedHeroUUIDs) do
		local hero = profile.Heroes[uuid]
		if hero and (hero.ComaUntilTimestamp or 0) <= now then
			sumLabor += StatFormulas.GetEffectiveLabor(hero, "FACILITY_GUARD_POST")
		end
	end
	local bossTier = profile.HighestClearedBiomeBoss or 0
	return StatFormulas.GetPassiveGoldRate(guardPost.Level, sumLabor, bossTier, FortressTree.PerkBonuses(profile.FortressTree))
end

-- Onboarding events reported by systems outside DataManager (tower floor clears).
function DataManager.ReportProgress(player: Player, eventName: string)
	OnboardingService.Report(player, eventName)
end

function DataManager.IsUnlocked(player: Player, key: string): boolean
	return OnboardingService.IsUnlocked(player, key)
end

function DataManager.LockedMessage(key: string): string
	return OnboardingService.LockedMessage(key)
end

OnboardingService.Init({
	GetProfile = function(player: Player) return ActiveProfiles[player] end,
	SendToast = DataManager.SendToast,
	SyncProfile = function(player: Player) DataManager.SyncProfile(player) end,
	SyncRemote = OnboardingSyncEvent,
})

FortressTreeService.Init({
	GetProfile = function(player: Player) return ActiveProfiles[player] end,
	SendToast = DataManager.SendToast,
	SyncProfile = function(player: Player) DataManager.SyncProfile(player) end,
	IsUnlocked = OnboardingService.IsUnlocked,
	Report = OnboardingService.Report,
	UnlockRemote = UnlockTreeNodeFunc,
})

--============================================================================
-- 7. PLAYER LIFECYCLE INITIALIZATION
--============================================================================

local AUTOSAVE_SECONDS = 120
local persistentPlayers: { [Player]: boolean } = {}
local releasedPlayers: { [Player]: boolean } = {}
local savesInFlight = 0 -- releases still writing; BindToClose waits for these

-- Checkpoint save for purchases and other high-value grants. Keeps the session lock.
function DataManager.SaveProfile(player: Player): boolean
	local profile = ActiveProfiles[player]
	if not profile or not persistentPlayers[player] then return false end
	return ProfilePersistence.Save(player.UserId, profile, false)
end

local function releaseProfile(player: Player)
	if releasedPlayers[player] then return end
	releasedPlayers[player] = true
	local profile = ActiveProfiles[player]
	if profile and persistentPlayers[player] then
		savesInFlight += 1
		ProfilePersistence.Save(player.UserId, profile, true)
		savesInFlight -= 1
	end
end

local function onPlayerAdded(player: Player)
	local loaded = ProfilePersistence.Load(player.UserId, function() return player.Parent == Players end)
	if not loaded.Ok then
		if player.Parent == Players then player:Kick("Could not load your save. Please rejoin. (" .. tostring(loaded.Reason) .. ")") end
		return
	end
	if player.Parent ~= Players then
		-- Left while loading: hand the lock back untouched.
		if loaded.Persistent and loaded.Data then ProfilePersistence.Save(player.UserId, loaded.Data, true) end
		return
	end

	local profile = if type(loaded.Data) == "table" then loaded.Data else createDefaultPlayerProfile()
	PitService.EnsureDefaults(profile)
	DataManager.EnsureFacilities(profile)
	ProfileMigrations.Run(profile)
	OnboardingService.EnsureState(profile)
	FortressTreeService.ApplyLevels(profile)
	ActiveProfiles[player] = profile
	persistentPlayers[player] = loaded.Persistent or nil
	releasedPlayers[player] = nil
	-- Claim the new player's record right away so the first visit survives a crash.
	if loaded.Persistent and not loaded.Data then task.spawn(DataManager.SaveProfile, player) end

	OfflineRewardService.ProcessLoginRewards(player, profile, DataManager)

	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		DataManager.SyncProfile(player)
	end)

	task.delay(0.5, function()
		if ActiveProfiles[player] then
			DataManager.SyncProfile(player)
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player: Player)
	local profile = ActiveProfiles[player]
	if profile then
		OfflineRewardService.RecordLogout(player, profile)
	end
	releaseProfile(player)
	if profile then forgeTransactions.Forget(profile) end
	pit:Forget(player)
	FortressTreeService.Forget(player)
	lastLeaderstatsWrite[player] = nil
	pendingCombatSync[player] = nil
	ActiveProfiles[player] = nil
	persistentPlayers[player] = nil
	releasedPlayers[player] = nil
end)

-- Autosave with jitter so six players do not all write on the same tick; refreshes the lock time.
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS + math.random() * 15)
		for player in persistentPlayers do
			if not releasedPlayers[player] and ActiveProfiles[player] then
				task.spawn(DataManager.SaveProfile, player)
				task.wait(1)
			end
		end
	end
end)

-- PlayerRemoving usually starts each release first, so wait on every in-flight save, not only the
-- ones started here, or the server can close before the lock is released.
game:BindToClose(function()
	for player, profile in ActiveProfiles do
		if persistentPlayers[player] and not releasedPlayers[player] then
			OfflineRewardService.RecordLogout(player, profile)
			task.spawn(releaseProfile, player)
		end
	end
	local deadline = os.clock() + 25
	repeat task.wait(0.1) until savesInFlight == 0 or os.clock() > deadline
end)

_G.DataManager = DataManager
