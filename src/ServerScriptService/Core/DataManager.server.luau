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
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))

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

local RequestUpgradeRarityFunc = ArtifactRemotes:FindFirstChild("RequestUpgradeRarity") :: RemoteFunction?
if not RequestUpgradeRarityFunc then
	RequestUpgradeRarityFunc = Instance.new("RemoteFunction")
	RequestUpgradeRarityFunc.Name = "RequestUpgradeRarity"
	RequestUpgradeRarityFunc.Parent = ArtifactRemotes
end

local RequestCraftArtifactFunc = ArtifactRemotes:FindFirstChild("RequestCraftArtifact") :: RemoteFunction?
if not RequestCraftArtifactFunc then
	RequestCraftArtifactFunc = Instance.new("RemoteFunction")
	RequestCraftArtifactFunc.Name = "RequestCraftArtifact"
	RequestCraftArtifactFunc.Parent = ArtifactRemotes
end

local RequestUpgradeArtifactFunc = ArtifactRemotes:FindFirstChild("RequestUpgradeArtifact") :: RemoteFunction?
if not RequestUpgradeArtifactFunc then
	RequestUpgradeArtifactFunc = Instance.new("RemoteFunction")
	RequestUpgradeArtifactFunc.Name = "RequestUpgradeArtifact"
	RequestUpgradeArtifactFunc.Parent = ArtifactRemotes
end

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
	| "FACILITY_CONDUIT"
	| "FACILITY_INFIRMARY"

export type MimicChestMode = "TRUE_STATE" | "FOOLS_GOLD" | "VEIL_OF_POVERTY"

export type HeroInstance = {
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Archetype: HeroArchetype,
	Stars: number,
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
	Level: number,
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
	Honor: number,
	RogueUntilTimestamp: number,
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
	BossPity: number,
	RiftLuresOwned: number,
	Heroes: { [string]: HeroInstance },
	DeployedSquadOrder: { string },
	Artifacts: { [string]: ArtifactInstance },
	Facilities: {
		ManaConduit: FacilityData,
		Infirmary: FacilityData,
	},
	Social: SocialProfile,
}

--============================================================================
-- 2. PROFILE CREATION & HERO FACTORY
--============================================================================

local DataManager = {}
_G.DataManager = DataManager
print("[DataManager] _G.DataManager registered at line 145")
local ActiveProfiles: { [Player]: PlayerProfile } = {}

local function createDefaultFacility(): FacilityData
	return {
		Level = 1,
		AssignedHeroUUIDs = {},
		UncollectedOutput = 0,
		BlessedUntil = 0,
		LeechedUntil = 0,
		LeechVisitorUserId = nil,
		LastRuneTimestamp = 0,
		LastRuneWasLeech = false,
	}
end

function DataManager.CreateArtifact(templateId: string, star: number?, rarity: number?): (string, ArtifactInstance)
	local seed = ArtifactCatalog.Seeds[templateId] or ArtifactCatalog.Seeds.art_hunters_shortbow
	local uuid = "art_" .. string.gsub(HttpService:GenerateGUID(false), "-", ""):sub(1, 10)
	local artifact: ArtifactInstance = {
		UUID = uuid,
		TemplateId = seed.TemplateId,
		DisplayName = seed.DisplayName,
		Type = seed.Type,
		Star = star or seed.DefaultStar,
		Rarity = rarity or 1,
		Level = 1,
		EquippedHeroUUID = nil,
		Locked = false,
	}
	return uuid, artifact
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
		Stars = seed.BaseStar,
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
		ImprintCapacity = math.ceil(seed.BaseStar / 2),
		SynthesisHistory = { DonorsConsumed = 0, XPGained = 0, ImprintsPerformed = 0, Promotions = 0 },
	}
	return uuid, hero
end

local function createDefaultPlayerProfile(): PlayerProfile
	local hanUUID, hanHero = DataManager.CreateHeroFromSeed("hero_han", 1.05)
	hanHero.Assignment = "SQUAD_SLOT_1"
	hanHero.Locked = true

	local jennaUUID, jennaHero = DataManager.CreateHeroFromSeed("hero_jenna", 1.00)
	jennaHero.Assignment = "SQUAD_SLOT_2"

	local catioUUID, catioHero = DataManager.CreateHeroFromSeed("hero_catio", 1.02)
	catioHero.Assignment = "FACILITY_CONDUIT"

	local conduit = createDefaultFacility()
	conduit.AssignedHeroUUIDs = { catioUUID }

	-- Grant 1★ starter artifacts equipped to matching starting heroes
	local bowUUID, bowArt = DataManager.CreateArtifact("art_hunters_shortbow", 1, 1)
	local swordUUID, swordArt = DataManager.CreateArtifact("art_iron_broadsword", 1, 1)
	local axeUUID, axeArt = DataManager.CreateArtifact("art_miner_pickaxe", 1, 1)

	-- Additional starter artifacts for forge crafting and fodder testing
	local riftUUID, riftArt = DataManager.CreateArtifact("art_blade_of_the_rift", 3, 1)
	riftArt.Level = 4 -- Starts at +4 for immediate mockup parity testing!
	local f1_UUID, f1_Art = DataManager.CreateArtifact("art_iron_broadsword", 1, 1)
	local f2_UUID, f2_Art = DataManager.CreateArtifact("art_rusty_daggers", 1, 1)
	local f3_UUID, f3_Art = DataManager.CreateArtifact("art_hunters_shortbow", 1, 1)
	local f4_UUID, f4_Art = DataManager.CreateArtifact("art_miner_pickaxe", 1, 1)
	local f5_UUID, f5_Art = DataManager.CreateArtifact("art_novice_tome", 1, 1)

	jennaHero.EquippedArtifactUUID = bowUUID
	bowArt.EquippedHeroUUID = jennaUUID

	hanHero.EquippedArtifactUUID = swordUUID
	swordArt.EquippedHeroUUID = hanUUID

	catioHero.EquippedArtifactUUID = axeUUID
	axeArt.EquippedHeroUUID = catioUUID

	return {
		SchemaVersion = 2,
		PitMaterials = {
			SoulEssence = 0,
			PromotionStone = 0,
			ImprintCatalyst = 0,
			IronGear = 25,
			RiftOrb = 10,
			AegisGem = 8,
			StarDust = 35,
			VoidPowder = 15,
		},
		PitRevision = 0,
		PlotIndex = 1,
		Currencies = {
			Gold = 500,
			Gems = 300, -- 3 immediate Gacha pulls during onboarding (Doc 3 Section 5.1)
		},
		BossPity = 0,
		RiftLuresOwned = 0,
		Heroes = {
			[hanUUID] = hanHero,
			[jennaUUID] = jennaHero,
			[catioUUID] = catioHero,
		},
		Artifacts = {
			[bowUUID] = bowArt,
			[swordUUID] = swordArt,
			[axeUUID] = axeArt,
			[riftUUID] = riftArt,
			[f1_UUID] = f1_Art,
			[f2_UUID] = f2_Art,
			[f3_UUID] = f3_Art,
			[f4_UUID] = f4_Art,
			[f5_UUID] = f5_Art,
		},
		DeployedSquadOrder = { hanUUID, jennaUUID },
		Facilities = {
			ManaConduit = conduit,
			Infirmary = createDefaultFacility(),
		},
		Social = {
			Honor = 0,
			RogueUntilTimestamp = 0,
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
	if profile and profile.PitMaterials then
		if profile.PitMaterials.IronGear == nil then profile.PitMaterials.IronGear = 25 end
		if profile.PitMaterials.RiftOrb == nil then profile.PitMaterials.RiftOrb = 10 end
		if profile.PitMaterials.AegisGem == nil then profile.PitMaterials.AegisGem = 8 end
		if profile.PitMaterials.StarDust == nil then profile.PitMaterials.StarDust = 35 end
		if profile.PitMaterials.VoidPowder == nil then profile.PitMaterials.VoidPowder = 15 end
	end
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
		local sUUID, sArt = DataManager.CreateArtifact("art_iron_broadsword", 1, 1)
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
	ProfileDeltaSyncEvent:FireClient(player, profile)
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
	ProfileDeltaSyncEvent:FireClient(player, { _PitDelta = true, Heroes = changed, Removed = removed,
		Currencies = profile.Currencies, PitMaterials = profile.PitMaterials, PitRevision = profile.PitRevision,
		UnlockedResearch = profile.UnlockedResearch })
end

function DataManager.ApplyCollisionGroup(player: Player)
	local profile = ActiveProfiles[player]
	local char = player.Character
	if not profile or not char then
		return
	end
	local groupName = "UnlockedRing2"
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("BasePart") then
			pcall(function()
				desc.CollisionGroup = groupName
			end)
		end
	end
end

function DataManager.AdjustHonor(player: Player, delta: number, markBetrayalRogue: boolean?)
	local profile = ActiveProfiles[player]
	if not profile then
		return
	end
	profile.Social.Honor = math.clamp(profile.Social.Honor + delta, -100, 100)
	if markBetrayalRogue then
		profile.Social.RogueUntilTimestamp = os.time() + 300 -- 5 minutes
		profile.Social.LastShatterTimestamp = os.time()
		profile.Social.Stats.PactsBetrayed += 1
	end
	if player.Character then
		player.Character:SetAttribute("Honor", profile.Social.Honor)
		player.Character:SetAttribute("IsRogue", DataManager.IsPlayerRogue(player))
	end
	DataManager.SyncProfile(player)
end

function DataManager.IsPlayerRogue(player: Player): boolean
	local profile = ActiveProfiles[player]
	if not profile then
		return false
	end
	return (profile.Social.Honor <= -30) or (os.time() < profile.Social.RogueUntilTimestamp)
end

function DataManager.MaxSquadSlots(_profile: PlayerProfile): number
	return 5
end

--============================================================================
-- 4. GACHA SUMMONING, THE PIT SYNTHESIS & STAR PROMOTION
--============================================================================

local function rollGachaHero(): (string, HeroInstance)
	local roll = math.random()
	local star = 1
	if roll <= 0.05 then
		star = 3 -- 5% 3★ Epic
	elseif roll <= 0.30 then
		star = 2 -- 25% 2★ Rare
	else
		star = 1 -- 70% 1★ Common
	end

	local pool = HeroCatalog.PoolByStar[star] or HeroCatalog.PoolByStar[1]
	local chosenId = pool[math.random(1, #pool)]
	return DataManager.CreateHeroFromSeed(chosenId)
end

RequestSummonFunc.OnServerInvoke = function(player: Player, pullCount: any)
	local profile = ActiveProfiles[player]
	if not profile then
		return { Success = false, Message = "Profile not loaded" }
	end

	local count = (pullCount == 10) and 10 or 1
	local gemCost = (count == 10) and 900 or 100

	if profile.Currencies.Gems < gemCost then
		DataManager.SendToast(player, string.format("Need %d Gems to Summon! (Collect from Mana Conduit)", gemCost), "WARN")
		return { Success = false, Message = "Insufficient Gems" }
	end

	profile.Currencies.Gems -= gemCost
	local summonedList: { HeroInstance } = {}

	for _ = 1, count do
		local uuid, hero = rollGachaHero()
		profile.Heroes[uuid] = hero
		table.insert(summonedList, hero)
	end

	DataManager.SyncProfile(player)
	local names = {}
	for _, h in ipairs(summonedList) do
		table.insert(names, string.format("%s (%d★)", h.DisplayName, h.Stars))
	end
	DataManager.SendToast(player, "Summoned: " .. table.concat(names, ", "), "SUCCESS")
	return { Success = true, Summoned = summonedList }
end

-- Legacy endpoints cannot bypass confirmed previews.
function DataManager.SynthesizeHeroes(_player: Player, _targetUUID: string, _fodderUUIDs: { string }): (boolean, string)
	return false, "Use the Synthesis chamber to synthesize heroes."
end
function DataManager.PromoteHeroStar(_player: Player, _targetUUID: string, _fodderUUIDs: { string }): (boolean, string)
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
(PitRequestFunc :: RemoteFunction).OnServerInvoke = function(player: Player, command: any, payload: any)
	return pit:Request(player, command, payload)
end


--============================================================================
-- ARTIFACT & WEAPON MANAGEMENT (EQUIP, UNEQUIP & BLACKSMITH UPGRADE)
--============================================================================

function DataManager.GetArtifacts(player: Player): { [string]: ArtifactInstance }
	local profile = ActiveProfiles[player]
	if not profile then return {} end
	if not profile.Artifacts then profile.Artifacts = {} end
	if profile and profile.PitMaterials then
		if profile.PitMaterials.IronGear == nil then profile.PitMaterials.IronGear = 25 end
		if profile.PitMaterials.RiftOrb == nil then profile.PitMaterials.RiftOrb = 10 end
		if profile.PitMaterials.AegisGem == nil then profile.PitMaterials.AegisGem = 8 end
		if profile.PitMaterials.StarDust == nil then profile.PitMaterials.StarDust = 35 end
		if profile.PitMaterials.VoidPowder == nil then profile.PitMaterials.VoidPowder = 15 end
	end
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

function DataManager.UpgradeArtifactRarity(player: Player, artifactUUID: string): (boolean, string?, number?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded", nil end

	local artifact = profile.Artifacts and profile.Artifacts[artifactUUID]
	if not artifact then return false, "Artifact not found", nil end

	if artifact.Rarity >= 16 then
		return false, string.format("%s is already at Maximum Rarity (Origin)!", artifact.DisplayName), artifact.Rarity
	end

	local cost = ArtifactCatalog.GetUpgradeCost(artifact.Rarity)
	if not cost then return false, "Cannot upgrade further", artifact.Rarity end

	if profile.Currencies.Gold < cost.Gold then
		return false, string.format("Need %d Gold to upgrade to %s! (Have: %d)", cost.Gold, ArtifactCatalog.GetRarityInfo(artifact.Rarity + 1).Name, profile.Currencies.Gold), artifact.Rarity
	end

	if cost.Gems > 0 and profile.Currencies.Gems < cost.Gems then
		return false, string.format("Need %d Gems to upgrade to %s! (Have: %d)", cost.Gems, ArtifactCatalog.GetRarityInfo(artifact.Rarity + 1).Name, profile.Currencies.Gems), artifact.Rarity
	end

	-- Deduct cost
	profile.Currencies.Gold -= cost.Gold
	if cost.Gems > 0 then
		profile.Currencies.Gems -= cost.Gems
	end

	artifact.Rarity += 1
	local newRarityInfo = ArtifactCatalog.GetRarityInfo(artifact.Rarity)

	DataManager.SyncProfile(player)
	DataManager.SendToast(player, string.format("⚒️ FORGE SUCCESS! %s upgraded to %s (%0.2fx Stats)!", artifact.DisplayName, newRarityInfo.Name, newRarityInfo.Multiplier), "SUCCESS")
	return true, string.format("Upgraded %s to %s!", artifact.DisplayName, newRarityInfo.Name), artifact.Rarity
end

RequestEquipArtifactFunc.OnServerInvoke = function(player: Player, heroUUID: any, artifactUUID: any)
	if type(heroUUID) ~= "string" or type(artifactUUID) ~= "string" then
		return false, "Invalid parameters"
	end
	return DataManager.EquipArtifact(player, heroUUID, artifactUUID)
end

RequestUnequipArtifactFunc.OnServerInvoke = function(player: Player, heroUUID: any)
	if type(heroUUID) ~= "string" then
		return false, "Invalid parameters"
	end
	return DataManager.UnequipArtifact(player, heroUUID)
end

RequestUpgradeRarityFunc.OnServerInvoke = function(player: Player, artifactUUID: any)
	if type(artifactUUID) ~= "string" then
		return false, "Invalid parameters", nil
	end
	return DataManager.UpgradeArtifactRarity(player, artifactUUID)
end

function DataManager.CraftArtifact(player: Player, templateId: string): (boolean, string?, any?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded", nil end

	local seed = ArtifactCatalog.Seeds[templateId]
	if not seed then
		return false, string.format("Unknown artifact recipe: %s", tostring(templateId)), nil
	end

	if not seed.CraftCost then
		return false, string.format("%s cannot be crafted at the Forge.", seed.DisplayName), nil
	end

	if not profile.PitMaterials then profile.PitMaterials = {} end

	-- Validate material requirements
	for matId, reqQty in pairs(seed.CraftCost) do
		local haveQty = profile.PitMaterials[matId] or 0
		if haveQty < reqQty then
			local matInfo = ArtifactCatalog.CraftingMaterials[matId]
			local matName = matInfo and matInfo.Name or matId
			return false, string.format("Need %d %s to craft %s (Have: %d)!", reqQty, matName, seed.DisplayName, haveQty), nil
		end
	end

	-- Deduct materials
	for matId, reqQty in pairs(seed.CraftCost) do
		profile.PitMaterials[matId] = math.max(0, (profile.PitMaterials[matId] or 0) - reqQty)
	end

	-- Create new artifact instance at enhancement level 0
	local uuid, artifact = DataManager.CreateArtifact(templateId, seed.DefaultStar or 1, 1)
	artifact.Level = 0

	if not profile.Artifacts then profile.Artifacts = {} end
	profile.Artifacts[uuid] = artifact

	DataManager.SyncProfile(player)
	DataManager.SendToast(player, string.format("⚒️ FORGE SUCCESS! Crafted %s!", artifact.DisplayName), "SUCCESS")
	return true, string.format("Crafted %s!", artifact.DisplayName), artifact
end

function DataManager.UpgradeArtifact(player: Player, targetUUID: string, fodderUUIDs: { any }): (boolean, string?, number?)
	local profile = ActiveProfiles[player]
	if not profile then return false, "Profile not loaded", nil end

	local target = profile.Artifacts and profile.Artifacts[targetUUID]
	if not target then return false, "Target artifact not found", nil end

	local currentLevel = target.Level or 0
	if currentLevel >= ArtifactCatalog.MaxEnhancementLevel then
		return false, string.format("%s is already at Maximum Enhancement (+%d)!", target.DisplayName, ArtifactCatalog.MaxEnhancementLevel), currentLevel
	end

	if type(fodderUUIDs) ~= "table" or #fodderUUIDs == 0 then
		return false, "No fodder artifacts selected for upgrade", currentLevel
	end

	if #fodderUUIDs > 5 then
		return false, "Cannot select more than 5 fodder artifacts at once", currentLevel
	end

	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentLevel)
	if #fodderUUIDs < reqFodder then
		return false, string.format("Enhancing to +%d requires %d fodder artifacts (Selected: %d)!", currentLevel + 1, reqFodder, #fodderUUIDs), currentLevel
	end

	-- Validate every fodder artifact
	local seen: { [string]: boolean } = {}
	for _, fUUID in ipairs(fodderUUIDs) do
		if type(fUUID) ~= "string" then
			return false, "Invalid fodder UUID", currentLevel
		end
		if fUUID == targetUUID then
			return false, "Cannot use target artifact as its own fodder", currentLevel
		end
		if seen[fUUID] then
			return false, "Duplicate fodder artifact selected", currentLevel
		end
		seen[fUUID] = true

		local fodder = profile.Artifacts[fUUID]
		if not fodder then
			return false, "Fodder artifact not found in inventory", currentLevel
		end
		if fodder.EquippedHeroUUID then
			return false, string.format("Cannot consume equipped artifact: %s!", fodder.DisplayName), currentLevel
		end
		if fodder.Locked then
			return false, string.format("Cannot consume locked artifact: %s!", fodder.DisplayName), currentLevel
		end
	end

	-- Consume fodder artifacts
	for _, fUUID in ipairs(fodderUUIDs) do
		profile.Artifacts[fUUID] = nil
	end

	target.Level = currentLevel + 1

	DataManager.SyncProfile(player)
	DataManager.SendToast(player, string.format("✨ ENHANCEMENT SUCCESS! %s is now +%d!", target.DisplayName, target.Level), "SUCCESS")
	return true, string.format("Upgraded %s to +%d!", target.DisplayName, target.Level), target.Level
end

RequestCraftArtifactFunc.OnServerInvoke = function(player: Player, templateId: any)
	if type(templateId) ~= "string" then
		return false, "Invalid parameters", nil
	end
	return DataManager.CraftArtifact(player, templateId)
end

RequestUpgradeArtifactFunc.OnServerInvoke = function(player: Player, targetUUID: any, fodderUUIDs: any)
	if type(targetUUID) ~= "string" or type(fodderUUIDs) ~= "table" then
		return false, "Invalid parameters", nil
	end
	return DataManager.UpgradeArtifact(player, targetUUID, fodderUUIDs)
end

--============================================================================
-- 5. HERO ASSIGNMENT (SQUAD, FACILITIES, BENCH & AUTO-SWAP EXHAUSTED)
--============================================================================

local function removeUUIDFromFacilities(profile: PlayerProfile, uuid: string)
	for _, fac in pairs(profile.Facilities) do
		for i = #fac.AssignedHeroUUIDs, 1, -1 do
			if fac.AssignedHeroUUIDs[i] == uuid then
				table.remove(fac.AssignedHeroUUIDs, i)
			end
		end
	end
end

AssignHeroRoleFunc.OnServerInvoke = function(player: Player, heroUUID: any, targetAssignment: any)
	local profile = ActiveProfiles[player]
	if not profile then
		return false, "Profile not loaded"
	end

	-- Special Smart Action from Document 4 Section 2.2: "AUTO_SWAP_EXHAUSTED"
	if heroUUID == "AUTO_SWAP_EXHAUSTED" then
		local maxSlots = DataManager.MaxSquadSlots(profile)
		local swappedCount = 0

		-- 1. Move any deployed hero with Stamina < 25% into Infirmary
		for _, h in pairs(profile.Heroes) do
			if string.find(h.Assignment, "^SQUAD_SLOT_") and h.CurrentStamina < 25 then
				h.Assignment = "FACILITY_INFIRMARY"
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
					if h.Assignment == "BENCHED" and h.CurrentStamina >= 50 and h.ComaUntilTimestamp <= os.time() then
						local _, _, dps = StatFormulas.GetEffectiveCombatStats(h, false, false)
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

	if type(heroUUID) ~= "string" or type(targetAssignment) ~= "string" then
		return false, "Invalid parameters"
	end

	local hero = profile.Heroes[heroUUID]
	if not hero then
		return false, "Hero not found"
	end

	if hero.ComaUntilTimestamp > os.time() and targetAssignment ~= "FACILITY_INFIRMARY" and targetAssignment ~= "BENCHED" then
		return false, "Hero is in a Coma and must recover in The Infirmary!"
	end

	removeUUIDFromFacilities(profile, heroUUID)

	if targetAssignment == "BENCHED" then
		hero.Assignment = "BENCHED"
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
	elseif targetAssignment == "FACILITY_CONDUIT" or targetAssignment == "FACILITY_INFIRMARY" then
		local facKey = if targetAssignment == "FACILITY_CONDUIT" then "ManaConduit" else "Infirmary"
		local facData = (profile.Facilities :: any)[facKey] :: FacilityData
		local cfg = (FacilityConfig.UpgradeTable :: any)[facKey][facData.Level]
		local maxWorkers = cfg and cfg.MaxWorkers or 1

		-- Note: Infirmary also holds resting/Coma heroes beyond healer worker slots
		if targetAssignment ~= "FACILITY_INFIRMARY" and #facData.AssignedHeroUUIDs >= maxWorkers then
			return false, string.format("%s Lv.%d only has %d Worker Slot(s)! Upgrade facility for more.", facKey, facData.Level, maxWorkers)
		end
		hero.Assignment = targetAssignment :: HeroAssignment
		if #facData.AssignedHeroUUIDs < maxWorkers then
			table.insert(facData.AssignedHeroUUIDs, heroUUID)
		end
	else
		return false, "Unknown assignment target"
	end

	DataManager.SyncProfile(player)
	return true, string.format("Assigned %s -> %s", hero.DisplayName, hero.Assignment)
end

--============================================================================
-- 6. FACILITY INTERACTIONS (COLLECT & UPGRADE)
--============================================================================

FacilityInteractEvent.OnServerEvent:Connect(function(player: Player, action: any, param: any)
	local profile = ActiveProfiles[player]
	if not profile or type(action) ~= "string" then
		return
	end

	if action == "COLLECT_CONDUIT" then
		local amt = math.floor(profile.Facilities.ManaConduit.UncollectedOutput)
		if amt > 0 then
			profile.Facilities.ManaConduit.UncollectedOutput -= amt
			-- Check Garnished Gem Debt from Parasite Audit Soul fine
			if profile.Social.GarnishedGemDebt > 0 then
				local seized = math.min(amt, profile.Social.GarnishedGemDebt)
				amt -= seized
				profile.Social.GarnishedGemDebt -= seized
			end
			profile.Currencies.Gems += amt
			DataManager.SendToast(player, string.format("Collected +%d Gems from Mana Conduit!", amt), "SUCCESS")
			DataManager.SyncProfile(player)
		else
			DataManager.SendToast(player, "Mana Conduit Chest is empty right now.", "INFO")
		end

	elseif action == "UPGRADE_FACILITY" and type(param) == "string" then
		local facData = (profile.Facilities :: any)[param] :: FacilityData?
		local upgTable = (FacilityConfig.UpgradeTable :: any)[param]
		if not facData or not upgTable then
			return
		end
		local nextLevel = facData.Level + 1
		local nextCfg = upgTable[nextLevel]
		if not nextCfg then
			DataManager.SendToast(player, param .. " is already at Max Level (Lv.5)!", "INFO")
			return
		end
		if profile.Currencies.Gold < nextCfg.Gold then
			DataManager.SendToast(player, string.format("Need %d Gold to upgrade %s to Lv.%d!", nextCfg.Gold, param, nextLevel), "WARN")
			return
		end
		profile.Currencies.Gold -= nextCfg.Gold
		facData.Level = nextLevel
		DataManager.SendToast(player, string.format("Upgraded %s to Level %d!", param, nextLevel), "SUCCESS")
		DataManager.SyncProfile(player)

	elseif action == "DEV_GRANT_RESOURCES" then
		-- Prototype helper so testers can also test mid/late-game features immediately if desired
		if not game:GetService("RunService"):IsStudio() then return end
		profile.Currencies.Gold += 25000
		profile.Currencies.Gems += 1800
		profile.PitMaterials.PromotionStone = (profile.PitMaterials.PromotionStone or 0) + 20
		profile.PitMaterials.SoulEssence = (profile.PitMaterials.SoulEssence or 0) + 100
		DataManager.SendToast(player, "[Prototype Boost] +25k Gold, +1.8k Gems, +20 Promotion Stones!", "SUCCESS")
		DataManager.SyncProfile(player)
	end
end)

--============================================================================
-- 7. PLAYER LIFECYCLE INITIALIZATION
--============================================================================

local function onPlayerAdded(player: Player)
	local profile = createDefaultPlayerProfile()
	PitService.EnsureDefaults(profile)
	ActiveProfiles[player] = profile

	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		char:SetAttribute("Honor", profile.Social.Honor)
		char:SetAttribute("IsRogue", DataManager.IsPlayerRogue(player))
		DataManager.ApplyCollisionGroup(player)
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
	pit:Forget(player)
	pendingCombatSync[player] = nil
	ActiveProfiles[player] = nil
end)

_G.DataManager = DataManager
