# Tower rebuild implementation plan

Current milestone: **Parts 1–3 VERIFIED for their recorded gates; implementation stops at Part 3.** Combat and damage feedback are enabled on floors 1 and 5 with prototype visuals. The user explicitly deferred animation/art polish, Part 4, and Part 5 on 2026-10-21. Resume those only after a new user request. See the [documentation index](README.md), [Part 3 evidence](PART_3_VERIFICATION.md), and [latest merge/Studio verification](MAIN_MERGE_AND_STUDIO_RESTORE_20261021.md).

## Five-part execution map

This document preserves the complete design roadmap. Parts 1–3 describe the completed milestone; later content and release requirements are deferred backlog. The broader design and final acceptance criteria below do not extend the current implementation scope.

| Part | Work package | Current status |
| --- | --- | --- |
| 1 | [Verified baseline, floor data, and contracts](PART_1_FOUNDATION.md) | VERIFIED — [evidence](PART_1_VERIFICATION.md) |
| 2 | [Hub, isolated rooms, travel, and replication](PART_2_WORLD_AND_TRAVEL.md) | VERIFIED — [evidence](PART_2_VERIFICATION.md) |
| 3 | [Working mob/squad combat and damage feedback](PART_3_COMBAT_AND_FEEDBACK.md) | VERIFIED — [evidence](PART_3_VERIFICATION.md) |
| Separate sprint | [Animation and art polish](deferred/ANIMATION_POLISH_SPRINT.md) | IMPLEMENTED (CLI VERIFIED; Studio NOT VERIFIED) |
| 4 | [All 50 floors, full enemy roster, and complete UI](deferred/PART_4_CONTENT_AND_UI.md) | IMPLEMENTED (CLI VERIFIED; Studio NOT VERIFIED) |
| Separate sprint | [Animation and art polish](deferred/ANIMATION_POLISH_SPRINT.md) | DEFERRED — not scheduled |
| 4 | [All 50 floors, full enemy roster, and complete UI](deferred/PART_4_CONTENT_AND_UI.md) | DEFERRED — implementation not started |
| 5 | [Integration, performance, migration, and release verification](deferred/PART_5_VERIFICATION_AND_MIGRATION.md) | DEFERRED — release verification not started |

### Rules for each implementation session

1. Read this master plan, the current part, and the previous part's handoff. Inspect the actual source and connected Studio state before making changes. Historical findings below must be rechecked when relevant.
2. Distinguish user requirements, proposed defaults, existing APIs, and new APIs. Biome names, roster counts, and independent squad assignment are proposed defaults, not additional user-confirmed requirements. Honor subsequent user corrections.
3. Work only on the current part. Include necessary prerequisite fixes within that part and record them. Do not silently redesign unrelated systems or expand into later content work.
4. Never invent asset IDs, animation IDs, existing modules, successful tool results, performance numbers, or test outcomes. Inspect assets before calling them suitable. Mark unavailable checks NOT VERIFIED and missing assets MISSING.
5. Keep server/client protocol changes together. Enforce FloorId and explicit safe-zone rules before off-map combat is enabled. Part 2 may use labeled development fixtures; they do not satisfy the final art/content requirements.
6. End with the part's handoff filled in: actual files changed, implemented contracts, executed checks, visual evidence where required, known issues, and the exact stopping point. Use NOT STARTED, IN PROGRESS, VERIFIED, BLOCKED, or DEFERRED for implementation status.
7. A verified gate records completion of that part; it does not authorize starting deferred work. Resume deferred scopes only when the user requests them. If a required tool or external asset is unavailable, finish independent authorized work, record the exact gap, and report it without claiming completion.

Partitioning limits context and scope; the recorded checks are what establish correctness. No phase is implemented merely because its checklist exists.

## Full-roadmap intended behavior

- The central crimson tower remains the cosmetic landmark and portal hub.
- There are exactly 50 playable floors, each in a separate enclosed room outside the visible hub. Players see the room they enter, without seeing neighboring rooms or rooms from the hub.
- Every floor is available immediately. Floor number indicates difficulty, not an unlock requirement. Boss kills never gate travel.
- Ten biomes each cover five floors. Each floor has its own name, layout, environmental set dressing, and encounter composition within its biome.
- Floors 5, 10, 15, 20, 25, 30, 35, 40, 45, and 50 contain a biome boss.
- Every usable hub entrance opens the same floor selector. Every room has a safe arrival/travel area with Previous Floor, Next Floor, Floor Selector, and Return to Hub controls.

## Planning assumptions

1. Floor rooms are shared within the current server. Players assigned to the same floor encounter each other and the same enemies/boss state.
2. Use the existing one deployed squad per player, with up to five heroes. One squad can be assigned to one floor at a time.
3. Track player location separately from squad assignment. The selector provides Visit Floor and Assign Squad actions; an assigned squad can remain fighting while its owner visits another room or the hub. Recall explicitly brings the squad back to its owner and updates assignment state.
4. Squad activity continues while its owner remains connected to that server. The project currently uses session-only profiles; cross-server presence, offline simulation, and persistent assignments are outside this rebuild.
5. Preserve the existing physical loot, private-pad relic extraction, hero stamina, coma, and deliberate-command progression rules. Travel itself does not award loot, restore heroes, or bank cargo.

Assumption 3 is a proposed gameplay default: independent assignment changes the existing player-following squad behavior. Record the chosen behavior explicitly in Part 1 and keep location and assignment distinct so presence cannot become misleading.

## Proposed biome schedule

These are provisional content names and themes.

| Floors | Biome | Boss |
| --- | --- | --- |
| 1-5 | Verdant Ruins | Mossbound Guardian |
| 6-10 | Fungal Hollow | Spore Matriarch |
| 11-15 | Sunken Sanctuary | Tidal Leviathan |
| 16-20 | Ashen Dunes | Sandstone Colossus |
| 21-25 | Frozen Citadel | Frostbound King |
| 26-30 | Thunder Highlands | Storm Roc |
| 31-35 | Infernal Foundry | Ember Titan |
| 36-40 | Corrupted Grove | Blight Sovereign |
| 41-45 | Astral Archives | Rift Warden |
| 46-50 | Abyssal Throne | Crimson Overlord |

Within each group, use five distinct environments: introduction, expanded encounter, terrain/layout variation, elite stronghold, and boss arena. Every room must work when entered directly. Raise enemy HP, damage, composition, and reward values with floor number, using configurable curves checked against current hero stats. Increase encounter complexity across biome groups while retaining readable attack telegraphs.

## Mob art, animation, and combat quality

The visual quality targets in this section belong to the separate animation/art polish sprint and eventual release review. They do not gate Part 3 combat completion. Part 3 uses the existing prototype models/clips while requiring readable warnings, authoritative impacts, basic hit feedback, and safe cleanup.

### Roster and visual direction

- Proposed baseline per biome: two regular enemy types, one elite, and one unique boss. This yields 30 regular/elite designs and ten bosses across the tower. Reuse compatible skeletons and animation families where appropriate, with floor-specific encounter variants.
- Match the existing stylized fantasy heroes and crimson hub through consistent proportions, material treatment, texture quality, and effects. Enemy roles must be recognizable at the normal gameplay camera distance.
- Give enemy types distinct silhouettes and attack identities. A crawler, armored guardian, and caster should read differently in shape and motion. Biome identity should come from modeled features, materials, and behavior as well as color.
- Each boss needs its own model identity, animation set, signature attacks, and biome-themed effects. Configure visual assets by enemy ID; do not route every floor boss to the same Rift Warden model.
- First-biome example: moss crawler (bite/lunge), ruin guardian (heavy strike), vinebound elite (root cast), and Mossbound Guardian boss (slam and sweeping roots).

### Asset production and validation

Audit existing models individually and retain assets that meet the visual target. The current seven MobRigs templates each contain one MeshPart and no bones, Motor6Ds, AnimationController, Animator, or Animation objects. They cannot supply articulated limb attacks as they stand; rebuild or rig them where needed.

Produce rigged meshes or articulated models with suitable joints for their anatomy. Verify scale, floor contact, pivots, rest pose, weapon attachment, textures, and deformation at maximum attack poses. Use client visual rigs while preserving the lightweight server simulation. Keep editable source assets and animation mappings with the project.

Create an asset manifest linking each enemy ID to its model, rig family, animation set, attack definitions, effects, and sound references. Check that the intended animations are accessible in a published playtest. A missing asset or animation must produce a diagnosable development error; generic placeholder visuals do not meet the final content gate.

Set mesh, bone, texture, and effect budgets using measurements from a representative busy room on mobile. Share materials/rig families where useful, limit particles and distant animation work, and verify the result at the intended encounter density.

### Required animations and attack timing

- Every moving enemy: idle, walk/run or anatomy-appropriate locomotion, basic attack, hit reaction, and death. Stationary creatures need appropriate idle/cast motion instead of an artificial walk cycle.
- Basic attacks need a visible anticipation, strike/contact moment, and recovery. Match the animation to the attack: bite, claw, weapon swing, projectile release, or spell cast.
- Elites add their special ability animation and readable ground/projectile warning. Bosses add multiple signature attacks, an entrance/awakening where appropriate, and phase-transition motion when their encounter uses phases.
- Hit reactions are visual unless gameplay explicitly grants a stagger. Attacks cannot be interrupted accidentally by idle loops or cosmetic flinches.

Represent attacks explicitly on the server: enemy ID, unique attack sequence, attack definition, target/aim, synchronized start time, windup, impact/release time, and recovery. Send attack presentation to clients viewing that floor and include sufficient current state for travel/late delivery to reconcile correctly. Deduplicate repeated events and clear canceled attacks after death, despawn, or a context change.

Clients play the authored animation and align trails, projectiles, impact effects, and sound to the authoritative timeline. The server validates targets/range and applies damage once at the defined impact time; client animation markers never grant damage or rewards. Telegraphs must appear before damage, and late events must not restart old attacks or create hits from dead enemies.

### Normal mob behavior is part of this work

Implement idle/patrol where appropriate, same-floor aggro, chase, facing, attack windup, impact, recovery, leash/reset, and death/respawn. Ranged enemies need visible projectile release and a defined server impact rule. Check nearby assigned heroes as well as player characters when deciding whether to activate combat or cast abilities.

The existing ordinary-mob update only handles respawning and stationary AoEs, with a separate global-boss path. Basic mob chase and basic attack execution must be added; moving a static mesh or repeatedly playing an animation without a matching attack is insufficient.

### Later visual benchmark

In the separate polish sprint, complete one first-biome regular mob, one elite, and the first boss to the intended art/animation standard before propagating the polished visual treatment to the remaining roster. Review normal-camera and mobile motion, foot contact, deformation, weapon attachment, and effects. Combat/content implementation can proceed with honestly labeled prototypes. Readable telegraphs and correct server impact timing remain immediate combat requirements.

## Historical findings before the rebuild

These observations describe the pre-Part-1 baseline. Parts 1–3 supersede several of them; consult their verification records for current behavior.

- Studio currently contains an 18-floor WalkableTower with roughly 6,390 descendants. TowerTraversal and TowerSpawnLayout depend on these physical platforms and ramps.
- CombatSimulation uses a 5 Hz lightweight entity simulation and one global world-boss state. Preserve the simulation approach, but move spawning and boss state into floor contexts.
- Heroes currently follow and leash to the player. Autonomous floor assignment needs a floor-local combat anchor and target acquisition.
- Entity coordinates currently use signed 16-bit values at one-tenth-stud precision, clamping world positions to approximately +/-3,276.7 studs. Off-map rooms require room-local positions and a matching server/client packet update.
- Several AoE and zone calculations use horizontal distance. Explicit FloorId checks are necessary to prevent cross-room damage and interactions.
- CombatSimulation treats any horizontal world radius >=460 as safe for banking/recovery. This must become explicit plot/safe-zone detection before off-map combat is enabled.
- Combat metadata, snapshots, and effects currently broadcast broadly. Floor-scoped delivery and stale-entity cleanup are needed.
- Replication currently stops at 255 entities globally. Replace that global truncation with per-floor/relevant entity batches so active floor encounters cannot silently disappear.
- Mobs currently replicate only a phase-style state, while the procedural animator recognizes the hero attacking state. The existing generic joint motion does not provide mob attack playback or synchronized attack timing.
- The renderer has no deliberate hit/cast/death playback, and its effect handler does not render the emitted HIT_SPARK effect. Add enemy action presentation and allow death animation to complete before cosmetic cleanup.
- PlotManager returns players to their plot on respawn. Floor location and squad state must reconcile with that existing behavior.

## Roadmap sequence (Parts 4–5 deferred)

1. Part 1 creates verified floor data and the state, network, attack, and asset contracts. It records migration/recovery steps and the boundary between existing and proposed modules.
2. Part 2 implements the hub and a limited test route through isolated rooms 1, 5, and 50, a minimal selector, validated travel, presence plumbing, loot-safe transfer, and matching server/client room-local replication. New floor encounters stay disabled until Part 3 passes. Preserve a recoverable copy of old generated traversal when replacing its test-route integration.
3. Part 3 completes the first playable combat slice: autonomous assigned squads, normal mob AI, independent floor boss state, synchronized authoritative attacks, and floating damage feedback using existing prototype visuals. It verifies cross-floor interaction boundaries and enables the two slice floors. Final art/animation polish is a separate sprint.
4. Part 4 expands through ten biome kits and 50 distinct rooms, completes the enemy roster and animated attacks, tunes difficulty/rewards, and finishes the selector/navigation/social UI. Work in five-floor biome batches within this part, with a recorded content check for each batch.
5. Part 5 completes integration and performance fixes, compilation and existing Pit regressions, targeted tower checks, multiplayer/mobile playtests, source/Studio comparison, targeted legacy migration, and final documentation. Preserve a recovery snapshot and record actual evidence against the acceptance criteria below.

## Final release acceptance criteria (deferred Part 5)

These criteria cover the eventual full rebuild. They are not claims that the Part 3 milestone supplies all 50 finished environments, the full roster, polished animation, or release certification.

- A new player can enter floors 1, 25, or 50 directly with no unlock, payment, or clear requirement.
- Exactly 50 floor definitions map to ten five-floor biome groups; each floor has its own environment variant.
- Only floors divisible by five host the configured biome boss, with independent state per floor.
- The tower is cosmetic; players enter gameplay rooms through working hub portals.
- Rooms cannot be seen from the hub or neighboring floors, including through the normal player camera.
- Two players assigned to the same floor share its encounters; selectors show correct owner names and update after reassignment or departure.
- Visiting a floor and assigning a squad are distinct, accurate states. No hero duplication occurs when changing assignment or roster.
- Previous/Next/Hub work, with correct boundaries and no progression gate.
- No attacks, AoEs, retaliation, pickup, or reward participation cross floor boundaries.
- Teleporting preserves hero/cargo rules and does not trigger accidental banking or recovery.
- Boss state and reward payout cannot be duplicated by travel or simultaneous kills.
- Respawn, wipe, disconnect, failed travel, and room retirement leave no stale presence, rigs, loot references, or targets.
- Off-map entity rendering, telegraphs, streaming readiness, and stale-packet rejection work reliably.
- Every enemy design has an approved in-game appearance, a functioning rig, and the animation set appropriate to its movement and attacks.
- Normal mobs visibly acquire/chase targets and execute attacks; their windup, contact, effects, and recovery match the actual server damage window.
- Each of the ten bosses has its own model identity and animated signature attacks, with readable warnings before damage.
- Two clients observe consistent attacks. Travel, delayed events, interrupted windups, simultaneous death, and packet loss never replay attacks, duplicate damage, or leave stuck poses/effects.
- Death animations finish through explicit cosmetic cleanup, without preventing authoritative death or reward payout.
- A representative full encounter meets the chosen mobile frame-time, memory, and effect budgets without broken materials, severe foot sliding, rig distortion, or weapon detachment.
- Existing plot facilities, Pit, hero management, loot extraction, and recovery still work.

## Main implementation areas

New modules: TowerFloorConfig, TowerFloorService, TowerRoomBuilder, TowerController, an enemy asset/attack catalog, an enemy animation controller, and focused tower behavior checks. Add rigged enemy models, animation sets, and their editable sources to the asset workflow.

Existing integrations: TowerTraversalSetup, TowerTraversal, TowerSpawnLayout, TowerBuilder, BridgeBuilder, CombatSimulation, HeroNavigation, EntityRenderer, HUDController, FacilityController, MasterController, DataManager, PlotManager, and RelicService.
