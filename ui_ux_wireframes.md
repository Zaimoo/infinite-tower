# DOCUMENT 4: UI/UX WIREFRAME SPECIFICATIONS & INTERACTION FLOWS
**Project Codename:** *Project: Waiting Room*  
**Target Devices:** PC (Keyboard/Mouse), Mobile/Tablet (Touch), Console (Gamepad)  
**UI Architecture:** Roblox `ScreenGui` (`IgnoreGuiInset = true`, responsive `UIScale` 1080p baseline) + Gothic Box Containers + World-Space `BillboardGui`, `Beam`, and `Highlight` instances.

---

## 0. SAVED UI TEXT BOX & CONTAINER DESIGN (`GothicBoxStyle`)

Saved in [`ReplicatedStorage/Shared/Util/GothicBoxStyle.luau`](file:///D:/Programming%20shi/infinite-tower/src/ReplicatedStorage/Shared/Util/GothicBoxStyle.luau) and applied in [`StarterPlayerScripts/UI/HUDController.client.luau`](file:///D:/Programming%20shi/infinite-tower/src/StarterPlayerScripts/UI/HUDController.client.luau):

- **Interior Surface:** Deep obsidian-violet glossy background (`#0D0912` $\rightarrow$ `#261C32` $\rightarrow$ `#0D0912` at a `128°` diagonal `UIGradient` sheen).
- **Outer Frame & Glow:** Crisp white-silver border (`#F6F4FF`, `1.5px–2px`) surrounded by a soft lavender-white outer glow (`#DED0FF`, `Transparency = 0.62`).
- **Double Inner Horizontal Trim Lines:** Inset parallel top and bottom trim lines (`#706484` outer line and `#443A54` inner line).
- **Ornate 4-Corner Gothic Filigree Crests:** White corner wings with stepped gothic spurs and a `45°` rotated white diamond crest containing a dark-violet diamond cutout (`#1A0F26`).
- **Bottom-Left Currency Placement:** Top bar is removed; `CurrencyCluster` (`GoldPill` and `GemsPill`) uses the compact Gothic Box Design and is anchored at the bottom-left (`Position = UDim2.new(0, 14, 1, -64)`, `AnchorPoint = Vector2.new(0, 1)`) directly above the **PATCH NOTES** button.

---

## 1. MAIN MASTER HUD (`MasterHUDScreenGui`)

The Main Master HUD is designed around **"Eyes-on-the-Arena" tactical command**. All critical combat telemetry (World Boss *Devouring Nova* telegraphs, Squad Stamina bars, Whistle cooldowns, and contested loot alerts) sit in the peripheral bands so the center `70%` of the viewport remains unobstructed for clicking targets, dodging AoEs, and spotting physical drops.

### 1.1 Full-Screen Master HUD ASCII Wireframe

```text
+------------------------------------------------------------------------------------------------------------------+
|                         [!] WORLD BOSS: THE DIMENSIONAL SOVEREIGN — SPAWNS IN 02:45 [!]                          |
|                         [====== DEVOURING NOVA IN: 04.2s (GET TO OUTER RIM + PRESS [E]!) ======]                 |
+------------------------------------------------------------------------------------------------------------------+
|                                                                                 +------------------------------+ |
|  [🚨 LOOT STOLEN BY @DarkRaider!]                                               | WORLD BOSS LIVE DPS (RING 3) | |
|  • Cargo: 450 Gold, 2x Mana Geodes                                              |------------------------------| |
|  • Grudge Active: 02:48 Remaining                                               | #1 @WhaleKing     41.2% [♛]  | |
|  [ ⚔️ RETALIATE (DISPATCH SQUAD) ]                                              | #2 @You           24.8% [✓]  | |
|                                                                                 | #3 @VortexMaster  16.4% [✓]  | |
|                                                                                 | #4 @ShadowF2P      9.1% [✓]  | |
|                                                                                 | #5 @CasualBob      5.3% [✓]  | |
|                                                                                 | #6 @NewbieDan      1.8% [X]  | |
|                                                                                 |   (Min 3.0% Req. for Loot!)  | |
|                                    ( CENTER VIEWPORT: ARENA )                   +------------------------------+ |
|                                                                                 | BOSS PITY METER: [████░░ 40%]| |
|                                 [Click / Tap] Mob, Boss, or Thief               +------------------------------+ |
|                                      to Focus Squad Aggro                                                        |
|                                                                                                                  |
|                                    +---------------------------------------+                                     |
|                                    |  [📦 CARRYING: 250 GOLD, 40 GEMS]     |                                     |
|                                    |  WalkSpeed: -15% | Drop: Keybind [R]  |                                     |
|                                    |  Bank at Perimeter or Plot Pad        |                                     |
|                                    +---------------------------------------+                                     |
|                                                                                                                  |
|  +------------+  +------------+  +------------+  +------------+  +------------+     +-----------+  +-----------+ |
|  | 1. Han 3★  |  | 2. Jenna 2★|  | 3. Aaron 2★|  | 4. Eolka 3★|  | 5. [COMA!] |     |    [Q]    |  |    [E]    | |
|  | HP [██████]|  | HP [██████]|  | HP [████░░]|  | HP [██████]|  | IN INFIRM. |     | OVERDRIVE |  |  RECALL   | |
|  | ST [████░░]|  | ST [█████░]|  | ST [██░░░░]|  | ST [████░░]|  | 00:42 Left |     | +40% ASPD |  | DODGE AoE | |
|  | [ATTACKING]|  | [ATTACKING]|  | [LOW STAM!]|  | [ATTACKING]|  | (0 DPS)    |     | (-5 STAM) |  | (2s Drop) | |
|  +------------+  +------------+  +------------+  +------------+  +------------+     +-----------+  +-----------+ |
|                                                                                                                  |
| +------------------------------------+                                                                           |
| | 🪙 14,250 GOLD     💎 1,450 GEMS   |  (Gothic Currency Box, Bottom-Left)                                       |
| +------------------------------------+                                                                           |
| +--------------------------------------------------------------------------------------------------------------+ |
| | [PATCH NOTES]  |  [⚔️ Focus] [⚡ Overdrive] [🛡️ Recall] [🪣 Collect Gems] [⚒️ Forge]  |  [PLOT TP]  [SETTINGS] | |
| +--------------------------------------------------------------------------------------------------------------+ |
+------------------------------------------------------------------------------------------------------------------+
```

### 1.2 Component Hierarchy (`StarterGui.MasterHUDScreenGui`)

```text
MasterHUDScreenGui (ScreenGui - ResetOnSpawn: false, IgnoreGuiInset: true)
├── UIScale_Responsive (UIScale - Responsive scaling across desktop, mobile, and tablet)
│
├── BottomLeftCurrencyCluster (Frame - AnchorPoint: 0, 1 | Pos: 0, 14, 1, -64 | Size: 258, 44)
│   ├── GoldPill (Frame with GothicBoxStyle) -> GoldIcon, GoldAmountLabel ("14,250")
│   └── GemsPill (Frame with GothicBoxStyle) -> GemsIcon, GemsAmountLabel ("1,450")
│
├── BottomToolbar (Frame with GothicBoxStyle - AnchorPoint: 0.5, 1 | Pos: 0.5, 0, 1, -6 | Size: 1, -24, 0, 50)
│   ├── LeftGroup -> PatchNotesButton ("PATCH NOTES")
│   ├── CenterToolbarGroup (Frame - Horizontal UIListLayout)
│   │   ├── Whistle_Q_Button ([Q] Overdrive, 20s cooldown radial overlay)
│   │   ├── Whistle_E_Button ([E] Recall, 6s cooldown radial overlay)
│   │   ├── Tool_Blacksmith (Quick-open Blacksmith Forge modal)
│   │   └── Tool_ThePit (Quick-open The Pit synthesis modal)
│   └── RightToolbarGroup -> PlotTeleportButton, SettingsButton
│
├── WorldBossTopBanner (Frame - AnchorPoint: 0.5, 0 | Pos: 0.5, 0, 0, 12)
│   ├── CountdownModeFrame (Visible T-20:00 to T-0:00 in Hub; turns Crimson at T-3:00)
│   ├── TowerFloorBossMode (Active on Tower Floors 5, 10, ..., 50 via _G.ClientCombatState.FloorBoss)
│   │   ├── BossNameAndPhaseLabel ("FLOOR 5 BIOME BOSS — MOSSBOUND GUARDIAN [PHASE 1 / PHASE 2: ENRAGED]")
│   │   └── BossHealthBar (Live HP Permille fill & percentage readout; auto-hides on boss death or floor exit)
│   └── ActiveBossModeFrame (Visible during Ring 3 Sovereign / Rift Boss fight)
│       ├── BossNameAndPhaseLabel ("THE DIMENSIONAL SOVEREIGN — PHASE 2: INSTABILITY")
│       ├── BossHealthBar (Dynamic HP / MaxHP + Tether Shield Overlay)
│       └── DevouringNovaCastBar (Pulses Red during 3.0s Nova Telegraph)
│
├── RetaliationAlertBanner (Frame - AnchorPoint: 0, 0.5 | Pos: 0, 16, 0.35, 0 | Visible on Theft)
│   ├── TheftAlertHeader ("🚨 LOOT STOLEN BY [PLAYER]")
│   ├── StolenCargoSummaryLabel ("450 Gold, 2x Mana Geodes")
│   ├── GrudgeTimerLabel ("Grudge Active: 02:48")
│   └── RetaliateAttackButton ("⚔️ RETALIATE (DISPATCH SQUAD)")
│
├── CarriedCargoPill (Frame - AnchorPoint: 0.5, 1 | Pos: 0.5, 0, 1, -120 | Visible when Carrying)
│   ├── CargoIcon, CargoLabel ("📦 Field: 250 Gold, 40 Gems")
│   └── DropCargoKeybindLabel ("Drop: [R] / Tap Here")
│
├── DeployedSquadStrip (Frame - AnchorPoint: 0.5, 1 | Pos: 0.5, 0, 1, -66)
│   └── SquadSlot_1..5 (Portrait, StarBadge, HPBar, StaminaBar, StateBadge, ComaOverlay)
│
└── RightWorldBossLeaderboard (Frame - AnchorPoint: 1, 0.5 | Pos: 1, -16, 0.45, 0)
    ├── HeaderLabel ("LIVE DAMAGE SCORE")
    ├── PlayerRankList (UIListLayout - Ranks #1 to #6)
    └── BossPityFooter ("+10% Pity for Ranks #4-#6")
```

---

## 2. WAITING ROOM MANAGEMENT UI (`WaitingRoomScreenGui`)

### 2.1 Overview & Architecture
The Waiting Room management experience uses a dual approach:
1. **Interactive 3D ProximityPrompts & Focused Modals (`FacilityController.luau`):** Approaching any station on the plot (Summoning Altar, Infirmary, Blacksmith Forge, Squad Banner) activates a dedicated HUD modal.
2. **Unified Overseer Modal (`WaitingRoomScreenGui`):** Opened via the bottom toolbar or `[F]` menu, providing centralized squad management, facility overview, and roster management.

```text
+------------------------------------------------------------------------------------------------------------------+
|  THE WAITING ROOM — PLOT OVERSEER CONSOLE                                                      [X CLOSE (ESC)]   |
+--------------------------------------------------------+---------------------------------------------------------+
|  LEFT PANE: ACTIVE SQUAD & FACILITIES                  |  RIGHT PANE: HERO ROSTER (24 / 50 CAPACITY)             |
|                                                        |  Sort: [★ Stars v] [Combat DPS] [Labor/m] [Stamina]     |
|  1. DEPLOYED COMBAT SQUAD (Active DPS: 642/s)          |  Filter: [All] [Benched Only] [Exhausted/Coma]          |
|  +---------+ +---------+ +---------+ +---------+ +---+ |  +---------------------------------------------------+  |
|  | 1.Han 3★| |2.Jenna2★| |3.Aaron2★| |4.Eolka3★| |5. | |  | [🔒] [Han 3★ Lv.15]      [🔒] [Eolka 3★ Lv.12]    |  |
|  | ST: 84% | | ST: 92% | | ST: 18% | | ST: 76% | |CAT| |  | DPS: 298 | Lab: 54/m     DPS: 267 | Lab: 62/m     |  |
|  | [BENCH] | | [BENCH] | | [HEAL!] | | [BENCH] | |BEN| |  | Status: [SQUAD SLOT 1]   Status: [SQUAD SLOT 4]   |  |
|  +---------+ +---------+ +---------+ +---------+ +---+ |  +---------------------------------------------------+  |
|  [⚡ AUTO-SWAP EXHAUSTED (<25% STAM) TO INFIRMARY]      |  | [🔓] [Catio 2★ Lv.20]    [🔓] [Catio 1★ Lv.10]    |  |
|  ----------------------------------------------------  |  | DPS: 65  | Lab: 61/m ★   DPS: 39  | Lab: 36/m ★   |  |
|  2. THE INFIRMARY & BARRACKS [Lv.3] — Regen: 11.6 St/s |  | Status: [BENCHED]        Status: [INFIRMARY #1]   |  |
|  Workers: [Aaron 2★ (+25%)] [Healer 2★] [🔒Lv5]        |  +---------------------------------------------------+  |
|  Recuperation Beds (4/4 Unlocked):                     |  | [🔓] [Velkist 2★ Lv.1]   [🔓] [Han 1★ Lv.1] (x9)  |  |
|  • Bed 1: [Velkist 2★] — COMA (00:24s remaining)       |  | DPS: 97  | Lab: 23/m     DPS: 51  | Lab: 17/m     |  |
|  • Bed 2: [Aaron 2★]   — Resting (Stamina: 44% -> 100%)|  | Status: [BENCHED]        Status: [BENCHED]        |  |
|  • Bed 3: [EMPTY BED]  | • Bed 4: [EMPTY BED]          |  | [DEPLOY] [ASSIGN WORK]   [FEED IN PIT] [ASSIGN]   |  |
|  ----------------------------------------------------  |  +---------------------------------------------------+  |
|  3. BLACKSMITH FORGE — Status: Active                  |                                                         |
|  Station: Anvil & Hearth online | Tier: Common -> Orig |  SELECTED HERO QUICK-ACTION BAR:                        |
|  [⚒️ OPEN BLACKSMITH FORGE]                             |  Selected: [Velkist 2★ Lv.1] (Striker | Bloodthirst)    |
|  ----------------------------------------------------  |  -> [Deploy to Squad]  [Send to Infirmary Bed]          |
|  4. WORLD BOSS TRIGGER (Uses 1x Rift Lure)             |  -> [Open in Synthesis Pit]   [Equip Weapon]            |
|  [🌌 SUMMON RIFT WARDEN AT RING 3]                     |                                                         |
+--------------------------------------------------------+---------------------------------------------------------+
```

---

## 3. THE PIT: SYNTHESIS & STAR PROMOTION UI (`SynthesisController.luau`)

### 3.1 Synthesis UI Modal (5 Donor Slots + Level Preview Bar)
Opened from the Pit Cauldron via `[E]` or `[F]` ProximityPrompt, this dedicated modal (`700 x 610` px) provides deterministic EXP feeding with a live level preview bar:

```text
+--------------------------------------------------------------------------------------------------+
|  🔥 HERO SYNTHESIS                                                              [X CLOSE]        |
|  Sacrifice duplicate or spare heroes to level up your core fighters.                             |
+------------------------------------------------+-------------------------------------------------+
|  RECIPIENT HERO                                |  SACRIFICE MATERIALS (UP TO 5 HEROES)           |
|                                                |                                                 |
|  +-------------------------+                   |  +-------+ +-------+ +-------+ +-------+ +----+ |
|  |       [Velkist 2★]      |                   |  |Slot 1 | |Slot 2 | |Slot 3 | |Slot 4 | |S.5 | |
|  |   Striker | Bloodthirst |                   |  |[Han1★]| |[Han1★]| |[Jen1★]| |[Cat1★]| |[+] | |
|  |   Level: 14 / 20        |                   |  | Lv.1  | | Lv.1  | | Lv.1  | | Lv.5  | |    | |
|  +-------------------------+                   |  +-------+ +-------+ +-------+ +-------+ +----+ |
|                                                |                                                 |
|  Level Preview: Lv. 14 ===> Lv. 16!            |  [⚡ AUTO-SELECT 1★ FODDER]     [CLEAR SELECTION] |
|  EXP: [████████████████░░░░] +600 EXP          |  *(Protected: Locked, Deployed, & Working units)|
|                                                |                                                 |
|  PROJECTED STAT BOOST:                         |  TRANSACTION SUMMARY:                           |
|  • Effective HP:  1,010 -> 1,089 (+79 HP)      |  • Donors to Consume: 4 Heroes                  |
|  • Effective ATK:   148 ->   160 (+12 ATK)     |  • Total EXP Gained:  +600 EXP                  |
|  • Combat DPS:    197.3 -> 213.3 (+16.0/s)     |  • Gold Fee:          0 Gold                    |
|                                                |                                                 |
|  +---------------------------------------------------------------------------------------------+ |
|  |                         [🔥 CONFIRM SYNTHESIS (CONSUME 4 HEROES) 🔥]                        | |
|  +---------------------------------------------------------------------------------------------+ |
+--------------------------------------------------------------------------------------------------+
```

---

## 4. THE BLACKSMITH FORGE UI (`BlacksmithModal`)

Opened at the 3D Anvil & Furnace station on each plot, the Blacksmith Forge allows Masters to view equipped weapons and ascend weapon rarity through 16 tiers:

```text
+--------------------------------------------------------------------------------------------------+
|  ⚒️ THE BLACKSMITH FORGE — ARTIFACT REFINEMENT                                  [X CLOSE]        |
|  Ascend weapon rarity to multiply permanent star base stats up to 18.00x. Zero RNG failure.      |
+------------------------------------------------+-------------------------------------------------+
|  EQUIPPED ARTIFACT                             |  RARITY ASCENSION PREVIEW                       |
|                                                |                                                 |
|  +-------------------------------------------+ |  CURRENT TIER:                                  |
|  | 🏹 HUNTER'S SHORTBOW                      | |  [3. RARE] (Cobalt Steel) — Multiplier: 1.35x  |
|  | Star Potential: 1★ (Base: +15 ATK, +5% Spd)| |  • Bonus ATK: +20 ATK                         |
|  | Permitted Class: Marksman (Jenna)         | |  • Bonus Speed: +6.75% Attack Speed           |
|  | Equipped By: [Jenna 2★ Lv.18]             | |                                                 |
|  +-------------------------------------------+ |  NEXT TIER:                                     |
|                                                |  [4. SUPERIOR] (Amethyst Inlay) — Mult: 1.60x   |
|  INVENTORY WEAPONS:                            |  • Bonus ATK: +24 ATK (+4 Increase!)            |
|  +-------------------------------------------+ |  • Bonus Speed: +8.00% Attack Speed (+1.25%!)   |
|  | [✓] Hunter's Shortbow (1★ Rare)           | |                                                 |
|  | [ ] Iron Broadsword   (1★ Common)         | |  FORGE ASCENSION REQUIREMENTS:                |
|  | [ ] Wind-Scout Recurve(2★ Uncommon)       | |  • Gold Fee:  1,500 Gold (Have: 14,250 Gold)  |
|  | [ ] Crystal Greatbow  (3★ Common)         | |  • Gems Fee:  0 Gems     (Have: 1,450 Gems)   |
|  +-------------------------------------------+ |                                                 |
|                                                |  +---------------------------------------------+|
|  [EQUIP TO SELECTED HERO]  [UNEQUIP]           |  |      [⚒️ ASCEND TO SUPERIOR (1,500G) ⚒️]        ||
|                                                |  +---------------------------------------------+|
+------------------------------------------------+-------------------------------------------------+
```

---

## 5. DIEGETIC WORLD-SPACE VISUAL HIERARCHY & TELLS

All world-space visual elements and diegetic indicators are rendered client-side (`StarterPlayerScripts/Rendering/`) with zero server-side Humanoid or UI overhead:

### 5.1 World-Space Billboard & VFX Specifications Table

| World-Space Element | Roblox Instance & Attachment | Stud Size & `MaxDistance` | Occlusion Rule | Visual Layout, Colors & Animation Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **1. Hunter's Shortbow Grip & Dynamic String** | Low-poly stave welded to `LeftHand` + dual `Beam`s to `RightHand.DrawAttachment` | R15 Hero Model | Native 3D Rig | Forward-canted chiseled stave with leather wrap. Dual sinew beams dynamically stretch from stave nocks to drawing hand. |
| **2. Physical Loot Overhead Carry Pose** | `HoldingAnimationController.client.luau` on `Character` | Player Character | Native 3D Rig | When carrying physical cargo, upper arms rotate $152^\circ$ upward into an overhead hauling pose. |
| **3. Blacksmith Forge World Billboard** | `BillboardGui` on `InteractionPart` (`StudsOffset = (0, 3.8, 0)`) | `160 x 42 px`<br>`MaxDistance: 80 studs` | `AlwaysOnTop = false` | Obsidian frame with gold text: `"⚒️ Blacksmith Forge"`. Surrounded by glowing neon coals (`ForgeLight`) and particle sparks. |
| **4. Contested Loot Theft Flag** | `BillboardGui` on `Character.Head` + Crimson `Highlight` | `Size: 7.5 x 2.2 studs`<br>`MaxDistance: 280 studs` | **`AlwaysOnTop = true`** | Displays `"💀 [LOOT THIEF]"` with a countdown timer showing the active retaliation grudge window (180s). |
| **5. Physical Relic World Billboard** | `BillboardGui` on `RelicPart` (`StudsOffset = (0, 3.5, 0)`) | `Size: 6.5 x 2.4 studs`<br>`MaxDistance: 220 studs` | **`AlwaysOnTop = true`** for Calamity Heart | Top row shows relic name; middle row shows ownership lock timer (`🔒 RANK #1 LOCK: 11.4s`); bottom row displays despawn bar. |
| **6. Espionage Channel (`Bless` vs. `Leech`)** | `ProximityPrompt` (`HoldDuration = 2.0s`) + Floor Rune Decal | `MaxDistance: 45 studs` | 3D Animation + Floor Decal | Both **Bless (+25%)** and **Plant Leech Rune (-20%)** play the same kneeling prayer animation and leave an identical violet runic circle for 15.0s. |

---

## 6. INFINITE TOWER FLOOR SELECTOR & NAVIGATION UI (`TowerController.client.luau`)

### 6.1 Top-Right `Return to Hub` Button & Biome-Grouped 50-Floor Selector Wireframe
When visiting any Tower floor (`FloorId >= 1`), a persistent **`Return to Hub`** button appears at the top-right (`UDim2.new(1, -18, 0, 18)`). Interacting with a `Floor Selector` pedestal, the Central Crimson Tower portal prompt, or the bottom toolbar `[TOWER]` button opens the **50-Floor Biome-Grouped Selector Modal**:

```text
                                                                                      +--------------------+
                                                                                      | [ RETURN TO HUB ]  |
                                                                                      +--------------------+
+----------------------------------------------------------------------------------------------------------+
|  INFINITE TOWER — 50 FLOORS (10 BIOMES)                                                      [Close]     |
|  You: Floor 5 | Squad: Floor 5 (5)                                                                       |
+--------------------------------------------------------------------+-------------------------------------+
|  SCROLLABLE 50-FLOOR LIST (GROUPED BY BIOME)                       |  SELECTED FLOOR DETAIL CARD         |
|  +--------------------------------------------------------------+  |  +-------------------------------+  |
|  |  BIOME 1 — VERDANT RUINS (FLOORS 1–5)                        |  |  | Floor 5 — Mossbound Court     |  |
|  +--------------------------------------------------------------+  |  | Biome: Verdant Ruins          |  |
|  | [F1: Overgrown Threshold] [F2: Broken Aqueduct] [F3: Rootway]|  |  | Role: Boss Floor              |  |
|  | [F4: Vinebound Bastion]   [◆ ★ F5: Mossbound Court]          |  |  | Visited: 1 | Squads: 1        |  |
|  +--------------------------------------------------------------+  |  |                               |  |
|  |  BIOME 2 — FUNGAL HOLLOW (FLOORS 6–10)                       |  |  | Status:                       |  |
|  +--------------------------------------------------------------+  |  | You are here | Squad assigned |  |
|  | [F6: Sporelit Entry]      [F7: Mycelium Galleries] ...       |  |  |                               |  |
|  | ...                       [◆ F10: Matriarch's Hollow]        |  |  | +---------------------------+ |  |
|  +--------------------------------------------------------------+  |  | |       [Visit floor]       | |  |
|  |  ... Biomes 3–9 ...                                          |  |  | +---------------------------+ |  |
|  +--------------------------------------------------------------+  |  | |      [Assign squad]       | |  |
|  |  BIOME 10 — ABYSSAL DESCENT (FLOORS 46–50)                   |  |  | +---------------------------+ |  |
|  +--------------------------------------------------------------+  |  | |      [Recall squad]       | |  |
|  | [F46: Abyssal Descent] ... [◆ F50: Overlord's Throne]        |  |  | +---------------------------+ |  |
|  +--------------------------------------------------------------+  |  +-------------------------------+  |
+--------------------------------------------------------------------+-------------------------------------+
```

### 6.2 Floor Button Status Badges
- **`◆`**: Milestone Biome Boss Floor (`Floors 5, 10, 15, 20, 25, 30, 35, 40, 45, 50`).
- **`★`**: Both the Master (`PlayerLocation`) and their deployed squad (`SquadContext`) are on this floor.
- **`●`**: The Master is currently visiting this floor.
- **`▲`**: The Master's deployed squad is stationed on this floor while the Master is elsewhere.
