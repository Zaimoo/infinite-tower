# Phase 2: shared navigation

Implemented on `codex/tower-movement-reliability`.

- Cached, height-aware connector routing preserves forward exits from mid-ramp positions. Moving destinations update the terminal waypoint instead of restarting at the entrance.
- Movement consumes its budget across waypoints, checks four foot-support corners and body clearance, enforces usable corridors, and uses elapsed time for airborne descent. Feet coordinates are explicit; existing root-based placement keeps a compatibility wrapper.
- Bounded FIFO path requests are deduplicated and invalidated by revision, floor, room/entity generation, and intent. Failed requests back off.
- Shared signed-progress recovery applies to follow and pursuit. Shuffling cannot reset it; route refresh starts after one second and unreachable is reported after three. Combat targets receive a five-second generation-scoped retry exclusion. Attacks pause recovery.
- Local passing uses stable actor priority and safe lateral movement. Scenery escape includes a short supported retreat before retrying forward movement.
- Removed distance/stuck follow teleports. Explicit recall remains. Active-run trail/regroup policy and assigned objective policy remain Phases 3 and 4.

Validation: the full CLI suite passed, including nine new navigation regressions and ten targeting tests. MCP ran isolated branch module copies because the reopened Studio production modules were not synced. All fourteen fixed connector directions passed, as did movement-budget, moving-terminal, edge-support, blocked-pursuit and clear-state checks. The lateral-steering iteration regrouped nine of ten sprint slots; the remaining slot was blocked by an ice spike beside a low snow mound. A directional probe confirmed a safe backward escape and the final change adds that bounded retreat. Repeated playtests were stopped at the user's request; the final retreat change has not been replayed.

These checks validate the shared core only. Full-width joins across all biomes, real assigned combat, head-on squads, live enemy patrol/return, load comparisons, and the final retreat replay remain acceptance checks. Do not treat this commit as full gameplay certification.
