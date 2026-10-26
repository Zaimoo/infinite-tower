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
ReplicatedStorage/Assets/Heroes/            (new folder of ModuleScripts, Rojo-tracked)
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

### Phase 2: Sockets and weapon prefabs

- Add `Grip` / `OffhandGrip` / `ShieldMount` / `Nock` attachments to all 6 prefabs in `WeaponModelBuilder`, oriented by the socket rule.
- Write `HeroSockets.Equip(rig, weaponModel, weaponType)` and `Unequip`.
- Extend `studio-hero-rigs.luau`:
  - For each weapon type on a bare rig, the handle is within 0.05 studs of the hand grip.
  - In a reference "arm forward" pose, the bow stave is within 10° of vertical and the arrow points within 10° of root `-Z`.
  - The sword points up along the forearm, and the shield sits on the forearm's outer face.
- Fix `HeroAssetSetup`'s `pairs` error on `EnsureWeapons()` (it returns an Instance) while in this area.

**Done when:** every weapon type sits correctly on a bare rig in the reference poses. Screenshot each.

### Phase 3: Costumes for all 12 heroes

- Port each hero's look from `HeroModelBuilder.BuildX` into `HeroCostumes` data. Keep colors and silhouettes; split cross-joint pieces per bone; drop any gear.
- Rebuild Jenna from the builder, not from JennaPreview. Her hair (`attachJennaHair`), pauldron (geometry only, no script) and cuffs become data pieces.
- `HeroRegistry.EnsureHeroes()` builds all 12 into `ReplicatedStorage.Assets.Heroes`, replacing the existing templates. `HeroAssetSetup` calls it.
- Add a costume lint to the Studio test: each piece is welded by a `Weld` to one bone, no bounds cross a joint plane, the hero is within budget, and there are no `LuaSourceContainer`s.

**Done when:** a side-by-side screenshot sheet of all 12 (front and side, bare and armed) matches the old looks, and the lint passes.

### Phase 4: Animator and clips

- Write `HeroAnimator` and `HeroClips` with all states for all 6 weapon types, plus the shared states.
- Re-author Jenna's Wind-Scout idle as `Overrides.hero_jenna.Idle` on the new rig.
- The animations plan's items 2 and 3 (attack tiers, arrow projectiles) target this animator instead of `ArtPackVisuals.Animate`; that plan gets a short pointer.
- Add a pure-Luau clip test: every weapon type has every required state, keyframe times are sorted from 0 to 1, and every joint name is valid.

**Done when:** in a playtest, each weapon type idles, walks and runs its three attack tiers without limbs clipping the torso or weapons crossing the face. Check with screenshots and the FK checks from Phase 2.

### Phase 5: Migrate consumers

- `EntityRenderer`: switch `ArtPackVisuals.Attach/EquipWeapon/UnequipWeapon/Animate` for heroes to `HeroRegistry`, `HeroSockets` and `HeroAnimator`. Mobs and props keep using `ArtPackVisuals`.
- `PlotManager.createWorkerAvatarPart`: clone the template upright and play `Sleep` / `Labor` (server-side static pose via `Transform` of the first keyframe).
- `HeroCard.Portrait`: pose the clone with the `Idle` first keyframe.
- `HoldingAnimationController`: use the `Carry` clip and `CarryAttachment` for hero rigs.
- `AdventurerPatrolController`: verify; it reads `HeroCatalog` and should need no change.

**Done when:** Hub, Fortress plot (beds, facility workers), the tower and the hero cards all show the new rigs. A multiplayer playtest with 2 clients shows no errors.

### Phase 6: Remove the old stack and update docs

- Delete `HeroModelBuilder.luau`, the hero branches in `ArtPackVisuals`, `normalizeR15Joints`, the `KiteShield` special case and the `starter_iron_vanguard` alias, if unused.
- **Studio action (needs user confirmation):** delete `ServerStorage.ModelViewer.JennaPreview`, and replace the model viewer with a script that builds previews from `HeroRegistry`.
- Update docs:
  - `GAME_DESIGN.MD` §7.5 (socket points and the shield on the forearm).
  - `technical_architecture.md` (asset layout, rig standard).
  - `CLAUDE.md` layout section (new `Assets/Heroes/` modules).

**Done when:** `grep` finds no references to the removed modules, `pwsh tests/run.ps1` and the Studio rig test pass, and docs match the code.

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
