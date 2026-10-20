# DOCUMENT 2: TECHNICAL ARCHITECTURE & LUAU SPECIFICATION — MVP (v0.1)
**Project Codename:** *Project: Waiting Room*  
**Architecture Standard:** `--!strict` Roblox Luau | Zero Server-Side Humanoids | 5 Hz (`0.20s`) Server Simulation Loop | 60 FPS Client `RenderStepped` Interpolation | `ProfileStore` / `ProfileService` Session-Locked Persistence

---

## 1. FULL ROBLOX STUDIO FOLDER HIERARCHY

To guarantee zero server-side `Humanoid` overhead while maintaining crisp 60 FPS visuals for up to 30 active combat heroes, 18 Tycoon worker heroes, 60+ Ring mobs/Elites, and the World Boss, the project strictly separates **Server Authority (Data Tables)** from **Client Presentation (R15 Visual Rigs & VFX)**.

```text
game
├── Workspace
│   ├── ArenaRings
│   │   ├── Ring1_OuterRuins          -- Radius 280..460 studs (Mob Spawn Anchors, Crystal Nodes)
│   │   ├── Ring2_CorruptedGrove      -- Radius 120..280 studs (Elite Anchors, Barrier Gate at R=280)
│   │   └── Ring3_CenterBossAltar     -- Radius 0..120 studs (Origin (0,16,0), World Boss & Rift Boss Altar)
│   ├── PerimeterHighway              -- Radius 460..480 studs
│   │   └── SharedPactPedestals       -- 6 Pedestal Parts at 30°, 90°, 150°, 210°, 270°, 330° (R=472)
│   ├── WaitingRoomPlots              -- 6 Plots at 0°, 60°, 120°, 180°, 240°, 300° (R=480..600)
│   │   ├── Plot_1 .. Plot_6
│   │   │   ├── PrivateExtractionPad  -- Part (16x16 studs, Local X=-35, R=490)
│   │   │   ├── MercenaryBoard        -- Interactive Noticeboard + Security/Purge Terminal
│   │   │   ├── SummoningAltar        -- Gacha Obelisk + The Pit (Synthesis Cauldron)
│   │   │   ├── Facility_ManaConduit  -- Worker Pedestals (x3) + Physical GemChest (Mimic-capable)
│   │   │   ├── Facility_Infirmary    -- Worker Pedestals (x3) + RecuperationBeds (x5)
│   │   │   └── Facility_DimLab       -- Worker Pedestals (x3) + Research & Rift Lure Terminal
│   ├── PhysicalRelics                -- Server-managed BaseParts (Anchored or Welded to Carrier HRP)
│   └── ClientVisualEntities          -- Client-only folder (Ignored by Server Physics; R15 Rigs & Mobs)
│
├── ReplicatedStorage
│   ├── Remotes                       -- Network Layer (Created/Validated at boot by NetworkInit)
│   │   ├── CombatRemotes             -- Folder
│   │   │   ├── ReplicationTick       -- UnreliableRemoteEvent (S->C: 5 Hz binary buffer snapshot)
│   │   │   ├── FocusTarget           -- RemoteEvent (C->S: [Click/Tap] target EntityId)
│   │   │   ├── WhistleCommand        -- RemoteEvent (C->S: "Q_OVERDRIVE" | "E_RECALL")
│   │   │   ├── BossTelegraph         -- RemoteEvent (S->C: Devouring Nova & Boss Phase VFX cues)
│   │   │   └── CombatVFX             -- UnreliableRemoteEvent (S->C: Hit sparks, crits, Coma warp)
│   │   ├── RelicPactRemotes          -- Folder
│   │   │   ├── RelicStateChanged     -- RemoteEvent (S->C: Spawn, Pickup, Fumble, Extract, LockTimer)

│   │   │   └── BountyDropped         -- RemoteEvent (S->C: Rogue Master Chest / Leech Bounty Bag)
│   │   ├── TycoonGachaRemotes        -- Folder
│   │   │   ├── RequestSummon         -- RemoteFunction (C->S: 1x or 10x Gacha Pull)
│   │   │   ├── SynthesizeHeroes      -- RemoteFunction (C->S: Feed fodder UUIDs into target UUID)
│   │   │   ├── PromoteHeroStar       -- RemoteFunction (C->S: 1★->5★ Star Promotion)
│   │   │   ├── AssignHeroRole        -- RemoteFunction (C->S: Deploy to Squad or Facility Slot)
│   │   │   └── FacilityInteract      -- RemoteEvent (C->S: Collect Gems, Upgrade, Unlock Research)
│   │   └── SyndicateRemotes          -- Folder

│   │       ├── PlotEspionage         -- RemoteEvent (C->S: Start/Finish Bless or Leech, Purge, Mimic)
│   │       └── ProfileDeltaSync      -- RemoteEvent (S->C: Lightweight state patch for UI/HUD)
│   │
│   ├── Shared
│   │   ├── Types                     -- Shared Luau Type Definitions
│   │   │   ├── SharedTypes.luau      -- HeroInstance, PlayerProfile, SocialProfile, CombatEntity
│   │   │   └── NetworkTypes.luau     -- Payload contracts & buffer byte layouts
│   │   ├── Config                    -- Static Read-Only Game Balance Tables
│   │   │   ├── HeroCatalog.luau      -- Base stats, Archetypes, Passive Traits, Gacha weights
│   │   │   ├── RelicConfig.luau      -- WalkSpeed penalties, despawn timers, payouts
│   │   │   ├── FacilityConfig.luau   -- Upgrade costs, output formulas, Research nodes
│   │   │   └── WorldBossConfig.luau  -- Dimensional Sovereign phases, Nova radius (85st), Pity table
│   │   └── Util
│   │       ├── StatFormulas.luau     -- Pure functions for EffectiveATK/HP/Labor, XP_Gained, Promotion
│   │       ├── BufferSerializer.luau -- Packs/unpacks 5 Hz entity transforms into compact buffers
│   │       └── SpatialGrid.luau      -- 2D uniform spatial hash for O(1) range & AoE queries
│   │
│   └── Assets                        -- Client-Cloned Visual Templates
│       ├── HeroRigs                  -- R15 MeshPart rigs (No Server Humanoids; AnimationController only)
│       ├── MobRigs                   -- Ring 1/2 Mobs, Elites, and Dimensional Sovereign rig
│       ├── RelicModels               -- Mana Geode, Cursed Urn, Abyssal Core, Calamity Heart
│       └── VFXTemplates              -- Red AoE decals, Whistle rings, Mimic chest teeth, Snares
│
├── ServerScriptService
│   ├── Core
│   │   ├── ServerBoot.server.luau          -- Deterministic initialization order for all services
│   │   ├── DataManager.server.luau         -- ProfileStore session-locking, UUID roster, auto-save
│   │   └── PlotManager.server.luau         -- Assigns 1 of 6 Waiting Room plots + CollisionGroups
│   ├── Combat
│   │   ├── CombatSimulation.server.luau    -- 5 Hz (0.2s) authoritative state machine & World Boss AI
│   │   ├── MobSpawner.server.luau          -- Ring 1/2 population density & Rift Lure summons
│   │   └── WorldBossDirector.server.luau   -- 20m schedule, Dynamic HP, Leaderboard, Pity + Direct Loot
│   ├── ExtractionAndSocial
│   │   ├── RelicService.server.luau        -- Physical Relics, welds, Fumbles, Tandem Carry, Pact splits
│   │   ├── SyndicateService.server.luau    -- Mercenary Board, Parasite/Saboteur ticks, Audit Soul
│   │   └── EspionageService.server.luau    -- Bless vs. Leech runes, 15s Purge window, Mimic Chest traps
│   └── Tycoon
│       ├── WaitingRoomService.server.luau  -- 1 Hz economy tick (Mana Conduit, Infirmary, Dim Lab)
│       └── GachaPromotionService.server.luau -- Summoning RNG, The Pit Synthesis, Star Promotion
│
└── StarterPlayer
    └── StarterPlayerScripts
        ├── ClientBoot.client.luau          -- Initializes client controllers
        ├── Rendering
        │   ├── EntityRenderer.client.luau  -- Spawns R15 rigs & lerps CFrames at 60 FPS (RenderStepped)
        │   ├── TelegraphVFX.client.luau    -- Smooth 60 FPS red AoE ring expansion & whistle effects
        │   └── MimicAndTellVFX.client.luau -- Renders 45s Parasite glance tell & Mimic chest illusions
        ├── Input
        │   ├── MasterController.client.luau -- Raycasts [Click/Tap] Focus Target, binds [Q], [E], [B]
        │   └── PromptController.client.luau -- Handles Bless/Leech hold-prompts & Relic pickup cues
        └── UI
            ├── HUDController.client.luau   -- Squad Stamina bars, World Boss timer & live DPS board
            ├── WaitingRoomUI.client.luau   -- Roster, The Pit (Synthesis), Star Promotion, Tech Tree
            └── SyndicateUI.client.luau     -- Blood Pact HUD, Mercenary Board, Audit Soul modal
```

---

## 2. DATASTORE SCHEMA (`DataManager.server.luau`)

This module defines the complete `--!strict` Luau type definitions (`HeroInstance`, `SocialProfile`, `PlayerProfile`) using flat UUID dictionaries for $O(1)$ hero lookups, implements session-locked persistence via `ProfileStore` / `ProfileService` conventions, and exposes atomic transaction methods for Synthesis, Star Promotion, and Honor/Debt tracking.

```luau
--!strict
-- ServerScriptService/Core/DataManager.server.luau
-- Authoritative Player Profile Schema, Session Locking, and Atomic Roster Transactions

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	| "MERCENARY_LISTED"

export type MercenaryDirective = "LOYAL" | "PARASITE" | "SABOTEUR"

export type MimicChestMode = "TRUE_STATE" | "FOOLS_GOLD" | "VEIL_OF_POVERTY"

export type HeroInstance = {
	UUID: string,                  -- Flat dictionary key (e.g., "h_8f94a2b0...")
	TemplateId: string,            -- Reference ID in HeroCatalog (e.g., "archon_vanguard")
	DisplayName: string,           -- Generated or catalog name
	Archetype: HeroArchetype,      -- Combat/Labor class
	Stars: number,                 -- 1 to 5 (4★ and 5★ via Star Promotion only)
	Level: number,                 -- 1 to (Stars * 10)
	XP: number,                    -- Current XP toward next level
	QualityScalar: number,         -- Rolled [0.90, 1.15] on summon
	BaseHP: number,                -- Star-promoted base HP (multiplied by 1.65x per Star promotion)
	BaseATK: number,               -- Star-promoted base ATK (multiplied by 1.65x per Star promotion)
	AttackRange: number,           -- Studs (e.g., 6 melee, 26 ranged)
	AttackInterval: number,        -- Seconds between attacks (e.g., 0.85s - 1.25s)
	BaseLabor: number,             -- Star-promoted base Labor (multiplied by 1.35x per Star promotion)
	PassiveTrait: string,          -- Trait ID (e.g., "IRON_WILL", "MANA_HARVESTER", "SWIFT_STRIKE")
	CurrentStamina: number,        -- 0.0 to 100.0
	MaxStamina: number,            -- Default 100.0
	ComaUntilTimestamp: number,    -- os.time() when Coma expires (0 if not in Coma)
	IsHardAuditComa: boolean,      -- True if banished by Audit Soul (5m Coma, non-reducible below 180s)
	Assignment: HeroAssignment,    -- Current deployment or Waiting Room facility slot
	Locked: boolean,               -- Player toggle to prevent accidental Synthesis/Promotion sacrifice
}

export type FacilityData = {
	Level: number,                 -- 1 to 10
	AssignedHeroUUIDs: { string }, -- Up to 3 Hero UUIDs
	UncollectedOutput: number,     -- Physical Gem Chest balance (Mana Conduit) or buffered RP (Dim Lab)
	BlessedUntil: number,          -- os.time() when +25% Visitor Blessing expires
	LeechedUntil: number,          -- os.time() when -20% Visitor Leech Rune expires
	LeechVisitorUserId: number?,   -- UserId of the thief currently leeching this facility
	LastRuneTimestamp: number,     -- os.time() when last Bless/Leech completed (for 15s Purge window)
	LastRuneWasLeech: boolean,     -- Hidden server truth for Purge Facility resolution
}

export type SocialProfile = {
	Honor: number,                      -- Clamped [-100, 100]; >= 50 Saint, <= -30 Rogue Master
	RogueUntilTimestamp: number,        -- os.time() when 5-minute Betrayal Rogue status expires
	PvPImmunityUntilTimestamp: number,  -- 60s grace period after Rogue Bounty is claimed
	ActivePactPartnerUserId: number?,   -- Session-only UserId of Blood Pact partner (nil if solo)
	LastShatterTimestamp: number,       -- os.time() when [B] Shatter Pact was pressed while carrying
	ListedMercenaryUUID: string?,       -- UUID of Hero listed on Mercenary Noticeboard
	ListedMercenaryFee: number,         -- Gold rental fee (500 to 10,000)
	ListedMercenaryDirective: MercenaryDirective, -- Hidden directive: "LOYAL" | "PARASITE" | "SABOTEUR"
	GarnishedGemDebt: number,           -- Unpaid 2x Parasite Audit Soul fine auto-seized from Mana Conduit
	MimicIllusionMode: MimicChestMode,  -- "TRUE_STATE" | "FOOLS_GOLD" | "VEIL_OF_POVERTY"
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
	Currencies: {
		Gold: number,               -- Unbanked/Wallet Gold (15% vulnerable to drop if killed as Rogue Master)
		Gems: number,               -- Premium/Tycoon Gacha currency
		ResearchPoints: number,     -- Generated by Dimensional Lab Scholars
	},
	BossPity: number,               -- 0 to 100 (+10% per World Boss clear for Ranks #4-#6; 100% = guaranteed 3★ Boss Hero)
	RiftLuresOwned: number,         -- Consumable items crafted in Dimensional Lab to summon Floor Bosses
	UnlockedResearch: {
		SquadSlot4: boolean,        -- Unlocks 4th Deployed Hero slot
		SquadSlot5: boolean,        -- Unlocks 5th Deployed Hero slot
		Ring2BarrierGate: boolean,  -- Unlocks passage through R=280 Arcane Barrier Gate
	},
	Heroes: { [string]: HeroInstance }, -- Flat UUID dictionary for O(1) lookup & mutation
	DeployedSquadOrder: { string },     -- Ordered array of up to 5 Hero UUIDs currently deployed
	Facilities: {
		ManaConduit: FacilityData,
		Infirmary: FacilityData,
		DimensionalLab: FacilityData,
	},
	Social: SocialProfile,
}

--============================================================================
-- 2. DEFAULT PROFILE TEMPLATE
--============================================================================

local CURRENT_SCHEMA_VERSION = 1

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

local function createStarterHeroUUID(): (string, HeroInstance)
	local uuid = "h_" .. string.gsub(HttpService:GenerateGUID(false), "-", ""):sub(1, 12)
	local starterHero: HeroInstance = {
		UUID = uuid,
		TemplateId = "starter_iron_vanguard",
		DisplayName = "Han Islat (1★)",
		Archetype = "Striker",
		Stars = 1,
		Level = 1,
		XP = 0,
		QualityScalar = 1.05,
		BaseHP = 280,
		BaseATK = 38,
		AttackRange = 6,
		AttackInterval = 0.85,
		BaseLabor = 12,
		PassiveTrait = "RELENTLESS_MARCH",
		CurrentStamina = 100.0,
		MaxStamina = 100.0,
		ComaUntilTimestamp = 0,
		IsHardAuditComa = false,
		Assignment = "SQUAD_SLOT_1",
		Locked = true,
	}
	return uuid, starterHero
end

local function createDefaultPlayerProfile(): PlayerProfile
	local starterUUID, starterHero = createStarterHeroUUID()
	return {
		SchemaVersion = CURRENT_SCHEMA_VERSION,
		Currencies = {
			Gold = 500,
			Gems = 300, -- Enough for 3 immediate Gacha pulls during onboarding
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
			[starterUUID] = starterHero,
		},
		DeployedSquadOrder = { starterUUID },
		Facilities = {
			ManaConduit = createDefaultFacility(),
			Infirmary = createDefaultFacility(),
			DimensionalLab = createDefaultFacility(),
		},
		Social = {
			Honor = 0,
			RogueUntilTimestamp = 0,
			PvPImmunityUntilTimestamp = 0,
			ActivePactPartnerUserId = nil,
			LastShatterTimestamp = 0,
			ListedMercenaryUUID = nil,
			ListedMercenaryFee = 1000,
			ListedMercenaryDirective = "LOYAL",
			GarnishedGemDebt = 0,
			MimicIllusionMode = "TRUE_STATE",
			Stats = {
				PactsHonored = 0,
				PactsBetrayed = 0,
				SoulsAudited = 0,
				RoguesDefeated = 0,
				LeechesPurged = 0,
			},
		},
	}
end

--============================================================================
-- 3. DATA MANAGER SERVICE & ATOMIC TRANSACTIONS
--============================================================================

local DataManager = {}
local ActiveProfiles: { [Player]: PlayerProfile } = {}

-- Exact Project Bible Formula: XP_Gained = (100 * (3 ^ (FodderStars - 1))) + (25 * FodderLevel)
function DataManager.CalculateSynthesisXP(fodderStars: number, fodderLevel: number): number
	return (100 * (3 ^ (fodderStars - 1))) + (25 * fodderLevel)
end

-- XP Required for Level L -> L + 1: round(50 * (L ^ 1.45))
function DataManager.GetXPRequiredForNextLevel(currentLevel: number): number
	return math.round(50 * (currentLevel ^ 1.45))
end

-- Gold Cost Table for Star Promotion (S -> S + 1)
local PROMOTION_GOLD_COSTS: { [number]: number } = {
	[1] = 1500,   -- 1★ -> 2★ (Requires 1x 1★ fodder)
	[2] = 7500,   -- 2★ -> 3★ (Requires 2x 2★ fodder)
	[3] = 35000,  -- 3★ -> 4★ (Requires 3x 3★ fodder)
	[4] = 150000, -- 4★ -> 5★ (Requires 4x 4★ fodder)
}

function DataManager.GetProfile(player: Player): PlayerProfile?
	return ActiveProfiles[player]
end

-- Atomic Synthesis ("The Pit") Transaction
function DataManager.SynthesizeHeroes(
	player: Player,
	targetUUID: string,
	fodderUUIDs: { string }
): (boolean, string)
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
		return false, "Target hero is already at Max Level for its Star tier"
	end

	if #fodderUUIDs == 0 or #fodderUUIDs > 20 then
		return false, "Invalid fodder count (1-20 allowed per batch)"
	end

	-- Validate all fodder heroes exist, are distinct, not locked, and not deployed/listed
	local seen: { [string]: boolean } = { [targetUUID] = true }
	local totalXPGained = 0

	for _, fUUID in ipairs(fodderUUIDs) do
		if seen[fUUID] then
			return false, "Duplicate or self-sacrificed hero UUID detected"
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
			return false, "Fodder hero must be Benched before Synthesis"
		end

		totalXPGained += DataManager.CalculateSynthesisXP(fodder.Stars, fodder.Level)
	end

	-- Consume fodder heroes from flat UUID dictionary
	for _, fUUID in ipairs(fodderUUIDs) do
		profile.Heroes[fUUID] = nil
	end

	-- Apply XP & level up capped at MaxLevel = Stars * 10
	targetHero.XP += totalXPGained
	while targetHero.Level < maxLevel do
		local reqXP = DataManager.GetXPRequiredForNextLevel(targetHero.Level)
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

	return true, string.format("Gained %d XP (Now Lv.%d)", totalXPGained, targetHero.Level)
end

-- Atomic Star Promotion Transaction (1★ to 5★)
function DataManager.PromoteHeroStar(
	player: Player,
	targetUUID: string,
	fodderUUIDs: { string }
): (boolean, string)
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
		return false, "Hero is already at maximum 5★ tier"
	end

	local requiredMaxLevel = currentStars * 10
	if targetHero.Level < requiredMaxLevel then
		return false, string.format("Hero must be Max Level (%d) to promote", requiredMaxLevel)
	end

	-- Must sacrifice S fodder heroes of Star tier S
	if #fodderUUIDs ~= currentStars then
		return false, string.format("Requires exactly %d fodder heroes of %d★ tier", currentStars, currentStars)
	end

	local goldCost = PROMOTION_GOLD_COSTS[currentStars] or 9999999
	if profile.Currencies.Gold < goldCost then
		return false, "Insufficient Gold for Star Promotion"
	end

	local seen: { [string]: boolean } = { [targetUUID] = true }
	for _, fUUID in ipairs(fodderUUIDs) do
		if seen[fUUID] then
			return false, "Duplicate hero UUID in promotion sacrifice"
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

	-- Deduct Gold & consume fodder UUIDs
	profile.Currencies.Gold -= goldCost
	for _, fUUID in ipairs(fodderUUIDs) do
		profile.Heroes[fUUID] = nil
	end

	-- Apply Promotion: Stars + 1, Level -> 1, Combat * 1.65x, Labor * 1.35x
	targetHero.Stars = currentStars + 1
	targetHero.Level = 1
	targetHero.XP = 0
	targetHero.BaseHP = math.round(targetHero.BaseHP * 1.65)
	targetHero.BaseATK = math.round(targetHero.BaseATK * 1.65)
	targetHero.BaseLabor = math.round(targetHero.BaseLabor * 1.35 * 100) / 100

	return true, string.format("Promoted %s to %d★!", targetHero.DisplayName, targetHero.Stars)
end

-- Adjust Honor and check Rogue Master status
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
end

function DataManager.IsPlayerRogue(player: Player): boolean
	local profile = ActiveProfiles[player]
	if not profile then
		return false
	end
	return (profile.Social.Honor <= -30) or (os.time() < profile.Social.RogueUntilTimestamp)
end

-- Session Lifecycle
Players.PlayerAdded:Connect(function(player: Player)
	-- In production, wrap with ProfileStore:StartSessionAsync(string.format("Player_%d", player.UserId))
	local profile = createDefaultPlayerProfile()
	-- Clear transient session fields
	profile.Social.ActivePactPartnerUserId = nil
	ActiveProfiles[player] = profile
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local profile = ActiveProfiles[player]
	if profile then
		-- Release session lock & persist to DataStore
		ActiveProfiles[player] = nil
	end
end)

_G.DataManager = DataManager
return DataManager
```

---

## 3. NETWORK PROTOCOL (`Remotes` SPECIFICATION)

To keep server bandwidth well under Roblox's `50 KB/s` per-client budget—even during a 6-player, 30-hero World Boss encounter—the network layer uses **binary `buffer` bitpacking** over an `UnreliableRemoteEvent` for the 5 Hz position/HP/Stamina snapshot, paired with rate-limited `RemoteEvent` and `RemoteFunction` endpoints for stateful actions.

### 3.1 Complete Remotes Specification Table

| Remote Name & Class | Direction | Payload Parameters & Types | Byte-Size Optimization | Server-Side Sanity Checks & Anti-Exploit Validations |
| :--- | :--- | :--- | :--- | :--- |
| **`ReplicationTick`**<br>`UnreliableRemoteEvent` | `S -> C` (5 Hz / 0.2s) | `snapshotBuf: buffer`<br>Header: `uint8` entityCount, `float32` serverTime.<br>Per Entity (12 bytes): `uint16` netId, `int16` posX (`*10`), `int16` posZ (`*10`), `uint8` rotYaw, `uint8` stateEnum, `uint16` hpPct (`0..1000`), `uint8` stamina (`0..100`), `uint8` flags (`Overdrive/Coma/Pacified`). | **12 bytes per entity.** 30 Heroes + 30 Mobs + 1 Boss = 61 entities $\times$ 12B + 5B header = **`737 bytes/tick` (`3.68 KB/s`)** per client. | Read-only broadcast (`S -> C`). Any `C -> S` packet fired on this remote is dropped and increments player exploit strike counter. |
| **`FocusTarget`**<br>`RemoteEvent` | `C -> S` | `targetNetId: number` (`uint16`) | `2 bytes` integer ID instead of passing `Instance` or string UUIDs. | 1. Rate limit: Max `8 calls/sec` per player.<br>2. Verify `targetNetId` exists in active `MobTable` or belongs to a confirmed **Rogue Master** (`IsPlayerRogue == true`) inside Ring 1 or Ring 2.<br>3. Verify distance between Master `HumanoidRootPart` and target is `<= 85 studs`. |
| **`WhistleCommand`**<br>`RemoteEvent` | `C -> S` | `commandCode: number` (`uint8`: `1 = Q_OVERDRIVE`, `2 = E_RECALL`) | `1 byte` enum (`uint8`). | 1. Server tracks authoritative cooldown timestamps: `Q` requires `os.clock() - lastQ >= 20.0s`; `E` requires `os.clock() - lastE >= 6.0s`.<br>2. For `Q_OVERDRIVE`, server verifies each deployed hero has `CurrentStamina >= 5.0` before deducting `5.0` Stamina.<br>3. For `E_RECALL`, server validates Master is alive and not currently inside an out-of-bounds geometry clip. |
| **`BossTelegraph`**<br>`RemoteEvent` | `S -> C` | `telegraphType: uint8`, `originXZ: Vector2int16`, `radius: uint8`, `durationMs: uint16` | `7 bytes` total per boss cast. | Server-authoritative broadcast only. Hit detection for **Devouring Nova** (`R <= 85 studs` at `t = 3.0s`) is computed 100% on the server—client VFX timing cannot be spoofed to dodge. |
| **`RelicStateChanged`**<br>`RemoteEvent` | `S -> C` | `relicNetId: uint16`, `tierId: uint8`, `state: uint8` (`SPAWN/PICKUP/FUMBLE/EXTRACT`), `carrierUserId: number?`, `lockExpiresAt: number` | Compact tuple (`~16 bytes`). | Server-only broadcast. Clients never tell the server they picked up or extracted a Relic; server `RelicService` validates 3D proximity (`<= 8 studs`) and owner-lock expiry (`3s` fumble lock / `15s` Rank #1 DPS lock). |
| **`LootStolenAlert`**<br>`RemoteEvent` | `S -> C` | `thiefUserId: number`, `thiefName: string`, `lootType: string`, `amount: number` | `~20 bytes`. | Broadcast to victim player when another player collects their drop, opening real-time retaliation HUD action. |
| **`SquadWipeState`**<br>`RemoteEvent` | `S -> C` | `isWiped: boolean` | `1 byte`. | Server fires `true` on squad defeat, locking field looting until player returns to plot infirmary/barracks; fires `false` on recovery. |
| **`CarriedLootSync`**<br>`RemoteEvent` | `S -> C` | `gold: number`, `gems: number`, `rp: number` | `6 bytes` (`uint16` x 3). | Synchronizes overhead unbanked field cargo carried by the Master. |
| **`RequestSummon`**<br>`RemoteFunction` | `C -> S` | `pullCount: number` (`1` or `10`) $\rightarrow$ Returns `{ HeroInstance }?` | Batch table returned only on pull completion. | 1. Rate limit: `1 call / 1.5s` (mutex lock per player).<br>2. Strictly enforce `pullCount == 1` (`100 Gems`) or `pullCount == 10` (`900 Gems`).<br>3. Server CSPRNG rolls rarity (`70% 1★`, `25% 2★`, `5% 3★`); client has zero control over RNG seed. |
| **`SynthesizeHeroes`**<br>`RemoteFunction` | `C -> S` | `targetUUID: string`, `fodderUUIDs: { string }` $\rightarrow$ Returns `(boolean, string)` | UUID array (`<= 20` items per batch). | 1. Mutex lock per player.<br>2. Reject if `targetUUID` is in `fodderUUIDs` or if `fodderUUIDs` contains duplicate strings (prevents duplication exploits).<br>3. Verify all fodder heroes are `BENCHED` and `Locked == false`. |
| **`PromoteHeroStar`**<br>`RemoteFunction` | `C -> S` | `targetUUID: string`, `fodderUUIDs: { string }` $\rightarrow$ Returns `(boolean, string)` | UUID array (`1` to `4` items). | 1. Mutex lock per player.<br>2. Verify `targetHero.Level == targetHero.Stars * 10` and `targetHero.Stars < 5`.<br>3. Verify `#fodderUUIDs == targetHero.Stars` and every fodder has `fodder.Stars == targetHero.Stars`.<br>4. Verify and deduct Gold cost (`1.5k / 7.5k / 35k / 150k`). |

| **`PlotEspionage`**<br>`RemoteEvent` | `C -> S` | `opCode: uint8` (`1 = BEGIN_CHANNEL`, `2 = COMPLETE_BLESS`, `3 = COMPLETE_LEECH`, `4 = PURGE_FACILITY`, `5 = TOGGLE_MIMIC`), `plotIndex: uint8`, `facilityId: uint8` | `3 bytes` (`uint8` $\times 3$). | 1. **Anti-Instant-Channel Check:** Server records `channelStartTime` on `BEGIN_CHANNEL` and triggers the shared kneeling animation for all clients. When `COMPLETE_BLESS` or `COMPLETE_LEECH` arrives, server verifies `os.clock() - channelStartTime >= 1.95s` and distance to facility `<= 12 studs`.<br>2. **On `PURGE_FACILITY`:** Verify caller owns `plotIndex`, `os.time() - LastRuneTimestamp <= 15`, and `PurgeCooldown` is ready. |

---

## 4. CORE SERVER SIMULATION (`CombatSimulation.server.luau`)

This script implements the **5 Hz (`0.20s`) server-authoritative combat state machine** with **Zero Server-Side Humanoids**. All heroes, mobs, and the World Boss exist as pure Luau tables in server memory. It handles:
- Hero states: `FOLLOW_MASTER`, `MOVE_TO_TARGET`, `ATTACKING`, `COMA`
- Master commands: **`[Click / Tap]` Focus Target**, **`[Q]` Overdrive Whistle** (`+40% Attack Speed`, `-5 Stamina`), and **`[E]` Emergency Recall Whistle** (`6s CD`, instant teleport to Master + `2.0s` aggro disable)
- World Boss **Devouring Nova** (`20.0s` interval, `3.0s` telegraph, `85-stud` radius check, `-50% Stamina` or `60-second Coma` + Infirmary warp, plus `5.0s` `+25%` Core Exposed punish window)
- Binary `buffer` serialization for the 5 Hz `ReplicationTick`

```luau
--!strict
-- ServerScriptService/Combat/CombatSimulation.server.luau
-- 5 Hz (0.20s) Server-Authoritative Combat & World Boss State Machine (Zero Server Humanoids)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataManager = _G.DataManager -- Loaded by ServerBoot

--============================================================================
-- 1. CONSTANTS & SIMULATION CONFIGURATION
--============================================================================

local TICK_INTERVAL = 0.20 -- 5 Hz Server Heartbeat
local MASTER_FORMATION_RADIUS = 5.5
local LEASH_DISTANCE = 65.0

-- Whistle Constants
local OVERDRIVE_COOLDOWN = 20.0
local OVERDRIVE_DURATION = 5.0
local OVERDRIVE_STAMINA_COST = 5.0
local OVERDRIVE_ATK_SPEED_MULT = 1.40

local RECALL_COOLDOWN = 6.0
local RECALL_PACIFY_DURATION = 2.0 -- Disables hero aggro for 2s after [E] Recall

-- World Boss ("The Dimensional Sovereign") Constants
local WORLD_BOSS_ORIGIN = Vector3.new(0, 16, 0)
local NOVA_INTERVAL = 20.0
local NOVA_TELEGRAPH_DURATION = 3.0
local NOVA_BLAST_RADIUS = 85.0 -- Safe Rim is R = 85..120 studs on Ring 3
local NOVA_PUNISH_DURATION = 5.0
local NOVA_PUNISH_DAMAGE_MULT = 1.25
local COMA_DURATION_DEFAULT = 60

--============================================================================
-- 2. RUNTIME SIMULATION TYPES
--============================================================================

export type HeroSimState = "FOLLOW_MASTER" | "MOVE_TO_TARGET" | "ATTACKING" | "COMA"

export type SimHero = {
	NetId: number,
	Owner: Player,
	HeroUUID: string,
	State: HeroSimState,
	Position: Vector3,
	Yaw: number,
	CurrentHP: number,
	MaxHP: number,
	EffectiveATK: number,
	AttackRange: number,
	AttackInterval: number,
	MoveSpeed: number,
	Stamina: number,
	SlotIndex: number, -- 1 to 5
	TargetNetId: number?,
	AttackCooldown: number,
	PacifiedUntil: number, -- Set by [E] Emergency Recall Whistle (os.clock() + 2.0s)
	OverdriveUntil: number, -- Set by [Q] Overdrive Whistle (os.clock() + 5.0s)
}

export type SimMob = {
	NetId: number,
	MobType: "RING1_MOB" | "RING2_ELITE" | "RIFT_BOSS" | "WORLD_BOSS",
	RingIndex: number, -- 1, 2, or 3
	Position: Vector3,
	HomePosition: Vector3,
	CurrentHP: number,
	MaxHP: number,
	ATK: number,
	AttackInterval: number,
	AttackCooldown: number,
	IsAlive: boolean,
	-- World Boss Specific State
	Phase: number, -- 1 (100-50%), 2 (50-25%), 3 (<25% Enrage)
	NextNovaCastTime: number,
	NovaDetonateTime: number?, -- Non-nil while 3.0s Devouring Nova telegraph is active
	PunishWindowUntil: number, -- +25% incoming damage for 5.0s after Nova detonation
	DamageLedger: { [number]: number }, -- [UserId] = RawDamageDealt
}

export type MasterCombatState = {
	FocusedTargetNetId: number?,
	LastOverdriveClock: number,
	LastRecallClock: number,
	DeployedHeroes: { [string]: SimHero }, -- [HeroUUID] = SimHero
}

--============================================================================
-- 3. STATE TABLES & NETWORK REFERENCES
--============================================================================

local NextNetId = 1
local function allocateNetId(): number
	local id = NextNetId
	NextNetId = (NextNetId % 65000) + 1
	return id
end

local ActiveMasters: { [Player]: MasterCombatState } = {}
local ActiveHeroesByNetId: { [number]: SimHero } = {}
local ActiveMobsByNetId: { [number]: SimMob } = {}
local ActiveWorldBoss: SimMob? = nil

-- Remotes
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatRemotes")
local ReplicationTickRemote = RemotesFolder:WaitForChild("ReplicationTick") :: UnreliableRemoteEvent
local FocusTargetRemote = RemotesFolder:WaitForChild("FocusTarget") :: RemoteEvent
local WhistleCommandRemote = RemotesFolder:WaitForChild("WhistleCommand") :: RemoteEvent
local BossTelegraphRemote = RemotesFolder:WaitForChild("BossTelegraph") :: RemoteEvent

--============================================================================
-- 4. HELPER FUNCTIONS (STAT FORMULAS & RING QUERIES)
--============================================================================

local function getHorizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getZoneStaminaDrainPerSec(pos: Vector3): number
	local r = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	if r <= 120 then
		return 1.50 -- Ring 3 (Center Boss Altar)
	elseif r <= 280 then
		return 1.20 -- Ring 2 (Corrupted Grove)
	elseif r <= 460 then
		return 0.80 -- Ring 1 (Outer Ruins)
	end
	return 0.0 -- Safe Zone / Waiting Room Plot
end

local function computeEffectiveStats(player: Player, heroData: any): (number, number)
	local s = heroData.Stars
	local l = heroData.Level
	local q = heroData.QualityScalar or 1.0
	local levelScalar = 1 + 0.08 * (l - 1)

	local profile = DataManager and DataManager.GetProfile(player)
	local pactBonus = (profile and profile.Social.ActivePactPartnerUserId ~= nil) and 0.20 or 0.0

	-- BaseATK and BaseHP in HeroInstance already store the 1.65^(S-1) promotion multiplier
	local effATK = math.round(heroData.BaseATK * q * levelScalar * (1 + pactBonus))
	local effHP = math.round(heroData.BaseHP * q * levelScalar)
	return effATK, effHP
end

local function getFormationOffset(slotIndex: number): Vector3
	local angle = ((slotIndex - 1) / 5) * (math.pi * 2)
	return Vector3.new(
		math.cos(angle) * MASTER_FORMATION_RADIUS,
		0,
		math.sin(angle) * MASTER_FORMATION_RADIUS
	)
end

local function getMasterRootPosition(player: Player): Vector3?
	local char = player.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and hrp.Position or nil
end

--============================================================================
-- 5. COMA & INFIRMARY RECALL LOGIC
--============================================================================

local function knockHeroIntoComa(simHero: SimHero, comaSeconds: number)
	simHero.State = "COMA"
	simHero.CurrentHP = 0
	simHero.TargetNetId = nil

	-- Update persistent HeroInstance in DataManager & recall to Infirmary
	local profile = DataManager and DataManager.GetProfile(simHero.Owner)
	if profile then
		local heroInstance = profile.Heroes[simHero.HeroUUID]
		if heroInstance then
			heroInstance.CurrentStamina = 0
			heroInstance.ComaUntilTimestamp = os.time() + comaSeconds
			heroInstance.Assignment = "FACILITY_INFIRMARY"
		end
	end

	-- Remove from active combat simulation
	ActiveHeroesByNetId[simHero.NetId] = nil
	local masterState = ActiveMasters[simHero.Owner]
	if masterState then
		masterState.DeployedHeroes[simHero.HeroUUID] = nil
	end
end

--============================================================================
-- 6. MASTER COMMAND HANDLERS ([CLICK] FOCUS, [Q] OVERDRIVE, [E] RECALL)
--============================================================================

-- [Click / Tap] Focus Target
FocusTargetRemote.OnServerEvent:Connect(function(player: Player, targetNetId: any)
	if type(targetNetId) ~= "number" then
		return
	end
	local masterState = ActiveMasters[player]
	local masterPos = getMasterRootPosition(player)
	if not masterState or not masterPos then
		return
	end

	-- Target can be a live Mob OR a Rogue Master's SimHero in Ring 1 / Ring 2
	local targetMob = ActiveMobsByNetId[targetNetId]
	local targetHero = ActiveHeroesByNetId[targetNetId]

	if targetMob and targetMob.IsAlive then
		if getHorizontalDistance(masterPos, targetMob.Position) <= 85 then
			masterState.FocusedTargetNetId = targetNetId
			for _, simHero in pairs(masterState.DeployedHeroes) do
				if simHero.State ~= "COMA" then
					simHero.TargetNetId = targetNetId
					simHero.PacifiedUntil = 0 -- Explicit focus command overrides post-recall pacify
					simHero.State = "MOVE_TO_TARGET"
				end
			end
		end
	elseif targetHero and targetHero.Owner ~= player then
		-- Verify PvP legality: Target owner must have stolen loot (Theft Grudge), or be tagged as Loot Thief
		local targetOwner = targetHero.Owner
		local isAuthorizedPvP = false

		if TheftGrudges[player.UserId] and (TheftGrudges[player.UserId][targetOwner.UserId] or 0) > os.clock() then
			isAuthorizedPvP = true
		elseif TheftGrudges[targetOwner.UserId] and (TheftGrudges[targetOwner.UserId][player.UserId] or 0) > os.clock() then
			isAuthorizedPvP = true
		elseif targetOwner.Character and targetOwner.Character:GetAttribute("IsLootThief") == true then
			isAuthorizedPvP = true
		elseif DataManager and DataManager.IsPlayerRogue and DataManager.IsPlayerRogue(targetOwner) then
			isAuthorizedPvP = true
		end

		if isAuthorizedPvP then
			masterState.FocusedTargetNetId = targetNetId
			for _, simHero in pairs(masterState.DeployedHeroes) do
				if simHero.State ~= "COMA" then
					simHero.TargetNetId = targetNetId
					simHero.PacifiedUntil = 0
					simHero.State = "MOVE_TO_TARGET"
				end
			end
			-- Grant reciprocal retaliation right to defender
			TheftGrudges[targetOwner.UserId] = TheftGrudges[targetOwner.UserId] or {}
			TheftGrudges[targetOwner.UserId][player.UserId] = math.max(TheftGrudges[targetOwner.UserId][player.UserId] or 0, os.clock() + 120)
		end
	end
end)

-- [Q] Overdrive Whistle & [E] Emergency Recall Whistle
WhistleCommandRemote.OnServerEvent:Connect(function(player: Player, commandCode: any)
	if type(commandCode) ~= "number" then
		return
	end
	local masterState = ActiveMasters[player]
	local masterPos = getMasterRootPosition(player)
	if not masterState or not masterPos then
		return
	end

	local now = os.clock()

	if commandCode == 1 then
		-- [Q] OVERDRIVE WHISTLE (20s CD, -5 Stamina/hero, +40% Attack Speed for 5s)
		if (now - masterState.LastOverdriveClock) < OVERDRIVE_COOLDOWN then
			return
		end
		masterState.LastOverdriveClock = now

		local profile = DataManager and DataManager.GetProfile(player)
		for uuid, simHero in pairs(masterState.DeployedHeroes) do
			if simHero.State ~= "COMA" and simHero.Stamina >= OVERDRIVE_STAMINA_COST then
				simHero.Stamina = math.max(0, simHero.Stamina - OVERDRIVE_STAMINA_COST)
				simHero.OverdriveUntil = now + OVERDRIVE_DURATION
				if profile and profile.Heroes[uuid] then
					profile.Heroes[uuid].CurrentStamina = simHero.Stamina
				end
			end
		end

	elseif commandCode == 2 then
		-- [E] EMERGENCY RECALL WHISTLE (6s CD, instant warp to Master + 2s aggro drop)
		if (now - masterState.LastRecallClock) < RECALL_COOLDOWN then
			return
		end
		masterState.LastRecallClock = now
		masterState.FocusedTargetNetId = nil

		for _, simHero in pairs(masterState.DeployedHeroes) do
			if simHero.State ~= "COMA" then
				simHero.Position = masterPos + getFormationOffset(simHero.SlotIndex)
				simHero.TargetNetId = nil
				simHero.State = "FOLLOW_MASTER"
				simHero.PacifiedUntil = now + RECALL_PACIFY_DURATION
			end
		end
	end
end)

--============================================================================
-- 7. WORLD BOSS ("THE DIMENSIONAL SOVEREIGN") & DEVOURING NOVA SIMULATION
--============================================================================

local function stepWorldBoss(boss: SimMob, dt: number, now: number)
	if not boss.IsAlive then
		return
	end

	-- Update Boss Phase based on HP thresholds (100%-50%, 50%-25%, <25% Enrage)
	local hpRatio = boss.CurrentHP / boss.MaxHP
	if hpRatio <= 0.25 then
		boss.Phase = 3
	elseif hpRatio <= 0.50 then
		boss.Phase = 2
	else
		boss.Phase = 1
	end

	-- 1. Check if Devouring Nova 3.0s Telegraph should start (Every 20.0s)
	if boss.NovaDetonateTime == nil and now >= boss.NextNovaCastTime then
		boss.NovaDetonateTime = now + NOVA_TELEGRAPH_DURATION
		boss.NextNovaCastTime = now + NOVA_INTERVAL

		-- Phase 2+ Gravity Well: Pull all heroes on Ring 3 inward before Nova telegraph
		if boss.Phase >= 2 then
			for _, simHero in pairs(ActiveHeroesByNetId) do
				local dist = getHorizontalDistance(simHero.Position, WORLD_BOSS_ORIGIN)
				if dist <= 120 then
					local dir = (simHero.Position - WORLD_BOSS_ORIGIN)
					local unitXZ = Vector3.new(dir.X, 0, dir.Z)
					if unitXZ.Magnitude > 0.01 then
						unitXZ = unitXZ.Unit
					else
						unitXZ = Vector3.new(1, 0, 0)
					end
					simHero.Position = WORLD_BOSS_ORIGIN + (unitXZ * 15.0)
				end
			end
		end

		-- Broadcast 3.0s red blast zone telegraph to all clients
		BossTelegraphRemote:FireAllClients(
			1, -- 1 = DEVOURING_NOVA
			Vector2int16.new(math.round(WORLD_BOSS_ORIGIN.X), math.round(WORLD_BOSS_ORIGIN.Z)),
			NOVA_BLAST_RADIUS,
			math.round(NOVA_TELEGRAPH_DURATION * 1000)
		)
	end

	-- 2. Check if Devouring Nova Detonates on this tick (t = 3.0s)
	if boss.NovaDetonateTime ~= nil and now >= boss.NovaDetonateTime then
		boss.NovaDetonateTime = nil
		boss.PunishWindowUntil = now + NOVA_PUNISH_DURATION -- 5.0s +25% Core Exposed window!

		-- Evaluate "Greed vs. Coma" AoE Hit Detection (Radius <= 85 studs)
		for _, simHero in pairs(ActiveHeroesByNetId) do
			if simHero.State ~= "COMA" then
				local distFromAltar = getHorizontalDistance(simHero.Position, WORLD_BOSS_ORIGIN)
				if distFromAltar <= NOVA_BLAST_RADIUS then
					-- Hero was left inside the red zone!
					if simHero.Stamina > 50.0 and boss.Phase == 1 then
						-- Instant 50% Stamina loss + 40% MaxHP damage
						simHero.Stamina = math.max(0, simHero.Stamina - 50.0)
						simHero.CurrentHP = math.max(1, simHero.CurrentHP - math.round(simHero.MaxHP * 0.40))
						local profile = DataManager and DataManager.GetProfile(simHero.Owner)
						if profile and profile.Heroes[simHero.HeroUUID] then
							profile.Heroes[simHero.HeroUUID].CurrentStamina = simHero.Stamina
						end
					else
						-- Knocked into a 60-second Coma & warped to Infirmary!
						knockHeroIntoComa(simHero, COMA_DURATION_DEFAULT)
					end
				end
			end
		end
	end
end

--============================================================================
-- 8. CORE 5 HZ (0.20s) HERO & COMBAT STATE MACHINE
--============================================================================

local function resolveTargetPositionAndAlive(targetNetId: number?): (Vector3?, SimMob?, SimHero?)
	if not targetNetId then
		return nil, nil, nil
	end
	local mob = ActiveMobsByNetId[targetNetId]
	if mob and mob.IsAlive then
		return mob.Position, mob, nil
	end
	local enemyHero = ActiveHeroesByNetId[targetNetId]
	if enemyHero and enemyHero.State ~= "COMA" then
		return enemyHero.Position, nil, enemyHero
	end
	return nil, nil, nil
end

local function stepHeroSimulation(simHero: SimHero, dt: number, now: number)
	if simHero.State == "COMA" then
		return
	end

	local masterPos = getMasterRootPosition(simHero.Owner)
	if not masterPos then
		return
	end

	-- Refresh Dynamic EffectiveATK (accounts for Blood Pact +20% ATK changes)
	local profile = DataManager and DataManager.GetProfile(simHero.Owner)
	if profile and profile.Heroes[simHero.HeroUUID] then
		local effATK, effHP = computeEffectiveStats(simHero.Owner, profile.Heroes[simHero.HeroUUID])
		simHero.EffectiveATK = effATK
		simHero.MaxHP = effHP
	end

	-- 1. Leash Check: If hero is too far from Master, snap back to FOLLOW_MASTER
	if getHorizontalDistance(simHero.Position, masterPos) > LEASH_DISTANCE then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

	-- 2. Pacified Override Check (2.0s after [E] Emergency Recall Whistle)
	local isPacified = now < simHero.PacifiedUntil
	if isPacified then
		simHero.TargetNetId = nil
		simHero.State = "FOLLOW_MASTER"
	end

	local isOverdrive = now < simHero.OverdriveUntil
	local isExhausted = simHero.Stamina <= 0.0
	local currentMoveSpeed = simHero.MoveSpeed
		* (isOverdrive and 1.20 or 1.0)
		* (isExhausted and 0.50 or 1.0)

	-- 3. State Machine Transitions & Execution
	local targetPos, targetMob, targetEnemyHero = resolveTargetPositionAndAlive(simHero.TargetNetId)

	if not targetPos and not isPacified then
		-- Auto-acquire nearest mob within 28 studs of Master if no explicit target
		local nearestDist = 28.0
		local nearestMobId: number? = nil
		for netId, mob in pairs(ActiveMobsByNetId) do
			if mob.IsAlive then
				local d = getHorizontalDistance(masterPos, mob.Position)
				if d < nearestDist then
					nearestDist = d
					nearestMobId = netId
				end
			end
		end
		if nearestMobId then
			simHero.TargetNetId = nearestMobId
			targetPos, targetMob, targetEnemyHero = resolveTargetPositionAndAlive(nearestMobId)
			simHero.State = "MOVE_TO_TARGET"
		else
			simHero.State = "FOLLOW_MASTER"
		end
	end

	if simHero.State == "FOLLOW_MASTER" or not targetPos then
		local goalPos = masterPos + getFormationOffset(simHero.SlotIndex)
		local delta = goalPos - simHero.Position
		local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if dist > 0.5 then
			local stepDist = math.min(dist, currentMoveSpeed * dt)
			local dir = Vector3.new(delta.X, 0, delta.Z).Unit
			simHero.Position += dir * stepDist
			simHero.Yaw = math.atan2(-dir.X, -dir.Z)
		end
		return
	end

	-- Target is valid: Check Attack Range
	local distToTarget = getHorizontalDistance(simHero.Position, targetPos)
	if distToTarget > simHero.AttackRange then
		simHero.State = "MOVE_TO_TARGET"
		local delta = targetPos - simHero.Position
		local dir = Vector3.new(delta.X, 0, delta.Z).Unit
		local stepDist = math.min(distToTarget - (simHero.AttackRange * 0.85), currentMoveSpeed * dt)
		simHero.Position += dir * math.max(0, stepDist)
		simHero.Yaw = math.atan2(-dir.X, -dir.Z)
	else
		simHero.State = "ATTACKING"
		local delta = targetPos - simHero.Position
		if delta.Magnitude > 0.01 then
			simHero.Yaw = math.atan2(-delta.X, -delta.Z)
		end

		-- Drain Combat Stamina (Reduced by -25% if in an active Blood Pact)
		local drainRate = getZoneStaminaDrainPerSec(simHero.Position)
		if profile and profile.Social.ActivePactPartnerUserId ~= nil then
			drainRate *= 0.75
		end
		simHero.Stamina = math.max(0.0, simHero.Stamina - (drainRate * dt))
		if profile and profile.Heroes[simHero.HeroUUID] then
			profile.Heroes[simHero.HeroUUID].CurrentStamina = simHero.Stamina
		end

		-- Execute Attack on Interval
		local effectiveInterval = simHero.AttackInterval / (isOverdrive and OVERDRIVE_ATK_SPEED_MULT or 1.0)
		simHero.AttackCooldown -= dt
		if simHero.AttackCooldown <= 0 then
			simHero.AttackCooldown = effectiveInterval
			local exhaustionScalar = isExhausted and 0.20 or 1.00
			local damage = math.round(simHero.EffectiveATK * exhaustionScalar)

			if targetMob then
				-- Check World Boss Post-Nova Punish Window (+25% damage)
				if targetMob.MobType == "WORLD_BOSS" and now < targetMob.PunishWindowUntil then
					damage = math.round(damage * NOVA_PUNISH_DAMAGE_MULT)
				end
				targetMob.CurrentHP = math.max(0, targetMob.CurrentHP - damage)
				targetMob.DamageLedger[simHero.Owner.UserId] = (
					targetMob.DamageLedger[simHero.Owner.UserId] or 0
				) + damage

				if targetMob.CurrentHP <= 0 then
					targetMob.IsAlive = false
					simHero.TargetNetId = nil
					simHero.State = "FOLLOW_MASTER"
				end
			elseif targetEnemyHero then
				-- Rogue Master Squad PvP (Deals 25% of PvE EffectiveATK)
				local pvpDamage = math.max(1, math.round(damage * 0.25))
				targetEnemyHero.CurrentHP -= pvpDamage
				if targetEnemyHero.CurrentHP <= 0 then
					knockHeroIntoComa(targetEnemyHero, 30)
				end
			end
		end
	end
end

--============================================================================
-- 9. COMPACT BINARY BUFFER SERIALIZATION & 5 HZ HEARTBEAT LOOP
--============================================================================

local STATE_TO_ENUM: { [HeroSimState]: number } = {
	FOLLOW_MASTER = 1,
	MOVE_TO_TARGET = 2,
	ATTACKING = 3,
	COMA = 4,
}

local function broadcastReplicationSnapshot(now: number)
	local entities: { any } = {}
	for _, h in pairs(ActiveHeroesByNetId) do
		table.insert(entities, { IsHero = true, Ref = h })
	end
	for _, m in pairs(ActiveMobsByNetId) do
		if m.IsAlive then
			table.insert(entities, { IsHero = false, Ref = m })
		end
	end

	local count = math.min(#entities, 255)
	-- 5-byte header + 12 bytes per entity
	local buf = buffer.create(5 + (count * 12))
	buffer.writeu8(buf, 0, count)
	buffer.writef32(buf, 1, now)

	local offset = 5
	for i = 1, count do
		local entry = entities[i]
		local e = entry.Ref
		buffer.writeu16(buf, offset + 0, e.NetId)
		buffer.writei16(buf, offset + 2, math.clamp(math.round(e.Position.X * 10), -32767, 32767))
		buffer.writei16(buf, offset + 4, math.clamp(math.round(e.Position.Z * 10), -32767, 32767))

		local yawByte = math.clamp(math.round(((e.Yaw or 0) + math.pi) / (2 * math.pi) * 255), 0, 255)
		buffer.writeu8(buf, offset + 6, yawByte)

		local stateByte = entry.IsHero and (STATE_TO_ENUM[e.State] or 1) or (10 + (e.Phase or 1))
		buffer.writeu8(buf, offset + 7, stateByte)

		local hpPermille = math.clamp(math.round((e.CurrentHP / math.max(1, e.MaxHP)) * 1000), 0, 1000)
		buffer.writeu16(buf, offset + 8, hpPermille)

		local staminaByte = entry.IsHero and math.clamp(math.round(e.Stamina), 0, 100) or 100
		buffer.writeu8(buf, offset + 10, staminaByte)

		local flags = 0
		if entry.IsHero then
			if now < e.OverdriveUntil then
				flags = bit32.bor(flags, 1)
			end
			if now < e.PacifiedUntil then
				flags = bit32.bor(flags, 2)
			end
		end
		buffer.writeu8(buf, offset + 11, flags)
		offset += 12
	end

	ReplicationTickRemote:FireAllClients(buf)
end

-- Authoritative 5 Hz Accumulator Loop
local accumulator = 0.0
RunService.Heartbeat:Connect(function(deltaTime: number)
	accumulator += deltaTime
	if accumulator < TICK_INTERVAL then
		return
	end

	local dt = accumulator
	accumulator = 0.0
	local now = os.clock()

	if ActiveWorldBoss and ActiveWorldBoss.IsAlive then
		stepWorldBoss(ActiveWorldBoss, dt, now)
	end

	for _, simHero in pairs(ActiveHeroesByNetId) do
		stepHeroSimulation(simHero, dt, now)
	end

	broadcastReplicationSnapshot(now)
end)
```

---

## 5. RELIC & BLOOD PACT SERVICE (`RelicService.server.luau`)

This script manages the physical extraction loop (*Steal an Egg* mechanics) and the **Blood Pact Prisoner's Dilemma**:
- Physical Relic spawning with despawn timers and initial owner-locks (including the **15-second Rank #1 DPS lock** for **The Calamity Heart**).
- Overhead `WeldConstraint` attachment, dynamic WalkSpeed penalties (`-15%` to `-45%`), jump disabling for Mythic/World Boss tiers, **Rogue Master `+10%` carry speed bonus**, and **Saboteur Mercenary `2.5s` Ankle Snare** triggers.
- **AoE Fumble Mechanic:** `1.0s` player stun + physical Relic drop with a `3.0s` owner-lock before any player in the server can steal it.
- **Tandem Relic Carry:** Checks every tick if the carrier's Blood Pact partner is within **`15 studs`**, halving the Relic WalkSpeed penalty (`-45%` $\rightarrow$ `-22.5%`).
- **Split vs. Betray Pad Triggers:** Stepping on a **Shared Pact Pedestal** awards **`75% / 75%` (`150%` total)** + **`+10 Honor`** each; pressing **`[B] Shatter Pact`** and stepping on a **Private Extraction Pad** awards **`130%` to the Betrayer**, **`0%` + `2.0s` Knockback to the Victim**, deducts **`-30 Honor`**, and brands the Betrayer a **Rogue Master for 5 minutes**.

```luau
--!strict
-- ServerScriptService/ExtractionAndSocial/RelicService.server.luau
-- Physical Relic Extraction, Overhead Welding, Fumbles, Tandem Carry (15st), and Blood Pact Split/Betrayal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DataManager = _G.DataManager

--============================================================================
-- 1. RELIC TIER SPECIFICATIONS (LOCKED PROJECT BIBLE)
--============================================================================

export type RelicTierId = "MANA_GEODE" | "CURSED_URN" | "ABYSSAL_CORE" | "CALAMITY_HEART"

export type RelicTierSpec = {
	DisplayName: string,
	WalkSpeedPenalty: number, -- 0.15 to 0.45
	DisableJump: boolean,
	TriggersSaboteurSnare: boolean,
	DespawnSeconds: number,
	InitialLockSeconds: number,
	Payout: {
		Gems: number,
		Gold: number,
		ResearchPoints: number,
	},
}

local RELIC_SPECS: { [RelicTierId]: RelicTierSpec } = {
	MANA_GEODE = {
		DisplayName = "Mana Geode",
		WalkSpeedPenalty = 0.15, -- -15% WalkSpeed
		DisableJump = false,
		TriggersSaboteurSnare = false,
		DespawnSeconds = 90,
		InitialLockSeconds = 3.0,
		Payout = { Gems = 40, Gold = 250, ResearchPoints = 10 },
	},
	CURSED_URN = {
		DisplayName = "Cursed Urn",
		WalkSpeedPenalty = 0.25, -- -25% WalkSpeed
		DisableJump = false,
		TriggersSaboteurSnare = true,
		DespawnSeconds = 120,
		InitialLockSeconds = 3.0,
		Payout = { Gems = 150, Gold = 1200, ResearchPoints = 45 },
	},
	ABYSSAL_CORE = {
		DisplayName = "Abyssal Core",
		WalkSpeedPenalty = 0.35, -- -35% WalkSpeed (Mythic)
		DisableJump = true,
		TriggersSaboteurSnare = true,
		DespawnSeconds = 150,
		InitialLockSeconds = 5.0,
		Payout = { Gems = 450, Gold = 4000, ResearchPoints = 150 },
	},
	CALAMITY_HEART = {
		DisplayName = "The Calamity Heart",
		WalkSpeedPenalty = 0.45, -- -45% WalkSpeed (World Boss Exclusive)
		DisableJump = true,
		TriggersSaboteurSnare = true,
		DespawnSeconds = 180,
		InitialLockSeconds = 15.0, -- 15-second exclusive lock for Rank #1 DPS
		Payout = { Gems = 1500, Gold = 15000, ResearchPoints = 500 },
	},
}

local BASE_WALKSPEED = 16.0
local BASE_JUMPPOWER = 50.0
local TANDEM_CARRY_RADIUS = 15.0 -- Staying within 15 studs halves WalkSpeed penalty
local FUMBLE_STUN_SECONDS = 1.0
local FUMBLE_OWNER_LOCK_SECONDS = 3.0
local SABOTEUR_SNARE_SECONDS = 2.5

--============================================================================
-- 2. RUNTIME RELIC STATE
--============================================================================

export type ActiveRelic = {
	RelicId: number,
	TierId: RelicTierId,
	Part: BasePart,
	Weld: WeldConstraint?,
	Carrier: Player?,
	LockedUserId: number?,
	LockExpiresAt: number,
	DespawnAt: number,
	SaboteurTriggeredForUser: { [number]: boolean },
}

local RelicService = {}
local NextRelicId = 1
local ActiveRelics: { [number]: ActiveRelic } = {}
local CarrierToRelic: { [Player]: ActiveRelic } = {}
local PlayerStunnedUntil: { [Player]: number } = {}

local PhysicalRelicsFolder = Workspace:FindFirstChild("PhysicalRelics") or Instance.new("Folder", Workspace)
PhysicalRelicsFolder.Name = "PhysicalRelics"

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RelicPactRemotes")
local RelicStateRemote = RemotesFolder:WaitForChild("RelicStateChanged") :: RemoteEvent
local BloodPactRemote = RemotesFolder:WaitForChild("BloodPactAction") :: RemoteEvent

--============================================================================
-- 3. WALKSPEED, TANDEM CARRY (15 STUDS) & SABOTEUR SNARE CALCULATION
--============================================================================

local function getCharacterParts(player: Player): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hum, hrp
end

local function isTandemCarryActive(carrier: Player, carrierPos: Vector3): boolean
	local profile = DataManager and DataManager.GetProfile(carrier)
	if not profile or not profile.Social.ActivePactPartnerUserId then
		return false
	end

	local partner = Players:GetPlayerByUserId(profile.Social.ActivePactPartnerUserId)
	if not partner then
		return false
	end

	local _, partnerHRP = getCharacterParts(partner)
	if not partnerHRP then
		return false
	end

	local dist = (partnerHRP.Position - carrierPos).Magnitude
	return dist <= TANDEM_CARRY_RADIUS
end

local function updateMasterMovementAttributes(player: Player, now: number)
	local hum, hrp = getCharacterParts(player)
	if not hum or not hrp then
		return
	end

	-- 1. Check Stun / Saboteur Ankle Snare
	local stunnedUntil = PlayerStunnedUntil[player] or 0
	if now < stunnedUntil then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		return
	end

	-- 2. Check Active Relic Carry Penalty & Modifiers
	local relic = CarrierToRelic[player]
	if not relic then
		hum.WalkSpeed = BASE_WALKSPEED
		hum.JumpPower = BASE_JUMPPOWER
		return
	end

	local spec = RELIC_SPECS[relic.TierId]
	local penalty = spec.WalkSpeedPenalty

	-- Blood Pact Tandem Carry: Halves WalkSpeed penalty if partner is within 15 studs
	if isTandemCarryActive(player, hrp.Position) then
		penalty *= 0.50
	end

	-- Rogue Master Perk: +10% Move Speed while carrying Relics
	local rogueBonus = (DataManager and DataManager.IsPlayerRogue(player)) and 0.10 or 0.0

	local multiplier = math.clamp(1.0 - penalty + rogueBonus, 0.35, 1.25)
	hum.WalkSpeed = BASE_WALKSPEED * multiplier
	hum.JumpPower = spec.DisableJump and 0 or BASE_JUMPPOWER
end

--============================================================================
-- 4. RELIC SPAWNING, OVERHEAD WELDING & FUMBLE MECHANICS
--============================================================================

function RelicService.SpawnRelic(tierId: RelicTierId, worldPos: Vector3, initialOwnerUserId: number?): ActiveRelic
	local spec = RELIC_SPECS[tierId]
	local relicId = NextRelicId
	NextRelicId += 1

	local part = Instance.new("Part")
	part.Name = string.format("Relic_%s_%d", tierId, relicId)
	part.Size = Vector3.new(3.2, 3.8, 3.2)
	part.Position = worldPos + Vector3.new(0, 2.5, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Parent = PhysicalRelicsFolder

	local now = os.clock()
	local relic: ActiveRelic = {
		RelicId = relicId,
		TierId = tierId,
		Part = part,
		Weld = nil,
		Carrier = nil,
		LockedUserId = initialOwnerUserId,
		LockExpiresAt = initialOwnerUserId and (now + spec.InitialLockSeconds) or 0,
		DespawnAt = now + spec.DespawnSeconds,
		SaboteurTriggeredForUser = {},
	}

	ActiveRelics[relicId] = relic
	RelicStateRemote:FireAllClients(relicId, tierId, "SPAWN", initialOwnerUserId, relic.LockExpiresAt)
	return relic
end

function RelicService.TryPickupRelic(player: Player, relic: ActiveRelic): boolean
	local now = os.clock()
	if relic.Carrier ~= nil then
		return false -- Already carried
	end
	if CarrierToRelic[player] ~= nil then
		return false -- Player already carrying a Relic
	end
	if now < (PlayerStunnedUntil[player] or 0) then
		return false -- Stunned players cannot pick up Relics
	end

	-- Check Exclusive Owner-Lock (3s on Fumble, 15s for Rank #1 DPS on Calamity Heart)
	if relic.LockedUserId and relic.LockedUserId ~= player.UserId and now < relic.LockExpiresAt then
		return false
	end

	local hum, hrp = getCharacterParts(player)
	if not hum or not hrp or hum.Health <= 0 then
		return false
	end

	if (hrp.Position - relic.Part.Position).Magnitude > 9.0 then
		return false
	end

	-- Weld Relic Overhead
	relic.Part.Anchored = false
	relic.Part.CFrame = hrp.CFrame * CFrame.new(0, 5.2, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = relic.Part
	weld.Parent = relic.Part

	relic.Weld = weld
	relic.Carrier = player
	CarrierToRelic[player] = relic

	-- Check if Renter has an active SABOTEUR Mercenary! (2.5s Ankle Snare on Rare/Mythic/Calamity pickup)
	local spec = RELIC_SPECS[relic.TierId]
	if spec.TriggersSaboteurSnare and not relic.SaboteurTriggeredForUser[player.UserId] then
		local syndicateService = _G.SyndicateService
		if syndicateService and syndicateService.HasActiveSaboteurMercenary(player) then
			relic.SaboteurTriggeredForUser[player.UserId] = true
			PlayerStunnedUntil[player] = now + SABOTEUR_SNARE_SECONDS
			syndicateService.ConsumeSaboteurSnare(player)
		end
	end

	updateMasterMovementAttributes(player, now)
	RelicStateRemote:FireAllClients(relic.RelicId, relic.TierId, "PICKUP", player.UserId, 0)
	return true
end

-- Triggered when an Elite or Boss AoE hits a Relic Carrier (1s Stun + Drop + 3s Owner-Lock)
function RelicService.FumbleRelicOnAoEHit(carrier: Player)
	local relic = CarrierToRelic[carrier]
	if not relic then
		return
	end

	local now = os.clock()
	if relic.Weld then
		relic.Weld:Destroy()
		relic.Weld = nil
	end

	local _, hrp = getCharacterParts(carrier)
	local dropPos = hrp and (hrp.Position + Vector3.new(0, -1.0, 0)) or relic.Part.Position

	relic.Carrier = nil
	CarrierToRelic[carrier] = nil
	relic.Part.Anchored = true
	relic.Part.Position = dropPos
	relic.LockedUserId = carrier.UserId
	relic.LockExpiresAt = now + FUMBLE_OWNER_LOCK_SECONDS

	-- Apply 1.0-second Stun to the Carrier
	PlayerStunnedUntil[carrier] = math.max(PlayerStunnedUntil[carrier] or 0, now + FUMBLE_STUN_SECONDS)
	updateMasterMovementAttributes(carrier, now)

	RelicStateRemote:FireAllClients(
		relic.RelicId,
		relic.TierId,
		"FUMBLE",
		carrier.UserId,
		relic.LockExpiresAt
	)
end

--============================================================================
-- 5. BLOOD PACT SHATTER [B] & EXTRACTION PAD RESOLUTION (SPLIT VS. BETRAY)
--============================================================================

local function awardRelicPayout(player: Player, spec: RelicTierSpec, scalar: number)
	local profile = DataManager and DataManager.GetProfile(player)
	if not profile then
		return
	end
	profile.Currencies.Gems += math.round(spec.Payout.Gems * scalar)
	profile.Currencies.Gold += math.round(spec.Payout.Gold * scalar)
	profile.Currencies.ResearchPoints += math.round(spec.Payout.ResearchPoints * scalar)
end

local function destroyRelicInstance(relic: ActiveRelic)
	if relic.Carrier then
		local carrier = relic.Carrier
		CarrierToRelic[carrier] = nil
		relic.Carrier = nil
		updateMasterMovementAttributes(carrier, os.clock())
	end
	if relic.Weld then
		relic.Weld:Destroy()
	end
	if relic.Part then
		relic.Part:Destroy()
	end
	ActiveRelics[relic.RelicId] = nil
end

-- Option 1: Carrier steps on a Shared Pact Pedestal (Both get 75% = 150% total + +10 Honor each)
function RelicService.ExtractOnSharedPactPedestal(carrier: Player, pedestalPart: BasePart)
	local relic = CarrierToRelic[carrier]
	if not relic then
		return
	end

	local profile = DataManager and DataManager.GetProfile(carrier)
	if not profile or not profile.Social.ActivePactPartnerUserId then
		return
	end

	local partner = Players:GetPlayerByUserId(profile.Social.ActivePactPartnerUserId)
	if not partner then
		return
	end

	local _, partnerHRP = getCharacterParts(partner)
	if not partnerHRP or (partnerHRP.Position - pedestalPart.Position).Magnitude > 35.0 then
		return -- Partner must be near the Shared Pact Pedestal to complete cooperative ritual
	end

	local spec = RELIC_SPECS[relic.TierId]
	awardRelicPayout(carrier, spec, 0.75)
	awardRelicPayout(partner, spec, 0.75)

	DataManager.AdjustHonor(carrier, 10, false)
	DataManager.AdjustHonor(partner, 10, false)
	profile.Social.Stats.PactsHonored += 1

	RelicStateRemote:FireAllClients(relic.RelicId, relic.TierId, "EXTRACT_SHARED", carrier.UserId, 0)
	destroyRelicInstance(relic)
end

-- Option 2: Carrier steps on their Private Extraction Pad (100% normal, OR 130% if they just shattered a Pact!)
function RelicService.ExtractOnPrivatePad(carrier: Player)
	local relic = CarrierToRelic[carrier]
	if not relic then
		return
	end

	local profile = DataManager and DataManager.GetProfile(carrier)
	if not profile then
		return
	end

	local spec = RELIC_SPECS[relic.TierId]
	local recentlyShattered = (os.time() - profile.Social.LastShatterTimestamp) <= 30
	local payoutScalar = recentlyShattered and 1.30 or 1.00

	awardRelicPayout(carrier, spec, payoutScalar)
	RelicStateRemote:FireAllClients(relic.RelicId, relic.TierId, "EXTRACT_PRIVATE", carrier.UserId, 0)
	destroyRelicInstance(relic)
end

-- Blood Pact Network Handler (Form Pact & [B] Shatter Pact)
BloodPactRemote.OnServerEvent:Connect(function(player: Player, actionType: any, targetUserId: any)
	if type(actionType) ~= "number" then
		return
	end

	local profile = DataManager and DataManager.GetProfile(player)
	if not profile then
		return
	end

	if actionType == 3 then
		-- [B] SHATTER PACT
		local partnerUserId = profile.Social.ActivePactPartnerUserId
		if not partnerUserId then
			return
		end

		local partner = Players:GetPlayerByUserId(partnerUserId)
		local partnerProfile = partner and DataManager.GetProfile(partner)

		-- Clear Pact links on both profiles
		profile.Social.ActivePactPartnerUserId = nil
		if partnerProfile then
			partnerProfile.Social.ActivePactPartnerUserId = nil
		end

		local isCarryingRelic = (CarrierToRelic[player] ~= nil)
		if isCarryingRelic then
			-- BETRAYAL! Brand Betrayer as Rogue Master for 5m (-30 Honor) & Knockback Victim for 2.0s
			DataManager.AdjustHonor(player, -30, true)

			if partner then
				PlayerStunnedUntil[partner] = os.clock() + 2.0
				updateMasterMovementAttributes(partner, os.clock())

				local _, betrayerHRP = getCharacterParts(player)
				local _, victimHRP = getCharacterParts(partner)
				if betrayerHRP and victimHRP and (victimHRP.Position - betrayerHRP.Position).Magnitude <= 30 then
					local pushDir = (victimHRP.Position - betrayerHRP.Position)
					local unitXZ = Vector3.new(pushDir.X, 0, pushDir.Z)
					if unitXZ.Magnitude > 0.01 then
						unitXZ = unitXZ.Unit
					else
						unitXZ = Vector3.new(0, 0, 1)
					end
					victimHRP.AssemblyLinearVelocity = (unitXZ * 55) + Vector3.new(0, 28, 0)
				end
			end
		end

		BloodPactRemote:FireAllClients(3, player.UserId, partnerUserId, isCarryingRelic)
	end
end)

--============================================================================
-- 6. CONTINUOUS PROXIMITY, DESPAWN & TANDEM CARRY HEARTBEAT
--============================================================================

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	-- 1. Check Relic Despawns & Uncarried Proximity Pickups
	for relicId, relic in pairs(ActiveRelics) do
		if relic.Carrier == nil then
			if now >= relic.DespawnAt then
				destroyRelicInstance(relic)
			else
				for _, player in ipairs(Players:GetPlayers()) do
					local _, hrp = getCharacterParts(player)
					if hrp and (hrp.Position - relic.Part.Position).Magnitude <= 6.5 then
						if RelicService.TryPickupRelic(player, relic) then
							break
						end
					end
				end
			end
		end
	end

	-- 2. Update WalkSpeeds for Active Carriers (Tandem 15-stud check & Stun expiry)
	for _, player in ipairs(Players:GetPlayers()) do
		if CarrierToRelic[player] or (PlayerStunnedUntil[player] and now <= PlayerStunnedUntil[player] + 0.5) then
			updateMasterMovementAttributes(player, now)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	-- Edge-Case Rule: If Carrier disconnects mid-carry, drop Relic immediately with 0s lock
	local relic = CarrierToRelic[player]
	if relic then
		RelicService.FumbleRelicOnAoEHit(player)
		relic.LockedUserId = nil
		relic.LockExpiresAt = 0
	end
	PlayerStunnedUntil[player] = nil
end)

_G.RelicService = RelicService
return RelicService
```
