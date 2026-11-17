# Prompt: Verdant Ruins — a Unique Layout for Every Floor (Floors 1–5)

Copy everything below the line into a Claude Code session opened at the repo root.

> **Status (2026-11-17).** Floor 1 is built. Two things changed from the plan below, because `main` moved on after it was written (PR #327):
> - Part 4.1–4.2 is mostly done already: `TowerLayout.Get(index, floorId)` / `ForFloor` give every floor its own layout, every consumer passes the floor id, graphs are cached per floor and portal spots follow the Apex.
> - Instead of new terrace ids with a `Role` field, authored floors (`AUTHORED` in `TowerLayout`) keep the existing ids as roles (`Basin` = ENTRY, `WestGallery`/`EastGallery` = WING, `Crossing` = CROSSING, `WestBastion`/`EastBastion` = UPPER_WING, `Apex` = APEX) and carry in-world names in `Names`. They can replace the path list (`Paths`). Set pieces key on `layout.Authored`, and lighting on `HubLighting.FloorGrades`. Floors 2–5 need new terraces (Floor 2's AqueductNorth, Floor 4's wall-walk links), so they will need either more role ids or the `Role` field after all.

---

## Role

You are a two-specialist team speaking as one. Say which role you are speaking as when it matters.

**Warden** is a senior level designer and gameplay engineer for *Infinite Tower: Become a Master!*, a Roblox squad-command action RPG. Warden owns topography, sightlines, combat spaces, pacing, navigation and the `TowerLayout` connector contract. Warden thinks in walkable surfaces, link slopes, camp spacing, leash radii and the route a squad of five takes from the Sanctuary to the Apex.

**Grove** is a senior environment artist and world-builder. Grove owns the ecosystem, the flora and fauna, landmarks, materials, lighting and atmosphere, and builds them from native Roblox parts the way `TowerBiomeAssets.luau` already does. Grove designs every prop so it has a reason to exist in the ecosystem and reads clearly from the gameplay camera.

Neither of you breaks the runtime contracts described below.

## Before you start

1. Follow `CLAUDE.md` and `AGENTS.md`. Use the `roblox-world-building`, `roblox-luau`, `roblox-npc-ai` and `roblox-performance` skills.
2. Read `docs/GAME_DESIGN.MD` §3.3 (Dynamic Tower Room Architecture & Biomes), `docs/TOWER_NAVIGATION.md`, and `reference/infinite_towers_biomes.md` §1.
3. Read all of `src/ReplicatedStorage/Shared/Config/TowerLayout.luau`. Then read the parts of `TowerRoomBuilder.luau`, `TowerBiomeAssets.luau`, `TowerPropClearance.luau`, `TowerNavigationGraph.luau`, `HeroNavigation.luau`, `SquadMovement.luau`, `TowerEncounterRuntime.luau`, `CampWaves.luau`, `FirstBiomeCombat.luau`, `TowerFloorConfig.luau` and `TowerEventService.server.luau` that consume the layout.
4. Branch off `main` (`feat/verdant-floor-layouts`). Use conventional commits.

## The problem today

All 50 floors share five layouts. `TowerLayout.Get(index)` takes `IndexInBiome` (1–5), so Floor 1 (Verdant), Floor 6 (Fungal) and Floor 11 (Ashen) are the same room with different props: a south Sanctuary, a wide Basin, two Galleries, a Crossing, Bastions from floor 4, and the Apex at the back. Only the scenery changes.

**The goal:** give each of the five Verdant Ruins floors its own hand-authored topography, built around one ecosystem, so that each floor has a different shape, route and combat rhythm. Biomes 2–10 keep the current generic layouts unchanged in this change.

---

## Part 1: The ecosystem (the "why" behind every prop)

Every landmark, plant and creature below must trace back to this ecosystem. If a prop doesn't fit it, cut it.

### The lost civilisation: the Solmere

The Solmere were sun-keepers who built terraced temples to catch the first and last light of the day. Their motif is the **carved sun disc** (a ring with rays and a glowing core; it's already the Verdant motif in `tools/blender/mob_kit.py`). Their architecture is pale limestone and green-grey slate with bronze inlays that have weathered to verdigris. They built in **terraces, aqueducts and sun-gates**: everything faced the sky. They vanished when the forest woke up.

### The Heartroot

One colossal fig tree, the **Heartroot**, grows up through all five floors. Its roots are the "mysterious energy" in the biome description: they carry **sunsap**, a faintly glowing emerald-gold sap that the Solmere once tapped to power their stone guardians. When the Solmere fell silent, the Heartroot kept feeding the guardians, and the forest swallowed the temples.

The player climbs the tree as well as the tower. The root system tells the story:

| Floor | Where on the Heartroot | What the player sees |
| --- | --- | --- |
| 1 | Root tips | Thin roots splitting paving stones; first glow-lilies |
| 2 | Feeder roots tapped by the aqueduct | Roots drinking from broken channels; sap-stained stone |
| 3 | Main roots | Roots as thick as bridges spanning a gorge |
| 4 | The trunk's strangler-vines | Vines that have crushed a fortress |
| 5 | The crown and heart | The canopy over a sunken court; the Mossbound Guardian holds the heart in its chest |

### Living layers (use all of them on every floor, weighted per floor)

| Layer | Contents | Notes |
| --- | --- | --- |
| **Canopy** | Banyan and fig crowns, hanging lianas, moss curtains | Tall, rooted on the chasm floor or terraces (existing chasm-grove rule). Breaks the skyline. |
| **Understory** | Tree ferns, strangler figs wrapped round Solmere columns, broadleaf shrubs | Mid-height silhouette; frames ramps without touching lanes. |
| **Forest floor** | Moss carpets, fern beds, leaf litter, fallen columns, mushrooms on dead wood | Low and cheap. Decals or thin parts. |
| **Water** | Channels, still pools, small falls, reeds and water-lilies | Water is cosmetic: never a hazard, never a walk surface you need to cross. |
| **Glow** | **Glow-lilies** (emerald, open at night), **sunbells** (gold, turn to face light shafts), sap veins in root bark | The biome's light sources. Neon used sparingly, as accents. |
| **Stone** | Solmere temples, sun-gates, stelae, aqueduct arches, guardian statues | Always partly reclaimed: moss on top faces, roots through cracks. |

### Food web (how the enemies fit, `MobCatalog` → `verdant_ruins`)

- **Moss Crawler** (`CRAWLER`) grazes the moss on Solmere stone. It is why the ruins have bare, gnawed patches. Show grazing scars (pale stone strips) near camp spots.
- **Bloom Tender** (`ROOTED_BIPED`, support, `MEND`) tends glow-lily beds and sunbells. Place lily beds where camps stand so the healer looks at home.
- **Ruin Guardian** (`ARMORED_BIPED`) is a Solmere stone sentinel kept moving by sunsap. Put empty guardian plinths and toppled sentinels around the floor: the ones that stopped working.
- **Vinebound Elite** (`ROOTED_BIPED`) is a guardian the vines have taken over. Show half-swallowed statues with vines in the same pose.
- **Mossbound Guardian** (`STONE_COLOSSUS`, boss) is the Solmere's greatest colossus. The Heartroot grew through it, and its chest holds the sap-heart. Its dais is where the root system converges.

### Ambient life (client-only, purely cosmetic)

Fireflies near water and lily beds, drifting pollen motes in light shafts, butterflies over sunbells, dragonflies over pools, birds crossing the canopy (a few flat-card silhouettes on a path), and occasional falling leaves. Everything is client-side, pooled, culled by distance, and scaled by the Graphics quality setting (`SettingsGraphicsEngine`). Nothing ambient replicates from the server.

---

## Part 2: Five floors, five shapes

Coordinates are **local floor space**, as in `TowerLayout`: +X is east, **+Z is south** (the Sanctuary side), −Z is north (the Apex side). Y is the walkable top surface. Footprints, height bands and mob totals stay as in GDD §3.3. The positions and sizes below are **starting values**: tune them until every contract assert passes, and keep the shape and intent.

**Fixed on every floor:**

- `Sanctuary` stays at `(0, 8, Depth/2 − 34)`, 128 × 56, with `CombatSafe`, `CanBankCargo` and `CanRecoverWipe`, its four portals and its exit lane. The arrival experience doesn't change.
- An `APEX` platform at the north end holds the Alpha or Boss summon and the boss portal spots at its back. It is at least 100 × 80 (Floor 5: larger, see below).
- The arrival area just below the Sanctuary ramp stays clear of camps, so arrivals land out of aggro.
- Mob totals and Elite counts are unchanged: **16 / 22 / 25 / 35 / 35** live mobs and **1 / 2 / 3 / 4 / 4** Elites. From Floor 3, at least one Elite camp stands above the entry level.

### Floor 1: Overgrown Threshold (`INTRODUCTION`)

*Footprint 380 × 420 × 130, Y 0 to +12, no chasm. Dawn.*

**Story beat:** the Solmere's front door. A processional avenue runs through a fern hollow to a half-fallen sun-gate. Roots are only starting to crack the paving.

**Shape: a straight processional spine with two side glades.** It's the most readable floor: the player sees the Apex the moment they step out of the Sanctuary.

```
                 N (−Z)
        ┌───────────────────────────┐
        │      [ DAWN GATE ]  Y12   │   Apex: sun-gate on a stepped plinth
        │     /      ‖      \       │
        │ [W GLADE]  ‖  [E GLADE]   │   Glades: low mounds, Y4 / Y6
        │   Y4  \ [AVENUE] /  Y6    │   Avenue: narrow raised causeway, Y3
        │        \   ‖    /         │
        │   ~ PILGRIM HOLLOW  Y0 ~  │   Entry: wide fern hollow
        │            ‖              │
        │      [ SANCTUARY ]  Y8    │
        └───────────────────────────┘
                 S (+Z)
```

| Platform | Role | Centre (X, Y, Z) | Size (W × D) | Character |
| --- | --- | --- | --- | --- |
| `Sanctuary` | SANCTUARY | 0, 8, 176 | 128 × 56 | The toppled outer gate, laid flat as a plinth |
| `PilgrimHollow` | ENTRY | 0, 0, 82 | 320 × 92 | Fern hollow, mossy paving, the first glow-lilies |
| `ProcessionalAvenue` | CROSSING | 0, 3, −30 | 52 × 96 | Narrow raised causeway lined with sun-disc stelae |
| `ShrineGladeWest` | WING | −122, 4, −12 | 84 × 76 | Ring of small sun shrines; sunbells |
| `BanyanWellEast` | WING | 124, 6, −24 | 84 × 76 | A banyan grown over a Solmere well |
| `DawnGate` | APEX | 0, 12, −140 | 104 × 80 | Stepped plinth under a cracked sun-gate arch |

**Links:** Sanctuary→Hollow, Hollow→Avenue, Hollow→West glade, Hollow→East glade, Avenue→DawnGate (**STAIRS**, the grand steps), West glade→DawnGate, East glade→Avenue (a side path that rejoins the spine, unlike the generic layout).

**Camps (16, 1 Elite):** `HOLLOW_WEST` 4, `HOLLOW_EAST` 4, `SHRINE_GLADE` 4 (Elite), `BANYAN_WELL` 4. The Avenue stays free: it's the safe "read the room" path.

**Patrol:** `ENTRY_LOOP` along the back third of the Hollow (replaces `BASIN_LOOP`).

**Set pieces:** the cracked **Dawn Gate** (sun-disc keystone with a glowing core, and a light shaft through the crack); the **Carved Deity Head** and **Lion Guardian** already in `TowerBiomeAssets`, moved onto the Hollow flanks; a column of six stelae down the Avenue, two fallen across the fern beds (off the lane).

**Ecosystem weight:** forest floor and stone. Light canopy, so the sky is visible.

### Floor 2: Broken Aqueduct (`EXPANDED_ENCOUNTER`)

*Footprint 420 × 470 × 140, Y 0 to +14, no chasm. Bright morning.*

**Story beat:** the Solmere fed their temples with an aqueduct. It snapped, the water spilled into a reed pond, and the feeder roots of the Heartroot found it.

**Shape: asymmetric diagonal.** The aqueduct runs from the south-east up to a spring in the north-west, so the Apex sits **off-centre to the west**. The aqueduct is broken mid-span: the deck route forces a detour through the Mill Ruin.

```
                 N (−Z)
        ┌───────────────────────────────┐
        │ [ WELLHEAD SHRINE ] Y14       │   Apex, off-centre west
        │      \          \             │
        │ [CISTERN]   [AQUEDUCT N]≈≈gap │   broken span: no link across
        │  Y6     \        |      \     │
        │          \  [AQUEDUCT S] [MILL RUIN] Y4
        │           \    Y10     /      │
        │    ~~~ MILL POND  Y0 ~~~      │   Entry: reed pond with stone pads
        │              ‖                │
        │        [ SANCTUARY ] Y8       │
        └───────────────────────────────┘
```

| Platform | Role | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `MillPond` | ENTRY | 0, 0, 112 | 360 × 100 | Reed pond. The walk surface is stone and packed earth; the cosmetic water sits in recessed beds off the lanes |
| `CisternPlaza` | WING | −140, 6, 8 | 92 × 80 | Open cistern ruin with dry steps, moss on every ledge |
| `AqueductSouth` | CROSSING | 64, 10, 10 | 60 × 70 | Top of the aqueduct; the arches below |
| `AqueductNorth` | WING | 40, 12, −92 | 56 × 64 | The far span. Reached only from the Mill |
| `MillRuin` | WING | 160, 4, −50 | 84 × 76 | Waterwheel ruin, roots through the wheel |
| `WellheadShrine` | APEX | −56, 14, −168 | 104 × 80 | The spring: a sun-disc fountain, the source of the stream |

**Links:** Sanctuary→Pond, Pond→Cistern, Pond→AqueductSouth (a ramp up an arch pier), Pond→Mill, Mill→AqueductNorth, AqueductNorth→Wellhead, Cistern→Wellhead. **There is no link between AqueductSouth and AqueductNorth**: the broken span is the floor's signature, and players see the gap from both sides.

**Camps (22, 2 Elites):** `POND_WEST` 4, `POND_EAST` 4, `CISTERN` 5 (Elite), `AQUEDUCT` 4, `MILL` 5 (Elite).

**Patrol:** `ENTRY_LOOP` along the north shore of the pond.

**Set pieces:** a run of 8–10 aqueduct arches crossing the floor diagonally, with the broken span hanging over a small fall; the stream that leaves the Wellhead, goes under the Cistern and drops into the pond (cosmetic, in a recessed channel that never cuts a lane); feeder roots wrapping two arches and drinking from the channel; the Mill's broken waterwheel.

**Ecosystem weight:** water and stone, with more birds and dragonflies.

### Floor 3: Rootway Crossing (`TERRAIN_VARIATION`)

*Footprint 460 × 520 × 155, Y −4 to +18, chasm (`Bottom = −4`). Noon, with strong light shafts.*

**Story beat:** a river cut a gorge across the floor, and the Heartroot's main roots bridged it. The Solmere built on the roots rather than fighting them.

**Shape: an east–west gorge** crossed by three root bridges at different heights. The gorge splits the floor into a south bank and a north bank. This is the first floor where falling (into the gorge) is possible, so the return ramps matter.

```
                 N (−Z)
        ┌───────────────────────────────────┐
        │        [ ROOT-THRONE ] Y18        │   Apex on the north bank
        │      /        ‖         \         │
        │ [ROOT PERCH]  ‖    [HOLLOW STUMP] │   W: on a root arch Y10 / E: felled giant Y6
        │ ≈≈≈≈≈≈≈≈≈ [THE KNOT] Y5 ≈≈≈≈≈≈≈≈≈ │   gorge: river at Bottom−4, Knot = tangle island
        │ ≈≈≈≈ /         ‖          \ ≈≈≈≈ │
        │   ~ FERN BANK  Y0 (south) ~       │   Entry; return ramps from the gorge floor
        │               ‖                   │
        │         [ SANCTUARY ] Y8          │
        └───────────────────────────────────┘
```

| Platform | Role | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `FernBank` | ENTRY | 0, 0, 124 | 400 × 108 | South bank; ferns down to the gorge lip |
| `TheKnot` | CROSSING | 0, 5, 0 | 74 × 60 | An island where three roots tangle mid-gorge |
| `RootPerch` | WING | −150, 10, −14 | 84 × 76 | A platform on a root arch above the west fall |
| `HollowStump` | WING | 152, 6, −34 | 84 × 76 | The cut top of a fallen giant tree, its rings visible |
| `RootThrone` | APEX | 0, 18, −182 | 104 × 80 | Solmere throne carved into a root buttress |

**Links:** Sanctuary→FernBank; FernBank→TheKnot (the **Great Root**: a root-shaped ramp deck); FernBank→RootPerch; FernBank→HollowStump; TheKnot→RootThrone (**STAIRS** cut into the root); RootPerch→RootThrone; HollowStump→RootThrone. Two **return ramps** rise from the gorge floor to FernBank (today's `ChasmWest` / `ChasmEast`, now authored against the `ENTRY` platform, not `Basin`).

**Camps (25, 3 Elites, at least one above the entry level):** `BANK_WEST` 5, `BANK_EAST` 5, `KNOT` 5 (Elite), `ROOT_PERCH` 5 (Elite), `HOLLOW_STUMP` 5 (Elite).

**Patrols:** `ENTRY_LOOP` on the north half of the Fern Bank; `ROOTWAY_WEST` (RootPerch → its link → RootThrone); `ROOTWAY_EAST` (HollowStump → its link → RootThrone).

**Set pieces:** the river along the gorge floor with a 40-stud waterfall off the west cliff (facing away from the ramps); the three root bridges as giant curved roots with sap veins that glow on their undersides; Solmere stairs and lanterns built *onto* the roots; light shafts through the canopy gap over the Knot; glow-lily rafts in the river.

**Ecosystem weight:** canopy and roots. This is the floor where the Heartroot becomes visible.

### Floor 4: Vinebound Bastion (`ELITE_STRONGHOLD`)

*Footprint 510 × 580 × 170, Y −4 to +22, chasm (`Bottom = −4`). Overcast and humid late afternoon, low mist.*

**Story beat:** the Solmere's fortress-temple, strangled by the Heartroot's vines. The vines tore a breach in the curtain wall and crushed the gatehouse. The towers still stand, and the guardians inside became Vinebound.

**Shape: a walled compound.** An outer ward with a marshy moat sits outside a curtain wall, and you go *through* a breached gatehouse into an inner ward with two towers and the keep. It's a ring rather than a fan: the wall-walks let squads flank between the barracks and the shrine.

```
                    N (−Z)
        ┌──────────────────────────────────────┐
        │ [W TOWER] Y14 ── [ INNER KEEP ] Y22 ── [E TOWER] Y16
        │     ‖                                     ‖
        │ [BARRACKS] Y8 ══ wall-walk ══ [SUN SHRINE] Y8
        │       \          [GATEHOUSE] Y5      /    │   the breach, choked by a strangler fig
        │ ≈≈ moat ≈≈≈≈≈≈≈≈≈≈≈ ‖ ≈≈≈≈≈≈≈≈≈≈≈ moat ≈≈ │   chasm, Bottom−4
        │    ~~ OUTER WARD (marsh meadow) Y0 ~~     │   Entry; return ramps from the moat
        │                    ‖                      │
        │              [ SANCTUARY ] Y8             │
        └──────────────────────────────────────────┘
```

| Platform | Role | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `OuterWard` | ENTRY | 0, 0, 150 | 440 × 118 | Marsh meadow, reeds, toppled wall blocks |
| `Gatehouse` | CROSSING | 0, 5, 48 | 74 × 60 | The burst gate, a strangler fig through its arch |
| `Barracks` | WING | −158, 8, 18 | 86 × 78 | Roofless barracks; racks of mossy stone spears |
| `SunShrine` | WING | 158, 8, 6 | 86 × 78 | Open-air shrine with a cracked sun-disc altar |
| `WestTower` | UPPER_WING | −152, 14, −140 | 84 × 76 | Vine-wrapped round tower, top floor open to the sky |
| `EastTower` | UPPER_WING | 152, 16, −150 | 84 × 76 | Leaning tower, held up by the vines that broke it |
| `InnerKeep` | APEX | 0, 22, −198 | 104 × 80 | Keep courtyard, the roof gone, vines as a ceiling |

**Links:** Sanctuary→OuterWard; OuterWard→Gatehouse; OuterWard→Barracks; OuterWard→SunShrine; Gatehouse→Barracks (west **wall-walk**); Gatehouse→SunShrine (east wall-walk); Barracks→WestTower; SunShrine→EastTower; WestTower→InnerKeep; EastTower→InnerKeep; Gatehouse→InnerKeep (**STAIRS**, the processional climb through the inner ward). Two return ramps from the moat floor to the OuterWard.

**Camps (35, 4 Elites):** `WARD_WEST` 5, `WARD_EAST` 5, `GATEHOUSE` 5, `BARRACKS` 5 (Elite), `SUN_SHRINE` 5 (Elite), `WEST_TOWER` 5 (Elite), `EAST_TOWER` 5 (Elite). The runtime still picks which camps the Elites lead (`CampRoster`); the flags only fix the count.

**Patrols:** `ENTRY_LOOP` (the moat-side edge of the Outer Ward), `WALL_WALK` (Barracks → Gatehouse → SunShrine, the floor's signature route), `TOWER_RING` (WestTower → Keep edge → EastTower, replacing `BASTION_RING`).

**Set pieces:** the curtain wall as a long crenellated line with three collapsed gaps; the strangler fig bursting through the gatehouse arch; vine "cables" between the towers and the keep (sagging, grounded at both ends); half-swallowed guardian statues in Vinebound poses at the gate; a moat of still green water with lily pads and mist.

**Ecosystem weight:** vines, stone and mist. Fewer flowers, more threat.

### Floor 5: Mossbound Court (`BOSS_ARENA`)

*Footprint 560 × 640 × 190, Y −6 to +28, chasm (`Bottom = −6`). Golden hour fading to dusk, with every glow-lily open.*

**Story beat:** the Solmere's holiest court, built round a cenote at the crown of the Heartroot. The Mossbound Guardian kneels on the dais with the sap-heart glowing in its chest. Every root on every floor below runs here.

**Shape: a spiral ascent around a cenote.** A great sinkhole fills the middle of the floor. Terraces climb round it in a ring (west side and east side), meet at the north, and the Sunbridge island in the cenote gives a direct but exposed route. The arena is the largest flat space in the biome.

```
                       N (−Z)
        ┌──────────────────────────────────────────┐
        │            [ MOSSBOUND DAIS ] Y28         │   Apex: 140 × 110, under a broken dome
        │          /          ‖          \          │
        │ [NW TIER] Y14       ‖        [NE TIER] Y16 │
        │     ‖        ≈≈≈ CENOTE ≈≈≈       ‖       │   chasm Bottom−6, falls pour in
        │ [W TERRACE] Y6  [SUNBRIDGE] Y5  [E TERRACE] Y8
        │        \            ‖             /       │
        │     ~~~ CENOTE RIM (south)  Y0 ~~~        │   Entry; return ramps from the cenote floor
        │                     ‖                     │
        │               [ SANCTUARY ] Y8            │
        └──────────────────────────────────────────┘
```

| Platform | Role | Centre (X, Y, Z) | Size | Character |
| --- | --- | --- | --- | --- |
| `CenoteRim` | ENTRY | 0, 0, 176 | 480 × 108 | Mossy rim terrace looking down into the sinkhole |
| `Sunbridge` | CROSSING | 0, 5, 40 | 74 × 60 | Island pillar in the cenote with a sun-disc mosaic floor |
| `WestTerrace` | WING | −176, 6, 36 | 86 × 80 | First spiral tier; glow-lily beds |
| `EastTerrace` | WING | 176, 8, 26 | 86 × 80 | First spiral tier; sunbell garden |
| `NorthwestTier` | UPPER_WING | −160, 14, −118 | 86 × 80 | Colonnade tier with roots through every column |
| `NortheastTier` | UPPER_WING | 162, 16, −126 | 86 × 80 | Colonnade tier with a hanging moss curtain |
| `MossboundDais` | APEX | 0, 28, −222 | 140 × 110 | The boss arena: open dais, broken dome above, Heartroot heart behind |

**Links:** Sanctuary→Rim; Rim→Sunbridge; Rim→WestTerrace; Rim→EastTerrace; WestTerrace→NorthwestTier; EastTerrace→NortheastTier; NorthwestTier→Dais; NortheastTier→Dais; Sunbridge→Dais (**STAIRS**, the long exposed climb). Two return ramps from the cenote floor to the Rim.

**Camps (35 + Boss, 4 Elites):** `RIM_WEST` 5, `RIM_EAST` 5, `SUNBRIDGE` 5, `WEST_TERRACE` 5, `EAST_TERRACE` 5, `NW_TIER` 5 (Elite), `NE_TIER` 5 (Elite), plus the Boss summon on the Dais (95-stud leash; the dais must fit the leash and the boss's `Frontal Cleave`, `Quake` and `Root Bloom` telegraphs without them spilling onto a ramp). Elite flags on two other camps of your choice to reach 4.

**Patrols:** `ENTRY_LOOP` (the Rim's cenote edge), `SPIRAL_WEST` and `SPIRAL_EAST` (terrace → tier), `CROWN_RING` (NW Tier → Dais edge → NE Tier).

**Set pieces:** the cenote with four falls pouring in from the court edges and mist rising from its floor; the **Heartroot heart**: the trunk rising behind the dais, with root buttresses converging on it and a slow sap pulse (a cheap Neon beat, not particles); the broken dome as a ring of arches with the canopy growing through; a light shaft onto the dais that turns gold, then emerald as dusk falls; sun-disc mosaics on every tier floor.

**Ecosystem weight:** everything at once, at its most alive. This is the postcard floor.

---

## Part 3: Environment and lighting per floor

There's no per-floor lighting today. Add a small client-side controller (for example `StarterPlayerScripts/Rendering/TowerFloorEnvironment.luau`) that applies a **preset from shared config** when the local player enters a tower floor and restores the previous `Lighting` state when they leave. Find how the client already knows its current floor (`TowerController` or a player attribute) and reuse that; add no new remote. Tween the change over about 1.5 s. Respect the Graphics quality setting.

Put the presets in a new `--!strict` config module, for example `Shared/Config/TowerFloorEnvironments.luau`, keyed by floor ID, with a fallback for floors that have none.

| Floor | Time of day | Light | Atmosphere | Accents |
| --- | --- | --- | --- | --- |
| 1 | Dawn (`ClockTime` ≈ 6.5) | Low, warm gold from the east | Light ground mist, high haze | Glow-lilies just closing; one shaft through the Dawn Gate |
| 2 | Morning (≈ 9) | Bright, clean, slightly cool | Clear; spray haze at the falls | Sparkle on the pond; birds |
| 3 | Noon (≈ 12) | Overhead and hard | Moderate haze in the gorge only | Strong shafts over the Knot; pollen motes |
| 4 | Overcast afternoon (≈ 16) | Soft and grey-green | Dense low mist on the moat | Few flowers; torches in the towers |
| 5 | Golden hour to dusk (≈ 18) | Long gold light, then emerald glow | Mist from the cenote | Every glow-lily open; fireflies; sap pulse |

Keep the biome's existing palette (`TowerBiomeAssets` theme and `TowerController` biome colours) as the base. Lighting changes the mood, not the identity.

---

## Part 4: Engineering — making layouts per floor without breaking the tower

This is the hard part. Do it first, prove it with the **current** generic layout, and only then author the Verdant floors.

### 4.1 One layout per floor, the same contract

1. Keep the link geometry in one place. The `link()` maths in `TowerLayout.Get` (inset to the slab edge, keep the inclined deck outside the upper terrace's shoulders, extend short links at the lower end, ≤ 15° slope, `Width = 28`, full-width landings) must be shared by authored layouts. Extract it into a function that takes **authored data** (platforms with roles, link pairs, camps, patrols, return links, set-piece anchors) and returns the existing layout table.
2. Add `TowerLayout.ForFloor(floorId)` that returns the authored layout for Verdant floors 1–5 and falls back to the generic `Get(IndexInBiome)` for every other floor. Put the Verdant data in its own `--!strict` module (for example `Shared/Config/TowerLayouts/VerdantRuins.luau`), tab-indented like the other config files.
3. Every layout gets a stable `Key` (for example `"verdant:1"` or `"generic:3"`). Use it as the cache key everywhere a layout or graph is cached.
4. Add `Role` to every platform: `SANCTUARY`, `ENTRY`, `CROSSING`, `WING`, `UPPER_WING`, `APEX`. Code that used to look up `Basin`, `Crossing`, `WestGallery` or `Apex` by name looks up the role instead. The generic layout gets roles too (`Basin` → `ENTRY`, Galleries → `WING`, Bastions → `UPPER_WING`).
5. Let authored links set `Kind = "STAIRS"` explicitly (today only `Crossing → Apex` is stairs, by name).
6. Make `PortalSpots` relative to the Apex's centre (the Floor 2 Apex is off-centre), and `Lanes` derive the entry causeway from the `ENTRY` platform and the Sanctuary link.
7. Patrol routes become authored data per layout. The generic layout keeps `BASIN_LOOP`, `GALLERY_*` and `BASTION_RING` as today. Authored layouts use their own IDs, and the runtime's "always run the entry loop" rule keys on a flag (for example `Always = true`), not the string `"BASIN_LOOP"`.

### 4.2 Move every consumer from `IndexInBiome` to `floorId`

These call sites read a layout by biome index today. Each must call `ForFloor(floorId)` (or receive the layout) instead, and caches must key on the layout's `Key`:

- `TowerRoomBuilder.luau` (build, lanes, placements)
- `TowerBiomeAssets.luau` (lanes, the `Basin` / `WestGallery` / `Crossing` / `Apex` lookups around lines 600 and 1147, the hard-coded Verdant set-piece offsets)
- `HeroNavigation.luau` and `SquadMovement.luau` (graph caches keyed by index)
- `CombatSimulation.server.luau` (layout and `Platforms.Basin`; portal spots)
- `TowerEncounterRuntime.luau` (layouts, `Platforms.Basin` / `Crossing` / `Apex`, patrol routes, `"BASIN_LOOP"`)
- `TowerEventService.server.luau` (Relic Rain lands on `Links`)
- `CampWaves.luau`, `FirstBiomeCombat.luau`, `TowerFloorConfig.luau` (placements)

Grep again for `Layout.Get(`, `.Platforms.`, `IndexInBiome` and every camp and patrol ID before you call this done. Don't trust this list to be complete.

### 4.3 Scenery

- Move the Verdant set pieces out of the generic biome branch into a Verdant builder that places them from the layout's **set-piece anchors** (named points authored with each floor), not from offsets relative to `WestGallery` and `Basin`.
- Keep every existing scenery rule: **grounded clutter** (nothing floats; compound props are Models tagged `PropKind`), **clear walkways** (`TowerLayout.Lanes` plus a 3-stud shoulder), **camp clearance**, **chasm groves** (Verdant set: canopy trees and ivy-wrapped columns), and **waterfalls facing away from ramps**.
- Water is cosmetic. Recessed channels and pools sit under or beside walk surfaces and are never part of a lane. Nothing in this change adds a hazard or a swim state.
- Native parts only, no external asset IDs, matching the existing kits.

### 4.4 Budgets

- Before changing anything, measure the current Verdant floors in Studio: part count, light count and active particle emitters per floor. Write the baseline into the PR description.
- Each new floor stays within **+25% parts** of its baseline, **≤ 24 local lights**, and **≤ 12 active particle emitters**, not counting client ambient life.
- Ambient life is pooled and capped (for example ≤ 40 fireflies and ≤ 6 birds on screen at High quality), and off at the lowest quality.
- Rooms still fit the 2,400-stud origin spacing; footprints stay as in GDD §3.3.

### 4.5 Data and saves

The layout is not saved. No profile schema change and no `DataManager.SyncProfile` migration are needed. If you find otherwise, stop and say so.

---

## Part 5: Process, tests and docs

### Phases and the review gate

1. **Contract refactor.** Do §4.1–4.2 with only the generic layouts. All tests must pass with **no visible change** in Studio. Commit: `refactor(tower): resolve floor layouts per floor with role-tagged platforms`.
2. **Design gate.** Before building any geometry, show the user, for each Verdant floor: the final coordinate table, an ASCII top-down map with links, camps and patrols marked, the height of every link and its slope, and the list of set pieces. **Stop and wait for sign-off.**
3. **Floors 1–5.** Author and build one floor at a time, lowest first. Commit each: `feat(tower): author Verdant floor N (<name>) layout`.
4. **Environment.** Lighting presets and ambient life. Commit: `feat(tower): per-floor environment for Verdant Ruins`.
5. **Docs and tests**, then open the PR against `main`.

### Tests

Run the suite with the local Luau CLI:

```bash
pwsh tests/run.ps1 -LuauDirectory D:/luau
```

Never pass `-InstallLuau`. Extend the specs so they loop over **floor IDs** (all 50), not just indices 1–5:

- `tower-rework.spec.luau`: every link ≤ 15°, stairs rise ≤ 1.0 stud, landings flush, no lane crosses a non-linked platform, every non-Sanctuary platform reachable from the Sanctuary.
- `tower-navigation.spec.luau`: the graph routes Sanctuary → Apex on every floor, and every camp's platform is reachable.
- `tower-camp-roster.spec.luau` and `tower-run-loop.spec.luau`: mob totals and Elite counts per floor as above; from Floor 3, at least one Elite camp above the entry level; the arrival area clear.
- `tower-patrols.spec.luau`: every route point lies on a platform or link; no route uses the Sanctuary link; exactly one `Always` route per floor.
- `tower-portals.spec.luau`: portal spots on the Apex, inside it, and in the lanes.
- Add a spec asserting that floors 6–50 produce **byte-for-byte the same layout as before** (snapshot the generic output before the refactor).

Then run `tests/studio-tower-prop-audit.luau` in Studio for all 50 floors: orphaned props, floating props and props on walkways must all be **0**.

### Docs (same PR)

- `docs/GAME_DESIGN.MD` §3.3: say that layouts resolve per floor, describe the five Verdant floors (shape, platforms, camps, patrols, environment) and the Solmere/Heartroot ecosystem, and note that biomes 2–10 still use the generic variants.
- `docs/TOWER_NAVIGATION.md`: platform roles, `ForFloor`, layout `Key` caching, authored patrols.
- `reference/infinite_towers_biomes.md` §1: add a short paragraph on the Solmere and the Heartroot.

### Finish with a Studio checklist for the user

Don't run the playtest yourself. End with a **How to test** checklist the user can follow in Studio, covering at least:

1. Floors 1–5: arrive, check you land out of aggro, and walk to the Apex by every route.
2. Floor 2: confirm the aqueduct gap has no link and the Mill detour works.
3. Floors 3–5: jump into the chasm, and climb out by a return ramp.
4. Squad follow, recall (`E`) and assigned-squad routing on ramps, stairs and wall-walks.
5. Patrols walk their routes and leash back.
6. Floor 5 boss: summon it, check the telegraphs stay on the dais, kill it, check Ascend and Rerun portals.
7. Relic Rain lands on Verdant ramps (force with `workspace.TowerEventForce = "RELIC_RAIN"`).
8. Lighting changes on entering each floor and restores on returning to the hub.
9. Floor 6 and Floor 11 look and play exactly as before.
10. Frame rate on a low-end device setting, compared with the baseline.

## Out of scope

- Biomes 2–10 (they come later, using the same contract).
- New enemies, new boss mechanics, hazards, swimming or terrain voxels.
- Changes to rewards, relic drops, mob stats or camp respawn timing.
