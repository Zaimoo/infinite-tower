---
name: hero-creation
description: >-
  Create or rework an Infinite Tower hero end to end: catalog data and its own kit (new
  mechanics in HeroSkillEffects, server-picked targets sent as cosmetic marks), its look
  (face decal, UGC-style or textured hair, costume), a per-hero weapon grip, its own idle,
  walk and attack animations, and its own skill VFX (styles, chargers, mirror clones,
  renderer blinks), then verify in tests and Studio and ship. Use when the user asks for a new
  hero, a hero's kit, animations, stance, grip or VFX, or says a hero's attacks "look
  default", "don't match the description" or need to "pop"; use hero-remodel instead for a
  look-only remodel.
---

# Hero creation

The rules and reasons are in `docs/hero-creation-pipeline.md` (read its §1 and §12 before
starting) and, for the look, `docs/hero-art-pipeline.md`. This skill is the procedure. It
reuses the `hero-remodel` skill's scripts (`.claude/skills/hero-remodel/scripts/`) for the
look; its own helpers are in `scripts/` and `references/` here.

**The description is the spec.** Before writing code, list every verb in the kit text a
player will expect to see (splits, bounces, blinks behind and back, five clones, rains) and
plan where each one is drawn. Read flavour words in names as flavour ("Shatterdance" is not a
dance), and literal promises as literal ("five mirror clones" means five visible clones).

## 0. Set up

1. `git branch --show-current` and `git status --short`. Work where the user said (the Gilded
   Mirror heroes all went on `feat/mirror-heroes-core`); otherwise branch from `origin/main`.
   Work in the main folder: Rojo syncs from there.
2. Make a task list with one step per phase below that applies.
3. Find the hero's existing pieces: seed (`HeroCatalog`), kit (`ArchetypeCombatSkills`), costume
   block (`-- N. NAME` in `HeroCostumes`), clip override (`Overrides.hero_<id>` and
   `OVERRIDE_WEAPON` in `HeroClips`), grip (`HeroSockets.HERO_GRIPS`), VFX recipe
   (`SkillVfxCatalog.Heroes`).
4. Files with CRLF endings (`git ls-files --eol <file>`): patch with
   `scripts/patchlib.py` (run from the repo root), which keeps endings. Write multi-line patch scripts with the Write tool
   and run them with `python -I`: bash heredocs with quotes and backticks have broken here.

## 1. Data and kit (new hero, or a kit rework)

1. Seed in `HeroCatalog.Seeds` (copy one of the same archetype), banner pool entries, rarity
   colours if the tier is new. Bump count assertions in `tests/hero-rig.spec.luau` and
   `tests/combat-vfx.spec.luau`.
2. Kit override in `ArchetypeCombatSkills` (`hero_<id> = { Archetype, Basic, Special, Skill,
   Passive? }`): names, descriptions written as promises, and only the numbers that differ.
   Keep the archetype's damage budget unless the user decides otherwise.
3. Set `Ticks`/`TickSeconds` to the number of on-screen beats (cuts, clones, waves), and
   `CastSeconds` long enough for the Skill to read. Tell the user when this holds the hero
   longer.
4. New mechanics: a `SecondaryEffect` (Special) or `Effect` (Skill) in `HeroSkillEffects`,
   with the archetype path as fallback; timed buffs on the sim hero, read in
   `CombatSimulation`.
5. If the visual needs a server decision before impact (a second target), follow the
   `TWIN_MARK` pattern (pipeline doc §5.4): public pick function, pick at the cue, store on the
   impact, broadcast a cosmetic `CombatVFX` message before `HERO_CUE`, reuse the pick at the
   hit while valid, and expose it through `PlayArgs` in `EntityRenderer.attackArgs`.
6. Tests through `HeroSkillEffects.Resolve` with fake mobs: numbers, fallbacks, promises.
7. GDD §4.4: ledger row and a mechanics line; §4.1 if the roster changed.

## 2. Look

Follow the `hero-remodel` skill (face, hair, costume) with these defaults:

- **Hair is UGC style:** `curtain` base, `clump` locks (fringe `tip` ≈ 5 for shallow points),
  layered fringe, framing clumps far enough forward to read from the front, a varied back
  layer, braids that the back hair gathers into in ordered slots. Copy the helpers and closest
  layout from `tools/make_isabelle_hair_ugc.py` (braid) or `tools/make_nyx_hair_ugc.py` (bob,
  textured).
- **Two-colour hair:** UVs with V by height (clamped 0.02–0.98) and a gradient texture from a
  PIL generator next to the export. **Strand textures** map along each lock instead (V root to
  tip, U across, a random slice per lock; written before `remove_doubles`), so the lines follow
  the hair: `tools/make_caspian_hair_ugc.py`; upload the texture like a face decal; `MESHES[mesh] =
  texture`; verify the import by the mirrored extreme vertex (counts differ).
- **Blender MCP down?** Run headless with `scripts/run_hair_headless.py` (see its docstring),
  which renders front, three-quarter, side and back. Stitch them and compare with the art; fix
  shape before detail; send the user the angles and the FBX path, and ask for the MeshId.
- Accessories that must sit on the eyes (monocles, marks) go in the face decal.
- After wiring the real mesh, run the tests again: the lint shows problems the placeholder hid.
- **Fit pass:** scale the hair down about the head (pipeline doc §6.2a: anchor `(0, 0.2, 0.04)`,
  try `k` 1 / 0.92 / 0.88 on head-only rigs) so it hugs the head instead of floating.

## 3. Grip (only when the user asks)

1. Add `HeroSockets.HERO_GRIPS.hero_<id>.<WEAPON>.<Main|Assembly> = { Reverse?, Shift?, Offset? }`.
2. Build the hero in Studio with the weapon and look at every current pose: all of them change.
3. Re-pose the clips (step 4). Grip facts are in pipeline doc §7 (forward vs reverse blade, bow
   cant about LeftWrist Y, upper-arm twist for a forearm across the chest).

## 4. Animation

1. `Overrides.hero_<id>` in `HeroClips` with a comment block describing each state:
   - `Idle = breathe(pose, seconds)` from the art's stance or the user's pose reference.
   - `Move = walk(upperBody)` when the idle is a guard the hero should keep while walking.
   - `AttackBasic`, `AttackSpecial`, `AttackSkill` with `signature(duration, keys, markers)`,
     one beat per described action, a `Charge` marker where a wind-up effect starts and a
     `Release` where the hit lands.
2. **`Release` sets the server's hit time** (`HeroActionTiming.ReleaseFraction`); keep it where
   the strike key is.
3. If an effect moves the hero (a blink), keep the clip's root motion small.
4. Measure in Studio with the line-up snippet in `references/studio-snippets.md`: one rig per
   key frame, or one per candidate joint value; capture from the front (the most positive X is
   on the viewer's left); pick by eye; then delete the rigs.
5. Clip rules (tests): knees ≤ 0, no elbow hyperextension, waist yaw within ±180°, loops end on
   their first pose.

## 5. VFX

1. Recipe in `SkillVfxCatalog.Heroes.hero_<id>`: a `Palette` from the art's glow (`Primary`),
   gilt or metal (`Secondary`), a pale `Core`, a deep `Accent`; one `Style` per tier.
2. New styles: register in `SkillVfxCatalog.Styles`, write the player in `SkillVfx` (`PLAYERS`)
   and a charger for wind-ups (`CHARGERS`). New recipe knobs go on `TierRecipe` with a comment.
3. Draw every described verb. Patterns (pipeline doc §9.5): bounce or chain with
   `afterHits`; split toward `Twin()`; clones with `MirrorClones` (charger raises and parks
   them, player takes over, safety timer); blink with `PlayArgs.Blink` (charger leaves a clone,
   streaks out, return streak shatters the clone).
4. Make it pop (pipeline doc §9.4): layered bursts, white core flashes, gilt glints, ground
   shockwaves, motes, wakes that linger, camera shake; sizes 3–10 studs and durations 0.3–0.7 s
   for Specials and Skills. Keep Basic attacks modest.
5. `combat-vfx.spec`: `heroSkillStyle` for a custom Skill style, `projectileStyles` for new
   projectile styles, and the Skill recipe's `Radius` equal to the kit's.
6. Clones and blinks can't run in the offline tests (they need instances): build clones in
   Studio Edit mode with the clone snippet to see them; the blink is checked in Play.

## 6. Verify

1. `pwsh tests/run.ps1 -LuauDirectory D:/luau` (never `-InstallLuau`). Ignore the expected
   "[The Pit] Request failed" line.
2. Studio MCP, Edit mode: look (front, back, face), key poses with the real grip, clones.
   Clean up every temporary model.
3. Give the user Play steps: restart Play, equip the hero's weapon (overrides need it),
   `/summon <hero>` and `/floors 10` when useful, which attack to watch and what to look for.

## 7. Ship

1. GDD and plan docs in the same change.
2. Commit in reviewable pieces with conventional messages (`feat(heroes): ...`); stage only
   this work (`git add -f` for files under `.claude/` if needed; never untracked `.fbm` folders,
   `sss`, `__pycache__`).
3. Push and open or update the PR when the user asks; edit PR bodies with
   `gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -F body=@file` (`gh pr edit` fails here).

## Reporting

Each turn: send renders (hair angles, face preview) as files, say what changed and why
(especially rejected attempts), say what is unverified (live fights, timing), and end with the
one thing you need from the user (a MeshId, a playtest).
