# Relic Loot & Summon Cost Rebalance: Implementation Plan

Status: implemented (2026-11-03). Deviation from the plan: the floor multipliers live in `TowerFloorConfig.RelicFloorMultipliers` (next to the drop tables), not in `RelicConfig`.

## Goals

1. **Limited hero banner** (*A Star's Arrival*) costs **200 Gems** for one pull and **1,800** for ten.
2. **Mana Geode** (Common relic) pays **100 Gems**. Higher tiers pay more from that baseline.
3. Retune relic **drop chances and tier split** so hourly gem income stays near the current targets despite the 10× Geode value.
4. Give each relic a **procedural 3D model** based on its name. Keep the glow and add effects so drops stand out.
5. Raise the **loot-lock cooldown to 5 seconds**.

## Where things live today

| Concern | File | Current value |
| --- | --- | --- |
| Relic tiers, payouts, locks | `Shared/Config/RelicConfig.luau` | Gems 10 / 30 / 300 / 1500, lock 3 / 3 / 5 / 15 s |
| Drop chance + tier split | `Shared/Config/TowerFloorConfig.luau` `GetKillRewards`, `RollRelic` | Relic 2→12 %, Elite +4 %, Core 2→20 %, Urn 18→40 % |
| Elite guaranteed Geode | `TowerFloorConfig.RollRelic` (line 196) | Every camp Elite drops a Geode at minimum |
| Relic spawn + visuals | `ExtractionAndSocial/RelicService.server.luau` `SpawnRelic` | Neon block/ball + `Highlight` + billboard |
| Fumble owner lock | `RelicService` `FUMBLE_OWNER_LOCK_SECONDS` | 3.0 s (also hard-coded in toast text) |
| Hero summon cost | `DataManager.server.luau:850` | Hard-coded `900 or 100` for **both** banners |
| Hero summon cost (UI) | `FacilityController.luau` lines 486, 610–611, 687, 794; `SummonReveal.luau:761–762` | Hard-coded 100 / 900 |
| Artifact banner cost | `ArtifactCatalog.Banner.Cost1X/Cost10X` | 160 / 1,600 (no change planned) |
| Summons → Gems conversion | `ShopConfig.GemsPerSummon` | 100 (used for the limited pack) |
| Gem/hour test | `tests/tower-run-loop.spec.luau:155–186` | 2,000 / 4,500 / 10,000 per hour at floors 1 / 25 / 50, ±25 % |

No client script listens to `RelicStateChanged` today, and the `relic_*` art-pack templates don't exist, so `ArtPackVisuals.Mesh` always falls back to a plain Neon part.

---

## 1. Summon costs

**Make the banner configs the single source of truth.**

- `HeroCatalog.PermanentBanner`: add `Cost1X = 100, Cost10X = 900`.
- `HeroCatalog.LimitedBanner`: add `Cost1X = 200, Cost10X = 1800`.
- `DataManager` `RequestSummonFunc`: resolve the banner first, then `gemCost = if count == 10 then banner.Cost10X else banner.Cost1X`. This is the only server-side change, and it keeps validation on the server.
- `FacilityController` (4 sites) and `SummonReveal` defaults: read `banner.Cost1X/Cost10X` instead of literals, so the button, the "Need X Gems" check and "Summon again" all show 200 / 1,800 on the limited banner.
- `ShopConfig.SafeGrant`: when converting a restricted player's *A Star's Arrival* summons to Gems, use the limited banner's `Cost1X` (200), not `GemsPerSummon` (100). Otherwise a restricted buyer gets half the value.
- Artifact banner stays 160 / 1,600.

### Hero rates and pity (offsetting the higher income)

The relic changes in §2–3 raise Gem income by about 1.3–1.5× (§3). To stop that turning into more heroes per hour, the banners get stingier. The rule is: **hours of play per hero copy must be at least what they were before**. Every figure below is measured at the new income.

**Call of the Rift** (price unchanged, so it takes the full cut). Rare-and-up rates are scaled by about ×0.67, Uncommon is trimmed and Common absorbs the rest. Pity goes from **80 to 120**.

| Tier | Old rate | **New rate** | Hours per copy, floor 1 (old → new) |
| --- | --- | --- | --- |
| 1 Common (Han) | 70.0 % | **75.32 %** | 0.1 → 0.05 |
| 2 Uncommon (Aaron) | 20.0 % | **18.0 %** | 0.25 → 0.2 |
| 3 Rare (Catio) | 7.0 % | **4.7 %** | 0.7 → 0.7 |
| 4 Superior (Valeria) | 2.5 % | **1.65 %** | 2.0 → 2.1 |
| 5 Exalted (Ignis) | 0.5 % | **0.33 %** | 3.3 → 3.4 (including pity) |
| Hard pity | 80 pulls (8,000 Gems, 4.0 h) | **120 pulls** (12,000 Gems, 4.1 h) | |

**A Star's Arrival** (the 200-Gem price already roughly halves pulls per hour, so this is a lighter trim). Pity goes from **90 to 100**.

| Tier | Old rate | **New rate** | Hours per copy, floor 1 (old → new) |
| --- | --- | --- | --- |
| 1 Common (Jenna) | 60.0 % | **61.14 %** | 0.1 → 0.1 |
| 2 Uncommon (Velkist) | 24.0 % | 24.0 % | 0.2 → 0.3 |
| 3 Rare (Eolka) | 10.0 % | **9.5 %** | 0.5 → 0.7 |
| 4 Superior (Morrigan) | 4.2 % | **3.8 %** | 1.2 → 1.8 |
| 5 Exalted (Archon) | 1.4 % | **1.2 %** | 3.6 → 5.7 |
| 6 Legendary (Solaris) | 0.33 % | **0.30 %** | 15 → 23 |
| 7 Mythical (Astrea) | 0.07 % | **0.06 %** | 4.4 → 6.7 (including pity) |
| Hard pity | 90 pulls (9,000 Gems, 4.5 h) | **100 pulls** (20,000 Gems, 6.9 h) | |

- **The permanent banner's pace is unchanged.** The limited banner becomes about 1.5× slower per copy, which keeps the event heroes special.
- On floor 50 at about 12,700 Gems an hour:
  - Limited hard pity takes about 1.6 hours.
  - Permanent hard pity takes about 0.9 hours (it was 0.8).
- The 10-pull Rare-or-better guarantee stays, and God's Blessing luck (`SummonLuck.ApplyLuck`) still shifts these base rates.
- **No save migration is needed.** Pity counters are plain counts, so raising `MaxPity` just gives existing counters more room.

**Code changes.** Only `HeroCatalog.PermanentBanner` and `LimitedBanner` change: `Rates`, `MaxPity` and the inline rate comments. The Altar rate grid, the pity bar and the Hero Index text already read `banner.Rates` and `banner.MaxPity`.

## 2. Relic payouts (Geode = 100 baseline, scaled by floor)

Each tier is worth roughly 3× the one below it, and Calamity Heart is a world-boss jackpot. The values below are the **floor 1 base**.

| Tier | Rarity | Dropped by | Base Gems (now → new) | Floor 50 Gems (×1.98) | Gold | Lock (s) |
| --- | --- | --- | --- | --- | --- | --- |
| Mana Geode | Common | everyone | 10 → **100** | 198 | 250 (unchanged) | 3 → **5** |
| Cursed Urn | Rare | everyone | 30 → **300** | 594 | 1,200 | 3 → **5** |
| Abyssal Core | Mythic | **Elites only** | 300 → **1,000** | 1,980 | 4,000 | 5 (unchanged) |
| The Calamity Heart | Boss Exclusive | **Alphas** (and Biome Bosses, see §3) | 1,500 → **5,000** | 9,900 | 15,000 | 15 (unchanged) |

`RelicConfig.CALAMITY_HEART.Rarity` changes from "World Boss Exclusive" to "Alpha Exclusive".

### Floor payout multiplier

Relic Gems now scale with the floor the relic dropped on. This replaces the Phase 6 M4 rule that relic gems are flat per tier.

- `RelicConfig.GemFloorScaling = 0.02`, so the Gem multiplier is `1 + 0.02 × (floor − 1)`: ×1.00 on floor 1, ×1.48 on floor 25 and ×1.98 on floor 50.
- `RelicConfig.GoldFloorScaling = 0.05` keeps the existing Gold multiplier (`1 + 0.05 × (floor − 1)`). It moves into config instead of being inline in `SpawnRelic`.
- Add `RelicConfig.FloorMultiplier(floorId, kind)`. `SpawnRelic` stores both multipliers on the relic. `awardRelicPayout` computes `gems = round(base × gemMult × scalar × streak)`, and Gold works as today.
- **The billboard shows the value:** "≈ 198 Gems · 3,000 Gold", so players can see why a deep-floor relic is worth fighting over.

The climb-streak multiplier (up to +100 %) stacks on top. A streaked Geode on floor 50 is worth about 396. A **wipe still forfeits the carried relic**, so the stakes of hauling go up a lot. That's intended: it makes contested loot matter.

> **The Calamity Heart now has a spawn source** (Alphas). Extracting one has a 25 % chance to grant a free **Archon**, the Exalted 5★ hero from the limited banner (`awardRelicPayout`). At the modelled drop rates, a player gets a Heart about every 9 hours on floor 1 and about every 2–5 hours on floor 50. The plan **lowers the Archon roll to 10 %**, so a free Exalted hero stays a rare jackpot rather than a farmable source. The broadcast toast's "3★" text should also become "5★" to match the hero.

## 3. Drop table, by enemy role

Each enemy role has its own drop table, and each top relic belongs to one role:
- **Regular:** Geodes and Urns only.
- **Elite:** the only source of **Abyssal Cores**.
- **Alpha** (the boss of floors 1–4 in each biome): the source of **Calamity Hearts**.
- **Biome Boss** (floors 5, 10, … 50): also drops Hearts, at double the Alpha share.

Every number interpolates linearly from floor 1 to floor 50 (`p = (floor − 1) / 49`).

### New `TowerFloorConfig.RelicDrops` table (keyed `REGULAR`, `ELITE`, `ALPHA`, `BOSS`)

| Role | Drop chance | Calamity Heart | Abyssal Core | Cursed Urn | Mana Geode |
| --- | --- | --- | --- | --- | --- |
| **Regular** | 0.6 % → 1.6 % | — | — | 12 % → 25 % | the rest (88 % → 75 %) |
| **Elite** | 6 % → 14 % | — | **6 % → 15 %** | 30 % → 40 % | the rest (64 % → 45 %) |
| **Alpha**, repeat kill | 20 % → 40 % | **2 % → 5 %** | — | 45 % → 55 % | the rest (53 % → 40 %) |
| **Biome Boss**, repeat kill | 20 % → 40 % | **4 % → 10 %** | — | 45 % → 55 % | the rest (51 % → 35 %) |
| Alpha or Biome Boss, first clear | 100 % | same shares | — | same shares | same shares, but a first Biome Boss clear gives at least an Urn |

With floor scaling, the expected value of one relic on floor 1 → floor 50 is:
- Regular: 124 → 297 Gems.
- Elite: 214 → 624 Gems.
- Alpha: 288 → 885 Gems.
- Biome Boss: 445 → 1,386 Gems.

### Code changes

- `GetKillRewards(floorId, role)` reads `RelicChance`, `HeartChance`, `CoreChance` and `UrnChance` from `RelicDrops[role]`, with 0 for any tier a role can't drop. The flat `bonus` and the shared Core and Urn curves go away. It also returns `GemMultiplier`. `ALPHA` already has a row in `BaseStatsByRole`, so the role assert holds.
- `RollRelic` keeps its signature and checks tiers in order: Heart, then Core, then Urn, then Geode. The camp-Elite guaranteed Geode is **removed**: at 100+ Gems it alone would pay about 7,000 Gems an hour. Elites still drop about 9–10× more often than Regulars.
- `CombatSimulation` boss path (line 2698):
  - Set `local relicRole = if bossTier > 0 then "BOSS" else "ALPHA"`.
  - Replace `firstClear or math.random() < 0.5` with `RollRelic(floor, relicRole, if firstClear then 0 else math.random(), math.random())`.
  - On a first Biome Boss clear, upgrade a rolled Geode to an Urn.
  - Kill gold still uses `GetKillRewards(floor, "BOSS")`.
- `SpawnRelic` already sizes the Heart larger and uses an `AlwaysOnTop` billboard, so the Heart needs no extra spawn work.
- `Gems` per kill stays at 1.

### Resulting economy

This updates the spec's model so boss time counts. Each boss takes about as long as 15 kills. A boss cycle is `round(20 + 1.2 × floor)` kill points, with Regulars worth 1 and Elites 3. The model assumes 900 kill-equivalents an hour and 8 % Elites.

| Floor | Boss | Mob kills / h | Bosses / h | Cores / h | Hearts / h | **Gems / h** | Old target |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Alpha | 492 | 27 | 0.14 | 0.11 | **~2,900** | 2,000 |
| 5 | Biome | 535 | 24 | 0.19 | 0.23 | **~4,000** | n/a |
| 24 | Alpha | 665 | 16 | 0.53 | 0.16 | **~6,400** | n/a |
| 25 | Biome | 668 | 16 | 0.55 | 0.32 | **~7,800** | 4,500 |
| 49 | Alpha | 737 | 11 | 1.21 | 0.21 | **~12,700** | n/a |
| 50 | Biome | 739 | 11 | 1.24 | 0.43 | **~15,100** | 10,000 |

- **Income is about 40–50 % above the old targets.** That roughly offsets the limited banner's doubled price: limited hard pity (18,000 Gems) takes about 6 hours on floor 1 and about 1.3 hours on floor 50.
- **Cores are an Elite event:** about one every 7 hours on floor 1 and one every 50 minutes on floor 50.
- **Hearts are rarer:** about one every 9 hours on floor 1, and one every 2–5 hours deep in the tower.
- **Biome Boss floors pay about 20 % more** than the Alpha floor after them. Income still rises with depth when you compare each biome's floors, so the monotonic check compares **Alpha floors only** (or biome averages) instead of every floor.

**New spec targets:** about 2,900 / 6,800 / 12,700 Gems an hour at Alpha floors 1 / 26 / 49, ±20 %. Biome Boss floors are checked separately to pay at least as much as the floor before them.

## 4. Loot lock → 5 s

- `RelicConfig`: set `InitialLockSeconds` to 5 for `MANA_GEODE` and `CURSED_URN`. `ABYSSAL_CORE` is already 5, and `CALAMITY_HEART` stays at 15 for the Rank #1 DPS lock.
- `RelicService`: `FUMBLE_OWNER_LOCK_SECONDS = 5.0`. Build the fumble toast from the constant (`%.1fs`) rather than the hard-coded "3.0s".
- The 1.5 s self-pickup block after a manual drop (`PickupBlockedUntil`) is a separate anti-spam timer and stays as it is.

## 5. Relic models and effects

### Architecture

To keep the server authoritative and the client responsible for rendering:

- **Server** (`RelicService.SpawnRelic`): keeps one **invisible root part** (`Transparency = 1`, same size and hitbox as today) that holds the billboard and the pickup, weld, ground-drop and despawn logic. That logic doesn't change. It sets attributes on the root: `RelicTier` and `RelicCarried` (updated on pickup, drop, fumble and extract). The `Highlight` moves to the client model.
- **New `src/ReplicatedStorage/Assets/RelicModelBuilder.luau`** (`--!strict`, same `makePart` helper style as `WeaponModelBuilder`): `RelicModelBuilder.Build(tierId): Model` returns a welded, massless, non-colliding model with a `PrimaryPart` at its centre, sized to the current relic footprint (about 3.2 × 3.8 studs, Heart 4.2).
- **New `src/StarterPlayerScripts/Rendering/RelicVisualController.client.luau`**: watches `Workspace.PhysicalRelics` (ChildAdded/ChildRemoved, which is streaming-safe), builds the model locally for each root, and moves it to the root's CFrame every frame with the idle animation. It destroys the model when the root goes away. This replaces the dead `ArtPackVisuals.Mesh(tierId)` path. If art-pack templates are added later, the builder can prefer them.

### Models by name

| Relic | Model |
| --- | --- |
| **Mana Geode** | A cracked open rock shell (Slate, 2 halves of angled wedges) with a cluster of 5–7 cyan Neon/Glass crystal spikes bursting out of the cavity. |
| **Cursed Urn** | An amphora: a ball body, a cylinder neck and lip, two ring handles and a sealed lid. Aged bronze with orange Neon rune bands, iron chain wraps, and a cracked lid leaking smoke. |
| **Abyssal Core** | A dark ForceField/Glass sphere with a violet Neon void nucleus, held in two crossed orbiting rings (thin cylinders) and a cage of 4 obsidian ribs. |
| **The Calamity Heart** | A crimson anatomical-style heart (2 balls and a wedge) with dark vein ridges, jagged crystal spikes growing from it, and a slow "beat" scale pulse. |

### Effects (scaled by tier so rarer relics read louder)

| Effect | Geode | Urn | Core | Heart |
| --- | --- | --- | --- | --- |
| `Highlight` outline (kept, tier colour) | ✓ | ✓ | ✓ | ✓ |
| `PointLight` (range / brightness) | 10 / 1.5 | 12 / 2 | 16 / 3 | 24 / 4 |
| **Loot beam**: vertical `Beam` pillar, visible from across the room | 20 studs | 30 | 45 | 70 |
| Rising motes `ParticleEmitter` (rate) | 6 | 10 | 16 | 24 |
| Pulsing ground ring (Neon disc, scale and fade loop) | ✓ | ✓ | ✓ | ✓ |
| Idle bob (±0.4 studs) and slow spin | ✓ | ✓ | ✓ | ✓ (spin and beat) |
| Spawn burst (one-shot `Emit`, light flash, 0.4 s) | ✓ | ✓ | ✓ | ✓ |
| Tier extras | — | smoke wisps | orbiting rings | screen-wide `AlwaysOnTop` billboard (exists) |

- **While carried** (`RelicCarried = true`): hide the beam, the ground ring and the bob, and keep the light, the motes and the outline. The relic overhead still reads clearly without the 70-stud pillar following the player.
- **Budget:** the beam and particles disable beyond 300 studs. At most about 20 relics per room is realistic, and particle counts stay modest.

## 6. Tests and docs

**Specs (`pwsh tests/run.ps1`):**

- `tower-run-loop.spec.luau`:
  - Replace `gemsPerKill`/`gemsPerHour` with the boss-cycle model from §3. Drop the Elite guaranteed-Geode term and apply `GemMultiplier`.
  - Set the targets to the Alpha-floor numbers from §3, ±20 %, and check monotonic income across Alpha floors.
  - Replace the "relic gems are flat per tier" comment and assertion with "payout strictly increases by tier".
  - Change the "camp Elite always drops a relic" assertion (lines 183–186) to role checks on every floor:
    - Drop chance rises Regular < Elite < Alpha.
    - `CoreChance > 0` only for `ELITE`.
    - `HeartChance > 0` only for `ALPHA` and `BOSS`.
    - The `BOSS` Heart share is above the `ALPHA` share.
- `tower-rework.spec.luau:94–97`:
  - `RollRelic(f, "ELITE", 0, 0)` returns `ABYSSAL_CORE`.
  - `RollRelic(f, "ALPHA", 0, 0)` returns `CALAMITY_HEART`.
  - `RollRelic(f, "REGULAR", 0, 0)` returns `CURSED_URN`, since Regulars can't drop Cores.
  - A failed roll now returns `nil` for Elites too.
- `tests/phase4-progression.luau:173–175`: pity becomes 120 / 100, `Rates[5]` 0.0033 and `Rates[7]` 0.0006.
- New assertions:
  - Each banner's `Rates` sum to 1.
  - The limited banner costs 200 / 1,800 and the permanent banner 100 / 900.
  - `MANA_GEODE.Payout.Gems == 100`, and payouts strictly increase by tier.
  - `FloorMultiplier(1, "Gems") == 1` and `FloorMultiplier(50, "Gems") == 1.98`.
  - Every tower-tier `InitialLockSeconds` is ≥ 5.
  - `RelicModelBuilder.Build` returns a model with a `PrimaryPart` for every `RelicTierId`.
- The `studio-tower-*` scripts already read payouts from `RelicConfig`, so they need no changes.

**Docs (same PR):**

- `GAME_DESIGN.MD`:
  - Line 90 (3 s → 5 s owner-lock).
  - Line 145 (the flat 10 / 30 / 300 becomes base 100 / 300 / 1,000 × floor multiplier, and the Elite guarantee goes).
  - Lines 699–700 (the boss repeat relic chance changes from 50 % to 20 → 40 %).
  - Lines 302, 356 and 368 (limited cost 200 / 1,800).
  - §4.1 pity (80 → 120, 90 → 100) and both drop-rate lists.
  - Add a short "Relic visuals" note to the extraction section.
- `CLAUDE.md`: the line "Both cost 100 Gems for one pull or 900 for ten" changes to say the permanent banner is 100 / 900 and the limited banner 200 / 1,800.

**No save migration is needed.** Nothing in the profile schema changes.

## 7. Suggested PR order

1. `feat(economy)`: summon costs from banner config, limited 200 / 1,800, and the new hero rates and pity (server, UI, shop conversion, tests). This ships together with PR 2, so income never rises before the banners tighten.
2. `feat(relics)`: payouts, drop table, Elite guarantee removed, 5 s lock (config, RelicService, specs, GDD).
3. `feat(relics)`: `RelicModelBuilder` and `RelicVisualController` (visual only, can be reviewed separately).

## Open decisions (defaults assumed above)

1. **Artifact banner** stays 160 / 1,600. "Limited banners" is read as the *A Star's Arrival* hero banner only.
2. **Elite guaranteed Geode** is removed rather than limited to the first Elite per floor visit, which would need new per-player state.
3. **Gold payouts** keep their base values and their existing ×(1 + 0.05 × (floor − 1)) floor scaling.
4. **Abyssal Core and Heart locks** stay at 5 s and 15 s. Only the 3 s locks are raised to 5.
5. **The Gem floor slope is 0.02** (×1.98 at floor 50). At 0.04 (×2.96) floor-50 income would reach about 20,000 Gems an hour. The slope is a single config value, so it's easy to tune after playtests.
6. **Biome Bosses also drop Hearts** at double the Alpha share. Without this, the hardest boss in each biome would drop worse relics than its Alphas. Making Hearts Alpha-only is a one-row config change.
7. **The Archon roll on Heart extraction drops from 25 % to 10 %**, now that Hearts can be farmed.
8. **The Artifact banner is not rebalanced.** At 160 Gems with pity 50, artifact pulls also become about 1.3–1.5× faster. The matching fix would be pity 50 → 70 with Rare-and-up rates scaled by about ×0.7. This is left out because only hero banners were asked for.
9. **The limited banner gets a light trim, not the permanent banner's full cut.** The 200-Gem price already does most of the work. With the full cut on top, limited heroes would take about 2× as long as before, for example about 9 hours for a floor-1 Mythical.

## How to test (Studio)

1. Run `pwsh tests/run.ps1`. All suites should pass.
2. Open the Summoning Altar and switch to *A Star's Arrival*. The buttons should read 200 / 1,800. With 1,799 Gems the 10-pull is refused with "Need 1800 Gems". The permanent banner still reads 100 / 900.
3. On floor 1, run the console command `_G.RelicService.SpawnRelic("MANA_GEODE", pos, player.UserId)` for each tier. Check that each relic has a distinct model, a beam, a light, particles, a bob and spin, and a spawn burst. Each should be visible from across the room.
4. Pick up a relic. The beam and ground ring should hide and the model should sit overhead. Drop it with `[R]` and the effects should return.
5. Bank a Geode at a sanctuary on floor 1. You should get +100 Gems, or more with a streak. On floor 50 the billboard should read ≈ 198 Gems, and banking it should pay that.
6. Repeat-kill Elites and Alphas. Both should drop more often than Regulars.
   - Only Elites should ever drop an Abyssal Core.
   - Only Alphas and Biome Bosses should drop a Calamity Heart.
   - To see a Heart quickly, temporarily set the `ALPHA` Heart share to 1.0 in Studio. Then check the 15 s lock, the −45 % speed, no jumping, and the extraction payout.
7. In a 2-player test, the second player can't grab the killer's drop for 5 s. After an AoE fumble, the toast says 5.0s and the relic stays locked for 5 s.
8. Farm floor 1 for about 15 minutes. You should see roughly 2–3 relics, and Elites shouldn't drop one every time.
