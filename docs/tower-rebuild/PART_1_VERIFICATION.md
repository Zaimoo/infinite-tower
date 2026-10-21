# Part 1 verification and recovery record

Date: 2026-10-21, Asia/Manila. Foundation gate: VERIFIED for source inspection, data, and documented contracts. No new service, remotes, room geometry, encounters, or packet codec is enabled.

## Baseline actually inspected

- Repository: `C:\Projects\infinite-tower`, starting commit `b2a9ef7` (main); implementation branch `codex/tower-rebuild-part-1`.
- Initial worktree changes: only untracked `docs/tower-rebuild/` (the existing six planning documents). The original documents were copied before editing; the other four part documents remain unchanged.
- Connected Studio: `Infinite Towers: Become a Master!`, place `136256010643848`, universe `10771894864`, Studio ID `35b19ba0-2dd4-49a7-ad5f-46a041997cb3`, Edit mode. All Studio calls in this session were read-only. No play session or source synchronization was performed.
- Actual tower path: `Workspace.BaseOverhaulGeometry.CentralCrimsonTower`; 7,972 descendants. Its `WalkableTower` has 18 floor models and 6,390 descendants (6,372 Parts); `TraversalVersion=3`, `WalkableFloors=18`. Existing geometry is still in place.
- Seven MobRigs templates each have one MeshPart and one Part; none has Bones, Motor6Ds, AnimationController, Animator, or Animation objects. Template presence is verified; final art quality, pivot/contact suitability, and articulated attacks are NOT VERIFIED. Detailed measured bounds/counts are in [Studio summary](evidence/PART_1_STUDIO_SUMMARY.json).

Source/Studio comparison used LF-normalized UTF-8 bytes, byte count, and DJB2 modulo 2^32 (initial value 5381). This is a drift check, not a cryptographic integrity assertion. There are 48 pre-existing repository scripts and 54 Studio scripts: 32 common scripts match, 16 common scripts differ, and six scripts exist only in Studio. The two new catalog modules are intentionally source-only. See [the comparison](evidence/PART_1_SOURCE_STUDIO.json) for every differing path/hash. For example, Studio HeroCatalog uses `PreferredFacility="NONE"` where source uses `FACILITY_CONDUIT`; these are real source differences, not merely CRLF differences. This work does not choose one side of those unrelated changes.

Studio-only scripts include BlurGuard, PromotionController, SquadController, and three LightConfig scripts in Jenna's pauldron. Existing `$ignoreUnknownInstances` mappings do not make these files part of the repository. Do not bulk synchronize/replace unknown instances during the next part.

## Recoverable source baseline

Local recovery directory: `C:\Users\msi\Documents\ChatGPT\Infinite towers\tower-rebuild-baseline-20261021`.

| Artifact | What it recovers |
| --- | --- |
| `source-b2a9ef7.zip` | Tracked repository contents before implementation; created with `git archive --format=zip --output=... HEAD`. |
| `original-plan/` | All six originally untracked tower planning documents. |
| `git-status.txt` | Initial worktree status. |
| `studio-sources.json` | Inventory of 54 Studio scripts and 48 unique complete source bodies. Six identical Animate bodies are deduplicated by their inventory hash. |
| `studio-script-bodies/` | Plaintext copies of those unique Studio source bodies, named by instance path. |
| `studio-inspection.json`, `studio-tower.json` | Script inventory, mob template measurements, tower attributes/counts. These are inspection evidence, not serialized geometry. |
| `verified-comparison.json` | Source/Studio differences and capture integrity result. |
| `verification-output.txt` | Actual compiler and test console output. |

All 48 captured bodies were rehashed and checked against their inspected byte count/hash; every one of the 54 inventory scripts has a captured matching body. Capture integrity errors: **0**.

SHA-256 of `source-b2a9ef7.zip`: `FDC10762B6F327A36F960A4BF54DD214CA0D5BFE375B7D089936A728040C6EBA`.

SHA-256 of `studio-sources.json`: `E175B82529BCA6899C7E0424D74BAEA969C21AF622DC8344246D8F5B494EC728`.

Recovery: extract the source archive into a separate directory and compare/copy the specific files needed; do not reset unrelated work. Restore planning documents from original-plan if needed. To recover a Studio source body, use its inventory path/hash to locate the captured Source (the matching hash identifies duplicate bodies), then restore that particular script deliberately. The archive and source export do **not** recover Studio model binaries or generated geometry. No such assets were changed in Part 1. A native place/model recovery snapshot, including old generated traversal and runtime-only assets, is still required in Part 2 before any geometry replacement; its save/restore is NOT VERIFIED here.

## Implemented data and interfaces

| File | Actual implementation |
| --- | --- |
| `src/ReplicatedStorage/Shared/Config/TowerFloorConfig.luau` | Immutable 50-record floor catalog, ten five-floor groups, unique floor names/layout/environment identifiers, unlocked records, biome encounter references, bosses only on 5/10/.../50, provisional difficulty/reward curves. `Version=1`. |
| same module | `IsFloorId(value)`, `Get(floorId)`, `GetAdjacent(floorId, direction)` where direction is -1/+1, and `GetEnemyStats(floorId, enemyId)`. Invalid inputs return false/nil without coercion or clamping. Enemy stats require actual encounter membership. Hub ID 0 is a context, not a floor record. |
| `src/ReplicatedStorage/Shared/Config/MobCatalog.luau` | Immutable ordered Biomes, 40 proposed enemy Entries (20 regular, 10 elite, 10 bosses), `Get(id)`, `SchemaVersion=1`. Anatomy/locomotion, proposed bounds/rig families, timing/impact contracts, animation slots, planned source paths. |
| same module | Models, rigs/pivots/contact, editable sources, animations, FX/audio are MISSING. Attack range/shape/target/damage/warning/projectile tuning is explicitly MISSING. Planned template/source paths are destinations, not supplied assets. |
| `TOWER_CONTRACTS.md` | Contract v1 defines independent player/squad states, one existing roster, transitions, validation/rate limits, readiness/rollback, presence, room pins/retirement, cargo/private extraction, packet v2 and action/lifecycle reconciliation. This is a documented interface; TowerFloorService/TowerRoomBuilder/TowerController and remotes do not exist yet. |
| `tests/tower.spec.luau` | Nine focused requirement/data checks, including invalid inputs, encounter membership, boss placement, manifest honesty, numeric progression, immutability, and current starter formula anchors. |
| `tests/run.ps1`, `tests/roblox-module-shim.luau` | Runs both suites against unchanged production module bodies. Added the existing ArtifactCatalog dependency and its Color3.fromHex constructor to fix the old loader's missing dependency; generated bundle now uses writable TEMP rather than the CLI installation directory. |

No existing gameplay source was modified. Existing APIs and proposed APIs are separated in [the contracts](TOWER_CONTRACTS.md). Independent assignment is a chosen implementation default for later parts; it has not changed current player-follow behavior. Content names and roster counts remain proposed defaults.

## Executed checks

Command from `C:\Projects\infinite-tower`:

```powershell
.\tests\run.ps1 -LuauDirectory 'C:\Users\msi\AppData\Local\Temp\infinite-tower-luau-0.743'
```

The final run also used `Tee-Object` to capture its actual output in the local recovery directory. Exit code 0. Production files compile in their original form before any test-loader wrapping. Relevant actual output:

```text
Compiled 20 KLOC into 601 KB bytecode (read 0.03s, parse 0.02s, compile 0.04s)
Pit regression tests: 52 passed, 0 failed
Tower foundation tests: 9 passed, 0 failed
```

Full output: [Part 1 test evidence](evidence/PART_1_TEST_OUTPUT.txt). `git diff --check` also passed. Native Studio compilation/execution of the new modules, a Rojo build/sync, multiplayer, visuals, mobile budgets, published animation access, and gameplay behavior of the proposed contracts are **NOT VERIFIED**. They are not substituted by the CLI data checks.

The tower tests independently check all 50 unlocked IDs, ten complete groups, ten distinct correctly placed bosses, every encounter's catalog membership, unique declared layout/environment records, 40 explicit missing-asset manifests, attack timeline consistency/cancellation policy, invalid destinations, adjacent-floor boundaries, finite/nonnegative scaling, and monotone role stats. These checks validate data references, not built rooms or finished art.

## Provisional balance evidence

The test executes existing HeroCatalog, StatFormulas, and ArtifactCatalog formulas using the default deployed Han (quality 1.05) and Jenna (quality 1), level 1, Common 1-star starters, no imprints/pact/overdrive. Results: Han 315 HP/61 ATK/75.4 formula DPS; Jenna 210 HP/54 ATK/70.9 formula DPS; combined 146.3 DPS.

Configurable per-floor curves: HP `1.08^(floor-1)`, damage `1.045^(floor-1)`, gold/XP `1.055^(floor-1)`. Base regular stats 850 HP/18 ATK/80 gold align with the current crawler. Elite base 2,200/35/210 and boss base 12,000/55/800 are provisional inputs, not replacements for the current global boss configuration.

| Floor | Preview enemy | HP | ATK | Gold | XP | HP / starter formula DPS (seconds) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | Moss Crawler | 850 | 18 | 80 | 20 | 5.8 |
| 5 | Mossbound Guardian | 16,326 | 66 | 991 | 248 | 111.6 |
| 25 | Frostbound King | 76,094 | 158 | 2,892 | 723 | 520.1 |
| 50 | Crimson Overlord | 521,129 | 475 | 11,027 | 2,757 | 3,562.1 |

These are analytical comparisons, not encounter TTK or playtested balance. They exclude the full room composition, incoming damage, movement, the 5 Hz simulation, stamina, higher-level/promoted heroes, and artifact progression. Direct access to floor 50 does not promise the starter roster can clear it. Later tuning must measure viable full squads and may change these provisional curves.

## Exact next starting point

Follow-up during Part 2 on 2026-10-21: all 52 Pit and nine foundation CLI tests were re-run successfully before implementation. MobCatalog and TowerFloorConfig were then installed in the matching Studio place, and the complete nine-test tower foundation suite passed using native require/Roblox data types. Both catalog sources match their repository files in the final Part 2 source/Studio comparison. These follow-up checks supersede the historical native-module NOT VERIFIED note above; final enemy art/animation quality remains unverified and missing as recorded.

Begin Part 2 by reading this record and TOWER_CONTRACTS v1. Review the 16 source/Studio differences before synchronizing, preserve a native place/model snapshot before replacing traversal, and implement the limited hub/1/5/50 route with encounters disabled. Introduce TowerFloorService and TowerRoomBuilder, explicit context/safety/cargo transfer, and the v2 encoder/decoder together. Do not send off-map entities through the old clamped world-coordinate packets or let radius >=460 bank/recover them.

Part 2 must test actual readiness rollback, live HP/cargo changes during preparation, independent assignment without changing owner view, reliable lifecycle bootstrap/despawn reconciliation, >255 relevant entities, floor isolation, respawn/disconnect, and private-pad validation. New encounters and authored enemy presentation remain Part 3 work; full content remains Part 4. Existing source/Studio drift and missing assets are recorded follow-up obligations, not reasons to overwrite user work or claim later gates passed.
