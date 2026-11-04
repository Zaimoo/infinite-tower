# Hub Re-layout: The Masters' Commons

> **Superseded** by `docs/cloister-hub-10-plots-plan.md` (10 plots around the Cloister Commons). Kept for history.

Status: **Phases 1–6 implemented.** Phase 7 (stretch goals) is still to do. Phase 5 was baked into the open place in Studio and has to be saved from Studio.

As built, the build differs from the plan below in these ways:
- The leaderboards hang back to back on a centre wall in a 44 × 34 pavilion at `R = 100`. Playtime faces the dais and Power faces the Loop. Each board is about 37 studs wide, so two could not fit side by side.
- The hub build moved from `PlaceIslandsInRing.server.luau` into the `HubOverhaul` ModuleScript, so Studio's Edit mode can bake it. The server Script now only calls `Build`, `StartRuntime` and `BridgeBuilder.Build`.
- Roblox caps parts at 2048 studs per axis, so the 3400-stud catch plane is a 2 × 2 grid of tiles.
- `PlotBuildings` now caches per island position (an `Origin` attribute), so courtyard buildings and outskirts follow a moved island. `HubOverhaul.StartRuntime` refreshes them after a rebuild.
- The plot gate lintels sit about 328 studs from the park centre, not 310, so each plot bridge is about 158 studs long.
- The Reflecting Pool is round (`R = 26`), not a crescent, so its coping clears the ±24° path hedges.
- The Commons has 820 parts, 21 PointLights and 5 ParticleEmitters.

## 1. What changes

| | Today | After |
| --- | --- | --- |
| Plot ring centre | The tower, `(0, 0)` | The Commons park, `C = (0, 12, -650)` |
| Plot arrangement | 6 plots, 60° apart, full circle at `R = 650` around the tower | 6 plots in a **horseshoe**, 48° apart, around the park. The open side faces the tower gate. |
| How plots connect | 6 bridges from each plot gate to the tower walkway ring (`R = 375`) | 6 bridges from each plot gate to the park rim, plus one wide causeway from the park to the tower gate |
| Social space | None (each plot is private, the walkway is a bare ring) | A shared 340-stud park in front of the gate that every player crosses between their plot and the tower |
| Leaderboards | 2 boards cloned into every plot (12 total) | 1 shared pair in the park's Leaderboard Pavilion |

Things that do **not** change: the tower and its gate, the hub arrival platform `(0, 18.5, -342)`, every plot's internal layout (all plot code uses plot-local CFrames), plot ownership, `Y = 12` ground height for heroes, and the off-map tower floors.

## 2. Current layout (measured in Studio, edit mode)

```
                                N (-Z)
                          ┌────────────┐
                          │  PLOT 1    │  centre (0, -650)
                          └─────┬──────┘
          PLOT 6 ┐              │ IslandBridge_1          ┌ PLOT 2
       (-563,-325)╲             │                        ╱ (563,-325)
                   ╲     ╭──────┴───────╮              ╱
                    ╲────┤  GATE z=-332 ├─────────────╱
                         │   CRIMSON    │   walkway ring R=375
                    ╱────┤   TOWER      ├─────────────╲
                   ╱     │  R ≈ 330     │              ╲
       (-563,325) ╱      ╰──────┬───────╯               ╲ (563,325)
          PLOT 5 ┘              │                        └ PLOT 3
                          ┌─────┴──────┐
                          │  PLOT 4    │  centre (0, 650)
                          └────────────┘
                                S (+Z)
   Island footprint 260 x 335 (bbox), front gate at R ≈ 482, outskirts out to R ≈ 817.
```

Source of these numbers: `PlaceIslandsInRing.server.luau` (`RingRadius = 650`, `StartAngleDeg = -90`), `BridgeBuilder.luau` (walkway `radius = 375`, `y = 16`), plus a live `GetBoundingBox` of each `Plot_N.FloatingFortressIsland`.

## 3. New world layout

### 3.1 Numbers

Park centre `C = (0, 12, -650)`. Bearings are measured from `C`, with 0° pointing north (away from the tower) and positive bearings to the east.

| | Value | Why |
| --- | --- | --- |
| Park radius | 170 (340 across) | Bigger than one plot, so it reads as the centrepiece and fits 7 themed wedges |
| Plot bearings | -120°, -72°, -24°, +24°, +72°, +120° | 48° spacing. The ±120° plots stay **≥ 433 studs** from the tower centre, which leaves a 47-stud gap to the walkway rail |
| Plot gate radius (from `C`) | 310 | Smallest radius at which neighbouring 260-wide fronts don't touch (front gap ≈ 16 studs, and it widens toward the rear) |
| Plot centre radius (from `C`) | 478 | Gate radius + 168 (half the island depth) |
| Plot bridges | 18 wide, about 140 long (`R` 170 to 310), `Y = 12`, flat | Same width and rails as today's bridges |
| Pilgrim's Causeway | 28 wide, `z` from -386 to -480, slopes from `Y = 16` down to `Y = 12` (2.4°) | 28 matches `TowerEntranceApproach` |
| Farthest island point | about 1,301 studs from the origin | Drives the new kill-plane size |

Plot world positions (island centre and gate):

| Plot | Bearing | Island centre (X, Z) | Front gate (X, Z) | Park rim gate (X, Z) |
| --- | --- | --- | --- | --- |
| Plot_1 | -120° | (-414, -411) | (-268, -495) | (-147, -565) |
| Plot_2 | -72° | (-455, -798) | (-295, -746) | (-162, -703) |
| Plot_3 | -24° | (-194, -1087) | (-126, -933) | (-69, -805) |
| Plot_4 | +24° | (194, -1087) | (126, -933) | (69, -805) |
| Plot_5 | +72° | (455, -798) | (295, -746) | (162, -703) |
| Plot_6 | +120° | (414, -411) | (268, -495) | (147, -565) |

Each plot faces the park: `CFrame.lookAt(islandCentre, C)`, the same convention used today with the tower.

### 3.2 World map (top-down, north up)

```
                                        N (-Z)
                    ┌──────────────┐               ┌──────────────┐
                    │   PLOT 3     │               │   PLOT 4     │
                    │   -24°       │               │   +24°       │
                    │ (-194,-1087) │               │ (194,-1087)  │
                    └──────╲───────┘               └───────╱──────┘
                            ╲ bridge 3               bridge 4╱
   ┌──────────────┐          ╲                              ╱          ┌──────────────┐
   │   PLOT 2     │           ╲   . · ˙ ˙ ˙ ˙ ˙ ˙ ˙ · .   ╱           │   PLOT 5     │
   │   -72°       │══════════  ˙                      ˙  ══════════════│   +72°       │
   │ (-455,-798)  │  bridge 2 ˙    THE MASTERS'          ˙  bridge 5   │ (455,-798)   │
   └──────────────┘          ˙       COMMONS              ˙            └──────────────┘
                             ˙     C = (0,-650)           ˙
                              ˙    R = 170, Y = 12       ˙
   ┌──────────────┐         ╱  ˙                      ˙   ╲         ┌──────────────┐
   │   PLOT 1     │ bridge 1     ˙ · . . ┌──┐ . . · ˙       bridge 6│   PLOT 6     │
   │   -120°      │═════╱                │SG│                  ╲═════│   +120°      │
   │ (-414,-411)  │                      │  │ Pilgrim's            │ (414,-411)   │
   └──────────────┘                      │  │ Causeway             └──────────────┘
                                         │  │ 28 wide, Y 12 → 16
                               ╭─────────┴──┴─────────╮
                               │   GATE  (0,-332)     │  arrival pad (0,18.5,-342)
                          ╭────┴──────────────────────┴────╮
                          │      CENTRAL CRIMSON TOWER     │  walkway ring R = 375
                          │             (0, 0)             │  (rail opening only at
                          ╰────────────────────────────────╯   the causeway now)
                                        S (+Z)
   SG = South Gate arch of the Commons.  Outskirts of every plot point away from the park.
```

### 3.3 Side elevation along the causeway (south to north)

```
  Y
  +16 ─ tower walkway ══╗
                         ╚══════ causeway (2.4° slope) ═════╗
  +12 ─                                                     ╚═ COMMONS (Y=12) ═══ bridge ═══ PLOT (Y=12)
   0
 -95 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ safety catch plane (now 3400 x 3400, centred on (0,-500)) ─ ─ ─ ─ ─ ─ ─
       z=-386             z=-480                         z=-820          R=310 from C
```

## 4. The Masters' Commons: full design

Park-local frame: origin at `C`, top surface is `y = 0` (world `Y = 12`), `-z` is north (away from the tower), `+z` is south (toward the tower gate).

### 4.1 Zone map

```
                              Plot 3 bridge              Plot 4 bridge
                                    ╲ (-24°)            (+24°) ╱
                         . · ˙ ˙ ˙ [G3]═══ ˙ ˙ ˙ ˙ ˙ ═══[G4] ˙ ˙ · .
                    . ˙  ◇      ◇      ◇      ◇      ◇      ◇      ˙ .
                 ˙  ◇ ┌─────────────── MASTERS' LOOP ────────────────┐ ◇ ˙
              ˙     ┌─┘  ♣  ♣  ♣   ╲   ~~~~~~~~~~~~~~~   ╱   ♣  ♣  ♣  └─┐   ˙
            ˙  ◇   │   LANTERN      ╲ ~~ J. REFLECTING ~~╱      LANTERN   │   ◇ ˙
          ˙        │  ♣ ORCHARD ♣    ╲~~ ◦ ◦ ⌒⌒⌒ ◦ ◦ ~~╱    ♣ ORCHARD ♣  │       ˙
 Plot 2 [G2]═══════│   K-NW  ♣  ♣     ╲~~~~ POOL ~~~~~╱     ♣  ♣  K-NE   │═══════[G5] Plot 5
 (-72°)  ˙         │  ♣  ♣  ♣  ▬▬      ╲      │       ╱      ▬▬  ♣  ♣  ♣  │         ˙ (+72°)
         ˙  ◇      │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┌────┴────┐ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │      ◇  ˙
         ˙         │   M. GAZEBO &    ── │ I. WAY- │ ──   L. LEADERBOARD │         ˙
         ˙         │   BANDSTAND ⬡       │ FINDER  │       PAVILION ▥▥   │         ˙
          ˙  ◇     │  ─ ─ ─ ─ ─ ─ ─ ─ ─  │  DAIS ✦ │ ─ ─ ─ ─ ─ ─ ─ ─ ─   │     ◇  ˙
 Plot 1 [G1]═══════│                  ╱  └────┬────┘  ╲                  │═══════[G6] Plot 6
 (-120°)    ˙      │  N. BIOME       ╱     ▒▒▒▒▒▒▒     ╲    O. OVERLOOK  │      ˙ (+120°)
              ˙    │   STONES ○○○   ╱  🔥 ▒ G.  ▒ 🔥   ╲   TERRACE (+4) │    ˙
                ˙  └─┐  ○ ◎ ○    ╱      ▒PILGRIM'S▒      ╲    ⊢telescopes└─┐ ˙
                   ˙ └──────────────── 🔥 ▒  WAY  ▒ 🔥 ──────────────────┘ ˙
                       ˙ ◇      ◇      ◇ ▒      ▒ ◇      ◇      ◇    ˙
                            ˙ · . . . . ┃ H. SOUTH GATE ┃ . . . . · ˙
                                         ┃   (36 wide)   ┃
                                         ▼ Pilgrim's Causeway → Tower Gate

   Legend: [Gn] gate landing to Plot n   ◇ lamp pylon   ♣ tree   ▬▬ bench   🔥 brazier
           ~~ water   ◦ stepping stone   ⌒ footbridge   ○ menhir   ▒ crimson runner
           ─ ─ radial path with hedges   ✦ statue + floating crystal
```

The wedges between the paths and the feature each one holds:

| Wedge | Bearing span | Feature |
| --- | --- | --- |
| North | -24° to +24° | J. Reflecting Pool |
| North-west / north-east | ±24° to ±72° | K. Lantern Orchards |
| West | -72° to -120° | M. Gazebo & Bandstand |
| East | +72° to +120° | L. Leaderboard Pavilion |
| South-west | -120° to 180° | N. Biome Stones |
| South-east | +120° to 180° | O. Overlook Terrace |
| South (centre line) | 180° | G. Pilgrim's Way and H. South Gate |

### 4.2 Element specification

Every element is built in code by the new `CommonsBuilder` (Phase 2). Positions are park-local `(x, z)`. "Deco" means `CanCollide = CanTouch = CanQuery = false, CastShadow = false`.

**A. Island mass**
- Top: a 24-sided slab, `R = 170`, 6 thick. Material `Grass` with colour `(64, 92, 52)`. The outer band (`R` 160 to 170) is `Slate` `(58, 62, 68)`, so the rim matches the plot islands.
- Underside: 6 stepped rock tiers that taper from `R = 165` to `R = 40` over 140 studs of depth, plus 16 outer spires, 10 deep stalactites and cloud wisps. This reuses `IslandBuilder`'s helpers and palette with the same fixed RNG seed style, so the park looks like it belongs with the plots. All of it is deco.

**B. Rim balustrade**
- A slate wall at `R = 167`, 3.5 tall and 2 thick, built as 72 segments. Every other segment carries a crenel cap.
- There are 7 openings: 20 wide at each of the six plot bearings, and 36 wide at 180° for the South Gate.
- Behind the wall sits an `InvisibleEdgeBarriers` ring (12 tall, transparent, `CanCollide = true`, `CanQuery = false`) with the same openings, so nobody falls off the park.

**C. Lamp pylons**
- 24 pylons on `R = 162`, one every 15°, skipping any that land in an opening.
- Each pylon is a 9-tall iron post (`Metal (40, 40, 44)`) carrying a lantern box with a `Neon (255, 196, 120)` core.
- Only every other pylon has a `PointLight` (range 16, brightness 1.2), which gives about 11 lights.

**D. Masters' Loop**
- A promenade ring from `R = 138` to `R = 156`, made of 48 `Cobblestone (92, 88, 84)` segments.
- The segments are 0.2 thick and sit at `y = 0.1`, which avoids z-fighting with the grass.
- The Loop links every gate landing, so a player can walk to any plot without crossing the gardens.

**E. Gate landings G1 to G6**
- A 24 × 16 cobble apron from `R = 156` to `R = 170` that meets the bridge deck flush.
- Two 14-tall banner pylons, each hanging a `Fabric` banner in the plot's beacon colour.
- A stone tablet with a `SurfaceGui` that reads `PLOT n · <Owner>'s Fortress`, or `PLOT n · Unclaimed`. The client fills it in from the owner attribute that `PlotManager` already sets.
- An 8-wide cyan `Neon` rune ring inlaid in the ground (transparency 0.35).

**F. Radial paths**
- 6 paths, 10 wide, `Cobblestone`, running from `R = 40` to `R = 138` along the plot bearings.
- Each is lined by 2-tall boxwood hedges (`Grass (40, 70, 38)`). The hedges break at the midpoint so players can step into the wedges.

**G. Pilgrim's Way (south boulevard)**
- 28 wide, from `R = 36` to `R = 170` at a bearing of 180°.
- A `Granite (145, 28, 38)` runner, 10 wide, runs down the centre and continues the `TowerHubArrival_Runner` all the way to the monument.
- 8 iron braziers, 4 per side spaced 16 apart, with fire `ParticleEmitter`s. 4 of them carry orange `PointLight`s.
- 18-tall crimson banner poles alternate with the braziers.

**H. South Gate**
- Twin 30-tall pylons on 6 × 6 bases at `x = ±18`, `R = 168`, in `Slate` with crimson `Granite` inlay bands.
- An arch lintel at `y = 24` spans 36 studs and frames the tower as you walk out. A hanging stone sign reads **THE INFINITE TOWER**.
- Two crouching gargoyle statues sit on the pylon caps (deco).

**I. Wayfinder Dais (centrepiece)**
- **Plaza:** a disc of `R = 36` in `Marble (200, 196, 188)`. A compass-rose inlay of 8 crimson `Granite` wedge strips is set into it, and 6 cyan `Neon` arrow strips point down each plot's radial path. Each arrow's tip carries a small engraved plot number.
- **Dais:** 3 tiers with radii 18, 14 and 10, each 1 stud high (this meets the ≤ 1-stud stair rule).
- **Statue of the First Master:** about 14 tall, on a 4-tall plinth, built only from parts. It has a cloak of wedges, a torso, a hooded head, and a raised sword arm pointing south at the tower. The figure is `Marble` and the sword edge is crimson `Neon`. It is a generic figure, not a hero rig.
- **Wayfinder Crystal:** a cyan `Neon` octahedron (two square pyramids) floating above the sword tip at `y ≈ 24`, with a `PointLight` (cyan, range 24) and a soft sparkle emitter. It is tagged `CommonsSpinner`, and a small client controller spins and bobs it locally, so the server never animates anything.
- **Squad plinths:** 5 knee-high plinths on `R = 26`, at bearings 36°, 108°, 180°+36°, and so on, avoiding the paths. Each holds a 3-tall hero silhouette statuette, standing for the five squad slots. (Stretch goal: show the top-Power player's squad. See Phase 7.)
- **Benches:** 4 stone benches at `R = 32` facing the statue, placed between the arrows.

**J. Reflecting Pool (north wedge)**
- A crescent pool centred at `(0, -95)`, made of 3 overlapping discs (radii 30, 24 and 24, the side discs offset ±26 in `x`).
- The water surface is a `Glass (60, 110, 140)` part at transparency 0.2, sunk to `y = -0.6`, with a collidable pool floor at `y = -1.2`. Walking in is just a shallow wade, with no swimming state.
- A 1-tall slate coping ring runs around the edge.
- 7 stepping stones cross east to west.
- A small arched footbridge crosses north to south. It has 3 segments with a peak of +2 and slopes ≤ 15°.
- 6 lily pads (thin green cylinders, deco).
- 2 weeping willows: a trunk plus drooping canopy spheres, deco.
- 1 fountain-jet particle in the centre and a low mist emitter.

**K. Lantern Orchards (north-west and north-east wedges)**
- Each orchard has 8 blossom trees in 2 staggered rows: a `Wood` trunk and a canopy of 3 spheres in `SmoothPlastic (255, 183, 197)`, with alternate trees in `(250, 240, 245)`.
- Paper lanterns hang between the trees: small `Neon` cubes under a thin wooden crossbar. Only 2 lanterns per orchard carry lights.
- 2 benches per orchard face the Loop.
- Flower beds line the radial paths: low strips in 3 colours.
- One firefly `ParticleEmitter` per orchard (rate 4, lifetime 6). The hub lighting is fixed, so it is always on.

**L. Leaderboard Pavilion (east wedge, centred at bearing 96°, `R = 95`)**
- An open colonnade on a 40 × 24 footprint, raised 1 stud (one step).
- 6 slate columns, 14 tall, carry a crimson-trimmed slate roof slab with crenels.
- The **shared** `AvxsedPlaytimeWS` and `AvxsedPowerWS` boards are mounted side by side on the back wall, facing the monument. They are the only world leaderboards left (see Phase 4).

**M. Gazebo & Bandstand (west wedge, bearing -96°, `R = 95`)**
- An octagonal gazebo 26 across, raised 1 stud.
- 8 carved posts hold up a conical roof of 8 wedge panels, topped with a lantern finial and one `PointLight`.
- A ring bench sits inside. This is the AFK and social spot.

**N. Biome Stones (south-west wedge, bearing -150°, `R = 100`)**
- A stone circle of `R = 20` made of 10 menhirs, 8 to 12 tall, one per tower biome in floor order. Each menhir is tinted in its biome's colour: Verdant green, Fungal purple, Ashen sand, Frozen ice blue, Infernal orange, Thunder gold, Corrupted plum, Sunken teal, Astral violet, Abyssal crimson.
- Each menhir carries a dim `Neon` rune strip.
- A flat altar stone sits in the centre.
- (Stretch goal: a rune brightens when any player in the server has cleared that biome's boss. See Phase 7.)

**O. Overlook Terrace (south-east wedge, bearing 150°, `R = 100`)**
- A 44 × 30 terrace raised 4 studs, with two 16-long ramps (14°, within the 15° slope rule) and a balustrade.
- 2 brass telescopes aimed at the tower top, plus crimson banners and one bench.
- It is a photo spot that frames the tower behind the South Gate.

**Budgets**
- About 1,100 parts in total, of which around 85% are deco.
- At most 30 `PointLight`s and at most 8 `ParticleEmitter`s.
- The park model uses `ModelStreamingMode = Atomic`. It doesn't need to be `Persistent`, because the plots and their beacons already are.

### 4.3 Gameplay rules for the Commons

- **Safe zone:** `CombatSafe = true` and `CanRecoverWipe = true`. No mobs spawn, and there is no PvP or retaliation damage.
- **Banking:** `CanBankCargo = true`, matching today's `HUB_BANK` belt, which allows banking anywhere between `R` 460 and 760. *Open question: if you'd rather banking be possible only at the plot extraction pads, flip this flag. It's one line.*
- **Player flow:**
  1. Spawn at your own `PlotSpawn`, which is unchanged.
  2. Walk out the plot gate and across your bridge.
  3. Cross the Commons.
  4. Walk down the Pilgrim's Causeway to the tower gate prompt.
  Returning from the tower lands you at the gate arrival pad, which is unchanged, and you walk the same route back.
- **Access:** the owner-locked barrier stays at each plot's own gate. Bridges and the park are public.

## 5. Code changes by phase

### Phase 1: one source of truth for hub geometry
- **New** `src/ReplicatedStorage/Shared/Config/HubLayout.luau` (`--!strict`, tabs). It holds `ParkCentre`, `ParkRadius`, `PlotBearingsDeg`, `PlotGateRadius`, `PlotCentreRadius`, `IslandSurfaceY`, `CausewayWidth`, `CausewayStartZ`/`EndZ`, `KillZone` and `IsletRing`.
- It also has helpers: `PlotIslandCFrame(i)`, `PlotGatePoint(i)`, `ParkGatePoint(i)` and `BearingToWorld(deg, r)`.
- It lives in `Shared` because the client beacon controller and the server zones both read it.

### Phase 2: build the Commons
- **New** `src/ServerScriptService/BaseOverhaul/CommonsBuilder.luau`. It has one `Build(container)` and a local builder function per element from A to O, following `IslandBuilder`'s `makePart` / `Decorative` pattern.
- It outputs `BaseOverhaulGeometry.MastersCommons` (a Model).
- Small refactor: move `makePart` and `makeWedge` out of `IslandBuilder` into `BaseOverhaul/PartKit.luau`, so the island, the Commons and the walls share them instead of keeping a fourth copy.

### Phase 3: move the plots and rebuild the bridges
- `PlaceIslandsInRing.server.luau`:
  - Replace the `RingRadius` / `StartAngleDeg` maths, in both the bake path and the already-baked path, with `HubLayout.PlotIslandCFrame(i)`.
  - Call `CommonsBuilder.Build`.
  - Bump `OVERHAUL_VERSION` to 8, and add `MastersCommons` to the `alreadyBaked` check.
  - Re-centre the kill zone to `(0, -95, -500)`, sized 3400 × 8 × 3400.
  - Re-centre the background islets on the park, at a radius of 1450 to 1650.
  - Fix the stale "5 islands / 72°" comments while there.
- `BridgeBuilder.luau`:
  - Delete the plot-to-walkway spans.
  - Build 6 plot-to-park spans from `PlotGatePoint(i)` to `ParkGatePoint(i)` at `Y = 12`, keeping the rails and the `Barrier_Front` disable.
  - Build the `PilgrimsCauseway` span from `(0, 16, -386)` to `(0, 12, -480)`.
  - Keep the 120-segment walkway ring, but give its outer rail just one opening, at -90°.
  - `TowerEntranceApproach`, `TowerPlazaFoundation` and `TowerHubArrival` stay as they are.
- `TowerTraversalSetup.server.luau`: no change. It only falls back to creating `TowerHubArrival`.

### Phase 4: systems that depend on position
- `TowerFloorService.luau:361-364`: replace the 24 `HUB_BANK_i` annulus sectors with:
  - a 24-gon polygon of the park, `ZoneId = "HUB_COMMONS"`
  - 6 bridge rectangles, `HUB_BRIDGE_i`
  - a causeway rectangle, `HUB_CAUSEWAY`
  All of them use the same flags as today. Plot zones derived from `PlotSpawn` need no change, because they follow the spawn.
- The `rooms[0].Bounds` of ±1500 already covers the farthest point (about 1,301), so it needs no change.
- Leaderboards:
  - Delete `alignPlotLeaderboards` and the per-plot clones.
  - `PlaytimeStandBuilder`, `PlaytimeBoardRenderer` and `PowerBoardRenderer` currently search `WaitingRoomPlots` for boards. Point them at `MastersCommons.LeaderboardPavilion` instead.
  - The in-HUD leaderboard from PR #104 is unaffected.
- `PlotBeaconController.client.luau`: update the "ring radius ~650" note, and check `OTHER_BEACON_MAX_DISTANCE` against the new spread. Plot-to-plot distance is now at most about 900, down from 1300, so the current values are safe.
- **New** `StarterPlayerScripts/Rendering/CommonsController.client.luau`:
  - spins and bobs everything tagged `CommonsSpinner`
  - fills in the gate tablets' owner names from the plot owner attributes

### Phase 5: rebake in Studio and save
Run the overhaul in Edit mode through Studio MCP with `forceRebuild` (by setting the version) so the baked geometry in the place file matches. Then save the place. The old `Plot_N` bridge parts are destroyed as part of the `IslandTowerBridges` rebuild.

### Phase 6: docs
In `docs/GAME_DESIGN.MD`:
- §3.1: replace the ASCII diagram with the new world map (3.2 above).
- §3.2: in the zones table, replace the "6 Floating Fortress Plots `R = 650`" row with the horseshoe numbers, and add a **Masters' Commons** row and a **Pilgrim's Causeway** row.
- §3.2: update the safety plane to 3400 × 3400 centred on `(0, -95, -500)`.
- §3.4: the "Perimeter Drawbridge" now connects to the Commons rim instead of the highway.
- **New §3.5 The Masters' Commons**: a condensed version of section 4 of this file.

### Phase 7: stretch goals (separate PRs)
- The squad plinths show the top-Power player's current squad, using `HeroRegistry` templates and refreshing every 60 s.
- The Biome Stones light up from the highest floor any player in the server has cleared. This is computed from live profiles; nothing new is persisted.

## 6. Risks

- **Front gap between neighbouring plots is about 16 studs.** The chamfered corners make it read wider, but if a future plot expansion makes islands wider than 260, raise `PlotGateRadius`. The `HubLayout` spec test (below) catches this.
- **Baked place-file geometry.** If Phase 5 is skipped, the runtime still rebuilds because the version changed, but the first server start pays the build cost. Bake it.
- **Pathfinding.** Heroes path from the plot to the tower over the bridges and the park. All slopes stay ≤ 15°, and steps stay ≤ 1 stud, except the 4-stud terrace, which has ramps. Hedges and benches are deco or low enough not to block navigation.
- **Part count.** About 1,100 parts is modest next to the tower's roughly 1,500 ring parts. Watch it in the MicroProfiler on mobile.

## 7. Tests

- **New** `tests/hublayout.spec.luau`, pure Luau with no Roblox APIs. It asserts that:
  - no two plot rectangles (260 × 336, oriented) overlap
  - every plot rectangle is ≥ 420 studs from the tower centre
  - every bridge is ≥ 100 and ≤ 160 studs long
  - every point is within the kill plane and `rooms[0].Bounds`
- Run `pwsh tests/run.ps1`, which compiles everything and runs all the specs.

## 8. How to test in Studio (after implementation)

1. Sync, press Play, and open the top-down view. You should see 6 plots in a horseshoe around a green round park, with the open side toward the tower gate.
2. From your plot spawn, walk out the gate and over your bridge into the park. Confirm the gate tablet shows your name.
3. Walk around the Masters' Loop and confirm that every gate opening lines up with its bridge, with no gaps or lips.
4. Cross the pool on the stepping stones and on the footbridge, climb the Overlook ramps, and step onto the dais tiers. There should be no stuck spots.
5. Go down the Pilgrim's Way and the causeway to the tower gate, and confirm the floor-selector prompt still fires. Then return to the hub and confirm you land on the arrival pad.
6. Carry loot into the park and confirm banking behaves per the `CanBankCargo` decision.
7. Jump off the park edge where there's no barrier (there shouldn't be one) and off a bridge. The catch plane should return you to your `PlotSpawn`.
8. Check the Leaderboard Pavilion boards update, and that the plots no longer have their own boards.
9. With 2 players, confirm each sees the other's beacon and plot name, and that you can't enter the other player's gate.
