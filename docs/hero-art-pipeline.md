# Hero Art Pipeline: Design Philosophy and Workflow

This is the guide for remodelling a hero in *Infinite Tower* from a reference image: the costume, the face decal, the hair mesh and the idle stance. It is written to be handed to another LLM or a new contributor as complete context. The rig contract behind it is in `docs/hero-rig-rebuild-plan.md`; this document covers how heroes are dressed and posed on that rig.

Reference examples, done in this order: **Jenna** (Part-built costume), **Han** (costume, generated face, store hair mesh), **Velkist** (costume, generated face, our own Blender hair, signature idle), **Aaron** (costume, generated face, our own Blender hair, signature idle).

---

## 1. Design philosophy

### 1.1 Style target

- **Blocky Roblox body, anime head.** The body is chunky R15 blocks with hard edges and flat colours. The head carries the anime character: a rounded head shape, a hand-drawn face decal and sculpted mesh hair.
- **The silhouette reads at gameplay distance.** Up to 30 heroes are on screen (6 players × 5 heroes), seen from an over-the-shoulder camera. Big shapes first: hair volume, shoulder shapes, coat tails, knee plates. Small details (buckles, laces) are a bonus, never the identity.
- **Interpret the reference; don't copy it.** Reference art is usually a high-detail render. Match its palette, shape language, layering and pose, translated into blocks and a few meshes. Never trace someone else's asset: when told "detail like X, but not the style", take the technique (layered grooved strands) and keep the hero's own cut.
- **Every hero is data.** Costumes, faces, hair placement and poses live in Luau source and generator scripts, so they can be reviewed, diffed and rebuilt. Nothing hero-related is authored only in Studio.

### 1.2 Visual rules (from the style spec)

| Rule | Value |
| --- | --- |
| Construction | Code-built Block/Wedge Parts; Ball/Cylinder sparingly; FileMesh only for allow-listed hair |
| Part budget | ≤ 60 parts per hero, counting the 16 rig parts |
| Edges | Hard 90° corners, flat shading; fake bevels with a Wedge |
| Proportions | 6.1 studs tall; head 1.4 studs; body types change width only; hands are fixed |
| Layering | Shell pieces +0.02–0.05 studs per side; plates 0.04–0.22 thick |
| Palette per hero | Skin, a dark base, a secondary, a metal trim (gold ≈ `200,160,70`), 1–2 accents; 5–7 colours |
| Value floor | No near-black outfit without a light trim on every bone (dark heroes vanish on dark floors) |
| Neon | Only thin accents (≤ 0.3 studs across); never a whole plate (it blooms into a flat blob) |
| Materials | SmoothPlastic, Fabric (cloth), Metal (trim, blades, plates), Neon (accents), Wood (hafts) |
| Gear | Never on the body; weapons and shields come from the weapon system |

### 1.3 Hard constraints (never break)

- **Don't break animations or weapon placement.** Never edit `HeroRigSpec` joints, hand sizes, grip attachments, `HeroSockets` or weapon prefabs while remodelling a hero. A remodel changes `HeroCostumes` data, generator scripts, hair assets, and optionally that hero's clip overrides in `HeroClips`.
- **One bone per piece.** Each costume piece is welded to exactly one body part with an explicit `Weld`. A piece that crosses a joint (cape, coat tail, long hair) must be marked `Loose`; the lint rejects anything else.
- **No external scripts, models or meshes** except allow-listed hair meshes (§4.6) and face images. Free models have shipped obfuscated loader scripts before; inspect any store asset before using it.
- **No copyrighted character art.** Don't use store decals or meshes of existing anime characters; generate our own.

---

## 2. Where things live

| What | Where |
| --- | --- |
| Skeleton, sizes, axis convention | `src/ReplicatedStorage/Assets/HeroRig/HeroRigSpec.luau` |
| Every hero's look (data + lint + mesh allowlist) | `src/ReplicatedStorage/Assets/HeroRig/HeroCostumes.luau` |
| Piece placement math (body-type and head scaling) | `src/ReplicatedStorage/Assets/HeroRig/HeroCostumeMath.luau` |
| Builds Parts/meshes from costume data | `src/ReplicatedStorage/Assets/HeroRig/HeroCostumeBuilder.luau` |
| Builds the bare rig (+ round head mesh) | `src/ReplicatedStorage/Assets/HeroRig/HeroRigBuilder.luau` |
| Poses: weapon clips and per-hero overrides | `src/ReplicatedStorage/Assets/HeroRig/HeroClips.luau` |
| Face generators + PNGs | `assets/faces/make_<hero>_face.py`, `hero_<hero>_face.png` |
| Hair sources and exports | `assets/hair/hero_hair.blend`, `<hero>_hair.fbx`, `<hero>_hair.json` |
| Offline tests | `tests/hero-rig.spec.luau` (run by `pwsh tests/run.ps1`) |
| Studio checks | `tests/studio-hero-rigs.luau`, `tests/studio-hero-model-viewer.luau` |

---

## 3. Rig facts you need

- **Coordinates:** studs, Roblox axes: +Y up, **−Z is the hero's front**, **+X is the hero's right**. When you face the hero, their right is on your left.
- **Body types** (`Slim`, `Standard`, `Heavy`) change torso width/depth and limb thickness only. Heights, hands and the head are shared. Costume pieces are authored on the **Standard** body and scaled horizontally to the others automatically.
- **Head:** a 1.4-stud Part with the built-in rounded head shape (`SpecialMesh`, `MeshType.Head`). **Head pieces are authored for a 1.2-stud head** (`HeroRigSpec.HEAD_AUTHORED_SIZE`) and scaled uniformly by 1.4/1.2 at build time: positions, sizes and mesh scales. Always author head pieces in 1.2-head units, centred on the head's centre.
- **Part sizes (Standard), useful for placing pieces:** UpperTorso 2.0 × 1.6 × 1.0; LowerTorso 2.0 × 0.4 × 1.0; arms and legs 1.0 thick; UpperArm 1.15, LowerArm 1.05, Hand 1.0 × 0.3 × 1.0; UpperLeg/LowerLeg 1.2; Foot 0.3 tall.
- **Pose axis convention** (rotations in degrees on `Motor6D.Transform`):

  | Joint | Positive rotation |
  | --- | --- |
  | Shoulder / hip `+X` | swing the limb forward |
  | Elbow `+X` | bend the forearm (flex) |
  | Knee `−X` | bend the shin back (flex); never positive |
  | Waist / neck `−X` | lean forward / look down; `+Y` turns left |
  | Left shoulder/hip `−Z`, right `+Z` | raise the limb outward |

- **Weapon grip rule:** a held weapon's head points along the hand's forward direction. An arm's shoulder pitch + elbow pitch (+ wrist pitch) tilts the weapon up from "pointing forward": 90° stands a blade upright, and negative values angle it down. Shields mount on the outer face of the left forearm.

---

## 4. Workflow: remodelling a hero from a reference image

Work in this order. Each step is independent enough to review on its own.

### 4.1 Read the reference

Write down, before touching code:
1. **Body build:** Slim, Standard or Heavy. Bulky reference art is Standard or Heavy.
2. **Palette:** 5–7 RGB values: skin, hair, main garment, secondary, leather, metal trim, accent.
3. **Layers per bone:** what sits on the torso (shirt, vest, straps), the arms (sleeves, bands, bracers, gloves), the waist (belt, pouches, sash), the legs (trousers, straps, knee plates, greaves) and the feet (boots, soles).
4. **Hair:** length (where the sides and back end), parting, swoop direction, fringe length, tufts, ponytail.
5. **Face:** expression and eye colour. Users may ask to change the expression; for example Aaron's nervous reference became a stern face.
6. **Stance:** foot width, knee bend, where each hand and weapon is.

### 4.2 Costume data (`HeroCostumes.luau`)

Each hero is one `do ... end` block:

```lua
do
	local skin, shirt, vest = { 244, 208, 172 }, { 236, 234, 230 }, { 92, 52, 42 }
	table.insert(COSTUMES, costume("hero_x", "Heavy", {
		Skin = skin, UpperTorso = shirt, LowerTorso = pants, UpperArm = shirt, LowerArm = shirt, Hand = glove,
		UpperLeg = pants, LowerLeg = greave, Foot = boot,
	}, {
		piece("VestL", "UpperTorso", { 0.7, 1.62, 1.08 }, { -0.68, 0, 0 }, vest, { Material = "Fabric" }),
		-- ...
	}, "rbxassetid://<face image id>"))
end
```

`piece(name, bone, size, position, color, extra)`: size and position are in the bone's space on the Standard body. `extra` can set `Shape` (`Wedge`, `Ball`, `Cylinder`), `Material`, `Rotation` (degrees, `CFrame.Angles` order X, Y, Z), `RelativeTo` (an earlier piece on the same bone) and `Loose`. The helpers `with(...)`, `NEON`, `METAL`, `WEDGE` and `LOOSE` merge these.

Proven recipes (copy and adapt):

| Feature | Recipe |
| --- | --- |
| Open vest/coat | `VestL`/`VestR` (0.7–0.75 × 1.62 × 1.08) at x ±0.66–0.68, plus `VestBack` (2.08 × 1.62 × 0.2) at z 0.48; the gap in front shows the shirt colour |
| V-neck / laced shirt | A skin diamond (0.36–0.42 square, 0.04 thick, `Rotation {0,0,45}`) at y 0.6–0.62, z −0.51; its top half hides inside the head. Laces: two thin bars rotated ±35° |
| Chest strap + buckle | Strap 0.4 × 1.3 × 0.06 at z −0.52; Metal buckle 0.5 × 0.22 × 0.08 |
| Sleeve / forearm bands | Rings 1.06–1.12 wide around the limb, 0.07–0.22 tall; a thin gold rim on top of a bracer |
| Belt with pouches | Belt 2.08 × 0.26 × 1.08; pouches 0.45 × 0.45 × 0.28 at x ±0.62, z −0.66, each with a darker flap `RelativeTo` the pouch |
| Torn sash / tatters | Wedges turned into downward triangles: size `{thickness, height, width}`, `Rotation {0, 90, 180}` (or `{0, -90, 180}` mirrored), `Loose` |
| Coat tails | A back panel 2.1 × 2.0 × 0.12 on the LowerTorso, `Rotation {-8..-10, 0, 0}` so it flares back, `Loose`; side panels optional |
| Knee plates | A gold Cylinder rim (0.1 × 0.6 × 0.6, `Rotation {0,90,0}`) at y 0.42, z −0.53 on the LowerLeg, plus a smaller dark Cylinder plate `RelativeTo` it at offset {0.04, 0, 0} |
| Boots | A shell (1.08 × 0.34 × 1.25) slightly forward on the Foot, plus a thin gold sole underneath |
| Pauldron | A Metal plate on the UpperArm at y ~0.42–0.45, tilted 12–15° about Z, with a gold trim `RelativeTo` it |

Rules of thumb:
- **Count parts as you go:** 16 rig parts + pieces ≤ 60. Typical remodels land at 50–59.
- **Lint failures tell you what to fix.** "X overlaps Head" from a collar means lower it; "overlaps LeftHand" from a cuff means shorten it or move it up the forearm. Mark only cloth and hair `Loose`, never rigid gear.
- **Keep the front of the fists clear.** Blades leave the grip through the front of the hand.

### 4.3 Face decal (generated, then uploaded)

Faces are drawn by small Python scripts with PIL (no external art):
- **Format:** a transparent 512 × 512 PNG, drawn at 4× and downsampled with LANCZOS for smooth edges. The decal stretches across the whole front of the head.
- **Layout** (in 512 space): brows at y ≈ 200–245, eye centres at y ≈ 262–270 and x ≈ 160 and 350, nose stroke around y 300–340, mouth around y 380–400.
- **Building blocks** (see `assets/faces/make_han_face.py`): an almond eye mask, an iris with a vertical gradient clipped to the eye, a pupil and two highlights, a thick upper lash line heavier at the outer corner, a thin lower lid, a lid crease, and polygon brows.
- **Expression levers:**
  - **Determined:** brows angled down toward the nose.
  - **Stern:** low, nearly straight brows and a firm mouth.
  - **Cocky:** pinched brows, half-lidded eyes and a crooked grin with teeth (`make_velkist_face.py`).
  - **Half-lidded / focused:** flatten the top lid curve, which clips the top of the iris.
- **Colours:** match the iris to the character. Make the brows dark when the hair is dark, but **brow colour should follow hair colour** (blond hair → dark gold brows, not black).

Upload (needs Studio MCP connected, and the user's OK the first time):
1. Serve the folder on localhost: `python -I -m http.server 8765 --bind 127.0.0.1` (from `assets/faces`).
2. Call Studio MCP `upload_image` with `http://127.0.0.1:8765/hero_<hero>_face.png`. It returns `rbxassetid://<id>`.
3. Stop the server, then set the ID as the costume's last argument. Optionally confirm with `ContentProvider:PreloadAsync` that it loads.

Faces are image IDs, used directly as `Decal.Texture`. Note: a *Decal* asset ID from the store is not the image ID; load the decal (`InsertService:LoadAsset`) and read `Decal.Texture`.

### 4.4 Hair mesh (Blender → FBX → Studio import)

Hair is the only place a mesh is worth it: Part-built hair can't reach the anime look. Hair is modelled procedurally in Blender through the Blender MCP (`execute_blender_code`) and checked with `look`. The script lives in the chat history and the result in `assets/hair/hero_hair.blend`; regenerate it rather than hand-editing.

**Coordinates in the generator:** write points in Roblox head space (Y up, front −Z, centred on a **1.2-stud reference head**), and convert to Blender with `B(p) = (x, −z, y)`. In Blender the face looks toward +Y, so "front" in `look` is view direction `[0, 1, 0.15]`. A reference head (cylinder r = 0.6, h = 1.2, bevelled) sits at the origin.

**Building blocks:**
- `dome(center, radii, keep)`: a partial ellipsoid for the scalp volume. `keep(x, y, z)` decides how far down it reaches; keep the hairline high at the front (y > ~0.26) and lower at the sides and back.
- `strand(points, width, thick, out_hint, tip)`: a tube along a cubic Bézier with a 6-point cross-section that has a **groove down the outer face**, so it catches light like real strand clumps. `tip` controls how late it tapers: higher is blunter.
- `clump(points, ...)`: 2–3 overlapping strands with jittered spread, length and twist (fixed RNG seed). This gives the "detailed" layered look and uneven tips.

**Shape guidance (lessons from iteration):**
- **Shape first, detail second.** Get length and silhouette right, then add strand detail. The common failure is hair that hangs down in long droopy strands when the reference is short and fluffy.
- Match **where the sides end** (eye level? jaw?), **fringe length** (brows? eyes?), the **swoop direction**, and **crown height**. Swirl the top clumps from an off-centre crown toward the swoop side.
- Avoid narrow "icicle" spikes; prefer wide clumps whose tips flick outward.
- Avoid long tubes lying across the head; they read as bars or headbands.

**Budget:** Roblox imports at most ~20k triangles per mesh, and 30 heroes are on screen. Aim for **4k–8k triangles**: no Subdivision modifier, 6-point cross-sections, 6–7 segments per strand. Detailed with subdivision came out at 56k, so don't.

**Export** (in the Blender script): select only the hair, then `export_scene.fbx(use_selection=True, object_types={'MESH'}, axis_forward='-Z', axis_up='Y', apply_unit_scale=True, bake_space_transform=True)`. Also write `<hero>_hair.json` (vertices in Roblox coordinates + triangles) and print the bounding-box **centre** and **size**. You need both for placement.

**Import (manual):** scripts can't publish meshes yet (`AssetService:CreateAssetAsync` → "not available yet"). The user imports the FBX with **File → Import 3D** in Studio and sends the MeshId (or you find it on the imported MeshPart). Move the imported copy out of Workspace (e.g. to ServerStorage) afterwards.

### 4.5 Placing an imported hair mesh

The Studio importer changes the mesh in a predictable way. Verify it every time by reading the uploaded mesh's vertices (`AssetService:CreateEditableMeshAsync(Content.fromUri(id))` in **Edit** mode; it's blocked on the client) and comparing the extreme-X vertices with the JSON export:
- **Scale:** vertices are stored at **100×** (cm), so use `Mesh.Scale = {0.01, 0.01, 0.01}`.
- **Centring:** vertices are recentred on the **bounding-box centre**, so use the export's centre as the piece `Position`.
- **Rotation:** X and Z come out negated (a **180° turn about Y**), so set `Rotation = {0, 180, 0}`.

Costume piece:

```lua
piece("HairMesh", "Head", { sizeX, sizeY, sizeZ }, { cx, cy, cz }, hairColour, with(LOOSE, {
	Rotation = { 0, 180, 0 },
	Mesh = { MeshId = "rbxassetid://<id>", Scale = { 0.01, 0.01, 0.01 } },
})),
```

- **Allowlist:** add the mesh to `HeroCostumes.MESHES` (`[meshId] = textureId` or `""` for untextured), with a comment naming the source. Untextured meshes take the piece colour, so the hair colour is just the costume colour.
- **Fit pass:** the exported centre is only the modelling position. Look at it in Studio from front, side, back and top. If the hair floats or the scalp shows, lower `cy` (Aaron needed −0.14 in 1.2-head units) and widen X/Z slightly (e.g. `0.0104` instead of `0.01`) so it hugs the round head. Hair modelled with lots of volume above the head needs this; hair centred on the head (Velkist) usually doesn't.
- **Store hair meshes** (Han): load the accessory with `InsertService:LoadAsset` without parenting it, inspect it (no scripts), and read its `SpecialMesh.MeshId/TextureId/Scale` and the Handle's `HairAttachment`. Place it with `hairAccessoryOffset(attachment)` so its HairAttachment meets the top of the 1.2-unit head.

### 4.6 Signature idle stance (`HeroClips.luau`)

Add `Idle = breathe(pose, seconds)` to `Overrides.hero_<id>` (create the block if missing). It only applies while the hero holds their archetype weapon (`OVERRIDE_WEAPON`). Attacks, walk and other states stay generic unless you also override them.

```lua
local stance: Pose = {
	Waist = { -3, 0, 0 }, Neck = { -5, -8, 6 },
	LeftShoulder = { 18, 0, -38 }, LeftElbow = { 62, 0, 0 },
	RightShoulder = { 18, 0, 38 }, RightElbow = { 62, 0, 0 },
	LeftHip = { 6, 0, -13 }, LeftKnee = { -16, 0, 0 }, LeftAnkle = { 10, 0, 13 },
	RightHip = { 6, 0, 13 }, RightKnee = { -16, 0, 0 }, RightAnkle = { 10, 0, -13 },
	RootOffset = { 0, -0.12, 0 },
}
Overrides.hero_x = { Idle = breathe(stance, 3.0), --[[ existing attack overrides ]] }
```

- **Wide stance:** abduct the hips (left −Z, right +Z) and counter-rotate the ankles by the same amount so the feet stay flat. Bend the knees negatively, and drop `RootOffset` y by 0.1–0.15 so the feet stay on the ground.
- **Weapon direction** (from §3): blades out and up means shoulders abducted ~38° with elbows ~60°. A sword held low and angled down means a small shoulder and elbow bend plus a strong negative wrist (−75°). A raised shield means the left shoulder forward ~45° with a slight inward yaw and the elbow ~85°.
- **Character:** a cocky head tilt (`Neck` Y/Z a few degrees), wariness (a slight waist turn), confidence (an upright waist).
- The clip tests require knees ≤ 0, no elbow hyperextension, and loops that end on their first pose (`breathe` handles that).

### 4.7 Verify

1. `pwsh tests/run.ps1` must pass. The `hero-rig.spec` suite runs the costume lint (budget, overlaps, materials, mesh allowlist) and the clip checks.
2. In Studio, after a Rojo sync and a fresh playtest, build the lineup with `tests/studio-hero-model-viewer.luau`. Wrap its body as `return (function() <file> end)()({ Armed = true })`; the file's own function needs its own `end`, so the text ends in `end end)()(...)`.
3. Look at the hero from the front, side, back and top: hair fit, face position, pieces staying attached, weapon in hand.
4. `tests/studio-hero-rigs.luau` in a playtest covers welds, mesh counts and "weapon never touches the head".

---

## 5. Gotchas (each cost an iteration)

- **Command bar module cache:** `require` in Studio's command bar caches modules across calls, so you'll build the *old* hero after editing files. Require a fresh `ReplicatedStorage.Assets.HeroRig:Clone()` (unparented) instead.
- **Playtest copies:** a running playtest uses the code from when it started. After edits, stop, sync and restart before judging the look. Heroes render on the **client** (`Workspace.ClientVisualEntities`), not the server.
- **Edit vs Play:** Studio MCP's Edit DataModel isn't available during Play, and EditableMesh reads are blocked on the client. Read mesh vertices in Edit mode.
- **Wedge orientation:** a WedgePart's tall face is at +Z (back) and its slope faces front/up. For a downward triangle visible from the front, use size `{thickness, height, width}` with `Rotation {0, ±90, 180}`; for a downward point seen from the side, use `{180, 0, 0}`.
- **The head is rounded:** pieces designed for a cube head leave gaps at the corners. Hair must come down over the temples and back of the round head.
- **Neon blooms:** large Neon parts become flat glowing blobs; keep Neon to strips and small gems.
- **Joint-crossing pieces:** collars rising into the head, cuffs reaching the hand, and quivers poking into a bigger head all fail the lint. Move them by 0.05–0.1 studs rather than marking them `Loose`.
- **Temporary Studio objects:** anything built in Edit mode for a preview (lineups, test rigs) must be deleted afterwards, or it is saved into the shared place.

---

## 6. Per-hero checklist

- [ ] Reference read: body build, palette, layers per bone, hair, face, stance (§4.1)
- [ ] Costume block written; within 60 parts; lint clean (§4.2)
- [ ] Face generated (`make_<hero>_face.py`), uploaded, ID set; brows match the hair (§4.3)
- [ ] Hair modelled in Blender at 4k–8k triangles; FBX + JSON exported; centre and size recorded (§4.4)
- [ ] Hair imported by the user; orientation verified; added to `MESHES`; piece placed; fit checked from four sides (§4.5)
- [ ] Idle stance override added; clip tests pass (§4.6)
- [ ] `pwsh tests/run.ps1` passes; Studio lineup reviewed; temporary objects removed (§4.7)
- [ ] Docs updated if a contract changed (`hero-rig-rebuild-plan.md` decisions, `technical_architecture.md` §6.3)

---

## 7. Status (2026-10-28)

| Hero | Costume | Face | Hair | Idle |
| --- | --- | --- | --- | --- |
| Jenna | Part-built, reference-matched | store anime face | Parts (hood) | signature |
| Han | remodelled | generated `121433999720755` | store mesh `15045614397` | weapon default |
| Velkist | remodelled | generated `104592422151826` | ours `109684055929778` | signature (showboat) |
| Aaron | remodelled | generated `135079238224097` | ours `76088495641706` (layered anime curtain bangs + feathered nape ducktail) | signature (wary guard) |
| Catio | remodelled | generated `hero_catio_face.png` | ours `139185116264855` (high-poly UGC shaggy anime wolf-cut) | weapon default |
| Others (7) | original Part-built ports | default smiley | Part blocks | weapon default |

**Aaron update (2026-10-28):** Generated stylized messy anime hair mesh `76088495641706` in Blender (`assets/hair/hero_hair.blend`, `tools/make_aaron_hair_v2.py`), replacing previous placeholders. Features center-left parted curtain bangs, dipping forehead strands, 5-point ridged layered clumps, and flared ducktail nape locks in Sandy Blonde (`#DEC085`). Scaled and positioned in `HeroCostumes.luau` at `{ 1.91, 1.66, 1.58 }` with offset `{ 0, 0.248, 0.061 }`. Verified in Studio across 4 angles with 0 lint errors and 16k passing spec tests.

**Catio remodel (2026-10-28):** Complete rebuild from Steampunk Cat-Miner to Royal Scholar / High Archbishop based on reference image. High-poly Roblox UGC aesthetic hair modelled in Blender (`catio_hair.fbx`, `catio_hair.json`, `hero_hair.blend`, 4,844 tris / 2,558 verts) in Dark Slate Navy (`#2D334A`), featuring center-left curtain bangs, dipping central forehead strands, jaw-framing side cascades, and floating crown ahoge flyaways. Custom stoic anime face generated via PIL (`assets/faces/make_catio_face.py`). Ceremonial white & gold robe costume authored with folded hooded cowl, royal sapphire brooch with silver swag chains, boxy kimono sleeve pauldrons, pleated hakama trousers, and gold-capped heavy boots (44 costume pieces, strictly within the 60-part budget). All 16,498 spec tests pass.
