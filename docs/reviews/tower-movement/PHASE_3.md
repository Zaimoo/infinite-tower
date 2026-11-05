# Phase 3 Review — Active Floor-Run Destination Policy

## Scope Completed
- Added `src/ServerScriptService/Combat/SquadMovement.luau` with bounded server-sampled supported player trails (`MAX_TRAIL_POINTS = 48`), lifecycle/teleport resets, jump-gap detection with connector-graph fallback, forward trail lookahead, and width-aware formation slots that compress on ramps/stairs and expand on platforms.
- Preserved sprint/catch-up speed scaling with independent `RouteLag` measurement, combat disengagement forward trail rejoin (`MarkCombat`), focus/pacify behavior, and lifecycle cleanup across transfers, recalls, rebuilds, revives, duels, and respawns in `CombatSimulation.server.luau`.
- Refined `TowerNavigationGraph.luau` landing-to-ramp `onDeck` transitions and `HeroNavigation.luau` backward obstacle-escape clearing and friendly avoidance.
- Added unit coverage in `tests/squad-movement.spec.luau` and updated `tests/studio-tower-movement.luau`.
