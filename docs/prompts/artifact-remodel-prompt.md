# Prompt: Artifact Weapon Remodel + VFX (Blender → Roblox)

Copy everything below the line into the chatbot / LLM.

---

## Role

You are a two-specialist team speaking as one. Say which role you are speaking as when it matters.

**Forge** is a senior 3D weapon artist and technical artist for a stylized anime-fantasy Roblox action RPG, *Infinite Tower: Become a Master!*. Forge models in **Blender** (via the Blender MCP / Python `bpy` when available) and understands how Roblox imports meshes, how Roblox `Attachment`s, `Weld`s and `WeldConstraint`s work, and how a prefab gets socketed onto a code-built hero rig. Forge thinks like both an artist (silhouette, readability at gameplay distance, rarity fantasy) and an engineer (pivots, axes, part names, budgets).

**Ember** is a senior Roblox VFX artist. Ember builds effects from `ParticleEmitter`, `Beam`, `Trail`, `PointLight`, `Highlight`, Neon/ForceField materials and flipbook textures. Ember knows what each costs (particle counts, overdraw, lights, transparency sorting) and how effects behave on welded, animated, moving parts. Ember designs each weapon's idle aura and attack accents, and scales them with rarity.

Neither of you breaks the runtime contract described below.

## The task

Replace the placeholder, primitive-built artifact (weapon) models with real Blender-authored meshes, **one model per artifact**, based on each artifact's `DisplayName`, `Description`, weapon `Type`, `RarityTier` and `Variant` in `src/ReplicatedStorage/Shared/Config/ArtifactCatalog.luau` (`ArtifactCatalog.Seeds`).

Today all 84 artifacts (7 launch rarity tiers × 6 weapon types × Standard/Enhanced) share six generic prefabs — `weapon_bow`, `weapon_sword_shield`, `weapon_daggers`, `weapon_axe`, `weapon_staff`, `weapon_tome` — built from Parts in `src/ReplicatedStorage/Assets/WeaponModelBuilder.luau`. Your job is to give each artifact its own model that visually matches its description, while still slotting into the existing socket system with zero changes to animations.

Work in batches by weapon type (e.g. all 14 bows), lowest rarity first, so the visual progression from Common to Origin reads clearly.

## Game facts you must respect

- **Artifacts are weapons.** Each archetype wields exactly one type:

  | Archetype | Weapon type | Prefab key | Held in |
  | --- | --- | --- | --- |
  | Vanguard | `SWORD_SHIELD` | `weapon_sword_shield` | sword: right hand; shield: left forearm |
  | Striker | `DAGGERS` | `weapon_daggers` | right hand + left hand |
  | Marksman | `BOW` | `weapon_bow` | left hand |
  | Miner | `AXE` | `weapon_axe` | right hand (two-handed swing via `OffhandGrip`) |
  | Scholar | `STAFF` | `weapon_staff` | right hand |
  | Healer | `TOME` | `weapon_tome` | left hand |

  There are no rings and no standalone shields — the shield only exists as part of `SWORD_SHIELD`.
- **Rarity** is inherent (16 tiers, Common → Origin). Higher tiers must *look* more valuable: richer materials, more ornament, gems, runes, glow. Enhanced variants are visibly upgraded versions of their Standard sibling (same family silhouette, extra detail / better metal), not unrelated designs.
- **Stars (1★–7★)** do not change the model. Don't model star variants.
- Art direction: stylized anime fantasy (think *Pick Me Up, Infinite Gacha*), chunky readable silhouettes, slightly oversized heads/blades, clean bevels, hand-painted or flat-PBR textures. Weapons are seen from an isometric-ish gameplay camera at small screen size — silhouette first, micro-detail last.

## Runtime contract (do not break this)

The weapon is attached to the hero by `src/ReplicatedStorage/Assets/HeroRig/HeroSockets.luau`, called from `HeroLoadout.luau`. Read both before starting. Summary:

1. **Prefab = a `Model`** in `ReplicatedStorage.Assets.Weapons`, named by the seed's `ModelAssetId`. It must have a **`PrimaryPart` named `Handle`**.
2. **Socket attachments live on the PrimaryPart.** The socket is one explicit `Weld` per socket:
   `weld.Part0 = rigPart`, `weld.Part1 = assembly.PrimaryPart`, `weld.C0 = rigAttachment.CFrame`, `weld.C1 = weaponAttachment.CFrame`.
   An explicit `Weld` is used (not a `WeldConstraint`) because a `WeldConstraint` freezes whatever offset exists when it activates and drifts once the hand is posed. The socket code creates these welds — **you don't**.
3. **Grip axis rule (critical).** Every `Grip` attachment follows one convention:
   - **UpVector (+Y)** runs along the handle **toward the weapon's head** (blade tip, axe head, staff orb, bow upper limb, tome spine top).
   - **LookVector (−Z of the attachment)** is the weapon's **working direction** (the cutting edge, the arrow flight, the crown face of the staff, the tome's front cover).
   - Blades and axe heads are modelled along handle **+Y with the edge facing +X**, and their Grip is rotated `(0, -90, 0)` degrees (`EDGE_PLUS_X`) so Look points along +X.
   - Hero hands carry `RightGripAttachment` / `LeftGripAttachment` with rotation `(-90, 0, 0)` (`HeroRigSpec.GRIP_ROTATION`); the shield uses `LeftLowerArm.ShieldMountAttachment` at `(0, 90, 0)`.
4. **Required attachments and sub-assemblies per type:**

   | Type | On `Handle` (PrimaryPart) | Sub-assembly (child `Model` with its own PrimaryPart) |
   | --- | --- | --- |
   | `BOW` | `Grip` at riser centre, rotation 0 (up = upper limb, look = arrow flight −Z). String sits behind the riser at +Z; nocked arrow on the +X side. | — |
   | `SWORD_SHIELD` | `Grip`, `EDGE_PLUS_X` | `OffhandShield` model with `ShieldMount` attachment on its PrimaryPart |
   | `DAGGERS` | `Grip`, `EDGE_PLUS_X` | `LeftDagger` model, PrimaryPart `HandleL` with its own `Grip`, `EDGE_PLUS_X`. Set Model attribute `ReverseGrip = true` if the blades should run along the forearm. |
   | `AXE` | `Grip` near the butt (≈ `(0, -0.9, 0)`) **and** `OffhandGrip` higher up the haft (≈ `(0, 0.2, 0)`), both `EDGE_PLUS_X` | — |
   | `STAFF` | `Grip` ≈ `(0, -0.4, 0)`, rotation 0 (up = orb, look = crown face −Z) | — |
   | `TOME` | `Grip`, rotation `(0, 180, 0)` (up = spine top, look = front cover +Z) | — |

   Use the existing builders in `WeaponModelBuilder.luau` as the **reference for position, scale and orientation**: match each new model's grip point, overall length and hand placement to the current one so existing animations (`HeroClips`) still line up.
5. **Internal welding.** Every non-PrimaryPart part/MeshPart in an assembly must be held to that assembly's PrimaryPart by a `WeldConstraint` (or a Weld with correct C0/C1). Sub-assemblies (`OffhandShield`, `LeftDagger`) must **not** be welded to the main `Handle` — the socket system welds each one to a different limb. No `Motor6D`s, no Humanoid, no Bones/skinning — weapons are rigid.
6. **Part properties.** All parts: `Anchored = false`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `Massless = true`, `CastShadow = false` (the socket code enforces this too, but ship it clean).
7. **Part naming drives rarity styling.** `WeaponModelBuilder.Style` turns parts whose names contain `Blade`, `Tip`, `Orb` or `Crystal` into Neon in the rarity colour at rarity ≥ 5 (Exalted+). The VFX bands below add effects on top of that glow. `Style` also has per-artifact recolours that match on `Limb`, `Riser`, `Band`, `Wrap`, `Guard`, `Pommel`, `Rune`, `Gem`, `ShieldPlate`, etc. **Split your mesh into separately named MeshParts along those semantic lines** (e.g. `Blade`, `BladeTip`, `Crossguard`, `Pommel`, `RuneCore`, `ShieldPlate`, `ShieldBoss`, `StaffOrb`) so the glow lands on the right pieces. Keep the handle/grip its own `Handle` part.
8. **Data hookup.** A per-artifact model needs: a new prefab name (use the artifact's `TemplateId`, e.g. `art_iron_broadsword`), that name set as the seed's `ModelAssetId`, and the prefab present in `Assets.Weapons`. `HeroSockets.ResolvePrefab` already prefers `seed.ModelAssetId`; the generic type prefab stays as the fallback, so **never delete the six generic prefabs**.

## Weapon VFX (Ember)

Every weapon gets VFX that **ramps with rarity tier**. A Common weapon is plain steel; an Origin weapon should look like it's tearing reality apart. Use the rarity colours from `ArtifactCatalog.GetRarityInfo(index).Color`:

| # | Rarity | Colour | # | Rarity | Colour |
| --- | --- | --- | --- | --- | --- |
| 1 | Common | #B0B0B0 | 9 | Ascendant | #E056FD |
| 2 | Uncommon | #4BB543 | 10 | Ethereal | #686DE0 |
| 3 | Rare | #2980B9 | 11 | Immortal | #FF7979 |
| 4 | Superior | #8E44AD | 12 | Divine | #F9CA24 |
| 5 | Exalted | #D35400 | 13 | Celestial | #00D2D3 |
| 6 | Legendary | #F1C40F | 14 | Primordial | #FF3838 |
| 7 | Mythical | #E74C3C | 15 | Supreme | #BADC58 |
| 8 | Transcendent | #1ABC9C | 16 | Origin | #FF9FF3 |

### Tier ladder (each band keeps everything below it)

| Band | Rarities | Idle (always on while equipped) | On attack |
| --- | --- | --- | --- |
| 0 | Common | Nothing. Clean materials only. | Nothing. |
| 1 | Uncommon, Rare | A faint rarity-coloured glint: sparse sparkle `ParticleEmitter` (≈1–2/s) on the blade, head, orb or cover. | A thin edge `Trail` during swings and arrow flight, ~0.15 s. |
| 2 | Superior, Exalted | A small `PointLight` (range 4–6, brightness ≤ 1) and Neon rune/gem parts. Gentle drifting motes (≈4/s). | A wider gradient trail and a small spark burst on Basic hits. |
| 3 | Legendary, Mythical | A soft aura hugging the blade or head (low-alpha particles or a ForceField inner shell), flavoured by the element in the description (frost, embers, poison, holy, shadow). Rising wisps. | A two-layer trail (core + soft glow), a shockwave ring on Special, and a charge glow as the skill gauge nears 100. |
| 4 | Transcendent → Divine (8–12) | Orbiting runes or shards (`Beam`s or small parts animated on the client), animated flipbook energy on the blade, and a pulsing light. | An element-specific Special/Skill burst and afterimage trails. |
| 5 | Celestial → Origin (13–16) | A full signature effect: reality cracks, star particles, a halo crown, and a colour-cycling gradient for Origin. An optional `Highlight` outline (at most one per hero). | A big Skill flourish, still sized to read at gameplay distance. |

Launch weapons stop at tier 7 (band 3), so spend most of the polish on bands 0–3 and make every rarity step *visible*, not only every band. Build bands 4–5 as data-driven templates so future tiers are cheap to add.

### VFX rules

- **VFX attachments.** Add named attachments on the PrimaryPart:
  - `VfxTip` and `VfxBase` at the two ends of the edge, as `Trail` endpoints.
  - `VfxCore` at the aura centre.
  - `VfxTipL` / `VfxBaseL` on `LeftDagger`, `VfxShield` on `OffhandShield`, and `VfxNock` on the bow string.

  Never reuse the `Grip`, `OffhandGrip` or `ShieldMount` names.
- **Apply VFX at equip time, from data.** One model is shared across rarities, so never bake effects into the prefab. Add `WeaponVfx.Apply(model, weaponType, rarityIndex, artifactId)`, called from `WeaponModelBuilder.Style`. Drive it from a `--!strict`, tab-indented config such as `Shared/Config/WeaponVfxConfig.luau`, which maps rarity → band, element → palette and textures, and holds per-type overrides.
- **Client only.** The client renders weapons (`EntityRenderer`, `HeroLoadout`), so add no server VFX and no new remotes. Hook attack accents into the existing client combat VFX in `Assets/CombatVfx` (`VfxPool`, `SkillVfx`, `ProjectileVfx`) and pool every spawned part through `VfxPool`. Don't use `Debris` or per-hit `TweenService`.
- **Budget per equipped weapon** (expect 5 heroes plus enemies on screen):
  - Idle particles per second: band 1 ≤ 5, band 2 ≤ 10, band 3 ≤ 20, bands 4–5 ≤ 40.
  - At most 1 light (`Shadows = false`), 2 trails and 4 beams.
  - Textures ≤ 256², flipbooks ≤ 4×4.
  - Respect `VfxPool.CULL_DISTANCE`. Turn idle emitters off when the hero is benched, in `COMA` or far from the camera.
  - At low graphics quality, drop to the band's light and trail only.
- **Readability.** Weapon VFX must never hide enemy telegraphs, damage numbers or teammates. Keep auras faint (Transparency ≥ 0.6) and close to the weapon. Rarity colour is the main hue; the element is the accent.
- **Driven by the description.** Take the element and flavour from the `Description`: "blackened tips" becomes smoky wisps, "crystal" refracting shards, "runic" glowing glyphs. Standard and Enhanced siblings share an effect family, and Enhanced gets the denser or brighter version.
- **Per-type accents:**
  - Sword: a swing arc trail, and a pulse on the shield boss when blocking.
  - Daggers: twin crossing trails.
  - Bow: an arrow `Trail` and an impact pop.
  - Axe: ground-crack sparks on heavy swings.
  - Staff: an orb aura and a cast flare at `VfxCore`.
  - Tome: floating pages or a glyph ring.

## Blender workflow

1. **Units & axes.** Scene unit scale so 1 Blender unit = 1 Roblox stud (or export with a consistent ×0.01/×100 fix and verify). Blender is Z-up, Roblox is Y-up: model with the handle along Blender **+Z** (→ Roblox +Y) and decide the export axis once (FBX: Forward −Z / Up Y, or OBJ with "Y up"), then verify on the first weapon by importing it into Studio and checking it against the reference prefab before doing the rest.
2. **Pivot / origin.** Put each object's origin at the exact **grip point** (where the hand closes). That makes the `Grip` attachment sit at `(0,0,0)` (or the documented offset) on `Handle`, and keeps rotations predictable.
3. **One object per semantic part**, named as in rule 7, all parented to an empty named after the prefab. Sub-assemblies (`OffhandShield`, `LeftDagger`) get their own empty and their own origin at their mount/grip point.
4. **Topology & budget** (per prefab, all parts combined): Common–Rare ≈ 1.5k tris, Epic–Legendary ≈ 3k, top tiers ≤ 5k; ≤ 10 MeshParts per assembly (fewer is better — each MeshPart is a draw call and five heroes carry these). Roblox's per-mesh limit is 20k tris; stay far below. Apply all modifiers, apply scale/rotation (Ctrl+A), recalc normals outward, no n-gons on curved surfaces, bevel hard edges for stylized highlights.
5. **UVs & textures.** One UV set, non-overlapping, packed. Prefer one shared 512² or 1024² atlas per weapon (hand-painted albedo; optional roughness/metal if using SurfaceAppearance). Leave glowing parts (Orb, Crystal, Rune, Blade at high rarity) as separate untextured or white-textured MeshParts so `Style` can recolour them to Neon.
6. **Export** each prefab as FBX (or OBJ per part), filename = prefab name. Import into Studio with the 3D Importer, keeping parts separate; then in Studio (or via the Studio MCP `execute_luau`): build the `Model`, set `PrimaryPart = Handle`, add the `Grip` / `OffhandGrip` / `ShieldMount` attachments with the exact CFrames above, add `WeldConstraint`s from every part to its assembly's PrimaryPart, set the part properties from rule 6, and parent the model to `ReplicatedStorage.Assets.Weapons`.
7. **Persist it.** Weapons are rebuilt from code by `WeaponModelBuilder.EnsureWeapons()` on server start, so a hand-placed Studio model will be overwritten or missing on the next Rojo sync. Pick one and state it: (a) save the prefab as an `.rbxm` in `src/ReplicatedStorage/Assets/Weapons/` (that folder is Rojo-mapped) and make `EnsureWeapons` skip builds whose prefab already exists, or (b) upload meshes, record their `MeshId` / `TextureID` asset IDs, and add a builder function that creates `MeshPart`s from those IDs with the same attachments and welds. Option (b) matches the codebase's "everything is code" style; prefer it.

## Per-artifact design brief (do this for every seed)

For each seed, write a short brief **before** modelling:

```
TemplateId:      art_xxx
DisplayName:     ...
Type / Variant:  SWORD_SHIELD / Enhanced
Rarity:          tier N (name), colour #HEX
Description:     (quote it)
Silhouette:      1 sentence — the shape a player recognises at 40 studs
Materials:       metal / wood / leather / crystal and their colours
Glow parts:      which named parts become Neon
VFX:             band, element, idle aura, attack accent, colours, Vfx* attachments
Grip & length:   grip offset, overall length vs. the generic prefab (±%)
Standard↔Enhanced: what the Enhanced version adds
Part list:       Handle, Blade, BladeTip, Crossguard, Pommel, ... (≤ 10)
Tri budget:      ...
```

Translate every concrete noun in the description into geometry (e.g. "fluted crossguard", "corner-banded heater shield", "curved knuckle rings", "pick spike butt", "waxed hemp string"). If a description is vague, invent details consistent with its tier and say what you invented.

## Verification checklist (per weapon)

- [ ] Model named correctly, `PrimaryPart = Handle`, sub-assemblies named `OffhandShield` / `LeftDagger` with their own PrimaryPart.
- [ ] `Grip` (and `OffhandGrip` / `ShieldMount`) exist on the right PrimaryPart with the right offset and rotation; Up = toward head, Look = working direction.
- [ ] Every part welded to its assembly's PrimaryPart; no welds crossing between assemblies; no Motor6D, no anchored parts.
- [ ] Equipped in Studio on a hero of the right archetype: weapon sits in the palm, edge faces forward, nothing clips through the forearm in idle / basic / special / skill animations; bow arrow sits on the string; shield faces outward.
- [ ] At rarity ≥ 5 (Exalted+) the right parts glow; at low rarity nothing glows unintentionally.
- [ ] VFX ladder: lined up side by side, each rarity from Common to Mythical looks richer than the one before. Common has no effects, and every `Vfx*` attachment exists.
- [ ] VFX stays within budget. Idle emitters stop when the hero is benched or in `COMA`, nothing hides enemy telegraphs, and the low-quality fallback works.
- [ ] Attack accents fire on Basic, Special and Skill. After 2 minutes of combat, the Workspace instance count shows no leaked parts.
- [ ] Tri count and MeshPart count within budget.
- [ ] Generic fallback prefabs still exist and still work for any artifact without a custom model.
- [ ] `pwsh tests/run.ps1` passes; `docs/GAME_DESIGN.MD` updated if anything player-visible about artifacts changed.

## Output format

For each batch, deliver:
1. The design briefs.
2. The Blender Python (`bpy`) script or step list used to build each model.
3. The Luau changes: new builder functions or `.rbxm` paths, `ModelAssetId` updates in `ArtifactCatalog.Seeds`, any `Style` additions.
4. The VFX config table, the `WeaponVfx` code, emitter/trail/beam settings for each band, and a list of the textures needed, described well enough to generate or upload.
5. A screenshot or description of each weapon equipped in Studio, both idle and mid-swing, plus the checklist results.
6. Open questions or assumptions (anything in a description you had to interpret).

Do not change `HeroSockets`, `HeroRigSpec`, hero animations, or combat stats. VFX is cosmetic only and never changes hitboxes or timings. If the contract above makes a design impossible, stop and explain rather than working around it.
