# DOCUMENT 1: COMPLETE GAME DESIGN DOCUMENT (GDD)
**Project Title:** *Infinite Tower: Become a Master!*  
**Target Platform:** Roblox (PC, Mobile, Tablet, Console)  
**Server Capacity:** 6 Players per Server (6 Dedicated Floating Fortress Plots)  
**Engine Architecture:** Server-Authoritative Data Tables (5 Hz Heartbeat) + Client-Side R15 Visual Interpolation (60 FPS `RenderStepped`) | Hybrid Replication: Central Hub 14-Byte Binary Buffers + Infinite Tower Room-Local v2 Binary Buffers (24-byte entity records, 46-byte header)

---

## 1. EXECUTIVE OVERVIEW & PLAYER FANTASY

### 1.1 High-Concept Pitch
**Infinite Tower: Become a Master!** is a tactical squad-command Action-RPG, extraction sandbox, and fortress progression game inspired by the dark survival manhwa *Pick Me Up, Infinite Gacha*. Players do not play as generic hack-and-slash warriors; instead, each player embodies a **Master**—a dimensional overseer who summons, trains, equips, promotes, and commands a roster of sentient Gacha Heroes from a private floating sanctuary known as the **Master's Fortress Plot**.

### 1.2 The "Pick Me Up" Fantasy & Zero-Waste Roster Economy
In traditional gacha/simulator games, 95% of summons are discarded as worthless stat-sticks, and combat is reduced to passive AFK auto-clicking. **Infinite Tower** solves both problems through two foundational pillars:

1. **The Dual-Role Living Roster (Combat + Labor):**
   - Every hero pulled from the Summoning Altar rolls with **Combat Stats** (movement speed, attack speed, attack damage, health) and **Labor Output** (separate facility productivity), without trait or imprint bonuses.
   - **Up to 5 Deployed Heroes** (all 5 slots unlocked from the start) accompany the Master into the Central Hub or are independently deployed to specific floors (1–50) of the **Infinite Tower**. Heroes charge an in-combat **Skill/Stamina Gauge** (0 to 100) through a 3-tier attack cadence (Basic -> Basic -> Special -> Skill Attack at 100), and risk a debilitating **60-second Coma** if left inside lethal AoE telegraphs.
   - **Benched Heroes** physically inhabit the player's **Fortress Plot** on recuperation beds in **The Infirmary & Barracks** (Coma recovery & rest), or can be forged powerful equipment at the **Blacksmith Forge**.
   - **Zero Dead Pulls:** Duplicate heroes across all star ranks are fed into the **Synthesis Chamber** (`SynthesisController.luau`) for EXP leveling to cap (`MaxLevel = Stars * 10`), or sacrificed at the **Promotion Altar** (`PromotionController.luau`) for **Star Promotion** ($1★ \to 7★$).
   - **Dual Hero Banners & Artifact Ascension:** At the **Summoning Altar**, players spend Gems (`100 Gems` single / `900 Gems` 10x) on two distinct banners: **Call of the Rift** (Permanent Banner featuring 5 stars: $1★ \to 5★$) and **A Star's Arrival** (Limited Time Banner featuring 1 character per star across all 7 stars: $1★ \to 7★$). In addition, Masters spend Gems at the **Artifact Summoning Banner** (`160 Gems` single / `1,600 Gems` 10x) to pull equippable archetype weapons across **16 Rarity Tiers** (`Common` $\to$ `Origin`) which define inherent base stats. At the **Blacksmith Forge** (`ForgeController.luau`), duplicate gear and Gold are used for **Star Ascension** ($1★ \to 7★$), multiplying base stats with massive progressive multipliers up to **`8.00x`**.

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
        T1["Gather Gold & Gems from Drops, Relics & Tower Floors"] --> T2["Summoning Altar: Call of the Rift (5★ Perm) & A Star's Arrival (1-7★ Limited)"]
        T2 --> T3["Synthesis Chamber: Feed Duplicates for XP & Max Level Cap"]
        T2 --> T4["Artifact Banner: 16 Rarity Tiers (160 Gems)"]
        T3 --> T5["Promotion Altar: Sacrifice Same-Rank Heroes for Star Promotion (1★ -> 7★)"]
        T4 --> T6["Blacksmith Forge: Star Ascension (1★ -> 7★ Multipliers)"]
    end

    subgraph Macro["Macro Loop: Tower Progression & Biome Boss Conquests"]
        B1["Prepare Squad: Rest to 100% Stamina & Equip High-Rarity/Star Artifacts"] --> B2["Advance Tower Floors: Clear Mobs & Elites across 5-Floor Biome"]
        B2 --> B3["Engage Biome Boss on Floor Milestone (Floor 5, 10, 15... 50)"]
        B3 --> B4["Dodge Signature Telegraphed AoEs (Self/Target Discs) via [E] Recall"]
        B4 --> B5["Punish Window: Trigger [Q] Overdrive to Burst Down Boss HP"]
        B5 --> B6["Claim Milestone Rewards: Massive Gold/Gems & High-Rarity Artifact Drops"]
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
2. **Tactical Grind & Skill Gauge Building (0:15 – 2:00):**
   - The Master uses **`[Click / Tap]` Focus Target** to direct all 5 deployed heroes onto target mobs, crystal nodes, or floor bosses.
   - Heroes execute a 3-tier cadence: **Basic Attack** (+5 Stamina) $\to$ **Special Attack** (+10 Stamina every 3rd hit) $\to$ **Skill Attack** (unleashed when Stamina reaches 100, resetting gauge to 0).
   - To accelerate clears and rapidly charge Skill Attacks, the Master triggers **`[Q]` Overdrive Whistle** (`20s CD`), granting **+40% Attack Speed** for `5s` with zero stamina cost.
   - When an Elite or Boss telegraphs a red ground AoE or ranged projectile (`ARC`, `SELF_DISC`, `TARGET_DISC`, or swept-corridor `PROJECTILE`), the Master triggers **`[E]` Emergency Recall Whistle** (`6s CD`), warping all 5 heroes to the Master's safe position and dropping their aggro for `2s`.
3. **Physical Loot Haul (2:00 – 2:45):**
   - Defeating mobs/Elites spawns physical drops in `Workspace.PhysicalLoot` (**Bounty Bags**, **Mana Geodes**, **Cursed Urns**, and **Abyssal Cores**).
   - The Master touches the drop to weld it overhead, incurring a **-15% to -45% WalkSpeed penalty** (and disabling jumping for high-tier relics).
   - If hit by an Elite/Boss AoE mid-haul, the Master is **stunned for 1s and fumbles the item** (which becomes stealable after a **3s owner-lock**).
4. **Extract & Bank (2:45 – 3:00):**
   - **Hub Banking:** Stepping onto the Perimeter Highway (`R >= 460 studs`) or a Private Extraction Pad safely deposits cargo into permanent Gold and Gems.
   - **Floor Safe Sanctuary Banking:** Bringing physical loot (Gold/Gems) or Relics back into any floor's elevated **Floor Safe Sanctuary** automatically deposits them at the **Floor Extraction Pad** (`FloorExtractionPad`), granting 100% relic payout and Market multipliers immediately without requiring a trip back to the Hub.
   - Comatose heroes are swapped into **Infirmary Recuperation Beds**, and fresh rested heroes are rotated into the active squad via the `[AutoSwap]` toolbar action.

### 2.2 The 15-Minute Meso Loop (Fortress, Synthesis, Promotion & Forge Progression)
1. **Facility Upkeep (Every 3–5 Minutes):**
   - Inspect Infirmary beds and swap resting heroes into active squad rotation.
2. **Summoning & Gacha Pulls (Every 5–10 Minutes):**
   - Spend Gems at the **Summoning Altar** on either **Call of the Rift** (1★–5★ Permanent Banner), **A Star's Arrival** (1★–7★ Limited Time Rate-Up Banner, featuring 1 character per star), or the **Artifact Banner** (`160 Gems` single / `1,600 Gems` 10x for archetype weapons across 16 Rarity Tiers).
   - **Synthesis Chamber (`SynthesisController.luau`):** Place a recipient hero and up to 5 fodder heroes to level up to the hero's current cap ($\text{MaxLevel} = \text{Stars} \times 10$).
   - **Promotion Altar (`PromotionController.luau`):** When a hero reaches max level, sacrifice same-rank heroes and Promotion Stones to permanently ascend star rating ($1★ \to 7★$).
3. **Artifact Star Ascension at the Blacksmith Forge (`ForgeController.luau`):**
   - **Star Ascension (Multipliers):** Ascend artifacts from $1★ \to 7★$ at the Forge by sacrificing duplicate artifacts and Gold, scaling inherent base stats by progressive multipliers up to **`8.00x`**.

### 2.3 The Macro Loop (Tower Progression & Biome Boss Conquests)
1. **Biome Traversal & Preparation:**
   - Masters organize their 5-hero squad, equip high-rarity and high-star artifacts, and ensure full stamina in the Infirmary before entering a new Biome.
   - Each of the 10 biomes spans 5 progressively harder floors (50 floors total) with 4 unique biome enemy species (2 Regulars, 1 Elite, and 1 Biome Boss; 40 total enemy species across the Tower). Floor 1 and the 3rd–4th floors of every biome include Elite encounters alongside Regulars. Enemy health and attack damage follow the stat-reference curve in Section 4.2. Reward scaling remains $\text{Reward} \times 1.055^{\text{Floor}-1}$; stat inflation does not change rewards.
2. **The Biome Boss Encounter (Floors 5, 10, 15, ..., 50):**
   - The 5th floor of every biome is a dedicated **Biome Boss Arena** (`BOSS_ARENA` layout variant) featuring an 8-column ritual ring, boss braziers, and a massive boss dais fixture (`BossDaisFixture`, $60 \times 2 \times 60\text{ studs}$).
   - Every Biome Boss transitions dynamically from **Phase 1** to **Phase 2 (Enraged)** below 55% HP and wields devastating signature attacks with distinct authoritative shapes and timings:
     - **Basic Attacks:** Wide frontal arcs (`ARC`, e.g. `guardian_crush`, 13 studs).
     - **Signature 1:** Expanding circular ground shocks centered on the boss (`SELF_DISC`, e.g. `moss_quake`, 22 studs radius).
     - **Signature 2:** Ranged ground craters placed under distant heroes (`TARGET_DISC`, e.g. `sweeping_roots`, 55 studs cast range, 13 studs radius).
     - **Ranged / Caster Regulars:** Biome ranged and caster regulars (`mob_lantern_spore`, `mob_crag_channeler`, `mob_thorn_weaver`, `mob_drowned_acolyte`, `mob_astral_scribe`, `mob_void_invoker`) fire authoritative swept-corridor projectiles (`PROJECTILE`) with a floor corridor warning and flying orb visual.
   - **Tactical Counterplay ("Dodge vs. Coma"):** Masters must watch the expanding progress-fill telegraph discs, corridor warnings, and sound cues, repositioning and executing **`[E]` Emergency Recall Whistle** to yank heroes out of danger. Heroes struck by signature skills suffer severe stamina loss or a debilitating **60-second Coma**.
   - **Punish Windows:** Following major signature attacks, the boss enters an extended recovery window (1.2s–1.5s), providing active Masters the ideal moment to pop **`[Q]` Overdrive Whistle** for massive burst DPS.
3. **Biome Clearance & Milestone Rewards:**
   - Defeating the Biome Boss awards immense Gold, Gems, and rare direct drops of high-rarity **Artifacts** (from Legendary up to Origin).
   - All 50 floors are accessible via the **Floor Selector** (`TowerController.client.luau`), with no boss-kill lock gating travel.

### 2.4 The AFK & Outskirts Facility Loop (Passive Boost Facilities & Auto/Offline Gold Generation)
While active squad command in the Central Hub and Infinite Tower drives peak progression, the **Outskirts & Facility Loop** ensures that a Master's benched roster continuously generates value both online and offline—reinforcing the **Zero-Waste Roster Economy**.

1. **Inner Fortress Stations vs. The Rear Outskirts:**
   - **Core Main Buildings (Inner Courtyard):** Essential progression stations that every Master accesses by default in their main fortress courtyard—including the **Summoning Altar**, **War Banner**, **Synthesis Chamber**, **Promotion Altar**, **Blacksmith Forge**, and **The Infirmary & Barracks** (which operates strictly as a Main Building for Stamina & Coma recovery).
   - **Support Facilities (Inner Fortress Wings):** Upgradeable utility and economic structures (`Level 1` $\to$ `Level 5`) located inside the fortress courtyard wings where benched heroes are stationed via `FacilityController.luau` to grant global percentage buffs:
     - **The Market (Inner Commercial Wing):** Grants a percentage multiplier ($+5\%$ base at Lv. 1 up to $+40\%+$ with high-tier Miners) **strictly to Loot Earnings from the Towers**—amplifying Gold dropped by Infinite Tower mobs/Biome Bosses (Floors $1\text{–}50$) and the banking value of physical loot extracted from the Central Crimson Tower rings. (Does not multiply Outskirts Guard Post passive Gold).
     - **The Training Grounds (Inner Martial Wing):** Grants a percentage multiplier ($+4\%$ base at Lv. 1 up to $+32\%+$ with high-tier Strikers/Scholars) to the Master's **Overall Squad Combat Power**, multiplying total `FinalATK` and `FinalHP` (both intrinsic hero stats and equipped Artifact stats) against all monsters.
   - **The Outskirts (Southern Frontier Wilderness):** The only area located *outside* the fortress walls, reached through the rear fortress gatehouse. Houses the **Outskirts Guard Post** and wilderness patrol run.
2. **The Outskirts Guard Post (Unified AFK Gold & Offline Rewards):**
   - At the southern rear border of the island, outside the fortress battlements, lies the **Outskirts Guard Post**, a frontier bastion and wilderness trail at the back of the fortress.
   - Masters assign benched heroes (`Vanguard` and `Marksman` preferred) to the Outskirts Guard Post as **Adventurers**. Assigned Adventurers physically venture out and patrol the southern outskirts trail, fending off ambient monsters in a lightweight client-rendered visual loop without draining their combat Stamina.
   - **Auto-Received Online Gold:** There is no manual treasury chest required while online. Every $60\text{ seconds}$ (ticked automatically in $10\text{-second}$ increments), passive Gold generated by stationed Adventurers is **automatically added directly to the Master's Gold balance**, scaled by the heroes' `EffectiveLabor` and the Master's **Highest Cleared Biome Boss** (Floors $5, 10, \dots, 50$).
   - **Offline Reward Function (`OfflineRewardService.luau`):** When a Master logs out (`PlayerRemoving`), the server records `LastLogoutTimestamp` alongside their current `PassiveGoldPerMin` rate. Upon reconnecting (`PlayerAdded`), the server calculates elapsed offline minutes up to the Guard Post's **Max Offline Accumulation Cap** ($4\text{ Hours}$ at Lv. 1 $\to$ $12\text{ Hours}$ at Lv. 5) and presents a **"Welcome Back, Master!" Offline Summary Modal**, crediting the accumulated Gold straight to the player's balance.

---

## 3. MAP & SPATIAL DESIGN SPECIFICATIONS

### 3.1 Dual-Mode Spatial Architecture

The world exists in two coordinated spatial contexts:
1. **The Central Hub & Floating Fortress Ring (World Coordinates):** Landmark Central Crimson Tower, perimeter bridges, and player fortress plots.
2. **The 50 Dynamic Isolated Tower Floors (Off-Map Isolated Grid):** Server-managed dynamic encounter rooms for vertical climbing and Biome Boss arenas.

```
                      CENTRAL HUB ARENA & FLOATING FORTRESS RING
                                    [N: (0, -750)]
                                  +----------------+
                                  |  PLOT 1 (0°)   |
                                  +-------+--------+
                                          | (Bridge)
                   PLOT 6 (300°)          |           PLOT 2 (60°)
                        \                 |                 /
                  (Bridge)\        +------+------+        /(Bridge)
                            \      |   CENTRAL   |       /
                             ------+   CRIMSON   +-------
                            /      |  TOWER HUB  |       \
                  (Bridge)/        +------+------+        \(Bridge)
                        /                 |                 \
                   PLOT 5 (240°)          |           PLOT 3 (120°)
                                          | (Bridge)
                                  +-------+--------+
                                  |  PLOT 4 (180°) |
                                  +----------------+
                                    [S: (0, +750)]

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
| **6 Floating Fortress Plots** | `R = 650 studs` ($Y = 12$) | Expanded $260 \times 320\text{ studs}$ citadel island with grand courtyard & rear outskirts ($1.2\times$ radius expansion) | Plot Owner + Visitors | Safe Zone. Personal fortress sanctuary for recovery, banner summoning, forge ascension, and AFK outskirts guard post. | Roster Recovery, Gacha Banners, Forge, Outskirts Passive Gold & Multipliers |
| **Safety Catch Plane** | Lower kill plane at $Y = -95$ | `2400 x 8 x 2400 studs` | Fallen players | Non-lethal catch plane; teleports fallen players safely to their PlotSpawn. | None |
| **50 Tower Floor Rooms** | Off-map grid: $X \ge 12,000, Y = 1,000, Z \ge 12,000$ (spaced $2,400\text{ studs}$) | Progressive $380 \times 130 \times 420\text{ studs}$ (F1) to $560 \times 190 \times 640\text{ studs}$ (F5) across 5 elevation tiers | Traversal via `TowerController` | Isolated floor-local PvE encounters; shared floor membership; elevated safe arrival sanctuary with instant loot unpackaging/banking. | Mob drops, Gold, Gems, **Biome Boss Rare Artifact Drops** |

### 3.3 Dynamic Tower Room Architecture & Biomes

Tower floors are dynamically managed by `TowerFloorService.luau` and generated via `TowerRoomBuilder.luau` in conjunction with `TowerLayout.luau` and `TowerBiomeAssets.luau`:
- **Room Origin Spacing Formula:**
  $$\text{Origin}(id) = \Big(12000 + ((id - 1) \bmod 10) \times 2400,\; 1000,\; 12000 + \lfloor(id - 1) / 10\rfloor \times 2400\Big)$$
  Spaced at $2,400\text{ studs}$ along both axes so enlarged, multi-tiered rooms remain completely isolated from adjacent cameras, raycasts, and simulation heartbeats.
- **Progressive 5-Floor Scale & Variant Progression:**
  Each biome spans 5 floors (`IndexInBiome = 1..5`). Rather than a static flat box, each room scales progressively across 5 layout variants guided by reference concepts:

| Floor in Biome | Variant Kind | Footprint ($W \times D \times H$) | Elevation Tiers | Architectural Theme | Mob Groups (Camps) | Total Mobs |
| :---: | :--- | :---: | :---: | :--- | :---: | :---: |
| **Floor 1** | `INTRODUCTION` | $380 \times 420 \times 130\text{ studs}$ | 3 Tiers ($Y: 0\text{ to }+12$) | Foreground courtyard, threshold entry arches, flora/crystals/dunes, north shrine. | 3 Camps | 10–12 Mobs (Includes 1 Elite on F1) |
| **Floor 2** | `EXPANDED_ENCOUNTER` | $420 \times 470 \times 140\text{ studs}$ | 3 Tiers ($Y: 0\text{ to }+14$) | Flanking elevated colonnades and side galleries connected by side ramps. | 4 Camps | 14–16 Mobs |
| **Floor 3** | `TERRAIN_VARIATION` | $460 \times 520 \times 155\text{ studs}$ | 4 Tiers ($Y: -4\text{ to }+18$) | Recessed elemental chasm (water/lava/mist) with arched bridge crossings and waterfalls. | 5 Camps | 18–20 Mobs (Includes 1 Elite pack) |
| **Floor 4** | `ELITE_STRONGHOLD` | $510 \times 580 \times 170\text{ studs}$ | 4 Tiers ($Y: -4\text{ to }+22$) | Monumental flanking guardians, watchtowers, and twin upper elite bastions. | 6 Camps | 22–25 Mobs (Includes 2 Elite packs) |
| **Floor 5** | `BOSS_ARENA` | $560 \times 640 \times 190\text{ studs}$ | 5 Tiers ($Y: -6\text{ to }+28$) | Full biome masterpiece: Apex Boss Dais, overhead centerpiece, and cascades. | 7 Camps | 25–29 Mobs (Boss + 2 Elite lieutenants) |

- **Multi-Tiered Spatial Topography (`TowerLayout.luau`):**
  Each room features 5 navigable elevation zones:
  1. **Elevated Safe Overlook ($Y = +8$):** South landing sanctuary housing arrival and extraction fixtures.
  2. **Foreground Basin ($Y = 0\text{ to }+2$):** Open entry courtyard and elemental basin connected by ceremonial ramps.
  3. **Flanking Galleries & Central Crossing ($Y = +4\text{ to }+12$):** Elevated West/East terraces and split bridges over recessed elemental channels.
  4. **Upper Bastions ($Y = +10\text{ to }+16$):** Fortified wings and guardian platforms.
  5. **Apex Sanctum / Boss Dais ($Y = +16\text{ to }+28$):** Grand tiered staircase ascending to the biome apex or Boss arena.
  *All slopes are restricted to $\le 15^\circ$ and stair rises to $\le 1.0\text{ stud}$ per tread, guaranteeing smooth grounded navigation for heroes (`HeroNavigation.luau`) and enemies without getting stuck.*
- **Floor Safe Sanctuary & In-Floor Loot Unpackaging (`CanBankCargo = true`):**
  The elevated south arrival sanctuary ($88 \times 56\text{ studs}$ at $Y = +8$) is designated with `CombatSafe = true`, `CanBankCargo = true`, and `CanRecoverWipe = true`:
  - **`FloorExtractionPad`:** Interactive unpackaging pad and altar. Entering the sanctuary while carrying physical Gold/Gems or Relics (`BankArmed = true`) immediately unpacks and banks them into permanent profile currency with 100% relic value and the active Market multiplier (`EXTRACT_SAFE_ZONE`).
  - **Travel Pedestals:** 4 ProximityPrompt pedestals (`PREVIOUS`, `NEXT`, `SELECTOR`, `HUB`) along the rear colonnade.
- **Procedural Landmark Kits (`TowerBiomeAssets.luau`):**
  Native-part procedural landmark kits for all 10 biomes (statues, bridges, falls, crystals, flora, overhead cogs, celestial orreries, chained obelisks) with local lights and zero external asset dependencies.
- **Multi-Area Spatial Mob Camps & AI Leashing (`FirstBiomeCombat.luau`, `TowerEncounterRuntime.luau`):**
  Enemies spawn in 3 to 7 distinct spatial camps per floor (10–29 mobs) with ground-raycasted elevations and localized leash radiuses ($60\text{ studs}$ for regular/elite packs, $95\text{ studs}$ for Boss encounters), allowing tactical, room-by-room progression without premature floor aggro pulls.
- **Room Lifecycle:** Rooms transition through `ABSENT -> BUILDING -> READY -> RETIRING -> ABSENT` with a 60-second retirement grace period when unoccupied.

#### Biome Catalog (50 Floors across 10 Biomes):
1. **Verdant Ruins (Floors 1–5):** Overgrown Threshold, Broken Aqueduct, Rootway Crossing, Vinebound Bastion, **Mossbound Court (Biome Boss: Mossbound Guardian)**.
2. **Fungal Hollow (Floors 6–10):** Sporelit Entry, Mycelium Galleries, Blooming Chasm, Rotcap Keep, **Matriarch's Hollow (Biome Boss: Spore Matriarch)**.
3. **Ashen Dunes (Floors 11–15):** Cinder Gate, Buried Caravan, Glasswind Ravine, Sunscar Fortress, **Colossus Dais (Biome Boss: Sandstone Colossus)**.
4. **Frozen Citadel (Floors 16–20):** Rimefall Approach, Frozen Barracks, Shattered Iceway, Whiteguard Keep, **Frostbound Throne (Biome Boss: Frostbound King)**.
5. **Infernal Foundry (Floors 21–25):** Slagworks Entry, Molten Assembly, Furnace Causeway, Ironflame Bulwark, **Titan's Crucible (Biome Boss: Ember Titan)**.
6. **Thunder Highlands (Floors 26–30):** Stormgrass Rise, Thunderhead Outpost, Skybridge Cliffs, Tempest Redoubt, **Roc's Eyrie (Biome Boss: Storm Roc)**.
7. **Corrupted Grove (Floors 31–35):** Blighted Verge, Twisted Orchard, Briar Labyrinth, Heartrot Stronghold, **Sovereign's Grove (Biome Boss: Blight Sovereign)**.
8. **Sunken Sanctuary (Floors 36–40):** Drowned Steps, Coral Cloister, Tidal Channels, Pearlguard Vault, **Leviathan's Basin (Biome Boss: Tidal Leviathan)**.
9. **Astral Archives (Floors 41–45):** Starlit Vestibule, Orbiting Stacks, Fractured Index, Runeguard Athenaeum, **Rift Warden's Observatory (Biome Boss: Rift Warden)**.
10. **Abyssal Throne (Floors 46–50):** Abyssal Descent, Crimson Procession, Voidspan Crossing, Dreadguard Citadel, **Overlord's Throne (Biome Boss: Crimson Overlord)**.


### 3.4 Private Fortress Plot & Outskirts Architectural Layout

To accommodate active fortress management, squad training, commerce, and the passive Outskirts AFK loop, each of the 6 Floating Fortress Islands is expanded by **$1.2\times$** radial distance out to **$R = 650\text{ studs}$** (top surface $Y = 12$) with an enlarged citadel island footprint of **$260\text{ studs (Width)} \times 320\text{ studs (Length)}$**.

The island is divided into two distinct, interconnected sectors:
1. **The Grand Citadel & Inner Courtyard (Front / North - $260 \times 180\text{ studs}$):** Heavily fortified with $28\text{-stud}$ high crenellated stone walls, corner watch bastions, and a private entrance gatehouse facing the perimeter drawbridge. Encloses all **Core Main Buildings** (Summoning Altar, War Banner, The Pit, Blacksmith Forge, Infirmary) as well as the internal support facilities (**The Market** and **The Training Grounds**).
2. **The Southern Outskirts (Rear / South - $260 \times 140\text{ studs}$):** The sole exterior zone outside the fortress walls, accessed through the vaulted rear fortress gatehouse. Spans open, rugged frontier terrain, pine trees, and dirt wilderness trails housing **The Outskirts Guard Post**.

```
                        NORTH (Facing Central Hub & Perimeter Highway)
                                        | (Bridge)
                                  [North Gatehouse]
                       +---------------------------------------+
                       |   Plaza & Cyan Private Extraction Pad  |
                       |                                       |
                       | [Infirmary & Beds]   [Summoning Altar]|
                       |                      (Hero & Artifact)|
                       |   [Plaza Fountain]                    |
                       | [War Banner Standard]                 |
                       |                                       |
                       | [The Pit / Cauldron] [Blacksmith Forge|
                       | (Synthesis & Promo)   & Anvil Hearth] |
                       |                                       |
                       | [Training Grounds]       [The Market] |
                       | (Sparring & Dummies)  (Bazaar Stalls) |
                       +-------------------+-------------------+
                                           | (Rear Fortress Gate)
                       ====================+====================
                       |         THE REAR OUTSKIRTS GROUNDS     |
                       |                                       |
                       |          [Wilderness Border Trail]    |
                       |                                       |
                       |          [Outskirts Guard Post]       |
                       |       (Timber Bastion & Patrol Run)   |
                       |                                       |
                       +---------------------------------------+
                                SOUTH (Southern Frontier)
```

#### Detailed Sector Breakdown:

1. **Sector A: Arrival Ramp, Gatehouse & Extraction Plaza (North Front):**
   - **Perimeter Drawbridge & Gate:** Connects the fortress to the Perimeter Highway ($R = 480 \to 520\text{ studs}$). Features an owner-locked collision barrier preventing unauthorized plot infiltration.
   - **Plaza & Extraction Pad:** Glowing cyan illuminated deposit zone ($24 \times 1 \times 24\text{ studs}$) for banking carried relics, geodes, and urns into permanent Gold and Gems.
   - **Beacon Pillar & Plot Spawn:** Center anchor with the Master's avatar beacon projected skyward.

2. **Sector B: Grand Inner Fortress Courtyard (Core Buildings & Interior Facilities):**
   - **Summoning Altar (East Courtyard):** Towering obsidian obelisk featuring dual runic summoning circles for the **Hero Banner** (`100 Gems` single / `900 Gems` 10x) and **Artifact Banner** (`160 Gems` single / `1,600 Gems` 10x).
   - **Plaza Fountain & War Banner (Center Courtyard):** Central triple-tiered Gothic stone fountain in the courtyard center with water basins and blue glow, flanked to the left by the heraldic War Banner standard on a carved stone pedestal with `[F]` proximity prompt opening the **Squad Deploy UI** (`SquadController.luau`).
   - **The Pit Sanctuary (West Courtyard):**
     - **Synthesis Chamber:** Fiery cauldron station with `[F]` prompt opening the **Synthesis UI** (`SynthesisController.luau`) for feeding EXP fodder.
     - **Promotion Altar:** Consecrated marble star dais with `[F]` prompt opening the **Promotion UI** (`PromotionController.luau`) for star ascensions ($1★ \to 5★$).
   - **The Blacksmith Forge (South-East Courtyard):** Interactive 3D station featuring an anvil, hearth coals, workbench, and prompt opening the **Forge UI** (`ForgeController.luau`) for Artifact Star Ascension ($1★ \to 7★$).
   - **The Infirmary & Barracks (North-West Courtyard):** Dedicated Gothic stone hall containing 5 permanent recuperation beds where wounded and `Coma`-afflicted heroes rest. Resting Healer heroes project an aura accelerating stamina regeneration.
   - **The Market (South-East Inner Wing):** Covered bazaar stalls, coin scales, and ledger counters located inside the fortress commercial quarter. Stationed workers (`Miner` preferred) boost Infinite Tower mob/boss loot drops and Hub extraction banking values ($+5\%$ to $+40\%+$).
   - **The Training Grounds (South-West Inner Wing):** Cobblestone sparring arena with weapon racks, archery targets, and training dummies located inside the fortress military quarter. Stationed trainers (`Striker` & `Scholar` preferred) boost the Master's overall squad combat power ($+4\%$ to $+32\%+$ Final ATK/HP).

3. **Sector C: The Southern Outskirts (Exterior Wilderness Zone):**
   - **Rear Fortress Archway:** A $24\text{-stud}$ wide vaulted stone passage connecting the inner fortress courtyard directly to the open wilderness behind the citadel.
   - **The Outskirts Guard Post (South Perimeter):** Heavy timber bastion, log palisade barricade, and campfire situated along the winding wilderness trail amidst lush rolling meadow grass, asymmetrical ancient pines, broadleaf oaks, wild berry shrubs, and mossy granite boulders. Stationed Adventurers (`Vanguard` & `Marksman` preferred) venture out along the curved patrol trail to battle ambient wildlife in a lightweight visual loop, auto-generating online Gold every 60 seconds and logging offline accumulation. Only the Outskirts and its Guard Post lie outside the fortress walls.

---

## 4. HERO, COMBAT & UI MECHANICS

### 4.1 Gacha Banners & Hero Roster Architecture

Hero summoning at the **Summoning Altar** (`FacilityController.luau`) is partitioned into two distinct banners:

#### 1. Permanent Banner: "Call of the Rift" (5 Stars: 1★ to 5★)
The permanent standard banner features exactly **one character for each star rating from 1★ to 5★** (5 total heroes):
- **Summon Cost:** `100 Gems` per single pull (`900 Gems` for 10x pull).
- **Pity System:** Guaranteed 5★ hero within **50 summons** (`MaxPity = 50`). Natural 5★ pull resets pity counter.
- **Drop Rates:**
  - `1★ Common (60.0%)`: **Han**
  - `2★ Rare (25.0%)`: **Aaron**
  - `3★ Epic (10.0%)`: **Catio**
  - `4★ Legendary (4.0%)`: **Valeria**
  - `5★ Mythic (1.0%)`: **Ignis**

#### 2. Limited Time Banner: "A Star's Arrival" (7 Stars: 1★ to 7★)
The inaugural limited-time rate-up banner features exactly **one character for each star rating from 1★ to 7★** (7 total heroes):
- **Summon Cost:** `100 Gems` per single pull (`900 Gems` for 10x pull).
- **Pity System:** Guaranteed 7★ featured hero (**Astrea**) within **50 summons** (`MaxPity = 50`). Natural 7★ pull resets pity counter.
- **Drop Rates:**
  - `1★ Common (50.0%)`: **Jenna**
  - `2★ Rare (25.0%)`: **Velkist**
  - `3★ Epic (13.5%)`: **Eolka**
  - `4★ Legendary (6.5%)`: **Morrigan**
  - `5★ Mythic (3.5%)`: **Sovereign Archon**
  - `6★ Transcendent (1.2%)`: **Solaris**
  - `7★ Primordial (0.3%)`: **Astrea (Featured 7★ Starlight Primordial)**

---

#### Launch Roster Base & Native Stats
Every summoned hero rolls a `QualityScalar` $q \in [0.90, 1.15]$ applied to their archetype base stats. Native stats scale with Base Star $S$ according to $Stat_0 \times 1.65^{(S - 1)}$ for combat and $L_0 \times 1.35^{(S - 1)}$ for labor:

| Banner | Hero | Star | Archetype | Base HP / ATK | Native HP / ATK | Base / Native Labor | Passive Trait |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- | :--- |
| **Call of the Rift** | **Han** | **1★** | Striker | `300` / `40` | `300` / `40` | `14` / `14.0` | **Unyielding Adaptation** (+10% ATK, -10% Stamina Drain) |
| **Call of the Rift** | **Aaron** | **2★** | Vanguard | `450` / `28` | `743` / `46` | `16` / `21.6` | **Phalanx Guard** (+25% Max HP, -15% AoE Taken) |
| **Call of the Rift** | **Catio** | **3★** | Miner | `280` / `24` | `762` / `65` | `20` / `36.5` | **Quartermaster's Ledger** (+25% Labor Output) |
| **Call of the Rift** | **Valeria** | **4★** | Healer | `260` / `18` | `1,168` / `81` | `18` / `44.3` | **Sanctuary Aegis** (+30% Healing, +20% Coma Recovery) |
| **Call of the Rift** | **Ignis** | **5★** | Vanguard | `450` / `26` | `3,335` / `193` | `16` / `53.1` | **Rift Warlord** (+35% ATK, +20% DMG Reduction) |
| **A Star's Arrival** | **Jenna** | **1★** | Marksman | `210` / `34` | `210` / `34` | `13` / `13.0` | **Windstep Precision** (+15% ASPD, +5% Move Spd) |
| **A Star's Arrival** | **Velkist** | **2★** | Striker | `300` / `44` | `495` / `73` | `14` / `18.9` | **Bloodthirst Frenzy** (+20% ATK, +1s Overdrive) |
| **A Star's Arrival** | **Eolka** | **3★** | Scholar | `230` / `52` | `626` / `142` | `22` / `40.1` | **Crimson Pyromancy** (+25% ATK, +30% Labor Output) |
| **A Star's Arrival** | **Morrigan**| **4★** | Vanguard | `450` / `24` | `2,021` / `108` | `16` / `39.4` | **Abyssal Bulwark** (+30% Max HP, +15% Reflect DMG) |
| **A Star's Arrival** | **Archon** | **5★** | Striker | `350` / `65` | `2,594` / `482` | `25` / `83.0` | **Dimensional Dominion** (+30% Boss DMG, +25% All Labor) |
| **A Star's Arrival** | **Solaris** | **6★** | Scholar | `240` / `55` | `2,935` / `673` | `22` / `98.6` | **Supernova Flare** (+40% ATK, +25% AoE Radius) |
| **A Star's Arrival** | **Astrea** | **7★** | Marksman | `230` / `48` | `4,641` / `969` | `23` / `139.2` | **Cosmic Zenith** (+50% ATK, +30% ASPD, +35% Boss DMG) |

#### Archetype Foundation Table

Archetypes define a hero's **combat role, base stats, attack cadence, range, labor, and permitted weapons**. Attack moves are **not** shared per archetype: every hero carries a bespoke 3-tier kit (see Section 4.4, *Hero Combat Skill Ledger*).

| Archetype | Combat Role | Base HP ($HP_0$) | Base ATK ($ATK_0$) | Attack Interval ($t_{\text{atk}}$) | Attack Range | Base Labor ($L_0$) | Permitted Weapons |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Vanguard** | Frontline Tank & Damage Absorber | `450` | `22` | `1.20s` | `6 studs` | `10 / min` | `SWORD_SHIELD` |
| **Striker** | Agile Melee Critical DPS | `280` | `38` | `0.85s` | `6 studs` | `12 / min` | `DAGGERS` |
| **Marksman** | Long-Range Physical DPS & Armor Shredder | `210` | `34` | `0.80s` | `28 studs` | `13 / min` | `BOW` |
| **Miner** | Heavy Blunt Disruptor & Gem Specialist | `300` | `20` | `1.05s` | `6 studs` | `20 / min` | `AXE` |
| **Healer** | Squad Sustain & Infirmary Specialist | `260` | `18` | `1.25s` | `24 studs` | `18 / min` | `TOME` |
| **Scholar** | Elemental Catalyst & Burst Magic | `220` | `24` | `1.00s` | `26 studs` | `22 / min` | `STAFF` |

*(Note: Each archetype equips exactly one weapon type, and each hero holds one artifact. Sword & Shield is a single combined weapon; rings are removed. See Section 7.5.)*

### 4.2 Effective Combat & Labor Formulas
- **Level Cap Formula:**
  $$\text{MaxLevel}(S) = S \times 10 \quad (1★ = \text{Lv.10},\; 2★ = \text{Lv.20},\; 3★ = \text{Lv.30},\; 4★ = \text{Lv.40},\; 5★ = \text{Lv.50},\; 6★ = \text{Lv.60},\; 7★ = \text{Lv.70})$$
- **Star Promotion Multipliers:** Promoting a hero from $S \to S+1$ resets Level to `1`, increases cap by `+10`, multiplies Base Combat stats by **`1.65x`**, and multiplies Base Labor output by **`1.35x`**.
- **Effective Combat Stats (with Artifact Integration):**
  $$\text{EffectiveATK} = \text{round}\Big(ATK_0 \times q \times 1.65^{(S - 1)} \times \big(1 + 0.08(L - 1)\big) \times (1 + B_{\text{TraitATK}} + B_{\text{ImprintATK}})\Big) + TotalATKBonus_{\text{Artifact}}$$
  $$\text{EffectiveHP} = \text{round}\Big(HP_0 \times q \times 1.65^{(S - 1)} \times \big(1 + 0.08(L - 1)\big) \times (1 + B_{\text{TraitHP}} + B_{\text{ImprintHP}})\Big)$$
  $$\text{EffectiveInterval} = \max\left(0.12\text{s}, \frac{HeroBaseInterval}{1 + TotalSpeedBonus_{\text{Artifact}}}\right)$$
  $$\text{TotalATKBonus}_{\text{Artifact}} = \text{round}\Big(ATK_{\text{Base, Rarity}} \times \text{Multiplier}_{\text{Star}}\Big)$$
  $$\text{TotalSpeedBonus}_{\text{Artifact}} = ASPD_{\text{Base, Rarity}} \times \text{Multiplier}_{\text{Star}}$$
  *(Where Rarity dictates inherent base stats and Stars ($1★ \to 7★$) dictate the progressive multiplier).*
- **Effective Labor Formula:**
  $$\text{EffectiveLabor} = L_0 \times q \times 1.35^{(S - 1)} \times \big(1 + 0.05(L - 1)\big) \times (1 + B_{\text{Synergy}}) \times (1 + B_{\text{TraitLabor}} + B_{\text{ImprintLabor}})$$
  *(Where $B_{\text{Synergy}} = 0.25$ when assigned to preferred facility).*

### 4.3 Fortress Outskirts & Facility Economy Formulas

Progression is bifurcated between **Core Main Buildings** (free, static fortress stations) and **Upgradeable Outskirts Facilities** (`Level 1` $\to$ `Level 5`) that scale passive Gold generation and global percentage multipliers:

#### 1. Core Main Building: The Infirmary & Barracks
The Infirmary operates as a standard, permanent fortress fixture with 5 default recuperation beds:
- **Base Stamina Recovery:** $3.0\text{ Stamina/sec}$ per occupied bed.
- **Healer Synergy Aura:** $+50\%$ acceleration ($4.5\text{ Stamina/sec}$) if at least one `Healer` hero is resting in the Infirmary.
- **Coma Duration:** Standard $60\text{ seconds}$ recovery, reduced to $40\text{ seconds}$ when a resting `Healer` is present.

#### 2. Upgradeable Support Facilities (Levels 1 to 5)

##### Facility A: The Outskirts Guard Post (Exterior AFK & Offline Gold Generation)
Located outside the fortress walls along the southern wilderness border. Stationed Adventurers (`Vanguard` & `Marksman` preferred, receiving $+25\%$ labor synergy) patrol the trail, generating automatic online Gold and accumulating offline rewards:

| Level | Gold Upgrade Cost | Max Adventurers | Base Gold / Min ($\text{BaseRate}$) | Max Offline Cap | Offline Efficiency | Visual Identity |
| :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Lv. 1** | Free (Unlocked) | 1 Worker | `30 Gold/min` | 4 Hours (240 min) | 75% | Rugged wooden lean-to, simple campfire, dirt path. |
| **Lv. 2** | 1,500 Gold | 2 Workers | `75 Gold/min` | 6 Hours (360 min) | 80% | Timber guard shack, log palisade fence, weapon rack. |
| **Lv. 3** | 6,000 Gold | 3 Workers | `160 Gold/min` | 8 Hours (480 min) | 85% | Stone-reinforced bastion, brazier, perimeter ditch. |
| **Lv. 4** | 20,000 Gold | 4 Workers | `300 Gold/min` | 10 Hours (600 min) | 90% | Fortified outpost tower, crenellated wall, watch bell. |
| **Lv. 5** | 60,000 Gold | 5 Workers | `550 Gold/min` | 12 Hours (720 min) | 100% | Castle frontier barbican, heavy iron gate, signal beacon. |

- **Online Passive Gold Formula:**
  $$\text{PassiveGoldPerMin} = \Big(\text{BaseRate}_{\text{Level}} + 0.85 \times \sum \text{EffectiveLabor}\Big) \times \Big(1 + 0.15 \times \text{BiomeBossTier}\Big)$$
  *(Where $\text{BiomeBossTier} \in [0, 10]$ is the highest Biome Boss defeated: Floor 5 = 1, Floor 10 = 2, ..., Floor 50 = 10).*  
  *Auto-credited directly to the Master's Gold balance every 60s in 10s sub-increments; no manual claim chest required.*
- **Offline Gold Accumulation Formula (`OfflineRewardService.luau`):**
  $$\text{OfflineGold} = \min\big(\text{ElapsedMinutes},\; \text{MaxOfflineCapMinutes}\big) \times \text{PassiveGoldPerMin} \times \text{OfflineEfficiency}_{\text{Level}}$$
  *Presented via "Welcome Back, Master!" modal upon login, depositing accumulated Gold straight to profile currency.*

##### Facility B: The Market (Interior Fortress Commercial Wing - Tower Loot & Extraction Multiplier)
Located inside the fortress commercial quarter. Stationed Merchants (`Miner` preferred, $+25\%$ labor synergy) amplify loot yields strictly from Infinite Tower clears and Hub cargo extractions:

| Level | Gold Upgrade Cost | Max Workers | Base Loot Multiplier ($\text{BaseBonus}$) | Visual Identity |
| :---: | :---: | :---: | :---: | :--- |
| **Lv. 1** | 1,000 Gold | 1 Worker | `+5.0%` | Single wooden stall, canvas canopy, coin scale. |
| **Lv. 2** | 3,500 Gold | 1 Worker | `+10.0%` | Expanded twin stalls, cargo crates, merchant wagon. |
| **Lv. 3** | 12,000 Gold | 2 Workers | `+18.0%` | Covered bazaar pavillion, hanging brass scales, safe box. |
| **Lv. 4** | 35,000 Gold | 2 Workers | `+28.0%` | Stone exchange depot, trade ledgers, guarded strongbox. |
| **Lv. 5** | 90,000 Gold | 3 Workers | `+40.0%` | Grand celestial merchant exchange, guild crest, vault cellar. |

- **Market Loot Multiplier Formula:**
  $$\text{MarketMultiplier} = 1 + \text{BaseBonus}_{\text{Level}} + \big(0.005 \times \sum \text{EffectiveLabor}_{\text{Market}}\big)$$
  *(Multiplies Gold dropped by mobs and Biome Bosses on Infinite Tower Floors 1–50 and physical cargo banked at the Extraction Pad. Does NOT amplify Outskirts Guard Post passive Gold).*

##### Facility C: The Training Grounds (Interior Fortress Martial Wing - Squad Combat Power Multiplier)
Located inside the fortress military quarter. Stationed Trainers (`Striker` & `Scholar` preferred, $+25\%$ labor synergy) conduct martial drills, applying an overall multiplier to squad combat stats:

| Level | Gold Upgrade Cost | Max Workers | Base Combat Multiplier ($\text{BaseBonus}$) | Visual Identity |
| :---: | :---: | :---: | :---: | :--- |
| **Lv. 1** | 1,200 Gold | 1 Worker | `+4.0%` | Dirt sparring circle, straw dummy, wooden sword rack. |
| **Lv. 2** | 4,000 Gold | 1 Worker | `+8.0%` | Fenced training yard, sandbags, archery targets. |
| **Lv. 3** | 14,000 Gold | 2 Workers | `+14.0%` | Cobblestone arena, iron weapon racks, training pell. |
| **Lv. 4** | 40,000 Gold | 2 Workers | `+22.0%` | Tiered training ring, enchanted strike dummies, war pavilion. |
| **Lv. 5** | 100,000 Gold | 3 Workers | `+32.0%` | Consecrated martial amphitheater, glowing runic combat ring. |

- **Training Combat Multiplier Formula:**
  $$\text{TrainingMultiplier} = 1 + \text{BaseBonus}_{\text{Level}} + \big(0.004 \times \sum \text{EffectiveLabor}_{\text{Training}}\big)$$
  *(Multiplies total squad $\text{FinalATK}$ and $\text{FinalHP}$ across all heroes and equipped Artifacts).*

### 4.4 Hero 3-Tier Attack Cadence & Dynamic Skill Gauge System

In Infinite Tower, combat is server-authoritative with client prediction/interpolation. **Every hero possesses a unique, bespoke 3-tier skill kit** (`Basic`, `Special`, `Skill / Ultimate`); kits are not shared across an archetype. Each hero executes its kit on a 3-tier attack cadence governed by the **Dynamic Skill Gauge** (formerly Stamina):

#### 1. In-Combat Skill Gauge Rules & Cadence Mechanics
- **Gauge Starting State & Maximum:** Heroes enter active combat with **0 Skill Gauge** (represented by the yellow billboard bar above the hero's head) that fills up to a maximum of **100**.
- **Accrual Rules:**
  - **Tier 1: Basic Attack:** Standard auto-attack governed by base interval $t_{\text{atk}}$. Generates **+5 Skill Gauge**.
  - **Tier 2: Special Attack:** Automatically procs on every **3rd attack** (Cadence: `Basic (5) -> Basic (5) -> Special (10)`). Generates **+10 Skill Gauge**. Deals amplified damage with archetype-specific secondary mechanics (frontal cleaves, pierces, multi-slashes, chain lightning, or allied mini-heals).
  - **Tier 3: Skill Attack (Ultimate):** When the gauge reaches **100**, the hero's next attack triggers their signature ultimate. Consumes all 100 gauge points (resetting back to **0**).
- **Accrual Math & Combat Rhythm:**
  - Each 3-attack cycle yields: $5 + 5 + 10 = 20\text{ Skill Gauge}$.
  - A hero requires exactly $5\text{ cycles} \times 3\text{ attacks} = 15\text{ attacks}$ ($10\text{ Basic} + 5\text{ Special}$) to reach 100 gauge points without external buffs.
  - At an average interval of $1.0\text{s}$, a hero triggers an ultimate roughly every $15\text{ seconds}$.
- **Overdrive Whistle Synergy (`[Q]`):** Overdrive Whistle grants $+40\%$ Attack Speed for $5\text{s}$ with zero Stamina drain, compressing the time to charge and release signature Ultimates during crucial DPS/punish windows.

#### 2. Hero Combat Skill Ledger

Each hero's kit is resolved by `HeroId` in `ArchetypeCombatSkills.HeroProfiles` (falling back to the archetype base profile for unknown heroes). A hero's kit inherits its archetype's damage multipliers and secondary mechanics (next table) unless it overrides them.

| # | Hero | Star | Archetype | Basic (+5 SP) | Special (+10 SP, 3rd Hit) | Skill / Ultimate (100 SP) |
| :---: | :--- | :---: | :--- | :--- | :--- | :--- |
| 1 | **Han** (`hero_han`) | 1★ | Striker | Gale Slash | Crescent Cross-Cut | Relentless Blade Flurry |
| 2 | **Aaron** (`hero_aaron`) | 2★ | Vanguard | Bastion Strike | Aegis Shield Bash | Fortress Bulwark |
| 3 | **Catio** (`hero_catio`) | 3★ | Miner | Pickaxe Cleave | Resonance Tremor | Crystalline Excavation |
| 4 | **Valeria** (`hero_valeria`) | 4★ | Healer | Emerald Bolt | Verdant Mend | Sanctuary Miracle |
| 5 | **Ignis** (`hero_ignis`) | 5★ | Vanguard | Molten Cleave | Magma Breaker | Infernal Juggernaut |
| 6 | **Jenna** (`hero_jenna`) | 1★ | Marksman | Wind-Step Shot | Piercing Gale Volley | Sylphid Arrow Storm |
| 7 | **Velkist** (`hero_velkist`) | 2★ | Striker | Twin Fang Cut | Shadow Rend | Phantom Lotus Execution |
| 8 | **Eolka** (`hero_eolka`) | 3★ | Scholar | Ruby Firebolt | Wildfire Chain | Crimson Hellfire Pillar |
| 9 | **Morrigan** (`hero_morrigan`) | 4★ | Vanguard | Abyssal Reap | Dread Shockwave | Obsidian Bastion |
| 10 | **Sovereign Archon** (`hero_archon`) | 5★ | Striker | Void Lance Strike | Rift Sever | Dimensional Cataclysm |
| 11 | **Solaris** (`hero_solaris`) | 6★ | Scholar | Solar Ray | Corona Arc | Supernova Starfall |
| 12 | **Astrea** (`hero_astrea`) | 7★ | Marksman | Astral Arrow | Nebula Piercer | Constellation Judgment |

#### 3. Archetype Base Mechanics (Kit Defaults)

These are the default multipliers and secondary mechanics each hero kit inherits from its archetype. The move names here are the archetype base profile names, used only as a fallback.

| Archetype | Attack Tier | Move Name | Damage / Effect | Secondary Mechanics & Range | Accrual |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Vanguard**<br>*(Tank)* | **Basic** | Shield / Blade Strike | `1.0x ATK` Physical | Single-target melee (`6 studs`). | `+5` |
| | **Special** (Hit 3) | Shield Bash | `1.4x ATK` Physical | Cleaves in front cone (`10 studs`). Applies 0.5s stagger / slow. | `+10` |
| | **Skill** (100 SP) | Fortress Aegis / Iron Roar | `0.0x ATK` Utility / Barrier | Resounding roar taunts all enemies within `25 studs` for `4s`. Grants Vanguard a damage barrier absorbing `40% Max HP` for `6s`. | `Resets to 0` |
| **Striker**<br>*(Melee DPS)* | **Basic** | Twin Blade Slash | `1.0x ATK` Physical | Single-target rapid melee (`6 studs`). | `+5` |
| | **Special** (Hit 3) | Flurry Cross | `1.6x ATK` Physical (2 hits) | Rapid dual cross-slash with `+25% bonus Crit Chance`. | `+10` |
| | **Skill** (100 SP) | Blade Tempest | `3.2x ATK` Physical | Omni-directional dashing flurry dealing massive burst in a `12-stud` radius. | `Resets to 0` |
| **Marksman**<br>*(Ranged DPS)* | **Basic** | Precision Shot | `1.0x ATK` Piercing | Single-target arrow projectile (`28 studs`). | `+5` |
| | **Special** (Hit 3) | Piercing Volley | `1.5x ATK` Piercing | Penetrating bolt passing through primary target in a straight line up to `32 studs`. | `+10` |
| | **Skill** (100 SP) | Rain of Arrows | `2.8x ATK` Physical (4 ticks) | Localized arrow storm (`16-stud` radius) dealing 4 rapid ticks and shredding enemy defense by `20%` for `5s`. | `Resets to 0` |
| **Miner**<br>*(Disruptor)* | **Basic** | Heavy Maul Swing | `1.0x ATK` Blunt | Single-target heavy melee (`6 studs`). | `+5` |
| | **Special** (Hit 3) | Seismic Slam | `1.5x ATK` Blunt | Ground pound shattering the earth in an `8-stud` radius, staggering targets. | `+10` |
| | **Skill** (100 SP) | Crystalline Cataclysm | `2.6x ATK` Blunt AoE | Summons sharp crystalline spikes under all enemies within `18 studs`; struck targets yield bonus temporary gem shards. | `Resets to 0` |
| **Healer**<br>*(Recovery)* | **Basic** | Holy Bolt | `1.0x ATK` Holy | Single-target holy projectile against hostile target (`24 studs`). | `+5` |
| | **Special** (Hit 3) | Radiant Pulse | `1.2x ATK` Holy + `8% Max HP` Heal | Strikes enemy and pulses a mini-heal restoring `8% Max HP` to lowest-HP ally within `30 studs`. | `+10` |
| | **Skill** (100 SP) | Sanctuary Miracle | `35% Max HP` Squad Heal + Cleanse | Chants divine circle (`25-stud` radius). Instantly restores `35% Max HP` to all active squad heroes, cleanses debuffs, and grants `3% HP/sec` regenerative aura for `4s`. | `Resets to 0` |
| **Scholar**<br>*(Mage)* | **Basic** | Arcane Spark | `1.0x ATK` Magic | Single-target mystical projectile (`26 studs`). | `+5` |
| | **Special** (Hit 3) | Chain Lightning | `1.4x ATK` Lightning | Arcs from primary target to up to 2 adjacent mobs within `14 studs`. | `+10` |
| | **Skill** (100 SP) | Supernova Cataclysm | `3.5x ATK` Fire AoE | Dimensional portal drops a burning meteor on target area (`20-stud` radius), leaving lingering ground flames for `3s`. | `Resets to 0` |

#### 4. Visual & Audio Combat Feedback
- **Billboard Gauge:** Yellow bar above hero health smoothly fills from $0 \to 100\%$.
- **Skill Ready Indicator:** When gauge reaches $100\%$, the bar triggers a dynamic golden pulsation animation (`#FFD700`), signaling the impending ultimate.
- **Floating Combat Text (FCT):**
  - **Basic Hit:** Pale Green (`#F3FFE2`)
  - **Special Hit:** Vibrant Orange (`#FF9900`), Bold font
  - **Skill / Ultimate Hit:** Glowing Gold (`#FFD700`), 1.25x scale, Extra Bold font
  - **Restorative Heal:** Lime Green (`#44FF88`), prefixed with `+`
  - **Protective Barrier:** Cyan (`#00E5FF`), prefixed with `🛡️ +`

### 4.5 Master Controls & Tactical Commands

| Action | Keybind / Input | Description |
| :--- | :--- | :--- |
| **Shift Sprint** | `[LeftShift / RightShift]` | $3.0\times$ speed multiplier for rapid traversal across bridges, rings, and rooms. |
| **Focus Target** | `[Click / Tap]` | Raycast onto any mob, boss, or thief to focus all 5 heroes' aggro. |
| **Overdrive Whistle** | `[Q]` / Bottom Bar | $20\text{s}$ CD. Grants $+40\%$ Attack Speed for $5\text{s}$ across all active heroes with zero Stamina drain, allowing squads to rapidly charge their Skill Gauges. |
| **Emergency Recall** | `[E]` / Bottom Bar | $6\text{s}$ CD. Instantly warps squad to Master + $2\text{s}$ pacify (dodges lethal AoE). Yields priority to ProximityPrompts. |
| **Drop Carried Item**| `[R]` / HUD Button | Drops carried cargo or relic on the ground; restores normal WalkSpeed. |
| **Retaliate Attack** | `[⚔️ RETALIATE]` | Single-click HUD prompt when your drop is stolen to unleash squad PvP retaliation. |

### 4.6 Tactical UI & HUD Architecture

The player interface is built from modular, gothic-styled components:
1. **Bottom Navigation Toolbar (`BottomToolbar`):**
   - **Left:** `[PATCH NOTES]` button displaying current server update toasts.
   - **Center Group:** `[THE PIT]` (opens Synthesis/Promotion modals) | `[FORGE]` (opens Blacksmith Star Ascension modal) | `[SQUAD]` (opens 5-Hero Squad Deploy modal) | `[OVERDRIVE]` (Whistle 1 / Q) | `[RECALL]` (Whistle 2 / E) | Vertical Divider | `[AutoSwap]` (4-way arrow icon: auto-swaps exhausted heroes with bench) | `[RosterGrid]` (3x3 grid icon: toggles Squad Deploy modal).
   - **Right Group:** Settings Gear (toggles telemetry overlay) | `[SAVE]` button (manual profile save trigger).
2. **Tower Navigation UI (`TowerController.client.luau`):**
   - **In-World Navigation Pedestals & Prompts:** Travel interactions are accessed in-world via ProximityPrompts (`Previous Floor`, `Next Floor`, `Floor Selector`, and `Return to Hub` pedestals on the safe arrival pad, plus the Central Crimson Tower `Choose floor` prompt in the Hub) and the bottom toolbar `[TOWER]` button.
   - **Top-Right `Return to Hub` Action Button:** Whenever the Master is visiting any Tower floor (`FloorId >= 1`), a dedicated top-right **`Return to Hub`** button (`TowerGui.ReturnHubButton`) is displayed for one-click extraction back to the Fortress Plot.
   - **Biome-Grouped Floor Selector Modal (`FloorSelector`):** Scrollable 50-floor selector organized under 10 **Biome Header Banners** (`BIOME 1 — VERDANT RUINS (FLOORS 1–5)` through `BIOME 10 — ABYSSAL THRONE (FLOORS 46–50)`). Each floor button displays live status badges (`◆` Boss Floor, `★` You + Squad present, `●` You present, `▲` Squad stationed) and opens a detail pane showing floor name, biome, role (`Boss Floor` / `Combat Floor`), live `Visited: N | Squads: M` presence counts, and action buttons (`Visit floor`, `Assign squad`, `Recall squad`).
   - **Modal Click-Through Prevention (`MasterController.client.luau`):** Viewport targeting checks `GuiService:GetGuiObjectsAtPosition` so clicking inside open UI modals or HUD buttons never leaks world-space `FocusTarget` raycasts onto mobs behind the UI.
3. **Real-Time Combat Feedback & Boss HUD (`CombatFeedback.luau`, `EnemyAnimationController.luau`, `HUDController.client.luau`):**
   - **Tower Floor Boss Top HUD Banner:** Engaging any of the 10 Biome Bosses on Floors `5, 10, ..., 50` activates the top-center Boss HUD Banner (`_G.ClientCombatState.FloorBoss`), displaying `"FLOOR N BIOME BOSS — NAME [PHASE 1 / PHASE 2: ENRAGED]"` and a live HP bar that automatically clears on boss death or floor departure.
   - **Damage Popups:** Server-hit floating damage labels pooled up to 32 active instances. Styled with `GothamBold` font, quadratic easing upward, and color-coded:
     - Gold (`#FFCF59`): Overdrive crits / empowered hits.
     - Pale Green (`#F3FFE2`): Normal outbound hero damage.
     - Coral Red (`#FF7474`): Incoming damage received by heroes.
   - **Hit Sparks:** Material Neon sphere sparks with dynamic scaling and fade.
   - **Telegraph Geometry (`MAX_EFFECTS = 12` Cap):** Authoritative server-timed warning shapes with expanding inner progress-fill discs (`SELF_DISC`, `TARGET_DISC`), frontal cleave wedges (`ARC`), and swept-corridor warning strips + flying Neon orbs (`PROJECTILE`).

---

## 5. BIOME BOSS ENCOUNTER DESIGN (MILESTONE FLOORS)

### 5.1 Architecture & Biome Milestone Cadence
In **Infinite Tower**, major boss encounters take place at the apex of each biome: every 5th floor of the Infinite Tower (Floors 5, 10, 15, 20, 25, 30, 35, 40, 45, 50). Each Biome Boss commands a massive dedicated arena dais ($60 \times 2 \times 60\text{ studs}$ `BossDaisFixture`) and possesses dynamic health, high damage multipliers, and signature multi-phase telegraphed attacks.

#### The 10 Biome Bosses:

| Floor | Biome Name | Biome Boss Name | Rig Family | Maximum Health | Basic Attack Damage | Signature Attack Types |
| :---: | :--- | :--- | :--- | :---: | :---: | :--- |
| **5** | **Verdant Ruins** | **Mossbound Guardian** | `STONE_COLOSSUS` | `22,050` | `16` | Frontal Cleave (`ARC`), Quake (`SELF_DISC`), Root Bloom (`TARGET_DISC`) |
| **10** | **Fungal Hollow** | **Spore Matriarch** | `FUNGAL_COLOSSUS` | `76,500` | `24` | Spore Burst (`SELF_DISC`), Corrosive Cloud (`TARGET_DISC`) |
| **15** | **Ashen Dunes** | **Sandstone Colossus** | `STONE_COLOSSUS` | `470,813` | `106` | Magma Cleave (`ARC`), Sand Quake (`SELF_DISC`), Obsidian Spikes (`TARGET_DISC`) |
| **20** | **Frozen Citadel** | **Frostbound King** | `ROYAL_BIPED` | `1,784,250` | `155` | Glacial Cleave (`ARC`), Blizzard Shock (`SELF_DISC`), Ice Spikes (`TARGET_DISC`) |
| **25** | **Infernal Foundry** | **Ember Titan** | `FORGE_COLOSSUS` | `12,198,938` | `685` | Anvil Hammer (`ARC`), Slag Quake (`SELF_DISC`), Molten Core (`TARGET_DISC`) |
| **30** | **Thunder Highlands** | **Storm Roc** | `GIANT_AVIAN` | `83,724,469` | `1,006` | Gale Slash (`ARC`), Thunderclap (`SELF_DISC`), Lightning Strike (`TARGET_DISC`) |
| **35** | **Corrupted Grove** | **Blight Sovereign** | `GROVE_COLOSSUS` | `950,189,344` | `4,436` | Briar Whip (`ARC`), Heartrot Bloom (`SELF_DISC`), Rot Tendrils (`TARGET_DISC`) |
| **40** | **Sunken Sanctuary** | **Tidal Leviathan** | `SERPENT` | `5,352,379,031` | `6,517` | Tidal Sweep (`ARC`), Maelstrom (`SELF_DISC`), Geyser Strike (`TARGET_DISC`) |
| **45** | **Astral Archives** | **Rift Warden** | `ARCANE_COLOSSUS` | `23,593,202,156` | `28,728` | Astral Sweep (`ARC`), Dimensional Rupture (`SELF_DISC`), Void Well (`TARGET_DISC`) |
| **50** | **Abyssal Throne** | **Crimson Overlord** | `ROYAL_COLOSSUS` | `110,844,632,813` | `42,211` | Hellfire Cleave (`ARC`), Abyssal Nova (`SELF_DISC`), Doom Pillars (`TARGET_DISC`) |

### 5.2 Full 40-Enemy Biome Roster & Procedural Rig Architecture
Each of the 10 biomes features 4 local-authored procedural enemies (2 Regulars, 1 Elite, 1 Biome Boss = **40 enemies total** in `MobCatalog.luau` and `FirstBiomeCombat.luau`), built with biome-specific material/glow palettes in `TowerEnemyRigs.luau` and animated with planted-foot leg counter-rotation (`plantedPose`) in `TowerEnemyClips.luau`:

| Biome (Floors) | Regular 1 | Regular 2 | Biome Elite | Biome Boss (5th Floor) |
| :--- | :--- | :--- | :--- | :--- |
| **1. Verdant Ruins (1–5)** | Moss Crawler (`CRAWLER`) | Ruin Guardian (`ARMORED_BIPED`) | Vinebound Elite (`ROOTED_BIPED`) | **Mossbound Guardian** (`STONE_COLOSSUS`) |
| **2. Fungal Hollow (6–10)** | Spore Skitter (`CRAWLER`) | Lantern Spore (`FUNGAL_BIPED`) | Mycelial Brute (`HEAVY_BIPED`) | **Spore Matriarch** (`FUNGAL_COLOSSUS`) |
| **3. Ashen Dunes (11–15)** | Dune Scarab (`INSECT`) | Ash Raider (`WEAPON_BIPED`) | Glass Scorpion (`SCORPION`) | **Sandstone Colossus** (`STONE_COLOSSUS`) |
| **4. Frozen Citadel (16–20)** | Frost Hound (`QUADRUPED`) | Rime Sentry (`WEAPON_BIPED`) | Glacier Knight (`ARMORED_BIPED`) | **Frostbound King** (`ROYAL_BIPED`) |
| **5. Infernal Foundry (21–25)** | Cinder Imp (`SMALL_BIPED`) | Forge Construct (`ARMORED_BIPED`) | Molten Taskmaster (`HEAVY_BIPED`) | **Ember Titan** (`FORGE_COLOSSUS`) |
| **6. Thunder Highlands (26–30)** | Storm Talon (`AVIAN`) | Crag Channeler (`CASTER_BIPED`) | Thunder Ram (`QUADRUPED`) | **Storm Roc** (`GIANT_AVIAN`) |
| **7. Corrupted Grove (31–35)** | Blight Wolf (`QUADRUPED`) | Thorn Weaver (`ROOTED_BIPED`) | Rotwood Keeper (`TREANT`) | **Blight Sovereign** (`GROVE_COLOSSUS`) |
| **8. Sunken Sanctuary (36–40)** | Tide Claw (`CRUSTACEAN`) | Drowned Acolyte (`CASTER_BIPED`) | Coral Warden (`ARMORED_BIPED`) | **Tidal Leviathan** (`SERPENT`) |
| **9. Astral Archives (41–45)** | Rune Mite (`CRAWLER`) | Astral Scribe (`CASTER_BIPED`) | Archive Executor (`ARMORED_BIPED`) | **Rift Warden** (`ARCANE_COLOSSUS`) |
| **10. Abyssal Throne (46–50)** | Abyss Reaver (`WEAPON_BIPED`) | Void Invoker (`CASTER_BIPED`) | Throne Executioner (`HEAVY_BIPED`) | **Crimson Overlord** (`ROYAL_COLOSSUS`) |


### 5.3 Tactical Mechanics & Combat Flow ("Greed vs. Coma")
1. **Telegraph Shapes & Timings (`AttackTimeline.luau`):**
   - **`ARC` (Basic Cleave):** Fast frontal swipe ($0.65\text{s–}1.1\text{s}$ windup, $7\text{–}13\text{-stud}$ reach). Vanguard tanks should position facing away from squishier DPS heroes.
   - **`SELF_DISC` (Boss Quake / Burst):** Expanding crimson circle with inner progress-fill disc centered on the boss ($1.8\text{s}$ windup, $1.2\text{s}$ recovery, 22-stud radius). Masters must sprint out and trigger **`[E]` Emergency Recall** before impact.
   - **`TARGET_DISC` (Targeted AoE):** Ground circle with expanding fill disc locked onto a hero's position ($1.4\text{s–}2.2\text{s}$ windup, $9\text{–}13\text{-stud}$ radius). Requires instant Master recognition and recall repositioning.
   - **`PROJECTILE` (Ranged Swept Corridor):** Aimed linear corridor ($0.75\text{s}$ windup + $0.35\text{s}$ travel time, $26\text{-stud}$ range, $2.2\text{-stud}$ corridor width). Evaluates authoritative swept-segment distance along the projectile line at `WindupSeconds + TravelSeconds`.
2. **Coma Skill Check:**
   - Heroes caught inside `SELF_DISC` or `TARGET_DISC` blast zones suffer instant 50% Stamina loss or fall into a **60-second Coma** (expelled back to the Fortress Infirmary).
3. **Punish Window:**
   - Immediately following a Signature detonation, the Biome Boss enters an exposed recovery window granting $+25\%$ damage taken for 4.0s. Active Masters trigger **`[Q]` Overdrive Whistle** to unleash $+40\%$ squad attack speed and maximize DPS output.

### 5.4 Biome Boss Loot & Progression Ledger
- **Encounter Respawns:** Biome Bosses operate on an authoritative server respawn cadence ($300\text{s}$ cooldown upon defeat).
- **Rewards Table:**
  - **Tiered Gold & Gems:** Scaled exponentially to biome difficulty.
  - **High-Rarity Artifact Drops:** Rare direct drops of high-tier Artifacts (from Legendary up to Origin rarity, e.g. `art_paladin_claymore`, `art_crystal_greatbow`, `art_blade_of_the_rift`).
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

Higher rarities retain stat definitions in [the complete weapon matrix](balance/STAT_SCALING_TABLES.md#weapon-power-by-inherent-rarity-and-promoted-stars). They are outside the required floor-50 reference build; this stat revision does not change how any rarity is obtained. The current hero level cap stays 50.

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
- **Summon Cost:** `160 Gems` per single pull, `1,600 Gems` for a 10x pull (matching live `ArtifactCatalog.Banner`).
- **Banner Rarity Probability Table:**
  - **Common (Tier 1):** `54.9%`
  - **Uncommon (Tier 2):** `25.0%`
  - **Rare (Tier 3):** `12.0%`
  - **Superior (Tier 4):** `5.5%`
  - **Exalted (Tier 5):** `2.0%`
  - **Legendary (Tier 6):** `0.5%`
  - **Mythical (Tier 7):** `0.1%`
  - *(Other Rarities will be available in future updates)*
- **Pity Safeguards:**
  - **10-Pull Guarantee:** Every 10-pull guarantees at least one **Rare (Tier 3)** or higher artifact.
  - **50-Pull Hard Pity:** If no **Legendary (Tier 6)** or higher artifact has been pulled in 49 pulls, the 50th pull guarantees a **Legendary (Tier 6)** or higher artifact.
  - **Biome Boss Milestone Drops:** Rare direct drops of Mythical to Origin artifacts from milestone floor clears.
  - **Blacksmith Rarity Refinement:** Forge masters can spend high quantities of Gold and Gems to refine an existing artifact's rarity tier upward.

### 7.5 Archetype Restrictions & 3D Socketing Standards
1. **One Weapon Type per Archetype:** Each hero holds a single equipped artifact, and each archetype can equip exactly one weapon type. There are no off-hand or accessory slots.

   | Archetype | Weapon type | Play pattern |
   | --- | --- | --- |
   | `Vanguard` | **Sword & Shield (`SWORD_SHIELD`)** | Main-hand slashing with an off-hand shield for defensive posture and damage mitigation. |
   | `Striker` | **Daggers (`DAGGERS`)** | High-speed dual-wield flurry attacks. |
   | `Marksman` | **Bow (`BOW`)** | Ranged single-target piercing attacks. |
   | `Miner` | **Axe (`AXE`)** | Heavy cleaving strikes. |
   | `Scholar` (Mage) | **Staff (`STAFF`)** | Ranged mystic projectiles and aura empowerment. |
   | `Healer` | **Tome (`TOME`)** | Channeled magical bursts and restorative resonance. |

   Swords and shields are a single combined weapon; legacy `SWORD` and `SHIELD` artifacts migrate to `SWORD_SHIELD`. Rings (`RING`) are removed: owned rings are deleted on load, and any hero left holding a weapon its archetype can no longer use is unequipped and given a compatible unequipped artifact if one is owned.
2. **Prefab Directory:** Centralized in `ReplicatedStorage.Assets.Weapons` (`weapon_bow`, `weapon_sword_shield`, `weapon_daggers`, `weapon_axe`, `weapon_staff`, `weapon_tome`; `weapon_sword` remains as the bare blade the sword & shield prefab is built from).
3. **Physical Constraints:** All weapon parts have `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `Massless = true`, `Anchored = false`, welded to the prefab's PrimaryPart `Handle`.
4. **Dynamic Socketing:** Each prefab carries oriented socket attachments: `Grip` on every weapon, plus `ShieldMount` on the shield and `Nock`/`TipUpper`/`TipLower` on the bow. The client joins each one to the matching hero-rig attachment with a single `Weld` (`HeroSockets`).

   | Weapon type | Main hand | Second socket |
   | --- | --- | --- |
   | `BOW` | Left hand grip | — (string `Nock` and limb tips for the draw) |
   | `SWORD_SHIELD` | Right hand grip | Shield strapped to the outer left forearm |
   | `DAGGERS` | Right hand grip | Off-hand dagger in the left hand grip |
   | `AXE` | Right hand grip, near the butt of the haft | — (`OffhandGrip` reserved for two-handed swings) |
   | `STAFF` | Right hand grip | — |
   | `TOME` | Left hand grip | — |

   Hero bodies never carry weapons or shields of their own; the equipped artifact is the only weapon shown.

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
