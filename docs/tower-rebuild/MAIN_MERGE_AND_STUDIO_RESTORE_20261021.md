# Main merge and Studio tower restoration — 2026-10-21

Merged `origin/main` at `39d9461` into `codex/tower-rebuild-part-1`, retaining the isolated 50-floor tower, independent travel/assignment, floors 1 and 5 combat, and damage-number feedback. Animation/art polish remains deferred to its separate sprint.

## Recovery points and merge resolution

The complete pre-merge tower work is committed at `5c87a95`. Backup branch `codex/tower-before-main-20261021` points to that checkpoint. Main supplies the forge, promotion, squad UI, and associated profile/building updates.

Conflicts were limited to `tests/run.ps1` and `tests/roblox-module-shim.luau`. The resolution retains the accurate Color3 shim and runs all five suites, including both main's forge coverage and the tower suites. Main's removal of the legacy Pit prompt and the tower's respawn integration coexist in PlotManager.

## Studio restoration

The connected place was `Infinite Towers: Become a Master!`, place ID `136256010643848`. Fifteen tower sources were already intact. Six had reverted and were restored: CombatSimulation, EntityRenderer, TowerTraversalSetup, HeroNavigation, PlotManager, and RelicService. Existing unrelated scripts and authored map assets were left in place.

The pre-restoration sources are preserved in [the source backup](evidence/STUDIO_RESTORE_BEFORE_20261021.json). Native clones of the six changed scripts are also retained under `ServerStorage.TowerRestoreBeforeMain_20261021`, with original paths recorded as attributes and cloned scripts disabled.

The first native run exposed a startup wait for the retired `ArenaRings.Ring3_CenterBossAltar`. CombatSimulation now binds its optional legacy lure prompt without waiting for absent geometry. This is the only combat source change relative to the tower checkpoint; the remainder of the tower implementation is preserved. The [initial blocked run](evidence/STUDIO_RESTORE_INITIAL_BLOCKER_20261021.json) is retained for traceability.

## Verification

- [CLI checks](evidence/MAIN_MERGE_TEST_OUTPUT_20261021.txt): production compilation and 101 passing assertions — 52 Pit, 6 Forge, 9 tower foundation, 12 transport, and 22 combat.
- [Native combat/feedback run](evidence/STUDIO_RESTORE_NATIVE_COMBAT_20261021.json): 11 passing checks covering default enablement, eight enemies across floors 1 and 5, unattended squad combat, retained hero/boss state, prototype rendering, feedback validation/styles/cap/expiry/cleanup, actual damage numbers, and actual Overdrive numbers (`-39` and gold `-46`).
- [Native travel run](evidence/STUDIO_RESTORE_NATIVE_TRAVEL_20261021.json): six passing real-client checks covering hub → 1 → 5 → 50, 49/50 adjacency, hub return, independent assignment, recall cooldown, invalid/stale rejection, and rig cleanup. The initial harness started after 1.1 seconds and encountered an expected stale-revision rejection during startup; [that result](evidence/STUDIO_RESTORE_TRAVEL_INITIAL_20261021.json) is retained. The successful harness allowed four seconds for initial profile/character setup and ran the same six assertions without request retries or weaker revision checks.
- [Final source comparison](evidence/STUDIO_RESTORE_SOURCE_COMPARISON_20261021.json): all 21 mapped tower scripts exactly match the repository; production scripts are enabled. Studio is back in Edit mode, with temporary test scripts removed and no combat preview override left behind.
- `git diff --check` passes. Native multiplayer, physical-device certification, and published-place release checks were not repeated in this merge task.

The restoration is applied to the open Studio place. No Roblox publishing or Git push was performed.
