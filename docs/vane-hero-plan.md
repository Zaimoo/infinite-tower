# Vane: Legendary Scholar implementation plan

Status: plan, not started (2026-11-10). One branch and PR: `feat/vane-hero`, modelled on the Edis Callen PR (`bb44bae`), which is the template for a brand-new hero end to end. Art follows `docs/hero-art-pipeline.md` and the `hero-remodel` skill.

---

## 1. Character analysis

**Who he is.** Valerius "Vane" survived the wipe of a previous Master's account on the deep floors. He watched 1★ heroes spent as fodder, so his loyalty is conditional: he judges the current Master's tactics coldly and keeps to himself, filling the barracks floor with spell formulas. His look sells "detached genius": immaculate regalia, glasses, a closed-mouth smirk, one hand idly holding a spell matrix like a pen.

**Name.** `Valerius` is one letter off the existing **Valeria** (Superior Healer). Use **Vane** as the display name and `hero_vane` as the id; Valerius stays in his lore text only.

**Role fit.** Mage → archetype **Scholar**, weapon **`STAFF`** (fixed by `CLAUDE.md`). The ornate crystal staff in the art is not costume: he uses the archetype staff from the weapon system. The floating sigil in his left hand is VFX, not costume (see §4.4).

**Theme vs. the other Scholars.** Eolka is fire, Solaris is solar fire. Vane is **void / gravity**: violet, black and gold. His kit should *feel* different too (lines and pulls instead of another meteor pillar), which needs new mechanics (§3).

### Reference read (pipeline §4.1)

| | Notes |
| --- | --- |
| Body | Male, **Standard**. The mantle and sleeves give the bulk, not the body type. |
| Palette | Skin `226,178,138` · hair violet `120,50,200` · robe deep purple `70,28,110` · robe secondary violet `130,64,180` · dark base (trousers) `34,24,44` · gold trim `200,160,70` · amethyst Neon accent `190,100,255` · boots `52,30,66` (8 colours) |
| Torso | Layered: black-violet undershirt with high standing collar, deep-purple coat, front tabard panels with gold borders, gold chain necklace with amethyst pendant |
| Shoulders | Big double-layer mantle/capelet with gold trim (his biggest silhouette shape) |
| Arms | Wide bell sleeves, gold cuff bands |
| Waist | Sash belt, gold diamond buckle with amethyst, hanging chain + gem |
| Legs | Long open over-robe to the ankles, flaring at the back and sides; front tabard panels; black trousers |
| Feet | Dark purple boots, gold strap with amethyst at the shin |
| Hair | Short, voluminous, tousled; swept back and up on top, strands falling forward over the forehead (part on his right), short sides, ends at the nape. Not spiky, soft clumped locks |
| Face | Half-lidded crimson eyes, rectangular black glasses, one brow lifted, smug closed-mouth smirk; small gold-and-amethyst earrings |
| Stance | Feet a little apart, upright. Right hand holds the staff upright beside him; left arm forward and out, palm up, presenting the sigil |

---

## 2. Banner placement: Call of the Rift, tier 6 beside Edis (done)

Decided: Vane joins the **permanent** banner as its second Legendary; more permanent heroes are planned. Main already supports several heroes per tier: `HeroesPoolByStar[tier]` on each banner (added with Shurn and Diran). The server rolls the rarity at its rate (with luck, pity and the 10-pull floor), then picks a hero from that tier's pool uniformly, so the tier's heroes split its odds. `HeroesByStar[tier]` stays as the single id for tiers without a pool and for UI that shows one hero per tier.

Done in this branch: `HeroesPoolByStar[6] = { "hero_edis", "hero_vane" }`, so tier 6 stays 0.15% and Edis and Vane are 0.075% each. Edis's "same Gems per copy as Solaris" note is gone from `HeroCatalog` and GDD §4.2, and the GDD now says tiers can hold several heroes.

Gaps in the pool feature, not specific to Vane (follow-up):
- **Summon banner strip** (`FacilityController.BuildBannerView`) still draws one chip per tier from `HeroesByStar`, so pooled heroes (Shurn, Ignis, Vane) don't appear on the banner and the rate shown is the whole tier's. It needs one chip per pooled hero with its share, and a scrolling strip as the roster grows. The Hero Index already reads the pools.
- **Superior tier**: `HeroesByStar[4]` is `hero_catio` (a Rare) with no pool since Valeria moved to the limited banner, so a Superior roll gives Catio. It needs a Superior permanent hero or an explicit decision.
- **Weights**: the pool pick is uniform and ignores `DropWeight`. That's fine while every pool should split evenly.
---

## 3. Gameplay kit

`ArchetypeCombatSkills.HERO_KITS.hero_vane` today can only override names and numbers. `HeroSkillEffects` picks effects **by archetype**, so Vane would just get chain lightning and a meteor. His kit needs two new mechanics.

| Tier | Name | Behaviour |
| --- | --- | --- |
| Basic | **Null Bolt** | Scholar projectile default (1.00×), void palette |
| Special | **Singularity Lance** | A near-instant beam from Vane through the target, 36 studs long, ~3 studs wide. Full Special damage to the target, 0.8× ATK to every other mob on the line |
| Skill | **Event Horizon** | A mini black hole at the target for 4 s: 16-stud radius, 3.5× ATK split over 8 ticks (0.5 s), pulling mobs towards the centre each tick, a final collapse burst on the last tick |

Description for Event Horizon: "Vane collapses the space around the target into a miniature black hole for 4s (16-stud radius), dragging enemies inward and dealing 3.50x ATK void damage over its lifetime."

### Engine work

1. **Effect dispatch by `SecondaryEffect`.** In `HeroSkillEffects.resolveSpecial`, branch on `special.SecondaryEffect` first and fall back to the archetype branch, so existing heroes are unchanged. Add a `SkillEffect` field (or similar) to `SkillAttackDef` for the same in `resolveSkill`.
2. **`BEAM_LINE` special.** New `SecondaryEffectType`. Hit every eligible mob within `BeamWidth` of the segment from `hit.Impact.Origin` through the target, extended to `SecondaryParam` studs. Don't reuse `PIERCING_LINE`: the Marksman version is really "one mob within 32 studs", and changing it would rebalance three bow heroes.
3. **`SINGULARITY` skill.** Uses the existing `Ticks`/`TickSeconds` (already split damage per tick) plus a new `PullStudsPerTick`. Each tick, damage mobs in radius and move them towards the centre, clamped so they never overshoot. Exempt Biome Bosses and Alphas (or halve the pull), and check how mob positions interact with `TowerEncounterRuntime` / mob pathing so pulled mobs don't desync or leave the floor. Rate limits and server authority are unchanged: it's all server-side.
4. **VFX.** `SkillVfxCatalog`: new Special style `BEAM` and Skill style `SINGULARITY` (dark sphere, a gold-violet accretion ring, debris spiralling in, collapse flash; TEMPEST's `Implode` sphere is a starting point). Register them in `Styles` and implement them in the client `SkillVfx` player. Palette: Primary `170,80,255`, Secondary `30,16,44`, Core `240,220,255`.
5. **Clips** (`HeroClips.luau`, `OVERRIDE_WEAPON.hero_vane = "STAFF"`): Special: staff levelled forward, a short brace, then a recoil on `Release`. Skill: staff raised overhead, left hand clenching closed as the hole forms, held through the cast (`CastSeconds` ~1.2). Superseded by the full per-spell animation and VFX design in `docs/vane-spell-animations-plan.md` (own Basic clip, Charge marker, Skill cast 1.4 s).

### Seed (`HeroCatalog.Seeds.hero_vane`)

Rarity 6, Scholar, `BannerOrigin = "STANDARD"`, `DropWeight = 0.5` (equal to Edis, so they split tier 6 evenly). Base around Solaris (240 HP / 55 ATK, interval 0.95, range 30) but trading toughness for reach: **220 HP / 60 ATK**, interval 1.0, range 32. Derive `NativeHP`/`NativeATK`/`NativeLabor` from `StatBalance` the way Edis did (note: Solaris's stored native values look out of date next to Edis's; check before copying either). `PreferredFacility = "FACILITY_TRAINING"`, `Color = 150,70,230`. Balance-check Event Horizon against Solaris's Supernova: less burst, more total value from grouping, so the 3.5× should not be raised.

### Lore features out of scope

Nothing in `src` implements a **sanity meter**, formation-quality judgement or **deployment voice lines**. Ship his lore as data only. If wanted later, a "Conditional Loyalty" trait (e.g. a debuff when squadmates are far below his level) and a voice-line system are their own design + GDD change and their own PR.

---

## 4. Art (hero-remodel skill)

### 4.1 Face: `assets/faces/make_vane_face.py`
Derive from `make_velkist_face.py` (cocky: half-lidded lids, pinched brow), but swap the toothy grin for a closed one-sided smirk. Crimson irises (`170,30,40` → `230,70,60`), violet-dark brows (`70,30,110`, following the hair), left brow raised a little higher. **Glasses on the decal**: thin black rectangular frames around both eyes plus a bridge, with a faint lens glint, since a Part frame would clip the rounded head. Preview, then upload via Studio MCP `upload_image`.

### 4.2 Hair: `tools/make_vane_hair_ugc.py`
Base: Morrigan (swept back with flaring locks) for the top, Archon for short sides. Layout: full `cap()` to the nape; 8–10 wide crown locks fanning back and up with soft upward flicks; 4–5 fringe locks falling forward and to his right across the forehead, ending at brow level, one longer lock dipping past the glasses; short side locks ending at mid-ear; back locks staggered to the nape. Target 8k–12k triangles. Export, send the angles render, wait for the user's MeshId.

### 4.3 Costume (`HeroCostumes.luau`, Standard, ≤ 60 parts)
Base colours: UpperTorso undershirt dark, arms robe purple, legs trousers dark, feet boots. Rough budget (44 pieces + 16 rig = 60):

| Group | Pieces |
| --- | --- |
| Torso | coat L/R + back (3), standing collar back + sides (3), tabard chest panel + gold border (2), chain + pendant + gem (3) |
| Mantle | capelet L/R on UpperArm + gold trim each (4), back capelet panel (1) |
| Sleeves | bell sleeve flare on each LowerArm, `Loose` + gold cuff (4) |
| Waist | sash, buckle, gem, hanging chain + gem (5) |
| Robe | back panel flaring `Rotation -10` + gold hem (2), side panels L/R + hems (4), front tabards L/R + gold borders (4) |
| Legs/feet | boot shells + gold soles (4), shin straps + gems (4) |
| Head | hair mesh (1), earrings (2) |

Rules to watch: the mantle is his silhouette, but keep it inside the arm swing so it doesn't lint into the head; collar must stay out of the chin; bell sleeves must keep the fist front clear for the staff grip; Neon only on the small gems (≤ 0.3). If it's over budget, drop the shin gems first, then the side-panel hems.

### 4.4 Idle (`Overrides.hero_vane.Idle = breathe(stance, 3.6)`)
"Calculating": upright waist, `Neck {-4, 6, 3}` (chin down, slight tilt). Right arm uses the measured staff pose `RightShoulder {10,0,28}`, `RightElbow {35,0,0}`, `RightWrist {45,-35,0}`. Left arm presents forward and out, `LeftShoulder {55,0,-30}`, `LeftElbow {60,0,0}`, wrist turned palm-up; **measure in Studio** since the staff is nearby. Feet slightly apart, small knee bends. Optional later: a small looping sigil VFX on the left hand during Idle (client-only, cosmetic).

---

## 5. Files touched

- `Shared/Config/HeroCatalog.luau`: seed, list-valued `HeroesByStar`, `TierHeroes`/`PickTierHero`, `PoolByStar[6]`
- `ServerScriptService/Core/DataManager.server.luau`: `rollBannerHero`, `featuredId`
- `StarterPlayerScripts/UI/FacilityController.luau` (roster strip, featured), `Hud/HeroIndex.luau`, `Hud/ShopPanel.luau`
- `Shared/Config/ArchetypeCombatSkills.luau`: kit, `BEAM_LINE`, skill-effect field, new def fields
- `ServerScriptService/Combat/HeroSkillEffects.luau`: dispatch, beam line, singularity + pull
- `Shared/Config/SkillVfxCatalog.luau` + client `SkillVfx`: `BEAM`, `SINGULARITY`
- `Assets/HeroRig/HeroCostumes.luau`, `HeroClips.luau`
- `assets/faces/*vane*`, `assets/hair/vane_hair*`, `tools/make_vane_hair_ugc.py`
- Specs: hero count 13 → 14 in the costume and VFX specs; new combat-skills tests for the line hit set and pull clamping/boss exemption
- Docs: GDD (banner, hero table, kit table, new mechanics), `CLAUDE.md` banner facts if a banner changes, `docs/ui/UI_ASSET_REQUESTS.md` portrait list, pipeline doc §7 status row

## 6. Order of work

1. ~~Branch; tier-6 pool entry; seed, kit names, 8-tick Event Horizon, clips, first-pass costume (no face or hair), VFX entry, docs.~~ Done on `feat/vane-hero`, tests pass, not committed.
2. Face decal (needs Python + PIL) and upload (needs Studio MCP).
3. Hair in Blender (needs the Blender MCP); the user imports the FBX and sends the MeshId; wire it and do a fit pass.
4. Studio temp-rig check of the costume and idle (front, face, back).
5. Engine: effect dispatch, `BEAM_LINE`, `SINGULARITY` + pull + tests; then the `BEAM` / `SINGULARITY` VFX styles.
6. `pwsh tests/run.ps1`, a tower playtest for the pull, then commit and open the PR (with the user's OK).

## 7. Risks

- **Pull vs. pathing**: the most likely source of bugs (mobs stuck in walls, off ledges, desync with the 24-byte entity records). Clamp to floor bounds and exempt big mobs.
- **Mantle vs. part budget**: robes are part-hungry; the 60 cap is tight.
- **Summon strip layout**: one chip per hero needs scrolling soon; check it on a phone-sized viewport.
- **Hidden `HeroesByStar` readers**: grep again for `HeroesByStar` before merging (tests and `studio-*` scripts included), since a string-to-list change fails silently where code concatenates or looks up the id.
