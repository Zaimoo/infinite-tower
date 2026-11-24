# Prompt: Sunken Sanctuary — a Unique Layout for Every Floor (Floors 36–40)

Copy everything below the line into a Claude Code session opened at the repo root, or follow it with the `biome-floor-redesign` skill (`.claude/skills/biome-floor-redesign/SKILL.md`), which is the procedure this plan plugs into.

> **Written 2026-11-22.** Six biomes are authored on `main`: Verdant Ruins (1–5), Fungal Hollow (6–10), Ashen Dunes (11–15), Frozen Citadel (16–20), Infernal Foundry (21–25) and Corrupted Grove (31–35). Thunder Highlands has Floor 26 built and Floors 27–30 planned (`docs/prompts/thunder-highlands-floor-layouts-prompt.md`). This brief builds on all seven prompts and treats the **built** Corrupted Grove floors as the bar to beat.
>
> **The escalation rule (from the Infernal plan, Part 2):** every floor is richer, taller and more varied than the one below it, and than every earlier floor at the same position in its biome. Sunken Sanctuary beats Corrupted Grove at each index on room area, room height, terraces, links, height levels and Apex height.
>
> **The compact-grand pacing rule (learned on Floor 25):** grow upward and inward. Depth stays capped at `795` studs. The scale goes into height, terrace count and density, not empty ground. A new corollary from this plan's validation: **keep the shortest walk to the Apex at or under about 2× the canonical layout.** Floor 40's first shape, a full maelstrom spiral, measured 3.5× and was replaced (§3.5).
>
> **The guide-image gate:** before building any floor, ask the user for that floor's guide image (skill step 2). The image sets mood, shapes and landmarks. Treat it as inspiration, never copy it 1:1, and keep the runtime rules below. Update the floor's section of this file with what you took from the image before you build. The biome-wide concept art is `reference/Sunken Sanctuary.png` (colossal trident statues, a gothic sea-cathedral with a glowing gate, a golden shell-crowned shrine at the head of a stair, broken arches with cascades, aqua rune-tablets, coral and kelp, mantas and fish shoals in shafts of light). It is the biome's palette and mood, not any one floor's guide.
>
> **The layout half is already proven:** every coordinate table in Part 3 was run through the real `TowerLayout` in Studio on 2026-11-22. The check confirmed that Studio's `build` → `PatrolRoutes` source was byte-identical to `main`, spliced the five entries into a throwaway clone of the module in `ServerStorage`, ran `Layout.Get`, `Layout.Validate`, `Layout.PatrolRoutes`, `Layout.PortalSpots` and `PatrolPath.LoopLength`, and then deleted the clone. Results: **zero** validation problems on all five floors, no build asserts, every link at or under `14.81°`, every terrain terrace on the 4-stud grid, every platform reachable from the Sanctuary, mob and Elite totals on contract (`16/22/25/35/35`, `1/2/3/4/4`), and every patrol under 240 s. Re-run that check after any coordinate change. The coordinates also live in Lua form in Part 3's tables. Copy them from there, not from memory.

---

## Role

You are a two-specialist team speaking as one. Say which role is speaking when it matters.

**Tidewright** is a senior level designer and gameplay engineer for *Infinite Towers: Become a Master!*, a Roblox squad-command action RPG. Tidewright owns topography, sightlines, combat space, pacing, navigation and the `TowerLayout` connector contract. They think in walkable surfaces, link slopes, landings, camp spacing, leash radii, and the route a squad of five takes from the Sanctuary to the Apex.

**Coralsmith** is a senior environment artist and world-builder. Coralsmith owns the Nereth ecosystem, the drowned temples, the coral and kelp, the bells, the Tidewall, materials, water, lighting and the Tidecall. They build from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the earlier biomes were built. Every prop has a reason to be in the sanctuary and reads clearly from the gameplay camera. Coralsmith makes every floor a visible step up from the one below it.

Neither of you breaks the runtime contracts described below.

## Before you start

1. `git fetch origin` and branch each floor from `origin/main` as `feat/sunken-sanctuary-floor-<N>`. Work in the main checkout, because Rojo syncs from there. Use conventional commits and **one PR per floor. Never stack PRs.** This repo keeps head branches after a merge, so a stacked PR merges into its parent branch and never reaches `main`.
2. Follow `CLAUDE.md`, `AGENTS.md` and the `biome-floor-redesign` skill. Use the `roblox-world-building`, `roblox-luau`, `roblox-studio-mcp`, `roblox-npc-ai` and `roblox-performance` skills.
3. Read `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, the authored floors) and §3.6 (lighting), `docs/TOWER_NAVIGATION.md` (including "Authored terrain walkways"), `reference/infinite_towers_biomes.md` §8 (Sunken Sanctuary) and `docs/tower-mob-remodel-plan.md` §8 (the Sunken Sanctuary enemy visuals and motif: verdigris bronze, coral growth and shell spirals; glow aqua).
4. Read the earlier floor prompts, newest first: Corrupted, Thunder, Infernal, Frozen, Ashen, Fungal, Verdant. Read their status notes and lessons, especially the Corrupted status log (kit clearance boxes, `OnTerrain` pinning, `wallFoot`). Then run `git log --oneline -- src/ServerScriptService/Core/Tower*.luau src/ReplicatedStorage/Shared/Config/TowerLayout.luau` and read the `fix(...)` commits.
5. Read the authored-floor code end to end:
   - `TowerLayout.luau`: `AUTHORED[31..35]` (the Fungal-style `Terrain = {...}` system this biome uses, including `Blight`, `Slope`, `Ridges`, `BridgeStyles` and `DeckLooks`), `build`, `Validate`, `PatrolRoutes`, `Lanes` and `PortalSpots`.
   - `TowerTerrain.luau`: `Palettes.sunken_sanctuary`, `Surfaces` (`HOLLIN`, `BLIGHT`), `MaterialColors`, `FungalMaterials`, `BlockyMaterials`, `Terrain.Shapes`, `Pools`, `Islands`, `Ridges`, `Bridges` and the `GroveScale` / `MeadowScale` / `GroundCover` paths.
   - `TowerRoomBuilder.luau`: decks, `RoundDecks`, `DeckThickness`, bridges and stairs, curbs, open-sky versus vaulted rooms (`isNatural`, about line 487; **`sunken_sanctuary` is not in it yet**, §5.1).
   - `TowerBiomeAssets.luau` and `TowerSetPieces/CorruptedFloor3x.luau`: `piece`, `group`, `kitAt`, `onTerrain`, `groundY`, `wallFoot`, `AirborneKinds`, and the current `sunken_sanctuary` branches (coral towers, marble columns, `BanyanTree`, `Obelisk`).
   - `TowerBiomeKit.luau` and `TowerKitProps.luau`: `ExtraTemplates`, `Biomes.sunken_sanctuary`, `Ecology.sunken_sanctuary`, `Has` and `Ready`.
   - `HubLighting.luau`: `BiomeGrades[8]` (aqua caustics) and `FloorGrades`.
   - `.claude/skills/biome-floor-redesign/references/studio-verify.luau`.

## The goal

The five Sunken Sanctuary floors (36–40) still use the seeded generic layout and the generic Sunken props (`CoralCluster` groves, `BanyanTree`, `Obelisk`, marble columns). Give each one its own hand-authored topography, built around one ecosystem, so each floor has a different shape, route and combat rhythm and reads differently from its neighbours. Every other floor stays byte-identical. The floor names are already fixed by the GDD (§3.3): **Drowned Steps, Coral Cloister, Tidal Channels, Pearlguard Vault, Leviathan's Basin**.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, ruin, bell and creature traces back to this ecosystem. If a prop doesn't fit it, cut it.

### The Nereth

The **Nereth** were tide-priests: an order who worshipped the ocean's power and built their sacred city on the seabed itself. (One line of continuity: the Hollin's blight-brook from Floor 31 runs down to this sea. Nereth pearl-divers once poled river barges up it to trade pearls for Hollin grafting wax, which sealed their bronze bell housings. One of those barges lies wrecked on Floor 36, a cider barrel stamped with the graft-knot still in its hold.)

They built in **pale limestone and white marble**, roofed in **verdigris bronze**, and dressed every surface with **shell-scalloped niches, mosaic floors of blue and gold tesserae, and tall lancet arches**, like the cathedral in the concept art. Their great works were colossal statues of tide-kings and tide-queens holding tridents, and bells: hundreds of bronze **Tidebells**, hung in every gate, arch and tower, rung to call the tide in and out. Their sigil is the **tide-spiral**: a nautilus spiral cupped in a breaking wave. It appears carved on keystones, cast on every bell's crown, inlaid in mosaic on landings, and on the Drowned Acolytes' shell staffs.

### The Stillwater Ward, the Leviathan and the Tidecall

The city stood on the seabed in air, inside the **Stillwater Ward**: a dome of held-back sea, sung steady by the Nereth cantors and anchored by the **Pearl of Stillwater**. The ocean's power that kept the dome standing was the **Tidal Leviathan** (`SERPENT`: a long eel-dragon with a frilled head, a bioluminescent stripe and bronze-temple debris fused to its back; `docs/tower-mob-remodel-plan.md` §8). It was the god's own breath, and every tide it circled the city, and the bells rang it in.

The last **High Cantor** wanted the ward to stand forever without the god's leave. He had the Pearlguard seal the Pearl in a vault (Floor 39) and rang the **Great Tidebell** to bind the Leviathan in its basin (Floor 40). The Leviathan rose. It tore the Great Tidebell's tower from the temple (the bronze debris on its back), the ward broke, and the city drowned. The ward survives only in pockets (the tower floors) and shrinks floor by floor. On Floor 36 the sea stands as a far wall on the horizon; by Floor 40 it has closed overhead into a dome of dark water with one eye of daylight above the dais.

**The Tidecall is the biome's through-line** (after the Heartroot, Veinweb, Ember Vein, Stillcold, Heartbeat, Tempest Squall and Rotpulse). On a shared server-time cycle (`workspace:GetServerTimeNow()`), a slow swell passes over the floor:
- aqua rune-light washes up the tide-spiral glyphs and rune tablets, then fades
- caustic light ripples brighten across the floor and walls
- kelp and banners sway the other way; bubbles rise from the vents
- a far bell tolls, and under it the Leviathan's long, low call plays spatially from the Tidewall

It is gentle on Floor 36 (a slow ~16 s swell with a clear bell) and builds to a heaving ~6 s surge on Floor 40, where every bell on the floor is cracked and the call comes from under the dais. It is **client-side and purely cosmetic** (§5.6).

### The Tidebells (the trail the player follows)

The player follows the bells up all five floors. The Nereth hung one in every gate along the pilgrim way. Where the bells still hang, the way is open.

| Floor | How far the drowning has gone | What the bells tell you |
| --- | --- | --- |
| 36 | The Steps: the city's sea-front, half in the surf at low tide | Clean bronze bells on the pilgrim stair's arches, ringing in the swell. The middle flight lies broken in the surf with its bell drowned beneath it. The Bell Stack's great bell still hangs. |
| 37 | The Cloister: where the cantors lived and sang the ward | Cloister bells in every arcade, green with verdigris, their ropes rotted. The Bell Tower behind the Chapter Isle is the one the cantors rang for vespers, now silent. |
| 38 | The Channels: the waterworks that moved the tide through the city | A bell on every lock gate, rung to open it. Bells hang only on gates that still open. The Tidebell Tower at the head of the flight tolls the swell. |
| 39 | The Vault: the Pearlguard's harbour fortress | The Pearlguard pulled the bells down and muffled them with wax and sailcloth so the Leviathan could not hear the city. Muffled bells are stacked as barricades in the gates and hung mute in the towers. |
| 40 | The Basin: the Leviathan's lair | The bells are everywhere and every one is cracked: on the wreck at the shore, in the reef, chained to the anchors. Behind the dais stands the stump of the Great Tidebell's tower. Its bell is on the Leviathan's back. |

### Living layers (use all of them on every floor, more of each the higher you go)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Coral & Glow** | Branching coral, brain coral, sea fans, glowing anemones, bioluminescent kelp tips, rune-light | The signature glow is **aqua to cyan** (hue 175°–195°) with pearl-white and soft gold accents. **Coral is pink-violet, white, aqua or ochre, never red or orange**: enemy telegraphs are `(255, 25, 55)` and `(255, 95, 40)` (`EntityRenderer`), and the reef must not camouflage them (§5.7). |
| **Drowned Masonry** | Limestone colonnades, lancet arches, broken stairs, mosaic floors, shell niches, rune tablets, collapsed domes | Weathered pale stone with barnacle crust and weed at the waterline. One limestone material family, one marble trim and one verdigris bronze. |
| **Bronze & Bells** | Tidebells, bell arches, bell cages, chains, verdigris domes, trident finials, bronze doors | Bronze is verdigris green-blue with worn gold on the raised edges, never shiny. |
| **Kelp & Seagrass** | Kelp forests along the walls, seagrass meadows, sea-lettuce on stone, hanging weed curtains | Kelp grows from the ground (`groundY`), never stands on a block, and sways on the Tidecall. Tall kelp stays off lanes and ≥ 18 studs clear above walk surfaces where it overhangs. |
| **Shell & Pearl** | Giant clams, scallop shells, nautilus shells, pearl beds, shell middens, oyster racks | Echo the relics (below) and the tide-spiral. |
| **Water** | The tide-flat surf (36), the garths (37), the locks (38), the harbour and moat (39), the maelstrom (40) | Terrain `Water`. The place-wide `Terrain.WaterColor` is already teal (`TowerTerrain` `applyColors`), so for the first time the water reads as itself. Never recolour it. Make depth read with pool beds (pale sand in the shallows, dark basalt in the deeps) and aqua underglow anchors. |
| **Remnant Air** | Dry stone, sun, gulls, the open sky of the ward | Floor 36 is half dry and bright. By Floor 40 there is only the eye of sky above the dais. |

### Food web (how the enemies fit, `MobCatalog` → `sunken_sanctuary`)

- **Tide Claw** (`CRUSTACEAN`, Regular: barnacled crab with asymmetric pincers and a coral-crusted shell; `CLAW`): scavenges the shallows. Put cracked shell middens, molted carapaces, rockpools and fish bones near their camps.
- **Drowned Acolyte** (`CASTER_BIPED`, Regular: amphibious priest with a fin hood, kelp-wrapped robe and shell staff; `PROJECTILE`): a Nereth novice who never left. Put offering bowls, kneeling stones, rune basins and drowned lamps at their camps.
- **Tide Cantor** (`CASTER_BIPED`, Support `MEND`: singer with a conch, frilled gills and a water-ring halo): still singing the ward. Put conch racks, lecterns of coral-crusted stone and choir benches where it stands.
- **Coral Warden / Alpha** (`ARMORED_BIPED`, Elite/Alpha: knight in branching coral armour with a nautilus shield and hook-glaive; the Alpha adds a pearl crown and gold-verdigris trim; `WEAPON_ARC` / `GROUND_AREA`): the Pearlguard. Put glaive racks, nautilus shields, guard posts and coral growth creeping from where each one has stood for centuries.
- **Tidal Leviathan** (`SERPENT`, Boss, Floor 40): the ocean's power itself. Its moves (GDD §5.1) are **Tidal Sweep** (`ARC`), **Maelstrom** (`SELF_DISC`) and **Geyser Strike** (`TARGET_DISC`).

The relic skins (`RelicConfig` → `SUNKEN`) are the **Drowned Pearl Geode**, the **Tidebound Urn**, the **Coral Abyss Core** and the **Heart of the Tidal Leviathan**. Echo them in barnacled stones split on pearls, coral-crusted temple urns with water still sloshing inside, deep-sea lights caged in living coral, and the scaled heart-pulse of the Tidecall.

### Ambient life (client-only, purely cosmetic)

Fish shoals and mantas gliding *in the Tidewall* (the far water wall) and later overhead, gulls over Floor 36 only, rising bubble columns from vents, drifting motes of plankton glow, caustic light on the floor, kelp sway, dripping water from arches, distant bells and the Tidecall. The higher the floor, the more of these run and the closer the water presses. Everything is pooled, culled by distance, scaled by the Graphics quality setting, and off or minimal at the lowest quality. Nothing replicates from the server.

---

## Part 2: The escalation ladder

### 2.1 Layout and scale (validated in Studio for the Part 3 coordinates)

| Floor | Room (W × D × H, Bottom) | Area (vs. Corrupted at this index) | Terraces | Links | Height levels | Apex Y | Max slope | Shortest walk (× canonical) | Corrupted as built (terraces / links / levels / Apex) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 36 | 570 × 600 × 210, 0 | 342,000 (> 313,200) | 12 | 16 | 11 | 32 | 14.69° | 588.0 (1.83×) | 11 / 13 / 10 / 28 |
| 37 | 640 × 690 × 235, 0 | 441,600 (> 396,800) | 14 | 17 | 13 | 40 | 14.81° | 716.8 (1.98×) | 13 / 15 / 12 / 36 |
| 38 | 700 × 740 × 265, −6 | 518,000 (> 489,600) | 16 | 19 | 15 | 48 | 14.81° | 727.0 (1.80×) | 15 / 17 / 14 / 44 |
| 39 | 780 × 795 × 290, −6 | 620,100 (> 596,250) | 17 | 20 | 16 | 56 | 14.81° | 886.1 (1.95×) | 16 / 19 / 15 / 52 |
| 40 | 860 × 795 × 330, −10 | 683,700 (> 643,950) | 19 | 23 | 18 | 64 | 14.79° | 966.8 (1.91×) | 18 / 21 / 17 / 60 |

- *Terraces* counts every platform, including `Sanctuary` and `ExtraPlatforms`.
- *Height levels* counts distinct walk heights among all platforms except `Sanctuary`. On every Sunken floor no two terraces share a height.
- *Shortest walk* is the Dijkstra distance from the Sanctuary centre to the Apex centre, summing centre → link end, the link's 3D length, and link end → centre, compared against the canonical layout for the same index measured the same way (the Corrupted plan's measure; Floor 35 is 671.4, 1.33×).
- Every walk here is longer than Corrupted's at the same index because every Sunken Apex is reached *around* water. Floor 37 was 2.30× before the Garth Causeway was added (§3.2). Don't push any floor past ~2.0×.

### 2.2 Assets and variety (targets your build must meet, measured by the set-piece census)

Corrupted as built is the floor of these numbers: Floor 32 placed 422 props, 354 ground cover and 37 distinct templates; the tallest landmarks were 113.6 / 130.5 / 153.5 / 187 / 252 studs.

| Floor | New kit templates | Distinct templates placed | Landmark set pieces | Placed props (excl. ground cover) | Ground cover and small clutter | Tallest landmark | Ambient systems |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 36 | ≥ 9 | ≥ 24 | ≥ 14 | ≥ 350 | ≥ 250 | ≥ 120 studs (the Bell Stack) | ≥ 6 |
| 37 | ≥ 10 | ≥ 30 | ≥ 16 | ≥ 440 | ≥ 360 | ≥ 140 (the Bell Tower) | ≥ 7 |
| 38 | ≥ 11 | ≥ 32 | ≥ 18 | ≥ 500 | ≥ 380 | ≥ 160 (the Sea-Gate) | ≥ 7 |
| 39 | ≥ 12 | ≥ 34 | ≥ 20 | ≥ 570 | ≥ 400 | ≥ 195 (the Pearl Vault dome) | ≥ 8 |
| 40 | ≥ 13 | ≥ 37 | ≥ 22, plus one colossal centrepiece | ≥ 660 | ≥ 450 | ≥ 265 (the Great Tidebell Tower) | ≥ 9 |

**Performance wins a conflict.** If a target and the frame-rate budget in §5.8 disagree, meet the budget and say so in the PR. Never pad a floor with filler to hit a count.

### 2.3 Variety and readability rules (judged in review)

- **No filler.** No single template makes up more than 12% of a floor's placed props (ground cover excluded). Coral is the easiest thing to over-scatter: count it.
- **Every terrace is a vignette:** at least 4 distinct prop kinds that say what the terrace was for (shell midden, votive pool, cloister walk, lockhouse, pearl market, chain tower, cantor's pulpit).
- **Every link is dressed at both ends:** bell arches, trident finials, shell-capped posts, bronze lamp-stands or kelp-wound pillars on the terrace, off the lane.
- **Three skyline layers on every floor:** *near* (props, coral and columns on the terraces); *mid* (landmark statues, towers, domes); *far* (**the Tidewall**: a curved wall of standing sea beyond the room with fish shoals and mantas in it, coming closer floor by floor until on Floor 40 it arches overhead into a dome with an eye of sky above the dais).
- **Every floor introduces at least one traversal feature and one landmark type that no earlier floor has.** Part 3 names them.
- **Grounded and readable:** density never hides camps, telegraphs, loot or the route.

---

## Part 3: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north. Y is the walkable top surface. Terrain terraces sit on multiples of 4. Any terrace at another height is a deck (`Terrain.Decks[id] = true`).

**Shapes already taken (35, don't repeat them):**
- **Verdant (1–5):** spine with glades; broken diagonal aqueduct; E–W gorge with three bridges; walled ring with wall-walks; spiral around a cenote.
- **Fungal (6–10):** horseshoe around a pool; switchback up a gallery wall; chasm with a round cap deck and hung bridges; bastion "H" through the Crossing; asymmetric radial spiderweb (dais in a moat, walk round to the one way in).
- **Ashen (11–15):** fork around a dune; single switchback; N–S ravine with two ledges and an arch; chokepoint gate and split fortress; route over a fallen giant.
- **Frozen (16–20):** lakeshore road versus floe chain; street lattice; inverted ravine (central spine); two routes in two climates; cathedral nave.
- **Infernal (21–25):** hub-and-spokes turntable; gantry Π with a stem; lava-lake fishbone causeway; three-strip sluice weave; hourglass pinch with side chambers.
- **Thunder (26 built, 27–30 planned):** braided contours round a headwall; concentric ringfort; sky-pinnacle archipelago; two-tier cliff fault with a viaduct; twin-wing caldera amphitheatre.
- **Corrupted (31–35):** meandering brook with four fords; up and over a ridge into a hidden hollow; hedge maze round a centred court; tree to tree up five elder trunks; up the backs of three converging roots.

**Where the Apex sits (the contrast rule):**

| Floor | Apex position | How you reach it | Dominant landform | Light |
| --- | --- | --- | --- | --- |
| 35 *(for reference)* | Back centre, the largest dais | Up the backs of three roots | Root ridges over a sap mire | Blight-eclipse crimson-violet |
| 36 | **Back-west, raised on a sea-stack** at the head of a broken stair | Climb the Pilgrim Stair until its middle flight is gone, then detour east over the Votive Pool or west over the wreck | A tide-flat strand with sandbars and a broken processional stair | Bright turquoise noon, sun caustics |
| 37 | **Centre-back, an isle in a flooded garth**, ringed by a cloister | Cross the south garth (or walk its cloister), then walk round the north cloister to a bridge onto the isle's west or east side | Two flooded garths ringed by arcades: a figure-eight | Warm gold-green afternoon through coral-grown arcades |
| 38 | **Back-west, the Sea-Gate at the head of a flight of locks** | Climb either bank of the lock flight, crossing the canal on gate bridges (the rungs) | A staircase of canal locks, water at five heights | Grey-teal storm tide, rain haze |
| 39 | **Back-east, hidden behind the inner sea-wall** | Through the one outer gate, along the outer ward, over the inner wall at one of its end towers, then across the inner ward | A harbour fortress of two staggered sea-walls | Deep blue twilight with pearl light |
| 40 | **Centre-back, a pillar dais in the eye of a maelstrom** | Climb one of two reef horns round the whirlpool to the chain anchors, then the Chain Stairs onto the dais from the west or east | A frozen maelstrom ringed by reef | Storm-eye: a dark sea-dome overhead, one shaft of daylight on the dais |

No two neighbours share an Apex position, an approach, a landform or a light (36 and 38 are both back-west, but they are not neighbours, and one is a sea-stack reached by a stair while the other is a gate at the head of a canal).

**Fixed on every floor:**
- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, `128 × 56`, and `Basin` stays centred on `X = 0`. Arrivals land out of aggro.
- `Apex` holds the Floor Alpha (36–39) or Biome Boss (40) summon and the Ascend/Rerun portals (`Layout.PortalSpots`, at the back of the Apex). Every Apex below is entered from the south, west or east, never the north. The portal spots measured in Studio are listed per floor.
- Mob totals and Elite counts stay **16 / 22 / 25 / 35 / 35** and **1 / 2 / 3 / 4 / 4**. Never add mobs for bigger rooms. `ExtraPlatforms` hold no camps.
- Floors 38–40 replace the generic patrols with authored routes (`ReplacePatrols = true`). `BASIN_LOOP` is always generated.

**Terrain system: use the Fungal one**, as Corrupted Grove did (`Terrain = { Direct = true, Surface = ..., Decks, DeckLooks, DeckThickness, RoundDecks, Shapes, Pools, Islands, Ridges, Bridges, BridgeStyles, LiquidRise, FloorDip, NoApexShelf, WallBand, GroveScale, MeadowScale, GroundCover, GroundCoverCount }`). A drowned city wants round, organic terraces, pools and hung walkways, and that system already does all three. Don't introduce a third system, and don't mix in the top-level `DirectTerrain` / `Suspended` / `Masonry` fields. Use `Shapes` (round or squircle) for every terrain terrace that isn't a built deck. New terrain features are listed in §5.3; each is an option on the Fungal system, not a new system.
- **Surface progression:** Floors 36–37 (the sea-front and cloister, still in sun) use a new `Surface = "NERETH"` (pale limestone flag trails over wet sand, sandstone patches, rock banks, limestone cliffs, basalt sea-stacks, pale sand pool beds, seagrass). **From Floor 38 onwards** use `Surface = "DEEPWARD"` (limestone trails over drowned grey rock, slate banks, basalt cliffs and dark basalt pool beds) so the ground darkens as the ward closes in. Both reuse existing place-wide material colours (§5.3).

---

### Floor 36: Drowned Steps (`sunken:1`, `INTRODUCTION`)

*570 × 600 × 210, `Bottom = 0`. Bright turquoise noon.*

**Guide image:** ask for it before building (skill step 2). Until then, build from this section and `reference/Sunken Sanctuary.png` (the golden shell-crowned shrine at the head of a stair, broken arches with cascades).

**Story beat:** the city's sea-front, where the pilgrims came ashore. The **Pilgrim Stair** climbed from the tide-flat to the **Bell Stack**, a limestone sea-stack crowned with a shrine and the first great bell. At low tide the stair stands out of the surf, but its middle flight broke when the ward failed and lies in the shallows, its bell drowned under the treads. The bells on the arches still ring in the swell. A Hollin river barge lies wrecked on the sandbar to the west.

**Shape: a broken processional stair over a tide-flat, with the Apex on a sea-stack in the back-west.** From the arrival you see the stair climb straight up from the **Stair Foot** to the **Pilgrims' Landing**, then nothing, then the **Bell Landing** high beyond the gap and the **Bell Stair** climbing to the Bell Stack. The middle flight is gone:
- **The east detour (quickest):** Stair Foot → **Votive Pool** (a flooded offering basin) → Bell Landing → the Bell Stair (`STAIRS`, +12) to the Apex.
- **The stair route:** Stair Foot → the **First Flight** (`STAIRS`, +8) to the Pilgrims' Landing, then down to the Votive Pool (east) or down to the **Hollin Barge** (west), because the next flight is broken.
- **The west route:** Shell Midden → Hollin Barge on the sandbar → **Cantors' Rock** → the Apex from the west.
- **The tidepool route (scenic):** Tidepool Steps → **Upper Pools** (Y 28, the highest point before the Apex) → down to the Bell Landing.

**New to the tower:** a stair route that is visibly broken, with the gap in plain view and two detours round it (one down to the surf and back up). Also new: the first floor whose water is the sea (tide-flat surf, sandbars and rockpools). New landmark type: a sea-stack shrine with a great bronze bell.

```
                                N (−Z)
   ┌────────────────────────────────────────────────────────┐
   │          [ THE BELL STACK ] Y32                         │
   │ [CANTORS'      ▲ (st) Bell Stair                        │
   │  ROCK] Y24     ║                                        │
   │    |   [BELL LANDING] Y20 ◄─────────── [UPPER POOLS] Y28 │
   │    |     ╳ the fallen flight  ▲                 |       │
   │    |     ╳ (no way across)    |                 |       │
   │ [HOLLIN BARGE] Y6 ◄─ [PILGRIMS' LANDING] Y16 ─► [VOTIVE POOL] Y10
   │    |                    ▲ (st) First Flight   /    \    │
   │ [SHELL MIDDEN] Y4   [STAIR FOOT] Y8 ─────────     [TIDEPOOL STEPS] Y12
   │        \  ≈ sandbar ≈     |       ≈ surf ≈        /     │
   │    ~~~~~~~~~~~~~~~~ THE TIDE-FLAT  Y0 ~~~~~~~~~~~~~~~    │
   │                           |                             │
   │                  [ PILGRIMS' GATE ] Y8                  │
   └────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | Pilgrims' Gate | 0, 8, 266 | 128 × 56 | deck (a bell arch over the arrival) |
| `Basin` | The Tide-Flat | 0, 0, 155 | 538 × 96 | terrain |
| `WestGallery` | Shell Midden | −170, 4, 40 | 84 × 72 | terrain (round) |
| `Wreck` (extra) | The Hollin Barge | −185, 6, −62 | 64 × 48 | deck (the barge's tilted deck, on the sandbar) |
| `Crossing` | Stair Foot | 30, 8, 30 | 76 × 60 | terrain (a flagged landing) |
| `Votive` (extra) | Votive Pool | 85, 10, −55 | 56 × 48 | deck (a flagged rim round a flooded offering basin) |
| `EastGallery` | Tidepool Steps | 195, 12, 45 | 84 × 72 | terrain (round, rockpools) |
| `PilgrimLanding` (extra) | Pilgrims' Landing | −30, 16, −52 | 64 × 52 | deck (the stair's first landing, on piers) |
| `BellLanding` (extra) | Bell Landing | 10, 20, −140 | 64 × 52 | terrain |
| `CantorRock` (extra) | Cantors' Rock | −222, 24, −196 | 56 × 48 | terrain (round) |
| `UpperPools` (extra) | Upper Pools | 150, 28, −150 | 72 × 60 | terrain (round) |
| `Apex` | The Bell Stack | −85, 32, −228 | 116 × 84 | terrain (round, sheer: the sea-stack) |

**Paths (16 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+4), `Basin→Crossing` (+8), `Basin→EastGallery` (+12), `Crossing→PilgrimLanding` (`STAIRS`: the First Flight, +8, 14.53°), `WestGallery→Wreck` (+2), `PilgrimLanding→Wreck` (−10), `Wreck→CantorRock` (+18), `CantorRock→Apex` (+8), `Crossing→Votive` (+2), `PilgrimLanding→Votive` (−6), `Votive→EastGallery` (+2), `EastGallery→UpperPools` (+16), `UpperPools→BellLanding` (−8), `Votive→BellLanding` (+10, 14.63°), `BellLanding→Apex` (`STAIRS`: the Bell Stair, +12, 14.69°).
*The broken flight:* there is **no** `PilgrimLanding→BellLanding` link. The gap between them (97 studs centre to centre) is the fallen flight: broken treads and a drowned bell in the surf below, the landing's far edge sheared off, no plank or rope across it (the "no fake bridges" rule). The links that cross open water (`WestGallery→Wreck`, `PilgrimLanding→Wreck`, `Crossing→Votive`, `Votive→BellLanding`) are `Terrain.Bridges` in a new `BridgeStyles = "CAUSEWAY"` style: a low flagged causeway on arched piers with weed at the waterline and a bell arch at one end.

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite: a Coral Warden on the Shell Midden, a Pearlguard who walked ashore), `EAST_GALLERY` 4. **Patrol:** `BASIN_LOOP` (100.6 s). **Portals:** Ascend `(−69, 32, −258)`, Rerun `(−101, 32, −258)`.

**Terrain:** `Surface = "NERETH"`. The tide-flat is broad, shallow `Pools` (`LiquidRise ≈ −1.2`, `FloorDip ≈ 5`) with low `Islands` sandbars rolling between the terraces, so the open ground reads as surf and wet sand, not a lake. The sandbar under the Hollin Barge is the largest island. The Bell Stack (Apex) is a round `Shapes` mesa with a **sheer** apron (§5.3: `Sheer = true`), so it reads as a sea-stack, not a hill. The Tidepool Steps and Upper Pools carry small rockpools in their off-lane halves. `NoApexShelf = true`. `GroveScale = 0`; the floor places its own coral and kelp.

**Landmarks (≥ 14):**
1. **The Bell Stack** (≥ 120 studs): a limestone sea-stack crowned with an open shrine of lancet arches and a golden shell canopy (the concept art's shrine), the first great Tidebell hanging in it.
2. **The Pilgrim Stair:** the First Flight with bell arches over its foot and top, the sheared Pilgrims' Landing, the fallen middle flight in the surf, and the Bell Stair climbing the stack. Seen whole from the arrival.
3. **The Hollin Barge:** a river barge wrecked on the sandbar, with a graft-knot cider barrel in its hold and Pale Band rags on the mast (the one thread back to Corrupted Grove).
4. **The Votive Pool:** a flooded offering basin with floating lamp bowls, bronze offering dishes and pilgrim tokens.
5. **The Shell Midden:** a heap of cracked shells and molted carapaces where the Tide Claws feed, with the Coral Warden's watch-post.
6. **The Tidepool Steps:** rock terraces of rockpools with anemones, starfish and crabs.
7. **The Upper Pools:** the highest rockpools, spilling down in small falls toward the Tidepool Steps.
8. **Cantors' Rock:** a rock in the surf with a ring of worn stone lecterns where cantors sang the tide in.
9. **Two colossal statues:** a tide-queen with a trident at the west edge and a tide-king at the east, half sunk to the knee in the surf, kelp in their crowns (the concept art's pair). Reuse `RobedStatueTrident`, scaled and retinted.
10. **Broken colonnades** along the shore, with arches standing in the surf.
11. **Rune tablets** glowing aqua along the stair (the Tidecall washes up them).
12. **The Pilgrims' Gate:** a bell arch over the arrival with the tide-spiral keystone.
13. **Sandbar life:** gulls, beached kelp, a pilgrim's lost sandal, oyster racks.
14. Far: the Tidewall on the horizon to the north, the sea standing like a cliff with fish shoals in it, and the cathedral spires of the city drowned beyond it.

**Kit candidates (≥ 9):** `BellStackShrine`, `GreatTidebell`, `BellArch`, `PilgrimStairFlight` (intact and broken variants), `HollinBarge`, `VotiveLampBowl`, `ShellMidden`, `RuneTablet`, `TidepoolRockCluster`, `KelpStand`, `SeagrassTuft`.

**Lighting grade (`FloorGrades[36]`):** bright turquoise noon: white-gold key, aqua bounce, strong caustics, the least hazy Sunken floor. `AtmosphereDensity ≈ 0.24`, `AtmosphereHaze ≈ 0.6`, `Saturation ≈ 0.18`, `Contrast ≈ 0.08`, `ColorShift_Top ≈ (210, 250, 255)`.

**Spec asserts:** key, name and `Size`. `Apex.X < 0` and `Apex.Z < −200` (back-west). `Crossing→PilgrimLanding` and `BellLanding→Apex` are `STAIRS`. **The broken-stair rule:** there is no link between `PilgrimLanding` and `BellLanding`, and the Apex is still reachable without one. 16 mobs and 1 Elite. Every terrain terrace on `Y % 4 == 0`. No `Validate` problems.

---

### Floor 37: Coral Cloister (`sunken:2`, `EXPANDED_ENCOUNTER`)

*640 × 690 × 235, `Bottom = 0`. Warm gold-green afternoon under coral arcades.*

**Guide image:** ask for it before building.

**Story beat:** the cantors' house, where the ward was sung. Two cloisters stand one behind the other: the **Lay Cloister** (south), where pilgrims and novices lived, and the **Cantors' Cloister** (north), where the cantors sang in the **Chapter House**, an isle in the middle of its flooded garth. The garths flooded when the ward failed. Coral has grown up the arcades so thickly that the arches are half stone and half reef. The Tide Cantors still sing in the walks.

**Shape: a figure-eight of two cloisters round two flooded garths, with the Apex on an isle in the north garth.** You arrive at the **Lay Court** facing the south garth:
- **Through or round the south garth:** cross the **Garth Causeway** straight over the water to **the Lavabo** (the Crossing: a fountain house at the waist where the two cloisters meet), or walk round by the **West Walk** or **East Walk** (the galleries, each with an Elite) to the Lavabo.
- **Round the north garth:** from the Lavabo you can see the **Chapter Isle** (the Apex) across the north garth, with **no way across**. Walk round by the **Cantors' Walk** (west) or the **Coral Walk** (east), then take the bridge onto the isle from its west or east side (`STAIRS`, +20 and +16).
- **Behind the isle:** the **Bell Tower** joins the two walks behind the isle and doesn't reach it. Spurs lead to the **Dorter**, **Frater**, **Choir Loft**, **Scriptorium** and **Sacristy**.

**New to the tower:** two linked rings, one you may cut across and one you must walk round, and arcade-covered walkways (cloister walks under arcades, ≥ 18 studs clear). New landmark type: a flooded cloister and a chapter-house isle.

```
                                 N (−Z)
   ┌────────────────────────────────────────────────────────┐
   │ [SACRISTY] Y28         [ BELL TOWER ] Y36                │
   │      |                /               \                 │
   │ [CHOIR] [CANTORS' WALK] ═(st)═► [CHAPTER ISLE] ◄═(st)═ [CORAL WALK] [SCRIPT-]
   │ [LOFT ]       Y20     ≈≈ north garth ≈≈  Y40       Y24   [ORIUM  ] Y30
   │   Y26            \     ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈         /                │
   │                   ───────── [ THE LAVABO ] Y16 ───────               │
   │ [THE DORTER] Y4         /         ║          \        [THE FRATER] Y10
   │        \    [WEST WALK] Y8  ≈ south garth ≈  [EAST WALK] Y12   /    │
   │                     \        (Garth Causeway)        /              │
   │       ~~~~~~~~~~~~~~~~~~~ LAY COURT  Y0 ~~~~~~~~~~~~~~~~~~~         │
   │                               |                                     │
   │                         [ LAY GATE ] Y8                             │
   └────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | Lay Gate | 0, 8, 311 | 128 × 56 | deck |
| `Basin` | Lay Court | 0, 0, 200 | 608 × 100 | terrain |
| `Dorter` (extra) | The Dorter | −250, 4, −40 | 56 × 48 | terrain |
| `WestGallery` | West Walk | −135, 8, 60 | 88 × 76 | terrain (an arcaded walk) |
| `Frater` (extra) | The Frater | 250, 10, −40 | 56 × 48 | deck (the refectory floor on its undercroft) |
| `EastGallery` | East Walk | 135, 12, 60 | 88 × 76 | terrain (an arcaded walk) |
| `Crossing` | The Lavabo | 0, 16, −50 | 84 × 64 | terrain (round: the fountain house) |
| `CantorsWalk` (extra) | Cantors' Walk | −150, 20, −185 | 80 × 64 | terrain |
| `CoralWalk` (extra) | Coral Walk | 150, 24, −185 | 80 × 64 | terrain |
| `ChoirLoft` (extra) | Choir Loft | −252, 26, −150 | 56 × 48 | deck (a gallery on corbels) |
| `Sacristy` (extra) | Sacristy | −255, 28, −300 | 56 × 44 | terrain |
| `Scriptorium` (extra) | Scriptorium | 252, 30, −150 | 56 × 48 | deck |
| `BellTower` (extra) | Bell Tower | 0, 36, −300 | 64 × 48 | terrain (the tower's terrace, behind the isle) |
| `Apex` | Chapter Isle | 0, 40, −185 | 120 × 88 | terrain (round, an isle in the north garth) |

**Paths (17 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→EastGallery` (+12), `Basin→Crossing` (the **Garth Causeway**, +16), `WestGallery→Crossing` (+8), `EastGallery→Crossing` (+4), `WestGallery→Dorter` (−4), `EastGallery→Frater` (−2), `Crossing→CantorsWalk` (+4), `Crossing→CoralWalk` (+8), `CantorsWalk→BellTower` (+16), `CoralWalk→BellTower` (+12), `CantorsWalk→Apex` (`STAIRS`: the West Isle Stair, +20, 14.81°), `CoralWalk→Apex` (`STAIRS`: the East Isle Stair, +16, 14.76°), `CantorsWalk→ChoirLoft` (+6), `CoralWalk→Scriptorium` (+6), `CantorsWalk→Sacristy` (+8).
*Garth crossings:* the Garth Causeway and both Isle Stairs are `Terrain.Bridges` over the garths (`BridgeStyles = "CAUSEWAY"` for the causeway; a new `"ARCADE"` style for the Isle Stairs: a stone stair-bridge under a run of coral-grown arches, ≥ 18 studs clear). The cloister walks are terrain links dressed with arcades along their **outer** edge only, so the gameplay camera sees in.

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4 (the Lavabo), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite). **Patrol:** `BASIN_LOOP` (112.9 s). **Portals:** Ascend `(16, 40, −217)`, Rerun `(−16, 40, −217)`.

**Terrain:** `Surface = "NERETH"`. Two garth `Pools`: the south garth between the Lay Court, both walks and the Lavabo (~210 × 150), and the north garth round the isle (~260 × 200, past the isle's apron). Use the new squircle option (§5.3: `Pools[i].Round`), because a cloister garth is a rounded square, not an oval. `LiquidRise ≈ 0.6` so the water sits just under the walk edges. The Chapter Isle is a round `Shapes` mesa with a **sheer** apron of coral rock (§5.3), and the Lavabo's north side is sheer too: only 59 studs separate their edges, so a normal 30–36-stud apron would close the water. **The north garth must read as impassable** from the Lavabo: open water at least 40 studs wide between them, with no stepping stones (the Infernal 24 lesson: no fake bridge between terraces that have no link). `GroveScale = 0`.

**Landmarks (≥ 16):**
1. **The Bell Tower** behind the isle (≥ 140 studs): a square limestone campanile with a verdigris spire and silent bells, framing the Chapter House from behind.
2. **The Chapter House** on the isle: an octagonal open chapter house with a ribbed vault half fallen, the cantors' stone stalls round its rim and a tide-spiral mosaic on the floor (the Alpha's lair; keep the floor clean).
3. **The Lavabo:** a round fountain house with a basin of shells where water still spills from bronze fish-head spouts.
4. **The arcades:** cloister arches along all four walks, coral grown up their columns and over their crowns (`CoralArcadeBay`, straight and corner variants).
5. **The Garth Causeway:** a flagged causeway across the south garth with a bell arch at each end.
6. **The Dorter:** cantors' cells with stone cots, kelp curtains and shell lamps.
7. **The Frater:** a long refectory table on its undercroft, set for a meal no one finished.
8. **The Choir Loft:** a gallery of stone choir benches with Tide Cantor conch racks.
9. **The Scriptorium:** stone desks with tide-charts carved in slate, drowned scrolls in jars.
10. **The Sacristy:** a vestment press and the bell-ropes coiled in bronze bins.
11. **The garths:** sea-fans and seagrass under clear water, a drowned sundial in each.
12. **The Isle Stairs:** stair-bridges under coral arches.
13. **Cantor statues** in the walk niches, each holding a conch.
14. **Verdigris bells** in every arcade, ropes rotted to stubs.
15. **Coral overgrowth** climbing the outer walls, thickest in the north.
16. Far: the Tidewall nearer now on three sides, mantas gliding in it; the drowned city's domes beyond the cloister roofs.

**Kit candidates (≥ 10):** `CoralArcadeBay` (straight, corner), `CampanileTower`, `ChapterHouseOctagon`, `LavaboFountain`, `CantorStall`, `ConchRack`, `RefectoryTable`, `ScriptoriumDesk`, `CantorNicheStatue`, `BrainCoralMound`, `SeaFanCluster`.

**Lighting grade (`FloorGrades[37]`):** warm gold-green afternoon: a low gold key through the arcades, green-aqua fill off the garths, soft shadows. `AtmosphereDensity ≈ 0.30`, `AtmosphereHaze ≈ 0.9`, `Saturation ≈ 0.12`, `Contrast ≈ 0.06`, `ColorShift_Top ≈ (255, 226, 165)`.

**Spec asserts:** key, name and `Size`. The Apex is entered by exactly two links, `CantorsWalk→Apex` and `CoralWalk→Apex`, both `STAIRS`, one from each side (`From.X < Apex.X` and `From.X > Apex.X`). There is no link between the Apex and the `Crossing` or the `BellTower`, and `BellTower.Z < Apex.Z` (behind it). `Basin→Crossing` exists (the causeway). 22 mobs and 2 Elites. No `Validate` problems.

---

### Floor 38: Tidal Channels (`sunken:3`, `TERRAIN_VARIATION`)

*700 × 740 × 265, `Bottom = −6` (the channel beds). Grey-teal storm tide.*

**Guide image:** ask for it before building.

**Story beat:** the waterworks. The Nereth moved the tide through the city on the Leviathan's breath, lifting it up a **flight of locks** to the **Sea-Gate**, where the ward met the open sea. Every lock gate had a bell, rung to open it. The gates that still open still have their bells. The **Tidebell Tower** at the head of the flight tolls the swell. Tide-mills, sluice houses and eel weirs line the side channels.

**Shape: a ladder up a flight of tide-locks to a gate in the back-west.** The canal climbs north up the middle of the room in five locks, each lock's water higher than the last. A bank runs up each side (the rails), and gate bridges cross the canal at the lock heads (the rungs):
- **The rails:** West Towpath → West Lockhouse → Upper West Lock; East Towpath → East Lockhouse → Upper East Lock.
- **The rungs:** the **Tail Gate** (Crossing) at the foot joins both towpaths; the **Middle Gate** bridges West Lockhouse ↔ East Lockhouse across lock 3; the **Head Gate** at the top joins both upper locks.
- **The Sea-Gate (Apex)** stands at the head of the flight, turned west: up the **Sea-Gate Stair** from the Head Gate (`STAIRS`, east entry) or straight up the **West Stair** from the Upper West Lock (`STAIRS`, +20, south entry).
- **The side channels:** the **Tide Mill** (an alternative way from the quay to the East Towpath), the **Sluice House**, the **Eel Weir**, the **Upper Pound** and the **Tidebell Tower** are spurs on the channels that feed the flight.

**New to the tower:** a ladder layout (two rails and three rungs) and water at five different heights in one chain (`Terrain.Locks`, §5.3). New landmark type: lock gates with working-looking bells and a tide-mill.

```
                                N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │ [ THE SEA-GATE ] Y48 ◄═(st)═ [HEAD GATE] Y36 ── [TIDEBELL TOWER] Y44
   │        ▲ (st)               /   ≈ lock 5 ≈ \       [UPPER POUND] Y34
   │ [UPPER WEST LOCK] Y28 ─────     ≈≈≈≈≈≈≈≈     [UPPER EAST LOCK] Y32 /
   │        |                       ≈ lock 4 ≈               |        │
   │ [WEST LOCKHOUSE] Y20 ═══ Middle Gate ═══ [EAST LOCKHOUSE] Y24 ── [EEL WEIR] Y26
   │ [SLUICE]   |                   ≈ lock 3 ≈               |        │
   │ [HOUSE ]─[WEST TOWPATH] Y12    ≈ lock 2 ≈    [EAST TOWPATH] Y16  │
   │   Y18            \             ≈ lock 1 ≈          /    \        │
   │                    ──────── [ TAIL GATE ] Y8 ──────    [TIDE MILL] Y4
   │                                  |                    /          │
   │      ~~~~~~~~~~~~~~~~~~ TAILWATER QUAY  Y0 ~~~~~~~~~~~~~~        │
   │                                  |                               │
   │                       [ LOCK-KEEPER'S STAIR ] Y8                 │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | Lock-keeper's Stair | 0, 8, 336 | 128 × 56 | deck |
| `Basin` | Tailwater Quay | 0, 0, 212 | 668 × 96 | terrain |
| `TideMill` (extra) | Tide Mill | 255, 4, 60 | 56 × 48 | deck (the mill floor over its race) |
| `Crossing` | Tail Gate | 0, 8, 95 | 88 × 64 | terrain (the bottom gate platform) |
| `WestGallery` | West Towpath | −130, 12, 10 | 88 × 76 | terrain |
| `EastGallery` | East Towpath | 130, 16, 0 | 88 × 76 | terrain |
| `SluiceHouse` (extra) | Sluice House | −255, 18, −20 | 56 × 48 | deck |
| `WestLockhouse` (extra) | West Lockhouse | −120, 20, −95 | 72 × 60 | terrain |
| `EastLockhouse` (extra) | East Lockhouse | 120, 24, −105 | 72 × 60 | terrain |
| `EelWeir` (extra) | Eel Weir | 255, 26, −120 | 56 × 48 | deck |
| `UpperWest` (extra) | Upper West Lock | −130, 28, −172 | 72 × 60 | terrain |
| `UpperEast` (extra) | Upper East Lock | 120, 32, −215 | 72 × 60 | terrain |
| `Pound` (extra) | Upper Pound | 265, 34, −250 | 56 × 48 | deck (a quay round a holding basin) |
| `HeadGate` (extra) | Head Gate | 0, 36, −300 | 72 × 56 | terrain (the top gate platform) |
| `BellTower` (extra) | Tidebell Tower | 170, 44, −310 | 56 × 48 | terrain |
| `Apex` | The Sea-Gate | −200, 48, −295 | 128 × 92 | terrain (round) |

**Paths (19 links):** `Sanctuary→Basin` (−8), `Basin→Crossing` (+8), `Crossing→WestGallery` (+4), `Crossing→EastGallery` (+8), `Basin→TideMill` (+4), `TideMill→EastGallery` (+12), `WestGallery→SluiceHouse` (+6), `WestGallery→WestLockhouse` (+8), `EastGallery→EastLockhouse` (+8), `WestLockhouse→EastLockhouse` (the **Middle Gate**, +4), `EastLockhouse→EelWeir` (+2), `WestLockhouse→UpperWest` (+8, 14.53°), `EastLockhouse→UpperEast` (+8), `UpperWest→HeadGate` (+8), `UpperEast→HeadGate` (+4), `UpperEast→Pound` (+2), `HeadGate→Apex` (`STAIRS`: the Sea-Gate Stair, +12), `UpperWest→Apex` (`STAIRS`: the West Stair, +20, 14.81°), `HeadGate→BellTower` (+8).
*Gate bridges:* every link that crosses the canal or a side channel is a `Terrain.Bridges` lock-gate bridge (a new `BridgeStyles = "LOCKGATE"`: a timber-and-bronze walkway on the closed mitre gates, a bell on a bracket at mid-span, the balance beams outside `UsableWidth`). Links that run **along** a bank are terrain ramps beside the lock walls. Two return ramps climb out of the channel beds onto the quay (built by the runtime at X ≈ ±259).

**Camps (25, 3 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite, at the Tail Gate), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (123.4 s), `TAIL_GATE` = `{WestGallery, Crossing, EastGallery}` (126.9 s), `WEST_FLIGHT` = `{WestGallery, WestLockhouse, UpperWest}` (74.0 s), `EAST_FLIGHT` = `{EastGallery, EastLockhouse, UpperEast}` (86.8 s), `HEAD_RUNG` = `{UpperWest, HeadGate, UpperEast}` (132.0 s). **Portals:** Ascend `(−184, 48, −329)`, Rerun `(−216, 48, −329)`.

**Terrain:** `Bottom = −6`, `Surface = "DEEPWARD"`. The flight is **`Terrain.Locks`** (new, §5.3): five rectangular chambers on the canal centreline (x ≈ −60..60), from the tail (z ≈ 60) to the head (z ≈ −270), each with its own water level (about −2, 4, 10, 16, 22), stepped lock walls between them and the mitre gates as kit. Side channels are ordinary `Pools` at the quay level. The banks are terrain ramps along the lock walls. Rain-slick pool beds and wet stone throughout. `GroveScale = 0`.

**Landmarks (≥ 18):**
1. **The Sea-Gate** (≥ 160 studs): a colossal bronze-and-limestone water gate standing open to the Tidewall, with two trident statues as its posts and the sea pressing at the frame. The Alpha's lair, with the portals inside it.
2. **The lock flight:** five chambers with stepped water, mitre gates, balance beams and bronze bells on every gate that opens.
3. **The Middle Gate:** the longest gate bridge, with the flight's biggest bell at mid-span.
4. **The Tidebell Tower:** a slender bell tower at the head of the flight, tolling the swell.
5. **The Tide Mill:** an undershot wheel turned by the ebb, with millstones and grain sacks rotted to weed.
6. **The Sluice House:** paddle gear, winding wheels and a sluice racing foam into a side channel.
7. **The Eel Weir:** wicker eel traps across a side channel, with drying racks.
8. **The Upper Pound:** a holding basin with moored drowned barges.
9. **The lockhouses:** keepers' houses with bronze winding gear and tide-boards.
10. **The Head Gate:** the top gate with the flight's control wheel and a tide-gauge column.
11. **The towpaths:** bollards, rope coils and the Tide Claws' wreck-picking middens.
12. **The Tail Gate:** the lowest gate, half broken, water pouring through a gap.
13. **Overflow falls** spilling down the lock walls (sculpted ribbons, not flat boxes).
14. **Rain:** a client rain-haze layer and rain rings on the water.
15. **Bell brackets** on every rung, and silent hooks on the gates that no longer open.
16. **Drowned barges** jammed in lock 2.
17. **Tide-gauge columns** with the tide-spiral marks.
18. Far: the Tidewall very near on the west, the Sea-Gate opening straight into it; storm light through the water.

**Kit candidates (≥ 11):** `LockChamberWall`, `MitreGatePair`, `BalanceBeam`, `SeaGateArch`, `TidebellTowerSlim`, `TideMillHouse`, `SluiceGear`, `EelTrapRack`, `MooredBarge`, `TideGaugeColumn`, `BollardRope`, `OverflowRibbon`.

**Lighting grade (`FloorGrades[38]`):** grey-teal storm tide: overcast, a flat cool key, rain haze, the water darker than the sky. `AtmosphereDensity ≈ 0.38`, `AtmosphereHaze ≈ 1.6`, `Saturation ≈ −0.05`, `Contrast ≈ 0.14`, `ColorShift_Top ≈ (175, 205, 210)`. The rune-light aqua is the only saturated colour, so the Tidecall reads strongly here.

**Spec asserts:** key, name and `Size` (`Bottom = −6`, 2 return ramps). `Apex.X < −150` and `Apex.Z < −250` (back-west). **The ladder rule:** the rungs `Crossing→WestGallery`, `Crossing→EastGallery`, `WestLockhouse→EastLockhouse`, `UpperWest→HeadGate` and `UpperEast→HeadGate` each join a west terrace to an east one, and along each rail the heights rise (`WestGallery < WestLockhouse < UpperWest`, `EastGallery < EastLockhouse < UpperEast`). `HeadGate→Apex` and `UpperWest→Apex` are `STAIRS`. 25 mobs and 3 Elites. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

### Floor 39: Pearlguard Vault (`sunken:4`, `ELITE_STRONGHOLD`)

*780 × 795 × 290, `Bottom = −6` (the harbour). Deep blue twilight with pearl light.*

**Guide image:** `reference/Sunken Sanctuary 39.jpg` (2026-11-24). Matches the plan's staggered two-wall harbour fortress closely, so the validated Part 3 coordinates stand as written. **Taken from it:** the monumental **verdigris-ribbed glass-and-limestone Pearl Vault dome** (≥ 195 studs tall) flanked by carved stone seahorse buttresses and golden pearl-lit arched glazing, opening onto a **colossal glowing open pearl-white scalloped clam** at its heart; the towering moss-draped **Inner Sea-Wall** with the sealed arched **Drowned Gate** (trident relief, flanking sea-serpent reliefs, teal trident banners) facing the Muster Yard and topped by a crenellated **Wall-Walk**; the western **Coral Gate Tower** wrapped in coral growth with a domed verdigris lantern crown and pennant, and the eastern **Tide Tower** crowned with a giant bronze armillary tide-sphere; the lower mossy **Outer Sea-Wall** fronting the harbour water with the arched **Sea Gate** (scallop-shell pediment over a raised bronze portcullis, flanking braziers and trident banners); **Divers' Wharf** on wet barnacled pilings with a bronze diving bell/helmet, coiled ropes and oyster baskets; **Pearl Market** with striped shell-awning stalls and oyster baskets; **Muster Yard** with weapon/glaive racks and muffled-bell barricades; **Oyster Pearl Beds** on timber racks over water; **Harbour Ward** with stone dockhouses, harbour jib crane and moored/beached Pearlguard galleys with scallop-emblem sails; and the towering carved **Tidewall** battlements with trident reliefs and misty white cascades behind the dome under deep blue-silver twilight lit by warm golden-pearl vault glow. **Left out or changed:** coral growths on the Coral Gate Tower and vaults use pink-violet, pale pearl-cream, ochre and aqua (never red-orange) so enemy telegraphs (`(255, 25, 55)` and `(255, 95, 40)`) stay unmistakable; the Pearl Vault dome sits in the back-east Apex `(230, 56, -300)` per the plan's coordinates (rather than dead centre) so the contrast rule holds and the entire Apex combat floor and Ascend/Rerun portals remain completely open inside the dome's wide arched rim; and crowd figures, drifting gulls and animated waterfalls wait for the client ambient pass (§5.6).

**Story beat:** the Pearlguard's harbour fortress, where the High Cantor had the Pearl of Stillwater sealed. Two staggered sea-walls guard the **Pearl Vault**: the outer wall has a single gate, the **Sea Gate**, and the inner wall can be crossed only by climbing its two end towers. The Pearlguard pulled down the city's bells and muffled them with wax and sailcloth so the Leviathan couldn't hear the city. The muffled bells are stacked as barricades in every gate. They are still on watch.

**Shape: a fortress of two staggered sea-walls, with the vault hidden in the back-east.** From the arrival you see only the outer wall and, over the inner wall, the vault's pearl-lit dome.
- **The outer ward:** the Harbour Strand reaches the outer wall's **one** gate, the Sea Gate (Crossing, east of centre). Inside, the outer ward runs west to the **Pearl Market** and east to the **Harbour Ward** (the galleries, Elites). The **Muster Yard** and **Pearl Beds** face the inner wall's sealed **Drowned Gate** in the middle, with no way through.
- **Over the inner wall:** climb the **Coral Gate Tower** at its west end (Elite, Y 32) or the **Tide Tower** at its east end (Elite, Y 36). The **Wall-Walk** joins the two towers along the top of the wall.
- **The inner ward:** from the Coral Gate Tower, down to the **Wardens' Hall**, up to the **Pearl Cistern**, along to the **Vault Stair** and up into the Pearl Vault from the west (`STAIRS`). From the Tide Tower, along the **East Rampart** into the vault from the south-west. A cross-link joins the Rampart to the Cistern.

**New to the tower:** the first Apex hidden behind a wall you must go *over*, not through; a wall-walk joining two Elite towers; and an outer gate placed off-centre so the route snakes. New landmark type: a domed treasury vault with a colossal clam.

```
                                 N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │ [SHELL CHAPEL] Y28              [RELIQUARY] Y52                    │
   │       |                              |                            │
   │ [WARDENS' HALL] Y24 ─ [PEARL CISTERN] Y40 ─ [VAULT STAIR] Y44 ═(st)═► [THE PEARL VAULT] Y56
   │       |                        \_________ [EAST RAMPART] Y48 ───► (back-east, hidden)
   │       |         (inner ward)                      |               │
   │ [CORAL GATE TOWER] Y32 ═════════ the Wall-Walk ═════════ [TIDE TOWER] Y36
   │  ▓▓▓▓▓▓▓▓▓▓▓▓ INNER SEA-WALL (sealed Drowned Gate) ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
   │       |          [MUSTER YARD] Y20 ── [PEARL BEDS] Y18      |      │
   │ [DIVERS'] [PEARL MARKET] Y12     (outer ward)     [HARBOUR WARD] Y16
   │ [WHARF Y4]        \______________ [SEA GATE] Y8 ________/         │
   │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ OUTER SEA-WALL ▓▓▓▓▓▓▓▓▓ ║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
   │       ~~~~~~~~~~~~~~~~~~ HARBOUR STRAND  Y0 ~~~~~~~~~~~~~~~~      │
   │                                |                                  │
   │                       [ BREAKWATER STEPS ] Y8                     │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | Breakwater Steps | 0, 8, 363.5 | 128 × 56 | deck |
| `Basin` | Harbour Strand | 0, 0, 230 | 748 × 104 | terrain |
| `DivingWharf` (extra) | Divers' Wharf | −300, 4, 60 | 56 × 48 | deck (a pier on piles) |
| `Crossing` | Sea Gate | 120, 8, 110 | 88 × 68 | terrain (the gatehouse court) |
| `WestGallery` | Pearl Market | −170, 12, 40 | 92 × 80 | terrain |
| `EastGallery` | Harbour Ward | 270, 16, −10 | 92 × 80 | terrain |
| `PearlBeds` (extra) | Pearl Beds | 100, 18, −30 | 60 × 52 | deck (oyster racks over a tank) |
| `MusterYard` (extra) | Muster Yard | −30, 20, −50 | 64 × 52 | terrain |
| `WardensHall` (extra) | Wardens' Hall | −170, 24, −215 | 76 × 64 | terrain |
| `ShellChapel` (extra) | Shell Chapel | −290, 28, −300 | 56 × 52 | terrain |
| `WestBastion` | Coral Gate Tower | −250, 32, −100 | 92 × 82 | terrain (the tower's wall-top court) |
| `EastBastion` | Tide Tower | 260, 36, −140 | 92 × 82 | terrain |
| `PearlCistern` (extra) | Pearl Cistern | −40, 40, −190 | 72 × 60 | terrain |
| `VaultStair` (extra) | Vault Stair | 60, 44, −290 | 72 × 52 | deck (the stair's landing on arches) |
| `Rampart` (extra) | East Rampart | 150, 48, −200 | 72 × 60 | terrain |
| `Reliquary` (extra) | Reliquary | 60, 52, −355 | 56 × 52 | terrain |
| `Apex` | The Pearl Vault | 230, 56, −300 | 144 × 104 | terrain (round) |

**Paths (20 links):** `Sanctuary→Basin` (−8), `Basin→Crossing` (+8), `Crossing→WestGallery` (+4), `Crossing→EastGallery` (+8), `WestGallery→DivingWharf` (−8), `WestGallery→MusterYard` (+8), `EastGallery→PearlBeds` (+2), `MusterYard→PearlBeds` (−2), `WestGallery→WestBastion` (+20, 14.81°), `EastGallery→EastBastion` (+20, 14.81°), `WestBastion→EastBastion` (the **Wall-Walk**, +4), `WestBastion→WardensHall` (−8), `WardensHall→ShellChapel` (+4), `WardensHall→PearlCistern` (+16, 14.76°), `PearlCistern→VaultStair` (+4), `VaultStair→Apex` (`STAIRS`: the Vault Stair, +12), `VaultStair→Reliquary` (+8), `EastBastion→Rampart` (+12), `Rampart→Apex` (+8), `Rampart→PearlCistern` (−8).
*Walls:* the two sea-walls are kit (`SeaWallSegment`, `SeaWallTower`), built along the terraces' edges and between them, outside every lane and landing. The Wall-Walk is a terrain ramp along the top of the inner wall, with crenellations outside `UsableWidth`. The climbs to both towers (`WestGallery→WestBastion`, `EastGallery→EastBastion`) are stairs cut into the wall's inner face. Two return ramps climb out of the harbour onto the strand (X ≈ ±289).

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite, the Coral Gate Tower at Y 32), `UPPER_EAST` 5 (Elite, the Tide Tower at Y 36).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (137.5 s), `OUTER_WARD` = `{WestGallery, Crossing, EastGallery}` (196.4 s), `WALL_WALK` = `{WestBastion, EastBastion}` (204.6 s), `WEST_CLIMB` = `{WestGallery, WestBastion, WardensHall}` (121.9 s), `EAST_CLIMB` = `{EastGallery, EastBastion, Rampart}` (103.9 s), `VAULT_RING` = `{PearlCistern, VaultStair, Apex, Rampart}` (176.8 s). **Portals:** Ascend `(246, 56, −340)`, Rerun `(214, 56, −340)`.

**Terrain:** `Bottom = −6`, `Surface = "DEEPWARD"`. The harbour is open water in front of the outer wall (`Pools`, `LiquidRise ≈ 1.0`) with the Divers' Wharf on piles. Inside the walls the ground is dry stone: the outer ward low and wide, the inner ward a raised plateau stepping up to the vault. The Pearl Cistern is a round `Shapes` terrace with a sunken (dry) cistern in its off-lane half. **Hide the vault:** the inner wall (kit) is tall enough that from the arrival camera only the dome shows above it (check this from the Sanctuary). `NoApexShelf = true`. `WallBand` keeps the cliff behind the vault low so the dome reads against the Tidewall.

**Landmarks (≥ 20):**
1. **The Pearl Vault** (≥ 195 studs with its dome): a domed limestone treasury with verdigris ribs, its great door torn open, and inside on the north half a **colossal open clam** where the Pearl of Stillwater lay, now empty and glowing pearl-white. The Alpha's lair. Keep the arena floor clean.
2. **The outer sea-wall** with the **Sea Gate**: a gatehouse with a bronze portcullis raised, muffled bells stacked as a barricade beside it.
3. **The inner sea-wall** with the sealed **Drowned Gate**, bricked up and flooded at its foot, facing the Muster Yard.
4. **The Coral Gate Tower** and **Tide Tower:** round wall towers grown over with coral, nautilus shields hung on their parapets.
5. **The Wall-Walk:** crenellations, glaive racks and hooded braziers (cold, aqua glass) along the inner wall.
6. **The Pearl Market:** stalls with shell awnings, pearl scales, baskets of oysters.
7. **The Harbour Ward:** bollards, cranes and a beached Pearlguard galley.
8. **The Pearl Beds:** oyster racks over a tank, glowing pearls in open shells (echo the *Drowned Pearl Geode* relic).
9. **The Divers' Wharf:** diving stones, weighted ropes, a bronze diving bell.
10. **The Muster Yard:** a drill court with armour stands and a wall of muffled bells.
11. **The Wardens' Hall:** the Pearlguard's long hall with a hearth of aqua flame and banners of the tide-spiral.
12. **The Shell Chapel:** a small chapel lined in shells, the Pearlguard's oath stone.
13. **The Pearl Cistern:** a dry cistern of coral-crusted urns (echo the *Tidebound Urn* relic).
14. **The Vault Stair:** a grand stair on arches with guardian statues of Coral Wardens.
15. **The East Rampart:** a high walk along the vault's south wall, with arrow loops.
16. **The Reliquary:** a deep-sea light caged in living coral on a plinth (echo the *Coral Abyss Core* relic).
17. **Muffled bells** everywhere: wrapped in sailcloth, sealed with wax, stacked in barricades.
18. **Harbour chains** across the water, and a sunken chain-boom.
19. **Pearl light** spilling from the vault's dome oculus.
20. Far: the Tidewall close on every side, darkening toward the top; the first sight of a vast shadow circling in it.

**Kit candidates (≥ 12):** `PearlVaultDome`, `ColossalClam`, `SeaWallSegment` (straight, corner, sealed gate), `SeaWallTower`, `PortcullisGatehouse`, `MuffledBellStack`, `OysterRack`, `DivingBell`, `PearlguardGalley`, `CoralWardenStatue`, `GlaiveRack`, `CoralCageReliquary`, `ShellAwningStall`.

**Lighting grade (`FloorGrades[39]`):** deep blue twilight: a low blue-violet sky, cool dim key, the pearl-white vault dome the brightest thing on the floor. `AtmosphereDensity ≈ 0.34`, `AtmosphereHaze ≈ 1.1`, `BloomIntensity ≈ 0.5`, `Saturation ≈ 0.08`, `ColorShift_Top ≈ (170, 190, 255)`. Check that the camps and telegraphs still read in the dark.

**Spec asserts:** key, name and `Size` (`Bottom = −6`, 2 return ramps). `Apex.X > 150` and `Apex.Z < −250` (back-east). **The outer-gate rule:** the Basin's only links are to the Sanctuary and the `Crossing`. **The inner-wall rule:** with `WestBastion` and `EastBastion` removed, the Apex is unreachable. `VaultStair→Apex` is `STAIRS`. `UPPER_WEST` and `UPPER_EAST` sit above Y 30. 35 mobs and 4 Elites. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

### Floor 40: Leviathan's Basin (`sunken:5`, `BOSS_ARENA`)

*860 × 795 × 330, `Bottom = −10` (the maelstrom bed, the deepest in the tower). Storm-eye under the sea.*

**Guide image:** ask for it before building.

**Story beat:** the Leviathan's lair, the inner basin of the Great Temple, where the High Cantor rang the Great Tidebell to bind the god. The Leviathan rose here and the ward broke. The water still turns in a vast frozen **maelstrom**. The **dais** stands on the old bell tower's foundation, a pillar of rock in the maelstrom's eye. The Pearlguard's binding chains still run from two **chain anchors** on the reef to the dais. Behind it rises the **stump of the Great Tidebell Tower**, torn off at the top. The ward has closed overhead into a dome of dark sea, with one eye of daylight above the dais.

**Shape: two reef horns climb round a maelstrom to chain bridges onto a pillar dais in its eye.** You arrive on the **Wrack Shore** and see the whole maelstrom in front of you, with the dais in its eye (`Apex`, Y 64, `196 × 144`, the largest Apex in the tower) and no way across the water:
- **The West Horn:** West Shoal → West Reef → **West Chain Tower** (Elite, Y 36) → **West Anchor** (Y 52) → the **West Chain Stair** (`STAIRS`, +12) onto the dais.
- **The East Horn:** East Shoal → East Reef → **East Chain Tower** (Elite, Y 38) → **East Anchor** (Y 56) → the **East Chain Stair** (`STAIRS`, +8).
- **The Tide Gate** (Crossing) at the front of the maelstrom joins both reefs. Its spur, the **Drowned Altar**, juts into the whirlpool where the High Cantor rang the bell: a dead end facing the dais.
- **The crests:** each Chain Tower also climbs to a crest at the room's edge (**West Crest**, **East Crest**) and round the back to its anchor by the **High Cantor's Pulpit** (west) or the **Pearl Reliquary** (east): a longer, higher way to the same anchor.

**New to the tower:** a boss dais standing *in* water, reached only by two chain bridges from the sides, with the arrival looking straight at it across a whirlpool; and the first dome of water overhead. New landmark type: the Great Tidebell Tower and a terrain maelstrom.

```
                                 N (−Z)
   ┌──────────────────────────────────────────────────────────────┐
   │ [HIGH CANTOR'S]      ▲▲ THE GREAT TIDEBELL TOWER ▲▲     [PEARL     ] │
   │ [PULPIT] Y44          (stump, behind the dais)         [RELIQUARY] Y42
   │ [WEST CREST] Y48  \                                 /  [EAST CREST] Y50
   │       |      [WEST ANCHOR] Y52 ═(st)═► [ LEVIATHAN'S ] ◄═(st)═ [EAST ANCHOR] Y56
   │       |          /                    [    DAIS     ]           \       │
   │ [WEST CHAIN TOWER] Y36  ≈≈≈≈≈≈≈≈≈≈≈≈  [ 196×144 Y64 ]  ≈≈  [EAST CHAIN TOWER] Y38
   │       |            ≈≈≈≈≈≈≈≈≈ the maelstrom ≈≈≈≈≈≈≈≈≈≈≈             |      │
   │ [WEST REEF] Y20         [DROWNED ALTAR] Y26 (spur)          [EAST REEF] Y22
   │ [KELP  ]  \   \__________        |        __________/   /   [BELL  ]   │
   │ [SHRINE] [WEST SHOAL] Y8    [ TIDE GATE ] Y12    [EAST SHOAL] Y10 [BARGE] │
   │   Y24            \                 |                 /             Y30   │
   │        ~~~~~~~~~~~~~~~~~~~ WRACK SHORE  Y0 ~~~~~~~~~~~~~~~~~~~          │
   │                                    |                                    │
   │                           [ THE LAST BELL ] Y8                          │
   └──────────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Last Bell | 0, 8, 363.5 | 128 × 56 | deck |
| `Basin` | Wrack Shore | 0, 0, 236 | 828 × 104 | terrain |
| `WestGallery` | West Shoal | −210, 8, 110 | 92 × 80 | terrain |
| `EastGallery` | East Shoal | 210, 10, 110 | 92 × 80 | deck (a reef-shelf deck of coral and timber) |
| `Crossing` | Tide Gate | 0, 12, 100 | 88 × 68 | terrain |
| `WestReef` (extra) | West Reef | −290, 20, 10 | 72 × 60 | terrain |
| `EastReef` (extra) | East Reef | 290, 22, 10 | 72 × 60 | deck |
| `KelpShrine` (extra) | Kelp Shrine | −370, 24, 70 | 56 × 48 | terrain |
| `DrownedAltar` (extra) | Drowned Altar | 0, 26, −10 | 64 × 52 | deck (a rock spur into the whirlpool) |
| `BellBarge` (extra) | Bell Barge | 370, 30, 70 | 56 × 48 | deck (a wrecked bell-barge) |
| `WestBastion` | West Chain Tower | −270, 36, −122 | 92 × 82 | terrain |
| `EastBastion` | East Chain Tower | 270, 38, −122 | 92 × 82 | deck |
| `PearlReliquary` (extra) | Pearl Reliquary | 230, 42, −320 | 60 × 52 | deck |
| `CantorPulpit` (extra) | High Cantor's Pulpit | −230, 44, −320 | 60 × 52 | terrain |
| `WestCrest` (extra) | West Crest | −350, 48, −240 | 56 × 52 | terrain |
| `EastCrest` (extra) | East Crest | 350, 50, −240 | 56 × 52 | deck |
| `WestAnchor` (extra) | West Anchor | −185, 52, −225 | 64 × 56 | terrain |
| `EastAnchor` (extra) | East Anchor | 185, 56, −225 | 64 × 56 | deck |
| `Apex` | Leviathan's Dais | 0, 64, −175 | 196 × 144 | terrain (round, sheer: the pillar in the eye) |

**Paths (23 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→Crossing` (+12), `Basin→EastGallery` (+10), `WestGallery→WestReef` (+12, 14.69°), `EastGallery→EastReef` (+12, 14.69°), `Crossing→WestReef` (+8), `Crossing→EastReef` (+10), `Crossing→DrownedAltar` (+14, 14.73°), `WestGallery→KelpShrine` (+16), `EastGallery→BellBarge` (+20), `WestReef→WestBastion` (+16), `EastReef→EastBastion` (+16), `WestBastion→WestAnchor` (+16, 14.76°), `EastBastion→EastAnchor` (+18, 14.79°), `WestBastion→WestCrest` (+12), `EastBastion→EastCrest` (+12), `WestCrest→CantorPulpit` (−4), `EastCrest→PearlReliquary` (−8), `CantorPulpit→WestAnchor` (+8), `PearlReliquary→EastAnchor` (+14, 14.73°), `WestAnchor→Apex` (`STAIRS`: the West Chain Stair, +12), `EastAnchor→Apex` (`STAIRS`: the East Chain Stair, +8).
*Chain bridges:* both Chain Stairs are `Terrain.Bridges` in a new `BridgeStyles = "CHAIN"`: a stone stair-bridge slung from the Pearlguard's binding chains, the chains running from bronze anchor bollards to rings set in the dais rim, outside `UsableWidth`, never overhanging the arena. The Tide Gate's links to both reefs and the Altar spur are `"CAUSEWAY"` bridges over the maelstrom's outer ring. Two return ramps climb out of the maelstrom bed onto the shore (X ≈ ±318).

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite, Y 36), `UPPER_EAST` 5 (Elite, Y 38). The **Tidal Leviathan** is summoned on the `196 × 144` dais. **Tidal Sweep** (`ARC`), **Maelstrom** (`SELF_DISC`) and **Geyser Strike** (`TARGET_DISC`) must stay on the dais and never spill onto a chain bridge. The serpent is long: check in playtest that its body and slither stay inside the dais and read against the floor. Keep the dais floor clean: a worn tide-spiral mosaic in dark limestone, ringed on the outer rim only by the chain rings and broken bell-tower footings.

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (151.6 s), `WEST_HORN` = `{WestGallery, WestReef, WestBastion, WestAnchor}` (160.3 s), `EAST_HORN` = `{EastGallery, EastReef, EastBastion, EastAnchor}` (160.4 s), `TIDE_GATE` = `{Crossing, DrownedAltar}` (44.7 s), `WEST_CREST` = `{WestBastion, WestCrest, CantorPulpit, WestAnchor}` (157.6 s), `EAST_CREST` = `{EastBastion, EastCrest, PearlReliquary, EastAnchor}` (158.2 s), `CHAIN_RING` = `{WestAnchor, Apex, EastAnchor}` (154.0 s). **Portals:** Ascend `(16, 64, −235)`, Rerun `(−16, 64, −235)`.

**Terrain:** `Bottom = −10`, `Surface = "DEEPWARD"`. The maelstrom is **`Terrain.Maelstrom`** (new, §5.3): a round basin about 230 studs in radius centred under the dais, carved deeper toward the eye, with low spiral ribs of rock in its bed so the whirlpool's turn reads in the terrain itself, filled to `LiquidRise ≈ 1.5`. The dais is a round `Shapes` pillar with a **sheer** apron rising from the eye. The reefs are rough coral-rock `Shapes` and `Islands` round the rim, thickening toward the back. The swirl itself (surface flow, foam spiral, the eye's spray) is a client-side cosmetic mesh that turns slowly and speeds up on the Tidecall. `NoApexShelf = true`. `WallBand` low at the back so the Great Tidebell Tower stands against the Tidewall.

**Landmarks (≥ 22, plus the colossal centrepiece):**
1. **The Great Tidebell Tower (colossal centrepiece, ≥ 265 studs):** the stump of the temple's bell tower behind the dais, a lancet-windowed limestone shaft torn off at the top, its bronze bell-frame twisted outward where the Leviathan ripped the bell away. It stands at the back wall and beyond. It **never overhangs the `196 × 144` arena** and stays clear of `Layout.PortalSpots`.
2. **The Sea-Dome:** the Tidewall closing overhead into a dome of dark water, with one round **eye of daylight** directly above the dais. A far-layer mesh, high above gameplay height, never between the camera and the arena.
3. **The maelstrom:** the spiral-ribbed whirlpool bed, foam spiral, spray at the eye, drowned debris turning in it.
4. **The two chain anchors:** colossal bronze bollards on the reef with the binding chains running to the dais, one chain snapped and trailing in the water.
5. **The Chain Stairs:** stair-bridges slung from the chains.
6. **The dais rim:** broken bell-tower footings and bronze chain rings on the outer edge only.
7. **The Drowned Altar:** the High Cantor's altar on a spur into the whirlpool, with his bell-hammer lying where he dropped it.
8. **The High Cantor's Pulpit:** a carved pulpit facing the dais, the cantor's robes fossilised in coral.
9. **The Pearl Reliquary:** the empty reliquary that was meant to hold the Pearl after the binding (echo the *Heart of the Tidal Leviathan* relic in a carved scaled heart on its door).
10. **The two Chain Towers:** round towers on the reef with winding drums for the chains.
11. **The Bell Barge:** a wrecked barge that carried the Great Tidebell to the temple, its empty cradle on deck.
12. **The Kelp Shrine:** a ring of standing stones in a kelp forest.
13. **The Tide Gate:** a ruined water gate at the maelstrom's mouth.
14. **The crests:** coral-crowned rock crests with Pearlguard lookouts, the last guards fused into the coral.
15. **Twin colossal statues** of the tide-king and tide-queen flanking the Tidebell Tower, both broken at the waist, their tridents fallen across the reef.
16. **Cracked bells** everywhere: on the shore, in the reef, chained to the anchors.
17. **Fused bronze debris** in the reef: pieces of the bell tower the Leviathan carried down.
18. **Kelp forests** along the walls rising toward the dome, swaying on the Tidecall.
19. **Bubble columns** rising from vents in the maelstrom bed.
20. **Rune rings** on the dais rim that flare aqua when the boss is summoned.
21. **The Last Bell** at the Sanctuary: a single uncracked bell on a post, the Nereth's last ringing bell.
22. **The Leviathan's shadow** circling in the Tidewall before the summon (client-only, far layer).

**Kit candidates (≥ 13):** `GreatTidebellTower` (stump, bell-frame), `SeaDomeShell`, `MaelstromSwirl` (client mesh), `ChainAnchorBollard`, `BindingChainRun`, `ChainTowerRound`, `DrownedAltar`, `CantorPulpit`, `ReliquaryShrine`, `BellBargeWreck`, `BrokenTideStatue` (king, queen), `CrackedBell`, `KelpForestTall`, `BubbleVent`.

**Lighting grade (`FloorGrades[40]`):** storm-eye under the sea: a dark blue-black sea-dome ambient, a single warm white-gold shaft of daylight on the dais, aqua rune-light round the rim and the maelstrom glowing faintly from below. `AtmosphereDensity ≈ 0.42`, `AtmosphereHaze ≈ 1.4`, `BloomIntensity ≈ 0.6`, `Contrast ≈ 0.12`, `Saturation ≈ 0.06`. The dais is lit by a soft neutral key so the Leviathan and every telegraph read. No red or orange anywhere on the floor.

**Spec asserts:** key, name and `Size` (`Bottom = −10`, 2 return ramps). The Apex is `196 × 144` at Y 64, is the highest terrace, and is entered by exactly two links (`WestAnchor`, `EastAnchor`), both `STAIRS`, one from each side. `DrownedAltar` has exactly one link (a dead end). No link from the `Crossing` or the `DrownedAltar` reaches the Apex. The Apex's landmark footprints stay off the arena and the portal lanes. 35 mobs, 4 Elites and the Boss camp. Authored patrols resolve and stay under 240 s. No `Validate` problems.

**Why not a spiral:** the first Floor 40 shape was a true maelstrom spiral (the route circling the dais 1¼ times). It measured 3.5× the canonical walk, too long a trek before a boss, so it became the two horns above, with the spiral kept in the terrain and the swirl.

---

## Part 4: Lighting per floor

Add `HubLighting.FloorGrades[36..40]`, each layered over `BiomeGrades[8]` (aqua caustics), as the earlier floors did. `ClockTime` is shared and never changes: show the mood through colour shift, ambient, atmosphere, tint, contrast, bloom and caustic decals. No two neighbouring floors may share a mood. Floor 35's blight eclipse is crimson-violet; Floor 36 must break cleanly from it into daylight.

| Floor | Mood | Key and ambient | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 36 | Bright turquoise noon | White-gold key, aqua bounce | Clear (`Density ~0.24`, `Haze ~0.6`) | Strong caustics; gulls; the Tidewall far off |
| 37 | Warm gold-green afternoon | Low gold key through arcades, green-aqua garth fill | `Density ~0.30`, `Haze ~0.9` | Dappled light through coral arches |
| 38 | Grey-teal storm tide | Flat cool overcast key | Thick rain haze (`Density ~0.38`, `Haze ~1.6`) | Rain rings; aqua rune-light the only saturated colour |
| 39 | Deep blue twilight | Cool dim blue-violet | `Density ~0.34`, `Haze ~1.1`, `Bloom ~0.5` | The vault dome's pearl-white light |
| 40 | Storm-eye under the sea | Dark sea-dome ambient, one warm shaft on the dais | `Density ~0.42`, `Haze ~1.4`, `Bloom ~0.6` | The eye of daylight; aqua rim runes; the maelstrom's glow |

Keep each floor at ≤ 24 lights. Effects are client-only, pooled and quality-scaled. Caustics are decals or texture-scrolled surfaces, faint on camp floors (§5.7).

---

## Part 5: Engineering

### 5.1 Room sizing and open sky

`TowerLayout` already supports `Size = { Width, Depth, Height, Bottom? }`, and every consumer reads the built layout's dimensions. **All five Sunken rooms are open-sky** (the ward's sky and the Tidewall), so add `sunken_sanctuary` to `TowerRoomBuilder`'s `isNatural` test (about line 487) with Floor 36's PR. Generic Sunken floors must not change: gate it to authored floors if the natural-room path changes anything for seeded layouts, and check that Floors 1–35 and 41–50 stay byte-identical. Floor 40's `Bottom = −10` is the deepest in the tower: check that terrain, return ramps (`AY = Bottom − 4 = −14`) and the room's floor slab all handle it. `HubLighting.TowerFloorAt` (2,400-stud grid) holds `860 × 795`.

### 5.2 Set pieces

Each floor gets its own module, `ServerScriptService/Core/TowerSetPieces/SunkenFloor<N>.luau`, mirroring `CorruptedFloor32..35.luau`, and exports its landmark footprints (`Floor<N>Landmarks`) for offline lane and camp checks. Use the shared helpers (`piece`, `group`, `kitAt`, `onTerrain`, `groundY`, `wallFoot`). Positions in a floor block are room-local: add `origin` when you set `.CFrame` yourself. Pieces that stand in water or hang (bells, chains, lamps on water, moored barges) must be pinned `OnTerrain` or listed in `AirborneKinds`, or the settle pass drops them (Floor 31 lesson).

### 5.3 Terrain, surface and materials

**Materials are place-wide.** Never use or recolour Fungal-owned materials (`Cobblestone`, `Concrete`, `Pavement`, `Asphalt`), never recolour shared `MaterialColors`, and never use `TowerTerrain.BlockyMaterials` (`Brick`, `WoodPlanks`): Roblox collides them as 4-stud steps. Never recolour the place-wide water.

Two new entries in `TowerTerrain.Surfaces`, using only uncoloured or already-coloured shared materials:
- `NERETH` (36–37): `Trail = Limestone` (pale temple flags), `Walk = Sand` (wet sea-sand), `WalkAccent = Sandstone`, `Bank = Rock`, `Cliff = Limestone`, `Peak = Basalt` (dark sea-stacks), `PoolBed = Sand` (turquoise water over pale sand), `Lush = LeafyGrass` (seagrass meadows).
- `DEEPWARD` (38–40): `Trail = Limestone`, `Walk = Rock`, `WalkAccent = Slate`, `Bank = Slate`, `Cliff = Basalt`, `Peak = Basalt`, `PoolBed = Basalt` (deep water over dark stone), `Lush = LeafyGrass`.

`Limestone` has no entry in `MaterialColors` and stays at its default colour. Add a spec that both surfaces avoid blocky and Fungal-owned materials. Mud stays out of these surfaces entirely: its rippled texture reads as water, and on a water biome that's confusing in both directions.

New terrain options, each on the Fungal system, each only where its floor needs it, each obeying every terrain rule (terraces on the 4-stud grid, never under `Bottom − 4`, FBM edges):
- **`Shapes[id].Sheer`** (36, 37, 40): a round terrace with a cliff apron of ≤ 8 studs instead of the usual 30–36-stud rock apron, so the Bell Stack and the dais pillar read as sea-stacks, not hills, and the Chapter Isle keeps open water round it.
- **`Pools[i].Round`** (37): a superellipse exponent for a pool, so the garths are rounded squares.
- **`Terrain.Locks`** (38): an ordered list of rectangular chambers (`X`, `Z`, `Width`, `Depth`, `Level`) with stepped walls between them, each filled to its own water level.
- **`Terrain.Maelstrom`** (40): a round basin (`X`, `Z`, `Radius`, `EyeDepth`, `Ribs`) carved deeper toward the centre with spiral ribs in its bed.
- **`BridgeStyles`:** `"CAUSEWAY"` (36, 37, 40), `"ARCADE"` (37), `"LOCKGATE"` (38) and `"CHAIN"` (40), each drawn outside `UsableWidth`.

Document each new option and bridge style in `docs/TOWER_NAVIGATION.md` in the floor's PR. A round shape's rock apron reaches about 30–36 studs past the shape (skill §3.3), so pools and moats round a round terrace must be bigger than they look on the map. `Sheer` exists partly to stop that apron from filling the garths and the maelstrom.

### 5.4 Kits: enough meshes for the ladder

1. Reuse first: `CoralCluster`, `RobedStatueTrident` and `RobedStatueStaff` (the colossal statues), `ArchPierBase`, `ArchPierSegment` and `ArchCrown` (aqueduct arches), `SolmereColonnadeWing`, `GothicPillarColonnade`, `CenoteColonnadeDome`, `CenoteCascadeSpillway`, `WaterfallRibbon`, `Waterwheel` and `MillWheel` (tide mill), `FieldstoneWeir` (eel weir), `GatehouseArch`, `CurtainWallRuins`, `VaultRibArch`, `DolmenBellGate`, `HangingLantern`, `StoneUrn`, `RuinRubble`, `BoulderCluster`, `GlowLilyCluster`, `ReedPondCluster`, `Obelisk` (rune pillars) and `SunkenWardenBoat`, retinted to the Sunken palette.
2. Generate each floor's new templates with `tools/blender/generate_sunken_f<N>_kit.py` → `assets-source/tower/sunken_f<N>_kit/` (FBX, .blend, `manifest.json`, previews). **Commit the generator.**
3. Register every template in `TowerBiomeKit.ExtraTemplates` only (Size, Min, Roles from the manifest). Names must be unique across all kits. Add only big architectural or natural pieces to `CastsShadow`.
4. **No new colour roles** unless a floor proves it needs one: `STONE` is limestone, `TRIM` marble and gold edges, `ALT` verdigris bronze, `WOOD` drowned timber, `MOSS` weed and seagrass, `FOLIAGE` kelp, `CAP`/`STEM` coral heads and stalks, `GLOW` rune-light and pearl, `CRYSTAL` sea-glass, `SILK` sailcloth and robes. Each floor passes a full tint table (in `TowerSetPieces/SunkenFloor<N>.luau`), so no template falls back to the biome palette.
5. Every template gets a part-built fallback in `TowerBiomeAssets` until it is imported (`TowerKitProps.Has(name)`). **Rebuild and recount after import:** a kit mesh's clearance box is the whole template per colour role, so big coral and kelp reach lanes that the fallback never did (Corrupted lesson 1).
6. **Uploading a kit creates permanent Roblox assets: ask the user before each upload.** On a yes: upload the FBX, insert it, run `tests/studio-tower-biome-kit-import.luau`, and ask the user to save the place.

### 5.5 Lessons from Floors 1–35 (each came from a real fix)

1. **Clearance removes a whole prop group if one part fails, silently.** Count every floor's set pieces after each build (`studio-verify.luau`). Fix a removed piece by moving or turning it, **never** by raising it on a plinth.
2. **Big kit meshes have big boxes.** The Great Tidebell Tower, the Pearl Vault dome, the colossal statues and the Sea-Dome are the riskiest pieces here: split them into parts and spec-check each footprint offline before Studio.
3. **Natural, not stacked.** Coral, kelp and statues grow from or stand on `groundY` with rock, weed and rubble at the foot. Never stand a statue or coral tree on a block. Use round `Shapes`, not square plinths.
4. **No fake bridges.** Where two terraces have no link (Floor 36's broken flight, Floor 37's Lavabo to the isle, Floor 39's Drowned Gate, Floor 40's shore to the dais), the gap must read as impassable.
5. **No flat semi-transparent boxes** for water, glow, foam, light shafts or the Tidewall. Use sculpted meshes, texture-scrolled surfaces, particles and invisible `PointLight` anchors.
6. **Never blocky materials** (`Brick`, `WoodPlanks`) on terrain.
7. **Check pitch signs** on leaning columns, fallen stairs, chains, kelp and overflow falls so nothing slopes upward or floats.
8. **Terrain terraces on multiples of 4.** Only decks sit at other heights.
9. **Overheads versus the camera:** arcades, arches, chain runs, kelp canopies and the Sea-Dome stay ≥ 18 studs clear over walk surfaces and never overhang the Floor 40 arena.
10. **Small clutter is non-collidable** (`CanCollide`, `CanQuery` and `CastShadow` all false), and grounding raycasts include `workspace.Terrain` with `IgnoreWater = true`. That matters more here than anywhere: half of every floor is water.
11. **≤ 24 lights per floor.** Count after every build.
12. **Perimeter props go at the foot of the walls, never on the cliff** (`wallFoot`, Floor 31): kelp forests and the Tidewall's base included.
13. **Explicit-height pieces must be pinned** `OnTerrain` or listed in `AirborneKinds` (Floor 31): bells, chains, moored barges and floating lamp bowls.

### 5.6 The Tidecall (client-only)

- One client module (`StarterPlayerScripts/Rendering/Tidecall.luau`) that runs **only** while the local player is on Floors 36–40.
- Synchronised from `workspace:GetServerTimeNow()`, so every player sees the same swell with zero remotes. The cycle tightens from about 16 s on Floor 36 to about 6 s on Floor 40.
- On each swell, acting on `CollectionService`-tagged parts and emitters with strict instance caps: wash aqua rune-light up tagged glyphs (Neon), brighten the caustic decals, sway kelp and banners, release bubble emitters, play one far bell toll and the Leviathan's call from the nearest point of the Tidewall, and add a small bloom nudge (`+0.05..0.1`, never a screen flash).
- **Zero gameplay effect.** At the lowest Graphics quality only the rune-light wash runs.

### 5.7 Telegraph readability

Enemy telegraphs are crimson `(255, 25, 55)` and orange `(255, 95, 40)`. The sanctuary's glow must never compete with them:
- Glows stay aqua to cyan (hue 175°–195°), pearl-white or soft gold. **No red or orange anywhere in a camp or on the Floor 40 dais**, including coral: real coral comes in reds and oranges, and the reef must not. Use pink-violet, white, aqua and ochre coral.
- Keep camp centres and the dais floor dark and uncluttered (flagstone, sand, mosaic). Caustic decals stay faint on camp floors so they don't wash out ground telegraph discs.
- Check that the Tide Cantor's `MEND` effect still reads against the aqua glow, and adjust the glow rather than the effect.
- In playtest, check that every telegraph reads at gameplay camera height: Tide Claw claws, Drowned Acolyte bolts, Coral Warden arcs and ground areas, and the Leviathan's Tidal Sweep, Maelstrom and Geyser Strike.

### 5.8 Performance

- **Instance, don't model.** Reuse MeshIds across terraces. Ground cover (seagrass, shells, small coral) uses multi-clump meshes with `CastShadow`, `CanCollide` and `CanQuery` off, tagged `TowerDetail` so the culler hides them past about 220 studs or at low quality. Landmarks are never culled.
- Lights ≤ 24 per floor. Particle emitters ≤ 12 on Floors 36–38 and ≤ 16 on Floors 39–40, all pooled and quality-scaled. The Tidewall, Sea-Dome and maelstrom swirl are single meshes with scrolling textures, not particle walls.
- Targets: ≥ 45 FPS in full camp fights on Floors 36–40 and ≥ 40 FPS in the Floor 40 boss fight at the lowest Graphics quality (MicroProfiler). Report the numbers in each PR.

### 5.9 Data and saves

Layouts are not persisted. No profile schema change and no `DataManager.SyncProfile` migration.

---

## Part 6: Process, tests and docs

### Per floor (lowest first, one PR each)

1. **Ask for the floor's guide image** (skill step 2) and update that floor's section here with what you take from it and what you leave out.
2. Branch `feat/sunken-sanctuary-floor-<N>` from `origin/main`.
3. Layout (`AUTHORED[N]`, the Part 3 table). Re-run the Studio validation probe from the header after any change.
4. Kit (reuse, then Blender), set pieces, terrain and lighting grade.
5. Tests and docs (below). Run the suites.
6. Studio verification (`studio-verify.luau`): probe build `Builder.Build(N, ...)`. The pass bar: no new `Validate` problems; every spawn and portal grounded; every link walkable both ways; every set piece present; ≤ 24 lights. Take screenshots from the arrival, from the Apex and of each landmark, compare them with the guide image and the neighbouring floors, and show the user. Then clean up the probe terrain, `workspace.TowerRooms` and the probe folders. Never use `ChangeHistoryService:Undo` to revert.
7. `git fetch origin`, merge `origin/main` (use `git merge-file --diff3 --diff-algorithm=histogram` on conflicts, then check every junction where two floors' tables meet), commit `feat(tower): author Sunken Sanctuary floor N (<Name>)`, and open the PR into `main`.

Thunder Highlands Floors 27–30 may land at the same time and touch the same shared code (`AUTHORED`, `TowerTerrain.Surfaces`, `TowerRoomBuilder`'s natural-room list, `TowerBiomeKit`, `HubLighting.FloorGrades`). Merge `origin/main` often.

### Tests

```bash
pwsh tests/run.ps1
```

(On a Mac without `pwsh` or the Luau CLI, port the runner as described in the project memory, and ask before downloading the CLI.) Extend:
- `tower-layout-variants.spec.luau`: for each floor, a "Floor N is the hand-authored ..." test (key, name, `Size`, links and kinds, the camp count, and the floor's defining rule from its **Spec asserts** above) and a "Floor N's terrain is the walking surface" test. Add the ladder test: across 36–40, room area, room height, terraces, links, height levels and Apex Y strictly increase, every floor beats Floors 1–35 at its index, and no terrain terrace is off the 4-stud grid.
- `tower-patrols.spec.luau`: Floors 38–40's authored patrols resolve, stay on walkways and loop in under 240 s.
- `tower-portals.spec.luau`: the portal spots are grounded on every Apex, and no landmark footprint covers them.
- `tower-biome-kit.spec.luau`: every new template exists, stands on its origin and uses known roles. `FloorGrades[36..40]` exist. `NERETH` and `DEEPWARD` use no `BlockyMaterials` and no Fungal-owned materials.
- Regression: Floors 1–35 and 41–50 unchanged.

### Docs (same PR as each floor)

- `docs/GAME_DESIGN.MD` §3.3: the floor's bullet under hand-authored floors. With Floor 36, also add a short paragraph on the Nereth, the Stillwater Ward, the Tidecall and the Tidebells.
- This file: the floor's status line, plus anything that changed in the build.
- `docs/TOWER_NAVIGATION.md`: any new terrain option or bridge style (`Sheer`, `Pools[i].Round`, `Locks`, `Maelstrom`, `CAUSEWAY`, `ARCADE`, `LOCKGATE`, `CHAIN`).
- `reference/infinite_towers_biomes.md` §8: with Floor 36, a short paragraph on the Nereth, the tide-spiral and the Tidecall.

### Studio checklist for the user (end of each floor's PR)

1. Arrive out of aggro on the Basin. Walk every route to the Apex: no invisible gaps, no blocky steps, nothing floating, nothing on a walkway.
2. **Floor 36:** see the whole Pilgrim Stair from the arrival, gap included. Confirm the broken flight can't be crossed, and take both detours round it.
3. **Floor 37:** cross the Garth Causeway and walk both south walks. Confirm the Chapter Isle can't be reached from the Lavabo, and walk round the north cloister to both Isle Stairs.
4. **Floor 38:** climb both banks of the lock flight, cross all three rungs, and see the water step up lock by lock. Climb out of the channel beds by both return ramps.
5. **Floor 39:** confirm only the vault's dome shows from the arrival. Take the Sea Gate, climb both towers, walk the Wall-Walk, and reach the vault both ways.
6. **Floor 40:** walk both horns to the dais. Summon the **Tidal Leviathan** and check that Tidal Sweep, Maelstrom and Geyser Strike stay on the dais and read clearly, that the serpent's body stays on the dais, that the Great Tidebell Tower and the Sea-Dome never cover the camera in the fight, and that Ascend (to Floor 41) and Rerun rise clear.
7. Telegraphs read against the aqua glows and the caustics on every floor.
8. The Tidecall matches across clients, builds from Floor 36 to 40, never flashes, and stops on leaving the biome.
9. Squad follow and recall (`E`) work across every causeway, arcade stair, lock-gate bridge, wall stair and chain stair.
10. Frame rate at the lowest Graphics quality: ≥ 45 FPS in camp fights and ≥ 40 FPS in the Leviathan fight.

## Out of scope

- Other biomes (Floors 1–35 and 41–50 stay unchanged).
- New enemies, boss moves, extra mobs for bigger rooms, swimming, drowning or water hazards that deal damage (all water here is cosmetic or a barrier), and weather or Tidecall effects on combat.
- Changes to rewards, relic drops, mob stats, camp respawn timing or the tower difficulty curve.

## Status

- 2026-11-22: plan written and the Part 3 layouts validated in Studio (0 `Validate` problems on all five floors; walks 1.83× / 1.98× / 1.80× / 1.95× / 1.91×; every patrol under 240 s).
- 2026-11-24: Floor 39 (*Pearlguard Vault*, `sunken:4`) authored on `feat/sunken-sanctuary-floor-39` with 15 sculpted Blender kit templates (`SunkenF39Kit.fbx`, including the 218-stud `PearlVaultDome`), `Surfaces.DEEPWARD`, `PathStyle = "DEEPWARD"`, `BridgeStyles = "WALLWALK"`, `FloorGrades[39]`, 26 spec-checked landmark footprints (`TowerSetPieces/SunkenFloor39.luau`), and specs (awaiting FBX import & Studio verification).
