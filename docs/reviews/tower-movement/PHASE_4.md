# Phase 4 Review — Assigned-Squad Destination Policy

## Scope Completed
- Extended `src/ServerScriptService/Combat/SquadMovement.luau` with assigned-squad destination and target-failure policy:
  - `SquadMovement.SelectAssignedAnchor`: computes and caches the squad engagement objective and regroup anchor once per squad tick, prioritizes `FocusedTargetNetId`, retains the active engagement objective while valid, adopts active squadmate targets in deterministic slot order, clusters healthy heroes by platform/connector so stranded/recovering heroes cannot drag the anchor backward, and scores candidate objectives by `TowerNavigationGraph` route cost (`SquadMovement.RouteCost`) instead of straight-line Euclidean distance across chasms.
  - `SquadMovement.BuildAssignedAssistList`: constructs a deterministic slot-ordered assist target list headed by the squad's chosen objective.
  - `SquadMovement.PlanAssignedRegroup`: computes per-slot regroup targets on the engagement landing/platform independently of the owner's sprint state or physical location.
  - `SquadMovement.FindAlternativeAttackPosition`, `SquadMovement.RejectTarget`, and `SquadMovement.HandleCombatMoveOutcome`: attempts an alternative supported attack position within the hero's `AttackRange` with valid line-of-sight before applying generation-scoped target exclusion (`NavigationRejectedTargets`).
- Updated `src/ServerScriptService/Combat/HeroTargeting.luau` to accept an optional `RouteCost` callback in `HeroTargeting.Context` for assigned-mode target acquisition.
- Integrated `SelectAssignedAnchor`, `BuildAssignedAssistList`, `PlanAssignedRegroup`, `RouteCost`, and `HandleCombatMoveOutcome` into `src/ServerScriptService/Combat/CombatSimulation.server.luau`.
- Added unit test cases in `tests/squad-movement.spec.luau` and `tests/hero-targeting.spec.luau`.

## Verification Status
- Verified project build integrity via `rojo build -o build.rbxl`.
- Per user instruction (`"just implement, dont test."`), live Studio playtest loops and CLI test execution were skipped for Phase 4. Multi-camp stationed combat cycles in Studio remain unverified.
