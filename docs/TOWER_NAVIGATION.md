# Tower Navigation & Squad Movement Architecture

This document defines the server-authoritative navigation contract, connector topology, active floor-run policy, assigned-squad policy, and client presentation rules for Infinite Tower.

## 1. Architecture Overview

Infinite Tower uses **one shared server-authoritative navigation solver** (`HeroNavigation.luau`) backed by **pure connector topology** (`TowerNavigationGraph.luau`) and **separate destination policies** (`SquadMovement.luau`) for active floor runs and assigned squads. Enemy AI (`TowerEncounterRuntime.luau`) shares `HeroNavigation` for patrol, chase, and home-return movement.

| Module | Responsibility |
| --- | --- |
| `src/ReplicatedStorage/Shared/Config/TowerLayout.luau` | Authored platform bounds, connector IDs, usable widths, flat landing extents, slope/stair bounds, and clearance lanes for all 5 floor variants. |
| `src/ServerScriptService/Core/TowerRoomBuilder.luau` | Constructs terraces, full-width flat landings, flared approaches, flush sloped decks/stairs, tapered curbs, and chasm return ramps. |
| `src/ServerScriptService/Core/TowerPropClearance.luau` | Enforces clear walkways, landing footprints, and grounded prop rules across all 50 biome floors. |
| `src/ServerScriptService/Core/TowerNavigationGraph.luau` | Pure topology graph: platform/connector location (`Locate`), shortest connector routes (`Route`), directed mid-connector progress preservation, and route cost (`Remaining`). |
| `src/ServerScriptService/Core/HeroNavigation.luau` | Feet-coordinate movement solver (`Step`), ground/clearance sweeps, friendly/prop avoidance, bounded async `PathfindingService` queue (`MAX_IN_FLIGHT = 6`), and signed-progress recovery. |
| `src/ServerScriptService/Combat/SquadMovement.luau` | Active floor-run trail/formation policy (`UpdateMaster`, `PlanActiveFollow`) and assigned-squad objective/regroup/target-failure policy (`SelectAssignedAnchor`, `PlanAssignedRegroup`, `HandleCombatMoveOutcome`). |
| `src/ServerScriptService/Combat/HeroCombatMovement.luau` | Pure fight positioning for a hero with a target: telegraph evasion, ranged kiting and spreading, melee ring slots (§6). |
| `src/ServerScriptService/Combat/HeroTargeting.luau` | Per-tick combat target retention, focus priority, squad assist, connector `RouteCost` scoring, and generation-scoped unreachable target exclusion. |
| `src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau` | 60 FPS visual interpolation of 5 Hz server snapshots with ramp/landing support clamping and distinct teleport snapping. |

## 2. Shared Connector Contract & Physical Joins (`TowerLayout` / `TowerRoomBuilder`)

1. **Connector Metadata:** Every link in `TowerLayout` defines:
   - Stable `Id` (`From .. ">" .. To`), unit direction (`DX`, `DZ`), `Width`, and `UsableWidth` (`Width - 3.2`).
   - Full-width flat landings at both ends (`StartLanding`, `EndLanding`, `LandingWidth = Width + 8`), deck endpoints (`DeckStart`, `DeckEnd`), and slope/stair profile (`MaxSlopeDegrees <= 15`, stair rise `<= 1.0` stud).
2. **Flush Landings & Flares:**
   - Inclined decks terminate outside the upper terrace's full shoulder footprint; flat landings bridge flush into the terrace at matching top-surface elevation.
   - Curbs stop 2 studs inside the sloped deck (`DeckLength - 4`), leaving landing approaches unobstructed across the full usable width.
   - Basin return ramps rise from the chasm floor (`Bottom - 4`) with matching top/bottom landings.

## 3. Shared Navigation Solver & Recovery (`TowerNavigationGraph` / `HeroNavigation`)

1. **Feet-Coordinate Convention:** All callers pass and receive ground-level feet positions.
2. **Height-Aware Connector Membership & Progress Preservation:**
   - `TowerNavigationGraph.Locate` classifies positions onto connectors only when within `UsableWidth * 0.5 + 1.5` and within 4.5 studs of the interpolated ramp elevation (`AY + (BY - AY) * t`), preventing chasm positions under bridges from false-matching overhead connectors.
   - When a moving goal triggers a route refresh while an actor is already on a connector, `TowerNavigationGraph.Route` preserves the current connector's forward progress (`t`) instead of emitting the entrance waypoint behind the actor.
3. **Structured Step Outcome & Signed-Progress Recovery:**
   - `HeroNavigation.Step` returns `{ Position, Consumed, Remaining, Status, BlockReason, RouteChanged }`, where `Status` is `"MOVING" | "ARRIVED" | "BLOCKED" | "REPATH" | "UNREACHABLE"`.
   - Recovery tracks signed route progress (`Remaining` reduction or forward displacement toward the goal). Unproductive sideways/backward shuffling does not reset the timer:
     - `>= 0.45 s` blocked by an obstacle triggers a short supported lateral/backward escape step (`EscapeRemaining`).
     - `>= 1.0 s` without net progress invalidates the cached route and requests a fresh path (`Status = "REPATH"`).
     - `>= 2.0 s` without net progress ignores temporary friendly avoidance so congested ramps can clear.
     - `>= 3.0 s` without net progress reports `Status = "UNREACHABLE"` so the destination policy can switch attack positions or exclude the target.
   - Ordinary follow lag never triggers a distance or stuck teleport; only explicit Master Recall (`E`), room transitions, and hard vertical safety recovery (`> 45` studs vertical delta) relocate heroes.

## 4. Active Floor-Run Destination Policy (`SquadMovement`)

1. **Bounded Supported Player Trail (`SquadMovement.UpdateMaster`):**
   - Samples supported Master positions into a bounded ring buffer (`MAX_TRAIL_POINTS = 48`), annotating each sample with `LocationKey`, `ConnectorId`, `UsableWidth`, forward tangent, and `WalkableFromPrev`.
   - Airborne jump frames are not recorded as unsupported mid-air points; when the Master lands across a chasm that fails `CanWalk`, the landing sample is marked `WalkableFromPrev = false`.
   - Teleports (`> 36` studs in one tick) and lifecycle changes (`FloorId`, `RoomGeneration`, `Assigned`, Recall, Respawn) reset the trail cleanly.
2. **Forward Lookahead & Graph Fallback (`SquadMovement.PlanActiveFollow`):**
   - Each hero maintains a monotonic `CursorSeq` along the Master's trail, advancing past reached samples and skipping obsolete U-turn loops on the same surface.
   - Heroes shortcut to the furthest walkable trail sample ahead that passes `CanShortcut` and elevation checks (`<= 4.5` studs), or fall back to the connector graph when reaching a jumped gap (`UseGraphFallback = true`).
   - When leaving combat (`SquadMovement.MarkCombat`), heroes rejoin a forward walkable trail sample rather than returning to an obsolete ramp entrance.
3. **Width-Aware Formation Slots (`SquadMovement.ResolveSlotGoal`):**
   - Slots `1..5` use deterministic lateral/trailing offsets that compress inside a connector's `UsableWidth` on ramps/stairs and expand on open platforms, with progressive narrowing (`0.65x`, `0.35x`, `0.0x`) if a shoulder lacks ground support.
   - Sprint and catch-up speeds scale from `RouteLag` (distance along the remaining trail excluding intentional formation spacing).

## 5. Assigned-Squad Destination Policy (`SquadMovement` / `HeroTargeting`)

1. **Per-Tick Engagement & Regroup Anchor (`SquadMovement.SelectAssignedAnchor`):**
   - Computed once per squad tick and cached for all 5 heroes:
     1. Prioritizes `FocusedTargetNetId` if eligible.
     2. Retains the squad's current `AssignedObjectiveNetId` while alive, eligible, and matching `EntityGeneration`.
     3. Adopts a valid target held by an active non-stranded squadmate in deterministic slot order (`SlotIndex 1..5`).
     4. Computes a non-dragged reference position from the largest platform/connector cluster of healthy heroes (excluding `UNREACHABLE` / `REPATH` heroes so a stranded hero cannot drag the squad anchor backward).
     5. Selects the next eligible mob with the lowest `SquadMovement.RouteCost` across the connector graph.
   - Regrouping uses the nearest landing/platform associated with the active engagement (`RegroupAnchor`) and operates at hero base speed independently of the owner's sprint state or physical location.
2. **Alternative Attack Position & Generation-Scoped Target Exclusion (`SquadMovement.HandleCombatMoveOutcome`):**
   - When `MOVE_TO_TARGET` reports `UNREACHABLE`, `SquadMovement.FindAlternativeAttackPosition` searches supported attack positions around the target within `hero.AttackRange` that satisfy `CanAttack`.
   - If an alternative position exists, the hero retries once toward `AlternativeAttackGoal`; if that also fails (or none exists), `SquadMovement.RejectTarget` records a 5-second exclusion scoped to `(NetId, EntityGeneration, FloorId, RoomGeneration)` and returns the hero to `FOLLOW_MASTER`.

## 6. Combat Movement (`HeroCombatMovement` / `CombatSimulation.stepCombatManeuver`)

Destination policy for a hero that already has a target. It follows the same split as the rest of this document: the policy is pure, the shared solver moves the hero.

1. **Plan (`HeroCombatMovement.Plan`):** returns at most one manoeuvre: `EVADE` (leave an enemy telegraph), `KITE` (ranged hero backs off a mob that closed in), `FLANK` (melee ring slot; Strikers go for the back, Vanguards guard the backline) or `SPREAD` (ranged heroes unstack). Tunables are constants on the module; behaviour and numbers are in GDD §4.5.
2. **Validate:** `stepCombatManeuver` resolves the goal with `HeroNavigation.PlaceOnGround` (ground support and a clear straight walk), rejects safe zones, and for positioning goals requires the target to stay inside `AttackRange` with `CanAttack` line of sight. A rejected goal backs off for 0.3–0.5 s before the next attempt.
3. **Walk:** `HeroNavigation.Step` moves the hero, so corridor limits, friendly avoidance and recovery all apply. A blocked or unreachable positioning goal is dropped; a blocked evade holds where it got to.
4. **Timing:** manoeuvres run only after the hero's blow is released (`CastLockUntil`, set in `performHeroAttack`). An evading hero does not attack and its swing timer keeps running; once clear it reports `HOLD` and waits for the telegraph to land before approaching again.
5. **Inputs:** `TowerEncounterRuntime:Threats(floorId, roomGeneration)` lists wind-ups in world space with time to impact; `combatRoomContext` caches those and the room's live mobs once per tick.

### Solver query cost

- `HeroNavigation` keeps one `RaycastParams` per collision group and rebuilds them when the exclusion list changes, instead of allocating one per ground or body query.
- `HeroNavigation.Step` gathers same-room actors within reach once per step; avoidance substeps scan that list instead of every actor on the server.
- `TowerNavigationGraph.new` indexes connectors by id (`LinkById`).

## 7. Verification & Review Index

- Implementation plan: [docs/tower-movement-reliability-plan.md](tower-movement-reliability-plan.md)
- Phase 0 baseline evidence: [docs/reviews/tower-movement/2026-11-05/README.md](reviews/tower-movement/2026-11-05/README.md)
- Phase 1 geometry review: [docs/reviews/tower-movement/PHASE_1.md](reviews/tower-movement/PHASE_1.md)
- Phase 2 shared solver review: [docs/reviews/tower-movement/PHASE_2.md](reviews/tower-movement/PHASE_2.md)
- Phase 3 active policy review: [docs/reviews/tower-movement/PHASE_3.md](reviews/tower-movement/PHASE_3.md)
- Phase 4 assigned policy review: [docs/reviews/tower-movement/PHASE_4.md](reviews/tower-movement/PHASE_4.md)
- Phase 5 presentation & final review: [docs/reviews/tower-movement/PHASE_5.md](reviews/tower-movement/PHASE_5.md)
