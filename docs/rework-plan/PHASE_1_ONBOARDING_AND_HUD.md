# Phase 1: Onboarding Engine, v3 Profile Schema & React-lua HUD

**Document Version:** 1.0  
**Phase Status:** Ready for Execution  
**Prerequisites:** Phase 0 complete  

---

## 1. Objectives & Scope

Phase 1 establishes the single guiding spine of the game: **a pinned "Next Goal" Quest Chain** that introduces systems one by one, paired with a modern, responsive **React-lua HUD** that eliminates clutter and respects mobile safe areas.

---

## 2. Server Architecture: Onboarding Engine

### 2.1 Configuration: `OnboardingConfig.luau`
Create `src/ReplicatedStorage/Shared/Config/OnboardingConfig.luau` defining the canonical first-session progression steps:

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
  - Validates that the reported event matches the current active step's `Event`.
  - Increments progress. If target is reached:
    - Awards milestone currencies (`Gold`, `Gems`).
    - Merges step `Unlocks` into `profile.Unlocks`.
    - Advances `profile.Onboarding.StepIndex += 1`.
    - Dispatches a celebratory broadcast toast.
    - Synchronizes state via `OnboardingRemotes/StateSync`.
- **Event Hooks:** Connect to:
  - `DataManager.CreateHeroFromSeed` (Summon)
  - `DataManager.AssignSquadSlot` (Deploy)
  - `TowerFloorService.ReportFloorClear` (Floor 1)
  - `BlacksmithService.UpgradeArtifact` (Forge)
  - `WaitingRoomService.AssignFacility` (Facilities)
  - `PitService.SynthesizeHero` (The Pit)

### 2.3 Profile Schema Migration (v2 $\to$ v3)
In `src/ServerScriptService/Core/DataManager.server.luau`:
- Set `SchemaVersion = 3`.
- Template additions:
  ```luau
  Onboarding = {
      StepIndex = 1,
      Progress = 0,
      Completed = false,
  },
  Unlocks = {
      Squad = false,
      Tower = false,
      Forge = false,
      Facilities = false,
      Pit = false,
  },
  ```
- **Migration Logic:**
  - If `profile.HighestClearedFloor >= 1`:
    - Auto-unlock `Squad`, `Tower`, `Forge`.
    - Set `StepIndex` to 4 (`step_forge`).
  - If existing veteran player (`HighestClearedFloor >= 5`):
    - Auto-unlock all systems.
    - Set `Onboarding.Completed = true`.

---

## 3. Client Architecture: React-lua UI Foundation

### 3.1 Directory Structure
All new UI components reside in `src/StarterPlayerScripts/UI/Next/` to run side-by-side with legacy screens during rollout:

```
src/StarterPlayerScripts/UI/Next/
├── Tokens.luau              -- Obsidian, Gold, Silver palette, typography, paddings
├── Root.client.luau         -- React root mounting into CoreUISafeInsets ScreenGui
├── State/
│   ├── useProfile.luau      -- Reactive hook for Currencies & Unlocks
│   └── useOnboarding.luau   -- Reactive hook for Active Step & Progress
└── Components/
    ├── Common/
    │   ├── Button.luau      -- Min 44px target, activated feedback, gamepad selectable
    │   ├── Card.luau        -- Gothic obsidian panel with ornate border
    │   └── Badge.luau       -- Notification / new unlock dot
    ├── HUD/
    │   ├── GoalTracker.luau -- Pinned objective card with progress bar and rewards
    │   ├── CurrencyBar.luau -- Large readable Gold and Gem pills with +/- floaters
    │   └── NavBar.luau      -- Bottom toolbar with Squad, Summon, Forge, Facilities, Tower
```

### 3.2 Design Tokens (`Tokens.luau`)
```luau
return {
    Colors = {
        Background = Color3.fromRGB(15, 17, 24),
        BackgroundSubtle = Color3.fromRGB(24, 27, 38),
        Border = Color3.fromRGB(54, 59, 82),
        BorderGold = Color3.fromRGB(218, 165, 32),
        TextPrimary = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(160, 168, 192),
        Gold = Color3.fromRGB(255, 215, 0),
        GemCyan = Color3.fromRGB(64, 224, 208),
        AccentRed = Color3.fromRGB(220, 53, 69),
    },
    Typography = {
        Font = Font.fromEnum(Enum.Font.GothamMedium),
        FontBold = Font.fromEnum(Enum.Font.GothamBold),
        SizeSM = 13,
        SizeMD = 16,
        SizeLG = 20,
        SizeXL = 24,
    },
    Layout = {
        MinTouchTarget = 44,
        PaddingSM = 8,
        PaddingMD = 12,
        PaddingLG = 16,
        CornerRadius = UDim.new(0, 8),
    }
}
```

### 3.3 Goal Tracker Component (`GoalTracker.luau`)
- Positioned at Top-Right (or anchored beneath the top bar).
- Features:
  - Step title in bold font ($\ge 16\text{ px}$).
  - Progress bar ($0 \to 100\%$).
  - Reward preview tag (`+200 Gems`).
  - Pulsing glow animation on completion.
  - Clicking opens guidance modal or highlights target island destination.

### 3.4 Navigation Bar (`NavBar.luau`)
- Anchored at bottom-center.
- Exactly 5 persistent tab buttons:
  1. **Squad** (Unlocked by Step 1)
  2. **Summon** (Always Unlocked)
  3. **Forge** (Unlocked by Step 3)
  4. **Facilities** (Unlocked by Step 4)
  5. **Tower** (Unlocked by Step 2)
- Locked tabs display a subtle lock icon and click hint ("Unlocks after Floor 1").
- Q/E Whistle buttons are **not** rendered.

### 3.5 Legacy HUD Cleanup
In `src/StarterPlayerScripts/UI/HUDController.client.luau`:
- Wrap legacy elements (old floating toolbar, Q/E keybind pills, World Boss & Pity stat table, duplicate bottom-left currency cluster) behind a feature flag: `_G.__USE_NEXT_HUD__ = true`.
- When flag is true, hide legacy frames, leaving only the 3D world, nameplates, and the new React HUD.

---

## 4. Verification & Testing

1. **New User Flow:**
   - Create clean test profile (`StepIndex = 1`).
   - Verify HUD displays: Goal Tracker ("Summon your first hero"), Currency Bar, NavBar with only Summon active.
   - Execute Summon -> Goal Tracker updates with celebratory pulse, awards 200 Gems, unlocks Squad tab.
   - Deploy Squad -> Goal Tracker advances to "Clear Floor 1", unlocks Tower tab.
2. **Device Simulator Tests:**
   - iPhone 14 / Dynamic Island: verify top bar clears notches (`CoreUISafeInsets`).
   - Mobile Portrait / Landscape: touch targets all $\ge 44 \times 44\text{ px}$.
   - Gamepad: navigate between NavBar tabs using controller D-pad.
3. **Build Integrity:**
   - `rojo build -o build.rbxl` compiles cleanly.
