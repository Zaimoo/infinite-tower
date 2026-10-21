# Part 1 of 5: Verified baseline, floor data, and contracts

Implementation status: VERIFIED (Part 1 source/data/documented-contract gate only; no new gameplay enabled).

Execution evidence and recovery instructions: [Part 1 verification](PART_1_VERIFICATION.md). Implemented interface specification: [Tower contracts v1](TOWER_CONTRACTS.md).

Read [the master requirements](TOWER_REBUILD_PLAN.md) before starting. This part defines and checks the foundation; later parts build gameplay and content.

## Scope

1. Inspect the current Git changes, source, connected Studio identity/mode, tower geometry, mob templates, and source/Studio differences. Preserve unrelated user work. Record what is actually present and a recoverable baseline; do not assume the earlier inspection is still current.
2. Create TowerFloorConfig with exactly 50 floor records, ten groups of five, boss entries on multiples of five, no unlock requirements, and configurable difficulty/reward values. Label biome/content names as proposed defaults. Do not claim its referenced art exists yet.
3. Record the state contract: player location versus squad assignment, one existing deployed roster per player, shared room membership, hub context, and room lifecycle. Document recall, unassigned squad-follow behavior, owner travel, roster changes, wipes, and respawn transitions explicitly.
4. Define the server service/remote interface for visit, assign, recall, presence, and readiness/error responses. Define validation and request limits. Floor IDs and owned rosters are server-validated; clients never provide authoritative coordinates, rewards, or damage.
5. Define room-local replication with floor/context identity, packet version, room origin lookup, entity lifecycle/generation, action sequence, and synchronized attack timing. Define how stale packets and reconnecting viewers reconcile. Encoder and decoder implementation will land together in Part 2.
6. Define the proposed MobCatalog/asset manifest: model, rig family, animation mappings, anatomy, bounds, attack phases/timing, effects/audio, and source paths. Record missing assets/animations explicitly.
7. Document cargo transfer, private extraction, safe-zone detection, and room retention/retirement rules. World radius must not establish safety in the new system. Rooms with active players, squads, or live loot cannot be discarded.

## Relevant source to inspect

- ReplicatedStorage/TowerSpawnLayout.luau and Shared/Config/WorldBossConfig.luau.
- Core/TowerTraversal, TowerTraversalSetup, HeroNavigation, DataManager, and PlotManager.
- Combat/CombatSimulation.server.luau and ExtractionAndSocial/RelicService.server.luau.
- Rendering/EntityRenderer.client.luau, Assets/ArtPackVisuals.luau, Input/MasterController.client.luau, and UI controllers.

These are repository-relative pointers, not guarantees of unchanged APIs. New names in the master plan are proposed modules until implemented.

## Scope boundary

Do not rebuild geometry, import the full enemy roster, replace the renderer, or enable new floor encounters in this part. A server contract is not a functioning service; identify scaffolding clearly.

## Verification gate

- Actual source/Studio baseline and recovery location recorded.
- Catalog checks prove 50 unique floor IDs, ten five-floor groups, ten correctly placed bosses, valid catalog/layout identifiers, and all floors unlocked. This gate validates data references, not room instances or finished assets that later parts create.
- Proposed scaling is checked for finite/nonnegative values and intended progression against current hero stats; distinguish provisional balance from playtested balance.
- State transitions and protocol fields are documented, including error/cancellation cases and the cargo policy.
- Existing versus newly introduced APIs and missing assets are listed without fabricated IDs.
- Compile changed Luau and run meaningful data/contract checks. Record exact commands and actual output.

## Handoff record to complete during execution

- Status: VERIFIED for this part's foundation gate, 2026-10-21 (Asia/Manila).
- Verified baseline/Studio identity and recovery snapshot: source commit b2a9ef7; branch codex/tower-rebuild-part-1; Edit Studio place 136256010643848. Source archive, original untracked plan, all Studio source bodies, geometry/rig inspection, and comparison saved in `C:\Users\msi\Documents\ChatGPT\Infinite towers\tower-rebuild-baseline-20261021`. No Studio changes. Native place/asset backup remains required before Part 2 geometry edits.
- Actual changed files and contracts implemented: new TowerFloorConfig and MobCatalog data modules, TOWER_CONTRACTS v1, tower data checks, test-loader dependency fix, verification/evidence files, and this/master handoff. See the complete file/API table in PART_1_VERIFICATION.md. Service, remotes, packet v2, gameplay transitions, and finished assets remain proposed interfaces, not running implementations.
- Checks executed, results, and evidence paths: Luau 0.743 compiled all production scripts; nine tower checks and 52 existing Pit regressions passed, zero failures; git diff --check passed. Studio read-only inspection and 54-script source-capture integrity check passed. Full output and source/Studio comparison are under `evidence/`, linked from PART_1_VERIFICATION.md.
- Remaining assumptions, missing assets, and blockers: independent squad assignment chosen as the proposed default; names/40-design roster/scaling provisional. Final rebuilt models, rigs, authored animations, FX/audio, sources, and executable attack tuning MISSING. 16 existing source/Studio script differences and six Studio-only scripts preserved. Runtime/new-module Studio sync, native place recovery, multiplayer/mobile, and later gameplay gates NOT VERIFIED; no Part 1 data/contract blocker remains.
- Next starting point: Part 2, beginning with source/Studio drift review and a native recovery snapshot, then limited fixture rooms, validated travel/presence, explicit safety/cargo transfer, and paired protocol v2 implementation. Keep new encounters disabled until Part 3.

## Suggested execution prompt

Implement only Part 1 of the tower rebuild. Read the master plan and this file, inspect actual source/Studio state, and distinguish existing APIs from proposed ones. Complete the foundation and its verification gate, then update this handoff with evidence. Do not begin Part 2 or claim unrun checks passed.
