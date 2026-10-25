# Phase 2: Combat Pacing, Fast-Paced Action & Spectacle

**Document Version:** 1.0  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phase 1 complete  

---

## 1. Objectives & Scope

Phase 2 transforms the moment-to-moment combat feel from a sluggish, detached server simulation into a **fast-paced, punchy 3D auto-battler**. We eliminate dead time between waves, accelerate attack and skill cadences, synchronize damage resolution with animation hit frames, add juicy visual feedback, and completely remove legacy Q/E whistle mechanics.

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

## 4. Audio/Visual Combat Juice & Spectacle

### 4.1 Client Feedback Service: `CombatFeedback.client.luau`
Create `src/StarterPlayerScripts/Rendering/CombatFeedback.client.luau` dedicated to client-side visual juice:
- **Object Pooling:** Pre-allocates 50 damage popup billboard labels and 30 hit flash effects to avoid runtime GC spikes on mobile.
- **Floating Damage Numbers:**
  - Standard Hits: White text, pops upward and fades over 0.6s.
  - Critical Hits: Large yellow-orange text with bold stroke, scales up ($1.3\times$) with spring pop.
  - Elemental / Skill Hits: Cyan / Purple tinted text based on hero weapon class.
  - Healing Numbers: Emerald green text with upward float.
- **Hit Flash & Micro Hit-Stop:**
  - On receiving damage, enemy meshes flash bright white (`ColorCorrection` or temporary `Highlight`) for 0.08s.
  - Critical hits introduce a 2-frame (0.033s) animation pause (hit-stop) on the attacking hero.
- **Camera Impulse:**
  - Boss ground slams and hero ultimates trigger procedural camera micro-shakes using `CFrame` noise offsets ($0.15\text{s}$ decay).

### 4.2 Auto-Cast Abilities & Ultimate Spectacle
- Heroes accumulate their Skill/Stamina Gauge (0 to 100) through combat actions.
- At 100 Gauge:
  - Hero triggers their **Signature Ultimate** automatically without requiring player button taps.
  - Visual burst: Hero briefly plays a golden aura flash, emits custom particle trail, and unleashes signature skill.
  - Boss health bar reflects the burst damage chunk immediately.

---

## 5. Verification & Testing

1. **Simulation Cadence Verification:**
   - Log hit event timestamps against animation keyframes; verify synchronization error is $< 50\text{ms}$.
2. **Mob Streaming Verification:**
   - Deploy squad into Tower Floor 1; kill 10 consecutive mobs; verify active mob count stays between 6 and 8 without dead periods.
3. **Performance Profiling:**
   - Measure client FPS on simulated mobile device with 8 mobs and 5 heroes fighting simultaneously.
   - MicroProfiler check: verify garbage collection spikes are zero due to object pooling.
4. **Whistle Verification:**
   - Press `[Q]` and `[E]`; verify zero network events or errors fired.
