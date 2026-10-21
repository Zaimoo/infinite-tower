# Stat system implementation plan

Prepared 2026-10-22 from the connected **Infinite Towers: Become a Master!** Studio place (`136256010643848`) and the current `codex/stat-scaling-overhaul` checkout. **Planning only: Studio was inspected in Edit mode; no scripts, instances, play state, or published place were changed.**

## Scope and acceptance target

Implement the stat calculations and hero/weapon progression in [the GDD](../../GAME_DESIGN.MD#42-effective-combat--labor-formulas) and [economy stat tables](../../economy_balancing_tables.md). Use [the calculator](stat-scaling-model.cjs), [generated reference](STAT_SCALING_TABLES.md), and [50-floor stat CSV](FLOOR_SCALING.csv) as numerical fixtures.

- Four hero combat stats: movement speed, attack speed, attack damage, health.
- Hero stars 1–5; level cap `10 * Stars`; promotion retains level and raises the cap. Combat growth is `3^(Stars-1) * 1.08^(Level-1)`.
- Artifact rarity is inherent. Weapon stars progress 1–7 with power multipliers `1 / 1.6 / 2.5 / 4 / 6.5 / 10 / 16`. No enhancement levels enter the new calculation.
- Weapon power is `InherentRarityPower * WeaponStarMultiplier`. Damage is `ROUND(SeedDamage * Quality * HeroGrowth * (1 + WeaponPower/40))`; health is `ROUND(SeedHealth * Quality * HeroGrowth)`.
- Attack speed is bounded at 5 attacks/s. Weapon rarity supplies its fixed speed bonus; levels/stars do not exponentially scale movement or attack speed. Launch movement speed remains 20 studs/s.
- The floor-50 reference uses five 5-star level-50 heroes with **Mythical 7-star weapons**, not higher-rarity equipment. Mythical has 7,000 inherent power and +30% speed; 7-star power is 112,000.
- Han/Jenna/Aaron/Velkist/Eolka at quality 1.00: **2,550,247,625 scheduled DPS**, or **1,912,685,719 at 75% uptime**. At quality 0.90 and 75% uptime: **1,721,417,146 DPS**. These values assume the current conservative 0.2s cooldown buckets and exclude Overdrive/exposure.

**Protected scope:** preserve banner costs, RNG pools/weights, drop rates, pity, boss reward rules, acquisition guarantees, Gold/EXP rewards, crafting recipes, navigation, buildings, plot architecture, and unrelated UI. Section 7.4 stays unchanged by this implementation. Mythical at floor 50 is a stat reference, not a new acquisition restriction or guaranteed drop.

## Current Studio findings

The viewport showed the fortress courtyard, facility buildings, fountain, and war banner. Studio was in Edit mode, so there were no live player-profile or combat measurements. The Output log contained repeated Roblox CorePackages/UIBlox warnings; that is not evidence that gameplay scripts passed or failed.

A read-only source inventory found **68 active source containers** under ReplicatedStorage, ServerScriptService, StarterPlayer, and StarterGui. Recovery copies under ServerStorage were excluded. Comparing UTF-8 source checksums after normalizing local line endings found **60 matching repository scripts, six differing scripts, and two Studio-only scripts**.

| Area | Observed current implementation | Implementation consequence |
| --- | --- | --- |
| `Shared.Util.StatFormulas` | Linear `1 + 0.08*(Level-1)` growth, trait/imprint factors, flat artifact ATK, old artifact enhancement input | Replace the shared math rather than adding a second multiplicative layer |
| `Shared.Config.HeroCatalog` | Immutable one-star seeds already exist; native values use 1.65 promotion; trait fields remain | Keep seed identity/banner weights; recompute derived native previews from the new factor |
| `Shared.Config.PitBalanceConfig` | Combat promotion 1.65, labor promotion 1.35, caps 1–5 | Change combat progression only; retain existing costs and EXP rules |
| `Shared.Util.PitMath.Promote` | Keeps level already, increments stars, mutates stored BaseHP/BaseATK by 1.65 | Preserve level behavior; stop double-counting pre-scaled base fields |
| `Shared.Config.ArtifactCatalog` | Stars own base stats; rarity multiplies them; enhancement +0–10; named-item formula exceptions | Introduce the new inherent-rarity power/speed data and progressive star factors |
| `Core.DataManager` | Creates pre-scaled hero bases; weapon instances have Level; existing upgrade raises Level | Add stat normalization and weapon-star transactions in narrowly selected functions |
| `CombatSimulation` | Deployment passes the weapon, but recurring and progression refresh calls omit it | Resolve equipped weapons consistently or the new weapon multiplier will disappear during refresh |
| `CombatSimulation` | 20 studs/s movement; attack cooldown reset in a 5 Hz loop | Keep current cadence for the first implementation and make displayed DPS match it |
| `FirstBiomeCombat` / `TowerEncounterRuntime` | Actual combat is authored for floors 1 and 5; spawn/respawn use entry HP/ATK directly | Updating only the generic TowerFloorConfig will not change actual slice combat |
| `ForgeController` / `DataManager.UpgradeArtifact` | Enhancement workflow, five-donor limit | A 7-star promotion needs six donors: update the actual picker and validator together |
| `CombatFeedback` / UI number helpers | Raw full-number text | Add compact damage/health/DPS formatting without changing layout or banner UI |

### Studio differences to preserve

These active scripts differ from the checkout:

- `ServerScriptService.BaseOverhaul.BridgeBuilder`
- `ServerScriptService.BaseOverhaul.PlaceIslandsInRing`
- `ServerScriptService.BaseOverhaul.WallsBuilder`
- `ServerScriptService.Core.DataManager`
- `ServerScriptService.Core.PlotManager`
- `StarterPlayer.StarterPlayerScripts.Input.MasterController`

Studio additionally contains `StarterPlayer.StarterPlayerScripts.BlurGuard` and `StarterPlayer.StarterPlayerScripts.Rendering.PlotBeaconController`.

The complete DataManager comparison specifically identified **plot-ownership validation added in Studio**, including an extra `targetPlot` argument on summon, Pit, equip/unequip, upgrade, crafting, assignment, and facility handlers. Preserve these checks and argument shapes. The other differing scripts were inventoried, not functionally audited, and are outside this stat task.

Do not overwrite these Studio scripts with older checkout copies or perform a whole-project push. The source comparison is a point-in-time snapshot; recheck before implementation because a colleague is editing the place.

## Implementation sequence

### 0. Establish the shared-file baseline

1. Re-read current Studio sources and Git status immediately before starting code work.
2. Reconcile **DataManager only where needed for stats/progression**, preserving its newer ownership guards and `targetPlot` parameters. Keep the other differing scripts and the two Studio-only scripts untouched.
3. Record protected banner/drop/reward blocks and their current behavior so later tests can show they were not changed. Do not treat documentation/runtime acquisition differences as permission to resolve them.
4. Use small patches grouped by math, hero progression, weapon promotion, combat integration, and numeric presentation. Avoid whole-file replacements in shared files.

**Exit:** the stat implementation has a current baseline and a clear list of protected functions/data; no colleague edits have been overwritten.

### 1. Implement the pure stat calculation

**Files:** `Shared/Util/StatFormulas.luau`, stat fields in `Shared/Config/HeroCatalog.luau`, a small dedicated balance module if that reduces edits to shared catalogs.

1. Define one pure calculation returning named `AttackDamage`, `Health`, `AttackSpeed`, `MovementSpeed`, `AttackInterval`, and scheduled `DPS` values. Range and labor remain separate metadata/output.
2. Derive damage/health from immutable catalog one-star seeds, stars, level, quality, and weapon power. Do not apply hero growth to old already-promoted BaseHP/BaseATK again.
3. Keep the existing tuple-returning API as an adapter while its consumers are migrated; avoid a simultaneous rewrite of every caller.
4. Remove trait/imprint contributions from combat and labor math. Ignore legacy effect fields. If other existing code still calls an effect helper, use a temporary zero-effect compatibility result rather than deleting unrelated Pit features in this patch.
5. Preserve the labor curve, facility synergy, XP curve, caps, and synthesis efficiency. Regenerate native-star compatibility values/previews from the correct one-star seeds; do not change hero identities, drop weights, or native stars.
6. Keep round-once damage/health calculations, finite/range checks, and bounded speeds. Apply Overdrive once, exposure once, exhaustion once; coma yields zero active DPS.

**Exit:** independent Luau results match the offline fixtures, including unequipped heroes, native 2/3-star heroes, quality boundaries, and max progression. Legacy trait/imprint fields cannot alter the result.

### 2. Wire hero leveling and promotion

**Files:** `Core/DataManager.server.luau` hero constructor/normalizer, `Shared/Util/PitMath.luau`, narrowly scoped `Core/PitService.luau` and `PitBalanceConfig.luau` changes.

1. Normalize hero stat inputs from TemplateId, Stars, Level, and QualityScalar. Keep UUIDs, assignment, locks/favorites, equipped weapon links, XP, stamina, and coma state.
2. Retain the existing promotion requirements and Gold/stone prices. Promotion increments stars once, retains level, raises the cap, and releases valid reserved XP through the existing advance function.
3. Replace repeated stored-base multiplication with canonical derivation. Refresh compatibility BaseHP/BaseATK/BaseLabor fields only if old consumers still need them; do not make them a second source of truth.
4. Make synthesis previews, promotion previews, commits, and live refresh use the same calculation. Include the resolved weapon when a preview claims equipped total damage/DPS; otherwise label it unarmed.
5. Keep current health clamping, cooldowns, entity identity, and target state during refresh; do not introduce free full healing or combat resets through promotion/equipment changes.

**Exit:** a 1-star level-10 hero becomes 2-star level-10, with 3x unrounded trained damage/health at the same level, not level 1 or a double promotion. Reconnect/redeploy does not apply promotion again.

### 3. Implement weapon stat progression and star promotion

**Files:** stat/progression portions of `Shared/Config/ArtifactCatalog.luau`, selected artifact functions/remotes in `Core/DataManager.server.luau`, upgrade view in `UI/ForgeController.luau`.

1. Add inherent rarity power/speed values and the seven star multipliers from the reference. Keep rarity names/colors and unrelated catalog fields stable.
2. Replace flat final ATK and enhancement-dependent weapon calculations with power amplification of trained hero damage. Remove named weapon exceptions from this reference weapon calculation so previews and combat agree.
3. Ignore legacy weapon Level in the new stat path; it is not a progression axis. Preserve item UUIDs, inherent Rarity, Star, ownership, equip links, and locks. Do not silently convert old enhancement investment into rarity, stars, currency, or refunds.
4. Implement a clearly identified weapon-star promotion operation. It consumes the configured duplicate count and existing specified Gold/Gems, increments Star once, and preserves recipient rarity/template/UUID. Validate all donors, ownership, locks/equip state, resources, and cap before mutation. Reject replay/stale requests without partial consumption.
5. Support six distinct donors for the final step; the current five-donor limit is insufficient. Do not change synthesis donor limits as a side effect.
6. Replace enhancement-specific controls and preview calculations **inside the existing Forge upgrade view only**. Preserve the summon and assign views, their prices/pools/pity, and the surrounding layout. Show current/next stars, power, hero damage/DPS, fixed rarity/speed, exact donors, and costs.
7. Retire enhancement behavior and coordinate the old rarity-changing upgrade endpoint with the progression owner. Do not rewrite Section 7.4, its acquisition behavior, crafting recipes, or the banner to make those old endpoints fit the new model.

**Exit:** Mythical 6-star to 7-star changes power from 70,000 to 112,000, consumes six eligible same-template donors plus 250,000 Gold/500 Gems, and keeps rarity and +30% speed fixed. Invalid attempts consume nothing. No enhancement level affects damage.

### 4. Integrate combat refresh and floor durability

**Files:** stat call sites in `Combat/CombatSimulation.server.luau`, stat lookups in `Combat/TowerEncounterRuntime.luau`, `Shared/Config/TowerFloorConfig.luau`, and stat fields in `FirstBiomeCombat.luau`.

1. Resolve the equipped artifact from the authoritative profile in deployment, recurring update, explicit progression refresh, equip/unequip, reconnect, and any DPS estimate that claims equipped output. Use a shared resolver to avoid fixing only the deploy path.
2. Refresh attack interval as well as damage/maximum health. Keep movement speed at the existing baseline. Preserve combat identities, cooldown state, navigation, telegraphs, attack timelines, stamina drain, and coma mechanics.
3. Match current tick-reset behavior in scheduled-DPS estimates. Defer cooldown-remainder/cadence improvements to a separate change; otherwise the implementation and calculated target will use different timing models.
4. Provide a single floor-role **HP/basic-damage** lookup from the stat checkpoints. Apply it on spawn and respawn in the real floor-1/floor-5 runtime, where the old values currently come directly from FirstBiomeCombat entries.
5. Change HP/ATK inputs only. Keep enemy counts/placement, names, rigs, timings, boss mechanics, Gold, XP, drops, respawn rewards, and reward multipliers unchanged. Do not multiply new absolute stats by the old shallow HP/damage curve again.
6. Cover all 50 stat rows with numerical tests. Do not enable new encounters on the other 48 floors: the inspected Studio only has the authored two-floor combat slice. A floor-50 runtime benchmark must use a controlled development test fixture, not imply that floor-50 content is released.
7. For benchmark measurements, use actual HP removed and exclude overkill. Existing reward ledgers currently accumulate raw damage; do not change payout/contribution rules inside this stat patch. Keep that discrepancy visible as a separate integration issue.

**Exit:** equipped weapon power survives recurring refresh, synthesis/promotion refresh, and redeploy; floor-1/floor-5 enemies use the new numeric curve without reward changes; floor-50 controlled output matches the reference.

### 5. Update numeric presentation without redesigning UI

**Files:** numeric consumers in Forge/hero/promotion/squad views, `UI/PitDesignTokens.luau`, and `Assets/CombatFeedback.luau` as needed.

1. Display the four combat stats with explicit units; label range and labor separately. Convert stored interval to attacks/s for display without renaming every persisted field.
2. Reuse the canonical snapshot for hero damage/DPS and all before/after previews. Do not derive client bonuses independently or retain a hidden enhancement factor.
3. Add K/M/B/T formatting for large damage/health/DPS values, with full values in detail views where supported. Keep network/server values numeric and unabridged.
4. Keep the room protocol's existing HP-permille snapshot. Audit absolute health and damage event fields for values above 32-bit range; the target floor-50 boss has **110,844,632,813 health**.

**Exit:** numeric previews match server calculations, billion-scale labels fit existing desktop/mobile layouts, and no banner or unrelated UI flow changed.

## Integration dependencies outside the stat patch

These are planning boundaries, not instructions to edit other systems:

- **Acquisition data contract:** Studio's SummonArtifact currently rolls 1–5 stars, uses 160/1600 Gems, and calls CreateArtifact with rarity 1. The GDD's preserved Section 7.4 describes a different rarity-based banner. Converting rolled stars into rarity, resetting all new pulls to 1-star, altering pity/prices, or adding Mythical caches would change acquisition and is outside this work. Agree with the colleague on how their acquisition code supplies immutable rarity and progressive stars. Until that integration exists, use explicitly constructed test fixtures for Mythical benchmarks; do not claim ordinary progression reaches them yet.
- **Legacy refinement wording/endpoint:** Section 7.4 was deliberately restored unchanged, including its old refinement text. That acquisition/progression conflict needs owner reconciliation; this plan does not silently rewrite it.
- **Legacy non-weapon catalog entries:** Studio still has shields/rings and named extra-stat branches. Preserve acquisition/equip permissions and do not delete items or convert inventories in this patch. Align their treatment with the responsible owner before whole-game activation; the billion-DPS proof uses ordinary weapons only.
- **Shared PvP/world-boss paths:** the same combat script also applies 25% PvP damage, estimates shared boss HP without equipment, and uses raw-damage reward ledgers. New weapon-amplified damage can break those assumptions. Record the effects and coordinate separate compatibility work; do not silently rebalance PvP, payouts, or boss rewards. Do not treat a passed tower fixture as clearance to publish the new stats across those modes.
- **Trait/imprint feature cleanup:** this implementation removes their numeric effects. Deleting menus, recipes, conversion rewards, and all transaction paths is separate feature cleanup owned outside the narrowed stat patch.

## Verification and delivery gates

| Gate | Required evidence |
| --- | --- |
| Reference parity | Luau matches generated damage/health/power/cadence fixtures, including all 784 hero/rarity/star combinations and quality boundaries |
| Hero progression | Level caps, retained levels, exact costs, XP reserve release, no double growth, preview/commit agreement, and stale-request rejection |
| Weapon progression | Every star step, six-donor final step, immutable rarity/speed, no enhancement contribution, lock/equip/ownership protection, atomic resource consumption |
| Live refresh | Weapon equipped at deploy remains effective after ticks, synthesis, promotion, equip/unequip, reconnect, and redeploy |
| Tower durability | Real spawn/respawn uses new HP/ATK on floors 1/5; all 50 generated stat rows remain monotonic; enemy reward fields unchanged |
| Billion-DPS target | Controlled floor-50 fixture records approximately 2.550B full-contact mixed-squad DPS; minimum-quality/75%-uptime model remains above 1B; allow for finite measurement windows and tick startup |
| Numeric safety | Damage/health above 4.29B and 100B, HP-permille round-trip, compact labels, no NaN/infinite input acceptance |
| Protected systems | No diff to banner probabilities/prices/pity, drops, rewards, navigation, scene geometry, unrelated UI, or colleague ownership guards |

During implementation, adapt existing relevant tests in `tests/pit.spec.luau`, `tests/forge.spec.luau`, and tower suites; do not delete unrelated feature tests to make the new math pass. Add focused regression coverage for missing weapon refresh and immutable-rarity star transactions. Then run the repository's compile/regression runner and relevant Studio server/client checks.

```powershell
node docs/balance/stat-scaling-model.cjs --check
.\tests\run.ps1
```

Implementation and verification completed locally and in Studio on 2026-10-22. See [IMPLEMENTATION_VERIFICATION.md](IMPLEMENTATION_VERIFICATION.md) for the executed checks, controlled live DPS results, preserved colleague changes, and remaining acquisition/PvP integration boundaries. The place was not published.
