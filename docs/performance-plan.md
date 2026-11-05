# Performance analysis and fix plan

Status: in progress (2026-11-05). Scope: client FPS, server heartbeat, network and memory after recent content growth.

Rule for every phase: **measure first, change second, re-measure.** No fix lands without a before/after number.

---

## Phase 0 — Baseline (no code changes)

Goal: find out *which* budget is blown before touching anything.

1. **Add profiler labels** (cheap, permanent). Only one `debug.profilebegin` exists today (`HeroAnimator.Step`). Wrap each per-frame callback so MicroProfiler bars have names:
   - Client `RenderStepped`/`Heartbeat`: `EntityRenderer` (split: `CombatFeedback`, `VfxPool`, `NodeLoop`), `FacilityWorkers`, `AdventurerPatrol`, `RelicVisuals`, `Commons`, `HubLighting`, `PlotBeacon`, `HeroCard`, `MasterController`.
   - Server `Heartbeat`: `CombatSim.StepActions`, `CombatSim.Tick` (split: `Heroes`, `Masters`, `Snapshot`), `RelicService`, `TowerFloorService`.
   - Add `debug.setmemorycategory` at the top of each big script (`EntityRenderer`, `FacilityWorkers`, `Patrol`, `CombatSim`, `DataManager`) so Dev Console memory splits by system.
2. **Capture four scenarios** in Studio (Start Server + 3–4 clients where relevant), each for ~60 s:
   | # | Scenario | Watch |
   | - | --- | --- |
   | A | Hub idle, all 10 plots populated (workers + patrol) | client ms/frame, draw calls, triangles |
   | B | Tower floor, full squad vs. dense mob pack, skills firing | server heartbeat, client EntityRenderer, Recv kB/s |
   | C | Biome boss fight, 3–4 players same floor | server Tick, snapshot bandwidth |
   | D | 20 min session with floor hops + menu use (Forge, Squad, Promotion) | client/server memory growth (leaks) |
3. Record per scenario: client FPS + MicroProfiler frame dump, server heartbeat (Dev Console → Server Stats), network Recv/Send kB/s, memory by category (`LuaHeap`, `PlaceMemory`, `GraphicsTexture`, `Instances`), Scene Analysis (instance counts, unparented instances, triangles).
4. Store numbers in `docs/reviews/perf-baseline.md` so later phases compare against them.

Tooling: Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`) can collect `Stats` / `workspace:GetRealPhysicsFPS()` / instance counts in a scripted way; the MicroProfiler dump is manual.

---

## Phase 1 — Suspected hotspots found by code review

Ranked by likely impact. Each is a hypothesis to confirm in Phase 0, not a guaranteed win.

### Server / network (affects everyone)

1. **Relic billboards rewritten every frame on the server** — `ServerScriptService/ExtractionAndSocial/RelicService.server.luau:480`. Each `Heartbeat` runs `string.format` and assigns `BillboardStatus.Text`/`TextColor3` (and `Prompt.Enabled`) for every relic. Property writes on replicated instances get sent to all clients, so this costs CPU and bandwidth at 60 Hz.
   *Fix:* only write when the displayed integer second or lock state changes (cache the last string), or move the countdown to the client from `DespawnAt`/`LockExpiresAt` attributes. Throttle the carried-relic extraction check to the 5–10 Hz sim tick.
2. **Snapshot broadcast allocations** — `CombatSimulation.server.luau:2366`. Every snapshot does `table.clone(e)` for every entity, builds a new `{IDLE=20,...}` lookup per mob, and runs `Protocol.Encode` **once per player** even when players share a floor.
   *Fix:* hoist the enemy-state lookup to a module constant; write the few derived fields into a reused per-entity scratch record instead of cloning; encode once per `(floor, context)` and fan the same buffers out to every player on it (context-specific fields permitting — check `Protocol.Encode`).
3. **Per-tick work in the sim loop** — `CombatSimulation.server.luau:2871`. `Tower.GetSafety` is called for every hero every tick and again for every master; `TowerRuns`/banking logic runs every tick. Profile `stepHeroSimulation` (line 2152) under scenario B/C; candidates are target acquisition (O(heroes × mobs) scans), navigation, and the sanctuary checks. Consider a spatial grid per floor for acquisition, and running banking/run-lifecycle checks at 2 Hz.
4. **Duplicate player-scan loops** — `TowerFloorService` (1 Hz, nested `rooms × states × adapters`), `TowerEventService`, `WaitingRoomService`, both leaderboard renderers. Individually cheap; verify none spike, and stagger their phases so they don't align on the same frame.
5. **Bandwidth audit** — in scenario B/C, log remote sizes/frequency (`HIT_SPARK`/`CombatVFX` per hit, `SquadStatus`, `TowerSnapshot`). Batch per-hit VFX into the snapshot or a per-tick batch if they dominate.

### Client

6. **EntityRenderer node loop** — `StarterPlayerScripts/Rendering/EntityRenderer.client.luau:645`. Per node per frame: `FindFirstChild("Head")`, `attachKOVFX`/`removeKOVFX` each doing `FindFirstChild("KOAttachment")`, plus a `PivotTo` on every node.
   *Fix:* cache `Head` and the KO attachment on the node at build time; only toggle KO VFX on state change; skip `PivotTo`/animator steps for nodes that are offscreen or far from the camera (lower rate, like the worker controllers already do).
7. **EntityRenderer Heartbeat resync check** — line 637 iterates all nodes every frame; it's throttled inside `requestEntityMetadata`, but break out of the loop after the first stale node and run the check at ~2 Hz.
8. **Ambient hub systems all running every frame** — `FacilityWorkerController`, `AdventurerPatrolController`, `RelicVisualController`, `CommonsController`, `HubLightingController`, `PlotBeaconController`. Workers/patrol already distance-throttle, but `resolvePlotOrigin` does 2–4 `FindFirstChild` calls per plot per frame — cache the origin and invalidate on the `Origin` attribute change. While the local player is inside the tower, park all hub-only systems entirely (one shared "InHub" flag).
9. **Rig and VFX cost** — 10 plots × workers + patrol adventurers + squad heroes are full code-built rigs. Measure in Scene Analysis: part count per hero rig, `Highlight` count (each one is expensive; several controllers create them), `PointLight`s from `RunicWeaponVfx`, `ParticleEmitter` rates. Fixes: `CastShadow=false`, `CanQuery/CanTouch=false` on all rig/decor parts, cap simultaneous `Highlight`s, disable runic lights beyond N studs, LOD far rigs (hide weapons/accessories, or swap to a low-part proxy).
10. **UI ViewportFrames** — `HeroCard` (lazy rigs, good), `FacilityPanel` previews with their own `RenderStepped`, Forge/Promotion ritual loops. Verify these disconnect when closed (scenario D) and that hidden ViewportFrames are emptied.
11. **Instance churn** — telegraph disks, whistle pulses, `CombatFeedback` popups are created and destroyed per event. Route them through the existing `CombatVfxPool` pattern if Phase 0 shows GC spikes.

### Build / world

12. **Streaming** — `default.project.json` has no streaming settings. Check `Workspace.StreamingEnabled` in the place; with 10 plots + Commons + tower rooms it should be on, with plots/tower rooms as `Atomic`/`Persistent` models where client code needs them. This is the biggest lever for mobile memory, but client code that does `FindFirstChild` on plots must become streaming-safe first (see `roblox-architecture`).
13. **Static geometry** — `PlotFacilityArchitecture`, `TowerRoomBuilder`, `CloisterBuilder`, `TowerBiomeAssets` build many Parts procedurally. Ensure all are `Anchored`, non-shadowing for small parts, `CanTouch=false`, and merged where possible. Check retired tower rooms are fully destroyed (`TowerFloorService` destroys after 60 s empty — verify no leftover instances/connections).

---

## Phase 2 — Fix order

Do these as separate small PRs (`perf(scope): ...`), each with before/after numbers in the PR body:

1. Profiler labels + memory categories (Phase 0.1).
2. Relic billboard write-on-change (item 1) — low risk, likely large network win.
3. Snapshot broadcast: shared encode per floor + no clones (item 2). Covered by `tests/tower*.spec.luau`; add a spec asserting identical packet bytes before/after.
4. EntityRenderer caching + distance LOD (items 6–7).
5. Hub systems park while in tower + cached plot origins (item 8).
6. Rig/VFX render cost (item 9), driven by Scene Analysis numbers.
7. Sim loop optimisations (item 3) only if server heartbeat is still short in scenario C.
8. Streaming (item 12) — largest change; its own plan once the rest is done.

Leak fixes (scenario D) jump the queue whenever found.

## Progress

| PR | Plan item | What landed |
| --- | --- | --- |
| #164 | Phase 0.1, item 1 | MicroProfiler labels and memory categories; relic billboards written only on change |
| #165 | item 2 | Snapshots encoded once per floor; no per-entity clones |
| #166 | items 6–7 | EntityRenderer distance LOD, highlight culling, cached KO/Head lookups, 4 Hz stale scan |
| #167 | item 8 | Hub workers/patrol/Commons park on tower floors; cached plot origins |
| #168 | item 9 (first pass) | Hub rig outlines culled by distance; weapon parts cast no shadows; `tests/studio-perf-census.luau` |
| #169 | item 3 (first pass) | Hero combat stats re-derived once a second instead of every sim tick |
| #170 | item 13 | `StaticGeometry.Apply` on hub, plots and tower rooms: anchored scenery stops generating touch events; small anchored parts stop casting shadows |
| #171 | items 10–11 | Damage/heal numbers pooled (no per-hit part + BillboardGui + TextLabel); hit sparks cast no shadows. UI previews and menu loops audited: they already clean up |

Still open: baseline numbers (Phase 0.2–0.4, needs Studio), item 3 beyond stats (targeting, safety checks) once `CombatSim.Heroes` is measured, items 4–5 and streaming (item 12, its own plan).

## Phase 3 — Guardrails

- Keep the labels; re-run scenarios A–D before each content drop and append to `perf-baseline.md`.
- Budget targets: client ≤ 16.6 ms/frame on a mid-range phone in A and B; server heartbeat ≥ 55 Hz in C; client memory flat (±5%) across D; tower Recv ≤ ~50 kB/s per client in C.
- Code review rule: no new `RenderStepped`/`Heartbeat` connection without distance/visibility throttling and a profiler label; no replicated property writes from server per-frame loops.

## How to test (per fix)

1. `pwsh tests/run.ps1` — compile + specs pass.
2. Studio: run the matching scenario from Phase 0 with MicroProfiler (Ctrl+Alt+F6) and Dev Console (F9) open.
3. Compare the labelled bar / heartbeat / kB/s / memory against the baseline table.
4. Visual check: relic timers still count down, entities still interpolate smoothly, hub workers resume when returning from the tower.
