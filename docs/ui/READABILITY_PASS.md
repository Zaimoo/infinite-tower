# UI readability implementation

## Window audit

All screen UI receives ExtraBold or heavier text, preserving the existing font family, with 1.8–3 px contextual outlines. Existing text outlines are reused; button borders are preserved. Outlines follow text fades, and dark text on bright buttons uses a light outline. World billboards are outside this pass.

| Window / surface | Copy and sizing decision |
| --- | --- |
| Settings (Overview, Audio, Graphics) | Removed the implementation-focused information card, including references to controls the window does not expose. Shortened preset, audio and graphics explanations. Added safe-area fitting and up to 1.2× scaling. |
| Tower travel | Shortened subtitle, increased detail and status text sizes, and allowed up to 1.25× scale. Kept power requirements, enemies, occupancy and travel feedback. |
| Forge inventory / equip / upgrade / sell | Shortened introductory copy; allowed 1.2× workbench scaling. Kept material requirements, protected-item explanations, sale review and undo. |
| Legacy forge / artifact catalog | Forge permits 1.2× scaling. Catalog odds and weapon information retained. Shared typography covers both. |
| Summoning facility | Permits 1.25× scaling; costs and odds retained. |
| Promotion / hero picker | Shortened action to “Promote” and selection instructions. Permits 1.25× scaling while keeping wide/stacked layout choice. Requirements and success rate retained. |
| Synthesis / material picker | Shortened recipient prompts. Existing 1.25× scale retained; consumption warnings retained. |
| Squad / hero details / selection drawer | Existing squad 1.35× fit retained. Stats, equipment and selection guidance retained. Shared typography strengthened. |
| Guard Post / Market / Training / God's Blessing | Shortened empty slot prompt to “Assign hero”. Existing fluid window retained; bonuses, assignment state and requirements retained. |
| Store | Existing fluid window retained. Prices, product contents and availability retained. Shared typography strengthened. |
| Hero / artifact Index | Removed the repeated hero totals on banner cards and let the class and weapon line wrap. Drop rates, stats, recipes and lore remain available. |
| Backpack | Removed the duplicate header capacity counts. Tabs show the counts and flag near or full inventory. The full-inventory warning, item status and descriptions remain visible. Shared typography strengthened. |
| Fortress upgrades | Existing interactive map zoom retained. Node effects and costs retained. Shared typography strengthened. |
| Offline earnings | Shortened title, subtitle and income breakdown. “Claim & Continue” becomes “Continue” because gold is already credited. Existing large window retained. |
| Duel / tower event / reward reveal | Kept time, scores, effects, reward names and skip controls. Existing sizing retained. Shared typography strengthened. |
| Leaderboard / playtime admin / HUD / tooltips | Functional labels retained; shared typography strengthened. No enlargement of peripheral overlays. |

## Verification

- Rojo live sync confirmed the new module and Settings changes in Studio.
- Rojo build succeeds; whitespace diff check passes.
- Studio audit: all 743 mounted ScreenGui text objects had ExtraBold-or-heavier fonts and contextual outlines.
- Inspected Settings, Tower and Promotion previews; offline earnings also inspected before changes. Opened the Store, Backpack and Index from the HUD. Confirmed the HUD returns after closing the Store and the Index opens next. Other windows were reviewed in source.
- Settings geometry assertions passed for 390×844, 844×390, 1280×720 and 1920×1080. This verifies bounds, not touch usability or device-emulator visuals.
- Isolated Studio check verified newly added text, subsequent font changes, outline fade synchronization and cleanup. The first integrated probe incorrectly assumed a particular stroke name; existing theme strokes can be reused.
- Studio reported pre-existing font/asset load and leaderboard path warnings. Verification covered viewing and closing windows.

Small phone screens still shrink fixed-canvas windows; a dedicated mobile reflow is separate from this typography and desktop scale pass.
