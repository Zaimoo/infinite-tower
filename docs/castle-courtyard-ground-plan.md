# Castle Courtyard Single-Asset Ground Replacement — Implementation Plan

**Target Pipeline:** Blender 5.x (`tools/blender/generate_castle_courtyard_ground.py`) ➔ Single-Asset FBX & Seamless PBR Textures (`assets/models/facilities/CastleCourtyardGround.fbx` & `assets/models/facilities/textures/castle_courtyard/`) ➔ Roblox Studio (`ReplicatedStorage.Assets.Environment.CastleCourtyard_Ground`) ➔ Luau Integration (`EnvironmentSpawner.luau`, `IslandBuilder.luau`, `HubOverhaul.luau`)  
**Approved Visual Preview:** `C:/Users/enter/.gemini/antigravity/brain/05ae6b20-23ac-40d3-8dc0-cb4a57c46b44/castle_ground_preview_grey_1794915305599.jpg`  
**Original Courtyard Reference:** `C:/Users/enter/.gemini/antigravity/brain/05ae6b20-23ac-40d3-8dc0-cb4a57c46b44/.user_uploaded/media_1794906995107_bd0f34c8.jpg`  
**Stone Texture & Tile Scale References:**
- Mixed flagstone & cobble motif: `C:/Users/enter/.gemini/antigravity/brain/05ae6b20-23ac-40d3-8dc0-cb4a57c46b44/.user_uploaded/media_1794914694724_9a9405e6.jpg`
- Single stone tile scale cue: `C:/Users/enter/.gemini/antigravity/brain/05ae6b20-23ac-40d3-8dc0-cb4a57c46b44/.user_uploaded/media_1794915039770_6f8bcbf1.png`

---

## 1. Visual & Spatial Analysis of the Castle Courtyard

### 1.1 Exact Courtyard Coordinates & Footprint
Inside each plot (`Workspace.WaitingRoomPlots.Plot_1..Plot_8`), the courtyard sits on `FloatingFortressIsland.IslandTopSurface`:
- **Footprint:** `160 × 120` studs (`X ∈ [-80, +80]`, `Z ∈ [-60, +60]` in courtyard-local coordinates).
- **Walking Elevation:** `IslandTopSurface` has `Size = Vector3.new(160, 6, 120)` and `CFrame = CFrame.new(0, -3, 0)` relative to courtyard origin, placing its solid top walking face at courtyard-local **`Y = 0.000`**.
- **Orientation:**
  - `-Z` (`Z = -60`): Front castle wall & `WestBridgeGateArch` facing the Central Crimson Tower bridge.
  - `+Z` (`Z = +60`): Dividing castle wall & `EastOutskirtsGateArch` (`X = +14`) opening onto the Southern Outskirts (`Z ∈ [+60, +160]`).
  - `±X` (`X = ±80`): East & West perimeter castle walls (`FortressWalls`).
  - `(0, 0, 0)`: Center of `PlazaFountain`.

### 1.2 Verified Studio Elevation Clearances
Measured directly from `Workspace.WaitingRoomPlots.Plot_1` in Roblox Studio Edit mode (all heights relative to `IslandTopSurface` top face `Y = 0.000`):

| Instance / Feature | Measured Local Y Bounds | Integration Requirement |
| --- | --- | --- |
| `IslandTopSurface` | `minY = -6.000`, `maxY = 0.000` | Currently `Material = Enum.Material.Grass`, `MaterialVariant = "HubMeadowGrass"`. Keep as `160 × 6 × 120` solid collider (`Slate`), covered by new ground mesh at `Y = +0.020`. |
| `CourtyardGroundTiles` (legacy) | `minY = 0.000`, `maxY = +0.080` | Currently **246 raw Parts** (`DampMossPatch_1..10`, scattered `CourtyardFlagstone` / `MossySunkenStone` / `PerimeterEdgeStone`, plaza rings, radial slabs). Remove completely once replaced. |
| `PlazaFountain` (`Fountain_Base_And_Tiers`) | `bottom = 0.000`, `Size = (25.35, 15.85, 25.35)` | Outer plinth radius is `12.675` studs; concentric plaza inner ring starts outside this edge (`R = 14.0`, `W = 3.2`, inner curb `R = 12.02`). |
| `Building_TrainingGrounds.Arena_Floor` | `centerY = +0.040`, `Size.Y = 0.080` (top `Y = +0.080`) | Floor at `Y = +0.020` clears cleanly underneath `Arena_Floor` (`+0.080`) with zero Z-fighting. |
| `Building_Market.Bazaar_FlagstonePath` | `centerY = +0.0314`, `Size.Y = 0.1128` (top `Y = +0.0878`) | Floor at `Y = +0.020` clears cleanly underneath `Bazaar_FlagstonePath` (`+0.0878`); `Path_Market` meets it smoothly. |
| `Outskirts_Ground` (beyond `Z = +60`) | `minY = +0.020`, `maxY = +0.678` | New courtyard floor at `Y = +0.020` aligns flush across `EastOutskirtsGateArch` (`Z = +60`). |
| `FortressWalls` | `minY = -0.0042` | Walls sit flush on `Y = 0.000`; perimeter skirt on the new ground drops to `Y = -0.200` along `±80, ±60` so no edge gap ever appears. |

### 1.3 Blender ↔ Roblox Coordinate Convention
Matching `tools/blender/generate_outskirts_guardhouse.py` (`1 Blender meter = 1 Roblox stud`):
- **Point conversion:** `rbx_to_blender(rx, ry, rz) = (rx, -rz, ry)`
- **FBX export flags:** `axis_forward="Z"`, `axis_up="Y"`, `apply_unit_scale=True`, `apply_scale_options="FBX_SCALE_UNITS"`, `bake_space_transform=False`, `path_mode="COPY"`, `embed_textures=True`.
- Model pivot sits at courtyard-local `(0, 0, 0)` (`Y = 0.000` walking plane).

### 1.4 What Is Replaced vs. Preserved
- **Removed:**
  1. Green `HubMeadowGrass` (`LeafyGrass`) material on `IslandTopSurface`.
  2. All 10 brown/green `DampMossPatch_1..10` parts.
  3. All scattered `CourtyardFlagstone`, `MossySunkenStone`, and `PerimeterEdgeStone` floor parts.
  4. All 246 parts in `CourtyardGroundTiles` (and its unused 10-mesh `SceneryBake` entry), consolidated into one Blender-authored `CastleCourtyard_Ground` asset.
- **Preserved:**
  - `IslandTopSurface` (`160 × 6 × 120`, `Anchored = true`, `CanCollide = true`, `CanQuery = true`, `CanTouch = false`) remains intact as the fast box collider and coordinate anchor, re-styled to neutral grey `Enum.Material.Slate`.
  - All perimeter `FortressWalls`, `CourtyardAccents` (`GothicBench_*`), `PlazaFountain`, `PlotSpawn`, `PrivateExtractionPad`, `PlotBeaconAnchor`, and all `PlotBuildings` remain untouched in place.

---

## 2. Existing Codebase Contracts to Preserve

| File | Symbol / Contract | Requirement |
| --- | --- | --- |
| `src/ServerScriptService/BaseOverhaul/IslandBuilder.luau` | `IslandBuilder.Build()` & `IslandTopSurface` | Must still emit `IslandTopSurface` (`160 × 6 × 120`, `CFrame = CFrame.new(0, -3, 0)`). Switch `TopMaterial`/`TopColor` to grey `Slate` and spawn `CastleCourtyard_Ground` when template is present. |
| `src/ServerScriptService/Core/PlotBuildings.luau` | `island:FindFirstChild("IslandTopSurface")` (lines 89–96) | Computes plot `surfaceY = top.Position.Y + top.Size.Y / 2` and `origin`. Must remain unchanged at `Y = 0` courtyard-local. |
| `src/ServerScriptService/Core/PlotManager.server.luau` | `island:FindFirstChild("IslandTopSurface")` (line 476) | Uses `IslandTopSurface.Position` as fallback for `PlotBeaconAnchor`. Preserved automatically. |
| `src/StarterPlayerScripts/Rendering/HubPresence.luau` | `HubPresence.ResolvePlotOrigin` (lines 32–40) | Derives client plot origin from `IslandTopSurface` when `PlotBuildings` has not streamed/loaded. Preserved automatically. |
| `src/StarterPlayerScripts/Rendering/PlotBeaconController.client.luau` | `island:FindFirstChild("IslandTopSurface")` (line 115) | Reads `IslandTopSurface` for beacon positioning. Preserved automatically. |
| `src/ServerScriptService/BaseOverhaul/EnvironmentSpawner.luau` | `ApplyGroundMaterials`, `UpgradeExistingScene` | Stop applying `HubMeadowGrass` to `IslandTopSurface`; add `SpawnCastleCourtyardGround` and in-place plot upgrade removing `CourtyardGroundTiles` and spawning `CastleCourtyard_Ground`. |
| `src/ServerScriptService/BaseOverhaul/HubOverhaul.luau` | `HubOverhaul.Version` (line 33) | Bump from `35` to `36` so baked plots rebuild cleanly with the new ground. |

---

## 3. Step-by-Step Implementation Tasks

### Task 1: Create Blender Generator & PBR Texture Baker (`tools/blender/generate_castle_courtyard_ground.py`)

Create `c:\WORK\infinite-tower\tools\blender\generate_castle_courtyard_ground.py` modeled directly on `tools/blender/generate_outskirts_guardhouse.py`.

#### 1A. Asset Structure & Texel Density Decision
- **Single Imported Studio Asset:** `CastleCourtyardGround.fbx` imports into Roblox Studio as one `Model` asset at `ReplicatedStorage.Assets.Environment.CastleCourtyard_Ground` (the exact same single-asset pattern used by `OutskirtsGround.fbx` ➔ `ReplicatedStorage.Assets.Environment.Outskirts_Ground`).
- **Why Seamless Tiling (`64 px/stud`) Beats a Unique Whole-Plot Texture (`6.4 px/stud`):**
  - Roblox caps uploaded textures at `1024 × 1024`. Mapping one unique non-tiling `1024 × 1024` texture across `160 × 120` studs yields only `6.4 pixels/stud`, which blurs badly at player camera height.
  - Using a **toroidally seamless `1024 × 1024` PBR texture** tiled across `16.0 × 16.0` stud cells (`10 × 7.5` repeats across `160 × 120`) delivers **`64 pixels/stud`** crispness (`~205 × 205 px` per flagstone) and **`~50` flagstones across the `160`-stud width**, matching the approved preview (`~45–55` stones wide).
- **Sub-Meshes Inside `CastleCourtyardGround.fbx` (2 `Opaque` `MeshPart`s in 1 Asset):**
  1. `Courtyard_FlagstoneFloor` — Continuous `160 × 120` grey weathered mixed-flagstone & inset cobblestone ground plane (`ry = +0.020`, perimeter skirt to `-0.200`), UV-tiled seamlessly at `16.0` studs/repeat with `Tex_CastleCourtyardStone_{Color,Normal,Roughness}.png`.
  2. `Courtyard_PlazaAndWalkways` — Bevelled 3D concentric fountain plaza rings (`R = 14.0` & `R = 17.8` + inner/outer curbs) and all 7 radial walkways (`Path_BridgeGate`, `Path_SummoningPortal`, `Path_BlacksmithForge`, `Path_Market`, `Path_OutskirtsGate`, `Path_SynthesisChamber`, `Path_TrainingArea`) at `ry = +0.045..0.075`, using `Tex_CastleWalkwaySlate_{Color,Normal,Roughness}.png` for the darker weathered slate stone tone shown in the approved preview.
  - *(Optional `--single-mesh` CLI flag: if you ever want strictly 1 single `MeshPart` total, `--single-mesh` merges `Courtyard_PlazaAndWalkways` into `Courtyard_FlagstoneFloor` using aligned walkway UVs on `Tex_CastleCourtyardStone` and 3D bevel height separation, since Roblox allows one `SurfaceAppearance` per `MeshPart`.)*

#### 1B. Seamless 1024×1024 PBR Texture Sets (`assets/models/facilities/textures/castle_courtyard/`)
1. **`Tex_CastleCourtyardStone_{Color,Normal,Roughness}.png`** (`1024 × 1024`, toroidally seamless):
   - **Layout (`5 × 5` organic mixed pavers per `16 × 16` stud tile):** Irregularly subdivided mix of primary flagstones (`~3.0–3.6` studs), half-width rectangular slabs, and `2×2` / `3×3` inset cobblestone clusters inspired by the reference texture, with slightly jittered rounded mortar joints (`0.12–0.22` stud bevelled gaps) so the floor reads naturally rather than as a rigid checkerboard.
   - **Color Grading (Approved Grey Palette):** Cool weathered castle grey harmonizing with `FortressWalls` (`#3B4048` / `#4E555F`):
     - Primary stone faces: `#565B64` to `#686E78` (subtle per-stone brightness & cool/warm-slate shift, avoiding bright white or muddy brown).
     - Secondary weathered basalt stones: `#484D56`.
     - Recessed gravel mortar & cracks: `#26292E` to `#31353C` with fine gravel speckle and subtle hairline fractures across occasional slabs.
     - **Macro Luminance Normalization:** Apply a high-pass / regional mean balance across the `1024 × 1024` canvas so no single dark spot stands out as a repeating stamp across the `10 × 7.5` courtyard repeats.
   - **Normal Map:** Crisp bevelled slab shoulders, fine stone grain relief, hairline crack grooves, and recessed pebbled mortar bed.
   - **Roughness Map:** `0.74–0.84` on worn stone tops (catching subtle directional sunlight) and `0.90–0.96` inside mortar seams and pitted crevices.

2. **`Tex_CastleWalkwaySlate_{Color,Normal,Roughness}.png`** (`1024 × 1024`, 2×2 atlas with `14px` padded cells):
   - **Cell `(0, 0)` — Walkway Slate Slab:** Darker cool castle slate (`#424750` to `#4E545E`) with subtle stone grain and bevelled edge shading matching `castle_ground_preview_grey_1794915305599.jpg`.
   - **Cell `(1, 0)` — Inner Cobble Trim Inlay:** Tight grey cobblestone strip pattern (`#3B4048` stones, `#22252A` seams) matching the textured center strips on the radial paths in the preview.
   - **Cell `(0, 1)` — Raised Curb Stone:** Slightly lighter weathered ashlar trim (`#525864` to `#5D6370`) for plaza and walkway curb borders.
   - **Cell `(1, 1)` — Deep Mortar & Plinth Backing:** Dark recessed stone (`#282C32`) for bevel skirts and underside faces.

#### 1C. Geometry Specification (`CastleCourtyardGround.fbx`)
- **Triangle Budget:** `< 3,500` triangles total (`Courtyard_FlagstoneFloor` `~1,700` tris + `Courtyard_PlazaAndWalkways` `~1,500` tris).
- **`Courtyard_FlagstoneFloor`:**
  - `32 × 24` quad grid spanning `X ∈ [-80.0, +80.0]`, `Z ∈ [-60.0, +60.0]` (`5 × 5` stud grid spacing).
  - Top surface sits at `ry = +0.020` with tiny deterministic micro-undulation (`±0.005` studs) in open courtyard quadrants, smoothly clamped to flat `ry = +0.020` under walls (`|X| > 72` or `|Z| > 52`), central plaza (`R < 21`), `TrainingArea` (`Arena_Floor`), and `MarketCluster` (`Bazaar_FlagstonePath`).
  - Planar world-space UVs: `u = (rx + 80.0) / 16.0`, `v = (-rz + 60.0) / 16.0` (exact seamless `10.0 × 7.5` tile span).
  - Outer skirt wall extruded down around the perimeter from `ry = +0.020` to `ry = -0.220`.
- **`Courtyard_PlazaAndWalkways`:**
  - Exact coordinates matching `IslandBuilder.luau` lines 149–357:
    - Inner plaza ring: `R = 14.0`, width `3.2`, 16 bevelled slabs (`ry = +0.048`) + inner curb ring (`R = 12.02`, width `0.60`, `ry = +0.075`).
    - Outer plaza ring: `R = 17.8`, width `3.8`, 20 bevelled slabs (`ry = +0.048`) + outer curb ring (`R = 20.23`, width `0.78`, `ry = +0.075`, interrupted at the 7 walkway branch angles `|Δθ| < 0.24` rad).
    - All 7 radial walkways (`Path_BridgeGate`, `Path_SummoningPortal`, `Path_BlacksmithForge`, `Path_Market`, `Path_OutskirtsGate`, `Path_SynthesisChamber`, `Path_TrainingArea`) built as bevelled center slabs (`ry = +0.048`) flanked by raised left/right curb stones (`ry = +0.075`, width `0.78`).

#### 1D. Manifest & Blender Verification Render
- Write `assets/models/facilities/castle_courtyard_ground_manifest.json` recording bounding box size (`160 × ~0.30 × 120`), triangle counts, and texture relative paths.
- Render a `1280 × 960` top-down Cycles/EEVEE verification image (`scratch/castle_courtyard_ground_preview.png`) from `rbx_to_blender(0, 145, 0)` looking at `(0, 0, 0)` with proxy dark walls (`#3B4048`) and central blue fountain so the generated ground can be visually verified against `castle_ground_preview_grey_1794915305599.jpg` before Studio import.

---

### Task 2: Export from Blender, Upload Textures & Import Single Asset into Roblox Studio

1. **Run the Blender Generator:**
   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b -P tools/blender/generate_castle_courtyard_ground.py
   ```
   *(If Blender is installed under another path, resolve with `where.exe blender` or run via Blender MCP `execute_blender_code`.)*
   - Inspect `scratch/castle_courtyard_ground_preview.png` via `read_file` to verify stone tile scale (`~50` across), cool grey colour harmony, zero seams, and clean plaza/walkway alignment.

2. **Upload PBR Texture Maps to Roblox:**
   - Start a local static server in `assets/models/facilities/textures/castle_courtyard/` (`python -I -m http.server 8766 --bind 127.0.0.1`).
   - Upload all 6 PNGs (`Tex_CastleCourtyardStone_{Color,Normal,Roughness}.png` and `Tex_CastleWalkwaySlate_{Color,Normal,Roughness}.png`) via Studio MCP `upload_image` and record the returned `rbxassetid://...` IDs.
   - Stop the local server.

3. **Import `CastleCourtyardGround.fbx` into Studio:**
   - Import `assets/models/facilities/CastleCourtyardGround.fbx` via **File ➔ Import 3D** with **Import As Model** checked, keeping `1 unit = 1 stud` (`Size.X ≈ 160`, `Size.Z ≈ 120`; if imported at cm scale, normalize with `model:ScaleTo(...)`).
   - Name the imported Model **`CastleCourtyard_Ground`**, set `WorldPivot = CFrame.identity`, and parent it under **`ReplicatedStorage.Assets.Environment`**.
   - On both child `MeshPart`s (`Courtyard_FlagstoneFloor` and `Courtyard_PlazaAndWalkways`), ensure a `SurfaceAppearance` child exists with `AlphaMode = Enum.AlphaMode.Opaque` and the uploaded `ColorMap`, `NormalMap`, and `RoughnessMap` `rbxassetid://...` IDs applied, `Material = Enum.Material.Plastic`, `Color = Color3.fromRGB(163, 162, 165)`, `Anchored = true`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `CastShadow = false`.

---

### Task 3: Integrate into Luau (`EnvironmentSpawner.luau`, `IslandBuilder.luau`, `HubOverhaul.luau`)

#### 3A. Update `src/ServerScriptService/BaseOverhaul/EnvironmentSpawner.luau`
1. **Register Texture Constants:** Add `CastleCourtyardStone` and `CastleWalkwaySlate` entries to `EnvironmentSpawner.DefaultGroundTextures` with the uploaded `rbxassetid://...` IDs (for reference and fallback parity).
2. **Prevent `HubMeadowGrass` Override on `IslandTopSurface` (`ApplyGroundMaterials`, lines 232–272):**
   - Explicitly handle `n == "IslandTopSurface"` before the `Grass` / `LeafyGrass` branch:
     ```luau
     if n == "IslandTopSurface" then
     	desc.Material = Enum.Material.Slate
     	desc.MaterialVariant = ""
     	desc.Color = Color3.fromRGB(74, 78, 86)
     	continue
     end
     ```
3. **Add `EnvironmentSpawner.SpawnCastleCourtyardGround(parent: Instance, courtyardCenterCF: CFrame): Model?`:**
   - Look up `findTemplate("CastleCourtyard_Ground")`. If missing, return `nil`.
   - Clone and wrap as a `Model` named `"CastleCourtyard_Ground"`.
   - Reset `PivotOffset = CFrame.identity` on descendant `BasePart`s, apply `Anchored = true`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `Massless = true`, `CastShadow = false`, `Material = Enum.Material.Plastic`, `Color = Color3.fromRGB(163, 162, 165)`, and ensure `SurfaceAppearance.AlphaMode = Enum.AlphaMode.Opaque`.
   - Set `model.WorldPivot = CFrame.identity`, call `model:PivotTo(courtyardCenterCF)`, tag `model:SetAttribute("BlenderEnvAsset", "CastleCourtyard_Ground")`, `model:SetAttribute("GroundVersion", 1)`, and parent to `parent` (`FloatingFortressIsland`).
4. **Upgrade Existing Baked Plots in `EnvironmentSpawner.UpgradeExistingScene(roots)`:**
   - When `EnvironmentSpawner.HasTemplate("CastleCourtyard_Ground")` is `true`, iterate over every `FloatingFortressIsland` found under `roots`:
     - Locate `IslandTopSurface` (`BasePart`); reset `Material = Enum.Material.Slate`, `MaterialVariant = ""`, `Color = Color3.fromRGB(74, 78, 86)`.
     - Destroy any existing `CourtyardGroundTiles` folder (clearing all 246 legacy tiles / `BakedMeshes`).
     - Compute `courtyardOriginCF = CFrame.new(top.Position.X, top.Position.Y + top.Size.Y * 0.5, top.Position.Z) * top.CFrame.Rotation`.
     - If `CastleCourtyard_Ground` is missing or its `GroundVersion` attribute `< 1`, destroy any stale copy and call `EnvironmentSpawner.SpawnCastleCourtyardGround(island, courtyardOriginCF)`.

#### 3B. Update `src/ServerScriptService/BaseOverhaul/IslandBuilder.luau`
1. **Update `IslandBuilder.Config` (lines 31–36):**
   - Change `TopMaterial = Enum.Material.Slate`, `TopColor = Color3.fromRGB(74, 78, 86)`, `DampMossMaterial = Enum.Material.Slate`, `DampMossColor = Color3.fromRGB(58, 62, 70)`.
2. **Update Procedural Fallback (`buildMossyFlagstoneCourtyard`):**
   - Remove the 10 green/brown `DampMossPatch_*` rectangles and replace olive moss tint (`COLOR_MOSS_OLIVE` / `COLOR_DAMP_MOSS`) with weathered grey slate/basalt tones (`#3C4048`, `#4A4F59`, `#2E323A`) so even offline tests and unimported fallback places never show green grass or brown dirt patches inside the castle walls.
3. **Use Single Blender Asset When Imported (`IslandBuilder.Build` lines 504–508):**
   - Require `EnvironmentSpawner` lazily (`pcall(require, script.Parent:FindFirstChild("EnvironmentSpawner"))`).
   - If `envSpawner and envSpawner.HasTemplate("CastleCourtyard_Ground")`:
     - Call `envSpawner.SpawnCastleCourtyardGround(islandModel, CFrame.identity)` and skip building `CourtyardGroundTiles` and `SceneryBake.Apply(..., "CourtyardGroundTiles")`.
   - Else fall back to the updated grey courtyard tile builder.

#### 3C. Update `src/ServerScriptService/BaseOverhaul/HubOverhaul.luau`
- Bump `HubOverhaul.Version` (line 33) from `35` to `36` so the next Studio rebake or server start rebuilds `Plot_1..Plot_8` cleanly.

---

### Task 4: Automated Testing, Build Integrity & Studio Verification

1. **Run Luau Test Suite:**
   ```powershell
   pwsh tests/run.ps1
   ```
   - Confirm all specs pass with zero regressions.

2. **Verify Rojo Build Integrity:**
   ```powershell
   rojo build -o build.rbxl
   ```
   - Confirm `build.rbxl` builds cleanly with zero errors.

3. **Live Roblox Studio Rebake & Visual Verification (via Studio MCP):**
   - Run `tests/studio-rebake-hub.luau` (or `HubOverhaul.Build(true)`) in Edit mode via `execute_luau`.
   - Assert across all 8 plots (`WaitingRoomPlots.Plot_1..Plot_8`):
     - `FloatingFortressIsland:FindFirstChild("CastleCourtyard_Ground")` exists with both `MeshPart`s (`Courtyard_FlagstoneFloor`, `Courtyard_PlazaAndWalkways`) and opaque `SurfaceAppearance` textures.
     - `FloatingFortressIsland:FindFirstChild("CourtyardGroundTiles") == nil`.
     - `IslandTopSurface` has `Material == Enum.Material.Slate`, `MaterialVariant == ""`, `CanCollide == true`.
     - Zero Z-fighting inside `TrainingArea.Arena_Floor` and `MarketCluster.Bazaar_FlagstonePath`, and seamless threshold meeting `Outskirts_Ground` at `EastOutskirtsGateArch`.
   - Capture top-down and ground-level courtyard screenshots with `screen_capture` to verify visual parity against `castle_ground_preview_grey_1794915305599.jpg`.
   - Run a short playtest via `start_stop_play` ➔ `get_console_output` ➔ verify `PlotSpawn`, player movement/collision across the courtyard, and zero runtime errors ➔ `start_stop_play` (stop), then save the Studio place (`Ctrl+S` / `save_place`).
