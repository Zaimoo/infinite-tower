# Part 5 of 5: Integration, performance, migration, and release verification

Implementation status: **DEFERRED by user request on 2026-10-21; implementation NOT STARTED.** The current milestone ends at Part 3. Preserve the acceptance matrix as future release work; it is not an active task or a claim that release checks have passed. Resume only after the user requests this part again and its prerequisites are verified.

Read [the master requirements](../TOWER_REBUILD_PLAN.md), [Part 4](PART_4_CONTENT_AND_UI.md), and its completed handoff. Review earlier protocol/asset handoffs when checking their behavior. Start only after the Part 4 gate is verified.

## Scope

1. Reconcile the final source and connected Studio state. Identify active script versions, stale generated geometry, old spawn paths/global boss behavior, asset availability, and protocol compatibility. Preserve a recoverable snapshot before targeted migration.
2. Complete the cosmetic-tower migration: retire old WalkableTower traversal and obsolete spawn dependencies, keep the intended exterior/hub/portals, and preserve island bridges, plots, facilities, and extraction pads. Verify initialization/restarts do not rebuild obsolete geometry or duplicate the new world.
3. Run production Luau compilation, existing Pit regressions, meaningful tower/catalog/transition checks, and multiplayer playtests. Use the actual available runner; read tests/run.ps1 instead of inventing a successful command or installing unrelated tooling.
4. Exercise all important lifecycle/failure paths: invalid/repeated travel, missing room readiness, death/respawn, recall, roster changes, coma/wipe/recovery, disconnect, packet delay/loss, stale generations, room sleeping, room retirement, and simultaneous boss kills.
5. Measure server tick work, replication traffic, instance/memory growth, client frame time, animation work, and effect counts with multiple active floors and a busy room. Compare against Part 3/4's recorded budgets and fix evidenced bottlenecks. Re-test fixes rather than fabricating benchmark numbers.
6. Verify published animation access where available, all art/animation mappings, death cleanup, and mobile/controller layout. Missing required external validation remains explicitly NOT VERIFIED.
7. Update README, TOWER_NAVIGATION, asset/source instructions, recovery procedure, and the final acceptance matrix. Explain what actually shipped, known limitations, and how to reproduce verification.

## Final acceptance matrix

Fill evidence with commands/output paths, Studio observations, or captured visual/playtest records. A checked box without evidence is not a pass. Use PASS, FAIL, or NOT VERIFIED.

| ID | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| T01 | 50 floors, ten five-floor biome groups, all unlocked immediately | NOT VERIFIED | None |
| T02 | Cosmetic central tower and every usable entrance portal work | NOT VERIFIED | None |
| T03 | 50 distinct room environments are isolated from hub/neighbors | NOT VERIFIED | None |
| T04 | Previous/Next/Selector/Hub navigation and 1/50 boundaries work | NOT VERIFIED | None |
| T05 | Shared same-server rooms and accurate squad owners/counts/presence | NOT VERIFIED | None |
| T06 | Player location and squad assignment follow the documented rules | NOT VERIFIED | None |
| T07 | Floor-local aggro, damage, AoEs, retaliation, pickup, and participation | NOT VERIFIED | None |
| T08 | All enemy designs meet the rig/model/animation quality standard | NOT VERIFIED | None |
| T09 | Ten correct biome bosses with distinct animated signature attacks | NOT VERIFIED | None |
| T10 | Synchronized attack timing, cancellation, and singular damage/rewards | NOT VERIFIED | None |
| T11 | HP/stamina/cargo preserved; no coordinate-based banking/recovery | NOT VERIFIED | None |
| T12 | Loot/relic extraction and existing recovery/progression rules work | NOT VERIFIED | None |
| T13 | Death, wipe, respawn, roster changes, and disconnect clean up correctly | NOT VERIFIED | None |
| T14 | Room-local replication, late packets, and >255-entity cases work | NOT VERIFIED | None |
| T15 | Room sleep/retirement preserves live loot and authoritative rewards | NOT VERIFIED | None |
| T16 | Mouse/touch/controller UI and performance meet recorded targets | NOT VERIFIED | None |
| T17 | Production compilation, Pit regressions, and relevant tower checks pass | NOT VERIFIED | None |
| T18 | Source/Studio sync, restart/idempotent migration, and recovery documented | NOT VERIFIED | None |

## Scope boundary

Fix defects needed to meet the existing requirements. Do not add unrelated features, offline simulation, multiple independent squads, or cross-server presence during release verification. Do not publish the game merely because this verification part exists; use the user's actual authorization for any publishing step.

## Verification gate and handoff

- Status: DEFERRED; implementation NOT STARTED.
- Actual changed files and final source/Studio comparison: none.
- Recovery snapshot/location and migration result: not recorded.
- Executed compilation/regression/playtest commands and results: none.
- Acceptance matrix with evidence: not completed.
- Performance measurements and tested environment: none.
- Unavailable checks, unresolved defects, and external blockers: not assessed during implementation.
- Release result: NOT VERIFIED. Report incomplete work honestly; the plan alone is not implementation evidence.

## Future execution prompt (use only after resumption is requested)

Implement only Part 5 of the tower rebuild using the verified Part 4 handoff. Complete targeted legacy migration, integration fixes, source/Studio synchronization, and documented regression/multiplayer/mobile/performance checks. Fill the acceptance matrix with actual evidence, preserve a recovery path, and report any unverified checks. Do not claim the rebuild finished unless its required gates have passed.
