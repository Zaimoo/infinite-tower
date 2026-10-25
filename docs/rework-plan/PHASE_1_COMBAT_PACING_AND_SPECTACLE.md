# Phase 1: Combat Pacing, Fast-Paced Action & Spectacle

**Document Version:** 2.0  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phase 0 complete  

---

## 1. Objectives & Scope

Phase 1 transforms the moment-to-moment combat feel from a sluggish, detached server simulation into a **fast-paced, punchy 3D auto-battler**. We eliminate dead time between waves, accelerate attack and skill cadences, synchronize damage resolution with animation hit frames, add juicy visual feedback, and completely remove legacy Q/E whistle mechanics.

---

## 2. Whistle Removal & Control Simplification

### 2.1 Server Cleanup (`CombatSimulation.server.luau`)
- Remove `WhistleCommandRemote` handling.
- Delete `OVERDRIVE_COOLDOWN`, `RECALL_COOLDOWN`, `isOverdrive`, `OVERDRIVE_ATK_SPEED_MULT`.
- Remove `CanRecall`, `CanOverdrive`, `LastOverdriveClock`, `LastRecallClock` from Master state tables.
- Remove Overdrive attack speed multipliers from stat calculations.

### 2.2 Client Cleanup (`MasterController.client.luau`)
- Remove `[Q]` and `[E]` keybind listeners from `UserInputService`.
- Master controls become pure 3D locomotion:
  - Movement: WASD / Thumbstick
  - Sprint: `[LeftShift]` (retained for rapid spatial traversal)
  - Camera: Mouse / Right Thumbstick

---

## 3. Fast-Paced Combat Pacing & Spawning

### 3.1 Dynamic Continuous Mob Streaming
- **Current Limitation:** Tower floors previously spawned only 3 to 9 static enemies per floor. Once cleared, the floor was empty until a floor reload.
- **New Dynamic Streaming Engine (`TowerEncounterRuntime.luau`):**
  - Maintains an active mob density of **6 to 8 enemies per active player** within a 55-stud radius of the squad.
  - When a mob is defeated, a new mob spawns from nearest spawn portals after a 1.0-second delay.
  - Mob composition:
    - 80% Regular Mobs (fast fodder)
    - 20% Elite Mobs (telegraphed mini-bosses, granting double kill progress)
  - Mobs stream continuously until the floor's kill target is satisfied and the Boss spawns.

### 3.2 Time-To-Kill (TTK) Calibration
Preserving the existing mathematical stat curves, we tune encounter tempo to fast-paced standards:
- **Regular Mobs:** TTK = **1.5 to 2.5 seconds** under squad focus.
- **Elite Mobs:** TTK = **6 to 10 seconds** with telegraphed attacks.
- **Floor Bosses:** TTK = **20 to 30 seconds** on-curve (reduced from 45s slog).
  - Boss HP multiplier adjusted from `DPS * 45` to `DPS * 25`.
  - Compensated with faster, dynamic AoE telegraph patterns to maintain excitement without fatigue.

### 3.3 Hit-Frame Damage Synchronization
- **Current Issue:** 5 Hz server heartbeat (0.20s tick) resolves damage on coarse tick boundaries regardless of animation timing, causing attacks to feel desynchronized and clunky.
- **Solution:**
  - Weapon animations emit animation markers: `"Windup"`, `"Hit"`, `"Recovery"`.
  - Server predicts and validates hit-frame timestamps.
  - Damage resolution triggers at the exact `"Hit"` keyframe ($t_{\text{hit}} \approx 0.35\text{s}$ into swing), ensuring visual and auditory synchrony.

---

## 4. Visual Feedback & Combat Juice

### 4.1 Combat Feedback System (`CombatFeedback.luau`)
Enhance existing client-side pooling for hit effects:
1. **Damage Numbers:**
   - Standard Hit: White font with slight float-up and fade.
   - Critical Hit / Special: Yellow/Orange bold font, 1.25x scale with elastic pop.
   - Weak/Resisted: Gray font.
   - Player Hero Damage (incoming): Crimson font with warning flash.
2. **Impact Sparks & Directional Slashes:**
   - Particle emitters oriented along weapon swing planes.
   - Distinct elemental bursts for Scholar and Miner archetypes.
3. **Screen Shake (Micro):**
   - Boss slams and critical strikes trigger subtle camera impulse (magnitude 0.15–0.4 studs, decay 0.2s) via `RunService.RenderStepped`.

---

## 5. Verification & Acceptance Criteria

1. **Automated Combat Tempo Test (`tests/phase1-combat-tempo.luau`):**
   - Run simulation over 1,000 damage events; verify damage timestamps correlate strictly with hit keyframes ($|\Delta t| < 0.05\text{s}$).
   - Verify standard mob TTK falls between 1.5s and 2.5s for standard gear.
   - Verify active mob streaming maintains 6–8 mobs per player continuously.
2. **Zero Whistle Remnants:**
   - Verify pressing `Q` or `E` causes 0 network calls and 0 client log errors.
3. **Studio Playtest:**
   - Engage standard wave in Floor 1; confirm fluid locomotion, punchy damage popups, and uninterrupted mob streaming.
