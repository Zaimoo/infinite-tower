# Tower rework implementation — October 24, 2026

Implemented on `codex/tower-rework`, starting from `main` after checkpoint PR #35.

## Runtime behavior

- Canonical order: Verdant Ruins, Fungal Hollow, Ashen Dunes, Frozen Citadel, Infernal Foundry, Thunder Highlands, Corrupted Grove, Sunken Sanctuary, Astral Archives, Abyssal Throne.
- The five variants grow from 380 × 420 × 130 to 560 × 640 × 190 studs (width × depth × height). Room origins are separated by 2,400 studs.
- `TowerLayout` defines the sanctuary, basin, galleries, crossing, bastions and apex, plus their shared traversal graph. Its heights are walkable top surfaces. Ramps are at most 15 degrees, the central staircase rises at most one stud per tread, and the recessed channels have return ramps.
- The same layout generates 3/4/5/6/7 camps and 11/15/19/24/29 enemies. Encounter manifests are counted from these placements, avoiding a second population formula. Elite counts are 1/1/2/3/2, with one boss and two elite lieutenants on the fifth floor.
- `TowerBiomeAssets` supplies distinct procedural landmark kits for all ten biomes. Decorations cannot block movement or contaminate ground probes. These are stylized native-part interpretations of the reference art, with local lights and no uploaded asset dependencies.
- All floor arrival sanctuaries allow cargo banking and wipe recovery eligibility. Pickup arms banking; returning to the sanctuary unpacks cargo and restores carry movement. Gold retains the Market multiplier.
- Floor relic extraction grants 100% of the configured payout, retains the Market bonus, broadcasts `EXTRACT_SAFE_ZONE`, and clears the authoritative identity before awarding. Hub owner-pad extraction remains available and broadcasts `EXTRACT_PRIVATE`.
- Banking requires matching floor and room generation, an armed carrier, an unexpired item, an authorized safe zone, and no pending transition. Missing profiles retain the carried loot.

## Verification

`tests/run.ps1` compiles production scripts and executes Pit, Forge, tower foundation, transport, combat, and rework suites. `tests/run-afk-tests.ps1` verifies compatibility with the current facility rules.

Studio verification in place **136256010643848**:

- Built all 50 rooms and raycast-verified all 980 enemy spawn positions, sanctuary arrival points, and extraction fixtures.
- Walked every traversal connection in both directions across all five geometry variants: **78 routes passed** using the actual lightweight `HeroNavigation` implementation.
- Exercised the actual server pickup/banking paths on all 50 floors: **50 Gold banks, 50 Gem banks, 50 full relic extractions, 50 duplicate-payout checks**, and all **980 runtime mob placements** passed. Unsafe field extraction was rejected on every floor. The test restores the player's currencies, location, anchor state, and passive-income configuration.
- Verified Hub owner-pad extraction and rejection on another player's pad. The normal travel request/client-readiness flow successfully transferred the player and squad to Floors 1, 5, and 50 and back to the Hub.

Reusable Studio probes are in `tests/studio-tower-rework.luau` (Edit-mode module) and `tests/studio-tower-extraction.server.luau` (temporary server Script in Play mode). The latter uses real game services and must run as a server Script, since plugin execution has a separate `_G` environment.

Edit-time room previews live under `Workspace.TowerReworkPreviews`. `TowerFloorService.Init` removes previews during Studio Play and builds authoritative rooms lazily. Original Studio sources were retained in `ServerStorage.TowerReworkBackup_20261024` before syncing the repository.

Published-place certification, mobile performance, multiplayer load, and final visual polish remain separate release checks. This session updates Studio's editable place; it does not publish the game.
