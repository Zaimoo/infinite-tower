---
name: hero-remodel
description: >-
  Remodel an Infinite Tower hero from a reference image: generate and upload an anime face
  decal, model UGC-style hair in Blender and wire in the user's imported mesh, rewrite the
  hero's costume data, add a signature idle stance, verify in Studio, then commit and open a
  PR. Use when the user shares character art and asks to remodel, restyle or "do the same
  for" a hero, or asks for a new hero face, hair mesh, costume or idle pose.
---

# Hero remodel from a reference image

One hero per branch and PR. The design rules (style, part budget, colours, rig facts, costume
recipes) are in `docs/hero-art-pipeline.md`; read it before the first remodel in a session.
This skill is the procedure, with the lessons that each cost an iteration.

For more than the look (a new hero, its kit, grip, attack animations or skill VFX), use the
`hero-creation` skill and `docs/hero-creation-pipeline.md` instead; they build on this skill.

**Never change** `HeroRigSpec` joints or hands, grip attachments, `HeroSockets` or weapon
prefabs. A remodel touches only that hero's block in `HeroCostumes.luau`, its override in
`HeroClips.luau`, and new files under `assets/faces`, `assets/hair` and `tools/`. That is what
keeps animations and weapon placement working. The one sanctioned rig edit is the `Slim`
numbers in `HeroRigSpec.BODY_TYPES` (pipeline doc §4.2), and only as its own change that
re-lints every `Slim` hero, never inside one hero's remodel.

**Partial restyles** ("redo X's face", "make her body slim") use only the matching steps: §2
for a face, §4.4 for a body switch, §3 and §6 for hair. Several heroes may share one branch
when the user asks for the same change on all of them.

## 0. Set up

1. **Check the folder first.** Another session may share this checkout. Run
   `git branch --show-current` and `git status --short`, and say what you find if it isn't
   what you expect. Never commit on a branch you didn't create for this hero. If tracked files
   have uncommitted changes from other work, ask before switching branches: they would come
   along. (A Valeria commit once landed on another session's branch and had to be moved.)
2. `git fetch origin && git switch -c feat/<hero>-remodel origin/main`. Work in the user's main
   folder: Rojo syncs only from there, so Studio sees the changes. Don't use a worktree unless
   the user agrees (it confused the user: imports and Studio checks both broke).
3. Find the hero: `-- N. NAME` blocks in `src/ReplicatedStorage/Assets/HeroRig/HeroCostumes.luau`,
   the `-- Name (WEAPON):` override in `HeroClips.luau`, and the weapon in `OVERRIDE_WEAPON`.
   The weapon type is fixed by the archetype (see `CLAUDE.md`); if the art shows a different
   item (an orb, a flaming fist), keep the archetype weapon and say the item is not costume.

## 1. Read the reference

Write down: body type (bulky art → `Heavy` or `Standard`; **women are always `Slim`**, see
below), 6–8 RGB colours, layers per bone
(torso, arms, waist, legs, feet, anything behind the back), hair (length, part, swoop
direction, tufts, ponytail), face (expression, eye colour, marks like scars or runes) and the
stance (feet, each hand, the weapon's angle).

## 2. Face decal

1. Derive `assets/faces/make_<hero>_face.py` from the closest existing generator with a small
   Python patch script (string replaces on colours, brow polygon, lid curve, mouth, extras),
   rather than writing one from scratch. Bases:
   - **Male:** `make_han_face.py` (serious, angular), `make_velkist_face.py` (cocky grin).
   - **Female:** always the constant-driven feminine `eye()` from `make_jenna_face.py` (warm,
     open), `make_edis_face.py` (cool, half-lidded: lower `EYE_TOP_PEAK`), `make_eolka_face.py`
     (knowing, warm) or `make_astrea_face.py` (serene, forehead jewel). Tune the module
     constants (`EYE_OUTER`, `EYE_INNER`, `EYE_TOP_PEAK`, `EYE_BOTTOM_PEAK`, `IRIS_CENTRE`,
     `IRIS_RADII`, `LASH_THICK`, `BROW_POINTS`) instead of redrawing. Targets in 512 space: eye
     ~120 wide and 55–65 tall, upper lash 3–4 px at the inner corner thickening to 10–12 px with
     one upward wing, iris radii ~31 × 38 overlapped by the lid, lid shadow, low glow crescent,
     one big catchlight, only the outer third of the lower lid, slim arched brows. Never the
     narrow slit eye of the male faces: the user rejected women's faces drawn that way.
   - Layout: brows y ≈ 200–245, eye centres y ≈ 262–270 at x ≈ 160 and 350, nose 300–340,
     mouth 380–400.
   Brow colour follows hair colour (blond → dark gold, silver → cool grey, not black). If the
   user asks for a different expression from the art (Aaron: nervous → serious), follow the user.
2. Run it with `python -I`, then **look at** `hero_<hero>_face_preview.png`. Fix anything that
   reads wrong (hooked beard lines, a too-thin smile) before uploading.
3. Upload: serve the folder (`python -I -m http.server 8765 --bind 127.0.0.1`, run in the
   background), call Studio MCP `upload_image` with
   `http://127.0.0.1:8765/hero_<hero>_face.png`, then stop the server. Put the returned
   `rbxassetid://…` as the costume's last argument.

## 3. Hair in Blender

1. Derive `tools/make_<hero>_hair_ugc.py` from an existing generator. Copy the helpers block
   (`B`, `shell`, `out_normal`, the scalp `cap()`, `smooth_path`, `ribbon`, `jitter`) from
   `tools/make_jenna_hair_ugc.py` and write only the layout. Closest bases:
   - long or layered: Valeria (`make_valeria_hair_ugc.py`); wavy: Solaris; very long and
     wavy, to the thighs: Astrea
   - ponytail: Eolka (high), Jenna (back)
   - short spiky: Archon, Ignis; swept back with flaring locks: Morrigan
   Set `OUT_DIR`, `NAME`, a new `random.Random(seed)` and the material colour.
2. Run it in Blender: `exec(open(path, encoding="utf-8").read())`, then `look` with
   `mode: angles`, views `[[0,1,0.12],[0.8,0.6,0.2],[1,-0.1,0.1],[0,-1,0.25]]` (front,
   three-quarter, side, back), `target: [<Name>Hair, "RefHead"]`.
3. Iterate on **shape before detail**, comparing each render with the reference side by side.
   The user rejects wrong shapes ("the hair looks inaccurate", "it looks different from this
   image") far more often than missing detail. If they ask for a change from the art ("make
   the hair longer"), change only that. Failures seen so far, and the fix:
   - thin "icicle" spikes, crown of thorns → wider ribbons, `tip` 2.4–2.6, fewer, fatter locks
   - spikes merging into one cone → fan locks from the crown in every direction instead
   - ends forming a straight brim → stagger each lock's end height with `rng.uniform`
   - hooks at strand ends → small outward flick, mostly downward
   - long droopy strands when the art is short and fluffy → shorten, end the sides at eye level
   - locks flaring twice as wide as the art → pull the end points in
   - straight hair when the art is wavy → a sideways sine wobble with amplitude ~0.1
   - scalp showing between locks or at the nape → extend `cap()` lower at the sides and back
4. For hair that reads as hair, texture it (Astrea): a PIL strand atlas
   (`assets/hair/make_<hero>_hair_texture.py`), UVs from `ribbon()`/`cap()`, the colour painted
   into the texture, and `MESHES[meshId] = textureId`. Rules in the pipeline doc §4.4
   "Textured hair". Blender can run headless (`blender -b --factory-startup --python ...`) to
   build, render and export when the Blender MCP is down.
5. Aim for 5k–14k triangles (Roblox's import limit is ~20k). Export with
   `scripts/blender_export_hair.py` (exec it after setting `HAIR`), which writes the FBX, the
   JSON and the `.blend`, and prints the centre and size you need for placement.
6. Send the user the angles render and ask them to import the FBX (File → Import 3D) and send
   the MeshId. **Scripts can't publish meshes** (`CreateAssetAsync` is "not available yet"),
   so this step is always manual. Give the full file path.

While waiting, write the costume with `MeshId = "rbxassetid://<HERO>_HAIR_ID"`. The lint will
fail on exactly that placeholder, which proves the rest of the costume is clean.

## 4. Costume

1. Write the new block in a temp file and apply it with `scripts/replace_costume_block.py`.
   **Don't** `read_text()`/`write_text()` the costume file yourself: on Windows that uses
   cp1252, crashed on the `★` in the headers, and emptied the whole file once. The script
   reads and writes UTF-8 bytes and keeps LF endings (the file is stored as LF; check with
   `git ls-files --eol`).
2. The hair piece, from the export's centre and size:
   ```lua
   piece("HairMesh", "Head", { sx, sy, sz }, { cx, cy, cz }, hair, with(LOOSE, {
       Rotation = { 0, 180, 0 },
       Mesh = { MeshId = "rbxassetid://…", Scale = { 0.01, 0.01, 0.01 } },
   })),
   ```
3. Stay within 60 parts (16 rig + pieces; count `piece(` lines). Only when the user says to go
   over the budget, give the hero its own ceiling in `HeroCostumes.BUDGET_OVERRIDES` (Astrea: 100);
   the lint and `tests/studio-hero-rigs.luau` read it through `HeroCostumes.BudgetFor`. `LOOSE` only silences the
   overlap lint, so use it for hair, cloth, trims on cloth and pieces well behind the back.
   Rigid gear that overlaps a bone (a collar in the chin, a cuff in the hand) gets moved
   0.05–0.1 studs instead. Use the recipes in `docs/hero-art-pipeline.md` §4.2.
4. **Female heroes:** `Slim` body (torso 1.5 × 0.78, limbs 0.7, fists 0.8 wide; grips stay at
   the hand's centre, so weapons don't move), narrow shoulders (no broad pauldrons; shoulder
   pieces stay within the arm's width, ≤ 1.06 across, and lie flat, ≤ 0.15 tall), a cinched
   waist, a skirt or panels that flare ±6–12° below the belt, fitted sleeves and legs, and a
   narrower stance. Armour follows the body instead of widening it. Recipe table:
   `docs/hero-art-pipeline.md` §4.2 "Feminine body".
   - **Switching an existing hero to `Slim`:** change the body type, keep authoring pieces in
     Standard space (they rescale horizontally), then fix what the lint and the look flag:
     shoulder plates wider than the arm, rings around limbs, back pieces now crossing the
     narrower arms, and fist-adjacent cuffs. Re-check the idle pose's weapon in Studio.
   - If `Slim` itself still reads bulky, that is a `HeroRigSpec.BODY_TYPES.Slim` change for all
     women at once, not costume padding (see the "Never change" note at the top).
5. Remove the hero's old pieces that don't fit (neon wings, halos, held orbs). Gear comes from
   the weapon.
6. Pieces behind the back (frames, banners, wings) must sit outside the arms' reach, or the
   arms hide them from the front: banners ended up at x ±3.25 for Solaris.
7. If the hair mesh leaves the cheek bare in front of the ear, add the sideburn recipe from
   the pipeline doc §4.2 (Gide) rather than regenerating the hair.

## 5. Idle stance

Add `Idle = breathe(pose, seconds)` to `Overrides.hero_<id>` in `HeroClips.luau`, with a short
comment, keeping the existing attack overrides. Axis rules are in the pipeline doc §3; knees
must stay ≤ 0. Adding an override can break the `hero-rig.spec` check that a hero *without*
one uses the weapon clip; it uses Han as the example, so repoint it if Han gets an idle.
Weapon angles that work:

- **Staff upright beside the right hip:** `RightShoulder {10,0,28}`, `RightElbow {35,0,0}`,
  `RightWrist {45,-35,0}`. Measured in Studio; guessing put the staff across the face.
- **Sword low and angled forward:** a small shoulder and elbow bend, `RightWrist {-60..-85,0,0}`.
- **Shield raised in front:** `LeftShoulder {45..50,-30,-12}`, `LeftElbow {80..85,0,0}`.
- **Daggers out at the sides:** shoulders `{25,0,±40}`, elbows `{50,0,0}`, wrists `{-70,0,0}`.
- **Wide stance:** hips `{x,0,∓10..16}`, ankles counter-rotated by the same Z, negative knees,
  and `RootOffset` y −0.1 to −0.3 so the feet stay on the ground.

If an arm angle is uncertain, measure it in Studio (sample the weapon's `Grip.WorldCFrame.UpVector`
in root space for a few candidate angles) instead of guessing.

## 6. Wire in the imported mesh

1. **Verify the ID first.** In Studio Edit mode, run the "verify mesh" snippet from
   `references/studio-snippets.md`, and `scripts/export_signature.py <hero>` locally. The vertex
   counts must match (not for textured meshes: UV seams split vertices) and the max-X vertex must mirror the export's (X and Z negated: the
   importer's 180° turn). A user once sent another hero's ID; the counts caught it.
2. Replace the placeholder and add the mesh to `HeroCostumes.MESHES` with a comment naming the
   generator: `scripts/wire_hair_mesh.py <placeholder> <meshId> <comment>`.
3. If an imported copy is in Workspace, mention it so the user can delete it before saving.

## 7. Test and check in Studio

1. `pwsh tests/run.ps1` must pass (add `-LuauDirectory <dir>` if the Luau CLI isn't in the
   default temp folder; on the user's machine it is `D:/luau`, never `-InstallLuau`). Ignore the expected "[The Pit] Request failed" line. Lint
   messages say what to move: "X overlaps Y" means move X 0.05–0.1 studs out of Y.
2. Build a temporary rig with the "temp rig" snippet (it equips the weapon, applies the idle
   pose, and moves the weapon parts with their handles). It requires a **clone** of
   `ReplicatedStorage.Assets.HeroRig`, because the command bar caches modules. Wait for Rojo
   first: the snippet checks a value you just changed and stops if it isn't synced yet.
3. `screen_capture` front (full body), face close-up and back. Check: face visible (a blank face
   right after building is usually the image still loading), hair snug with no scalp at sides
   or back, weapon pose as in the art, back pieces visible.
   - Hair floats or the scalp shows at the sides → lower `cy` by 0.1–0.15 and/or widen X and Z
     scale to ~0.0104 (Aaron).
   - Hair too big all round → scale it uniformly (Jenna: 0.0092).
   - Bald patch at the back that moving the mesh can't cover → fix `cap()` in the generator and
     ask for a re-import.
4. Fix, rebuild, recapture. Delete the temp rig (cleanup snippet) when done.
5. If Studio MCP is disconnected ("protocol version is not supported"), MCP tools only load at
   session start: ask the user to update the Studio MCP plugin and restart the session. You
   can wire the hair from the export numbers meanwhile, but say it is unverified and don't
   commit until the user agrees. When the user says "wait for Studio", stop there until they say
   it is back.

## 8. Commit and PR

Stage only this hero's files (never `sss`, `__pycache__`, `.blend1`, or other sessions' work):
the two HeroRig files, `assets/faces/*<hero>*`, `assets/hair/<hero>_hair*`, and
`tools/make_<hero>_hair_ugc.py`. Conventional commit `feat(heroes): remodel <Hero> from
<their> reference art`. Push, then open the PR with `--body-file` (summary of face, hair,
costume, idle; "Rig, sockets and weapon prefabs are unchanged"; tests and what was checked in
Studio). `gh pr edit` fails on this repo (Projects classic); use
`gh api -X PATCH repos/<owner>/<repo>/pulls/<n>` to edit. Ask before committing, pushing or
force-pushing. If the user asks you to pull from main first, merge `origin/main` into the hero
branch before finishing.

Afterwards, update the status table in `docs/hero-art-pipeline.md` §7 (face, hair mesh,
generator, idle) in the same PR. If the hero exposed a new lesson, add it to this skill and the
pipeline doc in the same PR, and keep `.agents/skills/hero-remodel/` identical to
`.claude/skills/hero-remodel/`.

## Reporting to the user

The user tests in Studio themselves and works through buttons. Each turn: send the face preview
and the hair angles render as files, say what changed and why (especially any rejected
attempt), say exactly what is unverified, and end with the one thing you need from them
(usually the MeshId).
