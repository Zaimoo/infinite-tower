# DOCUMENT 4: UI/UX WIREFRAME SPECIFICATIONS & INTERACTION FLOWS — MVP (v0.1)
**Project Codename:** *Project: Waiting Room*  
**Target Devices:** PC (Keyboard/Mouse), Mobile/Tablet (Touch), Console (Gamepad)  
**UI Architecture:** Roblox `ScreenGui` (`IgnoreGuiInset = true`, `UIScale` responsive 1080p baseline) + World-Space `BillboardGui`, `Beam`, and `Highlight` instances.

---

## 1. MAIN MASTER HUD (`MasterHUDScreenGui`)

The Main Master HUD is designed around **"Eyes-on-the-Arena" tactical command**. All critical combat telemetry (World Boss *Devouring Nova* telegraphs, Squad Stamina bars, Whistle cooldowns, and the dynamic `[B] Shatter Pact` betrayal trigger) sit in the peripheral bands so the center `70%` of the viewport remains unobstructed for clicking targets and spotting physical Relics.

### 1.1 Full-Screen Master HUD ASCII Wireframe

```text
+------------------------------------------------------------------------------------------------------------------+
| [GOLD: 14,250 (!)]  [GEMS: 1,450 (+)]  [RP: 340]   |   [HONOR: +55 ★ SYNDICATE SAINT]   |  [PLOT TP]  [SETTINGS] |
|----------------------------------------------------+------------------------------------+------------------------|
|                         [!] WORLD BOSS: THE DIMENSIONAL SOVEREIGN — SPAWNS IN 02:45 [!]                          |
|                         [====== DEVOURING NOVA IN: 04.2s (GET TO OUTER RIM + PRESS [E]!) ======]                 |
+------------------------------------------------------------------------------------------------------------------+
|                                                                                 +------------------------------+ |
|  [BLOOD PACT ACTIVE]                                                            | WORLD BOSS LIVE DPS (RING 3) | |
|  Partner: @VortexMaster                                                         |------------------------------| |
|  • +20% Squad ATK | -25% Stamina Drain                                          | #1 @WhaleKing     41.2% [♛]  | |
|  • Tandem Carry: [ACTIVE - 11.2 studs]                                          | #2 @You [PACT+25%]24.8% [✓]  | |
|    (Relic Slow Halved: -45% -> -22.5%)                                          | #3 @VortexMaster  16.4% [✓]  | |
|                                                                                 | #4 @ShadowF2P      9.1% [✓]  | |
|  [ACTIVE MERCENARY RENTED: 06:12]                                               | #5 @CasualBob      5.3% [✓]  | |
|  [Velkist 2★] (Working: Mana Conduit)                                           | #6 @NewbieDan      1.8% [X]  | |
|  [🔍 AUDIT SOUL (50G)]                                                          |   (Min 3.0% Req. for Loot!)  | |
|                                                                                 |------------------------------| |
|                                    ( CENTER VIEWPORT: ARENA )                   | BOSS PITY METER: [████░░ 40%]| |
|                                                                                 | (Ranks #4-#6: +10% Per Clear)| |
|                                 [Click / Tap] Mob or Rogue Hero                 +------------------------------+ |
|                                      to Focus Squad Aggro                                                        |
|                                                                                                                  |
|                                    +---------------------------------------+                                     |
|                                    |  [!] CARRYING: THE CALAMITY HEART [!] |                                     |
|                                    |  WalkSpeed: -22.5% (Tandem) | No Jump |                                     |
|                                    |   [B] SHATTER PACT (BETRAY FOR 130%)  |                                     |
|                                    +---------------------------------------+                                     |
|                                                                                                                  |
|  +------------+  +------------+  +------------+  +------------+  +------------+     +-----------+  +-----------+ |
|  | 1. Han 3★  |  | 2. Jenna 2★|  | 3. Aaron 2★|  | 4. Eolka 3★|  | 5. [COMA!] |     |    [Q]    |  |    [E]    | |
|  | HP [██████]|  | HP [██████]|  | HP [████░░]|  | HP [██████]|  | IN INFIRM. |     | OVERDRIVE |  |  RECALL   | |
|  | ST [████░░]|  | ST [█████░]|  | ST [██░░░░]|  | ST [████░░]|  | 00:42 Left |     | +40% ASPD |  | DODGE AoE | |
|  | [ATTACKING]|  | [ATTACKING]|  | [LOW STAM!]|  | [ATTACKING]|  | (0 DPS)    |     | (-5 STAM) |  | (2s Drop) | |
|  +------------+  +------------+  +------------+  +------------+  +------------+     +-----------+  +-----------+ |
+------------------------------------------------------------------------------------------------------------------+
```

### 1.2 Component Hierarchy (`StarterGui.MasterHUDScreenGui`)

```text
MasterHUDScreenGui (ScreenGui - ResetOnSpawn: false, IgnoreGuiInset: true)
├── UIScale_Responsive (UIScale - Auto-scales 1920x1080 baseline across PC/Mobile/Console)
├── TopBarContainer (Frame - AnchorPoint: 0.5, 0 | Size: 1, 0, 0, 56)
│   ├── CurrencyCluster (Frame - UIListLayout Horizontal)
│   │   ├── GoldPill (Frame) -> Icon, AmountLabel, AtRiskBadge ("15% Vulnerable if Rogue")
│   │   ├── GemsPill (Frame) -> Icon, AmountLabel, QuickShopButton
│   │   └── RPPill (Frame) -> Icon, AmountLabel, RatePerMinSubtext ("+30.6/m")
│   ├── HonorStatusBadge (Frame - Center)
│   │   ├── HonorFillBar (Frame - Range: -100 to +100)
│   │   ├── TierIcon (ImageLabel - Saint Halo / Neutral Shield / Rogue Red Skull)
│   │   └── RogueTimerLabel (TextLabel - Visible only when Rogue: "ROGUE: 04:18")
│   └── UtilityCluster (Frame - Right)
│       ├── ReturnToPlotButton (TextButton - Disabled if carrying Relic or PvP-locked)
│       └── WaitingRoomRosterButton (TextButton - Opens WaitingRoomScreenGui)
│
├── WorldBossTopBanner (Frame - AnchorPoint: 0.5, 0 | Pos: 0.5, 0, 0, 62)
│   ├── CountdownModeFrame (Visible T-20:00 to T-0:00; turns Crimson at T-3:00)
│   └── ActiveBossModeFrame (Visible during Ring 3 World Boss / Rift Boss fight)
│       ├── BossNameAndPhaseLabel ("THE DIMENSIONAL SOVEREIGN — PHASE 2: INSTABILITY")
│       ├── BossHealthBar (Frame - Dynamic HP / MaxHP + 40% Tether Shield Overlay)
│       └── DevouringNovaCastBar (Frame - Pulses Red during 3.0s Nova Telegraph)
│
├── LeftSyndicateTracker (Frame - AnchorPoint: 0, 0.5 | Pos: 0, 16, 0.45, 0)
│   ├── BloodPactCard (Frame - Visible when in a Pact or Invited)
│   │   ├── PartnerNameLabel, BuffSummaryLabel, TandemDistanceIndicator
│   └── RentedMercenaryCard (Frame - Visible during active 10m Mercenary rental)
│       ├── MercPortrait, RemainingTimeLabel ("06:12"), AuditSoulButton ("50 Gold")
│
├── RightWorldBossLeaderboard (Frame - AnchorPoint: 1, 0.5 | Pos: 1, -16, 0.45, 0)
│   ├── HeaderLabel ("LIVE DAMAGE SCORE")
│   ├── PlayerRankList (UIListLayout - 6 Row Frames for Ranks #1 to #6)
│   │   └── RankRow_1..6 (RankNum, PlayerName, PactBonusTag, DamagePct, QualifiedCheckmark)
│   └── BossPityFooter (Frame)
│       ├── PityProgressBar (0% to 100%, highlights "+10% on Clear for Ranks #4-#6")
│
└── BottomActionDock (Frame - AnchorPoint: 0.5, 1 | Pos: 0.5, 0, 1, -16)
    ├── RelicCarryContextBanner (Frame - Positioned above Squad Strip; Visible ONLY when carrying Relic)
    │   ├── RelicNameAndPenaltyLabel ("CARRYING: THE CALAMITY HEART (-45% SPD | NO JUMP)")
    │   └── ShatterPactButton (TextButton - Keybind [B] | Visible ONLY if in Blood Pact + Carrying Relic)
    ├── DeployedSquadStrip (Frame - UIListLayout Horizontal, 5 Hero Slots + 1 Mercenary Slot)
    │   └── SquadSlot_1..5 (Portrait, StarBadge, HPBar_Green, StaminaBar_Yellow, StateTag, ComaOverlay)
    └── WhistleControlCluster (Frame - Right of Squad Strip, Large Touch/Hotkey Buttons)
        ├── OverdriveButton_Q (ImageButton - Keybind [Q], 20s Radial Cooldown, "-5 STAM")
        └── EmergencyRecallButton_E (ImageButton - Keybind [E], 6s Radial Cooldown, "DODGE AoE")
```

### 1.3 UX Feedback & Micro-Interaction Rules (Main HUD)
1. **The `[E]` Recall Whistle "Skill-Check Assist" Pulse:**
   - When the World Boss begins channeling **Devouring Nova** (`3.0s` duration), the `DevouringNovaCastBar` fills from `0.0s` to `3.0s`.
   - Between **`t = 1.1s` and `t = 2.8s`** (the optimal counterplay window where the `2.0s` aggro-drop outlasts the detonation), the **`[E]` Emergency Recall Whistle** button border flashes bright cyan-gold and emits a crisp sonar ping, training F2P players to nail the timing.
2. **Post-Nova Punish Window (`+25% Boss Damage Taken`):**
   - For `5.0s` after *Devouring Nova* detonates, the Boss HP bar cracks open with a golden `"CORE EXPOSED (+25% DMG!)"` banner, and the **`[Q]` Overdrive Whistle** button pulses orange to prompt an immediate burst window.
3. **Dynamic `[B] Shatter Pact` Temptation UX:**
   - The **`[B] Shatter Pact`** button is hidden during normal play to prevent accidental clicks. The instant a Pact member picks up a physical Relic, the crimson **`[B] SHATTER PACT (BETRAY FOR 130%)`** banner slides up above the bottom hotbar with a heartbeat audio loop that accelerates as the carrier approaches `R = 460 studs` (the fork between the **Shared Pact Pedestal** and their **Private Extraction Pad**).
4. **3.0% World Boss Qualification Threshold Indicator:**
   - On the Right-Side Live DPS Leaderboard, a player's row is tinted **Muted Red (`[X] <3.0%`)** until their combined damage (including the `+25%` Blood Pact shared score) crosses `3.0%`, at which point the row flashes **Emerald Green (`[✓] LOOT QUALIFIED`)**.

---

## 2. WAITING ROOM MANAGEMENT UI (`WaitingRoomScreenGui`)

Accessible from anywhere on the player's Private Plot (or via the `[ROSTER & TYCOON]` HUD button), this unified screen lets the Master drag-and-drop or one-click assign heroes across their **Active 5-Hero Squad**, **Mana Conduit**, **Infirmary & Barracks**, and **Dimensional Lab**.

### 2.1 Waiting Room Management ASCII Wireframe

```text
+------------------------------------------------------------------------------------------------------------------+
|  THE WAITING ROOM — MASTER OVERSEER CONSOLE                                                    [X CLOSE (ESC)]   |
+--------------------------------------------------------+---------------------------------------------------------+
|  LEFT PANE: ACTIVE DEPLOYMENTS & TYCOON FACILITIES     |  RIGHT PANE: HERO ROSTER (24 / 50 CAPACITY)             |
|                                                        |  Sort: [★ Stars v] [Combat DPS] [Labor/m] [Stamina]     |
|  1. DEPLOYED COMBAT SQUAD (Active DPS: 642/s)          |  Filter: [All] [Benched Only] [Exhausted/Coma]          |
|  +---------+ +---------+ +---------+ +---------+ +---+ |  +---------------------------------------------------+  |
|  | 1.Han 3★| |2.Jenna2★| |3.Aaron2★| |4.Eolka3★| |🔒5| |  | [🔒] [Han 3★ Lv.15]      [🔒] [Eolka 3★ Lv.12]    |  |
|  | ST: 84% | | ST: 92% | | ST: 18% | | ST: 76% | |LAB| |  | DPS: 298 | Lab: 54/m     DPS: 267 | Lab: 62/m     |  |
|  | [BENCH] | | [BENCH] | | [HEAL!] | | [BENCH] | |LV3| |  | Status: [SQUAD SLOT 1]   Status: [SQUAD SLOT 4]   |  |
|  +---------+ +---------+ +---------+ +---------+ +---+ |  +---------------------------------------------------+  |
|  [⚡ AUTO-SWAP EXHAUSTED (<25% STAM) TO INFIRMARY]      |  | [🔓] [Catio 2★ Lv.20]    [🔓] [Catio 1★ Lv.10]    |  |
|  ----------------------------------------------------  |  | DPS: 65  | Lab: 61/m ★   DPS: 39  | Lab: 36/m ★   |  |
|  2. MANA CONDUIT [Lv.3] — Output: 92.1 Gems/min        |  | Status: [CONDUIT SLOT 1] Status: [INFIRMARY #1]   |  |
|  Workers: [Catio 2★ (+25%)] [Miner 2★ (+25%)] [🔒Lv5]  |  +---------------------------------------------------+  |
|  Chest: [340 / 600 Gems] [COLLECT] [UPGRADE: 7.5kG]    |  | [🔓] [Velkist 2★ Lv.1]   [🔓] [Han 1★ Lv.1] (x9)  |  |
|  Mimic Defense: (•) True  ( ) Fool's Gold  ( ) Poverty |  | DPS: 97  | Lab: 23/m     DPS: 51  | Lab: 17/m     |  |
|  [⚠️ VISITOR RUNE DETECTED! PURGE FACILITY (11.4s)]    |  | Status: [BENCHED]        Status: [BENCHED]        |  |
|  ----------------------------------------------------  |  | [DEPLOY] [ASSIGN WORK]   [FEED IN PIT] [ASSIGN]   |  |
|  3. THE INFIRMARY & BARRACKS [Lv.3] — Regen: 11.6 St/s |  +---------------------------------------------------+  |
|  Healers: [Catio 1★ (+25%)] [Healer 2★] [🔒Lv5]        |                                                         |
|  Recuperation Beds (4/4 Unlocked):                     |  SELECTED HERO QUICK-ACTION BAR:                        |
|  • Bed 1: [Velkist 2★] — COMA (00:24s remaining)       |  Selected: [Velkist 2★ Lv.1] (Striker | Bloodthirst)    |
|  • Bed 2: [Aaron 2★]   — Resting (Stamina: 44% -> 100%)|  -> [Deploy to Squad]  [Send to Infirmary Bed]          |
|  • Bed 3: [EMPTY BED]  | • Bed 4: [EMPTY BED]          |  -> [Assign: Conduit]  [Assign: Infirmary] [Assign: Lab]|
|  ----------------------------------------------------  |  -> [Open in Synthesis Pit]   [List on Mercenary Board] |
|  4. THE DIMENSIONAL LAB [Lv.2] — Output: 23.1 RP/min   |                                                         |
|  Scholars: [Jenna 2★ (+25%)] [🔒Lv3] [🔒Lv5]           |                                                         |
|  Tech: [✓ Slot 4] [✓ Ring 2 Gate] [Slot 5: 420 RP]     |                                                         |
|  Fabricator: [🌀 CRAFT RIFT LURE (300 RP + 5,000G)]    |                                                         |
+--------------------------------------------------------+---------------------------------------------------------+
```

### 2.2 Interaction Flows & Smart-Assignment Rules
1. **One-Click `"Auto-Swap Exhausted Squad to Infirmary"` Button:**
   - Pressing this single button scans the 5 Deployed Combat Squad slots for any hero with `Stamina < 25%`, moves them directly into available **Infirmary Recuperation Beds**, and slots the highest-DPS `100% Stamina` Benched Heroes into the squad—cutting roster maintenance during a 3-minute loop down to **under 2 seconds**.
2. **Preferred Facility Synergy Highlighting (`+25% Labor`):**
   - When dragging or selecting a Benched Hero, whichever facility matches their archetype (`Miner -> Mana Conduit`, `Healer -> Infirmary`, `Scholar -> Dimensional Lab`) glows with a green **`+25% SYNERGY BONUS`** border and previews the exact `+Gems/min`, `+Stamina/sec`, or `+RP/min` delta before confirmation.
3. **Live Espionage Counterplay (`Purge Facility` + `Mimic Illusion Toggle`):**
   - If a visitor completes a `2.0s` rune channel on any facility, that facility's card flashes amber with a `15.0s` countdown button: **`[⚠️ VISITOR RUNE DETECTED! PURGE FACILITY (15.0s)]`**.
   - Directly above it on the Mana Conduit card sits the 3-way radio toggle for **Mimic Chest Illusions** (`True State` / `Fool's Gold` / `Veil of Poverty`).

---

## 3. THE SYNTHESIS PIT & STAR PROMOTION UI (`ThePitScreenGui`)

Opened at the fiery cauldron in the center of the Waiting Room plot, this UI combines **Synthesis (XP Fodder Feeding)** and **Star Promotion (1★ $\rightarrow$ 5★ Ascension)** into a seamless two-stage progression pipeline.

### 3.1 Tab A — Synthesis ("The Pit" XP Leveling) ASCII Wireframe

```text
+------------------------------------------------------------------------------------------------------------------+
|  🔥 THE PIT — HERO SYNTHESIS & STAR PROMOTION                         [TAB 1: SYNTHESIS XP]  [TAB 2: PROMOTION]  |
+--------------------------------------------------------+---------------------------------------------------------+
|              TARGET HERO IN THE CAULDRON               |              SELECT FODDER DUPLICATES (4 / 20)          |
|                                                        |  [⚡ AUTO-SELECT 1★ FODDER TO CAP]   [CLEAR SELECTION]  |
|                   +----------------+                   |  *(Never selects Locked 🔒, Deployed, or Working units)*|
|                   |  [Velkist 2★]  |                   |                                                         |
|                   |  Lv. 14 -> 16! |                   |  +-----------+ +-----------+ +-----------+ +----------+ |
|                   +----------------+                   |  | [✓] Han 1★| | [✓] Han 1★| | [✓]Jenna1★| |[✓]Catio1★| |
|                                                        |  | Lv.1      | | Lv.1      | | Lv.1      | | Lv.5     | |
|  XP Bar: [████████████░░░░░░] +600 XP (2,340 / 2,540)  |  | +125 XP   | | +125 XP   | | +125 XP   | | +225 XP  | |
|  Formula: (100 * 3^(Stars-1)) + (25 * FodderLevel)     |  +-----------+ +-----------+ +-----------+ +----------+ |
|  ----------------------------------------------------  |  | [ ] Han 1★| | [ ]Aaron2★| | [🔒]Eolka3★| |[WORK]Cat1| |
|  STAT PREVIEW (Lv. 14 ---> Lv. 16):                    |  | Lv.1      | | Lv.1      | | LOCKED    | | IN LAB   | |
|  • Effective HP:     1,010  --->  1,089  (+79 HP)      |  | +125 XP   | | +325 XP   | | PROTECTED | | PROTECTED| |
|  • Effective ATK:      148  --->    160  (+12 ATK)     |  +-----------+ +-----------+ +-----------+ +----------+ |
|  • Combat DPS:       197.3  --->  213.3  (+16.0/s)     |                                                         |
|  • Labor Output:     31.2/m --->  33.1/m (+1.9/m)      |  TOTAL XP GAINED: +600 XP (Consumes 4 Fodder Heroes)    |
|                                                        |  [🔥 SACRIFICE INTO THE PIT (HOLD 0.5s OR CLICK) 🔥]   |
+--------------------------------------------------------+---------------------------------------------------------+
```

### 3.2 Tab B — Star Promotion (`1★` to `5★` Ascension) ASCII Wireframe

```text
+------------------------------------------------------------------------------------------------------------------+
|  ⭐ STAR PROMOTION ALTAR — ASCEND TO HIGHER RARITY                    [TAB 1: SYNTHESIS XP]  [TAB 2: PROMOTION]  |
+--------------------------------------------------------+---------------------------------------------------------+
|              MAX-LEVEL TARGET HERO                     |           SACRIFICE $S$ FODDER OF SAME STAR ($S$)       |
|                                                        |  Requirement: Sacrifice 2x [2★ Heroes] (Any Level)      |
|         +------------------------------------+         |                                                         |
|         |   [Velkist 2★]  ===>  [Velkist 3★] |         |     +-------------------+     +-------------------+     |
|         |   Lv. 20 (MAX)        Lv. 1 (Cap30)|         |     |  SACRIFICE SLOT 1 |     |  SACRIFICE SLOT 2 |     |
|         +------------------------------------+         |     |   [✓] Aaron 2★    |     |   [✓] Catio 2★    |     |
|                                                        |     |   Lv. 1 (Benched) |     |   Lv. 4 (Benched) |     |
|  PROMOTION MULTIPLIERS APPLIED TO BASE STATS:          |     +-------------------+     +-------------------+     |
|  • Base Combat Multiplier:  x1.65 Permanent Base Jump! |                                                         |
|  • Base Labor Multiplier:   x1.35 Permanent Base Jump! |  [⚡ AUTO-FILL UNLOCKED 2★ FODDER]                      |
|  • New Max Level Cap:       Lv. 20  --->  Lv. 30       |  -----------------------------------------------------  |
|  ----------------------------------------------------  |  PROMOTION COST CHECKLIST:                              |
|  LONG-TERM POWER PROJECTION (At 3★ Lv.30 Cap):         |  [✓] Target Hero at Max Level (Lv. 20 / 20)             |
|  • 2★ Lv.20 Max ATK: 183  ===>  3★ Lv.30 Max ATK: 398! |  [✓] 2 / 2 Benched 2★ Fodder Heroes Selected            |
|  • 2★ Lv.20 Max HP: 1,247 ===>  3★ Lv.30 Max HP: 2,712!|  [✓] Gold Fee: 7,500 Gold (You have: 14,250 Gold)       |
|                                                        |                                                         |
|  *(Note: Promotion resets Level to 1 while permanently |  +---------------------------------------------------+  |
|    multiplying underlying Base Stats by 1.65x/1.35x)*  |  |   [⭐ ASCEND TO 3★ EPIC (7,500 GOLD) ⭐]          |  |
|                                                        |  +---------------------------------------------------+  |
+--------------------------------------------------------+---------------------------------------------------------+
```

### 3.3 Step-by-Step UX Flow & Promotion Animation Sequence
1. **Step 1 — Smart Auto-Fodder Selection:**
   - Clicking **`[⚡ AUTO-SELECT 1★ FODDER TO CAP]`** calculates the exact remaining XP required to reach `MaxLevel = Stars * 10` and selects the lowest-level unlocked, benched `1★` heroes without wasting overflow XP.
   - If the target hero hits `MaxLevel` (`Lv.10`, `Lv.20`, `Lv.30`, or `Lv.40`), the UI automatically pulses a golden **`[READY FOR STAR PROMOTION ->]`** button that transitions directly to **Tab 2**.
2. **Step 2 — Promotion Safeguards:**
   - Locked heroes (`Locked == true`), deployed squad heroes, and facility workers are visually badged and excluded from fodder selection.
   - If a player selects a fodder hero with `Level > 1` for Star Promotion, a non-intrusive yellow banner reminds them: *"Tip: Fodder level does not affect Star Promotion; level 1 fodder works identically."*
3. **Step 3 — The 3.2-Second Promotion Cinematic:**
   - **`0.0s – 1.2s`:** The $S$ sacrificed fodder cards dissolve into streams of violet-gold soul embers that spiral into the cauldron.
   - **`1.2s – 2.2s`:** The target hero's R15 rig rises above the cauldron, enveloped in a pillar of light; the old Star badges shatter outward.
   - **`2.2s – 3.2s`:** Camera FOV punches in (`70° -> 58° -> 70°`) as the new **`S+1` Star Badges** slam into place with a metallic anvil chime, displaying the **`+65% BASE COMBAT / +35% BASE LABOR`** banner.

---

## 4. MERCENARY BOARD & SECRET DIRECTIVE MODAL (`MercenaryScreenGui`)

The Mercenary Noticeboard enforces strict **asymmetric information**: the Owner configures a hidden directive (`Loyal`, `Parasite`, `Saboteur`) in a private modal, while Renters see only the hero's public combat/labor stats and the Owner's Honor reputation.

### 4.1 View A — Owner Listing & Secret Directive Modal (Private to Owner)

```text
+------------------------------------------------------------------------------------------------------------------+
|  📜 LIST HERO ON MERCENARY BOARD (10-MINUTE CONTRACT)                                             [X CANCEL]     |
+------------------------------------------------------------------------------------------------------------------+
|  SELECTED HERO TO LIST: [Eolka 3★ Lv.22] (Scholar | 295 DPS | 58.4 Labor/min)                                    |
|  SET RENTAL FEE (GOLD): [=======●===============] 2,500 Gold (Range: 500G - 10,000G)                             |
|------------------------------------------------------------------------------------------------------------------|
|  CHOOSE SECRET DIRECTIVE (HIDDEN FROM ALL RENTERS — ONLY REVEALED IF RENTER PAYS 50G FOR 'AUDIT SOUL'):          |
|                                                                                                                  |
|  +----------------------------------+  +----------------------------------+  +---------------------------------+ |
|  |       [1. LOYAL CONTRACT]        |  |   (•) [2. PARASITE SIPHON]       |  |         [3. SABOTEUR]           | |
|  |         (Safe & Ethical)         |  |       (Stealth Gem Heist)        |  |      (Relic Ambush Trap)        | |
|  |----------------------------------|  |----------------------------------|  |---------------------------------| |
|  | • Works at 110% Efficiency       |  | • Appears to work at 100% Output |  | • Works normally at 100% Output | |
|  |   for the Renter.                |  | • SECRET: Siphons 30% of Renter's|  | • SECRET: When Renter picks up  | |
|  | • Server mints you a +15% Bonus  |  |   Mana Conduit Gems into YOUR    |  |   a Rare/Mythic/Calamity Relic, | |
|  |   Royalty on all output!         |  |   Gem Chest every 60s!           |  |   casts a 2.5s ANKLE SNARE!     | |
|  | • TELL: Golden work pulse.       |  | • TELL: Glances at your plot     |  | • TELL: Faint red weapon glint  | |
|  | • IF AUDITED: Passes Audit!      |  |   every 45s for 1.2s.            |  |   near Rare/Mythic Relics.      | |
|  |   Renter wastes 50 Gold.         |  | • IF AUDITED: 5m Coma + Fined    |  | • IF AUDITED: 5m Coma + Fined   | |
|  |                                  |  |   2x Siphoned Gems!              |  |   2x Rental Gold Fee & -15 Hon! | |
|  +----------------------------------+  +----------------------------------+  +---------------------------------+ |
|                                                                                                                  |
|                                [📌 POST MERCENARY LISTING FOR 2,500 GOLD 📌]                                     |
+------------------------------------------------------------------------------------------------------------------+
```

### 4.2 View B — Public Mercenary Noticeboard (What Renters See)

```text
+------------------------------------------------------------------------------------------------------------------+
|  ⚔️ SERVER MERCENARY NOTICEBOARD — RENT A HERO FOR 10 MINUTES                                     [X CLOSE]      |
+------------------------------------------------------------------------------------------------------------------+
|  OWNER & REPUTATION            HERO & STATS                         ROLE / SYNERGY         RENTAL FEE   ACTION   |
|  --------------------------------------------------------------------------------------------------------------  |
|  @SaintlyGrace                 [Aaron 3★ Lv.25]                     Vanguard / Infirmary   1,800 Gold   [RENT]   |
|  [★ SYNDICATE SAINT (+65)]     HP: 2,150 | DPS: 240 | Lab: 52/m     (+25% Healer Synergy)  (10m Term)            |
|  --------------------------------------------------------------------------------------------------------------  |
|  @CunningFox                   [Eolka 3★ Lv.22]                     Scholar / Dim. Lab     2,500 Gold   [RENT]   |
|  [• NEUTRAL MASTER (+10)]      HP: 1,420 | DPS: 295 | Lab: 58/m     (+25% Lab Synergy)     (10m Term)            |
|  --------------------------------------------------------------------------------------------------------------  |
|  @DarkBetrayer                 [Velkist 4★ Lv.15]                   Striker / Conduit      1,200 Gold   [RENT]   |
|  [💀 ROGUE MASTER (-45)]       HP: 2,890 | DPS: 510 | Lab: 74/m     (Suspiciously Cheap!)  (10m Term)            |
+------------------------------------------------------------------------------------------------------------------+
```

### 4.3 View C — `Audit Soul (50 Gold)` Inspection & Reveal Popup
At any point during the 10-minute rental, the Renter can click **`[🔍 AUDIT SOUL (50G)]`** on their HUD Mercenary tracker (or directly on the rented hero in their plot). A 1.5-second arcane eye scan sweeps over the hero, followed by one of two high-impact reveal modals:

```text
+-------------------------------------------------------+  +-------------------------------------------------------+
|          ✨ SOUL AUDIT RESULT: PURE SOUL ✨           |  |       🚨 SOUL AUDIT RESULT: TRAITOR EXPOSED! 🚨       |
|-------------------------------------------------------|  |-------------------------------------------------------|
|  Mercenary: [Aaron 3★] (Owner: @SaintlyGrace)         |  |  Mercenary: [Eolka 3★] (Owner: @CunningFox)           |
|  Hidden Directive Revealed: [LOYAL CONTRACT (110%)]   |  |  Hidden Directive Revealed: [PARASITE SIPHON (-30%)]  |
|                                                       |  |                                                       |
|  • Audit Cost Paid: -50 Gold                          |  |  • Traitor Banished to Owner's Infirmary (5m COMA!)   |
|  • This Mercenary is 100% loyal and gains +5% Bonus   |  |  • Siphoned Gems Recovered: +90 Gems                  |
|    Morale Output for the remainder of your contract!  |  |  • 2x Punitive Fine Seized from @CunningFox: +90 Gems |
|                                                       |  |  • TOTAL PAYOUT CREDITED TO YOU: +180 GEMS!           |
|                     [ CONTINUE ]                      |  |                   [ CLAIM BOUNTY ]                    |
+-------------------------------------------------------+  +-------------------------------------------------------+
```

---

## 5. WORLD SPACE BILLBOARDS & VISUAL TELLS

All world-space UI elements and diegetic tells are rendered client-side (`StarterPlayerScripts/Rendering/`) to preserve zero server-side Humanoid/UI overhead.

### 5.1 World-Space Billboard & VFX Specifications Table

| World-Space Element | Roblox Instance & Attachment | Stud Size & `MaxDistance` | `AlwaysOnTop` / Occlusion Rule | Visual Layout, Colors & Animation Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **1. Syndicate Saint Badge** (`Honor >= +50`) | `BillboardGui` on `Character.Head` (`StudsOffset = (0, 3.2, 0)`) + 3D Neon Halo Ring | `Size: 6.0 x 1.6 studs`<br>`MaxDistance: 140 studs` | `AlwaysOnTop = false` (Occluded by walls) | Gold-and-white crest (`#FFD700`), rotating 3D halo ring above head, subtext: `"★ SYNDICATE SAINT (+10% Visitor Blessing Bonus)"`. |
| **2. Rogue Master Bounty Skull** (`Honor <= -30` or `5m` Betrayal) | `BillboardGui` on `Character.Head` (`StudsOffset = (0, 3.8, 0)`) + Red `Highlight` outline | `Size: 7.5 x 2.2 studs`<br>`MaxDistance: 280 studs` | **`AlwaysOnTop = true`** when Rogue is inside **Ring 1 or Ring 2** (`False` on Private Plot) | Pulsing Crimson Skull (`#FF1E38`), countdown timer (`04:12`), and live Bounty Readout: `"💀 ROGUE BOUNTY: ~2,130 GOLD (CLICK SQUAD TO ATTACK)"`. |
| **3. Physical Relic Billboard** (Ground & Welded Overhead) | `BillboardGui` on `RelicPart` (`StudsOffset = (0, 3.5, 0)`) | `Size: 6.5 x 2.4 studs`<br>`MaxDistance: 220 studs` | **`AlwaysOnTop = true`** for **Calamity Heart** & **Abyssal Core** | • Top Row: Rarity & Name (`THE CALAMITY HEART`).<br>• Mid Row: **Lock Timer** (`🔒 RANK #1 LOCK: 11.4s` or `🔒 FUMBLE LOCK: 2.1s` in Amber `#FFAA00`; turns Green `🔓 STEALABLE NOW!` at `0.0s`).<br>• Bottom Row: Despawn Bar (`02:45`) + Penalty (`-45% SPD`). |
| **4. Blood Pact Tether Beam** | `Beam` between Carrier `HRP.RootAttachment` and Partner `HRP.RootAttachment` | `Width0/1: 0.45 studs`<br>Visible up to `35 studs` | Render in 3D world space | • **Distance `<= 15 studs` (Tandem Carry Active):** Bright Cyan-Gold (`#00F5D4`) flowing energy; halves Relic WalkSpeed penalty.<br>• **Distance `15..35 studs`:** Amber (`#FFB703`) thin line.<br>• **On `[B] Shatter Pact`:** Turns jagged Crimson (`#FF0033`) and snaps with an explosion VFX. |
| **5. Parasite Mercenary 45s Glance Tell** | Client `Motor6D.Transform` Neck IK + `ParticleEmitter` on Rented Mercenary Rig | `0 BillboardGui` *(Purely visual tell for observant players)* | 3D Rig Animation (`MaxDistance: 65 studs`) | **Every `45.0 seconds`:** The rented Mercenary pauses its work animation for **`1.2 seconds`**, rotates its `Head` `Motor6D` directly toward the **Owner's Plot**, and tucks a tiny purple mana orb into its cloak pocket (`3` faint purple sparkles). |
| **6. Saboteur Mercenary Glint Tell** | `Highlight` + Weapon `Attachment` glint on Rented Mercenary Rig | `MaxDistance: 50 studs` | 3D Rig VFX | When an uncollected **Cursed Urn**, **Abyssal Core**, or **Calamity Heart** is within `20 studs`, the Saboteur's weapon emits a `0.4s` crimson metallic glint + low blade-draw sound. |
| **7. Espionage Channel (`Bless` vs. `Leech`)** | `ProximityPrompt` (`HoldDuration = 2.0s`) + Floor Rune Decal on Facility | `MaxDistance: 45 studs` | 3D Animation + Floor Decal | Both **Bless (+25%)** and **Plant Leech Rune (-20%)** play the **exact same `2.0s` kneeling prayer animation** and leave an identical neutral-violet runic circle on the facility floor for `15.0s` (until the Purge window expires). |
| **8. Mimic Chest Illusion States** | Client `ManaConduit.GemChest` Mesh/Particle Controller | `MaxDistance: 120 studs` | 3D Prop Swap | • **Fool's Gold:** Renders overflowing high-poly Gem meshes & golden sparkles even when `UncollectedOutput < 20`; snaps jaws shut if leeched.<br>• **Veil of Poverty:** Hides Gem meshes and renders cobwebs even when chest is 100% full. |

### 5.2 ASCII Diagram of World-Space Billboards & The 45s Parasite Tell

```text
   [A] ROGUE MASTER IN RING 2                      [B] PHYSICAL RELIC (FUMBLE LOCK)
  +----------------------------+                  +--------------------------------+
  |   💀 ROGUE MASTER (03:48)  |                  |   🏺 CURSED URN (RARE RELIC)   |
  |     @DarkBetrayer [-45]    |                  |  [🔒 FUMBLE LOCK: 02.1s LEFT]  |
  |  BOUNTY: ~2,130 GOLD DROP  |                  |  Despawn: [████████░░ 01:38]   |
  +----------------------------+                  |  Carry Penalty: -25% WalkSpeed |
                ||                                +--------------------------------+
             \  ||  /                                             ||
              [Avatar]                                        [Urn Mesh]


   [C] THE 45-SECOND PARASITE MERCENARY GLANCE TELL (NO UI ICON — SKILL OBSERVATION)
  +--------------------------------------------------------------------------------+
  |  Normal (0s - 43.8s):                Every 45.0s (For 1.2s Duration):          |
  |                                                                                |
  |       [Mercenary]                         [Mercenary]  --> (Head turns toward  |
  |      /  |     |  \                       /  |     |  \      Owner's Plot #4!)  |
  |     Chopping Mana Crystal               Pauses work & tucks purple spark       |
  |     at Renter's Conduit                 into pocket -> Renter clicks           |
  |     (Looks 100% Normal)                 [🔍 AUDIT SOUL (50G)] to catch & fine! |
  +--------------------------------------------------------------------------------+
```
