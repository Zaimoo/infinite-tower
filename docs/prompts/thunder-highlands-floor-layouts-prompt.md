# Prompt: Thunder Highlands — a Unique Layout for Every Floor (Floors 26–30)

Copy everything below the line into a Claude Code session opened at the repo root.

> **Status (2026-11-22):** Floor 26 (Stormgrass Rise) is built on `feat/thunder-highlands-floor-26`, from the plan below and the guide image `reference/Thunder Highlands 26.jpg`. What changed in the build:
> - **From the image:** a dolmen bell-gate with three bronze bells spans the arrival trail between cairns with copper forked-bolt capstones; dry-stone field walls run across the moor; the sheepfold has a stone bothy, hurdles and sheep; the windmill is a ruined post mill with one snapped sail; the headwall carries **twin falls** into a plunge tarn; the stone ring is linked by glowing grounding chains; violet storm-glass fills the strike crater; prayer-flag lines on the Watch and the Crown. Left out: the image's sheep pens at the moor's foot (the Basin holds two camps) and its zigzag stair up the cliff (the layout's slate stair from the West Wind-Crag plays that part).
> - **The Stormgrass Crown Monolith moved onto the headwall.** The room leaves only 27 studs behind the Apex, too little for a 95-stud tor clear of the summit camp, so the split granite tor (crowned by the forked-bolt totem) stands on the headwall's turf top, as the tor stands over the falls in the image; a second, larger totem stands on the shelf behind the Crown. `APEX_ALCOVE` was dropped so the mountains wrap behind the summit.
> - **The Windmill Knoll is 112 × 88** (not 86 × 76), so the windmill fits on it outside the Elite camp and its mob slots, and **the Shepherd's Watch is 86 × 70 at (−178, −124)** (not 64 × 52), so a full-size croft stands on its north edge clear of the landing. The ladder row is unchanged (10 / 11 / 9, walk 479.4 = 1.49×).
> - **`Field.Accent` is now painted** (TowerTerrain.Build): the Infernal floors' slag-tip, pour-pit and lava-fall accents were computed but never applied before; Floor 26's scorch and headwall ribs use the same hook.
> - Lights 17, emitters 10, 323 props, 313 ground cover, 17 landmark groups (Studio Edit-mode build, kit fallbacks). The `TowerDetail` culling tier and the Tempest Squall are still to come (Part 5.6, 5.8).
>
> **Written 2026-11-20.** Five biomes are authored and merged on `main`: Verdant Ruins (1–5), Fungal Hollow (6–10), Ashen Dunes (11–15), Frozen Citadel (16–20) and Infernal Foundry (21–25, PR #352). Their prompts live in `docs/prompts/`, and the fix commits in `git log` carry the lessons. This brief builds on all five.
>
> **The escalation rule (Part 2): every floor is richer, taller, denser and more varied than the one below it.** Every Thunder Highlands floor carries more terraces, more links, more height levels, higher elevation, more distinct kit templates, more landmarks and greater skyline spectacle than any earlier floor at the same position in its biome (Floors 1–25), and each Thunder Highlands floor strictly beats the Thunder Highlands floor below it.
>
> **The compact-grand pacing rule (learned from Floor 25):** players found an `800 × 920` footprint too spread out and asked for Floor 25 to be tightened to `740 × 795` while keeping its full prop density and spectacle. Thunder Highlands continues the escalation ladder **upward and inward** — climbing dramatically in vertical height (`Apex Y 24 → 56`, room ceiling `180 → 290`, tallest skyline landmark `≥ 200 studs`), terrace/link complexity (`10/11/9` → `16/19/15`), and density — while keeping horizontal Depth compact (`550` → `795` studs) so combat stays brisk and walks stay punchy.
>
> **The layout half is already proven:** every coordinate table and patrol route in Part 3 was executed against `TowerLayout.Validate`, `Layout.PatrolRoutes`, `PatrolPath` and `TowerNavigationGraph.Route` via `D:/luau/luau.exe`. They have **zero** validation problems, every link is at or under `14.69°`, every terrain terrace sits on the 4-stud voxel grid, every patrol completes well under 240 s, every mob and Elite total matches contract, and every ladder count strictly climbs above Infernal Floors 21–25.

---

## Role

You are a two-specialist team speaking as one. Say which role you are speaking as when it matters.

**Warden** is a senior level designer and gameplay engineer for *Infinite Towers: Become a Master!*, a Roblox squad-command action RPG. Warden owns topography, sightlines, combat spaces, pacing, navigation and the `TowerLayout` connector contract. Warden thinks in walkable surfaces, link slopes, bridgehead landings, camp spacing, leash radii and the route a squad of five takes from the Sanctuary to the Apex.

**Stormwright** is a senior environment artist and world-builder. Stormwright owns the Kairnfolk ecosystem, dry-stone ringforts, suspension skybridges, copper lightning totems, cloud chasms, materials, lighting and the Tempest Squall. They build from voxel `Terrain`, native parts and headless-Blender kit meshes, the way the earlier biomes were built. Every prop has a reason to exist in the highlands and reads clearly from the gameplay camera. Stormwright treats every floor as a vertical and visual step up from the one below it.

Neither of you breaks the runtime contracts described below.

## Before you start

1. **`git pull` on `main` first** (ensure Infernal Foundry PR #352 is merged or branch from it if building sequentially). Branch `feat/thunder-highlands-floor-layouts` from the updated base. Use conventional commits.
2. Follow `CLAUDE.md` and `AGENTS.md`. Use the `roblox-world-building`, `roblox-luau`, `roblox-npc-ai` and `roblox-performance` skills.
3. Read `docs/GAME_DESIGN.MD` §3.3 (tower rooms, biomes, authored floors 1–25, escalation ladder) and §3.6 (lighting), `docs/TOWER_NAVIGATION.md`, `reference/infinite_towers_biomes.md` §6 (Thunder Highlands), `docs/tower-mob-remodel-plan.md` §6 (enemy visuals and motifs) and `docs/mob-reanimation-plan.md` (Avian/Quadruped/Storm Roc rigs).
4. Read all five earlier floor prompts, latest first: Infernal, Frozen, Ashen, Fungal, Verdant. Read their status notes and engineering lessons. Then run `git log --oneline -- src/ServerScriptService/Core/Tower*.luau src/ReplicatedStorage/Shared/Config/TowerLayout.luau` and inspect every `fix(...)` commit — especially the Floors 21–25 fixes on blocky terrain materials, exposed bridgehead aprons, fake bridges, and flat lava glow planes.
5. Read the authored-floor code end to end:
   - `TowerLayout.luau`: `AUTHORED[1..25]`, `Size`, `build`, `Validate`, `PatrolRoutes`, `Lanes`, `PortalSpots`.
   - `TowerRoomBuilder.luau`: `MASONRY_STYLES`, decks, `Suspended.Links`, `landingOutsideTerrace` bridgehead aprons, `StonePiers`, `GirderSpans`, stairs, curbs, open-sky vs. vaulted ceilings.
   - `TowerTerrain.luau`: `Palettes`, `Surfaces`, `MaterialColors`, `BlockyMaterials`, every `feat.Kind`, and `Liquid` handling.
   - `TowerBiomeAssets.luau` and `TowerSetPieces/` (`InfernalFoundry.luau`, `InfernalFloor24.luau`, `InfernalFloor25.luau`): how footprints are registered and spec-checked against lanes and camps.
   - `TowerBiomeKit.luau` and `TowerKitProps.luau`: `ExtraTemplates`, `Biomes.thunder_highlands`, `Ecology.thunder_highlands`, `Has`, `Ready`.
   - `HubLighting.luau`: `BiomeGrades[6]` and `FloorGrades[1..25]`.
   - `EffectCullingRules.luau` and `HubEffectCulling.client.luau`.
   - `tests/studio-tower-biome-kit-import.luau` and `tests/studio-tower-prop-audit.luau`.

## The goal

The five Thunder Highlands floors (26–30) still use the seeded generic layout and the generic Thunder Highlands props. Give each one its own hand-authored topography, built around one highland ecosystem, so that each floor has a different shape, route and combat rhythm. Each must be **a new high-water mark for verticality, detail and spectacle in the tower so far, and outdone by the floor above it**, while staying compact enough for crisp, engaging squad traversal. The other biomes stay exactly as they are in this change.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, ruin, cable and creature traces back to this ecosystem. If a prop doesn't fit, cut it. More assets means more *reasons*, not more filler.

### The Kairnfolk

The **Kairnfolk** were highland storm-shepherds, cliff-masons and copper-smiths who inhabited the wind-scoured peaks directly above the mountain's roots. (One line of flavour continuity: while the Sootwrights hammered the volcanic depths of the Infernal Foundry below, the Kairnfolk lived on the storm-swept ridge above, trading mountain peat and storm-glass fulgurite for hammered copper wire — until the Eternal Squall drove them from the crags.)

Their architecture is dry-stone slate masonry and weathered highland granite bound with hammered copper: stacked boundary cairns, circular broch ringforts, peat-turf roofs, braided copper grounding cables, standing rune-stones, rope-and-copper suspension skybridges, wind-harp towers and tall stone-and-copper lightning totems. Their sigil is the **forked-bolt totem**: a jagged lightning glyph crossed by three copper grounding rings (matching the Thunder Highlands enemy motif in `docs/tower-mob-remodel-plan.md` §6). It appears on cairn capstones, skybridge anchor pylons, wind-harp frames, redoubt shields and the Crag Channelers' staffs and cloaks.

### The Storm Roc and the Tempest Squall

Atop Floor 30 nests the **Storm Roc**, a colossal thunderhead-winged bird whose feathered thunderheart *"flashes with every beat"* (`RelicConfig` → `THUNDER_HEART`). Since the Roc claimed the summit caldera, the mountain's weather has locked into an unending electrical storm radiating outward and downward across all five floors:
- the sky-canyons are its updrafts
- the Kairnfolk's old copper lightning totems and grounding cables are its circuit
- the storm clouds pooling in the chasms are its breath

**The Tempest Squall is the biome's through-line** (its Heartroot, Veinweb, Ember Vein, Stillcold or Heartbeat). On a shared server-time cycle (`workspace:GetServerTimeNow()`), a rolling electrical squall sweeps across the peaks:
- cloth prayer pennants and wind-socks whip harder on the gust front
- copper wind-harp strings shimmer and chime spatially
- braided copper cables, lightning-rod spires and fulgurite glass seams flare electric violet-white
- distant sheet-lightning brightens the high thunderheads (never flashing the player's viewport blinding white) followed by a spatial rolling thunderclap

The squall is faint and gusty on Floor 26 and builds to a roaring maelstrom encircling the calm eye of Floor 30. It is **client-side and purely cosmetic** (§5.6).

| Floor | How strong the Tempest Squall is | What the player sees |
| --- | --- | --- |
| 26 | Brisk: the first stormgrass slopes | Wind-tacking moorland terraces, shepherd cairns, storm-bent highland pines, copper rod totems; clouds breaking overhead for pale storm-dawn light |
| 27 | Rising: the ringfort ridge | A concentric dry-stone broch outpost; twin Wind-Harp towers singing in the crosswind; beacon braziers and copper grounding lines humming across the ramparts |
| 28 | Fierce: the cloud-gorge needles | Freestanding rock pinnacles piercing a swirling cloud abyss; multi-level rope-and-copper suspension skybridges swaying visually; fulgurite glass needles glowing violet |
| 29 | Howling: the fault citadel | A two-tier highland redoubt split by a sheer cliff fault; a soaring Thunder-Viaduct leaping the chasm; copper capacitor spires crackling beside storm-bell gates |
| 30 | Maelstrom: the Eye of the Storm | A colossal Twin-Wing Caldera Amphitheatre ringing an open swirling Cloud-Eye; a cantilevered Eye Pulpit over the vortex; the 200-stud Shattered Sky-Spire & Lightning Crown towering behind Roc's Eyrie |

### Living layers (use all of them on every floor, more of each the higher you go)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Wind & Cloud** | Swirling cloud-sea chasms (Floors 28–30), drifting mist wisps, wind-socks, prayer pennants, slant rain streaks | Cosmetic: never a hazard, never flat semi-transparent boxes (§5.3, §5.5) |
| **Copper & Glyph** | Forked-bolt lightning totems, braided grounding cables, wind-harps, capacitor coils, storm-bells, copper-banded skybridge pylons | The signature skyline silhouette: oxidised verdigris + bright hammered copper + electric violet-white Neon accents |
| **Highland Stone** | Dry-stone slate walls, stacked trail cairns, standing rune-stones, broch drums, fractured basalt-slate sea stacks | Layered, wind-eroded, lichen-speckled; never smooth modern concrete |
| **Stormgrass & Pine** | Wind-bent highland pines (`PineTree` + sculpted bent pines), tussock stormgrass clumps, heather tufts, mossy turf ledges | Lean every wind-bent pine and grass cluster in a consistent wind vector (from the NW) so the whole mountain feels swept by one gale |
| **Fulgurite & Static** | Lightning-fused glass spikes (`FulguriteCluster` + new shards), scorched strike craters, glowing quartz-violet crystal veins | Echoes the Fulgurite Geode and Lightning Nexus Core relic skins |
| **Shepherd & Watch** | Ram pens, stone crofts, weathered wood palisades, cable winches, signal braziers, weathered wool-bales, iron-bound chests, giant shed Roc feathers (Floors 28–30) | Grounds every terrace as a lived-in highland pasture, outpost, skybridge station or redoubt |

### Food web (how the enemies fit, `MobCatalog` → `thunder_highlands`)

- **Storm Talon** (`AVIAN`, Regular — slate feathers, copper-tipped primaries, crackling crest plumes; `CLAW`): cliff-nesting raptors riding the ridge thermals. Put stick-and-bone perches, roost posts and torn wind-pennants near their camps.
- **Crag Channeler** (`CASTER_BIPED`, Regular — horned shaman in rune cloak with copper lightning-rod staff; `PROJECTILE`): descendants of Kairnfolk storm-callers still tending the copper circuits. Put standing rune-stones, copper grounding stakes and storm-urn tripods at their camps.
- **Squall Herald** (`AVIAN`, Support `ROUSE` — crested herald bird with fan tail and speaking-horn beak whose cry rings glow): calls the flock from elevated perches. Put copper wind-chime poles and horn-shaped cairns where they stand.
- **Thunder Ram / Alpha** (`QUADRUPED`, Elite/Alpha — shaggy ram with spiral copper-banded horns that arc lightning; Alpha adds gold-capped horns and storm-glyph saddle; `RAM` / `GROUND_AREA`): once herded by the Kairnfolk to discharge static from the pastures, now feral and huge. Put dry-stone ram pens, horn-rubbed standing stones and battered timber hurdles where Elites lead.
- **Storm Roc** (`GIANT_AVIAN`, Boss, Floor 30 — `24 × 16 × 17`, widest boss rig in the tower, thunderhead-grey wings edged in lightning and crest of copper spines): nests in the colossal Eyrie on `Apex`. Its moves (`docs/GAME_DESIGN.MD` §6) are **Gale Slash** (`ARC`), **Thunderclap** (`SELF_DISC`) and **Lightning Strike** (`TARGET_DISC`).

The relic skins (`RelicConfig` → `THUNDER`) are the **Fulgurite Geode**, the **Storm-Charged Urn**, the **Lightning Nexus Core** and the **Heart of the Storm Roc**. Echo them in shrines, strike craters, copper-caged lightning coils and the Eyrie nest.

### Ambient life (client-only, purely cosmetic)

Slant highland drizzle / storm rain, horizontal cloud-wisps skimming cliff edges, fluttering Kairnfolk prayer pennants, copper wind-harp chime pulses, crawling blue-violet static sparks on lightning totems, distant sheet-lightning flashes in the upper cloud bank, swirling cloud-vortex rings in the chasms (Floors 28–30), and soaring silhouettes of distant storm birds high in the open sky (never inside gameplay height). The higher the floor, the more systems run (see the ladder). Everything is client-side, pooled, culled by distance, scaled by the Graphics quality setting (`SettingsGraphicsEngine`), and off/minimal at the lowest quality. Nothing replicates from the server.

---

## Part 2: The escalation ladder — every floor richer, taller, grander

Floors 26–30 continue the standing escalation rule above Infernal Foundry (Floors 21–25), while honouring the **compact-grand pacing rule** (vertical grandeur and rich topology over bloated empty flat distance).

### 2.1 Layout and scale (already proven by the validator for the Part 3 coordinates)

| Floor | Room (W × D × H) | Area (vs. Infernal index) | Terraces | Links | Height levels | Apex top | Max slope | Shortest walk (vs. canonical) | Infernal best at this index (terraces / links / levels / Apex) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 26 | 510 × 550 × 180 | 280,500 (> 252,000) | 10 | 11 | 9 | Y 24 | 14.69° | 479.4 (1.49×) | 9 / 9 / 8 / Y 20 (Floor 21) |
| 27 | 600 × 605 × 205 | 363,000 (> 338,250) | 12 | 14 | 11 | Y 32 | 14.69° | 589.5 (1.62×*) | 11 / 12 / 10 / Y 24 (Floor 22) |
| 28 | 655 × 700 × 235 | 458,500 (> 437,500) | 13 | 16 | 12 | Y 40 | 14.63° | 596.1 (1.47×) | 12 / 12 / 11 / Y 28 (Floor 23) |
| 29 | 735 × 790 × 260 | 580,650 (> 579,150) | 15 | 17 | 13 | Y 48 | 11.59° | 672.2 (1.48×) | 14 / 14 / 12 / Y 36 (Floor 24) |
| 30 | 795 × 795 × 290 | 632,025 (> 588,300) | 16 | 19 | 15 | Y 56 | 14.48° | 872.0 (1.72×*) | 15 / 16 / 13 / Y 44 (Floor 25) |

- *Terraces* counts every platform, including `Sanctuary` and `ExtraPlatforms` (`ladderCounts`).
- *Height levels* counts distinct walk heights other than `Sanctuary`'s.
- Every floor strictly beats both the floor below it and its Infernal index counterpart in **room area, room height, terraces, links, height levels, and Apex elevation**, while keeping Depth capped at `795` studs (matching tightened Floor 25's brisk feel, and saving 154–234 studs of walk compared to Floor 24/25!).
- \*On Floor 27 (concentric ringfort with no `Basin→Crossing`) and Floor 30 (Twin-Wing Caldera Amphitheatre wrapping an open Cloud-Eye abyss), the walk ratio reflects the deliberate outer-arc signature shape while staying markedly brisker than Infernal Floors 24–25 (`906.4 / 1.99×` and `1,026.1 / 2.03×`). Do not add a center bypass that breaks Floor 27's ringfort or fills Floor 30's open Cloud Eye.

### 2.2 Assets and variety (targets your build must meet; measured by the census in §6)

| Floor | New kit templates | Distinct templates placed | Landmark set pieces | Placed props (excl. ground cover) | Ground cover and small clutter | Tallest landmark | Ambient systems |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 26 | ≥ 8 | ≥ 20 | ≥ 12 | ≥ 300 | ≥ 210 | ≥ 95 studs | ≥ 5 |
| 27 | ≥ 9 | ≥ 23 | ≥ 14 | ≥ 360 | ≥ 250 | ≥ 115 | ≥ 6 |
| 28 | ≥ 10 | ≥ 26 | ≥ 16 | ≥ 430 | ≥ 300 | ≥ 135 | ≥ 6 |
| 29 | ≥ 11 | ≥ 29 | ≥ 18 | ≥ 500 | ≥ 350 | ≥ 160 | ≥ 7 |
| 30 | ≥ 12 | ≥ 32 | ≥ 20, plus one colossal centrepiece | ≥ 580 | ≥ 400 | ≥ 200 (Shattered Sky-Spire) | ≥ 8 |

**Beat every earlier floor at the same index:** once `tests/studio-tower-asset-census.luau` runs across Floors 1–25, verify every Thunder Highlands floor strictly exceeds the highest earlier floor at its index (Floors 1–25) on prop count, template variety, landmark count and tallest landmark. If an Infernal floor exceeded the table above, beat it by at least +10%.

### 2.3 Variety, grandeur and compact-grand pacing rules (judged in review)

- **No filler.** No single template makes up more than 12% of a floor's placed props (ground cover excluded).
- **Every terrace is a vignette:** at least 4 distinct prop kinds that tell what the terrace was for (shepherd fold, windmill knoll, wind-harp post, cable anchor pylon, ram yard, pinion roost).
- **Every link is dressed at both ends:** cairns, copper anchor bollards, warning totems, lantern posts or timber gateposts on the terrace, off the lane.
- **Three skyline layers on every floor (all 5 Thunder Highlands floors have open storm skies!):**
  - *near*: props, cairns, copper grounding posts and wind-bent foliage on the terraces
  - *mid*: landmarks rising from ridges, ringfort walls, sea stacks or the cloud abyss
  - *far*: distant jagged mountain peaks, towering thunderhead cloud walls and copper ridge-beacons beyond the room walls
- **Every floor introduces at least one traversal feature and one landmark type that no earlier floor in the tower has.** Part 3 names them.
- **Vertical grandeur, compact travel:** spend scale on cliff drop, multi-tier elevation (`Y 0 → 56`), dramatic skybridges, cloud abyss depth (`Bottom = -6` and `-8`) and soaring landmarks (`≥ 200 studs` on Floor 30), never on empty flat prairies.
- **Grounded and readable:** density never hides camps, telegraphs, loot or the route. Paths and skybridges stay unmistakable from the gameplay camera.

---

## Part 3: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north (the Apex side). Y is the walkable top surface.

**Terrain terraces sit on multiples of 4 studs:** smooth terrain only renders flush on those planes. Terraces at other heights in the tables below (`Y 6, 10, 14, 18, 22, 30, 34, 46`) are **built decks** (`Decks[id] = true`), which can sit at any height. Any link spanning a chasm (`Bottom < 0`) OR connecting an off-4-stud deck MUST be in `Suspended.Links` so `TowerRoomBuilder` builds a solid visible bridge/skybridge with flush bridgehead aprons (§5.5). Tune coordinates only if needed, keep the shape and ladder, and re-run `TowerLayout.Validate` after every change.

**Already taken (25 shapes — don't repeat them):**
- **Verdant (1–5):** 1 spine with glades; 2 broken diagonal aqueduct; 3 E–W gorge with three bridges; 4 walled ring with wall-walks; 5 spiral around a cenote.
- **Fungal (6–10):** 6 horseshoe around a pool; 7 switchback up a gallery wall; 8 chasm with round cap deck & hung bridges; 9 bastion ring through the Crossing ("H"); 10 asymmetric radial spiderweb.
- **Ashen (11–15):** 11 fork around a dune; 12 single switchback; 13 N–S ravine with two ledges & arch; 14 chokepoint gate & split fortress; 15 route over a fallen giant.
- **Frozen (16–20):** 16 lakeshore road vs. floe chain; 17 street lattice; 18 inverted ravine (central spine); 19 two routes in two climates; 20 cathedral nave.
- **Infernal (21–25):** 21 hub-and-spokes rail turntable; 22 gantry crane Π with stem; 23 lava-lake fishbone causeway; 24 three-strip sluice-tower weave with blocked center Pour (west-only entry); 25 hourglass pinch with side chambers.

**Fixed on every floor:**
- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, `128 × 56`, and `Basin` stays centred at `X = 0`.
- `Apex` holds the Floor Alpha (Floors 26–29) or Biome Boss (Floor 30) summon and the Ascend/Rerun boss portals.
- Arrivals land out of aggro.
- Mob totals and Elite counts are **16 / 22 / 25 / 35 / 35** and **1 / 2 / 3 / 4 / 4**. Never add mobs for bigger rooms. From Floor 28, at least one Elite camp stands above the entry level.
- `ExtraPlatforms` hold no camps: they are landmark, ambush-sightline and vignette space.
- From Floor 28, each floor replaces or extends patrols with authored highland routes alongside `BASIN_LOOP`.

---

### Floor 26: Stormgrass Rise (`INTRODUCTION`)

*510 × 550 × 180, `Bottom = 0` (no chasm). Open storm-breaking highland dawn.*

**Story beat:** the lower grazing slopes of the Kairnfolk highlands, where stone boundary walls and copper lightning-rods first climb out of the mist toward the thunderheads.

**Shape: wind-tacking braided hillside contours around a sheer central turf-and-slate headwall.** `Basin` (Shepherd's Moor, Y 0) climbs into three staggered lower contours (`WestGallery` Windmill Knoll Y 4, `Crossing` Cairn Fold Y 8, `EastGallery` Standing Stones Y 6). Ahead of `Crossing` rises a sheer unclimbed storm-scarred headwall — **there is no direct `Crossing → Apex` link**, so every ascent tacks diagonally left or right across the wind through `WestCrag` (Y 16) or `EastCrag` (Y 18), while `Crossing` cross-braids into `WestCrag` and two outer cairn spurs (`ShepherdWatch` Y 10, `FulguriteSpur` Y 12) overlook the moor. **New to the tower:** wind-tacking hillside contour ascents around a sheer central headwall, plus standing stone rings and copper lightning-rod totems.

```
                        N (−Z)
            ┌───────────────────────────────────────┐
            │        [ STORMGRASS CROWN ] Y24       │
            │           // (stairs)     \           │
            │  [SHEPHERD]  [W. WIND-CRAG] [E. CRAG] [FULGURITE]
            │  [ WATCH  ]     Y16           Y18     [  SPUR   ]
            │    Y10        /   \            |         Y12
            │      \       /     \           |         /
            │ [WINDMILL KNOLL]  [CAIRN FOLD]  [STANDING STONES]
            │       Y4              Y8               Y6
            │         \              |              /
            │        ~~~ SHEPHERD'S MOOR  Y0 ~~~    │
            │                        |              │
            │                [ SANCTUARY ] Y8       │
            └───────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Shepherd's Moor | 0, 0, 132 | 420 × 92 | terrain |
| `WestGallery` | Windmill Knoll | −150, 4, 10 | 86 × 76 | terrain |
| `Crossing` | Cairn Fold | −6, 8, 16 | 78 × 62 | terrain |
| `EastGallery` | Standing Stones | 152, 6, 2 | 86 × 76 | deck (`KAIRN_STONE`) |
| `ShepherdWatch` (extra) | Shepherd's Watch | −182, 10, −120 | 64 × 52 | deck (`KAIRN_STONE`) |
| `FulguriteSpur` (extra) | Fulgurite Outcrop | 180, 12, −124 | 64 × 52 | terrain |
| `WestCrag` (extra) | West Wind-Crag | −76, 16, −96 | 72 × 60 | terrain |
| `EastCrag` (extra) | East Wind-Crag | 80, 18, −102 | 72 × 60 | deck (`KAIRN_STONE`) |
| `Apex` | Stormgrass Crown | 0, 24, −206 | 120 × 84 | terrain |

**Paths (11 links, max slope 14.69°, shortest walk 479.4 = 1.49× canonical):**
`Sanctuary→Basin`, `Basin→WestGallery`, `Basin→Crossing`, `Basin→EastGallery`, `WestGallery→ShepherdWatch`, `EastGallery→FulguriteSpur`, `WestGallery→WestCrag`, `Crossing→WestCrag`, `EastGallery→EastCrag`, `WestCrag→Apex` (`STAIRS`: slate steps with copper nosing), `EastCrag→Apex`.
*Suspended/Deck bridges:* list every link touching an off-grid deck (`Basin_EastGallery`, `WestGallery_ShepherdWatch`, `EastGallery_FulguriteSpur`, `EastGallery_EastCrag`, `EastCrag_Apex`) in `Suspended.Links` (built as dry-stone causeway bridges with flush bridgehead aprons so they meet off-grid decks cleanly).

**Camps (16, 1 Elite):** `BASIN_WEST` 4, `BASIN_EAST` 4, `WEST_GALLERY` 4 (Elite — Thunder Ram), `EAST_GALLERY` 4. **Patrol:** `BASIN_LOOP` (90.1 s).

**Landmarks (≥ 12):**
1. The **Stormgrass Crown Monolith** behind `Apex` (≥ 95 studs): a split granite tor crowned by a giant Kairnfolk copper forked-bolt lightning totem.
2. The **Sheer Turf-and-Slate Headwall** rising directly north of `Crossing` between `WestCrag` and `EastCrag`, streaked with wet slate ribs and a cascading highland rill.
3. The **Highland Windmill** on `WestGallery` (Windmill Knoll) — weathered timber tower with tattered sailcloth blades turning slowly in the squall.
4. The **Standing Stone Circle** ringing `EastGallery`, linked by braided copper grounding wires humming between the monoliths.
5. The **Dry-Stone Sheepfold & Ram Pen** edging `Crossing` (Cairn Fold), with battered timber hurdles and horn-rubbed boundary posts.
6. The **Shepherd's Croft & Stone Watch-Cairn** on `ShepherdWatch` with a peat-turf roof and fluttering wind-sock.
7. The **Fulgurite Lightning-Strike Crater** on `FulguriteSpur` — fused violet-blue glass spikes erupting from a scorched slate shelf.
8. Twin **Trail Cairns with Forked-Bolt Capstones** framing the `Basin` arrival trail and both upper wind-crags.
9. Wind-bent **Highland Pine Groves** leaning uniformly SE across the outer slopes.
10. A **Storm-Charged Urn Shrine** tucked beside `WestCrag` (echoing the Tier 2 relic skin).
11. **Copper-Wire Boundary Fences & Storm-Bell Gateposts** along the lower moor.
12. Far: jagged highland peaks and distant ridge-top lightning totems silhouetted against breaking storm clouds.

**Ecosystem weight:** lush wet stormgrass, dry-stone slate and first copper totems; faintest Tempest Squall.

---

### Floor 27: Thunderhead Outpost (`EXPANDED_ENCOUNTER`)

*600 × 605 × 205, `Bottom = 0` (no chasm). Gathering thunderhead noon.*

**Story beat:** a fortified Kairnfolk hilltop ringfort and signal station where shepherds once took refuge and relayed storm warnings down the mountain via copper wind-harps and beacon fires.

**Shape: concentric double-arc highland ringfort (broch).** `Basin` (Stockade Apron, Y 0) has **no direct path to `Crossing`** — it enters only through the twin outer palisade gate-bastions (`WestOuter` Y 6, `EastOuter` Y 8), climbing into the flanking yards (`WestGallery` Y 12, `EastGallery` Y 14). From the flanking yards, routes either cut inward to the elevated central **Signal Broch** (`Crossing`, Y 16), push outward onto two projecting **Wind-Harp Towers** (`WestHarp` Y 18, `EastHarp` Y 24) that catch the ridge crosswind, or sweep around the inner rampart arcs (`WestInner` Y 20, `EastInner` Y 22). Three converging approaches (`WestInner`, `Crossing` STAIRS, `EastInner`) ascend to **Thunderhead Lodge** (`Apex`, Y 32). **New to the tower:** a concentric circular dry-stone broch ringfort with twin projecting Wind-Harp acoustic towers.

```
                        N (−Z)
            ┌───────────────────────────────────────────┐
            │        [ THUNDERHEAD LODGE ] Y32          │
            │           /       ‖       \               │
            │  [W. HARP] [W. INNER] (st) [E. INNER] [E. HARP]
            │    Y18       Y20      ‖       Y22       Y24
            │      \      /         ‖         \      /  │
            │  [W. RAM YARD]──[SIGNAL BROCH]──[E. FORGE YARD]
            │      Y12             Y16             Y14  │
            │       |                               |   │
            │  [W. PALISADE]                 [E. PALISADE]
            │      Y6                               Y8  │
            │        \                             /    │
            │        ~~~ STOCKADE APRON  Y0 ~~~         │
            │                       |                   │
            │                [ SANCTUARY ] Y8           │
            └───────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Stockade Apron | 0, 0, 166 | 490 × 94 | terrain |
| `WestOuter` (extra) | West Palisade | −96, 6, 68 | 70 × 52 | deck (`KAIRN_STONE`) |
| `EastOuter` (extra) | East Palisade | 96, 8, 68 | 70 × 52 | terrain |
| `WestGallery` | West Ram Yard | −142, 12, −24 | 86 × 78 | terrain |
| `Crossing` | Signal Broch | 0, 16, −30 | 84 × 72 | terrain |
| `EastGallery` | East Forge Yard | 142, 14, −24 | 86 × 78 | deck (`KAIRN_STONE`) |
| `WestHarp` (extra) | West Wind-Harp | −224, 18, −124 | 58 × 52 | deck (`KAIRN_STONE`) |
| `EastHarp` (extra) | East Wind-Harp | 224, 24, −124 | 58 × 52 | terrain |
| `WestInner` (extra) | West Inner Rampart | −104, 20, −132 | 68 × 54 | terrain |
| `EastInner` (extra) | East Inner Rampart | 104, 22, −132 | 68 × 54 | deck (`KAIRN_STONE`) |
| `Apex` | Thunderhead Lodge | 0, 32, −232 | 126 × 88 | terrain |

**Paths (14 links, max slope 14.69°, shortest walk 589.5 = 1.62× canonical):**
`Sanctuary→Basin`, `Basin→WestOuter`, `Basin→EastOuter`, `WestOuter→WestGallery`, `EastOuter→EastGallery`, `WestGallery→Crossing`, `EastGallery→Crossing`, `WestGallery→WestHarp`, `EastGallery→EastHarp`, `WestGallery→WestInner`, `EastGallery→EastInner`, `WestInner→Apex`, `Crossing→Apex` (`STAIRS`: the Broch Ascent), `EastInner→Apex`.
*Suspended/Deck bridges:* list every link touching an off-grid deck (`Basin_WestOuter`, `WestOuter_WestGallery`, `EastOuter_EastGallery`, `EastGallery_Crossing`, `WestGallery_WestHarp`, `EastGallery_EastHarp`, `EastGallery_EastInner`, `EastInner_Apex`) in `Suspended.Links`.

**Camps (22, 2 Elites):** `BASIN_WEST` 4, `BASIN_EAST` 4, `CENTRAL_CROSSING` 4, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite). **Patrol:** `BASIN_LOOP` (105.9 s).

**Landmarks (≥ 14):**
1. The **Thunderhead Signal Tower & Lodge Hall** behind `Apex` (≥ 115 studs): stacked dry-stone broch keep topped with a copper cage lantern and three forked-bolt lightning spires.
2. The **Curved Outer Palisade Ringwall** sweeping between `WestOuter`, `WestGallery`, `EastGallery` and `EastOuter`, built of dry-stone base courses and copper-bound timber stakes.
3. The **Signal Broch Drum** framing `Crossing` — low circular ring-wall with an open central beacon brazier and braided copper grounding cables radiating outward to both Wind-Harp towers (≥ 22 studs overhead).
4. **West Wind-Harp Tower** on `WestHarp` — tall curved timber-and-copper acoustic frame strung with glowing resonant cables.
5. **East Wind-Harp Tower** on `EastHarp` — taller asymmetric twin with wind-vanes spinning on the squall.
6. **Copper-Smith's Open-Air Forge & Wire Reel** on `EastGallery` (where the Kairnfolk braided grounding cables).
7. **Thunder Ram Pens & Timber Chutes** on `WestGallery`.
8. **Inner Rampart Gate-Arches** crowning `WestInner` and `EastInner`.
9. **Signal Beacon Braziers** on stone plinths lighting the ringfort curve.
10. **Watch-Bell Gallows** flanking `Basin`'s twin palisade entries.
11. **Weathered Kairnfolk Longhouse Ruins** tucked against the outer hillside slopes.
12. **Storm-Charged Capacitor Casks & Copper Coil Racks** around the Broch perimeter.
13. **Wind-Bent Pine Shelterbelts** hugging the leeward side of the hillfort.
14. Far: a ring of storm-darkened highland ridges with blinking blue-violet signal towers along the horizon.

**Ecosystem weight:** fortified highland masonry, humming copper circuits, rising squall winds and acoustic harp chimes.

---

### Floor 28: Skybridge Cliffs (`TERRAIN_VARIATION`)

*655 × 700 × 235, `Bottom = -6` (deep cloud-filled alpine gorge). Cloud-sea squall afternoon.*

**Story beat:** the mountain fractures into freestanding slate sea-stacks and crag needles above a churning sea of storm clouds, spanned only by Kairnfolk rope-and-copper suspension skybridges.

**Shape: staggered sky-pinnacle archipelago over a deep cloud abyss.** Every terrace past `Basin` (Cloudbreak Ledge, Y 0) is an isolated rock needle or cliff stack piercing the cloud floor (`Bottom = -6`) at staggered X, Z and Y coordinates — **no two adjacent pinnacles share an axis**. Three distinct skybridge chains cross the abyss: a sweeping western pinnacle chain (`WestGallery` Y 8 → `NeedleWest` Y 16 → `SkyAnchorW` Y 28 → `Apex` Y 40), a high central sky-spire chord (`Basin` → `Crossing` Y 20 → `CloudSpire` Y 36 → `Apex` STAIRS), and a steeper eastern spire chain (`EastGallery` Y 12 → `NeedleEast` Y 24 → `SkyAnchorE` Y 30 → `Apex`), cross-linked at mid-gorge (`WestGallery→Crossing` and `EastGallery→Crossing`) with two precarious dead-end roosts (`GaleRoost` Y 14 and `FulminiteNeedle` Y 34) jutting over the clouds. **New to the tower:** a cloud-abyss pinnacle archipelago of freestanding rock needles joined by swaying-look rope-and-copper suspension skybridges (`SKYBRIDGE` masonry).

```
                        N (−Z)
            ┌──────────────────────────────────────────────┐
            │           [ SKYBRIDGE CROWN ] Y40            │
            │            /      ‖ (st)      \              │
            │  [W. CABLE PYLON] [THUNDERSTEP] [E. CABLE PYLON]
            │        Y28             Y36            Y30    │
            │         |               |              |     │
            │  [GALE] [W. PINION]     |       [E. PINION] [FULGURITE]
            │  [ROOST]   Y16          |          Y24      [ NEEDLE  ]
            │   Y14    /      \       |         /   \        Y34
            │     \   /    [CENTRAL SKY-SPIRE] /     \             │
            │ [W. SEA-STACK]─────  Y20  ──────[E. SEA-STACK]       │
            │       Y8              |               Y12            │
            │         \             |              /               │
            │        ~~~ CLOUDBREAK LEDGE  Y0 ~~~                  │
            │                       |                              │
            │                [ SANCTUARY ] Y8                      │
            └──────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Cloudbreak Ledge | 0, 0, 200 | 545 × 104 | terrain |
| `WestGallery` | West Sea-Stack | −178, 8, 40 | 88 × 78 | terrain |
| `EastGallery` | East Sea-Stack | 186, 12, 32 | 88 × 78 | terrain |
| `GaleRoost` (extra) | Gale Roost | −256, 14, −60 | 60 × 54 | deck (`SKYBRIDGE`) |
| `NeedleWest` (extra) | West Pinion Crag | −148, 16, −76 | 70 × 60 | terrain |
| `Crossing` | Central Sky-Spire | −6, 20, −28 | 86 × 72 | terrain |
| `NeedleEast` (extra) | East Pinion Crag | 164, 24, −84 | 70 × 60 | terrain |
| `SkyAnchorW` (extra) | West Cable Pylon | −176, 28, −194 | 72 × 62 | terrain |
| `SkyAnchorE` (extra) | East Cable Pylon | 172, 30, −198 | 72 × 62 | deck (`SKYBRIDGE`) |
| `FulminiteNeedle` (extra) | Fulgurite Needle | 258, 34, −102 | 56 × 50 | deck (`SKYBRIDGE`) |
| `CloudSpire` (extra) | Thunderstep Crag | 22, 36, −164 | 68 × 56 | terrain |
| `Apex` | Skybridge Crown | −12, 40, −270 | 132 × 90 | terrain |

**Paths (16 links, max slope 14.63°, shortest walk 596.1 = 1.47× canonical):**
`Sanctuary→Basin`, `Basin→WestGallery`, `Basin→Crossing`, `Basin→EastGallery`, `WestGallery→GaleRoost`, `WestGallery→NeedleWest`, `WestGallery→Crossing`, `EastGallery→Crossing`, `EastGallery→NeedleEast`, `NeedleWest→SkyAnchorW`, `Crossing→CloudSpire`, `NeedleEast→FulminiteNeedle`, `NeedleEast→SkyAnchorE`, `SkyAnchorW→Apex`, `CloudSpire→Apex` (`STAIRS`: stone cliff-cut steps), `SkyAnchorE→Apex`.
*Suspended skybridges:* **every link past `Basin` except `CloudSpire_Apex`** (all 14 chasm spans!) goes in `Suspended.Links` with `Masonry = "SKYBRIDGE"`, so each span hangs cleanly over the cloud abyss with twin timber-and-copper anchor pylons, catenary main cables, vertical rope-and-copper hangers, and solid visible bridgehead aprons joining every sea-stack cleanly. (The two chasm return ramps climb out of the cloud floor back onto `Basin`.)

**Camps (25, 3 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite — elevated at Y 20!), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (`Always`, 115.6 s), `WEST_SKYLINE` = `{WestGallery, NeedleWest, SkyAnchorW}` (97.2 s), `EAST_SKYLINE` = `{EastGallery, NeedleEast, SkyAnchorE}` (93.7 s), `CLOUD_SPAN` = `{WestGallery, Crossing, CloudSpire}` (130.5 s).

**Landmarks (≥ 16):**
1. The **Twin Crown Anchor Pylons & Great Forked-Bolt Arch** behind `Apex` (≥ 135 studs): colossal stone-and-copper suspension towers anchoring heavy lightning-catching cables up into the storm deck.
2. **Sculpted Cloud-Abyss Deck** spanning `Bottom = -6` — layered billowing cloud-bank meshes, slow drifting mist planes and soft violet-white invisible-anchor underglow (zero flat coloured boxes!).
3. **Shattered Sea-Stack Pillars** rising from the clouds beside the archipelago, some snapped mid-height with snapped suspension cables dangling down into the mist.
4. **Heavy Cable-Winch Capstans** bolted to `SkyAnchorW` and `SkyAnchorE` that tension the skybridges.
5. **Storm Talon Nest Platforms & Giant Shed Feathers** perched on `GaleRoost` (the first hint of the Storm Roc above).
6. **Giant Fulgurite Crystal Spire** bursting out of `FulminiteNeedle`, pulsing electric violet on the squall.
7. **Central Sky-Spire Beacon Totem** crowning the edge of `Crossing` — a copper tripod mast with spinning anemometer cups.
8. **Broken Skybridge Stub** projecting dramatically off the north side of `EastGallery` into empty mist (clearly terminated by a jagged snapped plank edge + barrier cairns so it NEVER reads as a walkable bridge — §5.5!).
9. **Cliff-Anchored Copper Grounding Chains** bolted down the sheer rock sides of each sea-stack into the cloud sea.
10. **Hanging Storm Lanterns & Prayer-Pennant Lines** strung along the skybridge main cables (≥ 18 studs clear overhead at peaks, sides outside `UsableWidth`).
11. **Wind-Twisted Cliff Pines** clinging horizontally out of the sheer slate aprons.
12. **Thunder-Glass Waystones** marking each skybridge bridgehead.
13. **Rope-Pulley Supply Hoist** on `Basin` (Cloudbreak Ledge) overlooking the first drop.
14. **Storm-Cracked Stone Bridge Piers** rising out of the cloud floor beneath `Crossing`.
15. **Squall Herald Perch-Poles** with copper sound-horns on `NeedleWest` and `NeedleEast`.
16. Far: an endless range of needle-like cloud-piercing peaks and distant hanging bridges vanishing into the violet squall.

**Ecosystem weight:** vertical exposure, swaying-look skybridges, luminous cloud abyss and crackling fulgurite needles.

---

### Floor 29: Tempest Redoubt (`ELITE_STRONGHOLD`)

*735 × 790 × 260, `Bottom = -6` (storm-lashed cliff moat / cloud chasm). Electric dusk.*

**Story beat:** the Kairnfolk's mountain acropolis — a two-tiered stone-and-copper stronghold split across a sheer geological cliff fault, built to channel the mountain's lightning into defensive storm-batteries.

**Shape: two-tiered highland acropolis split by an east–west cliff fault, crossed by twin flanking cliff switchbacks and a soaring central Thunder-Viaduct.** South of the cliff fault sits the lower ward: `Basin` (Outer Causeway, Y 0) feeds the **Lower Barbican** (`Crossing`, Y 8) and twin terraced **Ram Yards** (`WestGallery` Y 12, `EastGallery` Y 14), each flanked by an outer cliff-edge **Horn Post** (`WestHornPost`, `EastHornPost`, Y 16). Across the middle of the room, the ground shears upward by 20+ studs along the **East–West Cliff Fault**. Three dramatic ways scale it:
- West cliff switchback: `WestGallery` (Y 12) → `WestSwitchback` (Y 22) → `WestBastion` (West Stormkeep, Y 30)
- East cliff switchback: `EastGallery` (Y 14) → `EastSwitchback` (Y 24) → `EastBastion` (East Stormkeep, Y 32)
- Central **Thunder-Viaduct**: `Crossing` (Y 8) → `ViaductPier` (Y 20) → `UpperGate` (Storm-Bell Gate, Y 36, STAIRS) → `Apex` (Tempest Redoubt, Y 48, STAIRS), leaping straight over the fault on towering arched stone-and-copper viaduct piers!
On the upper citadel, `WestBastion` links cross-wall to `UpperGate` and branches out to the towering dead-end **Capacitor Spire** (`WestCoilSpire`, Y 38), while both Stormkeeps and the Storm-Bell Gate converge on **Tempest Redoubt** (`Apex`, Y 48). **New to the tower:** a geological two-tier cliff-fault acropolis with a central arched Thunder-Viaduct leaping over the escarpment and crackling copper capacitor battery spires.

```
                        N (−Z)
            ┌───────────────────────────────────────────────┐
            │  [CAPACITOR]    [ TEMPEST REDOUBT ] Y48       │
            │  [  SPIRE  ]       /     ‖ (st)    \          │
            │     Y38      [W. STORMKEEP]─[STORM-BELL] [E. STORMKEEP]
            │        \     /     Y30      [GATE Y36]      Y32
            │         \   /                   ‖ (st)       |
            │  ═══════════╦═════════════[VIADUCT PIER]═════╦═══  <-- E-W CLIFF FAULT
            │  [W. HORN] [W. FAULT]          Y20       [E. FAULT] [E. HORN]
            │    Y16     [SW. Y22 ]           |        [SW. Y24 ]   Y16
            │      \       /                  |           \        /
            │  [W. RAM YARD]           [LOWER BARBICAN]   [E. RAM YARD]
            │       Y12                      Y8                Y14
            │          \                     |                /
            │           ~~~~ OUTER CAUSEWAY  Y0 ~~~~         │
            │                            |                   │
            │                    [ SANCTUARY ] Y8            │
            └───────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Outer Causeway | 0, 0, 230 | 630 × 112 | terrain |
| `Crossing` | Lower Barbican | 0, 8, 102 | 88 × 68 | terrain |
| `WestGallery` | West Ram Yard | −208, 12, 84 | 92 × 80 | terrain |
| `EastGallery` | East Ram Yard | 208, 14, 84 | 92 × 80 | deck (`KAIRN_STONE`) |
| `WestHornPost` (extra) | West Horn Post | −302, 16, −28 | 62 × 56 | terrain |
| `EastHornPost` (extra) | East Horn Post | 302, 16, −28 | 62 × 56 | terrain |
| `ViaductPier` (extra) | Thunder-Viaduct Pier | 0, 20, −24 | 68 × 58 | deck (`THUNDER_VIADUCT`) |
| `WestSwitchback` (extra) | West Fault Switchback | −194, 22, −48 | 72 × 60 | deck (`KAIRN_STONE`) |
| `EastSwitchback` (extra) | East Fault Switchback | 194, 24, −48 | 72 × 60 | terrain |
| `WestBastion` | West Stormkeep | −212, 30, −176 | 92 × 82 | deck (`KAIRN_STONE`) |
| `EastBastion` | East Stormkeep | 212, 32, −176 | 92 × 82 | terrain |
| `UpperGate` (extra) | Storm-Bell Gate | 0, 36, −160 | 84 × 64 | terrain |
| `WestCoilSpire` (extra) | Capacitor Spire | −282, 38, −304 | 68 × 56 | deck (`THUNDER_VIADUCT`) |
| `Apex` | Tempest Redoubt | 0, 48, −306 | 136 × 98 | terrain |

**Paths (17 links, max slope 11.59°, shortest walk 672.2 = 1.48× canonical):**
`Sanctuary→Basin`, `Basin→Crossing`, `Basin→WestGallery`, `Basin→EastGallery`, `Crossing→ViaductPier`, `WestGallery→WestHornPost`, `EastGallery→EastHornPost`, `WestGallery→WestSwitchback`, `EastGallery→EastSwitchback`, `WestSwitchback→WestBastion`, `EastSwitchback→EastBastion`, `ViaductPier→UpperGate` (`STAIRS`: upper viaduct grand steps), `WestBastion→UpperGate`, `WestBastion→WestCoilSpire`, `WestBastion→Apex`, `EastBastion→Apex`, `UpperGate→Apex` (`STAIRS`: Storm-Bell Keep steps).
*Suspended/Viaduct spans:* `Crossing_ViaductPier`, `ViaductPier_UpperGate`, `Basin_EastGallery`, `EastGallery_EastHornPost`, `WestGallery_WestSwitchback`, `EastGallery_EastSwitchback`, `WestSwitchback_WestBastion`, `WestBastion_UpperGate`, `WestBastion_WestCoilSpire`, `WestBastion_Apex`, `EastBastion_Apex` in `Suspended.Links`, with `StonePiers = { ViaductPier = true }` so the central viaduct stands on towering arched highland masonry piers rooted deep into the cliff fault!

**Camps (35, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5, `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5 (Elite), `UPPER_WEST` 5 (Elite — elevated Y 30!), `UPPER_EAST` 5 (Elite — elevated Y 32!).

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (`Always`, 129.7 s), `LOWER_WALL` = `{WestGallery, Basin, EastGallery}` (204.0 s), `FAULT_VIADUCT` = `{Crossing, ViaductPier, UpperGate}` (105.9 s), `UPPER_REDOUBT` = `{WestBastion, Apex, EastBastion}` (200.0 s).

**Landmarks (≥ 18):**
1. The **Tempest Redoubt Citadel Keep & Twin Lightning Spires** behind `Apex` (≥ 160 studs): tiered dry-stone highland fortress walls crowned by a huge copper-ringed storm-spire catching sky lightning.
2. The **East–West Cliff Fault Escarpment** (`CLIFF_FAULT` terrain feature) shearing across the centre of the mountain with stepped basalt-slate strata and foaming storm-water cascades.
3. The **Arched Thunder-Viaduct** (`ViaductPier` + arched masonry piers + copper parapet conduits) leaping straight across the cliff fault from `Crossing` to `UpperGate`.
4. The **Storm-Bell Gatehouse** astride `UpperGate` — massive granite portal housing a giant verdigris-copper storm-bell hung ≥ 20 studs overhead.
5. The **Grand Copper Capacitor Spire** crowning `WestCoilSpire` — nested copper torus coils and caged lightning-nexus sphere (echoing the Tier 3 relic skin).
6. **West & East Stormkeep Round Towers** anchoring `WestBastion` and `EastBastion`, wired by overhead copper grounding cables to the Redoubt Keep.
7. **Lower Barbican Gatehouse & Portcullis** framing `Crossing` with twin forked-bolt banners.
8. **Twin Cliff-Edge Signal Horns** (huge copper-bound acoustic trumpets) mounted on `WestHornPost` and `EastHornPost`.
9. **Fault Switchback Retaining Buttresses** propping up `WestSwitchback` and `EastSwitchback` against the sheer rock wall.
10. **Fortified Thunder Ram Stables** along `WestGallery` and `EastGallery`.
11. **Copper-Caged Lightning Nexus Brazier Pedestals** lining the Outer Causeway (`Basin`).
12. **Storm-Glass Ballista / Lightning-Spear Emplacements** overlooking the fault from the Stormkeeps.
13. **Crag Channeler Ritual Dais** carved with a giant forked-bolt mosaic beside `UpperGate`.
14. **Shattered Cliff-Wall Watchtower** half-toppled into the western chasm wall.
15. **Braided Copper Conduit Runs** climbing the cliff face beside the viaduct piers.
16. **Highland Pine & Cairn Windbreaks** sheltering the lower causeway flanks.
17. **Weathered Shield-Walls & Kairnfolk War-Banners** snapping violently in the dusk gale.
18. Far: storm-lit mountain buttresses, distant crackling relay spires and an electric-violet dusk cloud bank.

**Ecosystem weight:** monumental highland engineering, crackling electric dusk, howling wind and towering stone-and-copper architecture.

---

### Floor 30: Roc's Eyrie (`BOSS_ARENA`)

*795 × 795 × 290, `Bottom = -8` (abyssal storm-cloud caldera — the deepest drop in the tower!). Eye of the Maelstrom.*

**Story beat:** the summit caldera at the roof of the Thunder Highlands — a colossal hollowed peak where the **Storm Roc** built its eyrie atop a shattered Kairnfolk lightning-crown, turning the whole mountain into the eye of an eternal maelstrom.

**Shape: ascending Twin-Wing Caldera Amphitheatre around an open central Cloud-Eye abyss.** You arrive at **Thunderhead Threshold** (`Basin`, Y 0) on the southern caldera lip looking straight across a vast, empty, swirling **Cloud-Eye** (`Bottom = -8`) up at the soaring **Roc's Eyrie** (`Apex`, Y 56, `180 × 132`) and the **≥ 200-stud Shattered Sky-Spire** towering behind it!
- At the southern lip of the vortex sits **Eye-Rim Overlook** (`Crossing`, Y 12), projecting a dramatic dead-end **Storm Eye Pulpit** (`EyePulpit`, Y 16) straight out into the swirling cloud abyss for a breathtaking 360° vista of the whole amphitheatre.
- **No path crosses the open Cloud Eye directly to `Apex`** — instead, the **West Wing** and **East Wing** sweep outward and upward around the caldera rim in stepped winged arcs (`WestGallery` Y 8 → `WestPinion` Y 20 → `WestBastion` Y 32 → `WestAerie` Y 44 → `Apex` Y 56; `EastGallery` Y 10 → `EastPinion` Y 22 → `EastBastion` Y 34 → `EastAerie` Y 46 → `Apex` Y 56), with inner chord skybridges (`Crossing→WestPinion`, `Crossing→EastPinion`), a lower flank link (`WestGallery→Crossing`), and three perched talon-outcrop spurs (`WestPerch` Y 14, `EastPerch` Y 18, `WestCrown` Y 40) ringing the caldera cliffs!
- **New to the tower:** a hollow **Twin-Wing Caldera Amphitheatre** wrapping an open storm-vortex Cloud Eye with a cantilevered viewing pulpit, culminating in the tower's largest and highest open-sky boss dais (`180 × 132` at `Y 56`) crowned by a **≥ 200-stud Shattered Sky-Spire & Lightning Crown**.

```
                        N (−Z)
            ┌─────────────────────────────────────────────────┐
            │           [     ROC'S EYRIE     ]               │
            │           [   180 × 132   Y56   ]               │
            │  [SHATTERED]   // (st)    \\ (st)               │
            │  [CROWN Y40] [W. AERIE]   [E. AERIE]            │
            │      \       /  Y44          Y46                │
            │   [W. GALE BASTION]   (   )   [E. GALE BASTION] │
            │         Y32          (CLOUD)        Y34         │
            │          |            (EYE)          |          │
            │  [W. PERCH] [W. PINION][PULPIT][E. PINION] [E. PERCH]
            │     Y14        Y20   /  Y16  \    Y22        Y18│
            │       \       /     /    |    \      \      /   │
            │   [W. FEATHER]──[EYE-RIM OVERLOOK]  [E. FEATHER]│
            │       Y8               Y12               Y10    │
            │          \              |               /       │
            │          ~~~ THUNDERHEAD THRESHOLD Y0 ~~~       │
            │                         |                       │
            │                 [ SANCTUARY ] Y8                │
            └─────────────────────────────────────────────────┘
```

| Id (role) | Name | Centre (X, Y, Z) | Size | Kind |
| --- | --- | --- | --- | --- |
| `Basin` | Thunderhead Threshold | 0, 0, 232 | 665 × 108 | terrain |
| `WestGallery` | West Feather Shelf | −208, 8, 92 | 92 × 80 | terrain |
| `EastGallery` | East Feather Shelf | 208, 10, 92 | 92 × 80 | deck (`KAIRN_STONE`) |
| `Crossing` | Eye-Rim Overlook | 0, 12, 98 | 86 × 64 | terrain |
| `WestPerch` (extra) | West Talon Perch | −322, 14, −14 | 62 × 54 | deck (`SKYBRIDGE`) |
| `EyePulpit` (extra) | Storm Eye Pulpit | 0, 16, −16 | 64 × 54 | terrain (or deck) |
| `EastPerch` (extra) | East Talon Perch | 322, 18, −14 | 62 × 54 | deck (`SKYBRIDGE`) |
| `WestPinion` (extra) | West Pinion Crag | −148, 20, −22 | 72 × 58 | terrain |
| `EastPinion` (extra) | East Pinion Crag | 148, 22, −22 | 72 × 58 | deck (`KAIRN_STONE`) |
| `WestBastion` | West Gale Bastion | −194, 32, −140 | 92 × 82 | terrain |
| `EastBastion` | East Gale Bastion | 194, 34, −140 | 92 × 82 | deck (`KAIRN_STONE`) |
| `WestCrown` (extra) | Shattered Crown Spire | −316, 40, −266 | 64 × 56 | terrain |
| `WestAerie` (extra) | West Aerie Landing | −182, 44, −262 | 72 × 58 | terrain |
| `EastAerie` (extra) | East Aerie Landing | 182, 46, −262 | 72 × 58 | deck (`KAIRN_STONE`) |
| `Apex` | Roc's Eyrie | 0, 56, −298 | 180 × 132 | terrain (or `EYRIE_NEST` deck — Y 56 is a multiple of 4!) |

**Paths (19 links, max slope 14.48°, shortest walk 872.0 = 1.72× canonical):**
`Sanctuary→Basin`, `Basin→WestGallery`, `Basin→Crossing`, `Basin→EastGallery`, `Crossing→EyePulpit`, `Crossing→WestPinion`, `Crossing→EastPinion`, `WestGallery→Crossing`, `WestGallery→WestPerch`, `EastGallery→EastPerch`, `WestGallery→WestPinion`, `EastGallery→EastPinion`, `WestPinion→WestBastion`, `EastPinion→EastBastion`, `WestBastion→WestCrown`, `WestBastion→WestAerie`, `EastBastion→EastAerie`, `WestAerie→Apex` (`STAIRS`: West Eyrie Ascent), `EastAerie→Apex` (`STAIRS`: East Eyrie Ascent).
*Suspended spans:* put `Crossing_EyePulpit`, `Crossing_WestPinion`, `Crossing_EastPinion`, `WestGallery_Crossing`, `WestGallery_WestPerch`, `EastGallery_EastPerch`, `Basin_EastGallery`, `WestGallery_WestPinion`, `EastGallery_EastPinion`, `WestPinion_WestBastion`, `EastPinion_EastBastion`, `WestBastion_WestCrown`, `WestBastion_WestAerie`, `EastBastion_EastAerie`, `WestAerie_Apex`, `EastAerie_Apex` in `Suspended.Links` (cantilevered stone-and-copper skybridges and winged stairs soaring above the `Bottom = -8` Cloud Eye!).

**Camps (35 + Boss, 4 Elites):** `BASIN_WEST` 5, `BASIN_EAST` 5, `CENTRAL_CROSSING` 5 (Elite), `WEST_GALLERY` 5 (Elite), `EAST_GALLERY` 5, `UPPER_WEST` 5 (Elite — Y 32), `UPPER_EAST` 5 (Elite — Y 34). The **Storm Roc** (`24 × 16 × 17`) is summoned on the `180 × 132` Eyrie dais (95-stud leash). **Gale Slash**, **Thunderclap** and **Lightning Strike** must stay cleanly on the dais and never spill onto a ramp. Keep the dais floor clean, dark storm-slate ringed on the outer rim only by low woven nest-timber and copper-glyph bollards.

**Patrols (authored, `ReplacePatrols = true`):** `BASIN_LOOP` (`Always`, 140.2 s), `WEST_WING` = `{WestGallery, WestPinion, WestBastion, WestAerie}` (152.9 s), `EAST_WING` = `{EastGallery, EastPinion, EastBastion, EastAerie}` (152.9 s), `EYE_CHORD` = `{WestPinion, Crossing, EastPinion}` (152.8 s), `EYRIE_CROWN` = `{WestAerie, Apex, EastAerie}` (149.3 s).

**Landmarks (≥ 20, plus the colossal centrepiece):**
1. **The Shattered Sky-Spire & Lightning Crown (colossal centrepiece, ≥ 200 studs tall):** a split mountain peak behind `Apex` wrapped in a broken ring of towering copper-and-slate lightning arches framing the Eyrie sky — **never overhanging the `180 × 132` boss arena**, and clear of `Layout.PortalSpots`!
2. **The Woven Great Nest Rim:** colossal lightning-blasted highland pine trunks and braided copper cable woven around the outer north/east/west edges of the `Apex` dais (outside the walkable combat ring).
3. **The Cloud-Eye Vortex** (`CLOUD_EYE` terrain feature at `Bottom = -8`): concentric sculpted cloud-bank walls and swirling mist vortex filling the open central caldera beneath `EyePulpit`.
4. **The Storm Eye Pulpit Shrine** on `EyePulpit`: a cantilevered stone compass-ring and forked-bolt lightning mast jutting straight into the vortex.
5. **Giant Shed Storm-Roc Feathers** (20–30 studs long, slate-and-copper metallic vanes crackling with static) impaled dramatically into `WestGallery`, `EastGallery`, `WestPerch` and `EastPerch`.
6. **Shattered Copper Crown Arc** on `WestCrown` — a fallen fragment of the summit's ancient lightning ring still humming with violet arcs.
7. **Twin Aerie Threshold Totems** flanking `WestAerie` and `EastAerie` at the foot of the twin summit stairs.
8. **Gale Bastion Wind-Harps** mounted atop `WestBastion` and `EastBastion`, angled into the rotating storm wall.
9. **Pinion Crag Cable-Anchors** on `WestPinion` and `EastPinion` tying the inner chord skybridges into the caldera ribs.
10. **Colossal Bleached Mountain-Beast Ribs & Talon Scars** nestled below `WestPerch` and `EastPerch` (the Roc's larder, outside walkable lanes).
11. **Feather-Heart Lightning Shrine** echoing the *Heart of the Storm Roc* relic skin on `Crossing`.
12. **Thunderhead Threshold Monolith Gate** framing the entrance onto `Basin`.
13. **Fulgurite Glass Columns** jutting from the sheer inner caldera cliffs.
14. **Hanging Copper Grounding Chains** anchored from the outer bastion cliffs down into the swirling cloud eye.
15. **Broken Kairnfolk Sky-Observatory Ruins** half-buried in the southern caldera rim.
16. **Twin Gale-Lantern Towers** lighting the wings' ascent from `WestGallery` and `EastGallery`.
17. **Ring of Eight Outer Caldera Lightning Rods** silhouetted on the cliff peaks ringing the entire amphitheatre.
18. **Cascading Rain-Spill Waterfalls** blowing sideways off the eastern and western caldera walls into mist.
19. **Storm-Bent Ancient Pines** clinging to the leeward ledges of the lower rim.
20. **Crag Channeler Offering Cairns** stacked with copper rings and fulgurite shards along both Aerie stairheads.
21. Far: a colossal circular wall of violet-lit thunderhead supercell clouds enclosing the entire horizon, opening straight upward into the bright Eye of the Maelstrom above the Eyrie.

**Ecosystem weight:** everything at full Tempest Squall intensity. The open-sky summit postcard of the first 30 floors, and the new high-water mark for the tower.

---

## Part 4: Environment and lighting per floor

Add `HubLighting.FloorGrades[26..30]`, each layered over `BiomeGrades[6]` (violet storm light), as Floors 1–25 did. `ClockTime` is shared and never changes; read mood through colour shift, ambient, atmosphere, tint, contrast, bloom and sun rays. Tune haze carefully so all three open-sky skyline layers (near terraces, mid cloud-gorges/towers, far peaks/supercell walls) stay distinct and readable.

| Floor | Mood | Light | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 26 | Storm-breaking highland dawn | Cool slate-blue ambient, pale gold-violet top light breaking through clouds | Light valley mist (`Density ~0.26`, `Haze ~1.0`) | Crisp wet-grass contrast; faint distant ridge flashes |
| 27 | Gathering thunderhead noon | Silver-indigo overcast sky, stronger contrast (`~0.16`), warm copper-fire pools on the broch | Thickening highland cloud haze (`Density ~0.30`, `Haze ~1.25`) | Copper beacon glow contrasting with bruised violet-grey clouds |
| 28 | Cloud-sea squall afternoon | Dark slate shadows above, **luminous silver-violet bounce from the cloud abyss below** (`ColorShift_Bottom`) | Crisp gorge air with deep chasm mist (`Density ~0.28`, `Haze ~1.15`) | Electric violet fulgurite needles & skybridge lanterns popping against dark sea-stacks |
| 29 | Electric dusk | Deep storm-indigo twilight, cool electric-violet key, warm amber hearth/brazier fill on the Stormkeeps | Charged storm haze (`Density ~0.32`, `Haze ~1.35`, `BloomIntensity ~0.56`) | Capacitor spire arcs & Storm-Bell Gate lighting the cliff fault |
| 30 | Eye of the Maelstrom | Bright electric white-violet shaft pouring down from the open storm-eye over dark thunderhead walls | Clear eye air inside (`Density ~0.26`, `Haze ~1.10`), strong bloom (`~0.64`) nudged softly on squall peaks | 200-stud Shattered Sky-Spire & dark slate Eyrie dais reading crisply for the Storm Roc fight |

Effects are client-only and pooled, and respect the Graphics quality setting.

---

## Part 5: Engineering

### 5.1 Room sizing and compact-grand pacing

`TowerLayout` already supports `Size = { Width, Depth, Height, Bottom? }` from Infernal Foundry (Floors 21–25), and every consumer (`TowerRoomBuilder`, `TowerTerrain`, `TowerBiomeAssets`, `TowerFloorService`, `TowerEventService`, `HubLighting.TowerFloorAt`) reads the built layout's dimensions.
- Keep all five Thunder Highlands rooms open-sky (`isNatural` already includes `thunder_highlands` in `TowerRoomBuilder.luau` line 481 — confirm no vault ceiling closes them off!).
- Confirm `HubLighting.TowerFloorAt` (2,400-stud grid) cleanly holds `795 × 795`.
- Keep Floors 1–25 and 31–50 byte-identical.

### 5.2 Set-piece registry & clean module sizing

- Place Thunder Highlands set pieces in `ServerScriptService/Core/TowerSetPieces/ThunderHighlands.luau` (and split per floor — `ThunderFloor26.luau` .. `ThunderFloor30.luau` — once a floor exceeds ~800–1,000 lines, mirroring `InfernalFloor24.luau` and `InfernalFloor25.luau`), exporting each floor's `LandmarkFootprints` for offline SAT lane/camp spec verification.
- If the Infernal PR left any shared infrastructure unfinished on your base branch (the merged `TowerLayout` schema, `TowerSetPieces/init.luau` registry, `tests/studio-tower-asset-census.luau`, or the `TowerDetail` culling tier), check its status first and wire Thunder Highlands cleanly into it rather than duplicating ad-hoc branches in `TowerBiomeAssets.luau`.

### 5.3 Terrain materials, surfaces, cloud chasms and masonry

**Materials are place-wide.** Never touch Fungal-owned materials (`Cobblestone`, `Concrete`, `Pavement`, `Asphalt`), never recolour shared `MaterialColors`, and **never use `TowerTerrain.BlockyMaterials` (`Brick`, `WoodPlanks`)** on terrain surfaces or accents.

- Add `KAIRN` to `TowerTerrain.Surfaces` using the existing highland materials:
  - `Trail = Slate`, `Walk = Grass`, `WalkAccent = LeafyGrass`, `Bank = Rock`, `Cliff = Slate`, `Peak = Rock`, `PoolBed = Mud`, `Lush = LeafyGrass` (with `Water` for shallow highland rills/tarns on Floors 26–27, and `Liquid.Dry = true` on the cloud-abyss Floors 28–30 so the bottom floor renders crisp dark slate beneath sculpted cloud banks rather than turquoise swimming water!).
- **Terrain features (data-driven in `TowerTerrain.luau`):**
  - Reuse `APEX_ALCOVE`, `PRESSURE_RIDGE` (for wind-scoured slate ribs) and `CENOTE_LAGOON` (dry, for Floor 30's hollow caldera floor).
  - Add only what is genuinely new, obeying every terrain rule (`UNDER`/`RIM` clearance, never above a walkway, never under `Bottom - 4`, 6-stud moat, `RES / 2`, FBM edges, 4-stud terrace grid):
    - `CLIFF_FAULT` (Floor 29: a dramatic E–W step-shelf escarpment across the room's middle)
    - `SEA_STACK_APRON` (Floor 28: tight, near-vertical sea-stack columns under pinnacle terraces so the cloud chasm opens wide between stacks)
    - `CLOUD_EYE` (Floor 30: deep circular caldera basin beneath `EyePulpit` ringed by steep amphitheatre walls)
    - `LIGHTNING_SCAR` (shallow blasted radial rock grooves / fulgurite ridges on Floors 26, 28, 30)
- **Cloud chasms (Floors 28–30):** **never** use giant flat semi-transparent coloured boxes (the Floor 24 Pour glow-seam lesson!). Build the swirling cloud sea from layered sculpted cloud-bank kit meshes (`CloudBankLayer`), subtle particle mist wisps, and invisible `Transparency = 1` `PointLight` underglow anchors.
- **Masonry styles (`TowerRoomBuilder.MASONRY_STYLES`):**
  - `KAIRN_STONE`: weathered highland slate-granite slabs, dry-stone battered aprons, oxidised copper corner bands.
  - `SKYBRIDGE`: timber-and-copper slatted bridge decks, twin stone-and-copper anchor pylons at bridgeheads, thick braided copper catenary cables and vertical suspension hangers (outside `UsableWidth`, ≥ 18 studs clear overhead at towers!).
  - `THUNDER_VIADUCT`: heavy arched slate masonry viaducts with inlaid copper lightning-conduit trim and copper parapet rings.
  - `EYRIE_NEST`: dark storm-slate boss dais rimmed with weathered giant pine logs and copper glyph inlays (strictly outside the walkable arena ring).
- **`PathStyle = "KAIRN"`:** slate flagstone trails with mossy turf kerbs, copper-nosed slate stairs, and solid visible `KAIRN_STONE` / `SKYBRIDGE` bridgehead aprons on exposed landings (`landingOutsideTerrace`).

### 5.4 Kits: enough meshes for the ladder

Follow the per-floor headless-Blender kit pipeline:
1. Generate with `tools/blender/generate_thunder_fN_kit.py` → `assets-source/tower/thunder_fN_kit/`, run with headless Blender (`--background`).
2. Register every new template in **`TowerBiomeKit.ExtraTemplates`** only (never alter `Templates`). Add `CastsShadow` entries for large architectural/natural meshes only (never small clutter, glow or crystal).
3. Reuse aggressively across all 5 floors to hit the "distinct templates placed" ladder cleanly: core kit (`PineTree`, `Cairn`, `CliffRockA`/`CliffRockB`, `ChasmIsland`, `Obelisk`, `CrystalSpire`, `BoulderCluster`, `RuinRubble`, `StoneUrn`, `ArchCrown`, `ArchPierSegment`, `DeadTree`) plus re-tinted earlier `ExtraTemplates` (`FulguriteCluster`, `VarrashLightningRod`, `VarrashWaystone`, `SignalBrazier`, `CurtainWallRuins`, `TollHouseRuins`).
4. Place every template behind `TowerKitProps.Has(name)` with a crisp native fallback.

| Floor | New kit template candidates (meet ≥ 8 / 9 / 10 / 11 / 12) |
| --- | --- |
| 26 | `ForkedBoltTotem`, `HighlandWindmill`, `StandingStoneArc`, `ShepherdCroft`, `DryStoneWall`, `RamHurdleFence`, `TrailCairnTall`, `WindBentPine`, `StormgrassTuft` |
| 27 | `BrochKeepTower`, `WindHarpTower`, `PalisadeWallSpan`, `CopperWireReel`, `SignalBeaconPlinth`, `WatchBellGallows`, `HighlandLonghouse`, `StormUrnTripod`, `CopperCablePost`, `BeaconBrazierTall` |
| 28 | `SkybridgePylon`, `CableWinchCapstan`, `SeaStackSpire`, `CloudBankLayer`, `ShedRocFeather`, `FulguriteSpireTall`, `AnemometerMast`, `CliffGroundingChain`, `SnappedBridgeStub`, `TalonNestPlatform`, `PrayerPennantLine` |
| 29 | `RedoubtCitadelKeep`, `StormBellGatehouse`, `CapacitorCoilSpire`, `ViaductArchPier`, `StormkeepRoundTower`, `SignalHornEmplacement`, `FaultButtressWall`, `LightningSpearBallista`, `CopperConduitRun`, `ForkedBoltBanner`, `ThunderRamStable`, `NexusCorePedestal` |
| 30 | `ShatteredSkySpire`, `LightningCrownArch`, `EyrieNestRimSegment`, `EyePulpitCompass`, `ColossalRocFeather`, `CalderaLightningRod`, `ShatteredCrownFragment`, `GaleLanternTower`, `CalderaRibBones`, `ObservatoryRuin`, `FeatherHeartShrine`, `SupercellCloudPillar`, `AerieThresholdTotem` |

`TowerBiomeKit.Biomes.thunder_highlands` already defines `MOSS`, `WOOD`, `FOLIAGE`, `CRYSTAL` and `ALT`. Add `COPPER` (burnished copper `Metal`) and `VERDIGRIS` (weathered turquoise-slate copper patina) if needed.

**Import into the live experience** (`Infinite Towers: Become a Master!`, placeId `136256010643848`) via File > Import 3D and `tests/studio-tower-biome-kit-import.luau` (ensure Rojo is synced before running the importer so `ExtraTemplates` is current!), verify mesh parity, and save the place.

### 5.5 Lessons from Floors 1–25 (every single one came from a real Studio fix)

1. **Off-grid decks & chasm spans MUST be in `Suspended.Links`** (Infernal 24 & 25): on `DirectTerrain = true` floors, un-suspended links render as invisible terrain proxies that cannot meet off-4-stud deck heights (`Y 6, 10, 14, 18, 22, 30, 34, 46`) or cross chasms. Put them in `Suspended.Links` and extend `TowerRoomBuilder`'s `landingOutsideTerrace` bridgehead apron logic to `KAIRN` / `KAIRN_STONE` / `SKYBRIDGE` / `THUNDER_VIADUCT` so every diagonal or cliff-edge join is visibly and physically flush!
2. **Never build fake decorative bridges or stepped crags across non-existent paths** (Infernal 24 `CitadelApproachCrag`): if two terraces have no `TowerLayout` link (like Floor 26's `Crossing` to `Apex`, Floor 27's `Basin` to `Crossing`, or Floor 30's `EyePulpit` to `Apex`), leave the gap unmistakably impassable — sheer cliff face, solid palisade wall, or wide open Cloud Eye! Broken skybridge stubs on Floor 28 must end abruptly with jagged planks and cairn barriers, never reaching across toward another terrace.
3. **Never place flat semi-transparent coloured boxes for glow or clouds** (Infernal 24 `PourMagmaGlowSeam`): use invisible `Transparency = 1` `PointLight` anchors + sculpted 3D meshes (`CloudBankLayer`, `FulguriteSpireTall`) and pooled particle emitters.
4. **Never use blocky terrain materials** (`Brick`, `WoodPlanks` — Infernal 21–23): Roblox collides them as 4-stud stairs.
5. **Verify pitch signs on angled chutes, leaning pines, feathers and cables** (Infernal 24 downward-chute pitch bug): check `CFrame.Angles` sign in Studio so waterfalls, chains, snapped cables and buttresses slope the right way and never float upward.
6. **Terrain terraces on multiples of 4 studs** (Fungal): only decks sit on off-4 heights.
7. **Big landmarks vs. boss portals** (Ashen): keep the 200-stud `ShatteredSkySpire` and every Apex landmark clear of `Layout.PortalSpots` lanes.
8. **Offline SAT footprint checks** (Infernal 21–25): check every placed landmark's real scaled rotated footprint against `Layout.Lanes` and `room.Camps` in a spec before opening Studio. One overlapping part deletes the whole prop!
9. **Overheads vs. the camera** (Frozen 19–20, Infernal 22 & 25): overhead copper cables, Storm-Bell arches and the Shattered Sky-Spire keep ≥ 18 studs clear over walk surfaces and **never overhang the Floor 30 boss arena**.
10. **Ground everything; small clutter non-collidable:** grounding raycasts include `workspace.Terrain` (`IgnoreWater = true`), hanging cables/chains attach to registered pylons or cliff anchors, and small clutter has `CanCollide = false`, `CanQuery = false`, `CastShadow = false`.

### 5.6 The Tempest Squall (client-only)

- One client module (`StarterPlayerScripts/Rendering/TempestSquall.luau`) running **only** while the local player is on Floors 26–30.
- Synchronised from `workspace:GetServerTimeNow()` so every player experiences the same gusts and lightning swells with zero remotes. Cycle tightens from Floor 26 (~12 s rolling gusts) to Floor 30 (~5 s maelstrom surges).
- On each surge, operating on `CollectionService`-tagged parts/emitters with strict instance caps:
  - flares electric violet-white Neon seams on copper lightning totems, cables and fulgurite spires
  - pulses copper wind-harp chime shimmer and plays one spatial wind/chime or distant rolling thunder sound
  - briefly increases slant-rain / cloud-wisp emitter rate
  - adds a gentle, short bloom nudge (`+0.08..0.15`, **never** a blinding full-screen white flash!)
- **Zero gameplay effect.** At lowest Graphics quality, only the Neon static pulse runs.

### 5.7 Telegraph readability

Electric violet-white lightning glows and luminous cloud mist contrast naturally well against warm orange-red enemy telegraphs — **protect that advantage**:
- Keep camp centres and the `180 × 132` Floor 30 Eyrie dais free of bright white-violet Neon inlays or busy clutter (use dark storm-slate and muted highland stormgrass on combat floors).
- Verify in playtest that every enemy telegraph — especially Crag Channeler bolts, Thunder Ram charges/ground-areas, and the Storm Roc's **Gale Slash**, **Thunderclap** and **Lightning Strike** — pops unmistakably at gameplay camera height.

### 5.8 Performance: higher spectacle, locked frame rate

- **Instance, don't model.** Reuse MeshIds aggressively across terraces and cliff rims; ground cover (`StormgrassTuft`, heather, pebbles) uses multi-clump meshes with `CastShadow = false`, `CanCollide = false`, `CanQuery = false`.
- **Detail tiers:** tag small clutter and ground cover `TowerDetail` so `EffectCullingRules` / client culler hides them past ~220 studs or at low quality. Landmarks are never culled.
- **Lights & emitters:** ≤ 24 `PointLight`/`SpotLight` per floor (rely on Neon + bloom for totems and fulgurite). Particle emitters: ≤ 12 on Floors 26–28, ≤ 16 on Floors 29–30, all pooled and quality-scaled.
- **Budget & target:** each Thunder Highlands floor stays within **1.5×** the same-index Infernal floor's instance count, hitting **≥ 45 FPS** in full camp fights on Floors 26–30 and **≥ 40 FPS** during the Floor 30 Storm Roc fight at the lowest Graphics quality setting (MicroProfiler). Report the numbers in the PR.

### 5.9 Data and saves

Layouts are not persisted. No profile schema change and no `DataManager.SyncProfile` migration are needed.

---

## Part 6: Process, tests and docs

### Phases and the review gate

1. **Prep & baseline:** verify `TowerSetPieces` registry and `tests/studio-tower-asset-census.luau` are present (or finish them first if still owed from Infernal). Record the Floors 1–25 per-index census maxima.
2. **Design gate:** for each Thunder Highlands floor (26–30), present:
   - final coordinate table and ASCII map with links, `Suspended.Links`, camps and patrols
   - every link's rise and slope
   - the ladder row it must beat
   - the landmark list
   - the Blender kit templates to generate, each with a one-line silhouette description

   **Stop and wait for sign-off.**
3. **Floors 26–30**, one at a time, lowest first (`feat(tower): author Thunder Highlands floor N (<name>)`). Run `pwsh tests/run.ps1 -LuauDirectory D:/luau`, `rojo build -o build.rbxl`, and the Studio census/audit after each floor.
4. **Lighting & Atmosphere:** `HubLighting.FloorGrades[26..30]`, **Tempest Squall** (`TempestSquall.luau`), and `TowerDetail` culling verification.
5. **Kits imported into the main experience** (`placeId 136256010643848`) and verified.
6. **Docs, specs and PR** against `main` with the full census table and MicroProfiler FPS numbers.

### Tests

```bash
pwsh tests/run.ps1 -LuauDirectory D:/luau
```

Never pass `-InstallLuau`. Extend:

- `tower-layout-variants.spec.luau`:
  - each Thunder Highlands floor (26–30) is authored and fixed with its key (`thunder:1..5`), name, `Size`, `PathStyle = "KAIRN"`, `DirectTerrain = true`, `Surface = "KAIRN"`, and signature topology assertions:
    - **Floor 26:** no direct `Crossing→Apex` (wind-tacking contours around the central headwall); `WestCrag→Apex` is `STAIRS`.
    - **Floor 27:** concentric ringfort — no `Basin→Crossing`; `Basin` enters only via `WestOuter` and `EastOuter`; `Crossing→Apex` is `STAIRS`.
    - **Floor 28:** `Bottom = -6` with 2 return ramps; staggered sky-pinnacle archipelago with `SKYBRIDGE` suspended spans across the cloud gorge; `CloudSpire→Apex` is `STAIRS`.
    - **Floor 29:** `Bottom = -6` with 2 return ramps; `CLIFF_FAULT` terrain feature + arched `ViaductPier` (`StonePiers`); `ViaductPier→UpperGate` and `UpperGate→Apex` are `STAIRS`.
    - **Floor 30:** `Bottom = -8` with 2 return ramps; `EyePulpit` is a dead-end overlook over the open `CLOUD_EYE` (no direct path from `Crossing` or `EyePulpit` to `Apex`); `Apex` is `180 × 132` at `Y 56`; `WestAerie→Apex` and `EastAerie→Apex` are `STAIRS`.
  - **the ladder:** across Floors 26–30, room area, room height, terraces (`10..16`), links (`11..19`), height levels (`9..15`) and Apex Y (`24..56`) strictly increase, and every floor strictly beats Floors 1–25 at the same index.
  - every terrain terrace (`not Decks[id]`) sits on `Y % 4 == 0`; every link slope `≤ 15°`; zero `Validate` problems; mob totals `16 / 22 / 25 / 35 / 35` and Elite counts `1 / 2 / 3 / 4 / 4`; `ExtraPlatforms` hold no camps; every camp and platform reachable from `Sanctuary`.
  - offline SAT landmark footprint checks against `Layout.Lanes` and `room.Camps` for Floors 26–30.
- `tower-patrols.spec.luau`: Floors 28–30 authored patrols resolve cleanly, stay on walkways, keep loop duration `< 240 s`, and have exactly one `Always` route (`BASIN_LOOP`).
- `tower-portals.spec.luau`; `tower-biome-kit.spec.luau` (Thunder `ExtraTemplates` well-formed and meeting the ladder count per floor, `Templates` unchanged, `FloorGrades[26..30]` layered over `BiomeGrades[6]`, `KAIRN` surface uses zero `BlockyMaterials` and zero `FungalMaterials`).
- Regression snapshots: Floors 1–25 and 31–50 unchanged.

Then, in Studio, run `tests/studio-tower-prop-audit.luau` across all 50 floors (orphaned, floating, and walkway-overlapping props must all be **0**) and `tests/studio-tower-asset-census.luau` on Floors 1–30. Verify project integrity with `rojo build -o build.rbxl`.

### Docs (same PR)

- `docs/GAME_DESIGN.MD` §3.3: the Kairnfolk, the Storm Roc & Tempest Squall, the five Thunder Highlands floors, and the compact-grand pacing refinement to the escalation ladder.
- `docs/TOWER_NAVIGATION.md`: `KAIRN` path/surface style, `SKYBRIDGE` / `THUNDER_VIADUCT` masonry, and new terrain feature kinds (`CLIFF_FAULT`, `SEA_STACK_APRON`, `CLOUD_EYE`, `LIGHTNING_SCAR`).
- `reference/infinite_towers_biomes.md` §6: a short paragraph on the Kairnfolk, the forked-bolt totem, and the Tempest Squall.

### Finish with a Studio checklist for the user

Don't run the playtest yourself. End with a **How to test** checklist the user can follow:

1. Floors 26–30, each:
   - arrive out of aggro on `Basin`
   - walk every route and every bridgehead to the `Apex` (zero invisible gaps, zero blocky steps, zero awkward overhangs)
   - nothing floats; skybridges and cables anchor cleanly into pylons and cliff faces
   - nothing sits on a walkway or narrows a landing
   - each floor feels taller, denser and more dramatic than the last without feeling bloated to walk
2. Floor 26: `Crossing` faces a sheer unclimbed headwall; climb via both wind-tacking contours and inspect the Windmill Knoll and Standing Stones.
3. Floor 27: `Basin` enters only through the twin palisade gates; walk the concentric broch ringfort and both projecting Wind-Harp towers.
4. Floor 28: walk every rope-and-copper suspension skybridge across the sea-stack archipelago; check the layered cloud abyss below (no flat coloured boxes); drop into the cloud floor and climb out via both return ramps.
5. Floor 29: walk both cliff-fault switchbacks and cross the arched central Thunder-Viaduct through the Storm-Bell Gatehouse; check the crackling Capacitor Spire.
6. Floor 30:
   - walk out onto the cantilevered **Storm Eye Pulpit** over the open Cloud Eye (`Bottom = -8`)
   - sweep up both Twin-Wing arcs to the `180 × 132` Y 56 Eyrie dais
   - verify the ≥ 200-stud Shattered Sky-Spire towers behind the dais and never covers the camera during combat
   - summon the **Storm Roc** (`24 × 16 × 17`): verify Gale Slash, Thunderclap and Lightning Strike read cleanly and stay on the dais
   - defeat the Roc: verify Ascend (to Floor 31) and Rerun portals rise clear of all scenery
7. Telegraphs read clearly against violet lightning glows and dark slate floors on all five floors.
8. The **Tempest Squall** pulses identically across clients, intensifies from Floor 26 to Floor 30, never blinds the screen white, and stops cleanly on leaving the biome.
9. Squad follow and recall (`E`) work reliably across every skybridge, switchback, viaduct stair and bridgehead apron.
10. All authored patrols (`WEST_SKYLINE`, `EAST_SKYLINE`, `CLOUD_SPAN`, `LOWER_WALL`, `FAULT_VIADUCT`, `UPPER_REDOUBT`, `WEST_WING`, `EAST_WING`, `EYE_CHORD`, `EYRIE_CROWN`) walk smoothly without snagging.
11. Relic Rain lands cleanly on Thunder Highlands walkways (`workspace.TowerEventForce = "RELIC_RAIN"`).
12. Each floor's lighting grade transitions smoothly on entry and restores in the hub; all three skyline layers read clearly through the storm air.
13. Floors 1–25 and 31–50 look and play identically to before.
14. Frame rate at lowest Graphics quality: ≥ 45 FPS in camp fights, ≥ 40 FPS in the Floor 30 Storm Roc boss fight; `TowerDetail` distant clutter fades cleanly.
15. In the live experience (`placeId 136256010643848`), every Thunder Highlands kit renders as Blender meshes, not native part fallbacks.

## Out of scope

- Other biomes (Floors 1–25 and 31–50 stay unchanged).
- New enemies, boss moves, extra mobs for bigger rooms, lightning strike damage, wind pushback physics, swaying bridge physics, or weather that affects combat.
- Changes to rewards, relic drops, mob stats, camp respawn timing, or the tower difficulty curve.
