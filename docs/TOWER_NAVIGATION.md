# Tower traversal and hero navigation

Current milestone: Parts 1–3 are verified, with working combat on floors 1 and 5. Animation/art polish and Parts 4–5 are deferred. Start with the [tower documentation index](tower-rebuild/README.md) and [Part 3 verification](tower-rebuild/PART_3_VERIFICATION.md) for current behavior.

Historical traversal-v3 record: the 18-floor ascent and 14-byte packet format described below have been superseded by the isolated-room Part 2 implementation. Current travel, room-local v2 replication, safety, recovery, and source/Studio evidence are documented in [Part 2 verification](tower-rebuild/PART_2_VERIFICATION.md). The old traversal module/geometry remain recoverable; legacy tower spawners are disabled.

`Core/TowerTraversalSetup.server.luau` applies `TowerTraversal` to the baked CentralCrimsonTower and to replacement tower models. The original core and ledge parts remain as dimension references for `TowerSpawnLayout`; hollow masonry walls and separate physical platforms replace their solid cylinders. Each of the 18 levels has a quarter-turn ascent ramp, a landing, a stairwell opening with headroom, and an uninterrupted inner walking strip. The base entrance remains open.

`Core/HeroNavigation.luau` keeps heroes as lightweight server tables. It computes asynchronous Roblox navigation paths (maximum three simultaneous computations, a one-second retry interval per hero), follows waypoints, and checks every movement substep for body clearance, walkable ground, and supported edges. Hero sweeps prevent crossing through squadmates. Player bodies, visual rigs, loot, and display models are excluded from terrain queries. Recall uses a supported formation position on the player's current floor. Attacks require line of sight and compatible height; boss pulls respect ground and collision.

`CombatSimulation` snapshots append signed, quantized Y at byte offset 12. Records are 14 bytes, with the existing five-byte header. Snapshots split into batches of at most 64 entities (901 bytes before transport encoding), preserving the 5 Hz simulation. `EntityRenderer` uses authoritative Y, retains legacy 12-byte packet decoding, and snaps long recall distances rather than interpolating through scenery. The existing hero rig offsets and tower enemy placements are retained.

## Verification

Validated in a Studio server playtest:

- All 3,456 platform sections have raycast support.
- 576 sequential traversal samples cover every ramp, including upper-floor headroom.
- A complete computed route climbs from the base to floor 1 without cutting through the tower.
- Heroes route around a solid wall and refuse to walk into unsupported space.
- The player stands on lower, middle, and top platforms, and a solid tower wall blocks walking through it.
- Production Luau compiles; the existing 51 Pit regression tests pass.

Gameplay QA should also cover two squads meeting on a narrow path, following a moving player through the base entrance, recalling on each floor, and approaching enemies on different floors. Test with the baked tower present; these sources add traversal to that geometry rather than generating the tower itself.
