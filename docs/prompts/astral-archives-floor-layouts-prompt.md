# Prompt: Astral Archives — a Unique Layout for Every Floor (Floors 41–45)

Copy everything below the line into a Claude Code session opened at the repo root, or follow it with the `biome-floor-redesign` skill (`.claude/skills/biome-floor-redesign/SKILL.md`), which is the procedure this plan plugs into.

> **Written 2026-11-23.** Six biomes are authored on `main`: Verdant Ruins (1–5), Fungal Hollow (6–10), Ashen Dunes (11–15), Frozen Citadel (16–20), Infernal Foundry (21–25) and Corrupted Grove (31–35). Thunder Highlands has Floor 26 on `main` and Floors 27–30 planned. Sunken Sanctuary has Floors 36 and 37 built on their own branches (`feat/sunken-sanctuary-floor-36`, `-37`, not yet merged) and Floors 38–40 planned (`docs/prompts/sunken-sanctuary-floor-layouts-prompt.md`). This brief builds on all eight prompts and treats the **Sunken plan's numbers** as the bar to beat.
>
> **The escalation rule (from the Infernal plan, Part 2):** every floor is richer, taller and more varied than the one below it, and than every earlier floor at the same position in its biome. Astral Archives beats the Sunken plan at each index on room area, room height, terraces, links, height levels and Apex height.
>
> **The compact-grand pacing rule (Floor 25, sharpened by the Sunken plan):** grow upward and inward. Depth stays capped at `795` studs. Keep the shortest walk to the Apex **at or under about 2× the canonical layout**. That cap shaped every floor below: four first ideas (a full orrery loop on Floor 42, a wall-to-wall zig-zag across the rifts on Floor 43, and a wall-to-wall slalom or a front-half Apex on Floor 44) came out at an estimated 2.5–2.9× and were pulled in (§3.6).
>
> **The guide-image gate:** before building any floor, ask the user for that floor's guide image (skill step 2). The image sets mood, shapes and landmarks. Treat it as inspiration, never copy it 1:1, and keep the runtime rules below. Update the floor's section of this file with what you took from the image before you build. There is no biome-wide concept art yet; if the user has one, save it as `reference/Astral Archives.<ext>` and record what it sets here.
>
> **The layout half is already proven:** every coordinate table in Part 3 was run through the real `TowerLayout` in Studio on 2026-11-23. Studio's `TowerLayout` source was byte-identical to this checkout (139,192 characters, Rojo-synced). The five entries were spliced into a throwaway clone in `ServerStorage._AstralProbe`, and the check ran `Layout.Get`, `Layout.Validate`, `Layout.PatrolRoutes`, `Layout.PortalSpots` and `PatrolPath.LoopLength`, then deleted the clone. Results: **zero** validation problems on all five floors, no build asserts, every link at or under `14.87°`, every terrain terrace on the 4-stud grid, no two terraces at the same height, every platform reachable from the Sanctuary, mob and Elite totals on contract (`16/22/25/35/35`, `1/2/3/4/4`), and every patrol under 240 s (the longest is 171.8 s). Re-run that check after any coordinate change. The exact Lua is in **Appendix A**: copy it from there, not from memory.

---

## Role

You are a two-specialist team speaking as one. Say which role is speaking when it matters.

**Starwright** is a senior level designer and gameplay engineer for *Infinite Towers: Become a Master!*, a Roblox squad-command action RPG. Starwright owns topography, sightlines, combat space, pacing, navigation and the `TowerLayout` connector contract. They think in walkable surfaces, link slopes, landings, camp spacing, leash radii, and the route a squad of five takes from the Sanctuary to the Apex.

**Lampwright** is a senior environment artist and world-builder. Lampwright owns the Halcyr ecosystem, the floating stacks, the orreries, the Index Lamps, the rift, materials, starlight, the void and the Conjunction. They build from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the earlier biomes were built. Every prop has a reason to be in the archive and reads clearly from the gameplay camera. Lampwright makes every floor a visible step up from the one below it.

Neither of you breaks the runtime contracts described below.

## Before you start

1. `git fetch origin` and branch each floor from `origin/main` as `feat/astral-archives-floor-<N>`. Work in the main checkout, because Rojo syncs from there. Use conventional commits and **one PR per floor. Never stack PRs.** This repo keeps head branches after a merge, so a stacked PR merges into its parent branch and never reaches `main`.
2. Follow `CLAUDE.md`, `AGENTS.md` and the `biome-floor-redesign` skill. Use the `roblox-world-building`, `roblox-luau`, `roblox-studio-mcp`, `roblox-npc-ai` and `roblox-performance` skills.
3. Read `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, the authored floors) and §3.6 (lighting), `docs/TOWER_NAVIGATION.md` (including "Authored terrain walkways"), `reference/infinite_towers_biomes.md` §9 (Astral Archives) and `docs/tower-mob-remodel-plan.md` §5.9 (the Astral enemy visuals and motif: floating pages, brass orreries and star-glyphs; glow starlight gold with indigo).
4. Read the earlier floor prompts, newest first: Sunken, Corrupted, Thunder, Infernal, Frozen, Ashen, Fungal, Verdant. Read their status notes and lessons, especially the Corrupted status log (kit clearance boxes, `OnTerrain` pinning, `wallFoot`) and the Sunken status log (`Sheer` aprons, `Pools[i].Round`, bridge styles). Then run `git log --oneline -- src/ServerScriptService/Core/Tower*.luau src/ReplicatedStorage/Shared/Config/TowerLayout.luau` and read the `fix(...)` commits.
5. Read the authored-floor code end to end:
   - `TowerLayout.luau`: `AUTHORED[31..37]` (the Fungal-style `Terrain = {...}` system this biome uses), `build`, `Validate`, `PatrolRoutes`, `Lanes` and `PortalSpots`.
   - `TowerTerrain.luau`: `Palettes.astral_archives` (Salt ground, Limestone, Slate cliffs, solid `Glacier` liquid), `Surfaces`, `MaterialColors`, `FungalMaterials`, `BlockyMaterials`, `Terrain.Shapes` (and Sunken's `Sheer`), `Pools`, `Islands`, `Ridges`, `Bridges`.
   - `TowerRoomBuilder.luau`: decks, `RoundDecks`, `DeckThickness`, bridges and stairs, curbs, open-sky versus vaulted rooms (`isNatural`, about line 487; **`astral_archives` is not in it**, §5.1).
   - `TowerBiomeAssets.luau` and `TowerSetPieces/`: `piece`, `group`, `kitAt`, `onTerrain`, `groundY`, `wallFoot`, `AirborneKinds`, and the current `astral_archives` branches (the backdrop `Orrery` group with `CelestialOrreryRing`, `OrbitingPlanet` and `OrreryCentralSun`, about line 7374; the `isCosmic` sky, about line 719).
   - `TowerBiomeKit.luau` and `TowerKitProps.luau`: `ExtraTemplates`, `Biomes.astral_archives` (`BanyanTree`, `Obelisk`, `TomeStack`), `Ecology.astral_archives` (`CrystalSpire` groves), `Has` and `Ready`.
   - `HubLighting.luau`: `BiomeGrades[9]` (indigo starlight) and `FloorGrades`.
   - `.claude/skills/biome-floor-redesign/references/studio-verify.luau`.

## The goal

The five Astral Archives floors (41–45) still use the seeded generic layout and the generic Astral props (`CrystalSpire` groves, `Obelisk` monoliths, `TomeStack` clutter, a backdrop orrery). Give each one its own hand-authored topography, built around one ecosystem, so each floor has a different shape, route and combat rhythm and reads differently from its neighbours. Every other floor stays byte-identical. The floor names are already fixed by the GDD (§3.3): **Starlit Vestibule, Orbiting Stacks, Fractured Index, Runeguard Athenaeum, Rift Warden's Observatory**.

This is the first biome where the walkable world **floats**. Every earlier biome stood on ground: a valley, a cave floor, a seabed. The Archives hang in a starfield over the **Nebula Floor**, a dark star-glass ground far below that only catches you when you fall. That single idea drives the new terrain option (§5.3, `Shapes[id].Float`) and the readability rules (§5.7).

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, shelf, lamp and creature traces back to this ecosystem. If a prop doesn't fit it, cut it.

### The Halcyr

The **Halcyr** were star-archivists: an order who believed every star was a book, and built a library beyond the sky to shelve them all. (One line of continuity: on Floor 41's Catalogue Isle, in a brass frame among the newest accessions, hangs a water-stained slate tide-chart from the Nereth Scriptorium on Floor 37. The Halcyr copied every tide the Nereth ever rang. The frame's label reads "*received wet*".)

They built in **pale vellum-white stone and deep lapis-indigo marble**, framed in **brass and worn gold leaf**, and shelved in **ebony**. Every surface carries **star-glyphs**: each star in their catalogue has a glyph, inlaid in gold on the floors, cut into the shelf-ends and stamped on every spine. Their great works were **orreries** (brass models of the heavens that also served as the catalogue's index, each planet a department) and **lecterns** raised on spires so a reader could read by starlight. Their sigil is the **star-quill**: a four-pointed star pierced by a quill, inside a ring. It appears on keystones, on the Index Lamps, on the Archive Executors' tabards and stamped in gold on the Astral Scribes' tomes.

### The Index, the Rift and the Warden

The Halcyr ordered their catalogue with the **Index Engine** (Floor 43): a vast brass machine of card-drawers, ring-gears and shelf-ranges that held one entry for every star. One entry was blank. Where the starfield had a tear in it, the Index listed only "*unwritten*": the **Rift**, the one place no star had ever been catalogued. It leads down, out of the sky, into the dark under everything (the Abyssal Throne, Floors 46–50).

The Halcyr built the **Rift Warden** (`ARCANE_COLOSSUS`: a towering guardian of stacked bookshelves and brass rings with a rift-eye core and floating tome shields; `docs/tower-mob-remodel-plan.md` §5.9) to stand in the **Observatory** (Floor 45), keep the Rift sealed and watch it. Its eye is a lens ground to look into the Rift without being read back.

The last **Grand Indexer** wanted the catalogue complete. They ordered the Index Engine to write the unwritten entry. The Engine read the Rift, and the Rift read the Engine back: the **Index fractured** (Floor 43), splitting the Index Floor into tilted plates and throwing shards into the cracks. The **Runeguard**, the archive's wardens, sealed the Athenaeum (Floor 44) with the half-written entry inside. The Warden's lens cracked and its eye opened. Now the Rift is reading the Archive, one page at a time: pages, lamps and stars drift toward it floor by floor. On Floor 41 the sky is full of stars. By Floor 45 half of it is black, and every loose page on the floor is being pulled into the eye.

### The Conjunction (the biome's through-line)

After the Heartroot, Veinweb, Ember Vein, Stillcold, Heartbeat, Tempest Squall, Rotpulse and Tidecall comes the **Conjunction**. On a shared server-time cycle (`workspace:GetServerTimeNow()`), the archive's orreries align:
- a slow sweep of starlight crosses the floor like the shadow of an orrery's arm turning overhead
- the constellation lines in the sky and the gold star-glyphs on the floors light in order, then fade
- loose pages lift, turn a quarter-circle and settle; the Index Lamps brighten
- a far chime rings, and under it a low, wrong note: the Rift reading

It is calm on Floor 41 (a slow ~16 s sweep with a clear chime) and builds to a ~6 s pull on Floor 45, where the sweep bends toward the rift-eye, the pages lift and do not settle, and the chime is answered from inside the Rift. It is **client-side and purely cosmetic** (§5.6).

### The Index Lamps (the trail the player follows)

The Halcyr hung a floating **Index Lamp** (a star-quill lantern in a brass ring) at every shelfmark along the readers' way. Where the lamps are lit, the way is open.

| Floor | How far the Rift has read | What the lamps tell you |
| --- | --- | --- |
| 41 | The Vestibule: the readers' entrance, untouched | Every lamp lit, warm gold, strung along the Quill constellation. The brightest line is the Quill's shaft to the Nib Star. |
| 42 | The Orrery: the index of departments | Lamps ride the planets round their orbits. Only the lamps at a conjunction (where an orbit's bridge reaches in) are lit, so the lit lamps show the way inward. |
| 43 | The Fracture: the Index Engine broke here | Lamps hang crooked, their strings snapped. They are lit only on the floating shards, because only the shards still cross the rifts. |
| 44 | The Athenaeum: sealed by the Runeguard | The Runeguard shuttered every lamp behind rune-plates so the Rift could not read by them. The only unshuttered lamps hang in the two Waygates. |
| 45 | The Observatory: the Warden's watch | Every lamp is drifting toward the rift-eye, guttering violet. The last two still burning gold hang on the Observatory's great rings, either side of the dais. |

### Living layers (use all of them on every floor, more of each the higher you go)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Starlight & Glow** | Star-glyphs, Index Lamps, constellation lines, star-glass floors, the Nebula Floor's glints | The signature glow is **pale starlight gold** (hue 42°–52°, low saturation) and **indigo** (230°–250°), with silver-white accents. **Never orange or red**: enemy telegraphs are `(255, 25, 55)` and `(255, 95, 40)` (`EntityRenderer`). A saturated gold drifts toward that orange, so keep it pale (§5.7). |
| **Stacks** | Ebony bookcases, shelf-ranges, rolling ladders, lecterns, card-catalogue cabinets, reading desks, chained tomes | Shelves face outward from an isle's edge, never across a lane. Tall stacks stay off lanes and ≥ 18 studs clear above walk surfaces where they overhang. |
| **Brass & Orrery** | Orreries, armillary spheres, astrolabes, orbit rails, ring-gears, telescopes, chains | Brass is worn and warm, with darker oxidised hollows, never mirror-bright. |
| **Stone** | Vellum-white stone, lapis-indigo marble, gold inlay, star-quill keystones | One pale stone family, one dark marble and one gold. |
| **Drift** | Floating pages, slowly orbiting tomes, quills, ink motes, dust of stars | Client-side and pooled (§5.8). The drift is calm on 41 and leans toward the Rift on 45. |
| **Star-glass** | The Nebula Floor's pools, star-wells in the isles, glass bridge decks | Terrain `Glacier`, the palette's solid liquid (`Palettes.astral_archives.Liquid`). Depth reads through dark beds and a client starfield under the glass, not a deep `Bottom` (§5.1). |
| **Void** | The Rift and its cracks, violet motes rising, stars going out | Absent on 41, a hairline in the sky on 42, the rifts on 43, sealed moats on 44, the whole floor torn on 45. Void violet stays **off walk surfaces** (§5.7). |

### Food web (how the enemies fit, `MobCatalog` → `astral_archives`)

- **Rune Mite** (`CRAWLER`, Regular: a clockwork mite with a floating rune-plate shell and brass legs; `BITE`): eats bindings. Put chewed spines, drifts of loose pages, brass filings and gnawed card-drawers near their camps.
- **Astral Scribe** (`CASTER_BIPED`, Regular: a hooded scribe with a quill-staff and an open floating tome, trailing pages; `PROJECTILE`): still copying. Put writing desks, ink-pots, star-charts pinned to boards and spilled quills at their camps.
- **Glyph Warden** (`CASTER_BIPED`, Support `WARD`: an archivist with orbiting glyph rings that lock into the ward): put warding circles inlaid in the floor and glyph pillars where it stands.
- **Archive Executor / Alpha** (`ARMORED_BIPED`, Elite/Alpha: a tall armoured enforcer with a segmented glaive and a star-chart tabard; the Alpha adds an orrery crown; `WEAPON_ARC` / `GROUND_AREA`): the Runeguard. Put glaive racks, seal-presses, shuttered lamps and confiscated books in chains wherever one stands guard.
- **Rift Warden** (`ARCANE_COLOSSUS`, Boss, Floor 45): the archive's last guard. Its moves (GDD §5.1) are **Astral Sweep** (`ARC`), **Dimensional Rupture** (`SELF_DISC`) and **Void Well** (`TARGET_DISC`).

The relic skins (`RelicConfig` → `ASTRAL`) are the **Aether Glass Geode**, the **Phase-Shift Urn**, the **Nexus Singularity Core** and the **Heart of the Rift Warden**. Echo them in stone shells split on starlit glass, archive urns flickering half out of the world, pinpoint singularities orbited by tiny rune rings, and brass astrolabe rings that tick like a clock.

### Ambient life (client-only, purely cosmetic)

Pages drifting and turning, tomes orbiting the tall landmarks, ink motes, shooting stars, constellations drawn in the sky that brighten on the Conjunction, a starfield turning slowly under the star-glass, orrery planets that turn on their rails (Floor 42), an aurora split by the Fracture (Floor 43), violet motes rising from the rifts (43–45), and on Floor 45 everything leaning toward the rift-eye. The higher the floor, the more of these run and the darker the sky. Everything is pooled, culled by distance, scaled by the Graphics quality setting, and off or minimal at the lowest quality. Nothing replicates from the server.

---

## Part 2: The escalation ladder

### 2.1 Layout and scale (validated in Studio for the Part 3 coordinates)

| Floor | Room (W × D × H, Bottom) | Area (vs. Sunken plan at this index) | Terraces | Links | Height levels | Apex Y | Max slope | Shortest walk (× canonical) | Sunken plan (terraces / links / levels / Apex) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 41 | 600 × 620 × 225, −4 | 372,000 (> 342,000) | 13 | 18 | 12 | 36 | 14.79° | 622.5 (1.94×) | 12 / 16 / 11 / 32 |
| 42 | 660 × 680 × 250, −4 | 448,800 (> 441,600) | 15 | 20 | 14 | 44 | 14.76° | 670.0 (1.85×) | 14 / 17 / 13 / 40 |
| 43 | 720 × 750 × 280, −6 | 540,000 (> 518,000) | 17 | 23 | 16 | 52 | 14.83° | 751.5 (1.86×) | 16 / 19 / 15 / 48 |
| 44 | 800 × 795 × 305, −6 | 636,000 (> 620,100) | 18 | 23 | 17 | 60 | 14.76° | 884.2 (1.94×) | 17 / 20 / 16 / 56 |
| 45 | 900 × 795 × 350, −6 | 715,500 (> 683,700) | 20 | 26 | 19 | 68 | 14.87° | 958.4 (1.89×) | 19 / 23 / 18 / 64 |

- *Terraces* counts every platform, including `Sanctuary` and `ExtraPlatforms`.
- *Height levels* counts distinct walk heights among all platforms except `Sanctuary`. On every Astral floor no two terraces share a height.
- *Shortest walk* is the Dijkstra distance from the Sanctuary centre to the Apex centre, summing centre → link end, the link's 3D length, and link end → centre, against the canonical layout for the same index measured the same way (321.0 / 362.9 / 404.8 / 455.4 / 506.4). This is the Sunken plan's measure.
- The Apex is `204 × 152` on Floor 45, larger than the Sunken plan's `196 × 144`.
- **Why `Bottom` is shallow.** The Basin return ramps run from `Bottom − 4` to `0` over a fixed 43-stud run (`build`, `ReturnLinks`), so they stay at or under 15° only while `Bottom ≥ −7`. At `−6` they are 13.1°. The Archives float over a void, but the void is sold by dark star-glass, fog and the client starfield, not by depth. (Corrupted 35's `−8` and the Sunken plan's `−10` make those ramps 15.6° and 18.0° by this formula. Check that in Studio before copying them.)

### 2.2 Assets and variety (targets your build must meet, measured by the set-piece census)

The Sunken plan's targets are the floor of these numbers.

| Floor | New kit templates | Distinct templates placed | Landmark set pieces | Placed props (excl. ground cover) | Ground cover and small clutter | Tallest landmark | Ambient systems |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 41 | ≥ 10 | ≥ 26 | ≥ 15 | ≥ 380 | ≥ 270 | ≥ 130 studs (the Lectern of First Light) | ≥ 7 |
| 42 | ≥ 11 | ≥ 32 | ≥ 17 | ≥ 470 | ≥ 380 | ≥ 150 (the Sun-Lectern's armillary) | ≥ 8 |
| 43 | ≥ 12 | ≥ 34 | ≥ 19 | ≥ 530 | ≥ 400 | ≥ 175 (the Index Engine) | ≥ 8 |
| 44 | ≥ 13 | ≥ 36 | ≥ 21 | ≥ 600 | ≥ 420 | ≥ 210 (the Athenaeum dome) | ≥ 9 |
| 45 | ≥ 14 | ≥ 39 | ≥ 23, plus one colossal centrepiece | ≥ 700 | ≥ 480 | ≥ 285 (the Great Telescope) | ≥ 10 |

**Performance wins a conflict.** If a target and the frame-rate budget in §5.8 disagree, meet the budget and say so in the PR. Never pad a floor with filler to hit a count.

### 2.3 Variety and readability rules (judged in review)

- **No filler.** No single template makes up more than 12% of a floor's placed props (ground cover excluded). Bookcases and tome stacks are the easiest things to over-scatter: count them.
- **Every terrace is a vignette:** at least 4 distinct prop kinds that say what it was for (catalogue isle, inkwell, bindery, errata press, copyists' yard, seal forge, lens gallery).
- **Every link is dressed at both ends:** star-quill lamp posts, brass newels, shelf-end pylons or glyph pillars on the terrace, off the lane.
- **Three skyline layers on every floor:** *near* (props, shelves, lamps on the isles); *mid* (landmark spires, orreries, towers, domes); *far* (**the Starfield**: a sky dome of stars and constellations with the far stacks of the archive floating in it, darkening floor by floor until on Floor 45 half of it is torn black around the rift-eye).
- **Every floor introduces at least one traversal feature and one landmark type that no earlier floor has.** Part 3 names them.
- **Grounded and readable:** density never hides camps, telegraphs, loot or the route. "Grounded" here means grounded on an isle: nothing floats unless it is on the drift list (pages, tomes, lamps, planets), and those are client-only.

---

## Part 3: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north. Y is the walkable top surface. Terrain terraces sit on multiples of 4. Any terrace at another height is a deck (`Terrain.Decks[id] = true`).

**Shapes already taken (40, don't repeat them):**
- **Verdant (1–5):** spine with glades; broken diagonal aqueduct; E–W gorge with three bridges; walled ring with wall-walks; spiral around a cenote.
- **Fungal (6–10):** horseshoe around a pool; switchback up a gallery wall; chasm with a round cap deck and hung bridges; bastion "H" through the Crossing; asymmetric radial spiderweb (dais in a moat, walk round to the one way in).
- **Ashen (11–15):** fork around a dune; single switchback; N–S ravine with two ledges and an arch; chokepoint gate and split fortress; route over a fallen giant.
- **Frozen (16–20):** lakeshore road versus floe chain; street lattice; inverted ravine (central spine); two routes in two climates; cathedral nave.
- **Infernal (21–25):** hub-and-spokes turntable; gantry Π with a stem; lava-lake fishbone causeway; three-strip sluice weave; hourglass pinch with side chambers.
- **Thunder (26 built, 27–30 planned):** braided contours round a headwall; concentric ringfort; sky-pinnacle archipelago; two-tier cliff fault with a viaduct; twin-wing caldera amphitheatre.
- **Corrupted (31–35):** meandering brook with four fords; up and over a ridge into a hidden hollow; hedge maze round a centred court; tree to tree up five elder trunks; up the backs of three converging roots.
- **Sunken (36–37 built, 38–40 planned):** broken processional stair over a tide-flat; figure-eight of two cloisters; ladder up a flight of locks; two staggered sea-walls; two reef horns round a maelstrom.

**Where the Apex sits (the contrast rule):**

| Floor | Apex position | How you reach it | Dominant landform | Light |
| --- | --- | --- | --- | --- |
| 40 *(for reference)* | Centre-back, a pillar dais in a maelstrom | Up two reef horns to chain stairs | A frozen maelstrom ringed by reef | Storm-eye under a sea-dome |
| 41 | **Back-east, raised on the Nib Star** | Follow the Quill constellation up its shaft from the front-west, or take the Inkwell line up the east | Floating star-isles over the Nebula Floor, drawn as one constellation | Pale gold first light |
| 42 | **Dead centre, the Sun-Lectern**, in plain view and out of reach from the front | Step inward orbit by orbit through the moons; in only from the west or east | A brass orrery of floating planets on orbit rails | Warm brass noon from the Sun-Lectern |
| 43 | **Back-west, the Lifted Index**: the highest corner of a tilted, cracked floor | Climb plate to plate up the tilt, crossing each rift on a floating shard or round its pinched end | A fractured index-floor of fault plates split by three rifts | Split violet-teal aurora |
| 44 | **Back-east, behind two rune-wards** | Through the one Waygate in each ward: west of centre, then east of centre | A walled athenaeum of three wards over void moats | Sealed indigo dusk with rune-lamp gold |
| 45 | **Centre-back, the largest dais**, its lens aimed at the Rift | Over the Rift on one of three sutures, then up the transit towers to the Observatory's great rings | A diagonal rift torn across the floor | Rift-eye: black starfield, violet rift glow, a silver lens-light on the dais |

No two neighbours share an Apex position, an approach, a landform or a light. 41 and 44 are both back-east, but they are not neighbours: one is a floating star you walk a constellation to, the other a sealed hall behind two walls.

**Fixed on every floor:**
- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, `128 × 56`, and `Basin` stays centred on `X = 0`. Arrivals land out of aggro.
- `Apex` holds the Floor Alpha (41–44) or Biome Boss (45) summon and the Ascend/Rerun portals (`Layout.PortalSpots`, at the back of the Apex). Every Apex below is entered from the south, west or east, never the north. The portal spots measured in Studio are listed per floor.
- Mob totals and Elite counts stay **16 / 22 / 25 / 35 / 35** and **1 / 2 / 3 / 4 / 4**. Never add mobs for bigger rooms. `ExtraPlatforms` hold no camps.
- Floors 43–45 replace the generic patrols with authored routes (`ReplacePatrols = true`). `BASIN_LOOP` is always generated.

**Terrain system: use the Fungal one**, as Corrupted Grove and Sunken Sanctuary did (`Terrain = { Direct = true, Surface = ..., Decks, DeckLooks, DeckThickness, RoundDecks, Shapes, Pools, Islands, Ridges, Bridges, BridgeStyles, LiquidRise, FloorDip, NoApexShelf, WallBand, GroveScale, MeadowScale, GroundCover, GroundCoverCount }`). Don't introduce a third system, and don't mix in the top-level `DirectTerrain` / `Suspended` / `Masonry` fields. Use `Shapes` (round or squircle) for every terrain terrace that isn't a built deck. New terrain features are listed in §5.3; each is an option on the Fungal system, not a new system.
- **Surface progression:** Floors 41–42 (the archive still whole) use a new `Surface = "HALCYR"` (pale limestone flag trails over star-dust salt, slate banks, slate cliffs and star-glass pool beds). **From Floor 43 on** use `Surface = "RIFTWARD"` (limestone trails over dark slate, basalt banks and cliffs, star-glass pool beds), so the ground darkens as the Rift reads the archive. Both reuse place-wide colours only (§5.3).

---

### Floor 41: Starlit Vestibule (`astral:1`, `INTRODUCTION`)

*600 × 620 × 225, `Bottom = −4`. Pale gold first light.*

**Guide image:** ask for it before building.

**Story beat:** the readers' entrance. New readers came through the **Index Gate**, crossed the **Readers' Concourse** and followed the lamps of the **Quill**, the Halcyr's guiding constellation, from star-isle to star-isle up to the **Nib Star**, where the **Lectern of First Light** stands on its spire and the first book a reader ever opened lies waiting. Nothing here is broken yet. The Rift is a rumour.

**Shape: a constellation of floating star-isles, traced by star-glass bridges, with the Apex as its brightest star in the back-east.** From the arrival you see the Quill drawn in light across the void: its **shaft** climbs diagonally from the **Vane Root** (front-west) through **Lamplighters' Isle** and **the Calamus** to **Nib Landing** and the **Nib Star**. Its **vane** fans out north-west (the **First Barb**, **Second Barb** and **Vane Tip**), and the short **Inkwell line** climbs the east side:
- **The shaft (the brightest line):** Vane Root → Lamplighters' Isle → the Calamus → Nib Landing → the **Nib Stair** (`STAIRS`, +8) onto the Nib Star.
- **The Inkwell line (quickest, measured):** Concourse → **the Inkwell** → **the Blotter** → the Nib Star from the south. A spur from the Blotter to Nib Landing joins it to the shaft.
- **The vane (scenic):** Lamplighters' Isle → First Barb → Second Barb → Vane Tip → the Nib Star from the west. The Calamus also links to the Second Barb.
- **Catalogue Isle**, low in the middle, joins the Concourse to the Calamus and the Inkwell: the reading-room shortcut.

**New to the tower:** the first floor that **floats**: every terrace past the Concourse is an island with nothing under it but the Nebula Floor (`Shapes[id].Float`, §5.3), joined by **star-glass bridges** (`BridgeStyles = "STARGLASS"`). It is also the first floor whose map is a drawn figure: stand at the Index Gate and you see the route as a constellation. New landmark types: a ring-gate over the arrival and a lectern spire. *Closest earlier shapes:* Verdant 2's broken diagonal aqueduct (a single ground-built line with a forced detour) and Thunder 28's sky-pinnacle archipelago (rock needles, no two adjacent at the same height). Here the isles form one figure with loops, the shaft is the readable spine, and the bridges are the constellation's lines.

```
                                    N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │              [VANE TIP] Y32 ───────────────► [ THE NIB STAR ] Y36
   │             /                                   ▲ (st)    ▲     │
   │ [SECOND BARB] Y26          [NIB LANDING] Y28 ───┘          |     │
   │     |       \                ▲        \______________ [THE BLOTTER] Y30
   │ [FIRST BARB] Y20 ────── [THE CALAMUS] Y24                  ▲     │
   │          \             /         ▲                         |     │
   │       [LAMPLIGHTERS' ISLE] Y16    └─── [CATALOGUE ISLE] Y6 ─┤     │
   │              ▲                             |                |     │
   │       [VANE ROOT] Y8                       |          [THE INKWELL] Y12
   │              \                             |              /       │
   │    ~~~~~~~~~~~~~~~~ READERS' CONCOURSE  Y0 ~~~~~~~~~~~~~~~~        │
   │                               |                                    │
   │                      [ THE INDEX GATE ] Y8                         │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Index Gate | 0, 8, 276 | 128 × 56 | deck (under the ring-gate) |
| `Basin` | Readers' Concourse | 0, 0, 165 | 568 × 96 | terrain (the archive's front floor, the only ground) |
| `WestGallery` | Vane Root | −190, 8, 25 | 84 × 72 | terrain (round, floating) |
| `Catalogue` (extra) | Catalogue Isle | 95, 6, −35 | 64 × 52 | deck (a card-catalogue floor on brass struts) |
| `EastGallery` | The Inkwell | 190, 12, 30 | 84 × 72 | terrain (round, floating, with a star-well) |
| `Shaft` (extra) | Lamplighters' Isle | −95, 16, −20 | 64 × 56 | terrain (round, floating) |
| `Barb1` (extra) | First Barb | −215, 20, −100 | 60 × 52 | terrain (round, floating) |
| `Crossing` | The Calamus | 0, 24, −85 | 76 × 60 | terrain (round, floating) |
| `Barb2` (extra) | Second Barb | −130, 26, −170 | 60 × 52 | deck (a glass reading-floor) |
| `NibLanding` (extra) | Nib Landing | 80, 28, −140 | 64 × 56 | terrain (round, floating) |
| `Blotter` (extra) | The Blotter | 210, 30, −60 | 60 × 52 | deck (a vellum-stone slab on chains) |
| `Barb3` (extra) | Vane Tip | −30, 32, −235 | 60 × 52 | terrain (round, floating) |
| `Apex` | The Nib Star | 175, 36, −225 | 112 × 84 | terrain (round, floating, the largest isle) |

**Paths (18 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→EastGallery` (+12), `Basin→Catalogue` (+6), `WestGallery→Shaft` (+8, 14.53°), `Shaft→Crossing` (+8, 14.53°), `Crossing→NibLanding` (+4), `NibLanding→Apex` (`STAIRS`: the Nib Stair, +8), `Shaft→Barb1` (+4), `Barb1→Barb2` (+6), `Crossing→Barb2` (+2), `Barb2→Barb3` (+6), `Barb3→Apex` (+4), `Catalogue→Crossing` (+18, 14.79°), `Catalogue→EastGallery` (+6), `EastGallery→Blotter` (+18, 14.79°), `Blotter→Apex` (+6), `Blotter→NibLanding` (−2).
*Bridges:* every link off the Concourse crosses open void, so every one except `Sanctuary→Basin` is a `Terrain.Bridges` entry. The shaft's four links use `"STARGLASS"` with the brightest gold edge-light; the others use `"STARGLASS"` with a paler edge, so the shaft reads first.

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite: an Archive Executor on the Vane Root, the Runeguard's doorkeeper), `EAST_GALLERY` 4. **Patrol:** `BASIN_LOOP` (105.9 s). **Portals:** Ascend `(191, 36, −255)`, Rerun `(159, 36, −255)`.

**Terrain:** `Surface = "HALCYR"`. The Concourse is the only ground: a broad flagged floor with a stepped front edge. Every other terrain terrace is a round `Shapes` isle with `Float = { Under = 26..40 }` (§5.3), its underside a tapering cone of slate and star-glass crystal, so open void shows under and between them. The Nebula Floor below (`Bottom − 4`) is dark slate with wide star-glass `Pools` (`LiquidRise ≈ 0`, solid `Glacier`) so a fallen squad lands on glass over stars and walks back to the Concourse by the return ramps. `GroveScale = 0` (no crystal groves on this floor); `NoApexShelf = true`; `WallBand` very low on every side so the starfield, not a cliff, is the room's edge.

**Landmarks (≥ 15):**
1. **The Lectern of First Light** on the Nib Star (≥ 130 studs): a slender vellum-stone spire with a gold-leaf crown, holding a lectern and an open book at the top in a pool of starlight. The Alpha's lair is round its foot; keep the arena floor clean.
2. **The Index Gate:** a ring-gate of brass and lapis over the arrival with the star-quill at its crown, its inner ring slowly turning.
3. **The Quill constellation:** Index Lamps on every isle and gold star-glass bridges tracing the figure, readable from the arrival.
4. **The Concourse:** a lapis-and-vellum floor inlaid with a gold star-map, reading benches along its edge and a front stair down from the Index Gate.
5. **Catalogue Isle:** card-catalogue cabinets with drawers half open, a librarian's desk and, in its brass frame, the Nereth tide-chart "*received wet*".
6. **The Inkwell:** a round star-well cut through the isle, ringed by ink-pots, quill racks and copyists' desks.
7. **The Blotter:** a great vellum slab hung on four chains, blotted with star-ink.
8. **Vane Root:** the Runeguard doorkeeper's post: a glaive rack, a register lectern and a turnstile of brass.
9. **Lamplighters' Isle:** a lamp-store with spare Index Lamps on racks and a long hooked pole.
10. **The three barbs:** each a small reading-garden of potted star-moss under a curved bookcase.
11. **A colossal Halcyr statue** at each side of the room's edge (a robed archivist holding an astrolabe aloft), standing on their own isles off the route. Reuse `RobedStatueStaff`, scaled and retinted.
12. **Floating tomes** orbiting the Lectern spire (client drift).
13. **Isle undersides:** slate cones with star-glass crystal tips and hanging lamp-chains, so every isle reads as afloat.
14. **The Nebula Floor:** the star-glass ground far below, glinting.
15. Far: the Starfield with the archive's far stacks floating in it, and the Quill drawn again in the sky above the floor.

**Kit candidates (≥ 10):** `IndexGateRing`, `LecternSpire`, `StarIsleUnderside` (three sizes), `StarglassBridgeSpan`, `IndexLamp`, `CatalogueCabinet`, `CopyistDesk`, `BookcaseCurved`, `InkwellBasin`, `ChainedSlab`, `StarMossPlanter`, `FloatingTomeCluster`.

**Lighting grade (`FloorGrades[41]`):** pale gold first light: a soft gold key, indigo sky, silver fill off the star-glass, the clearest Astral floor. `AtmosphereDensity ≈ 0.22`, `AtmosphereHaze ≈ 0.5`, `Saturation ≈ 0.12`, `Contrast ≈ 0.06`, `ColorShift_Top ≈ (255, 236, 196)`. It must break cleanly from Floor 40's dark storm-eye.

**Spec asserts:** key, name and `Size` (`Bottom = −4`, 2 return ramps). `Apex.X > 100` and `Apex.Z < −200` (back-east). `NibLanding→Apex` is `STAIRS`. **The Quill rule:** the shaft `WestGallery → Shaft → Crossing → NibLanding → Apex` exists link by link and rises at every step. The Apex is entered by exactly three links (`NibLanding`, `Barb3`, `Blotter`). Every terrace except `Sanctuary`, `Basin` and the decks has `Shapes[id].Float`. 16 mobs and 1 Elite. No `Validate` problems.

---

### Floor 42: Orbiting Stacks (`astral:2`, `EXPANDED_ENCOUNTER`)

*660 × 680 × 250, `Bottom = −4`. Warm brass noon from the Sun-Lectern.*

**Guide image:** ask for it before building.

**Story beat:** the index of departments. The Halcyr built their catalogue as a working orrery: the **Sun-Lectern** at the centre holds the master index, and each department of the archive is a **planet**, a floating stack-isle riding a brass **orbit rail** round it. Readers rode the orbits and crossed inward wherever two orbits met (a **conjunction**). The orbits still turn, slowly, but the Rift has knocked them out of true: a hairline of void runs across the sky above the Sun.

**Shape: a brass orrery, with the Apex as the Sun in the middle of the room.** From the arrival you look straight across **Perihelion Court** at the Sun-Lectern, 28 studs up and 74 studs of void away, with **no way across**. You reach it by stepping inward:
- **Outer orbit (west and east):** the Plinth → **Folio** or **Codex** (the galleries, Elites). From each, the orbit runs round the outside: Folio → **Glossary** → **Atlas** → **the Aphelion** (north, behind the Sun) → **Almanac** → **Marginalia** → Codex.
- **The moons (the south conjunction):** Folio → **Folio Moon** → Perihelion Court ← **Codex Moon** ← Codex. Each moon is also a conjunction inward.
- **Middle orbit:** **Lexicon** (west) and **Concordance** (east), reached only at a conjunction: from a moon (south) or from Atlas / Almanac (north).
- **The Sun:** up the **Lexicon Stair** (`STAIRS`, +12) from the west or the **Concordance Stair** (`STAIRS`, +8) from the east.

**New to the tower:** a layout read as orbits: you change orbit only where an orbit's bridge reaches in, and the conjunctions alternate between the south (the moons) and the north (Atlas, Almanac). New traversal: **orrery-arm bridges** (`BridgeStyles = "ORBIT"`): brass arms with a glass walk, swinging out from a planet. New landmark type: a working orrery the floor is built inside. *Closest earlier shapes:* Fungal 10's ring round a central dais (one way in, walked round a moat) and Thunder 28's concentric ringfort (ring walls and gates). Here there are no ring walls: the rings are cosmetic rails, the planets are separate isles at rising heights, there are two ways in, and the shortest route is a spiral of three short hops, not a walk round.

```
                                     N (−Z)
   ┌────────────────────────────────────────────────────────────┐
   │     [ATLAS] Y26 ─────── [THE APHELION] Y40 ─────── [ALMANAC] Y28     │
   │       |    \                                       /    |           │
   │ [GLOSSARY]  [LEXICON] Y32 ═(st)═► [ THE SUN- ] ◄═(st)═ [CONCORDANCE] Y36 [MARGINALIA]
   │   Y22 |          ▲                [ LECTERN  ] Y44         ▲          Y24 |
   │       |          |                  (no way in             |            |
   │ [FOLIO] Y8 ── [FOLIO MOON] Y18      from the south)   [CODEX MOON] Y20 ── [CODEX] Y12
   │       \              \                                   /             /
   │        \              ──── [PERIHELION COURT] Y16 ───────             /
   │         \                           |                              /
   │    ~~~~~~~~~~~~~~~~~~~~~ THE ORRERY PLINTH  Y0 ~~~~~~~~~~~~~~~~~~~~~  │
   │                                     |                                 │
   │                            [ THE ORRERY GATE ] Y8                     │
   └────────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Orrery Gate | 0, 8, 306 | 128 × 56 | deck |
| `Basin` | The Orrery Plinth | 0, 0, 195 | 628 × 100 | terrain |
| `WestGallery` | Folio | −200, 8, 20 | 88 × 76 | terrain (round, floating) |
| `EastGallery` | Codex | 200, 12, 20 | 88 × 76 | terrain (round, floating) |
| `Crossing` | Perihelion Court | 0, 16, 80 | 76 × 60 | terrain (round, floating) |
| `MoonSW` (extra) | Folio Moon | −100, 18, 20 | 60 × 52 | deck (a brass moon-disc) |
| `MoonSE` (extra) | Codex Moon | 100, 20, 20 | 60 × 52 | terrain (round, floating) |
| `MoonW` (extra) | Glossary | −260, 22, −80 | 56 × 48 | deck |
| `MoonE` (extra) | Marginalia | 260, 24, −80 | 56 × 48 | terrain (round, floating) |
| `OuterNW` (extra) | Atlas | −200, 26, −230 | 64 × 52 | deck |
| `OuterNE` (extra) | Almanac | 200, 28, −230 | 64 × 52 | terrain (round, floating) |
| `MiddleW` (extra) | Lexicon | −170, 32, −110 | 64 × 56 | terrain (round, floating) |
| `MiddleE` (extra) | Concordance | 170, 36, −110 | 64 × 56 | terrain (round, floating) |
| `Aphelion` (extra) | The Aphelion | 0, 40, −270 | 64 × 52 | terrain (round, floating, the cold far planet) |
| `Apex` | The Sun-Lectern | 0, 44, −70 | 124 × 92 | terrain (round, floating) |

**Paths (20 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→EastGallery` (+12), `Basin→Crossing` (+16, 14.76°), `WestGallery→MoonW` (+14, 14.73°), `MoonW→OuterNW` (+4), `OuterNW→Aphelion` (+14), `Aphelion→OuterNE` (−12), `OuterNE→MoonE` (−4), `MoonE→EastGallery` (−12, 14.69°), `MoonSW→MiddleW` (+14), `MoonSE→MiddleE` (+16), `OuterNW→MiddleW` (+6), `OuterNE→MiddleE` (+8), `MiddleW→Apex` (`STAIRS`: the Lexicon Stair, +12), `MiddleE→Apex` (`STAIRS`: the Concordance Stair, +8), `WestGallery→MoonSW` (+10, 14.63°), `MoonSW→Crossing` (−2), `EastGallery→MoonSE` (+8, 14.53°), `MoonSE→Crossing` (−4).
*Bridges:* the conjunctions (`MoonSW→MiddleW`, `MoonSE→MiddleE`, `OuterNW→MiddleW`, `OuterNE→MiddleE`) are `"ORBIT"` arms; every other void-crossing link is `"STARGLASS"`. The orbit rails themselves are cosmetic brass rings (kit, §5.4) at three radii round the Sun, ≥ 18 studs above every walk surface they pass over and never across a lane below that height. **Perihelion Court must read as a dead end toward the Sun:** 74 studs of open void, no stepping isle, no rail low enough to look walkable.

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4 (Perihelion Court), `WEST_GALLERY` 5 (Elite, Folio), `EAST_GALLERY` 5 (Elite, Codex). **Patrol:** `BASIN_LOOP` (116.4 s). **Portals:** Ascend `(16, 44, −104)`, Rerun `(−16, 44, −104)`.

**Terrain:** `Surface = "HALCYR"`. Every terrace past the Plinth is a `Float` isle (§5.3). The Nebula Floor below carries one great round star-glass `Pool` centred under the Sun, so the orrery reads as hanging over a glass disc of stars. The Plinth's north edge is the orrery's base ring: a stepped brass-and-stone rim. `GroveScale = 0`; `NoApexShelf = true`; `WallBand` low.

**Landmarks (≥ 17):**
1. **The Sun-Lectern** (≥ 150 studs with its armillary): a gold-and-brass sun globe on a round lectern dais, inside a tall armillary sphere whose rings rise high over the isle and never cross the arena below 18 studs. The Alpha's lair is under it; keep the floor clean.
2. **The orbit rails:** three brass rings round the Sun at rising heights, with toothed gear-tracks.
3. **The planets:** each isle crowned with its department's planet globe (a different colour and band each) on a short brass mast, off the lanes.
4. **The orrery arms:** the conjunction bridges, each a brass arm with a counterweight beyond the isle's edge.
5. **Folio and Codex:** circular reading rooms with ring bookcases round their edges, open to the void on the inner side.
6. **The moons:** brass moon-discs engraved with phases.
7. **Glossary** and **Marginalia:** narrow stacks of slips and annotation boxes.
8. **Atlas:** a great globe-stand and map-chests.
9. **Almanac:** star-tables carved on standing slates.
10. **Lexicon** and **Concordance:** tall lectern rows facing the Sun.
11. **The Aphelion:** the cold far planet, frosted star-glass, a lone telescope pointed out at the Starfield.
12. **Perihelion Court:** a brass sundial reading the Sun-Lectern's light, and a gap of void.
13. **The hairline in the sky:** the first sight of the Rift, a thin violet tear over the Sun.
14. **Ring-gears** half-sunk in the Plinth, the orrery's drive.
15. **The Orrery Gate:** the arrival under a brass ring with planets on wires.
16. **Floating tomes** in slow orbits round each planet (client drift).
17. Far: the Starfield with constellations of the department sigils.

**Kit candidates (≥ 11):** `SunLecternGlobe`, `ArmillarySphereTall`, `OrbitRailSegment` (arc, gear-track), `OrreryArmBridge`, `PlanetGlobe` (six banded variants by tint), `RingBookcase`, `MoonPhaseDisc`, `GlobeStand`, `StarTableSlate`, `LecternRow`, `RingGearHalf`, `SundialBrass`.

**Lighting grade (`FloorGrades[42]`):** warm brass noon: a warm key from the Sun-Lectern, cool indigo ambient, brass highlights on every rail. `AtmosphereDensity ≈ 0.28`, `AtmosphereHaze ≈ 0.8`, `BloomIntensity ≈ 0.5`, `Saturation ≈ 0.10`, `ColorShift_Top ≈ (255, 220, 160)`. Keep the gold pale enough that the Sun never reads orange (§5.7).

**Spec asserts:** key, name and `Size` (`Bottom = −4`, 2 return ramps). The Apex is entered by exactly two links, `MiddleW→Apex` and `MiddleE→Apex`, both `STAIRS`, one from each side. There is no link between the Apex and the `Crossing` or the `Aphelion`. **The conjunction rule:** `MiddleW` and `MiddleE` each have exactly three links (a moon, an outer planet and the Apex). The outer orbit `WestGallery → MoonW → OuterNW → Aphelion → OuterNE → MoonE → EastGallery` is a chain of links. 22 mobs and 2 Elites. No `Validate` problems.

---

### Floor 43: Fractured Index (`astral:3`, `TERRAIN_VARIATION`)

*720 × 750 × 280, `Bottom = −6`. Split violet-teal aurora.*

**Guide image:** ask for it before building.

**Story beat:** where the Index Engine broke. The **Index Floor** was one vast level hall of shelf-ranges. When the Engine read the Rift, the floor cracked into **plates** and the whole hall tilted: the north-west corner lifted, the south-east sank. Three **rifts** opened across it, and the shards of the cracked floor hang in them. The **Index Engine** stands at the back-east where the last rift closes, broken open, card-drawers spilling into the void. The aurora overhead is the sky's light, split by the Fracture.

**Shape: climb plate to plate up a tilted, cracked floor to its highest corner in the back-west.** Four ranges of plates step up from front to back and from east to west, so every plate is higher than the one south of it and the one east of it. Three rifts cut between the ranges:
- **Rift A** (between ranges one and two) is open from the east wall and **pinches shut at the west**: cross it on the **Cleft Shard** (centre-west), on the **Tilted Shard** (east), or round its pinched end from **Westrange** to the **Bindery Plate**.
- **Rift B** (between ranges two and three) is open from the west and **pinches shut at the east**: cross it on the **Index Shard**, which hangs where rifts B and C meet in the west, or round its pinched end from the **Errata Plate** to the **Ink-Cellar Plate**.
- **Rift C** (between ranges three and four) runs from the west wall to the **Index Engine**: cross it up the **Index Stair** from the Index Shard (`STAIRS`, +22), on the **Hanging Shard** (east of centre) to the **Colophon Plate**, or to the Engine itself.
- **The Lifted Index** (Apex) takes the Index Stair from the south or the Colophon link from the east.

**New to the tower:** terraces tilted as one landform (fault plates rising toward one corner, with sheer up-thrown scarps, §5.3 `Scarp`), cracks that close against a wall so the way round alternates sides (`Terrain.Rifts` with `Pinch`), and floating **shard decks** in the cracks (`BridgeStyles = "SHARD"`). New landmark type: a colossal broken machine at the fracture's origin. *Closest earlier shapes:* Verdant 3's E–W gorge (one gorge, three bridges), Ashen 13's N–S ravine with ledges, and Thunder 29's single cliff fault with a viaduct. Here there are three cracks that close at alternating ends, every crossing is either a shard or a pinch, and the ground itself tilts toward the goal.

```
                                     N (−Z)
   ┌────────────────────────────────────────────────────────────┐
   │ [ THE LIFTED INDEX ] Y52 ◄────────── [COLOPHON PLATE] Y48     [INDEX ENGINE] Y44
   │        ▲ (st)                           ▲                          ▲        │
   │ ╲╲╲╲╲ rift C ╲╲╲╲╲╲╲╲╲╲╲╲╲╲ [HANGING SHARD] Y40 ╲╲╲╲╲╲╲╲╲ (closes at the Engine)
   │   [INDEX SHARD] Y30 ── [LEDGER PLATE] Y36 ─────────── [INK-CELLAR PLATE] Y32
   │    /         \                                                   ▲        │
   │ ╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲ rift B ╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲╲  (pinch)  │        │
   │ [BINDERY PLATE] Y28 ─ [READING PLATE] Y24 ────────── [ERRATA PLATE] Y20       │
   │   ▲          \             ▲                                   ▲            │
   │ (pinch)  [CLEFT SHARD] Y18 ╲╲╲╲╲╲╲ rift A ╲╲╲╲╲╲╲╲╲ [TILTED SHARD] Y10        │
   │ [WESTRANGE] Y16 ── [THE RULED COURT] Y12              [EASTRANGE] Y8            │
   │        \                  |                            /                     │
   │     ~~~~~~~~~~~~~~~~~~~ THE INDEX FLOOR  Y0 ~~~~~~~~~~~~~~~~~~~              │
   │                           |                                                  │
   │                  [ THE SHELFMARK STAIR ] Y8                                  │
   └────────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Shelfmark Stair | 0, 8, 341 | 128 × 56 | deck |
| `Basin` | The Index Floor | 0, 0, 230 | 688 × 96 | terrain (the unbroken front of the hall) |
| `EastGallery` | Eastrange | 200, 8, 75 | 88 × 76 | terrain (plate, scarp north) |
| `ShardE` (extra) | The Tilted Shard | 190, 10, −10 | 56 × 48 | deck (floating shard in rift A) |
| `Crossing` | The Ruled Court | −20, 12, 85 | 84 × 64 | terrain (plate) |
| `WestGallery` | Westrange | −220, 16, 70 | 88 × 76 | terrain (plate) |
| `ShardA` (extra) | The Cleft Shard | −100, 18, 5 | 56 × 48 | deck (floating shard in rift A) |
| `P2E` (extra) | Errata Plate | 180, 20, −95 | 72 × 60 | terrain (plate) |
| `P2C` (extra) | Reading Plate | −40, 24, −75 | 72 × 60 | terrain (plate) |
| `P2W` (extra) | Bindery Plate | −210, 28, −80 | 72 × 60 | terrain (plate) |
| `ShardB` (extra) | The Index Shard | −110, 30, −165 | 56 × 48 | deck (the largest shard, where rifts B and C meet) |
| `P3E` (extra) | Ink-Cellar Plate | 240, 32, −185 | 72 × 60 | terrain (plate) |
| `P3C` (extra) | Ledger Plate | 20, 36, −175 | 72 × 60 | terrain (plate) |
| `ShardC` (extra) | The Hanging Shard | 140, 40, −245 | 56 × 48 | deck (floating shard in rift C) |
| `Engine` (extra) | The Index Engine | 250, 44, −300 | 64 × 52 | terrain (the Engine's footing) |
| `P4C` (extra) | Colophon Plate | 60, 48, −305 | 72 × 56 | terrain (plate) |
| `Apex` | The Lifted Index | −210, 52, −285 | 132 × 96 | terrain (round, the up-thrown corner) |

**Paths (23 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+16), `Basin→Crossing` (+12), `Basin→EastGallery` (+8), `WestGallery→Crossing` (−4), `Crossing→ShardA` (+6, 14.39°), `ShardA→P2C` (+6), `ShardA→P2W` (+10), `EastGallery→ShardE` (+2), `ShardE→P2E` (+10, 14.63°), `WestGallery→P2W` (+12, rift A's pinch), `P2W→P2C` (−4), `P2C→P2E` (−4), `P2W→ShardB` (+2), `P2C→ShardB` (+6), `ShardB→P3C` (+6), `ShardB→Apex` (`STAIRS`: the Index Stair, +22, 14.83°), `P3C→ShardC` (+4), `ShardC→P4C` (+8, 14.53°), `P4C→Apex` (+4), `P2E→P3E` (+12, 14.69°, rift B's pinch), `P3E→Engine` (+12, rift C's closed end), `P3C→P3E` (−4).
*Crossings:* every link that touches a shard is a `Terrain.Bridges` entry in `"SHARD"` style (a short glass-and-stone span with the shard's broken edge showing). Links along a range are terrain ramps over the plates' stepped edges. The pinch links climb over the closed end of a crack, where the two plates still touch. Two return ramps climb from the Nebula Floor onto the Index Floor (X ≈ ±266).

**Camps (25, 3 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite, the Ruled Court), `WEST_GALLERY` 5 (Elite, Westrange), `EAST_GALLERY` 5 (Elite, Eastrange).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (127.0 s), `WEST_PLATES` = `{WestGallery, P2W, P2C}` (128.5 s), `RIFT_CROSSING` = `{Crossing, ShardA, P2C}` (85.8 s), `EAST_PLATES` = `{EastGallery, ShardE, P2E}` (69.0 s), `UPPER_ROW` = `{ShardB, P3C, P3E}` (140.4 s). **Portals:** Ascend `(−194, 52, −321)`, Rerun `(−226, 52, −321)`.

**Terrain:** `Bottom = −6`, `Surface = "RIFTWARD"`. Each plate is a `Shapes` squircle with a **`Scarp`** (§5.3): a sheer face on its north and west sides (the up-thrown edges facing the player as they climb, banded with shelf-strata: rows of books fossilised in the rock) and an ordinary apron to the south and east. **`Terrain.Rifts`** (§5.3) carves the three cracks down to the Nebula Floor: rift A along `Z ≈ −10` from the east wall to its pinch at `X ≈ −170` (half-width ~20); rift B along `Z ≈ −127` from the west wall to its pinch at `X ≈ 200` (half-width ~12, the narrowest); rift C from the west wall along `Z ≈ −213`, east along `Z ≈ −240` to its closed end at the Engine's foot (`X ≈ 240`). Rifts B and C widen into one chasm round the Index Shard. Rift beds glow faint violet from below (§5.7). The shards are decks with `Float` undersides of jagged floor-slab. `GroveScale = 0`; `NoApexShelf = true`.

**Landmarks (≥ 19):**
1. **The Index Engine** (≥ 175 studs): a colossal brass catalogue-machine of stacked card-drawer banks, ring-gears and shelf-towers, split down the middle where the Rift read it, drawers spilling cards into rift C. It stands at the back-east and never overhangs a lane.
2. **The Lifted Index:** the highest plate, a reading hall whose floor is tilted toward the room, its great catalogue desk sliding against the scarp. The Alpha's lair; keep the arena level and clean.
3. **The three rifts:** sheer cracks with shelf-strata walls, violet light below and pages falling into them.
4. **The shards:** floor-slab fragments hanging in the cracks, each with a crooked Index Lamp still lit.
5. **The scarps:** sheer up-thrown faces of fossilised shelves on every plate's north and west edges.
6. **Toppled shelf-ranges** lying across the plates, off the lanes, books avalanching toward the south-east.
7. **The Ruled Court:** a ruled star-map floor cracked across, with a broken lectern ring.
8. **The Reading Plate:** reading desks sliding downhill, chairs tipped.
9. **The Bindery Plate:** presses and sewing frames, spools of gold thread.
10. **The Errata Plate:** a correction press and racks of struck-through pages.
11. **The Ledger Plate:** tall ledger stacks, one fallen into rift C.
12. **The Ink-Cellar Plate:** cracked ink vats bleeding indigo into the rock.
13. **The Colophon Plate:** the last page of every book bound into a wall of colophons.
14. **Westrange** and **Eastrange:** the front ranges, half intact, their shelf-ends lettered with star-glyphs.
15. **The Shelfmark Stair:** the arrival stair, its glyph-numbers counting up to the break.
16. **The aurora:** violet and teal ribbons across the sky, split along the line of the Fracture.
17. **Page falls:** sculpted ribbons of falling pages down the rift walls (meshes, not flat boxes).
18. **Broken orrery rings** from the Engine thrown across the plates.
19. Far: the Starfield, with the first stars going out along the Fracture's line.

**Kit candidates (≥ 12):** `IndexEngineCore` (split into drawer banks, gear ring and shelf towers for clearance), `ScarpShelfStrata`, `ShardSlab` (three sizes), `ToppledShelfRange`, `CardDrawerSpill`, `CatalogueDeskTilted`, `BinderyPress`, `ErrataPress`, `LedgerStackTall`, `InkVatCracked`, `ColophonWall`, `BrokenOrreryRing`, `PageFallRibbon`.

**Lighting grade (`FloorGrades[43]`):** split violet-teal aurora: a cool key, teal-violet sky light split along the Fracture, the rifts glowing from below. `AtmosphereDensity ≈ 0.34`, `AtmosphereHaze ≈ 1.2`, `Saturation ≈ 0.0`, `Contrast ≈ 0.14`, `ColorShift_Top ≈ (180, 205, 255)`. The rift glow stays below the walk surfaces; the plates are lit neutral so camps read.

**Spec asserts:** key, name and `Size` (`Bottom = −6`, 2 return ramps). `Apex.X < −150` and `Apex.Z < −250` (back-west). **The tilt rule:** along each range the plates rise from east to west (`EastGallery < Crossing < WestGallery`, `P2E < P2C < P2W`, `P3E < P3C`), and each range is higher than the one south of it. **The rift rule:** every link from range one to range two either touches `ShardA` or `ShardE` or is the pinch `WestGallery→P2W`. `ShardB→Apex` is `STAIRS`. 25 mobs and 3 Elites. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

### Floor 44: Runeguard Athenaeum (`astral:4`, `ELITE_STRONGHOLD`)

*800 × 795 × 305, `Bottom = −6`. Sealed indigo dusk with rune-lamp gold.*

**Guide image:** ask for it before building.

**Story beat:** the Runeguard's fortress-library, where the half-written entry was sealed. When the Index fractured, the Runeguard drew two **rune-wards** across the Athenaeum: walls of locked glyphs standing over void moats, each pierced by a single **Waygate** they could hold. Behind the second ward, in the **Sealed Stacks** under the Athenaeum's dome, lies the entry the Engine began to write. The Runeguard shuttered every lamp so the Rift could not read by them. They are still on watch.

**Shape: three wards in a row, each higher than the last, with one Waygate through each ward wall: west of centre, then east of centre.** From the arrival you see the first ward wall and, over both walls, the dome of the Sealed Stacks in the back-east.
- **The outer ward:** the Petitioners' Yard reaches the **Warded Court** (Crossing), **Copyists' Yard** (west gallery, Elite), **Binders' Yard** (east gallery, Elite), the **Porters' Lodge** and the **Overlook Loft**. Nothing in the east of the outer ward reaches the ward wall.
- **The first ward, the West Waygate:** from the Warded Court or Copyists' Yard, through the West Waygate into the middle ward.
- **The middle ward:** the **Hall of Indices** in the centre, the **West Tower** (Elite, Y 32) and **East Tower** (Elite, Y 36) at its ends, the **Seal Forge** and the **Lantern Walk** (a dead-end overlook of the second ward).
- **The second ward, the East Waygate:** from the Hall or the East Tower, through the East Waygate into the inner ward.
- **The inner ward:** up the **Waygate Stair** (`STAIRS`, +16) straight into the Sealed Stacks, or west to the **Court of Seals** and in by the **Seal Stair** (`STAIRS`, +8). The **Forbidden Vault** and the **Reliquary of Lenses** lie west of the Court of Seals.

**New to the tower:** **Waygates** (`BridgeStyles = "WAYGATE"`): the only crossing of each ward is a bridge that passes through a standing ring-portal, so the gate reads as magic, not masonry (the biome lore's portals, kept physical: §5.3). Rune-ward walls over void moats (`Terrain.Rifts` used as straight moats, with the ward's light-wall as kit). New landmark type: a domed athenaeum and rune pylons. *Closest earlier shapes:* Sunken 39's two staggered sea-walls (one gate, then over the inner wall at its towers) and Infernal 24's three-strip weave. Here you go *through* both walls, never over them, and each wall has exactly one gate, on alternate sides of centre, so the route swings west, then east.

```
                                     N (−Z)
   ┌────────────────────────────────────────────────────────────┐
   │ [RELIQUARY] Y48 ─ [FORBIDDEN VAULT] Y56 ─ [COURT OF SEALS] Y52 ═(st)═► [ THE SEALED ] │
   │                                               ▲                  [  STACKS  ] Y60│
   │                                                \                ▲ (st)            │
   │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ second rune-ward ▓▓▓▓▓▓▓▓▓▓▓ [EAST WAYGATE] Y44 ▓▓▓▓▓▓▓▓▓▓▓ │
   │          [LANTERN WALK] Y40                    ▲            ▲                    │
   │           /          \                         |            |                    │
   │ [WEST TOWER] Y32    [HALL OF INDICES] Y28 ─────┘ ── [SEAL FORGE] Y24 ── [EAST TOWER] Y36
   │        ▲               ▲                                                         │
   │         \             /                                                          │
   │ ▓▓▓▓▓▓▓▓ [WEST WAYGATE] Y20 ▓▓▓▓▓▓▓▓▓▓▓▓ first rune-ward ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
   │         /          \                   [OVERLOOK LOFT] Y18                       │
   │ [COPYISTS' YARD] Y12  [WARDED COURT] Y8 ──/    \── [PORTERS' LODGE] Y4 ── [BINDERS' YARD] Y16
   │          \               |                           /                           │
   │     ~~~~~~~~~~~~~~~~~ PETITIONERS' YARD  Y0 ~~~~~~~~~~~~~~~~~                     │
   │                          |                                                       │
   │                 [ THE POSTERN STAIR ] Y8                                         │
   └────────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Postern Stair | 0, 8, 363.5 | 128 × 56 | deck |
| `Basin` | Petitioners' Yard | 0, 0, 230 | 768 × 104 | terrain |
| `Lodge` (extra) | Porters' Lodge | 100, 4, 95 | 64 × 52 | terrain |
| `Crossing` | The Warded Court | −90, 8, 85 | 88 × 68 | terrain |
| `WestGallery` | Copyists' Yard | −290, 12, 70 | 92 × 80 | terrain |
| `EastGallery` | Binders' Yard | 250, 16, 70 | 92 × 80 | terrain |
| `Loft` (extra) | Overlook Loft | 40, 18, 15 | 60 × 48 | deck (a gallery on brackets) |
| `Gate1` (extra) | The West Waygate | −130, 20, −15 | 64 × 48 | deck (the bridge through the first ring) |
| `Forge` (extra) | Seal Forge | 110, 24, −60 | 64 × 52 | terrain |
| `Hall` (extra) | Hall of Indices | −10, 28, −90 | 88 × 64 | terrain |
| `WestBastion` | West Tower | −270, 32, −110 | 92 × 82 | terrain (the tower's wall-top court) |
| `EastBastion` | East Tower | 260, 36, −120 | 92 × 82 | terrain |
| `LanternWalk` (extra) | The Lantern Walk | −130, 40, −165 | 64 × 52 | terrain |
| `Gate2` (extra) | The East Waygate | 140, 44, −195 | 64 × 48 | deck (the bridge through the second ring) |
| `Reliquary` (extra) | Reliquary of Lenses | −200, 48, −290 | 64 × 52 | terrain |
| `Seals` (extra) | Court of Seals | 30, 52, −300 | 72 × 60 | terrain |
| `Vault` (extra) | The Forbidden Vault | −60, 56, −320 | 64 × 52 | terrain |
| `Apex` | The Sealed Stacks | 230, 60, −300 | 140 × 100 | terrain (round) |

**Paths (23 links):** `Sanctuary→Basin` (−8), `Basin→Crossing` (+8), `Basin→WestGallery` (+12), `Basin→EastGallery` (+16), `Basin→Lodge` (+4), `Lodge→Loft` (+14, 14.73°), `Loft→Crossing` (−10), `Lodge→EastGallery` (+12), `Crossing→Gate1` (+12, 14.69°), `WestGallery→Gate1` (+8), `Gate1→Hall` (+8), `Gate1→WestBastion` (+12), `WestBastion→LanternWalk` (+8), `Hall→LanternWalk` (+12, 14.58°), `Hall→Forge` (−4), `Forge→EastBastion` (+12), `Hall→Gate2` (+16), `EastBastion→Gate2` (+8), `Gate2→Apex` (`STAIRS`: the Waygate Stair, +16, 14.76°), `Gate2→Seals` (+8), `Seals→Vault` (+4), `Seals→Apex` (`STAIRS`: the Seal Stair, +8), `Vault→Reliquary` (−8).
*Wards:* the first ward runs wall to wall along `Z ≈ −22`, between the outer ward and the middle ward; the second along `Z ≈ −215` (west) to `Z ≈ −235` (east). Each is a `Terrain.Rifts` moat (half-width ~10) under a rune-ward light-wall (kit `RunewardVeil` between `RunewardPylon`s), and **only** the Waygate links cross it. The four links that touch `Gate1` or `Gate2` are `Terrain.Bridges` in `"WAYGATE"` style. Two return ramps climb from the Nebula Floor onto the yard (X ≈ ±296).

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (the Warded Court), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite, the West Tower at Y 32), `UPPER_EAST` 5 (Elite, the East Tower at Y 36).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (141.0 s), `OUTER_WARD` = `{WestGallery, Gate1, Crossing}` (116.3 s), `WEST_GATE` = `{Gate1, WestBastion, LanternWalk}` (128.5 s), `MIDDLE_WARD` = `{LanternWalk, Hall, Forge, EastBastion}` (171.8 s), `EAST_GATE` = `{EastBastion, Gate2, Seals}` (117.9 s), `INNER_WARD` = `{Seals, Apex, Gate2}` (137.3 s). **Portals:** Ascend `(246, 60, −338)`, Rerun `(214, 60, −338)`.

**Terrain:** `Bottom = −6`, `Surface = "RIFTWARD"`. Unlike 41–43, the Athenaeum stands on ground: three broad stepped wards of dark slate and limestone, each ward a plateau higher than the last, the moats cut between them. Only the Waygates and the Loft are decks. **Show the dome:** from the arrival camera, the Athenaeum dome must rise over both ward walls (check from the Sanctuary). `NoApexShelf = true`. `WallBand` keeps the cliff behind the dome low so it reads against the Starfield.

**Landmarks (≥ 21):**
1. **The Athenaeum dome** over the Sealed Stacks (≥ 210 studs): a lapis-and-vellum dome on a drum of tall windows, its gold ribs locked with rune-chains. Inside, the shelves of the Sealed Stacks ring the room and, on the north half, the **half-written entry**: a single open book on a sealed lectern under a cage of rune-rings. The Alpha's lair; keep the arena floor clean.
2. **The two rune-wards:** pylons of lapis and brass carrying a wall of locked glyphs, shimmering over the void moats.
3. **The West and East Waygates:** standing ring-portals over their bridges, inner rings turning, the only lit lamps on the floor hanging in them.
4. **The West Tower** and **East Tower:** round Runeguard towers with glaive racks, shuttered lamps and confiscated books chained to the parapets.
5. **The Hall of Indices:** a long hall of index cabinets, a great index board with every star-glyph, half its plates blacked out.
6. **The Seal Forge:** a forge for rune-seals, stamps and wax, an anvil of star-iron.
7. **The Lantern Walk:** a high walk of shuttered lamps facing the second ward and the dome.
8. **The Court of Seals:** a court of sealing presses and the Runeguard's oath-stones.
9. **The Forbidden Vault:** a vault door of brass rings, half open, books in chains inside.
10. **The Reliquary of Lenses:** racks of ground lenses for reading by starlight, one lens cracked (echo the Warden's eye).
11. **The Warded Court:** a court ringed by warding circles where petitioners waited.
12. **Copyists' Yard:** long copy desks under awnings, stacks of fair copies.
13. **Binders' Yard:** sewing frames, presses, hides stretched for vellum.
14. **The Porters' Lodge:** book carts, a porter's ledger and a lift-cage.
15. **The Overlook Loft:** a bracketed gallery facing the first ward.
16. **Shuttered lamps** everywhere: Index Lamps boxed behind rune-plates.
17. **Confiscated books** in chains and wax seals.
18. **Glyph pillars** at every ward foot (where Glyph Wardens stand).
19. **Rune-chains** binding the dome's ribs.
20. **The Postern Stair:** the arrival through a small back gate, the petitioners' way in.
21. Far: the Starfield dimming, the Rift a long violet tear across the north sky.

**Kit candidates (≥ 13):** `AthenaeumDome` (drum, ribs and dome split for clearance), `RunewardPylon`, `RunewardVeil` (client-animated glyph wall), `WaygateRing`, `RuneguardTower`, `IndexBoard`, `SealPress`, `StarIronAnvil`, `ShutteredLamp`, `ChainedTomeRack`, `VaultRingDoor`, `LensRack`, `SewingFrame`, `BookCartLift`.

**Lighting grade (`FloorGrades[44]`):** sealed indigo dusk: a dim cool ambient, warm gold pools only under the Waygates' lamps and the dome's windows, the ward-walls the brightest thing on the floor. `AtmosphereDensity ≈ 0.36`, `AtmosphereHaze ≈ 1.0`, `BloomIntensity ≈ 0.55`, `Saturation ≈ 0.06`, `ColorShift_Top ≈ (205, 195, 255)`. Check that every camp and telegraph still reads in the dark.

**Spec asserts:** key, name and `Size` (`Bottom = −6`, 2 return ramps). `Apex.X > 150` and `Apex.Z < −250` (back-east). **The ward rule:** with `Gate1` removed, none of `Hall`, `WestBastion`, `EastBastion`, `Forge`, `LanternWalk` or the Apex is reachable from the Sanctuary; with `Gate2` removed, the Apex is unreachable. `Gate1.X < 0 < Gate2.X` (the gates alternate). `Gate2→Apex` and `Seals→Apex` are `STAIRS`. `UPPER_WEST` and `UPPER_EAST` sit above Y 30. 35 mobs and 4 Elites. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

### Floor 45: Rift Warden's Observatory (`astral:5`, `BOSS_ARENA`)

*900 × 795 × 350, `Bottom = −6`. Rift-eye under a torn sky.*

**Guide image:** ask for it before building.

**Story beat:** the Warden's watch. The **Observatory** stands at the back of the archive on its observing floor, the **Great Telescope** behind it aimed down at the place where the Rift was sealed. The Rift is open now: a tear across the whole floor from the front-east to the back-west, pulling pages, lamps and stars into it. The Rift Warden stitched what it could: three **sutures** of shelves and brass chain still hold the two banks together. The Observatory's great **azimuth rings** stand either side of the dais, the last two lamps burning gold on them.

**Shape: a diagonal rift torn across the floor, stitched in three places, with the Observatory at the back-centre on the far bank.** You arrive on the **Meridian Terrace** and see the Rift run away from you across the whole floor, the Observing Floor high on the far bank (`Apex`, Y 68, `204 × 152`, the largest Apex in the tower).
- **The middle suture (quickest, measured):** **Meridian Court** (Crossing) → the **Middle Suture** → the **Lens Gallery** → the **East Ring** → the **East Ring Stair** (`STAIRS`, +8) onto the dais. A spur from the Middle Suture ends at the **Rift Overlook**, a ledge facing the dais across the void: a dead end.
- **The east suture:** the Plinth → the **Fallen Catalogue** → over the Rift's narrow east tip to the **East Stacks** (Elite) → the **East Transit Tower** (Elite, Y 40) → the East Ring, or round by the **Orrery Crest**.
- **The west suture:** the **West Stacks** (Elite) → the **West Transit Tower** (Elite, Y 32), or by the **Ink Pools** and **Star-Lectern** → the **West Suture** → the **West Rift Lip** → the **West Ring** → the **West Ring Stair** (`STAIRS`, +12).

**New to the tower:** a rift you see end to end from the arrival, crossed only at three sutures (`BridgeStyles = "SUTURE"`: shelves lashed together with brass chain and stitched with light), and a boss dais whose backdrop is a torn sky. New landmark type: the Great Telescope and the rift-eye. *Closest earlier shapes:* Verdant 3's E–W gorge with three root bridges (straight across the route, on the ground) and Sunken 40's two horns to chain stairs. Here the tear runs diagonally, so each suture sits at a different depth and height, the banks are unequal (the near bank is the south-west triangle, the far bank holds the dais), and the middle suture is the short way, not a dead end.

```
                                        N (−Z)
   ┌──────────────────────────────────────────────────────────────────┐
   │ [WEST RIFT LIP] Y48 ─ [WEST RING] Y56 ═(st)═► [ THE OBSERVING ] ◄═(st)═ [EAST RING] Y60 ─ [ORRERY CREST] Y46
   │       ▲                                      [     FLOOR      ]       ▲     ▲         /   │
   │ [WEST SUTURE] Y42 ╲╲                         [ 204×152   Y68  ]      /      |        /    │
   │       ▲             ╲╲╲   [RIFT OVERLOOK] Y30                 [LENS GALLERY] Y36 ─ [EAST TRANSIT TOWER] Y40
   │ [WEST TRANSIT TOWER] Y32 ╲╲╲    ▲                                ▲                ▲       │
   │       ▲     ▲              ╲╲╲ [MIDDLE SUTURE] Y26 ───────────────┘                |       │
   │       |  [STAR-LECTERN] Y20   ╲╲╲╲   ▲       ▲    ╲╲╲ the Rift ╲╲╲        [EAST STACKS] Y10│
   │       |       ▲                      |   [PROOF ROOM] Y22    ╲╲╲╲╲╲╲╲╲╲╲╲╲╲    ▲         │
   │ [WEST STACKS] Y8 ─ [INK POOLS] Y16 ─ [MERIDIAN COURT] Y12       [FALLEN CATALOGUE] Y4 ┘   │
   │        \                    |                       /                                  │
   │    ~~~~~~~~~~~~~~~~~~~~~~ MERIDIAN TERRACE  Y0 ~~~~~~~~~~~~~~~~~~~~~~~                  │
   │                                     |                                                  │
   │                            [ THE LAST LAMP ] Y8                                        │
   └──────────────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Last Lamp | 0, 8, 363.5 | 128 × 56 | deck |
| `Basin` | Meridian Terrace | 0, 0, 236 | 868 × 104 | terrain |
| `Fallen` (extra) | Fallen Catalogue | 180, 4, 120 | 64 × 52 | terrain (near bank) |
| `WestGallery` | West Stacks | −300, 8, 80 | 92 × 80 | terrain (near bank) |
| `EastGallery` | East Stacks | 300, 10, 10 | 92 × 80 | deck (far bank: a stack-floor on shelving) |
| `Crossing` | Meridian Court | −60, 12, 100 | 88 × 68 | terrain (near bank) |
| `Ink` (extra) | The Ink Pools | −165, 16, 85 | 56 × 48 | terrain (near bank) |
| `Lectern` (extra) | Star-Lectern | −170, 20, −10 | 64 × 52 | terrain (near bank) |
| `Proof` (extra) | Proof Room | 50, 22, 55 | 60 × 48 | deck (near bank) |
| `SutureMid` (extra) | The Middle Suture | 40, 26, −20 | 56 × 48 | deck (in the Rift) |
| `Overlook` (extra) | Rift Overlook | −60, 30, −95 | 64 × 52 | deck (far lip, cantilevered over the Rift) |
| `WestBastion` | West Transit Tower | −330, 32, −80 | 92 × 82 | terrain (near bank) |
| `Lens` (extra) | Lens Gallery | 150, 36, −60 | 72 × 60 | terrain (far bank) |
| `EastBastion` | East Transit Tower | 300, 40, −150 | 92 × 82 | terrain (far bank) |
| `SutureW` (extra) | The West Suture | −230, 42, −165 | 56 × 48 | deck (in the Rift) |
| `Orrery` (extra) | Orrery Crest | 340, 46, −300 | 64 × 52 | deck (far bank) |
| `RiftLipW` (extra) | West Rift Lip | −300, 48, −250 | 64 × 56 | terrain (far bank) |
| `WestAnchor` (extra) | The West Ring | −205, 56, −235 | 64 × 56 | terrain (far bank) |
| `EastAnchor` (extra) | The East Ring | 215, 60, −235 | 64 × 56 | terrain (far bank) |
| `Apex` | The Observing Floor | 0, 68, −225 | 204 × 152 | terrain (round) |

**Paths (26 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→Crossing` (+12), `Basin→Fallen` (+4), `Fallen→EastGallery` (+6, the east suture), `WestGallery→Ink` (+8), `Ink→Crossing` (−4), `Crossing→Lectern` (+8), `WestGallery→WestBastion` (+24, 14.84°), `Lectern→WestBastion` (+12), `Crossing→SutureMid` (+14), `Fallen→Proof` (+18, 14.03°), `Proof→SutureMid` (+4), `SutureMid→Lens` (+10), `SutureMid→Overlook` (+4), `WestBastion→SutureW` (+10, 14.63°), `SutureW→RiftLipW` (+6), `RiftLipW→WestAnchor` (+8), `WestAnchor→Apex` (`STAIRS`: the West Ring Stair, +12), `EastGallery→EastBastion` (+30, 14.87°), `Lens→EastBastion` (+4), `EastBastion→EastAnchor` (+20, 14.81°), `Lens→EastAnchor` (+24), `EastBastion→Orrery` (+6), `Orrery→EastAnchor` (+14), `EastAnchor→Apex` (`STAIRS`: the East Ring Stair, +8).
*Sutures:* the links that cross the Rift (`Fallen→EastGallery`, and every link touching `SutureMid` or `SutureW`) are `Terrain.Bridges` in `"SUTURE"` style. Both Ring Stairs are `Terrain.Bridges` in `"STARGLASS"` style, rising between the azimuth rings' brass arcs, outside `UsableWidth` and never overhanging the arena. Two return ramps climb from the Nebula Floor onto the terrace (X ≈ ±333).

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite, Y 32), `UPPER_EAST` 5 (Elite, Y 40). The **Rift Warden** is summoned on the `204 × 152` dais. **Astral Sweep** (`ARC`), **Dimensional Rupture** (`SELF_DISC`) and **Void Well** (`TARGET_DISC`) must stay on the dais and never spill onto a Ring Stair. The Warden is tall: check in playtest that its tome shields and brass rings stay inside the camera's view of the arena and never clip the Telescope. Keep the dais floor clean: a worn gold meridian line and star-map in dark lapis, ringed on the outer rim only by the azimuth rings' footings.

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (158.6 s), `WEST_BANK` = `{WestGallery, Ink, Crossing, Lectern}` (159.2 s), `MID_SUTURE` = `{Crossing, SutureMid, Lens}` (110.3 s), `WEST_HORN` = `{WestBastion, SutureW, RiftLipW, WestAnchor}` (136.1 s), `EAST_HORN` = `{EastGallery, EastBastion, EastAnchor}` (122.7 s), `EAST_CREST` = `{EastBastion, Orrery, EastAnchor}` (119.1 s), `ANCHOR_RING` = `{WestAnchor, Apex, EastAnchor}` (168.7 s). **Portals:** Ascend `(16, 68, −289)`, Rerun `(−16, 68, −289)`.

**Terrain:** `Bottom = −6`, `Surface = "RIFTWARD"`. **`Terrain.Rifts`** (§5.3) carves the tear down to the Nebula Floor along a polyline from the east wall at about `(430, 150)` through `(240, 70)`, `(40, −20)`, `(−120, −60)`, `(−230, −160)` to the west wall at about `(−450, −190)`. It is narrow at the east tip (half-width ~16, where the east suture is a short span), widest round the middle suture (~40) and ~35 at the west suture. The Rift never runs under a terrace except the two suture decks and the Rift Overlook's cantilever; tune the polyline in Studio until it clears `Lectern`, `WestBastion` and `RiftLipW`. The Rift bed is star-glass over a client-side rift-eye mesh glowing violet (§5.7). The near bank is low and broad, the far bank rises to the dais in a round `Shapes` mesa with a sheer apron (Sunken's `Sheer`) so the Observing Floor reads as a pedestal. `NoApexShelf = true`. `WallBand` low at the back so the Telescope stands against the torn sky.

**Landmarks (≥ 23, plus the colossal centrepiece):**
1. **The Great Telescope (colossal centrepiece, ≥ 285 studs):** a brass refractor on a stone-and-brass equatorial mount behind the dais, its tube aimed down and west at the Rift, its objective lens cracked. It stands at the back wall and beyond, **never overhangs the `204 × 152` arena**, and stays clear of `Layout.PortalSpots`.
2. **The Observatory dome:** an open ribbed dome behind and above the dais, its shutters torn open, framing the Telescope. A far-layer mesh, never between the camera and the arena.
3. **The Rift:** the tear end to end, pages and lamps falling into it, violet light from below, edges fringed with crystallised starlight.
4. **The rift-eye:** where the Rift widens, a slow-turning eye of void deep in its bed (client mesh), the thing the Warden watches.
5. **The three sutures:** shelves lashed across the tear with brass chains, stitched with gold light.
6. **The azimuth rings:** two colossal brass rings standing either side of the dais on the West and East Rings, the last gold lamps hanging in them.
7. **The Ring Stairs:** glass stairs rising between each ring's arcs.
8. **The dais rim:** the rings' footings and a gold meridian line, on the outer edge only.
9. **The Rift Overlook:** a brass cantilever over the tear facing the dais, the Grand Indexer's chair overturned on it.
10. **The Lens Gallery:** lens-grinding benches and racks of lenses, all turned to the Rift.
11. **The Transit Towers:** round towers with transit instruments, marking where stars crossed the meridian.
12. **The Orrery Crest:** the Observatory's great orrery fallen on its side, rings bent, planets scattered.
13. **The Star-Lectern:** the reader's lectern with the star-catalogue open at the last page.
14. **The Ink Pools:** spilled indigo ink pooled in the flags, star-glyphs written in it.
15. **The Fallen Catalogue:** a whole range of card cabinets toppled toward the Rift's east tip.
16. **The Proof Room:** a press with the last proofs of the catalogue, one sheet blank.
17. **The West Rift Lip:** a crystal-fringed lip with the Warden's old watch-post.
18. **The torn sky:** half the Starfield black, stars streaming into the tear.
19. **Drifting Index Lamps** guttering violet, all leaning toward the Rift (client).
20. **Pages in the wind:** pages lifted off every surface and pulled toward the eye on the Conjunction.
21. **Rune rings** on the dais rim that flare gold when the boss is summoned.
22. **The Last Lamp** at the Sanctuary: one Index Lamp on a post, still gold, still steady.
23. **The Warden's shadow:** the silhouette of shelves and rings standing in the dome before the summon (client-only, far layer).

**Kit candidates (≥ 14):** `GreatTelescope` (mount, tube, lens split for clearance), `ObservatoryDomeRibs`, `AzimuthRing`, `RiftEyeMesh` (client), `RiftLipCrystal`, `SutureShelfSpan`, `TransitTower`, `TransitInstrument`, `LensBench`, `FallenOrrery`, `StarLecternGrand`, `InkPoolDecal`, `ToppledCabinetRange`, `ProofPress`, `MeridianFooting`.

**Lighting grade (`FloorGrades[45]`):** rift-eye under a torn sky: a black-indigo ambient, a cold silver-white key from the Observatory lens on the dais, violet from the Rift below, gold only on the two rings' lamps. `AtmosphereDensity ≈ 0.40`, `AtmosphereHaze ≈ 1.3`, `BloomIntensity ≈ 0.6`, `Contrast ≈ 0.12`, `Saturation ≈ 0.05`. The dais is lit by a soft neutral key so the Warden and every telegraph read. No red or orange anywhere on the floor.

**Spec asserts:** key, name and `Size` (`Bottom = −6`, 2 return ramps). The Apex is `204 × 152` at Y 68, is the highest terrace, and is entered by exactly two links (`WestAnchor`, `EastAnchor`), both `STAIRS`, one from each side. `Overlook` has exactly one link (a dead end). **The suture rule:** with `Fallen→EastGallery`, `SutureMid` and `SutureW` removed, the Apex is unreachable. The Apex's landmark footprints stay off the arena and the portal lanes. 35 mobs, 4 Elites and the Boss camp. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

### 3.6 Shapes that were tried and pulled in

These walks are estimates from centre-to-centre distances, made while drafting; only the final layouts above were run in Studio.

- **Floor 42, a true orrery loop** (arrive on the outer orbit, ride it round to a north conjunction, ride the middle orbit back south): about 2.8× the canonical walk. The orbits stayed, the conjunctions moved to the moons so the short way is three hops.
- **Floor 43, a full zig-zag** (cross each rift at alternate walls): about 2.6×. The rifts still pinch at alternate walls, but the shards sit near the centre line, so the shortest route is a gentle diagonal and the pinches are the slow ways round.
- **Floor 44, a wall-to-wall slalom** (Waygates at the room's edges): about 2.5×. The Waygates moved to ±130–140 studs from centre.
- **Floor 44, the Apex in the front half** (a hook round the whole room, entered from the north with the portals on its south side): about 2.9×. Dropped.

---

## Part 4: Lighting per floor

Add `HubLighting.FloorGrades[41..45]`, each layered over `BiomeGrades[9]` (indigo starlight), as the earlier floors did. `ClockTime` is shared and never changes: show the mood through colour shift, ambient, atmosphere, tint, contrast, bloom and sky decals. No two neighbouring floors may share a mood. Floor 40's storm-eye is dark blue-black; Floor 41 must break cleanly from it into pale gold.

| Floor | Mood | Key and ambient | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 41 | Pale gold first light | Soft gold key, indigo sky, silver fill off the glass | Clear (`Density ~0.22`, `Haze ~0.5`) | The Quill bright in the sky; full Starfield |
| 42 | Warm brass noon | Warm key from the Sun-Lectern, cool indigo ambient | `Density ~0.28`, `Haze ~0.8`, `Bloom ~0.5` | Brass glints on the rails; the hairline Rift |
| 43 | Split violet-teal aurora | Cool key, aurora split along the Fracture | `Density ~0.34`, `Haze ~1.2` | Rifts glowing from below; stars going out |
| 44 | Sealed indigo dusk | Dim cool ambient, warm pools under the Waygates | `Density ~0.36`, `Haze ~1.0`, `Bloom ~0.55` | The ward-walls' glyph light; the dome's windows |
| 45 | Rift-eye under a torn sky | Black-indigo ambient, silver lens-light on the dais | `Density ~0.40`, `Haze ~1.3`, `Bloom ~0.6` | Violet rift below; two gold ring-lamps; half the sky black |

Keep each floor at ≤ 24 lights. Effects are client-only, pooled and quality-scaled.

---

## Part 5: Engineering

### 5.1 Room sizing, open sky and depth

`TowerLayout` already supports `Size = { Width, Depth, Height, Bottom? }`, and every consumer reads the built layout's dimensions. **All five Astral rooms are open-sky** (the Starfield), so add `astral_archives` to `TowerRoomBuilder`'s `isNatural` test (about line 487) with Floor 41's PR. Generic Astral floors must not change: gate it to authored floors if the natural-room path changes anything for seeded layouts, and check that Floors 1–40 and 46–50 stay byte-identical. `HubLighting.TowerFloorAt` (2,400-stud grid) holds `900 × 795`.

`Bottom` stays at `−4` (41–42) and `−6` (43–45) so the Basin return ramps stay under 15° (§2.1). The void's depth is sold by the Nebula Floor's darkness, the star-glass pools and the client starfield beneath them.

### 5.2 Set pieces

Each floor gets its own module, `ServerScriptService/Core/TowerSetPieces/AstralFloor<N>.luau`, mirroring the Corrupted and Sunken floor modules, and exports its landmark footprints (`Floor<N>Landmarks`) for offline lane and camp checks. Use the shared helpers (`piece`, `group`, `kitAt`, `onTerrain`, `groundY`, `wallFoot`). Positions in a floor block are room-local: add `origin` when you set `.CFrame` yourself. Pieces that hang or float by design (Index Lamps on chains, chained slabs, orbit rails, planet globes, azimuth rings) must be pinned `OnTerrain` or listed in `AirborneKinds`, or the settle pass drops them (Floor 31 lesson). Client drift (pages, tomes, drifting lamps) is never a server prop.

### 5.3 Terrain, surface and materials

**Materials are place-wide.** Never use or recolour Fungal-owned materials (`Cobblestone`, `Concrete`, `Pavement`, `Asphalt`), never recolour shared `MaterialColors`, and never use `TowerTerrain.BlockyMaterials` (`Brick`, `WoodPlanks`): Roblox collides them as 4-stud steps.

Two new entries in `TowerTerrain.Surfaces`, using only uncoloured or already-coloured shared materials (`Limestone`, `Salt`, `Slate` and `Glacier` have no `MaterialColors` entry; `Basalt` is the shared dark grey):
- `HALCYR` (41–42): `Trail = Limestone` (pale vellum flags), `Walk = Salt` (star-dust), `WalkAccent = Limestone`, `Bank = Slate`, `Cliff = Slate`, `Peak = Basalt`, `PoolBed = Glacier` (star-glass), `Lush = Salt`.
- `RIFTWARD` (43–45): `Trail = Limestone`, `Walk = Slate`, `WalkAccent = Basalt`, `Bank = Basalt`, `Cliff = Basalt`, `Peak = Basalt`, `PoolBed = Glacier`, `Lush = Slate`.

Add a spec that both surfaces avoid blocky and Fungal-owned materials. Mud stays out of both (its rippled texture reads as liquid).

New terrain options, each on the Fungal system, each only where its floor needs it, each obeying every terrain rule (terraces on the 4-stud grid, never under `Bottom − 4`, FBM edges):
- **`Shapes[id].Float = { Under = n }`** (41, 42, and the 43 shards): the terrace's terrain body ends in a tapering, noise-warped underside `n` studs below its top (slate with star-glass crystal at the tip) instead of an apron to the ground, leaving open air down to the Nebula Floor. Every link touching a floating isle is a `Terrain.Bridges` entry. Grounding raycasts and the settle pass already treat terrain as support, so props on an isle are grounded on it.
- **`Shapes[id].Scarp = { Sides = {"N","W"}, Height = n }`** (43): a sheer up-thrown face on the listed sides (≤ 8-stud apron, like Sunken's `Sheer`) and the ordinary apron elsewhere, so a plate reads as a tilted fault block.
- **`Terrain.Rifts`** (43, 44, 45): a list of polylines (`Points`, `HalfWidth` per point, `Pinch = "W"|"E"|nil`) carved down to `Bottom − 4` with rough walls, narrowing to closed at a pinch. 44 uses straight wall-to-wall rifts as the ward moats. A rift never runs under a link except a bridge.
- **`BridgeStyles`:** `"STARGLASS"` (41, 42, 45; a glass deck on brass ribs with constellation inlay and a gold edge-light), `"ORBIT"` (42; a brass orrery arm with a counterweight past the isle), `"SHARD"` (43; a short span of cracked floor-slab), `"WAYGATE"` (44; a bridge through a standing ring-portal) and `"SUTURE"` (45; shelves lashed with brass chain), each drawn outside `UsableWidth`.

**Waygates stay physical.** The biome's lore has "magical portals connecting distant chambers". A real teleport link would touch navigation, squad follow, recall, patrols and the connector graph, so here every portal is a ring-gate over a real walkway. Teleporting links are out of scope (Part 6).

Document each new option and bridge style in `docs/TOWER_NAVIGATION.md` in the floor's PR.

### 5.4 Kits: enough meshes for the ladder

1. Reuse first: `RobedStatueStaff` (the colossal Halcyr statues), `Obelisk` (glyph pillars), `CrystalSpire` (isle-underside crystals), `TomeStack`, `ArchPierBase`, `ArchPierSegment` and `ArchCrown`, `GothicPillarColonnade`, `CenoteColonnadeDome` (domes), `VaultRibArch`, `GatehouseArch`, `CurtainWallRuins`, `HangingLantern`, `StoneUrn`, `RuinRubble`, `BoulderCluster`, the backdrop orrery's `CelestialOrreryRing` / `OrbitingPlanet` / `OrreryCentralSun` part-builders, and the Sunken bell-arch and chain pieces (retinted brass) where a ring or chain fits.
2. Generate each floor's new templates with `tools/blender/generate_astral_f<N>_kit.py` → `assets-source/tower/astral_f<N>_kit/` (FBX, .blend, `manifest.json`, previews). **Commit the generator.**
3. Register every template in `TowerBiomeKit.ExtraTemplates` only (Size, Min, Roles from the manifest). Names must be unique across all kits. Add only big architectural pieces to `CastsShadow`.
4. **No new colour roles** unless a floor proves it needs one: `STONE` is vellum-white stone, `ALT` lapis-indigo marble, `TRIM` gold leaf, `METAL` brass, `WOOD` ebony shelving, `SILK` vellum pages and robes, `GLOW` starlight and lamp-light, `CRYSTAL` star-glass, `MOSS` star-moss. Each floor passes a full tint table (in `TowerSetPieces/AstralFloor<N>.luau`), so no template falls back to the biome palette.
5. Every template gets a part-built fallback in `TowerBiomeAssets` until it is imported (`TowerKitProps.Has(name)`). **Rebuild and recount after import:** a kit mesh's clearance box is the whole template per colour role, so the tall pieces (the Lectern spire, the armillary, the Engine, the dome, the Telescope, the rings) reach lanes that the fallback never did (Corrupted lesson 1).
6. **Uploading a kit creates permanent Roblox assets: ask the user before each upload.** On a yes: upload the FBX, insert it, run `tests/studio-tower-biome-kit-import.luau`, and ask the user to save the place.

### 5.5 Lessons from Floors 1–40 (each came from a real fix)

1. **Clearance removes a whole prop group if one part fails, silently.** Count every floor's set pieces after each build (`studio-verify.luau`). Fix a removed piece by moving or turning it, **never** by raising it on a plinth.
2. **Big kit meshes have big boxes.** The Lectern spire, the Sun-Lectern's armillary, the Index Engine, the Athenaeum dome, the Great Telescope and the azimuth rings are the riskiest pieces here: split them into parts and spec-check each footprint offline before Studio.
3. **Natural, not stacked.** Shelves, statues and lamp-posts stand on `groundY` of their isle, with rubble, pages and dust at the foot. Never stand a spire on a block. Use round `Shapes`, not square plinths.
4. **No fake bridges.** Where two terraces have no link (Floor 42's Perihelion Court to the Sun, Floor 43's rifts away from the shards and pinches, Floor 44's ward walls away from the Waygates, Floor 45's Rift away from the sutures and the Overlook toward the dais), the gap must read as impassable. No orbit rail, chain or shelf may look walkable across it.
5. **No flat semi-transparent boxes** for glass, glow, light shafts, ward-walls, the Rift or the sky. Use sculpted meshes, texture-scrolled surfaces, particles and invisible `PointLight` anchors.
6. **Never blocky materials** (`Brick`, `WoodPlanks`) on terrain.
7. **Check pitch signs** on toppled shelves, tilted desks, chains, page falls and the Telescope's tube, so nothing slopes the wrong way or floats.
8. **Terrain terraces on multiples of 4.** Only decks sit at other heights.
9. **Overheads versus the camera:** armillary rings, orbit rails, rune-chains, the dome and the Telescope stay ≥ 18 studs clear over walk surfaces and never overhang the Floor 45 arena.
10. **Small clutter is non-collidable** (`CanCollide`, `CanQuery` and `CastShadow` all false), and grounding raycasts include `workspace.Terrain` with `IgnoreWater = true`.
11. **≤ 24 lights per floor.** Count after every build. Index Lamps are mostly `Neon` with no light; only the route's key lamps carry a `PointLight`.
12. **Perimeter props go at the foot of the walls, never on the cliff** (`wallFoot`, Floor 31). On the floating floors there is little wall: the far stacks belong to the Starfield layer, not the room.
13. **Explicit-height pieces must be pinned** `OnTerrain` or listed in `AirborneKinds` (Floor 31): lamps, chained slabs, rails, planets, rings.
14. **Stale terrain in Studio captures** (Floor 36): after a probe rebuild, set `workspace.CurrentCamera.CFrame` in `execute_luau`, wait ~6 s, then capture with no camera arguments, before judging terrain from a screenshot. Floor origins are `X = 12000 + ((id − 1) % 10) × 2400`, `Z = 12000 + floor((id − 1) / 10) × 2400`, `Y = 1000` (Floor 41 = 12000, 1000, 21600), not the formula in `studio-verify.luau`.

### 5.6 The Conjunction (client-only)

- One client module (`StarterPlayerScripts/Rendering/Conjunction.luau`) that runs **only** while the local player is on Floors 41–45.
- Synchronised from `workspace:GetServerTimeNow()`, so every player sees the same sweep with zero remotes. The cycle tightens from about 16 s on Floor 41 to about 6 s on Floor 45.
- On each sweep, acting on `CollectionService`-tagged parts and emitters with strict instance caps: pass a soft band of starlight across the floor (a texture-scrolled sky decal, not a moving part), light tagged star-glyphs and constellation lines in order (Neon), brighten the Index Lamps, lift and settle tagged page emitters, play one far chime (and on 43–45 the low Rift note from the nearest rift), and add a small bloom nudge (`+0.05..0.1`, never a screen flash). On 45 the sweep bends toward the rift-eye and the pages lean into it.
- **Zero gameplay effect.** At the lowest Graphics quality only the glyph wash runs.

### 5.7 Telegraph readability

Enemy telegraphs are crimson `(255, 25, 55)` and orange `(255, 95, 40)`. The Relic Rain event's meteor warning is a **3 s purple disc** on a ramp (GDD §3.3). The Archives' glows must compete with neither:
- Glows stay pale starlight gold (hue 42°–52°, saturation ≤ 0.5), indigo, or silver-white. **No red or orange anywhere in a camp or on the Floor 45 dais.** A saturated gold reads orange from the gameplay camera: keep it pale.
- **Void violet stays off walk surfaces:** it lives in rift beds, the sky and far layers only, never on a terrace, ramp or bridge deck, so a Relic Rain disc always reads.
- Keep camp centres and the dais floor dark and uncluttered (lapis, flagstone, star-map inlay). Star-glyph inlay stays faint on camp floors so it doesn't break up ground telegraph discs.
- Check that the Glyph Warden's `WARD` shield still reads against the star-glyph glow, and adjust the glow rather than the effect.
- In playtest, check that every telegraph reads at gameplay camera height: Rune Mite bites, Astral Scribe bolts (their floor corridor warning especially, over star-glass), Archive Executor arcs and ground areas, and the Rift Warden's Astral Sweep, Dimensional Rupture and Void Well.
- **The floating floors add one more:** a projectile corridor warning drawn over a bridge must stay visible against the void beneath it. Check the Scribe's corridor on a `STARGLASS` bridge.

### 5.8 Performance

- **Instance, don't model.** Reuse MeshIds across isles. Ground cover (page drifts, star-moss, dust, small tomes) uses multi-clump meshes with `CastShadow`, `CanCollide` and `CanQuery` off, tagged `TowerDetail` so the culler hides them past about 220 studs or at low quality. Landmarks are never culled.
- Lights ≤ 24 per floor. Particle emitters ≤ 12 on Floors 41–43 and ≤ 16 on Floors 44–45, all pooled and quality-scaled. The Starfield, the torn sky, the rift-eye and the Nebula Floor's starfield are single meshes with scrolling textures, not particle walls.
- Isle undersides are the new cost: keep each `Float` underside to one terrain body plus at most one crystal-tip mesh.
- Targets: ≥ 45 FPS in full camp fights on Floors 41–45 and ≥ 40 FPS in the Floor 45 boss fight at the lowest Graphics quality (MicroProfiler). Report the numbers in each PR.

### 5.9 Data and saves

Layouts are not persisted. No profile schema change and no `DataManager.SyncProfile` migration.

---

## Part 6: Process, tests and docs

### Per floor (lowest first, one PR each)

1. **Ask for the floor's guide image** (skill step 2) and update that floor's section here with what you take from it and what you leave out.
2. Branch `feat/astral-archives-floor-<N>` from `origin/main`.
3. Layout (`AUTHORED[N]`, from Appendix A). Re-run the Studio validation probe from the header after any change.
4. Kit (reuse, then Blender), set pieces, terrain and lighting grade.
5. Tests and docs (below). Run the suites.
6. Studio verification (`studio-verify.luau`): probe build `Builder.Build(N, ...)`. The pass bar: no new `Validate` problems; every spawn and portal grounded; every link walkable both ways; every set piece present; ≤ 24 lights. Take screenshots from the arrival, from the Apex and of each landmark, compare them with the guide image and the neighbouring floors, and show the user. Then clean up the probe terrain, `workspace.TowerRooms` and the probe folders. Never use `ChangeHistoryService:Undo` to revert.
7. `git fetch origin`, merge `origin/main` (use `git merge-file --diff3 --diff-algorithm=histogram` on conflicts, then check every junction where two floors' tables meet), commit `feat(tower): author Astral Archives floor N (<Name>)`, and open the PR into `main`.

Sunken Sanctuary Floors 36–40 and Thunder Highlands 27–30 may land at the same time and touch the same shared code (`AUTHORED`, `TowerTerrain.Surfaces`, `TowerRoomBuilder`'s natural-room list, `TowerBiomeKit`, `HubLighting.FloorGrades`, `docs/TOWER_NAVIGATION.md`). Merge `origin/main` often. Floor 43 and 45 both need `Terrain.Rifts`: build it with Floor 43 and reuse it.

### Tests

```bash
pwsh tests/run.ps1
```

(On a Mac without `pwsh` or the Luau CLI, port the runner as described in the project memory, and ask before downloading the CLI.) Extend:
- `tower-layout-variants.spec.luau`: for each floor, a "Floor N is the hand-authored ..." test (key, name, `Size`, links and kinds, the camp count, and the floor's defining rule from its **Spec asserts** above) and a "Floor N's terrain is the walking surface" test. Add the ladder test: across 41–45, room area, room height, terraces, links, height levels and Apex Y strictly increase, every floor beats Floors 1–40 at its index, no two terraces on a floor share a height, and no terrain terrace is off the 4-stud grid.
- `tower-patrols.spec.luau`: Floors 43–45's authored patrols resolve, stay on walkways and loop in under 240 s.
- `tower-portals.spec.luau`: the portal spots are grounded on every Apex, and no landmark footprint covers them.
- `tower-biome-kit.spec.luau`: every new template exists, stands on its origin and uses known roles. `FloorGrades[41..45]` exist. `HALCYR` and `RIFTWARD` use no `BlockyMaterials` and no Fungal-owned materials.
- Regression: Floors 1–40 and 46–50 unchanged.

### Docs (same PR as each floor)

- `docs/GAME_DESIGN.MD` §3.3: the floor's bullet under hand-authored floors. With Floor 41, also add a short paragraph on the Halcyr, the Index, the Rift, the Conjunction and the Index Lamps.
- This file: the floor's status line, plus anything that changed in the build.
- `docs/TOWER_NAVIGATION.md`: any new terrain option or bridge style (`Float`, `Scarp`, `Rifts`, `STARGLASS`, `ORBIT`, `SHARD`, `WAYGATE`, `SUTURE`).
- `reference/infinite_towers_biomes.md` §9: with Floor 41, a short paragraph on the Halcyr, the star-quill and the Conjunction.

### Studio checklist for the user (end of each floor's PR)

1. Arrive out of aggro on the Basin. Walk every route to the Apex: no invisible gaps, no blocky steps, nothing floating that shouldn't, nothing on a walkway.
2. **Floor 41:** see the Quill from the Index Gate. Walk the shaft, the vane and the Inkwell line. Step off an isle on purpose and walk back from the Nebula Floor by a return ramp.
3. **Floor 42:** confirm the Sun can't be reached from Perihelion Court. Step in through a moon and through Atlas or Almanac, and enter the Sun from both sides.
4. **Floor 43:** see the tilt from the arrival. Cross each rift on a shard and round each pinch.
5. **Floor 44:** confirm the dome shows over both ward walls from the arrival. Confirm each ward can only be crossed at its Waygate, and reach the Sealed Stacks by both stairs.
6. **Floor 45:** see the Rift end to end from the arrival. Cross all three sutures. Summon the **Rift Warden** and check that Astral Sweep, Dimensional Rupture and Void Well stay on the dais and read clearly, that the Telescope and dome never cover the camera in the fight, and that Ascend (to Floor 46) and Rerun rise clear.
7. Telegraphs read against the gold and indigo glows, and a Relic Rain disc reads on every bridge style.
8. The Conjunction matches across clients, builds from Floor 41 to 45, never flashes, and stops on leaving the biome.
9. Squad follow and recall (`E`) work across every star-glass bridge, orrery arm, shard span, Waygate and suture.
10. Frame rate at the lowest Graphics quality: ≥ 45 FPS in camp fights and ≥ 40 FPS in the Rift Warden fight.

## Out of scope

- Other biomes (Floors 1–40 and 46–50 stay unchanged).
- Teleporting portals as links, new enemies, boss moves, extra mobs for bigger rooms, fall damage or void hazards that deal damage (the Nebula Floor only catches you), and Conjunction effects on combat.
- Changes to rewards, relic drops, mob stats, camp respawn timing or the tower difficulty curve.

## Status

- 2026-11-23: plan written and the Part 3 layouts validated in Studio (0 `Validate` problems on all five floors; walks 1.94× / 1.85× / 1.86× / 1.94× / 1.89×; every patrol under 240 s).
- 2026-11-24: all five guide images imported (`reference/Astral Archives 41..45.jpg`), all five Blender kits generated (87 templates across `tools/blender/generate_astral_f41..45_kit.py`) and imported into `ServerStorage.TowerBiomeKit`, `AUTHORED[41..45]` layouts authored, `HALCYR`/`RIFTWARD` terrain surfaces + `Float`/`Scarp`/`Sheer`/`Rifts` + all five `BridgeStyles` (`STARGLASS`, `ORBIT`, `SHARD`, `WAYGATE`, `SUTURE`) implemented, `HubLighting.FloorGrades[41..45]` added, `AstralFloor41..45` set-piece modules wired into `TowerBiomeAssets`, client-only `Conjunction.luau` ambience implemented, and all automated test suites & docs updated.

---

## Appendix A: validated `AUTHORED` skeletons

Layout fields only, exactly as validated on 2026-11-23. Each floor's PR adds `PathStyle`, `Names` and the full `Terrain = {...}` (with `Direct = true`, `Surface`, `Shapes`, `Bridges`, `BridgeStyles` and the floor's new options) around these. `Terrain.Decks` lists the deck terraces the grid check expects.

```lua
[41] = {
	Key = "astral:1", Name = "Starlit Vestibule",
	Size = { Width = 600, Depth = 620, Height = 225, Bottom = -4 },
	Basin = { X = 0, Y = 0, Z = 165, Width = 568, Depth = 96 },
	WestGallery = { X = -190, Y = 8, Z = 25, Width = 84, Depth = 72 },
	EastGallery = { X = 190, Y = 12, Z = 30, Width = 84, Depth = 72 },
	Crossing = { X = 0, Y = 24, Z = -85, Width = 76, Depth = 60 },
	ExtraPlatforms = {
		Catalogue = { X = 95, Y = 6, Z = -35, Width = 64, Depth = 52 },
		Shaft = { X = -95, Y = 16, Z = -20, Width = 64, Depth = 56 },
		Barb1 = { X = -215, Y = 20, Z = -100, Width = 60, Depth = 52 },
		Barb2 = { X = -130, Y = 26, Z = -170, Width = 60, Depth = 52 },
		Barb3 = { X = -30, Y = 32, Z = -235, Width = 60, Depth = 52 },
		NibLanding = { X = 80, Y = 28, Z = -140, Width = 64, Depth = 56 },
		Blotter = { X = 210, Y = 30, Z = -60, Width = 60, Depth = 52 },
	},
	Apex = { X = 175, Y = 36, Z = -225, Width = 112, Depth = 84 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "EastGallery" }, { "Basin", "Catalogue" },
		{ "WestGallery", "Shaft" }, { "Shaft", "Crossing" }, { "Crossing", "NibLanding" }, { "NibLanding", "Apex" },
		{ "Shaft", "Barb1" }, { "Barb1", "Barb2" }, { "Crossing", "Barb2" }, { "Barb2", "Barb3" }, { "Barb3", "Apex" },
		{ "Catalogue", "Crossing" }, { "Catalogue", "EastGallery" }, { "EastGallery", "Blotter" }, { "Blotter", "Apex" },
		{ "Blotter", "NibLanding" },
	},
	Stairs = { NibLanding_Apex = true },
	Terrain = { Decks = { Sanctuary = true, Catalogue = true, Barb2 = true, Blotter = true } },
},
[42] = {
	Key = "astral:2", Name = "Orbiting Stacks",
	Size = { Width = 660, Depth = 680, Height = 250, Bottom = -4 },
	Basin = { X = 0, Y = 0, Z = 195, Width = 628, Depth = 100 },
	WestGallery = { X = -200, Y = 8, Z = 20, Width = 88, Depth = 76 },
	EastGallery = { X = 200, Y = 12, Z = 20, Width = 88, Depth = 76 },
	Crossing = { X = 0, Y = 16, Z = 80, Width = 76, Depth = 60 },
	ExtraPlatforms = {
		MoonSW = { X = -100, Y = 18, Z = 20, Width = 60, Depth = 52 },
		MoonSE = { X = 100, Y = 20, Z = 20, Width = 60, Depth = 52 },
		MoonW = { X = -260, Y = 22, Z = -80, Width = 56, Depth = 48 },
		MoonE = { X = 260, Y = 24, Z = -80, Width = 56, Depth = 48 },
		OuterNW = { X = -200, Y = 26, Z = -230, Width = 64, Depth = 52 },
		OuterNE = { X = 200, Y = 28, Z = -230, Width = 64, Depth = 52 },
		MiddleW = { X = -170, Y = 32, Z = -110, Width = 64, Depth = 56 },
		MiddleE = { X = 170, Y = 36, Z = -110, Width = 64, Depth = 56 },
		Aphelion = { X = 0, Y = 40, Z = -270, Width = 64, Depth = 52 },
	},
	Apex = { X = 0, Y = 44, Z = -70, Width = 124, Depth = 92 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "EastGallery" }, { "Basin", "Crossing" },
		{ "WestGallery", "MoonW" }, { "MoonW", "OuterNW" }, { "OuterNW", "Aphelion" }, { "Aphelion", "OuterNE" },
		{ "OuterNE", "MoonE" }, { "MoonE", "EastGallery" },
		{ "MoonSW", "MiddleW" }, { "MoonSE", "MiddleE" }, { "OuterNW", "MiddleW" }, { "OuterNE", "MiddleE" },
		{ "MiddleW", "Apex" }, { "MiddleE", "Apex" },
		{ "WestGallery", "MoonSW" }, { "MoonSW", "Crossing" }, { "EastGallery", "MoonSE" }, { "MoonSE", "Crossing" },
	},
	Stairs = { MiddleW_Apex = true, MiddleE_Apex = true },
	Terrain = { Decks = { Sanctuary = true, MoonSW = true, MoonW = true, OuterNW = true } },
},
[43] = {
	Key = "astral:3", Name = "Fractured Index",
	Size = { Width = 720, Depth = 750, Height = 280, Bottom = -6 },
	Basin = { X = 0, Y = 0, Z = 230, Width = 688, Depth = 96 },
	WestGallery = { X = -220, Y = 16, Z = 70, Width = 88, Depth = 76 },
	EastGallery = { X = 200, Y = 8, Z = 75, Width = 88, Depth = 76 },
	Crossing = { X = -20, Y = 12, Z = 85, Width = 84, Depth = 64 },
	ExtraPlatforms = {
		ShardA = { X = -100, Y = 18, Z = 5, Width = 56, Depth = 48 },
		ShardE = { X = 190, Y = 10, Z = -10, Width = 56, Depth = 48 },
		P2W = { X = -210, Y = 28, Z = -80, Width = 72, Depth = 60 },
		P2C = { X = -40, Y = 24, Z = -75, Width = 72, Depth = 60 },
		P2E = { X = 180, Y = 20, Z = -95, Width = 72, Depth = 60 },
		ShardB = { X = -110, Y = 30, Z = -165, Width = 56, Depth = 48 },
		P3C = { X = 20, Y = 36, Z = -175, Width = 72, Depth = 60 },
		P3E = { X = 240, Y = 32, Z = -185, Width = 72, Depth = 60 },
		ShardC = { X = 140, Y = 40, Z = -245, Width = 56, Depth = 48 },
		Engine = { X = 250, Y = 44, Z = -300, Width = 64, Depth = 52 },
		P4C = { X = 60, Y = 48, Z = -305, Width = 72, Depth = 56 },
	},
	Apex = { X = -210, Y = 52, Z = -285, Width = 132, Depth = 96 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "Crossing" }, { "Basin", "EastGallery" },
		{ "WestGallery", "Crossing" }, { "Crossing", "ShardA" }, { "ShardA", "P2C" }, { "ShardA", "P2W" },
		{ "EastGallery", "ShardE" }, { "ShardE", "P2E" }, { "WestGallery", "P2W" }, { "P2W", "P2C" }, { "P2C", "P2E" },
		{ "P2W", "ShardB" }, { "P2C", "ShardB" }, { "ShardB", "P3C" }, { "ShardB", "Apex" },
		{ "P3C", "ShardC" }, { "ShardC", "P4C" }, { "P4C", "Apex" }, { "P2E", "P3E" }, { "P3E", "Engine" }, { "P3C", "P3E" },
	},
	Stairs = { ShardB_Apex = true },
	Patrols = {
		WEST_PLATES = { "WestGallery", "P2W", "P2C" },
		RIFT_CROSSING = { "Crossing", "ShardA", "P2C" },
		EAST_PLATES = { "EastGallery", "ShardE", "P2E" },
		UPPER_ROW = { "ShardB", "P3C", "P3E" },
	},
	ReplacePatrols = true,
	Terrain = { Decks = { Sanctuary = true, ShardA = true, ShardE = true, ShardB = true, ShardC = true } },
},
[44] = {
	Key = "astral:4", Name = "Runeguard Athenaeum",
	Size = { Width = 800, Depth = 795, Height = 305, Bottom = -6 },
	Basin = { X = 0, Y = 0, Z = 230, Width = 768, Depth = 104 },
	WestGallery = { X = -290, Y = 12, Z = 70, Width = 92, Depth = 80 },
	EastGallery = { X = 250, Y = 16, Z = 70, Width = 92, Depth = 80 },
	Crossing = { X = -90, Y = 8, Z = 85, Width = 88, Depth = 68 },
	WestBastion = { X = -270, Y = 32, Z = -110, Width = 92, Depth = 82 },
	EastBastion = { X = 260, Y = 36, Z = -120, Width = 92, Depth = 82 },
	ExtraPlatforms = {
		Lodge = { X = 100, Y = 4, Z = 95, Width = 64, Depth = 52 },
		Loft = { X = 40, Y = 18, Z = 15, Width = 60, Depth = 48 },
		Gate1 = { X = -130, Y = 20, Z = -15, Width = 64, Depth = 48 },
		Forge = { X = 110, Y = 24, Z = -60, Width = 64, Depth = 52 },
		Hall = { X = -10, Y = 28, Z = -90, Width = 88, Depth = 64 },
		LanternWalk = { X = -130, Y = 40, Z = -165, Width = 64, Depth = 52 },
		Gate2 = { X = 140, Y = 44, Z = -195, Width = 64, Depth = 48 },
		Reliquary = { X = -200, Y = 48, Z = -290, Width = 64, Depth = 52 },
		Seals = { X = 30, Y = 52, Z = -300, Width = 72, Depth = 60 },
		Vault = { X = -60, Y = 56, Z = -320, Width = 64, Depth = 52 },
	},
	Apex = { X = 230, Y = 60, Z = -300, Width = 140, Depth = 100 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "Crossing" }, { "Basin", "WestGallery" }, { "Basin", "EastGallery" },
		{ "Basin", "Lodge" }, { "Lodge", "Loft" }, { "Loft", "Crossing" }, { "Lodge", "EastGallery" },
		{ "Crossing", "Gate1" }, { "WestGallery", "Gate1" }, { "Gate1", "Hall" }, { "Gate1", "WestBastion" },
		{ "WestBastion", "LanternWalk" }, { "Hall", "LanternWalk" }, { "Hall", "Forge" }, { "Forge", "EastBastion" },
		{ "Hall", "Gate2" }, { "EastBastion", "Gate2" }, { "Gate2", "Apex" }, { "Gate2", "Seals" },
		{ "Seals", "Vault" }, { "Seals", "Apex" }, { "Vault", "Reliquary" },
	},
	Stairs = { Gate2_Apex = true, Seals_Apex = true },
	Patrols = {
		OUTER_WARD = { "WestGallery", "Gate1", "Crossing" },
		WEST_GATE = { "Gate1", "WestBastion", "LanternWalk" },
		MIDDLE_WARD = { "LanternWalk", "Hall", "Forge", "EastBastion" },
		EAST_GATE = { "EastBastion", "Gate2", "Seals" },
		INNER_WARD = { "Seals", "Apex", "Gate2" },
	},
	ReplacePatrols = true,
	Terrain = { Decks = { Sanctuary = true, Loft = true, Gate1 = true, Gate2 = true } },
},
[45] = {
	Key = "astral:5", Name = "Rift Warden's Observatory",
	Size = { Width = 900, Depth = 795, Height = 350, Bottom = -6 },
	Basin = { X = 0, Y = 0, Z = 236, Width = 868, Depth = 104 },
	WestGallery = { X = -300, Y = 8, Z = 80, Width = 92, Depth = 80 },
	EastGallery = { X = 300, Y = 10, Z = 10, Width = 92, Depth = 80 },
	Crossing = { X = -60, Y = 12, Z = 100, Width = 88, Depth = 68 },
	WestBastion = { X = -330, Y = 32, Z = -80, Width = 92, Depth = 82 },
	EastBastion = { X = 300, Y = 40, Z = -150, Width = 92, Depth = 82 },
	ExtraPlatforms = {
		Fallen = { X = 180, Y = 4, Z = 120, Width = 64, Depth = 52 },
		Ink = { X = -165, Y = 16, Z = 85, Width = 56, Depth = 48 },
		Lectern = { X = -170, Y = 20, Z = -10, Width = 64, Depth = 52 },
		Proof = { X = 50, Y = 22, Z = 55, Width = 60, Depth = 48 },
		SutureMid = { X = 40, Y = 26, Z = -20, Width = 56, Depth = 48 },
		Overlook = { X = -60, Y = 30, Z = -95, Width = 64, Depth = 52 },
		Lens = { X = 150, Y = 36, Z = -60, Width = 72, Depth = 60 },
		SutureW = { X = -230, Y = 42, Z = -165, Width = 56, Depth = 48 },
		Orrery = { X = 340, Y = 46, Z = -300, Width = 64, Depth = 52 },
		RiftLipW = { X = -300, Y = 48, Z = -250, Width = 64, Depth = 56 },
		WestAnchor = { X = -205, Y = 56, Z = -235, Width = 64, Depth = 56 },
		EastAnchor = { X = 215, Y = 60, Z = -235, Width = 64, Depth = 56 },
	},
	Apex = { X = 0, Y = 68, Z = -225, Width = 204, Depth = 152 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "Crossing" }, { "Basin", "Fallen" },
		{ "Fallen", "EastGallery" }, { "WestGallery", "Ink" }, { "Ink", "Crossing" }, { "Crossing", "Lectern" },
		{ "WestGallery", "WestBastion" }, { "Lectern", "WestBastion" }, { "Crossing", "SutureMid" },
		{ "Fallen", "Proof" }, { "Proof", "SutureMid" }, { "SutureMid", "Lens" }, { "SutureMid", "Overlook" },
		{ "WestBastion", "SutureW" }, { "SutureW", "RiftLipW" }, { "RiftLipW", "WestAnchor" }, { "WestAnchor", "Apex" },
		{ "EastGallery", "EastBastion" }, { "Lens", "EastBastion" }, { "EastBastion", "EastAnchor" },
		{ "Lens", "EastAnchor" }, { "EastBastion", "Orrery" }, { "Orrery", "EastAnchor" }, { "EastAnchor", "Apex" },
	},
	Stairs = { WestAnchor_Apex = true, EastAnchor_Apex = true },
	Patrols = {
		WEST_BANK = { "WestGallery", "Ink", "Crossing", "Lectern" },
		MID_SUTURE = { "Crossing", "SutureMid", "Lens" },
		WEST_HORN = { "WestBastion", "SutureW", "RiftLipW", "WestAnchor" },
		EAST_HORN = { "EastGallery", "EastBastion", "EastAnchor" },
		EAST_CREST = { "EastBastion", "Orrery", "EastAnchor" },
		ANCHOR_RING = { "WestAnchor", "Apex", "EastAnchor" },
	},
	ReplacePatrols = true,
	Terrain = { Decks = { Sanctuary = true, EastGallery = true, Proof = true, SutureMid = true, Overlook = true, SutureW = true, Orrery = true } },
},
```
