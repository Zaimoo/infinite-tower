# Project: Waiting Room (*Infinite Towers: Become a Master!*)

> **Core Concept:** An asynchronous squad-command extraction RPG and Tycoon built in Roblox. Direct squads of anime heroes in a concentric arena, extract physical loot drops, dodge high-stakes telegraphed boss mechanics, and manage your private Waiting Room tycoon.

---

## 🏛️ Architectural Standards

- **Zero Server-Side Humanoids:** All active combat entities (Heroes, Ring 1 Mobs, Ring 2 Elites, and Ring 3 World Boss) run as lightweight Luau table state machines on the server.
- **5 Hz Server Simulation Loop:** Tick rate of `0.20s` (`5 Hz`) guarantees deterministic math, leashing, and collision-free spatial management.
- **60 FPS Client RenderStepped Interpolation:** Visual rigs are interpolated smoothly on the client (`RenderStepped`) from a compact 14-byte binary buffer broadcast over `UnreliableRemoteEvent` (`5-byte` packet header, `14 bytes` per entity including quantized Y floor height; at most 64 entities per packet).
- **Floating Island & Central Crimson Tower Architecture:**
  - 5 floating fortress plot islands arranged symmetrically in a ring ($R = 540\text{ studs}$, $72^\circ$ spacing, $Y = 12$) facing the Central Crimson Tower.
  - Central Crimson Tower featuring 18 fully walkable platforms, quarter-turn ascent ramps with server-side collision, and grounded waypoint navigation for lightweight hero entities.
- **Equippable Artifact & Blacksmith System:**
  - 6 archetypally restricted weapon classes (Bows, Swords, Daggers, Axes, Tomes, Staves) with permanent 1★–7★ Base Stat seeds.
  - Deterministic 16-tier Rarity upgrade path (`Common` $\to$ `Origin`) at the Waiting Room Blacksmith Forge using Gold and Gems, multiplying base stats up to $18.00\times$.
  - 3D visual socketing and procedural combat animations with dynamic weapon geometry.
- **Physical Contested Loot & Retaliation PvP:**
  - Monsters and crystal nodes drop 3D physical cargo in `Workspace.PhysicalLoot` tagged with `KillerUserId`.
  - Picking up another player's loot flags the player as a `[Loot Thief]` and grants the victim a 3-minute retaliation grudge.
  - Aggrieved Masters can click `[⚔️ RETALIATE]` to command their deployed squad to attack the thief's heroes at $25\%$ PvP damage scaling.
  - On squad defeat, all carried loot spills onto the ground, and field looting is locked until the Master returns to their Waiting Room plot to heal or swap heroes.
  - Safe looting deposit occurs upon reaching the perimeter highway or private plot extraction pads.

---

## 📂 Project Structure

```text
├── GAME_DESIGN.MD                    -- Document 1: Master Game Design Document (GDD)
├── technical_architecture.md         -- Document 2: Technical Architecture & Network Contracts
├── economy_balancing_tables.md       -- Document 3: Mathematical Economy & Balancing Tables
├── ui_ux_wireframes.md               -- Document 4: UI/UX Wireframes & Spatial Screen Specifications
├── PROTOTYPE_DOCUMENTATION.md        -- Prototype Implementation & Verification Document
├── docs/
│   ├── PIT_OVERHAUL.md               -- The Pit progression, imprints, synthesis, and verification
│   └── TOWER_NAVIGATION.md           -- Tower traversal, 18-floor navigation, and hero routing
└── src/
    ├── ServerScriptService/
    │   ├── BaseOverhaul/             -- Floating island ring, Central Crimson Tower, bridges, and lighting
    │   ├── Combat/                   -- CombatSimulation (5 Hz Zero-Humanoid Engine, buffer packing, PvP)
    │   ├── Core/                     -- DataManager (Profiles/Gacha), PitService, PlotManager, TowerTraversal, HeroNavigation
    │   ├── ExtractionAndSocial/      -- RelicService, SyndicateService (Plot Espionage)
    │   └── Tycoon/                   -- WaitingRoomService (1 Hz Facility Production), BlacksmithService (Forge Station)
    ├── StarterPlayerScripts/
    │   ├── Input/                    -- MasterController (Raycasting, [Shift] Sprint, [Q] Overdrive, [E] Recall)
    │   ├── Rendering/                -- EntityRenderer (Buffer Unpacker), HoldingAnimationController
    │   └── UI/                       -- HUDController (Gothic Toolbar/Currencies), SynthesisController, PitController, FacilityController
    └── ReplicatedStorage/
        ├── Assets/                   -- ArtPackVisuals, Hero Rigs, Mob Rigs, Relics, Weapons, Props
        └── Shared/                   -- ArtifactCatalog, FacilityConfig, HeroCatalog, PitBalanceConfig, RelicConfig, WorldBossConfig, GothicBoxStyle, StatFormulas, PitMath
```

---

## 🎮 Master Controls

| Action | Input | Description |
| :--- | :--- | :--- |
| **Movement Sprint** | `[LeftShift / RightShift]` | $3.0\times$ movement speed multiplier for rapid traversal across bridges and arena rings. |
| **Focus Target** | `[Click / Tap]` | Raycast onto any mob, boss, or enemy thief to focus squad aggro. |
| **Overdrive Whistle** | `[Q]` | $20\text{s}$ CD. Consumes $5$ Stamina/hero for $+40\%$ Attack Speed for $5\text{s}$. |
| **Emergency Recall** | `[E]` | $6\text{s}$ CD. Instantly warps squad to Master + $2\text{s}$ pacify (dodges $85\text{-stud}$ Devouring Nova). Yields priority to nearby ProximityPrompts. |
| **Drop Carried Item** | `[R]` / Drop button | Place carried cargo or a relic on the ground for pickup; restores normal movement. |
| **Retaliate Attack** | `[⚔️ RETALIATE]` | Single-click HUD response when your drop is stolen to unleash squad PvP. |
| **Blacksmith Forge** | `[E]` / Prompt | Approach the Blacksmith Forge on your plot to view, equip, and ascend weapon rarities (Common $\to$ Origin). |
| **The Pit (Synthesis)** | `[E]` / `[F]` / Prompt | Approach the Pit cauldron to open the dedicated Synthesis UI modal (recipient slot, 5 donor slots, level preview) or star promotion. |
| **Facility HUDs** | `[F]` / Prompt | Approach Summoning Altar, Infirmary, or Squad Management to open focused facility HUDs. |

---

## ⚙️ Running in Roblox Studio

1. Open Roblox Studio with Place ID `136256010643848`.
2. Scripts are synced via Rojo from `src/` to `ServerScriptService`, `StarterPlayer.StarterPlayerScripts`, and `ReplicatedStorage`.
3. Press **F5 (Play)** to playtest the full loop: Gacha summoning, deploying squads, fighting mobs on the Central Crimson Tower, contested loot hauling, Blacksmith weapon ascension, and World Boss encounters.

The Pit supports batch synthesis, focused imprints, material-based star promotion, and hero conversion. See [the Pit implementation and playtest guide](docs/PIT_OVERHAUL.md) for formulas, schema compatibility, test commands, and Studio checks. Profiles remain **session-only**.

Tower walls, all 18 platforms, and connecting ascent ramps have server collision. Lightweight heroes use grounded, collision-checked waypoint navigation. See [tower traversal and navigation](docs/TOWER_NAVIGATION.md) for implementation and verification.
