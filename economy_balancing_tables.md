# DOCUMENT 3: ECONOMY, PROGRESSION MATH & BALANCING TABLES
**Project Codename:** *Project: Waiting Room*  
**Architecture Standard:** Zero Server-Side Humanoids | Gold & Gems Economy | Equippable Artifacts & Blacksmith Ascension  
**Spreadsheet Compatibility:** All tables below use strict, flat Markdown column formatting designed for direct copy-paste into **Google Sheets** or **Microsoft Excel**.

---

## 1. HERO SEED TABLE (LAUNCH ROSTER)

### 1.1 Launch Roster & World Boss Exclusive Seed Table
- **Banner Pool Cost:** `100 Gems` (Single Pull) | `900 Gems` (10x Pull).
- **Banner Drop Rates:** `1★ Common (70%)`, `2★ Rare (25%)`, `3★ Epic (5%)`. `4★` and `5★` are obtained exclusively via **Star Promotion**.
- **Stat Normalization Note:** In the table below, **Native Star Stats** show the exact stats when summoned at their base Star tier (`Level 1`, `QualityScalar = 1.00`), while **1★ Base Equivalent** shows the underlying $S=1$ seed values before the $1.65^{(S-1)}$ (Combat) and $1.35^{(S-1)}$ (Labor) Star Promotion multipliers.

| Hero ID | Hero Name | Origin / Banner Pool | Base Star | Archetype | Native HP (Lv.1) | Native ATK (Lv.1) | 1★ Base HP | 1★ Base ATK | Attack Interval (s) | Attacks / Sec | Native Base DPS (Lv.1) | Attack Range (Studs) | Native Base Labor (/min) | 1★ Base Labor (/min) | Preferred Facility (+25% Labor) | Passive Trait Name | Passive Combat Multiplier | Passive Labor / Utility Multiplier |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `hero_han` | **Han** | Standard Banner (25.0% Net) | 1★ | Striker | 300 | 40 | 300 | 40 | 0.85 | 1.18 | 47.06 | 6 | 14.0 | 14.0 | Mana Conduit | Unyielding Adaptation | +10% ATK | -10% Combat Stamina Drain |
| `hero_jenna` | **Jenna** | Standard Banner (22.5% Net) | 1★ | Marksman | 210 | 34 | 210 | 34 | 0.80 | 1.25 | 42.50 | 28 | 13.0 | 13.0 | Mana Conduit | Windstep Precision | +15% Attack Speed | +5% Squad Move Speed |
| `hero_catio` | **Catio** | Standard Banner (22.5% Net) | 1★ | Miner | 280 | 24 | 280 | 24 | 1.05 | 0.95 | 22.86 | 6 | 20.0 | 20.0 | Mana Conduit | Quartermaster's Ledger | +0% Combat | +25% Labor Output |
| `hero_aaron` | **Aaron** | Standard Banner (13.0% Net) | 2★ | Vanguard | 743 | 46 | 450 | 28 | 1.10 | 0.91 | 41.82 | 7 | 21.6 | 16.0 | Infirmary | Phalanx Guard | +25% Max HP | -15% AoE Damage Taken |
| `hero_velkist` | **Velkist** | Standard Banner (12.0% Net) | 2★ | Striker | 495 | 73 | 300 | 44 | 0.75 | 1.33 | 97.33 | 6 | 18.9 | 14.0 | Mana Conduit | Bloodthirst Frenzy | +20% ATK | +1.0s [Q] Overdrive Duration |
| `hero_eolka` | **Eolka** | Standard Banner (5.0% Net) | 3★ | Scholar | 626 | 142 | 230 | 52 | 1.00 | 1.00 | 142.00 | 30 | 40.1 | 22.0 | Mana Conduit | Crimson Pyromancy | +25% ATK | +30% Labor Output |
| `hero_archon` | **Sovereign Archon** | World Boss Exclusive (RNG / 100% Pity) | 3★ | Striker | 953 | 177 | 350 | 65 | 0.80 | 1.25 | 221.25 | 14 | 45.6 | 25.0 | All Facilities (+25%) | Dimensional Dominion | +30% Boss Damage | +25% All-Facility Labor & -25% Nova Stamina Loss |

---

## 2. STAR PROMOTION & LEVELING CURVE TABLES (1★ LV.1 TO 5★ LV.50)

### 2.1 Core Progression Formulas (Google Sheets Ready)
- **Max Level Cap:** `MaxLevel = Stars * 10`
- **XP Required for Level $L \to L+1$:** `=ROUND(50 * (L ^ 1.45), 0)`
- **Synthesis ("The Pit") Fodder Base XP:** `base = (100 * (3 ^ (FodderStars - 1))) + (25 * FodderLevel)`
- **Level Efficiency Scaling:** `efficiency = MAX(0.55, 1 - 0.025 * MAX(0, RecipientLevel - FodderLevel - 5))`
- **Star Promotion Multipliers (Per Star above 1★):** `CombatMult = 1.65 ^ (Stars - 1)` | `LaborMult = 1.35 ^ (Stars - 1)`
- **Level Stat Scaling:** `+8% Combat Stats per Level above 1` (`1 + 0.08 * (L - 1)`) | `+5% Labor Output per Level above 1` (`1 + 0.05 * (L - 1)`)

### 2.2 Star Promotion Milestone & Reference Stat Table (`Han` — 1★ Base to 5★ Lv.50)
*Reference Hero: **Han** (`1★ Base HP = 300`, `1★ Base ATK = 40`, `Attack Interval = 0.85s`, `1★ Base Labor = 14.0/min`, `Passive Trait = +10% ATK`, `Preferred Facility Synergy = +25%`).*

| Milestone Stage | Star Tier (S) | Hero Level (L) | Level Cap (10*S) | Tier XP Required (Lv.1 to Cap) | Promotion Materials Required | Promotion Gold Cost | Cumulative 1★ Copies Used | Star Combat Mult (1.65^(S-1)) | Level Combat Mult (1+0.08*(L-1)) | Total Combat Mult | Han Effective HP | Han Effective ATK (+10% Trait) | Han Base DPS | Han Overdrive DPS (+40% Spd) | Star Labor Mult (1.35^(S-1)) | Level Labor Mult (1+0.05*(L-1)) | Han Effective Labor (/min, +25% Synergy) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1★ Base Summon** | 1★ | 1 | 10 | 0 | None | 0 | 1 | 1.000x | 1.00x | 1.000x | 300 | 44 | 51.76 | 72.47 | 1.000x | 1.00x | 17.50 |
| **1★ Mid-Level** | 1★ | 5 | 10 | 826 | None | 0 | 1 | 1.000x | 1.32x | 1.320x | 396 | 58 | 68.24 | 95.53 | 1.000x | 1.20x | 21.00 |
| **1★ Max Level** | 1★ | 10 | 10 | 4,450 | None | 0 | 1 | 1.000x | 1.72x | 1.720x | 516 | 76 | 89.41 | 125.18 | 1.000x | 1.45x | 25.38 |
| **Promote 1★ -> 2★** | 2★ | 1 | 20 | 0 | 1x Promotion Stone | 1,500 | 2 | 1.650x | 1.00x | 1.650x | 495 | 73 | 85.88 | 120.24 | 1.350x | 1.00x | 23.63 |
| **2★ Mid-Level** | 2★ | 10 | 20 | 4,450 | None | 0 | 2 | 1.650x | 1.72x | 2.838x | 851 | 125 | 147.06 | 205.88 | 1.350x | 1.45x | 34.26 |
| **2★ Max Level** | 2★ | 20 | 20 | 21,813 | None | 0 | 2 | 1.650x | 2.52x | 4.158x | 1,247 | 183 | 215.29 | 301.41 | 1.350x | 1.95x | 46.07 |
| **Promote 2★ -> 3★** | 3★ | 1 | 30 | 0 | 3x Promotion Stones | 7,500 | 6 | 2.723x | 1.00x | 2.723x | 817 | 120 | 141.18 | 197.65 | 1.823x | 1.00x | 31.89 |
| **3★ Mid-Level** | 3★ | 15 | 30 | 11,401 | None | 0 | 6 | 2.723x | 2.12x | 5.772x | 1,732 | 254 | 298.82 | 418.35 | 1.823x | 1.70x | 54.22 |
| **3★ Max Level** | 3★ | 30 | 30 | 56,906 | None | 0 | 6 | 2.723x | 3.32x | 9.039x | 2,712 | 398 | 468.24 | 655.53 | 1.823x | 2.45x | 78.14 |
| **Promote 3★ -> 4★** | 4★ | 1 | 40 | 0 | 8x Promotion Stones | 35,000 | 24 | 4.492x | 1.00x | 4.492x | 1,348 | 198 | 232.94 | 326.12 | 2.460x | 1.00x | 43.06 |
| **4★ Mid-Level** | 4★ | 20 | 40 | 21,813 | None | 0 | 24 | 4.492x | 2.52x | 11.320x | 3,396 | 498 | 585.88 | 820.24 | 2.460x | 1.95x | 83.96 |
| **4★ Max Level** | 4★ | 40 | 40 | 114,209 | None | 0 | 24 | 4.492x | 4.12x | 18.508x | 5,552 | 814 | 957.65 | 1,340.71 | 2.460x | 2.95x | 127.02 |
| **Promote 4★ -> 5★** | 5★ | 1 | 50 | 0 | 18x Promotion Stones | 150,000 | 120 | 7.412x | 1.00x | 7.412x | 2,224 | 326 | 383.53 | 536.94 | 3.322x | 1.00x | 58.13 |
| **5★ Mid-Level** | 5★ | 25 | 50 | 36,928 | None | 0 | 120 | 7.412x | 2.92x | 21.643x | 6,493 | 952 | 1,120.00 | 1,568.00 | 3.322x | 2.20x | 127.88 |
| **5★ Max Level** | 5★ | 50 | 50 | 197,521 | None | 0 | 120 | 7.412x | 4.92x | 36.467x | 10,940 | 1,605 | 1,888.24 | 2,643.53 | 3.322x | 3.45x | 200.54 |

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
- **Mana Conduit (`Gems/min`):** `(5 * Level + 0.45 * SumEffectiveLabor) * (1 + 0.12 * (Level - 1))`
- **The Infirmary (`Stamina/sec` & `Coma Duration`):** `StaminaRegen = 2.5 + (0.4 * Level) + (0.06 * SumEffectiveLabor)` | `ComaSec = MAX(20, 60 / (1 + 0.05 * (Level - 1) + 0.008 * SumEffectiveLabor))`
*(Worker Benchmarks below use **Catio** (`20 Base Labor + 25% Synergy`) for Mana Conduit and **Aaron** for Infirmary).*

| Facility Name | Facility Level | Upgrade Cost (Gold) | Max Worker Slots | Facility Level Mult | Base Output / Min (0 Workers) | Output / Min (1★ Lv.10 Workers Filled) | Output / Min (2★ Lv.20 Workers Filled) | Output / Min (3★ Lv.30 Workers Filled) | Physical Chest / Capacity Cap |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Mana Conduit** | **Level 1** | 0 *(Starter)* | 1 Slot | 1.00x | 5.0 Gems/m | 21.3 Gems/m *(1 Worker)* | 34.6 Gems/m *(1 Worker)* | 55.3 Gems/m *(1 Worker)* | 150 Gems |
| **Mana Conduit** | **Level 2** | 800 Gold | 1 Slot | 1.12x | 11.2 Gems/m | 29.5 Gems/m *(1 Worker)* | 44.4 Gems/m *(1 Worker)* | 67.5 Gems/m *(1 Worker)* | 300 Gems |
| **Mana Conduit** | **Level 3** | 2,500 Gold | 2 Slots | 1.24x | 18.6 Gems/m | 59.1 Gems/m *(2 Workers)* | 92.1 Gems/m *(2 Workers)* | 143.3 Gems/m *(2 Workers)* | 600 Gems |
| **Mana Conduit** | **Level 4** | 7,500 Gold | 2 Slots | 1.36x | 27.2 Gems/m | 71.6 Gems/m *(2 Workers)* | 107.8 Gems/m *(2 Workers)* | 164.0 Gems/m *(2 Workers)* | 1,200 Gems |
| **Mana Conduit** | **Level 5** | 22,000 Gold | 3 Slots | 1.48x | 37.0 Gems/m | 109.5 Gems/m *(3 Workers)* | 168.5 Gems/m *(3 Workers)* | 260.2 Gems/m *(3 Workers)* | 2,500 Gems |
| **The Infirmary & Barracks** | **Level 1** | 0 *(Starter)* | 1 Slot | 1.00x | 2.90 Stam/s (60.0s Coma) | 5.08 Stam/s (46.5s Coma) | 6.85 Stam/s (39.3s Coma) | 9.61 Stam/s (31.7s Coma) | 2 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 2** | 600 Gold | 1 Slot | 1.05x | 3.30 Stam/s (57.1s Coma) | 5.48 Stam/s (44.8s Coma) | 7.25 Stam/s (38.1s Coma) | 10.01 Stam/s (30.9s Coma) | 3 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 3** | 2,000 Gold | 2 Slots | 1.10x | 3.70 Stam/s (54.5s Coma) | 8.05 Stam/s (35.7s Coma) | 11.60 Stam/s (27.9s Coma) | 17.12 Stam/s (20.8s Coma) | 4 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 4** | 6,000 Gold | 2 Slots | 1.15x | 4.10 Stam/s (52.2s Coma) | 8.45 Stam/s (34.7s Coma) | 12.00 Stam/s (27.2s Coma) | 17.52 Stam/s (20.0s Cap) | 5 Recuperation Beds |
| **The Infirmary & Barracks** | **Level 5** | 18,000 Gold | 3 Slots | 1.20x | 4.50 Stam/s (50.0s Coma) | 11.03 Stam/s (29.0s Coma) | 16.35 Stam/s (21.5s Coma) | 24.63 Stam/s (20.0s Cap) | 5 Beds (+15% Max Stam Buff) |

---

## 5. EQUIPPABLE ARTIFACT & BLACKSMITH ECONOMY TABLES

### 5.1 The 7 Star Tiers (Permanent Foundation Base Stats)
Each weapon rolls with an immutable Star Tier (1★ to 7★) determining its un-multiplied base attack attributes:

| Star Tier | Base Attack Power ($ATK_{\text{Base}}$) | Base Attack Speed Bonus ($ASPD_{\text{Base}}$) | Typical Progression Role |
| :---: | :---: | :---: | :--- |
| **1★** | **`+15`** | **`+5.0%`** (`+0.05`) | Starter weaponry (`art_hunters_shortbow`, `art_iron_broadsword`) |
| **2★** | **`+35`** | **`+10.0%`** (`+0.10`) | Mid Ring 1 drops & starter craft (`art_recurve_composite`) |
| **3★** | **`+75`** | **`+16.0%`** (`+0.16`) | Rare Ring 1 sentinel drops (`art_crystal_greatbow`) |
| **4★** | **`+150`** | **`+24.0%`** (`+0.24`) | Ring 2 Corrupted Grove Elite drops |
| **5★** | **`+300`** | **`+34.0%`** (`+0.34`) | Rare Ring 2 Abyssal Executioner drops |
| **6★** | **`+550`** | **`+46.0%`** (`+0.46`) | Rift Warden Floor Boss exclusive drops |
| **7★** | **`+950`** | **`+60.0%`** (`+0.60`) | Dimensional Sovereign World Boss pinnacle drops |

### 5.2 The 16 Rarity Tiers & Blacksmith Upgrade Costs
Weapons ascend through 16 rarity tiers at the Waiting Room Blacksmith Forge, multiplying the base stats:

| Tier Index | Rarity Name | Multiplier | Gold Upgrade Cost | Gems Upgrade Cost | Rarity Hex Color | Visual Aesthetic & Resonance |
| :---: | :--- | :---: | :---: | :---: | :---: | :--- |
| **1** | **Common** | **`1.00x`** | — *(Starter)* | — | `#B0B0B0` | Raw wrought iron & plain ash wood |
| **2** | **Uncommon** | **`1.15x`** | 250 Gold | 0 Gems | `#4BB543` | Polished bronze fittings with leather wrap |
| **3** | **Rare** | **`1.35x`** | 600 Gold | 0 Gems | `#2980B9` | Tempered cobalt steel edge |
| **4** | **Superior** | **`1.60x`** | 1,500 Gold | 0 Gems | `#8E44AD` | Deep amethyst inlay and balance grooves |
| **5** | **Exalted** | **`1.90x`** | 3,500 Gold | 0 Gems | `#D35400` | Bronzed runic plating with warm amber sheen |
| **6** | **Legendary** | **`2.30x`** | 8,000 Gold | 15 Gems | `#F1C40F` | Radiant gold leaf with subtle particle motes |
| **7** | **Mythical** | **`2.80x`** | 18,000 Gold | 35 Gems | `#E74C3C` | Crimson mana channels with pulsing inner embers |
| **8** | **Transcendent**| **`3.40x`** | 40,000 Gold | 75 Gems | `#1ABC9C` | Pure sea-glass teal resonance with mist |
| **9** | **Ascendant** | **`4.10x`** | 90,000 Gold | 150 Gems | `#E056FD` | Neon violet crystal edge with planar crackle |
| **10** | **Ethereal** | **`5.00x`** | 200,000 Gold | 300 Gems | `#686DE0` | Semi-translucent spectral steel with low hum |
| **11** | **Immortal** | **`6.10x`** | 450,000 Gold | 600 Gems | `#FF7979` | Sanguine abyssal alloy with trailing smoke |
| **12** | **Divine** | **`7.50x`** | 1,000,000 Gold | 1,200 Gems | `#F9CA24` | Blinding solar radiant aura with consecrated luster |
| **13** | **Celestial** | **`9.20x`** | 2,200,000 Gold | 2,500 Gems | `#00D2D3` | Cosmic azure starry core with orbital motes |
| **14** | **Primordial** | **`11.30x`** | 5,000,000 Gold | 5,000 Gems | `#FF3838` | Volcanic magma veins with glowing neon ignition |
| **15** | **Supreme** | **`14.00x`** | 12,000,000 Gold | 10,000 Gems | `#BADC58` | Iridescent viridian prism with bloom |
| **16** | **Origin** | **`18.00x`** | 30,000,000 Gold | 25,000 Gems | `#FF9FF3` | Full prismatic animated chroma aura with rift distortion |

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
- **Onboarding Pulls (`T = 0:30`):** Player spends `300 Gems` for 3 pulls (`2x 1★` + `1x 2★`, or `3x 1★`). Player deploys 3 heroes into Ring 1 / Central Crimson Tower and assigns 1 hero to Mana Conduit.
- **Active Extraction Rate:** Player completes 1 physical Relic extraction every `~2.5 minutes`, banking Gold and Gems at the perimeter or plot pad.
- **World Boss Cycles:** Spawns at `T = 20:00` and `T = 40:00`. Even placing Rank #4 or #5 awards `+400 Gems`, `+4,000 Gold`, and `+10% Boss Pity`.

### 6.2 Chronological Milestone Pacing Table (Minutes 0 to 45)

| Milestone Target | Target Unlock Requirements | Active Play Time | Cumulative Gold Earned | Cumulative Gems Earned | Primary Gameplay Loop & Progression Drivers |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **0. Onboarding & First 3 Pulls** | `300 Starter Gems` | **1.0 Min** | 500 Gold | 300 Gems | Spend starter `300 Gems` -> Deploy 3-Hero Squad + Assign 1 Worker to Mana Conduit. |
| **1. First Weapon Ascension** | **250 Gold** | **3.0 Mins** | 1,200 Gold | 340 Gems | Upgrade starter bow/sword to **Uncommon** (`1.15x` multiplier) at the Blacksmith Forge. |
| **2. Mana Conduit Lv.2** | **800 Gold** | **7.5 Mins** | 2,800 Gold | 460 Gems | Upgrade Mana Conduit to Lv.2 -> increases uncollected cap to 300 Gems. |
| **3. Rare Weapon Ascension** | **600 Gold** | **12.0 Mins** | 5,600 Gold | 880 Gems | Upgrade primary weapon to **Rare** (`1.35x` multiplier); squad DPS climbs to ~250. |
| **4. First 2★ -> 3★ Promotion** | **7,500 Gold + 3 Stones** | **22.0 Mins** | 16,500 Gold | 1,950 Gems | First World Boss clear awards `+4,000 Gold` & `+400 Gems`. Synthesize dupes in The Pit, craft Promotion Stones, and promote core hero to 3★! |
| **5. Exalted Weapon Ascension** | **3,500 Gold** | **32.0 Mins** | 28,000 Gold | 2,800 Gems | Ascend weapon to **Exalted** (`1.90x` multiplier), pushing squad DPS past 650. |
| **6. Second World Boss Push** | **5-Hero Squad + Exalted Gear**| **42.0 Mins** | 46,000 Gold | 4,200 Gems | Compete for Rank #1–#3 DPS on Dimensional Sovereign with sprint dodging and overdrive whistles! |
