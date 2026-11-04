# Tower content pass: implementation plan

Status: proposal, nothing implemented yet. Written 2026-11-04 on `feat/astrea-remodel` (move to its own branch before starting).

## 0. What I found

I built 13 floors in Studio (Edit mode, then removed them). That covered all 5 layouts of Verdant Ruins and one floor from each of the other 9 biomes. Then I audited every `BiomeAssets` part.

### 0.1 Hallucinated trees and pillars (orphaned prop pieces)

A prop counted as orphaned when its anchor piece was missing within about 40 studs: a tree trunk, spire shaft, mushroom stem or arch pier.

| Floor | Biome | Orphaned pieces |
| --- | --- | --- |
| 1 | verdant_ruins | Tree 23, Arch 11 |
| 3 | verdant_ruins | Tree 95, Spire 4, Arch 2 |
| 5 | verdant_ruins | Tree 228, Spire 4, Arch 7 |
| 8 | fungal_hollow | Mushroom 18, Arch 4 |
| 19 | frozen_citadel | Spire 38, Arch 8 |
| 24 | infernal_foundry | Spire 106 |
| 35 | corrupted_grove | Tree 201, Arch 10 |
| 48 | abyssal_throne | Spire 108 |

**Root cause.** Props are built from loose parts with no grouping. Two cleanup passes then delete single parts, not whole props:

1. `TowerBiomeAssets.luau:997-1043` (camp clearance) deletes any part within 34 studs of a camp and between -2 and +22 studs high. Trunks, stems and plinths fall inside that box, but canopies, caps and spire tops sit higher and survive. The result is floating foliage, mushroom caps without stems and spire peaks hovering in the air.
2. `TowerRoomBuilder.luau:620-645` (lane clearance) deletes any part tagged `SolidScenery` that touches a ramp or a camp. `SpireShaft`, `SpirePlinth`, `SpireUpperTier` and `ArchPier` are solid, so they get removed. Their non-solid `SpirePeakFacet`, `SpireRune*`, `ArchVoussoir` and `ArchPierCap` pieces stay behind, floating.

**Placement problems.** These also produce wrong-looking trees and pillars:

- `populateLandmark` on the north horizon places props at `bottom + peakH * 0.55`, which is inside the cliff face rather than on a ledge (`TowerBiomeAssets.luau:471`).
- Courtyard landmarks sit at `basin.Width * 0.44`, the same X as `BasinWingElementalPool`, so trees grow out of the pools (`:561-575`).
- `tree()` leans its trunk up to 4.5 studs and spreads its boughs 22 studs. On narrow island crowns and cliff ledges, the canopy and roots hang over empty air.

GDD §5 (line 234) already describes the intended fix: the "grounded clutter rule" and `PropGroup` models whose props are cleared together with their support. The code never implemented it.

### 0.2 Shrubs and clutter on pathways

The audit counted visible props inside a ramp or stair corridor (link width + 4 studs):

| Floor | Props on ramps | Main offenders |
| --- | --- | --- |
| 1 | 30 | FoliageBush ×18, FallenColumnDrum ×6 |
| 8 | 107 | SporeCap / SporeStalk / SporeRingGlow |
| 24 | 106 | DiscardedCogRim ×74, SlagHeap ×18 |
| 35 | 108 | BlightThornLoop ×89, BlightRootRot ×19 |
| 19 | 69 | IceCrystalSpike, SnowdriftMound |

**Sources** (all in `TowerBiomeAssets.luau`):

- `:959-975` deliberately places clutter at `link.Width/2 + 3.2` on both sides of every ramp, at 25% and 75% of its length. With clutter radius around 4–6 studs, that clutter spills onto the walkway.
- `:945-957`: the inner Basin clutter line at `x = ±22–28` sits on the walkable Basin, next to the 34-wide causeway.
- `:989-995`: Sanctuary gateway clutter at `x = ±18 / ±28`, `safe.Z - 20` sits in the arrival exit lane.
- `:977-987`: gallery corner clutter lands where ramps arrive on the galleries.
- Waterfalls (`CascadingFall`, `FallFoamCore`) from the inner chasm islands cut across ramp corridors on floors 2, 3, 8, 13 and 42.

None of this clutter collides, because it is `CanCollide=false`, so the only problem is how it looks. The existing clearance pass only checks `SolidScenery`, so it never removes any of it.

### 0.3 Current spawn mechanic

- `TowerLayout.Placements` (`TowerLayout.luau:72-86`) gives each camp a fixed pattern: slot 1 is the Elite (in Elite-led camps), then the camp alternates `RegularEnemyIds[1]` and `[2]` by slot parity. The 5 positions come from fixed offsets `{0,0},{-18,12},{18,12},{-12,-16},{12,-16}`.
- Which camps are Elite-led is hard-coded per layout (`camp(..., elite, ...)` in `TowerLayout.luau:63-70`). For example, `WEST_GALLERY` always has the Elite on every floor, and on floors 4–5 so do both Bastions.
- `FirstBiomeCombat.Floors[floorId]` is computed once at load, so every floor has the same mix of the same two Regulars in the same places, every wave, forever.
- `TowerEncounterRuntime:SyncRooms` respawns a camp's slots at the same `HomePosition` with the same `EnemyId`.
- `CampWaves.EffectivePlacements` adds multi-Master extras round-robin across the camp's Regular ids.

---

## 1. Phase A: fix orphaned props (trees and pillars)

**Goal:** a prop is either whole or absent. No prop floats or sticks into rock.

1. **Introduce prop groups.** Every compound builder in `TowerBiomeAssets` (`tree`, `mushroom`, `spire`, `arch`, `statue`, `libraryWing`, `cogwheel`, `chain`, `waterfall` and every `*Clutter`) creates a `Model` named after the prop, with attributes `PropKind`, `PropFootprint` (XZ radius) and `PropSupport` (terrace id or `"CHASM"`, `"CLIFF"`, `"ISLAND"`). Each builder's `block`/`orb`/`beam` calls parent into that model. Implementation: give `block()` a current-parent upvalue that the builders push and pop, or pass `parent` explicitly.
2. **Clear by group.** Rewrite both clearance passes to iterate prop `Model`s and test the group's bounding box (`GetBoundingBox`) plus footprint against the clearance volumes. Destroy the whole model on a hit. Delete the per-part loops at `TowerBiomeAssets.luau:997-1043` and `TowerRoomBuilder.luau:620-645`, and replace them with one shared `PropClearance` module (see Phase B), so both passes use the same volumes.
3. **Ground everything.** Add `groundAt(xz, maxDrop)`. It raycasts against an include-list of registered supports (terrace slabs, island crowns, cliff ledges, the Ground slab) and returns the top Y. If no support lies under the full footprint, drop the prop.
   - Horizon landmarks: place them on the top of `NorthHorizonFoothill` (the shelf) instead of `peakH * 0.55`.
   - Cliff ridge landmarks: place them on the top of `PerimeterCliffLedge`.
4. **Fix the known misplacements.**
   - Move courtyard landmarks from `basin.Width * 0.44` to `* 0.38`, or move the wing pools outward. One or the other has to move.
   - Clamp `tree()` lean and bough reach to the support's footprint, or use a compact tree variant (`tScale` capped so the root spread stays at or under the support half-width) on islands and ledges.
5. **Audit and guard.** Add `tests/tower-props.spec.luau`, or a Studio script `tests/studio-tower-prop-audit.luau` if the builder cannot run outside Studio. It builds every floor, and then:
   - asserts that every prop `Model` that has an anchor part (trunk, shaft, stem, pier) still has it;
   - asserts that no prop's bounding-box bottom sits more than 1 stud above its support's top;
   - prints the orphan count per floor (target 0).

## 2. Phase B: clear pathways

**Goal:** no visible prop stands inside a walkable lane: ramps, stairs, the causeway, the Sanctuary exit, or ramp landings.

1. **One source of lane geometry.** Add `TowerLayout.Lanes(index)`, which returns oriented boxes for:
   - every `Link` (width + 6 studs of shoulder, from 2 studs below to 14 studs above the surface);
   - the Basin causeway (40 wide);
   - the Sanctuary exit (from `safe.Z - 28` to the Basin ramp head, 36 wide);
   - a 20×20 landing pad at each end of every link.

   Both builders and the prop-audit spec use this table.
2. **Stop placing clutter on lanes.**
   - Remove the ramp-curb clutter loop (`TowerBiomeAssets.luau:959-975`). Replace it with clutter just outside the curbs (`link.Width/2 + 6 + footprint`), and only where a support exists below. That is usually the chasm floor, not the ramp.
   - Push the inner Basin clutter line from `±22–28` out to at least `±(20 + 4 + footprint)`, and run it through the lane check.
   - Move the Sanctuary gateway clutter out of the exit lane, to `x = ±34` or more, beside the pillars.
   - Move gallery corner clutter off the corner where a ramp lands (check against the landing pads).
   - Rotate or shift chasm-island waterfalls so they fall on the side away from the central ramps. Waterfalls are prop groups too, so the lane check removes the whole fall, foam and mist together.
3. **Single clearance pass.** Run `PropClearance.Apply(kit, lanes, campAreas)` once, after `BiomeAssets.Build` and after the room-builder decor is placed. Lanes remove **all** prop groups, solid or not. Camp areas (Phase C) remove only solid groups and anything taller than 3 studs, so low ground cover can stay around camps.
4. **Spec check:** zero visible prop parts intersect any lane box on every floor, and `RampPostLantern`, `BridgeCurb` and `BridgeRuneStrip` are exempt by name.

## 3. Phase C: randomized mob types across spawning areas

**Interpretation, to confirm:** each camp (spawning area) holds **one** Regular type instead of an alternating mix. Which type goes to which area is random, re-rolled when the room is rebuilt and on each camp wave respawn, so a floor never plays the same way twice.

**Elites move too.** The layout no longer fixes which camps are Elite-led. It fixes only how many Elites a floor has: 1 / 2 / 3 / 4 / 4 on floors 1–5 of a biome, as today. The runtime picks which spawning areas get an Elite leader when the room is built, and picks again whenever that camp's wave respawns. Total Elites per floor, and so the kill-point budget, stays the same. The Apex Sanctum is never a candidate, because it remains the summon spot for the Alpha or Biome Boss.

### 3.1 Data

- `TowerLayout.Get` gives each camp a `SpawnArea = { X, Y, Z, Radius, Platform }` (radius 22 for 4–5 member camps, 28 on Bastions) in place of the implicit fixed offsets.
- `TowerLayout.Get` drops the per-camp `Elite` flag. It returns `EliteCount` (1 / 2 / 3 / 4 / 4) and marks each camp `EliteEligible`: every live camp except `APEX_SANCTUM`. The Bastions on floors 4–5 are eligible like any other area.
- `TowerLayout.Placements` stops resolving `EnemyId` for live camps. Each placement returns `{ CampId, Slot }`, and slot 1 of each camp is the potential leader. Only the Apex Sanctum and boss placements keep a fixed `EnemyId`. Positions are no longer stored, because the runtime rolls them.
- `MobCatalog.Biomes[i].RegularEnemyIds` stays the pool. Adding a third Regular per biome later (see Improvements) then just works.

### 3.2 New pure module `ReplicatedStorage/Shared/Util/CampRoster.luau` (`--!strict`, no services, specs can run it)

- `CampRoster.AssignTypes(rng, campIds, pool) -> { [campId]: enemyId }` uses a shuffle bag, so every Regular type appears on the floor at least once when there are at least as many camps as types, and no two adjacent camps (by layout order) share a type when that can be avoided.
- `CampRoster.RollPositions(rng, area, count, minSpacing) -> { Vector2 }` uses Poisson-disk-style rejection inside the area circle. `minSpacing` is about 9 studs, there are 30 attempts per point, and it falls back to a ring layout if the attempts run out.
- `CampRoster.RerollType(rng, campId, current, pool, neighbours)` runs on wave respawn. It prefers a type different from `current`.
- `CampRoster.AssignElites(rng, eligibleCampIds, eliteCount) -> { [campId]: true }` picks `eliteCount` distinct camps for an Elite leader. It spreads them out: it avoids two Elites in neighbouring areas when it can, and keeps at least one Elite above Basin level from floor 3 on, so the climb still gets harder near the Apex.
- `CampRoster.MoveElite(rng, campId, eliteCamps, eligible, campAlive)` runs when an Elite-led camp's wave respawns. It moves the Elite to a random eligible camp that has no Elite, and prefers a camp that is currently cleared (waiting to respawn) so the Elite never pops into a fight already in progress. If no such camp exists, the Elite stays put. The camp it leaves gets an ordinary member in slot 1.
- RNG: `Random.new(hash(floorId, roomGeneration, campId, waveNumber))` on the server, so it is deterministic for specs and replays, but still varies per wave.

### 3.3 Runtime (`TowerEncounterRuntime.luau`)

1. On first sync of a room generation, call `AssignTypes` and `AssignElites` once per floor. Store the results in `ledger.CampTypes` and `ledger.EliteCamps`.
2. When an Elite-led camp's wave respawns, call `MoveElite` first and update `ledger.EliteCamps`. The camp that receives the Elite swaps its slot-1 member to the Elite on its own next respawn. A camp that is alive is never changed mid-fight.
3. When a slot is created or a camp wave respawns:
   - resolve `EnemyId`. Slot 1 of a camp in `ledger.EliteCamps` gets the biome's `EliteEnemyId`. Every other slot gets `ledger.CampTypes[campId]`;
   - roll a position with `RollPositions`, ground it with `api.Navigation.Ground`, and reject points that are in `CombatSafe` zones or inside lane boxes;
   - re-apply `TowerFloorConfig.GetEnemyStats` for the new `EnemyId` (MaxHP, ATK, Gold, DisplayName, Role, MobType).
4. **Identity change on respawn.** A slot that changes `EnemyId` must not reuse its old visual. The cleanest option is to allocate a **new NetId** for every member on wave respawn and retire the old one, so the client builds a fresh rig. Verify `EntityRenderer` and the v2 protocol keep rigs by NetId and `EntityGeneration`. If they rebuild on a generation bump, bumping `EntityGeneration` is enough. Check `HeroTargeting`'s cached NetId too. The GDD's Hero Auto-Targeting paragraph already says a hero re-acquires a respawned mob, so a new NetId is safe.
5. `CampWaves.EffectivePlacements`: extras inherit the camp's current type from `ledger.CampTypes` (extras are never Elites), and their positions come from the same `RollPositions` call (count = base + extras), so extras never stack on base members.
6. Surge packs (`SpawnSurge`) stay as they are, but use the `CampRoster` pool so that a third Regular type is supported later.

### 3.4 Knock-on changes

- `TowerRoomBuilder.luau:631`: the clearance points currently come from `Layout.Placements` positions. Switch them to the camp `SpawnArea` circles (Phase B's `PropClearance` takes them as `campAreas`).
- `TowerBiomeAssets.luau:999`: delete the hard-coded `campOffsets`, which the camp areas replace.
- `FirstBiomeCombat.Floors` no longer holds positions. Update `tests/tower-run-loop.spec.luau` and every spec that reads `.X/.Z` from placements.
- **No save-schema change.** All of this is runtime state, so `DataManager.SyncProfile` needs no migration.
- **GDD:** update §2.5 item 1 and the "Multi-Area Spatial Mob Camps" paragraph (line ~237) to say that each spawning area fields one random Regular type per wave, that the floor's Elites (1–4) are assigned to random areas and move between areas as camps respawn, and that positions are scattered inside the area. Update the Floor 4–5 table rows ("2 Elite-led Bastion packs") to match.

### 3.5 Specs (`tests/tower-camp-roster.spec.luau`)

- With 4–7 camps and a pool of 2, every type appears on every floor, across 1,000 seeds.
- No camp is mixed: every MEMBER in a camp shares one `EnemyId`.
- Rolled positions stay inside `Radius`, at least `minSpacing` apart, and outside lane boxes.
- Same seed gives the same assignment. Different `waveNumber` gives a different assignment at least once in N rolls.
- Every floor has exactly `EliteCount` live Elites after any sequence of respawns, never two in one camp, and never one in the Apex Sanctum.
- `MoveElite` never moves an Elite into a camp that is alive (mid-fight), and over 1,000 waves each eligible area hosts an Elite at least once.
- Kill-point and Alpha-threshold math is unchanged (Regular 1, Elite 3), and the per-floor kill-point total per full clear is unchanged.

## 4. Phase D: third Regular, a support type per biome

**Goal:** each biome gets a third Regular that supports its allies rather than fighting. It is fragile and stays behind the line, so it becomes a target players want to kill first. That gives camp fights a decision to make.

### 4.1 Role in camps

- Support is **not** a camp type. Camps stay homogeneous in their fighter type (Phase C). A support **joins** a camp as an extra member: slot 5 of a 5-member camp, or appended to a 4-member camp.
- `CampRoster.AssignSupports(rng, campIds, maxSupports)` gives about 50% of live camps one support, capped at `ceil(camps / 2)`. Floors 1–2 of biome 1 have none, so the tutorial floors stay simple. It re-rolls on each wave, like types and Elites do.
- Supports also join surge packs from biome 3 on (1 Elite, 2 Regulars, 1 support).
- Supports count toward `MaxLiveMobsPerFloor` (48). Extra members for additional Masters are never supports.

### 4.2 Support kits

There are three behaviours. Each biome uses one, so neighbouring biomes feel different.

| Kit | What it does | Numbers (start points for tuning) |
| --- | --- | --- |
| `MEND` | Channels a heal on the ally with the lowest HP% within range | 2.0 s windup, heals 12% of the ally's MaxHP, 7 s cooldown, range 30 |
| `WARD` | Puts a shield on the ally nearest the squad | Shield of 15% of the ally's MaxHP for 6 s, 9 s cooldown, range 26 |
| `ROUSE` | Battle cry: allies within 18 studs get +25% ATK and +20% move speed | Lasts 5 s, 10 s cooldown |

All three are interruptible. Any hero hit during the windup cancels the cast (`CancelReason = "INTERRUPTED"`), which is a reason to bring Strikers and Marksmen. A support never attacks unless no ally is alive, and then it uses a weak projectile (0.5× ATK).

### 4.3 Roster (one per biome)

| Biome | Support | Kit | Rig family to reuse |
| --- | --- | --- | --- |
| Verdant Ruins | Bloom Tender | MEND | `ROOTED_BIPED` (small) |
| Fungal Hollow | Sporecap Chanter | ROUSE | `FUNGAL_BIPED` |
| Ashen Dunes | Ember Oracle | WARD | `CASTER_BIPED` |
| Frozen Citadel | Rime Chaplain | WARD | `CASTER_BIPED` |
| Infernal Foundry | Bellows Imp | ROUSE | `SMALL_BIPED` |
| Thunder Highlands | Squall Herald | ROUSE | `AVIAN` |
| Corrupted Grove | Rot Mender | MEND | `ROOTED_BIPED` |
| Sunken Sanctuary | Tide Cantor | MEND | `CASTER_BIPED` |
| Astral Archives | Glyph Warden | WARD | `CASTER_BIPED` |
| Abyssal Throne | Void Hierophant | MEND | `CASTER_BIPED` |

Every support has a distinctive silhouette element added in `TowerEnemyRigs` (a floating halo, a lantern or a banner pole) and uses the biome palette's `Glow`, so it can be read at a distance.

### 4.4 Implementation

1. **Catalog.** In `MobCatalog`, `biome()` takes a fifth argument. Supports are `Role = "REGULAR"` with `Support = "MEND" | "WARD" | "ROUSE"`. Add `SupportEnemyId` to the biome record, and keep `RegularEnemyIds` for fighters only.
2. **Stats.** In `FirstBiomeCombat`, supports get 0.7× Regular HP, 0.5× ATK, `MoveSpeed` 10 and `AggroRange` 46. Their single move uses a new shape, `ALLY_CAST`, with `TargetRule = "ALLY_SAME_CAMP"`.
3. **Runtime.** A new branch in `TowerEncounterRuntime:Step` handles mobs with `Support`:
   - pick an ally with the kit's rule;
   - keep an 18–24 stud gap behind that ally, away from the nearest hero (a kite step through `Navigation.Step`);
   - start the cast with `Timeline.Start`, targeting the ally.

   `Timeline.Step` already takes the hit callback, so pass one that heals, shields or buffs instead of calling `api.Damage`.
4. **Mob state.** Shields and buffs live on the mob record (`m.Shield`, `m.ShieldUntil`, `m.BuffATK`, `m.BuffUntil`). `api.Damage` on a mob drains the shield first. Cancelling on a hit needs a small hook in the hero-damage path (`CombatSimulation`) that calls `Runtime:Cancel(m, "INTERRUPTED")` when the victim is mid-windup and has `Support`.
5. **Client.** Add an `ALLY_CAST` telegraph in `EnemyAnimationController` (a beam from caster to ally), shield and buff glows on the target, and a "Support" tag on the name plate.
6. **Encounters.** `TowerFloorConfig` currently builds `Encounters` by counting `Layout.Placements` EnemyIds, and `GetEnemyStats` refuses any enemy that isn't listed. With random types, build `Encounters` from the biome pool instead (both fighters, the support, the Elite, the Alpha and the Boss), with **expected** counts. `RecommendedPower` then uses expected counts, so it stays stable.
7. **Rewards.** A support is a Regular for kill points (1) and relic table (`REGULAR`). Optionally give it +50% Gold to reward focusing it.

## 5. Phase E: patrols

**Goal:** some mobs walk the lanes between areas, so the floor feels alive and players can't treat every camp as a static farm.

1. **Routes.** `TowerLayout.PatrolRoutes(index)` returns waypoint loops built from the link centrelines (lane geometry from Phase B). It never uses the Sanctuary link or the Basin centre under the arrival ramp. Examples:
   - `BASIN_LOOP`: Basin West → Crossing ramp foot → Basin East and back (all floors);
   - `GALLERY_WEST` / `GALLERY_EAST`: Gallery ↔ Apex or Bastion ramp (floor 3 on);
   - `BASTION_RING`: West Bastion → Apex edge → East Bastion (floors 4–5).
2. **Count and makeup.** There is 1 patrol on floors 1–2 of a biome and 2 on floors 3–5. Each patrol is 3 members of one fighter type, rolled from the pool like camps are. From biome 4 on, a patrol may carry the floor's support. Patrols use the same `CampRoster` RNG, and their `CampId` is `PATROL_<route>`.
3. **Movement.** A patrol has a moving anchor. `m.HomePosition` becomes the patrol's current waypoint target, which advances at `MoveSpeed × 0.5` (a walk, not a run). Members keep formation offsets around the anchor.
   - When a hero comes within `AggroRange`, the whole patrol engages. The leash is measured from where they engaged, not from a spawn point.
   - On reset, they walk back to the nearest waypoint and resume the loop.
   - Add `PATROL = 25` to the mob `StateEnum` map (`CombatSimulation.server.luau:2366`), and map it to a slow locomotion clip on the client.
4. **Respawn.** A patrol respawns as a group 20 s after it is wiped, at the route's start waypoint, provided no Master is within 40 studs of that point. Otherwise it waits.
5. **Budget.** Patrol members count toward the 48 live-mob cap. If the cap would be exceeded, patrols are the first thing skipped.
6. **Safety.** Patrols never enter `CombatSafe` zones: waypoints are checked against `GetSafety` when the room builds, and any waypoint inside a safe zone is a spec failure.
7. **Specs.** Every route waypoint lies on a lane and outside safe zones. A patrol's anchor completes a loop within its expected time. Patrols respect the live-mob budget.

## 6. Phase F: Elite affixes

**Goal:** an Elite rolls modifiers each time it spawns, so the same Elite in the same area plays differently, and dangerous rolls pay better.

### 6.1 Affix table (new `--!strict` config `Shared/Config/EliteAffixes.luau`)

| Affix | Effect | Counterplay |
| --- | --- | --- |
| `SHIELDED` | Starts with a shield of 30% MaxHP that comes back after 6 s without taking damage | Burst it down; keep pressure on it |
| `HASTED` | +35% move speed, −25% cooldowns | Tank with a Vanguard; kite it |
| `VAMPIRIC` | Heals 35% of the damage it deals | Shields, healing, dodging telegraphs |
| `FRENZIED` | Below 50% HP: +40% ATK, +25% attack speed, glows red | Burst it from 60% down |
| `SPLITTING` | On death, 2 Regulars of the camp's type step out (summoned, never respawn, worth 0 kill points) | Area-of-effect damage |
| `WARDED` | Aura: allies within 18 studs take 25% less damage | Pull the Elite away, or kill it first |
| `COMMANDER` | Aura: allies within 20 studs get +20% ATK | Kill it first |
| `VOLATILE` | On death, a 1.5 s telegraphed 12-stud blast | Back off when it dies |

### 6.2 Rules

- **How many affixes:** biomes 1–2 have a 50% chance of 1. Biomes 3–6 always have 1. Biomes 7–10 always have 2, never a duplicate, and never `SHIELDED` together with `WARDED`.
- **Alphas and Biome Bosses** get 1 affix from floor 26 up, from a boss-safe subset (no `SPLITTING` and no `HASTED`).
- **When rolled:** at spawn and on every respawn, with the seeded `CampRoster` RNG plus the affix pool.
- **Rewards per affix:** +25% to the Elite's relic `Drop` chance and +15% Gold. The tier roll is unchanged, so Abyssal Cores stay Elite-only. Kill points stay at 3, so the boss threshold doesn't move.

### 6.3 Implementation

1. **Pure rules module.** `Shared/Util/AffixRules.luau` holds pure functions (`Roll`, `ModifyOutgoing`, `ModifyIncoming`, `OnDeath`, `RewardMultipliers`) so the specs can test them without Roblox services.
2. **Runtime hooks.**
   - In `TowerEncounterRuntime`, apply the stat affixes when stats are set on spawn.
   - Apply auras in `Tick`, with one radius scan per Elite at 5 Hz.
   - Run death effects from `Death`. `SPLITTING` uses the same summoned-mob path as `SpawnSurge`.
3. **Combat hooks.** In `CombatSimulation`, `api.Damage` (damage to mobs) consults `ModifyIncoming` for the shield and `WARDED`. The mob hit callback consults `ModifyOutgoing` for `VAMPIRIC`, `FRENZIED` and `COMMANDER`. `Reward` multiplies `RelicChance` and Gold by `RewardMultipliers(m.Affixes)`.
4. **Network.**
   - Affix ids go in the entity metadata entry (`EntityMetadataRemote`, which is already per entity and reliable) as `Affixes = { "SHIELDED", ... }`.
   - The live shield fraction goes in the record's Stamina byte, which mobs don't use. Check that the client ignores Stamina for mobs today.
   - No change to the v2 record layout.
5. **Client.** The name plate prefix reads, for example, "Shielded, Frenzied Glacier Knight", with small affix icons. Add a shield bar over the HP bar, a red tint when `FRENZIED` is active, and aura rings for `WARDED` and `COMMANDER`.
6. **Specs** (`tests/tower-affixes.spec.luau`):
   - affix counts by biome;
   - no banned pairs;
   - shield absorbs before HP;
   - `SPLITTING` respects the live-mob budget;
   - reward multipliers apply to Elites only, and Cores stay Elite-only.

## 7. Phase G: timed general events

**Goal:** server-wide events on a timer that change how the tower plays for a few minutes. The main one is "harder mobs, better relics", and every player in the server sees the same event at the same time.

### 7.1 Schedule

- `TowerEventService` (server) runs a cycle: 15 minutes calm, then a 60 s warning banner, then a 5-minute event. The event is picked by weighted random, never the same one twice in a row.
- **Featured biome:** some events apply to the whole tower, others to one featured biome, picked from the biomes that players in this server have unlocked. That pulls the 6 players together for contested-loot play.
- **Newcomer protection:** difficulty-raising events never apply to floors 1–5.
- **Studio testing:** in Studio only, the attribute `workspace.TowerEventForce = "<EventId>"` starts that event's 60 s warning immediately, so the full warning → pop-up → active flow can be tested.

### 7.2 Events (new `--!strict` config `Shared/Config/TowerEventConfig.luau`)

| Event | Scope | Mob modifiers | Reward modifiers |
| --- | --- | --- | --- |
| **Calamity Hour** | Whole tower (floor 6+) | ×1.6 HP, ×1.35 ATK, every Elite +1 affix | Relic `Drop` ×2.0. Tier shift: 30% of Geodes become Urns, 15% of Urns become Cores (Elites only) |
| **Elite Tide** | Featured biome | Every live camp is Elite-led; Elites +1 affix | Core chance ×1.5 |
| **Relic Rain** | Featured biome | None | A relic meteor lands every 30 s at a random lane point on a random floor of the biome. It is contested loot, so normal carry, bank and retaliation rules apply |
| **Swarm** | Whole tower | Camp respawn 10 s → 4 s; +1 member per camp (within budget) | Kill points ×1.5, so bosses get summoned sooner |
| **Golden Tide** | Whole tower | None | Gold ×2; Market multiplier applies on top |
| **Alpha Hunt** | Featured biome | Each floor's Alpha also spawns as a roaming patrol (Phase E route) | Heart chance ×2 on those Alphas |

### 7.3 Rules that prevent exploits

- **Stamp at spawn.** Every mob records `m.EventId` and its modifiers when it spawns. Its stats and rewards come from that stamp, not from the event running when it dies. Mobs spawned during Calamity Hour stay hard and keep paying the bonus after the event ends. Mobs spawned before it never pay the bonus.
- Relic and gold modifiers are applied only on the server, inside `Reward` and `RollRelic`.
- Event state is server-owned. Clients only receive state to display.

### 7.4 Implementation

1. **Config.** `TowerEventConfig` holds the event table: `Id`, `DisplayName`, `Scope`, `Weight`, `MinFloor`, `MobMods`, `RewardMods` and banner text.
2. **Service.** `ServerScriptService/Core/TowerEventService.luau` owns the scheduler loop, the current-event state and `GetModifiers(floorId)`. It publishes state as `ReplicatedStorage` attributes, so late joiners pick it up for free and no RemoteEvent is needed:
   - `TowerEventPhase`: `CALM`, `WARNING` or `ACTIVE`;
   - `TowerEventId`: the current or upcoming event;
   - `TowerEventStartsAt` and `TowerEventEndsAt`: server times;
   - `TowerEventBiome`.
3. **Runtime hooks.**
   - `TowerEncounterRuntime` multiplies HP and ATK when stats are set, adds affixes, and stamps `m.EventId`.
   - `CampWaves.ScheduleRespawn` takes a respawn override.
   - `EffectivePlacements` takes an extra-member count.
4. **Rewards.**
   - `TowerFloorConfig.RollRelic` gains an optional `mods` argument (`DropMult`, `CoreMult`, `HeartMult`, `TierShift`), and its spec covers the shifted tiers.
   - `CombatSimulation` `Reward` passes the mob's stamped mods.
   - `TowerProgress` kill points take a multiplier for Swarm.
5. **Relic Rain** reuses `_G.RelicService.SpawnRelic` with no owner. It needs a meteor VFX (a telegraph circle 3 s before impact) in the existing VFX primitives.
6. **HUD.** The full design is in 7.6. In short:
   - an event indicator with a timer sits bottom right, above Squad Power;
   - each event has its own Gilded Grimoire icon, and hovering it shows the event's description;
   - a pop-up appears in the centre of the screen when an event starts;
   - the floor selector marks floors in the featured biome with the event icon;
   - name plates of mobs carrying the event's bonus get an event tint.
7. **Analytics (optional).** Log event start and end, and relics dropped during each event, through the `roblox-analytics-liveops` skill, so the multipliers can be tuned.
8. **Design doc.** Add a "Tower Events" section next to GDD §2.5, and note the event modifiers in the relic economy tables.
9. **Specs** (`tests/tower-events.spec.luau`):
   - the scheduler never repeats an event back to back;
   - the featured biome is always an unlocked one;
   - the stamped mods are what `Reward` uses;
   - `RollRelic` with mods keeps Cores Elite-only and Hearts Alpha/Boss-only;
   - difficulty events never touch floors 1–5.

### 7.5 Economy guard

Calamity Hour roughly doubles relic income for players who can handle it. Over a 20-minute cycle that is about +25% relics per hour for active players. Check that against the tuning comment in `TowerFloorConfig.RelicDrops` (about 2,900 / 6,800 / 12,700 Gems per hour) before shipping, and scale `DropMult` down if needed.

### 7.6 Event HUD: indicator, icons, tooltip and pop-up

Interactive mockup: [docs/ui/tower-event-hud-mockup.html](ui/tower-event-hud-mockup.html). Its icon shape data is already in the `GrimoireIcons.Drawings` format, so it can be copied into Luau directly.

**Change from the mockup review:** the timer sits on the label row ("TOWER EVENT ── 4:32"), so the event name gets the card's full width. "Calamity Hour" didn't fit beside the timer at 200 px.

Everything here is client-only and React, inside the existing `Hud` app. It follows the Gilded Grimoire rules already used by `SquadPowerBadge`, `GrimoireIcons` and `GildedGrimoire`: glass cards, Cinzel numbers, gold section labels, chunky inked icons and no image assets.

#### Event data on the client

- **Text comes from shared config.** `TowerEventConfig` lives in `ReplicatedStorage/Shared/Config`, so the client reads each event's `DisplayName`, `Icon`, `Accent`, `Description` and `Effects` lines directly, with no network traffic. Example for Calamity Hour:
  - `Description`: "The tower stirs. Monsters grow fiercer, and relics answer the bold."
  - `Effects`: "Monsters: +60% HP, +35% ATK (floor 6+)", "Elites gain an extra affix", "Relic drop chance ×2, better relic tiers".
- **New hook `Hud/useTowerEvent.luau`.** It subscribes to the five `TowerEvent*` attributes with `GetAttributeChangedSignal`. It returns `{ Phase, Event, Biome, SecondsLeft, Fraction }`, re-computing the timer once a second from `workspace:GetServerTimeNow()` in a single `task.delay` loop that is cleaned up on unmount (not every frame).
- **Where it shows.** The indicator appears everywhere, hub included, because it invites players to the tower. The pop-up appears everywhere too.

#### Indicator card (new `Components.TowerEventBadge`)

**Placement.** The badge sits directly above the Squad Power badge:
- it is right-anchored at `L.Edge`;
- its bottom is `L.Edge + powerHeight + 8`;
- it has the same width as the power badge (200, or 130 in compact mode).

Add `L.EventBadgeHeight = 52` (compact 40) to `Theme.luau`. In `HudApp`, the Right Rail's `rightBottom` must also subtract `eventHeight + L.StackGap`, so the rail still stops above everything.

**Layout** (on the same `glass` card as Squad Power):

```
┌──────────────────────────────┐
│ [icon]  TOWER EVENT ───────  │  ← sectionLabel, gold
│         Calamity Hour   4:32 │  ← Cinzel name · timer right-aligned (Display font)
│ ▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱ │  ← 3 px gilded bar, drains to 0
└──────────────────────────────┘
```

**States:**

| Phase | Icon | Text | Style |
| --- | --- | --- | --- |
| `CALM` | `EventHourglass` | "Next event" and `mm:ss` | Muted text, no accent, bar hidden |
| `WARNING` (60 s) | The upcoming event's icon | "<Event> in" and `0:45` | Gold stroke pulsing every 1 s, bar fills up |
| `ACTIVE` | The event's icon | Event name and time left | Event `Accent` stroke, bar drains, icon gets a slow 4 s glow |

- **Featured biome.** For featured-biome events, a third line reads "Featured: Frozen Citadel" in small muted text, and the card grows by 14 px. The rail offset reads the real height from the hook, so the layout stays correct.
- **Compact (phones).** The card shows only the icon and the timer.

#### Hover tooltip

The tooltip follows the `SquadPowerBadge` pattern:
- `MouseEnter` and `MouseLeave` show and hide it;
- a tap toggles it on touch screens;
- it is a glass panel anchored bottom-right, just above the card, 260 px wide, with height to fit, at `BackgroundTransparency` 0.15.

Contents, top to bottom:
1. The icon (36) and the event name in Cinzel with the gold gradient (`GildedGrimoire.Text.Gold`).
2. The scope line: "Whole tower · floors 6–50" or "Featured biome: Frozen Citadel".
3. The description, in italic body text.
4. The effect lines, each with a small bullet glyph. Monster lines are tinted `Blood`, and reward lines `Royal` gold.
5. A footer in muted text: "Monsters that appear during the event keep its bonus until defeated."

In the `CALM` phase the tooltip shows "The tower is calm. Next event in 12:40." When the upcoming event is already known, it shows its name; it is always known during `WARNING`.

#### Start pop-up (new `Components.TowerEventPopup`)

1. **Trigger.** It fires when `TowerEventPhase` changes from `WARNING` to `ACTIVE` while the client is running. A player who joins mid-event sees only the badge, with no pop-up. There is one pop-up per event start.
2. **Look.** A `GildedGrimoire` glass frame of 440 × 160, centred, slightly above middle (`Position = 0.5, 0, 0.38, 0`). It contains:
   - the event icon at 76 px, with 8 thin gold rays slowly rotating behind it;
   - the title in Cinzel with the gold gradient, for example "CALAMITY HOUR";
   - the description as one line of body text;
   - the scope and duration in muted text, for example "Floors 6–50 · 5:00".

   The frame's stroke uses the event `Accent`.
3. **Motion.** A 0.35 s pop-in (scale 0.85 → 1 with `Back` easing, fading in from transparency 1), a 3.5 s hold, then a 0.4 s fade-out. It uses `CanvasGroup` so the whole card fades together.
4. **Never blocks play.** `Active = false` and no modal layer, so clicks and camera input pass through. If a full-screen panel is open (Facility, Shop or Hero Index), the pop-up waits in a queue until the panel closes. If it can't show within 20 s, it is dropped and the badge alone is enough.
5. **Warning nudge.** When `WARNING` begins, there is no pop-up, only the badge pulse and a toast through the existing toast path: "Calamity Hour begins in 60 seconds".
6. **End notice.** When the event ends, a toast reads "Calamity Hour has ended". There is no pop-up.
7. **Sound (optional).** A short gilded chime on pop-in, routed through the existing UI sound group (see the `roblox-audio` skill), which respects the music and SFX settings.

#### Event icons (added to `GrimoireIcons.Drawings`)

All icons use the 64 × 64 grid, the palette above, ink outlines and a sheen on the main shape, matching `Summon`, `Forge` and `Power`. Each is 4 to 7 shapes, back to front:

| Icon id | Event | Drawing |
| --- | --- | --- |
| `EventCalamity` | Calamity Hour | A blood moon (`Blood`, round, 40 across) half covered by a `Dark` eclipse disc, with a thin gold crescent rim and two small ember sparks |
| `EventEliteTide` | Elite Tide | A three-point gold crown over a steel heater shield with a violet gem in the centre |
| `EventRelicRain` | Relic Rain | Three falling crystals (violet, cyan, gold) rotated 30°, each with an ember trail bar behind it, and a gold star spark |
| `EventSwarm` | Swarm | Three overlapping stone discs, each with two ember "eyes", behind three blood-red claw slashes |
| `EventGoldenTide` | Golden Tide | A stack of three gold coins (rounded rectangles) under a gold wave crest |
| `EventAlphaHunt` | Alpha Hunt | A gilded horned skull: stone mask, two curved gold horns, ember eyes, and a thin cyan target ring behind |
| `EventHourglass` | Calm (no event) | A gold-framed hourglass with violet sand, leaning slightly |

- **Accent per event** (stroke and bar): Calamity `BloodLo`, Elite Tide `GoldLo`, Relic Rain `VioletLo`, Swarm `EmberLo`, Golden Tide `GoldHi`, Alpha Hunt `CyanLo`.
- **Where icons are reused:** the floor selector marks featured-biome floors with the event icon at 18 px, and name plates of mobs carrying the event's bonus show it at 14 px.
- **Before committing:** render each icon on a test sheet at 18, 30 and 76 px with a Studio screenshot and check it still reads at the smallest size, as was done for the existing rail icons.

#### Specs and checks

- `tests/tower-events.spec.luau` adds:
  - every event in `TowerEventConfig` has an `Icon` that exists in `GrimoireIcons.Drawings`, plus an `Accent`, a `Description` of at most 140 characters, and 1–4 `Effects` lines;
  - every icon shape lies inside the 64 grid.
- The `useTowerEvent` timer maths (a pure helper) is tested for `CALM`, `WARNING` and `ACTIVE`, and for server-time drift.
- **Studio check:**
  - force each event with `workspace.TowerEventForce`;
  - screenshot the badge, the tooltip and the pop-up at desktop and phone sizes with the device simulator;
  - confirm the Right Rail never overlaps the badge.

## 8. Phase H: Sanctuary and portals

**What's there now** (`TowerRoomBuilder.luau:465-597`, from Studio screenshots of floor 1):
- The safe zone is marked only by two thin side strips (`SanctuaryBoundary`, 1 × 0.2) and a front strip (`SanctuaryThreshold`). From the Basin it reads as just another terrace.
- The four travel stations at the back (`PREVIOUS`, `NEXT`, `SELECTOR`, `HUB`) are 10 × 7 × 4 stone blocks with a trim cap and a flat rune panel. These are the "statues". The client finds them through the prompt's `TowerAction` attribute (`TowerController.client.luau:957-976`).
- The boss ascension portal (`CombatSimulation.server.luau:2393-2521`) is a generic blue neon disc on a slate plinth. It spawns where the boss died, so it can land mid-arena, on a ramp edge or half inside a prop.

### 8.1 A Sanctuary you can spot from anywhere

1. **Glowing square outline.** Replace `SanctuaryBoundary` and `SanctuaryThreshold` with a raised four-sided rim that traces the `ARRIVAL` zone polygon exactly (±44 in X, `safe.Z ± 28`):
   - each side is a 1.2-wide, 0.35-high strip in `theme.LightColor` (Neon, which stays under the 8-stud bloom limit because each strip is thin), sitting on a darker 2.4-wide trim band;
   - a short gap in the front edge marks the exit to the Basin ramp, with two small pylons framing it;
   - the outline is the zone boundary, so the safe area is exactly what the player sees.
2. **Corner beacons.** At each corner, a 3 × 3 pylon with a crystal cap (in the biome style, see H.2) and a thin translucent light column rising to the skylight, about 1.5 studs wide at 0.75 transparency. You can see these from the Apex, so players always know which way is safe.
3. **Ground glow.** A `SurfaceLight` on the `SafeArrival` slab, plus a faint inner fill that is 0.85 transparent and slightly lighter than the terrace, makes the safe square read as lit.
4. **Client pulse.** A `TowerSanctuaryFX` tag that the client animates with a slow 3 s breathe on the rim transparency (0.0 ↔ 0.25). The server builds everything static.
5. **Label.** A `BillboardGui` "SANCTUARY" with a small safe-zone icon above the front gap, visible from 160 studs away, and hidden within 25 studs so it doesn't clutter the screen inside.
6. **Lanes.** The front gap and the rim are added to Phase B's lane and clearance tables, so no props spawn on the outline or the beacons.

### 8.2 Biome-themed portal kit (new `ServerScriptService/Core/TowerPortalKit.luau`)

`TowerPortalKit.Build(parent, cframe, theme, biomeId, opts)` returns a portal `Model` with:
- a frame;
- a vortex (two stacked discs that the client spins in opposite directions);
- an inner glow;
- a particle emitter;
- a `PointLight`;
- an invisible `PortalTrigger` part carrying the `ProximityPrompt`.

`opts` holds `Action`, `Label`, `Scale`, `Dormant` and `Hue`. The model is tagged `TowerPortal` (CollectionService), and the client animates it from the existing `PortalEffectController` style, with spin, pulse and a particle burst when someone uses it.

**Frames per biome** (they reuse the helpers in `TowerBiomeAssets`, so move `ring`, `beam` and `orb` into a shared `TowerShapes` module):

| Biome | Frame | Vortex colours |
| --- | --- | --- |
| Verdant Ruins | Moss-covered stone ring wrapped in vines, with leaf clusters at the top | Green and gold |
| Fungal Hollow | Arch of two mushroom stems with a cap lintel and glowing gills | Teal and violet |
| Ashen Dunes | Obsidian ring with sandstone keystones and magma cracks | Orange and ember |
| Frozen Citadel | Ring of jagged ice crystals | Ice blue and white |
| Infernal Foundry | Riveted iron cog ring with a molten rim | Red and orange |
| Thunder Highlands | Henge ring between two monolith piers, with small lightning arcs | Electric blue and violet |
| Corrupted Grove | Ring of black thorns | Magenta core |
| Sunken Sanctuary | Gold lotus ring with coral at the base | Cyan and gold |
| Astral Archives | Two crossed gold armillary rings | Starfield blue and lavender |
| Abyssal Throne | Spiked obsidian crescent | Violet and teal |

**Telling the actions apart within a biome:** the frame stays the same and the vortex hue changes:
- `NEXT`: the biome accent, brightest;
- `PREVIOUS`: the accent at 60% brightness;
- `SELECTOR`: gold;
- `HUB`: white;
- `RERUN`: green;
- `ASCEND`: the accent, at 1.6× scale.

A dormant portal (Previous on floor 1, Next on floor 50) keeps its frame with an empty, dark centre and its prompt disabled.

### 8.3 Sanctuary travel portals replace the stone stations

- In `TowerRoomBuilder`, swap the four `part(model, action, …)` blocks for `TowerPortalKit.Build`. The portals stand in a shallow arc across the back of the Sanctuary, facing the arrival point: each about 10 wide and 13 tall, spaced 21 apart (they fit in the 88-stud width).
- **Keep the contract:** each portal's trigger part is still named `PREVIOUS`, `NEXT`, `SELECTOR` or `HUB`, and its prompt keeps the `TowerAction` attribute and the F key. `TowerController` and the server validation stay unchanged. The `PedestalLabel` billboards move onto the portal tops.
- The Unpackaging Altar and pad stay at the centre. The rear columns (`SanctuaryRearColumn`) are removed, because the portals take their place.

### 8.4 Boss ascension portal moves to the back

1. **Fixed spot.** `TowerLayout.Get` gains `PortalSpots = { Ascend, Rerun }` at the back of the Apex: `Z = apex.Z - apex.Depth/2 + 12`, with `X = +12` for Ascend and `X = -12` for Rerun, both facing south towards the arena. They sit in front of the citadel backdrop and are reserved in the clearance tables, so props never cover them.
2. **New spawn function.** `spawnFloorAscensionPortal` (`CombatSimulation.server.luau:2393`) ignores the boss's death position. It builds both portals with `TowerPortalKit` at `room.Origin + PortalSpots`, grounded with `HeroNavigation.Ground`. It keeps the existing one-per-room check, the `HighestClearedFloor` gate, the 4 s debounce and the hold-to-use prompt (0.35 s).
3. **Arrival effect.** When the boss dies, a light pillar strikes each portal spot, the frame rises out of the ground over 1.5 s (a client tween on the `TowerPortal` tag), and a toast says "Portals opened at the back of the Apex". The HUD shows a compass arrow to the portal for 10 s.
4. **Floor 50:** Ascend becomes "Return to Hub" (as today), and Rerun is still offered.

### 8.5 Rerun portal

**What it does:** "Rerun Floor N" sends the Master and their squad back to this floor's Sanctuary arrival with a fresh kill counter, so they can summon and farm the boss again without walking out through the selector.

1. **Server.** Add `TowerFloorService.RerunFloor(player)`, modelled on `RecallWipedSquad`. It cancels any pending request and transfers the character and squad to the same room's arrival through `adapters.Combat.Transfer`. It then calls a new combat hook, `ResetFloorProgress(player, floorId)`, which replaces `ActivePlayerProgress[player]` with `TowerProgress.CreateProgress(floorId)`, fires `FloorProgressRemote`, and clears any surge pack the player owns.
2. **Gate.** The rerun uses the same checks as Ascend:
   - the player is on this floor and not transitioning;
   - `HighestClearedFloor` is at least this floor;
   - a debounce applies.

   Anyone else gets a toast.
3. **Run tracking.** `TowerRunService`: a rerun closes the current run summary and opens a new one, so run stats stay per attempt. Loot the player is carrying is **not** banked automatically. They respawn in the Sanctuary, where the Unpackaging Altar is, so they can bank it there.
4. **No change** to shared camps or to other players' progress. The floor stays a shared room.

### 8.6 Specs and design doc

- `tests/tower-portals.spec.luau`:
  - every floor's `PortalSpots` lie on the Apex terrace, outside lanes and camp areas;
  - the Sanctuary rim matches the `ARRIVAL` zone polygon to within 0.5 studs;
  - all four travel triggers keep their names and `TowerAction` attributes;
  - the rerun reset gives fresh progress for that floor only.
- **GDD:** update the Sanctuary description (glowing outline, beacons, themed travel portals) and the boss-kill flow (two portals at the back of the Apex: Ascend and Rerun).

## 9. Order of work and branches

1. `fix(tower): group props and clear them whole` (Phase A, steps 1–2, plus the audit script).
2. `fix(tower): ground landmarks and keep lanes clear` (Phase A, steps 3–4, and Phase B).
3. `feat(tower): random mob types and roaming Elites across spawning areas` (Phase C, plus GDD and specs).

4. `feat(tower): support Regulars for every biome` (Phase D). Needs C.
5. `feat(tower): lane patrols` (Phase E). Needs B's lane geometry and C's roster.
6. `feat(tower): Elite affixes` (Phase F). Needs C. Can run alongside D and E.
7. `feat(tower): timed tower events` (Phase G). Needs F (for "+1 affix") and E (for Alpha Hunt). The other events could ship earlier.
8. `feat(tower): glowing Sanctuary and biome portals with rerun` (Phase H). It only needs Phase A's shared shape helpers and Phase B's clearance tables, so it can go straight after B, ahead of C–G if you want the visual win early.

Phases A and B touch only the builders. Phase C touches only the layout, the runtime and a new util, apart from the single clearance-point line in `TowerRoomBuilder`. So C could run in parallel with A and B, provided A and B own that line. D, E and F all edit `TowerEncounterRuntime`, so run them one after another, or keep each phase's logic in its own module and limit the runtime edits to small hook calls.

## 10. How to test (Studio)

1. Run `pwsh tests/run.ps1`. The new `tower-props` and `tower-camp-roster` suites must pass.
2. Open Studio, sync with Rojo, and run the prop-audit script. The orphan count and ramp-intrusion count must be 0 on all 50 floors.
3. Play solo and teleport to floors 1, 5, 8, 24 and 35. Walk Sanctuary → Basin → each Gallery → Apex. Check that no bushes, cogs or thorn loops sit on ramps or the causeway, and that no floating canopies, mushroom caps or spire tips appear.
4. On floor 2, clear the `BASIN_WEST` camp and wait 10 s. The wave returns as one Regular type, possibly a different one, in new positions, and every member has the right rig and name plate.
5. On floor 4, note which areas have Elites (look for the Elite name plates). Clear an Elite-led camp, then clear another camp. When that second camp respawns, the Elite can lead it instead, and the floor still shows 3 Elites in total. Re-enter the floor a few times and confirm that the Elites start in different areas.
6. With 2 test clients on one floor, check that the extra members join each camp as that camp's current type and do not overlap.
7. **Supports:** on floor 13 (Ashen Dunes, WARD), find a camp with an Ember Oracle. Watch it shield the fighter nearest your squad. Hit it during its windup and confirm the cast cancels. Kill it first and confirm the camp stops getting shields.
8. **Patrols:** on floor 3, watch a patrol walk its loop without entering the Sanctuary. Pull it, run past its leash, and confirm it walks back to the nearest waypoint and carries on with its loop.
9. **Affixes:** on floor 31 or higher, Elites show 2 affixes on their name plate. Check a `SHIELDED` Elite's shield bar drains before its HP. Kill a `SPLITTING` Elite and confirm 2 Regulars appear and do not respawn. Kill a `VOLATILE` Elite and confirm the blast is telegraphed.
10. **Events:** in Studio, set `workspace.TowerEventForce = "CALAMITY_HOUR"`. Check that:
    - after 60 s of the badge pulsing gold above Squad Power, the centre pop-up appears with the blood-moon icon, holds about 3.5 s and fades without blocking input;
    - the badge switches to "Calamity Hour" with a draining bar and timer on all clients;
    - hovering the badge (or tapping it on phone size) shows the description and effect lines;
    - joining with a second client mid-event shows the badge but no pop-up;
    - mobs on floor 6 and up spawn stronger, while floor 1–5 mobs are unchanged;
    - mobs that spawned before the event keep their normal stats.

    Then clear the attribute. Mobs that spawned during the event stay strong until they die.
11. **Relic Rain:** force it and confirm a telegraphed meteor drops a relic on a lane every 30 s, and that stealing one starts the normal retaliation window.
12. **Sanctuary:** on floors 1, 13 and 35, stand on the Apex and look back. The Sanctuary outline and corner light columns are clearly visible, and the outline pulses. Walk out over the outline and confirm combat starts exactly at the glowing edge.
13. **Travel portals:** each of the four Sanctuary portals matches the biome's style, shows the right label, and does the same thing the old stone station did. Previous on floor 1 and Next on floor 50 are dark and can't be used.
14. **Boss portals:** kill the boss on floor 3 somewhere off-centre. Two portals rise at the back of the Apex, not where the boss died. Ascend takes you to floor 4. A second test client that hasn't cleared floor 3 gets the warning toast.
15. **Rerun:** use Rerun on floor 3. You and your squad appear at the Sanctuary, the kill counter starts again from 0, carried loot is still carried, and reaching the threshold summons the Alpha again.

---

## 11. Further improvements to tower content (suggestions)

Ordered by value for effort. The support Regulars, patrols, Elite affixes and timed events are now Phases D–G above.

**Encounters**

1. **More camp archetypes.** Tag spawning areas as `AMBUSH` (members wait hidden and pop up when a Master enters) or `GUARD` (members stay around a loot chest). This uses the same `CampRoster` and just adds an area tag.
2. **Per-visit floor events** that sit alongside the timed server events: a Treasure Goblin that flees through the lanes, or a Cursed Shrine that gives a squad buff in exchange for a harder next wave.

**Rewards and contested loot**

3. **Loot chests in camp areas**, opened when a wave is cleared. This gives players a reason to clear an area instead of just farming kill points, and they feed the existing carry/bank loop.
4. **Secret alcoves** behind waterfalls or under the chasm islands, reached by small hidden ramps, with a guaranteed Mana Geode. It rewards exploring the 3D layouts you already have.

**Layout and visuals**

5. **Layout mirroring and rotation per biome**: flip X on even biomes and swap Bastion and Gallery decor, so the 5 layouts feel like 10+ without new geometry.
6. **Biome hazards on the chasm floor and lanes edges**: lava ticks in Ashen and Infernal, slippery ice in Frozen, lightning strikes telegraphed on the ground in Thunder, poison mist pools in Corrupted. They should stay off the lanes so pathing remains fair.
7. **Performance pass.** Each floor builds thousands of parts (the `ring()` helper emits 6–18 beams per ring, and `chain()` 14 rings). Cache prop groups as templates per biome and clone them, merge clutter into `MeshPart`s where possible, and set `RenderFidelity` / `LevelOfDetail` on distant cliff massifs. Measure with `rbx-scene-analysis` before and after.
8. **Wayfinding**: subtle glowing arrows or rune strips on lane surfaces that point to the Apex once the kill threshold is met, plus a minimap ping on the summoned boss.

**Progression feel**

9. **Floor modifiers that scale with biome depth**: shorter respawn, Elites in every camp on floor 4 and above, a second Alpha on floor 5. These make the sawtooth difficulty visible, not just numeric.
10. **First-clear bonuses** per floor (one-time Gems or relic) tracked on the profile. **This needs a save migration in `DataManager.SyncProfile`.**
