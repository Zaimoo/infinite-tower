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
local TowerRun = require(Shared.Util.TowerRun)
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local InventoryCapacity = require(Shared:WaitForChild("Util"):WaitForChild("InventoryCapacity"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local MirrorBanner = require(Shared:WaitForChild("Util"):WaitForChild("MirrorBanner"))
local AnvilBanner = require(Shared:WaitForChild("Util"):WaitForChild("AnvilBanner"))
local Onboarding = require(Shared:WaitForChild("Util"):WaitForChild("Onboarding"))
local OnboardingService = require(script.Parent:WaitForChild("OnboardingService"))
local FortressTreeService = require(script.Parent:WaitForChild("FortressTreeService"))
local RewardsService = require(script.Parent:WaitForChild("RewardsService"))
local RewardRules = require(Shared:WaitForChild("Util"):WaitForChild("RewardRules"))
local ProfileMigrations = require(script.Parent:WaitForChild("ProfileMigrations"))
local ProfilePersistence = require(script.Parent:WaitForChild("ProfilePersistence"))
local ForgeTransactions = require(script.Parent:WaitForChild("ForgeTransactions"))
local TowerFloorService = require(script.Parent:WaitForChild("TowerFloorService"))
local RaidConfig = require(Shared:WaitForChild("Config"):WaitForChild("RaidConfig"))
local TowerFloorConfig = require(Shared:WaitForChild("Config"):WaitForChild("TowerFloorConfig"))
local SettingsConfig = require(Shared:WaitForChild("Config"):WaitForChild("SettingsConfig"))
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

local SaveUserSettingsFunc = SyndicateRemotes:FindFirstChild("SaveUserSettings") :: RemoteFunction?
if not SaveUserSettingsFunc then
	SaveUserSettingsFunc = Instance.new("RemoteFunction")
	SaveUserSettingsFunc.Name = "SaveUserSettings"
	SaveUserSettingsFunc.Parent = SyndicateRemotes
end

local lastSettingsSave: { [Player]: number } = {}

local function applySettingsAttributes(player: Player, s: SettingsConfig.SettingsState?)
	local clean = s or SettingsConfig.DEFAULTS
	player:SetAttribute("Settings_MasterVolume", clean.Sound)
	player:SetAttribute("Settings_MusicVolume", clean.Music)
	player:SetAttribute("Settings_AmbienceVolume", clean.Ambience)
	player:SetAttribute("Settings_MuteSFX", clean.MuteSFX)
	player:SetAttribute("Settings_MuteMusic", clean.MuteMusic)
	player:SetAttribute("Settings_MuteAmbience", clean.MuteAmbience)
	player:SetAttribute("Settings_FOV", clean.FOV)
	player:SetAttribute("Settings_Brightness", clean.Brightness)
	player:SetAttribute("Settings_GlobalShadows", clean.GlobalShadows)
	player:SetAttribute("Settings_Bloom", clean.Bloom)
	player:SetAttribute("Settings_ColorFX", clean.ColorFX)
	player:SetAttribute("Settings_ShowNotifications", clean.ShowNotifications)
	player:SetAttribute("Settings_DamageNumbers", clean.DamageNumbers)
	player:SetAttribute("Settings_CompactMode", clean.CompactMode)
	player:SetAttribute("Settings_ReduceMotion", clean.ReduceMotion)
	player:SetAttribute("Settings_HighContrast", clean.HighContrast)
	player:SetAttribute("Settings_LivePreview", clean.LivePreview)
	player:SetAttribute("Settings_Scale", clean.Scale)
	player:SetAttribute("Settings_Theme", clean.Theme)
	player:SetAttribute("Settings_Font", clean.Font)
end

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
-- The Gilded Mirror's Spark: spend one banked pick on any of the five mirror heroes.
local ClaimMirrorSparkFunc = progressionRemote("ClaimMirrorSpark", "RemoteFunction") :: RemoteFunction
-- The Gilded Anvil (Tier-8 Gildforged relics): Focus pick, Spark claim, and pack reveal notification.
local SetAnvilFocusFunc = progressionRemote("SetAnvilFocus", "RemoteFunction") :: RemoteFunction
local ClaimAnvilSparkFunc = progressionRemote("ClaimAnvilSpark", "RemoteFunction") :: RemoteFunction
local AnvilRevealEvent = progressionRemote("AnvilReveal", "RemoteEvent") :: RemoteEvent

--============================================================================
-- 1. EXPORTED TYPE DEFINITIONS
--============================================================================

export type HeroArchetype = "Vanguard" | "Striker" | "Marksman" | "Berserker" | "Healer" | "Scholar"

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
	CurrentStamina: number,
	MaxStamina: number,
	ComaUntilTimestamp: number,
	IsHardAuditComa: boolean,
	Assignment: HeroAssignment,
	Locked: boolean,
	Favorite: boolean,
	OverflowXP: number,
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
}

export type PlayerProfile = {
	SchemaVersion: number,
	UnlockedResearch: { [string]: boolean }?, -- Legacy Pit compatibility only; no research UI or unlocks.
	PitMaterials: { [string]: number },
	PitRevision: number,
	PlotIndex: number,
	Raid: { LastRewardedRaid: number, BestDamage: number, Kills: number, Participations: number }?,
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
	Rewards: RewardRules.State?, -- daily / weekly / playtime claims and redeemed codes (RewardsService)
}

--============================================================================
-- 2. PROFILE CREATION & HERO FACTORY
--============================================================================

local DataManager = {}
_G.DataManager = DataManager
print("[DataManager] _G.DataManager registered at line 145")
local ActiveProfiles: { [Player]: PlayerProfile } = {}

function DataManager.ApplySettingsAttributes(player: Player, s: SettingsConfig.SettingsState?)
	applySettingsAttributes(player, s)
end

SaveUserSettingsFunc.OnServerInvoke = function(player: Player, rawSettings: any): { Success: boolean, Settings: SettingsConfig.SettingsState? }
	local profile = ActiveProfiles[player]
	if not profile then
		return { Success = false }
	end

	local now = os.clock()
	if now - (lastSettingsSave[player] or 0) < 0.25 then
		return { Success = false }
	end
	lastSettingsSave[player] = now

	local clean = SettingsConfig.Sanitize(rawSettings)
	profile.Settings = clean
	applySettingsAttributes(player, clean)

	task.spawn(function()
		DataManager.SaveProfile(player)
	end)

	return { Success = true, Settings = clean }
end

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
	-- A hero's archetype is its template's (Miner became Berserker). Re-derive it before the
	-- equip check below, or a renamed archetype would be stripped of its own weapon. Its name is
	-- the template's too: heroes save their DisplayName when summoned, so a renamed hero (Rourke
	-- became Rook) would keep the old name on cards and nameplates. Players can't rename heroes.
	for _, hero in pairs(profile.Heroes) do
		local heroSeed = HeroCatalog.Seeds[hero.TemplateId]
		if heroSeed and hero.Archetype ~= heroSeed.Archetype then
			hero.Archetype = heroSeed.Archetype :: HeroArchetype
		end
		if heroSeed and hero.DisplayName ~= heroSeed.DisplayName then
			hero.DisplayName = heroSeed.DisplayName
		end
	end

	for uuid, artifact in pairs(profile.Artifacts) do
		local seed = ArtifactCatalog.Seeds[artifact.TemplateId]
		if seed then
			artifact.Type = seed.Type
			artifact.DisplayName = seed.DisplayName
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
		CurrentStamina = 100.0,
		MaxStamina = 100.0,
		ComaUntilTimestamp = 0,
		IsHardAuditComa = false,
		Assignment = "BENCHED",
		Locked = false,
		Favorite = false,
		OverflowXP = 0,
		SynthesisHistory = { DonorsConsumed = 0, XPGained = 0, Promotions = 0 },
	}
	return uuid, hero
end

local function createDefaultPlayerProfile(): PlayerProfile
	-- Gide leads the starting squad (replacing Jenna; Han was the starter before he became Mythical).
	local gideUUID, gideHero = DataManager.CreateHeroFromSeed("hero_gide", 1.05)
	gideHero.Assignment = "SQUAD_SLOT_1"
	gideHero.Locked = true

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

	gideHero.EquippedArtifactUUID = axeUUID
	axeArt.EquippedHeroUUID = gideUUID

	catioHero.EquippedArtifactUUID = f4_UUID
	f4_Art.EquippedHeroUUID = catioUUID

	return {
		SchemaVersion = ProfileMigrations.CurrentSchema,
		PitMaterials = {
			SoulEssence = 0,
			PromotionStone = 2,
		},
		PitRevision = 0,
		PlotIndex = 1,
		Raid = { LastRewardedRaid = 0, BestDamage = 0, Kills = 0, Participations = 0 },
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
			[gideUUID] = gideHero,
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
		DeployedSquadOrder = { gideUUID },
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
		Rewards = RewardRules.NewState(),
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

function DataManager.SendToast(player: Player, message: string, colorType: string?, receipt: TowerRun.RelicReceipt?)
	SystemToastEvent:FireClient(player, message, colorType or "INFO", receipt)
end

function DataManager.BroadcastToast(message: string, colorType: string?)
	SystemToastEvent:FireAllClients(message, colorType or "ALERT")
end

-- Build a sanitized copy of profile for client UI (hiding secret directive of rented mercenary!)
function DataManager.EnsureRaidData(profile: any): any
	local raid = profile.Raid
	if type(raid) ~= "table" then
		raid = {}
		profile.Raid = raid
	end
	for _, key in { "LastRewardedRaid", "BestDamage", "Kills", "Participations" } do
		if type(raid[key]) ~= "number" or raid[key] ~= raid[key] then raid[key] = 0 end
	end
	return raid
end

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
	-- Raid bosses (docs/raid-boss-plan.md §10): idempotent payout key and raid stats. Lazy, so old profiles gain it.
	DataManager.EnsureRaidData(profile)
	-- The Gilded Mirror and Gilded Anvil Spark counters: lazy, so old profiles gain them.
	MirrorBanner.EnsureSpark(profile)
	AnvilBanner.EnsureSpark(profile)
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

	-- Mirror heroes copy the best normal hero (docs/gilded-mirror-plan.md): derived, so recomputed on every sync.
	StatFormulas.RefreshMirrorSources(profile)
	if progressionOnly and _G.CombatSimulation and _G.CombatSimulation.RefreshPlayerHeroStats then
		_G.CombatSimulation.RefreshPlayerHeroStats(player)
	end
	DataManager.UpdateSquadPower(player)
	DataManager.ApplySettingsAttributes(player, profile.Settings)
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
	local curFloorAttr = player.Character and player.Character:GetAttribute("TowerFloorId")
	floorStat.Value = if typeof(curFloorAttr) == "number" and curFloorAttr > 0 then curFloorAttr else (profile.HighestClearedFloor or 0)
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
	-- A promoted or levelled normal hero can change what every mirror hero copies: send those heroes too.
	if StatFormulas.RefreshMirrorSources(profile) then
		for uuid, hero in pairs(profile.Heroes) do
			if StatFormulas.IsMirror(hero) then changed[uuid] = hero end
		end
	end
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
	local bannerPool = (banner :: any).HeroesPoolByStar and (banner :: any).HeroesPoolByStar[tier]
	local chosenId = if bannerPool and #bannerPool > 0 then bannerPool[math.random(1, #bannerPool)] else banner.HeroesByStar[tier]
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

-- The Gilded Mirror (Robux only, granted by ShopService): no luck and no pity; the ten-pull floor and the
-- Spark come from MirrorBanner. Returns the same shape as RollSummons.
function DataManager.RollMirrorSummons(player: Player, count: number): ({ HeroInstance }, number, number, any, string, boolean)
	local profile = ActiveProfiles[player] :: PlayerProfile
	local spark = MirrorBanner.EnsureSpark(profile)
	local summonedList: { HeroInstance } = {}
	local bestTier = 0
	for _, tier in MirrorBanner.RollTiers(count, function() return math.random() end) do
		local uuid, hero = DataManager.CreateHeroFromSeed(MirrorBanner.HeroForTier(tier))
		profile.Heroes[uuid] = hero
		table.insert(summonedList, hero)
		bestTier = math.max(bestTier, tier)
	end
	if MirrorBanner.AddPulls(spark, count) > 0 then
		DataManager.SendToast(player, "Spark ready|Choose any Gilded Mirror hero in the Store", "SUCCESS")
	end
	return summonedList, bestTier, 0, HeroCatalog.MirrorBanner, "MirrorSpark", false
end

-- The Gilded Anvil (Robux only, granted by ShopService): no luck and no pity; custom Focus (40% / 12%),
-- 10-pull Focus guarantee, and 60-pull Spark come from AnvilBanner. Enforces artifact inventory cap.
function DataManager.RollAnvilSummons(player: Player, count: number): ({ ArtifactInstance }, boolean, string?)
	local profile = ActiveProfiles[player] :: PlayerProfile
	if not profile then
		return {}, false, "Profile not loaded"
	end
	if not profile.Artifacts then
		profile.Artifacts = {}
	end
	local safeCount = if count == 10 then 10 else 1
	local cap = InventoryCapacity.ArtifactCap(profile.FortressTree)
	if InventoryCapacity.ArtifactCount(profile) + safeCount > cap then
		DataManager.SendToast(player, string.format("Artifacts full|%d max · Promote or free space", cap), "WARN")
		return {}, false, "Artifact inventory full"
	end

	local spark = AnvilBanner.EnsureSpark(profile)
	local summonedList: { ArtifactInstance } = {}
	local rolledIds = AnvilBanner.Roll(safeCount, spark.Focus, function() return math.random() end)
	for _, weaponId in ipairs(rolledIds) do
		local uuid, artifact = DataManager.CreateArtifact(weaponId, 1, 8)
		profile.Artifacts[uuid] = artifact
		table.insert(summonedList, artifact)
	end
	if AnvilBanner.AddPulls(spark, safeCount) > 0 then
		DataManager.SendToast(player, "Spark ready|Choose any Gildforged weapon in the Store", "SUCCESS")
	end
	AnvilRevealEvent:FireClient(player, summonedList)
	return summonedList, true, nil
end

-- Rolls `count` heroes on a banner (no cost): pity, the 10-pull floor and God's Blessing luck all
-- apply. Used by Gem summons and by Robux summon packs (ShopService).
function DataManager.RollSummons(player: Player, bannerId: string, count: number): ({ HeroInstance }, number, number, any, string, boolean)
	if MirrorBanner.IsBanner(bannerId) then
		return DataManager.RollMirrorSummons(player, count)
	end
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
	-- The Gilded Mirror is Robux only (ShopService); it has no Gem price.
	if MirrorBanner.IsBanner(bannerId) then
		return { Success = false, Message = "The Gilded Mirror is summoned from the Store." }
	end

	local count = (pullCount == 10) and 10 or 1
	-- Heroes working in a facility are out of the backpack and don't count (InventoryCapacity).
	local heroCap = InventoryCapacity.HeroCap(profile.FortressTree)
	if InventoryCapacity.HeroCount(profile) + count > heroCap then
		DataManager.SendToast(player, string.format("Heroes full|%d max · Synthesize some", heroCap), "WARN")
		return { Success = false, Message = "Hero inventory full" }
	end

	local costBanner = if isLimitedBanner(bannerId) then HeroCatalog.LimitedBanner else HeroCatalog.PermanentBanner
	local gemCost = if count == 10 then costBanner.Cost10X else costBanner.Cost1X

	if profile.Currencies.Gems < gemCost then
		DataManager.SendToast(player, string.format("Not enough Gems|Need %d", gemCost), "WARN")
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

-- Spends one banked Spark pick on a mirror hero the player chose.
local lastSparkClaim: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player) lastSparkClaim[player] = nil end)
ClaimMirrorSparkFunc.OnServerInvoke = function(player: Player, heroId: any)
	local now = os.clock()
	if now - (lastSparkClaim[player] or -99) < 1 then
		return { Success = false, Message = "Slow down." }
	end
	lastSparkClaim[player] = now
	local profile = ActiveProfiles[player]
	if not profile then return { Success = false, Message = "Profile not loaded" } end
	if not MirrorBanner.IsSparkChoice(heroId) then return { Success = false, Message = "Choose a Gilded Mirror hero." } end
	local spark = MirrorBanner.EnsureSpark(profile)
	if spark.Selections <= 0 then
		return { Success = false, Message = string.format("Spark needs %d more pulls.", HeroCatalog.MirrorBanner.SparkPulls - spark.Pulls) }
	end
	local heroCap = InventoryCapacity.HeroCap(profile.FortressTree)
	if InventoryCapacity.HeroCount(profile) + 1 > heroCap then
		DataManager.SendToast(player, string.format("Heroes full|%d max · Synthesize some", heroCap), "WARN")
		return { Success = false, Message = "Hero inventory full" }
	end
	spark.Selections -= 1
	local uuid, hero = DataManager.CreateHeroFromSeed(heroId :: string)
	profile.Heroes[uuid] = hero
	DataManager.SendToast(player, string.format("Spark|%s joins your roster", hero.DisplayName), "SUCCESS")
	DataManager.SyncProfile(player)
	return { Success = true, Hero = hero }
end

local lastAnvilSparkClaim: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player) lastAnvilSparkClaim[player] = nil end)

SetAnvilFocusFunc.OnServerInvoke = function(player: Player, focusChoice: any)
	local profile = ActiveProfiles[player]
	if not profile then return { Success = false, Message = "Profile not loaded" } end
	local ok, resolved = AnvilBanner.SetFocus(profile, focusChoice)
	if not ok or not resolved then
		return { Success = false, Message = "Choose a valid Gildforged Focus weapon type." }
	end
	DataManager.SyncProfile(player)
	local weaponId = AnvilBanner.ResolveWeaponId(resolved)
	local seed = weaponId and ArtifactCatalog.Seeds[weaponId]
	return { Success = true, Focus = resolved, DisplayName = seed and seed.DisplayName or resolved }
end

ClaimAnvilSparkFunc.OnServerInvoke = function(player: Player, choice: any)
	local now = os.clock()
	if now - (lastAnvilSparkClaim[player] or -99) < 1 then
		return { Success = false, Message = "Slow down." }
	end
	lastAnvilSparkClaim[player] = now
	local profile = ActiveProfiles[player]
	if not profile then return { Success = false, Message = "Profile not loaded" } end
	local weaponId = AnvilBanner.ResolveWeaponId(choice)
	if not weaponId then return { Success = false, Message = "Choose a Gildforged relic." } end
	local spark = AnvilBanner.EnsureSpark(profile)
	if spark.Selections <= 0 then
		return { Success = false, Message = string.format("Spark needs %d more pulls.", AnvilBanner.SPARK_COST - spark.Pulls) }
	end
	if not profile.Artifacts then profile.Artifacts = {} end
	local artifactCap = InventoryCapacity.ArtifactCap(profile.FortressTree)
	if InventoryCapacity.ArtifactCount(profile) + 1 > artifactCap then
		DataManager.SendToast(player, string.format("Artifacts full|%d max · Promote or free space", artifactCap), "WARN")
		return { Success = false, Message = "Artifact inventory full" }
	end
	local claimed, claimedId = AnvilBanner.ClaimSpark(profile, weaponId)
	if not claimed or not claimedId then
		return { Success = false, Message = "Couldn't claim the Spark." }
	end
	local uuid, artifact = DataManager.CreateArtifact(claimedId, 1, 8)
	profile.Artifacts[uuid] = artifact
	DataManager.SendToast(player, string.format("Spark|%s forged in your armory", artifact.DisplayName), "SUCCESS")
	DataManager.SyncProfile(player)
	AnvilRevealEvent:FireClient(player, { artifact })
	return { Success = true, Artifact = artifact }
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
	SyncArtifacts = function(player: Player) DataManager.SyncProfile(player) end,
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
		local message = OnboardingService.LockedMessage("Pit", player)
		return { Success = false, Message = message, Reason = message }
	end
	local response = pit:Request(player, command, payload)
	if command == "COMMIT" and type(response) == "table" and response.Success then
		OnboardingService.Report(player, "PitUsed", response.Result and response.Result.Action)
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
	DataManager.SendToast(player, string.format("Equipped|%s on %s", artifact.DisplayName, hero.DisplayName), "SUCCESS")
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
	DataManager.SendToast(player, string.format("Unequipped|%s", hero.DisplayName), "INFO")
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

	if #artifactUUIDs > InventoryCapacity.ArtifactCap(profile.FortressTree) then
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
					DataManager.SendToast(player, string.format("Can't sell|%s is equipped", art.DisplayName), "WARN")
					return false, string.format("Cannot sell %s: weapon is equipped", art.DisplayName), 0, 0
				end
				if art.Locked then
					DataManager.SendToast(player, string.format("Can't sell|%s is locked", art.DisplayName), "WARN")
					return false, string.format("Cannot sell %s: weapon is locked", art.DisplayName), 0, 0
				end
				if ArtifactCatalog.IsGildforged(art) or (art.Rarity or 1) >= 8 then
					DataManager.SendToast(player, string.format("Can't sell|%s is Gildforged", art.DisplayName), "WARN")
					return false, string.format("Cannot sell %s: Gildforged weapons cannot be sold", art.DisplayName), 0, 0
				end
				local price = ArtifactCatalog.CalculateSellPrice(art.Rarity or 1, art.Star or 1, art.TemplateId)
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
	DataManager.SendToast(player, string.format("Sold %d|+%s Gold", soldCount, tostring(totalGold)), "SUCCESS")

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
		return false, OnboardingService.LockedMessage("Forge", player), 0, 0
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
		return false, OnboardingService.LockedMessage("Forge", player), nil
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
			if kind == "UPGRADE" then
				OnboardingService.Report(player, "ArtifactUpgraded")
			elseif kind == "EQUIP" or kind == "EQUIP_BEST" then
				OnboardingService.Report(player, "ArtifactEquipped")
			end
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
		DataManager.SendToast(player, string.format("Not enough Gold|Need %d", cost), "WARN")
		return false, string.format("Need %d Gold to Summon!", cost), nil, nil
	end

	if not profile.Artifacts then profile.Artifacts = {} end
	local artifactCap = InventoryCapacity.ArtifactCap(profile.FortressTree)
	if InventoryCapacity.ArtifactCount(profile) + count > artifactCap then
		DataManager.SendToast(player, string.format("Artifacts full|%d max · Sell some", artifactCap), "WARN")
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
	-- Onboarding: the very first roll yields a weapon a squad hero can hold, so the "equip it"
	-- lesson that follows always works. Later rolls are uniform across the six types.
	local guidedType = OnboardingService.StarterWeaponType(player)

	for pull = 1, count do
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
		local chosenType = if pull == 1 and guidedType then guidedType else archetypeTypes[math.random(1, #archetypeTypes)]
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

-- The squad is locked while the Master or the squad is in the tower or the raid arena (the arena is
-- tower floor RaidConfig.FloorId), and during a floor transition. Returns the refusal and a code the
-- Squad window uses to show it as a modal ("SQUAD_LOCKED_TOWER" / "SQUAD_LOCKED_RAID"), or nil.
local function squadLockReason(player: Player): (string?, string?)
	local state = TowerFloorService.GetState(player)
	if not state then return nil, nil end
	local floor, squadFloor = state.FloorId or 0, state.SquadFloorId or 0
	if floor == RaidConfig.FloorId or squadFloor == RaidConfig.FloorId then
		return "You can't change your squad during a raid.", "SQUAD_LOCKED_RAID"
	end
	if floor ~= 0 or squadFloor ~= 0 or state.Pending ~= nil then
		return "You can't change your squad in the tower. Return home first.", "SQUAD_LOCKED_TOWER"
	end
	return nil, nil
end

AssignHeroRoleFunc.OnServerInvoke = function(player: Player, heroUUID: any, targetAssignment: any, targetPlot: any?)
	if not validateCallerPlotOwnership(player, targetPlot) then
		return false, "Plot ownership validation failed"
	end
	local profile = ActiveProfiles[player]
	if not profile then
		return false, "Profile not loaded"
	end

	-- No squad swaps in the tower or a raid: the squad smart actions, deploying a hero, or moving a
	-- deployed hero out. Bench and facility moves for heroes outside the squad still go through.
	local lockReason, lockCode = squadLockReason(player)
	if lockReason then
		local movesSquad = heroUUID == "AUTO_SWAP_EXHAUSTED" or heroUUID == "AUTO_BEST"
		if not movesSquad and type(targetAssignment) == "string" then
			movesSquad = string.find(targetAssignment, "^SQUAD_") ~= nil
		end
		if not movesSquad and type(heroUUID) == "string" then
			local current = profile.Heroes[heroUUID]
			movesSquad = current ~= nil and string.find(current.Assignment or "", "^SQUAD_SLOT_") ~= nil
		end
		if movesSquad then
			return false, lockReason, lockCode
		end
	end

	-- Special Smart Action from Document 4 Section 2.2: "AUTO_SWAP_EXHAUSTED"
	if heroUUID == "AUTO_SWAP_EXHAUSTED" then
		if not OnboardingService.Require(player, "Squad") then -- toasts the unlock hint
			return false, OnboardingService.LockedMessage("Squad", player)
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
		DataManager.SendToast(player, string.format("Squad rotated|%d swapped", swappedCount), "SUCCESS")
		return true, "Auto-swapped exhausted heroes"
	end

	-- "AUTO_BEST": deploy the strongest ready heroes (by Squad Power) from the squad and bench.
	-- Facility workers stay at work; resting heroes are benched.
	if heroUUID == "AUTO_BEST" then
		if not OnboardingService.Require(player, "Squad") then -- toasts the unlock hint
			return false, OnboardingService.LockedMessage("Squad", player)
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
		return false, OnboardingService.LockedMessage("Squad", player)
	end
	if supportFacility then
		if not OnboardingService.Require(player, "Facilities") then -- toasts the unlock hint
			return false, OnboardingService.LockedMessage("Facilities", player)
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
		OnboardingService.Report(player, "FacilityAssigned", supportFacility)
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
		DataManager.SendToast(player, "Upgrades|Level facilities at the Architect's Table", "INFO")

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

-- Studio-only chat commands:
--   * `/summon <hero|weapon> [1-7]` grants any HeroCatalog hero or ArtifactCatalog weapon.
--   * `/weapon <id|name|archetype|gild> [1-7]` (alias `/summonweapon`) grants any weapon at 1..7★.
if game:GetService("RunService"):IsStudio() then
	local function normalizeWeaponQuery(text: string): string
		return (string.gsub(string.lower(text), "[^%w]+", ""))
	end

	local function resolveWeaponSeedId(query: string): string?
		local q = string.lower((string.gsub(query, "^%s*(.-)%s*$", "%1")))
		if q == "" then
			return nil
		end
		if ArtifactCatalog.Seeds[q] then
			return q
		end
		if ArtifactCatalog.Seeds["art_" .. q] then
			return "art_" .. q
		end
		if ArtifactCatalog.Seeds["art_gild_" .. q] then
			return "art_gild_" .. q
		end
		local byArchetype = AnvilBanner.ResolveWeaponId(string.upper(q))
		if byArchetype and ArtifactCatalog.Seeds[byArchetype] then
			return byArchetype
		end

		local qNorm = normalizeWeaponQuery(q)
		for _, id in ArtifactCatalog.AnvilOrder do
			local seed = ArtifactCatalog.Seeds[id]
			if seed and (string.lower(seed.DisplayName) == q or normalizeWeaponQuery(seed.DisplayName) == qNorm) then
				return id
			end
		end
		for _, id in ArtifactCatalog.CatalogOrder do
			local seed = ArtifactCatalog.Seeds[id]
			if seed and (string.lower(seed.DisplayName) == q or normalizeWeaponQuery(seed.DisplayName) == qNorm) then
				return id
			end
		end

		local function matchOrdered(list: { string }): string?
			for _, id in list do
				local seed = ArtifactCatalog.Seeds[id]
				if seed then
					local dnNorm = normalizeWeaponQuery(seed.DisplayName)
					local idNorm = normalizeWeaponQuery((string.gsub(id, "^art_gild_", "")))
					if string.sub(dnNorm, 1, #qNorm) == qNorm or string.sub(idNorm, 1, #qNorm) == qNorm then
						return id
					end
				end
			end
			for _, id in list do
				local seed = ArtifactCatalog.Seeds[id]
				if seed then
					local dnNorm = normalizeWeaponQuery(seed.DisplayName)
					if string.find(dnNorm, qNorm, 1, true) or string.find(string.lower(id), q, 1, true) then
						return id
					end
				end
			end
			return nil
		end

		return matchOrdered(ArtifactCatalog.AnvilOrder) or matchOrdered(ArtifactCatalog.CatalogOrder)
	end

	local function grantDevWeapons(player: Player, profile: PlayerProfile, rawArgs: string): boolean
		local trimmed = string.match(rawArgs, "^%s*(.-)%s*$") or ""
		if trimmed == "" then
			return false
		end

		local star = 1
		local query = trimmed
		local qPart, starStr = string.match(trimmed, "^(.-)%s+([1-7])$")
		if qPart and starStr then
			query = qPart
			star = tonumber(starStr) or 1
		end

		local qLower = string.lower(query)
		local seedIds: { string }
		local isBatch = qLower == "gild" or qLower == "allgild" or qLower == "anvil"
		if isBatch then
			seedIds = table.clone(ArtifactCatalog.AnvilOrder)
		else
			local resolved = resolveWeaponSeedId(query)
			if not resolved then
				return false
			end
			seedIds = { resolved }
		end

		if not profile.Artifacts then
			profile.Artifacts = {}
		end
		local artifactCap = InventoryCapacity.ArtifactCap(profile.FortressTree)
		if InventoryCapacity.ArtifactCount(profile) + #seedIds > artifactCap then
			DataManager.SendToast(player, string.format("Artifacts full|%d max · Free %d slot%s first", artifactCap, #seedIds, if #seedIds == 1 then "" else "s"), "WARN")
			return true
		end

		local names = {}
		for _, id in seedIds do
			local seed = ArtifactCatalog.Seeds[id]
			local uuid, artifact = DataManager.CreateArtifact(id, star, seed and seed.RarityTier or 1)
			profile.Artifacts[uuid] = artifact
			table.insert(names, artifact.DisplayName)
		end

		local summary = if isBatch
			then string.format("%d Gildforged weapons (%d★)", #names, star)
			else string.format("%s (%d★)", table.concat(names, ", "), star)
		DataManager.SendToast(player, "[Dev] Summoned " .. summary, "SUCCESS")
		DataManager.SyncProfile(player)
		return true
	end

	local weaponCommand = Instance.new("TextChatCommand")
	weaponCommand.Name = "DevSummonWeapon"
	weaponCommand.PrimaryAlias = "/weapon"
	weaponCommand.SecondaryAlias = "/summonweapon"
	weaponCommand.Parent = game:GetService("TextChatService")
	weaponCommand.Triggered:Connect(function(source: TextSource, message: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		local profile = player and ActiveProfiles[player]
		if not player or not profile then return end

		local rawArgs = string.match(message, "^%S+%s*(.-)%s*$") or ""
		if not grantDevWeapons(player, profile, rawArgs) then
			DataManager.SendToast(player, "Usage: /weapon <id|name|gild> [1-7], e.g. /weapon wyrmheart 7", "WARN")
		end
	end)

	local summonCommand = Instance.new("TextChatCommand")
	summonCommand.Name = "DevSummonHero"
	summonCommand.PrimaryAlias = "/summon"
	summonCommand.Parent = game:GetService("TextChatService")
	summonCommand.Triggered:Connect(function(source: TextSource, message: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		local profile = player and ActiveProfiles[player]
		if not player or not profile then return end

		local rawArgs = string.match(message, "^%S+%s*(.-)%s*$") or ""
		local arg = string.lower(string.match(rawArgs, "^(%S+)") or "")
		local seedId = if HeroCatalog.Seeds[arg] then arg else "hero_" .. arg
		if arg ~= "" and not HeroCatalog.Seeds[seedId] then
			for id, seed in HeroCatalog.Seeds do
				if string.lower(seed.DisplayName) == arg then
					seedId = id
					break
				end
			end
		end
		if arg ~= "" and not HeroCatalog.Seeds[seedId] then
			if grantDevWeapons(player, profile, rawArgs) then
				return
			end
		end
		if arg == "" or not HeroCatalog.Seeds[seedId] then
			DataManager.SendToast(player, "Usage: /summon <hero|weapon>, e.g. /summon edis or /weapon wyrmheart", "WARN")
			return
		end
		local heroCap = InventoryCapacity.HeroCap(profile.FortressTree)
		if InventoryCapacity.HeroCount(profile) + 1 > heroCap then
			DataManager.SendToast(player, string.format("Heroes full|%d max · Synthesize some", heroCap), "WARN")
			return
		end

		local uuid, hero = DataManager.CreateHeroFromSeed(seedId)
		profile.Heroes[uuid] = hero
		DataManager.SendToast(player, string.format("[Dev] Summoned %s", hero.DisplayName), "SUCCESS")
		DataManager.SyncProfile(player)
	end)

	-- Studio-only chat command: `/mirrorpull [1|10]` runs Gilded Mirror pulls as if a Robux pack was bought
	-- (ProductIds are 0 until the products exist), so the ten-pull floor and the Spark can be tested.
	local mirrorCommand = Instance.new("TextChatCommand")
	mirrorCommand.Name = "DevMirrorPull"
	mirrorCommand.PrimaryAlias = "/mirrorpull"
	mirrorCommand.Parent = game:GetService("TextChatService")
	mirrorCommand.Triggered:Connect(function(source: TextSource, message: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		local profile = player and ActiveProfiles[player]
		if not player or not profile then return end
		local count = if string.match(message, "^%S+%s+10") then 10 else 1
		local summoned = DataManager.RollMirrorSummons(player, count)
		local names = {}
		for _, hero in summoned do table.insert(names, hero.DisplayName) end
		local spark = MirrorBanner.EnsureSpark(profile)
		DataManager.SendToast(player, string.format("[Dev] %s · Spark %d/%d (%d to pick)", table.concat(names, ", "),
			spark.Pulls, HeroCatalog.MirrorBanner.SparkPulls, spark.Selections), "SUCCESS")
		DataManager.SyncProfile(player)
	end)

	-- Studio-only chat command: `/anvilpull [1|10] [focus]` simulates Gilded Anvil Robux pack pulls.
	local anvilCommand = Instance.new("TextChatCommand")
	anvilCommand.Name = "DevAnvilPull"
	anvilCommand.PrimaryAlias = "/anvilpull"
	anvilCommand.Parent = game:GetService("TextChatService")
	anvilCommand.Triggered:Connect(function(source: TextSource, message: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		local profile = player and ActiveProfiles[player]
		if not player or not profile then return end
		local count = if string.match(message, "^%S+%s+10") then 10 else 1
		local focusArg = string.match(message, "^%S+%s+%d+%s+(%S+)") or string.match(message, "^%S+%s+(%a%S+)")
		if focusArg then
			AnvilBanner.SetFocus(profile, string.upper(focusArg))
		end
		local summoned, ok, err = DataManager.RollAnvilSummons(player, count)
		if not ok then
			DataManager.SendToast(player, "[Dev] " .. tostring(err), "WARN")
			return
		end
		local names = {}
		for _, art in summoned do table.insert(names, art.DisplayName) end
		local spark = AnvilBanner.EnsureSpark(profile)
		DataManager.SendToast(player, string.format("[Dev] %s · Focus %s · Spark %d/%d (%d to pick)", table.concat(names, ", "),
			spark.Focus, spark.Pulls, AnvilBanner.SPARK_COST, spark.Selections), "SUCCESS")
		DataManager.SyncProfile(player)
	end)

	-- Studio-only chat command: `/floors [n]` sets the caller's tower progress so floors 1..n are open
	-- (floors before n count as cleared, along with their Biome Bosses). No argument unlocks all 50.
	-- It sets progress exactly, so a lower n locks floors again for testing early-game flows.
	local floorCount = TowerFloorConfig.FloorCount
	local floorsCommand = Instance.new("TextChatCommand")
	floorsCommand.Name = "DevUnlockFloors"
	floorsCommand.PrimaryAlias = "/floors"
	floorsCommand.SecondaryAlias = "/unlockfloors"
	floorsCommand.Parent = game:GetService("TextChatService")
	floorsCommand.Triggered:Connect(function(source: TextSource, message: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		local profile = player and ActiveProfiles[player]
		if not player or not profile then return end

		local arg = string.match(message, "^%S+%s+(%S+)")
		local target = if arg then tonumber(arg) else floorCount
		if not target or target ~= target or target < 1 or target > floorCount or target % 1 ~= 0 then
			DataManager.SendToast(player, string.format("Usage: /floors [1-%d], e.g. /floors 25", floorCount), "WARN")
			return
		end

		local cleared = target - 1
		profile.MaxFloorReached = target
		profile.HighestClearedFloor = cleared
		profile.HighestClearedBiomeBoss = cleared // 5
		DataManager.SendToast(player, string.format("[Dev] Floors 1-%d unlocked", target), "SUCCESS")
		DataManager.SyncProfile(player)
	end)
end

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

-- Gold multiplier from Roblox friends in this server (GDD §4.8); stacks with the Market.
function DataManager.GetFriendBoostMultiplier(player: Player): number
	return RewardsService.GetFriendBoostMultiplier(player)
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
		DataManager.SendToast(player, string.format("Biome boss down|Floor %d · Guard Post Gold up", bossTier * 5), "SUCCESS")
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
function DataManager.ReportProgress(player: Player, eventName: string, detail: (string | number)?)
	OnboardingService.Report(player, eventName, detail)
end

function DataManager.IsUnlocked(player: Player, key: string): boolean
	return OnboardingService.IsUnlocked(player, key)
end

function DataManager.LockedMessage(key: string, player: Player?): string
	return OnboardingService.LockedMessage(key, player)
end

OnboardingService.Init({
	GetProfile = function(player: Player) return ActiveProfiles[player] end,
	SendToast = DataManager.SendToast,
	SyncProfile = function(player: Player) DataManager.SyncProfile(player) end,
	SyncRemote = OnboardingSyncEvent,
	PitLesson = function(profile: any, promotion: boolean, synthesis: boolean): string?
		if not promotion and not synthesis then return nil end
		local donorId: string? = nil
		if synthesis then
			for id, hero in profile.Heroes do
				if pit:DonorStatus(profile, hero).EligibleDonor then donorId = id; break end
			end
		end
		for id, hero in profile.Heroes do
			if not string.match(hero.Assignment or "", "^SQUAD_SLOT_%d+$") or not pit:RecipientStatus(profile, hero).Eligible then continue end
			if promotion and hero.Level >= StatFormulas.GetMaxLevel(hero.Stars) then
				local preview = pit:Build(profile, { Action = "PROMOTION", Recipient = id })
				if preview.CanCommit then return "Promotion" end
			elseif donorId and hero.Level < StatFormulas.GetMaxLevel(hero.Stars) then
				local preview = pit:Build(profile, { Action = "SYNTHESIS", Recipient = id, Donors = { donorId } })
				if preview.CanCommit then return "Synthesis" end
			end
		end
		return nil
	end,
})

FortressTreeService.Init({
	GetProfile = function(player: Player) return ActiveProfiles[player] end,
	SendToast = DataManager.SendToast,
	SyncProfile = function(player: Player) DataManager.SyncProfile(player) end,
	IsUnlocked = OnboardingService.IsUnlocked,
	Report = OnboardingService.Report,
	UnlockRemote = UnlockTreeNodeFunc,
})

RewardsService.Init({
	GetProfile = function(player: Player) return ActiveProfiles[player] end,
	SendToast = DataManager.SendToast,
	SyncProfile = function(player: Player) DataManager.SyncProfile(player, true) end,
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
	RewardsService.EnsureState(profile)
	ActiveProfiles[player] = profile
	persistentPlayers[player] = loaded.Persistent or nil
	releasedPlayers[player] = nil
	DataManager.ApplySettingsAttributes(player, profile.Settings)
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
	lastSettingsSave[player] = nil
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
