# Part 3 implementation, verification, and handoff

Latest integration: [main merge and Studio restoration](MAIN_MERGE_AND_STUDIO_RESTORE_20261021.md) preserves this scope, fixes startup with the retired altar absent, and passes 101 CLI plus 17 native checks.

Scope revised by the user on 2026-10-21: working combat and basic feedback now; animation/art polish in a separate sprint. This record distinguishes gameplay verification from later release certification.

Status: **VERIFIED for the revised Part 3 combat/feedback gate**. The current default-on combat/feedback run passed all 11 native checks, alongside 95 CLI regressions. Final art quality is deferred and does not block this combat gate. This is not a published release certification.

## Implemented behavior

Floors 1 and 5 contain the first-biome slice: Moss Crawlers, a Vinebound Elite, and the floor-5 Mossbound Guardian. Floor 50 remains a transport fixture. `FirstBiomeCombat.ReleaseEnabled=true` enables these two floors without a preview flag. A Studio-only `TowerCombatPreview=false` override can pause encounters for transport testing. No other floor populations are enabled and nothing has been published to Roblox by this work.

Mobs acquire same-room heroes and player characters, chase and face targets, telegraph, impact once, recover, reset to their home, die, and respawn. Assigned squads use a combat anchor separate from safe arrival and fight while their owner stays in the hub. Assignment, recall, and roster rebuilding preserve runtime hero state. Enemy deaths retain per-slot/life reward claims and respawn deadlines; room rebuilding preserves boss HP and cooldowns.

Movement/acquisition runs at 5 Hz. Active impacts validate every server heartbeat so contact is not delayed by a whole movement tick. Damage checks actor/target life, context, entity generation, safe zones, shape/range, and line of sight. The reliable action channel supplies original synchronized start times, cancellation, completion, hit, and death messages; bounded bootstrap reconciliation and tombstones prevent delayed attacks from reviving dead actors.

Damage feedback uses the existing room-scoped server hit event. Floating numbers show actual applied HP loss, including overkill clamping and actual Humanoid damage after protection. Pale numbers indicate enemy damage, gold indicates Overdrive, and red indicates incoming damage to heroes/player characters. They last 0.8 seconds, cap at 32 concurrent labels, reject invalid/nonpositive values, and clear on view changes. Hit sparks and existing HP bars accompany them. This cosmetic unreliable event never grants damage or rewards; packet loss may omit a number while authoritative HP still replicates.

## Production sources

| Source under `src/` | Responsibility |
| --- | --- |
| `ReplicatedStorage/Shared/Config/FirstBiomeCombat.luau` | Executable slice population, stats, attacks, enablement, and local visual references. The broader MobCatalog remains a proposal manifest. |
| `ReplicatedStorage/Shared/Util/AttackTimeline.luau` | Qualified identity, shapes, scheduled once-only impact, cancellation, and stall expiry. |
| `ReplicatedStorage/Shared/Util/EnemyActionState.luau` | Client sequence reconciliation, terminal records, and death tombstones. |
| `ServerScriptService/Combat/TowerEncounterRuntime.luau` | Room-local AI, player/hero targets, retained lives/cooldowns/reward claims, respawn, and active actions. |
| `ServerScriptService/Combat/CombatSimulation.server.luau` | Hero combat anchors, progression qualification, HP/loot/coma integration, scoped action replication, and actual-damage feedback. |
| `ReplicatedStorage/Assets/CombatFeedback.luau` | Bounded floating damage labels and hit sparks. |
| `StarterPlayerScripts/Rendering/EntityRenderer.client.luau` | Atomic roster/action bootstrap, cancellation/death cleanup, scoped feedback, and prototype visual playback. |
| `ReplicatedStorage/Assets/TowerEnemyRigs.luau` | Editable native articulated model builder: six-legged crawler, branch biped elite, and stone boss. |
| `ReplicatedStorage/Assets/TowerEnemyClips.luau` | Local authored prototype pose clips and sampling. |
| `ReplicatedStorage/Assets/EnemyAnimationController.luau` | Dedicated prototype clip player, warning shapes, contact effects, hit reaction, and cosmetic death cleanup. |

The three native models/clips have no claimed uploaded model/animation IDs. Their local sources are real; their final art/animation approval remains deferred.

## Attacks

All use scheduled server shape checks and fixed warning/aim geometry; no cosmetic projectile decides damage.

| Enemy / attack | Windup | Recovery | Shape |
| --- | --- | --- | --- |
| Crawler / moss_bite | 0.65 s | 0.65 s | Forward arc, range 7 |
| Elite / vine_cleave | 0.9 s | 0.8 s | Forward arc, range 9 |
| Elite / root_bloom | 1.4 s | 1.0 s | Fixed target disc, radius 9 |
| Boss / guardian_crush | 1.1 s | 1.0 s | Forward arc, range 13 |
| Boss / moss_quake | 1.8 s | 1.2 s | Self disc, radius 22 |
| Boss / sweeping_roots | 2.2 s | 1.5 s | Fixed target disc, radius 13 |

## Executed evidence

- Part 2 was re-tested before implementation: 73 CLI checks passed, plus [six real client travel/assignment/recall checks](evidence/PART_3_PART2_RETEST.json). The route was repeated successfully after restoring the tested files to a reconnected Studio session.
- The original expanded suite passed **95 checks**, including 22 attack/cancellation/reconciliation cases. The revised enabled configuration also passes [all 95 checks](evidence/PART_3_COMBAT_SCOPE_TEST_OUTPUT.txt); production scripts compile in their original form.
- The [revised native run](evidence/PART_3_COMBAT_SCOPE_NATIVE_TESTS.json) passed **five gameplay checks and six feedback checks**: default enablement without a preview switch, unattended combat, state preservation, boss travel retention, rendering, input rejection, label styles, the 32-label cap/expiry, clear/reuse, real server-hit numbers, and real Overdrive numbers. Observed live labels included ordinary `-39` and Overdrive `-46`. Expiry is tested against the shipped module with an explicit expired clock; the renderer advances cleanup each render frame. Earlier startup-timing test failures were corrected before this passing run.
- [Five native solo checks](evidence/PART_3_SERVER_TESTS.json) passed: exact populations, unattended assigned combat, state-preserving roster rebuild, recall, and boss state across travel. This earlier run used the preview switch; the revised native run separately verifies default enablement and damage feedback.
- [Seven real two-client checks](evidence/PART_3_MULTIPLAYER_TESTS.json) passed: shared identities/rigs, regular/elite/boss attacks, warnings before damage, contact-pose samples, attacker death during windup, target departure/cross-floor rejection, late-entry seek and duplicate START rejection, retained boss state, and once-only reward/deadline retention across geometry rebuilding. These predate the damage-number/default-on scope update; the authority interfaces are unchanged by that update.
- The final two-client combat run enforced server contact lateness below 0.12 seconds. Initial 5 Hz impact polling was slower; it was replaced by heartbeat validation and re-tested. The two simulated clients measured roughly 66–69 ms frame times; that result is not a physical mobile benchmark.
- A separate [10-second mobile-viewport combat measurement](evidence/PART_3_MOBILE_MEASUREMENT.json), 750×381 landscape with Sensor game orientation, recorded 448 frames, 20.79 ms median, 31.94 ms p95, and 0.2022 ms p95 per-rig animation calls. Studio-reported total memory changed from 2574.19 to 2584.09 MB; it includes the test environment and is not a certified device memory budget. This predates floating-number feedback.
- The encounter has 140 native art parts and 52 Motor6Ds across four enemies. The new rigs use no skinned meshes, texture maps, or bones. Use these as provisional observations for Part 4, not universal limits for later assets.

## Prototype visual evidence and deferred work

See [crawler](evidence/PART_3_CRAWLER_PREVIEW.png), [elite](evidence/PART_3_ELITE_PREVIEW.png), [boss](evidence/PART_3_BOSS_PREVIEW.png), [contact poses](evidence/PART_3_CONTACT_POSES.png), and the [live floor-5 overview](evidence/PART_3_FLOOR5_PREVIEW.png). These are prototype previews, not final-quality approval. Foot contact during body leans, contact poses, silhouette/material polish, refined motion and audio belong to [the separate polish sprint](ANIMATION_POLISH_SPRINT.md).

Native fault injection of real packet loss, a published-place access check, physical-device certification, and full release regression remain NOT VERIFIED. Part 2's earlier respawn/disconnect tests are not represented as re-executed with combat by this record. Retain these explicit integration checks for Part 5.

## Recovery and next work

Pre-change Studio sources and the later reconnect backup are under `evidence/PART_3_STUDIO_BEFORE.json`, `PART_3_RECONNECTED_STUDIO_BEFORE.json`, and `PART_3_COMBAT_SCOPE_STUDIO_BEFORE.json`. Earlier comparison matched all 20 tower source mappings. The scope update's five production mappings have a separate [source/Studio comparison](evidence/PART_3_COMBAT_SCOPE_SOURCE_STUDIO.json). Preserve unrelated Studio-only assets and other source changes. Temporary fixtures under `tests/` are outside production mappings and are removed from Edit after native runs.

Next: Part 4 content/UI work when requested. Animation/art polish remains its own deferred sprint and no longer prevents using this combat slice. Floors 1 and 5 are enabled; no Roblox publishing was performed.
