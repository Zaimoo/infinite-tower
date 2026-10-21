# DOCUMENT 2: TECHNICAL ARCHITECTURE & LUAU SPECIFICATION
**Project Codename:** *Project: Waiting Room* (*Infinite Towers: Become a Master!*)  
**Architecture Standard:** `--!strict` Roblox Luau | Zero Server-Side Humanoids | 5 Hz (`0.20s`) Server Simulation Loop | 60 FPS Client `RenderStepped` Interpolation | 14-Byte Binary Buffer Replication | Profile Session-Locked Persistence

---

## 1. FULL ROBLOX STUDIO FOLDER HIERARCHY

To guarantee zero server-side `Humanoid` overhead while maintaining crisp 60 FPS visuals for deployed combat heroes, Tycoon worker heroes, tower mobs/Elites, and the World Boss, the project strictly separates **Server Authority (Data Tables & Navigation)** from **Client Presentation (R15 Visual Rigs, Weapons & Gothic UI)**.

```text
game
├── Workspace
│   ├── BaseOverhaulGeometry
│   │   ├── CentralCrimsonTower       -- 18-floor walkable tower with ascent ramps & center fountain
│   │   └── IslandTowerBridges        -- High-elevation stone bridges connecting floating islands to tower
│   ├── ArenaRings
│   │   ├── Ring1_OuterRuins          -- Outer annulus surrounding the central structure
│   │   ├── Ring2_CorruptedGrove      -- Mid-tier annulus with Elite mobs
│   │   └── Ring3_CenterBossAltar     -- Center altar for World Boss & Rift Warden encounters
│   ├── PerimeterHighway              -- R >= 460 studs safe banking boundary
│   ├── WaitingRoomPlots              -- 5 Floating Plot Islands (Plot_1 .. Plot_5 at 72° spacing)
│   │   ├── Plot_1 .. Plot_5
│   │   │   ├── FloatingFortressIsland -- Island terrain mesh, perimeter walls, and central plaza
│   │   │   ├── PlotSpawn             -- Player SpawnLocation
│   │   │   ├── PrivateExtractionPad  -- Glowing platform for banking cargo
│   │   │   ├── SummoningAltar        -- Gacha Obelisk + The Pit Cauldron
│   │   │   ├── Facility_ManaConduit  -- 3 Worker Pedestals + Gem Chest
│   │   │   ├── Facility_Infirmary    -- 3 Worker Pedestals + 5 Recuperation Beds
│   │   │   ├── Facility_Blacksmith   -- 3D Anvil, glowing coals, furnace, workbench, and prompt
│   │   │   └── ActivePlotWorkers     -- Dynamic 3D physical worker models & sleeping bed avatars
│   │   └── Plot_6                    -- Reserved / hidden legacy slot
│   ├── PhysicalLoot                  -- Universal collectible physical drops (Gold bags, Gem crystals)
│   ├── PhysicalRelics                -- Server-managed BaseParts (WeldConstraint overhead)
│   └── ClientVisualEntities          -- Client-only folder (Ignored by Server Physics; R15 Rigs & Mobs)
│
├── ReplicatedStorage
│   ├── Remotes                       -- Network Layer (Auto-registered at boot)
│   │   ├── CombatRemotes             -- ReplicationTick, FocusTarget, WhistleCommand, BossTelegraph, CombatVFX, EntityMetadataSync, WorldBossTrigger, LootStolenAlert, SquadWipeState, CarriedLootSync, DropCarriedItem
│   │   ├── RelicPactRemotes          -- RelicStateChanged, BountyDropped
│   │   ├── TycoonGachaRemotes        -- RequestSummon, SynthesizeHeroes, PromoteHeroStar, AssignHeroRole, FacilityInteract
│   │   ├── ArtifactRemotes           -- RequestEquipArtifact, RequestUnequipArtifact, RequestUpgradeRarity
│   │   └── SyndicateRemotes          -- PlotEspionage, ProfileDeltaSync, SystemToast
│   ├── Shared
│   │   ├── Config
│   │   │   ├── ArtifactCatalog.luau  -- Weapons, 7 Star Tiers, 16 Rarity Tiers, Blacksmith upgrade costs
│   │   │   ├── FacilityConfig.luau   -- Levels 1-5 upgrade costs (Gold only), caps
│   │   │   ├── HeroCatalog.luau      -- Roster seed stats, archetypes, traits, banner weights
│   │   │   ├── PitBalanceConfig.luau -- Pit costs, EXP formulas, imprint definitions, promotion materials
│   │   │   ├── RelicConfig.luau      -- Speed penalties, despawn times, drop rates, Gold/Gem payouts
│   │   │   └── WorldBossConfig.luau  -- Mob specs, Sovereign phases, direct loot rankings
│   │   └── Util
│   │       ├── GothicBoxStyle.luau   -- Obsidian & white filigree UI container styling
│   │       ├── PitMath.luau          -- Synthesis preview, imprint matching, conversion calculations
│   │       └── StatFormulas.luau     -- Mathematical formulas (Level XP, Promotion, Labor, Combat DPS)
│   └── Assets                        -- Rigs, Mob Rigs, Relics, Weapons, Props, and ArtPackVisuals
│
├── ServerScriptService
│   ├── BaseOverhaul
│   │   ├── BridgeBuilder.luau        -- High-elevation stone bridge construction
│   │   ├── FountainBuilder.luau      -- Central plaza gothic fountain model
│   │   ├── IslandBuilder.luau        -- Floating island rock geometry and foundation
│   │   ├── LightingAndEffects.luau   -- Atmospheric lighting, fog, and skybox setup
│   │   ├── PlaceIslandsInRing.server.luau -- Master runner for island ring & safety catch plane
│   │   ├── TowerBuilder.luau         -- Procedural 18-floor Crimson Tower generator
│   │   └── WallsBuilder.luau         -- Castle battlements and fortress wall builder
│   ├── Combat
│   │   └── CombatSimulation.server.luau -- 5 Hz zero-humanoid engine, 14-byte replication, Contested Loot, Retaliation PvP
│   ├── Core
│   │   ├── DataManager.server.luau   -- Profiles, session management, Gacha, Blacksmith upgrades, artifact persistence
│   │   ├── HeroNavigation.luau       -- Grounded waypoint navigation, slope and clearance verification
│   │   ├── PitService.luau           -- Authoritative synthesis, promotion, and imprint transactions
│   │   ├── PlotBuildingPlacement.server.luau -- Facility placement runner
│   │   ├── PlotBuildings.luau        -- Facility layout logic
│   │   ├── PlotFacilityArchitecture.luau -- Facility geometry generator
│   │   ├── PlotManager.server.luau   -- 5-island plot allocation, respawn binding, worker 3D models
│   │   ├── TowerTraversal.luau       -- Collision-checked tower ramp traversal and waypoint routing
│   │   └── TowerTraversalSetup.server.luau -- Traversal initialization
│   ├── ExtractionAndSocial
│   │   ├── RelicService.server.luau  -- Relic spawning, welds, slow penalties, fumbles, extraction pads
│   │   └── SyndicateService.server.luau -- Waiting room espionage (Bless vs Leech, 15s Purge, Mimic chest)
│   └── Tycoon
│       ├── BlacksmithService.server.luau -- 3D Blacksmith Forge stations, prompts, and upgrade integration
│       └── WaitingRoomService.server.luau -- 1 Hz facility production (Mana Conduit & Infirmary)
│
└── StarterPlayer.StarterPlayerScripts
    ├── Input
    │   └── MasterController.client.luau -- Click raycast, [Shift] Sprint, [Q], [E] hotkeys, ProximityPrompts
    ├── Rendering
    │   ├── EntityRenderer.client.luau -- 5 Hz 14-byte buffer unpacker, 60 FPS lerp, unit status billboards, weapon socketing
    │   └── HoldingAnimationController.client.luau -- Upper-arm holding pose animation for carrying physical loot
    └── UI
        ├── FacilityController.luau   -- Focused facility HUDs (Summoning, Infirmary, Squad Management)
        ├── GothicBoxStyle.luau       -- Client-side container styling helper
        ├── HeroCard.luau             -- Reusable hero card UI component
        ├── HUDController.client.luau -- 60 FPS HUD, Gothic bottom toolbar, bottom-left currencies, modals
        ├── PitController.luau        -- Pit interface wrapper
        ├── PitDesignTokens.luau      -- Design tokens and color palette for The Pit
        └── SynthesisController.luau  -- Dedicated Synthesis UI modal (recipient slot, 5 material slots, preview)
```

---

## 2. DATASTORE SCHEMA & TYPES (`DataManager.server.luau`)

This module defines the authoritative `--!strict` Luau type definitions (`HeroInstance`, `ArtifactInstance`, `SocialProfile`, `PlayerProfile`) using flat UUID dictionaries for $O(1)$ lookups, implements session-locked persistence, and exposes atomic transaction methods for Synthesis, Star Promotion, Artifact Refinement, and Honor tracking.

```luau
--!strict
local ArtifactCatalog = require(game:GetService("ReplicatedStorage").Shared.Config.ArtifactCatalog)

export type HeroRoleAssignment = 
	| "SQUAD_SLOT_1" | "SQUAD_SLOT_2" | "SQUAD_SLOT_3" | "SQUAD_SLOT_4" | "SQUAD_SLOT_5"
	| "FACILITY_CONDUIT"
	| "FACILITY_INFIRMARY"
	| "BENCHED"

export type HeroInstance = {
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Stars: number,
	Level: number,
	CurrentXP: number,
	MaxXP: number,
	BaseHP: number,
	BaseATK: number,
	AttackInterval: number,
	AttackRange: number,
	BaseLabor: number,
	CurrentStamina: number,
	MaxStamina: number,
	QualityScalar: number,
	Assignment: HeroRoleAssignment,
	Locked: boolean,
	ComaUntilTimestamp: number,
	EquippedArtifactUUID: string?,
	InheritedImprints: { [string]: number }?,
}

export type ArtifactInstance = {
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Type: ArtifactCatalog.WeaponType,
	Star: number,      -- 1..7 (Permanent base potential)
	Rarity: number,    -- 1..16 (Common -> Origin multiplier)
	EquippedHeroUUID: string?,
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
	GarnishedGemDebt: number,
	MimicIllusionMode: "TRUE_STATE" | "FOOLS_GOLD" | "VEIL_OF_POVERTY",
	Stats: {
		RoguesDefeated: number,
		LeechesPurged: number,
	},
}

export type PlayerProfile = {
	SchemaVersion: number,
	UnlockedResearch: { [string]: boolean }?, -- Legacy Pit compatibility only
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
```

---

## 3. NETWORK PROTOCOL (`Remotes` SPECIFICATION)

To keep server bandwidth well under Roblox's `50 KB/s` per-client budget—even during a 6-player, 30-hero World Boss encounter—the network layer uses **binary `buffer` bitpacking** over an `UnreliableRemoteEvent` for the 5 Hz transform and state snapshot, paired with rate-limited `RemoteEvent` and `RemoteFunction` endpoints for stateful actions.

### 3.1 Complete Remotes Specification Table

| Remote Name & Class | Direction | Payload Parameters & Types | Byte-Size Optimization | Server-Side Sanity Checks & Anti-Exploit Validations |
| :--- | :--- | :--- | :--- | :--- |
| **`ReplicationTick`**<br>`UnreliableRemoteEvent` | `S -> C` (5 Hz / 0.2s) | `snapshotBuf: buffer`<br>Header: `uint8` count, `float32` serverTime.<br>Per Entity (14 bytes): `uint16` netId, `int16` posX (`*10`), `int16` posZ (`*10`), `uint8` rotYaw, `uint8` stateEnum, `uint16` hpPct (`0..1000`), `uint8` stamina (`0..100`), `uint8` flags (`Overdrive/Coma/CoreExposed`), `int16` posY (`*10`). | **14 bytes per entity; at most 64 entities per packet.** Max packet size = 5 + (64 $\times$ 14) = **`901 bytes/packet`**. | Read-only broadcast (`S -> C`). Any incoming packets from clients are immediately dropped. |
| **`FocusTarget`**<br>`RemoteEvent` | `C -> S` | `targetNetId: number`, `targetPlayerUserId: number?` | `2–6 bytes` integer IDs instead of string instances. | 1. Rate limit: Max `8 calls/sec` per player.<br>2. Verifies `targetNetId` exists in active MobTable or belongs to an active Loot Thief / enemy squad.<br>3. Verifies distance to target is `<= 350 studs`. |
| **`WhistleCommand`**<br>`RemoteEvent` | `C -> S` | `commandCode: number` (`uint8`: `1 = Q_OVERDRIVE`, `2 = E_RECALL`) | `1 byte` enum (`uint8`). | 1. Server tracks authoritative cooldowns: `Q` requires `20.0s`; `E` requires `6.0s`.<br>2. For `Q_OVERDRIVE`, deducts `5.0` Stamina per hero.<br>3. For `E_RECALL`, validates Master character position and applies a 2.0s pacification drop. |
| **`BossTelegraph`**<br>`RemoteEvent` | `S -> C` | `telegraphType: uint8`, `originXZ: Vector2int16`, `radius: uint8`, `durationMs: uint16` | `7 bytes` total per boss cast. | Server-authoritative broadcast. Hit detection for **Devouring Nova** (`R <= 85 studs` at `t = 3.0s`) is computed 100% on the server. |
| **`RelicStateChanged`**<br>`RemoteEvent` | `S -> C` | `relicNetId: uint16`, `tierId: uint8`, `state: uint8`, `carrierUserId: number?`, `lockExpiresAt: number` | Compact tuple (`~16 bytes`). | Server broadcast. Clients do not claim relic pickups; server `RelicService` validates 3D proximity (`<= 8 studs`) and owner-lock expiry. |
| **`LootStolenAlert`**<br>`RemoteEvent` | `S -> C` | `thiefUserId: number`, `thiefName: string`, `lootType: string`, `amount: number` | `~20 bytes`. | Broadcast to victim when another player picks up their drop, opening real-time `[⚔️ RETALIATE]` HUD action. |
| **`SquadWipeState`**<br>`RemoteEvent` | `S -> C` | `isWiped: boolean` | `1 byte`. | Server fires `true` on squad wipe, locking looting until the player returns to plot; fires `false` on recovery. |
| **`CarriedLootSync`**<br>`RemoteEvent` | `S -> C` | `gold: number`, `gems: number` | `4 bytes` (`uint16` $\times 2$). | Synchronizes unbanked field cargo carried overhead. |
| **`DropCarriedItem`**<br>`RemoteEvent` | `C -> S` | None | `0 bytes` payload. | Drops currently carried physical cargo or relic on the ground with a 1.5s re-pickup lockout. |
| **`RequestSummon`**<br>`RemoteFunction` | `C -> S` | `pullCount: number` (`1` or `10`) $\rightarrow$ `{ HeroInstance }?` | Returned table on completion. | Strict verification of `100 Gems` (1x) or `900 Gems` (10x). CSPRNG rolls 70%/25%/5% rates server-side. |
| **`RequestUpgradeRarity`**<br>`RemoteFunction` | `C -> S` | `artifactUUID: string` $\rightarrow$ `(boolean, string, number?)` | String UUID + Result tuple. | Validates artifact ownership, checks Gold/Gem costs from `ArtifactCatalog`, and advances rarity tier (1 to 16). |
| **`RequestEquipArtifact`**<br>`RemoteFunction` | `C -> S` | `heroUUID: string`, `artifactUUID: string` $\rightarrow$ `(boolean, string)` | String UUIDs. | Validates archetype compatibility (`Marksman` $\to$ `BOW`, etc.) and equips weapon to hero slot. |
| **`RequestUnequipArtifact`**<br>`RemoteFunction` | `C -> S` | `heroUUID: string` $\rightarrow$ `(boolean, string)` | String UUID. | Clears equipped weapon from specified hero. |

### 3.2 14-Byte Binary Buffer Wire Layout

```text
Header (5 bytes):
[0]      uint8    entityCount (1..64)
[1..4]   float32  serverTimestamp

Per Entity (14 bytes stride):
Offset + 0..1   uint16   NetId
Offset + 2..3   int16    PositionX (* 10, quantized)
Offset + 4..5   int16    PositionZ (* 10, quantized)
Offset + 6      uint8    Yaw (quantized: (yaw + pi) / (2 * pi) * 255)
Offset + 7      uint8    StateEnum (Hero: 1..6; Mob: 10 + Phase)
Offset + 8..9   uint16   HPPermille (0..1000)
Offset + 10     uint8    Stamina (0..100)
Offset + 11     uint8    Flags (Bit 0: Overdrive, Bit 1: Pacified, Bit 2: Core Exposed)
Offset + 12..13 int16    PositionY (* 10, quantized floor height)
```

---

## 4. CORE SERVER SIMULATION (`CombatSimulation.server.luau`)

The combat simulation runs at an authoritative $5\text{ Hz}$ tick rate (`0.20s`), managing zero server-side humanoids.

### 4.1 Grounded Waypoint Hero Navigation
Heroes navigate the 18 platforms and quarter-turn ascent ramps of the Central Crimson Tower via `HeroNavigation.luau` and `TowerTraversal.luau`:
- Asynchronous path computation with a maximum of three concurrent queries per tick.
- Every movement step performs ground raycasts, clearance checks, and slope validation.
- Recall commands snap heroes directly to a supported formation point on the Master's current platform floor.
- Dynamic line-of-sight and height verification ensure heroes cannot attack through floor ceilings or solid tower walls.

### 4.2 Contested Loot, Retaliation PvP & Squad Wipe
1. **Loot Drops:** Mobs drop physical cargo in `Workspace.PhysicalLoot` tagged with `KillerUserId`.
2. **Theft Detection:** Collecting another player's drop flags the picker as `IsLootThief = true` and records a 3-minute `TheftGrudge`.
3. **Targeted Retaliation:** The victim receives a HUD alert with a `[⚔️ RETALIATE]` button. Activating it dispatches squad-vs-squad PvP targeting at $25\%$ PvP damage scaling. The targeted squad auto-retaliates in mutual defense.
4. **Squad Wipe:** If all 5 heroes fall into `COMA`, carried loot spills at the Master's feet, and field looting is locked (`CanCollectLoot = false`) until the Master returns to their plot to heal heroes in the Infirmary.

### 4.3 Master Movement & Shift Sprint
`MasterController.client.luau` monitors `[LeftShift / RightShift]` key states on `RenderStepped`, applying an immediate $3.0\times$ speed multiplier to the Master's Humanoid WalkSpeed. ProximityPrompts for plot facilities arbitrate hotkey precedence so interacting with facilities does not trigger emergency whistles.

---

## 5. PHYSICAL RELIC EXTRACTION SERVICE (`RelicService.server.luau`)

Manages physical relics (`MANA_GEODE`, `CURSED_URN`, `ABYSSAL_CORE`, `CALAMITY_HEART`):
- **Overhead Welding:** Relics weld directly above the carrier's `HumanoidRootPart` with a `WeldConstraint`.
- **Movement Penalties:**
  - `MANA_GEODE`: `-15%` WalkSpeed slow.
  - `CURSED_URN`: `-25%` WalkSpeed slow.
  - `ABYSSAL_CORE`: `-35%` WalkSpeed slow, jump disabled.
  - `CALAMITY_HEART`: `-45%` WalkSpeed slow, jump disabled, 15-second Rank #1 DPS exclusive lock.
- **AoE Fumbles:** Taking damage from an Elite or Boss AoE triggers a 1.0s stun and drops the relic on the ground with a 3.0s owner lock before other players can steal it.
- **Deposit:** Reaching the Perimeter Highway ($R \ge 460\text{ studs}$) or a Private Extraction Pad converts the relic into banked Gold and Gems.

---

## 6. EQUIPPABLE ARTIFACT & BLACKSMITH SYSTEM ARCHITECTURE

Artifact progression is managed server-authoritatively by `DataManager.server.luau` and `BlacksmithService.server.luau`, guided by `ArtifactCatalog.luau`:

### 6.1 Data Model & Archetype Restrictions
Weapons are categorized into 6 types with strict hero class permissions:
- `BOW`: Marksman (`hero_jenna`)
- `SWORD`: Striker, Vanguard (`hero_han`, `hero_velkist`, `hero_aaron`, `hero_archon`)
- `DAGGERS`: Striker (`hero_velkist`)
- `AXE`: Vanguard, Miner (`hero_aaron`, `hero_catio`)
- `TOME`: Scholar, Healer (`hero_eolka`)
- `STAFF`: Scholar, Healer (`hero_eolka`)

### 6.2 Deterministic 16-Tier Rarity Ascension
- **Star Tier (1★ to 7★):** Fixed seed establishing Base Attack Power (`+15` to `+950`) and Base Attack Speed (`+5%` to `+60%`).
- **Rarity Multiplier (1.00x to 18.00x):** Ascended at the Blacksmith Forge using Gold and Gems.
- **Instant Stat Refresh:** Modifying an equipped weapon immediately updates `simHero.ATK` and `simHero.AttackInterval` on the next $5\text{ Hz}$ tick.
- **3D Visual Socketing:** `ArtPackVisuals.luau` clones weapon models client-side into hero rigs and rigidly welds them to `LeftHand` or `RightHand` with dynamic string beams and arrow attachments.

---

## 7. DEDICATED SYNTHESIS & THE PIT ARCHITECTURE

The Pit progression is governed by `PitService.luau`, `PitMath.luau`, `PitBalanceConfig.luau`, and `SynthesisController.luau`:

### 7.1 Synthesis Modal Flow
- Dedicated UI modal (`SynthesisController.luau`) displaying 1 recipient slot on the left and 5 donor material slots on the right.
- Real-time level preview bar and projected stat delta calculation before committing the transaction.
- 100% deterministic EXP:
  $$\text{EXP} = \text{round}\Big(\big(100 \times 3^{(S_{\text{donor}}-1)} + 25 \times L_{\text{donor}}\big) \times \max(0.55, 1 - 0.025 \times \text{gap}) \times (1 + \text{bonus})\Big)$$

### 7.2 Star Promotion & Conversion
- Promotion from $S \to S+1$ requires the target hero at Max Level ($S \times 10$), Gold, and Promotion Stones crafted from Soul Essence.
- Conversion disassembles spare heroes into Soul Essence based on Star tier and investment levels.
- Focused imprints allow 100% deterministic trait memory transfers between compatible roles using Imprint Catalysts.
