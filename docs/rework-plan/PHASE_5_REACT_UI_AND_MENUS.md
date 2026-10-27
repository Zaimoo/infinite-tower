# Phase 5: Unified React-lua UI, HUD & Menu Migration

**Document Version:** 3.0 (updated for the shipped Phase 3 duels and Phase 4 progression)  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phases 1 through 4 complete (Phases 3 and 4: PR #72)  

---

## 1. Objectives & Scope

Phase 5 delivers the complete front-end overhaul using **React-lua** (`jsdotlua/react` + `react-roblox` 17.2.1). With all underlying game loops, combat pacing, death flows, and progression services finalized in Phases 1–4, the entire client presentation can be built against real, production-ready server contracts with **zero throwaway code or mock states**.

Phases 3 and 4 shipped interim imperative UI for their features. Phase 5 rebuilds each one in React against the same server contracts and then deletes the interim script (§6). **No server contract changes:** the components read the profile sync and the remotes listed in §7.

---

## 2. Core HUD Architecture (Max 4 Persistent Elements)

```
+---------------------------------------------------------------+
| [Gold: 1,250] [Gems: 45]          [=== Floor 3: 12/20 ===]    |
| (Top-Left)                        (Top-Center)                |
|                                                               |
|                                   [Next Goal 3/7: Clear Fl. 1]|
|                                   [Reward: 1,000 Gold]        |
|                                   (Top-Right)                 |
|                                                               |
|                                                               |
|                                                               |
|          [Summon] [Squad] [Forge] [Fortress] [Tower]          |
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
   - Reads `ProgressionRemotes.OnboardingSync` (`Step`: Index, Total, Title, Description, Reward; plus `Unlocks`). Hidden once the 7-step chain is complete.
   - Flashes on a new goal; tap/click opens a detailed quest panel with the reward preview.
   - Replaces the interim `GoalTrackerController.client.luau`.
4. **Bottom-Center — Modern Navigation Toolbar:**
   - Buttons: **Summon, Squad, Forge, Fortress, Tower**. The Fortress button opens the Fortress Tree (§4.4).
   - Icons for unlocked systems only (reads `profile.Unlocks`). The Fortress button shows once `Squad` is unlocked, since the tree's Command branch (squad slots) opens with the first summon.
   - Notification badges: a buildable tree node, an open squad slot with no hero, unassigned facility workers, available weapon promotions.
   - The legacy Overdrive `[Q]` and Recall `[E]` whistle buttons are removed.
- **Lock toasts:** Locked actions (squad, Forge, facilities, Pit, Tower) are refused on the server with a toast that names the step to finish. The HUD keeps a toast stack for these and other `SystemToast` messages; it is not one of the 4 persistent elements.

---

## 3. Gameplay Modals & Prompts

1. **Defeat Modal (`DefeatModal.luau`):**
   - Appears upon squad wipe.
   - Summary: Highest floor reached, mobs defeated, safe banked loot.
   - One-tap button: **[RETURN TO FORTRESS]** (teleports and restores full HP).
2. **Retaliation Duel UI (`DuelPrompts.luau`, `DuelScreen.luau`), replacing `DuelController.client.luau` and the HUD's stolen-loot banner:**
   - **Victim prompt:** `🚨 [THIEF] STOLE 120 GOLD! (2:41)` with a live countdown for the 3-minute window and **[⚔️ RETALIATE]** (fires `TowerRemotes.InitiateRetaliation(DropId)`). It appears on `LootContested {Kind = "STOLEN"}` and is removed on `{Kind = "CLEAR"}` or expiry.
   - **Thief billboard:** the server-made `[Loot Thief]` tag stays as is (world space, not React).
   - **Duel screen** (`TowerRemotes.DuelState`):
     - **START:** a fixed high-angle camera behind your squad over the hex arena, and a banner with both names, a `mine ⚔ theirs` heroes-left score and the "Fight in N" then seconds-left timer.
     - **SCORE / FIGHT:** updates the score.
     - **END:** VICTORY or DEFEAT with the lockout line (you keep or lose the drop; "time up: more HP left wins" on timeout).
     - **CLEAR:** gives the camera back.
   - Hero nameplates stay green for your squad and orange for the enemy during a duel (`EntityRenderer`).
3. **Offline Facility Reward Modal (`OfflineRewardModal.luau`):**
   - Shows upon joining if offline time $> 10\text{ minutes}$.
   - Shows assigned workers, hours away, and total accumulated Gold/materials with **[CLAIM ALL]** button.
   - The offline cap includes the Night Watch perk (+2 h).

---

## 4. Modernized React-lua Menus

Migrate legacy imperative menu files into declarative React components:

1. **Summoning Altar (`SummonModal.luau`):**
   - Hero and Weapon banners with card reveal animations.
   - **Rarity everywhere:** roster lines and reveal cards show the hero's inherent rarity and star, e.g. `Ignis · Exalted 5★`. Rarity gets a frame colour per tier (Common to Mythical).
   - **Odds panel:**
     - The tier rates per banner: Call of the Rift 70/20/7/2.5/0.5%; A Star's Arrival 60/24/10/4.2/1.4/0.33/0.07%.
     - Pity counters "Guaranteed Exalted Ignis in N" (80) and "Guaranteed Mythical Astrea in N" (90).
     - "10x guarantees a Rare or better".
   - **God's Blessing badge:**
     - The `✨ Blessing +X% luck` badge appears when luck is above 0.
     - Expanding it shows the boosted odds, computed with `SummonLuck.ApplyLuck` from the Blessing level, Acolyte labor and the Saint's Favor perk.
     - The artifact banner shows the same badge.
2. **Squad Management (`SquadModal.luau`):**
   - Five slot cards; **only the open slots are usable** (`FortressTree.SquadSlots(profile.FortressTree)`, 1 to start).
   - Locked slots show 🔒 **[LOCKED]** and the next Command node's cost and floor requirement. Clicking one opens the Fortress Tree focused on that node.
   - Header `ACTIVE SQUAD (n/open)`. Until the first summon, the screen shows "🔒 Summon your first hero to change your squad".
   - Drag-and-drop or one-tap assign, total squad power, and rarity on every hero card.
   - Show the server's message for **every** refused assignment, such as a coma or a locked slot. The legacy screen drops these.
3. **Blacksmith Forge (`ForgeModal.luau`):**
   - Flexible responsive layout, weapon ascension preview, stat delta comparison.
   - Locked until Floor 1 is cleared (`profile.Unlocks.Forge`): the promote button reads "🔒 CLEAR FLOOR 1 TO UNLOCK PROMOTION".
   - Every refused promotion shows its reason.
4. **Fortress Tree (`FortressTreeModal.luau`), replacing `FortressTreeController.luau`:**
   - **Layout:** a full-screen, windowless hex map over a light dim of the world. The orange Citadel sits in the centre, with five branches winding out from it:
     - Divine goes north.
     - Command goes north-east.
     - Commerce goes east.
     - Outskirts goes south.
     - Martial goes west.

     The axial layout lives in a shared table.
   - **Node states:**
     - **Owned:** blue with a ✓.
     - **Buildable:** blue with the price, red when you can't afford it.
     - **Floor-gated:** grey with "Floor N Required".
     - **Unreachable:** a grey "?".

     Tiles have white rims, branch icons and names.
   - **Input:**
     - **Pan:** drag anywhere.
     - **Zoom:** the scroll wheel zooms toward the cursor (0.45–1.8×, and the wheel does not reach the camera while the map is open); pinch on touch; plus **−/+** buttons.
     - **Recenter:** **⌖ RECENTER** resets both.
     - **Build:** click to build. On touch, the first tap previews and the second tap builds.
     - A release after a drag never counts as a click.
   - **Tooltip:** name, branch and level (or "COMMAND · SQUAD SLOT n"), effect, then cost / ✓ Built / the blocking reason. It follows the mouse, and on touch it sits beside the node.
   - **Purchase:** `ProgressionRemotes.UnlockTreeNode(nodeId)` returns `(ok, message)`; the tree refreshes from the next profile sync. A pop animation plays on success.
   - **Opened from:** the Architect's Table prompt, the Fortress toolbar button, locked squad slots and the facility panels.
5. **Plot Facilities (`FacilityModal.luau`):**
   - **Panels:** the Guard Post, Market, Training Grounds and God's Blessing. Each shows its summary line (level, workers used of total, bonus), with perk bonuses and perk worker slots included.
   - **No upgrade buttons:** facilities are levelled only in the Fortress Tree. A small "View in Fortress Tree" link is allowed.
   - **God's Blessing panel:** the luck breakdown (base, Acolyte labor, perk, the +50% cap), Acolyte assignment (`PRAY`) and the Healer synergy badge.
   - **No Infirmary panel.** The Infirmary was removed in Phase 4.
6. **The Pit (`PitModal.luau`):**
   - Unified Synthesis (duplicate fodder leveling) and Promotion (star ascension).
   - Locked until a facility worker is assigned (`profile.Unlocks.Pit`).

---

## 5. Cross-Platform Polish

1. **Mobile Safe Areas:**
   - All screens padded against `CoreUISafeInsets` to prevent notch and home-bar overlap.
   - Touch hitboxes $\ge 44 \times 44\text{ px}$.
   - The Fortress Tree's hex tiles count as hitboxes, so they must stay $\ge 44$ px at the minimum zoom on phones.
2. **Gamepad Navigation:**
   - Automatic `GuiService.SelectedObject` focus on modal open.
   - D-pad spatial navigation across all grid slots.
   - In the Fortress Tree, the D-pad moves between neighbouring hexes, the left stick pans, the triggers zoom, and `ButtonA` builds.
   - `ButtonB` closes open modals.

---

## 6. Retirement of Legacy Code

Delete once each React replacement passes its tests:

| Legacy script | Replaced by |
| :--- | :--- |
| `HUDController.client.luau` (now ~2,000 lines, incl. the stolen-loot banner and toolbar) | HUD root, toolbar, toast stack, `DuelPrompts` |
| `GoalTrackerController.client.luau` (Phase 4 interim) | Next Goal card |
| `DuelController.client.luau` (Phase 3 interim) | `DuelScreen` |
| `FortressTreeController.luau` (Phase 4 interim) | `FortressTreeModal` |
| `SquadController.luau`, `ForgeController.luau`, `FacilityController.luau`, `SynthesisController.luau`, `PromotionController.luau` | `SquadModal`, `ForgeModal`, `FacilityModal`, `PitModal`, `SummonModal` |

---

## 7. Server Contracts the UI Consumes

| Contract | Use |
| :--- | :--- |
| `SyndicateRemotes.ProfileDeltaSync` | `Unlocks`, `Onboarding`, `FortressTree`, `Facilities` (incl. `GodsBlessing`), hero `Rarity`, pity counters |
| `ProgressionRemotes.OnboardingSync` | Next Goal card |
| `ProgressionRemotes.UnlockTreeNode` (RemoteFunction) | Fortress Tree purchases |
| `TowerRemotes.LootContested` / `InitiateRetaliation` / `DuelState` | Retaliation prompt and duel screen |
| `SyndicateRemotes.SystemToast` | Toast stack, including lock hints |
| Shared modules | `FortressTreeConfig`, `FortressTree` (`CanUnlock`, `SquadSlots`, `PerkBonuses`), `SummonLuck`, `HeroCatalog.RarityName`, `LootDuel` constants |

---

## 8. Verification & Acceptance Criteria

1. **React Component Specs (`tests/phase5-ui.spec.luau`):**
   - Unit test each React component rendering in isolation.
   - Verify HUD respects `profile.Unlocks` and shows max 4 elements.
   - **Fortress Tree:**
     - Node state is correct for each of owned, buildable, gated and hidden.
     - Zoom keeps the point under the cursor fixed, and panning stays within the map bounds.
   - **Squad screen:** locked slot rendering matches `SquadSlots`.
   - **Summon screen:** the luck badge and boosted odds match `SummonLuck`.
   - **Duel screen:** it follows START → END → CLEAR, and the camera is handed back.
2. **Studio Playtest & Safe Area Inspection:**
   - Test UI across Mobile, Tablet, Console, and PC emulator modes.
   - Confirm zero overlapping text and flawless gamepad navigation.
   - Walk a fresh profile through the full 7-step onboarding using only the new UI.
   - Run a two-client retaliation duel.
