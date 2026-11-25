# Tower Navigation & Squad Movement Architecture

This document defines the server-authoritative navigation contract, connector topology, active floor-run policy, assigned-squad policy, and client presentation rules for Infinite Tower.

## 1. Architecture Overview

Infinite Tower uses **one shared server-authoritative navigation solver** (`HeroNavigation.luau`) backed by **pure connector topology** (`TowerNavigationGraph.luau`) and **separate destination policies** (`SquadMovement.luau`) for active floor runs and assigned squads. Enemy AI (`TowerEncounterRuntime.luau`) shares `HeroNavigation` for patrol, chase, and home-return movement.

| Module | Responsibility |
| --- | --- |
| `src/ReplicatedStorage/Shared/Config/TowerLayout.luau` | Authored platform bounds, connector IDs, usable widths, flat landing extents, slope/stair bounds, and clearance lanes for the 5 canonical layouts, plus each floor's own seeded variation (`Get(index, floorId)`, `ForFloor`, `Validate`; see §2a). |
| `src/ServerScriptService/Core/TowerRoomBuilder.luau` | Constructs terraces, full-width flat landings, flared approaches, flush sloped decks/stairs, tapered curbs, and chasm return ramps. |
| `src/ServerScriptService/Core/TowerPropClearance.luau` | Enforces clear walkways, landing footprints, and grounded prop rules across all 50 biome floors. |
| `src/ServerScriptService/Core/TowerNavigationGraph.luau` | Pure topology graph: platform/connector location (`Locate`), shortest connector routes (`Route`), directed mid-connector progress preservation, and route cost (`Remaining`). |
| `src/ServerScriptService/Core/HeroNavigation.luau` | Feet-coordinate movement solver (`Step`), ground/clearance sweeps, friendly/prop avoidance, bounded async `PathfindingService` queue (`MAX_IN_FLIGHT = 6`), and signed-progress recovery. |
| `src/ServerScriptService/Combat/SquadMovement.luau` | Active floor-run trail/formation policy (`UpdateMaster`, `PlanActiveFollow`) and assigned-squad objective/regroup/target-failure policy (`SelectAssignedAnchor`, `PlanAssignedRegroup`, `HandleCombatMoveOutcome`). |
| `src/ServerScriptService/Combat/HeroCombatMovement.luau` | Pure fight positioning for a hero with a target: telegraph evasion, ranged kiting and spreading, melee ring slots (§6). |
| `src/ServerScriptService/Combat/HeroTargeting.luau` | Per-tick combat target retention, focus priority, squad assist, connector `RouteCost` scoring, and generation-scoped unreachable target exclusion. |
| `src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau` | 60 FPS visual interpolation of 5 Hz server snapshots with ramp/landing support clamping and distinct teleport snapping. |

## 2a. Per-Floor Layouts

Every floor has its own variation of its canonical layout, unless it is hand-authored (`AUTHORED` in `TowerLayout`: fixed terrace spots, optional `ExtraPlatforms` such as floor 2's `AqueductNorth`, explicit `Stairs` overrides forcing `Kind = "STAIRS"`, and its own path list, e.g. floor 1's east gallery joins the Crossing instead of the Apex and floor 2 breaks the central viaduct span to force a detour through `Mill Ruin`, and floor 6 has no path across its glowpool; core terrace ids keep their roles, same `Validate` checks), seeded by its floor id (`TowerLayout.Get(index, floorId)`): galleries, bastions, the Crossing and the Apex shift, resize and change height, each side on its own, and the long climbs to the Apex may wind through a small `Bend_<From>_<To>` terrace (`Bend = true`, no camp) as two ordinary connectors. The Sanctuary and the Basin never move. A variation is kept only if `TowerLayout.Validate` finds nothing the canonical layout does not already have (terraces overlapping or leaving the room, connectors running over a terrace or crossing, cramped camps); otherwise the next seed is tried, and the canonical layout is the fallback.

Every consumer passes the floor id: `HeroNavigation` and `SquadMovement` keep one graph per floor, and camps, patrol routes (which follow both connectors of a bent path, and route `BASTION_RING` across `Crossing` on an authored floor whose bastions meet at the Crossing such as Floor 9), boss portal spots, clearance lanes, the Relic Rain ramps and camp scaling all read the floor's own layout. `TowerNavigationGraph` needs no change: a bend terrace is just another node. `tests/tower-layout-variants.spec.luau` checks all 50 floors: determinism, validity, slopes, camps and patrols on walkways, and a route from the Sanctuary to every camp and terrace.

Authored floors may override their room size (`TowerLayout` `AUTHORED[n].Size = { Width, Depth, Height, Bottom? }`, Floor 21 first); lanes, patrols, portals and the navigation graph all read the built layout, so nothing else keys room size on the floor index. A top-level `DirectTerrain` floor can name its ground palette beside it (`Surface`, e.g. `SOOTWRIGHT`), and its `TerrainFeatures` may include `SLAG_TIP` heaps (mountain kind, kept off walkways by the usual caps), `POUR_PIT` molten cauldron pits (carves a noisy elliptical lava pool with a basalt/cracked-lava rim berm, Floor 24), and `LAVA_FALL` volcanic wall cascades (mountain cliff chutes painted with vertical `CrackedLava` ribbons, Floor 24). `GirderSpans` (Floor 22) marks suspended links built as free-hanging crane girders: same connector, lane and navigation contract, only no trestles under them. `StonePiers` (Floor 23+) builds the named suspended decks and spans on soot-brick piers out of the lava instead of iron gantries and trestles; navigation is unchanged. Floor 26 adds the `KAIRN` path style and surface and the `KAIRN_STONE` masonry (dry-stone platforms; its suspended links are dry-stone causeways whose exposed landings are solid slate aprons, like `FOUNDRY_IRON`'s), and two terrain features: `HEADWALL` (a sheer, turf-capped rock block of mountain kind, so the usual moat and caps keep it off every walkway and it offers no way up) and `LIGHTNING_SCAR` (a strike crater's low ring wall on open ground). A feature's own ground material (`Field.Accent`: slag, scorch, a headwall's turf and rock ribs) is painted everywhere except walkways and water. An authored floor can also spread its boss portals apart on the Apex (`Portals = { Spread = n }`, Floor 27), leaving room for a landmark between them. Floor 28 adds the `SKYBRIDGE` masonry (its suspended links are rope-and-plank suspension bridges whose pylons, cables, hangers and hand ropes are all dressing around the same straight deck and invisible railing colliders; exposed landings are slate aprons as with `KAIRN_STONE`, and its decks are 10-stud dry-stone caps set into the terrain needles under them) and the `SEA_STACK_APRON` terrain feature (`Steep`: every terrace and walkway apron falls that many times as steeply, so terraces stand as sheer needles and nothing on their flanks is walkable; the abyss floor is painted slate). Floor 29 adds the `CLIFF_FAULT` terrain feature (`Z`, `Top`, `Amp`: north of a wavering east-west line the ground is a plateau `Top` studs over the chasm floor behind a sheer, stepped scarp. The plateau is a floor that walkway caps never dig under, so every walkway north of the line must stand above it; hung and suspended links over it rest on it) and `Viaducts` (`{ [linkId] = true }` on a `KAIRN_STONE` floor: that suspended ramp or stair rides on open round arches on tall piers out of the chasm instead of solid dry-stone walling; the piers are solid, the arches and copper conduits dressing). Floor 30 adds the `CLOUD_EYE` terrain feature (`X`, `Z`, `RX`, `RZ`: suppresses open-ground hills inside the central caldera ellipse and leaves it bare wet slate at `Bottom` so sculpted cloud-vortex meshes fill the abyss cleanly beneath all walkways), per-link `Skybridges` (`{ [linkId] = true }` on a `KAIRN_STONE` floor: renders individual links—Floor 30's West Wing spans—as `SKYBRIDGE` rope-and-copper suspension bridges alongside dry-stone East Wing causeways, with identical deck/landing/railing collision and navigation), and per-link `CopperCoping` (`{ [linkId] = true }`: adds hammered-copper parapet coping along a causeway's curb tops as non-colliding dressing).

On standard natural floors (GDD §3.3) the voxel terrain (`TowerTerrain`) never adds a way onto a walkway: within reach of a terrace, ramp or landing it stays a full voxel (`UNDER = 4.5` studs) under its top and edge (voxel surfaces render a little off their requested height), never digs under the chasm floor (whose invisible Ground slab is the walking surface there), and falls away at 1.4 studs per stud or steeper, beyond `Navigation.Ground`'s 0.65 normal limit. On floors that declare `DirectTerrain = true` in `TowerLayout.AUTHORED` (`verdant:1..5` and grounded desert flats on `ashen:1`), terrain-walking `Part` slabs, landings, and ramps are non-colliding (`CanCollide = false, CanQuery = false, Transparency = 1`) so actors walk directly on `Terrain` without floating over contour dips, `TowerTerrain` aligns walk surfaces flush by subtracting `RES / 2` (`2.0` studs) with `ownSurface` priority and paints from the biome's `Palettes` (`Grass`/`LeafyGrass`/`Ground` in Verdant; `Sand`/`Sandstone`/`Ground`/`Basalt` in Ashen Dunes, driven by `TerrainFeatures`, `Liquid`, `Decks`, `Suspended`, and `Masonry` on `AUTHORED`), `Include`-filtered server raycasts (`TowerFloorService.commit`, `GroundDrop`, `TowerEncounterRuntime.findGrounded`) include `workspace.Terrain` (`IgnoreWater = true`), while architectural stone decks/stairs and suspended bridges remain solid `Part`s. A mountain may rise beside a walkway only as a canyon wall: past a 6-stud moat and at least 8 studs above every walkway in reach. Ramp curbs stay as invisible colliders, and the chasm's Ground slab stays as an invisible catch.

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

## Authored terrain walkways (`Terrain.Direct`)

On a hand-authored floor with `Terrain.Direct` (floor 6), natural terraces, landings and ramps are the voxel terrain itself: their parts are invisible proxies (`CanCollide`, `CanQuery` and `CanTouch` off), and `TowerTerrain` puts the field 2 studs (`SOFT`) under each walking plane, which is where smooth terrain renders its surface. Built decks (`Terrain.Decks`, e.g. the Sanctuary and floor 6's Veinspan bridge) and stair treads stay solid parts. Navigation needs no change: `HeroNavigation` raycasts exclude only the actors, so they hit the terrain, and the connector graph is the same layout geometry. Server raycasts that include only the room model (`TowerFloorService` arrival and loot drops, `TowerEncounterRuntime.findGrounded`) also include `workspace.Terrain` and ignore water.

Floor 31 (Blighted Verge, `corrupted:1`) adds three walkway options to the same system:

- **`Terrain.BridgeStyles`**: a hung walkway (`Terrain.Bridges`) can be a `LOG` instead of planks. The ramp part stays as the solid walking surface but is hidden, and a colossal fallen trunk with a split limb is drawn under it as non-colliding dressing, with no rope rails. Its landings are solid, unseen proxies. Navigation is unchanged.
- **`Terrain.DeckLooks`**: a built deck's colour and material (for example fieldstone or a log floor) without a masonry style.
- **Fords** (`TowerLayout` `Fords`): which links cross the floor's brook. These are data for the specs (no route to the Apex avoids them), not a new connector kind: two are hung walkways and two are earthen causeways.

Set pieces placed at a deliberate height in water (a mill footing, a weir, lilies) are tagged `OnTerrain`, and hanging ones (lanterns) are listed in `TowerBiomeAssets.AirborneKinds`, so `TowerPropClearance.Settle` leaves them where they are.

Floor 32 (Twisted Orchard, `corrupted:2`) adds two authored terrain landforms to `Terrain.Direct`:

- **`Terrain.Slope`**: a continuous south-facing slope (`ZStart`, `ZEnd`, `YStart`, `YEnd`, optional `BenchSpan`/`BenchStep` E–W orchard benches and `FadeNorth` drop into a bowl behind the crest). Because it keeps kind `CHASM`, walkway caps and aprons protect every terrace and ramp identically to flat chasm ground.
- **`Terrain.Ridges`**: polylines of `{ X, Z, Top }` points forming continuous earthen ridge crests (the Graft Ridge). High crests take kind `MOUNTAIN` so walkway caps never crater the solid ridge between terraces while walkways still take priority inside `MOAT`.

Floor 33 (Briar Labyrinth, `corrupted:3`) adds a corrupted terrain surface/relief tier (used from Floor 33 onwards across the deep Corrupted Grove) and a second `Terrain.BridgeStyles` option:

- **`Surfaces.BLIGHT` & `Terrain.Blight`**: violet cobble trails (`Cobblestone`), deep indigo blighted earth (`Concrete`), blackened basalt cliffs/seams (`Basalt`), dark violet-slate banks (`Pavement`) and abyssal pit beds (`Asphalt`) with ridged corruption veining and sunken pit fissures/jagged crags (`FissureDepth`, `CragHeight`). Reuses existing place-wide material colours so Floors 1–32 remain byte-identical.
- **`Terrain.BridgeStyles = "HEDGE"`**: hung labyrinth walkways over the sunken thorn pit keep their solid timber/earth deck and replace rope railings with 5.4-stud-tall clipped hawthorn hedge walls, glowing violet-magenta briar vines and timber posts placed strictly outside `UsableWidth` (non-colliding dressing; navigation is unchanged).
- **`Terrain.BridgeStyles = "BRANCH"`** (Floor 34, Heartrot Stronghold): hung tree-to-tree branch bridges over the rot bog carry gnarled dark-wood handrails, rope lanyards and glowing violet-magenta sap tendrils strictly outside `UsableWidth` (non-colliding dressing; navigation is unchanged).
- **`Terrain.BridgeStyles = "ROOT"`** (Floor 35, Sovereign's Grove): hung root-burl walkways over the sap mire carry blackened root-bark curbs laced with glowing violet-magenta heartrot veins strictly outside `UsableWidth` (non-colliding dressing; navigation is unchanged).

Floor 36 (Drowned Steps, `sunken:1`) adds four options to the same system:

- **`Terrain.BridgeStyles = "CAUSEWAY"`**: a hung walkway drawn as a flagged limestone causeway on round-arched piers standing in the surf, with a low parapet and marble posts outside `UsableWidth`. The ramp part stays the solid walking surface; piers, arches and parapets are non-colliding dressing. Navigation is unchanged.
- **`Terrain.Shapes[id].Sheer`**: a rounded terrain terrace whose apron drops as a near-vertical cliff (about 3.4–4.2 studs of drop per stud, against 1–1.6 for a bank). It only makes the ground steeper, so it never offers a new way onto a walkway.
- **`Terrain.WallBand.NorthScale`**: scales the wall band's height along the north wall (blending back to full height toward the corners), so a far backdrop (the Tidewall) shows over a low shore.
- **`BrokenFlight`** (`TowerLayout`): the pair of terraces the fallen middle flight once joined. It is spec data (no link joins them, and the Apex stays reachable), not a connector.

Floor 36's shrine canopy and its great bell hang over the Apex camp above the camp band (`TowerBiomeAssets.AirborneKinds`), and its bell arches span the Pilgrim Stair on purpose (`NerethBellArch` is exempt from the walkway and camp clearance, like `RampArch`): their openings are wider than the flight and their piers stand outside the lane.

Floor 37 (Coral Cloister, `sunken:2`) adds two options to the same system:

- **`Terrain.Pools[i].Round`**: optional superellipse exponent for an authored pool (`(|dx|/RX)^p + (|dz|/RZ)^p <= 1`), so cloister garths carve as rounded squares instead of ovals. Pools without `Round` keep the exact ellipse formula.
- **`Terrain.BridgeStyles = "ARCADE"`**: a hung `STAIRS` bridge over water carried on arched limestone piers underneath, with a low limestone balustrade, tall coral-grown columns strictly outside `UsableWidth`, and overhead transverse arches ≥ 20 studs clear above the treads (non-colliding dressing inside `BridgeCurb`; navigation is unchanged).

Floor 37's flush tide-spiral floor mosaics (`CloisterFloorMosaic`, non-colliding and `CanQuery = false`) are exempt from walkway and camp clearance so they lie cleanly across Lay Court and Chapter Isle without affecting grounding or combat.

Floor 38 (Tidal Channels, `sunken:3`) adds stepped canal waterworks to `Terrain.Direct`:

- **`Surfaces.DEEPWARD`**: wet storm-tide masonry surface using zero-noise flat shared terrain materials (`Ground` and `LeafyGrass` on walk/trail planes so every terrace and ramp renders flush with zero voxel-bump drift, `Slate` banks, and `Basalt` cliffs/peaks/lock beds — no blocky materials, no Fungal-owned materials, and no edits to shared `MaterialColors`).
- **`Terrain.Locks`**: an array of `{ X, Z, Width, Depth, Level, Bed, Wall }` lock chambers whose beds carve as `POOL`, whose cheeks raise retaining lips around each chamber, and whose stepped water heights are exported via `field.WaterLevel(x, z)` and written column-by-column in `TowerTerrain.Build` so canal water steps up lock by lock (`-2 → 4 → 10 → 16 → 22`).
- **`Terrain.BridgeStyles = "LOCKGATE"`**: hung canal and side-channel bridges over the locks keep their solid wet timber-and-bronze walking deck and add hanging V-mitre lock gates with aqua tide-wave runes and foaming overflow curtains underneath, timber handrails/balance beams strictly outside `UsableWidth`, and an overhead mid-span bell gallows with at least 19 studs of vertical headroom (all non-colliding dressing; navigation is unchanged).
- **`Terrain.BridgeStyles = "WALLWALK"`** (Floor 39, Pearlguard Vault): an elevated flagged-limestone parapet walkway spanning between the inner bastion towers (`WestBastion → EastBastion`) atop a battered curtain wall dropping beneath the deck to screen the lower inner ward from arrival, with crenellated merlons and hooded aqua braziers strictly outside `UsableWidth` (non-colliding dressing; navigation is unchanged).
- **`Terrain.Maelstrom` & `Terrain.BridgeStyles = "CHAIN"`** (Floor 40, Leviathan's Basin): `Terrain.Maelstrom` carves a circular underwater whirlpool funnel (`kind = "POOL"`) with 6 logarithmic spiral rock ribs around the sheer central dais pillar (`Shapes.Apex.Sheer = true`), while the animated multi-layer whirlpool swirl, subtle water-tornado funnels, drifting debris, quality-scaled eye spray, and orbiting overhead Sea-Dome silhouettes run purely client-side (`MaelstromVortexController.client.luau`, `CanCollide = false`, `CanQuery = false`, exempt in `AirborneKinds`, `WalkwayExemptKinds`, and `CampExemptKinds`). `BridgeStyles = "CHAIN"` dresses the twin `STAIRS` links onto Leviathan's Dais (`WestAnchor_Apex`, `EastAnchor_Apex`) with weathered stone underside stringers, bronze cross-bearers, stabilizing belly chains, carved stone end-piers, and sagging catenary heavy bronze suspension chains strictly outside `UsableWidth` (never overhanging the boss arena; navigation is unchanged).

Floors 41–45 (Astral Archives, `astral:1`–`astral:5`, `PathStyle = "HALCYR"`) extend the same `Terrain.Direct` system with open-sky Starfield rooms, two non-blocky shared-material surfaces, three terrain landform options and five physical bridge styles:

- **`Surfaces.HALCYR` (Floors 41–42) & `Surfaces.RIFTWARD` (Floors 43–45)**: use only uncoloured or already-coloured shared materials (`Limestone`, `Salt`, `Slate`, `Basalt`, `Glacier`), avoiding `BlockyMaterials`, Fungal-owned materials and `Mud`, so Floors 1–40 and 46–50 stay unchanged.
- **`Shapes[id].Float = { Under = n }`** (Floors 41–42 floating isles): renders a terrace's terrain as a tapering, noise-warped underside cone ending `n` studs below its top (slate body with a `Glacier` star-glass tip) with open air beneath down to the Nebula Floor (`BaseSample`), while landing strips attached to floating isles never raise ground pillars down to the floor.
- **`Shapes[id].Scarp = { Sides = { ... }, Height = n }`** (Floor 43 fault plates) and **`Shapes[id].Sheer = true`** (Floor 45 dais pedestal): drops the apron steeply (≤ 7.5 studs horizontally) on the listed fault sides (`"N"`, `"S"`, `"E"`, `"W"`) or all sides while keeping normal aprons elsewhere.
- **`Terrain.Rifts`** (Floors 43–45): carves polyline cracks or straight ward moats (`Points = { { X, Z, HalfWidth? } }`, optional `Pinch = "W" | "E"`) down to `Bottom - 4` (`Glacier` rift beds) with FBM-warped cliff walls, pinching closed at the named wall and never cutting under solid non-bridge terrain terraces or earthen ramps.
- **`Terrain.BridgeStyles`** (all physical walkways; dressing strictly outside `UsableWidth`, navigation unchanged):
  - `"STARGLASS"` (Floors 41, 42, 45): solid lapis-and-star-glass deck on brass cross-ribs with pale starlight-gold edge-light and constellation spine inlay.
  - `"ORBIT"` (Floor 42): brass orrery-arm conjunction span with twin brass girder rails, gear posts and a non-colliding outer counterweight globe.
  - `"SHARD"` (Floor 43): dark-slate and vellum-limestone fractured floor-slab span with jagged broken-edge side teeth and brass under-ties.
  - `"WAYGATE"` (Floor 44): pale vellum limestone deck with gold rune bands and lapis-brass parapets passing physically through a standing Waygate ring-portal.
  - `"SUTURE"` (Floor 45): dark ebony shelf-plank bridge lashed across the Rift with brass chains and pale starlight-gold suture stitches.
  - `"CHAINFORD"` (Floor 46): blackened-iron diamond-plate grate spanned across braided Undertow channels on chain bolsters with bone-white limestone edge guides and iron chain bollards (a squad that steps into a channel walks back out by the Basin return ramps).
  - `"PROCESSIONAL"` (Floor 47): obsidian processional deck and `StationW`/`StationE` stairs with matte wine-crimson `Fabric` center runner, bone-white border flags, flanking statue plinths and draped wine banners outside `UsableWidth`. Closed-loop `Terrain.Rifts` (`Loop = true`) carves the void moat around the central Crimson Bier mesa.
  - `"CATENARY"` (Floor 48): blackened-iron diamond-plate span suspended across open void with heavy transverse iron ribs, under-spine, tall iron anchor pylons and parabolic catenary suspension chains/hanger rods outside `UsableWidth` (a squad that falls off walks back up from the void floor by the Basin return ramps).
  - `"DRAWBRIDGE"` (Floor 49): iron-banded obsidian drawbridge deck and stairs across the keep's closed-loop Undertow moat (`Loop = true`), with riveted iron curbs and taut diagonal winching chains ascending to gate-side piers outside `UsableWidth`.
  - `"THRONE"` (Floor 50): imperial obsidian limb treads/decks with riveted iron cross-bands, bone-white limestone coping and sparing old-gold crown trim.
