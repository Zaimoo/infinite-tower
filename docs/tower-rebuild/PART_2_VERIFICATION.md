# Part 2 verification and handoff

Date: 2026-10-21, Asia/Manila. Status: **VERIFIED for the Part 2 isolated-room transport gate**. Part 3 combat and Parts 3/4 enemy art are NOT STARTED. No new floor encounter is enabled.

Historical handoff at Part 2 completion. Current implementation and the user's later combat-only Part 3 scope are recorded in [Part 3 verification](PART_3_VERIFICATION.md); final animation/art polish is a separate sprint.

## What is implemented

The cosmetic crimson tower and its bridge/island approaches remain. The traversal setup retires the old 18-floor ascent into ServerStorage during Play, restores the decorative shell, connects tower portal triggers to the selector, and provides a supported hub arrival outside banking triggers. A recoverable native pre-change copy of all 6,390 traversal descendants and 56 script containers is retained in `ServerStorage.TowerRebuildPart2Recovery_20261021` in the Edit model. The original external Part 1 baseline is also retained. No published-place release was performed.

All 50 catalog IDs are directly selectable without progression checks. Floors 1, 5, and 50 have distinct labeled transport fixtures; other destinations build generic fixtures on demand. Opaque walls/ceiling enclose each room, with supported arrival areas, safe polygons, Previous/Next/Selector/Hub prompts, and bounds recovery. These are **DEVELOPMENT_FIXTURE** environments, not final biome content.

Origins are deterministic: hub `(0,0,0)`; floor `n` uses `(12000 + ((n-1)%10)*1800, 1000, 12000 + floor((n-1)/10)*1800)`. Floor 50 is `(28200,1000,19200)`. Entity packets carry room-local XYZ rather than clamped world coordinates.

Visit and squad assignment are independent. A following squad moves with its owner; an assigned squad stays in its shared floor when the owner travels. Assignment transfers the existing roster, not a duplicate. Recall uses the same server lane/cooldown as the existing E whistle, preserves living hero HP/stamina/cooldowns, clears targets/navigation, and applies two seconds of pacify. There is no autonomous floor combat yet.

Travel validates schemas, revisions, floor IDs, live characters, eligible profiles/rosters, room identity, supported arrival, rate limits, deduplication, and one pending transition per owner. Client streaming readiness uses a token and eight-second deadline; server geometry validation remains authoritative. Commit captures current cargo and hero transfer state, preserves identity/weld/expiry/locks, and rolls back transfer failures. Source state is not frozen or rewound during preparation.

Explicit context and safe-zone checks replace off-map radius-based banking/recovery. Cross-floor targeting/AoE/pickup paths are gated. Cargo/relic drops pin rooms; character replacement/disconnect drop held items, reconcile membership, and cancel pending work. Private relic extraction validates live carrier identity, hub context, real plot ownership, pad volume, and once-only payout inside the extraction method. Travel itself never pays, extracts, heals, or resets coma.

## Production files

| File under `src/` | Change |
| --- | --- |
| `ReplicatedStorage/Shared/Util/TowerProtocol.luau` | Strict v2 buffer codec, context equality, modular sequence comparison, bounds and polygon membership. |
| `ReplicatedStorage/Shared/Util/TowerRequestPolicy.luau` | Bounded request schema and canonical deduplication fingerprint. |
| `ServerScriptService/Core/TowerRoomBuilder.luau` | Enclosed on-demand fixtures and safe travel surfaces. |
| `ServerScriptService/Core/TowerFloorService.luau` | Room lifecycle, session/player/squad state, remotes, readiness, transitions, presence, safety, pins, and retained encounter ledger foundation. |
| `ServerScriptService/Core/TowerTraversalSetup.server.luau` | Cosmetic hub integration and recoverable legacy retirement. |
| `ServerScriptService/Combat/CombatSimulation.server.luau` | Existing roster/cargo adapters, context guards, scoped replication/effects, v2 snapshots, disabled legacy spawners, recall integration, explicit banking, and lifecycle cleanup. |
| `ServerScriptService/Core/HeroNavigation.luau` | Hero avoidance requires matching floor/generation. |
| `ServerScriptService/Core/PlotManager.server.luau` | Existing plot respawn commits hub context. Merged the pre-existing Studio removal of Mana Conduit worker rendering into source instead of overwriting it. |
| `ServerScriptService/ExtractionAndSocial/RelicService.server.luau` | Context-qualified relic identity/pickup/drop, cargo adapter/pins, validated private-pad extraction, and expiry/cleanup. |
| `StarterPlayerScripts/Rendering/EntityRenderer.client.luau` | Matching decoder, generation-qualified reliable roster assembly, stale-view rejection, independent watchdog/resync, view cleanup, preserved hero metadata/weapon updates. |
| `StarterPlayerScripts/UI/TowerController.client.luau` | Minimal 50-floor selector, visit/assign/recall, presence, readiness, adjacent/hub controls, and compact phone layout. |

Both Part 1 catalog modules were installed in Studio without changing their source data. Only the 13 explicitly mapped files were synchronized; unrelated Studio-only scripts, assets, and other recorded drift were preserved. All 13 final source/Studio comparisons match: [comparison evidence](evidence/PART_2_SOURCE_STUDIO.json).

## Executed evidence

| Check | Actual result/evidence |
| --- | --- |
| Original production Luau compilation and unchanged-module CLI suites | Passed. 52 Pit, nine tower foundation, and 12 transport tests: **73 passed, zero failed**. [Full output](evidence/PART_2_TEST_OUTPUT.txt). |
| Part 1 native Studio gate before Part 2 | Both catalogs required successfully; complete nine-test foundation suite passed. No new encounters existed at that point. |
| Real client/server travel with StreamingEnabled=true | Hub → 1 → 5 → 50 → 49 → 50 → hub passed. Native v2 visuals rendered both heroes at floor 50 coordinates. [Six client checks](evidence/PART_2_CLIENT_TESTS.json). Final responsive-client regression repeated these checks successfully. |
| Independent assignment and recall | Owner ViewEpoch unchanged by assignment/recall; assigned heroes absent from an unrelated owner view; recall converges on one six-second cooldown. Included in client evidence. |
| Cargo/relic transfer and readiness failures | Ten live server checks passed, including live HP/stamina/cooldown and cargo identity preservation, no off-map banking, failed arrival surface, timeout with source damage preserved, duplicate/pending/conflicting request behavior, cancellation, bounds recovery, and enclosure raycasts. [Server results](evidence/PART_2_SERVER_TESTS.json). |
| Two real clients | Six checks passed through StudioTestService with two simulated clients: common floor-50 IDs/positions/presence; reassignment; cross-floor pickup; injected old-view snapshots/metadata; respawn preserving assigned squad HP/context; disconnect cleanup; retirement retaining payout claims. [Actual returned result](evidence/PART_2_MULTIPLAYER_TESTS.json). |
| Above the old 255 cap | 300 nonattacking development mob fixtures plus two deployed heroes produced **302 reliable metadata records and 302 rendered VisualNodes** on the live floor-50 client. CLI encoded/decoded every ID in a 500-entity fixture over 16 packets, maximum 814 buffer bytes. [Counts](evidence/PART_2_NETWORK_RENDER.json), [screenshot](evidence/PART_2_FLOOR50_NETWORK.png). No mobile performance claim is inferred. |
| Existing elite AoE isolation | Injected an existing elite AoE and a hero with identical physical coordinates but different FloorIds; HP did not change. Temporary context/entity state restored. [Extra probes](evidence/PART_2_EXTRA_TESTS.json). |
| Dropped-loot retention | Forced empty-room age beyond 60 seconds: live loot kept its room; removing the item allowed retirement. Included in extra probes. |
| Real private-pad payout | Actual owned pad paid one carried relic exactly once; a second direct extraction paid nothing. Test balances restored. Off-map/hub-arrival rejection separately passed. Included in extra probes. |
| Actual mouse input | Selector buttons completed hub → 1 → 5 → 50 → hub. Next disabled on 50; Previous disabled at hub/1. [Desktop selector](evidence/PART_2_SELECTOR_DESKTOP.png). |
| Phone layout | iPhone 17 Pro landscape, measured viewport 750×381, game orientation Sensor, CoreUISafeInsets. Selector 500×291; action targets 145×44. Fixed bar/selector overlap and excessive global scaling. [Phone screenshot](evidence/PART_2_SELECTOR_PHONE.png). Phone inspection used the normal OpenSelector event; desktop mouse interaction was tested separately. |
| Cleanup | All 300 stress entities and temporary multiplayer Edit scripts removed. Test-only source files remain under `tests/`, outside production mappings. Play stopped, simulator stopped, default viewport restored. |
| Whitespace | `git diff --check` passed. |

The earliest solo play session stalled on external avatar requests; retrying without appearance in that disposable session loaded the avatar. Later solo and two-client tests loaded characters normally. No permanent avatar setting was changed. Early test-harness timing/dedup retries and the simulator's unsupported pre-device orientation call were corrected; the evidence above records the passing runs, not those preliminary attempts.

## Protocol and implementation boundaries

- Binary version 2 uses the documented 46-byte header and 24-byte records, 32 records per packet, synchronized server time, 16 raw session bytes (32 lowercase hex characters in reliable messages), floor/generation/view epoch, entity generation, and action sequence. No global 255 truncation or world-position clamping remains in the active encoder.
- Part 2 reliable existence uses complete bounded roster chunks plus COMPLETE at an atomic non-yielding server cut. BootstrapRevision/LifecycleRevision increase monotonically; bootstrap includes snapshot sequence, empty Actions, and disabled boss presentation. Clients replace the roster only after a complete revision, reject older revisions/generations/contexts, retain generation history within a view, and buffer at most two snapshots before bootstrap. Full roster cuts replace proposed incremental upsert/despawn deltas while there are no new attacks. Part 3 must add action/delta reconciliation if it introduces interleaved or yielding lifecycle work.
- `TowerAction` exists as a reserved reliable event; no authored action playback, new mob AI, or attack damage schedule is implemented. Snapshot ActionSequence is zero without an action. Existing CombatRemotes remain for input/HUD compatibility; metadata requests receive the current scoped context/bootstrap, and existing effect messages now include context.
- Room retirement is 60 seconds after no player, squad, live item, or pending transfer pins remain. Per-floor encounter seed/generation/payout tables persist for the session across geometry rebuilding. They are a retention foundation, not implemented biome boss AI or rewards.
- `TowerSpawnLayout`, the original traversal module, and old spawner bodies remain for recovery/reference. Their active legacy population/boss entry points are disabled; lures are not consumed. There are no simultaneous old/new floor spawners.
- Existing Pit/economy behavior is covered by 52 CLI regressions. Full native Pit UI revalidation, a physical-device frame/memory budget, portrait/touch interaction certification, published asset access, and combat with actual new enemies remain later-part checks. The old HUD still has prototype boss information; complete tower UI replacement belongs to Part 4.

## Re-running and recovery

Run `./tests/run.ps1` from `C:\Projects\infinite-tower`; it compiles every original production file, then executes shipped modules with a CLI-only Roblox constructor/module shim. The new transport tests independently exercise codec limits, all 50 destinations, malformed requests/buffers, sequence wrap, context rejection, and polygon boundaries.

Native fixtures are in `tests/studio-part2-client.luau`, `studio-part2-server.luau`, `studio-part2-extra.server.luau`, and the multiplayer client/server pair. Inject them only into disposable Studio test sessions as described in their headers. The server stress suite intentionally leaves 300 nonattacking entities for measurement; remove IDs >=3,000,000,000 and rebuild metadata, or stop Play. Multiplayer uses the argument `TOWER_PART2_MULTI`, returns its result through StudioTestService, and removes a simulated client during cleanup testing. Historical one-time migration scripts are retained under `evidence/migration-scripts/`; **do not rerun them against the implemented source**.

For recovery, compare individual sources against the Part 1 external baseline or the native ServerStorage recovery copies. Recover old traversal from the native recovery folder or the runtime `TowerLegacyTraversal` folder, with the old traversal setup/spawners restored together in a separate test copy. Do not bulk-reset unrelated Studio scripts/assets or unrelated worktree changes.

## Exact Part 3 starting point

Read this record and TOWER_CONTRACTS v1. Keep all context, cargo, safety, generation, and presence guarantees while adding floor-local AI/assignment anchors, retained per-floor boss state and payout claims, authoritative action timelines, and authored client animation playback. Supply and validate the first-biome regular/elite/boss art/rig/animations; all manifest assets are still MISSING. Extend the reliable lifecycle/action protocol deliberately on both ends and repeat two-client isolation/late-action/respawn tests with real attacks. Do not enable the encounters or expand to Part 4 until that quality gate passes.
