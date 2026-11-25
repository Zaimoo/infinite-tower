# Prompt: Abyssal Throne — a Unique Layout for Every Floor (Floors 46–50)

Copy everything below the line into a Claude Code session opened at the repo root, or follow it with the `biome-floor-redesign` skill (`.claude/skills/biome-floor-redesign/SKILL.md`), which is the procedure this plan plugs into.

> **Written 2026-11-25.** Nine biomes are authored on `main` (Floors 1–45): Verdant Ruins, Fungal Hollow, Ashen Dunes, Frozen Citadel, Infernal Foundry, Thunder Highlands, Corrupted Grove, Sunken Sanctuary and Astral Archives (`origin/main` at `2018a84`). Floors 46–50 are the last floors still on the seeded generic layout. This brief builds on all nine floor prompts, and treats the **Astral Archives floors as built on `main`** (not as planned) as the bar to beat.
>
> **The escalation rule (from the Infernal plan, Part 2):** every floor is richer, taller and more varied than the one below it, and than every earlier floor at the same position in its biome. The Abyssal Throne beats the built Astral floors at each index on room area, room height, terraces, links, height levels and Apex height. It is the tower's last biome, so Floor 50 is the largest room in the tower.
>
> **The compact-grand pacing rule (Floor 25, kept by the Sunken and Astral plans):** grow upward and inward. Depth stays capped at `795` studs. Keep the shortest walk to the Apex **at or under about 2× the canonical layout**. Floor 44 shipped at 2.23×; don't use that as licence. Three first ideas were pulled in to meet the cap (§3.6).
>
> **The guide-image gate:** before building any floor, ask the user for that floor's guide image (skill step 2). The image sets mood, shapes and landmarks. Treat it as inspiration, never copy it 1:1, and keep the runtime rules below. Update the floor's section of this file with what you took from the image and what you left out before you build. There is no biome-wide concept art yet; if the user has one, save it as `reference/Abyssal Throne.<ext>` and record what it sets here.
>
> **The layout half is already proven:** every coordinate table in Part 3 was run on 2026-11-25 through the real `TowerLayout` module from `origin/main` (`2018a84`), using the official Luau CLI (0.743) with `Color3`, `Vector3` and `Enum.Material` stubbed. The five entries were spliced into a scratch copy, and the check ran `Layout.ForFloor`, `Layout.Validate` (counting only problems the canonical layout doesn't already have), `Layout.PatrolRoutes`, `Layout.PortalSpots` and `PatrolPath.LoopLength`.
> - **Results:** **zero** new validation problems on all five floors and no build asserts.
> - **Links and terraces:** every link at or under `14.86°`, every terrain terrace on the 4-stud grid, no two terraces at the same height, every platform reachable from the Sanctuary.
> - **Camps and patrols:** mob and Elite totals on contract (`16/22/25/35/35`, `1/2/3/4/4`), and every patrol under 240 s (the longest is 185.7 s).
>
> Re-run the check after any coordinate change: the exact skeletons are in **Appendix A** and the probe in **Appendix B**. Copy them from there, not from memory. Studio's `TowerLayout` is Rojo-synced from the same file, so a Studio probe gives the same answers.

---

## Role

You are a two-specialist team speaking as one. Say which role is speaking when it matters.

**Vaultwright** is a senior level designer and gameplay engineer for *Infinite Towers: Become a Master!*, a Roblox squad-command action RPG. Vaultwright owns:
- topography, sightlines, combat space, pacing and navigation;
- the `TowerLayout` connector contract.

They think in walkable surfaces, link slopes, landings, camp spacing, leash radii, and the route a squad of five takes from the Sanctuary to the Apex.

**Veilwright** is a senior environment artist and world-builder. Veilwright owns the Vahl and their court, the Undertow, the chains, the Wardlights, the obsidian and iron, the crimson silk, the void and the Dirge. They build from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the earlier biomes were built. Every prop has a reason to be in the abyss and reads clearly from the gameplay camera. Veilwright makes every floor a visible step up from the one below it, and makes Floor 50 the most imposing place in the tower.

Neither of you breaks the runtime contracts described below.

## Before you start

1. `git fetch origin` and branch each floor from `origin/main` as `feat/abyssal-throne-floor-<N>`. Work in the main checkout, because Rojo syncs from there. Use conventional commits and **one PR per floor. Never stack PRs.** This repo keeps head branches after a merge, so a stacked PR merges into its parent branch and never reaches `main`.
2. Follow `CLAUDE.md`, `AGENTS.md` and the `biome-floor-redesign` skill. Use the `roblox-world-building`, `roblox-luau`, `roblox-studio-mcp`, `roblox-npc-ai` and `roblox-performance` skills.
3. Read these docs:
   - `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, the authored floors; the floor names), §3.6 (lighting) and §5.2 (the Abyssal Throne roster and the Crimson Overlord's moves).
   - `docs/TOWER_NAVIGATION.md`, including "Authored terrain walkways".
   - `reference/infinite_towers_biomes.md` §10 (Abyssal Throne).
   - `docs/tower-mob-remodel-plan.md` §5.10 (the Abyssal visuals): blackened iron, crimson silk and void light; glow crimson with void purple; shares the raid bosses' visual language.
4. Read the earlier floor prompts, newest first: Astral, Sunken, Corrupted, Thunder, Infernal, Frozen, Ashen, Fungal, Verdant. Read their status notes and lessons, especially:
   - the Astral floors as built (`Float` isles, `Scarp`, `Rifts`, the five bridge styles, `VoidCatchY` void-fall recovery);
   - the Corrupted status log (kit clearance boxes, `OnTerrain` pinning, `wallFoot`);
   - the Sunken status log (`Sheer` aprons, `Pools[i].Round`, bridge styles).

   Then run `git log --oneline -- src/ServerScriptService/Core/Tower*.luau src/ReplicatedStorage/Shared/Config/TowerLayout.luau` and read the `fix(...)` commits.
5. Read the authored-floor code end to end:
   - **`TowerLayout.luau`:** `AUTHORED[36..45]`, which use the Fungal-style `Terrain = {...}` system this biome uses; `build`, `Validate`, `PatrolRoutes`, `Lanes` and `PortalSpots`.
   - **`TowerTerrain.luau`:**
     - `Palettes.abyssal_throne`: Basalt ground, Slate, and `Liquid = CrackedLava`, which **this biome must not use**: §5.3.
     - `Surfaces`, `MaterialColors`, `FungalMaterials` and `BlockyMaterials`.
     - The shape and pool options: `Terrain.Shapes` (with `Float`, `Scarp` and Sunken's `Sheer`), `Pools`, `Islands`, `Ridges`, `Rifts` and `Bridges`.
   - **`TowerRoomBuilder.luau`:**
     - Decks, `RoundDecks`, `DeckThickness`, bridges, stairs and curbs, and the `BridgeStyles` the Sunken and Astral floors added.
     - Open-sky versus vaulted rooms (`isNatural`, about line 530). **`abyssal_throne` is not in it** (§5.1).
     - `VoidCatchY`, which `TowerFloorService` and `CombatSimulation` already use to put fallen players and heroes back at the Sanctuary.
   - **`TowerBiomeAssets.luau` and `TowerSetPieces/`:**
     - The shared helpers: `piece`, `group`, `kitAt`, `onTerrain`, `groundY`, `wallFoot` and `AirborneKinds`.
     - The current `abyssal_throne` branches: the backdrop `spire` (about line 734), the `ChainedSpire` beside the Crossing (about line 1013), and the sub-floor `AbyssalTealMist` sea (about line 770).
     - The `AstralFloor4x.luau` modules, as the newest models.
   - **`TowerBiomeKit.luau` and `TowerKitProps.luau`:** `ExtraTemplates`, `Biomes.abyssal_throne` (`BlightTree`, `ObsidianSpire`, `VoidShards`), `Ecology.abyssal_throne`, `Has` and `Ready`, and the Sunken `HangingAbyssChain` and `AbyssReliquaryShrine` templates, which are reusable here.
   - **`HubLighting.luau`:** `BiomeGrades[10]` (violet void) and `FloorGrades` (Floors 41–45 are the newest).
   - **`RelicConfig.luau`:** the `THRONE` skins.
   - **`.claude/skills/biome-floor-redesign/references/studio-verify.luau`.**

## The goal

The five Abyssal Throne floors (46–50) still use the seeded generic layout and the generic Abyssal props:
- `ObsidianSpire` groves, `BlightTree` slopes and `VoidShards` clutter;
- a backdrop spire and a chained spire;
- a teal sub-floor mist.

Give each one its own hand-authored topography, built around one ecosystem, so each floor has a different shape, route and combat rhythm and reads differently from its neighbours. Every other floor stays byte-identical. The floor names are already fixed by the GDD (§3.3) and `TowerFloorConfig`: **Abyssal Descent, Crimson Procession, Voidspan Crossing, Dreadguard Citadel, Overlord's Throne**.

This is the tower's summit, and it is underground. Every earlier biome had a sky; the Archives were a sky. Here the "sky" is the underside of everything: a black, starless vault with the Rift a thin pale wound high overhead on Floor 46, closing floor by floor until on Floor 50 the only light above the Throne is the **Crimson Eclipse**. Two ideas drive the biome:
- **Everything here is drawn toward the Throne.** The rivers of dark energy (the **Undertow**) run *uphill* toward it, chains lean toward it, ash drifts toward it, and the Wardlights gutter in its direction. The floors read as one slope of the world pouring toward the back of Floor 50.
- **The colour identity fights the telegraphs.** The biome's motif is crimson, and enemy telegraphs are crimson and orange. §5.7 is the most important section in this file. Read it before you pick a single glow colour.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, chain, lamp and creature traces back to this ecosystem. If a prop doesn't fit it, cut it.

### The Vahl and the Warden-King

The **Vahl** were a mortal kingdom on the lip of the Abyss: wardens who swore iron oaths to keep the dark below from climbing out. Their first king, **Vharos the Warden-King**, went down to its bottom to seal it at the source. He built the **Throne** there, and sat it so that the dark would have a master instead of a mouth.

The Throne kept him. His iron plate grew into him. His mantle became the chains of every oath sworn to him. His sword became the crimson light the Throne draws up out of the dark. He is the **Crimson Overlord** now (`ROYAL_COLOSSUS`): crowned, in black-iron plate, a sword of crimson light and an articulated mantle of chains (`docs/tower-mob-remodel-plan.md` §5.10).

The Vahl followed their king down and became his court:
- the **Dreadguard**, his executioners;
- the **Void Hierophants**, his priests;
- the **Void Invokers**, the court's casters;
- the **Abyss Reavers**, its outriders.

They are still holding the dark shut, and still holding everyone else out.

They built in:
- **obsidian** and **blackened iron**;
- **crimson silk** banners, veils and runners (silk, never glow: §5.7);
- **bone-white marble**: the old mortal stone of the Vahl, used only for the oldest works and, by design, for every **walkway trim and flagged trail**, so the route always reads pale against the dark.

Their sigil is the **Chained Crown**: a crown inside a ring of chain with **one broken link**. The broken link is Vharos's own oath, the one that held when the rest of him didn't. It appears on keystones, banners, the Dreadguard's pauldrons and the Throne's backrest.

**One line of continuity:** on Floor 46, the Rift's underside hangs high in the black vault, and pages still flutter down out of it from the Archive above. Among the debris on the Fallstrand, pinned to an obsidian spike near the Sanctuary, is the half-written entry from the Sealed Stacks (Floor 44), the page that read "*unwritten*". One word has since been written on it, in crimson: **Vharos**.

### The Undertow, the Wardlights and the Dirge

The **Undertow** is the Abyss's rivers of dark energy: ribbons of violet void that flow *uphill* toward the Throne.
- On Floor 46 they braid across the floor and pour **upward** into the dark at the **Upfall**.
- On Floor 48 the void they leave behind is so deep the Vahl could only cross it on chains.
- On Floor 50 every ribbon in the room runs into the Throne's base.

They are the biome's water, its lava and its light, and they never touch a walkway.

The Vahl lit their king's road with **Wardlights**: pale bone-white flames in black-iron cages, hung from chains at every waystation. They were lit for the processions that carried oaths down to the Throne. Where the Wardlights burn, the way is open.

| Floor | What the court remembers | What the Wardlights tell you |
| --- | --- | --- |
| 46 | The Descent: where the dark first catches what falls | Lit only on the eyots the Undertow hasn't covered. They lean upstream, toward the Upfall. |
| 47 | The Procession: the road the oaths were carried down | Two rows of lamps, one per column of the procession; where the columns cross, the rows cross. |
| 48 | The Voidspan: the court's crossing of the great void | Lamps hang from the four great chains themselves. The lowest lamp, at the Keystone, burns brightest. |
| 49 | The Citadel: the Dreadguard's fortress | Shuttered on the walls (the guard keeps them dark), lit only on the drawbridges into the keep. |
| 50 | The Throne | Every lamp in the room leans toward the seat. The last two burn on the Throne's hands, either side of the Overlord. |

The biome's through-line, after the Heartroot, Veinweb, Ember Vein, Stillcold, Heartbeat, Tempest Squall, Rotpulse, Tidecall and the Conjunction, is the **Dirge**. On a shared server-time cycle (`workspace:GetServerTimeNow()`):
- a far iron bell tolls once;
- the Undertow surges brighter and faster for a moment, toward the Throne;
- the Wardlights flare and lean, then settle;
- tagged chains draw taut, then slacken;
- loose ash and pages lift and drift toward the back of the room.

It is slow on Floor 46 (a ~16 s toll, nothing answers) and tightens to ~6 s on Floor 50. There, every toll is answered by a deep double beat from inside the Throne: the Overlord's heart (the "Heart of the Crimson Overlord" relic). It is **client-side and purely cosmetic** (§5.6).

### Living layers (use all of them on every floor, more of each the higher you go)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Wardlight & Glow** | Wardlights, bone-white flag trails, the Rift's pale wound, cold silver key light | The signature *walkway* glow is **bone-white and pale silver** (hue 30°–60°, saturation ≤ 0.2). Crimson and void violet never glow on or near a walk surface (§5.7). |
| **Iron & Chain** | Blackened iron gates, cages, braziers, gibbets, capstans, chain-ranks, colossal chains | The biome's skeleton. Chains are kit meshes, never stretched parts. Every chain that looks load-bearing goes somewhere. |
| **Obsidian & Stone** | Obsidian spires and walls, basalt bedrock, bone-white marble trim, the Chained Crown on keystones | One black stone family, one bone-white trim stone, and iron. |
| **Crimson Silk** | Banners, veils, stair runners, the Procession's canopies, the Overlord's colours | **Fabric, matte, never Neon.** Deep wine crimson (about `(118, 22, 36)`), never the telegraph crimson `(255, 25, 55)`. |
| **Undertow** | Void rivers in their beds, the Upfall, the void under the chains | Client-side scrolling-texture meshes over dark basalt beds, ≥ 2 studs below every walk surface (§5.3). |
| **Ash & Bone** | Ash drifts, bone-white rubble, fallen Halcyr pages (46), offerings, oath-tablets | Ground cover. Pages appear only on 46–47, ash on every floor, and thicker the closer to the Throne. |
| **Void** | The black vault, the Rift's closing wound, the Crimson Eclipse (50 only) | Sky and far layers only. |

### Food web (how the enemies fit, `MobCatalog` → `abyssal_throne`)

- **Abyss Reaver** (`WEAPON_BIPED`, Regular: a lean armoured reaver with hooked twin blades and a tattered crimson half-cape; `WEAPON_ARC`): the court's outriders. Near their camps put weapon racks of hooked blades, whetstones, torn half-capes and cut chain.
- **Void Invoker** (`CASTER_BIPED`, Regular: a robed invoker whose hands hold a crackling void orb; `PROJECTILE`): put invocation circles inset in the flags, cracked void-orb cradles and oath-tablets.
- **Void Hierophant** (`CASTER_BIPED`, Support `MEND`: a masked high priest with a tall crown-mitre and a void-light censer): put censer stands, kneeling stools and mitre racks where it stands.
- **Throne Executioner / Alpha** (`HEAVY_BIPED`, Elite/Alpha: a hulking hooded executioner with an oversized axe; the Alpha adds a gilded skull pauldron and a crimson banner; `WEAPON_ARC` / `GROUND_AREA`): the Dreadguard. Put execution blocks, axe-racks, gibbets and chained penitents' cages wherever one stands guard.
- **Crimson Overlord** (`ROYAL_COLOSSUS`, Boss, Floor 50). His moves (GDD §5.1) are **Hellfire Cleave** (`ARC`), **Abyssal Nova** (`SELF_DISC`) and **Doom Pillars** (`TARGET_DISC`).

The relic skins (`RelicConfig` → `THRONE`) are:
- the **Abyssal Trench Geode** (black rock split over blood-red crystal);
- the **Sovereign's Cursed Urn** (a throne-room urn sealed with chains and a crimson sigil);
- the **Void Titan Core** (a shard of the void in an obsidian cage);
- the **Heart of the Crimson Overlord** (the crowned heart).

Echo them in split obsidian geodes on the eyots, sealed urns in the reliquaries, caged void shards on the citadel walls, and on Floor 50 the Throne's own heart showing through a crack in its base.

### Ambient life (client-only, purely cosmetic)

- the Undertow flowing uphill;
- ash drifting toward the Throne;
- Halcyr pages fluttering down out of the Rift (46–47 only);
- Wardlight flames leaning;
- chains swaying and clinking;
- void motes rising from the beds;
- the distant silhouettes of the court on far ledges (still, until the Dirge, when they bow);
- the Rift's wound overhead closing floor by floor;
- on Floor 50, the Crimson Eclipse breathing with the Overlord's heartbeat.

Everything is pooled, culled by distance, scaled by the Graphics quality setting, and off or minimal at the lowest quality. Nothing replicates from the server.

---

## Part 2: The escalation ladder

### 2.1 Layout and scale (validated for the Part 3 coordinates)

| Floor | Room (W × D × H, Bottom) | Area (vs. Astral as built) | Terraces | Links | Height levels | Apex Y | Max slope | Shortest walk (× canonical) | Astral as built (terraces / links / levels / Apex) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 46 | 640 × 640 × 240, −4 | 409,600 (> 372,000) | 14 | 19 | 13 | 40 | 14.79° | 650.1 (2.03×) | 13 / 18 / 12 / 36 |
| 47 | 700 × 700 × 265, −4 | 490,000 (> 448,800) | 16 | 21 | 15 | 48 | 14.81° | 746.9 (2.06×) | 15 / 20 / 14 / 44 |
| 48 | 760 × 760 × 295, −6 | 577,600 (> 540,000) | 18 | 24 | 17 | 56 | 14.81° | 781.0 (1.93×) | 17 / 23 / 16 / 52 |
| 49 | 840 × 795 × 320, −6 | 667,800 (> 636,000) | 19 | 25 | 18 | 64 | 14.86° | 927.0 (2.04×) | 18 / 23 / 17 / 60 |
| 50 | 940 × 795 × 370, −6 | 747,300 (> 715,500) | 21 | 29 | 20 | 72 | 14.81° | 851.4 (1.68×) | 20 / 26 / 19 / 68 |

- *Terraces* counts every platform, including `Sanctuary` and `ExtraPlatforms`.
- *Height levels* counts distinct walk heights among all platforms except `Sanctuary`. On every Abyssal floor no two terraces share a height.
- *Shortest walk* is the Dijkstra distance from the Sanctuary centre to the Apex centre (summing centre → link end, the link's 3D length, and link end → centre) against the canonical layout for the same index measured the same way (321.0 / 362.9 / 404.8 / 455.4 / 506.4). This is the Astral plan's measure.
- The Floor 50 Apex (the Throne's seat) is `212 × 156`, larger than Floor 45's `204 × 152`, the largest in the tower. Floor 50's room is the largest and tallest in the tower.
- **Why `Bottom` is shallow:** the Basin return ramps run from `Bottom − 4` to `0` over a fixed 43-stud run (`build`, `ReturnLinks`), so they stay at or under 15° only while `Bottom ≥ −7`. At `−6` they are 13.1°. The abyss's depth is sold by darkness, the Undertow's glow from below, fog and the black vault, not by a deep `Bottom` (§5.1).

### 2.2 Assets and variety (targets your build must meet, measured by the set-piece census)

The Astral plan's targets are the floor of these numbers.

| Floor | New kit templates | Distinct templates placed | Landmark set pieces | Placed props (excl. ground cover) | Ground cover and small clutter | Tallest landmark | Ambient systems |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 46 | ≥ 11 | ≥ 28 | ≥ 16 | ≥ 420 | ≥ 300 | ≥ 150 studs (the Upfall) | ≥ 8 |
| 47 | ≥ 12 | ≥ 34 | ≥ 18 | ≥ 500 | ≥ 400 | ≥ 170 (the Effigy behind the Bier) | ≥ 9 |
| 48 | ≥ 13 | ≥ 36 | ≥ 20 | ≥ 560 | ≥ 420 | ≥ 200 (the four Anchor Spires) | ≥ 9 |
| 49 | ≥ 14 | ≥ 38 | ≥ 22 | ≥ 640 | ≥ 450 | ≥ 235 (the Dreadguard Keep's tower) | ≥ 10 |
| 50 | ≥ 15 | ≥ 41 | ≥ 25, plus one colossal centrepiece | ≥ 760 | ≥ 520 | ≥ 320 (the Throne's backrest and crown) | ≥ 11 |

**Performance wins a conflict.** If a target and the frame-rate budget in §5.8 disagree, meet the budget and say so in the PR. Never pad a floor with filler to hit a count.

### 2.3 Variety and readability rules (judged in review)

- **No filler.** No single template makes up more than 12% of a floor's placed props (ground cover excluded). Chains, banners and Wardlights are the easiest things to over-scatter: count them.
- **Every terrace is a vignette:** at least 4 distinct prop kinds that say what it was for (reaving post, invocation circle, ossuary, oath-hall, gibbet ledge, armoury, reliquary).
- **Every link is dressed at both ends:** Wardlight posts, iron newels, chain bollards or banner pairs on the terrace, off the lane.
- **Three skyline layers on every floor:**
  - *near*: props, chains and Wardlights on the terraces;
  - *mid*: landmark spires, gates, the Effigy, the keep;
  - *far*: **the Vault**, a black sky-dome with the court's far fortresses and spires on distant ledges. It carries the Rift's wound closing from a pale gash on Floor 46 to a hairline on Floor 49, replaced on Floor 50 by the Crimson Eclipse.
- **Every floor introduces at least one traversal feature and one landmark type that no earlier floor has.** Part 3 names them.
- **Grounded and readable:** density never hides camps, telegraphs, loot or the route. Everything stands on stone or hangs from a chain that goes somewhere. Only ash, pages and motes float, and those are client-only.

---

## Part 3: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north. Y is the walkable top surface. Terrain terraces sit on multiples of 4. Any terrace at another height is a deck (`Terrain.Decks[id] = true`).

**Shapes already taken (45, don't repeat them):**
- **Verdant (1–5):** spine with glades; broken diagonal aqueduct; E–W gorge with three bridges; walled ring with wall-walks; spiral around a cenote.
- **Fungal (6–10):** horseshoe around a pool; switchback up a gallery wall; chasm with a round cap deck and hung bridges; bastion "H" through the Crossing; asymmetric radial spiderweb.
- **Ashen (11–15):** fork around a dune; single switchback; N–S ravine with two ledges and an arch; chokepoint gate and split fortress; route over a fallen giant.
- **Frozen (16–20):** lakeshore road versus floe chain; street lattice; inverted ravine (central spine); two routes in two climates; cathedral nave.
- **Infernal (21–25):** hub-and-spokes turntable; gantry Π with a stem; lava-lake fishbone causeway; three-strip sluice weave; hourglass pinch with side chambers.
- **Thunder (26–30):** braided contours round a headwall; concentric ringfort; sky-pinnacle archipelago; two-tier cliff fault with a viaduct; twin-wing caldera amphitheatre.
- **Corrupted (31–35):** meandering brook with four fords; up and over a ridge into a hidden hollow; hedge maze round a centred court; tree to tree up five elder trunks; up the backs of three converging roots.
- **Sunken (36–40):** broken processional stair over a tide-flat; figure-eight of two cloisters; ladder up a flight of locks; two staggered sea-walls; two reef horns round a maelstrom.
- **Astral (41–45):** a constellation of floating isles; an orrery with the Apex as its Sun; a tilted, cracked floor of fault plates; three wards with one Waygate each; a diagonal rift stitched at three sutures.

**Where the Apex sits (the contrast rule):**

| Floor | Apex position | How you reach it | Dominant landform | Light |
| --- | --- | --- | --- | --- |
| 45 *(for reference)* | Centre-back, the Observing Floor | Over the Rift on a suture, up a Ring Stair | A diagonal rift across the floor | Rift-eye under a torn sky |
| 46 | **Back-west, the Upfall** | Eyot to eyot up a braided river that runs uphill | A braided void-river of lens-shaped eyots | Ash-fall dusk under the Rift's wound |
| 47 | **Centre, the Crimson Bier**, in plain view from the arrival | Two processional columns cross at the Crossing, then climb a Station Stair from the west or east | Processional courts plaited across the floor | Crimson vigil: dark, bone-white lamps, wine silk |
| 48 | **Back-east, the Far Gate** | Down a sagging chain of hung platforms to the low Keystone, then back up the far chain | A void spanned by four great chains crossing in a saltire | Void-glare from below |
| 49 | **Dead centre, the Dreadguard Keep**, inside a star fort | Round the covered way, up a bastion's flank, along the curtain, in by a drawbridge stair | A bastioned star fort round a moated keep | Iron night, shuttered lamps |
| 50 | **Centre-back, the Throne's seat**, the largest dais | Up the Throne itself: its feet, its greaves, its armrests, its hands | The colossal Throne as the landform | The Crimson Eclipse behind the Throne |

No two neighbours share an Apex position, an approach, a landform or a light. 47 and 49 both hold the Apex mid-room, but they are not neighbours. 47's is a low bier reached by crossing columns, 49's a moated keep reached through a fortress.

**Fixed on every floor:**
- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, `128 × 56`, and `Basin` stays centred on `X = 0`. Arrivals land out of aggro.
- `Apex` holds the Floor Alpha (46–49) or Biome Boss (50) summon and the Ascend/Rerun portals (`Layout.PortalSpots`, at the back of the Apex). Every Apex below is entered from the south, west or east, never the north. The measured portal spots are listed per floor.
- Mob totals and Elite counts stay **16 / 22 / 25 / 35 / 35** and **1 / 2 / 3 / 4 / 4**. Never add mobs for bigger rooms. `ExtraPlatforms` hold no camps.
- Floors 48–50 replace the generic patrols with authored routes (`ReplacePatrols = true`). `BASIN_LOOP` is always generated.

**Terrain system: use the Fungal one**, as Corrupted, Sunken and Astral did: `Terrain = { Direct = true, Surface = ..., Decks, DeckLooks, DeckThickness, RoundDecks, Shapes, Pools, Islands, Ridges, Rifts, Bridges, BridgeStyles, LiquidRise, FloorDip, NoApexShelf, WallBand, GroveScale, MeadowScale, GroundCover, GroundCoverCount }`.
- Don't introduce a third system, and don't mix in the top-level `DirectTerrain` / `Suspended` / `Masonry` fields.
- **One exception:** the top-level `Liquid = { Dry = true }` (read by `TowerTerrain.Field` for every system, Floor 28) is how these floors drop the palette's liquid (§5.3).
- Use `Shapes` (round, squircle or lens) for every terrain terrace that isn't a built deck. New terrain options are listed in §5.3; each is an option on the Fungal system.
- **Surface progression:** Floors 46–47 (the court's outer domain) use a new `Surface = "VAHL"`, and **from Floor 48 on** `Surface = "THRONEWARD"`, so the ground darkens and the pale trails narrow as you near the Throne. Both reuse place-wide colours only (§5.3).

---

### Floor 46: Abyssal Descent (`abyssal:1`, `INTRODUCTION`)

*640 × 640 × 240, `Bottom = −4`. Ash-fall dusk under the Rift's wound.*

**Guide image:** `reference/Abyssal Throne 46.jpg`.

**Story beat:** where the dark first catches what falls. The squad comes down through the Rift and lands on the **Fallstrand**, a strand of debris from the Archive above: shelf-ends, brass, drifts of pages. Ahead, the **Undertow** braids across a black plain in a dozen violet ribbons, and the ribbons run **uphill**, away from you and up the floor. At the back-west they gather and pour straight up into the dark: the **Upfall**. The Vahl's outriders hold the eyots between the channels. The Throne is not in sight yet. Everything is already flowing toward it.

**Shape: a braided void-river climbed eyot to eyot upstream, to the Upfall at the back-west.** Lens-shaped eyots (long north–south, narrow east–west) sit between braided channels in four staggered rows. Every link crosses a channel diagonally, so the route reads as a braid:
- **The quick way (measured):** Fallstrand → the **Ford of Pages** (Crossing) → **Cinder Eyot** → **Wreck Shoal** → up onto the Upfall from the south-west.
- **The midbraid:** Ford of Pages → **the Drift** → **Midbraid** → **the Lip** → the **Lip Stair** (`STAIRS`, +10) onto the Upfall from the east.
- **The east braid:** **Ashbar** → **Gallows Eyot** → **Bonebar** → the **Weir of Hooks** → the Lip.
- Cross-links tie the rows: Cinder Eyot and Gallows Eyot each also reach Midbraid.

**New to the tower:** a braided river that runs uphill, crossed on **chain-fords** (`BridgeStyles = "CHAINFORD"`: low black-iron grate walks hung on chains just over the Undertow). New landmark type: the **Upfall**, a river of void pouring upward into the sky.

*Closest earlier shapes:* Corrupted 31's meandering brook (one stream, four fords on the ground) and Thunder 26's braided contours (braided *ridges* round a headwall). Here the water is the braid, the land is the eyots between the strands, every crossing is diagonal, and the river runs toward the goal.

```
                                     N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │   [ THE UPFALL ] Y40 ◄═(st)═ [THE LIP] Y30 ◄── [WEIR OF HOOKS] Y32   │
   │        ▲                        ▲                    ▲            │
   │  [WRECK SHOAL] Y22         [MIDBRAID] Y24        [BONEBAR] Y28     │
   │        ▲     ↖               ▲    ▲   ↗                ▲          │
   │  ~~~  [CINDER EYOT] Y16   [THE DRIFT] Y14   [GALLOWS EYOT] Y20 ~~~ │
   │        ▲         ↖           ▲          ↗          ▲              │
   │  [REAVING EYOT] Y8      [FORD OF PAGES] Y12        [ASHBAR] Y4     │
   │          \                   |                     /              │
   │    ~~~~~~~~~~~~~~~~~~~~~ THE FALLSTRAND  Y0 ~~~~~~~~~~~~~~~~~~~~   │
   │                              |                                    │
   │                      [ THE FALLSTAIR ] Y8                         │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Fallstair | 0, 8, 286 | 128 × 56 | deck (a stair of fallen Archive stone) |
| `Basin` | The Fallstrand | 0, 0, 180 | 608 × 96 | terrain (the debris strand) |
| `EastGallery` | Ashbar | 175, 4, 55 | 84 × 76 | terrain (lens eyot) |
| `WestGallery` | Reaving Eyot | −175, 8, 55 | 84 × 76 | terrain (lens eyot, Elite) |
| `Crossing` | The Ford of Pages | 0, 12, 60 | 76 × 64 | terrain (lens eyot) |
| `EyotC` (extra) | The Drift | 0, 14, −55 | 52 × 60 | deck (a raft of fallen shelving wedged in the braid) |
| `EyotW` (extra) | Cinder Eyot | −100, 16, −45 | 60 × 76 | terrain (lens eyot) |
| `EyotE` (extra) | Gallows Eyot | 100, 20, −45 | 60 × 76 | terrain (lens eyot) |
| `ShoalW` (extra) | Wreck Shoal | −215, 22, −120 | 60 × 76 | deck (the wreck of a fallen Halcyr stack) |
| `ShoalC` (extra) | Midbraid | 0, 24, −160 | 64 × 72 | terrain (lens eyot) |
| `ShoalE` (extra) | Bonebar | 215, 28, −120 | 60 × 76 | terrain (lens eyot) |
| `HeadC` (extra) | The Lip | 25, 30, −262 | 56 × 52 | deck (obsidian lip at the Upfall's foot) |
| `HeadE` (extra) | Weir of Hooks | 160, 32, −245 | 64 × 60 | terrain |
| `Apex` | The Upfall | −150, 40, −240 | 120 × 88 | terrain (round, the head of the braid) |

**Paths (19 links):**
- **From the Fallstrand:** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→Crossing` (+12, 14.69°), `Basin→EastGallery` (+4).
- **First row of crossings:** `WestGallery→EyotW` (+8, 14.53°), `Crossing→EyotW` (+4), `Crossing→EyotE` (+8), `EastGallery→EyotE` (+16, 14.76°), `Crossing→EyotC` (+2).
- **Second row:** `EyotW→ShoalW` (+6), `EyotW→ShoalC` (+8), `EyotC→ShoalC` (+10), `EyotE→ShoalC` (+4), `EyotE→ShoalE` (+8).
- **To the Upfall:** `ShoalW→Apex` (+18, 14.79°), `ShoalC→HeadC` (+6), `ShoalE→HeadE` (+4), `HeadC→Apex` (`STAIRS`: the Lip Stair, +10), `HeadE→HeadC` (−2).

*Fords:*
- Every link off the Fallstrand crosses a channel, so every one except `Sanctuary→Basin` is a `Terrain.Bridges` entry in `"CHAINFORD"` style.
- `ShoalW→Apex` and `HeadC→Apex` are ramps and stairs over the Upfall's basin, in the same style with taller chain-posts.

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite: a Throne Executioner on the Reaving Eyot, the court's first sentry), `EAST_GALLERY` 4.
- **Patrol:** `BASIN_LOOP` (112.9 s).
- **Portals:** Ascend `(−134, 40, −272)`, Rerun `(−166, 40, −272)`.

**Terrain:** `Surface = "VAHL"`, `Liquid = { Dry = true }`.
- **The Fallstrand** is the only broad ground: dark basalt littered with the Archive's debris, its north edge breaking into the braid.
- **The eyots** are lens `Shapes` (`Round ≈ 2.4`, elongated N–S) with short `Sheer` aprons (≤ 8 studs), so each reads as a slab of black rock standing in the braid.
- **The braid channels** are `Terrain.Rifts` used as shallow river beds: polylines between the eyots, half-width 14–22, carved to `Bottom − 4`, dark basalt bed, and **no terrain liquid**. The Undertow is a client mesh laid in each bed (§5.3).
- **The Upfall's basin** is a round bowl behind and west of the Apex, where every channel gathers.
- `GroveScale = 0`; `NoApexShelf = true`; `WallBand` low at the back so the Upfall stands against the black vault.

**Landmarks (≥ 16):**
1. **The Upfall** (≥ 150 studs): a column of violet void pouring *upward* out of its basin into the dark, its edges shedding motes that fall up. A client mesh with scrolling textures over an invisible anchor. Its foot is behind the Apex and never overhangs the arena or the portal lanes.
2. **The Rift's wound:** a long pale gash high in the black vault, the only sky, still shedding pages.
3. **The Fallstrand's debris:** the Archive's shelves, a fallen armillary ring and a toppled Index Lamp, half buried in ash.
4. **The *unwritten* page:** pinned to an obsidian spike beside the Fallstair, the word "Vharos" written across it in crimson ink (a decal, matte).
5. **The chain-fords:** black-iron grate walks on chains between iron posts, the Undertow sliding uphill under them.
6. **The braid:** a dozen violet ribbons running north between the eyots (client meshes).
7. **The Reaving Eyot:** the court's first sentry post: a reaving rack of hooked blades, an execution block and a gibbet cage.
8. **The Ford of Pages:** a drift of Halcyr pages that the Undertow keeps pulling upstream.
9. **The Drift:** a raft of fallen Archive shelving wedged across a channel.
10. **Wreck Shoal:** a whole Halcyr stack fallen out of the sky and broken over a shoal.
11. **Gallows Eyot:** a row of iron gibbets, empty, facing upstream.
12. **Bonebar:** bone-white rubble of the Vahl's oldest marble, a fallen statue's hand.
13. **The Weir of Hooks:** an iron weir of hooks across a channel where the Undertow combs out the debris.
14. **The Lip:** an obsidian lip at the Upfall's foot with the first Chained Crown keystone.
15. **Split obsidian geodes** on the eyots, blood-red crystal inside (the Trench Geode skin).
16. Far: the Vault, with the court's far spires on distant ledges and the first glimpse of a crimson glow beyond them.

**Kit candidates (≥ 11):** `UpfallColumn` (client mesh + anchor), `ChainFordSpan`, `ChainPostIron`, `EyotSlab` (three sizes), `ReavingRack`, `GibbetCage`, `ExecutionBlock`, `WeirOfHooks`, `FallenStackWreck`, `ObsidianGeodeSplit`, `WardlightCage`, `ChainedCrownKeystone`, `UndertowRibbon` (client).

**Lighting grade (`FloorGrades[46]`):** ash-fall dusk.
- A pale bone key from the Rift's wound overhead, a dark violet ambient, grey-violet ash haze, and the Undertow glowing below the eyots.
- `AtmosphereDensity ≈ 0.34`, `AtmosphereHaze ≈ 1.2`, `Saturation ≈ 0.0`, `Contrast ≈ 0.10`, `ColorShift_Top ≈ (214, 206, 228)`.
- It must break cleanly from Floor 45's black-indigo rift-eye into grey ash.

**Spec asserts:**
- **Room:** key, name and `Size` (`Bottom = −4`, 2 return ramps). `Apex.X < −100` and `Apex.Z < −200` (back-west).
- **The braid rule:**
  - every link except `Sanctuary→Basin` is a `Terrain.Bridges` entry;
  - every link between two eyots runs diagonally (its terraces' centres differ in X and Z by at least 40 studs each), except the links touching the midbraid's spine, `EyotC` or `HeadC`;
  - every terrace past the Basin is higher than the Basin.
- **Stairs:** `HeadC→Apex` is `STAIRS`.
- **Camps:** 16 mobs and 1 Elite.
- **Validation:** no `Validate` problems.

---

### Floor 47: Crimson Procession (`abyssal:2`, `EXPANDED_ENCOUNTER`)

*700 × 700 × 265, `Bottom = −4`. Crimson vigil.*

**Guide image:** `reference/Abyssal Throne 47.jpg`.

**Story beat:** the road the oaths were carried down. Twice a year the Vahl carried their oaths to the Throne in two columns: the **Sworn** on the west and the **Bound** on the east. The columns met and crossed at the **Crossing of Oaths**, swapping sides so that no oath reached the Throne by the hand that swore it. They gathered at the **Crimson Bier**, where an effigy of the Warden-King lay in state. The procession has been walking ever since. The Bier stands in the middle of the floor in plain sight from the arrival, ringed by stone mourners.

**Shape: two processional columns plaited across the floor, swapping sides at the Crossing of Oaths, then climbing to the Bier in the centre from the west or east.** Nothing approaches the Bier from the front: the **Mourners' Gallery** in front of it is a dead end that faces the Bier across the void.
- **The Sworn (west):** the **Hall of Sworn** (west gallery, Elite) → the Crossing of Oaths → the **Station of Bound** (east) → up the east **Station Stair** onto the Bier.
- **The Bound (east):** the **Hall of Bound** (east gallery, Elite) → the Crossing → the **Station of Sworn** (west) → up the west **Station Stair**. (The measured quickest route is this one: Hall of Bound → Crossing → Station of Sworn.)
- **The outer aisle:** **Shrine of Silk** / **Shrine of Iron** → **Chapel of Ash** / **Chapel of Chains** → the **Vigils** on the back wall → the **Ossuary** behind the Bier, with the **Vigil Walk** joining both Vigils across the back.

**New to the tower:** a layout read as two columns that **cross**: every quick route changes sides at the Crossing of Oaths, so the squad always arrives at the Bier on the side it didn't start on. New traversal: **processional stairs** (`BridgeStyles = "PROCESSIONAL"`: obsidian stairs with a matte wine-silk runner, flanked by rows of kneeling statues and banner poles outside the walk). New landmark type: the **Effigy and Bier**.

*Closest earlier shapes:* Frozen 20's cathedral nave (one axis, chapels off it) and Astral 42's Sun in the middle (in sight, out of reach from the front). Here the axis is never walked straight, the two strands cross once in the middle, and the Apex is a low bier you climb onto from the side.

```
                                     N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │       [VIGIL OF SWORN] Y36 ── [ THE OSSUARY ] Y44 ── [VIGIL OF BOUND] Y40   │
   │            ▲     \__________ the Vigil Walk __________/     ▲               │
   │            |              [  THE EFFIGY  ]                   |               │
   │  [CHAPEL OF ASH] Y20     [ CRIMSON BIER ] Y48        [CHAPEL OF CHAINS] Y24 │
   │        ▲   \              ▲(st)       (st)▲              /   ▲              │
   │        |  [STATION OF SWORN] Y28   [MOURNERS] Y22   [STATION OF BOUND] Y32  │
   │        |            ↖             ▲              ↗             |            │
   │        |              [ CROSSING OF OATHS ] Y16                |            │
   │        |            ↗                            ↖             |            │
   │  [SHRINE OF SILK] Y4 ─ [HALL OF SWORN] Y8      [HALL OF BOUND] Y12 ─ [SHRINE OF IRON] Y6
   │                      \                            /                         │
   │    ~~~~~~~~~~~~~~~~~~~~~~ THE MUSTER  Y0 ~~~~~~~~~~~~~~~~~~~~~~             │
   │                                |                                            │
   │                       [ THE OATHGATE ] Y8                                   │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Oathgate | 0, 8, 316 | 128 × 56 | deck |
| `Basin` | The Muster | 0, 0, 210 | 668 × 96 | terrain |
| `ShrineW` (extra) | Shrine of Silk | −200, 4, 122 | 64 × 56 | terrain |
| `ShrineE` (extra) | Shrine of Iron | 200, 6, 122 | 64 × 56 | deck (an iron-floored shrine) |
| `WestGallery` | Hall of Sworn | −110, 8, 95 | 84 × 72 | terrain (Elite) |
| `EastGallery` | Hall of Bound | 110, 12, 95 | 84 × 72 | terrain (Elite) |
| `Crossing` | The Crossing of Oaths | 0, 16, 20 | 80 × 64 | terrain (round) |
| `ChapelW` (extra) | Chapel of Ash | −270, 20, −85 | 60 × 52 | terrain |
| `Mourners` (extra) | The Mourners' Gallery | 0, 22, −60 | 60 × 40 | deck (a dead end facing the Bier) |
| `ChapelE` (extra) | Chapel of Chains | 270, 24, −85 | 60 × 52 | terrain |
| `StationW` (extra) | Station of Sworn | −145, 28, −55 | 68 × 60 | terrain |
| `StationE` (extra) | Station of Bound | 145, 32, −55 | 68 × 60 | terrain |
| `VigilW` (extra) | Vigil of Sworn | −215, 36, −235 | 64 × 56 | terrain |
| `VigilE` (extra) | Vigil of Bound | 215, 40, −235 | 64 × 56 | terrain |
| `Ossuary` (extra) | The Ossuary | 0, 40, −290 | 72 × 56 | terrain |
| `Apex` | The Crimson Bier | 0, 48, −160 | 120 × 92 | terrain (round) |

**Paths (21 links):**
- **From the Muster:** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→EastGallery` (+12, 14.69°).
- **Into the Crossing of Oaths:** `WestGallery→Crossing` (+8, 14.53°), `EastGallery→Crossing` (+4).
- **To the Shrines:** `WestGallery→ShrineW` (−4), `EastGallery→ShrineE` (−6).
- **Out of the Crossing:** `Crossing→StationW` (+12), `Crossing→StationE` (+16), `Crossing→Mourners` (+6).
- **Onto the Bier:** `StationW→Apex` (`STAIRS`: the west Station Stair, +20, 14.81°), `StationE→Apex` (`STAIRS`: the east Station Stair, +16, 14.76°).
- **The outer aisle:** `StationW→ChapelW` (−8), `StationE→ChapelE` (−8), `ShrineW→ChapelW` (+16), `ShrineE→ChapelE` (+18), `ChapelW→VigilW` (+16), `ChapelE→VigilE` (+16).
- **The Vigils and the Ossuary:** `VigilW→Ossuary` (+4), `VigilE→Ossuary` (0: both leave their Vigil beside the Vigil Walk, so they stay near its height and never cut across it), `VigilW→VigilE` (+4: the Vigil Walk, behind the Bier).

*Styles:*
- Both Station Stairs are `"PROCESSIONAL"`.
- The `Crossing→Station` ramps are processional ramps (the same runner, no stair treads).
- The links that cross open void (`Crossing→Mourners`, both `Chapel→Vigil` links and the Vigil Walk) are `Terrain.Bridges` in `"PROCESSIONAL"` style with an iron deck.
- **The Mourners' Gallery must read as a dead end:** open void between it and the Bier, no low chain or banner across the gap.

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4 (the Crossing of Oaths), `WEST_GALLERY` 5 (Elite, the Hall of Sworn), `EAST_GALLERY` 5 (Elite, the Hall of Bound).
- **Patrol:** `BASIN_LOOP` (123.4 s).
- **Portals:** Ascend `(16, 48, −194)`, Rerun `(−16, 48, −194)`.

**Terrain:** `Surface = "VAHL"`, `Liquid = { Dry = true }`.
- Stepped processional courts of dark basalt flags with bone-white marble borders, each court a round or squircle `Shapes` plateau with a short `Sheer` apron.
- The Bier stands on a round mesa in a ring of void: a `Terrain.Rifts` loop round the Apex, half-width ~16, carved to `Bottom − 4`. The Undertow runs round it, so the Bier reads as an island in the middle of the floor.
- `NoApexShelf = true`.

**Landmarks (≥ 18):**
1. **The Effigy** behind the Bier (≥ 170 studs): a colossal recumbent-then-rising statue of the Warden-King in black iron, carried on the shoulders of stone bearers. It stands between the Bier's back edge and the Ossuary, never over the arena or the portal lanes.
2. **The Crimson Bier:** a raised black-marble catafalque at the Bier's back edge, draped in wine silk. Keep the arena floor clean.
3. **The two columns:** rows of stone processioners (the Sworn in hoods, the Bound in chains) lining the outer edges of each court, all facing the Bier.
4. **The Crossing of Oaths:** a round court inlaid with the two columns' paths crossing in bone-white marble, a broken oath-stone at its centre.
5. **The Station Stairs:** obsidian stairs with silk runners, kneeling statues either side.
6. **The Halls of Sworn and Bound:** long oath-halls of iron lecterns, chained oath-tablets and banners.
7. **The Mourners' Gallery:** a balcony of veiled stone mourners facing the Bier across the void.
8. **The Shrines of Silk and Iron:** a loom-shrine of crimson silk and a forge-shrine of black iron.
9. **The Chapels of Ash and Chains:** an ash-urn chapel and a chapel of hanging chain-votives.
10. **The Vigils:** stands of hooded vigil-keepers on the back wall, their Wardlights leaning toward the Bier.
11. **The Ossuary:** bone-white niches stacked with the sealed urns of the court (the Sovereign's Cursed Urn skin).
12. **Banner avenues:** paired matte wine-silk banners on iron poles along every processional link, outside the walk.
13. **The Oathgate:** the arrival through an iron gate hung with oath-tablets.
14. **The Muster:** a broad parade court with standard-bearers' sockets and a fallen standard.
15. **Censer stands** where the Hierophants stand, void-light smoke kept low and pale.
16. **The ring of void** round the Bier, the Undertow circling it (client mesh).
17. **The Rift's wound** narrowing overhead.
18. Far: the court's far ledges lined with distant processioners.

**Kit candidates (≥ 12):** `EffigyOnBearers` (statue, bearers and plinth split for clearance), `CrimsonBierCatafalque`, `ProcessionerStatue` (Sworn and Bound variants by tint), `KneelingStatue`, `ProcessionalStairRunner`, `OathLectern`, `OathTabletChained`, `MournerVeiled`, `SilkLoomShrine`, `IronForgeShrine`, `ChainVotiveRack`, `OssuaryNicheWall`, `BannerPoleWine`, `CenserStand`.

**Lighting grade (`FloorGrades[47]`):** crimson vigil.
- A dark, still floor: a low cool ambient, warm bone-white pools under the Wardlights, the wine silk catching only reflected light.
- Crimson appears only as a faint glow on the far ledges and behind the Effigy, ≥ 30 studs above any walk surface.
- `AtmosphereDensity ≈ 0.36`, `AtmosphereHaze ≈ 1.0`, `BloomIntensity ≈ 0.45`, `Saturation ≈ 0.12`, `ColorShift_Top ≈ (226, 206, 214)`, `TintColor` a faint rose, never red.

**Spec asserts:**
- **Room:** key, name and `Size` (`Bottom = −4`, 2 return ramps). `|Apex.X| < 20` and `−220 < Apex.Z < −100` (centre).
- **The Bier rule:** the Apex is entered by exactly two links, `StationW→Apex` and `StationE→Apex`, both `STAIRS`, one from each side. `Mourners` has exactly one link (a dead end).
- **The plait rule:** with the Crossing removed, neither Station is reachable from the Basin except round the outer aisle, and the measured shortest route passes through the Crossing.
- **Camps:** 22 mobs and 2 Elites.
- **Validation:** no `Validate` problems.

---

### Floor 48: Voidspan Crossing (`abyssal:3`, `TERRAIN_VARIATION`)

*760 × 760 × 295, `Bottom = −6`. Void-glare from below.*

**Guide image:** `reference/Abyssal Throne 48.jpg`.

**Story beat:** the court's crossing of the great void. Here the Undertow drops away into a void so deep the Vahl could not bridge it in stone. So they hung **four great chains** across it from four **Anchor Spires**, two on each rim, crossing in a saltire over the middle. They hung platforms on the chains like beads. Where the chains cross, at the lowest point of the sag, hangs the **Keystone**, a cage-platform of iron that the whole span pulls on. Crossing the Voidspan means going *down* into the sag before you can climb out of it.

**Shape: down a sagging chain of hung platforms to the low Keystone, then back up the far chain to the Far Gate in the back-east.** From the arrival you look across the void and see the saltire whole: two chains from the near spires dipping to the Keystone, two rising from it to the far spires.
- **The near rim:** the **Hookward** (west gallery, Elite), the **Chainwright's Yard** (Crossing, Elite) and the **Ashgrate** (east gallery, Elite) climb to the **West** and **East Anchor Spires**, joined by the **Rim Walk**.
- **The saltire (quickest, measured):** an Anchor Spire → its **near bead** → **the Keystone** (Y 25, the lowest platform past the rim) → the opposite **far bead** → the opposite **Far Anchor** → the Far Gate up the **Gate Stair** (`STAIRS`, +12). Every chain crosses to the other side, so the quick way is a diagonal across the void.
- **The Gibbet Ledges (the long way):** from each near-rim gallery, a ledge path along the void's end wall (the **West** and **East Gibbet Ledges**) to the far anchors, never touching the chains.
- **The Spireward:** a back terrace from the Far West Anchor to the Far Gate from the west.

**New to the tower:**
- **A route that goes down before it goes up.** Every earlier floor climbs at every step of its quickest route; here the quickest route drops 6 studs into the sag before climbing out.
- **Catenary spans** (`BridgeStyles = "CATENARY"`): straight hung decks on four colossal chains. The sag lives in the platform heights and the chains overhead; every deck is level and firm.
- **New landmark type:** the Anchor Spires with their chain-capstans, and the Keystone cage.

*Closest earlier shapes:* Thunder 28's skybridge archipelago (rock needles linked by rope bridges, every hop climbing) and Astral 41's constellation of floating isles. Here the platforms hang *from* the structure overhead, they form one crossing figure, and the middle is the lowest point.

```
                                     N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │      [SPIREWARD] Y48 ─────────────────────► [ THE FAR GATE ] Y56   │
   │         ▲                                      ▲ (st)              │
   │ [FAR WEST ANCHOR] Y40              [FAR EAST ANCHOR] Y44            │
   │      ▲          ▲                     ▲          ▲                 │
   │      |      [FAR BEAD W] Y31   [FAR BEAD E] Y33  |                 │
   │ [WEST GIBBET]       ╲          ╱             [EAST GIBBET]         │
   │  LEDGE Y36           [ THE KEYSTONE ] Y22      LEDGE Y20            │
   │      ▲              ╱          ╲                  ▲                 │
   │      |      [NEAR BEAD W] Y26  [NEAR BEAD E] Y30  |                 │
   │      |       ▲                          ▲         |                 │
   │      | [WEST ANCHOR] Y28 ── rim walk ── [EAST ANCHOR] Y32           │
   │      |        ▲      ↖                ↗    ▲      |                 │
   │ [HOOKWARD] Y8      [CHAINWRIGHT'S YARD] Y12      [ASHGRATE] Y16     │
   │          \                 |                    /                   │
   │    ~~~~~~~~~~~~~~~~~~ THE CAPSTAN QUAY  Y0 ~~~~~~~~~~~~~~~~~~        │
   │                            |                                        │
   │                   [ THE CHAIN STAIR ] Y8                            │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Chain Stair | 0, 8, 346 | 128 × 56 | deck |
| `Basin` | The Capstan Quay | 0, 0, 238 | 728 × 100 | terrain |
| `WestGallery` | The Hookward | −215, 8, 100 | 88 × 76 | terrain (Elite) |
| `Crossing` | The Chainwright's Yard | 0, 24, 115 | 84 × 64 | terrain (Elite) |
| `EastGallery` | The Ashgrate | 215, 16, 100 | 88 × 76 | terrain (Elite) |
| `GibbetE` (extra) | East Gibbet Ledge | 295, 20, −100 | 60 × 52 | terrain (a ledge on the void's end wall) |
| `Keystone` (extra) | The Keystone | 0, 25, −105 | 60 × 52 | deck (hung where the chains cross) |
| `BeadNW` (extra) | Near Bead West | −32, 26, −35 | 52 × 44 | deck (hung) |
| `AnchorNW` (extra) | West Anchor Spire | −60, 28, 30 | 64 × 52 | terrain (the spire's footing) |
| `BeadNE` (extra) | Near Bead East | 32, 30, −35 | 52 × 44 | deck (hung) |
| `BeadFW` (extra) | Far Bead West | −32, 29, −175 | 52 × 44 | deck (hung) |
| `AnchorNE` (extra) | East Anchor Spire | 60, 32, 30 | 64 × 52 | terrain |
| `BeadFE` (extra) | Far Bead East | 32, 31, −175 | 52 × 44 | deck (hung) |
| `GibbetW` (extra) | West Gibbet Ledge | −295, 36, −100 | 60 × 52 | terrain (a ledge on the void's end wall) |
| `AnchorFW` (extra) | Far West Anchor | −60, 40, −240 | 64 × 52 | terrain |
| `AnchorFE` (extra) | Far East Anchor | 60, 44, −240 | 64 × 52 | terrain |
| `Spireward` (extra) | The Spireward | −60, 48, −322 | 64 × 52 | terrain |
| `Apex` | The Far Gate | 170, 56, −305 | 112 × 84 | terrain (round) |

**Paths (24 links):**
- **From the Quay:** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→Crossing` (+12, 14.69°), `Basin→EastGallery` (+16).
- **Up to the Anchor Spires:** `WestGallery→AnchorNW` (+20), `Crossing→AnchorNW` (+16, 14.76°), `Crossing→AnchorNE` (+20, 14.81°), `EastGallery→AnchorNE` (+16), `AnchorNW→AnchorNE` (+4: the Rim Walk).
- **The saltire:** `AnchorNW→BeadNW` (−2), `BeadNW→Keystone` (−1), `AnchorNE→BeadNE` (−2), `BeadNE→Keystone` (−5), `Keystone→BeadFW` (+4), `Keystone→BeadFE` (+6), `BeadFW→AnchorFW` (+11), `BeadFE→AnchorFE` (+13). The four Keystone links stay within +6: a steeper one is too short for 15°, starts deep inside the Keystone, and runs across its neighbour (the build bug the Keystone had at Y 22).
- **To the Far Gate:** `AnchorFE→Apex` (`STAIRS`: the Gate Stair, +12, 14.69°), `AnchorFW→Spireward` (+8), `Spireward→Apex` (+8).
- **The Gibbet Ledges:** `WestGallery→GibbetW` (+28), `GibbetW→AnchorFW` (+4), `EastGallery→GibbetE` (+4), `GibbetE→AnchorFE` (+24).

*Spans:*
- The eight saltire links are `Terrain.Bridges` in `"CATENARY"` style.
- The Gibbet Ledge links are `Terrain.Bridges` in a narrow iron-grate style bolted to the end walls.
- The beads and the Keystone are decks hung from the chains overhead, which pass ≥ 18 studs above every deck and never cross a lane below that height.
- Every link that touches a bead or the Keystone is the only way onto it.

**Camps (25, 3 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite, the Chainwright's Yard), `WEST_GALLERY` 5 (Elite, the Hookward), `EAST_GALLERY` 5 (Elite, the Ashgrate).

**Patrols (authored, `ReplacePatrols = true`):**
- `BASIN_LOOP` (134.0 s)
- `NEAR_RIM` = `{WestGallery, AnchorNW, AnchorNE, EastGallery}` (185.7 s)
- `WEST_CHAIN` = `{AnchorNW, BeadNW, Keystone}` (59.3 s)
- `EAST_CHAIN` = `{AnchorNE, BeadNE, Keystone}` (59.6 s)
- `FAR_CHAIN` = `{BeadFW, Keystone, BeadFE}` (62.6 s)

**Portals:** Ascend `(186, 56, −335)`, Rerun `(154, 56, −335)`.

**Terrain:** `Bottom = −6`, `Surface = "THRONEWARD"`, `Liquid = { Dry = true }`.
- **The void:** a `Terrain.Rifts` polyline carved down to the floor (`Bottom − 4`) from wall to wall, between the near rim (north edge ≈ `Z 0`) and the far rim (south edge ≈ `Z −215`), with sheer basalt walls.
- **The Gibbet Ledges** are terrain ledges cut into the void's end walls.
- **The void's floor** is dark basalt with the Undertow pooled across it as one great client mesh of slow violet, so the whole span is lit from below.
- **The Anchor Spires' footings** are round `Shapes` with `Sheer` aprons.
- `NoApexShelf = true`.
- Set the room's `VoidCatchY` (the Astral void-fall recovery) just above the void floor, so a squad that falls is returned to the Chain Stair rather than walking the void floor back to the return ramps. Keep the two return ramps (the spec still asserts them); they catch anything the recovery misses.

**Landmarks (≥ 20):**
1. **The four Anchor Spires** (≥ 200 studs): obsidian spires with iron collars and great chain-capstans, each carrying one of the four chains. Their bases stand on the anchor footings off the lanes; their heights carry the chains well above every deck.
2. **The four great chains:** colossal iron chains hanging in catenaries from the spires' collars, crossing in a saltire over the Keystone (kit meshes, in segments).
3. **The Keystone:** an iron cage-platform hung where the chains cross, its brightest Wardlight at the lowest point of the floor.
4. **The beads:** hung iron platforms with chain-hangers at their corners.
5. **The Far Gate:** an obsidian gatehouse on the far rim, its gate the first to bear the Chained Crown in gold-rimmed iron. The Alpha's lair; keep the arena floor clean.
6. **The Gibbet Ledges:** iron gibbets and cages hung off the end walls above the void.
7. **The void's glow:** the Undertow pooled far below, lighting the chains from underneath.
8. **The Chainwright's Yard:** forges and racks of chain-links, a half-forged link the size of a house.
9. **The Hookward:** hooks, pulleys and the reaving crews' gear.
10. **The Ashgrate:** a grated floor over an ash-pit, ash rising through it.
11. **The Capstan Quay:** the great capstans that once took up the chains' slack, now seized.
12. **The Rim Walk:** an iron walk between the near spires with chain-bollards.
13. **The Spireward:** a guard-court behind the far anchors.
14. **Fallen chain-links** lying across the rim, off the lanes.
15. **Counterweights:** colossal iron weights hanging on the far side of each spire.
16. **Wardlights** hung from the chains themselves (client sway).
17. **Caged void shards** on the anchor footings (the Void Titan Core skin).
18. **The Chain Stair:** the arrival down iron steps from the Quay's gatehouse.
19. **The Rift's wound** a thin line overhead.
20. Far: the court's fortress on the far wall, the Dreadguard Citadel's towers just visible beyond.

**Kit candidates (≥ 13):** `AnchorSpire` (base, collar and capstan split for clearance), `GreatChainSegment` (straight and catenary pieces), `KeystoneCage`, `HungBeadPlatform`, `CatenarySpanDeck`, `ChainCapstanGreat`, `Counterweight`, `GibbetLedgeCage`, `FarGatehouse`, `HalfForgedLink`, `AshGrateFloor`, `ChainBollard`, `HookPulleyRack`, `VoidPoolMesh` (client).

**Lighting grade (`FloorGrades[48]`):** void-glare.
- A black vault, a cold violet glow from the void below lighting everything from underneath, and bone-white Wardlights on the decks.
- `AtmosphereDensity ≈ 0.38`, `AtmosphereHaze ≈ 1.3`, `BloomIntensity ≈ 0.55`, `Saturation ≈ 0.08`, `ColorShift_Bottom ≈ (150, 110, 220)`, `ColorShift_Top ≈ (170, 168, 190)`.
- The decks are lit neutral so camps read.

**Spec asserts:**
- **Room:** key, name and `Size` (`Bottom = −6`, 2 return ramps). `Apex.X > 120` and `Apex.Z < −250` (back-east).
- **The sag rule:** the Keystone is lower than all four beads, and every bead is lower than its anchor. The measured shortest route passes through the Keystone and includes at least one link that goes down.
- **The saltire rule:** each near anchor reaches the Keystone only through its own near bead, and the Keystone reaches each far anchor only through its own far bead. The measured shortest route crosses from one side of the room to the other (in on a west bead, out on an east one, or the reverse).
- **The Gibbet rule:** with the Keystone removed, the Apex is still reachable, but only by a Gibbet Ledge.
- **Stairs:** `AnchorFE→Apex` is `STAIRS`.
- **Camps:** 25 mobs and 3 Elites.
- **Patrols:** the authored patrols resolve and stay under 240 s.
- **Validation:** no `Validate` problems.

---

### Floor 49: Dreadguard Citadel (`abyssal:4`, `ELITE_STRONGHOLD`)

*840 × 795 × 320, `Bottom = −6`. Iron night.*

**Guide image:** `reference/Abyssal Throne 49.jpg`.

**Story beat:** the Dreadguard's fortress. Here the Throne's executioners built the last wall between the Abyss and the Throne: a **star fort** of obsidian and iron, its bastions pointed outward so no wall could be approached without being seen from two others. At its heart, on a mound ringed by a void moat, stands the **Dreadguard Keep**, where they keep the Overlord's sword when he is not holding it. They keep their lamps shuttered on the walls so nothing can see them first. The only lit lamps are on the drawbridges into the keep.

**Shape: a bastioned star fort round a moated central keep.**
- **Outside the walls:** from the arrival you face the **Ravelin** (Crossing), a pointed outwork in front of the gate, with the **covered way** to either side: the **Western** and **Eastern Covert**.
- **The flanks:** the covered way runs out to the two front bastions, the **Bastion of Hooks** (west gallery, Elite) and the **Bastion of Axes** (east gallery, Elite).
- **The curtains:** up the curtain walls to the two rear bastions, the **West** and **East Dread Bastions** (Elite, Y 32 and 36), and on round the **North Curtains** to the **North Bastion**, a dead end over the Countermine.
- **Into the keep:** from the **West** or **East Curtain**, cross into the inner ward (the **West** and **East Inner Ward**), then up a **drawbridge stair** (`STAIRS`) over the moat into the keep. The quickest route (measured) is the covered way → a front bastion → its curtain → its inner ward → the drawbridge.
- **The Sallyport:** a dead-end postern platform on the Ravelin's inner side, facing the keep across the moat.

**New to the tower:** a bastioned **star fort**: walls you walk *round* and *along*, never through, with the goal in the middle the whole time. New traversal: **drawbridge stairs** (`BridgeStyles = "DRAWBRIDGE"`: iron-banded stair-bridges let down over the moat on chains, the chains running up to the keep's gate-towers). New landmark type: the central keep tower and the star fort's arrow-head bastions.

*Closest earlier shapes:* Verdant 4's walled ring with wall-walks, Thunder 27's concentric ringfort, Astral 44's three wards with one gate each, and Fungal 10's dais in a moat. Here the wall is a star of bastions with no gate into the middle. The way in is up and along the walls, then across the moat by drawbridge from either side, and the Apex sits in the dead centre of the room.

```
                                     N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │  [NORTH CURTAIN W] Y44 ── [NORTH BASTION] Y40 ── [NORTH CURTAIN E] Y48  │
   │          ▲                    [COUNTERMINE] Y30          ▲             │
   │ [W. DREAD BASTION] Y32                       [E. DREAD BASTION] Y36    │
   │        ▲      \                                    /      ▲            │
   │        |   [W. INNER WARD] Y52 ═(st)═► [ THE DREADGUARD ] ◄═(st)═ [E. INNER WARD] Y56
   │ [W. CURTAIN] Y24 ──┘          ~ moat ~  [      KEEP      ] ~ moat ~   └── [E. CURTAIN] Y28
   │        ▲                               [   Y64 144×108  ]                   ▲      │
   │        |                                  [SALLYPORT] Y22                    |      │
   │ [BASTION OF HOOKS] Y16                        ▲                [BASTION OF AXES] Y20 │
   │        ▲                                       |                            ▲      │
   │   [WESTERN COVERT] Y4 ────────────── [ THE RAVELIN ] Y12 ───── [EASTERN COVERT] Y8  │
   │           \                                  |                       /             │
   │    ~~~~~~~~~~~~~~~~~~~~~~~~~ THE GLACIS  Y0 ~~~~~~~~~~~~~~~~~~~~~~~~~               │
   │                                              |                                     │
   │                                    [ THE IRON POSTERN ] Y8                         │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Iron Postern | 0, 8, 363.5 | 128 × 56 | deck |
| `Basin` | The Glacis | 0, 0, 240 | 808 × 104 | terrain |
| `CovertW` (extra) | The Western Covert | −125, 4, 120 | 60 × 52 | terrain (the covered way) |
| `CovertE` (extra) | The Eastern Covert | 125, 8, 120 | 60 × 52 | terrain |
| `Crossing` | The Ravelin | 0, 12, 110 | 88 × 68 | terrain (the pointed outwork) |
| `WestGallery` | Bastion of Hooks | −265, 16, 75 | 92 × 80 | terrain (front bastion, Elite) |
| `EastGallery` | Bastion of Axes | 265, 20, 75 | 92 × 80 | terrain (front bastion, Elite) |
| `Sallyport` (extra) | The Sallyport | 0, 22, 30 | 64 × 48 | deck (a postern platform, dead end) |
| `CurtainW` (extra) | The West Curtain | −320, 24, −70 | 64 × 72 | terrain (wall-walk) |
| `CurtainE` (extra) | The East Curtain | 320, 28, −70 | 64 × 72 | terrain (wall-walk) |
| `Countermine` (extra) | The Countermine | 0, 30, −225 | 64 × 48 | deck (a mine-head behind the keep, dead end) |
| `WestBastion` | West Dread Bastion | −270, 32, −215 | 92 × 82 | terrain (rear bastion, Elite) |
| `EastBastion` | East Dread Bastion | 270, 36, −215 | 92 × 82 | terrain (rear bastion, Elite) |
| `NorthBastion` (extra) | The North Bastion | 0, 40, −320 | 80 × 60 | terrain |
| `CurtainNW` (extra) | North Curtain West | −140, 44, −300 | 72 × 56 | terrain |
| `CurtainNE` (extra) | North Curtain East | 140, 48, −300 | 72 × 56 | terrain |
| `InnerW` (extra) | West Inner Ward | −175, 52, −70 | 64 × 64 | terrain |
| `InnerE` (extra) | East Inner Ward | 175, 56, −70 | 64 × 64 | terrain |
| `Apex` | The Dreadguard Keep | 0, 64, −90 | 144 × 108 | terrain (round, the keep's mound) |

**Paths (25 links):**
- **The Glacis and the Ravelin:** `Sanctuary→Basin` (−8), `Basin→Crossing` (+12), `Basin→CovertW` (+4), `Basin→CovertE` (+8), `Crossing→CovertW` (−8), `Crossing→CovertE` (−4), `Crossing→Sallyport` (+10, 14.63°).
- **Out to the front bastions:** `CovertW→WestGallery` (+12), `CovertE→EastGallery` (+12).
- **Along the curtains:** `WestGallery→CurtainW` (+8), `EastGallery→CurtainE` (+8), `CurtainW→WestBastion` (+8), `CurtainE→EastBastion` (+8).
- **Into the inner wards:** `CurtainW→InnerW` (+28, 14.86°), `CurtainE→InnerE` (+28, 14.86°), `WestBastion→InnerW` (+20, 14.05°).
- **Round the north curtains:** `WestBastion→CurtainNW` (+12), `EastBastion→CurtainNE` (+12), `CurtainNW→NorthBastion` (−4), `CurtainNE→NorthBastion` (−8), `CurtainNW→InnerW` (+8), `CurtainNE→InnerE` (+8), `NorthBastion→Countermine` (−10).
- **Into the keep:** `InnerW→Apex` (`STAIRS`: the West Drawbridge, +12), `InnerE→Apex` (`STAIRS`: the East Drawbridge, +8).

*Styles:*
- Both drawbridges are `Terrain.Bridges` in `"DRAWBRIDGE"` style and are the **only** links that cross the keep's moat.
- `Crossing→Sallyport` is a short iron bridge over the outer ditch.
- The curtain links are wall-walk ramps with crenellated parapets (curbs outside `UsableWidth`).
- Two return ramps climb from the floor onto the Glacis (X ≈ ±311).

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (the Ravelin), `WEST_GALLERY` 5 (Elite, the Bastion of Hooks), `EAST_GALLERY` 5 (Elite, the Bastion of Axes), `UPPER_WEST` 5 (Elite, the West Dread Bastion at Y 32), `UPPER_EAST` 5 (Elite, the East Dread Bastion at Y 36).

**Patrols (authored, `ReplacePatrols = true`):**
- `BASIN_LOOP` (148.1 s)
- `GLACIS` = `{CovertW, Crossing, CovertE}` (100.6 s)
- `WEST_FLANK` = `{WestGallery, CurtainW, WestBastion}` (123.7 s)
- `EAST_FLANK` = `{EastGallery, CurtainE, EastBastion}` (123.7 s)
- `NORTH_WALK` = `{CurtainNW, NorthBastion, CurtainNE}` (113.4 s)
- `INNER_WARD` = `{InnerW, Apex, InnerE}` (141.5 s)

**Portals:** Ascend `(16, 64, −132)`, Rerun `(−16, 64, −132)`.

**Terrain:** `Bottom = −6`, `Surface = "THRONEWARD"`, `Liquid = { Dry = true }`.
- **The fort stands on ground:** the bastions and curtains are raised plateaus (squircle `Shapes` with sheer, battered aprons that read as walls).
- **The outer ditch** runs between the covered way and the bastions.
- **The keep's moat** is a `Terrain.Rifts` loop round the Apex mound (half-width ~14, carved to `Bottom − 4`, the Undertow circling in it). **Only the two drawbridges cross it.** The Sallyport and the Countermine look at the keep across it.
- **Show the keep:** from the arrival camera, the keep's tower must rise over the Ravelin (check from the Sanctuary).
- `NoApexShelf = true`; `WallBand` low behind the North Bastion so the fort's star outline reads against the black vault.

**Landmarks (≥ 22):**
1. **The Dreadguard Keep** (≥ 235 studs with its tower): a squat obsidian keep on its mound with one great square tower rising from its back half. Its gate-towers carry the drawbridge chains, and the Overlord's sword-rack hangs empty in a niche on the tower. The tower stands behind the portal spots and never over the arena. The Alpha's lair; keep the keep's floor clean.
2. **The star fort's bastions:** arrow-head obsidian bastions with iron-capped salients and sentry boxes.
3. **The drawbridges:** iron-banded stair-bridges on chains, the only lit lamps on the walls hanging from their gate-towers.
4. **The moat:** a ring of void round the keep, the Undertow circling it.
5. **The curtain walls:** crenellated wall-walks with shuttered lamps and arrow-slits.
6. **The Ravelin:** a pointed outwork with an iron portcullis that leads nowhere (the fort has no gate).
7. **The covered way:** a sunken walk behind a palisade of iron stakes.
8. **The Bastion of Hooks:** hook-racks, grapnels and a siege-hook crane.
9. **The Bastion of Axes:** the executioners' yard: execution blocks, axe-racks, a whetstone wheel.
10. **The Dread Bastions:** heavy bastions with spiked iron braziers (shuttered) and chained penitents' cages.
11. **The North Bastion:** a lookout over the Countermine with the fort's great iron bell.
12. **The Countermine:** a mine-head where the Dreadguard dug down to meet the void, its winding gear still turning.
13. **The Sallyport:** a postern platform with an iron door into the rock.
14. **The inner wards:** armouries of black plate on stands.
15. **Gibbets and spikes** on the salients (bare iron).
16. **Caged void shards** set in the walls' merlons (the Void Titan Core skin).
17. **Shuttered Wardlights** everywhere on the walls.
18. **The Chained Crown** in iron over the keep's gates.
19. **Sentry statues** of Dreadguard on every salient's point.
20. **The Glacis:** an open killing slope of ash before the walls.
21. **The Iron Postern:** the arrival through a small iron door in the outer wall.
22. Far: the Throne's crimson glow beyond the fort's north wall, the Rift a hairline above it.

**Kit candidates (≥ 14):** `DreadguardKeep` (mound, keep and tower split for clearance), `StarBastionSalient`, `CurtainWallCrenel`, `DrawbridgeStair`, `GateTowerChained`, `RavelinPortcullis`, `IronStakePalisade`, `SiegeHookCrane`, `ExecutionYardSet`, `PenitentCage`, `GreatIronBell`, `MineWindingGear`, `ArmourStandPlate`, `ShutteredWardlight`, `DreadguardSentry`.

**Lighting grade (`FloorGrades[49]`):** iron night.
- A moonless, steel-blue dark: a dim cool ambient, the walls barely lit, warm bone-white only at the drawbridges, a faint crimson glow on the north horizon (sky only).
- `AtmosphereDensity ≈ 0.40`, `AtmosphereHaze ≈ 1.1`, `BloomIntensity ≈ 0.5`, `Saturation ≈ 0.04`, `ColorShift_Top ≈ (176, 186, 214)`.
- Check that every camp and telegraph still reads in the dark.

**Spec asserts:**
- **Room:** key, name and `Size` (`Bottom = −6`, 2 return ramps). `|Apex.X| < 20` and `|Apex.Z| < 150` (dead centre).
- **The drawbridge rule:** the Apex is entered by exactly two links, `InnerW→Apex` and `InnerE→Apex`, both `STAIRS`, one from each side. With both inner wards removed, the Apex is unreachable.
- **The star rule:** no link joins the Basin, the Ravelin, the Coverts or the Sallyport to the Apex or an inner ward directly.
- **Dead ends:** `Sallyport` and `Countermine` each have exactly one link.
- **Camps:** `UPPER_WEST` and `UPPER_EAST` sit above Y 30. 35 mobs and 4 Elites.
- **Patrols:** the authored patrols resolve and stay under 240 s.
- **Validation:** no `Validate` problems.

---

### Floor 50: Overlord's Throne (`abyssal:5`, `BOSS_ARENA`)

*940 × 795 × 370, `Bottom = −6`. The Crimson Eclipse.*

**Guide image:** `reference/Abyssal Throne 50.jpg`.

**Story beat:** the Throne. At the bottom of the Abyss, where every Undertow ends, stands the **Throne** of the Warden-King: built so vast that the whole court could kneel on its steps, and grown vaster since. Its **feet** stand on the **Supplicants' Floor**. Its **greaves** rise like towers, its **armrests** are walled terraces, and its **hands** rest on the armrests' ends, open, the last two Wardlights burning in their palms. On its **seat** the **Crimson Overlord** waits for the oath he swore to be answered. Behind him the Throne's **backrest** rises out of sight into the black, crowned by the Chained Crown, with the **Crimson Eclipse** burning behind it.

**Shape: you climb the Throne itself: its feet, its greaves, its armrests, then onto the seat.**
- **The Grand Stair** up the Throne's front: its old flight lies shattered in the void, but a restored flight climbs on from the **Broken Stair** landing straight to the seat. (Build change: the Broken Stair was a dead end at first; playtesters read it as a missing ramp.) Build change, also from playtesting: Floor 50 is indoors, the inside of the Throne, under a coffered, vaulted roof (`ThroneHallOverhead`); Floor 49's north wall holds the Throne Gate, so the citadel reads as the throne's entrance.
- **The legs (quickest, measured):** the **Supplicants' Floor** → the **Footstool** (Crossing) → the **West** or **East Foot** → that side's **Greave** → its **Armrest** → the **Armrest Stair** (`STAIRS`) onto the seat.
- **The chains:** from the **Hall of Kneeling** (west gallery, Elite) or the **Hall of Oaths** (east gallery, Elite) up to the **West** or **East Mantle Bastion** (Elite, Y 32 and 36). From each Mantle Bastion either cross to its Greave, or climb the Overlord's **mantle-chains** that hang from the Throne's shoulders (the **West** and **East Chain**) to that side's **Hand**, then step from the Hand onto the seat.
- **The Reliquaries:** dead ends at the back corners, off the Chains, where the court keeps the Overlord's relics.

**New to the tower:** the boss arena *is* the landmark: every terrace past the Footstool is part of one colossal Throne, and the Apex is its seat. New traversal: **greave stairs** and **armrest walks** (`BridgeStyles = "THRONE"`: obsidian treads with iron banding and wine-silk runners, set into the Throne's limbs). New landmark type: the Throne's backrest and the Crimson Eclipse.

*Closest earlier shapes:* Ashen 15's route over a fallen giant (climbing a colossal body lying down), Corrupted 35's three converging roots, and Infernal 25's hourglass with side chambers. Here the giant is a throne standing up, the two limbs are mirror routes with a chain climb outside each, and the arena is the seat.

```
                                     N (−Z)
   ┌──────────────────────────────────────────────────────────────────┐
   │ [RELIQUARY W] Y46       ░░ THE BACKREST & THE CHAINED CROWN ░░        [RELIQUARY E] Y50
   │      ▲               [WEST HAND] Y62 ──► [  THE SEAT  ] ◄── [EAST HAND] Y66      ▲      │
   │ [WEST CHAIN] Y44 ─────────▲              [ 212×156 Y72 ]           ▲ ───── [EAST CHAIN] Y48
   │      ▲            [WEST ARMREST] Y52 ═(st)═►          ◄═(st)═ [EAST ARMREST] Y56   ▲  │
   │      |                   ▲                                        ▲             |  │
   │ [W. MANTLE BASTION] Y32 ─ [WEST GREAVE] Y38                [EAST GREAVE] Y42 ─ [E. MANTLE BASTION] Y36
   │      ▲                   ▲            [BROKEN STAIR] Y30           ▲             ▲  │
   │      |              [WEST FOOT] Y20         ▲               [EAST FOOT] Y24     |  │
   │ [HALL OF KNEELING] Y8 ──┘        [ THE FOOTSTOOL ] Y16              └── [HALL OF OATHS] Y12
   │          \                               |                               /       │
   │    ~~~~~~~~~~~~~~~~~~~~~~~~ THE SUPPLICANTS' FLOOR  Y0 ~~~~~~~~~~~~~~~~~~~~~~~    │
   │                                          |                                       │
   │                                  [ THE LAST OATH ] Y8                            │
   └──────────────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Sanctuary` | The Last Oath | 0, 8, 363.5 | 128 × 56 | deck |
| `Basin` | The Supplicants' Floor | 0, 0, 245 | 908 × 104 | terrain |
| `WestGallery` | Hall of Kneeling | −320, 8, 95 | 92 × 80 | terrain (Elite) |
| `EastGallery` | Hall of Oaths | 320, 12, 95 | 92 × 80 | terrain (Elite) |
| `Crossing` | The Footstool | 0, 28, 110 | 96 × 68 | terrain |
| `FootW` (extra) | West Foot | −170, 20, 60 | 72 × 60 | terrain (the Throne's foot) |
| `FootE` (extra) | East Foot | 170, 24, 60 | 72 × 60 | terrain |
| `BrokenStair` (extra) | The Broken Stair | 0, 35, 29 | 64 × 36 | deck (the Grand Stair's landing; the restored flight climbs on to the Seat) |
| `WestBastion` | West Mantle Bastion | −330, 32, −90 | 92 × 82 | terrain (Elite) |
| `EastBastion` | East Mantle Bastion | 330, 36, −90 | 92 × 82 | terrain (Elite) |
| `ShinW` (extra) | West Greave | −200, 38, −40 | 64 × 56 | deck (the greave's top, built) |
| `ShinE` (extra) | East Greave | 200, 42, −40 | 64 × 56 | deck |
| `ChainW` (extra) | West Chain | −350, 44, −230 | 64 × 56 | terrain (the mantle-chain's anchor ledge) |
| `ReliquaryW` (extra) | West Reliquary | −370, 46, −335 | 64 × 52 | deck (dead end) |
| `ChainE` (extra) | East Chain | 350, 48, −230 | 64 × 56 | terrain |
| `ReliquaryE` (extra) | East Reliquary | 370, 50, −335 | 64 × 52 | deck (dead end) |
| `ArmW` (extra) | West Armrest | −190, 52, −150 | 64 × 72 | terrain (the armrest's walled top) |
| `ArmE` (extra) | East Armrest | 190, 56, −150 | 64 × 72 | terrain |
| `HandW` (extra) | West Hand | −200, 62, −265 | 64 × 56 | deck (the open palm) |
| `HandE` (extra) | East Hand | 200, 66, −265 | 64 × 56 | deck (the open palm) |
| `Apex` | The Seat | 0, 72, −200 | 212 × 156 | terrain (round, the largest Apex in the tower) |

**Paths (29 links):**
- **The Supplicants' Floor:** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→Crossing` (+16, 14.76°), `Basin→EastGallery` (+12).
- **The feet:** `WestGallery→FootW` (+12), `EastGallery→FootE` (+12), `Crossing→FootW` (+4), `Crossing→FootE` (+8), `Crossing→BrokenStair` (+7), `BrokenStair→Apex` (+37, the Grand Stair, `STAIRS`). The Footstool rose to Y 28 and the landing moved to Z 29 so the 37-stud flight fits a 15° stair between the landing and the Seat.
- **Up the legs:** `FootW→ShinW` (+18, 14.79°), `FootE→ShinE` (+18, 14.79°), `ShinW→ArmW` (+14, 14.73°), `ShinE→ArmE` (+14, 14.73°).
- **The Mantle Bastions:** `WestGallery→WestBastion` (+24), `EastGallery→EastBastion` (+24), `WestBastion→ShinW` (+6), `EastBastion→ShinE` (+6).
- **Up the chains:** `WestBastion→ChainW` (+12), `EastBastion→ChainE` (+12), `ChainW→HandW` (+18), `ChainE→HandE` (+18), `ChainW→ReliquaryW` (+2), `ChainE→ReliquaryE` (+2).
- **Onto the seat:** `ArmW→HandW` (+10), `ArmE→HandE` (+10), `ArmW→Apex` (`STAIRS`: the West Armrest Stair, +20, 14.81°), `ArmE→Apex` (`STAIRS`: the East Armrest Stair, +16, 14.76°), `HandW→Apex` (+10), `HandE→Apex` (+6).

*Styles:*
- The leg, armrest and hand links are `"THRONE"` style.
- `WestBastion→ChainW`, `ChainW→HandW` and the east mirrors are **chain climbs**: ramps in a black-iron cage that runs up beside a colossal hanging chain, outside `UsableWidth`.
- Two return ramps climb from the floor onto the Supplicants' Floor (X ≈ ±348).

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (the Footstool), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite, the West Mantle Bastion at Y 32), `UPPER_EAST` 5 (Elite, the East Mantle Bastion at Y 36).
- **The boss:** the **Crimson Overlord** is summoned on the `212 × 156` seat.
- **Moves:** **Hellfire Cleave** (`ARC`), **Abyssal Nova** (`SELF_DISC`) and **Doom Pillars** (`TARGET_DISC`) must stay on the seat and never spill onto an Armrest Stair or a Hand.
- **Size:** the Overlord is a colossus. Check in playtest that his crown and mantle stay inside the camera's view of the arena and never clip the backrest.
- **Keep the seat clean:** a dark obsidian floor with a worn bone-white inlay of the Chained Crown, ringed on the outer rim only by the armrests' inner walls.

**Patrols (authored, `ReplacePatrols = true`):**
- `BASIN_LOOP` (165.6 s)
- `SUPPLICANTS` = `{WestGallery, Crossing, EastGallery}`
- `WEST_LEG` = `{FootW, ShinW, ArmW}` (87.6 s)
- `EAST_LEG` = `{FootE, ShinE, ArmE}` (87.6 s)
- `WEST_CHAINS` = `{WestBastion, ChainW, HandW}` (119.3 s)
- `EAST_CHAINS` = `{EastBastion, ChainE, HandE}` (119.3 s)
- `THRONE_SEAT` = `{ArmW, Apex, ArmE}` (159.0 s)

`SUPPLICANTS` does **not** resolve as written: the galleries have no direct link to the Footstool. It was dropped silently in the check. Either reroute it as `{WestGallery, Basin, EastGallery}` or drop it, and confirm in the spec.

**Portals:** Ascend `(16, 72, −266)`, Rerun `(−16, 72, −266)`.

**Terrain:** `Bottom = −6`, `Surface = "THRONEWARD"`, `Liquid = { Dry = true }`.
- **The Supplicants' Floor** is a vast flagged court of black basalt with bone-white kneeling-lines.
- **The feet** are terrain mounds shaped as the Throne's sabatons (squircle `Shapes`).
- **The greaves, hands and reliquaries** are built decks; the **armrests and the seat** are terrain plateaus with `Sheer` aprons, dressed by the Throne kit so the terrain reads as carved obsidian.
- **The Undertow:** every channel in the room runs toward the Throne's base and vanishes into it (client meshes in `Terrain.Rifts` beds along the room's edges, never under a lane).
- `NoApexShelf = true`; `WallBand` low at the back so the backrest stands against the Eclipse.
- **If the backrest's footprint needs the room**, spread the portals (`Portals.Spread`, as on Floors 27 and 29) and say so in the PR.

**Landmarks (≥ 25, plus the colossal centrepiece):**
1. **The Throne's backrest and the Chained Crown (colossal centrepiece, ≥ 320 studs):** a sheer wall of carved obsidian rising behind the seat, ribbed with iron and hung with chains, crowned by the Chained Crown in black iron with its one broken link. It stands at the back wall and beyond, **never overhangs the `212 × 156` arena**, and stays clear of `Layout.PortalSpots`.
2. **The Crimson Eclipse:** a black sun ringed in crimson behind the crown, breathing with the Overlord's heartbeat on the Dirge. Sky and far layer only (§5.7).
3. **The armrests:** walled obsidian terraces running north–south either side of the seat, their inner walls the arena's rim.
4. **The hands:** two colossal iron gauntlets resting open on the armrests' ends, the last two Wardlights burning in their palms. The Hand decks are the palms.
5. **The greaves:** two towering obsidian greaves with iron banding.
6. **The feet:** colossal sabatons planted on the Supplicants' Floor.
7. **The Broken Stair:** the Grand Stair up the Throne's front, shattered, its last landing a dead end facing the seat across the void.
8. **The mantle-chains:** colossal chains hanging from the Throne's shoulders to the Chain ledges, each with a caged climb beside it.
9. **The Mantle Bastions:** the court's last guard-posts, iron and silk.
10. **The Hall of Kneeling:** rows of kneeling stone supplicants facing the Throne.
11. **The Hall of Oaths:** oath-tablets in chains, the court's whole register.
12. **The Footstool:** a colossal footstool of black marble, worn by kneeling.
13. **The Reliquaries:** the Overlord's relics in iron cages (the Heart's reliquary is empty: his heart is still in him).
14. **The Throne's heart:** a crack in the Throne's base glowing with the Overlord's heartbeat (deep, matte red-black, beating on the Dirge, never Neon crimson at walk height).
15. **The Undertow's end:** every violet ribbon in the room running into the Throne's base.
16. **Crimson banners** hanging the full height of the backrest (matte wine silk).
17. **The court's silhouettes** kneeling on the far ledges round the room (far layer).
18. **Bone-white kneeling-lines** inlaid across the Supplicants' Floor.
19. **Iron censers** on the Footstool's corners.
20. **Fallen Dreadguard statues** at the feet, kneeling.
21. **Wardlights** leaning toward the seat everywhere.
22. **The Chained Crown inlay** on the seat floor (bone-white, worn, faint).
23. **The Last Oath:** the arrival under an iron arch carved with the oath the Warden-King swore.
24. **Ash** thickest here, banked against everything on the north side.
25. Far: the Vault black and starless, the Rift gone, only the Eclipse.

**Kit candidates (≥ 15):** `ThroneBackrest` (wall, ribs and crown split for clearance), `ChainedCrownColossal`, `CrimsonEclipseDisc` (client), `ThroneArmrestWall`, `GauntletHandOpen`, `GreaveTower`, `SabatonFoot`, `BrokenGrandStair`, `MantleChainColossal`, `ChainClimbCage`, `KneelingSupplicant`, `OathRegisterWall`, `FootstoolGreat`, `RelicCageIron`, `ThroneHeartCrack`, `BackrestBannerWine`.

**Lighting grade (`FloorGrades[50]`):** the Crimson Eclipse.
- A black-violet ambient, a cold silver-white key on the seat so the Overlord and every telegraph read, and the Eclipse's crimson only in the sky behind the crown.
- `AtmosphereDensity ≈ 0.42`, `AtmosphereHaze ≈ 1.4`, `BloomIntensity ≈ 0.6`, `Contrast ≈ 0.14`, `Saturation ≈ 0.06`, `ColorShift_Top ≈ (200, 196, 214)`.
- **No crimson or orange light on any walk surface**, including the seat.

**Spec asserts:**
- **The Apex:** `212 × 156` at Y 72, the highest terrace, the largest Apex in the tower.
- **Room:** key, name and `Size` (`Bottom = −6`, 2 return ramps). It is the largest and tallest room in the tower.
- **The Throne rule:**
  - the Apex is entered by exactly four links: the two Armrest Stairs (`STAIRS`, one from each side) and the two Hands;
  - `BrokenStair` has two links: up from the Footstool, and the `BrokenStair→Apex` Grand Stair (`STAIRS`) to the Seat;
  - with both Armrests and both Hands removed, the Apex is unreachable.
- **Dead ends:** `ReliquaryW` and `ReliquaryE` each have exactly one link.
- **Arena clearance:** the Apex's landmark footprints stay off the arena and the portal lanes.
- **Camps:** 35 mobs, 4 Elites and the Boss camp.
- **Patrols:** the authored patrols resolve and stay under 240 s.
- **Validation:** no `Validate` problems.

---

### 3.6 Shapes that were tried and pulled in

The walks below were measured with the same probe as the final layouts (Appendix B).

- **Floor 47, a full three-crossing plait** (the columns swap sides three times, the Bier at the back): 2.75×. The plait kept one crossing, and the Bier moved to the centre of the room.
- **Floor 48, a wide saltire** (Anchor Spires at ±195, beads at ±100): 2.75×. Narrowed to ±60 / ±32 (the void is still wall to wall). Then the sag was flattened: a 24-stud climb out of a Keystone at Y 14 pushed the ramp back over the near bead.
- **Floor 48, a direct bead-to-gate link** (`BeadFE→Apex`, with the East Gibbet Ledge linked straight to the gate): the link ran over the Far East Anchor, and the Gibbet Ledge became the quickest way. Dropped.
- **Floor 47, the Shrine of Silk off the Muster** (`Basin→ShrineW`): it ran over the Hall of Sworn. Dropped, and replaced by the Vigil Walk.
- **Outer-aisle shortcuts** (`WestGallery→StationW`, `EastGallery→StationE`): they bypassed the Crossing of Oaths, so the plait stopped mattering. Dropped.

---

## Part 4: Lighting per floor

Add `HubLighting.FloorGrades[46..50]`, each layered over `BiomeGrades[10]` (violet void), as the earlier floors did. `ClockTime` is shared and never changes: show the mood through colour shift, ambient, atmosphere, tint, contrast, bloom and sky decals. No two neighbouring floors may share a mood. Floor 45's rift-eye is black-indigo; Floor 46 must break cleanly from it into grey ash.

| Floor | Mood | Key and ambient | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 46 | Ash-fall dusk | A pale bone key from the Rift's wound, dark violet ambient | `Density ~0.34`, `Haze ~1.2` | The Undertow glowing below; pages falling |
| 47 | Crimson vigil | A low cool ambient, bone-white pools under the Wardlights | `Density ~0.36`, `Haze ~1.0`, `Bloom ~0.45` | Wine silk; crimson only far and high |
| 48 | Void-glare | A black vault, cold violet up-light from the void | `Density ~0.38`, `Haze ~1.3`, `Bloom ~0.55` | Chains lit from below; the Keystone's lamp |
| 49 | Iron night | A steel-blue dark, warm only at the drawbridges | `Density ~0.40`, `Haze ~1.1`, `Bloom ~0.5` | Shuttered walls; a crimson glow on the north horizon |
| 50 | The Crimson Eclipse | A black-violet ambient, a silver key on the seat | `Density ~0.42`, `Haze ~1.4`, `Bloom ~0.6` | The Eclipse behind the crown; the Throne's heartbeat |

Keep each floor at ≤ 24 lights. Effects are client-only, pooled and quality-scaled.

---

## Part 5: Engineering

### 5.1 Room sizing, the black vault and depth

`TowerLayout` already supports `Size = { Width, Depth, Height, Bottom? }`, and every consumer reads the built layout's dimensions. `HubLighting.TowerFloorAt` (2,400-stud grid) holds `940 × 795`.

**All five Abyssal rooms are open to the black vault** (no ceiling, a starless sky dome), so add `abyssal_throne` to `TowerRoomBuilder`'s `isNatural` test (about line 530) with Floor 46's PR, gated to authored layouts exactly as Astral did: `(floorSpec.BiomeId == "abyssal_throne" and layout.Authored ~= nil)`. Check that Floors 1–45 stay byte-identical.

The generic `abyssal_throne` pieces must stand down on authored floors, as the Astral ones did (`astralFloor`): the backdrop `spire` and `ChainedSpire` branches in `TowerBiomeAssets`, and the teal `AbyssalTealMist` sub-floor sea. The teal mist is also off-palette for this plan.

`Bottom` stays at `−4` (46–47) and `−6` (48–50), so the Basin return ramps stay under 15° (§2.1). The abyss's depth is sold by the black vault, the Undertow's up-light, fog and the void meshes, not by a deep floor. Set `VoidCatchY` on every floor whose void a squad can fall into (46, 48, 50 at least), as Floors 41–45 do. Without it, a fallen squad walks back to the return ramps across a dark floor.

### 5.2 Set pieces

Each floor gets its own module, `ServerScriptService/Core/TowerSetPieces/AbyssalFloor<N>.luau`, mirroring the `AstralFloor4x` modules. Each exports its landmark footprints (`Landmarks`, `Straddles = true` for a gate that spans a walkway on purpose) for offline lane and camp checks.
- Use the shared helpers: `piece`, `group`, `kitAt`, `onTerrain`, `groundY` and `wallFoot`.
- Positions in a floor block are room-local: add `origin` when you set `.CFrame` yourself.
- **Pin hanging pieces:** pieces that hang by design (Wardlights on chains, the great chains, the beads' hangers, gibbet cages, the mantle-chains, the gauntlets) must be pinned `OnTerrain` or listed in `AirborneKinds`, or the settle pass drops them (Floor 31 lesson).
- Client effects (the Undertow, the Upfall, the Eclipse, ash, pages, motes) are never server props.

### 5.3 Terrain, surface and materials

**Materials are place-wide.**
- Never use or recolour Fungal-owned materials (`Cobblestone`, `Concrete`, `Pavement`, `Asphalt`).
- Never recolour shared `MaterialColors`.
- Never use `TowerTerrain.BlockyMaterials` (`Brick`, `WoodPlanks`): Roblox collides them as 4-stud steps.
- **Never use `CrackedLava` here**, even though `Palettes.abyssal_throne.Liquid` names it. It is the Infernal floors' orange lava, and in this biome it reads as an enemy telegraph (§5.7). Every Abyssal floor sets `Liquid = { Dry = true }`, and the Undertow is a mesh (below).

Two new entries in `TowerTerrain.Surfaces`, using only uncoloured or already-coloured shared materials (`Basalt` is the shared dark grey; `Slate`, `Limestone` and `Salt` have no `MaterialColors` entry, so they render their default pale tones):
- `VAHL` (46–47): `Trail = Limestone` (bone-white flags), `Walk = Basalt`, `WalkAccent = Slate`, `Bank = Slate`, `Cliff = Basalt`, `Peak = Basalt`, `PoolBed = Basalt`, `Lush = Slate`.
- `THRONEWARD` (48–50): `Trail = Limestone`, `Walk = Basalt`, `WalkAccent = Basalt`, `Bank = Basalt`, `Cliff = Basalt`, `Peak = Basalt`, `PoolBed = Basalt`, `Lush = Basalt`. The pale trails are the only light ground; the court's flags narrow as you near the Throne.

Add a spec that both surfaces avoid blocky, Fungal-owned and `CrackedLava` materials. Mud stays out of both (its rippled texture reads as liquid).

**Reuse before adding.** `Shapes[id].Float`, `Shapes[id].Scarp`, `Sheer`, `Terrain.Rifts`, `Terrain.Bridges` and `BridgeStyles` all exist on `main`.
- **`Terrain.Rifts`** carves the braid (46), the Bier's ring (47), the void (48), the keep's moat (49) and the Undertow's channels (50).
- **47 and 49 need a closed loop:** if `Rifts` can't close a loop yet, add a `Loop = true` option, a ring that never runs under a link except a bridge.
- **New `BridgeStyles`,** each drawn outside `UsableWidth`, each documented in `docs/TOWER_NAVIGATION.md` in its floor's PR:
  - `"CHAINFORD"` (46): a low iron grate on chains;
  - `"PROCESSIONAL"` (47): obsidian with a matte wine-silk runner, statue rows outside the walk;
  - `"CATENARY"` (48): a hung iron deck, the chain overhead;
  - `"DRAWBRIDGE"` (49): an iron-banded stair-bridge on chains;
  - `"THRONE"` (50): obsidian treads banded in iron.

**The Undertow is a mesh, not terrain.** Each river bed is dark basalt carved by `Rifts`. The Undertow itself is one client-side mesh per channel with a scrolling violet texture running *toward the Throne*, ≥ 2 studs under every walk surface. Use an invisible `PointLight` anchor every ~80 studs, counted in the light budget. No terrain liquid, no flat semi-transparent boxes.

### 5.4 Kits: enough meshes for the ladder

1. **Reuse first:**
   - `ObsidianSpire` (spires, far layer), `HangingAbyssChain` and `AbyssReliquaryShrine` (the Sunken abyss pieces);
   - `ChainAnchorBollard`, `ChainTowerRound`;
   - `GatehouseArch`, `CurtainWallRuins`, `VaultRibArch`, `GothicPillarColonnade`;
   - `HangingLantern` (retinted iron for Wardlights), `StoneUrn`, `RuinRubble`, `BoulderCluster`;
   - the Thunder `CurtainWallSegment` and `StormkeepRoundTower` (retinted obsidian) where a wall or round tower fits.
2. Generate each floor's new templates with `tools/blender/generate_abyssal_f<N>_kit.py` → `assets-source/tower/abyssal_f<N>_kit/` (FBX, .blend, `manifest.json`, previews). **Commit the generator.**
3. Register every template in `TowerBiomeKit.ExtraTemplates` only (Size, Min, Roles from the manifest). Names must be unique across all kits. Add only big architectural pieces to `CastsShadow`.
4. **No new colour roles** unless a floor proves it needs one:

   | Role | Colour |
   | --- | --- |
   | `STONE` | Obsidian |
   | `ALT` | Bone-white marble |
   | `METAL` | Blackened iron |
   | `TRIM` | Dark iron and chain |
   | `SILK` | Wine crimson silk |
   | `ACCENT` | Old gold, used sparingly (the Chained Crown's rim) |
   | `GLOW` | Wardlight bone-white |
   | `CRYSTAL` | Blood-red geode crystal or caged void, matte or low-emission |
   | `MOSS` | Ash |

   Each floor passes a full tint table (in `TowerSetPieces/AbyssalFloor<N>.luau`), so no template falls back to the biome palette.
5. Every template gets a part-built fallback in `TowerBiomeAssets` until it is imported (`TowerKitProps.Has(name)`). **Rebuild and recount after import:** a kit mesh's clearance box is the whole template per colour role, so the tall pieces reach lanes that the fallback never did (Corrupted lesson 1). The tall pieces here are the Upfall, the Effigy, the Anchor Spires, the great chains, the keep's tower and the backrest.
6. **Uploading a kit creates permanent Roblox assets: ask the user before each upload.** On a yes: upload the FBX, insert it, run `tests/studio-tower-biome-kit-import.luau`, and ask the user to save the place.

### 5.5 Lessons from Floors 1–45 (each came from a real fix)

1. **Clearance removes a whole prop group if one part fails, silently.** Count every floor's set pieces after each build (`studio-verify.luau`). Fix a removed piece by moving or turning it, **never** by raising it on a plinth.
2. **Camp clearance is centre-based and wide** (34 studs from a camp centre, 7 from a mob slot): a gate straddling the lane in front of a camp gets deleted. Floor 29 moved its barbican off the camp's terrace for this. Plan the Ravelin's portcullis (49), the Station Stairs' statue rows (47) and the Footstool's censers (50) with that radius in mind.
3. **Big kit meshes have big boxes.** Split the Upfall, the Effigy, the Anchor Spires, the keep and the backrest into parts, and spec-check each footprint offline before Studio.
4. **Portal lanes are walkways.** A landmark behind the Apex can't cover the portal lanes (half-width 10 from each spot): Floors 27 and 29 spread the portals with `Portals.Spread` to fit their keeps. Check the Effigy (47), the keep's tower (49) and the backrest (50).
5. **Natural, not stacked.** Statues, gibbets and Wardlight posts stand on `groundY` of their terrace with ash and rubble at the foot. Never stand a spire on a block. Use round or lens `Shapes`, not square plinths.
6. **No fake bridges.** Where two terraces have no link, the gap must read as impassable. No chain, banner or statue row may look walkable across it:
   - Floor 47's Mourners' Gallery to the Bier;
   - Floor 48's void away from the chains and the Gibbet Ledges;
   - Floor 49's moat away from the drawbridges;
   - Floor 50's Broken Stair to the seat.
7. **No flat semi-transparent boxes** for the Undertow, glow, the void, the Eclipse or ash. Use sculpted meshes, texture-scrolled surfaces, particles and invisible `PointLight` anchors.
8. **Never blocky materials** (`Brick`, `WoodPlanks`) on terrain, and never `CrackedLava` in this biome.
9. **Check pitch signs** on toppled statues, leaning Wardlights, chains, the gauntlets and the Effigy, so nothing slopes the wrong way or floats.
10. **Terrain terraces on multiples of 4.** Only decks sit at other heights.
11. **Overheads versus the camera:** the great chains, the drawbridge chains, the backrest's chains and every banner stay ≥ 18 studs clear over walk surfaces and never overhang the Floor 50 arena.
12. **Small clutter is non-collidable** (`CanCollide`, `CanQuery` and `CastShadow` all false), and grounding raycasts include `workspace.Terrain` with `IgnoreWater = true`.
13. **≤ 24 lights per floor.** Count after every build. Wardlights are mostly `Neon` with no light; only the route's key lamps carry a `PointLight`.
14. **Perimeter props go at the foot of the walls, never on the cliff** (`wallFoot`, Floor 31).
15. **Explicit-height pieces must be pinned** `OnTerrain` or listed in `AirborneKinds` (Floor 31): lamps, chains, cages, gauntlets.
16. **Stale terrain in Studio captures** (Floor 36): after a probe rebuild, set `workspace.CurrentCamera.CFrame` in `execute_luau`, wait ~6 s, then capture with no camera arguments, before judging terrain from a screenshot.
17. **Long builds drop the Studio MCP call** (Floors 28–29). Start the build in a `task.spawn` that writes its result to `_G`, then read it in a second call. Floor origins are `X = 12000 + ((id − 1) % 10) × 2400`, `Z = 12000 + floor((id − 1) / 10) × 2400`, `Y = 1000`, not the formula in `studio-verify.luau`. Floor 46 is `(24000, 1000, 21600)`, Floor 50 `(33600, 1000, 21600)`. Confirm from the built model's pivot.
18. **Edit-mode module caching** (Floors 28–29): `TowerBiomeAssets` is too large to patch by string. Rename the synced `TowerLayout` to `TowerLayout_cached`, clone a fresh `TowerLayout` beside it for the probe, and restore the name afterwards. Rojo keeps syncing to the renamed instance.

### 5.6 The Dirge (client-only)

- One client module (`StarterPlayerScripts/Rendering/Dirge.luau`) that runs **only** while the local player is on Floors 46–50.
- Synchronised from `workspace:GetServerTimeNow()`, so every player sees the same toll with zero remotes. The cycle tightens from about 16 s on Floor 46 to about 6 s on Floor 50.
- **On each toll,** acting on `CollectionService`-tagged parts, meshes and emitters with strict instance caps:
  - play one far bell;
  - surge the Undertow's texture speed and brightness toward the Throne;
  - flare and lean the tagged Wardlights, then settle them;
  - draw the tagged chains taut (a small client tween on dressing only), then slacken them;
  - lift the ash and page emitters toward the back of the room;
  - add a small bloom nudge (`+0.05..0.1`, never a screen flash).
- **On Floor 50,** the toll is answered by a double heartbeat from the Throne: the Eclipse and the Throne's heart-crack pulse once, deep red-black, never bright crimson.
- **Zero gameplay effect.** At the lowest Graphics quality only the bell and the Undertow surge run.

### 5.7 Telegraph readability (read this first)

Enemy telegraphs are crimson `(255, 25, 55)` and orange `(255, 95, 40)` (`EntityRenderer`). The Relic Rain event's meteor warning is a **3 s purple disc** on a ramp (GDD §3.3). This biome's motif is crimson and void violet, which means **its two signature colours are the two colours the player must never confuse with danger.** These rules are not negotiable:

- **Walk surfaces glow bone-white or silver, nothing else.** Wardlights, trail flags and every glow within 20 studs above a walk surface: hue 30°–60°, saturation ≤ 0.2.
- **Crimson is cloth, not light.** Banners, runners, veils and capes are matte `Fabric` in deep wine (around `(118, 22, 36)`; value ≤ 0.5), never `Neon`, never a `PointLight`.
- **Emissive crimson lives only in the sky and the far layer:** the Eclipse, the far ledges' glow, the top of the backrest. It is always ≥ 30 studs above the nearest walk surface and never inside a camp's view cone at gameplay camera height. The Overlord's sword is a mob visual and keeps its crimson.
- **Void violet stays off walk surfaces:** it lives in the Undertow's beds, the Upfall, the void under the chains, the moats and the sky. Never on a terrace, ramp, bridge deck or stair, so a Relic Rain disc always reads.
- **No orange anywhere.** No fire: the Vahl's lamps are bone-white, their braziers shuttered or cold, and `CrackedLava` is banned (§5.3).
- **Keep camp floors and the Floor 50 seat dark and uncluttered:** obsidian and basalt with faint bone-white inlay, so ground telegraph discs read.
- **Check the support glows:** the Void Hierophant's `MEND` beam and the Void Invoker's orb must still read against the Undertow. Adjust the environment, not the effect.
- **In playtest, check every telegraph at gameplay camera height:**
  - Abyss Reaver arcs;
  - Void Invoker bolts, especially their floor corridor warning on a `"CATENARY"` deck over the void's glow;
  - Throne Executioner arcs and ground areas;
  - the Crimson Overlord's Hellfire Cleave, Abyssal Nova and Doom Pillars on the seat.

### 5.8 Performance

- **Instance, don't model.** Reuse MeshIds across terraces. Ground cover (ash drifts, bone rubble, pages, small chain) uses multi-clump meshes with `CastShadow`, `CanCollide` and `CanQuery` off, tagged `TowerDetail`, so the culler hides them past about 220 studs or at low quality. Landmarks are never culled.
- Lights ≤ 24 per floor. Particle emitters ≤ 12 on Floors 46–48 and ≤ 16 on Floors 49–50, all pooled and quality-scaled.
- The Vault, the Undertow, the Upfall and the Eclipse are single meshes with scrolling textures, not particle walls.
- The great chains are the new cost: build each as a few long kit segments, not hundreds of links.
- Targets: ≥ 45 FPS in full camp fights on Floors 46–50 and ≥ 40 FPS in the Crimson Overlord fight at the lowest Graphics quality (MicroProfiler). Report the numbers in each PR.

### 5.9 Data and saves

Layouts are not persisted. No profile schema change and no `DataManager.SyncProfile` migration.

---

## Part 6: Process, tests and docs

### Per floor (lowest first, one PR each)

1. **Ask for the floor's guide image** (skill step 2) and update that floor's section here with what you take from it and what you leave out.
2. Branch `feat/abyssal-throne-floor-<N>` from `origin/main`.
3. Layout (`AUTHORED[N]`, from Appendix A). Re-run the probe from Appendix B after any change.
4. Kit (reuse, then Blender), set pieces, terrain and lighting grade.
5. Tests and docs (below). Run the suites.
6. **Studio verification** (`studio-verify.luau`): probe build `Builder.Build(N, ...)`.
   - **The pass bar:** no new `Validate` problems; every spawn and portal grounded; every link walkable both ways; every set piece present; ≤ 24 lights.
   - **Screenshots:** from the arrival, from the Apex and of each landmark. Compare them with the guide image and the neighbouring floors, and show the user.
   - **Clean up:** clear the probe terrain, `workspace.TowerRooms` and the probe folders, and restore `TowerLayout` if you renamed it. Never use `ChangeHistoryService:Undo` to revert.
7. **Ship:**
   - `git fetch origin` and merge `origin/main`. On conflicts, use `git merge-file --diff3 --diff-algorithm=histogram`, then check every junction where two floors' tables meet.
   - Commit `feat(tower): author Abyssal Throne floor N (<Name>)`, and open the PR into `main`.

The five floors share code (`AUTHORED`, `TowerTerrain.Surfaces`, `TowerRoomBuilder`'s natural-room list and `BridgeStyles`, `TowerBiomeKit`, `HubLighting.FloorGrades`, `docs/TOWER_NAVIGATION.md`). Merge `origin/main` often. Build any `Rifts` loop option with Floor 47 and reuse it on Floor 49.

### Tests

```bash
pwsh tests/run.ps1
```

(If the Luau CLI isn't installed, ask before downloading it.) Extend:
- **`tower-layout-variants.spec.luau`:**
  - for each floor, a "Floor N is the hand-authored ..." test (key, name, `Size`, links and kinds, the camp count, and the floor's defining rule from its **Spec asserts** above) and a "Floor N's terrain is the walking surface" test;
  - **the ladder test:** across 46–50, room area, room height, terraces, links, height levels and Apex Y strictly increase; every floor beats Floors 1–45 at its index; no two terraces on a floor share a height; no terrain terrace is off the 4-stud grid; Floor 50 has the largest room and the largest Apex in the tower.
- **`tower-patrols.spec.luau`:** Floors 48–50's authored patrols resolve, stay on walkways and loop in under 240 s.
- **`tower-portals.spec.luau`:** the portal spots are grounded on every Apex, and no landmark footprint covers them.
- **`tower-biome-kit.spec.luau`:** every new template exists, stands on its origin and uses known roles. `FloorGrades[46..50]` exist. `VAHL` and `THRONEWARD` use no `BlockyMaterials`, no Fungal-owned materials and no `CrackedLava`.
- **A colour spec:** no part a Floor 46–50 set-piece module builds within 20 studs above a walk surface is `Neon` with a hue in 330°–30° or 260°–300°. This is the §5.7 rule, checked offline over the modules' fallbacks and tint tables.
- **Regression:** Floors 1–45 unchanged.

### Docs (same PR as each floor)

- `docs/GAME_DESIGN.MD` §3.3: the floor's bullet under hand-authored floors. With Floor 46, also add a short paragraph on the Vahl, the Warden-King, the Undertow, the Wardlights and the Dirge.
- This file: the floor's status line, plus anything that changed in the build.
- `docs/TOWER_NAVIGATION.md`: any new terrain option or bridge style (`Rifts` loops, `CHAINFORD`, `PROCESSIONAL`, `CATENARY`, `DRAWBRIDGE`, `THRONE`), and `VoidCatchY` if its use changes.
- `reference/infinite_towers_biomes.md` §10: with Floor 46, a short paragraph on the Vahl, the Chained Crown and the Dirge.

### Studio checklist for the user (end of each floor's PR)

1. Arrive out of aggro on the Basin. Walk every route to the Apex: no invisible gaps, no blocky steps, nothing floating that shouldn't, nothing on a walkway.
2. **Floor 46:** see the Upfall from the Fallstair. Cross the braid on the chain-fords both ways, and confirm the Undertow runs *uphill*. Step into a channel on purpose and check you are returned.
3. **Floor 47:** confirm the Bier can't be reached from the Mourners' Gallery. Walk both columns through the Crossing of Oaths and onto the Bier from both Station Stairs.
4. **Floor 48:** see the saltire from the arrival. Walk down to the Keystone and up the far chain, then take a Gibbet Ledge the long way. Step off a bead on purpose and check you are returned.
5. **Floor 49:** confirm the keep's tower shows over the Ravelin from the arrival. Confirm the moat can only be crossed by the drawbridges, and reach the keep from both sides.
6. **Floor 50:**
   - Climb both legs and both chains to the seat.
   - Summon the **Crimson Overlord**: Hellfire Cleave, Abyssal Nova and Doom Pillars must stay on the seat and read clearly.
   - The backrest and crown must never cover the camera in the fight.
   - Ascend and Rerun must rise clear.
7. **Telegraphs:** every telegraph reads against the bone-white, wine and violet, nothing on a walk surface reads as crimson, orange or purple, and a Relic Rain disc reads on every bridge style.
8. **The Dirge** matches across clients, builds from Floor 46 to 50, never flashes, and stops on leaving the biome.
9. **Squad follow and recall** (`E`) work across every chain-ford, processional stair, catenary span, drawbridge and Throne walk.
10. **Frame rate** at the lowest Graphics quality: ≥ 45 FPS in camp fights and ≥ 40 FPS in the Crimson Overlord fight.

## Out of scope

- Other biomes (Floors 1–45 stay unchanged).
- What Floor 50's Ascend leads to: it keeps today's behaviour.
- Teleporting links, new enemies, boss moves, extra mobs for bigger rooms, fall damage or void hazards that deal damage (the void only catches you), and Dirge effects on combat.
- Changes to rewards, relic drops, mob stats, camp respawn timing or the tower difficulty curve.

## Status

- **2026-11-25:** plan written. The Part 3 layouts were validated offline against `origin/main`'s `TowerLayout` (`2018a84`) with the official Luau CLI:
  - 0 new `Validate` problems on all five floors;
  - walks 2.03× / 2.06× / 1.93× / 2.04× / 1.68×;
  - every patrol under 240 s (Floor 50's `SUPPLICANTS` doesn't resolve as written, see Floor 50).

- **Floor 46 (`feat/abyssal-throne-floor-46`):** built `AbyssalF46Kit` (15 templates, `tools/blender/generate_abyssal_f46_kit.py`), `AbyssalFloor46.luau` (20 landmarks, 172-stud Upfall), `Dirge.luau` / `DirgeRuntime.client.luau`, `Surfaces.VAHL` / `Surfaces.THRONEWARD`, `CHAINFORD` bridges, `AUTHORED[46]` and `FloorGrades[46]`, verified offline via `tests/run.ps1` and `rojo build`. Awaits Studio Kit upload approval & live Studio playtest.
- **Floor 47 (`feat/abyssal-throne-floor-47`):** built `AbyssalF47Kit` (15 templates, `tools/blender/generate_abyssal_f47_kit.py`), `AbyssalFloor47.luau` (22 landmarks, 186-stud arched Effigy on Bearers), `Terrain.Rifts` `Loop = true`, `PROCESSIONAL` stairs/bridges, `AUTHORED[47]` and `FloorGrades[47]`, verified offline via `tests/run.ps1` and `rojo build`. Awaits Studio Kit upload approval & live Studio playtest.
- **Floor 48 (`feat/abyssal-throne-floor-48`):** built `AbyssalF48Kit` (15 templates, `tools/blender/generate_abyssal_f48_kit.py`), `AbyssalFloor48.luau` (26 landmarks, 214-stud Anchor Spires), `Surfaces.THRONEWARD`, `CATENARY` suspended decks, `VoidCatchY = -3.5`, `AUTHORED[48]` and `FloorGrades[48]`, verified offline via `tests/run.ps1` and `rojo build`. Awaits Studio Kit upload approval & live Studio playtest.
- **Floor 49 (`feat/abyssal-throne-floor-49`):** built `AbyssalF49Kit` (16 templates, `tools/blender/generate_abyssal_f49_kit.py`), `AbyssalFloor49.luau` (28 landmarks, 244-stud Dreadguard Keep Tower), star-fort bastion layout with closed-loop moat & `DRAWBRIDGE` stairs, `AUTHORED[49]` and `FloorGrades[49]`, verified offline via `tests/run.ps1` and `rojo build`. Awaits Studio Kit upload approval & live Studio playtest.
- **Floor 50 (`feat/abyssal-throne-floor-50`):** built `AbyssalF50Kit` (16 templates, `tools/blender/generate_abyssal_f50_kit.py`), `AbyssalFloor50.luau` (32 landmarks, 334-stud `ThroneBackrest` + `CrimsonEclipseDisc`), `THRONE` bridges/stairs, dropped invalid `SUPPLICANTS` patrol per §3.5, `AUTHORED[50]` and `FloorGrades[50]`, verified full 46–50 escalation ladder & all 50 floors offline via `tests/run.ps1` and `rojo build`. Awaits Studio Kit upload approval & live Studio playtest.

---

## Appendix A: validated `AUTHORED` skeletons

Layout fields only, exactly as validated on 2026-11-25. Each floor's PR adds `PathStyle`, `Names`, `Liquid = { Dry = true }` and the full `Terrain = {...}` (with `Direct = true`, `Surface`, `Shapes`, `Rifts`, `Bridges`, `BridgeStyles` and the floor's new options) around these. `Terrain.Decks` lists the deck terraces the grid check expects. Floor 50's `SUPPLICANTS` patrol is shown as validated; fix it as described in Floor 50.

```lua
[46] = {
	Key = "abyssal:1", Name = "Abyssal Descent",
	Size = { Width = 640, Depth = 640, Height = 240, Bottom = -4 },
	Basin = { X = 0, Y = 0, Z = 180, Width = 608, Depth = 96 },
	WestGallery = { X = -175, Y = 8, Z = 55, Width = 84, Depth = 76 },
	EastGallery = { X = 175, Y = 4, Z = 55, Width = 84, Depth = 76 },
	Crossing = { X = 0, Y = 12, Z = 60, Width = 76, Depth = 64 },
	ExtraPlatforms = {
		EyotW = { X = -100, Y = 16, Z = -45, Width = 60, Depth = 76 },
		EyotC = { X = 0, Y = 14, Z = -55, Width = 52, Depth = 60 },
		EyotE = { X = 100, Y = 20, Z = -45, Width = 60, Depth = 76 },
		ShoalW = { X = -215, Y = 22, Z = -120, Width = 60, Depth = 76 },
		ShoalC = { X = 0, Y = 24, Z = -160, Width = 64, Depth = 72 },
		ShoalE = { X = 215, Y = 28, Z = -120, Width = 60, Depth = 76 },
		HeadC = { X = 25, Y = 30, Z = -262, Width = 56, Depth = 52 },
		HeadE = { X = 160, Y = 32, Z = -245, Width = 64, Depth = 60 },
	},
	Apex = { X = -150, Y = 40, Z = -240, Width = 120, Depth = 88 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "Crossing" }, { "Basin", "EastGallery" },
		{ "WestGallery", "EyotW" }, { "Crossing", "EyotW" }, { "Crossing", "EyotE" }, { "EastGallery", "EyotE" },
		{ "Crossing", "EyotC" },
		{ "EyotW", "ShoalW" }, { "EyotW", "ShoalC" }, { "EyotC", "ShoalC" }, { "EyotE", "ShoalC" }, { "EyotE", "ShoalE" },
		{ "ShoalW", "Apex" }, { "ShoalC", "HeadC" }, { "ShoalE", "HeadE" }, { "HeadC", "Apex" }, { "HeadE", "HeadC" },
	},
	Stairs = { HeadC_Apex = true },
	Terrain = { Decks = { Sanctuary = true, EyotC = true, ShoalW = true, HeadC = true } },
},
[47] = {
	Key = "abyssal:2", Name = "Crimson Procession",
	Size = { Width = 700, Depth = 700, Height = 265, Bottom = -4 },
	Basin = { X = 0, Y = 0, Z = 210, Width = 668, Depth = 96 },
	WestGallery = { X = -110, Y = 8, Z = 95, Width = 84, Depth = 72 },
	EastGallery = { X = 110, Y = 12, Z = 95, Width = 84, Depth = 72 },
	Crossing = { X = 0, Y = 16, Z = 20, Width = 80, Depth = 64 },
	ExtraPlatforms = {
		ShrineW = { X = -200, Y = 4, Z = 122, Width = 64, Depth = 56 },
		ShrineE = { X = 200, Y = 6, Z = 122, Width = 64, Depth = 56 },
		Mourners = { X = 0, Y = 22, Z = -60, Width = 60, Depth = 40 },
		StationW = { X = -145, Y = 28, Z = -55, Width = 68, Depth = 60 },
		StationE = { X = 145, Y = 32, Z = -55, Width = 68, Depth = 60 },
		ChapelW = { X = -270, Y = 20, Z = -85, Width = 60, Depth = 52 },
		ChapelE = { X = 270, Y = 24, Z = -85, Width = 60, Depth = 52 },
		VigilW = { X = -215, Y = 36, Z = -235, Width = 64, Depth = 56 },
		VigilE = { X = 215, Y = 40, Z = -235, Width = 64, Depth = 56 },
		Ossuary = { X = 0, Y = 40, Z = -290, Width = 72, Depth = 56 },
	},
	Apex = { X = 0, Y = 48, Z = -160, Width = 120, Depth = 92 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "EastGallery" },
		{ "WestGallery", "Crossing" }, { "EastGallery", "Crossing" },
		{ "WestGallery", "ShrineW" }, { "EastGallery", "ShrineE" },
		{ "Crossing", "StationW" }, { "Crossing", "StationE" }, { "Crossing", "Mourners" },
		{ "StationW", "Apex" }, { "StationE", "Apex" },
		{ "StationW", "ChapelW" }, { "StationE", "ChapelE" },
		{ "ShrineW", "ChapelW" }, { "ShrineE", "ChapelE" },
		{ "ChapelW", "VigilW" }, { "ChapelE", "VigilE" },
		{ "VigilW", "Ossuary" }, { "VigilE", "Ossuary" }, { "VigilW", "VigilE" },
	},
	Stairs = { StationW_Apex = true, StationE_Apex = true },
	Terrain = { Decks = { Sanctuary = true, ShrineE = true, Mourners = true } },
},
[48] = {
	Key = "abyssal:3", Name = "Voidspan Crossing",
	Size = { Width = 760, Depth = 760, Height = 295, Bottom = -6 },
	Basin = { X = 0, Y = 0, Z = 238, Width = 728, Depth = 100 },
	WestGallery = { X = -215, Y = 8, Z = 100, Width = 88, Depth = 76 },
	EastGallery = { X = 215, Y = 16, Z = 100, Width = 88, Depth = 76 },
	Crossing = { X = 0, Y = 24, Z = 115, Width = 84, Depth = 64 },
	ExtraPlatforms = {
		AnchorNW = { X = -60, Y = 28, Z = 30, Width = 64, Depth = 52 },
		AnchorNE = { X = 60, Y = 32, Z = 30, Width = 64, Depth = 52 },
		BeadNW = { X = -32, Y = 26, Z = -35, Width = 52, Depth = 44 },
		BeadNE = { X = 32, Y = 30, Z = -35, Width = 52, Depth = 44 },
		Keystone = { X = 0, Y = 25, Z = -105, Width = 60, Depth = 52 },
		BeadFW = { X = -32, Y = 29, Z = -175, Width = 52, Depth = 44 },
		BeadFE = { X = 32, Y = 31, Z = -175, Width = 52, Depth = 44 },
		AnchorFW = { X = -60, Y = 40, Z = -240, Width = 64, Depth = 52 },
		AnchorFE = { X = 60, Y = 44, Z = -240, Width = 64, Depth = 52 },
		GibbetW = { X = -295, Y = 36, Z = -100, Width = 60, Depth = 52 },
		GibbetE = { X = 295, Y = 20, Z = -100, Width = 60, Depth = 52 },
		Spireward = { X = -60, Y = 48, Z = -322, Width = 64, Depth = 52 },
	},
	Apex = { X = 170, Y = 56, Z = -305, Width = 112, Depth = 84 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "Crossing" }, { "Basin", "EastGallery" },
		{ "WestGallery", "AnchorNW" }, { "Crossing", "AnchorNW" }, { "Crossing", "AnchorNE" }, { "EastGallery", "AnchorNE" },
		{ "AnchorNW", "BeadNW" }, { "BeadNW", "Keystone" }, { "AnchorNE", "BeadNE" }, { "BeadNE", "Keystone" },
		{ "Keystone", "BeadFW" }, { "Keystone", "BeadFE" }, { "BeadFW", "AnchorFW" }, { "BeadFE", "AnchorFE" },
		{ "AnchorFE", "Apex" }, { "AnchorFW", "Spireward" }, { "Spireward", "Apex" },
		{ "WestGallery", "GibbetW" }, { "GibbetW", "AnchorFW" }, { "EastGallery", "GibbetE" }, { "GibbetE", "AnchorFE" },
		{ "AnchorNW", "AnchorNE" },
	},
	Stairs = { AnchorFE_Apex = true },
	Patrols = {
		NEAR_RIM = { "WestGallery", "AnchorNW", "AnchorNE", "EastGallery" },
		WEST_CHAIN = { "AnchorNW", "BeadNW", "Keystone" },
		EAST_CHAIN = { "AnchorNE", "BeadNE", "Keystone" },
		FAR_CHAIN = { "BeadFW", "Keystone", "BeadFE" },
	},
	ReplacePatrols = true,
	Terrain = { Decks = { Sanctuary = true, BeadNW = true, BeadNE = true, Keystone = true, BeadFW = true, BeadFE = true } },
},
[49] = {
	Key = "abyssal:4", Name = "Dreadguard Citadel",
	Size = { Width = 840, Depth = 795, Height = 320, Bottom = -6 },
	Basin = { X = 0, Y = 0, Z = 240, Width = 808, Depth = 104 },
	WestGallery = { X = -265, Y = 16, Z = 75, Width = 92, Depth = 80 },
	EastGallery = { X = 265, Y = 20, Z = 75, Width = 92, Depth = 80 },
	Crossing = { X = 0, Y = 12, Z = 110, Width = 88, Depth = 68 },
	WestBastion = { X = -270, Y = 32, Z = -215, Width = 92, Depth = 82 },
	EastBastion = { X = 270, Y = 36, Z = -215, Width = 92, Depth = 82 },
	ExtraPlatforms = {
		CovertW = { X = -125, Y = 4, Z = 120, Width = 60, Depth = 52 },
		CovertE = { X = 125, Y = 8, Z = 120, Width = 60, Depth = 52 },
		CurtainW = { X = -320, Y = 24, Z = -70, Width = 64, Depth = 72 },
		CurtainE = { X = 320, Y = 28, Z = -70, Width = 64, Depth = 72 },
		InnerW = { X = -175, Y = 52, Z = -70, Width = 64, Depth = 64 },
		InnerE = { X = 175, Y = 56, Z = -70, Width = 64, Depth = 64 },
		CurtainNW = { X = -140, Y = 44, Z = -300, Width = 72, Depth = 56 },
		CurtainNE = { X = 140, Y = 48, Z = -300, Width = 72, Depth = 56 },
		NorthBastion = { X = 0, Y = 40, Z = -320, Width = 80, Depth = 60 },
		Sallyport = { X = 0, Y = 22, Z = 30, Width = 64, Depth = 48 },
		Countermine = { X = 0, Y = 30, Z = -225, Width = 64, Depth = 48 },
	},
	Apex = { X = 0, Y = 64, Z = -90, Width = 144, Depth = 108 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "Crossing" }, { "Basin", "CovertW" }, { "Basin", "CovertE" },
		{ "CovertW", "WestGallery" }, { "CovertE", "EastGallery" }, { "Crossing", "CovertW" }, { "Crossing", "CovertE" },
		{ "Crossing", "Sallyport" },
		{ "WestGallery", "CurtainW" }, { "EastGallery", "CurtainE" },
		{ "CurtainW", "WestBastion" }, { "CurtainE", "EastBastion" },
		{ "CurtainW", "InnerW" }, { "CurtainE", "InnerE" },
		{ "WestBastion", "CurtainNW" }, { "EastBastion", "CurtainNE" },
		{ "CurtainNW", "NorthBastion" }, { "CurtainNE", "NorthBastion" },
		{ "CurtainNW", "InnerW" }, { "CurtainNE", "InnerE" },
		{ "InnerW", "Apex" }, { "InnerE", "Apex" }, { "WestBastion", "InnerW" }, { "NorthBastion", "Countermine" },
	},
	Stairs = { InnerW_Apex = true, InnerE_Apex = true },
	Patrols = {
		GLACIS = { "CovertW", "Crossing", "CovertE" },
		WEST_FLANK = { "WestGallery", "CurtainW", "WestBastion" },
		EAST_FLANK = { "EastGallery", "CurtainE", "EastBastion" },
		NORTH_WALK = { "CurtainNW", "NorthBastion", "CurtainNE" },
		INNER_WARD = { "InnerW", "Apex", "InnerE" },
	},
	ReplacePatrols = true,
	Terrain = { Decks = { Sanctuary = true, Sallyport = true, Countermine = true } },
},
[50] = {
	Key = "abyssal:5", Name = "Overlord's Throne",
	Size = { Width = 940, Depth = 795, Height = 370, Bottom = -6 },
	Basin = { X = 0, Y = 0, Z = 245, Width = 908, Depth = 104 },
	WestGallery = { X = -320, Y = 8, Z = 95, Width = 92, Depth = 80 },
	EastGallery = { X = 320, Y = 12, Z = 95, Width = 92, Depth = 80 },
	Crossing = { X = 0, Y = 28, Z = 110, Width = 96, Depth = 68 },
	WestBastion = { X = -330, Y = 32, Z = -90, Width = 92, Depth = 82 },
	EastBastion = { X = 330, Y = 36, Z = -90, Width = 92, Depth = 82 },
	ExtraPlatforms = {
		FootW = { X = -170, Y = 20, Z = 60, Width = 72, Depth = 60 },
		FootE = { X = 170, Y = 24, Z = 60, Width = 72, Depth = 60 },
		BrokenStair = { X = 0, Y = 35, Z = 29, Width = 64, Depth = 36 },
		ShinW = { X = -200, Y = 38, Z = -40, Width = 64, Depth = 56 },
		ShinE = { X = 200, Y = 42, Z = -40, Width = 64, Depth = 56 },
		ReliquaryW = { X = -370, Y = 46, Z = -335, Width = 64, Depth = 52 },
		ReliquaryE = { X = 370, Y = 50, Z = -335, Width = 64, Depth = 52 },
		ArmW = { X = -190, Y = 52, Z = -150, Width = 64, Depth = 72 },
		ArmE = { X = 190, Y = 56, Z = -150, Width = 64, Depth = 72 },
		ChainW = { X = -350, Y = 44, Z = -230, Width = 64, Depth = 56 },
		ChainE = { X = 350, Y = 48, Z = -230, Width = 64, Depth = 56 },
		HandW = { X = -200, Y = 62, Z = -265, Width = 64, Depth = 56 },
		HandE = { X = 200, Y = 66, Z = -265, Width = 64, Depth = 56 },
	},
	Apex = { X = 0, Y = 72, Z = -200, Width = 212, Depth = 156 },
	Paths = {
		{ "Sanctuary", "Basin" }, { "Basin", "WestGallery" }, { "Basin", "Crossing" }, { "Basin", "EastGallery" },
		{ "WestGallery", "FootW" }, { "EastGallery", "FootE" }, { "Crossing", "FootW" }, { "Crossing", "FootE" },
		{ "Crossing", "BrokenStair" }, { "BrokenStair", "Apex" },
		{ "FootW", "ShinW" }, { "FootE", "ShinE" }, { "WestGallery", "WestBastion" }, { "EastGallery", "EastBastion" },
		{ "WestBastion", "ShinW" }, { "EastBastion", "ShinE" },
		{ "ShinW", "ArmW" }, { "ShinE", "ArmE" },
		{ "WestBastion", "ChainW" }, { "EastBastion", "ChainE" },
		{ "ChainW", "HandW" }, { "ChainE", "HandE" },
		{ "ArmW", "HandW" }, { "ArmE", "HandE" },
		{ "ArmW", "Apex" }, { "ArmE", "Apex" }, { "HandW", "Apex" }, { "HandE", "Apex" },
		{ "ChainW", "ReliquaryW" }, { "ChainE", "ReliquaryE" },
	},
	Stairs = { ArmW_Apex = true, ArmE_Apex = true },
	Patrols = {
		SUPPLICANTS = { "WestGallery", "Crossing", "EastGallery" },
		WEST_LEG = { "FootW", "ShinW", "ArmW" },
		EAST_LEG = { "FootE", "ShinE", "ArmE" },
		WEST_CHAINS = { "WestBastion", "ChainW", "HandW" },
		EAST_CHAINS = { "EastBastion", "ChainE", "HandE" },
		THRONE_SEAT = { "ArmW", "Apex", "ArmE" },
	},
	ReplacePatrols = true,
	Terrain = { Decks = { Sanctuary = true, BrokenStair = true, ShinW = true, ShinE = true, HandW = true, HandE = true, ReliquaryW = true, ReliquaryE = true } },
},
```

## Appendix B: the offline layout probe

No Studio needed: `TowerLayout` and `PatrolPath` are pure modules.

1. Export them from the commit you're checking:

   ```bash
   git show origin/main:src/ReplicatedStorage/Shared/Config/TowerLayout.luau > TowerLayout.luau
   git show origin/main:src/ReplicatedStorage/Shared/Util/PatrolPath.luau > PatrolPath.luau
   ```

2. Make `TowerLayoutAbyss.luau`:
   - drop its `--!strict` first line;
   - prepend the three stubs below;
   - paste the Appendix A entries as `AUTHORED[46] = {...}` … `AUTHORED[50] = {...}` statements just above `local function build(`.
3. Run `luau probe.luau` with the official Luau CLI (`D:/luau` here; never install it without asking).

```lua
-- Stubs (top of TowerLayoutAbyss.luau):
local Enum = { Material = setmetatable({}, { __index = function(_, k) return k end }) }
local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
local Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }

-- probe.luau
local Layout = require("./TowerLayoutAbyss")
local PatrolPath = require("./PatrolPath")

-- Dijkstra from the Sanctuary: centre -> link end, the link's 3D length, link end -> centre.
local function walk(room)
	local P, adj = room.Platforms, {}
	for id in P do adj[id] = {} end
	local function d3(ax, ay, az, bx, by, bz) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2 + (az - bz) ^ 2) end
	for _, l in room.Links do
		local a, b = P[l.From], P[l.To]
		local w = d3(a.X, a.Y, a.Z, l.AX, l.AY, l.AZ) + d3(l.AX, l.AY, l.AZ, l.BX, l.BY, l.BZ) + d3(l.BX, l.BY, l.BZ, b.X, b.Y, b.Z)
		table.insert(adj[l.From], { l.To, w })
		table.insert(adj[l.To], { l.From, w })
	end
	local dist, done = { Sanctuary = 0 }, {}
	while true do
		local best, bestD = nil, math.huge
		for id, dd in dist do if not done[id] and dd < bestD then best, bestD = id, dd end end
		if not best then break end
		done[best] = true
		for _, e in adj[best] do dist[e[1]] = math.min(dist[e[1]] or math.huge, bestD + e[2]) end
	end
	return dist.Apex or math.huge
end

for floor = 46, 50 do
	local index = (floor - 1) % 5 + 1
	local room, canon = Layout.ForFloor(floor), Layout.Get(index)
	local allowed, fresh = {}, {}
	for _, p in Layout.Validate(canon) do allowed[p] = true end
	for _, p in Layout.Validate(room) do if not allowed[p] then table.insert(fresh, p) end end
	local terraces, levels, seen, maxSlope, mobs = 0, 0, {}, 0, 0
	for id, p in room.Platforms do
		terraces += 1
		if id ~= "Sanctuary" and not seen[p.Y] then seen[p.Y] = true levels += 1 end
	end
	for _, l in room.Links do
		local run = math.sqrt((l.BX - l.AX) ^ 2 + (l.BZ - l.AZ) ^ 2)
		maxSlope = math.max(maxSlope, math.deg(math.atan(math.abs(l.BY - l.AY) / run)))
	end
	for _, c in room.Camps do if c.Id ~= "APEX_SANCTUM" then mobs += c.Size end end
	print(string.format("F%d %s: %dx%dx%d B%d | T%d L%d H%d Apex Y%d | slope %.2f | walk %.1f (%.2fx) | mobs %d elites %d | new problems: %s",
		floor, room.Name, room.Width, room.Depth, room.Height, room.Bottom, terraces, #room.Links, levels, room.Platforms.Apex.Y,
		maxSlope, walk(room), walk(room) / walk(canon), mobs, room.EliteCount, #fresh == 0 and "none" or table.concat(fresh, "; ")))
	for name, route in Layout.PatrolRoutes(index, floor) do
		print(string.format("   patrol %s %.1f s", name, PatrolPath.LoopLength(route) / PatrolPath.Speed))
	end
	for name, p in Layout.PortalSpots(index, floor) do
		print(string.format("   portal %s (%.0f, %.0f, %.0f)", name, p.X, p.Y, p.Z))
	end
end
```
