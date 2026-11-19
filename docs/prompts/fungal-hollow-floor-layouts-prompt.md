# Prompt: Fungal Hollow — a Unique Layout for Every Floor (Floors 6–10)

Copy everything below the line into a Claude Code session opened at the repo root.

> **Status (2026-11-18).** Floors 6 and 7 are built on `feat/fungal-floor-6` (branched from `main`, not from the Verdant branch) and verified in Studio: spawns, surfaces and every route. Floor 7's middle terrace is a rounded terrain island (`Terrain.Shapes`), not a slab. Floor 8 is written (Studio verification pending): the cap top is a round deck (`Terrain.RoundDecks`), the walkways are hung plank decks (`Terrain.Bridges`), the aqueduct runs east-west and the wings sit north of the chasm return ramps (Violet Cap −140, 8, −20, 62 × 62; Crystal Islet 150, 4, −30; Old Aqueduct 10, 12, −60, 96 × 48). Floor 9 (Rotcap Keep) is built and Studio-verified (props, raycasts/Blockcasts, specs, 7-template `fungal_f9_kit` Blender assets `BrokenBarricade`, `RotVat`, `OssuaryBones`, `RotcapTower`, `VelmariBanner`, `RotcapCluster`, `RotMyceliumWeb` exported to `assets-source/tower/fungal_f9_kit/`, tinted yellow-green + violet ecosystem role mix, alternating `VaultLantern`s, 8 tinted set-piece `PointLight`s including crown glow, yellow-green oculus spotlight, and `FloorGrades[9]`): wings shifted north of the chasm return ramps (`WestGallery` −156, 8, −12, 92 × 80; `EastGallery` 160, 12, −20, 92 × 80; `WestBastion` −150, 16, −144, 88 × 78; `EastBastion` 150, 20, −136, 88 × 78; `Crossing` 0, 20, −124, 76 × 62; `Apex` 0, 24, −228, 108 × 80) and `BASTION_RING` updated to cross `Crossing`. Floor 10 (Matriarch's Hollow, `fungal:10`) is built and Studio-verified (custom Asymmetric Radial Spiderweb layout: `Basin` 0, 0, 188, 480 × 104; `WestGallery` −184, 8, 12, 92 × 84; `EastGallery` 184, 12, 0, 92 × 84; `Crossing` 0, 12, −16, 76 × 76; `WestBastion` −176, 16, −124, 90 × 82; `EastBastion` 176, 20, −132, 90 × 82; `Apex` 0, 28, −228, 140 × 108; 11 web connectors with `Crossing_Apex` Silk Stair and 5 `Terrain.Bridges` web spans; 7-template `fungal_f10_kit` Blender assets `WebbedArchway`, `SilkSpire`, `BroodEggClutch`, `StolenLampCocoon`, `SilkWindlass`, `LastLampShrine`, `SilkWebCurtain` exported to `assets-source/tower/fungal_f10_kit/`, `FloorGrades[10]`, 24 lights with sole warm `LastLampWarmGlow`, prop/raycast/Blockcast/spec audits all clean). Terrain terraces must stand on multiples of 4 studs (smooth terrain only renders exactly on those planes). §4.1 was done as new data instead of a refactor of the Verdant tables, because `main` doesn't have them yet: `TowerLayout` `Terrain` (`Direct`, `Decks`, `DeckThickness`, `Pools`, `Islands`, `LiquidRise`, `FloorDip`, `WallBand`, `Surface`, `GroveScale`, `GroundCover`, `CliffVeins`), `Stairs`, `Skylight`, and `TowerTerrain.Surfaces`. When `feat/verdant-floors-2-3-4` merges, move its per-key tables (`DECK_PLATFORMS`, `SUSPENDED_*`, `isDirectTerrain`) onto this data.
>
> Original status: not started. This brief continues the Verdant Ruins work in `docs/prompts/verdant-ruins-floor-layouts-prompt.md`. It builds on the pipeline from `feat/verdant-floors-2-3-4` (Floors 2–4): `ExtraPlatforms`, `Stairs` overrides, direct-`Terrain` walkways, `TowerBiomeKit.ExtraTemplates`, the headless Blender kit scripts and `HubLighting.FloorGrades`. **Build Floor 6 first, then stop for review.** Floors 7–10 are designed below so that Floor 6's engineering fits all five, but they're built in later sessions.

---

## Role

You are a two-specialist team speaking as one. Say which role you are speaking as when it matters.

**Warden** is a senior level designer and gameplay engineer for *Infinite Tower: Become a Master!*, a Roblox squad-command action RPG. Warden owns topography, sightlines, combat spaces, pacing, navigation and the `TowerLayout` connector contract. Warden thinks in walkable surfaces, link slopes, camp spacing, leash radii and the route a squad of five takes from the Sanctuary to the Apex.

**Mycel** is a senior environment artist and world-builder. Mycel owns the ecosystem: fungi, crystals, water, creatures, landmarks, materials, lighting and atmosphere. Mycel builds with the sculpted Tower Biome Kit meshes, new Blender templates where the kit has nothing that fits, and native Roblox parts as the fallback, the way `TowerBiomeAssets.luau` already does. Every prop has a reason to exist in the ecosystem and reads clearly from the gameplay camera.

Neither of you breaks the runtime contracts described below.

## Before you start

1. Follow `CLAUDE.md` and `AGENTS.md`. Use the `roblox-world-building`, `roblox-luau`, `roblox-npc-ai` and `roblox-performance` skills.
2. Read `docs/GAME_DESIGN.MD` §3.3, `docs/TOWER_NAVIGATION.md`, `reference/infinite_towers_biomes.md` §2 and the concept art `reference/Fungal Hollow.png`. The art sets the **mood and palette**. The layouts below are original: don't trace the painting's composition.
3. **Study how the Verdant floors were built.** Read `docs/prompts/verdant-ruins-floor-layouts-prompt.md` (especially §4.3, "Scenery, Terrain & Headless Blender Pipeline"), then run `git diff main...origin/feat/verdant-floors-2-3-4` and read every change in:
   - `TowerLayout.luau`: `AUTHORED[2..4]`, `ExtraPlatforms`, `Stairs`, custom `Paths`, `Names`, the authored `WALL_WALK` patrol.
   - `TowerTerrain.luau`: `DECK_PLATFORMS`, `SUSPENDED_PLATFORMS`, `SUSPENDED_LINKS`, `isDirectTerrain`, the `RES / 2` alignment (`ownSurface - 2.0`), FBM-warped aprons (`warpDist`, `warpBeyond`), `TRAIL` kind, per-floor pools, rivers and moats, `liquidLevel`, and `materialFor`'s grass, dirt-trail and moss grammar.
   - `TowerRoomBuilder.luau`: invisible proxy slabs on direct-terrain terraces, solid masonry decks and stairs, organic root and stump pads, root-cable bridges, stepping-stone ramp lips, curbless natural paths.
   - `TowerBiomeAssets.luau`: per-floor set-piece branches keyed on `layout.Authored`, `KitProps.Has(name)` with native fallbacks, lanes and camp clearance, waterfalls facing away from ramps.
   - `TowerBiomeKit.luau` (`ExtraTemplates`, `CastsShadow`), `TowerKitProps.luau`, `tests/studio-tower-biome-kit-import.luau`, `tools/blender/generate_verdant_f{2,3,4}_kit.py` and `assets-source/tower/verdant_f{2,3,4}_kit/`.
   - `TowerFloorService.luau` and `TowerEncounterRuntime.luau`: raycasts include `workspace.Terrain` with `IgnoreWater = true`.
4. **Branch.** If `feat/verdant-floors-2-3-4` is merged, branch off `main`. If it isn't, branch off `origin/feat/verdant-floors-2-3-4` and say so in the PR. Name the branch `feat/fungal-floor-layouts` and use conventional commits.

## The problem today

Floors 6–10 use the seeded generic variants of the five canonical layouts, dressed with the generic Fungal kit: a `GiantMushroom` grove, `MushroomCluster` clutter, `CrystalSpire` monoliths, cobblestone arches and the `CavernSkylight` backdrop in `TowerBiomeAssets`. The terrain palette is `Mud`, `Slate` and `Basalt` (`TowerTerrain.Palettes.fungal_hollow`). The floors read as "Verdant with mushrooms": no ecosystem, no story, and the same shapes as every other biome.

**The goal:** give each Fungal Hollow floor its own hand-authored topography and a living, biome-specific ecosystem, with the same polish as Verdant floors 1–4: sculpted terrain you walk on, built masonry only where it makes sense, ground cover that makes the floor feel alive, and set pieces from Blender. Fungal Hollow must look and feel **underground**. It is not a forest with purple paint.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, fungus and creature below must trace back to this ecosystem. If a prop doesn't fit it, cut it.

### The scene

This is a twilight subterranean cavern of deep indigo slate and violet cobblestone, lit by an eerie bioluminescent cyan-and-violet glow. Dark teal pools shimmer under the bridges. Glowing mycelium veins pulse like nerves across the gallery walls. Giant mushrooms with violet domes, luminous cyan gills and hanging spore-bulb tendrils rise like umbrellas from the islands and slopes, next to translucent teal crystal spires. High overhead, a circular cavern skylight lets in pale cyan mist through a fringe of dangling roots.

### The lost builders: the Velmari lamp-masons

The Velmari were a subterranean order of masons who quarried the cavern and lit it. They had no sun, so they **farmed light**: they cultivated glowcaps, set teal crystals into their stonework, and carried light down into the dark. They built in **indigo slate and violet cobble**: arched aqueducts and bridges over the pools, lamp-galleries cut into the walls, stepped altars, and lamp-posts that hold a single glowing bulb. Their motif is the **gill-wheel**, a disc carved with radiating gill lines around a hanging bulb (a lantern seen from below). Put it on keystones, altars, lamp-posts and gates.

The Velmari over-farmed. The glowcaps joined into one organism, and the Velmari became its gardeners, then its congregation, then its food. Their robed descendants, the Sporecap Chanters, still keep candles burning on the altars.

### The Lampkeepers (the story the player follows)

Not every Velmari gave in. The **Lampkeepers** were the last of the order who refused the Veinweb. They kept their own lamps lit (plain flame and crystal, never glowcap) and fled *up* through the cavern, ahead of the bloom, toward the great skylight and the surface beyond it. They left a trail: lamps they kept burning, camps they made and abandoned, and their sign chalked on rocks at every fork, a **gill-wheel with one ray drawn long, pointing the way up**.

Their trail is the spine of Floors 7–10. It tells the player, without a word of text, that someone climbed this way before them, how far they got and what happened to them:

| Floor | The Lampkeepers' trail | Mood it sets |
| --- | --- | --- |
| 6 | Nothing yet: the Velmari are a ruin, centuries old | The past |
| 7 | The one living lamp in the Lantern Vault is theirs, freshly trimmed; a chalk sign beside it points up | Someone is here |
| 8 | Their refuge in the bloom: shelters under caps, a forward camp, rope bridges, a watch-post; the Sanctuary is their last lit camp | They lived here, and recently |
| 9 | Their last stand in the Velmari keep: barricades in the gates, their camp overrun and turned into a Chanter shrine, their lamps among the bones | They were caught |
| 10 | The last lamp: one Lampkeeper lantern still burning on the Silk Shore, and their stolen lamps wrapped in silk round the Matriarch's dais | The end of the trail, and why it ended |

Rules for every Lampkeeper piece: it's **built by people on the run** (rope, planks, cut cap, slate scavenged from ruins; nothing grand), it sits **off every lane and camp**, it's cosmetic (no collision, no gameplay), and it **never adds text**. Their warm flame-orange light is the only warm light in the biome besides the Chanters' candles, so the player learns to read warm light as "people".

### The Veinweb

A single mycelial organism, the **Veinweb**, runs through all five floors. The cyan-violet veins on the walls are its nerves, the giant mushrooms are its fruit, and the spore-bulbs are its seeds. Its fruiting heart is the **Spore Matriarch**. The player climbs *toward* the heart, and the network gets denser, brighter and more threatening on every floor.

| Floor | Where in the Veinweb | What the player sees |
| --- | --- | --- |
| 6 | The edge: first veins and the Elder Cap | Thin veins on the walls, one colossal mushroom, Velmari ruins still mostly stone |
| 7 | The gallery nets | Mycelium strung in nets across the Velmari lamp-galleries; veins thicken |
| 8 | The bloom | The cavern floor has fallen away; giant caps grow from the chasm, and some are walkable |
| 9 | The rot | Rotcaps have burst through the Velmari citadel; stone crumbles, the glow turns sickly |
| 10 | The heart | The Matriarch's nest under the great skylight; silk, egg-sacs, every vein converging |

### Living layers (use all of them on every floor, weighted per floor)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Canopy** | Giant mushrooms (violet domes, cyan gills, spore-bulb tendrils), dangling cavern roots, hanging moss strands | Rooted on the chasm floor, islands or slopes (the chasm-grove rule). Caps break the skyline the way trees do on Verdant floors. |
| **Understory** | Shelf fungi on walls and stems, mid-height mushroom clusters, teal crystal spires | Frames ramps without touching lanes. |
| **Cavern floor** (the biome's "grass") | Glowcap turf (dense tufts of tiny glowing caps), spore-moss mounds, violet cobble trails, scattered crystal shards, fallen Velmari masonry | The Fungal equivalent of the Verdant grass and moss. It must cover the ground densely and cheaply. See §4.3. |
| **Water** | Dark teal pools, small falls from the cavern walls, glowing pad-caps on the water | Cosmetic: never a hazard, never a walk surface you have to cross. |
| **Glow** | Mycelium veins on cliff faces, cyan gills, violet spore-bulbs, crystal cores, Chanter candles | The light sources. Neon only as accents; few real lights. |
| **Stone** | Velmari bridges, aqueduct arches, lamp-galleries, altars, lamp-posts | Always partly reclaimed: veins in the joints, shelf fungi on the sides, caps through the cracks. |

### Food web (how the enemies fit, `MobCatalog` → `fungal_hollow`)

- **Spore Skitter** (`CRAWLER`): spider-legged, glow-capped grazers that feed on the vein-bulbs. Show **grazed veins** (dark, dull stretches with the bulbs gone) and **egg-sac clusters** near their camps.
- **Lantern Spore** (`FUNGAL_BIPED`, projectile): mobile stalks that drink light and fire it back as spores. They gather around **crystal clusters**, so put crystals by their camps.
- **Sporecap Chanter** (support, `ROUSE`): robed, mushroom-capped descendants of the Velmari. They tend **candle altars**. Put a candle shrine at every camp that has a Chanter, so the healer looks at home.
- **Mycelial Brute** (`HEAVY_BIPED`, Elite and the floor Alpha on 6–9): heavy cap-brutes who drag spiked fungal clubs. They're the Veinweb's quarry-workers: show **smashed masonry**, club-drag scars in the cobble, and broken lamp-posts near Elite camps.
- **Spore Matriarch** (`FUNGAL_COLOSSUS`, boss, Floor 10): a multi-limbed spider-colossus with an expanding spore crown. Her nest is the Veinweb's heart.

### Ambient life (client-only, purely cosmetic)

Drifting spore motes in the skylight shaft, **spore-medusae** (slow, translucent, jellyfish-like puffballs that drift high over the pools, as in the art), glow-moths near the candles, dripping water from the roots, and a slow pulse along the veins. Everything is client-side, pooled, culled by distance and scaled by the Graphics quality setting (`SettingsGraphicsEngine`). Nothing ambient replicates from the server, and nothing floats on the server: the grounded-clutter rule still applies to every server prop.

---

## Part 2: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north (the Apex side). Y is the walkable top surface. Footprints, height bands and mob totals stay as in GDD §3.3. Positions and sizes are **starting values**: tune them until `Layout.Validate` and every spec pass, and keep the shape and intent.

Authored floors keep the role ids (`Basin` = ENTRY, `WestGallery`/`EastGallery` = WING, `Crossing` = CROSSING, `WestBastion`/`EastBastion` = UPPER_WING, `Apex` = APEX) because camps attach to them (`TowerLayout` `camp(...)`). In-world names go in `Names`. Use `ExtraPlatforms` only for terraces without camps.

**Fixed on every floor:**

- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, 128 × 56, with `CombatSafe`, `CanBankCargo` and `CanRecoverWipe`, its four portals and its exit lane.
- The Apex holds the Alpha or Boss summon and the portal spots at its back. It is at least 104 × 76 (Floor 10: larger).
- The arrival area below the Sanctuary ramp stays clear of camps.
- Mob totals and Elite counts are unchanged: **16 / 22 / 25 / 35 / 35** live mobs and **1 / 2 / 3 / 4 / 4** Elites. From Floor 8, at least one Elite camp stands above the entry level.
- `Validate`'s limits: non-fixed terraces stay 30 studs inside the side walls and 12 inside the front and back walls, and any two terraces keep a 10-stud gap (the Basin and the Sanctuary too: a deep floor's Basin has to sit far enough south of the Sanctuary).
- **Terrain terraces stand on multiples of 4 studs.** Smooth terrain only renders exactly on a plane at the voxel grid; decks (built masonry, cap tops) and ramps can be at any height. The Y values for Floors 8–10 below are already snapped.

### Floor 6: Sporelit Entry (`INTRODUCTION`) — BUILD THIS FIRST

*Footprint 380 × 420 × 130, Y 0 to +12, no chasm. Underground twilight.*

**Story beat:** the edge of the Veinweb. The Velmari's outer quarry: a still teal glowpool with one colossal mushroom, the **Elder Cap**, rising from an island in the middle. The walls carry the first thin veins. The ruins are still mostly stone.

**Shape: a horseshoe around the Elder Cap.** Verdant Floor 1 shows the Apex straight away. Floor 6 **hides** it: the Elder Cap's dome blocks the view north, and what the player sees from the Sanctuary is the **skylight's cyan shaft** glowing over the cap, a beacon to walk toward. Two routes wrap round the pool, one on each side. Neither runs through the middle.

```
                   N (−Z)
        ┌─────────────────────────────────┐
        │   ( skylight oculus overhead )  │
        │      [ SKYLIGHT DAIS ]  Y12     │   Apex under the shaft; Crown Cluster behind
        │     /                  \        │
        │    /  ~~~~~~~~~~~~~  [VEINSPAN] │   Crossing: Velmari bridge-deck, Y9
        │   /  ~  (ELDER CAP)  ~    ‖     │   central glowpool + island (not walkable)
        │ [CHANTERS'  ~~~~~~~~ [SKITTER   │
        │  TERRACE] Y8         WARREN] Y4 │   wings
        │     \                  /        │
        │   ~ GLOWPOOL SHORE  Y0 ~        │   Entry: wide cobble-and-turf shore
        │              ‖                  │
        │      [ LAMPWRIGHT'S LANDING ] Y8│   Sanctuary
        └─────────────────────────────────┘
                   S (+Z)
```

| Platform (role id) | Name | Centre (X, Y, Z) | Size (W × D) | Character |
| --- | --- | --- | --- | --- |
| `Sanctuary` | Lampwright's Landing | 0, 8, 176 | 128 × 56 | A Velmari lamp-gate landing; two gill-wheel lamp-posts |
| `Basin` (ENTRY) | Glowpool Shore | 0, 0, 96 | 320 × 80 | Glowcap turf, violet cobble trails, the south shore of the pool |
| `WestGallery` (WING) | Chanters' Terrace | −112, 8, −6 | 84 × 76 | A stepped candle altar under shelf fungi; Elite camp |
| `EastGallery` (WING) | Skitter Warren | 118, 4, 6 | 80 × 72 | Egg-sacs and silk between mushroom stems; grazed veins |
| `Crossing` (CROSSING) | Veinspan | 104, 9, −96 | 52 × 64 | A Velmari arched bridge-deck over the east pool, veins up its piers |
| `Apex` (APEX) | Skylight Dais | 0, 12, −150 | 104 × 80 | Round slate dais under the oculus; the Alpha's ground |

**Links (custom `Paths`):** Sanctuary→Basin; Basin→WestGallery; Basin→EastGallery; EastGallery→Crossing (**STAIRS**: the Mason's Stair, cut slate climbing onto the bridge); Crossing→Apex; WestGallery→Apex (the Mycelium Ramp: a long earthen ramp along the west shore). **There is no Basin→Crossing and no Basin→Apex link**: the pool forces the horseshoe. Check that WestGallery→Apex passes west of the Elder Cap island (at Z = −30 the ramp is near X ≈ −93; the island must stay within about X −45..45).

**Camps (16, 1 Elite; the generic index-1 roster):** `BASIN_WEST` 4 (pool-edge Skitters grazing a vein), `BASIN_EAST` 4 (Lantern Spores around a crystal cluster), `WEST_GALLERY` 4 (**Elite**: a Mycelial Brute and Chanters at the candle altar), `EAST_GALLERY` 4 (Skitter Warren), and `APEX_SANCTUM` (the Mycelial Brute Alpha under the shaft). The Veinspan has no camp: it's the calm, scenic route.

**Patrol:** keep the generic routes for index 1 (`BASIN_LOOP` as the always-on loop along the Glowpool Shore's north edge). Check they follow the authored links and don't step into the pool.

**Set pieces:**

1. **The Elder Cap.** A colossal mushroom about 90–110 studs tall on a rock island in the central glowpool: violet spotted dome, luminous cyan gills underneath, a dozen spore-bulb tendrils hanging from the rim with violet glowing bulbs, and mycelium roots splaying into the water. This is the floor's postcard and the reason the Apex is hidden. It needs a new Blender template (`ElderCap`); don't just scale `GiantMushroom`.
2. **The cavern skylight and the Crown Cluster.** Move the generic `CavernSkylight` over the Apex: a circular oculus in the vaulted ceiling (`TowerRoomBuilder` already leaves a skylight aperture; centre it over the Skylight Dais for this floor), a fringe of dangling roots hanging from its rim, a pale cyan light shaft down to the dais (a soft transparent beam, plus at most one `SpotLight`), and drifting mist. Behind the Apex, on the shelf, place the **Crown Cluster**: a colossal cluster of mushrooms at the top of the floor, framed by the oculus.
3. **The Veinspan.** The Crossing is built masonry (an `IsDeck` platform): a violet-slate bridge deck on two or three arches over the east pool, using the kit's `ArchPierBase`, `ArchPierSegment` and `ArchCrown` re-tinted indigo, with veins climbing the piers and two Velmari lamp-posts at its ends.
4. **The Chanters' altar.** A stepped altar with candle clusters and a gill-wheel lantern on the west terrace, outside the camp radius (new template `CandleAltar`).
5. **Teal crystal spires** in groves on the slopes and on small pool islets (`CrystalSpire` tinted teal, with `GLOW` cores), plus ground shards near the Lantern Spore camp.
6. **Mycelium veins on the walls.** Branching cyan-violet veins across the perimeter cliff faces and the Veinspan piers (new template `MyceliumVein`). A slow pulse is a cheap client-side colour tween, not particles.
7. **Small falls** from the north-west and north-east walls into the glowpool, facing away from every ramp; glowing pad-caps floating on the water.
8. **Skitter Warren dressing:** egg-sac clusters, silk strands between stems (grounded at both ends), and grazed veins.

**Ecosystem weight:** cavern floor, water and stone. One giant (the Elder Cap) instead of a forest, so the space reads as a cavern.

### Floor 7: Mycelium Galleries (`EXPANDED_ENCOUNTER`)

*Footprint 420 × 470 × 140, Y 0 to +14, no chasm. Deeper; the veins thicken.*

**Story beat:** the Velmari's lamp-galleries, cut in tiers into a cavern wall. The Veinweb has strung mycelium nets across them, like spider-silk across shelves.

**Shape: a switchback climb.** The main route zig-zags east → west → east up the wall. A shortcut ramp from the floor reaches the middle tier.

| Role id | Name | Centre | Size | Character |
| --- | --- | --- | --- | --- |
| `Basin` | Drip Hall | 0, 0, 118 | 340 × 88 | Dripping roots, puddle pools, glowcap turf |
| `EastGallery` | Lower Lamp Gallery | 126, 4, 20 | 88 × 72 | First carved gallery: lamp niches in the back wall (Elite) |
| `Crossing` | Netted Isle | −20, 8, −40 | 60 × 60 | A rounded rock island in the span pool, mycelium nets on stalks round it |
| `WestGallery` | Upper Lamp Gallery | −134, 12, −110 | 88 × 72 | Higher gallery: broken lamp-wheels, shelf fungi (Elite) |
| `Apex` | Lantern Vault | 40, 16, −180 | 104 × 76 | A vaulted chamber full of dead lamps and one living one |

**Links:** Sanctuary→Basin; Basin→EastGallery; Basin→Crossing (the shortcut); EastGallery→Apex (the long east climb); Crossing→WestGallery (**STAIRS**, the gallery steps); WestGallery→Apex. **Camps (22, 2 Elites):** the generic index-2 roster (Basin 4 + 4, Crossing 4, both galleries Elite). **Set pieces:** mycelium nets as cloth-like meshes strung between grounded posts; wall-cut lamp niches; a hanging-net waterfall of glowing threads (cosmetic); the first **spore-medusae** drifting in the vault. **The trail begins here:** the Lantern Vault's one living lamp is a Lampkeeper's, its flame warm orange among the dead violet bulbs, and a chalk gill-wheel on the rock beside it points up. (Built: the living lamp is the colossal lamp-post; still to add, a small change: warm-flame colour on it and the chalk sign.)

### Floor 8: Blooming Chasm (`TERRAIN_VARIATION`)

*Footprint 460 × 520 × 155, Y −4 to +18, chasm (`Bottom = −4`). The brightest floor: everything in bloom.*

**Story beat:** the cavern floor collapsed into a chasm, and the Veinweb bloomed in it. Giant mushrooms rise from the chasm floor like umbrellas; the tops of the biggest ones are wide enough to fight on. **This is where the Lampkeepers made their refuge.** They camped on the rim, lashed rope-and-plank walkways to the Veinweb's cables to reach the islets, and held the old aqueduct as their road north. The bloom drove them on. Their camps get colder the further in you go.

**Shape: an archipelago of caps and islets.** The whole middle is chasm (unlike Floor 3's single east–west gorge). The Velmari aqueduct in the middle is the hub, and it can only be reached from the islands.

| Role id | Name | Centre | Size | Character |
| --- | --- | --- | --- | --- |
| `Sanctuary` | Lampkeepers' Rest | 0, 8, 226 | 128 × 56 | Their last lit camp, now the Masters' safe ground |
| `Basin` | Rim of Blooms | 0, 0, 136 | 400 × 96 | South rim looking into the chasm |
| `WestGallery` | Violet Cap | −140, 8, −20 | 62 × 62 | **The walkable top of a colossal mushroom cap** (a cap-top deck; Elite) |
| `EastGallery` | Crystal Islet | 150, 4, −30 | 84 × 76 | Rock island bristling with teal spires (terrain; Elite) |
| `Crossing` | Old Aqueduct | 10, 12, −60 | 96 × 48 | A surviving Velmari aqueduct span (masonry deck; Elite) |
| `Apex` | Bloomcrown Ledge | 0, 20, −196 | 104 × 80 | North cliff ledge under a canopy of caps (terrain) |

**Links:** Sanctuary→Basin; Basin→WestGallery and Basin→EastGallery (the Lampkeepers' **rope walkways**: plank decks lashed to the Veinweb's cables, suspended over the chasm like Floor 3's root bridges); WestGallery→Crossing; EastGallery→Crossing; Crossing→Apex (**STAIRS**); EastGallery→Apex. Two return ramps from the chasm floor to the Basin. **Camps (25, 3 Elites):** generic index 3.

**Set pieces:** the Violet Cap's stem and gills below its walkable top (a solid stem down to the chasm floor, as Floor 3's Hollow Stump does); teal chasm pools and falls; glowing pad-caps; a sea of mid-size caps on the chasm floor below eye level.

**The Lampkeepers' structures (keep it to these four sites, and keep each one small):**

1. **Lampkeepers' Rest (the Sanctuary).** Their last lit camp: two **cap shelters** (lean-tos roofed with a cut section of cap, a bedroll inside) at the Sanctuary's back corners, and a ring-shaped **crystal brazier** with a warm flame. Clear of the four portals, the arrival point and the exit lane. One warm light. The safe zone *is* their camp, so arriving feels like reaching shelter.
2. **The forward camp on the Rim of Blooms**, at its west end beyond the west camp's reach (about X −175): a single shelter, a **supply cache** (bedrolls, sacks, a crate, a rope coil), a lamp pole and a cold fire-ring, looking out over the chasm toward the aqueduct. Unlit: they left it.
3. **The watch-post on the Old Aqueduct**: a low **barricade** of planks and scavenged slate lashed with cable across the aqueduct's north corner, a dead lamp hung from it, and a chalk sign pointing north to the ledge. It sits at a corner, at least 40 studs from the deck's centre and off both stair landings (the Elite camp is on the deck).
4. **The fallen camp on the chasm floor**, below the Crystal Islet near a return ramp: a shelter crushed under a toppled cap, its supplies spilled, its lamp still faintly lit. Only players who drop into the chasm find it, and the return ramp is right there. (A small reward for falling: it's dressing only, no loot.)

Plus **chalk signs** (a flat gill-wheel with one long ray, as a thin part or decal on rock) at the Rim's two walkway heads and at the foot of the aqueduct stairs, each pointing the way up.

**New kit (`fungal_f8_kit`):** `CapShelter` (lean-to of a cut cap on two poles, with a bedroll), `CampSupplies` (one cluster: bedrolls, sacks, a crate, a rope coil), `CrystalBrazier` (a slate ring holding crystals and a warm flame; `CANDLE` role for the flame), `Barricade` (planks and slate lashed with cable, about 14 studs wide), and `ChalkSign`. Everything else comes from the existing kits (`GiantMushroom`, `CrystalSpire`, `VelmariLampPost` with a dead or warm bulb, `MushroomCluster`, `PadCap`). Budget: at most **two** new lights on the floor (the Rest's brazier, the fallen camp's lamp).

### Floor 9: Rotcap Keep (`ELITE_STRONGHOLD`)

*Footprint 510 × 580 × 170, Y −4 to +22, chasm (`Bottom = −4`). The glow turns sickly: yellow-green rot under the violet.*

**Story beat:** the Velmari citadel, devoured from the inside. Rotcaps burst through the roofs, the stone crumbles, and the Chanters made the keep their temple. **This is where the Lampkeepers made their last stand.** They fell back into the keep and barricaded its gates; the Brutes broke the barricades, and the Chanters turned their camp into a shrine. The trail stops being a trail here: it becomes a battlefield the player walks through after the fact.

**Shape: an "H" with a high keystone.** You can't go straight up the middle. Both wings climb to rot-spires, and high spans from each spire meet at a central keystone above a rot pit, which then climbs to the keep.

| Role id | Name | Centre | Size | Character |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Broken Gate | 0, 8, 256 | 128 × 56 | The keep's outer gate, its barricade smashed open |
| `Basin` | Fallen Quarry | 0, 0, 160 | 440 × 110 | Quarry floor, toppled blocks, club-drag scars, a second broken barricade |
| `WestGallery` | Brewing Cellars | −156, 8, −12 | 92 × 80 | Roofless cellars, vats of glowing rot; the Lampkeepers' overrun camp, now a Chanter shrine |
| `EastGallery` | Ossuary of Caps | 160, 12, −20 | 92 × 80 | Velmari bones grown through with caps, Lampkeeper lamps among them |
| `WestBastion` | West Rot-Spire | −150, 16, −144 | 88 × 78 | A tower split by a rotcap (Elite) |
| `EastBastion` | East Rot-Spire | 150, 20, −136 | 88 × 78 | A leaning tower held up by mycelium (Elite); their lookout |
| `Crossing` | The Keystone | 0, 20, −124 | 76 × 62 | High masonry hub over the rot pit; their last barricade, broken |
| `Apex` | Keep of the Rotcap | 0, 24, −228 | 108 × 80 | Roofless keep, a giant rotcap as its ceiling |

**Links:** Sanctuary→Basin; Basin→WestGallery; Basin→EastGallery; WestGallery→WestBastion; EastGallery→EastBastion; WestBastion→Crossing and EastBastion→Crossing (the high spans); Crossing→Apex (**STAIRS**). Return ramps from the rot pit to the Basin. **Camps (35, 4 Elites):** generic index 4. Put Elite flags where the runtime needs them, and check the Elite count stays 4.

**The Lampkeepers' last stand (reuse the Floor 8 kit, broken):** smashed `Barricade`s at the Broken Gate, across the Fallen Quarry's north side and on the Keystone; their camp in the Brewing Cellars with its `CapShelter`s torn and a Chanter `CandleAltar` set up in the middle of it; their lamps (dead `VelmariLampPost` bulbs, the warm flames gone out) among the bones in the Ossuary; one chalk sign on the East Rot-Spire, the last one, pointing at the keep. **No warm light anywhere on this floor**: the absence is the point.

### Floor 10: Matriarch's Hollow (`BOSS_ARENA`)

*Footprint 560 × 640 × 190, Y −6 to +28. The heart: every vein converges here. Concept art: `reference/Fungal Hollow 10.webp` (mood, silk and lamp language, and the idea of a dais standing alone in the middle of the cavern; the layout below is original).*

**Story beat:** the Matriarch's nest. Her dais is a round mesa in the middle of the cavern under the largest oculus in the biome, ringed by a dark moat, and the Velmari's deepest galleries round the walls are now egg racks and spinning-rooms. **The end of the Lampkeepers' trail:** one of them got this far. Their lantern still burns at the arrival, the first warm light since Floor 8. On the dais their stolen lamps hang wrapped in silk round the rim: the Matriarch eats light, which is why they fled toward the oculus and why none of them reached it.

**Shape: a ring round a central dais, and it plays nothing like Floor 9.** Floor 9 is an "H" with the boss at the back. On Floor 10 the boss is in the middle, in plain sight from the arrival across the moat, and the whole floor is the walk round to the one way in:

- **The dais is in the middle and you can't get there.** From the Silk Shore the player looks north across the moat at the Matriarch's Dais, lit by the oculus, with four silk-shrouded spires standing in the water at its corners.
- **Walk the ring.** Rim paths climb from the shore to the lower ring (the West Egg Gallery and the Spinneret Ledge), wall stairs climb to the upper ring (the two cocoon arcades), and hung silk spans cross from the arcades to the **Brood Pillar**, a deck over the brood pool at the very back of the nest.
- **One way in, from the back.** The **Silk Stair** runs south from the Brood Pillar across the moat to the dais' north rim. It is the only link to the dais, so the fight always starts from the back, facing the heart and the boss portals on the south rim.

```
                          N (−Z)
        ┌──────────────────────────────────────────────┐
        │   [W COCOON]═span═( BROOD PILLAR )═span═[E COCOON]   upper ring Y16/20; pillar deck Y12
        │   [ ARCADE ]       ~~brood pool~~       [ ARCADE ]
        │      ‖ wall           ‖ Silk Stair          ‖ wall
        │      ‖ stairs  ▲  ~~~~‖~~~~~~~~~  ▲        ‖ stairs
        │   [W EGG   ]   ~~ ( MATRIARCH'S )  ~~   [SPINNERET]   lower ring Y8/12
        │   [ GALLERY]   ~~ (    DAIS     )  ~~   [ LEDGE   ]   dais Y28, round, oculus above
        │       ╲        ▲  ~~ moat  ~~~~~  ▲        ╱          ▲ = Shroud Spires in the moat
        │        ╲ rim path                rim path ╱
        │           ~~~~~~~ SILK SHORE  Y0 ~~~~~~~      │
        │                 [ THE LAST LAMP ]  Y8          │
        └──────────────────────────────────────────────┘
                          S (+Z)
```

| Role id | Name | Centre | Size | Character |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Last Lamp | generic | generic | One Lampkeeper shrine, its lantern still burning; a shelter and a floor rosette |
| `Basin` | Silk Shore | 0, 0, 196 | 480 × 100 | Silk curtains along the rim, chalk signs, looking across the moat at the dais |
| `WestGallery` | West Egg Gallery | −205, 8, −30 | 86 × 80 | Lower ring: egg racks against the cliff either side of a webbed arch, a cold Chanter altar (Elite) |
| `EastGallery` | Spinneret Ledge | 205, 12, −30 | 86 × 80 | Lower ring: silk windlasses, loom cables down into the moat (Elite) |
| `WestBastion` | West Cocoon Arcade | −160, 16, −215 | 86 × 80 | Upper ring: a silk spire, a curtain, an egg rack (Elite) |
| `EastBastion` | East Cocoon Arcade | 160, 20, −215 | 86 × 80 | Upper ring: as west, mirrored (Elite) |
| `Crossing` | Brood Pillar | 0, 12, −262 | 76 × 68 | A deck over the brood pool on a fungus-and-silk pillar; egg clutches, cocoon lamps and silk spools at the stair head |
| `Apex` | Matriarch's Dais | 0, 28, −60 | 140 × 110 | Terrain, rounded (`Shapes`, `Round 3`): the boss dais in the moat under the great oculus, stolen lamps round its rim, the Veinweb heart on the south rim between the portals |

All terrain terraces stand on 4-stud planes.

**Links:** Sanctuary→Basin (ramp); Basin→WestGallery and Basin→EastGallery (rim paths); WestGallery→WestBastion and EastGallery→EastBastion (**STAIRS**, the wall stairs); WestBastion→Crossing and EastBastion→Crossing (hung silk spans, `Bridges`); Crossing→Apex (the **Silk Stair**, hung over the moat). 8 links; the dais has exactly one.

**Camps (35 + Boss, 4 Elites):** generic index 5, and the Boss summon on the dais (95-stud leash). The dais must hold the leash and the `Spore Burst` (`SELF_DISC`) and `Corrosive Cloud` (`TARGET_DISC`) telegraphs without spilling onto the stair. Boss portals stand on the dais' south rim (`Portals = {Side = "SOUTH", Spread = 44}`), facing the shore. Patrols: `GALLERY_WEST`/`EAST` climb the wall stairs; `BASTION_RING` crosses the Brood Pillar between the arcades.

**Terrain:** direct; one great moat round the dais (`Pools`, centre 0, −46, radii 124 × 128, reaching well south of the dais so it reads from the shore) and the brood pool under the pillar with two side pools; `FloorDip` 6; no apex shelf behind the dais (`Terrain.NoApexShelf`), so it stands free; the great oculus (`Skylight`, radius 70) over the dais.

**Set pieces:** the earlier `fungal_f10_kit` (`WebbedArchway`, `SilkSpire`, `BroodEggClutch`, `StolenLampCocoon`, `SilkWindlass`, `LastLampShrine`, `SilkWebCurtain`) plus `fungal_f10_nest_kit` (`tools/blender/generate_fungal_f10_nest_kit.py`, adds the `SILK` colour role):

1. **Shroud Spires** (`ShroudSpire`, 36 × 62 studs, named apart from `SilkSpire`): four silk-wrapped spires standing in the moat at the dais' corners, the floor's landmark from the shore.
2. **Egg racks** (`EggRack`): frames of glowing egg-sacs against the West Egg Gallery's cliff and on the cocoon arcades' outer edges.
3. **Silk spools** (`SilkSpool`) in the Brood Pillar deck's back corners, and **cocoon lamps** (`CocoonLamp`) flanking the head of the Silk Stair on the dais.
4. **Silk drapes** (`SilkDrape`): modelled, not placed yet.
5. **The stolen lamps** (`StolenLampCocoon`): a ring round the dais rim, outside the telegraph discs and the stair's landing.
6. **The Veinweb heart**: an `ElderCap` growing straight out of the dais floor just in from the south rim, between the portals. Its roots climb out of a low mound of mossy slate and silk veins run from it across the dais. Never stand it on a plinth or shelf. Two `SilkSpire`s frame it.
7. **The Last Lamp** (the Sanctuary): the `LastLampShrine`, a warm `VelmariLampPost` and a `CapShelter`; the floor's only warm light.

**Lighting:** the brightest, clearest Fungal floor, the opposite of Floor 9's murk: pale silk-white air, cyan from the oculus, a magenta bounce off the moat (`HubLighting.FloorGrades[10]`).

---

## Part 3: Lighting per floor

Add `HubLighting.FloorGrades[6]` (and later 7–10), layered over the Fungal biome grade (`HubLighting.BiomeGrades`, the "deep blue cavern, glowing caps" entry). `HubLightingController.client.luau` already applies and blends floor grades. Add no new module and no new remote.

| Floor | Mood | Ambient / colour shift | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 6 | Underground twilight | Indigo ambient; cyan top, violet bottom | Moderate violet haze, dense low mist on the pool | Bloom up (about 0.5) for the gills; a soft cyan shaft through the oculus |
| 7 | Deeper and darker | Lower ambient; more violet | Hazier; drip mist | Lamp niches warm against the cold |
| 8 | Full bloom | Brightest Fungal floor; strong cyan | Mist rising from the chasm | Gills and crystals at their most saturated; the Lampkeepers' Rest is the one warm pool of light |
| 9 | Sickly rot | Yellow-green tint mixed into the violet | Thick, murky | Fewer glows, harsher contrast; no warm light at all |
| 10 | The heart | Violet-magenta, with cyan from the great oculus | Spore haze | A slow pulse from the heart; the last lamp's warm flame at the arrival |

Fungal Hollow has no sun or time of day. Keep `SunRays` low or off. The only "sunlight" is the oculus shaft. Lighting changes the mood, not the biome's identity.

---

## Part 4: Engineering

### 4.1 Generalise the authored-floor terrain data first (no visible change)

The Verdant branch hard-codes authored floors by key string in several places: `isDirectTerrain` / `isDirectTerrainLayout` (`"verdant:1" … "verdant:4"`), `DECK_PLATFORMS`, `SUSPENDED_PLATFORMS` and `SUSPENDED_LINKS` (duplicated in `TowerTerrain` and `TowerRoomBuilder`), the per-key `liquidLevel` and `floorDip`, the per-key pools in `natural()`, the per-key `band`, and a green-only `materialFor`. Adding five Fungal floors on top of that won't scale. Before authoring Floor 6:

1. Move this into the `AUTHORED` entry as data, for example:
   ```luau
   Terrain = {
   	Direct = true,                         -- walk on voxel terrain (invisible proxy slabs)
   	Decks = { Crossing = true },           -- built masonry platforms (solid parts, UNDER below)
   	Suspended = { ... }, SuspendedLinks = { ... },
   	LiquidRise = 2.6, FloorDip = 1.8,      -- liquid level above Bottom, pool bed depth
   	Pools = { { X = 0, Z = -30, RX = 70, RZ = 60 }, ... }, -- ellipses (and bands for rivers and moats)
   	WallBand = { Base = 34, Noise = 14 },
   	Surface = "FUNGAL",                    -- key into a surface palette (below)
   },
   ```
   Expose it on the built layout (for example `layout.Terrain`) and read it in `TowerTerrain` and `TowerRoomBuilder` from one place.
2. Replace the green-only branch of `materialFor` with a **surface palette** per biome: `Trail`, `Walk`, `WalkAccent`, `Bank`, `Cliff`, `Peak`, `PoolBed`. Verdant keeps exactly `Ground`, `Grass`, `LeafyGrass` and so on.
3. Move the Verdant floors onto the new data and **prove nothing changed**: add a spec that samples `TowerTerrain.Field` heights and kinds on a grid for `verdant:1..4` and compares them with a snapshot taken before the refactor, and keep `tower-layout-variants.spec.luau` green. Commit: `refactor(tower): data-drive authored floor terrain`.

### 4.2 Terrain materials are place-wide: claim free ones for Fungal

`Terrain:SetMaterialColor`, `WaterColor` and `Terrain.Decoration` apply to **every** floor in the server (`TowerTerrain.MaterialColors`, `applyColors`). Recolouring `Mud`, `Slate`, `Grass` or `LeafyGrass` would recolour the Verdant floors too. So:

- **Don't recolour any material another biome's palette uses.** Today no palette uses `Cobblestone`, `Pavement`, `Asphalt`, `Concrete`, `Brick` or `WoodPlanks`. Claim the ones you need for Fungal and give them Fungal colours: for example `Cobblestone` → violet cobble (trails), `Pavement` → indigo slate (walk surfaces), `Asphalt` → wet teal-black (pool beds and banks), and `Concrete` → pale lilac spore-moss. Add a comment that they're Fungal-owned, and a spec that fails if two biome palettes or surface palettes share a recoloured material.
- `Grass` decoration (3D blades) only grows on `Grass`, which stays green. Fungal gets its "grass" from **glowcap turf meshes** instead (§4.3), not from terrain decoration.
- `WaterColor` is already teal (`44, 138, 132`) on the Verdant branch. That matches "dark teal pools", so keep it and don't change it per floor.

### 4.3 Scenery, ground cover and the Blender kit

- **What players see is what supports them** (the same contract as the Verdant floors). The Glowpool Shore, the wings, the Apex and the earthen ramps are direct `Terrain` with invisible proxy slabs. Only built Velmari masonry (the Veinspan deck and the Mason's Stair on Floor 6) stays as solid, visible parts with recessed terrain beneath (`UNDER = 4.5` under decks, `2.8` under stair treads). Keep the `RES / 2` alignment, the `ownSurface` priority and the FBM-warped aprons exactly as Verdant does them.
- **Surface identity:** violet cobble down the path spines (`TRAIL`), indigo slate and spore-moss on the walk surfaces, wet teal-black at the pool banks, slate cliffs with mycelium veins. Lay flush Velmari slate stepping stones down the earthen ramps (as Verdant's `RampStepLip` does).
- **Glowcap turf (the biome's grass).** Scatter dense ground cover off the lanes: clusters of tiny caps with glowing undersides, spore-moss mounds and crystal shards. Keep it cheap: a few multi-cap meshes (one mesh holds 10–15 caps), placed many times, with no lights and `CastShadow = false`. Respect lanes, shoulders and camp clearance (`TowerPropClearance`). It must make the floor look alive at gameplay camera height, the way grass blades do on Verdant.
- **Assets to reuse** (check `TowerBiomeKit.Templates` and the Verdant `ExtraTemplates` first): `GiantMushroom` and `MushroomCluster` (secondary caps and the understory), `CrystalSpire` (teal spires), `ArchPierBase`, `ArchPierSegment` and `ArchCrown` (Velmari bridge arches), `CliffRockA`/`CliffRockB`, `ChasmIsland`, `BoulderCluster`, `RuinRubble`, `StoneUrn` and `Obelisk` (masonry clutter), and `RootBridgeArch` re-tinted as mycelium for later floors. Every kit template is recoloured by role (`CAP`, `GLOW`, `STEM`, `TRIM`, …), so re-tint through the roles rather than making new meshes. The enemy rigs in `assets-source/tower/enemies/` (`mob_spore_skitter`, `mob_lantern_spore`, `mob_sporecap_chanter`, `elite_mycelial_brute`, `boss_spore_matriarch`) show the Fungal shape language and colours to match.
- **New templates for Floor 6:** write `tools/blender/generate_fungal_f6_kit.py` following `generate_verdant_f2_kit.py` (load the helpers from `generate_tower_biome_kit.py` with `RUN_KIT = False`; 1 unit = 1 stud; stand on z = 0; front −Y; one mesh per colour role named `<Template>__<ROLE>`). Output `assets-source/tower/fungal_f6_kit/` (`FungalF6Kit.blend`, `.fbx`, `manifest.json`, `previews/`). Create only what the kit lacks:
  - `ElderCap`: colossal mushroom with a violet spotted dome, cyan gills (`GLOW`), hanging spore-bulb tendrils with glowing bulbs, and a root-foot.
  - `GlowcapTuft`: the ground-cover cluster of 10–15 tiny caps on a spore-moss mound. Make two or three variants.
  - `MyceliumVein`: a flat, branching vein network that lies against cliff faces and piers (`GLOW` + `STEM`).
  - `CandleAltar`: a stepped slate altar with candle clusters and a gill-wheel lantern.
  - `VelmariLampPost`: a slate post with a gill-wheel hood and a hanging glowing bulb.
  - `HangingRootFringe`: a ring segment of dangling roots for the oculus rim.
  - `EggSacCluster` and `PadCap` (a glowing cap floating on water), if native parts can't make them read well.

  Register each one in `TowerBiomeKit.ExtraTemplates` (and `CastsShadow` for the big ones), add it to `tests/studio-tower-biome-kit-import.luau` (`templateSpec`), and place it with `if KitProps.Has(name) then … else <native fallback> end`, so the floor looks right before and after the FBX import. Keep the triangle counts similar to the Verdant kits.
- Keep every existing scenery rule: **grounded clutter** (compound props are Models tagged `PropKind`, and hanging roots attach to the ceiling or oculus rim as a registered support), **clear walkways** (`TowerLayout.Lanes` + 3-stud shoulder), **camp clearance**, **chasm groves** (Fungal set: giant mushrooms and crystal spires), and **waterfalls facing away from ramps**.
- Water stays cosmetic: `Terrain` `Water` in recessed beds, never part of a lane, no swim state or hazard.

### 4.4 Budgets

- Before changing anything, measure Floor 6 as it is in Studio: part count, local lights and active particle emitters. Put the baseline in the PR description.
- Floor 6 stays within **+25% parts** of its baseline, **≤ 24 local lights** and **≤ 12 active emitters**, not counting client ambient life. Glow comes from Neon and the gills, not from `PointLight`s on every mushroom.
- Ground cover is the main risk: count turf instances and check frame rate at the lowest graphics setting.

### 4.5 Data and saves

Layouts aren't saved. There's no profile change and no `DataManager.SyncProfile` migration. If you find otherwise, stop and say so.

---

## Part 5: Process, tests and docs

### Phases and review gates

1. **Study.** Read everything in "Before you start" and summarise, in a few lines, what you'll reuse from the Verdant branch.
2. **Refactor** (§4.1–4.2) with no visible change to Verdant floors 1–4 or any other floor. Commit.
3. **Design gate for Floor 6.** Show the user the final coordinate table, an ASCII top-down map with links, camps and patrols, every link's rise and slope, the set-piece list with positions, the list of new Blender templates, and the material and lighting plan. **Stop and wait for sign-off.**
4. **Blender kit.** Generate `fungal_f6_kit`, render the contact sheet, and show it to the user before placing anything. Commit: `feat(tower): add Fungal Floor 6 Blender kit`.
5. **Build Floor 6.** Layout, terrain, masonry, set pieces, ground cover and `FloorGrades[6]`. Commit: `feat(tower): author Fungal floor 6 (Sporelit Entry) layout`.
6. **Docs and tests**, then **stop**. Floors 7–10 get their own sessions with this same brief, one floor each, and each starts with its own design gate.

### Tests

Run `pwsh tests/run.ps1` (never pass `-InstallLuau`). On a machine without `pwsh` or the Luau CLI, port the runner as the repo notes describe, and ask the user before downloading the CLI. Extend the specs so Floor 6 is covered:

- `tower-layout-variants.spec.luau`: Floor 6 is authored (`Key`, `Names`, `Paths`, `Stairs`); `Validate` returns no problems; there is no Basin→Crossing or Basin→Apex link; WestGallery→Apex stays clear of the Elder Cap island.
- `tower-rework.spec.luau` and `tower-navigation.spec.luau`: links ≤ 15°, stairs within the step limit, flush landings, Sanctuary → Apex routable, every camp reachable.
- Camp roster, patrols and portals: 16 mobs and 1 Elite, the arrival area clear, patrol points on platforms or links, portal spots on the Apex.
- The terrain snapshot spec from §4.1 (Verdant unchanged) and the shared-material spec from §4.2.
- Floors other than 6 produce the same layout as before.

Then, in Studio: run `tests/studio-tower-prop-audit.luau` on Floor 6 (orphaned, floating and on-walkway props must all be **0**), and run raycast and `Blockcast` shoulder checks along every Floor 6 link and the Sanctuary grid so nobody hits hidden ledges or floats over voxel dips.

### Docs (same PR)

- `docs/GAME_DESIGN.MD` §3.3: add Floor 6 under "Hand-authored floors" (shape, platforms, camps, set pieces, lighting) and mention the Velmari and the Veinweb. Document the data-driven `Terrain` block and the Fungal-owned terrain materials.
- `docs/TOWER_NAVIGATION.md`: the `Terrain` authored data (`Direct`, `Decks`, `Suspended`) replacing the per-key tables.
- `reference/infinite_towers_biomes.md` §2: a short paragraph on the Velmari lamp-masons and the Veinweb.
- Update this prompt's **Status** line.

### Finish with a Studio checklist for the user

Don't run the playtest yourself. End with a **How to test** checklist:

1. Import `FungalF6Kit.fbx` with `tests/studio-tower-biome-kit-import.luau`, then check that Floor 6 looks right both with and without the import (the fallbacks).
2. Arrive on Floor 6: you land out of aggro on terrain, the Apex is hidden behind the Elder Cap, and the skylight shaft is visible over it.
3. Walk both routes to the Apex (west Mycelium Ramp; east Warren → Mason's Stair → Veinspan). Check that nothing lets you cut across the pool.
4. Squad follow, recall (`E`) and assigned-squad routing on the stair, the bridge deck and the long ramp.
5. Patrols walk and leash; the Elite camp at the altar; summon and kill the Alpha on the dais; Ascend and Rerun portals.
6. Relic Rain lands on Floor 6 ramps (`workspace.TowerEventForce = "RELIC_RAIN"`).
7. Lighting blends into the Floor 6 grade and restores in the hub.
8. Verdant Floors 1–4 and Floors 7–50 look exactly as before (terrain colours included).
9. Frame rate at the lowest graphics setting, compared with the baseline.

## Out of scope

- Floors 8–10 (designed here, built later), and biomes 3–10.
- Any gameplay from the Lampkeepers' story: no quests, pickups, dialogue or text. It's told only through the set dressing.
- New enemies, boss mechanics, hazards, swimming, or reward, drop and stat changes.
- Server-side floating props of any kind; the spore-medusae are client ambient only.
