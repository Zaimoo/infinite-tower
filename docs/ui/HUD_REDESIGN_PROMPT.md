# Prompt: HUD Redesign ("Clear Glass" pass)

Paste everything below the line into a new session. Attach the reference screenshots (the translucent RPG menus with Stash/Equipments/Quests tabs) and a fresh screenshot of the live HUD in the hub **and** on a tower floor.

---

Act as a Senior UI/UX Designer and Roblox front-end engineer on **Infinite Tower: Become a Master!** Redesign the on-screen HUD so it matches the clean, translucent RPG layout in the attached reference shots. Use our dark gothic anime palette, and show only features that already exist in our game.

Before writing code, read:
- `docs/rework-plan/PHASE_5_REACT_UI_AND_MENUS.md` §2 (the Seven Fixed Zones contract) and `docs/rework-plan/PHASE_6_TOWER_UX.md` §3 (tower additions to those zones).
- `docs/ui/GILDED_GRIMOIRE.md` (the current theme, which this pass partly replaces).
- `src/StarterPlayerScripts/UI/Hud/` (`HudApp`, `Components`, `Theme`, `Icons`, `Whistles`, `Store`), plus `Phase5HudController.client.luau`.
- Use the `roblox-ui` skill, and the `roblox-input` skill for keybind and gamepad work.

## 0. What the reference is for (and what it is not)

Take only the reference's **structure**:
- Thin framed panels with corner brackets.
- A dark translucent body over the 3D world.
- A coloured header strip with the title on the left and `X` on the right.
- Small uppercase section labels with a hairline rule after them.
- Pill buttons with a subtle tint per category.
- A compact player list in the top right.
- Generous spacing.

Do **not** take its features: Stash, Equipments, Quests, Achievements, Profile, Race rerolls, loadouts, Dash/Sprint/Emote hints, the minimap and the compass. If a reference element has no equivalent in our game, leave it out.

## 1. Scope: the HUD inventory (redesign these, and add nothing)

The HUD is React-lua, mounted by `Phase5HudController` into two ScreenGuis: `Phase5Hud` (DisplayOrder 1, the zones) and `Phase5Overlay` (DisplayOrder 10, the portal for panels). Legacy pieces still live in `MasterHUDScreenGui` (DisplayOrder 5, `HUDController.client.luau`).

### 1A. Persistent zones (`Hud/HudApp.luau`)

| Zone | React key / component | Content today | Keep |
| --- | --- | --- | --- |
| Left Rail | `LeftRail` → `Components.RailButton` | Summon, Squad, Forge, Upgrades (Fortress Tree), Index, Settings | Unlock gating via `profile.Unlocks`. Badges: Squad = empty slots, Upgrades = buildable nodes, Index = new heroes |
| Right Rail | `RightRail` → `Components.RailButton` | Store, Overdrive `[Q]`, Recall `[E]`, Tower | Key chips, radial cooldown + seconds, disabled state from `Whistles.Blocked`, the Store wiggle, the Tower lock during boss lock |
| Squad Status | `Status` → `Components.SquadStatusCard` | One tile per **open** slot (1–5, from `FortressTree.SquadSlots`), plus one locked-range tile | Portrait framed in rarity colour, name, rarity, stars, level, archetype icon, HP bar (stamina label when off-floor), skill gauge (glows at 100), state chip (Fighting / Idle / Moving / Recalled / Down + countdown / Dueling / Resting / Farming), `+ Assign` |
| Currency | `Currency` → `Components.CurrencyBar` | Gold and Gems chips above the status card | Tick-up and `+150` delta floaters. Phase 6 adds the **At Risk** chip |
| Squad Power | `Power` → `Components.SquadPowerBadge` | `⚔ 12,480 SQUAD POWER` with a per-hero breakdown tooltip | Green/red delta floater. Phase 6: `% READY`, next wall, Attuned marker |
| Next Goal | `Goal` → `Components.NextGoalCard` | Onboarding step card, top right. Hidden once the chain is complete | Flash on a new goal |

Note: the original brief said "4 hero slots". The squad has up to **5** slots (slot 1 plus 4 from the Fortress Tree). Design for 1–5 open slots and the locked tile.

### 1B. Top-center and transient HUD (`HUDController.client.luau`, `MasterHUDScreenGui`)

These share the screen with the zones, so they must use the same visual language:
- `FloorBossTopBanner`: the floor kill bar, which morphs into the boss HP bar.
- `ToastBanner`
- `LootStolenBanner`
- `SquadWipeRecoveryBanner`
- `PartiallyDefeatedSquadBanner` (squad compromised)
- `SquadVitalityTooltip`
- `CarriedLootPill`
- `DuelBanner` (`DuelScreenGui`)
- The offline-reward popup (`OfflineRewardScreenGui`)

Restyle them with the new tokens. Do not move their logic.

### 1C. Top-right leaderboard (`LeaderboardController.client.luau`, `CustomLeaderboardGui`)

Today this is a replica of the CoreGui PlayerList with columns People / Floor / Power.

Redesign it as the reference's compact panel: header `PLAYERS 6/6`, then rows with avatar, display name, `@username` and `F{floor} · {power}`. Highlight the local player's row. The panel collapses to a single header pill (`Tab` toggles it).

It must **stack under** the Next Goal card. It must never overlap the card or the Right Rail. When the goal card is visible, the leaderboard starts collapsed.

### 1D. Out of scope here (separate tasks, do not touch)

- Full screens: Summon, Squad modal, Forge, Synthesis/Promotion (the Pit), Fortress Tree, Facility panel, Hero Index, Shop, Settings and the Tower selector.
- These will get the same tokens later. For now, only make sure the shared header and button tokens you add can be reused there.

## 2. Visual system: "Clear Glass" (overrides Gilded Grimoire for HUD zones only)

### 2.1 Tokens

Add these to `Hud/Theme.luau` as `Theme.Glass`. Keep the existing `Theme.Colors` keys so other screens don't break.

| Token | Value | Use |
| --- | --- | --- |
| `Base` | `#0D0912` | Panel body, BackgroundTransparency **0.35–0.45** for rails and cards |
| `BaseRaised` | `#261C32` | Header strip, tile background, transparency 0.25 |
| `Hairline` | `#F6F4FF` at transparency 0.82 | 1px `UIStroke` on every panel and tile |
| `Text` | `#F6F4FF` | Primary text |
| `TextMuted` | `#F6F4FF` at transparency 0.45 | Secondary labels and section headers |
| `Arcane` | `#C084FC` | Active, selected and focused state; skill gauge |
| `Royal` | `#FACC15` | Currency, primary call to action, a full gauge, the local-player row |
| `Danger` | `#EF4444` | Down, badges, boss HP, loot stolen |
| `Vital` | `#4ADE80` | HP, positive deltas |

Transparency rule: aim for **0.35–0.5**, not the 0.5–0.7 in the original brief. Light floors and the Archangel-white reference sky wash out text at 0.6 or more. A transparency of 0.7 is allowed only for empty or decorative backplates. Text and bars stay fully opaque. Verify that every text and bar reaches a WCAG contrast of 4.5:1 or better against both a bright hub sky and a dark tower floor.

### 2.2 Shapes and type

- **Panels:** `UICorner` 6 px (tiles 4 px). One 1px `UIStroke` with `ApplyStrokeMode = Border`. No gradients on bodies. At most one subtle top-to-bottom `UIGradient` (transparency 0 → 0.08) on header strips only.
- **Corner brackets:** four 10×10 L-shaped hairlines in `Hairline` at the outer corners of the Squad Status card and the leaderboard only. They replace the gold diamond studs. Build one `Components.Brackets` and reuse it.
- **Category tint:** each rail button keeps its existing `Accent` colour, but only as a 2px bottom underline and the icon tint. The button body stays neutral glass, like the reference's tab pills.
- **Remove from HUD zones:** thick ink outlines, the inset gold rail, top-lit gradients and diamond studs.
- **Type:** the reference is a condensed sans for UI chrome and a serif only for big names. Use:
  - `Enum.Font.Montserrat` / `FontFace` Montserrat SemiBold for labels.
  - Bold for numbers, with `TextScaled` off and explicit `TextSize`.
  - Cinzel for hero names and the Squad Power number only.
- **Section labels:** uppercase, `TextMuted`, letter-spaced, followed by a 1px hairline rule, like `RACE REROLLS ———`.
- **Icons:** keep the drawn `Hud/Icons` set (no emoji, per Gilded Grimoire). Flatten it: drop the thick black outline to 1px and drop the sheen.

### 2.3 Motion (TweenService, ≤ 180 ms, Quad Out)

- **Hover:** the stroke goes from `Hairline` to `Arcane` and the body transparency drops by 0.1. Replace the old 10% scale grow with 4% (rails only).
- **Press:** scale to 0.96 and back.
- **Badge pop:** scale 0 → 1.15 → 1 when the count rises.
- **Number tick-up:** keep the existing behaviour. Floaters rise 16 px and fade out over 0.8 s.
- **Reduced motion:** respect `GuiService.ReducedMotionEnabled` by skipping the scale and pop and keeping only the colour change.

## 3. Layout

Keep the Seven Fixed Zones contract and the existing no-overlap maths in `HudApp`: `railSize`, `currencyBottom`, `rightTop`/`rightBottom`, the compact switch at `screen.X < 700 or screen.Y < 480`, and the 44 px minimum touch target. Only change what is listed below.

1. **Squad Status becomes a pull-up drawer** (this is on the backlog):
   - **Collapsed (default in hub and plot):** one slim strip at the bottom left. Per slot it shows a 36 px portrait with a rarity-coloured 2px ring, a 3px HP line under the portrait, and a tiny state dot. On hover or tap it shows a compact tooltip: name, Lv, ★, HP %, state.
   - **Expanded:** the current full tiles slide up from the strip (200 ms). Toggle it with a chevron tab on the strip, a hotkey (suggest `Tab` is taken by the leaderboard, so use `C`), or gamepad `ButtonY`. The choice persists per session in `Store`.
   - **Auto-expand:** expand automatically when a squad member goes **Down** or a squad-compromised alert fires. Collapse 4 s after the danger clears, unless the player expanded the drawer manually.
   - **Currency:** the currency bar rides on top of whichever height the drawer currently has. Update `currencyBottom` and the Left Rail limit from the **current** drawer height so nothing overlaps mid-tween.
2. **Rails:**
   - Make the rail buttons square glass tiles with the label **below** the tile (12 px, `TextMuted`, white on hover), not overlapping its foot.
   - Show key chips (`Q`, `E`) as a small outlined square in the top-left. Swap to gamepad glyphs when `UserInputService.PreferredInput` is a gamepad, and hide them on touch.
   - The cooldown sweep is a dark radial fill with the seconds in `Text`.
3. **Top right:** Next Goal card first, then the collapsed leaderboard pill, then the Right Rail. Feed the leaderboard's height into `rightTop` the same way the goal card's is fed today.
4. **Phone (< 700 px wide):**
   - Labels are dropped before numbers.
   - The rails become icon-only.
   - The drawer is always collapsed unless tapped.
   - The leaderboard is a pill only.
   - Squad Power shows the number only.

## 4. Script compatibility (hard constraints)

The HUD is React, so there is no fixed GUI tree to preserve. The real contract is:

- **Global entry points.** These must keep working unchanged:
  - `_G.OpenMasterModal`, `_G.OpenFacilityHUD`, `_G.ToggleTower`, `_G.ToggleSettings`, `_G.OpenHeroIndex`, `_G.CloseHeroIndex`, `_G.IsHeroIndexOpen`, `_G.OpenRobuxShop`, `_G.OpenFacilityPanel`.
  - `_G.IsAnyMasterModalOpen`, `_G.IsTowerSelectorOpen`, `_G.IsFacilityPromptVisible`, `_G.TriggerHUDWhistleCooldown`, `_G.ClientCombatState`, `_G.CurrentProfile`.
- **ScreenGui names and DisplayOrders:**
  - `Phase5Hud` (1), `MasterHUDScreenGui` (5) and `Phase5Overlay` (10), with `CoreUISafeInsets` and `ResetOnSpawn = false`.
  - `CustomLeaderboardGui`, `DuelScreenGui`, `OfflineRewardScreenGui` and `SettingsUi`.
- **Named instances** that legacy code or tests look up: the banner names in §1B, plus `LeftRail`, `RightRail`, `ModalScrim` and `FloatingToolbar`. Grep `tests/studio-*` and `src/` for `FindFirstChild`/`WaitForChild` on any name before renaming it. If a rename is needed, keep the old name.
- **Inputs:**
  - Keep `Whistles.Fire` as the only path for Overdrive and Recall.
  - Keyboard Q/E stay in `MasterController` so they yield to ProximityPrompts.
  - Gamepad L1/R1 stay in `Phase5HudController`.
  - Any new toggle (drawer, leaderboard) uses `ContextActionService` and ignores `gameProcessedEvent` and open modals.
- **Client only.** No new remotes and no server changes. Everything reads `Store.Profile`, `Store.Goal`, `Whistles` and `_G.ClientCombatState`. Do not add per-frame work: the existing 5 Hz `setTick` loop is the refresh budget. The drawer and tooltip must not add a second loop.
- **Style:** match the surrounding style. Use `--!strict`, tabs, `React.createElement` as `e`, and tokens from `Theme`, never inline `Color3.fromRGB` in components.

## 5. Accessibility and platform checks

- Every interactive element is 44×44 px or larger, and is gamepad-selectable (`Selectable = true`, sensible `NextSelection*` between the rail columns and the drawer).
- Nothing depends on colour alone: Down has an icon and text, and rarity has stars as well as the ring colour.
- Text is at least 12 px at the 375 px phone width.
- Test it at 1920×1080, 1366×768, 1024×600 (the compact switch), 375×812 (phone) and on a console 10-foot view. Test each in the hub, on the plot, on a tower floor, during a boss, during a duel, and with 1, 3 and 5 open slots.

## 6. Deliverables

1. The `Theme.Glass` tokens, and the updated `Components` (`RailButton`, `SquadStatusCard` as a drawer, `CurrencyBar`, `SquadPowerBadge`, `NextGoalCard`, a new `Brackets`).
2. `LeaderboardController` restyled and stacked into the top-right zone.
3. The §1B banners restyled through the shared tokens (this can go through `GildedGrimoire.Reframe` with a new `Glass` tone, rather than per-banner edits).
4. Doc updates in the same change:
   - `PHASE_5_REACT_UI_AND_MENUS.md` §2.0/§2.0b/§2.2: the new style and the drawer.
   - `GILDED_GRIMOIRE.md`: HUD zones now use Clear Glass.
   - `docs/GAME_DESIGN.MD` §4.6, if HUD behaviour changes.
5. `pwsh tests/run.ps1` passes. Add a Studio playtest screenshot set covering the §5 matrix.
6. A short before/after note listing any element whose name or position changed.

Work in this order:
1. Tokens and a single restyled `RailButton`. Pause for a screenshot review.
2. The drawer.
3. Currency, Power and Goal.
4. The leaderboard.
5. The banners.
