# The Gilded Mirror: premium mirror-hero banner implementation plan

Status: PRs 1–4 built on `feat/mirror-heroes-core` (2026-11-13); PR 5 (final looks: faces and hair through `hero-remodel`) not started. PR 4 built the kits, their clips and VFX, and the glass shatter on KO. Changes from §5: Shatterdance uses the Striker splash (half damage to others), Twin Reflection's search range is `TwinRange` (the VFX test ties `Radius` to the sigil), and Hall of Mirrors draws with the `CRYSTALS` style. PR 2 put the banner in the Store (`ShopPanel`) instead of a fourth summon-altar tab, next to the other Robux packs, with the odds listed inline; `HeroOddsModal` is unchanged. GDD sections to update with the code: §2.5 (Rift Attunement exception list), §4 (banners, Pit promotion), §8 if any new remote is added.

---

## 1. Summary

**The Gilded Mirror** is a Robux-only summon banner with five heroes. **Mirror heroes** have no base stats of their own: their base stats are a percentage of the Master's best normal hero. Rarer heroes mirror a higher percentage, and each star adds +2%.

| Hero | Archetype / weapon | Rarity | Rate | Mirror 1★ → 7★ |
| --- | --- | --- | --- | --- |
| Isabelle | Marksman / `BOW` | Mythical (7) | 50% | 110% → 122% |
| Nyx | Striker / `DAGGERS` | Transcendent (8) | 28% | 120% → 132% |
| Caspian | Vanguard / `SWORD_SHIELD` | Ascendant (9) | 14% | 130% → 142% |
| Seraphine | Scholar / `STAFF` | Ethereal (10) | 6% | 140% → 152% |
| Rourke ★ featured | Berserker / `AXE` | Immortal (11) | 2% | 150% → 162% |

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

- **Archetype shape.** `HeroPower = round(10 × DPS + HP)` and `DPS = ATK / interval`. Using the mirror hero's seed HP `h`, ATK `a` and attack interval `i`: `k = targetPower / (10a/i + h)`, then `HP = k·h` and `ATK = k·a`. Rourke copying a Healer still gets Berserker-shaped stats.
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

Shared theme: **gilt and glass.** Every costume uses a gold trim colour (`212,175,90`), at least one `Glass` piece (mirror shards, a lens or a visor) and one small `Neon` accent in the hero's rarity colour. Each stays inside the 60-part budget (`HeroCostumes.PART_BUDGET`). Rourke, the featured hero, may ask for an override up to 80, the way Astrea did. Faces and hair go through the `hero-remodel` skill and `docs/hero-art-pipeline.md` once the user provides reference art. Until then, each uses block hair and the default face.

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

### 4.5 Rourke (Immortal Berserker, featured)

- **Body:** Heavy. A battle-scarred brute in gilded war harness.
- **Palette:** skin `176,120,88` · hair rust red `160,60,40` · harness dark leather `60,40,30` · fur mantle grey-brown `110,96,84` · trousers black `30,28,30` · gold trim · accent Immortal rose `255,121,121` (Neon).
- **Pieces:** a fur mantle over both shoulders (Loose), a cross-chest leather harness with **gold mirror-plate medallions**, a bare arm with gold armbands, a wide belt with a skull-shaped gold buckle, a loincloth tabard, and heavy boots.
- **Hair:** a wild mane with a short braided beard.
- **Silhouette:** the widest of the five. The mantle makes his top half huge.

---

## 5. Kits and animations

Clips live in `HeroClips.luau` as data (`Idle`, `Move`, `AttackBasic`, `AttackSpecial`, `AttackSkill`) and play through `HeroAnimator`. Each hero gets its own signature idle, like Jenna, Rhyman and Vane. Timing follows `AttackTimeline` so damage lands on the impact frame.

**Numbers are multiples of the hero's ATK** (`DamageMultiplier` in `ArchetypeCombatSkills`). The kits are tuned to match the existing archetype kits, so mirror heroes get their power from the mirror percentage, not from stronger skills. Rourke, the featured hero, gets one small extra (the attack-speed buff).

| Archetype | Basic | Special (every 3rd attack) | Skill (100 gauge) |
| --- | --- | --- | --- |
| Vanguard | 1.0 | 1.4 + cone stagger | taunt 25 studs 4 s + 40% Max HP barrier 6 s |
| Striker | 1.0 | 1.6 + 25% crit | 3.2 in 12 studs |
| Marksman | 1.0 | 1.5 + pierce line | 2.8 in 16 studs + 20% defense shred 5 s |
| Berserker | 1.0 | 1.5 + stagger | 2.6 in 18 studs |
| Scholar | 1.0 | 1.4 + chain to 2 | 3.5 in 20 studs |

### 5.1 Isabelle (`BOW`)

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Basic | Glint Shot | 1.0× ATK arrow. | A quick draw and release. The bow stays canted at chest height, and the monocle catches the light on release. |
| Special | Ricochet | 1.5× to the target, then bounces once to the nearest other enemy within 14 studs for 0.75×. | A full draw with a half turn of the torso, then the release follows through. |
| Skill | Twin Reflection | The arrow splits and hits the two highest-HP enemies for **2.5×** each. With only one enemy, both halves hit it (5.0×). A focused boss-killer, where the Marksman default is a 2.8× area. | She steps back, holds the draw for 0.4 s while the arrow glows, then releases with a hand flourish as it splits. |
| Idle | — | — | Weight on the back foot, bow low in her left hand, right hand resting on the quiver strap. Every few seconds she adjusts the monocle. |

### 5.2 Nyx (`DAGGERS`)

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Basic | Gilt Cut | Two slashes of 0.5× each (1.0× total). | Alternating forehand and backhand cuts. |
| Special | Mirror Step | Blinks behind the target and strikes for 1.6× with +25% crit chance. | A crouch, then she vanishes (leaving an afterimage) and reappears behind the target with a reverse-grip stab. |
| Skill | Shatterdance | Five mirror clones each slash every enemy within 12 studs for **0.65×** (3.25× total). | She spins up to a throwing pose, clones appear in a ring and slash inward in sequence, and she lands in a kneel. |
| Passive | Gilded Edge | Basic attacks charge 15% more skill gauge (5 → 5.75) while another mirror hero is within 8 studs. | — |
| Idle | — | — | Low crouch, both daggers reversed, one hand touching the mask. The cape sways. |

### 5.3 Caspian (`SWORD_SHIELD`)

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Basic | Gilt Edge | 1.0× sword strike. | A short overhand chop from behind the shield. |
| Special | Polished Bash | 1.4× shield bash with the Vanguard cone stagger (10 studs). | He steps forward and drives the shield in, and the chest mirror flashes. |
| Skill | Looking-Glass Bulwark | Taunts enemies within 25 studs for 4 s and raises a 40% Max HP barrier for 6 s (the Vanguard default). For those 6 s, **20% of the ranged damage Caspian takes is reflected** back to the attacker. | He plants the shield in the ground and raises the sword overhead, and a glass wall rises from the shield edge. |
| Idle | — | — | Upright guard, shield forward, sword resting on the shoulder. A slow, heavy breath. |

### 5.4 Seraphine (`STAFF`)

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Basic | Shard Bolt | 1.0× glass-shard projectile. | One-handed staff point. A halo shard detaches and flies. |
| Special | Refraction | A glass prism hits the target for **1.5×**, then splits into three shards that hit the three nearest other enemies within 14 studs for **0.6×** each. | She draws the staff back, the three halo shards join into a prism at the staff tip, and she thrusts the staff forward to launch it. |
| Skill | Hall of Mirrors | Four mirror crystals surround a 16-stud area and fire beams for 4 s: **3.5×** in total over 8 pulses to every enemy inside. | Staff held two-handed overhead. She turns a slow half circle while the crystals rise. |
| Idle | — | — | Floating slightly (`floatIdle`), staff upright, free hand palm up. The halo shards turn slowly. |

### 5.5 Rourke (`AXE`)

| Slot | Name | Effect | Animation |
| --- | --- | --- | --- |
| Basic | Gilt Cleave | 1.0× heavy horizontal swing. | A wide two-handed sweep with a step through. |
| Special | Last Stand | 1.5× overhead chop with the Berserker stagger, rising linearly to **2.5×** as his HP falls from full to 10%. | He raises the axe high behind his head, roars, and brings it down to the ground. |
| Skill | Gilded Frenzy | A ground slam for **2.6×** to every enemy within 18 studs, then +25% attack speed for 4 s. | He jumps, slams down with both hands, then spins once with the axe. |
| Idle | — | — | Feet wide, axe resting on the right shoulder, left fist clenched forward. A big chest heave every breath. |

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
| Isabelle | a gold trail on the arrow (`SHOT`) | a bounce flash between targets (`Chain`) | the arrow glows red, splits into two arrows with mirrored trails, and two impacts land (`Volley` with 2) |
| Nyx | thin teal slash arcs (`Slash`) | a teal afterimage at the start point and a burst behind the target (`Cross`) | five translucent glass clones slash inward in sequence, then shatter (`Whirl` with clone pass) |
| Caspian | a short gold swing arc | a ring shockwave from the shield (`Tremor`, small) | a tall pink-violet glass wall with a moving reflection streak, plus a glint flying back to the shooter on each reflected hit (`Bulwark`) |
| Seraphine | a spinning glass shard (`BOLT`) | an indigo glass prism flies to the target (`BOLT`), bursts with a light flash, and three smaller shards fan out to the next enemies (`Chain`) | four crystals rise and fire indigo beams to the centre (`Crystals` + `Beam`) |
| Rourke | a heavy rose-gold swing arc (`Cleave`) | an overhead trail that grows redder as his HP falls, plus a ground crack (`Execute`) | a gold shockwave ring with gold shards flying out (`Tremor`), then a rose aura on the axe for 4 s |

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

- Reference art for the five faces and hair (the user's call); block hair until then.
- Real ProductIds for the two offers (Creator Hub).
- Whether Rourke gets a part-budget override to 80.
