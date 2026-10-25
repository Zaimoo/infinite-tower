# Phase 5: Unified React-lua UI, HUD & Menu Migration

**Document Version:** 2.0  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phases 1 through 4 complete  

---

## 1. Objectives & Scope

Phase 5 delivers the complete front-end overhaul using **React-lua** (`jsdotlua/react` + `react-roblox` 17.2.1). With all underlying game loops, combat pacing, death flows, and progression services finalized in Phases 1–4, the entire client presentation can be built against real, production-ready server contracts with **zero throwaway code or mock states**.

---

## 2. Core HUD Architecture (Max 4 Persistent Elements)

```
+---------------------------------------------------------------+
| [Gold: 1,250] [Gems: 45]          [=== Floor 3: 12/20 ===]    |
| (Top-Left)                        (Top-Center)                |
|                                                               |
|                                   [Next Goal: Clear Floor 3]  |
|                                   [Defeat Boss to Unlock...]  |
|                                   (Top-Right)                 |
|                                                               |
|                                                               |
|                                                               |
|                 [Summon] [Squad] [Forge] [Plot]               |
|                 (Bottom-Center Navigation Bar)                |
+---------------------------------------------------------------+
```

1. **Top-Center — Floor Progress & Boss Health Bar:**
   - Displays real-time mob kill progress: `[=== Floor 1: 14/15 ===]`.
   - On boss summon, smoothly morphs into an intimidating Boss Health Bar with phase indicators and name banner.
2. **Top-Left — Clean Currency Bar:**
   - Displays Gold and Gems with responsive typography.
   - Smooth numerical tick-up and delta floaters (`+150 Gold`).
3. **Top-Right — Pinned "Next Goal" Quest Card:**
   - Displays current objective from `OnboardingService`.
   - Tap/click opens detailed quest panel with rewards preview.
4. **Bottom-Center — Modern Navigation Toolbar:**
   - Icons for unlocked systems only (reads `profile.Unlocks`).
   - Notification badges (e.g. unassigned workers, available weapon upgrades).

---

## 3. Gameplay Modals & Prompts

1. **Defeat Modal (`DefeatModal.luau`):**
   - Appears upon squad wipe.
   - Summary: Highest floor reached, mobs defeated, safe banked loot.
   - One-tap button: **[RETURN TO FORTRESS]** (teleports and restores full HP).
2. **Retaliation Duel Prompts (`DuelPrompts.luau`):**
   - Victim Prompt: `[PlayerName] took your drop! [RETALIATE (5v5)]`
   - Thief Billboard: Floating `[Loot Thief]` tag above avatar.
   - Duel Result Modal: Declares winner with clear confirmation that only the contested drop was at stake.
3. **Offline Facility Reward Modal (`OfflineRewardModal.luau`):**
   - Shows upon joining if offline time $> 10\text{ minutes}$.
   - Shows assigned workers, hours away, and total accumulated Gold/materials with **[CLAIM ALL]** button.

---

## 4. Modernized React-lua Menus

Migrate legacy imperative menu files into declarative React components:
1. **Summoning Altar (`SummonModal.luau`):**
   - Hero and Weapon banners with card reveal animations.
2. **Squad Management (`SquadModal.luau`):**
   - 5 active combat slots, drag-and-drop or one-tap assign, total squad power calculation.
3. **Blacksmith Forge (`ForgeModal.luau`):**
   - Flexible responsive layout, weapon ascension preview, stat delta comparison.
4. **Plot Facilities (`FacilityModal.luau`):**
   - Fortress building overview, benched hero labor assignment, hourly rate tracker.
5. **The Pit (`PitModal.luau`):**
   - Unified Synthesis (duplicate fodder leveling) and Promotion (star ascension).

---

## 5. Cross-Platform Polish & Legacy Retirement

1. **Mobile Safe Areas:**
   - All screens padded against `CoreUISafeInsets` to prevent notch and home-bar overlap.
   - Touch hitboxes $\ge 44 \times 44\text{ px}$.
2. **Gamepad Navigation:**
   - Automatic `GuiService.SelectedObject` focus on modal open.
   - D-pad spatial navigation across all grid slots.
   - `ButtonB` closes open modals.
3. **Retirement of Legacy Code:**
   - Delete legacy 1,731-line imperative `HUDController.client.luau`.
   - Delete legacy imperative controllers (`SquadController.luau`, `ForgeController.luau`, `FacilityController.luau`, `SynthesisController.luau`, `PromotionController.luau`).

---

## 6. Verification & Acceptance Criteria

1. **React Component Specs (`tests/phase5-ui.spec.luau`):**
   - Unit test each React component rendering in isolation.
   - Verify HUD respects `profile.Unlocks` and shows max 4 elements.
2. **Studio Playtest & Safe Area Inspection:**
   - Test UI across Mobile, Tablet, Console, and PC emulator modes.
   - Confirm zero overlapping text and flawless gamepad navigation.
