# Prompt: Frozen Citadel — a Unique Layout for Every Floor (Floors 16–20)

Copy everything below the line into a Claude Code session opened at the repo root.

> **Written 2026-11-18**, after Verdant Ruins (Floors 1–5, merged) and Ashen Dunes (Floors 11–15, on `feat/ashen-dunes-floor-layouts`) were built from `docs/prompts/verdant-ruins-floor-layouts-prompt.md` and `docs/prompts/ashen-dunes-floor-layouts-prompt.md`.
>
> This brief builds on what those floors left behind:
> - **Layout data fields** on the `AUTHORED` table: `DirectTerrain`, `Decks`, `Suspended`, `Masonry`, `Liquid`, `TerrainFeatures`, `Patrols`/`ReplacePatrols`, `ExtraPlatforms`, `Stairs`, `PathStyle`.
> - **Terrain feature kinds:** `DUNE`, `RAVINE`, `RIVER_GORGE`, `MOAT_CHANNELS`, `CENOTE_LAGOON`, `LAVA_CHANNEL`, `POOL_ELLIPSES_SQ`, `APEX_ALCOVE`.
> - **Per-floor Blender kits** in `ExtraTemplates`.
>
> The starting coordinates in Part 2 were run through the current `TowerLayout.Validate`: no problems, every link at or under 15°, and the mob and Elite totals are right.

---

## Role

You are a two-specialist team speaking as one. Say which role you are speaking as when it matters.

**Warden** is a senior level designer and gameplay engineer for *Infinite Tower: Become a Master!*, a Roblox squad-command action RPG. Warden owns topography, sightlines, combat spaces, pacing, navigation and the `TowerLayout` connector contract. Warden thinks in walkable surfaces, link slopes, camp spacing, leash radii and the route a squad of five takes from the Sanctuary to the Apex.

**Rime** is a senior environment artist and world-builder. Rime owns the ecosystem, the landforms, landmarks, materials, lighting and atmosphere. Rime builds them from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the Verdant and Ashen floors do. Every prop has a reason to exist in the ecosystem and reads clearly from the gameplay camera.

Neither of you breaks the runtime contracts described below.

## Before you start

1. Follow `CLAUDE.md` and `AGENTS.md`. Use the `roblox-world-building`, `roblox-luau`, `roblox-npc-ai` and `roblox-performance` skills.
2. Read `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, hand-authored floors: the Verdant and Ashen entries are the worked examples) and the lighting section, `docs/TOWER_NAVIGATION.md`, and `reference/infinite_towers_biomes.md` §4.
3. Read both earlier prompts, especially the Ashen one's §4 (Engineering), and `git log` for the Ashen floors. The fix commits carry the lessons, and §4.4 below sums them up.
4. Read the authored-floor code end to end:
   - `TowerLayout.luau`: the `AUTHORED[11..15]` entries, `build`, `Validate`, `PatrolRoutes` and its authored `Patrols`, `Lanes`, `PortalSpots`.
   - `TowerRoomBuilder.luau`: decks, suspended links and every `layout.Masonry == ...` branch.
   - `TowerTerrain.luau`: every `feat.Kind` and the `Liquid` handling.
   - `TowerBiomeAssets.luau`: the `layout.Authored == "ashen:N"` set pieces and `reservedSpots`.
   - `TowerBiomeKit.luau` and `TowerKitProps.luau`: `ExtraTemplates`, `Has`, `Ready`.
   - `HubLighting.luau`: `FloorGrades`.
   - `tests/studio-tower-biome-kit-import.luau`.
5. **Branch:** the Ashen floors are on `feat/ashen-dunes-floor-layouts`. Branch from `main` **after it merges** (`feat/frozen-citadel-floor-layouts`). If it hasn't merged, stop and ask; don't branch from a branch that is still under review. Use conventional commits.

## The goal

The five Frozen Citadel floors (16–20) still use the seeded generic layout and generic Frozen props: frosted pines, ice spires and the citadel-keep backdrop. Give each one its own hand-authored topography, built around one ecosystem, so that each floor has a different shape, route and combat rhythm. Each floor must also be clearly different from the ten authored floors before it (listed in Part 2). The other biomes stay exactly as they are.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, landform and creature traces back to this ecosystem. If a prop doesn't fit, cut it.

### The Whiteguard

The Whiteguard was an order of knight-wardens sworn to hold the high pass for their King. Their architecture is blue-grey granite in massive courses, with iron bands and studs, steep slate roofs, round towers with conical caps, and arrow-slit windows glazed with pale blue glass. Their motif is the **ward-star**: a six-pointed snowflake inside a shield. It appears on banners, shields, doors and the floor of the throne hall.

### The Stillheart and the Stillcold

The King was dying. The order's frost-wrights carved him a new heart of glacier glass, the **Stillheart**, so that he would never die. It worked too well: the heart stopped *time* around it. Its cold, the **Stillcold**, spread outward through the citadel and froze everything it touched at the moment it arrived. The garrison froze at its posts, the snow stopped mid-fall, and the King still sits on his throne.

The relic skins already tell this story (`RelicConfig` → `FROZEN`). The *Glacial Urn* has "runes frozen mid-glow", the *Permafrost Core* is "ancient ice that never melts, caged in iron", and the *Heart of the Frostbound King* is "a crowned heart of glacier glass, beating slow and cold". Echo them in the set pieces.

**The Stillcold is the biome's through-line (its Heartroot or Ember Vein).** It grows stronger floor by floor:

| Floor | How strong the Stillcold is | What the player sees |
| --- | --- | --- |
| 16 | Not yet: ordinary deep winter | A frozen lake and the great frozen waterfall, the **Rimefall**. The cold is still natural. |
| 17 | It reached the barracks first | Soldiers frozen mid-drill in clear ice, brazier flames turned to blue ice, kennel chains frozen mid-swing |
| 18 | It cracked the glacier road | The Iceway shattered into heaved slabs. The first **frozen moments**: a supply cart stopped mid-fall into a crevasse, held in an ice pillar. |
| 19 | It caught a battle | A siege frozen mid-assault: ladders, a battering ram, a relief army's tents |
| 20 | Its source | The throne hall: an avalanche frozen mid-crest behind the throne, knights frozen mid-kneel, the King, and the Stillheart glowing in his chest |

**The frozen-moment rule:** anything "frozen mid-air" is held by ice that reaches the ground: an ice pillar, a frozen spray, an icicle column. That keeps the grounded-clutter rule (nothing floats) and makes the effect read as deliberate.

### Weather

The blizzard blows **from the north**, down from the throne, the source of the cold. Snow drifts pile against the north faces of everything, and icicles hang on the south eaves. Snowfall and wind-blown snow streaks are client-side and get heavier floor by floor. Floor 18 is the blizzard floor.

### Living layers (use all of them on every floor, weighted per floor)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Landform** | Snowfields, frozen lakes, glaciers, seracs, crevasses, granite crags | Terrain: `Snow`, `Glacier`, `Ice` and `Rock` (the Frozen palette) |
| **Flora** | Frost pines (kit `PineTree`), rime-crusted heather, pale frost lichen on rock, **snowbells** (blue bell flowers at the snow line) | Sparse; thins out floor by floor and is almost gone on Floor 20 |
| **Rimelight** | **Rimelight crystals**: blue ice crystals that grow along the Stillcold's lines, the "magical blue crystals" that light the citadel; **rimeblooms**, ice flowers where the cold is strongest | The light sources. Neon/Glass accents only, and few lights. |
| **Ice** | Icicles, frozen falls, clear ice encasing people and objects, frost on every surface | Ice is cosmetic: never a hazard, never slippery |
| **Stone** | Whiteguard walls, towers, barracks, the keep, the throne hall | Always frosted on top, drifted on the north side |

### Food web (how the enemies fit, `MobCatalog` → `frozen_citadel`)

- **Frost Hound** (`QUADRUPED`): the Whiteguard's kennel hounds, gone feral and hunting in packs. Kennels on Floor 17, and paw-print trails in the snow near camps.
- **Rime Sentry** (`WEAPON_BIPED`): garrison soldiers the Stillcold froze at their posts and keeps moving, still walking their rounds with ice spears. Put sentry boxes and frozen watch-fires at camps.
- **Rime Chaplain** (support, `WARD`): the order's chaplains, still raising rime wards. Put ward-star shrines and Glacial Urns where they stand.
- **Glacier Knight** (`ARMORED_BIPED`, Elite): the order's knights, shield and broad ice blade. Banners and weapon racks where Elites tend to lead.
- **Frostbound King** (`ROYAL_BIPED`, boss, Floor 20): greatsword and cloak, the Stillheart in his chest. His moves are Glacial Cleave (`ARC`), Blizzard Shock (`SELF_DISC`) and Ice Spikes (`TARGET_DISC`).

### Ambient life (client-only, purely cosmetic)

Snowfall and wind-borne snow streaks (heavier on Floor 18), breath-frost puffs near camps, ravens on battlements, drifting ice glitter in light shafts, and occasional small snow slides off roofs (cosmetic, nowhere near walkways). On Floor 19, an aurora ribbon in the sky only. Everything is client-side, pooled, culled by distance, scaled by the Graphics quality setting (`SettingsGraphicsEngine`), and off at the lowest quality. Nothing replicates from the server.

---

## Part 2: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north (the Apex side). Y is the walkable top surface. Footprints, height bands, chasm depth and mob totals follow GDD §3.3 by floor-in-biome.

The values below are **validated starting points**. Tune them, keep the shape and intent, and re-run the validator after every change.

**Already taken (don't repeat them):**
- Verdant:
  - 1: a spine with glades
  - 2: a broken diagonal aqueduct
  - 3: an east–west gorge with three bridges
  - 4: a walled ring with wall-walks
  - 5: a spiral around a cenote
- Ashen:
  - 11: a fork around a dune
  - 12: a single switchback
  - 13: a north–south ravine with two ledges and an arch
  - 14: a chokepoint gate and a split fortress
  - 15: a route over a fallen giant

**Fixed on every floor:**
- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, 128 × 56, and `Basin` stays centred at X = 0.
- The `Apex` holds the Alpha or Boss summon and the boss portals.
- Arrivals land out of aggro.
- Mob totals and Elite counts are **16 / 22 / 25 / 35 / 35** and **1 / 2 / 3 / 4 / 4**. From Floor 18, at least one Elite camp stands above the entry level. `ExtraPlatforms` hold no camps.

### Floor 16: Rimefall Approach (`INTRODUCTION`)

*380 × 420 × 130, Y 0 to +12, no chasm. Overcast whiteout morning.*

**Story beat:** the road to the citadel crosses a frozen mountain lake below the **Rimefall**, a great waterfall frozen solid. The Whiteguard's hunters and ice-fishers lived on its shores.

**Shape: two ways across a frozen lake.** One is the **long shoreline road** round the lake's west side. The other is a **chain of ice floes** straight across it: shorter, but narrow and exposed. A fisher's hut stands on a side floe. This choice of routes is the floor's lesson.

```
                 N (−Z)
        ┌───────────────────────────────┐
        │ [ RIMEFALL SHRINE ] Y12       │   Apex at the foot of the frozen waterfall (west of centre)
        │    |              \           │
        │    |           [NORTH FLOE] Y8│
        │ [HUNTERS' LODGE]      |       │   ≈≈≈ frozen lake ≈≈≈
        │   Y4  |        [HEART FLOE] Y4 ── [FISHER'S HUT] Y5
        │       |        [SOUTH FLOE] Y2│
        │   ~~~ SNOWFIELD  Y0 ~~~  /    │
        │              ‖                │
        │        [ SANCTUARY ] Y8       │
        └───────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Snowfield | 0, 0, 90 | 330 × 80 | Wind-packed snow, sledge tracks, a toppled ward-star waymarker |
| `WestGallery` | Hunters' Lodge | −116, 4, −10 | 84 × 76 | Timber-and-granite lodge, antler racks, drying racks |
| `FloeSouth` (extra) | South Floe | 40, 2, 10 | 40 × 36 | First floe, frozen in the lake ice |
| `Crossing` | Heart Floe | 60, 4, −50 | 56 × 48 | The biggest floe, with a cairn and ice-fishing holes |
| `EastGallery` | Fisher's Hut | 130, 5, −30 | 60 × 56 | A hut on a side floe, nets frozen stiff |
| `FloeNorth` (extra) | North Floe | 60, 8, −108 | 40 × 36 | A floe heaved up against the shore ice |
| `Apex` | Rimefall Shrine | −30, 12, −158 | 104 × 76 | A ward-star shrine at the frozen waterfall's foot |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `WestGallery→Apex`, `Basin→FloeSouth`, `FloeSouth→Crossing`, `Crossing→EastGallery`, `Crossing→FloeNorth`, `FloeNorth→Apex`. Floe links are low ice-slab bridges: suspended decks over the lake.

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite), `EAST_GALLERY` 4. **Patrol:** `BASIN_LOOP`.

**Set pieces:**
- The **Rimefall**: a frozen waterfall about 70 tall on the north wall behind the shrine (kit mesh), with icicle curtains and pale blue light inside the ice.
- The **frozen lake**: terrain `Ice` in a shallow depression, with pressure ridges and trapped bubbles (decals or thin parts).
- Fishing holes on the Heart Floe, the Hunters' Lodge, and frost pines on the shore.

**Ecosystem weight:** natural winter. The most flora in the biome and no Stillcold yet: the citadel is only a silhouette above the falls.

### Floor 17: Frozen Barracks (`EXPANDED_ENCOUNTER`)

*420 × 470 × 140, Y 0 to +14, no chasm. Clear, cold noon.*

**Story beat:** the garrison's quarter. The Stillcold reached it first and froze the soldiers mid-drill on the parade ground.

**Shape: a lattice of streets.** This is the first floor that is a **mesh**, not a tree. The barracks stand around a parade ground with streets running between them, so squads can loop, flank and cut across. Every street converges on the Armory, and one stair climbs from it to the Commander's Hall.

```
                 N (−Z)
        ┌───────────────────────────────┐
        │     [ COMMANDER'S HALL ] Y14  │
        │               ‖  (stairs)     │
        │          [ ARMORY ] Y10       │
        │         /     |      \        │
        │ [W BARRACKS]─[MESS HALL]─[E BARRACKS]   streets between the blocks
        │   Y6    \      Y4      /  Y6  │
        │     ~~~ PARADE GROUND Y0 ~~~  │   soldiers frozen mid-drill
        │               ‖               │
        │         [ SANCTUARY ] Y8      │
        └───────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Parade Ground | 0, 0, 112 | 360 × 92 | Flagstones under snow, a drill company frozen in ranks (statues) |
| `WestGallery` | West Barracks | −130, 6, 0 | 84 × 76 | Bunkhouse yard, cots and lockers frozen in place |
| `EastGallery` | East Barracks & Kennels | 130, 6, 0 | 84 × 76 | Kennel runs, chains frozen mid-swing |
| `Crossing` | Mess Hall | 0, 4, −10 | 72 × 58 | Roofless mess, long tables, a soup cauldron frozen mid-boil |
| `Armory` (extra) | Armory | 0, 10, −96 | 64 × 44 | Weapon racks, shields with the ward-star |
| `Apex` | Commander's Hall | 0, 14, −180 | 104 × 80 | The garrison commander's hall, a war table under ice |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `Basin→EastGallery`, `Basin→Crossing`, `WestGallery→Crossing`, `EastGallery→Crossing`, `Crossing→Armory`, `WestGallery→Armory`, `EastGallery→Armory`, `Armory→Apex` (**STAIRS**, `Stairs = { Armory_Apex = true }`).

(Gallery → Apex links ran over the Armory, so the streets converge on the Armory instead.)

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite). **Patrol:** `BASIN_LOOP` only (the generic rule adds a second route from the third floor of a biome).

**Set pieces:**
- The **frozen drill company**: ranks of soldier statues in clear ice on the parade ground, off the causeway lane and out of the camps' clearance.
- Brazier flames turned to blue ice, kennel chains frozen mid-swing, the cauldron frozen mid-boil (a crown of ice "bubbles" fused to the rim).
- Barracks blocks with steep slate roofs, drifted on the north side.

**Ecosystem weight:** stone and the first frozen moments. Clear sky and hard shadows.

### Floor 18: Shattered Iceway (`TERRAIN_VARIATION`)

*460 × 520 × 155, Y −4 to +18, chasm (`Bottom = −4`). Blizzard afternoon.*

**Story beat:** the Whiteguard built a road on top of the glacier, the **Iceway**. When the Stillcold hit the glacier it froze too fast and shattered: crevasses opened on both sides and the road heaved into slabs.

**Shape: an inverted ravine.** The *centre* of the floor is the high ground: the glacier spine that carries the Iceway north in two heaved slabs. Crevasses (the chasm) open on **both sides** of it, with moraine banks beyond. Ashen 13 is the opposite, with the chasm in the middle and ledges on the walls. Ice-slab bridges leap the crevasses from the Lower Iceway out to both moraines. The west moraine climbs to the gate on its own; the east moraine rejoins the spine.

```
                     N (−Z)
        ┌──────────────────────────────────────┐
        │          [ ICEFALL GATE ] Y18        │
        │        /          ‖ (stairs)         │
        │       /     [UPPER ICEWAY] Y12 ──────[EAST MORAINE] Y4
        │ [WEST MORAINE]    ‖                  │
        │   Y8 ≈≈crevasse≈≈ ‖  ≈≈crevasse≈≈    │   chasm on both sides of the spine
        │     \═══ [LOWER ICEWAY] Y6 ═════/    │   ice-slab bridges over the crevasses
        │                   ‖                  │
        │      ~~~ MORAINE FOOT  Y0 ~~~        │   return ramps from the crevasse floors
        │                   ‖                  │
        │             [ SANCTUARY ] Y8         │
        └──────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Moraine Foot | 0, 0, 124 | 400 × 104 | Boulder-strewn moraine at the glacier's snout |
| `Crossing` | Lower Iceway | 0, 6, 10 | 70 × 60 | The first heaved road slab, flagstones split by ice |
| `UpperIceway` (extra) | Upper Iceway | 0, 12, −96 | 64 × 56 | The second slab, tilted, a road shrine half-swallowed |
| `WestGallery` | West Moraine | −150, 8, −40 | 80 × 80 | A moraine bank with a collapsed toll shelter |
| `EastGallery` | East Moraine | 150, 4, −70 | 80 × 80 | A lower bank, seracs leaning over it |
| `Apex` | Icefall Gate | 0, 18, −190 | 110 × 84 | The Iceway's gate into the citadel, under a frozen icefall |

**Paths:** `Sanctuary→Basin`, `Basin→Crossing`, `Crossing→WestGallery`, `Crossing→EastGallery` (both suspended ice-slab bridges), `Crossing→UpperIceway`, `UpperIceway→Apex` (**STAIRS**), `WestGallery→Apex`, `EastGallery→UpperIceway`. Return ramps from the crevasse floors to the Basin.

**Camps (25, 3 Elites, at least one above the entry level):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (the `Always` entry loop), `WEST_MORAINE` = {WestGallery, Apex}, `ICEWAY_CROSS` = {WestGallery, Crossing, EastGallery}, `EAST_CLIMB` = {EastGallery, UpperIceway}. **The generic gallery routes assert here:** there is no `EastGallery→Apex` link (checked against the current `PatrolRoutes`).

**Set pieces:**
- The **glacier spine**: a raised `Glacier` ridge under both slabs (a new terrain feature, §4.2), banded blue with dirt layers.
- Twin crevasses with blue ice walls fading to black. The **crevasse cart**: a supply cart frozen mid-fall, held in an ice pillar that rises from the crevasse floor (the frozen-moment rule).
- Seracs leaning over the East Moraine, at least 14 studs clear above any walk surface. Road waystones half-buried.

**Ecosystem weight:** ice and wind. The heaviest snow streaks in the biome; keep camps readable at 120 studs.

### Floor 19: Whiteguard Keep (`ELITE_STRONGHOLD`)

*510 × 580 × 170, Y −4 to +22, chasm (`Bottom = −4`). Twilight, with an aurora.*

**Story beat:** a relief army besieged the keep to free it from the Stillcold. The cold caught the battle mid-assault.

**Shape: two routes, two climates.** The west route goes **through the glacier caves** under the keep's rock: dim and blue-lit, with rimelight crystals and narrow chambers. The east route goes **over the battlements**: open and windy, along a long viaduct to the outer gate, the east bailey and the Whiteguard Tower. The routes never connect until the keep. Ashen 14 is one gate that splits; here the routes are separate from the start, and they feel different.

```
                       N (−Z)
        ┌──────────────────────────────────────────┐
        │ [CRYSTAL GROTTO] Y12 ── [ KEEP HALL ] Y22 ── [WHITEGUARD TOWER] Y16
        │       ‖  (caves)                     ‖  (battlements)
        │ [ICE CAVE MOUTH] Y4                [EAST BAILEY] Y10
        │       \                          /        │
        │        \          [VIADUCT GATE] Y8       │   long viaduct from the camp
        │         \            //                   │
        │      ~~~ SIEGE CAMP (frozen relief army) Y0 ~~~
        │                       ‖                   │
        │                 [ SANCTUARY ] Y8          │
        └──────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Siege Camp | 0, 0, 160 | 440 × 110 | The relief army's camp: tents, a battering ram and soldiers, all frozen |
| `Crossing` | Viaduct Gate | 40, 8, 10 | 74 × 60 | The outer gate at the end of the viaduct, a siege ladder frozen against it |
| `EastGallery` | East Bailey | 165, 10, −30 | 86 × 78 | Bailey yard, a frozen trebuchet |
| `EastBastion` | Whiteguard Tower | 160, 16, −160 | 84 × 76 | The great round tower, its banner frozen mid-flutter |
| `WestGallery` | Ice Cave Mouth | −165, 4, −10 | 86 × 78 | The cave entrance, an icicle curtain, rimelight crystals |
| `WestBastion` | Crystal Grotto | −160, 12, −150 | 84 × 76 | An open-roofed grotto lined with big rimelight crystals |
| `Apex` | Keep Hall | 0, 22, −210 | 110 × 84 | The keep's courtyard hall, its doors sealed by a wall of ice |

**Paths:** `Sanctuary→Basin`, `Basin→Crossing` (the **viaduct**, a suspended deck), `Crossing→EastGallery`, `EastGallery→EastBastion`, `EastBastion→Apex`, `Basin→WestGallery`, `WestGallery→WestBastion`, `WestBastion→Apex`.

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5, `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite), `UPPER_EAST` 5 (Elite).

**Patrols:** the generic `BASIN_LOOP`, `GALLERY_WEST`, `GALLERY_EAST` and `BASTION_RING` all work here; add an authored `VIADUCT` = {Crossing, EastGallery}.

**Set pieces:**
- **The caves stay readable from the camera.** "Caves" means terrain or kit overhangs on the *outer* side of the west route only, plus translucent ice roofs (Glass/Ice at about 0.4–0.6 transparency) over at most a third of any cave terrace. Overheads stay ≥ 18 studs above the walk surface. Check the gameplay camera on every cave terrace before you sign it off.
- The frozen siege: the battering ram at the viaduct's foot, a ladder on the gate, arrows stuck in an ice sheet (never in mid-air), and the trebuchet.
- Curtain walls with ward-star banners, and the aurora in the sky (client-only).

**Ecosystem weight:** stone and battle, frozen. The most rimelight crystals in the biome.

### Floor 20: Frostbound Throne (`BOSS_ARENA`)

*560 × 640 × 190, Y −6 to +28, chasm (`Bottom = −6`). Endless frozen night.*

**Story beat:** the throne hall, where the Stillcold began. Knights frozen mid-kneel line the nave. Behind the throne, an avalanche that broke through the hall's back wall hangs frozen mid-crest. The King sits on the throne with the Stillheart glowing in his chest.

**Shape: a cathedral nave.** It's a long, symmetric throne hall:
- the **nave** (a 72 × 120 Crossing) runs north to the royal stair
- **aisles** run either side of it, behind colonnades
- **transepts** link the nave to both aisles midway
- the aisles climb to **chapels** that flank the dais

The space is formal and symmetric, and every route reads toward the throne. No other floor has this layout.

```
                         N (−Z)
        ┌────────────────────────────────────────────┐
        │   ░░ frozen avalanche wave behind the throne ░░
        │              [ FROSTBOUND THRONE ] Y28      │   140 × 110 dais
        │          /           ‖ royal stair  \       │
        │ [WEST CHAPEL] Y16    ‖        [EAST CHAPEL] Y16
        │       ‖              ‖              ‖       │
        │ [WEST AISLE] ═transept═ [NAVE] ═transept═ [EAST AISLE]
        │   Y6      ¦ colonnade ¦  Y8  ¦ colonnade ¦  Y6
        │        \             ‖              /       │
        │     ~~~ FROZEN ANTECHAMBER  Y0 ~~~          │   return ramps from the chasm
        │                      ‖                      │
        │                [ SANCTUARY ] Y8             │
        └────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Frozen Antechamber | 0, 0, 180 | 480 × 100 | The hall's great porch, doors burst open by ice |
| `Crossing` | Nave of Kneeling Knights | 0, 8, 10 | 72 × 120 | Ward-star floor inlay, knights kneeling in ice along both edges |
| `WestGallery` | West Aisle | −170, 6, 20 | 86 × 80 | Behind the colonnade, shattered stained glass glazed over with ice |
| `EastGallery` | East Aisle | 170, 6, 20 | 86 × 80 | The mirror of the west aisle; a frozen font |
| `WestBastion` | West Chapel | −165, 16, −130 | 86 × 80 | The order's chapel, rows of Glacial Urns |
| `EastBastion` | East Chapel | 165, 16, −130 | 86 × 80 | The reliquary chapel, the Permafrost Core in an iron cage |
| `Apex` | Frostbound Throne | 0, 28, −232 | 140 × 110 | The dais, under a crown of icicles hanging from the broken vault |

**Paths:** `Sanctuary→Basin`, `Basin→Crossing`, `Basin→WestGallery`, `Basin→EastGallery`, `Crossing→WestGallery` and `Crossing→EastGallery` (the **transepts**), `WestGallery→WestBastion`, `EastGallery→EastBastion`, `WestBastion→Apex`, `EastBastion→Apex`, `Crossing→Apex` (**STAIRS**: the royal stair, `Stairs = { Crossing_Apex = true }`). Return ramps from the chasm.

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5, `EAST_GALLERY` 5, `UPPER_WEST` 5 (Elite), `UPPER_EAST` 5 (Elite), plus Elite flags on two other camps to make 4. The Boss is summoned on the dais (95-stud leash). Glacial Cleave, Blizzard Shock and Ice Spikes must stay on the dais and never spill onto a ramp.

**Patrols:** the generic routes work; add an authored `TRANSEPT` = {WestGallery, Crossing, EastGallery}.

**Set pieces:**
- The **frozen avalanche wave**: a huge curling ice crest (kit mesh) rising behind the throne from the back wall. It reaches forward no further than the back third of the dais, and **never overhangs the arena or a walkway**, so the camera and the boss fight stay clear.
- Ice-pillar colonnades between the nave and the aisles, with gaps where the transepts cross.
- Knights kneeling along the nave's edges, kept outside the stair's and the transepts' landing lanes.
- The throne under a crown of icicles, with the King's Stillheart glow: a cheap Neon pulse, not particles.
- A shattered rose window glazed with ice on the north wall.

**Ecosystem weight:** ice and stone, no flora at all. The postcard floor: everything stopped.

---

## Part 3: Environment and lighting per floor

Add `HubLighting.FloorGrades[16..20]`, each layered over the Frozen biome grade ("cold, clear blue"), as Floors 1–5 and 11–15 did. `ClockTime` is shared and never changes; read time of day through colour shift, ambient, atmosphere, tint, bloom and sun rays.

| Floor | Time | Light | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 16 | Overcast whiteout morning | Flat, bright, low contrast | Thick white haze (keep camps readable) | Blue glow inside the Rimefall |
| 17 | Clear cold noon | Crisp, high contrast, blue shadows | Thin, clear | Sparkle on frost; hard shadows |
| 18 | Blizzard afternoon | Dim and diffuse | Dense blue-grey haze, snow streaks | Readable at 120 studs: test it |
| 19 | Twilight with aurora | Deep blue ambient, green-violet sky | Moderate haze | Rimelight crystals carry the cave route |
| 20 | Frozen night | Indigo, moonlit | Still and clear: no wind in the hall | Cyan Stillheart bloom, ice glints |

Floors 18 and 20 are the readability risks: test that mobs, telegraphs and loot read, and raise ambient or exposure if they don't. Effects are client-only and pooled, and respect the Graphics quality setting.

---

## Part 4: Engineering — extend the data-driven pipeline

### 4.1 Masonry styles as data first

The Ashen floors added `Masonry` styles as growing `if layout.Masonry == "VARRASH_…"` branches in `TowerRoomBuilder` (decks, stairs, suspended links and curbs). **Before adding Frozen styles, turn these into a `MASONRY_STYLES` table:** colours, materials, curb style, stair treads, deck trim and suspended-deck supports, keyed by the `Masonry` name. Keep every existing Verdant and Ashen floor **visually identical**, proven by a snapshot spec over the built part properties if you can build headlessly, otherwise by a Studio before/after part-property dump for Floors 1–5 and 11–15. Commit: `refactor(tower): drive masonry styles from a style table`.

Then add the Frozen styles:

| Style | Used for | Look |
| --- | --- | --- |
| `WHITEGUARD` | Barracks, keep and fortress decks | Blue-grey granite courses, iron studs and bands, frost on top faces |
| `GLACIER_SLAB` | Floes and Iceway slabs, ice bridges | `Glacier` material, translucent edges, banded with dirt layers |
| `THRONE_HALL` | Nave and dais | Polished granite, a ward-star inlay, ice glaze |

`PathStyle = "WHITEGUARD"`:
- Ramps are granite flagstones with frost.
- Kerbs are iron-capped granite, with snow drifted on the north side.
- Stairs are granite with ice-glazed treads.
- Landings take the terrace's own snow.
- On direct-terrain floors the walkable earth is sculpted `Terrain`: `Snow` on top, `Glacier` and `Rock` on slopes.

### 4.2 Terrain features

Reuse existing kinds where they fit. Their materials come from the Frozen palette: `Snow`, `Glacier`, `Rock`, and `Ice` as the solid liquid.
- `DUNE` makes **snowdrifts**: orient them north to south, crests leaning south, with the drift on north faces.
- `RAVINE` makes **crevasses**: Floor 18 needs two, one either side of the spine.
- `CENOTE_LAGOON` or `POOL_ELLIPSES_SQ` makes the **frozen lake** on Floor 16.

Add new kinds only where nothing fits, each data-driven and obeying every terrain rule:
- `GLACIER_SPINE`: a raised banded ridge under the Floor 18 slabs.
- `ICEFALL`: frozen cascade terrain on a wall (the Rimefall's base and the Icefall Gate).
- `PRESSURE_RIDGE`: heaved ice lines across the frozen lake.

The terrain rules:
- Never above a walkway.
- Never under the chasm floor.
- The 6-stud moat and canyon-wall rule beside walkways.
- The `RES / 2` isosurface offset.
- FBM-warped edges.

`Liquid` on these floors is frozen (`Ice`, solid). It is cosmetic: never slippery, never a hazard, never part of a lane. Players may walk on the lake ice off-route, but heroes route by connectors only, and no camp or patrol relies on lake ice.

### 4.3 Kits

Follow the per-floor kit pipeline:
1. Generate them with `tools/blender/generate_frozen_fN_kit.py`, writing `assets-source/tower/frozen_fN_kit/` (FBX, manifest and previews). Use the same runner as the Ashen generators; the project memory has the headless Blender path, run with `--background`.
2. Register them in **`TowerBiomeKit.ExtraTemplates`** only. Adding to `Templates` gates `KitProps.Ready()` on every floor.
3. Add them to the Studio importer.
4. Place each one behind `if KitProps.Has(name) then … else <native fallback> end`.

Candidates:
- Floor 16: `RimefallIcefall`, `IceFloeSlab`, `HuntersLodge`, `FisherHut`
- Floor 17: `BarracksBlock`, `FrozenSoldier`, `KennelRow`, `IceBrazier`
- Floor 18: `SeracCluster`, `IceSlabBridge`, `CrevasseCartPillar`, `GlacierShrine`
- Floor 19: `IceCaveOverhang`, `RimelightCrystalCluster`, `WhiteguardTower`, `FrozenSiegeLadder`, `FrozenTrebuchet`
- Floor 20: `KneelingKnight`, `IcePillarColonnade`, `FrozenAvalancheWave`, `ThroneOfIcicles`, `ShatteredRoseWindow`

The Frozen kit palette already has `MOSS` (snow), `WOOD`, `FOLIAGE`, `CRYSTAL` (ice) and `ALT`. Add `GRANITE` or `IRON` swatches if you need them.

**Import the FBXs into the live experience, not only a copy.** The main experience (`Infinite Towers: Become a Master!`, placeId 136256010643848) was once missing the Verdant Floor 5 kit while a copy place had it.
- After importing, check `ServerStorage.TowerBiomeKit` against the **repo's** `ExtraTemplates` list, read fresh.
- Edit-mode `require` caches modules. The importer now clones the module to work around this; do the same in any check you write.
- Save the place.

### 4.4 Lessons from the Ashen build (each one came from a fix commit)

- **Big landmarks vs. boss portals:** keep every Apex landmark clear of the boss portal lanes (`Layout.PortalSpots`). The Cinder Gate arch had to be moved for this.
- **Overarching spans vs. camp clearance:** arches and spans over a camp need the camp-centre exemption the Ashen work added, or the camp cull removes them. Use it deliberately, never to hide a prop inside a camp.
- **Imported landmarks vs. camps and lanes:** check each kit landmark's real scaled footprint, from the template `Size` × scale, against `Lanes` and `Camps` **offline** before building. One overlapping part removes the whole prop.
- **Ground everything:** ruins and cliffs needed grounding fixes. Every prop stands on terrain or a terrace, and frozen-moment pieces stand on their ice pillars.
- **Never stand a whole tree or kit model on a ledge, branch or roof.** Strip it to the part you need (the Verdant canopy lesson).

The rules carried over from Verdant: players walk on direct `Terrain`, and grounding raycasts include `workspace.Terrain` with `IgnoreWater = true`. Solid parts are kept for built masonry and suspended decks.

### 4.5 Budgets

- Measure each Frozen floor first (parts, local lights, particle emitters) and put the baselines in the PR.
- Each floor stays within +25% parts, ≤ 24 local lights and ≤ 12 active emitters, not counting client ambient life.
- Rimelight and the Stillheart use Neon and bloom, not lights.
- Floors 19 and 20 are the risk (crystals, colonnades, the frozen army): check frame rate on a low-end setting.

### 4.6 Data and saves

The layout isn't saved. No profile schema change and no `DataManager.SyncProfile` migration are needed. If you find otherwise, stop and say so.

---

## Part 5: Process, tests and docs

### Phases and the review gate

1. **Masonry refactor (§4.1)** with no visible change.
2. **Design gate.** For each Frozen floor, show:
   - the final coordinate table
   - an ASCII map with links, camps and patrols
   - every link's rise and slope
   - the terrain features (with any new kinds)
   - the kit templates you plan to generate, each with a one-line silhouette description

   **Stop and wait for sign-off.**
3. **Floors 16–20**, one at a time, lowest first. Each floor's kit, terrain, layout and set pieces go in one commit: `feat(tower): author Frozen floor N (<name>)`.
4. **Lighting:** `FloorGrades[16..20]`. **Ambient life** (client-only).
5. **Kits imported into the main experience** and verified (§4.3).
6. **Docs and tests**, then open the PR against `main`.

### Tests

```bash
pwsh tests/run.ps1 -LuauDirectory D:/luau
```

Never pass `-InstallLuau`. Extend:

- `tower-layout-variants.spec.luau`: each Frozen floor is authored and fixed, with its key, name and signature links:
  - Floor 16 has both a shoreline route and a floe route to the Apex.
  - Floor 17's streets form a cycle (WestGallery → Crossing → EastGallery → Basin → WestGallery) and converge on the Armory.
  - Floor 18's `Crossing` links to both moraines, and the East Moraine reaches the Apex only via the Upper Iceway.
  - Floor 19's west and east routes share no terrace below the Apex.
  - Floor 20 has the transepts and the royal stair.

  Plus: mob totals and Elite counts, camps inside their terraces and never on an `ExtraPlatform`, and everything reachable from the Sanctuary.
- `tower-patrols.spec.luau`: authored patrols resolve on Floors 18–20, and every floor has exactly one `Always` route.
- `tower-portals.spec.luau`, and `tower-biome-kit.spec.luau` (Frozen `ExtraTemplates` well-formed, `Templates` unchanged, `FloorGrades[16..20]` layered over the Frozen grade).
- A snapshot showing that Floors 1–15 and Floors 21–50 are unchanged (layout, lanes, patrols).

Then, in Studio, run `tests/studio-tower-prop-audit.luau` for all 50 floors. Orphaned props, floating props and props on walkways must all be **0**.

### Docs (same PR)

- `docs/GAME_DESIGN.MD` §3.3:
  - the Whiteguard, the Stillheart, the Stillcold and the frozen-moment rule
  - the five Frozen floors (shape, terraces, camps, patrols, environment)
  - the masonry style table
- `docs/TOWER_NAVIGATION.md`: any new terrain feature kinds.
- `reference/infinite_towers_biomes.md` §4: a short paragraph on the Whiteguard and the Stillheart.

### Finish with a Studio checklist for the user

Don't run the playtest yourself. End with a **How to test** checklist the user can follow, covering at least:

1. Floors 16–20:
   - arrive out of aggro
   - walk every route to the Apex
   - nothing floats; frozen-moment pieces stand on ice
   - nothing sits on a walkway
2. Floor 16: the floe chain and the shoreline both reach the shrine; the Fisher's Hut is a side floe.
3. Floor 17: loop the streets; every street reaches the Armory, and its stair leads to the Commander's Hall.
4. Floor 18:
   - both ice bridges from the Lower Iceway work
   - the East Moraine reaches the gate only via the Upper Iceway
   - drop into a crevasse and climb out by a return ramp
   - the blizzard is readable
5. Floor 19: the cave route is readable from the camera (overheads ≥ 18 studs, translucent roofs); the battlement route via the viaduct; the routes meet only at the Keep Hall.
6. Floor 20:
   - nave, transepts, aisles, chapels and royal stair
   - summon the King: his telegraphs stay on the dais
   - the avalanche wave never covers the fight
   - kill him: the Ascend and Rerun portals rise
7. Squad follow and recall (`E`) on ice bridges, the viaduct and the royal stair.
8. Patrols walk their routes.
9. Relic Rain lands on Frozen ramps (`workspace.TowerEventForce = "RELIC_RAIN"`).
10. Each floor's lighting changes on entry and restores in the hub.
11. Floors 1–15 and 21–50 look and play exactly as before.
12. Frame rate on Floors 19 and 20 at a low-end setting, compared with the baselines.
13. In the main experience, the Frozen kits show as meshes, not part fallbacks.

## Out of scope

- Other biomes.
- New enemies or boss mechanics, slippery ice, cold damage, freezing status effects, or weather that touches combat.
- Changes to rewards, relic drops, mob stats or camp respawn timing.
