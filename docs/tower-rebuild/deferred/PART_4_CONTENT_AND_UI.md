# Part 4 of 5: All 50 floors, full enemy roster, and complete UI

Implementation status: **DEFERRED by user request on 2026-10-21; implementation NOT STARTED.** The current milestone ends at Part 3. No Part 4 source changes landed. Resume only after the user explicitly requests this work again; passing Part 3 does not automatically start it.

Read [the master requirements](../TOWER_REBUILD_PLAN.md), [Part 3](../PART_3_COMBAT_AND_FEEDBACK.md), and its completed handoff. Start after the first-biome combat gate is verified. Final animation/art polish is tracked in its [separate sprint](ANIMATION_POLISH_SPRINT.md), not a Part 3 prerequisite.

## Scope

1. Expand in ten five-floor biome batches. Each floor gets its own layout/name, set dressing, encounter composition, valid navigation, safe landing, and travel controls. Share a coherent biome within each group; do not count identical rooms with changed labels as distinct finished environments.
2. Finish the proposed per-biome roster: two regular designs, one elite, one distinct boss. The proposed total is 30 regular/elite designs and ten bosses. Keep these counts identified as planning defaults unless the user changes them. Reuse compatible rig/animation families without erasing model/attack identity.
3. Supply functional presentation and readable signature-attack warnings for each enemy, including the second first-biome regular type. Preserve per-enemy animation mappings and follow Part 3's authority/timing interfaces and measured budgets. Track final rig/animation/art polish separately; Part 3 prototypes do not establish a final visual standard.
4. Populate floor-specific encounters, scaling, and rewards. Check current hero balance and preserve stamina/progression/economy rules. Difficulty rises with floor number, but no entry requirements are introduced. Bosses belong only on floors 5, 10, ..., 50.
5. Finish TowerController and integrate it with existing HUD/modal/prompt/input conventions. Show biome groups, floor number/name/difficulty, boss status, visitor count, assigned owner names/counts, your location, and your squad assignment. Visit, Assign, and Recall actions need pending/success/failure states.
6. Complete Previous/Next/Floor Selector/Hub access from every room. Disable Previous on 1 and Next on 50. Validate mouse, touch, and controller navigation; prevent combat clicks through menus and preserve prompt priority over Recall.
7. Complete per-floor environment presentation, room sleeping/retirement rules, and presence updates on reassignment, roster changes, wipe, respawn, and departure. Keep encounters and pending loot/rewards authoritative while rooms change activity.
8. Record content checks as each biome finishes. Save actual asset/source/animation references and visual evidence. Verify runtime resolution for every catalog entry; a missing clip or silently substituted placeholder fails the content gate.

## Content ledger to fill during execution

| Floors | Biome | Room/environment checks | Enemy/animation checks | Gameplay evidence |
| --- | --- | --- | --- | --- |
| 1-5 | Verdant Ruins | NOT VERIFIED | NOT VERIFIED | None |
| 6-10 | Fungal Hollow | NOT VERIFIED | NOT VERIFIED | None |
| 11-15 | Sunken Sanctuary | NOT VERIFIED | NOT VERIFIED | None |
| 16-20 | Ashen Dunes | NOT VERIFIED | NOT VERIFIED | None |
| 21-25 | Frozen Citadel | NOT VERIFIED | NOT VERIFIED | None |
| 26-30 | Thunder Highlands | NOT VERIFIED | NOT VERIFIED | None |
| 31-35 | Infernal Foundry | NOT VERIFIED | NOT VERIFIED | None |
| 36-40 | Corrupted Grove | NOT VERIFIED | NOT VERIFIED | None |
| 41-45 | Astral Archives | NOT VERIFIED | NOT VERIFIED | None |
| 46-50 | Abyssal Throne | NOT VERIFIED | NOT VERIFIED | None |

The master biome names are proposed. Update the ledger and catalog together if names change.

## Verification gate

- All 50 destinations can be entered directly. Every room passes geometry, landing, camera isolation, navigation, and environment checks.
- Catalog/asset validation finds no unresolved enemy IDs, missing required animations, invalid boss mappings, or unlabeled temporary content.
- Each biome has actual combat verification and readable attack warnings. Record prototype presentation honestly; final appearance and polished motion approval belong to the separate polish sprint and release review.
- Boss placement, independent state, enemy scaling, and reward values match the catalog; direct floor-50 entry works with its finished content.
- Two-player selectors show assigned owners/counts accurately while visitors and assignments differ. All travel controls and boundaries work.
- Mobile/controller UI remains usable and does not trigger world combat beneath menus. The representative busiest room meets the recorded content budgets or has a documented optimization fix before proceeding.
- Compile changed scripts, run catalog/completeness checks, and record actual results and content limitations.

## Handoff record to complete during execution

- Status: DEFERRED; implementation NOT STARTED.
- Part 3 combat gate/budgets consumed: not verified for Part 4. Final visual benchmark is deferred to the separate polish sprint.
- Actual changed files and asset manifest: none.
- Completed biome ledger and visual evidence: none.
- UI/input/multiplayer checks and results: none.
- Missing content or unresolved issues: not assessed during implementation.
- Resume point: implement this plan only when requested again. Part 5 remains independently deferred and requires its own resumption request.

## Future execution prompt (use only after resumption is requested)

Implement only Part 4 using the verified Part 3 combat handoff and provisional performance observations. Complete floor content, functional biome encounters/presentation mappings, and travel/presence UI. Track final animation/art polish in its separate sprint. Work biome by biome, record actual combat evidence, label prototypes honestly, and do not begin final release work.
