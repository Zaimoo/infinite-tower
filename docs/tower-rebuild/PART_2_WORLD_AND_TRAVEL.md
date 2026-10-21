# Part 2 of 5: Hub, isolated rooms, travel, and replication

Implementation status: VERIFIED for the Part 2 fixture/transport gate. New encounters remain disabled; finished environments and enemy content are not supplied by this part. See [executed verification and handoff](PART_2_VERIFICATION.md).

Read [the master requirements](TOWER_REBUILD_PLAN.md), [Part 1](PART_1_FOUNDATION.md), and its completed handoff. Start only after the Part 1 gate is verified.

## Scope

1. Implement TowerFloorService and TowerRoomBuilder against the recorded contracts. Build a development route through hub, floors 1 and 5, and a floor-50 probe. Provide generic on-demand fixture rooms for other valid floor IDs needed by selection or Previous/Next tests, such as 2, 4, 6, and 49. Label all unfinished room art as development fixtures. All 50 destination IDs already exist in the catalog; complete content belongs to Part 4.
2. Connect usable hub entrances to a minimal floor selector. Build safe landing/travel areas, floor bounds and recovery, Previous/Next/Hub controls, and deterministic room origins. Separate rooms visually from the hub and one another. Preserve the tower exterior, island plots, and bridge approaches.
3. Preserve a recoverable snapshot before replacing the old traversal integration on the test route. Avoid simultaneous legacy and new tower spawners. Keep new floor encounters disabled until Part 3 verifies them.
4. Implement visit/assign/recall state plumbing, validated requests, membership/presence summaries, and safe transfer of existing deployed hero state. Player location and assigned squad destination must remain distinct. Part 3 adds autonomous floor combat.
5. Change server packet encoding and client decoding/rendering together. Use the agreed room-local coordinates and context identity, remove global 255-entity truncation, scope snapshots/metadata/effects to relevant viewers, and clear stale rigs on travel. Carry current action/lifecycle data in the protocol even if its playback is completed in Part 3.
6. Wait for destination readiness with bounded failure recovery, reset interpolation/velocity, and retain the previous valid location if transfer fails. Reject stale packets from prior rooms/generations. Local environment changes must not overwrite every player's Lighting.
7. Replace radial safe-zone banking/recovery before testing off-map entities. Apply FloorId checks to existing targeting, AoEs, retaliation, loot pickup, and reward attribution paths. Preserve cargo/relic transfer and private-pad extraction. Do not restore HP or stamina during travel.
8. Implement room retention and cleanup foundations: players, assigned squads, and live loot keep a room active. Preserve authoritative boss/reward state according to the Part 1 contract. Exercise basic respawn/disconnect membership cleanup.

## Relevant implementation areas

TowerFloorService, TowerRoomBuilder, TowerController, TowerSpawnLayout, TowerTraversalSetup, TowerBuilder, BridgeBuilder, CombatSimulation, EntityRenderer, PlotManager, and RelicService. Adapt names to the verified Part 1 interfaces; document deviations.

## Scope boundary

Use labeled entity fixtures or existing templates for transfer/network checks. They are not finished mobs. Do not build the remaining biome art or advertise the test route as the completed 50-floor experience.

## Verification gate

- Hub -> 1 -> 5 -> 50 -> Hub works through the minimal test UI; direct floor-50 coordinates render correctly on both clients.
- Previous/Next reaches the correct adjacent fixture room; Previous is disabled on 1 and Next on 50. Fixture availability must not introduce a progression lock. Part 4 repeats this check across finished content.
- Rooms cannot be seen from the hub/neighbors at normal player camera positions. Landing surfaces and floor-bound recovery work.
- Two viewers receive correct room membership/presence. Reassignment/recall does not duplicate heroes, and owner travel preserves the chosen assignment behavior.
- Existing interaction paths reject cross-floor targets/pickups/AoEs. Repeat with actual new enemies in Part 3.
- Off-map coordinates never trigger automatic banking/recovery. Cargo/relic transfer preserves counts and ownership; extraction still requires its intended location.
- Old-room packets cannot recreate stale rigs/effects. A test above 255 relevant entities is not silently truncated; record actual rendering/network results and fixture cleanup.
- Invalid destinations, repeated requests, failed readiness, respawn, and disconnect leave a valid character location and accurate membership.
- Compile touched production scripts and record the actual Studio/multiplayer checks. Mark checks requiring unavailable clients/tools NOT VERIFIED.

## Handoff record to complete during execution

- Status: VERIFIED (fixture/transport scope).
- Part 1 gate and contract version consumed: re-ran 52 Pit and nine foundation CLI tests, then all nine tower foundation tests against native Studio modules before Part 2. Contract document v1 and binary packet v2 consumed.
- Actual changed files, protocol version, and source/Studio sync: 11 Part 2 production files; both Part 1 catalogs also installed in Studio. All 13 mapped scripts match by LF-normalized UTF-8 byte count and DJB2. See PART_2_SOURCE_STUDIO.json.
- Checks/results, screenshots, and fixture cleanup: 73 CLI tests; six live client checks; ten server checks; six two-client checks; additional AoE, drop-retention, and owned-pad probes; actual 302-entity rendering; mouse-driven hub/1/5/50/hub route; iPhone landscape layout inspection. Evidence is linked in PART_2_VERIFICATION.md. Temporary multiplayer scripts and stress entities removed; Studio stopped and default viewport restored.
- Unfinished fixture rooms/assets and known issues: all room art remains DEVELOPMENT_FIXTURE; no new mobs, authored attacks, animations, audio, or final mobile performance claims. Part 2 uses atomic full reliable roster cuts instead of incremental lifecycle deltas; TowerAction is reserved for Part 3. Existing unrelated source/Studio drift is retained and documented.
- Next starting point: Part 3, using PART_2_VERIFICATION.md and its explicit protocol/retention boundaries. The user's revised Part 3 gate is working combat and basic feedback; final art/animation polish is deferred to its separate sprint.

## Suggested execution prompt

Implement only Part 2 of the tower rebuild using the verified Part 1 handoff. Complete the limited hub/room travel route, matching server/client replication, presence plumbing, and cargo/isolation safeguards. Keep new floor encounters disabled. Record actual verification evidence and remaining fixtures in this handoff; do not begin Part 3.
