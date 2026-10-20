# The Pit: progression and verification

The current integration preserves the removal of research and RP from the game.
Advanced promotions and Runic Method have no lab prerequisite, infirmary upgrades
cost Gold, and all five squad slots are available. References to lab unlocks in
the original design notes below describe the previous progression model.

The Pit has four operations: deterministic EXP synthesis, guaranteed focused
imprints, guaranteed star promotion, and deterministic conversion. Heroes are
selected by their instance UUID. Display names and template IDs are never donor
identifiers. The existing 1–5 star ceiling and session-only profiles remain.

## Balance and existing systems

`src/ReplicatedStorage/Shared/Config/PitBalanceConfig.luau` owns Pit costs, EXP
efficiency, imprint definitions, reserve limits and combat EXP rewards.
`Shared/Util/PitMath.luau` calculates previews and results.
`Shared/Util/StatFormulas.luau` remains the common combat and facility stat path.
`ServerScriptService/Core/PitService.luau` validates and commits requests;
`DataManager.server.luau` connects it to the live session profile and remotes.

No extra rarity tiers, premium purchase requirement, Blood Pact mechanic or
mercenary rental is introduced. Standard summons retain their 100/900 Gem prices
and 70%/25%/5% distribution for 1/2/3 stars.

### Synthesis

Up to six donors are allowed. Each donor contributes:

```text
base = 100 × 3^(donorStars − 1) + 25 × donorLevel
gap = max(0, recipientLevel − donorLevel − 5)
efficiency = max(0.55, 1 − 0.025 × gap)
bonus = 0.10 with Essence Attunement + 0.05 for matching archetypes
EXP = round(base × efficiency × (1 + bonus))
```

The preview reports each component. Every donor is evaluated against the same
starting recipient, so changing donor order cannot alter the batch value.
The existing curve is `round(50 × level^1.45)` EXP per level. Caps are 10, 20,
30, 40 and 50. Combat stats use the existing `1 + 0.08 × (level − 1)` factor;
labor uses `1 + 0.05 × (level − 1)`.

Below 5 stars, reserve capacity equals the EXP costs of the next two levels after
the current cap. A 1-star hero can reserve 3,027 EXP for later promotion. Promotion
releases the reserve through the ordinary level curve. A transaction that would
exceed the reserve is rejected before donors are consumed. At 5 stars there is no
future-tier reserve. The UI directs capped heroes toward promotion.

### Imprints

Focused imprints have a disclosed **100%** success chance and grant half the
normal synthesis EXP. At 5 stars/level 50 the preview explicitly offers a
memory-only transfer with **0 EXP**, allowing endgame inheritance without claiming
unusable EXP. There is no random roll or probabilistic failure: pity,
failure consolation and client-specified odds do not apply. A rejected operation
consumes neither donor nor catalyst.

An imprint costs 200 Gold and consumes one compatible donor and one Imprint
Catalyst. Signature traits stay intact. Inherited memories occupy 1/1/2/2/3 slots
at 1/2/3/4/5 stars.
Repeating an existing memory raises its proficiency in the same slot, to rank 3;
it cannot create duplicate copies. Compatibility checks donor role, recipient
role, required stars, research and available capacity.

| Memory | Donor role | Recipient roles | Per-rank effect |
| --- | --- | --- | --- |
| Blade Discipline | Striker | Striker, Vanguard | +2% ATK |
| Measured Aim | Marksman | Marksman, Scholar | +2% ATK |
| Guardian's Memory | Vanguard | Vanguard, Healer | +3% HP |
| Mana Stewardship | Miner | Miner, Striker | +3% labor |
| Runic Method | Scholar | Scholar, Marksman | +1% ATK, +3% labor; 2 stars and Memory Studies |
| Steady Recovery | Healer | Healer, Vanguard | +2% HP, +2% labor |

The shared stat pipeline ignores unknown/incompatible memories, bounds each rank,
and caps total inherited bonuses at 12% ATK, 12% HP and 15% labor. Bonuses are
additive alongside native trait bonuses, avoiding a second multiplicative stack.

### Promotion and crafting

Promotion requires the current cap, Gold and Promotion Stones. It raises stars
by exactly one, keeps the current level/skills/traits and releases reserved EXP.
There is no identical-hero or same-rarity sacrifice requirement.

| Promotion | Required level | Gold | Stones | Additional research |
| --- | --- | --- | --- | --- |
| 1 → 2 stars | 10 | 1,500 | 1 | — |
| 2 → 3 stars | 20 | 7,500 | 3 | — |
| 3 → 4 stars | 30 | 35,000 | 8 | Advanced Stonecraft |
| 4 → 5 stars | 40 | 150,000 | 18 | Master Stonecraft |

Each promotion multiplies stored base HP/ATK once by 1.65 and base labor once by
1.35. Effective stats already use these scaled base fields; rendering, refresh,
combat reconnect and facility reassignment must not apply the multiplier again.

The existing Gems currency represents crystallized mana and is reused as the
crystal ingredient. Deposited physical loot already awards this currency; no
parallel crystal inventory is invented.

| Recipe | Gold | Gems | Soul Essence | Output |
| --- | --- | --- | --- | --- |
| Promotion Stone | 100 | 20 | 8 | 1 stone |
| Imprint Catalyst | 150 | 15 | 4 | 1 catalyst |

Advanced progression unlocks use the existing Dimensional Lab research system:

| Research | Lab level | RP | Gold | Effect |
| --- | --- | --- | --- | --- |
| Essence Attunement | 1 | 40 | 750 | +10% synthesis EXP |
| Memory Studies | 2 | 120 | 2,500 | Enables compatible Runic Method transfers |
| Advanced Stonecraft | 2 | 150 | 3,000 | Enables 3 → 4 star rituals |
| Master Stonecraft | 4 | 450 | 15,000 | Enables 4 → 5 star rituals |

Converting a fresh 1-star hero grants 4 Soul Essence, so the first stone requires
two such heroes, 20 Gems and 100 Gold, in addition to the promotion's 1,500 Gold.
Active Ring 1 enemies already award 45–210 Gold. These costs are adjustable in
the balance config; the old design documents' same-tier sacrifice model is no
longer the Pit implementation.

### Conversion and economy loops

```text
Soul Essence = rarityBase + floor((level − 1) / 5)
               + 2 × total bounded inherited imprint ranks
rarityBase = [4, 12, 36, 108, 324]
```

Conversion rewards only Soul Essence. It never grants Gold, Gems, heroes,
Promotion Stones or catalysts. Crafting spends Gold/Gems/Essence; summoning spends
Gems. Because no Pit conversion/crafting path produces Gems or heroes, repeatedly
cycling those operations cannot create a free summon or replenish its consumed
hero. Investment can increase eventual essence value but still consumes a finite
hero, active-play currencies and materials.

### Combat EXP

Eligible monster kills grant 25 EXP in Ring 1, 65 EXP in later rings, and 150 EXP
for Rift/World bosses. Each hero must contribute at least 2% of the target's max
HP, with damage recorded within 15 seconds of the kill. The Master must have
issued a valid nearby focus, Overdrive or recall command within 45 seconds. The
owner must remain connected/alive, and the hero must still be deployed, alive,
not in coma and have stamina. Per-hero awards have an 8-second cooldown and a
150-EXP maximum. Profile updates are deferred after the combat tick; Pit
transactions never execute inside the 5 Hz simulation loop. The service enforces
the existing level/reserve limits and sends affected-hero deltas.

## Safety, network contract and profile compatibility

Pit operations reject locked/favorited, assigned/deployed, recovering, reserved,
in-combat or specially protected donors. Sovereign Archon defaults to protected.
Assignment indexes as well as hero fields must agree before consumption. The
recipient cannot be its own donor; duplicate UUIDs are rejected; duplicate names
are allowed and stay distinct. High-rarity donors need explicit confirmation.
The unified protection control is deliberate: unlocking a normal hero clears
`Locked`, `Favorite` and legacy `Favorited` flags. It cannot unlock unique heroes.

The `TycoonGachaRemotes.PitRequest` RemoteFunction accepts `STATE`, `PREVIEW`,
`COMMIT` or `LOCK`. A preview carries an action (`SYNTHESIS`, `IMPRINT`,
`PROMOTION`, `CONVERSION`, `CRAFT`) and only hero
UUIDs plus the requested memory/recipe. A successful eligible preview returns an
opaque short-lived token. Confirmation submits that token and the rare-donor
confirmation flag. The server derives EXP, outcomes, costs and ownership.

The service serializes each player's requests and revalidates live state at
commit. Tokens expire after 45 seconds, are player-specific, and are consumed
once. Stale, replayed, modified, missing or insufficient-resource operations must
leave the profile unchanged. Previews do not consume heroes or currencies.
Client feedback follows the authoritative result; animation is cosmetic.
The fingerprint covers the selected heroes, resource balances, research and
assignment/reservation indexes. Ordinary stamina regeneration, unrelated heroes
and facility output-buffer changes do not invalidate a confirmation; crossing
the exhausted threshold does. State/preview/lock requests have server throttles.
Commits and locks return changed heroes plus explicit removals and resource
balances; `_PitDelta` profile events merge those changes into the existing HUD.

Schema version 2 initializes fields for existing session profiles rather than
replacing heroes, assignments, inventory, native traits or levels:

- Profile: `PitMaterials = {SoulEssence, PromotionStone, ImprintCatalyst}`,
  `PitRevision`, and the four Pit research booleans in `UnlockedResearch`.
- Hero: `Favorite`, `OverflowXP`, `InheritedImprints` (ID → rank map), derived
  `ImprintCapacity`, and `SynthesisHistory` counters for donors, EXP, imprints and
  promotions. Existing `Locked` values are preserved.

Defaults prepare the schema for later saving. This change does **not** implement
durable persistence.

## Repeatable automated checks

From the repository root in PowerShell:

```powershell
.\tests\run.ps1 -InstallLuau  # first run; downloads official Luau 0.743 to TEMP
.\tests\run.ps1               # later runs; no download
# Or use an existing official installation:
.\tests\run.ps1 -LuauDirectory C:\Tools\Luau
```

The runner first compiles every production `.luau` file unchanged. It then wraps
the real modules in CLI loader closures and executes `tests/pit.spec.luau`.
`tests/roblox-module-shim.luau` supplies module tree lookup and catalog color
constructors; it contains no gameplay formulas, transaction implementation or
mock success results. The suite uses isolated profiles, controlled time and
generated tokens. It exits nonzero on a failed assertion.

These tests exercise calculations and service behavior, not Roblox rendering,
RemoteFunction transport, physical input, live combat or device emulation.
Those require the Studio checks below. The CLI compiler is a syntax/bytecode
check; it is not a Roblox API/type-validation result.

### Recorded verification (20 October 2026)

- Official Luau 0.743 compiled all production scripts successfully (approximately
  15,000 lines at this checkpoint).
- Initial CLI regression suite: **48 passed, 0 failed**. The balance sweep checks 30,000
  combinations across donor stars/levels, recipient levels, research and affinity;
  native catalog combat/labor formulas remain unchanged without imprints.
- The same 48-test spec executed in connected Roblox Studio Edit against the
  actual ModuleScripts, with **48 passed, 0 failed**. It used real Roblox module
  loading and engine values rather than the CLI shim.
- Validated service cases include malformed requests, duplicate names/UUIDs,
  ownership, all donor protections and redundant assignment indexes, stale and
  replayed tokens, exact costs, overflow rejection/reserve release, guaranteed
  imprints/capacity/rank bounds, final-cap memory-only inheritance, isolated
  player profiles, reentrant request locks and post-commit replication failures.
- After the final protection/combat-sync changes, the expanded CLI suite passed
  **51 tests, 0 failed**. Added checks cover deliberate clearing of current/legacy
  favorite flags, combat-award locking during callback reentry, and a throwing
  combat replication callback preserving exactly one successful award.
- Connected Studio Play verified actual UI confirmation/RemoteFunction flows:
  two-donor synthesis granted 256 EXP (level 1 → 3, 69 EXP remaining); cancel
  preserved inputs; focused imprint granted Blade Discipline rank 1 and 170 EXP,
  consuming its donor once; conversion granted exactly 8 Soul Essence.
- The live promotion test increased 1 → 2 stars, retained level 10 and its
  imprint, and released 100 reserved EXP. ATK changed 77 → 127, HP 516 → 851,
  DPS 90.6 → 149.4, and labor 20.3 → 27.4. These matched the shared formulas.
- Desktop rendering at 1,340 × 696 showed the three-column composition with
  real, static hero busts. Responsive layouts, physical controller/touch input,
  multiplayer and live combat participation need the remaining checks below;
  a passing isolated engine module suite does not establish those outcomes.

## Studio playtest checklist

Use a test session; current profiles intentionally reset on leaving.

- **Desktop:** Open the Pit via its world prompt and HUD. Check all four tabs,
  live resource amounts, roster search/sorts/role/rarity/status filters, protected
  explanations and before/after stats. Select six donors and try a seventh.
  Preview and cancel, then confirm; verify only the displayed UUIDs disappear.
- **Promotion loop:** Earn/convert two expendable 1-star heroes, craft a stone,
  reach level 10 and promote. Verify exact Gold/Gems/Essence costs, new frame,
  level cap, stored reserve release and one application of stat multipliers.
  Assign the survivor to a facility and verify its actual productivity.
- **Imprints:** Transfer a compatible memory, upgrade it to rank 3, attempt a
  fourth upgrade, fill slots, try an incompatible ranged/melee transfer and try
  Runic Method before/after Memory Studies. Confirm guaranteed outcomes and
  catalyst costs; rejection must preserve all inputs.
- **Tablet emulator:** Verify the compact composition, expanded details and
  roster scrolling in both orientations. Important text and actions must fit.
- **Phone emulator:** Follow recipient → donors/materials → review → confirm.
  Check sticky action, scroll reachability, top-bar/touch safe areas and readable
  targets. Test long names, empty rosters and a large roster.
- **Controller emulator:** Navigate tabs, cards, filters, help, confirmation,
  action and close using selection/activate/back. Selection must remain visible
  after a refresh and return to gameplay after closing.
- **Accessibility/lifecycle:** Increase text preference, enable reduced motion,
  skip ritual effects and repeatedly open/close the Pit. No clipped buttons,
  lingering modal, repeated callbacks, stuck focus or permanently blocked
  movement/whistles should remain. Closing during a request must be safe.
- **Live rejection:** Preview, then assign/lock a donor or spend the required
  currency elsewhere. Commit must fail clearly, preserve inputs and refresh the
  displayed state. Double-click confirmation and replay the request; exactly
  one operation can commit.
- **Two-player Start Server:** Use separate clients to operate their Pits
  simultaneously. Submit another player's UUID/token from a test client and
  verify rejection. One profile's changes must not affect the other. Have one
  player fight while the other submits batches; watch server timing for combat
  responsiveness. Verify no inactive/disconnected hero receives combat EXP.
- **Regression:** Summon once/ten times at 100/900 Gems; deploy/recall/fight,
  extract loot, research, assign/unassign workers, recover from coma, and use
  retaliation. Confirm these paths still update their existing UI and state.

Record the tested Studio build, emulator dimensions, player count and observed
results before treating visual/device/multiplayer acceptance as verified.
