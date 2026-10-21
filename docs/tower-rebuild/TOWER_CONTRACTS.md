# Tower foundation contracts v1

Status: proposed implementation contract established in Part 1. This document does not implement a service, create remotes, change the existing combat protocol, supply assets, or enable encounters. The future binary protocol is **version 2**; contract-document version 1 and packet version 2 are different identifiers. See [Part 1](PART_1_FOUNDATION.md) for implementation and verification status.

Part 2 follow-up: the transport service, room builder, selector, safe/cargo integration, and v2 codec now exist and have source/Studio evidence. See [Part 2 verification](PART_2_VERIFICATION.md) for implemented interfaces and deliberate lifecycle/action boundaries. The paragraphs below preserve the full target contract; they do not imply Part 3 attacks or final assets are implemented.

Independent squad assignment is the chosen implementation default from the master plan, not an additional user-confirmed requirement. Biome/content names, attack timings, request limits, and retention timings below are provisional configuration defaults. All fifty floor IDs are available without payment, level, prior clear, boss kill, or unlock checks.

## Ownership and authoritative state

- `FloorId` is a finite integer: `0` identifies the hub, including existing plots; `1..50` identify playable floors. An absent value is never an alias for the hub.
- `PlayerLocation` records `{FloorId, RoomGeneration, LocationRevision, CharacterGeneration}`. It describes the committed character location, not a pending request or squad destination. Server-only world coordinates remain in the character/room state.
- `SquadAssignment` is either `nil` (follow the owner in the owner's committed context) or a floor ID `1..50` (remain on that shared floor independently). A separate `SquadContext` records the actual floor and room generation occupied by the deployed entities. An empty or wiped roster is not advertised as an active squad.
- One existing deployed roster per owner remains authoritative: profile heroes assigned to `SQUAD_SLOT_1` through `SQUAD_SLOT_5`, represented once by the existing combat entities. Assignment never creates a second roster. Profile ownership, coma, capacity, and facility restrictions remain authoritative.
- `SquadRevision` increments after a committed assignment, recall, roster change, or wipe. `CharacterGeneration` increments on character replacement. Revisions are server-issued integers, never client authority.
- Each room has shared player membership, squad membership, entity state, loot, encounter state, and a boss/reward ledger. Two players on the same floor see the same encounter; visiting a floor and assigning a squad are distinct memberships. Profiles and assignments remain session-only.

Floor equality, room generation equality, and live membership are prerequisites for damage, aggro, targeting, retaliation, pickup, AoE/fumble, and reward participation. Distance, raycasts, or height are additional checks; none substitutes for context identity. Safe-zone checks apply to both participants where relevant. The owner's remote viewing location cannot grant participation to an absent squad.

Validate participation context when the qualifying action/hit is recorded. Retain that qualified contribution in the encounter ledger; later owner travel does not erase earned participation or require the owner to view the room at payout time. A payout still validates the retained contributor identity and its once-only claim.

## State transitions

Each owner has one serialized transition lane shared by character travel, assignment, recall, roster rebuild, and recovery. Validate the committed revisions again immediately before commit. Build/readiness work may yield; authoritative membership changes do not yield midway. A transaction prepares its destination and reversible cargo/entity state before removing source membership.

Preparation does not pause source combat, stamina, cooldowns, loot expiry, pickup, or deliberate actions for up to eight seconds. Reserve the destination and transition identity, not a frozen historical health/cargo snapshot. Capture current runtime state in the non-yielding commit and revalidate it there. Death, wipe, incompatible roster/cargo change, expiry, or a changed character cancels or re-prepares the operation. Rollback preserves current valid source state and never rewinds damage/timers or recreates expired/spent cargo from preparation-time data.

| Trigger | Result on successful commit | Failure/cancellation |
| --- | --- | --- |
| Visit floor | Move character to the server-selected arrival area. A following squad transfers with the owner; an assigned squad remains on its assigned floor. No heal, stamina reset, reward, or banking. | Keep previous committed location, assignment, HP, stamina, cargo, and membership. |
| Return to hub | Same travel semantics, to a server-selected safe hub arrival outside extraction/bank triggers. Assigned squad stays assigned. | Same rollback as visit. |
| Assign squad | Move the existing eligible roster to the destination safe formation anchor; set assignment and squad context; cancel old targets/actions/navigation. Owner stays in place. Same assignment is an idempotent success. | No duplicate/newly healed entities; preserve prior assignment/context and roster. |
| Owner visits while assigned | Change only player location and any player-carried item context. Assigned heroes keep position, health, stamina, cooldowns, and floor-local activity. | Previous player state remains valid. |
| Recall | Clear assignment and transfer surviving deployed heroes to owner context/formation. Preserve the existing six-second recall cooldown and two-second pacify. Clear targets, hostile focus, actions, and navigation. HP, coma, stamina, and cargo do not reset. | Do not consume cooldown on preparation failure. No hero resurrection or change to owner location. |
| Roster/facility change | Reconcile UUIDs against profile under the same lane. Remove ineligible entities once; retain eligible entities and their runtime state; add new eligible heroes at the current squad anchor. An empty roster clears assignment and active squad presence. | Reject stale roster revision and retry from current profile; never restore a removed hero from stale work. |
| Individual coma | Use existing coma/infirmary progression, cancel action, remove entity and participation references once. Remaining heroes retain assignment. | No dead entity remains targetable or able to impact later. |
| Full wipe | Clear assignment/active squad membership, preserve infirmary/coma and field-looting lock. Spill/fumble player-held items at the player's committed location under existing ownership rules, even if owner and squad occupied different floors. Squad death drops stay on the squad's floor. | Serialize against travel; use the last valid context if character is unavailable. Never move items to a default origin. |
| Character death/respawn | Cancel pending travel first. Drop/fumble carried items once at the recorded last valid player location before replacing the character. PlotManager's existing plot respawn commits hub location. Following survivors reconcile to the new owner context; independently assigned survivors retain assignment. Wipe/coma and theft state are not cleared by travel. | Late Ready/commit from the old character generation is rejected. Recreate no cargo weld on the replacement character automatically. |
| Disconnect | Cancel pending work, remove viewer/player/squad memberships, remove deployed entities and stale targeting/participation references. Spill held cargo/relic once in the last valid context, release disconnected-owner pickup locks consistently with existing relic behavior, and keep the room while live drops remain. | No offline simulation or persistent assignment. Last location is server state, not client coordinates. |
| Reconnect | Create a new session profile/location using existing session-only behavior; bootstrap a new viewer context. | Never accept an earlier connection's Ready, presence subscription, or packet epoch. |

Recall requests from the new selector and existing E/WhistleCommand must converge on one implementation and cooldown; they cannot be two independent teleport paths. In Part 2 assignment is state/transfer plumbing with new encounters disabled. Part 3 supplies autonomous floor-local targeting and combat.

## Proposed server interface

`TowerFloorService` is a proposed server module, not an existing API. Proposed methods are `VisitFloor(player, floorId, request)`, `ReturnToHub(player, request)`, `AssignSquad(player, floorId, request)`, `Recall(player, request)`, and `GetPresence(player, request)`. Internal calls use the same validation/transition lane as remote calls. Helpers for membership, readiness, safe-zone lookup, cargo transfer, and room retention are private implementation details until implemented.

The proposed `ReplicatedStorage.Remotes.TowerRemotes` folder contains these reliable `RemoteEvent`s:

| Remote | Direction | Payload/purpose |
| --- | --- | --- |
| `Request` | Client -> server | `{ContractVersion=1, RequestId, Action, FloorId?, CharacterGeneration?, ExpectedLocationRevision?, ExpectedSquadRevision?}`. Actions: `VISIT`, `HUB`, `ASSIGN`, `RECALL`, `PRESENCE_SUBSCRIBE`, `PRESENCE_UNSUBSCRIBE`, `RESYNC`, `CANCEL`. CANCEL additionally supplies `CancelRequestId`. Mutating actions require the character generation and both expected revisions from Self; initial presence subscription does not. RESYNC supplies the committed context identity. |
| `Response` | Server -> requesting client | `{ContractVersion, RequestId, Status, ErrorCode?, RetryAfterSeconds?, LocationRevision, SquadRevision}`; status is `PENDING`, `COMMITTED`, `REJECTED`, or `CANCELED`. A successful no-op uses COMMITTED. |
| `Context` | Server -> client | `{ContractVersion, RequestId, Stage, ServerSessionId, FloorId, RoomGeneration, ViewEpoch, CharacterGeneration, Origin, Bounds, Arrival, ReadyToken?, ReadyDeadline?, LocationRevision}`. Stage `PREPARE` advertises pending data and includes readiness token/deadline; `COMMIT` changes current viewer context; `ABORT` invalidates prepared data. All spatial data is server-issued. |
| `Ready` | Client -> server | `{ContractVersion, RequestId, ReadyToken, ViewEpoch, CharacterGeneration, Result}` where Result is `READY` or `FAILED`. No coordinates or asset instance names are accepted as authority. |
| `Presence` | Server -> subscribed client | Full replacement `{ContractVersion, ServerSessionId, PresenceRevision, Floors, Self}`. Each floor lists separately `Visitors` and `Squads` using `{UserId, Username, DisplayName}`; squads also include roster size/revision. Self includes committed location, assignment, CharacterGeneration, LocationRevision, SquadRevision, and pending request ID. |

`Ready` confirms the client has requested destination streaming and prepared its view. The server independently verifies the room, supported arrival surface, bounds, character identity/health, and transition state. It never trusts Ready as proof of safe geometry or a valid destination. PREPARE may prefetch assets but does not switch current packet acceptance or visible membership. COMMIT switches the view, resets interpolation/velocity, clears old effects/rigs, and opens the committed bootstrap. ABORT discards prefetched state. Source state stays authoritative until commit.

Context/Ready exchanges apply only when the character changes viewer context (VISIT/HUB, including a following squad). ASSIGN and RECALL prepare server-side squad transfer against the same eight-second preparation budget, without requesting owner streaming or changing the owner's ViewEpoch. A successful squad-only transfer publishes Response and Self/presence revisions; it never sends a player Context COMMIT for the squad's destination. Revalidate destination room generation and roster/character revisions immediately before either kind of commit.

Validation and limits (provisional defaults):

- Reject malformed tables, unknown actions/fields, nonfinite numbers, noninteger IDs, floor IDs outside the catalog, and mismatched contract versions. Request IDs are printable ASCII strings of 1..64 characters. Reject client coordinates, currency, damage, hero stats, roster UUID lists, and reward claims. Assignment resolves the owner's roster on the server.
- Require a connected player, loaded profile, current character generation/revisions, and the appropriate live character/eligible roster. Recheck ownership and eligibility after preparation. Hub is valid for VISIT only through `HUB`; ASSIGN accepts only `1..50`.
- Shared Request budget: token bucket burst 4, refill 2 tokens/second per owner. Presence subscription and explicit resync additionally have a one-second minimum interval. Ready/CANCEL have a separate burst-4/refill-2 bucket so a rejected request flood cannot permanently block rollback. Responses do not cause recursive requests.
- One pending transition per owner. A different transition while busy receives `BUSY`; it does not silently cancel an earlier request. Explicit CANCEL cancels a still-pending request; a committed request returns its stored result. Timeout is eight seconds from PREPARE. Disconnect, character replacement, wipe, and incompatible roster changes invalidate pending work.
- Deduplicate before consuming transition resources: retain the last 64 terminal request results for 60 seconds per connection. An identical RequestId/payload replays its result; a reused ID with different content yields `REQUEST_ID_CONFLICT`. Exactly-once semantics apply within this bounded window; a retry after expiry must still be safe because destination/no-op and revision checks are authoritative. Never claim an old failed request committed merely because the character happens to be nearby.
- Keep the pending RequestId and canonical validated payload as well. An identical retry replays PENDING; changed content with that ID yields REQUEST_ID_CONFLICT. Perform this comparison before BUSY so network retries cannot accidentally start a second operation or be mistaken for a competing command. Limit canonical payload storage to the bounded accepted schema.
- Error codes: `BAD_REQUEST`, `VERSION_MISMATCH`, `INVALID_FLOOR`, `PROFILE_NOT_READY`, `CHARACTER_NOT_READY`, `NO_ELIGIBLE_SQUAD`, `STALE_REVISION`, `RATE_LIMITED`, `BUSY`, `REQUEST_ID_CONFLICT`, `RECALL_COOLDOWN`, `ROOM_UNAVAILABLE`, `READY_TIMEOUT`, `READY_FAILED`, `CANCELED`, `INTERNAL_ERROR`. Failed transitions return current committed revisions and preserve the source; internal details are logged server-side.

Presence subscriptions exist only while the selector is open, plus a lightweight self-state update after commits. A reconnect/new subscription receives a full snapshot. Revisions are monotonic within ServerSessionId; clients replace, never merge, older snapshots. Display names are presentation only; UserId is identity. Departures, wipe, reassignment, and disconnect publish the next revision. Selector viewing does not subscribe the client to remote floor combat or grant membership there.

## Room-local replication v2 (implementation in Part 2)

The existing world-coordinate protocol remains unchanged in Part 1. Encoder and decoder must switch together; v2 never infers compatibility from packet length. Unknown versions and malformed payloads are rejected with a bounded resync request. Legacy and v2 writers cannot feed the same decoder concurrently.

Context identity is `(ServerSessionId, FloorId, RoomGeneration, ViewEpoch)`. ServerSessionId is one random 128-bit server-lifetime identifier, represented as 32 hexadecimal characters in reliable messages and sixteen bytes in buffers. RoomGeneration changes whenever a room is rebuilt. ViewEpoch is server-issued per viewer and increments on every committed context replacement, including returning to the same floor. An ABORT invalidates its pending epoch. Epoch/generation exhaustion requires fresh session/context identity, not reuse.

Room origins are server-owned, deterministic for the current build, and transmitted in a reliable bootstrap keyed by context identity. `worldPosition = Origin + localPosition`. Entities, loot, telegraphs, targets, projectiles, and attack aim all use that same context; effects cannot silently fall back to world zero or another room origin. Hub entities use FloorId 0 and its explicitly defined origin.

The new reliable combat interfaces are proposed `TowerEntityState` (bootstrap, metadata upsert, despawn), `TowerAction` (start/cancel/death), and client `RESYNC` through TowerRemotes.Request. The proposed unreliable `TowerSnapshot` event carries only binary v2 snapshots. They must be created and connected together in Part 2. Old CombatRemotes remain necessary until each existing caller is migrated deliberately.

Reliable bootstrap contains the full context identity/origin, BootstrapRevision, complete live entity roster/metadata, current snapshot sequence, active actions with their original start times, and boss presentation state. Large bootstraps use indexed bounded chunks plus a reliable completion record; clients atomically replace the roster only after all chunks of the same revision arrive. Buffer at most two snapshots while awaiting that bootstrap; otherwise discard and request resync. Never create an identity from a snapshot alone.

Capture that roster/actions at a server `LifecycleRevision` cutline. Reliable upsert/despawn/action deltas after the cutline carry increasing lifecycle revisions and queue during chunk assembly. On COMPLETE, install the cutline state atomically and then apply queued newer deltas in order. Maintain generation-qualified despawn tombstones through the current context so an older upsert or delayed START cannot revive an identity. Bound the chunk/delta queue and preparation time; overflow or a missing revision abandons that bootstrap and requests a new one. Geometry generation, viewer epoch, and lifecycle revision are separate values.

Entity identity is `(ServerSessionId, FloorId, RoomGeneration, EntityId, EntityGeneration)`, where ID and generation are positive u32 values. Transfer, respawn, or reuse of an ID creates a new generation and reliable lifecycle record. All targets, hit ledgers, pending attacks, and metadata references use this qualified identity. NetId alone is insufficient. Despawn cancels actions and removes the live identity once; a separate bounded cosmetic death record may keep its visual alive without retaining authority.

Snapshots use little-endian primitives with this fixed layout:

| Header byte offset | Field | Type |
| --- | --- | --- |
| 0 | PacketVersion (2) | u8 |
| 1 | FloorId (0..50) | u8 |
| 2 | HeaderBytes (46) | u16 |
| 4 | ServerSessionId | 16 raw bytes |
| 20 | RoomGeneration | u32 |
| 24 | ViewEpoch | u32 |
| 28 | SnapshotSequence | u32 |
| 32 | ServerTime from Workspace:GetServerTimeNow() | f64 |
| 40 | BatchIndex (1-based) | u16 |
| 42 | BatchCount | u16 |
| 44 | EntityCount in this batch | u16 |

| Record byte offset | Field | Type |
| --- | --- | --- |
| 0 | EntityId | u32 |
| 4 | EntityGeneration | u32 |
| 8, 10, 12 | Local X, Y, Z multiplied by 10 and rounded | three i16 |
| 14 | Yaw, mapping -pi..pi to 0..255 | u8 |
| 15 | Presentation state enum defined by v2 codec | u8 |
| 16 | HP permille, 0..1000 | u16 |
| 18 | Stamina, 0..100 (nonheroes 100) | u8 |
| 19 | Flags: bit 0 hero, bit 1 overdrive, bit 2 pacified, bit 3 boss core exposed; other bits reserved zero | u8 |
| 20 | Current ActionSequence, 0 when no active action | u32 |

Record size is 24 bytes. Exact buffer length is `46 + EntityCount * 24`; zero-count heartbeat batches are valid. EntityCount has a hard ceiling of 64; the initial encoder uses **32 records per batch**, an 814-byte buffer, to retain remote payload headroom. Do not send 64 records merely because the field permits them. Verify actual remote payload limits and measured overhead before changing this default. BatchCount is at least one; BatchIndex must be in range. Every relevant live entity is scheduled across batches: no global 255-entity truncation. Bound total work per tick and report overload explicitly; do not hide active encounters by dropping later IDs.

All local XYZ components must be finite and within -3276.7..3276.7 studs before quantization. Geometry/room bounds must fit that envelope with margins. **Never clamp a position into the range.** An invalid entity is diagnosed, recovered to a validated local safe position or excluded with explicit lifecycle handling; it must not appear at a clamped wall. ServerTime is finite and uses the shared server clock, not os.clock() sent as a cross-machine timebase.

Each snapshot tick shares sequence/time across its batches. Track the most recent accepted sequence per entity; a late batch from an older tick may update an entity not yet seen at a newer tick but cannot rewind another entity. Duplicate batch/identity records are ignored. u32 sequence comparison uses `(incoming - previous) mod 2^32`: positive differences below 2^31 are newer, zero is duplicate, half-range or larger is stale/ambiguous and must not advance state. Resync before a viewer can remain disconnected for the ambiguous interval. Context identity comparisons happen before sequence comparisons.

Missing or reordered unreliable batches never mean death. Reliable roster/despawn defines existence; missing updates briefly hold/extrapolate within bounds, then freeze/fade while requesting a bounded resync. A local watchdog runs independently of receiving packets. Context COMMIT clears old rigs, selection IDs, attacks, effects, and interpolation; all old-context events are rejected even if their entity ID matches. Reconnecting viewers receive a new epoch and a complete bootstrap. Reliable metadata/despawn/action streams carry the same identity, epoch, and revision rules as snapshots.

## Authoritative actions and animation

An attack definition names its EnemyId, AttackId, animation slot, windup, impact/release offset, recovery duration, range/shape, telegraph, target rule, damage rule, and optional projectile model/speed/impact rule. All timing values are finite/nonnegative; impact/release cannot precede windup. Presentation recovery is not permission for an extra damage application.

In the implemented Part 1 manifest, `entry.Id` maps to EnemyId and `entry.Attacks[n].Id` maps to AttackId. Timings, attack kind, animation slot, and a proposed server impact rule exist as data. `Gameplay.Status=MISSING` lists range/shape, target/damage rules, warning geometry, and ranged speed/collision as still unauthored. These entries cannot execute attacks; Part 3 must supply and verify those fields before enabling encounters.

The server action record contains qualified actor/context identity, unique positive u32 ActionSequence, AttackId, target identity and/or local aim, `StartServerTime`, `WindupSeconds`, `ImpactOffsetSeconds`, `RecoverySeconds`, and `Status`. Ranged definitions explicitly state whether impact uses an authoritative simulated projectile or a scheduled validated hit; a cosmetic projectile never decides damage. Do not introduce invented asset IDs to fill missing presentation slots.

The reliable START event precedes scheduled damage and uses GetServerTimeNow() time. Server ticks validate actor alive, target alive/same context, range/shape, safety, and cancellation status before applying impact exactly once per action/target according to its definition. Death, despawn, transfer, leash reset, invalid target policy, or explicit cancellation cancels the action and sends CANCEL. Reward/death ledgers are independently idempotent. Client animation markers and Ready never grant damage, loot, or rewards.

Clients deduplicate by context/qualified actor/ActionSequence, seek into the original timeline on late arrival, and skip completed effects rather than restarting old windups. Bootstrap reconciles currently active actions. Snapshot ActionSequence indicates which reliable action is expected; missing action data triggers bounded resync, not invented hits. Cosmetic hit reactions do not cancel attack tracks unless the server records gameplay stagger. Death visuals use an explicit completion/timeout policy before cosmetic cleanup; authoritative death and rewards occur immediately and only once. A dead actor's delayed START cannot resurrect its pose or damage.

## Cargo, safety, and lifecycle

Travel prepares a transfer record holding the existing item identity, ownership/theft locks, amounts, expiry, weld/carrier, source context, and movement penalty. Commit moves character and its one carried item together, updates item context and weld once, and preserves counts/locks/expiry; rollback restores the same identity in the source. Concurrent pickup/drop/extract/wipe is serialized with this record. Assignment/recall moves heroes, not the owner's cargo. No travel path calls reward, banking, extraction, stamina recovery, or coma reset.

Floor equality is mandatory for pickup and all loot/reward attribution. Player cargo follows the player's committed location; physical death drops stay in the killing floor. Carried loot, dropped loot, relics, projectiles with pending impact, and pending transitions all pin their authoritative room until resolved. Disconnect/respawn must release or drop held items before destroying carrier references. Ground drops use a validated floor-local surface; failed raycasts cannot drop into a neighboring room or zero origin.

Replace world-radius safety before off-map integration. Server-authored safe zones consist of `{ZoneId, FloorId, RoomGeneration, LocalPolygonXZ, MinY, MaxY, CombatSafe, CanBankCargo, CanRecoverWipe}`. Polygon points and vertical bounds are finite and validated, boundary inclusion is deterministic, and server point-in-polygon plus height determines membership. Tags/visual markers can identify definitions but client-added attributes cannot confer safety. Room arrival zones have `CombatSafe=true`, `CanBankCargo=false`, `CanRecoverWipe=false`; hub bank/recovery zones are separately authored. Being far from world origin grants nothing. Travel arrival is outside deposit triggers, and a transfer suppresses extraction/banking until committed and the server observes a subsequent deliberate entry into the designated trigger.

Relics extract only at a real private pad in hub context whose authoritative plot owner equals the carrier UserId, with server distance/volume, live-character, carrier identity, no-transition, and once-only payout checks inside `ExtractOnPrivatePad`, not just its caller. Remove the current unowned-pad test exemption for production. Never award from a floor arrival area or the selector. Ordinary cargo banks only in an explicitly designated hub banking zone; the intended perimeter behavior is preserved through authored bounds rather than radius. Loot theft, lock timers, movement penalties, infirmary rules, and deliberate-command progression remain in force.

Rooms move through `ABSENT -> BUILDING -> READY -> RETIRING -> ABSENT`, with `FAILED` recording diagnosable build failures. BUILDING is not visitable. Players, nonempty assigned/following squads, live dropped/carried loot/relics, pending transfers, and pending impacts pin a room. Cancellation releases only its own reservation. RETIRING rechecks all pins immediately before destruction, and a new request cancels retirement or waits for a fresh generation.

Provisional empty-room retirement grace is 60 seconds. Retiring geometry does not reset authoritative encounter state. Keep per-floor boss identity/generation, alive/dead status, respawn deadline, payout-claimed ledger, and encounter seed/state for the whole server session. Rebuilding a room consumes that retained state; travel/retirement cannot respawn a defeated boss or repay contributors. Damage participation uses qualified entities and recorded command activity, not current viewer membership. No offline continuation is promised after server shutdown.

## Asset manifest boundary

The proposed pure-data MobCatalog links EnemyId to role/biome, model reference/status, rig family, anatomy, intended bounds/pivot/floor contact, locomotion mode, animation mappings, attack definitions, effects/audio references, and editable model/animation source paths. Each reference has explicit status `MISSING`, `UNVERIFIED`, or `VERIFIED`; no fabricated Roblox asset/animation IDs or fallback approvals. All proposed rebuilt enemy art, authored animation sets, effects/audio, and editable sources start **MISSING** until individually supplied and inspected. Existing templates do not establish finished quality or valid articulation.

Required slots are idle, anatomy-appropriate locomotion, basic attack, hit, death; elite special and boss signatures/awakening/phases add slots when their definitions require them. Missing required slots produce a diagnosable development validation error. The user revised Part 3 to accept the existing prototype visuals and deferred final art/animation quality to a separate sprint. Prototypes do not establish final visual approval. Published animation access, deformation, and foot contact require later evidence; readable warnings before authoritative damage remain a current combat requirement.

## Existing APIs and migration hazards rechecked in source

These are current APIs; proposed names above do not replace them in Part 1. Paths are relative to `src/`.

| Existing API/behavior | Current source | Integration obligation |
| --- | --- | --- |
| `_G.CombatSimulation.RebuildPlayerSquad(player)` and `RefreshPlayerHeroStats(player)` | `ServerScriptService/Combat/CombatSimulation.server.luau:275,297` | Preserve runtime health/cooldowns; reconcile roster under transition lane. |
| `WhistleCommand` codes 1/2; `FocusTarget` | same file:1179,1263 | Route recall through one cooldown; qualify targets and retaliation by context. |
| `DropCarriedLoot(player, openLoot?)`, exported `SpawnPhysicalLoot` and `CollectPhysicalLoot` | same file:435,1873 | Introduce context-aware cargo access/transfer; actual carry lives in private CarrierToHeldLoot, not Master.CarriedLoot. |
| `_G.RelicService.SpawnRelic`, `TryPickupRelic`, `DropCarriedRelic`, `FumbleRelicOnAoEHit`, `ExtractOnPrivatePad` | `ServerScriptService/ExtractionAndSocial/RelicService.server.luau:100,186,237,264,344` | Add floor identity, atomic carrier transfer, and validation inside extraction. |
| `HeroNavigation.Ground`, `PlaceNear`, `Step`, `Clear`, `CanAttack` | `ServerScriptService/Core/HeroNavigation.luau:39,96,124,86,172` | Keep collision support; clear stale paths on context change and prevent cross-context hero avoidance. |
| `ReplicationTick`, `EntityMetadataSync`, `BossTelegraph`, `CombatVFX` | combat file:18-24; `StarterPlayerScripts/Rendering/EntityRenderer.client.luau:16-20` | Migrate both ends together and migrate HUD/input global boss assumptions. |

Verified source hazards to resolve in Part 2 before off-map combat is enabled:

- Current SimHero/SimMob/MasterCombatState contain no floor/context (`CombatSimulation:71-136`). Heroes follow/leash to the owner, normally 65 studs or 150 for PvP and 15 vertically (`1554-1572`); auto-targeting centers on owner (`1588-1606`).
- The current snapshot writer caps all entities at 255, batches 64, writes world XYZ as clamped i16/10, and broadcasts globally (`1700-1755`). It sends os.clock() time; the decoder ignores it and infers twelve/fourteen-byte stride (`EntityRenderer:299-345`). ID allocation wraps at 60,000 without generation (`CombatSimulation:144-148`).
- Renderer stale cleanup is packet-driven (`EntityRenderer:381-390`), not an independent watchdog. Global metadata replacement and single WorldBoss state need context-specific bootstrap/cleanup.
- Banking/recovery uses radius >=460 (`CombatSimulation:1812-1866`); zone stamina uses radius (`241-252`); PvP safety checks only attacker radius (`1146-1176`). Horizontal AoEs can affect stacked rooms (`1388-1419,1470-1490`).
- Ordinary mob stepping lacks basic chase/attack; the nearby check actually tests players despite its hero/player comment (`1424-1495`). New encounters stay disabled in Part 2.
- Combat disconnect cleanup removes heroes but does not clear/drop private held cargo (`1775-1787`). Relic disconnect fumbles then releases owner lock (`RelicService:423-430`). Character replacement needs explicit cargo reconciliation.
- Relic extraction accepts OwnerUserId 0 as a test exemption in its heartbeat (`RelicService:401-407`), and direct extraction lacks ownership/distance validation (`344-358`).
- Mob snapshots encode phase as `10 + Phase` (`CombatSimulation:1730`), while procedural animation recognizes attack only as state 3 (`ReplicatedStorage/Assets/ArtPackVisuals.luau:179`). Renderer handles whistle VFX but not emitted HIT_SPARK (`EntityRenderer:458-479`). Authored mob action/death presentation remains Part 3 work.

Source inspection establishes these obligations, not runtime verification of the proposed contract. Part 2 must record actual encoder/decoder, cargo rollback, multiplayer, streaming, >255-entity, and stale-context checks; Part 3 must verify them again with real attacks and enemy assets.
