# DOCUMENT 3: ECONOMY, PROGRESSION MATH & BALANCING TABLES — MVP (v0.1)
**Project Codename:** *Project: Waiting Room*  
**Spreadsheet Compatibility:** All tables below use strict, flat Markdown column formatting designed for direct copy-paste into **Google Sheets** or **Microsoft Excel**.

---

## 1. HERO SEED TABLE (v0.1 LAUNCH ROSTER)

### 1.1 Launch Roster & World Boss Exclusive Seed Table
- **Banner Pool Cost:** `100 Gems` (Single Pull) | `900 Gems` (10x Pull).
- **Banner Drop Rates:** `1★ Common (70%)`, `2★ Rare (25%)`, `3★ Epic (5%)`. `4★` and `5★` are obtained exclusively via **Star Promotion**.
- **Stat Normalization Note:** In the table below, **Native Star Stats** show the exact stats when summoned at their base Star tier (`Level 1`, `QualityScalar = 1.00`), while **1★ Base Equivalent** shows the underlying $S=1$ seed values before the $1.65^{(S-1)}$ (Combat) and $1.35^{(S-1)}$ (Labor) Star Promotion multipliers.

| Hero ID | Hero Name | Origin / Banner Pool | Base Star | Archetype | Native HP (Lv.1) | Native ATK (Lv.1) | 1★ Base HP | 1★ Base ATK | Attack Interval (s) | Attacks / Sec | Native Base DPS (Lv.1) | Attack Range (Studs) | Native Base Labor (/min) | 1★ Base Labor (/min) | Preferred Facility (+25% Labor) | Passive Trait Name | Passive Combat Multiplier | Passive Labor / Utility Multiplier |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `hero_han` | **Han** | Standard Banner (25.0% Net) | 1★ | Striker | 300 | 40 | 300 | 40 | 0.85 | 1.18 | 47.06 | 6 | 14.0 | 14.0 | Mana Conduit | Unyielding Adaptation | +10% ATK | -10% Combat Stamina Drain |
| `hero_jenna` | **Jenna** | Standard Banner (22.5% Net) | 1★ | Marksman | 210 | 34 | 210 | 34 | 0.80 | 1.25 | 42.50 | 28 | 13.0 | 13.0 | Dimensional Lab | Windstep Precision | +15% Attack Speed | +5% Squad Move Speed |
| `hero_catio` | **Catio** | Standard Banner (22.5% Net) | 1★ | Miner / Healer | 280 | 24 | 280 | 24 | 1.05 | 0.95 | 22.86 | 6 | 20.0 | 20.0 | Mana Conduit & Infirmary | Quartermaster's Ledger | +0% Combat | +25% Labor Output & +10% Infirmary Regen |
| `hero_aaron` | **Aaron** | Standard Banner (13.0% Net) | 2★ | Vanguard | 743 | 46 | 450 | 28 | 1.10 | 0.91 | 41.82 | 7 | 21.6 | 16.0 | Infirmary | Phalanx Guard | +25% Max HP | -15% AoE Damage Taken |
| `hero_velkist` | **Velkist** | Standard Banner (12.0% Net) | 2★ | Striker | 495 | 73 | 300 | 44 | 0.75 | 1.33 | 97.33 | 6 | 18.9 | 14.0 | Mana Conduit | Bloodthirst Frenzy | +20% ATK | +1.0s [Q] Overdrive Duration |
| `hero_eolka` | **Eolka** | Standard Banner (5.0% Net) | 3★ | Scholar | 626 | 142 | 230 | 52 | 1.00 | 1.00 | 142.00 | 30 | 40.1 | 22.0 | Dimensional Lab | Crimson Pyromancy | +25% ATK | +30% Dimensional Lab RP Output |
| `hero_archon` | **Sovereign Archon** | World Boss Exclusive (RNG / 100% Pity) | 3★ | Striker / Archon | 953 | 177 | 350 | 65 | 0.80 | 1.25 | 221.25 | 14 | 45.6 | 25.0 | All Facilities (+25%) | Dimensional Dominion | +30% Boss Damage | +25% All-Facility Labor & -25% Nova Stamina Loss |

---

## 2. STAR PROMOTION & LEVELING CURVE TABLES (1★ LV.1 TO 5★ LV.50)

### 2.1 Core Progression Formulas (Google Sheets Ready)
- **Max Level Cap:** `MaxLevel = Stars * 10`
- **XP Required for Level $L \to L+1$:** `=ROUND(50 * (L ^ 1.45), 0)`
- **Synthesis ("The Pit") Fodder XP Gained:** `=(100 * (3 ^ (FodderStars - 1))) + (25 * FodderLevel)`
- **Star Promotion Multipliers (Per Star above 1★):** `CombatMult = 1.65 ^ (Stars - 1)` | `LaborMult = 1.35 ^ (Stars - 1)`
- **Level Stat Scaling:** `+8% Combat Stats per Level above 1` (`1 + 0.08 * (L - 1)`) | `+5% Labor Output per Level above 1` (`1 + 0.05 * (L - 1)`)

### 2.2 Star Promotion Milestone & Reference Stat Table (`Han` — 1★ Base to 5★ Lv.50)
*Reference Hero: **Han** (`1★ Base HP = 300`, `1★ Base ATK = 40`, `Attack Interval = 0.85s`, `1★ Base Labor = 14.0/min`, `Passive Trait = +10% ATK`, `Preferred Facility Synergy = +25%`).*

| Milestone Stage | Star Tier (S) | Hero Level (L) | Level Cap (10*S) | Tier XP Required (Lv.1 to Cap) | Promotion Fodder Required | Promotion Gold Cost | Cumulative 1★ Hero Copies Used | Star Combat Mult (1.65^(S-1)) | Level Combat Mult (1+0.08*(L-1)) | Total Combat Mult | Han Effective HP | Han Effective ATK (+10% Trait) | Han Base DPS | Han Overdrive DPS (+40% Spd) | Star Labor Mult (1.35^(S-1)) | Level Labor Mult (1+0.05*(L-1)) | Han Effective Labor (/min, +25% Synergy) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1★ Base Summon** | 1★ | 1 | 10 | 0 | None | 0 | 1 | 1.000x | 1.00x | 1.000x | 300 | 44 | 51.76 | 72.47 | 1.000x | 1.00x | 17.50 |
| **1★ Mid-Level** | 1★ | 5 | 10 | 826 | None | 0 | 1 | 1.000x | 1.32x | 1.320x | 396 | 58 | 68.24 | 95.53 | 1.000x | 1.20x | 21.00 |
| **1★ Max Level** | 1★ | 10 | 10 | 4,450 | None | 0 | 1 | 1.000x | 1.72x | 1.720x | 516 | 76 | 89.41 | 125.18 | 1.000x | 1.45x | 25.38 |
| **Promote 1★ -> 2★** | 2★ | 1 | 20 | 0 | 1x 1★ Hero | 1,500 | 2 | 1.650x | 1.00x | 1.650x | 495 | 73 | 85.88 | 120.24 | 1.350x | 1.00x | 23.63 |
| **2★ Mid-Level** | 2★ | 10 | 20 | 4,450 | None | 0 | 2 | 1.650x | 1.72x | 2.838x | 851 | 125 | 147.06 | 205.88 | 1.350x | 1.45x | 34.26 |
| **2★ Max Level** | 2★ | 20 | 20 | 21,813 | None | 0 | 2 | 1.650x | 2.52x | 4.158x | 1,247 | 183 | 215.29 | 301.41 | 1.350x | 1.95x | 46.07 |
| **Promote 2★ -> 3★** | 3★ | 1 | 30 | 0 | 2x 2★ Heroes | 7,500 | 6 | 2.723x | 1.00x | 2.723x | 817 | 120 | 141.18 | 197.65 | 1.823x | 1.00x | 31.89 |
| **3★ Mid-Level** | 3★ | 15 | 30 | 11,401 | None | 0 | 6 | 2.723x | 2.12x | 5.772x | 1,732 | 254 | 298.82 | 418.35 | 1.823x | 1.70x | 54.22 |
| **3★ Max Level** | 3★ | 30 | 30 | 56,906 | None | 0 | 6 | 2.723x | 3.32x | 9.039x | 2,712 | 398 | 468.24 | 655.53 | 1.823x | 2.45x | 78.14 |
| **Promote 3★ -> 4★** | 4★ | 1 | 40 | 0 | 3x 3★ Heroes | 35,000 | 24 | 4.492x | 1.00x | 4.492x | 1,348 | 198 | 232.94 | 326.12 | 2.460x | 1.00x | 43.06 |
| **4★ Mid-Level** | 4★ | 20 | 40 | 21,813 | None | 0 | 24 | 4.492x | 2.52x | 11.320x | 3,396 | 498 | 585.88 | 820.24 | 2.460x | 1.95x | 83.96 |
| **4★ Max Level** | 4★ | 40 | 40 | 114,209 | None | 0 | 24 | 4.492x | 4.12x | 18.508x | 5,552 | 814 | 957.65 | 1,340.71 | 2.460x | 2.95x | 127.02 |
| **Promote 4★ -> 5★** | 5★ | 1 | 50 | 0 | 4x 4★ Heroes | 150,000 | 120 | 7.412x | 1.00x | 7.412x | 2,224 | 326 | 383.53 | 536.94 | 3.322x | 1.00x | 58.13 |
| **5★ Mid-Level** | 5★ | 25 | 50 | 36,928 | None | 0 | 120 | 7.412x | 2.92x | 21.643x | 6,493 | 952 | 1,120.00 | 1,568.00 | 3.322x | 2.20x | 127.88 |
| **5★ Max Level** | 5★ | 50 | 50 | 197,521 | None | 0 | 120 | 7.412x | 4.92x | 36.467x | 10,940 | 1,605 | 1,888.24 | 2,643.53 | 3.322x | 3.45x | 200.54 |

### 2.3 Complete Level-by-Level XP Curve Table (Levels 1 to 50)
*Formula: `XP_To_Next_Level = ROUND(50 * (Level ^ 1.45), 0)` | `1★ Fodder (Lv.1) = 125 XP` | `2★ Fodder (Lv.1) = 325 XP` | `3★ Fodder (Lv.1) = 925 XP`.*

| Level (L) | Star Tier Unlock | XP to Next Level (L -> L+1) | Cumulative XP from Lv.1 | 1★ Lv.1 Fodders Needed (125 XP ea) | 2★ Lv.1 Fodders Needed (325 XP ea) | Level Combat Scalar (1+0.08*(L-1)) | Level Labor Scalar (1+0.05*(L-1)) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | 1★–5★ | 50 | 0 | 0.0 | 0.0 | 1.00x | 1.00x |
| **2** | 1★–5★ | 137 | 50 | 0.4 | 0.2 | 1.08x | 1.05x |
| **3** | 1★–5★ | 246 | 187 | 1.5 | 0.6 | 1.16x | 1.10x |
| **4** | 1★–5★ | 373 | 433 | 3.5 | 1.3 | 1.24x | 1.15x |
| **5** | 1★–5★ | 516 | 806 | 6.4 | 2.5 | 1.32x | 1.20x |
| **6** | 1★–5★ | 672 | 1,322 | 10.6 | 4.1 | 1.40x | 1.25x |
| **7** | 1★–5★ | 840 | 1,994 | 16.0 | 6.1 | 1.48x | 1.30x |
| **8** | 1★–5★ | 1,020 | 2,834 | 22.7 | 8.7 | 1.56x | 1.35x |
| **9** | 1★–5★ | 1,210 | 3,854 | 30.8 | 11.9 | 1.64x | 1.40x |
| **10 (1★ Cap)** | **1★ Max** | 1,409 | **4,450** *(Capped)* | **35.6** | **13.7** | **1.72x** | **1.45x** |
| **11** | 2★–5★ | 1,618 | 6,473 | 51.8 | 19.9 | 1.80x | 1.50x |
| **12** | 2★–5★ | 1,836 | 8,091 | 64.7 | 24.9 | 1.88x | 1.55x |
| **13** | 2★–5★ | 2,062 | 9,927 | 79.4 | 30.5 | 1.96x | 1.60x |
| **14** | 2★–5★ | 2,297 | 11,989 | 95.9 | 36.9 | 2.04x | 1.65x |
| **15** | 2★–5★ | 2,540 | 14,286 | 114.3 | 44.0 | 2.12x | 1.70x |
| **16** | 2★–5★ | 2,790 | 16,826 | 134.6 | 51.8 | 2.20x | 1.75x |
| **17** | 2★–5★ | 3,048 | 19,616 | 156.9 | 60.4 | 2.28x | 1.80x |
| **18** | 2★–5★ | 3,314 | 22,664 | 181.3 | 69.7 | 2.36x | 1.85x |
| **19** | 2★–5★ | 3,586 | 25,978 | 207.8 | 79.9 | 2.44x | 1.90x |
| **20 (2★ Cap)** | **2★ Max** | 3,866 | **29,564** | **236.5** | **91.0** | **2.52x** | **1.95x** |
| **21** | 3★–5★ | 4,152 | 33,430 | 267.4 | 102.9 | 2.60x | 2.00x |
| **22** | 3★–5★ | 4,445 | 37,582 | 300.7 | 115.6 | 2.68x | 2.05x |
| **23** | 3★–5★ | 4,744 | 42,027 | 336.2 | 129.3 | 2.76x | 2.10x |
| **24** | 3★–5★ | 5,050 | 46,771 | 374.2 | 143.9 | 2.84x | 2.15x |
| **25** | 3★–5★ | 5,362 | 51,821 | 414.6 | 159.4 | 2.92x | 2.20x |
| **26** | 3★–5★ | 5,680 | 57,183 | 457.5 | 175.9 | 3.00x | 2.25x |
| **27** | 3★–5★ | 6,003 | 62,863 | 502.9 | 193.4 | 3.08x | 2.30x |
| **28** | 3★–5★ | 6,333 | 68,866 | 550.9 | 211.9 | 3.16x | 2.35x |
| **29** | 3★–5★ | 6,668 | 75,199 | 601.6 | 231.4 | 3.24x | 2.40x |
| **30 (3★ Cap)** | **3★ Max** | 7,009 | **81,867** | **654.9** | **251.9** | **3.32x** | **2.45x** |
| **31** | 4★–5★ | 7,355 | 88,876 | 711.0 | 273.5 | 3.40x | 2.50x |
| **32** | 4★–5★ | 7,707 | 96,231 | 769.8 | 296.1 | 3.48x | 2.55x |
| **33** | 4★–5★ | 8,064 | 103,938 | 831.5 | 319.8 | 3.56x | 2.60x |
| **34** | 4★–5★ | 8,427 | 112,002 | 896.0 | 344.6 | 3.64x | 2.65x |
| **35** | 4★–5★ | 8,795 | 120,429 | 963.4 | 370.6 | 3.72x | 2.70x |
| **36** | 4★–5★ | 9,167 | 129,224 | 1,033.8 | 397.6 | 3.80x | 2.75x |
| **37** | 4★–5★ | 9,545 | 138,391 | 1,107.1 | 425.8 | 3.88x | 2.80x |
| **38** | 4★–5★ | 9,928 | 147,936 | 1,183.5 | 455.2 | 3.96x | 2.85x |
| **39** | 4★–5★ | 10,316 | 157,864 | 1,262.9 | 485.7 | 4.04x | 2.90x |
| **40 (4★ Cap)** | **4★ Max** | 10,708 | **168,180** | **1,345.4** | **517.5** | **4.12x** | **2.95x** |
| **41** | 5★ Only | 11,105 | 178,888 | 1,431.1 | 550.4 | 4.20x | 3.00x |
| **42** | 5★ Only | 11,507 | 189,993 | 1,519.9 | 584.6 | 4.28x | 3.05x |
| **43** | 5★ Only | 11,914 | 201,500 | 1,612.0 | 620.0 | 4.36x | 3.10x |
| **44** | 5★ Only | 12,325 | 213,414 | 1,707.3 | 656.7 | 4.44x | 3.15x |
| **45** | 5★ Only | 12,741 | 225,739 | 1,805.9 | 694.6 | 4.52x | 3.20x |
| **46** | 5★ Only | 13,161 | 238,480 | 1,907.8 | 733.8 | 4.60x | 3.25x |
| **47** | 5★ Only | 13,586 | 251,641 | 2,013.1 | 774.3 | 4.68x | 3.30x |
| **48** | 5★ Only | 14,015 | 265,227 | 2,121.8 | 816.1 | 4.76x | 3.35x |
| **49** | 5★ Only | 14,449 | 279,242 | 2,233.9 | 859.2 | 4.84x | 3.40x |
| **50 (5★ Cap)** | **5★ Max** | 0 *(Max)* | **293,691** | **2,349.5** | **903.7** | **4.92x** | **3.45x** |

---

## 3. MOB & WORLD BOSS SCALING TABLE

| Entity ID | Entity Name | Zone / Ring | Spawn Count / Cap | Base HP | ATK | Attack Interval (s) | Respawn Time (s) | Direct Wallet Gold | Mana Geode Drop % (-15% Spd) | Cursed Urn Drop % (-25% Spd) | Abyssal Core Drop % (-35% Spd) | Calamity Heart Drop % (-45% Spd) | AoE Telegraph Shape & Size | AoE Telegraph Cast Time (s) | AoE Cooldown (s) | On-Hit Penalty / Special Mechanic |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `mob_mana_node` | **Mana Crystal Cluster** | Ring 1 (R: 280–460) | 18 Nodes | 450 | 0 | 0.00 | 8.0 | 45 | 18.0% | 0.0% | 0.0% | 0.0% | None | 0.0 | 0.0 | Passive resource node; zero Stamina damage back to squad |
| `mob_ruin_crawler` | **Ruin Scavenger** | Ring 1 (R: 280–460) | 24 Mobs | 850 | 18 | 1.40 | 6.0 | 80 | 25.0% | 0.0% | 0.0% | 0.0% | None | 0.0 | 0.0 | Standard starter combat mob |
| `mob_stone_sentinel` | **Mossbound Sentinel** | Ring 1 (R: 280–460) | 10 Mobs | 2,200 | 35 | 1.80 | 12.0 | 210 | 55.0% | 2.0% | 0.0% | 0.0% | Circle (R = 10 studs) | 2.0 | 12.0 | Teaches new Masters `[E]` Recall Whistle timing; causes Carrier Fumble |
| `elite_corrupted_stalker` | **Corrupted Stalker** | Ring 2 (R: 120–280) | 12 Elites | 6,500 | 85 | 1.10 | 15.0 | 550 | 15.0% | 35.0% | 3.0% | 0.0% | Cone (90°, R = 16 studs) | 1.6 | 9.0 | Fast gap-closer; stuns Relic Carrier for 1.0s & forces Fumble |
| `elite_blighted_treant` | **Blighted Elder Treant** | Ring 2 (R: 120–280) | 8 Elites | 14,000 | 140 | 1.60 | 22.0 | 1,100 | 0.0% | 60.0% | 8.0% | 0.0% | Circle (R = 22 studs) | 2.2 | 11.0 | High-density Ring 2 Elite; drains -15 Hero Stamina if not recalled |
| `elite_abyssal_exec` | **Abyssal Executioner** | Ring 2 (R: 120–280) | 4 Rare Elites | 32,000 | 240 | 1.40 | 45.0 | 2,600 | 0.0% | 40.0% | 30.0% | 0.0% | Cross + Circle (R = 26 studs) | 2.0 | 10.0 | Guards Ring 2->3 bridge choke points; prime ambush hazard for Relic Carriers |
| `boss_rift_warden` | **The Rift Warden (Lure Boss)** | Ring 3 Altar (R: 0–120) | Summoned via Rift Lure | 95,000 | 360 | 1.25 | On Lure Use | 6,000 | 0.0% | 100.0% (x2) | 100.0% (x1) | 0.0% | Ring Donut (R = 15–55 studs) | 2.5 | 14.0 | Knockback + -30 Hero Stamina on hit; guaranteed 1x Abyssal Core physical drop |
| `world_boss_p1` | **Dimensional Sovereign (Phase 1: 100–50%)** | Ring 3 Altar (R: 0–120) | Every 20 Mins (5m Cap) | Dynamic (`>=75,000`) | 420 | 1.20 | 1,200.0 | See Direct Table | 0.0% | 0.0% | 0.0% | 100.0% (On Kill) | **Devouring Nova** Circle (R = 0–85 studs) | **3.0** | **20.0** | Instant -50% Hero Stamina (or 60s Coma if `<50` Stamina); 5s `+25%` Damage Taken punish window after cast |
| `world_boss_p2` | **Dimensional Sovereign (Phase 2: 50–25%)** | Ring 3 Altar (R: 0–120) | Phase Transition | Dynamic (`50% HP`) | 480 | 1.10 | N/A | See Direct Table | 0.0% | 0.0% | 0.0% | 100.0% (On Kill) | Gravity Pull + **Devouring Nova** (R = 0–85 studs) | **3.0** | **20.0** | Pulls all heroes to R=15st 1.0s before Nova; spawns 2 Rift Tether Crystals (40% Boss Shield until focused) |
| `world_boss_p3` | **Dimensional Sovereign (Phase 3: <25% Enrage)** | Ring 3 Altar (R: 0–120) | Phase Transition | Dynamic (`25% HP`) | 560 | 0.88 (+35% Spd) | N/A | See Direct Table | 0.0% | 0.0% | 0.0% | 100.0% (On Kill) | **Devouring Nova** (R = 0–85st) + Rim Puddles | **3.0** | **20.0** | Guaranteed **60s Coma** on any hero inside R<=85st; drops **The Calamity Heart** (15s Rank #1 DPS Lock) on death |

---

## 4. WAITING ROOM TYCOON ECONOMY TABLES (LEVELS 1–5)

### 4.1 Facility Upgrade & Production Table (Levels 1–5)
*Formulas:*
- **Mana Conduit (`Gems/min`):** `(5 * Level + 0.45 * SumEffectiveLabor) * (1 + 0.12 * (Level - 1))`
- **The Infirmary (`Stamina/sec` & `Coma Duration`):** `StaminaRegen = 2.5 + (0.4 * Level) + (0.06 * SumEffectiveLabor)` | `ComaSec = MAX(20, 60 / (1 + 0.05 * (Level - 1) + 0.008 * SumEffectiveLabor))`
- **The Dimensional Lab (`RP/min`):** `(3 * Level + 0.35 * SumEffectiveLabor) * (1 + 0.10 * (Level - 1))`
*(Worker Benchmarks below use **Catio** (`20 Base Labor + 25% Synergy`) for Mana Conduit/Infirmary and **Eolka/Jenna** for Dimensional Lab).*

| Facility Name | Facility Level | Upgrade Cost (Gold) | Upgrade Cost (RP) | Max Worker Slots | Facility Level Mult | Base Output / Min (0 Workers) | Output / Min (1★ Lv.10 Workers Filled) | Output / Min (2★ Lv.20 Workers Filled) | Output / Min (3★ Lv.30 Workers Filled) | Physical Chest / Buffer Cap |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Mana Conduit** | **Level 1** | 0 *(Starter)* | 0 | 1 Slot | 1.00x | 5.0 Gems/m | 21.3 Gems/m *(1 Worker)* | 34.6 Gems/m *(1 Worker)* | 55.3 Gems/m *(1 Worker)* | 150 Gems |
| **Mana Conduit** | **Level 2** | 800 Gold | 25 RP | 1 Slot | 1.12x | 11.2 Gems/m | 29.5 Gems/m *(1 Worker)* | 44.4 Gems/m *(1 Worker)* | 67.5 Gems/m *(1 Worker)* | 300 Gems |
| **Mana Conduit** | **Level 3** | 2,500 Gold | 75 RP | 2 Slots | 1.24x | 18.6 Gems/m | 59.1 Gems/m *(2 Workers)* | 92.1 Gems/m *(2 Workers)* | 143.3 Gems/m *(2 Workers)* | 600 Gems |
| **Mana Conduit** | **Level 4** | 7,500 Gold | 200 RP | 2 Slots | 1.36x | 27.2 Gems/m | 71.6 Gems/m *(2 Workers)* | 107.8 Gems/m *(2 Workers)* | 164.0 Gems/m *(2 Workers)* | 1,200 Gems |
| **Mana Conduit** | **Level 5** | 22,000 Gold | 500 RP | 3 Slots | 1.48x | 37.0 Gems/m | 109.5 Gems/m *(3 Workers)* | 168.5 Gems/m *(3 Workers)* | 260.2 Gems/m *(3 Workers)* | 2,500 Gems |
| **The Infirmary & Barracks** | **Level 1** | 0 *(Starter)* | 0 | 1 Slot | 1.00x | 2.90 Stam/s (60.0s Coma) | 5.08 Stam/s (46.5s Coma) | 6.85 Stam/s (39.3s Coma) | 9.61 Stam/s (31.7s Coma) | 2 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 2** | 600 Gold | 20 RP | 1 Slot | 1.05x | 3.30 Stam/s (57.1s Coma) | 5.48 Stam/s (44.8s Coma) | 7.25 Stam/s (38.1s Coma) | 10.01 Stam/s (30.9s Coma) | 3 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 3** | 2,000 Gold | 60 RP | 2 Slots | 1.10x | 3.70 Stam/s (54.5s Coma) | 8.05 Stam/s (35.7s Coma) | 11.60 Stam/s (27.9s Coma) | 17.12 Stam/s (20.8s Coma) | 4 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 4** | 6,000 Gold | 160 RP | 2 Slots | 1.15x | 4.10 Stam/s (52.2s Coma) | 8.45 Stam/s (34.7s Coma) | 12.00 Stam/s (27.2s Coma) | 17.52 Stam/s (20.0s Cap) | 5 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 5** | 18,000 Gold | 400 RP | 3 Slots | 1.20x | 4.50 Stam/s (50.0s Coma) | 11.03 Stam/s (29.0s Coma) | 16.35 Stam/s (21.5s Coma) | 24.63 Stam/s (20.0s Cap) | 5 Beds (+15% Max Stam Buff) |
| **The Dimensional Lab** | **Level 1** | 0 *(Starter)* | 0 | 1 Slot | 1.00x | 3.0 RP/m | 11.3 RP/m *(1 Worker)* | 18.0 RP/m *(1 Worker)* | 28.4 RP/m *(1 Worker)* | 100 RP |
| **The Dimensional Lab** | **Level 2** | 1,000 Gold | 30 RP | 1 Slot | 1.10x | 6.6 RP/m | 15.7 RP/m *(1 Worker)* | 23.1 RP/m *(1 Worker)* | 34.5 RP/m *(1 Worker)* | 250 RP |
| **The Dimensional Lab** | **Level 3** | 3,200 Gold | 90 RP | 2 Slots | 1.20x | 10.8 RP/m | 30.6 RP/m *(2 Workers)* | 46.8 RP/m *(2 Workers)* | 71.9 RP/m *(2 Workers)* | 500 RP |
| **The Dimensional Lab** | **Level 4** | 9,000 Gold | 240 RP | 2 Slots | 1.30x | 15.6 RP/m | 37.1 RP/m *(2 Workers)* | 54.6 RP/m *(2 Workers)* | 81.8 RP/m *(2 Workers)* | 1,000 RP |
| **The Dimensional Lab** | **Level 5** | 25,000 Gold | 600 RP | 3 Slots | 1.40x | 21.0 RP/m | 55.7 RP/m *(3 Workers)* | 84.0 RP/m *(3 Workers)* | 127.9 RP/m *(3 Workers)* | 2,000 RP |

### 4.2 Dimensional Lab Tech Tree & Crafting Costs Table

| Research / Craft Node ID | Unlock Name | Required Lab Level | Research Points (RP) Cost | Gold Cost | Gameplay Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `tech_squad_slot_4` | **4th Squad Deployment Slot** | Lab Level 1 | **65 RP** | **1,200 Gold** | Increases active Master squad size from 3 Heroes to 4 Heroes (+33% Squad DPS). |
| `tech_ring2_barrier` | **Ring 2 Arcane Barrier Key** | Lab Level 2 | **180 RP** | **3,500 Gold** | Permanently unlocks passage through the `R = 280` Barrier Gate into Ring 2 (Corrupted Grove). |
| `tech_squad_slot_5` | **5th Squad Deployment Slot** | Lab Level 3 | **420 RP** | **12,000 Gold** | Increases active Master squad size from 4 Heroes to the maximum 5 Heroes (+25% Squad DPS). |
| `craft_rift_lure` | **Craft Repeatable Rift Lure** | Lab Level 3 | **300 RP** *(Per Lure)* | **5,000 Gold** | Crafts 1x **Rift Lure** item; used at Ring 3 Center Altar to summon **The Rift Warden** (Guaranteed Abyssal Core). |

---

## 5. TIME-TO-UNLOCK PACING SIMULATION (F2P ACTIVE PLAY)

### 5.1 F2P Pacing Assumptions
- **Starting Resources (`T = 0:00`):** `500 Gold`, `300 Gems` (3 immediate Gacha pulls), `0 RP`, and `1x` starter hero (**Han 1★ Lv.1**).
- **Onboarding Pulls (`T = 0:30`):** Player spends `300 Gems` for 3 pulls (statistically `2x 1★` + `1x 2★`, or `3x 1★`). Player deploys 3 heroes into Ring 1 and assigns 1 hero to the **Dimensional Lab**.
- **Active Extraction Rate:** Player completes 1 physical Relic extraction every `~2.5 minutes` (or `~2.0 minutes` in a **Blood Pact** using **Shared Pact Pedestals** for `75% / 75%` cooperative split).
- **World Boss Cycles:** Spawn at `T = 20:00` and `T = 40:00`. Even if the F2P player places **Rank #4 or #5 DPS**, they earn `+400 Gems`, `+4,000 Gold`, `+140 RP`, and `+10% Boss Pity` through active **`[E]` Emergency Recall Whistle** dodging.

### 5.2 Chronological Milestone Pacing Table (Minutes 0 to 45)

| Milestone Target | Target Unlock Requirements | Active Play Time (Solo F2P) | Active Play Time (Blood Pact Co-op F2P) | Cumulative Gold Earned | Cumulative Gems Earned | Cumulative RP Earned | Primary Income Breakdown During Phase |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **0. Onboarding & First 3 Pulls** | `300 Starter Gems` | **1.0 Min** | **1.0 Min** | 500 Gold | 300 Gems | 0 RP | Spend starter `300 Gems` -> Deploy 3-Hero Squad to Ring 1 + Assign 1 Worker to Dimensional Lab. |
| **1. Unlock 4th Hero Slot** | **65 RP + 1,200 Gold** | **8.5 Mins** | **7.0 Mins** | 1,650 Gold | 480 Gems | 75 RP | • `3x` Mana Geode Extractions (`30 RP`, `750 Gold`, `120 Gems`)<br>• `7.5m` Lab Lv.1 Output (`~45 RP`)<br>• Ring 1 Mob Gold (`~400 Gold`). |
| **2. Unlock Ring 2 Barrier Gate** | **180 RP + 3,500 Gold** *(+Lab Lv.2: 30 RP, 1,000G)* | **16.5 Mins** | **13.5 Mins** | 5,400 Gold | 890 Gems | 285 RP | • Upgrade Lab to Lv.2 at `T=10m`<br>• `4x` more Mana Geode Extractions (`40 RP`, `1,000G`)<br>• `1x` Plot Blessing on Neighbor (`+25 Gems`)<br>• `8m` Lab Lv.2 Output (`~125 RP`). |
| **3. First 3★ Star Promotion** | **3x 2★ Heroes (1 at Lv.20) + 7,500 Gold** | **24.5 Mins** | **20.5 Mins** | 15,800 Gold | 1,950 Gems | 580 RP | • **T=20:00 World Boss Clear (Rank #4):** `+400 Gems`, `+4,000 Gold`, `+140 RP`, `+10% Pity`<br>• `3x` Ring 2 Cursed Urn Extractions (`+450 Gems`, `+3,600 Gold`, `+135 RP`)<br>• `~16` Total Gacha Pulls (`1,600 Gems`) -> Feed 1★ dupes in **The Pit** -> Promote `2★ Lv.20` to **3★**! |
| **4. Unlock 5th Hero Slot** | **420 RP + 12,000 Gold** *(+Lab Lv.3: 90 RP, 3,200G)* | **34.0 Mins** | **28.0 Mins** | 29,500 Gold | 2,750 Gems | 1,090 RP | • Upgrade Lab to Lv.3 at `T=26m` (2 Worker Slots = `~45 RP/min`)<br>• `4x` Cursed Urns + `1x` Abyssal Core Extraction (`+330 RP`, `+8,800 Gold`, `+1,050 Gems`). |
| **5. Craft First Rift Lure** | **300 RP + 5,000 Gold** | **41.5 Mins** | **34.5 Mins** | 44,000 Gold | 4,100 Gems | 1,450 RP | • **T=40:00 Second World Boss Clear (Rank #2–#3 with 5-Hero Squad + 3★ Carry):** `+650 Gems`, `+6,500 Gold`, `+225 RP`<br>• `3m` Lab Lv.3 Output (`~135 RP`) -> Craft **Rift Lure** & summon **The Rift Warden** at Ring 3! |

### 5.3 Summary of Retention & Monetization Pacing Hooks
1. **Minute 8 (`4th Hero Slot`):** Immediate dopamine hit within the first 10 minutes of play; validates the **Dimensional Lab** worker loop.
2. **Minute 16 (`Ring 2 Access`):** Unlocked just 3.5 minutes before the **20-minute World Boss** warning banner, giving the player their first taste of **Cursed Urn** physical extractions and Elite red AoE dodging right before the server boss spawns.
3. **Minute 24 (`First 3★ Star Promotion`):** Powered by the 20-minute World Boss direct payout, proving to Free-to-Play players that active **`[E]` Recall Whistle** skill checks translate directly into high-tier roster promotions.
4. **Minute 34–42 (`5th Hero Slot` + `First Rift Lure`):** Completes the full 5-hero squad right before the second World Boss cycle (`T = 40:00`), enabling the player to compete for **Rank #1 DPS** and the **15-second exclusive lock on The Calamity Heart**.
