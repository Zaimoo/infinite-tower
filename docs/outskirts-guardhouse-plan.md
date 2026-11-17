# Outskirts Guardhouse Area Overhaul — Complete Implementation Plan

**Target Executor:** Hydrogen Extra  
**Reference Image:** `C:/Users/enter/.gemini/antigravity/brain/1f0596d8-a4d0-45c0-9724-9721c02d88c0/.user_uploaded/media_1794880931388_d85f33f6.jpg`  
**Target Pipeline:** Blender 5.x (`tools/blender/generate_outskirts_guardhouse.py`) ➔ FBX & PBR Textures (`assets/models/facilities/`) ➔ Roblox Studio (`ReplicatedStorage.Assets.CustomFacilityMeshes.GuardpostOutskirts` & `ReplicatedStorage.Assets.PlotFacilities.GuardpostOutskirts`) ➔ Luau Integration (`PlotFacilityArchitecture.luau`, `OutskirtsEnvironmentBuilder.luau`, `PlotBuildings.luau`, `FacilityConfig.luau`, `OutskirtsRules.luau`, `AdventurerPatrolController.client.luau`)

---

## 1. Visual & Spatial Analysis of the Reference Image

### 1.1 Coordinate Frame & Camera Alignment
In *Infinite Tower*, each player's Fortress Plot (`WaitingRoomPlots.Plot_1..8`) has its courtyard origin (`origin`) at `Y = 12.0` (`IslandTopSurface` top face, which is aligned with `OutskirtsGrounds` top face at local `Y = 0.0`):
- **Dividing Castle Wall (`FortressWalls`)**: Runs along plot-local `Z = +57` (outer stone face at `Z = +60`).
- **Rear Gatehouse (`EastOutskirtsGateArch`)**: Centered at plot-local `(14, 0, 57)`, with a `14W × 15H` walkthrough opening (`X ∈ [7, 21]`), open double wooden doors, crenelated stone merlons, and two exterior flickering wall torches at `(3.4, 10.5, 61.1)` and `(24.6, 10.5, 61.1)`.
- **Reference Camera Perspective**: Positioned in the southern/south-western outskirts around plot-local `(-14, 44, 138)` looking back toward `(14, 3, 82)` (`-Z / +X` diagonal):
  - **Top-Left**: The dividing stone castle wall (`Z = 60`) and `EastOutskirtsGateArch` (`X = 14, Z = 60`) with its two warm wall torches and rectangular fitted-stone threshold apron (`X = 14, Z = 65.5`).
  - **Upper-Right of Center** (`+X` side of the connector path, plot-local `(26.0, 0, 82.5)`): The **Elevated Timber Guard Tower (Outskirts Guardhouse)** resting on a mossy rounded-square cobblestone pad.
  - **Middle-Left of Center** (`-X` side of the connector path, plot-local `(-1.5, 0, 90.0)`): The **Stone-Ringed Campfire**, 3 mossy split-log benches, chopped stump, and cooking spit tripod with crate.
  - **Lower-Left Perimeter** (wrapping around the `-X` and `+Z` side of the campfire clearing from `(-22, 0, 84)` to `(-5.5, 0, 101.5)` and turning right to `(5.5, 0, 96.5)`): The **Sharpened Timber Palisade & Pointed Split-Rail Corner Fence**.
  - **Center & Foreground** (`X ≈ 11..14, Z = 65..112` branching into `X ∈ [-68, +68], Z ≈ 108..116`): The **Organic Trodden Dirt Pathway** inlaid with **Large Chiseled Grey Polygonal Stepping Stones**.
  - **Surrounding Framing**: Tiered dark-green **Highland Pine / Spruce trees**, plump multi-lobed **leafy green bushes**, **woodland ferns**, **3D grass blade tufts**, and **faceted mossy grey boulders**, bathed in cool misty blue-grey forest shadow contrasted against warm golden-amber fire and lantern light.

### 1.2 Facility Local Space (`GuardpostOutskirts`)
- Update `FacilityConfig.FacilityLayout.Guardpost.Offset` (and `OutskirtsRules.GuardPostCenter`) from `Vector3.new(12, 0, 115)` to **`Vector3.new(12, 0, 96)`** (`RotationY = 0`).
- Every Guardpost mesh is authored in **Guardpost-local Roblox coordinates** `(rx, ry, rz)` relative to `centerCF = origin * CFrame.new(12, 0, 96)`:
  - Conversion from plot-local `(px, py, pz)` to Guardpost-local `(rx, ry, rz)`:
    $$\text{rx} = \text{px} - 12.0, \quad \text{ry} = \text{py}, \quad \text{rz} = \text{pz} - 96.0$$
  - Conversion from Guardpost-local Roblox `(rx, ry, rz)` to Blender `(bx, by, bz)` (`1 Blender meter = 1 Roblox stud`, exported with `axis_forward="Z"`, `axis_up="Y"` matching `generate_training_grounds.py` and `generate_merchant_bazaar.py`):
    $$\text{rbx\_to\_blender}(rx, ry, rz) = (rx, -rz, ry)$$

---

## 2. Existing Codebase Audit & Contracts to Preserve

Before replacing any models, Hydrogen Extra must preserve these exact runtime contracts across server and client scripts:

| File | Contract / Symbol | Requirement |
| --- | --- | --- |
| `src/ReplicatedStorage/Shared/Config/FacilityConfig.luau` | `FacilityConfig.FacilityLayout.Guardpost` | Defines `Offset`, `RotationY`, `Radius = 22`, `PromptText = "Guardpost"`, `Keybind = Enum.KeyCode.F`. |
| `src/ServerScriptService/Core/PlotBuildings.luau` | `Buildings.Build(plot)` (`VERSION`) | Bump `VERSION` from `42` to `43`. Calls `OutskirtsBuilder.Build(folder, origin)`, `EnvironmentSpawner.UpgradeExistingScene({ folder })`, and `Architecture.BuildGuardPost(folder, gpCF)`. Expects `folder:FindFirstChild("Building_GuardPost")`, sets attribute `Facility = "GuardPost"`, attaches `ProximityPrompt` named `"FacilityHUDPrompt"` (`FacilityHUD = "GuardPost"`, `ObjectText = "Outskirts Guard Post"`, `ActionText = "Guardpost"`, `KeyboardKeyCode = Enum.KeyCode.F`, `MaxActivationDistance = 18`) to the returned `gpInteract` (`FacilityInteraction` part), and calls `syncPlotFacilityAnchor(plot, "GuardPost", gpInteract.CFrame)`. Also add a cache check confirming `Building_GuardPost` contains a `MeshPart` so cached plots auto-upgrade. |
| `src/ServerScriptService/Core/PlotFacilityArchitecture.luau` | `Arch.BuildGuardPost(folder, centerCF)` & `Arch.EnsureFacilityPrefabs()` | Bump `PrefabVersion` from `15` to `16`. `BuildGuardPost` must create `Model` named `"Building_GuardPost"`, populate it via `instantiateBundledMeshes("GuardpostOutskirts", GUARDPOST_OUTSKIRTS_MESHES, model, centerCF)` (with a procedural fallback if meshes are unavailable in CLI tests), attach lights/particles/colliders, call `finalizeFacilityModel` creating `PrimaryRoot` (`model.PrimaryPart`), `PromptAnchor` (`Attachment`), and `FacilityInteraction` (`Part`), and register the prefab as `ReplicatedStorage.Assets.PlotFacilities.GuardpostOutskirts`. |
| `src/ServerScriptService/Core/FacilityPresence.luau` | `BUILDING_PREFIX = "Building_"` | Unoccupied plots stash every `Building_*` model in `PlotBuildings` (including `Building_GuardPost`) and leave non-`Building_*` instances in `PlotBuildings` (the outskirts ground, pathway, trees, bushes, boulders) visible. Keep core Guardhouse + Campfire + Fence inside `Building_GuardPost`, and keep terrain/trail/stepping-stones/greenery in `OutskirtsEnvironmentBuilder.luau`. |
| `src/StarterPlayerScripts/Rendering/FacilityLabelController.client.luau` | `roofOffset` / `BillboardStudsOffset` | Reads `BillboardStudsOffset` on `FacilityInteraction` (or `building:GetBoundingBox()`) to position `FacilityLabel_GuardPost` (`"Outskirts Guard Post"`, `"+X Gold/min"`, `"Lv.N · X/Y Adventurers"`). Set `gpInteract:SetAttribute("BillboardStudsOffset", Vector3.new(9.5, 19.5, -3.0))` so the floating label hovers cleanly above the Guard Tower roof ridge instead of the empty midpoint between the tower and fence. |
| `src/StarterPlayerScripts/UI/OnboardingGuide.client.luau` | `worldTarget("GuardPost", root)` | Finds `PlotBuildings.Building_GuardPost` and its `ProximityPrompt`. When the player is inside the courtyard (`Z < 64`), aims the guide arrow at `origin:PointToWorldSpace(Vector3.new(14, 2, 67))` (the Rear Gatehouse); once in the Outskirts (`Z >= 64`), aims directly at `FacilityHUDPrompt`. Keep `FacilityHUDPrompt` enabled and reachable right along the main connector path. |
| `src/ReplicatedStorage/Shared/Util/OutskirtsRules.luau` & `tests/outskirts-waves.spec.luau` | `GuardPostCenter`, `GatehouseRunIn`, `BuildingAttackTargets`, `CampfireRestSlots`, `DefenderSlots`, `SpawnLanes` | All waypoints must stay within `OutskirtsRules.Bounds` (`X ∈ [-75, 75], Z ∈ [62, 158]`), and every `SpawnLane` must satisfy `Spawn.Z > Mid.Z > BuildingTarget.Z`. |
| `src/StarterPlayerScripts/Rendering/AdventurerPatrolController.client.luau` | `campfireLook`, `CampfireRestSlots`, `BuildingAttackTargets` | Coma heroes walk to `CampfireRestSlots[slot]` and sleep facing `campfireLook` (update `campfireLook` to `Vector3.new(-1.5, 0, 90.0)` to match the new campfire center). |

---

## 3. Step-by-Step Execution Tasks

### Task 1: Create the Blender Procedural Generator & PBR Texture Baker (`tools/blender/generate_outskirts_guardhouse.py`)

Create `c:\WORK\infinite-tower\tools\blender\generate_outskirts_guardhouse.py` modeled directly on `tools/blender/generate_training_grounds.py` and `tools/blender/generate_merchant_bazaar.py`.

#### 1A. Output Paths & Collection Structure
- **Script Path**: `tools/blender/generate_outskirts_guardhouse.py`
- **FBX Output Path**: `assets/models/facilities/OutskirtsGuardhouse.fbx`
- **Manifest Output Path**: `assets/models/facilities/outskirts_guardhouse_manifest.json`
- **Texture Directory**: `assets/models/facilities/textures/outskirts_guardhouse/`
  - `Tex_GuardpostGround_Color.png`, `Tex_GuardpostGround_Normal.png`, `Tex_GuardpostGround_Roughness.png` (`1024×1024`, 4×4 UV atlas with `14px` cell padding)
  - `Tex_GuardpostProps_Color.png`, `Tex_GuardpostProps_Normal.png`, `Tex_GuardpostProps_Roughness.png` (`1024×1024`, 4×4 UV atlas with `14px` cell padding)
- **Collection Name**: `OutskirtsGuardhouse_Prefab`
- **Triangle Budget**: Strictly `< 6,500` triangles total across all meshes in the FBX.

#### 1B. 4×4 PBR Atlas Cell Layouts (`1024×1024`)
1. **`Tex_GuardpostGround` (`Mat_GuardpostGround`)**:
   - `Cell (0, 0)`: **Mossy Cobblestone Pad** — Rounded bevelled grey-slate cobblestones (`#5A6068` to `#484E56`) with deep mortar grooves and lush moss-green crevices (`#486B34`), Worley cellular height + normal map, roughness `0.78–0.92`.
   - `Cell (1, 0)`: **Chiseled Grey Stepping Stone** — Hand-split layered slate flagstone (`#68707A` center, `#7A828C` bevel highlight, `#495058` edge shadow), subtle surface flake normal, roughness `0.75`.
   - `Cell (2, 0)`: **Gatehouse Threshold Stone Slab** — Warm weathered castle ashlar paver (`#6E6A66` to `#585450`), roughness `0.80`.
   - `Cell (3, 0)`: **Trodden Dirt Pathway** — Rich warm damp earth (`#5A4332` to `#463325`) with subtle pebble grit noise, roughness `0.88–0.95`.
   - `Cell (0, 1)`: **Campfire Scorched Ash & Charred Earth** — Radial gradient from warm grey-black ash center (`#262220`) to compacted warm earth rim (`#523C2C`), roughness `0.94`.
   - `Cell (1, 1)`: **Campfire River Stones** — Warm fire-baked grey-brown field stones (`#6B6560` with warm ochre/soot tinting), roughness `0.82`.
   - `Cell (2, 1)`: **Lush Forest Grass & Moss** — Deep rich forest green (`#3E6630` to `#56853E`) for moss patches, log moss blankets, and grass tufts, roughness `0.85`.
   - `Cell (3, 1)`: **Woodland Fern & Shrub Leaf** — Vibrant layered leaf green (`#4E7D38` to `#6CA148`) with central vein normal detail, roughness `0.72`.
   - `Cells (0..3, 2..3)`: Variations for dark wet moss, boulder slate rock (`#5E646C`), pebble scatter, and cliffstone pier footings.

2. **`Tex_GuardpostProps` (`Mat_GuardpostProps`)**:
   - `Cell (0, 0)`: **Heavy Structural Timber** — Warm medium-brown hewn oak beams (`#6E472B` to `#593820`) with pronounced vertical woodgrain normal grooves, roughness `0.82`.
   - `Cell (1, 0)`: **Deck & Wall Planks** — Weathered golden-brown horizontal wood planks (`#7C5233` to `#644026`), plank seam normal map, roughness `0.80`.
   - `Cell (2, 0)`: **Weathered Dark Shingle Roof** — Charcoal-brown split cedar/slate roof shingles (`#3D322C` to `#2E2520`) with staggered shingle-lap normal relief, roughness `0.85`.
   - `Cell (3, 0)`: **Roof & Log Moss Overlay** — Velvety olive-emerald moss (`#4F7836` to `#638E42`), high micro-roughness `0.92`.
   - `Cell (0, 1)`: **Rough Tree Bark (Campfire Logs & Palisade Stakes)** — Deep furrowed dark-brown pine bark (`#4A3222` to `#382417`), strong vertical bark ridges in normal map, roughness `0.90`.
   - `Cell (1, 1)`: **Cut Log End-Grain & Sharpened Stake Tips** — Warm tan sapwood (`#B88A5A` to `#9A6E42`) with concentric growth rings, roughness `0.78`.
   - `Cell (2, 1)`: **Crate & Barrel Wood** — Clean joined pine boards (`#8A5A36`) with frame bevels, roughness `0.78`.
   - `Cell (3, 1)`: **Burlap Grain Sacks & Rope** — Woven coarse tan hemp/burlap (`#B09066` to `#8F724C`) with cross-hatch weave normal, roughness `0.92`.
   - `Cell (0, 2)`: **Hammered Wrought Iron** — Dark gunmetal iron (`#2B2E34`) for barrel hoops, spearheads, window bars, cooking pot, and lantern frame, metallic-look low roughness `0.45`.
   - `Cell (1, 2)`: **Swallowtail Cloth Banner** — Warm weathered ochre-tan fabric (`#A68660` to `#8C6D4B`) with subtle fabric weave and darker border trim, roughness `0.88`.
   - `Cell (2, 2)`: **Glowing Lantern Glass / Warm Amber Core** — Warm golden-amber (`#FFB84D`), roughness `0.25`.
   - `Cell (3, 2)`: **Charred Firewood & Glowing Ember Cracks** — Blackened char (`#1E1A18`) with glowing orange-red ember veins (`#FF6A1A`), roughness `0.85`.

#### 1C. Semantic Mesh Objects in `OutskirtsGuardhouse.fbx`
Build and export the following distinct mesh objects inside `OutskirtsGuardhouse_Prefab` (all static meshes have transforms applied so `location = (0,0,0), rotation = (0,0,0), scale = (1,1,1)` in Blender, and `PivotOffset` / `Pos` recorded in `outskirts_guardhouse_manifest.json`):

1. **`GuardTower_CobblePad`** (`Mat_GuardpostGround`, `CastShadow = false`):
   - Centered at Guardpost-local `(rx = +14.0, ry = 0.0, rz = -13.5)` (plot-local `(26.0, 0, 82.5)`), rotated by `tower_yaw = -18°` so the tower's front-left window faces the pathway/campfire and front-right ladder faces the foreground trail.
   - Thin (`ry = 0.0..0.09`) rounded-rectangle cobblestone base pad (`13.6 × 13.6` studs) composed of:
     - A slightly domed dark-earth/mortar bed (`ry = 0.0..0.04`),
     - ~48 bevelled 3D individual cobblestone slabs (`ry = 0.02..0.09`) in concentric/staggered rings with irregular sizes and slight yaw/height jitter matching the reference image,
     - 14 low-poly 3D green moss & grass tufts tucked around the outer cobble rim and between stones,
     - 4 bevelled square stone pier footings (`1.65 × 0.45 × 1.65` studs) at local tower corners `(±4.3, 0.22, ±4.3)` supporting the 4 timber legs.

2. **`GuardTower_Structure`** (`Mat_GuardpostProps`, `CastShadow = true`):
   - Centered at `(rx = +14.0, ry = 0.0, rz = -13.5)`, `tower_yaw = -18°`:
   - **Substructure (`ry = 0.40..8.20`)**:
     - 4 heavy square chamfered timber corner posts (`0.85 × 7.8 × 0.85` studs) rising from `(±4.3, 0.40, ±4.3)` to `(±4.1, 8.20, ±4.1)` (slight inward batter for a sturdy medieval silhouette).
     - 4 horizontal lower/upper tie beams + **8 diagonal X-brace / knee-brace timbers** (`0.42 × 0.42` cross-section) across all 4 faces of the stilt base, exactly matching the prominent timber cross-bracing in the reference image.
   - **Upper Watch Deck & Balustrade (`ry = 8.20..11.20`)**:
     - Overhanging timber joist frame (`11.2 × 0.55 × 11.2` studs at `ry = 8.20`) topped by 9 bevelled wooden deck planks (`11.6 × 0.28 × 1.22` studs at `ry = 8.55`).
     - Post-and-rail wooden balustrade around all 4 edges (`±5.35` studs from tower center), leaving a `2.6`-stud ladder entry gap on the front-right face (`+X_tower`, near `+Z_tower` corner):
       - 8 chunky corner/intermediate railing posts (`0.52 × 2.65 × 0.52` studs, `ry = 8.65..11.30`) with pyramidal/chamfered caps,
       - Double horizontal railing bars (`ry = 10.85` and `ry = 9.35`) and vertical balusters (`0.22 × 1.40 × 0.22` studs spaced every `1.1` studs).
   - **Elevated Wooden Guard Cabin (`ry = 8.68..16.20`)**:
     - Footprint `7.8 × 7.8` studs centered on the deck:
     - 4 heavy corner timber studs (`0.65 × 6.8 × 0.65` studs) + horizontal clapboard/plank walls (`ry = 8.68..15.40`) + triangular front/back gable walls (`ry = 15.40..18.60`).
     - **Front-Left Lookout Window** (facing `-Z_tower` / pathway): Framed timber window opening (`2.8W × 2.4H` at `ry = 11.0..13.4`) with a thick projecting wooden sill, header lintel, and 4 vertical dark-iron/wooden window bars over a recessed dark interior backing plate.
     - **Front-Right Cabin Doorway & Lantern Bracket** (facing `+X_tower` above the ladder): Framed doorway recess with a wrought-iron lantern arm projecting from the right jamb at `ry = 13.6` holding the hanging lantern housing (`ry = 12.3..13.5`) with an emissive amber glass core.
   - **Steep Wooden Access Ladder (`ry = 0.08..9.10`)**:
     - Positioned on the front-right face (`+X_tower`, offset toward the front corner), leaning from ground `(lx = +6.8, ly = 0.08, lz = +2.4)` up to the deck opening `(lx = +5.35, ly = 8.95, lz = +2.4)`:
     - 2 long chamfered timber side rails (`0.32 × 9.3 × 0.48` studs) + 8 flat horizontal wooden rungs (`0.36 × 0.22 × 2.15` studs).

3. **`GuardTower_Roof`** (`Mat_GuardpostProps`, `CastShadow = true`):
   - Centered above the cabin (`ry = 14.80..19.40`):
   - Steep pitched A-frame gable roof (`pitch = 38°`, eaves overhang `9.8 × 10.2` studs) with exposed rafter tails, thick chamfered timber fascia/bargeboards, and a heavy ridge beam cap.
   - **Individual Layered Shingle Courses**: 7 staggered rows per roof slope of individual 3D bevelled wooden shingles (`~1.1W × 0.18T × 1.45L` studs) with subtle random tilt/yaw/color variation so the roof has the exact chunky, hand-laid medieval shingle silhouette of the reference image.
   - **3D Moss Clumps on Roof Eaves**: Sculpted low-poly velvety green moss patches (`Cell (3, 0)`) clinging to the lower right and lower left shingle courses.

4. **`GuardTower_Props`** (`Mat_GuardpostProps`, `CastShadow = true`):
   - **Under-Tower Clutter (`ry = 0.08..3.80`)**:
     - **Left/Back-Left Under Stilts**: 2 stacked framed wooden supply crates (`2.4×2.2×2.4` and `1.9×1.8×1.9` studs, angled naturally).
     - **Right/Back-Right Under Stilts**: 2 banded wooden barrels (`radius = 1.15, height = 2.8` studs with 2 iron hoops each).
     - **Front-Center Pier Footing Cluster**: 4 plump tied burlap grain sacks (`radius = 0.85..1.05, height = 1.4..1.7` studs, pinched at the neck with a tied flare top and rope collar) resting against the front-center timber leg and cobbles.
   - **Left Flank Weapon Rack & Hanging Banner**:
     - **Spear & Halberd Rack**: Just outside the left stilt frame (`lx = -5.6, lz = -1.2`), a rustic timber A-frame weapon rack (`4.2` studs wide, `3.4` studs tall) holding 5 upright iron-tipped spears/halberds.
     - **Hanging Swallowtail Banner**: Projecting outward from the front-left balustrade post (`lx = -5.4, ly = 11.2, lz = -4.2`), a horizontal timber crossbar supporting a draped ochre-tan swallowtail cloth banner (`2.2W × 4.6H` studs) with twin bottom points.

5. **`Campfire_Area`** (`Mat_GuardpostProps` & `Mat_GuardpostGround`, `CastShadow = true`):
   - Centered at Guardpost-local `(rx = -13.5, ry = 0.0, rz = -6.0)` (plot-local `(-1.5, 0, 90.0)`):
   - **Compacted Dirt & Ash Hearth Pad**: Thin (`ry = 0.0..0.06`, diameter `~13.5` studs) organic dirt clearing with a scorched dark ash bed inside the stone ring.
   - **Stone Fire Ring**: 12 chunky, bevelled, irregular grey-brown river stones (`~1.35W × 0.85H × 1.15D` studs) arranged in a `2.7`-stud radius circle around `(-13.5, 0, -6.0)`.
   - **Charred Firewood & Ember Bed**: Domed glowing ember core (`ry = 0.06..0.55`) topped by 6 crossed charred split logs (`length = 3.2..3.8` studs, tilted inward at `25–35°`).
   - **3 Mossy Felled Log Benches & Chopped Stump**:
     - Arranged in the exact U-formation around the fire ring:
       1. **Back-Left Log Bench**: centered at `(rx = -16.8, ry = 0.85, rz = -9.8)`, `length = 6.8` studs, `radius = 0.92` studs, angled at `yaw = -38°` (facing fire).
       2. **Front-Left Log Bench**: centered at `(rx = -17.2, ry = 0.85, rz = -2.6)`, `length = 6.6` studs, `radius = 0.90` studs, angled at `yaw = +32°` (facing fire).
       3. **Front-Right Log Bench**: centered at `(rx = -9.6, ry = 0.85, rz = -2.4)`, `length = 6.4` studs, `radius = 0.88` studs, angled at `yaw = -32°` (facing fire).
     - Each log has a 10-sided organic cylinder trunk with root/bark taper, flat tan end-grain faces (`Cell (1, 1)`), and a sculpted **green moss cap blanket** (`Cell (3, 0)`) draped along the upper/outer bark surface!
     - **Chopped Tree Stump**: At `(rx = -20.6, ry = 0.65, rz = -6.4)` (`radius = 0.85, height = 1.3` studs with root flares and tan cut top).
   - **Cooking Spit Tripod, Hanging Kettle & Supply Crate**:
     - At `(rx = -10.2, ry = 0.0, rz = -9.2)` (back-right of the fire ring): 2 forked wooden stakes (`2.6` studs tall) supporting a horizontal wooden spit rod with a hanging dark-iron kettle/pot and a tied cloth pouch, plus a framed wooden supply crate (`1.95 × 1.85 × 1.95` studs) at `(rx = -7.8, ry = 0.95, rz = -7.5)`.

6. **`Outskirts_Fence`** (`Mat_GuardpostProps`, `CastShadow = true`):
   - Wraps the outer-left and front-left perimeter of the campfire clearing along the exact chain seen in the reference image:
     - **Section A — Sharpened Timber Palisade (`V0 -> V1 -> V2`)**:
       - Runs from `V0 = (-32.0, 0, -13.0)` (plot-local `(-20.0, 0, 83.0)`, right in front of the left pine tree) through `V1 = (-24.5, 0, -4.0)` to `V2 = (-17.5, 0, +4.5)` (plot-local `(-5.5, 0, 100.5)`).
       - Composed of **14 chunky vertical round/octagonal timber stakes** (`diameter = 0.95..1.15` studs, spaced every `~1.45` studs, heights alternating organically between `3.8` and `4.6` studs) with **conical/faceted sharpened tan wood tips**, bound together on the inner/outer face by two horizontal split-rail binding beams (`ry = 1.2` and `ry = 2.7`).
     - **Section B — Pointed-Post Split-Rail Corner Fence (`V2 -> V3 -> V4`)**:
       - Runs from `V2 = (-17.5, 0, +4.5)` to the front corner post `V3 = (-8.5, 0, +7.0)` (plot-local `(3.5, 0, 103.0)`) and turns north-east to `V4 = (-6.0, 0, +0.5)` (plot-local `(6.0, 0, 96.5)`) right beside the central stepping-stone pathway!
       - Features heavy sharpened square/octagonal corner & intermediate posts (`1.15 × 4.5 × 1.15` studs) connected by two thick horizontal timber rails (`0.38 × 0.55` studs at `ry = 1.35` and `ry = 2.85`).

7. **`Outskirts_SteppingStones`** (`Mat_GuardpostGround`, `CastShadow = false`):
   - Authored in Guardpost-local space so the entire gatehouse apron, connector dirt bed, and chiseled grey stepping stones align seamlessly with `GuardTower_CobblePad`, `Campfire_Area`, and `Outskirts_Fence`:
   - **Gatehouse Flagstone Apron (`rz = -35.0..-26.0`, `rx = -9.5..+13.5`)**:
     - Fits flush against the exterior of `EastOutskirtsGateArch` (plot-local `X = 14, Z = 61..70`): a raised stone curb border (`ry = 0.0..0.14`) enclosing ~22 fitted irregular polygonal ashlar/slate stone slabs (`ry = 0.0..0.12`) with dark mortar seams.
   - **Organic Trodden Dirt Trail Bed (`ry = 0.0..0.04`)**:
     - Smoothly contoured low-profile dirt ribbon (`Cell (3, 0)`) leading from the Gatehouse Apron `(rx = +2.0, rz = -26.0)` down between the Guard Tower and Campfire through `(rx = +0.5, rz = -6.0)` to `(rx = -1.0, rz = +14.0)` and flaring left (`rx = -32.0, rz = +18.0`) and right (`rx = +28.0, rz = +16.0`) along the main trail.
   - **14 Chiseled Grey Polygonal Stepping Stones + Accent Cobbles (`ry = 0.02..0.11`)**:
     - Large, flat, 6–8 sided bevelled grey slate flagstones (`2.8..4.6` studs across, `Cell (1, 0)`) placed at the exact stepping rhythm of the reference image:
       - 5 stones descending from the Gatehouse Apron past the Guard Tower (`(1.8, -22.5)`, `(3.2, -17.5)`, `(0.8, -12.5)`, `(-0.5, -6.8)`, `(-1.2, -1.0)`),
       - 4 stones through the fence-corner junction (`(2.2, +5.2)`, `(-1.8, +10.8)`, `(-3.2, +16.5)`, `(-10.5, +14.8)`),
       - 5 stones along the lower-left and lower-right trail branches (`(-16.5, +15.2)`, `(-23.0, +14.5)`, `(6.5, +12.5)`, `(14.0, +14.8)`, `(21.5, +15.5)`), plus small satellite pebble clusters.

#### 1D. Verification Renders in Blender
- `generate_outskirts_guardhouse.py` must include a `render_preview()` function that sets up EEVEE/Cycles with a cool misty blue-grey world background (`#3B4C5E`), a warm angled key sun, and warm orange-amber point lights at the gatehouse torches, campfire core, and tower lantern, rendering a `1280×900` preview from `rbx_to_blender(-26.0, 42.0, 42.0)` looking at `rbx_to_blender(2.0, 3.5, -12.0)` to `scratch/outskirts_guardhouse_preview.png` so Hydrogen Extra can visually compare the render against the reference image!

---

### Task 2: Export from Blender & Import into Roblox Studio

1. **Run the Blender Generator**:
   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b -P tools/blender/generate_outskirts_guardhouse.py
   ```
   *(If Blender is installed at another path such as `5.1` / `5.3` or via `where.exe blender`, use that binary or the Blender MCP `execute_blender_code` tool.)*
   - Verify that `assets/models/facilities/OutskirtsGuardhouse.fbx`, `assets/models/facilities/outskirts_guardhouse_manifest.json`, and all 6 PNG textures under `assets/models/facilities/textures/outskirts_guardhouse/` are generated without errors and `total_tris < 6500`.
   - Inspect the rendered preview image with `read_file` and compare it side-by-side against the reference image (`media_1794880931388_d85f33f6.jpg`).

2. **Upload PBR Textures & Import FBX into Roblox Studio**:
   - **Option A — Automated Open Cloud / Studio MCP Upload & Import**:
     - Use the Roblox Studio MCP `upload_image` / `store_image` tool (or the user's Studio Asset Manager / 3D Importer) to upload the 6 PBR textures (`Tex_GuardpostGround_Color/Normal/Roughness` and `Tex_GuardpostProps_Color/Normal/Roughness`) and record their `rbxassetid://...` IDs.
     - Import `assets/models/facilities/OutskirtsGuardhouse.fbx` into Roblox Studio via the 3D Importer (`File -> Import 3D`):
       - Ensure **Import As Model** is checked, **Scale Unit** matches `Studs` (or normalize via `ScaleTo` if imported at cm scale `100×`), and all 7 child `MeshPart`s (`GuardTower_CobblePad`, `GuardTower_Structure`, `GuardTower_Roof`, `GuardTower_Props`, `Campfire_Area`, `Outskirts_Fence`, `Outskirts_SteppingStones`) are present.
   - **Option B — Studio Placement & `BundledMeshSpec` Extraction**:
     - In Roblox Studio (via Studio MCP `execute_luau`), parent the imported model under `ReplicatedStorage.Assets.CustomFacilityMeshes` named **`GuardpostOutskirts`**, set `WorldPivot = CFrame.identity`, attach `SurfaceAppearance` instances with the uploaded `ColorMap`, `NormalMap`, and `RoughnessMap` IDs to each `MeshPart`, and read back each `MeshPart`'s `MeshId`, `Size`, `Pos`, and `PivotOffset` so they can be baked directly into `GUARDPOST_OUTSKIRTS_MESHES` in `src/ServerScriptService/Core/PlotFacilityArchitecture.luau` (matching `TRAINING_GROUND_MESHES` and `MARKET_BAZAAR_MESHES`!).

---

### Task 3: Replace Old Guardhouse & Environment in Luau (`PlotFacilityArchitecture.luau`, `OutskirtsEnvironmentBuilder.luau`, `PlotBuildings.luau`)

#### 3A. Update `src/ReplicatedStorage/Shared/Config/FacilityConfig.luau`
- In `FacilityConfig.FacilityLayout.Guardpost` (line 279):
  ```luau
  Guardpost = {
  	Offset = Vector3.new(12, 0, 96),
  	RotationY = math.rad(0),
  	Radius = 22,
  	PromptText = "Guardpost",
  	Keybind = if Enum then Enum.KeyCode.F else ("F" :: any),
  },
  ```

#### 3B. Replace `Arch.BuildGuardPost` in `src/ServerScriptService/Core/PlotFacilityArchitecture.luau`
1. Bump `PrefabVersion` in `Arch.EnsureFacilityPrefabs()` from `15` to `16`.
2. Define the texture constants and `GUARDPOST_OUTSKIRTS_MESHES: { BundledMeshSpec }` table right above `Arch.BuildGuardPost`:
   - Include all 7 mesh specs (`GuardTower_CobblePad`, `GuardTower_Structure`, `GuardTower_Roof`, `GuardTower_Props`, `Campfire_Area`, `Outskirts_Fence`, `Outskirts_SteppingStones`) with their exact `MeshId`, `Size`, `Pos`, `PivotOffset`, `ColorMap`, `NormalMap`, `RoughnessMap`, and `CastShadow`.
3. In `Arch.BuildGuardPost(folder: Instance, centerCF: CFrame): Part`:
   - Create `model = Instance.new("Model")`, `model.Name = "Building_GuardPost"`, `model.Parent = folder`.
   - Call `instantiateBundledMeshes("GuardpostOutskirts", GUARDPOST_OUTSKIRTS_MESHES, model, centerCF)`.
   - **Procedural Fallback**: If `instantiateBundledMeshes` returns `false` (e.g., before Studio asset IDs are populated or in offline Luau CLI tests), build a high-detail procedural version at the exact same Guardpost-local coordinates (`towerCF = centerCF * CFrame.new(14.0, 0, -13.5) * CFrame.Angles(0, math.rad(-18), 0)`, `fireCenter = centerCF * CFrame.new(-13.5, 0, -6.0)`, palisade & split-rail fence along `(-32, 0, -13) -> (-17.5, 0, 4.5) -> (-8.5, 0, 7.0) -> (-6.0, 0, 0.5)`) so offline tests and fallback places match the layout 1:1.
   - **Dynamic VFX & Lighting (Always Attached)**:
     - **Campfire (`fireCenter = centerCF * CFrame.new(-13.5, 0, -6.0)`)**:
       - `CampfireFlameCore` (`Part`, `Ball`, diameter `1.6`, `Enum.Material.Neon`, `Color3.fromRGB(255, 145, 50)`, `Transparency = 0.15`, at `fireCenter * CFrame.new(0, 0.85, 0)`).
       - `PointLight` on `CampfireFlameCore`: `Color = Color3.fromRGB(255, 150, 55)`, `Brightness = 2.4`, `Range = 26`, `Shadows = true`.
       - `CampfireFlames` (`ParticleEmitter` on `CampfireFlameCore`) + `CampfireSparks` (subtle rising ember sparks, `Rate = 6`, `LightEmission = 0.65`).
     - **Guard Tower Hanging Lantern (`towerCF * CFrame.new(4.2, 12.6, 2.2)`)**:
       - `TowerLanternLightHost` (invisible non-colliding `Part` inside the lantern housing):
       - `PointLight`: `Color = Color3.fromRGB(255, 180, 75)`, `Brightness = 1.65`, `Range = 20`, `Shadows = false`.
   - **Invisible Solid Collision Hulls (`CanCollide = true, Transparency = 1, CastShadow = false`)**:
     - `TowerBaseCollider` (`Size = V(9.8, 12.0, 9.8)` at `towerCF * CFrame.new(0, 6.0, 0)`).
     - `CampfireCollider` (`Size = V(5.2, 2.2, 5.2)` at `fireCenter * CFrame.new(0, 1.1, 0)`).
     - `LogBenchCollider_1..3` matching the 3 mossy split-log benches.
     - `FenceCollider_1..4` along the 4 segments of `Outskirts_Fence` (`V0->V1`, `V1->V2`, `V2->V3`, `V3->V4`).
   - **Standardized Root, PromptAnchor & Label Offset**:
     - Call `local interactionPart = finalizeFacilityModel(model, centerCF, V(4, 1.0, 4), V(4.5, 3.8, -10.5))` (keeping `hullSize.Y = 1.0` so `PrimaryRoot` has `CanCollide = false` and players/heroes walk freely along the stepping-stone path!).
     - Set `interactionPart:SetAttribute("BillboardStudsOffset", Vector3.new(9.5, 16.5, -3.0))` so `FacilityLabelController.client.luau` places the `"Outskirts Guard Post"` floating label directly above the Guard Tower's shingled roof peak!

#### 3C. Update `src/ServerScriptService/Core/OutskirtsEnvironmentBuilder.luau`
Update the surrounding wilderness environment in `OutskirtsEnvironmentBuilder.luau` to match the reference image's exact greenery, boulders, and path framing:
1. **`BuildTerrainFloor(folder, origin)`**:
   - Keep `OutskirtsGrounds` (`Size = V(160, 6, 100)`, `CFrame = origin * CFrame.new(0, -3, 110)`, `CanCollide = true, CanTouch = true, CanQuery = true`), updating its base color to rich deep forest meadow green `Color3.fromRGB(56, 88, 42)` (`Enum.Material.LeafyGrass` or `Grass`) with subtle dark-moss tone patches (`Color3.fromRGB(46, 74, 36)` and `Color3.fromRGB(64, 98, 48)`) matching the lush, slightly moody forest floor of the reference image.
   - Keep `GatehouseApron` at `origin * CFrame.new(14, 0.04, 65.5)` (`Size = V(24, 0.12, 9.5)`, `Color3.fromRGB(98, 96, 94)`, `Enum.Material.Slate`) with bevelled stone paver slabs so the apron is always present even on unoccupied plots.
2. **`BuildCurvedPath(folder, origin)`**:
   - Align the connector dirt trail from `(14, 0, 69)` through `(12.5, 0, 88)` to `(11, 0, 108)` and the east-west patrol trail `getPathZ(x)` (`110 + math.sin(x * 0.055) * 6 + math.cos(x * 0.11) * 2.5`) using rich damp-earth brown `Color3.fromRGB(92, 68, 50)` (`Enum.Material.Ground`) and chiseled grey slate stepping stones (`Color3.fromRGB(106, 114, 122)`, `Enum.Material.Slate`) that align with `Outskirts_SteppingStones`.
3. **Trees, Lush Bushes, Woodland Ferns & Mossy Boulders (`Build(folder, origin)`)**:
   - Update `landmarkTrees`, `westernGrove`, `easternGrove`, and `backdropTrees` so conical **Highland Pines** (`HighlandPineTree` via `EnvironmentSpawner.SpawnPine`) frame the exact composition of the reference image while keeping the Guard Tower (`(26, 0, 82.5)`), Campfire (`(-1.5, 0, 90)`), Fence, and Pathway 100% clear:
     - **Left Wall & Fence Framing Pines**: `(-8, 0, 71)` (`scale = 1.05`), `(-22, 0, 78)` (`scale = 1.15`), `(-22, 0, 118)` (`scale = 1.12`), `(-14, 0, 130)` (`scale = 1.05`).
     - **Right Guard Tower & Forest Copse Pines**: `(35, 0, 69)` (`scale = 1.08`), `(44, 0, 74)` (`scale = 1.18`), `(38, 0, 86)` (`scale = 1.02`), `(49, 0, 84)` (`scale = 1.15`), `(34, 0, 104)` (`scale = 1.06`), `(46, 0, 112)` (`scale = 1.18`), `(38, 0, 126)` (`scale = 1.14`), `(52, 0, 124)` (`scale = 1.22`).
     - **Deep Backdrop & Outer Flank Pines**: Keep the 18 outer pines along `Z = 144..154` and `X = ±58..68`.
   - Update `bushes` (`WildForestShrub` via `EnvironmentSpawner.SpawnShrub`, `Berries = false` for clean natural leafy shrubs matching the reference image):
     - Wall base right of gate: `(23.5, 0, 65.5)` (`scale = 0.95`), `(25.0, 0, 69.5)` (`scale = 0.85`).
     - Wall base left of gate: `(0.5, 0, 66.5)` (`scale = 0.90`).
     - Outside the fence corner: `(-9.5, 0, 103.5)` (`scale = 0.92`), `(-2.0, 0, 105.5)` (`scale = 0.88`).
     - Foreground bottom-left: `(-8.5, 0, 123.0)` (`scale = 0.95`), `(-6.0, 0, 129.5)` (`scale = 1.05`).
     - Right of central path beside boulder: `(22.0, 0, 108.5)` (`scale = 1.05`).
   - Add a `buildWoodlandFern(folder, origin, localPos, scale, rotY)` helper creating star-arranged arched green fern fronds (`Color3.fromRGB(76, 122, 54)`, `CanCollide = false`) placed at `(-3.5, 0, 67.5)`, `(-5.2, 0, 104.8)`, `(30.5, 0, 105.5)`, `(36.0, 0, 95.0)`, and `(-16.0, 0, 115.0)`.
   - Update `boulders` (`buildMossyBoulder`) to feature faceted angular grey slate boulders (`Color3.fromRGB(98, 104, 112)`) at `(27.5, 0, 112.0)` (`Size = V(5.2, 3.2, 4.6)`, `RotY = 28`) and `(42.5, 0, 92.0)` (`Size = V(5.6, 3.0, 4.8)`, `RotY = 115`), plus outer trail boulders.

#### 3D. Update `src/ServerScriptService/Core/PlotBuildings.luau`
1. Bump `local VERSION = 42` to `local VERSION = 43`.
2. In the cache validation block (lines 110–123), also verify that `existingGP` (`folder:FindFirstChild("Building_GuardPost")` or stashed via `FacilityPresence`) exists so plots automatically rebuild with v43.
3. Update `MaxActivationDistance` on the `Building_GuardPost` `FacilityHUDPrompt` from `16` to `18`.

---

### Task 4: Update Waypoints & Preserve Wave Defense / Patrol Logic (`OutskirtsRules.luau` & `AdventurerPatrolController.client.luau`)

1. **In `src/ReplicatedStorage/Shared/Util/OutskirtsRules.luau`**:
   - Update `OutskirtsRules.GuardPostCenter = Vector3.new(12, 0, 96)`.
   - Update `OutskirtsRules.GatehouseRunIn` so newly assigned heroes jog right down the stepping-stone path:
     ```luau
     OutskirtsRules.GatehouseRunIn = table.freeze({
     	Vector3.new(14, 0, 66),
     	Vector3.new(13, 0, 84),
     	Vector3.new(11, 0, 108),
     })
     ```
   - Update `OutskirtsRules.CampfireRestSlots` so coma/resting heroes rest right on/beside the 3 mossy split-log benches around the new Campfire `(-1.5, 0, 90.0)`:
     ```luau
     OutskirtsRules.CampfireRestSlots = table.freeze({
     	Vector3.new(-4.8, 0, 86.2),
     	Vector3.new(-5.2, 0, 93.4),
     	Vector3.new(2.4, 0, 93.6),
     	Vector3.new(-6.2, 0, 89.8),
     	Vector3.new(0.8, 0, 86.5),
     })
     ```
   - Update `OutskirtsRules.BuildingAttackTargets` and `OutskirtsRules.SpawnLanes[1..3].BuildingTarget` to target the new Fence/Campfire flank, Central Stepping-Stone Gate, and Guard Tower base (note: all have `Z ∈ [88, 103]`, strictly `< Mid.Z` (`134..135`) `< Spawn.Z` (`150..152`), and well inside `Bounds` `[-75..75] × [62..158]`):
     ```luau
     OutskirtsRules.BuildingAttackTargets = table.freeze({
     	Vector3.new(-3.5, 0, 102.5),
     	Vector3.new(12.0, 0, 98.0),
     	Vector3.new(24.0, 0, 89.5),
     })
     ```
     And in `OutskirtsRules.SpawnLanes`:
     - Lane 1: `Spawn = Vector3.new(-30, 0, 150)`, `Mid = Vector3.new(-12, 0, 134)`, `BuildingTarget = Vector3.new(-3.5, 0, 102.5)`
     - Lane 2: `Spawn = Vector3.new(12, 0, 152)`, `Mid = Vector3.new(12, 0, 135)`, `BuildingTarget = Vector3.new(12.0, 0, 98.0)`
     - Lane 3: `Spawn = Vector3.new(42, 0, 150)`, `Mid = Vector3.new(30, 0, 134)`, `BuildingTarget = Vector3.new(24.0, 0, 89.5)`

2. **In `src/StarterPlayerScripts/Rendering/AdventurerPatrolController.client.luau`**:
   - Update line 907 `local campfireLook = Vector3.new(-1.5, 0, 90.0)` so sleeping/resting heroes face the new campfire center.

---

### Task 5: Automated Testing, Studio Playtest Verification & Build Integrity

1. **Run the Luau Unit Test Suite**:
   ```powershell
   pwsh tests/run.ps1
   ```
   - Verify that all spec suites pass, specifically:
     - `tests/outskirts-waves.spec.luau` (validates `GuardPostCenter`, `GatehouseRunIn`, `BuildingAttackTargets`, `CampfireRestSlots`, `DefenderSlots`, and `SpawnLanes` bounds and north-marching Z order).
     - `tests/afk-facility.spec.luau` (validates Guard Post passive Gold rates and offline rewards).
     - `tests/phase4-progression.luau` (validates Guard Post onboarding lessons and Fortress Tree unlocks).

2. **Verify Project Build Integrity**:
   ```powershell
   rojo build -o build.rbxl
   ```
   - Confirm `build.rbxl` builds cleanly with zero warnings or errors.

3. **Live Roblox Studio Verification (via Studio MCP)**:
   - Trigger `HubOverhaul.RebuildPlotBuildings()` (or start a Studio playtest via `start_stop_play`) and verify:
     1. `Plot_1.PlotBuildings.Building_GuardPost` spawns with all 7 `MeshPart`s (`GuardTower_CobblePad`, `GuardTower_Structure`, `GuardTower_Roof`, `GuardTower_Props`, `Campfire_Area`, `Outskirts_Fence`, `Outskirts_SteppingStones`) and PBR `SurfaceAppearance` textures applied.
     2. `FacilityHUDPrompt` (`[F] Outskirts Guard Post`) is active on `FacilityInteraction`, opens the **Outskirts Guard Post** modal in `FacilityController`, and allows assigning/unassigning Adventurers.
     3. `FacilityLabel_GuardPost` floats cleanly above the Guard Tower shingle roof peak.
     4. Assigned Adventurers jog out of `EastOutskirtsGateArch` down the stepping-stone path, patrol the dirt trail, and defend `Building_GuardPost` against incoming biome waves.
     5. Capture a Studio screenshot from the reference camera angle (`origin * CFrame.lookAt(Vector3.new(-14, 44, 138), Vector3.new(14, 3, 82))`) using `screen_capture` and confirm visual parity with the reference image.
