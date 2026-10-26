# Implementation Plan: Hero Rig Rebuild (R15 from Scratch)

## Goal

Throw away the current hero modeling stack and rebuild all 12 heroes on one code-authored R15 rig standard that:

1. **Animates predictably.** Every joint rests at identity, uses the same axis convention, and nothing is baked into `C0`. One pose works the same on every hero.
2. **Fits the artifact system by contract.** Hands and weapons meet at named, oriented attachments. Equipping is a single `Weld` between two attachments: no per-weapon magic matrices and no `WeldConstraint` offset capture.
3. **Lives in the repo.** Rigs, costumes, grips and animation clips are Luau source synced by Rojo. Nothing hero-related is authored only in Studio.

Out of scope: hero stats, kits, gacha and the server combat simulation. The tower enemy rigs (`TowerEnemyRigs`, `TowerEnemyClips`) also stay as they are; they are the precedent this plan copies.

---

## Why reset: problems in the current stack

| Problem | Where | Effect |
| --- | --- | --- |
| Two incompatible sources per hero | `HeroModelBuilder.BuildX()` vs the Studio-only `ServerStorage.ModelViewer.JennaPreview` | Jenna's live rig is a clone of a hand-made Studio model with baked aiming rotations in `Motor6D.C0`. The builder now patches it at runtime (`normalizeR15Joints`, `JENNA_IDLE_OFFSETS`). |
| Unsafe Studio asset | `JennaPreview.RightUpperArm.CrystalPauldron.LightConfig` | Obfuscated external module loader (P1 in `docs/reviews/2026-10-21/CURRENT_SYSTEMS_REVIEW.md`). `EnsureHeroes` strips it on clone, but the source model still carries it. |
| Rigs from `CreateHumanoidModelFromDescription` | `createBaseR15` | Part sizes and attachment positions come from Roblox's default bundle, not from us. The Humanoid is created and then destroyed. |
| Cosmetics cross joints | e.g. Jenna's `LeatherCuff` is welded to the forearm but wraps the hand | Any wrist rotation visibly twists the hand out of its glove. |
| Rigs carry gear | Aaron's sculpted `KiteShield`; a baked `EquippedWeapon` on JennaPreview | `EquipWeapon` needs special cases (skip the shield "if the rig already sculpts one"). |
| Weapon grips are magic numbers | `bowGripOffset` matrix, `CFrame.Angles(-90,0,0)` / `(180,0,0)` per type in `ArtPackVisuals.EquipWeapon` | No shared definition of "handle up" or "pointing forward", so poses are tuned by trial and error against each weapon. |
| `WeldConstraint` for equipment | `EquipWeapon`, every costume piece | It captures whatever offset exists when it activates. A posed hand produced a bow floating 2.5 studs away. |
| Joint sign convention undocumented | `ArtPackVisuals.Animate` | Plan angles and the old `hasBow` branch use the wrong signs (`-X` was assumed to raise the arm; on this rig `+X` does). |
| Poses keyed by hero id | `isMarksman = (assetId == "hero_jenna")` | Astrea, the other bow user, falls through to a different branch; every new hero needs new code. |

---

## Target architecture

```text
ReplicatedStorage/Assets/HeroRig/           (new folder of ModuleScripts, Rojo-tracked; not
                                             Assets/Heroes, which holds the built templates)
  HeroRigSpec.luau        R15 skeleton: part sizes, joint positions, attachment table, axis convention
  HeroRigBuilder.luau     Builds a bare, neutral R15 rig from HeroRigSpec (+ body type)
  HeroCostumes.luau       Per-hero appearance data: colors, face, hair and costume pieces per bone
  HeroCostumeBuilder.luau Applies a costume to a bare rig (Weld per piece, one bone per piece)
  HeroRegistry.luau       EnsureHeroes(): builds all 12 templates into ReplicatedStorage.Assets.Heroes
  HeroSockets.luau        Equip/unequip: weapon attachment -> hand attachment welds, bow string wiring
  HeroClips.luau          Keyframed poses per weapon type and state (TowerEnemyClips format)
  HeroAnimator.luau       Client-side clip player: evaluates and blends clips into Motor6D.Transform

ReplicatedStorage/Assets/WeaponModelBuilder.luau   (kept; every prefab gains Grip attachments)
ReplicatedStorage/Assets/ArtPackVisuals.luau       (keeps props and mobs; hero code moves out)
```

Removed when the migration completes: `HeroModelBuilder.luau`, the hero branches of `ArtPackVisuals.Animate` and `ArtPackVisuals.EquipWeapon`, `normalizeR15Joints`, `JENNA_IDLE_OFFSETS`, and the Studio-only `ModelViewer.JennaPreview`.

### 1. Rig contract (`HeroRigSpec`)

- **Parts:** the 15 standard R15 parts plus `HumanoidRootPart`, all plain `Part`s built by our code with explicit sizes. No `Humanoid`; an `AnimationController` named `AnimController` keeps the "no server-side Humanoid" standard.
- **Body types:** `Slim`, `Standard` and `Heavy` change part sizes only. Joint attachment positions are derived from the sizes, so the skeleton stays consistent. **Hands are the same size on every body type**, so every grip fits every hero.
- **Joints:** 15 `Motor6D`s with standard names, parented to `Part1`. `C0` and `C1` equal the `*RigAttachment` CFrames, which are pure translations (no rotation). The rest pose is arms down, legs straight.
- **Ground contract:** `HumanoidRootPart` center sits 3.0 studs above the feet's soles. `EntityRenderer` and `ArtPackVisuals.Attach` already assume this.
- **Axis convention** (documented in the spec and enforced by tests):

  | Joint | Positive rotation means |
  | --- | --- |
  | Shoulder / hip `+X` | swing the limb forward |
  | Elbow `+X` | bend the forearm forward (flex) |
  | Knee `-X` | bend the shin backward (flex) |
  | Waist / neck `-X` | lean forward / look down |
  | Waist / neck `+Y` | turn left |
  | Left shoulder / hip `-Z`, right `+Z` | raise the limb outward (abduct) |

- **Named attachments** (positions from the spec):

  | Attachment | On | Purpose |
  | --- | --- | --- |
  | `RightGripAttachment`, `LeftGripAttachment` | hands | weapon grips (see socket contract) |
  | `DrawAttachment` | `RightHand` | bowstring draw point |
  | `ShieldMountAttachment` | `LeftLowerArm` | shield strapped to the forearm |
  | `BackSheathAttachment` | `UpperTorso` | stowed weapon (sleeping, labor, Hub idle) |
  | `HipSheathAttachment` | `LowerTorso` | stowed daggers, tome |
  | `HatAttachment`, `HairAttachment` | `Head` | hair and headwear |
  | `CarryAttachment` | `UpperTorso` | carried loot (replaces `HoldingAnimationController` arm overrides) |

- **Budget:** at most 60 parts per hero, including costume (6 players × 5 heroes = 30 rigs on screen in the Hub).

### 2. Costume contract (`HeroCostumes`)

- Each hero is **data**: body type, skin/hair/outfit colors, face texture, and a list of pieces `{ Bone, Shape, Size, Offset, Color, Material }`.
- **One bone per piece.** A piece is welded to exactly one body part with a `Weld` (explicit `C0`) and must fit inside that bone's segment. Gloves belong to the hand, cuffs to the forearm, and a cuff may not overlap the hand. The builder checks this and warns about any piece whose bounds cross a joint plane.
- Hair, capes and long coats that must cross joints are split into one piece per bone (a cape gets an upper piece on `UpperTorso` and a lower piece on `LowerTorso`).
- **No gear on rigs.** Weapons and shields only arrive through `HeroSockets`. Aaron's sculpted kite shield becomes his `SWORD_SHIELD` prefab's look, or a cosmetic override on the prefab, not part of his body.
- **No scripts, decals with external IDs, or anything not built by our code.** The only asset IDs allowed are face textures listed in `HeroCostumes`.

### 3. Socket contract (`HeroSockets` + `WeaponModelBuilder`)

Every weapon prefab gets a `Grip` attachment (and `OffhandGrip` / `ShieldMount` / `Nock` where relevant) on its `Handle`. Both sides follow one orientation rule:

- **`UpVector` runs along the handle toward the weapon's head:** blade tip, bow upper limb, staff orb, axe head, tome spine top.
- **`LookVector` is the weapon's working direction:** the arrow's flight, the blade edge, the staff's casting direction.
- Hand grips use the same rule in hand space: up = along the knuckle line toward the thumb (hand `-Z`), look = down the forearm line (hand `-Y`). This is the natural grip measured in the Jenna idle work: with the arm raised forward, a bow stands vertical and the arrow points at the target.

Equipping is always:

```lua
weld.Part0 = hand
weld.Part1 = weapon.Handle
weld.C0 = handGrip.CFrame   -- e.g. RightGripAttachment
weld.C1 = weaponGrip.CFrame -- the prefab's Grip
```

| Weapon type | Main `Grip` → | Second socket |
| --- | --- | --- |
| `BOW` | `LeftGripAttachment` | string `Beam`s from limb tips to `Nock` at rest; to `RightHand.DrawAttachment` while drawing |
| `SWORD_SHIELD` | `RightGripAttachment` | shield `ShieldMount` → `LeftLowerArm.ShieldMountAttachment` |
| `DAGGERS` | `RightGripAttachment` | left dagger `Grip` → `LeftGripAttachment`; optional `ReverseGrip` attribute rotates 180° about look |
| `AXE` | `RightGripAttachment` | optional `OffhandGrip` for a two-handed swing pose |
| `STAFF` | `RightGripAttachment` | none |
| `TOME` | `LeftGripAttachment` | none |

Rarity tinting and the crystal/recurve color overrides stay, moved into `WeaponModelBuilder` so `HeroSockets` only welds.

### 4. Animation contract (`HeroClips` + `HeroAnimator`)

- Clips use the `TowerEnemyClips` format: keyframes in normalized time, each a table of joint name → `CFrame`, written with the axis convention above. They are native source, with no uploaded animation IDs (no asset-permission risk).
- **Clips are keyed by weapon type, not hero.** States per type: `Idle`, `Move`, `AttackBasic`, `AttackSpecial`, `AttackSkill`, `Hit`, `Coma`, plus shared `Carry`, `Sleep` and `Labor`. A hero may override any clip by id (`HeroClips.Overrides.hero_jenna.Idle`), which is how hero signatures like Jenna's Wind-Scout stance stay possible.
- `HeroAnimator.Step(node, dt, now)` picks the state from the node (moving, `StateEnum`, the attack tier stamped by the `HERO_ATTACK` event from the animations plan, carrying, coma) and cross-fades between clips (0.12 s default). It masks upper and lower body so `Move` legs combine with weapon-arm clips.
- Plot workers sleeping in beds use the `Sleep` clip on an upright-built rig, replacing `PlotManager`'s rotated-ground + 0.72 scale hack.
- Static previews (`HeroCard` viewports, the model viewer) pose the template by applying a clip's first keyframe directly to `Motor6D.Transform`. They never edit `C0`.

---

## Phases

Each phase lands as its own PR off `main`. The game stays playable between phases because the old path is removed only in Phase 6.

### Phase 0: Quarantine and decide (small, first)

- **Studio action (needs user confirmation):** delete `CrystalPauldron.LightConfig` and its children from `ServerStorage.ModelViewer.JennaPreview` and from any saved `ReplicatedStorage.Assets.Heroes.hero_jenna`. Then publish.
- Settle the open decisions below.
- Park `feat/jenna-idle-stance`: its findings (natural grip, `Weld` over `WeldConstraint`, sign convention) are folded into this plan, and its code is superseded.

**Done when:** no Studio-only hero model contains a script, and the decisions are recorded in this file.

#### Phase 0 results (2026-10-26)

- **Quarantine done in Studio** (not yet saved or published; the user saves and publishes the place):
  - Deleted `ServerStorage.ModelViewer.JennaPreview.RightUpperArm.CrystalPauldron.LightConfig` (Script) with its `Type` and `EasyConfiguration` (+ `Pose`) children.
  - Deleted the three flat copies in `ServerStorage.TowerRebuildPart2Recovery_20261021.Sources` (named `ReplicatedStorage.Assets.Heroes.hero_jenna.RightUpperArm.CrystalPauldron.LightConfig`, `...LightConfig.Type`, `...LightConfig.EasyConfigurati`).
  - A full-place scan afterwards finds nothing named `LightConfig` or `EasyConfiguration*`. The `CrystalPauldron` part itself (geometry only) remains.
- **Parked:** `feat/jenna-idle-stance` holds local commit `79b7661` (idle stance, Weld bow grip, tiered bow attacks, arrow VFX, `HERO_ATTACK`, `HeroAssetSetup` count fix). It is not pushed and not for merge.
- **Reference screenshots** of all 12 current heroes are in `docs/hero-rig-rebuild/reference/` (3 front groups, side lineup, Jenna close-up).
- **Measurements from the current rigs:**
  - `HumanoidRootPart` sits **3.19** studs above the soles, not 3.0. The new spec should pick one value and make `EntityRenderer` and `ArtPackVisuals.Attach` agree with it.
  - Part counts: Jenna 70; the other 11 heroes 19–30. Jenna is over the 60-part budget.
  - Most heroes still have Roblox's default black arms and stock face; only Jenna has a custom face and full costume. Phase 3 is a chance to give every hero arms and hands in their palette.
- **JennaPreview inventory** (54 costume pieces; everything but the mesh items below ports directly to Part data):
  - **Head (16):** `HairBase`, bangs ×4, `HairSide` ×2 with wedge tips, `HairTress` ×2 with wedge tips, `GoggleLens` ×2, `OpenHood`, `SteampunkGoggles`.
  - **UpperTorso (8):** `BackQuiver` + `QuiverGoldRim`, `CrossHarness`, `StrapBuckle`, `CapeStar` ×4, `StarryCape`.
  - **LowerTorso (15):** `UtilityBelt`, `BeltBuckle`, `LeatherPouch` ×2, `PotionVial` ×4 + `PotionCap` ×4, `CoatTailL/R` + `CoatHem` ×2.
  - **Arms (8):** `CrystalPauldron` + `PauldronCrystal_1..3` (right upper arm); `LeatherCuff` + `CuffGoldBand` per forearm.
  - **Legs (4):** `SkinGap` per upper leg, `BootGoldCuff` per lower leg.
  - **Joint-crossing pieces to split or resize:** `CoatTailL/R` (hang across the hips), `LeatherCuff` (overlaps the hand), and `StarryCape` (2.9 studs tall on `UpperTorso`, crossing the waist).
- **External mesh assets used by Jenna** (conflict with decision 1, Parts not meshes):

  | Piece | Asset |
  | --- | --- |
  | `OpenHood` | SpecialMesh `rbxassetid://76062497` |
  | `CrystalPauldron` | SpecialMesh `rbxassetid://4375709707` (came with the loader; likely a free model) |
  | `StarryCape` | MeshPart `rbxassetid://17190632448` + decal `rbxassetid://15158250787` |
  | `SteampunkGoggles` | MeshPart `rbxassetid://15021146916` |
  | face | decal `rbxassetid://800114796` |

  Plan for Phase 3: rebuild the hood, pauldron, cape and goggles from Parts/WedgeParts. Keep the face decal as the one allowed asset type, listed in `HeroCostumes`.
- **Tooling note:** a failed MCP call left a Studio undo recording open in the Edit DataModel. Since then, `execute_luau` in Edit mode runs code but reports "No recording in progress" instead of returning results. Play-mode DataModels are unaffected. Restarting Studio clears it.

### Phase 1: Skeleton (`HeroRigSpec`, `HeroRigBuilder`)

- Write the spec (sizes per body type, joint and attachment table, axis convention) and a builder that produces a bare neutral rig.
- Add `tests/studio-hero-rigs.luau` (run through Studio MCP), which builds each body type and asserts:
  - All 15 motors exist with identity-rotation `C0`/`C1`.
  - Each named attachment exists.
  - The HRP-to-sole distance is 3.0.
  - Forward kinematics: `+X` on `LeftShoulder` moves `LeftHand` toward root `-Z`, and `-X` on `LeftKnee` moves `LeftFoot` toward `+Z`.
- Add a pure-Luau spec test (`tests/hero-rig.spec.luau`) for the data: every joint has an attachment pair, and hands are equal across body types.

**Done when:** both tests pass, and a bare rig of each body type renders upright in Studio.

#### Phase 1 results (2026-10-26)

- **Modules** live in `src/ReplicatedStorage/Assets/HeroRig/`, not `Assets/Heroes/`, because `ReplicatedStorage.Assets.Heroes` is the runtime folder of built templates that `HeroCard` and `ArtPackVisuals.Template` read:
  - `HeroRigSpec.luau`: pure data and math with plain number arrays (no `Vector3`/`CFrame`), so it loads in the offline runner. It holds part names, joints, shared heights, the three body types, `HAND_SIZE`, `GRIP_ROTATION`, `AxisChecks`, and `Layout(bodyType)`.
  - `HeroRigBuilder.luau`: `Build({ Name, BodyType, SkinColor, Pivot, AnchorRoot })`, `GetJoints(model)`, `ResetPose(model)`. It builds no Humanoid and no Animator (an Animator would overwrite `Motor6D.Transform`).
- **Skeleton numbers:** root 3.0 above the soles (`GROUND_OFFSET`); total height 5.9. Heights are shared by all body types; Slim, Standard and Heavy change torso width and depth (1.8/2.0/2.3 × 0.9/1.0/1.2) and limb thickness (0.85/1.0/1.15). Hands are 1.0 × 0.3 × 1.0 on every type. Shoulders pivot on the arm's own axis beside the torso.
- **Tests:**
  - `tests/hero-rig.spec.luau` (in `tests/run.ps1`): 729 checks pass. It covers structure and build order, ground contract, pivots on parts, rig attachments as pure translations on the pivots, required sockets, grips inside the fist, left/right symmetry, limb clearance, equal hands, the axis convention via rotation math, and rejection of unknown body types.
  - `tests/studio-hero-rigs.luau` (Server DataModel of a playtest): 315 checks pass on all three body types. It covers structure, identity-rotation `C0`/`C1`, attachments meeting at joints, the ground contract, every `AxisChecks` rule against the live engine, and grip orientation (at rest it looks down the arm with up forward; with the shoulder at +90° it looks forward with up vertical).
- **How the Studio test ran:** Rojo could not sync, because another Team Create user holds the Rojo session lock. The modules were injected as temporary ModuleScripts into the playtest's Server DataModel from the repo files (comments stripped, code identical), and discarded when the playtest stopped. The shared place was not changed.
- **Screenshot:** `docs/hero-rig-rebuild/phase-1/body-types-slim-standard-heavy.jpg`.

### Phase 2: Sockets and weapon prefabs

- Add `Grip` / `OffhandGrip` / `ShieldMount` / `Nock` attachments to all 6 prefabs in `WeaponModelBuilder`, oriented by the socket rule.
- Write `HeroSockets.Equip(rig, weaponModel, weaponType)` and `Unequip`.
- Extend `studio-hero-rigs.luau`:
  - For each weapon type on a bare rig, the handle is within 0.05 studs of the hand grip.
  - In a reference "arm forward" pose, the bow stave is within 10° of vertical and the arrow points within 10° of root `-Z`.
  - The sword points up along the forearm, and the shield sits on the forearm's outer face.
- Fix `HeroAssetSetup`'s `pairs` error on `EnsureWeapons()` (it returns an Instance) while in this area.

**Done when:** every weapon type sits correctly on a bare rig in the reference poses. Screenshot each.

#### Phase 2 results (2026-10-26)

- **Weapon sockets** (`WeaponModelBuilder.luau`; geometry untouched except the bow). Every rule is `UpVector` toward the weapon's head and `LookVector` = working direction:

  | Prefab | Attachments on the primary part |
  | --- | --- |
  | `weapon_bow` | `Grip` (handle center; up = upper limb, look = arrow flight -Z), `Nock`, `TipUpper`, `TipLower` |
  | `weapon_sword` / `weapon_sword_shield` | `Grip` (look = edge, +X); the shield's `HandleS` gets `ShieldMount` on the back of the face plate (look out through the face) |
  | `weapon_daggers` | `Grip` on `Handle` and on `LeftDagger.HandleL` |
  | `weapon_axe` | `Grip` near the butt of the haft, `OffhandGrip` higher up |
  | `weapon_staff` | `Grip` below center (look = crown face, -Z) |
  | `weapon_tome` | `Grip` on the spine (look = front cover, +Z) |

- **Bow rebuilt from code only:**
  - `BuildBow` no longer clones a Studio-saved or Jenna-baked bow. There was none in the place, so the live bow was already the code fallback.
  - The limbs now curve back so their tips meet the string, and `alignHunterArrow` nocks the arrow on the string pointing -Z. It used to point along +X, sideways out of the bow.
  - The live game still equips through `ArtPackVisuals.EquipWeapon`, which re-aligns the arrow with its own legacy math. So in-game the bow only changes by its limb shape until Phase 5.
- **`HeroSockets.luau`** (`Assets/HeroRig/`):
  - `PREFABS` and `SOCKETS` per weapon type are plain data, checked offline.
  - `Equip(rig, weapon, weaponType)` places each assembly and joins it with one `Weld` (`C0` = rig attachment, `C1` = weapon attachment). It honours a `ReverseGrip` attribute on daggers.
  - `Unequip(rig)` removes the weapon.
  - The shield mounts to `LeftLowerArm.ShieldMountAttachment` (decision 3).
- **`EnsureWeapons` return:** it returns `(Folder, table)`; `ArtPackVisuals` relies on the folder coming first. The annotation is corrected; the `HeroAssetSetup` count fix was already on `main`.
- **What "rest" looks like under the grip rule:** with the arm hanging, a held weapon's head points forward (thumb side) and its working direction points down the arm. With the forearm raised forward, blades point up. With the whole arm raised forward, the bow stands vertical and the arrow points at the target. Clips in Phase 4 start from this.
- **Tests:**
  - `hero-rig.spec.luau` now has 807 checks. Every catalog weapon type has sockets and a prefab, and every socket lands on a rig attachment on every body type.
  - `studio-hero-rigs.luau` now has 360 checks, all passing in a playtest. Per weapon type it checks attachments coincide (< 0.05 studs, < 2°) and no weapon parts are anchored. It also checks:
    - **Bow:** with the arm raised, the stave is vertical, the arrow points forward, and the nock sits on the string.
    - **Sword:** the blade points up with the forearm raised.
    - **Shield:** it faces outward, stands vertical, and sits outside the forearm.
    - **Daggers:** reverse grip points them backward, and re-equipping replaces the previous weapon.
    - **Axe:** it is held near the butt.
    - **Unequip:** it clears the weapon.
- **How the Studio test ran:** the Rojo lock was still held by another Team Create user. The playtest server fetched the five changed files from a temporary 127.0.0.1-only file server and loaded them as play-only ModuleScripts; the shared place was not changed.
- **Screenshots:** `docs/hero-rig-rebuild/phase-2/`.

### Phase 3: Costumes for all 12 heroes

- Port each hero's look from `HeroModelBuilder.BuildX` into `HeroCostumes` data. Keep colors and silhouettes; split cross-joint pieces per bone; drop any gear.
- Rebuild Jenna from the builder, not from JennaPreview. Her hair (`attachJennaHair`), pauldron (geometry only, no script) and cuffs become data pieces.
- `HeroRegistry.EnsureHeroes()` builds all 12 into `ReplicatedStorage.Assets.Heroes`, replacing the existing templates. `HeroAssetSetup` calls it.
- Add a costume lint to the Studio test: each piece is welded by a `Weld` to one bone, no bounds cross a joint plane, the hero is within budget, and there are no `LuaSourceContainer`s.

**Done when:** a side-by-side screenshot sheet of all 12 (front and side, bare and armed) matches the old looks, and the lint passes.

#### Phase 3 results (2026-10-26)

- **New modules** in `Assets/HeroRig/`:
  - `HeroCostumeMath.luau`: pure piece resolution (`RelativeTo` chains, horizontal scaling from the Standard body to the hero's body type) and an exact oriented-box overlap test.
  - `HeroCostumes.luau`: all 12 heroes as data (body type, body colours for every part, face, pieces), plus `BodyColors` and `Lint`.
  - `HeroCostumeBuilder.luau`: builds Parts/WedgeParts, each with one explicit `Weld` to its bone.
  - `HeroRegistry.luau`: `Build(heroId)` and `EnsureHeroes()`, which always rebuilds `ReplicatedStorage.Assets.Heroes` from code.
- **`HeroAssetSetup`** now calls `HeroRegistry.EnsureHeroes()`. `HeroModelBuilder.luau` is no longer called and is deleted in Phase 6. JennaPreview is no longer read by any code.
- **Body types:**
  - Standard: Han, Catio, Morrigan, Archon, Solaris.
  - Slim: Jenna, Velkist, Eolka, Valeria, Astrea.
  - Heavy: Aaron, Ignis.
- **Arms:** every hero now has sleeve and hand colours in their palette (no more default black arms).
- **Porting changes from `HeroModelBuilder`:**
  - **Gear removed from bodies:** Aaron's kite shield (his `SWORD_SHIELD` shield replaces it), Velkist's hand dagger, Eolka's and Valeria's staffs and Eolka's hip tome, Jenna's and Astrea's arm-welded bows, Han's katana and Catio's back pick.
  - **Moved by the lint:** Catio's hip pouches (they sat where the hanging forearms are) and Velkist's thigh sheath (same). Archon's and Astrea's wings went higher and further back, out of the arm zone.
  - **Loose (cloth and hair that may clip):** skirts and trims (Eolka, Valeria), capes (Morrigan, Astrea, Jenna's lower cape and coat tails), mantles and scarf (Archon, Solaris, Velkist), braids (Eolka), Jenna's long tresses, and Han's belt knot.
- **Jenna** was rebuilt from the Phase 0 inventory with 44 pieces (60 parts, at the budget):
  - **Hair:** the exact `attachJennaHair` offsets.
  - **Catalogue meshes recreated from Parts:** a 4-panel hood, goggles with a brass band and cylinder lenses, a two-piece starry cape, and a crystal pauldron.
  - **Cuffs:** they now sit fully on the forearm, clear of the hand.
  - **Trimmed to meet the budget:** potion caps, two potions, one pouch, the strap buckle, side hair tips, coat hems and two cape stars.
- **Lint:** `HeroCostumes.Lint` rejects unknown bones, shapes and materials, bad `RelativeTo`, non-`rbxassetid` faces, more than 60 parts, and any non-Loose piece whose oriented box overlaps another bone (shrunk by 0.1 studs, at most half of each dimension). The first sampled version missed a cuff straddling the thin hand; the exact separating-axis test catches it.
- **Tests:**
  - `hero-rig.spec.luau`: 1,027 checks. Every costume lints clean and matches `HeroCatalog`, body colours cover every part, and the lint catches the hand-cuff case, accepts it when marked Loose, and reports a bad `RelativeTo`.
  - `studio-hero-rigs.luau`: 564 checks, all passing in a playtest. Per hero it checks the budget, one Part per piece, no meshes or scripts, at most the face decal, and one `Weld` per piece to its parent bone. In a mixed pose (shoulder, elbow, neck, knee), pieces stay attached with drift under 0.001 studs. It also builds an armed copy of every hero through `HeroSockets`.
- **Live-path check (playtest only):** after `HeroRegistry.EnsureHeroes()` ran on the playtest server, `EntityRenderer` rebuilt the squad (Jenna, Han) from the new templates. The legacy `ArtPackVisuals.EquipWeapon` still put the bow in Jenna's left hand (0.05 studs) and the daggers in Han's right hand. Roots sit 3.0 above the soles, matching the renderer's assumption. Output showed no new errors. Until Phase 4–5, heroes use the legacy procedural poses and legacy grips on the new rigs, so weapon angles look generic (for example Jenna's bow is held flat at the hip).
- **How the Studio checks ran:** this branch was not synced into the shared Team Create place, because Rojo would push unmerged code that changes the live hero models. The checks ran on files loaded into playtests from a temporary 127.0.0.1-only file server.
- **Screenshots:** `docs/hero-rig-rebuild/phase-3/` (three front groups, Jenna front and back, armed row).

### Phase 4: Animator and clips

- Write `HeroAnimator` and `HeroClips` with all states for all 6 weapon types, plus the shared states.
- Re-author Jenna's Wind-Scout idle as `Overrides.hero_jenna.Idle` on the new rig.
- The animations plan's items 2 and 3 (attack tiers, arrow projectiles) target this animator instead of `ArtPackVisuals.Animate`; that plan gets a short pointer.
- Add a pure-Luau clip test: every weapon type has every required state, keyframe times are sorted from 0 to 1, and every joint name is valid.

**Done when:** in a playtest, each weapon type idles, walks and runs its three attack tiers without limbs clipping the torso or weapons crossing the face. Check with screenshots and the FK checks from Phase 2.

#### Phase 4 results (2026-10-26)

- **`HeroClips.luau`** (`Assets/HeroRig/`), pure data:
  - **Per weapon type** (`UNARMED`, `BOW`, `SWORD_SHIELD`, `DAGGERS`, `AXE`, `STAFF`, `TOME`): `Idle`, `Move`, `AttackBasic`, `AttackSpecial`, `AttackSkill`.
  - **Shared:** `Hit`, `Coma` (kneeling slump), `Carry` (loot overhead), `Sleep` (lying on the back via the `Root` joint) and `Labor` (hammering).
  - **Override:** `hero_jenna.Idle`, the Wind-Scout stance.
  - **`Get(heroId, weaponType, state)`** resolves override → weapon type → shared → `UNARMED`.
  - **Generators:** idles come from `breathe(stance)`, and walks from `walk(carry)`, which swings the legs and bobs the root while keeping the weapon carry.
- **`HeroAnimator.luau`:**
  - `new(rig, {HeroId?, WeaponType?})` reads `HeroId` and `EquippedWeaponType` from the rig by default.
  - `SetLocomotion` and `SetWeaponType` change the looping clip underneath.
  - `PlayAction(state, duration?)` plays one action on top, rescaled to the given duration (the attack interval) with 0.08 s fades. While moving, actions drive only the upper body.
  - `Step(dt)` smooths `Motor6D.Transform` writes; `Evaluate`, `Sample` and `ApplyPose` serve static previews and tests.
- **Authoring with the grip rule:** an arm's shoulder pitch plus elbow pitch sets the weapon's tilt from "head forward", so 90° stands a sword or staff upright. The bow aim keeps the archer's body turn in the waist. A shoulder yaw after the 90° pitch rolled the bow 18° off vertical; the Studio test caught it, and the yaw was removed.
- **Tests:**
  - `hero-rig.spec.luau`: 10,914 checks. Every weapon type has every state; keys are sorted 0..1; joint names are valid; rotations are within 180°. Loops and actions end on their starting pose. Knees never bend forward and elbows never hyperextend. Overrides point at real heroes, `Get` fallbacks are correct, and every catalog weapon type has clips.
  - `studio-hero-rigs.luau`: 677 checks, all passing in a playtest. For each weapon type on its showcase hero (Han unarmed and daggers, Jenna bow, Aaron sword and shield, Catio axe, Eolka staff, Valeria tome), every state is sampled at 11 frames. The weapon never touches the head, and the hands never enter the torso. At full draw the bow is vertical with the arrow forward. The animator reads the rig's attributes, starts on Jenna's override, keeps the legs walking under an attack while moving, clears finished actions, lowers the body in `Coma`, and rejects action states as locomotion.
- **Screenshots** (`docs/hero-rig-rebuild/phase-4/`): Jenna and Aaron posed in each state. `Motor6D.Transform` does not replicate, so previews and the live renderer must pose rigs on the client. Phase 5 runs `HeroAnimator` in `EntityRenderer`.
- **Not wired into the game yet:** `EntityRenderer` still calls `ArtPackVisuals.Animate`. Phase 5 switches heroes to `HeroAnimator`, `HeroSockets` and `HeroRegistry`, and drives `PlayAction` from attack events (the animations plan's `HERO_ATTACK` tiers).

### Phase 5: Migrate consumers

- `EntityRenderer`: switch `ArtPackVisuals.Attach/EquipWeapon/UnequipWeapon/Animate` for heroes to `HeroRegistry`, `HeroSockets` and `HeroAnimator`. Mobs and props keep using `ArtPackVisuals`.
- `PlotManager.createWorkerAvatarPart`: clone the template upright and play `Sleep` / `Labor` (server-side static pose via `Transform` of the first keyframe).
- `HeroCard.Portrait`: pose the clone with the `Idle` first keyframe.
- `HoldingAnimationController`: use the `Carry` clip and `CarryAttachment` for hero rigs.
- `AdventurerPatrolController`: verify; it reads `HeroCatalog` and should need no change.

**Done when:** Hub, Fortress plot (beds, facility workers), the tower and the hero cards all show the new rigs. A multiplayer playtest with 2 clients shows no errors.

#### Phase 5 results (2026-10-26)

Skills consulted: `roblox-characters-animation`, `roblox-performance`, `roblox-networking`.

- **`EntityRenderer`:**
  - Heroes whose rig carries `HeroRigVersion` equip through the new `HeroLoadout` and animate through a per-node `HeroAnimator`, created once and cached on the node. Locomotion is `Coma` when the state is 4, `Move` while interpolating towards a new position, otherwise `Idle`.
  - Other entities, and any hero without a new rig, keep the legacy `ArtPackVisuals` path.
  - Hero root height uses `HeroRigSpec.GROUND_OFFSET` (3.0), replacing the old 3.2.
  - The per-frame step carries a `HeroAnimator.Step` MicroProfiler label.
- **Attack tiers:** `CombatSimulation` broadcasts `HERO_ATTACK` on the existing unreliable `CombatVFX` remote when a hero's attack fires. The payload is `(context, "HERO_ATTACK", position, NetId, tier 1..3, interval ms)`, floor-scoped through `BroadcastAt`.
  - Clients call `PlayAction(AttackBasic|AttackSpecial|AttackSkill, interval)`, clamped to 0.35–1.2 s.
  - Legacy rigs get the `AttackAnimTier`/`AttackAnimStartClock`/`AttackAnimDuration` fields that `ArtPackVisuals.Animate` already read but nothing set.
  - It is cosmetic, so a dropped packet only skips one swing.
- **`HeroLoadout.luau`** (new) resolves the prefab with the pure `HeroSockets.ResolvePrefab` (the artifact's own type wins), clones it, styles it and sockets it, and sets the entity's `EquippedArtifactId`/`Type` attributes.
  - Weapon styling (crystal greatbow, recurve, rarity ≥ 14 glow) moved into `WeaponModelBuilder.Style`, which `ArtPackVisuals.EquipWeapon` now calls too. Behaviour is unchanged.
- **`HeroAnimator.ApplyStaticPose`:** poses anchored clones by writing part CFrames down the joint chain, then moving welded pieces. `ViewportFrame`s never simulate joints. `HeroCard.Portrait` uses it to show each hero's `Idle` first frame (Jenna's signature stance).
- **`PlotManager`:**
  - Infirmary workers' rig root is now anchored. Hero templates are unanchored assemblies, so before this the cloned worker was held by nothing and fell.
  - The sleeping pose stays as the server laying the whole model flat. A server-side `Sleep` clip would not show, because `Motor6D.Transform` does not replicate; clients would need their own animator for plot workers, which is not worth it for a static bed pose.
- **Not changed:**
  - `HoldingAnimationController` animates the player's own avatar (Master), not heroes.
  - `AdventurerPatrolController` reads `HeroCatalog` only.
- **Tests:**
  - `hero-rig.spec.luau`: 10,945 checks. Every catalog artifact resolves to a built prefab of its own type; type-only, empty and unknown inputs resolve correctly.
  - `studio-hero-rigs.luau`: 677 checks still pass.
- **Live check (playtest only):**
  - **Swap:** this branch was not synced into the shared place. The playtest server loaded the branch modules and rebuilt the templates, then the client disabled the running `EntityRenderer` and started the branch version.
  - **Results:** the squad (Jenna, Han) rebuilt with weapons socketed by `HeroSockets` (`HeroSocket_Grip` welds), and Jenna's joints matched her signature idle exactly. With `HERO_ATTACK` events fired at the client's view context, Jenna's bow arm peaked at 145° (Skill sky aim) and Han's dagger arm at 130° (Special cross-slash).
  - **Hero cards:** a `ViewportFrame` clone posed by `ApplyStaticPose` moved Jenna's hand into the idle carry, with costume pieces following.
  - **Output:** no errors from the new code. The only errors came from a test command, which `require`s its own copy of `TowerFloorService`, a copy that has no rooms.
- **Not verified:**
  - The server's `HERO_ATTACK` broadcast inside real combat (it is compile-checked; the client side was driven by direct fires).
  - The plot worker anchor (no infirmary workers in the test profile).
  - A 2-client playtest. Studio MCP only starts single-client Play.
  - Run all three in Studio after merge with Rojo synced.
- **Screenshot:** `docs/hero-rig-rebuild/phase-5/live-squad-attacking.jpg`.
- **Possible follow-ups:**
  - `IKControl` for the bow draw hand (to the string) and foot planting during crouches; a shared `Hit` reaction keyed to incoming damage on a hero.

### Phase 6: Remove the old stack and update docs

- Delete `HeroModelBuilder.luau`, the hero branches in `ArtPackVisuals`, `normalizeR15Joints`, the `KiteShield` special case and the `starter_iron_vanguard` alias, if unused.
- **Studio action (needs user confirmation):** delete `ServerStorage.ModelViewer.JennaPreview`, and replace the model viewer with a script that builds previews from `HeroRegistry`.
- Update docs:
  - `GAME_DESIGN.MD` §7.5 (socket points and the shield on the forearm).
  - `technical_architecture.md` (asset layout, rig standard).
  - `CLAUDE.md` layout section (new `Assets/Heroes/` modules).

**Done when:** `grep` finds no references to the removed modules, `pwsh tests/run.ps1` and the Studio rig test pass, and docs match the code.

#### Phase 6 results (2026-10-26)

- **Removed:**
  - `HeroModelBuilder.luau`, together with `normalizeR15Joints`, `JENNA_IDLE_OFFSETS`, `attachJennaHair` and the JennaPreview cloning.
  - From `ArtPackVisuals`:
    - **`Animate`'s hero code:** Jenna and bow branches, attack-tier poses, the Wind-Scout stance and nocked-arrow handling. `Animate` keeps a small generic walk/strike/idle for non-hero art-pack rigs.
    - **`EquipWeapon` and `UnequipWeapon`,** including the `KiteShield` special case and the per-type grip matrices.
  - **`EntityRenderer`'s legacy fallbacks:** the `ArtPackVisuals` equip path and the `AttackAnim*` fields. Heroes without a `HeroRegistry` rig (template missing) now render unarmed.
- **Kept:** the `starter_iron_vanguard` → `hero_han` alias in `ArtPackVisuals`. No code uses it, but saved profiles may still carry that template id, so removing it risks unrendered heroes for no gain.
- **Model viewer:**
  - **New script:** `tests/studio-hero-model-viewer.luau` builds a posed lineup of all 12 heroes from `HeroRegistry`, optionally armed, with any clip state and time. Every part is anchored and posed with `HeroAnimator.ApplyStaticPose`, so it works in Edit mode too.
  - **Studio, with your confirmation:** deleted `ServerStorage.ModelViewer.JennaPreview`; the folder keeps its `DisplayPedestal`. No other `JennaPreview` exists in the place. Studio still needs to be saved and published.
- **Docs:**
  - `GAME_DESIGN.MD` §7.5 now describes socket attachments, the one-`Weld` equip, the shield on the forearm, and no gear on bodies.
  - `technical_architecture.md` has the asset tree, the setup and renderer roles, a corrected §6.1 weapon list (it predated one-weapon-per-archetype), socketing in §6.2, and a new §6.3 "Hero Rig Standard".
  - `CLAUDE.md` layout covers `Assets/HeroRig/`.
- **Checks:**
  - **References:** `grep` over `src/` finds no references to the removed code, apart from one provenance comment in `HeroCostumes` noting that Jenna was rebuilt from the JennaPreview inventory.
  - **Offline:** `pwsh tests/run.ps1` passes, with 10,945 hero rig checks.
  - **Studio playtest:** `studio-hero-rigs.luau` passes 677 checks; the trimmed `ArtPackVisuals` loads with its remaining API (`Animate`, `Attach`, `AttachAt`, `Mesh`, `Resolve`, `SetChestState`, `Template`); and the model viewer built all 12 heroes armed and posed (screenshots in `docs/hero-rig-rebuild/phase-6/`).

### Rebuild complete

All six phases are merged or in review. Open follow-ups, none blocking:
- **Unverified live:** the server's `HERO_ATTACK` broadcast in real combat, the plot-worker anchor, and a 2-client playtest, once the merged code is synced into Studio.
- **Possible improvements:** `IKControl` for the bow draw hand and foot planting; a hero `Hit` reaction on incoming damage; richer costumes for the 11 heroes that are faithful ports of simple originals.
- **Animations plan:** `animations-implementation-plan.md` (untracked) still describes the old `ArtPackVisuals.Animate` approach. Its items 2–3 are now covered by `HeroClips`/`HeroAnimator` and the `HERO_ATTACK` cue. The arrow projectile VFX (item 3) remain to do on top of `HeroAnimator`.

---

## Verification (every phase)

1. `pwsh tests/run.ps1`: compile plus the spec suites, including the new `hero-rig.spec.luau` and clip tests.
2. Rojo-sync to Studio, then run `tests/studio-hero-rigs.luau` through Studio MCP (structural, FK and socket assertions).
3. Playtest screenshots from fixed camera positions (front and side of each hero being changed), compared against the previous phase.
4. From Phase 5 on, a 2-client local server test for errors in Output.

---

## Risks

- **Visual regressions while porting 12 looks.** Phase 3 is data entry against reference screenshots taken before Phase 0; capture them first.
- **Hand-made Studio work is lost.** JennaPreview's sculpted details must be re-expressed as data pieces. The plan keeps her hair builder and recreates the pauldron's geometry, but anything else unique to the preview should be listed in Phase 0 before deletion.
- **Animation feel.** Procedural keyframes are coarser than authored Roblox animations. The format can later load `KeyframeSequence` data exported from the Animation Editor into the same clip tables if needed.
- **In-flight branches.** `feat/jenna-idle-stance` and the animations-plan work in progress touch `ArtPackVisuals`. Land or park them before Phase 5 to avoid conflicts.

## Decisions (settled in Phase 0, 2026-10-26)

1. **Parts, not meshes.** Rigs are blocky `Part`s built in code, matching the current style, reviewable and diffable. The costume format may gain an optional `MeshId` later.
2. **Native clips, not uploaded animations.** Clips are Luau keyframe tables like `TowerEnemyClips`, so there are no asset-permission failures in live servers.
3. **Shield on the forearm.** `SWORD_SHIELD` mounts its shield to `LeftLowerArm.ShieldMountAttachment`, not to the hand.
4. **Per-hero clip overrides allowed.** Clips are keyed by weapon type; a hero may override any state (`HeroClips.Overrides.<heroId>.<State>`) for signature stances.
