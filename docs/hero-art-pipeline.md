# Hero Art Pipeline: Design Philosophy and Workflow

This is the guide for remodelling a hero in *Infinite Tower* from a reference image: the costume, the face decal, the hair mesh and the idle stance. It is written to be handed to another LLM or a new contributor as complete context. The rig contract behind it is in `docs/hero-rig-rebuild-plan.md`; this document covers how heroes are dressed and posed on that rig.

All 12 heroes have been through this pipeline (status in §7). The step-by-step procedure for an agent, with helper scripts and Studio snippets, is the `hero-remodel` skill in `.claude/skills/hero-remodel/` (mirrored in `.agents/skills/hero-remodel/`). This document holds the rules and the reasons; the skill holds the steps. Keep the two consistent when either changes.

Good examples to copy from: **Han** (store hair mesh), **Velkist** (cocky face, showboat idle), **Eolka** (feminine face and Slim body, high ponytail, staff idle), **Valeria** (long layered hair), **Solaris** (wavy hair, back-mounted frame and banners), **Astrea** (very long straight hair in two meshes, curtain bangs drawn as arcs; over-budget costume).

---

## 1. Design philosophy

### 1.1 Style target

- **Blocky Roblox body, anime head.** The body is chunky R15 blocks with hard edges and flat colours. The head carries the anime character: a rounded head shape, a hand-drawn face decal and sculpted mesh hair.
- **The silhouette reads at gameplay distance.** Up to 30 heroes are on screen (6 players × 5 heroes), seen from an over-the-shoulder camera. Big shapes first: hair volume, shoulder shapes, coat tails, knee plates. Small details (buckles, laces) are a bonus, never the identity.
- **Women read as women from a distance.** On blocky bodies the shoulder line is the strongest gender cue, so a female hero's silhouette has to be feminine before any detail. That means narrower shoulders, a cinched waist, hips and skirts that flare wider than the waist, slimmer limbs and lighter feet. Bulky male builds (broad pauldrons, boxy chest plates, Heavy bodies) make every hero look like the same man in a different outfit. Armoured women keep their armour, but it follows the body and doesn't widen the shoulders. The recipe is in §4.2.
- **Interpret the reference; don't copy it.** Reference art is usually a high-detail render. Match its palette, shape language, layering and pose, translated into blocks and a few meshes. Never trace someone else's asset: when told "detail like X, but not the style", take the technique (layered grooved strands) and keep the hero's own cut.
- **Every hero is data.** Costumes, faces, hair placement and poses live in Luau source and generator scripts, so they can be reviewed, diffed and rebuilt. Nothing hero-related is authored only in Studio.

### 1.2 Visual rules (from the style spec)

| Rule | Value |
| --- | --- |
| Construction | Code-built Block/Wedge Parts; Ball/Cylinder sparingly; FileMesh only for allow-listed hair |
| Part budget | ≤ 60 parts per hero, counting the 16 rig parts; a hero the user signs off to go over gets its own ceiling in `HeroCostumes.BUDGET_OVERRIDES` (Astrea: 100) |
| Edges | Hard 90° corners, flat shading; fake bevels with a Wedge |
| Proportions | 6.1 studs tall; head 1.4 studs; body types change width only; hands are fixed (`Slim` has narrower fists) |
| Layering | Shell pieces +0.02–0.05 studs per side; plates 0.04–0.22 thick |
| Palette per hero | Skin, hair, a dark base, a secondary, a metal trim (gold ≈ `200,160,70`), 1–2 accents; 6–9 colours |
| Value floor | No near-black outfit without a light trim on every bone (dark heroes vanish on dark floors) |
| Neon | Only thin accents (≤ 0.3 studs across); never a whole plate (it blooms into a flat blob) |
| Materials | SmoothPlastic, Fabric (cloth), Metal (trim, blades, plates), Neon (accents), Wood (hafts) |
| Gear | Never on the body; weapons and shields come from the weapon system |

### 1.3 Hard constraints (never break)

- **Don't break animations or weapon placement.** Never edit `HeroRigSpec` joints, hand sizes, grip attachments, `HeroSockets` or weapon prefabs while remodelling a hero. A remodel changes `HeroCostumes` data, generator scripts, hair assets, and optionally that hero's clip overrides in `HeroClips`.
- **One bone per piece.** Each costume piece is welded to exactly one body part with an explicit `Weld`. A piece that crosses a joint (cape, coat tail, long hair) must be marked `Loose`; the lint rejects anything else. `Loose` only switches off the overlap lint; the piece is still welded to its one bone, so it will clip when that joint bends. Use it for hair, cloth, trims sewn onto cloth (a hem on a skirt) and pieces mounted well behind the back. Rigid gear that overlaps another bone (a collar in the chin, a cuff in the hand) gets moved, not loosened.
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
| Face generators + PNGs | `assets/faces/make_<hero>_face.py`, `hero_<hero>_face.png`, `hero_<hero>_face_preview.png` |
| Hair generators (run inside Blender) | `tools/make_<hero>_hair_ugc.py` (older: `make_aaron_hair_v2.py`, `make_catio_hair_v2.py`) |
| Hair exports | `assets/hair/<hero>_hair.fbx` (for Import 3D), `<hero>_hair.json` (to verify the import), `<hero>_hair_ugc.blend` |
| Procedure, helper scripts, Studio snippets | `.claude/skills/hero-remodel/` |
| Offline tests | `tests/hero-rig.spec.luau` (run by `pwsh tests/run.ps1`) |
| Studio checks | `tests/studio-hero-rigs.luau`, `tests/studio-hero-model-viewer.luau` |

---

## 3. Rig facts you need

- **Coordinates:** studs, Roblox axes: +Y up, **−Z is the hero's front**, **+X is the hero's right**. When you face the hero, their right is on your left.
- **Body types** (`Slim`, `Standard`, `Heavy`) change torso width/depth and limb thickness only. Heights and the head are shared. Costume pieces are authored on the **Standard** body and scaled horizontally to the others automatically.
- **`Slim` is the feminine build:** torso 1.5 × 0.78 (Standard is 2.0 × 1.0), limbs 0.7 thick (Standard 1.0) and fists 0.8 wide (`HandWidth`; every other body uses the 1.0 `HAND_SIZE`). The grips sit at the hand's centre, so weapons are held in the same place. It was slimmed from 1.8 / 0.85 on 2026-11-11 because the women still read as bulky.
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
1. **Body build:** Slim, Standard or Heavy. Bulky reference art is Standard or Heavy. Women are `Slim` (§1.1), even when the art shows armour.
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
| Sideburns (hair mesh leaves the cheek bare) | Hair-coloured pieces on the Head, lying flat on the round head in front of the ear: a Block `{0.07, 0.4, 0.26}` at `{±0.5755, 0.05, -0.2562}` with `Rotation {0, ±24, 0}`, and a Wedge tip `{0.07, 0.3, 0.26}` below it at y −0.3 with `Rotation {0, ±24, 180}`; both `Loose` (Gide) |

**Feminine body** (every female hero, from §1.1). The rig's body types only change width, so the shape comes from the body type plus the costume:

| Feature | Recipe |
| --- | --- |
| Body type | `Slim` (torso 1.5 wide, limbs 0.7, fists 0.8). Never `Heavy`. |
| Shoulders | No broad or stacked pauldrons. Shoulder pieces stay within the arm's width (≤ 1.06 across on the UpperArm) and lie flat (≤ 0.15 tall), or use bare shoulder caps or puffed sleeves. Nothing pokes out sideways past the arm. |
| Waist | A narrow belt or sash, and torso pieces that taper towards the waist (Wedges at the sides of a bodice). Leave the waist as the narrowest point of the silhouette. |
| Hips and skirt | Skirts, tassets and coat panels flare outwards below the belt (`Rotation` ±6–12°), so the hips read wider than the waist. |
| Chest | A bodice, a neckline trim or a fitted breastplate that follows the torso. No boxy, raised chest plates. Never sculpt anatomy. |
| Arms and legs | Slim sleeves or bell sleeves, fitted trousers or leggings, boots without a heavy cuff or wide toe cap. |
| Stance | Narrower feet than male heroes, a slight hip shift or one knee bent inwards, an upright waist. |

If `Slim` still isn't feminine enough, change the `Slim` numbers in `HeroRigSpec.BODY_TYPES` rather than fighting it with costume pieces (every `Slim` hero is a woman, so they all move together). That is a rig change: rerun the lint for every `Slim` hero and check weapons and animations in Studio as `hero-rig-rebuild-plan.md` describes. The rig has no taper, so a waist narrower than the hips still has to come from the costume.

Rules of thumb:
- **Count parts as you go:** 16 rig parts + pieces ≤ 60. Typical remodels land at 50–59.
- **Lint failures tell you what to fix.** "X overlaps Head" from a collar means lower it; "overlaps LeftHand" from a cuff means shorten it or move it up the forearm. Use `Loose` only as §1.3 allows (hair, cloth, trims on cloth, pieces well behind the back), never to hide rigid gear clipping into a bone.
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
  - **Feminine eyes:** tall and rounded, never the narrow male slit. `make_jenna_face.py` and `make_edis_face.py` share an `eye()` driven by constants: the eye is about 120 wide and 55–65 tall in 512 space, the upper lash is a filled band that thickens from 3–4 px at the inner corner to 10–12 px at the outer corner and ends in one smooth upward wing, the iris is large (radii about 31 × 38) with the lid overlapping its top, a soft lid shadow, a glow crescent low in the iris and one big catchlight. Only the outer third of the lower lid is drawn, and the brows are slim and arched. Lower `EYE_TOP_PEAK` (Edis) for a cooler, half-lidded look.
- **Colours:** match the iris to the character. Make the brows dark when the hair is dark, but **brow colour should follow hair colour** (blond hair → dark gold brows, not black).

Upload (needs Studio MCP connected, and the user's OK the first time):
1. Serve the folder on localhost: `python -I -m http.server 8765 --bind 127.0.0.1` (from `assets/faces`).
2. Call Studio MCP `upload_image` with `http://127.0.0.1:8765/hero_<hero>_face.png`. It returns `rbxassetid://<id>`.
3. Stop the server, then set the ID as the costume's last argument. Optionally confirm with `ContentProvider:PreloadAsync` that it loads.

Faces are image IDs, used directly as `Decal.Texture`. Note: a *Decal* asset ID from the store is not the image ID; load the decal (`InsertService:LoadAsset`) and read `Decal.Texture`.

### 4.4 Hair mesh (Blender → FBX → Studio import)

Hair is the only place a mesh is worth it: Part-built hair can't reach the anime look. Hair is modelled procedurally in Blender through the Blender MCP (`execute_blender_code`) and checked with `look`. Each hero has a generator script in `tools/make_<hero>_hair_ugc.py`; change and rerun the script rather than hand-editing the mesh, so the hair stays reproducible.

**Coordinates in the generator:** write points in Roblox head space (Y up, front −Z, centred on a **1.2-stud reference head**), and convert to Blender with `B(p) = (x, −z, y)`. In Blender the face looks toward +Y, so "front" in `look` is view direction `[0, 1, 0.12]`. A reference head (`RefHead`) sits at the origin.

**Building blocks** (the helpers at the top of `tools/make_jenna_hair_ugc.py`; copy them, write only the layout):
- `cap()`: the scalp shell. It must reach down over the temples, behind the ears and to the nape, or the round head shows through between locks.
- `ribbon(path, width, thick, ...)`: one lock, a flat strip with a groove down its outer face so it catches light like a strand clump, tapering to a tip. `smooth_path` turns a few control points into a curve; `out_normal` keeps the lock's face pointing away from the head; `shell` gives it thickness.
- `jitter` with a fixed `random.Random(seed)`: uneven spread, length and twist, so the locks look layered rather than stamped.

**Shape guidance (lessons from iteration):**
- **Match the reference's silhouette before adding detail.** Most rejected attempts were the wrong shape, not too little detail: "the hair looks inaccurate", "it looks different from this image". Compare the `look` render with the reference side by side: where the sides end (eye level? jaw? chest?), fringe length, parting, swoop direction, crown height, and any ponytail or long fall.
- When the user asks for a change from the reference ("make the hair longer"), change only that and keep the rest of the cut.
- Avoid narrow "icicle" spikes and crowns of thorns; prefer fewer, wider locks whose tips flick outward a little.
- Fan the top locks out from the crown in every direction, or the spikes merge into one cone.
- Stagger the ends' heights, or they form a straight brim.
- Avoid long tubes lying across the head; they read as bars or headbands.
- Wavy art needs a sideways wobble in the locks (amplitude around 0.1); straight locks read as a different character.

**Budget:** Roblox imports at most ~20k triangles per mesh, and 30 heroes are on screen. Aim for **5k–14k triangles**: no Subdivision modifier. One attempt with subdivision came out at 56k.

**Textured hair (Astrea).** A flat colour reads as plastic strips. To read as hair, give the mesh UVs and a strand texture, as UGC hair does:
- **Texture:** `assets/hair/make_<hero>_hair_texture.py` draws our own atlas with PIL. It is 1024 × 1024 in four 256-px columns, and each column is one lock, root at the top and tip at the bottom. It has fine strand lines, a few soft clump grooves, darker roots fading to bright tips, a soft shine band near the root and shading across the lock. Columns 0–1 are outer variants; 2–3 are darker and cooler, for inner layers and the scalp, so the layers separate. Upload it like a face decal.
- **UVs in the generator:** `ribbon()` maps u across the lock (`PROFILE_U`) and v along it (v = 1 at the root) into a random column (`inner=True` picks 2–3), using its own `random.Random` so texture choices never change the shape. `cap()` maps the scalp to an inner column with strands running down from the crown. Use a flat card profile: the texture carries the detail, not a ridge.
- **Colour:** a textured mesh ignores the part colour, so paint the colour into the texture (one texture per hair colour). List it as `MESHES[meshId] = textureId` and set the piece's `Mesh.TextureId` to match.
- **Layering rules that keep cards clean:** neighbouring crown cards alternate depth (they overlap near the crown), long falls stay under the crown layer until below its tips, and nothing starts from `hang()`'s front-part root behind the head. Crossing cards show as a criss-cross lattice.

**Export:** exec the skill's `scripts/blender_export_hair.py` after setting `HAIR` and `OUT_DIR`. It exports the FBX (`axis_forward='-Z'`, `axis_up='Y'`, `bake_space_transform=True`), writes `<hero>_hair.json` (vertices in Roblox coordinates plus triangles) and the `.blend`, and prints the bounding-box **centre** and **size**. You need both for placement.

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
- **Verify the ID before wiring it.** The vertex count of the uploaded mesh must match the export, and its min-X vertex must mirror the export's max-X vertex (skill §6). A mesh with UVs comes back with more vertices (the importer splits them along texture seams), so for textured hair rely on the mirrored min-X vertex and the size. A user once sent another hero's MeshId, and this check caught it.
- **Fit pass:** the exported centre is only the modelling position. Look at it in Studio from front, side, back and top. If the hair floats or the scalp shows, lower `cy` (Aaron needed −0.14 in 1.2-head units) and widen X/Z slightly (e.g. `0.0104` instead of `0.01`) so it hugs the round head. If it is too big all round, scale it uniformly (Jenna uses `0.0092`). A bald patch at the back or sides that moving the mesh can't cover means the scalp `cap()` is too short: fix the generator and re-import.
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
- **Weapon direction** (from §3): blades out and up means shoulders abducted ~38° with elbows ~60°. A sword held low and angled down means a small shoulder and elbow bend plus a strong negative wrist (−75°). A raised shield means the left shoulder forward ~45° with a slight inward yaw and the elbow ~85°. A staff upright beside the right hip is `RightShoulder {10,0,28}`, `RightElbow {35,0,0}`, `RightWrist {45,-35,0}`. That one was measured in Studio after a guessed pose put the staff across the face, so measure rather than guess when a weapon passes near the head.
- Heroes without a weapon swing (Valeria's tome) can use their own idle helper, such as `floatIdle`; it must still loop cleanly.
- **Character:** a cocky head tilt (`Neck` Y/Z a few degrees), wariness (a slight waist turn), confidence (an upright waist).
- The clip tests require knees ≤ 0, no elbow hyperextension, and loops that end on their first pose (`breathe` handles that).

### 4.7 Verify

1. `pwsh tests/run.ps1` must pass (add `-LuauDirectory <dir>` if the Luau CLI isn't in the default temp folder). The `hero-rig.spec` suite runs the costume lint (budget, overlaps, materials, mesh allowlist) and the clip checks. The "[The Pit] Request failed" line is expected.
2. **Quick check in Edit mode (preferred for a single hero):** build a temporary rig with the skill's "temp rig" snippet (`references/studio-snippets.md`). It equips the archetype weapon, applies the idle pose, and stops if Rojo hasn't synced your latest edit. Capture front, face close-up and back with `screen_capture`, then delete the rig.
3. **Full lineup in a playtest:** after a Rojo sync and a fresh playtest, run `tests/studio-hero-model-viewer.luau`. Wrap its body as `return (function() <file> end)()({ Armed = true })`; the file's own function needs its own `end`, so the text ends in `end end)()(...)`.
4. Look at the hero from the front, side, back and top: hair fit, face position, pieces staying attached, weapon in hand, back pieces visible past the arms.
5. `tests/studio-hero-rigs.luau` in a playtest covers welds, mesh counts and "weapon never touches the head".
6. If Studio couldn't be checked (for example the MCP was disconnected), say so, and don't commit until the user has looked or agrees.

---

## 5. Gotchas (each cost an iteration)

- **Command bar module cache:** `require` in Studio's command bar caches modules across calls, so you'll build the *old* hero after editing files. Require a fresh `ReplicatedStorage.Assets.HeroRig:Clone()` (unparented) instead.
- **Playtest copies:** a running playtest uses the code from when it started. After edits, stop, sync and restart before judging the look. Heroes render on the **client** (`Workspace.ClientVisualEntities`), not the server.
- **Edit vs Play:** Studio MCP's Edit DataModel isn't available during Play, and EditableMesh reads are blocked on the client. Read mesh vertices in Edit mode.
- **Wedge orientation:** a WedgePart's tall face is at +Z (back) and its slope faces front/up. For a downward triangle visible from the front, use size `{thickness, height, width}` with `Rotation {0, ±90, 180}`; for a downward point seen from the side, use `{180, 0, 0}`.
- **The head is rounded:** pieces designed for a cube head leave gaps at the corners. Hair must come down over the temples and back of the round head.
- **Neon blooms:** large Neon parts become flat glowing blobs; keep Neon to strips and small gems.
- **Joint-crossing pieces:** collars rising into the head, cuffs reaching the hand, and quivers poking into a bigger head all fail the lint. Move them by 0.05–0.1 studs rather than marking them `Loose`.
- **Temporary Studio objects:** anything built in Edit mode for a preview (lineups, test rigs, the imported hair MeshPart) must be deleted afterwards, or it is saved into the shared place.
- **File encoding:** `HeroCostumes.luau` contains `★` and is stored with LF endings. Writing it with Python's default encoding on Windows (cp1252) crashed mid-write and left the file empty. Edit it with the skill's `replace_costume_block.py` and `wire_hair_mesh.py`, which write UTF-8 bytes and keep LF.
- **Work in the main checkout, not a worktree:** Rojo syncs from the main folder only, so a worktree's edits never reach Studio and its files are hard for the user to find.
- **Back pieces hidden by the arms:** frames, banners and wings behind the back must clear the arms' swing, or the front view hides them (Solaris's banners ended up at x ±3.25).
- **Idle overrides and the spec:** `hero-rig.spec` checks that a hero *without* an idle override uses the weapon clip, using Han as the example. If Han gets an idle override, point that check at another hero.
- **Studio MCP disconnects** ("protocol version is not supported"): MCP tools only load at session start, so the user has to update the plugin and restart the session. The Studio ID also changes when Studio restarts; get it again with `list_roblox_studios`.

---

## 6. Per-hero checklist

- [ ] Reference read: body build, palette, layers per bone, hair, face, stance (§4.1)
- [ ] Female hero: `Slim` body, narrow shoulders, cinched waist, flared hips (§4.2)
- [ ] Costume block written; within 60 parts; lint clean (§4.2)
- [ ] Face generated (`make_<hero>_face.py`), uploaded, ID set; brows match the hair (§4.3)
- [ ] Hair generator `tools/make_<hero>_hair_ugc.py` written; silhouette matches the reference; 5k–14k triangles; FBX + JSON exported; centre and size recorded (§4.4)
- [ ] Hair imported by the user; MeshId verified against the export; added to `MESHES`; piece placed; fit checked from four sides (§4.5)
- [ ] Idle stance override added; clip tests pass (§4.6)
- [ ] `pwsh tests/run.ps1` passes; checked in Studio (or marked unverified); temporary objects removed (§4.7)
- [ ] One branch and PR for this hero, with only this hero's files staged
- [ ] Docs updated if a contract changed (`hero-rig-rebuild-plan.md` decisions)

---

## 7. Status (2026-11-11)

Every hero's hair is our own Blender mesh except Han's, which is a Creator Store hair. Every face is our own generated decal.

| Hero | Face | Hair mesh | Hair generator | Idle |
| --- | --- | --- | --- | --- |
| Han | `121433999720755` | store `15045614397` | — | weapon default |
| Aaron | `135079238224097` | `76088495641706` | `make_aaron_hair_v2.py` | wary guard |
| Catio | `121586827857415` | `139185116264855` | `make_catio_hair_v2.py` | weapon default |
| Valeria | `75911538426683` | `119546665528137` | `make_valeria_hair_ugc.py` | floating tome (`floatIdle`) |
| Ignis | `137040425989997` | `101701313703578` | `make_ignis_hair_ugc.py` | brawler |
| Jenna | `79233691033516` | `107250648665529` (scale 0.0092) | `make_jenna_hair_ugc.py` | ready stance |
| Velkist | `104592422151826` | `109684055929778` | `velkist_hair.blend` | showboat |
| Eolka | `128405793720315` | `123421721359927` | `make_eolka_hair_ugc.py` | poised (staff) |
| Morrigan | `134987323511884` | `132434150044694` | `make_morrigan_hair_ugc.py` | planted |
| Sovereign Archon | `104359124032831` | `139133902834118` | `make_archon_hair_ugc.py` | prowl |
| Solaris | `89614314986771` | `116753377442189` | `make_solaris_hair_ugc.py` | sunward (staff) |
| Astrea | `84469832141456` | head `79290192354958` + back fall `98817994028995`, textured `126451381570698` | `make_astrea_hair_ugc.py`, `make_astrea_hair_texture.py` | poised mid-draw; own Basic, Special (charged draw) and Skill (360° pirouette, sky shot) clips |

Open issues:
- **Female heroes predate the feminine-body rule (§1.1).** Jenna, Edis, Aeli, Eolka, Solaris and Astrea are `Slim` (Eolka's pauldrons became flat shoulder caps, and Solaris's and Astrea's side skirts flare from the belt). Valeria is still `Standard` with broad pauldrons: switch her to `Slim` and slim her shoulder pieces, then run the lint, because pieces rescale with the body.
- **Faces predating the feminine eye (§4.3).** Jenna, Edis, Eolka and Astrea use the constant-driven feminine `eye()`. Valeria's and Solaris's faces still use the older narrow eye.
