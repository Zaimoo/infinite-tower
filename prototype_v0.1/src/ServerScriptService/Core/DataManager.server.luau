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

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TycoonRemotes = Remotes:WaitForChild("TycoonGachaRemotes")
local SyndicateRemotes = Remotes:WaitForChild("SyndicateRemotes")

local RequestSummonFunc = TycoonRemotes:WaitForChild("RequestSummon") :: RemoteFunction
local SynthesizeHeroesFunc = TycoonRemotes:WaitForChild("SynthesizeHeroes") :: RemoteFunction
local PromoteHeroStarFunc = TycoonRemotes:WaitForChild("PromoteHeroStar") :: RemoteFunction
local AssignHeroRoleFunc = TycoonRemotes:WaitForChild("AssignHeroRole") :: RemoteFunction
local FacilityInteractEvent = TycoonRemotes:WaitForChild("FacilityInteract") :: RemoteEvent

local ProfileDeltaSyncEvent = SyndicateRemotes:WaitForChild("ProfileDeltaSync") :: RemoteEvent
local SystemToastEvent = SyndicateRemotes:WaitForChild("SystemToast") :: RemoteEvent

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
	| "FACILITY_LAB"

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
	PlotIndex: number,
	Currencies: {
		Gold: number,
		Gems: number,
		ResearchPoints: number,
	},
	BossPity: number,
	RiftLuresOwned: number,
	UnlockedResearch: {
		SquadSlot4: boolean,
		SquadSlot5: boolean,
		Ring2BarrierGate: boolean,
	},
	Heroes: { [string]: HeroInstance },
	DeployedSquadOrder: { string },
	Facilities: {
		ManaConduit: FacilityData,
		Infirmary: FacilityData,
		DimensionalLab: FacilityData,
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

	return {
		SchemaVersion = 1,
		PlotIndex = 1,
		Currencies = {
			Gold = 500,
			Gems = 300, -- 3 immediate Gacha pulls during onboarding (Doc 3 Section 5.1)
			ResearchPoints = 0,
		},
		BossPity = 0,
		RiftLuresOwned = 0,
		UnlockedResearch = {
			SquadSlot4 = false,
			SquadSlot5 = false,
			Ring2BarrierGate = false,
		},
		Heroes = {
			[hanUUID] = hanHero,
			[jennaUUID] = jennaHero,
			[catioUUID] = catioHero,
		},
		DeployedSquadOrder = { hanUUID, jennaUUID },
		Facilities = {
			ManaConduit = conduit,
			Infirmary = createDefaultFacility(),
			DimensionalLab = createDefaultFacility(),
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
	return ActiveProfiles[player]
end

function DataManager.SendToast(player: Player, message: string, colorType: string?)
	SystemToastEvent:FireClient(player, message, colorType or "INFO")
end

function DataManager.BroadcastToast(message: string, colorType: string?)
	SystemToastEvent:FireAllClients(message, colorType or "ALERT")
end

-- Build a sanitized copy of profile for client UI (hiding secret directive of rented mercenary!)
function DataManager.SyncProfile(player: Player)
	local profile = ActiveProfiles[player]
	if not profile then
		return
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
	if _G.CombatSimulation and _G.CombatSimulation.RebuildPlayerSquad then
		_G.CombatSimulation.RebuildPlayerSquad(player)
	end
	if _G.PlotManager and _G.PlotManager.RefreshPlotVisuals then
		_G.PlotManager.RefreshPlotVisuals(player)
	end

	ProfileDeltaSyncEvent:FireClient(player, profile)
end

function DataManager.ApplyCollisionGroup(player: Player)
	local profile = ActiveProfiles[player]
	local char = player.Character
	if not profile or not char then
		return
	end
	local groupName = profile.UnlockedResearch.Ring2BarrierGate and "UnlockedRing2" or "DefaultPlayer"
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

function DataManager.MaxSquadSlots(profile: PlayerProfile): number
	if profile.UnlockedResearch.SquadSlot5 then
		return 5
	elseif profile.UnlockedResearch.SquadSlot4 then
		return 4
	end
	return 3
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

-- Atomic Synthesis ("The Pit") Transaction
function DataManager.SynthesizeHeroes(player: Player, targetUUID: string, fodderUUIDs: { string }): (boolean, string)
	local profile = ActiveProfiles[player]
	if not profile then
		return false, "Profile not loaded"
	end

	local targetHero = profile.Heroes[targetUUID]
	if not targetHero then
		return false, "Target hero does not exist"
	end

	local maxLevel = targetHero.Stars * 10
	if targetHero.Level >= maxLevel then
		return false, string.format("%s is already at Max Level (Lv.%d)! Use Star Promotion.", targetHero.DisplayName, maxLevel)
	end

	if type(fodderUUIDs) ~= "table" or #fodderUUIDs == 0 or #fodderUUIDs > 20 then
		return false, "Select 1 to 20 unlocked Benched fodder heroes"
	end

	local seen: { [string]: boolean } = { [targetUUID] = true }
	local totalXPGained = 0

	for _, fUUID in ipairs(fodderUUIDs) do
		if seen[fUUID] then
			return false, "Duplicate or self-sacrificed hero detected"
		end
		seen[fUUID] = true

		local fodder = profile.Heroes[fUUID]
		if not fodder then
			return false, "Fodder hero missing"
		end
		if fodder.Locked then
			return false, "Cannot sacrifice a Locked hero"
		end
		if fodder.Assignment ~= "BENCHED" then
			return false, "Fodder hero must be Benched first"
		end

		totalXPGained += StatFormulas.CalculateSynthesisXP(fodder.Stars, fodder.Level)
	end

	for _, fUUID in ipairs(fodderUUIDs) do
		profile.Heroes[fUUID] = nil
	end

	targetHero.XP += totalXPGained
	while targetHero.Level < maxLevel do
		local reqXP = StatFormulas.GetXPRequiredForNextLevel(targetHero.Level)
		if targetHero.XP >= reqXP then
			targetHero.XP -= reqXP
			targetHero.Level += 1
		else
			break
		end
	end

	if targetHero.Level >= maxLevel then
		targetHero.XP = 0
	end

	DataManager.SyncProfile(player)
	local msg = string.format("The Pit: +%d XP -> %s is now Lv.%d!", totalXPGained, targetHero.DisplayName, targetHero.Level)
	DataManager.SendToast(player, msg, "SUCCESS")
	return true, msg
end

SynthesizeHeroesFunc.OnServerInvoke = function(player: Player, targetUUID: any, fodderUUIDs: any)
	if type(targetUUID) ~= "string" or type(fodderUUIDs) ~= "table" then
		return false, "Invalid arguments"
	end
	return DataManager.SynthesizeHeroes(player, targetUUID, fodderUUIDs)
end

-- Atomic Star Promotion Transaction (1★ to 5★)
function DataManager.PromoteHeroStar(player: Player, targetUUID: string, fodderUUIDs: { string }): (boolean, string)
	local profile = ActiveProfiles[player]
	if not profile then
		return false, "Profile not loaded"
	end

	local targetHero = profile.Heroes[targetUUID]
	if not targetHero then
		return false, "Target hero not found"
	end

	local currentStars = targetHero.Stars
	if currentStars >= 5 then
		return false, "Hero is already at maximum 5★ Mythic tier!"
	end

	local requiredMaxLevel = currentStars * 10
	if targetHero.Level < requiredMaxLevel then
		return false, string.format("Hero must reach Max Level (Lv.%d) before promoting!", requiredMaxLevel)
	end

	if type(fodderUUIDs) ~= "table" or #fodderUUIDs ~= currentStars then
		return false, string.format("Requires sacrificing %dx %d★ Benched heroes!", currentStars, currentStars)
	end

	local goldCost = StatFormulas.GetPromotionGoldCost(currentStars)
	if profile.Currencies.Gold < goldCost then
		return false, string.format("Requires %d Gold for %d★ -> %d★ Promotion", goldCost, currentStars, currentStars + 1)
	end

	local seen: { [string]: boolean } = { [targetUUID] = true }
	for _, fUUID in ipairs(fodderUUIDs) do
		if seen[fUUID] then
			return false, "Duplicate fodder UUID"
		end
		seen[fUUID] = true

		local fodder = profile.Heroes[fUUID]
		if not fodder or fodder.Stars ~= currentStars then
			return false, string.format("All fodder heroes must be %d★", currentStars)
		end
		if fodder.Locked or fodder.Assignment ~= "BENCHED" then
			return false, "Fodder heroes must be unlocked and Benched"
		end
	end

	profile.Currencies.Gold -= goldCost
	for _, fUUID in ipairs(fodderUUIDs) do
		profile.Heroes[fUUID] = nil
	end

	targetHero.Stars = currentStars + 1
	targetHero.Level = 1
	targetHero.XP = 0
	targetHero.BaseHP = math.round(targetHero.BaseHP * 1.65)
	targetHero.BaseATK = math.round(targetHero.BaseATK * 1.65)
	targetHero.BaseLabor = math.round(targetHero.BaseLabor * 1.35 * 100) / 100

	DataManager.SyncProfile(player)
	local msg = string.format("STAR PROMOTION! %s ascended to %d★ (1.65x Combat / 1.35x Labor)!", targetHero.DisplayName, targetHero.Stars)
	DataManager.BroadcastToast(string.format("⭐ %s promoted %s to %d★!", player.DisplayName, targetHero.DisplayName, targetHero.Stars), "SUCCESS")
	return true, msg
end

PromoteHeroStarFunc.OnServerInvoke = function(player: Player, targetUUID: any, fodderUUIDs: any)
	if type(targetUUID) ~= "string" or type(fodderUUIDs) ~= "table" then
		return false, "Invalid arguments"
	end
	return DataManager.PromoteHeroStar(player, targetUUID, fodderUUIDs)
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
			return false, string.format("All %d Unlocked Squad Slots are full! (Unlock more in Dimensional Lab)", maxSlots)
		end
	elseif targetAssignment == "FACILITY_CONDUIT" or targetAssignment == "FACILITY_INFIRMARY" or targetAssignment == "FACILITY_LAB" then
		local facKey = if targetAssignment == "FACILITY_CONDUIT" then "ManaConduit"
			elseif targetAssignment == "FACILITY_INFIRMARY" then "Infirmary"
			else "DimensionalLab"
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
-- 6. FACILITY INTERACTIONS (COLLECT, UPGRADE, TECH TREE & RIFT LURES)
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

	elseif action == "COLLECT_LAB" then
		local amt = math.floor(profile.Facilities.DimensionalLab.UncollectedOutput)
		if amt > 0 then
			profile.Facilities.DimensionalLab.UncollectedOutput -= amt
			profile.Currencies.ResearchPoints += amt
			DataManager.SendToast(player, string.format("Collected +%d Research Points (RP) from Dimensional Lab!", amt), "SUCCESS")
			DataManager.SyncProfile(player)
		else
			DataManager.SendToast(player, "Dimensional Lab buffer is empty right now.", "INFO")
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
		if profile.Currencies.Gold < nextCfg.Gold or profile.Currencies.ResearchPoints < nextCfg.RP then
			DataManager.SendToast(player, string.format("Need %d Gold + %d RP to upgrade %s to Lv.%d!", nextCfg.Gold, nextCfg.RP, param, nextLevel), "WARN")
			return
		end
		profile.Currencies.Gold -= nextCfg.Gold
		profile.Currencies.ResearchPoints -= nextCfg.RP
		facData.Level = nextLevel
		DataManager.SendToast(player, string.format("Upgraded %s to Level %d!", param, nextLevel), "SUCCESS")
		DataManager.SyncProfile(player)

	elseif action == "UNLOCK_TECH" and type(param) == "string" then
		local node = (FacilityConfig.TechNodes :: any)[param]
		if not node then
			return
		end
		if profile.Facilities.DimensionalLab.Level < node.ReqLabLevel then
			DataManager.SendToast(player, string.format("Requires Dimensional Lab Level %d!", node.ReqLabLevel), "WARN")
			return
		end
		if param == "tech_squad_slot_4" and profile.UnlockedResearch.SquadSlot4 then return end
		if param == "tech_squad_slot_5" and profile.UnlockedResearch.SquadSlot5 then return end
		if param == "tech_ring2_barrier" and profile.UnlockedResearch.Ring2BarrierGate then return end

		if profile.Currencies.ResearchPoints < node.RPCost or profile.Currencies.Gold < node.GoldCost then
			DataManager.SendToast(player, string.format("Need %d RP + %d Gold for %s!", node.RPCost, node.GoldCost, node.Name), "WARN")
			return
		end

		profile.Currencies.ResearchPoints -= node.RPCost
		profile.Currencies.Gold -= node.GoldCost

		if param == "tech_squad_slot_4" then
			profile.UnlockedResearch.SquadSlot4 = true
			DataManager.SendToast(player, "Unlocked 4th Squad Deployment Slot!", "SUCCESS")
		elseif param == "tech_ring2_barrier" then
			profile.UnlockedResearch.Ring2BarrierGate = true
			DataManager.ApplyCollisionGroup(player)
			DataManager.SendToast(player, "Ring 2 Arcane Barrier Gate Unlocked! You may now enter Ring 2 & Ring 3!", "SUCCESS")
		elseif param == "tech_squad_slot_5" then
			profile.UnlockedResearch.SquadSlot5 = true
			DataManager.SendToast(player, "Unlocked 5th Squad Deployment Slot (Max 5-Hero Squad)!", "SUCCESS")
		elseif param == "craft_rift_lure" then
			profile.RiftLuresOwned += 1
			DataManager.SendToast(player, "Crafted 1x Rift Lure! Use it at the Ring 3 Altar to summon The Rift Warden!", "SUCCESS")
		end
		DataManager.SyncProfile(player)

	elseif action == "DEV_GRANT_RESOURCES" then
		-- Prototype helper so testers can also test mid/late-game features immediately if desired
		profile.Currencies.Gold += 25000
		profile.Currencies.Gems += 1800
		profile.Currencies.ResearchPoints += 600
		DataManager.SendToast(player, "[Prototype Boost] +25,000 Gold, +1,800 Gems, +600 RP added!", "SUCCESS")
		DataManager.SyncProfile(player)
	end
end)

--============================================================================
-- 7. PLAYER LIFECYCLE INITIALIZATION
--============================================================================

local function onPlayerAdded(player: Player)
	local profile = createDefaultPlayerProfile()
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
	ActiveProfiles[player] = nil
end)

_G.DataManager = DataManager
