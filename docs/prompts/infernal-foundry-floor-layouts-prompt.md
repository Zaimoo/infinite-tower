# Prompt: Infernal Foundry — a Unique Layout for Every Floor (Floors 21–25)

Copy everything below the line into a Claude Code session opened at the repo root.

> **Written 2026-11-20.** Four biomes are authored and merged on `main`: Verdant Ruins (1–5), Fungal Hollow (6–10), Ashen Dunes (11–15) and Frozen Citadel (16–20). Their prompts are in `docs/prompts/`, and the fix commits in `git log` carry the lessons. This brief builds on all of them.
>
> **The escalation rule (Part 2): every floor is bigger, richer and more varied than the one below it.** Every Infernal floor carries more assets, more variety, a grander scale and a more elaborate layout than any earlier floor at the same position in its biome (Floors 1–20). Each Infernal floor must also beat the Infernal floor below it.
>
> **Status (2026-11-20): All five Infernal Foundry floors (21, 22, 23, 24 and 25) are built** on branch `feat/infernal-floor-21`, from Part 3's coordinates and reference images (a rail yard round a turntable; an assembly hall under a gantry crane; a rail causeway over a lava lake to a furnace door; an iron-walled three-strip fortress over two lava channels and The Pour; and the Titan's Crucible hourglass boss arena crowned by the 179.5-stud Great Crucible). Floor 25 keeps the validated 15/16/13 hourglass pinch layout tightened to a punchier `740 × 795 × 250` (`Bottom = -6`, area 588,300 > Floor 24's 579,150, `170 × 124` dark-iron boss dais, every route passing Pour Gate, `LOWER_PINCH` / `UPPER_PINCH` / `CRUCIBLE_RING` patrols), adds `TowerSetPieces/InfernalFloor25.luau` (39 spec-checked footprints, 179.5-stud Great Crucible behind the dais, zero overhang over the arena), adds `FloorGrades[25]` (molten gold under-light under a dark vault), and adds `generate_infernal_f25_kit.py` (12 templates). Floor 24 keeps Part 3's exact validated 14/14/12 layout (`715 × 810 × 230`, `Basin` linking only to `WestGallery` — note: in a `715 × 810` room, Sanctuary Z+371 to Apex Z−320 is 691.6 studs straight-line vs 1.5× canonical F4 = 683.0, and the west-only entry routes in 906.4 studs / 1.99×, preserving the signature shape without shrinking the room), adds `POUR_PIT` and `LAVA_FALL` terrain features, splits its set pieces into `TowerSetPieces/InfernalFloor24.luau` (18 landmark groups, 37 spec-checked footprints, 141.8-stud Citadel Keep), adds `FloorGrades[24]` (siege-red night with cool steel-blue fill), and adds `generate_infernal_f24_kit.py` (12 templates); `TowerRoomBuilder` also renders solid visible diamond-plate bridgehead aprons on exposed `FOUNDRY_IRON` landings so every diagonal/chasm span joins flush. Floor 23 moved its Furnace Mouth 10 studs south (Z −285) and its north span and bays 5 studs south (Z −195, the span 70 deep) so the walk stays within 1.5×, added `StonePiers` and `generate_infernal_f23_kit.py` (11 templates). Floor 22 added a loading ramp `Basin→Crossing` (12 links), because the girder-only route walked 1.9× the canonical distance; it also added `GirderSpans` (free crane spans), `TowerSetPieces` helpers shared by every Infernal floor, and `generate_infernal_f22_kit.py` (12 templates). For Floor 21: Done: the `Size` override (§5.1), `AUTHORED[21]`, the `SOOTWRIGHT` path style and surface, `FOUNDRY_IRON` masonry (decks, gantry, girder bridges, iron stairs), the `SLAG_TIP` feature, `tools/blender/generate_infernal_f21_kit.py` (12 templates), `TowerSetPieces/InfernalFoundry.luau` (landmark footprints are spec-checked against lanes and camps), `FloorGrades[21]` and the specs. Not done yet, and still owed before merging: the schema merge and set-piece registry (§5.2), the census script (§6; Floors 21–25 set `FloorNLandmarks`, `FloorNProps` and `FloorNGroundCover` attributes on their `BiomeAssets` model for it), the Heartbeat (§5.6), the `TowerDetail` culling tier (§5.8), and importing the Floor 25 kit (and any remaining kits) into the live place (§5.4).
>
> The layout half of that is already proven: the coordinates in Part 3 were run through `TowerLayout.Validate` and `PatrolRoutes` from `origin/main`, with the room-size override this brief adds (§5.1). They have no problems, every link is at or under 15°, the mob and Elite totals are right, and the terrace, link and height-level counts climb strictly from floor to floor, above every earlier floor at the same position. The asset half is a set of measured targets that your build must meet.

---

## Role

You are a two-specialist team speaking as one. Say which role you are speaking as when it matters.

**Warden** is a senior level designer and gameplay engineer for *Infinite Tower: Become a Master!*, a Roblox squad-command action RPG. Warden owns topography, sightlines, combat spaces, pacing, navigation and the `TowerLayout` connector contract. Warden thinks in walkable surfaces, link slopes, camp spacing, leash radii and the route a squad of five takes from the Sanctuary to the Apex.

**Forgewright** is a senior environment artist and world-builder. Forgewright owns the ecosystem, the machinery, landmarks, materials, lighting and atmosphere. They build from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the earlier biomes were built. Every prop has a reason to exist in the ecosystem and reads clearly from the gameplay camera. Forgewright treats every floor as a step up in spectacle from the one below it.

Neither of you breaks the runtime contracts described below.

## Before you start

1. **`git pull` on `main` first:** a local checkout may be behind. Branch `feat/infernal-foundry-floor-layouts` from the updated `main`. Use conventional commits.
2. Follow `CLAUDE.md` and `AGENTS.md`. Use the `roblox-world-building`, `roblox-luau`, `roblox-npc-ai` and `roblox-performance` skills.
3. Read `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, the hand-authored floors 1–20) and the lighting section, `docs/TOWER_NAVIGATION.md`, and `reference/infinite_towers_biomes.md` §5.
4. Read all four earlier floor prompts, latest first: Frozen, Ashen, Fungal, Verdant. Read their status notes and their engineering parts. Then read `git log --oneline -- src/ServerScriptService/Core/Tower*.luau src/ReplicatedStorage/Shared/Config/TowerLayout.luau` and open every `fix(...)` commit: each one is a lesson.
5. Read the authored-floor code end to end:
   - `TowerLayout.luau`: `AUTHORED[1..20]`, `build`, `Validate`, `PatrolRoutes`, `Lanes`, `PortalSpots`.
   - `TowerRoomBuilder.luau`: `MASONRY_STYLES`, decks, suspended links, stairs, curbs, walls and the vault.
   - `TowerTerrain.luau`: `Palettes`, `Surfaces`, `MaterialColors`, every `feat.Kind`, and the `Liquid` handling.
   - `TowerBiomeAssets.luau`: the per-floor `layout.Authored == ...` set pieces, `reservedSpots`, and the section 7 ecology.
   - `TowerBiomeKit.luau` and `TowerKitProps.luau`: `ExtraTemplates`, `Has`, `Ready`.
   - `HubLighting.luau`: `FloorGrades`.
   - `EffectCullingRules.luau` and `HubEffectCulling.client.luau`.
   - `tests/studio-tower-biome-kit-import.luau` and `tests/studio-tower-prop-audit.luau`.

## The goal

The five Infernal Foundry floors (21–25) still use the seeded generic layout and the generic Infernal props. Give each one its own hand-authored topography, built around one ecosystem, so that each floor has a different shape, route and combat rhythm. Each must be **the most lavish floor in the tower so far, and less lavish than the next**. The other biomes stay exactly as they are in this change.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, machine and creature traces back to this ecosystem. If a prop doesn't fit, cut it. More assets means more *reasons*, not more filler.

### The Sootwrights

The Sootwrights were a guild of smith-artificers who hollowed out the mountain over the **root of the Ember Vein**. The Ember Vein is the magma vein the Varrash tapped from above in the Ashen Dunes; keep that continuity light, as one line of flavour. The Sootwrights forged the weapons of legend.

Their architecture is basalt brickwork bound with black iron: riveted plates, brass fittings gone green-black, diamond-plate floors, furnace mouths, flues, chains, cranes, rail lines and bellows ducts. Their sigil is the **hammer-ring**: a hammer inside a ring of gear teeth. It appears on gates, furnace doors, crane cabs and the Titan's chest.

### The Ember Titan and the Heartbeat

The guild's masterwork was the **Ember Titan**, an automaton built to run the Foundry forever. Its heart is "an anvil-forged heart pumping liquid fire" (the relic skin). When the guild died out, the Titan kept working. Its heart drives the whole Foundry like a body:
- the lava channels are its arteries
- the bellows are its lungs
- the drop-hammers are its pulse

It still forges Forge Constructs, and Cinder Imps are born from its sparks.

**The Heartbeat is the biome's through-line** (its Heartroot, Ember Vein or Stillcold). Every few seconds the whole Foundry beats as one:
- lava seams brighten
- distant drop-hammers thud
- steam vents puff
- sparks shower from the crucibles

The beat is faint on Floor 21 and full on Floor 25, where the heart is. It is client-side and cosmetic (§5.6).

| Floor | How strong the Heartbeat is | What the player sees |
| --- | --- | --- |
| 21 | Faint: the outer works | Slag tips, ore yards and a great rail turntable; hammer thuds far off; the sky still shows through the smoke |
| 22 | Steady: the assembly floor | A gantry crane carrying half-built Forge Constructs; chains and hooks; quench pools hissing |
| 23 | Loud: the furnaces | A causeway past open furnace bays; heat haze; the lava pulses with the beat |
| 24 | Hard: the defences | Iron bulwarks over lava strips; slag cannons, signal flames, flame-jet gates |
| 25 | Full: the heart | The Titan's crucible, its heart visible; every glow in the room beats with it |

### Living layers (use all of them on every floor, more of each the higher you go)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Fire** | Lava channels and pools, glowing seams, crucible pours, sparks and embers | Cosmetic: never a hazard, never part of a lane |
| **Iron** | Machinery, cranes, rails and ore carts, chains, pipes and bellows ducts, gears, anvils | The main skyline: big, readable silhouettes |
| **Stone** | Basalt brickwork, cooled slag crust, obsidian | Banded by soot near every flue |
| **Steam and soot** | Quench pools (dark liquid), steam vents, smoke plumes, falling ash | The atmosphere layer |
| **Ember life** | **Ember lichen** (orange crust on hot iron), **cinder blooms** (ash-grey flowers with glowing hearts, near vents), heat beetles on warm plates | The only "living" things: sparse, always near heat |
| **Work** | Tools, moulds, ingots, half-finished weapons and constructs, ledgers, coal | What makes the place read as a working foundry. It's the main source of the extra props: dense, varied, and grounded on every terrace |

### Food web (how the enemies fit, `MobCatalog` → `infernal_foundry`)

- **Cinder Imp** (`SMALL_BIPED`): born from the Titan's sparks, scavenging the slag. Put spark-showers and slag nests near their camps.
- **Forge Construct** (`ARMORED_BIPED`, hammer arm): the Titan's workers, still assembling. Put half-built construct shells, parts racks and assembly jigs at camps.
- **Bellows Imp** (support, `ROUSE`): imps pumping hand bellows to stoke their allies. Put bellows rigs and coal bins where they stand.
- **Molten Taskmaster** (`HEAVY_BIPED`, Elite, foundry chain): the overseers. Put chain winches and overseer platforms where Elites tend to lead.
- **Ember Titan** (`FORGE_COLOSSUS`, boss, Floor 25): furnace-bodied with articulated fists. Its moves are Anvil Hammer (`ARC`), Slag Quake (`SELF_DISC`) and Molten Core (`TARGET_DISC`).

The relic skins (`RelicConfig` → `INFERNAL`) are the Slag Iron Geode, the Ashen Crucible Urn, the Molten Reactor Core and the Heart of the Ember Titan. Echo them in set pieces.

### Ambient life (client-only, purely cosmetic)

Falling ash, rising embers over lava, steam puffs on the Heartbeat, spark showers from crucibles and anvils, heat shimmer, heat beetles, and soot from flues. The higher the floor, the more systems run (see the ladder). Everything is client-side, pooled, culled by distance, scaled by the Graphics quality setting (`SettingsGraphicsEngine`), and off at the lowest quality. Nothing replicates from the server.

---

## Part 2: The escalation ladder — every floor bigger, richer, grander

This is the standard for Floors 21–25, and for every biome after this one: Floors 26–50 continue the climb.

### 2.1 Layout and scale (already proven by the validator for the Part 3 coordinates)

| Floor | Room (W × D × H) | Terraces | Links | Height levels | Apex top | Earlier best at this index (terraces / links / levels) |
| --- | --- | --- | --- | --- | --- | --- |
| 21 | 480 × 525 × 160 | 9 | 9 | 8 | Y 20 | 8 / 8 / 6 (Floor 16) |
| 22 | 550 × 615 × 180 | 11 | 12 | 10 | Y 24 | 7 / 10 / 6 (Floors 2, 17) |
| 23 | 625 × 700 × 205 | 12 | 12 | 11 | Y 28 | 7 / 8 / 6 (Floor 18) |
| 24 | 715 × 810 × 230 | 14 | 14 | 12 | Y 36 | 8 / 11 / 7 (Floor 4) |
| 25 | 800 × 920 × 270 | 15 | 16 | 13 | Y 44 | 8 / 9 / 7 (Floors 5, 15) |

- *Terraces* counts every platform, including the Sanctuary and `ExtraPlatforms`.
- *Height levels* counts the distinct walk heights other than the Sanctuary's.
- Rooms grow from about 1.26× to 1.43× the canonical footprint for each floor index, with an authored `Size` override (§5.1). They still fit the 2,400-stud room grid.

### 2.2 Assets and variety (targets your build must meet; measured by the census in §6)

| Floor | New kit templates | Distinct templates placed | Landmark set pieces | Placed props (excl. ground cover) | Ground cover and small clutter | Tallest landmark | Ambient systems |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 21 | ≥ 6 | ≥ 16 | ≥ 10 | ≥ 260 | ≥ 180 | ≥ 80 studs | ≥ 4 |
| 22 | ≥ 7 | ≥ 19 | ≥ 12 | ≥ 320 | ≥ 220 | ≥ 95 | ≥ 5 |
| 23 | ≥ 8 | ≥ 22 | ≥ 14 | ≥ 380 | ≥ 260 | ≥ 110 | ≥ 5 |
| 24 | ≥ 9 | ≥ 25 | ≥ 16 | ≥ 450 | ≥ 300 | ≥ 130 | ≥ 6 |
| 25 | ≥ 10 | ≥ 28 | ≥ 18, plus one colossal centrepiece | ≥ 520 | ≥ 340 | ≥ 170 (the crucible) | ≥ 7 |

**Above the earlier floors too:** before building, run the census on Floors 1–20. Each Infernal floor's prop, template and landmark counts must be **at least 1.3× the highest earlier floor at the same index**. If 1.3× that number is higher than the table above, it becomes the target.

### 2.3 Variety and grandeur rules (judged in review)

- **No filler.** No single template makes up more than 12% of a floor's placed props (ground cover excluded).
- **Every terrace is a vignette:** at least 4 distinct prop kinds that tell what the place was for.
- **Every link is dressed at both ends:** clutter, signage, posts or machinery on the terrace, off the lane.
- **Three skyline layers on every floor:**
  - *near*: props on the terraces
  - *mid*: landmarks rising from the chasm or yard
  - *far*: a backdrop beyond the walls, such as a vault, distant furnaces or flues
- **Every floor introduces at least one traversal feature and one landmark type that no earlier floor in the tower has.** Part 3 names them.
- **Grander every floor:** landmark heights, room size, the number of moving (cosmetic) machines and the Heartbeat's reach all climb. Floor 25's crucible is the largest single prop in the tower so far.
- **Grounded and readable:** density never hides camps, telegraphs, loot or the route. Paths stay obvious from the gameplay camera.

---

## Part 3: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north (the Apex side). Y is the walkable top surface.

**Terrain terraces sit on multiples of 4 studs**: smooth terrain only renders exactly on those planes (the Fungal lesson). Terraces at other heights in the tables below are **built decks**, which can be at any height. Tune positions and keep the shape, the intent and the ladder; re-run the validator after every change.

**Already taken (don't repeat them):**
- Verdant:
  - 1: a spine with glades
  - 2: a broken diagonal aqueduct
  - 3: an east–west gorge with three bridges
  - 4: a walled ring with wall-walks
  - 5: a spiral around a cenote
- Fungal:
  - 6: a horseshoe around a pool
  - 7: a switchback up a gallery wall
  - 8: a chasm with a round cap deck and hung bridges
  - 9: a bastion ring through the Crossing
  - 10: an asymmetric radial spiderweb
- Ashen:
  - 11: a fork around a dune
  - 12: a single switchback
  - 13: a north–south ravine with two ledges and an arch
  - 14: a chokepoint gate and a split fortress
  - 15: a route over a fallen giant
- Frozen:
  - 16: a lakeshore road versus a floe chain
  - 17: a street lattice
  - 18: an inverted ravine (a central spine)
  - 19: two routes in two climates
  - 20: a cathedral nave

**Fixed on every floor:**
- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, 128 × 56, and `Basin` stays centred at X = 0.
- The `Apex` holds the Alpha or Boss summon and the boss portals.
- Arrivals land out of aggro.
- Mob totals and Elite counts are **16 / 22 / 25 / 35 / 35** and **1 / 2 / 3 / 4 / 4**. The bigger rooms **don't** add mobs. From Floor 23, at least one Elite camp stands above the entry level.
- `ExtraPlatforms` hold no camps: they are landmark and vignette space.
- From Floor 23, each floor has a second patrol route besides the entry loop.

### Floor 21: Slagworks Entry (`INTRODUCTION`)

*480 × 525 × 160, no chasm. Smoky red dawn.*

**Story beat:** the Foundry's outer works, where ore came in and slag went out. Every rail line meets at the **Great Turntable**.

**Shape: a hub with spokes and one rim link.** The yard crosses a weighbridge onto the Turntable. Four spurs leave it: the Sorting Shed, the Slag Tip, the Ore Crusher and the Coal Bunker. The Furnace Steps climb from it to the gate. One rim track links the Sorting Shed to the Ore Crusher. **New to the tower:** a hub that every route passes through, and a working rail network.

```
                    N (−Z)
        ┌─────────────────────────────────────┐
        │          [ FURNACE GATE ] Y20       │
        │ [ORE CRUSHER] Y16  ‖ (steps) [COAL BUNKER] Y6
        │      ‖    \        ‖        /       │
        │ [SORTING SHED]─[GREAT TURNTABLE]─[SLAG TIP]
        │      Y8            Y4          Y12  │
        │                [WEIGHBRIDGE] Y2     │
        │        ~~~ ORE YARD  Y0 ~~~         │
        │                    ‖                │
        │             [ SANCTUARY ] Y8        │
        └─────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Ore Yard | 0, 0, 120 | 400 × 90 | terrain |
| `Weighbridge` (extra) | Weighbridge | 0, 2, 54 | 60 × 20 | deck |
| `Crossing` | Great Turntable | 0, 4, −10 | 96 × 84 | deck |
| `WestGallery` | Sorting Shed | −150, 8, 0 | 84 × 76 | terrain |
| `EastGallery` | Slag Tip | 150, 12, −20 | 84 × 76 | terrain |
| `OreCrusher` (extra) | Ore Crusher | −140, 16, −130 | 70 × 60 | deck |
| `CoalBunker` (extra) | Coal Bunker | 140, 6, −140 | 70 × 60 | deck |
| `Apex` | Furnace Gate | 0, 20, −190 | 120 × 84 | terrain |

**Paths:** `Sanctuary→Basin`, `Basin→Weighbridge`, `Weighbridge→Crossing`, `Crossing→WestGallery`, `Crossing→EastGallery`, `Crossing→OreCrusher`, `Crossing→CoalBunker`, `Crossing→Apex` (STAIRS: the Furnace Steps), `WestGallery→OreCrusher` (the rim track).

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite), `EAST_GALLERY` 4. **Patrol:** `BASIN_LOOP`.

**Landmarks (≥ 10):**
1. The Great Turntable: rails to every spur, a cab hut on its rim, an ore train parked on it.
2. The weighbridge scale and its office.
3. The Ore Crusher's jaw machine.
4. Coal hoppers over the bunker.
5. The cooled slag waterfall down the Slag Tip.
6. The Sorting Shed: chutes and grates.
7. The Furnace Gate: hammer-ring doors, flues smoking above.
8. Rail buffers and a derailed cart.
9. A water tower on iron legs.
10. Ore heaps along the yard.
11. Far: the Foundry's flue stacks against the red sky.

**Ecosystem weight:** iron and slag; the faintest Heartbeat. This is the only Infernal floor with open sky.

### Floor 22: Molten Assembly (`EXPANDED_ENCOUNTER`)

*550 × 615 × 180, no chasm. Interior work-light.*

**Story beat:** the assembly hall. A **gantry crane** spans it on two piers. Its girder carries two hoists and a trolley, and half-built Forge Constructs still ride the hooks.

**Shape: a gantry "Π" with a stem.** Both piers rise from the yard. The girder runs pier → West Hoist → Crane Trolley → East Hoist → pier, tilted by a failed jack (Y 8 to 12). From the trolley, the stem climbs over the Inspection Gallery and up a stair to the Assembly Hall. Each pier also carries a dead-end loft: the Pattern Loft and the Control Cab. **New to the tower:** a walkable crane girder with machinery nodes.

```
                    N (−Z)
        ┌─────────────────────────────────────────┐
        │           [ ASSEMBLY HALL ] Y24         │
        │ [PATTERN LOFT] Y16  ‖ (stair)  [CONTROL CAB] Y20
        │      ‖        [INSPECTION GALLERY] Y18   ‖
        │      ‖              ‖                    ‖
        │ [W PIER]═[W HOIST]═[TROLLEY]═[E HOIST]═[E PIER]   the girder (suspended)
        │   Y8  \     Y9        Y10       Y11   / Y12
        │        \                             /  │
        │       ~~~ ASSEMBLY YARD  Y0 ~~~         │
        │                     ‖                   │
        │               [ SANCTUARY ] Y8          │
        └─────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Assembly Yard | 0, 0, 150 | 470 × 100 | terrain |
| `WestGallery` | West Gantry Pier | −175, 8, −20 | 80 × 68 | deck |
| `WestHoist` (extra) | West Hoist | −88, 9, −20 | 40 × 40 | deck (girder node) |
| `Crossing` | Crane Trolley | 0, 10, −20 | 72 × 56 | deck |
| `EastHoist` (extra) | East Hoist | 88, 11, −20 | 40 × 40 | deck (girder node) |
| `EastGallery` | East Gantry Pier | 175, 12, −20 | 80 × 68 | deck |
| `Inspection` (extra) | Inspection Gallery | 0, 18, −120 | 64 × 48 | deck |
| `PatternLoft` (extra) | Pattern Loft | −180, 16, −150 | 70 × 60 | deck |
| `ControlCab` (extra) | Control Cab | 180, 20, −160 | 66 × 56 | deck |
| `Apex` | Assembly Hall | 0, 24, −230 | 120 × 88 | terrain |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `Basin→EastGallery`, `Basin→Crossing` (the loading ramp, added when building: it keeps the walk within 1.5×), `WestGallery→WestHoist`, `WestHoist→Crossing`, `Crossing→EastHoist`, `EastHoist→EastGallery` (the girder: suspended), `Crossing→Inspection`, `Inspection→Apex` (**STAIRS**, `Stairs = { Inspection_Apex = true }`), `WestGallery→PatternLoft`, `EastGallery→ControlCab`.

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite). **Patrol:** `BASIN_LOOP` only.

**Landmarks (≥ 12):**
1. The gantry: lattice piers and a box girder.
2. Two girder hoists, each with a hanging construct at least 18 studs overhead.
3. The trolley and its hook.
4. The failed jack under the east end.
5. The master jig in the Assembly Hall with a nearly finished construct.
6. Rows of construct shells on jigs in the yard.
7. Quench pools steaming on the Heartbeat.
8. The Pattern Loft: wooden patterns and lathes.
9. The Control Cab: lever banks and gauges.
10. Parts racks.
11. Overhead lamp strings.
12. Conveyor rollers.
13. Far: the hall's ribbed vault and a second, idle gantry beyond the north wall.

**Ecosystem weight:** iron and steam, warm sodium light; more machinery than Floor 21.

### Floor 23: Furnace Causeway (`TERRAIN_VARIATION`)

*625 × 700 × 205, chasm (`Bottom = −4`) of lava. The hottest light so far.*

**Story beat:** the furnace line. A causeway in three spans runs north over the lava, with **furnace bays** opening off it on both sides, like ribs.

**Shape: a fishbone.**
- The spine is South → Mid → North Causeway, then a stair to the Furnace Mouth.
- Six ribs leave the spine, two per span, on alternate sides: West Smelting Bay and Slag Bay; East Quench Bay and Cooling Bay; Casting Bay and Blade Gallery.
- One east catwalk joins the Quench Bay up to the Blade Gallery.

The bays hold the camps and the vignettes. **New to the tower:** a three-span causeway over open lava, and the fishbone.

```
                         N (−Z)
        ┌──────────────────────────────────────────────┐
        │              [ FURNACE MOUTH ] Y28           │
        │                      ‖ (stair)               │
        │ [CASTING BAY] Y24═[NORTH CAUSEWAY] Y20═[BLADE GALLERY] Y22
        │                      ‖                  ‖ catwalk
        │ [COOLING BAY] Y14═[MID CAUSEWAY] Y12═[EAST QUENCH BAY] Y16
        │                      ‖      ≈≈ lava ≈≈       │
        │ [W SMELTING BAY] Y8═[SOUTH CAUSEWAY] Y6═[SLAG BAY] Y4
        │                      ‖                       │
        │          ~~~ CHARGING FLOOR  Y0 ~~~          │   return ramps from the lava shore
        │                      ‖                       │
        │                [ SANCTUARY ] Y8              │
        └──────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Charging Floor | 0, 0, 180 | 540 × 110 | terrain |
| `Crossing` | South Causeway | 0, 6, 40 | 64 × 100 | deck |
| `WestGallery` | West Smelting Bay | −140, 8, 40 | 84 × 76 | terrain |
| `SlagBay` (extra) | Slag Bay | 140, 4, 40 | 80 × 72 | terrain |
| `MidCauseway` (extra) | Mid Causeway | 0, 12, −90 | 60 × 80 | deck |
| `EastGallery` | East Quench Bay | 140, 16, −90 | 84 × 76 | terrain |
| `CoolingBay` (extra) | Cooling Bay | −140, 14, −90 | 80 × 72 | deck |
| `NorthCauseway` (extra) | North Causeway | 0, 20, −195 | 60 × 70 | deck |
| `CastingBay` (extra) | Casting Bay | −140, 24, −195 | 76 × 68 | terrain |
| `BladeGallery` (extra) | Blade Gallery | 140, 22, −195 | 76 × 68 | deck |
| `Apex` | Furnace Mouth | 0, 28, −285 | 124 × 84 | terrain |

**Paths:** `Sanctuary→Basin`, `Basin→Crossing`, `Crossing→WestGallery`, `Crossing→SlagBay`, `Crossing→MidCauseway`, `MidCauseway→EastGallery`, `MidCauseway→CoolingBay`, `MidCauseway→NorthCauseway`, `NorthCauseway→CastingBay`, `NorthCauseway→BladeGallery`, `NorthCauseway→Apex` (**STAIRS**), `EastGallery→BladeGallery` (the catwalk). Return ramps from the lava shore to the Basin.

**Camps (25, 3 Elites, at least one above the entry level):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (`Always`), `SPINE` = {Crossing, MidCauseway, NorthCauseway, Apex}, `CATWALK` = {EastGallery, BladeGallery, NorthCauseway}. On today's `main`, the generic builder finds no gallery route on this floor.

**Landmarks (≥ 14):**
1. Six furnace towers along the spine, mouths pulsing on the Heartbeat.
2. The tilting crucible in the West Smelting Bay pouring a Neon stream into a mould bed (the stream reaches the mould).
3. A slag-ladle cart tipping into the lava in the Slag Bay.
4. Quench tanks steaming.
5. Cooling racks of glowing blades.
6. Casting mould beds.
7. A blade gallery with finished weapons on display.
8. Causeway piers rising from the lava.
9. Bellows ducts along the spine.
10. A giant furnace door at the Mouth.
11. Coal carts on the Charging Floor.
12. A crane over the Charging Floor.
13. The lava lake with crust islands.
14. Far: the furnace hall's back wall of stacked flues.

**Ecosystem weight:** fire; white-orange glare and heavy bloom. **Test telegraph readability** (§5.7).

### Floor 24: Ironflame Bulwark (`ELITE_STRONGHOLD`)

*715 × 810 × 230, chasm (`Bottom = −4`) with lava strips. Siege-red night with cool steel fill.*

**Story beat:** the Foundry's defences. Two lava channels cut the floor into three north–south **strips**. The Sootwrights walled the strips with iron bulwarks and crossed the channels only at **sluice towers**.

**Shape: a weave across the strips.**
- The yard leads **only to the west strip**.
- The west strip climbs the West Gun Deck → Powder Store → West Bulwark Tower → the citadel, with a dead-end Signal Bastion beyond the tower.
- Or the route weaves east: Gun Deck → West Sluice → Ironflame Gate (centre strip) → East Sluice → East Foundry Deck → Hammer Hall → East Bulwark Tower → the citadel.
- North of the gate is the sealed Ironflame Forge (a dead end behind flame-jet "portcullises").
- The south of the centre strip is the **Pour**, a lava pit.

**New to the tower:** sluice towers standing in the lava channels, and strip-to-strip weaving.

```
                            N (−Z)
        ┌──────────────────────────────────────────────────┐
        │ [SIGNAL BASTION] Y32   [ IRONFLAME CITADEL ] Y36   [E BULWARK TOWER] Y30
        │       ‖                /                    \         ‖
        │ [W BULWARK TOWER] Y24     ≈ [IRONFLAME FORGE] Y20 ≈  [HAMMER HALL] Y18
        │       ‖                ≈        ‖           ≈          ‖
        │ [POWDER STORE] Y16     ≈ [IRONFLAME GATE] Y14 ═[E SLUICE] Y12═[E FOUNDRY DECK] Y10
        │       ‖           [W SLUICE] Y12 ═╝    ≈  THE POUR  ≈ │
        │ [WEST GUN DECK] Y8 ═══╝                              │   lava channels between the strips
        │        \                                             │
        │         ~~~~~~~~ MUSTERING YARD  Y0 ~~~~~~~~         │   return ramps from the lava shore
        │                          ‖                           │
        │                    [ SANCTUARY ] Y8                  │
        └──────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Mustering Yard | 0, 0, 230 | 620 × 120 | terrain |
| `WestGallery` | West Gun Deck | −230, 8, 60 | 92 × 80 | deck |
| `PowderStore` (extra) | Powder Store | −230, 16, −65 | 70 × 56 | deck |
| `WestBastion` | West Bulwark Tower | −230, 24, −190 | 90 × 80 | deck |
| `SignalBastion` (extra) | Signal Bastion | −230, 32, −310 | 80 × 56 | deck |
| `WestSluice` (extra) | West Sluice Tower | −115, 12, −10 | 48 × 44 | deck |
| `Crossing` | Ironflame Gate | 0, 14, −40 | 84 × 64 | deck |
| `IronflameForge` (extra) | Ironflame Forge | 0, 20, −160 | 76 × 60 | deck |
| `EastSluice` (extra) | East Sluice Tower | 115, 12, −70 | 48 × 44 | deck |
| `EastGallery` | East Foundry Deck | 230, 10, −80 | 92 × 80 | deck |
| `HammerHall` (extra) | Hammer Hall | 230, 18, −190 | 80 × 64 | deck |
| `EastBastion` | East Bulwark Tower | 230, 30, −300 | 90 × 80 | deck |
| `Apex` | Ironflame Citadel | 0, 36, −320 | 124 × 96 | terrain |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `WestGallery→PowderStore`, `PowderStore→WestBastion`, `WestBastion→Apex`, `WestBastion→SignalBastion`, `WestGallery→WestSluice`, `WestSluice→Crossing`, `Crossing→IronflameForge`, `Crossing→EastSluice`, `EastSluice→EastGallery`, `EastGallery→HammerHall`, `HammerHall→EastBastion`, `EastBastion→Apex`.

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5, `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite), `UPPER_EAST` 5 (Elite).

**Patrols:** today the generic builder yields `BASIN_LOOP` and `BASTION_RING` here. Author `WEST_STRIP` = {WestGallery, PowderStore, WestBastion} and `WEAVE` = {WestGallery, WestSluice, Crossing, EastSluice, EastGallery}.

**Landmarks (≥ 16):**
1. Bulwark walls along both lava channels.
2. Two sluice towers with gates and chains.
3. The Pour, fed by a crucible chute.
4. Slag cannons on the Gun Deck.
5. Powder kegs and a hoist in the Powder Store.
6. The signal fire on the Signal Bastion.
7. Flame-jet portcullises sealing the Ironflame Forge.
8. Drop-hammers in the Hammer Hall, beating on the Heartbeat.
9. Anvils.
10. Chain winches.
11. Bulwark tower caps.
12. Armour racks.
13. A siege ballista.
14. The citadel's iron doors with the hammer-ring.
15. Watch braziers.
16. Ruined barricades in the yard.
17. Far: the outer mountain wall with lava falls.

**Ecosystem weight:** iron and fire under a siege mood; the most machinery in motion yet (cosmetic, client-side).

### Floor 25: Titan's Crucible (`BOSS_ARENA`)

*800 × 920 × 270, chasm (`Bottom = −6`) of lava. Molten under-light, full Heartbeat. The grandest floor in the tower so far.*

**Story beat:** the heart of the Foundry. The Ember Titan stands at its crucible on a dais above the lava. The crucible is the biggest object in the tower so far, and the Titan's heart drives every channel in the room.

**Shape: an hourglass with side chambers.**
- **Wide at the bottom:** two mould stations, each with a dead-end side chamber (the Pattern Shop and the Ingot Store).
- **The pinch:** both stations feed the Pour Gate, and nothing bypasses it.
- **The widening:** from the Pour Gate, duct bridgeheads lead out to the two bellows towers. A dead-end Pour Spout overlook looks at the lava fall.
- **The top:** the bellows towers climb to the crucible dais, each with a dead-end chain gallery beside the dais.

**New to the tower:** a pinch that every route passes through, side chambers at every level, and a colossal centrepiece.

```
                              N (−Z)
        ┌─────────────────────────────────────────────────────┐
        │ [W CHAIN GALLERY] Y36   [ TITAN'S CRUCIBLE ] Y44   [E CHAIN GALLERY] Y40
        │          \             /   (crucible behind)   \          /
        │       [WEST BELLOWS] Y30                     [EAST BELLOWS] Y32
        │              \                                 /       │
        │          [WEST DUCT] Y24   [POUR SPOUT] Y28  [EAST DUCT] Y26
        │                    \            ‖            /         │
        │                       [ POUR GATE ] Y20                │   the pinch
        │ [PATTERN SHOP] Y12    /     ≈≈ lava ≈≈      \   [INGOT STORE] Y14
        │          \           /                       \        /
        │       [WEST MOULD STATION] Y8          [EAST MOULD STATION] Y8
        │                 \                             /        │
        │              ~~~~~~ CASTING FLOOR  Y0 ~~~~~~           │   return ramps from the lava shore
        │                            ‖                           │
        │                      [ SANCTUARY ] Y8                  │
        └─────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Casting Floor | 0, 0, 270 | 700 × 120 | terrain |
| `WestGallery` | West Mould Station | −250, 8, 80 | 100 × 88 | terrain |
| `EastGallery` | East Mould Station | 250, 8, 80 | 100 × 88 | terrain |
| `PatternShop` (extra) | Pattern Shop | −280, 12, −50 | 72 × 64 | terrain |
| `IngotStore` (extra) | Ingot Store | 280, 14, −50 | 72 × 64 | deck |
| `Crossing` | Pour Gate | 0, 20, −60 | 96 × 76 | deck |
| `PourSpout` (extra) | Pour Spout | 0, 28, −170 | 64 × 48 | deck |
| `WestDuct` (extra) | West Duct | −130, 24, −180 | 60 × 56 | deck |
| `EastDuct` (extra) | East Duct | 130, 26, −180 | 60 × 56 | deck |
| `WestBastion` | West Bellows | −260, 30, −260 | 100 × 90 | deck |
| `EastBastion` | East Bellows | 260, 32, −260 | 100 × 90 | deck |
| `WestChainGallery` (extra) | West Chain Gallery | −230, 36, −380 | 80 × 64 | deck |
| `EastChainGallery` (extra) | East Chain Gallery | 230, 40, −380 | 80 × 64 | deck |
| `Apex` | Titan's Crucible | 0, 44, −360 | 170 × 124 | terrain (dark iron dais) |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `Basin→EastGallery`, `WestGallery→PatternShop`, `EastGallery→IngotStore`, `WestGallery→Crossing`, `EastGallery→Crossing`, `Crossing→PourSpout`, `Crossing→WestDuct`, `Crossing→EastDuct`, `WestDuct→WestBastion`, `EastDuct→EastBastion`, `WestBastion→WestChainGallery`, `EastBastion→EastChainGallery`, `WestBastion→Apex`, `EastBastion→Apex`. There is no `Basin→Crossing` and no `Crossing→Apex`.

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5, `UPPER_WEST` 5 (Elite), `UPPER_EAST` 5 (Elite). The Boss is summoned on the dais (95-stud leash). The dais is 170 × 124. Anvil Hammer, Slag Quake and Molten Core must stay on it and never spill onto a ramp.

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (`Always`), `LOWER_PINCH` = {WestGallery, Crossing, EastGallery}, `UPPER_PINCH` = {WestBastion, WestDuct, Crossing, EastDuct, EastBastion}, `CRUCIBLE_RING` = {WestBastion, Apex, EastBastion}.

**Landmarks (≥ 18, plus the centrepiece):**
1. **The Great Crucible:** at least 170 studs tall, on trunnions behind the dais, pouring a Neon stream into the lava on the Heartbeat. It **never overhangs the arena**.
2. The Titan's heart beating in the crucible's furnace grate (a Neon pulse).
3. Two great bellows heaving (the lungs).
4. Duct manifolds.
5. Giant moulds for a Titan's fist and helm.
6. Lathes in the Pattern Shop.
7. Ingot pallets in the Ingot Store.
8. The Pour Spout chute.
9. Chain runs from the vault, hung from registered vault supports and ending well above walk height.
10. Chain galleries with rails.
11. Vault rib arches.
12. Ladle carts.
13. Cooling ingots on the Casting Floor.
14. Anvils for the Titan's tools.
15. A gallery of finished weapons.
16. Lava falls from the walls.
17. Basalt columns ringing the dais.
18. Far: the colossal vault and the flues of the whole Foundry.

**Ecosystem weight:** everything at full beat. The postcard floor, and the new high-water mark for the tower.

---

## Part 4: Environment and lighting per floor

Add `HubLighting.FloorGrades[21..25]`, each layered over the Infernal biome grade ("forge red"), as Floors 1–20 did. `ClockTime` is shared and never changes; read mood through colour shift, ambient, atmosphere, tint, bloom and sun rays. The bigger rooms need their haze tuned so the far skyline layer still reads.

| Floor | Mood | Light | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 21 | Smoky red dawn (the only open sky) | Low red-orange, sulphur-yellow tint | Smoke haze | Flue plumes against the sky |
| 22 | Interior work-light | Warm sodium amber, strong contrast | Thin steam haze | Hanging lamp strings; quench steam |
| 23 | Furnace glare | White-orange, heavy bloom | Heat haze | Six furnace mouths pulsing |
| 24 | Siege-red night | Deep red key, **cool steel-blue fill** for contrast | Smoky | Signal fire, flame jets, lava falls |
| 25 | Molten heart | Molten gold under-light, black vault | Smoke over lava | The Heartbeat drives the bloom (client) |

Effects are client-only and pooled, and respect the Graphics quality setting.

---

## Part 5: Engineering

### 5.1 Authored room size (new)

Room size today comes from the per-index tables (`widths`, `depths`, `heights`, `apexHeights` in `TowerLayout`), so Floor 21 is the same size as Floor 1. Add an authored override, `Size = { Width, Depth, Height, Bottom? }`, which `build` reads before the tables. The validated coordinates in Part 3 use it.

Then **grep every consumer of room size and floor index** and make each read the built layout:
- `TowerRoomBuilder` (walls, vault and ceiling, skylight, `Bounds`, the Ground catch slab)
- `TowerTerrain` (field extents, wall bands)
- `TowerBiomeAssets` (backdrop placement, ecology density; it scales with area, so check its caps)
- `TowerFloorService` (zones, arrival, retirement)
- `TowerEventService` (Relic Rain spread)
- `HubLighting.TowerFloorAt` (the 2,400-stud grid still holds: the biggest room is 920 deep)
- anything else keyed on `IndexInBiome` for size

Keep the generic floors and Floors 1–20 byte-identical (§5.2 snapshots).

**Walking distance:** bigger rooms mean longer walks. Measure the shortest Sanctuary → Apex route (`TowerNavigationGraph`) on each Infernal floor. Keep it **≤ 1.5×** that of the canonical layout at the same index. If it's longer, add a shortcut link; don't shrink the room.

Update GDD §3.3's footprint table: authored floors may override the per-index footprint.

### 5.2 One authored-floor schema, then a set-piece registry (overdue clean-ups)

**One schema.** `AUTHORED` has two schemas:
- Verdant, Ashen and Frozen use top-level `DirectTerrain`, `Decks`, `Suspended`, `Masonry`, `Liquid`, `TerrainFeatures` and `Patrols`/`ReplacePatrols`.
- Fungal uses a nested `Terrain = { Direct, Surface, Decks, DeckThickness, Pools, Islands, Shapes, RoundDecks, Bridges, LiquidRise, FloorDip, WallBand, GroveScale, GroundCover, CliffVeins }` plus `Skylight`.

Merge them into one (a nested `Terrain` block, with `Size`, `Masonry`, `Patrols` and `Skylight` beside it), read from one place.
- Prove nothing changed with snapshots for Floors 1–20 and 26–50: layout, lanes, patrols, portal spots, and a grid of `TowerTerrain.Field` samples.
- Commit: `refactor(tower): one authored-floor schema`.

**Set-piece registry.** `TowerBiomeAssets.luau` is about 7,800 lines with 45 `layout.Authored == ...` branches. Add a registry (`ServerScriptService/Core/TowerSetPieces/init.luau`, keyed by the authored key) and put Infernal in `InfernalFoundry.luau`. With five times more set pieces per floor, that module will be large: split it per floor if it passes about 1,500 lines. Leave the existing biomes where they are in this change.

### 5.3 Terrain materials, surfaces and features

**Materials are place-wide.** The owners today:
- **Fungal:** `Cobblestone`, `Concrete`, `Pavement`, `Asphalt`.
- **Shared and coloured:** `Grass`, `LeafyGrass`, `Mud`, `Ground`, `Rock`, `Sand`, `Sandstone`, `Basalt`, `Snow`, `Ice`.
- **Used by palettes:** `Slate`, `Glacier`, `CrackedLava`, `Limestone`, `Salt`.

`Brick` and `WoodPlanks` are unclaimed for a reason: **Roblox collides them as 4-stud blocks**, so a ramp or trail in either is a staircase heroes cannot climb (Floors 21–23 shipped Brick trails and their Sanctuary ramps blocked the squad; `TowerTerrain.BlockyMaterials` and a spec now forbid them). Concrete and Pavement step by about a stud: walkable, but avoid them on ramps.
- Use `Basalt`, `Slate`, `Ground` and `CrackedLava` with their current colours (the `SOOTWRIGHT` surface).
- Add the Infernal entry to `TowerTerrain.Surfaces`; the spec fails if any palette or surface uses a blocky material.

**Mostly decks:** most Infernal walk surfaces are built iron and stone. Part 3 marks each terrace as terrain or deck. Direct terrain is for yards, banks, mould stations and the dais.

**Terrain features:**
- Reuse `LAVA_CHANNEL`, `APEX_ALCOVE` and the pool and lagoon kinds with `CrackedLava`.
- Add only what's missing, data-driven, obeying every terrain rule:
  - `SLAG_TIP` (Floor 21)
  - `LAVA_LAKE` with crust islands (Floors 23 and 25)
  - `POUR_PIT` (Floor 24)
  - `LAVA_FALL` (wall cascades, Floors 24 and 25)
- The terrain rules: never above a walkway, never under the chasm floor, the 6-stud moat, `RES / 2`, FBM edges, and terraces on multiples of 4.

**Lava** is cosmetic: never a hazard, never part of a lane; glow from Neon seams and bloom.

**Masonry:** add the Infernal styles to `MASONRY_STYLES`:
- `FOUNDRY_IRON`: riveted plate, diamond-plate treads, brass trim.
- `SOOT_BASALT`: basalt brickwork with iron bands.
- `GIRDER`: open lattice with grating decks, for Floor 22's girder and the duct bridgeheads.
- `CRUCIBLE`: dark iron with a molten lip.

`PathStyle = "SOOTWRIGHT"`:
- Ramps are diamond-plate on basalt, with rail inlays where the story puts rails.
- Kerbs are iron with rivets.
- Stairs are iron treads with brass nosing.
- Landings take the surface they sit on.

### 5.4 Kits: enough meshes for the ladder

Follow the per-floor kit pipeline:
1. Generate them with `tools/blender/generate_infernal_fN_kit.py`, writing `assets-source/tower/infernal_fN_kit/`. Use the same runner as the earlier generators; the project memory has the headless Blender path, run with `--background`.
2. Register them in **`TowerBiomeKit.ExtraTemplates`** only.
3. Add them to the Studio importer.
4. Place each one behind `KitProps.Has` with a native fallback.

**Reuse aggressively** to reach the "distinct templates placed" targets without bloating the kit. Every earlier template can be re-tinted through its roles, for example `ArchCrown`, `ArchPierSegment`, `Obelisk`, `FurnaceStack`, `ForgeScrap`, `BoulderCluster`, `RuinRubble`, `StoneUrn`, `ChasmIsland` and `CliffRockA`/`CliffRockB`, plus Ashen's portcullis and kiln pieces and Frozen's tower and wall pieces. New templates (at least the ladder's count per floor):

| Floor | Candidates |
| --- | --- |
| 21 | `RailTurntable`, `OreCart`, `OreTrain`, `SlagTipFlow`, `FurnaceGateDoors`, `OreCrusherJaw`, `CoalHopper`, `WeighbridgeScale`, `RailBuffer`, `WaterTowerLegs` |
| 22 | `GantryPier`, `GantryGirder`, `GirderHoist`, `CraneTrolleyHook`, `ConstructShell`, `AssemblyJig`, `QuenchTank`, `PatternRack`, `ControlCabLevers`, `ConveyorRollers` |
| 23 | `FurnaceTower`, `TiltingCrucible`, `CausewayPier`, `SlagLadleCart`, `CoolingRack`, `CastingMouldBed`, `BladeDisplay`, `FurnaceDoorGiant`, `BellowsDuctRun`, `CrustIsland` |
| 24 | `BulwarkWall`, `SluiceTower`, `SluiceGateChain`, `SlagCannon`, `SignalBrazier`, `DropHammer`, `PowderKegStack`, `FlameJetPortcullis`, `ChainWinch`, `SiegeBallista`, `ArmourRack` |
| 25 | `GreatCrucible`, `TitanHeartGrate`, `GreatBellows`, `TitanMouldFist`, `TitanMouldHelm`, `HangingChainRun`, `PourSpoutChute`, `DuctManifold`, `IngotPallet`, `PatternLathe`, `VaultRibArch`, `ChainGalleryRail` |

The Infernal kit palette already has `MOSS` (cracked lava), `WOOD`, `FOLIAGE`, `METAL` (diamond plate), `CRYSTAL` (molten glass) and `ALT`. Add `BRASS` and `SOOT` if you need them.

**Import into the live experience** (`Infinite Towers: Become a Master!`, placeId 136256010643848), not only a copy.
- Check `ServerStorage.TowerBiomeKit` against the repo's `ExtraTemplates`, read fresh. Edit-mode `require` caches modules; clone the module as the importer does.
- Save the place.

### 5.5 Lessons from Floors 1–20 (each one came from a fix commit)

- **Terrain terraces on multiples of 4 studs** (Fungal). Decks and stairs can be at any height.
- **Materials are place-wide** (Fungal): claim, don't recolour shared ones.
- **Big landmarks vs. boss portals** (Ashen): keep every Apex landmark clear of `Layout.PortalSpots` lanes.
- **Spans over camps** (Ashen): girders, arches and chains over a camp need the camp-centre exemption, used deliberately.
- **Check footprints offline:** test every kit landmark's real scaled footprint against `Lanes` and `Camps` before building. One overlapping part removes the whole prop.
- **Overheads vs. the camera** (Frozen 19 and 20): hooks, chains, girders and the crucible keep at least 18 studs over any walk surface and never cover the boss arena. Check the camera on every terrace with something overhead.
- **Ground everything; never stand a whole model on a ledge or branch** (Verdant, Ashen). Hanging things hang from a registered support.
- **Collision of biome assets:** Frozen 16 made biome assets collidable (`git show 5e1f644`). With much denser props, check that no collidable prop narrows a lane, blocks a landing or crowds a camp. Small clutter should not collide.
- **Change layouts through the validator** (Frozen 20). Update the specs, the GDD and this ladder together.

The rules carried over from Verdant: players walk on direct `Terrain` where it's natural ground, and grounding raycasts include `workspace.Terrain` with `IgnoreWater = true`.

### 5.6 The Heartbeat (client-only)

- One client module (for example `StarterPlayerScripts/Rendering/FoundryHeartbeat.luau`) runs only while the local player is on Floors 21–25.
- It derives the beat from `workspace:GetServerTimeNow()`, so every client beats together and no remote is needed. The period gets shorter toward Floor 25 (for example 4 s on 21 down to 2 s on 25).
- On each beat it does the following, on CollectionService-tagged parts and emitters with a strict cap:
  - tweens Neon seam colour
  - puffs steam
  - triggers sparks
  - nudges bloom
  - plays one spatial thud
- It also drives the cosmetic machinery: drop-hammers, bellows, hoists and the crucible pour.
- **No gameplay effect.** At the lowest graphics setting, only the seams pulse.

### 5.7 Telegraph readability

Lava and glow are red and orange, the same family as enemy telegraphs. Denser scenery makes this harder.
- Keep lava, Neon seams and busy clutter out of camp areas and the boss dais (the dais floor is dark iron).
- Check in a playtest that every Infernal telegraph (camp attacks; Anvil Hammer, Slag Quake and Molten Core) reads at gameplay distance.
- If it doesn't, change the floor's colours or clear the clutter, not the telegraphs.

### 5.8 Performance: many more assets, same frame rate

More assets is only acceptable if the game stays smooth:
- **Instance, don't model.** Reach the prop counts by placing the same kit meshes many times (one MeshId reused is cheap). Ground cover uses multi-clump meshes. Small clutter has `CastShadow = false`, `CanCollide = false` and `CanQuery = false`.
- **Detail tiers:** tag small clutter and ground cover `TowerDetail`. Extend `EffectCullingRules` and the client culler (the hub's `HubEffectCulling` pattern, with hysteresis) so detail beyond about 220 studs, or at low quality, is hidden on the client. Landmarks are never culled.
- **Lights** stay ≤ 24 per floor: glow from Neon and bloom. Particle emitters: ≤ 12 on Floors 21–23, ≤ 16 on 24–25, all pooled and quality-scaled.
- **Measure:**
  - Record parts, MeshParts, lights, emitters and client memory on Frozen 16–20 as the reference, then on each Infernal floor.
  - Each Infernal floor may use up to **1.6×** the same-index Frozen floor's instance count, provided the frame-rate target holds.
  - **Target:** in Studio playtest at the lowest graphics setting, ≥ 45 FPS during a full camp fight on every Infernal floor, and ≥ 40 FPS during the Floor 25 boss fight (MicroProfiler).
  - Put the numbers in the PR.
- If a floor misses the frame-rate target, cut clutter and ground cover first, then props, and landmarks last. Never cut below the ladder: optimise instead.

### 5.9 Data and saves

The layout isn't saved. No profile schema change and no `DataManager.SyncProfile` migration are needed. If you find otherwise, stop and say so.

---

## Part 6: Process, tests and docs

### Phases and the review gate

1. **The room-size override (§5.1), the schema merge and the set-piece registry (§5.2)**, with no visible change to Floors 1–20 and 26–50.
2. **Census baseline:** add `tests/studio-tower-asset-census.luau`. It builds a floor in Studio and reports:
   - room size, terraces, links and height levels
   - new templates, distinct templates and kit instances
   - landmark set pieces (`PropKind` models tagged as landmarks), placed props, and ground cover and clutter
   - the tallest prop
   - parts, MeshParts, lights and emitters

   Run it on Floors 1–20 and record the per-index maxima. That fixes the 1.3× targets (§2.2).
3. **Design gate.** For each Infernal floor, show:
   - the final coordinate table and an ASCII map with links, camps and patrols
   - every link's rise and slope
   - the ladder row it must meet
   - the landmark list
   - the kit templates you plan to generate, each with a one-line silhouette description

   **Stop and wait for sign-off.**
4. **Floors 21–25**, one at a time, lowest first. Each floor's kit, terrain, layout and set pieces go in one commit: `feat(tower): author Infernal floor N (<name>)`. Run the census after each floor and paste its row into the commit body.
5. **Lighting:** `FloorGrades[21..25]`. **The Heartbeat and ambient life** (client-only). **The detail-tier culling** (§5.8).
6. **Kits imported into the main experience** and verified (§5.4).
7. **Docs and tests**, then open the PR against `main` with the census table and the performance numbers.

### Tests

```bash
pwsh tests/run.ps1 -LuauDirectory D:/luau
```

Never pass `-InstallLuau`. Extend:

- `tower-layout-variants.spec.luau`:
  - each Infernal floor is authored and fixed, with its key, name, `Size` and signature links:
    - Floor 21 is a hub: every route from the Basin passes the `Crossing`.
    - Floor 22's piers join only through the girder nodes, and only the trolley's stem reaches the Apex.
    - Floor 23's bays branch off the spine.
    - Floor 24's Basin links only to the West Gun Deck.
    - Floor 25 has no `Basin→Crossing` or `Crossing→Apex`, and every Basin→Apex route passes the `Crossing`.
  - **the ladder:** across Floors 21–25, room area, terraces, links and height levels each strictly increase, and every Infernal floor's terraces, links and levels are greater than every earlier authored floor at the same index
  - mob totals and Elite counts, camps inside their terraces and never on an `ExtraPlatform`, and everything reachable from the Sanctuary
  - the Sanctuary → Apex route length is ≤ 1.5× canonical
- `tower-patrols.spec.luau`: Floors 23–25 each have the entry loop plus at least one more route, every point is on a walkway, and each floor has exactly one `Always` route.
- `tower-portals.spec.luau`; `tower-biome-kit.spec.luau` (Infernal `ExtraTemplates` well-formed and at least the ladder's count per floor, `Templates` unchanged, `FloorGrades[21..25]` layered over the Infernal grade; no blocky terrain material anywhere); `effect-culling.spec.luau` (the detail tier).
- The schema and size snapshots: Floors 1–20 and 26–50 unchanged.

Then, in Studio, run `tests/studio-tower-prop-audit.luau` for all 50 floors. Orphaned props, floating props and props on walkways must all be **0**. Run `tests/studio-tower-asset-census.luau` on Floors 1–25, and check that every Infernal floor meets its ladder row and beats both the floor below it and 1.3× the best earlier floor at its index.

### Docs (same PR)

- `docs/GAME_DESIGN.MD` §3.3:
  - the Sootwrights, the Ember Titan and the Heartbeat
  - the five Infernal floors
  - **the escalation ladder as a standing rule for Floors 26–50**
  - the authored `Size` override, and the merged schema
- `docs/TOWER_NAVIGATION.md`: the schema, `Size`, and any new terrain feature kinds.
- `reference/infinite_towers_biomes.md` §5: a short paragraph on the Sootwrights and the Heartbeat.

### Finish with a Studio checklist for the user

Don't run the playtest yourself. End with a **How to test** checklist the user can follow, covering at least:

1. Floors 21–25, each:
   - arrive out of aggro
   - walk every route to the Apex
   - nothing floats; hanging things hang from girders or the vault
   - nothing sits on a walkway
   - the floor feels bigger and busier than the last
2. Floor 21: every route passes the Great Turntable; the rim track links the shed and the crusher.
3. Floor 22: walk the girder pier to pier through both hoists and the trolley; the hooks stay well overhead.
4. Floor 23: walk the spine and visit every bay; take the catwalk; drop into the lava chasm and climb out by a return ramp.
5. Floor 24: the yard only leads west; weave through both sluice towers; the Pour blocks the middle.
6. Floor 25:
   - every route passes the Pour Gate
   - the crucible dwarfs everything and never covers the fight
   - summon the Titan: its telegraphs read and stay on the dais
   - kill it: the Ascend and Rerun portals rise
7. Telegraphs read against the lava and clutter on every floor.
8. The Heartbeat pulses on every client at once, stronger toward Floor 25, and stops when you leave the biome.
9. Squad follow and recall (`E`) on the girder, causeways, sluice towers and duct bridgeheads; walking time feels reasonable.
10. Patrols walk their routes.
11. Relic Rain lands on Infernal ramps (`workspace.TowerEventForce = "RELIC_RAIN"`).
12. Each floor's lighting changes on entry and restores in the hub; the far skyline reads through the haze.
13. Floors 1–20 and 26–50 look and play exactly as before.
14. Frame rate at the lowest graphics setting: ≥ 45 FPS in camp fights, ≥ 40 FPS in the Floor 25 boss fight; distant clutter hides and reappears smoothly.
15. In the main experience, the Infernal kits show as meshes, not part fallbacks.

## Out of scope

- Other biomes, and moving the existing biomes' set pieces out of `TowerBiomeAssets` (§5.2 only adds the registry). Raising Floors 1–20 to the new standard is a separate task.
- New enemies or boss mechanics, extra mobs for the bigger rooms, lava damage, burning status effects, moving platforms, or machinery that affects combat.
- Changes to rewards, relic drops, mob stats, camp respawn timing, or the tower difficulty curve (just retuned in PR #351).
