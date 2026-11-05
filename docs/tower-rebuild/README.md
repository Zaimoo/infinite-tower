# Tower Rebuild & Navigation Index

This directory indexes the spatial architecture, connector geometry, and squad navigation documentation for the 50-floor Infinite Tower.

## Architecture & Specifications

- **[Tower Navigation & Squad Movement Architecture](../TOWER_NAVIGATION.md)** — Authoritative reference for `TowerLayout` connector metadata, `TowerRoomBuilder` flush landings, `TowerNavigationGraph` routing, `HeroNavigation` movement/recovery, `SquadMovement` active/assigned destination policies, `HeroTargeting` route-cost selection, and `EntityRenderer` transition clamping.
- **[Tower Movement Reliability Implementation Plan](../tower-movement-reliability-plan.md)** — Phased design and acceptance plan (Phases 0–5).
- **[Game Design Document (§3.3 & §4.5)](../GAME_DESIGN.MD)** — Multi-tiered room topography, camp/patrol rules, and squad command mechanics.

## Phase Reviews & Verification Evidence

- **[Phase 0 — Baseline Reproduction & Diagnostics](../reviews/tower-movement/2026-11-05/README.md)**
- **[Phase 1 — Shared Connector Contract & Ramp Joins](../reviews/tower-movement/PHASE_1.md)**
- **[Phase 2 — Shared Routing & Movement Recovery](../reviews/tower-movement/PHASE_2.md)**
- **[Phase 3 — Active Floor-Run Destination Policy](../reviews/tower-movement/PHASE_3.md)**
- **[Phase 4 — Assigned-Squad Destination Policy](../reviews/tower-movement/PHASE_4.md)**
- **[Phase 5 — Presentation Review & Documentation](../reviews/tower-movement/PHASE_5.md)**
