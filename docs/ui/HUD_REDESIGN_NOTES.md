# HUD "Clear Glass" pass: before / after

Brief: `docs/ui/HUD_REDESIGN_PROMPT.md`. Style reference: `docs/ui/GILDED_GRIMOIRE.md` (Clear Glass section) and `docs/rework-plan/PHASE_5_REACT_UI_AND_MENUS.md` §2.0b, §2.2a and §2.4.

## Not changed

- **Left and Right Rail buttons** keep the Gilded Grimoire look, by request. `LeftRail` and `RightRail` keep their names. The Right Rail now starts below the leaderboard (see below).
- Every `_G` entry point, the ScreenGui names and DisplayOrders (`Phase5Hud` 1, `MasterHUDScreenGui` 5, `CustomLeaderboardGui` 8, `Phase5Overlay` 10, `DuelScreenGui`, `OfflineRewardScreenGui`), the banner names in §1B, the whistle inputs (Q/E in `MasterController`, L1/R1 in `Phase5HudController`).
- No remotes or server code changed.

## Changed names or positions

| Element | Before | After |
| :--- | :--- | :--- |
| Squad Status Card | Always-expanded card, bottom-left (`Status` key) | Inside the pull-up **Squad drawer** (`Status` → `Components.SquadDrawer`). Collapsed by default to a 56 px portrait strip that turns into the full card (never both) on the chevron, `C` or gamepad `Y`, or automatically on danger. |
| Gold / Gems bar | Its own `Currency` key, positioned above the card | A child of the drawer (`Above`), riding its top edge. The `Currency` key is gone. |
| Left Rail | Stopped above the expanded card; overflowed on short screens | Stops above the drawer's current height, and wraps into extra columns when 44 px buttons don't fit (both rails). |
| Leaderboard | Imperative `LeaderboardModal` (with `CloseButton`, `Header`, `PlayerScrollList`, `Row_<UserId>`) at the very top-right, over the Next Goal card | `LeaderboardPanel`, drawn by HudApp into `CustomLeaderboardGui`, stacked **under** the Next Goal card. The old child names are gone (nothing in `src/` or `tests/` looked them up). Collapsed to a pill while the goal card shows. |
| Right Rail top | Goal card bottom + 16 px | Leaderboard bottom + 16 px |
| `Tab` | `UserInputService.InputBegan` in `LeaderboardController` | `ContextActionService` action `HudLeaderboard` in HudApp (passes while a modal is open) |
| New action | — | `HudSquadDrawer` (`C`, `ButtonY`; `Y` passes while a ProximityPrompt is showing) |
| §1B banners, duel banner, offline-reward popup | Gilded Grimoire framing (`GrimoireCorner`, `GrimoireFill`, `GrimoireInk`, `GrimoireRail`) | Clear Glass framing (`GlassCorner`, `GlassStroke`, optional `GlassAccent`). Names, positions and logic unchanged. |
| Floor / boss bar fill | Purple kill bar, amber when complete, pink boss HP | `Arcane` kill bar, `Royal` when complete, `Danger` boss HP |
| `Store` | `Profile`, `Goal`, `Revision` | Adds `DrawerExpanded`, `Players`, `LeaderboardOpen`, `SetPlayers` |

## Still to verify in Studio

The §5 matrix (1920×1080, 1366×768, 1024×600, 375×812, console; hub, plot, tower floor, boss, duel; 1, 3 and 5 open slots) has not been captured yet.
