# Phase 3: Tower PvP & Contested Drop Retaliation

**Document Version:** 2.0  
**Phase Status:** Implemented (see GAME_DESIGN.MD §6.1)  
**Prerequisites:** Phase 2 complete  

---

## 1. Objectives & Scope

Phase 3 introduces emergent, low-stakes multiplayer friction in shared tower floors:
1. **Contested Regular Mob Drops:** Slaying regular mobs drops physical loot attributed to the killer.
2. **Loot Theft & Flagging:** Another player can pick up the dropped item, immediately flagging them as a `[Loot Thief]`.
3. **Retaliation Duel:** The victim receives an on-screen prompt to initiate a quick 5v5 squad duel against the thief.
4. **Low-Stakes Resolution:** The duel has **zero death/wipe/teleport consequence**. The loser is merely locked out of that specific contested drop.

---

## 2. Drop Attribution & Theft Rules

### 2.1 Loot Drop Ownership
- Mob death creates an active drop record:
  ```luau
  type ActiveLootDrop = {
      DropId: string,
      ItemType: string,
      Amount: number,
      KillerPlayer: Player,
      KillerUserId: number,
      Position: Vector3,
      FloorId: number,
      ContestedBy: Player?,
      Status: "UNCLAIMED" | "PICKED_UP" | "CONTESTED" | "BANKED",
  }
  ```

### 2.2 Picking Up Another Player's Loot
- If `picker ~= drop.KillerPlayer`:
  - `picker` receives the item into temporary carried status.
  - `picker` gains the `[Loot Thief]` flag (3-minute duration or until duel resolution).
  - The server fires `TowerRemotes.LootContested:FireClient(victim, thief, dropId)`.

---

## 3. Retaliation Duel Flow

### 3.1 Invitation & Acceptance
- Victim can press prompt or send remote intent `TowerRemotes.InitiateRetaliation:FireServer(dropId)`.
- Thief receives challenge notice. Both squads enter a temporary duel engagement zone.

### 3.2 Duel Mechanics
- Squads fight on a floating hex-grid arena, lined up melee-front / ranged-back, viewed from a fixed high-angle camera behind each player's own squad.
- Both squads battle in an isolated sparring state using their deployed 5-hero teams.
- Tower mob aggression is suppressed during the duel.
- **Victory Condition:** Slaying all 5 opposing heroes.

### 3.3 Zero-Consequence Payout
- **If Victim Wins:**
  - Carried drop transfers directly to the victim.
  - Thief is locked out of the drop for its lifetime, exactly as a losing victim is.
  - Thief's `[Loot Thief]` flag is cleared.
  - Thief experiences NO wipe, NO loss of other inventory, and NO teleport.
- **If Thief Wins:**
  - Thief retains the contested drop.
  - Victim is locked out of reclaiming that drop, and the thief becomes its owner.
  - Victim experiences NO wipe, NO loss of banked currencies, and NO teleport.
- All heroes on both sides return to their pre-duel health upon duel conclusion.

---

## 4. Verification & Acceptance Criteria

1. **Automated PvP Attribution Test (`tests/phase3-pvp-duels.luau`):**
   - Verify killer picking up drop incurs 0 thief flags.
   - Verify non-killer pickup sets `[Loot Thief]` flag and triggers victim notification.
   - Simulate duel resolution: verify winner receives item, loser is locked out of drop only, and neither player loses banked loot or gets teleported.
