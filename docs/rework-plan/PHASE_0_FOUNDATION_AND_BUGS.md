# Phase 0: Foundation, Toolchain & Critical P1 Bug Fixes

**Document Version:** 1.0  
**Phase Status:** Completed & Verified (Merged to Main)  
**Prerequisites:** None  

---

## 1. Objectives & Scope

Before introducing new gameplay features, onboarding systems, or UI components, we must ensure the core runtime and simulation are stable and free of blocking defects. Phase 0 eliminates 5 known P1 bugs identified in the systems review and validates the Rokit/Rojo/Wally toolchain.

---

## 2. Toolchain Verification

1. **Rokit Configuration (`rokit.toml`):**
   - Pin `rojo = "rojo-rbx/rojo@7.7.1"`
   - Pin `wally = "UpliftGames/wally@0.3.2"`
2. **Wally Configuration (`wally.toml`):**
   - Package name: `infinite-tower/infinite-tower`
   - Dependencies: `React = "jsdotlua/react@17.2.1"`, `ReactRoblox = "jsdotlua/react-roblox@17.2.1"`
3. **Rojo Mapping (`default.project.json`):**
   - Ensure `ReplicatedStorage.Packages` maps directly to `Packages/`.
   - Run `rojo build -o build.rbxl` and verify 0 errors.

---

## 3. Critical P1 Bug Fixes

### 3.1 Bug 1: Combat Ticks Erasing Equipped Weapon ATK
- **Problem:** When a hero is deployed, `CombatSimulation` calculates initial stats correctly with the equipped weapon. However, inside the 5 Hz tick loop (`CombatSimulation.server.luau` ~line 1562) and in `RefreshPlayerHeroStats` (~line 283), stats are recalculated without looking up the hero's equipped artifact UUID. This drops ATK from 59 back to base 44 after 0.20s, rendering all weapons ineffective.
- **Affected Files:**
  - `src/ServerScriptService/Combat/CombatSimulation.server.luau`
- **Fix:**
  - Standardize stat resolution via `StatFormulas.GetCombatSnapshot(hero, artifact)`.
  - In both periodic refresh and tick loops, consistently resolve `profile.Artifacts[hero.EquippedArtifactUUID]` before computing effective stats.
- **Verification:** An offline test verifying that a hero with a Common 1★ weapon maintains their full attack damage for 100 simulation ticks without regression.

---

### 3.2 Bug 2: Enemy AoE Attacks Hitting Other Tower Floors & Misaligned Warning Heights
- **Problem:** `CombatSimulation` AoE damage routines (e.g. boss slams and elite ground hazards around lines 1392 and 1473) check only 2D X/Z Euclidean distance. Because tower floors stack vertically in the world space, an attack on floor 2 hits heroes on floor 1 or floor 3. Furthermore, telegraph replication omits the Y height, causing `EntityRenderer` to draw danger zones at the wrong elevation.
- **Affected Files:**
  - `src/ServerScriptService/Combat/CombatSimulation.server.luau`
  - `src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau`
- **Fix:**
  - Enforce floor context matching: an AoE can only damage entities sharing the exact same `FloorId`.
  - Include the authoritative Vector3 origin (including Y elevation) in all telegraph network payloads.
  - Reject damage if vertical distance $|\Delta Y| > 15\text{ studs}$.
- **Verification:** Spatial test ensuring an AoE on floor 2 produces 0 damage on entities located at the same X/Z on floor 1.

---

### 3.3 Bug 3: Sixth Player Overwriting Plot 1
- **Problem:** `PlotManager.server.luau` (~line 205) defaults to plot 1 when scanning 5 plots, and assigns plot 1 to a 6th player even when all plots are occupied. When either player leaves, cleanup erases the other player's workers and state.
- **Affected Files:**
  - `src/ServerScriptService/Core/PlotManager.server.luau`
- **Fix:**
  - Explicitly handle plot allocation exhaustion. Return a clean error if no plot is free.
  - Align server `MaxPlayers` to the 5 available fortress plot islands.
- **Verification:** Unit test simulating 6 consecutive player joins; verify player 6 is safely queued or rejected without overwriting plot 1.

---

### 3.4 Bug 4: Avatar Reset Bypassing Physical Cargo Extraction
- **Problem:** `CombatSimulation.server.luau` (~line 1818) keys carried loot by player ID rather than character instance. If a player resets their avatar while hauling cargo, the cargo remains attached in server state to the player ID. When the new avatar spawns at the plot, the proximity banking check completes and awards the loot without requiring physical transport.
- **Affected Files:**
  - `src/ServerScriptService/Combat/CombatSimulation.server.luau`
- **Fix:**
  - Bind cargo state to the specific `Character` model and listen to `Humanoid.Died` / `CharacterRemoving`.
  - If the character dies or is removed, drop the carried cargo at the character's death location in the world.
- **Verification:** Test verifying that calling `Character:BreakJoints()` while carrying cargo drops the loot at the point of death and clears the player's carrier record.

---

### 3.5 Bug 5: Unvalidated Remote Interaction Payouts
- **Problem:** In `SyndicateService.server.luau`, blessing and purge handlers accept completion codes without verifying interaction initiation, proximity, channel time, or owner differentiation. Calling these directly grants unlimited Gems and Gold.
- **Affected Files:**
  - `src/ServerScriptService/ExtractionAndSocial/SyndicateService.server.luau`
- **Fix:**
  - Require server-owned interaction sessions: server records start time and validates elapsed duration.
  - Verify player proximity ($\le 25\text{ studs}$).
  - Reject self-targeting for blessings and purges.
  - Implement a 60-second cooldown per target player.
- **Verification:** Script attempting immediate duplicate remote calls; verify rejection and 0 currency delta.

---

## 4. Verification & Exit Criteria

1. **Automated Suite (`tests/phase0-verification.luau`):**
   - 14/14 automated assertions passing (0 failures) in Roblox Studio Edit mode:
     - `Bug1_GetEquippedArtifact` (PASS)
     - `Bug1_EffectiveStats_WeaponBonusApplied` (PASS)
     - `Bug1_WeaponATK_Preserved_100Ticks` (PASS)
     - `Bug2_AoE_Hits_SameFloor` (PASS)
     - `Bug2_AoE_Rejects_DifferentFloor` (PASS)
     - `Bug2_AoE_Rejects_DeltaY_Over_11` (PASS)
     - `Bug3_6thPlayer_NoOverwritePlot1` (PASS)
     - `Bug3_PlotRealloc_FreedIndex` (PASS)
     - `Bug4_CargoCarried_InitialState` (PASS)
     - `Bug4_DeathDropsCargo` (PASS)
     - `Bug5_Reject_SelfBless` (PASS)
     - `Bug5_ValidTarget_Accepted` (PASS)
     - `Bug5_Cooldown_Enforced_Within60s` (PASS)
     - `Bug5_Cooldown_Expires_After60s` (PASS)
2. **Clean Project Build:**
   - `rojo build -o build.rbxl` verified with 0 errors.
3. **Studio Parity:**
   - Byte-level synchronization verified across all 5 modified scripts in Roblox Studio Edit mode (Place ID 136256010643848).
4. **Git Delivery:**
   - Committed on `feat/phase-0-foundation-and-bugs`, merged cleanly into `main`, and pushed to remote origin.
