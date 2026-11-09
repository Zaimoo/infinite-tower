# UI Overhaul Plan: one game, one UI

Status: **plan only, nothing implemented**. Written 2026-11-09 from a Studio playtest audit (HUD, Forge, Blacksmith summon, Synthesis and its picker, Promotion, Tower, Fortress Tree, Hero Index, Store, Settings) and a code read of `src/StarterPlayerScripts/UI`.

Ground rules:
- Keep every feature, screen and flow that exists today. This plan restyles, unifies and adds feedback. It removes nothing players use.
- **Gilded Grimoire** (`docs/ui/GILDED_GRIMOIRE.md`) stays the theme. The references (a bright simulator HUD, an inventory window and a rebirth window) are guides to *structure and feel*: chunky tiles, colour-coded intent, big numbers, before→after previews, warnings next to the action. We are not copying their look.
- The HUD Left/Right Rail buttons keep their current chunky icon style. The user decided that on 2026-11-03.

**Decisions (2026-11-09):**
1. **HUD goes fully gothic.** Clear Glass is retired from the HUD cards (power, event, leaderboard, currency, banners). Everything uses Grimoire.
2. **Brighter, still Gilded Grimoire.** Raise saturation and value: brighter domain-tinted window headers, vivid intent buttons, glowing rarity rails, lighter panel interiors. Keep the ink outlines, gold rails, diamond studs and Cinzel type. See §3.0.
3. **The §6 confirmation table is approved as written**, including hold-to-confirm for Exalted+ sells.
4. **Settings keeps an explicit Apply button.** It gets an "Unsaved changes" state and a confirm when closing with unapplied changes (§5.10).

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

**Phase 0 status (2026-11-09):** B2 and B4–B10 are fixed in code and the test suite passes. They are **not yet verified in a Studio playtest**. B3 still needs its clean-session check. Fixing the suite also needed two test-harness repairs: a stray `end` in `tests/forge-workbench.spec.luau`, and registering `EquipBest` (plus its spec) in `tests/run.ps1`.
- **B2:** the summon view now uses `InventoryCapacity.ArtifactCount`/`ArtifactCap`, the same rule as the server.
- **B4** was not a live bug: Promotion never takes donor heroes, so the server never asks for rare confirmation. The client now sends the preview's flag instead of a blanket `true`, so the safeguard holds if that changes.
- **B5:** rail buttons show the reason in a bubble on hover, gamepad focus or tap, with a lock badge.
- **B6:** Apply is real now. The draft previews live, Apply keeps it, and closing with unapplied changes asks "Discard unsaved changes?". Another window taking over discards the draft.
- **B7:** long panels fade at the bottom while there's more to scroll, and the collection count sits inside the header bar.
- **B8–B10:** the Forge hint follows the route and selection. Disabled buttons lose the gold rail and show their reason as a tooltip. The copy is fixed. Buttons get unique `Action_<Text>` names.

| ID | Bug | Where | Impact |
| --- | --- | --- | --- |
| B1 | ~~Forge detail actions show the literal text "Button" over each icon.~~ **Fixed in `a61c3ce`** (`IconAction` now sets `Text = ""`). | `ForgeWorkbench/Components.luau` | Done. |
| B2 | The Blacksmith summon view caps artifacts at `StatBalance.MaxArtifactInventory` (50) and ignores Storage nodes. **Confirmed live:** at 44/100 the summon view says "Room for 6 more: a 10x needs 10 free slots" and greys out Summon 10x. | `ForgeController.luau:1636` and `:1652`. Use `InventoryCapacity.ArtifactCap`. | Players with Storage upgrades are wrongly refused 10x pulls. **Highest priority.** |
| B3 | Duplicate UI instances: 2× Forge host folders, Blacksmith modal and scrims, and 3× `HeroSelectionDrawer`. **Probably caused by another agent's Studio MCP session** re-running client scripts. Re-check in a clean playtest; only investigate if it reproduces. | Clean-session check in Phase 0 | Low until it reproduces. |
| B4 | Promotion bypasses the rare-donor confirmation (see R4). | `PromotionController.luau:818` | A safety net is silently disabled. |
| B5 | `RailButton` accepts `DisabledReason`, but nothing passes or renders it. Overdrive greys out with no explanation. | `Hud/Components.luau:124` | Players do not know why the button is off. |
| B6 | Settings says "Changes apply instantly" but shows an Apply button. | `Settings/SettingsApp.luau` | Contradicts itself. |
| B7 | Hero Index detail panel is clipped at the bottom ("Drop rate" cut off). Its title-bar progress bar has no label. | `Hud/HeroIndex.luau` | Reads as broken. |
| B8 | The Forge footer shows "Select an artifact to equip or upgrade." while an artifact *is* selected, and stays on the Upgrade stage. | `ForgeWorkbench/App.luau:646` | Wrong instruction. |
| B9 | "Review Upgrade" looks enabled (gold outline) with no material chosen. The copy reads "Choose 1 more artifacts", "500 Gold · 0 Gems · 1 artifacts" and "+×3.24". | `ForgeWorkbench/Screens.luau` (upgrade stage) | Sloppy, reads unfinished. |
| B10 | Four sibling sell buttons are all named `Action`, so tests, Studio MCP and gamepad focus maps cannot address them. | `ForgeWorkbench` sell action bar | Untestable. |

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

### 3.0 "Brighter Grimoire": what changes, what stays
| Stays | Gets brighter |
| --- | --- |
| Ink outlines (2–3.5 px), gold inset rail, diamond corner studs | Window **header bars** become saturated domain colours (ember orange, amethyst, azure, royal gold, crimson) with a subtle diagonal pattern, like the reference headers, instead of the same violet everywhere |
| Cinzel family, white→gold title gradient | Panel interiors lift from near-black (`#0D0912`) to a lighter violet-plum, so contents stop sitting in a void |
| Violet base tone, obsidian accents | Intent buttons use vivid fills (gold, jade, azure, crimson) with a top shine, not outline-only dark buttons |
| Rarity colours | Rarity tiles get a tinted gradient fill plus an outer glow from Exalted up; Mythical and above get an animated shimmer |
| No emoji, drawn icons | Icons get one value step brighter and a stronger white sheen |
Rule of thumb: **dark is for backgrounds only.** Anything you can press or read is bright. Contrast stays at least 4.5:1 for text.

### 3.1 Surfaces
| Token | Use |
| --- | --- |
| `Window` | Violet top-lit gradient, 3 px ink outline, gold rail, diamond studs on the corners. Every modal window. |
| `Panel` | Deep tone, 2 px ink, gold rail at 50%. Sections inside a window. |
| `Tile` | Rarity-tinted top-lit gradient (never flat black), 2 px ink, rarity-coloured rail, and a soft inner glow for Exalted+. Artifact, hero and material tiles. |
| `HudCard` | Compact Grimoire card for the HUD (power, event, leaderboard, currency, banners): ink outline, gold rail, a 0.1 transparency fill so the world still reads behind. It **replaces Clear Glass** (decision 1). |
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
- Backspace, gamepad B and a scrim click close the top window (Roblox reserves Esc for its own menu, so a game never receives it). A window can veto the close ("unsaved selection"), which opens a ConfirmDialog.
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
- Power and Tower Event cards move from Clear Glass to `HudCard` (Grimoire). Numbers go to 22–26 px, labels to 13 px. The event card gets a progress ring for the timer.
- Currency chips and banners (loot stolen, squad down, boss, toasts) also move to Grimoire. Retire the `Theme.Glass`, `GlassFrame` and `GlassText` usages and update `GILDED_GRIMOIRE.md` §Clear Glass.
- Leaderboard: Grimoire panel, 14 px minimum. Highlight the local player's row in gold. Collapse it to a small "People (n)" tab rather than a tiny X.
- Rail badges are wired to real signals: Index (new heroes), Store (limited banner live), Upgrades (a node is affordable), Backpack (inventory ≥90% or a new artifact).
- Delete the hidden legacy toolbar, top bar and currency cluster from `HUDController` once nothing reads them (R9).

### 5.2 Forge (`ForgeWorkbench/*`, `ForgeController` summon, `ForgeNavigation`)

Re-audited live on 2026-11-09 after `a61c3ce`, across all four states: Artifacts, Upgrade, material picker and Sell, plus the Summon tab.

**What works and stays:** square image-first tiles with 3D models, the rarity label with stars and power, equipped and locked protection with padlocks in Sell and the picker, the before→after numbers on Upgrade, quick-pick sell chips, Squad Optimal, the 44/100 capacity chip, and the red close X.

**Problems, by state**

| State | Problem | Fix |
| --- | --- | --- |
| All | **Artifacts and Summon are two different windows.** The tab switches from the Workbench frame (big red X, three chips, flat header) to the old gothic modal (diamond studs, small X, Gold chip only), and the window jumps size. The tab strip floats *outside* the window at the top of the screen. | One Forge `Window` (§4.2) with an ember header. Artifacts and Summon become a `TabRail` *inside* it, with the same frame, size and chips (Gold, Gems, capacity) on both tabs. |
| All | The HUD currency chips draw over the window's bottom-left corner and status line. | WindowManager focus mode (§4.1). |
| All | The footer status line is often wrong or redundant (B8), and in Sell it repeats the instruction box. | Remove the footer. Results go to `Notify`, blockers to a `Callout` above the primary button. |
| Artifacts | Tiles are flat black. On equipped tiles the border colour switches to teal and hides the rarity colour (an Exalted tile has a cyan border). Rarity text overlaps tall models ("Uncommon" behind the staff head). Stars, power and the equipped shield are 10–12 px. | Brighter tile (§3.0): rarity gradient fill and rail. Equipped becomes an **owner-portrait corner badge**, never a border colour. Rarity label sits on a top band above the model viewport. Power is 15 px bold and stars are drawn icons. |
| Artifacts | Detail panel: equipped weapons preview as a **tiny hero model** in a black box, so the weapon itself can't be read. The four icon actions (Lock, Sell, Unequip, Upgrade) are 22 px icons with 10 px labels floating mid-panel, leaving 40% of the panel empty. | The weapon is the hero of the preview: big, slowly rotating, on a rarity-lit pedestal. The owner shows as a portrait chip ("Equipped by Aaron"). The actions become a row of M-size labelled buttons pinned to the panel bottom, with Upgrade as `Primary`. The freed space shows `DeltaStat` against the target hero's current weapon ("+1.2M DPS"). |
| Artifacts | Search placeholder is centred. The sort button reads just "BEST", which looks like a duplicate of Squad Optimal. | Left-aligned `SearchBox` with a clear button. Sort becomes "Sort: Best ▾". Squad Optimal turns `Confirm` (green) and carries the preview gain ("+4.28M") as a tooltip or subtitle. Its label text is currently grey, which looks disabled. |
| Artifacts | ~~All 44 tiles mount live `ViewportFrame`s.~~ **Correction:** all 44 tile *buttons* exist, but `InventoryGrid` already mounts 3D previews only for the visible rows ±1 (`ShowPreview`). | No change needed. |
| Upgrade | The stage floats in a black void: the material slot sits top-left, the target is centre-left and the numbers are on the right. There's no Back button (only the X or the Artifacts tab). "★ · KEPT" is cryptic. "Review Upgrade" looks enabled with nothing chosen (B9). | A three-zone layout: **TARGET · KEPT** card (left) → arrow with the cost → **RESULT** card (right, the new star count glowing), with a **MATERIALS · CONSUMED** strip of N labelled slots below. Add a Back button in the header. Review is `Primary` and Disabled with the reason "Choose 1 more material". The cost chips show balance after the upgrade, and drop "0 Gems" when it's zero. |
| Material picker | The grid has broken spacing (about 60 px column gaps, 6 px rows) and two-thirds of the panel is empty black. Padlocked tiles don't say why. "Back" is a plain text button. | Use the same `InventoryGrid` as the main view with "eligible first" sorting. Locked or equipped tiles get a tooltip with the reason ("Equipped by Ignis: unequip first"). Header says "Choose 1 material · it will be destroyed", with the standard close. |
| Sell | Two exits ("Done" bottom-left, "Exit Delete Mode" in the panel). The commit button reads "Select Items". The breakdown is about 11 px. "Delete / Sell" naming is mixed. Four buttons are all named `Action` (B10). | One exit (Back in the header). The commit becomes `Danger` "Sell 6 · +1,240 Gold", Disabled until something is selected. The breakdown becomes rarity-coloured chips at 13 px. Call it "Sell" everywhere. Give every button a unique name. |
| Summon | **B2** blocks 10x at 44/100. The banner has a red pill blob behind the centre weapon, and side weapons render as black silhouettes. Both summon buttons are violet or slate, with no best-value cue. "Room for 6 more…" and "Rare+ guaranteed in 4" are small grey text on the right. | Fix B2. The carousel gets a rarity ring glow and lit side weapons. 10x gets a "BEST VALUE · Rare+ guaranteed" ribbon. Pity becomes two inline-labelled bars. The capacity warning becomes a `Callout` that only shows when it actually blocks. |

**Confirms (from §6):** sell Rare–Superior is Hard; sell Exalted+ or any ★2+ is Critical (hold); Upgrade with Rare+ donors is Hard, showing donor tiles; Summon 10x is Soft on first use per session.

### 5.2a Backpack (`Hud/BackpackPanel.luau`)
The rail's Backpack now opens a separate list window (Artifacts 44/100, Heroes 7/100, Materials). It has its own plain header, a small "×", text-only rows with tiny model thumbnails, and an empty "Select an item to inspect it." panel.
- Put it on the standard `Window` with a royal-gold header. Tabs become the `TabRail`, with capacity bars inside the tab labels.
- Reuse the Forge `Tile` grid for artifacts and the hero `Tile` for heroes, so the same item looks the same in every screen.
- The detail panel reuses the Forge detail component. Add a "Manage in Forge" `Travel` button rather than duplicating equip, upgrade and sell actions here.
- Empty detail state: `EmptyState` with a hint, not a blank panel.

### 5.3 Blacksmith summon (`ForgeController` summon view)
- Fix B2. It is merged into the Forge window as the Summon tab (§5.2).
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
- Resolve B6 with **explicit Apply** (decision 4): remove "Changes apply instantly". Changing any option shows an amber "Unsaved changes" `Callout` and lights up Apply as `Primary`. Apply shows a "Settings applied" toast. Closing with unapplied changes opens a Soft confirm ("Discard changes?").
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
- Loot stolen, squad down and boss banners: one `Banner` component (`HudCard` Grimoire, accent bar, icon) with consistent slide-in and out.

### 5.13 World UI (`Rendering/EntityRenderer.client.luau`)
- Hero nameplates overlap heavily at mid-range (five large plates in a row). Scale them by distance and shrink to name plus HP beyond 40 studs. Show your own squad's plates fully only when you hover or target them. Turn `AlwaysOnTop` off for non-duel heroes.
- Hide all nameplates while a modal is open (WindowManager focus mode).

### 5.14 Facility labels in the world (plots and Hub)
Every facility building gets a floating label above it (`BillboardGui` on the building's roof attachment, client-built per plot in `Rendering/`). That covers the Blacksmith Forge, Guard Post, Market, Training Grounds, God's Blessing, Summoning, the Pit (Synthesis/Promotion), Fortress Tree/Upgrades and Storage.
- **Content:** a drawn facility icon and the name in Grimoire title type (white→gold, ink outline), and under it one live status line in 13–14 px body type. Examples: "Lv.3 · 2/4 workers · +18% loot" (Market), "Lv.2 · +12% squad ATK" (Training), "+1.2K Gold/min" (Guard Post), "44/100 weapons" (Forge).
- **States:** a gold "!" badge when something needs attention (free worker slot, upgrade affordable, gold to collect). Locked buildings show a lock and "Unlock in Upgrades". The label of the building you're standing at grows slightly and shows its key prompt.
- **Readability:** scale by distance and fade between about 60 and 120 studs. Only your own plot's labels show full status; other players' plots show the name only. `AlwaysOnTop` off, so buildings occlude them. Labels are hidden while a modal is open, and status is updated on change only, not per frame.
- **Data:** read from the replicated profile (facility levels, assigned workers, bonuses via `StatFormulas`). There are no new remotes, and it's purely visual.
- Lands in Phase 6 with the other world UI, or earlier as its own small PR.

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
| **0. Hotfixes** | B2 first, then B4, B5, B6, B7, B8, B9, B10; a clean-session check for B3 (B1 already fixed) | S |
| **1. Kit foundation** | `Kit/` tokens re-export, `Button`, `CurrencyChip`, `Bar`, `DeltaStat`, `Callout`, `Tooltip`, `Notify`, `ConfirmDialog`, motion presets. Spec tests for pure logic (tooltip placement/flip, toast coalescing, confirm-tier selection from the §6 table). | L · **Built 2026-11-09:** `UI/Kit` (see `GILDED_GRIMOIRE.md` §The UI kit), `Shared/Util/UiKitRules` with 12 spec tests, server and client toasts routed to `Notify`. Checked in a Studio playtest. No screen uses the other pieces yet; adoption starts in Phase 3. |
| **2. WindowManager** | Registry, scrim/blur, HUD focus mode, Esc/B, open/close transitions, `_G` shims; B3 investigation | M · **Built 2026-11-09:** `UI/WindowManager` (registry of 12 windows in `HUDController` plus the offline-reward popup; `_G.OpenMasterModal` / `_G.IsAnyMasterModalOpen` route through it). Backspace / B go to the topmost window through an `InputContext` at priority 1000. Settings, Promotion and Forge step back first; the Tower selector keeps its own handler. Windows with a `UIScale` shrink out on close. The HUD currency bar stays over a window only when it has none of its own. The confirm dialog sinks Backspace / B at priority 5000. **B3 closed:** in a clean session the only duplicate is the two hero drawers, which Synthesis and the legacy Forge build on purpose. In Studio, B closed the Index; the picker-then-window layering is not yet verified. **Keys (2026-11-09):** Esc never reaches the game (Roblox opens its menu), so every back binding uses Backspace, ignored while a text box has focus, plus gamepad B. Playtested: one window at a time, close animation, HUD currency, focus mode and the welcome-back popup all pass. |
| **3. Pit + Forge** | Synthesis, picker, Promotion, Forge Workbench, Blacksmith summon onto `Window` + Kit; the §6 confirms | L · Split in two. **3a built 2026-11-09:** all §6 confirmations except Leave Raid (Forge sell Hard/Critical, Synthesis rare donors Hard and EXP overflow Soft, 10x summons Soft once per session for Forge and heroes, Upgrades nodes ≥25% of Gold, Visit Floor under-powered, moving a hero off another facility job); Synthesis empty state with a primary Select Hero, gold primary Confirm, gold EXP bar with ghost preview, footer callout, refusals as toasts; hero picker cards fully clickable (no per-card SELECT buttons); Promotion gold/slate button state and status callout. Compiles; not yet playtested. **3b built 2026-11-09:** one Forge window. The Summon tab hosts the legacy summon view inside the Workbench body (`Forge:HostSummon`), the tabs sit in the header beside an ember domain bar, and the floating tab bar is gone. Tiles get a rarity fill and border; the owner is a portrait badge, rarity and stars sit in a top band off the art, and power is 15 px. The detail panel always previews the weapon and uses labelled 2×2 action buttons (Upgrade primary, Sell red, disabled reasons on hover). The upgrade stage gets a Back button. Sell mode has one exit, "Pick weapons to sell", and "Sell" naming. No Forge text is smaller than 13 px. Compiles; not yet playtested. |
| **4. Tower + Fortress + Index + Store** | §5.6–5.9 | M · **Built 2026-11-09 (partial):** Tower refusals as toasts (plus the Phase 3 under-powered confirm); Upgrades gets a red X top-right instead of the bottom Close bar, a dimmed world (scrim 0.4) and build results as toasts; Index grid centred; Store LIMITED pill gold/white and Coming Soon with a lock, muted text and no hover. **Left:** Tower roster tooltips, locked-floor tooltips, Index silhouettes for missing heroes, Store discount ribbon and header layout. |
| **5. HUD pass** | §5.1, leaderboard, rail badges, legacy HUD removal | M · **Built 2026-11-09 (partial):** fully gothic HUD: the `GildedGrimoire.Glass` tokens now draw plum cards with an ink outline (and a gold rail on imperative banners) in Cinzel, restyling power and event cards, the leaderboard, currency, banners and popups at once; rail key chips sit on their icon; leaderboard text 14 px; Backpack rail badge "!" at 90% capacity (Upgrades and Index badges already existed). **Left:** removing the hidden legacy HUD, the event-timer ring, currency income tooltip. |
| **6. Settings, Squad, Facility, popups, world UI** | §5.10–5.13 | M · **Built 2026-11-09 (partial):** facility labels above every building (§5.14; `Rendering/FacilityLabelController`) with your plot's live status; hero and mob nameplates hidden while a window is open; Leave Raid uses the confirm dialog. **Left:** Settings window restyle, Squad and Facility windows onto the kit, nameplate distance scaling, Gotham sweep in Duel and Offline popups. |
| **7. Polish** | Stagger/tab motion everywhere, sound pass (`UIAssets` slots), Reduce Motion audit, gamepad navigation audit | S · **Built 2026-11-09 (partial):** hero picker cards stagger in (Reduce Motion respected through `Kit.Motion`). **Left:** stagger and tab motion on other grids, sound pass, gamepad navigation audit. |

Verification for each phase: `pwsh tests/run.ps1` (compile plus specs), then a Studio MCP playtest that opens each touched window, captures it, tests Esc/B close and the confirm paths, and checks the duplicate-instance count.

---

## 10. Decisions

All four were answered on 2026-11-09 and are recorded at the top of this plan: fully gothic HUD, brighter Grimoire, the §6 table as written, and explicit Apply in Settings.
