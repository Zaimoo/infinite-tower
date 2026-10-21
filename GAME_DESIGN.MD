# DOCUMENT 1: COMPLETE GAME DESIGN DOCUMENT (GDD)
**Project Title:** *Infinite Tower: Become a Master!*  
**Target Platform:** Roblox (PC, Mobile, Tablet, Console)  
**Server Capacity:** 5–6 Players per Server  
**Engine Architecture:** Server-Authoritative Data Tables (5 Hz Heartbeat) + Client-Side R15 Visual Interpolation (60 FPS `RenderStepped`) | Hybrid Replication: Central Hub 14-Byte Binary Buffers + Infinite Tower Room-Local v2 Binary Buffers (24-byte entity records, 46-byte header)

---

## 1. EXECUTIVE OVERVIEW & PLAYER FANTASY

### 1.1 High-Concept Pitch
**Infinite Tower: Become a Master!** is a tactical squad-command Action-RPG, extraction sandbox, and fortress progression game inspired by the dark survival manhwa *Pick Me Up, Infinite Gacha*. Players do not play as generic hack-and-slash warriors; instead, each player embodies a **Master**—a dimensional overseer who summons, trains, equips, promotes, and commands a roster of sentient Gacha Heroes from a private floating sanctuary known as the **Master's Fortress Plot**.

### 1.2 The "Pick Me Up" Fantasy & Zero-Waste Roster Economy
In traditional gacha/simulator games, 95% of summons are discarded as worthless stat-sticks, and combat is reduced to passive AFK auto-clicking. **Infinite Tower** solves both problems through two foundational pillars:

1. **The Dual-Role Living Roster (Combat + Labor):**
   - Every hero pulled from the Summoning Altar rolls with **Combat Stats** (movement speed, attack speed, attack damage, health) and **Labor Output** (separate facility productivity), without trait or imprint bonuses.
   - **Up to 5 Deployed Heroes** (all 5 slots unlocked from the start) accompany the Master into the Central Hub or are independently deployed to specific floors (1–50) of the **Infinite Tower**. Heroes expend **Stamina** as they fight and risk a debilitating **60-second Coma** if left inside lethal AoE telegraphs.
   - **Benched Heroes** physically inhabit the player's **Fortress Plot** on recuperation beds in **The Infirmary & Barracks** (Stamina & Coma recovery), or can be forged powerful equipment at the **Blacksmith Forge**.
   - **Zero Dead Pulls:** Duplicate 1★–3★ heroes are fed into the **Synthesis Chamber** (`SynthesisController.luau`) for EXP leveling to cap (`MaxLevel = Stars * 10`), or converted into materials for Gold-and-Stone **Star Promotion** ($1★ \to 5★$), which keeps the current level.
   - **Dual Gacha & Artifact Ascension:** In addition to summoning heroes, Masters spend Gems at the **Artifact Summoning Banner** to pull equippable weapons, shields, and rings across **16 Rarity Tiers** (`Common` $\to$ `Origin`) which define inherent base stats. At the **Blacksmith Forge** (`ForgeController.luau`), duplicate gear and Gold are used for **Star Promotion** ($1★ \to 7★$), multiplying inherent rarity power by up to **16.00x**, without enhancement levels.

2. **Tactical Master Agency Over AFK Whaling:**
   - The Master carries no personal weapon. Instead, the Master directs squads through battlefield commands—**`[Click / Tap]` Focus Target**, **`[Q]` Overdrive Whistle**, and **`[E]` Emergency Recall Whistle**—while physically hauling heavy, high-value **Relics** and cargo back to their plot.
   - Masters use **`[LeftShift]` Sprint** ($3.0\times$ speed multiplier) to cross high-elevation bridges and dodge lethal hazards.
   - Because boss signature skill checks (the **Biome Boss** signature attacks like *Moss Quake* and *Sweeping Roots*, and elite ground telegraphs) inflict instant 50% Stamina loss or a **60-second Coma** on heroes left inside the blast zone, an AFK player will have their squad wiped and sent to the Infirmary, dropping their DPS to zero. An active Master who times **`[E]` Emergency Recall Whistle** to dodge the blast and triggers **`[Q]` Overdrive Whistle** during punish windows will consistently out-damage and out-loot an AFK whale.

### 1.3 Hybrid Retention Matrix & Core Drivers

| Reference Title | Adopted Core Mechanic | *Infinite Tower* Evolution |
| :--- | :--- | :--- |
| ***Pick Me Up, Infinite Gacha*** | Desperate squad survival, Synthesis chamber, Star Promotion, living lobby workers | Heroes suffer Stamina drain and `Coma` if mismanaged; 4★/5★ heroes require hard promotion sacrifices; War Banner plot deployment. |
| ***Pet Simulator 99*** | Multi-unit squad grinding, tactile loot explosions, exponential progression | Replaces passive pet hovering with Stamina-managed combat squads, active whistle commands, and isolated 50-floor dynamic tower rooms. |
| ***Blox Fruits*** | Telegraphed boss skills, live DPS leaderboards, open-world bounty hunting | **Greed vs. Coma** boss checks, 10 **Biome Bosses** (Floors 5, 10, ..., 50), and **Contested Loot & Targeted Retaliation PvP** in arena rings. |
| ***Grow a Garden*** | Cozy-yet-competitive perimeter plots, passive production, fortress management | Dedicated private plots with Infirmary recuperation beds, War Banner squad deployment, and Forge progression. |
| ***Steal an Egg*** | Physical object hauling, movement penalties, fumble & steal tension | High-tier **Relics** & cargo weld overhead, slow WalkSpeed by up to -45%, and fumble on AoE hits. |

**The Intimate Server Dynamic:**
In a 5–6 player server, anonymity disappears. Every player knows who conquered the latest Biome Boss, who just scooped contested loot, and who holds an active 3-minute retaliation grudge. The interplay of high-stakes extraction, boss timing, and targeted revenge loops keeps players engaged in continuous Biome Boss clears and Infinite Tower floor pushes.

---

## 2. DETAILED CORE LOOPS

```mermaid
flowchart TD
    subgraph Micro["3-Minute Loop: Grind & Extract"]
        M1["Deploy 5 Rested Heroes (Hub Arena or Tower Floors 1-50)"] --> M2["Command Squad: Focus Target, [Q] Overdrive, [E] Recall Dodge"]
        M2 --> M3["Pick Up Physical Loot / Relic (-15% to -45% WalkSpeed)"]
        M3 --> M4["Haul Across Bridges or Portals to Plot Pad (Dodge AoE & Loot Thieves)"]
        M4 --> M5["Bank Gold & Gems; Swap Exhausted Heroes into Infirmary Beds"]
        M5 --> M1
    end

    subgraph Meso["15-Minute Loop: Recovery, Synthesis, Promotion & Forge"]
        T1["Gather Gold & Gems from Drops, Relics & Tower Floors"] --> T2["Summoning Altar: Pull Hero Banner & Artifact Banner (100 Gems)"]
        T2 --> T3["Synthesis Chamber: Feed Duplicates for XP & Max Level Cap"]
        T3 --> T4["Promotion Altar: Gold & Promotion Stones (1★ -> 5★); Keep Level"]
        T4 --> T5["Blacksmith Forge: Weapon Star Promotion (1★ -> 7★); No Enhancement Levels"]
    end

    subgraph Macro["Macro Loop: Tower Progression & Biome Boss Conquests"]
        B1["Prepare Squad: Rest to 100% Stamina & Equip High-Rarity/Star Artifacts"] --> B2["Advance Tower Floors: Clear Mobs & Elites across 5-Floor Biome"]
        B2 --> B3["Engage Biome Boss on Floor Milestone (Floor 5, 10, 15... 50)"]
        B3 --> B4["Dodge Signature Telegraphed AoEs (Self/Target Discs) via [E] Recall"]
        B4 --> B5["Punish Window: Trigger [Q] Overdrive to Burst Down Boss HP"]
        B5 --> B6["Claim Pinnacle Rewards: Massive Gold/Gems & High-Rarity Pinnacle Artifact Drops"]
        B6 --> B7["Unlock Next Biome Tier & Advance to Higher Tower Floors"]
    end

    Micro --> Meso
    Meso --> Macro
    Macro --> Micro
```

### 2.1 The 3-Minute Micro Loop (Grind, Command & Physical Extraction)
1. **Deploy & Traverse (0:00 – 0:15):**
   - The Master selects up to 5 rested heroes from their roster via the **War Banner** or **Squad Deploy UI** (`SquadController.luau`).
   - The Master can sprint (`[LeftShift]`, $3.0\times$ speed) across high-elevation stone bridges onto the **Central Hub**, or use the **Tower Controller** (`TowerController.client.luau`) to travel (`Visit floor`) or station their squad (`Assign squad`) on any of the 50 **Infinite Tower Floors**.
2. **Tactical Grind & Stamina Expenditure (0:15 – 2:00):**
   - The Master uses **`[Click / Tap]` Focus Target** to direct all 5 deployed heroes onto target mobs, crystal nodes, or floor bosses.
   - To accelerate clears, the Master triggers **`[Q]` Overdrive Whistle** (`20s CD`), trading `5 Stamina` per hero for `+40% Attack Speed` for `5s`.
   - When an Elite or Boss telegraphs a red ground AoE (`ARC`, `SELF_DISC`, or `TARGET_DISC`), the Master triggers **`[E]` Emergency Recall Whistle** (`6s CD`), warping all 5 heroes to the Master's safe position and dropping their aggro for `2s`.
3. **Physical Loot Haul (2:00 – 2:45):**
   - Defeating mobs/Elites spawns physical drops in `Workspace.PhysicalLoot` (**Bounty Bags**, **Mana Geodes**, **Cursed Urns**, and **Abyssal Cores**).
   - The Master touches the drop to weld it overhead, incurring a **-15% to -45% WalkSpeed penalty** (and disabling jumping for high-tier relics).
   - If hit by an Elite/Boss AoE mid-haul, the Master is **stunned for 1s and fumbles the item** (which becomes stealable after a **3s owner-lock**).
4. **Extract & Bank (2:45 – 3:00):**
   - Stepping onto the Perimeter Highway (`R >= 460 studs`) or a Private Extraction Pad safely deposits cargo into permanent Gold and Gems.
   - Depleted heroes (`Stamina < 25%`) are swapped into **Infirmary Recuperation Beds**, and fresh rested heroes are rotated into the active squad via the `[AutoSwap]` toolbar action.

### 2.2 The 15-Minute Meso Loop (Fortress, Synthesis, Promotion & Forge Progression)
1. **Facility Upkeep (Every 3–5 Minutes):**
   - Inspect Infirmary beds and swap resting heroes into active squad rotation.
2. **Summoning & Gacha Pulls (Every 5–10 Minutes):**
   - Spend Gems (`100 Gems` single / `900 Gems` 10x) at the **Summoning Altar** on either the **Hero Banner** (1★–3★ heroes) or the **Artifact Banner** (weapons, shields, and rings across 16 Rarity Tiers).
   - **Synthesis Chamber (`SynthesisController.luau`):** Place a recipient hero and up to 5 fodder heroes to level up to the hero's current cap ($\text{MaxLevel} = \text{Stars} \times 10$).
   - **Promotion Altar (`PromotionController.luau`):** When a hero reaches max level, spend Gold and Promotion Stones to promote star rating ($1★ \to 5★$), keeping the current level and raising the cap by 10.
3. **Artifact Star Promotion at the Blacksmith Forge (`ForgeController.luau`):**
   - Promote an existing weapon from 1★ to 7★ using same-template duplicates and Gold/Gems. Power multipliers are **1.00 / 1.60 / 2.50 / 4.00 / 6.50 / 10.00 / 16.00x**.
   - Rarity is fixed when the item is acquired. A better rarity requires a newly acquired weapon, which starts at 1★. There are no enhancement levels or enhancement-fodder multipliers in the stat model.

### 2.3 The Macro Loop (Tower Progression & Biome Boss Conquests)
1. **Biome Traversal & Preparation:**
   - Masters organize their 5-hero squad, equip high-rarity and high-star artifacts, and ensure full stamina in the Infirmary before entering a new Biome.
   - Each biome spans 5 progressively harder floors. Enemy health and attack damage follow the stat-reference curve in Section 4.2. Reward scaling remains $\text{Reward} \times 1.055^{\text{Floor}-1}$; stat inflation does not change rewards.
2. **The Biome Boss Encounter (Floors 5, 10, 15, ..., 50):**
   - The 5th floor of every biome is a dedicated **Biome Boss Arena** featuring a massive boss dais fixture (e.g. `BossDaisFixture` on Floor 5, $60 \times 2 \times 60\text{ studs}$).
   - The Biome Boss wields devastating signature attacks with distinct shapes and timings:
     - **Basic Attacks:** Wide frontal arcs (`ARC`, e.g. `guardian_crush`, 13 studs).
     - **Signature 1:** Expanding circular ground shocks centered on the boss (`SELF_DISC`, e.g. `moss_quake`, 22 studs radius).
     - **Signature 2:** Ranged ground craters placed under distant heroes (`TARGET_DISC`, e.g. `sweeping_roots`, 55 studs cast range, 13 studs radius).
   - **Tactical Counterplay ("Dodge vs. Coma"):** Masters must watch the expanding telegraph decals and sound cues, repositioning and executing **`[E]` Emergency Recall Whistle** to yank heroes out of danger. Heroes struck by signature skills suffer severe stamina loss or a debilitating **60-second Coma**.
   - **Punish Windows:** Following major signature attacks, the boss enters an extended recovery window (1.2s–1.5s), providing active Masters the ideal moment to pop **`[Q]` Overdrive Whistle** for massive burst DPS.
3. **Biome Clearance & Pinnacle Rewards:**
   - Defeating the Biome Boss awards immense Gold, Gems, and rare direct drops of high-rarity **Pinnacle Artifacts** (from Legendary up to Origin).
   - Bosses unlock clearance to enter the next biome in the Infinite Tower.

---

## 3. MAP & SPATIAL DESIGN SPECIFICATIONS

### 3.1 Dual-Mode Spatial Architecture

The world exists in two coordinated spatial contexts:
1. **The Central Hub & Floating Fortress Ring (World Coordinates):** Landmark Central Crimson Tower, perimeter bridges, and player fortress plots.
2. **The 50 Dynamic Isolated Tower Floors (Off-Map Isolated Grid):** Server-managed dynamic encounter rooms for vertical climbing and Biome Boss arenas.

```
                      CENTRAL HUB ARENA & FLOATING FORTRESS RING
                                    [N: (0, -600)]
                                  +----------------+
                                  |  PLOT 1 (0°)   |
                                  +-------+--------+
                                          | (Bridge)
                     PLOT 5 (288°)        |        PLOT 2 (72°)
                         \                |                /
                   (Bridge)\       +------+------+       /(Bridge)
                             \     |   CENTRAL   |     /
                              -----+   CRIMSON   +-----
                             /     |  TOWER HUB  |     \
                   (Bridge)/       +------+------+       \(Bridge)
                         /                |                \
                    PLOT 4 (216°)         |        PLOT 3 (144°)
                                          | (Bridge)
                                  +-------+--------+
                                  |  Perimeter Rim |
                                  +----------------+
                                    [S: (0, +600)]

               =======================================================
               OFF-MAP INFINITE TOWER ROOMS (Isolated Dynamic Grid)
               Origin(id) = (12000 + ((id-1)%10)*1800, 1000, 12000 + floor((id-1)/10)*1800)
               Enclosed 248 x 84 x 248 studs chambers with Safe Arrival platforms (CombatSafe=true)
               Floors 5, 10, 15, ..., 50 feature dedicated Biome Boss Dais Arenas (BossDaisFixture)
```

### 3.2 Global Coordinate Systems & Zones Table

| Zone Name | Radial Distance / Coordinate Space | Dimensions | Access Rule | Combat & PvP Rules | Primary Drops |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Central Crimson Tower** | `0 – 120 studs` (Hub) | Central 18-level landmark structure | Open to all | Landmark tower hub, open entrance portal to Infinite Tower floors. | Mana Geodes, Gold |
| **Ring 2: Corrupted Grove** | `120 – 280 studs` (Hub) | `160 studs` annulus | Open to all | High-density Elites with red AoE telegraphs. Contested loot PvP active. | **Cursed Urns**, **Abyssal Cores**, High Gold |
| **Ring 1: Outer Ruins** | `280 – 460 studs` (Hub) | `180 studs` annulus | Open from start | Low-level mobs & Mana Crystal nodes. Contested loot PvP active. | **Mana Geodes**, Starter Gold |
| **Perimeter Highway** | `460 – 480 studs` (Hub) | `20 studs` paved ring road | Open to all | **Safe Zone** (No mobs). Safe banking threshold ($R \ge 460$). | Banked cargo conversion |
| **5 Floating Fortress Plots** | `R = 540 studs` ($Y = 12$) | Fortress island mesh with courtyard & walls | Plot Owner + Visitors | Safe Zone. Personal fortress sanctuary for recovery, banner summoning, and forge ascension. | Healing, Blacksmithing, Synthesis, Promotion |
| **Safety Catch Plane** | Lower kill plane at $Y = -95$ | `2400 x 8 x 2400 studs` | Fallen players | Non-lethal catch plane; teleports fallen players safely to their PlotSpawn. | None |
| **50 Tower Floor Rooms** | Off-map grid: $X \ge 12,000, Y = 1,000, Z \ge 12,000$ | `248 x 84 x 248 studs` each | Traversal via `TowerController` | Isolated floor-local PvE encounters; shared floor membership; safe arrival zone. | Mob drops, Gold, Gems, **Biome Boss Pinnacle Artifacts** |

### 3.3 Dynamic Tower Room Architecture & Biomes

Tower floors are dynamically managed by `TowerFloorService.luau` and generated via `TowerRoomBuilder.luau`:
- **Room Origin Formula:**
  $$\text{Origin}(id) = \Big(12000 + ((id - 1) \bmod 10) \times 1800,\; 1000,\; 12000 + \lfloor(id - 1) / 10\rfloor \times 1800\Big)$$
- **Enclosure:** Enclosed $248 \times 84 \times 248\text{ studs}$ slate walls and opaque ceiling, preventing cross-floor visual overlap or raycast leakage.
- **Safe Arrival Zone:** $70 \times 0.2 \times 42\text{ studs}$ elevated landing pad at `origin + (0, 0.1, 90)` designated with `CombatSafe = true`, `CanBankCargo = false`.
- **Travel Pedestals:** 4 ProximityPrompt interaction points on the arrival pad:
  - `PREVIOUS`: Move to floor $id - 1$ (disabled on Floor 1).
  - `NEXT`: Move to floor $id + 1$ (disabled on Floor 50).
  - `SELECTOR`: Opens the full 50-floor modal selector.
  - `HUB`: Returns player directly to their Fortress Plot.
- **Room Lifecycle:** Rooms transition through `ABSENT -> BUILDING -> READY -> RETIRING -> ABSENT` with a 60-second retirement grace period when unoccupied.

#### Biome Catalog (50 Floors across 10 Biomes):
1. **Verdant Ruins (Floors 1–5):** Overgrown Threshold, Broken Aqueduct, Rootway Crossing, Vinebound Bastion, **Mossbound Court (Biome Boss: Mossbound Guardian)**.
2. **Fungal Hollow (Floors 6–10):** Sporelit Entry, Mycelium Galleries, Blooming Chasm, Rotcap Keep, **Matriarch's Hollow (Biome Boss: Spore Matriarch)**.
3. **Drowned Steps (Floors 11–15):** Drowned Steps, Coral Cloister, Tidal Channels, Pearlguard Vault, **Leviathan's Basin (Biome Boss: Abyssal Leviathan)**.
4. **Cinder Gate (Floors 16–20):** Cinder Gate, Buried Caravan, Glasswind Ravine, Sunscar Fortress, **Colossus Dais (Biome Boss: Cinder Colossus)**.
5. **Rimefall Approach (Floors 21–25):** Rimefall Approach, Frozen Barracks, Shattered Iceway, Whiteguard Keep, **Frostbound Throne (Biome Boss: Frost Sovereign)**.
6. **Stormgrass Rise (Floors 26–30):** Stormgrass Rise, Thunderhead Outpost, Skybridge Cliffs, Tempest Redoubt, **Roc's Eyrie (Biome Boss: Tempest Roc)**.
7. **Slagworks Entry (Floors 31–35):** Slagworks Entry, Molten Assembly, Furnace Causeway, Ironflame Bulwark, **Titan's Crucible (Biome Boss: Slagwork Titan)**.
8. **Blighted Verge (Floors 36–40):** Blighted Verge, Twisted Orchard, Briar Labyrinth, Heartrot Stronghold, **Sovereign's Grove (Biome Boss: Heartrot Sovereign)**.
9. **Starlit Vestibule (Floors 41–45):** Starlit Vestibule, Orbiting Stacks, Fractured Index, Runeguard Athenaeum, **Rift Warden's Observatory (Biome Boss: Rift Warden)**.
10. **Abyssal Descent (Floors 46–50):** Abyssal Descent, Crimson Procession, Voidspan Crossing, Dreadguard Citadel, **Overlord's Throne (Biome Boss: Abyssal Overlord)**.

### 3.4 Private Fortress Plot Internal Layout
Each of the 5 Floating Fortress Islands is oriented radially toward the central tower:
- **Plaza & Extraction Pad:** Glowing cyan platform for depositing carried cargo into permanent vault currency.
- **Summoning Altar:** Dimensional obelisk for 100-Gem Hero and Artifact Banner Gacha pulls.
- **War Banner:** Physical banner with proximity prompt that opens the **Squad Deploy UI** (`SquadController.luau`).
- **Synthesis Chamber:** Fiery cauldron station with `[F]` prompt opening the **Synthesis UI** (`SynthesisController.luau`) for feeding EXP fodder.
- **Promotion Altar:** Consecrated star ascension dais with `[F]` prompt opening the **Promotion UI** (`PromotionController.luau`).
- **The Blacksmith Forge:** Interactive 3D station featuring an anvil, hearth coals, workbench, and prompt opening the **Forge UI** (`ForgeController.luau`) for weapon Star Promotion.
- **The Infirmary & Barracks:** Recuperation beds where exhausted or `Coma`-afflicted heroes lie down while assigned Healers accelerate stamina recovery.

---

## 4. HERO, COMBAT & UI MECHANICS

### 4.1 Gacha Banner & Base Archetypes
- **Summon Cost:** `100 Gems` per single pull (`900 Gems` for 10x pull).
- **Drop Rates:** `1★ Common (70.0%)`, `2★ Rare (25.0%)`, `3★ Epic (5.0%)`. `4★` and `5★` are obtained exclusively via **Star Promotion**.

#### Launch Roster Base Stats (At 1★, Level 1)
Every summoned hero rolls a `QualityScalar` $q \in [0.90, 1.15]$ applied to attack damage and health. The four combat stats are **movement speed**, **attack speed**, **attack damage**, and **health**. Movement speed is 20 studs/s for launch heroes; attack speed is the reciprocal of the listed base interval. Range is targeting metadata and labor is facility output. Named heroes use the one-star seeds in Document 3; the archetype table below supplies fallback seeds:

| Archetype | Base HP ($HP_0$) | Base ATK ($ATK_0$) | Attack Interval ($t_{\text{atk}}$) | Attack Range | Base Labor ($L_0$) | Preferred Facility (+25% Synergy) | Permitted Weapons |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Vanguard** (Tank) | `450` | `22` | `1.20s` | `6 studs` | `10 / min` | None | `SWORD`, `AXE`, `SHIELD` |
| **Striker** (Melee DPS) | `280` | `38` | `0.85s` | `6 studs` | `12 / min` | None | `SWORD`, `DAGGERS`, `SHIELD` |
| **Marksman** (Ranged DPS) | `210` | `34` | `0.80s` | `28 studs` | `13 / min` | None | `BOW` |
| **Miner** (Gem Specialist) | `300` | `20` | `1.05s` | `6 studs` | `20 / min` | None | `AXE`, `SHIELD` |
| **Healer** (Infirmary Spec.) | `260` | `18` | `1.25s` | `24 studs` | `18 / min` | **The Infirmary & Barracks** | `STAFF`, `TOME` |
| **Scholar** (Spell Specialist)| `220` | `24` | `1.00s` | `26 studs` | `22 / min` | None | `TOME`, `STAFF` |

*(Note: Rings (`RING`) are universal accessories and can be equipped by any archetype).*

### 4.2 Effective Combat & Labor Formulas

**Stat-only design revision (2026-10-22; implementation pending).** This section changes calculations and progression. Banner, acquisition, drop rates, rewards, and navigation retain their existing rules. The complete [calculated reference](docs/balance/STAT_SCALING_TABLES.md) and [50-floor stat CSV](docs/balance/FLOOR_SCALING.csv) are generated by the offline calculator.

#### 4.2.1 Leveling, stars, and the four combat stats

`S` is hero stars (1–5), `L` is level (1–`10*S`), `q` is summon quality. Weapon rarity is inherent; weapon stars are progressive. `D0`, `H0`, `AS0`, and `MS0` are immutable one-star level-one seeds. Use the named hero's seeds when available.

$$G(S,L) = 3^{S-1} \times 1.08^{L-1}$$

$$P = InherentRarityPower \times WeaponStarMultiplier$$

$$AttackDamage = \operatorname{round}\left(D_0 \times q \times G(S,L) \times \left(1 + \frac{P}{40}\right)\right)$$

$$Health = \operatorname{round}\left(H_0 \times q \times G(S,L)\right)$$

$$AttackSpeed = \min\left(5,\; AS_0 \times (1 + RaritySpeedBonus) \times OverdriveMultiplier\right)$$

$$MovementSpeed = MS_0 = 20\text{ studs/s for launch heroes}$$

- **Promotion keeps level.** Raise the cap by 10 and multiply trained damage and health by 3 at the same level; multiply labor's star factor by 1.35. No level reset or post-promotion power loss.
- **Each level compounds damage and health by 1.08.** The old linear `1 + 0.08*(L-1)` factor is retired. Level 50 alone gives about 43.43x; combined with 5-star promotion the hero growth factor is about 3,517.62x.
- **Weapon power amplifies the trained hero.** 20 power gives `1.50x` damage; 180 power gives `5.50x`. The fixed 40-point denominator is shared by all weapon types. A hero's seed damage, quality, level, and stars still matter at every weapon tier. Unequipping uses `P = 0`.
- **Only damage and health grow exponentially.** Weapon star promotion multiplies power only. Rarity never changes on an owned weapon. Weapon rarity supplies a bounded attack-speed bonus. Movement speed, targeting range, labor, and stamina do not inherit combat growth. Coma disables movement/attacks; it does not change the stored movement-speed seed.
- **Reference loadout:** The DPS benchmark uses one weapon per hero and the four specified combat stats. It assumes no additional accessory, critical-hit, or proc multipliers; it does not change the item catalog or equip permissions.
- **Round damage and health once, at the end.** Derive from immutable seeds rather than repeatedly multiplying already-scaled fields. `ATK` and `HP` in legacy code are aliases for attack damage and health, not extra stats.

Attack range remains fixed targeting metadata. Master sprint and relic-carry movement penalties belong to the player character and do not modify hero movement speed.

#### 4.2.2 DPS definition, commands, and the floor-50 target

The acceptance target is **at least 1B total squad DPS at 75% combat uptime**, using five 5-star level-50 heroes, Mythical 7-star weapons, and quality as low as 0.90. No higher-than-Mythical drop, critical hit, Overdrive, exposure bonus, paid modifier, or exclusive hero is required.

The conservative calculation matches a 5 Hz cooldown reset:

```text
Interval = 1 / AttackSpeed
TickInterval = 0.20 * CEILING(Interval / 0.20)
HeroDPS = AttackDamage / TickInterval
SquadDPS = SUM(HeroDPS of deployed heroes)
EncounterDPS = SquadDPS * AttackUptime
```

For Han / Jenna / Aaron / Velkist / Eolka, with quality 1.00 and Mythical 7-star weapons:

| Measure | Design result |
| --- | --- |
| Sustained five-hero squad DPS while attacking | **2.550B** |
| DPS at 75% attack uptime | **1.913B** |
| DPS at 75% uptime and minimum 0.90 quality | **1.721B** |
| Han normal hit with Mythical | **394.114M** |
| Han health | **1.055M** |

`[Q]` Overdrive multiplies attack speed by 1.40 for 5s, on a 20s cooldown, at 5 stamina per hero. It does not multiply hit damage or create critical hits. Exposure multiplies hit damage by 1.25 only while the target is exposed. These two effects are distinct. Exhaustion multiplies hit damage by 0.20; coma produces zero DPS. The benchmark is a rested combat window, not an infinite-duration AFK DPS claim.

Preserving cooldown remainder in a later implementation would reduce tick-quantization losses. Until then, show conservative scheduled DPS in previews; a 40% attack-speed buff can cross different tick boundaries for different heroes. Confirm actual output in Studio before claiming smooth speed gains.

#### 4.2.3 Enemy scaling and encounter duration

Use the [generated expected-build checkpoints and 50-floor CSV](docs/balance/STAT_SCALING_TABLES.md). Five copies of Han provide a reproducible calibration squad; the mixed launch squad above verifies the target without an exclusive summon. Checkpoint equipment is an **earned build available before that encounter**, never a stat grant for visiting its floor.

For adjacent checkpoints `(fa, Da)` and `(fb, Db)`, compute the intermediate floor's expected squad output as `D(f) = Da * (Db/Da)^((f-fa)/(fb-fa))`. Interpolate reference Han health geometrically in the same way. This avoids abrupt enemy stat jumps at a hero promotion or weapon rarity threshold.

| Enemy role | Maximum health | Basic attack damage | Focused contact-time target |
| --- | --- | --- | --- |
| Regular | `ROUND(2 * D(f))` | `ROUND(0.015 * ReferenceHeroHealth(f))` | 2s |
| Elite | `ROUND(8 * D(f))` | `ROUND(0.030 * ReferenceHeroHealth(f))` | 8s |
| Biome boss | `ROUND(45 * D(f))` | `ROUND(0.040 * ReferenceHeroHealth(f))` | 45s |

These are static floor configurations. They do not read the visiting player's equipment and do not erase the benefit of an upgrade. Bosses spawn every fifth floor only. Additional squads share the existing encounter and shorten the fight; there is no per-visitor health inflation in this floor curve. Attack timings and signature patterns remain authored by the enemy catalog.

Floor 50 has about **4.926B regular health**, **19.706B elite health**, and **110.845B boss health**. The Mythical mixed squad takes about **43.5s** of uninterrupted attacks, or **58.0s at 75% uptime**, to defeat that boss before commands. Overdrive and exposure shorten the fight. Tune boss encounters around roughly **40–65s for the reference build**, with rested heroes and correct recalls. Recheck stamina against actual encounter density: current attack-state drain is 1.5/s, Overdrive costs 5, and signatures still remove 50% stamina or cause coma. Damage growth does not bypass these skill checks.

#### 4.2.4 Facility output

$$EffectiveLabor = L_0 \times q \times 1.35^{S-1} \times (1 + 0.05(L-1)) \times (1 + B_{Synergy})$$

`B_Synergy = 0.25` when assigned to the preferred facility (including the existing all-facility preference), applied once. Labor is facility output, separate from the four combat stats. It receives no weapon, trait, or inherited-memory modifier. Infirmary formulas in Section 4.3 remain unchanged.

### 4.3 Fortress Plot Facility Output Formulas
The Infirmary upgrades from **Level 1 to Level 5** using Gold:
- **Upgrade Table:**
  - Level 1: Free (Default), 1 Max Worker, 2 Beds.
  - Level 2: 600 Gold, 1 Max Worker, 3 Beds.
  - Level 3: 2,000 Gold, 2 Max Workers, 4 Beds.
  - Level 4: 6,000 Gold, 2 Max Workers, 5 Beds.
  - Level 5: 18,000 Gold, 3 Max Workers, 5 Beds.
- **Stamina Recovery Rate:**
  $$\text{StaminaRegenPerSec} = 2.5 + (0.4 \times F) + (0.06 \times \sum \text{EffectiveLabor})$$
- **Coma Duration Reduction:**
  $$\text{EffectiveComaDuration} = \max\left(20\text{s}, \frac{60\text{s}}{1 + 0.05(F - 1) + 0.008 \sum \text{EffectiveLabor}}\right)$$

### 4.4 Master Controls & Tactical Commands

| Action | Keybind / Input | Description |
| :--- | :--- | :--- |
| **Shift Sprint** | `[LeftShift / RightShift]` | $3.0\times$ speed multiplier for rapid traversal across bridges, rings, and rooms. |
| **Focus Target** | `[Click / Tap]` | Raycast onto any mob, boss, or thief to focus all 5 heroes' aggro. |
| **Overdrive Whistle** | `[Q]` / Bottom Bar | $20\text{s}$ CD. Consumes $5$ Stamina/hero for $+40\%$ Attack Speed for $5\text{s}$. |
| **Emergency Recall** | `[E]` / Bottom Bar | $6\text{s}$ CD. Instantly warps squad to Master + $2\text{s}$ pacify (dodges lethal AoE). Yields priority to ProximityPrompts. |
| **Drop Carried Item**| `[R]` / HUD Button | Drops carried cargo or relic on the ground; restores normal WalkSpeed. |
| **Retaliate Attack** | `[⚔️ RETALIATE]` | Single-click HUD prompt when your drop is stolen to unleash squad PvP retaliation. |

### 4.5 Tactical UI & HUD Architecture

The player interface is built from modular, gothic-styled components:
1. **Bottom Navigation Toolbar (`BottomToolbar`):**
   - **Left:** `[PATCH NOTES]` button displaying current server update toasts.
   - **Center Group:** `[THE PIT]` (opens Synthesis/Promotion modals) | `[FORGE]` (opens Blacksmith Star Ascension / Enhancement modal) | `[SQUAD]` (opens 5-Hero Squad Deploy modal) | `[OVERDRIVE]` (Whistle 1 / Q) | `[RECALL]` (Whistle 2 / E) | Vertical Divider | `[AutoSwap]` (4-way arrow icon: auto-swaps exhausted heroes with bench) | `[RosterGrid]` (3x3 grid icon: toggles Squad Deploy modal).
   - **Right Group:** Settings Gear (toggles telemetry overlay) | `[SAVE]` button (manual profile save trigger).
2. **Tower Navigation UI (`TowerController.client.luau`):**
   - **TravelBar (Top of Screen):** Persistent navigation bar displaying `[Previous]`, `[Next]`, `[Floor selector]`, and `[Hub]` buttons.
   - **Floor Selector Modal (`FloorSelector`):** Responsive 50-floor grid showing milestone **Biome Boss floors** (`◆`), biome names, current visitors count, assigned player squads, and action buttons (`Visit floor`, `Assign squad`, `Recall squad`).
3. **Real-Time Combat Feedback (`CombatFeedback.luau`):**
   - **Damage Popups:** Server-hit floating damage labels pooled up to 32 active instances. Styled with `GothamBold` font, quadratic easing upward, and color-coded:
     - Gold (`#FFCF59`): Overdrive crits / empowered hits.
     - Pale Green (`#F3FFE2`): Normal outbound hero damage.
     - Coral Red (`#FF7474`): Incoming damage received by heroes.
   - **Hit Sparks:** Material Neon sphere sparks with dynamic scaling and fade.
   - **Telegraph Geometry:** Authoritative server-timed warning decals and cylinders (`ARC`, `SELF_DISC`, `TARGET_DISC`).

---

## 5. BIOME BOSS ENCOUNTER DESIGN (MILESTONE FLOORS)

### 5.1 Architecture & Biome Milestone Cadence
In **Infinite Tower**, major boss encounters take place at the apex of each biome: every 5th floor of the Infinite Tower (Floors 5, 10, 15, 20, 25, 30, 35, 40, 45, 50). Each Biome Boss commands a massive dedicated arena dais ($60 \times 2 \times 60\text{ studs}$ `BossDaisFixture`) and possesses dynamic health, high damage multipliers, and signature multi-phase telegraphed attacks.

#### The 10 Biome Bosses:

| Floor | Biome Name | Biome Boss Name | Rig Family | Maximum Health | Basic Attack Damage | Signature Attack Types |
| :---: | :--- | :--- | :--- | :---: | :---: | :--- |
| **5** | **Verdant Ruins** | **Mossbound Guardian** | `STONE_COLOSSUS` | `22,050` | `16` | Frontal Cleave (`ARC`), Quake (`SELF_DISC`), Root Bloom (`TARGET_DISC`) |
| **10** | **Fungal Hollow** | **Spore Matriarch** | `FUNGAL_MATRIARCH` | `76,500` | `24` | Spore Burst (`SELF_DISC`), Corrosive Cloud (`TARGET_DISC`) |
| **15** | **Drowned Steps** | **Abyssal Leviathan** | `LEVIATHAN` | `470,813` | `106` | Tidal Sweep (`ARC`), Maelstrom (`SELF_DISC`), Geyser Strike (`TARGET_DISC`) |
| **20** | **Cinder Gate** | **Cinder Colossus** | `FIRE_COLOSSUS` | `1,784,250` | `155` | Magma Cleave (`ARC`), Eruption (`SELF_DISC`), Fire Rain (`TARGET_DISC`) |
| **25** | **Rimefall Approach** | **Frost Sovereign** | `FROST_GIANT` | `12,198,938` | `685` | Glacial Smash (`ARC`), Blizzard Shock (`SELF_DISC`), Ice Spikes (`TARGET_DISC`) |
| **30** | **Stormgrass Rise** | **Tempest Roc** | `GIANT_AVIAN` | `83,724,469` | `1,006` | Gale Slash (`ARC`), Thunderclap (`SELF_DISC`), Lightning Strike (`TARGET_DISC`) |
| **35** | **Slagworks Entry** | **Slagwork Titan** | `MAGMA_CONSTRUCT` | `950,189,344` | `4,436` | Anvil Hammer (`ARC`), Slag Quake (`SELF_DISC`), Molten Core (`TARGET_DISC`) |
| **40** | **Blighted Verge** | **Heartrot Sovereign** | `CORRUPTED_TREANT` | `5,352,379,031` | `6,517` | Briar Whip (`ARC`), Heartrot Bloom (`SELF_DISC`), Rot Tendrils (`TARGET_DISC`) |
| **45** | **Starlit Vestibule** | **Rift Warden** | `COSMIC_ENTITY` | `23,593,202,156` | `28,728` | Astral Sweep (`ARC`), Dimensional Rupture (`SELF_DISC`), Void Well (`TARGET_DISC`) |
| **50** | **Abyssal Descent** | **Abyssal Overlord** | `DEMONIC_OVERLORD` | `110,844,632,813` | `42,211` | Hellfire Cleave (`ARC`), Abyssal Nova (`SELF_DISC`), Doom Pillars (`TARGET_DISC`) |

### 5.2 Tactical Mechanics & Combat Flow ("Greed vs. Coma")
1. **Telegraph Shapes & Timings:**
   - **`ARC` (Basic Cleave):** Fast frontal swipe ($1.1\text{s}$ windup, $1.0\text{s}$ recovery, 13-stud reach). Vanguard tanks should position facing away from squishier DPS heroes.
   - **`SELF_DISC` (Boss Quake):** Expanding crimson circle centered on the boss ($1.8\text{s}$ windup, $1.2\text{s}$ recovery, 22-stud radius). Masters must sprint out and trigger **`[E]` Emergency Recall** before impact.
   - **`TARGET_DISC` (Targeted AoE):** Red circle targeted at distant heroes ($2.2\text{s}$ windup, $1.5\text{s}$ recovery, 13-stud radius). Requires instant Master recognition and recall repositioning.
2. **Coma Skill Check:**
   - Heroes caught inside `SELF_DISC` or `TARGET_DISC` blast zones suffer instant 50% Stamina loss or fall into a **60-second Coma** (expelled back to the Fortress Infirmary).
3. **Punish Window:**
   - Immediately following a Signature detonation, the Biome Boss enters an exposed recovery window granting $+25\%$ damage taken for 4.0s. Active Masters trigger **`[Q]` Overdrive Whistle** to unleash $+40\%$ squad attack speed and maximize DPS output.

### 5.3 Biome Boss Loot & Progression Ledger
- **Encounter Respawns:** Biome Bosses operate on an authoritative server respawn cadence ($300\text{s}$ cooldown upon defeat).
- **Rewards Table:**
  - **Tiered Gold & Gems:** Scaled exponentially to biome difficulty.
  - **Pinnacle Artifact Drops:** Rare direct drops of high-rarity Pinnacle Artifacts (from Legendary up to Origin tier, e.g. `art_paladin_claymore`, `art_crystal_greatbow`, `art_blade_of_the_rift`).
  - **Biome Key / Floor Advancement:** Defeating the Biome Boss permanently unlocks the subsequent biome on the **Floor Selector**.

---

## 6. CONTESTED LOOT & RETALIATION PVP

### 6.1 Contested Loot & Targeted Retaliation PvP
1. **Universal Physical Drops:** Monsters and crystal nodes drop 3D physical cargo in `Workspace.PhysicalLoot` tagged with `KillerUserId`.
2. **Physical Overhead Hauling:** Picking up loot welds it overhead, slows movement by `-15%` to `-45%`, and triggers the upper-arm holding pose (`HoldingAnimationController.client.luau`).
3. **Theft Detection & Retaliation:** Picking up another player's loot flags the player as a `[Loot Thief]` and registers a 3-minute retaliation grudge. The victim receives a real-time HUD alert with a `[⚔️ RETALIATE]` button.
4. **Squad-vs-Squad Clash:** Clicking `[⚔️ RETALIATE]` commands your squad to attack the thief's squad at $25\%$ PvP damage scaling. The targeted squad auto-retaliates. Defeated heroes enter `COMA`.
5. **Squad Wipe & Spilled Loot:** On squad defeat, all carried loot spills onto the ground, and field looting is locked until the Master returns to their Fortress Plot to heal in the Infirmary.
6. **Perimeter Banking:** Reaching the perimeter highway ($R \ge 460$) or private plot pad safely banks loot into permanent Gold and Gems.

---

## 7. EQUIPPABLE ARTIFACT & BLACKSMITH SYSTEM

### 7.1 Inherent Rarity, Progressive Stars

An **artifact is a weapon**, with one equipped artifact UUID per hero. Its rarity is an immutable property assigned on acquisition. **Star Promotion is the only upgrade to an owned weapon.** There are no enhancement levels or enhancement-fodder multipliers in the stat model.

1. **Inherent rarity:** Sets base weapon power and a fixed attack-speed bonus. The stat reference uses **Mythical at hero level 50 / floor 50**. Rarity cannot be upgraded, rerolled, or refined on the same UUID.
2. **Progressive stars (1★ to 7★):** Multiply power by **1.00 / 1.60 / 2.50 / 4.00 / 6.50 / 10.00 / 16.00x**. Each promotion retains the recipient's rarity, template, and owner.
3. **New weapon acquisition:** A higher-rarity weapon is a new item, starting at 1★. Stars do not transfer between items. Compare resulting damage before equipping; a promoted lower-rarity weapon can outperform a fresh higher-rarity weapon.

`WeaponPower = InherentRarityPower * WeaponStarMultiplier`

`WeaponDamageMultiplier = 1 + WeaponPower/40`

At **Mythical 7★**, power is `7,000 * 16 = 112,000`, for a **2,801x trained-damage multiplier**. The fixed rarity bonus is **+30% attack speed** at every star rank. Weapons do not change health or movement speed. Hero stars, levels, and seed damage remain the other major power axis.

### 7.2 Inherent Weapon Stats by Rarity

| Tier | Inherent rarity | Base power (1★) | Attack-speed bonus | 7★ power | 7★ trained-damage multiplier |
| --- | --- | --- | --- | --- | --- |
| 1 | Common | 20 | 5.0% | 320 | 9x |
| 2 | Uncommon | 60 | 7.5% | 960 | 25x |
| 3 | Rare | 180 | 10.0% | 2,880 | 73x |
| 4 | Superior | 540 | 13.0% | 8,640 | 217x |
| 5 | Exalted | 1,400 | 16.5% | 22,400 | 561x |
| 6 | Legendary | 3,500 | 20.0% | 56,000 | 1,401x |
| 7 | Mythical | 7,000 | 30.0% | 112,000 | 2,801x |
| 8 | Transcendent | 10,000 | 35.0% | 160,000 | 4,001x |
| 9 | Ascendant | 14,000 | 40.0% | 224,000 | 5,601x |
| 10 | Ethereal | 20,000 | 45.0% | 320,000 | 8,001x |
| 11 | Immortal | 28,000 | 50.0% | 448,000 | 11,201x |
| 12 | Divine | 40,000 | 55.0% | 640,000 | 16,001x |
| 13 | Celestial | 56,000 | 60.0% | 896,000 | 22,401x |
| 14 | Primordial | 80,000 | 65.0% | 1,280,000 | 32,001x |
| 15 | Supreme | 112,000 | 70.0% | 1,792,000 | 44,801x |
| 16 | Origin | 160,000 | 75.0% | 2,560,000 | 64,001x |

These values apply to every compatible weapon type; templates select appearance/type rather than a special stat formula. Attack speed is fixed by inherent rarity, not multiplied by stars. A Common 7★ weapon has 320 power, while a Mythical 1★ has 7,000 power; a Legendary 7★ has 56,000 power and can outperform that newly acquired Mythical until it is promoted.

Higher rarities retain stat definitions in [the complete weapon matrix](docs/balance/STAT_SCALING_TABLES.md#weapon-power-by-inherent-rarity-and-promoted-stars). They are outside the required floor-50 reference build; this stat revision does not change how any rarity is obtained. The current hero level cap stays 50.

### 7.3 Weapon Star Promotion (1★ to 7★)

Promotion consumes other copies of the **same weapon template**, of any rarity or star rank, plus the listed Gold/Gems. The recipient's inherent rarity never changes. Reject locked, equipped, duplicate, or recipient-as-donor UUIDs. Consumed donors return no previous investment. No random success roll applies.

| Result stars | Power multiplier | Donors for this step | Gold | Gems |
| --- | --- | --- | --- | --- |
| 1 | 1.00x | — | — | — |
| 2 | 1.60x | 1 | 500 | 0 |
| 3 | 2.50x | 2 | 2,000 | 0 |
| 4 | 4.00x | 3 | 8,000 | 0 |
| 5 | 6.50x | 4 | 25,000 | 50 |
| 6 | 10.00x | 5 | 75,000 | 150 |
| 7 | 16.00x | 6 | 250,000 | 500 |

The full 1★ to 7★ path consumes 21 donor weapons plus the retained original. There is no additional enhancement-fodder sink. The multipliers now supply the full weapon progression that the removed enhancement track previously shared. Prices and acquisition pacing remain proposed tuning.

### 7.4 Artifact Summoning Banner (Gacha Mechanics)
- **Altar Integration:** The Summoning Altar features two banner tabs: **[HERO BANNER]** and **[ARTIFACT BANNER]**.
- **Summon Cost:** `100 Gems` per single pull, `900 Gems` for a 10x pull (1 free roll equivalent).
- **Banner Rarity Probability Table:**
  - **Common (Tier 1):** `55.0%`
  - **Uncommon (Tier 2):** `25.0%`
  - **Rare (Tier 3):** `12.0%`
  - **Superior (Tier 4):** `5.5%`
  - **Exalted (Tier 5):** `2.0%`
  - **Legendary (Tier 6):** `0.5%`
- **Pity Safeguards:**
  - **10-Pull Guarantee:** Every 10-pull guarantees at least one **Rare (Tier 3)** or higher artifact.
  - **50-Pull Hard Pity:** If no **Legendary (Tier 6)** or higher artifact has been pulled in 49 pulls, the 50th pull guarantees a **Legendary (Tier 6)** or higher artifact.
- **Acquiring Pinnacle Rarities (Tiers 7–16):**
  - **Biome Boss Pinnacle Drops:** Rare direct drops of Mythical to Origin artifacts from milestone floor clears.
  - **Blacksmith Rarity Refinement:** Forge masters can spend high quantities of Gold and Gems to refine an existing artifact's rarity tier upward.

### 7.5 Archetype Restrictions & 3D Socketing Standards
1. **Equippable Weapon & Item Catalog:**
   - **Swords (`SWORD`):** Permitted on `Vanguard`, `Striker`. High single-target slashing DPS.
   - **Daggers (`DAGGERS`):** Permitted on `Striker`. High-speed dual-wield flurry attacks.
   - **Bows (`BOW`):** Permitted on `Marksman`. Ranged single-target piercing attacks.
   - **Axes (`AXE`):** Permitted on `Vanguard`, `Miner`. Heavy cleaving strikes.
   - **Staves (`STAFF`):** Permitted on `Healer`, `Scholar`. Ranged mystic projectiles and aura empowerment.
   - **Tomes (`TOME`):** Permitted on `Healer`, `Scholar`. Channeled magical bursts and restorative resonance.
   - **Shields (`SHIELD`):** Permitted on `Vanguard`, `Striker`, `Miner`. Off-hand defensive posture and damage mitigation.
   - **Rings (`RING`):** Universal accessory equipable by any archetype for secondary stat amplification.
2. **Prefab Directory:** Centralized in `ReplicatedStorage.Assets.Weapons` (`weapon_bow`, `weapon_sword`, `weapon_daggers`, `weapon_axe`, `weapon_staff`, `weapon_tome`).
3. **Physical Constraints:** All weapon parts have `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `Massless = true`, `Anchored = false`, welded to an invisible PrimaryPart `Handle`.
4. **Dynamic Socketing:** Attached to `RightHand` via `ArtPackVisuals.AttachAt`. Bows feature dual dynamic `Beam` sinew strings connecting from stave tips to `RightHand.DrawAttachment`.

---

## 8. NETWORK PROTOCOL & REPLICATION ARCHITECTURE

### 8.1 Room-Local Replication v2 Protocol
To isolate simulation state and prevent entity overflow or vertical AoE bleed across the 50 Tower Floors:
- **Packet Structure:** 46-byte header + 24 bytes per entity record. Batches capped at 32 records (814 bytes total).
- **Context Identity:** `(ServerSessionId, FloorId, RoomGeneration, ViewEpoch)`.
  - Floor 0 represents the Central Hub and Fortress Plots.
  - Floors 1–50 represent dynamic isolated tower chambers (with Biome Boss arenas on Floors 5, 10, 15... 50).
- **Entity Record Layout:**
  - `EntityId` (u32), `EntityGeneration` (u32).
  - Local quantized `X, Y, Z` (3x i16, factor 10.0).
  - `Yaw` (u8), `PresentationState` (u8), `HP Permille` (u16, 0..1000), `Stamina` (u8, 0..100).
  - `Flags` (u8: bit 0 hero, bit 1 overdrive, bit 2 pacified, bit 3 boss core exposed).
  - `Current ActionSequence` (u32).

### 8.2 Reliable Travel & Squad Assignment Lifecycle
- **Transition Lane:** One serialized transition lane per player. State transitions (`VISIT`, `HUB`, `ASSIGN`, `RECALL`) are verified against character generation and monotonic location/squad revisions.
- **Idempotency & Replay Cache:** The server retains the last 64 terminal request results for 60 seconds per connection.
- **Budgeting:** Token bucket burst 4, refill 2 tokens/second per owner. 8-second preparation deadline before timeout rollback.
