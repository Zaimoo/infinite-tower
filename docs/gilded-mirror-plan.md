# The Gilded Mirror: premium mirror-hero banner implementation plan

Status: PRs 1–4 built on `feat/mirror-heroes-core` (2026-11-13). PR 5 (final looks and own kits, through the `hero-creation` skill): Isabelle, Nyx, Caspian, Seraphine and Rook built (2026-11-14). PR 4 built the kits, their clips and VFX, and the glass shatter on KO. Changes from §5: Shatterdance uses the Striker splash (half damage to others), Twin Reflection's search range is `TwinRange` (the VFX test ties `Radius` to the sigil), and Hall of Mirrors first drew with the `CRYSTALS` style (it now has its own, `HALL_OF_MIRRORS`). Isabelle's Ricochet and Twin Reflection have their own VFX styles (`RICOCHET`, `TWIN`) and clips; the server sends Twin Reflection's second target as a cosmetic `TWIN_MARK` (GDD §4.4). PR 2 put the banner in the Store (`ShopPanel`) instead of a fourth summon-altar tab, next to the other Robux packs, with the odds listed inline; `HeroOddsModal` is unchanged. GDD sections to update with the code: §2.5 (Rift Attunement exception list), §4 (banners, Pit promotion), §8 if any new remote is added.

---

## 1. Summary

**The Gilded Mirror** is a Robux-only summon banner with five heroes. **Mirror heroes** have no base stats of their own: their base stats are a percentage of the Master's best normal hero. Rarer heroes mirror a higher percentage, and each star adds +2%.

| Hero | Archetype / weapon | Rarity | Rate | Mirror 1★ → 7★ |
| --- | --- | --- | --- | --- |
| Isabelle | Marksman / `BOW` | Mythical (7) | 50% | 110% → 122% |
| Nyx | Striker / `DAGGERS` | Transcendent (8) | 28% | 120% → 132% |
| Caspian | Vanguard / `SWORD_SHIELD` | Ascendant (9) | 14% | 130% → 142% |
| Seraphine | Scholar / `STAFF` | Ethereal (10) | 6% | 140% → 152% |
| Rook ★ featured | Berserker / `AXE` | Immortal (11) | 2% | 150% → 162% |

- **Price:** 55 R$ for one pull, 499 R$ for ten (about 9% off). Every ten-pull includes at least one Caspian or better.
- **Spark:** after 80 pulls on this banner, the Master picks any one of the five.
- **No filler:** every pull is one of the five heroes.

## 2. Rules (the spec)

### 2.1 Mirror stats

```
source        = the Master's best NORMAL hero by base power (no weapon, Training Grounds included)
mirror%       = MirrorBase[rarity] + 0.02 × (stars − 1)
targetPower   = source base power × mirror%
HP, ATK       = targetPower split by the MIRROR hero's own archetype shape (below)
final         = HP/ATK × own weapon bonus (1 + WeaponPower/40), then Rift Attunement
```

- **Archetype shape.** `HeroPower = round(10 × DPS + HP)` and `DPS = ATK / interval`. Using the mirror hero's seed HP `h`, ATK `a` and attack interval `i`: `k = targetPower / (10a/i + h)`, then `HP = k·h` and `ATK = k·a`. Rook copying a Healer still gets Berserker-shaped stats.
- **Mirror heroes never copy each other.** The source is always a hero whose seed has no `Mirror` field.
- **No levels.** Mirror heroes don't take XP. `Level` stays at 1 and the UI shows "Mirrored".
- **Labor** copies the source hero's effective labor at 100% (no bonus).
- **When it updates.** The source is recomputed on every `SyncProfile` and Pit delta (summons, promotions, synthesis, combat level-ups). Weapons don't affect the source, so equipping doesn't need a refresh. In the tower, mirror heroes refresh like any other hero's stats when the Pit delta arrives.
- **Caps.** Rift Attunement applies unchanged in the tower. Bounty duels use the lower of the two Masters' caps.

### 2.2 The last normal hero is protected

A Master must always own at least one normal hero. Heroes leave the roster only as Pit donors (`SYNTHESIS` / `CONVERSION`, `PitService.luau:409`). So:

- `PitService:DonorStatus` marks a hero **Protected** with the reason "Your mirror heroes copy your last normal hero." when it's the only normal hero left.
- `PitService:Build` also counts the normal heroes left after `staged.Remove`. Several donors in one request must not be able to remove the last one together. If none would remain, it rejects with the same reason.
- Applies to every Master, not only those who own a mirror hero, so the rule is simple and can't be bypassed by pulling one later.

### 2.3 Promotion and donors

- **Promotion:** normal Gold and Promotion Stone costs (`PitBalanceConfig.Promotion`), **no level gate**, and +2% mirror per star. On purpose, this is a worse deal than promoting a normal hero (×1.5, and every mirror hero copies that ×1.5), so players invest in their free roster first.
- **Synthesis:** mirror heroes can't be synthesis recipients (they have no XP). `RecipientStatus` returns "Mirror heroes don't level."
- **As donors:** duplicates can be consumed like any hero. `PitMath.EffectiveStars` already clamps to 7, so a mirror donor is worth the same as a Mythical donor. Keep that.

### 2.4 Purchases

- Uses the existing Robux summon pack path: `ShopConfig` offers with `Grant = { Kind = "Summons", Banner = "GILDED_MIRROR" }`, granted by `ShopService` `ProcessReceipt` (already idempotent with the `ShopReceipts_V1` claim).
- **Paid random items:** the banner and its offers are **hidden** for players where `ArePaidRandomItemsRestricted` is true. If a receipt still arrives (bought before a policy change), `ShopConfig.SafeGrant` converts it to Gems. `GemsPerSummon("GILDED_MIRROR")` = 150, matching the Gem store rate (Vault of Gems: 3,000 Gems for 1,000 R$).
- **Odds** are shown on the banner page and in `HeroOddsModal` before purchase.
- **ProductIds** are created by hand in the Creator Hub and stay 0 until the user turns them on (see the `profiles-not-persisted` note: saving exists, ProductIds are still 0).

---

## 3. Data and code changes

### 3.1 Config

| File | Change |
| --- | --- |
| `HeroCatalog.luau` | Five seeds with `BannerOrigin = "PREMIUM"`, `Rarity` 7–11 and `Mirror = true`. Seed HP/ATK are only the **shape** (ratio and interval), never used as stats. New `HeroCatalog.MirrorBanner` (`BannerId = "banner_gilded_mirror"`, `Rates` [7]=0.50 [8]=0.28 [9]=0.14 [10]=0.06 [11]=0.02, `HeroesByStar`, `TenPullMinTier = 9`, `SparkPulls = 80`, `RobuxOnly = true`). **Extend `RarityNames`** to 11 (Transcendent, Ascendant, Ethereal, Immortal). Today `RarityName` clamps to 7, so rarity 8–11 would display as "Mythical". |
| `StatBalance.luau` | `B.MirrorBase = { [7]=1.10, [8]=1.20, [9]=1.30, [10]=1.40, [11]=1.50 }`, `B.MirrorPerStar = 0.02`. |
| `ShopConfig.luau` | `MirrorPack` offers: `pack_mirror_1` (55 R$), `pack_mirror_10` (499 R$). `GemsPerSummon` handles `GILDED_MIRROR`. |
| `ArchetypeCombatSkills.luau` | Five hero kits (§5). |
| `SkillVfxCatalog.luau` | Tier recipes and palettes for the five kits (§6). |
| `HeroCostumes.luau` | Five costumes (§4). |
| `HeroClips.luau` | Five clip sets (§5). |

### 3.2 Shared logic

- `StatFormulas`: `IsMirror(hero)`, `GetMirrorSource(profile)` (best normal hero by `GetHeroPower(hero, nil, training)`), `GetMirrorPercent(hero)`, `GetMirrorStats(hero, source)`.
- `GetCombatSnapshot` gets a mirror branch (built): when the hero is a mirror hero, it reads `hero.MirrorSource` (`{ UUID, Name, Stars, Level, Power, Labor }`), which the server writes, and applies `GetMirrorPercent` at snapshot time, so promotion previews need no refresh. Its weapon, Overdrive and Training stay as they are. This keeps `GetHeroPower(hero, artifact, mult)` and all its callers unchanged, since they don't need the profile. Without a source it falls back to a 1★ Lv 1 Common.
- `GetEffectiveLabor`: a mirror hero returns `hero.MirrorSource.Labor`, ×1.25 at its own preferred facility.
- `PitMath.Promote`: mirror heroes skip the BaseHP/BaseATK rewrite and the level reset. Stars +1 only.
- `PitMath.Snapshot` / preview: `Before`/`After` include `MirrorPercent` and the recomputed HP/ATK.

### 3.3 Server

- `DataManager` (built): `StatFormulas.RefreshMirrorSources(profile)` writes `MirrorSource` onto every mirror hero. Called from `SyncProfile` and `SyncPitDelta`; when it changes anything, `SyncPitDelta` also sends every mirror hero. It's cheap: one pass over at most 50 heroes. No save migration is needed: the field is derived and rewritten on load.
- `DataManager.RollSummons`: supports `RobuxOnly` banners (no Gem charge; only called from `ShopService.grant` with a receipt). Tracks `profile.MirrorSpark.Pulls`. At 80 it sets `profile.MirrorSpark.Ready = true` and resets the counter.
- **New remote** `RequestMirrorSpark(heroId)`: validates `Ready`, that `heroId` is one of the five, and the hero cap, then grants and clears `Ready`. Rate-limited like the other summon remotes.
- `PitService`: §2.2 guard; mirror recipients skip the level-cap check in `PROMOTION`; synthesis rejects mirror recipients.
- **Migration** in `DataManager.SyncProfile` / `ProfileMigrations`: add `MirrorSpark = { Pulls = 0, Ready = false }` when it's missing. A profile with no mirror heroes needs nothing else.
- `TowerEncounterRuntime` / `CombatSimulation`: no change beyond the snapshot. Confirm the floor-entry snapshot reads `GetCombatSnapshot`.

### 3.4 Client UI

| Where | Change |
| --- | --- |
| Summon facility (`FacilityController`) | A fourth banner tab, "The Gilded Mirror", priced in R$ through `MarketplaceService:PromptProductPurchase`. Spark progress "62 / 80" and a **Choose your hero** button when `Ready`. Hidden when restricted. |
| `HeroOddsModal` | The five rates and the 10-pull and Spark rules. |
| `SummonReveal` / `SummonRevealFx` | Premium reveal: a gilded mirror frame appears, cracks, and the hero steps through. The rarity colour comes from the 8–11 artifact tier colours. |
| `PromotionController` | Mirror recipients: "Mirror" badge in place of "LV x/y", Mirror row in place of Level (152% → 154%), source line "Copying Astrea ★★★ Lv.20", and a hint "Promoting Astrea raises this hero by ×1.5". The picker never shows "NEED LV." for them. |
| `HeroCard` / `HeroIndex` | Mirror % badge, "151% of Astrea × weapon", Level shows "Mirrored", Labor "= Astrea", and an attunement note when capped. |
| Pit donor picker | The protected last normal hero shows its reason. |
| Rarity colours | Hero UI uses `ArtifactCatalog` tier colours for 8–11 (Transcendent teal, Ascendant pink-violet, Ethereal indigo, Immortal rose). |

---

## 4. Looks

Shared theme: **gilt and glass.** Every costume uses a gold trim colour (`212,175,90`), at least one `Glass` piece (mirror shards, a lens or a visor) and one small `Neon` accent in the hero's rarity colour. Each stays inside the 60-part budget (`HeroCostumes.PART_BUDGET`). Rook fitted cleanly inside 56 parts without needing an exception override. Faces and hair go through the `hero-remodel` skill and `docs/hero-art-pipeline.md`.

### 4.1 Isabelle (Mythical Marksman)

- **Body:** Slim. A hunter in a fitted ivory and gold riding coat.
- **Palette:** skin `236,200,170` · hair platinum blonde `232,220,190` · coat ivory `236,230,214` · coat lining deep teal `30,80,90` · trousers charcoal `44,44,50` · boots dark brown `70,48,34` · gold trim · accent Mythical red `231,76,60` (Neon).
- **Pieces:** a long high-collared coat with a split tail (Loose), gold buttons down the front, a leather quiver strap across the chest, fingerless gloves, a round **glass monocle** over the right eye, and knee-high boots with gold buckles.
- **Hair:** a long side braid over the left shoulder, with straight bangs.
- **Silhouette:** tall and narrow. The coat tail and the braid give her movement.

### 4.2 Nyx (Transcendent Striker)

- **Body:** Slim. An assassin in a black bodysuit with gold filigree.
- **Palette:** skin `214,170,140` · hair jet black with teal tips `20,20,26` / `26,188,156` · bodysuit black `22,22,28` · wraps graphite `58,58,66` · gold trim · accent Transcendent teal `26,188,156` (Neon).
- **Pieces:** a half-cape on the left shoulder (Loose), a gold filigree collar, wrapped forearms, a short tabard, thigh straps, soft boots, and a **mirror-glass half mask** over the lower face.
- **Hair:** a short asymmetric bob, longer on the left.
- **Silhouette:** small and low, with the cape breaking the outline on one side.

### 4.3 Caspian (Ascendant Vanguard)

- **Body:** Heavy. An armoured knight in white-gold plate.
- **Palette:** skin `200,150,115` · hair auburn `140,70,40` · plate pearl white `228,226,220` · plate shadow `170,168,160` · undercloth royal blue `40,60,130` · gold trim · accent Ascendant pink-violet `224,86,253` (Neon).
- **Pieces:** big layered pauldrons, a breastplate with a **round glass mirror set in the centre**, faulds, greaves, a blue tabard (Loose), and a short blue cape.
- **Hair:** short and swept back, with a short beard.
- **Silhouette:** wide at the shoulders. The weapon system provides his sword and shield; the costume adds no gear.

### 4.4 Seraphine (Ethereal Scholar)

- **Body:** Slim. A court mage in layered indigo robes.
- **Palette:** skin `240,214,196` · hair silver-white `220,222,235` · robe indigo `50,52,120` · inner robe pale lavender `200,196,235` · gold trim · accent Ethereal indigo `104,109,224` (Neon) · glass shards light blue `190,215,255`.
- **Pieces:** a tall standing collar, a long open robe (Loose) over an inner gown, bell sleeves with gold cuffs, a gold circlet, and **three small glass shards** that orbit behind her head as a halo (attached to the head, animated by the idle).
- **Hair:** very long and straight to the waist, with a half-up knot.
- **Silhouette:** tall, a triangle that widens to the floor.

### 4.5 Rook (Immortal Berserker, featured, built)

- **Body:** Heavy. A battle-scarred brute in sleeveless leather armor, fur mantle, and gilded war harness.
- **Palette:** skin `176,120,88` · hair rust-copper `136,48,28` (textured `rook_hair_texture.png`) · tunic/boots `54,40,34` / `48,36,32` · harness leather `76,48,34` · fur mantle grey-brown `112,96,84` · trousers black `30,28,30` · gold trim · accent hot rose `255,76,148` (Neon).
- **Pieces (56 parts total):** a fur mantle & back cape over both shoulders (`Loose`), a cross-chest leather harness with five **gold mirror-plate medallions** (two collarbone fur clasps, one chest center medallion, two lower harness studs), embossed gold forearm bracers, a belt with glowing rose side runes and a rose-eyed gold skull buckle, fur hip tassets with gilt trim, and heavy studded boots.
- **Hair & Face:** wild swept-back rust-copper mane (`tools/make_rook_hair_ugc.py`) + braided goatee; custom scarred face decal (`assets/faces/make_rook_face.py`).

---

## 5. Kits and animations

Clips live in `HeroClips.luau` as data and play through `HeroAnimator`; every row below is a
state a player sees. A hero's own clips apply only while it holds its signature weapon
(`OVERRIDE_WEAPON`); without it the hero uses the shared unarmed set. Damage lands on each attack
clip's `Release` marker (`HeroActionTiming`), so the strike key and the marker stay together.

Every mirror hero has, as its own: a **stance** (`Idle`), a **walk** (`Move`, usually the stance's
upper body over walking legs), and its **three attacks**, plus its weapon **grip** when it differs
from the standard. Shared by every hero and not overridden: the **hit flinch** (`Hit`), the
**knocked-out** slump (`Coma`, with the mirror glass shatter on top, §6.1) and the off-duty states
(`Carry` for loot, `Labor`, `Sleep`, the Market and Training Grounds work loops). Rows marked
*built* are in the game (PR #281); the rest are the plan for that hero's own pass.

**Numbers are multiples of the hero's ATK** (`DamageMultiplier` in `ArchetypeCombatSkills`). The kits are tuned to match the existing archetype kits, so mirror heroes get their power from the mirror percentage, not from stronger skills. Rourke, the featured hero, gets one small extra (the attack-speed buff).

| Archetype | Basic | Special (every 3rd attack) | Skill (100 gauge) |
| --- | --- | --- | --- |
| Vanguard | 1.0 | 1.4 + cone stagger | taunt 25 studs 4 s + 40% Max HP barrier 6 s |
| Striker | 1.0 | 1.6 + 25% crit | 3.2 in 12 studs |
| Marksman | 1.0 | 1.5 + pierce line | 2.8 in 16 studs + 20% defense shred 5 s |
| Berserker | 1.0 | 1.5 + stagger | 2.6 in 18 studs |
| Scholar | 1.0 | 1.4 + chain to 2 | 3.5 in 20 studs |

### 5.1 Isabelle (`BOW`), built

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Grip | — | Standard bow grip (left hand). | — |
| Idle | — | — | From her art: upright, mid-stride, the bow held low in her left hand, the draw hand loose at her side, head turned a little to her left. A slow breath. |
| Walk | — | — | Her stance's upper body over walking legs (`walk(poised)`): the bow low in her left hand, the draw hand loose, head turned a little left. |
| Basic | Glint Shot | 1.0× ATK arrow. | A quick snap shot with the bow canted (`LeftWrist` Y 35°) and her head tilted toward the monocle. |
| Special | Ricochet | 1.5× to the target, then bounces once to the nearest other enemy within 14 studs for 0.75×. | She turns away, pivots back low (crouch) and shoots with the bow held flat (80° cant). |
| Skill | Twin Reflection | The arrow splits: **2.5×** to the target and 2.5× to the toughest other enemy within 30 studs (both halves hit a lone target). A focused boss-killer, where the Marksman default is a 2.8× area. Cast 1.5 s. | A step back into a long rising draw held while the arrow glows, then a release with a small hop and the draw hand sweeping wide as it splits. |
| Hit / KO | — | — | Shared flinch; shared slump with the glass shatter. |

### 5.2 Nyx (`DAGGERS`), built

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Grip | — | Her own grip (`HeroSockets.HERO_GRIPS`): the right dagger held forward, the left reversed along the forearm. | — |
| Idle | — | — | From the user's pose reference: a wide guard, right foot forward, body turned a little left, the forward blade across her chest angled down and out, the reversed blade low by her left hip. |
| Walk | — | — | The same guard over walking legs (`walk(guardArms)`). |
| Basic | Gilt Cut | Two slashes of 0.5× each (1.0× total). | The forward blade raised high, an overhead diagonal cut, then a backhand sweep of the reversed blade: one cut per hit. |
| Special | Mirror Step | Blinks behind the target and strikes for 1.6× with +25% crit chance. | She gathers low; the renderer blinks her behind the target (a glass clone stays in her place) where she thrusts with the reversed blade held as a guard; she blinks back as the clone shatters. |
| Skill | Shatterdance | Five mirror clones each cut every enemy within 12 studs (**3.25×** total over 5 cuts, 0.18 s apart, half to the others). Cast 1.4 s. | No dance: she crosses the forward blade upright before her face with the reversed one and holds it while the clones cut, then slashes both out as the last one shatters. |
| Passive | Gilded Edge | Basic attacks charge 15% more skill gauge (5 → 5.75) while another mirror hero is within 8 studs. | — |
| Hit / KO | — | — | Shared flinch; shared slump with the glass shatter. |

### 5.3 Caspian (`SWORD_SHIELD`), built

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Grip | — | Standard sword and shield. | — |
| Idle | — | — | From his art: standing tall, feet apart, the sword low in his right hand with the blade angled down across his front, the shield's face forward at his left side. A slow, heavy breath. |
| Walk | — | — | The same arms over walking legs (`walk(arms)`). |
| Basic | Gilt Edge | 1.0× sword strike. | A diagonal slash: he turns right with the sword cocked high over his right shoulder, turns into the strike sweeping it down across his body, and follows through low on his left. |
| Special | Polished Bash | 1.4× shield bash with the Vanguard cone stagger (10 studs). | He turns away pulling the shield back, then steps in and drives it forward; the shield flashes like a mirror. |
| Skill | Looking-Glass Bulwark | Taunts enemies within 25 studs for 4 s and raises a 40% Max HP barrier for 6 s (the Vanguard default). For those 6 s, **20% of the ranged damage Caspian takes is reflected** back to the attacker. | He plants the shield in front of him and raises the sword overhead as the glass wall rises. |
| Hit / KO | — | — | Shared flinch; shared slump with the glass shatter. |

### 5.4 Seraphine (`STAFF`), built

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Grip | — | Standard staff grip (right hand). | — |
| Idle | — | — | From her art: she floats about a stud off the floor (every clip is lifted, legs hanging loose) and bobs slowly up and down; the staff upright in her right hand, the free hand raised palm up before her chest (where the art's grimoire floats), head tilted down a little. Her three halo shards hang above her head (costume). |
| Walk | — | — | No steps: she flies, from the user's flying-wizard reference. The whole body leans forward, the legs trail behind bent at the knee, the staff is carried tipped ahead in her right hand and the left arm is swept back, still bobbing. |
| Basic | Shard Bolt | 1.0× glass-shard projectile. | A one-handed point with the staff as a shard leaves her halo (`Origin = "HALO"`). |
| Special | Refraction | A glass prism hits the target for **1.5×**, then splits into three shards that hit the three nearest other enemies within 14 studs for **0.6×** each. | She draws the staff back and turns into it while the three halo shards fly to its tip and join into a prism (`Charge` 0.2), then thrusts it forward to launch it (`Release` 0.62, 1.2 s clip). |
| Skill | Hall of Mirrors | Four mirror crystals rise around the target and fire for 4 s: **3.5×** in total over 8 pulses to the target, and 60% of that to every other enemy within 16 studs. Cast 1.4 s. | Staff held two-handed overhead; she turns a slow half circle while the crystals fire. |
| Hit / KO | — | — | Shared flinch; shared slump with the glass shatter. |

### 5.5 Rook (`AXE`), built

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Grip | — | Two-handed at all times (`HeroSockets.HERO_GRIPS.hero_rourke`): the right hand choked up under the axe head (`Shift = -0.32`, blade canted forward-down by `Offset`), the left hand on the haft below it (`OffhandGrip`, solved each frame by `HeroAnimator.SolveOffhand`). No one-handed carry. | — |
| Idle | — | — | From his reference art: a wide, low two-handed guard. Feet planted far apart, knees bent deep, leaning a little forward with his chin down; the right hand low in front of his right thigh with the blade hanging down, the haft rising diagonally across his body to the left hand at his left hip. A heavy breath every 2.8 s. (Built; measured in Studio.) |
| Walk | — | — | A heavy, rolling stride (0.95 s) that keeps the two-handed guard. Each step: heel strike with the toes up while the back foot pushes off its toes, the weight dropping onto the front knee, passing with the back knee lifted high, then the push into the next step. Above the waist the torso twists against the legs, rolls toward the planted foot and dips on each landing, the hips shift over the planted foot, the axe sways with the twist, and his head stays level on the target. (Built.) |
| Basic | Gilt Cleave | 1.0× to the target. His basics alternate: a forehand cleave, then a backhand return (cosmetic; the hit is the same). | **Built.** *Forehand* (0.9 s): from the guard he hauls the axe back over his right shoulder with the torso wound 70° away and his weight on the right leg, then plants a long step with the left foot and whips his whole body through a flat sweep (`Release` 0.6); the momentum turns him a further quarter turn before he settles. *Backhand* (0.9 s, `HeroClips.Alternates`, same `Release`): he swings the axe across to his left and loads low there, then drags it back in a rising cut as he steps through with the right foot, finishing high over his right shoulder. |
| Special | Last Stand | 1.5× overhead chop with the Berserker stagger (8 studs), rising linearly to **2.5×** as his HP falls from full to 10%. The third hit of his combo. | **Built.** A leaping chop (1.3 s). A deep crouch with the axe dragged behind him (`Charge` 0.2), a spring about 4.5 studs up and 1.6 forward with the axe swung up behind his head as he roars at the top, then down into the ground as he lands on bent knees (`Release` 0.6), and a backward heave to wrench it free. Root motion only. |
| Skill | Gilded Frenzy | A leaping slam for **1.2×** to the target (the first tick), then a whirlwind of **4 spins** for **0.35×** each (one tick each, 0.3 s apart): **2.6×** in total, the Berserker budget. Others take the Berserker half: within 18 studs for the slam, within 12 for the spins (`SpinRadius`). Then **+25% attack speed for 4 s**, from the last spin. Cast 2.4 s. | **Built.** A crouch (`Charge` 0.1), a leap about 6 studs straight up with the axe overhead, and a two-handed slam (`Release` 0.36, the first tick). Then four full 360° spins (a steadily turning root, one turn per tick) with the axe held out at arm's length, edging forward; the axe flung wide on the last, then an overhead roar with the axe raised as the frenzy takes hold. |
| Hit / KO | — | — | Shared flinch; shared slump with the glass shatter. |

**Rook's attacks (built).** Big, whole-body moves: every attack uses the legs, the waist and
the root, not only the arms. Forehand, backhand, leaping chop runs as one three-hit combo, since
the Special is every 3rd attack. Every attack starts and ends in the two-handed guard.

- *VFX* (§6.2). Gilt Cleave: a rose crescent with a gilt one and a white edge inside along
  each swing's path (flat for the forehand, rising for the backhand, from the rig's
  `BasicSwing` attribute), a wake of light along the swing, a glint and gilt sparks. Last Stand
  (`chargeLeap` then `LAST_STAND`): sparks on the axe through the crouch, a dust burst and ring
  at take-off, a rose streak up to the top of the leap and a gilt glint for the roar, a streak
  down onto the target, then a vertical blade of light, a tall crescent, a crack of shards along
  his heading, two shockwaves over 8 studs and a layered flash. Gilded Frenzy (`chargeLeap` then
  `GILDED_FRENZY`): the take-off dust and a streak under him in the air, then the slam (a beam
  from above, shockwaves across 18 studs, lightning arcs, shards under every enemy hit), a ring
  of three crescents round him and a ground ring over 12 studs on each spin with a flash on
  each enemy that spin hit, then a roar burst and a wave rolling out; the 4 s aura on his axe
  is `MirrorHeroFx`.
- *How.* Alternate clips (`HeroClips.Alternates`, played in turn by `HeroAnimator.PlayAction`,
  tested to share the main clip's `Release`). The Skill's ticks are weighted by
  `HeroSkillEffects.TickWeight` (`SlamShare`), with the slam's splash over `Radius` and the
  spins' over `SpinRadius`. Leaps and spins are root motion only; the server position never
  moves.
- *Not built.* The bigger roar below 35% HP (the client has no HP in the attack's VFX args).

**New mechanics, each needing a combat-sim change and a spec test:**

- Ricochet and Refraction (extra targets after impact; one shared helper)
- Targeting the two highest-HP enemies
- Reflecting ranged damage Caspian takes (only `PROJECTILE` deliveries count as ranged)
- Missing-HP damage scaling
- The attack-speed buff
- Nyx's distance check for her passive

Caspian's reflection has the highest risk, since it needs a hook where ranged damage is applied. Limiting it to damage Caspian himself takes keeps that hook in one place.

---

## 6. VFX

Built from `CombatVfx` (`SkillVfx` styles, `ProjectileVfx`, `VfxPool`, `VfxPrimitives`), with recipes in `SkillVfxCatalog` and colours from each hero's palette. Everything goes through `VfxPool` so 30 heroes on screen stay within the performance budget (`docs/performance-plan.md`).

### 6.1 Shared mirror effects

- **Reflection thread:** when the squad is deployed, a thin gold beam briefly links each mirror hero to the source hero (0.6 s), so the player sees who is being copied.
- **Glint:** every 6–10 s at random, a light streak sweeps across the hero's glass pieces (a moving thin Neon part, client only, pooled).
- **Glass break on KO:** shards burst outward and fade when a mirror hero falls.
- **Summon reveal:** a gold mirror frame appears, its glass cracks in three steps, shatters, and the hero steps through. The rarity colour tints the cracks.

### 6.2 Per hero

| Hero | Basic | Special | Skill |
| --- | --- | --- | --- |
| Isabelle (built) | crimson arrows with long laser-like trails (`SHOT`) | the arrow glints off the target and a second arrow bounces to the enemy the hit carried on to (`RICOCHET`) | a charged draw at the nock, then the arrow splits through a gilt mirror pane into two halves toward the server-picked targets (`TWIN`, `TWIN_MARK`) |
| Nyx (built) | an X of teal and gilt crescents, one per hit (`GILT_CUT`) | a glass clone left in her place, streaks out and back, a lance-bright stab from behind (`MIRROR_STEP`, renderer blink) | five glass clones of her before mirror panes, each lunging in, slashing and shattering in turn, then a shockwave (`SHATTERDANCE`, `MirrorClones`) |
| Caspian (built) | a diagonal cut line, wake and crescent through the target along his swing (`DIAGONAL_SLASH`) | a mirror flash on the shield and a shockwave over the stagger cone (`POLISHED_BASH`) | a wall of mirror panes, a taunt shockwave with tethers to every enemy in range, then a glass barrier for 6 s; each reflected hit flies back at the shooter (`LOOKING_GLASS`, `REFLECT`) |
| Seraphine (built) | a glass shard leaves her halo and flies to the target (`BOLT`, `SHARD` projectile, `HALO` origin) | the halo shards fly to the staff tip and join into a prism (charger); the prism (`PRISM`) breaks on the target in a triangle of glass rings and three shards fly on to the other enemies hit (`REFRACTION`) | a floor sigil, four mirror crystals with panes rising round the target, beams from every crystal into the target and at every enemy inside on each of the 8 pulses, then the crystals shatter in a shockwave (`HALL_OF_MIRRORS`) |
| Rook (built) | rose, gilt and white crescents along each swing's own path (flat forehand, rising backhand), a wake of light and gilt sparks (`GILT_CLEAVE`) | a dust burst at take-off, a streak up the leap and down onto the target, then a blade of light, a crack of shards along his heading and two shockwaves (`chargeLeap`, `LAST_STAND`) | take-off dust and a streak under the leap; the slam's shockwaves, lightning and shards under every enemy hit; a ring of crescents and a ground ring per spin with flashes on enemies hit; a roar burst (`chargeLeap`, `GILDED_FRENZY`), plus the 4 s rose aura on his axe (`MirrorHeroFx`) |

---

## 7. Delivery

Split into PRs so each can be reviewed and playtested on its own, branching from `main`:

1. **`feat/mirror-heroes-core` (built):** config, `MirrorBanner` data, `StatFormulas` mirror math, `RefreshMirrorSources`, the last-normal-hero guard, Pit promotion rules, `RarityNames` to 11, specs. Heroes use first-pass costumes and clips (signature idle and Skill) and the archetype kits. `MirrorSpark` and its migration move to PR 2.
2. **`feat/mirror-banner`:** `MirrorBanner`, Robux offers, the `RobuxOnly` roll path, Spark counter and remote, banner tab, odds modal, policy hiding.
3. **`feat/mirror-ui`:** promotion tab, hero card and index, reflection thread and glint.
4. **`feat/mirror-kits`:** the five kits, new combat mechanics, clips and per-hero VFX.
5. **`feat/mirror-looks`:** the five costumes, plus faces and hair through `hero-remodel` once reference art exists, and the summon reveal.

Each PR updates the matching GDD sections.

### 7.1 Tests (`pwsh tests/run.ps1 -LuauDirectory D:/luau`)

- `mirror.spec.luau`: mirror percentage per rarity and star; archetype shape keeps `10·DPS + HP = targetPower`; the source skips mirror heroes; the weapon multiplies; labor copies at 100%; Rift Attunement caps.
- Pit spec: the last normal hero is protected as a single donor and in a multi-donor request; mirror promotion has no level gate and gives +2%; mirror heroes are rejected as synthesis recipients.
- Banner spec: rates sum to 1; ten-pull floor; Spark at 80; `SafeGrant` converts to 150 Gems per pull.
- `HeroCostumes.Lint` passes for all five (part budget, one bone per piece).

### 7.2 Playtest checklist (Studio)

1. Start with the starter pair. Grant each mirror hero through the admin path, then check their power on the hero card is 110–150% of the best starter's base power × their weapon.
2. Promote the best normal hero. Every mirror hero's HP and ATK should go up ×1.5.
3. Promote Isabelle. The tab shows no level requirement and a +2% Mirror row.
4. In the Pit, try to use your last normal hero as a donor, alone and together with others. Both should be refused.
5. Enter floor 1. Check the reflection thread appears, power is capped by Rift Attunement, and stats don't change mid-fight when you level a hero.
6. Cast each Skill. Check the timing and VFX, and that Caspian reflects ranged damage only, and only damage he takes himself.
7. With a test ProductId, buy one pull and ten pulls. Check the receipt grants once, the Spark counter goes up, and at 80 the choice opens.
8. Start a duel between a Master with a mirror hero and one without. Both should use the lower cap.

## 8. Open items

- Real ProductIds for the two offers (Creator Hub).
