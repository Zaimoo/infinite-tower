# Vane: spell animations and VFX plan

Status: implemented (2026-11-11). All three spells have their own clip and VFX style, and the server runs `BEAM_LINE` and `SINGULARITY` (with the pull). The key poses were solved against the rig in Studio. Differences from the first draft: the Lance's left hand aims two fingers beside the staff instead of gripping it (from side-on it can't reach the shaft), the staff is levelled by the wrist and not the shoulder, and the crush pulls the fist down and in. Not yet done: a tower playtest of the effects and the pull (§7 steps 2–5).

---

## 1. Where it stands

| Tier | Spell | Clip today | VFX today | Problem |
| --- | --- | --- | --- | --- |
| Basic | Null Bolt | Generic `ByWeapon.STAFF.AttackBasic` (staff thrust) | `BOLT` / `ORB` from the chest | Identical to Eolka, Shurn and Solaris. Nothing says "Vane" |
| Special | Singularity Lance | `Overrides.hero_vane.AttackSpecial` (level, brace, recoil; Release 0.62) | `CHAIN` with a `BOLT` projectile | The clip aims a beam, but a chain-lightning bolt fires |
| Skill | Event Horizon | `Overrides.hero_vane.AttackSkill` (raise, crush; Release 0.62) | `PILLAR`, height 30, linger 4 | A pillar of light. No hole, no pull, and nothing marks the 8 ticks |

Constraints found in the code:

- **Clip length is not the clip's `Duration`.** `HeroActionTiming.CastSeconds` stretches every attack to the attack interval, clamped to `[0.35, 1.2]` and raised to the tier's `CastSeconds`. Vane's interval is 1.0, so Basic and Special play over **1.0 s** and Skill plays over **1.2 s** (the Scholar `CastSeconds`). Key times below are fractions of those.
- **Release is shared truth.** The server schedules the hit at `cast × Release` and the client starts the VFX on the same marker. Moving a Release marker moves the damage, which is fine (it's data), but any change needs the tests in §6.
- **VFX only start at Release.** `EntityRenderer` calls `SkillVfx.Play` from `OnMarker("Release")`. There is no hook for wind-up effects, so today every spell "pops" out of nothing. §4.1 adds a `Charge` marker.
- **STAFF has no muzzle.** `shotOrigin` uses the weapon's `Nock` attachment (bows only), else the rig pivot + 1.5. Staff spells leave from the chest. §4.2 adds a staff-tip and left-hand origin.
- **Keys interpolate linearly** and `HeroAnimator` smooths Transform writes at rate 18. Easing comes from key spacing: tight keys snap, repeated keys hold.
- **No finger joints.** A "clench" has to come from wrist curl, an elbow pull and a shoulder drop.
- `hero_vane.Skill.Description` says a 20-stud radius but the design says 16. Settle it on 16 with the server change, and set the VFX `Radius` to match.

---

## 2. Motion language

Eolka and Solaris throw their whole bodies into big, sweeping, two-armed casts. Vane is the opposite: **economy and contempt**. He moves as little as he can, very precisely, and the world does the work.

1. **The left hand casts, the staff conducts.** Basics come from a flick of the left hand, and the staff stays planted like a lectern. The staff only acts for the Special (a sightline) and the Skill (a conductor's baton).
2. **Slow in, snap, long hold.** Each spell has a lazy anticipation (≈35–45% of the clip), a 2–3-frame snap on Release, then a *moving hold*: the pose drifts 1–3° so it never freezes dead. Hits feel heavy because the body stops while the effect keeps going.
3. **Small amplitudes.** Waist turns ≤ 20°, root dips ≤ 0.15 studs. Big numbers are reserved for one arm per spell.
4. **A signature recovery.** After Event Horizon, he pushes up his glasses with his left middle finger. This is the beat players will remember. It is optional for the Special if the hand-to-face pose measures cleanly.
5. **Palette discipline.** Primary violet `170,80,255`, Secondary near-black `30,16,44`, Core white-violet `240,220,255`, plus a new **Accent gold `225,180,90`** used only for the accretion ring and the lens glint. The black is the star: void effects read as *absence*, with bright rims around dark centres, and are never just glowing purple blobs.

---

## 3. Spell by spell

Joint values are `{rx, ry, rz}` degrees in the `HeroRigSpec` convention (shoulder/hip +X forward, elbow +X flex, knee −X flex, waist/neck −X lean forward, +Y turn left). They are first-pass numbers. Each one marked *measure* needs a Studio check against the staff and the mantle (§7).

Every clip starts from and returns to a new **`ready`** pose: `p.Stand` with the left arm held a little forward, which is his idle hand without the full presentation (`LeftShoulder {30,0,-18}`, `LeftElbow {50,0,0}`). This keeps the hand-off from Idle to an attack under the 0.08 s fade.

### 3.1 Null Bolt (Basic): "The Dismissal"

A two-finger flick from the left hand, as if he's tapping ash off a cigarette. The staff doesn't move.

**Clip** `Overrides.hero_vane.AttackBasic`, `signature(1.0, …)`, markers `{ Charge = 0.2, Release = 0.52 }` (release at 0.52 s).

| Fraction | Beat | Pose (deltas on `ready`) |
| --- | --- | --- |
| 0.00 | ready | `ready` |
| 0.20 | Cock: hand drawn back in front of the left shoulder, wrist bent back | `Waist {0,10,0}`, `LeftShoulder {38,-20,-12}`, `LeftElbow {108,0,0}`, `LeftWrist {-40,0,0}`, `Neck {-2,-6,0}` (measured: `{70,…}/115` put the hand in the hair) |
| 0.45 | Late anticipation (a slow creep, so the snap reads) | the cock pose, with `LeftElbow {114,0,0}` and `LeftWrist {-48,0,0}` |
| 0.52 | **Snap**: forearm whips out, wrist flicks forward | `Waist {-4,-8,0}`, `LeftShoulder {82,10,-12}`, `LeftElbow {18,0,0}`, `LeftWrist {35,0,0}` |
| 0.58 | Overshoot | `LeftWrist {45,0,0}`, `LeftElbow {10,0,0}` |
| 0.80 | Moving hold, hand still out, wrist relaxing | `LeftShoulder {76,8,-12}`, `LeftElbow {22,0,0}`, `LeftWrist {15,0,0}` |
| 1.00 | ready | `ready` |

Legs stay on `p.Stand` (no weight shift). He doesn't step into a basic.

**VFX** (Style `BOLT`, recipe changes: `Origin = "LEFT_HAND"`, `Projectile = "VOID"`, `ImpactStyle = "IMPLODE"`):

- **Charge (0.2 → 0.52):** a palm-sized glyph disc (`Disc`, radius 0.35, Primary, transparency 0.4) appears in front of the left palm and spins up. Three Motes are drawn in from 1.5 studs. It is deliberately tiny.
- **Release:** the glyph pops (Core `Burst`, 0.6 studs) and the bolt leaves the left hand.
- **Projectile `VOID`** (new `ProjectileVfx` kind): a black core sphere (SmoothPlastic, Secondary) with a violet Neon rim shell 1.3× its size, a short Primary trail that **tapers to black**, and two small orbiting motes. It flies straight (`Arc = 0`).
- **Impact `IMPLODE`:** instead of an outward burst, a Primary ring **contracts** from 2.5 → 0 studs over 0.12 s, then a 1.9-stud Core flash (`Burst`, 0.15 s). It reads as the hit being swallowed. `Ring` already lerps `From → To`, so `From = 2.5, To = 0.2` needs no new primitive.

### 3.2 Singularity Lance (Special): "Sightline"

He turns side-on and levels the staff like a sniper sighting down a rifle, with the left hand guiding the shaft. A charged pause, a beam, recoil, and a contemptuous flourish back to rest.

**Clip** `Overrides.hero_vane.AttackSpecial`, rewritten, `signature(1.0, …)`, markers `{ Charge = 0.2, Release = 0.55 }`.

| Fraction | Beat | Pose |
| --- | --- | --- |
| 0.00 | ready | `ready` |
| 0.20 | Turn side-on; staff swings down off vertical; left hand reaches for the shaft | `Waist {-2,-22,0}`, `Neck {-4,20,0}` (eyes stay on target), `RightShoulder {60,-10,6}`, `RightElbow {30,0,0}`, `LeftShoulder {70,30,-4}`, `LeftElbow {50,0,0}`; left foot forward `LeftHip {14,0,-6}`, `RightHip {-10,0,6}` |
| 0.40 | **Sighted**: staff level, left hand on the shaft (*measure*), chin down on the line | `levelled`: `Waist {-6,-24,0}`, `Neck {-8,22,0}`, `RightShoulder {88,-10,6}`, `RightElbow {8,0,0}`, `LeftShoulder {84,28,-6}`, `LeftElbow {28,0,0}`, knees `-16/-12`, `RootOffset {0,-0.12,0}` |
| 0.52 | Moving hold (a 2° drift forward builds pressure) | `levelled` with `Waist {-8,-24,0}`, `RightShoulder {90,-10,6}` |
| 0.55 | **Fire**: the body locks for 3 frames | as 0.52 |
| 0.60 | **Recoil**: tip kicks up, chest back, a half-step back | `Waist {6,-18,0}`, `RightShoulder {104,-10,6}`, `LeftShoulder {74,24,-10}`, `LeftElbow {40,0,0}`, `RootOffset {0,-0.08,0.14}` |
| 0.75 | Release the shaft, left hand falls away palm-up (a dismissive "there") | `RightShoulder {70,-6,10}`, `LeftShoulder {40,10,-24}`, `LeftElbow {55,0,0}`, `LeftWrist {0,0,-30}` |
| 0.88 | Staff rolls back upright (`RightWrist` roll 0 → 90 across 0.75–0.88 gives a quarter spin) | `p.Stand` arms, `RightWrist {45,-35,90}` → settle |
| 1.00 | ready | `ready` |

**VFX** (new Style `BEAM`; recipe `{ Style = "BEAM", Origin = "STAFF_TIP", Length = 36, Width = 3, Impact = 2.2, Linger = 0.3, Shake = 0.12 }`):

- **Charge (0.2 → 0.55):** motes stream *into* the staff tip from a 3-stud cone ahead of it. A dark sphere grows at the tip (`Shell`, 0 → 0.6 studs, Secondary) with a thin Core rim. In the last 0.1 s, a gold Accent **lens glint** (a short cross-flare built from two thin Neon parts) flashes on the tip. That's the tell that it's about to fire.
- **Release (impact = release, `Delivery = "AREA"`, `TravelSeconds = 0`):**
  - A new primitive, **`Lance`**, draws three nested cylinders along the line: a Core core (0.35 × Width), a Primary sheath (0.7 × Width, transparency 0.3), and a Secondary outer haze (Width, transparency 0.7). It **extends** from the tip to full `Length` over 0.06 s, holds for 0.08 s, then thins (radius → 0) and fades over `Linger`.
  - Two `Beam` jagged arcs (existing primitive) wrap the outside in Primary and Secondary, so the core looks like it's being torn through space.
  - A muzzle `FlightRing` (radius 1.2, Core) faces along the beam, plus a second ring 0.08 s later at radius 2. That's the shockwave the recoil sells.
  - On each server-reported hit along the line (`afterHits("HIT", …)` with a line filter): a small `IMPLODE` contraction plus a black spark. Hits are staggered by distance along the line (≈ 0.004 s per stud), so the beam visibly "passes through" the pack.
  - An afterimage: 6 Motes evenly spaced along the line drift outward and fade over 0.4 s.
- **Geometry must match the server:** the line runs from Vane's **feet** (`Self()`) through `Cue.Aim`, extended to `Length` (that's what `BEAM_LINE` hits), and is lifted to chest height. Only the near end bends to the staff tip. The test in §6 asserts the client's endpoint formula equals the server's.

### 3.3 Event Horizon (Skill): "The Crush"

He reaches toward the target with an open hand, gathers space, and closes his fist. The hole is born on the clench, and the staff tip points at it like a conductor holding a note. Then he twists the fist (the pull), lets go, and pushes up his glasses.

**Timing change:** `hero_vane.Skill.CastSeconds = 1.4` (Scholar is 1.2). The extra 0.2 s pays for the hold and the glasses push. That's 0.2 s more lockout than Solaris, which suits his lower burst. If balance objects, the fallback is 1.2 s with the glasses beat cut. **Release = 0.5 → 0.70 s**, then the 8 ticks run 0.70 → 4.20 s (the clip ends at 1.40 s, and the hole outlives him).

**Clip** `Overrides.hero_vane.AttackSkill`, rewritten, `signature(1.4, …)`, markers `{ Charge = 0.15, Release = 0.5 }`.

| Fraction | Beat | Pose |
| --- | --- | --- |
| 0.00 | ready | `ready` |
| 0.15 | **Gather**: half-step back, staff planted (butt down), left arm sweeps out to the side, palm open | `Waist {4,8,0}`, `RightShoulder {12,0,24}`, `RightElbow {40,0,0}`, `LeftShoulder {60,0,-70}`, `LeftElbow {10,0,0}`, `LeftWrist {0,0,-20}`, `RootOffset {0,-0.05,0.08}` |
| 0.38 | **Reach**: arm sweeps forward to the target at head height, palm out; staff rises so the tip sits beside his head; chin up | `reach`: `Waist {-4,-6,0}`, `Neck {6,0,0}`, `RightShoulder {120,0,14}`, `RightElbow {30,0,0}`, `LeftShoulder {100,10,-8}`, `LeftElbow {8,0,0}`, `LeftWrist {-30,0,0}` (palm toward target) |
| 0.46 | Creep: fingers "resist" (arm trembles 2° forward) | `reach` with `LeftShoulder {102,10,-8}`, `LeftWrist {-34,0,0}` |
| 0.50 | **Clench**: forearm pulls in, wrist curls, shoulder drops; waist snaps forward | `crush`: `Waist {-10,-4,0}`, `Neck {-4,0,0}`, `LeftShoulder {88,8,-10}`, `LeftElbow {45,0,0}`, `LeftWrist {40,0,0}`, `RightShoulder {150,0,10}`, `RightElbow {18,0,0}`, `RootOffset {0,-0.12,0}` |
| 0.54 | Impact settle (2-frame overshoot) | `crush` with `Waist {-12,-4,0}`, `LeftElbow {50,0,0}` |
| 0.62 / 0.68 / 0.74 | **Held control**: micro-tremor ±1.5° on `LeftShoulder`/`LeftWrist` across three keys, staff tip tracking the hole | `crush` ± tremor |
| 0.80 | **Twist**: he turns the closed fist (the "screw"), which visually pairs with the first pull tick | `LeftWrist {40,0,-55}`, `LeftElbow {55,0,0}` |
| 0.86 | Let go: arm drops, staff returns upright | `p.Stand` right arm; `LeftShoulder {35,0,-15}`, `LeftElbow {70,0,0}` |
| 0.94 | **Glasses push**: left middle finger to the bridge (*measure*, the hand must stop in front of the face decal, not inside the head) | `LeftShoulder {125,20,-4}`, `LeftElbow {140,0,0}`, `LeftWrist {-20,0,0}`, `Neck {-6,4,0}` |
| 1.00 | ready | `ready` |

**VFX** (new Style `SINGULARITY`; recipe `{ Style = "SINGULARITY", Radius = 16, Core = 2.6, Impact = 5, Shake = 0.3, Tether = true }`; tick times from `HeroActionTiming.Ticks(profile.Skill)` and `VfxMath.WaveTimes`, like `WAKE`):

| Phase | When | What |
| --- | --- | --- |
| **Charge** | Charge → Release (0.21 → 0.70 s) | At the aim point: a ground `Ring` **contracts** from Radius → 1 (Secondary, width 0.8); 12 Motes spiral inward on a log spiral; a dark ground `Disc` fades in to transparency 0.35 (the floor "dims"). If `Tether`, a thin flickering Primary `Beam` runs from Vane's left hand to the point (he is holding it). |
| **Birth** | Release (0.70 s) | A 0.1 s Core pinpoint flash, then the **event sphere** grows 0 → `Core` studs over 0.15 s: a black SmoothPlastic sphere plus a slightly larger Neon Primary rim shell at transparency 0.6. An **accretion disc** appears (new primitive `Accretion`: a flat torus-like ring of 2 Neon discs, Accent gold outer and Primary inner, tilted 18° toward the camera side, spinning at 1.2 rev/s). A shockwave `Ring` runs *inward* from Radius → Core (space folding), and camera shake 0.18. |
| **Sustain** | each of the 8 ticks | The sphere "breathes" +12% for 0.1 s. The accretion ring flashes brighter. For every server hit in radius (`afterHits` per tick), a short Primary `Beam` streak runs from the mob toward the centre (the pull vector), plus a black spark on the mob. Debris Motes are emitted at the rim and spiral in. A rotating rim `Ring` at Radius marks the danger area for the whole lifetime. |
| **Collapse** | last tick (4.20 s) | The sphere and accretion shrink to 0 over 0.12 s, a 0.05 s pause (a beat of nothing), then a Core `Burst` of `Impact` studs, an outward `Ring` 1 → Radius × 1.1 (width 1.2), 10 Motes flung out, shake `Shake`. The ground disc fades over 0.4 s. |

**The pull itself is server movement.** Mobs slide inward through `EntityRenderer`'s 60 FPS interpolation of the 5 Hz sim, 0.5 s per tick, so the pull reads as a stepped slide. That's fine because each step lines up with a streak and a breath. No client-side position faking: it would fight the interpolation and lie about where mobs are.

---

## 4. Plumbing

### 4.1 `Charge` marker (anticipation VFX)

- `HeroClips`: hero overrides may add `Charge = <fraction>` to `Markers`, always before `Release`. Weapon defaults don't change.
- `EntityRenderer` `OnMarker`: on `"Charge"` with `action.Data`, call `SkillVfx.PlayCharge(pool, args)` (pcall-wrapped like Release). `args` is built by the same function as `playAttackVfx`, so factor out `attackArgs(rig, animator, meta, cue)`.
- `SkillVfx.PlayCharge`: looks up the tier recipe and calls `CHARGERS[recipe.Style]` if there is one. Charge effects end **at Release** (`EndAt = releaseAt` from `VfxMath.FlightWindow`), so if the attack is cancelled (the hero is hit or goes into coma) they stop on their own and nothing dangles.
- Cosmetic only: the server ignores `Charge`.

### 4.2 Cast origins

New optional recipe field `Origin: "CHEST" | "LEFT_HAND" | "STAFF_TIP"` (default: today's behaviour). `EntityRenderer` resolves it:

- `STAFF_TIP`: a `Tip` attachment on the equipped staff prefab. Check `HeroSockets.PREFABS` and `WeaponModelBuilder`. If staves have no tip attachment, add one at the head of each STAFF prefab (WeaponVfx's `_Upper` glint emitter already sits there, so its parent is the reference).
- `LEFT_HAND`: `LeftHand.LeftGripAttachment.WorldPosition` (`EntityRenderer.castPoint`).
- Both fall back to the chest point. Pass `OriginOf: (name) -> Vector3` in `PlayArgs` so Charge and Release effects can track the hand or tip live while the clip moves.

### 4.3 Catalog and players

`SkillVfxCatalog.luau`:
- Types: `Palette.Accent: Color3?`; `TierRecipe` gains `Origin`, `ImpactStyle`, `Length`, `Width`, `Core`, `Tether`.
- `Styles.Special.BEAM = true`, `Styles.Skill.SINGULARITY = true`, and update the header comment.
- `hero_vane`: Accent in the palette; Basic `{ Style = "BOLT", Projectile = "VOID", Origin = "LEFT_HAND", ImpactStyle = "IMPLODE", Scale = 0.9, Arc = 0, Trail = 0.18, Impact = 1.9 }`; Special and Skill as in §3.

`SkillVfx.luau`: `playBeam`, `playSingularity`, `CHARGERS = { BOLT = chargeGlyph, BEAM = chargeTip, SINGULARITY = chargeWell }` (BOLT only charges when `Origin == "LEFT_HAND"`, so other casters stay unchanged), and an `ImpactStyle` branch in `playProjectile`.

`VfxPrimitives.luau` (new, each pooled through `VfxPool.Acquire` with its own kind):
- `Lance(pool, a, b, width, palette, at, extend, hold, fade)`: three nested cylinders.
- `Accretion(pool, center, radius, tilt, inner, outer, startAt, endAt, spin)`: a spinning tilted ring pair.
- `Sphere(pool, center, fromR, toR, color, material, startAt, endAt)`: a radius-animated ball for the event sphere and the tip well. `Shell` follows a centre but doesn't animate radius, so check whether extending `Shell` is cleaner than adding this.
- `Flare(pool, pos, size, color, at, duration)`: the cross-shaped lens glint.

`ProjectileVfx.luau`: a `VOID` kind (dark core, Neon rim, tapered trail, two orbit motes).

### 4.4 Config (`ArchetypeCombatSkills.hero_vane`)

- `Skill.CastSeconds = 1.4`; `Skill.Description` radius → 16.
- `Special.Delivery = "AREA"`, `TravelSeconds = 0`, together with `SecondaryEffect = "BEAM_LINE"` (server plan). **Ship order:** the `BEAM` VFX must not land before `BEAM_LINE`, or the beam would hit things it didn't damage. Land them in one commit.

### 4.5 Performance budget

Peak pooled parts per effect: Basic ≤ 8, Special ≤ 24, Skill ≤ 40 (sustain streaks are capped at 8 mobs per tick, like `CRYSTALS` caps at 10). Up to 10 Vanes can be in a server, but tower rooms are per squad, and `pool:Visible` already culls far effects. No `ParticleEmitter`s are created per cast: motes come from the pool. Neon is limited to rims, cores, the accretion ring and the flare.

---

## 5. Files touched

- `src/ReplicatedStorage/Assets/HeroRig/HeroClips.luau`: `ready` pose; Vane `AttackBasic` (new), `AttackSpecial` and `AttackSkill` (rewritten); `Charge` markers; marker comment.
- `src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau`: `attackArgs` factor-out, `Charge` dispatch, `OriginOf`.
- `src/ReplicatedStorage/Assets/CombatVfx/SkillVfx.luau`, `VfxPrimitives.luau`, `ProjectileVfx.luau`.
- `src/ReplicatedStorage/Shared/Config/SkillVfxCatalog.luau`, `ArchetypeCombatSkills.luau`.
- The staff prefab(s): `Tip` attachment, if missing (`WeaponModelBuilder` / `HeroSockets`).
- `tests/hero-rig.spec.luau`, `tests/combat-vfx.spec.luau` (+ a timing case wherever `HeroActionTiming` is covered).
- Docs: `docs/vane-hero-plan.md` §3.5 points here; GDD kit table (cast 1.4 s, radius 16); `docs/projectile-skill-vfx-plan.md` style list (BEAM, SINGULARITY, Charge marker, Origin).

---

## 6. Tests

`hero-rig.spec`:
- Vane resolves his own `AttackBasic`/`AttackSpecial`/`AttackSkill` with STAFF and falls back to UNARMED without it (existing pattern).
- **Every override**: if `Charge` exists, `0 < Charge < Release`. Add this to the generic marker loop so future heroes are covered.
- Keys are sorted, start at 0, end at 1, and the first and last keys equal `ready`/`Stand` (smooth hand-off).

`combat-vfx.spec`:
- `BEAM` and `SINGULARITY` are in both `SkillVfxCatalog.Styles` and `SkillVfx.Styles` (the existing parity check picks this up once registered), and `VOID` is a known projectile kind.
- Every `Origin`/`ImpactStyle` value is in its allowed set.
- Beam endpoint: the client formula `feet + flatDir(feet→aim) × Length` equals the server `BEAM_LINE` segment for a few fixtures.
- Singularity wave times: 8 waves, 0.5 s apart, starting at impact, matching `HeroActionTiming.Ticks`.

Timing:
- `HeroActionTiming.For("hero_vane", "STAFF", "SKILL", def, 1.0, d)` gives cast 1.4 and release 0.70; Basic release 0.52; Special release 0.55 with zero travel.

Run `pwsh tests/run.ps1`.

---

## 7. Studio verification (Studio MCP)

1. **Pose pass on a temp rig** (the `hero-remodel` skill's temp-rig flow): for each clip, apply the pose at every key fraction with `HeroAnimator` set to that time, and capture front and side screenshots. Check that the staff doesn't pass through the mantle or head at 0.38–0.54 of the Skill, that the left hand meets the shaft at Special 0.40 (*measure*), and that the glasses push stops in front of the face (*measure*). Write the measured values back into `HeroClips`.
2. **Motion pass:** play each clip at real speed in a tower room against a dummy pack, and check the Idle → attack → Idle blend for pops (mostly from the `ready` pose).
3. **VFX pass:** in a playtest, cast each tier from close, mid and max range (32). Check the beam end against the hit numbers, that streaks point to the centre and land with damage numbers, and that collapse lines up with the last tick. Read the console for `CombatVfx:` warnings.
4. **Readability:** test on a bright biome and a dark biome. The black sphere needs its rim to read on dark floors, so raise the rim transparency or Core brightness if it disappears.
5. **Perf:** five-hero squad with Vane casting Skill into a 12-mob pack. Check `VfxPool:Count()` stays within §4.5 and the MicroProfiler shows no spike on collapse.

---

## 8. Order of work

1. Plumbing with no visual change: the `Charge` marker dispatch, `attackArgs`, `OriginOf`, catalog types, staff `Tip` attachment. Tests green.
2. **Null Bolt**: clip, `VOID` projectile, glyph charge, `IMPLODE` impact. It's the smallest piece and proves the Charge/Origin plumbing end to end.
3. **Event Horizon**: clip + `CastSeconds 1.4`, `Sphere`/`Accretion`, `SINGULARITY` phases. It can land before the server pull: the visuals stay true without movement because damage ticks are already 8 × 0.5 s.
4. **Singularity Lance**: clip, `Lance`/`Flare`, `BEAM`, in the same commit as the server `BEAM_LINE`.
5. Studio pose and VFX passes (§7), measured values written back, docs, `pwsh tests/run.ps1`, then commit (with the user's OK).

## 9. Risks

- **Hand-to-staff and hand-to-face contacts** are the fragile poses. They depend on the costume's sleeve and mantle shapes, so measure them after the costume fit pass, not before.
- **1.4 s Skill lock** changes DPS a little. Check it with the Event Horizon balance pass in the hero plan; the fallback is §3.3.
- **Beam/server mismatch** if `BEAM_LINE` uses a different origin (hero position vs. `hit.Impact.Origin`). Pin it with the §6 endpoint test.
- **Black reads as a hole only with a rim.** Without the Neon rim shell and the gold accretion, it looks like a missing texture. Don't cut those for perf: cut motes first.
