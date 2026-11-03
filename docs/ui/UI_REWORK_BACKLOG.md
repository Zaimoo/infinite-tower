# UI: To Be Reworked

Screens and HUD pieces that still need a rework pass. Move an item to **Done** with its date when it lands, and update the screen's design doc in the same change.

## Open

### Summon Heroes
Better UI, a reveal animation per pull instead of a simple alert, and general Roblox UI polish.

### Squad UI
The Squad screen has no stats overview, doesn't show the equipped weapon, and is missing other relevant hero details.

### Synthesis
Make it two columns:
- **Left:** a big card for the selected hero, with a way to select or change that hero.
- **Right:** the heroes to synthesize with.

## Done

### Squad Status HUD (2026-11-03)
It is now a pull-up drawer (`Components.SquadDrawer`, `PHASE_5_REACT_UI_AND_MENUS.md` §2.2a). Collapsed, it is a compact portrait strip with a hover or tap tooltip. Expanding turns the strip into the detailed card and collapsing turns it back, so only one squad view is ever on screen.

### HUD overlaps on short screens (2026-11-03)
- When the Left or Right Rail can't fit even 44 px buttons in one column, it wraps into extra columns instead of running into the cards below it.
- With the drawer expanded, the detailed card, the Gold/Gems bar and the Left Rail no longer overlap.
