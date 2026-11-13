# Hero Creation Pipeline

How a hero goes from an idea and a piece of reference art to a finished, playable hero in
*Infinite Tower*: its data, its own kit, its look (face, hair, costume), how it holds its
weapon, its stance and attack animations, its skill effects, and the checks before it ships.

This document holds the **rules and the reasons**. The step-by-step procedure for an agent is
the `hero-creation` skill (`.claude/skills/hero-creation/`). The look-only part (face decal,
hair mesh, costume, idle) is covered in more depth by `docs/hero-art-pipeline.md` and the
`hero-remodel` skill; this document builds on them and does not repeat their recipes.

Worked examples, built with this pipeline in November 2026 (the Gilded Mirror, PR #281):

- **Isabelle** (Marksman): UGC-style braid hair, a monocle drawn into the face decal, her own
  bow clips (canted, flat, rising draw), `RICOCHET` and `TWIN` VFX styles, and a server-picked
  second target sent to clients (`TWIN_MARK`).
- **Nyx** (Striker): a textured black-to-teal hair mesh, a per-hero grip (forward main dagger,
  reversed off-hand), a guard idle and walk from a pose reference, `GILT_CUT`, `MIRROR_STEP`
  (a real blink behind the target and back, with a glass clone left in her place) and
  `SHATTERDANCE` (five glass clones of her that slash in turn).

---

## 1. Principles

1. **The description is the spec.** Every kit line ("blinks behind the target", "five mirror
   clones slash inward in turn", "the arrow splits") must be *visibly true* on screen. Players
   read the description, then watch the hero. Read it literally for what happens, not for
   flavour words: "Shatterdance" is not a dance, but "five mirror clones" means five clones you
   can see, and "blinks behind" means she is seen behind the target, then back.
2. **The server decides, the client shows.** Damage, targets, positions and timing are server
   authoritative (`CombatSimulation`, `HeroSkillEffects`). Effects, clones and blinks are
   cosmetic and client-only. When a visual needs something only the server knows (a second
   target), the server sends it as a small cosmetic message, and the server's own hit reuses the
   same decision so the drawing and the damage agree.
3. **One hero at a time, nothing shared breaks.** A hero's own data goes in per-hero tables
   (kit override, costume block, clip override, grip entry, VFX recipe). Shared systems change
   only to gain a new *capability* (a new effect type, VFX style, primitive) that defaults to
   off for everyone else.
4. **Measure, don't guess.** Joint angles, weapon directions and fits are checked in Studio
   on a temporary rig. Every guessed weapon pose in this project's history came out wrong at
   least once (staff across the face, fist by the face instead of across the chest).
5. **Make it read at gameplay distance.** Up to 30 heroes share the screen under an
   over-the-shoulder camera. Big shapes, bright accents and generous effect sizes and durations
   win. The user's feedback on first passes was consistently "too minuscule", "make it pop".
6. **Every hero is data in the repo.** Generators, costumes, clips, grips and recipes are
   source, reviewable and rebuildable. Nothing is authored only in Studio.

---

## 2. Where a hero lives

| Layer | File(s) | Notes |
| --- | --- | --- |
| Catalog seed (stats, rarity, archetype, banner, labor) | `Shared/Config/HeroCatalog.luau` | Banner pools (`HeroesByStar`, `HeroesPoolByStar`), odds, display name |
| Kit (Basic / Special / Skill / Passive) | `Shared/Config/ArchetypeCombatSkills.luau` (`HeroKitOverride`) | Falls back to the archetype per field |
| New combat mechanics | `ServerScriptService/Combat/HeroSkillEffects.luau` | `SecondaryEffect` (Special), `Effect` (Skill) |
| Combat hooks (buffs, passives, cues) | `ServerScriptService/Combat/CombatSimulation.server.luau` | Attack speed, gauge, cosmetic messages |
| Attack timing | `Shared/Util/HeroActionTiming.luau` | Reads the clip's `Release` marker |
| Look: costume, hair placement, mesh allowlist | `Assets/HeroRig/HeroCostumes.luau` | Lint and part budget |
| Face, hair generators and exports | `assets/faces/`, `tools/make_<hero>_hair_ugc.py`, `assets/hair/` | See `hero-art-pipeline.md` |
| Grip | `Assets/HeroRig/HeroSockets.luau` (`HERO_GRIPS`) | Per hero, per weapon type, per assembly |
| Stance and attack clips | `Assets/HeroRig/HeroClips.luau` (`Overrides`, `OVERRIDE_WEAPON`) | Only while holding the signature weapon |
| VFX recipe and palette | `Shared/Config/SkillVfxCatalog.luau` (`Heroes`, `Styles`) | Style per tier |
| VFX players and chargers | `Assets/CombatVfx/SkillVfx.luau` | `PLAYERS`, `CHARGERS` |
| VFX building blocks | `Assets/CombatVfx/VfxPrimitives.luau`, `ProjectileVfx.luau`, `MirrorClones.luau` | |
| Attack cue to the client | `StarterPlayerScripts/Rendering/EntityRenderer.client.luau` (`attackArgs`) | `Rig`, `Twin`, `Blink`, `RecentHits` |
| Design ledger | `docs/GAME_DESIGN.MD` §4.1 (banners), §4.4 (kit ledger and mechanics) | Update in the same change |
| Tests | `tests/hero-rig.spec.luau`, `combat-vfx.spec.luau`, `combat-skills.spec.luau`, `hero-action.spec.luau`, per-feature specs (e.g. `mirror.spec.luau`) | `pwsh tests/run.ps1 -LuauDirectory D:/luau` |

---

## 3. The flow

```
0 Brief ──► 1 Data & kit ──► 2 Look ──► 3 Grip ──► 4 Animation ──► 5 VFX ──► 6 Verify ──► 7 Ship
            (server)          (art)      (rig)      (clips)           (client)   (tests+Studio)
```

Order matters: the kit fixes ticks, cast time and delivery, which the clips and VFX are timed
to; the grip changes how every pose reads, so it comes before the clips; the look (hair,
costume) is what the mirror clones copy, so it should exist before clone-based VFX are judged.
A remodel of an existing hero can start at step 2.

---

## 4. Step 0: the brief

Before code, write down, per hero:

- **Identity:** name, archetype (fixes the weapon type; see `CLAUDE.md`), rarity, banner,
  body type (`Slim` for every woman).
- **Kit text:** Basic, Special and Skill names and descriptions, and any passive. Underline
  every verb a player will expect to *see*: splits, bounces, blinks, clones, rains, shatters.
- **Reference art** for the look, and optionally a **pose reference** for the stance (Nyx's
  idle came from a separate figure). Note what to drop (Nyx's mask was dropped on request) and
  what the art shows that is not costume (held items are the weapon system's).
- **Palette for effects:** usually the art's glow colour as `Primary`, gilt or a metal as
  `Secondary`, a pale `Core`, a deep `Accent`.

Ask the user only what the art and descriptions cannot answer.

---

## 5. Step 1: data and kit

### 5.1 Catalog seed

Add the seed to `HeroCatalog.Seeds` (copy a hero of the same archetype), register it in its
banner's `HeroesByStar`/`HeroesPoolByStar`, and add its rarity colour if the tier is new
(`Hud/Theme.luau`, `BillboardThemes.luau`). Update the GDD §4.1 roster and §4.4 ledger row.
Count assertions in the tests (`hero-rig.spec`: number of costumes; `combat-vfx.spec`: number
of heroes with VFX) go up by one.

### 5.2 Kit override

In `ArchetypeCombatSkills`, add `hero_<id> = { Archetype, Basic, Special, Skill, Passive? }`.
Each tier merges over the archetype's, so give only what differs: `Name`, `Description`, and
the numbers that make it this hero.

Rules:

- **Keep the archetype's budget** unless the user decides otherwise. A hero's strength comes
  from its stats and rarity; a kit changes *shape* (single target vs area, burst vs sustain).
- **Ticks and timing are part of the kit.** `Ticks`/`TickSeconds` spread a tier's damage
  (each tick is a damage event the VFX can draw: Gilt Cut's 2 cuts, Shatterdance's 5 clones).
  `CastSeconds` holds the hero for a Skill's whole animation. Spreading ticks wider (Nyx
  0.12 → 0.18 s) or lengthening a cast (Isabelle 1.2 → 1.5 s) changes no damage but gives the
  visuals room to read. Say so to the user when you do it: the hero stands still longer.
- **Delivery** (`MELEE`, `PROJECTILE` with `ProjectileSpeed`, `AREA` with `TravelSeconds`) sets
  release-to-impact time, which every effect is timed to.
- Write the **description as a promise you will draw.**

### 5.3 New mechanics

If the kit needs something no archetype does, add it as a named effect in
`HeroSkillEffects`: a `SecondaryEffect` for Specials (`RICOCHET`, `LAST_STAND`) or an `Effect`
for Skills (`TWIN_SHOT`, `MIRROR_WALL`, `FRENZY`), plus its fields on the def types. Keep the
archetype default as the fallback path. Buffs that outlive the hit (attack speed, reflect)
are stored on the sim hero with an expiry and read in `CombatSimulation`.

### 5.4 Decisions the client must draw: cosmetic marks

When the visual needs a server decision before the hit lands (Twin Reflection's second
target), use the `TWIN_MARK` pattern:

1. Put the choice in a public function (`HeroSkillEffects.PickTwinTarget`).
2. In `CombatSimulation`, when the attack is decided (next to `HERO_CUE`), call it, store the
   result on the impact entry (`TwinTarget`, `TwinGeneration`), and broadcast a cosmetic
   message on `CombatVFX` (position, attacker NetId, target NetId) *before* the cue.
3. At the hit, prefer the stored choice while it is still valid (alive, same generation, in
   range plus a margin), else choose again.
4. On the client, `EntityRenderer` keeps the latest mark per attacker and exposes it to
   `SkillVfx` through `PlayArgs` (`Twin()`), resolving the live position by NetId.

Never let a client choice drive damage. Validate nothing from the client here because nothing
comes from the client: marks are server-to-client only.

### 5.5 Kit tests

Add pure-Luau tests (the feature's spec, or `combat-skills.spec`) through
`HeroSkillEffects.Resolve` with fake mobs: the numbers, the fallbacks (a lone target, a dead
pick), and anything the kit promises. Example: "Twin Reflection's second half lands on the
target picked when the attack started".

---

## 6. Step 2: the look

Follow `docs/hero-art-pipeline.md` (§4) and the `hero-remodel` skill for the face decal,
hair mesh and costume. What this project learned since, and now does by default:

### 6.1 UGC-style hair

Roblox UGC hair is built from **thick, rounded clumps that taper to soft points**, not flat
strips, over a base shell so no scalp shows. The generators (`tools/make_isabelle_hair_ugc.py`,
`tools/make_nyx_hair_ugc.py`) carry the helpers:

- **`curtain(...)`**: one grooved sheet around the head with a cut hem, the base layer. A
  hime-cut fringe can be a curtain on its own, but layered clumps over it look better.
- **`clump(...)`**: a rounded `PROFILE` (eight points) and a `tip` exponent: about 2–3 for
  pointed locks, about 5 for wide fringe locks that only point at the very end (shallow
  notches, not a sawtooth).
- **Layers:** a fringe of staggered clumps plus a narrower second layer offset by half a clump;
  framing clumps placed far enough forward to read from the front (edge-on clumps look like
  icicles); a back layer with per-clump random width, length, depth, sway and flick; a short top
  layer for the layered look.
- **Braids and ponytails** must grow out of the hair: the back clumps on the braid's side
  curve and gather into the braid's root, each ending in its own slot across the root in order
  (no two cross), farther clumps riding a little higher. The braid tapers from a full root.
- **Avoid**: clumps that all meet at the crown pole (crossing mess: start them below the
  crown), roots that stand off the head (a visible hoop from behind), tiny floating flicks.

Bases: long or layered Valeria, wavy Solaris, ponytail or braid Aeli/Isabelle, male bangs Han,
messy bob Nyx.

### 6.2 Two-colour hair: texture by height

A one-colour mesh takes the costume colour. For a gradient (Nyx's black to teal), give the
mesh UVs with **V mapped to height on the head** (1 at the crown, about 0.5 at the cheeks, 0 at
the chin), U across the head without a wrap seam, and a vertical gradient texture generated
with PIL (`assets/hair/make_nyx_hair_texture.py`). Every lock then changes colour at the same
height, like the art. **Clamp V to 0.02–0.98**: a V of exactly 1 samples across the wrap into
the other end of the texture. List the mesh in `HeroCostumes.MESHES` as `[meshId] = textureId`
and set the piece's `Mesh.TextureId`. A textured import has more vertices than the export (the
importer splits seams): verify it by the mirrored extreme vertex, not the count.

Height mapping suits a plain gradient. **A texture with strand lines must follow the locks**
instead (the user's feedback on Caspian: "the texture doesn't follow the hair's direction"):
map every lock along its own length (V from about 1 at its root to 0 at its tip, U across it
from the profile, each lock on its own random slice of the texture) and the base sheet with V
down from the crown and U zig-zagging around the head (continuous, no seam). Record a UV per
vertex while building and write them to the loops **before** `remove_doubles`, which would
merge the vertices the table is keyed on (`tools/make_caspian_hair_ugc.py`). Each lock then
runs from a darker root through a shine to a lighter tip, which also reads as depth.

### 6.3 Headless Blender

When the Blender MCP is down, generators run headless:
`blender.exe --background --factory-startup --python <runner.py> [-- --export]`
(Steam install, see memory). The skill's `scripts/run_hair_headless.py` execs the generator,
optionally exports, adds torso and arm proxies, and renders front, three-quarter, side and back
(plus back-right and low for braids) with Workbench (`TEXTURE` colour mode for textured hair).
Stitch the renders side by side and compare them with the art before every export.

### 6.4 Faces with marks and accessories

Draw small facial accessories into the decal when they must line up with the eyes (Isabelle's
monocle and chain): a 3D piece over a decal never aligns exactly on the round head.

### 6.5 Costume lint after the placeholder

The lint stops at the first problem per hero, so the hair placeholder hides later issues.
Expect one more round after wiring the real mesh (Nyx's thigh pouch overlapped her hand).

---

## 7. Step 3: the grip

Weapons attach per weapon type (`HeroSockets.SOCKETS`, grip attachments, `GRIP_SHIFT`, the
prefab's `ReverseGrip` attribute). A hero can hold its weapon differently through
`HeroSockets.HERO_GRIPS`:

```lua
hero_nyx = { DAGGERS = { Main = { Reverse = false }, LeftDagger = { Reverse = true } } },
```

- Keys: hero id, weapon type, then assembly (`Main` for the weapon itself, else the socket's
  `Assembly`, e.g. `LeftDagger`, `OffhandShield`).
- Fields: `Reverse` (overrides the prefab), `Shift` (studs towards the pommel, added to
  `GRIP_SHIFT`), `Offset` (an extra `CFrame` on the weapon side of the weld).
- The hero comes from the rig's `HeroId` attribute (set by `HeroCostumeBuilder.Apply`).
- `hero-rig.spec` checks every entry names a real hero, weapon type and assembly.

A new grip changes how every pose reads: re-pose that hero's clips (step 4) and measure in
Studio. Add one only when the user asks.

Grip facts measured in Studio (blade = the weapon's head):

- **Forward grip:** the blade leaves past the thumb, perpendicular to the forearm; shoulder +
  elbow + wrist pitch tilts it up from pointing forward (90° = upright).
- **Reverse grip:** the blade runs along the forearm.
- **Bow:** a `LeftWrist` turn about **Y** cants the bow sideways (60° ≈ a strong cant, 80° ≈
  flat); X tilts it fore and aft; Z does nothing visible.
- **Forearm across the chest:** twist the upper arm in (`RightShoulder {40, 45, 0}`,
  `RightElbow {90}`); pitch alone lifts the fist to the face.

---

## 8. Step 4: animation

### 8.1 What can be overridden

`HeroClips.Overrides.hero_<id>` may set any state: `Idle`, `Move`, `AttackBasic`,
`AttackSpecial`, `AttackSkill` (others fall back). Overrides apply **only while the hero holds
its signature weapon** (`OVERRIDE_WEAPON[hero_<id>]`); an unarmed hero uses the shared unarmed
set. When the user reports "default animations", check that the hero has the weapon first.

### 8.2 Building clips

- `breathe(pose, seconds)`: a looping idle.
- `walk(upperBody, armSwing?)`: a walk cycle that keeps the given upper body (arms, waist,
  neck) over walking legs. Give a guard-style hero a walk with its guard (`walk(guardArms)`),
  or it walks with the generic arms of its weapon.
- `signature(duration, keys, markers)`: an attack. Keys are `{ fraction, pose }`.
- `merge(a, b)` layers poses; start from `WeaponPoses.<TYPE>` keys (`Carry`, `Aim`, `Drawn`,
  `Release`, `Crouch`, `Crouched`, `Guard`, ...).
- Axis rules (`hero-art-pipeline.md` §3): +X on shoulders and hips swings forward; knees bend
  negative (never positive); left shoulder raises with −Z, right with +Z; waist and neck −X lean
  forward, +Y turns left. Waist yaw stays within ±180°.

### 8.3 Markers drive the server

`Release` is not just cosmetic: `HeroActionTiming.ReleaseFraction` reads it, so the **server's
hit time is `CastSeconds × Release` (+ travel)**. Moving a Release marker moves the damage.
Other markers: `Charge` (when the wind-up effect starts: `SkillVfx` chargers), `Nock` (bow:
when the arrow reappears).

### 8.4 Reading the art into poses

- **Idle** from the art's stance or a pose reference: feet, knee bend, waist turn, where each
  hand and blade is. Wide stance: abduct the hips, counter-rotate the ankles, bend the knees,
  drop `RootOffset` y 0.1–0.3.
- **Attacks** act out the description, beat by beat, and give the effects a pose to land on:
  a wind-up key (Charge), the strike key (Release), a hold, a recovery. Make each tier read
  differently from the shared weapon set: a cant, a pivot, a lunge, a held glowing draw.
- When the effect moves the hero (a blink), keep the clip's own root motion small; the
  renderer does the travel.

### 8.5 Measure in Studio

Build temporary rigs side by side, one per key frame (the skill's `references/studio-snippets.md`
has a line-up snippet), and capture from the front. With the camera at −Z looking at +Z, the
rig at the most positive X is on the **viewer's left**. For an uncertain joint, build one rig
per candidate value and pick by eye. Delete the rigs afterwards.

---

## 9. Step 5: VFX

### 9.1 How an attack's effect plays

The server sends a `HERO_CUE` when it decides an attack (tier, cast, release, travel, start
time, aim). `EntityRenderer` plays the tier's clip; at the clip's `Charge` marker it calls
`SkillVfx.PlayCharge`, at `Release` it calls `SkillVfx.Play`. The recipe comes from
`SkillVfxCatalog.Get(heroId, weaponType, tier)`: the hero's own entry wins, else the weapon's.

In a player, `ctx.StartAt` is the release time (or now, if late) and `ctx.ArriveAt` is the
server impact time; damage numbers appear at `ArriveAt`. A charger gets `StartAt` (now) and
`ReleaseAt`. Multi-tick tiers: `VfxMath.WaveTimes(ArriveAt, ticks, gap)` gives one time per
damage event.

`PlayArgs` (built in `EntityRenderer.attackArgs`) gives a player what it can know:

| Field | What |
| --- | --- |
| `Origin`, `OriginOf(name)` | Where a projectile leaves (nock, staff tip, hand) |
| `Target()`, `Cue.Aim` | Live target body centre; ground aim |
| `Self()`, `Allies()` | Attacker feet; squad positions |
| `RecentHits(kind, centre, radius, since)` | Positions the server reported hits or heals at (bounces, chains) |
| `Twin()` | The server-picked second target (`TWIN_MARK`) |
| `Rig` | The attacker's rendered rig (for clones) |
| `Blink(pos, yaw, from, to)` | Draw the attacker elsewhere for a window (cosmetic) |
| `Shake(magnitude)` | Camera shake, only for the local player's own heroes |

### 9.2 Adding a hero's styles

1. Recipe in `SkillVfxCatalog.Heroes.hero_<id>`: `Palette` and `Basic`, `Special`, `Skill`, each
   `{ Style = "...", ...knobs }`. Document new knobs on `TierRecipe`.
2. Register each new style in `SkillVfxCatalog.Styles` (per tier).
3. Write the player (`local function playX(ctx)`) and add it to `PLAYERS`; a wind-up goes in
   `CHARGERS` (the clip needs a `Charge` marker).
4. `combat-vfx.spec`: add the hero to `heroSkillStyle` if its Skill is not the archetype's
   style, add projectile styles to `projectileStyles`, and keep `recipe.Skill.Radius` equal to
   the kit's `Skill.Radius` (the test checks it).

### 9.3 Building blocks

`VfxPrimitives`: `Flight` (projectile with arc, follows a moving target), `Burst`, `Flare`
(camera-facing glint), `Disc` (glass pane, ground ring: the disc face is perpendicular to the
CFrame's X axis), `FlightRing`, `Ring` (ground shockwave), `SlashArc`, `Lance` (beam stab),
`Ribbon` (a lingering wake along a path), `Motes` (sparks and shards), `Beam` (lightning),
`Sigil`, `Shell`, `Pillar`, `Spike`, `Implode`, `Glyph`, `Converge`, `Orb`, `Constellation`, and
`At(pool, time, fn)` to schedule. `ProjectileVfx` paints arrows, bolts and orbs in the palette.

`MirrorClones.Make(rig, parent, tint, rim)`: a glass copy of the hero's rendered rig (costume,
hair, weapon) with its scripts, humanoid, tags and effects stripped, anchored, under a
`Highlight`; `Pose(frame, pose)`, `Move(frame)`, `Fade(0..1)`, `Destroy()`. Pose it from the
hero's own clips (`HeroAnimator.Sample`). A clone copies the rig as it is, grip included.

Renderer blink: `PlayArgs.Blink` sets a window in which `EntityRenderer` draws the hero at
another spot (feet position and yaw); the server position, targeting and HP all stay put.
Yaw for facing direction `d`: `math.atan2(-d.X, -d.Z)`.

For effects that last longer than a few frames, use `pool:Run({ Update = fn(now) -> done,
Cleanup })`, and re-pose clones only when their state changes (posing is not free).

### 9.4 Making it read

What the user accepted after asking for "more pop":

- **Sizes:** impact bursts 3–4.5 studs, flares 4–10, ground shockwaves over the skill radius,
  mirror panes 4–8 studs across.
- **Durations:** bursts and flares 0.3–0.55 s, wakes linger 0.45–0.7 s, a mirror or clone
  stays a beat (0.5–0.7 s) after its moment.
- **Layering** for every big moment: a coloured burst, a white core flash, a gilt glint, a
  ground ring, a spray of motes, and camera shake on the local player's hero.
- **Basic attacks stay modest:** they fire constantly.
- **Show the decision:** a bounce arrow from the target to where the server reported the next
  hit; a split toward the target the server picked; clones you can count.

### 9.5 Patterns

- **Bounce or chain** (`RICOCHET`, `CHAIN`): main projectile, then `afterHits` to read the
  server's hit positions and draw a second flight from the target to each.
- **Split** (`TWIN`): charge at the nock, a lead projectile to a split point where a mirror pane
  forms ahead of time, then two halves to `Target()` and `Twin()`, landing together.
- **Clones** (`SHATTERDANCE`): the charger raises clones (and panes) around the target and
  parks them per attacker NetId; the player takes them over, and per damage tick a clone winds
  up, lunges, slashes and shatters. A safety timer destroys parked clones if the strike never
  comes.
- **Blink** (`MIRROR_STEP`): the charger leaves a clone in place, streaks to behind the target
  and calls `Blink` until the return; the player draws the strike from there; the return
  streaks home and shatters the clone.

---

## 10. Step 6: verify

1. `pwsh tests/run.ps1 -LuauDirectory D:/luau`: every suite passes (the costume lint, clip
   rules, VFX catalog checks, kit tests).
2. **Studio, Edit mode (Studio MCP):** temporary rigs for the look (front, back, face
   close-up) and for every key pose with the real grip; build a clone set to see clones. Clean
   up every temporary model.
3. **Studio, Play (the user):** most VFX, blinks and timing can only be judged in a fight. End
   with a short test checklist: restart Play, give the hero its weapon, `/summon` and
   `/floors 10` if needed, which attack to watch and what to look for.

---

## 11. Step 7: ship

- Update `docs/GAME_DESIGN.MD` (roster, ledger, mechanics paragraph) and any plan doc in the
  same change.
- Commit in reviewable pieces (data and kit, look, grip and clips, VFX), conventional commits,
  on the branch the user chose; push and open or update the PR when asked. Never commit other
  sessions' work or untracked junk.
- Leave the imported hair copy in Workspace for the user to delete before saving the place.

---

## 12. Lessons (each cost an iteration)

| Feedback | Cause | Rule now |
| --- | --- | --- |
| "The animations and VFX are the defaults" | Kit visuals reused generic styles; overrides are bow-only | Every described verb gets its own style and clip; check the weapon is equipped |
| "The VFX is too minuscule" | Basic-sized effects on a Special | §9.4 sizes and durations; layer every big moment |
| "I don't see the clones" | Clones drawn as dashes and panes only | Draw the thing the description names (`MirrorClones`) |
| "It doesn't mean a literal dance" | Read a flavour word as an action | Read the kit for what happens, not the name |
| "She's supposed to blink behind the target and back" | Lunge in place | Move what the description moves (renderer blink), leave a clone |
| "The fringe is ugly", "follow UGC hair" | Flat ribbons, sawtooth edges | §6.1 clumps over a curtain |
| "The braid looks like a separate part" | Back hair ended beside the braid | Gather the back clumps into the braid's root |
| "The base of the back is overlapping" | Converging clumps crossed | Ordered end slots, farther clumps higher |
| Hair top teal instead of black | UV V = 1 wrapped | Clamp V to 0.02–0.98 |
| "The texture doesn't follow the hair's direction" | Strand texture mapped by height | Map strand textures along each lock (§6.2) |
| Fist by the face instead of across the chest | Pitch only | Twist the upper arm (shoulder Y) |
