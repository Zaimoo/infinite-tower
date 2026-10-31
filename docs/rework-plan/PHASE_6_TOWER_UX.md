# Phase 6 UX: Making the Tower Run Felt

**Document Version:** 1.0  
**Status:** Planned (companion to [PHASE_6_TOWER_RUN_LOOP.md](PHASE_6_TOWER_RUN_LOOP.md), plan v2.2)  
**Builds on:** the Phase 5 HUD (seven fixed zones, `Hud/HudApp`, `Components`, `Theme`, `Icons`) and `Shared/Util/ModalAnimator`

---

## 1. Goal

Phase 6 adds systems a player can't see in the code:
- camp waves,
- the climb streak,
- banking risk,
- downed heroes,
- boss lock,
- wipe loss,
- walls,
- Rift Attunement,
- assigned-squad farming.

If the player doesn't notice them, they don't exist. This plan gives each one a **moment**: something that triggers it, feedback the player sees and hears, and a payoff.

At any point in a run, a player should be able to answer five questions from the screen alone, without opening a menu:
1. **How close am I to the boss?**
2. **What am I risking right now?** (carried relic, unbanked earnings, streak)
3. **Who in my squad is still standing?**
4. **Am I strong enough for this floor and the next wall?**
5. **Where do I go next?** (camps, sanctuary, portal)

## 2. Principles

1. **No new permanent HUD zones.** Phase 5 caps the HUD at seven zones that never overlap. New information goes *inside* existing zones (floor bar, squad card, currency bar, power badge) or into short-lived banners, toasts and world-space markers.
2. **World first, UI second.** Show it in the room when you can: a sealed portal, a glowing sanctuary beam, a downed hero's wisp. Players look at the action, not the corners.
3. **Show the risk before the commitment.** Every penalty is announced before it can hit: boss lock on summon, wipe loss in the at-risk chip, squad HP on the portal prompt.
4. **Celebrate gains loudly and losses clearly.** Gains get sound, particles and number tick-ups. Losses get a clear itemised explanation, plus a reminder of what is safe. This keeps rage-quits down (target under 10% of wipes, plan M7).
5. **Mobile first.** Everything works at 375 px wide with touch targets of 44 px or more, inside `CoreUISafeInsets`. Phone layouts drop labels before they drop numbers.
6. **One look, one voice.** Reuse the cartoon-gothic style (`Components.Panel`, Cinzel labels, outlined bars). Copy is short and uses child-friendly words: "Down", "Wiped", "Banked", never "dead".

## 3. The Tower HUD at a Glance

```
+------------------------------------------------------------------+
|              [FLOOR 13 · GLASSWIND RAVINE  ▮▮▮▯▯]                |
|              [=====●======|========  31/36   ]  [🔥 x3 +30%]      |
|              (surge marker at 50%)  (2 Top-Center)               |
|                                                                  |
| (4 Left rail)                                     (5 Right rail) |
|                                                     [OD][RC][TW🔒]|
|                                                                  |
| [Gold 18,240 ][Gems 1,120 ]  [AT RISK ⚠ 2,400 G · 96 💎 · 🏺 Urn] |
| +--------------------------------+               +-------------+ |
| | Catio ⛏ [HP===  ] Fighting      |               | ⚔ 48,200    | |
| | Han   ⚔ [  DOWN  ] next floor   |               | 112% READY  | |
| | Eolka 🔮[HP=====] Fighting      |               | ▲ Wall F15  | |
| +--------------------------------+               +-------------+ |
+------------------------------------------------------------------+
```

| Zone (Phase 5) | Phase 6 additions |
| --- | --- |
| **2 Top-Center:** floor bar | Floor name and difficulty pips, Elite ticks, surge marker, the **streak chip** attached to the right, and boss bar morph with the lock badge |
| **Currency bar** | The **At Risk chip** (unbanked Gold and Gems plus the carried relic) |
| **6 Squad Status Card** | **DOWN** state without a timer, a standing count, the revive preview, and the "Farming" state for assigned squads |
| **7 Squad Power badge** | **% READY** against the current floor, the next wall, and the **Attuned** marker |
| **5 Right rail**, Tower button | A lock overlay during boss lock |

---

## 4. Feature Moments

Each feature lists what the player should **feel**, then its **surfaces**, **copy**, **audio and VFX**, and **data**.

### 4.1 Floor arrival (all milestones)
**Feel:** "I've entered somewhere new, and I know what I'm up against."
- **Arrival card** (top-centre, 2.5 s, `ModalAnimator` slide-down, no scrim; it doesn't block input):
  - `FLOOR 13 · GLASSWIND RAVINE`
  - biome name, and difficulty pips for the floor's place in the biome (▮▮▮▯▯, so floor 5 shows all five in red),
  - the floor boss's name and portrait: the **Alpha** on floors 1–4 or the **Biome Boss** on floor 5,
  - `112% READY` (Squad Power against Recommended Power), coloured green, amber or red.
  - On 5th floors it gets a **WALL** ribbon: "Biome Boss floor".
- **Floor sign in the world:** the existing `SurfaceGui` sign shows the same title. Nothing new to build there.
- **Audio:** a biome sting (short, per biome) the first time per run.
- **Data:** `TowerFloorConfig.Get` (name, biome, floor-in-biome), `RecommendedPower`, and the attuned `SquadPower` from the profile sync.

### 4.2 Kill threshold and camp waves (M1, M3)
**Feel:** "There's always something to fight, and every kill pushes the bar."
- **Floor bar:** `31/36`. Regular kills add one tick, and Elite kills add three ticks with a gold flash. The bar pulses when a kill lands.
- **Surge marker:** a small horn icon at 50%. When crossed, see §4.3.
- **Camp respawn in the world:** each camp centre gets a ground glyph (a faint circle in the biome accent colour). When a camp is fully cleared, the glyph drains. Over the 10 s respawn it fills back up, and when it completes the mobs rise out of it with a burst. Players learn that camps come back and where.
- **No idle prompts:** if the squad has had no target for 8 s, a world-space chevron points to the nearest live camp. This is client-side, from the mob snapshot.
- **Data:** `FloorProgress` (`CurrentKills`, `RequiredKills`, `SurgeSpawned`) and a new `CampState` per camp in the room snapshot metadata (`CampId`, `RespawnAt`), sent at most 2 Hz over the metadata path, not in the 24-byte record.

### 4.3 Surge pack (M1)
**Feel:** "Uh oh, here they come."
- **Screen-edge warning:** a red pulse on the side the surge spawns from, plus `SURGE INCOMING`, shown 1.5 s before it arrives.
- **Spawn:** rift-tear VFX at the spawn point (a ring of particles), with the pack stepping out of it.
- **Audio:** a war horn, then a short drum loop until the pack dies.
- **Payoff:** clearing it plays a `SURGE CLEARED` toast and a big tick on the bar (the Elite counts 3).
- **Data:** a `SURGE_SPAWN` action on the existing `TowerAction` remote, with position and side.

### 4.4 Boss summon, intro and boss lock (M3, M3b, penalties)
**Feel:** "This is a fight I chose and can't run from."
- **Intro** (2.2 s, the boss's existing invulnerable wake-up window):
  - **Alpha:** a horizontal name card `VINEBOUND ALPHA`, in the biome colour, with a camera nudge toward the Apex.
  - **Biome Boss:** a full-width card `MOSSBOUND GUARDIAN · BIOME BOSS`, a heavier sting, a screen shake and a darkened vignette.
- **Floor bar morphs into the boss bar** (Phase 5 already does this). Phase 6 adds a **🔒 lock badge** on the bar's left with `Travel sealed`.
- **World lock:**
  - the four sanctuary pedestals get red chains and dimmed prompts,
  - the portal spot (once it exists) shows a sealed red barrier.
  - Pressing a sealed prompt shows `Defeat the boss to travel` instead of nothing happening.
- **Right rail:** the Tower button gets the lock overlay. Tapping it shows the same message.
- **Toast on summon:** `Floor 13 boss summoned · travel sealed until it falls`.
- **Unlock:** chains shatter (particles and sound) on the boss's death or a wipe.
- **Data:** a `BossLocked` attribute on the player's tower context (server-set), plus the existing boss presentation.

### 4.5 Floor cleared, first clear and portal (M4, M5)
**Feel:** "I did it, and the next floor is calling."
- **Clear beat** (on the boss's death, about 3 s total):
  1. a camera punch and a gold flash, with a `FLOOR 13 CLEARED` banner,
  2. **first clear only:** a reward chest bursts from the boss's spot. Gems, Gold and a guaranteed relic fly out, then the itemised rewards tick into the currency bar. On a Biome Boss, the chest is bigger and shows the artifact reveal (rarity-coloured beam, then the card),
  3. **streak +1** (§4.6),
  4. the **portal opens** where the boss fell, with a beam of light from the sanctuary to it. The sanctuary `NEXT` pedestal glows too.
- **Portal prompt** (prompt only, no touch-teleport): `Ascend to Floor 14`. Its object text shows the **squad check** before you commit: `Squad 62% HP · 1 down (revives at 30%)`.
- **Players who haven't cleared the floor** see the portal greyed out with `Clear this floor's boss to ascend`. This is client-side, from `MaxFloorReached`.
- **Data:** the boss `Reward` path sends `FloorCleared { FirstClear, Rewards, Artifact? }` on a new `TowerRemotes.FloorCleared`. The portal visibility check runs on the client and is enforced on the server.

### 4.6 Climb streak (M5)
**Feel:** "I'm on a roll. Do I push one more?"
- **Streak chip**, attached to the right of the floor bar: `🔥 x3 · +30% relics`.
  - The flame grows in tiers: small at 1–2, medium at 3–5, large at 6–9, and blue at the cap (10, "MAX +100%").
  - On increase: the chip pops (scale 1.25 → 1), the number ticks up, and a whoosh plays.
  - Hidden at 0, and outside the tower.
- **Relic value shows the streak:** the carried relic's billboard and the At Risk chip both show the multiplied value, so the streak visibly makes the carried loot worth more: `🏺 Cursed Urn · 150 💎 (+30%)`.
- **On loss** (wipe, return, disconnect): the chip **shatters** in place, with the reason underneath for 2 s (`Streak lost · squad wiped`).
- **First-time tip** (one-shot): "Clear floors back to back to grow your streak. Banked relics pay more. Going home or wiping resets it."
- **Data:** a new `TowerRemotes.RunState { Streak, BestStreak, UnbankedGold, UnbankedGems }`, sent on change.

### 4.7 Carrying, at risk and banking (M4, M5, penalties)
**Feel:** "This loot is mine only once I get it home."
- **At Risk chip** (currency bar, appears only when something is at risk): `AT RISK ⚠ 2,400 G · 96 💎 · 🏺 Urn`.
  - Amber normally.
  - It turns **red and pulses** when the squad is low: one hero standing, or under 30% total HP.
  - Tooltip: "Lose 25% of unbanked Gold and Gems and your carried relic if your squad wipes. Bank at a sanctuary to make it safe."
- **Carried relic:** the overhead model already exists. Add a value billboard (tier name, Gems with streak) visible to everyone, so thieves see what's worth taking.
- **Way home:** while carrying, the sanctuary shows a tall light beam visible from anywhere in the room. When it's off-screen, a screen-edge arrow points to it.
- **Bank moment** (entering a sanctuary or pad):
  - coins and gems fly from the character into the currency chips, which tick up,
  - a breakdown toast: `BANKED · 🏺 Cursed Urn 75 💎 ×1.3 streak = 98 💎 · +1,200 G`,
  - the At Risk chip drains to zero and hides,
  - a satisfying chime plays.
- **Data:** `RunState.Unbanked*`, plus the existing `RelicStateChanged` (`EXTRACT_SAFE_ZONE`, `EXTRACT_PRIVATE`). The bank toast comes from the server, with the final numbers.

### 4.8 Downed heroes and no heal between floors (M3, penalties)
**Feel:** "Every hero I lose here stays lost until I move on, so I'd better play carefully."
- **Squad card tile**, when down:
  - portrait in greyscale with a cracked frame,
  - the HP bar replaced by `DOWN`,
  - the sub-label `Back on next floor` (no countdown).
  - The card header shows **`2/3 standing`**.
- **In the world:** a soft wisp hovers where the hero fell, and the hero's nameplate dims. Others can see you're short-handed.
- **Last hero standing:** a heartbeat audio loop, a red vignette at the screen edges, and the At Risk chip turns red. That's the "wipe danger" signal.
- **Sanctuary healing:** green motes rise from heroes inside the sanctuary, `+HP` ticks show over them, and the squad card shows a `Healing` chip.
- **Floor transition:** a revive animation on arrival (light column), and downed tiles flip back to colour at 30% HP, with a `Revived (30% HP)` toast.
- **Data:** a `Downed` flag in the hero metadata sync (the ≤ 2 Hz path from Phase 5 §2.2).

### 4.9 Wipe (penalties)
**Feel:** "That hurt, but I understand why, and I still have a lot."

This extends the Phase 5 **Defeat modal** (merged with the run summary, §4.12).
- **Header:** `SQUAD WIPED · FLOOR 13`.
- **Two columns:**
  - **Lost** (red): carried relic, streak x3, `−600 G · −24 💎` (25% of unbanked).
  - **Safe** (green): banked Gold and Gems this run, all heroes and weapons, and `Floor 13 still unlocked`.
- **One tip, picked by cause:** "Bank at the sanctuary before the boss", or "Your squad was 68% ready. Train at the Fortress".
- **Buttons:** **[RETURN TO FORTRESS]**, the primary button. Restoring the whole squad is the existing plot restore.
- **Data:** the server sends a `RunSummary` with `Reason = "WIPE"` and the loss lines. The client never calculates losses.

### 4.10 Power, walls and Rift Attunement (M3)
**Feel:** "I can see how close I am to breaking through, and every session moves the needle."
- **Squad Power badge:**
  - `⚔ 48,200` with `112% READY` underneath, in green (100% or more), amber (70–99%) or red (under 70%).
  - A third line shows the **next wall**: `▲ Wall F15 · 64%`.
  - On phones it shows the % only.
- **Attuned marker:** when any hero is capped, the badge shows a small 🔒 and `ATTUNED`. The tooltip lists each hero as `Astrea 42,000 / 1,014,981 attuned`, with the hint `Reach Floor 20 to unlock +30%`.
- **Squad panel:** each hero card shows an attunement bar (attuned / raw) when capped. Reaching a new floor makes it fill up with a `+X% unlocked` flash. This turns attunement into a reward for climbing, not a hidden nerf.
- **Wall progress between sessions:** the run summary and the Tower panel show `Wall F15: 52% → 64% ready this session`.
- **Data:** the profile sync gains `AttunedSquadPower`, `RawSquadPower` and the per-hero attunement. Recommended Power comes from shared config.

### 4.11 Tower panel and floor selector (TowerController)
**Feel:** "The tower is a journey with clear milestones."
- **Floors grouped by biome.** Each biome is a row of 5 tiles. The 5th tile is larger and marked **WALL**, with the Biome Boss portrait. Floors 1–4 show the Alpha's portrait.
- **Tile states:**
  - Cleared: gold check.
  - Current: pulsing frame.
  - Unlocked, not yet cleared: normal.
  - Locked: padlock and `Clear F12 first`.
- **Each tile shows the floor's Recommended Power and your % ready**, so players can pick a farm floor (well over 100%) or a push floor.
- **Assign squad:** the button reads `Assign squad · farms Gold, Gems and XP`. The sub-copy reads `Relics drop only while you're on that floor. Climbing needs you there.`
- **Assigned squad on the Squad card:** a header chip `Farming F12`, and tiles show `Farming` instead of Fighting.

### 4.12 Run summary (M5)
**Feel:** "That run counted."

This shows on a hub or plot return and on a wipe (merged with §4.9). It is skipped if the run lasted under 30 s.
- **Hero row:** floors climbed this run (`F10 → F14`) with a `NEW BEST FLOOR` ribbon when it applies.
- **Stats:** best streak, Gold and Gems banked (with streak bonus earned), relics banked, Alphas and bosses defeated, hero levels gained.
- **Progress line:** `Wall F15: 52% → 64% ready`.
- **Buttons:** **[CONTINUE]** (closes) and, on a return, **[BACK TO THE TOWER]** (opens the Tower panel at your highest floor).
- **Data:** `TowerRemotes.RunSummary` (server-built from the run state).

---

## 5. First-Time Tips

Each new system gets **one** contextual tip, the first time it matters. Tips are short cards, dismissed with a tap, and never repeat:

| Tip | Trigger |
| --- | --- |
| Camps come back | First camp cleared |
| Surge | First surge |
| Boss lock | First boss summon |
| Streak | First floor clear in a run |
| Banking and At Risk | First relic picked up |
| Down until next floor | First hero down |
| % Ready and walls | First arrival on a 5th floor |
| Attunement | First time a hero is capped |
| Assigned squads farm | First Assign |

- **Storage:** `profile.Onboarding.SeenTips` (a map of tip id to true). `DataManager.SyncProfile` already defaults missing onboarding fields lazily. Add `SeenTips = {}` there, with no other schema change. The client asks the server to mark a tip seen; the server validates the tip id against a fixed list.

## 6. Audio and VFX Budget

- **Audio cues:** biome sting, surge horn and drums, boss intro (Alpha and Biome Boss), clear fanfare, first-clear chest, streak up and streak shatter, bank chime, heartbeat (last hero standing), revive.
  - Use one `SoundGroup` per category so Settings volume sliders apply.
  - Audio assets must be owned by the experience or have permission granted (see the `roblox-audio` skill).
- **VFX:** use pooled `ParticleEmitter`s and `Beam`s, at most ~12 active effects at once (matching the telegraph cap).
- **Lighter effects on phones:** reduce particle rates when graphics quality is 3 or lower.
- **Respect reduced motion:** add a "Reduce screen shake" toggle to Settings, which removes the camera punches and shakes.

## 7. Data Contracts (server-authoritative)

| Contract | Direction | Contents | Rate |
| --- | --- | --- | --- |
| `TowerRemotes.RunState` | S→C | `Streak`, `BestStreak`, `UnbankedGold`, `UnbankedGems` | On change |
| `TowerRemotes.FloorCleared` | S→C | `FloorId`, `FirstClear`, reward lines, `Artifact?` | On boss death |
| `TowerRemotes.RunSummary` | S→C | `Reason`, floors, streak, banked, losses, wall % | On run end |
| `TowerRemotes.TipSeen` | C→S | `TipId` (validated against a fixed list, rate-limited) | On dismiss |
| `TowerAction` `SURGE_SPAWN` | S→C | position, side | On spawn |
| Context attribute `BossLocked` | S→C | boolean | On change |
| Hero metadata `Downed` | S→C | boolean per hero | ≤ 2 Hz |
| Room metadata `CampState` | S→C | `CampId`, `RespawnAt` | ≤ 2 Hz |
| Profile sync | S→C | `AttunedSquadPower`, `RawSquadPower`, per-hero attunement, `Onboarding.SeenTips` | Existing sync |

The client only displays these. Rewards, losses, lock state and attunement are always computed on the server.

## 8. Delivery (aligned with the run-loop milestones)

| UX step | Lands with | Contents |
| --- | --- | --- |
| UX-1 | M1 | Floor bar ticks, camp glyphs, idle chevron, surge warning |
| UX-2 | M3 | Arrival card, % READY badge, Down state and standing count, sanctuary healing, last-hero danger, boss lock visuals, attunement badge and bars |
| UX-3 | M3b | Alpha and Biome Boss intros, Tower panel portraits |
| UX-4 | M4 | Clear beat, first-clear chest, artifact reveal |
| UX-5 | M5 | Streak chip, At Risk chip, bank moment, portal prompt rework and squad check, wipe and run summary modal |
| UX-6 | M7 | First-time tips, audio pass, reduced-motion toggle, telemetry on tip views |

## 9. Acceptance

- **Five-question test:** in a playtest, new players answer the five questions in §1 correctly from the screen alone, without opening a menu.
- **Mobile:** at 375 × 667 and on a tablet, no Phase 5 zones overlap with the streak chip, At Risk chip and three-line power badge all shown at once. Every button is at least 44 px.
- **Gamepad:** the portal, pedestal and sealed prompts, the run summary buttons and the tip cards are all reachable with the gamepad.
- **Performance:** on a mid-range phone in a full 6-player floor, VFX and UI updates stay under 2 ms of client frame time.
- **Telemetry (M7):** tip view and dismiss counts, the share of wipes where the player had banked in the last 2 minutes (are players learning to bank?), and rage-quits after wipe-modal views.
