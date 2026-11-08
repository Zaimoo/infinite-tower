# UI Overhaul Plan: one game, one UI

Status: **plan only, nothing implemented**. Written 2026-11-09 from a Studio playtest audit (HUD, Forge, Blacksmith summon, Synthesis and its picker, Promotion, Tower, Fortress Tree, Hero Index, Store, Settings) and a code read of `src/StarterPlayerScripts/UI`.

Ground rules:
- Keep every feature, screen and flow that exists today. This plan restyles, unifies and adds feedback. It removes nothing players use.
- **Gilded Grimoire** (`docs/ui/GILDED_GRIMOIRE.md`) stays the theme. The references (a bright simulator HUD, an inventory window and a rebirth window) are guides to *structure and feel*: chunky tiles, colour-coded intent, big numbers, before→after previews, warnings next to the action. We are not copying their look.
- The HUD Left/Right Rail buttons keep their current chunky icon style. The user decided that on 2026-11-03.

---

## 1. Diagnosis: why the UI reads as bad, convoluted, inconsistent and plain

### 1.1 Root causes

| # | Root cause | Evidence |
| --- | --- | --- |
| R1 | **Three-and-a-half visual languages.** Grimoire chunky (Promotion, Tower, Synthesis, Fortress Tree), Clear Glass (HUD cards, leaderboard, banners), the Forge Workbench's flat dark tokens (`ForgeWorkbench/Tokens.luau`), and Settings' web-dashboard look (`Settings/SettingsComponents.luau`). | Screens side by side do not look like one game. Promotion, Tower and Upgrades look good *because* they commit to one language. |
| R2 | **No shared window anatomy.** Every window builds its own header, title placement, currency display and close button. | 8 close-button implementations in PlayerGui: `GothicCloseButton`, `CloseForgeButton`, `Close` (Index/Shop), `PickerClose`, `CloseBtn`, `CloseDrawerBtn`, the Fortress Tree's red "Close" bar, `ExitButton` (Settings). Titles are left-aligned in most windows, centred in Store and Promotion, letter-spaced in Settings and the Blacksmith. |
| R3 | **Warnings are footer text.** Errors, refusals and results go to a small muted label at the bottom of the window. | `self.Status`/`Message`/`Footer` labels in Facility, Fortress Tree, Promotion (two), Squad (two), Synthesis, Tower, HeroSelectionDrawer, the Forge "Optimal gear equipped…" line and the Facility panel's `say()`. Easy to miss, and they never explain *what to do*. |
| R4 | **Inconsistent confirmations.** Destructive and expensive actions confirm in one place and not the next. | Forge sell has `C.ConfirmModal`. Synthesis has its own popup. The Facility panel uses a press-twice "CONFIRM" button. Promotion sends `ConfirmRare = true` unconditionally (`PromotionController.luau:818`), so the server's rare-donor safeguard never reaches the player. Summon 10x (45,000 Gold / 1,800 Gems), Visit Floor while under-powered, Reset Defaults and Leave Raid have no confirmation. |
| R5 | **Weak button hierarchy.** The primary action is often the least prominent control. | Synthesis: "SELECT HERO" is gold and "CONFIRM SYNTHESIZE" is dark. The hero picker has 16 identical gold SELECT buttons. Promotion's disabled PROMOTE looks like an enabled one. Store's "COMING SOON" looks clickable. |
| R6 | **No window manager.** Open state is coordinated through `_G.Open*`, `_G.Is*Open`, `_G.SetModalFocusMode` and `_G.UpdateBottomTabHighlights`. | HUD currency chips and the squad strip draw *over* open windows (Index, Store, synthesis picker). Rails stay live behind modals. Esc and gamepad B close only Tower, the hero drawer and the Forge Workbench. Windows pop in through `ModalFit` but vanish instantly (already in `UI_REWORK_BACKLOG.md`). |
| R7 | **Plain surfaces.** Large flat dark fills, tiny type and empty space. | Synthesis's empty right half ("Select a hero first"), Settings' empty lower half, Hero Index's two-column grid in a three-column space, black Forge tiles, 11 px leaderboard text, 10 px Forge action labels. |
| R8 | **Little feedback or motion between states.** | Tabs swap instantly, lists pop in all at once, numbers jump, a selection gets only a stroke change, and there is no close animation. The single toast slot (`HUDController.client.luau:450`) *replaces* the previous message. |
| R9 | **Legacy code still loaded.** | `HUDController.client.luau` (2,288 lines) still builds the hidden `FloatingToolbar`, `TopBarContainer` and `CurrencyCluster`. Gotham fonts remain in 15 files despite the "never Gotham" rule (70 references in `ForgeController.luau` alone). |

### 1.2 Bugs found during the audit (fix first)

| ID | Bug | Where | Impact |
| --- | --- | --- | --- |
| B1 | Forge detail actions show the literal text **"Button"** over each icon. `C.IconAction` creates a `TextButton` without `Text = ""`. | `ForgeWorkbench/Components.luau:311` (uncommitted, on `feat/forge-ui-redesign`) | Visible on every artifact selection. |
| B2 | The Blacksmith summon view caps artifacts at `StatBalance.MaxArtifactInventory` (50) and ignores Storage nodes. The Workbench shows 29/**100** and the summon view 29/**50**. `SummonBlockReason` also **blocks summons client-side** at 50 when the server allows more. | `ForgeController.luau:1636` and `:1652`. Use `InventoryCapacity.ArtifactCap`. | Players with Storage upgrades are wrongly refused. |
| B3 | Controllers build twice. In a live session `MasterHUDScreenGui` holds 2× `BlacksmithForgeModal`, `ForgeScrim`, `ForgeWorkbenchOpenState` and `ArtifactsCatalogScrim`, and 3× `HeroSelectionDrawer`. | Probably `ForgeController` and `HeroSelectionDrawer` construction on respawn or re-require. Needs investigation. | Memory use, duplicate connections, and possible double-fired handlers. |
| B4 | Promotion bypasses the rare-donor confirmation (see R4). | `PromotionController.luau:818` | A safety net is silently disabled. |
| B5 | `RailButton` accepts `DisabledReason`, but nothing passes or renders it. Overdrive greys out with no explanation. | `Hud/Components.luau:124` | Players do not know why the button is off. |
| B6 | Settings says "Changes apply instantly" but shows an Apply button. | `Settings/SettingsApp.luau` | Contradicts itself. |
| B7 | Hero Index detail panel is clipped at the bottom ("Drop rate" cut off). Its title-bar progress bar has no label. | `Hud/HeroIndex.luau` | Reads as broken. |

---

## 2. What we take from the references (principles, not looks)

1. **Every window has a coloured header bar** with an icon, a title and a red X in the same place. *We do:* one `Window` header in Grimoire, tinted per domain.
2. **Colour = intent** on action buttons (green equip, blue recall, grey neutral, red danger). *We do:* a fixed button-intent palette (§3.3).
3. **Category tabs on the left with big icons** (Pets/Items/Eggs). *We do:* a standard vertical tab rail for multi-section windows (Forge Artifacts/Summon, Pit Synthesis/Promotion, Index Heroes/Artifacts, Settings).
4. **Big numbers, small labels.** Currency, DPS and power are the largest text on screen. *We do:* a type scale where numbers are a step above labels (§3.2).
5. **Before → after on every upgrade** ("×34.75, now ×33.25"). *We do:* a `DeltaStat` component used by Promotion, Synthesis EXP, Forge upgrade, Equip Best and Fortress nodes.
6. **The warning sits next to the action, in colour, and says what to do** ("Need 287Qi more Cash", "Rebirth clears your unsold loot. Sell it first!"). *We do:* `Callout` (§4.4) replaces footer status text.
7. **Progress bars carry their numbers inside** ("53.1Qi / 341Qi"). *We do:* `Bar` with an inline label everywhere (EXP, pity, capacity, kill bar).
8. **Notification badges ("!")** on things that need attention. *We do:* rail badges already exist. Wire them to real signals (§5.1).

---

## 3. Target design system: "Grimoire v2"

One token module, `Shared/Util/GildedGrimoire.luau`, stays the single source. `Hud/Theme`, `ForgeWorkbench/Tokens`, `PitDesignTokens` and `Settings/SettingsConfig` colours become thin re-exports, then go away.

### 3.1 Surfaces
| Token | Use |
| --- | --- |
| `Window` | Violet top-lit gradient, 3 px ink outline, gold rail, diamond studs on the corners. Every modal window. |
| `Panel` | Deep tone, 2 px ink, gold rail at 50%. Sections inside a window. |
| `Tile` | Rarity-tinted top-lit gradient (never flat black), 2 px ink, rarity-coloured rail, and a soft inner glow for Exalted+. Artifact, hero and material tiles. |
| `Glass` | Clear Glass. **HUD status cards only** (power, event, leaderboard), and a bit stronger: base 0.25, 14 px numbers minimum. |
| `Scrim` | Black at 0.45 behind every modal, plus `Lighting` blur 8. One scrim, owned by the window manager. |

### 3.2 Type scale (Cinzel family, no Gotham)
| Role | Size (px, at 1080p) | Font |
| --- | --- | --- |
| Window title | 28 | Cinzel Decorative Heavy, white→gold, ink stroke |
| Section header | 18 | Cinzel Heavy |
| Big number | 26–34 | Cinzel Heavy number style |
| Body | 15 | Cinzel Bold, parchment |
| Caption / chip | 13 (**floor**) | Cinzel Bold |
Nothing below 13 px. That retires the 10 px Forge labels and the 11 px leaderboard. Phones take the `ModalFit` scale, never smaller fonts.

### 3.3 Button intents (one `Button` component, React and imperative)
| Intent | Tone | Used for |
| --- | --- | --- |
| `Primary` | Gold | The one main action of a window (Promote, Synthesize, Summon, Visit Floor, Build) |
| `Confirm` | Jade (green) | Equip, Equip Best/Squad Optimal, Claim |
| `Travel` | Azure (blue) | Recall, Hub, Island, Assign Squad |
| `Secondary` | Deep violet | Filters, sort, view odds, cancel |
| `Danger` | Crimson | Sell, Salvage, Leave Raid, Reset |
| `Disabled` | Slate, desaturated icon, lock glyph | Any blocked action. **Always** carries a `Reason`, shown as a tooltip and an inline callout (§4.4). |
Sizes: `L` 56 px (window primary), `M` 44 px (default, the touch minimum), `S` 36 px (chips and filters, mouse-only rows).

### 3.4 Spacing and shape
4-pt grid (4/8/12/16/24/32). Corners: window 16, panel 12, tile/button 10, chip 999 (pill). Tile grid gap 8. Window padding 16.

### 3.5 Colour meaning (locked)
Gold = currency, primary or local player. Amethyst = selected/focus. Jade = gain/HP/safe. Crimson = loss/danger/boss. Azure = travel/info. Rarity colours appear only on rarity, never as decoration.

---

## 4. Shared kit to build (`src/StarterPlayerScripts/UI/Kit/`)

Each module is `--!strict`, has a React component *and* an imperative adapter, because half the screens are imperative (`ForgeController`, `SynthesisController`, `PromotionController`, `FacilityController`, `FortressTreeController`, `TowerController`, `SquadController`). The adapters let us restyle those without rewriting them in React first.

### 4.1 `WindowManager`
- Registry `{ id, open, close, isOpen, priority }`. It replaces the `_G.Open*` and `_G.Is*Open` globals; keep thin `_G` shims for one release.
- One modal at a time, with stack semantics (a picker opened from Synthesis pushes; closing pops back).
- Owns the scrim, the blur, and **HUD focus mode**: while a window is open the rails, currency chips and squad strip fade to 0 and stop taking input. That fixes HUD chips drawing over windows.
- Esc, gamepad B and a scrim click close the top window. A window can veto the close ("unsaved selection"), which opens a ConfirmDialog.
- Open and close transitions: open is scale 0.92→1 with Back easing over 0.22 s plus a scrim fade. Close is scale 1→0.95 and fade over 0.14 s, *then* `Visible = false`. That clears the backlog item "Window close transitions".
- Sets `GuiService.SelectedObject` on open and restores it on close.

### 4.2 `Window` (anatomy every modal uses)
```
┌ [icon] TITLE ───────── [Gold chip][Gems chip][Cap chip] [X] ┐  header 64 px, domain tint
│ [tab rail]│ body                                            │
│           │                                                 │
├───────────┴──────── [Callout] ─────── [Secondary] [PRIMARY] ┤  action footer 72 px
└─────────────────────────────────────────────────────────────┘
```
- Domain tints on the header: Forge = ember, Pit (Synthesis/Promotion) = amethyst, Tower = azure, Fortress = gold, Index = parchment, Store = crimson, Settings = slate.
- Currency chips are the same `CurrencyChip` as the HUD's, top-right, in every window, and only the currencies that window spends.
- The close X is always top-right: 44 px, crimson, ink outline.

### 4.3 `Notify` (toasts)
- A stack of up to 3 toasts, top-centre below the top bar. Each slides in, is pushed down by newer toasts, and shows an icon by type: `info`, `success`, `warn`, `error`, `reward`.
- `reward` toasts carry an icon and an amount, count up, and fly a small icon to the matching HUD currency chip.
- Same-text toasts coalesce with "×3" instead of flickering.
- The `SystemToast` remote and `showClientToast` route here. The single-slot `playToast` is retired.

### 4.4 `Callout` (warnings next to the action)
- An inline pill that sits directly above or beside the primary button, with an icon, one line of text and an optional fix-it link ("Need 2,400 more Gold · **Get Gold**", "Inventory full · **Sell weapons**").
- Severities: `info` (azure), `warn` (amber, with a slow pulse), `block` (crimson; the primary button is Disabled with the same reason).
- It replaces every footer `Status`/`Message`/`say()` label. Transient results ("Saved", "Optimal gear equipped on 2 heroes") go to `Notify` instead.

### 4.5 `ConfirmDialog`
Three tiers, chosen by the risk table in §6:
- **Soft:** title, body, Cancel and Confirm, with "Don't ask again this session".
- **Hard:** adds a summary of what is lost (tiles of the consumed items), and Confirm is Danger-toned with a 1 s arm delay.
- **Critical:** hold-to-confirm (1.2 s ring fill) for irreversible loss of rare+ items.
Each tier is gamepad-safe: focus starts on Cancel. The existing `C.ConfirmModal` and the Synthesis popup become this component.

### 4.6 `Tooltip`
- One tooltip layer and one instance, positioned to the cursor or anchor with edge flipping.
- Triggers: hover after 0.35 s (mouse), long-press after 0.4 s (touch), selection plus a 0.5 s dwell (gamepad).
- Content: a title, a rarity or tag line, up to 4 stat lines with `DeltaStat` support, a body line, a disabled reason in crimson, and a key hint.
- API: `Tooltip.Bind(guiObject, contentFn)` imperative, and `<Tooltip.Target content=…>` in React. The Fortress Tree's private tooltip (`FortressTreeController.luau:718`) and the squad strip tooltip move onto it.

### 4.7 Building blocks
`Button` (§3.3), `IconButton`, `CurrencyChip`, `Bar` (inline label, segmented option, full-glow), `DeltaStat` (old → new with an arrow, green or red), `Tile` (artifact/hero/material variants, with selected, locked, equipped, new and disabled states), `TabRail`, `SegmentedControl` (sort/filter chips), `EmptyState` (illustration icon, one sentence and a primary action, instead of a blank panel), `Badge`, `SearchBox` (left-aligned placeholder, clear button).

### 4.8 Motion presets (extend `UIFeel`)
| Preset | Spec | Where |
| --- | --- | --- |
| `Open`/`Close` | §4.1 | All windows |
| `TabSwap` | Old content fades and slides 12 px out; new content slides in (0.16 s) | Every tab rail or segmented control |
| `Stagger` | Grid children pop in 18 ms apart, capped at 12 animated, rest instant | Inventory, materials, picker, index |
| `Select` | Tile scale 1→1.06→1.03, rail brightens, check badge pops | Tiles |
| `NumberTick` | `UIFeel.CountUp` + green/red flash and a floater | Currency, power, EXP, stars |
| `BarFill` | Ghost bar shows the preview, real bar tweens on commit | EXP, pity, kill bar |
| `Attention` | 2 s glow pulse plus badge bob, for new or claimable items | Rail badges, new artifacts |
| `Deny` | Existing `UIFeel.Deny` plus the Callout flashing | Every refused action |
| `Success` | Burst + shimmer on the primary button + `Notify` | Commit results |
All presets respect `UIFeel.ReducedMotion()`.

---

## 5. Per-screen plan

### 5.1 HUD (`Phase5Hud`, `Hud/*`, `HUDController`)
- **Keep** the rail icon style. Fix the key chips: they float apart from their icons ("Q", "E" sit to the left of Overdrive and Recall). Anchor them to the icon's top-left inside the button bounds.
- Overdrive: render `DisabledReason` as a tooltip and as a small lock glyph (B5). The cooldown already shows seconds; add a radial sweep.
- Currency chips (bottom-left): move up a size (big number 22 px). Show the `+87` gain floater consistently. Clicking a chip opens a tooltip with income per minute and a "Get more" link to the Store.
- The squad strip plus the orphaned "Assign" button become one unit: Assign docks onto the strip's right end as a `Travel` button.
- Power and Tower Event cards: Glass stays, but numbers go to 22–26 px, labels to 13 px. The event card gets a progress ring for the timer.
- Leaderboard: 14 px minimum. Highlight the local player's row in gold. Collapse it to a small "People (n)" tab rather than a tiny X.
- Rail badges are wired to real signals: Index (new heroes), Store (limited banner live), Upgrades (a node is affordable), Backpack (inventory ≥90% or a new artifact).
- Delete the hidden legacy toolbar, top bar and currency cluster from `HUDController` once nothing reads them (R9).

### 5.2 Forge Workbench (`ForgeWorkbench/*`): finish on the current branch
- Fix B1. Give the detail actions real labels (`IconButton` M size, 13 px).
- Remove the duplicates: "Filters (0)" (top) and "Filter (0)" (bottom), and "BEST" (top) and "Equip Best / Squad Optimal" (bottom). Keep search, filters and sort on top, actions at the bottom.
- Tiles: rarity-tinted gradient instead of black, the star row as icons, and the power number at 15 px. Locked shows a padlock corner, equipped the owner's portrait corner.
- Detail panel: `DeltaStat` against the currently equipped weapon of the target hero ("+1.2M DPS ↑").
- Move "Optimal gear equipped on 2 squad members." to `Notify`. Turn "Undo expired" into a ghost Undo button with a countdown ring that disappears when it expires.
- The capacity chip warns at ≥90% (amber) and when full (crimson), with a Callout "Inventory full · Sell".
- Confirms: sell of Rare+ (Hard), sell of Exalted+ or any starred weapon (Critical), and an Upgrade that consumes Rare+ donors (Hard, showing the donor tiles).

### 5.3 Blacksmith summon (`ForgeController` summon view)
- Fix B2.
- Clean up the banner preview: remove the red pill blob behind the centre weapon, and give the carousel a rarity-coloured ring glow.
- Summon buttons: 1x is `Primary` and 10x is `Primary` with a "BEST VALUE · Rare+ guaranteed" ribbon. Show cost chips with the player's balance in red when short, and Disabled with a reason.
- The pity bar gets inline labels: "Exalted+ in 94" inside the bar and "Rare+ in 7" as a second thin segment bar.
- Confirm: Soft confirm for 10x on the first use per session ("Spend 45,000 Gold?"), with "don't ask again".

### 5.4 Synthesis and its hero picker (`SynthesisController`, `HeroSelectionDrawer`)
- Empty state: replace the blank right half with an `EmptyState` (an illustration, "Pick the hero who receives EXP", and a Primary "Select Hero" button). The left "SELECT HERO" becomes Secondary.
- "CONFIRM SYNTHESIZE" becomes `Primary`, Disabled with a reason until materials are picked.
- EXP bar: change the blue to the Grimoire gold bar. Show a ghost preview of the EXP gained, a level-up marker ("Lv 8 → 10"), and an overflow warning Callout when EXP is wasted past the cap.
- Material tiles: equipped heroes move to a collapsed "In use" section and cannot be selected. Selected tiles get a check badge and a counter ("6 selected · +2,140 EXP").
- Picker: remove the 16 gold SELECT buttons. The whole card is the button, with hover glow and a tooltip of stats. Use one "Choose" footer button for gamepad. Hide HUD chips while the picker is open (R6).
- Confirm: Hard when any donor is Rare+ or starred (the existing `RequiresRareConfirmation`), showing donor tiles.

### 5.5 Promotion (`PromotionController`): the template for the others
- It already looks good. Keep the ring stage and the compare table, but use `DeltaStat` rows (green arrows) and show "—" as an EmptyState hint.
- Fix B4: if `preview.RequiresRareConfirmation`, show a Hard confirm; otherwise commit.
- Disabled PROMOTE gets Slate with a reason. The status text moves to a Callout ("Need 3 more Promotion Stones").
- Commit plays the success preset: ring spin-up, star pop, `NumberTick` on stats.

### 5.6 Tower floor selector (`TowerController`)
- Keep the layout. "(under-powered)" becomes a crimson `Callout` with the gap ("You're 8.3M under the recommended power"). **Visit Floor** while under-powered opens a Soft confirm.
- The footer "You: Hub · Squad: Following Master / Hub travel complete" becomes a status chip row in the header (location and squad state as chips). Travel results go to `Notify`.
- Locked floors get a tooltip: "Clear Floor 18 to unlock". Roster names get mob tooltips (HP, element).
- Biome cards: selected glow pulse, and stagger on open.

### 5.7 Upgrades / Fortress Tree (`FortressTreeController`)
- Keep the hex nodes and chains. They are the strongest screen.
- Replace the red bottom "Close" bar with the standard X. Move the title and help line into a compact `Window` header strip that sits below the Roblox top bar.
- Raise the scrim opacity and blur so hero nameplates and world clutter stop showing through.
- Moves its tooltip to `Tooltip` with `DeltaStat` lines and the cost against balance. Footer `Status` moves to `Notify` and Callouts.
- Affordable nodes pulse softly (`Attention`). Building plays the chain-light-up animation along the path to the new node.
- Confirm: Soft for nodes costing ≥25% of current Gold.

### 5.8 Hero Index (`Hud/HeroIndex.luau`)
- Label the header bar ("9 / 12 heroes collected"). Fix the clipped detail panel (B7) with a scroll or an auto-sized section.
- Make the grid responsive (`UIGridLayout` fill, 3–4 columns) so there's no empty gutter.
- Missing heroes: silhouette tiles with a "Where to get" tooltip (banner and drop rate).

### 5.9 Store (`Hud/ShopPanel.luau`)
- Standard `Window` header (title left, currency right). Fix the unreadable "LIMITED" pill.
- "COMING SOON" becomes a Disabled button with a lock and tooltip, visually distinct from purchasable items.
- Discounts become a proper ribbon ("-10%" corner banner with the struck price) rather than floating text.
- Purchases go through `roblox-monetization` patterns. Gems and Robux confirmations come from Roblox's own prompt, so no extra modal is needed.

### 5.10 Settings (`Settings/*`)
- Move it into Grimoire v2 (§3): `Window`, with the `TabRail` **on the left** like every other window.
- Resolve B6: either make everything apply instantly and remove Apply, or keep Apply and say "Unsaved changes" in a Callout. Instant apply plus a Revert is recommended.
- Fill the Overview with presets as large cards, each with a preview description and tooltips.
- Reset Defaults gets a Soft confirm.

### 5.11 Squad, Facility and the hero summon banners (`SquadController`, `FacilityController`, `Hud/FacilityPanel.luau`)
- Same window anatomy. `say()`, `SquadHint` and `Status` move to Callouts and `Notify`.
- The Facility "press CONFIRM twice" pattern becomes a Soft ConfirmDialog ("Take Valeria off the Guard Post?").
- Hero summon 10x (1,800 Gems): Soft confirm on the first use per session, the same as the Forge.
- Assignment chips get tooltips (what the facility does with this hero's labor).

### 5.12 Summon Reveal, Offline Reward, Duel, Raid HUD, Tower Event HUD, banners
- Strip the remaining Gotham fonts (Offline Reward, Duel).
- Offline reward: a reward toast also flies to the currency chip.
- Raid "Leave": Soft confirm (it already has a local `confirm` state; move it onto `ConfirmDialog`).
- Loot stolen, squad down and boss banners: one `Banner` component (Glass, accent bar, icon) with consistent slide-in and out.

### 5.13 World UI (`Rendering/EntityRenderer.client.luau`)
- Hero nameplates overlap heavily at mid-range (five large plates in a row). Scale them by distance and shrink to name plus HP beyond 40 studs. Show your own squad's plates fully only when you hover or target them. Turn `AlwaysOnTop` off for non-duel heroes.
- Hide all nameplates while a modal is open (WindowManager focus mode).

---

## 6. Warning and confirmation matrix

| Action | Risk | Treatment |
| --- | --- | --- |
| Sell Common/Uncommon artifacts | Low | None; Undo toast for 8 s |
| Sell Rare–Superior, or any locked-adjacent selection | Medium | Hard confirm |
| Sell or salvage Exalted+, or any ★2+ | High | Critical (hold) |
| Upgrade consuming Rare+ donors | Medium | Hard, showing donor tiles |
| Synthesis with rare or starred donors | Medium | Hard (`RequiresRareConfirmation`) |
| Promotion with rare donors | Medium | Hard (fix B4) |
| Summon 10x (Gold or Gems) | Spend | Soft, first time per session |
| Fortress node ≥25% of Gold | Spend | Soft |
| Visit floor under recommended power | Gameplay | Soft, with the power gap |
| Unassign hero from facility | Low | Soft |
| Leave raid / leave duel | Gameplay | Soft |
| Settings → Reset Defaults | Low | Soft |
| Inventory ≥90% / full | Info / Block | Amber / crimson Callout + Backpack badge |
| Not enough currency | Block | Disabled with reason + Callout "Need X more · Get" |

---

## 7. Tooltip inventory (minimum set)

Rail buttons (name, key, disabled reason), currency chips (balance, income/min), squad strip slots (already have one: move it to Tooltip), artifact tiles (name, rarity, ★, PWR, owner, Δ vs equipped), hero tiles (stats, assignment, stamina), Fortress nodes (effect Δ, cost vs balance, requirement), locked floors, roster mobs, summon buttons (cost, odds summary, pity), pity bar, capacity chip, Promotion and Synthesis stat rows, Settings options, Store items, leaderboard rows (squad power breakdown).

---

## 8. Architecture cleanup (done alongside, not as a separate project)

1. `WindowManager` replaces the `_G.Open*`, `_G.Is*Open`, `_G.SetModalFocusMode` and `_G.UpdateBottomTabHighlights` globals, keeping shims for one release.
2. Find and fix the double and triple builds (B3), and add a guard test in Studio (`tests/studio-*`) that counts PlayerGui children by name after respawn.
3. Remove the hidden legacy HUD from `HUDController.client.luau` and shrink it towards being a thin event router.
4. Run a Gotham sweep: `GildedGrimoire.Watch` already converts at runtime. Replace the sources so the runtime pass can be removed later.
5. Token consolidation (§3): `Hud/Theme`, `ForgeWorkbench/Tokens`, `PitDesignTokens` and the Settings colours re-export Grimoire.

---

## 9. Phases

Each phase is its own PR off `main` with conventional commits. Each adds Studio captures at 1920×1080, 1366×768 and phone landscape (Device Simulator) to `docs/screenshots/ui-overhaul/`, and updates `GILDED_GRIMOIRE.md` and `UI_REWORK_BACKLOG.md`.

| Phase | Scope | Size |
| --- | --- | --- |
| **0. Hotfixes** | B1 (on the current `feat/forge-ui-redesign` branch before its PR), B2, B4, B5, B6, B7 | S |
| **1. Kit foundation** | `Kit/` tokens re-export, `Button`, `CurrencyChip`, `Bar`, `DeltaStat`, `Callout`, `Tooltip`, `Notify`, `ConfirmDialog`, motion presets. Spec tests for pure logic (tooltip placement/flip, toast coalescing, confirm-tier selection from the §6 table). | L |
| **2. WindowManager** | Registry, scrim/blur, HUD focus mode, Esc/B, open/close transitions, `_G` shims; B3 investigation | M |
| **3. Pit + Forge** | Synthesis, picker, Promotion, Forge Workbench, Blacksmith summon onto `Window` + Kit; the §6 confirms | L |
| **4. Tower + Fortress + Index + Store** | §5.6–5.9 | M |
| **5. HUD pass** | §5.1, leaderboard, rail badges, legacy HUD removal | M |
| **6. Settings, Squad, Facility, popups, world UI** | §5.10–5.13 | M |
| **7. Polish** | Stagger/tab motion everywhere, sound pass (`UIAssets` slots), Reduce Motion audit, gamepad navigation audit | S |

Verification for each phase: `pwsh tests/run.ps1` (compile plus specs), then a Studio MCP playtest that opens each touched window, captures it, tests Esc/B close and the confirm paths, and checks the duplicate-instance count.

---

## 10. Decisions needed from you

1. **HUD cards:** should Clear Glass stay on the HUD status cards (power, event, leaderboard, currency) as recommended, or should the HUD go fully Grimoire for maximum consistency? The rails stay Grimoire either way.
2. **Saturation:** the references are much brighter. Should Grimoire v2 push saturation up (brighter domain-tinted headers, more colourful intent buttons) or stay moody gothic, adding colour only to intent and rarity?
3. **Confirm defaults:** is the §6 table the right risk level, especially Critical (hold-to-confirm) for Exalted+ sells?
4. **Settings apply model:** instant apply plus Revert (recommended), or explicit Apply?
