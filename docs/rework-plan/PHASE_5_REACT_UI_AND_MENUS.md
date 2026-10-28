# Phase 5: Unified React-lua UI, HUD & Menu Migration

**Document Version:** 3.3 (adds the facility panel redesign)  
**Phase Status:** In progress, slice 1 of 3 done (see §9)  
**Prerequisites:** Phases 1 through 4 complete (Phases 3 and 4: PR #72)  

---

## 1. Objectives & Scope

Phase 5 delivers the complete front-end overhaul using **React-lua** (`jsdotlua/react` + `react-roblox` 17.2.1). With all underlying game loops, combat pacing, death flows, and progression services finalized in Phases 1–4, the entire client presentation can be built against real, production-ready server contracts with **zero throwaway code or mock states**.

Phases 3 and 4 shipped interim imperative UI for their features. Phase 5 rebuilds each one in React against the same server contracts and then deletes the interim script (§6). **No server contract changes:** the components read the profile sync and the remotes listed in §7.

---

## 2. Core HUD Architecture (Seven Fixed Zones)

The HUD is limited to **seven fixed zones** (the earlier four plus the side rails, the status card and the Squad Power badge). Nothing else stays on screen; prompts, toasts and modals come and go. Every zone sits inside `CoreUISafeInsets`, is laid out in scale with `UISizeConstraint` limits, and **zones never overlap**.

```
+-----------------------------------------------------------------+
| [Gold 1,250] [Gems 45]     [=== Floor 3: 12/20 ===]  [NEXT GOAL]|
| (1 Top-Left)               (2 Top-Center)            [3/7 ...  ]|
|                                                     (3 Top-Right)|
| +--+                                                       +--+ |
| |SU|                                                       |OD| |
| |SQ|  (4 Left Rail: menus)            (5 Right Rail: combat)|RC| |
| |FG|                                                       |TW| |
| |FT|                                                       +--+ |
| |IX|                                                            |
| +--+                                                            |
| +-----------------------+                                       |
| | Han ⚔️ Common 1★ Lv.4 |                                       |
| | [HP====    ][SK== ]   |                                       |
| | Jenna ...  (6 Squad   |                        +------------+ |
| | 🔒 Slot 3   Status)   |                        | ⚔ 12,480   | |
| +-----------------------+                        | (7 Power)  | |
|                                                  +------------+ |
+-----------------------------------------------------------------+
SU Summon · SQ Squad · FG Forge · FT Fortress · IX Index
OD Overdrive [Q] · RC Recall [E] · TW Tower
```

1. **Top-Center — Floor Progress & Boss Health Bar:**
   - Displays real-time mob kill progress: `[=== Floor 1: 14/15 ===]`.
   - On boss summon, smoothly morphs into an intimidating Boss Health Bar with phase indicators and name banner.
2. **Bottom-Left, above the Squad Status Card — Currency Bar** (moved from the top-left so money sits with the squad):
   - Displays Gold and Gems with responsive typography.
   - Smooth numerical tick-up and delta floaters (`+150 Gold`).
3. **Top-Right — Pinned "Next Goal" Quest Card:**
   - Reads `ProgressionRemotes.OnboardingSync` (`Step`: Index, Total, Title, Description, Reward; plus `Unlocks`). Hidden once the 7-step chain is complete.
   - Flashes on a new goal; tap/click opens a detailed quest panel with the reward preview.
   - Replaces the interim `GoalTrackerController.client.luau`.
4. **Left Rail — Menus (vertical, left edge):**
   - **Buttons, top to bottom:** Summon, Squad, Forge, Fortress and Index. Each button has an icon, a short label and an optional badge.
   - **Unlock rules:** buttons appear only for unlocked systems (`profile.Unlocks`). Summon and Index are always shown. Fortress shows once `Squad` is unlocked, because the Command branch opens with the first summon.
   - **Badges:**
     - **Fortress:** a node you can build.
     - **Squad:** an open slot with no hero.
     - **Forge:** a promotion you can afford.
     - **Index:** a newly owned hero you haven't viewed yet.
   - **Placement:** the rail is vertically centred in the space between the currency bar and the Squad Status Card.
5. **Right Rail — Combat (vertical, right edge):**
   - **Overdrive `[Q]`, Recall `[E]` and Tower.** Overdrive and Recall show their key or gamepad glyph, plus a radial cooldown sweep with the seconds left (§2.1).
   - **No overlap with the Next Goal card:** the rail's top is anchored to the card's bottom edge plus a 16 px gap. It moves up when the card is hidden (the chain is complete) and down when the card grows.
   - **Short screens:** buttons shrink, but never below 44×44 px, so the rail never reaches the card.
6. **Bottom-Left — Squad Status Card:** the live state of every squad slot (§2.2).
7. **Bottom-Right — Squad Power badge:** the squad's overall power (§2.3). The Right Rail's bottom stops 12 px above it, so the two never overlap.

The legacy single bottom-centre bar is retired; the bottom centre stays clear for the drop-cargo button and prompts.

### 2.0 Rail Button Style
- **Custom gothic icons, no disc:** chunky icons drawn from layered GUI shapes (`Hud/Icons.luau`, a 64-unit grid scaled to size). Each shape has a top-lit gradient, a thick black outline and a highlight sheen. The icons:
  - **Summon:** an amethyst crystal over a gold altar.
  - **Squad:** a blood-red shield over crossed blades.
  - **Forge:** an anvil and an ember hammer.
  - **Fortress:** a stone keep with an amethyst roof.
  - **Index:** an open leather tome.
  - **Overdrive:** a gold lightning bolt.
  - **Recall:** a cyan portal with a homing chevron.
  - **Tower:** an obsidian spire.
- **Label:** Cinzel Decorative at its heaviest weight, white fading to antique gold, with a thick black outline. It overlaps the foot of the icon.
- **Badges and keys:** a red badge with a white ring at the top-right, and a key chip at the top-left.
- **Cooldown:** the icon dims and desaturates, with the remaining seconds shown large in the middle.
- **Size and hover:** icons are 72 px and shrink to fit the rail (never below 44 px). Hovering grows the button 10%.

### 2.0b HUD Card Style
All HUD cards share the rail buttons' cartoon-gothic look: the Next Goal card, the Squad Status Card, the Gold and Gems chips and the Squad Power badge.
- **Panels:** an obsidian-violet gradient, a thick black outline and a thin inset gold rail (`Components.Panel`). Gold chips are tinted bronze, Gems teal, and Squad Power crimson.
- **Text:**
  - Titles and numbers use the heavy outlined gothic label: Cinzel Decorative Heavy, white fading to gold.
  - Body text uses Cinzel Bold with a light ink outline.
- **Bars:** chunky, with black outlines, gradient fills and a top shine. The skill gauge rim glows gold when full.
- **Icons** drawn in the same way, each breaking out over its card's edge:
  - **Goal:** a quest scroll with a wax seal.
  - **Gold:** a coin stack.
  - **Gems:** a cut diamond.
  - **Power:** crossed swords over a crimson boss.
  - **Lock:** a gold padlock, on the locked-slots tile.

### 2.1 Overdrive & Recall (kept, hotkeys activated)
The whistles stay in the game; Phase 5 removes only their old bottom-bar placement. **They are currently dead on keyboard:** the HUD buttons fire `CombatRemotes.WhistleCommand`, but no `[Q]`/`[E]` binding exists.
- **Bindings:** `ContextActionService` actions `WhistleOverdrive` and `WhistleRecall`. These are bound only while a Tower floor is active (`FloorId >= 1`), and unbound in the hub, on the plot and during a duel.
  - **Keyboard:** `Q` and `E`.
  - **Gamepad:** `ButtonL1` and `ButtonR1`.
  - **Touch:** the rail buttons.
- **When they're ignored:** the bindings do nothing while a modal is open, while typing in chat or a text box (`gameProcessedEvent`), and while the matching cooldown is running.
- **Recall and prompts:** Recall yields to a visible ProximityPrompt that uses the same key (GDD §4.5).
- **Server authority:** the server already enforces the cooldowns (Overdrive 20 s for +40% attack speed over 5 s; Recall 6 s) and blocks Recall during a duel. The client cooldown sweep is display only, started from a successful send and corrected by the server.

### 2.2 Squad Status Card
- **One tile per squad slot, laid out left to right** in slot order. The card has a fixed height and **grows to the right** as slots open; it never grows upward. Only open slots get a full tile (`FortressTree.SquadSlots`). The locked slots share one narrow tile, `🔒 Slots 3–5 · Fortress Tree`, which opens the tree.
- **Width fitting:** tiles are 176 px wide and shrink to 132 px so the card stays clear of the Squad Power badge. If even 132 px tiles would reach it, the card switches to the compact portrait strip.
- **Full tile:**
  - The hero's card portrait (the same hero-rig portrait as the Squad modal), framed in the hero's rarity colour.
  - Name, rarity, star and level.
  - **Archetype:** an icon plus a short label, e.g. `🛡️ Vanguard`. The icons are the same as the facility and squad screens: 🛡️ Vanguard, ⚔️ Striker, 🏹 Marksman, ⛏️ Miner, 🔮 Scholar, 💚 Healer. The phone strip shows the icon only, on the portrait's corner.
  - **HP bar.** In the Tower it is live HP. On the plot or in the hub it shows stamina instead, with a label.
  - **Skill gauge** (0–100), glowing when full.
  - **State chip:** Fighting, Idle, Recalled, Down (KO / coma, with the seconds left), or Dueling.
- **Empty open slot:** `+ Assign`, which opens the Squad modal on that slot.
- **Data:**
  - HP comes from the tower room snapshot and entity metadata (`_G.ClientCombatState`).
  - Skill gauge and state come from the same feed. If a field is not in the 24-byte entity record, add it to the throttled metadata sync (≤ 2 Hz) rather than to the record.
  - Profile data covers stamina, rarity and level.
- **Interaction:** clicking a row selects that hero as the camera focus. Double-click (or `ButtonY`) opens the Squad modal.
- **Phone layout:** the card collapses to a strip of hero portraits with an HP line and an archetype corner icon; tap to expand.
- **Position:** anchored bottom-left above the safe-area inset, with the Gold/Gems bar 8 px above it. The left rail stops 12 px above the currency bar, and neither overlaps the drop-cargo button.

### 2.3 Squad Power Badge
**Squad Power** is one number for the whole active squad:
$$\text{HeroPower} = \text{round}\big(10 \times \text{DPS} + \text{Health}\big) \qquad \text{SquadPower} = \sum_{\text{deployed heroes}} \text{HeroPower}$$
DPS and Health come from `StatFormulas.GetCombatSnapshot`, which already includes stars, level, rarity, the equipped weapon and the Training Grounds multiplier. Heroes in a coma still count; only deployed squad slots count. The weights (10 × DPS + Health) are first-pass tuning.
- **Display:** a compact badge bottom-right, showing `⚔ 12,480` and the label `SQUAD POWER`.
- **Changes:** when power changes (a hero is deployed, levelled, promoted, re-equipped, or a Training Grounds change), the number ticks to the new value and shows a green `+840` or red `−320` floater.
- **Tooltip:** hover (or tap) shows each deployed hero's power and the Training Grounds multiplier.
- **Source of truth:** the server computes Squad Power so the HUD and the player list (§2.4) always agree, and sends it in the profile sync as `profile.SquadPower`. The client only displays it.
- **Phone:** shrinks to the number only.

### 2.4 Player List (Leaderboard) Columns
The Roblox player list (top-right, opened with `Tab`) gains two columns for every player in the server, using `leaderstats`:

| Column | Value | Updated when |
| :--- | :--- | :--- |
| **Floor** | The highest Tower floor the player has cleared (`profile.HighestClearedFloor`, 0 before the first clear) | A floor boss is cleared |
| **Power** | That player's Squad Power (§2.3), shown abbreviated (`12.4K`, `3.1M`) | Their squad, heroes, weapons or Training Grounds change; throttled to at most once every 2 s |

- **Server only:** `DataManager` creates the `leaderstats` folder on join (an `IntValue` named `Floor` and a `NumberValue` named `Power`) and writes both. Clients never write them.
- **Sorting:** Roblox sorts by the first stat, so `Floor` comes first, then `Power` breaks ties visually.
- **Placement:** the player list opens over the top-right, where the Next Goal card sits. While the list is open, the card stays where it is, under the list. No HUD zone moves.

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
   - **Assignment on every hero card:** each roster card shows where that hero is assigned now, as a coloured chip:

     | Assignment | Chip |
     | :--- | :--- |
     | `SQUAD_SLOT_n` | `⚔ Squad · Slot n` |
     | `FACILITY_GUARD_POST` | `🏕️ Guard Post` |
     | `FACILITY_MARKET` | `💰 Market` |
     | `FACILITY_TRAINING` | `⚔️ Training Grounds` |
     | `FACILITY_GODS_BLESSING` | `👼 God's Blessing` |
     | `BENCHED` | `Bench` (muted) |

     Moving a facility worker into the squad needs a confirmation that names the facility it leaves ("Take Valeria off God's Blessing?"), because the server removes the hero from the facility. A roster filter lets you choose All, Bench, Squad or Working.
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
5. **Plot Facilities (`FacilityModal.luau`), full redesign:** all four support facilities (Guard Post, Market, Training Grounds, God's Blessing) share one panel layout. Only the content changes per facility. Opened from each facility's `[F]` prompt.
   - **Header:**
     - The facility's name and accent colour, its current level (`Lv.3 · Stone Bastion`), the worker count (`2/3 workers`), and the archetypes that get the +25% bonus, as icons.
     - A **Next unlock** hint shows the next level or perk node in that facility's Fortress Tree branch, with its cost and floor requirement. Clicking it opens the tree focused on that node.
     - **No upgrade button:** facilities are levelled only in the tree.
   - **Bonus block (the panel's focus):** one large live figure, with a breakdown underneath:

     | Facility | Big figure | Breakdown |
     | :--- | :--- | :--- |
     | Guard Post | `💰 412 Gold/min` | Base rate (with Long Patrols), worker labor × 0.85, Biome Boss tier bonus; offline cap and efficiency (with Night Watch) and Gold earned while offline at the cap |
     | Market | `📦 +27.5% tower loot` | Level bonus (with Appraiser's Eye), worker labor × 0.005 |
     | Training Grounds | `⚔️ +18.2% squad ATK & HP` | Level bonus (with Veteran Drills), worker labor × 0.004, and the resulting change in Squad Power |
     | God's Blessing | `✨ +31% summon luck` | Base luck, Acolyte labor × 0.004, Saint's Favor, the +50% cap; plus the boosted top-tier odds on each banner |

   - **Worker slots:** one card per slot, from the facility's level plus perk slots (`StatFormulas.GetFacilityMaxWorkers`).
     - **Filled slot:** portrait, name, archetype, rarity, labor, a ★ bonus badge if the hero gets the +25%, and a remove button.
     - **Empty slot:** a `+` that opens the hero picker.
     - **Locked slot** (the facility can't hold more workers yet): 🔒 and the node that opens it.
   - **Hero picker:**
     - **Cards:** the same hero cards as the Squad modal, with rarity frame, archetype, level, labor and an assignment chip.
     - **Order:** heroes that get the +25% bonus are listed first and highlighted.
     - **Preview:** hovering (or first-tapping) a hero previews the change to the big figure, e.g. `+38 Gold/min`, before you assign.
     - **Taking a hero from elsewhere:** picking a hero who is in the squad or at another facility asks for confirmation that names where they come from.
   - **World link:** assigned workers appear at the facility in the world as they already do; the panel is the only place to manage them.
   - **Locked and unbuilt:** a facility with no prompt can't be opened. Old links to an unbuilt facility (such as notification badges) open the Fortress Tree on its first node instead.
   - **Layout:**
     - **Desktop:** header and bonus block on the left, worker slots and picker on the right.
     - **Tablet:** stacked, with the picker as a bottom sheet.
     - **Phone:** header, big figure, then slots; the picker is a full-screen sheet.
     - **Gamepad:** D-pad moves between slots and picker cards, `ButtonA` assigns, `ButtonX` removes, `ButtonB` closes.
     - Every screen keeps safe areas and 44 px hit targets.
   - **Data:** profile sync (`Facilities`, `FortressTree`, `Heroes`), `StatFormulas` (labor, gold rate, multipliers, worker slots), `FortressTree.PerkBonuses`, `SummonLuck`; assignments go through `AssignHeroRole` and **every refusal message is shown**. No new remote.
   - **No Infirmary panel.** The Infirmary was removed in Phase 4.
6. **The Pit (`PitModal.luau`):**
   - Unified Synthesis (duplicate fodder leveling) and Promotion (star ascension).
   - **One world prompt:** `[F] The Pit · Synthesis & Promotion`. The old separate Synthesis `[E]` and Promotion Altar `[F]` prompts are gone.
   - **Tabs:** the screen opens on Synthesis, with a tab navigator at the top: `THE PIT  |  🧪 SYNTHESIS  |  ⭐ PROMOTION`.
     - **Slice 1 (done):** the tab bar is a React element centred just above the open legacy window, and switching tabs swaps the two existing screens.
     - **Slice 3:** both tabs move into one React `PitModal`, with the tab bar inside its header.
   - Locked until a facility worker is assigned (`profile.Unlocks.Pit`).
7. **Hero Index (`IndexModal.luau`), new:** an encyclopedia of every hero, opened from the left rail's Index button and from a "View Index" link on each Summon banner. It is never locked. It has three columns:
   - **Left — Banners:** a list of hero banners: *Call of the Rift*, *A Star's Arrival* and any future banners. Each entry shows its title art, Permanent or Limited tag, tier count and owned count (e.g. `3/5 owned`). The selected banner is highlighted.
   - **Middle — Heroes in the banner:** a grid of that banner's heroes, sorted by rarity tier (highest first). Each card shows portrait, name, a frame in the rarity colour, and its summoned star.
     - **Unowned heroes** show as a darkened silhouette, but the name stays visible.
     - **Owned heroes** show a copy count badge.
     - A filter chip toggles **All / Owned**.
   - **Right — Hero details** for the selected hero:
     - Name, rarity, summoned star, archetype and weapon type.
     - Base and native HP/ATK, with the rarity multiplier shown.
     - Labor and preferred facility (e.g. Healers → God's Blessing).
     - Passive trait.
     - The Basic, Special and Skill kit, from `ArchetypeCombatSkills` (hero kit first, falling back to the archetype).
     - Drop rate on this banner, with and without the current God's Blessing luck, and whether it is the banner's pity hero.
     - If owned: copies, best star and highest level.
     - A 3D model preview from the hero rig templates, which can be turned by dragging.
   - **Data:** client-only, from `HeroCatalog`, `ArchetypeCombatSkills`, `StatFormulas`, `SummonLuck` and the profile; no new remote. The "new hero" badge is a per-viewer flag of heroes already opened, kept in the profile sync if saved profiles exist, otherwise session-only.
   - **Responsive layout:**
     - **Desktop:** three columns at 22% / 43% / 35%.
     - **Tablet:** the banner list becomes a top tab strip above heroes and details.
     - **Phone:** one column at a time (banners → heroes → details) with a back button.
     - **Gamepad:** bumpers switch banners, the D-pad moves in the grid, and `ButtonA` opens details.

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
| `HUDController.client.luau` (now ~2,000 lines, incl. the stolen-loot banner, bottom toolbar and whistle buttons) | HUD root, Left/Right Rails, Squad Status Card, whistle bindings, toast stack, `DuelPrompts` |
| `GoalTrackerController.client.luau` (Phase 4 interim) | Next Goal card |
| `DuelController.client.luau` (Phase 3 interim) | `DuelScreen` |
| `FortressTreeController.luau` (Phase 4 interim) | `FortressTreeModal` |
| `SquadController.luau`, `ForgeController.luau`, `FacilityController.luau`, `SynthesisController.luau`, `PromotionController.luau` | `SquadModal`, `ForgeModal`, `FacilityModal`, `PitModal`, `SummonModal` |

---

## 7. Server Contracts the UI Consumes

| Contract | Use |
| :--- | :--- |
| `SyndicateRemotes.ProfileDeltaSync` | `Unlocks`, `Onboarding`, `FortressTree`, `Facilities` (incl. `GodsBlessing`), hero `Rarity`, pity counters, `SquadPower` (new) |
| `Player.leaderstats` (`Floor`, `Power`), new, server-written | Player list columns |
| `ProgressionRemotes.OnboardingSync` | Next Goal card |
| `ProgressionRemotes.UnlockTreeNode` (RemoteFunction) | Fortress Tree purchases |
| `TowerRemotes.LootContested` / `InitiateRetaliation` / `DuelState` | Retaliation prompt and duel screen |
| `CombatRemotes.WhistleCommand` (1 = Overdrive, 2 = Recall) | Right Rail buttons and `Q`/`E` bindings |
| Tower room snapshot, `CombatRemotes.EntityMetadataSync`, `_G.ClientCombatState` | Squad Status Card (HP, skill gauge, state) |
| `SyndicateRemotes.SystemToast` | Toast stack, including lock hints |
| Shared modules | `FortressTreeConfig`, `FortressTree` (`CanUnlock`, `SquadSlots`, `PerkBonuses`), `SummonLuck`, `HeroCatalog` (seeds, banners, `RarityName`), `ArchetypeCombatSkills`, `StatFormulas`, `LootDuel` constants |

---

## 8. Verification & Acceptance Criteria

1. **React Component Specs (`tests/phase5-ui.spec.luau`):**
   - Unit test each React component rendering in isolation.
   - Verify HUD respects `profile.Unlocks` and shows only the seven fixed zones.
   - **Squad Power:** the badge value matches `profile.SquadPower` and the §2.3 formula for a known squad, the change floater appears, and the Right Rail never intersects the badge.
   - **Player list:** `leaderstats.Floor` and `leaderstats.Power` exist for every player, update after a floor clear or a squad change, and match `profile.HighestClearedFloor` and `profile.SquadPower`.
   - **Layout:** the Right Rail never intersects the Next Goal card, and the Left Rail never intersects the Squad Status Card. Test at 1920×1080, 1280×720, an iPad and an iPhone safe area, and with the goal card shown and hidden.
   - **Whistles:** `Q`/`E` fire `WhistleCommand` 1/2 only on a Tower floor, never while typing, in a modal or in a duel, and never during a cooldown.
   - **Squad Status Card:** one full row per open slot, a single locked line, live HP and gauge changes, and the Down countdown.
   - **Facility panels:**
     - The big figure and breakdown match `StatFormulas` for a known worker set.
     - The hover preview equals the value after assigning.
     - Perk slots appear, and locked slots name their node.
     - Refusals are shown.
   - **Hero Index:**
     - Banner → hero grid → details selection.
     - Unowned silhouettes and owned counts.
     - Drop rate with and without luck matches `SummonLuck`.
     - Each layout switches correctly (desktop, tablet, phone).
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
   - On a Tower floor, press `Q` and `E` and confirm the Overdrive and Recall effects and cooldown sweeps.

---

## 9. Implementation Status

**Slice 1, the HUD shell (done; branch `feat/phase5-ui`):**

| Feature | Location |
| :--- | :--- |
| React mount | `UI/Phase5HudController.client.luau` |
| Components | `UI/Hud/` (`Theme`, `Store`, `Whistles`, `Components`, `HudApp`, `HeroIndex`) |
| Left and Right Rails, laid out from the screen size so they never overlap; legacy bottom toolbar hidden | `HudApp` |
| Next Goal card (replaces `GoalTrackerController.client.luau`, now deleted) | `Components.NextGoalCard` |
| Squad Status Card: live HP, skill gauge, state; stamina off-floor; compact strip on phones | `Components.SquadStatusCard` |
| Squad Power badge, computed on the server | `StatFormulas.GetSquadPower`, `DataManager.UpdateSquadPower` |
| `leaderstats` Floor / Power columns | `DataManager.UpdateSquadPower` |
| Whistles: Q/E and L1/R1 through one module, gated to Tower floors and blocked in duels | `Hud/Whistles`, `MasterController`, mount script |
| Hero Index: three columns, single-column on narrow screens, `ButtonB` closes | `Hud/HeroIndex` |

**Slice 1 differs from this spec in these ways:**
- **Status card row click** opens the Squad modal rather than focusing the camera on that hero.
- **Hero Index:**
  - Shows a static portrait, not a rotatable 3D model.
  - Has no tablet tab strip; narrow screens get the single-column flow.
  - The "new hero" badge lasts only for the session.
- **Forge badge** is not built yet.

**Visual standard:** every screen uses the **Gilded Grimoire** theme ([`docs/ui/GILDED_GRIMOIRE.md`](../ui/GILDED_GRIMOIRE.md), `Shared/Util/GildedGrimoire.luau`). It means ink-outlined, gold-railed gradient panels, heavy Cinzel type and code-drawn cartoon icons. The shared gothic kit (`GothicBoxStyle`, `GothicFont`) renders in this theme, so Summoning, Synthesis, Promotion and the Forge use it too, and they call `GildedGrimoire.Watch` to convert their leftover Gotham text. React screens use it through `Hud/Gothic.luau` and `Hud/Components.luau`.

**Slice 2 (in progress):**
- **Done:**
  - The facility panel redesign (§4.5) as one gothic React panel, `Hud/FacilityPanel.luau`, used by the Guard Post, Market, Training Grounds and God's Blessing prompts. It has a header with the next Fortress Tree node, the big bonus figure and breakdown, worker slots with remove buttons and a locked-slot hint, and a hero picker with a hover preview, confirmation for heroes working elsewhere, and server refusal messages.
  - A gothic Pit tab bar; the Pit windows now leave 64 px above them for it.
  - **Squad Deploy redesign** (`UI/SquadController.luau`, still imperative, in Gilded Grimoire):
    - **Slot cards:** a portrait with a rarity ring and archetype icon, plus power, rarity, level and resting state.
    - **Slot buttons:** CHANGE + REMOVE on a filled slot, ASSIGN on an empty one, UNLOCK on a locked one (opens the Fortress Tree).
    - **Choosing a hero:** CHANGE or ASSIGN highlights the heroes who can take that slot; clicking one assigns it, and a squad hero swaps slots.
    - **Clicking a hero with no slot chosen** fills the first empty slot. When the squad is full, the hero is held and every slot offers REPLACE.
    - **Roster:** a grid with chips for each hero's slot, facility or resting state, power/stars/level sorting, and a "ready only" filter.
    - **Server replies:** the screen shows the AssignHeroRole result. The server now validates the slot before it removes the hero from a facility.
  - **Tower selector:** shows each floor's **Recommended Power** (`TowerFloorConfig.RecommendedPower`) next to your Squad Power, in red when you're under it. The value is the floor roster's Σ(MaxHP + 10 × ATK) × 0.08, so Floor 1 ≈ one fresh 1★ hero (~700).
- **Next:** React Summon (assignment chips, slot locks).

**Slice 3:** Fortress Tree, Forge, Pit and duel screens in React, then delete the legacy controllers (§6).

**Note from PR #73:** it made facility buildings always visible. That is reverted: the Phase 4 rule (§5.6) stands, so the Market and Training Grounds stay hidden until their first Fortress Tree node is built.

