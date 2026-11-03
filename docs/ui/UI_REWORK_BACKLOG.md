# UI: To Be Reworked

Screens and HUD pieces that still need a rework pass. Move an item to **Done** with its date when it lands, and update the screen's design doc in the same change.

## Open

### Assets for the feel layer
The code is wired; the art and audio are not uploaded. Fill the slots in `UI/UIAssets.luau` from `docs/ui/UI_ASSET_REQUESTS.md`. Until then the UI is silent (apart from the click) and uses drawn fallbacks.

### Window close transitions
Windows pop in through `ModalFit`, but still vanish instantly on close. Each controller's `Close` would need to wait for a shrink tween first.

## Done

### UI feel layer and reveal polish (2026-11-03)
Hover and press springs, click sounds and haptics on every button, window open pops, refusal shakes, animated toasts, the offline reward count-up, and a richer per-pull reveal (tease, card flip, star pops, NEW badge, jackpot effects, AGAIN buttons). The Forge artifact banner uses the same reveal now. See `PHASE_5_REACT_UI_AND_MENUS.md`, Slice 2.

### Summon Heroes (2026-11-03)
The banner card shows the featured hero, a per-tier roster with drop rates and a pity bar. Each pull now plays its own reveal (rift orb, rarity flash, card flip; rarer pulls get rays and more pulses), with SKIP and a 10x results grid (`UI/SummonReveal.luau`). Unaffordable or refused summons say why. See `PHASE_5_REACT_UI_AND_MENUS.md`, Slice 2.

### Squad UI (2026-11-03)
Down to 900 × 560, with a Hero Details panel: stats overview, the equipped weapon, level and EXP, assignment, stamina and trait. Slot cards show the weapon too.

### Synthesis (2026-11-03)
Two columns: a big recipient card with SELECT / CHANGE HERO on the left, the material heroes on the right.

### Squad Status HUD (2026-11-03)
It is now a pull-up drawer (`Components.SquadDrawer`, `PHASE_5_REACT_UI_AND_MENUS.md` §2.2a). Collapsed, it is a compact portrait strip with a hover or tap tooltip. Expanding turns the strip into the detailed card and collapsing turns it back, so only one squad view is ever on screen.

### HUD overlaps on short screens (2026-11-03)
- When the Left or Right Rail can't fit even 44 px buttons in one column, it wraps into extra columns instead of running into the cards below it.
- With the drawer expanded, the detailed card, the Gold/Gems bar and the Left Rail no longer overlap.
