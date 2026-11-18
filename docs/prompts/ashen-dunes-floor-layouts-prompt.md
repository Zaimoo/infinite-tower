# Prompt: Ashen Dunes — a Unique Layout for Every Floor (Floors 11–15)

Copy everything below the line into a Claude Code session opened at the repo root.

> **Written 2026-11-18**, after Verdant Ruins Floors 1–5 were built (`docs/prompts/verdant-ruins-floor-layouts-prompt.md`; Floor 1 in PR #328, Floors 2–5 on `feat/verdant-floors-2-3-4`). This brief reuses everything those floors added. Part 4 lists the conventions to follow and the gotchas they left behind. The starting coordinates in Part 2 were run through `TowerLayout.Validate` with no problems, and every link is at or under 15°.

---

## Role

You are a two-specialist team speaking as one. Say which role you are speaking as when it matters.

**Warden** is a senior level designer and gameplay engineer for *Infinite Tower: Become a Master!*, a Roblox squad-command action RPG. Warden owns topography, sightlines, combat spaces, pacing, navigation and the `TowerLayout` connector contract. Warden thinks in walkable surfaces, link slopes, camp spacing, leash radii and the route a squad of five takes from the Sanctuary to the Apex.

**Cinder** is a senior environment artist and world-builder. Cinder owns the ecosystem, the landforms, landmarks, materials, lighting and atmosphere. Cinder builds them from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the Verdant floors do. Every prop has a reason to exist in the ecosystem and reads clearly from the gameplay camera.

Neither of you breaks the runtime contracts described below.

## Before you start

1. Follow `CLAUDE.md` and `AGENTS.md`. Use the `roblox-world-building`, `roblox-luau`, `roblox-npc-ai` and `roblox-performance` skills.
2. Read `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, hand-authored floors) and the lighting section, `docs/TOWER_NAVIGATION.md`, and `reference/infinite_towers_biomes.md` §3.
3. Read `docs/prompts/verdant-ruins-floor-layouts-prompt.md`, especially its status note and §4.3 (Scenery, Terrain & Headless Blender Pipeline). The Verdant floors are the worked example for everything here.
4. Read all of `src/ReplicatedStorage/Shared/Config/TowerLayout.luau` (the `AUTHORED` table, `build`, `Validate`, `PatrolRoutes`, `Lanes`). Then read how the Verdant floors are built:
   - `TowerRoomBuilder.luau`: `DECK_PLATFORMS`, `SUSPENDED_LINKS`, `isDirectTerrainLayout`, `isFortressStone` and the Solmere path style.
   - `TowerTerrain.luau`: the per-floor deck and suspended maps, `liquidLevel`, and the per-floor wet and moat shaping.
   - `TowerBiomeAssets.luau`: the `layout.Authored == "verdant:N"` set pieces.
   - `TowerBiomeKit.luau` (`ExtraTemplates`) and `TowerKitProps.luau` (`Has`, `Ready`).
   - `HubLighting.luau` (`FloorGrades`).
5. Verdant Floors 2–5 live on `feat/verdant-floors-2-3-4`. Branch from `main` **after that merges** (`feat/ashen-dunes-floor-layouts`). If it hasn't merged, stop and ask; don't branch from a branch that is still under review. Use conventional commits.

## The goal

The five Ashen Dunes floors (11–15) still use the seeded generic layout and the generic Ashen props: an obsidian crag, sandstone arches, dead trees and a volcano backdrop. Give each one its own hand-authored topography, built around one ecosystem, so that each floor has a different shape, route and combat rhythm. Each floor must also be clearly different from its Verdant counterpart, not a sand-coloured copy. Biomes 2 and 4–10 stay exactly as they are.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, landform and creature traces back to this ecosystem. If a prop doesn't fit, cut it.

### The lost civilisation: the Varrash

The Varrash were caravan traders and glassmakers who lived on the routes that crossed the black desert. Their craft was **bottling sunfire**: they fed their kilns from a magma vein under Mount Cinderhold and blew the light into glass. Their motif is the **sealed flame**: a teardrop of amber glass in a hexagonal sandstone cage. It appears on gates, urns, waystones and the Colossus's chest.

Their architecture is banded sandstone (rust and cream courses) on black basalt footings, with amber glass windows and bronze cage-work weathered dark. They built **caravanserais, kiln towers, toll gates and waystones**: everything was oriented to the trade road.

The Varrash tapped the vein too deep. Cinderhold erupted, the ash buried their caravans and cities, and the vein's heat glassed a long scar across the land: **the Sunscar**.

### The Ember Vein

The Ember Vein is the Ashen counterpart of the Verdant Heartroot. It is the magma vein under all five floors, and it shows more of itself the higher the player climbs:

| Floor | Where on the Vein | What the player sees |
| --- | --- | --- |
| 11 | Its far reach | Warm sand, faint heat shimmer, a few steam vents, first ashbloom flowers |
| 12 | Under the trade road | Ash-buried caravans; sand glassed in patches where the vein ran close |
| 13 | Where it broke the surface | A ravine with walls fused to black-and-amber glass by an ancient lightning storm and the vein's heat |
| 14 | The Varrash tap | A kiln fortress built straight over the vein; the Sunscar's lava fissure splits it |
| 15 | The vent mouth | Cinderhold's caldera: a cracked-lava lake, ash fall, and the Sandstone Colossus guarding the vent |

### The glasswind

Hot wind laden with glass grit. It drives the dunes (ridges run roughly west to east across every floor, crests leaning east), carves the sandstone into hoodoos and mushroom rocks, and polishes basalt and obsidian. It also buries and unburies ruins, so Varrash stonework is always partly under sand, with drifts piled on its west faces.

### Living layers (use all of them on every floor, weighted per floor)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Landform** | Dunes, hoodoos, mushroom rocks, mesas, basalt columns, obsidian flows | The main skyline. Dunes are terrain; rocks are kit meshes or parts. |
| **Flora** | **Ashbloom** (orange flowers that open in heat, the biome's main colour accent), **ember cacti** (barrel cacti with faint glowing seams), **glasswort** (low shrubs crusted with salt-glass beads), bone-white petrified trees, rust lichen on basalt | Sparse, in clusters, always where there's shade or a vent. |
| **Heat** | Steam and heat vents with yellow sulphur crusts, glowing cracks, the cracked-lava chasm | Lava is cosmetic: never a hazard, never a walk surface. |
| **Glass** | Fulgurites (lightning-fused sand tubes), glass fields, obsidian shards, amber Varrash glass | The light sources and the sparkle. Neon only as accents. |
| **Stone** | Varrash gates, kiln towers, caravanserais, waystones, buried wagons, giant fossils | Always half-buried, with drifts against the west faces. |

### Food web (how the enemies fit, `MobCatalog` → `ashen_dunes`)

- **Dune Scarab** (`INSECT`) rolls balls of ash and dung and burrows in dune lees. Put dung balls and burrow holes near camps.
- **Ash Raider** (`WEAPON_BIPED`) is what remains of the Varrash caravan guards: cloth-wrapped scavengers with curved blades. Put raider camps among wagon wrecks, with tarps strung between them.
- **Ember Oracle** (support, `WARD`) is a veiled seer who tends ember shrines (glass flames on stone posts). Put a shrine at camps so the support looks at home.
- **Glass Scorpion** (`SCORPION`, Elite) lives in the glass fields and its carapace has turned to glass. Put glass-field patches where Elites tend to lead.
- **Sandstone Colossus** (`STONE_COLOSSUS`, boss, Floor 15) is the Varrash furnace guardian. A magma heart in a glass cage sits in its chest; it is the "Heart of the Sandstone Colossus" relic skin. Its moves are Magma Cleave, Sand Quake and Obsidian Spikes.

The relic skins already tell this story (`RelicConfig` → `ASHEN`): the Vitrified Glass Geode (fulgurites), the Sun-Scorched Urn (caravans), the Sandstorm Core (the glasswind) and the Colossus Heart. Echo them in set pieces.

### Ambient life (client-only, purely cosmetic)

Heat shimmer over vents and lava, ash flakes drifting down, small dust devils crossing open sand, embers rising from cracks, a few carrion-bird silhouettes circling, and beetles skittering on dune faces. Everything is client-side, pooled, culled by distance, scaled by the Graphics quality setting (`SettingsGraphicsEngine`), and off at the lowest quality. Nothing replicates from the server.

---

## Part 2: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north (the Apex side). Y is the walkable top surface. Footprints, height bands, chasm depth and mob totals follow GDD §3.3 by floor-in-biome.

The values below are **validated starting points**: they pass `TowerLayout.Validate` with no problems, and every link is ≤ 15°. Tune them, keep the shape and intent, and re-run the validator after every change.

**Fixed on every floor:**

- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, 128 × 56. Arrival, banking, portals and the exit lane are unchanged. `Basin` stays centred at X = 0 (a spec asserts it).
- The `Apex` holds the Alpha or Boss summon and the boss portals at its back.
- Arrivals land out of aggro: the Basin centre below the arrival ramp stays clear.
- Mob totals and Elite counts are unchanged: **16 / 22 / 25 / 35 / 35** live mobs and **1 / 2 / 3 / 4 / 4** Elites. From Floor 13, at least one Elite camp stands above the entry level. `ExtraPlatforms` hold no camps.

### Floor 11: Cinder Gate (`INTRODUCTION`)

*380 × 420 × 130, Y 0 to +12, no chasm. Searing noon.*

**Story beat:** the Varrash frontier toll gate, set into a basalt wall at the edge of the black desert. A great dune, the **Sleeping Dune**, has migrated into the courtyard and now blocks the straight road.

**Shape: a fork around a dune.** The Verdant Floor 1 avenue runs straight to the summit. Here the summit is in view but the way is blocked: the road splits round the Sleeping Dune, and its crest is a dead-end lookout that shows the whole floor.

```
                 N (−Z)
        ┌───────────────────────────┐
        │     [ CINDER GATE ] Y12   │   Apex: toll gate in the basalt wall
        │    /                 \    │
        │ [TOLL HOUSE]  /\  [WATCH KILN] Y7
        │   Y4      [DUNE CREST] Y10│   lookout on the Sleeping Dune (dead end)
        │      \    ~~dune~~   /    │
        │     ~~ ASH FLATS  Y0 ~~   │
        │            ‖              │
        │      [ SANCTUARY ] Y8     │
        └───────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Ash Flats | 0, 0, 82 | 330 × 88 | Wind-rippled black sand, half-buried waystones |
| `Crossing` | Dune Crest | 0, 10, −20 | 48 × 44 | The Sleeping Dune's crest: a lookout, sand-paved, one fallen waystone |
| `WestGallery` | Toll House | −116, 4, −20 | 84 × 76 | Roofless toll house, scales and coin chests, sand drifts |
| `EastGallery` | Watch Kiln | 118, 7, −44 | 80 × 72 | Squat kiln tower, amber glass windows, a cold beacon |
| `Apex` | Cinder Gate | 0, 12, −150 | 110 × 80 | The gate court, under a sealed-flame arch in the basalt wall |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `Basin→EastGallery`, `Basin→Crossing` (a sand slope up the dune; dead end), `WestGallery→Apex`, `EastGallery→Apex`. There is no `Crossing→Apex`.

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite), `EAST_GALLERY` 4. The Dune Crest has no camp (none on the Crossing at index 1). **Patrol:** `BASIN_LOOP`.

**Set pieces:**
- The **Cinder Gate** itself: a basalt wall with a sandstone gatehouse, and a sealed-flame teardrop in the keystone, glowing amber. The boss portals stand under its arch.
- The **Sleeping Dune**: a terrain dune about 140 wide whose crest *is* the lookout. Wind ripples, and a buried caravan wagon pokes out of its west flank.
- Waystones (sandstone posts with bronze flame cages) lining both forks, and toll scales at the Toll House.

**Ecosystem weight:** sand and stone, so the player learns the biome's palette. Only a little heat: one steam vent, the first ashbloom.

### Floor 12: Buried Caravan (`EXPANDED_ENCOUNTER`)

*420 × 470 × 140, Y 0 to +14, no chasm. Afternoon sandstorm.*

**Story beat:** a whole caravan swallowed when the ash fell, including the **Sand-Strider**, the giant beast of burden that pulled it. Only its fossil ribcage and skull still show.

**Shape: a switchback trail.** It's one long route that zig-zags up the floor east, west, then east, like a caravan road climbing a dune slope. It has no shortcuts and no forks: the Verdant floors always offer two ways up, and this one deliberately doesn't. The camps sit along the road.

```
                 N (−Z)
        ┌───────────────────────────────┐
        │          [ MASTER'S TOMB ] Y14│   Apex, off-centre east
        │                 /             │
        │ [SPICE VAULT] Y12             │
        │      \                        │
        │    [CARAVANSERAI ROOF] Y9     │
        │                   \           │
        │              [STRIDER'S RIBS] Y5   the ramp runs through the fossil ribcage
        │                  /            │
        │   ~~ WAGON CIRCLE  Y0 ~~      │
        │              ‖                │
        │        [ SANCTUARY ] Y8       │
        └───────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Wagon Circle | 0, 0, 110 | 360 × 96 | Wagons drawn into a defensive ring, half sunk in ash |
| `EastGallery` | Strider's Ribs | 130, 5, 10 | 88 × 76 | Under the fossil ribcage; the skull lies on its side |
| `Crossing` | Caravanserai Roof | −10, 9, −30 | 70 × 56 | The buried inn's flat roof, now ground level; skylights into the sand |
| `WestGallery` | Spice Vault | −130, 12, −80 | 88 × 76 | Collapsed warehouse, burst spice urns staining the sand red and saffron |
| `Apex` | Caravan Master's Tomb | 40, 14, −170 | 104 × 80 | A tented tomb-pavilion: torn awnings on bronze poles, a treasure dais |

**Paths:** `Sanctuary→Basin`, `Basin→EastGallery`, `EastGallery→Crossing`, `Crossing→WestGallery`, `WestGallery→Apex`.

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite). **Patrol:** `BASIN_LOOP`.

**Set pieces:**
- The **Sand-Strider fossil**: a ribcage of 8–10 arching ribs that the `EastGallery→Crossing` ramp runs through. Tag it so walkway clearance exempts it, as `RampArch` is; it straddles the lane above head height. The skull (a kit mesh) lies beside it.
- Buried wagons and wheels breaking the surface. Tarps strung between poles in the Ash Raider camps.
- The caravanserai's skylight grilles set flush in the roof, and burst urns on the Spice Vault (Sun-Scorched Urn style).

**Ecosystem weight:** sand, wreckage and wind. Heaviest dust in the biome, with the glasswind visible as ground-level sand streams.

### Floor 13: Glasswind Ravine (`TERRAIN_VARIATION`)

*460 × 520 × 155, Y −4 to +18, chasm (`Bottom = −4`). Dusk.*

**Story beat:** where the Ember Vein broke the surface, an ancient lightning storm and the vein's heat fused the ravine walls to black-and-amber glass. The glasswind howls down it.

**Shape: a north–south ravine with two ledges.** Verdant Floor 3's gorge runs east–west across the route. This ravine runs *along* it: the ravine floor is the chasm. Two ledge routes climb its walls at different heights, and a natural **Glass Arch** spans the ravine between them. The east ledge can only reach the summit by crossing the arch.

```
                    N (−Z)
        ┌────────────────────────────────────┐
        │        [ LIGHTNING SCAR ] Y18      │   Apex: a glassed crater
        │       /           ‖                │
        │ [WEST LEDGE]  [GLASS ARCH] Y5  [EAST LEDGE]
        │   Y10  ═══════/  ≈ravine≈  \══════  Y6
        │      ‖        ≈≈ black sand ≈≈   ‖ │   chasm floor, fulgurites, shards
        │    ~~~ RAVINE MOUTH  Y0 ~~~        │   return ramps from the ravine floor
        │                ‖                   │
        │          [ SANCTUARY ] Y8          │
        └────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Ravine Mouth | 0, 0, 124 | 400 × 104 | Wind-scoured basalt pavement, glass grit drifts |
| `WestGallery` | West Ledge | −140, 10, −34 | 80 × 110 | A long shelf on the west wall, under overhangs of glass |
| `EastGallery` | East Ledge | 140, 6, −56 | 80 × 110 | A lower, wider shelf; fulgurite "organ pipes" along its lip |
| `Crossing` | Glass Arch | 0, 5, −78 | 64 × 44 | A natural arch of fused glass over the ravine, amber glowing through it |
| `Apex` | Lightning Scar | 0, 18, −185 | 110 × 84 | A shallow crater of glass and fulgurites, a Varrash lightning rod at its rim |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `Basin→EastGallery`, `WestGallery→Crossing`, `EastGallery→Crossing`, `Crossing→Apex` (**STAIRS**, cut into the glass), `WestGallery→Apex`. Return ramps from the ravine floor to the Basin. The ledges are placed so these ramps run clear of them.

**Camps (25, 3 Elites, at least one above the entry level):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite).

**Patrols (authored, see §4.1):** `BASIN_LOOP`; `WEST_LEDGE` (WestGallery → its link → Apex); `ARCH_CROSSING` (WestGallery → Crossing → EastGallery, across the arch). The generic `GALLERY_EAST` can't be built here: there is no `EastGallery→Apex` link.

**Set pieces:**
- The **Glass Arch**: a suspended deck (masonry-style solid surface with recessed terrain beneath, as Verdant's root bridges are). It reads as one fused span: black glass with amber veins lit from inside.
- Ravine walls of terrain, with Glass / Basalt / Obsidian banding and glassy overhangs above the ledges (all above head height).
- Fulgurite clusters and shard fields on the ravine floor.
- One **sandfall**, a sand cascade pouring off the west rim (beams and particles), facing away from the ramps.

**Ecosystem weight:** glass and wind. Least sand, most sparkle.

### Floor 14: Sunscar Fortress (`ELITE_STRONGHOLD`)

*510 × 580 × 170, Y −4 to +22, chasm (`Bottom = −4`). Night, lit by kilns and lava.*

**Story beat:** the Varrash kiln fortress, built straight over the Ember Vein to tap it. The tap failed, and the **Sunscar**, a lava fissure, split the fortress down the middle.

**Shape: a single gate, a split fortress, and a bridge across the scar.** Verdant Floor 4 is a walled ring the player enters from both flanks. Here the Basin links **only** to the Kiln Gate, a real chokepoint. From the gate the fortress splits into west and east halves, divided by the Sunscar. The **Scar Bridge** joins the halves high over the lava, so squads can switch sides. Each half climbs its own tower to the throne hall.

```
                       N (−Z)
        ┌──────────────────────────────────────────┐
        │ [WEST KILN] Y14 ── [SUNSCAR THRONE] Y22 ── [SIGNAL TOWER] Y16
        │      ‖              ≈≈ scar ≈≈           ‖
        │ [GLASSBLOWERS' ROW] ═══ SCAR BRIDGE ═══ [CISTERN BARRACKS]
        │   Y8          \    ≈≈ lava fissure ≈≈  /   Y8
        │                 \   [KILN GATE] Y5   /    │   the only way in
        │                          ‖                │
        │      ~~~ ASHMARKET (lower town) Y0 ~~~    │
        │                          ‖                │
        │                   [ SANCTUARY ] Y8        │
        └──────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Ashmarket | 0, 0, 150 | 440 × 110 | The lower town: market stalls under ash, a dry fountain |
| `Crossing` | Kiln Gate | 0, 5, 52 | 74 × 60 | Barbican gate, portcullis jammed half open, kiln glow behind |
| `WestGallery` | Glassblowers' Row | −160, 8, 0 | 86 × 78 | Workshops with cold glory-holes and racks of blown glass |
| `EastGallery` | Cistern Barracks | 160, 8, −10 | 86 × 78 | Barracks over a dry cistern; weapon racks |
| `WestBastion` | West Kiln | −160, 14, −150 | 84 × 76 | A bottle-shaped kiln tower, its top glowing |
| `EastBastion` | Signal Tower | 160, 16, −160 | 84 × 76 | Signal tower with a great amber lens |
| `Apex` | Sunscar Throne | 0, 22, −205 | 110 × 84 | Throne hall straddling the scar's head, the vein tap below a glass floor |

**Paths:** `Sanctuary→Basin`, `Basin→Crossing`, `Crossing→WestGallery`, `Crossing→EastGallery`, `WestGallery→EastGallery` (the **Scar Bridge**, a long suspended deck), `WestGallery→WestBastion`, `EastGallery→EastBastion`, `WestBastion→Apex`, `EastBastion→Apex`.

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5, `UPPER_WEST` 5 (Elite), `UPPER_EAST` 5 (Elite).

**Patrols:** `BASIN_LOOP`, `GALLERY_WEST`, `GALLERY_EAST`, `BASTION_RING` (the generic ones work here), plus an authored `SCAR_BRIDGE` (WestGallery → bridge → EastGallery).

**Set pieces:**
- The **Sunscar**: a cracked-lava fissure in the chasm running from under the throne to the Kiln Gate (terrain `CrackedLava` plus a neon glow seam). Heat shimmer over it, and embers.
- The Scar Bridge: sandstone arches on basalt piers that rise from the chasm floor beside the lava, never in it.
- Kiln towers glowing at the top, and the jammed portcullis.
- Market stalls with ash-heavy awnings, and broken amber-glass shards everywhere.

**Ecosystem weight:** fire and masonry. The least natural floor: it's a ruin built on a wound.

### Floor 15: Colossus Dais (`BOSS_ARENA`)

*560 × 640 × 190, Y −6 to +28, chasm (`Bottom = −6`). Eruption: a crimson sky with ash falling.*

**Story beat:** Cinderhold's caldera, at the vent mouth. Long ago an **Elder Colossus**, the first Varrash furnace guardian, fell here, and its stone body lies across the caldera. The player climbs over it to reach the dais where the Sandstone Colossus guards the vent.

**Shape: the route runs over a fallen giant.** Verdant Floor 5 spirals around a cenote. Here the path is the Elder Colossus's body, lying diagonally across the floor: up its open palm, along its forearm to its chest, then over its shoulder. The east side climbs its shattered shield and fallen crown instead. From the chest, a long stair up the old trade-road cut gives a direct, exposed route.

```
                         N (−Z)
        ┌────────────────────────────────────────────┐
        │              [ COLOSSUS DAIS ] Y28          │   140 × 110 at the vent mouth
        │          /           ‖            \         │
        │ [SHOULDER] Y16       ‖          [FALLEN CROWN] Y14
        │       \              ‖                ‖     │
        │        [ELDER'S CHEST] Y10            ‖     │   ≈≈ cracked-lava lake ≈≈
        │      /                          [BROKEN SHIELD] Y8
        │ [FALLEN HAND] Y6                     /      │
        │        \                            /       │
        │       ~~~ CALDERA FLOOR  Y0 ~~~             │   return ramps from the lava shore
        │                      ‖                      │
        │                [ SANCTUARY ] Y8             │
        └────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Caldera Floor | 0, 0, 176 | 480 × 108 | Ash plain at the lava's shore, glass-crusted |
| `WestGallery` | Fallen Hand | −180, 6, 30 | 88 × 80 | The Elder's open palm, fingers curled up as walls |
| `Crossing` | Elder's Chest | −30, 10, −40 | 80 × 64 | Its cracked chest plate, the empty heart-cage open |
| `EastGallery` | Broken Shield | 180, 8, 20 | 88 × 80 | Its great shield, split and tilted, half in the lava |
| `WestBastion` | Shoulder | −150, 16, −150 | 86 × 80 | The shoulder pauldron, ringed by basalt columns |
| `EastBastion` | Fallen Crown | 170, 14, −140 | 86 × 80 | Its crown, toppled on its side, a ring of sandstone spikes |
| `Apex` | Colossus Dais | 0, 28, −232 | 140 × 110 | Open dais at the vent mouth, magma glowing behind and below it |

**Paths:** `Sanctuary→Basin`, `Basin→WestGallery`, `WestGallery→Crossing` (the **forearm**), `Basin→EastGallery`, `Crossing→WestBastion` (the upper arm), `EastGallery→EastBastion`, `WestBastion→Apex`, `EastBastion→Apex`, `Crossing→Apex` (**STAIRS**, the long exposed climb up the trade-road cut). Two return ramps from the lava shore to the Caldera Floor.

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5, `EAST_GALLERY` 5, `UPPER_WEST` 5 (Elite), `UPPER_EAST` 5 (Elite), plus Elite flags on two other camps to make 4. The Boss is summoned on the Dais (95-stud leash). Magma Cleave, Sand Quake and Obsidian Spikes must stay on the dais and never spill onto a ramp.

**Patrols (authored):** `BASIN_LOOP`; `FOREARM` (WestGallery → Crossing → WestBastion); `SHIELD_CLIMB` (EastGallery → EastBastion); `CROWN_RING` (WestBastion → Dais edge → EastBastion). The generic `GALLERY_WEST` can't be built here: there is no `WestGallery→WestBastion` link.

**Set pieces:**
- The **Elder Colossus**: the body's pieces are the platforms themselves (palm, chest, shoulder) plus kit meshes for the forearm and upper arm that the ramps run along. The head lies face-down beside the crown, and a giant hand's fingers curl up around the palm as low walls.
- The **cracked-lava lake** filling the chasm, with glowing seams, heat shimmer and embers.
- The **vent** behind the dais: a magma column (cheap Neon plus beams; no heavy particles) with ash plumes. This replaces the generic volcano backdrop on this floor.
- Basalt columns ringing the dais.

**Ecosystem weight:** everything at full heat. This is the postcard floor.

---

## Part 3: Environment and lighting per floor

Add `HubLighting.FloorGrades[11..15]` the way Verdant Floors 1–5 did. Each grade layers over the Ashen biome grade ("hot orange dust"). `ClockTime` is shared and never changes, so time of day is read through colour shift, ambient, atmosphere, tint and bloom. `HubLightingController` already picks the grades up by floor id.

| Floor | Time | Light | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 11 | Searing noon | White-hot, slightly overexposed, short shadows | Thin heat haze, pale ochre | Glare off the glass; one steam vent |
| 12 | Afternoon sandstorm | Diffuse amber | Dense ochre haze (keep camps readable at 120 studs) | Sand streams at ground level |
| 13 | Dusk in the ravine | Low orange from the west, violet shade | Moderate haze, cool in the ravine | Amber glowing through the Glass Arch |
| 14 | Night | Dark blue ambient; kiln and lava glow does the lighting | Smoky, low | Bloom on lava seams and kiln tops |
| 15 | Eruption | Crimson sky, under-lit from below | Thick ash haze, falling ash | Strong bloom on the vent and lava |

Floor 14 is a night floor: test that mobs, telegraphs and loot stay readable, and raise its ambient if they don't. Effects are client-only and pooled, and respect the Graphics quality setting.

---

## Part 4: Engineering — build on the Verdant pipeline

### 4.1 Turn the Verdant special cases into data first

The Verdant floors hard-coded their keys in several places. Adding five Ashen keys to every list would make them unmaintainable. **Before authoring any Ashen floor, move these into the `AUTHORED` entries**, with Verdant behaviour unchanged:

| Today (hard-coded) | Where | Becomes an `AUTHORED` field |
| --- | --- | --- |
| `isDirectTerrainLayout` / `isDirectTerrain` key lists | `TowerRoomBuilder`, `TowerTerrain` | `DirectTerrain = true` |
| `DECK_PLATFORMS[key]` (two copies) | `TowerRoomBuilder`, `TowerTerrain` | `Decks = { Crossing = true, ... }` |
| `SUSPENDED_LINKS[key]` and `SUSPENDED_PLATFORMS[key]` | `TowerRoomBuilder`, `TowerTerrain` | `Suspended = { Links = {...}, Platforms = {...} }` |
| `isFortressStone` | `TowerRoomBuilder` | `Masonry = "FORTRESS"` (or a palette name) |
| `liquidLevel` per key, and the per-key wet, moat and pond shaping | `TowerTerrain` | `Liquid = { Level = 3.2, ... }` and `TerrainFeatures = { ... }` (see below) |
| `room.Authored == "verdant:4"` → `WALL_WALK` | `TowerLayout.PatrolRoutes` | `Patrols = { WALL_WALK = { "WestGallery", "Crossing", "EastGallery" } }` |

- **Patrols:** authored patrols are a list of terrace ids. `PatrolRoutes` turns each into points along the real connectors with the existing `pathBetween` helper. An authored floor that sets `Patrols` replaces the generic gallery and bastion routes, which assert that particular links exist (they fail on Floors 13 and 15 as designed). Keep exactly one `Always` route per floor: the entry loop.
- **`TerrainFeatures`:** a list of typed shapes that `TowerTerrain` stamps into its field, for example:
  - `{ Kind = "DUNE", X, Z, Length, Width, Height, Yaw }`
  - `{ Kind = "LAVA_CHANNEL", From, To, Width }`
  - `{ Kind = "RAVINE", ... }`
  - `{ Kind = "POND", ... }` and `{ Kind = "MOAT", ... }` (the Verdant shapes moved over)

  Each feature keeps the existing terrain rules: never above a walkway, never under the chasm floor, a 6-stud moat and canyon-wall rule beside walkways.

Prove the refactor before going further. Add a snapshot spec showing that Verdant Floors 1–5 and the generic Floors 6–50 produce the **same layout, lanes, patrols and terrain field samples** (sample a grid) as before. Commit: `refactor(tower): drive authored floor terrain, decks and patrols from layout data`.

### 4.2 Authoring

- Add `AUTHORED[11..15]` with keys `ashen:1` to `ashen:5`, `Name`, `Names`, `Paths`, `Stairs`, any `ExtraPlatforms`, and the data fields from §4.1. Keep the core role ids. The Sanctuary and Basin rules are in Part 2.
- New path style: `PathStyle = "VARRASH"`.
  - Ramps are banded sandstone flagstones with flush basalt step lips. Kerbs are sandstone with sand drifted against them on the windward side.
  - Stairs are cut sandstone; on Floor 13 they are black glass with amber inlay.
  - Landings take the terrace's own ground.
  - This follows the Solmere grammar: on direct-terrain floors the walkable earth is sculpted `Terrain` (Sand on top, Sandstone on slopes), and solid parts are kept for built masonry and suspended decks only.

### 4.3 Terrain, kits and scenery (the Verdant rules, applied to sand and lava)

**Terrain**
- **Direct-terrain walkways:**
  - Players walk on voxel `Terrain`. Terrace and landing parts become invisible, non-colliding proxies; only `BridgeCurb` rails stay solid.
  - Mind the `RES / 2` isosurface offset, and warp the edges with FBM noise so terraces don't look extruded.
  - Paint packed `Ground` or `Sandstone` down the path spines, with `Sand` around them and `Basalt` on cliffs.
- **Raycast contract:** every `Include`-filtered grounding raycast (`TowerFloorService.commit`, `GroundDrop`, `TowerEncounterRuntime.findGrounded`) includes `workspace.Terrain`, with `IgnoreWater = true`.
- **Dunes:**
  - Terrain features with ridges oriented west to east, crests leaning east, and wind ripples from noise.
  - A dune may rise beside a walkway only past the 6-stud moat, and never onto a lane. The Floor 11 Dune Crest is the one walkable dune top, and it is its own platform.
- **Lava** is `CrackedLava` (the Ashen palette's `LiquidSolid`). It is cosmetic: never a hazard, never part of a lane. Glow seams are thin Neon parts in the cracks, and heat shimmer is client-side.

**Kit meshes**
- Floor props go through the headless Blender kit pipeline:
  1. Generate them with `tools/blender/generate_ashen_fN_kit.py`, writing `assets-source/tower/ashen_fN_kit/` (FBX, manifest and preview renders). Use the same runner as `generate_verdant_fN_kit.py`; the project memory has the headless Blender path, and it runs with `--background`.
  2. Register them in **`TowerBiomeKit.ExtraTemplates`**, never in `Templates`. Adding to `Templates` blocks `TowerKitProps.Ready()` on *every* floor until it's imported.
  3. Add them to `tests/studio-tower-biome-kit-import.luau`.
  4. Place each one behind `if KitProps.Has(name) then … else <native-part fallback> end`.
- Candidate templates:
  - Floor 11: `CinderGateArch`, `VarrashWaystone`
  - Floor 12: `StriderRibcage`, `StriderSkull`, `BuriedWagon`
  - Floor 13: `GlassArchSpan`, `FulguriteCluster`
  - Floor 14: `KilnTower`, `SignalLensTower`, `PortcullisGate`
  - Floor 15: `ElderColossusForearm`, `ElderColossusHead`, `ElderCrown`, `BasaltColumnRing`
- The kit palette roles (`MOSS`, `WOOD`, `FOLIAGE`, `CRYSTAL`, `ALT`) already have Ashen swatches. Add `GLASS` (amber, slight transparency) if you need it, in `SharedPalette` or the Ashen palette.

**Scenery rules (unchanged)**
- Grounded clutter: nothing floats. Compound props are Models tagged `PropKind`.
- Clear walkways: `TowerLayout.Lanes` plus a 3-stud shoulder.
- Camp clearance: a 34-stud radius, from camp Y − 2 to camp Y + 22.
- Settle pass, and `OnTerrain` for props placed on terrain.
- Ecology `reservedSpots`, so the scatter grows around set pieces.
- Spanning props (the Strider ribcage, arches over ramps) use a walkway-exempt kind and keep everything above lane height (walk surface + 14).

**Lessons from Verdant Floor 1**
- **Never stand a whole tree or kit model on a branch, ledge or ribcage:** strip it to the part you need, as the Verdant Floor 1 canopy does.
- Check every big prop's footprint against the lanes **offline** (a Luau script over `Lanes` and `Camps`) before building. One overlapping part removes the whole prop.

### 4.4 Budgets

- Measure each Ashen floor in Studio before you change it: parts, local lights and particle emitters. Put the baselines in the PR.
- Each floor stays within +25% parts of its baseline, ≤ 24 local lights and ≤ 12 active particle emitters, not counting client ambient life.
- Lava glow uses Neon and bloom, not lights.
- Floors 14 and 15 are the risk: check frame rate on a low-end setting.

### 4.5 Data and saves

The layout isn't saved. No profile schema change and no `DataManager.SyncProfile` migration are needed. If you find otherwise, stop and say so.

---

## Part 5: Process, tests and docs

### Phases and the review gate

1. **Refactor (§4.1)** with no visible change, proven by snapshots.
2. **Design gate.** For each Ashen floor, show:
   - the final coordinate table
   - an ASCII map with links, camps and patrols
   - every link's rise and slope
   - the terrain features
   - the kit templates you plan to generate, each with a one-line silhouette description

   **Stop and wait for sign-off.**
3. **Floors 11–15**, one at a time, lowest first. Each floor's kit, terrain, layout and set pieces go in one commit: `feat(tower): author Ashen floor N (<name>)`.
4. **Lighting:** `HubLighting.FloorGrades[11..15]`. **Ambient life** (client-only).
5. **Docs and tests**, then open the PR against `main`.

### Tests

```bash
pwsh tests/run.ps1 -LuauDirectory D:/luau
```

Never pass `-InstallLuau`. Extend the existing specs to cover Floors 11–15:

- `tower-layout-variants.spec.luau`:
  - each Ashen floor is authored and fixed, with its key, name and signature links (Floor 11's crest has no `Crossing→Apex`; Floor 12 is one unbranched route; Floor 13's east ledge reaches the Apex only via the arch; Floor 14's Basin links only to the Kiln Gate)
  - mob totals and Elite counts
  - camps inside their terraces, never on an `ExtraPlatform`
  - every terrace and camp reachable from the Sanctuary
- `tower-patrols.spec.luau`: authored patrols resolve on Floors 13–15, every point is on a walkway, and each floor has exactly one `Always` route.
- `tower-portals.spec.luau`: the portal spots on the Apex.
- `tower-biome-kit.spec.luau`: every Ashen `ExtraTemplates` entry is well-formed, `Templates` is unchanged, and `FloorGrades[11..15]` layer over the Ashen grade.
- The snapshot spec from §4.1: Verdant floors and the generic floors are unchanged.

Then, in Studio, run `tests/studio-tower-prop-audit.luau` for all 50 floors. Orphaned props, floating props and props on walkways must all be **0**.

### Docs (same PR)

- `docs/GAME_DESIGN.MD` §3.3:
  - the Varrash, the Ember Vein and the glasswind
  - the five Ashen floors (shape, terraces, camps, patrols, environment)
  - the `AUTHORED` data fields from §4.1
- `docs/TOWER_NAVIGATION.md`: authored patrols and the terrain features.
- `reference/infinite_towers_biomes.md` §3: a short paragraph on the Varrash and the Ember Vein.

### Finish with a Studio checklist for the user

Don't run the playtest yourself. End with a **How to test** checklist the user can follow, covering at least:

1. Floors 11–15:
   - arrive out of aggro
   - walk every route to the Apex
   - nothing floats; no prop or dune sits on a walkway
2. Floor 11: the Dune Crest is a dead end with the whole floor in view.
3. Floor 12: the only way up is the switchback, through the Strider's ribs.
4. Floor 13: the east ledge must cross the Glass Arch; drop into the ravine and climb back out by a return ramp.
5. Floor 14: the Kiln Gate is the only way in; switch sides over the Scar Bridge; the night is readable.
6. Floor 15:
   - climb hand → forearm → chest → shoulder, and the shield and crown side
   - summon the Colossus: its telegraphs stay on the dais
   - kill it: the Ascend and Rerun portals rise
7. Squad follow and recall (`E`) on sand ramps, glass stairs and the long bridges.
8. Patrols walk their authored routes.
9. Relic Rain lands on Ashen ramps (`workspace.TowerEventForce = "RELIC_RAIN"`).
10. Each floor's lighting changes on entry and restores in the hub.
11. Verdant Floors 1–5 and Floors 6–10 and 16–50 look and play exactly as before.
12. Frame rate on Floors 14 and 15 at a low-end setting, compared with the baselines.

## Out of scope

- Other biomes.
- New enemies or boss mechanics, hazards, damaging lava, sandstorm gameplay effects or weather that touches combat.
- Changes to rewards, relic drops, mob stats or camp respawn timing.
