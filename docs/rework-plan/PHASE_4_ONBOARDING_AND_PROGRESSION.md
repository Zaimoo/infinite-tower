# Phase 4: Onboarding Engine, Fortress Tree, Hero Rarity & Idle Loop Backend

**Document Version:** 3.0 (adds the Fortress Development Tree, the God's Blessing facility, inherent hero rarity and lowered hero banner odds)  
**Phase Status:** Implemented (see §10 for what differs from this spec)  
**Prerequisites:** Phase 3 complete  

---

## 1. Objectives & Scope

Phase 4 implements the server-authoritative spine of the game's progression:
1. **Onboarding Engine (`OnboardingService.luau`):** A sequential quest chain that unlocks the game's interlocking systems one by one.
2. **Profile Schema v3 Migration (`DataManager.server.luau`):** Adds `Onboarding`, `Unlocks` and `FortressTree` tables to player profiles and a `Rarity` field to every owned hero, with automatic migration for existing data.
3. **Progressive System Gating:** Server handlers reject actions on locked systems until the corresponding milestone step has been cleared.
4. **Fortress Development Tree (`FortressTreeService.luau`):** A skill tree that is now the only way to unlock and upgrade the support facilities: the Outskirts Guard Post, the Market, the Training Grounds and the new God's Blessing (§5).
5. **God's Blessing Facility:** An angel statue added to the Plaza Fountain, turning it into an upgradeable facility that raises summon luck (§6).
6. **Inherent Hero Rarity & Lowered Hero Odds:** Heroes gain an immutable inherent rarity, like weapons, that multiplies their base stats. Heroes are still summoned at their template's star, and the hero banners roll at lower odds than before (§7).
7. **Facility-Only Idle Labor Backend:** Integrates `WaitingRoomService` and `OfflineRewardService` to generate passive Gold and Materials exclusively from benched heroes assigned to Fortress Plot facilities (§8).

---

## 2. Server Architecture: Onboarding Engine

### 2.1 Configuration: `OnboardingConfig.luau`
Create `src/ReplicatedStorage/Shared/Config/OnboardingConfig.luau` defining the canonical first-session progression milestones:

```luau
--!strict
export type Step = {
	Id: string,
	Title: string,             -- Displayed in the Goal Tracker
	Description: string,       -- Subtitle or guidance hint
	Event: string,             -- Authoritative server trigger name
	TargetCount: number,       -- Required repetitions (usually 1)
	Unlocks: { string },       -- System keys unlocked upon completion
	Reward: { Gold: number?, Gems: number? }?,
}

local Steps: { Step } = {
	{
		Id = "step_summon",
		Title = "Summon your first hero",
		Description = "Visit the Summoning Altar on your Fortress Plot",
		Event = "HeroSummoned",
		TargetCount = 1,
		Unlocks = { "Squad" },
		Reward = { Gems = 200 },
	},
	{
		Id = "step_deploy",
		Title = "Deploy your squad",
		Description = "Assign your heroes to active combat slots",
		Event = "SquadDeployed",
		TargetCount = 1,
		Unlocks = { "Tower" },
		Reward = { Gold = 500 },
	},
	{
		Id = "step_floor1",
		Title = "Clear Floor 1 of the Tower",
		Description = "Defeat the Floor 1 boss in the Infinite Tower",
		Event = "FloorCleared",
		TargetCount = 1,
		Unlocks = { "Forge" },
		Reward = { Gold = 1000 },
	},
	{
		Id = "step_forge",
		Title = "Upgrade a weapon at the Forge",
		Description = "Ascend an artifact weapon at the Blacksmith",
		Event = "ArtifactUpgraded",
		TargetCount = 1,
		Unlocks = { "Facilities", "FortressTree" },
		Reward = { Gems = 100 },
	},
	{
		Id = "step_facilities",
		Title = "Assign a hero to work",
		Description = "Put a benched hero to work at the Outskirts Guard Post",
		Event = "FacilityAssigned",
		TargetCount = 1,
		Unlocks = { "Pit" },
		Reward = { Gold = 750 },
	},
	{
		Id = "step_pit",
		Title = "Level up a hero in The Pit",
		Description = "Synthesize duplicate heroes to level up your squad",
		Event = "PitUsed",
		TargetCount = 1,
		Unlocks = { "TowerFloor5" },
		Reward = { Gems = 250 },
	},
	{
		Id = "step_tree",
		Title = "Grow your fortress",
		Description = "Unlock a new node in the Fortress Tree",
		Event = "TreeNodeUnlocked",
		TargetCount = 1,
		Unlocks = {},
		Reward = { Gold = 1000 },
	},
}

return table.freeze(Steps)
```

`step_facilities` points at the Guard Post because it is the only facility open at the start; the Market, Training Grounds and God's Blessing are bought in the tree. `step_tree` is the first goal that teaches the tree.

### 2.2 Server Service: `OnboardingService.luau`
Create `src/ServerScriptService/Core/OnboardingService.luau`:
- **State Management:** Interacts with `profile.Onboarding` and `profile.Unlocks`.
- **Authoritative Progress Verification:**
  - `OnboardingService.Report(player: Player, eventName: string, param: any?)`
  - Validates that the reported event matches the active step.
  - On step completion:
    - Awards milestone currencies (`Gold`, `Gems`).
    - Merges step `Unlocks` into `profile.Unlocks`.
    - Advances `profile.Onboarding.StepIndex`.
    - Fires `OnboardingSyncRemote:FireClient(player, activeStep, profile.Unlocks)`.

---

## 3. Profile Schema v3 Migration

In `DataManager.server.luau`:
- Bump `DEFAULT_PROFILE.SchemaVersion = 3`.
- Migration function:
  ```luau
  if (profile.SchemaVersion or 1) < 3 then
      profile.Onboarding = {
          StepIndex = 1,
          StepProgress = 0,
          CompletedSteps = {},
      }
      profile.Unlocks = {
          ["Summon"] = true, -- Base system always unlocked
      }
      -- Grandfather existing players who already have progress
      if #profile.Heroes > 1 then profile.Unlocks["Squad"] = true end
      if (profile.MaxFloorReached or 0) >= 1 then profile.Unlocks["Tower"] = true end
      if (profile.MaxFloorReached or 0) >= 2 then
          profile.Unlocks["Forge"] = true
          profile.Unlocks["Facilities"] = true
          profile.Unlocks["FortressTree"] = true
      end
      if (profile.MaxFloorReached or 0) >= 5 then profile.Unlocks["Pit"] = true end

      -- Fortress Tree: grant the nodes that match facility levels the player already bought (§5.5)
      profile.FortressTree = FortressTree.NodesFromFacilityLevels(profile.Facilities)
      profile.Facilities.GodsBlessing = profile.Facilities.GodsBlessing or { Level = 0, Workers = {} }

      -- Hero rarity: stamp the template's inherent rarity; stars are untouched (§7.6)
      for _, hero in profile.Heroes do
          hero.Rarity = HeroCatalog.RarityOf(hero.TemplateId)
      end

      profile.SchemaVersion = 3
  end
  ```

---

## 4. Shared Rules Modules

Phase 4 adds three pure `--!strict` modules so the client can preview costs and odds, while the server stays the only writer:

| Module | Purpose |
| :--- | :--- |
| `Shared/Config/FortressTreeConfig.luau` | Node list: id, branch, kind (`UNLOCK`, `LEVEL`, `PERK`), Gold cost, prerequisite node ids and floor gate. |
| `Shared/Util/FortressTree.luau` | `CanUnlock(profile, nodeId)`, `FacilityLevel(tree, facility)`, `PerkBonuses(tree)` and `NodesFromFacilityLevels(facilities)`. |
| `Shared/Util/SummonLuck.luau` | `Luck(godsBlessingLevel, labor, perks)` and `ApplyLuck(rates, luck)` (§6.3). |

`FacilityConfig` gains a `GodsBlessing` level table, `HeroCatalog` gains a `Rarity` per template and the new banner rates (§7), and `StatBalance` gains `HeroRarityCombatMultiplier = 1.35` and `HeroRarityLaborMultiplier = 1.12`.

---

## 5. Fortress Development Tree

### 5.1 Concept
The Fortress Tree replaces the old per-facility **[UPGRADE]** buttons. Every support facility is unlocked and levelled by buying nodes in the tree. The tree is opened from the **Facilities** toolbar button and from the **Architect's Table**, a drafting desk with blueprints beside the War Banner.

Core Main Buildings (Summoning Altar, War Banner, The Pit, Blacksmith Forge) are not in the tree. The Infirmary & Barracks was removed (§10). They are always available once onboarding unlocks them.

### 5.2 Layout
The root node, **Citadel Charter**, is owned by every player. Four branches grow from it, one per facility:

```
                              [Citadel Charter] (owned)
        +-------------------+---------+----------+--------------------+
        |                   |                    |                    |
   OUTSKIRTS            COMMERCE              MARTIAL               DIVINE
 Guard Post           The Market         Training Grounds       God's Blessing
 [Lv1 Frontier Camp]  [Open the Market]  [Raise the Grounds]    [Consecrate the Angel]
 [Lv2]                [Lv2]              [Lv2]                  [Lv2]
 [Lv3]──(Night Watch) [Lv3]──(Extra Stall) [Lv3]──(Drill Sergeant) [Lv3]──(Votive Candles)
 [Lv4]                [Lv4]              [Lv4]                  [Lv4]
 [Lv5]──(Long Patrols)[Lv5]──(Appraiser) [Lv5]──(Veteran Drills) [Lv5]──(Saint's Favor)
```

Each facility branch has 5 level nodes and 2 perk nodes. A fifth branch, **Command**, has 4 nodes that open squad slots 2–5 (§5.7). The tree has 33 nodes including the root.

### 5.3 Node Rules
- **Level nodes** must be bought in order. The facility's level equals the number of level nodes owned in its branch, so buying `Lv1` unlocks the facility.
- **Perk nodes** hang off level 3 and level 5 of each branch and need that level node first.
- **Floor gates:** level 3 nodes need `HighestClearedFloor >= 5`, level 4 nodes need `>= 15` and level 5 nodes need `>= 25`. Every Divine node also needs `>= 5`, so God's Blessing opens after the first Biome Boss.
- **Costs** are Gold only and are taken when the node is bought. Nodes are permanent. There is no respec and no refund.
- **Guard Post Lv1 (Frontier Camp)** is free and owned from the start, so the idle loop works before the player first opens the tree.

### 5.4 Node Costs & Effects

| Branch | Node | Kind | Gold | Floor gate | Effect |
| :--- | :--- | :---: | ---: | :---: | :--- |
| Outskirts | Frontier Camp | Lv1 | Free | — | Guard Post Lv1 (owned by default) |
| Outskirts | Timber Shack | Lv2 | 1,500 | — | Guard Post Lv2 |
| Outskirts | Stone Bastion | Lv3 | 6,000 | 5 | Guard Post Lv3 |
| Outskirts | Night Watch | Perk | 8,000 | 5 | +2 h Max Offline Cap |
| Outskirts | Fortified Outpost | Lv4 | 20,000 | 15 | Guard Post Lv4 |
| Outskirts | Frontier Barbican | Lv5 | 60,000 | 25 | Guard Post Lv5 |
| Outskirts | Long Patrols | Perk | 75,000 | 25 | +10% Guard Post `BaseRate` |
| Commerce | Open the Market | Lv1 | 1,000 | — | Market Lv1 |
| Commerce | Twin Stalls | Lv2 | 3,500 | — | Market Lv2 |
| Commerce | Bazaar Pavilion | Lv3 | 12,000 | 5 | Market Lv3 |
| Commerce | Extra Stall | Perk | 15,000 | 5 | +1 Market worker slot |
| Commerce | Exchange Depot | Lv4 | 35,000 | 15 | Market Lv4 |
| Commerce | Merchant Exchange | Lv5 | 90,000 | 25 | Market Lv5 |
| Commerce | Appraiser's Eye | Perk | 110,000 | 25 | +5% Market `BaseBonus` |
| Martial | Raise the Grounds | Lv1 | 1,200 | — | Training Grounds Lv1 |
| Martial | Training Yard | Lv2 | 4,000 | — | Training Grounds Lv2 |
| Martial | Cobblestone Arena | Lv3 | 14,000 | 5 | Training Grounds Lv3 |
| Martial | Drill Sergeant | Perk | 18,000 | 5 | +1 Training Grounds worker slot |
| Martial | War Pavilion | Lv4 | 40,000 | 15 | Training Grounds Lv4 |
| Martial | Martial Amphitheater | Lv5 | 100,000 | 25 | Training Grounds Lv5 |
| Martial | Veteran Drills | Perk | 125,000 | 25 | +3% Training `BaseBonus` |
| Divine | Consecrate the Angel | Lv1 | 2,500 | 5 | God's Blessing Lv1 |
| Divine | Gilded Wings | Lv2 | 8,000 | 5 | God's Blessing Lv2 |
| Divine | Choir of Light | Lv3 | 25,000 | 5 | God's Blessing Lv3 |
| Divine | Votive Candles | Perk | 30,000 | 5 | +1 God's Blessing worker slot |
| Divine | Radiant Halo | Lv4 | 70,000 | 15 | God's Blessing Lv4 |
| Divine | Seraph Ascendant | Lv5 | 180,000 | 25 | God's Blessing Lv5 |
| Divine | Saint's Favor | Perk | 200,000 | 25 | +3% summon luck (still under the cap in §6.3) |
| Command | Second Banner | Slot | 500 | — | Opens squad slot 2 |
| Command | Third Banner | Slot | 2,000 | — | Opens squad slot 3 |
| Command | Fourth Banner | Slot | 6,000 | 5 | Opens squad slot 4 |
| Command | Fifth Banner | Slot | 15,000 | 10 | Opens squad slot 5 |

Level node costs for the three existing facilities are the same as the old upgrade costs in GDD §4.3. Only where they are bought has changed.

### 5.5 Server Service: `FortressTreeService.luau`
Create `src/ServerScriptService/Core/FortressTreeService.luau`:
- **State:** `profile.FortressTree = { Nodes = { [nodeId] = true } }`. `profile.Facilities[name].Level` is still stored, so existing facility code keeps reading it, but this service is its only writer.
- **Remote:** `ProgressionRemotes.UnlockTreeNode` (RemoteFunction, one `nodeId: string`) returns `(ok, message)`. The updated tree and facility levels reach the client in the normal profile sync.
- **Validation:** The node id must exist in `FortressTreeConfig`. The node must not be owned yet, every prerequisite must be owned, the floor gate must be met, the player must hold enough Gold and `profile.Unlocks.FortressTree` must be set. Requests are limited to 4 per second per player.
- **On success:** Deduct Gold, add the node, recompute `Facilities[name].Level` and the perk bonuses, report `TreeNodeUnlocked` to `OnboardingService`, save and sync.
- **Retirement:** The old `FacilityInteract` "UPGRADE" action is removed. Worker assignment through `FacilityInteract` stays.
- **Migration helper:** `FortressTree.NodesFromFacilityLevels` grants the level nodes that match each facility's saved level, so nobody pays twice. Perks are never granted by migration.

### 5.6 Facilities Appear Only When Unlocked
A support facility does not exist in the world until its branch's level 1 node is owned:
- **Locked:** The facility's model, its `[F]` prompt and its worker spots are not built. Its site on the plot is plain ground that matches the area around it (courtyard cobblestone for the Market and Training Grounds), with no outline, sign or prompt. A locked facility also has no entry in the Facilities panel or the worker-assignment lists. It is shown only as a locked node in the Fortress Tree.
- **Unlocking:** When the level 1 node is bought, the server builds the facility's level 1 model on its site, and a short construction reveal plays: dust, scaffolding that drops away, then the building. The prompt and worker spots appear when the reveal ends.
- **Upgrading:** Each later level node plays an upgrade burst (dust and sparkles) on the standing building. The God's Blessing angel changes its look every level (§6.1). The Market and Training Grounds keep one model for now; per-level models for them (GDD §4.3 *Visual Identity* columns) are future art work.
- **Who builds it:** `PlotManager` builds and removes facility models on the server from the owner's `Facilities[name].Level`, so the owner and anyone visiting the plot see the same thing. `FortressTreeService` calls it after every successful purchase. On join, the plot is built from the saved levels with no reveal.
- **The Guard Post** is visible from the start, because its level 1 node is owned by default.
- **Core Main Buildings** (Summoning Altar, War Banner, The Pit, Blacksmith Forge) are not affected and are always in the world.

### 5.7 Squad Slots
- Every Master starts with **one** squad slot (`FortressTreeConfig.BaseSquadSlots`). Each Command node opens the next slot, in order, up to 5. `FortressTree.SquadSlots(tree)` is the single source; `DataManager.MaxSquadSlots` returns it.
- Command nodes carry `System = "Squad"`, so they unlock with the first summon instead of the Fortress Tree step. Every other node needs `FortressTree`. `FortressTree.CanUnlock` takes `profile.Unlocks` and checks each node's own system.
- The server rejects assignment to a slot that is not open, and `SyncProfile` benches any hero standing in one. The new default profile deploys only Han; Jenna starts on the bench.
- The Squad screen shows locked slots as 🔒 **[LOCKED]**; clicking one opens the Fortress Tree.
- The v3 migration grants Command nodes for every slot a saved hero already stands in, so old squads are not broken up.

---

## 6. God's Blessing (Fountain Facility)

### 6.1 Placement & Visuals
The Plaza Fountain in the centre of the courtyard keeps its basins and water. When the facility is unlocked, a **marble angel statue** with folded wings and both hands raised, holding a lantern of light, rises onto its top tier. The fountain becomes the **God's Blessing** facility, with a `[F]` prompt that opens its facility panel (assign Acolytes, see the current luck bonus).

Following §5.6, there is no angel, prompt or glow before the Divine branch's level 1 node is bought. Until then the fountain is a plain fountain with an ordinary top tier. Each level adds to the look:

| Level | Visual identity |
| :---: | :--- |
| **Lv. 1** | Cleaned marble angel, soft lantern glow, candles on the rim. |
| **Lv. 2** | Gilded wing edges, the water glows pale gold. |
| **Lv. 3** | A faint choir chime and rising light motes around the statue. |
| **Lv. 4** | A floating golden halo, petals drifting across the basin. |
| **Lv. 5** | Wings spread, and a beam of light rises from the lantern into the sky. |

When a summon at the Summoning Altar lands on a boosted tier, the angel's lantern pulses.

### 6.2 Level Table
Stationed **Acolytes** (`Healer` preferred, +25% labor synergy) pray at the fountain:

| Level | Max Workers | Base Luck (`BaseLuck`) |
| :---: | :---: | :---: |
| **Lv. 1** | 1 | `+4%` |
| **Lv. 2** | 1 | `+8%` |
| **Lv. 3** | 2 | `+14%` |
| **Lv. 4** | 2 | `+22%` |
| **Lv. 5** | 3 | `+32%` |

### 6.3 Summon Luck Formula
$$\text{Luck} = \min\Big(0.50,\; \text{BaseLuck}_{\text{Level}} + 0.004 \times \sum \text{EffectiveLabor}_{\text{Acolytes}} + \text{Perk}_{\text{Saint's Favor}}\Big)$$

Luck applies to every banner at the Summoning Altar: both hero banners and the artifact banner. For a banner whose tiers have base rates $p_1$ (the lowest tier) to $p_n$:

$$p'_i = p_i \times (1 + \text{Luck}) \quad \text{for } i \ge 2, \qquad p'_1 = 1 - \sum_{i \ge 2} p'_i$$

- Only the lowest tier pays for the boost, so the odds always add up to 100%.
- Luck never changes pity counters, the pity threshold or the 10-pull guarantee.
- The server reads luck when the pull is made. The client shows the boosted odds on the banner panel with a `Blessing +X%` badge, using `SummonLuck.ApplyLuck`.

**Example** (*A Star's Arrival*, Lv. 5 with 2 Acolytes at 40 total Labor: `0.32 + 0.16 = 0.48` Luck):

| Tier | Base rate | With +48% luck |
| :--- | ---: | ---: |
| Common | 60.00% | 40.80% |
| Uncommon | 24.00% | 35.52% |
| Rare | 10.00% | 14.80% |
| Superior | 4.20% | 6.22% |
| Exalted | 1.40% | 2.07% |
| Legendary | 0.33% | 0.49% |
| Mythical | 0.07% | 0.10% |

---

## 7. Inherent Hero Rarity & Lowered Hero Odds

### 7.1 Concept
Heroes gain an **inherent rarity**, like weapons, but it only adds a stat multiplier. Summoning and stars work as before:
- **Inherent rarity** is fixed per hero template and multiplies the hero's base combat and labor stats. It cannot be upgraded, rerolled or refined.
- **Heroes are still summoned at their template's star**, which matches their rarity tier at launch: Han and Jenna arrive at 1★, Ignis and Archon at 5★, and Astrea at 7★.
- **Stars** still rise through Promotion at The Pit, with the level cap `Stars × 10`. Promotion stops at `PitBalanceConfig.MaxStars = 5`, as before; Solaris and Astrea are summoned at 6★ and 7★ and simply cannot be promoted further yet.
- Rarity stays with the hero when it is promoted. A promoted Common hero reaches the same stars as a Mythical one, but keeps its lower rarity multiplier.

### 7.2 Rarity Ladder
Heroes use the same tier names as weapons (GDD §7.2). Launch heroes span tiers 1 to 7. Tiers 8 to 16 are reserved for future heroes.

| Tier | Rarity | Combat multiplier ($1.35^{t-1}$) | Labor multiplier ($1.12^{t-1}$) | Launch heroes |
| :---: | :--- | ---: | ---: | :--- |
| 1 | Common | 1.00× | 1.00× | Han, Jenna |
| 2 | Uncommon | 1.35× | 1.12× | Aaron, Velkist |
| 3 | Rare | 1.82× | 1.25× | Catio, Eolka |
| 4 | Superior | 2.46× | 1.40× | Valeria, Morrigan |
| 5 | Exalted | 3.32× | 1.57× | Ignis, Sovereign Archon |
| 6 | Legendary | 4.48× | 1.76× | Solaris |
| 7 | Mythical | 6.05× | 1.97× | Astrea |

### 7.3 Stat Formula
$$\text{HeroCombatMult} = 1.35^{(t-1)} \times 3^{(S-1)} \times 1.08^{(L-1)}$$
$$\text{HeroLaborMult} = 1.12^{(t-1)} \times 1.35^{(S-1)} \times \big(1 + 0.05(L-1)\big)$$

$t$ is the inherent rarity tier, $S$ the stars and $L$ the level. A Common hero ($t = 1$) has the same stats as before, so the floor balance tables, which use Han as the reference, stay valid. Every other hero is stronger than before by its rarity multiplier, from 1.35× (Uncommon) to 6.05× (Mythical).

### 7.4 Lowered Hero Banner Odds
Both hero banners now roll a rarity tier, and each tier holds one hero. The rates are lower than before, which God's Blessing (§6) can partly offset:

| Banner | Common | Uncommon | Rare | Superior | Exalted | Legendary | Mythical | Hard pity |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| *Call of the Rift* (old) | 60% | 25% | 10% | 4% | 1% | — | — | Top hero in 50 |
| *Call of the Rift* (new) | **70%** | **20%** | **7%** | **2.5%** | **0.5%** | — | — | Ignis (Exalted) in **80** |
| *A Star's Arrival* (old) | 50% | 25% | 13.5% | 6.5% | 3.5% | 1.2% | 0.3% | Astrea in 50 |
| *A Star's Arrival* (new) | **60%** | **24%** | **10%** | **4.2%** | **1.4%** | **0.33%** | **0.07%** | Astrea (Mythical) in **90** |

- Costs are unchanged: 100 Gems for one pull and 900 for ten.
- **New 10-pull guarantee:** every 10-pull on either hero banner includes at least one Rare or higher hero, matching the artifact banner.
- Pity is raised so it does not undo the lower odds. With the old 50-pull pity, a 0.5% top rate would mostly be paid out by pity.

### 7.5 Promotion & Fodder
- Promotion keeps its current rules (same-rank donors plus Promotion Stones), and the recipient's rarity never changes.
- Synthesis fodder XP is unchanged and still uses the fodder's stars.

### 7.6 Existing Heroes (Migration)
Owned heroes keep their stars and level and get their template's rarity. Their stats then follow §7.3, the same as newly summoned heroes, so old and new copies of a hero are equally strong.

---

## 8. Facility Idle Labor Loop Backend

1. **Zero Confusion:** Idle rewards generate strictly from benched heroes assigned to Fortress Plot facilities (`WaitingRoomService` + `OfflineRewardService`). No floor idle chest.
2. **Formula:**
   $$\text{HourlyGold} = \text{BaseRate} + 0.85 \times \sum \text{EffectiveLabor}(\text{assigned heroes})$$
   `EffectiveLabor` now includes the rarity labor multiplier (§7.3). `BaseRate` and the offline cap include the Outskirts perks (§5.4).
3. **Calculation & Claim:**
   - Server records `LastClaimTimestamp` in profile.
   - On claim request, server validates elapsed time (capped at 24h), credits Gold/materials to profile, and resets timestamp.

---

## 9. Verification & Acceptance Criteria

1. **Automated Onboarding Test (`tests/phase4-onboarding.luau`):**
   - Verify step sequence progression and currency awards.
   - Verify `profile.Unlocks` gating rejects unauthorized actions.
   - Verify v3 migration populates clean default data for new and existing profiles.
2. **Automated Fortress Tree Test (`tests/phase4-fortress-tree.luau`):**
   - Reject unknown nodes, owned nodes, missing prerequisites, unmet floor gates and too little Gold.
   - Verify facility level equals the number of owned level nodes, and that perks apply their bonuses.
   - Verify migration grants level nodes matching saved facility levels and no perks.
3. **Automated Summon Luck Test (`tests/phase4-summon-luck.luau`):**
   - Verify luck is capped at 50%, boosted odds still add up to 100%, and pity thresholds and guarantees are unchanged.
   - Verify the §6.3 example table.
4. **Automated Hero Rarity Test (`tests/phase4-hero-rarity.luau`):**
   - Verify every hero is summoned at its template's star with its template's rarity, and that the banner rates and pity match §7.4.
   - Verify a Common hero's stats match the old formula, and that rarity multipliers follow §7.2.
   - Verify migration keeps stars and level unchanged and stamps rarity.
5. **Automated Facility Labor Test (`tests/phase4-facility-labor.luau`):**
   - Verify benched heroes assigned to facilities produce correct labor rates.
   - Verify 24-hour cap enforcement.
6. **Studio Playtest:**
   - On a fresh profile, only the Guard Post stands: the Market and Training Grounds sites are empty ground, the fountain has no angel, and none of them has a prompt or appears in the Facilities panel.
   - Buying a level 1 node plays the construction reveal and the facility appears with its prompt, without a rejoin. A second player visiting the plot sees the same buildings.
   - Buying later level nodes plays an upgrade burst, and each God's Blessing level changes the angel. After a rejoin the plot is built straight from the saved levels.

---

## 10. Implementation Notes

What shipped, and where it differs from the sections above:

| Area | Files |
| :--- | :--- |
| Rules (shared, pure) | `Shared/Config/FortressTreeConfig.luau`, `Shared/Config/OnboardingConfig.luau`, `Shared/Util/FortressTree.luau`, `Shared/Util/SummonLuck.luau`, `Shared/Util/Onboarding.luau` |
| Server | `Core/OnboardingService.luau`, `Core/FortressTreeService.luau`, `Core/ProfileMigrations.luau` (v3), `Core/FacilityPresence.luau` (hide and reveal), `Core/AngelStatue.luau`, plus changes in `DataManager`, `PlotManager`, `PlotBuildings` (Architect's Table), `TowerFloorService` (Tower gate) and `CombatSimulation` (`FloorCleared`) |
| Client | `UI/FortressTreeController.luau` (tree panel), `UI/GoalTrackerController.client.luau` (interim Next Goal card until Phase 5), a FORTRESS toolbar button, and the God's Blessing panel and luck badge in `UI/FacilityController.luau` |
| Tests | `tests/phase4-progression.luau` (one suite instead of the four listed in §9) |

- **Gating:** Squad (squad assignment and auto-swap), Tower (travel; Floor 5+ needs `TowerFloor5`), Forge (craft and upgrade), Facilities (support facility assignment; the Infirmary stays open) and Pit (preview and commit) are checked on the server. Summoning is never gated.
- **Artifact banner luck:** the live artifact banner rolls star pools (1–2★ 50%, 3★ 35%, 4★ 12%, 5★ 3%), not the rarity table in GDD §7.4, so luck boosts those pools above the lowest.
- **Studio helper:** the **+Resources** prototype button also unlocks every system and finishes the quest chain, for testing later systems quickly.
- **Not built yet:** the facility idle-labor claim flow in §8 (passive Gold already works through the existing Guard Post loop), and per-level Market and Training Grounds models.
- **Infirmary removed:** the Infirmary & Barracks building, its beds, the `FACILITY_INFIRMARY` assignment and its stamina and coma formulas are gone; benched and working heroes recover stamina passively. Saved Infirmary heroes return to the bench, Valeria (Healer) now prefers God's Blessing, and Syndicate bless/leech runes target the Guard Post.
- **Courtyard layout:** with the Infirmary gone, the courtyard is a 3 x 2 grid either side of a clear spawn-to-rear-gate walkway (GDD §3.4): Summoning and Forge by the spawn, the Command Post (War Banner + Architect's Table) and The Pit in the middle, Training Grounds and Market at the back (`PlotBuildings` version 17).
