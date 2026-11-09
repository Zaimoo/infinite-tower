# Tower Mob Remodel: Implementation Plan

Status: **pilot built (Verdant Ruins), awaiting review** (§10). Owner: Zaimoo. Written 2026-11-09.

**Pilot notes (2026-11-09).** Step 0 and the Verdant Ruins shapes are built; changes from the plan above:
- **Templates live in the place, not in git.** Rojo deletes unknown children of the `Assets` folder it syncs, so templates go in `ReplicatedStorage.TowerEnemyTemplates`, a folder Rojo ignores, saved with the place. Saving `.rbxm` copies for git is optional. `EnemyRigFactory` reads that folder.
- **Joint pivots come from a generated index.** They live in `Shared/Config/TowerEnemyModelIndex.luau` (built by `tools/make_enemy_model_index.py`), not in attributes on the template. The factory and `tests/enemy-models.spec.luau` both read it.
- **Alphas are their own template** (`alpha_vinebound`): the Elite's meshes plus trophy joints, on a gilded copy of the atlas. That's one extra import per biome, and no texture swapping at runtime.
- **Crawlers have more meshes:** their 16-joint skeleton gives about 18 mesh parts (over the 14 in §4). The per-mesh triangle cap is what matters, and it holds.
- **Tier B (the baked normal/AO maps for Elites, Alphas and Bosses) waits for your sign-off on the shapes**, because a bake has to be redone whenever the geometry changes. The pilot ships all six on the Tier A gradient atlas first.

Every tower enemy is rebuilt as a high-fidelity Blender model, art-directed per biome. That is 60 enemies across 10 biomes: 20 Regulars, 10 Supports, 10 Elites, 10 Alphas and 10 Biome Bosses. The new models keep the existing combat, animation and network contracts, so the server is untouched and every client system that draws an enemy gets the new look from one switch.

When this ships, `docs/GAME_DESIGN.MD` §5.2 (roster and rig architecture) gets the new art pipeline, and `MobCatalog` entries change from `LOCAL_AUTHORED_UNVERIFIED` to the uploaded templates.

---

## 1. Where we are

- **`TowerEnemyRigs.luau`** builds every enemy from Roblox parts: 353 lines, about 25 to 60 parts per rig. It has 23 rig families, and each biome is just a palette swap (`Palettes[biomeId]`).
- **Result** (see `docs/screenshots/verdant_ruins_mobs/`): the bipeds are near-identical boxes with a diamond on the chest. A Regular, an Elite and a Boss differ mostly in scale. Silhouettes don't say "fungal" or "frozen", and nothing reads at a glance in a busy camp.
- **`TowerEnemyClips.luau`** animates them through named `Motor6D`s that every family shares:

| Family group | Joints the clips drive |
| --- | --- |
| Bipeds and colossi (`*_BIPED`, `*_COLOSSUS`, `TREANT`) | `Body`, `Head`, `ArmL/R`, `ForearmL/R`, `LegL/R`, `KneeL/R` |
| `QUADRUPED` | `Body`, `Head`, `ArmL/R` + `ForearmL/R` (front legs), `LegL/R` + `KneeL/R` (hind legs) |
| `AVIAN`, `GIANT_AVIAN` | `Body`, `Head`, `ArmL/R` + `ForearmL/R` (wings), `LegL/R` + `KneeL/R` |
| `SERPENT` | `Body`, `Head`, `ArmL/R` + `ForearmL/R` (fins), `LegL/R` + `KneeL/R` (coils, tail) |
| `CRAWLER`, `INSECT`, `SCORPION`, `CRUSTACEAN` | `Body`, `Head`, `JawL/R`, `Leg-1_i` / `Leg1_i` + `Knee-1_i` / `Knee1_i` (3 pairs) |

- **Three places build enemy rigs:**
  - `EntityRenderer`, through `EnemyAnimationController.Attach`, for tower combat.
  - `AdventurerPatrolController` (`TowerEnemyRigs.Build`), for the hub patrol waves.
  - `FacilityPanel` (`TowerEnemyRigs.Build`), for the Facility mob preview.
- **The raid work already proved the pipeline:**
  - Procedural Blender generators (`tools/blender/raid_kit.py`).
  - Segmented meshes exported with joint pivots in JSON.
  - A generated Luau asset table.
  - Mesh rigs that keep the clip contract (`RaidBossRigs`).
  - Two gotchas learned there: the importer's 180° mesh flip, and scripts being unable to set `MeshId`.

## 2. Goals and non-goals

**Goals**
1. **Each biome reads instantly:** silhouette, materials and glow say where you are, and the six enemies of a biome look like one ecosystem.
2. **Roles read instantly:**
   - **Regular:** small, simple shapes.
   - **Support:** robed or haloed, with a clear focus object.
   - **Elite:** armoured, carries a signature weapon, with a mid-size glow.
   - **Alpha:** the Elite's model gilded, with a crown or trophy piece added.
   - **Biome Boss:** a landmark silhouette with layered detail.
3. **High fidelity at Roblox cost:** smooth-shaded, bevelled, layered forms, with a baked normal map and ambient occlusion on the bigger enemies, while staying inside the budgets in §4.
4. **No gameplay change:** same enemy ids, hitbox `Bounds`, attacks, animation slots, network records and server code.

**Non-goals**
- Skinned meshes or uploaded `Animation` assets. Rigs stay rigid segments with `Motor6D`s driven by `TowerEnemyClips`.
- New enemies, abilities or stats.
- The four raid bosses, which are already done.

## 3. The approach

### 3.1 Segmented meshes on the existing joint contract

Each enemy is a set of **rigid mesh segments, one per joint the family's clips drive**. Each segment's origin is the joint pivot, exactly as with the raid bosses. Because the joint names don't change, `TowerEnemyClips` animates the new models without edits. If a family's proportions change enough to need it, it gets a light retune (§6.4).

- **Extra moving bits** (tails, capes, antennae, spore sacs) are welded to their parent segment, or get a small sway driven by the client.
- **Neon glow pieces** are separate meshes, coloured from the biome palette, one mesh per glow colour.

### 3.2 Two fidelity tiers

| Tier | Used for | Surface | Why |
| --- | --- | --- | --- |
| **A: gradient palette** | Regulars and Supports (30 enemies) | One **512² atlas per biome** of 16×16 swatches. Half are flat colours; half are vertical gradients (dark at the bottom, light at the top), so UV height fakes ambient occlusion and rim light. A small hand-placed band of UVs per part gives soft shading without baking. | These are the most numerous on screen (up to 48 live mobs a floor), so they share one texture per biome and cost little memory. |
| **B: baked surface** | Elites/Alphas (20) and Biome Bosses (10) | A **high-poly source** is baked onto a **low-poly game mesh**. It is built procedurally in Blender (subdivision, bevel, displacement noise for rock, bark, chitin and ice), then the bake makes a ColorMap with AO and a **normal map**. This uses Cycles, 1024² per Elite or Alpha and 2048² per Boss, delivered as a `SurfaceAppearance`. | These are fewer, bigger and fought up close, so baked normals give real surface detail (cracks, scales, rivets, runes) without the triangles. |

**Alphas** reuse their Elite's meshes. The Alpha look is a second baked texture set (gilded trims, a brighter emissive), plus 1 or 2 extra **trophy meshes** (crown, banner, horn caps) welded on. The `1.4×` scale stays.

### 3.3 Templates, not runtime mesh creation

Scripts can't set `MeshPart.MeshId`, and `SurfaceAppearance` maps can't be set from scripts either. So each enemy ships as an **imported template model** saved as `.rbxm` under `src/ReplicatedStorage/Assets/TowerEnemies/<enemyId>.rbxm`. That is the `PlannedTemplatePath` `MobCatalog` already names, and Rojo syncs `.rbxm` files as-is.

- The template is the model exactly as Studio's 3D Importer produced it, with the mesh flip and scale corrected and the segments renamed to their joint names.
- At runtime, `EnemyRigFactory` clones the template and wires the `Motor6D`s from the pivots stored as attributes on each segment. Nothing is created from asset ids at runtime.
- This replaces the raid bosses' `CreateMeshPartAsync` path for tower enemies. Templates load with the place, so there's no preload delay and no first-spawn stand-in.

## 4. Budgets

Measured per enemy, after decimation:

| Role | Triangles (whole rig) | Max per mesh | Mesh parts | Textures |
| --- | --- | --- | --- | --- |
| Regular | ≤ 3,500 | 1,200 | ≤ 14 | biome atlas (shared) |
| Support | ≤ 3,000 | 1,200 | ≤ 12 | biome atlas (shared) |
| Elite | ≤ 8,000 | 3,000 | ≤ 18 | 1024² Color + Normal |
| Alpha | Elite + ≤ 1,000 trophy | 3,000 | ≤ 20 | 1024² Color + Normal (gilded set) |
| Biome Boss | ≤ 20,000 | 8,000 | ≤ 24 | 2048² Color + Normal |

- **Worst case on a floor:** 48 live mobs, roughly 40 Regulars or Supports, 6 Elites, 1 Alpha and 1 Boss. That is about 140k + 48k + 9k + 20k ≈ **217k triangles**, below the current part-built cost once draw calls are counted (the part rigs use 25 to 60 instances each).
- **Texture memory per floor:** the biome atlas (512², about 1 MB), the Elite set (1024² colour + normal, about 8 MB), and either the Alpha set (floors 1–4, about 8 MB) or the Boss set (floor 5, 2048², about 32 MB). That's about 17–41 MB uncompressed, or roughly a quarter of that after Roblox's GPU compression. Only the biome you're in is loaded.
- **Every mesh part** gets `CastShadow = false` except the body and boss segments, `CanQuery`/`CanTouch = false`, `Massless = true`, and `RenderFidelity = Automatic` so Roblox handles distance LOD.
- **Glow meshes and accessories hide beyond 140 studs**, following the `performance-plan.md` §9 LOD guidance.

## 5. Biome art direction

Each biome gets a **palette** (primary, secondary, accent, trim, glow), a **material language**, a **motif** repeated on all six enemies, and a silhouette note per enemy. Rig families stay as they are in `MobCatalog`.

### 1. Verdant Ruins (floors 1–5)
*Overgrown temple stone and living moss. Motif: carved sun-disc glyphs half-swallowed by vines. Glow: spring green.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Moss Crawler | `CRAWLER` | A low stone-backed beetle. Its shell is a cracked temple tile with a moss tuft and a little fern sprouting from it. It has root-like legs and green-lit mandibles. |
| Ruin Guardian | `ARMORED_BIPED` | A weathered stone sentinel: a broken column for a torso, a slab head with one glowing glyph eye, and vine-bound gauntlets. |
| Bloom Tender | `ROOTED_BIPED` | A slender dryad-like sprout with a lily-pad hood and a blossom crown that glows when it heals. Its legs are root tendrils. |
| Vinebound Elite / Alpha | `ROOTED_BIPED` | A knight overrun by vines, with a living-wood shield and a thorn-whip arm. The Alpha adds a gilded sun-disc halo and golden bark plates. |
| Mossbound Guardian | `STONE_COLOSSUS` | A ruined temple statue on the march: a moss-carpeted back, a tree growing from one shoulder, a sun-disc chest core and fists of fallen pillars. |

### 2. Fungal Hollow (6–10)
*Bioluminescent caves. Motif: gill fans and spore-glow dots. Glow: cyan-teal with violet accents.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Spore Skitter | `CRAWLER` | A puffball body on spindly legs, with gill skirts underneath and glowing spore freckles. |
| Lantern Spore | `FUNGAL_BIPED` | A tall stalk whose head is a translucent lantern-cap holding a glowing core. Its arms are drooping tendrils. |
| Sporecap Chanter | `FUNGAL_BIPED` | A hunched mushroom monk with a wide brim cap, a censer of spores, and rings of light that pulse when it rouses allies. |
| Mycelial Brute / Alpha | `HEAVY_BIPED` | A shelf-fungus hulk with club forearms of bracket fungi and a mycelium-web chest. The Alpha adds an amber-capped crown and gilded gill fans. |
| Spore Matriarch | `FUNGAL_COLOSSUS` | A towering morel matriarch with a layered cap crown that splits open in Phase 2, tendril skirts and spore-sac lanterns. |

### 3. Ashen Dunes (11–15)
*Sun-bleached sandstone, glassed sand and ember. Motif: wind-worn banded stone and black volcanic glass. Glow: ember orange.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Dune Scarab | `INSECT` | An iridescent bronze scarab with a horn and a sand-streaming carapace. |
| Ash Raider | `WEAPON_BIPED` | A wrapped desert raider: layered sashes, a mask with ember eyes and a curved khopesh. |
| Ember Oracle | `CASTER_BIPED` | A veiled seer with a ring of floating glass shards that become the ward. |
| Glass Scorpion / Alpha | `SCORPION` | An obsidian-glass scorpion with translucent amber segments and a molten tail-tip. The Alpha adds gold-banded pincers and a sun-crest on its tail. |
| Sandstone Colossus | `STONE_COLOSSUS` | A colossal sphinx-guardian torso of stacked banded sandstone, with glass-veined fists and a magma seam down its spine. |

### 4. Frozen Citadel (16–20)
*Frost-locked fortress. Motif: hexagonal ice and blue steel with silver filigree. Glow: pale ice-blue.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Frost Hound | `QUADRUPED` | A lean wolf with a crystalline icicle mane, frosted breath vents and silver-shod paws. |
| Rime Sentry | `WEAPON_BIPED` | A helmed spearman in blue steel, with a fur mantle and an ice-crystal spearhead. |
| Rime Chaplain | `CASTER_BIPED` | A robed priest with a tall mitre and a snowflake reliquary that projects the ward. |
| Glacier Knight / Alpha | `ARMORED_BIPED` | A heavy plate knight with a tower shield of ice and a broad glacier blade. The Alpha adds a silver crown of icicles and gilded filigree. |
| Frostbound King | `ROYAL_BIPED` | A tall frozen monarch with a jagged ice crown, an articulated ermine cloak and a greatsword sheathed in ice. Frost trails from his cloak's hem. |

### 5. Infernal Foundry (21–25)
*Working forge. Motif: rivets, pistons, cooling slag and glowing seams. Glow: molten orange-gold.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Cinder Imp | `SMALL_BIPED` | A soot-black imp with ember cracks, spark-tipped horns and a tiny tong-claw. |
| Forge Construct | `ARMORED_BIPED` | A riveted iron automaton with a piston hammer arm and a furnace-grill chest. |
| Bellows Imp | `SMALL_BIPED` | An imp strapped to a leather bellows pack that puffs sparks when it rouses allies. |
| Molten Taskmaster / Alpha | `HEAVY_BIPED` | A hulking overseer in a foundry apron and plate, dragging a glowing chain. The Alpha adds a gilded slag-crown and a brass-banded chain. |
| Ember Titan | `FORGE_COLOSSUS` | A walking blast furnace: chimney shoulders venting smoke, a molten core window, and anvil-head fists. |

### 6. Thunder Highlands (26–30)
*Storm-scoured crags. Motif: copper totems and jagged lightning glyphs. Glow: electric violet-white.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Storm Talon | `AVIAN` | A raptor with slate feathers, copper-tipped primaries and crackling crest plumes. |
| Crag Channeler | `CASTER_BIPED` | A horned shaman with a copper lightning-rod staff and a rune cloak. |
| Squall Herald | `AVIAN` | A crested herald bird with a fan tail and a speaking-horn beak, whose cry rings glow. |
| Thunder Ram / Alpha | `QUADRUPED` | A shaggy ram with spiral copper-banded horns that arc lightning. The Alpha adds gold-capped horns and a storm-glyph saddle. |
| Storm Roc | `GIANT_AVIAN` | A colossal storm bird with thunderhead-grey wings edged in lightning and a crest of copper spines. |

### 7. Corrupted Grove (31–35)
*Blighted forest. Motif: bruised bark, weeping sap and purple rot blooms. Glow: sickly magenta.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Blight Wolf | `QUADRUPED` | A gaunt wolf with a thorned spine, bark-plated flanks and rot-bloom eyes. |
| Thorn Weaver | `ROOTED_BIPED` | A spindly briar figure that throws thorn bolts from its finger-branches. |
| Rot Mender | `ROOTED_BIPED` | A hunched grafter with stitched bark and a sap-lantern used for its MEND. |
| Rotwood Keeper / Alpha | `TREANT` | A hollow-trunk treant with root legs, branch arms and a glowing rot heart. The Alpha adds a gilded antler crown. |
| Blight Sovereign | `GROVE_COLOSSUS` | A crowned dead-tree colossus with a hanging-moss mantle, grasping branch hands and a cavity of rot light. |

### 8. Sunken Sanctuary (36–40)
*Drowned temple. Motif: verdigris bronze, coral growth and shell spirals. Glow: aqua.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Tide Claw | `CRUSTACEAN` | A barnacled crab with asymmetric pincers and a coral-crusted shell. |
| Drowned Acolyte | `CASTER_BIPED` | An amphibious priest with a fin hood, a kelp-wrapped robe and a shell staff. |
| Tide Cantor | `CASTER_BIPED` | A singer with a conch, frilled gills and a water-ring halo. |
| Coral Warden / Alpha | `ARMORED_BIPED` | A knight in branching coral armour with a nautilus shield and a hook-glaive. The Alpha adds a pearl crown and gold-verdigris trim. |
| Tidal Leviathan | `SERPENT` | A long eel-dragon with a frilled head, bioluminescent stripe and bronze-temple debris fused to its back. |

### 9. Astral Archives (41–45)
*Cosmic library. Motif: floating pages, brass orreries and star-glyphs. Glow: starlight gold with indigo.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Rune Mite | `CRAWLER` | A clockwork mite with a floating rune-plate shell and brass legs. |
| Astral Scribe | `CASTER_BIPED` | A hooded scribe with a quill-staff and an open floating tome, trailing pages. |
| Glyph Warden | `CASTER_BIPED` | An archivist with orbiting glyph rings that lock into the ward. |
| Archive Executor / Alpha | `ARMORED_BIPED` | A tall armoured enforcer with a segmented glaive and a star-chart tabard. The Alpha adds an orrery crown. |
| Rift Warden | `ARCANE_COLOSSUS` | A towering guardian of stacked bookshelves and brass rings, with a rift-eye core and floating tome shields. |

### 10. Abyssal Throne (46–50)
*The tower's apex. Motif: blackened iron, crimson silk and void light. Glow: crimson with void purple. It shares the raid bosses' visual language, so the endgame feels coherent.*

| Enemy | Family | Remodel |
| --- | --- | --- |
| Abyss Reaver | `WEAPON_BIPED` | A lean armoured reaver with hooked twin blades and a tattered crimson half-cape. |
| Void Invoker | `CASTER_BIPED` | A robed invoker whose hands hold a crackling void orb. |
| Void Hierophant | `CASTER_BIPED` | A masked high priest with a tall crown-mitre and a void-light censer. |
| Throne Executioner / Alpha | `HEAVY_BIPED` | A hulking hooded executioner with an oversized axe. The Alpha adds a gilded skull pauldron and a crimson banner. |
| Crimson Overlord | `ROYAL_COLOSSUS` | A crowned colossus in black-iron plate with a sword of crimson light and an articulated mantle of chains. |

## 6. Pipeline

### 6.1 Blender: generators per biome

- **`tools/blender/mob_kit.py`** grows out of `raid_kit.py`. It adds:
  - **Family skeletons:** a template for each joint layout in §1. It places the pivot empties and validates that every segment maps to a joint the family's clips know.
  - **Fidelity helpers:** subdivision and bevel modifiers, procedural displacement (Voronoi for rock, wave or noise for bark, hex for ice, scale for chitin), weighted-normal shading, and decimation to the §4 budget.
  - **Tier A:** biome gradient-atlas UV mapping (swatch plus height gradient).
  - **Tier B:** a high-to-low bake. The script duplicates each segment, keeps the high-poly copy for baking, decimates the game copy, Smart-UV-unwraps it, then bakes AO + diffuse and a tangent-space normal map in Cycles into the enemy's atlas.
  - **Export:**
    - One FBX per enemy, with every segment and glow mesh.
    - `<enemyId>.json`: per segment, the joint name, parent, pivot (Roblox coordinates) and bounding box, plus the triangle count.
    - The baked PNGs.
- **Generators:** `tools/blender/mobs/<biome>.py`, one file per biome, holds its palette, motif helpers (sun-disc glyph, gill fan, hex ice, rivet strip, …) and six builders. Run with:
  ```bash
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" -b -P tools/blender/generate_mobs.py -- verdant_ruins
  ```
- **Sources:** `assets-source/tower/enemies/<enemyId>/model.blend` (the `PlannedModelSourcePath` in `MobCatalog`).
- **Exports:** `assets/models/enemies/<biome>/`, with previews in `.../previews/*.jpg` (front, three-quarter, side and back, plus a biome lineup).

### 6.2 Studio: import and templates

Per biome:
1. You import the six FBXs by hand with Studio's 3D Importer (decision 4, §10).
2. Run the template prep script `tests/studio-enemy-template-prep.luau` through Studio MCP. It:
   - fixes scale to the JSON bounds (the FBX comes in at about 74×) and applies the 180° Y mesh turn (raid finding),
   - renames the segments to their joint names and stores the pivot and parent on each as attributes (`JointPivot`, `JointParent`),
   - turns off shadows, query and touch, sets `Massless`, and anchors nothing,
   - checks that the `SurfaceAppearance` came through (Tier B) and that the `TextureID` is set (Tier A).
3. It files each model under `ReplicatedStorage.TowerEnemyTemplates.<enemyId>` (saved with the place; see the pilot notes).

### 6.3 Runtime: one rig factory

- **New `ReplicatedStorage/Assets/EnemyRigFactory.luau`** with `Build(model, root, enemyId)`:
  - If `Assets.TowerEnemies[enemyId]` exists, it clones it, places the segments relative to `root` and `RootHeight`, and creates one `Motor6D` per segment from its `JointPivot`/`JointParent`. Bind and C1 come from the pivot (the same math as `RaidBossRigs`), and glow meshes are welded on.
  - It returns the same rig shape as `TowerEnemyRigs.Build`: `Joints`, `Parts`, `Root`, `Model`, `Spec`, `EnemyId`, `Distance`. It keeps `SupportHalo`/`AffixRing` hooks so support and affix glows still work.
  - **Otherwise** it falls back to `TowerEnemyRigs.Build`, so a biome can ship before the next one is done.
- **Route all three callers through it:** `EnemyAnimationController.Attach`, `AdventurerPatrolController` and `FacilityPanel`.
- **Alphas:** the factory clones the Elite's template, swaps in the Alpha `SurfaceAppearance` (from a sibling `Alpha` folder in the template), and welds on the trophy meshes. `RaidBossRigs` can later move onto the same factory and templates.

### 6.4 Animation fit

The new proportions differ from the part rigs, so per family:
- Check every clip against the new model with the Studio lineup script below (each slot, plus Alpha scale).
- Retune only where something reads wrong: limbs clipping, feet sliding, a head turning through armour. Changes go in `TowerEnemyClips` per family, not per enemy, so the 60 enemies stay on 23 clip sets.
- `RootHeight` per enemy comes from the JSON (feet at Y = 0), replacing the per-family table where they differ.

## 7. Tests and verification

- **`tests/enemy-models.spec.luau`** (pure Luau, generated data). For every enemy with a template entry:
  - every segment name is a joint its family's clips drive, and every joint the clips need has a segment;
  - triangle counts are within §4;
  - each Alpha's base Elite has a template;
  - there are no orphan parents.
  - This needs a generated `TowerEnemyModelIndex.luau` (from the JSONs) that the CLI can read without `.rbxm`.
- **`tests/studio-enemy-lineup.luau`:** spawns a biome's six enemies plus the Alpha on a platform, cycles each animation slot, and takes screenshots for `docs/screenshots/<biome>_mobs/` (before and after).
- **Performance check:** run `performance-plan.md` scenario B (dense mob pack) before and after a biome lands. Record client frame time, triangles and draw calls.

## 8. Build order

One biome per PR, with a review gate after the pilot.

0. **Pipeline:**
   - `mob_kit.py` with the family skeletons, both fidelity tiers and the bake.
   - `EnemyRigFactory` with the fallback, routing all three callers.
   - The template-prep and lineup Studio scripts.
   - The model-index generator and spec.
1. **Pilot: Verdant Ruins.** All six enemies plus the Alpha, compared side by side with the current `docs/screenshots/verdant_ruins_mobs`. **Review gate:** you sign off on the style, fidelity and budgets before the rest are built.
2. Fungal Hollow and Ashen Dunes (crawlers, insects, scorpions: the multi-leg families).
3. Frozen Citadel and Infernal Foundry (armoured bipeds and the forge colossus).
4. Thunder Highlands and Corrupted Grove (avians, quadrupeds, the treant).
5. Sunken Sanctuary and Astral Archives (crustacean, serpent, arcane colossus).
6. Abyssal Throne, aligned with the raid bosses' style. Then move `RaidBossRigs` onto the template factory.
7. **Cleanup:**
   - `TowerEnemyRigs` stays as the fallback, and `MobCatalog` statuses are updated.
   - Update `docs/GAME_DESIGN.MD` §5.2.
   - Remove the `TowerEncounterRuntime` fallback boss spec's reliance on the part rig.

## 9. Risks

| Risk | Mitigation |
| --- | --- |
| The importer changes scale and orientation (about 74× and a 180° Y turn on the raid meshes) | The prep script normalises from the JSON. The spec catches missing joints. |
| `SurfaceAppearance` and `MeshId` can't be set from scripts | Ship imported templates as `.rbxm` (§3.3), never build from ids at runtime. |
| Baked textures get moderated or are slow to approve | Upload per biome, and fall back to the part rig until approved (the factory fallback). |
| Clip fit after proportion changes | Retune per family, verified by the lineup script before each PR. |
| Too many triangles on a full floor | The budgets in §4, `RenderFidelity Automatic`, glow and accessory culling beyond 140 studs, and the perf check per PR. |
| `.rbxm` files are binary in git | Keep each template small (meshes are referenced by id, not embedded). One file per enemy keeps diffs isolated. |

## 10. Decisions (2026-11-09)

1. **Style: stylized.** Chunky, readable silhouettes, saturated biome palettes, and baked AO and normals for depth. No realistic PBR (no roughness or metalness maps), so the mobs match the heroes and raid bosses.
2. **Textures: 2048² for Biome Bosses only.** Elites and Alphas use 1024²; Regulars and Supports use the shared 512² biome atlas (§3.2, §4).
3. **No AI-generated meshes.** Every body, accessory, weapon and trophy is modelled procedurally in the Blender generators, so all of it stays editable and re-runnable.
4. **Uploads are done by hand.** Claude exports the FBXs, textures and JSON per biome. You import them with Studio's 3D Importer. Claude then runs the template-prep script through Studio MCP and saves the `.rbxm` templates (§6.2).
