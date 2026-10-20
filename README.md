# Project: Waiting Room (*Infinite Towers: Become a Master!*)

> **Core Concept:** An asynchronous squad-command extraction RPG and Tycoon built in Roblox. Direct squads of anime heroes in a concentric arena, extract physical loot drops, dodge high-stakes telegraphed boss mechanics, and manage your private Waiting Room tycoon.

---

## 🏛️ Architectural Standards

- **Zero Server-Side Humanoids:** All active combat entities (Heroes, Ring 1 Mobs, Ring 2 Elites, and Ring 3 World Boss) run as lightweight Luau table state machines on the server.
- **5 Hz Server Simulation Loop:** Tick rate of `0.20s` (`5 Hz`) guarantees deterministic math, leashing, and collision-free spatial management.
- **60 FPS Client RenderStepped Interpolation:** Visual rigs are interpolated smoothly on the client (`RenderStepped`) from a compact binary buffer broadcast over `UnreliableRemoteEvent` (`14 bytes` per entity, including floor height; at most 64 entities per packet).
- **Physical Contested Loot & Retaliation PvP:**
  - Monsters and crystal nodes drop 3D physical cargo in `Workspace.PhysicalLoot` tagged with `KillerUserId`.
  - Picking up another player's loot flags the player as a `[Loot Thief]` and grants the victim a 3-minute retaliation grudge.
  - Aggrieved Masters can click `[⚔️ RETALIATE]` to command their deployed squad to attack the thief's heroes at $25\%$ PvP damage scaling.
  - On squad defeat, all carried loot spills onto the ground, and field looting is locked until the Master returns to their Waiting Room plot to heal or swap heroes.

---

## 📂 Project Structure

```text
├── GAME_DESIGN.MD                    -- Document 1: Master Game Design Document (GDD)
├── technical_architecture.md         -- Document 2: Technical Architecture & Network Contracts
├── economy_balancing_tables.md       -- Document 3: Mathematical Economy & Balancing Tables
├── ui_ux_wireframes.md               -- Document 4: UI/UX Wireframes & Spatial Screen Specifications
├── PROTOTYPE_DOCUMENTATION.md        -- Prototype Implementation & Verification Document
└── src/
    ├── ServerScriptService/
    │   ├── Core/                     -- DataManager (Profiles/Gacha), PitService, PlotManager
    │   ├── Combat/                   -- CombatSimulation (5 Hz Zero-Humanoid Engine)
    │   ├── ExtractionAndSocial/      -- RelicService, SyndicateService (Plot Espionage)
    │   └── Tycoon/                   -- WaitingRoomService (1 Hz Facility Production Loop)
    ├── StarterPlayerScripts/
    │   ├── Input/                    -- MasterController (Raycasting, [Q] Overdrive, [E] Recall)
    │   ├── Rendering/                -- EntityRenderer (Buffer Unpacker), HoldingAnimationController
    │   └── UI/                       -- HUDController, PitController, reusable HeroCard and Pit design tokens
    └── ReplicatedStorage/
        ├── Assets/                   -- ArtPackVisuals (Zero-Humanoid R15 & Skinned Animator)
        └── Shared/                   -- Catalog/configs, PitBalanceConfig, StatFormulas, PitMath
```

---

## 🎮 Master Controls

| Action | Input | Description |
| :--- | :--- | :--- |
| **Focus Target** | `[Click / Tap]` | Raycast onto any mob, boss, or enemy thief to focus squad aggro. |
| **Overdrive Whistle** | `[Q]` | $20\text{s}$ CD. Consumes $5$ Stamina/hero for $+40\%$ Attack Speed for $5\text{s}$. |
| **Emergency Recall** | `[E]` | $6\text{s}$ CD. Instantly warps squad to Master + $2\text{s}$ pacify (dodges $85\text{-stud}$ Devouring Nova). |
| **Drop Carried Item** | `[R]` / Drop button | Place carried cargo or a relic on the ground for pickup; restores normal movement. |
| **Retaliate Attack** | `[⚔️ RETALIATE]` | Single-click HUD response when your drop is stolen to unleash squad PvP. |
| **Waiting Room** | UI / Prompt | Manage roster, Gacha pulls, facility worker assignments, and synthesis. |
| **The Pit** | UI / `[E]` prompt | Approach the Pit and open hero synthesis and promotion; ascend heroes from $1★$ to $5★$. |
| **Facility HUDs** | `[F]` / Click or tap prompt | Approach synthesis, promotion, infirmary, summoning, or the squad banner to open its management HUD. |

---

## ⚙️ Running in Roblox Studio

1. Open Roblox Studio with Place ID `136256010643848`.
2. Scripts are managed in `ServerScriptService`, `StarterPlayerScripts`, and `ReplicatedStorage`.
3. Press **F5 (Play)** to playtest the full loop: Gacha summoning, deploying squads, fighting Ring 1 mobs, contested loot hauling, and World Boss encounters.

The Pit now supports batch synthesis, focused imprints, material-based star promotion, and hero conversion. See [the Pit implementation and playtest guide](docs/PIT_OVERHAUL.md) for formulas, schema compatibility, test commands, and Studio checks. Profiles remain **session-only**.

Tower walls, all 18 platforms, and connecting ascent ramps have server collision. Lightweight heroes use grounded, collision-checked waypoint navigation. See [tower traversal and navigation](docs/TOWER_NAVIGATION.md) for implementation and verification.
