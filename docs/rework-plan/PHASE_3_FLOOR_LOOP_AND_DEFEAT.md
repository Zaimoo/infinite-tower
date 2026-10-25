# Phase 3: Tower Floor Loop, Per-Player Progress & Defeat Flow

**Document Version:** 1.0  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phase 1 & 2 complete  

---

## 1. Objectives & Scope

Phase 3 implements the core progression loop of the Infinite Tower:
1. **Globally Shared Tower Floors:** Players share the same floor world space.
2. **Per-Player Kill Progress Bar:** Each player tracks their individual kill quota to summon the floor boss.
3. **Boss Gating & Shared Full-Copy Loot:** Slaying the boss unlocks the next floor; all participants with $\ge 3\%$ damage receive full reward copies.
4. **Fast Defeat Flow:** Complete removal of the 60s coma; dead heroes stay down mid-run; squad wipes teleport immediately back to the plot with full HP restoration and a Defeat Modal.

---

## 2. Shared Tower Architecture & Per-Player Tracking

### 2.1 Server Floor Service (`TowerFloorService.luau`)
- **Shared Floor Instance:** Each floor (1–50) runs as a single server-authoritative simulation space for all players visiting that floor on the server.
- **Per-Player State Table:**
  ```luau
  type PlayerFloorProgress = {
      FloorId: number,
      Kills: number,
      TargetKills: number,
      BossActive: boolean,
      BossEntityNetId: number?,
  }
  local PlayerProgress: { [Player]: PlayerFloorProgress } = {}
  ```
- **Kill Target Calculation:**
  $$\text{TargetKills}(\text{floor}) = \text{round}(12 + 0.5 \times \text{floor})$$
  - Floor 1: 12 kills
  - Floor 10: 17 kills
  - Floor 25: 25 kills
  - Floor 50: 37 kills
- **Progress Contribution:**
  - Standard Mob killed by squad: $+1$ Progress
  - Elite Mob killed by squad: $+2$ Progress
- **Network Replication:**
  - Reliable RemoteEvent: `FloorRemotes/ProgressSync(kills: number, target: number, bossActive: boolean, bossHealthPct: number?)`

---

## 3. Boss Summoning & Progression Gate

### 3.1 Summoning Flow
1. When a player's `Kills >= TargetKills`:
   - `BossActive` becomes `true`.
   - The player's Floor Progress Bar on the client flashes and transforms into the **Boss Health Bar**.
   - The Floor Boss spawns in the floor's central arena chamber with a dynamic ground seal telegraph.
2. **Boss Engagement:**
   - The summoning player's squad automatically targets the Boss.
   - Other players on the floor can see and choose to assist in damaging the Boss.

### 3.2 Clear Condition & Full-Copy Rewards
- Upon the Boss reaching 0 HP:
  - **Damage Ledger Evaluation:** Any player on the floor who contributed $\ge 3.0\%$ of total boss damage receives:
    1. **Floor Clear Credit:** `profile.HighestClearedFloor = math.max(profile.HighestClearedFloor, floorId)`.
    2. **Full Copies of Boss Rewards:** Guaranteed Gold, Gems, and gear roll added directly to their profile inventory.
    3. **Uncontestable Status:** Boss drops are credited directly or banked safely—they cannot be stolen or contested.
  - A celebratory **Victory Modal** appears on the client displaying stats, rewards, and a **[Proceed to Floor N+1]** shortcut.

---

## 4. Death & Defeat Architecture

### 4.1 Mid-Run Death Rules
- When an individual hero reaches 0 HP:
  - Plays dramatic collapse animation.
  - Collides are disabled; hero remains down on the floor for the remainder of the run.
  - Client HUD hero portrait greys out with a red skull icon.
  - **No Revive Mid-Run:** The debilitating 60s hospital timer and mid-combat revives are abolished. The remaining living heroes continue fighting.

### 4.2 Squad Wipe Flow (All 5 Heroes Down)
If the last living hero in the player's squad dies:
1. **Server Intervention (`CombatSimulation.server.luau`):**
   - Encounter immediately stops for that player.
   - Any carried unbanked physical cargo on that floor drops at the squad's death location.
   - Server resets the player's `Kills` on that floor to 0.
   - Master and squad are teleported back to the player's private Fortress Plot spawn pad.
2. **Instant Plot Restoration:**
   - All 5 heroes are instantly healed to 100% HP upon arrival at the Plot.
   - Zero medical wait times, zero hospital cooldowns.
3. **Defeat Modal (`DefeatModal.luau`):**
   - Renders a clean gothic defeat screen:
     - Floor reached and kill progress before wipe.
     - Confirmation that banked currencies and inventory are 100% safe.
     - One-click **[Retry Floor]** button (teleports back to floor start).
     - One-click **[Upgrade Squad]** button (opens Forge / Pit).

---

## 5. Client UI Components

### 5.1 Floor Progress & Boss Bar (`FloorProgressBar.luau`)
Create `src/StarterPlayerScripts/UI/Next/Components/HUD/FloorProgressBar.luau`:
- Anchored at top-center (`UDim2.new(0.5, 0, 0, 16)`).
- **Normal State:**
  - Gothic border frame with obsidian fill.
  - Header: `FLOOR 1: OVERGROWN THRESHOLD`.
  - Progress fill bar: Crimson red fill displaying `Kills: 7 / 12`.
  - Right-side icon: Locked Boss Crest that pulses as progress approaches 100%.
- **Boss State:**
  - Bar smoothly transitions into a double-layered Boss Health Bar.
  - Header: Boss Name in bold gold text (e.g., `MOSS COLOSSUS`).
  - Real-time HP percentage and segment notches.

### 5.2 Defeat Modal (`DefeatModal.luau`)
Create `src/StarterPlayerScripts/UI/Next/Components/Modals/DefeatModal.luau`:
- Modal dialog with dark gothic vignette backdrop.
- Text: *"YOUR SQUAD HAS FALLEN"*.
- Quick action buttons with prominent touch and controller focus.

---

## 6. Verification & Testing

1. **Kill Bar Progression:**
   - Slay 12 mobs on Floor 1; verify ProgressSync increments after each kill.
   - On 12th kill, verify boss spawns and bar switches to Boss Health Bar.
2. **Clear & Next Floor Gate:**
   - Slay boss; verify `profile.HighestClearedFloor` updates from 0 to 1.
   - Verify Floor 2 unlocks in the Tower navigation selector.
3. **Multiplayer Boss Scaling & Full Copies:**
   - Spawn 2 clients; both deal $\ge 3\%$ damage to boss.
   - Verify both clients receive full copies of the clear reward and floor progression without splits.
4. **Squad Wipe Teleport & Full Heal:**
   - Force squad HP to 0; verify instant teleportation to Plot spawn.
   - Verify all 5 heroes have 100% HP immediately upon arrival.
   - Verify Defeat modal appears with working Retry and Upgrade buttons.
