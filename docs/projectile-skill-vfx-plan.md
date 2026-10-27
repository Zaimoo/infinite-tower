# Implementation Plan: Marksman Projectiles and Skill VFX/Animations

## Goal

1. **Marksman attacks fire real projectiles.** Every Basic, Special and Skill from a `BOW` hero (Jenna, Astrea) leaves the bow at the release frame, flies to the target, and the damage number appears when it lands, not before the archer has drawn.
2. **Every hero's Special and Skill has its own VFX and animation.** All 12 heroes get signature visuals for their kit (GDD §4.4 ledger), built from a small shared set of effect primitives and driven by data, not one-off code per hero.
3. **Server stays authoritative.** Damage, targets and areas are decided on the server. The client only draws what the server already decided, and its timing comes from the same shared numbers the server uses.

Out of scope: damage numbers, balance multipliers, new skill mechanics, enemy projectiles (the `PROJECTILE` enemy attack in `AttackTimeline` / `EnemyAnimationController` already works) and uploaded animation or particle assets. Everything stays code-authored, like the hero rigs.

This plan supersedes the draft in `docs/animations-implementation-plan.md`. Parts of that draft already landed (the `HERO_ATTACK` cue, the BOW clips in `HeroClips`, the per-hero kits in `ArchetypeCombatSkills`). The rest is replaced here.

## Where things stand (2026-10-26)

| Piece | State |
| --- | --- |
| `CombatSimulation` hero attack (`stepHeroSimulation`, ~L1355–1625) | Picks tier (BASIC/SPECIAL/SKILL), broadcasts `HERO_ATTACK`, then **applies damage on the same tick**. Special/Skill mechanics are inline `if simHero.Archetype == ...` blocks. |
| `HERO_ATTACK` cue | `CombatVFX` (unreliable). Overloads the hit-number slots: `amount` = NetId, `isOverdrive` = tier 1–3, `incoming` = interval ms. No target, no aim point, no server time. |
| `EntityRenderer` | Plays `AttackBasic/Special/Skill` via `HeroAnimator:PlayAction(state, interval)`. Spawns nothing. |
| `HeroClips` BOW | Draw/release keys exist. Release is at ~0.72 of the clip, so with a 0.8 s interval the string lets go ~0.58 s **after** the server already dealt damage. |
| `CombatFeedback:SpawnArrowProjectile` | ~280 lines of Jenna-flavoured arrow, volley and arrow-rain code. **Never called.** |
| Skill primary hit | Server sends `vfxRemoteType = skillProfile.Skill.VFXKey` (`MARKSMAN_SKILL`, `VANGUARD_SKILL`, ...). The client only handles `SKILL_CAST`, `SKILL_TEMPEST`, ... so **the ultimate's main-target damage number never shows** (bug). |
| Rain of Arrows | GDD says 4 ticks over the area; the server deals one instant 0.5× splash. |

The core problem is timing: as long as damage lands on the decision tick, no projectile can look right. So the plan starts with a server-side action timeline for heroes, mirroring what enemies already do with `AttackTimeline` (windup → travel → impact).

## Target architecture

```
CombatSimulation (5 Hz decision)            Heartbeat (server)
  decide tier, target, aim                    HeroImpactQueue.Drain(now)
  timing = HeroActionTiming.For(...)            ├ target still valid? → damage, HIT_* number
  HeroImpactQueue.Push(impact @ t_impact) ──►   ├ tier effect → HeroSkillEffects.Resolve(...)
  broadcast HeroCue (buffer)                    └ multi-tick skills re-push their next tick
        │
        ▼ CombatVFX (unreliable, room-scoped)
EntityRenderer
  HeroAnimator:PlayAction(tier, castSeconds, startOffset)
  at clip marker "Release" → SkillVfx.Play(heroId, tier, cue, rig)
                                  ├ ProjectileVfx (arrow / bolt / orb flights)
                                  └ VfxPrimitives (rings, sigils, pillars, beams, rain, shells)
HIT_SPARK / HIT_SPECIAL / HIT_SKILL arrive at impact time → CombatFeedback numbers
```

### 1. Shared timing (`HeroActionTiming`, new, `Shared/Util`, `--!strict`)

One pure module both sides require, so the server's impact time and the client's release frame cannot drift.

- `HeroClips` clips gain optional markers: `Markers = { Release = 0.72 }` (fraction of the clip). `Release` means the moment the attack is delivered: the arrow leaves the bow, or the blade makes contact. Bows also carry `Nock`. Default when missing: `0.6`.
- `HeroActionTiming.For(heroId, weaponType, tier, interval, distance) -> { CastSeconds, ReleaseSeconds, TravelSeconds, ImpactSeconds }`
  - `CastSeconds = clamp(interval, 0.35, 1.2)` for Basic/Special (the clamp `EntityRenderer` already uses moves here). For Skill: `max(that, Skill.CastSeconds)`.
  - `ReleaseSeconds = CastSeconds * marker`.
  - `TravelSeconds = distance / ProjectileSpeed` for projectile tiers, else 0.
- New config fields on each tier in `ArchetypeCombatSkills` (inherited by hero kits, overridable): `Delivery = "MELEE" | "PROJECTILE" | "AREA"`, `ProjectileSpeed` (studs/s), `Ticks` and `TickSeconds` (multi-hit), and `Skill.CastSeconds`.
  - Marksman defaults: Basic `PROJECTILE` 95 st/s; Special `PROJECTILE` 120 st/s (pierce line); Skill `AREA`, `CastSeconds = 1.1`, `Ticks = 4`, `TickSeconds = 0.15`, the first tick after a 0.35 s flare flight.
  - Healer/Scholar Basic also become `PROJECTILE` (GDD already calls them projectiles), so they get bolts and orbs for free.
- `HeroClips` lives in `Assets`, and the server requiring it is fine (ReplicatedStorage). If that feels wrong, move markers into the config instead. That is a Phase 0 decision.

### 2. Server impact queue (`HeroImpactQueue`, new, `ServerScriptService/Combat`)

- A pure, testable queue: `Push(impact)`, `Drain(now, resolve)`. The resolver is injected, like `AttackTimeline`.
- An impact records: attacker identity (`AttackTimeline.Identity`), target identity, tier, aim position, `ImpactAt`, a damage snapshot (`EffectiveATK × mult`, overdrive flag) and the tick index.
- Drained from a `RunService.Heartbeat` connection, not the 5 Hz step. A 200 ms grain is too coarse for a 0.3 s arrow. The queue is tiny (≤ 30 heroes × ~2 in flight).
- Rules:
  - **Attacker leaves before release** (coma, room change, recall whistle): cancel. After release, the arrow is in the air and still lands.
  - **Target dead or gone at impact**: Basic and Special fizzle (no damage; the client arrow sticks into the last position). Area skills still resolve against whatever is in the radius.
  - The skill gauge is still granted on the decision tick, so cadence stays deterministic (GDD §4.4 maths unchanged).
  - PvP (`targetEnemyHero`) goes through the same path, with 25% damage and barrier absorption applied at impact.
- `AttackCooldown` becomes `max(effectiveInterval, CastSeconds)` on Skill attacks only. That is a small deliberate slowdown so ultimates read on screen. Document it in GDD §4.4.

### 3. Effect resolution (`HeroSkillEffects`, new, `ServerScriptService/Combat`)

- Move the inline Special and Skill blocks out of `stepHeroSimulation` into `Resolve(simHero, impact, ctx)`, keyed by archetype as now. Behaviour is unchanged except:
  - Marksman Skill becomes 4 ticks of `2.8 × ATK / 4` across the 16-stud radius (matches the GDD), with defense shred applied on the first tick.
  - The primary-hit number for Skill uses a real client key: `HIT_SKILL`. This fixes the missing-ultimate-number bug.
- `ctx` passes in `ActiveMobsByNetId`, `handleMobDeath`, `Tower.BroadcastAt` and so on, so `combat-skills.spec.luau` can drive it without the full sim.
- This also shrinks `CombatSimulation.server.luau` (2,063 lines) by roughly 250.

### 4. Network cue (`HeroCue`, in `TowerProtocol`)

Replace the overloaded `HERO_ATTACK` arguments with one packed buffer on the same `CombatVFX` remote, keeping the project's "binary buffers" rule (CLAUDE.md, GDD §8):

| Field | Type | Bytes |
| --- | --- | --- |
| Tag (7), tier (1–3), flags (bit 0 overdrive), padding | u8 × 4 | 4 |
| Attacker NetId, attacker generation, target NetId (0 = none) | u32 × 3 | 12 |
| CastMs, ReleaseMs, TravelMs, padding | u16 × 4 | 8 |
| StartServerTime | f64 | 8 |
| Aim position | f32 × 3 | 12 |
| **Total** | | **44** |

NetIds are u32 in the v2 protocol, so the cue uses u32 too. The attacker generation lets the client drop a cue meant for a replaced entity.

- `TowerProtocol.EncodeHeroCue` and `DecodeHeroCue`. The client validates with `P.Finite` / `P.Integer` and drops anything malformed.
- The remote is unreliable, so a lost cue only loses the visual. Damage itself is server state, and its number arrives separately with the `HIT_*` event at impact. A **late** cue fast-forwards: `elapsed = GetServerTimeNow() - StartServerTime`. The animation starts at that offset, and if `elapsed > ReleaseMs + TravelMs` the projectile is skipped.
- Bandwidth: ≤ 30 heroes × ~1.25 cues/s × 44 B ≈ 1.7 KB/s per room worst case. Fine.

### 5. Client animation (`HeroAnimator`, `HeroClips`)

- `HeroAnimator:PlayAction(state, duration, startOffset?, data?)` plus a plain `OnMarker(name, action)` callback field. It fires once per marker as the action passes it, then `"End"` when the action finishes or is replaced.
- `EntityRenderer` HERO_ATTACK handler: decode the cue, `PlayAction(ATTACK_TIER_STATES[tier], CastSeconds, elapsed)`, and stash the cue on the action so the `Release` marker can spawn the VFX.
- **Bow arrow handling:** at `Release`, hide the bow's `HunterArrow` (`LocalTransparencyModifier = 1` on its parts). Show it again at a `Nock` marker (~0.9), or when the action ends. The projectile spawns at the bow's `Nock` attachment world CFrame (`WeaponModelBuilder` already adds it).
- **Signature clips** (`HeroClips.Overrides[heroId]`), added per hero in Phase 4. They exist for the Skill tier for all 12 heroes and the Special tier where the weapon default does not fit the move (e.g. Velkist's *Shadow Rend* blink, Catio's *Resonance Tremor* ground strike). Each keeps the `Release`/`Impact` marker. Skill clips are authored at `Skill.CastSeconds` length (1.1–1.4 s) instead of being squashed into the 0.8 s interval.
- `hero-rig.spec.luau` gains a check that every `Attack*` clip's markers lie in (0, 1) and that every hero/weapon resolves an `AttackSkill` clip.

### 6. Client VFX (`ReplicatedStorage/Assets/CombatVfx/`, new folder)

| Module | Job |
| --- | --- |
| `VfxPool` | Recycles anchored, non-colliding, non-querying parts and attachments. One `Step(now)` from `EntityRenderer`'s render loop. No `Debris`, no per-effect `TweenService` in the hot path. |
| `VfxPrimitives` | ~10 building blocks: `Flight` (arc/straight, with trail), `Burst` (expanding sphere), `GroundRing`, `Sigil` (rotating ring with runes), `Pillar`, `Beam`/`Chain` (segment arcs between points), `Rain` (N flights from a sky disc), `Shell` (barrier bubble), `SlashArc` (crescent wedge sweep), `Aura` (rising motes). Each takes a palette and a duration. |
| `ProjectileVfx` | Projectile bodies: `ARROW` (shaft, head and fletching, from today's `buildProjectileArrow`), `BOLT` (glowing spear), `ORB`, `STAR`. `SpawnArrowProjectile` moves here from `CombatFeedback`, generalised by palette. |
| `SkillVfx` | `Play(heroId, tier, cue, rig)` looks up the recipe and composes primitives. Flights end at `cue.Aim` (or the target's live interpolated position if it is still rendered) at `StartServerTime + ReleaseMs + TravelMs`, so the visual lands in the same frame the number arrives. |

`CombatFeedback` keeps hit numbers and screen shake only, and gains `HIT_SKILL` (gold, 1.25× per GDD §4.4.4).

**Data: `Shared/Config/SkillVfxCatalog.luau`** (`--!strict`, tabs). This is pure data keyed `[heroId][tier]`, with an archetype fallback:

```lua
hero_jenna = {
	Palette = { Primary = Color3.fromRGB(120, 235, 255), Secondary = Color3.fromRGB(90, 255, 170) },
	Basic = { Projectile = "ARROW", Trail = 0.6, Impact = "Burst" },
	Special = { Projectile = "ARROW", Count = 3, Spread = 6, Pierce = true, Impact = "Burst" },
	Skill = { Sequence = { { "Flight", To = "Sky", Projectile = "ARROW" }, { "Sigil", At = "Aim", Radius = 16 }, { "Rain", Count = 14, Ticks = 4 } }, Shake = 0.25 },
},
```

**Performance budget:** at most 48 live flights and 400 pooled parts per client. Effects more than 180 studs from the camera are culled, and above the cap the oldest effect drops to its impact burst only. Other players' squads in the room draw Basic projectiles at half trail length. Parts use `Neon`/`ForceField`, `CastShadow = false`, and no `PointLight` except on Skills (one each, so lights stay under 10 at once).

### 7. Visual direction per hero

Marksman first (Phase 3); the rest in Phase 5.

| Hero | Special | Skill (ultimate) |
| --- | --- | --- |
| **Jenna** (BOW) | *Piercing Gale Volley*: 3-arrow fan; the centre arrow carries cyan wind rings and pierces 32 studs. | *Sylphid Arrow Storm*: flare arrow skyward, emerald sigil opens over the aim point, 14 arrows rain in 4 waves (one per damage tick). |
| **Astrea** (BOW) | *Nebula Piercer*: violet star-bolt that leaves a fading nebula ribbon. | *Constellation Judgment*: lines draw a constellation above the area, then each star drops as a white-gold bolt (4 waves). |
| **Han** (DAGGERS) | *Crescent Cross-Cut*: two crossing wind crescents. | *Relentless Blade Flurry*: afterimage dashes plus a ring of slash arcs (12 st). |
| **Velkist** (DAGGERS) | *Shadow Rend*: dark slash with a short blink smear. | *Phantom Lotus Execution*: purple lotus of blade petals blooms and closes. |
| **Archon** (DAGGERS) | *Rift Sever*: a line tear that lingers 0.3 s. | *Dimensional Cataclysm*: a sphere implodes then bursts, with shards. |
| **Aaron** (SWORD_SHIELD) | *Aegis Shield Bash*: frontal cone shockwave. | *Fortress Bulwark*: gold shell plus a taunt ring pulse (25 st). |
| **Ignis** (SWORD_SHIELD) | *Magma Breaker*: cone of ember cracks. | *Infernal Juggernaut*: molten shell plus a fire taunt ring. |
| **Morrigan** (SWORD_SHIELD) | *Dread Shockwave*: dark cone with smoke motes. | *Obsidian Bastion*: black-glass shell plus a dread ring. |
| **Catio** (AXE) | *Resonance Tremor*: ground ring with cracks (8 st). | *Crystalline Excavation*: crystal spikes erupt under each hit enemy. |
| **Valeria** (TOME) | *Verdant Mend*: leaf bolt to the enemy, plus green motes to the healed ally. | *Sanctuary Miracle*: a 25-stud green circle with a rising light column on each ally. |
| **Eolka** (STAFF) | *Wildfire Chain*: red arcs hop between targets (uses the server's chain targets). | *Crimson Hellfire Pillar*: a pillar drops, then a burning ground disc for 3 s. |
| **Solaris** (STAFF) | *Corona Arc*: gold arcs with a sun-flare burst. | *Supernova Starfall*: a mini-star drops, then a white flash and solar ground fire. |

Healer and Scholar Basics become `BOLT`/`ORB` projectiles in their palettes. Melee Basics get a short `SlashArc` trail on the weapon at the `Impact` marker.

For multi-target visuals (chains, pierce lines, cleave hits), the server already broadcasts a `HIT_SPARK` for every secondary target at its position. The VFX reads those positions, collected in a short window after impact, and does not need a second cue.

## Phases

Each phase is its own branch and PR off `main` (`feat(combat): ...`).

### Phase 0: Decide (small, first)
- Settle: markers in `HeroClips` vs config; whether Basic/Special fizzle on a dead target (recommended: yes) or retarget; the Skill `CastSeconds` cooldown change.
- Delete the dead `SpawnArrowProjectile` path only once Phase 3 has moved it.

#### Phase 0 decisions (2026-10-26)
- Markers live in `HeroClips` (a `RELEASE_MARKERS` table per weapon, applied to the weapon clips; hero overrides set their own). The server requires `HeroClips` through `HeroActionTiming`.
- Basic and Special fizzle on a dead or departed target. Skills still resolve their area.
- An Ultimate locks the hero for `max(interval, Skill.CastSeconds)`.

### Phase 1: Server action timeline
- `HeroActionTiming`, `HeroImpactQueue`, `HeroSkillEffects` extraction, `HIT_SKILL` key and Marksman 4-tick rain.
- Old `HERO_ATTACK` cue kept as-is for now (the client keeps animating). Damage now lands at impact.
- Tests: new `hero-action.spec.luau` (timing maths, cancel before release, fizzle, multi-tick, PvP path) registered in `tests/run.ps1`. Extend `combat-skills.spec.luau` for `HeroSkillEffects`.
- GDD §4.4: delivery and timing, the Skill cast lock and 4-tick rain.

#### Phase 1 results (2026-10-26)
- `HeroClips`: `Clip.Markers`, a `RELEASE_MARKERS` table (all 7 weapon types × 3 tiers, bows add `Nock = 0.9`), and `HeroClips.Marker(clip, name, fallback)`.
- `ArchetypeCombatSkills`: optional `Delivery`, `ProjectileSpeed`, `TravelSeconds`, `Ticks`, `TickSeconds` on every tier and `CastSeconds` on Skills. Marksman, Healer and Scholar Basic/Special are `PROJECTILE`; Marksman, Healer and Scholar Skills are `AREA`; Marksman Skill is 4 ticks.
- `Shared/Util/HeroActionTiming.luau`: `For`, `CastSeconds`, `ReleaseFraction`, `TravelSeconds`, `Ticks`.
- `Combat/HeroImpactQueue.luau`: pure queue (`Push`, `Drain(now, canRelease, resolve)`), drained every Heartbeat by `CombatSimulation`.
- `Combat/HeroSkillEffects.luau`: the archetype Special/Skill blocks, moved out of `stepHeroSimulation` with the same numbers. Splash damage is divided by `Ticks`, and one-shot effects fire on tick 1.
- `CombatSimulation`: the attack decision pushes an impact and moves the gauge. `canReleaseHeroImpact` and `resolveHeroImpact` land the primary hit (mob or PvP, unchanged rules). A mob kill only clears the attacker's target if it is still that mob. `HERO_ATTACK` now sends the cast time (ms) instead of the raw interval.
- Fixed: the Ultimate's primary hit now sends `HIT_SKILL`, which `EntityRenderer` shows as the gold skill number. It used to send the profile's `VFXKey`, which the client ignored.
- `tests/hero-action.spec.luau` (timing, markers on every clip, queue release/fizzle/catch-up, rain ticks, pierce, Vanguard barrier) registered in `tests/run.ps1`; all suites pass.
- Not yet checked in a Studio playtest: the feel of the delayed hits, and boss clear times.

### Phase 2: Cue protocol and animation markers
- `HeroCue` buffer in `TowerProtocol` (round-trip spec in `tower-transport.spec.luau`), `HeroAnimator` start offset and markers, BOW `Release`/`Nock` markers and `HunterArrow` hide/show.
- GDD §8: cue layout.

#### Phase 2 results (2026-10-26)
- `TowerProtocol.EncodeHeroCue` / `DecodeHeroCue` (44 bytes, layout above). Decode rejects a wrong tag or size, a bad tier or flags, zero ids, zero cast, release after cast, and non-finite time or aim.
- `CombatSimulation` sends `HERO_CUE` (the encoded buffer) instead of the old overloaded `HERO_ATTACK` arguments. Its timing is the same `HeroActionTiming` result the impact queue uses, and its start time is `Workspace:GetServerTimeNow()`.
- `HeroClips.MarkersBetween(clip, from, to)`, a pure helper that returns the markers crossed in clip order.
- `HeroAnimator`: `PlayAction(state, duration, startOffset?, data?)`. A late start skips the markers it has already passed. `OnMarker` fires each marker once, then `End` on finish or replacement. `Action.Data` carries the decoded cue, ready for Phase 3 VFX.
- `EntityRenderer`: decodes `HERO_CUE`, checks the node's `EntityGeneration`, ignores cues older than their cast, and plays the clip at the late offset. For bows, `Release` hides the `HunterArrow` (`LocalTransparencyModifier`), and `Nock` or `End` shows it again.
- `tests/hero-action.spec.luau` gained marker-order and cue round-trip/rejection checks; all suites pass.

### Phase 3: Marksman projectiles (the headline)
- `CombatVfx/` folder with `VfxPool`, `VfxPrimitives` (Flight, Burst, Sigil, Rain, Beam), `ProjectileVfx` and `SkillVfx`; catalog entries for Jenna, Astrea and the Marksman fallback.
- Arrows for Basic, Special and Skill, with impact landing in sync with the hit numbers.
- Studio check: Jenna and Astrea squads on a floor-1 room and on a boss floor; capture screenshots of each tier.

#### Phase 3 results (2026-10-26)
- `Shared/Config/SkillVfxCatalog.luau`: palettes and tier recipes for `hero_jenna`, `hero_astrea` and the `BOW` fallback, plus `WeaponArchetype` for reading tick timing.
- `Assets/CombatVfx/`:
  - `VfxMath`: pure flight, pierce, fan, rain and wave maths.
  - `VfxPool`: pooled assemblies, a server-time effect scheduler, a 160-effect cap and 180-stud culling. It lives in its own `Workspace.ClientCombatVfx` folder, because `clearView` empties `ClientVisualEntities`.
  - `VfxPrimitives`: Flight, Burst, Disc, Sigil, FlightRing and At.
  - `ProjectileVfx`: `ARROW` and `ASTRAL` bodies, repainted for each hero's palette on every reuse.
  - `SkillVfx`: Basic, Special and Skill as described in GDD §4.4.4.
- `EntityRenderer`: at the `Release` marker it plays the cue's VFX from the bow's `Nock` attachment, aimed at the target's rendered `RootPart` (falling back to the cue's aim). It steps the pool every frame and clears it with the view.
- `CombatFeedback`: removed the unused `SpawnArrowProjectile` code and `ActiveFlights`.
- The plan listed Rain and Beam primitives. Rain is built from Flight in `SkillVfx`, and Beam moves to Phase 5, when chains need it.
- A cue that arrives after its release frame plays the animation from its offset but draws no projectile; the damage number still shows.
- `tests/combat-vfx.spec.luau` registered in `tests/run.ps1`; all suites pass.
- Playtest fixes:
  - The real bug: `playAttackVfx` was declared above `local VisualNodesByNetId` in `EntityRenderer`, so its target lookup read a nil global. Every flight's first update errored, the error aborted the pool step, arrows never showed, and sigils were stranded on the floor. The helper now sits below that declaration, and `luau-analyze` reports no other unknown globals in the renderer or `CombatVfx`.
  - The arrow read as a small blue sphere: the 0.08-stud shaft vanished at camera distance and the tip glow dominated. After two playtest rounds `buildArrow` uses a 0.28 x 4.5-stud light shaft, a 0.6 x 1.0 diamond head, 0.9 x 1.3 fletching, a faint 0.6 glow and a 1.2-stud trail, all from named constants at the top of the builder.
  - Hardening done along the way: pooled assemblies are parked unparented instead of at y = -10,000 (below `FallenPartsDestroyHeight`), `Acquire` drops assemblies whose parts are gone, each effect's update and cleanup runs in `pcall` (with a `CombatVfx:` warning), and the attack VFX call in `EntityRenderer` is guarded.

### Phase 4: Signature skill animations
- `HeroClips.Overrides` `AttackSkill` for all 12 heroes, plus Special overrides where needed, all with markers.
- `tests/studio-hero-model-viewer.luau` gains a "play tier" mode to review clips without combat.

#### Phase 4 results (2026-10-26)
- `HeroClips`:
  - `WeaponPoses`: each weapon's key poses, exposed so overrides can build on them.
  - `OVERRIDE_WEAPON` (exported as `HeroClips.OverrideWeapon`): a hero override now applies only while the hero holds its signature weapon. `HeroClips.Get` enforces this, and the server's `HeroActionTiming` reads clips through `Get`, so an unarmed hero uses the `UNARMED` clips and markers on both sides.
  - A signature `AttackSkill` for all 12 heroes, each with its own `Release` (bows also `Nock`):
    - Jenna: a backward wind-step leap, firing at the top of the jump.
    - Astrea: an arched, deliberate sky shot with a held follow-through.
    - Aaron: shield planted in a braced stance.
    - Ignis: a two-armed roar.
    - Morrigan: sword driven into the ground from one knee.
    - Han: four alternating cuts and a double slash.
    - Velkist: a coiled lunge with blades opening like lotus petals.
    - Archon: crossed blades torn apart.
    - Catio: an axe spin into a two-handed slam.
    - Eolka: staff raised, then driven down in a lunge.
    - Solaris: gather the sky, bring it together, throw it down.
    - Valeria: tome lifted in blessing, then arms opened wide.
  - Special overrides for Velkist (Shadow Rend dash cut) and Catio (Resonance Tremor ground strike).
- `tests/hero-rig.spec.luau`: every hero has a signature weapon and `AttackSkill`, every attack override has a `Release` (bows `Nock` after it), unarmed heroes fall back to `UNARMED`, and the two special overrides resolve. The existing clip checks cover angle limits, joint names and matching start and end poses for all 14 new clips.
- `tests/studio-hero-model-viewer.luau`: new `Play`, `Seconds` and `HeroId` options loop a state on the lineup by writing static poses, in Edit mode or a playtest, and print each clip's length and `Release`.

### Phase 5: Skill VFX for the other 10 heroes
- The remaining primitives (Pillar, Shell, SlashArc, Chain, Aura, GroundRing) and catalog entries per the table above. Can be split into one PR per archetype.

#### Phase 5 results (2026-10-27)
- `SkillVfxCatalog`: every tier names a `Style`, which picks a `SkillVfx` player, and the remaining fields tune it. There are entries for all 12 heroes and fallbacks for all six weapons. `Catalog.Styles` lists the valid styles per tier.
- Styles:

  | Tier | Bow | Sword and shield | Daggers | Axe | Staff | Tome |
  | --- | --- | --- | --- | --- | --- | --- |
  | Basic | SHOT (arrow) | SLASH (crescent) | SLASH | SLASH | BOLT (`ORB`/`BOLT`) | BOLT |
  | Special | VOLLEY | CLEAVE (slash + 110° shockwave cone) | CROSS (two crossing crescents) | TREMOR (ground ring, disc, spikes) | CHAIN (orb, then lightning to each chained hit) | MEND (bolt, then motes on the healed ally) |
  | Skill | STORM | BULWARK (barrier shell for 6 s + taunt shockwave to 25 studs) | TEMPEST (ring of crescents + 12-stud shockwave; Archon adds a collapsing rift) | CRYSTALS (spike cluster + a spike under each hit enemy) | PILLAR (column drops, burst, 3 s burning ground) | SANCTUARY (25-stud sigil + a light column on each squad hero) |

- New primitives in `VfxPrimitives`: `Ring` (an expanding ground band, full or cone, made of 16 segments), `SlashArc` (a 9-segment crescent that sweeps on and then fades), `Shell`, `Pillar`, `Beam` (a zigzag of 4 segments), `Spike` and `Motes`, plus `Yaw`. `ProjectileVfx` gains `BOLT` and `ORB`.
- Melee blows land on their release frame, the same moment `SkillVfx.Play` runs, so `Play` now accepts a cue up to 0.2 s past its impact.
- Hit and heal positions (`CHAIN`, `MEND`, `CRYSTALS`): `EntityRenderer` keeps the last 64 hit and heal positions the server reported (`RecentHits`). The effect reads them 0.2 s after impact, so it lands on the enemies and allies the server actually picked. The renderer also supplies `Self` and `Allies` (the attacker's squad) as foot-level positions, matching the server's entity positions and `Cue.Aim`.
- `tests/combat-vfx.spec.luau`: every hero and weapon has valid styles and projectiles, all 12 heroes are covered, each ultimate's style matches its archetype, and each ultimate's radius matches its kit.
- Not built yet: dedicated Healer heal-ring and Scholar meteor projectiles. `PILLAR` draws the meteor as a column of light.
- Playtest tweak: slashes looked small. Every crescent now goes through `SLASH_SIZE = 1.7` in `SkillVfx`, giving a basic slash about a 3.7-stud radius. `SlashArc`'s band is about twice as wide (0.3 × radius), thicker, and spans 165°.

### Phase 6: Polish and budget
- Culling, caps, mobile check (`studio-part3-mobile-client.luau`), and the multiplayer check with 6 squads in a room (`studio-part3-multiplayer-*`). MicroProfiler label `CombatVfx.Step` under 1 ms at 30 heroes.

#### Phase 6 results (2026-10-27)
- `CombatVfx/VfxQuality.luau` (pure): three levels. Detail multiplies effect counts, and MaxEffects is the live-effect budget:

  | Level | Detail | MaxEffects |
  | --- | --- | --- |
  | High | 1.0 | 160 |
  | Medium | 0.6 | 110 |
  | Low | 0.35 | 70 |

  The player's Settings UI quality is the ceiling. If the smoothed frame time stays above 1/35 s for 3 s, the effective level drops one step. It climbs back after 8 s below 1/50 s, never above the setting. Hitches over 1 s are ignored.
- `VfxPool`:
  - Owns a quality state, fed by `Step(now, dt)`.
  - Uses the effective budget.
  - Exposes `Detail()`, `Pressure()` (live / budget) and `Decor()`, which is false below Detail 0.5 or above 60% pressure.
  - `Stats()` returns live, parked, refused, Step ms (smoothed) and the quality level.
  - `Prewarm(kind, build, count)` builds assemblies ahead of time.
- `VfxPrimitives.Prewarm(pool)` builds the common assemblies ahead of time, so the first big skill does not hitch. `Sigil` takes an optional spoke count.
- `SkillVfx`:
  - Counts (rain arrows, slashes, spikes, motes, crystal hits) scale with detail.
  - Decoration (sigil spokes, volley side arrows and rings, motes) is skipped when `Decor()` is false.
  - Other players' heroes (`Owned = false`) draw at half detail with no decoration, and their basics are skipped below High.
- `EntityRenderer`:
  - Follows the `Settings_Quality` attribute and prewarms the pool.
  - Steps the pool with the frame `dt`.
  - Leaves out camera shake when `Settings_ReduceMotion` is on.
  - Publishes stats every second as attributes on `Workspace.ClientCombatVfx` (`Live`, `Parked`, `RefusedPerSecond`, `StepMs`, `Quality`, `QualitySetting`).
- `SettingsApp` now publishes `Settings_Quality` alongside the other `Settings_*` attributes.
- `tests/studio-vfx-stress.client.luau`: plays fake cues for 30 heroes (all 12 kits) around the camera on a private pool and reports average and peak Step ms, peak live effects, refusals and FPS. Target: under 1 ms average Step at High.
- `tests/combat-vfx.spec.luau` covers `VfxQuality`: parsing, cheaper levels, the timed drop and recovery, the setting ceiling, ignored hitches and count scaling.
- Not done here (needs Studio): the stress numbers, the mobile check and the 6-squad multiplayer check. Those are the author's playtest.
- First stress run (30 heroes, High): about 1.03 ms average, 3.1 ms peak, 59–61 peak live, 0 refused, 60 FPS. A second run meant to be at Low also reported High, which exposed two gaps that are now fixed:
  - **Quality picker:** the Settings UI had no Quality picker (only the Performance and Cinematic presets changed it). It now has a "Combat Effects Quality" Low/Medium/High row on the Graphics tab.
  - **Roblox graphics slider:** the VFX ignored Roblox's own graphics slider. `VfxQuality.FromRobloxLevel` maps `GameSettings.SavedQualityLevel` (1–3 Low, 4–6 Medium, Automatic or 7–10 High), and `EntityRenderer` and the stress script use the lower of that and the Settings choice.
- Step cost: every per-frame position write in `VfxPrimitives` now goes through `VfxPool:Move` / `MoveModel`. These queue CFrames using cached part offsets, and `Step` writes them all with one `Workspace:BulkMoveTo`, then runs cleanups so assemblies are parked after their last move.

## Verification (every phase)

- `pwsh tests/run.ps1`: everything compiles and all spec suites pass.
- Studio playtest via Studio MCP: no console errors, damage numbers appear when the projectile or effect lands, and no orphaned parts are left in `ClientVisualEntities` after 2 minutes of combat (pool count is steady).
- Multiplayer: a second client sees the same arrows, and a client that joins mid-fight shows no stray effects.

## Risks

- **Feel change:** damage now lands up to ~0.9 s after the attack decision for archers. DPS is unchanged, but kills come later and overkill shots can fizzle. Watch the boss-floor clear times in `phase1-combat-tempo.luau`.
- **Squad recall mid-flight:** the cancel rule must use entity generation (`AttackTimeline.Matches`), or a recalled hero's old arrow could hit in a new room.
- **Unreliable cue loss** under bad network means no projectile, but numbers still show. Acceptable. If it turns out to be visible, send Skill cues reliably (rare, 1 per ~15 s per hero).
- **Part churn** is the main client cost. The pool and caps in Phase 3 are not optional.
