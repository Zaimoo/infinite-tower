# Stat scaling implementation verification

Verified in the local checkout and Roblox Studio on 2026-10-22. Branch: `codex/stat-scaling-overhaul`. The place was not published.

## Implemented

- Canonical four-stat snapshots use immutable hero seeds, 3× hero-star growth, 8% compounded level growth, bounded quality, fixed movement speed, and rarity/star weapon power. Hero promotion retains the current level and releases bounded stored XP through ordinary levels.
- Weapon rarity stays fixed; stars progress from 1 to 7. Enhancement levels and retired trait/imprint bonuses do not affect stats. Legacy save fields are retained without conversion or refunds.
- Atomic star promotion validates exact distinct same-template donors, inventory ownership, locks, both equip links, resources, and the cap before mutation. The final step consumes six copies, 250,000 Gold, and 500 Gems.
- Deployment, recurring combat updates, explicit progression refresh, squad selection, and equipped DPS estimates resolve the weapon from the profile. Damage, health, and attack interval refresh together.
- All 50 floors share the stat curve. The existing floor-1/floor-5 encounter director consumes those HP/ATK values without changing placements, enemy attacks, rewards, or available encounters.
- Forge shows fixed rarity, current/next stars, power, speed, equipped hero damage/DPS, exact costs, and six donor slots. Hero cards expose the four stats; large combat/UI values use K/M/B/T formatting.

## Checks

| Check | Result |
| --- | --- |
| Production Luau compilation | Passed for every production script |
| Automated regressions | 107 passed: 52 Pit, 12 Forge/stat, 9 tower foundation, 12 transport, 22 combat |
| Independent reference model | Passed all 50 floor rows, promotion continuity, quality boundaries, and 784 hero/rarity/weapon-star combinations |
| Luau parity sweep | All 784 hero/weapon combinations match the damage, health, and attack-speed equations |
| Weapon transactions | Every star step; exact final cost; replay rejection; duplicate/self/foreign/missing/locked/equipped donor rejection; insufficient/malformed funds/progression cases |
| Retired bonuses | Imprint, passive trait fields, legacy Blood Pact flag, and weapon Level cannot restore stat bonuses |
| Studio startup | Native server and client started; game server error audit returned an empty list |
| Studio promotion | Real DataManager operation promoted Mythical 6→7, preserved rarity/speed, charged exact resources, and rejected replay |
| Studio UI | Six slots, fixed rarity, exact costs, max-star state, and 307.97M→492.64M Han DPS preview passed native assertions and visual inspection |
| Studio source audit | All 16 intended script bodies matched the final merged sources after stopping Play; temporary test scripts absent |

Run the automated checks with:

```powershell
node docs/balance/stat-scaling-model.cjs --check
.\tests\run.ps1
```

## Controlled live DPS fixture

The manual fixture is [studio-stat-verification.server.luau](../../tests/studio-stat-verification.server.luau). It is outside the Rojo source tree. Run it only as a temporary Script in the **Studio Play server**, with a loaded player. It restores the session profile and encounter actors after completion. Stop Play after testing.

Five class-compatible weapons were explicitly constructed at Mythical 7-star for Han/Jenna/Aaron/Velkist/Eolka, all 5-star, level 50, quality 1.00, rested. The authored floor-5 room hosted a stationary boss with the floor-50 HP budget (110,844,632,813), incoming attacks suppressed, and other targets excluded. This tests full-contact damage through the real combat loop; it does not represent ordinary acquisition or released floor-50 content.

After five seconds of positioning, the final run measured **31,509,434,278 actual HP removed in 12.0156 seconds**, or **2.622B DPS**. The scheduled steady-state equation gives **2.550B DPS**. Finite sampling windows and attack phase account for the small difference; no overkill was counted.

The separate minimum-quality (0.90), 75%-uptime calculation remains **1.721B DPS**. This is a numerical uptime model, not a measured dodging encounter.

Native floor-5 spawn checks confirmed regular HP 980/ATK 6, elite HP 3,920/ATK 12, and boss HP 22,050/ATK 16. Original Gold rewards remained 80/210/991.

## Protected changes and remaining integration work

This patch leaves the artifact banner implementation, acquisition probabilities/prices/pity, crafting recipes, drops, rewards, navigation, geometry, and GDD Section 7.4 unchanged. The colleague's newer hero-banner pity work, Forge banner-symbol change, and plot ownership guards were preserved in Studio during the final merge. Those Studio-only changes are not copied into this branch's stat-only repository diff.

Acquisition still needs its owner's rarity/star contract integration: the existing artifact banner supplies Common rarity and rolled stars. The benchmark does not grant Mythical items or alter those pulls. Legacy shield/ring items and trait/imprint menus/transactions remain for their owner's feature cleanup, with their stat bonuses retired here.

PvP's existing 25% coefficient and raw-damage reward contribution rules remain unchanged. Their compatibility with billion-scale damage is still separate integration work. No publishing or production inventory migration was performed.
