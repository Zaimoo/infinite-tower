# Phase 2: Floor Loop, Progression Backend, Boss Spawning & Defeat Flow

**Document Version:** 2.0  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phase 1 complete  

---

## 1. Objectives & Scope

Phase 2 implements the complete tower floor game loop:
1. **Per-Player Kill Progression:** Each player tracks their own kill progress bar in the globally shared tower floor. Slaying required mobs spawns their individual Floor Boss.
2. **Boss Gate & Shared Loot:** Slaying the boss unlocks the next floor for that player. Boss loot is uncontestable and provides full copies to any player dealing $\ge 3\%$ damage.
3. **Defeat Flow & Hard Death Rules:** Dead heroes remain down for the rest of the floor (no mid-run revives). If all 5 heroes die (squad wipe), the squad immediately teleports to the Fortress Plot, restores full HP on arrival, and preserves all banked loot.

---

## 2. Shared Multi-Player Floor Architecture

### 2.1 Capacity & Floor Isolation
- Each floor instance supports up to **6 concurrent players** sharing the same room geometry.
- Room origins and bounds are managed by `TowerFloorService.luau`.
- Mobs spawned for one player can be engaged by others, but kill credit and progress attribute strictly to the contributing squad.

---

## 3. Per-Player Kill Progress & Boss Gate

### 3.1 Server State (`CombatSimulation.server.luau` / `TowerFloorService.luau`)
Track each player's floor session state:
```luau
export type PlayerFloorProgress = {
    FloorId: number,
    CurrentKills: number,
    RequiredKills: number,         -- e.g. 15 for Floor 1, scaling with floor level
    BossSpawned: boolean,
    BossNetId: number?,
    BossDefeated: boolean,
}
```

### 3.2 Kill Accounting & Boss Summoning
- Standard mob kill = **+1 Progress**.
- Elite mob kill = **+2 Progress**.
- When `CurrentKills >= RequiredKills`:
  - `BossSpawned = true`.
  - The server spawns the player's Floor Boss in the arena center.
  - Replicates boss presence via `TowerRemotes.TowerAction` / `BossPresentation`.

### 3.3 Boss Victory & Floor Unlock
- When the boss dies:
  - If the player dealt damage:
    - Unlock next floor: `profile.MaxFloorReached = math.max(profile.MaxFloorReached, currentFloor + 1)`.
    - Report milestone to progression engine.
  - Distribute **uncontestable boss loot** (full copies to anyone with $\ge 3\%$ damage).

---

## 4. Defeat Rules & Squad Wipe Flow

### 4.1 No Mid-Run Revives
- Heroes that reach `CurrentHP <= 0` enter `State = "COMA"`.
- Comatose heroes cannot attack, move, or be targeted.
- Comatose heroes do not revive until the squad returns to the Fortress Plot.

### 4.2 Squad Wipe Trigger
- On each hero death, evaluate `masterState.DeployedHeroes`.
- If **all 5 heroes are in COMA**:
  - Set `masterState.IsSquadWiped = true`.
  - Trigger immediate Defeat flow:
    1. Drop unbanked carried floor loot at the defeat location.
    2. Teleport player and squad back to their Fortress Plot (`PlotManager.TeleportPlayerToPlot`).
    3. Fire client defeat notification `TowerRemotes.SquadDefeated:FireClient(player)`.
    4. On plot arrival, fully restore HP to all heroes (`hero.CurrentHP = hero.MaxHP`, clear `COMA`).
    5. Banked currencies, items, and inventory are 100% safe.

---

## 5. Verification & Acceptance Criteria

1. **Automated Floor Loop Test (`tests/phase2-floor-loop.luau`):**
   - Verify kill increments progress from 0 to target.
   - Verify reaching kill target spawns boss.
   - Verify slaying boss unlocks next floor and delivers full reward copies.
2. **Automated Defeat Rule Test (`tests/phase2-defeat-rules.luau`):**
   - Kill 1 to 4 heroes: verify remaining heroes continue fighting.
   - Kill 5th hero: verify wipe trigger fires, teleport to plot occurs, and full HP is restored on arrival.
