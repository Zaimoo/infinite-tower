# Tower Mob Reanimation: Implementation Plan

Status: **steps 1–3 built**, step 4 done (all five pairs exported); steps 5–8 to do. Decisions settled (§8). Owner: Zaimoo. Written 2026-11-09.

All 60 tower enemies are now remodelled meshes (`docs/tower-mob-remodel-plan.md`), but they still move with the clips written for the old part rigs. This plan rebuilds their **idle, walking and attack** animation (plus the hit, death and awakening clips those blend with) so each family moves like what it is. It stays on the existing contract: rigid segments, `Motor6D`s, clips authored as code in `TowerEnemyClips`, no uploaded `Animation` assets. The server, the network records and combat timings don't change.

---

## 1. What's wrong today

How it works now: `EnemyRigFactory` builds the rig (a `Motor6D` per joint, `Bind` = rest pose). Every frame, `EnemyAnimationController.Step` picks one clip (Death, then action, then Awakening, then Locomotion, then HitReaction, else Idle), samples it with `TowerEnemyClips.Sample` and writes `Motor.C0 = Bind * pose`.

| # | Problem | Where | What you see |
| --- | --- | --- | --- |
| 1 | **Five clip groups for 24 families.** Every biped and colossus family (18 of them, about 45 of the 60 enemies) shares one `idle` and one `walk`. Crawlers, quadrupeds, avians and serpents reuse the *biped* idle and hit, and quadrupeds, avians and serpents use the biped death. | `TowerEnemyClips.luau` family switch | A sandstone colossus and a cinder imp walk the same way. A wolf idles with its front legs bent like elbows. Wings never fold or flutter. |
| 2 | **Idle barely moves, and every mob breathes together.** The body moves ±1.5°, and `phase = (now % 3) / 3` is the same clock for every mob. | `EnemyAnimationController.Step`, patrol, Facility preview | A camp of statues bobbing in unison. |
| 3 | **Feet skate.** The cycle length is hard-coded to 3.6, 4.8 or 9.6 studs per walk cycle and ignores leg length. A ±24° swing on the Throne Executioner (hip 3.7 studs × 1.25 render scale = 4.6) covers about 7.5 studs per cycle, so the legs cycle about 1.55× faster than the ground moves. The Crimson Overlord is the same (15 studs vs 9.6), and Alphas (1.4×) are worse. | `Step`, `phase = Distance / stride` | Mobs moonwalk, especially big ones. |
| 4 | **Idle and walk flicker.** `moving = (GoalPos - CurrentPos).Magnitude > .15` with 5 Hz snapshots has no hysteresis. Heroes already fixed this with `MOVE_GRACE`. | `Step` | Walk/idle pops while chasing. |
| 5 | **Every state change is a hard cut.** There's no fade or smoothing. Hit reactions only play when the mob is *standing still and not attacking*, because the hit check comes after `moving`. | `Step` | Snapping poses, and mobs that never flinch while they chase. |
| 6 | **Translations are absolute studs.** Death drops the body 2.4 studs whether the mob is 2.4 or 25 studs tall. The bite lunge is 0.5 studs on everything. | `death`, `bite`, `quadAttack` keys | Small mobs sink through the floor when they die; bosses barely bow. Lunges are invisible on big mobs. |
| 7 | **Attack timing is pinned to phase 0.8.** For `PROJECTILE`, `ImpactOffsetSeconds = windup + 0.4 s flight`, so the throw key lands about 0.15 s after the orb has already left (`ReleaseAt = windup`). All 9 `ARC` attacks use the same `cleave`. Elite Specials reuse `cast` (bipeds) or the basic attack (crawlers, quadrupeds). | `Step`, clip table | Attacks don't read; projectiles leave before the hand throws. |
| 8 | **Three copies of the state machine.** Tower (`EnemyAnimationController.Step`), hub patrol (`AdventurerPatrolController` around line 682) and Facility preview (`FacilityPanel` around line 457) each choose and sample clips themselves, with drift: Awakening lasts 2.2 s vs 1.1 s, and the patrol has no boss stride. | three callers | Fixes land in one place and not the others. |
| 9 | **Garbage every frame.** `Sample` allocates two tables per call. At 48 mobs × 60 fps that's about 5,800 tables a second. | `TowerEnemyClips.Sample` | GC hitches in dense packs. |
| 10 | **Joints that never move.** Alpha `Trophy_*` joints (11) and glow-only carriers are rigid. Crawler jaws only move during the bite. | `TowerEnemyClips` | Stiff silhouettes. |

## 2. Goals and non-goals

**Goals**
1. **Each family moves like itself:** a heavy colossus weight-shifts and stomps, a caster floats and sways, a crawler moves its legs in a tripod gait, an avian folds and flutters its wings.
2. **Idle is alive and desynced:** visible breathing, per-mob phase and rate, occasional fidgets.
3. **Walking is planted:** cycle length comes from each model's leg length and real ground speed. No skating, no flicker.
4. **Attacks read:** clear anticipation, then strike, then recovery, keyed to the server's `WindupSeconds`, `ImpactOffsetSeconds` and `RecoverySeconds`, so the swing lands with the telegraph. Different shapes look different.
5. **Smooth transitions:** crossfades between states, hits flinch on top of anything.
6. **One animator** for the tower, hub patrol, Facility preview and Studio lineup.

**Non-goals**
- Uploaded `Animation` assets, `Animator`, `Humanoid`, skinned meshes, IK foot placement.
- Renaming or re-parenting the existing clip joints. New joints are **added** as `Extra*` joints (§3.8) and the existing contract stays as it is.
- Any server, network or combat-timing change.

## 3. Design

### 3.1 `EnemyAnimator`: one player for every enemy rig

New module, `src/ReplicatedStorage/Assets/EnemyAnimator.luau`, modelled on `HeroAnimator`:

```lua
local anim = EnemyAnimator.new(rig, { Seed = netId })  -- rig from EnemyRigFactory / RaidBossRigs
anim:SetSpeed(studsPerSecond)                           -- from the interpolated position, not GoalPos
anim:PlayAction(action, now)                            -- the server's action record (AnimationKey, Windup, Impact, Recovery, Aim)
anim:Hit(now)  anim:Die(now)  anim:Awaken(now)  anim:Cancel()
anim:Step(dt, now)                                      -- writes Motor6D.Transform
```

**Layers**, evaluated in order:
1. **Base:** Idle and Locomotion, blended by a speed weight (0 at standstill, 1 at walking speed), so there's no hard switch.
2. **Action:** an attack, Awakening or Signature move. It drives the full body when the mob is still and only the upper body when it's moving (a per-motion-set joint mask, the same idea as `HeroAnimator`), so the legs keep walking. It fades in and out over 0.12 s.
3. **Hit (additive):** a short flinch rotation layered on top of whatever is playing, so mobs flinch mid-chase and mid-windup. It never cancels the action, since the server doesn't interrupt either.
4. **Death:** overrides everything, with a 0.1 s fade in.

**Smoothing:** each joint's written pose eases towards its target at an exponential rate (14/s). This covers any switch the layers don't fade, such as an action cancel or a late join.

**Output:** writes `Motor6D.Transform` and leaves `C0 = Bind` alone, as `HeroAnimator` does. Enemy rigs have no `Animator` or `Humanoid`, so nothing overwrites `Transform`.

**Legacy clips:** `RaidBossRigs` and the part-rig fallback still work. Old-format frames are treated as a clip with `Release = Impact = 0.8`.

### 3.2 Motion sets instead of family groups

`TowerEnemyClips` keeps its public shape (`Clips[enemyId][slot]`, `Clips.Sample`), so the raid bosses and the lineup script keep working. Internally it's built from **motion sets**, one module each under `src/ReplicatedStorage/Assets/EnemyClips/`:

| Motion set | Families | Character | Idle | Gait |
| --- | --- | --- | --- | --- |
| `LightBiped` | `SMALL_BIPED`, `CASTER_BIPED`, `FUNGAL_BIPED` | Light, quick, hands busy | Floating sway, hands drift and the focus hand pulses; fidget: glances round, or rolls a shoulder | Bouncy, short stride, arms swing |
| `WarriorBiped` | `WEAPON_BIPED`, `ARMORED_BIPED`, `ROYAL_BIPED` | Guarded and disciplined | Weapon held ready, weight shifts foot to foot; fidget: tests the weapon, adjusts the shield | Measured march, guard arm stays up |
| `HeavyBiped` | `HEAVY_BIPED` | Hunched brute | Slow heavy breathing, shoulders roll, knuckles hang low; fidget: cracks neck | Wide stance, lumbering roll side to side |
| `Rooted` | `ROOTED_BIPED`, `TREANT` | Creaking, plant-like | Swaying like a branch in wind, delayed head | Shuffling drag, no bounce, long sway |
| `Colossus` | all `*_COLOSSUS` | Landmark weight | Very slow, deep breath, torso turns side to side | Heavy plant, body dips on each step |
| `Quadruped` | `QUADRUPED` | Predator or ram | Head scans, tail-end shift, front legs straight (no elbow bend) | Diagonal trot, head bob |
| `Avian` | `AVIAN`, `GIANT_AVIAN` | Bird | Wings folded with an occasional ruffle; head darts | Hop-walk with half-open wings for balance |
| `Serpent` | `SERPENT` | Coiled eel-dragon | Coils rise and fall, head weaves | S-wave travelling down the body and tail joints |
| `Multileg` | `CRAWLER`, `SIX_LEGGED_CRAWLER`, `INSECT`, `CRUSTACEAN`, `SCORPION` | Skittering | Mandibles twitch, legs tap one at a time | Alternating tripod (legs 1 and 3 on one side with 2 on the other), body bob per step |

`EnemyClips/Common.luau` holds the pose helpers (`plantedPose`, `rot`), the clip compiler (§3.7) and the shared hit and death building blocks.

Each motion set exports `Idle`, `Fidgets` (1 or 2), `Locomotion`, `HitReaction`, `Death`, `Awakening` (used by bosses) and its attack styles (§3.3), together with:
- `ReferenceHeight`, for size scaling (§3.5);
- `SwingDegrees`, for stride matching (§3.6);
- `UpperBody`, the list of joints an action drives while moving.

### 3.3 Attack styles: pick by shape, set and role

Each move picks its style from its `Shape` and the enemy's motion set. `EnemyClips/Overrides.luau` sets a style for a specific enemy and move where the default doesn't fit (for example, the Rime Sentry's spear is a thrust, not a slash).

| Shape | Light / Warrior / Heavy biped | Rooted | Colossus | Quadruped | Avian | Serpent | Multileg |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ARC` | `Slash`, mirrored on alternate `ActionSequence`; Heavy uses `Backhand` | `Whip` (vine or branch lash) | `Sweep` | `LungeBite` | `Rake` | `CoilBite` | `Snap` (scorpion: `Pinch`) |
| `TARGET_DISC` | `Overhead` chop or leap | `RootBurst` (both arms drive down) | `Pound` at the target | `Pounce` | `Dive` | `RearStrike` | `TailStab` (scorpion), else `Leap` |
| `SELF_DISC` | `Stomp` | `Uproot` | `TwoFistSlam` | `HowlStomp` | `WingBuffet` | `CoilSlam` | `Drum` |
| `PROJECTILE` | `Throw` (one hand); casters `Bolt` (staff or palm forward) | `Fling` | `Hurl` | `Spit` | `WingFlick` | `Spit` | `Spit` |
| Support kit (`MEND`, `WARD`, `ROUSE`) | `Channel`: both hands raised, held through the beam or aura | `Channel` | n/a | n/a | `Cry` (squall herald) | n/a | n/a |

Elite `Special` and Boss `Signature1`/`Signature2` resolve through the same table from *their* move's shape, so a boss's two signatures look different from each other and from its basic attack.

Every attack clip has **three phases split by two markers**: `Release` (end of anticipation, where the strike starts) and `Impact` (contact or launch), followed by recovery. Anticipation is slow with a held pose. The strike takes 2 to 4 keys and overshoots past the target pose. Recovery settles in with a small overshoot.

### 3.4 Timing: clip time follows the server's timings

Time `t` is measured from the action's `StartServerTime`. `W`, `I` and `R` are the action's windup, impact and recovery times: for melee `W = I`, and for projectiles `I = W + 0.4 s` of flight. `lead = min(0.15 × W, 0.25 s)` is the time the strike takes.

| Real time | Clip time | What it covers |
| --- | --- | --- |
| 0 to W − lead | 0 to `Release` | Anticipation |
| W − lead to W | `Release` to `Impact` | Strike: melee contact, or the projectile's launch |
| W to I | held at `Impact` | Follow-through while the projectile flies (an empty span for melee) |
| I to I + R | `Impact` to 1 | Recovery |

A late observer seeks to the same point, which needs no special case. The orb leaves exactly as the hand releases (`ReleaseAt = W` in the telegraph), and the telegraph fills exactly as a melee blow lands.

### 3.5 Size normalisation

`EnemyRigFactory` adds `rig.Metrics = { Height, HipHeight, LegLength, MotionScale }` for both templates and the part rig:
- `Height` is the drawn height (`Index.Height × RemodelScale × 1.4 for Alphas`, or `spec.Height` for the part rig).
- `HipHeight` is the `LegL` pivot Y, or for multileg rigs the mean height of the `Leg*` pivots, times the render scale.
- `MotionScale` is `Height / set.ReferenceHeight`.

Clip translations are authored for the reference height and multiplied by `MotionScale` when sampled. Rotations aren't scaled. This fixes the death drop, lunges and bobs for every size at once.

### 3.6 Planted walking

- **Stride:** cycle length = `2 × 2 × LegLength × sin(SwingDegrees) × StrideFactor`. That's two steps per cycle, with `StrideFactor` (about 0.9 to 1.0) tuned per set in the lineup. Clip phase is `distance travelled / cycle length`.
- **Speed:** measured from the change in `CurrentPos` per frame, smoothed over about 0.15 s, not from the `GoalPos` gap.
- **Hysteresis**, the same pattern as the heroes' `MOVE_GRACE`: start walking above 0.6 studs/s, and drop back to idle only after 0.25 s below 0.3 studs/s. The base-layer blend weight follows speed, so slowing to a stop eases into idle.
- **Facing:** the renderer's yaw lerp stays. Optionally, the body leans a few degrees into turns, based on yaw rate.

### 3.7 Life: desync, fidgets and aim

- **Seed per mob** from `NetId` (or patrol index or a preview constant): idle phase offset, idle rate × 0.9–1.1, and gait rate × 0.95–1.05.
- **Fidgets:** every 6–14 s (seeded, decided), a still mob plays one of its set's fidgets as a low-weight action, which is skipped if it's in combat range.
- **Head aim:** during an attack's anticipation, the head (and the body, for quadrupeds and serpents) yaws towards `action.Aim`, clamped to ±35°. Every action record already carries `Aim`.
- **Secondary motion:** every `Trophy_*` joint, every glow-only carrier, and every `Extra*` joint that the current clip doesn't key (§3.8) gets a damped spring. The spring lags behind its parent's angular velocity and has a little gravity droop. Capes, censers, chains and antennae swing on their own, with no keys to author. It's cheap (one spring per joint) and off beyond `LOD_FULL_RATE_DISTANCE`. Per-joint stiffness comes from a role in the extra-joint registry: `Cloth` is soft, `Hanging` swings like a pendulum, `Rigid` is stiff, and `Spin` turns steadily.

### 3.8 Extra joints (Blender re-export, decided)

Appendages that are now welded into a parent segment become **joints of their own**, so they can move. `mob_kit.validate` already accepts any joint named `Extra*` that has a parent. The factory wires every index segment as a `Motor6D` whatever its name, and welds `<Joint>_Glow_*` pieces to the longest matching joint name. So the runtime needs no change: new joints simply show up in `rig.Joints`.

**Rules**
- Existing clip joints keep their names and parents. Extras hang *below* them, so Head stays a child of Body, and a serpent's tail carries on from `KneeL`.
- `mob_kit.EXTRAS` is a registry of every allowed extra joint name, with its canonical parent, its role (`Keyed` or one of the spring roles in §3.7) and which motion sets key it. `validate` rejects any name that isn't in the registry or has the wrong parent.
- Clips may key extras. A clip key for a joint the model doesn't have is ignored, so clips and models can land in either order.
- Geometry is only **split**, not remodelled. Triangle counts stay the same. The mesh-part budget in `enemy-models.spec.luau` rises by the number of extras the enemy declares (at most 6).

**Keyed extras** (clips drive them for idle, gait and attacks):

| Enemy | Extras | What they add |
| --- | --- | --- |
| Glass Scorpion / Alpha | `ExtraTail1`–`ExtraTail4` (chain from Body), `ExtraSting` (the Alpha's `Trophy_SunCrest` moves under it) | The tail curls and quivers at idle, cocks back during the windup, and the stab is the `TARGET_DISC` attack |
| Dune Scarab | `ExtraElytraL`/`R` | Wing-cases flick open when it attacks, buzz while it walks, and splay when it dies |
| Rune Mite | `ExtraShell` (the floating rune plate), `ExtraKey` (winding key, `Spin`) | The shell hovers and bobs and the key turns |
| Frost Hound, Blight Wolf | `ExtraJaw`, `ExtraTail1`–`ExtraTail2` (the wolf gets a tail only if the model has one) | The jaw opens on the bite; the tail wags at idle and streams out while it runs |
| Thunder Ram / Alpha | `ExtraTail1` | A short tail flick. Horns stay on Head, since the attack is a headbutt |
| Storm Talon, Squall Herald, Storm Roc | `ExtraBeak` (lower beak, or the Herald's horn flare), `ExtraTailFan`, `ExtraCrest` (`Cloth`) | The beak opens to cry or strike; the tail fan spreads for balance and display |
| Tidal Leviathan | `ExtraJaw`, `ExtraFrill`, `ExtraTail1`–`ExtraTail3` (continuing from `KneeL` to the fin) | The jaw gapes, the frill flares during the windup, and the S-wave carries on to the fin |
| Vinebound Elite / Alpha | `ExtraWhip1`–`ExtraWhip3` (from `ForearmL`) | The thorn whip coils at idle and cracks out on the `ARC` attack |
| Molten Taskmaster / Alpha | `ExtraChain1`–`ExtraChain3` (from `ForearmR`) | The chain drags on the walk and whips round on the attack |
| Forge Construct | `ExtraPiston` (from `ForearmR`) | The piston fires as the hammer lands |
| Bellows Imp | `ExtraBellows` (from Body) | The bellows pump on ROUSE and puff at idle |
| Spore Matriarch | `ExtraCrownL`/`R` (from Head) | The morel crown splits open for `Signature` moves (the Phase 2 look in the remodel plan) |
| Rift Warden | `ExtraTomeL`/`R` (from `ForearmL`/`R`) | The floating tome shields bob at idle and swing in front on the windup |

**Spring extras** (secondary motion only, no keys):

| Enemy | Extras |
| --- | --- |
| Abyss Reaver, Rime Sentry | `ExtraCape` (`Cloth`) |
| Frostbound King | `ExtraCape1`–`ExtraCape3` (the five cloak panels in three groups, `Cloth`) |
| Ash Raider | `ExtraWrapTail` (headwrap tail, from Head, `Cloth`) |
| Casters with robes (Ember Oracle, Void Invoker, Void Hierophant, Rime Chaplain, Drowned Acolyte, Tide Cantor, Astral Scribe, Glyph Warden, Crag Channeler, Sporecap Chanter) | `ExtraHem` (back panel of the robe hem, `Cloth`) |
| Void Hierophant, Sporecap Chanter | `ExtraCenser` (`Hanging`) |
| Rot Mender | `ExtraLantern` (`Hanging`) |
| Astral Scribe | `ExtraTome` (from Body, `Rigid`, with a hover bob) |
| Ember Oracle, Rime Chaplain, Glyph Warden, Tide Cantor | `ExtraRing` (the floating ward shards or rings, `Spin`) |
| Crimson Overlord | `ExtraMantleL`/`R` (chain mantle, `Hanging`) |
| Rotwood Keeper / Alpha, Blight Sovereign | `ExtraMantle` (moss, `Cloth`), `ExtraBranches` (crown branches, `Rigid`) |
| Mossbound Guardian | `ExtraVines` (`Cloth`), `ExtraTree` (the shoulder tree, `Rigid`) |
| Spore Skitter, Moss Crawler | `ExtraAntennaL`/`R` (`Rigid`) |
| Tide Claw | `ExtraEyeL`/`R` (eyestalks, `Rigid`) |
| Spore Matriarch | `ExtraSkirt` (tendril skirt, `Cloth`), `ExtraSacs` (spore-sac lanterns, `Hanging`) |

**As built, pair 5:** the Rune Mite's `ExtraKey` is a `Rigid` spring, not `Spin`: the key turns about the body's long axis and a Spin joint only turns about up (registry updated). The Glyph Warden's three rings orbit together as one `ExtraRing`; the Crimson Overlord's five back chains hang as `ExtraMantleL` / `ExtraMantle` / `ExtraMantleR`; the Astral Scribe's tome is `ExtraTome` on `ForearmL`. The Void Invoker and Throne Executioners are unchanged.

**As built, pair 4:** the Tidal Leviathan's tail is `KneeL` → `ExtraTail1` → `ExtraTail2` (the fin rides the last link), with `ExtraJaw` and `ExtraFrill` (both side frills) on its head; the Blight Wolf got a two-link tail like the Frost Hound. The Drowned Acolyte keeps its robe whole. 2048² boss bakes can still run out of memory on a busy machine even alone; a retry in a fresh process has always worked.

**As built, pair 3:** the Crag Channeler keeps its cloak on the body (it is a closed tube around the torso, so tilting it would cut through the legs). The Herald's speaking horn and rings are its `ExtraBeak`. Boss 2048² bakes need their own Blender process: the Storm Roc ran out of memory baked after four other enemies in one run, so run bosses one per process.

**As built, pair 2:** the Frostbound King's five cloak panels hang as three joints (`ExtraCape1`–`3`: the two left panels, the centre one, the two right panels); the Glass Scorpion Alpha's `Trophy_SunCrest` now hangs from `ExtraSting`; the Ember Oracle and Rime Chaplain have no `ExtraHem` (single-tube robes, like the Chanter). The Ember Oracle's `ExtraRing` is glow-only, so the factory gives it an invisible carrier part.

**As built, pair 1:** the Spore Matriarch's crown is one `ExtraCrown` joint (both morel tiers; the morel is radially symmetric, so it rises rather than splits), its four spore sacs are `ExtraSacs1`–`ExtraSacs4` (each swings on its own stalk), and the Sporecap Chanter has no `ExtraHem` (its robe is one tube, so a hem split would need a remodel).

That comes to **43 of the 60 enemies** (20 with keyed extras, 23 with springs only) across all 10 biomes. Enemies not listed keep their current models. The exact split is settled in each biome's generator, so the tables may shift by a piece or two where a model turns out differently.

**Re-export pipeline**, one PR per biome pair, in the same order as the remodel:
1. *(Built, step 3.)* The registry lives in `tools/blender/mob_extras.py` (pure Python, self-check: `python tools/blender/mob_extras.py`), and `mob_kit.chain(asset, base, points, parent, radius, colour)` splits a rod chain into links (the helper splits a rod chain such as a tail, whip or chain into one joint per link). Extend `validate`.
2. In `tools/blender/mobs/<biome>.py`, move each appendage's geometry out of its parent segment into a new `A.segment("Extra…", pivot, parent)`, with the pivot at the attachment point.
3. Run `generate_mobs.py -- <biome>`. This exports the FBX, JSON and previews.
4. **Rebake Tier B** for every Elite, Alpha and Boss whose segments changed (`bake.py`), because a bake has to be redone when the geometry changes.
5. Regenerate the index with `tools/make_enemy_model_index.py`.
6. **You re-import** the changed FBXs with the 3D Importer (remodel decision 4). Claude then runs `tests/studio-enemy-template-prep.luau` through Studio MCP, which replaces the templates in `ReplicatedStorage.TowerEnemyTemplates`, and you save the place.
7. Run the spec, then the lineup (§6).

### 3.9 Performance

- **Compile clips once** at require time into per-joint arrays of keys, with markers precomputed. `Sample` writes into a table reused per animator, so `Step` allocates nothing.
- **Existing LOD stays:** beyond 140 studs, mobs step at 15 Hz. Add: beyond 140 studs, skip fidgets, head aim and springs.
- **Budget:** ≤ 0.6 ms of client frame time for 48 mobs at full rate, measured under `debug.profilebegin("EnemyAnimator.Step")` in `performance-plan.md` scenario B, before and after.

## 4. File changes

| File | Change |
| --- | --- |
| `src/ReplicatedStorage/Assets/EnemyAnimator.luau` | **New.** Layers, timing map, smoothing, stride, desync, head aim, and springs for unkeyed `Extra*` and `Trophy_*` joints (§3.1–3.8). |
| `src/ReplicatedStorage/Assets/EnemyClips/*.luau` | **New.** `Common` plus the 9 motion sets, and `Overrides`. |
| `src/ReplicatedStorage/Assets/TowerEnemyClips.luau` | Rebuilt as the entry point: resolves each enemy to its motion set and styles, and keeps `Clips[enemyId][slot]` and `Clips.Sample`. Also exports `Clips.Meta[enemyId]` (set, markers, masks). |
| `src/ReplicatedStorage/Assets/EnemyRigFactory.luau` | Adds `rig.Metrics` for both template and part rigs. |
| `src/ReplicatedStorage/Assets/EnemyAnimationController.luau` | `Attach` creates the animator. `Action`, `Hit`, `Death` and `Cancel` forward to it. `Step` becomes glows plus `animator:Step`. The telegraph code is unchanged. |
| `src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau` | Only if needed, passes the yaw rate for the turn lean. Spawn and LOD paths are unchanged. |
| `src/StarterPlayerScripts/Rendering/AdventurerPatrolController.client.luau` | Drops its own clip-choosing code (around lines 682–728) and uses `EnemyAnimator`. The building-hit VFX moves to the animator's `Impact` marker callback. |
| `src/StarterPlayerScripts/UI/Hud/FacilityPanel.luau` | Uses `EnemyAnimator`. **Important:** the viewport preview positions parts by hand (`Part1.CFrame = Part0.CFrame * C0 * C1:Inverse()` around line 482), which ignores `Transform`. That line becomes `C0 * Transform * C1:Inverse()`. |
| `src/ReplicatedStorage/Assets/RaidBossRigs.luau` | No change expected. Its `rig.Clips` goes through the legacy path. |
| `tests/enemy-clips.spec.luau` | **New** (§6), added to the suite list in `tests/run.ps1`. |
| `tests/studio-enemy-lineup.luau` | Adds an `ANIMATE` mode and a `WALK_LINE` mode (§6). |
| `docs/GAME_DESIGN.MD` §5.2 | Rewrites the rig and animation paragraph. It's stale: it still says 40 enemies, part rigs and `plantedPose`. |
| `src/ReplicatedStorage/Shared/Config/MobCatalog.luau` | Updates the `SourceModule` and `NativeClipModule` references. |
| `tools/blender/mob_kit.py` | Adds the `EXTRAS` registry (name, canonical parent, `Motion` role, keyed-by sets) and a `chain()` helper. `validate` checks extras against the registry. The segment JSON gains a `Motion` field. |
| `tools/blender/mobs/<biome>.py` (all 10) | Splits the §3.8 appendages into `Extra*` segments. |
| `tools/make_enemy_model_index.py`, `src/ReplicatedStorage/Shared/Config/TowerEnemyModelIndex.luau` | The index carries `Motion` per segment, which the animator reads to choose each joint's spring. Regenerated after every biome export. |
| `assets/models/enemies/<biome>/*` | Re-exported FBX, JSON and previews, plus rebaked Tier B maps where segments changed. |
| `tests/enemy-models.spec.luau` | Extras must be in the registry under their canonical parent. The mesh-part budget allows for the declared extras. |
| `tests/studio-enemy-template-prep.luau` | Checked to make sure it keeps `Extra*` names. If it renames anything by whitelist, it gets the registry names. |

## 5. Build order

Each step is one PR off `main`, verified in the lineup before it merges.

1. **Animator core, behaviour parity.** `EnemyAnimator` with layers, smoothing, the timing map, hysteresis, desync, `Transform` writes and compiled clips, running the **current** clips. Route all three callers through it, and fix the Facility `Transform` link. The spec goes in here. *Visible win: no snapping, no lockstep breathing, no walk/idle flicker, hits flinch mid-chase, projectiles release on time.*
2. **Size and stride.** `rig.Metrics`, `MotionScale`, and cycle length from leg length. *Win: no skating, and deaths and lunges sit right on every size.*
3. **Extra-joint pipeline.** The `mob_kit` registry and `chain()`, the `Motion` field through the JSON and index, the spec updates, and the animator's springs. On the current models, springs only move `Trophy_*` joints so far.
4. **Re-export, by biome pair:** Verdant Ruins + Fungal Hollow, Ashen Dunes + Frozen Citadel, Infernal Foundry + Thunder Highlands, Corrupted Grove + Sunken Sanctuary, Astral Archives + Abyssal Throne. That's 5 PRs, each needing your hand re-import (§3.8). These can run alongside steps 5–7, because clips ignore joints a model doesn't have yet.
5. **Bipeds:** `LightBiped`, `WarriorBiped`, `HeavyBiped`, `Rooted`. Idle, fidgets, gait and their attack styles, including the keyed whip, chain, piston and bellows. This covers the most enemies, about 40 of 60.
6. **Colossi and bosses:** the `Colossus` set, Awakening, `Signature1`/`Signature2` and boss deaths. Includes `ROYAL_BIPED`, the `GIANT_AVIAN` boss styles, the Spore Matriarch's crown split and the Rift Warden's tomes.
7. **Creatures:** `Quadruped`, `Avian`, `Serpent`, `Multileg`, each with its own idle, gait, hit and death, using their keyed extras (tails, jaws, beaks, tail fans, elytra, sting). Best done after their biome pairs from step 4 have landed.
8. **Polish:** head aim, turn lean, spring tuning per role, the performance pass, the GDD and `MobCatalog` updates.

## 6. Tests and verification

**`tests/enemy-clips.spec.luau`** (pure Luau, runs under `pwsh tests/run.ps1 -LuauDirectory D:/luau`):
- every enemy in `FirstBiomeCombat.Entries` resolves to a motion set and has every slot in `RequiredSlots`;
- every move's `AnimationKey` resolves to a style clip;
- every attack clip has `0 < Release ≤ Impact < 1`, and keys are sorted with T from 0 to 1;
- every joint a clip drives exists in that set's joint contract, and every remodelled enemy's index joints include the set's required joints;
- **timing map:** for sample moves (melee, projectile, support), clip time at `t = W − lead` is `Release`, from `t = W` to `t = I` it's `Impact`, and at `t = I + R` it's 1; the map never decreases and stays within 0 to 1;
- **stride:** cycle length > 0 for every enemy, and it grows with leg length;
- **scale:** a sampled translation at `MotionScale` 2 is twice the translation at 1;
- **desync:** two seeds give different idle phases; the same seed gives the same phase;
- **no allocation:** a sample after warm-up returns the same reused table;
- **extras:** every `Extra*` joint a clip keys is in the registry. Every enemy listed in §3.8 as having keyed extras has them once its biome is re-exported (each biome's PR switches this on). Every unkeyed extra has a spring `Motion` role.

**`tests/studio-enemy-lineup.luau`:**
- **`ANIMATE = true`** loops every enemy of `BIOME` through Idle, then a fidget, then Locomotion on a treadmill (distance advanced at walking speed), then each of its attacks with **its real server timings** and the telegraph drawn, then Hit, then Death, then respawn. Screenshots per slot go to `docs/screenshots/<biome>_mobs/anim/`.
- **`WALK_LINE = true`** walks each enemy 30 studs across a grid floor, to check for foot sliding by eye.

**Performance:** `performance-plan.md` scenario B before and after steps 1, 4 (the last pair) and 7. Record client frame time and the `EnemyAnimator.Step` profile.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Some template joints aren't axis-aligned the way the factory assumes, so a rotation bends the wrong way. | `WALK_LINE` and `ANIMATE` per biome, from step 1. If needed, a per-joint axis fix-up goes in `Overrides`, not in the clips. |
| Moving from `C0` to `Transform` breaks the Facility viewport preview, or any other code that reads `C0`. | Fix `FacilityPanel`'s link math in step 1. Grep for `Motor.C0` reads before merging. |
| Clip retuning across 60 models takes a lot of art time. | Tune per motion set (9), not per enemy. Size and stride come from metrics automatically. Overrides are kept for outliers only. |
| Upper-body masking looks odd on families without a clear upper body (`Multileg`, `Serpent`). | Their mask is the head and jaws only. Their attacks are full-body and play while the mob is still, which is normal, since mobs stop to attack. |
| Smoothing blurs fast strikes. | The action layer bypasses smoothing during `Release`→`Impact`; only state changes are smoothed. |
| Re-importing 43 FBXs by hand is a lot of Studio work. | Five biome-pair batches, re-importing only the enemies that changed. The game keeps working between batches, because clips ignore missing extras. |
| Tier B rebakes change the textures, so they have to be uploaded and moderated again. | Rebake only the Elites, Alphas and Bosses whose segments changed. Until a new template lands, the old one stays in use. |
| A split appendage shows a gap or seam when it rotates. | Pivots go at natural breaks such as hinges, shoulders and tail links. The generator adds a small overlap cap (a ball or collar) at each new joint. The lineup checks the full range of motion. |
| More joints cost more per frame (about 16 → 22 per mob). | Springs and fidgets are off beyond 140 studs. Measured in performance scenario B after the last re-export batch. |

## 8. Decisions (2026-11-09)

1. **Gait method:** keyframed gaits with stride matching (§3.6). No IK foot planting.
2. **Extra joints:** yes, re-export. 43 enemies get `Extra*` joints, keyed or springs (§3.8), in five biome-pair batches (step 4).
3. **Fidget frequency:** every 6–14 s, seeded per mob (§3.7).

## How to test (per PR)

1. Run `pwsh tests/run.ps1 -LuauDirectory D:/luau`. All suites pass, including `enemy-clips.spec.luau`.
2. In Studio, sync with Rojo, then run `tests/studio-enemy-lineup.luau` with `BIOME` set, `ANIMATE = true`. Watch every enemy cycle Idle, fidget, walk, each attack, hit and death. Check that the strike lands as the telegraph fills, and that projectiles leave the hand when the orb launches.
3. Run it again with `WALK_LINE = true`. Feet should stay planted on the grid, with no moonwalking, for the Regular, the Elite, the Alpha (1.4×) and the Boss.
4. Play-test a tower floor with a full camp. Mobs breathe out of sync, walk/idle doesn't flicker while they chase, they flinch when hit mid-run, and nothing snaps between states.
5. Open the Facility mob preview and watch the hub patrol wave. Both animate the same way as the tower.
6. Run performance scenario B. `EnemyAnimator.Step` stays ≤ 0.6 ms for 48 mobs.
7. **Re-export PRs only:** after re-importing and template prep, check the biome's previews and lineup. The new joints should show no gaps when they rotate. Capes, censers and chains should swing and settle when the mob stops. Tails, jaws, beaks and the sting should move in their clips. Tier B surfaces should look the same as before the split.
