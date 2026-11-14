# First session, clips and social play

Two goals:

1. **First session.** A new player pulls on both hero banners, places a flashy hero in their squad, clears Floor 1, banks a relic, then steals a relic and wins the duel that follows, all in about eight minutes. Theft and the bounty duel are the game's core loop, so every new player plays through them once.
2. **Clips and social play.** Thefts, bounties, duels and big pulls become things the whole server sees and talks about.

Everything here builds on systems that already exist: the linear guide (GDD §4.7), the bounty duel (§6.1), timed tower events (§3.3), raids (§5.6), the friend boost (§4.8), `OnboardingService` telemetry and `DataManager.BroadcastToast`. Update the GDD in the same change as each item.

**Rules for this plan**

- Prefer changes that need **no save-schema change**. New one-time flags go in `profile.Onboarding.Guide.Facts`, a free-form `{ [string]: boolean }` map that already tolerates new keys, instead of new top-level fields.
- Existing players must never lose anything they have, and must never pick up a new-player gift.
- Every Phase 1 change ships behind a per-player experiment (A1), not a server-wide switch.

---

## Where we are today

Checked against the code on 2026-11-15.

| Area | Today (code) | Problem for a new player |
| --- | --- | --- |
| Starter roster | Gide (slot 1, protected from Pit and sale) and Catio (bench), `TowerHardcoreConfig.StarterGems = 900`: one ten-pull with a guaranteed Rare (`TenPullMinTier`) | On Call of the Rift the Rare tier is only Catio, who they already own. The "guaranteed" hit is a duplicate. |
| Squad size | `BaseSquadSlots = 1`; slots = base + Command level (`FortressTree.luau:54`). Slot 2 is the `sq_1` node, 500 Gold | One hero fights Floor 1. That's fine if that hero is the best one they own, but nothing makes sure it is. |
| Hero banners | Two banners: Call of the Rift (100 / 900 Gems) and A Star's Arrival (200 / 1,800, featured Astrea, 50/50 rule). The guide only ever points at Call of the Rift | New players never learn the limited banner, its pity or its featured Mythical, which is the banner most worth saving Gems for. |
| Guide chain | 10 core steps: Summon, Squad, Visit, Clear, Return, Roll, Equip, GuardPost, Tree, Synthesis. Clear opens the Forge, Roll opens Facilities, Tree and Pit | Steps 6–10 put five systems in front of the player before they have climbed a second floor. Nothing teaches theft or duels. |
| Theft and duels | Picking up someone else's relic flags the thief for 3 minutes and opens a bounty. A duel starts only when another Master on the floor presses F within 12 studs of the thief (`challengeThief` → `startDuel`). Both sides must be real players | A new player rarely has another Master on their floor, so many never steal, get hunted or duel in their first sessions, although that's the core loop. |
| First relic | First clears force a relic (`RollRelic` with `dropRoll` 0, `CombatSimulation:3078`), but **only for the player who lands the kill** (`p == killer`) | On a shared Floor 1, a new player whose kill is stolen by a veteran gets no relic. |
| Bank lesson | Conditional, top priority, can be snoozed. No reward | Carrying and banking is optional in session 1. |
| Skill gauge | New heroes start at `CurrentStamina = 100` (`DataManager:439`) | Good: the first Ultimate fires on the first attack. Nothing frames it as a moment. |
| Hero animations | Every hero has its own Ultimate clip. Most low-tier heroes use the generic weapon-type Basic and Move clips | The clips players see most often are the generic ones. |
| Telemetry | `GuideOffered`, `GuideCompleted`, `GuideSkipped`, `GuideSnoozed`; `GuideTimeFromJoin` for Visit, Clear and Return only, timed from session start; `TowerTelemetry` floor clears, run ends, wipes. **All of it is skipped in Studio.** Nothing calls `LogOnboardingFunnelStepEvent` | No Creator Hub onboarding funnel, no timing past Return, and Studio playtests record nothing. |
| Rollout switch | `workspace.OnboardingV2` is a server-wide attribute | A server switch can't run an A/B test: every player in a server gets the same arm. |
| Bounties | Toast to Masters on the same floor, banner to the owner | Nobody in the hub knows a theft happened. |
| Server-wide messages | `DataManager.BroadcastToast` → `SystemToastEvent:FireAllClients`. One caller (Calamity Heart Archon roll), which breaks the toast rules in §4.6.1 (emoji, full sentence) | No queue, no rate limit, and toasts are too small for headline moments. |
| Tower events | 15 min calm, 60 s warning, 5 min event, picked by weight. `RELIC_RAIN` already exists (weight 2) | Already a server-wide rhythm, but nothing pulls players together. It drifts against the raid schedule (:00 and :30), so warnings can collide. |
| Friend boost | +10% Gold per friend in the server, up to +30%, shown in Rewards | No invite button, and the boost is hidden in a window. |

---

## Part A: the first session

### Target timeline

| Time | What happens | Guide step |
| --- | --- | --- |
| 0:00–0:20 | Spawn facing the Summoning Altar. The spotlight points to the Call of the Rift ten-pull. | 1. Summon a hero |
| 0:20–1:00 | The ten-pull reveal ends on the showcase hero (A2). | |
| 1:00–1:30 | The spotlight moves to A Star's Arrival: one single pull with the 200 Gems step 1 paid. The card shows Astrea and the pity counter. | 2. Try the limited banner |
| 1:30–1:50 | Open Squad and place the showcase hero in slot 1. Gide goes to the bench. | 3. Set your squad |
| 1:50–2:20 | Trail to the Tower entrance, then Floor 1. | 4. Enter the Tower |
| 2:20–4:20 | One hero clears Floor 1. Its first Ultimate is framed (A5). Whistle hints appear once each. | 5. Clear Floor 1 |
| 4:20–5:20 | The boss drops a guaranteed relic (A4). "Carry it home": seal countdown, pick up, slow walk, sanctuary or hub bank. | 6. Bank your relic |
| 5:20–6:00 | Floor 2. A Rival Master is carrying their own relic and drops it nearby (A7). | |
| 6:00–6:30 | Pick it up: the player is now a `[Loot Thief]` with a bounty. | 7. Steal a relic |
| 6:30–7:30 | The Rival hunts them down and the bounty duel starts. The player's squad wins. | 8. Win the duel |
| 7:30–8:00 | Bank the stolen relic, then the payout card and "Back to the Hub". | 9. Return to the Hub |

Forge, Equip, Guard Post, Fortress Tree and Synthesis become chapter 2 (A3).

### A1. Measure first (do this before anything else)

The guide already logs a lot. Fill the gaps rather than adding a second system.

- **One milestone funnel for every arm.** Log `AnalyticsService:LogOnboardingFunnelStepEvent` with fixed milestones, not guide step numbers, so control and variants feed the same funnel even when the chain changes:
  1. `Joined`
  2. `FirstPull`
  3. `LimitedPull`
  4. `SquadSet`
  5. `EnteredTower`
  6. `FirstUltimate`
  7. `ClearedFloor1`
  8. `PickedUpRelic`
  9. `BankedRelic`
  10. `ReachedFloor2`
  11. `FirstTheft`
  12. `FirstDuel`
  13. `DuelWon`
  14. `BankedStolenRelic`

  Steps must be sequential and 1-based, so a milestone reached out of order also logs every skipped earlier step. Real thefts and duels count as well as the Rival's.
- **Timing for every milestone.** Extend `GuideTimeFromJoin` beyond Visit, Clear and Return. Store `profile.Onboarding.FirstJoinAt` (`os.time()`) in `OnboardingService.EnsureState` when it is missing, and time from it rather than from `os.clock()` at session start. Existing profiles get no value and are left out of first-session metrics. (`EnsureState` fills in the default, so this needs no migration.)
- **Studio playtests.** `telemetry()` returns early in Studio. Add a `DebugOnboardingTelemetry` Workspace attribute that prints each milestone and its time to Output, so the `tests/studio-*` playtests (PC, phone emulator, gamepad) can check timing. They're a sanity check, not the baseline.
- **Baseline from live data.** Collect at least one week of the live funnel before Phase 1 ships, and judge every later change against it.
- **Experiment plumbing.** Assign the onboarding arm with `ConfigService:GetConfigForPlayerAsync(player)` on first join, and save the arm in `profile.Onboarding.Arm` so a player never switches arms in the middle of onboarding. `workspace.OnboardingV2` stays as the emergency kill switch. Roblox experiments run 14 to 60 days with at most two variants plus control. If new-player volume is too low to reach the minimum detectable effect, ship to everyone and compare against the baseline week instead.

**Files:** `OnboardingService.luau`, `CombatSimulation.server.luau` (Ultimate, floor clear, theft, duel), `RelicService.server.luau` (pickup, bank).

### A2. A showcase first ten-pull

- **Raise the first ten-pull's guarantee from Rare to Superior or higher.** On Call of the Rift that is Aeli most of the time, with the banner's normal upper-tier odds above that. It reuses the existing guarantee path: `DataManager:949` passes `banner.TenPullMinTier` to `rollBannerHero`, so pass 4 (Superior) instead for this one pull.
- **Who qualifies:** a Call of the Rift ten-pull made while `guide.Facts.Summon` is not set, which is true only before a profile's first summon of any kind. The flag already exists and is already credited to every older player who has cleared Floor 1, so there's **no new field and no migration**, and no veteran can farm it. While step 1 is active, the spotlight points at the ten-pull. Also hide the single-pull buttons on both banners during step 1, so the player can't use up the guarantee on a single pull.
- **Why Superior and not an Exalted "showcase list":** Superior (tier 4) sits below `PityMinTier = 5`, so the gift doesn't touch the 120-pull pity or the Gem economy. A guaranteed Exalted would hand every new player a 0.33% hero and reset their pity. If Aeli's Ultimate doesn't read clearly at a glance, give Aeli's skill VFX a pass (`hero-creation`, A8) rather than raising the tier.
- **No auto-deploy.** The player places the hero themselves in step 3 (A3).
- **Policy:** Gems can be bought, so this banner is a paid random item. Show the first-pull guarantee in `HeroOddsModal` through `HeroBannerOdds`, which must mirror the server roll. The paid random item check currently lives in `ShopService` (where Gems are sold), so confirm it also covers players for whom paid random items are restricted.
- **Tests:** add the first-pull guarantee to `tests/hero-banner-odds.spec.luau`, covering who qualifies, that the tier is at least 4, and that pity is unchanged.

### A3. One hero, both banners and a shorter guide

- **Keep the squad at one hero.** `BaseSquadSlots` stays 1 and no slot is granted. The showcase hero carries Floor 1 alone, which makes it the star of the first fight. Slot 2 stays the first Fortress Tree buy.
- **New core chain** (`GuideConfig.Chain`), chapter 1:

  | Step | Goal | Done when | Reward |
  | :---: | :--- | :--- | :--- |
  | 1 | Summon a hero | Call of the Rift ten-pull (`HeroSummoned`) | 200 Gems |
  | 2 | Try the limited banner | A Star's Arrival pull (new event `LimitedSummoned`) | 200 Gems |
  | 3 | Set your squad | `SquadDeployed` | |
  | 4 | Enter the Tower | `FloorVisited` (floor 1) | |
  | 5 | Clear Floor 1 | `FloorCleared` (floor 1). Opens the Forge | 5,000 Gold |
  | 6 | Bank your relic | `RelicBanked` (promoted from a conditional lesson) | 200 Gems (moved from Equip) |
  | 7 | Steal a relic | `RelicStolen` (new event, A7) | |
  | 8 | Win the duel | `DuelWon` (new event, A7) | 100 Gems |
  | 9 | Return to the Hub | `TowerReturned` | |

  - **Step 2, Try the limited banner.** Step 1's 200 Gems pay for exactly one A Star's Arrival single pull, so the spotlight goes on that button. The card's featured Astrea, the "View Heroes & Odds" button and the pity counter are the lesson: this is the banner worth saving for. `DataManager` reports `LimitedSummoned` when `isLimited` is true. Step 2's own 200 Gems replace what the pull cost.
  - **Step 3, Set your squad.** The spotlight goes on the showcase hero's card, then on slot 1. Placing it swaps Gide to the bench. Gide is protected from the Pit and sale, so he's safe there, and he becomes the first Guard Post worker in chapter 2. The step completes on any squad change, so a player who prefers Gide isn't stuck. `AUTO_BEST` counts too.
  - **Steps 7 and 8** are the Rival lesson (A7). Until A7 ships, the chain goes straight from step 6 to step 9.
- **Chapter 2** starts after the first Floor 2 clear or the first hub return, whichever comes later: Roll → Equip → Guard Post → Tree → Synthesis. The Tree step's `buildableNode` should prefer `sq_1` (Second Banner, 500 Gold), so slot 2 is the first fortress upgrade and the bench hero from chapter 1 joins the squad.
- **Move the unlocks with the steps.** The unlock keys (`Forge` on Clear; `Facilities`, `FortressTree` and `Pit` on Roll) and both lock-hint tables in `OnboardingService` (`LOCK_HINTS` and `V2_LOCK_HINTS`) must match the new order. `TowerFloor5` stays gated on reaching Floor 5. The old v1 hint "Level a hero in The Pit first" must not come back.
- **If the first relic is lost** (it despawns, or a wipe fumbles it), the Bank step is passed over like any other impossible step and comes back as the conditional lesson.
- Keep the guide's existing rules: a step that can't be done yet is passed over, reaching Floor 3 opens everything, and rewards already paid are never paid again. Bump the guide `Version` to 4. Credit existing players the way v3 did: anyone who has cleared Floor 1 gets steps 1–3, and anyone who has cleared Floor 2 also gets steps 7 and 8. Credited steps pay nothing.
- **Gem pacing: the second ten-pull is the reward for finishing chapter 2.**
  - The limited pull costs 200 and step 2 pays 200, so it's Gem-neutral.
  - Chapter 1 ends at about 710 Gems: step 1's 200, about 12 from the Floor 1 first clear, about 100 from each of the two Mana Geodes, the Bank step's 200 (moved from Equip) and the duel's 100.
  - The 10- and 20-minute playtime tiers add 65, and the Synthesis step's 250 at the end of chapter 2 brings the total to about 1,030. So 900 for the second Call of the Rift ten-pull arrives as chapter 2 finishes, around 20–30 minutes in.
  - Don't raise the duel reward without redoing this: at 250 Gems, the second ten-pull would arrive about ten minutes in, before chapter 2.

**Files:** `GuideConfig.luau`, `GuideLessons.luau`, `OnboardingService.luau`, `OnboardingConfig.luau` (unlock map), `DataManager.server.luau` (`LimitedSummoned`), GDD §4.1 and §4.7.

### A4. Make the first relic matter

- **Guarantee it even when the kill is stolen.** On a profile's first Floor 1 clear (`HighestClearedFloor == 0`), spawn a relic tagged to that player whether or not they landed the kill. The condition makes it once per profile, so it can't be farmed.
- **Protect it.** Lock a profile's first ever relic to its owner until it is banked or despawns. `RelicService` already has owner locks (`LockedUserId`, `LockExpiresAt`, `LockKind`) for fumbled relics; add a `LockKind = "FIRST"` with no expiry. A one-hero newcomer who loses their first relic to a veteran with a full squad can't win the duel back, so it would teach "the game is unfair" one step before A7 teaches theft properly. From the second relic on, every relic can be stolen as normal.
- **Bank your relic** becomes a core step: a trail to the nearest sanctuary. The caption explains the 5 s seal countdown, then the slowdown, then that other Masters can steal *later* relics.
- **On banking**, show a short payout card (Gold, Gems, Promotion Stones) with a count-up and a sound. It's the first big reward moment after the pull. Respect Reduce Motion.

**Files:** `CombatSimulation.server.luau` (first-clear relic), `RelicService.server.luau` (first-relic lock), `GuideLessons.luau`, a new `BankPayoutController` under `UI`.

### A5. Frame the first Ultimate

- New heroes already start with a full gauge. The first time any of a player's heroes fires an Ultimate, play a 0.4 s slow-motion moment, a camera punch-in and a name banner ("Event Horizon!").
  - It's client-only, on the renderer clock. The server is unaffected, and `EntityRenderer` catches up on the snapshot buffer afterwards. Never in a duel or a raid.
  - Under Reduce Motion, show the banner without the slow motion or the camera move.
  - Store the flag as `guide.Facts.FirstUltimate`, which needs no migration.
- With one hero in the squad, the first Ultimate is always the showcase hero's, on its first attack of Floor 1.
- After that, the banner is only for Legendary and Mythical heroes (rarity tiers 6–7) and Biome Boss kills, so it stays special. (Every hero is summoned at 1★, so "7★" can't be the rule: stars only come from promotion.)
- **One-time whistle hints, input-aware:** "Speed up your heroes" the first time a boss enters its post-Signature recovery (the tower Punish Window, §5.3), and "Pull them out" on the first lethal telegraph. Show the bound control: `Q`/`E` on keyboard, `L1`/`R1` on gamepad, the Right Rail button on touch.

**Files:** `EntityRenderer.client.luau`, `HeroClips` and the VFX layer, `MasterController.client.luau` and `Phase5HudController` (hints).

### A6. Cut friction

- Spawn new players facing the Summoning Altar and Tower entrance, with no camera fly-in.
- Hold the daily reward, playtime and code popups until after step 9. Prompt for experience notifications (`ExperienceNotificationService:PromptOptIn`) right after the duel win, because it's the high point of session 1.
- Check the mobile layout: whistle buttons at least 64 px, the guide card clear of the joystick, and the banner single-pull button reachable on a phone during step 2.
- Add a "Report a problem" button (`SocialService:PromptFeedbackSubmissionAsync`) to the Guide help panel, so first-session blockers reach Creator Hub with device info.

### A7. The Rival Master: steal, get hunted, duel

Theft and the bounty duel are the core loop, but they need a second real Master on the same floor, and a new player rarely has one. So every new player plays them once against a server-run **Rival Master** on Floor 2 (steps 7 and 8). Real thefts and duels count too: a player who has already stolen and won a duel for real when they reach step 7 is credited both steps.

**The scripted beat**

1. On the player's first Floor 2 visit, a Rival Master (a named NPC Master with a one-hero squad) walks in carrying a relic and fumbles it near the player. Caption: "Rival dropped a relic|Take it".
2. Picking it up is a real theft through the normal path: `registerPickup` with the Rival as owner, the `[Loot Thief]` flag and the 3-minute bounty. Caption: "You're a Loot Thief|They'll come for it".
3. The Rival runs to the player and claims the bounty, which starts the real bounty duel: the line-up, the arena, the camera and 50% hero-vs-hero damage. For the thief, being hunted means the duel starts the moment the hunter reaches them, which is how theft feels in normal play.
4. The Rival's hero is tuned so the player's showcase hero wins (for example the Rival fields Shurn, Common, at a fixed low level). The winner keeps the relic as normal.
5. Bank it (the same sanctuary trail as step 6), then the payout card.

**Rules**

- **Once per profile**, with `guide.Facts.Steal` and `guide.Facts.Duel` set by the real `RelicStolen` and `DuelWon` events. No new save field.
- **Private bounty.** The Rival's relic and the lesson's bounty are visible only to the player: other Masters on the floor get no bounty toast and no `Claim Bounty [F]` prompt, so a veteran can't jump into the lesson. Mark the contest as a training contest (`contest.Training = true`) and skip the public toast and prompt for it.
- **If the player loses anyway** (they leave, wipe or take too long), the Rival fumbles the relic back to them and the step passes. The lesson never ends on a loss.
- **The relic** is a Mana Geode at Floor 2 value. Training thefts and duels never count towards Notoriety or the weekly boards (B6).

**What has to change in the duel code**

- Today both sides of a duel are real players. `startDuel` looks up `Players:GetPlayerByUserId(contest.ThiefUserId)` and reads each side's `ActiveMasters[player].DeployedHeroes`, and the forfeit, `DuelState` and outcome code assume a `Player` on each side.
- Allow one server-owned side: a `DuelSquad` with `Player = nil` and a rival id (a negative number, which `LootDuel.IsTheft` already treats as someone else's relic). Skip `DuelState`, forfeit checks and lockouts for that side, and give its hero a `SimHero` with no `Owner`.
- **Start with a one-day spike:** run a duel in Studio against a server-owned squad and find every place that dereferences `hero.Owner` or the side's `Player`. If the spike shows too many, use the fallback: run the Rival's squad as hero-styled mobs in the arena with the duel's camera and UI, and keep the real duel code for players.
- A7 is the largest item in Part A, so ship it in its own experiment after Phase 1. Until then the chain skips steps 7 and 8.

**Files:** `CombatSimulation.server.luau` (duel section, training contests), `LootDuel.luau`, `RelicService.server.luau`, a new `RivalMaster.luau` under `Combat`, `DuelController.client.luau`, `GuideLessons.luau`, GDD §4.7 and §6.1.

### A8. Better animations for low-tier heroes

A new player's squad is low-tier for their first hours: about 75% of Call of the Rift pulls are Gide or Shurn. Every hero already has its own Ultimate (`AttackSkill`) in `HeroClips`, and most have their own idle. What stays generic are the clips that play most often. A Basic plays on every attack, a Special on every third, and Move plays the whole time between fights.

| Hero | Tier | Own clips | Generic clips |
| --- | --- | --- | --- |
| Gide | Common (starter) | Idle, Special, Ultimate | Basic, Move |
| Shurn | Common (the Rival's hero, A7) | Idle, Special, Ultimate | Basic, Move |
| Jenna | Common (limited, the likely step 2 pull) | Idle, Ultimate | Basic, Special, Move |
| Aaron | Uncommon | Idle, Ultimate | Basic, Special, Move |
| Velkist | Uncommon (limited) | Idle, Special, Ultimate | Basic, Move |
| Catio | Rare (starter, bench) | Special, Ultimate | Idle, Basic, Move |
| Eolka | Rare (limited) | Idle, Ultimate | Basic, Special, Move |
| Aeli | Superior (showcase, A2) | Idle, Ultimate | Basic, Special, Move |
| Morrigan | Superior (limited) | Idle, Ultimate | Basic, Special, Move |

Work in this order:

1. **Generic Basic and Move for all six weapon types** (`ByWeapon` in `HeroClips`: 12 clips). Clips are looked up by hero, then weapon type, then shared, so this one pass upgrades every hero above and any future hero without overrides. Add clearer anticipation, follow-through and weight, so each Basic reads as a hit. Keep the existing `Release` marker timings (`RELEASE_MARKERS`) so projectiles and damage still line up with the server.
2. **Aeli's own Basic and Special.** She's the showcase hero (A2) and, with one squad slot, the only hero fighting Floor 1 and the Rival duel. Check her Ultimate's VFX in Studio at the same time, because whether it reads at a glance depends more on the VFX than on the animation.
3. **Gide's own Basic.** He's the fallback squad hero and the one players see in the hub before their first pull.
4. **Catio's own idle**, so he doesn't stand in the default axe stance on the bench or at the Guard Post.
5. **The other low-tier heroes** only if they still look flat after step 1.

Steps 2–4 use the `hero-creation` skill (animations, grip, Studio check). Step 1 needs a Studio check of every weapon type, both walking and attacking, including on heroes that only override some states. The changes are art, not flow, so they ship to every A1 arm at once. Note the ship date against the baseline week so a change in feel isn't mistaken for an onboarding effect.

**Files:** `HeroClips.luau` (`ByWeapon` and `Overrides`), `HeroAnimator.luau` if new markers are needed, `tests/hero-rig.spec.luau`.

### Experiment design for Phase 1

Don't ship everything as one blob, or a change in retention can't be traced to anything.

| Arm | Contents |
| --- | --- |
| Control | Today's guide |
| Variant 1 | A3 + A4: the new chain (both banners, Set your squad, Bank as a core step) and the protected first relic |
| Variant 2 | Variant 1 + A2 + A5: the showcase pull and the framed Ultimate |

A7 (the Rival lesson) runs as its own experiment once Phase 1 has a winner: the winning arm with steps 7–8 against the winning arm without them.

### Part A done when

- **Primary:** day-1 return rate is up against the A1 baseline, with significance in the experiment.
- Median time from first join to `ClearedFloor1` is under 4:30 on phone.
- At least 70% of new players reach `BankedRelic` in session 1.
- Once A7 ships: at least 60% of new players reach `DuelWon` in session 1, and their day-1 return beats players who never duelled.
- **Guardrails** (don't ship a variant that worsens these): session-1 length, Gem balance at the end of day 1 (the economy gift), phone crash rate and FPS during the slow-motion moment, and the share of new players who skip the tutorial.

---

## Part B: clips and social play

### B0. One news channel (build first, B1–B3 depend on it)

- Add a server `NewsService` that every server-wide moment goes through. It owns a queue, merging ("3 Hearts stolen in the last minute") and a rate limit of one headline every 4 s.
- Send structured payloads over one new RemoteEvent: `{ Kind, ActorUserId, TargetUserId?, ItemId?, EndsAt? }`. The client builds the text from config. No free text goes over the wire, and only Roblox display names (already filtered) and server-picked text are shown, so nothing needs `TextService` filtering.
- Headlines are a news banner, a separate surface from toasts (avatar headshots, countdown). Anything that stays a toast follows §4.6.1: `"Headline|detail"`, no emoji, no sentences.
- Move the existing Archon broadcast (`RelicService:395`, which uses an emoji and a full sentence) onto `NewsService`. Keep `DataManager.BroadcastToast` for plain system notices.
- Add a settings toggle to mute the news banner, for players who find it noisy.
- Training contests and duels (A7) never make the news.

### B1. Make thefts server-wide news

- When a **Core or Heart** is stolen, every player in the server gets a headline: **PlayerX** took a **Calamity Heart** from **PlayerY**, with the bounty countdown. Smaller relics keep today's floor-only toast, so the feed doesn't turn into spam.
- A **Wanted board** in the Cloister Commons shows the current thieves, their relic, their floor and the time left, with a "Hunt" button that travels to that floor (normal travel rules apply).
- **Measure whether hunts can succeed.** A thief is usually close to a sanctuary, so hunters coming from the hub may rarely arrive in time. Watch `HuntTravel` → `DuelStarted`. If few hunts reach a duel, try a slower bank for Core and Heart thieves (a 3 s channel at a sanctuary while flagged) before lengthening the bounty.

**Files:** `CombatSimulation.ReportRelicPickup`, `NewsService`, a new `NewsFeedController.client.luau`, a hub board builder in `BaseOverhaul`.

### B2. Duels as a show

- **Intro card** during the 2.5 s line-up: both avatars, squad power and "VS".
- **Finish:** slow motion on the last knockout (client-only, respects Reduce Motion), the winner's squad plays a victory pose, and a result card names the prize. There's no victory clip yet: add a `Victory` state to `HeroClips`, one shared clip per weapon type (7 clips). Heroes can get their own later through `Overrides`.
- **Server-wide result** through `NewsService`: "**PlayerZ** claimed the bounty on **PlayerX**" or "**PlayerX** escaped with the loot".
- **Spectating:** Masters on the same floor get a "Watch" button that moves their camera to the arena. The arena is built under the room's ceiling, so room-local replication already sends them its entities. Players in the hub only get the result headline, because sending them the duel's entities would break room-local replication.
- The Rival duel (A7) uses the same intro card, finish and victory pose, so every new player sees the full show once.

**Files:** `DuelController.client.luau`, `DuelArena.luau`, `LootDuel`, `CombatSimulation` duel section, `HeroClips.luau` (`Victory`).

### B3. Big-moment broadcasts

Send a `NewsService` headline and a sound for:

- a **Legendary or Mythical** hero pull (rarity tiers 6–7; every hero is summoned at 1★), plus a light beam over the puller's plot Summoning Altar that players in the hub can see
- an Exalted+ weapon from the Forge
- the first clear of a Biome Boss in this server
- banking a Calamity Heart

A ten-pull with several hits becomes one merged headline.

### B4. Make the timed events gather people

`TowerEventService` already publishes its state as `ReplicatedStorage` attributes (`TowerEventPhase`, `TowerEventStartsAt`, `TowerEventBiome`), so most of this is client-only:

- A countdown on a hub **Tower board** (next to the Wanted board, not mixed into it) and in the HUD badge, naming the floor or biome affected.
- A "Go to event" travel button during the 60-second warning. For a biome event it takes you to the lowest floor of that biome you have unlocked.
- **More relic events, without breaking the picker.** `RELIC_RAIN` already exists. Instead of "every third cycle", which would fight the weighted, never-twice-in-a-row picker, raise its weight or add a picker rule in `TowerEventRules`: at most N cycles without a relic event. Check first whether Relic Rain meteors carry an owner. Unowned relics never open a bounty, so if they're unowned, Relic Rain makes no thefts.
- **Don't collide with raids.** The 21-minute event cycle drifts against raids at :00 and :30. Delay any event warning that would overlap a raid's 60 s warning or its fight, so the server is never split between two calls at once. Cover it in `tests/tower-events.spec.luau`.

**Files:** `TowerEventService.server.luau`, `TowerEventRules`, `TowerEventConfig.luau`, the tower event HUD.

### B5. Bring friends

- An **Invite friends** button in the Rewards window and on the friend-boost toast: `SocialService:PromptGameInvite`, shown only when `CanSendGameInviteAsync` allows it, labelled "+10% Gold per friend here (up to +30%)". The boost rewards *playing together*. Don't add a reward for sending invites. Check Roblox's current policy on rewarded engagement before you change that.
- Show the active friend boost on the HUD next to Gold, not only in the Rewards window.
- Optional: an experience notification ("Your friend is climbing Floor 12"). It needs opt-in (A6), a Creator Hub notification string, and a call to Open Cloud `POST /cloud/v2/users/{userId}/notifications` with the key in Secrets. Notifications are rate-limited and moderated, so send only ones players value.

**Files:** `RewardsService.luau`, the Rewards UI, `HudApp.luau`.

### B6. Reputation and leaderboards

- Track `Thefts`, `BountiesClaimed` and `Escapes` per player in a new top-level `profile.Notoriety`. Don't reuse `profile.Social`, which v7 deleted. Add schema v10 in `ProfileMigrations` (zeros).
- **Count only fair fights, or the boards reward griefing:**
  - no training thefts or duels (A7)
  - no theft from a protected first relic (A4)
  - no theft or claim between Roblox friends (two friends could farm each other)
  - at most N counted thefts per victim per day
- **Nameplate titles** by count: "Pickpocket", "Notorious Thief", "Bounty Hunter", "Warden". Show them as a line in the existing hero and Master nameplate style (§5.5 billboard rules: no plate or badge).
- **Weekly boards** for Top Thieves and Top Hunters, in two new slots in the Leaderboard Pavilion (`SharedLeaderboards`). Use one `OrderedDataStore` per week (`Thefts_2026W47`), following `PowerLeaderboardSystem/PowerDataStore` (including its Studio scope). Write a player's weekly total at their autosave, not on every theft, to stay inside the write budget. One server loop reads the boards every 60 s and caches them.

### B7 (optional). Clip prompts

After a duel win or a Biome Boss kill, show a small "Save this moment" prompt through `CaptureService`. Check the current API and its limits first, and skip it if the API isn't available to the experience.

### Analytics for Part B

Log custom events for `TheftAnnounced`, `HuntTravel`, `DuelStarted`, `DuelWatched`, `BigMomentBroadcast`, `InviteSent` and `EventTravel`. Use low-cardinality fields (relic tier, event id, training or real), never user ids. Watch average session length, the share of sessions with at least one real duel, and `HuntTravel` → `DuelStarted` conversion.

---

## Risks and guardrails

| Risk | Guardrail |
| --- | --- |
| Veterans steal from a one-hero newcomer's first relic | A4 first-relic lock. B6 excludes protected relics from Notoriety. |
| A veteran joins the Rival lesson | A7 private bounty: no public toast or prompt for training contests. |
| The new player loses the Rival duel | A7 tuning, and a fallback that hands the relic back so the lesson never ends on a loss. |
| The duel code can't take a server-owned side | A7 one-day spike first, with the hero-styled mob fallback. |
| Notoriety farming between friends or alts | B6 friend exclusion, per-victim daily cap, no training thefts. |
| News spam in a full server | B0 rate limit, merging, a Core/Heart-only threshold and a mute toggle. |
| Events and raids split the server | B4 scheduling rule and test. |
| Showcase pull disturbs the Gem economy | A2 uses Superior (below pity). A3's limited pull is Gem-neutral. A1 tracks the day-1 Gem balance as a guardrail. |
| Slow motion stutters on low-end phones | A5 is client-only with a Reduce Motion fallback. A1 tracks FPS and crash rate. |
| Guide reorder strands a player behind a lock | A3 moves the unlock keys and both hint tables with the steps. Floor 3 still opens everything. |
| Animation changes muddy the experiment | A8 ships to every arm at once, and its ship date is noted against the baseline. |

## Order of work

| Phase | Items | Why first |
| --- | --- | --- |
| 0 | A1 | Without a baseline and per-player arms you can't tell whether anything helped. |
| 1 | A3, A4 (Variant 1), then A2, A5 (Variant 2), with A8 steps 1–2 alongside | These change day-1 retention the most. The new chain needs no new systems. A8 makes the one hero on screen look good. |
| 1b | A7 spike, then A7 and the B2 victory clips | The core loop in onboarding. Largest item in Part A, so it gets its own experiment. |
| 2 | B0, then B1, B2, B3, B5 | Mostly presentation on systems that already work. B0 first, because the rest send through it. |
| 3 | B4, B6, A6, A8 steps 3–5 | Polish and longer-term engagement. |
| 4 | B7 | Only if the data asks for it. |

## Decisions for the team

1. Whether Aeli's Ultimate reads clearly enough to be the showcase, or needs a VFX pass first (A2, A8).
2. Protect only the first relic, or all Floor 1–2 relics in session 1 (A4).
3. The Rival's hero and level, so a new player's one hero wins about every time without it feeling rigged (A7).
4. Relic tiers big enough for a server-wide theft headline (B1). Proposed: Core and Heart.

## Save schema changes (summary)

| Change | Item | Migration |
| --- | --- | --- |
| `Onboarding.FirstJoinAt`, `Onboarding.Arm` | A1 | None: set in `EnsureState` when missing. Existing profiles are excluded from first-session metrics. |
| Showcase guarantee | A2 | None: keyed on the existing `guide.Facts.Summon`. |
| Guide v4 chain (Limited, Squad, Bank, Steal, Duel steps) | A3, A7 | None: guide facts. Credit existing players inside `EnsureState`, as v3 did. |
| First-relic lock, training contests | A4, A7 | None: runtime only. |
| `guide.Facts.FirstUltimate` | A5 | None: a new key in an existing map. |
| `Notoriety = { Thefts, BountiesClaimed, Escapes }` | B6 | Schema v10, zeros. Test in `tests/phase4-progression.luau` or `tests/profile-persistence.spec.luau`. |
