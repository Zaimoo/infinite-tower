# DOCUMENT 3: ECONOMY, PROGRESSION MATH & BALANCING TABLES
**Project Codename:** *Project: Waiting Room*  
**Architecture Standard:** Zero Server-Side Humanoids | Gold & Gems Economy | Equippable Artifacts & Blacksmith Ascension  
**Spreadsheet Compatibility:** All tables below use strict, flat Markdown column formatting designed for direct copy-paste into **Google Sheets** or **Microsoft Excel**.

---

## 1. HERO SEED TABLE (LAUNCH ROSTER)

### 1.1 Launch Roster & World Boss Exclusive Seed Table
- **Banner Pool Cost:** `100 Gems` (Single Pull) | `900 Gems` (10x Pull).
- **Banner Drop Rates:** `1★ Common (70%)`, `2★ Rare (25%)`, `3★ Epic (5%)`. `4★` and `5★` are obtained exclusively via **Star Promotion**.
- **Stat Normalization Note:** In the table below, **Native Star Stats** show the exact stats when summoned at their base Star tier (`Level 1`, `QualityScalar = 1.00`), while **1★ Base Equivalent** shows the underlying $S=1$ seed values before the $3^{(S-1)}$ (Combat) and $1.35^{(S-1)}$ (Labor) Star Promotion multipliers.

| Hero ID | Hero Name | Origin / Banner Pool | Base Star | Archetype | Native Health (Lv.1) | Native Attack Damage (Lv.1) | 1★ Base HP | 1★ Base ATK | Attack Interval (s) | Attacks / Sec | Movement Speed (Studs/sec) | Native Base DPS (Lv.1) | Attack Range (Studs) | Native Base Labor (/min) | 1★ Base Labor (/min) | Preferred Facility (+25% Labor) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `hero_han` | **Han** | Standard Banner (25.0% Net) | 1★ | Striker | 300 | 40 | 300 | 40 | 0.85 | 1.18 | 20 | 47.06 | 6 | 14.0 | 14.0 | None |
| `hero_jenna` | **Jenna** | Standard Banner (22.5% Net) | 1★ | Marksman | 210 | 34 | 210 | 34 | 0.80 | 1.25 | 20 | 42.50 | 28 | 13.0 | 13.0 | None |
| `hero_catio` | **Catio** | Standard Banner (22.5% Net) | 1★ | Miner | 280 | 24 | 280 | 24 | 1.05 | 0.95 | 20 | 22.86 | 6 | 20.0 | 20.0 | None |
| `hero_aaron` | **Aaron** | Standard Banner (13.0% Net) | 2★ | Vanguard | 1,350 | 84 | 450 | 28 | 1.10 | 0.91 | 20 | 76.36 | 7 | 21.6 | 16.0 | Infirmary |
| `hero_velkist` | **Velkist** | Standard Banner (12.0% Net) | 2★ | Striker | 900 | 132 | 300 | 44 | 0.75 | 1.33 | 20 | 176.00 | 6 | 18.9 | 14.0 | None |
| `hero_eolka` | **Eolka** | Standard Banner (5.0% Net) | 3★ | Scholar | 2,070 | 468 | 230 | 52 | 1.00 | 1.00 | 20 | 468.00 | 30 | 40.1 | 22.0 | None |
| `hero_archon` | **Sovereign Archon** | World Boss Exclusive (RNG / 100% Pity) | 3★ | Striker | 3,150 | 585 | 350 | 65 | 0.80 | 1.25 | 20 | 731.25 | 14 | 45.6 | 25.0 | All Facilities (+25%) |


---

## 2. STAR PROMOTION & LEVELING CURVE TABLES (1★ LV.1 TO 5★ LV.50)

### 2.1 Core Progression Formulas (Google Sheets Ready)
- **Max Level Cap:** `MaxLevel = Stars * 10`
- **XP Required for Level $L \to L+1$:** `=ROUND(50 * (L ^ 1.45), 0)`
- **Synthesis ("The Pit") Fodder Base XP:** `base = (100 * (3 ^ (FodderStars - 1))) + (25 * FodderLevel)`
- **Level Efficiency Scaling:** `efficiency = MAX(0.55, 1 - 0.025 * MAX(0, RecipientLevel - FodderLevel - 5))`
- **Star Promotion Multipliers (Per Star above 1★):** `CombatMult = 3 ^ (Stars - 1)` | `LaborMult = 1.35 ^ (Stars - 1)`
- **Level Stat Scaling:** `+8% compounded damage and health per Level above 1` (`1.08 ^ (L - 1)`) | `+5% Labor Output per Level above 1` (`1 + 0.05 * (L - 1)`)

- **Promotion:** Keep the current level; increase its cap by 10. Derive damage/health once from immutable one-star seeds, with no trait or imprint factor.
- **Weapon Power:** `=InherentRarityPower*WeaponStarMultiplier`; inherent rarity stays fixed and stars progress from 1 to 7. There are no enhancement levels.
- **Attack Damage:** `=ROUND(SeedDamage*Quality*3^(Stars-1)*1.08^(Level-1)*(1+WeaponPower/40),0)`
- **Health:** `=ROUND(SeedHealth*Quality*3^(Stars-1)*1.08^(Level-1),0)`
- **Attack Speed:** `=MIN(5,BaseAttackSpeed*(1+InherentRaritySpeedBonus)*OverdriveMultiplier)` attacks/s. Stars and levels do not multiply speed.
- **Movement Speed:** 20 studs/s for launch heroes; it does not inherit exponential damage/health growth.
- **5 Hz DPS:** `TickInterval=0.20*CEILING((1/AttackSpeed)/0.20,1)`; `DPS=AttackDamage/TickInterval`. Use a small floating-point tolerance at exact tick boundaries, as in the calculator.
- **Stat reference:** [Generated tables](balance/STAT_SCALING_TABLES.md) and [50-floor stat CSV](balance/FLOOR_SCALING.csv). These model calculations do not change drops, pity, rewards, navigation, or acquisition rules. Runtime implementation remains pending.

### 2.2 Star Promotion Milestone & Reference Stat Table (`Han` — 1★ Base to 5★ Lv.50)
*Reference Hero: Han (one-star seeds: 300 health, 40 damage, 0.85s interval, 20 studs/s movement, 14 labor/min), quality 1.00, no weapon, traits, imprints, or facility synergy. Promotion retains level. Cumulative level XP follows the existing XP formula; Gold and stone prices are retained.*

| Milestone | Hero stars | Level | Level cap | Cumulative level XP | Promotion Stones | Promotion Gold | Star damage/health factor | Level damage/health factor | Unarmed damage | Health | Scheduled DPS | Overdrive DPS | Labor/min (no synergy) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1★ Base Summon | 1 | 1 | 10 | 0 | — | — | 1.00x | 1.0000x | 40 | 300 | 40.00 | 50.00 | 14.00 |
| 1★ Mid-Level | 1 | 5 | 10 | 806 | — | — | 1.00x | 1.3605x | 54 | 408 | 54.00 | 67.50 | 16.80 |
| 1★ Max Level | 1 | 10 | 10 | 5,064 | — | — | 1.00x | 1.9990x | 80 | 600 | 80.00 | 100.00 | 20.30 |
| Promote 1★ -> 2★ | 2 | 10 | 20 | 5,064 | 1 | 1,500 | 3.00x | 1.9990x | 240 | 1,799 | 240.00 | 300.00 | 27.41 |
| 2★ Mid-Level | 2 | 15 | 20 | 14,284 | — | — | 3.00x | 2.9372x | 352 | 2,643 | 352.00 | 440.00 | 32.13 |
| 2★ Max Level | 2 | 20 | 20 | 29,528 | — | — | 3.00x | 4.3157x | 518 | 3,884 | 518.00 | 647.50 | 36.86 |
| Promote 2★ -> 3★ | 3 | 20 | 30 | 29,528 | 3 | 7,500 | 9.00x | 4.3157x | 1,554 | 11,652 | 1,554.00 | 1,942.50 | 49.75 |
| 3★ Mid-Level | 3 | 25 | 30 | 51,661 | — | — | 9.00x | 6.3412x | 2,283 | 17,121 | 2,283.00 | 2,853.75 | 56.13 |
| 3★ Max Level | 3 | 30 | 30 | 81,433 | — | — | 9.00x | 9.3173x | 3,354 | 25,157 | 3,354.00 | 4,192.50 | 62.51 |
| Promote 3★ -> 4★ | 4 | 30 | 40 | 81,433 | 8 | 35,000 | 27.00x | 9.3173x | 10,063 | 75,470 | 10,063.00 | 12,578.75 | 84.39 |
| 4★ Mid-Level | 4 | 35 | 40 | 119,511 | — | — | 27.00x | 13.6901x | 14,785 | 110,890 | 14,785.00 | 18,481.25 | 93.00 |
| 4★ Max Level | 4 | 40 | 40 | 166,504 | — | — | 27.00x | 20.1153x | 21,725 | 162,934 | 21,725.00 | 27,156.25 | 101.61 |
| Promote 4★ -> 5★ | 5 | 40 | 50 | 166,504 | 18 | 150,000 | 81.00x | 20.1153x | 65,174 | 488,802 | 65,174.00 | 81,467.50 | 137.18 |
| 5★ Mid-Level | 5 | 45 | 50 | 222,974 | — | — | 81.00x | 29.5560x | 95,761 | 718,210 | 95,761.00 | 119,701.25 | 148.80 |
| 5★ Max Level | 5 | 50 | 50 | 289,443 | — | — | 81.00x | 43.4274x | 140,705 | 1,055,286 | 140,705.00 | 175,881.25 | 160.43 |

### 2.3 The Pit Recipes & Conversion Table
- **Soul Essence Conversion:** Disassembling heroes in The Pit yields Soul Essence based on Star tier (`1★: 4`, `2★: 12`, `3★: 36`, `4★: 108`, `5★: 324`) plus bonus essence for invested levels (`+1 per 5 levels`) and imprint ranks (`+2 per rank`).
- **Deterministic Crafting:**

| Recipe Product | Gold Cost | Gems Cost | Soul Essence Cost | Output | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Promotion Stone** | 100 Gold | 20 Gems | 8 Soul Essence | 1x Stone | Required sacrifice for Star Promotions ($1★ \to 5★$). |
| **Imprint Catalyst**| 150 Gold | 15 Gems | 4 Soul Essence | 1x Catalyst | Required consumable for 100% deterministic Imprint transfers. |

---

## 3. MOB & WORLD BOSS SCALING TABLE

| Entity ID | Entity Name | Zone / Ring | Spawn Count / Cap | Base HP | ATK | Attack Interval (s) | Respawn Time (s) | Direct Wallet Gold | Mana Geode Drop % (-15% Spd) | Cursed Urn Drop % (-25% Spd) | Abyssal Core Drop % (-35% Spd) | Calamity Heart Drop % (-45% Spd) | AoE Telegraph Shape & Size | AoE Telegraph Cast Time (s) | AoE Cooldown (s) | Special Mechanic / Hazard |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `mob_mana_node` | **Mana Crystal Cluster** | Ring 1 / Central Tower | 14 Nodes | 450 | 0 | 0.00 | 8.0 | 45 | 25.0% | 0.0% | 0.0% | 0.0% | None | 0.0 | 0.0 | Passive resource node; zero stamina damage back to squad |
| `mob_ruin_crawler` | **Ruin Scavenger** | Ring 1 / Central Tower | 16 Mobs | 850 | 18 | 1.40 | 6.0 | 80 | 30.0% | 0.0% | 0.0% | 0.0% | None | 0.0 | 0.0 | Standard starter combat mob |
| `mob_stone_sentinel` | **Mossbound Sentinel** | Ring 1 / Tower Platforms | 8 Mobs | 2,200 | 35 | 1.80 | 12.0 | 210 | 60.0% | 5.0% | 0.0% | 0.0% | Circle (R = 10 studs) | 2.0 | 12.0 | Teaches new Masters `[E]` Recall Whistle timing; causes Carrier Fumble |
| `elite_corrupted_stalker` | **Corrupted Stalker** | Ring 2 (R: 120–280) | 10 Elites | 6,500 | 85 | 1.10 | 15.0 | 550 | 15.0% | 40.0% | 4.0% | 0.0% | Cone (90°, R = 16 studs) | 1.6 | 9.0 | Fast gap-closer; stuns Relic Carrier for 1.0s & forces Fumble |
| `elite_blighted_treant` | **Blighted Elder Treant** | Ring 2 (R: 120–280) | 6 Elites | 14,000 | 140 | 1.60 | 22.0 | 1,100 | 0.0% | 65.0% | 10.0% | 0.0% | Circle (R = 22 studs) | 2.2 | 11.0 | High-density Ring 2 Elite; drains Hero Stamina if not recalled |
| `elite_abyssal_exec` | **Abyssal Executioner** | Ring 2 (R: 120–280) | 4 Rare Elites | 32,000 | 240 | 1.40 | 45.0 | 2,600 | 0.0% | 45.0% | 35.0% | 0.0% | Cross + Circle (R = 26 studs) | 2.0 | 10.0 | Guards Ring 2 choke points; prime ambush hazard for Relic Carriers |
| `boss_rift_warden` | **The Rift Warden (Floor Boss)**| Ring 3 Altar (R: 0–120) | Summoned Boss | 95,000 | 360 | 1.25 | On Summon | 6,000 | 0.0% | 100.0% (x1) | 100.0% (x1) | 0.0% | Ring Donut (R = 15–55 studs) | 2.5 | 14.0 | Guaranteed 1x Cursed Urn and 1x Abyssal Core physical drop |
| `world_boss_sovereign`| **Dimensional Sovereign** | Ring 3 Center Altar | Every 20 Mins | Dynamic (`>=75,000`) | 420 | 1.20 | 1,200.0 | See Direct Table | 0.0% | 0.0% | 0.0% | 100.0% (On Kill) | **Devouring Nova** (R = 0–85 studs) | **3.0** | **20.0** | Expanding red AoE; drops **The Calamity Heart** (15s Rank #1 Lock) |

### 3.1 World Boss Direct Loot Payout Table
Qualification: Masters must deal $\ge 3.0\%$ of Boss total HP to qualify for rank-based rewards.

| DPS Rank | Gems Awarded | Gold Awarded | Sovereign Archon (3★) Drop Chance | Boss Pity Gained |
| :---: | :---: | :---: | :---: | :---: |
| **#1** | **1,000 Gems** | **10,000 Gold** | **15.0%** | **0%** (1st gets Calamity Heart lock) |
| **#2** | **750 Gems** | **7,500 Gold** | **10.0%** | **+5%** |
| **#3** | **550 Gems** | **5,500 Gold** | **7.0%** | **+5%** |
| **#4** | **400 Gems** | **4,000 Gold** | **4.0%** | **+10%** |
| **#5** | **300 Gems** | **3,000 Gold** | **2.5%** | **+10%** |
| **#6** | **250 Gems** | **2,500 Gold** | **1.5%** | **+10%** |

---

## 4. WAITING ROOM TYCOON ECONOMY TABLES (LEVELS 1–5)

### 4.1 Facility Upgrade & Production Table (Levels 1–5)
*Formulas:*
- **The Infirmary (`Stamina/sec` & `Coma Duration`):** `StaminaRegen = 2.5 + (0.4 * Level) + (0.06 * SumEffectiveLabor)` | `ComaSec = MAX(20, 60 / (1 + 0.05 * (Level - 1) + 0.008 * SumEffectiveLabor))`
*(Worker Benchmarks below use **Aaron** for Infirmary).*

| Facility Name | Facility Level | Upgrade Cost (Gold) | Max Worker Slots | Facility Level Mult | Base Output / Min (0 Workers) | Output / Min (1★ Lv.10 Workers Filled) | Output / Min (2★ Lv.20 Workers Filled) | Output / Min (3★ Lv.30 Workers Filled) | Physical Chest / Capacity Cap |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **The Infirmary & Barracks** | **Level 1** | 0 *(Starter)* | 1 Slot | 1.00x | 2.90 Stam/s (60.0s Coma) | 5.08 Stam/s (46.5s Coma) | 6.85 Stam/s (39.3s Coma) | 9.61 Stam/s (31.7s Coma) | 2 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 2** | 600 Gold | 1 Slot | 1.05x | 3.30 Stam/s (57.1s Coma) | 5.48 Stam/s (44.8s Coma) | 7.25 Stam/s (38.1s Coma) | 10.01 Stam/s (30.9s Coma) | 3 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 3** | 2,000 Gold | 2 Slots | 1.10x | 3.70 Stam/s (54.5s Coma) | 8.05 Stam/s (35.7s Coma) | 11.60 Stam/s (27.9s Coma) | 17.12 Stam/s (20.8s Coma) | 4 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 4** | 6,000 Gold | 2 Slots | 1.15x | 4.10 Stam/s (52.2s Coma) | 8.45 Stam/s (34.7s Coma) | 12.00 Stam/s (27.2s Coma) | 17.52 Stam/s (20.0s Cap) | 5 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 5** | 18,000 Gold | 3 Slots | 1.20x | 4.50 Stam/s (50.0s Coma) | 11.03 Stam/s (29.0s Coma) | 16.35 Stam/s (21.5s Coma) | 24.63 Stam/s (20.0s Cap) | 5 Beds (+15% Max Stam Buff) |

---

## 5. EQUIPPABLE ARTIFACT & BLACKSMITH ECONOMY TABLES

### 5.1 Weapon Star Promotion (Progressive Power Multipliers)

Artifact rarity is inherent. Stars are the progressive upgrade, from 1★ to 7★, without enhancement levels. Hero stars are a separate 1★–5★ progression. The recipient retains rarity during weapon promotion; duplicate and currency costs below match the GDD's existing star-promotion schedule.

| Weapon stars | Power multiplier | Duplicate weapons for this step | Gold | Gems |
| --- | --- | --- | --- | --- |
| 1 | 1.00x | — | — | — |
| 2 | 1.60x | 1 | 500 | 0 |
| 3 | 2.50x | 2 | 2,000 | 0 |
| 4 | 4.00x | 3 | 8,000 | 0 |
| 5 | 6.50x | 4 | 25,000 | 50 |
| 6 | 10.00x | 5 | 75,000 | 150 |
| 7 | 16.00x | 6 | 250,000 | 500 |

`WeaponPower = InherentRarityPower * WeaponStarMultiplier`

`TrainedDamageMultiplier = 1 + WeaponPower/40`

Weapon stars multiply power only; rarity's speed bonus, hero movement speed, and hero health stay unchanged. The full 1★–7★ path consumes 21 duplicates plus the retained weapon. There is no enhancement-fodder calculation.

### 5.2 Inherent Rarity Stats and Level-50 Weapon Reference

| Tier | Inherent rarity | Base power (1★) | Fixed attack-speed bonus | 7★ power | 7★ trained-damage multiplier | Color |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Common | 20 | 5.0% | 320 | 9x | #B0B0B0 |
| 2 | Uncommon | 60 | 7.5% | 960 | 25x | #4BB543 |
| 3 | Rare | 180 | 10.0% | 2,880 | 73x | #2980B9 |
| 4 | Superior | 540 | 13.0% | 8,640 | 217x | #8E44AD |
| 5 | Exalted | 1,400 | 16.5% | 22,400 | 561x | #D35400 |
| 6 | Legendary | 3,500 | 20.0% | 56,000 | 1,401x | #F1C40F |
| 7 | Mythical | 7,000 | 30.0% | 112,000 | 2,801x | #E74C3C |
| 8 | Transcendent | 10,000 | 35.0% | 160,000 | 4,001x | #1ABC9C |
| 9 | Ascendant | 14,000 | 40.0% | 224,000 | 5,601x | #E056FD |
| 10 | Ethereal | 20,000 | 45.0% | 320,000 | 8,001x | #686DE0 |
| 11 | Immortal | 28,000 | 50.0% | 448,000 | 11,201x | #FF7979 |
| 12 | Divine | 40,000 | 55.0% | 640,000 | 16,001x | #F9CA24 |
| 13 | Celestial | 56,000 | 60.0% | 896,000 | 22,401x | #00D2D3 |
| 14 | Primordial | 80,000 | 65.0% | 1,280,000 | 32,001x | #FF3838 |
| 15 | Supreme | 112,000 | 70.0% | 1,792,000 | 44,801x | #BADC58 |
| 16 | Origin | 160,000 | 75.0% | 2,560,000 | 64,001x | #FF9FF3 |

At hero level 50 / floor 50, the expected build uses **Mythical 7★** weapons: 112,000 power, 2,801x trained damage, and +30% attack speed. Five 5★ level-50 Han/Jenna/Aaron/Velkist/Eolka produce **2.550B scheduled DPS**, **1.913B at 75% uptime**, or **1.721B at 75% uptime with minimum 0.90 quality**. This is a stat benchmark, not a change to rarity availability, drops, or pity.

The [complete rarity-by-star matrix](balance/STAT_SCALING_TABLES.md#weapon-power-by-inherent-rarity-and-promoted-stars) and [enemy stat checkpoints](balance/STAT_SCALING_TABLES.md#enemy-durability-and-basic-attack-checkpoints) are generated by `node docs/balance/stat-scaling-model.cjs --write`; use `--check` to verify them. Enemy health follows expected squad DPS; basic damage follows expected hero health. These generated files contain no reward scaling.

### 5.3 Weapon Archetype Compatibility
| Weapon Type | Permitted Hero Archetypes | Launch Roster Compatible Heroes | Equipping Behavior |
| :--- | :--- | :--- | :--- |
| **`BOW`** | **Marksman** (Exclusively) | `hero_jenna` | Socketed to `LeftHand`; dynamic dual `Beam` strings anchor to `RightHand.DrawAttachment` |
| **`SWORD`** | **Striker**, **Vanguard** | `hero_han`, `hero_velkist`, `hero_aaron`, `hero_archon` | Rigidly welded to `RightHand.RightGripAttachment` |
| **`DAGGERS`** | **Striker** (Exclusively) | `hero_velkist` | Dual-wielded: Main dagger in `RightHand`, off-hand in `LeftHand` with reverse grip |
| **`AXE`** | **Vanguard**, **Miner** | `hero_aaron`, `hero_catio` | Welded to `RightHand.RightGripAttachment` for cleaving and mining |
| **`TOME`** | **Scholar**, **Healer** | `hero_eolka` | Floats or equips to hip/off-hand with ambient arcane script particles |
| **`STAFF`** | **Scholar**, **Healer** | `hero_eolka` | Welded to `RightHand` with crystal focus head channeling spells |

---

## 6. TIME-TO-UNLOCK PACING SIMULATION (F2P ACTIVE PLAY)

### 6.1 F2P Pacing Assumptions
- **Starting Resources (`T = 0:00`):** `500 Gold`, `300 Gems` (3 immediate Gacha pulls), and starter hero (**Han 1★ Lv.1**).
- **Onboarding Pulls (`T = 0:30`):** Player spends `300 Gems` for 3 pulls (`2x 1★` + `1x 2★`, or `3x 1★`). Player deploys 3 heroes into Ring 1 / Central Crimson Tower.
- **Active Extraction Rate:** Player completes 1 physical Relic extraction every `~2.5 minutes`, banking Gold and Gems at the perimeter or plot pad.
- **World Boss Cycles:** Spawns at `T = 20:00` and `T = 40:00`. Even placing Rank #4 or #5 awards `+400 Gems`, `+4,000 Gold`, and `+10% Boss Pity`.

### 6.2 Chronological Milestone Pacing Table (Minutes 0 to 45)

| Milestone Target | Target Unlock Requirements | Active Play Time | Cumulative Gold Earned | Cumulative Gems Earned | Primary Gameplay Loop & Progression Drivers |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **0. Onboarding & First 3 Pulls** | `300 Starter Gems` | **1.0 Min** | 500 Gold | 300 Gems | Spend starter `300 Gems` -> Deploy 3-Hero Squad into Ring 1. |
| **1. First Weapon Ascension** | **250 Gold** | **3.0 Mins** | 1,200 Gold | 340 Gems | Upgrade starter bow/sword to **Uncommon** (`1.15x` multiplier) at the Blacksmith Forge. |
| **2. The Infirmary Lv.2** | **600 Gold** | **7.5 Mins** | 2,800 Gold | 460 Gems | Upgrade Infirmary to Lv.2 -> unlocks 3rd recuperation bed and boosts stamina regen. |
| **3. Rare Weapon Ascension** | **600 Gold** | **12.0 Mins** | 5,600 Gold | 880 Gems | Upgrade primary weapon to **Rare** (`1.35x` multiplier); squad DPS climbs to ~250. |
| **4. First 2★ -> 3★ Promotion** | **7,500 Gold + 3 Stones** | **22.0 Mins** | 16,500 Gold | 1,950 Gems | First World Boss clear awards `+4,000 Gold` & `+400 Gems`. Synthesize dupes in The Pit, craft Promotion Stones, and promote core hero to 3★! |
| **5. Exalted Weapon Ascension** | **3,500 Gold** | **32.0 Mins** | 28,000 Gold | 2,800 Gems | Ascend weapon to **Exalted** (`1.90x` multiplier), pushing squad DPS past 650. |
| **6. Second World Boss Push** | **5-Hero Squad + Exalted Gear**| **42.0 Mins** | 46,000 Gold | 4,200 Gems | Compete for Rank #1–#3 DPS on Dimensional Sovereign with sprint dodging and overdrive whistles! |
