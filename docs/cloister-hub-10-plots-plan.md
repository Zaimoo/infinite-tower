# Hub Re-layout v2: The Cloister Commons (10 plots)

Status: **implemented.** As built, the hub grew to 840 × 1120 (centre `(0, 12, -1036)`) with concentric corners (outer R 160, void R 40) so the band stays 120 wide; that keeps every neighbour gap at least 24 studs. The island is 340 × 500. Invisible barriers are 20 studs tall, because players could jump a 12-stud barrier from the top of the wall. Figures below are from the original proposal. It replaces the round Masters' Commons and the 6-plot horseshoe (`docs/commons-hub-layout-plan.md`). GDD §3.1, §3.2, §3.4, §3.5 and §3.6 get updated in the same PR.

## 1. Goal

The game goes from 6 plots to 10, so each server holds 10 players with one plot each. The current horseshoe can't take 4 more plots without overlaps. The hub becomes a **rounded rectangle in front of the tower gate**, built as a **hollow cloister**: a promenade band runs around a central void, a garden island floats in the middle, and the 10 plots line the outside with short bridges.

| | Today | After |
| --- | --- | --- |
| Plots | 6, horseshoe around a round park (R 170) | **10**, around a rounded-rectangle cloister |
| Hub | Round park, about 91k sq studs | 800 × 1080 rectangle with 80-stud corners. Walkable area about 330k sq studs (band plus island), not the full 860k |
| Plot bridges | about 158 studs | **40 studs** |
| Causeway | 94 studs | 90 studs |
| Map extent | about 1,300 from the tower | about **1,930** north of the tower, ±776 east-west |

## 2. World layout

Coordinates use the same frame as today: the tower is at `(0, 0)`, north is −Z, and the ground is at `Y = 12`.

### 2.1 Numbers (checked by script: no overlaps, closest neighbour gap 24 studs)

| Item | Value |
| --- | --- |
| Hub centre | `(0, 12, -1016)` |
| Hub outline | X −400 to +400, Z −1556 to −476, corner radius 80 |
| Cloister band (walkable ring) | 120 studs wide, inside the outline |
| Inner void | 560 × 840 (rounded, radius 40). Open sky down to the catch plane |
| Centre island | 300 × 420 rounded rectangle, holding the Wayfinder Dais and the pool |
| Island footbridges | 4, one per side, 20 wide, crossing the 130/210-stud gap from the band to the island |
| Pilgrim's Causeway | `z = -386` (walkway edge) to `z = -476` (hub south edge), 40 wide, unchanged style |
| Plot bridges | 18 wide, 40 long, flat at `Y = 12` |

| Plot | Side | Island centre (X, Z) | Faces | Gate (X, Z) | Hub landing (X, Z) | Nearest point to tower |
| --- | --- | --- | --- | --- | --- | --- |
| Plot_1 | West, south | (−608, −732) | East (bearing −90 outward) | (−440, −732) | (−400, −732) | about 740 |
| Plot_2 | West, middle | (−608, −1016) | East | (−440, −1016) | (−400, −1016) | |
| Plot_3 | West, north | (−608, −1300) | East | (−440, −1300) | (−400, −1300) | |
| Plot_4 | North-west corner | (−524, −1680) | South-east (−45°) | (−405, −1561) | (−377, −1533) | |
| Plot_5 | North, west | (−142, −1764) | South (0°) | (−142, −1596) | (−142, −1556) | |
| Plot_6 | North, east | (142, −1764) | South | (142, −1596) | (142, −1556) | |
| Plot_7 | North-east corner | (524, −1680) | South-west (+45°) | (405, −1561) | (377, −1533) | |
| Plot_8 | East, north | (608, −1300) | West (+90°) | (440, −1300) | (400, −1300) | |
| Plot_9 | East, middle | (608, −1016) | West | (440, −1016) | (400, −1016) | |
| Plot_10 | East, south | (608, −732) | West | (440, −732) | (400, −732) | about 740 |

Each island's front (−Z local) faces the hub centre line. For the side plots that means facing straight across, not at the hub centre, so every gate meets its band at a right angle.

### 2.2 Map

```
                     P5            P6
                ╭──────────────────────────╮
         P4  ╱  │ ═══════ north band ═════ │  ╲  P7
            ╱   │ ║  ┌────────────────┐  ║ │   ╲
                │ ║  │   ~ void ~     │  ║ │
         P3 ════│ ║  │  ┌──────────┐  │  ║ │════ P8
                │ ║  │  │  CENTRE  │  │  ║ │
                │ ║==│==│  ISLAND  │==│==║ │      == footbridges
         P2 ════│ ║  │  │  dais +  │  │  ║ │════ P9
                │ ║  │  │   pool   │  │  ║ │
                │ ║  │  └──────────┘  │  ║ │
         P1 ════│ ║  └────────────────┘  ║ │════ P10
                │ ══ south "Grand Terrace" ══│
                ╰─────────────┬────────────╯
                              │  Pilgrim's Causeway (90)
                        [ TOWER GATE ]
                     ( CRIMSON TOWER  0,0 )
```

## 3. The Cloister Commons design

Most of today's Commons elements move onto the band or the island. Positions below are hub-local: the origin is at `(0, 12, -1016)`, +X is east, and −Z is north.

| Zone | Where | Contents (reused from `CommonsBuilder` unless noted) |
| --- | --- | --- |
| **Grand Terrace** (south band) | z +420 to +540 | The South Gate arch (44 wide) where the causeway arrives, the end of the Pilgrim's Way boulevard with braziers and banners, and the **Leaderboard Pavilion** facing the gate, so arrivals see the boards first. |
| **West band** | x −400 to −280 | Landings for Plots 1–3 (banners, nameplate tablets, cyan runes). Between them sit the **Lantern Orchard** (south) and the **Gazebo** (north). |
| **East band** | x +280 to +400 | Landings for Plots 8–10. Between them sit the **Overlook Terrace** (south, looking at the tower) and the **Biome Stones** (north). |
| **North band** | z −540 to −420 | Landings for Plots 5 and 6, plus a second **Lantern Orchard**. |
| **Corners** | radius 80 | Landings for Plots 4 and 7, angled 45°, each with a crenellated corner bastion and a lamp tower. |
| **Centre island** | 300 × 420 | The **Wayfinder Dais** with the statue, crystal and squad plinths, and the **Reflecting Pool** to the north. 10 compass arrows, one per plot. |
| **Footbridges** | 4 | Short timber-and-stone arches from each band to the island. Two hanging lanterns each. |
| **Inner void** | 560 × 840 | Open sky. A low balustrade and invisible barrier line both edges. Background islets and cloud wisps drift below it. |
| **Edges** | Outer and inner | The rim wall with crenels and lamp pylons, broken by 10 plot openings plus the South Gate, and an inner balustrade along the void. |

Budget: about 1,400 parts, at most 36 PointLights and at most 8 ParticleEmitters.

**Lighting:**
- The whole hub is Sanctuary.
- Dread changes to 395 (full) and 470 (none), so it ends at the hub's south edge (z −476).
- The 90-stud causeway stays the transition.

## 4. Code changes by phase

### Phase 1: layout config and test
- **`HubLayout.luau`:**
  - replace `PlotBearingsDeg`, `PlotCentreRadius`, `ParkCentre` and `ParkRadius` with a `Plots` table of 10 entries `{ Centre, Facing }`
  - add `Hub = { Centre, HalfX = 400, HalfZ = 540, CornerRadius = 80, BandWidth = 120, Island = {...} }`
  - keep the helpers `PlotIslandCFrame(i)`, `PlotCorners(i)` and `HubLandingPoint(i)`, now driven by the table
  - `BankZonePolygons()` covers the band (as an outer and inner polygon pair), the island, the 4 footbridges, the 10 bridges and the causeway
  - `KillZoneCentre` moves to `(0, -95, -900)` with `KillZoneSize` 2,000 × 3,000 (tiled; tiling already exists)
- **`hublayout.spec.luau`:**
  - the overlap, tower-clearance and bridge-length tests now cover 10 plots, and a new test requires at least 20 studs between neighbours
  - the zone test checks a point on each band, the island, every bridge and the causeway, and that the void is **not** a bank zone (no banking mid-air)
- **`HubLighting.luau`:** `DreadNoneRadius` changes to 470. Its test now checks that the hub's south edge is Sanctuary.

### Phase 2: build the cloister
- **New `CloisterBuilder.luau`**, which replaces `CommonsBuilder`:
  - shared pieces: `PartKit`, plus the rounded-rectangle helpers `roundedRectRing(halfX, halfZ, r, width)` and `roundedRectEdge(...)`, which return segment CFrames for walls, slabs and barriers
  - the band slab, the void edges and the island get the same stepped-rock underside style
- **Moved, not rewritten:**
  - the element builders from `CommonsBuilder` (dais, pool, orchards, pavilion, gazebo, biome stones, overlook, South Gate, Pilgrim's Way) become functions that take a local CFrame
  - `BindGateTablets` stays, now looping over 10 landings
- **`CommonsBuilder.luau`** is deleted once nothing references it.

### Phase 3: place 10 plots, bridges, causeway
- **`HubOverhaul.luau`:**
  - loop over `#HubLayout.Plots`
  - create `Plot_7`…`Plot_10` when they're missing (the code path already exists), clone the island template, and move each plot
  - bump `HubOverhaul.Version` to 10
  - the `alreadyBaked` check uses `Plot_10` and `#children >= 10` instead of the hard-coded `Plot_6`
- **`BridgeBuilder.luau`:** 10 plot bridges using the Sanctuary palette, landing at `HubLandingPoint(i)`. The causeway runs from the walkway to `z = -476`. The walkway rail opening stays at −90°.
- **`CausewayBuilder.luau`:** its length now comes from `HubLayout`, which is already parameterised. Check the pylon and arch spacing over 90 studs.
- **`SharedLeaderboards.luau`:** no change (it reads the pavilion).

### Phase 4: 10 players
- **`PlotManager.server.luau:409`:**
  - `for i = 1, 6` becomes `for _, i in HubLayout.AssignmentOrder`
  - the order fills nearest-to-gate first, so small servers cluster near the tower and Grand Terrace: `{1, 10, 2, 9, 3, 8, 4, 7, 5, 6}`
- **Studio game settings:** set the server's **Max Players to 10**. This is a place setting, not code, so it's on the playtest checklist.
- **`TowerFloorService.luau`:** change `rooms[0].Bounds` to `Min (-1600, -100, -2100)` and `Max (1600, 2500, 1600)` to cover z −1,932.
- **Beacons and HUD:** `PlotBeaconController` ranges (3,500) still cover everything, so only the comment changes. Check that the HUD and leaderboard lists handle 10 players, including the `ForgeController` `for i = 1, 6` loops at lines 1454 and 1651, which may be UI slots unrelated to plots.
- **`PlotBuildings`:** nothing to change. It already rebuilds when an island moves (Origin cache).

### Phase 5: rebake and save
- Rebake in Edit mode from a fresh module copy (the clone-the-folder method, which avoids Studio's require cache).
- Run `RebuildPlotBuildings` for all 10 plots, then save the place.
- `Plot_7`–`Plot_10` are created by the build, so no manual Studio work is needed.

### Phase 6: docs
- **GDD §3.1:** new map.
- **GDD §3.2:** new zone rows (Cloister Commons, band, void, island, 10 plots, catch plane).
- **GDD §3.4:** the drawbridge lands on the band.
- **GDD §3.5:** rewritten for the cloister.
- **GDD §3.6:** new Dread radius.
- **`CLAUDE.md`:** "Each server holds 6 players" becomes 10.
- **`commons-hub-layout-plan.md`:** marked superseded, later deleted.

## 5. Risks

- **Performance.** Each plot is about 2,000–2,200 parts with buildings, so 4 more plots add about 8,500. The hub goes from about 900 to about 1,400 parts. Check server memory and client FPS on mobile in the MicroProfiler with 10 players. Plots are `Persistent` for streaming, so all 10 always load on every client. Consider making only the *outskirts* non-persistent.
- **Walk times.** The farthest plot (Plot 5 or 6) is about 1,600 studs from the tower gate: about 100 s at walk speed 16. Assigning plots nearest-first keeps most servers short, but a sprint key or a "return to plot" teleport on the HUD is worth adding.
- **Void falls.** The inner void is new open sky next to walkways. A balustrade and invisible barrier line both edges, and the catch plane covers it.
- **Data.** `profile.PlotIndex` is assigned per session and not persisted (`profiles-not-persisted`), so no migration is needed. Confirm before persistence ships.

## 6. Tests

- `pwsh tests/run.ps1`: all suites, including the extended `hublayout.spec.luau`. It checks: 10 plots, no overlap, a neighbour gap of at least 20, tower clearance of at least 430, bridges of 30–60 studs, bank zones (void excluded), lighting zones, and that all geometry sits inside the catch plane and the room bounds.

## 7. How to test in Studio (after implementation)

1. Set Max Players to 10 in Game Settings, then start a local 10-player test server (Test → Clients and Servers → 10).
2. Check that each player gets a distinct plot, filled in the order 1, 10, 2, 9, …, and that each gate tablet shows the right owner.
3. Walk from Plot 5 (the far north) along the band, over a footbridge and the island, to the South Gate and the tower, and time the trip.
4. Check every plot bridge meets its landing flush, and that the corner plots 4 and 7 line up at 45°.
5. Lean over the inner void and both edges: the barriers should hold. Jump off a plot bridge: the catch plane should return you home.
6. Carry loot onto the band, the island and a bridge: it should bank. It must not bank mid-void.
7. The lighting should stay warm across the whole hub and only darken on the causeway.
8. Check FPS and server memory with all 10 plots built.
