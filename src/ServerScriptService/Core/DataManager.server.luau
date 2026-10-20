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
	Favorite: boolean,
	OverflowXP: number,
	InheritedImprints: { [string]: number },
	ImprintCapacity: number,
	SynthesisHistory: any,
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
	PitMaterials: { [string]: number },
	PitRevision: number,
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
		EssenceAttunement: boolean,
		MemoryStudies: boolean,
		AdvancedStonecraft: boolean,
		MasterStonecraft: boolean,
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

	return {
		SchemaVersion = 2,
		PitMaterials = { SoulEssence = 0, PromotionStone = 0, ImprintCatalyst = 0 },
		PitRevision = 0,
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
			EssenceAttunement = false,
			MemoryStudies = false,
			AdvancedStonecraft = false,
			MasterStonecraft = false,
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

-- Legacy endpoints cannot bypass confirmed previews.
function DataManager.SynthesizeHeroes(_player: Player, _targetUUID: string, _fodderUUIDs: { string }): (boolean, string)
	return false, "Open The Pit and confirm a synthesis preview."
end
function DataManager.PromoteHeroStar(_player: Player, _targetUUID: string, _fodderUUIDs: { string }): (boolean, string)
	return false, "Open The Pit and confirm a material-based promotion preview."
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
		if node.ResearchKey and (profile.UnlockedResearch :: any)[node.ResearchKey] then return end
		if param == "tech_squad_slot_4" and profile.UnlockedResearch.SquadSlot4 then return end
		if param == "tech_squad_slot_5" and profile.UnlockedResearch.SquadSlot5 then return end
		if param == "tech_ring2_barrier" and profile.UnlockedResearch.Ring2BarrierGate then return end

		if profile.Currencies.ResearchPoints < node.RPCost or profile.Currencies.Gold < node.GoldCost then
			DataManager.SendToast(player, string.format("Need %d RP + %d Gold for %s!", node.RPCost, node.GoldCost, node.Name), "WARN")
			return
		end

		profile.Currencies.ResearchPoints -= node.RPCost
		profile.Currencies.Gold -= node.GoldCost

		if node.ResearchKey then
			(profile.UnlockedResearch :: any)[node.ResearchKey] = true
			DataManager.SendToast(player, "Unlocked " .. node.Name .. "!", "SUCCESS")
		elseif param == "tech_squad_slot_4" then
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
		if not game:GetService("RunService"):IsStudio() then return end
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
