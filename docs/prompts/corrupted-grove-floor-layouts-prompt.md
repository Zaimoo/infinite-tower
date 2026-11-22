# Prompt: Corrupted Grove — a Unique Layout for Every Floor (Floors 31–35)

Copy everything below the line into a Claude Code session opened at the repo root, or follow it with the `biome-floor-redesign` skill (`.claude/skills/biome-floor-redesign/SKILL.md`), which is the procedure this plan plugs into.

> **Written 2026-11-21.** Five biomes are authored on `main`: Verdant Ruins (1–5), Fungal Hollow (6–10), Ashen Dunes (11–15), Frozen Citadel (16–20) and Infernal Foundry (21–25). Thunder Highlands (26–30) has a plan (`docs/prompts/thunder-highlands-floor-layouts-prompt.md`) but no floors in code yet. This brief builds on all six prompts and treats the Thunder plan's numbers as the bar to beat.
>
> **The escalation rule (from the Infernal plan, Part 2):** every floor is richer, taller and more varied than the one below it, and than every earlier floor at the same position in its biome. Corrupted Grove beats the Thunder plan at each index on room area, room height, terraces, links, height levels and Apex height.
>
> **The compact-grand pacing rule (learned on Floor 25):** grow upward and inward. Depth stays capped at `795` studs. The scale goes into height, terrace count and density, not empty ground.
>
> **The guide-image gate:** before building any floor, ask the user for that floor's guide image (skill step 2). The image sets mood, shapes and landmarks. Treat it as inspiration, never copy it 1:1, and keep the runtime rules below. Update the floor's section of this file with what you took from the image before you build.
>
> **The layout half is already proven:** every coordinate table in Part 3 was run through the real `TowerLayout` in Studio on 2026-11-21. The check used a throwaway clone of the module with these entries spliced into `AUTHORED`, ran `Layout.Get`, `Layout.Validate`, `Layout.PatrolRoutes` and `PatrolPath.LoopLength`, and then deleted the clone. Results: **zero** validation problems on all five floors, no build asserts, every link at or under `14.81°`, every terrain terrace on the 4-stud grid, every platform reachable from the Sanctuary, mob and Elite totals on contract (`16/22/25/35/35`, `1/2/3/4/4`), and every authored patrol under 240 s. Re-run that check after any coordinate change.

---

## Role

You are a two-specialist team speaking as one. Say which role is speaking when it matters.

**Thornwarden** is a senior level designer and gameplay engineer for *Infinite Towers: Become a Master!*, a Roblox squad-command action RPG. Thornwarden owns topography, sightlines, combat space, pacing, navigation and the `TowerLayout` connector contract. They think in walkable surfaces, link slopes, landings, camp spacing, leash radii, and the route a squad of five takes from the Sanctuary to the Apex.

**Grovewright** is a senior environment artist and world-builder. Grovewright owns the Hollin ecosystem, the grafted trees, the briar hedges, the treehouse keeps, the Mother Graft, materials, lighting and the Rotpulse. They build from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the earlier biomes were built. Every prop has a reason to be in the grove and reads clearly from the gameplay camera. Grovewright makes every floor a visible step up from the one below it.

Neither of you breaks the runtime contracts described below.

## Before you start

1. `git fetch origin` and branch each floor from `origin/main` as `feat/corrupted-grove-floor-<N>`. Work in the main checkout, because Rojo syncs from there. Use conventional commits and **one PR per floor. Never stack PRs.** This repo keeps head branches after a merge, so a stacked PR merges into its parent branch and never reaches `main`.
2. Follow `CLAUDE.md`, `AGENTS.md` and the `biome-floor-redesign` skill. Use the `roblox-world-building`, `roblox-luau`, `roblox-studio-mcp`, `roblox-npc-ai` and `roblox-performance` skills.
3. Read `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, the authored floors) and §3.6 (lighting), `docs/TOWER_NAVIGATION.md` (including "Authored terrain walkways"), `reference/infinite_towers_biomes.md` §7 (Corrupted Grove) and `docs/tower-mob-remodel-plan.md` §7 (the Corrupted Grove enemy visuals and motif).
4. Read the earlier floor prompts, newest first: Thunder, Infernal, Frozen, Ashen, Fungal, Verdant. Read their status notes and lessons. Then run `git log --oneline -- src/ServerScriptService/Core/Tower*.luau src/ReplicatedStorage/Shared/Config/TowerLayout.luau` and read the `fix(...)` commits. The Fungal fixes are the ones that bite here: clearance silently removing whole prop groups, oversized mushroom meshes reaching a boss slot, and trees standing on blocks.
5. Read the authored-floor code end to end:
   - `TowerLayout.luau`: `AUTHORED[6..10]` (the Fungal `Terrain = {...}` system this biome uses), `AUTHORED[21..25]`, `build`, `Validate`, `PatrolRoutes`, `Lanes` and `PortalSpots`.
   - `TowerTerrain.luau`: `Palettes.corrupted_grove`, `Surfaces`, `MaterialColors`, `BlockyMaterials`, `Terrain.Shapes`, `Pools`, `Islands`, `Bridges` and the `GroveScale` / `GroundCover` paths.
   - `TowerRoomBuilder.luau`: decks, `RoundDecks`, `DeckThickness`, bridges and stairs, curbs, open-sky versus vaulted rooms.
   - `TowerBiomeAssets.luau`: the Fungal floor blocks (`if fungalFloor == N then ... end`), `piece`, `group`, `kitAt`, `onTerrain`, `groundY`, and the corrupted branches of `mushroom()` and `tree()`.
   - `TowerBiomeKit.luau` and `TowerKitProps.luau`: `ExtraTemplates`, `Biomes.corrupted_grove`, `Ecology.corrupted_grove`, `Has` and `Ready`.
   - `HubLighting.luau`: `BiomeGrades[7]` (magenta murk) and `FloorGrades`.
   - `.claude/skills/biome-floor-redesign/references/studio-verify.luau`.

## The goal

The five Corrupted Grove floors (31–35) still use the seeded generic layout and the generic Corrupted props (`BlightTree`, corrupted `GiantMushroom`, `BlightPod`, `Obelisk`). Give each one its own hand-authored topography, built around one ecosystem, so each floor has a different shape, route and combat rhythm and reads differently from its neighbours. Every other floor stays byte-identical.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, ruin, band and creature traces back to this ecosystem. If a prop doesn't fit it, cut it.

### The Hollin

The **Hollin** were grove-wardens and grafters, a quiet order who never built in stone if they could grow the building instead. (One line of continuity: their seed-traders climbed down to the Kairnfolk ridges below to trade grafting wax and cider for copper wire. That wire still binds their oldest grafts.) Their craft was grafting: they bound cuttings of every tree in the forest onto one trunk, generation after generation, until it became the **Mother Graft**, a colossal tree bearing a hundred kinds of leaf.

Their architecture is grown rather than built: living arches trained from pleached saplings, hedge walls woven from willow and hawthorn, wattle-and-daub crofts, shingle-roofed treehouses bracketed onto trunks, wicker bee-skeps, oak cider presses, and grafting benches with clay pots of wax. Their only stone is mossy fieldstone for wellheads, weirs and boundary markers. Their sigil is the **graft-knot**: two branches crossed and bound by a single ring band. It appears carved on stiles, wellheads and shrine posts, woven into hedge gates, stamped on cider barrels, and on the Rot Menders' sap-lanterns.

### The Mother Graft, the Heartrot and the Rotpulse

The Mother Graft is the **Blight Sovereign** (`GROVE_COLOSSUS`): a crowned dead-tree colossus with a hanging-moss mantle and a cavity of rot light (`docs/tower-mob-remodel-plan.md` §7). Something went wrong in the last graft. A rot took the heartwood, the **Heartrot**, and the tree woke. Its rot runs out through the roots of every tree grafted from it, so the forest is corrupted from the inside, outward and downward.

**The Rotpulse is the biome's through-line** (after the Heartroot, Veinweb, Ember Vein, Stillcold, Heartbeat and Tempest Squall). On a shared server-time cycle (`workspace:GetServerTimeNow()`), a slow pulse of magenta rot-light travels out along the roots:
- root seams and bark fissures flare magenta, then fade
- rot-bloom flowers open and close
- spore motes puff from blight pods
- a low creak and groan, like a tree breathing, plays spatially from the nearest large trunk

It is faint on Floor 31, where the pulse reaches only the brook, and it builds to a heartbeat on Floor 35, where every root on the floor beats with the Sovereign's cavity. It is **client-side and purely cosmetic** (§5.6).

### The Pale Bands (the trail the player follows)

The last Hollin wardens fought the blight with the only tool they had: they cut away rot, sealed the wound with wax, and tied a **pale linen graft-band** around every tree they saved. The bands are the player's trail across all five floors:

| Floor | How far the rot has gone | What the bands tell you |
| --- | --- | --- |
| 31 | The Verge: green forest, rot only in the brook and the north-east | Clean white bands on healthy trees along the south bank. Fresh-cut stumps, wax pots and a warden's camp at the Woodcutters' Ring. Across the brook the bands stop. |
| 32 | The Orchard: every tree grafted, every graft turning | Bands on every orchard tree, now stained pink at the knot. Half the rows have been felled to stop the spread. The press-house behind the crest is still lit. |
| 33 | The Labyrinth: the hedge-maze the wardens planted to wall the rot in | Bands tied to hedge gates as wayfinding. They mark the true path (west) and are missing on the false one (east). The thornheart at the centre is what the maze was built to hold. |
| 34 | The Stronghold: the wardens' last refuge in the elder trees | Bands wound around the treehouse keeps' trunks as wards, torn and soaked magenta. Barricades, cut rope bridges and the wardens' cots. They were holding out. |
| 35 | The Grove: the Mother Graft itself | One last band, enormous and rotten, tied around the Sovereign's own trunk below the heart-cavity. At the foot of the Taproot stands the **Last Warden**, a Hollin figure half-grafted into the root, still holding the knife. |

### Living layers (use all of them on every floor, more of each the higher you go)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Blight & Bloom** | Magenta rot-bloom flowers, blight pods, weeping sap runs, fungal brackets, spore drifts, rot-scum on water | The signature glow. Always magenta to violet (hue 290°–320°), **never crimson or red**: enemy telegraphs are `(255, 25, 55)` and `(255, 95, 40)` (`EntityRenderer`), and the grove must not camouflage them (§5.7). |
| **Twisted Wood** | `BlightTree`, `DeadTree`, new twisted grafted trees, hollow stumps, fallen trunks, root arches, the five elder rotwoods (34) and the Mother Graft (35) | Every tree grows from the ground (`groundY`), with roots, rock and moss at the foot. Never stand a tree on a block, pillar or shelf. |
| **Briar & Hedge** | Hawthorn and bramble hedges, briar knots, thorn arches, nettle beds | Hedge walls stay at or under 9 studs over the walk surface so the gameplay camera sees over them (Floor 33's maze reads from above, not from inside). |
| **Hollin Craft** | Graft-knot posts, Pale Bands, wattle crofts, bee-skeps, cider presses, grafting benches, wax pots, pruning hooks, ladders, wicker lanterns, fieldstone wellheads and weirs | Grown and woven, never machined. One fieldstone material for everything stone. |
| **Water & Mire** | The blight-brook (31), cider-rot puddles (32), the thorn pit (33), the rot bog (34), the sap mire (35) | Terrain `Water` (the palette's liquid). `Terrain.WaterColor` is place-wide teal (`TowerTerrain` line 113), so make the water read tainted with floating scum and leaf props and magenta underglow anchors, never by recolouring water. |
| **Remnant Green** | Healthy ferns, moss and leafy grass that shrink floor by floor | Floor 31 is still half green. Floor 35 has only a ring of green round the Last Warden. |

### Food web (how the enemies fit, `MobCatalog` → `corrupted_grove`)

- **Blight Wolf** (`QUADRUPED`, Regular: thorned spine, bark-plated flanks, rot-bloom eyes; `BITE`): runs in packs through the undergrowth. Put gnawed bones, flattened bracken beds and claw-scored stumps near their camps.
- **Thorn Weaver** (`ROOTED_BIPED`, Regular: spindly briar figure throwing thorn bolts; `PROJECTILE`): grows out of the hedges. Put briar knots, half-woven thorn screens and loose thorn bundles at their camps.
- **Rot Mender** (`ROOTED_BIPED`, Support `MEND`: hunched grafter with stitched bark and a sap-lantern): a Hollin grafter the blight took, still "healing" by grafting rot into wounds. Put grafting benches, wax pots and sap-lantern hooks where it stands.
- **Rotwood Keeper / Alpha** (`TREANT`, Elite/Alpha: hollow trunk, root legs, glowing rot heart; the Alpha adds a gilded antler crown; `SLAM` / `GROUND_AREA`): an elder tree that walked. Put uprooted craters, torn-up root trails and fresh-snapped branches where Elites lead.
- **Blight Sovereign** (`GROVE_COLOSSUS`, Boss, Floor 35): the Mother Graft. Its moves (GDD §5.1) are **Briar Whip** (`ARC`), **Heartrot Bloom** (`SELF_DISC`) and **Rot Tendrils** (`TARGET_DISC`).

The relic skins (`RelicConfig` → `CORRUPTED`) are the **Blightroot Geode**, the **Rotbloom Urn**, the **Heartrot Core** and the **Heart of the Blight Sovereign**. Echo them in split-knot shrines, choked flower urns, thorn-caged seed pods and the Sovereign's cavity.

### Ambient life (client-only, purely cosmetic)

Falling leaves (green on 31, brown by 33, ash-grey on 35), drifting spore motes, fireflies over the brook (31–32 only, gone after), crows and moths circling the high trees out of gameplay height, dripping sap, creaking branches, and the Rotpulse. The higher the floor, the more of these run. Everything is pooled, culled by distance, scaled by the Graphics quality setting, and off or minimal at the lowest quality. Nothing replicates from the server.

---

## Part 2: The escalation ladder

### 2.1 Layout and scale (validated in Studio for the Part 3 coordinates)

| Floor | Room (W × D × H) | Area (vs. Thunder plan at this index) | Terraces | Links | Height levels | Apex Y | Max slope | Shortest walk (× canonical) | Thunder plan at this index (terraces / links / levels / Apex) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 31 | 540 × 580 × 195 | 313,200 (> 280,500) | 11 | 13 | 10 | 28 | 14.53° | 563.5 (1.76×) | 10 / 11 / 9 / 24 |
| 32 | 620 × 640 × 220 | 396,800 (> 363,000) | 13 | 15 | 12 | 36 (crest 48) | 14.81° | 544.8 (1.50×) | 12 / 14 / 11 / 32 |
| 33 | 680 × 720 × 250 | 489,600 (> 458,500) | 15 | 17 | 14 | 44 | 14.79° | 853.4 (2.11×\*) | 13 / 16 / 12 / 40 |
| 34 | 750 × 795 × 275 | 596,250 (> 580,650) | 16 | 19 | 15 | 52 | 14.81° | 724.8 (1.59×) | 15 / 17 / 13 / 48 |
| 35 | 810 × 795 × 305 | 643,950 (> 632,025) | 18 | 21 | 17 | 60 | 14.81° | 671.4 (1.33×) | 16 / 19 / 15 / 56 |

- *Terraces* counts every platform, including `Sanctuary` and `ExtraPlatforms`.
- *Height levels* counts distinct walk heights among all platforms except `Sanctuary`. On every Corrupted floor no two terraces share a height.
- *Shortest walk* is the Dijkstra distance from the Sanctuary centre to the Apex centre, summing centre → link end, the link's 3D length, and link end → centre. It is compared against the canonical layout for the same index measured the same way. It is **not** directly comparable with the Thunder plan's walk column, which may have used a different measure.
- \*Floor 33 is a maze: the walk is long on purpose, but still near the Infernal ceiling (`2.03×` on Floor 25). Do not add a shortcut from the Briar Gate to the Thornheart Court.
- Floor 32's highest walk (the Grafted Crown, Y 48) is above its Apex (Y 36). That is the floor's shape (§3.2), not a ladder mistake. The ladder counts Apex Y.

### 2.2 Assets and variety (targets your build must meet, measured by the set-piece census)

| Floor | New kit templates | Distinct templates placed | Landmark set pieces | Placed props (excl. ground cover) | Ground cover and small clutter | Tallest landmark | Ambient systems |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 31 | ≥ 8 | ≥ 22 | ≥ 13 | ≥ 320 | ≥ 230 | ≥ 105 studs | ≥ 5 |
| 32 | ≥ 9 | ≥ 25 | ≥ 15 | ≥ 390 | ≥ 270 | ≥ 125 | ≥ 6 |
| 33 | ≥ 10 | ≥ 28 | ≥ 17 | ≥ 460 | ≥ 320 | ≥ 150 | ≥ 6 |
| 34 | ≥ 11 | ≥ 31 | ≥ 19 | ≥ 530 | ≥ 370 | ≥ 175 | ≥ 7 |
| 35 | ≥ 12 | ≥ 34 | ≥ 21, plus one colossal centrepiece | ≥ 620 | ≥ 430 | ≥ 230 (the Mother Graft) | ≥ 8 |

**Performance wins a conflict.** If a target and the frame-rate budget in §5.8 disagree, meet the budget and say so in the PR. Never pad a floor with filler to hit a count.

### 2.3 Variety and readability rules (judged in review)

- **No filler.** No single template makes up more than 12% of a floor's placed props (ground cover excluded).
- **Every terrace is a vignette:** at least 4 distinct prop kinds that say what the terrace was for (mill, croft, press-house, grafting yard, bee-skep row, hedge gate, treehouse keep, root shrine).
- **Every link is dressed at both ends:** graft-knot posts, stiles, wicker lanterns, band-tied saplings or hedge gateposts on the terrace, off the lane.
- **Three skyline layers on every floor:** *near* (props, hedges and saplings on the terraces); *mid* (landmark trees, the mill, the press-house, the elder rotwoods); *far* (a forest wall beyond the room, twisted canopies against the sky, and from Floor 33 the silhouette of the Mother Graft on the horizon, growing closer floor by floor until it fills the back of Floor 35).
- **Every floor introduces at least one traversal feature and one landmark type that no earlier floor has.** Part 3 names them.
- **Grounded and readable:** density never hides camps, telegraphs, loot or the route.

---

## Part 3: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north. Y is the walkable top surface. Terrain terraces sit on multiples of 4. Any terrace at another height is a deck (`Terrain.Decks[id] = true`).

**Shapes already taken (30, don't repeat them):**
- **Verdant (1–5):** spine with glades; broken diagonal aqueduct; E–W gorge with three bridges; walled ring with wall-walks; spiral around a cenote.
- **Fungal (6–10):** horseshoe around a pool; switchback up a gallery wall; chasm with a round cap deck and hung bridges; bastion "H" through the Crossing; asymmetric radial spiderweb (dais in a moat, walk round to the one way in).
- **Ashen (11–15):** fork around a dune; single switchback; N–S ravine with two ledges and an arch; chokepoint gate and split fortress; route over a fallen giant.
- **Frozen (16–20):** lakeshore road versus floe chain; street lattice; inverted ravine (central spine); two routes in two climates; cathedral nave.
- **Infernal (21–25):** hub-and-spokes turntable; gantry Π with a stem; lava-lake fishbone causeway; three-strip sluice weave; hourglass pinch with side chambers.
- **Thunder plan (26–30):** braided contours round a headwall; concentric ringfort; sky-pinnacle archipelago; two-tier cliff fault with a viaduct; twin-wing caldera amphitheatre.

**Where the Apex sits (the contrast rule):**

| Floor | Apex position | How you reach it | Dominant landform | Light |
| --- | --- | --- | --- | --- |
| 31 | **Corner** (north-east), low, in plain view across the water | Ford the brook once or zigzag across it three times | A meandering brook valley | Sickly gold afternoon |
| 32 | **Hidden** behind a crest, **lower** than the crest | Climb the orchard slope, top the ridge, descend into the hollow | A south-facing slope and an E–W ridge | Overripe rose dusk |
| 33 | **Centre** of the room, visible over the hedges, unreachable from the front | Thread the maze: west is true, east is false, the back ring is long | A hedge-walled maze over a thorn pit | Hard thorn-shadow noon |
| 34 | **High, back-west**, in the fork of the greatest tree | Climb tree to tree on bracket decks and branch bridges | Five elder trunks rising from a bog | Green-black canopy gloom with light shafts |
| 35 | **Back centre**, the largest dais, inside the Mother Graft's root crown | Walk up the backs of three colossal roots | Three root ridges over a sap mire | Blight-eclipse crimson-violet |

**Fixed on every floor:**
- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, `128 × 56`, and `Basin` stays centred on `X = 0`. Arrivals land out of aggro.
- `Apex` holds the Floor Alpha (31–34) or Biome Boss (35) summon and the Ascend/Rerun portals (`Layout.PortalSpots`, at the back of the Apex: every Apex below is entered from the south, west or east, never the north).
- Mob totals and Elite counts stay **16 / 22 / 25 / 35 / 35** and **1 / 2 / 3 / 4 / 4**. Never add mobs for bigger rooms. `ExtraPlatforms` hold no camps.
- Floors 33–35 replace the generic patrols with authored routes (`ReplacePatrols = true`). `BASIN_LOOP` is always generated.

**Terrain system: use the Fungal one** (`Terrain = { Direct = true, Surface = "HOLLIN" | "BLIGHT", Blight, Decks, DeckThickness, RoundDecks, Shapes, Pools, Islands, Ridges, Bridges, BridgeStyles, LiquidRise, FloorDip, GroveScale, GroundCover, GroundCoverCount }`). A forest wants round, organic terraces, pools and hung walkways, and that system already does all three. Don't introduce a third system, and don't mix in the top-level `DirectTerrain` / `Suspended` / `Masonry` fields. Use `Shapes` (round or squircle) for every terrain terrace that isn't a built deck, so nothing reads as a square plinth.
- **Terrain corruption progression:** Floors 31–32 (the outer verge and grafting orchard) use `Surface = "HOLLIN"` (warm autumn earth and pale sand trails). **From Floor 33 onwards (Floors 33, 34, 35), use `Surface = "BLIGHT"` + `Blight = { FissureDepth, CragHeight }`**: cracked violet cobble trails (`Cobblestone`), deep indigo-violet blighted earth (`Concrete`), blackened basalt corruption fissures and sheer crag cliffs (`Basalt`), dark violet-slate banks (`Pavement`), and abyssal pit/mire beds (`Asphalt`), sculpted with twisted blight-fissures, jagged corrupted outcrops (`Ridges`), and physical glowing violet-magenta cliff/pit root veins (hue 285°–315°, never crimson) so the terrain itself visibly rots and darkens as you climb toward the Blight Sovereign. (`BLIGHT` reuses existing place-wide material colours and never edits `MaterialColors`, keeping Floors 1–32 byte-identical.)

---

### Floor 31: Blighted Verge (`corrupted:1`, `INTRODUCTION`)

*540 × 580 × 195, `Bottom = 0`. Sickly gold late afternoon.*

**Built (2026-11-22, `feat/corrupted-grove-floor-31`).** Guide image: `reference/Corrupted Grove 31.webp`. Taken from it: the thatched mill with its big undershot wheel on the brook, a stepped fieldstone weir, the split elder glowing magenta at the spring, the felled log hung with Pale Bands, the stacked cairn behind a stake fence, the wardens' lean-to with lanterns, wicker lanterns in banded birches, the great oak on a rocky knoll, the woven wattle arch with the graft-knot over the arrival, and the gold-and-magenta light. Left out: the painting's dense fog and foliage, which would hide camps and the route. At the user's request the south bank is **autumn gold and amber, not green**: golden beeches and grass, bracken, dry ground; the only green is olive moss on the props. What changed from the plan during the build is noted under each heading below.

**Story beat:** the edge of the grove, where the Hollin still held the line. The south bank is autumn gold and banded. A blight-brook rises at the **Heartrot Spring** in the north-east corner and carries the rot downstream in a magenta-scummed meander. Everything north of the water has turned.

**Shape: a meandering blight-brook that splits the floor into a healthy bank and a rotten bank, with the Apex in the far north-east corner.** The brook rises from a cascade beside the Apex and winds west-south-west in an S to a sinkhole in the west wall. Polyline as built: `(214,−236) → (230,−70) → (120,−64) → (40,−8) → (−20,2) → (−100,−14) → (−180,−78) → (−262,−84)`. (The planned upstream run at x ≈ 232–250 lay inside the east wall's mountain band, where pools can't form, so the brook now rises in the low ground east of the Apex.) Four **fords** cross it: stepping stones, a fallen log, a mill-race plank and a fieldstone weir. **Every route to the Apex fords the brook at least once.** The quick route fords once, via the Last Green, the Lantern Copse and the Weir Ford. The scenic zigzag fords three times, via the Pale Glade, the Weir Mill, the Lantern Copse and Rothollow. A back path along the rotten bank (Warding Shrine → the Blight Line) reaches the Apex from the west. **New to the tower:** fords (four crossings of a live brook that every route must use) and a corner Apex visible across water from the arrival. New landmark type: a Hollin water mill on a weir.

```
                               N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │                                     [ HEARTROT SPRING ]  ≈│ spring
   │          [ THE BLIGHT LINE ] Y24 ──────────  Y28        ≈ │ cascade
   │         /                                    ║ (st)    ≈  │
   │ [WARDING SHRINE] Y16                     [ROTHOLLOW] Y20 ≈  │
   │        \           (rotten bank)              ║ Weir Ford ≈ │
   │ ≈≈≈≈≈≈≈≈\≈≈≈≈≈≈≈≈            ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈   │
   │ sink [WOODCUTTERS] ≈≈≈ [ WEIR MILL ] Y8 ≈≈≈  Log Ford       │
   │        Y10   Stepping- //  ≈≈≈≈≈≈≈≈≈  \ \_____[LANTERN COPSE] Y12
   │          \   Stone    //   Mill-Race   \_____/     /        │
   │        [PALE GLADE] Y4     Ford  [THE LAST GREEN] Y6        │
   │              \     (healthy bank)      /                  │
   │         ~~~~~~~~~~~ VERGE MEADOW  Y0 ~~~~~~~~~~~           │
   │                            |                              │
   │                    [ WARDEN'S STILE ] Y8                  │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Verge Meadow | 0, 0, 150 | 508 × 96 | terrain |
| `WestGallery` | Pale Glade | −160, 4, 40 | 86 × 72 | terrain (round) |
| `LastGreen` (extra) | The Last Green | 60, 6, 45 | 64 × 52 | deck (a mossy fieldstone knoll top) |
| `Crossing` | Weir Mill | −20, 8, −40 | 76 × 60 | terrain (round island in the meander) |
| `Woodcutters` (extra) | Woodcutters' Ring | −205, 10, −40 | 64 × 52 | deck (a ring of sawn stumps on a log platform) |
| `EastGallery` | Lantern Copse | 175, 12, −10 | 86 × 72 | terrain (round) |
| `WardingShrine` (extra) | Warding Shrine | −170, 16, −120 | 68 × 56 | terrain |
| `Rothollow` (extra) | Rothollow | 175, 20, −112 | 70 × 56 | terrain |
| `BlightLine` (extra) | The Blight Line | −40, 24, −150 | 68 × 56 | terrain |
| `Apex` | Heartrot Spring | 130, 28, −205 | 116 × 84 | terrain |

**Paths (13 links):** `Sanctuary→Basin` (−8, 13.6°), `Basin→WestGallery` (+4), `Basin→LastGreen` (+6), `WestGallery→Woodcutters` (+6, 14.4°), `WestGallery→Crossing` (**Stepping-Stone Ford**, +4), `LastGreen→Crossing` (**Mill-Race Ford**, +2), `LastGreen→EastGallery` (+6), `Crossing→EastGallery` (**Fallen-Log Ford**, +4), `Crossing→WardingShrine` (+8), `EastGallery→Rothollow` (**Weir Ford**, +8), `Rothollow→Apex` (`STAIRS`: the Rootstep Stairs, +8, 14.53°), `WardingShrine→BlightLine` (+8), `BlightLine→Apex` (+4).
*Fords, as built:* the open ground sits at Y −4 and the terraces at Y 4–12, so no ford can sit at water level. The Mill-Race Ford (a plank walkway) and the Fallen-Log Ford are hung over the water (`Terrain.Bridges`; `Terrain.BridgeStyles = { Crossing_EastGallery = "LOG" }` draws a colossal fallen trunk with a split limb, worn flat on top, no rope rails). The Stepping-Stone Ford and the Weir Ford are earthen causeways across the brook (fieldstone pavers down the spine; a fieldstone weir with foam beside the Weir Ford). The layout records all four in `Fords`. Only those four links cross the water.

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite: a Rotwood Keeper in the Pale Glade, the first sign that the rot has crossed the water), `EAST_GALLERY` 4. **Patrol:** `BASIN_LOOP` (95.3 s).

**Terrain, as built:** 28 `Pools` chained along the polyline (RX 14–19, overlapping). `LiquidRise = −1.6` and `FloorDip = 6` put the water about 1.5 studs below its banks, under the floor's invisible slab, so it reads as a channel; when the water sat flush with the banks it read as ground. Seven low `Islands` hillocks roll the open ground of both banks. `NoApexShelf = true`: the Apex is in a corner, so there is no full-width shelf behind it. `GroveScale = 0` and `MeadowScale = 0.15` (a new option) keep the biome's random blight trees and pods off the autumn bank; the floor places its own trees. The banks are told apart by props, not materials: golden grass, bracken, banded beeches and lanterns south of the brook; rot-blooms, blight pods, twisted and dead trees north of it. Rot-lilies, pink scum, reeds and bank stones mark the brook itself, because the place-wide teal water reads brown in this light. The mill moved downstream to `(95, −62)`, between the Fallen-Log Ford and the weir: every brook-side spot beside the Weir Mill (Crossing) lies inside a landing lane. The Heartrot Spring stands at `(206, −240)` in the low ground east of the Apex; in the corner itself the wall's mountain buried it. The planned spring cascade was dropped: the spring wells from the elder's roots straight into the brook's head pool.

**Landmarks (≥ 13):**
1. **The Heartrot Spring** at the Apex (≥ 105 studs): a split, blackened elder trunk with the spring welling from its roots, magenta rot-light in the crack, and the cascade falling beside it.
2. **The Weir Mill** on the Crossing island: a wattle-and-thatch Hollin mill with an undershot wheel turning in the brook and a fieldstone weir across the meander (the Weir Ford's sister).
3. **The Pale Glade** (`WestGallery`): a ring of healthy beeches, each tied with a white Pale Band, round a mossy graft-knot post. The Elite's camp, with one banded tree split open by the Keeper.
4. **The Woodcutters' Ring:** fresh-sawn stumps, a wardens' lean-to, a sawhorse, split logs, wax pots and a pruning-hook rack, where the Hollin cut away the first rot.
5. **The Last Green:** the greenest spot on the floor, a fieldstone knoll under a great healthy oak, banded, with a warden's bench and a lantern.
6. **The Lantern Copse** (`EastGallery`): wicker lanterns hung in young birches, a Hollin trail-shrine, and the first band stained pink.
7. **The Warding Shrine:** a fieldstone cairn ringed by banded stakes, the wardens' farthest outpost across the water, now overgrown with briar.
8. **Rothollow:** a sunken hollow of rotting trunks, rot-bloom flowers and blight pods, where the brook first turns magenta.
9. **The Blight Line:** a row of felled trees laid as a barrier across the rotten bank, with bands torn from them and left on the ground.
10. **Four ford dressings:** stepping stones with a graft-knot marker post, the fallen-log ford with its root plate, the mill-race plank, and the fieldstone weir with a spill of foam.
11. **The Sinkhole** at the west wall, where the brook drains into a mossy rock throat.
12. A **gradient forest wall** on the perimeter, green and leafy in the south-west and twisted and bare in the north-east.
13. Far: rolling forest canopy to the south, darkening to blighted crowns and a magenta haze to the north.

**Kit, as built (15 templates, `tools/blender/generate_corrupted_f31_kit.py` → `assets-source/tower/corrupted_f31_kit/`, imported into the place):** `HollinWaterMill`, `MillWheel`, `FieldstoneWeir`, `PaleBandTree`, `GraftKnotPost`, `WardensLeanTo`, `SawnStumpCluster`, `HeartrotSpringTrunk` (placed at 1.25×, 113.6 studs), `HollinStileArch`, `WattleFence`, `FieldstoneCairn`, `FelledBandLog`, `HangingLantern`, `AutumnGrassTuft`, `RotBloomCluster`. Reused: `BlightTree`, `DeadTree`, `BlightPod`, `BoulderCluster`, `StoneUrn`, `FernCluster` (bracken), `GlowLilyCluster` (rot-lilies) and `ReedPondCluster`. Set pieces: `TowerSetPieces/CorruptedGrove.luau` (`Floor31`, with `Floor31Landmarks` for the spec).

**Lighting grade (`FloorGrades[31]`), as built:** a warm gold key with a rose haze, the least murky Corrupted floor. `AtmosphereDensity 0.26`, `AtmosphereHaze 0.75`, `Saturation 0.16`, `Contrast 0.12`, `ColorShift_Top (255, 196, 128)`. Sun rays were dropped: the client destroys every `SunRaysEffect`.

**Spec asserts (`tower-layout-variants.spec.luau`):** key, name and `Size`. `Apex.X > 0` and `Apex.Z < −150` (the corner). The four ford links exist (`Fords`); two are hung (`Terrain.Bridges`, one a `LOG`) and two are causeways. **The brook rule:** with the four ford links removed, the Apex is unreachable from the Sanctuary. `Rothollow→Apex` is `STAIRS`. 16 mobs and 1 Elite. Every terrain terrace on `Y % 4 == 0`. No `Validate` problems.

---

### Floor 32: Twisted Orchard (`corrupted:2`, `EXPANDED_ENCOUNTER`)

*620 × 640 × 220, `Bottom = 0`. Overripe rose dusk.*

**Guide image:** `reference/Corrupted Grove 32.jpg`. Taken from it: the rose-amber dusk sky and rose-violet mist; the blossom-draped pleached Orchard Gate with stone footings and a graft-knot crown; the slatted timber Windfall Hollow heaped with glowing red-pink fruit and dripping magenta must; the fenced open-arbor Grafters' Yard with grafting benches, clay rootstock pots and a glowing wax cauldron; the grand Grafters' Stair climbing under a flowering pleached tunnel hung with glowing magenta rot-fruits; the terraced West and East Rows of gnarled, crutch-propped fruit trees with orchard ladders, wicker baskets and glowing magenta must puddles underneath; the mossy fieldstone West Espalier with fan-trained trees pulling away; the Skep Terrace's bench of woven golden-straw bee-skeps with two glowing hives; the cooperage shed and split stave Cider Vat pouring glowing magenta must down the eastern slope; the Felled Row's stumps and smouldering brash piles; Crookback Ridge's hunched pear tree overhanging a Hollin wooden bench and ridge-walk wattle fence; Thorn Saddle's dark briar arch; the Grafted Crown's five distinct seasonal boughs (pink cherry blossom, golden amber, olive fruiting green, crimson-plum, pale white blossom, plus one bare dead eastern limb); and the colossal domed, open-ribbed Great Cider Press rising behind the ridge with its tall central screw, oozing magenta must and dark smoke plume. Left out: the painting's Windfall Hollow sits on the south-east foreground while our validated layout keeps `Windfall` at `(-100, 6, 20)` on the south-west slope so every proven route and slope check stays intact; and the painting's dense background mist and low foliage are opened up around every camp and landing lane so combat and telegraphs read clearly.

**Story beat:** the Hollin's grafting orchard. Long rows of grafted fruit trees climb a south-facing slope to the **Graft Ridge**. Every graft has twisted and every fruit has gone soft and glowing. Behind the ridge, out of sight, lies the **Pressing Hollow** with the great cider press, where the wardens still pressed the windfall to stop the rot spreading through the fruit.

**Shape: up and over.** The route climbs the orchard slope from the Orchard Lawn to the ridge, then **descends** into the hollow, so the Apex is hidden from the arrival and sits **lower than the crest**. Three ways cross the ridge:
- **Centre:** the Grafters' Yard climbs the **Grafters' Stair** (`STAIRS`, +32) straight to **the Grafted Crown** (Y 48, the floor's high point), then the **Press Stair** (`STAIRS`, −12) drops into the hollow.
- **West:** the West Rows → West Espalier → Crookback Ridge (Y 40), then down to the Apex (−4). A ridge-walk also joins Crookback Ridge to the Crown.
- **East:** the East Rows → Skep Terrace (Y 28) → Thorn Saddle (Y 44), then down to the Apex (−8). The Cider Vats are a dead-end spur.

**New to the tower:** the first floor where every route tops out above the Apex and walks *down* to it, and the first hidden Apex. You see only the press-house smoke and the Crown's tree from the arrival. New landmark type: the great cider press and a grafted orchard.

```
                               N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │               [   PRESSING HOLLOW   ] Y36  (hidden)        │
   │                /        ║ (st, down)    \                   │
   │ [CROOKBACK RIDGE]───[ THE GRAFTED CROWN ]  [THORN SADDLE]   │
   │      Y40   ═══ GRAFT RIDGE ═══  Y48   ═══════   Y44  [CIDER] │
   │        |                  ║ (st, up)          |    [ VATS ] │
   │ [WEST ESPALIER] Y24       ║          [SKEP TERRACE] Y28 Y20│
   │        |                  ║                   |            │
   │ [WEST ROWS] Y8 [WINDFALL] [GRAFTERS' YARD] Y16  [EAST ROWS] Y12
   │        \        Y6   \      |              /               │
   │         ~~~~~~~~~~~~~ ORCHARD LAWN  Y0 ~~~~~~~~~~~~~        │
   │                            |                              │
   │                     [ ORCHARD GATE ] Y8                   │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Orchard Lawn | 0, 0, 180 | 588 × 100 | terrain |
| `Windfall` (extra) | Windfall Hollow | −100, 6, 20 | 56 × 48 | deck (a slatted fruit-drying floor) |
| `WestGallery` | West Rows | −200, 8, 60 | 88 × 76 | terrain |
| `EastGallery` | East Rows | 200, 12, 55 | 88 × 76 | terrain |
| `Crossing` | Grafters' Yard | 0, 16, 40 | 80 × 64 | terrain |
| `CiderVats` (extra) | Cider Vats | 250, 20, −110 | 60 × 52 | terrain |
| `WestEspalier` (extra) | West Espalier | −170, 24, −70 | 76 × 62 | terrain |
| `EastEspalier` (extra) | Skep Terrace | 150, 28, −80 | 76 × 62 | terrain |
| `Apex` | Pressing Hollow | 0, 36, −250 | 120 × 88 | terrain (round bowl) |
| `RidgeWest` (extra) | Crookback Ridge | −130, 40, −175 | 72 × 56 | terrain |
| `RidgeEast` (extra) | Thorn Saddle | 145, 44, −185 | 72 × 56 | terrain |
| `GraftedCrown` (extra) | The Grafted Crown | 0, 48, −140 | 84 × 60 | terrain (round) |

**Paths (15 links):** `Sanctuary→Basin` (−8, 14.5°), `Basin→WestGallery` (+8), `Basin→Crossing` (+16, 14.7°), `Basin→EastGallery` (+12), `Basin→Windfall` (+6), `WestGallery→WestEspalier` (+16, 14.4°), `EastGallery→EastEspalier` (+16), `Crossing→GraftedCrown` (`STAIRS`: the Grafters' Stair, +32, 14.81°), `GraftedCrown→Apex` (`STAIRS`: the Press Stair, −12, 14.7°), `WestEspalier→RidgeWest` (+16, 14.8°), `EastEspalier→RidgeEast` (+16, 14.8°), `RidgeWest→Apex` (−4), `RidgeEast→Apex` (−8), `EastEspalier→CiderVats` (−8), `RidgeWest→GraftedCrown` (+8).

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4 (the Grafters' Yard), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite). **Patrol:** `BASIN_LOOP` (109.4 s).

**Terrain:** one continuous south-facing slope from the Lawn up to an E–W **Graft Ridge** that joins Crookback Ridge, the Crown and Thorn Saddle. Its north face falls into a round bowl (`Shapes` round) that is the Pressing Hollow. The ridge crest must be solid ground between the three crossings. It **hides** the Apex from the Sanctuary's eye height (check this from the arrival camera), with no gap the camera can see through below Y 52. Orchard rows are shallow terrain benches (2–3 studs) running E–W across the slope, each lined with a row of twisted grafted trees. Rot-fruit puddles (tiny `Pools`, LiquidRise ≈ 0.8) sit under the trees.

**Landmarks (≥ 15):**
1. **The Great Cider Press** in the Pressing Hollow (≥ 125 studs with its press-house): a colossal oak screw-press with a pleached-willow roof, the screw beam rising through it, magenta must oozing from the bed. It is the Alpha's lair, and the floor's tallest piece stands on the hollow's back rim, clear of the portal spots.
2. **The Grafted Crown:** a single enormous grafted tree on the ridge top with five kinds of leaf on five limbs, each limb banded, one limb dead. It is the floor's beacon, seen from the arrival above the crest.
3. **The Grafters' Stair:** a long stair of fieldstone treads and root risers climbing between two rows of pleached trees whose branches meet overhead as a living arch (≥ 18 studs clear over the treads).
4. **Orchard rows** of twisted grafted fruit trees (`GraftedFruitTree`, three variants), banded, propped on crutch poles, with ladders and fruit baskets.
5. **The Windfall Hollow:** a slatted drying floor heaped with rotting windfall fruit, flies and baskets.
6. **The Grafters' Yard** (`Crossing`): grafting benches, wax pots, a rootstock nursery in clay pots, and a whetstone.
7. **The West Espalier:** a fieldstone wall with fruit trees trained flat against it in fans, half of them pulled off the wall by the rot.
8. **The Skep Terrace:** a row of wicker bee-skeps on a bench. Most are dead, two are humming, and a swarm of magenta motes hangs over them.
9. **The Cider Vats:** a cooperage yard of split barrels and a rotted vat leaking magenta must down the slope.
10. **Crookback Ridge:** a lone, hunched pear tree bent double by its own graft, with a Hollin bench under it looking back down the orchard.
11. **Thorn Saddle:** bramble choking the ridge, with a gap cut by the wardens.
12. **Felled rows:** a stretch of the east slope where the wardens felled a whole row to stop the spread: stumps in a line, burnt brash piles.
13. **The Orchard Gate:** a pleached arch over the Sanctuary exit with a graft-knot keystone.
14. **Press-house smoke** rising behind the ridge, the only hint of the hollow from the arrival.
15. Far: terraced orchard hills on the horizon, all twisting, and the first sight of a darker forest beyond.

**Kit candidates (≥ 9):** `GraftedFruitTree` (3 variants), `GreatCiderPress`, `PressHouseRoof`, `PleachedArch`, `EspalierWall`, `BeeSkepBench`, `CiderVatSplit`, `GraftingBench`, `FruitBasketPile`, `CrutchPoleProp`.

**Lighting grade (`FloorGrades[32]`):** overripe rose dusk: warm rose-amber key, heavy sweet haze, rot-fruit glows. `AtmosphereDensity ≈ 0.34`, `AtmosphereHaze ≈ 1.2`, `Contrast ≈ 0.06`, `Saturation ≈ 0.12`.

**Spec asserts:** key, name and `Size`. `GraftedCrown.Y > Apex.Y`, and every link that enters the Apex descends (`From.Y > Apex.Y`). `Crossing→GraftedCrown` and `GraftedCrown→Apex` are `STAIRS`. There is no link from the Basin, the Galleries or the Crossing straight to the Apex. 22 mobs and 2 Elites. No `Validate` problems.

---

### Floor 33: Briar Labyrinth (`corrupted:3`, `TERRAIN_VARIATION`)

*680 × 720 × 250, `Bottom = −6` (the thorn pit). Hard thorn-shadow noon.*

**Guide image:** `reference/Corrupted Grove 33.jpg`. Taken from it: the crisp violet-lavender noon sky with the colossal **Mother Graft** silhouette glowing magenta on the far north horizon; the central raised round **Thornheart Court** dominated on its north half by the massive tangled **Thornheart** briar knot wrapped around a split elder trunk with a blazing magenta heartrot cavity; the **Briar Gate** directly south across the pit whose woven hawthorn doors have grown shut with glowing magenta thorns; the sunken central **thorn pit** holding mossy stone-pedestal **topiary ruins** (a clipped stag with twig antlers and a triple-ring graft-knot topiary), snapped wooden bridges and glowing magenta briar veins; the cozy timber-and-thatch **Mender's Croft** with its chimney, grafting benches and **stitched-bark scarecrow** on the south-west approach; **Nettle Turn**'s wooden **three-arm signpost** (one arm hacked off) and hanging **Pale Bands** marking the true west path; the elevated **Hanging Garden** stilt terrace with its flowering **hanging-planter pergola**; **Briar Cloister**'s hedged arches ringing a mossy **fieldstone wellhead**; the **North Hedge Gate** framing the Thornheart from behind; **Gibbet Thicket**'s dead gnarled trees hung with empty **gibbet cages**; the **East Rosary**'s ruined mossy stone arches overgrown with giant shield-sized magenta **rot-roses**; and the false eastern dead-end **Thornwrack** where a woven briar basket nest holds a fallen warden's skeleton clutching a torn Pale Band. Left out: excessive ground clutter inside combat arenas and camp circles, keeping camp floors and the Court arena clean for telegraphs and squad movement; hedge walls stay ≤ 8.5 studs tall so the camera reads the maze clearly from above.

**Story beat:** the wardens planted a hedge-maze to wall the rot in. At its centre lies the **Thornheart**, a knot of briar the size of a house, grown round a blighted cutting of the Mother Graft that the Hollin could not burn. The briar has since run wild through the hedges, and the thorn pit has opened beneath them.

**Shape: a hedge maze over a thorn pit with the Apex in the middle.** From the arrival you see the **Thornheart Court** (the Apex) in the centre of the room across the pit, and the **Briar Gate** (Crossing, Elite) stands directly before it, **with no way across**. From the gate the maze branches:
- **East** (the false path): the East Walk leads only to **Thornwrack**, a dead end where a warden's skeleton hangs in the briar. Its hedge gates carry no bands.
- **West** (the true path, banded): West Walk → Nettle Turn → **Hanging Garden** → up the Garden Stair into the Court from the west (+18).
- **The long ring:** Nettle Turn → Briar Cloister → North Hedge Gate (behind the Court) → Gibbet Thicket → East Rosary → **Thornheart Steps** (`STAIRS`) into the Court from the south-east.
- **The croft path:** a side lane from the Briar Lawn through the **Mender's Croft** joins the West Walk without passing the Briar Gate.

**New to the tower:** a true maze, with dead ends and a false branch, loops, and two entries to a central summit that are on opposite sides from where you first see it. Also new: hedge-walled walkways (hedges at most 9 studs high, so the camera reads the maze from above). New landmark type: the Thornheart, a living briar knot.

```
                               N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │ [BRIAR CLOISTER] Y24 ── [NORTH HEDGE GATE] Y28 ── [GIBBET THICKET] Y32
   │     /     \                                          |    │
   │ [NETTLE   [ ...thorn pit... ]                 [EAST ROSARY] Y36
   │  TURN] Y20  \                                        |  [THORN-│
   │    |     [HANGING GARDEN] Y26 ═► [ THORNHEART ]       |  WRACK]│
   │    |                              [  COURT  ]  ◄═ [THORNHEART]  Y22 │
   │    |          (thorn pit)         [   Y44   ]  (st)[ STEPS Y40]  |  │
   │ [WEST WALK] Y12 ─────── [ BRIAR GATE ] Y8 ─────── [EAST WALK] Y16 │
   │       \ [MENDER'S CROFT] Y4    |   (no way across)          │
   │        \_____/                 |                           │
   │         ~~~~~~~~~~~~~~~~ BRIAR LAWN  Y0 ~~~~~~~~~~~~~~~~    │
   │                                |                           │
   │                         [ HEDGE STILE ] Y8                 │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Briar Lawn | 0, 0, 200 | 648 × 96 | terrain |
| `MenderCroft` (extra) | Mender's Croft | −100, 4, 118 | 56 × 44 | terrain |
| `Crossing` | Briar Gate | 0, 8, 80 | 84 × 64 | terrain (hedge-walled) |
| `WestGallery` | West Walk | −200, 12, 60 | 88 × 76 | terrain |
| `EastGallery` | East Walk | 200, 16, 60 | 88 × 76 | terrain |
| `NettleThicket` (extra) | Nettle Turn | −235, 20, −130 | 72 × 60 | terrain |
| `Thornwrack` (extra) | Thornwrack | 255, 22, −60 | 60 × 56 | deck (a woven-briar platform) |
| `BriarCloister` (extra) | Briar Cloister | −150, 24, −255 | 64 × 52 | terrain |
| `HangingGarden` (extra) | Hanging Garden | −150, 26, −30 | 64 × 56 | deck (a wattle garden terrace on posts) |
| `NorthGate` (extra) | North Hedge Gate | 0, 28, −235 | 80 × 60 | terrain |
| `HangingThicket` (extra) | Gibbet Thicket | 150, 32, −250 | 64 × 56 | terrain |
| `EastRosary` (extra) | East Rosary | 170, 36, −120 | 64 × 56 | terrain |
| `ThornheartSteps` (extra) | Thornheart Steps | 110, 40, −10 | 64 × 56 | terrain |
| `Apex` | Thornheart Court | 0, 44, −60 | 124 × 92 | terrain (round, `Shapes`) |

**Paths (17 links):** `Sanctuary→Basin` (−8), `Basin→Crossing` (+8), `Basin→MenderCroft` (+4, 14.1°), `MenderCroft→WestGallery` (+8, 14.5°), `Crossing→WestGallery` (+4), `Crossing→EastGallery` (+8), `EastGallery→Thornwrack` (+6, dead end), `WestGallery→NettleThicket` (+8), `NettleThicket→HangingGarden` (+6), `NettleThicket→BriarCloister` (+4), `HangingGarden→BriarCloister` (−2), `HangingGarden→Apex` (the Garden Stair, +18, 14.79°), `BriarCloister→NorthGate` (+4), `NorthGate→HangingThicket` (+4), `HangingThicket→EastRosary` (+4), `EastRosary→ThornheartSteps` (+4), `ThornheartSteps→Apex` (`STAIRS`, +4).
*Every link that crosses the thorn pit* is a `Terrain.Bridges` hedge bridge: a plank-and-wattle deck with low hedge walls on both sides, outside `UsableWidth`. Two return ramps climb out of the pit onto the Briar Lawn (built by the runtime at X ≈ ±252).

**Camps (25, 3 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite, at the Briar Gate, raised to Y 8), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (119.9 s), `GATE_WALK` = `{WestGallery, Crossing, EastGallery}` (160.9 s), `WEST_MAZE` = `{WestGallery, NettleThicket, HangingGarden}` (130.0 s), `OUTER_RING` = `{BriarCloister, NorthGate, HangingThicket, EastRosary}` (173.6 s).

**Terrain:** `Bottom = −6`, **`Surface = "BLIGHT"`** with **`Blight = { FissureDepth = 4.5, CragHeight = 14 }`** (the first deeply corrupted floor: violet cobble paths, deep indigo blighted earth, blackened basalt fissures/cliffs, dark violet-slate banks and abyssal pit floor — no plain brown earth and no water). Jagged corrupted basalt crags (`Ridges`) jut out of open pit pockets around the central mesa, and a raised rocky mound at `(0, −166)` seats the Thornheart behind the Court (with `NorthGate` shifted to `Z = −255` for clearance). Every terrace is a raised hedge-topped mound (`Shapes`, squircle) with sheer blackened basalt banks draped in black briar roots and glowing violet-magenta cliff veins (`Neon`, hue ~300°) descending into the scarred thorn pit. Hedge walls run along terrace edges and `BridgeStyles = "HEDGE"` bridge sides, broken only where a link lands, staying ≤ 9 studs so the maze reads from above. The south face of the Court and the north face of the Briar Gate are sheer briar-veined cliffs so the gap reads as impassable (Infernal 24 lesson: no fake bridge between terraces that have no link).

**Landmarks (≥ 17):**
1. **The Thornheart** on the Court (≥ 150 studs): a house-sized knot of black briar on the back (north) half of the Court, grown round a split stump with a magenta cavity. Spikes reach up and out, never over the arena floor or the portal spots.
2. **The Briar Gate:** a pleached hawthorn gatehouse whose doors have grown shut toward the Court, with the gate-arch facing the Thornheart.
3. **Hedge walls** throughout (`HedgeWallSegment`, straight, corner and broken variants), ≤ 9 studs over the walk.
4. **Thornwrack:** the false path's end, with a warden's skeleton in the briar and a torn band in its hand.
5. **The Hanging Garden:** a wattle terrace of hanging planters and a pergola, the wardens' rest stop on the true path.
6. **The Mender's Croft:** a wattle-and-daub croft with grafting benches, the Rot Mender's sap-lantern hook and a stitched-bark scarecrow.
7. **Nettle Turn:** a stinging-nettle bed and a banded signpost with three arms, one hacked off.
8. **The Briar Cloister:** a square of pleached arches round a dry wellhead, overgrown.
9. **The North Hedge Gate:** a tall hedge arch behind the Court with a view of the Thornheart from behind.
10. **Gibbet Thicket:** wicker gibbet cages hung in dead trees, empty, swinging.
11. **The East Rosary:** a rose garden gone to rot-bloom, magenta roses the size of shields.
12. **Thornheart Steps:** fieldstone steps cut through a briar bank into the Court.
13. **Band-tied hedge gates** marking the true path at every turn (none on the false path).
14. **The thorn pit:** thorn knots, bone litter and snapped hedge bridges at the bottom.
15. **Topiary ruins:** the maze's old clipped topiary (a stag, an owl, a graft-knot) gone shaggy and blighted.
16. **Return-ramp briar stairs** climbing out of the pit, dressed so they read as the way out.
17. Far: a sea of hedge-tops and dead trees, and the **Mother Graft** visible for the first time on the far horizon.

**Kit candidates (≥ 10):** `HedgeWallSegment` (3 variants), `ThornheartKnot`, `BriarGatehouse`, `WattleCroft`, `HangingPlanterPergola`, `GibbetCage`, `RotRoseBush`, `TopiaryRuin` (2 variants), `ThreeArmSignpost`, `ThornKnotCluster`, `WardenSkeleton`.

**Lighting grade (`FloorGrades[33]`):** hard overhead thorn-shadow noon with deep shadows in the hedges and a cool violet ambient. `AtmosphereDensity ≈ 0.30`, `AtmosphereHaze ≈ 0.9`, `Contrast ≈ 0.16`, `Saturation ≈ 0.0`. The crispest, least hazy Corrupted floor, so the maze reads from above.

**Spec asserts:** key, name and `Size` (`Bottom = −6`, 2 return ramps). There is no `Crossing→Apex` link. The **maze rule:** removing `HangingGarden→Apex` and `ThornheartSteps→Apex` leaves the Apex unreachable, and `Thornwrack` has exactly one link (a dead end). The Apex is centred (`|Apex.X| ≤ 10`, and `Apex.Z` within the middle third of the room's depth). `ThornheartSteps→Apex` is `STAIRS`. 25 mobs and 3 Elites. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

### Floor 34: Heartrot Stronghold (`corrupted:4`, `ELITE_STRONGHOLD`)

*750 × 795 × 275, `Bottom = −6` (the rot bog). Green-black canopy gloom with shafts of light.*

**Story beat:** the wardens' last refuge. When the maze failed, the Hollin climbed into the five greatest elder trees of the grove and built a stronghold in their trunks: bracket decks, treehouse keeps and branch bridges, with a palisade of sharpened stakes round the bog below. The Heartrot reached them through the roots. The elders are rotting from the inside, and the keeps are full of the wardens' last things.

**Shape: tree to tree up five elder trunks over a rot bog, to a keep in the fork of the greatest tree at the back-west.** Below, the Sedge Landing reaches the Rootgate palisade (Crossing) and the two stockades (Galleries). Above, every terrace is a deck bracketed onto or ringed round one of the five elder trunks. Branch bridges (`Terrain.Bridges`, rope-and-branch) span the bog between them:
- **Tree I, the Gate Elm** (centre): the Lower Bole ring deck, and the **Bole Stair** (`STAIRS`, +20) climbing its trunk to the Middle Fork.
- **Tree II** (west): the Sap Cistern, a deck round a sap-tap, rising to **Tree IV**, the West Bole Keep (Elite).
- **Tree III** (east): the Bracket Ledge, a giant shelf-fungus deck, rising to **Tree V**, the East Bole Keep (Elite).
- **The Great Rotwood** (back-west): the **Heartrot Crown** (Apex, Y 52) in its fork, reached from the West Bole Keep (direct), the Middle Fork, and the long Canopy Walk from the East Bole Keep.

**New to the tower:** terraces built *on* living trees (bracket decks and ring decks round trunks, a stair up a trunk), and an Apex in a tree's fork off-centre at the back-west. New landmark type: Hollin treehouse keeps.

```
                               N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │ [WEEPING ]  [ HEARTROT CROWN ] Y52 ◄────────── [CANOPY WALK] Y44
   │ [GALLOWS ]    (Great Rotwood)  \                     /     │
   │   Y48  \        ▲      ▲        \                   /      │
   │   [WEST BOLE KEEP] Y32  \    [MIDDLE FORK] Y40─[SEED VAULT] Y30
   │         |  (Tree IV)     \______/  ║ (st, Bole Stair)  [EAST BOLE KEEP] Y36
   │   [SAP CISTERN] Y26 ─── [LOWER BOLE] Y20 ─── [BRACKET LEDGE] Y18  (Tree V)
   │ [MENDER'S]  (Tree II)    (Tree I)          (Tree III)      │
   │ [ WARD Y6]      \           |                    /         │
   │      \  [WEST STOCKADE] Y12  [ROOTGATE] Y8  [EAST STOCKADE] Y14
   │                  \           |              /              │
   │         ~~~~~~~~~~~~~~~ SEDGE LANDING  Y0 ~~~~~~~~~~~~~~    │
   │                              |                            │
   │                        [ BOG STAIR ] Y8                   │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Sedge Landing | 0, 0, 232 | 718 × 104 | terrain |
| `MenderWard` (extra) | Mender's Ward | −295, 6, −20 | 56 × 52 | deck (a stilt hut over the bog) |
| `Crossing` | Rootgate | 0, 8, 110 | 88 × 68 | terrain (palisaded) |
| `WestGallery` | West Stockade | −205, 12, 95 | 92 × 80 | terrain |
| `EastGallery` | East Stockade | 205, 14, 85 | 92 × 80 | deck (a boardwalk stockade on stilts) |
| `ShelfLedge` (extra) | Bracket Ledge | 160, 18, −40 | 72 × 60 | deck (shelf-fungus bracket on Tree III) |
| `LowerBole` (extra) | The Lower Bole | 0, 20, 0 | 80 × 64 | deck (ring deck round Tree I) |
| `SapCistern` (extra) | Sap Cistern | −150, 26, −60 | 72 × 60 | deck (on Tree II) |
| `SeedVault` (extra) | Seed Vault | 110, 30, −150 | 60 × 52 | deck (a hollow-limb store) |
| `WestBastion` | West Bole Keep | −240, 32, −170 | 92 × 82 | deck or terrain on Tree IV's root plate |
| `EastBastion` | East Bole Keep | 235, 36, −160 | 92 × 82 | deck or terrain on Tree V's root plate |
| `MiddleFork` (extra) | Middle Fork | 0, 40, −150 | 80 × 64 | terrain (the Gate Elm's fork, a raised root mound) |
| `CanopyWalk` (extra) | Canopy Walk | 130, 44, −275 | 76 × 60 | terrain |
| `WeepingGallows` (extra) | Weeping Gallows | −300, 48, −300 | 56 × 52 | terrain |
| `Apex` | Heartrot Crown | −150, 52, −290 | 136 × 100 | terrain (round, the Great Rotwood's fork) |

**Paths (19 links):** `Sanctuary→Basin` (−8), `Basin→Crossing` (+8), `Basin→WestGallery` (+12), `Basin→EastGallery` (+14), `WestGallery→MenderWard` (−6), `Crossing→LowerBole` (+12, 14.3°), `WestGallery→SapCistern` (+14), `EastGallery→ShelfLedge` (+4), `LowerBole→SapCistern` (+6), `LowerBole→ShelfLedge` (−2), `SapCistern→WestBastion` (+6), `ShelfLedge→EastBastion` (+18, 14.8°), `LowerBole→MiddleFork` (`STAIRS`: the Bole Stair, +20), `MiddleFork→SeedVault` (−10), `EastBastion→CanopyWalk` (+8), `MiddleFork→Apex` (+12), `CanopyWalk→Apex` (+8), `WestBastion→Apex` (+20, 14.81°), `WestBastion→WeepingGallows` (+16).
*Every link past the Sedge Landing* that spans the bog is a `Terrain.Bridges` branch bridge: a rope-and-branch deck with rope rails, hung from limbs overhead ≥ 18 studs clear. Two return ramps climb out of the bog onto the Landing (X ≈ ±278).

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite, the West Bole Keep at Y 32), `UPPER_EAST` 5 (Elite, the East Bole Keep at Y 36).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (132.3 s), `BOLE_RING` = `{SapCistern, LowerBole, ShelfLedge}` (130.7 s), `WEST_CLIMB` = `{WestGallery, SapCistern, WestBastion}` (123.3 s), `EAST_CLIMB` = `{EastGallery, ShelfLedge, EastBastion}` (110.7 s), `CROWN_WALK` = `{WestBastion, Apex, MiddleFork}` (143.5 s).

**Terrain:** `Bottom = −6`, **`Surface = "BLIGHT"`** with **`Blight = { FissureDepth = 5.0, CragHeight = 15 }`** — a deeply corrupted violet-black rot bog (`Asphalt` / `Pavement` / `Basalt` with ridged corruption veins and abyssal shallow `Water` pools at `LiquidRise ≈ 1.8`, sedge and blight-pod ground cover, and glowing magenta heartrot veins snaking through the bog and climbing the root-plates and trunk bases). Each elder tree's root plate is a broad jagged corrupted mound (`Ridges` / `Islands`) rising from the bog under its decks, with the trunk mesh standing on it. **Trunk placement is the hardest part of this floor.** Trunks are big, and big boxes trip `CampHitTest` and `WalkwayHitTest` (skill §5.2). Put each trunk beside its deck, off every lane and ≥ 34 studs from camp centres. Model the trunk as several kit pieces (root flare, bole, fork) so one failed piece doesn't take the whole tree. Spec-check the footprints offline before Studio.

**Landmarks (≥ 19):**
1. **The Great Rotwood** behind the Heartrot Crown (≥ 175 studs): the largest elder, split down one side to a glowing heartrot cavity, its fork cradling the Apex. Its branches arch round the dais but never over the combat floor or the portal spots.
2. **The Heartrot Crown keep:** the wardens' last hall in the fork, with a shingled roof torn half away, the bands wound round its posts soaked magenta, and their final barricade.
3. **The five elder trunks** (Trees I–V), each ≥ 120 studs, each with a different rot (split, hollowed, fungus-shelved, root-heaved, bark-sloughed).
4. **The Bole Stair:** a stair of plank treads pegged up the Gate Elm's flank with a rope handrail.
5. **The West and East Bole Keeps:** treehouse keeps with shingle roofs, arrow slits cut in bark, and band-wound trunks.
6. **The Bracket Ledge:** a shelf-fungus bracket the size of a terrace, with smaller brackets stepping below it.
7. **The Sap Cistern:** a sap-tap with a wooden spout, a cistern tub and buckets, the sap gone magenta.
8. **The Seed Vault:** a hollow limb stacked with sealed seed jars, the Hollin's last clean cuttings (echo the *Heartrot Core* relic: one jar caged in thorns).
9. **The Weeping Gallows:** a dead tree with rope ends where the wardens hung their dead out of the bog, bands on each rope. Keep it sombre, not gory.
10. **The Rootgate:** a palisade gate of sharpened stakes woven into the Gate Elm's roots.
11. **The two stockades:** wattle palisades, watch-ladders and the wardens' cots.
12. **The Mender's Ward:** a stilt hut where the wardens tended the sick, now the Rot Menders' nest.
13. **Branch bridges** with rope rails, lanterns on the hangers, and one cut bridge hanging uselessly into the bog (clearly severed, never reaching a terrace).
14. **Hanging moss curtains** from the high limbs, all outside walk lanes and ≥ 18 studs clear.
15. **Light shafts** through canopy gaps: invisible `SpotLight` anchors and a few beam meshes over the bog, never over a camp.
16. **Bog life:** half-sunk logs, rot-bloom lilies, a sunken warden's boat.
17. **Barricades** of lashed branches at the top of every climb, broken through.
18. **The Canopy Walk:** a long, high branch path with carved handholds and a lookout seat.
19. Far: the canopy roof closing overhead at the room's edges (open sky only in the middle), and the Mother Graft's silhouette much nearer.

**Kit candidates (≥ 11):** `ElderTrunkRootFlare`, `ElderTrunkBole` (2 variants), `ElderTrunkFork`, `GreatRotwoodCavity`, `TreehouseKeep`, `BoleStairRail`, `ShelfFungusBracket` (2 sizes), `SapTapCistern`, `SeedJarStack`, `BranchBridgeHanger`, `StakePalisadeSegment`, `StiltHut`, `MossCurtain`.

**Lighting grade (`FloorGrades[34]`):** green-black canopy gloom, sun rays through gaps, magenta heartrot glows from the cavities. `AtmosphereDensity ≈ 0.40`, `AtmosphereHaze ≈ 1.4`, `BloomIntensity ≈ 0.50`, `SunRays` on, `Saturation ≈ 0.06`. The darkest Corrupted floor. Check that the camps and telegraphs still read.

**Spec asserts:** key, name and `Size` (`Bottom = −6`, 2 return ramps). `Apex.X < −100` and `Apex.Z < −250` (back-west), and the Apex is the highest terrace. `LowerBole→MiddleFork` is `STAIRS`. Three links enter the Apex (`WestBastion`, `MiddleFork`, `CanopyWalk`). `UPPER_WEST` and `UPPER_EAST` sit above Y 30. 35 mobs and 4 Elites. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

### Floor 35: Sovereign's Grove (`corrupted:5`, `BOSS_ARENA`)

*810 × 795 × 305, `Bottom = −8` (the sap mire). Blight eclipse.*

**Story beat:** the Mother Graft. The whole floor is its root crown: three colossal roots fan out from the dais at the back and reach toward the arrival like the fingers of a hand, over a mire of its weeping sap. The Sovereign stands in the cavity of its own dead trunk. The last Pale Band, enormous and rotten, is tied round the trunk below the heart. At the foot of the Taproot stands the Last Warden.

**Shape: up the backs of three roots to the palm.** You arrive on the **Mire Shore** and see all three roots rising away from you toward the **Sovereign's Dais** (Apex, Y 60, `184 × 136`, the largest Apex in the tower):
- **West Root:** West Root Foot (Y 8) → West Root Knee (Y 20) → West Root Crest (Y 36, Elite) → West Root Crown (Y 48) → the Dais.
- **The Taproot** (centre): Taproot Foot (Crossing, Y 12) → Taproot Knuckle (Y 24) → Taproot Spine (Y 40) → the **Heart Stair** (`STAIRS`, +20) to the Dais.
- **East Root:** East Root Foot (Y 10) → East Root Knee (Y 22) → East Root Crest (Y 38, Elite) → East Root Crown (Y 50) → the Dais.
- **Cross-roots:** the Taproot Knuckle joins both knees (the roots touch there). Four spurs hang off the roots: the Weeping Pulpit and the Rotbloom Nursery over the mire, the Fallen Crown Ring (west) and the Sapfall Ledge (east).

**New to the tower:** walking along the tops of colossal roots that belong to the boss, which all converge on its dais. New landmark type: the Mother Graft, a ≥ 230-stud dead colossus tree behind the arena, the tallest landmark in the tower.

```
                               N (−Z)
   ┌──────────────────────────────────────────────────────────┐
   │             ▲▲▲ THE MOTHER GRAFT (≥230, behind) ▲▲▲        │
   │ [W. ROOT CROWN] Y48 ─► [ SOVEREIGN'S DAIS ] ◄─ [E. ROOT CROWN] Y50
   │        |                [ 184 × 136  Y60 ]           |     │
   │        |                       ║ (st, Heart Stair)   |     │
   │ [FALLEN] [W. ROOT CREST]  [TAPROOT SPINE]  [E. ROOT CREST] [SAP-]
   │ [ CROWN]       Y36              Y40              Y38  [FALL ]
   │ [RING Y28]       |                |                |  [Y30  ]
   │      \  [W. ROOT KNEE] ── [TAPROOT KNUCKLE] ── [E. ROOT KNEE]
   │              Y20                  Y24                Y22   │
   │               |  [WEEPING]       |       [ROTBLOOM]   |    │
   │               |  [PULPIT Y14]    |     [NURSERY Y18]  |    │
   │       [W. ROOT FOOT] Y8   [TAPROOT FOOT] Y12   [E. ROOT FOOT] Y10
   │               \                  |                 /       │
   │           ~~~~~~~~~~~~~~ MIRE SHORE  Y0 ~~~~~~~~~~~~~~      │
   │                                  |                         │
   │                          [ THE LAST BAND ] Y8              │
   └──────────────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Mire Shore | 0, 0, 236 | 778 × 104 | terrain |
| `WestGallery` | West Root Foot | −230, 8, 100 | 92 × 80 | terrain |
| `EastGallery` | East Root Foot | 230, 10, 100 | 92 × 80 | deck (root-bark deck) |
| `Crossing` | Taproot Foot | 0, 12, 105 | 88 × 68 | terrain |
| `WeepingPulpit` (extra) | Weeping Pulpit | −120, 14, 40 | 60 × 50 | deck (a root-burl over the mire) |
| `RotbloomNursery` (extra) | Rotbloom Nursery | 120, 18, 40 | 60 × 50 | deck |
| `WestRootKnee` (extra) | West Root Knee | −250, 20, −30 | 76 × 64 | terrain |
| `EastRootKnee` (extra) | East Root Knee | 250, 22, −30 | 76 × 64 | deck |
| `TaprootKnuckle` (extra) | Taproot Knuckle | 0, 24, −20 | 80 × 64 | terrain |
| `FallenCrownRing` (extra) | Fallen Crown Ring | −330, 28, −120 | 60 × 56 | terrain |
| `SapfallLedge` (extra) | Sapfall Ledge | 330, 30, −120 | 60 × 56 | deck |
| `WestBastion` | West Root Crest | −200, 36, −160 | 92 × 82 | terrain |
| `EastBastion` | East Root Crest | 200, 38, −160 | 92 × 82 | deck |
| `TaprootSpine` (extra) | Taproot Spine | 0, 40, −140 | 76 × 56 | terrain |
| `WestRootCrown` (extra) | West Root Crown | −165, 48, −290 | 64 × 56 | terrain |
| `EastRootCrown` (extra) | East Root Crown | 165, 50, −290 | 64 × 56 | deck |
| `Apex` | Sovereign's Dais | 0, 60, −300 | 184 × 136 | terrain (round, `Shapes`) |

**Paths (21 links):** `Sanctuary→Basin` (−8), `Basin→WestGallery` (+8), `Basin→Crossing` (+12, 14.0°), `Basin→EastGallery` (+10), `WestGallery→WestRootKnee` (+12), `EastGallery→EastRootKnee` (+12), `Crossing→TaprootKnuckle` (+12), `WestRootKnee→WestBastion` (+16, 14.8°), `EastRootKnee→EastBastion` (+16, 14.8°), `WestBastion→WestRootCrown` (+12), `EastBastion→EastRootCrown` (+12), `WestRootCrown→Apex` (+12, 14.7°), `EastRootCrown→Apex` (+10), `TaprootKnuckle→TaprootSpine` (+16, 14.3°), `TaprootSpine→Apex` (`STAIRS`: the Heart Stair, +20, 14.81°), `WestGallery→WeepingPulpit` (+6), `EastGallery→RotbloomNursery` (+8), `WestRootKnee→FallenCrownRing` (+8, 14.5°), `EastRootKnee→SapfallLedge` (+8, 14.5°), `TaprootKnuckle→WestRootKnee` (−4), `TaprootKnuckle→EastRootKnee` (−2).
*Root walks:* every link **along** a root (Foot → Knee → Crest → Crown → Dais, and the Taproot chain) is the root itself. Lay it as a terrain ridge capped with root-bark kit segments (`RootRidgeSegment`) so you walk on the root's back, with bark plates, moss and side-roots, never a plank bridge. Links that leave a root over the mire (the cross-roots, the four spurs, and the Basin to each Foot) are `Terrain.Bridges` root-burl bridges. Two return ramps climb out of the mire onto the Shore (X ≈ ±300).

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite, Y 36), `UPPER_EAST` 5 (Elite, Y 38). The **Blight Sovereign** is summoned on the `184 × 136` dais. **Briar Whip** (`ARC`), **Heartrot Bloom** (`SELF_DISC`) and **Rot Tendrils** (`TARGET_DISC`) must stay on the dais and never spill onto a root. Keep the dais floor clean: dark root-bark and mud, ringed on the outer rim only by low side-roots and the Pale Band stakes.

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (142.8 s), `WEST_ROOT` = `{WestGallery, WestRootKnee, WestBastion, WestRootCrown}` (163.9 s), `EAST_ROOT` = `{EastGallery, EastRootKnee, EastBastion, EastRootCrown}` (163.9 s), `TAPROOT` = `{Crossing, TaprootKnuckle, TaprootSpine}` (99.3 s), `KNEE_CHORD` = `{WestRootKnee, TaprootKnuckle, EastRootKnee}` (200.2 s), `CROWN_RING` = `{WestRootCrown, Apex, EastRootCrown}` (133.3 s).

**Terrain:** `Bottom = −8`, **`Surface = "BLIGHT"`** with **`Blight = { FissureDepth = 6.0, CragHeight = 16 }`** — the deepest drop and most heavily corrupted terrain in the biome. The sap mire is abyssal blackened `Asphalt` and scarred `Basalt` with broad, shallow `Water` sap pools (`LiquidRise ≈ 2`), jagged corrupted outcrops, floating rot-scum and glowing violet-magenta heartrot fissures converging toward the dais. The three roots are long blackened basalt/violet-veined terrain ridges (`Ridges` / `Shapes` chains) whose crests carry the walk, with steep root-plated, glowing-veined cliffs plunging into the mire, tapering toward the shore and thickening toward the dais. The dais is the corrupted root crown: a round mesa (`Shapes` round) veined with dark basalt and violet cobble at the foot of the Mother Graft, leaving green moss only in a tiny ring round the Last Warden.

**Landmarks (≥ 21, plus the colossal centrepiece):**
1. **The Mother Graft (colossal centrepiece, ≥ 230 studs):** the dead colossus trunk behind the dais, with a hundred kinds of dead branch, the heart-cavity glowing magenta at about Y 120, and the last Pale Band tied round the trunk below it. It stands at the back wall and beyond. Its trunk and limbs **never overhang the `184 × 136` arena** and stay clear of `Layout.PortalSpots`.
2. **The three great roots,** dressed end to end with root-bark segments, side-roots, moss and rot-bloom, thickening toward the dais.
3. **The Last Warden** at the Taproot Foot: a Hollin warden half-grafted into the root, knife in hand, with a ring of green moss and ferns round their feet (the only green on the floor).
4. **The Heart Stair:** treads cut into the Taproot's final rise, flanked by banded stakes, climbing straight at the cavity.
5. **The Sovereign's Dais rim:** low side-roots and Pale Band stakes on the outer edge only.
6. **The Weeping Pulpit:** a root-burl lookout over the mire, weeping sap down its sides.
7. **The Rotbloom Nursery:** a bed of shield-sized rot-blooms the Sovereign is growing, breathing spores (echo the *Rotbloom Urn* relic).
8. **The Fallen Crown Ring:** a fallen ring of the Mother Graft's old crown branches, like a broken circlet, on the west spur.
9. **The Sapfall Ledge:** magenta sap pouring off a root into the mire in a slow sticky fall (a mesh ribbon, not a flat transparent box).
10. **The Knee Junctions:** where the roots touch at the knees, bark fused and cracked, with blight pods bursting from the seams.
11. **Root crests and crowns:** knots, burls and a warden's shrine on each crest.
12. **The sap mire:** floating rot-scum, sunken grafting tools, bones of old Rotwood Keepers.
13. **Hanging moss mantles** from the Mother Graft's lowest limbs, at the room's edges and far above.
14. **Grafted limbs** of every species jutting from the trunk: an oak limb, a pine limb, a fruit limb with rotten fruit.
15. **The ring of dead elders** round the room's rim, bowing toward the Mother Graft.
16. **Rot-light seams** pulsing along every root on the Rotpulse.
17. **Spore drifts** in the air over the mire.
18. **A heartrot geode** split open at the West Root Crown (echo the *Blightroot Geode* relic).
19. **A thorn-caged seed** at the East Root Crown (echo the *Heartrot Core* relic).
20. **The Last Band** at the Sanctuary: a single clean white band on a post, the wardens' final marker before the grove.
21. Far: a ring of dead forest under a crimson-violet eclipse sky, with the Mother Graft's crown filling the upper half of the view from the arrival.

**Kit candidates (≥ 12):** `MotherGraftTrunk`, `MotherGraftCavity`, `MotherGraftLimb` (4 species variants), `GiantPaleBand`, `RootRidgeSegment` (straight and bend), `RootKneeJunction`, `LastWardenGraft`, `RotbloomGiant`, `FallenCrownBranch`, `SapfallRibbon`, `HeartrotGeode`, `ThornCagedSeed`, `MossMantle`.

**Lighting grade (`FloorGrades[35]`):** blight eclipse. A dim crimson-violet sky, the Mother Graft's cavity the brightest light on the floor, magenta seams on the roots. The dais is lit by a soft cool key so the Sovereign and every telegraph read. `AtmosphereDensity ≈ 0.36`, `AtmosphereHaze ≈ 1.2`, `BloomIntensity ≈ 0.6`, `Contrast ≈ 0.10`. The crimson stays in the sky and the far layer only, never on the dais or a camp.

**Spec asserts:** key, name and `Size` (`Bottom = −8`, 2 return ramps). The Apex is `184 × 136` at Y 60, is the highest terrace, and is entered by exactly three links (`WestRootCrown`, `TaprootSpine`, `EastRootCrown`). `TaprootSpine→Apex` is `STAIRS`. The Apex's landmark footprints stay off the arena and the portal lanes. 35 mobs, 4 Elites and the Boss camp. Authored patrols resolve and stay under 240 s. No `Validate` problems.

---

## Part 4: Lighting per floor

Add `HubLighting.FloorGrades[31..35]`, each layered over `BiomeGrades[7]` (magenta murk), as the earlier floors did. `ClockTime` is shared and never changes: show the mood through colour shift, ambient, atmosphere, tint, contrast, bloom and sun rays. No two neighbouring floors may share a mood.

| Floor | Mood | Key and ambient | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 31 | Sickly gold afternoon | Warm gold key from the south-west; the green bank stays green | Light haze (`Density ~0.30`, `Haze ~1.0`) thickening magenta to the north-east | Fireflies over the brook; magenta scum on the water |
| 32 | Overripe rose dusk | Rose-amber key; warm, sweet and heavy | `Density ~0.34`, `Haze ~1.2` | Glowing rot-fruit; press-house smoke behind the ridge |
| 33 | Hard thorn-shadow noon | High, white-violet key; deep hedge shadows | Crisp (`Density ~0.30`, `Haze ~0.9`, `Contrast ~0.16`) | Low saturation; the maze reads from above |
| 34 | Canopy gloom | Green-black ambient, sun rays through gaps | Thick (`Density ~0.40`, `Haze ~1.4`, `Bloom ~0.5`) | Magenta cavities in the elder trunks |
| 35 | Blight eclipse | Crimson-violet sky; cool soft key on the dais | `Density ~0.36`, `Haze ~1.2`, `Bloom ~0.6` | The Mother Graft's cavity; root seams on the Rotpulse |

Keep each floor at ≤ 24 lights. Effects are client-only, pooled and quality-scaled.

---

## Part 5: Engineering

### 5.1 Room sizing

`TowerLayout` already supports `Size = { Width, Depth, Height, Bottom? }`, and every consumer reads the built layout's dimensions. All five Corrupted rooms are open-sky: `TowerRoomBuilder`'s `isNatural` test already includes `corrupted_grove` (about line 482), so no vault ceiling closes them. Floor 34's canopy roof is props at the room's edges, not a ceiling. `HubLighting.TowerFloorAt` (2,400-stud grid) holds `810 × 795`. Floors 1–30 and 36–50 stay byte-identical.

### 5.2 Set pieces

Put each floor's set pieces in its own block. Once a floor's block passes about 800 lines, split it into `ServerScriptService/Core/TowerSetPieces/CorruptedFloor<N>.luau`, mirroring `InfernalFloor24/25.luau`, and export each floor's landmark footprints for offline lane and camp checks. Use the shared helpers (`piece`, `group`, `kitAt`, `onTerrain`, `groundY`). Positions in a floor block are room-local: add `origin` when you set `.CFrame` yourself.

### 5.3 Terrain, surface and materials

**Materials are place-wide.** Never use or recolour Fungal-owned materials (`Cobblestone`, `Concrete`, `Pavement`, `Asphalt`), never recolour shared `MaterialColors`, and never use `TowerTerrain.BlockyMaterials` (`Brick`, `WoodPlanks`): Roblox collides them as 4-stud steps.

`HOLLIN` in `TowerTerrain.Surfaces`, as built on Floor 31, uses materials the grove can share without recolouring:
`Trail = Sand` (pale trodden paths), `Walk = Ground` (brown earth), `WalkAccent = Sand` (dry autumn patches), `Bank = Ground`, `Cliff = Slate`, `Peak = Basalt`, `PoolBed = Mud`, `Lush = Ground`.
**Mud only under water:** its rippled texture reads as water on dry ground (Floor 31's first build looked flooded). `LeafyGrass` was tried as the accent and read too green for the autumn bank. The magenta comes from props, glows and light, **never** from recoloured terrain.

New terrain work, only where the floor needs it, obeying every terrain rule (terraces on the 4-stud grid, never under `Bottom − 4`, FBM edges, round aprons):
- A **brook** chain (Floor 31): a polyline of overlapping `Pools`, or a small `BROOK` helper that emits them, plus the cascade and sinkhole.
- A **ridge crest** (Floor 32): a continuous E–W ridge joining three terraces, with a bowl behind it.
- **Hedge mounds** (Floor 33): squircle `Shapes` with steep banks into the pit.
- **Root plates** (Floor 34): `Islands` mounds under each elder trunk.
- A **`ROOT_RIDGE`** (Floor 35): long tapering ridges along the root links. If a chain of `Shapes` can't make a continuous crest, add this as a new terrain feature and document it in `docs/TOWER_NAVIGATION.md`.

A round shape's rock apron reaches about 30–36 studs past the shape (skill §3.3), so pools and moats round a round terrace must be bigger than they look on the map.

### 5.4 Kits: enough meshes for the ladder

1. Reuse first: `BlightTree`, `DeadTree`, `GiantMushroom` (corrupted colours), `BlightPod`, `BoulderCluster`, `RuinRubble`, `StoneUrn`, `FoliageBush`, `Obelisk` (as fieldstone markers), `FernCluster`, `HollowStumpRim` and `RootBridgeArch` (`verdant_f3_kit`), `RotcapCluster`, `RotMyceliumWeb` and `OssuaryBones` (`fungal_f9_kit`), retinted to the Corrupted palette.
2. Generate each floor's new templates with `tools/blender/generate_corrupted_f<N>_kit.py` → `assets-source/tower/corrupted_f<N>_kit/` (FBX, .blend, `manifest.json`, previews). **Commit the generator.**
3. Register every template in `TowerBiomeKit.ExtraTemplates` only (Size, Min, Roles from the manifest). Names must be unique across all kits. Add only big architectural or natural pieces to `CastsShadow`.
4. No new colour roles (decided on Floor 31): the existing roles carry the grove. `SILK` is the Pale Bands' linen, `ALT` thatch and straw, `STONE` fieldstone, `TRIM` pale cut wood and carved rings, `GLOW` rot light or lantern glass, `CANDLE` flames, `STEM`/`CAP` rot-bloom stalks and petals. Each floor passes a full tint table (`AUTUMN`, `ROTTEN`, `BLOOM` and so on in `TowerSetPieces/CorruptedGrove.luau`), so no template falls back to the biome palette.
5. Every template gets a part-built fallback in `TowerBiomeAssets` until it is imported (`TowerKitProps.Has(name)`).
6. **Uploading a kit creates permanent Roblox assets: ask the user before each upload.** On a yes: upload the FBX, insert it, run `tests/studio-tower-biome-kit-import.luau`, and ask the user to save the place.

### 5.5 Lessons from Floors 1–25 (each came from a real fix)

1. **Clearance removes a whole prop group if one part fails, silently.** Count every floor's set pieces after each build (`studio-verify.luau`). Fix a removed piece by moving or turning it, **never** by raising it on a plinth.
2. **Big kit meshes have big boxes.** A Fungal mushroom's gill mesh reached a boss slot from 37 studs away. The elder trunks (34) and the Mother Graft (35) are the riskiest pieces in the tower: split them into parts and check each footprint.
3. **Natural, not stacked.** Trees and roots grow from `groundY` with roots, rock and moss at the foot. Never stand a tree on a block. Use round `Shapes`, not square plinths.
4. **No fake bridges.** Where two terraces have no link (Floor 31's banks away from the fords, Floor 32's Lawn to the Hollow, Floor 33's Briar Gate to the Court, Floor 34's cut bridge), the gap must read as impassable.
5. **No flat semi-transparent boxes** for glow, mist or sap. Use sculpted meshes, particles and invisible `PointLight` anchors.
6. **Never blocky materials** (`Brick`, `WoodPlanks`) on terrain.
7. **Check pitch signs** on leaning trees, hanging moss, sap falls and fallen logs so nothing slopes upward or floats.
8. **Terrain terraces on multiples of 4.** Only decks sit at other heights.
9. **Overheads versus the camera:** pleached arches, branch bridges' hangers, moss curtains and the Mother Graft's limbs stay ≥ 18 studs clear over walk surfaces and never overhang the Floor 35 arena.
10. **Small clutter is non-collidable** (`CanCollide`, `CanQuery` and `CastShadow` all false), and grounding raycasts include `workspace.Terrain` with `IgnoreWater = true`.
11. **≤ 24 lights per floor.** Count after every build.

### 5.6 The Rotpulse (client-only)

- One client module (`StarterPlayerScripts/Rendering/Rotpulse.luau`) that runs **only** while the local player is on Floors 31–35.
- Synchronised from `workspace:GetServerTimeNow()`, so every player sees the same pulse with zero remotes. The cycle tightens from about 14 s on Floor 31 to about 5 s on Floor 35 (a heartbeat).
- On each pulse, acting on `CollectionService`-tagged parts and emitters with strict instance caps: flare root seams and rot-blooms (magenta Neon), puff spore emitters briefly, play one spatial creak or groan from the nearest large trunk, and add a small bloom nudge (`+0.05..0.1`, never a screen flash).
- **Zero gameplay effect.** At the lowest Graphics quality only the Neon pulse runs.

### 5.7 Telegraph readability

Enemy telegraphs are crimson `(255, 25, 55)` and orange `(255, 95, 40)`. The grove's glow must never compete with them:
- Rot glows stay magenta to violet (hue 290°–320°). No red or crimson Neon anywhere inside a camp or on the Floor 35 dais. The biome brief's "crimson growths" live in the sky grade and the far layer only.
- Keep camp centres and the dais floor dark and uncluttered (mud, bark, moss).
- In playtest, check that every telegraph reads at gameplay camera height: Thorn Weaver bolts, Rotwood Keeper slams and ground areas, and the Sovereign's Briar Whip, Heartrot Bloom and Rot Tendrils.

### 5.8 Performance

- **Instance, don't model.** Reuse MeshIds across terraces. Ground cover uses multi-clump meshes with `CastShadow`, `CanCollide` and `CanQuery` off, tagged `TowerDetail` so the culler hides them past about 220 studs or at low quality. Landmarks are never culled.
- Lights ≤ 24 per floor. Particle emitters ≤ 12 on Floors 31–33 and ≤ 16 on Floors 34–35, all pooled and quality-scaled.
- Targets: ≥ 45 FPS in full camp fights on Floors 31–35 and ≥ 40 FPS in the Floor 35 boss fight at the lowest Graphics quality (MicroProfiler). Report the numbers in each PR.

### 5.9 Data and saves

Layouts are not persisted. No profile schema change and no `DataManager.SyncProfile` migration.

---

## Part 6: Process, tests and docs

### Per floor (lowest first, one PR each)

1. **Ask for the floor's guide image** (skill step 2) and update that floor's section here with what you take from it and what you leave out.
2. Branch `feat/corrupted-grove-floor-<N>` from `origin/main`.
3. Layout (`AUTHORED[N]`, the Part 3 table). Re-run the Studio validation probe from the header after any change.
4. Kit (reuse, then Blender), set pieces, terrain and lighting grade.
5. Tests and docs (below). Run the suites.
6. Studio verification (`studio-verify.luau`): probe build `Builder.Build(N, ...)`. The pass bar: no new `Validate` problems; every spawn and portal grounded; every link walkable both ways; every set piece present; ≤ 24 lights. Take screenshots from the arrival, from the Apex and of each landmark, compare them with the guide image and the neighbouring floors, and show the user. Then clean up the probe terrain, `workspace.TowerRooms` and the probe folders. Never use `ChangeHistoryService:Undo` to revert.
7. `git fetch origin`, merge `origin/main` (use `git merge-file --diff3 --diff-algorithm=histogram` on conflicts, then check every junction where two floors' tables meet), commit `feat(tower): author Corrupted Grove floor N (<Name>)`, and open the PR into `main`.

Build Floor 31 only after the Thunder Highlands floors that touch shared code (for example `TowerRoomBuilder`'s natural-room list, `TowerTerrain.Surfaces` and `TowerBiomeKit` roles) have merged, or merge `origin/main` often. These files conflict a lot.

### Tests

```bash
pwsh tests/run.ps1
```

(On a Mac without `pwsh` or the Luau CLI, port the runner as described in the project memory, and ask before downloading the CLI.) Extend:
- `tower-layout-variants.spec.luau`: for each floor, a "Floor N is the hand-authored ..." test (key, name, `Size`, links and kinds, the camp count, and the floor's defining rule from its **Spec asserts** above) and a "Floor N's terrain is the walking surface" test. Add the ladder test: across 31–35, room area, room height, terraces, links, height levels and Apex Y strictly increase, every floor beats Floors 1–25 at its index, and no terrain terrace is off the 4-stud grid.
- `tower-patrols.spec.luau`: Floors 33–35's authored patrols resolve, stay on walkways and loop in under 240 s.
- `tower-portals.spec.luau`: the portal spots are grounded on every Apex, and no landmark footprint covers them.
- `tower-biome-kit.spec.luau`: every new template exists, stands on its origin and uses known roles. `FloorGrades[31..35]` exist. `HOLLIN` uses no `BlockyMaterials` and no Fungal-owned materials.
- Regression: Floors 1–30 and 36–50 unchanged.

### Docs (same PR as each floor)

- `docs/GAME_DESIGN.MD` §3.3: the floor's bullet under hand-authored floors. With Floor 31, also add a short paragraph on the Hollin, the Mother Graft, the Heartrot, the Rotpulse and the Pale Bands.
- This file: the floor's status line, plus anything that changed in the build.
- `docs/TOWER_NAVIGATION.md`: any new terrain feature or bridge style (`FORD`, `ROOT_RIDGE`, hedge bridges).
- `reference/infinite_towers_biomes.md` §7: with Floor 31, a short paragraph on the Hollin, the graft-knot and the Rotpulse.

### Studio checklist for the user (end of each floor's PR)

1. Arrive out of aggro on the Basin. Walk every route to the Apex: no invisible gaps, no blocky steps, nothing floating, nothing on a walkway.
2. **Floor 31:** ford the brook at all four fords, and confirm the banks can't be crossed anywhere else. See the Heartrot Spring across the water from the arrival.
3. **Floor 32:** confirm the Pressing Hollow is hidden from the arrival. Climb all three ways over the Graft Ridge and walk down into the hollow.
4. **Floor 33:** confirm the Briar Gate faces the Court with no way across. Take the false east path to Thornwrack, the true west path, and the long ring. Climb out of the thorn pit by both return ramps.
5. **Floor 34:** climb tree to tree on every branch bridge and the Bole Stair. Check that no trunk blocks a camp or a lane and that the cut bridge never reads as walkable.
6. **Floor 35:** walk all three roots to the dais. Summon the **Blight Sovereign** and check that Briar Whip, Heartrot Bloom and Rot Tendrils stay on the dais and read clearly. Check that the Mother Graft never covers the camera in the fight, and that Ascend (to Floor 36) and Rerun rise clear.
7. Telegraphs read against the magenta glows on every floor.
8. The Rotpulse matches across clients, builds from Floor 31 to 35, never flashes, and stops on leaving the biome.
9. Squad follow and recall (`E`) work across every ford, hedge bridge, branch bridge, root walk and stair.
10. Frame rate at the lowest Graphics quality: ≥ 45 FPS in camp fights and ≥ 40 FPS in the Sovereign fight.

## Out of scope

- Other biomes (Floors 1–30 and 36–50 stay unchanged).
- New enemies, boss moves, extra mobs for bigger rooms, hazards that deal damage (the thorn pit and the mire are cosmetic), and weather or Rotpulse effects on combat.
- Changes to rewards, relic drops, mob stats, camp respawn timing or the tower difficulty curve.

## Status

- 2026-11-21: plan written and the Part 3 layouts validated in Studio.
- 2026-11-22: **Floor 31 built** (`feat/corrupted-grove-floor-31`): layout, Hollin surface and path style, the 15-template kit (imported into the place), set pieces, `FloorGrades[31]`, specs and docs. Verified in Studio: no new `Validate` problems, 20/20 spawns grounded, 26/26 routes walkable both ways, both portals grounded, every set piece present, 21 lights. Lessons for Floors 32–35: (1) a kit mesh's clearance box is the whole template per colour role, so big foliage reaches lanes that the fallback never did, so rebuild after import; (2) pieces placed at an explicit height in water or hanging (mill, weir, lilies, lanterns) must be pinned `OnTerrain` or listed in `AirborneKinds`, or the settle pass drops them; (3) the shared `rod` helper uses `CFrame.lookAt`, which degenerates for vertical rods, so the grove module builds its own; (4) a perimeter treeline goes at the foot of the walls, never on the cliff: the first rim groves scattered trees 14-30 studs in from the wall, which put them up to 115 studs up the slope with their roots in the air. `wallFoot` now marches in from each wall to the first level, low ground, and every grove tree needs level ground under its trunk.
- 2026-11-22: **Floor 32 built** (`feat/corrupted-grove-floor-32`): layout (`AUTHORED[32]`, 620 × 640 × 220, 13 terraces, 15 links, 12 walk heights, Grafted Crown Y 48 above hidden Pressing Hollow Y 36), `Terrain.Slope` (continuous south-facing terraced orchard slope) and `Terrain.Ridges` (solid E–W Graft Ridge + raised press-house knoll at `(-108, -280)`), 15-template Blender kit (`tools/blender/generate_corrupted_f32_kit.py` → `assets-source/tower/corrupted_f32_kit/CorruptedF32Kit.fbx`, imported and filed into `ServerStorage.TowerBiomeKit` with 0.00 drift), set pieces (`TowerSetPieces/CorruptedFloor32.luau`, 20 spec-checked footprints, 16 landmarks, 422 props, 354 ground cover, 37 distinct kit templates placed), `FloorGrades[32]` (overripe rose dusk), specs and docs. Verified in Studio with live Blender meshes: no new `Validate` problems, 26/26 spawns grounded, 30/30 routes walkable both ways, both portals grounded (`dy = 0.00`), all 5 arrival sightlines to the Pressing Hollow hidden behind the ridge, all 23 set-piece groups present, 24 lights, 11 emitters.
- 2026-11-22: **Floor 33 built** (`feat/corrupted-grove-floor-33`): layout (`AUTHORED[33]`, 680 × 720 × 250, `Bottom = -6`, 15 terraces, 17 links, 14 walk heights, centred Thornheart Court Y 44, false unbanded Thornwrack east dead-end, Pale-Band west maze + outer ring, `NorthGate` shifted to `Z = -255`, 2 return ramps, `ReplacePatrols` with `GATE_WALK` / `WEST_MAZE` / `OUTER_RING`), corrupted terrain tier (`Surfaces.BLIGHT` + `Terrain.Blight` pit fissures & crags for Floors 33–35), `BridgeStyles = "HEDGE"`, 16-template Blender kit (`tools/blender/generate_corrupted_f33_kit.py` → `assets-source/tower/corrupted_f33_kit/CorruptedF33Kit.fbx`, imported and filed into `ServerStorage.TowerBiomeKit` with 0.00 drift), set pieces (`TowerSetPieces/CorruptedFloor33.luau`, 19 spec-checked footprints, 153.5-stud Thornheart, cliff & pit glowing briar veins), `FloorGrades[33]` (violet hard-shadow noon), specs and docs. Verified in Studio with live Blender meshes: 0 `Validate` problems, 2,780 MeshParts, 19/19 landmarks surviving, 0 dropped, 22 lights, 8 emitters. Next: Floor 34 (Heartrot Stronghold).
