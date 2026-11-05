# Forge Roll System Redesign — Revision 2 (audit, fixes, Gilded Grimoire UI)

Revision 1 of this plan (commit `fd126ed`) moved the Blacksmith Forge to a Gold banner with an 84-weapon roster, 1★ drops, a 120-pull Exalted+ pity, selling and a 50-item cap. Most of it shipped in `1394c97`. This revision records what the audit of that commit found, fixes what is broken, re-tunes the sell economy, and redesigns the Forge screens in **Gilded Grimoire** (`docs/ui/GILDED_GRIMOIRE.md`).

The 84-weapon roster itself is unchanged and is kept as the appendix. `ArtifactCatalog.luau` is now its source of truth.

---

## 1. What shipped and works

| Area | State |
| :--- | :--- |
| Roster | 84 seeds, 2 per archetype per tier, `CatalogOrder` matches `Seeds` exactly, `RosterByTierAndType` and `GetTierPair` resolve every pair. Every legacy template ID survived, so old references still resolve. |
| Banner config | Gold, 5,000 / 45,000, `MaxPity = 120`, `PityRarity = 5`, 7-tier `BaseRarityRates` (sum 1.0). |
| Server summon | Gold deduction, cap check before deduction, luck via `SummonLuck.ApplyLuck`, 10-pull Rare+ guarantee (rolling counter `ArtifactBanner10Pity`), pity reset on Exalted+, uniform archetype, 60/40 variant, 1★ drops, onboarding report, Blessing pulse. |
| Hero cap | `RequestSummon` rejects pulls past 50 heroes. |
| Selling | `RequestSellArtifacts` remote with plot, onboarding, equipped and locked guards. |
| Cleanup | `CraftArtifact`, `GrantBossArtifact`, `BossArtifactRarity` and the CombatSimulation hook are gone. |
| Index | 84-weapon tags, `CatalogOrder` enumeration, rarity from `seed.RarityTier`. |
| Tests | `tests/run.ps1` compiles and every suite passes. |

---

## 2. Bugs found (fix first)

Ranked by severity. File references are to the current branch.

### P0 — breaks play or the economy

1. **Assign tab crashes whenever it renders a card.** `updateCard` in `ForgeController.luau` (≈ line 811) is a plain `local function`, but its sell-mode block reads `self.SellMode` and `self.SelectedSellUUIDs`. There is no `self` in scope, so every render throws `attempt to index nil`. The Assign tab, sell mode and the equip flow all die with it. The compile-only test run cannot catch this.
   **Fix:** pass the controller in (`updateCard(self, node, item, heroMap, order)`) or pass `sellMode` and `selected` as arguments. Fix the call in `renderSlice`.

2. **Selling duplicates a UUID's payout.** `DataManager.SellArtifacts` iterates the client list without de-duplicating. `{ uuid, uuid, uuid }` pays three times for one weapon. That is a Gold dupe exploit.
   **Fix:** build a `seen` set; skip repeats. Also cap the list at `StatBalance.MaxArtifactInventory` entries and reject non-string entries outright.

3. **Selling returns more Gold than a summon costs, so luck makes Gold infinite.** With the Revision 1 sell table, the expected sell value of one pull is about **4,320 Gold at zero luck** (86% of 5,000, 96% of the 10x price per pull). At the `MaxSummonLuck` of +50%, it is about **5,980 Gold per pull**, above the 4,500 a 10x costs per pull. A player with a levelled God's Blessing can summon and sell in a loop for profit and farm pity for free. See §3 for the new table.

4. **The starter Blade of the Rift is a Legendary labelled Common.** `createDefaultPlayerProfile` calls `CreateArtifact("art_blade_of_the_rift", 3, 1)`. The explicit `1` overrides the seed's `RarityTier = 6`, so the card says Common while the template is a Legendary. If the rarity were fixed instead, new players would start with a 3★ Legendary.
   **Fix:** stop passing rarity at all (`CreateArtifact` already defaults to `seed.RarityTier`), and swap the starter for a Common or Uncommon weapon. Make `CreateArtifact` ignore any rarity that disagrees with the seed, since rarity is inherent.

### P1 — wrong behaviour, misleading UI

5. **"View Artifacts" closes when you click inside it.** The window is a plain `Frame` parented to the scrim `TextButton`. Frames don't sink input, so a click on a card, tab gap or scroll area falls through to the scrim and closes the modal.
   **Fix:** make the window a `TextButton` with `AutoButtonColor = false` and an empty `Activated` handler, like the Forge root, or parent it beside the scrim instead of inside it.

6. **The catalog modal is not fitted or closed with the Forge.** It is a fixed 840 × 540 frame with no `UIScale`/`ModalFit`, so it overflows phones. `Forge:Close` doesn't hide it, so closing the Forge can leave it floating.
   **Fix:** `ModalFit.Bind` it; call `CloseArtifactsModal` from `Close`.

7. **The banner advertises things that don't exist.** The Summon tab still shows "5-STAR FEATURED HERO & ARTIFACTS", "Rate Up" chips for Blade of the Rift and Genesis Sunderer, and a hard-coded "Event Ends: 2d 14h". There is no rate-up and no end date. Showing a rate-up that the server doesn't apply is misleading odds disclosure on a paid random item.
   **Fix:** remove the chips and the timer (§5.2 replaces them with real rates).

8. **The pity roll hard-codes its odds.** The 120th pull used fixed weights (`r * 0.026`). Luck multiplies every upper tier by the same factor, so this happened to match the luck-adjusted split, but it would drift silently if the rates changed.
   **Fix (done):** `tier = SummonLuck.RollAtLeast(tierRates, cfg.PityRarity, math.random())`.

9. **The cap gives no client feedback.** The plan's amber-at-45 state isn't built, the summon buttons stay enabled when full, and `PerformSummon` doesn't check the cap. A full player gets a silent shake plus a server toast. The 10x button should disable at 41+.

10. **Sell-mode selection can go stale.** After a sell, summon or equip from another screen, `SelectedSellUUIDs` can hold UUIDs that no longer exist or are now equipped. The valuation label skips missing ones but not newly equipped ones, and the server will reject the whole batch.
    **Fix:** prune the selection in `RenderAssignView` against the current profile.

11. **The assign signature misses state.** `computeAssignSignature` sums counts, stars and rarities. Selling one artifact and summoning another of the same rarity and star gives the same signature, so the list doesn't redraw. Use a sorted join of `uuid:star:equipped`, or a revision counter bumped by `SyncProfile`.

12. **The Upgrade view can target a sold weapon.** `SelectedTargetUUID` and `FodderUUIDs` aren't cleared when those artifacts disappear. Prune them in `RenderUpgradeView`.

### P2 — leftovers and documentation drift

13. Dead code: `ArtifactCatalog.CraftingMaterials = {}`, the `CraftingRecipeOrder` alias, `BlacksmithUpgradeCosts`/`GetUpgradeCost`, `DefaultStar` on every seed, `RequestUpgradeRarity` (server + `HUDController` line 1376), `formatCraftCost` in `HeroIndex`, the `FORGE_ICONS` crafting map and `CraftingMaterials` lookup in `BackpackModel`. Remove them in one pass.
14. The Revision 1 sell table contradicts its own formula (7★ Common: table 25,000, formula 4,000) and labels donor counts per star wrong (promotion uses 1/2/3/4/5/6 donors, 21 in total to 7★). Replaced in §3.
15. `GAME_DESIGN.MD` still says the Artifact Banner costs **160 / 1,600 Gems** (Summoning Altar, ≈ line 326) and that **first Biome Boss clears drop an artifact** (≈ line 738). `CLAUDE.md` still says 160/1,600 Gems and a 50-pull pity.
16. The header comment of `ForgeController.luau` still says "50-pull pity counter, rate-up featured items" and "cosmic purple aesthetic".

---

## 3. Economy fixes

### 3.1 Sell prices

Selling is a way to clear space and get a little back, never a refund. Target: the expected sell value of a pull stays **under 15% of its cost even at maximum luck**.

| Tier | Old 1★ price | **New 1★ price** |
| :--- | ---: | ---: |
| Common | 1,000 | **100** |
| Uncommon | 2,500 | **250** |
| Rare | 6,000 | **600** |
| Superior | 15,000 | **1,500** |
| Exalted | 40,000 | **5,000** |
| Legendary | 100,000 | **12,000** |
| Mythical | 300,000 | **40,000** |

Formula: `SellPrice = Base(tier) × (1 + 0.5 × (Star − 1))`. This is unchanged. A 7★ weapon contains 22 copies but sells for 4× base, so promotion is never a Gold farm.

Expected value per pull: **≈ 445 Gold at no luck (9.9% of the 10x per-pull price)**, **≈ 657 Gold at +50% luck (14.6%)**. Add a spec that asserts `EV(MaxSummonLuck) < 0.15 × Cost10X / 10`, so later price changes can't reopen the loop.

### 3.2 Promotion donors — decided: same tier and type

Promotion consumed copies of the **same template**. With 84 templates, a specific Exalted Enhanced weapon drops at about 0.02 × 1/6 × 0.4 ≈ **0.13%** per pull, and 7★ needs 21 donors, so high-tier stars were out of reach.

**Decision (done):** a donor is any weapon of the **same rarity tier and weapon type**, either variant (`WeaponPromotion.IsDonorFor`). The Upgrade picker and auto-fill use the same check; auto-fill spends low stars first and Standard before Enhanced. GDD §7 and CLAUDE.md say so.

### 3.3 Starting Gold

New profiles start with 500 Gold and get 1,000 for clearing Floor 1, so the first Forge summon is several Guard Post sessions away. The Forge onboarding step (`ArtifactUpgraded`) still works from the starter duplicates. No change needed, but note the first-summon timing in the GDD so it stays a decision.

---

## 4. Server changes

`DataManager.server.luau`:

- `SellArtifacts`: de-duplicate, cap list length, validate every entry is a string, keep all-or-nothing on equipped/locked. Return the new Gold total so the client can float the delta.
- `SummonArtifact`: pity via `RollAtLeast(tierRates, cfg.PityRarity, …)`. Guard against a nil seed from `GetTierPair` (fall back to the other variant, then error loudly) so a roster gap can't take Gold without granting a weapon.
- `CreateArtifact`: rarity always from the seed.
- `createDefaultPlayerProfile`: Common or Uncommon starter weapons only, all at seed rarity.
- `SyncProfile` migration (profiles aren't persisted yet, but keep the schema honest): clamp `Rarity` to the seed's `RarityTier`, default `ArtifactBanner10Pity` to 0, remap an old `ArtifactBannerPity` above 119 to 119.
- Remove `RequestUpgradeRarity` and `UpgradeArtifactRarity`.

---

## 5. Gilded Grimoire UI redesign

The Forge still runs on the old cosmic-purple palette (`C.Border #C084FC`, raw `Color3.fromHex` violets), Gotham fonts, rounded `UICorner` buttons and emoji. Gilded Grimoire forbids all three. Rules for every Forge surface:

- Frames through `GildedGrimoire.Frame(obj, { Class, Tone })`: **Window** for the Forge and the catalog, **Panel** for sections, **Card** for artifacts, **Button**/**Compact** for controls. No bare `UICorner` + `UIStroke` boxes.
- Tones carry meaning: **Bronze** for anything Gold (prices, sell value, Gold chip), **Crimson** for the destructive sell confirm, **Gold** for the primary action, **Action** for summon buttons (via `GrimoireSummonButton`), **Slate** for disabled or locked, **Deep** for nested panels.
- Fonts: `GildedGrimoire.Fonts.Title / Number / Body` only. Numbers through `StyleText(…, "Number")`.
- Icons: `GrimoireIcons` only. Replace `ICON_MAP` emoji with the archetype drawings (`Vanguard`, `Striker`, `Marksman`, `Miner`, `Scholar`, `Healer`) or the weapon preview from `ArtifactPreview`. Replace `✓`, `✕`, `⚒️` with drawn icons or `GothicBoxStyle.CreateCloseButton`.
- Rarity colour is an accent (card rail, badge, tier header), not a fill.
- Bars through `GildedGrimoire.Bar`.

### 5.1 Header

- Keep the Forge icon and the gold-gradient title. Add a **Bronze Gold chip** at the top right (`GrimoireIcons.IconText("Gold", …)`) showing current Gold, with green/red floaters on change.
- Tabs stay as they are (`StyleTabs`), but drop the dead underline tween code in `SetTab`.

### 5.2 Summon tab

```
┌─ Panel (Violet, gold rail) ─────────────────────────────────────────┐
│  E C H O E S   O F   T H E   R I F T                [ Banner icon ] │
│  84 weapons · every archetype · all drop at 1★                      │
│  ┌ Deep ─────────────────────────────────────────────────────────┐  │
│  │ Common 54.9 · Uncommon 25.0 · Rare 12.0 · Superior 5.5 ·      │  │
│  │ Exalted 2.0 · Legendary 0.5 · Mythical 0.1   (+X% Blessing)   │  │
│  └───────────────────────────────────────────────────────────────┘  │
│  Showcase: rotating ArtifactPreview of one Legendary/Mythical seed  │
│                                      [ VIEW ALL WEAPONS & ODDS ]    │
└─────────────────────────────────────────────────────────────────────┘
  Exalted+ guaranteed in 87      ▕██████████░░░░░░░░░░▏ 33 / 120
  Rare+ guaranteed in 6 pulls
  [ SUMMON 1X  ● 5,000 ]                [ SUMMON 10X  ● 45,000 ]
```

- Remove the watermark, the Rate Up chips, the fake timer, and the procedural rift vortex (its purple gradients clash with the theme).
- Rate strip: one rarity-coloured pill per tier, live from `SummonLuck.ForProfile` (same as the modal). When luck > 0, show a small **Blessing** icon and `+X%`.
- Showcase: a slow-rotating `ArtifactPreview` that cycles the 12 Legendary and Mythical seeds every few seconds, with name and tier badge. That replaces the fake "featured" art with real content.
- Pity: `GildedGrimoire.Bar`, glowing gold at 100+. A second line shows the 10-pull counter from `ArtifactBanner10Pity`.
- Summon buttons: `GrimoireSummonButton` with `Icon = "Gold"`. Disabled (Slate) with a reason line when Gold is short or the inventory can't fit the pull. 10x disables at 41+ artifacts.

### 5.3 Assign tab

- Header row: **capacity pill** (`Artifacts 37 / 50`): Deep normally, Bronze rail at 45+, Crimson at 50, with the full-inventory hint "Sell or promote weapons to make room".
- Filter and sort chips: archetype icons (All + 6) and sort by Rarity / Stars / Power. Replace the current Star-first sort with Rarity, then Stars, then Power.
- Card: rarity rail and badge, weapon preview, name in Title font, stars as drawn icons, variant tag (`Enhanced +20%`), three stat cells, carrier line. Add a **lock toggle** (Lock icon) so players can protect weapons from sell-all. This needs a small `RequestToggleArtifactLock` remote; `Locked` already exists on the instance.
- Sell mode: the header swaps to `Selected 6 · ● 1,850` (Bronze), **Select all Common** / **Select all ≤ Uncommon** quick picks (safer than all), **Sell** (Crimson) and **Cancel**. Selected cards get a Crimson rail and a check stud; equipped or locked cards go Slate with the reason.
- Confirm dialog: one Gilded Grimoire dialog before any sell, listing the count and total. Show it in red when the selection includes Exalted or above.

### 5.4 Upgrade tab

- Keep the layout, re-skin it: target slot as a Card with the rarity rail, donor slots as Slot frames with the archetype icon as placeholder, the preview rows with Number fonts and green deltas.
- Footer: show Gems only when the step costs Gems (4★ and up).
- If §3.2 is accepted, the donor picker lists same-tier, same-type weapons and labels the other variant.

### 5.5 "View all weapons & odds" modal

- Window frame, `CreateCloseButton`, `ModalFit`, input-sinking window (bug 5), closes with the Forge (bug 6).
- Top: the live rate strip and rules line (pity 120 Exalted+, 10-pull Rare+, 60/40 variant, 1★).
- Archetype tabs with icons and counts (All 84, each 14).
- Body grouped by **tier**, highest first: a tier header row (rarity colour, name, live %, per-weapon %), then the Standard and Enhanced cards side by side for each archetype. Per-weapon odds = `rate(tier) / 6 × 0.6` or `× 0.4`; showing them is the clearest odds disclosure.
- Each card: preview, name, variant tag, 1★ Power / Dmg / Spd, a one-line description (full text on hover), and an **Owned** stud if the player has one.

### 5.6 Artifact Index (`HeroIndex.luau`)

- Acquisition line reads from config: `"Blacksmith Forge · " .. StatBalance.Format(Banner.Cost1X) .. " Gold"` instead of a hard-coded string.
- Show the per-weapon drop rate (as in §5.5) and the sell price at 1★.
- Delete `formatCraftCost`.

---

## 6. Tests

Add to `tests/forge.spec.luau`:

- Sell de-duplication: the same UUID three times pays once.
- Sell EV bound at `MaxSummonLuck` (§3.1).
- Pity roll uses luck: `RollAtLeast` with boosted rates never returns below 5.
- Every `(tier, type)` pair has both variants (guards the nil-seed path).
- `CreateArtifact` always uses seed rarity.
- Starter profile contains no weapon above Uncommon.

Static checking: `luau-compile` doesn't catch the `self` crash. Add a `luau-analyze` pass over `src/StarterPlayerScripts/UI/ForgeController.luau` (and ideally all `--!strict` files) to `tests/run.ps1`. The undefined-global warning would have caught bug 1.

---

## 7. Implementation order

1. **Hotfix (P0)**: bugs 1–4 and the new sell table, with their specs. Ship this alone; it unbreaks the Assign tab and closes the Gold exploit.
2. **Server polish**: pity luck, nil-seed guard, migration, lock remote, dead remote removal.
3. **Client correctness**: bugs 5–6 and 9–12.
4. **Gilded Grimoire pass**: header, Summon, Assign, Upgrade, modal (§5.1–5.5).
5. **Index**: §5.6.
6. **Cleanup**: P2 item 13.
7. **Docs**: GDD (Summoning Altar line, biome boss artifact line, sell table, donor rule if changed) and CLAUDE.md core facts.
8. `pwsh tests/run.ps1`, then a Studio playtest.

The donor rule (§3.2) is decided: same tier and type.

---

## 8. How to test (Studio)

1. Open the Forge, go to **Assign**: cards render, no errors in Output.
2. Toggle sell mode, select two weapons, sell: Gold rises by exactly the shown total (new prices), cards disappear, capacity drops.
3. Try to sell an equipped or locked weapon: it can't be selected.
4. With 41+ artifacts, the 10x button is disabled with a reason; at 50, both are.
5. Summon 1x and 10x with enough Gold: every result is 1★, the 10x contains a Rare or better, the pity bar moves.
6. Set `ArtifactBannerPity = 119` (DEV command or Studio MCP) and pull once: Exalted or above, pity resets.
7. Open **View all weapons & odds**: click inside cards and tabs and it stays open; tabs filter; percentages match the rate strip; closing the Forge closes it.
8. New profile: no starter weapon is labelled above Uncommon.
9. Resize to the mobile preset: the Forge and the modal fit the screen.

---

## Appendix — The 84-weapon roster (unchanged from Revision 1)

Display names below are the plan's; a few template IDs keep legacy names (for example `art_rusty_daggers` is Rogue Daggers, `art_necronomicon_pages` is Codex of the Deep). `ArtifactCatalog.luau` is authoritative.

The roster defines exactly **2 artifacts per archetype for every rarity tier** ($6 \times 7 \times 2 = 84$ weapons), ensuring that every single hero class has immediate weapon options at every progression milestone.

---

#### Tier 1: Common (`#B0B0B0`) — 54.9% Base Rate
*Base Stats: Standard = 20 Power, $+5.0\%$ ATK SPD | Enhanced = 24 Power, $+6.0\%$ ATK SPD*

1. **Vanguard (`SWORD_SHIELD`)**:
   - **Standard: Iron Broadsword**: Utilitarian cast-grey iron blade with rough fuller hammer marks and wooden corner-banded heater shield.
   - **Enhanced: Tempered Bastard Sword**: Double-quenched carbon steel blade with fluted crossguard and reinforced steel buckler.
2. **Striker (`DAGGERS`)**:
   - **Standard: Rogue Daggers**: Pair of simple drop-point trench daggers with leather cord wraps and blackened tips.
   - **Enhanced: Serrated Skewers**: Deeply serrated butchering daggers with curved knuckle rings and brass pommel weights.
3. **Marksman (`BOW`)**:
   - **Standard: Hunter's Shortbow**: Lightweight curved yew hunting bow with waxed hemp string and smooth ash grip.
   - **Enhanced: Reinforced Yew Longbow**: Stouter yew stave backed with cured tendon cordage, firing heavy field arrows.
4. **Miner (`AXE`)**:
   - **Standard: Prospector's Cleaver**: Wedge-profile industrial steel axe with beveled cutting bevel and pick spike butt.
   - **Enhanced: Heavy Hewing Axe**: Broad-faced logging axe with hardened wedge bit and counter-weighted iron poll.
5. **Scholar (`STAFF`)**:
   - **Standard: Apprentice Wand-Staff**: Slender birch rod with polished copper socket holding cloudy river quartz focus.
   - **Enhanced: Scholar's Spire**: Carved rowan staff banded with brass astrological markings and faceted amber focus.
6. **Healer (`TOME`)**:
   - **Standard: Novice Prayerbook**: Pocket calfskin booklet inscribed with foundational cleansing scriptures and linen clasp.
   - **Enhanced: Acolyte's Litany**: Embossed pigskin codex with stamped brass corner fittings and soothing verse marginalia.

---

#### Tier 2: Uncommon (`#4BB543`) — 25.0% Base Rate
*Base Stats: Standard = 60 Power, $+7.5\%$ ATK SPD | Enhanced = 72 Power, $+9.0\%$ ATK SPD*

7. **Vanguard (`SWORD_SHIELD`)**:
   - **Standard: Runic Longsword**: Cobalt-treated steel knightly blade etched with faint emerald rune grooves and matching runic pavise.
   - **Enhanced: Knightly Estoc**: Needle-pointed triangular thrusting sword with full basket hilt and convex teardrop kite shield.
8. **Striker (`DAGGERS`)**:
   - **Standard: Viper Kris**: Flamboyant serpentine wavy-bladed daggers tipped with emerald venom gloss and snake-eye brass hilts.
   - **Enhanced: Silent Dirk Pair**: Needle-point stiletto dirks with non-reflective blued steel blades and lead-dampened guards.
9. **Marksman (`BOW`)**:
   - **Standard: Wind-Scout Recurve**: Slender composite recurve layered with pale ashwood, horn tips, and falcon feather accents.
   - **Enhanced: Gale-Force Composite**: Deeply reflexed composite bow bound in emerald silk sinew with carved ivory riser tips.
10. **Miner (`AXE`)**:
    - **Standard: Canyon Splitter**: Heavy dwarven wedge axe with raw amethyst geode chips embedded into the spine.
    - **Enhanced: Quakestone Greataxe**: Broad bearded mining axe forged of grey granite-tempered steel with hexagonal brass shaft.
11. **Scholar (`STAFF`)**:
    - **Standard: Ruby Channeling Staff**: Polished hickory staff holding an uncut igneous crystal head that amplifies casting cadence.
    - **Enhanced: Pyromancer's Torch-Rod**: Dark iron rod terminating in an open-caged brazier casting continual fiery ember wisps.
12. **Healer (`TOME`)**:
    - **Standard: Cleric Scripture**: White calfskin volume with silver-embossed holy wards and trailing azure silk bookmark ribbons.
    - **Enhanced: Mendicant's Psalter**: Gold-leafed prayerbook with illuminated margins depicting dawn light and soothing aura petals.

---

#### Tier 3: Rare (`#2980B9`) — 12.0% Base Rate
*Base Stats: Standard = 180 Power, $+10.0\%$ ATK SPD | Enhanced = 216 Power, $+12.0\%$ ATK SPD*

13. **Vanguard (`SWORD_SHIELD`)**:
    - **Standard: Paladin Spatha**: Noble chivalric broadsword with winged crossguard and radiant sun-crested heater shield.
    - **Enhanced: Vanguard Warden Bastion**: Heavy tower-blade with full-length blood channel and massive scalloped fortress shield.
14. **Striker (`DAGGERS`)**:
    - **Standard: Shadow Fangs**: Twin obsidian stilettos trailing purple-black abyssal smoke, set in skeletal dragon-rib hilts.
    - **Enhanced: Phantom Stiletto**: Translucent spirit-glass blades that blur into ethereal silhouettes during rapid thrusts.
15. **Marksman (`BOW`)**:
    - **Standard: Stormstrider Longbow**: Tall elven recurve inlaid with storm-silver alloy and eagle-wing riser accents.
    - **Enhanced: Thunderhead Recurve**: Taut recurve wrapped in coiled copper lightning wires that discharge spark showers on draw.
16. **Miner (`AXE`)**:
    - **Standard: Warforged Battleaxe**: Symmetrical twin-bearded dwarven axe forged from dark gunmetal iron with bronze geometric inlays.
    - **Enhanced: Iron-Juggernaut Cleaver**: Asymmetrical slab-iron executioner axe with heavy boiler-plate rivets and counterbalance hammer.
17. **Scholar (`STAFF`)**:
    - **Standard: Frostweaver Scepter**: Pale driftwood staff crowned with an intricate snowflake crystal radiating drifting frost mist.
    - **Enhanced: Glacial Monolith**: Translucent blue glacial ice rod suspended with floating frost-rime shards orbiting the crown.
18. **Healer (`TOME`)**:
    - **Standard: Hermetic Grimoire**: Aged midnight-blue velvet book bound in wrought-iron brackets with a glowing alchemy circle.
    - **Enhanced: Restorative Codex**: Embossed silver-leaf volume that floats open, turning pages automatically upon mana contact.

---

#### Tier 4: Superior (`#8E44AD`) — 5.5% Base Rate
*Base Stats: Standard = 540 Power, $+13.0\%$ ATK SPD | Enhanced = 648 Power, $+15.0\%$ ATK SPD*

19. **Vanguard (`SWORD_SHIELD`)**:
    - **Standard: Crystal Claymore**: Translucent amethyst-bladed greatsword paired with an interlocking prismatic crystal barrier.
    - **Enhanced: Resonant Bulwark**: Vibrating sonic steel broadsword with an acoustic hexagonal aegis that deflects kinetic blows.
20. **Striker (`DAGGERS`)**:
    - **Standard: Phantom Edge**: Semitransparent spirit glass daggers with ornate filigree crossguards and phase-strike luminescence.
    - **Enhanced: Nightstalker Katar**: Punching katars forged of black meteoric iron with dual glowing violet plasma edges.
21. **Marksman (`BOW`)**:
    - **Standard: Crystal Greatbow**: Towering prismatic mana-quartz bow with condensed cerulean mana string that hums melodically.
    - **Enhanced: Prismatic Arbalest**: Intricate crystal-limbed mechanical greatbow with floating mana focus sights.
22. **Miner (`AXE`)**:
    - **Standard: Magma Cleaver**: Volcanic black basalt axe head fractured with molten lava veins and an obsidian counter-spike.
    - **Enhanced: Obsidian Hell-Splitter**: Solid jagged volcanic glass double axe billowing white sulfur smoke along its searing edge.
23. **Scholar (`STAFF`)**:
    - **Standard: Archmage Caduceus**: Petrified ebony wood staff with entwined brass serpents suspending a hovering multi-faceted arcane prism.
    - **Enhanced: Chronomancer's Spindle**: Ornate brass clockwork staff with spinning interlocking astrolabe gears around a quartz core.
24. **Healer (`TOME`)**:
    - **Standard: Sanctuary Gospel**: Valeria's signature grimoire style: Gold-leaf spine with emerald centerpiece emitting restorative motes.
    - **Enhanced: Seraph's Testament**: Gilded cathedral tome whose pages radiate warm golden feathered halos when healing spells are cast.

---

#### Tier 5: Exalted (`#D35400`) — 2.0% Base Rate (Hard Pity Target)
*Base Stats: Standard = 1,400 Power, $+16.5\%$ ATK SPD | Enhanced = 1,680 Power, $+18.5\%$ ATK SPD*

25. **Vanguard (`SWORD_SHIELD`)**:
    - **Standard: Holy Claymore**: Consecrated white-silver executioner sword with angelic wing quillons and radiant sunburst kite shield.
    - **Enhanced: Aegis of Valor**: Gilded royal arming sword paired with an incandescent solar shield projecting humming barrier domes.
26. **Striker (`DAGGERS`)**:
    - **Standard: Bloodthirst Twinblades**: Jagged crimson Damascus demonic falchions with arterial filigree dripping phantom blood embers.
    - **Enhanced: Crimson Carnage**: Asymmetrical curved demonic scythe-daggers forged of living bone that thrum with predatory frenzy.
27. **Marksman (`BOW`)**:
    - **Standard: Phoenix Greatbow**: Swept crimson-gold limbs sculpted like flaming phoenix wings emitting rippling heat shimmers.
    - **Enhanced: Solar Flare Recurve**: Blinding incandescent bow with floating corona rings that materializes searing sunlight javelins.
28. **Miner (`AXE`)**:
    - **Standard: Titan Earthshaker**: Monumental runic double axe with dwarven runes pulsing seismic tremors across the earth.
    - **Enhanced: Mountain Breaker**: Massive monolithic stone-and-gold greataxe that fissures the bedrock with localized shockwaves.
29. **Scholar (`STAFF`)**:
    - **Standard: Pillar of Muspelheim**: Dark iron battle-staff with open caged brazier containing an eternal roiling miniature flame star.
    - **Enhanced: Void Channeler**: Abyssal black-stone staff crowned with a miniature gravitational singularity dragging light inward.
30. **Healer (`TOME`)**:
    - **Standard: Codex of the Deep**: Aged forbidden leather tome with an iridescent demonic eye on the cover that blinks rhythmically.
    - **Enhanced: Lifebinder's Chronicle**: Living wooden-covered grimoire entwined with blooming sacred vines that shed luminescent pollen.

---

#### Tier 6: Legendary (`#F1C40F`) — 0.5% Base Rate (Hard Pity Eligible)
*Base Stats: Standard = 3,500 Power, $+20.0\%$ ATK SPD | Enhanced = 4,200 Power, $+22.5\%$ ATK SPD*

31. **Vanguard (`SWORD_SHIELD`)**:
    - **Standard: Blade of the Rift**: Dimensional cosmic glass blade swirling with inner nebula stars and antique cathedral portal shield.
    - **Enhanced: Aegis Core**: Hexagonal floating segmented gold plates orbiting a hyper-dense glowing rift power core.
32. **Striker (`DAGGERS`)**:
    - **Standard: Eclipse Daggers**: Opposing celestial twins: one forged of lunar silver, one of solar gold, with crescent eclipse guards.
    - **Enhanced: Abyssal Razor**: Void-matter shadow daggers that leave pitch-black cuts suspended in three-dimensional space.
33. **Marksman (`BOW`)**:
    - **Standard: Celestial Zenith**: Pristine white marble and polished gold riser with floating orbital ring sights and starlight string.
    - **Enhanced: Supernova Greatbow**: Colossal cosmic recurve radiating stellar flares that nocks superheated fusion plasma bolts.
34. **Miner (`AXE`)**:
    - **Standard: Valkyrie Waraxe**: Elegant winged golden waraxe with braided platinum shaft and cyan celestial teardrop gems.
    - **Enhanced: World Shaper**: Mythic foundry greataxe with burning celestial brass conduits and an anti-gravity core.
35. **Scholar (`STAFF`)**:
    - **Standard: Solaris Sun Scepter**: Golden solar eclipse crown with rotating orbital rings suspending an incandescent sun core.
    - **Enhanced: Chronos Time-Weft**: Complex astronomical clockwork mechanism rotating in 3D around an unmoving time singularity.
36. **Healer (`TOME`)**:
    - **Standard: Seraphic Liturgy**: Heavy gilded cathedral tome that floats opened with radiating translucent golden wings extending from the spine.
    - **Enhanced: Divine Providence**: Radiant crystalline codex made of prism diamond leaves that project prismatic restorative beams.

---

#### Tier 7: Mythical (`#E74C3C`) — 0.1% Base Rate (Hard Pity Eligible)
*Base Stats: Standard = 7,000 Power, $+30.0\%$ ATK SPD | Enhanced = 8,400 Power, $+35.0\%$ ATK SPD*

37. **Vanguard (`SWORD_SHIELD`)**:
    - **Standard: Astral Executioner**: Starlight alloy chisel-tipped blade with constellation runes and monolithic starry mirror shield.
    - **Enhanced: Worldbreaker Bastion**: Colossal cosmic bastion forged from a collapsed star; gravitational lensing warps space around its rim.
38. **Striker (`DAGGERS`)**:
    - **Standard: Abyssal Ravagers**: Floating dark-matter phantom daggers tethered by purple lightning arcs around the hero's wrists.
    - **Enhanced: Void Reapers**: Twin rift scythe-daggers that slice through the fabric of dimensions, leaving tearing cosmic rifts.
39. **Marksman (`BOW`)**:
    - **Standard: Cosmic Sagittarius**: Astrea's pinnacle relic: stave formed of pure starlight constellation lines; nocks pure energy lances.
    - **Enhanced: Infinity Bow of Genesis**: Transcendent cosmic arc whose string is a beam of creation light, firing arrows that warp space-time.
40. **Miner (`AXE`)**:
    - **Standard: World Carver**: Monolithic dark-matter greataxe crackling with rift lightning that leaves trailing space rifts when swung.
    - **Enhanced: Genesis Sunderer**: Colossal primordial axe infused with the spark of planetary creation; seismic ripples shatter reality.
41. **Scholar (`STAFF`)**:
    - **Standard: Eye of the Singularity**: Stave of black cosmic glass culminating in an event horizon core that bends ambient light.
    - **Enhanced: Omega Archon Caduceus**: Primordial staff crowned by an uncoiling infinity loop of cosmic plasma, channeling raw arcane genesis.
42. **Healer (`TOME`)**:
    - **Standard: Akashic Infinity**: Boundless astral codex without covers: floating holographic tablets orbiting an ethereal singularity.
    - **Enhanced: Book of Primordial Genesis**: Transcendent scripture of life itself, written in eternal light that resurrects fallen allies and grants immortality.

---
