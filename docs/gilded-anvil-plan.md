# The Gilded Anvil: premium artifact banner

Status: **implemented** (2026-11-14). Shipped across `ArtifactCatalog`, `AnvilBanner`, `WeaponVfxConfig` (Band 6), `GildedAnvilMeshData` / `WeaponModelBuilder`, `WeaponVfx`, `GildedAnvilFx`, `ShopConfig`, `ShopService`, `DataManager`, `ShopPanel`, and `SummonReveal`. This document also serves as the companion specification to the Gilded Mirror hero banner (`docs/gilded-mirror-plan.md`).

---

## 1. Summary

**The Gilded Anvil** is a Robux-only artifact banner with six **Gildforged** weapons, one for each archetype. Every pull is one of the six; there is no filler.

| Artifact | Archetype / weapon | Element | Template id (proposed) |
| --- | --- | --- | --- |
| Dawnwarden's Oath | Vanguard / `SWORD_SHIELD` | Sunlight (gold, white) | `art_gild_dawnwarden_oath` |
| Eclipse Sisters | Striker / `DAGGERS` | Eclipse (black, corona gold) | `art_gild_eclipse_sisters` |
| Aurora Skyhook | Marksman / `BOW` | Aurora (teal, violet, pink) | `art_gild_aurora_skyhook` |
| Wyrmheart Cleaver | Berserker / `AXE` | Dragonfire (molten gold, crimson) | `art_gild_wyrmheart_cleaver` |
| Orrery of the Ninth Sky | Scholar / `STAFF` | Star-orbit (gold, deep blue) | `art_gild_ninth_sky_orrery` |
| Evergarden Codex | Healer / `TOME` | Bloom (white bark, jade, gold) | `art_gild_evergarden_codex` |

The shared look: every Gildforged weapon carries **gold filigree** inlay and a living centrepiece (a sun disc, an eclipse, a beating heart, an orbiting sphere) that moves on its own. Normal artifacts are static models with particles; these are the only artifacts with moving parts.

## 2. Banner rules (proposed, open to tuning)

- **Rarity:** all six are **Transcendent (tier 8)**, so whichever archetype a Master plays, the weapon they want is worth the same. Power follows the existing table: 10,000 at 1★, 160,000 at 7★ (`STAT_SCALING_TABLES.md`), above the launch Mythical (7,000 → 112,000).
- **Focus pick:** before buying, the Master picks a Focus archetype. **40%** of pulls give the Focus weapon, **12%** each give one of the other five. Changing the Focus is free.
- **Price:** Robux only (`ShopConfig`, granted through `ShopService` like the Mirror). Proposed **49 R$** for one pull, **449 R$** for ten. No Gem or Gold price, no God's Blessing luck.
- **10-pull guarantee:** every ten-pull contains at least one copy of the Focus weapon.
- **Spark:** every **60 pulls** bank one free pick of any of the six.
- **Promotion:** star promotion works as usual (§7.3): donors must be the same tier and stars, so in practice Gildforged weapons promote with other Gildforged copies of any type.
- **Not sellable:** Gildforged weapons can't be sold for Gold, so Robux never turns into Gold. They still count against the 50-artifact cap, and the purchase is refused when it would exceed the cap (like the Forge).
- **Paid random items:** players whose `PolicyService` restricts them never see the banner. A purchase that still arrives becomes Gems at the Gem store's rate, as on the Mirror.

## 3. Premium VFX layer (what "more than normal" means)

Today's `WeaponVfx` tops out at **Band 5** (Legendary and Mythical): a PointLight, dense motes, an aura and a wide trail. Tiers 8–11 currently map to Band 4. Gildforged weapons get a new **Band 6 "Gilded"** that keeps everything in Band 5 and adds the following on top:

| Layer | Normal artifact (Band 5) | Gildforged (Band 6) |
| --- | --- | --- |
| Model | Static parts | A moving centrepiece (orbits, spins, pulses) |
| Idle glow | PointLight + motes + aura | Same, plus a **gold glint** that sweeps along the filigree every 4 s |
| Footprint | None | A faint gold **sigil under the hero** while the weapon is drawn, unique per weapon |
| Swing / shot trail | One or two layers in the element colour | Two layers (element colour + gold edge), plus a short **afterimage** of the weapon on Special attacks |
| Hit | Shared element hit spark | Its **own** hit effect per weapon |
| Skill | Hero's skill VFX only | A **signature finisher** layered on the hero's skill (described per weapon below) |
| Kill / crit | None | A small signature burst |
| Equip | None | A one-shot **equip flourish** in the Squad / Forge preview and in the world |
| Summon | Normal Forge reveal | Its own reveal: a gold anvil strike, sparks, and the weapon rising out of the light |

**Budget (proposed):** `Band6 = { MoteRate = 18, AuraRate = 18, LightRange = 8.5, LightBrightness = 0.9 }`. At most one moving centrepiece and one ambient emitter per weapon. Beyond 60 studs only the light and glint remain. **Reduce Motion** turns off the orbiting pieces, footprints, afterimages and kill bursts (the light and trail stay). In the tower, effects on other Masters' heroes use Band 5 rates, so a full server never stacks 40 premium emitters at full rate.

## 4. The six artifacts

Each entry gives the catalog `Description` (one line, the same style as `ArtifactCatalog`), the full look for the modeller, and the VFX by moment.

### 4.1 Dawnwarden's Oath (Vanguard, `SWORD_SHIELD`)

**Catalog line:** "White-gold longsword sworn to a kite shield whose sun-disc boss rises and sets in the hand of its bearer."

**Look.** A straight, broad longsword in white-gold steel, with a gold fuller engraved with sunrays and a crossguard shaped like two outspread wings. The shield is a tall kite shield of pale enamel bordered with gold filigree; its boss is a **sun disc** set in a ring of gold rays, which turns slowly in its socket.

**VFX.**
- **Idle:** the sun disc rotates slowly and gives off a warm pulse every 3 s. Three thin halo rings orbit the shield's face. A heat-shimmer line runs up the blade's edge.
- **Footprint:** a rising-sun sigil (half disc and rays) under the hero.
- **Basic:** gold-cored trail with a white feathered edge; on hit, a short crescent of light hangs in the air for 0.3 s.
- **Special:** a sword afterimage repeats the swing; on hit, the shield flashes and a hexagonal ward ripples across its face.
- **Skill finisher:** the hero plants the sword, and a translucent golden **tower-shield wall** rises in front of the squad for the length of the skill, with light motes falling through it.
- **Kill / crit:** a burst of gold feathers.
- **Equip:** the sun disc ignites from dim to full like a sunrise.

### 4.2 Eclipse Sisters (Striker, `DAGGERS`)

**Catalog line:** "Twin daggers Umbra and Corona: one of black glass edged in light, one of gold wreathed in black flame."

**Look.** Mismatched twins. **Umbra** (main hand) is a slim black-glass blade whose edge is a thin line of white corona light. **Corona** (off hand) is a curved gold blade with black flame licking off its spine. The two pommels are a black sphere and a gold ring; held together, they form an eclipse.

**VFX.**
- **Idle:** a tiny **eclipse** (a black sphere with a ring of light) drifts in a slow loop between the hero's hands. While the hero moves, the blades leave faint ghost afterimages.
- **Footprint:** a crescent-moon sigil that waxes while the hero stands still.
- **Basic:** alternating black and gold slash trails; when two consecutive hits land on the same target, the trails cross into an X-shaped spark.
- **Special:** three shadow afterimages repeat the flurry 0.1 s behind the hero.
- **Skill finisher:** a ring of eclipse light closes around the main target for 0.4 s, then bursts outward as a corona flare.
- **Kill / crit:** the target's outline shatters into shards of light.
- **Equip:** the two blades cross and the eclipse forms between them.

### 4.3 Aurora Skyhook (Marksman, `BOW`)

**Catalog line:** "Recurve bow whose limbs are ribbons of living aurora held in gold clasps, strung with a thread of polar light."

**Look.** A recurve bow with a gold grip and gold limb clasps. The limbs themselves are two curved **aurora ribbons** that flow from teal to violet to pink, and the string is a thin line of white light. Gold tips at each limb end hold the ribbons in shape.

**VFX.**
- **Idle:** the aurora ribbons ripple (an animated beam texture), shedding faint curtains of colour that drift downward and fade.
- **Footprint:** a ring of aurora light with a north-star point.
- **Draw:** the arrow forms from motes of light spiralling into the nock.
- **Basic:** the arrow trails an aurora ribbon; impact blooms into a small aurora curtain flare.
- **Special:** mid-flight the arrow passes through a prism flash and splits into three.
- **Skill finisher:** the hero fires straight up; an aurora curtain lights the sky over the target area and arrows of light rain through it.
- **Kill / crit:** a starburst in aurora colours.
- **Equip:** the ribbons unfurl from the gold clasps.

### 4.4 Wyrmheart Cleaver (Berserker, `AXE`)

**Catalog line:** "Two-handed greataxe forged around a caged dragon's heart; molten gold drips from a head carved as a roaring skull."

**Look.** A long, blackened-iron haft wrapped in gold rings and red leather. The head is a single great blade shaped like a **dragon skull** in mid-roar, its edge glowing molten. In the skull's open jaw, a **dragon heart** of ember sits in a gold cage.

**VFX.**
- **Idle:** the heart **beats** every 1.2 s: a pulse of light, a ring of heat haze and a few ember sparks. Drops of molten gold drip from the edge and sizzle where they land.
- **Footprint:** cracked ground glowing with lava light.
- **Basic:** a wide fire trail with an ember shower.
- **Special / slam:** glowing cracks spread from the impact point with a ring shockwave.
- **Low health:** the skull's eyes ignite and flame wings flicker from the axe head.
- **Skill finisher:** on the final chop, a spectral **dragon head** roars out of the blade along the strike.
- **Kill / crit:** an ember burst with a short heartbeat sound.
- **Equip:** the heart beats for the first time and the eyes flash.

### 4.5 Orrery of the Ninth Sky (Scholar, `STAFF`)

**Catalog line:** "Gilded staff crowned by a living armillary sphere: three gold rings turning around a captured star and its moons."

**Look.** A tall, slender staff of deep blue lacquer inlaid with gold constellation lines. Its head is a gold **armillary sphere**: three rings at different angles around a small, bright captured star, with three tiny moons on wire arms.

**VFX.**
- **Idle:** the three rings counter-rotate, the moons orbit the star, and faint constellation lines flicker between the moons and the hero's shoulders.
- **Footprint:** a star chart that slowly turns.
- **Basic:** the rings snap into alignment and flash; the projectile is a small comet with a gold tail.
- **Special:** the hero draws a constellation glyph in the air before casting; the glyph stays for 0.5 s.
- **Skill finisher:** a large translucent armillary sphere unfolds above the target area and meteors fall through it.
- **Kill / crit:** a small supernova flare.
- **Equip:** the rings spin up from still to full speed.

### 4.6 Evergarden Codex (Healer, `TOME`)

**Catalog line:** "Living tome bound in white bark and gold filigree, its leaf-pages turning on their own and breathing blossoms."

**Look.** A thick tome with covers of pale **white bark** framed in gold filigree, a jade gemstone set in the front, and a blossom-shaped bookmark. The pages are thin green leaves with gold veins.

**VFX.**
- **Idle:** the pages turn on their own; glowing petals and leaves drift out. Small flowers sprout in the hero's footsteps and fade after 2 s.
- **Footprint:** a ring of blooming flowers.
- **Basic:** petals spiral from the tome to the target; a hit makes a small bloom.
- **Heal:** a flower blooms over the healed ally and sheds light.
- **Special:** a page tears free and becomes a glowing butterfly that flies to its target.
- **Skill finisher:** the tome opens wide and a **tree of light** grows behind the hero; its canopy rains petals over allies in range.
- **Kill / crit:** a puff of seeds that drift away.
- **Equip:** the tome opens and the first flower blooms.

## 5. Build checklist (shipped)

1. Catalog entries in `ArtifactCatalog` (tier 8, `Variant = "Gildforged"`, `CalculateSellPrice` returning `0` / unsellable across sell UIs & `DataManager.SellArtifacts`) and `WeaponVfxConfig` (Band 6, six bespoke elements: `SUNLIGHT`, `ECLIPSE`, `AURORA`, `DRAGONFIRE`, `STAR_ORBIT`, `BLOOM`).
2. Sculpted `EditableMesh` + `AssetService:CreateMeshPartAsync` models in `GildedAnvilMeshData` and `WeaponModelBuilder` (`IsGildedTemplate`, `CloneOrBuildPrefab`, per-assembly `OffhandShield`, `LeftDagger`, `HunterArrow`, invisible `Handle` on `Evergarden Codex`, and `GildAnimRole` `Weld`s).
3. `WeaponVfx` Band 6 layers (`VfxGildFiligreeTrail`, `VfxGildGlintSweep`, `SetRateScale`, `BaseRate`/`VfxKeepFar` LOD) and `GildedAnvilFx`, driven by `_G.GildedAnvilCombatFx` hooks in `EntityRenderer`. `GildedAnvilFx` covers:
   - centrepiece animation that spins up on equip;
   - a footprint sigil for each weapon (rising sun, a waxing crescent, an aurora ring with a north star, lava cracks, a turning star chart, a flower ring);
   - idle extras: the Wyrmheart's heartbeat, embers, molten drips and a skull that burns below 30% HP, the Dawnwarden's sun pulse, and the Evergarden's footstep flowers;
   - weapon afterimages on Specials (three for the Eclipse Sisters);
   - each weapon's own Basic and Special hit effect, signature skill finishers, and kill / crit bursts;
   - Reduce Motion, 60-stud LOD and the Band 5 cap on other Masters' weapons.

   Hit and kill events carry no attacker, so the client credits them to the Gildforged hero that last attacked toward that spot (a cosmetic guess). Not built: the Eclipse's drifting mini-eclipse between the hands, the Aurora's shed curtains, the Orrery's constellation lines to the shoulders, the bow's draw spiral and the Evergarden's heal bloom.
4. Store card, 3D `ArtifactPreview` tiles, Focus pick, and Spark (`AnvilBanner`, `ShopConfig.Anvil`, `ShopService`, `DataManager.RollAnvilSummons` + `SetAnvilFocus`/`ClaimAnvilSpark`, `ShopPanel`, `SummonReveal`, and `ForgeController`).
5. GDD §7 (`docs/GAME_DESIGN.MD` §7.4a) and unit tests (`tests/anvil.spec.luau`) updated with shipped behavior.

## 5a. Mesh upload (Blender to Roblox)

The models are authored in `tools/blender/generate_gilded_anvil_weapons.py`, which exports one FBX per weapon to `assets/artifacts/gilded_anvil/`, plus `manifest.json` and the packed geometry shards in `ReplicatedStorage/Assets/GildedAnvilMeshes/`.

`WeaponModelBuilder` builds each part from its uploaded `MeshId` (`AssetService:CreateMeshPartAsync`). A part with no MeshId falls back to rebuilding the sculpt from its shard through `EditableMesh` (`GildedAnvilMeshData.GetGeometry`, decoded only on that path). The fallback is a stopgap: it doesn't save with the place, server-built copies don't replicate, and it depends on the EditableMesh memory budget. Ship with every MeshId filled in.

1. In Studio, **File → Import 3D** each `art_gild_*.fbx` into Workspace, keeping the parts separate and leaving the model named after the file.
2. Run `tests/studio-gilded-anvil-import.luau` through Studio MCP. It finalizes the prefabs in `ReplicatedStorage.Assets.Weapons` and prints a JSON map `{ templateId: { PartName: MeshId } }` on its last line.
3. Save that JSON as `assets/artifacts/gilded_anvil/mesh_ids.json`, then run `python3 tools/apply_gilded_anvil_mesh_ids.py`. It writes the IDs into the shards and the manifest and warns about any part that has no ID.

The generator reads `mesh_ids.json` too, so a re-export keeps the IDs. If a weapon's geometry changes, re-upload that weapon.

## 6. Resolved design decisions

- **Same tier for all six:** All six Gildforged relics ship at Tier 8 (Transcendent, `10,000` Power at 1★ up to `160,000` at 7★).
- **Price and Spark count:** `49` Robux per single pull (`pack_anvil_1`), `449` Robux per 10-pull (`pack_anvil_10`, `-8%` vs `490`), `60` pulls per Spark pick (`AnvilBanner.SPARK_COST`), and `135` Gems per pull for policy-restricted fallback (`ShopConfig.GemsPerSummon`).
- **Cross-type Tier-8 promotion:** `WeaponPromotion` accepts any Tier-8 weapon of matching star rank as a donor across archetypes, including across Gildforged and any future Tier-8 Transcendent weapons.
- **Tiers 8–11 VFX band:** `WeaponVfxConfig.RarityBands[8..11]` raised from Band 4 to Band 5 so no premium-tier weapon falls below Mythical visuals, while Gildforged weapons exclusively receive Band 6.
