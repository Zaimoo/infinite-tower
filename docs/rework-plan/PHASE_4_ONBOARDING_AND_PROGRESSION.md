# Phase 4: Onboarding Engine, Progressive Unlocks & Idle Loop Backend

**Document Version:** 2.0  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phase 3 complete  

---

## 1. Objectives & Scope

Phase 4 implements the server-authoritative spine of the game's progression:
1. **Onboarding Engine (`OnboardingService.luau`):** A sequential quest chain that gradually unlocks the game's 10 interlocking systems one by one.
2. **Profile Schema v3 Migration (`DataManager.server.luau`):** Adds `Onboarding` and `Unlocks` tables to player profiles with automatic migration for existing data.
3. **Progressive System Gating:** Server handlers reject actions on locked systems until the corresponding milestone step has been cleared.
4. **Facility-Only Idle Labor Backend:** Integrates `WaitingRoomService` and `OfflineRewardService` to generate passive Gold and Materials exclusively from benched heroes assigned to Fortress Plot facilities.

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
		Unlocks = { "Facilities" },
		Reward = { Gems = 100 },
	},
	{
		Id = "step_facilities",
		Title = "Assign a hero to work",
		Description = "Put a benched hero to work at a facility",
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
}

return table.freeze(Steps)
```

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
      if (profile.MaxFloorReached or 0) >= 2 then profile.Unlocks["Forge"] = true; profile.Unlocks["Facilities"] = true end
      if (profile.MaxFloorReached or 0) >= 5 then profile.Unlocks["Pit"] = true end
      profile.SchemaVersion = 3
  end
  ```

---

## 4. Facility Idle Labor Loop Backend

1. **Zero Confusion:** Idle rewards generate strictly from benched heroes assigned to Fortress Plot facilities (`WaitingRoomService` + `OfflineRewardService`). No floor idle chest.
2. **Formula:**
   $$\text{HourlyGold} = \text{BaseRate} + 0.85 \times \sum \text{EffectiveLabor}(\text{assigned heroes})$$
3. **Calculation & Claim:**
   - Server records `LastClaimTimestamp` in profile.
   - On claim request, server validates elapsed time (capped at 24h), credits Gold/materials to profile, and resets timestamp.

---

## 5. Verification & Acceptance Criteria

1. **Automated Onboarding Test (`tests/phase4-onboarding.luau`):**
   - Verify step sequence progression and currency awards.
   - Verify `profile.Unlocks` gating rejects unauthorized actions.
   - Verify v3 migration populates clean default data for new and existing profiles.
2. **Automated Facility Labor Test (`tests/phase4-facility-labor.luau`):**
   - Verify benched heroes assigned to facilities produce correct labor rates.
   - Verify 24-hour cap enforcement.
