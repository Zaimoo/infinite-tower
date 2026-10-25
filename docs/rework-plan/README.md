# Infinite Tower: Full Game Rework - Master Roadmap & Phase Index

**Project Title:** Infinite Tower - Full Game & Systems Rework  
**Target Architecture:** AFK Journey-style 3D Auto-Battler with Persistent Multiplayer Tower  
**UI Framework:** React-lua (`jsdotlua/react` + `react-roblox` 17.2.1)  
**Status:** In Progress (Phased Rollout)  

---

## 1. Roadmap Overview

```mermaid
flowchart TD
    P0["Phase 0: Foundation & P1 Bug Fixes\n(Weapon ATK tick erase, AoE Z-height, Plot overwrite)"]
    P1["Phase 1: Onboarding Engine & React-lua HUD\n(Pinned Goal Tracker, OnboardingService, v3 Profile Schema)"]
    P2["Phase 2: Fast-Paced Combat & Feedback\n(Continuous mob spawns, hit feedback, damage popups, no Q/E)"]
    P3["Phase 3: Floor Loop & Defeat Flow\n(Per-player progress bar, boss gate, no-revive squad wipe to plot)"]
    P4["Phase 4: Tower PvP & Low-Stakes Duels\n(Thief flags, Retaliate duel, loser loot lockout)"]
    P5["Phase 5: Menu Migration & Facility Idle Integration\n(React Forge, Squad, Pit, Facilities)"]

    P0 --> P1 --> P2 --> P3 --> P4 --> P5
```

---

## 2. Phase Index & Specifications

Each phase has its own detailed, self-contained implementation specification:

| Phase | Document | Focus Areas | Key Deliverables |
| :---: | :--- | :--- | :--- |
| **0** | [PHASE_0_FOUNDATION_AND_BUGS.md](PHASE_0_FOUNDATION_AND_BUGS.md) | Bug fixes & tooling | Fix 5 critical P1 bugs from systems review; verify Rokit/Rojo/Wally setup. |
| **1** | [PHASE_1_ONBOARDING_AND_HUD.md](PHASE_1_ONBOARDING_AND_HUD.md) | Progression & Core UI | `OnboardingConfig`, `OnboardingService`, v3 profile schema migration, React-lua HUD with pinned Goal Tracker. |
| **2** | [PHASE_2_COMBAT_PACING_AND_SPECTACLE.md](PHASE_2_COMBAT_PACING_AND_SPECTACLE.md) | Combat action & juice | Dynamic mob streamer, hit-frame damage synchronization, damage popups, screen shakes, removal of Q/E whistles. |
| **3** | [PHASE_3_FLOOR_LOOP_AND_DEFEAT.md](PHASE_3_FLOOR_LOOP_AND_DEFEAT.md) | Tower loop & failure | Globally shared floors, per-player kill progress bar, boss summoning gate, full-copy boss loot, no-revive squad wipe to plot. |
| **4** | [PHASE_4_TOWER_PVP_RETALIATION.md](PHASE_4_TOWER_PVP_RETALIATION.md) | Tower PvP & Duels | Killer-tagged mob loot, [Loot Thief] flags, non-consequential retaliation duel, loser drop lockout. |
| **5** | [PHASE_5_MENUS_AND_IDLE_FACILITY.md](PHASE_5_MENUS_AND_IDLE_FACILITY.md) | Menus & Idle loop | Incremental React migration for Forge, Squad, Facilities, The Pit; facility-only idle claim modal; gamepad polish. |

---

## 3. High-Level Principles & Architecture Contracts

1. **Server Authority:** All progression state (unlocked systems, onboarding step, floor clears, kill progress, inventory, currencies) is server-authoritative. The client sends intents; the server validates and replicates via delta snapshots.
2. **Hands-Off Auto-Battling:** The Master explores and guides movement in 3D. Combat is 100% automatic—no manual skill taps, no formation management, no Q/E whistles.
3. **Clean HUD Limit (Max 4 Persistent Elements):**
   - Top-Center: Floor Progress Bar (transitions to Boss Health Bar).
   - Top-Left: Currencies (Gold, Gems) with readable font sizes and delta popups.
   - Top-Right: Pinned "Next Goal" Quest Card.
   - Bottom-Center: Navigation Toolbar with icons and badge indicators.
4. **Zero-Deadweight Systems:** All 10 existing systems are preserved but locked behind progressive milestone unlocks. New players see only 1–2 systems at a time.
5. **Low-Stakes Multiplayer:** Shared tower floors foster emergent encounters. Contested drops enable squad duels without wiping or teleporting either player; the loser is merely locked out of that single drop.
